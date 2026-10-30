extends SceneTree
## Mana on the ground (talents.json "mana_orbs", user decision 29.10.2026): a
## fallen enemy may leave a mana orb, a boss or mini-boss always a mana potion;
## a hero with mana walks over it and refills, heroes with Ausdauer or Zorn
## leave it lying; orbs fade. Also: keys 1-4 cast the talent bar without Shift,
## and the necromancer plays with mana.

const Game = preload("res://src/game.gd")
const TalentCombat = preload("res://src/combat/talent_combat.gd")
var checked := 0
var failures: Array[String] = []
var game
var tc
var d: Dictionary


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("TALENT_MANA_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _start()
	test_boss_leaves_a_potion_and_mage_drinks_it()
	test_orbs_drop_by_chance_and_fade()
	test_stamina_heroes_leave_mana_lying()
	test_necromancer_plays_with_mana()
	test_key_one_casts_the_first_slot()
	test_no_mana_says_so_and_a_new_build_keeps_mana()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	game.queue_free()
	print("TALENT_MANA checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _start() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://talent_mana_test_profile.json"
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 4242
	game._begin_run()
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	game.players[1].max_hp = 999
	game.players[1].hp = 999


func _hero(class_id: String, ranks: Dictionary, bar: Array) -> Dictionary:
	var player: Dictionary = game.players[1]
	player.class_id = class_id
	player.pos = Vector2(300, 240)
	tc.reset(3)
	tc.set_build(1, {"class": class_id, "level": 30, "ranks": ranks, "bar": bar})
	return tc.runtime(1)


func test_boss_leaves_a_potion_and_mage_drinks_it() -> void:
	# Arrange
	var rt := _hero("mage", {"fire_1": 3}, ["fire_1"])
	rt.res = 10.0
	# Act: a boss falls far away, then the mage walks onto its potion
	tc.enemy_killed({"pos": Vector2(600, 240), "boss": true, "kind": "boss"}, 1)
	check(tc.orbs.size() == 1 and bool(tc.orbs[0].potion), "a boss always leaves a mana potion")
	check(tc.snapshot().orbs.size() == 1, "clients see the potion")
	tc.step(0.05)
	check(tc.orbs.size() == 1 and float(rt.res) < 20.0, "the potion waits until the hero walks over it")
	game.players[1].pos = Vector2(600, 240)
	tc.step(0.05)
	# Assert
	check(tc.orbs.is_empty() and float(rt.res) >= float(rt.res_max) - 1.0, "the potion refills the mana (%.0f / %.0f)" % [rt.res, rt.res_max])


func test_orbs_drop_by_chance_and_fade() -> void:
	var rt := _hero("mage", {"fire_1": 3}, ["fire_1"])
	rt.res = float(rt.res_max)
	tc._rng.seed = 5
	for i in range(200): tc.enemy_killed({"pos": Vector2(900, 900), "kind": "skeleton"}, 1)
	var dropped: int = tc.orbs.size()
	check(dropped > 0 and dropped <= int(d.mana_orbs.max_on_floor), "ordinary enemies leave orbs now and then, never more than %d at once" % int(d.mana_orbs.max_on_floor))
	check(not tc.orbs.any(func(o: Dictionary) -> bool: return bool(o.potion)), "ordinary enemies leave orbs, not potions")
	tc.step(float(d.mana_orbs.life) + 0.1)
	check(tc.orbs.is_empty(), "orbs fade after %d s" % int(d.mana_orbs.life))
	tc.enemy_killed({"pos": Vector2(300, 240), "kind": "skeleton", "summoned": true, "boss": true}, 1)
	check(tc.orbs.is_empty(), "summoned enemies leave nothing")


func test_stamina_heroes_leave_mana_lying() -> void:
	var rt := _hero("archer", {"sniper_1": 3}, ["sniper_1"])
	rt.res = 5.0
	tc.enemy_killed({"pos": Vector2(300, 240), "boss": true, "kind": "boss"}, 1)
	tc.step(0.05)
	check(tc.orbs.size() == 1, "an archer (Ausdauer) leaves the potion lying")
	check(not tc.restore_mana(1, 0.5), "mana does not refill Ausdauer")


func test_necromancer_plays_with_mana() -> void:
	var rt := _hero("necromancer", {"minion_1": 3}, ["minion_1"])
	check(str(rt.res_kind) == "mana" and float(rt.res_max) == float(d.resources.necromancer.max), "the necromancer has mana")
	tc.pets.clear() # the bone warrior came with the build; it fell
	check(tc.cast(1, "minion_1", {"aim": Vector2.RIGHT}) and str(tc.pets[0].kind) == "bone_warrior", "the necromancer raises his bone warrior again")
	check(float(rt.res) < float(rt.res_max), "raising the dead costs mana")


func test_key_one_casts_the_first_slot() -> void:
	var rt := _hero("mage", {"fire_1": 3}, ["fire_1"])
	rt.res = float(rt.res_max)
	game.enemies.clear()
	tc.handle_input(1, game.players[1], {"skills": 1 << TalentCombat.BAR_BIT, "aim": Vector2.RIGHT})
	check(float(rt.cds.get("fire_1", 0.0)) > 0.0, "key 1 casts the first talent slot")


func test_no_mana_says_so_and_a_new_build_keeps_mana() -> void:
	# Arrange
	var rt := _hero("mage", {"fire_1": 3}, ["fire_1"])
	rt.res = 2.0
	tc.events.clear()
	# Act
	var fired: bool = tc.cast(1, "fire_1", {"aim": Vector2.RIGHT})
	tc.cast(1, "fire_1", {"aim": Vector2.RIGHT})
	var hints: Array = tc.events.filter(func(e: Dictionary) -> bool: return str(e.kind) == "no_res")
	# Assert
	check(not fired and hints.size() == 1 and str(hints[0].text) == "Wenig Mana", "a press without mana shows Wenig Mana, once per 0.8 s")
	check(is_equal_approx(float(rt.regen), float(d.resources.mage.regen)) and float(d.resources.mage.regen) < 1.0, "mana comes back slowly (about 2 every 3 s)")
	rt.res = 30.0
	rt.cds["fire_1"] = 3.0
	tc.set_build(1, {"class": "mage", "level": 30, "ranks": {"fire_1": 3, "fire_2": 1}, "bar": ["fire_1"]}, true)
	var after: Dictionary = tc.runtime(1)
	check(is_equal_approx(float(after.res), 30.0) and float(after.cds.get("fire_1", 0.0)) > 0.0, "skilling mid-run keeps mana and cooldowns (no free refill)")
