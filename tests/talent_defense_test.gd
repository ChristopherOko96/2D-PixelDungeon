extends SceneTree
## The user's third wish list (30.10.2026): every class defends on Shift
## (talents.json "defense": the archer rolls away, mage, warrior and
## necromancer hold up a block that lasts two hits, then breaks), companions
## go for what their hero attacks or what attacks it and stay in the fight,
## the fire mage's Pyro-Monster, the skill bar's description cards, and keys
## 5 and 6 no longer firing keys 1-4 and R in the crypt.

const Game = preload("res://src/game.gd")
const TalentCombat = preload("res://src/combat/talent_combat.gd")
const TalentBar = preload("res://src/ui/talent_bar.gd")
var checked := 0
var failures: Array[String] = []
var game
var tc
var d: Dictionary


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("TALENT_DEFENSE_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _start()
	test_archer_rolls_away_and_is_untouchable()
	test_block_lasts_two_hits_then_breaks_and_mends()
	test_every_class_has_a_defense_on_shift()
	test_companion_attacks_what_its_hero_attacks_and_stays()
	test_companion_answers_an_enemy_going_for_its_hero()
	test_pyro_monster_fights_for_the_fire_mage()
	test_skill_bar_cards_say_what_a_skill_does()
	test_keys_five_and_six_keep_their_own_bits()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	game.queue_free()
	print("TALENT_DEFENSE checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _start() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://talent_defense_test_profile.json"
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 5252
	game._begin_run()
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	game.players[1].max_hp = 999
	game.players[1].hp = 999


func _hero(class_id: String, ranks: Dictionary = {}, companion: String = "") -> Dictionary:
	var player: Dictionary = game.players[1]
	player.class_id = class_id
	player.pos = Vector2(300, 240)
	game.enemies.clear()
	tc.reset(3)
	tc.set_build(1, {"class": class_id, "level": 30, "ranks": ranks, "bar": [], "companion": companion})
	return tc.runtime(1)


func _foe(at: Vector2) -> Dictionary:
	var enemy: Dictionary = game._create_enemy("skeleton", at)
	enemy.hp = 999.0
	enemy.max_hp = 999.0
	enemy.aggro = true
	enemy.aggro_target = 1
	game.enemies.append(enemy)
	return enemy


func _tick(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		tc.step(1.0 / 30.0)
		t += 1.0 / 30.0


func test_archer_rolls_away_and_is_untouchable() -> void:
	# Arrange
	var rt := _hero("archer")
	var start: Vector2 = game.players[1].pos
	# Act: Shift with a move direction
	tc.hold(1, false, true, Vector2.INF, Vector2.RIGHT)
	# Assert
	check(Vector2(game.players[1].pos).distance_to(start) > 60.0, "Ausweichen rolls the archer about 3 m")
	check(tc.incoming(1, 10, Vector2.ZERO) == 0, "during the roll a hit misses")
	check(int(rt.defense.left) == 1, "a roll uses one of two charges")
	tc.hold(1, false, false, Vector2.INF, Vector2.RIGHT)
	tc.hold(1, false, true, Vector2.INF, Vector2.RIGHT)
	tc.hold(1, false, false, Vector2.INF, Vector2.RIGHT)
	var spent: Vector2 = game.players[1].pos
	tc.hold(1, false, true, Vector2.INF, Vector2.RIGHT)
	check(Vector2(game.players[1].pos) == spent, "with no charge left Shift does nothing")
	_tick(0.5)
	check(tc.incoming(1, 10, Vector2.ZERO) > 0, "after the roll hits land again")
	_tick(4.2)
	check(int(rt.defense.left) >= 1, "a charge comes back after 4 s")


func test_block_lasts_two_hits_then_breaks_and_mends() -> void:
	# Arrange
	var rt := _hero("mage")
	# Act / Assert
	tc.hold(1, false, true, Vector2.INF, Vector2.ZERO)
	check(bool(rt.defense.up), "holding Shift raises the magic block")
	check(tc.incoming(1, 10, Vector2.ZERO) == 0 and int(rt.defense.left) == 1, "the first hit is stopped, one is left")
	check(tc.incoming(1, 10, Vector2.ZERO) == 0 and float(rt.defense.broken) > 0.0, "the second hit is stopped and breaks the block")
	tc.hold(1, false, true, Vector2.INF, Vector2.ZERO)
	check(tc.incoming(1, 10, Vector2.ZERO) > 0, "a broken block stops nothing, however long Shift is held")
	tc.hold(1, false, false, Vector2.INF, Vector2.ZERO)
	_tick(8.2)
	check(int(rt.defense.left) == 2, "after 8 s the block is whole again")
	tc.hold(1, false, true, Vector2.INF, Vector2.ZERO)
	tc.incoming(1, 10, Vector2.ZERO)
	tc.hold(1, false, false, Vector2.INF, Vector2.ZERO)
	_tick(3.2)
	check(int(rt.defense.left) == 2, "lowered, a used block regains a hit after 3 s")


func test_every_class_has_a_defense_on_shift() -> void:
	for class_id: String in d.resources:
		var rt := _hero(class_id)
		check(not Dictionary(rt.get("defense", {})).is_empty(), "%s has a defense on Shift" % class_id)
		check(not Dictionary(tc.player_state(1).get("defense", {})).is_empty(), "%s: the HUD shows it" % class_id)


func test_companion_attacks_what_its_hero_attacks_and_stays() -> void:
	# Arrange: a wolf, an enemy the hero shoots far across the room
	_hero("archer", {"beast_1": 1}, "wolf")
	var near := _foe(Vector2(330, 240))
	near.aggro = false
	var prey := _foe(Vector2(420, 250))
	prey.aggro = false
	# Act: the hero's own hit
	game._damage_enemy(prey, 1.0, Vector2.RIGHT, 1, true)
	_tick(0.1)
	var wolf: Dictionary = tc.permanent_pet(1)
	# Assert
	check(int(wolf.target) == int(prey.id), "the companion goes for what its hero attacks, not the nearest enemy")
	game.players[1].pos = Vector2(60, 240)
	_tick(3.0)
	check(int(wolf.target) == int(prey.id) and Vector2(wolf.pos).distance_to(prey.pos) < 60.0, "it stays at that enemy though the hero walked away")
	game.players[1].pos = Vector2(220, 240)
	game.enemies.clear()
	_tick(3.0)
	check(Vector2(wolf.pos).distance_to(game.players[1].pos) < 80.0, "with the fight over it comes back to its hero")


func test_companion_answers_an_enemy_going_for_its_hero() -> void:
	# Arrange
	_hero("archer", {"beast_1": 1}, "bear")
	var idle := _foe(Vector2(340, 240))
	idle.aggro = false
	var attacker := _foe(Vector2(520, 300))
	# Act
	_tick(0.1)
	# Assert
	check(int(tc.permanent_pet(1).target) == int(attacker.id), "an enemy going for the hero is the companion's target")


func test_pyro_monster_fights_for_the_fire_mage() -> void:
	# Arrange / Act
	_hero("mage", {"fire_1": 2, "fire_3": 1})
	var pyro: Dictionary = tc.permanent_pet(1)
	# Assert
	check(not pyro.is_empty() and str(pyro.kind) == "pyro", "the fire mage's talent 3 is the Pyro-Monster")
	check(str(tc.pet_ability("pyro", 0).name) == "Glutfaust" and str(tc.pet_ability("pyro", 1).name) == "Feuerkreis", "its abilities on 5 and 6")
	var foe := _foe(Vector2(pyro.pos) + Vector2(20, 0))
	pyro.target = int(foe.id)
	check(tc.pet_cast(1, 0, true) and Dictionary(foe.get("statuses", {})).has("burn"), "Glutfaust sets the enemy on fire")


func test_skill_bar_cards_say_what_a_skill_does() -> void:
	# Arrange
	var rt := _hero("mage", {"fire_1": 2})
	rt.bar = ["fire_1"]
	# Act
	var slots: Array = TalentBar.new().skill_slots(tc.player_state(1))
	# Assert
	check(str(slots[0].text) == str(d.talents.fire_1.text) and str(slots[0].meta).contains("Mana"), "the card shows the description, cost and cooldown")
	var shift: Array = slots.filter(func(s: Dictionary) -> bool: return bool(s.get("defense", false)))
	check(shift.size() == 1 and str(shift[0].key) == "SH" and not str(shift[0].text).is_empty(), "the bar has the Shift defense with its text")


func test_keys_five_and_six_keep_their_own_bits() -> void:
	# Arrange / Act: key 5 (bit 9) as the crypt sends it
	game.commands.erase(1)
	game._accept_input(1, Vector2.ZERO, Vector2.RIGHT, false, 999999, 1 << TalentCombat.PET_BIT)
	# Assert
	check(int(game.commands[1].skills) == 1 << TalentCombat.PET_BIT, "key 5 stays bit 9 (it used to become keys 1-4 and R)")
