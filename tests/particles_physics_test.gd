extends SceneTree
## Pixel particle physics and floor marks (src/vfx/particles.gd,
## assets/data/vfx_particles.json): particles fall, bounce off walls and never
## pass through them; debris settles as floor pixels, sparks leave nothing;
## liquid splats stop at walls while cracks mark the wall itself.

const Particles = preload("res://src/vfx/particles.gd")
const STEP := 1.0 / 60.0
## A 10 x 5 cell floor (320 x 160 px); everything else counts as wall.
const FLOOR_SIZE := Vector2i(10, 5)
var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("PARTICLES_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _room() -> Dictionary:
	var tiles: Array = []
	for y in range(FLOOR_SIZE.y):
		for x in range(FLOOR_SIZE.x): tiles.append({"x": x, "y": y, "layer": "floor"})
	return {"id": "test_room", "painted_tiles": tiles}


func _fresh() -> Particles:
	var particles := Particles.new()
	particles.set_layout(_room(), "test")
	return particles


func _run() -> void:
	_test_debris_bounces_off_a_wall_and_settles_on_the_floor()
	_test_spark_fades_without_a_mark()
	_test_particle_falls_to_the_floor()
	_test_splat_stops_at_the_wall()
	_test_crack_marks_the_wall()
	_test_clear_removes_marks()
	_test_without_a_room_particles_fly_freely()
	_test_kick_lifts_loose_debris_again()
	_test_pool_creeps_then_dries_darker()
	_test_pool_never_creeps_into_a_wall()
	_test_embers_smoke_and_turn_to_soot()
	_test_frost_melts_to_water_that_dries()
	_test_kicked_frost_still_melts()
	_test_frost_on_debris_still_melts()
	print("PARTICLES checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _step(particles: Particles, seconds: float) -> void:
	for frame in range(int(seconds / STEP)): particles.update(STEP)


## Painted floor pixels inside `area` (world px).
func _painted(particles: Particles, area: Rect2) -> int:
	var total := 0
	for y in range(int(area.position.y), int(area.end.y), 2):
		for x in range(int(area.position.x), int(area.end.x), 2):
			if particles.mark_at(Vector2(x, y)).a > 0.05: total += 1
	return total


func _test_kick_lifts_loose_debris_again() -> void:
	# Arrange: debris dropped in the middle of the floor and left to settle.
	var particles := _fresh()
	particles.burst(Vector2(160, 70), Color.GRAY, 12, 60.0, 0.4, Vector2.ZERO, PI, 2.0, 5.0, "debris", 4.0)
	_step(particles, 3.0)
	var lying := particles.loose_count()
	# Act: a blast right there.
	particles.kick(Vector2(160, 74), 60.0, 1.0)
	# Assert
	check(lying > 0, "settled debris lies loose on the floor (%d pixels)" % lying)
	check(particles.loose_count() == 0 and particles.count() > 0, "a blast throws the loose pixels back into the air")


func _test_pool_creeps_then_dries_darker() -> void:
	# Arrange
	var particles := _fresh()
	var area := Rect2(100, 40, 120, 80)
	particles.splat(Vector2(160, 80), Color(0.8, 0.1, 0.1), 0.65, 8.0, Vector2.RIGHT)
	var fresh := _painted(particles, area)
	var wet := particles.mark_at(Vector2(160, 80))
	# Act
	_step(particles, 4.0)
	var spread := _painted(particles, area)
	_step(particles, 6.0)
	# Assert
	check(spread > fresh, "a pool keeps creeping outwards (%d -> %d pixels)" % [fresh, spread])
	check(particles.pool_count() == 0, "a pool stops and dries")
	check(particles.mark_at(Vector2(160, 80)).r < wet.r - 0.1, "a dried pool is darker than a fresh one")


func _test_pool_never_creeps_into_a_wall() -> void:
	# Arrange: a pool right at the east wall, splashed towards it.
	var particles := _fresh()
	particles.splat(Vector2(312, 80), Color.RED, 0.6, 10.0, Vector2.RIGHT)
	# Act
	_step(particles, 6.0)
	# Assert
	check(_painted(particles, Rect2(320, 40, 40, 80)) == 0, "liquid never creeps into the wall")


func _test_embers_smoke_and_turn_to_soot() -> void:
	# Arrange
	var particles := _fresh()
	particles.embers(Vector2(160, 80), 8.0, 6)
	var glowing := particles.ember_count()
	# Act
	_step(particles, 1.5)
	var smoking := particles.count()
	_step(particles, 4.0)
	# Assert
	check(glowing == 6, "fire leaves embers on the floor")
	check(smoking > 0, "glowing embers give off smoke")
	check(particles.ember_count() == 0 and _painted(particles, Rect2(140, 64, 40, 32)) > 0, "burnt-out embers leave soot")


func _test_frost_melts_to_water_that_dries() -> void:
	# Arrange
	var particles := _fresh()
	var area := Rect2(140, 64, 40, 32)
	var water := Color(str(Particles.settings().frost.water))
	particles.frost(Vector2(160, 80), 6.0, 10, Color(0.8, 0.95, 1.0, 0.8))
	var frosted := _painted(particles, area)
	var water_at_start := _coloured(particles, area, water)
	# Act
	_step(particles, 10.5)
	var water_later := _coloured(particles, area, water)
	_step(particles, 11.0)
	# Assert
	check(frosted > 0 and water_at_start == 0, "frost crystals lie on the floor, no water yet")
	check(water_later > 0, "frost melts to water (%d water pixels)" % water_later)
	check(_painted(particles, area) == 0, "the water dries away")


## Regression: a blast (or a death nearby) threw frost pixels as plain debris,
## and they lay on the floor as frost for good instead of melting.
func _test_kicked_frost_still_melts() -> void:
	# Arrange: frost crystals, then a weak blast right on them.
	var particles := _fresh()
	particles.frost(Vector2(160, 80), 4.0, 8, Color(0.8, 0.95, 1.0, 0.8))
	particles.kick(Vector2(160, 80), 12.0, 0.3)
	# Act: long enough for anything frozen to melt (melt_after max 10 s).
	_step(particles, 14.0)
	# Assert: no bright frost pixel is left anywhere on the floor.
	var frosty := 0
	for y in range(0, 160, 2):
		for x in range(0, 320, 2):
			var here := particles.mark_at(Vector2(x, y))
			if here.a > 0.05 and here.b > 0.75 and here.b >= here.r: frosty += 1
	check(frosty == 0, "frost thrown by a blast still melts (%d frost pixels left)" % frosty)


## Regression: frost blended over bone chips no longer looked like frost and
## stayed pale on the floor for good instead of melting.
func _test_frost_on_debris_still_melts() -> void:
	# Arrange: tan bone chips, frost on top of them.
	var particles := _fresh()
	var area := Rect2(140, 64, 40, 32)
	particles.scatter(Vector2(160, 80), Color(0.8, 0.7, 0.6, 0.95), 6.0, 40)
	particles.frost(Vector2(160, 80), 6.0, 30, Color(0.8, 0.95, 1.0, 0.55))
	# Act
	_step(particles, 11.0)
	# Assert: no pale frost blend is left (water or bare chips only).
	var pale := 0
	for y in range(int(area.position.y), int(area.end.y), 2):
		for x in range(int(area.position.x), int(area.end.x), 2):
			var here := particles.mark_at(Vector2(x, y))
			if here.a > 0.05 and here.g > 0.75 and here.b > 0.7: pale += 1
	check(pale == 0, "frost on top of debris still melts (%d pale pixels left)" % pale)


## Floor pixels inside `area` with the colour `color` (alpha ignored).
func _coloured(particles: Particles, area: Rect2, color: Color) -> int:
	var total := 0
	for y in range(int(area.position.y), int(area.end.y), 2):
		for x in range(int(area.position.x), int(area.end.x), 2):
			var here := particles.mark_at(Vector2(x, y))
			if here.a > 0.05 and absf(here.r - color.r) + absf(here.g - color.g) + absf(here.b - color.b) < 0.04: total += 1
	return total


func _test_debris_bounces_off_a_wall_and_settles_on_the_floor() -> void:
	# Arrange: debris thrown hard at the east wall (x = 320).
	var particles := _fresh()
	particles.emit(Vector2(290, 80), Vector2(900, 0), Color.RED, 0.6, "debris", 2.0, 10.0, 60.0, 0.0)
	var farthest := 0.0
	var last := Vector2.ZERO
	# Act
	for frame in range(240):
		if particles.count() == 0: break
		last = particles._particles[0].pos
		farthest = maxf(farthest, last.x)
		particles.update(STEP)
	# Assert
	check(farthest < 320.0, "debris never passes the wall (reached x=%.1f)" % farthest)
	check(particles.count() == 0, "debris comes to rest and leaves the live particles")
	check(particles.mark_at(last).a > 0.0, "resting debris stays as a floor pixel")
	check(last.x < 300.0, "the wall bounced the debris back (rest x=%.1f)" % last.x)


func _test_spark_fades_without_a_mark() -> void:
	# Arrange
	var particles := _fresh()
	particles.emit(Vector2(100, 80), Vector2(120, 0), Color.YELLOW, 0.3, "spark", 2.0, 10.0, 40.0, 4.0)
	# Act
	for frame in range(120): particles.update(STEP)
	# Assert
	check(particles.count() == 0 and particles.chunk_count() == 0, "sparks fade and leave no floor mark")


func _test_particle_falls_to_the_floor() -> void:
	# Arrange: dropped from 20 px without upward speed.
	var particles := _fresh()
	particles.emit(Vector2(100, 60), Vector2.ZERO, Color.WHITE, 2.0, "spark", 2.0, 20.0, 0.0, 0.0)
	var start := float(particles._particles[0].z)
	# Act
	for frame in range(90): particles.update(STEP)
	# Assert
	check(start == 20.0 and float(particles._particles[0].z) == 0.0, "gravity brings a particle down to the floor (it bounces, then rests)")


func _test_splat_stops_at_the_wall() -> void:
	# Arrange
	var particles := _fresh()
	# Act: a big splat right at the east wall.
	particles.splat(Vector2(314, 80), Color.RED, 0.6, 14.0)
	# Assert
	check(particles.mark_at(Vector2(312, 80)).a > 0.0, "the splat covers the floor next to the wall")
	check(particles.mark_at(Vector2(324, 80)).a == 0.0, "the splat stops at the wall")
	check(particles.stain_count() == 1, "the splat is counted as one floor mark")


func _test_crack_marks_the_wall() -> void:
	# Arrange
	var particles := _fresh()
	# Act: something struck the east wall; the normal points back to the floor.
	particles.crack(Vector2(320, 80), Vector2.LEFT)
	# Assert
	var in_wall := false
	for y in range(64, 98, 2):
		for x in range(320, 334, 2):
			if particles.mark_at(Vector2(x, y)).a > 0.0: in_wall = true
	check(in_wall, "a crack runs into the wall that was struck")


func _test_clear_removes_marks() -> void:
	# Arrange
	var particles := _fresh()
	particles.splat(Vector2(100, 80), Color.RED, 0.6, 10.0)
	particles.emit(Vector2(100, 80), Vector2(50, 0), Color.RED, 1.0)
	# Act
	particles.clear()
	# Assert
	check(particles.count() == 0 and particles.chunk_count() == 0 and particles.stain_count() == 0, "a new room starts without particles or marks")


func _test_without_a_room_particles_fly_freely() -> void:
	# Arrange: no layout (editor previews, old tests) means no walls.
	var particles := Particles.new()
	particles.emit(Vector2(100, 80), Vector2(600, 0), Color.WHITE, 1.0, "dust", 2.0, 10.0, 0.0, 0.0)
	# Act
	for frame in range(18): particles.update(STEP)
	# Assert
	check(float(particles._particles[0].pos.x) > 250.0, "without a room nothing blocks a particle")
