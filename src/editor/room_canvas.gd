extends Control
## The Dungeon-Werkstatt's drawing surface: the room in the real 0x72 crypt
## look (crypt_0x72_art.gd bakes it like the game, gates and candles
## included), markers drawn with the game's sprites, an optional grid and the
## brush under the mouse. Mouse wheel zooms around the pointer; the middle
## button, or space with the left button, pans. Clicks become cell events for
## the editor. Draws only; the editor owns the room (room_doc.gd).
## With a decor piece chosen, a ghost of it follows the mouse: white outline
## where it may go, red with stripes where not. With the grid on, cells of
## solid pieces are hatched.

signal cell_pressed(cell: Vector2i, button: int)
signal cell_dragged(cell: Vector2i, button: int)
signal cell_released(cell: Vector2i, button: int)
signal hovered(cell: Vector2i)

const Crypt72 = preload("res://src/crypt_0x72_art.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const Decor = preload("res://src/dungeon/decor_catalog.gd")
const CELL := 32.0
const SPRITES := "res://assets/sprites/0x72/"
const MIN_ZOOM := 0.2
const MAX_ZOOM := 3.0
## Seconds between two bakes while painting (the overlay shows strokes at once).
const BAKE_GAP := 0.12

var doc: RefCounted
var zoom := 0.5
var offset := Vector2(20, 20)
var show_grid := true
## Brush outline: cells around the hovered cell, or a rectangle while dragging.
var brush_radius := 0
var rect_from := Vector2i(-1, -1)
var hover := Vector2i(-1, -1)
var tool_color := Color("edbf75")
## The decor piece shown under the mouse ("" for none), and whether it fits there.
var ghost_id := ""
var ghost_variant := 0
var ghost_ok := true
var _ghosts: Dictionary = {}
var _baked_styles: Dictionary = {}
var _baked_carpets: Dictionary = {}
var _baked_decor: Dictionary = {}
var _world: Node2D
var _crypt: RefCounted
var _template: Dictionary = {}
var _bake_wait := 0.0
var _bake_due := false
var _baked_floor: Dictionary = {}
var _drag_button := 0
var _panning := false
var _pan_from := Vector2.ZERO
var _clock := 0.0
var _icons: Dictionary = {}


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	_world = Node2D.new()
	_world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world.draw.connect(_draw_world)
	add_child(_world)
	for name: String in ["knight_m_idle_anim_f0", "skelet_idle_anim_f0", "chest_full_open_anim_f0", "chest_mimic_open_anim_f2", "floor_stairs"]:
		_icons[name] = load(SPRITES + name + ".png")


## Shows a room and fits it into view.
func show_room(room_doc: RefCounted) -> void:
	doc = room_doc
	rebake()
	fit()


## Re-bakes the 0x72 room image from the current room (call after changes).
func rebake() -> void:
	if doc == null: return
	_template = doc.to_template()
	var config := {"tile_size": 32, "generator_version": Dungeon.GENERATOR_VERSION, "world_size": _template.world_size, "play_bounds": _template.play_bounds}
	var layout := Dungeon._make_layout(_template, config)
	layout.id = "werkstatt-" + str(_template.get("id", ""))
	# The gates the game would set, so the arches show where they will be.
	layout.exits = []
	for side: String in ["west", "east", "north", "south"]:
		var gate := Dungeon._crypt_wall_door(side, 1, layout)
		if gate.is_empty() or layout.exits.any(func(other: Dictionary) -> bool: return other.door_cell == gate.door_cell): continue
		gate.forward = layout.exits.is_empty()
		layout.exits.append(gate)
	if doc.role() == "boss" and doc.stairs != Vector2i(-1, -1):
		var stairs := Dungeon._make_stairs(layout)
		if not stairs.is_empty(): layout.exits.append(stairs)
	_crypt = Crypt72.new()
	_crypt.bake(layout, absi(str(_template.get("id", "")).hash()))
	_baked_floor = doc.floor_cells.duplicate()
	_baked_styles = doc.floor_styles.duplicate(true)
	_baked_carpets = doc.carpets.duplicate(true)
	_baked_decor = doc.decor.duplicate(true)
	_bake_due = false
	_world.queue_redraw()


## Decor the last bake placed by itself ([x, y, id, variant]).
func auto_items() -> Array:
	return _crypt.auto_items.duplicate(true) if _crypt != null else []


## Redraws during a stroke: new floor shows at once as a light area, the
## crypt art follows with the bake when the stroke ends.
func request_bake() -> void:
	_world.queue_redraw()


## Zoom and offset so the whole room fits.
func fit() -> void:
	if doc == null or size.x <= 0.0: return
	var room := Vector2(doc.size) * CELL
	zoom = clampf(minf((size.x - 24.0) / room.x, (size.y - 24.0) / room.y), MIN_ZOOM, MAX_ZOOM)
	offset = (size - room * zoom) * 0.5
	_apply_view()


func zoom_by(factor: float, around: Vector2) -> void:
	var before := (around - offset) / zoom
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	offset = around - before * zoom
	_apply_view()


func _apply_view() -> void:
	_world.position = offset
	_world.scale = Vector2(zoom, zoom)
	_world.queue_redraw()


## The cell under a point of this control.
func cell_at(point: Vector2) -> Vector2i:
	var world := (point - offset) / zoom
	return Vector2i(floori(world.x / CELL), floori(world.y / CELL))


func _process(delta: float) -> void:
	_clock += delta
	if _bake_due:
		_bake_wait -= delta
		if _bake_wait <= 0.0:
			_bake_wait = BAKE_GAP
			rebake()
	# Animated candles and the gate chevron.
	if is_visible_in_tree(): _world.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			zoom_by(1.15, button.position)
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			zoom_by(1.0 / 1.15, button.position)
			accept_event()
			return
		var pan_click: bool = button.button_index == MOUSE_BUTTON_MIDDLE or (button.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE))
		if pan_click:
			_panning = button.pressed
			_pan_from = button.position
			accept_event()
			return
		if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			grab_focus()
			var cell := cell_at(button.position)
			if button.pressed:
				_drag_button = button.button_index
				cell_pressed.emit(cell, button.button_index)
			elif _drag_button == button.button_index:
				_drag_button = 0
				cell_released.emit(cell, button.button_index)
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _panning:
			offset += motion.position - _pan_from
			_pan_from = motion.position
			_apply_view()
			accept_event()
			return
		var cell := cell_at(motion.position)
		if cell != hover:
			hover = cell
			hovered.emit(cell)
			if _drag_button != 0: cell_dragged.emit(cell, _drag_button)
			_world.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = Vector2i(-1, -1)
		_world.queue_redraw()


