extends RefCounted
## Collision, sight and path finding on a floor map's tile grid (see
## floor_map_generator.gd). Bodies are circles tested as their bounding box
## against solid tiles, like the room geometry tested them against rectangles.
## Movement goes in sub-steps of at most STEP pixels, X then Y, so actors
## slide along walls and fast movers cannot tunnel. Functions over the map
## dictionary; the per-radius clearance grid is cached by map seed here, not on
## the map, because the host copies the map into every snapshot.

const FloorMap = preload("res://src/dungeon/floor_map_generator.gd")
## Longest sub-step in pixels; smaller than half a tile.
const STEP: float = 8.0
## Clearance grids: "<seed>:<radius>" -> {Vector2i: true}; only the newest floor is kept.
static var _cache: Dictionary = {}


## Moves a body of `radius` by `delta`, stopping per axis at walls (sliding).
## A blocked start position is left where it is.
static func move_actor(map: Dictionary, pos: Vector2, delta: Vector2, radius: float) -> Vector2:
	if not pos.is_finite() or not delta.is_finite():
		return pos
	var steps: int = maxi(1, ceili(delta.length() / STEP))
	var part: Vector2 = delta / float(steps)
	var result: Vector2 = pos
	for i: int in range(steps):
		var moved_x: Vector2 = Vector2(result.x + part.x, result.y)
		if part.x != 0.0 and FloorMap.clear_at(map, moved_x, radius):
			result = moved_x
		var moved_y: Vector2 = Vector2(result.x, result.y + part.y)
		if part.y != 0.0 and FloorMap.clear_at(map, moved_y, radius):
			result = moved_y
	return result


## True when a body of `radius` cannot travel the straight line `from` -> `to`
## (both ends included). Radius 0 tests the line itself, for shots and sight.
static func segment_blocked(map: Dictionary, from: Vector2, to: Vector2, radius: float) -> bool:
	if not from.is_finite() or not to.is_finite():
		return true
	var steps: int = maxi(1, ceili(from.distance_to(to) / STEP))
	for i: int in range(steps + 1):
		if not FloorMap.clear_at(map, from.lerp(to, float(i) / float(steps)), maxf(radius, 0.5)):
			return true
	return false


## Waypoints from `from` to `to` for a body of `radius` over tile centres,
## ending at `to`. A clear straight line returns [to]; no route returns [].
static func find_path(map: Dictionary, from: Vector2, to: Vector2, radius: float) -> PackedVector2Array:
	var result: PackedVector2Array = []
	if not segment_blocked(map, from, to, radius):
		result.append(to)
		return result
	var size: float = float(map.tile_size)
	var open: Dictionary = _clearance(map, radius)
	var start: Vector2i = _nearest_open(open, from, size)
	var goal: Vector2i = _nearest_open(open, to, size)
	if start == Vector2i(-1, -1) or goal == Vector2i(-1, -1):
		return result
	var parents: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		if current == goal:
			break
		for direction: Vector2i in FloorMap.DIRECTIONS:
			var next: Vector2i = current + direction
			if open.has(next) and not parents.has(next):
				parents[next] = current
				queue.append(next)
	if not parents.has(goal):
		return result
	var backwards: Array[Vector2] = []
	var step: Vector2i = goal
	while true:
		backwards.append((Vector2(step) + Vector2(0.5, 0.5)) * size)
		if parents[step] == step: break
		step = parents[step]
	backwards.reverse()
	# Collapse straight, visible stretches so chasers move smoothly.
	var anchor: Vector2 = from
	var index := 0
	while index < backwards.size():
		var furthest: int = index
		while furthest + 1 < backwards.size() and not segment_blocked(map, anchor, backwards[furthest + 1], radius):
			furthest += 1
		anchor = backwards[furthest]
		result.append(anchor)
		index = furthest + 1
	result.append(to)
	return result


## The open tile centre nearest to `point` for a body of `radius`.
static func nearest_free_point(map: Dictionary, point: Vector2, radius: float) -> Vector2:
	var size: float = float(map.tile_size)
	var tile: Vector2i = _nearest_open(_clearance(map, radius), point, size)
	return (Vector2(tile) + Vector2(0.5, 0.5)) * size if tile != Vector2i(-1, -1) else point


# Tiles whose centre has room for `radius`, cached per floor seed and radius.
static func _clearance(map: Dictionary, radius: float) -> Dictionary:
	var key: String = "%d:%d" % [int(map.seed), roundi(radius)]
	if _cache.has(key):
		return _cache[key]
	if not _cache.is_empty() and not str(_cache.keys()[0]).begins_with("%d:" % int(map.seed)):
		_cache.clear()
	var size: float = float(map.tile_size)
	var open: Dictionary = {}
	for y: int in range(int(map.height)):
		for x: int in range(int(map.width)):
			if FloorMap.walkable(FloorMap.tile_at(map, x, y)) and FloorMap.clear_at(map, (Vector2(x, y) + Vector2(0.5, 0.5)) * size, radius):
				open[Vector2i(x, y)] = true
	_cache[key] = open
	return open


# Nearest open tile within a few tiles of `point`; ties resolve by coordinate.
static func _nearest_open(open: Dictionary, point: Vector2, size: float) -> Vector2i:
	var origin: Vector2i = Vector2i(floori(point.x / size), floori(point.y / size))
	if open.has(origin):
		return origin
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			var tile: Vector2i = origin + Vector2i(dx, dy)
			if not open.has(tile): continue
			var distance: float = point.distance_squared_to((Vector2(tile) + Vector2(0.5, 0.5)) * size)
			if distance < best_distance or (distance == best_distance and (tile.x < best.x or (tile.x == best.x and tile.y < best.y))):
				best = tile
				best_distance = distance
	return best
