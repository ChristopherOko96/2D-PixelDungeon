extends SceneTree
## Exercises free exploration, spatial party transitions and replicated hit feedback.
## Uses a real local host with controlled simulation steps, not a substitute peer.

const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("EXPLORATION_RULE_FAIL: ", description)

func _initialize() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.port_input.text = "18896"
	game._host_session()
	check(game.hosting, "isolated test host starts")
	if not game.hosting:
		_finish(game)
		return
	game._add_player(200)
	game.requested_seed = 32167
	game._begin_run()
	check(game.get("floor_index") == 1, "a new run starts on floor one")
	var initial_snapshot: Dictionary = game._make_snapshot()
	check(initial_snapshot.get("floor_index") == 1 and initial_snapshot.get("cleared_room_ids", []).is_empty(), "snapshot identifies floor one with no cleared rooms")
	var first_id: String = game.current_layout.id
	var first_room: int = game.room
	_action(game, 1, "interact")
	check(game.room == first_room and game.phase == "combat", "interaction cannot skip an uncleared encounter")
	if game.has_method("_damage_enemy"):
		_test_enemy_hit_feedback(game)
	_complete_room(game)
	check(game.phase == "explore" and game.room == first_room, "shared reward readiness unlocks walking without an automatic room transition")
	if game.phase != "explore":
		_finish(game)
		return
	check(first_id in game.get("cleared_room_ids"), "cleared room has persistent identity")
	_test_hit_feedback(game)
	var before: Vector2 = game.players[200].pos
	game.commands.clear()
	game._accept_input(200, Vector2.RIGHT, Vector2.RIGHT, false, 100)
	game._simulate_players(0.05)
	check(game.players[200].pos.x > before.x, "remote player's movement input works after clearing the room")
	var perk_count: int = game.players[200].perks.size()
	_action(game, 200, "perk", 0)
	check(game.players[200].perks.size() == perk_count, "exploration cannot grant another perk")
	var forward: Dictionary = _exit(game.current_layout, "door", 2)
	check(not forward.is_empty(), "cleared first room has a physical door to room two")
	if forward.is_empty():
		_finish(game)
		return
	_move_party(game, Vector2(150, 210))
	_action(game, 1, "interact")
	check(game.room == 1, "interact from the middle of the room cannot teleport the party")
	game.players[1].pos = _exit_center(forward)
	_action(game, 1, "interact")
	check(game.room == 1, "one player at the door cannot pull a distant living teammate")
	game.players[200].hp = 0
	game.players[200].pos = _exit_center(forward)
	_action(game, 200, "interact")
	check(game.room == 1, "fallen players cannot activate a transition")
	_action(game, 1, "interact")
	check(game.room == 2 and game.phase == "combat", "living party enters the next encounter through the door")
	check(game.players[200].hp > 0, "fallen teammate revives only on first entry into a new encounter")
	check(game.players[200].perks.size() == perk_count, "door transition preserves earned perks")
	_complete_room(game)
	var second_id: String = game.current_layout.id
	var back: Dictionary = _exit(game.current_layout, "door", 1)
	_move_party(game, _exit_center(back))
	game.players[200].hp = 0
	_action(game, 1, "interact")
	check(game.room == 1 and game.phase == "explore" and game.enemies.is_empty(), "returning to a cleared room neither respawns an encounter nor freezes walking")
	check(game.players[200].hp == 0, "revisiting a cleared room cannot repeatedly revive teammates")
	check(game.players[1].perks.size() == 2, "backtracking does not grant duplicate rewards")
	game.players[200].hp = 1
	forward = _exit(game.current_layout, "door", 2)
	_move_party(game, _exit_center(forward))
	_action(game, 1, "interact")
	check(game.room == 2 and game.current_layout.id == second_id and game.phase == "explore", "previously cleared destination stays cleared with the same layout ID")
	# The active campaign now has ten rooms; the old third-room boss assumption
	# skipped seven required encounters. Exercise each actual configured doorway.
	var boss_room: int = game.floor_layouts.size()
	for destination in range(3,boss_room+1):
		forward = _exit(game.current_layout, "door", destination)
		check(not forward.is_empty(), "room%d exposes a physical door to room%d" % [game.room,destination])
		if forward.is_empty():
			_finish(game)
			return
		_move_party(game, _exit_center(forward))
		_action(game, 200, "interact")
		check(game.room == destination and game.phase == "combat", "a client activates the shared entrance to room%d" % destination)
		check(bool(game.current_layout.boss) == (destination == boss_room), "only the final configured room is a boss encounter")
		if destination == boss_room:
			# Floor plan: on floor 1 the final room holds a strong group (the
			# Leerenrufer waits on floor 10, see crypt_bosses_test).
			check(game.enemies.filter(func(enemy: Dictionary): return enemy.boss).is_empty() and game.enemies.size() == int(game.balance.enemy_roster.floor_plan.strong_group_count), "the final entrance of floor 1 spawns the strong group")
		_complete_room(game)
	check(game.room == boss_room and game.phase == "explore", "boss reward leaves the complete floor freely explorable")
	var completed_snapshot: Dictionary = game._make_snapshot()
	check(completed_snapshot.floor_map.all(func(value: Dictionary) -> bool: return value.cleared), "the completed floor map marks every room cleared")
	var stairs: Dictionary = _exit(game.current_layout, "stairs", 0)
	check(not stairs.is_empty(), "completed boss arena exposes stairs to the next floor")
	var old_seed: int = completed_snapshot.seed
	var old_perks: Array = game.players[1].perks.duplicate()
	_move_party(game, _exit_center(stairs))
	_action(game, 1, "interact")
	check(game.get("floor_index") == 2 and game.room == 1 and game.phase == "combat", "stairs explicitly start floor two")
	check(int(game._make_snapshot().seed) != old_seed and game.current_layout.id != first_id, "next floor has newly seeded room identities")
	check(game.get("cleared_room_ids").is_empty(), "next floor begins with fresh encounter completion state")
	check(game.players[1].perks == old_perks, "descending preserves the player's build")
	check(game._make_snapshot().get("floor_index") == 2, "snapshot replicates descent to floor two")
	_test_four_player_gate(game)
	_finish(game)

