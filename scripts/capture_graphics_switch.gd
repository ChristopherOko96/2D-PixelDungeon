extends SceneTree
## Captures the Pixel / HD switch: the main menu options with the HD check, the
## same Hell-Dungeon spot in pixel and in HD, the pause menu's graphics line,
## and the Frostgruft's note that it only has pixel art. Uses its own settings
## file, so the player's choice stays as it is.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_graphics_switch.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const GraphicsSettings = preload("res://src/core/graphics_settings.gd")
const PATH := "user://graphics_capture.cfg"

var _out := "res://production/qa/evidence/graphics-switch"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.get("state") is Dictionary and not (_game.state as Dictionary).is_empty():
			_game.state.inv = 0.0
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _world(scene: PackedScene) -> void:
	if _game != null:
		_game.queue_free()
		await process_frame
	_game = scene.instantiate()
	_game.class_id = "swordsman"
	_game.graphics_path = PATH
	root.add_child(_game)
	await _wait(5)
	_game.state.offer = []
	# a room with lava, walls and props: the start room of floor 1
	await _wait(150)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var menu: Node = Game.new()
	menu.session_bind_ip = "127.0.0.1"
	root.add_child(menu)
	await _wait(40)
	menu.main_menu._open_options()
	await _wait(4)
	await _shot("01-optionen-hd-schalter")
	menu.queue_free()
	await _wait(3)
	GraphicsSettings.store("pixel", PATH)
	await _world(HellScene)
	await _shot("02-hoelle-pixel")
	_game.apply_graphics("hd")
	await _wait(20)
	await _shot("03-hoelle-hd")
	_game.open_pause()
	_game.pause_menu.select_section("display")
	await _wait(5)
	await _shot("04-pause-grafik")
	_game.pause_menu.visible = false
	await _world(FrostScene)
	_game.open_pause()
	_game.pause_menu.select_section("display")
	await _wait(5)
	await _shot("05-frost-pause-grafik")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	quit()
