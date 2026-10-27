extends SceneTree
var Dungeon = load("res://src/dungeon/dungeon_generator.gd")
const Store = preload("res://src/dungeon_editor_store.gd")
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("WALK_GEOMETRY_FAIL ",label)
func fixture() -> Dictionary:
	var rooms: Array = []
	for index in range(4):
		var room := {"id":"walk_%d" % index,"title":"WALK%d" % index,"boss":index == 3,"layout_mode":"freeform","world_size":[512,384],"play_bounds":[0,0,512,384],"obstacles_tiles":[],"painted_tiles":[],"player_spawns":[[144,144],[176,144],[208,144],[240,144]],"enemy_spawns":[[336,144],[368,176],[304,208],[336,240],[368,272]],"brazier_spawns":[],"authored_doors":[{"x":2,"y":6,"side":"west","tile":"items_002","rotation":3}]}
		for y in range(2,10):
			for x in range(2,14): room.painted_tiles.append({"x":x,"y":y,"tile":"violet_017","rotation":0,"solid":false,"layer":"floor"})
		if index == 3: room.stairs_spawn = [320,208]
		else: room.authored_doors.append({"x":13,"y":6,"side":"east","tile":"items_002","rotation":1})
		rooms.append(room)
	return {"schema_version":1,"generator_version":4,"tile_size":32,"world_size":[896,480],"play_bounds":[32,48,832,400],"max_actor_radius":24,"templates":rooms}
func _initialize() -> void:
	var config := fixture()
	check(Dungeon.has_method("valid_collision_overrides"),"override geometry API exists")
	if not Dungeon.has_method("valid_collision_overrides"):
		finish()
		return
	check(Dungeon.validate_config(config).is_empty(),"base freeform fixture is publishable")
	var before := config.duplicate(true)
	var room: Dictionary = config.templates[0]
	var layout: Dictionary = Dungeon.preview_template(room,config)
	check(not layout.has("visual_obstacles") and not layout.has("collision_overrides"),"absence preserves previous layout fields")
	room.painted_tiles.append({"x":6,"y":6,"tile":"rose_007","rotation":3,"solid":true,"layer":"structure"})
	var artwork: Array = room.painted_tiles.duplicate(true)
	room.collision_overrides = [{"x":6,"y":6,"blocked":false}]
	layout = Dungeon.preview_template(room,config)
	check(not Dungeon.segment_blocked(Vector2(208,208),Vector2(208,208),12,layout),"manual walkable overrides a solid sprite")
	check(Dungeon.move_actor(Vector2(176,208),Vector2(64,0),12,layout).is_equal_approx(Vector2(240,208)),"host actor movement crosses formerly solid art")
	check(not Dungeon.segment_blocked(Vector2(176,208),Vector2(240,208),5,layout),"projectile sweep uses unblocked mask")
	check(Dungeon.find_path(Vector2(176,208),Vector2(240,208),12,layout).size() == 1,"pathfinding uses unblocked mask")
	check(layout.visual_obstacles.has([192.0,192.0,32.0,32.0]) and room.painted_tiles == artwork and layout.painted_tiles == artwork,"visual obstacle and original sprite remain unchanged")
	room.collision_overrides = [{"x":6,"y":6,"blocked":true}]
	layout = Dungeon.preview_template(room,config)
	check(Dungeon.segment_blocked(Vector2(176,208),Vector2(240,208),5,layout),"manual block stops projectile sweep")
	check(Dungeon.move_actor(Vector2(176,208),Vector2(64,0),12,layout).x < 192,"manual block stops host actor")
	room.painted_tiles.pop_back()
	layout = Dungeon.preview_template(room,config)
	check(Dungeon.segment_blocked(Vector2(208,208),Vector2(208,208),12,layout),"block applies without any solid art")
	check(layout.visual_obstacles.is_empty(),"manual block never creates a visual pillar")
	room.collision_overrides = [{"x":1,"y":6,"blocked":false}]
	layout = Dungeon.preview_template(room,config)
	check(not Dungeon.segment_blocked(Vector2(48,208),Vector2(48,208),12,layout),"manual walkable opens an unpainted void cell")
	check(Dungeon.find_path(Vector2(80,208),Vector2(48,208),12,layout).size() == 1,"new invisible walkable cell joins normal floor")
	check(Dungeon.validate_config(config).is_empty(),"connected manual floor passes full validation")
	room.collision_overrides.append({"x":0,"y":0,"blocked":false})
	check(not Dungeon.validate_config(config).is_empty(),"isolated manual walkable island is rejected")
	room.collision_overrides = [{"x":1,"y":6,"blocked":true}]
	layout = Dungeon.preview_template(room,config)
	check(Dungeon.segment_blocked(Vector2(48,208),Vector2(48,208),12,layout),"block applies to an empty cell")
	var bounds := Rect2(0,0,512,384)
	check(not Dungeon.valid_collision_overrides([{"x":4294967296,"y":0,"blocked":false}],bounds),"original coordinate overflow fails before narrowing")
	check(not Dungeon.valid_collision_overrides([{"x":2,"y":2,"blocked":1}],bounds),"blocked must be boolean")
	check(not Dungeon.valid_collision_overrides([{"x":2,"y":2,"blocked":true},{"x":2,"y":2,"blocked":false}],bounds),"duplicate coordinates rejected")
	check(not Dungeon.valid_collision_overrides([{"x":2.5,"y":2,"blocked":true}],bounds),"fractional cell coordinates rejected")
	var path := "user://walkability_geometry_test.json"
	Store.write_config(path,config)
	var loaded := Store.read_config(path)
	check(loaded.error.is_empty() and loaded.config.templates[0].collision_overrides[0].blocked,"override metadata survives JSON roundtrip")
	var invalid := config.duplicate(true)
	invalid.templates[0].collision_overrides[0].blocked = "false"
	Store.write_config(path,invalid)
	check(not Store.read_config(path).error.is_empty(),"file importer rejects invalid override types")
	DirAccess.remove_absolute(path)
	var legacy: Dictionary = before.templates[0].duplicate(true)
	legacy.erase("layout_mode")
	legacy.play_bounds = [32,64,448,288]
	legacy.obstacles_tiles = [[6,6,2,1]]
	legacy.painted_tiles = []
	legacy.collision_overrides = [{"x":6,"y":6,"blocked":false}]
	layout = Dungeon.preview_template(legacy,config)
	check(not Dungeon.segment_blocked(Vector2(208,208),Vector2(208,208),12,layout) and Dungeon.segment_blocked(Vector2(240,208),Vector2(240,208),12,layout),"legacy override opens only selected portion of wall")
	check(layout.visual_obstacles.has([192.0,192.0,64.0,32.0]),"legacy complete visual footprint survives")
	check(before == fixture(),"baseline fixture input remains independent")
	finish()
func finish() -> void:
	print("WALKABILITY_GEOMETRY checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