func _test_hit_feedback(game: Node) -> void:
	# Isolate hit physics from room decoration/void ordering. In freeform crypts
	# obstacles[0] may be an outside void at x=0, so a point left of it is invalid.
	# This explicit fixture provides a clear start and a real wall to sweep into.
	var saved_layout: Dictionary = game.current_layout
	var saved_positions: Dictionary = {}
	for id: int in game.players: saved_positions[id] = game.players[id].pos
	game.current_layout = {"id":"hit-feedback-fixture","tile_size":32,"world_size":[896,480],"play_bounds":[32.0,48.0,832.0,400.0],"obstacles":[[320.0,180.0,64.0,120.0]],"exits":[]}
	# Arrange a fresh, vulnerable player with a movement command in a clear area.
	game.players[1].pos = Vector2(75, 105)
	game.players[1].invulnerable = 0.0
	var hp_before: int = game.players[1].hp
	game.commands[1] = {"move": Vector2.RIGHT, "aim": Vector2.RIGHT, "fire": true, "time": Time.get_ticks_msec() / 1000.0}
	game._damage_player(1, 1)
	check(game.players[1].hp == hp_before - 1, "a fresh player hit deals exactly one health damage")
	check(float(game.players[1].get("hitstun", 0.0)) > 0.0 and float(game.players[1].get("hit_flash", 0.0)) > 0.0, "damage sets authoritative hitstun and flash timers")
	var hit_snapshot: Dictionary = game._make_snapshot()
	check(float(hit_snapshot.players[1].get("hitstun", 0.0)) > 0.0 and float(hit_snapshot.players[1].get("hit_flash", 0.0)) > 0.0, "snapshot exposes hit feedback alongside HP")
	var stunned_position: Vector2 = game.players[1].pos
	game.bullets.clear()
	game._simulate_players(0.01)
	check(game.players[1].pos == stunned_position and game.bullets.is_empty(), "brief hitstun blocks movement and shooting")
	game._damage_player(1, 1)
	check(game.players[1].hp == hp_before - 1, "invulnerability prevents a second immediate hit")
	game._simulate_players(2.0)
	check(float(game.players[1].get("hitstun", 0.0)) == 0.0 and float(game.players[1].get("hit_flash", 0.0)) == 0.0, "hit feedback expires rather than locking the player permanently")
	# Knockback still obeys the same solid geometry as ordinary movement.
	var obstacle: Array = game.current_layout.obstacles[0]
	var player_radius: float = game.balance.player.radius
	game.players[1].pos = Vector2(float(obstacle[0]) - player_radius - 0.25, float(obstacle[1]) + float(obstacle[3]) * 0.5)
	check(not Dungeon.segment_blocked(game.players[1].pos,game.players[1].pos,player_radius,game.current_layout), "knockback fixture begins outside the radius-grown wall")
	game.players[1].invulnerable = 0.0
	game.commands.clear()
	game._damage_player(1, 1, Vector2.RIGHT)
	game._simulate_players(0.1)
	check(game.players[1].pos.x < float(obstacle[0]) - player_radius, "hit knockback cannot push the player through a solid wall")
	check(not Dungeon.segment_blocked(game.players[1].pos,game.players[1].pos,player_radius,game.current_layout), "knockback ends in clear actor space rather than inside solid geometry")
	game._simulate_players(2.0)
	game.current_layout = saved_layout
	for id: int in saved_positions: game.players[id].pos = saved_positions[id]

