extends RefCounted
## Open endless floors: one seeded map per floor instead of a chain of rooms.
## Rooms sit on a grid of cells (one room per used cell, the used cells always
## touch), neighbouring rooms are joined by corridors, and a few extra joins
## make loops. The result is an ordinary crypt template with a `crypt_recipe`,
## so CryptGenerator builds the floor and walls and the 0x72 crypt renderer
## draws it like every authored room. The start room is a corner of the walk,
## the boss room the room farthest from it; the stairs down wait there.
## Pure data in, data out (assets/data/dungeon_open_floor.json); no game state.

const DATA_PATH := "res://assets/data/dungeon_open_floor.json"
const TILE := 32
const NEIGHBOURS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


## Loads the tuning file; an unreadable file yields {} and no open floors.
static func load_data() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## Builds the template of floor `floor_index`. Equal seed and data give an
## equal template. `rooms` lists every room as [x, y, w, h] in tiles; index
## `start_room` holds the party, `boss_room` the floor's final group.
static func make_template(seed_value: int, floor_index: int, data: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := Vector2i(int(data.map_tiles[0]), int(data.map_tiles[1]))
	var grid := Vector2i(int(data.grid[0]), int(data.grid[1]))
	var cell := Vector2i(map.x / grid.x, map.y / grid.y)
	var wanted: int = rng.randi_range(int(data.room_count[0]), mini(int(data.room_count[1]), grid.x * grid.y))
	var cells := _grow_cells(grid, wanted, rng)
	var rooms: Array[Rect2i] = []
	for grid_cell: Vector2i in cells: rooms.append(_room_in(grid_cell, cell, data, rng))
	var links := _links(cells, float(data.get("extra_links", 0.0)), rng)
	var start := 0
	var boss := _farthest(start, cells.size(), links, rooms)
	var template := {
		"id": "open_%d" % floor_index, "title": "ENDLOS · EBENE %d" % floor_index, "boss": true,
		"layout_mode": "freeform", "crypt_profile": true, "open_floor": true,
		"world_size": [map.x * TILE, map.y * TILE], "play_bounds": [0, 0, map.x * TILE, map.y * TILE],
		"theme": str(data.themes[posmod(floor_index - 1, data.themes.size())]), "room_theme": "entrance",
		"decoration_enabled": false, "obstacles_tiles": [], "authored_doors": [],
		"stairs_art": {"tile": "violet_000", "rotation": 0},
		"encounter": {"open": true, "spawn_min_distance": 288.0},
		"crypt_recipe": {"chambers": rooms.map(func(r: Rect2i) -> Array: return [r.position.x, r.position.y, r.size.x, r.size.y]), "links": links},
		"rooms": rooms.map(func(r: Rect2i) -> Array: return [r.position.x, r.position.y, r.size.x, r.size.y]),
		"start_room": start, "boss_room": boss,
	}
	template.player_spawns = _around(_centre(rooms[start]), 4, 64.0)
	var stairs := Vector2((rooms[boss].end.x - 2) * TILE + TILE * 0.5, _centre(rooms[boss]).y)
	template.stairs_spawn = [stairs.x, stairs.y]
	template.reward_spawn = [_centre(rooms[boss]).x, _centre(rooms[boss]).y]
	template.boss_spawns = _around(_centre(rooms[boss]) - Vector2(TILE * 2, 0), 5, 72.0)
	var enemy_spawns: Array = []
	var chest_spawns: Array = []
	for index in range(rooms.size()):
		if index == start or index == boss: continue
		var group: int = rng.randi_range(int(data.enemy_group[0]), int(data.enemy_group[1]))
		enemy_spawns.append_array(_scatter(rooms[index], group, float(data.get("enemy_spacing", 56)), rng))
		# Chest spots against the north wall of the room, away from its corners.
		for x in range(rooms[index].position.x + 2, rooms[index].end.x - 2, 3): chest_spawns.append([x, rooms[index].position.y])
	template.enemy_spawns = enemy_spawns
	template.chest_spawns = chest_spawns
	template.chest_range = data.get("chests_per_floor", [4, 6]).duplicate()
	var crates: Array = data.get("crates_per_room", [1, 3])
	template.crate_range = [int(crates[0]) * rooms.size(), int(crates[1]) * rooms.size()]
	return template


## A connected set of `wanted` grid cells, grown from a random cell by adding a
## random free neighbour of the set each step. The first cell is the start.
static func _grow_cells(grid: Vector2i, wanted: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [Vector2i(rng.randi_range(0, grid.x - 1), rng.randi_range(0, grid.y - 1))]
	while cells.size() < wanted:
		var frontier: Array[Vector2i] = []
		for used: Vector2i in cells:
			for step: Vector2i in NEIGHBOURS:
				var next := used + step
				if next.x >= 0 and next.y >= 0 and next.x < grid.x and next.y < grid.y and not cells.has(next) and not frontier.has(next): frontier.append(next)
		if frontier.is_empty(): break
		cells.append(frontier[rng.randi_range(0, frontier.size() - 1)])
	return cells


## A room inside its grid cell, keeping `room_margin` tiles to the cell edge so
## walls and corridors of neighbours never merge rooms by accident.
static func _room_in(grid_cell: Vector2i, cell: Vector2i, data: Dictionary, rng: RandomNumberGenerator) -> Rect2i:
	var margin: int = int(data.get("room_margin", 3))
	var smallest := Vector2i(int(data.room_tiles_min[0]), int(data.room_tiles_min[1]))
	var largest := cell - Vector2i.ONE * margin * 2
	var size := Vector2i(rng.randi_range(smallest.x, maxi(smallest.x, largest.x)), rng.randi_range(smallest.y, maxi(smallest.y, largest.y)))
	var origin := grid_cell * cell + Vector2i.ONE * margin
	var slack := largest - size
	return Rect2i(origin + Vector2i(rng.randi_range(0, maxi(0, slack.x)), rng.randi_range(0, maxi(0, slack.y))), size)


## Corridors as [room, room] index pairs: a random spanning tree over grid
## neighbours, then each remaining neighbour pair with chance `extra`.
static func _links(cells: Array[Vector2i], extra: float, rng: RandomNumberGenerator) -> Array:
	var links: Array = []
	var joined := {0: true}
	var open: Array[int] = [0]
	while not open.is_empty():
		var current: int = open.pop_at(rng.randi_range(0, open.size() - 1))
		var steps: Array = NEIGHBOURS.duplicate()
		for index in range(steps.size() - 1, 0, -1):
			var swap := rng.randi_range(0, index)
			var held: Variant = steps[index]
			steps[index] = steps[swap]
			steps[swap] = held
		for step: Vector2i in steps:
			var other := cells.find(cells[current] + step)
			if other < 0 or joined.has(other): continue
			joined[other] = true
			links.append([current, other])
			open.append(other)
	for a in range(cells.size()):
		for b in range(a + 1, cells.size()):
			if (cells[a] - cells[b]).length_squared() != 1: continue
			if links.has([a, b]) or links.has([b, a]): continue
			if rng.randf() < extra: links.append([a, b])
	return links


## The room with the most corridor steps from `start`; ties go to the larger room.
static func _farthest(start: int, count: int, links: Array, rooms: Array[Rect2i]) -> int:
	var depth := {start: 0}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for link: Array in links:
			var other: int = int(link[1]) if int(link[0]) == current else int(link[0]) if int(link[1]) == current else -1
			if other < 0 or depth.has(other): continue
			depth[other] = int(depth[current]) + 1
			queue.append(other)
	var best := start
	for index in range(count):
		if not depth.has(index) or index == start: continue
		if int(depth[index]) > int(depth.get(best, -1)) or (int(depth[index]) == int(depth[best]) and rooms[index].get_area() > rooms[best].get_area()): best = index
	return best


static func _centre(room: Rect2i) -> Vector2:
	return (Vector2(room.position) + Vector2(room.size) * 0.5).floor() * TILE + Vector2.ONE * TILE * 0.5


## `count` points in a small ring around `centre` (world px, as [x, y]).
static func _around(centre: Vector2, count: int, spread: float) -> Array:
	var points: Array = [[centre.x, centre.y]]
	for index in range(1, count):
		var offset := Vector2.RIGHT.rotated(TAU * float(index - 1) / float(maxi(1, count - 1))) * spread
		points.append([roundf(centre.x + offset.x), roundf(centre.y + offset.y)])
	return points


## Up to `count` cell centres inside `room` (one tile in from its walls), at
## least `spacing` px apart, as [x, y] world px.
static func _scatter(room: Rect2i, count: int, spacing: float, rng: RandomNumberGenerator) -> Array:
	var spots: Array[Vector2] = []
	for y in range(room.position.y + 1, room.end.y - 1):
		for x in range(room.position.x + 1, room.end.x - 1): spots.append(Vector2(x, y) * TILE + Vector2.ONE * TILE * 0.5)
	for index in range(spots.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held := spots[index]
		spots[index] = spots[swap]
		spots[swap] = held
	var picked: Array = []
	for spot: Vector2 in spots:
		if picked.all(func(other: Array) -> bool: return spot.distance_to(Vector2(other[0], other[1])) >= spacing): picked.append([spot.x, spot.y])
		if picked.size() >= count: break
	return picked
