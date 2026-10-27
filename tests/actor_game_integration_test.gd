extends SceneTree
## Focused authority-to-snapshot fixtures; no campaign or load-test claim.

const Game = preload("res://src/game.gd")
var checked: int = 0
var failures: Array[String] = []
var game: Node

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ACTOR_GAME_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.session_bind_ip = "127.0.0.1"
	game.port_input.text = str(45000 + OS.get_process_id() % 10000)
	game.requested_seed = 42026
	game._host_session()
	check(game.hosting and game.active, "owned local host starts")
	_test_skin_slots_and_same_seed_restart()
	_test_motion_is_actual_displacement()
	_test_damage_and_shield_feedback()
	_test_transition_counter()
	_test_enemy_facing_and_motion()
	game._leave_session()
	game.queue_free()
	await process_frame
	print("ACTOR_GAME checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _reset() -> void:
	game.players.clear()
	game.commands.clear()
	game.enemies.clear()
	game.bullets.clear()
	game._transition_state.clear()
	game._transition_request.clear()
	game._last_transition_state.clear()
	game._add_player(1)
	game.players[1].pos = Vector2(128, 256)
	game.players[1].invulnerable = 0.0
	game.players[1].reserve_shield = 0
	game.perk_combat.reset()
	game.phase = "combat"
	game.current_layout = {"id":"actor-integration-fixture", "template_id":"actor-integration-fixture", "generator_version":4, "tile_size":32, "world_size":[1024,768], "play_bounds":[32,32,960,704], "obstacles":[], "exits":[], "boss":false, "title":"Controlled actor fixture", "grid_x":0, "grid_y":0}
	game.floor_layouts.clear()
	game.floor_layouts.append(game.current_layout)
	game.room = 1
	game.floor_index = 1

func _test_skin_slots_and_same_seed_restart() -> void:
	_reset()
	for id: int in [102,103,104]: game._add_player(id)
	var expected: Array[String] = ["player_warden","player_ranger","player_arcanist","player_lizard"]
	var skin_set: Dictionary = {}
	var index: int = 0
	for member: Dictionary in game.players.values():
		check(str(member.skin) == expected[index], "four slots select their authored character " + str(index))
		skin_set[str(member.skin)] = true
		index += 1
	check(skin_set.size() == 4, "all four occupied slots have distinct skins")
	var arcanist: String = str(game.players[103].skin)
	var lizard: String = str(game.players[104].skin)
	game.players.erase(102)
	game._add_player(105)
	check(str(game.players[105].skin) == "player_ranger", "replacement takes the freed ranger slot")
	check(str(game.players[103].skin) == arcanist and str(game.players[104].skin) == lizard, "slot replacement does not rename existing characters")
	var before: Dictionary = {}
	for id: int in game.players: before[id] = str(game.players[id].skin)
	var serial: int = int(game.run_serial)
	game._begin_run()
	check(int(game.run_serial) == serial + 1, "run start increments its independent serial")
	for id: int in before: check(str(game.players[id].skin) == before[id], "run start preserves occupied character slot for peer " + str(id))
	var first: Dictionary = game._make_snapshot(false)
	game._begin_run()
	var restarted: Dictionary = game._make_snapshot(false)
	check(int(restarted.run_seed) == int(first.run_seed) and int(restarted.run_seed) == 42026, "fixed-seed restart keeps the requested dungeon seed")
	check(int(restarted.get("run_serial", -1)) == int(first.get("run_serial", -1)) + 1, "fixed-seed restart serial survives the snapshot")
	for id: int in before: check(str(restarted.players[id].skin) == before[id], "restart preserves character identity for peer " + str(id))

func _test_motion_is_actual_displacement() -> void:
	_reset()
	var delta: float = 0.1
	var start: Vector2 = game.players[1].pos
	game._accept_input(1, Vector2.RIGHT, Vector2.UP, false, 1)
	game._simulate_players(delta)
	var actual: Vector2 = (Vector2(game.players[1].pos) - start) / delta
	var player: Dictionary = game._make_snapshot(false).players[1]
	check(actual.x > 0 and is_zero_approx(actual.y), "accepted input moves the authority on the open floor")
	check(Vector2(float(player.mx), float(player.my)).is_equal_approx(actual), "snapshot motion is actual displacement per second")
	check(bool(player.moving) and is_zero_approx(float(player.ax)) and is_equal_approx(float(player.ay), -1.0), "motion and independent north aim both survive serialization")
	game.commands.clear()
	game.players[1].pos = Vector2(992 - float(game.balance.player.radius), 256)
	game._accept_input(1, Vector2.RIGHT, Vector2.UP, false, 2)
	game._simulate_players(delta)
	player = game._make_snapshot(false).players[1]
	check(Vector2(float(player.mx), float(player.my)).is_zero_approx() and not bool(player.moving), "pressing against the room boundary reports zero actual locomotion")
	game.commands.clear()
	game._simulate_players(delta)
	player = game._make_snapshot(false).players[1]
	check(Vector2(float(player.mx), float(player.my)).is_zero_approx(), "no fresh command cannot retain prior walk motion")

func _test_damage_and_shield_feedback() -> void:
	_reset()
	var hp: int = int(game.players[1].hp)
	game._damage_player(1, 2, Vector2(3, -4))
	var player: Dictionary = game._make_snapshot(false).players[1]
	check(int(player.hp) == hp - 2 and int(player.hurts) == 1, "actual damage changes hearts and the authoritative hurt counter")
	check(is_equal_approx(float(player.last_hit_damage), 2.0), "actual damage magnitude survives serialization")
	check(Vector2(float(player.hit_dx), float(player.hit_dy)).is_equal_approx(Vector2(0.6, -0.8)), "damage direction is normalized before serialization")
	game._damage_player(1, 4, Vector2.DOWN)
	player = game._make_snapshot(false).players[1]
	check(int(player.hurts) == 1 and is_equal_approx(float(player.last_hit_damage), 2), "invulnerability cannot invent another hurt event")
	for shield: String in ["reserve_shield", "shield", "soul_shield"]:
		game.players[1].invulnerable = 0.0
		if shield == "reserve_shield": game.players[1].reserve_shield = 1
		else: game.players[1].perk_runtime[shield] = 1
		var blocks: int = int(game.players[1].blocks)
		game._damage_player(1, 3, Vector2.LEFT)
		player = game._make_snapshot(false).players[1]
		check(int(player.blocks) == blocks + 1 and int(player.hp) == hp - 2 and int(player.hurts) == 1, "absorbed " + shield + " increments block feedback without a flesh hit")

func _test_transition_counter() -> void:
	_reset()
	game.phase = "explore"
	var exit: Dictionary = {"kind":"door", "target_room":1, "rect":[112,240,32,32]}
	game.current_layout.exits = [exit]
	game.players[1].motion = Vector2(60,0)
	game.players[1].moving = true
	game._use_exit(1)
	var player: Dictionary = game._make_snapshot(false).players[1]
	check(int(player.interacts) == 1 and game.is_transitioning(), "a validated nearby exit increments the interaction counter")
	check(Vector2(float(player.mx),float(player.my)).is_zero_approx() and not bool(player.moving), "the transition stops locomotion for the fade")
	game._use_exit(1)
	check(int(game.players[1].interacts) == 1, "a repeated interact during the same transition cannot duplicate its event")

func _test_enemy_facing_and_motion() -> void:
	_reset()
	var enemy: Dictionary = game._create_enemy("skeleton_guard", Vector2(512,384))
	enemy.shot_timer = 10.0
	game.enemies = [enemy]
	var start: Vector2 = enemy.pos
	game._simulate_enemies(0.1)
	var actual: Vector2 = (Vector2(enemy.pos) - start) / 0.1
	var visible: Dictionary = game._make_snapshot(false).enemies[0]
	check(actual.length() > 0 and bool(visible.moving), "real crypt AI locomotion sets the moving state")
	check(Vector2(float(visible.mx),float(visible.my)).is_equal_approx(actual), "enemy motion serializes its actual simulated displacement")
	check(Vector2(float(visible.facing_x),float(visible.facing_y)).is_equal_approx((Vector2(game.players[1].pos)-start).normalized()), "enemy facing serializes the actual target-facing vector")
	game._damage_enemy(enemy, 2.0, Vector2.UP, 1)
	visible = game._make_snapshot(false).enemies[0]
	check(float(visible.last_hit_damage) > 0 and Vector2(float(visible.dx),float(visible.dy)).is_equal_approx(Vector2.UP), "enemy damage magnitude and direction survive serialization")
