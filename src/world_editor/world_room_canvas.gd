extends Control
## The Weltbauer's drawing surface: the room as the game draws it (walls from hell_walls.gd, liquid
## edges from pool_paint.gd, merged pits and areas from world_terrain.gd, moving fires), with painting,
## placing and moving. Everything changes the room dictionary and tells `changed`.

signal changed
## An object was selected ({} for none).
signal selected(object: Dictionary)
## The word under the mouse for the status line.
signal hover_text(text: String)

## The kind a click with the door spot tool sets: "", "in" or "out" (Data.PORT_USES).
var port_use := ""
## The colour of a door spot by its kind.
const PORT_TINTS := {"": Color("edbf75"), "in": Color("58d68d"), "out": Color("ec7063")}
## True once the hand has zoomed or moved the view: it then stays until EINPASSEN or another room.
var _view_moved := false
## The canvas's size the view was last laid out for.
var _last_size := Vector2.ZERO
## How far above its foot a wall picture hangs, as the game draws it (hell_game.gd wall_decor).
const WALL_DECOR_DROP := 74.0
const Data = preload("res://src/world_editor/world_room_data.gd")
const Walls = preload("res://src/hell/hell_walls.gd")
const PoolPaint = preload("res://src/vfx/pool_paint.gd")
const Terrain = preload("res://src/world_editor/world_terrain.gd")
const LaunchPads = preload("res://src/hell/launch_pads.gd")
const Monsters = preload("res://src/hell/hell_monsters.gd")
const Gates = preload("res://src/world_editor/world_gates.gd")
const Contents = preload("res://src/world_kit/room_contents.gd")
const FrostPuzzles = preload("res://src/world_kit/frost_puzzles.gd")
const RoomWeather = preload("res://src/world_kit/room_weather.gd")
const CELL := 96.0
const SNAP := 24.0
const CELL_KINDS := ["launch", "plate", "spikes", "vent"]
const TERRAIN := {"floor": Data.FLOOR, "wall": Data.WALL, "liquid": Data.LIQUID, "bridge": Data.BRIDGE, "pit": Data.PIT}
const UNDO_LIMIT := 80
## How far a gate's front picture stands below its cells (as the game's boss gate).
const GATE_FOOT := 8.0

var room: Dictionary = {}
var art: RefCounted
## "select", a TERRAIN word, "area", "tile", "place", "port" or "erase".
var tool: String = "select"
## What "place" sets, "area" and "tile" paint: a parts-list entry.
var brush: Dictionary = {}
var brush_size: int = 1
var grid_on: bool = true
var feet_on: bool = true
var catalog: RefCounted
var picked: Dictionary = {}
var time: float = 0.0
## The room's weather drawn over it (room_weather.gd draw_preview).
var weather_on := true
var _weather: RefCounted = RoomWeather.new()

var _world := Node2D.new()
var _ground := Node2D.new()
var _things := Node2D.new()
var _front := Node2D.new()
var _marks := Node2D.new()
var _walls: Dictionary = {}
var _crust: Dictionary = {}
## The cells the gates open in the walls (world_gates.gd), the same ones the game opens.
var _dug: Dictionary = {}
var _undo: Array = []
var _redo: Array = []
var _hover := Vector2.ZERO
var _rect_start := Vector2i(-1, -1)
var _painting := false
var _erasing := false
var _panning := false
var _dragging := false
var _drag_off := Vector2.ZERO
var _stroke_changed := false
var _clock := 0.0


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	add_child(_world)
	for layer: Node2D in [_ground, _things, _front, _marks]:
		_world.add_child(layer)
	_ground.draw.connect(_draw_ground)
	_things.draw.connect(_draw_things)
	_front.draw.connect(_draw_front)
	_marks.draw.connect(_draw_marks)
	resized.connect(_on_resized)
	mouse_exited.connect(func() -> void: _marks.queue_redraw())


func _process(delta: float) -> void:
	time += delta
	if art != null and art.flush(24) > 0:
		_ground.queue_redraw()
	_clock += delta
	if _clock >= 1.0 / 15.0:
		_clock = 0.0
		_things.queue_redraw()
		_marks.queue_redraw()


## Shows `value` drawn with `pictures`; forgets the undo steps of the room before.
func show_room(value: Dictionary, pictures: RefCounted) -> void:
	room = value
	art = pictures
	_undo.clear()
	_redo.clear()
	picked = {}
	selected.emit(picked)
	texture_filter = TEXTURE_FILTER_NEAREST if bool(art.theme.get("pixel", true)) else TEXTURE_FILTER_LINEAR
	refresh()
	fit()


## The room's whole picture again after a change.
func refresh() -> void:
	if room.is_empty():
		return
	var w := int(room.width)
	var h := int(room.height)
	_dug = Gates.dug(room)
	var grid := PackedByteArray()
	grid.resize(w * h)
	for y in range(h):
		for x in range(w):
			grid[y * w + x] = _terrain_at(x, y)
	_walls = Walls.build(grid, w, h, CELL, Gates.doorways(room))
	_crust = {}
	if PoolPaint.crusts(str(art.theme.get("sprites", ""))):
		_crust = PoolPaint.lava_rim(_terrain_at, 0, 0, w, h, CELL, 3.0)
	_ground.queue_redraw()
	_front.queue_redraw()
	_things.queue_redraw()
	_marks.queue_redraw()


func _terrain_at(x: int, y: int) -> int:
	match _shown_cell(x, y):
		Data.FLOOR, Data.PIT: return 1
		Data.LIQUID: return 2
		Data.BRIDGE: return 3
	return 0


## A cell as it shows: what a gate digs is floor.
func _shown_cell(x: int, y: int) -> String:
	return Data.FLOOR if _dug.has(Vector2i(x, y)) else Data.cell_at(room, x, y)


