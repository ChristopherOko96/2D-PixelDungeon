extends SceneTree
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("FREEFORM_MODEL_FAIL ",label)
func _initialize() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	var model = load("res://src/dungeon_editor_model.gd").new(config)
	model.create_room()
	check(model.template().get("layout_mode","") == "freeform","new room uses genuinely manual geometry")
	check(model.template().player_spawns.is_empty() and model.template().enemy_spawns.is_empty(),"no authored entities are invented")
	check(model.editable(Vector2i.ZERO),"canvas edges can be authored")
	if not model.has_method("paint_floor"):
		print("FREEFORM_MODEL checked=%d failures=%d" % [checked,failures])
		quit(1)
		return
	model.begin_edit()
	model.paint_floor(Vector2i(0,0),"violet_017",1)
	model.paint_tile(Vector2i(0,0),"violet_007",2,true)
	model.end_edit()
	check(model.template().painted_tiles.size() == 2,"wall art overlays floor without destroying its footprint")
	model.undo()
	check(model.template().painted_tiles.is_empty(),"one undo restores true void")
	model.redo()
	model.begin_edit()
	model.set_authored_door(Vector2i(0,0),"west","items_002",3)
	model.end_edit()
	check(model.template().authored_doors.size() == 1 and model.template().authored_doors[0].x == 0,"door is placed exactly where authored")
	check(model.template().painted_tiles.size() == 1 and model.template().painted_tiles[0].layer == "floor","door cuts painted wall without inventing a floor")
	model.begin_edit()
	model.set_authored_door(Vector2i(4,4),"east","items_002",1)
	model.end_edit()
	check(model.template().painted_tiles.size() == 1,"door on empty canvas never adds floor")
	model.set_spawn("player_spawns",0,Vector2(48,48))
	check(model.template().player_spawns.size() == 1,"first spawn is deliberate")
	model.set_spawn("player_spawns",3,Vector2(80,80))
	check(model.template().player_spawns.size() == 1,"skipped spawn indices never invent positions")
	check(model.resize_room(Vector2i(40,24)).is_empty() and model.template().player_spawns == [[48.0,48.0]],"resizing keeps authored positions without redistributing")
	check(not model.validate().is_empty(),"unfinished canvas cannot replace playable game data")
	model.remove_spawn("player_spawns",0)
	check(model.template().player_spawns.is_empty(),"spawn can be removed")
	print("FREEFORM_MODEL checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
