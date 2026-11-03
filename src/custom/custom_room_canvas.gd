extends Control
## Draft room canvas using the CURRENT story skins and the runtime wall contour builder.
## Logical cells are 96 world units, matching hell_game.gd. No legacy dungeon palette.

signal changed
const Walls = preload("res://src/hell/hell_walls.gd")
const Graphics = preload("res://src/core/graphics_settings.gd")
const THEMES := {"krypta": "res://assets/data/krypta_theme.json", "frost": "res://assets/data/frost_theme.json", "hell": "res://assets/data/hell_theme.json"}
const ROOTS := {"krypta": "res://assets/sprites/krypta_pixel/", "frost": "res://assets/sprites/frost/", "hell": "res://assets/sprites/hell_0x72/"}
const CELL := 96.0
var room: Dictionary = {}
var world: String = "krypta"
var tool: String = "floor"
var prop_name: String = "crate_a"
var grid_on: bool = true
var settings_path: String = Graphics.SETTINGS_PATH
var _skin_root: String = ""
var _textures: Dictionary = {}
var _floor: Dictionary = {}
var _walls: Dictionary = {}
var _scale: float = 0.2
var _pan: Vector2 = Vector2.ZERO
var _hover: Vector2i = Vector2i(-1, -1)
var _start: Vector2i = Vector2i(-1, -1)
var _painting: bool = false
var _erasing: bool = false
var _panning: bool = false
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _stroke_changed: bool = false


func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(fit_room)
	custom_minimum_size = Vector2(360, 330)


## Connects the canvas to an isolated authoring draft (not live game state).
func configure(value: Dictionary, world_id: String) -> void:
	room = value
	world = world_id if ROOTS.has(world_id) else "krypta"
	_skin_root = skin_root(world, settings_path)
	var config: Dictionary = DataCache.load_dict(str(THEMES[world]))
	var skin: Dictionary = Graphics.skin(config, Graphics.mode(settings_path))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if bool(skin.get("pixel", config.get("pixel", true))) else CanvasItem.TEXTURE_FILTER_LINEAR
	_undo.clear()
	_redo.clear()
	_textures.clear()
	_rebuild()
	fit_room()


## Selects a brush. Tool changes finish any active stroke.
func set_tool(value: String) -> void:
	_finish_stroke()
	tool = value
	queue_redraw()


## Fits the entire room, including raised wall faces, into this view.
func fit_room() -> void:
	if room.is_empty() or size.x < 1: return
	var extent := Vector2(float(room.width), float(room.height)) * CELL
	_scale = clampf(minf((size.x - 48) / extent.x, (size.y - 48) / extent.y), 0.04, 0.65)
	_pan = ((size - extent * _scale) * 0.5).round()
	queue_redraw()


## Restores one complete brush transaction.
func undo() -> void:
	_finish_stroke()
	if _undo.is_empty(): return
	_redo.append(room.duplicate(true))
	_restore(_undo.pop_back())


## Reapplies one undone transaction.
func redo() -> void:
	if _redo.is_empty(): return
	_undo.append(room.duplicate(true))
	_restore(_redo.pop_back())


## Clears only the selected room's authored geometry and markers, with Undo.
func clear_room() -> void:
	_checkpoint()
	for key: String in ["floor", "ports", "props", "enemy_spawns"]: room[key] = []
	_rebuild()
	changed.emit()


func _restore(value: Dictionary) -> void:
	room.clear()
	room.merge(value, true)
	_rebuild()
	changed.emit()


func _checkpoint() -> void:
	_undo.append(room.duplicate(true))
	if _undo.size() > 60: _undo.pop_front()
	_redo.clear()


func _texture(id: String) -> Texture2D:
	if not _textures.has(id):
		var path := _skin_root + id + ".png"
		_textures[id] = load(path) if ResourceLoader.exists(path) else null
	return _textures[id]


## Resolves exactly the skin chosen in the shared graphics options, without changing it.
static func skin_root(world_id: String, settings_file: String = Graphics.SETTINGS_PATH) -> String:
	var key: String = world_id if THEMES.has(world_id) else "krypta"
	var config: Dictionary = DataCache.load_dict(str(THEMES[key]))
	var skin: Dictionary = Graphics.skin(config, Graphics.mode(settings_file))
	return str(skin.get("sprites", config.get("sprites", ROOTS[key])))


