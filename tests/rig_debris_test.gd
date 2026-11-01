extends SceneTree
## The shared debris physics (src/rig_kit/rig_debris.gd, RigDebris) on a fake
## world (a RigDebrisHost with wall rectangles and hook counters):
## - a piece flying into a wall is thrown back (wall_bounce, wall_spin) and
##   never enters it; one that starts inside a wall leaves freely;
## - a falling piece bounces, slides and comes to rest, and stays put after;
## - above cap the oldest resting pieces crumble by dither level and go after
##   dither_time; moving pieces never crumble;
## - bounces: after the last bounce the next landing stops it dead (the hero's
##   weapon); a lying piece eases onto snap_turn; max_air lays a piece down;
## - a shove pushes overlapping pieces apart; on_land runs once at the first
##   bounce and its shards join, a broken piece goes;
## - launch is deterministic for a seed, and vfx_gore.json "ragdoll" carries
##   every physics key the rigs run on (no code fallbacks any more).
## Deterministic, no files written.

const DT := 1.0 / 60.0
const GORE := "res://assets/data/vfx_gore.json"
## The physics keys the rig ragdoll reads (RigDebris header).
const RIG_KEYS := ["gravity", "bounce", "rest_vz", "ground_keep", "spin_keep", "wall_bounce", "wall_spin", "friction", "rest_speed", "rest_spin",
	"radius", "shove", "cap", "dither_time", "speed", "spread", "jitter", "pop", "depth", "lift", "spin", "scatter", "loose", "turn_steps", "turn_new", "outline"]
## A floor-bound test material: strong gravity, a clear bounce, quick friction.
const PHYS := {"gravity": 600.0, "bounce": 0.4, "rest_vz": 40.0, "ground_keep": 0.6, "spin_keep": 0.5, "wall_bounce": 0.5, "wall_spin": -0.5,
	"friction": 8.0, "rest_speed": 5.0, "rest_spin": 1.5, "radius": 4.0, "shove": 1.4, "cap": 3, "dither_time": 0.4}


## A world of wall rectangles that counts what RigDebris asked of it.
class FakeWorld extends RigDebrisHost:
	var walls: Array[Rect2] = []
	var ticks := 0
	var wall_hits := 0
	var landings := 0
	var shards: Array[Dictionary] = []

	func solid(point: Vector2) -> bool:
		for r: Rect2 in walls:
			if r.has_point(point): return true
		return false

	func on_tick(_piece: Dictionary, _delta: float) -> void:
		ticks += 1

	func on_wall(_piece: Dictionary) -> void:
		wall_hits += 1

	func on_land(piece: Dictionary) -> Array[Dictionary]:
		landings += 1
		if not bool(piece.get("brittle", false)): return []
		piece.broken = true
		return shards


var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("RIG_DEBRIS_FAIL: ", description)


