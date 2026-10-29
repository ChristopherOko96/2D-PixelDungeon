extends RefCounted
## Pixel or HD graphics: one setting for every world, stored with the other
## options in user://settings.cfg ([options] graphics = "pixel" / "hd"). The
## main menu (Optionen) and the pause menu (Ansicht) switch it. Each world names
## the sets it has in its theme data ("skins": {"pixel": {...}, "hd": {...}},
## theme keys that replace the defaults); a world without the chosen set keeps
## its own look. Static helpers; `path` lets tests use their own file.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "options"
const KEY := "graphics"
const DEFAULT := "pixel"
const MODES := ["pixel", "hd"]
const LABELS := {"pixel": "PIXEL", "hd": "HD"}


## The chosen mode ("pixel" or "hd").
static func mode(path: String = SETTINGS_PATH) -> String:
	var file := ConfigFile.new()
	if file.load(path) != OK: return DEFAULT
	var value := str(file.get_value(SECTION, KEY, DEFAULT))
	return value if value in MODES else DEFAULT


## Stores the mode and keeps every other option in the file.
static func store(value: String, path: String = SETTINGS_PATH) -> void:
	if value not in MODES: return
	var file := ConfigFile.new()
	file.load(path)
	file.set_value(SECTION, KEY, value)
	file.save(path)


## The other mode.
static func other(value: String) -> String:
	return "hd" if value == "pixel" else "pixel"


## The theme keys of a world's set for `value` ({} when the world lacks it).
static func skin(theme: Dictionary, value: String) -> Dictionary:
	return theme.get("skins", {}).get(value, {})


## True when the world has a set for `value`.
static func has(theme: Dictionary, value: String) -> bool:
	return theme.get("skins", {}).has(value)


## A short line for menus: what the chosen mode means in this world.
## A world without named sets has its one look (theme "pixel" says which).
static func note(theme: Dictionary, value: String) -> String:
	var sets: Dictionary = theme.get("skins", {})
	if sets.is_empty(): sets = {("pixel" if bool(theme.get("pixel", true)) else "hd"): {}}
	if sets.has(value): return "Grafik: " + str(LABELS.get(value, value))
	var own := str(sets.keys()[0])
	return "Grafik: %s · diese Welt hat nur %s-Grafik" % [LABELS.get(value, value), LABELS.get(own, own)]
