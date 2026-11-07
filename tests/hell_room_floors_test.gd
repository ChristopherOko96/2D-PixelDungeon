extends SceneTree
## The hell's floors come from the Weltbauer's room files (assets/data/world_rooms/hell,
## hell_world.json room_library, tools/hell_dungeon/rooms/build_hell_rooms.js), as the Krypta's do:
## - every file is playable and its canvas fits its slots;
## - all ten floors build from files for several runs, none falls back to the generator;
## - puzzle rooms (role jump) turn up over the runs and never hold a fight;
## - the enemies follow the ground of the rooms, far fewer than the generator's 200 a floor.

const Pack = preload("res://src/world_kit/world_pack.gd")
const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const Data = preload("res://src/world_editor/world_room_data.gd")
const RUNS := [101, 202, 303, 404]
## The most enemies a floor may hold in all (the generator's floors had up to 200).
## The hell is the steep last world: one more enemy per fight room every third floor (hell_world.js DIFF).
const MOST_ENEMIES := 150

var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_FLOORS_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_files_are_playable()
	_test_floors_come_from_files()
	print("HELL_FLOORS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_files_are_playable() -> void:
	# Arrange
	var files := Data.list_rooms("hell")
	# Assert
	check(files.size() >= 50, "the Hölle has its room files (%d)" % files.size())
	var roles := {}
	for t: Dictionary in files:
		if not bool(t.get("in_floors", false)):
			continue
		roles[str(t.role)] = int(roles.get(str(t.role), 0)) + 1
		check(Data.problems(t).is_empty(), "%s is playable: %s" % [t.id, str(Data.problems(t))])
		check(Data.floor_size_fits(t), "%s fits its slots" % t.id)
	for role: String in ["start", "combat", "key", "boss", "portal", "treasure", "vault", "secret", "stairs", "jump"]:
		check(int(roles.get(role, 0)) > 0, "a room file for the role %s" % role)


func _test_floors_come_from_files() -> void:
	var pack := Pack.new("res://assets/data/hell_world.json", "res://assets/sprites/hell/manifest.json")
	check(pack.pack.has("room_library"), "the Hölle builds from room files")
	var puzzles := {}
	for run: int in RUNS:
		for n in range(1, pack.floor_count() + 1):
			# Act
			var W := RoomFloor.build(n, run, pack)
			# Assert
			check(not W.is_empty(), "floor %d of run %d builds from the room files" % [n, run])
			if W.is_empty():
				continue
			var enemies := 0
			for r: Dictionary in W.rooms:
				var t: Dictionary = r.get("file", {})
				check(str(t.get("world", "")) == "hell", "E%d run %d: room %s is a Hölle file" % [n, run, str(t.get("id", "?"))])
				if str(r.gtype) == "jump":
					puzzles[str(t.id)] = true
					check(int(r.get("mobs", 0)) == 0 and not r.has("placed_mobs"), "E%d run %d: the puzzle room %s holds no fight" % [n, run, t.id])
				enemies += int(r.get("mobs", 0)) + (r.get("placed_mobs", []) as Array).size()
			check(enemies <= MOST_ENEMIES, "E%d run %d: %d enemies, at most %d" % [n, run, enemies, MOST_ENEMIES])
	# the tiers of the puzzles met follow the floors (docs/BEUTEORDNUNG.de.md 3): low on floor 1, high on floor 10
	check(puzzles.size() >= 6, "several puzzle rooms turn up over the runs (%s)" % str(puzzles.keys()))
	print("HELL_FLOORS puzzles seen: ", puzzles.keys())
