extends SceneTree
## The labyrinth rooms (docs/WELTBAUER.de.md "Die Labyrinthe der Krypta"):
## - the walkway joins the doors and stays lit; the maze part (maze_zone) turns dark and the camera comes nearer;
## - the maze holds no monster from the start; the dead come out of broken pieces in that very corridor;
## - such a monster chases only while it sees the hero, no wall between.

const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const RoomWorld = preload("res://src/world_editor/world_room_world.gd")
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const ROOM := "res://assets/data/world_rooms/krypta/k_labyrinth_la.json"
const M := 2
const C := 96.0

var checked := 0
var failures: Array[String] = []
var game: Node


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("MAZE_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(5)
	_test_maze_file_has_a_dark_part_and_no_fight()
	game = KryptaScene.instantiate()
	game.class_id = "swordsman"
	game.graphics_path = "user://maze_test_graphics.cfg"
	game.world_room_path = ROOM
	root.add_child(game)
	await _frames(30)
	await _test_dark_only_in_the_maze()
	_test_released_dead_stand_in_the_corridor()
	await _test_monster_chases_only_what_it_sees()
	game.queue_free()
	await process_frame
	print("MAZE checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _frames(n: int) -> void:
	for i in range(n):
		if game != null and not game.state.is_empty():
			game.state.hp = game.state.max_hp
			game.state.inv = 5.0
		await process_frame


func _room() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(ROOM))


## A floor cell of the maze part (room cells) with open ground to `ways` sides.
func _maze_cell(room: Dictionary, ways: int) -> Vector2i:
	for run: Array in room.maze_zone:
		for x in range(int(run[0]), int(run[2]) + 1):
			var c := Vector2i(x, int(run[1]))
			if _floor(room, c) and [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)].filter(func(d: Vector2i) -> bool: return _floor(room, c + d)).size() == ways:
				return c
	return Vector2i(-1, -1)


func _floor(room: Dictionary, c: Vector2i) -> bool:
	return c.y >= 0 and c.y < (room.cells as Array).size() and c.x >= 0 and c.x < str(room.cells[c.y]).length() and str(room.cells[c.y])[c.x] == "1"


func _place(c: Vector2i) -> void:
	game.player.x = (c.x + M + 0.5) * C
	game.player.y = (c.y + M + 0.5) * C + 10.0


# ---------- the file ----------

func _test_maze_file_has_a_dark_part_and_no_fight() -> void:
	# Arrange
	var room := _room()
	# Act
	var raw := RoomWorld.new(room).build_raw(3, 1)
	# Assert
	var r: Dictionary = raw.rooms[0]
	check(bool(room.get("maze", false)) and not (r.get("maze_zone", []) as Array).is_empty(), "the labyrinth knows its dark part")
	check(int(r.mobs) == 0 and (r.get("placed_mobs", []) as Array).is_empty(), "no monster waits from the start")
	var hidden := (room.objects as Array).filter(func(o: Dictionary) -> bool: return o.has("enemies")).size()
	check(hidden >= 5, "the dead hide in its pieces (%d)" % hidden)
	check((raw.ents as Array).filter(func(e: Dictionary) -> bool: return str(e.type) == "tablet").size() == 2, "an Inschrift stands at each of the two ways in")


# ---------- in the game ----------