## The canvas changed its size, as when the side panel shows other settings: a view the hand has moved
## stays as it is, with the same spot in the middle; an untouched one fits the new size.
func _on_resized() -> void:
	if _view_moved:
		_world.position += (size - _last_size) * 0.5
	else:
		fit()
	_last_size = size


## Fits the room into the view.
func fit() -> void:
	_view_moved = false
	_last_size = size
	if room.is_empty() or size.x < 2.0:
		return
	var extent := Vector2(float(room.width), float(room.height)) * CELL
	var s := clampf(minf((size.x - 40.0) / extent.x, (size.y - 40.0) / extent.y), 0.08, 2.0)
	_world.scale = Vector2.ONE * s
	_world.position = ((size - extent * s) * 0.5).round()


## A step back / forward.
func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_snapshot())
	_restore(_undo.pop_back())


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_snapshot())
	_restore(_redo.pop_back())


func _snapshot() -> Dictionary:
	return room.duplicate(true)


func _restore(value: Dictionary) -> void:
	room.clear()
	room.merge(value, true)
	picked = {}
	selected.emit(picked)
	refresh()
	changed.emit()


## Call before a change that should be one undo step.
func checkpoint() -> void:
	_undo.append(_snapshot())
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()


## The selected object goes (Entf).
func delete_picked() -> void:
	if picked.is_empty():
		return
	checkpoint()
	(room.objects as Array).erase(picked)
	picked = {}
	selected.emit(picked)
	refresh()
	changed.emit()


## A copy of the selected object beside it.
func duplicate_picked() -> void:
	if picked.is_empty():
		return
	checkpoint()
	var copy: Dictionary = picked.duplicate(true)
	copy.x = float(copy.x) + CELL * 0.5
	(room.objects as Array).append(copy)
	picked = copy
	selected.emit(picked)
	refresh()
	changed.emit()


func _to_room(at: Vector2) -> Vector2:
	return (at - _world.position) / _world.scale.x


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i((p / CELL).floor())


## Where a piece lands for a click at `p`: game pieces on the middle of a cell, others on the small
## grid, free with Alt.
func _placed_at(p: Vector2, kind: String) -> Vector2:
	var cell := _cell_of(p)
	if kind in CELL_KINDS or FrostPuzzles.KINDS.has(kind):
		return (Vector2(cell) + Vector2.ONE * 0.5) * CELL
	if kind in ["gate", "secret"]:
		var at := Gates.spot(room, p)
		return Vector2(float(at.x), float(at.y))
	if Input.is_key_pressed(KEY_ALT):
		return p.round()
	return (p / SNAP).round() * SNAP


func _gui_input(event: InputEvent) -> void:
	if room.is_empty():
		return
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and b.pressed:
			var factor := 1.15 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			var old := _world.scale.x
			var s := clampf(old * factor, 0.08, 3.0)
			_world.scale = Vector2.ONE * s
			_world.position = b.position - (b.position - _world.position) * (s / old)
			_view_moved = true
			accept_event()
		elif b.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = b.pressed
			accept_event()
		elif b.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			grab_focus()
			if b.pressed:
				_press(_to_room(b.position), b.button_index == MOUSE_BUTTON_RIGHT, b.shift_pressed)
			else:
				_release(_to_room(b.position))
			accept_event()
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if _panning or Input.is_key_pressed(KEY_SPACE) and m.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_world.position += m.relative
			_view_moved = true
		_hover = _to_room(m.position)
		var c := _cell_of(_hover)
		hover_text.emit("Feld %d, %d" % [c.x, c.y])
		if _dragging and not picked.is_empty():
			if str(picked.kind) in ["gate", "secret"]:
				_move_gate(_hover)
			else:
				var at := _placed_at(_hover + _drag_off, str(picked.kind))
				if at != Vector2(float(picked.x), float(picked.y)):
					picked.x = at.x
					picked.y = at.y
					_stroke_changed = true
					_things.queue_redraw()
		elif _painting and _rect_start.x < 0:
			_paint(c)
		_marks.queue_redraw()


## A gate being dragged goes to the wall under the mouse and takes that wall's lie.
func _move_gate(p: Vector2) -> void:
	var at := Gates.spot(room, p, picked)
	if bool(at.ok) and (float(at.x) != float(picked.x) or float(at.y) != float(picked.y) or str(at.dir) != str(picked.get("dir", "v"))):
		picked.x = at.x
		picked.y = at.y
		picked.dir = at.dir
		_stroke_changed = true
		refresh()


func _press(p: Vector2, right: bool, shift: bool) -> void:
	if Input.is_key_pressed(KEY_SPACE):
		return
	var cell := _cell_of(p)
	_erasing = right
	match tool:
		"select":
			if right:
				_delete_at(p)
				return
			var hit := _object_at(p)
			picked = hit
			selected.emit(picked)
			if not hit.is_empty():
				checkpoint()
				_dragging = true
				_stroke_changed = false
				_drag_off = Vector2(float(hit.x), float(hit.y)) - p
			_marks.queue_redraw()
		"place":
			if right:
				_delete_at(p)
			else:
				_place(p)
		"erase":
			_delete_at(p)
		"port":
			_toggle_port(cell)
		_:
			checkpoint()
			_painting = true
			_stroke_changed = false
			if shift:
				_rect_start = cell
			else:
				_rect_start = Vector2i(-1, -1)
				_paint(cell)


func _release(p: Vector2) -> void:
	if _dragging:
		_dragging = false
		if _stroke_changed:
			changed.emit()
		elif not _undo.is_empty():
			_undo.pop_back()
	if _painting:
		_painting = false
		if _rect_start.x >= 0:
			var end := _cell_of(p)
			for y in range(mini(_rect_start.y, end.y), maxi(_rect_start.y, end.y) + 1):
				for x in range(mini(_rect_start.x, end.x), maxi(_rect_start.x, end.x) + 1):
					_paint_one(Vector2i(x, y))
			_rect_start = Vector2i(-1, -1)
			refresh()
		if _stroke_changed:
			changed.emit()
		elif not _undo.is_empty():
			_undo.pop_back()


