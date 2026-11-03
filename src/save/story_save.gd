extends RefCounted
## Story world save data (src/hell/hell_game.gd: Hell-Dungeon and Frostgruft):
## the floor number and everything the portal carries to the next floor
## (hearts, the character's gold, blessings, level, skills, relic, cards, talent bonus).
## Loading opens the same scene on that floor with these values.

## The state keys hell_game.load_floor carries from floor to floor.
const CARRIED := ["hp", "max_hp", "gems", "gold", "dmg", "rate", "speed_mul", "range", "buffs", "skill", "level", "exp", "relic", "relic_on",
	"upgrades", "offer", "cards_due", "relic_floor", "relic_item", "talent", "crystals_run", "run_id", "items", "world_run"]


## The world id of `game` and so its save folder: its theme's "world_id" ("krypta",
## "frost" or "hell", assets/data/*_theme.json), else the old rule on its theme path.
static func mode(game: Node) -> String:
	var theme: Variant = game.get("theme")
	return world_of(theme if theme is Dictionary else {}, str(game.get("theme_path")))


## A theme's world id: its "world_id" key; a theme without it (an older or a test
## theme) gets legacy_mode() of `theme_path`, so saves keep their folder.
static func world_of(theme: Dictionary, theme_path: String) -> String:
	var id := str(theme.get("world_id", ""))
	return id if not id.is_empty() else legacy_mode(theme_path)


## The rule from before world_id, kept as the fallback: "frost" when `path` names
## the Frostgruft, "krypta" for the crypt (Story 1), otherwise "hell".
static func legacy_mode(path: String) -> String:
	if path.contains("frost"):
		return "frost"
	return "krypta" if path.contains("krypta") else "hell"


## The world id of a story scene (the theme_path its root sets, src/hell/hell_game.gd,
## and that theme's world_id), read without instancing the scene; legacy_mode() of
## the scene path when the scene or its theme is missing, "" without a scene.
static func world_of_scene(scene_path: String) -> String:
	if scene_path.is_empty():
		return ""
	if not ResourceLoader.exists(scene_path):
		return legacy_mode(scene_path)
	var packed := load(scene_path) as PackedScene
	var state := packed.get_state() if packed != null else null
	var theme_path := ""
	if state != null and state.get_node_count() > 0:
		for i in range(state.get_node_property_count(0)):
			if state.get_node_property_name(0, i) == &"theme_path":
				theme_path = str(state.get_node_property_value(0, i))
	if theme_path.is_empty():
		return legacy_mode(scene_path)
	var id := str(DataCache.load_dict(theme_path).get("world_id", ""))
	return id if not id.is_empty() else legacy_mode(theme_path)


## The save record for the floor the game just loaded.
static func capture(game: Node) -> Dictionary:
	var keep := {}
	for key: String in CARRIED:
		if game.state.has(key):
			var value: Variant = game.state[key]
			keep[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	var record := {"class_id": str(game.class_id), "scene": str(game.scene_file_path), "floor": int(game.state.floor), "run_id": str(game.state.get("run_id", "")),
		"title": str(game.W.get("title", "")), "level": int(game.state.get("level", 1)), "keep": keep}
	var custom: Variant = game.get("custom_story")
	if custom is Dictionary and not custom.is_empty():
		# A run keeps the exact room revision it began with even if its editor draft changes.
		record.custom_story = custom.duplicate(true)
		record.custom_preview_room = str(game.get("custom_preview_room"))
	return record


## A safe local filename component, also for an untrusted save snapshot.
static func custom_key(story: Dictionary) -> String:
	var id := str(story.get("id", ""))
	if id.is_empty() or id.length() > 80:
		return id.sha256_text().substr(0, 24)
	for character: String in id:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
			return id.sha256_text().substr(0, 24)
	return id


## Custom run saves never share the main story's slots. `root` isolates test fixtures.
static func custom_saves_dir(story: Dictionary, preview: bool = false, root: String = "") -> String:
	var base := (root.trim_suffix("/") + "/saves/" + ("preview/" if preview else "")) if not root.is_empty() \
		else ("user://custom_story_preview_saves/" if preview else "user://custom_story_saves/")
	return base + custom_key(story) + "/"


## A copied profile belongs to this Custom story; preview profiles are disposable copies.
static func custom_profile_path(story: Dictionary, preview: bool = false, root: String = "") -> String:
	var base := root.trim_suffix("/") + "/profiles/" if not root.is_empty() else "user://custom_story_profiles/"
	return base + ("preview/" if preview else "") + custom_key(story) + ".json"
