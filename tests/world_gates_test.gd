extends SceneTree
## The Weltbauer's gates: a gate digs its wall away in the editor just as in the game, finds its lie
## from the wall, every kind of gate has its pictures in every set, and the parts list sorts them as
## gates and everything else where it belongs. Usage:
##   godot --headless --path . --script res://tests/world_gates_test.gd
const Data = preload("res://src/world_editor/world_room_data.gd")
const Canvas = preload("res://src/world_editor/world_room_canvas.gd")
const Art = preload("res://src/world_editor/world_art.gd")
const Catalog = preload("res://src/world_editor/world_asset_catalog.gd")
const Gates = preload("res://src/world_editor/world_gates.gd")
const RoomWorld = preload("res://src/world_editor/world_room_world.gd")
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const C := 96.0
## A fixed room: 14 x 10 with walls round it.
const ROOM_SIZE := Vector2i(14, 10)

var _failed := 0
var _checked := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
		print("WORLD_GATES_FAIL: ", what)


func _run() -> void:
	await _test_gate_digs_the_wall_in_the_editor()
	_test_spot_takes_the_lie_from_the_wall()
	_test_thick_wall_is_dug_through()
	_test_every_style_has_its_pictures()
	_test_gate_pictures_are_gates()
	_test_sorting()
	_test_old_pieces_become_gates()
	await _test_game_digs_the_same()
	print("WORLD_GATES checked=%d failed=%d" % [_checked, _failed])
	print("WORLD_GATES_TEST_PASS" if _failed == 0 else "WORLD_GATES_TEST_FAILED %d" % _failed)
	quit(1 if _failed > 0 else 0)


func _new_canvas() -> Control:
	var canvas: Control = Canvas.new()
	canvas.size = Vector2(1000, 700)
	canvas.catalog = Catalog.new()
	root.add_child(canvas)
	canvas.show_room(Data.fresh("krypta", "Test", ROOM_SIZE), Art.new("krypta", "pixel"))
	await process_frame
	return canvas


