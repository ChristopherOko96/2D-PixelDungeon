extends SceneTree
## Uses disposable user:// fixtures; never publishes over the project's rooms.
const Store = preload("res://src/dungeon_editor_store.gd")
const Editor = preload("res://src/dungeon_editor.gd")
const Game = preload("res://src/game.gd")
var checked := 0
var failures: Array[String] = []
var owned_files: Array[String] = []
var folder := ""

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("EDITOR_INTEGRATION_FAIL: ",description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	folder = "user://editor_test_%d" % Time.get_ticks_usec()
	var path := folder.path_join("dungeon_fixture.json")
	var draft_path := folder.path_join("dungeon_draft.json")
	owned_files.append(path)
	owned_files.append(draft_path)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	var original := JSON.stringify(source,"",true)
	var saved := Store.write_config(path,source)
	Store.write_config(draft_path,source)
	check(saved.error.is_empty(), "first draft save succeeds")
	var loaded := Store.read_config(path)
	check(loaded.error.is_empty() and loaded.config.templates.size() == 4 and loaded.config.tile_size == 32, "native32 JSON round-trips through the real file boundary")
	var legacy_path := folder.path_join("dungeon_legacy16.json")
	owned_files.append(legacy_path)
	var legacy := source.duplicate(true)
	legacy.generator_version = 3
	legacy.tile_size = 16
	legacy.world_size = [448,240]
	legacy.play_bounds = [16,24,416,200]
	legacy.max_actor_radius = 12
	for room: Dictionary in legacy.templates:
		for field in ["player_spawns","enemy_spawns"]:
			for point: Array in room[field]:
				point[0] /= 2.0
				point[1] /= 2.0
	legacy.templates[0].brazier_spawns = [[36,39]]
	legacy.templates[0].reward_spawn = [224,120]
	legacy.templates[3].stairs_spawn = [300,150]
	legacy.door_lanes = {"vertical":224,"horizontal":124}
	legacy.room_order = [source.templates[0].id,source.templates[1].id,source.templates[3].id]
	Store.write_config(legacy_path,legacy)
	var legacy_original := FileAccess.get_file_as_string(legacy_path)
	var migrated := Store.read_config(legacy_path)
	check(migrated.error.is_empty() and migrated.migrated and migrated.config.generator_version == 4 and migrated.config.world_size == [896.0,480.0], "legacy16 draft files migrate to native32/version4")
	check(migrated.config.templates[0].brazier_spawns == [[72.0,78.0]] and migrated.config.templates[3].stairs_spawn == [600.0,300.0] and migrated.config.door_lanes == {"vertical":448.0,"horizontal":248.0}, "file migration includes optional props, stairs and paired door lanes")
	check(FileAccess.get_file_as_string(legacy_path) == legacy_original, "migration reads preserve the complete original legacy file")
	var wrong_version_path := folder.path_join("dungeon_wrong_version.json")
	owned_files.append(wrong_version_path)
	var wrong_version := legacy.duplicate(true)
	wrong_version.generator_version = []
	Store.write_config(wrong_version_path,wrong_version)
	check(not Store.read_config(wrong_version_path).error.is_empty(), "invalid version types fail closed without a script conversion error")
	var editor := Editor.new()
	editor.active_config_path = path
	root.add_child(editor)
	await process_frame
	check(editor.model != null, "F6 editor constructs its model and controls")
	editor.load_draft(legacy_path)
	check(editor.model.config.tile_size == 32 and not editor.model.config.has("room_order"), "the editor adopts migrated rooms as a library and removes old fixed sequences")
	check(FileAccess.get_file_as_string(legacy_path) == legacy_original, "loading legacy rooms in the actual editor does not rewrite their source")
	editor.load_draft(draft_path)
	editor.tool_menu.select(0)
	editor.model.begin_edit()
	editor.paint_at(Vector2(400,208))
	editor.model.end_edit()
	check(editor.model.wall_cells().has(Vector2i(12,6)), "the canvas brush edits the selected room")
	editor._undo()
	check(not editor.model.wall_cells().has(Vector2i(12,6)), "the actual Undo button path restores the draft")
	editor._redo()
	check(editor.model.wall_cells().has(Vector2i(12,6)), "the actual Redo path restores the painted cell")
	editor.model.begin_edit()
	editor.paint_at(Vector2(400,176))
	editor.paint_drag_to(Vector2(496,176))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	editor._painting = true
	editor._input(release)
	check(editor.model.wall_cells().has(Vector2i(13,5)) and editor.model.wall_cells().has(Vector2i(14,5)) and not editor._painting, "fast strokes fill skipped cells and release over UI closes the transaction")
	editor._undo()
	check(not editor.model.wall_cells().has(Vector2i(13,5)) and editor.model.wall_cells().has(Vector2i(12,6)), "one Undo removes only that complete drag stroke")
	editor.tool_menu.select(4)
	editor._last_cell = Vector2i(-100,-100)
	editor.model.begin_edit()
	editor.paint_at(Vector2(384,56))
	editor.model.end_edit()
	check(editor.model.config.get("door_lanes",{}).get("vertical",-1) == 384, "the north wall's half-row accepts an actual door-tool click")
	if editor.model.config.has("door_lanes"): editor._undo()
	editor.tool_menu.select(6)
	editor.model.begin_edit()
	editor.paint_at(Vector2(576,400))
	editor.model.end_edit()
	editor.tool_menu.select(7)
	editor.model.begin_edit()
	editor.paint_at(Vector2(480,272))
	editor.model.end_edit()
	editor._select_room(3)
	editor.tool_menu.select(5)
	editor.model.begin_edit()
	editor.paint_at(Vector2(560,336))
	editor.model.end_edit()
	editor._select_room(0)
	editor.tool_menu.select(0)
	var id: String = editor.model.template().id
	editor.model.template().theme = "moss"
	editor._refresh_controls()
	saved = editor.save_draft(draft_path)
	if not saved.get("backup", "").is_empty(): owned_files.append(saved.backup)
	check(saved.error.is_empty(), "replacing an existing draft succeeds")
	check(FileAccess.file_exists(saved.get("backup","")) and FileAccess.get_file_as_string(saved.backup).contains("generator_version"), "the previous content is backed up before replacement")
	check(not editor.model.is_dirty(), "save establishes a clean undo-aware state")
	editor.model.template().title = "TEMPORARY"
	editor.load_draft(draft_path)
	check(editor.model.template().title != "TEMPORARY" and editor.model.template().theme == "moss", "Load restores portable authored room data")
	var malformed_path := folder.path_join("dungeon_broken.json")
	owned_files.append(malformed_path)
	var malformed := FileAccess.open(malformed_path,FileAccess.WRITE)
	malformed.store_string("{unfinished")
	malformed.close()
	var before_load: Dictionary = editor.model.config.duplicate(true)
	editor.load_draft(malformed_path)
	check(editor.model.config == before_load, "malformed JSON leaves the complete current draft untouched")
	editor.message.hide()
	editor.load_draft(wrong_version_path)
	check(editor.model.config == before_load, "invalid version types also leave the actual editor draft intact")
	editor.message.hide()
	var before_rejected_apply := FileAccess.get_file_as_string(path)
	editor.model.begin_edit()
	editor.model.set_spawn("player_spawns",0,Vector2(400,208))
	editor.model.end_edit()
	editor._refresh_controls()
	editor.apply_to_game()
	check(FileAccess.get_file_as_string(path) == before_rejected_apply, "an invalid draft cannot replace the active game config")
	editor.message.hide()
	var protected_save: Dictionary = editor.save_draft(path)
	if not protected_save.get("backup", "").is_empty(): owned_files.append(protected_save.backup)
	check(not protected_save.error.is_empty() and FileAccess.get_file_as_string(path) == before_rejected_apply, "Save As cannot bypass validation by targeting the active config")
	editor.message.hide()
	# Reset the disposable active file after exercising the previously unsafe path.
	var reset := FileAccess.open(path,FileAccess.WRITE)
	reset.store_string(before_rejected_apply)
	reset.close()
	editor._undo()
	editor.model.set_fixed_order([id,source.templates[1].id,source.templates[3].id])
	editor._refresh_controls()
	editor.apply_to_game()
	if not editor.last_write_result.get("backup", "").is_empty(): owned_files.append(editor.last_write_result.backup)
	check(not JSON.parse_string(FileAccess.get_file_as_string(path)).has("room_order"), "Apply publishes a room library for random generation without a fixed floor sequence")
	editor.message.hide()
	var game := Game.new()
	game.dungeon_file_path = path
	game.session_bind_ip = "127.0.0.1"
	root.add_child(game)
	await process_frame
	game.port_input.text = "18897"
	game._host_session()
	game.requested_seed = 42
	# Isolate one authored template for this geometry test after validating the
	# published file is a random room library. This does not write the file.
	game.dungeon_config.room_order = [id,source.templates[1].id,source.templates[3].id]
	game._begin_run()
	check(game.current_layout.template_id == id and game.current_layout.theme == "moss", "the real game loads and uses the authored file")
	check(game.current_layout.obstacles.has([384.0,192.0,32.0,32.0]), "painted wall geometry is authoritative in the live room")
	check(game.current_layout.reward_spawn == Vector2(496,272) and game.current_layout.brazier_spawns.has(Vector2(592,400)), "authored chest and fire positions survive save, apply and real game loading")
	var authored_stairs: Array = game.floor_layouts[2].exits.filter(func(exit: Dictionary): return exit.kind == "stairs")
	check(authored_stairs.size() == 1 and authored_stairs[0].rect == [544.0,320.0,32.0,32.0], "the boss floor uses the authored interior stair position")
	game._leave_session()
	game.queue_free()
	await process_frame
	editor._test_room()
	check(is_instance_valid(editor._test_game) and editor._test_game.hosting and not editor.visible, "Solo Test opens the selected room with the real game")
	if is_instance_valid(editor._test_game):
		check(editor._test_game.session_bind_ip == "127.0.0.1", "solo preview binds only to loopback")
		editor._return_from_test()
		check(editor.visible and editor.model.template().theme == "moss", "returning from playtest keeps the editor draft")
	await process_frame
	check(JSON.stringify(JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json")),"",true) == original, "integration never changes the actual project config")
	editor.queue_free()
	await process_frame
	for file_path in owned_files:
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(file_path)
	DirAccess.remove_absolute(folder)
	print("DUNGEON_EDITOR_INTEGRATION checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
