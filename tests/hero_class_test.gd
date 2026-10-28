extends SceneTree
## Hero classes and basic attacks (step 2 of the main port): class values,
## perks on top of class bases, the swordsman's melee swing (arc, reach, walls),
## the mage's splash, melee-safe perk offers, the host-validated lobby class
## action and the snapshot fields clients draw from. Uses a disposable loopback
## host and the fixed rect room library in tests/fixtures (known geometry).
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const HeroClass = preload("res://src/player/hero_class.gd")
const PerkRules = preload("res://src/perk_rules.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("HERO_CLASS_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _new_host() -> Node:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var port := PacketPeerUDP.new()
	port.bind(0, "127.0.0.1")
	game.port_input.text = str(port.get_local_port())
	port.close()
	game.session_bind_ip = "127.0.0.1"
	game.requested_seed = 4242
	game._host_session()
	return game

## An open rect room from the fixture library: no pillars, known bounds.
func _open_room() -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dungeon_rooms_rect4.json"))
	var rooms: Array[Dictionary] = Dungeon.generate(7, 3, config)
	var layout: Dictionary = rooms[0].duplicate(true)
	layout.obstacles = []
	return layout

func _enemy(game: Node, point: Vector2) -> Dictionary:
	var enemy: Dictionary = game._create_enemy("chaser", point)
	enemy.hp = 100.0
	enemy.max_hp = 100.0
	return enemy

func _run() -> void:
	_test_class_values_come_from_balance()
	_test_unknown_class_falls_back_to_unchanged_archer()
	_test_perks_build_on_class_base()
	_test_melee_offers_exclude_projectile_only_perks()
	await _test_swing_hits_only_in_front_within_reach()
	await _test_swing_never_hits_through_walls()
	await _test_mage_orb_bursts_for_half_damage_around_impact()
	await _test_lobby_class_action_is_validated_and_survives_run_start()
	finish()

func _balance() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))

func _fresh(class_id: String, balance: Dictionary) -> Dictionary:
	var player := {"pos": Vector2.ZERO, "perks": []}
	PerkRules.initialize_player(player, balance)
	HeroClass.apply(player, class_id, balance)
	return player

func _test_class_values_come_from_balance() -> void:
	# Arrange
	var balance := _balance()
	# Act
	var sword := _fresh("swordsman", balance)
	var bow := _fresh("archer", balance)
	var staff := _fresh("mage", balance)
	# Assert
	check(sword.max_hp == 10 and sword.hp == 10 and is_equal_approx(sword.speed, 148.0) and is_equal_approx(sword.damage, 5.0) and is_equal_approx(sword.shot_interval, 0.4), "swordsman: 5 hearts, speed 148 (20 % slower since 2026-10-28), sword 5 damage every 0.4 s")
	check(sword.melee and is_equal_approx(sword.reach, 64.0) and is_equal_approx(sword.arc, 2.0) and is_zero_approx(sword.shot_speed), "swordsman attacks in melee with the sword's reach and arc")
	check(bow.max_hp == 8 and not bow.melee and is_equal_approx(bow.shot_speed, 600.0) and is_equal_approx(bow.shot_life, 1.2) and bow.projectile == "arrow", "archer: 4 hearts and arrows")
	check(staff.max_hp == 6 and not staff.melee and is_equal_approx(staff.damage, 3.5) and is_equal_approx(staff.splash, 40.0) and staff.projectile == "magic", "mage: 3 hearts and splashing magic orbs")

func _test_unknown_class_falls_back_to_unchanged_archer() -> void:
	# Arrange
	var balance := _balance()
	# Act
	var player := _fresh("does_not_exist", balance)
	# Assert: the default archer equals the pre-class player values.
	check(player.class_id == "archer" and player.max_hp == int(balance.player.hp) and is_equal_approx(player.damage, float(balance.player.damage)) and is_equal_approx(player.shot_interval, float(balance.player.shot_interval)) and is_equal_approx(player.shot_speed, float(balance.bullet.speed)), "an unknown class becomes the default archer with the old player values")

func _test_perks_build_on_class_base() -> void:
	# Arrange
	var balance := _balance()
	var sword := _fresh("swordsman", balance)
	# Act
	PerkRules.grant(sword, PerkRules.find(balance, "ember"), balance)
	# Assert
	check(is_equal_approx(sword.damage, 6.0), "a damage perk adds to the class weapon damage (5 + 1)")

func _test_melee_offers_exclude_projectile_only_perks() -> void:
	# Arrange
	var balance := _balance()
	var sword := _fresh("swordsman", balance)
	var bow := _fresh("archer", balance)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var melee_saw_projectile_only := false
	var ranged_saw_projectile_only := false
	# Act
	for index in range(300):
		for offered: Dictionary in PerkRules.offer(sword, balance, rng):
			if bool(offered.get("projectile_only", false)): melee_saw_projectile_only = true
		for offered: Dictionary in PerkRules.offer(bow, balance, rng):
			if bool(offered.get("projectile_only", false)): ranged_saw_projectile_only = true
	# Assert
	check(not melee_saw_projectile_only, "the swordsman is never offered projectile-only perks")
	check(ranged_saw_projectile_only, "ranged classes still get projectile perks")

