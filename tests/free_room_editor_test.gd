extends SceneTree
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("FREE_ROOM_FAIL ",label)
func _initialize() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	var model = load("res://src/dungeon_editor_model.gd").new(config)
	check(model.has_method("resize_room"),"per-template room sizing exists")
	if not model.has_method("resize_room"):
		quit(1)
		return
	model.create_room()
	check(model.template().obstacles_tiles.is_empty() and model.template().brazier_spawns.is_empty() and model.template().painted_tiles.is_empty() and model.template().authored_doors.is_empty(),"new room has no inherited floor, walls, doors or furnishings")
	check(model.template().player_spawns.is_empty() and model.template().enemy_spawns.is_empty(),"new canvas has no automatically positioned entities")
	var old: Dictionary = model.config.templates[0].duplicate(true)
	check(model.resize_room(Vector2i(40,24)).is_empty(),"large blank room accepted")
	check(Vector2(model.preview().world_size[0],model.preview().world_size[1]) == Vector2(1280,768) and model.config.templates[0] == old,"only selected room dimensions change")
	model.begin_edit()
	for y in range(17,20):
		for x in range(31,34): model.paint_floor(Vector2i(x,y),"violet_017",0)
	model.end_edit()
	var Dungeon = load("res://src/dungeon/dungeon_generator.gd")
	check(not Dungeon.segment_blocked(Vector2(1040,592),Vector2(1040,592),12,model.preview()),"manually painted floor is clear before overlaid solid art")
	model.begin_edit()
	model.paint_tile(Vector2i(32,18),"violet_017",3,true)
	model.end_edit()
	var layout: Dictionary = model.preview()
	var structures: Array = layout.painted_tiles.filter(func(cell: Dictionary): return cell.get("layer","") == "structure")
	check(layout.painted_tiles.size() == 10 and structures.size() == 1 and structures[0].rotation == 3,"selected tile and rotation persist over its separate floor layer")
	check(Dungeon.segment_blocked(Vector2(1040,592),Vector2(1040,592),12,layout),"solid art produces host collision beyond old viewport")
	model.undo()
	check(model.template().painted_tiles.size() == 9 and not Dungeon.segment_blocked(Vector2(1040,592),Vector2(1040,592),12,model.preview()),"one undo removes the solid stroke while retaining clear floor")
	model.redo()
	check(model.template().painted_tiles.size() == 10,"redo restores the structure above its floor")
	check(not model.resize_room(Vector2i(12,10)).is_empty(),"shrinking cannot silently discard authored tiles")
	check(not model.resize_room(Vector2i(500,500)).is_empty(),"bounded room dimensions")
	model.begin_edit()
	model.paint_tile(Vector2i(32,18),"",0,false)
	for y in range(17,20):
		for x in range(31,34): model.paint_floor(Vector2i(x,y),"violet_017",0,true)
	model.end_edit()
	check(model.resize_room(Vector2i(16,12)).is_empty(),"empty room can shrink")
	check(not model.validate().is_empty(),"an empty canvas cannot be published as a playable room")
	# Arrange a deliberately authored floor rather than relying on automatic fill.
	model.begin_edit()
	for y in range(12):
		for x in range(16): model.paint_floor(Vector2i(x,y),"violet_017",0)
	for index in range(4): model.set_spawn("player_spawns",index,Vector2(96+index*32,128))
	for index in range(5): model.set_spawn("enemy_spawns",index,Vector2(384+(index%2)*32,192+(index/2)*32))
	model.set_authored_door(Vector2i(14,6),"east","items_002",1)
	model.end_edit()
	check(model.validate().is_empty(),"manually placed floor, party/enemies and doorway form a playable mixed library")
	check(model.preview().exits.size() == 1 and model.preview().exits[0].side == "east","preview shows only the authored door")
	var Store = load("res://src/dungeon_editor_store.gd")
	var path := "user://free_room_editor_test.json"
	check(Store.write_config(path,model.config).error.is_empty(),"variable size draft saved")
	var loaded: Dictionary = Store.read_config(path)
	check(loaded.error.is_empty() and loaded.config == JSON.parse_string(JSON.stringify(model.config)),"variable size roundtrip")
	DirAccess.remove_absolute(path)
	print("FREE_ROOM checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
