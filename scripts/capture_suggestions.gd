extends SceneTree
## Captures the Werkstatt's suggestions and the new chests from the real
## windowed game: a labyrinth layout (GRUNDRISS) and its decor (DEKORIEREN), a
## throne hall decorated with its light shaft, that hall test-played, then a
## chest with the "E ÖFFNEN" hint and a Mimik springing in a test run. Works on
## a copy of the room library (user://). Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_suggestions.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const COPY := "user://capture_suggest_library.json"

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
			_game.players[1].hp = maxi(4, int(_game.players[1].hp))
		await process_frame


func _shot(name: String) -> void:
	await _wait(3)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


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
	# A labyrinth: GRUNDRISS, then DEKORIEREN.
	_editor.new_room()
	_editor.suggest_layout()
	await _wait(20)
	await _shot("13-vorschlag-grundriss")
	var maze_id := str(_editor.doc.room.id)
	_editor.suggest_decor()
	await _wait(20)
	await _shot("14-vorschlag-deko")
	print("MAZE checks=%s" % str(_editor.doc.checks(_editor.config).map(func(c): return ("OK " if c.ok else "!! ") + c.text)))
	_editor.save(false)
	# A throne hall for a boss.
	_editor.new_room()
	_editor._edit(func(): _editor.doc.set_role("boss"))
	_editor._sync_controls()
	_editor.suggest_layout()
	_editor.suggest_decor()
	await _wait(20)
	await _shot("15-thronsaal-editor")
	var throne: Vector2i = _editor.doc.enemies[0] if not _editor.doc.enemies.is_empty() else Vector2i(24, 5)
	var playable: bool = _editor.save(false)
	print("THRONE playable=%s checks=%s" % [playable, str(_editor.doc.checks(_editor.config).map(func(c): return ("OK " if c.ok else "!! ") + c.text))])
	_editor.test_play()
	await _wait(120)
	if _game.players.has(1): _game.players[1].pos = Vector2(throne) * 32.0 + Vector2(16, 16) + Vector2(0, 220)
	await _wait(40)
	print("THRONE_TEST layout=%s phase=%s" % [str(_game.current_layout.get("template_id", "")), _game.phase])
	await _shot("16-thronsaal-im-spiel")
	_game._leave_session()
	await _wait(30)
	# The labyrinth in the game: a chest with the E hint, then a Mimik.
	_editor.select_room(_editor.room_ids.find(maze_id))
	_editor.test_play()
	await _wait(120)
	var hero: Dictionary = _game.players[1]
	var room_id := str(_game.current_layout.id)
	var at := Vector2i(int(hero.pos.x / 32.0), int(hero.pos.y / 32.0))
	var chest_cell := _free_cell_near(at, Vector2i(2, 0))
	var mimic_cell := _free_cell_near(at, Vector2i(0, 2))
	var list: Array = _game.chests.chests.get(room_id, [])
	for entry: Array in [[chest_cell, "chest", 7001], [mimic_cell, "mimic", 7002]]:
		var cell: Vector2i = entry[0]
		list.append({"id": int(entry[2]), "kind": str(entry[1]), "pos": Vector2(cell) * 32.0 + Vector2(16, 16), "hits": 0, "max": 0, "open": false})
		_game.current_layout.obstacles.append([float(cell.x) * 32.0, float(cell.y) * 32.0, 32.0, 32.0])
	_game.chests.chests[room_id] = list
	_game.enemies.clear()
	hero.pos = Vector2(chest_cell) * 32.0 + Vector2(16, 16) + Vector2(-34, 0)
	await _wait(20)
	await _shot("17-truhe-mit-e")
	hero.pos = Vector2(mimic_cell) * 32.0 + Vector2(16, 16) + Vector2(0, -34)
	await _wait(5)
	_game.action_times.clear()
	_game._server_action(1, "interact", 0)
	await _wait(24)
	print("MIMIC enemies=%d phase=%s" % [_game.enemies.filter(func(e): return str(e.kind) == "mimic").size(), _game.phase])
	await _shot("18-mimik")
	_game._leave_session()
	await _wait(20)
	quit(0)


## A floor cell near `from` (first `offset`, then around it) for a test chest.
func _free_cell_near(from: Vector2i, offset: Vector2i) -> Vector2i:
	var floor_cells := {}
	for entry: Dictionary in _game.current_layout.get("painted_tiles", []):
		if str(entry.get("layer", "")) == "floor": floor_cells[Vector2i(int(entry.x), int(entry.y))] = true
	for ring in range(0, 4):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				var cell := from + offset + Vector2i(dx, dy)
				if floor_cells.has(cell) and cell != from: return cell
	return from + offset