func _test_enemy_hit_feedback(game: Node) -> void:
	var enemy: Dictionary = game.enemies[0].duplicate(true)
	game.enemies = [enemy]
	var hp_before: float = enemy.hp
	game._damage_enemy(enemy, 2.0, Vector2.ZERO)
	check(enemy.hp == hp_before - 2.0, "enemy hit applies projectile damage exactly once")
	check(float(enemy.get("hitstun", 0.0)) > 0.0 and float(enemy.get("hit_flash", 0.0)) > 0.0, "enemy damage creates visible stun and flash")
	var hit_snapshot: Dictionary = game._make_snapshot()
	check(float(hit_snapshot.enemies[0].get("hitstun", 0.0)) > 0.0 and float(hit_snapshot.enemies[0].get("hit_flash", 0.0)) > 0.0, "enemy hit feedback reaches snapshots with its HP")
	var initial_position: Vector2 = enemy.pos
	game._simulate_enemies(0.01)
	check(enemy.pos == initial_position, "a briefly stunned enemy cannot chase during the stun")
	# A boss hit also interrupts for a short readable beat, without emitting a burst.
	enemy.boss = true
	enemy.hp = 70.0
	enemy.max_hp = 70.0
	enemy.radius = float(game.balance.boss.radius)
	enemy.speed = float(game.balance.boss.speed)
	enemy.shot_timer = 0.0
	enemy.hitstun = 0.0
	enemy.stun_cooldown = 0.0
	game.bullets.clear()
	game._damage_enemy(enemy, 1.0, Vector2.ZERO)
	initial_position = enemy.pos
	game._simulate_enemies(0.01)
	check(enemy.pos == initial_position and game.bullets.is_empty(), "boss stun pauses movement and a pending shot burst")
	var remaining_stun: float = enemy.hitstun
	game._damage_enemy(enemy, 1.0, Vector2.ZERO)
	check(is_equal_approx(enemy.hitstun, remaining_stun), "repeated hits during cooldown cannot continuously refresh boss stun")
	game._simulate_enemies(0.1)
	check(enemy.hitstun == 0.0 and enemy.attack == "windup" and game.bullets.is_empty(), "boss resumes attack anticipation while stun cooldown remains active")
	game._simulate_enemies(float(game.balance.attacks.boss.windup)+0.01)
	check(game.bullets.size() == int(game.balance.boss.bullet_count), "boss fires after the visible anticipation interval")

