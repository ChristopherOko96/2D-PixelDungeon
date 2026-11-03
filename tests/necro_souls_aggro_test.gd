extends "res://tests/talent_pet_test.gd"
## Real shared runtime. No earned campaign; synthetic builds and local host.
func _run() -> void:
	await _start()
	game.progress.save_path = "user://necro_souls_aggro_test.json"
	game.current_layout = {"id": "souls-test", "world_size": [1408, 704], "play_bounds": [32, 32, 1344, 640], "obstacles": [], "exits": []}
	test_souls_are_a_capped_kill_resource_with_reserve()
	test_kill_credit_and_duplicate_protection()
	test_actual_companion_kill_feeds_owner()
	test_every_companion_acquires_and_stays_without_owner_leash()
	test_guardian_keeps_battle_when_owner_runs()
	test_retained_target_cannot_be_hit_through_wall()
	test_ranged_companion_routes_around_nearby_cover()
	test_legacy_story_companions_keep_their_fight()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	game._leave_session()
	game.queue_free()
	await process_frame
	print("NECRO_SOULS_AGGRO checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_souls_are_a_capped_kill_resource_with_reserve() -> void:
	var rt := _hero("necromancer", {"soul_1": 1})
	check(str(rt.res_kind) == "souls" and float(rt.res_max) == 100.0, "necro uses 100 base souls, never mana")
	check(is_equal_approx(float(rt.res), 50.0), "run begins with fifty souls")
	if str(rt.res_kind) != "souls": return
	rt.res = 0.0
	tc.step(5.0)
	check(is_equal_approx(float(rt.res), 5.0), "quiet Seelensog generates one soul per second")
	rt.res = 39.0
	tc.step(20.0)
	check(float(rt.res) == 40.0, "waiting only refills the forty-soul reserve")
	rt.res = 75.0
	tc.step(10.0)
	check(float(rt.res) == 75.0, "reserve limit never drains collected souls")
	var boss := _foe(Vector2(80, 0))
	boss.boss = true
	rt.res = 0.0
	tc.step(5.0)
	check(is_equal_approx(float(rt.res), 10.0), "boss without adds still allows two souls per second")
	check(not tc.restore_mana(1, 1.0) and float(rt.res) == 10.0, "mana potions cannot refill souls")
	tc.runtime(1).bar = ["soul_1"]
	var before := float(rt.res)
	check(tc.cast(1, "soul_1") and is_equal_approx(float(rt.res), before - 8.0), "a learned bolt consumes eight souls")
	var left := float(rt.res)
	tc.set_build(1, {"class": "necromancer", "level": 30, "ranks": {"soul_1": 1}, "bar": ["soul_1"]}, true)
	check(is_equal_approx(float(tc.runtime(1).res), left), "editing build never refills souls")
	game.players[1].hp = 0
	tc.runtime(1).res = 0.0
	tc.step(20.0)
	check(float(tc.runtime(1).res) == 0.0, "dead necromancers cannot accumulate souls")
	game.players[1].hp = 999

func test_kill_credit_and_duplicate_protection() -> void:
	var rt := _hero("necromancer", {})
	if str(rt.res_kind) != "souls": return
	rt.res = 0.0
	var victim := _foe(Vector2(80, 0))
	game._damage_enemy(victim, 99999.0, Vector2.RIGHT, 1, true)
	check(is_equal_approx(float(rt.res), 8.0), "real host kill yields eight souls")
	tc.enemy_killed(victim, 1)
	check(is_equal_approx(float(rt.res), 8.0), "same death cannot grant souls twice")
	var summoned := _foe(Vector2(80, 0))
	summoned.summoned = true
	game._damage_enemy(summoned, 99999.0, Vector2.RIGHT, 1, true)
	check(is_equal_approx(float(rt.res), 8.0), "summoned hostiles cannot farm souls")
	var alive := _foe(Vector2(80, 0))
	tc.enemy_killed(alive, 1)
	check(is_equal_approx(float(rt.res), 8.0), "nonlethal notification cannot mint souls")
	var mini := _foe(Vector2(80, 0))
	mini.miniboss = true
	game._damage_enemy(mini, 99999.0, Vector2.RIGHT, 1, true)
	check(is_equal_approx(float(rt.res), 28.0), "miniboss rewards twenty souls")
	var boss := _foe(Vector2(80, 0))
	boss.boss = true
	game._damage_enemy(boss, 99999.0, Vector2.RIGHT, 1, true)
	check(is_equal_approx(float(rt.res), 58.0), "boss rewards thirty souls")
	rt.res = 99.0
	var capped := _foe(Vector2(80, 0))
	game._damage_enemy(capped, 99999.0, Vector2.RIGHT, 1, true)
	check(float(rt.res) == float(rt.res_max), "soul income never overfills capacity")
	game.players[2] = game.players[1].duplicate(true)
	tc.set_build(2, {"class": "mage", "level": 30, "ranks": {}, "bar": []})
	rt.res = 0.0
	var ally_kill := _foe(Vector2(80, 0))
	game._damage_enemy(ally_kill, 99999.0, Vector2.RIGHT, 2, true)
	check(is_equal_approx(float(rt.res), 4.0), "nearby allied kill gives bounded assist souls")
	game.players.erase(2)
	tc.runtimes.erase(2)

func test_every_companion_acquires_and_stays_without_owner_leash() -> void:
	for kind: String in d.pet.kinds:
		var rt := _hero("mage", {})
		tc._spawn_pet(1, rt, "frost_3", {"pet_kind": kind, "hp": 50, "every": 1.0, "dmg": 1.0}, Vector2(300, 240), false, 30.0)
		var pet: Dictionary = tc.pets[0]
		var victim := _foe(Vector2(50, 0))
		victim.aggro = false
		victim.aggro_target = 2
		game.players[1].pos = Vector2(1200, 240)
		check(int(tc._pet_prey(pet, game.players[1]).get("id", -1)) == int(victim.id), "%s acquires near itself without waiting for owner aggro" % kind)
		pet.target = int(victim.id)
		victim.pos = Vector2(800, 240)
		check(int(tc._pet_prey(pet, game.players[1]).get("id", -1)) == int(victim.id), "%s keeps a living battle target outside acquisition range" % kind)
		victim.hp = 0.0
		var other := _foe(Vector2(-850, 0))
		other.aggro = false
		check(int(tc._pet_prey(pet, game.players[1]).get("id", -1)) == int(other.id), "%s continues fighting nearby survivors after its target dies" % kind)
		other.hp = 0.0
		check(tc._pet_prey(pet, game.players[1]).is_empty(), "%s releases target only after battle ends" % kind)

func test_actual_companion_kill_feeds_owner() -> void:
	var rt := _hero("necromancer", {"minion_1": 1})
	check(tc.cast(1,"minion_1",{"aim":Vector2.LEFT}),"companion kill fixture explicitly summons its warrior")
	rt.res = 0.0
	var enemy := _foe(Vector2(10, 0))
	enemy.hp = 0.2
	_tick(1.0)
	check(float(enemy.hp) <= 0.0 and bool(enemy.get("talent_death_paid", false)), "real bone-warrior attack kills through the host death path")
	check(float(rt.res) >= 8.0 and float(rt.res) < 11.0, "companion kill grants owner exactly one normal reward plus passive time")

func test_guardian_keeps_battle_when_owner_runs() -> void:
	var rt := _hero("necromancer", {})
	var cfg: Dictionary = d.talents.soul_14
	var victim := _foe(Vector2(70, 0))
	var actor := {"pos": Vector2(320, 240), "target": int(victim.id), "owner": 1, "info": cfg}
	game.players[1].pos = Vector2(1200, 240)
	check(int(tc.guardians._prey(tc, actor, game.players[1], rt).get("id", -1)) == int(victim.id), "guardian retains enemy when owner leaves its old leash")
	victim.hp = 0.0
	var survivor := _foe(Vector2(-800, 0))
	check(int(tc.guardians._prey(tc, actor, game.players[1], rt).get("id", -1)) == int(survivor.id), "guardian switches to remaining local enemy, not back to distant owner")

class StoryHost extends Node:
	var mobs: Array = []
	var talents: Object = null
	func box_blocked(_box: Rect2, _solid: bool = true) -> bool: return false

func test_retained_target_cannot_be_hit_through_wall() -> void:
	_hero()
	var pet: Dictionary = tc.permanent_pet(1)
	var prey := _foe(Vector2(120, 0))
	pet.target = int(prey.id)
	var before := float(prey.hp)
	var layout: Dictionary = game.current_layout
	game.current_layout = {"world_size": [1408, 704], "play_bounds": [32, 32, 1344, 640], "obstacles": [[350, 32, 32, 640]], "exits": []}
	check(not tc.pet_cast(1, 0, true) and float(prey.hp) == before, "retaining target never lets companion abilities fire through walls")
	game.current_layout = layout

func test_ranged_companion_routes_around_nearby_cover() -> void:
	_hero()
	var pet: Dictionary = tc.permanent_pet(1)
	var prey := _foe(Vector2(70, 0))
	pet.target = int(prey.id)
	var before: Vector2 = pet.pos
	var layout: Dictionary = game.current_layout
	game.current_layout = {"tile_size": 32, "world_size": [1408, 704], "play_bounds": [32, 32, 1344, 640], "obstacles": [[330, 200, 16, 80]], "exits": []}
	_tick(0.3)
	check(Vector2(pet.pos).distance_to(before) > 5.0, "ranged companion routes around cover even while inside weapon range (from=%s to=%s route=%s)" % [before, pet.pos, pet.get("route", [])])
	game.current_layout = layout

func test_legacy_story_companions_keep_their_fight() -> void:
	var pick = load("res://src/combat/companion_targets.gd")
	var host := StoryHost.new()
	var enemy := {"p": Vector2(70, 0), "hp": 5.0, "spawn": 0.0}
	var ally := {"p": Vector2.ZERO}
	host.mobs = [enemy]
	check(is_same(pick.story_pick(host, ally), enemy), "story/relic ally acquires nearby enemy")
	enemy.p = Vector2(1500, 0)
	var closer := {"p": Vector2(20, 0), "hp": 5.0, "spawn": 0.0}
	host.mobs.append(closer)
	check(is_same(pick.story_pick(host, ally), enemy), "legacy ally keeps its living battle target out of initial range")
	enemy.hp = 0.0
	check(is_same(pick.story_pick(host, ally), closer), "legacy ally continues on nearby survivors")
	closer.hp = 0.0
	check(pick.story_pick(host, ally).is_empty(), "legacy ally returns only after no local survivors remain")
	host.free()