func _initialize() -> void:
	_test_wall_throws_a_piece_back_and_keeps_it_out()
	_test_piece_inside_a_wall_leaves_freely()
	_test_falling_piece_bounces_slides_and_rests()
	_test_cap_crumbles_the_oldest_resting_pieces()
	_test_last_bounce_stops_dead_and_snaps_flat()
	_test_max_air_lays_a_piece_down()
	_test_shove_pushes_overlapping_pieces_apart()
	_test_first_bounce_shatters_once()
	_test_launch_is_deterministic_for_a_seed()
	_test_gore_table_carries_every_rig_key()
	print("RIG_DEBRIS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


static func _piece(x: float, y: float, z: float, vx: float, vy: float, vz: float, spin := 0.0) -> Dictionary:
	return {"x": x, "y": y, "z": z, "vx": vx, "vy": vy, "vz": vz, "ang": 0.0, "spin": spin, "life": 0.0, "rest": false}


func _test_wall_throws_a_piece_back_and_keeps_it_out() -> void:
	# Arrange: a wall from x = 100 on, a piece sliding at it on the floor
	var world := FakeWorld.new()
	world.walls.append(Rect2(100, -1000, 500, 2000))
	var debris := RigDebris.new(PHYS.duplicate(), world)
	var d := _piece(90.0, 0.0, 0.0, 300.0, 0.0, 0.0, 4.0)
	debris.add(d)
	# Act
	var entered := false
	var first_vx := 0.0
	var first_spin := 0.0
	for i in range(30):
		debris.step(DT)
		if world.wall_hits == 1 and first_vx == 0.0:
			first_vx = float(d.vx)
			first_spin = float(d.spin)
		if world.solid(Vector2(float(d.x), float(d.y))): entered = true
	# Assert
	check(world.wall_hits >= 1, "a piece flying into a wall hits it (%d)" % world.wall_hits)
	check(first_vx < 0.0 and absf(first_vx) <= 300.0 * 0.5 + 0.01, "the wall throws it back with wall_bounce of its speed (vx %.1f)" % first_vx)
	check(first_spin < 0.0, "wall_spin turns its spin round (%.2f)" % first_spin)
	check(not entered and float(d.x) < 100.0, "it never enters the wall (x %.1f)" % float(d.x))


func _test_piece_inside_a_wall_leaves_freely() -> void:
	# Arrange: a piece cut at the wall starts inside it
	var world := FakeWorld.new()
	world.walls.append(Rect2(100, -1000, 500, 2000))
	var debris := RigDebris.new(PHYS.duplicate(), world)
	var d := _piece(105.0, 0.0, 0.0, -200.0, 0.0, 0.0)
	debris.add(d)
	# Act
	for i in range(10): debris.step(DT)
	# Assert
	check(float(d.x) < 100.0 and world.wall_hits == 0, "a piece starting inside a wall leaves it freely (x %.1f, hits %d)" % [float(d.x), world.wall_hits])


func _test_falling_piece_bounces_slides_and_rests() -> void:
	# Arrange: dropped from 30 px with a push, on an open floor
	var world := FakeWorld.new()
	var debris := RigDebris.new(PHYS.duplicate(), world)
	var d := _piece(0.0, 0.0, 30.0, 120.0, 0.0, 80.0, 6.0)
	debris.add(d)
	# Act
	var bounces := 0
	var rest_at := -1.0
	var results: Array[int] = []
	for i in range(240):
		var before_vz := float(d.vz)
		debris.step(DT)
		if before_vz < 0.0 and float(d.vz) > 0.0: bounces += 1
		if bool(d.rest) and rest_at < 0.0: rest_at = debris.clock
	var still := Vector2(float(d.x), float(d.y))
	for i in range(30): results.append(debris.step_piece(d, DT))
	# Assert
	check(bounces >= 1, "a hard landing bounces (%d)" % bounces)
	check(rest_at > 0.0 and rest_at < 3.0, "it comes to rest within 3 s (%.2f s)" % rest_at)
	check(float(d.z) == 0.0 and float(d.vx) == 0.0 and float(d.vy) == 0.0 and float(d.spin) == 0.0, "a resting piece lies on the floor without speed or spin")
	check(still == Vector2(float(d.x), float(d.y)) and results.all(func(r: int) -> bool: return r == RigDebris.Step.IDLE), "a resting piece stays put (IDLE)")
	check(world.ticks > 0, "the host is ticked every step")


func _test_cap_crumbles_the_oldest_resting_pieces() -> void:
	# Arrange: five resting pieces and one moving one, cap 3
	var debris := RigDebris.new(PHYS.duplicate())
	for i in range(5):
		var d := _piece(float(i) * 50.0, 0.0, 0.0, 0.0, 0.0, 0.0)
		d.rest = true
		d.n = i
		debris.add(d)
	var moving := _piece(400.0, 0.0, 50.0, 0.0, 0.0, 0.0)
	debris.add(moving)
	# Act
	debris.step(DT)
	var crumbling: Array = debris.pieces.filter(func(d: Dictionary) -> bool: return float(d.get("gone_at", -1.0)) >= 0.0).map(func(d: Dictionary) -> int: return int(d.get("n", -1)))
	var level_now := debris.crumble_level(debris.pieces[0])
	for i in range(int(0.25 / DT)): debris.step(DT)
	var level_later := debris.crumble_level(debris.pieces[0]) if float(debris.pieces[0].get("gone_at", -1.0)) >= 0.0 else -1
	for i in range(int(0.3 / DT)): debris.step(DT)
	# Assert
	check(crumbling == [0, 1, 2], "above cap (3 of 6 standing) the three oldest resting pieces crumble, not the moving one (%s)" % [crumbling])
	check(level_now == 1 and level_later >= 2 and level_later <= 3, "a crumbling piece loses its pixels by dither level (%d -> %d)" % [level_now, level_later])
	check(debris.pieces.size() == 3 and not debris.pieces.any(func(d: Dictionary) -> bool: return int(d.get("n", -1)) in [0, 1, 2]), "after dither_time the crumbled pieces are gone (%d left)" % debris.pieces.size())


func _test_last_bounce_stops_dead_and_snaps_flat() -> void:
	# Arrange: the hero weapon's rule: one bounce, then it lies on its flat side (half turns + a quarter)
	var phys := {"gravity": 600.0, "bounce": 0.35, "rest_vz": 0.0, "ground_keep": 0.6, "spin_keep": 0.4, "bounces": 1, "snap_turn": 0.5, "snap_offset": 0.25, "snap_rate": 15.0}
	var debris := RigDebris.new(phys)
	var d := _piece(0.0, 0.0, 20.0, 40.0, 0.0, 60.0, 5.0)
	debris.add(d)
	# Act
	var steps: Array[int] = []
	for i in range(240): steps.append(debris.step_piece(d, DT))
	# Assert
	check(steps.count(RigDebris.Step.BOUNCE) == 1, "it bounces exactly once (%d)" % steps.count(RigDebris.Step.BOUNCE))
	check(steps.count(RigDebris.Step.REST) == 1 and steps.find(RigDebris.Step.REST) > steps.find(RigDebris.Step.BOUNCE), "the next landing stops it dead")
	var flat := RigDebris.snapped_angle(float(d.ang), phys)
	check(absf(float(d.ang) - flat) < 0.01 and absf(fposmod(flat - PI * 0.5, PI)) < 0.001, "lying, it eased onto its flat side (%.3f rad)" % float(d.ang))


func _test_max_air_lays_a_piece_down() -> void:
	# Arrange: no gravity, so it would hang in the air for ever
	var debris := RigDebris.new({"max_air": 0.5})
	var d := _piece(0.0, 0.0, 10.0, 0.0, 0.0, 0.0)
	debris.add(d)
	# Act
	for i in range(int(0.6 / DT)): debris.step(DT)
	# Assert
	check(bool(d.rest) and float(d.z) == 0.0, "after max_air a piece lies down on the floor")


func _test_shove_pushes_overlapping_pieces_apart() -> void:
	# Arrange: a moving piece driven into a resting one
	var debris := RigDebris.new(PHYS.duplicate())
	var still := _piece(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
	still.rest = true
	var moving := _piece(-3.0, 0.0, 0.0, 30.0, 0.0, 0.0)
	debris.add(still)
	debris.add(moving)
	# Act
	debris.step(DT)
	# Assert
	check(Vector2(float(moving.x), float(moving.y)).distance_to(Vector2.ZERO) > 3.0 and float(moving.vx) < 30.0, "the moving piece is pushed out and bounces off (x %.2f, vx %.1f)" % [float(moving.x), float(moving.vx)])
	check(float(still.x) == 0.0, "the resting piece stays put")


func _test_first_bounce_shatters_once() -> void:
	# Arrange: a brittle piece whose host hands back two shards at its first bounce
	var world := FakeWorld.new()
	world.shards = [_piece(0.0, 0.0, 1.0, 10.0, 0.0, 20.0), _piece(0.0, 0.0, 1.0, -10.0, 0.0, 20.0)]
	var debris := RigDebris.new(PHYS.duplicate(), world)
	var d := _piece(0.0, 0.0, 20.0, 0.0, 0.0, 0.0)
	d.brittle = true
	debris.add(d)
	# Act
	for i in range(120): debris.step(DT)
	# Assert
	check(world.landings == 1, "on_land runs once, at the first bounce (%d)" % world.landings)
	check(debris.pieces.size() == 2 and not debris.pieces.has(d), "its shards join and the broken piece goes (%d pieces)" % debris.pieces.size())


func _test_launch_is_deterministic_for_a_seed() -> void:
	# Arrange
	var phys := RigDebris.load_physics(GORE)
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 7
	b.seed = 7
	# Act
	var one := RigDebris.new(phys, null, a).launch(Vector2.RIGHT, Vector2(0, -10), 1.6, 1.0, true)
	var two := RigDebris.new(phys, null, b).launch(Vector2.RIGHT, Vector2(0, -10), 1.6, 1.0, true)
	var none := RigDebris.new(phys, null, a).launch(Vector2.ZERO, Vector2.ZERO, 1.0, 1.0, false)
	# Assert
	check(one == two, "the same seed launches the same way (%s)" % [one])
	check(float(one.vz) > 0.0 and absf(float(one.spin)) >= float(Array(phys.loose.spin)[0]), "a held item flies up and always turns over (%s)" % [one])
	check(absf(float(none.vx)) <= float(Array(phys.scatter)[0]) and absf(float(none.vy)) <= float(Array(phys.scatter)[1]) * float(phys.depth), "a blow without direction scatters within ragdoll.scatter")


func _test_gore_table_carries_every_rig_key() -> void:
	# Arrange / Act
	var phys := RigDebris.load_physics(GORE)
	var hero: Dictionary = phys.get("hero_weapon", {})
	# Assert
	var missing: Array = RIG_KEYS.filter(func(k: String) -> bool: return not phys.has(k))
	check(missing.is_empty(), "vfx_gore.json ragdoll has every key the rig debris runs on (missing %s)" % [missing])
	var hero_missing: Array = ["speed", "lift", "spin", "gravity", "bounce", "ground_keep", "spin_keep", "rest_vz", "bounces", "snap_turn", "snap_rate", "steps_per_s", "settle"].filter(func(k: String) -> bool: return not hero.has(k))
	check(hero_missing.is_empty(), "ragdoll.hero_weapon has every key of the hero's dropped weapon (missing %s)" % [hero_missing])