# --- Drawing ----------------------------------------------------------------------

func _draw_world() -> void:
	if doc == null: return
	var room := Vector2(doc.size) * CELL
	_world.draw_rect(Rect2(Vector2(-6, -6) / zoom, room + Vector2(12, 12) / zoom), Color("483b3a"), false, 3.0 / zoom)
	if _crypt != null:
		_crypt.draw_room(_world)
		_crypt.draw_props(_world, _clock, false)
	# Strokes not yet baked: new floor in sand, removed floor dark.
	for cell: Vector2i in doc.floor_cells:
		if not _baked_floor.has(cell): _world.draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), Color(0.67, 0.55, 0.48, 0.85))
	for cell: Vector2i in _baked_floor:
		if not doc.floor_cells.has(cell): _world.draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), Color(0.04, 0.03, 0.03, 0.92))
	_draw_unbaked_decor()
	if show_grid: _draw_grid(room)
	_draw_markers()
	_draw_brush()


## Decor strokes not yet baked: painted floor styles and carpet show at once
## (carpet without its border), removed pieces are crossed out.
func _draw_unbaked_decor() -> void:
	var size_cell := Vector2(CELL, CELL)
	for cell: Vector2i in doc.floor_styles:
		if _baked_styles.get(cell) != doc.floor_styles[cell]:
			var texture := Decor.texture(str(doc.floor_styles[cell][0]), int(doc.floor_styles[cell][1]))
			if texture != null: _world.draw_texture_rect(texture, Rect2(Vector2(cell) * CELL, size_cell), false)
	for cell: Vector2i in doc.carpets:
		if _baked_carpets.get(cell) != doc.carpets[cell]:
			var sheet := Decor.texture(str(doc.carpets[cell][0]))
			if sheet != null: _world.draw_texture_rect_region(sheet, Rect2(Vector2(cell) * CELL, size_cell), Rect2(16, 16, 16, 16))
	for layer: Array in [[_baked_styles, doc.floor_styles], [_baked_carpets, doc.carpets], [_baked_decor, doc.decor]]:
		var before: Dictionary = layer[0]
		var now: Dictionary = layer[1]
		for cell: Vector2i in before:
			if not now.has(cell):
				var corner := Vector2(cell) * CELL
				_world.draw_line(corner + Vector2(6, 6), corner + size_cell - Vector2(6, 6), Color(0.94, 0.54, 0.42, 0.9), 3.0 / zoom)
				_world.draw_line(corner + Vector2(size_cell.x - 6, 6), corner + Vector2(6, size_cell.y - 6), Color(0.94, 0.54, 0.42, 0.9), 3.0 / zoom)


