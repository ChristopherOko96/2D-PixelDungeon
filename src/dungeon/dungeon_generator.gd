extends RefCounted
## Seeded floor assembly and host-side geometry, independent of scenes or peers.
## Configuration schema 1 uses pixel world_size/play_bounds/spawns, tile-unit
## obstacles_tiles, and max_actor_radius for clearance. Every layout contains
## plain pixel rectangle arrays and Vector2 spawns, safe for Godot Variant RPCs.
## Geometry is conservative circle-vs-grown-AABB, not Godot physics determinism.

const SCHEMA_VERSION: int = 1
const GENERATOR_VERSION: int = 3
const MIN_ROOMS: int = 5
const MAX_ROOMS: int = 12
const EPSILON: float = 0.00001
# Subpixel separation keeps swept wall contact outside the closed navigation
# obstruction, including after Vector2's single-precision coordinate rounding.
const CONTACT_MARGIN: float = 0.001
# Door order is part of the generator contract: it fixes RNG draws and door keys.
const DIRECTION_NAMES: Array[String] = ["north", "east", "south", "west"]
const DIRECTION_VECTORS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const OPPOSITE: Dictionary = {"north": "south", "east": "west", "south": "north", "west": "east"}
# Doors use the player's collision radius (game.gd moves players with 12 px).
const DOOR_ACTOR_RADIUS: float = 12.0
# Matches the 80 px opening dungeon_view.gd draws, so a player who visibly stands
# in the doorway always goes through (a 64 px trigger missed players at its edge).
const DOOR_HALF_WIDTH: float = 40.0
const DOOR_TRIGGER_MARGIN: float = 4.0
const ENTRY_DEPTH: float = 48.0
const MAX_GRID_EXTENT: int = 4
const MAX_TOPOLOGY_ATTEMPTS: int = 32

## Picks the floor's room count from the run seed, inclusive of both limits.
## Uses its own generator so the count never shifts the layout's RNG stream.
static func room_count_for_seed(seed: int, minimum: int, maximum: int) -> int:
	var low: int = clampi(mini(minimum, maximum), MIN_ROOMS, MAX_ROOMS)
	var high: int = clampi(maxi(minimum, maximum), MIN_ROOMS, MAX_ROOMS)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("room-count:%d" % seed)
	return rng.randi_range(low, high)

## Builds a repeatable branching floor after The Binding of Isaac; invalid data or
## counts return no rooms. Rooms form a loop-free tree on the grid: a cell is only
## added where exactly one occupied neighbour (its parent) touches it, so grid
## adjacency and doors coincide. Room 0 is the start; the boss is the dead end
## farthest from it (breadth-first distance), the treasure room another dead end.
static func generate(seed: int, room_count: int, config: Dictionary) -> Array[Dictionary]:
	var rooms: Array[Dictionary] = []
	if room_count < MIN_ROOMS or room_count > MAX_ROOMS or not validate_config(config).is_empty():
		return rooms
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var cells: Array[Vector2i] = []
	for attempt: int in range(MAX_TOPOLOGY_ATTEMPTS):
		cells = _grow_tree(room_count, rng)
		if cells.size() == room_count and _dead_ends(cells).size() >= 2:
			break
		cells = []
	if cells.is_empty():
		return rooms
	var distances: Array[int] = _distances(cells)
	var leaves: Array[int] = _dead_ends(cells)
	var boss_index: int = leaves[0]
	for leaf: int in leaves:
		if distances[leaf] > distances[boss_index]:
			boss_index = leaf
	leaves.erase(boss_index)
	var treasure_index: int = leaves[rng.randi_range(0, leaves.size() - 1)]
	var normals: Array[Dictionary] = []
	var bosses: Array[Dictionary] = []
	for template: Dictionary in config.templates:
		if template.boss:
			bosses.append(template)
		else:
			normals.append(template)
	_shuffle(normals, rng)
	var normal_turn: int = 0
	var cell_index: Dictionary = {}
	for index: int in range(room_count):
		cell_index[cells[index]] = index
		var kind: String = "normal"
		if index == 0:
			kind = "start"
		elif index == boss_index:
			kind = "boss"
		elif index == treasure_index:
			kind = "treasure"
		var template: Dictionary
		if kind == "boss":
			template = bosses[rng.randi_range(0, bosses.size() - 1)]
		else:
			if normal_turn > 0 and normal_turn % normals.size() == 0:
				var last_template: String = normals[normals.size() - 1].id
				_shuffle(normals, rng)
				if normals[0].id == last_template:
					var swap: Dictionary = normals[0]
					normals[0] = normals[1]
					normals[1] = swap
			template = normals[normal_turn % normals.size()]
			normal_turn += 1
		var layout: Dictionary = _make_layout(template, config)
		layout.id = _room_id(seed, index)
		layout.kind = kind
		layout.boss = kind == "boss"
		layout.grid_x = cells[index].x
		layout.grid_y = cells[index].y
		layout.distance = distances[index]
		rooms.append(layout)
	for index: int in range(room_count):
		var doors: Dictionary = {}
		for side: int in range(DIRECTION_NAMES.size()):
			var neighbour: Vector2i = cells[index] + DIRECTION_VECTORS[side]
			if cell_index.has(neighbour):
				doors[DIRECTION_NAMES[side]] = rooms[cell_index[neighbour]].id
		rooms[index].doors = doors
	return rooms

