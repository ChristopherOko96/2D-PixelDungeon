extends RefCounted
## The lasting player profile: per class the character level, EXP and talent
## build, plus gold, soul shards, the pity counter for boss drops, the bosses
## already beaten on Albtraum and the boss completions already rewarded
## (docs/TALENTE-SEELENSPLITTER.de.md). Pure functions on a plain Dictionary,
##   {version, gold, shards: {have, earned, spent}, pity, nightmare_firsts: [],
##    rewarded: [], difficulty, classes: {class_id: {level, exp, ranks: {talent: rank},
##    ultimate, soul_tier, soul_paid, bar: [talent ids]}}}
## so the rules test without files; load / save keep it in user://profile.json.
## Saving writes a temporary file first and then replaces the old one, so a
## crash mid-write never leaves a broken profile.

const DATA_PATH := "res://assets/data/talents.json"
const SAVE_PATH := "user://profile.json"
const VERSION := 1


## Where this process keeps the profile: test runs (a SceneTree script started
## with -s) use their own file, so they never touch the player's progress.
static func default_path() -> String:
	var loop := Engine.get_main_loop()
	return "user://profile_test.json" if loop != null and loop.get_script() != null else SAVE_PATH


## The talent data (assets/data/talents.json); empty when missing or broken.
static func data(path: String = DATA_PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## A fresh profile: level 1 in every class, nothing learned, no shards.
static func fresh(d: Dictionary) -> Dictionary:
	var classes := {}
	for id: String in d.get("classes", {}):
		classes[id] = fresh_class()
	return {"version": VERSION, "gold": 0, "shards": {"have": 0, "earned": 0, "spent": 0}, "pity": 0,
		"nightmare_firsts": [], "rewarded": [], "difficulty": "normal", "classes": classes}


static func fresh_class() -> Dictionary:
	return {"level": 1, "exp": 0, "ranks": {}, "ultimate": "", "soul_tier": 0, "soul_paid": 0, "bar": []}


## Class entry of `class_id`, created on first use.
static func class_state(profile: Dictionary, class_id: String) -> Dictionary:
	if not profile.classes.has(class_id): profile.classes[class_id] = fresh_class()
	return profile.classes[class_id]


## Repairs a loaded or received profile: known keys only, sane numbers, no
## negative currencies, have == earned - spent, unknown talents dropped.
static func sanitize(raw: Variant, d: Dictionary) -> Dictionary:
	var profile := fresh(d)
	if not raw is Dictionary: return profile
	profile.gold = maxi(0, int(raw.get("gold", 0)))
	var shards: Dictionary = raw.get("shards", {}) if raw.get("shards", {}) is Dictionary else {}
	var earned := maxi(0, int(shards.get("earned", 0)))
	var spent := clampi(int(shards.get("spent", 0)), 0, earned)
	profile.shards = {"have": earned - spent, "earned": earned, "spent": spent}
	profile.pity = clampi(int(raw.get("pity", 0)), 0, int(d.get("soul_shards", {}).get("pity_after", 10)) - 1)
	for key: String in ["nightmare_firsts", "rewarded"]:
		var list: Variant = raw.get(key, [])
		if list is Array: profile[key] = list.filter(func(v: Variant) -> bool: return v is String).slice(-int(d.get("soul_shards", {}).get("reward_memory", 200)) if key == "rewarded" else 0)
	var difficulty := str(raw.get("difficulty", "normal"))
	profile.difficulty = difficulty if d.get("difficulties", {}).has(difficulty) else "normal"
	var classes: Variant = raw.get("classes", {})
	if classes is Dictionary:
		for id: String in profile.classes:
			var entry: Variant = classes.get(id, {})
			if not entry is Dictionary: continue
			var state: Dictionary = profile.classes[id]
			state.level = clampi(int(entry.get("level", 1)), 1, int(d.get("max_level", 30)))
			state.exp = maxi(0, int(entry.get("exp", 0)))
			var ranks: Variant = entry.get("ranks", {})
			if ranks is Dictionary:
				for talent: Variant in ranks:
					var info: Dictionary = d.talents.get(str(talent), {})
					if info.is_empty() or str(info["class"]) != id: continue
					var rank := clampi(int(ranks[talent]), 0, int(info.ranks))
					if rank > 0: state.ranks[str(talent)] = rank
			state.ultimate = str(entry.get("ultimate", ""))
			state.soul_tier = clampi(int(entry.get("soul_tier", 0)), 0, 3)
			state.soul_paid = maxi(0, int(entry.get("soul_paid", 0)))
			var bar: Variant = entry.get("bar", [])
			if bar is Array: state.bar = bar.filter(func(v: Variant) -> bool: return state.ranks.has(str(v))).map(func(v: Variant) -> String: return str(v)).slice(0, int(d.get("bar_slots", 4)))
	return profile


## Reads the profile from `path`; a fresh one when there is none or it is broken.
static func load_profile(d: Dictionary, path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return fresh(d)
	return sanitize(JSON.parse_string(FileAccess.get_file_as_string(path)), d)


## Writes the profile (temporary file, then replace). Returns OK or an error code.
static func save_profile(profile: Dictionary, path: String = SAVE_PATH) -> Error:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(profile, " "))
	file.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null: return DirAccess.get_open_error()
	if FileAccess.file_exists(path): dir.remove(path.get_file())
	return dir.rename(temp.get_file(), path.get_file())


## The build of one class as sent to the host in multiplayer.
static func build_of(profile: Dictionary, class_id: String) -> Dictionary:
	var state := class_state(profile, class_id)
	return {"class": class_id, "level": state.level, "ranks": state.ranks.duplicate(), "ultimate": state.ultimate,
		"soul_tier": state.soul_tier, "bar": state.bar.duplicate(), "pity": profile.pity, "difficulty": profile.difficulty,
		"nightmare_firsts": profile.nightmare_firsts.duplicate()}
