extends RefCounted
## One room of the Weltbauer as a file: assets/data/world_rooms/<world>/<id>.json. The rows of
## `cells` say what each cell is (WALL, FLOOR, LIQUID, BRIDGE, PIT), `tiles` and `areas` dress single
## cells, `objects` holds everything placed, in room pixels with the foot at x, y. Testable without UI.
## The game reads these files through world_room_world.gd.

const DIR := "res://assets/data/world_rooms"
const SCHEMA := 1
const CELL := 96.0
const WALL := "0"
const FLOOR := "1"
const LIQUID := "2"
const BRIDGE := "3"
const PIT := "4"
const MIN_SIZE := Vector2i(6, 6)
const MAX_SIZE := Vector2i(64, 60)
## One slot of a floor's grid in cells, and the room for the corridor between two slots
## (krypta_world.json room_library holds the same numbers for the floor builder).
const SLOT := Vector2i(14, 11)
const SLOT_GAP := Vector2i(3, 3)
const Gates = preload("res://src/world_editor/world_gates.gd")
const WORLDS := {
	"krypta": {"name": "Krypta", "scene": "res://src/hell/krypta_dungeon.tscn", "theme": "res://assets/data/krypta_theme.json", "pack": "res://assets/data/krypta_world.json"},
	"frost": {"name": "Frostgruft", "scene": "res://src/hell/frost_dungeon.tscn", "theme": "res://assets/data/frost_theme.json", "pack": "res://assets/data/frost_world.json"},
	"hell": {"name": "Hölle", "scene": "res://src/hell/hell_dungeon.tscn", "theme": "res://assets/data/hell_theme.json", "pack": "res://assets/data/hell_world.json"},
}
## What a door spot is for. Unmarked spots serve either way.
const PORT_USES := {"": "Ein- und Ausgang", "in": "Eingang", "out": "Ausgang"}
const ROLES := {"combat": "Kampfraum", "start": "Eingang", "key": "Schlüsselraum", "shop": "Shop", "treasure": "Schatzraum", "puzzle": "Rätselraum", "secret": "Geheimraum", "boss": "Bossraum", "portal": "Portalraum", "vault": "Tresorkammer", "stairs": "Treppenkammer", "jump": "Sprungrätsel / Labyrinth"}


## A new room: floor inside a wall frame, the hero's start in the middle.
static func fresh(world: String = "krypta", title: String = "Neuer Raum", size: Vector2i = Vector2i(16, 12)) -> Dictionary:
	var rows: Array = []
	for y in range(size.y):
		var row := ""
		for x in range(size.x):
			row += FLOOR if x > 0 and y > 0 and x < size.x - 1 and y < size.y - 1 else WALL
		rows.append(row)
	return {"schema_version": SCHEMA, "id": new_id(title), "title": title, "world": world, "role": "combat",
		"width": size.x, "height": size.y, "cells": rows, "tiles": {}, "areas": {}, "ports": [], "auto_mobs": 0,
		"objects": [{"kind": "start", "x": (size.x / 2 + 0.5) * CELL, "y": (size.y / 2 + 0.7) * CELL}]}


## A file name from a title: small letters, digits and _, with the clock so it stays unique.
static func new_id(title: String) -> String:
	var clean := ""
	for ch: String in title.to_lower().replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss"):
		clean += ch if ch in "abcdefghijklmnopqrstuvwxyz0123456789" else "_"
	while clean.contains("__"):
		clean = clean.replace("__", "_")
	return "%s_%d" % [clean.strip_edges().trim_prefix("_").trim_suffix("_").left(40), Time.get_ticks_usec() + int(Time.get_unix_time_from_system()) * 1000]