## Centre of the doorway on one wall of the play bounds, in room pixels.
static func door_center(direction: String, layout: Dictionary) -> Vector2:
	var bounds: Rect2 = _rect(layout.play_bounds)
	match direction:
		"north":
			return Vector2(bounds.get_center().x, bounds.position.y)
		"south":
			return Vector2(bounds.get_center().x, bounds.end.y)
		"west":
			return Vector2(bounds.position.x, bounds.get_center().y)
		"east":
			return Vector2(bounds.end.x, bounds.get_center().y)
	return bounds.get_center()

## True when an actor of `radius` stands in the doorway of `direction`'s wall.
static func at_door(pos: Vector2, direction: String, radius: float, layout: Dictionary) -> bool:
	if not pos.is_finite() or not OPPOSITE.has(direction) or not _geometry_valid(layout):
		return false
	var center: Vector2 = door_center(direction, layout)
	var reach: float = radius + DOOR_TRIGGER_MARGIN
	if direction == "north" or direction == "south":
		return absf(pos.x - center.x) <= DOOR_HALF_WIDTH and absf(pos.y - center.y) <= reach
	return absf(pos.y - center.y) <= DOOR_HALF_WIDTH and absf(pos.x - center.x) <= reach

## Point just inside the doorway where an arriving party gathers.
static func entry_point(direction: String, layout: Dictionary) -> Vector2:
	return door_center(direction, layout) + _inward(direction) * ENTRY_DEPTH

