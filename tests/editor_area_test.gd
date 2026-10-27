extends SceneTree
## Pure in-memory area operations, never writes the user's map or game files.
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("EDITOR_AREA_FAIL ",label)
func fixture() -> Dictionary:
	var rooms: Array = []
	for index in range(4):
		var room := {"id":"area_%d" % index,"title":"AREA%d" % index,"boss":index == 3,"layout_mode":"freeform","world_size":[512,384],"play_bounds":[0,0,512,384],"obstacles_tiles":[],"painted_tiles":[],"authored_doors":[],"player_spawns":[[80,112]],"enemy_spawns":[],"brazier_spawns":[[80,80]],"reward_spawn":[112,80],"reward_visible":true}
		for y in range(2,4):
			for x in range(2,5): room.painted_tiles.append({"x":x,"y":y,"tile":"violet_017","rotation":0,"solid":false,"layer":"floor"})
		room.painted_tiles.append({"x":2,"y":2,"tile":"violet_002","rotation":1,"solid":true,"layer":"structure"})
		room.painted_tiles.append({"x":7,"y":7,"tile":"amber_017","rotation":0,"solid":false,"layer":"floor"})
		room.authored_doors = [{"x":3,"y":2,"tile":"items_002","rotation":1,"side":"east"}]
		room.stairs_spawn = [144,80]
		room.stairs_art = {"tile":"violet_000","rotation":0}
		rooms.append(room)
	return {"schema_version":1,"generator_version":4,"tile_size":32,"world_size":[896,480],"play_bounds":[32,48,832,400],"max_actor_radius":24,"templates":rooms}
func find_cell(room: Dictionary, cell: Vector2i, layer: String) -> Dictionary:
	for entry: Dictionary in room.painted_tiles:
		if entry.x == cell.x and entry.y == cell.y and entry.get("layer","") == layer: return entry
	return {}
