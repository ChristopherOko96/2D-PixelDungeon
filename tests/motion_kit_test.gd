extends SceneTree
## The motion kit (src/physics_kit/motion_kit.gd, MotionKit; BAUPLAN M1b) on a
## fake host and fake walls, no game:
## - the hero's knockback: speed by kind from the world's table, a mob's
##   share, squashed on the floor's depth, eased out over its time (about
##   speed x time / 3 px), never a step longer than knock.step_max (no
##   tunnelling), a wall stopping one axis, the state ended when its time is up;
## - walking: firm grip takes the wanted velocity at once, low grip keeps the
##   momentum, a wall zeroes the blocked axis, the void's pull;
## - a monster's step: its push decays by push.decay a frame, walls stop each
##   axis, the velocity it moved with;
## - the skid timer, the grips from the data, ElementRules forwarding.
## Values come from assets/data/physics_motion.json. Deterministic; writes nothing.

const ElementRules = preload("res://src/combat/element_rules.gd")
const DT := 1.0 / 60.0
## A world's knock table as the worlds keep it (speeds px/s by kind).
const TABLE := {"time": 0.22, "mob_scale": 0.7, "slam": 620, "contact": 300, "huge": 40000}
var checked := 0
var failures: Array[String] = []


## A hero on open floor with a wall from `wall_x` on (world px, his feet).
class FakeHost extends "res://src/physics_kit/motion_host.gd":
	var x := 0.0
	var y := 0.0
	var vel := Vector2.ZERO
	var knock: Dictionary = {}
	var wall_x := INF
	var asked := 0

	func hero_x() -> float:
		return x

	func hero_y() -> float:
		return y

	func place_hero(nx: float, ny: float) -> void:
		x = nx
		y = ny

	func hero_blocked(bx: float, _by: float) -> bool:
		asked += 1
		return bx >= wall_x

	func hero_velocity() -> Vector2:
		return vel

	func set_hero_velocity(v: Vector2) -> void:
		vel = v

	func knock_state() -> Dictionary:
		return knock

	func set_knock_state(k: Dictionary) -> void:
		knock = k


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("MOTION_KIT_FAIL: ", label)