## One brush touch: the brush's square of cells.
func _paint(c: Vector2i) -> void:
	var before := _stroke_changed
	var half := (brush_size - 1) / 2
	for y in range(c.y - half, c.y - half + brush_size):
		for x in range(c.x - half, c.x - half + brush_size):
			_paint_one(Vector2i(x, y))
	if _stroke_changed and not before or _stroke_changed:
		refresh()


func _paint_one(c: Vector2i) -> void:
	if c.x < 0 or c.y < 0 or c.x >= int(room.width) or c.y >= int(room.height):
		return
	var spot := "%d,%d" % [c.x, c.y]
	match tool:
		"area":
			if _erasing:
				if (room.areas as Dictionary).has(spot):
					room.areas.erase(spot)
					_stroke_changed = true
			elif str((room.areas as Dictionary).get(spot, "")) != str(brush.get("asset", "")):
				room.areas[spot] = str(brush.asset)
				_stroke_changed = true
		"tile":
			if _erasing:
				if (room.tiles as Dictionary).has(spot):
					room.tiles.erase(spot)
					_stroke_changed = true
			elif str((room.tiles as Dictionary).get(spot, "")) != str(brush.get("asset", "")):
				room.tiles[spot] = str(brush.asset)
				_stroke_changed = true
		_:
			var value: String = TERRAIN.get(tool, Data.FLOOR)
			if _erasing:
				# right button: floor back from liquid and pits, wall back from floor
				value = Data.WALL if tool == "floor" else Data.FLOOR
			if Data.set_cell(room, c.x, c.y, value):
				_stroke_changed = true


func _place(p: Vector2) -> void:
	var kind := str(brush.get("kind", "prop"))
	var gate_spot := {}
	if kind in ["gate", "secret"]:
		gate_spot = Gates.spot(room, p)
		if not bool(gate_spot.ok):
			hover_text.emit("Ein Tor braucht eine Mauer mit Boden davor: klicke auf eine Mauer.")
			return
	checkpoint()
	var at := _placed_at(p, kind)
	var o: Dictionary = {}
	if kind == "prop":
		var look: Texture2D = art.picture_now(str(brush.asset) if not brush.has("frames") else str((brush.frames as Array)[0]))
		o = catalog.new_prop(brush, look, not str(brush.asset).begins_with("@"))
	elif kind == "enemy":
		o = {"kind": "enemy", "mob": str(brush.mob)}
	else:
		o = {"kind": kind}
		o.merge(((brush.get("defaults", {}) as Dictionary).duplicate(true)), true)
		if kind == "plate":
			o.order = 0
	o.x = at.x
	o.y = at.y
	if not gate_spot.is_empty():
		o.dir = gate_spot.dir
	if kind == "start":
		for old: Dictionary in (room.objects as Array).duplicate():
			if str(old.kind) == "start":
				(room.objects as Array).erase(old)
	(room.objects as Array).append(o)
	picked = o
	selected.emit(picked)
	refresh()
	changed.emit()


func _delete_at(p: Vector2) -> void:
	var hit := _object_at(p)
	if hit.is_empty():
		return
	checkpoint()
	(room.objects as Array).erase(hit)
	if is_same(picked, hit):
		picked = {}
		selected.emit(picked)
	refresh()
	changed.emit()


## The door spots of the room's outer wall: a click sets one of the kind `port_use` (two cells wide), changes
## a spot of another kind to it, and takes away a spot of that kind.
func _toggle_port(c: Vector2i) -> void:
	checkpoint()
	var ports: Array = room.ports
	for port: Dictionary in ports:
		if Vector2i(int(port.cell[0]), int(port.cell[1])) == c:
			if str(port.get("use", "")) == port_use:
				ports.erase(port)
			elif port_use == "":
				port.erase("use")
			else:
				port.use = port_use
			refresh()
			changed.emit()
			return
	var w := int(room.width)
	var h := int(room.height)
	var dist := [c.y, w - 1 - c.x, h - 1 - c.y, c.x]
	var side: String = ["north", "east", "south", "west"][dist.find(dist.min())]
	# the wall faces the floor beside it: floor below means this is a north wall, whatever is nearest
	var open := func(x: int, y: int) -> bool: return Data.cell_at(room, x, y) != Data.WALL
	if open.call(c.x, c.y + 1):
		side = "north"
	elif open.call(c.x, c.y - 1):
		side = "south"
	elif open.call(c.x + 1, c.y):
		side = "west"
	elif open.call(c.x - 1, c.y):
		side = "east"
	var added := {"side": side, "cell": [c.x, c.y]}
	if port_use != "":
		added.use = port_use
	ports.append(added)
	refresh()
	changed.emit()


