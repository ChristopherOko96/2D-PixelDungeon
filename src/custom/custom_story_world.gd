extends RefCounted
## Seeded assembly of authored 96px story modules. Current Story world data,
## renderer and gameplay are reused; the legacy editor/library is not involved.
const Data = preload("res://src/custom/custom_story_data.gd")
const WorldPack = preload("res://src/world_kit/world_pack.gd")
const C := 96.0
const DIRECTIONS := {"north": Vector2i.UP, "east": Vector2i.RIGHT, "south": Vector2i.DOWN, "west": Vector2i.LEFT}
const OPPOSITE := {"north": "south", "east": "west", "south": "north", "west": "east"}

var story: Dictionary = {}
var pack: Dictionary = {}
var last_errors: Array[String] = []
var error_message: String = ""
var _preview: String = ""


## `preview_room_id` tests one draft module in the same renderer and runtime.
func _init(record: Dictionary, preview_room_id: String = "") -> void:
	story = record.duplicate(true)
	_preview = preview_room_id
	var info: Dictionary = Data.WORLDS.get(str(story.get("world", "")), Data.WORLDS.krypta)
	pack = DataCache.load_dict(str(info.pack))


## Count of playable floors (one for a selected-room preview).
func floor_count() -> int:
	return 1 if not _preview.is_empty() else clampi(int(story.get("floor_count", 1)), 1, 10)


## Builds deterministic connected geometry in hell_floor_data's raw schema.
## Returns {} plus last_errors when the authoring constraints cannot be fulfilled.
func build_raw(n: int, run: int) -> Dictionary:
	error_message = ""
	last_errors = Data.validate(story, _preview.is_empty())
	if not _preview.is_empty():
		last_errors.clear()
		var selected := _find_room(_preview)
		if selected.is_empty(): last_errors.append("Der gewählte Raum fehlt.")
		else: last_errors = Data.room_problems(selected, true)
	if not last_errors.is_empty():
		error_message = "\n".join(last_errors)
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldPack.floor_seed(run, n)
	if not _preview.is_empty():
		return _raster([{ "room": _find_room(_preview), "at": Vector2i.ZERO, "parent": -1, "depth": 0, "used": {}}], [], n, run, rng)
	# Repeated attempts choose compatible modules and free ports, never bend or
	# stretch authored geometry to force an impossible connection.
	for attempt in range(120):
		var assembled := _assemble(rng)
		if not assembled.is_empty(): return _raster(assembled.rooms, assembled.links, n, run, rng)
	last_errors = ["Die Raumanschlüsse passen nicht zu einer vollständigen Etage. Ergänze gegenüberliegende Türen und mehr Raumvarianten."]
	error_message = last_errors[0]
	return {}


func _find_room(id: String) -> Dictionary:
	for room: Dictionary in story.get("rooms", []):
		if str(room.id) == id: return room
	return {}