func _test_four_player_gate(game: Node) -> void:
	# Arrange four established members and a cleared first encounter. These are
	# controlled host members; a real four-process run is a separate smoke test.
	game._add_player(201)
	game._add_player(202)
	game._begin_run()
	_complete_room(game)
	check(game.phase == "explore" and game.room == 1 and game.players.size() == 4, "four ready members remain in the cleared room until they use an exit")
	if game.phase != "explore": return
	var door: Dictionary = _exit(game.current_layout, "door", 2)
	if door.is_empty():
		check(false, "four-player scenario has a physical door")
		return
	var center: Vector2 = _exit_center(door)
	var index := 0
	for id: int in game.players:
		game.players[id].pos = Dungeon.entry_for_player(2, index, game.current_layout)
		index += 1
	game.players[1].pos = center
	game.players[202].pos = Vector2(150, 210)
	_action(game, 1, "interact")
	check(game.room == 1, "a distant fourth living member prevents the other three from leaving")
	game.players[202].pos = Dungeon.entry_for_player(2, 3, game.current_layout)
	game.players[202].hitstun = 0.1
	_action(game, 1, "interact")
	check(game.room == 1, "the party cannot leave while its fourth member is stunned")
	game.players[202].hitstun = 0.0
	game.players[1].pos = Dungeon.entry_for_player(2, 0, game.current_layout)
	game.players[201].pos = center
	_action(game, 201, "interact")
	check(game.room == 2 and game.phase == "combat" and game.players.size() == 4, "a nearby client moves all four gathered members into the encounter")
	var arrival: Dictionary = _exit(game.current_layout, "door", 1)
	var unique_positions: Dictionary = {}
	var safe_arrival := not arrival.is_empty()
	for player: Dictionary in game.players.values():
		var position: Vector2 = player.pos
		unique_positions[position] = true
		if Dungeon.segment_blocked(position, position, float(game.balance.player.radius), game.current_layout): safe_arrival = false
		if position.distance_to(_exit_center(arrival)) <= float(game.balance.exploration.interaction_radius): safe_arrival = false
	check(safe_arrival and unique_positions.size() == 4, "all four entry slots are distinct, outside solids and beyond the immediate return trigger")

func _complete_room(game: Node) -> void:
	game.enemies.clear()
	game._check_room_end()
	check(game.phase == "reward", "defeating the room presents the personal reward phase")
	for id: int in game.players:
		if game.players[id].hp <= 0: continue
		_action(game, id, "perk", 0)
		_action(game, id, "ready")

func _action(game: Node, id: int, action: String, value: int = 0) -> void:
	game.action_times.clear()
	game._server_action(id, action, value)
	if not game._transition_state.is_empty():
		game._step_transition(1.0)
		for frame in range(12): game.transition_view.update(0.1)

func _exit(layout: Dictionary, kind: String, target: int) -> Dictionary:
	for value: Dictionary in layout.get("exits", []):
		if value.kind == kind and int(value.target_room) == target:
			return value
	return {}

func _exit_center(exit: Dictionary) -> Vector2:
	var values: Array = exit.get("rect", [0, 0, 0, 0])
	return Vector2(float(values[0]) + float(values[2]) * 0.5, float(values[1]) + float(values[3]) * 0.5)

func _move_party(game: Node, position: Vector2) -> void:
	game.commands.clear()
	for id: int in game.players:
		game.players[id].pos = position

func _finish(game: Node) -> void:
	game._leave_session()
	game.queue_free()
	print("EXPLORATION_RULES checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