## The object whose picture lies under `p`, the front-most first.
func _object_at(p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_y := -INF
	for o: Dictionary in room.objects:
		if box_of(o).grow(4.0).has_point(p) and float(o.y) >= best_y:
			best = o
			best_y = float(o.y)
	return best


## Where an object's picture lies in room px.
func box_of(o: Dictionary) -> Rect2:
	var x := float(o.x)
	var y := float(o.y)
	match str(o.kind):
		"prop":
			var t: Texture2D = art.picture_now(str(o.asset))
			return _picture_rect(o, t.get_size() if t != null else Vector2(48, 48))
		"launch", "plate", "spikes", "vent":
			return Rect2(x - 44.0, y - 44.0, 88.0, 88.0)
		_ when FrostPuzzles.FLAT.has(str(o.kind)):
			return Rect2(x - 44.0, y - 44.0, 88.0, 88.0)
		_ when FrostPuzzles.KINDS.has(str(o.kind)):
			return Rect2(x - 44.0, y - 70.0, 88.0, 110.0)
		"gate", "secret":
			var two := Gates.cells(o)
			return Rect2(Vector2(two[0]) * CELL, Vector2(two[1] - two[0] + Vector2i.ONE) * CELL)
		"start":
			return Rect2(x - 30.0, y - 80.0, 60.0, 84.0)
	return Rect2(x - 40.0, y - 70.0, 80.0, 74.0)


# ---------- drawing, the game's order ----------

func _strip(ci: CanvasItem, w: Dictionary) -> void:
	var t: Texture2D = art.tex.get("wall_h")
	if t == null:
		return
	var x := float(w.x0)
	while x < float(w.x1):
		var off := fmod(x - float(w.x0), t.get_width())
		var part := minf(t.get_width() - off, float(w.x1) - x)
		ci.draw_texture_rect_region(t, Rect2(x, float(w.y), part, t.get_height()), Rect2(off, 0, part, t.get_height()))
		x += part


func _draw_ground() -> void:
	var ci := _ground
	var tex: Dictionary = art.tex
	var w := int(room.width)
	var h := int(room.height)
	ci.draw_rect(Rect2(Vector2(-2, -2) * CELL, Vector2(w + 4, h + 4) * CELL), Color("0b0b10"))
	var outside := _outside_walls()
	var cfg := Terrain.config()
	var pit_look: Dictionary = cfg.pit.get(str(room.world), cfg.pit.krypta)
	var px := float(cfg.art_px)
	var one_to_one: bool = art.pixel_tiles
	for y in range(h):
		for x in range(w):
			var cell := _shown_cell(x, y)
			var at := Vector2(x, y) * CELL
			var r := Rect2(at, Vector2.ONE * (CELL + 0.5))
			if cell == Data.WALL:
				if not outside.has(Vector2i(x, y)):
					if tex.has("wall_top"):
						ci.draw_texture(tex.wall_top, at)
					elif tex.has("wall_v"):
						ci.draw_texture_rect(tex.wall_v, r, true, Color(0.75, 0.68, 0.7))
				continue
			# an ice lake (room ice_lake): its whole floor is the ice the game draws
			if cell == Data.LIQUID or cell == Data.BRIDGE or (cell == Data.FLOOR and bool(room.get("ice_lake", false))):
				var lt: Texture2D = tex.get("lava_01") if (x * 7 + y * 13) % 10 > 6 else tex.get("lava_00")
				if lt != null:
					if one_to_one:
						ci.draw_texture(lt, at)
					else:
						ci.draw_texture_rect_region(lt, r, Rect2(14, 14, 68, 68))
			else:
				var own := str((room.tiles as Dictionary).get("%d,%d" % [x, y], ""))
				var tile: Texture2D = art.picture(own) if own != "" else tex.get("floor_%02d" % ((x + 2) * 7 + (y + 2) * 3) if false else ["floor_00", "floor_01", "floor_02", "floor_03", "floor_04"][((x + 2) * 7 + (y + 2) * 3) % 5])
				if tile != null:
					ci.draw_texture(tile, at)
	if not PoolPaint.crusts(str(art.theme.get("sprites", ""))):
		var rim: Texture2D = tex.get("lava_edge_top")
		if rim != null:
			for y in range(h):
				for x in range(w):
					if _terrain_at(x, y) not in [2, 3]:
						continue
					for side: Array in [[Vector2i(0, -1), Vector2(x * CELL, y * CELL), 0.0], [Vector2i(0, 1), Vector2(x * CELL + CELL, y * CELL + CELL), PI], [Vector2i(-1, 0), Vector2(x * CELL, y * CELL + CELL), -PI / 2], [Vector2i(1, 0), Vector2(x * CELL + CELL, y * CELL), PI / 2]]:
						var n := _terrain_at(x + side[0].x, y + side[0].y)
						if n == 1 or n == 0:
							ci.draw_set_transform(side[1], side[2])
							if one_to_one:
								ci.draw_texture_rect_region(rim, Rect2(0, -18, CELL, 36), Rect2(0, 0, CELL, 36))
							else:
								ci.draw_texture_rect_region(rim, Rect2(-2, -18, 50, 36), Rect2(0, 0, 48, 36))
								ci.draw_texture_rect_region(rim, Rect2(46, -18, 52, 36), Rect2(6, 0, 48, 36))
							ci.draw_set_transform(Vector2.ZERO)
	elif _crust.has("tex"):
		ci.draw_texture_rect(_crust.tex, _crust.rect, false)
	for y in range(h):
		for x in range(w):
			var at := Vector2(x, y) * CELL
			var spot := "%d,%d" % [x, y]
			if (room.areas as Dictionary).has(spot):
				var name := str(room.areas[spot])
				var same := func(c: Vector2i) -> bool: return str((room.areas as Dictionary).get("%d,%d" % [c.x, c.y], "")) == name
				Terrain.draw_area(ci, art.picture(name), Vector2i(x, y), at, CELL, same, cfg.area, px)
			if Data.cell_at(room, x, y) == Data.PIT:
				var same_pit := func(c: Vector2i) -> bool: return Data.cell_at(room, c.x, c.y) == Data.PIT
				Terrain.draw_pit(ci, Vector2i(x, y), at, CELL, same_pit, pit_look, px)
	for strip: Dictionary in _walls.get("north", []):
		ci.draw_rect(Rect2(float(strip.x0), float(strip.y) + 74.0, float(strip.x1) - float(strip.x0), 40.0), Color(0, 0, 0, 0.35))
		_strip(ci, strip)
	var wv: Texture2D = tex.get("wall_v")
	for s: Dictionary in _walls.get("side", []):
		if bool(s.glow):
			var g: Texture2D = tex.get("wall_v_glow")
			if g != null:
				var at := Vector2(float(s.x) + 31.0 - g.get_width() / 2.0, float(s.y) - g.get_height() / 2.0)
				_sprite(ci, g, at, g.get_size(), bool(s.flip))
			continue
		if wv == null:
			continue
		var yy := float(s.y0)
		while yy < float(s.y1):
			var off := fmod(yy - float(s.y0), wv.get_height())
			var part := minf(wv.get_height() - off, float(s.y1) - yy)
			if bool(s.flip):
				ci.draw_set_transform(Vector2(float(s.x) + wv.get_width(), yy), 0.0, Vector2(-1, 1))
				ci.draw_texture_rect_region(wv, Rect2(0, 0, wv.get_width(), part), Rect2(0, off, wv.get_width(), part))
				ci.draw_set_transform(Vector2.ZERO)
			else:
				ci.draw_texture_rect_region(wv, Rect2(float(s.x), yy, wv.get_width(), part), Rect2(0, off, wv.get_width(), part))
			yy += part
	var post: Texture2D = tex.get("wall_h_glowpost")
	if post != null:
		for p: Vector2 in _walls.get("posts", []):
			ci.draw_texture(post, p - Vector2(post.get_width() / 2.0, post.get_height()))
	var cap: Texture2D = tex.get("corner_cap")
	if cap != null:
		for c: Vector2 in _walls.get("caps", []):
			ci.draw_texture(cap, c - Vector2(38, 38))


## The wall cells open to the outside (they stay dark; enclosed ones show the wall's top).
func _outside_walls() -> Dictionary:
	var w := int(room.width)
	var h := int(room.height)
	var out := {}
	var todo: Array = []
	for x in range(w):
		todo.append(Vector2i(x, 0))
		todo.append(Vector2i(x, h - 1))
	for y in range(h):
		todo.append(Vector2i(0, y))
		todo.append(Vector2i(w - 1, y))
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or out.has(c) or _shown_cell(c.x, c.y) != Data.WALL:
			continue
		out[c] = true
		todo.append(c + Vector2i.LEFT)
		todo.append(c + Vector2i.RIGHT)
		todo.append(c + Vector2i.UP)
		todo.append(c + Vector2i.DOWN)
	return out


func _sprite(ci: CanvasItem, t: Texture2D, at: Vector2, s: Vector2, flip: bool, tint := Color.WHITE) -> void:
	if flip:
		ci.draw_set_transform(at + Vector2(s.x, 0.0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(t, Rect2(Vector2.ZERO, s), false, tint)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect(t, Rect2(at, s), false, tint)


## Where a part's picture lies, as the game draws it: flat on the floor round its middle in its own size
## (carpets), on a wall hanging from its top, else standing on its foot; all stretched by Data.stretch.
func _picture_rect(o: Dictionary, natural: Vector2) -> Rect2:
	var x := float(o.x)
	var y := float(o.y)
	var s := natural
	if o.has("decal"):
		var d: Dictionary = o.decal
		if float(d.get("w", 0)) > 0.0:
			s = Vector2(float(d.w), float(d.h))
		s *= Data.stretch(o)
		return Rect2(x - s.x * 0.5, y - float(d.get("dy", 0.0)) - s.y * 0.5, s.x, s.y)
	s *= Data.stretch(o)
	if bool(o.get("wall_decor", false)):
		return Rect2(x - s.x * 0.5, y - WALL_DECOR_DROP, s.x, s.y)
	return Rect2(x - s.x * 0.5, y - s.y, s.x, s.y)


func _sort_key(o: Dictionary) -> float:
	match str(o.get("layer", "normal")):
		"floor": return float(o.y) - 1000000.0
		"front": return float(o.y) + 1000000.0
	if str(o.kind) in ["launch", "plate", "spikes", "vent"] or FrostPuzzles.FLAT.has(str(o.kind)):
		return float(o.y) - 500000.0
	if str(o.kind) == "gate":
		return box_of(o).end.y
	return float(o.y)


func _draw_things() -> void:
	if room.is_empty():
		return
	var ci := _things
	var list: Array = (room.objects as Array).duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _sort_key(a) < _sort_key(b))
	var cfg := Terrain.config()
	for o: Dictionary in list:
		_draw_object(ci, o, cfg)


func _draw_object(ci: CanvasItem, o: Dictionary, cfg: Dictionary) -> void:
	var x := float(o.x)
	var y := float(o.y)
	var tex: Dictionary = art.tex
	match str(o.kind):
		"prop":
			var name := str(o.asset)
			if o.has("frames"):
				name = str((o.frames as Array)[int(time * float(o.get("fps", 8.0)) + x * 0.013) % (o.frames as Array).size()])
			var t: Texture2D = art.moving(name, Vector2(x, y), time)
			if t == null:
				ci.draw_rect(Rect2(x - 20, y - 40, 40, 40), Color(1, 0, 1, 0.5))
				return
			var r := _picture_rect(o, t.get_size())
			_sprite(ci, t, r.position, r.size, bool(o.get("flip", false)) and not o.has("decal"))
		"launch":
			Terrain.draw_pad(ci, Vector2(x, y), str(o.get("dir", "n")), time, 0.0, tex.get("rune_plate"), cfg.pad)
		"plate":
			var t: Texture2D = tex.get("rune_plate")
			if t != null:
				ci.draw_texture(t, Vector2(x, y) - t.get_size() * 0.5)
		"spikes":
			var t: Texture2D = tex.get("spike_trap")
			if t != null:
				ci.draw_texture(t, Vector2(x, y) - t.get_size() * 0.5)
		"vent":
			var t: Texture2D = tex.get("vent", tex.get("ice_crack"))
			if t != null:
				ci.draw_texture(t, Vector2(x, y) - t.get_size() * 0.5)
		"gate":
			_draw_gate(ci, o, Color.WHITE)
		"secret":
			pass
		"start":
			_draw_hero_mark(ci, x, y)
		"enemy":
			_draw_enemy(ci, o)
		"raw":
			_foot_picture(ci, tex.get(_raw_picture(o)), x, y)
		_ when FrostPuzzles.FLAT.has(str(o.kind)):
			FrostPuzzles.draw_flat(ci, str(o.kind), o, Vector2(x, y), time, tex)
		_ when FrostPuzzles.KINDS.has(str(o.kind)):
			FrostPuzzles.draw_standing(ci, str(o.kind), o, Vector2(x, y), time, tex)
		_:
			var name := str(_PICTURES.get(str(o.kind), ""))
			_foot_picture(ci, art.moving(name, Vector2(x, y), time), x, y)


## A gate as the game draws it: a side view round its middle, a front view on its foot.
func _draw_gate(ci: CanvasItem, o: Dictionary, tint: Color) -> void:
	var side := str(o.get("dir", "v")) == "h"
	var t: Texture2D = art.picture(Gates.picture(o, side))
	if t == null:
		return
	var m := _door_middle(o)
	if side:
		_sprite(ci, t, m + Vector2(Gates.side_shift(room, o), 0.0) - t.get_size() * 0.5, t.get_size(), false, tint)
	else:
		var s: Vector2 = t.get_size() * float(Gates.style_of(o).get("scale", 1.0))
		_sprite(ci, t, Vector2(m.x - s.x * 0.5, m.y + CELL * 0.5 + GATE_FOOT - s.y), s, false, tint)


## The marks of a chest that bites and of a piece that lets out enemies.
const ENEMY_MARK := Color("e0584a")
const _PICTURES := {"tablet": "obelisk", "lever": "torch_dead", "brazier": "brazier_bowl", "skullheap": "skull_pile", "chest": "chest_closed", "key": "key", "heart": "heart", "gem": "rune_gem", "well": "fountain", "portal": "portal"}


func _raw_picture(o: Dictionary) -> String:
	match str((o.ent as Dictionary).get("type", "")):
		"shop": return "shop_table"
		"vault": return "chest_gold"
		"seal": return "seal"
		"crate": return str((o.ent as Dictionary).get("look", "crate_a"))
		"npc": return "npc_idle_f0"
		"stairs": return "stairs_down"
	return ""


func _foot_picture(ci: CanvasItem, t: Texture2D, x: float, y: float) -> void:
	if t != null:
		ci.draw_texture(t, Vector2(x - t.get_width() * 0.5, y - t.get_height()))
	else:
		ci.draw_rect(Rect2(x - 20, y - 40, 40, 40), Color(0.6, 0.6, 0.7, 0.6))


func _draw_hero_mark(ci: CanvasItem, x: float, y: float) -> void:
	var f := int(time * 6.0) % 4
	var t: Texture2D = art.picture("@res://assets/sprites/0x72/knight_m_idle_anim_f%d.png" % f)
	ci.draw_arc(Vector2(x, y - 2.0), 34.0, 0.0, TAU, 28, Color("7fe08a"), 3.0)
	if t != null:
		var s := t.get_size() * 3.0
		ci.draw_texture_rect(t, Rect2(x - s.x * 0.5, y - s.y + 6.0, s.x, s.y), false)


func _draw_enemy(ci: CanvasItem, o: Dictionary) -> void:
	var x := float(o.x)
	var y := float(o.y)
	# it waits as a chest in the game, and so it does here
	if Contents.is_chest_mob(str(o.get("mob", ""))):
		_foot_picture(ci, art.picture("chest_closed"), x, y)
		return
	var look: Dictionary = enemy_look(str(o.get("mob", "")))
	ci.draw_arc(Vector2(x, y - 2.0), 34.0, 0.0, TAU, 28, Color("e0584a"), 3.0)
	if look.has("frames"):
		var name := str((look.frames as Array)[int(time * 6.0) % (look.frames as Array).size()])
		var t: Texture2D = art.picture(name)
		if t != null:
			var s: Vector2 = t.get_size() * float(look.scale)
			ci.draw_texture_rect(t, Rect2(x - s.x * 0.5, y - s.y, s.x, s.y), false)
	elif look.has("sheet"):
		var t: Texture2D = art.picture(str(look.sheet))
		if t == null:
			return
		var w := float(look.w)
		var h := float(look.h)
		var s := float(look.scale)
		var f := int(time * 6.0) % int(look.count)
		var px := float(look.get("px", 1.0))
		ci.draw_texture_rect_region(t, Rect2(x - w * s * 0.5, y - h * s, w * s, h * s), Rect2(f * w * px, 0.0, w * px, h * px))
	else:
		ci.draw_circle(Vector2(x, y - 30.0), 22.0, Color("a33a30"))


## What a monster kind looks like: pictures of the world's set or a sheet ({} when unknown).
func enemy_look(mob: String) -> Dictionary:
	return enemy_look_in(art, mob)


static func enemy_look_in(pictures: RefCounted, mob: String) -> Dictionary:
	var theme: Dictionary = pictures.theme
	if theme.has("mobs") and (theme.mobs as Dictionary).has(mob):
		var def: Dictionary = theme.mobs[mob]
		var frames: Array = []
		var first := "%s_f0" % str(def.get("sprite", mob))
		for k in range(int(def.get("frames", 1))):
			frames.append("%s_f%d" % [str(def.get("sprite", mob)), k])
		if pictures.tex.has(first):
			return {"frames": frames, "scale": float(def.get("scale", 1.0))}
		if pictures.tex.has(str(def.get("sprite", mob))):
			return {"frames": [str(def.get("sprite", mob))], "scale": float(def.get("scale", 1.0))}
		return {}
	var balance: Dictionary = DataCache.load_dict(str(theme.get("balance", "")))
	var section: Dictionary = balance.get("monsters", {})
	var data: Dictionary = DataCache.load_dict(str(section.get("data", Monsters.DATA_PATH)))
	var def: Dictionary = (data.get("defs", {}) as Dictionary).get(mob, {})
	if def.is_empty():
		return {}
	var dir := str(section.get("sprites", Monsters.SPRITE_DIR))
	var path := dir + mob + ".png"
	if not ResourceLoader.exists(path):
		return {}
	return {"sheet": "@" + path, "w": float(def.w), "h": float(def.h), "scale": float(def.get("scale", 1.0)), "px": float(def.get("px", 1.0)), "count": int(((def.get("anims", {}) as Dictionary).get("idle", {}) as Dictionary).get("frames", 1))}


func _door_middle(o: Dictionary) -> Vector2:
	var c := Vector2(float(o.x), float(o.y))
	var cell := (c / CELL).floor()
	if str(o.get("dir", "v")) == "h":
		return (cell + Vector2(0.5, 1.0)) * CELL
	return (cell + Vector2(1.0, 0.5)) * CELL


func _draw_front() -> void:
	if room.is_empty():
		return
	for strip: Dictionary in _walls.get("south", []):
		_strip(_front, strip)


## Grid, feet, door spots, throws and the selection over everything; tools only, never in the game.
func _draw_marks() -> void:
	if room.is_empty():
		return
	var ci := _marks
	var line := 1.0 / _world.scale.x
	var w := int(room.width)
	var h := int(room.height)
	if weather_on:
		_weather.draw_preview(ci, Rect2(0, 0, w * CELL, h * CELL), room, 1.0 / 15.0)
	_draw_frost_light(ci)
	if grid_on:
		for x in range(w + 1):
			ci.draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, h * CELL), Color(0.7, 0.85, 1, 0.13), line)
		for y in range(h + 1):
			ci.draw_line(Vector2(0, y * CELL), Vector2(w * CELL, y * CELL), Color(0.7, 0.85, 1, 0.13), line)
	for o: Dictionary in room.objects:
		var kind := str(o.kind)
		if kind == "launch":
			_draw_throw(ci, o, line)
			# a sleeping pad shows the group that wakes it
			if str(o.get("wake", "")) != "":
				_draw_group_tag(ci, o, line, str(o.wake))
		elif kind in ["gate", "secret", "plate", "lever", "brazier", "skullheap"] or str(o.get("opens", "")) != "" or (FrostPuzzles.KINDS.has(kind) and str(o.get("group", "")) != ""):
			_draw_group_tag(ci, o, line)
		elif kind == "prop" and feet_on and bool(o.get("block", false)):
			var foot: Array = o.get("foot", [60, 30])
			ci.draw_rect(Rect2(float(o.x) - float(foot[0]) * 0.5, float(o.y) - float(foot[1]), float(foot[0]), float(foot[1])), Color(1, 0.3, 0.25, 0.8), false, 2.0 * line)
		if kind == "secret":
			var m := _door_middle(o)
			var size2 := Vector2(CELL * 2.0, CELL) if str(o.get("dir", "v")) == "v" else Vector2(CELL, CELL * 2.0)
			ci.draw_rect(Rect2(m - size2 * 0.5, size2), Color(0.7, 0.4, 1.0, 0.3))
			ci.draw_rect(Rect2(m - size2 * 0.5, size2), Color(0.8, 0.55, 1.0, 0.9), false, 2.0 * line)
		if (o.has("loot") and kind == "prop"):
			ci.draw_circle(Vector2(float(o.x), float(o.y) + 6.0), 7.0 * line + 4.0, Color(1, 0.85, 0.3, 0.95))
		if o.has("enemies") or (o.get("ent") is Dictionary and (o.ent as Dictionary).has("enemies")):
			ci.draw_circle(Vector2(float(o.x) + 16.0, float(o.y) + 6.0), 7.0 * line + 4.0, ENEMY_MARK)
		var bites := (kind == "enemy" and Contents.is_chest_mob(str(o.get("mob", "")))) or (kind == "chest" and str(o.get("mimic", "no")) != "no")
		if bites:
			var unsure := kind == "chest" and str(o.mimic) == "random"
			ci.draw_arc(Vector2(float(o.x), float(o.y) - 2.0), 40.0, 0.0, TAU, 28, ENEMY_MARK, 3.0 * line)
			ci.draw_string(ThemeDB.fallback_font, Vector2(float(o.x) - 24.0, float(o.y) - 44.0), "M?" if unsure else "M", HORIZONTAL_ALIGNMENT_CENTER, 48.0, 22, ENEMY_MARK)
	for port: Dictionary in room.ports:
		var along := Vector2(1, 2) if str(port.get("side", "")) in ["east", "west"] else Vector2(2, 1)
		var r := Rect2(Vector2(float(port.cell[0]), float(port.cell[1])) * CELL, along * CELL)
		var use := str(port.get("use", ""))
		var tint: Color = PORT_TINTS.get(use, PORT_TINTS[""])
		ci.draw_rect(r, Color(tint, 0.4))
		ci.draw_rect(r, tint, false, 3.0 * line)
		if use != "":
			ci.draw_string(ThemeDB.fallback_font, r.get_center() + Vector2(-24.0, 8.0), "EIN" if use == "in" else "AUS", HORIZONTAL_ALIGNMENT_CENTER, 48.0, 22, Color.WHITE)
	if not picked.is_empty():
		ci.draw_rect(box_of(picked).grow(4.0), Color("ffe08a"), false, 2.0 * line)
	var c := _cell_of(_hover)
	if tool in TERRAIN or tool in ["area", "tile"]:
		var half := (brush_size - 1) / 2
		var r := Rect2(Vector2(c.x - half, c.y - half) * CELL, Vector2.ONE * brush_size * CELL)
		if _painting and _rect_start.x >= 0:
			var lo := Vector2i(mini(_rect_start.x, c.x), mini(_rect_start.y, c.y))
			var hi := Vector2i(maxi(_rect_start.x, c.x), maxi(_rect_start.y, c.y))
			r = Rect2(Vector2(lo) * CELL, Vector2(hi - lo + Vector2i.ONE) * CELL)
		ci.draw_rect(r, Color(1, 0.9, 0.5, 0.18))
		ci.draw_rect(r, Color("ffe08a"), false, 2.0 * line)
	elif tool == "place" and not brush.is_empty():
		var kind := str(brush.get("kind", "prop"))
		var at := _placed_at(_hover, kind)
		if kind in ["gate", "secret"]:
			_draw_gate_ghost(ci, kind, line)
		elif kind == "prop":
			var t: Texture2D = art.picture(str(brush.asset) if not brush.has("frames") else str((brush.frames as Array)[0]))
			if t != null:
				var s := t.get_size() * (float(catalog.cfg.small_scale) if str(brush.asset).begins_with("@") and maxf(t.get_width(), t.get_height()) <= float(catalog.cfg.small_art) else 1.0)
				ci.draw_texture_rect(t, Rect2(at.x - s.x * 0.5, at.y - s.y, s.x, s.y), false, Color(1, 1, 1, 0.65))
		else:
			ci.draw_circle(at, 10.0 * line + 6.0, Color(1, 0.9, 0.5, 0.75))


