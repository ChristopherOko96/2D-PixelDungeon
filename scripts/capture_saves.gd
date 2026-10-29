extends SceneTree
## Captures the save slot screens in the real windowed game: the main menu's
## SPIELSTÄNDE panel, the crypt pause page "Speichern" after saving, and the
## story pause menu (Esc) in the Hell-Dungeon. Uses its own save folder.
## Usage: godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_saves.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const SaveStore = preload("res://src/save/save_store.gd")
const DIR := "user://save_capture/"

var _out := "res://production/qa/evidence/save-slots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames): await process_frame


func _shot(name: String) -> void:
	await _wait(3)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var store := SaveStore.new(DIR)
	for mode: String in SaveStore.MODE_NAMES:
		for slot in range(1, 4): store.erase(mode, slot)
	var game: Node = Game.new()
	game.saves = store
	root.add_child(game)
	game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	game.main_menu.saves = store
	# a mage on floor 3 saved into slot 1, then the menu with that slot
	game.main_menu.selected_story = "krypta"
	game.requested_seed = 4242
	game._start_solo(false, "mage")
	game.floor_index = 2
	game._enter_next_floor()
	game.team_progress.team.level = 6
	game.floor_save = game.CryptSave.capture(game)
	game.hordes.enabled = false
	game.enemies.clear()
	game.set_pause_open(true)
	await _wait(10)
	game.pause_menu.select_section("save")
	game.pause_menu.save_requested.emit(1)
	await _shot("02-krypta-pause-speichern")
	game.set_pause_open(false)
	game._leave_session()
	await _wait(10)
	store.write("hell", 2, {"class_id": "archer", "floor": 4, "level": 5, "title": "Glutkessel", "scene": "res://src/hell/hell_dungeon.tscn", "keep": {}})
	game.main_menu._open_saves()
	await _shot("01-hauptmenue-spielstaende-krypta")
	game.main_menu._show_save_mode("hell")
	game.main_menu._erase_slot(2)
	await _shot("03-hauptmenue-spielstaende-hoelle-loeschen")
	game.queue_free()
	await _wait(5)
	var hell: Node = HellScene.instantiate()
	hell.saves = store
	hell.class_id = "mage"
	root.add_child(hell)
	await _wait(40)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	hell._unhandled_input(esc)
	hell.pause_menu.select_section("save")
	hell.save_slot(3)
	await _shot("04-hoelle-pause-speichern")
	for mode: String in SaveStore.MODE_NAMES:
		for slot in range(1, 4): store.erase(mode, slot)
	quit(0)
