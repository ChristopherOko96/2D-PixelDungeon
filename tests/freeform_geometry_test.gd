extends SceneTree
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const Store = preload("res://src/dungeon_editor_store.gd")
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("FREEFORM_GEOMETRY_FAIL ",label)
func fixture() -> Dictionary:
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
		room.authored_doors = [{"x":2,"y":6,"side":"west","tile":"items_002","rotation":3}]
		if not room.boss: room.authored_doors.append({"x":13,"y":6,"side":"east","tile":"items_002","rotation":1})
		else:
			room.stairs_spawn = [320,208]
			room.stairs_art = {"tile":"violet_000","rotation":2}
	return config
func _initialize() -> void:
	var config := fixture()
	check(Dungeon.valid_room_dimensions(config.templates[0],config),"free canvas dimensions include outer cells")
	if not Dungeon.valid_room_dimensions(config.templates[0],config):
		finish()
		return
	check(Dungeon.validate_config(config).is_empty(),"painted floor and authored ports form publishable library")
	var source := config.duplicate(true)
	var preview := Dungeon.preview_template(config.templates[0],config)
	check(preview.exits.size() == 2,"preview contains only two explicitly authored doors")
	check(preview.exits[0].rect == [64.0,192.0,32.0,32.0],"door keeps chosen interior canvas position")
	check(Dungeon.segment_blocked(Vector2(16,16),Vector2(16,16),12,preview),"unpainted void blocks movement")
	check(not Dungeon.segment_blocked(Vector2(208,208),Vector2(208,208),12,preview),"painted floor allows movement")
	var room: Dictionary = config.templates[0]
	room.painted_tiles.append({"x":6,"y":6,"tile":"violet_007","rotation":1,"solid":true,"layer":"structure"})
	check(Dungeon.valid_painted_tiles(room.painted_tiles,Rect2(0,0,512,384)),"floor and structure coexist at same cell")
	preview = Dungeon.preview_template(room,config)
	check(Dungeon.segment_blocked(Vector2(208,208),Vector2(208,208),12,preview),"authored wall blocks host movement")
	room.painted_tiles.pop_back()
	var generated := Dungeon.generate(24680,3,config)
	var selected_order := Dungeon.selected_room_order(3,3,config,str(config.templates[1].id))
	check(selected_order.size() == 3 and selected_order[0] == config.templates[1].id,"isolated normal test picks compatible sequence starting with selected room")
	var selected_boss_order := Dungeon.selected_room_order(3,3,config,str(config.templates[3].id))
	check(selected_boss_order.size() == 3 and selected_boss_order[-1] == config.templates[3].id,"isolated boss test ends with chosen boss")
	check(generated.size() == 3,"generator assembles authored compatible ports")
	if generated.size() == 3:
		check(generated[0].template_id != generated[1].template_id,"compatible normal room alternatives remain varied")
		check(generated[2].exits[-1].tile == "violet_000" and generated[2].exits[-1].rotation == 2,"explicit stairs retain selected art and rotation")
		check(generated[0].exits.size() == 1 and generated[1].exits.size() == 2 and generated[2].exits.size() == 2,"runtime activates only linked ports plus explicit boss stairs")
		check(generated == Dungeon.generate(24680,3,config),"freeform generation deterministic")
		for layout: Dictionary in generated:
			for exit: Dictionary in layout.exits:
				if exit.kind == "door": check(exit.entry_spawns.size() == 4,"authored port retains four clear party arrivals")
	var blank: Dictionary = config.templates[0].duplicate(true)
	blank.painted_tiles = []
	blank.authored_doors = []
	blank.player_spawns = []
	blank.enemy_spawns = []
	var empty_preview := Dungeon.preview_template(blank,config)
	check(empty_preview.exits.is_empty() and empty_preview.obstacles.size() == 1,"empty draft has no automatic door and one merged void obstacle")
	var partial := config.duplicate(true)
	partial.templates[0] = blank
	var path := "user://freeform_geometry_draft.json"
	check(Store.write_config(path,partial).error.is_empty(),"unfinished blank draft saves")
	var loaded := Store.read_config(path)
	check(loaded.error.is_empty() and loaded.config.templates[0].player_spawns.is_empty(),"unfinished blank draft loads without fabricated starts")
	var original_file := FileAccess.get_file_as_string(path)
	var oversized := partial.duplicate(true)
	oversized.notes = "x".repeat(2097152)
	check(not Store.write_config(path,oversized).error.is_empty() and FileAccess.get_file_as_string(path) == original_file,"oversized draft cannot overwrite readable original")
	DirAccess.remove_absolute(path)
	check(not Dungeon.validate_config(partial).is_empty(),"unfinished draft cannot enter runtime")
	var impossible := config.duplicate(true)
	for value: Dictionary in impossible.templates: value.authored_doors = [value.authored_doors[0]]
	check(not Dungeon.validate_config(impossible).is_empty() and Dungeon.generate(1,3,impossible).is_empty(),"incompatible ports fail instead of fabricating exits")
	var malformed := config.duplicate(true)
	malformed.templates[0].authored_doors[0].side = "diagonal"
	check(not Dungeon.validate_config(malformed).is_empty(),"invalid authored side rejected")
	var island := config.duplicate(true)
	island.templates[0].painted_tiles.append({"x":0,"y":0,"tile":"violet_017","rotation":0,"solid":false,"layer":"floor"})
	check(not Dungeon.validate_config(island).is_empty(),"small painted island cannot hide outside boss navigation lattice")
	var wrapped_floor := [{"x":4294967296,"y":0,"tile":"violet_017","rotation":0,"solid":false,"layer":"floor"}]
	check(not Dungeon.valid_painted_tiles(wrapped_floor,Rect2(0,0,512,384)),"large JSON floor coordinate cannot wrap into canvas")
	var wrapped_door := [{"x":4294967296,"y":0,"tile":"items_002","rotation":0,"side":"north"}]
	check(not Dungeon.valid_authored_doors(wrapped_door,Rect2(0,0,512,384)),"large JSON door coordinate cannot wrap into canvas")
	check(config == source,"generation and preview preserve authored library")
	finish()
func finish() -> void:
	print("FREEFORM_GEOMETRY checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
