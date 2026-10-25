extends SceneTree
## Exercises server-side gameplay invariants. This does not replace real peer tests.

const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
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
	# JSON numbers load as floats; the field once read "7777.0" and solo start failed.
	check(game._port() == int(game.balance.network.port), "the default port field holds a usable integer port")
	check(game.main_menu.visible and game.menu_open, "the game opens on the title screen")
	game.port_input.text = "18890"
	game._host_session()
	check(game.hosting, "host session starts")
	if not game.hosting:
		quit(1)
		return
	game._add_player(200)
	game._server_action(200, "start", 0)
	check(game.phase == "lobby", "remote player cannot start the host's run")
	game.requested_seed = 24680
	game._begin_run()
	var room_count: int = game.floor_layouts.size()
	check(room_count >= 6 and room_count <= 10, "a run has 6-10 rooms")
	check(game.current_layout.kind == "start" and game.phase == "explore" and game.enemies.is_empty(), "the run starts in the empty start room with open doors")
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

	var treasure: int = _first_index(game, "treasure")
	game._enter_room(treasure, "north")
	check(game.phase == "reward" and game.reward_kind == "treasure" and game.enemies.is_empty(), "the treasure room opens a perk choice without enemies")
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
	check(game.room == treasure + 1 and game.phase == "reward", "one ready player cannot skip the team's selection")
	game.action_times.clear()
	game._server_action(1, "perk", 0)
	game.action_times.clear()
	game._server_action(1, "ready", 0)
	check(game.room == treasure + 1 and game.phase == "explore", "all living ready players open the doors together")
	game._enter_room(treasure, "north")
	check(game.phase == "explore" and game.perk_options.size() <= 3 and game.players[1].perks.size() == 1, "a looted treasure room grants no second perk")

	var normal: int = _first_index(game, "normal")
	game.players[200].hp = 0
	game._enter_room(normal, "west")
	check(game.players[200].hp == int(ceil(game.players[200].max_hp * 0.5)), "fallen player revives at half health in a new room")
	check(game.phase == "combat" and game.enemies.size() >= 3 and game.enemies.size() <= 5, "an unvisited normal room locks with 3-5 enemies")
	game.players[1].invulnerable = 0.0
	var before: int = game.players[1].hp
	game._damage_player(1, 1)
	game._damage_player(1, 1)
	check(game.players[1].hp == before - 1, "invulnerability prevents immediate repeated damage")
	var side: String = game.current_layout.doors.keys()[0]
	game.players[1].pos = Dungeon.door_center(side, game.current_layout) - Vector2(Dungeon.DIRECTION_VECTORS[Dungeon.DIRECTION_NAMES.find(side)]) * 12.0
	game._check_doors()
	check(game.room == normal + 1, "doors stay locked while enemies live")
	game.enemies.clear()
	game._check_room_end()
	check(game.phase == "explore" and game.room_states[game.current_layout.id].cleared, "clearing a normal room opens its doors")
	var target: int = game._room_index(game.current_layout.doors[side])
	game._check_doors()
	check(game.room == target + 1, "a player in an open doorway moves the party to the neighbour")
	for id in game.players:
		check(game.players[id].pos.distance_to(Dungeon.entry_point(Dungeon.OPPOSITE[side], game.current_layout)) < 120.0, "the party arrives at the opposite door")
	game._enter_room(normal, Dungeon.OPPOSITE[side])
	check(game.phase == "explore" and game.enemies.is_empty(), "a cleared room never respawns its enemies")

	_test_knockback_and_shooters(game)

	var boss: int = _first_index(game, "boss")
	game._enter_room(boss, "north")
	check(game.phase == "combat" and game.enemies.size() == 1 and game.enemies[0].boss, "the boss room locks with the boss")
	game.enemies.clear()
	game._check_room_end()
	check(game.phase == "reward" and game.reward_kind == "boss", "the boss room also grants a personal perk selection")
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

