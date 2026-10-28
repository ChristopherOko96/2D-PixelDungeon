extends SceneTree
## Body-part HP on the host (src/combat/body_parts.gd): parts add up to the
## enemy's HP, a vital part kills, a weapon disables its attack, the torso takes
## the legs with it, arms grow back, projectiles hit the part they cross, and
## the Leerenrufer's eye can only be hit while the beam runs.

const BodyParts = preload("res://src/combat/body_parts.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("BODY_PARTS_FAIL: ", description)

func _enemy(id: int, max_hp: float, pos := Vector2(400, 300), face := 1.0) -> Dictionary:
	return {"id": id, "pos": pos, "hp": max_hp, "max_hp": max_hp, "face": face, "radius": 13.0}

func _initialize() -> void:
	var parts = BodyParts.new()
	parts.reset(4242)
	# Skeleton weights: legs 2+2, torso 3, skull 3, sword 1 = 11.
	var skeleton := _enemy(1, 11.0)
	parts.attach(skeleton, "skeleton")
	check(parts.has_parts(skeleton) and is_equal_approx(float(skeleton.hp), 11.0), "attached parts add up to the enemy's HP")
	check(is_equal_approx(float(skeleton.parts.skull.hp), 3.0) and is_equal_approx(float(skeleton.parts.weapon.hp), 1.0), "each part gets its weight's share")
	var hit: Dictionary = parts.damage(skeleton, 1.0, "weapon")
	check(hit.destroyed and not hit.killed and "weapon" in skeleton.parts_lost, "the sword breaks off")
	check(not parts.can(skeleton, "attack") and parts.can(skeleton, "block"), "without its sword the skeleton cannot attack")
	check(is_equal_approx(float(skeleton.hp), 10.0), "a lost part's HP leaves the total")
	hit = parts.damage(skeleton, 5.0, "torso")
	check(hit.destroyed and "leg_l" in skeleton.parts_lost and "leg_r" in skeleton.parts_lost, "a broken torso takes both legs with it")
	check(is_equal_approx(parts.speed_scale(skeleton), 0.7), "a skull without torso hops at 70 % speed")
	check(is_equal_approx(float(skeleton.hp), 5.0), "the full damage counts against the total, even beyond the torso's own HP")
	hit = parts.damage(skeleton, 2.0, "torso")
	check(hit.part == "skull" and not hit.killed and is_equal_approx(float(skeleton.hp), 3.0) and is_equal_approx(float(skeleton.parts.skull.hp), 1.0), "a hit on a lost part lands on a living one")
	hit = parts.damage(skeleton, 1.0, "skull")
	check(hit.killed and float(skeleton.hp) == 0.0, "destroying the skull kills at once, with HP left in the total")

	# Legs: one lost slows to 60 %, both to 35 %.
	var walker := _enemy(2, 11.0)
	parts.attach(walker, "skeleton")
	parts.damage(walker, 2.0, "leg_l")
	check(is_equal_approx(parts.speed_scale(walker), 0.6) and is_equal_approx(float(walker.hp), 9.0), "one leg off: 60 % speed")
	parts.damage(walker, 2.0, "leg_r")
	check(is_equal_approx(parts.speed_scale(walker), 0.35) and not parts.damage(walker, 0.5, "torso").killed, "both legs off: it crawls on")
	# A huge hit stays lethal wherever it lands.
	var tank := _enemy(7, 11.0)
	parts.attach(tank, "skeleton")
	hit = parts.damage(tank, 999.0, "leg_l")
	check(hit.killed and float(tank.hp) == 0.0, "a 999 hit on a leg still kills")

	# Moderkoloss: the arm grows back after 6 s with half its HP.
	var brute := _enemy(3, 60.0)
	parts.attach(brute, "big_zombie")
	var arm_max: float = brute.parts.arm.max
	parts.damage(brute, arm_max, "arm")
	check(not parts.can(brute, "attack"), "without its arm the brute cannot slam")
	parts.step(brute, 5.9)
	check("arm" in brute.parts_lost, "the arm is still gone after 5.9 s")
	parts.step(brute, 0.2)
	check(not "arm" in brute.parts_lost and parts.can(brute, "attack") and is_equal_approx(float(brute.parts.arm.hp), arm_max * 0.5), "after 6 s the arm is back with half its HP")
	check(is_equal_approx(float(brute.hp), 60.0 - arm_max * 0.5), "regrown HP returns to the total")

	# Projectiles: a shot through the skull's height hits the skull (or the sword
	# drawn in front of it); a shot far below the feet misses.
	var target := _enemy(4, 11.0)
	parts.attach(target, "skeleton")
	var library = parts._library
	var rig: Dictionary = library.rig("skeleton")
	var skull_y: float = 300.0 + (float(rig.by_id.skull.center.y) - float(rig.center.y)) * 2.0
	var through := parts.segment_part(target, Vector2(300, skull_y), Vector2(500, skull_y), 3.0)
	check(through in ["skull", "weapon"], "a shot at head height hits the skull or the sword in front (%s)" % through)
	check(parts.segment_part(target, Vector2(300, 360), Vector2(500, 360), 3.0) == "", "a shot below the feet misses")
	check(parts.reach(target) > 13.0, "the broad phase covers the whole drawn figure")

	# Fallback without impact point is seeded and prefers non-vital parts.
	var a := BodyParts.new()
	var b := BodyParts.new()
	a.reset(7)
	b.reset(7)
	var ea := _enemy(5, 11.0)
	var eb := _enemy(5, 11.0)
	a.attach(ea, "skeleton")
	b.attach(eb, "skeleton")
	var same := true
	for i in range(6): same = same and a.damage(ea, 0.1).part == b.damage(eb, 0.1).part
	check(same, "status damage picks the same parts for the same seed")

	# Leerenrufer: the eye only counts during the beam.
	var boss := _enemy(6, 140.0)
	parts.attach(boss, "void")
	var void_rig: Dictionary = library.rig("void")
	var eye_y: float = 300.0 + (float(void_rig.eye_center.y) - float(void_rig.center.y) - float(void_rig.hover)) * float(void_rig.scale)
	var eye_x: float = 400.0 + (float(void_rig.eye_center.x) - float(void_rig.ground.x)) * float(void_rig.scale)
	check(parts.segment_part(boss, Vector2(eye_x - 1, eye_y), Vector2(eye_x + 1, eye_y), 2.0) == "core", "outside the beam a shot at the eye hits the core")
	boss.exposed_action = "beam"
	check(parts.segment_part(boss, Vector2(eye_x - 1, eye_y), Vector2(eye_x + 1, eye_y), 2.0) == "eye", "during the beam the eye is hit")
	parts.damage(boss, 20.0, "eye")
	check(not parts.can(boss, "beam") and parts.can(boss, "cast"), "a destroyed eye stops the beam, the salvo still works")

	# Pending impact parts are per enemy and used once.
	parts.set_pending(skeleton, "skull")
	check(parts.take_pending(walker) == "" and parts.take_pending(skeleton) == "skull" and parts.take_pending(skeleton) == "", "an impact part belongs to one enemy and is used once")
	print("BODY_PARTS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
