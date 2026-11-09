extends SceneTree
## Real story input routing: one character/inventory view and a stable pause.
var game: Node
var failures := 0
var checks := 0
var scratch := ""

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("MENU_FLOW_FAIL: ", label)

func _run() -> void:
	scratch = "res://tests/.tmp_menu_flow_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	game = load("res://src/hell/krypta_dungeon.tscn").instantiate()
	game.class_id = "swordsman"
	game.profile_path = scratch.path_join("profile.json")
	game.meta_path = scratch.path_join("meta.cfg")
	game.settings_path = scratch.path_join("settings.cfg")
	game.graphics_path = game.settings_path
	game.saves = preload("res://src/save/save_store.gd").new(scratch.path_join("saves"))
	root.add_child(game)
	game.set_process(false)
	await process_frame
	if game.loading_screen != null:
		game.loading_screen.queue_free()
		game.loading_screen = null
	game._process(0.0)
	for key: Key in [KEY_C, KEY_TAB, KEY_I]:
		_press(key)
		check(game.inventory_panel.open and not game.state.get("status", false), "C/Tab/I share the character inventory: " + str(key))
		check(game._simulation_paused(), "character reading pauses solo gameplay")
		var before: float = game.state.t
		game._process(0.25)
		check(is_equal_approx(game.state.t, before), "reading cannot advance simulation")
		_press(KEY_ESCAPE)
		check(not game.inventory_panel.open and not game.state.get("status", false), "one Esc returns from direct character view")
		game.state.status = false # clear the old bug so later checks stay independent
	_press(KEY_ESCAPE)
	check(game.pause_menu.visible and game._simulation_paused(), "Esc pauses gameplay")
	game.pause_menu.select_section("inventory")
	check(game.inventory_panel.open and game._simulation_paused(), "pause to inventory retains pause")
	_press(KEY_ESCAPE)
	check(game.pause_menu.visible and not game.inventory_panel.open, "inventory opened by pause returns to pause")
	_press(KEY_ESCAPE)
	_press(KEY_I)
	check(game.inventory_panel.has_method("set_character_view"), "same view has character data")
	var item_button: Button = game.inventory_panel._buttons.inv_equip
	check(item_button.focus_mode != Control.FOCUS_NONE, "inventory actions support keyboard focus")
	_press(KEY_K)
	check(game.run_talents != null and game.run_talents.visible and not game.inventory_panel.open, "talents replace the character view, never stack")
	game.queue_free()
	await process_frame
	for name: String in ["profile.json", "meta.cfg", "settings.cfg"]:
		var path := ProjectSettings.globalize_path(scratch.path_join(name))
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch.path_join("saves")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	print("MENU_FLOW checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func _press(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	game._unhandled_input(event)
