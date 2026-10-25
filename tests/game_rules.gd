extends SceneTree
## Exercises server-side gameplay invariants. This does not replace real peer tests.

const Game = preload("res://src/game.gd")
var failures: Array[String] = []
var checked := 0

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("RULE_FAIL: ", description)

func _initialize() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	check(int(game.balance.network.max_players) == 4, "current player cap is four including the host")
	game.port_input.text = "18890"
	game._host_session()
	check(game.hosting, "host session starts")
	if not game.hosting:
		quit(1)
		return
	game._add_player(200)
	game._server_action(200, "start", 0)
	check(game.phase == "lobby", "remote player cannot start the host's run")
	game._begin_run()
	check(game.phase == "combat" and game.enemies.size() == 3, "first combat room starts")
	game._accept_input(999, Vector2.RIGHT, Vector2.RIGHT, true, 1)
	check(not game.commands.has(999), "unknown peer input is rejected")
	game._accept_input(200, Vector2(NAN, 0), Vector2.RIGHT, true, 1)
	check(not game.commands.has(200), "non-finite movement is rejected")
	game._accept_input(200, Vector2(1000, 1000), Vector2(100, 0), true, 1)
	check(game.commands.has(200), "valid member input is accepted")
	check(game.commands[200].move.length() <= 1.0001, "movement cannot exceed normalized speed")
	check(is_equal_approx(game.commands[200].aim.length(), 1.0), "aim is normalized")
	game._accept_input(200, Vector2.ZERO, Vector2.LEFT, false, 0)
	check(game.commands[200].sequence == 1, "stale input cannot replace a newer command")

	game.phase = "reward"
	game.perk_options = game.balance.perks.slice(0, 3)
	game.action_times.clear()
	game._server_action(200, "perk", 99)
	check(game.players[200].perks.is_empty(), "invalid perk index grants nothing")
	game.action_times.clear()
	game._server_action(200, "perk", 0)
	check(game.players[200].perks.size() == 1 and game.players[200].picked, "one personal perk is granted")
	game.action_times.clear()
	game._server_action(200, "perk", 1)
	check(game.players[200].perks.size() == 1, "duplicate requests cannot grant a second room perk")
	game.action_times.clear()
	game._server_action(200, "ready", 0)
	check(game.room == 1 and game.phase == "reward", "one ready player cannot skip the team's selection")
	game.action_times.clear()
	game._server_action(1, "perk", 0)
	game.action_times.clear()
	game._server_action(1, "ready", 0)
	check(game.room == 2 and game.phase == "combat", "all living ready players advance together")

	game.players[200].hp = 0
	game._spawn_room()
	check(game.players[200].hp == int(ceil(game.players[200].max_hp * 0.5)), "fallen player revives at half health in next room")
	game.players[1].invulnerable = 0.0
	var before: int = game.players[1].hp
	game._damage_player(1, 1)
	game._damage_player(1, 1)
	check(game.players[1].hp == before - 1, "invulnerability prevents immediate repeated damage")
	game.room = game.balance.rooms.enemy_counts.size()
	game.phase = "combat"
	game.enemies.clear()
	game._check_room_end()
	check(game.phase == "reward", "the boss room also grants a personal perk selection")
	for id in game.players:
		game.players[id].picked = true
		game.players[id].ready = true
	game._advance_if_ready()
	check(game.phase == "victory", "final shared readiness completes the run without another room")
	game.phase = "combat"
	for player in game.players.values():
		player.hp = 0
	game._check_room_end()
	check(game.phase == "dead", "team wipe ends the run")
	game._leave_session()
	check(not game.active and game.players.is_empty(), "leaving clears session state")
	print("GAME_RULES checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
