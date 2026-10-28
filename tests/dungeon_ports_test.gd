extends SceneTree
## Exercises generated physical connections independently from game input/networking.

var checked := 0
var failures: Array[String] = []
var generator: Script

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("DUNGEON_PORTS_FAIL: ", description)

func _initialize() -> void:
	generator = load("res://src/dungeon/dungeon_generator.gd")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	var themes := {}
	for seed_value: int in range(12):
		var rooms: Array[Dictionary] = generator.generate(seed_value, 3, config)
		check(rooms.size() == 3, "a three-room floor is generated")
		if rooms.is_empty(): continue
		check(rooms == generator.generate(seed_value, 3, config), "ports and themes are deterministic")
		check(int(rooms[0].generator_version) == 4, "physical-connection layout uses generator version four")
		check(rooms[0].has("theme") and rooms[0].has("exits"), "generated rooms carry a theme and physical exits")
		if not rooms[0].has("theme") or not rooms[0].has("exits"): continue
		for index: int in range(rooms.size()):
			var room: Dictionary = rooms[index]
			themes[room.theme] = true
			check(room.theme in ["rose", "moss", "amber", "violet"], "theme selects a supplied tileset")
			check(room.exits.size() == (1 if index == 0 else 2), "only route connections and the final stairs are generated")
			var stair_count := 0
			for exit: Dictionary in room.exits:
				var bounds := Rect2(float(room.play_bounds[0]), float(room.play_bounds[1]), float(room.play_bounds[2]), float(room.play_bounds[3]))
				var region := Rect2(float(exit.rect[0]), float(exit.rect[1]), float(exit.rect[2]), float(exit.rect[3]))
				check(bounds.encloses(region), "exit trigger stays inside physical floor")
				check(not generator.segment_blocked(region.get_center(), region.get_center(), 12.0, room), "exit center clears player radius")
				check(not generator.find_path(room.player_spawns[0], region.get_center(), 12.0, room).is_empty(), "exit is reachable from the spawn")
				if exit.kind == "stairs":
					stair_count += 1
					check(index == 2 and exit.target_room == 0, "stairs only lead down from the final room")
					continue
				check(exit.kind == "door", "room link is a door")
				var target_index: int = int(exit.target_room) - 1
				check(target_index >= 0 and target_index < rooms.size() and absi(target_index - index) == 1, "door targets an actual adjacent route room")
				var target: Dictionary = rooms[target_index]
				var expected_side: String = "east" if target.grid_x > room.grid_x else "west" if target.grid_x < room.grid_x else "south" if target.grid_y > room.grid_y else "north"
				# Crypt gates sit in a north wall face; the logical direction is `toward`.
				var direction: String = str(exit.get("toward", exit.side))
				check(direction == expected_side, "door follows logical room direction")
				var opposites := {"east": "west", "west": "east", "north": "south", "south": "north"}
				var reciprocal: Array = target.exits.filter(func(value: Dictionary) -> bool: return value.kind == "door" and int(value.target_room) == index + 1)
				check(reciprocal.size() == 1 and str(reciprocal[0].get("toward", reciprocal[0].side)) == opposites[direction], "adjacent room has exactly one opposite return door")
				if exit.has("door_cell"):
					# A gate: both arch cells are wall, the trigger right below is floor.
					var gate := Vector2i(int(exit.door_cell[0]), int(exit.door_cell[1]))
					var cells := {}
					for tile: Dictionary in room.painted_tiles:
						var key := Vector2i(int(tile.x), int(tile.y))
						if bool(tile.get("solid", false)): cells[key] = "wall"
						elif str(tile.get("layer", "")) == "floor" and not cells.has(key): cells[key] = "floor"
					check(cells.get(gate, "") == "wall" and cells.get(gate + Vector2i.RIGHT, "") == "wall", "a crypt gate is set into a wall, never onto the floor")
					check(Vector2i(int(region.get_center().x / 32.0), int(region.get_center().y / 32.0)).y == gate.y + 1, "the gate's trigger is the floor right in front of it")
				else:
					var other_region: Rect2 = Rect2(float(reciprocal[0].rect[0]), float(reciprocal[0].rect[1]), float(reciprocal[0].rect[2]), float(reciprocal[0].rect[3]))
					check(is_equal_approx(region.position.y, other_region.position.y) if exit.side in ["east", "west"] else is_equal_approx(region.position.x, other_region.position.x), "opposite doorways share the same lane")
					match exit.side:
						"north": check(is_equal_approx(region.position.y, bounds.position.y), "north door meets north wall")
						"south": check(is_equal_approx(region.end.y, bounds.end.y), "south door meets south wall")
						"east": check(is_equal_approx(region.end.x, bounds.end.x), "east door meets east wall")
						"west": check(is_equal_approx(region.position.x, bounds.position.x), "west door meets west wall")
				var entries: Array[Vector2] = []
				for slot: int in range(4):
					var entry: Vector2 = generator.entry_for_player(int(exit.target_room), slot, room)
					check(not generator.segment_blocked(entry, entry, 12.0, room), "every player entry slot clears geometry")
					check(not region.grow(12.0).has_point(entry), "arrival cannot immediately retrigger the doorway")
					check(not generator.find_path(region.get_center(), entry, 12.0, room).is_empty(), "every entry slot is reachable from its door")
					for earlier: Vector2 in entries:
						check(entry.distance_to(earlier) >= 25.0, "party entry slots do not overlap")
					entries.append(entry)
			check(stair_count == (1 if index == 2 else 0), "only boss room has one staircase")
	check(themes.size() == 4, "different seeds expose all four supplied palettes")
	var long_floor: Array[Dictionary] = generator.generate(7241, 10, config)
	check(long_floor.size() == 10, "maximum supported floor retains usable connections")
	for room: Dictionary in long_floor:
		check(generator.entry_for_player(-123, 2, room) == room.player_spawns[2], "unknown entrance origin falls back to an authored spawn")
		for exit: Dictionary in room.exits:
			if exit.kind != "door": continue
			for slot: int in range(4):
				var entry: Vector2 = generator.entry_for_player(int(exit.target_room), slot, room)
				check(not generator.segment_blocked(entry, entry, 12.0, room), "all four maximum-floor arrival slots are clear")
	var malformed_layout: Dictionary = generator._make_layout(config.templates[0], config)
	malformed_layout.id = "blocked-fixture"
	malformed_layout.obstacles = [[432.0, 48.0, 32.0, 32.0]]
	check(generator._make_door("north", 2, malformed_layout).is_empty(), "a solid covering the requested doorway fails closed")
	print("DUNGEON_PORTS checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