func _test_dark_only_in_the_maze() -> void:
	# Arrange: the hero on the walkway
	var room := _room()
	var start: Dictionary = (room.objects as Array).filter(func(o: Dictionary) -> bool: return str(o.kind) == "start")[0]
	_place(Vector2i(int(float(start.x) / C), int(float(start.y) / C)))
	await _frames(40)
	var zoom_out: float = game.camera.zoom.x
	# Assert
	check(not game.in_maze() and game.maze_dark < 0.05, "the walkway stays lit (%.2f)" % game.maze_dark)
	check(game.maze_cover_alpha() > 0.9, "from the walkway the maze's corridors stay dark, never read through (%.2f)" % game.maze_cover_alpha())
	# Act: into the maze
	_place(_maze_cell(room, 2))
	await _frames(60)
	# Assert
	check(game.in_maze(), "a corridor of the maze is the maze")
	check(game.maze_dark > 0.9, "it turns dark inside (%.2f)" % game.maze_dark)
	check(game.maze_cover_alpha() < 0.1, "inside, the hero's own sight takes over from the outside cover (%.2f)" % game.maze_cover_alpha())
	if bool(game.theme.get("pixel", true)) and bool(game.cam_rig.cfg.get("pixel", {}).get("fixed_zoom", true)):
		check(is_equal_approx(game.camera.zoom.x, zoom_out), "pixel maze keeps the floor's scale while darkness closes in")
	else:
		check(game.camera.zoom.x > zoom_out * 1.05, "the non-pixel camera comes nearer (%.2f > %.2f)" % [game.camera.zoom.x, zoom_out])


func _test_released_dead_stand_in_the_corridor() -> void:
	# Arrange: a dead end of the maze, its corridor cells reached over the floor
	var room := _room()
	var dead := _maze_cell(room, 1)
	var near := {dead: 0}
	var todo: Array[Vector2i] = [dead]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		if int(near[c]) >= 3:
			continue
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _floor(room, c + d) and not near.has(c + d):
				near[c + d] = int(near[c]) + 1
				todo.append(c + d)
	var at := Vector2((dead.x + M + 0.5) * C, (dead.y + M + 0.75) * C)
	var outside := 0
	# Act: twenty times two dead out of a piece there
	for i in range(20):
		game.mobs = []
		if game.monsters != null:
			game.monsters.reset()
		game.release_room_enemies(["zombie", "zombie"], at, 0)
		for m: Dictionary in game.mobs:
			var p: Vector2 = m.get("p", Vector2(float(m.get("x", 0.0)), float(m.get("y", 0.0))))
			var c := Vector2i(int(floor(p.x / C)) - M, int(floor(p.y / C)) - M)
			if not near.has(c):
				outside += 1
	# Assert
	check(outside == 0, "every released monster stands in the piece's own corridor (%d outside)" % outside)
	game.mobs = []
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true


func _test_monster_chases_only_what_it_sees() -> void:
	# Arrange: a monster in a corridor, the hero close but behind a wall
	var room := _room()
	var a := Vector2i(-1, -1)
	var b := Vector2i(-1, -1)
	for run: Array in room.maze_zone:
		for x in range(int(run[0]), int(run[2]) + 1):
			var c := Vector2i(x, int(run[1]))
			if a.x < 0 and _floor(room, c) and not _floor(room, c + Vector2i(0, 1)) and _floor(room, c + Vector2i(0, 2)):
				a = c
				b = c + Vector2i(0, 2)
	check(a.x >= 0, "a wall between two corridors is found")
	if a.x < 0 or game.monsters == null:
		return
	game.mobs = []
	var m: Dictionary = game.monsters.spawn(0, Vector2((a.x + M + 0.5) * C, (a.y + M + 0.7) * C), "zombie")
	m.sight = 6.0 * C
	m.spawn = 0.0
	_place(b)
	var before: Vector2 = m.p
	# Act
	await _frames(45)
	# Assert
	check((m.p as Vector2).distance_to(before) < 20.0, "behind a wall it does not come (moved %.0f)" % (m.p as Vector2).distance_to(before))
	# Act: the hero steps into its corridor
	_place(a + Vector2i(0, 0) + (Vector2i(1, 0) if _floor(room, a + Vector2i(1, 0)) else Vector2i(-1, 0)) * 2 if _floor(room, a + (Vector2i(1, 0) if _floor(room, a + Vector2i(1, 0)) else Vector2i(-1, 0)) * 2) else a + (Vector2i(1, 0) if _floor(room, a + Vector2i(1, 0)) else Vector2i(-1, 0)))
	var seen_at: Vector2 = m.p
	await _frames(45)
	check((m.p as Vector2).distance_to(seen_at) > 20.0 or (m.p as Vector2).distance_to(Vector2(game.player.x, game.player.y)) < 90.0, "in sight it comes for the hero")
	game.mobs = []