func _click(canvas: Control, cell: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = canvas._world.position + cell * C * canvas._world.scale.x
	canvas._gui_input(e)
	e = e.duplicate()
	e.pressed = false
	canvas._gui_input(e)


## A gate in the top wall: the wall runs on straight with a gap of the gate's two cells and no bend
## round it. With nothing behind the wall nothing is dug. Taking the gate away closes the gap.
func _test_gate_digs_the_wall_in_the_editor() -> void:
	var canvas := await _new_canvas()
	var before: int = (canvas._walls.north as Array).size()
	canvas.tool = "place"
	canvas.brush = {"kind": "gate", "defaults": {"style": "boss_gate", "group": "A", "lock": ""}}
	_click(canvas, Vector2(6.0, 0.5))
	var gate: Dictionary = canvas.picked
	_check(str(gate.get("kind", "")) == "gate", "a click on the wall sets the gate")
	_check(str(gate.get("dir", "")) == "v", "in the top wall the way leads up and down")
	var two := Gates.cells(gate)
	var line := (two[0].y + 1) * C - 74.0
	var x0 := two[0].x * C
	var x1 := (two[1].x + 1) * C
	for strip: Dictionary in canvas._walls.north:
		_check(is_equal_approx(float(strip.y), line), "the top wall stays one straight line, %s" % str(strip))
		_check(float(strip.x1) <= x0 or float(strip.x0) >= x1, "no wall where the gate stands, %s" % str(strip))
	_check((canvas._walls.north as Array).size() == before + 1, "the wall runs on left and right of it")
	_check(canvas._terrain_at(two[0].x, two[0].y) == 0, "with nothing behind it the gate digs nothing")
	_check(Data.cell_at(canvas.room, two[0].x, two[0].y) == Data.WALL, "the painted wall stays in the file")
	canvas.delete_picked()
	_check((canvas._walls.north as Array).size() == before, "without the gate the wall is whole again")
	canvas.brush = {"kind": "gate", "defaults": {"style": "portcullis", "group": "A", "lock": ""}}
	_click(canvas, Vector2(0.5, 5.0))
	_check(str(canvas.picked.get("dir", "")) == "h", "in the left wall the way leads left and right")
	var count: int = (canvas.room.objects as Array).size()
	_click(canvas, Vector2(7.0, 5.0))
	_check((canvas.room.objects as Array).size() == count, "in the middle of the floor no gate is set")
	canvas.queue_free()
	await process_frame


func _test_spot_takes_the_lie_from_the_wall() -> void:
	var room := Data.fresh("krypta", "Test", ROOM_SIZE)
	var top := Gates.spot(room, Vector2(6.1, 0.4) * C)
	_check(bool(top.ok) and str(top.dir) == "v" and int(top.y) == 0, "top wall, %s" % str(top))
	var bottom := Gates.spot(room, Vector2(6.1, 9.6) * C)
	_check(bool(bottom.ok) and str(bottom.dir) == "v" and is_equal_approx(float(bottom.y), 9.0 * C), "bottom wall, %s" % str(bottom))
	var left := Gates.spot(room, Vector2(0.4, 5.0) * C)
	_check(bool(left.ok) and str(left.dir) == "h" and int(left.x) == 0, "left wall, %s" % str(left))
	var right := Gates.spot(room, Vector2(13.6, 5.0) * C)
	_check(bool(right.ok) and str(right.dir) == "h" and is_equal_approx(float(right.x), 13.0 * C), "right wall, %s" % str(right))
	_check(not bool(Gates.spot(room, Vector2(7.0, 5.0) * C).ok), "no wall in reach of the room's middle")
	# the slab lies in the wall column beside the room
	_check(Gates.side_shift(room, {"kind": "gate", "x": 0.0, "y": 4.0 * C, "dir": "h"}) > 0.0, "on the left wall towards the room")
	_check(Gates.side_shift(room, {"kind": "gate", "x": 13.0 * C, "y": 4.0 * C, "dir": "h"}) < 0.0, "on the right wall towards the room")


## A gate in a wall three cells thick digs through to the ground behind.
func _test_thick_wall_is_dug_through() -> void:
	var room := Data.fresh("krypta", "Test", ROOM_SIZE)
	for y in range(ROOM_SIZE.y):
		for x in range(6, 9):
			Data.set_cell(room, x, y, Data.WALL)
	room.objects.append({"kind": "gate", "x": 7.0 * C, "y": 4.0 * C, "dir": "h", "group": "A"})
	var dug := Gates.dug(room)
	for x in range(6, 9):
		_check(dug.has(Vector2i(x, 4)) and dug.has(Vector2i(x, 5)), "column %d is dug" % x)
	_check(dug.size() == 6, "and nothing more, %d" % dug.size())
	var outer := Data.fresh("krypta", "Test", ROOM_SIZE)
	outer.objects.append({"kind": "gate", "x": 5.0 * C, "y": 0.0, "dir": "v", "group": "A"})
	_check(Gates.dug(outer).is_empty(), "a gate in the outer wall leads nowhere and digs nothing")


## All kinds in all sets: nothing a gate draws may be missing.
func _test_every_style_has_its_pictures() -> void:
	var cfg := Gates.config()
	for name: String in [str(cfg.side_picture), str(cfg.open_side_picture)]:
		for set_def: Dictionary in cfg.sets:
			_check(ResourceLoader.exists(str(set_def.folder) + name + ".png"), "%s in %s" % [name, set_def.folder])
			var slab: Texture2D = load(str(set_def.folder) + name + ".png")
			_check(int(slab.get_height()) == 2 * int(C), "%s fits a doorway of two cells" % name)
	for id: String in cfg.styles:
		var style: Dictionary = cfg.styles[id]
		for key: String in ["front", "open_front"]:
			var name := str(style.get(key, ""))
			if name == "":
				continue
			if name.begins_with("@"):
				_check(ResourceLoader.exists(name.substr(1)), "%s %s: %s" % [id, key, name])
				continue
			for set_def: Dictionary in cfg.sets:
				_check(ResourceLoader.exists(str(set_def.folder) + name + ".png"), "%s %s in %s" % [id, key, set_def.folder])
	for set_def: Dictionary in cfg.sets:
		if FileAccess.file_exists(str(set_def.folder) + "manifest.json"):
			var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(set_def.folder) + "manifest.json"))
			_check(manifest.has("side_slab") and manifest.has("side_slab_open"), "%s's manifest loads the slab" % set_def.folder)
			_check(not manifest.has("side_portcullis"), "%s has no tilted gates any more" % set_def.folder)


