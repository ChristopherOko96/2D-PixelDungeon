extends RefCounted
## The story chapters of the account (docs/BEUTEORDNUNG.de.md section 1): which stories are open and
## which heroes carry on. Story 1 is always open; a story opens when any hero finished the one before
## it. The hero (a class of the account) who finished story K is kept with everything its run carried
## (StorySave.CARRIED) and may go on in story K + 1; it dies with its gold and items. Pure functions on
##   {version, unlocked: highest open story number, heroes: {class_id: {next: story number, done: chapters
##    finished, keep: {...}, title, saved_at}}}
## and load / save of user://story_progress.json (tests pass their own path).

const SAVE_PATH := "user://story_progress.json"
const VERSION := 1


## A fresh account: story 1 open, no hero waiting.
static func fresh() -> Dictionary:
	return {"version": VERSION, "unlocked": 1, "heroes": {}}


## Where this process keeps the progress: test runs (a SceneTree script) use their own file.
static func default_path() -> String:
	var loop := Engine.get_main_loop()
	if loop != null and loop.get_script() != null:
		return "user://story_progress_test.json"
	return SAVE_PATH


static func load_progress(path: String = "") -> Dictionary:
	var file := path if not path.is_empty() else default_path()
	if not FileAccess.file_exists(file):
		return fresh()
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	return sanitize(raw)


## Known keys only, sane numbers.
static func sanitize(raw: Variant) -> Dictionary:
	var out := fresh()
	if not raw is Dictionary:
		return out
	out.unlocked = maxi(1, int(raw.get("unlocked", 1)))
	var heroes: Variant = raw.get("heroes", {})
	if heroes is Dictionary:
		for id: Variant in heroes:
			var h: Variant = heroes[id]
			if h is Dictionary and h.get("keep", null) is Dictionary:
				out.heroes[str(id)] = {"next": maxi(2, int(h.get("next", 2))), "done": maxi(1, int(h.get("done", 1))),
					"keep": (h.keep as Dictionary).duplicate(true), "title": str(h.get("title", "")), "saved_at": int(h.get("saved_at", 0))}
	return out


## Written to a side file first, then moved over the old one.
static func save_progress(progress: Dictionary, path: String = "") -> bool:
	var file := path if not path.is_empty() else default_path()
	var temp := file + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(progress, " "))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(file)) == OK


## True when story number `story` may be played.
static func is_open(progress: Dictionary, story: int) -> bool:
	return story <= int(progress.get("unlocked", 1))


## The hero of `class_id` waiting for story `story` ({} when none).
static func waiting(progress: Dictionary, class_id: String, story: int) -> Dictionary:
	var h: Dictionary = (progress.get("heroes", {}) as Dictionary).get(class_id, {})
	return h if not h.is_empty() and int(h.get("next", 0)) == story else {}


## Any hero of `class_id` waiting, for whatever story ({} when none).
static func hero_of(progress: Dictionary, class_id: String) -> Dictionary:
	return (progress.get("heroes", {}) as Dictionary).get(class_id, {})


## Story `story` won with `class_id`: the next story opens and the hero is kept with `keep` (what its
## run carried), `done` = chapters it finished now. `last` = the highest story there is: past it no
## hero waits.
static func on_win(progress: Dictionary, class_id: String, story: int, keep: Dictionary, done: int, last: int, title := "") -> void:
	progress.unlocked = maxi(int(progress.get("unlocked", 1)), mini(story + 1, last))
	if story >= last:
		(progress.heroes as Dictionary).erase(class_id)
		return
	progress.heroes[class_id] = {"next": story + 1, "done": maxi(1, done), "keep": keep.duplicate(true), "title": title,
		"saved_at": int(Time.get_unix_time_from_system())}


## The hero of `class_id` fell, or a fresh run of that class began: it is gone, with gold and items.
static func drop_hero(progress: Dictionary, class_id: String) -> void:
	(progress.get("heroes", {}) as Dictionary).erase(class_id)


## A short line for the menu: "STUFE 7 · 340 GOLD · 9 GEGENSTÄNDE".
static func describe(hero: Dictionary) -> String:
	var keep: Dictionary = hero.get("keep", {})
	var items: Dictionary = keep.get("items", {})
	var bag: Array = ((items.get("inventory", {}) as Dictionary).get("bag", []) as Array) if items.get("inventory", {}) is Dictionary else []
	var lp := "%d/%d LP" % [int(keep.get("hp", 0)), int(keep.get("max_hp", 0))]
	return "LAUFSTUFE %d · %d GOLD · %s · %d IM RUCKSACK" % [int(keep.get("level", 1)), int(keep.get("gold", 0)), lp, bag.size()]