func _initialize() -> void:
	var Model = load("res://src/dungeon_editor_model.gd")
	var source := fixture()
	var original := source.duplicate(true)
	var model = Model.new(source)
	check(model.has_method("edit_area"),"atomic selected area operation exists")
	if not model.has_method("edit_area"):
		finish()
		return
	var before: Dictionary = model.config.duplicate(true)
	var result: Dictionary = model.edit_area(Rect2i(2,2,3,1),"rose_018",3,false,"floor",false,true)
	check(result.error.is_empty() and result.changed == 3,"three selected cells are replaced in one operation")
	check(find_cell(model.template(),Vector2i(2,2),"floor").tile == "rose_018" and find_cell(model.template(),Vector2i(2,2),"structure").is_empty(),"visible replacement clears selected overlying wall")
	check(model.template().authored_doors.is_empty() and not model.template().has("stairs_spawn") and not model.template().has("stairs_art"),"replacement clears selected doors and stairs")
	check(model.template().player_spawns == before.templates[0].player_spawns and model.template().brazier_spawns == before.templates[0].brazier_spawns and model.template().reward_spawn == before.templates[0].reward_spawn,"spawn fire and chest survive area edits")
	check(find_cell(model.template(),Vector2i(7,7),"floor") == find_cell(before.templates[0],Vector2i(7,7),"floor") and model.config.templates[1] == before.templates[1],"outside cells and other rooms remain unchanged")
	check(model._undo.size() == 1,"whole replacement consumes one undo entry")
	model.undo()
	check(model.config == before,"one undo restores tiles ports and stair metadata together")
	model.redo()
	check(model.template().authored_doors.is_empty() and find_cell(model.template(),Vector2i(2,2),"floor").rotation == 3,"redo restores complete operation")
	var history: int = model._undo.size()
	result = model.edit_area(Rect2i(2,2,3,1),"rose_018",3,false,"floor",false,true)
	check(result.changed == 0 and model._undo.size() == history,"identical repaint does not consume undo history")
	model = Model.new(fixture())
	result = model.edit_area(Rect2i(2,2,3,1),"moss_017",1,false,"floor",false,false)
	check(result.changed == 3 and not find_cell(model.template(),Vector2i(2,2),"structure").is_empty() and model.template().authored_doors.size() == 1 and model.template().has("stairs_spawn"),"layer-only replace preserves wall and functional overlays")
	result = model.edit_area(Rect2i(2,2,3,1),"",0,false,"floor",true,false)
	check(result.changed == 3 and not find_cell(model.template(),Vector2i(2,2),"structure").is_empty() and model.template().authored_doors.size() == 1,"layer-only erase preserves unrelated layers and doorway")
	result = model.edit_area(Rect2i(2,2,3,1),"",0,false,"structure",true,true)
	check(result.changed == 3 and model.template().authored_doors.is_empty() and not model.template().has("stairs_spawn"),"visible erase removes both tile layers and functional overlays")
	check(find_cell(model.template(),Vector2i(2,2),"floor").is_empty() and find_cell(model.template(),Vector2i(2,2),"structure").is_empty(),"erased freeform area returns to void")
	model.undo()
	check(not find_cell(model.template(),Vector2i(2,2),"structure").is_empty() and model.template().authored_doors.size() == 1,"one undo restores erased selected area")
	model = Model.new(fixture())
	result = model.edit_area(Rect2i(-1,-1,3,3),"amber_017",0,false,"floor",false,true)
	check(result.changed == 4 and not find_cell(model.template(),Vector2i.ZERO,"floor").is_empty() and find_cell(model.template(),Vector2i(-1,-1),"floor").is_empty(),"selection clips to full editable cells before iteration")
	var bounded_before: Dictionary = model.config.duplicate(true)
	check(model.edit_area(Rect2i(2147483640,0,20,1),"amber_017",0,false,"floor",false,true).changed == 0 and model.config == bounded_before,"32-bit rectangle end overflow cannot wrap onto real canvas")
	check(not model.edit_area(Rect2i(0,0,-1,1),"amber_017",0,false,"floor",false).error.is_empty() and not model.edit_area(Rect2i(0,0,65,1),"amber_017",0,false,"floor",false).error.is_empty(),"negative and oversized areas fail closed")
	check(not model.edit_area(Rect2i(0,0,1,1),"../../bad",0,false,"floor",false).error.is_empty() and model.config == bounded_before,"invalid art fails before modifying any content")
	check(source == original,"authoring never mutates its original input dictionary")
	var large := fixture()
	large.templates[0].world_size = [2048,1536]
	large.templates[0].play_bounds = [0,0,2048,1536]
	model = Model.new(large)
	result = model.edit_area(Rect2i(0,0,64,48),"violet_017",0,false,"floor",false,true)
	check(result.changed > 3000 and model.template().painted_tiles.size() == 3072 and model._undo.size() == 1,"full maximum canvas paints in one bounded transaction")
	result = model.edit_area(Rect2i(0,0,64,48),"violet_002",1,true,"structure",false,false)
	check(result.changed == 3072 and model.template().painted_tiles.size() == 6144,"maximum two-layer canvas remains within supported tile cap")
	# Older rectangular rooms still retain automatic floor but clear only selected cover.
	var legacy := fixture()
	legacy.templates[0].erase("layout_mode")
	legacy.templates[0].play_bounds = [32,64,448,288]
	legacy.templates[0].obstacles_tiles = [[2,2,3,2]]
	legacy.templates[0].painted_tiles = []
	model = Model.new(legacy)
	result = model.edit_area(Rect2i(2,2,2,1),"rose_017",0,false,"floor",false,true)
	check(result.changed == 2 and not model.wall_cells().has(Vector2i(2,2)) and model.wall_cells().has(Vector2i(4,2)) and model.wall_cells().has(Vector2i(2,3)),"legacy area replacement clears only selected wall cells")
	model.undo()
	check(model.template().obstacles_tiles == [[2,2,3,2]],"legacy wall rectangle restored by single undo")
	finish()
func finish() -> void:
	print("EDITOR_AREA checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
