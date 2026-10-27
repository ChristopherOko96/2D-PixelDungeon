extends SceneTree
## Headless checks for collision, sight and paths on a tile grid
## (src/dungeon/tile_geometry.gd), through the shared Dungeon entry points.

const FloorMap = preload("res://src/dungeon/floor_map_generator.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("TILE_GEOMETRY_FAIL: ", description)

func _initialize() -> void:
	# Arrange: a 12 x 8 room (walls around) with a wall stub from the top at x = 6.
	var rows := [
		"############",
		"#.....#....#",
		"#.....#....#",
		"#.....#....#",
		"#..........#",
		"#..........#",
		"#..........#",
		"############"]
	var map := _map(rows, 1)

	# Movement and sliding.
	var moved: Vector2 = Dungeon.move_actor(Vector2(100, 60), Vector2(200, 0), 12.0, map)
	check(moved.x <= 192.0 - 12.0 + 0.01 and moved.x > 150.0, "a body stops at a wall instead of passing it")
	var slid: Vector2 = Dungeon.move_actor(Vector2(100, 60), Vector2(200, 40), 12.0, map)
	check(slid.y > 60.0 and slid.x <= 180.01, "blocked on one axis, a body slides along the other")
	var fast: Vector2 = Dungeon.move_actor(Vector2(100, 170), Vector2(2000, 0), 12.0, map)
	check(fast.x <= 352.0 - 12.0 + 0.01 and fast.x > 300.0, "a huge step cannot tunnel through the outer wall")
	check(Dungeon.move_actor(Vector2(16, 16), Vector2(50, 0), 12.0, map) == Vector2(16, 16), "a body inside a wall stays put")

	# Sight and shots.
	check(Dungeon.segment_blocked(Vector2(100, 60), Vector2(260, 60), 0.0, map), "the wall stub blocks sight")
	check(not Dungeon.segment_blocked(Vector2(100, 170), Vector2(300, 170), 0.0, map), "an open floor gives clear sight")
	check(Dungeon.segment_blocked(Vector2(100, 150), Vector2(300, 150), 24.0, map) and not Dungeon.segment_blocked(Vector2(100, 150), Vector2(300, 150), 0.0, map), "a wide body grazes the stub where a shot still passes")
	check(Dungeon.segment_blocked(Vector2(100, 170), Vector2(100, 400), 0.0, map), "a shot out of the map is blocked")

	# Paths around the stub; none into a sealed pocket.
	var path: PackedVector2Array = Dungeon.find_path(Vector2(100, 60), Vector2(300, 60), 12.0, map)
	check(not path.is_empty() and path[path.size() - 1] == Vector2(300, 60), "a path leads around the wall to the goal")
	var walk := Vector2(100, 60)
	var ok := true
	for point: Vector2 in path:
		if Dungeon.segment_blocked(walk, point, 12.0, map): ok = false
		walk = point
	check(ok, "every leg of the path is walkable for the body")
	var sealed := _map([
		"#######",
		"#..#..#",
		"#..#..#",
		"#######"], 2)
	check(Dungeon.find_path(Vector2(48, 48), Vector2(150, 48), 12.0, sealed).is_empty(), "there is no path into a sealed pocket")
	var free: Vector2 = Dungeon._nearest_free_point(Vector2(10, 10), 12.0, map)
	check(FloorMap.clear_at(map, free, 12.0), "the nearest free point has room for the body")

	# A real floor: the start reaches the boss arena for the biggest bodies.
	var map_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_floormap.json"))
	var rooms_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	var floor_map: Dictionary = FloorMap.generate(4242, map_config, rooms_config)
	var boss: Dictionary = floor_map.rooms.filter(func(room: Dictionary) -> bool: return room.kind == "boss")[0]
	var route: PackedVector2Array = Dungeon.find_path(floor_map.rooms[0].player_spawns[0], boss.enemy_spawns[0], 24.0, floor_map)
	check(not route.is_empty(), "a boss-sized body finds a way from the start to the boss arena")

	print("TILE_GEOMETRY checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

# A floor map from text rows: '#' wall, '.' room floor.
func _map(rows: Array, seed: int) -> Dictionary:
	var tiles := PackedByteArray()
	for row: String in rows:
		for ch in row:
			tiles.append(FloorMap.SOLID if ch == "#" else FloorMap.ROOM)
	return {"seed": seed, "width": rows[0].length(), "height": rows.size(), "tile_size": 32, "tiles": tiles, "rooms": []}
