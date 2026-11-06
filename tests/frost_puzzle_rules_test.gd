extends SceneTree
## The rules of the Frostgruft's puzzle pieces without a game (src/world_kit/frost_puzzles.gd):
## the aurora light and its prisms, the sliding ice block, the growing snowball, the mirror ghost,
## the crystal bells and the ember's steps.

const Frost = preload("res://src/world_kit/frost_puzzles.gd")

var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("FROST_RULES_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_prisms_turn_the_light()
	_test_light_stops_and_lights_a_seal()
	_test_block_slides_until_stopped_and_fills_a_crevasse()
	_test_snowball_grows_and_only_a_big_one_fills()
	_test_ghost_mirrors_and_waits_at_walls()
	_test_bells_count_only_the_melody()
	_test_ember_costs_more_in_fog()
	_test_bell_wave_is_sound()
	print("FROST_RULES checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## A map of letters: '#' wall, '/' and '\' prisms, 'S' seal, 'B' something solid, '.' free, 'o' a pit.
func _map(rows: Array) -> Callable:
	return func(c: Vector2i) -> String:
		if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= str(rows[c.y]).length():
			return "wall"
		match str(rows[c.y])[c.x]:
			"#": return "wall"
			"/": return "prism0"
			"\\": return "prism1"
			"S": return "seal"
			"B": return "stop"
		return "free"


func _test_prisms_turn_the_light() -> void:
	check(Frost.reflect(Vector2i(1, 0), 0) == Vector2i(0, -1), "east into / goes north")
	check(Frost.reflect(Vector2i(0, -1), 0) == Vector2i(1, 0), "north into / goes east")
	check(Frost.reflect(Vector2i(1, 0), 1) == Vector2i(0, 1), "east into \\ goes south")
	check(Frost.reflect(Vector2i(-1, 0), 1) == Vector2i(0, -1), "west into \\ goes north")


func _test_light_stops_and_lights_a_seal() -> void:
	# Arrange: the light leaves (0, 2) eastwards, turns north at (3, 2), east at (3, 0), meets the seal
	var rows := [".../..S", ".......", ".../...", "......."]
	var what := _map(rows)
	# Act
	var res := Frost.trace(Vector2i(0, 2), Vector2i(1, 0), _map(rows))
	# Assert
	check(res.seal == Vector2i(6, 0), "the light reaches the seal over two prisms (%s)" % str(res.seal))
	check((res.turns as Array).size() == 2, "it turned twice (%d)" % (res.turns as Array).size())
	var blocked := Frost.trace(Vector2i(0, 0), Vector2i(1, 0), _map(["..B..S"]))
	check(blocked.seal == null and blocked.end == Vector2i(2, 0), "something solid stops the light (%s)" % str(blocked.end))
	var loop := Frost.trace(Vector2i(0, 1), Vector2i(1, 0), _map(["#######", "#/...\\#", "#.....#", "#\\.../#", "#######"]))
	check(loop.seal == null, "a ring of prisms never runs forever")
	check(what.call(Vector2i(6, 0)) == "seal", "the map helper reads seals")


func _test_block_slides_until_stopped_and_fills_a_crevasse() -> void:
	# Arrange / Act
	var stop := Frost.slide(Vector2i(0, 0), Vector2i(1, 0), func(c: Vector2i) -> String: return "block" if c.x >= 5 else "free")
	var pit := Frost.slide(Vector2i(0, 0), Vector2i(1, 0), func(c: Vector2i) -> String: return "pit" if c.x == 3 else "free")
	var none := Frost.slide(Vector2i(0, 0), Vector2i(1, 0), func(_c: Vector2i) -> String: return "block")
	# Assert
	check(stop.to == Vector2i(4, 0) and not stop.fill, "the block stops before the wall (%s)" % str(stop.to))
	check(pit.to == Vector2i(3, 0) and pit.fill, "the block drops into the crevasse it meets")
	check(none.to == Vector2i(0, 0), "a block against a wall stays")


func _test_snowball_grows_and_only_a_big_one_fills() -> void:
	var free := func(c: Vector2i) -> String: return "pit" if c.x == 9 else "free"
	var snow := func(c: Vector2i) -> bool: return c.x == 1 or c.x == 2 or c.x == 3
	# Act
	var a := Frost.roll(Vector2i(0, 0), Vector2i(1, 0), 1, free, snow)
	var b := Frost.roll(Vector2i(3, 0), Vector2i(1, 0), 3, free, snow)
	var small := Frost.roll(Vector2i(8, 0), Vector2i(1, 0), 2, free, snow)
	var big := Frost.roll(Vector2i(8, 0), Vector2i(1, 0), 3, free, snow)
	var full := Frost.roll(Vector2i(2, 0), Vector2i(1, 0), 3, free, snow)
	# Assert
	check(a.size == 2 and a.to == Vector2i(1, 0), "deep snow makes the ball bigger")
	check(b.size == 3 and b.moved, "plain snow keeps its size")
	check(small.lost and not small.fill, "a small ball is lost in the crevasse")
	check(big.fill and not big.lost, "a big ball fills the crevasse")
	check(full.size == 3, "a ball never grows past the biggest size")


func _test_ghost_mirrors_and_waits_at_walls() -> void:
	var open := func(c: Vector2i) -> bool: return c.x >= 0 and c.x <= 4
	# Act
	var left := Frost.ghost_step(Vector2i(2, 2), Vector2i(1, 0), open)
	var down := Frost.ghost_step(Vector2i(2, 2), Vector2i(0, 1), open)
	var wall := Frost.ghost_step(Vector2i(0, 2), Vector2i(1, 0), open)
	var diag := Frost.ghost_step(Vector2i(2, 2), Vector2i(-1, -1), open)
	# Assert
	check(left == Vector2i(1, 2), "the hero steps right, the ghost left")
	check(down == Vector2i(2, 3), "up and down stay the same")
	check(wall == Vector2i(0, 2), "against a wall the ghost waits")
	check(diag == Vector2i(3, 1), "a slant step is mirrored sideways only")


func _test_bells_count_only_the_melody() -> void:
	var melody := Frost.melody_of("5, 4,2,1")
	check(melody == [5, 4, 2, 1], "the melody reads its numbers (%s)" % str(melody))
	check(Frost.bell_strike(melody, 0, 5) == "right", "the first right note")
	check(Frost.bell_strike(melody, 3, 1) == "done", "the last note finishes it")
	check(Frost.bell_strike(melody, 1, 2) == "wrong", "a wrong note")
	check(Frost.melody_of([3, "1"]) == [3, 1], "a melody as a list")


func _test_ember_costs_more_in_fog() -> void:
	var data := {"ember": {"fog_cost": 3}}
	check(Frost.ember_cost(false, data) == 1, "a plain cell costs one step")
	check(Frost.ember_cost(true, data) == 3, "cold fog costs its fog_cost")


func _test_bell_wave_is_sound() -> void:
	var w := Frost.bell_wave(523.25, 0.2, 3.0, [[1.0, 1.0], [2.0, 0.5]])
	check(w.data.size() == int(22050 * 0.2) * 2, "the bell is 16 bit mono of its length")
	var loud := 0
	for i in range(0, w.data.size(), 2):
		loud = maxi(loud, absi(w.data.decode_s16(i)))
	check(loud > 3000 and loud <= 30000, "the bell sounds and never clips (%d)" % loud)
