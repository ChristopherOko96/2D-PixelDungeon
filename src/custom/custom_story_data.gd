extends RefCounted
## Versioned, local Custom Story content. Room coordinates are current-story cells
## (96 world px), not the old 32 px room library. Drafts may be incomplete.

const DIR := "user://custom_stories"
const ROLES := ["start", "combat", "shop", "treasure", "boss"]
const WORLDS := {
	"krypta": {"name": "Krypta", "theme": "res://assets/data/krypta_theme.json", "pack": "res://assets/data/krypta_world.json", "sprites": "res://assets/sprites/krypta/"},
	"frost": {"name": "Frostgruft", "theme": "res://assets/data/frost_theme.json", "pack": "res://assets/data/frost_world.json", "sprites": "res://assets/sprites/frost/"},
	"hell": {"name": "Hölle", "theme": "res://assets/data/hell_theme.json", "pack": "res://assets/data/hell_world.json", "sprites": "res://assets/sprites/hell_0x72/"},
}
const SIDES := ["north", "east", "south", "west"]


## New editable story with current-world module examples, ready to play.
static func fresh_story(world: String = "krypta", title: String = "Meine Geschichte") -> Dictionary:
	if not WORLDS.has(world): world = "krypta"
	var story := {"schema_version": 1, "id": "story_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec() % 1000000],
		"title": title, "world": world, "revision": 0, "floor_count": 3, "rooms_per_floor": 7, "rooms": []}
	for pair: Array in [["start", "Eingang"], ["combat", "Raum A1"], ["combat", "Raum A2"], ["combat", "Raum A3"], ["shop", "Shop"], ["treasure", "Schatzkammer"], ["boss", "Boss-Arena"]]:
		story.rooms.append(fresh_room(world, str(pair[0]), str(pair[1])))
	return story


## One room module. The two-cell-wide ports lie on the reserved outer wall.
static func fresh_room(world: String = "krypta", role: String = "combat", title: String = "Raum A1") -> Dictionary:
	var width: int = 18 if role == "boss" else 14
	var height: int = 16 if role == "boss" else 12
	var floor_cells: Array = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			# Two restrained alcove variants; always retain a broad central route.
			if title.ends_with("A2") and x <= 2 and y <= 2: continue
			if title.ends_with("A3") and x >= width - 3 and y >= height - 3: continue
			floor_cells.append([x, y])
	var room := {"id": "room_%d_%s" % [Time.get_ticks_usec(), role], "title": title, "role": role, "width": width, "height": height,
		"floor": floor_cells, "ports": [
			{"side": "north", "cell": [width / 2 - 1, 0]}, {"side": "east", "cell": [width - 1, height / 2 - 1]},
			{"side": "south", "cell": [width / 2 - 1, height - 1]}, {"side": "west", "cell": [0, height / 2 - 1]}],
		"props": [], "enemy_spawns": [[width - 4, 3], [width - 4, height - 4], [3, height - 4]]}
	var manifest: Dictionary = DataCache.load_dict(str(WORLDS.get(world, WORLDS.krypta).sprites) + "manifest.json")
	for name: String in ["brazier_pillar", "brazier_blue", "barrel_a"]:
		if manifest.has(name):
			room.props.append({"name": name, "x": 3, "y": 3})
			break
	return room


## Only simple file IDs are allowed; no paths can enter the story directory.
static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 80: return false
	for ch: String in id:
		if ch not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-": return false
	return true


## Read one story (or its valid backup); unknown or malformed IDs give {}.
static func load_story(id: String, base_dir: String = DIR) -> Dictionary:
	if not valid_id(id): return {}
	for suffix: String in [".json", ".json.bak"]:
		var path := base_dir.path_join(id + suffix)
		if not FileAccess.file_exists(path): continue
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if value is Dictionary and str(value.get("id", "")) == id and validate(value).is_empty(): return value
	return {}


## Saved full story records, sorted by title. A missing directory is an empty list.
static func list_stories(base_dir: String = DIR) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base_dir)): return out
	var listed := {}
	for name: String in DirAccess.get_files_at(base_dir):
		if not name.ends_with(".json") and not name.ends_with(".json.bak"): continue
		var id := name.trim_suffix(".bak").trim_suffix(".json")
		if listed.has(id): continue
		listed[id] = true
		var story := load_story(id, base_dir)
		if not story.is_empty(): out.append(story)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.title).naturalnocasecmp_to(str(b.title)) < 0)
	return out


