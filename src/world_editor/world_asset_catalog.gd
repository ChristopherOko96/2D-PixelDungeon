extends RefCounted
## The Weltbauer's parts list: every picture under assets/, per world and category, whether the game
## uses it yet or not; film strips and numbered frames as one animated part. Also says for each
## world which pictures exist in only one of its two graphics sets. Reads folders, no UI.

const CONFIG_PATH := "res://assets/data/world_editor.json"
const ROOT := "res://assets"
const OTHER := "other"
const OTHER_CATEGORY := "Sonstiges"
const Gates = preload("res://src/world_editor/world_gates.gd")

var cfg: Dictionary = {}
## Every picture file under assets/ once: res path -> true.
var _files: Array = []
## The sorting rules with their patterns ready (world_editor.json rules).
var _rules: Array = []
var _frame_number := RegEx.create_from_string("(_anim)?[_-]?f(rame)?_?\\d+$")


func _init() -> void:
	cfg = DataCache.load_dict(CONFIG_PATH)
	for rule: Dictionary in cfg.rules:
		var ready: Dictionary = rule.duplicate()
		for key: String in ["name", "folder"]:
			if rule.has(key):
				ready[key] = RegEx.create_from_string(str(rule[key]))
		_rules.append(ready)
	_scan(ROOT)


func _scan(folder: String) -> void:
	for name: String in DirAccess.get_files_at(folder):
		if name.ends_with(".png") and FileAccess.file_exists(folder.path_join(name) + ".import"):
			_files.append(folder.path_join(name))
	for sub: String in DirAccess.get_directories_at(folder):
		if not sub.begins_with("."):
			_scan(folder.path_join(sub))


## How many pictures were found.
func file_count() -> int:
	return _files.size()


## The world's theme with its two graphics sets: {"pixel": folder, "hd": folder}.
static func skin_folders(theme: Dictionary) -> Dictionary:
	var skins: Dictionary = theme.get("skins", {})
	return {"pixel": str((skins.get("pixel", {}) as Dictionary).get("sprites", theme.get("sprites", ""))),
		"hd": str((skins.get("hd", {}) as Dictionary).get("sprites", theme.get("sprites", "")))}


## Names that lack a version in a set: {"hd_only": [...], "pixel_only": [...], "both": n}.
## "hd_only" pictures show in Pixel view cut to its grid (world_room_world.gd resolve).
static func coverage(theme: Dictionary) -> Dictionary:
	var f := skin_folders(theme)
	var hd := _names(str(f.hd))
	var pixel := _names(str(f.pixel))
	var hd_only: Array = []
	var pixel_only: Array = []
	var both := 0
	for n: String in hd:
		if pixel.has(n):
			both += 1
		else:
			hd_only.append(n)
	for n: String in pixel:
		if not hd.has(n):
			pixel_only.append(n)
	return {"hd_only": hd_only, "pixel_only": pixel_only, "both": both}


static func _names(folder: String) -> Dictionary:
	var out := {}
	if folder != "" and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		for name: String in DirAccess.get_files_at(folder):
			if name.ends_with(".png"):
				out[name.trim_suffix(".png")] = true
	return out


## The parts of tab `world` ("krypta", "frost", "hell" or OTHER): an Array of
## {label, cat, kind, asset, frames?, fps?, folder, strip?, area?}.
func entries(world: String, theme: Dictionary) -> Array:
	var skin := skin_folders(theme)
	var own := {}
	var loose: Array = []
	var taken: Array = (cfg.world_folders as Dictionary).keys()
	for path: String in _files:
		var owner := _owner_of(path)
		if world == OTHER:
			if owner == "":
				loose.append(path)
			continue
		if owner != world:
			continue
		var folder := path.get_base_dir() + "/"
		if folder == str(skin.pixel) or folder == str(skin.hd):
			own[path.get_file().get_basename()] = path
		else:
			loose.append(path)
	var out: Array = []
	out.append_array(_grouped(own.keys(), own, true))
	var keys: Array = []
	var paths := {}
	for path: String in loose:
		keys.append(path)
		paths[path] = path
	out.append_array(_grouped(keys, paths, false))
	var order := category_names()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.cat) != str(b.cat):
			return order.find(str(a.cat)) < order.find(str(b.cat))
		return str(a.label).naturalnocasecmp_to(str(b.label)) < 0)
	return out


## The categories in the order of the list.
func category_names() -> Array:
	var names: Array = (cfg.categories as Array).map(func(c: Dictionary) -> String: return str(c.name))
	names.append(OTHER_CATEGORY)
	return names


func _owner_of(path: String) -> String:
	var rel := path.trim_prefix(ROOT + "/")
	for world: String in cfg.world_folders:
		for folder: Variant in cfg.world_folders[world]:
			if rel.begins_with(str(folder) + "/"):
				return world
	# the sets named in the themes
	if rel.begins_with("sprites/krypta"):
		return "krypta"
	return ""


