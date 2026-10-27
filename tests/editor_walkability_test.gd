extends SceneTree
## Manual collision edits remain independent of all authored artwork.
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("EDITOR_WALKABILITY_FAIL ",label)
func fixture() -> Dictionary:
	var rooms: Array = []
	for index in range(4):
		rooms.append({"id":"walk_%d" % index,"title":"WALK%d" % index,"boss":index == 3,"layout_mode":"freeform","world_size":[512,384],"play_bounds":[0,0,512,384],"obstacles_tiles":[],"painted_tiles":[{"x":2,"y":2,"tile":"violet_002","rotation":1,"solid":true,"layer":"structure"}],"authored_doors":[{"x":3,"y":2,"tile":"items_002","rotation":1,"side":"east"}],"stairs_spawn":[144,80],"stairs_art":{"tile":"violet_000","rotation":0},"player_spawns":[[80,112]],"enemy_spawns":[],"brazier_spawns":[[80,80]],"reward_spawn":[112,80]})
	return {"schema_version":1,"generator_version":4,"tile_size":32,"world_size":[896,480],"play_bounds":[32,48,832,400],"max_actor_radius":24,"templates":rooms}
func override_at(model: RefCounted, cell: Vector2i) -> Dictionary:
	for entry: Dictionary in model.template().get("collision_overrides",[]):
		if int(entry.x) == cell.x and int(entry.y) == cell.y: return entry
	return {}
func _initialize() -> void:
	var Model = load("res://src/dungeon_editor_model.gd")
	var source := fixture()
	var original := source.duplicate(true)
	var model = Model.new(source)
	check(model.has_method("set_area_walkability"),"selected areas support independent walkability")
	if not model.has_method("set_area_walkability"):
		finish()
		return
	var before: Dictionary = model.config.duplicate(true)
	var result: Dictionary = model.set_area_walkability(Rect2i(2,2,3,2),true)
	check(result.error.is_empty() and result.changed == 6,"whole selected area receives explicit walkable state")
	check(override_at(model,Vector2i(2,2)).get("blocked") == false and override_at(model,Vector2i(4,3)).get("blocked") == false,"walls and empty cells may both become walkable")
	var graphic_copy: Dictionary = model.template().duplicate(true)
	graphic_copy.erase("collision_overrides")
	check(graphic_copy == before.templates[0] and model.config.templates[1] == before.templates[1],"art spawns ports stairs props and other rooms are unchanged")
	check(model._undo.size() == 1,"one complete collision operation has one undo entry")
	model.undo()
	check(model.config == before,"one undo restores exact metadata")
	model.redo()
	check(model.template().collision_overrides.size() == 6,"one redo restores collision area")
	var history: int = model._undo.size()
	result = model.set_area_walkability(Rect2i(2,2,3,2),true)
	check(result.changed == 0 and model._undo.size() == history,"same state is a no-op without history")
	result = model.set_area_walkability(Rect2i(3,2,1,1),false)
	check(result.changed == 1 and override_at(model,Vector2i(3,2)).blocked and not override_at(model,Vector2i(2,2)).blocked,"blocking a subset leaves neighboring overrides intact")
	model.begin_edit()
	model.paint_tile(Vector2i(2,2),"amber_017",0,false,"structure")
	model.end_edit()
	check(override_at(model,Vector2i(2,2)).is_empty() and override_at(model,Vector2i(3,2)).blocked,"painting resets only its own manual collision")
	model.undo()
	check(override_at(model,Vector2i(2,2)).get("blocked") == false,"painting undo restores manual collision too")
	model.begin_edit()
	model.set_authored_door(Vector2i(3,2),"east","items_002",1)
	model.end_edit()
	check(override_at(model,Vector2i(3,2)).is_empty(),"deliberately placing a door resets its prior manual collision")
	model.undo()
	check(override_at(model,Vector2i(3,2)).blocked,"door undo restores prior blocking")
	result = model.edit_area(Rect2i(2,2,2,1),"violet_017",0,false,"floor",false,false)
	check(result.changed == 2 and override_at(model,Vector2i(2,2)).is_empty() and override_at(model,Vector2i(3,2)).is_empty() and not override_at(model,Vector2i(4,2)).is_empty(),"area repaint clears manual states only inside its scope")
	model.undo()
	check(not override_at(model,Vector2i(2,2)).is_empty() and override_at(model,Vector2i(3,2)).blocked,"bulk repaint undo restores collision mask")
	model = Model.new(fixture())
	model.set_area_walkability(Rect2i(2,2,1,1),false)
	result = model.edit_area(Rect2i(2,2,1,1),"violet_002",1,true,"structure",false,false)
	check(result.changed == 1 and override_at(model,Vector2i(2,2)).is_empty(),"identical artwork repaint still commits explicit collision reset")
	model.undo()
	check(override_at(model,Vector2i(2,2)).blocked,"undo recovers mask-only reset")
	var preserved: Dictionary = model.config.duplicate(true)
	model.begin_edit()
	model.paint_tile(Vector2i(2,2),"invalid",0,false,"floor")
	model.end_edit()
	check(model.config == preserved,"rejected paint cannot silently clear manual collision")
	model.begin_edit()
	model.paint_floor(Vector2i(2,2),"violet_017",0,true)
	model.end_edit()
	check(override_at(model,Vector2i(2,2)).is_empty(),"deliberate layer erasure resets cell collision")
	model = Model.new(fixture())
	result = model.set_area_walkability(Rect2i(-1,-1,3,3),false)
	check(result.changed == 4 and model.template().collision_overrides.size() == 4,"negative origin clips safely to canvas")
	var clipped_before: Dictionary = model.config.duplicate(true)
	result = model.set_area_walkability(Rect2i(2147483640,0,20,1),false)
	check(result.changed == 0 and model.config == clipped_before,"end overflow does not wrap onto map")
	check(not model.set_area_walkability(Rect2i(0,0,-1,1),false).error.is_empty() and not model.set_area_walkability(Rect2i(0,0,65,1),false).error.is_empty(),"invalid area dimensions fail before mutation")
	model.set_area_walkability(Rect2i(15,11,1,1),true)
	check(not model.resize_room(Vector2i(12,10)).is_empty(),"resizing cannot silently crop collision overrides")
	model.create_room()
	check(not model.template().has("collision_overrides"),"new blank room never inherits previous mask")
	check(source == original,"authoring preserves source dictionary")
	var legacy := fixture()
	legacy.templates[0].erase("layout_mode")
	legacy.templates[0].play_bounds = [32,64,448,288]
	model = Model.new(legacy)
	result = model.set_area_walkability(Rect2i(0,0,3,3),true)
	check(result.changed == 2 and override_at(model,Vector2i.ZERO).is_empty(),"legacy protected exterior cells cannot be manually opened")
	model.begin_edit()
	model.paint_wall(Vector2i(1,2),true)
	model.end_edit()
	check(override_at(model,Vector2i(1,2)).is_empty() and not override_at(model,Vector2i(2,2)).is_empty(),"legacy wall brush resets only its own mask")
	var large := fixture()
	large.templates[0].world_size = [2048,1536]
	large.templates[0].play_bounds = [0,0,2048,1536]
	model = Model.new(large)
	result = model.set_area_walkability(Rect2i(0,0,64,48),true)
	check(result.changed == 3072 and model.template().collision_overrides.size() == 3072 and model._undo.size() == 1,"maximum canvas is handled in one bounded batch")
	finish()
func finish() -> void:
	print("EDITOR_WALKABILITY checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