## Four player positions inside the doorway on `direction`'s wall. A point without
## player clearance falls back to the nearest free floor cell, so arrivals never
## start inside cover.
static func entry_spawns(direction: String, layout: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not OPPOSITE.has(direction) or not _geometry_valid(layout):
		return result
	var inward: Vector2 = _inward(direction)
	var across: Vector2 = Vector2(-inward.y, inward.x)
	var base: Vector2 = entry_point(direction, layout)
	for offset: Vector2 in [Vector2(-26, 0), Vector2(26, 0), Vector2(-26, 40), Vector2(26, 40)]:
		var point: Vector2 = base + across * offset.x + inward * offset.y
		if segment_blocked(point, point, DOOR_ACTOR_RADIUS, layout):
			point = _nearest_free_point(point, DOOR_ACTOR_RADIUS, layout)
		result.append(point)
	return result

## Returns actionable validation errors; never repairs malformed configuration.
## All spawn positions and all navigation lattice cells must remain connected at
## max_actor_radius, so the configured largest actor cannot be stranded.
static func validate_config(config: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	for key: String in ["schema_version", "generator_version", "tile_size", "world_size", "play_bounds", "max_actor_radius", "templates"]:
		if not config.has(key):
			errors.append("Missing required dungeon field: %s" % key)
	if not errors.is_empty():
		return errors
	if not _integer(config.schema_version) or int(config.schema_version) != SCHEMA_VERSION:
		errors.append("Unsupported dungeon schema_version")
	if not _integer(config.generator_version) or int(config.generator_version) != GENERATOR_VERSION:
		errors.append("Unsupported dungeon generator_version")
	if not _integer(config.tile_size) or float(config.tile_size) < 8.0:
		errors.append("tile_size must be a positive integer of at least 8 pixels")
	if not _numbers(config.world_size, 2) or not _numbers(config.play_bounds, 4):
		errors.append("world_size/play_bounds must be finite pixel arrays")
	if not _number(config.max_actor_radius) or float(config.max_actor_radius) <= 0.0:
		errors.append("max_actor_radius must be finite and positive")
	if not config.templates is Array or config.templates.is_empty():
		errors.append("templates must be a nonempty array")
	if not errors.is_empty():
		return errors
	var bounds: Rect2 = _rect(config.play_bounds)
	var world: Vector2 = Vector2(float(config.world_size[0]), float(config.world_size[1]))
	var radius: float = float(config.max_actor_radius)
	if world.x <= 0.0 or world.y <= 0.0 or bounds.position.x < 0.0 or bounds.position.y < 0.0 or bounds.end.x > world.x or bounds.end.y > world.y or bounds.size.x <= radius * 2.0 or bounds.size.y <= radius * 2.0:
		errors.append("play_bounds must contain actor clearance and fit within world_size")
		return errors
	var ids: Dictionary = {}
	var normals: int = 0
	var bosses: int = 0
	for entry: Variant in config.templates:
		if not entry is Dictionary:
			errors.append("Each template must be an object")
			continue
		var template: Dictionary = entry
		var label: String = str(template.get("id", "<unnamed>"))
		if not template.get("id") is String or label.is_empty() or ids.has(label):
			errors.append("Template IDs must be nonempty and unique: %s" % label)
		ids[label] = true
		if not template.get("title") is String or str(template.title).is_empty() or not template.get("boss") is bool:
			errors.append("Template %s needs a title and boolean boss flag" % label)
			continue
		if template.boss:
			bosses += 1
		else:
			normals += 1
		if not template.get("obstacles_tiles") is Array:
			errors.append("Template %s needs obstacles_tiles" % label)
			continue
		var geometry_valid: bool = true
		for obstacle: Variant in template.obstacles_tiles:
			if not _numbers(obstacle, 4):
				geometry_valid = false
				break
			for component: Variant in obstacle:
				if not _integer(component):
					geometry_valid = false
			var rect: Rect2 = _rect(obstacle)
			rect.position *= float(config.tile_size)
			rect.size *= float(config.tile_size)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not bounds.encloses(rect):
				geometry_valid = false
		if not geometry_valid:
			errors.append("Template %s obstacles must be positive tile rectangles within play_bounds" % label)
			continue
		# Cutouts shape the room (cross, steps, corridors); they may reach past
		# the play bounds into the walls, but must overlap the floor.
		for cutout: Variant in template.get("cutouts_tiles", []):
			if not _numbers(cutout, 4):
				geometry_valid = false
				continue
			for component: Variant in cutout:
				if not _integer(component):
					geometry_valid = false
			if not geometry_valid:
				continue
			var overlap: Rect2 = _clipped_cutout(cutout, config).intersection(bounds)
			if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
				geometry_valid = false
		if not geometry_valid:
			errors.append("Template %s cutouts must be integer tile rectangles overlapping play_bounds" % label)
			continue
		var points_valid: bool = true
		for key: String in ["player_spawns", "enemy_spawns"]:
			var minimum: int = 4 if key == "player_spawns" else 5
			if not template.get(key) is Array or template.get(key, []).size() < minimum:
				points_valid = false
				continue
			for point: Variant in template[key]:
				if not _numbers(point, 2):
					points_valid = false
		if not points_valid:
			errors.append("Template %s needs four player and five enemy finite pixel spawn pairs" % label)
			continue
		var layout: Dictionary = _make_layout(template, config)
		var points: Array = layout.player_spawns + layout.enemy_spawns
		for point: Vector2 in points:
			if segment_blocked(point, point, radius, layout):
				points_valid = false
		if not points_valid:
			errors.append("Template %s has a spawn without actor clearance" % label)
			continue
		if not _floor_connected(layout, radius):
			errors.append("Template %s has disconnected floor or unreachable spawns" % label)
			continue
		# Every template can sit anywhere on the floor, so all four doorways must be
		# walkable for a player and reachable from the room's own player spawns.
		for direction: String in DIRECTION_NAMES:
			var arrival: Vector2 = entry_point(direction, layout)
			var doorway: Vector2 = door_center(direction, layout) + _inward(direction) * DOOR_ACTOR_RADIUS
			if segment_blocked(arrival, doorway, DOOR_ACTOR_RADIUS, layout) or find_path(arrival, layout.player_spawns[0], DOOR_ACTOR_RADIUS, layout).is_empty():
				errors.append("Template %s blocks the %s doorway" % [label, direction])
		for index: int in range(layout.enemy_spawns.size()):
			var mirrored: Vector2 = spawn_for_enemy(index, layout, "east")
			if segment_blocked(mirrored, mirrored, radius, layout):
				errors.append("Template %s has a mirrored enemy spawn without actor clearance" % label)
				break
	if normals < 3 or bosses < 1:
		errors.append("Dungeon requires at least three normal templates and one boss template")
	return errors

## Moves an actor using swept X then Y clipping against radius-grown rectangles.
## The fixed axis order permits wall sliding and prevents large-step tunneling.
## Starting positions must be valid; malformed movement leaves position unchanged.
static func move_actor(pos: Vector2, delta: Vector2, radius: float, layout: Dictionary) -> Vector2:
	if not pos.is_finite() or not delta.is_finite() or not is_finite(radius) or radius < 0.0 or not _geometry_valid(layout):
		return pos
	var bounds: Rect2 = _rect(layout.play_bounds).grow(-radius)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return pos
	var result: Vector2 = pos.clamp(bounds.position, bounds.end)
	var target: float = clampf(result.x + delta.x, bounds.position.x, bounds.end.x)
	for entry: Array in layout.obstacles:
		var wall: Rect2 = _rect(entry).grow(radius)
		if result.y > wall.position.y + EPSILON and result.y < wall.end.y - EPSILON:
			if delta.x > 0.0 and result.x <= wall.position.x + EPSILON:
				target = minf(target, wall.position.x - CONTACT_MARGIN)
			elif delta.x < 0.0 and result.x >= wall.end.x - EPSILON:
				target = maxf(target, wall.end.x + CONTACT_MARGIN)
	result.x = target
	target = clampf(result.y + delta.y, bounds.position.y, bounds.end.y)
	for entry: Array in layout.obstacles:
		var wall: Rect2 = _rect(entry).grow(radius)
		if result.x > wall.position.x + EPSILON and result.x < wall.end.x - EPSILON:
			if delta.y > 0.0 and result.y <= wall.position.y + EPSILON:
				target = minf(target, wall.position.y - CONTACT_MARGIN)
			elif delta.y < 0.0 and result.y >= wall.end.y - EPSILON:
				target = maxf(target, wall.end.y + CONTACT_MARGIN)
	result.y = target
	return result

## Sweeps a segment against radius-grown walls and physical room boundaries.
## Includes the full segment, so high-speed projectiles cannot cross thin pillars.
## Invalid geometry or non-finite input is treated as blocked.
static func segment_blocked(from: Vector2, to: Vector2, radius: float, layout: Dictionary) -> bool:
	if not from.is_finite() or not to.is_finite() or not is_finite(radius) or radius < 0.0 or not _geometry_valid(layout):
		return true
	var bounds: Rect2 = _rect(layout.play_bounds).grow(-radius)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or not _inside(from, bounds) or not _inside(to, bounds):
		return true
	for entry: Array in layout.obstacles:
		if _segment_intersects_rect(from, to, _rect(entry).grow(radius)):
			return true
	return false

## Returns authored player spawn positions, wrapping nonnegative slot indices.
## Empty or invalid layout spawn data returns Vector2.ZERO.
static func spawn_for_player(index: int, layout: Dictionary) -> Vector2:
	return _spawn(index, layout.get("player_spawns", []))

## Returns authored enemy spawn positions, wrapping nonnegative slot indices.
## Templates place enemies on the east side; a party entering through the east
## door gets them mirrored to the west so nobody spawns in contact range.
## Empty or invalid layout spawn data returns Vector2.ZERO.
static func spawn_for_enemy(index: int, layout: Dictionary, entry_direction: String = "") -> Vector2:
	var point: Vector2 = _spawn(index, layout.get("enemy_spawns", []))
	if entry_direction == "east" and _numbers(layout.get("play_bounds"), 4):
		var bounds: Rect2 = _rect(layout.play_bounds)
		point.x = bounds.position.x + bounds.end.x - point.x
	return point

## Finds collision-free waypoints on a cardinal tile lattice, including `to`.
## Endpoints clamp to this actor's floor clearance so larger enemies can chase a
## smaller player near the floor edge. Clear direct paths return [clamped_to];
## non-finite/inside-wall endpoints and unreachable goals return [].
## Callers may cache routes and consume waypoints; no scene/physics state is used.
static func find_path(from: Vector2, to: Vector2, radius: float, layout: Dictionary) -> PackedVector2Array:
	var result: PackedVector2Array = []
	if not from.is_finite() or not to.is_finite() or not is_finite(radius) or radius < 0.0 or not _geometry_valid(layout):
		return result
	var bounds: Rect2 = _rect(layout.play_bounds).grow(-radius)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return result
	from = from.clamp(bounds.position, bounds.end)
	to = to.clamp(bounds.position, bounds.end)
	if not segment_blocked(from, to, radius, layout):
		result.append(to)
		return result
	if segment_blocked(from, from, radius, layout) or segment_blocked(to, to, radius, layout) or not _integer(layout.get("tile_size")) or int(layout.tile_size) < 8:
		return result
	var tile: float = float(layout.tile_size)
	var cells: Dictionary = _floor_cells(layout, radius)
	var starts: Array[Vector2i] = _nearby_visible_cells(from, radius, layout, cells, tile)
	var goals: Array[Vector2i] = _nearby_visible_cells(to, radius, layout, cells, tile)
	var goal_set: Dictionary = {}
	for cell: Vector2i in goals:
		goal_set[cell] = true
	var parents: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell: Vector2i in starts:
		parents[cell] = cell
		queue.append(cell)
	var cursor: int = 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		if goal_set.has(current):
			var backwards: Array[Vector2] = []
			var step: Vector2i = current
			backwards.append(Vector2(step) * tile)
			while parents[step] != step:
				step = parents[step]
				backwards.append(Vector2(step) * tile)
			backwards.reverse()
			# Collapse straight, visible stretches to keep chasing smooth.
			var anchor: Vector2 = from
			var next_index: int = 0
			while next_index < backwards.size():
				var furthest: int = next_index
				while furthest + 1 < backwards.size() and not segment_blocked(anchor, backwards[furthest + 1], radius, layout):
					furthest += 1
				anchor = backwards[furthest]
				result.append(anchor)
				next_index = furthest + 1
			result.append(to)
			return result
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next: Vector2i = current + direction
			if cells.has(next) and not parents.has(next) and not segment_blocked(Vector2(current) * tile, Vector2(next) * tile, radius, layout):
				parents[next] = current
				queue.append(next)
	return result

static func _room_id(seed: int, index: int) -> String:
	return "v%d-s%d-r%02d" % [GENERATOR_VERSION, seed, index + 1]

static func _grow_tree(count: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var occupied: Dictionary = {Vector2i.ZERO: true}
	var guard: int = 0
	while cells.size() < count and guard < count * 64:
		guard += 1
		var parent: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var candidate: Vector2i = parent + DIRECTION_VECTORS[rng.randi_range(0, DIRECTION_VECTORS.size() - 1)]
		if occupied.has(candidate) or absi(candidate.x) > MAX_GRID_EXTENT or absi(candidate.y) > MAX_GRID_EXTENT:
			continue
		var touching: int = 0
		for direction: Vector2i in DIRECTION_VECTORS:
			if occupied.has(candidate + direction):
				touching += 1
		if touching != 1:
			continue
		occupied[candidate] = true
		cells.append(candidate)
	return cells

static func _neighbour_count(cells: Array[Vector2i], index: int) -> int:
	var count: int = 0
	for direction: Vector2i in DIRECTION_VECTORS:
		if cells.has(cells[index] + direction):
			count += 1
	return count

# Dead ends other than the start room, in room order.
static func _dead_ends(cells: Array[Vector2i]) -> Array[int]:
	var result: Array[int] = []
	for index: int in range(1, cells.size()):
		if _neighbour_count(cells, index) == 1:
			result.append(index)
	return result

static func _distances(cells: Array[Vector2i]) -> Array[int]:
	var result: Array[int] = []
	result.resize(cells.size())
	result.fill(-1)
	result[0] = 0
	var queue: Array[int] = [0]
	var cursor: int = 0
	while cursor < queue.size():
		var current: int = queue[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTION_VECTORS:
			var next: int = cells.find(cells[current] + direction)
			if next >= 0 and result[next] < 0:
				result[next] = result[current] + 1
				queue.append(next)
	return result

static func _inward(direction: String) -> Vector2:
	var side: int = DIRECTION_NAMES.find(direction)
	return -Vector2(DIRECTION_VECTORS[side]) if side >= 0 else Vector2.ZERO

static func _nearest_free_point(point: Vector2, radius: float, layout: Dictionary) -> Vector2:
	var tile: float = float(layout.get("tile_size", 32))
	var best: Vector2 = point
	var best_distance: float = INF
	var cells: Dictionary = _floor_cells(layout, radius)
	for cell: Vector2i in cells:
		var candidate: Vector2 = Vector2(cell) * tile
		var distance: float = candidate.distance_squared_to(point)
		# Ties resolve by coordinate so every peer picks the same cell.
		if distance < best_distance or (distance == best_distance and (candidate.x < best.x or (candidate.x == best.x and candidate.y < best.y))):
			best = candidate
			best_distance = distance
	return best

static func _shuffle(values: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Dictionary = values[index]
		values[index] = values[other]
		values[other] = swap

## A cutout tile rectangle in pixels, clipped to the world so it stays on the
## tile grid (the play bounds' top edge is not); the walls hide the overlap.
static func _clipped_cutout(cutout: Array, config: Dictionary) -> Rect2:
	var tile: float = float(config.tile_size)
	var rect: Rect2 = Rect2(float(cutout[0]) * tile, float(cutout[1]) * tile, float(cutout[2]) * tile, float(cutout[3]) * tile)
	return rect.intersection(Rect2(Vector2.ZERO, Vector2(float(config.world_size[0]), float(config.world_size[1]))))

static func _make_layout(template: Dictionary, config: Dictionary) -> Dictionary:
	var obstacles: Array = []
	for obstacle: Array in template.obstacles_tiles:
		obstacles.append([float(obstacle[0]) * float(config.tile_size), float(obstacle[1]) * float(config.tile_size), float(obstacle[2]) * float(config.tile_size), float(obstacle[3]) * float(config.tile_size)])
	# Cutouts collide like cover; they are listed again so the view can tell them apart.
	var cutouts: Array = []
	for cutout: Array in template.get("cutouts_tiles", []):
		var rect: Rect2 = _clipped_cutout(cutout, config)
		cutouts.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	obstacles.append_array(cutouts)
	var players: Array[Vector2] = []
	var enemies: Array[Vector2] = []
	for point: Array in template.player_spawns:
		players.append(Vector2(float(point[0]), float(point[1])))
	for point: Array in template.enemy_spawns:
		enemies.append(Vector2(float(point[0]), float(point[1])))
	return {"template_id": template.id, "title": template.title, "boss": template.boss,
		"accent_color": template.get("accent_color", "536b72"),
		"generator_version": int(config.generator_version), "tile_size": int(config.tile_size),
		"world_size": config.world_size.duplicate(), "play_bounds": config.play_bounds.duplicate(),
		"obstacles": obstacles, "cutouts": cutouts, "player_spawns": players, "enemy_spawns": enemies}

static func _spawn(index: int, points: Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var point: Variant = points[posmod(index, points.size())]
	return point if point is Vector2 else Vector2.ZERO

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _number(value) and floorf(float(value)) == float(value)

static func _numbers(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size:
		return false
	for component: Variant in value:
		if not _number(component):
			return false
	return true

static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

static func _geometry_valid(layout: Dictionary) -> bool:
	if not _numbers(layout.get("play_bounds"), 4) or not layout.get("obstacles") is Array:
		return false
	for entry: Variant in layout.obstacles:
		if not _numbers(entry, 4) or float(entry[2]) <= 0.0 or float(entry[3]) <= 0.0:
			return false
	return true

static func _inside(point: Vector2, bounds: Rect2) -> bool:
	return point.x >= bounds.position.x and point.y >= bounds.position.y and point.x <= bounds.end.x and point.y <= bounds.end.y

static func _segment_intersects_rect(from: Vector2, to: Vector2, wall: Rect2) -> bool:
	var delta: Vector2 = to - from
	var entry: float = 0.0
	var exit: float = 1.0
	for axis: int in range(2):
		if absf(delta[axis]) <= EPSILON:
			if from[axis] < wall.position[axis] or from[axis] > wall.end[axis]:
				return false
		else:
			var first: float = (wall.position[axis] - from[axis]) / delta[axis]
			var second: float = (wall.end[axis] - from[axis]) / delta[axis]
			entry = maxf(entry, minf(first, second))
			exit = minf(exit, maxf(first, second))
			if entry > exit:
				return false
	return true

static func _floor_cells(layout: Dictionary, radius: float) -> Dictionary:
	var cells: Dictionary = {}
	var bounds: Rect2 = _rect(layout.play_bounds).grow(-radius)
	var tile: float = float(layout.tile_size)
	for y: int in range(int(ceilf(bounds.position.y / tile)), int(floorf(bounds.end.y / tile)) + 1):
		for x: int in range(int(ceilf(bounds.position.x / tile)), int(floorf(bounds.end.x / tile)) + 1):
			var cell: Vector2i = Vector2i(x, y)
			var point: Vector2 = Vector2(cell) * tile
			if not segment_blocked(point, point, radius, layout):
				cells[cell] = true
	return cells

static func _nearby_visible_cells(point: Vector2, radius: float, layout: Dictionary, cells: Dictionary, tile: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin: Vector2i = Vector2i(roundi(point.x / tile), roundi(point.y / tile))
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			var cell: Vector2i = origin + Vector2i(x, y)
			if cells.has(cell) and not segment_blocked(point, Vector2(cell) * tile, radius, layout):
				result.append(cell)
	return result

static func _floor_connected(layout: Dictionary, radius: float) -> bool:
	var cells: Dictionary = _floor_cells(layout, radius)
	if cells.is_empty():
		return false
	var tile: float = float(layout.tile_size)
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [cells.keys()[0]]
	visited[queue[0]] = true
	var cursor: int = 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next: Vector2i = current + direction
			if cells.has(next) and not visited.has(next) and not segment_blocked(Vector2(current) * tile, Vector2(next) * tile, radius, layout):
				visited[next] = true
				queue.append(next)
	if visited.size() != cells.size():
		return false
	for point: Vector2 in layout.player_spawns + layout.enemy_spawns:
		if _nearby_visible_cells(point, radius, layout, cells, tile).is_empty():
			return false
	return true