func _draw_grid(room: Vector2) -> void:
	var line := Color(1, 1, 1, 0.07)
	var width := 1.0 / zoom
	for x in range(0, int(room.x / CELL) + 1): _world.draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, room.y), line, width)
	for y in range(0, int(room.y / CELL) + 1): _world.draw_line(Vector2(0, y * CELL), Vector2(room.x, y * CELL), line, width)
	# The outer border stays wall: shown darker.
	_world.draw_rect(Rect2(Vector2(CELL, CELL), room - Vector2(CELL, CELL) * 2.0), Color(1, 1, 1, 0.12), false, width)
	# Solid decor (blocks movement in the game): hatched.
	for cell: Vector2i in doc.decor:
		if not doc.solid_at(cell): continue
		var corner := Vector2(cell) * CELL
		for stroke: Array in [[Vector2(0, 16), Vector2(16, 0)], [Vector2(0, 32), Vector2(32, 0)], [Vector2(16, 32), Vector2(32, 16)]]:
			_world.draw_line(corner + Vector2(stroke[0]), corner + Vector2(stroke[1]), Color(0.94, 0.54, 0.42, 0.55), 1.5 / zoom)
		_world.draw_rect(Rect2(corner, Vector2(CELL, CELL)), Color(0.94, 0.54, 0.42, 0.7), false, 1.5 / zoom)


func _draw_markers() -> void:
	# Enemy points the game adds by itself (to reach five), faint.
	var authored: Array = doc.enemies.map(func(cell: Vector2i) -> Vector2: return Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5)
	for point: Array in _template.get("enemy_spawns", []):
		var at := Vector2(float(point[0]), float(point[1]))
		if authored.has(at): continue
		_icon("skelet_idle_anim_f0", at, Color(1, 1, 1, 0.35))
	for cell: Vector2i in doc.enemies: _icon("skelet_idle_anim_f0", _centre(cell), Color.WHITE, Color("da4e38"))
	for cell: Vector2i in doc.chests: _icon("chest_full_open_anim_f0", _centre(cell), Color.WHITE, Color("edbf75"))
	# Mimiks: the chest with its teeth showing, outlined red (in the game it looks like any chest).
	for cell: Vector2i in doc.mimics: _icon("chest_mimic_open_anim_f2", _centre(cell), Color.WHITE, Color("da4e38"))
	for cell: Vector2i in doc.torches: _ring(_centre(cell), Color("ffb35c"))
	if doc.stairs != Vector2i(-1, -1): _icon("floor_stairs", _centre(doc.stairs), Color.WHITE, Color("8fd8e6"))
	if doc.start != Vector2i(-1, -1):
		for point: Array in _template.get("player_spawns", []).slice(1):
			_world.draw_circle(Vector2(float(point[0]), float(point[1])), 6.0, Color(0.45, 0.85, 0.8, 0.5))
		_icon("knight_m_idle_anim_f0", _centre(doc.start), Color.WHITE, Color("72dcc8"))


