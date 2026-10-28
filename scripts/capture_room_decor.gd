extends SceneTree
## Captures the Dungeon-Werkstatt's decor library from the real windowed game:
## a hall decorated category by category (floor styles, carpets, wall pieces,
## furniture, light and odds and ends) with the placement ghost, then the
## decorated room test-played in the real game. Works on a copy of the room
## library (user://), so the shipped rooms stay untouched. Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_room_decor.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const COPY := "user://capture_decor_library.json"

var _out := "res://production/qa/evidence/dungeon-werkstatt"
var _game: Node
var _editor: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(2, int(_game.players[1].hp))
		await process_frame


func _shot(name: String) -> void:
	await _wait(3)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


func _place(id: String, cells: Array, variant: int = 0) -> void:
	for cell: Vector2i in cells:
		var problem: String = _editor.doc.place_decor(id, cell, variant)
		if not problem.is_empty(): print("PLACE %s at %s: %s" % [id, cell, problem])


## Moves the mouse over `cell` so the canvas shows the ghost there.
func _hover(cell: Vector2i) -> void:
	var canvas: Control = _editor._canvas
	var motion := InputEventMouseMotion.new()
	motion.position = canvas.offset + (Vector2(cell) * 32.0 + Vector2(16, 16)) * canvas.zoom
	canvas._gui_input(motion)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var file := FileAccess.open(COPY, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	file.close()
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	_game.main_menu.open_room_editor("")
	_editor = _game.main_menu.room_editor
	_editor.config_path = COPY
	_editor.open("")
	await _wait(10)
	# A hall with a side chamber.
	_editor.new_room()
	var doc = _editor.doc
	doc.begin_change()
	doc.fill_rect(Vector2i(1, 1), Vector2i(38, 24), false)
	doc.fill_rect(Vector2i(3, 5), Vector2i(36, 20), true)
	doc.set_marker("start", Vector2i(6, 12))
	for cell: Vector2i in [Vector2i(30, 8), Vector2i(31, 17), Vector2i(22, 18), Vector2i(26, 12)]: doc.set_marker("enemy", cell)
	doc.set_marker("chest", Vector2i(34, 6))
	doc.set_title("Bannerhalle")
	doc.set_auto_decor(false)
	# Floor styles and carpets.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	doc.paint_area_rect("floor_cracks", Vector2i(25, 15), Vector2i(31, 19), false, 0, true, rng)
	doc.paint_area("floor_moss", Vector2i(4, 18), 1, false)
	doc.paint_area("floor_dark", Vector2i(33, 18), 1, false, 0, true, rng)
	doc.paint_area_rect("floor_stones", Vector2i(12, 6), Vector2i(19, 8), false, 0, true, rng)
	doc.paint_area_rect("carpet_red", Vector2i(9, 11), Vector2i(31, 13), false)
	doc.paint_area_rect("carpet_red", Vector2i(19, 6), Vector2i(21, 10), false)
	doc.paint_area_rect("carpet_beige", Vector2i(13, 15), Vector2i(17, 18), false)
	_editor._after_change()
	_editor.select_tool("decor")
	_editor.show_category("boden")
	_editor.pick_decor("floor_cracks")
	await _wait(20)
	_hover(Vector2i(27, 17))
	await _shot("06-deko-boden")
	_editor.show_category("teppich")
	_editor.pick_decor("carpet_red")
	await _wait(10)
	_hover(Vector2i(20, 12))
	await _shot("07-deko-teppich")
	# Wall pieces on the north wall (row 4), clear of the gates.
	var gates: Array = doc.gate_spots()
	print("GATES %s" % str(gates))
	var free_wall: Array = []
	for x in range(3, 37):
		if doc.decor_problem("banner", Vector2i(x, 4)).is_empty(): free_wall.append(Vector2i(x, 4))
	print("FREE WALL %s" % str(free_wall))
	var wall_plan := ["banner", "wall_torch", "banner", "fountain_lava", "wall_sign", "banner", "wall_torch", "wall_grate", "banner", "fountain_water", "wall_ring", "wall_slime", "wall_torch", "banner", "wall_hole"]
	var step := maxi(1, free_wall.size() / wall_plan.size())
	for index in range(wall_plan.size()):
		if index * step >= free_wall.size(): break
		_place(str(wall_plan[index]), [free_wall[index * step]], index % 4)
	_editor._after_change()
	_editor.show_category("wand")
	_editor.pick_decor("banner", 1)
	await _wait(10)
	_hover(free_wall[free_wall.size() - 1] if not free_wall.is_empty() else Vector2i(20, 4))
	await _shot("08-deko-wand")
	# Furniture: columns along the carpet, crates and a cabinet in the corner.
	_place("column", [Vector2i(10, 9), Vector2i(16, 9), Vector2i(24, 9), Vector2i(30, 9), Vector2i(10, 15), Vector2i(24, 15)])
	_place("crate", [Vector2i(35, 19), Vector2i(34, 20), Vector2i(35, 20)])
	_place("cabinet", [Vector2i(3, 15), Vector2i(3, 16)])
	_editor._after_change()
	_editor.show_category("moebel")
	_editor.pick_decor("column")
	await _wait(10)
	_hover(Vector2i(6, 12))
	await _shot("09-deko-moebel-gesperrt")
	# Light and odds and ends.
	_place("fire", [Vector2i(20, 17), Vector2i(7, 19)])
	_place("skull", [Vector2i(28, 18), Vector2i(4, 9), Vector2i(33, 15)], 0)
	_place("skull", [Vector2i(29, 16)], 1)
	_place("signpost", [Vector2i(8, 10)])
	_place("rug", [Vector2i(33, 11)], 1)
	_editor._after_change()
	_editor.show_category("licht")
	_editor.pick_decor("fire")
	await _wait(20)
	_editor._refresh_checks()
	_hover(Vector2i(14, 19))
	await _shot("10-deko-licht")
	_editor.show_tab("raum")
	await _wait(5)
	await _shot("11-deko-pruefung")
	var playable: bool = _editor.save()
	print("SAVED playable=%s checks=%s" % [playable, str(doc.checks(_editor.config).map(func(c): return ("OK " if c.ok else "!! ") + c.text))])
	_editor.test_play()
	await _wait(150)
	print("TEST room=%s layout=%s phase=%s" % [_game.test_room_id, str(_game.current_layout.get("template_id", "")), _game.phase])
	await _shot("12-deko-im-spiel")
	_game._leave_session()
	await _wait(30)
	quit(0)
