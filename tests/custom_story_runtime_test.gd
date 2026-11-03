extends SceneTree
## Real current-world scenes use Custom module geometry and isolated progression.

const Data = preload("res://src/custom/custom_story_data.gd")
const StorySave = preload("res://src/save/story_save.gd")
const Profile = preload("res://src/progress/profile.gd")
const SCENES := {"krypta": "res://src/hell/krypta_dungeon.tscn", "frost": "res://src/hell/frost_dungeon.tscn", "hell": "res://src/hell/hell_dungeon.tscn"}
var checked: int = 0
var failures: int = 0
var scratch: String = ""


func _initialize() -> void:
	scratch = "res://tests/.tmp_custom_runtime_%d" % Time.get_ticks_usec()
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	var source_path := scratch + "/source_profile.json"
	var source := Profile.fresh(Profile.data())
	Profile.save_profile(source, source_path)
	var source_before := FileAccess.get_file_as_string(source_path)
	for world: String in SCENES:
		var record: Dictionary = Data.fresh_story(world, "Custom runtime fixture")
		record.floor_count = 2
		var game: Node = _scene(record, source_path)
		root.add_child(game)
		current_scene = game
		game.set_process(false)
		check(not game._custom_load_failed and not game.W.is_empty(), world + ": module floor loads")
		if game.W.is_empty():
			game.queue_free()
			await process_frame
			continue
		check(str(game.theme.world_id) == world, world + ": current Story theme is retained")
		check(game.floors_raw.size() == 2 and int(game.W.cell) == 96, world + ": custom floor count and current-world units")
		check(game.profile_path.begins_with(scratch) and game.profile_path != source_path, world + ": copied profile is isolated")
		check(game.saves.dir == StorySave.custom_saves_dir(record, false, scratch), world + ": save slots are isolated")
		check(game.heroic() and game.story_items != null and game.talents != null, world + ": real hero talents and inventory are connected")
		var kinds: Array = game.W.ents.map(func(e: Dictionary) -> String: return str(e.type))
		check(kinds.has("shop") and kinds.has("npc") and kinds.has("chest") and kinds.has("portal"), world + ": shop with merchant, treasure chest and boss portal are on the floor (%s)" % [kinds])
		check(game.W.props.any(func(p: Dictionary) -> bool: return str(p.name) == "shop_table"), world + ": the shop has its merchant table")
		game._process(0.0)
		game._process(1.0 / 15.0)
		check(is_equal_approx(float(game.state.t), 4.0 / 60.0), world + ": Custom run retains fixed simulation timing")
		check(game.save_slot(1), world + ": Custom save writes")
		var saved: Dictionary = game.saves.read(world, 1)
		var seed_before: int = int(game.state.world_run)
		var geometry_before := str(game.W.grid)
		game.custom_story.title = "Changed draft"
		check(str(saved.custom_story.title) == "Custom runtime fixture", world + ": save keeps an independent content snapshot")
		game.queue_free()
		await process_frame
		var again: Node = _scene(record, source_path)
		again.resume = saved
		root.add_child(again)
		current_scene = again
		again.set_process(false)
		check(int(again.state.world_run) == seed_before and str(again.W.grid) == geometry_before, world + ": resume reconstructs the same generated geometry")
		check(str(again.custom_story.title) == "Custom runtime fixture", world + ": resume uses saved content, not changed draft")
		again.load_floor(2, true)
		check(int(again.state.floor) == 2 and bool(again.W.final), world + ": custom final floor is independent of ten-floor main stories")
		again.queue_free()
		await process_frame
		var preview: Node = _scene(record, source_path)
		preview.custom_preview_room = str(record.rooms[1].id)
		root.add_child(preview)
		current_scene = preview
		preview.set_process(false)
		check(preview.W.rooms.size() == 1 and preview.floors_raw.size() == 1, world + ": selected room tests in its own current-world scene")
		check(not preview.save_slot(1), world + ": room preview cannot overwrite run slots")
		preview.queue_free()
		await process_frame
	check(FileAccess.get_file_as_string(source_path) == source_before, "source profile was never modified by Custom play, resume or preview")
	_cleanup(scratch)
	print("CUSTOM_STORY_RUNTIME checked=%d failures=%d" % [checked, failures])
	quit(1 if failures else 0)


func _scene(record: Dictionary, source_path: String) -> Node:
	var game: Node = (load(str(SCENES[str(record.world)])) as PackedScene).instantiate()
	game.custom_story = record.duplicate(true)
	game.custom_storage_root = scratch
	game.profile_path = source_path
	game.settings_path = scratch + "/settings.cfg"
	game.graphics_path = game.settings_path
	game.class_id = "mage"
	game.mouse_taken = true
	game.keys_taken = true
	return game


func _cleanup(path: String) -> void:
	for name: String in DirAccess.get_directories_at(path): _cleanup(path.path_join(name))
	for name: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func check(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("CUSTOM_STORY_RUNTIME_FAIL " + message)