func _draw_brush() -> void:
	if hover.x < 0: return
	var width := 2.0 / zoom
	if not ghost_id.is_empty() and rect_from.x < 0:
		_draw_ghost(width)
		return
	if rect_from.x >= 0:
		var low := Vector2i(mini(rect_from.x, hover.x), mini(rect_from.y, hover.y))
		var high := Vector2i(maxi(rect_from.x, hover.x), maxi(rect_from.y, hover.y))
		_world.draw_rect(Rect2(Vector2(low) * CELL, Vector2(high - low + Vector2i.ONE) * CELL), Color(tool_color, 0.18))
		_world.draw_rect(Rect2(Vector2(low) * CELL, Vector2(high - low + Vector2i.ONE) * CELL), tool_color, false, width)
		return
	var corner := Vector2(hover - Vector2i(brush_radius, brush_radius)) * CELL
	_world.draw_rect(Rect2(corner, Vector2.ONE * CELL * (brush_radius * 2 + 1)), tool_color, false, width)


## The chosen piece at 60 % on the hovered cell, outlined white (fits) or red
## with stripes (does not).
func _draw_ghost(width: float) -> void:
	var key := "%s:%d" % [ghost_id, ghost_variant]
	if not _ghosts.has(key):
		var preview: Dictionary = Decor.preview(ghost_id, ghost_variant, false)
		_ghosts[key] = {"texture": ImageTexture.create_from_image(preview.image) if preview.image != null else null, "origin": preview.origin}
	var ghost: Dictionary = _ghosts[key]
	var corner := Vector2(hover) * CELL
	if ghost.texture != null:
		var texture: Texture2D = ghost.texture
		var at: Vector2 = corner - Vector2(ghost.origin) * 2.0
		_world.draw_texture_rect(texture, Rect2(at, texture.get_size() * 2.0), false, Color(1, 1, 1, 0.6) if ghost_ok else Color(1, 0.55, 0.5, 0.45))
	var cell_rect := Rect2(corner, Vector2(CELL, CELL))
	if ghost_ok:
		_world.draw_rect(cell_rect, Color(1, 1, 1, 0.9), false, width)
		return
	_world.draw_rect(cell_rect, Color(0.94, 0.3, 0.25, 0.25))
	for step in range(3):
		var along := 8.0 + step * 8.0
		_world.draw_line(corner + Vector2(along, 0), corner + Vector2(0, along), Color(0.94, 0.3, 0.25, 0.9), width * 0.75)
		_world.draw_line(corner + Vector2(CELL, CELL - along), corner + Vector2(CELL - along, CELL), Color(0.94, 0.3, 0.25, 0.9), width * 0.75)
	_world.draw_rect(cell_rect, Color(0.94, 0.3, 0.25, 1.0), false, width)


func _centre(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5


## A sprite standing on a cell (2x art), with an outline square in `mark`.
func _icon(name: String, at: Vector2, tint: Color, mark: Color = Color(0, 0, 0, 0)) -> void:
	var texture: Texture2D = _icons.get(name)
	if mark.a > 0.0: _world.draw_rect(Rect2(at - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), mark, false, 2.0 / zoom)
	if texture == null: return
	var extent := Vector2(texture.get_width(), texture.get_height()) * 2.0
	_world.draw_texture_rect(texture, Rect2(at + Vector2(-extent.x * 0.5, CELL * 0.5 - extent.y), extent), false, tint)


func _ring(at: Vector2, color: Color) -> void:
	_world.draw_arc(at, CELL * 0.45, 0.0, TAU, 20, color, 2.0 / zoom)
