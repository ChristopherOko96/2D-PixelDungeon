extends SceneTree
## Actual freeform editor controls; changes stay in memory and disposable drafts.
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("FREEFORM_UI_FAIL ",label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var editor = load("res://src/dungeon_editor.gd").new()
	root.add_child(editor)
	await process_frame
	check(editor.has_method("set_canvas_background"),"free canvas background control exists")
	if not editor.has_method("set_canvas_background"):
		editor.queue_free()
		await process_frame
		finish()
		return
	editor.new_blank_room()
	check(editor.model.template().get("layout_mode","") == "freeform","new room is freeform")
	check(editor._preview_layout.exits.is_empty() and editor._preview_layout.painted_tiles.is_empty(),"blank canvas has no automatic floor walls or doors")
	check(editor.model.template().player_spawns.is_empty() and editor.model.template().enemy_spawns.is_empty(),"no automatic spawn data")
	editor.set_canvas_background(true)
	check(editor.canvas_background == Color.WHITE and editor.view._snapshot.editor_background == Color.WHITE,"white background is preview only")
	editor.grid_toggle.button_pressed = false
	check(not editor.grid_visible,"grid can be hidden")
	editor.grid_toggle.button_pressed = true
	editor.width_input.value = 40
	editor.height_input.value = 24
	editor._resize_selected()
	check(editor._canvas_zoom == 0.5 and editor.model.template().player_spawns.is_empty(),"resizing changes blank canvas without creating starts")
	editor.select_tile("violet_017")
	editor.tool_menu.select(1)
	editor._last_cell = Vector2i(-100,-100)
	editor.model.begin_edit()
	editor.paint_at(Vector2(16,16))
	editor.model.end_edit()
	check(editor.model.template().painted_tiles.size() == 1 and editor.model.template().painted_tiles[0].layer == "floor","floor can be painted at canvas origin")
	editor.tool_menu.select(0)
	editor._last_cell = Vector2i(-100,-100)
	editor.model.begin_edit()
	editor.paint_at(Vector2(16,16))
	editor.model.end_edit()
	check(editor.model.template().painted_tiles.size() == 2,"wall layer preserves floor beneath it")
	editor.tool_menu.select(4)
	editor.select_tile("violet_000")
	editor.tool_menu.select(4)
	editor.tile_rotation = 0
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_E
	editor._unhandled_input(key)
	check(editor.tile_rotation == 1,"E rotates free door facing")
	editor._last_cell = Vector2i(-100,-100)
	editor.model.begin_edit()
	editor.paint_at(Vector2(400,208))
	editor.model.end_edit()
	var door: Dictionary = editor.model.template().authored_doors[0]
	check(door.x == 12 and door.y == 6 and door.side == "east" and door.tile == "violet_000","door can be positioned in canvas interior with chosen art and direction")
	editor._undo()
	check(editor.model.template().authored_doors.is_empty(),"door stroke is undoable")
	editor._redo()
	check(editor.model.template().authored_doors.size() == 1,"door redo restores its location")
	editor.tool_menu.select(2)
	editor.slot.value = 1
	editor._last_cell = Vector2i(-100,-100)
	editor.model.begin_edit()
	editor.paint_at(Vector2(176,176))
	editor.model.end_edit()
	check(editor.model.template().player_spawns.size() == 1,"first player slot is explicitly placed")
	editor.slot.value = 4
	editor._last_cell = Vector2i(-100,-100)
	editor.model.begin_edit()
	editor.paint_at(Vector2(336,176))
	editor.model.end_edit()
	check(editor.model.template().player_spawns.size() == 1 and editor.status.text.contains("zuerst"),"skipped slots explain required preceding starts")
	var path := "user://freeform_ui_draft.json"
	var saved: Dictionary = editor.save_draft(path)
	check(saved.error.is_empty(),"unfinished free canvas can be saved")
	var Store = load("res://src/dungeon_editor_store.gd")
	var loaded: Dictionary = Store.read_config(path)
	check(loaded.error.is_empty() and loaded.config.templates[-1].authored_doors.size() == 1,"unfinished geometry survives file boundary")
	DirAccess.remove_absolute(path)
	# Arrange a valid library where the old fixed middle room cannot connect.
	var config := port_fixture()
	var old_config := config.duplicate(true)
	old_config.room_order = [config.templates[2].id,config.templates[0].id,config.templates[3].id]
	var Dungeon = load("res://src/dungeon/dungeon_generator.gd")
	check(Dungeon.generate(3,3,old_config).is_empty(),"counterexample reproduces failure of previous predetermined test order")
	editor.model.config = config
	editor.model.selected = 2
	editor._refresh_controls()
	editor._refresh_room()
	editor._test_room()
	check(is_instance_valid(editor._test_game) and not editor.visible,"selected-room test finds compatible alternative instead of hiding editor over lobby")
	if is_instance_valid(editor._test_game):
		check(editor._test_game.current_layout.template_id == config.templates[2].id and editor._test_game.phase == "combat","the chosen freeform room actually starts in combat")
		editor._return_from_test()
	editor.queue_free()
	await process_frame
	finish()
func port_fixture() -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	for index in range(config.templates.size()):
		var room: Dictionary = config.templates[index]
		room.layout_mode = "freeform"
		room.world_size = [512,384]
		room.play_bounds = [0,0,512,384]
		room.obstacles_tiles = []
		room.painted_tiles = []
		room.brazier_spawns = []
		room.erase("reward_spawn")
		room.player_spawns = [[144,144],[176,144],[208,144],[240,144]]
		room.enemy_spawns = [[336,144],[368,176],[304,208],[336,240],[368,272]]
		for y in range(2,10):
			for x in range(2,14): room.painted_tiles.append({"x":x,"y":y,"tile":"violet_017","rotation":0,"solid":false,"layer":"floor"})
		room.authored_doors = []
		if index != 2: room.authored_doors.append({"x":2,"y":6,"side":"west","tile":"items_002","rotation":3})
		if index in [1,2]: room.authored_doors.append({"x":13,"y":6,"side":"east","tile":"items_002","rotation":1})
		if room.boss:
			room.stairs_spawn = [320,208]
			room.stairs_art = {"tile":"violet_000","rotation":2}
	return config
func finish() -> void:
	print("FREEFORM_EDITOR_UI checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
