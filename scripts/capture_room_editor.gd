extends SceneTree
## Captures the Dungeon-Werkstatt from the real windowed game: opened from the
## main menu, a new room built (floor, start, enemies, chests, candles), saved,
## test-played in the real game and back in the editor. Works on a copy of the
## room library (user://), so the shipped rooms stay untouched. Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_room_editor.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const COPY := "user://capture_room_library.json"

var _out := "res://production/qa/evidence/dungeon-werkstatt"
var _game: Node


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


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var file := FileAccess.open(COPY, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	file.close()
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(40)
	await _shot("01-hauptmenue-editor-knopf")
	# The editor works on the copy.
	_game.main_menu.open_room_editor("")
	var editor: Control = _game.main_menu.room_editor
	editor.config_path = COPY
	editor.open("crypt_10")
	await _wait(20)
	await _shot("02-boss-raum")
	# A new room: a cross of two halls with a side chamber.
	editor.new_room()
	var doc = editor.doc
	doc.begin_change()
	doc.fill_rect(Vector2i(1, 1), Vector2i(38, 24), false)
	doc.fill_rect(Vector2i(3, 9), Vector2i(36, 15), true)
	doc.fill_rect(Vector2i(16, 3), Vector2i(23, 22), true)
	doc.fill_rect(Vector2i(28, 3), Vector2i(35, 8), true)
	doc.set_marker("start", Vector2i(6, 12))
	for cell: Vector2i in [Vector2i(30, 12), Vector2i(20, 6), Vector2i(20, 19), Vector2i(31, 5)]: doc.set_marker("enemy", cell)
	for cell: Vector2i in [Vector2i(33, 4), Vector2i(17, 21)]: doc.set_marker("chest", cell)
	for cell: Vector2i in [Vector2i(10, 10), Vector2i(10, 14), Vector2i(22, 4)]: doc.set_marker("torch", cell)
	doc.set_title("Kreuzgang")
	editor._sync_controls()
	editor._after_change()
	editor.select_tool("chest")
	await _wait(30)
	editor._refresh_checks()
	await _wait(5)
	await _shot("03-neuer-raum")
	var playable: bool = editor.save()
	print("SAVED playable=%s checks=%s" % [playable, str(doc.checks(editor.config).map(func(c): return ("OK " if c.ok else "!! ") + c.text))])
	# Test play in the real game.
	editor.test_play()
	print("AFTER test_play active=%s phase=%s status=%s" % [_game.active, _game.phase, _game.status_message])
	await _wait(150)
	print("TEST room=%s layout=%s phase=%s active=%s status=%s" % [_game.test_room_id, str(_game.current_layout.get("template_id", "")), _game.phase, _game.active, _game.status_message])
	await _shot("04-testspiel")
	_game._leave_session()
	await _wait(30)
	print("BACK editor_visible=%s room=%s" % [editor.visible, str(editor.doc.room.id) if editor.doc != null else ""])
	await _shot("05-zurueck-im-editor")
	quit(0)
