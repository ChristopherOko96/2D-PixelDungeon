extends SceneTree
## Big bosses have no one-shot body parts (src/combat/body_parts.gd, rigs.json
## "unbreakable"): Knochenkoloss, Moderkoloss and Frostleiche lose only their
## arm (and with it their attack); legs, head and body take damage but never
## break or kill, so only the full HP bar decides. The same holds for the
## Leerenrufer's core. Small enemies keep their vital skull.

const BodyParts = preload("res://src/combat/body_parts.gd")
const BRUTES := ["bone_colossus", "big_zombie", "frost_corpse"]
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("BOSS_PARTS_FAIL: ", description)


func _enemy(id: int, max_hp: float) -> Dictionary:
	return {"id": id, "pos": Vector2(400, 300), "hp": max_hp, "max_hp": max_hp, "face": 1.0, "radius": 13.0}


func _initialize() -> void:
	var parts = BodyParts.new()
	parts.reset(77)
	for rig: String in BRUTES:
		_test_brute_dies_only_by_its_hp_bar(parts, rig)
	_test_void_core_is_no_shortcut(parts)
	_test_small_enemies_keep_their_vital_skull(parts)
	print("BOSS_PARTS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_brute_dies_only_by_its_hp_bar(parts: RefCounted, rig: String) -> void:
	# Arrange: 120 HP split arm 20, legs 15 + 15, head 30, torso 40
	var boss := _enemy(1, 120.0)
	parts.attach(boss, rig)
	# Act: far more than the head's and the legs' own shares
	var head: Dictionary = parts.damage(boss, 45.0, "head")
	var leg: Dictionary = parts.damage(boss, 25.0, "leg_l")
	var arm: Dictionary = parts.damage(boss, 20.0, "arm")
	# Assert
	check(not head.killed and not head.destroyed and float(boss.hp) > 0.0, "%s: a head hit beyond its share does not kill" % rig)
	check(not leg.destroyed and not "leg_l" in boss.parts_lost and is_equal_approx(parts.speed_scale(boss), 1.0), "%s: legs take damage but never break" % rig)
	check(arm.destroyed and not parts.can(boss, "attack"), "%s: the arm breaks off and takes the attack with it" % rig)
	check(is_equal_approx(float(boss.hp), 30.0), "%s: every hit counts against the HP bar (%.1f)" % [rig, float(boss.hp)])
	# Act: the rest of the bar, on the head again
	var last: Dictionary = parts.damage(boss, 30.0, "head")
	check(last.killed and float(boss.hp) == 0.0, "%s: it falls when the HP bar is empty" % rig)


func _test_void_core_is_no_shortcut(parts: RefCounted) -> void:
	var boss := _enemy(2, 140.0)
	parts.attach(boss, "void")
	var share := float(boss.parts.core.max)
	var hit: Dictionary = parts.damage(boss, share + 10.0, "core")
	check(not hit.killed and float(boss.hp) > 0.0 and not "core" in boss.parts_lost, "Leerenrufer: emptying the core's share does not kill")
	var claw: Dictionary = parts.damage(boss, 30.0, "claw_l")
	check(claw.destroyed and not parts.can(boss, "summon"), "Leerenrufer: a claw still breaks off")


func _test_small_enemies_keep_their_vital_skull(parts: RefCounted) -> void:
	var skeleton := _enemy(3, 11.0)
	parts.attach(skeleton, "skeleton")
	var hit: Dictionary = parts.damage(skeleton, 3.0, "skull")
	check(hit.killed, "a skeleton still dies by its skull")
