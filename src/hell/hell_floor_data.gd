extends RefCounted
## Loads the baked hell floors (assets/data/hell_floors.json, written by
## tools/hell_dungeon/bake_floors.js from the same core as the browser preview)
## and turns one floor into runtime data: packed cell arrays plus plain
## dictionaries for rooms, doors, props and entities.

const DATA_PATH := "res://assets/data/hell_floors.json"
const VOID := 0
const FLOOR := 1
const LAVA := 2
const BRIDGE := 3


## Returns every baked floor dictionary, or an empty array when the file is missing or broken.
static func load_all(path: String = DATA_PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	return (parsed as Dictionary).get("floors", [])


## Converts one baked floor into runtime data. The input dictionary is not changed.
static func prepare(raw: Dictionary) -> Dictionary:
	var cols := int(raw.cols)
	var rows := int(raw.rows)
	var count := cols * rows
	var grid := PackedByteArray()
	var holes := PackedByteArray()
	var tiles := PackedByteArray()
	grid.resize(count)
	holes.resize(count)
	tiles.resize(count)
	var grid_text: String = raw.grid
	var hole_text: String = raw.holes
	var tile_text: String = raw.tiles
	for i in range(count):
		grid[i] = grid_text.unicode_at(i) - 48
		holes[i] = hole_text.unicode_at(i) - 48
		tiles[i] = _base36(tile_text.unicode_at(i))
	var room_at := PackedInt32Array()
	room_at.resize(count)
	var baked_rooms: Array = raw.room_at
	for i in range(count):
		room_at[i] = int(baked_rooms[i])
	var rooms: Array = []
	for r: Dictionary in raw.rooms:
		var room := r.duplicate(true)
		room.index = int(r.index)
		for k in ["bx", "by", "bw", "bh", "mobs"]:
			room[k] = int(r[k])
		room.fight = false
		room.doors = []
		room.cells = []
		rooms.append(room)
	for i in range(count):
		if room_at[i] >= 0:
			rooms[room_at[i]].cells.append(Vector2i(i % cols, i / cols))
	var doors: Array = []
	for d: Dictionary in raw.doors:
		var door := d.duplicate(true)
		door.a = int(d.a)
		door.b = int(d.b)
		door.unlocked = false
		door.broken = false
		var cells: Array[Vector2i] = []
		for c: Array in d.cells:
			cells.append(Vector2i(int(c[0]), int(c[1])))
		door.cells = cells
		door.index = doors.size()
		doors.append(door)
		rooms[door.a].doors.append(door.index)
		rooms[door.b].doors.append(door.index)
	var groups: Dictionary = {}
	for key: String in (raw.get("groups", {}) as Dictionary):
		var g: Dictionary = (raw.groups[key] as Dictionary).duplicate(true)
		g.solved = false
		g.next = 1
		groups[key] = g
	var ents: Array = []
	for e: Dictionary in raw.ents:
		var ent := e.duplicate(true)
		ent.room = int(e.room)
		if ent.has("order"):
			ent.order = int(ent.order)
		ents.append(ent)
	return {
		"n": int(raw.n), "title": raw.title, "circle": raw.circle, "final": bool(raw.get("final", false)),
		"theme": raw.theme, "boss": raw.boss, "diff": raw.diff, "quick": int(raw.get("quick", -1)),
		"cols": cols, "rows": rows, "cell": int(raw.get("cell", 96)), "tile_names": raw.tile_names,
		"grid": grid, "holes": holes, "tiles": tiles, "room_at": room_at,
		"rooms": rooms, "doors": doors, "groups": groups, "ents": ents,
		"props": raw.props, "decals": raw.decals, "wall_decor": raw.wall_decor, "lights": raw.lights.duplicate(true),
	}


static func _base36(code: int) -> int:
	return code - 48 if code < 58 else code - 87