## The cell at (x, y); WALL outside the room.
static func cell_at(room: Dictionary, x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= int(room.width) or y >= int(room.height):
		return WALL
	return str(room.cells[y])[x]


## Sets one cell. Returns true when something changed.
static func set_cell(room: Dictionary, x: int, y: int, value: String) -> bool:
	if x < 0 or y < 0 or x >= int(room.width) or y >= int(room.height):
		return false
	var row := str(room.cells[y])
	if row[x] == value:
		return false
	row[x] = value
	room.cells[y] = row
	return true


## Changes the room's size around its top left; what falls outside goes, what is new is wall.
static func resize(room: Dictionary, size: Vector2i) -> void:
	size = size.clamp(MIN_SIZE, MAX_SIZE)
	var rows: Array = []
	for y in range(size.y):
		var row := ""
		for x in range(size.x):
			row += cell_at(room, x, y)
		rows.append(row)
	room.cells = rows
	room.width = size.x
	room.height = size.y
	room.objects = (room.objects as Array).filter(func(o: Dictionary) -> bool:
		return float(o.x) >= 0.0 and float(o.y) >= 0.0 and float(o.x) < size.x * CELL and float(o.y) < size.y * CELL + CELL)
	for key: String in ["tiles", "areas"]:
		for spot: String in (room[key] as Dictionary).keys():
			var at := spot.split(",")
			if int(at[0]) >= size.x or int(at[1]) >= size.y:
				room[key].erase(spot)


## Why a room cannot be played (German, for the editor's list); [] when it can.
static func problems(room: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if int(room.get("schema_version", 0)) != SCHEMA:
		out.append("Unbekannte Dateiversion.")
		return out
	if not WORLDS.has(str(room.get("world", ""))):
		out.append("Unbekannte Welt.")
		return out
	var w := int(room.get("width", 0))
	var h := int(room.get("height", 0))
	if w < MIN_SIZE.x or h < MIN_SIZE.y or w > MAX_SIZE.x or h > MAX_SIZE.y or (room.get("cells", []) as Array).size() != h:
		out.append("Die Raumgröße stimmt nicht.")
		return out
	var floor_cells := 0
	for row: Variant in room.cells:
		if str(row).length() != w:
			out.append("Die Raumgröße stimmt nicht.")
			return out
		floor_cells += str(row).count(FLOOR) + str(row).count(BRIDGE)
	if floor_cells == 0:
		out.append("Der Raum hat keinen Boden.")
	var starts := (room.get("objects", []) as Array).filter(func(o: Dictionary) -> bool: return str(o.kind) == "start")
	if starts.is_empty():
		out.append("Der Spielerstart fehlt.")
	else:
		var c := Vector2i(int(float(starts[0].x) / CELL), int((float(starts[0].y) - 6.0) / CELL))
		if cell_at(room, c.x, c.y) not in [FLOOR, BRIDGE]:
			out.append("Der Spielerstart steht nicht auf Boden.")
	return out


## Hints that do not stop a test (a pad into a wall, a group without a gate) in German.
static func hints(room: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var openers := {}
	var targets := {}
	var dug := Gates.dug(room)
	for o: Dictionary in room.objects:
		match str(o.kind):
			"launch":
				# a sleeping pad is what its group opens
				if str(o.get("wake", "")) != "":
					targets[str(o.wake)] = true
				var step: Vector2i = {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)}.get(str(o.get("dir", "n")), Vector2i.ZERO)
				var at := Vector2i(int(float(o.x) / CELL), int(float(o.y) / CELL)) + step * int(o.get("cells", 4))
				# a jump puzzle throws into traps on purpose
				if str(room.get("role", "")) != "jump" and not dug.has(at) and cell_at(room, at.x, at.y) not in [FLOOR, BRIDGE]:
					out.append("Eine Sprungplatte landet nicht auf Boden (Feld %d, %d)." % [at.x, at.y])
			"plate", "lever", "brazier":
				openers[str(o.get("group", "A"))] = true
			"gate", "secret":
				var two := Gates.cells(o)
				if cell_at(room, two[0].x, two[0].y) != WALL or cell_at(room, two[1].x, two[1].y) != WALL:
					out.append("Ein Tor steht nicht in einer Mauer (Feld %d, %d)." % [two[0].x, two[0].y])
				if str(o.get("lock", "")) == "" and (str(o.kind) == "secret" or Gates.closes(o)):
					targets[str(o.get("group", "A"))] = true
	for g: String in openers:
		# the floor's own plates (group seq) open what the floor's plan says
		if not targets.has(g) and g != "seq":
			out.append("Gruppe %s öffnet nichts: es fehlt ein Tor oder Geheimgang dieser Gruppe." % g)
	for g: String in targets:
		if not openers.has(g):
			out.append("Tor der Gruppe %s hat keinen Auslöser." % g)
	out.append_array(floor_hints(room))
	return out


## How much a part's picture is stretched: Größe (scale) times Breite (scale_w) and Höhe (scale_h).
static func stretch(o: Dictionary) -> Vector2:
	return Vector2(float(o.get("scale_w", 1.0)), float(o.get("scale_h", 1.0))) * float(o.get("scale", 1.0))


## Where a room's enemies come from: "random" by chance, "manual" where they were set. An older file
## without the setting goes by what it holds.
static func spawn_mode(room: Dictionary) -> String:
	var chosen := str(room.get("spawn_mode", ""))
	if chosen != "":
		return chosen
	for o: Dictionary in room.get("objects", []):
		if str(o.get("kind", "")) == "enemy":
			return "manual"
	return "random"


## The size in cells a room for floors must have: that of its slots.
static func floor_size(room: Dictionary) -> Vector2i:
	var want := Vector2i.ZERO
	for s: Array in room.get("slots", [[0, 0]]):
		want = want.max(Vector2i(int(s[0]) + 1, int(s[1]) + 1) * (SLOT + SLOT_GAP) - SLOT_GAP)
	return want


## True when a room has the size of its slots; any other size cannot stand on a floor.
static func floor_size_fits(room: Dictionary) -> bool:
	return Vector2i(int(room.width), int(room.height)) == floor_size(room)


## What keeps a room marked for floors out of them, in German. A slot is SLOT cells, SLOT_GAP cells lie
## between two slots. A room needs one door spot at least; with few it only comes where they suit the floor.
static func floor_hints(room: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not bool(room.get("in_floors", false)):
		return out
	if not floor_size_fits(room):
		var want := floor_size(room)
		out.append("Für Etagen muss der Raum %d x %d Felder groß sein (Größe seiner Plätze)." % [want.x, want.y])
		return out
	if (room.get("ports", []) as Array).is_empty():
		out.append("Für Etagen braucht der Raum mindestens eine Türstelle.")
	return out


static func path_of(world: String, id: String) -> String:
	return DIR.path_join(world).path_join(id + ".json")


## Writes the room as readable JSON (an old file stays as .bak). Returns "" or a German error.
static func save(room: Dictionary, base: String = DIR) -> String:
	var folder := base.path_join(str(room.world))
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		return "Der Raumordner konnte nicht angelegt werden."
	var path := folder.path_join(str(room.id) + ".json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return "Der Raum konnte nicht geschrieben werden."
	file.store_string(JSON.stringify(room, "\t", false))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return "Der Raum konnte nicht übernommen werden."
	return ""


## A room file, {} when missing or broken.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	Gates.adopt_pieces(parsed)
	return parsed


## Every room of `world`, sorted by title; each with its file in `_path`.
static func list_rooms(world: String, base: String = DIR) -> Array:
	var out: Array = []
	var folder := base.path_join(world)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		return out
	for name: String in DirAccess.get_files_at(folder):
		if name.ends_with(".json"):
			var room := load_file(folder.path_join(name))
			if not room.is_empty():
				room["_path"] = folder.path_join(name)
				out.append(room)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.title).naturalnocasecmp_to(str(b.title)) < 0)
	return out


## Removes a room file and its backup.
static func remove(room: Dictionary, base: String = DIR) -> void:
	var path := ProjectSettings.globalize_path(base.path_join(str(room.world)).path_join(str(room.id) + ".json"))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")
