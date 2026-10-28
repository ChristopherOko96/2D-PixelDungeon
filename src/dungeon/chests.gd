extends RefCounted
## Loot chests and crates on the host (assets/data/loot_chests.json). A new
## floor gets 3-5 chests in random rooms (never the boss room), on the room
## template's chest_spawns or, without them, on floor spots along a north wall.
## A hero opens a chest with E (`interact`); it drops loot: a general perk the
## opener's class can use (the user's items will join later). Some chests are
## Mimiks (from `mimic_from_floor` with `mimic_chance`, and on the template's
## mimic_spawns): they look exactly like a chest, bite the opener, fight as an
## enemy (balance enemy_roster "mimic") and drop `mimic_drops` perks when they
## fall. Crates break under `crate_hits` hits. A hero walking over the loot
## takes it (PerkRules.grant). State is kept per room, so a revisited room
## shows what is left. Clients draw `snapshot()`, where a Mimik is a "chest".

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
## Mimik rolls use their own stream, so chest and crate spots stay as before.
var _mimic_rng := RandomNumberGenerator.new()


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
	_mimic_rng.seed = seed_value + 90717
	var rooms: Array = []
	for index in range(layouts.size()):
		var layout: Dictionary = layouts[index]
		if bool(layout.get("boss", false)) or index == layouts.size() - 1: continue
		rooms.append(layout)
	_place_chests(rooms)
	for layout: Dictionary in rooms: _place_authored_mimics(layout)
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
			taken.append({"id": _next_id, "kind": "mimic" if _rolls_mimic() else "chest", "pos": spot, "hits": 0, "max": 0, "open": false})
			chests[room_id] = taken
			_next_id += 1
			placed += 1


## True when the next random chest of this floor is a Mimik.
func _rolls_mimic() -> bool:
	var floor_number := int(game.get("floor_index")) if game != null and game.get("floor_index") != null else 1
	if floor_number < int(_value("mimic_from_floor", 2)): return false
	return _mimic_rng.randf() < _value("mimic_chance", 0.16)


## Mimiks the author set in the editor (template mimic_spawns, cells): always there.
func _place_authored_mimics(layout: Dictionary) -> void:
	var room_id := str(layout.id)
	var taken: Array = chests.get(room_id, [])
	for cell: Variant in layout.get("mimic_spawns", []):
		if not cell is Array or cell.size() != 2: continue
		var spot := Vector2(float(cell[0]) * 32.0 + 16.0, float(cell[1]) * 32.0 + 16.0)
		if taken.any(func(other: Dictionary) -> bool: return Vector2(other.pos).distance_to(spot) < 31.0): continue
		taken.append({"id": _next_id, "kind": "mimic", "pos": spot, "hits": 0, "max": 0, "open": false})
		_next_id += 1
	if not taken.is_empty(): chests[room_id] = taken


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
			if taken.any(func(other: Dictionary) -> bool: return str(other.get("kind", "chest")) != "crate" and Vector2(other.pos).distance_to(spot) < 96.0): continue
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


## One hit on every whole crate inside the circle (areas, explosions).
## Chests do not break: they open with E.
func hit_circle(point: Vector2, radius: float, owner: int, excluded: Array = []) -> void:
	for chest: Dictionary in _here():
		if not _breakable(chest) or int(chest.id) in excluded: continue
		if Vector2(chest.pos).distance_to(point) <= radius + _value("radius", 14): _hit(chest, owner, (Vector2(chest.pos) - point).normalized())


## A projectile or beam segment; returns true when it struck a whole crate.
## A shot dictionary remembers its crates, so one shot hits each only once.
func hit_segment(from: Vector2, to: Vector2, radius: float, owner: int, shot: Dictionary = {}) -> bool:
	for chest: Dictionary in _here():
		if not _breakable(chest): continue
		if not shot.is_empty() and int(chest.id) in Array(shot.get("chest_ids", [])): continue
		if game.perk_combat.segment_hits(from, to, chest.pos, radius + _value("radius", 14)):
			if not shot.is_empty():
				if not shot.has("chest_ids"): shot.chest_ids = []
				shot.chest_ids.append(int(chest.id))
			_hit(chest, owner, (to - from).normalized())
			return true
	return false


## A melee swing: crates within reach in front of the hero.
func hit_arc(origin: Vector2, aim: Vector2, reach: float, arc: float, owner: int) -> void:
	for chest: Dictionary in _here():
		if not _breakable(chest): continue
		var offset: Vector2 = Vector2(chest.pos) - origin
		if offset.length() > reach + _value("radius", 14): continue
		if offset.length() > 0.1 and absf(aim.angle_to(offset)) > arc * 0.5 + 0.2: continue
		_hit(chest, owner, offset.normalized())


func _breakable(chest: Dictionary) -> bool:
	return not bool(chest.open) and str(chest.get("kind", "chest")) == "crate"


