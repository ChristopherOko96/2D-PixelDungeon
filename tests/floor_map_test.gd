extends SceneTree
## Headless checks for the large floor map generator (src/dungeon/floor_map_generator.gd)
## with the real data files: determinism, layout rules and connectivity over many seeds.

const FloorMap = preload("res://src/dungeon/floor_map_generator.gd")
const SEEDS := 150
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("FLOOR_MAP_FAIL: ", description)

func _initialize() -> void:
	var map_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_floormap.json"))
	var rooms_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	check(FloorMap.validate(map_config, rooms_config).is_empty(), "the shipped floor map data is valid")

	# Bad data fails closed.
	var broken := map_config.duplicate(true)
	broken.cell_tiles = [20, 12]
	check(not FloorMap.validate(broken, rooms_config).is_empty() and FloorMap.generate(1, broken, rooms_config).is_empty(), "cells too small for a template room are rejected")
	var wide := map_config.duplicate(true)
	wide.corridor_width = 5
	check(not FloorMap.validate(wide, rooms_config).is_empty(), "a corridor wider than the cell band is rejected")
	var too_many := map_config.duplicate(true)
	too_many.room_count = [7, 20]
	check(not FloorMap.validate(too_many, rooms_config).is_empty(), "more rooms than cells are rejected")

	# Same seed, same map; another seed, another map.
	var first: Dictionary = FloorMap.generate(4242, map_config, rooms_config)
	var again: Dictionary = FloorMap.generate(4242, map_config, rooms_config)
	var other: Dictionary = FloorMap.generate(4243, map_config, rooms_config)
	check(first.tiles == again.tiles and first.rooms.size() == again.rooms.size() and first.rooms[0].id == again.rooms[0].id, "the same seed builds the same floor")
	check(first.tiles != other.tiles, "another seed builds another floor")
	check(int(first.width) == 96 and int(first.height) == 64 and first.tiles.size() == 96 * 64, "the floor is 96 x 64 tiles")

	var all_ok := {"count": true, "kinds": true, "boss_far": true, "connected": true, "overlap": true, "spawns": true, "doors": true, "walls": true, "arena": true, "corridor": true}
	for seed: int in range(1, SEEDS + 1):
		var map: Dictionary = FloorMap.generate(seed, map_config, rooms_config)
		var rooms: Array = map.rooms
		if rooms.size() < int(map_config.room_count[0]) or rooms.size() > int(map_config.room_count[1]): all_ok.count = false
		var kinds: Dictionary = {}
		for room: Dictionary in rooms: kinds[room.kind] = int(kinds.get(room.kind, 0)) + 1
		if rooms[0].kind != "start" or int(kinds.get("boss", 0)) != 1 or int(kinds.get("treasure", 0)) != 1: all_ok.kinds = false
		var boss: Dictionary = rooms.filter(func(room: Dictionary) -> bool: return room.kind == "boss")[0]
		for room: Dictionary in rooms:
			if int(room.distance) > int(boss.distance): all_ok.boss_far = false
		# Boss arenas keep their authored 28 x 15 size, so the boss patterns still fit.
		if Array(boss.rect).slice(2, 4) != [28, 15] or str(boss.template_id).is_empty(): all_ok.arena = false
		var reach: Vector2i = FloorMap.reachable(map)
		if reach.x != reach.y: all_ok.connected = false
		for i: int in range(rooms.size()):
			var a := _rect(rooms[i].rect)
			for j: int in range(i + 1, rooms.size()):
				if a.grow(1).intersects(_rect(rooms[j].rect)): all_ok.overlap = false
			# Spawns stand on open floor with room for the actor's body.
			for point: Vector2 in rooms[i].player_spawns:
				if not FloorMap.clear_at(map, point, 12.0): all_ok.spawns = false
			for point: Vector2 in rooms[i].enemy_spawns:
				if not FloorMap.clear_at(map, point, 12.0): all_ok.spawns = false
			if rooms[i].player_spawns.size() < 4 or rooms[i].enemy_spawns.size() < 1: all_ok.spawns = false
			# Every connection has a doorway on both rooms, and a room is entered only through doorways.
			if rooms[i].doors.is_empty(): all_ok.doors = false
			for side: String in rooms[i].doors:
				var tile: Array = rooms[i].doors[side].tile
				if FloorMap.tile_at(map, int(tile[0]), int(tile[1])) != FloorMap.DOORWAY: all_ok.doors = false
			var outline := _rect(rooms[i].rect)
			for x: int in range(outline.position.x, outline.end.x):
				for y: int in [outline.position.y, outline.end.y - 1]:
					var code: int = FloorMap.tile_at(map, x, y)
					if code != FloorMap.SOLID and code != FloorMap.DOORWAY: all_ok.walls = false
			for y: int in range(outline.position.y, outline.end.y):
				for x: int in [outline.position.x, outline.end.x - 1]:
					var code: int = FloorMap.tile_at(map, x, y)
					if code != FloorMap.SOLID and code != FloorMap.DOORWAY: all_ok.walls = false
		# Corridors are wide enough for the largest body (3 tiles: 96 px > 2 x 24 px).
		for y: int in range(int(map.height)):
			for x: int in range(int(map.width)):
				if FloorMap.tile_at(map, x, y) == FloorMap.CORRIDOR and not _in_open_3x3(map, x, y): all_ok.corridor = false
	check(all_ok.count, "every floor has 7 to 9 rooms")
	check(all_ok.kinds, "every floor has a start, one boss and one treasure room")
	check(all_ok.boss_far, "the boss room is the farthest room from the start")
	check(all_ok.arena, "boss arenas keep the authored 28 x 15 template")
	check(all_ok.connected, "every walkable tile is reachable from the start")
	check(all_ok.overlap, "rooms never touch or overlap")
	check(all_ok.spawns, "spawns stand on open floor, four for players and at least one enemy")
	check(all_ok.doors, "every room has doorways and each door is a doorway tile")
	check(all_ok.walls, "a room's outline is wall except its doorways, so corridors never cut walls")
	check(all_ok.corridor, "every corridor tile lies in a 3 x 3 open block")

	var room_index: int = FloorMap.room_at(first, first.rooms[0].player_spawns[0])
	check(room_index == 0, "room_at finds the start room from its spawn")
	check(FloorMap.room_at(first, Vector2(-100, -100)) == -1, "outside every room room_at is -1")

	print("FLOOR_MAP checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _rect(value: Array) -> Rect2i:
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))

# Some 3 x 3 block containing (x, y) is entirely walkable.
func _in_open_3x3(map: Dictionary, x: int, y: int) -> bool:
	for oy: int in range(-2, 1):
		for ox: int in range(-2, 1):
			var open := true
			for dy: int in range(3):
				for dx: int in range(3):
					if not FloorMap.walkable(FloorMap.tile_at(map, x + ox + dx, y + oy + dy)): open = false
			if open: return true
	return false
