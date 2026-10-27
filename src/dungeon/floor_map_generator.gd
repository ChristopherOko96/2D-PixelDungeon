extends RefCounted
## Floor map generator, version 4: one large tile map per floor instead of a
## sequence of single-screen rooms. The map is split into a grid of cells
## (assets/data/dungeon_floormap.json); a seeded spanning tree over the cells
## decides which rooms are joined. Each cell holds one room: an authored
## template from dungeon_rooms.json (cutouts and pillars become solid tiles,
## arenas keep their 28x15 size) or a generated smaller room. Joined rooms get
## doorways in facing walls and a corridor `corridor_width` tiles wide that
## runs only through the free bands between cells, so it never cuts a wall.
## The start room is the tree's root, the boss sits in the leaf farthest from
## it, the treasure room in another leaf. Same data and seed give the same map.
## Pure functions over plain data; no scenes, peers or physics.

const GENERATOR_VERSION: int = 4
## Tile codes in `tiles` (row-major, width x height).
const SOLID: int = 0
const ROOM: int = 1
const CORRIDOR: int = 2
const DOORWAY: int = 3
const DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SIDES: Array[String] = ["north", "east", "south", "west"]
const OPPOSITE: Dictionary = {"north": "south", "east": "west", "south": "north", "west": "east"}
## Authored templates: footprint including walls, in tiles (local floor x 1..26, y 1..13).
const TEMPLATE_FOOTPRINT: Vector2i = Vector2i(28, 15)
const PLAYER_RADIUS: float = 12.0


