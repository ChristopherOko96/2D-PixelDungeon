extends SceneTree
## Captures the snow at the Frostgruft's walls from the real windowed game (src/hero/frost_wall_snow.gd,
## src/hero/frost_snow.gd): one fixed world run (the same floor every time, so before and after
## pictures show the same walls), the start room whole, then close-ups of a straight north wall, a
## left and a right side wall, an inner and an outer corner, a doorway and the stairs door. A close-up
## is the frame's centre cut out and enlarged 3x with nearest filtering (no smoothing).
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_wall_snow.gd -- <output_dir> [pixel|hd] [world_run] [bare]
## bare: the walls' snow switched off (seam and lip strength 0), for comparing the same spots without it.
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const GRAPHICS_FILE := "user://capture_frost_wall_snow.cfg"

var _out := "res://production/qa/evidence/frost-wall-snow/after-pixel"
var _graphics := "pixel"
var _run_no := 4242
var _bare := false
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_graphics = args[1]
	if args.size() > 2:
		_run_no = int(args[2])
	_bare = args.size() > 3 and args[3] == "bare"
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 0.0
			_game.state.hp = _game.state.max_hp
			_game.state.banner.t = 99.0
		await process_frame


func _calm() -> void:
	for r: Dictionary in _game.W.rooms:
		r.fight = false
		r.cleared = true
	_game.mobs = []


## Frames world point p: the hero stands a little below it, the camera settles on it.
func _look(p: Vector2) -> void:
	_game.player.x = p.x
	_game.player.y = p.y + 150.0
	_game.camera.position = p
	await _wait(4)
	_game.camera.position = p
	await _wait(2)


func _shot(name: String, at: Vector2, close := true) -> void:
	await _look(at)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])
	if close:
		var zoom: Vector2 = _game.camera.zoom
		var c: Vector2 = (at - _game.camera.get_screen_center_position()) * zoom + Vector2(image.get_width(), image.get_height()) / 2.0
		var r := Rect2i(Vector2i(c - Vector2(213, 120)), Vector2i(426, 240))
		r.position = r.position.clamp(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height()) - r.size)
		var crop := image.get_region(r)
		crop.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
		print("CAPTURED %s result=%d" % [name + "-nah", crop.save_png(_out.path_join(name + "-nah.png"))])


func _wall(x: int, y: int) -> bool:
	return x < 0 or y < 0 or x >= _game.W.cols or y >= _game.W.rows or _game._cell(x, y) == 0