func _test_swing_hits_only_in_front_within_reach() -> void:
	# Arrange
	var game = await _new_host()
	game.player_classes[1] = "swordsman"
	game._begin_run()
	game.current_layout = _open_room()
	var player: Dictionary = game.players[1]
	player.pos = Vector2(200, 250)
	var front := _enemy(game, Vector2(250, 250))
	var behind := _enemy(game, Vector2(150, 250))
	var far := _enemy(game, Vector2(300, 250))
	game.enemies = [front, behind, far]
	var swings: int = int(player.get("swings", 0))
	# Act
	game.perk_combat.melee(1, Vector2.RIGHT)
	# Assert
	check(is_equal_approx(front.hp, 95.0), "the swing hits the enemy in front for the sword's damage")
	check(is_equal_approx(behind.hp, 100.0), "the swing misses an enemy behind the swordsman")
	check(is_equal_approx(far.hp, 100.0), "the swing misses an enemy beyond its reach")
	var snapshot: Dictionary = game._make_snapshot()
	check(snapshot.players[1].class_id == "swordsman" and snapshot.players[1].melee and int(snapshot.players[1].swings) == swings + 1 and is_equal_approx(float(snapshot.players[1].swing_angle), 0.0), "the snapshot carries class, weapon and the swing cue for clients")
	# Act: the normal input path (attack button held) swings instead of shooting.
	game.bullets.clear()
	player.shot_timer = 0.0
	game.commands[1] = {"move": Vector2.ZERO, "aim": Vector2.RIGHT, "fire": true, "sequence": 1, "time": Time.get_ticks_msec() / 1000.0}
	game._simulate_players(0.016)
	# Assert
	check(int(player.swings) == swings + 2 and game.bullets.is_empty() and is_equal_approx(front.hp, 90.0), "the attack input makes the swordsman swing, not shoot")
	game._leave_session()
	game.queue_free()
	await process_frame

func _test_swing_never_hits_through_walls() -> void:
	# Arrange
	var game = await _new_host()
	game.player_classes[1] = "swordsman"
	game._begin_run()
	var layout := _open_room()
	layout.obstacles = [[220.0, 220.0, 8.0, 60.0]]
	game.current_layout = layout
	game.players[1].pos = Vector2(200, 250)
	var hidden := _enemy(game, Vector2(245, 250))
	game.enemies = [hidden]
	# Act
	game.perk_combat.melee(1, Vector2.RIGHT)
	# Assert
	check(is_equal_approx(hidden.hp, 100.0), "a wall between swordsman and enemy blocks the swing")
	game._leave_session()
	game.queue_free()
	await process_frame

func _test_mage_orb_bursts_for_half_damage_around_impact() -> void:
	# Arrange
	var game = await _new_host()
	game.player_classes[1] = "mage"
	game._begin_run()
	game.current_layout = _open_room()
	game.players[1].pos = Vector2(200, 250)
	var target := _enemy(game, Vector2(300, 250))
	var neighbour := _enemy(game, Vector2(300, 285))
	var outside := _enemy(game, Vector2(300, 340))
	game.enemies = [target, neighbour, outside]
	game.bullets.clear()
	# Act
	game.perk_combat.shoot(1, Vector2.RIGHT)
	var orb: Dictionary = game.bullets[0] if not game.bullets.is_empty() else {}
	for step in range(40):
		if game.bullets.is_empty(): break
		game._simulate_bullets(0.025)
	# Assert
	check(not orb.is_empty() and orb.get("style", "") == "magic" and is_equal_approx(Vector2(orb.velocity).length(), 380.0), "the mage fires a slower magic orb")
	check(is_equal_approx(target.hp, 100.0 - 3.5 - 1.75), "the hit enemy takes the orb plus half damage from the burst")
	check(is_equal_approx(neighbour.hp, 100.0 - 1.75), "a nearby enemy takes half damage from the burst")
	check(is_equal_approx(outside.hp, 100.0), "enemies outside the burst radius are not hurt")
	game._leave_session()
	game.queue_free()
	await process_frame

func _test_lobby_class_action_is_validated_and_survives_run_start() -> void:
	# Arrange
	var game = await _new_host()
	game._add_player(200)
	# Act / Assert: valid pick in the lobby.
	game.action_times.clear()
	game._server_action(1, "class", 0)
	check(game.players[1].class_id == "swordsman" and game.players[1].max_hp == 10, "a lobby class pick applies the class to that player")
	check(str(game.players[200].get("class_id", "")) == "archer", "another player's class is unchanged")
	game.action_times.clear()
	game._server_action(1, "class", 9)
	check(game.players[1].class_id == "swordsman", "an out-of-range class index is rejected")
	# Act: the run starts; classes persist through the fresh build.
	game._begin_run()
	check(game.players[1].class_id == "swordsman" and game.players[1].hp == 10, "the chosen class survives the run start")
	game.action_times.clear()
	game._server_action(1, "class", 2)
	check(game.players[1].class_id == "swordsman", "classes cannot be changed during a run")
	game._leave_session()
	check(game.player_classes.is_empty(), "leaving the session forgets all class picks")
	game.queue_free()
	await process_frame

func finish() -> void:
	print("HERO_CLASS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if not failures.is_empty() else 0)
