extends SceneTree
## How many enemies a fight room drawn in the Weltbauer gets (docs/WELTBAUER.de.md "Wie viele Gegner"):
## - with enemies by chance, one per room_library.mobs_by_area.cells_per_mob cells of its ground, within
##   min and max, so a big hall holds more than a small chamber;
## - a file's own count (auto_mobs) and enemies set by hand stay as they are.

const Pack = preload("res://src/world_kit/world_pack.gd")
const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const Data = preload("res://src/world_editor/world_room_data.gd")
const RUNS := [21, 22, 23]

var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("ROOM_MOBS_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_count_follows_the_ground()
	_test_floor_rooms_get_enemies_by_size()
	print("ROOM_MOBS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_count_follows_the_ground() -> void:
	# Arrange
	var by_area := {"cells_per_mob": 28, "min": 4, "max": 12}
	# Act / Assert
	check(RoomFloor.mobs_for_area(100, by_area, 0) == 4, "a small chamber holds the fewest (%d)" % RoomFloor.mobs_for_area(100, by_area, 0))
	check(RoomFloor.mobs_for_area(280, by_area, 0) == 10, "280 cells hold 10 (%d)" % RoomFloor.mobs_for_area(280, by_area, 0))
	check(RoomFloor.mobs_for_area(900, by_area, 1) == 12, "a huge hall stops at the most (%d)" % RoomFloor.mobs_for_area(900, by_area, 1))


func _test_floor_rooms_get_enemies_by_size() -> void:
	var pack := Pack.new("res://assets/data/krypta_world.json", "res://assets/sprites/krypta/manifest.json")
	var by_area: Dictionary = (pack.pack.room_library as Dictionary).get("mobs_by_area", {})
	check(not by_area.is_empty(), "the Krypta names how many cells one enemy gets")
	var small := 99
	var big := 0
	for run: int in RUNS:
		for n in range(1, pack.floor_count() + 1):
			# Arrange / Act
			var W := RoomFloor.build(n, run, pack)
			for r: Dictionary in W.get("rooms", []):
				var t: Dictionary = r.get("file", {})
				if str(r.type) != "combat" or t.is_empty() or Data.spawn_mode(t) == "manual" or int(t.get("auto_mobs", 0)) > 0:
					continue
				# Assert
				var want := RoomFloor.mobs_for_area(RoomFloor.ground_of(t), by_area, int(r.index))
				check(int(r.mobs) == want, "E%d run %d %s: %d enemies for %d cells (want %d)" % [n, run, t.id, int(r.mobs), RoomFloor.ground_of(t), want])
				if RoomFloor.ground_of(t) < 200:
					small = mini(small, int(r.mobs))
				if RoomFloor.ground_of(t) > 290:
					big = maxi(big, int(r.mobs))
	check(big >= small + 4, "a big hall holds clearly more enemies than a small chamber (%d > %d)" % [big, small])