## Numbered frames in one folder become one animated part.
func _grouped(keys: Array, paths: Dictionary, sheet_names: bool) -> Array:
	var groups := {}
	var single: Array = []
	var pattern := RegEx.create_from_string("^(.*?)(?:_anim)?[_-]?f(?:rame)?_?(\\d+)$")
	for key: Variant in keys:
		var path: String = paths[key]
		var base := path.get_file().get_basename()
		var hit := pattern.search(base)
		if hit == null:
			single.append(key)
			continue
		var id := path.get_base_dir() + "|" + hit.get_string(1)
		if not groups.has(id):
			groups[id] = []
		groups[id].append([int(hit.get_string(2)), key])
	var out: Array = []
	for key: Variant in single:
		out.append(_entry(str(key), str(paths[key]), sheet_names))
	for id: String in groups:
		var frames: Array = groups[id]
		if frames.size() < 2:
			out.append(_entry(str(frames[0][1]), str(paths[frames[0][1]]), sheet_names))
			continue
		frames.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
		var e := _entry(str(frames[0][1]), str(paths[frames[0][1]]), sheet_names)
		e.frames = frames.map(func(f: Array) -> String: return _asset_name(str(f[1]), str(paths[f[1]]), sheet_names))
		e.fps = 8.0
		e.label = str(e.label).get_slice("_f", 0) + " (animiert)"
		out.append(e)
	return out


func _asset_name(key: String, path: String, sheet_names: bool) -> String:
	return key if sheet_names else "@" + path


func _entry(key: String, path: String, sheet_names: bool) -> Dictionary:
	var base := path.get_file().get_basename()
	var rel := path.get_base_dir().trim_prefix(ROOT + "/")
	var rule := rule_of(base, rel)
	var e := {"label": base, "cat": str(rule.cat), "kind": "prop", "asset": _asset_name(key, path, sheet_names), "folder": rel, "layer": str(rule.layer), "block": bool(rule.block)}
	if bool(rule.get("area", false)):
		e.area = true
	_make_gate(e, base, path, sheet_names)
	for word: Variant in cfg.strip_folders:
		if rel.split("/").has(str(word)):
			e.maybe_strip = true
	return e


## A picture that shows a gate is a gate, not a piece: it digs its wall and lies by it.
func _make_gate(e: Dictionary, base: String, path: String, sheet_names: bool) -> void:
	var meant := Gates.style_of_picture("@" + path)
	var by_file := not meant.is_empty()
	if not by_file:
		meant = Gates.style_of_picture(base)
	if meant.is_empty():
		return
	var style: Dictionary = Gates.config().styles[meant.style]
	e.kind = "gate"
	e.cat = str(cfg.gate_category)
	e.label = str(meant.label)
	e.defaults = {"style": meant.style, "dir": "v", "group": "A", "lock": ""}
	# a set of gates outside the world's two sets keeps its own look
	if not sheet_names and not by_file:
		e.defaults.set_folder = path.get_base_dir() + "/"
		e.label = str(e.label) + " · " + path.get_base_dir().get_file()


## The rule a picture falls under: the first that fits its name and folder, with its category's
## layer and blocking unless it says otherwise.
func rule_of(base: String, rel: String) -> Dictionary:
	var name := _frame_number.sub(base, "")
	for rule: Dictionary in _rules:
		if rule.has("name") and (rule.name as RegEx).search(name) == null:
			continue
		if rule.has("folder") and (rule.folder as RegEx).search(rel) == null:
			continue
		var out: Dictionary = {"cat": rule.cat, "layer": "normal", "block": false, "area": rule.get("area", false)}
		for c: Dictionary in cfg.categories:
			if str(c.name) == str(rule.cat):
				out.layer = c.layer
				out.block = c.block
		for key: String in ["layer", "block"]:
			if rule.has(key):
				out[key] = rule[key]
		return out
	return {"cat": OTHER_CATEGORY, "layer": "normal", "block": false, "area": false}


## The category of a picture.
func category_of(base: String, rel: String) -> String:
	return str(rule_of(base, rel).cat)


## The defaults of a newly placed piece: layer and blocking from its sorting, size by its art.
func new_prop(entry: Dictionary, picture: Texture2D, in_world_set: bool) -> Dictionary:
	var name := str(entry.asset).to_lower()
	var rule := rule_of(str(entry.get("label", entry.asset)), str(entry.get("folder", "")))
	var o := {"kind": "prop", "asset": str(entry.asset), "flip": false, "layer": str(entry.get("layer", rule.layer)), "block": bool(entry.get("block", rule.block)), "scale": 1.0}
	var size := picture.get_size() if picture != null else Vector2(48, 48)
	if not in_world_set and maxf(size.x, size.y) <= float(cfg.small_art):
		o.scale = float(cfg.small_scale)
	var shown: Vector2 = size * float(o.scale)
	o.foot = [roundf(maxf(20.0, shown.x * 0.7)), roundf(clampf(shown.y * 0.25, 16.0, 40.0))]
	if entry.has("frames"):
		o.frames = entry.frames
		o.fps = float(entry.get("fps", 8.0))
		o.asset = str((entry.frames as Array)[0])
	if name.begins_with("@") and entry.has("strip"):
		o.frames = entry.frames
		o.fps = 12.0
		o.asset = str((entry.frames as Array)[0])
	return o