## Where a gate would land under the mouse: green on its two cells, already showing itself; red
## with no wall in reach.
func _draw_gate_ghost(ci: CanvasItem, kind: String, line: float) -> void:
	var at := Gates.spot(room, _hover)
	var color := Color("7fe08a") if bool(at.ok) else Color("f0574a")
	if not bool(at.ok):
		var cell := Rect2(Vector2(_cell_of(_hover)) * CELL, Vector2.ONE * CELL)
		ci.draw_rect(cell, Color(color, 0.25))
		ci.draw_rect(cell, color, false, 3.0 * line)
		return
	var ghost := {"kind": kind, "x": at.x, "y": at.y, "dir": at.dir, "style": (brush.get("defaults", {}) as Dictionary).get("style", Gates.DEFAULT_STYLE)}
	if (brush.get("defaults", {}) as Dictionary).has("set_folder"):
		ghost.set_folder = brush.defaults.set_folder
	var box := box_of(ghost)
	ci.draw_rect(box, Color(color, 0.3))
	if kind == "gate":
		_draw_gate(ci, ghost, Color(1, 1, 1, 0.75))
	ci.draw_rect(box, color, false, 3.0 * line)


## A pad's way: where it throws, green on floor, red into a wall.
func _draw_throw(ci: CanvasItem, o: Dictionary, line: float) -> void:
	var from := Vector2(float(o.x), float(o.y))
	var to := LaunchPads.target_of(from, str(o.get("dir", "n")), int(o.get("cells", 4)), CELL)
	var c := _cell_of(to)
	var good: bool = _shown_cell(c.x, c.y) in [Data.FLOOR, Data.BRIDGE]
	var color := Color("7fe08a") if good else Color("f0574a")
	var n := 18
	var last := from
	var height := 30.0 + 18.0 * float(o.get("cells", 4))
	for k in range(1, n + 1):
		var u := float(k) / n
		var p: Vector2 = from.lerp(to, u) - Vector2(0.0, LaunchPads.arc(u, height))
		if k % 2 == 0:
			ci.draw_line(last, p, color, 3.0 * line)
		last = p
	ci.draw_rect(Rect2(to - Vector2.ONE * 34.0, Vector2.ONE * 68.0), color, false, 3.0 * line)


