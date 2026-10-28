extends SceneTree
## Hell monster rules (src/hell/hell_monster_rules.gd): the ready attack that has
## waited longest goes first and a passive trail never does, first cooldowns use
## `first` when set, a monster cannot be hit while it arrives, transforms, dies,
## burrows or flies, Ignaroth's phases lead 1 -> 2 -> 3 -> 4 and the fourth dies,
## HP, animation frames, shot colours, echo attacks and the boss-bar status.

const Rules = preload("res://src/hell/hell_monster_rules.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_MONSTER_RULES_FAIL: ", description)


func _attack(kind: String, every: float, extra := {}) -> Dictionary:
	var a := {"id": kind, "kind": kind, "every": every}
	a.merge(extra, true)
	return a


func _lord(phase: int, anims: Dictionary) -> Dictionary:
	return {"kind": "lord", "phase": phase, "anims": anims}


func _mob(fields := {}) -> Dictionary:
	var m := {"intro": null, "trans": null, "dying": null, "burrowed": false, "alt": 0.0}
	m.merge(fields, true)
	return m


func _initialize() -> void:
	# pick_attack
	var attacks := [_attack("bolt", 2.0), _attack("slam", 3.0, {"range": 300.0}), _attack("trail", 0.0)]
	check(Rules.pick_attack(attacks, [0.5, 0.5, -1.0], 200.0) == -1, "no attack is ready while every cooldown runs (trail never counts)")
	check(Rules.pick_attack(attacks, [-0.1, -2.0, -9.0], 200.0) == 1, "of two ready attacks the one that waited longest goes first")
	check(Rules.pick_attack(attacks, [-0.1, -2.0, -9.0], 500.0) == 0, "an attack out of range is skipped")
	check(Rules.pick_attack(attacks, [1.0, 1.0, -9.0], 100.0) == -1, "a passive trail is never chosen")
	# cooldowns
	check(is_equal_approx(Rules.first_cooldown(_attack("echoes", 17.0, {"first": 4.0}), 0.9), 4.0), "`first` sets the first cooldown")
	check(is_equal_approx(Rules.first_cooldown(_attack("bolt", 10.0), 0.0), 3.5), "without `first` the first cooldown is 35 % of every at roll 0")
	check(is_equal_approx(Rules.first_cooldown(_attack("bolt", 10.0), 1.0), 8.5), "and 85 % at roll 1")
	check(is_equal_approx(Rules.next_cooldown(_attack("bolt", 4.0), true, 0.9), 4.0), "a boss keeps its rhythm")
	check(is_equal_approx(Rules.next_cooldown(_attack("bolt", 4.0), false, 1.0), 4.8), "a mob varies up to 120 %")
	# immunity
	check(not Rules.is_immune(_mob(), 30.0), "a monster on the ground can be hit")
	check(Rules.is_immune(_mob({"intro": {"t": 0.0}}), 30.0), "not during the arrival")
	check(Rules.is_immune(_mob({"trans": {"t": 0.0}}), 30.0), "not while transforming")
	check(Rules.is_immune(_mob({"dying": {"t": 0.0}}), 30.0), "not while dying")
	check(Rules.is_immune(_mob({"burrowed": true}), 30.0), "not while burrowed")
	check(Rules.is_immune(_mob({"alt": 31.0}), 30.0) and not Rules.is_immune(_mob({"alt": 30.0}), 30.0), "not above the flight threshold, only above it")
	# Ignaroth's phases
	var defs := {"drache1": _lord(1, {}), "drache2": _lord(2, {}), "drache3": _lord(3, {}), "drache4": _lord(4, {}), "glutimp": {"kind": "mob", "anims": {}}}
	check(Rules.next_form(defs, "drache1") == "drache2", "phase 1 turns into phase 2")
	check(Rules.next_form(defs, "drache2") == "drache3", "phase 2 turns into phase 3")
	check(Rules.next_form(defs, "drache3") == "drache4", "phase 3 turns into phase 4")
	check(Rules.next_form(defs, "drache4") == "", "phase 4 has no next form and dies")
	check(Rules.next_form(defs, "glutimp") == "", "a mob never transforms")
	# HP
	check(is_equal_approx(Rules.spawn_hp({"hp": 5}, false, 90.0, 1.32), 7.0), "a mob's HP is its own HP times the floor toughness, rounded")
	check(is_equal_approx(Rules.spawn_hp({"hpMul": 1}, true, 90.0, 1.32), 90.0), "a boss takes the floor's boss HP")
	check(is_equal_approx(Rules.spawn_hp({}, false, 90.0, 1.0), 1.0), "a form without own HP (an echo) starts at 1 before its share is set")
	# animation
	var def := {"anims": {"idle": {"row": 0, "frames": 8}, "cast": {"row": 3, "frames": 8}, "death": {"row": 5, "frames": 6}}}
	check(Rules.frame_of(def, "cast", 0.0) == Vector2i(0, 3), "the first frame of cast sits in its own row")
	check(Rules.frame_of(def, "cast", 1.0) == Vector2i(13 % 8, 3), "8-frame attacks run at 13 frames per second and loop")
	check(Rules.frame_of(def, "fly", 0.0).y == 0, "a missing animation falls back to idle")
	check(is_equal_approx(Rules.anim_fps(8, "idle"), 9.0) and is_equal_approx(Rules.anim_fps(8, "fly"), 11.0), "idle breathes slower, flight beats at 11")
	check(is_equal_approx(Rules.anim_fps(4, "run"), 10.0), "classic 4-frame sets keep 10 frames per second")
	check(Rules.act_anim("ring", def) == "cast" and Rules.act_anim("bolt", def) == "attack", "spells use the cast pose, strikes the attack pose")
	check(Rules.act_anim("ring", {"anims": {"idle": {}}}) == "attack", "without a cast pose a spell uses attack")
	# colours, echoes, status
	check(Rules.shot_color("drache4", false) == "void" and Rules.shot_color("drache1", true) == "void", "the last form and every echo burn violet")
	check(Rules.shot_color("seelenhirte", false) == "soul" and Rules.shot_color("drache3", false) == "fire", "soul fire is green, the rest orange")
	var kept := Rules.echo_attacks([_attack("bolt", 1.0), _attack("burrow", 1.0), _attack("flight", 1.0), _attack("slam", 1.0)], ["bolt", "slam"])
	check(kept.size() == 2 and kept[0].kind == "bolt" and kept[1].kind == "slam", "echoes keep only their strikes and shots")
	check(Rules.boss_status(_mob({"alt": 300.0}), 30.0) == " · in der Luft", "the boss bar says when he flies")
	check(Rules.boss_status(_mob({"trans": {}}), 30.0) == " · verwandelt sich", "and when he transforms")
	check(Rules.boss_status(_mob(), 30.0) == "", "and nothing while he fights on the ground")
	check(is_equal_approx(Rules.smooth(-1.0), 0.0) and is_equal_approx(Rules.smooth(0.5), 0.5) and is_equal_approx(Rules.smooth(2.0), 1.0), "smoothstep is clamped")
	check(is_equal_approx(Rules.angle_gap(0.1, TAU - 0.1), 0.2), "angle gaps wrap around")
	print("HELL_MONSTER_RULES checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
