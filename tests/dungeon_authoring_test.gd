extends SceneTree
## Pure authoring operations against an in-memory legacy16 input and native32 authoring configuration.
var checked := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("AUTHORING_FAIL: ", label)

func fixture() -> Dictionary:
	var templates: Array = []
	for index in range(4):
		templates.append({"id": "fixture_%d" % index, "title": "Raum %d" % index, "boss": index == 3, "obstacles_tiles": [], "player_spawns": [[75,105],[101,130],[127,105],[153,130]], "enemy_spawns": [[320,60],[368,88],[400,120],[336,152],[384,192]],"reward_spawn":[224,144],"brazier_spawns":[]})
	return {"schema_version":1,"generator_version":3,"tile_size":16,"world_size":[448,240],"play_bounds":[16,24,416,200],"max_actor_radius":12,"templates":templates}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := "res://src/dungeon_editor_model.gd"
	check(FileAccess.file_exists(path), "authoring model exists")
	if not FileAccess.file_exists(path):
		finish()
		return
	var model = load(path).new(fixture())
	check(model.config.tile_size == 32 and model.config.generator_version == 4 and model.config.world_size == [896,480], "legacy authoring data migrates to the native32 contract")
	check(model.template().player_spawns[0] == [150,210] and model.template().reward_spawn == [448,288], "migration doubles pixel positions without changing tile cells")
	check(fixture().tile_size == 16 and fixture().templates[0].player_spawns[0] == [75,105], "migration preserves its input draft")
	var legacy := fixture()
	legacy.templates[0].brazier_spawns = [[36,39]]
	legacy.templates[3].stairs_spawn = [300,150]
	legacy.door_lanes = {"vertical":192,"horizontal":128}
	var legacy_before := var_to_str(legacy)
	var upgraded: Dictionary = load("res://src/dungeon/dungeon_generator.gd").upgrade_config(legacy)
	check(upgraded.templates[0].brazier_spawns == [[72,78]] and upgraded.templates[3].stairs_spawn == [600,300], "all optional prop coordinates migrate")
	check(upgraded.door_lanes == {"vertical":384,"horizontal":256}, "paired door lanes migrate together")
	check(var_to_str(legacy) == legacy_before, "optional migration leaves the complete source dictionary intact")
	check(load("res://src/dungeon/dungeon_generator.gd").upgrade_config(upgraded) == upgraded, "normalizing an already migrated library never doubles it again")
	check(model.validate().is_empty(), "initial fixture is usable")
	var original: Dictionary = model.config.duplicate(true)
	model.begin_edit()
	model.paint_wall(Vector2i(12,6), true)
	model.paint_wall(Vector2i(13,6), true)
	model.paint_wall(Vector2i(12,7), true)
	model.paint_wall(Vector2i(13,7), true)
	model.end_edit()
	check(model.template().obstacles_tiles == [[12,6,2,2]], "adjacent wall cells merge into a proper rectangle")
	check(model.validate().is_empty(), "reachable edited layout remains valid")
	model.undo()
	check(model.config == original, "one undo reverses the entire brush stroke")
	model.redo()
	check(model.template().obstacles_tiles.size() == 1, "redo restores the stroke")
	var before: Dictionary = model.config.duplicate(true)
	model.begin_edit()
	model.paint_wall(Vector2i(0,0), true)
	model.end_edit()
	check(model.config == before, "outside-grid paint is ignored")
	model.begin_edit()
	model.paint_wall(Vector2i(12,6), false)
	model.end_edit()
	check(not model.wall_cells().has(Vector2i(12,6)) and model.wall_cells().size() == 3, "floor brush removes precisely one cell")
	model.begin_edit()
	model.set_spawn("player_spawns", 0, Vector2(176,208))
	model.set_theme("moss")
	model.end_edit()
	check(model.template().player_spawns[0] == [176.0,208.0] and model.template().theme == "moss", "spawn and palette are stored as portable values")
	model.begin_edit()
	model.set_door_lane("north", Vector2(384,48))
	model.end_edit()
	check(model.config.door_lanes.vertical == 384, "opposite doors share the authored vertical lane")
	var id: String = model.create_room(false)
	check(id != "" and model.config.templates.size() == 5, "a new room is appended without replacing existing rooms")
	check(model.delete_room() and model.config.templates.size() == 4, "deleting a library room is supported")
	model.undo()
	check(model.config.templates.size() == 5 and model.template().id == id, "undo restores a removed room")
	check(not model.validate().is_empty(), "undo restores the genuinely unfinished canvas without inventing game content")
	check(model.delete_room() and model.config.templates.size() == 4, "removing the unfinished draft restores the existing playable library")
	model.set_fixed_order(["fixture_0","fixture_1","fixture_3"])
	check(model.validate().is_empty(), "a valid authored three-room floor is accepted")
	var generated: Array = load("res://src/dungeon/dungeon_generator.gd").generate(42,3,model.config)
	check(generated.size() == 3 and generated[0].template_id == "fixture_0" and generated[2].template_id == "fixture_3", "the game generator actually follows the selected room order")
	model.set_fixed_order(["missing","fixture_1","fixture_3"])
	check(not model.validate().is_empty(), "unknown room references block publishing")
	model.clear_fixed_order()
	model.selected = 0
	model.begin_edit()
	model.paint_wall(Vector2i(5,6), true)
	model.end_edit()
	check(not model.validate().is_empty(), "a player spawn inside a wall blocks publishing")
	model.undo()
	check(model.validate().is_empty(), "undo also restores publishability")
	finish()

func finish() -> void:
	print("DUNGEON_AUTHORING checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