func _hit(chest: Dictionary, _owner: int, direction: Vector2) -> void:
	chest.hits = int(chest.hits) + 1
	chest.hit_dir = direction
	if int(chest.hits) < int(chest.max): return
	chest.open = true
	# The broken crate no longer blocks: its cell leaves the room's collision.
	_free_cell(chest)
	game.add_fx("crate_break", chest.pos, 20.0)
	game.layout_changed()


## Takes a chest or crate cell out of the room's collision.
func _free_cell(chest: Dictionary) -> void:
	var rect := _rect_of(chest)
	for key: String in ["obstacles", "breakable_obstacles"]:
		var list_of: Array = game.current_layout.get(key, [])
		for index in range(list_of.size() - 1, -1, -1):
			if Array(list_of[index]) == rect:
				list_of.remove_at(index)
				break


## E pressed by hero `id`: opens the nearest closed chest within reach (a
## Mimik springs instead). Returns true when there was one, so E does nothing else.
func interact(id: int) -> bool:
	var player: Dictionary = game.players.get(id, {})
	if player.is_empty() or int(player.hp) <= 0: return false
	var reach := _value("open_radius", 30) + float(game.balance.player.radius)
	var best: Dictionary = {}
	var best_distance := INF
	for chest: Dictionary in _here():
		if bool(chest.open) or str(chest.get("kind", "chest")) == "crate": continue
		var distance: float = Vector2(player.pos).distance_to(chest.pos)
		if distance <= reach and distance < best_distance:
			best = chest
			best_distance = distance
	if best.is_empty(): return false
	if str(best.kind) == "mimic": _spring(best, id)
	else: _open(best, id)
	return true


## The lid opens and the loot hops out in front of the chest (it stays standing).
func _open(chest: Dictionary, owner: int) -> void:
	chest.open = true
	chest.opened_by = owner
	_drop(_roll_drops(owner, 1), Vector2(chest.pos) + Vector2(0, 34))
	game.add_fx("chest_open", chest.pos, 24.0)
	print("CHEST_OPENED room=%s peer=%d" % [_room_id(), owner])


## A Mimik: the chest becomes an enemy, bites the opener and the room fights again.
func _spring(chest: Dictionary, opener: int) -> void:
	var list: Array = _here()
	list.erase(chest)
	_free_cell(chest)
	var enemy: Dictionary = game._create_enemy("mimic", Vector2(chest.pos))
	enemy.mimic = true
	game.enemies.append(enemy)
	var player: Dictionary = game.players.get(opener, {})
	if not player.is_empty(): game._damage_player(opener, int(_value("mimic_bite", 2)), (Vector2(player.pos) - Vector2(chest.pos)).normalized())
	if game.phase == "explore": game.phase = "combat"
	game.add_fx("mimic_spring", chest.pos, 26.0)
	game.layout_changed()
	print("MIMIC_SPRUNG room=%s peer=%d" % [_room_id(), opener])


## A fallen Mimik drops better loot than a chest: `mimic_drops` perks.
func mimic_defeated(enemy: Dictionary, owner: int) -> void:
	var drops := _roll_drops(owner, int(_value("mimic_drops", 2)))
	for index in range(drops.size()):
		var side := (float(index) - float(drops.size() - 1) * 0.5) * 36.0
		_drop([drops[index]], Vector2(enemy.pos) + Vector2(side, 10))
	print("MIMIC_DEFEATED room=%s drops=%d" % [_room_id(), drops.size()])


func _drop(drops: Array, point: Vector2) -> void:
	var list: Array = loot.get(_room_id(), [])
	for drop: Dictionary in drops:
		drop.id = _next_id
		_next_id += 1
		drop.pos = point
		drop.age = 0.0
		list.append(drop)
	loot[_room_id()] = list


## Rolls `count` different drops for the hero who opened the chest (perks
## their class can use).
func _roll_drops(owner: int, count: int) -> Array:
	var player: Dictionary = game.players.get(owner, {})
	if player.is_empty():
		for candidate: Dictionary in game.players.values():
			player = candidate
			break
	var offer := PerkRules.offer(player, game.balance, _rng, count) if not player.is_empty() else []
	var result: Array = []
	for perk: Dictionary in offer:
		if str(perk.get("stat", "")) == "reserve": continue
		result.append({"kind": "perk", "perk": str(perk.id), "name": str(perk.get("name", ""))})
	return result


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
		visible_chests.append({"kind": "crate" if str(chest.get("kind", "chest")) == "crate" else "chest", "id": int(chest.id), "x": Vector2(chest.pos).x, "y": Vector2(chest.pos).y, "hits": int(chest.hits), "max": int(chest.max), "open": bool(chest.open), "dx": direction.x})
	var visible_loot: Array = []
	for item: Dictionary in loot.get(_room_id(), []):
		visible_loot.append({"id": int(item.id), "x": Vector2(item.pos).x, "y": Vector2(item.pos).y, "kind": str(item.kind), "perk": str(item.get("perk", "")), "name": str(item.get("name", "")), "age": float(item.age)})
	return {"chests": visible_chests, "loot": visible_loot}
