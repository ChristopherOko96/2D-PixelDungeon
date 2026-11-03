extends SceneTree
## Pure save/schema regressions: no profiles or persistent files are opened.

const StorySave = preload("res://src/save/story_save.gd")
var checked: int = 0
var failures: int = 0

class FakeStory extends Node:
	var class_id: String = "mage"
	var state: Dictionary = {"floor": 2, "hp": 9, "level": 3, "run_id": "custom-test", "world_run": 4711}
	var W: Dictionary = {"title": "Raum A1"}
	var custom_story: Dictionary = {"id": "mine", "revision": 4, "rooms": [{"title": "Original"}]}
	var custom_preview_room: String = ""


func _initialize() -> void:
	var game := FakeStory.new()
	var data := StorySave.capture(game)
	check(data.custom_story.id == "mine" and int(data.custom_story.revision) == 4, "save embeds the selected Custom story and its revision")
	check(int(data.keep.world_run) == 4711, "the layout run seed is retained")
	game.custom_story.rooms[0].title = "Edited afterwards"
	check(str(data.custom_story.rooms[0].title) == "Original", "later room edits cannot mutate a saved run")
	check(StorySave.custom_saves_dir(game.custom_story) == "user://custom_story_saves/mine/", "slots have a per-story directory")
	check(StorySave.custom_saves_dir(game.custom_story, true) != StorySave.custom_saves_dir(game.custom_story), "playtests cannot share run slots")
	check(StorySave.custom_profile_path(game.custom_story) == "user://custom_story_profiles/mine.json", "progression has a per-story profile")
	check(StorySave.custom_profile_path(game.custom_story, true) != StorySave.custom_profile_path(game.custom_story), "playtests cannot share earned progression")
	check(StorySave.custom_saves_dir(game.custom_story, false, "res://test/") == "res://test/saves/mine/", "fixtures may isolate all writes")
	check(not StorySave.custom_key({"id": "../../other"}).contains("/"), "untrusted ids never become path traversal")
	game.custom_story = {}
	check(not StorySave.capture(game).has("custom_story"), "ordinary stories keep the original save schema")
	game.free()
	print("CUSTOM_STORY_SAVE checked=%d failures=%d" % [checked, failures])
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("CUSTOM_STORY_SAVE_FAIL " + message)