func _test_knockback_and_shooters(game: Node) -> void:
	var bounds := Rect2(game.current_layout.play_bounds[0], game.current_layout.play_bounds[1], game.current_layout.play_bounds[2], game.current_layout.play_bounds[3])
	var player: Dictionary = game.players[1]
	player.invulnerable = 0.0
	player.pos = Dungeon.entry_point("west", game.current_layout)
	var start: Vector2 = player.pos
	game._damage_player(1, 1, start + Vector2(-20, 0))
	check(player.knock.x > 0.0 and is_zero_approx(player.knock.y), "a hit pushes the player away from the source")
	game.commands.clear()
	game._simulate_players(0.05)
	check(player.pos.x > start.x, "player knockback moves the player")
	player.invulnerable = 0.0
	player.knock = Vector2(-5000, 0)
	for step in range(8): game._simulate_players(0.5)
	check(player.pos.x >= bounds.position.x + 12.0 - 0.01, "knockback never pushes a player through the wall")
	check(is_zero_approx(Vector2(game.players[1].knock).length()), "knockback fades out")

	# An open fixture room isolates combat rules from the template's cover.
	var saved_layout: Dictionary = game.current_layout
	var open_room: Dictionary = saved_layout.duplicate(true)
	open_room.obstacles = []
	game.current_layout = open_room
	game.phase = "combat"
	for id in game.players: game.players[id].pos = Vector2(200, 248)
	var enemy := {"pos": Vector2(600, 248), "hp": 8, "max_hp": 8, "boss": false, "kind": "chaser", "radius": 13.0, "speed": 55.0, "shot_timer": 1.0, "nav_timer": 0.0, "nav_path": PackedVector2Array()}
	game.enemies = [enemy]
	game.bullets.clear()
	game._add_bullet(Vector2(585, 248), Vector2(600, 0), 1, 2)
	game._simulate_bullets(0.02)
	check(enemy.hp == 6 and enemy.knock.x > 0.0 and enemy.hit_timer > 0.0, "a player shot damages, flashes and pushes the enemy back")
	var before_x: float = enemy.pos.x
	game._simulate_enemies(0.05)
	check(enemy.pos.x > before_x, "enemy knockback beats its chase toward the player")

	var shooter := {"pos": Vector2(500, 248), "hp": 6, "max_hp": 6, "boss": false, "kind": "shooter", "radius": 13.0, "speed": 45.0, "shot_timer": 0.0, "nav_timer": 0.0, "nav_path": PackedVector2Array()}
	game.enemies = [shooter]
	game.bullets.clear()
	game._simulate_enemies(0.016)
	check(shooter.attack == "windup" and game.bullets.is_empty(), "a shooter winds up before it fires (anticipation)")
	var planted: Vector2 = shooter.pos
	game._simulate_enemies(0.2)
	check(shooter.pos == planted, "a winding-up shooter stands still")
	game._simulate_enemies(0.25)
	check(shooter.attack == "active" and game.bullets.size() == 1 and game.bullets[0].owner == 0 and game.bullets[0].velocity.x < 0.0, "the projectile spawns on the active frame, aimed at the player")
	for step in range(10): game._simulate_enemies(0.05)
	check(shooter.attack == "" and game.bullets.size() == 1, "the shooter recovers and returns to its cooldown without a second shot")
	for id in game.players: game.players[id].pos = Vector2(440, 248)
	before_x = shooter.pos.x
	game._simulate_enemies(0.1)
	check(shooter.pos.x > before_x, "a crowded shooter backs away to keep its range")

	# Death: the killing blow starts a dying state that neither attacks nor takes hits.
	var victim := {"pos": Vector2(300, 248), "hp": 2, "max_hp": 8, "boss": false, "kind": "shooter", "radius": 13.0, "speed": 45.0, "shot_timer": 0.0, "nav_timer": 0.0, "nav_path": PackedVector2Array()}
	game.enemies = [victim]
	game.bullets.clear()
	for id in game.players: game.players[id].pos = Vector2(200, 248)
	game._hit_enemy(victim, 2, Vector2.RIGHT)
	check(victim.hp == 0 and victim.dying > 0.0 and victim.hits == 1 and victim.knock.x > 0.0, "the killing blow starts the death animation with a final kick")
	game._add_bullet(Vector2(290, 248), Vector2(600, 0), 1, 2)
	game._simulate_bullets(0.02)
	check(game.bullets.size() == 1 and victim.hits == 1, "a dying enemy can no longer be hit")
	game.bullets.clear()
	game._simulate_enemies(0.3)
	check(game.bullets.is_empty() and str(victim.get("attack", "")) == "", "a dying enemy never attacks")
	game.players[1].invulnerable = 0.0
	victim.pos = game.players[1].pos
	var health_before: int = game.players[1].hp
	game._simulate_enemies(0.01)
	check(game.players[1].hp == health_before, "a dying enemy deals no contact damage")
	check(game.enemies.size() == 1, "the corpse stays while its animation runs")
	game.phase = "combat"
	game._check_room_end()
	check(game.phase == "combat", "the room stays locked until the death animation ends")
	game._simulate_enemies(0.5)
	game._simulate_bullets(0.0)
	check(game.enemies.is_empty(), "the enemy is removed once its death animation has finished")

	for layout in game.floor_layouts:
		var kinds: Array[String] = game._enemy_kinds_for(layout)
		check(kinds.size() >= 3 and kinds.size() <= 5 and kinds[0] == "chaser" and kinds.count("shooter") <= 2, "rooms mix 3-5 enemies with at most two shooters")
	game.enemies.clear()
	game.bullets.clear()
	game.current_layout = saved_layout
	game.phase = "explore"

func _first_index(game: Node, kind: String) -> int:
	for i in range(game.floor_layouts.size()):
		if game.floor_layouts[i].kind == kind: return i
	return -1