func _pool(role: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for room: Dictionary in story.rooms:
		if str(room.role) == role: out.append(room)
	return out


func _assemble(rng: RandomNumberGenerator) -> Dictionary:
	var starts := _pool("start")
	var placed: Array = [{"room": starts[rng.randi_range(0, starts.size() - 1)], "at": Vector2i.ZERO, "parent": -1, "depth": 0, "used": {}}]
	var roles: Array[String] = []
	var count := int(story.rooms_per_floor)
	for index in range(count - 2): roles.append("combat")
	if roles.size() > 1 and not _pool("shop").is_empty(): roles[0] = "shop"
	if roles.size() > 2 and not _pool("treasure").is_empty(): roles[1] = "treasure"
	# Shuffle the non-terminal roles, preserving a dedicated entrance and boss.
	for i in range(roles.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := roles[i]
		roles[i] = roles[j]
		roles[j] = swap
	roles.append("boss")
	var links: Array = []
	for role: String in roles:
		var candidates := _pool(role)
		var accepted := false
		for attempt in range(120):
			var parent_index := rng.randi_range(0, placed.size() - 1)
			# Prefer distant parents for the guardian, but allow fallback to any port.
			if role == "boss" and attempt < 60:
				for k in range(placed.size()):
					if int(placed[k].depth) > int(placed[parent_index].depth): parent_index = k
			var parent: Dictionary = placed[parent_index]
			var ports: Array = parent.room.ports
			if ports.is_empty(): continue
			var pi := rng.randi_range(0, ports.size() - 1)
			if parent.used.has(pi): continue
			var p: Dictionary = ports[pi]
			var room: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
			var choices: Array = []
			for q: Dictionary in room.ports:
				if str(q.side) == OPPOSITE[str(p.side)]: choices.append(q)
			if choices.is_empty(): continue
			var q: Dictionary = choices[rng.randi_range(0, choices.size() - 1)]
			var direction: Vector2i = DIRECTIONS[str(p.side)]
			var from: Vector2i = parent.at + _cell(p.cell)
			var to: Vector2i = from + direction * rng.randi_range(5, 8)
			var at := to - _cell(q.cell)
			var rect := Rect2i(at, Vector2i(int(room.width), int(room.height))).grow(1)
			var fits := true
			for old: Dictionary in placed:
				var occupied := Rect2i(old.at, Vector2i(int(old.room.width), int(old.room.height))).grow(1)
				if occupied.intersects(rect): fits = false
			if not fits: continue
			# The short connector may not tunnel through any unrelated module.
			var across := Vector2i.DOWN if direction.x != 0 else Vector2i.RIGHT
			for old_index in range(placed.size()):
				if old_index == parent_index: continue
				var old: Dictionary = placed[old_index]
				var occupied := Rect2i(old.at, Vector2i(int(old.room.width), int(old.room.height))).grow(1)
				for step in range(int(from.distance_to(to)) + 1):
					if occupied.has_point(from + direction * step) or occupied.has_point(from + direction * step + across): fits = false
			if not fits: continue
			parent.used[pi] = true
			var child_used := {}
			child_used[room.ports.find(q)] = true
			links.append({"a": parent_index, "b": placed.size(), "from": from, "to": to, "dir": direction})
			placed.append({"room": room, "at": at, "parent": parent_index, "depth": int(parent.depth) + 1, "used": child_used})
			accepted = true
			break
		if not accepted: return {}
	return {"rooms": placed, "links": links}


func _raster(placed: Array, links: Array, n: int, run: int, rng: RandomNumberGenerator) -> Dictionary:
	var min_cell := Vector2i(100000, 100000)
	var max_cell := Vector2i(-100000, -100000)
	for item: Dictionary in placed:
		min_cell = min_cell.min(item.at)
		max_cell = max_cell.max(item.at + Vector2i(int(item.room.width), int(item.room.height)))
	var shift := Vector2i(2, 2) - min_cell
	var dimensions := max_cell - min_cell + Vector2i(4, 4)
	var cols := dimensions.x
	var rows := dimensions.y
	var grid: Array = []
	var room_at: Array = []
	var tiles: Array = []
	grid.resize(cols * rows); grid.fill(0)
	room_at.resize(cols * rows); room_at.fill(-1)
	tiles.resize(cols * rows); tiles.fill(0)
	var rooms: Array = []
	var ents: Array = []
	var props: Array = []
	var lights: Array = []
	var info: Dictionary = Data.WORLDS.get(str(story.world), Data.WORLDS.krypta)
	var manifest: Dictionary = DataCache.load_dict(str(info.sprites) + "manifest.json")
	for index in range(placed.size()):
		var item: Dictionary = placed[index]
		var room: Dictionary = item.room
		var at: Vector2i = item.at + shift
		var role := "start" if not _preview.is_empty() else str(room.role)
		for point: Array in room.floor:
			var p := at + _cell(point)
			grid[p.y * cols + p.x] = 1
			room_at[p.y * cols + p.x] = index
			tiles[p.y * cols + p.x] = rng.randi_range(0, 4)
		var center := _nearest_floor(room, Vector2i(int(room.width) / 2, int(room.height) / 2))
		var spawn_cells: Array = []
		for point: Array in room.get("enemy_spawns", []):
			var p := at + _cell(point)
			spawn_cells.append([p.x, p.y])
		rooms.append({"index": index, "id": "%s_%d" % [room.id, index], "module_id": room.id, "preview_role": str(room.role) if not _preview.is_empty() else "", "name": str(room.title), "kind": str(room.role).to_upper(),
			"type": role, "gtype": role, "icon": "", "icon_key": "", "bx": at.x + 1, "by": at.y + 1,
			"bw": int(room.width) - 2, "bh": int(room.height) - 2, "mobs": 4 if role == "combat" else 2 if role == "boss" else 0,
			"spawn": [center.x - 0.5, center.y - 0.3], "spawn_cells": spawn_cells, "drop": "", "reward": null,
			"cleared": role not in ["combat", "boss"], "info": str(room.title), "on_path": true, "seq": false, "tidy": true})
		for prop: Dictionary in room.get("props", []):
			if not manifest.has(str(prop.name)): continue
			var p := (Vector2(at) + Vector2(float(prop.x) + 0.5, float(prop.y) + 0.7)) * C
			props.append({"name": prop.name, "x": p.x, "y": p.y, "flip": false, "low": false, "solid": null})
			if str(prop.name).contains("brazier") or str(prop.name).contains("torch"):
				lights.append({"x": p.x, "y": p.y - 50.0, "r": 240, "c": "255,170,80" if str(story.world) == "hell" else "120,180,255"})
		var point := (Vector2(at + center) + Vector2(0.5, 0.7)) * C
		if role == "shop":
			# the same merchant stand as the main stories' key room (world_core.gd): trader,
			# table, the shop's interaction point and a warm light over them
			ents.append({"type": "npc", "x": point.x, "y": point.y - C * 0.95, "room": index})
			if manifest.has("shop_table"):
				var table := Vector2(point.x, point.y - C * 0.1)
				props.append({"name": "shop_table", "x": table.x, "y": table.y, "flip": false, "low": false, "solid": [table.x - 75.0, table.y - 40.0, table.x + 75.0, table.y]})
			ents.append({"type": "shop", "x": point.x, "y": point.y, "room": index})
			lights.append({"x": point.x, "y": point.y - C * 1.1, "r": 300, "c": "255,200,140", "f": 2})
			ents.append({"type": "well", "x": point.x + C * 2.0, "y": point.y, "room": index, "used": false})
		elif role == "treasure":
			ents.append({"type": "chest", "x": point.x, "y": point.y, "room": index, "state": "", "magic": false, "loot": {"gems": 6 + n, "heart": true}})
		if role == "boss" or not _preview.is_empty():
			var exit_cell := _nearest_floor(room, Vector2i(int(room.width) / 2, 2))
			var exit_at := (Vector2(at + exit_cell) + Vector2(0.5, 0.7)) * C
			ents.append({"type": "portal", "x": exit_at.x, "y": exit_at.y, "room": index, "active": not _preview.is_empty()})
	var doors: Array = []
	for link: Dictionary in links:
		var from: Vector2i = link.from + shift
		var to: Vector2i = link.to + shift
		var d: Vector2i = link.dir
		var across := Vector2i.DOWN if d.x != 0 else Vector2i.RIGHT
		for step in range(int(from.distance_to(to)) + 1):
			for off: Vector2i in [Vector2i.ZERO, across]:
				var p := from + d * step + off
				grid[p.y * cols + p.x] = 1
				room_at[p.y * cols + p.x] = int(link.b)
		var a := from
		var b := from + across
		var middle := (Vector2(a + b) * 0.5 + Vector2(0.5, 0.5)) * C
		doors.append({"a": int(link.a), "b": int(link.b), "kind": "open", "key": "", "group": "", "hidden": false,
			"dir": "h" if d.x != 0 else "v", "cells": [[a.x, a.y], [b.x, b.y]], "x0": a.x, "y0": a.y,
			"x1": b.x, "y1": b.y, "cx": middle.x, "cy": middle.y, "crack_x": middle.x, "crack_y": middle.y, "boss_gate": false})
	var floor_n := clampi(n, 1, pack.floors.size() - 1)
	var definition: Dictionary = pack.floors[floor_n]
	var depth: float = (n - 1) / 9.0
	var lighting: Dictionary = pack.get("light", {}) if pack.get("light") is Dictionary else {}
	var theme := {"dark": (0.6 + depth * 0.2) * float(lighting.get("dark", 1.0)), "grade": depth * 0.16,
		"vignette": (0.25 + depth * 0.45) * float(lighting.get("vignette", 1.0)), "embers": 2 + roundi(depth * 5), "hot": 0.0, "wall_glow": depth, "circle": 0}
	if str(story.world) == "krypta": theme.crypt = true
	if str(story.world) == "frost": theme.frost = true
	var grid_text := ""
	var tile_text := ""
	for i in range(grid.size()):
		grid_text += str(grid[i])
		tile_text += str(tiles[i])
	var diff: Dictionary = pack.get("diff", {})
	return {"n": n, "title": "%s · Etage %d" % [story.title, n], "circle": str(info.name), "final": n == floor_count(),
		"seed": WorldPack.floor_seed(run, n), "run": run, "cell": int(C), "cols": cols, "rows": rows,
		"theme": theme, "boss": definition.boss.duplicate(true), "diff": {"hp": 1.0 + (n - 1) * float(diff.get("hp_step", 0.16)), "speed": 1.0 + (n - 1) * float(diff.get("speed_step", 0.04)), "extra": int(floor((n - 1) / maxf(1.0, float(diff.get("extra_every", 3))))), "shooters": bool(definition.get("shooters", false))},
		"grid": grid_text, "holes": "0".repeat(cols * rows), "tiles": tile_text, "tile_names": ["floor_00", "floor_01", "floor_02", "floor_03", "floor_04"],
		"room_at": room_at, "quick": -1, "rooms": rooms, "doors": doors, "groups": {}, "ents": ents, "props": props, "decals": [], "wall_decor": [], "lights": lights}


static func _cell(point: Array) -> Vector2i:
	return Vector2i(int(point[0]), int(point[1]))


static func _nearest_floor(room: Dictionary, wanted: Vector2i) -> Vector2i:
	var best := _cell(room.floor[0])
	var distance := best.distance_squared_to(wanted)
	for point: Array in room.floor:
		var p := _cell(point)
		if p.distance_squared_to(wanted) < distance:
			best = p
			distance = p.distance_squared_to(wanted)
	return best
