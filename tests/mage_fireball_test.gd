extends SceneTree
## Focused release timing, cancellation, locked grip and fixed native core.
const Combat = preload("res://src/combat/talent_combat.gd")
const Fireball = preload("res://src/vfx/mage_fireball.gd")
const Look = preload("res://src/hero/hero_look.gd")
var checked := 0
var failed := 0

class Host extends RefCounted:
	var players := {1: {"hp": 8, "pos": Vector2(300, 240), "damage": 4.0}}
	var enemies: Array = []
	var bullets: Array = []
	var elements: Variant = null
	func _add_bullet(at: Vector2, velocity: Vector2, owner: int, damage: float, extra: Dictionary) -> Dictionary:
		var shot := {"pos": at, "velocity": velocity, "owner": owner, "damage": damage}
		shot.merge(extra)
		bullets.append(shot)
		return shot

func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failed += 1
		printerr("FIREBALL_FAIL: ", label)

func _initialize() -> void:
	var host := Host.new()
	var tc := Combat.new()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/talents.json"))
	tc.bind(host, data)
	tc.set_build(1, {"class": "mage", "level": 3, "ranks": {"fire_1": 1}, "bar": ["fire_1"]})
	var mana := float(tc.runtime(1).res)
	check(tc.cast(1, "fire_1", {"aim": Vector2.RIGHT}), "accepted learned cast")
	check(host.bullets.is_empty(), "no projectile before visible release")
	check(is_equal_approx(float(tc.runtime(1).res), mana - 14.0), "mana paid once at preparation")
	check(not tc.cast(1, "fire_1"), "duplicate input rejected")
	tc.step(0.17)
	check(host.bullets.is_empty(), "still preparing before 180ms")
	tc.step(0.01)
	check(host.bullets.size() == 1, "one projectile at 180ms")
	if not host.bullets.is_empty():
		check(is_equal_approx(float(host.bullets[0].damage), 5.0), "rank-one damage unchanged")
		check(host.bullets[0].velocity == Vector2(440, 0), "locked aim and flight speed")
	tc.step(0.2)
	check(host.bullets.size() == 1, "release cannot repeat")
	for cancel in ["death", "room"]:
		host.bullets.clear()
		host.players[1].hp = 8
		tc.reset()
		tc.set_build(1, {"class": "mage", "level": 3, "ranks": {"fire_1": 1}, "bar": ["fire_1"]})
		tc.cast(1, "fire_1")
		if cancel == "death": host.players[1].hp = 0
		else:
			tc.room_changed()
			check(tc.events.is_empty(), "room change removes pending cast presentation")
		tc.step(0.3)
		check(host.bullets.is_empty(), "pending cast cancelled on " + cancel)
	var look := Look.new()
	host.players[1].hp = 8
	tc.reset()
	tc.set_build(1, {"class": "mage", "level": 3, "ranks": {"fire_1": 1}, "bar": ["fire_1"]})
	host.bullets.clear()
	tc.runtime(1).echo = 25.0
	tc.cast(1, "fire_1", {"aim": Vector2.RIGHT})
	tc.step(0.18)
	tc.step(0.34)
	check(host.bullets.size() == 1, "echo waits 350ms after release")
	tc.step(0.02)
	check(host.bullets.size() == 2, "echo repeats once after release")
	if host.bullets.size() == 2: check(is_equal_approx(float(host.bullets[1].damage), 1.25), "echo scales original damage")
	tc.step(0.4)
	check(host.bullets.size() == 2, "echo does not recurse")
	var event := {"kind": "cast", "talent": "fire_1", "owner": 1, "span": 0.5, "life": 0.4, "windup": 0.18, "angle": 0.0}
	look.observe_fireball("p1", 1, [event], 10.0)
	check(look.casting_aim("p1", Vector2.LEFT, 10.0) == Vector2.RIGHT, "late snapshot keeps locked hand direction")
	look.observe_fireball("p1", 1, [], 10.1)
	check(look.casting_aim("p1", Vector2.LEFT, 10.1) == Vector2.LEFT, "room event removal clears pose")
	var core: Array = []
	for frame in range(4):
		var shape := Fireball.cells(frame)
		var current: Array = []
		for i in range(0, shape.size(), 2):
			if Vector2(shape[i]).length() <= 5.0: current.append(shape[i])
		if frame == 0: core = current
		check(current == core, "flight core stays fixed frame %d" % frame)
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		for age in [0.0, 0.09, 0.18, 0.3, 0.45]:
			var pose := Fireball.pose(age, 0.18, direction)
			check(float(pose.side) == (-1.0 if direction.x < -0.1 else 1.0), "constant grip side")
	print("MAGE_FIREBALL checked=%d failures=%d" % [checked, failed])
	quit(1 if failed else 0)