func _initialize() -> void:
	seed(7)
	test_knock_start()
	test_knock_eases_out_and_ends()
	test_knock_never_tunnels()
	test_knock_wall_stops_one_axis()
	test_walk_grip_and_pull()
	test_body_push_and_walls()
	test_skid_and_data()
	print("MOTION_KIT checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _kit(host: FakeHost) -> MotionKit:
	return MotionKit.new(host)


func _run_knock(kit: MotionKit, host: FakeHost, frames: int) -> Array:
	var steps: Array = []
	for i in range(frames):
		var before := Vector2(host.x, host.y)
		kit.step_knock(DT)
		steps.append(Vector2(host.x, host.y) - before)
		if host.knock.is_empty():
			break
	return steps


func test_knock_start() -> void:
	var host := FakeHost.new()
	var kit := _kit(host)
	var spec: Dictionary = kit.cfg.knock
	check(kit.knock_hero(Vector2(-50, 0), "slam", TABLE, false), "a known kind pushes")
	var v: Vector2 = host.knock.v
	check(is_equal_approx(v.length(), float(TABLE.slam)) and v.x > 0.0, "away from the blow at the kind's speed")
	check(is_equal_approx(float(host.knock.T), float(TABLE.time)) and float(host.knock.t) == 0.0, "its time from the world's table")
	host.knock = {}
	kit.knock_hero(Vector2(0, -50), "slam", TABLE, false)
	var down: Vector2 = host.knock.v
	check(is_equal_approx(down.y, float(TABLE.slam) * float(spec.squash[1])), "squashed on the floor's depth")
	host.knock = {}
	kit.knock_hero(Vector2(-50, 0), "slam", TABLE, true)
	check(is_equal_approx((host.knock.v as Vector2).length(), float(TABLE.slam) * float(TABLE.mob_scale)), "a mob's blow pushes mob_scale of it")
	host.knock = {}
	check(not kit.knock_hero(Vector2(-50, 0), "nothing", TABLE, false) and host.knock.is_empty(), "an unknown kind pushes nothing")
	var bare := kit.knock_start(Vector2.ZERO, Vector2(-1, 0) * 30.0, "slam", {"slam": 100}, true)
	check(is_equal_approx(float(bare.T), float(spec.time)) and is_equal_approx((bare.v as Vector2).length(), 100.0 * float(spec.mob_scale)), "without time and mob_scale in the table the data's defaults hold")
	var on_top := kit.knock_start(Vector2(5, 5), Vector2(5.2, 5.1), "slam", TABLE, false)
	check((on_top.v as Vector2).length() > 1.0, "right on top of the blow it still flies off somewhere")


func test_knock_eases_out_and_ends() -> void:
	var host := FakeHost.new()
	var kit := _kit(host)
	kit.knock_hero(Vector2(-50, 0), "contact", TABLE, false)
	var steps := _run_knock(kit, host, 200)
	check(host.knock.is_empty(), "the knock ends when its time is up")
	var frames := steps.size()
	check(absi(frames - int(ceil(float(TABLE.time) / DT))) <= 1, "it lasts its time")
	var falling := true
	for i in range(1, frames - 1):
		falling = falling and (steps[i] as Vector2).length() <= (steps[i - 1] as Vector2).length() + 0.0001
	check(falling, "its speed only eases out")
	var expected := float(TABLE.contact) * float(TABLE.time) / 3.0
	check(absf(host.x - expected) < expected * 0.15 and is_zero_approx(host.y), "it covers about speed x time / 3 px")


func test_knock_never_tunnels() -> void:
	var host := FakeHost.new()
	var kit := _kit(host)
	var longest_allowed := float(kit.cfg.knock.step_max)
	kit.knock_hero(Vector2(-50, 0), "huge", TABLE, false)
	var steps := _run_knock(kit, host, 200)
	var longest := 0.0
	for s: Vector2 in steps:
		longest = maxf(longest, s.length())
	check(longest <= longest_allowed + 0.0001 and longest > longest_allowed * 0.99, "no step is longer than knock.step_max")
	host.x = 0.0
	host.y = 0.0
	host.wall_x = longest_allowed * 1.5
	kit.knock_hero(Vector2(-50, 0), "huge", TABLE, false)
	_run_knock(kit, host, 200)
	check(host.x < host.wall_x, "a thin wall half a step further stops it (no tunnelling)")


func test_knock_wall_stops_one_axis() -> void:
	var host := FakeHost.new()
	var kit := _kit(host)
	host.wall_x = 10.0
	kit.knock_hero(Vector2(-40, -40), "slam", TABLE, false)
	_run_knock(kit, host, 200)
	check(host.x < 10.0 and host.y > 20.0, "the wall stops x, he slides on along y")


func test_walk_grip_and_pull() -> void:
	var host := FakeHost.new()
	var kit := _kit(host)
	var want := Vector2(300, 0)
	kit.step_hero(want, MotionKit.FIRM, Vector2.ZERO, DT)
	check(host.vel == want and is_equal_approx(host.x, want.x * DT), "firm grip takes the wanted velocity at once")
	kit.step_hero(Vector2.ZERO, MotionKit.FIRM, Vector2.ZERO, DT)
	check(host.vel == Vector2.ZERO, "and stops at once")
	var ice := float(kit.grip("glaze"))
	host.vel = want
	for i in range(60):
		kit.step_hero(Vector2.ZERO, ice, Vector2.ZERO, DT)
	check(is_equal_approx(host.vel.x, want.x * pow(ice, 60.0 * DT)), "on ice the momentum left after a second is the grip")
	host.vel = want
	host.wall_x = host.x + 1.0
	kit.step_hero(want, MotionKit.FIRM, Vector2(0, 30), DT)
	check(host.vel.x == 0.0 and host.vel.y == 0.0 and host.x < host.wall_x, "a wall zeroes the blocked axis")
	check(is_equal_approx(host.y, 30.0 * DT), "the pull moves him")
	var pull := MotionKit.pull(36.0, Vector2(10, 0), Vector2.ZERO)
	check(pull.is_equal_approx(Vector2(-36, 0)), "the pull points to the centre at its strength")
	check(MotionKit.pull(36.0, Vector2(0.5, 0), Vector2.ZERO) == Vector2.ZERO and MotionKit.pull(0.0, Vector2(10, 0), Vector2.ZERO) == Vector2.ZERO, "no pull at the centre or without strength")
	check(ElementRules.slide(Vector2(10, 0), Vector2.ZERO, 0.35, DT) == MotionKit.slide(Vector2(10, 0), Vector2.ZERO, 0.35, DT), "ElementRules.slide forwards")
	check(ElementRules.pull({"pull": 36}, Vector2(10, 0), Vector2.ZERO) == pull, "ElementRules.pull forwards the rule's strength")


func test_body_push_and_walls() -> void:
	var kit := MotionKit.new()
	var decay := float(kit.cfg.push.decay)
	var open := func(_x: float, _y: float) -> bool: return false
	var r: Dictionary = kit.step_body(Vector2.ZERO, Vector2.ZERO, Vector2(60, 0), MotionKit.FIRM, Vector2.ZERO, Vector2(0, 600), DT, open)
	check((r.v as Vector2).is_equal_approx(Vector2(60, 600)), "it moves with its walk plus its push")
	check((r.p as Vector2).is_equal_approx(Vector2(60, 600) * DT), "axis by axis on open floor")
	check((r.push as Vector2).is_equal_approx(Vector2(0, 600) * decay), "the push decays by push.decay a frame")
	check(r.vel == Vector2(60, 0), "firm grip keeps the wanted velocity")
	var wall := func(x: float, _y: float) -> bool: return x > 0.5
	var w: Dictionary = kit.step_body(Vector2.ZERO, Vector2.ZERO, Vector2(600, 600), MotionKit.FIRM, Vector2.ZERO, Vector2.ZERO, DT, wall)
	check(is_zero_approx((w.p as Vector2).x) and is_equal_approx((w.p as Vector2).y, 600.0 * DT), "a wall stops one axis, it slides along it")
	var slick: Dictionary = kit.step_body(Vector2.ZERO, Vector2(200, 0), Vector2.ZERO, 0.35, Vector2.ZERO, Vector2.ZERO, DT, open)
	check((slick.vel as Vector2).x > 190.0 and (slick.vel as Vector2).x < 200.0, "on blood it keeps most of its momentum")
	var corner := func(x: float, y: float) -> bool: return x > 0.5 and y > 0.5
	var c: Dictionary = kit.step_body(Vector2.ZERO, Vector2.ZERO, Vector2(60, 60), MotionKit.FIRM, Vector2.ZERO, Vector2.ZERO, DT, corner)
	check((c.p as Vector2).is_equal_approx(Vector2(1, 1)) or (c.p as Vector2).is_equal_approx(Vector2(1, 0)), "x moves first, then y from where x left it")
	check(MotionKit.integrate(Vector2.ZERO, Vector2(60, 60), DT, corner) == Vector2(1, 0), "integrate tests y from the new x")


func test_skid_and_data() -> void:
	var kit := MotionKit.new()
	var spec: Dictionary = kit.cfg.skid
	var slow := 0
	for i in range(60):
		slow += 1 if kit.skid(float(spec.speed) * 0.5, DT) else 0
	check(slow == 0, "no skid at a walk")
	var fast := 0
	for i in range(60):
		fast += 1 if kit.skid(float(spec.speed) * 2.0, DT) else 0
	check(absi(fast - int(1.0 / float(spec.every))) <= 1, "a skid every skid.every s at speed")
	check(kit.grip("slip") > 0.0 and kit.grip("slip") < 1.0 and kit.grip("medium") > 0.0 and kit.grip("glaze") > 0.0, "the grips come from the data")
	check(kit.grip("no such") == MotionKit.FIRM, "an unknown grip is firm floor")
	var empty := MotionKit.new(MotionKit.Host.new())
	empty.step_knock(DT)
	empty.step_hero(Vector2(10, 0), MotionKit.FIRM, Vector2.ZERO, DT)
	check(true, "an empty host (the contract's defaults) runs without errors")
