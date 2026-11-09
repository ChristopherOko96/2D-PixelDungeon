extends SceneTree
## Read-only UX inspection of the real story menus, with isolated save paths.
var game: Node
var scratch := ""
const OUT := "res://production/qa/evidence/menu-ux-2026-11-09"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	scratch = "res://tests/.tmp_menu_audit_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	seed(4242)
	game = load("res://src/hell/krypta_dungeon.tscn").instantiate()
	game.class_id = "swordsman"
	game.profile_path = scratch.path_join("profile.json")
	game.meta_path = scratch.path_join("meta.cfg")
	game.settings_path = scratch.path_join("settings.cfg")
	game.graphics_path = game.settings_path
	game.saves = preload("res://src/save/save_store.gd").new(scratch.path_join("saves"))
	game.mouse_taken = true
	game.keys_taken = true
	root.add_child(game)
	game.set_process(false)
	await process_frame
	if game.loading_screen != null:
		game.loading_screen.queue_free()
		game.loading_screen = null
	game._process(0.0)
	root.size = Vector2i(1280, 720)
	await _shot("01-hud")
	_press(KEY_C)
	await _shot("02-status")
	print("MENU_AUDIT status=", game.state.status, " paused=", game._simulation_paused())
	_press(KEY_I)
	await _shot("03-status-and-inventory")
	print("MENU_AUDIT stacked status=", game.state.status, " inventory=", game.inventory_panel.open, " paused=", game._simulation_paused(), " rect=", game.inventory_panel.panel)
	_press(KEY_ESCAPE)
	print("MENU_AUDIT first_escape status=", game.state.status, " inventory=", game.inventory_panel.open)
	_press(KEY_ESCAPE)
	_press(KEY_I)
	await _shot("04-inventory")
	_press(KEY_ESCAPE)
	_press(KEY_ESCAPE)
	await _shot("05-pause")
	print("MENU_AUDIT pause_visible=", game.pause_menu.visible, " paused=", game._simulation_paused())
	# Follow the actual pause navigation command to detect implicit resume.
	game.pause_menu.select_section("inventory")
	await _shot("06-inventory-from-pause")
	print("MENU_AUDIT inventory_from_pause visible=", game.inventory_panel.open, " paused=", game._simulation_paused())
	game.queue_free()
	await process_frame
	for name: String in ["profile.json", "meta.cfg", "settings.cfg"]:
		var path := ProjectSettings.globalize_path(scratch.path_join(name))
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch.path_join("saves")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	print("MENU_AUDIT completed")
	quit()

func _press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)
	game._sync_overlays()
	game.hud.queue_redraw()

func _shot(label: String) -> void:
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT.path_join(label + ".png"))
	print("MENU_CAPTURE ", label, " error=", error)
