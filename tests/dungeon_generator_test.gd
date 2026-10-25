extends SceneTree
## Headless deterministic generator and collision tests, without network peers.

var _failures: Array[String] = []
var _checked: int = 0
var _generator: Script

func _initialize() -> void:
	if not ResourceLoader.exists("res://src/dungeon/dungeon_generator.gd"):
		_check(false, "dungeon generator implementation exists")
		_finish()
		return
	_generator = load("res://src/dungeon/dungeon_generator.gd")
	if _generator == null:
		_check(false, "dungeon generator script loads")
		_finish()
		return
	_test_invalid_config_rejected()
	_test_seed_stability_and_topology()
	_test_spawns_and_connected_floor()
	_test_swept_shots_and_actor_sliding()
	_test_obstacle_paths()
	_test_doors()
	_test_authored_config()
	_finish()

func _check(condition: bool, description: String) -> void:
	_checked += 1
	if not condition:
		_failures.append(description)
		printerr("DUNGEON_FAIL: ", description)

func _finish() -> void:
	print("DUNGEON_GENERATOR checked=%d failures=%d" % [_checked, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _fixture_config() -> Dictionary:
	var templates: Array = []
	for index: int in range(4):
		templates.append({
			"id": "fixture_%d" % index, "title": "Fixture %d" % index,
			"boss": index == 3,
			"obstacles_tiles": [[11 + index, 4, 1, 2], [14 - index, 10, 2, 1]],
			"player_spawns": [[150, 210], [202, 260], [254, 210], [306, 260]],
			"enemy_spawns": [[640, 120], [736, 176], [800, 240], [672, 304], [768, 384]]
		})
	return {"schema_version": 1, "generator_version": 2, "tile_size": 32,
		"world_size": [896, 480], "play_bounds": [32, 48, 832, 400],
		"max_actor_radius": 24, "templates": templates}

func _test_invalid_config_rejected() -> void:
	var valid: Dictionary = _fixture_config()
	_check(_generator.validate_config(valid).is_empty(), "fixture config is valid")
	_check(not _generator.validate_config({}).is_empty(), "missing config fails closed")
	_check(_generator.generate(1, 3, {}).is_empty(), "invalid config produces no dungeon")
	for key: String in ["schema_version", "generator_version", "tile_size", "world_size", "play_bounds", "max_actor_radius", "templates"]:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(key)
		_check(not _generator.validate_config(missing).is_empty(), "missing %s is rejected" % key)
	for value: Variant in [0, -1, NAN, "32"]:
		var broken: Dictionary = valid.duplicate(true)
		broken.tile_size = value
		_check(not _generator.validate_config(broken).is_empty(), "invalid tile size %s is rejected" % str(value))
	var duplicate: Dictionary = valid.duplicate(true)
	duplicate.templates[1].id = duplicate.templates[0].id
	_check(not _generator.validate_config(duplicate).is_empty(), "duplicate template IDs are rejected")
	var blocked: Dictionary = valid.duplicate(true)
	blocked.templates[0].obstacles_tiles = [[1, 1, 26, 13]]
	_check(not _generator.validate_config(blocked).is_empty(), "blocked or outside floor spawns are rejected")
	var disconnected: Dictionary = valid.duplicate(true)
	disconnected.templates[0].obstacles_tiles = [[12, 2, 2, 12]]
	_check(not _generator.validate_config(disconnected).is_empty(), "a wall severing floor connectivity is rejected")
	var unsupported: Dictionary = valid.duplicate(true)
	unsupported.generator_version = 3
	_check(_generator.generate(1, 6, unsupported).is_empty(), "unsupported generator version fails closed")
	for count: int in [0, 4, 13]:
		_check(_generator.generate(1, count, valid).is_empty(), "unsupported room count %d fails closed" % count)

func _test_seed_stability_and_topology() -> void:
	var config: Dictionary = _fixture_config()
	var before: String = var_to_str(config)
	var first: Array[Dictionary] = _generator.generate(7241, 8, config)
	_check(first.size() == 8, "fixed room count is respected")
	_check(first == _generator.generate(7241, 8, config), "same seed produces exactly the same layout")
	_check(before == var_to_str(config), "generation does not mutate config")
	var template_orders: Dictionary = {}
	var shapes: Dictionary = {}
	var counts: Dictionary = {}
	for seed_value: int in range(48):
		var count: int = _generator.room_count_for_seed(seed_value, 6, 10)
		_check(count >= 6 and count <= 10, "seeded room count stays within 6-10")
		_check(count == _generator.room_count_for_seed(seed_value, 6, 10), "seeded room count is stable")
		counts[count] = true
		var floor_layout: Array[Dictionary] = _generator.generate(seed_value, count, config)
		_check(floor_layout.size() == count, "requested room count is respected")
		if floor_layout.size() != count:
			continue
		var by_cell: Dictionary = {}
		var by_id: Dictionary = {}
		var kinds: Dictionary = {}
		var order: Array[String] = []
		for room: Dictionary in floor_layout:
			var cell: Vector2i = Vector2i(room.grid_x, room.grid_y)
			_check(not by_id.has(room.id), "room IDs are unique within a floor")
			_check(not by_cell.has(cell), "floor grid never revisits coordinates")
			by_id[room.id] = room
			by_cell[cell] = room
			kinds[room.kind] = int(kinds.get(room.kind, 0)) + 1
			_check(int(room.generator_version) == 2, "room records generator version")
			_check(room.boss == (room.kind == "boss"), "boss flag matches the room kind")
			order.append(room.template_id)
		_check(floor_layout[0].kind == "start" and kinds.get("start", 0) == 1, "the first room is the only start room")
		_check(kinds.get("boss", 0) == 1 and kinds.get("treasure", 0) == 1, "each floor has exactly one boss and one treasure room")
		var edges: int = 0
		for room: Dictionary in floor_layout:
			var cell: Vector2i = Vector2i(room.grid_x, room.grid_y)
			for side: int in range(4):
				var name: String = _generator.DIRECTION_NAMES[side]
				var neighbour: Variant = by_cell.get(cell + _generator.DIRECTION_VECTORS[side])
				if neighbour == null:
					_check(not room.doors.has(name), "no door leads into an empty grid cell")
					continue
				edges += 1
				_check(room.doors.get(name, "") == neighbour.id, "every grid neighbour is joined by a door")
				_check(neighbour.doors.get(_generator.OPPOSITE[name], "") == room.id, "doors are symmetric")
		_check(edges / 2 == count - 1, "the floor is a loop-free tree")
		var distance: Dictionary = {floor_layout[0].id: 0}
		var queue: Array = [floor_layout[0].id]
		var cursor: int = 0
		while cursor < queue.size():
			var current: Dictionary = by_id[queue[cursor]]
			cursor += 1
			for next_id: Variant in current.doors.values():
				if not distance.has(next_id):
					distance[next_id] = distance[current.id] + 1
					queue.append(next_id)
		_check(distance.size() == count, "every room is reachable from the start")
		var farthest_dead_end: int = -1
		for room: Dictionary in floor_layout:
			_check(int(room.distance) == int(distance.get(room.id, -1)), "recorded distance matches breadth-first distance")
			if room.kind != "start" and room.doors.size() == 1:
				farthest_dead_end = maxi(farthest_dead_end, int(room.distance))
		for room: Dictionary in floor_layout:
			if room.kind == "boss":
				_check(room.doors.size() == 1 and int(room.distance) == farthest_dead_end, "the boss is the dead end farthest from the start")
			elif room.kind == "treasure":
				_check(room.doors.size() == 1, "the treasure room is a dead end")
		template_orders[str(order)] = true
		var shape: Array = []
		for room: Dictionary in floor_layout:
			shape.append(Vector2i(room.grid_x, room.grid_y))
		shapes[str(shape)] = true
	_check(template_orders.size() > 3, "different seeds vary authored template order")
	_check(shapes.size() > 20, "different seeds produce different floor shapes")
	_check(counts.size() == 5, "seeds cover every room count from 6 to 10")
	var another: Array[Dictionary] = _generator.generate(7242, 8, config)
	_check(first[0].id != another[0].id, "different seeds produce different stable room IDs")

func _test_doors() -> void:
	var config: Dictionary = _fixture_config()
	for template: Dictionary in config.templates:
		var layout: Dictionary = _generator._make_layout(template, config)
		for name: String in _generator.DIRECTION_NAMES:
			var arrivals: Array[Vector2] = _generator.entry_spawns(name, layout)
			_check(arrivals.size() == 4, "a doorway offers four arrival points")
			for point: Vector2 in arrivals:
				_check(not _generator.segment_blocked(point, point, 12.0, layout), "arrival points clear the player")
				for other: String in _generator.DIRECTION_NAMES:
					_check(not _generator.at_door(point, other, 12.0, layout), "arriving players never stand in a doorway")
			var inward: Vector2 = -Vector2(_generator.DIRECTION_VECTORS[_generator.DIRECTION_NAMES.find(name)])
			var doorway: Vector2 = _generator.door_center(name, layout) + inward * 12.0
			_check(_generator.at_door(doorway, name, 12.0, layout), "a player against the wall at the door is in the doorway")
			_check(not _generator.at_door(doorway + Vector2(inward.y, inward.x) * 48.0, name, 12.0, layout), "the doorway is narrower than the wall")
		var mirrored: Vector2 = _generator.spawn_for_enemy(0, layout, "east")
		var plain: Vector2 = _generator.spawn_for_enemy(0, layout)
		_check(is_equal_approx(mirrored.x, 896.0 - plain.x) and mirrored.y == plain.y, "east arrivals mirror enemy spawns away from the door")
	_check(not _generator.at_door(Vector2(448, 248), "north", 12.0, _generator._make_layout(config.templates[0], config)), "the room centre is not a doorway")

func _test_spawns_and_connected_floor() -> void:
	var config: Dictionary = _fixture_config()
	for seed_value: int in range(32):
		var floor_layout: Array[Dictionary] = _generator.generate(seed_value, 6, config)
		for room: Dictionary in floor_layout:
			var spawn_points: Array = room.player_spawns + room.enemy_spawns
			for point: Vector2 in spawn_points:
				_check(not _generator.segment_blocked(point, point, 24.0, room), "all authored spawns clear the largest actor")
			_check(_all_floor_cells_connected(room, 24.0), "radius-24 floor remains connected across many seeds")
			_check(_generator.spawn_for_player(0, room) == room.player_spawns[0], "player spawn helper returns authored position")
			_check(_generator.spawn_for_enemy(4, room) == room.enemy_spawns[4], "enemy spawn helper returns authored position")
			_check(_generator.spawn_for_player(999, room) == room.player_spawns[999 % room.player_spawns.size()], "spawn helper wraps deterministic index")

func _all_floor_cells_connected(room: Dictionary, radius: float) -> bool:
	# Independent BFS builds the traversable floor on a 16px lattice and sweeps
	# every connecting edge. It detects isolated pockets as well as blocked spawns.
	var cells: Dictionary = {}
	for y: int in range(80, 417, 16):
		for x: int in range(64, 833, 16):
			var point: Vector2 = Vector2(x, y)
			if not _generator.segment_blocked(point, point, radius, room):
				cells[Vector2i(x, y)] = true
	if cells.is_empty():
		return false
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [cells.keys()[0]]
	visited[queue[0]] = true
	var cursor: int = 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i(16, 0), Vector2i(-16, 0), Vector2i(0, 16), Vector2i(0, -16)]:
			var next: Vector2i = cell + direction
			if cells.has(next) and not visited.has(next) and not _generator.segment_blocked(Vector2(cell), Vector2(next), radius, room):
				visited[next] = true
				queue.append(next)
	return visited.size() == cells.size()

func _test_swept_shots_and_actor_sliding() -> void:
	var room: Dictionary = {"play_bounds": [32, 48, 832, 400], "obstacles": [[384, 128, 32, 192]]}
	_check(_generator.segment_blocked(Vector2(340, 200), Vector2(480, 200), 5.0, room), "fast bullet sweep hits a thin wall")
	_check(_generator.segment_blocked(Vector2(384, 100), Vector2(384, 350), 5.0, room), "parallel grazing sweep hits expanded wall")
	_check(not _generator.segment_blocked(Vector2(100, 350), Vector2(800, 350), 5.0, room), "sweep through open lane stays clear")
	_check(_generator.segment_blocked(Vector2(100, 100), Vector2(-10, 100), 5.0, room), "sweep leaving physical bounds is blocked")
	_check(_generator.segment_blocked(Vector2(NAN, 0), Vector2.ZERO, 5.0, room), "non-finite sweep fails closed")
	var hit: Vector2 = _generator.move_actor(Vector2(340, 200), Vector2(150, 0), 12.0, room)
	_check(is_equal_approx(hit.x, 372.0) and is_equal_approx(hit.y, 200.0), "large actor step stops at expanded wall without tunneling")
	var slide: Vector2 = _generator.move_actor(Vector2(340, 200), Vector2(100, 60), 12.0, room)
	_check(is_equal_approx(slide.x, 372.0) and is_equal_approx(slide.y, 260.0), "diagonal actor movement slides along wall")
	var boundary: Vector2 = _generator.move_actor(Vector2(100, 100), Vector2(-1000, -1000), 24.0, room)
	_check(boundary == Vector2(56, 72), "actor radius stays within physical floor bounds")
	_check(_generator.move_actor(Vector2(100, 100), Vector2(NAN, 0), 12.0, room) == Vector2(100, 100), "invalid movement does not corrupt actor position")
	_check(not _generator.segment_blocked(hit, hit, 12.0, room), "an actor stopped by a wall remains a valid navigation endpoint")
	var route_after_contact: PackedVector2Array = _generator.find_path(hit, Vector2(500, 200), 12.0, room.merged({"tile_size": 32}))
	_check(not route_after_contact.is_empty(), "a chasing actor can route around a wall after touching it")

func _test_obstacle_paths() -> void:
	var wall_room: Dictionary = {"tile_size": 32, "play_bounds": [32, 48, 832, 400], "obstacles": [[384, 128, 32, 192]]}
	var route: PackedVector2Array = _generator.find_path(Vector2(340, 200), Vector2(500, 200), 24.0, wall_room)
	_check(route.size() >= 2, "blocked direct chase gets waypoints around a pillar")
	var previous: Vector2 = Vector2(340, 200)
	for waypoint: Vector2 in route:
		_check(not _generator.segment_blocked(previous, waypoint, 24.0, wall_room), "every routed segment clears boss radius")
		previous = waypoint
	_check(previous == Vector2(500, 200), "route reaches exact requested endpoint")
	var direct: PackedVector2Array = _generator.find_path(Vector2(100, 380), Vector2(800, 380), 13.0, wall_room)
	_check(direct == PackedVector2Array([Vector2(800, 380)]), "clear chase returns only the target")
	var sealed: Dictionary = {"tile_size": 32, "play_bounds": [32, 48, 832, 400], "obstacles": [[384, 48, 32, 400]]}
	_check(_generator.find_path(Vector2(100, 200), Vector2(800, 200), 13.0, sealed).is_empty(), "unreachable target returns no route")
	_check(_generator.find_path(Vector2(400, 200), Vector2(800, 200), 13.0, wall_room).is_empty(), "inside-wall endpoint returns no route")
	_check(_generator.find_path(Vector2(NAN, 200), Vector2(800, 200), 13.0, wall_room).is_empty(), "non-finite route endpoint fails closed")
	var edge_target: PackedVector2Array = _generator.find_path(Vector2(100, 380), Vector2(44, 436), 24.0, wall_room)
	_check(not edge_target.is_empty() and edge_target[edge_target.size() - 1] == Vector2(56, 424), "boss route adapts a smaller player's edge target to boss clearance")

func _test_authored_config() -> void:
	var file: FileAccess = FileAccess.open("res://assets/data/dungeon_rooms.json", FileAccess.READ)
	_check(file != null, "authored room config exists")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary, "authored room config is valid JSON object")
	if not parsed is Dictionary:
		return
	var config: Dictionary = parsed
	_check(_generator.validate_config(config).is_empty(), "authored room config passes schema, spawn and connectivity validation")
	var normals: int = 0
	var bosses: int = 0
	var obstacle_sets: Dictionary = {}
	for template: Dictionary in config.templates:
		if template.boss:
			bosses += 1
		else:
			normals += 1
			obstacle_sets[str(template.obstacles_tiles)] = true
	_check(normals >= 3 and bosses >= 1, "authored content contains three normal layouts and a boss arena")
	_check(obstacle_sets.size() >= 3, "normal room obstacles differ")
	for seed_value: int in range(16):
		var count: int = _generator.room_count_for_seed(seed_value, 6, 10)
		var floor_layout: Array[Dictionary] = _generator.generate(seed_value, count, config)
		_check(floor_layout.size() == count and count >= 6 and count <= 10, "authored config generates a 6-10 room floor")
		for room: Dictionary in floor_layout:
			_check(_all_floor_cells_connected(room, 24.0), "authored floor is fully connected for boss-sized actors")
			for obstacle: Array in room.obstacles:
				for component: Variant in obstacle:
					_check(fmod(float(component), 32.0) == 0.0, "obstacle geometry aligns to 32px grid")
	# Explicitly cover every authored template, including those not selected by a
	# particular run, and both enemy radii independently from grid connectivity.
	for template: Dictionary in config.templates:
		var layout: Dictionary = _generator._make_layout(template, config)
		for radius: float in [13.0, 24.0]:
			for enemy: Vector2 in layout.enemy_spawns:
				for player: Vector2 in layout.player_spawns:
					var route: PackedVector2Array = _generator.find_path(enemy, player, radius, layout)
					_check(not route.is_empty(), "every authored enemy can reach every player at radius %.0f" % radius)
					var previous: Vector2 = enemy
					for waypoint: Vector2 in route:
						_check(not _generator.segment_blocked(previous, waypoint, radius, layout), "authored chase waypoints are collision free")
						previous = waypoint
					_check(previous == player, "authored chase reaches requested player position")
