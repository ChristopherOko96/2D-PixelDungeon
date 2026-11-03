extends SceneTree
const Data = preload("res://src/custom/custom_story_data.gd")
const World = preload("res://src/custom/custom_story_world.gd")
const FloorData = preload("res://src/hell/hell_floor_data.gd")
var checked := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, text: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("CUSTOM_STORY_DATA_FAIL " + text)

func _run() -> void:
	for world: String in Data.WORLDS:
		var story: Dictionary = Data.fresh_story(world)
		check(Data.validate(story, true).is_empty(), world + ": example can play " + str(Data.validate(story, true)))
		var variations := {}
		for seed_value in range(1, 16):
			var generator: RefCounted = World.new(story)
			var raw: Dictionary = generator.build_raw(1, seed_value)
			check(not raw.is_empty(), world + ": seed builds " + str(generator.last_errors))
			if raw.is_empty(): continue
			check(raw == generator.build_raw(1, seed_value), world + ": same seed repeats exactly")
			variations[JSON.stringify(raw.room_at).sha256_text()] = true
			var floor: Dictionary = FloorData.prepare(raw)
			check(floor.rooms.size() == int(story.rooms_per_floor), world + ": expected room count")
			check(_connected(floor), world + ": all painted floor and connectors connected")
			check(floor.rooms.filter(func(r: Dictionary) -> bool: return r.type == "start").size() == 1 and floor.rooms.filter(func(r: Dictionary) -> bool: return r.type == "boss").size() == 1, world + ": one start and one boss")
			check(floor.doors.size() == floor.rooms.size() - 1, world + ": connected room tree")
			check(floor.ents.any(func(e: Dictionary) -> bool: return e.type == "portal" and not bool(e.active)), world + ": closed boss exit")
		check(variations.size() > 10, world + ": seeds make different layouts")
		var selected: Dictionary = story.rooms[1]
		var preview: Dictionary = World.new(story, str(selected.id)).build_raw(1, 42)
		check(not preview.is_empty() and preview.rooms.size() == 1 and preview.rooms[0].type == "start" and preview.rooms[0].preview_role == "combat", world + ": exact selected-room preview")
		check(preview.ents.any(func(e: Dictionary) -> bool: return e.type == "portal" and bool(e.active)), world + ": preview can finish")
	_test_drafts_and_storage()
	print("CUSTOM_STORY_DATA checked=%d failures=%d" % [checked, failures])
	quit(1 if failures > 0 else 0)

func _connected(floor: Dictionary) -> bool:
	var walk: Array = []
	for i in range(floor.grid.size()):
		if int(floor.grid[i]) == 1: walk.append(i)
	if walk.is_empty(): return false
	var seen := {walk[0]: true}
	var todo: Array = [walk[0]]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		for offset: int in [-1, 1, -int(floor.cols), int(floor.cols)]:
			var next := i + offset
			if next >= 0 and next < floor.grid.size() and int(floor.grid[next]) == 1 and not seen.has(next):
				seen[next] = true
				todo.append(next)
	return seen.size() == walk.size()

func _test_drafts_and_storage() -> void:
	var story: Dictionary = Data.fresh_story()
	var room: Dictionary = story.rooms[1]
	room.floor.clear()
	check(Data.validate(story).is_empty() and not Data.validate(story, true).is_empty(), "an incomplete draft can save but not play")
	check(not Data.valid_id("../escape"), "path traversal rejected")
	var folder := "res://tests/.tmp_custom_data_%d" % Time.get_ticks_usec()
	var result: Dictionary = Data.save_story(story, folder)
	check(str(result.error).is_empty() and int(result.story.revision) == 1, "draft saved with revision")
	check(Data.list_stories(folder).size() == 1 and Data.load_story(str(story.id), folder).title == story.title, "saved story listed and loaded")
	result = Data.save_story(result.story, folder)
	check(int(result.story.revision) == 2, "revision increases")
	for file: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