## Save a draft transactionally; returns {error, story}. Successful saves bump revision.
static func save_story(story: Dictionary, base_dir: String = DIR) -> Dictionary:
	var problems := validate(story)
	if not problems.is_empty(): return {"error": "\n".join(problems), "story": story}
	var out: Dictionary = story.duplicate(true)
	var old := load_story(str(out.id), base_dir)
	out.revision = maxi(int(out.get("revision", 0)), int(old.get("revision", 0))) + 1
	var folder := ProjectSettings.globalize_path(base_dir)
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return {"error": "Der Geschichtenordner konnte nicht angelegt werden.", "story": story}
	var path := folder.path_join(str(out.id) + ".json")
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return {"error": "Die Geschichte konnte nicht geschrieben werden.", "story": story}
	var ok := file.store_string(JSON.stringify(out, "\t"))
	file.close()
	var check_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(temp)) if ok else null
	if not check_value is Dictionary or not validate(check_value).is_empty():
		DirAccess.remove_absolute(temp)
		return {"error": "Die gespeicherte Geschichte konnte nicht zurückgelesen werden.", "story": story}
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(path + ".bak")
		if DirAccess.rename_absolute(path, path + ".bak") != OK: return {"error": "Die Sicherung konnte nicht angelegt werden.", "story": story}
	if DirAccess.rename_absolute(temp, path) != OK: return {"error": "Die Geschichte konnte nicht übernommen werden; die Sicherung bleibt erhalten.", "story": story}
	return {"error": "", "story": out}


## Deletes a story file and its backup; `extra_dirs`/`extra_files` (its save slots and
## copied profile) go with it. Returns false for an invalid id or when the story file stays.
static func delete_story(id: String, base_dir: String = DIR, extra_dirs: Array = [], extra_files: Array = []) -> bool:
	if not valid_id(id): return false
	for suffix: String in [".json", ".json.bak", ".json.tmp"]:
		var path := ProjectSettings.globalize_path(base_dir.path_join(id + suffix))
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	for folder: Variant in extra_dirs: remove_tree(str(folder))
	for file: Variant in extra_files:
		var path := ProjectSettings.globalize_path(str(file))
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	return not FileAccess.file_exists(base_dir.path_join(id + ".json"))


## Removes a folder with everything in it; a missing folder is fine.
static func remove_tree(path: String) -> void:
	var folder := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(folder): return
	for name: String in DirAccess.get_directories_at(folder): remove_tree(folder.path_join(name))
	for name: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)


## Schema checks for drafts; for_play additionally checks complete connected modules.
static func validate(story: Dictionary, for_play: bool = false) -> Array[String]:
	var errors: Array[String] = []
	if not _whole(story.get("schema_version"), 1, 1): errors.append("Unbekannte Geschichten-Version.")
	if not valid_id(str(story.get("id", ""))): errors.append("Ungültige Geschichten-ID.")
	if not story.get("title") is String or str(story.get("title", "")).strip_edges().is_empty() or str(story.get("title", "")).length() > 100: errors.append("Bitte einen Titel mit 1 bis 100 Zeichen eingeben.")
	if not WORLDS.has(str(story.get("world", ""))): errors.append("Welt muss Krypta, Frostgruft oder Hölle sein.")
	if not _whole(story.get("floor_count"), 1, 10): errors.append("Etagenzahl muss zwischen 1 und 10 liegen.")
	if not _whole(story.get("rooms_per_floor"), 3, 16): errors.append("Räume je Etage: 3 bis 16.")
	if not story.get("rooms") is Array or story.get("rooms", []).size() > 64:
		errors.append("Die Raumbibliothek darf höchstens 64 Räume enthalten.")
		return errors
	var ids := {}
	var roles := {}
	for value: Variant in story.rooms:
		if not value is Dictionary:
			errors.append("Ungültiger Raumeintrag.")
			continue
		var id := str(value.get("id", ""))
		if ids.has(id): errors.append("Doppelte Raum-ID: " + id)
		ids[id] = true
		roles[str(value.get("role", ""))] = true
		for message: String in room_problems(value, for_play): errors.append(str(value.get("title", id)) + ": " + message)
		if for_play and WORLDS.has(str(story.get("world", ""))) and value.get("props", []) is Array:
			var manifest: Dictionary = DataCache.load_dict(str(WORLDS[str(story.world)].sprites) + "manifest.json")
			for prop: Variant in value.get("props", []):
				if prop is Dictionary and not manifest.has(str(prop.get("name", ""))): errors.append(str(value.get("title", id)) + ": Ausstattung gehört nicht zur gewählten Welt: " + str(prop.get("name", "")))
	if for_play:
		for role: String in ["start", "combat", "boss"]:
			if not roles.has(role): errors.append("Raumtyp fehlt: " + role)
	return errors