## Actionable errors for the map parameters; empty when they can be used.
static func validate(map_config: Dictionary, rooms_config: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	for key: String in ["schema_version", "generator_version", "tile_size", "map_tiles", "cell_tiles", "room_count", "corridor_width", "template_chance", "small_room_min", "small_room_max", "small_room_pillars", "max_actor_radius"]:
		if not map_config.has(key):
			errors.append("Missing floor map field: %s" % key)
	if not errors.is_empty():
		return errors
	if int(map_config.generator_version) != GENERATOR_VERSION:
		errors.append("Unsupported floor map generator_version")
	var map_size: Vector2i = _vec(map_config.map_tiles)
	var cell: Vector2i = _vec(map_config.cell_tiles)
	if cell.x < TEMPLATE_FOOTPRINT.x + 4 or cell.y < TEMPLATE_FOOTPRINT.y + 4:
		errors.append("cell_tiles must fit a template room plus a 2 tile margin on every side")
	if map_size.x < cell.x * 2 or map_size.y < cell.y * 2:
		errors.append("map_tiles must hold at least 2 x 2 cells")
	var grid: Vector2i = Vector2i(map_size.x / maxi(cell.x, 1), map_size.y / maxi(cell.y, 1))
	if int(map_config.room_count[0]) < 3 or int(map_config.room_count[1]) < int(map_config.room_count[0]) or int(map_config.room_count[1]) > grid.x * grid.y:
		errors.append("room_count must lie between 3 and the number of cells")
	if int(map_config.corridor_width) != 3:
		errors.append("corridor_width must be 3: the corridor runs in the 4 tile band between cells")
	var smallest: Vector2i = _vec(map_config.small_room_min)
	var largest: Vector2i = _vec(map_config.small_room_max)
	if smallest.x < 5 or smallest.y < 5 or largest.x < smallest.x or largest.y < smallest.y or largest.x + 6 > cell.x or largest.y + 6 > cell.y:
		errors.append("small rooms must be at least 5 x 5 and fit their cell with margins")
	var templates: Array = rooms_config.get("templates", [])
	var normals := 0
	var bosses := 0
	for template: Dictionary in templates:
		if template.get("boss", false): bosses += 1
		else: normals += 1
	if normals < 1 or bosses < 1:
		errors.append("dungeon_rooms.json needs at least one normal and one boss template")
	return errors


## Builds the floor map for `seed`. Returns {} for unusable configuration.
## Result: {generator_version, seed, width, height, tile_size, tiles
## (PackedByteArray of tile codes), rooms (Array of room records), edges
## (Array of [parent, child] room indices)}.
static func generate(seed: int, map_config: Dictionary, rooms_config: Dictionary) -> Dictionary:
	if not validate(map_config, rooms_config).is_empty():
		return {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var map_size: Vector2i = _vec(map_config.map_tiles)
	var cell: Vector2i = _vec(map_config.cell_tiles)
	var grid: Vector2i = Vector2i(map_size.x / cell.x, map_size.y / cell.y)
	var count: int = rng.randi_range(int(map_config.room_count[0]), int(map_config.room_count[1]))
	var tree: Dictionary = _grow_tree(count, grid, rng)
	var cells: Array[Vector2i] = tree.cells
	var edges: Array = tree.edges
	var distances: Array[int] = _distances(cells.size(), edges)
	var leaves: Array[int] = _leaves(cells.size(), edges)
	var boss_index: int = leaves[0]
	for leaf: int in leaves:
		if distances[leaf] > distances[boss_index]:
			boss_index = leaf
	leaves.erase(boss_index)
	var treasure_index: int = leaves[rng.randi_range(0, leaves.size() - 1)] if not leaves.is_empty() else -1
	var normals: Array = []
	var bosses: Array = []
	for template: Dictionary in rooms_config.templates:
		if template.get("boss", false): bosses.append(template)
		else: normals.append(template)
	_shuffle(normals, rng)
	var tiles: PackedByteArray = PackedByteArray()
	tiles.resize(map_size.x * map_size.y)
	tiles.fill(SOLID)
	var map: Dictionary = {"generator_version": GENERATOR_VERSION, "seed": seed, "width": map_size.x, "height": map_size.y,
		"tile_size": int(map_config.tile_size), "tiles": tiles, "rooms": [], "edges": edges}
	var normal_turn := 0
	for index: int in range(cells.size()):
		var kind: String = "normal"
		if index == 0: kind = "start"
		elif index == boss_index: kind = "boss"
		elif index == treasure_index: kind = "treasure"
		var template: Dictionary = {}
		if kind == "boss":
			template = bosses[rng.randi_range(0, bosses.size() - 1)]
		elif kind == "normal" and rng.randf() < float(map_config.template_chance):
			template = normals[normal_turn % normals.size()]
			normal_turn += 1
		var room: Dictionary = _place_room(map, cells[index], cell, template, map_config, rng)
		room.id = "v%d-s%d-r%02d" % [GENERATOR_VERSION, seed, index + 1]
		room.kind = kind
		room.distance = distances[index]
		room.cell = [cells[index].x, cells[index].y]
		room.doors = {}
		map.rooms.append(room)
	for edge: Array in edges:
		_connect(map, int(edge[0]), int(edge[1]), cell, rng)
	return map


## Tile code at tile (x, y); outside the map counts as solid.
static func tile_at(map: Dictionary, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= int(map.width) or y >= int(map.height):
		return SOLID
	return map.tiles[y * int(map.width) + x]


static func walkable(code: int) -> bool:
	return code == ROOM or code == CORRIDOR or code == DOORWAY


## Whether a circle of `radius` at pixel `point` touches only walkable tiles.
static func clear_at(map: Dictionary, point: Vector2, radius: float) -> bool:
	var size: float = float(map.tile_size)
	for y: int in range(floori((point.y - radius) / size), floori((point.y + radius - 0.001) / size) + 1):
		for x: int in range(floori((point.x - radius) / size), floori((point.x + radius - 0.001) / size) + 1):
			if not walkable(tile_at(map, x, y)):
				return false
	return true


## Index of the room whose floor contains pixel `point`, or -1 (corridor or wall).
static func room_at(map: Dictionary, point: Vector2) -> int:
	var size: float = float(map.tile_size)
	var tile: Vector2i = Vector2i(floori(point.x / size), floori(point.y / size))
	for index: int in range(map.rooms.size()):
		var floor_rect: Array = map.rooms[index].floor
		if Rect2i(int(floor_rect[0]), int(floor_rect[1]), int(floor_rect[2]), int(floor_rect[3])).has_point(tile):
			return index
	return -1


## Number of walkable tiles reachable from the start room's first player spawn,
## and the total walkable count; equal when the whole floor is connected.
static func reachable(map: Dictionary) -> Vector2i:
	var size: float = float(map.tile_size)
	var start: Vector2 = map.rooms[0].player_spawns[0]
	var origin: Vector2i = Vector2i(floori(start.x / size), floori(start.y / size))
	var seen: Dictionary = {origin: true}
	var queue: Array[Vector2i] = [origin]
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = current + direction
			if not seen.has(next) and walkable(tile_at(map, next.x, next.y)):
				seen[next] = true
				queue.append(next)
	var total := 0
	for code: int in map.tiles:
		if walkable(code): total += 1
	return Vector2i(queue.size(), total)


# Spanning tree over grid cells: start in a random cell, then repeatedly add a
# free cell next to a random occupied one. Edges are [parent, child] indices.
static func _grow_tree(count: int, grid: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var cells: Array[Vector2i] = [Vector2i(rng.randi_range(0, grid.x - 1), rng.randi_range(0, grid.y - 1))]
	var index_of: Dictionary = {cells[0]: 0}
	var edges: Array = []
	var guard := 0
	while cells.size() < count and guard < count * 200:
		guard += 1
		var parent: int = rng.randi_range(0, cells.size() - 1)
		var candidate: Vector2i = cells[parent] + DIRECTIONS[rng.randi_range(0, 3)]
		if index_of.has(candidate) or candidate.x < 0 or candidate.y < 0 or candidate.x >= grid.x or candidate.y >= grid.y:
			continue
		index_of[candidate] = cells.size()
		edges.append([parent, cells.size()])
		cells.append(candidate)
	return {"cells": cells, "edges": edges}


static func _distances(count: int, edges: Array) -> Array[int]:
	var result: Array[int] = []
	result.resize(count)
	result.fill(-1)
	result[0] = 0
	var changed := true
	while changed:
		changed = false
		for edge: Array in edges:
			var a: int = int(edge[0])
			var b: int = int(edge[1])
			if result[a] >= 0 and result[b] < 0:
				result[b] = result[a] + 1
				changed = true
	return result


# Rooms with exactly one connection, other than the start.
static func _leaves(count: int, edges: Array) -> Array[int]:
	var degree: Array[int] = []
	degree.resize(count)
	degree.fill(0)
	for edge: Array in edges:
		degree[int(edge[0])] += 1
		degree[int(edge[1])] += 1
	var result: Array[int] = []
	for index: int in range(1, count):
		if degree[index] == 1: result.append(index)
	return result


# Carves one room into its cell, always 2 tiles clear of the cell's edges so
# corridors can pass between cells.
static func _place_room(map: Dictionary, cell_pos: Vector2i, cell: Vector2i, template: Dictionary, config: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var footprint: Vector2i = TEMPLATE_FOOTPRINT
	if template.is_empty():
		var smallest: Vector2i = _vec(config.small_room_min)
		var largest: Vector2i = _vec(config.small_room_max)
		footprint = Vector2i(rng.randi_range(smallest.x, largest.x) + 2, rng.randi_range(smallest.y, largest.y) + 2)
	var origin: Vector2i = cell_pos * cell + Vector2i(rng.randi_range(2, cell.x - footprint.x - 2), rng.randi_range(2, cell.y - footprint.y - 2))
	var floor_rect: Rect2i = Rect2i(origin + Vector2i.ONE, footprint - Vector2i(2, 2))
	_fill(map, floor_rect, ROOM)
	var size: float = float(map.tile_size)
	var pixel_origin: Vector2 = Vector2(origin) * size
	var room: Dictionary = {"rect": [origin.x, origin.y, footprint.x, footprint.y], "floor": [floor_rect.position.x, floor_rect.position.y, floor_rect.size.x, floor_rect.size.y],
		"template_id": str(template.get("id", "")), "title": str(template.get("title", "")), "accent_color": str(template.get("accent_color", "536b72")),
		"player_spawns": [], "enemy_spawns": [], "solid": []}
	if not template.is_empty():
		# Cutouts and pillars become solid tiles inside the floor.
		for rect: Array in template.get("cutouts_tiles", []) + template.get("obstacles_tiles", []):
			var solid: Rect2i = Rect2i(origin.x + int(rect[0]), origin.y + int(rect[1]), int(rect[2]), int(rect[3])).intersection(floor_rect)
			if solid.size.x > 0 and solid.size.y > 0:
				_fill(map, solid, SOLID)
				room.solid.append([solid.position.x, solid.position.y, solid.size.x, solid.size.y])
		for point: Array in template.player_spawns:
			room.player_spawns.append(pixel_origin + Vector2(float(point[0]), float(point[1])))
		for point: Array in template.enemy_spawns:
			room.enemy_spawns.append(pixel_origin + Vector2(float(point[0]), float(point[1])))
		return room
	# Generated room: a few single pillars away from the doors and the middle.
	var centre: Vector2i = floor_rect.position + floor_rect.size / 2
	for i: int in range(rng.randi_range(0, int(config.small_room_pillars))):
		var spot: Vector2i = Vector2i(rng.randi_range(floor_rect.position.x + 2, floor_rect.end.x - 3), rng.randi_range(floor_rect.position.y + 2, floor_rect.end.y - 3))
		if absi(spot.x - centre.x) <= 2 or absi(spot.y - centre.y) <= 2:
			continue
		_fill(map, Rect2i(spot, Vector2i.ONE), SOLID)
		room.solid.append([spot.x, spot.y, 1, 1])
	# Spawns: players gather left of the middle, enemies spread over the right half.
	var radius: float = float(config.max_actor_radius)
	var free: Array[Vector2] = []
	for y: int in range(floor_rect.position.y, floor_rect.end.y):
		for x: int in range(floor_rect.position.x, floor_rect.end.x):
			var point: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * size
			if clear_at(map, point, radius): free.append(point)
	var middle: Vector2 = (Vector2(centre) + Vector2(0.5, 0.5)) * size
	free.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(middle) < b.distance_squared_to(middle) or (a.distance_squared_to(middle) == b.distance_squared_to(middle) and (a.x < b.x or (a.x == b.x and a.y < b.y))))
	for point: Vector2 in free:
		if room.player_spawns.size() < 4 and point.x <= middle.x: room.player_spawns.append(point)
	var right: Array = free.filter(func(point: Vector2) -> bool: return point.x > middle.x + size)
	for i: int in range(5):
		if right.is_empty(): break
		room.enemy_spawns.append(right.pop_at(rng.randi_range(0, right.size() - 1)))
	return room


# Joins rooms a and b (neighbouring cells): doorways in their facing walls and
# an L or Z shaped corridor through the free band on the cell border.
static func _connect(map: Dictionary, a: int, b: int, cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var room_a: Dictionary = map.rooms[a]
	var room_b: Dictionary = map.rooms[b]
	var step: Vector2i = Vector2i(int(room_b.cell[0]) - int(room_a.cell[0]), int(room_b.cell[1]) - int(room_a.cell[1]))
	var side_a: String = SIDES[DIRECTIONS.find(step)]
	var side_b: String = OPPOSITE[side_a]
	var door_a: Vector2i = _door_tile(room_a, side_a)
	var door_b: Vector2i = _door_tile(room_b, side_b)
	var horizontal: bool = step.y == 0
	# The band between the two cells; the corridor turns inside it.
	var border: int = (maxi(int(room_a.cell[0]), int(room_b.cell[0])) * cell.x) if horizontal else (maxi(int(room_a.cell[1]), int(room_b.cell[1])) * cell.y)
	var turn: int = border - 1 + rng.randi_range(0, 1)
	var points: Array[Vector2i] = []
	if horizontal:
		points = [door_a + step, Vector2i(turn, door_a.y), Vector2i(turn, door_b.y), door_b - step]
	else:
		points = [door_a + step, Vector2i(door_a.x, turn), Vector2i(door_b.x, turn), door_b - step]
	for i: int in range(points.size() - 1):
		_carve_line(map, points[i], points[i + 1])
	for tile: Vector2i in [door_a, door_b]:
		var across: Vector2i = Vector2i(0, 1) if horizontal else Vector2i(1, 0)
		for k: int in range(-1, 2):
			var spot: Vector2i = tile + across * k
			map.tiles[spot.y * int(map.width) + spot.x] = DOORWAY
	var size: float = float(map.tile_size)
	room_a.doors[side_a] = {"to": room_b.id, "tile": [door_a.x, door_a.y], "center": (Vector2(door_a) + Vector2(0.5, 0.5)) * size}
	room_b.doors[side_b] = {"to": room_a.id, "tile": [door_b.x, door_b.y], "center": (Vector2(door_b) + Vector2(0.5, 0.5)) * size}


# Middle tile of a room's wall on `side`; the doorway is it and its two neighbours.
static func _door_tile(room: Dictionary, side: String) -> Vector2i:
	var rect: Array = room.rect
	var floor_rect: Array = room.floor
	var middle: Vector2i = Vector2i(int(floor_rect[0]) + int(floor_rect[2]) / 2, int(floor_rect[1]) + int(floor_rect[3]) / 2)
	if not str(room.template_id).is_empty():
		# Templates keep their authored doorway: column 14 and row 7 of the room.
		middle = Vector2i(int(rect[0]) + 14, int(rect[1]) + 7)
	match side:
		"north": return Vector2i(middle.x, int(rect[1]))
		"south": return Vector2i(middle.x, int(rect[1]) + int(rect[3]) - 1)
		"west": return Vector2i(int(rect[0]), middle.y)
	return Vector2i(int(rect[0]) + int(rect[2]) - 1, middle.y)


# A 3 tile wide straight corridor between two tiles on one row or column.
static func _carve_line(map: Dictionary, from: Vector2i, to: Vector2i) -> void:
	var step: Vector2i = Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var at: Vector2i = from
	while true:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var x: int = at.x + dx
				var y: int = at.y + dy
				if x >= 0 and y >= 0 and x < int(map.width) and y < int(map.height) and map.tiles[y * int(map.width) + x] == SOLID:
					map.tiles[y * int(map.width) + x] = CORRIDOR
		if at == to: break
		at += step


static func _fill(map: Dictionary, rect: Rect2i, code: int) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			map.tiles[y * int(map.width) + x] = code


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Variant = values[index]
		values[index] = values[other]
		values[other] = swap


static func _vec(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))