## The aurora light of the room's sources as the game will run it, through the prisms as they are set.
func _draw_frost_light(ci: CanvasItem) -> void:
	var at := {}
	for o: Dictionary in room.objects:
		if FrostPuzzles.SOLID.has(str(o.kind)):
			at[FrostPuzzles.cell_of(o)] = o
	var what := func(c: Vector2i) -> String:
		var cell := Data.cell_at(room, c.x, c.y)
		if cell == Data.WALL:
			return "wall"
		var o: Variant = at.get(c)
		if o == null:
			return "free"
		match str(o.kind):
			"prism": return "prism%d" % int(o.get("turn", 0))
			"beam_seal": return "seal"
		return "stop"
	for o: Dictionary in room.objects:
		if str(o.kind) != "beam_source":
			continue
		var start := FrostPuzzles.cell_of(o)
		var res := FrostPuzzles.trace(start, FrostPuzzles.DIRS.get(str(o.get("dir", "e")), Vector2i(1, 0)), what)
		var from := FrostPuzzles.centre(start)
		for c: Vector2i in res.turns:
			FrostPuzzles.draw_beam(ci, from, FrostPuzzles.centre(c), time, {"width": 5.0})
			from = FrostPuzzles.centre(c)
		var tip := FrostPuzzles.centre(res.seal) if res.seal != null else FrostPuzzles.centre(res.end)
		FrostPuzzles.draw_beam(ci, from, tip, time, {"width": 5.0})


func _draw_group_tag(ci: CanvasItem, o: Dictionary, line: float, own := "") -> void:
	var group := own if own != "" else str(o.get("opens", o.get("group", "")))
	var at := box_of(o).get_center()
	var tag: Color = Color.from_hsv(fmod(float(group.unicode_at(0) if group != "" else 65) * 0.17, 1.0), 0.7, 1.0)
	ci.draw_circle(at, 14.0, Color(0, 0, 0, 0.7))
	ci.draw_arc(at, 14.0, 0.0, TAU, 20, tag, 2.0 * line + 1.0)
	var font := ThemeDB.fallback_font
	# the plates of the floor's riddle (group seq, world_editor.gd FLOOR_RIDDLE)
	var text := "ET" if group == "seq" else group
	if int(o.get("order", 0)) > 0:
		text += str(int(o.order))
	ci.draw_string(font, at + Vector2(-9.0, 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, 18.0, 16, tag)