## Boss gate, boss arch and lintel are gates in every world's list, not pieces.
func _test_gate_pictures_are_gates() -> void:
	var catalog := Catalog.new()
	for world: String in Data.WORLDS:
		var list := catalog.entries(world, Art.load_theme(world))
		for name: String in ["boss_gate", "boss_gate_blue", "boss_arch", "demon_lintel", "portcullis", "gate_side", "side_slab", "side_slab_open"]:
			var found := list.filter(func(e: Dictionary) -> bool: return str(e.asset) == name)
			_check(not found.is_empty(), "%s lists %s" % [world, name])
			if not found.is_empty():
				_check(str(found[0].kind) == "gate", "%s: %s is a gate, was %s" % [world, name, found[0].kind])
				_check(str(found[0].cat) == "Tore und Durchgänge", "%s: %s sorted as a gate, was %s" % [world, name, found[0].cat])


## Pictures whose names used to mislead: "arch" in archer, "ash" in slash, "pit" in spit, and every
## picture has a place.
func _test_sorting() -> void:
	var catalog := Catalog.new()
	var expected := {
		"skeleton_archer_idle_f0|sprites/crypt_enemies": "Figuren",
		"slash|sprites/fx": "Effekte",
		"bone_a|sprites/krypta": "Knochen und Gräber",
		"floor_00|sprites/krypta": "Boden und Flächen",
		"blood_a|sprites/krypta": "Bodendeko",
		"wall_h|sprites/krypta": "Mauern und Wandteile",
		"banner_1|sprites/krypta": "Wandschmuck",
		"torch_a|sprites/krypta": "Licht und Feuer",
		"barrel_a|sprites/krypta": "Truhen und Behälter",
		"table_a|sprites/krypta": "Möbel und Altäre",
		"rune_pillar_a|sprites/krypta": "Säulen, Statuen, Felsen",
		"spike_trap|sprites/krypta": "Fallen und Rätsel",
		"portal|sprites/krypta": "Treppen, Portale, Brunnen",
		"icon_door|sprites/krypta": "Symbole und Tafeln",
		"weapon_axe|sprites/0x72": "Gegenstände und Waffen",
		"knight_m_idle_anim_f0|sprites/0x72": "Figuren",
		"boss_atlas|actors/baked": "Übersichten und Quellen",
		"crypt_008|crypt/props": "Knochen und Gräber",
	}
	for key: String in expected:
		var part := key.split("|")
		_check(catalog.category_of(part[0], part[1]) == str(expected[key]), "%s was %s" % [key, catalog.category_of(part[0], part[1])])
	var unsorted: Array = []
	for path: String in catalog._files:
		var rel: String = path.get_base_dir().trim_prefix(Catalog.ROOT + "/")
		if catalog.category_of(path.get_file().get_basename(), rel) == Catalog.OTHER_CATEGORY:
			unsorted.append(path)
	for path: String in unsorted.slice(0, 40):
		print("WORLD_GATES_UNSORTED: ", path)
	_check(unsorted.is_empty(), "%d pictures have no category" % unsorted.size())


## A boss gate placed as a loose piece in an older room becomes a gate when the room loads.
func _test_old_pieces_become_gates() -> void:
	var room := Data.fresh("krypta", "Test", ROOM_SIZE)
	room.objects.append({"kind": "prop", "asset": "boss_gate", "x": 6.0 * C, "y": 1.0 * C})
	room.objects.append({"kind": "prop", "asset": "barrel_a", "x": 3.0 * C, "y": 3.0 * C})
	Gates.adopt_pieces(room)
	_check(str(room.objects[1].kind) == "gate" and str(room.objects[1].style) == "boss_gate", "the gate piece is a gate now")
	_check(str(room.objects[2].kind) == "prop", "a barrel stays a barrel")


