extends SceneTree
## Captures evidence of the debug level choice from the real windowed game: the
## title screen, the world list, the crypt world, the Hell-Dungeon world, and a
## boss start on hell floor 1 picked through its button.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_level_select.gd -- <output_dir>
const MainScene = preload("res://src/main.tscn")

var _out := "res://production/qa/evidence/level-select"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in range(3):
		await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var game: Node = MainScene.instantiate()
	root.add_child(game)
	current_scene = game
	for i in range(30):
		await process_frame
	await _shot("01-titel.png")
	var menu = game.main_menu
	menu._open_debug()
	await _shot("02-welt-waehlen.png")
	menu._open_world("crypt")
	await _shot("03-welt-krypta.png")
	menu._open_world("hell")
	await _shot("04-welt-hell-dungeon.png")
	var boss_button: Button = null
	for node: Node in menu._hell_panel.get_children():
		if node is Button and (node as Button).text.begins_with("BOSS"):
			boss_button = node
			break
	boss_button.pressed.emit()
	for i in range(90):
		await process_frame
		if current_scene != null and current_scene.has_method("enter_boss_room"):
			current_scene.state.inv = 5.0
	var hell: Node = current_scene
	print("HELL floor=%d room=%s fight=%s" % [hell.state.floor, hell.W.rooms[hell.state.room].type, hell.W.rooms[hell.state.room].fight])
	# the invulnerable hero blinks; show it steadily for the picture
	hell.state.inv = 0.0
	await _shot("05-hell-etage1-boss.png")
	print("LEVEL_SELECT_CAPTURE done")
	quit(0)