func _rebuild() -> void:
	_floor.clear()
	if room.is_empty(): return
	for p: Array in room.get("floor", []): _floor[Vector2i(int(p[0]), int(p[1]))] = true
	var grid := PackedByteArray()
	grid.resize(int(room.width) * int(room.height))
	for p: Vector2i in _floor:
		if p.x >= 0 and p.y >= 0 and p.x < int(room.width) and p.y < int(room.height): grid[p.y * int(room.width) + p.x] = 1
	for port: Dictionary in room.get("ports", []):
		var p := Vector2i(int(port.cell[0]), int(port.cell[1]))
		for off in range(2):
			var c := p + (Vector2i(0, off) if str(port.side) in ["east", "west"] else Vector2i(off, 0))
			if c.x >= 0 and c.y >= 0 and c.x < int(room.width) and c.y < int(room.height): grid[c.y * int(room.width) + c.x] = 1
	_walls = Walls.build(grid, int(room.width), int(room.height), CELL)
	queue_redraw()


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(((at - _pan) / (_scale * CELL)).floor())


func _inside(c: Vector2i) -> bool:
	return not room.is_empty() and c.x >= 1 and c.y >= 1 and c.x < int(room.width) - 1 and c.y < int(room.height) - 1


func _paint(c: Vector2i, rebuild_now: bool = true) -> void:
	if not _inside(c): return
	if tool in ["floor", "erase", "rect"]:
		var erase := _erasing or tool == "erase"
		if erase == (not _floor.has(c)): return
		if erase:
			_floor.erase(c)
			room.props = Array(room.get("props", [])).filter(func(p: Dictionary) -> bool: return int(p.x) != c.x or int(p.y) != c.y)
			room.enemy_spawns = Array(room.get("enemy_spawns", [])).filter(func(p: Array) -> bool: return int(p[0]) != c.x or int(p[1]) != c.y)
		else: _floor[c] = true
		var cells: Array = []
		for key: Vector2i in _floor: cells.append([key.x, key.y])
		room.floor = cells
	elif tool == "enemy":
		var enemies: Array = Array(room.get("enemy_spawns", [])).filter(func(p: Array) -> bool: return int(p[0]) != c.x or int(p[1]) != c.y)
		if not _erasing and _floor.has(c): enemies.append([c.x, c.y])
		room.enemy_spawns = enemies
	elif tool == "prop":
		var props: Array = Array(room.get("props", [])).filter(func(p: Dictionary) -> bool: return int(p.x) != c.x or int(p.y) != c.y)
		if not _erasing and _floor.has(c): props.append({"name": prop_name, "x": c.x, "y": c.y})
		room.props = props
	_stroke_changed = true
	if rebuild_now: _rebuild()


func _port(c: Vector2i) -> void:
	if room.is_empty(): return
	var w := int(room.width)
	var h := int(room.height)
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h: return
	var distances := [c.y, w - 1 - c.x, h - 1 - c.y, c.x]
	var side: String = ["north", "east", "south", "west"][distances.find(distances.min())]
	var point := Vector2i(clampi(c.x, 1, w - 3), 0)
	match side:
		"south": point.y = h - 1
		"east": point = Vector2i(w - 1, clampi(c.y, 1, h - 3))
		"west": point = Vector2i(0, clampi(c.y, 1, h - 3))
	var ports: Array = Array(room.get("ports", [])).filter(func(p: Dictionary) -> bool: return str(p.side) != side)
	if not _erasing: ports.append({"side": side, "cell": [point.x, point.y]})
	room.ports = ports
	_stroke_changed = true
	_rebuild()


func _finish_stroke() -> void:
	if not _painting: return
	_painting = false
	if _stroke_changed: changed.emit()
	elif not _undo.is_empty(): _undo.pop_back()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if room.is_empty(): return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var old := _scale
			_scale = clampf(_scale * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.035, 0.8)
			_pan = event.position - (event.position - _pan) * (_scale / old)
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				_checkpoint()
				_painting = true
				_stroke_changed = false
				_erasing = event.button_index == MOUSE_BUTTON_RIGHT
				_start = _cell(event.position)
				if tool == "port": _port(_start)
				elif tool != "rect": _paint(_start)
			else:
				if _painting and tool == "rect":
					var end := _cell(event.position)
					for y in range(mini(_start.y, end.y), maxi(_start.y, end.y) + 1):
						for x in range(mini(_start.x, end.x), maxi(_start.x, end.x) + 1): _paint(Vector2i(x, y), false)
					_rebuild()
				_finish_stroke()
			accept_event()
	elif event is InputEventMouseMotion:
		if _panning: _pan += event.relative
		_hover = _cell(event.position)
		if _painting and tool not in ["rect", "port"]: _paint(_hover)
		queue_redraw()