## In the real game: the dug cells are open once the gate is, an open passage at once, and the picture
## the gate shows is loaded.
func _test_game_digs_the_same() -> void:
	var room := Data.fresh("krypta", "Test", ROOM_SIZE)
	# a wall through the room: gates in it lead on, those in the outer wall do not
	for x in range(ROOM_SIZE.x):
		Data.set_cell(room, x, 6, Data.WALL)
	room.objects[0].x = 3.5 * C
	room.objects[0].y = 3.5 * C
	room.objects.append({"kind": "gate", "style": "portcullis", "x": 0.0, "y": 2.0 * C, "dir": "h", "group": "A"})
	room.objects.append({"kind": "plate", "x": 3.5 * C, "y": 2.5 * C, "group": "A", "order": 0})
	room.objects.append({"kind": "gate", "style": "boss_arch", "x": 6.0 * C, "y": 6.0 * C, "dir": "v", "group": "B"})
	room.objects.append({"kind": "gate", "style": "wood_door", "x": 13.0 * C, "y": 2.0 * C, "dir": "h", "group": "A"})
	var raw: Dictionary = RoomWorld.new(room).build_raw(1, 77)
	var cols := int(raw.cols)
	var at := func(x: int, y: int) -> String: return str(raw.grid)[(y + RoomWorld.MARGIN) * cols + x + RoomWorld.MARGIN]
	var dug := Gates.dug(room)
	for c: Vector2i in dug:
		_check(at.call(c.x, c.y) == "1", "the game opens %s" % c)
	_check(dug.has(Vector2i(6, 6)) and dug.has(Vector2i(7, 6)) and dug.size() == 2, "only the gate with ground on both sides digs, %s" % str(dug))
	_check(at.call(5, 6) == "0", "beside the gate the wall stays")
	_check(at.call(0, 2) == "0", "a gate with nothing behind stays in its wall")
	_check((raw.doors as Array).size() == 2, "the closing gates are doors, %d" % (raw.doors as Array).size())
	_check((raw.passages as Array).size() == 1, "the arch is a passage")
	_check(not (raw.groups as Dictionary).has("B"), "an open passage needs no group")
	var game: Node = KryptaScene.instantiate()
	game.world_room = room
	game.custom_storage_root = "user://world_gates_test"
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game.tex.has("side_slab"), "the stone slab is loaded")
	_check(game.tex.has("@res://assets/sprites/0x72/doors_leaf_closed.png"), "the file gate too")
	_check((game.W.passages as Array).size() == 1, "the floor keeps its passages")
	var door: Dictionary = game.W.doors[0]
	_check(game._door_closed(door), "the gate is shut")
	var m := RoomWorld.MARGIN
	_check(game._cell_blocked(0 + m, 2 + m, false), "a shut gate blocks the way")
	_check(not game._cell_blocked(6 + m, 6 + m, false), "the hero walks through the open passage")
	_check(game._cell_blocked(5 + m, 6 + m, false), "the wall beside it still stands")
	var strips: Array = (game.walls.north as Array).filter(func(s: Dictionary) -> bool: return is_equal_approx(float(s.y), (6 + m + 1) * C - 74.0))
	_check(strips.size() == 2, "the game's wall has the same gap as the editor's, %d" % strips.size())
	_check(float(door.art_dx) > 0.0, "on the left wall the slab lies towards the room")
	_check(float(game.W.doors[1].art_dx) < 0.0, "on the right wall too")
	_check(str(door.pictures.side) == "side_slab", "a closing gate shows the shut slab from the side")
	_check(str(door.pictures.open_side) == "side_slab_open", "and the slid-open one when open")
	game.queue_free()
	await process_frame

