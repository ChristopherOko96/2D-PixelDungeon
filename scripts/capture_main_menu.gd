extends SceneTree
## Captures the real main menu screens of the running game (not headless):
## title screen, debug level list, options, multiplayer lobby and the first
## frame of a story run. Usage:
##   godot --path . -s res://scripts/capture_main_menu.gd -- <output_dir>
const Game = preload("res://src/game.gd")

var _out := "res://production/qa/evidence/main-menu-step1"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()

func _wait(frames: int) -> void:
	for i in range(frames): await process_frame

func _shot(name: String) -> void:
	await _wait(3)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	var result := image.save_png(path)
	print("CAPTURED %s %dx%d result=%d" % [path, image.get_width(), image.get_height(), result])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var game = Game.new()
	root.add_child(game)
	# Loopback only, so capturing never triggers a firewall prompt.
	game.session_bind_ip = "127.0.0.1"
	await _wait(40)
	await _shot("01-hauptmenue.png")
	game.main_menu._open_debug()
	await _shot("02-debug-levelliste.png")
	game.main_menu._open_options()
	await _shot("03-optionen.png")
	game.main_menu._close_panels()
	game.main_menu.multiplayer_requested.emit()
	await _shot("04-mehrspieler-lobby.png")
	game.lobby_menu_button.pressed.emit()
	await _wait(2)
	game.main_menu._open_classes(false)
	await _wait(30)
	await _shot("05-story-start.png")
	game._leave_session()
	await _wait(10)
	await _shot("06-zurueck-im-menue.png")
	quit(0)
