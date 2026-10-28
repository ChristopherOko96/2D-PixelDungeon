extends RefCounted
## Breakable loot chests on the host (assets/data/loot_chests.json). A new floor
## gets 3-5 chests in random rooms (never the boss room), on the room
## template's chest_spawns or, without them, on floor spots along a north wall.
## Any attack that reaches a chest counts as one hit; after `hits` hits it
## bursts open and drops loot: a general perk the breaker's class can use. A
## hero walking over the loot takes it (PerkRules.grant). Chest and loot state
## is kept per room, so a revisited room shows what is left. Clients draw
## `snapshot()`; chests block heroes like a small crate.

const PerkRules = preload("res://src/perk_rules.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const DATA_PATH := "res://assets/data/loot_chests.json"

var game: Node
## room id -> Array of chests {id, pos, hits, max, open, hit_count}.
var chests: Dictionary = {}
## room id -> Array of loot {id, pos, kind, perk, name, age}.
var loot: Dictionary = {}
var _data: Dictionary = {}
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func bind(owner: Node) -> void:
	game = owner
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	_data = parsed if parsed is Dictionary else {}


func _value(key: String, fallback: float) -> float:
	return float(_data.get(key, fallback))


## Places a fresh floor's breakables: 3-5 loot chests in random rooms (never the
## boss room) and a few crates along the walls of every room. Each one is a
## solid 32 px cell in the room's collision; a placement that would cut a door
## or spawn off from the rest of the room is dropped.
func place_floor(layouts: Array, seed_value: int) -> void:
	chests.clear()
	loot.clear()
	_rng.seed = seed_value + 90001
	var rooms: Array = []
	for index in range(layouts.size()):
		var layout: Dictionary = layouts[index]
		if bool(layout.get("boss", false)) or index == layouts.size() - 1: continue
		rooms.append(layout)
	_place_chests(rooms)
	for layout: Dictionary in layouts: _place_crates(layout)
	for layout: Dictionary in layouts: _solidify(layout)


func _place_chests(rooms: Array) -> void:
	if rooms.is_empty(): return
	var wanted := _rng.randi_range(int(_value("per_floor_min", 3)), int(_value("per_floor_max", 5)))
	var per_room := int(_value("per_room", 2))
	var placed := 0
	var order: Array = rooms.duplicate()
	for index in range(order.size() - 1, 0, -1):
		var swap := _rng.randi_range(0, index)
		var held: Variant = order[index]
		order[index] = order[swap]
		order[swap] = held
	# Round-robin over the shuffled rooms, so chests spread before doubling up.
	for round_index in range(per_room):
		for layout: Dictionary in order:
			if placed >= wanted: return
			var spots := _spots(layout)
			var room_id := str(layout.id)
			var taken: Array = chests.get(room_id, [])
			if taken.size() > round_index or spots.size() <= taken.size(): continue
			var free := spots.filter(func(spot: Vector2) -> bool: return taken.all(func(chest: Dictionary) -> bool: return Vector2(chest.pos).distance_to(spot) > 96.0))
			if free.is_empty(): continue
			var spot: Vector2 = free[_rng.randi_range(0, free.size() - 1)]
			taken.append({"id": _next_id, "kind": "chest", "pos": spot, "hits": 0, "max": int(_value("hits", 3)), "open": false})
			chests[room_id] = taken
			_next_id += 1
			placed += 1


## Crates in small groups along the walls (wall above or beside the cell).
func _place_crates(layout: Dictionary) -> void:
	var range_values: Array = _data.get("crates_per_room", [3, 7])
	var wanted := _rng.randi_range(int(range_values[0]), int(range_values[1]))
	var spots := _spots(layout, true)
	var room_id := str(layout.id)
	var taken: Array = chests.get(room_id, [])
	var tries := 0
	while wanted > 0 and not spots.is_empty() and tries < 40:
		tries += 1
		var seed_spot: Vector2 = spots[_rng.randi_range(0, spots.size() - 1)]
		# A group of 1-3 crates next to each other along the wall.
		var group := [seed_spot]
		for offset: Vector2 in [Vector2(32, 0), Vector2(-32, 0)]:
			if group.size() < _rng.randi_range(1, 3) and spots.has(seed_spot + offset): group.append(seed_spot + offset)
		for spot: Vector2 in group:
			if wanted <= 0: break
			if taken.any(func(other: Dictionary) -> bool: return Vector2(other.pos).distance_to(spot) < 31.0): continue
			if taken.any(func(other: Dictionary) -> bool: return str(other.get("kind", "chest")) == "chest" and Vector2(other.pos).distance_to(spot) < 96.0): continue
			taken.append({"id": _next_id, "kind": "crate", "pos": spot, "hits": 0, "max": int(_value("crate_hits", 2)), "open": false})
			_next_id += 1
			wanted -= 1
			spots.erase(spot)
	if not taken.is_empty(): chests[room_id] = taken


## Puts the room's breakables into its collision, dropping any that would cut
## off a door, the stairs or a spawn (4-neighbour flood over the floor cells).
func _solidify(layout: Dictionary) -> void:
	var room_id := str(layout.id)
	var list: Array = chests.get(room_id, [])
	if list.is_empty(): return
	var floor_cells := {}
	for entry: Dictionary in layout.get("painted_tiles", []):
		if str(entry.get("layer", "")) == "floor" and not bool(entry.get("solid", false)): floor_cells[Vector2i(int(entry.x), int(entry.y))] = true
	var anchors: Array[Vector2i] = []
	for exit: Dictionary in layout.get("exits", []): anchors.append(_cell(Dungeon._rect(exit.rect).get_center()))
	for point: Variant in Array(layout.get("player_spawns", [])) + Array(layout.get("enemy_spawns", [])): anchors.append(_cell(Vector2(point)))
	var blocked := {}
	var kept: Array = []
	for item: Dictionary in list:
		var cell := _cell(item.pos)
		blocked[cell] = true
		if anchors.has(cell) or not _connected(floor_cells, blocked, anchors):
			blocked.erase(cell)
			continue
		kept.append(item)
	chests[room_id] = kept
	for item: Dictionary in kept:
		var rect := _rect_of(item)
		layout.obstacles.append(rect)
		if not layout.has("breakable_obstacles"): layout.breakable_obstacles = []
		layout.breakable_obstacles.append(rect)


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(int(floor(point.x / 32.0)), int(floor(point.y / 32.0)))


func _rect_of(item: Dictionary) -> Array:
	var cell := _cell(item.pos)
	return [float(cell.x) * 32.0, float(cell.y) * 32.0, 32.0, 32.0]


func _connected(floor_cells: Dictionary, blocked: Dictionary, anchors: Array[Vector2i]) -> bool:
	if anchors.is_empty(): return true
	var start: Vector2i = anchors[0]
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if seen.has(next) or blocked.has(next) or not floor_cells.has(next): continue
			seen[next] = true
			queue.append(next)
	for anchor: Vector2i in anchors:
		if not seen.has(anchor): return false
	return true


## Candidate spots of a room (cell centres, world px): authored chest_spawns
## first (chests only); otherwise floor cells against a wall with open floor
## around, away from doors and spawns. `crates` also accepts side walls.
func _spots(layout: Dictionary, crates: bool = false) -> Array:
	var result: Array = []
	if not crates:
		for cell: Variant in layout.get("chest_spawns", []):
			if cell is Array and cell.size() == 2: result.append(Vector2(float(cell[0]) * 32.0 + 16.0, float(cell[1]) * 32.0 + 16.0))
		if not result.is_empty(): return result
	var floor_cells := {}
	var walls := {}
	for entry: Dictionary in layout.get("painted_tiles", []):
		var cell := Vector2i(int(entry.x), int(entry.y))
		if bool(entry.get("solid", false)): walls[cell] = true
		elif str(entry.get("layer", "")) == "floor": floor_cells[cell] = true
	var keep_clear: Array = []
	for exit: Dictionary in layout.get("exits", []): keep_clear.append(Dungeon._rect(exit.rect).get_center())
	for point: Variant in Array(layout.get("player_spawns", [])) + Array(layout.get("enemy_spawns", [])): keep_clear.append(Vector2(point))
	var clearance := _value("clearance", 3) * 32.0
	for cell: Vector2i in floor_cells:
		if walls.has(cell): continue
		var against_north := walls.has(cell + Vector2i.UP) and floor_cells.has(cell + Vector2i.DOWN) and floor_cells.has(cell + Vector2i.DOWN * 2)
		var against_side := crates and (walls.has(cell + Vector2i.LEFT) and floor_cells.has(cell + Vector2i.RIGHT * 2) or walls.has(cell + Vector2i.RIGHT) and floor_cells.has(cell + Vector2i.LEFT * 2))
		if not against_north and not against_side: continue
		var open := 0
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if floor_cells.has(cell + step): open += 1
		if open < 3: continue
		var center := Vector2(cell) * 32.0 + Vector2(16, 16)
		if keep_clear.any(func(other: Vector2) -> bool: return other.distance_to(center) < clearance): continue
		if Dungeon.segment_blocked(center, center, 12.0, layout): continue
		result.append(center)
	result.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result


func _room_id() -> String:
	return str(game.current_layout.get("id", ""))


func _here() -> Array:
	return chests.get(_room_id(), [])


## One hit on every closed chest inside the circle (areas, explosions).
func hit_circle(point: Vector2, radius: float, owner: int, excluded: Array = []) -> void:
	for chest: Dictionary in _here():
		if bool(chest.open) or int(chest.id) in excluded: continue
		if Vector2(chest.pos).distance_to(point) <= radius + _value("radius", 14): _hit(chest, owner, (Vector2(chest.pos) - point).normalized())


## A projectile or beam segment; returns true when it struck a closed chest.
## A shot dictionary remembers its chests, so one shot hits each only once.
func hit_segment(from: Vector2, to: Vector2, radius: float, owner: int, shot: Dictionary = {}) -> bool:
	for chest: Dictionary in _here():
		if bool(chest.open): continue
		if not shot.is_empty() and int(chest.id) in Array(shot.get("chest_ids", [])): continue
		if game.perk_combat.segment_hits(from, to, chest.pos, radius + _value("radius", 14)):
			if not shot.is_empty():
				if not shot.has("chest_ids"): shot.chest_ids = []
				shot.chest_ids.append(int(chest.id))
			_hit(chest, owner, (to - from).normalized())
			return true
	return false


## A melee swing: chests within reach in front of the hero.
func hit_arc(origin: Vector2, aim: Vector2, reach: float, arc: float, owner: int) -> void:
	for chest: Dictionary in _here():
		if bool(chest.open): continue
		var offset: Vector2 = Vector2(chest.pos) - origin
		if offset.length() > reach + _value("radius", 14): continue
		if offset.length() > 0.1 and absf(aim.angle_to(offset)) > arc * 0.5 + 0.2: continue
		_hit(chest, owner, offset.normalized())


func _hit(chest: Dictionary, owner: int, direction: Vector2) -> void:
	chest.hits = int(chest.hits) + 1
	chest.hit_dir = direction
	if int(chest.hits) < int(chest.max): return
	chest.open = true
	# The broken box no longer blocks: its cell leaves the room's collision.
	var rect := _rect_of(chest)
	for key: String in ["obstacles", "breakable_obstacles"]:
		var list_of: Array = game.current_layout.get(key, [])
		for index in range(list_of.size() - 1, -1, -1):
			if Array(list_of[index]) == rect:
				list_of.remove_at(index)
				break
	if str(chest.get("kind", "chest")) == "crate":
		game.add_fx("crate_break", chest.pos, 20.0)
		game.layout_changed()
		return
	var drop := _roll_drop(owner)
	if not drop.is_empty():
		drop.id = _next_id
		_next_id += 1
		drop.pos = Vector2(chest.pos) + Vector2(0, 34)
		drop.age = 0.0
		var list: Array = loot.get(_room_id(), [])
		list.append(drop)
		loot[_room_id()] = list
	game.add_fx("chest_open", chest.pos, 24.0)
	game.layout_changed()
	print("CHEST_OPENED room=%s perk=%s" % [_room_id(), str(drop.get("perk", ""))])


## Rolls one drop for the hero who opened the chest (perks their class can use).
func _roll_drop(owner: int) -> Dictionary:
	var player: Dictionary = game.players.get(owner, {})
	if player.is_empty():
		for candidate: Dictionary in game.players.values():
			player = candidate
			break
	var offer := PerkRules.offer(player, game.balance, _rng, 1) if not player.is_empty() else []
	if offer.is_empty() or str(offer[0].get("stat", "")) == "reserve": return {}
	return {"kind": "perk", "perk": str(offer[0].id), "name": str(offer[0].get("name", ""))}


## Pickups and keeping heroes out of chests; call once per host step.
func step(delta: float) -> void:
	var list: Array = loot.get(_room_id(), [])
	for index in range(list.size() - 1, -1, -1):
		var item: Dictionary = list[index]
		item.age = float(item.age) + delta
		if float(item.age) < 0.5: continue
		for id: int in game.players:
			var player: Dictionary = game.players[id]
			if int(player.hp) <= 0 or Vector2(player.pos).distance_to(item.pos) > _value("pickup_radius", 22) + float(game.balance.player.radius): continue
			if _take(id, player, item):
				list.remove_at(index)
				break
	for chest: Dictionary in _here():
		if bool(chest.open): continue
		for player: Dictionary in game.players.values():
			var offset: Vector2 = Vector2(player.pos) - Vector2(chest.pos)
			var minimum := _value("radius", 14) + float(game.balance.player.radius)
			if offset.length() < minimum and offset.length() > 0.01:
				player.pos = Dungeon.move_actor(player.pos, offset.normalized() * (minimum - offset.length()), float(game.balance.player.radius), game.current_layout)


func _take(id: int, player: Dictionary, item: Dictionary) -> bool:
	if str(item.kind) != "perk": return false
	var definition := PerkRules.find(game.balance, str(item.perk))
	if definition.is_empty(): return false
	if bool(definition.get("projectile_only", false)) and bool(player.get("melee", false)): return false
	if not PerkRules.grant(player, definition, game.balance): return false
	game.perk_combat.granted(id, definition)
	player.last_perk = str(item.perk)
	player.loot_taken = int(player.get("loot_taken", 0)) + 1
	game.add_fx("loot_taken", item.pos, 20.0)
	print("LOOT_TAKEN peer=%d perk=%s" % [id, str(item.perk)])
	return true


## Chests and loot of the current room for clients.
func snapshot() -> Dictionary:
	var visible_chests: Array = []
	for chest: Dictionary in _here():
		var direction: Vector2 = chest.get("hit_dir", Vector2.ZERO)
		visible_chests.append({"kind": str(chest.get("kind", "chest")), "id": int(chest.id), "x": Vector2(chest.pos).x, "y": Vector2(chest.pos).y, "hits": int(chest.hits), "max": int(chest.max), "open": bool(chest.open), "dx": direction.x})
	var visible_loot: Array = []
	for item: Dictionary in loot.get(_room_id(), []):
		visible_loot.append({"id": int(item.id), "x": Vector2(item.pos).x, "y": Vector2(item.pos).y, "kind": str(item.kind), "perk": str(item.get("perk", "")), "name": str(item.get("name", "")), "age": float(item.age)})
	return {"chests": visible_chests, "loot": visible_loot}
