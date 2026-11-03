extends SceneTree
## Captures the loading screens in the real worlds (src/ui/loading_screen.gd): A, B and C in each
## world with a different class each, the parade back to the menu, and A in a narrow window.
## Prints how long a floor and the menu really take to load.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_loading_screens.gd -- <output_dir>
const SCENES := {"krypta": "res://src/hell/krypta_dungeon.tscn", "hell": "res://src/hell/hell_dungeon.tscn", "frost": "res://src/hell/frost_dungeon.tscn"}
const SHOTS := [["krypta", "A", "swordsman"], ["krypta", "B", "archer"], ["krypta", "C", "mage"],
	["hell", "A", "necromancer"], ["hell", "B", "swordsman"], ["hell", "C", "archer"],
	["frost", "A", "mage"], ["frost", "B", "necromancer"], ["frost", "C", "swordsman"]]

var _out := "res://production/qa/evidence/loading"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s" % [_out, file])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.size = Vector2i(1280, 720)
	var game: Node
	for spec: Array in SHOTS:
		if game != null:
			game.queue_free()
			await process_frame
		seed(4711)
		game = (load(SCENES[spec[0]]) as PackedScene).instantiate()
		game.class_id = spec[2]
		game.loading_forced = true
		root.add_child(game)
		current_scene = game
		await process_frame
		_force(game, spec[1])
		for i in range(50):
			await process_frame
		await _shot("%s_%s_%s.png" % [spec[0], spec[1], spec[2]])
		# what a floor change really takes, with the screen off
		var started := Time.get_ticks_msec()
		game._no_loading_once = true
		game.load_floor(2, true)
		print("LOADING_TIME floor ", spec[0], " ", Time.get_ticks_msec() - started, " ms")
	game.queue_free()
	await process_frame
	# the same screen in a narrow and a wide window
	for size: Vector2i in [Vector2i(960, 720), Vector2i(1920, 800)]:
		root.size = size
		game = (load(SCENES.frost) as PackedScene).instantiate()
		game.class_id = "archer"
		game.loading_forced = true
		root.add_child(game)
		await process_frame
		_force(game, "C")
		for i in range(30):
			await process_frame
		await _shot("frost_C_%dx%d.png" % [size.x, size.y])
		game.queue_free()
		await process_frame
	root.size = Vector2i(1280, 720)
	# the parade
	var LoadingScreen: GDScript = load("res://src/ui/loading_screen.gd")
	var parade: CanvasLayer = LoadingScreen.new()
	root.add_child(parade)
	var started := Time.get_ticks_msec()
	parade.finished.connect(func(_s: PackedScene) -> void: print("LOADING_TIME parade ended after ", Time.get_ticks_msec() - started, " ms"))
	parade.start_menu("res://src/main.tscn")
	for i in range(40):
		await process_frame
	await _shot("menu_parade.png")
	# to its end, so the menu has really loaded
	while parade._menu_scene == null and not parade._menu_failed:
		await process_frame
	print("LOADING_TIME menu loaded after ", Time.get_ticks_msec() - started, " ms")
	print("LOADING_SHOTS_DONE")
	quit()


## Shows the asked variant on the world's own data, whatever was rolled.
func _force(game: Node, variant: String) -> void:
	var old: CanvasLayer = game.loading_screen
	if old != null:
		old.queue_free()
		game.loading_screen = null
	game._no_loading_once = false
	game.loading_variant = variant
	game._show_loading()
	game.loading_screen.hold = 60.0