func _strip(texture: Texture2D, area: Rect2) -> void:
	if texture == null: return
	var at := 0.0
	while at < area.size.x:
		var width := minf(float(texture.get_width()), area.size.x - at)
		draw_texture_rect_region(texture, Rect2(area.position + Vector2(at, 0), Vector2(width, area.size.y)), Rect2(0, 0, width, texture.get_height()))
		at += width


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("11131b"))
	if room.is_empty(): return
	draw_set_transform(_pan, 0.0, Vector2.ONE * _scale)
	var extent := Vector2(float(room.width), float(room.height)) * CELL
	draw_rect(Rect2(Vector2.ZERO, extent), Color("191b25"))
	for p: Vector2i in _floor:
		var tile: Texture2D = _texture("floor_%02d" % ((p.x * 7 + p.y * 3) % 5))
		if tile != null: draw_texture_rect(tile, Rect2(Vector2(p) * CELL, Vector2.ONE * CELL), false)
	for strip: Dictionary in _walls.get("north", []):
		draw_rect(Rect2(strip.x0, strip.y + 74.0, strip.x1 - strip.x0, 32.0), Color(0, 0, 0, 0.3))
		_strip(_texture("wall_h"), Rect2(strip.x0, strip.y, strip.x1 - strip.x0, 74.0))
	for side: Dictionary in _walls.get("side", []):
		if side.glow: continue
		var texture: Texture2D = _texture("wall_v")
		if texture != null: draw_texture_rect(texture, Rect2(side.x, side.y0, 62.0, side.y1 - side.y0), true)
	for strip: Dictionary in _walls.get("south", []): _strip(_texture("wall_h"), Rect2(strip.x0, strip.y, strip.x1 - strip.x0, 74.0))
	var cap: Texture2D = _texture("corner_cap")
	if cap != null:
		for p: Vector2 in _walls.get("caps", []): draw_texture(cap, p - cap.get_size() * 0.5)
	var props: Array = room.get("props", []).duplicate()
	props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.y) < float(b.y))
	for p: Dictionary in props:
		var texture: Texture2D = _texture(str(p.name))
		if texture != null: draw_texture(texture, (Vector2(float(p.x) + 0.5, float(p.y) + 0.5) * CELL) - Vector2(texture.get_width() * 0.5, texture.get_height()))
	if grid_on:
		for x in range(int(room.width) + 1): draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, extent.y), Color(0.7, 0.8, 1, 0.16), 1.0 / _scale)
		for y in range(int(room.height) + 1): draw_line(Vector2(0, y * CELL), Vector2(extent.x, y * CELL), Color(0.7, 0.8, 1, 0.16), 1.0 / _scale)
	for p: Dictionary in room.get("ports", []):
		var rect := Rect2(Vector2(p.cell[0], p.cell[1]) * CELL, Vector2(CELL, CELL * 2) if str(p.side) in ["east", "west"] else Vector2(CELL * 2, CELL))
		draw_rect(rect, Color(0.95, 0.7, 0.25, 0.45))
		draw_rect(rect, Color("edbf75"), false, 3.0 / _scale)
	for p: Array in room.get("enemy_spawns", []):
		var at := (Vector2(p[0], p[1]) + Vector2.ONE * 0.5) * CELL
		draw_circle(at, 19, Color("da4e38"))
		draw_line(at - Vector2(10, 10), at + Vector2(10, 10), Color.WHITE, 2.0 / _scale)
		draw_line(at + Vector2(-10, 10), at + Vector2(10, -10), Color.WHITE, 2.0 / _scale)
	if _inside(_hover): draw_rect(Rect2(Vector2(_hover) * CELL, Vector2.ONE * CELL), Color("edbf75"), false, 2.0 / _scale)
	if _painting and tool == "rect":
		var lo := Vector2i(mini(_start.x, _hover.x), mini(_start.y, _hover.y))
		var hi := Vector2i(maxi(_start.x, _hover.x), maxi(_start.y, _hover.y))
		draw_rect(Rect2(Vector2(lo) * CELL, Vector2(hi - lo + Vector2i.ONE) * CELL), Color(0.8, 0.6, 0.2, 0.3))
	draw_set_transform(Vector2.ZERO)
