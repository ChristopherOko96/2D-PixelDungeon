extends SceneTree
## Talent points, tier locks, ultimates and their stages, reset, EXP, the profile
## file and soul shard drops (src/progress/*.gd, assets/data/talents.json).

const Profile = preload("res://src/progress/profile.gd")
const Rules = preload("res://src/progress/talent_rules.gd")
const Drops = preload("res://src/progress/soul_drops.gd")
const FIGHT := {"present": true, "seconds": 60.0, "damage_share": 0.5}
var checked := 0
var failures: Array[String] = []
var d: Dictionary

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("TALENT_PROGRESS_FAIL: ", label)

func _initialize() -> void:
	d = Profile.data()
	check(d.talents.size() == 168, "168 talents are defined (4 classes x 3 branches x 14)")
	_test_data_is_complete()
	_test_points_per_level()
	_test_tier_locks()
	_test_ultimate_needs_shards_and_is_unique()
	_test_soul_tiers_and_reset()
	_test_one_branch_per_character()
	_test_old_profiles_move_over()
	_test_ultimate_stages()
	_test_rank_down_keeps_build_valid()
	_test_exp_levels()
	_test_profile_save_and_sanitize()
	_test_drop_chances()
	_test_shards_per_boss_and_nightmare_first()
	_test_ultimate_pace()
	_test_no_farming_or_duplicates()
	print("TALENT_PROGRESS checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _profile(level: int, class_id := "swordsman") -> Dictionary:
	var profile := Profile.fresh(d)
	Profile.class_state(profile, class_id).level = level
	return profile


func _fill(profile: Dictionary, class_id: String, ids: Array) -> void:
	for id: String in ids:
		while Rules.rank(Profile.class_state(profile, class_id), id) < int(d.talents[id].ranks):
			var why := Rules.rank_up(d, profile, class_id, id)
			if not why.is_empty():
				printerr("fill stopped at ", id, ": ", why)
				return


func _test_data_is_complete() -> void:
	var per_class := {}
	for talent: Dictionary in d.talents.values():
		per_class[talent["class"]] = int(per_class.get(talent["class"], 0)) + 1
		var ranks := int(talent.ranks)
		for key: String in talent:
			if talent[key] is Array and key not in ["statuses", "stages"]: check(talent[key].size() == ranks, "%s.%s has one value per rank" % [talent.id, key])
		if str(talent.kind) != "passive": check(talent.has("cost") and talent.has("cd"), "%s has cost and cooldown" % talent.id)
	check(per_class.size() == 4 and per_class.values().all(func(n: int) -> bool: return n == 42), "each class has 42 talents (%s)" % per_class)
	check(d.classes.has("necromancer") and d.resources.necromancer.kind == "mana", "the necromancer plays with mana")
	check(float(d.resources.mage.max) > float(d.resources.necromancer.max), "the mage has the most mana")
	for class_entry: Dictionary in d.classes.values():
		for spec: Dictionary in class_entry.specs:
			var tiers := {}
			var points := 0
			var ultimates := 0
			for id: String in spec.talents:
				tiers[int(d.talents[id].tier)] = true
				points += int(d.talents[id].ranks)
				if str(d.talents[id].kind) == "ultimate": ultimates += 1
			check(spec.talents.size() == 14 and tiers.size() == 8 and ultimates == 1, "%s: 14 talents in 8 rows, one ultimate" % spec.id)
			check(points > Rules.points_total(d, int(d.max_level)), "%s: more ranks (%d) than points at level 30, so a build must choose" % [spec.id, points])


func _test_points_per_level() -> void:
	# Arrange / Act / Assert
	check(Rules.points_total(d, 1) == 0, "level 1 has no talent point")
	check(Rules.points_total(d, 2) == 1, "level 2 gives the first point")
	check(Rules.points_total(d, 30) == 29, "level 30 gives 29 points")
	var state := Profile.fresh_class()
	state.exp = 0
	var gained := Rules.add_exp(d, state, Rules.exp_to_next(d, 1))
	check(gained == 1 and state.level == 2 and Rules.free_points(d, state) == 1, "a level-up gives one talent point")


func _test_tier_locks() -> void:
	var profile := _profile(4)
	check(not Rules.check_rank_up(d, profile, "swordsman", "berserk_3").is_empty(), "row II is locked below level 5")
	Profile.class_state(profile, "swordsman").level = 5
	check(Rules.check_rank_up(d, profile, "swordsman", "berserk_3").contains("Punkte"), "row II needs 2 points in its branch")
	check(Rules.rank_up(d, profile, "swordsman", "berserk_1").is_empty(), "row I opens at level 2")
	check(Rules.rank_up(d, profile, "swordsman", "berserk_2").is_empty(), "a second talent of row I")
	check(Rules.rank_up(d, profile, "swordsman", "berserk_3").is_empty(), "2 points in the branch open row II")
	check(Rules.rank_up(d, profile, "swordsman", "mage_1").length() > 0, "talents of other classes are refused")
	Rules.rank_up(d, profile, "swordsman", "berserk_1")
	check(Rules.check_rank_up(d, profile, "swordsman", "berserk_1").contains("Kein freier"), "no rank without a free point")


func _test_ultimate_needs_shards_and_is_unique() -> void:
	var profile := _profile(30)
	_fill(profile, "swordsman", ["berserk_1", "berserk_2", "berserk_3", "berserk_4", "berserk_5"])
	check(Rules.check_rank_up(d, profile, "swordsman", "berserk_14").contains("Punkte"), "the ultimate needs 20 points in the branch")
	_fill(profile, "swordsman", ["berserk_6", "berserk_7"])
	check(Rules.check_rank_up(d, profile, "swordsman", "berserk_14").contains("Seelensplitter"), "missing soul shards block the ultimate")
	profile.shards = {"have": 5, "earned": 5, "spent": 0}
	check(Rules.rank_up(d, profile, "swordsman", "berserk_14").is_empty(), "the ultimate unlocks with enough shards")
	check(profile.shards.have == 5 - int(d.soul_shards.ultimate_cost) and profile.shards.spent == int(d.soul_shards.ultimate_cost) and int(d.soul_shards.ultimate_cost) == 1, "unlocking spends exactly one shard (Stufe 1)")
	check(Rules.check_rank_up(d, profile, "swordsman", "blade_14").length() > 0, "a second ultimate is refused")


func _test_soul_tiers_and_reset() -> void:
	var profile := _profile(30)
	_fill(profile, "swordsman", ["guard_1", "guard_2", "guard_3", "guard_4", "guard_5", "guard_6", "guard_7"])
	profile.shards = {"have": 16, "earned": 16, "spent": 0}
	profile.gold = 2000
	Rules.rank_up(d, profile, "swordsman", "guard_14")
	check(profile.shards.have == 15, "the ultimate unlocks with one shard (Stufe 1)")
	check(Rules.soul_up(d, profile, "swordsman").is_empty() and Rules.soul_up(d, profile, "swordsman").is_empty(), "Stufe 2 and Stufe 3 can be bought")
	check(profile.shards.have == 10 and Profile.class_state(profile, "swordsman").soul_tier == 2, "the stages cost 2 + 3 shards (6 in all)")
	check(not Rules.soul_up(d, profile, "swordsman").is_empty(), "there is no Stufe 4")
	check(is_equal_approx(Rules.soul_scale(d, Profile.class_state(profile, "swordsman")), 1.2), "Stufe 3 replaces the lower bonus (+20 %)")
	var cost := Rules.reset_cost(d, profile, "swordsman")
	check(Rules.reset(d, profile, "swordsman").is_empty(), "the reset works with enough gold")
	var state := Profile.class_state(profile, "swordsman")
	check(state.ranks.is_empty() and Rules.free_points(d, state) == 29, "the reset refunds every talent point")
	check(profile.shards.have == 16 and profile.shards.spent == 0 and profile.shards.earned == 16, "the reset refunds every spent shard, no duplicates")
	check(profile.gold == 2000 - cost and state.soul_tier == 0, "the reset costs gold and ends the soul tiers")
	profile.gold = 0
	_fill(profile, "swordsman", ["guard_1"])
	check(not Rules.reset(d, profile, "swordsman").is_empty(), "a reset without enough gold is refused")


## Every ultimate has two stages that change it (talents.json "stages");
## Rules.staged sums them in, cumulatively.
func _test_ultimate_stages() -> void:
	for id: String in d.talents:
		var info: Dictionary = d.talents[id]
		if str(info.kind) != "ultimate": continue
		var stages: Array = info.get("stages", [])
		check(stages.size() == (d.soul_shards.tier_costs as Array).size(), "%s has a stage per bought tier" % id)
		check(stages.all(func(st: Dictionary) -> bool: return not str(st.get("name", "")).is_empty() and not str(st.get("text", "")).is_empty()), "%s stages are named and described" % id)
		check(Rules.staged(d, id, 0) == info, "%s at Stufe 1 plays as written" % id)
		check(Rules.staged(d, id, 2) != Rules.staged(d, id, 1) and Rules.staged(d, id, 1) != info, "%s changes with every stage" % id)
	var inferno := Rules.staged(d, "fire_14", 2)
	check(float(inferno.crater.time) == 7.0 and inferno.has("shower"), "Meteor Stufe 3: the long crater and the shower")
	check(not Rules.staged(d, "fire_14", 1).has("shower") and float(Rules.staged(d, "fire_14", 1).crater.time) == 7.0, "Meteor Stufe 2 keeps the shower for later")
	check(Rules.staged(d, "sniper_14", 2).has("end_burst") and Rules.staged(d, "sniper_14", 2).has("mark"), "Himmelsspeer Stufe 3 brands and bursts")
	check(str(Rules.staged(d, "blade_14", 1).status) == "bleed" and not Rules.staged(d, "blade_14", 1).has("radial"), "Klingensturm Stufe 2 bleeds, the blades wait for Stufe 3")
	check(float(Rules.staged(d, "guard_14", 2).thorns) > 0.0 and (Rules.staged(d, "guard_14", 2).after as Array).size() == 1, "Bollwerk Stufe 3 keeps the thorns and adds its closing wave")
	check(is_equal_approx(float(Rules.staged(d, "fire_14", 1).dmg[0]), float(d.talents.fire_14.dmg[0])), "a stage without a damage change keeps the damage")


## User decision 29.10.2026: one branch per character. The first point picks
## it, the others stay locked until a reset; an old build spread over several
## branches keeps the branch with the most points.
func _test_one_branch_per_character() -> void:
	var profile := _profile(10, "mage")
	check(Rules.chosen_spec(d, Profile.class_state(profile, "mage")).is_empty(), "before the first point every branch is open")
	check(Rules.check_rank_up(d, profile, "mage", "frost_1").is_empty() and Rules.check_rank_up(d, profile, "mage", "arcane_1").is_empty(), "the first point may go anywhere")
	Rules.rank_up(d, profile, "mage", "fire_1")
	check(Rules.chosen_spec(d, Profile.class_state(profile, "mage")) == "fire", "the first point makes a fire mage")
	check(Rules.check_rank_up(d, profile, "mage", "frost_1").contains("Feuermagier"), "a fire mage cannot learn frost talents")
	check(not Rules.valid_build(d, {"level": 10, "ranks": {"fire_1": 1, "frost_1": 1}}), "a build in two branches is invalid")
	profile.gold = 1000
	Rules.reset(d, profile, "mage")
	check(Rules.check_rank_up(d, profile, "mage", "frost_1").is_empty(), "after a reset another branch can be chosen")
	var mixed := _profile(20, "mage")
	Profile.class_state(mixed, "mage").ranks = {"fire_1": 3, "fire_2": 2, "frost_1": 1}
	Rules.repair(d, mixed, "mage")
	check(Profile.class_state(mixed, "mage").ranks == {"fire_1": 3, "fire_2": 2}, "repair keeps the branch with the most points")


## Version 1 profiles (the 4-row trees): the old ultimates <spec>_6 move to
## row VIII (<spec>_14) and the build is repaired to fit the new rows.
func _test_old_profiles_move_over() -> void:
	var raw := {"version": 1, "shards": {"earned": 4, "spent": 3}, "classes": {"mage": {"level": 30, "ranks": {"fire_1": 3, "fire_2": 3, "fire_3": 3, "fire_4": 3, "fire_5": 3, "fire_6": 1, "frost_1": 2}, "ultimate": "fire_6", "soul_paid": 3, "bar": ["fire_1", "fire_6"]}}}
	var path := "user://talent_progress_migrate_test.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var loaded := Profile.load_profile(d, path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var state := Profile.class_state(loaded, "mage")
	check(not state.ranks.has("frost_1") and Rules.chosen_spec(d, state) == "fire", "the old build keeps its main branch")
	check(not state.ranks.has("fire_6") or str(d.talents.fire_6.kind) != "ultimate", "the old ultimate id is gone")
	check(Rules.valid_build(d, state), "the moved build fits the new rows")
	check(int(loaded.shards.have) + int(loaded.shards.spent) == 4, "no soul shard is lost on the way")


func _test_rank_down_keeps_build_valid() -> void:
	var profile := _profile(12, "mage")
	Rules.rank_up(d, profile, "mage", "fire_1")
	Rules.rank_up(d, profile, "mage", "fire_1")
	Rules.rank_up(d, profile, "mage", "fire_3")
	check(not Rules.can_rank_down(d, profile, "mage", "fire_1"), "a point that opens a higher tier cannot be taken back")
	check(Rules.rank_down(d, profile, "mage", "fire_3").is_empty() and Rules.rank_down(d, profile, "mage", "fire_1").is_empty(), "points without dependants can be taken back")
	var broken := _profile(10, "mage")
	Profile.class_state(broken, "mage").ranks = {"fire_5": 3, "fire_1": 1}
	check(Rules.repair(d, broken, "mage") > 0 and Rules.valid_build(d, Profile.class_state(broken, "mage")), "an invalid received build is repaired")


func _test_exp_levels() -> void:
	var state := Profile.fresh_class()
	Rules.add_exp(d, state, 100000000)
	check(state.level == 30 and state.exp == 0, "the level stops at 30")
	# Max level only after several full runs (user decision 29.10.2026, was 1.5
	# floors): one floor brings roughly 60 kills and the floor bonus, a run 10 floors.
	var total := 0
	for level in range(1, 30): total += Rules.exp_to_next(d, level)
	var per_run: int = (60 * int(d.exp.kill) + int(d.exp.floor)) * 10
	check(float(total) / per_run >= 2.5 and float(total) / per_run <= 4.0, "level 30 takes several full runs (%.2f)" % (float(total) / per_run))
	check(Rules.exp_to_next(d, 2) == 2 * Rules.exp_to_next(d, 1) and Rules.exp_to_next(d, 29) == 29 * Rules.exp_to_next(d, 1), "every level follows the same rule (base x level)")


func _test_profile_save_and_sanitize() -> void:
	var profile := _profile(25, "archer")
	profile.shards = {"have": 4, "earned": 7, "spent": 3}
	profile.nightmare_firsts = ["rot_king"]
	Profile.class_state(profile, "archer").ranks = {"sniper_1": 3}
	var path := "user://talent_progress_test.json"
	check(Profile.save_profile(profile, path) == OK, "the profile saves")
	var loaded := Profile.load_profile(d, path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(loaded.shards.have == 4 and loaded.nightmare_firsts == ["rot_king"], "currencies and first kills survive a restart")
	check(Profile.class_state(loaded, "archer").level == 25 and Profile.class_state(loaded, "archer").ranks.get("sniper_1", 0) == 3, "level and talents survive a restart")
	var forged := Profile.sanitize({"gold": -50, "shards": {"have": 99, "earned": 2, "spent": 5}, "classes": {"mage": {"level": 99, "ranks": {"fire_1": 9, "nope": 1}}}}, d)
	check(forged.gold == 0 and forged.shards.have == 0 and forged.shards.spent == 2, "negative or inconsistent currencies are repaired")
	check(Profile.class_state(forged, "mage").level == 30 and Profile.class_state(forged, "mage").ranks == {"fire_1": 3}, "levels and ranks are clamped, unknown talents dropped")


func _test_drop_chances() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var per_boss := int(d.soul_shards.per_boss)
	for difficulty: String in ["normal", "hard", "nightmare"]:
		var shards := 0
		var kills := 4000
		var profile := Profile.fresh(d)
		profile.nightmare_firsts = ["boss"]
		for i in range(kills):
			shards += int(Drops.resolve(d, profile, "boss", difficulty, "k%d" % i, 10, 10, FIGHT, rng.randf()).count)
		var expected: float = per_boss + float(d.difficulties[difficulty].extra_pct) / 100.0
		check(absf(float(shards) / kills - expected) < 0.03, "%s gives about %.2f shards per boss (%.3f)" % [difficulty, expected, float(shards) / kills])
	check(not Drops.can_drop({"boss": false}) and not Drops.can_drop({"boss": true, "miniboss": true}) and not Drops.can_drop({"boss": true, "elite": true}), "normal enemies, mini-bosses and elites never drop shards")
	check(Drops.can_drop({"boss": true}), "a real floor boss can drop shards")


func _test_shards_per_boss_and_nightmare_first() -> void:
	var profile := Profile.fresh(d)
	var result: Dictionary = Drops.resolve(d, profile, "boss", "normal", "p0", 10, 10, FIGHT, 0.99)
	check(result.shard and int(result.count) == int(d.soul_shards.per_boss), "every fair boss kill gives %d shards, no luck needed" % int(d.soul_shards.per_boss))
	check(int(Drops.resolve(d, profile, "rot_king", "nightmare", "n1", 10, 30, FIGHT, 0.99).count) == int(d.soul_shards.per_boss) + 1, "the first Albtraum kill of a boss gives one more")
	check(int(Drops.resolve(d, profile, "rot_king", "nightmare", "n2", 10, 30, FIGHT, 0.99).count) == int(d.soul_shards.per_boss), "the first-kill bonus comes only once per boss")
	check(int(Drops.resolve(d, profile, "rot_king", "nightmare", "n3", 10, 30, FIGHT, 0.0).count) == int(d.soul_shards.per_boss) + 1, "luck adds one shard on Albtraum")
	check(int(Drops.resolve(d, profile, "boss", "normal", "n4", 10, 10, FIGHT, 0.0).count) == int(d.soul_shards.per_boss), "Normal has no extra chance, so the pace is exact")


## User decisions 29.10.2026: shards only from the run's boss (one per full
## run, floor 10); the ultimate is an expansion: unlocked with one shard, then
## Stufe 2 and 3, about one stage per full run on Normal.
func _test_ultimate_pace() -> void:
	var profile := Profile.fresh(d)
	var cost := int(d.soul_shards.ultimate_cost)
	var runs := 0
	while int(profile.shards.have) < cost and runs < 10:
		runs += 1
		Drops.resolve(d, profile, "final", "normal", "run%d" % runs, 20, Drops.boss_level(d, 10, "normal"), FIGHT, 0.99)
	check(runs == 1, "on Normal the ultimate opens with the first full run (%d)" % runs)
	var total := cost
	for price: Variant in d.soul_shards.tier_costs: total += int(price)
	while int(profile.shards.earned) < total and runs < 10:
		runs += 1
		Drops.resolve(d, profile, "final", "normal", "run%d" % runs, 20, Drops.boss_level(d, 10, "normal"), FIGHT, 0.99)
	check(runs == 3, "Stufe 3 is paid for after the third full run (%d)" % runs)


func _test_no_farming_or_duplicates() -> void:
	var profile := Profile.fresh(d)
	var result: Dictionary = Drops.resolve(d, profile, "boss", "normal", "f1", int(d.max_level), Drops.boss_level(d, 10, "normal"), FIGHT, 0.0)
	check(result.shard and int(result.count) == int(d.soul_shards.per_boss), "the Normal final boss gives shards even at level %d" % int(d.max_level))
	check(not Drops.resolve(d, profile, "boss", "normal", "f2", 10, 10, {"present": false, "seconds": 60.0, "damage_share": 0.5}, 0.0).shard, "leaving the fight gives nothing")
	check(not Drops.resolve(d, profile, "boss", "normal", "f3", 10, 10, {"present": true, "seconds": 60.0, "damage_share": 0.0}, 0.0).shard, "idling through the fight gives nothing")
	check(Drops.resolve(d, profile, "boss", "normal", "f4", 10, 10, FIGHT, 0.0).shard, "a fair kill can drop")
	check(not Drops.resolve(d, profile, "boss", "normal", "f4", 10, 10, FIGHT, 0.0).shard and profile.shards.earned == 2 * int(d.soul_shards.per_boss), "the same completion cannot reward twice")
	check(Drops.boss_level(d, 5, "nightmare") == 18 and Drops.boss_level(d, 5, "normal") == 10, "boss level = floor x 2 + difficulty bonus")