## Room schema and reachability checks, also usable for the editor's live checklist.
static func room_problems(room: Dictionary, for_play: bool = false) -> Array[String]:
	var errors: Array[String] = []
	if not valid_id(str(room.get("id", ""))): errors.append("Ungültige Raum-ID.")
	if not room.get("title") is String or str(room.get("title", "")).length() > 100: errors.append("Ungültiger Raumname.")
	if not ROLES.has(str(room.get("role", ""))): errors.append("Unbekannter Raumtyp.")
	if not _whole(room.get("width"), 12, 32) or not _whole(room.get("height"), 10, 26):
		errors.append("Raumgröße: 12–32 × 10–26 Zellen.")
		return errors
	var w := int(room.width)
	var h := int(room.height)
	var mask := {}
	if not room.get("floor") is Array or room.get("floor", []).size() > w * h:
		errors.append("Ungültige Bodenliste.")
		return errors
	for c: Variant in room.floor:
		if not _point(c, w, h) or int(c[0]) == 0 or int(c[1]) == 0 or int(c[0]) == w - 1 or int(c[1]) == h - 1:
			errors.append("Boden muss innerhalb des Wandrahmens liegen.")
			break
		var key := Vector2i(int(c[0]), int(c[1]))
		if mask.has(key): errors.append("Doppeltes Bodenfeld.")
		mask[key] = true
	if not room.get("ports") is Array or room.get("ports", []).size() > 12:
		errors.append("Ungültige Türanschlüsse.")
		return errors
	var used := {}
	for p: Variant in room.ports:
		if not p is Dictionary or not SIDES.has(str(p.get("side", ""))) or not _point(p.get("cell"), w, h):
			errors.append("Ungültiger Türanschluss.")
			continue
		var c := Vector2i(int(p.cell[0]), int(p.cell[1]))
		var side := str(p.side)
		var valid := (side == "north" and c.y == 0 and c.x > 0 and c.x < w - 2) or (side == "south" and c.y == h - 1 and c.x > 0 and c.x < w - 2) or (side == "west" and c.x == 0 and c.y > 0 and c.y < h - 2) or (side == "east" and c.x == w - 1 and c.y > 0 and c.y < h - 2)
		if not valid: errors.append("Türanschluss muss mit zwei Zellen im äußeren Wandrahmen liegen.")
		var stamp := "%s:%d:%d" % [side, c.x, c.y]
		if used.has(stamp): errors.append("Doppelter Türanschluss.")
		used[stamp] = true
		if for_play:
			var inward := {"north": Vector2i.DOWN, "south": Vector2i.UP, "east": Vector2i.LEFT, "west": Vector2i.RIGHT}[side] as Vector2i
			var across := Vector2i.RIGHT if side in ["north", "south"] else Vector2i.DOWN
			if not mask.has(c + inward) or not mask.has(c + inward + across): errors.append("Vor jeder Tür müssen zwei begehbare Innenfelder liegen.")
	for name: String in ["props", "enemy_spawns"]:
		if not room.get(name, []) is Array or room.get(name, []).size() > 256:
			errors.append("Ungültige Liste: " + name)
			continue
		for value: Variant in room.get(name, []):
			var point: Variant = [value.get("x"), value.get("y")] if name == "props" and value is Dictionary else value
			if not _point(point, w, h): errors.append("Ungültige Platzierung in " + name)
			elif for_play and not mask.has(Vector2i(int(point[0]), int(point[1]))): errors.append("Platzierung liegt außerhalb des Bodens: " + name)
			if name == "props" and (not value is Dictionary or not value.get("name") is String or str(value.get("name", "")).is_empty() or str(value.get("name", "")).contains("/")): errors.append("Ungültiges Ausstattungs-Asset.")
	if for_play:
		if mask.size() < 20: errors.append("Mindestens 20 Bodenfelder werden benötigt.")
		if str(room.get("role", "")) == "boss" and (not mask.has(Vector2i(w / 2, h / 2)) or not mask.has(Vector2i(w / 2, h / 2 + 1))): errors.append("Die Mitte der Boss-Arena muss für den Wächter frei bleiben.")
		if room.ports.is_empty(): errors.append("Mindestens ein Türanschluss wird benötigt.")
		if not mask.is_empty():
			var seen := {mask.keys()[0]: true}
			var todo: Array = [mask.keys()[0]]
			while not todo.is_empty():
				var at: Vector2i = todo.pop_back()
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if mask.has(at + d) and not seen.has(at + d):
						seen[at + d] = true
						todo.append(at + d)
			if seen.size() != mask.size(): errors.append("Alle Bodenfelder müssen miteinander verbunden sein.")
	return errors


static func _whole(v: Variant, low: int, high: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and float(v) >= low and float(v) <= high


static func _point(v: Variant, w: int, h: int) -> bool:
	return v is Array and v.size() == 2 and _whole(v[0], 0, w - 1) and _whole(v[1], 0, h - 1)