## A snow cell away from fire bowls and thaw (their melted patches would hide the walls' snow).
func _floor(x: int, y: int) -> bool:
	if _wall(x, y) or not _game.frost_snow.snow.has(y * _game.W.cols + x):
		return false
	var at := Vector2((x + 0.5) * _game.C, (y + 0.5) * _game.C)
	for e: Dictionary in _game.W.ents:
		if e.type == "brazier" and at.distance_to(Vector2(e.x, e.y)) < 2.6 * _game.C:
			return false
	return true


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var cfg := ConfigFile.new()
	cfg.set_value("options", "graphics", _graphics)
	cfg.save(GRAPHICS_FILE)
	_game = FrostScene.instantiate()
	_game.class_id = "swordsman"
	_game.graphics_path = GRAPHICS_FILE
	root.add_child(_game)
	await _wait(10)
	_game.state.world_run = _run_no
	_game.load_floor(1, true)
	await _wait(20)
	_calm()
	if _bare and _game.frost_snow.get("walls") != null:
		_game.frost_snow.walls.cfg.lip = 0.0
		_game.frost_snow.walls.cfg.seam = 0.0
		for node: CanvasItem in _game._chunk_nodes:
			node.queue_redraw()
	var C: float = _game.C
	var start: Dictionary = _game._room_of_type("start")
	await _shot("01-startraum", Vector2((float(start.bx) + float(start.bw) / 2.0) * C, (float(start.by) + float(start.bh) / 2.0) * C), false)
	# the spots: the first of each kind, scanning the start room's neighbourhood first
	var spots := {}
	var cols: int = _game.W.cols
	var rows: int = _game.W.rows
	for y in range(1, rows - 1):
		for x in range(1, cols - 1):
			if not _floor(x, y):
				continue
			var at := Vector2(x * C, y * C)
			if not spots.has("02-gerade-nordwand") and _wall(x, y - 1) and range(-3, 4).all(func(k: int) -> bool: return _floor(x + k, y) and _wall(x + k, y - 1)):
				spots["02-gerade-nordwand"] = at + Vector2(C / 2.0, 0)
			if not spots.has("03-seitenwand-links") and _wall(x - 1, y) and range(-1, 3).all(func(k: int) -> bool: return _floor(x, y + k) and _wall(x - 1, y + k)):
				spots["03-seitenwand-links"] = at + Vector2(0, C / 2.0)
			if not spots.has("04-seitenwand-rechts") and _wall(x + 1, y) and range(-1, 3).all(func(k: int) -> bool: return _floor(x, y + k) and _wall(x + 1, y + k)):
				spots["04-seitenwand-rechts"] = at + Vector2(C, C / 2.0)
			if not spots.has("05-innenecke") and _wall(x, y - 1) and _wall(x - 1, y) and _floor(x + 1, y) and _floor(x, y + 1):
				spots["05-innenecke"] = at
			if not spots.has("06-aussenecke") and _wall(x - 1, y - 1) and _floor(x - 1, y) and _floor(x, y - 1):
				spots["06-aussenecke"] = at
	for d: Dictionary in _game.W.doors:
		if d.kind == "open" or d.kind == "lock":
			spots["07-tuer"] = Vector2(float(d.cx), float(d.cy))
			break
	for w: Dictionary in _game.W.wall_decor:
		if w.name == "door_stairs":
			spots["08-treppe"] = Vector2(float(w.x), float(w.y) + 90.0)
			break
	var names := spots.keys()
	names.sort()
	for n: String in names:
		print("SPOT %s %s" % [n, spots[n]])
		await _shot(n, spots[n])
	# The rejected version was most visible around these concrete object classes. Capture the real
	# generated instances as well so a visual review cannot pass on wall-only evidence.
	var wanted_props := {
		"skull_pile": "09-schaedelhaufen", "skull_heap": "09-schaedelhaufen",
		"coal_skulls": "09-schaedelhaufen", "rocks_a": "10-felshaufen", "rocks_dark": "10-felshaufen",
		"boulders": "10-felshaufen", "urn_a": "11-urne", "urn_b": "11-urne", "urn_c": "11-urne",
		"bone_a": "12-knochen", "bone_b": "12-knochen", "bone_c": "12-knochen"
	}
	var object_spots := {}
	for p: Dictionary in _game.W.props:
		var capture_name: String = str(wanted_props.get(str(p.name), ""))
		if capture_name != "" and not object_spots.has(capture_name):
			object_spots[capture_name] = Vector2(float(p.x), float(p.y))
	for e: Dictionary in _game.W.ents:
		if e.type == "brazier" and not object_spots.has("13-feuerschale"):
			object_spots["13-feuerschale"] = Vector2(float(e.x), float(e.y))
	for d: Dictionary in _game.W.decals:
		if str(d.name) in FRAMED_NAMES and not object_spots.has("14-bodenplatte"):
			object_spots["14-bodenplatte"] = Vector2(float(d.x), float(d.y))
	var object_names := object_spots.keys()
	object_names.sort()
	for n: String in object_names:
		print("OBJECT SPOT %s %s" % [n, object_spots[n]])
		await _shot(n, object_spots[n])
	quit(0)


const FRAMED_NAMES := ["rune_big", "rune_plate", "rune_small", "fire_plate", "demon_plate", "grate", "pit"]
