extends SceneTree
## One world id per story world (BAUPLAN M0a): the three theme files name it
## ("world_id": krypta, frost, hell) and the three places that used to guess it from
## a file name read it instead: the save folder (src/save/story_save.gd mode), the
## main menu's FORTSETZEN (src/main_menu.gd _save_mode_of) and the sound world
## (src/hero/story_sound.gd world_of). A theme without the key keeps the old rule,
## so saves written before it land in the same folder.

const StorySave = preload("res://src/save/story_save.gd")
const StorySound = preload("res://src/hero/story_sound.gd")
const MainMenu = preload("res://src/main_menu.gd")
## theme file -> its world id, the scene that runs it
const WORLDS := {
	"res://assets/data/krypta_theme.json": {"id": "krypta", "scene": "res://src/hell/krypta_dungeon.tscn"},
	"res://assets/data/frost_theme.json": {"id": "frost", "scene": "res://src/hell/frost_dungeon.tscn"},
	"res://assets/data/hell_theme.json": {"id": "hell", "scene": "res://src/hell/hell_dungeon.tscn"},
}
const AUDIO_RULES := "res://assets/data/audio_rules.json"

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("WORLD_ID_FAIL: ", label)


func _initialize() -> void:
	_test_every_theme_names_its_world()
	_test_save_mode_reads_the_theme()
	_test_theme_without_world_id_keeps_the_old_rule()
	_test_scene_leads_to_its_world()
	_test_sound_world_reads_the_theme()
	print("WORLD_ID checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## A stand-in for the story world node: just the two properties the readers use.
func _fake_world(theme: Dictionary, theme_path: String) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar theme: Dictionary = {}\nvar theme_path := \"\"\n"
	script.reload()
	var node := Node.new()
	node.set_script(script)
	node.set("theme", theme)
	node.set("theme_path", theme_path)
	return node


func _test_every_theme_names_its_world() -> void:
	for path: String in WORLDS:
		var theme := DataCache.load_dict(path)
		check(str(theme.get("world_id", "")) == str(WORLDS[path].id), "%s names world_id %s" % [path.get_file(), WORLDS[path].id])
		check(StorySave.legacy_mode(path) == str(WORLDS[path].id), "%s: the id is the folder the old rule chose, old saves stay found" % path.get_file())


func _test_save_mode_reads_the_theme() -> void:
	var node := _fake_world({"world_id": "frost"}, "res://assets/data/some_other_theme.json")
	check(StorySave.mode(node) == "frost", "the save folder follows the theme's world_id, not the file name")
	node.free()
	for path: String in WORLDS:
		var world := _fake_world(DataCache.load_dict_copy(path), path)
		check(StorySave.mode(world) == str(WORLDS[path].id), "%s saves under %s" % [path.get_file(), WORLDS[path].id])
		world.free()


func _test_theme_without_world_id_keeps_the_old_rule() -> void:
	check(StorySave.world_of({}, "res://assets/data/frost_theme.json") == "frost", "no world_id: a frost path is the Frostgruft")
	check(StorySave.world_of({}, "res://assets/data/krypta_theme.json") == "krypta", "no world_id: a krypta path is the crypt")
	check(StorySave.world_of({}, "") == "hell", "no world_id and no path: the hell, as before")
	var node := _fake_world({}, "res://assets/data/krypta_theme.json")
	check(StorySave.mode(node) == "krypta", "a world whose theme lacks world_id saves where it always did")
	node.free()


func _test_scene_leads_to_its_world() -> void:
	for path: String in WORLDS:
		var scene := str(WORLDS[path].scene)
		check(StorySave.world_of_scene(scene) == str(WORLDS[path].id), "%s runs world %s" % [scene.get_file(), WORLDS[path].id])
		check(MainMenu._save_mode_of({"scene": scene}) == str(WORLDS[path].id), "the main menu looks for %s saves of %s" % [WORLDS[path].id, scene.get_file()])
	check(MainMenu._save_mode_of({}) == "", "a story without a scene has no save mode")
	check(StorySave.world_of_scene("res://src/hell/missing_frost_scene.tscn") == "frost", "a missing scene falls back to the old rule on its path")


func _test_sound_world_reads_the_theme() -> void:
	var rules := DataCache.load_dict(AUDIO_RULES)
	for path: String in WORLDS:
		var world := _fake_world(DataCache.load_dict_copy(path), path)
		check(StorySound.world_of(world, rules) == str(WORLDS[path].id), "%s sounds like world %s" % [path.get_file(), WORLDS[path].id])
		world.free()
	var renamed := _fake_world({"world_id": "krypta"}, "res://assets/data/renamed.json")
	check(StorySound.world_of(renamed, rules) == "krypta", "the sound world follows world_id, not the file name")
	renamed.free()
	var unknown := _fake_world({"world_id": "not_a_world"}, "res://assets/data/frost_theme.json")
	check(StorySound.world_of(unknown, rules) == "frost", "an id audio_rules.json does not know keeps the old rule")
	unknown.free()
	var old := _fake_world({}, "res://assets/data/frost_theme.json")
	check(StorySound.world_of(old, rules) == "frost", "a theme without world_id keeps worlds.by_theme")
	old.free()
