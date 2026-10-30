extends RefCounted
## The lasting player profile: per class the character level, EXP and talent
## build, plus gold, soul shards, the bosses already beaten on Albtraum and the boss completions already rewarded
## (docs/TALENTE-SEELENSPLITTER.de.md). Pure functions on a plain Dictionary,
##   {version, gold, shards: {have, earned, spent}, nightmare_firsts: [],
##    rewarded: [], difficulty, classes: {class_id: {level, exp, ranks: {talent: rank},
##    ultimate, soul_tier, soul_paid, bar: [talent ids]}}}
## so the rules test without files; load / save keep it in user://profile.json.
## Saving writes a temporary file first and then replaces the old one, so a
## crash mid-write never leaves a broken profile.

const DATA_PATH := "res://assets/data/talents.json"
const SAVE_PATH := "user://profile.json"
## The talent test profile of debug builds (main menu TALENT-TEST): level 30
## in every class, many shards and gold (talents cost mana as usual); the player's
## own profile stays untouched while it is on.
const DEBUG_PATH := "user://profile_debug.json"
const DEBUG_FLAG := "user://talent_debug.flag"
## 2: the 8-row trees (29.10.2026); the old ultimates <spec>_6 became <spec>_14.
const VERSION := 2
## Old ultimate ids of version 1 profiles.
const OLD_ULTIMATES := ["fire", "frost", "arcane", "sniper", "trapper", "beast", "berserk", "guard", "blade"]


## Where this process keeps the profile: test runs (a SceneTree script started
## with -s) use their own file, so they never touch the player's progress.
static func default_path() -> String:
	var loop := Engine.get_main_loop()
	if loop != null and loop.get_script() != null: return "user://profile_test.json"
	return DEBUG_PATH if debug_enabled() else SAVE_PATH


## True while the talent test profile is on (debug builds only).
static func debug_enabled() -> bool:
	return OS.is_debug_build() and FileAccess.file_exists(DEBUG_FLAG)


## Turns the talent test profile on (written fresh: level 30 everywhere, 99
## shards, 99999 gold; casts cost mana as usual) or off. Debug builds only.
static func set_debug(on: bool, d: Dictionary) -> void:
	if not OS.is_debug_build(): return
	if not on:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEBUG_FLAG))
		return
	var profile := fresh(d)
	profile.gold = 99999
	profile.shards = {"have": 99, "earned": 99, "spent": 0}
	profile.debug_free = true
	for id: String in profile.classes: profile.classes[id].level = int(d.get("max_level", 30))
	save_profile(profile, DEBUG_PATH)
	var flag := FileAccess.open(DEBUG_FLAG, FileAccess.WRITE)
	if flag != null: flag.store_string("talent test profile on")


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
	return {"version": VERSION, "gold": 0, "shards": {"have": 0, "earned": 0, "spent": 0},
		"nightmare_firsts": [], "rewarded": [], "difficulty": "normal", "classes": classes, "debug_free": false}


static func fresh_class() -> Dictionary:
	return {"level": 1, "exp": 0, "ranks": {}, "ultimate": "", "soul_tier": 0, "soul_paid": 0, "bar": [], "companion": "wolf"}


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
	profile.debug_free = bool(raw.get("debug_free", false)) and OS.is_debug_build()
	var shards: Dictionary = raw.get("shards", {}) if raw.get("shards", {}) is Dictionary else {}
	var earned := maxi(0, int(shards.get("earned", 0)))
	var spent := clampi(int(shards.get("spent", 0)), 0, earned)
	profile.shards = {"have": earned - spent, "earned": earned, "spent": spent}
	for key: String in ["nightmare_firsts", "rewarded"]:
		var list: Variant = raw.get(key, [])
		if list is Array: profile[key] = list.filter(func(v: Variant) -> bool: return v is String).slice(-int(d.get("soul_shards", {}).get("reward_memory", 200)) if key == "rewarded" else 0)
	var difficulty := str(raw.get("difficulty", "normal"))
	profile.difficulty = difficulty if d.get("difficulties", {}).has(difficulty) else "normal"
	var classes: Variant = raw.get("classes", {})
	if classes is Dictionary and int(raw.get("version", 1)) < 2: classes = _migrate_v1(classes)
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
			state.soul_tier = clampi(int(entry.get("soul_tier", 0)), 0, (d.get("soul_shards", {}).get("tier_costs", []) as Array).size())
			state.soul_paid = maxi(0, int(entry.get("soul_paid", 0)))
			var bar: Variant = entry.get("bar", [])
			var kind := str(entry.get("companion", "wolf"))
			var known: Dictionary = d.get("pet", {}).get("kinds", {})
			state.companion = kind if known.has(kind) and not bool(known[kind].get("summon_only", false)) else str(d.get("pet", {}).get("default_kind", "wolf"))
			if bar is Array: state.bar = bar.filter(func(v: Variant) -> bool: return state.ranks.has(str(v))).map(func(v: Variant) -> String: return str(v)).slice(0, int(d.get("bar_slots", 4)))
	return profile


## Reads the profile from `path`; a fresh one when there is none or it is
## broken. Builds that no longer fit the trees (several branches, a talent
## above its row) are repaired; the points come back.
static func load_profile(d: Dictionary, path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return fresh(d)
	var profile := sanitize(JSON.parse_string(FileAccess.get_file_as_string(path)), d)
	# loaded at run time: talent_rules.gd preloads this script
	var rules: GDScript = load("res://src/progress/talent_rules.gd")
	for class_id: String in profile.classes: rules.repair(d, profile, class_id)
	return profile


## Version 1 profiles: the ultimate <spec>_6 is now <spec>_14 (ranks, ultimate, bar).
static func _migrate_v1(classes: Dictionary) -> Dictionary:
	var out := classes.duplicate(true)
	for id: Variant in out:
		var entry: Variant = out[id]
		if not entry is Dictionary: continue
		var rename := func(talent: String) -> String:
			var spec := talent.get_slice("_", 0)
			return spec + "_14" if talent == spec + "_6" and OLD_ULTIMATES.has(spec) else talent
		if entry.has("ranks") and entry.ranks is Dictionary:
			var ranks := {}
			for talent: Variant in entry.ranks: ranks[rename.call(str(talent))] = entry.ranks[talent]
			entry.ranks = ranks
		entry.ultimate = rename.call(str(entry.get("ultimate", "")))
		if entry.has("bar") and entry.bar is Array: entry.bar = (entry.bar as Array).map(func(v: Variant) -> String: return rename.call(str(v)))
	return out


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
		"soul_tier": state.soul_tier, "bar": state.bar.duplicate(), "companion": str(state.get("companion", "wolf")), "free": bool(profile.get("debug_free", false)), "difficulty": profile.difficulty,
		"nightmare_firsts": profile.nightmare_firsts.duplicate()}
