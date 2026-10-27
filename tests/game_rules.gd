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
	_test_exp_and_levels(game)
	_test_boss_moves(game)
	_test_beam_dodge(game)
	_test_endless(game)
	_test_golem_and_mobs(game)
	_test_infernal(game)
	_test_classes_and_loot(game)
	_test_orcs_and_depth(game)
	_test_minibosses_and_decor(game)

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
	game.enemies = [{"pos": Vector2(300, 248), "hp": 50, "max_hp": 50, "boss": true, "kind": "boss", "attack": "active", "move": "beam", "airborne": true}]
	game._check_room_end()
	check(game.phase == "dead", "team wipe ends the run")
	check(game.enemies[0].attack == "" and not game.enemies[0].airborne, "a team wipe ends the boss's attack, so no beam freezes on screen")
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

	var shooter := {"pos": Vector2(500, 248), "hp": 6, "max_hp": 6, "boss": false, "aggro": true, "kind": "shooter", "radius": 13.0, "speed": 45.0, "shot_timer": 0.0, "nav_timer": 0.0, "nav_path": PackedVector2Array()}
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
		var ranged := 0
		for kind in kinds:
			if game.balance.story_floor.ranged.has(kind): ranged += 1
		check(kinds.size() >= 3 and kinds.size() <= 5 and game.balance.story_floor.melee.has(kinds[0]) and ranged <= 2, "rooms mix 3-5 enemies with at most two ranged ones")
	game.enemies.clear()
	game.bullets.clear()
	game.current_layout = saved_layout
	game.phase = "explore"

func _open_room(game: Node) -> Dictionary:
	var saved: Dictionary = game.current_layout
	var open_room: Dictionary = saved.duplicate(true)
	open_room.obstacles = []
	game.current_layout = open_room
	game.enemies.clear()
	game.bullets.clear()
	game.orbs.clear()
	return saved

func _enemy(kind: String, pos: Vector2, hp: int, id: int) -> Dictionary:
	return {"pos": pos, "hp": hp, "max_hp": hp, "boss": kind == "boss", "kind": kind, "radius": 24.0 if kind == "boss" else 13.0, "speed": 35.0, "shot_timer": 0.0, "nav_timer": 0.0, "nav_path": PackedVector2Array(), "id": id}

func _orb_total(game: Node) -> int:
	var total := 0
	for orb in game.orbs: total += int(orb.value)
	return total

func _test_exp_and_levels(game: Node) -> void:
	var saved_layout := _open_room(game)
	game.phase = "combat"
	var player: Dictionary = game.players[1]
	for id in game.players: game.players[id].pos = Vector2(760, 400)
	var victim := _enemy("chaser", Vector2(300, 248), 2, 50)
	game.enemies = [victim]
	game._hit_enemy(victim, 2, Vector2.RIGHT)
	var dropped: int = game.orbs.size()
	check(dropped >= 2 and _orb_total(game) == int(game.balance.exp.chaser), "a dying goblin drops its EXP as several orbs")
	game._drop_exp(victim)
	game._add_bullet(Vector2(290, 248), Vector2(600, 0), 1, 2)
	game._simulate_bullets(0.02)
	check(game.orbs.size() == dropped, "the same death never drops EXP twice")
	for step in range(30): game._simulate_orbs(1.0 / 30.0)
	check(game.orbs.size() == dropped and int(player.exp) == 0, "orbs out of reach stay on the floor during combat")
	var pickups := int(player.pickups)
	player.pos = Vector2(330, 250)
	for step in range(60): game._simulate_orbs(1.0 / 30.0)
	check(game.orbs.is_empty() and int(player.exp) == int(game.balance.exp.chaser) and int(player.pickups) == pickups + dropped, "nearby orbs are pulled in, collected and credited at once")

	player.hp = 5
	player.level = 1
	player.exp = 0
	var level_ups := int(player.level_ups)
	game._collect_orb(1, {"value": 100 + 283 + 7})
	check(player.level == 3 and player.exp == 7 and int(player.level_ups) == level_ups + 2, "one pickup can grant several level-ups, with the surplus kept")
	check(player.hp == mini(player.max_hp, 5 + 2 * int(game.balance.leveling.heal)), "each level-up heals a little")
	var entry: Dictionary = game._make_snapshot().players[1]
	check(entry.level == 3 and entry.exp == 7 and entry.exp_next == 520 and entry.stats.level == 3, "the snapshot carries level, EXP and the next threshold")
	game._grant_perk(1, {"id": "test", "stat": "damage", "amount": 1})
	check(is_equal_approx(float(game._make_snapshot().players[1].stats.damage), float(player.damage)), "stats in the snapshot follow an upgrade at once")
	player.perks.pop_back()

	# A calm room pulls every orb in, wherever it lies.
	game.phase = "explore"
	game.calm_clock = 0.0
	game.orbs = [{"id": 900, "pos": Vector2(800, 100), "vel": Vector2.ZERO, "value": 3, "age": 1.0}]
	player.pos = Vector2(100, 400)
	for step in range(150): game._simulate_orbs(1.0 / 30.0)
	check(game.orbs.is_empty(), "after a cleared room every orb flies to a player")
	game.orbs = [{"id": 901, "pos": Vector2(800, 100), "vel": Vector2.ZERO, "value": 4, "age": 0.0}]
	pickups = int(game.players[1].pickups) + int(game.players[200].pickups)
	game.current_layout = saved_layout
	game._enter_room(0, "")
	check(game.orbs.is_empty() and int(game.players[1].pickups) + int(game.players[200].pickups) == pickups + 1, "orbs left behind are credited when the party leaves")
	game.players[1].hp = game.players[1].max_hp

func _test_boss_moves(game: Node) -> void:
	var saved_layout := _open_room(game)
	var bounds := Rect2(game.current_layout.play_bounds[0], game.current_layout.play_bounds[1], game.current_layout.play_bounds[2], game.current_layout.play_bounds[3])
	var moves: Dictionary = game.balance.boss_moves
	game.phase = "combat"
	for id in game.players:
		game.players[id].pos = Vector2(200, 248)
		game.players[id].move = Vector2.ZERO
		game.players[id].invulnerable = 99.0
	var boss := _enemy("boss", Vector2(600, 248), 94, 77)
	game.enemies = [boss]
	game._simulate_enemies(0.016)
	check(boss.attack == "windup" and boss.move == "volley" and game.bullets.is_empty(), "the boss opens with a telegraphed volley")
	while boss.attack == "windup": game._simulate_enemies(0.02)
	check(game.bullets.size() == int(moves.volley.count), "the volley fires its full fan on the active frame")
	while boss.attack == "active": game._simulate_enemies(0.02)
	check(game.bullets.size() == 2 * int(moves.volley.count) - 1, "a second fan fills the gaps of the first")

	# Lead aiming: a player running downwards is shot where they will be.
	game.bullets.clear()
	game.players[1].move = Vector2.DOWN
	game._fire_fan(boss, moves.volley, 1, false)
	check(game.bullets[int(moves.volley.count) / 2].velocity.y > 1.0, "the volley leads a moving player instead of aiming at them")
	game.players[1].move = Vector2.ZERO

	# Every move of the sequence shows up; the beam stays locked at full health.
	var seen := {}
	game.bullets.clear()
	boss.attack = ""
	boss.shot_timer = 0.0
	for step in range(500):
		for id in game.players:
			game.players[id].invulnerable = 99.0
		game._simulate_enemies(0.05)
		game._simulate_bullets(0.05)
		if boss.attack != "": seen[boss.move] = true
	check(seen.has("volley") and seen.has("rings") and seen.has("charge") and seen.has("slam"), "the boss cycles through volley, rings, charge and jump")
	check(not seen.has("beam"), "the ultimate beam is locked while the boss is healthy")
	boss.hp = boss.max_hp

	# Jump: airborne the boss cannot be hit; the landing hurts and throws a ring.
	game.bullets.clear()
	boss.pos = Vector2(600, 248)
	boss.knock = Vector2.ZERO
	boss.move = "slam"
	boss.attack = "windup"
	boss.attack_time = 0.01
	game._boss_begin(boss, Vector2(400, 248))
	for id in game.players:
		game.players[id].pos = Vector2(400, 248)
		game.players[id].invulnerable = 0.0
		game.players[id].hp = game.players[id].max_hp
	game._simulate_enemies(0.02)
	game._simulate_enemies(0.2)
	var hits := int(boss.get("hits", 0))
	check(boss.attack == "active" and boss.airborne and float(boss.air) > 0.3, "the boss leaves the ground on its jump")
	game._add_bullet(boss.pos + Vector2(-20, 0), Vector2(600, 0), 1, 2)
	game._simulate_bullets(0.02)
	check(int(boss.get("hits", 0)) == hits, "shots pass under the jumping boss")
	var impacts := int(boss.get("impacts", 0))
	while boss.attack == "active":
		for id in game.players: game.players[id].pos = Vector2(400, 248)
		game._simulate_enemies(0.02)
	check(not boss.airborne and int(boss.impacts) == impacts + 1 and boss.pos.distance_to(Vector2(400, 248)) < 40.0, "the boss lands on the marked spot")
	check(game.players[1].hp == game.players[1].max_hp - int(moves.slam.damage), "the landing shockwave costs a full heart")
	check(game.bullets.size() >= int(moves.slam.count), "the landing throws a ring of debris")

	# Charge: runs along the locked lane and crashes into the wall.
	game.bullets.clear()
	boss.pos = Vector2(360, 248)
	boss.move = "charge"
	boss.attack = "windup"
	# Already past the lock: the lane stays aimed at the west wall.
	boss.attack_time = 0.2
	game._boss_begin(boss, Vector2(100, 248))
	for id in game.players:
		game.players[id].pos = Vector2(300, 420)
		game.players[id].invulnerable = 99.0
	impacts = int(boss.impacts)
	var guard := 0
	while (boss.attack == "windup" or boss.attack == "active") and guard < 200:
		game._simulate_enemies(0.02)
		guard += 1
	check(boss.attack == "recovery" and int(boss.impacts) == impacts + 1, "a charge that hits the wall crashes and stops")
	check(boss.pos.x < bounds.position.x + 40.0, "the charge carried the boss across the room")
	var parked: Vector2 = boss.pos
	game._simulate_enemies(0.3)
	check(boss.pos == parked, "the boss is stunned after the crash (the opening)")

	# Ultimate: below the threshold the beam comes next and hurts along its line.
	game.bullets.clear()
	boss.pos = Vector2(600, 248)
	boss.attack = ""
	boss.shot_timer = 0.0
	boss.hp = int(boss.max_hp * float(game.balance.boss.ultimate.hp_ratio)) - 1
	for id in game.players:
		game.players[id].invulnerable = 99.0
		game.players[id].hp = game.players[id].max_hp
	game.players[1].pos = Vector2(450, 248)
	game.players[200].pos = Vector2(100, 420)
	game._simulate_enemies(0.016)
	check(boss.move == "beam" and boss.attack == "windup", "a hurt boss unleashes its ultimate beam")
	while boss.attack == "windup":
		game.players[1].pos = Vector2(450, 248)
		game.players[200].pos = Vector2(100, 420)
		game._simulate_enemies(0.02)
	for id in game.players: game.players[id].invulnerable = 0.0
	for step in range(5):
		game.players[1].pos = Vector2(450, 248)
		game.players[200].pos = Vector2(100, 420)
		game._simulate_enemies(0.02)
	check(game.players[1].hp == game.players[1].max_hp - int(moves.beam.damage), "standing in the beam costs a full heart")
	check(game.players[200].hp == game.players[200].max_hp, "a player beside the beam is safe")
	game.players[1].invulnerable = 0.0
	game._simulate_enemies(0.02)
	check(game.players[1].hp == game.players[1].max_hp - int(moves.beam.damage), "one beam hits each player only once")
	check(Vector2(boss.beam_end).x <= bounds.position.x + 13.0, "the beam reaches the wall behind its target")
	var snapshot_boss: Dictionary = game._make_snapshot().enemies[0]
	check(snapshot_boss.move == "beam" and snapshot_boss.attack == "active" and snapshot_boss.has("bx"), "the snapshot carries the beam for the animation")
	game.players[1].pos = Vector2(450, 100)
	var angle_before := float(boss.beam_angle)
	game._simulate_enemies(0.1)
	check(absf(angle_difference(angle_before, float(boss.beam_angle))) <= float(moves.beam.turn_rate) * 0.1 + 0.001, "the beam turns slowly enough to outrun")
	for step in range(150): game._simulate_enemies(0.02)
	check(absf(angle_difference(float(boss.beam_fired), float(boss.beam_angle))) <= float(moves.beam.max_sweep) + 0.001, "the beam never sweeps further than its limit")
	var beams := 0
	boss.since_ultimate = 0
	for i in range(int(game.balance.boss.ultimate.every) + 1):
		if game._next_boss_move(boss) == "beam": beams += 1
	check(beams == 1, "the beam repeats only every few moves")

	game.orbs.clear()
	game._hit_enemy(boss, 999, Vector2.RIGHT)
	check(_orb_total(game) >= int(game.balance.exp.boss) and not boss.get("airborne", false), "the boss drops its big EXP reward when it dies")
	for id in game.players:
		game.players[id].invulnerable = 0.0
		game.players[id].hp = game.players[id].max_hp
	game.enemies.clear()
	game.bullets.clear()
	game.orbs.clear()
	game.current_layout = saved_layout
	game.phase = "explore"

## Goblins and orcs, their warlord, and the deeper floors: more creatures per
## room and elites with an extra attack.
func _test_orcs_and_depth(game: Node) -> void:
	var saved_layout := _open_room(game)
	game.phase = "combat"
	game.endless = true
	game.floor_number = 3
	check(game._floor_roster().boss == "hell_prince" and game._floor_roster().melee.has("chort"), "endless floor 3 is hell with Azrakor")
	for id in game.players:
		game.players[id].pos = Vector2(300, 248)
		game.players[id].invulnerable = 99.0
	var kinds := ["g_cutthroat", "g_spearman", "g_archer", "g_shieldbearer", "g_bomber", "g_trapper", "g_shaman", "g_captain", "o_brute",
		"g_hunter", "g_phalanx", "g_flailer", "o_bonecaller", "o_berserker", "o_chieftain", "o_blackknight"]
	for kind in kinds:
		game.enemies.clear()
		game.bullets.clear()
		game.abilities.clear()
		var orc: Dictionary = game._spawn_enemy(kind, Vector2(400, 248), 0)
		var hurt_ally: Dictionary = game._spawn_enemy("g_skirmisher", Vector2(430, 300), 1)
		hurt_ally.hp = 1
		hurt_ally.speed = 0.0
		orc.shot_timer = 0.0
		var acted := false
		for step in range(150):
			game._simulate_enemies(0.02)
			game.abilities.update(0.02)
			if int(orc.get("attacks", 0)) > 0: acted = true
		check(acted, "the %s uses its ability" % kind)
	check(game.balance.mobs.g_skirmisher.speed > game.balance.mobs.o_brute.speed, "skirmishers are fast, brutes slow")

	# Shields stop shots from the front, not from behind, and never a sword.
	game.enemies.clear()
	game.bullets.clear()
	var guard: Dictionary = game._spawn_enemy("g_shieldbearer", Vector2(500, 248), 0)
	guard.face = -1.0
	game._add_bullet(Vector2(470, 248), Vector2(600, 0), 1, 2)
	for step in range(4): game._simulate_bullets(0.02)
	check(guard.hp == guard.max_hp and int(guard.get("blocks", 0)) == 1, "a shield blocks a shot from the front")
	game._add_bullet(Vector2(530, 248), Vector2(-600, 0), 1, 2)
	for step in range(4): game._simulate_bullets(0.02)
	check(guard.hp < guard.max_hp, "a shot from behind gets through")
	var hero: Dictionary = game.players[1]
	game.Loadout.apply_class(hero, "swordsman", game.balance)
	hero.pos = Vector2(460, 248)
	var before: int = guard.hp
	game._swing(1, Vector2.RIGHT)
	check(guard.hp < before, "a sword swing beats the shield")
	game.Loadout.apply_class(hero, game.balance.default_class, game.balance)

	# Healer, war cry, trap, rage.
	game.enemies.clear()
	var shaman: Dictionary = game._spawn_enemy("g_shaman", Vector2(500, 248), 0)
	var wounded: Dictionary = game._spawn_enemy("o_brute", Vector2(540, 248), 1)
	wounded.hp = 5
	game.abilities.fire(shaman, game.balance.attacks.g_shaman, 1)
	check(wounded.hp == 5 + int(game.balance.attacks.g_shaman.amount), "the goblin shaman heals a hurt ally")
	game.abilities.fire(game._spawn_enemy("g_captain", Vector2(520, 270), 2), game.balance.attacks.g_captain, 1)
	check(float(wounded.haste) > 0.0 and float(shaman.haste) > 0.0, "the captain's war cry hurries the allies around")
	game.abilities.clear()
	var trapper: Dictionary = game._spawn_enemy("g_trapper", Vector2(600, 248), 3)
	hero.pos = Vector2(300, 248)
	game.abilities.fire(trapper, game.balance.attacks.g_trapper, 1)
	var trap: Dictionary = game.abilities.hazards[0]
	check(trap.kind == "trap" and trap.state == "armed", "the trapper sets an armed bear trap")
	hero.invulnerable = 0.0
	var hp: int = hero.hp
	hero.pos = trap.pos
	game.abilities.update(0.02)
	check(hero.hp < hp and float(hero.rooted) > 0.0, "stepping into the trap hurts and holds the player")
	game.commands[1] = {"move": Vector2.RIGHT, "aim": Vector2.RIGHT, "fire": false, "sequence": 9999, "time": Time.get_ticks_msec() / 1000.0}
	hero.knock = Vector2.ZERO
	var held: Vector2 = hero.pos
	game._simulate_players(0.1)
	check(hero.pos == held, "a trapped player cannot walk away at once")
	game.commands.clear()
	hero.rooted = 0.0
	hero.hp = hero.max_hp
	hero.invulnerable = 99.0
	# Aggro in the running game: an unaware enemy far away stands still until hit.
	var sleeper: Dictionary = game._spawn_enemy("chaser", Vector2(820, 420), 3)
	var sleeper_start: Vector2 = sleeper.pos
	game._simulate_enemies(0.2)
	check(sleeper.pos == sleeper_start and not sleeper.aggro, "an enemy that has not noticed anyone stays put")
	game._hit_enemy(sleeper, 1.0, Vector2.RIGHT, 1)
	check(sleeper.aggro and sleeper.aggro_target == 1, "a hit wakes the enemy and locks it onto the shooter")
	game.enemies.erase(sleeper)
	var berserker: Dictionary = game._spawn_enemy("o_berserker", Vector2(700, 248), 4)
	berserker.hp = int(berserker.max_hp / 3)
	berserker.aggro = true
	game._simulate_enemies(0.02)
	check(berserker.get("raging", false), "a hurt berserker flies into a rage")

	# Depth: more creatures and elites with an extra attack.
	var shallow := 0
	var deep := 0
	for layout in game.floor_layouts:
		game.floor_number = 1
		shallow += game._enemy_kinds_for(layout).size()
		game.floor_number = 7
		deep += game._enemy_kinds_for(layout).size()
	check(deep > shallow, "deeper floors put more creatures in a room")
	game.floor_number = 50
	for layout in game.floor_layouts:
		check(game._enemy_kinds_for(layout).size() <= int(game.balance.depth.max_enemies), "rooms never exceed the creature limit")
	game.enemies.clear()
	game.bullets.clear()
	var elite: Dictionary = game._spawn_enemy("g_hunter", Vector2(500, 248), 0)
	var normal_hp: int = elite.max_hp
	game._make_elite(elite)
	check(elite.elite and elite.max_hp > normal_hp, "an elite is tougher")
	elite.shot_timer = 0.0
	for step in range(80): game._simulate_enemies(0.02)
	check(game.bullets.size() >= int(game.balance.attacks.g_hunter.count) + int(game.balance.depth.elite_ring), "an elite adds a ring of shots to its attack")
	game.floor_number = 7
	var deep_hunter: Dictionary = game._spawn_enemy("g_hunter", Vector2(500, 248), 0)
	check(int(deep_hunter.extra_shots) >= 2, "deep floors give fans extra shots")

	# Grumskar.
	game.enemies.clear()
	game.bullets.clear()
	game.abilities.clear()
	game.floor_number = 3
	var warlord: Dictionary = game._spawn_enemy("o_warlord", Vector2(600, 248), 0)
	check(warlord.boss and game._make_snapshot().boss_bar.name == game.balance.o_warlord.name, "Grumskar is a boss with his name on the bar")
	var seen := {}
	for step in range(1200):
		for id in game.players:
			game.players[id].invulnerable = 99.0
			game.players[id].hp = game.players[id].max_hp
		game._simulate_enemies(0.05)
		game.abilities.update(0.05)
		game._simulate_bullets(0.05)
		if warlord.attack != "": seen[warlord.move] = true
		if game.enemies.size() > 6: game.enemies = [warlord]
	for move in ["cleave", "charge", "warcry", "axe", "quake"]:
		check(seen.has(move), "Grumskar uses his %s" % move)
	for id in game.players:
		game.players[id].invulnerable = 0.0
		game.players[id].hp = game.players[id].max_hp
	game.enemies.clear()
	game.bullets.clear()
	game.abilities.clear()
	game.endless = false
	game.floor_number = 1
	game.current_layout = saved_layout
	game.phase = "explore"

## Hero classes in play: the sword hits a cone, arrows pierce, magic splashes,
## weapons are found and picked up, and level-ups offer class abilities.
func _test_classes_and_loot(game: Node) -> void:
	var saved_layout := _open_room(game)
	game.phase = "combat"
	game.loot = []
	var hero: Dictionary = game.players[1]
	game.Loadout.apply_class(hero, "swordsman", game.balance)
	hero.pos = Vector2(400, 248)
	var front := _enemy("chaser", Vector2(450, 248), 50, 300)
	var behind := _enemy("chaser", Vector2(350, 248), 50, 301)
	var far := _enemy("chaser", Vector2(560, 248), 50, 302)
	game.enemies = [front, behind, far]
	game._swing(1, Vector2.RIGHT)
	check(front.hp < 50 and behind.hp == 50 and far.hp == 50, "a sword swing hits in front within reach only")
	game.Loadout.apply_ability(hero, "whirl", game.balance)
	game._swing(1, Vector2.RIGHT)
	check(behind.hp < 50 and far.hp == 50, "Whirlwind Blade hits all around")
	game.bullets.clear()
	game._add_bullet(Vector2(430, 248), Vector2(-100, 0), 0, 1)
	game.Loadout.apply_ability(hero, "parry", game.balance)
	game._swing(1, Vector2.RIGHT)
	check(game.bullets.is_empty(), "Parry cuts enemy shots out of the air")

	game.enemies = [_enemy("chaser", Vector2(480, 248), 50, 310), _enemy("chaser", Vector2(540, 248), 50, 311)]
	game.bullets.clear()
	game.Loadout.apply_class(hero, "archer", game.balance)
	game.Loadout.apply_ability(hero, "pierce", game.balance)
	game._shoot(1, Vector2.RIGHT)
	for step in range(20): game._simulate_bullets(0.02)
	check(game.enemies[0].hp < 50 and game.enemies[1].hp < 50, "a piercing arrow hits two enemies in a row")
	game.bullets.clear()
	game.Loadout.apply_ability(hero, "multishot", game.balance)
	game._shoot(1, Vector2.RIGHT)
	check(game.bullets.size() == 2 and game.bullets[0].kind == "arrow", "Multishot fires an extra arrow")

	game.enemies = [_enemy("chaser", Vector2(480, 248), 50, 320), _enemy("chaser", Vector2(480, 290), 50, 321)]
	game.bullets.clear()
	game.Loadout.apply_class(hero, "mage", game.balance)
	game._shoot(1, Vector2.RIGHT)
	for step in range(30): game._simulate_bullets(0.02)
	check(game.enemies[0].hp < 50 and game.enemies[1].hp < 50, "a magic orb explodes and hurts enemies nearby")

	# Double Cast: a second volley follows a moment later.
	game.enemies.clear()
	game.bullets.clear()
	game.Loadout.apply_class(hero, "mage", game.balance)
	game.Loadout.apply_ability(hero, "double", game.balance)
	game.commands.clear()
	game._shoot(1, Vector2.RIGHT)
	check(game.bullets.size() == 1, "the first spell flies at once")
	for step in range(8): game._simulate_players(0.02)
	check(game.bullets.size() == 2, "Double Cast sends a second spell right after")
	game.bullets.clear()

	# Chests: sometimes in a cleared room; touching one gives a small boost.
	game.Loadout.apply_class(hero, "archer", game.balance)
	game.loot.clear()
	game.loot.append({"id": 77, "pos": hero.pos + Vector2(8, 0), "open": false})
	hero.hp = hero.max_hp - 2
	var fields := ["damage", "speed", "max_hp", "hp", "shot_interval", "range", "shot_speed", "luck"]
	var before_stats := {}
	for field in fields: before_stats[field] = hero.get(field, 0)
	game._open_chests()
	check(game.loot[0].open and int(hero.boosts) == 1 and not str(hero.boost_text).is_empty(), "walking into a chest opens it and grants a boost")
	var changed := false
	for field in fields:
		if not is_equal_approx(float(hero.get(field, 0)), float(before_stats[field])): changed = true
	check(changed, "the boost changes one of the hero's stats")
	game._open_chests()
	check(int(hero.boosts) == 1, "an open chest gives nothing more")
	var found := 0
	for layout in game.floor_layouts:
		game.current_layout = layout
		game.loot = []
		game._maybe_place_chest()
		found += game.loot.size()
	game.current_layout = game.floor_layouts[0]
	check(found > 0 and found < game.floor_layouts.size() + 1, "chests turn up in some rooms")
	game.loot.clear()

	# Level-up: an offer of class abilities, chosen by key.
	hero.choices = []
	hero.pending_choices = 0
	game._on_level_up(1)
	check(hero.choices.size() == 3, "a level-up offers three abilities")
	var chosen: String = hero.choices[0]
	game.action_times.clear()
	game._server_action(1, "ability", 0)
	check(game.Loadout.stacks(hero, chosen) == 1 and hero.choices.is_empty(), "choosing an ability applies it")
	var cards: Array = game._make_snapshot().players[1].choices
	check(cards.is_empty(), "no cards stay after the choice")

	# Shield: the mage's arcane shield swallows one hit.
	game.Loadout.apply_class(hero, "mage", game.balance)
	game.Loadout.apply_ability(hero, "shield", game.balance)
	hero.invulnerable = 0.0
	var hp: int = hero.hp
	game._damage_player(1, 2, hero.pos + Vector2(10, 0))
	check(hero.hp == hp and hero.shield_timer > 0.0, "the arcane shield blocks a hit, then recharges")
	game.Loadout.apply_class(hero, game.balance.default_class, game.balance)
	hero.invulnerable = 0.0
	game.enemies.clear()
	game.bullets.clear()
	game.loot.clear()
	game.current_layout = saved_layout
	game.phase = "explore"


## The infernal creatures and Molgrax: rosters, abilities and the boss bar.
func _test_infernal(game: Node) -> void:
	var saved_layout := _open_room(game)
	game.phase = "combat"
	game.endless = true
	game.floor_number = 1
	check(game._floor_roster().boss == "rot_king" and game._floor_roster().melee.has("tiny_zombie"), "endless floor 1 is the crypt with Morgrul and the undead")
	game.endless = false
	check(game._floor_roster().boss == "hell_prince" and game._floor_roster().melee.has("chaser") and game._floor_roster().melee.has("imp"), "the story keeps goblins and imps with Azrakor")
	# Only the new bosses lead a floor; the old ones are gone from every roster.
	var new_bosses := ["seraph", "rot_king", "hell_prince", "ogre_warchief"]
	var new_minis := ["winged_chort", "soul_caller", "crystal_wogol", "golden_angel"]
	var all_rosters: Array = [game.balance.story_floor] + game.balance.floors
	check(all_rosters.all(func(roster: Dictionary) -> bool: return new_bosses.has(str(roster.boss)) and new_minis.has(str(roster.miniboss))), "every floor uses only the new bosses and mini-bosses")
	var seraph: Dictionary = game._spawn_enemy("seraph", Vector2(400, 240), 0)
	check(seraph.boss and seraph.max_hp >= 220 and str(game._definition("seraph").name).begins_with("SERAPHIEL"), "a new floor boss spawns as a boss with its own stats")
	seraph.move = "lightfan"
	check(str(game._attack_for(seraph).get("projectile", "")) == "spear", "a new boss's move comes from its own move list")
	game.enemies.erase(seraph)
	# Only 0x72 pixel monsters spawn as normal enemies, on every floor.
	var pixel_kinds := ["chaser", "shooter", "imp", "skelet", "necromancer", "tiny_zombie", "chort", "wogol", "doc", "pumpkin_dude", "big_zombie", "angel",
		"o_brute", "o_berserker", "o_chieftain"]
	var rosters: Array = [game.balance.story_floor] + game.balance.floors
	check(rosters.all(func(roster: Dictionary) -> bool: return (roster.melee + roster.ranged).all(func(kind: Variant) -> bool: return pixel_kinds.has(str(kind)))), "every floor spawns only 0x72 pixel monsters")
	game.endless = true
	for id in game.players:
		game.players[id].pos = Vector2(300, 248)
		game.players[id].invulnerable = 99.0
	var kinds := ["glutling", "schattling", "funkenball", "blutqualle", "stachelwaechter", "leerenpriester", "krabbenteufel", "fackelteufel"]
	for kind in kinds:
		game.enemies.clear()
		game.bullets.clear()
		game.abilities.clear()
		var creature: Dictionary = game._spawn_enemy(kind, Vector2(420, 248), 0)
		creature.shot_timer = 0.0
		var acted := false
		for step in range(120):
			game._simulate_enemies(0.02)
			game.abilities.update(0.02)
			if not game.bullets.is_empty() or not game.abilities.hazards.is_empty() or creature.get("dashing", false): acted = true
		check(acted, "the %s uses its attack" % kind)
		check(creature.max_hp < int(game.balance.molgrax.hp) / 4, "the %s is far weaker than the boss" % kind)
	game.enemies.clear()
	var blob: Dictionary = game._spawn_enemy("glutling", Vector2(500, 248), 0)
	game.abilities.clear()
	game._hit_enemy(blob, 999, Vector2.RIGHT)
	check(game.abilities.hazards.size() == 1 and game.abilities.hazards[0].kind == "fire", "an ember blob leaves a fire patch when it dies")

	game.enemies.clear()
	game.abilities.clear()
	var molgrax: Dictionary = game._spawn_enemy("molgrax", Vector2(600, 248), 0)
	var bar: Dictionary = game._make_snapshot().boss_bar
	check(bar.name == game.balance.molgrax.name and bar.hp == molgrax.max_hp, "the boss bar names the boss and shows full health")
	game._hit_enemy(molgrax, 30, Vector2.RIGHT)
	check(game._make_snapshot().boss_bar.hp == molgrax.max_hp - 30, "the boss bar drains with damage")
	var seen := {}
	for step in range(1200):
		for id in game.players:
			game.players[id].invulnerable = 99.0
			game.players[id].hp = game.players[id].max_hp
		game._simulate_enemies(0.05)
		game.abilities.update(0.05)
		game._simulate_bullets(0.05)
		if molgrax.attack != "": seen[molgrax.move] = true
	for move in ["swipe", "fireball", "slam", "eruption", "void"]:
		check(seen.has(move), "Molgrax uses his %s" % move)
	game.enemies.clear()
	check(game._make_snapshot().boss_bar.is_empty(), "no boss, no boss bar")
	for id in game.players:
		game.players[id].invulnerable = 0.0
		game.players[id].hp = game.players[id].max_hp
	game.bullets.clear()
	game.abilities.clear()
	game.endless = false
	game.current_layout = saved_layout
	game.phase = "explore"

## The golem of floor 2 and the mobs of the deeper floors: every move runs its
## phases, hazards warn before they hurt, and the new mobs use their abilities.
func _test_golem_and_mobs(game: Node) -> void:
	var saved_layout := _open_room(game)
	var moves: Dictionary = game.balance.golem_moves
	game.phase = "combat"
	game.endless = true
	game.floor_number = 2
	check(game._floor_roster().boss == "ogre_warchief" and game._floor_roster().melee.has("o_brute"), "floor 2 is the orc camp with Brugg")
	var golem: Dictionary = game._spawn_enemy("golem", Vector2(600, 248), 0)
	check(golem.boss and golem.radius == float(game.balance.golem.radius), "the golem spawns as a boss with its own stats")
	for id in game.players:
		game.players[id].pos = Vector2(400, 248)
		game.players[id].hp = game.players[id].max_hp
		game.players[id].invulnerable = 99.0
	var seen := {}
	for step in range(900):
		for id in game.players:
			game.players[id].invulnerable = 99.0
			game.players[id].hp = game.players[id].max_hp
		game._simulate_enemies(0.05)
		game.abilities.update(0.05)
		game._simulate_bullets(0.05)
		if golem.attack != "": seen[golem.move] = true
	for move in ["cleave", "barrage", "quake", "axe", "boulder", "channel"]:
		check(seen.has(move), "the golem uses its %s" % move)
	check(not seen.has("thorns"), "the thorn ultimate waits until the golem is hurt")

	# Cleave: hits in front, not behind.
	game.bullets.clear()
	golem.pos = Vector2(500, 248)
	golem.face = -1.0
	golem.aim_dir = Vector2.LEFT
	game.players[1].pos = Vector2(430, 248)
	game.players[200].pos = Vector2(570, 248)
	for id in game.players:
		game.players[id].hp = game.players[id].max_hp
		game.players[id].invulnerable = 0.0
	game.abilities.fire(golem, moves.cleave, 1)
	check(game.players[1].hp == game.players[1].max_hp - int(moves.cleave.damage) and game.players[200].hp == game.players[200].max_hp, "the axe cleave hits in front and spares the player behind")
	check(game.bullets.size() == int(moves.cleave.count) and game.bullets[0].kind == "slash", "the cleave sends slash waves")

	# Quake: eruptions warn first, then hurt whoever still stands there.
	game.abilities.clear()
	for id in game.players:
		game.players[id].hp = game.players[id].max_hp
		game.players[id].invulnerable = 0.0
	game.players[1].pos = Vector2(442, 248)
	game.players[200].pos = Vector2(650, 100)
	golem.aim_dir = Vector2.LEFT
	game.abilities.fire(golem, moves.quake, 1)
	check(game.abilities.hazards.size() >= int(moves.quake.steps) and game.abilities.hazards[0].state == "warn", "the quake marks its eruptions before they burst")
	game.abilities.update(0.1)
	check(game.players[1].hp == game.players[1].max_hp, "nothing hurts during the warning")
	for step in range(20): game.abilities.update(0.05)
	check(game.players[1].hp == game.players[1].max_hp - int(moves.quake.damage), "an eruption hurts the player who stayed on it")
	check(game.players[200].hp == game.players[200].max_hp, "players away from the cracks are safe")

	# Boomerang axe: flies out and comes back to the golem.
	game.abilities.clear()
	game.players[1].invulnerable = 99.0
	golem.aim_point = Vector2(200, 248)
	game.abilities.fire(golem, moves.axe, 1)
	check(golem.axe_out and game.abilities.hazards[0].kind == "axe", "the axe is thrown")
	var far := 0.0
	for step in range(40):
		game.abilities.update(0.05)
		if not game.abilities.hazards.is_empty(): far = maxf(far, golem.pos.distance_to(game.abilities.hazards[0].pos))
	check(far > 200.0 and game.abilities.hazards.is_empty() and not golem.axe_out, "the axe flies out, returns and is caught")

	# Boulder: lands on the marked spot, explodes and throws shards.
	game.bullets.clear()
	game.abilities.fire(golem, moves.boulder, 1)
	var rock: Dictionary = game.abilities.hazards[0]
	check(rock.state == "fly" and rock.has("goal"), "the boulder flies toward a marked landing spot")
	for step in range(25): game.abilities.update(0.05)
	check(game.bullets.size() == int(moves.boulder.count), "the landing boulder bursts into toxic shards")

	# Thorns ultimate once the golem is hurt.
	game.abilities.clear()
	golem.attack = ""
	golem.shot_timer = 0.0
	golem.axe_out = false
	golem.hp = int(golem.max_hp * 0.5)
	game._simulate_enemies(0.016)
	check(golem.move == "thorns" and golem.attack == "windup", "a hurt golem calls the thorn ultimate")
	while golem.attack == "windup": game._simulate_enemies(0.05)
	for step in range(3): game._simulate_enemies(0.05)
	var under_player := false
	for hazard in game.abilities.hazards:
		if hazard.kind == "thorns" and hazard.pos.distance_to(game.players[1].pos) < 1.0: under_player = true
	check(under_player and float(moves.thorns.warn) * float(game.balance.player.speed) > float(moves.thorns.radius) + 24.0, "thorns rise under the player with time to step away")

	# Facing: the golem turns with weight, not on every pixel.
	golem.attack = ""
	golem.shot_timer = 99.0
	golem.face = 1.0
	golem.turn_cooldown = 0.0
	game._turn_toward(golem, golem.pos + Vector2(-10, 0), 0.016)
	check(golem.face == 1.0, "a boss ignores a target barely on the other side")
	game._turn_toward(golem, golem.pos + Vector2(-100, 0), 0.016)
	game._turn_toward(golem, golem.pos + Vector2(100, 0), 0.016)
	check(golem.face == -1.0, "a boss cannot flip back and forth at once")

	# Mobs: imp dash, skeleton fan, necromancer summons.
	game.enemies.clear()
	game.bullets.clear()
	game.abilities.clear()
	for id in game.players:
		game.players[id].pos = Vector2(300, 248)
		game.players[id].invulnerable = 99.0
	var imp: Dictionary = game._spawn_enemy("imp", Vector2(460, 248), 0)
	imp.shot_timer = 0.0
	game._simulate_enemies(0.016)
	check(imp.attack == "windup", "an imp in range crouches before its dash")
	var start: Vector2 = imp.pos
	while imp.attack == "windup": game._simulate_enemies(0.02)
	for step in range(15): game._simulate_enemies(0.02)
	check(start.x - imp.pos.x > 100.0, "the imp dashes at the player")
	game.enemies.clear()
	var skeleton: Dictionary = game._spawn_enemy("skelet", Vector2(500, 248), 0)
	skeleton.shot_timer = 0.0
	for step in range(40): game._simulate_enemies(0.02)
	check(game.bullets.size() == int(game.balance.attacks.skelet.count) and game.bullets[0].kind == "bone", "a skeleton throws a fan of three bones")
	game.enemies.clear()
	var necro: Dictionary = game._spawn_enemy("necromancer", Vector2(560, 248), 0)
	necro.shot_timer = 0.0
	necro.aggro = true
	for step in range(80): game._simulate_enemies(0.02)
	var zombies := 0
	for other in game.enemies:
		if other.kind == "tiny_zombie" and other.get("summoner", -1) == necro.id: zombies += 1
	check(zombies == int(game.balance.attacks.necromancer.count), "a necromancer raises zombies")
	for step in range(600): game._simulate_enemies(0.02)
	zombies = 0
	for other in game.enemies:
		if other.kind == "tiny_zombie": zombies += 1
	check(zombies <= int(game.balance.attacks.necromancer.max_summons), "a necromancer never keeps more than its limit of zombies")
	check(game._make_snapshot().has("hazards"), "the snapshot carries hazards for the animations")
	for id in game.players:
		game.players[id].invulnerable = 0.0
		game.players[id].hp = game.players[id].max_hp
	game.enemies.clear()
	game.bullets.clear()
	game.abilities.clear()
	game.endless = false
	game.floor_number = 1
	game.current_layout = saved_layout
	game.phase = "explore"

## Endless mode: beating the boss leads to a new, harder floor with the same
## heroes; a story run still ends in victory.
func _test_endless(game: Node) -> void:
	var saved_layouts: Array[Dictionary] = game.floor_layouts.duplicate()
	var saved_states: Dictionary = game.room_states.duplicate(true)
	var saved_layout: Dictionary = game.current_layout
	var saved_seed: int = game.run_seed
	game.endless = true
	game.floor_number = 1
	game.rooms_cleared_before = 0
	var boss_index := _first_index(game, "boss")
	game._enter_room(boss_index, "north")
	var floor_one_boss_hp: int = game.enemies[0].max_hp
	var hero: Dictionary = game.players[1]
	hero.level = 4
	hero.damage = 5.0
	hero.hp = 3
	game.enemies.clear()
	game._check_room_end()
	check(game.phase == "reward" and game.reward_kind == "boss", "the endless boss also grants a perk choice first")
	var cleared_first: int = game._rooms_cleared()
	for id in game.players:
		game.players[id].picked = true
		game.players[id].ready = true
	game._advance_if_ready()
	check(game.phase == "explore" and game.floor_number == 2 and game.current_layout.kind == "start", "after the boss the party starts a new floor instead of winning")
	check(game.run_seed != saved_seed and game.room_states.size() == game.floor_layouts.size() and game._rooms_cleared() == 1, "the new floor is freshly generated")
	check(hero.level == 4 and is_equal_approx(hero.damage, 5.0) and hero.hp == 3 + int(game.balance.endless.heal_per_floor), "heroes keep level and stats and heal a little")
	check(game._make_snapshot().floor == 2 and game._make_snapshot().endless and game._make_snapshot().rooms_total == cleared_first + 1, "the snapshot carries the floor and all rooms cleared so far")
	game._enter_room(_first_index(game, "boss"), "north")
	var chief: Dictionary = game.balance.bosses.ogre_warchief
	var chief_base: int = int(chief.hp) + int(chief.hp_per_extra_player) * (game.players.size() - 1)
	check(floor_one_boss_hp > 0 and game.enemies[0].kind == "ogre_warchief" and game.enemies[0].max_hp > chief_base and game.enemies[0].speed > float(chief.speed), "floor 2 brings Brugg, tougher and faster than his base values")
	check(game._floor_scaling().pause < 1.0, "the boss pauses less between moves on deeper floors")
	game.floor_number = 50
	check(game._floor_scaling().speed <= float(game.balance.endless.speed_max) and game._floor_scaling().pause >= float(game.balance.endless.pause_min), "endless scaling is capped so it stays playable")
	game.endless = false
	game.floor_number = 1
	check(game._floor_scaling().hp == 1.0, "story runs use the base difficulty")
	game.enemies.clear()
	game.floor_layouts = saved_layouts
	game.room_states = saved_states
	game.current_layout = saved_layout
	game.run_seed = saved_seed
	game.rooms_cleared_before = 0
	game.phase = "explore"

## A player who steps off the warning line during the lock and keeps running
## sideways is never caught, close to the boss or across the room.
func _test_beam_dodge(game: Node) -> void:
	var saved_layout := _open_room(game)
	var moves: Dictionary = game.balance.boss_moves
	var speed := float(game.balance.player.speed)
	game.phase = "combat"
	for distance in [130.0, 300.0, 560.0]:
		var boss := _enemy("boss", Vector2(720, 248), 50, 88)
		boss.max_hp = 200
		boss.ultimate_used = false
		game.enemies = [boss]
		game.bullets.clear()
		var runner: Dictionary = game.players[1]
		game.players[200].hp = 0
		runner.hp = runner.max_hp
		runner.invulnerable = 0.0
		runner.pos = Vector2(720.0 - distance, 248)
		game._simulate_enemies(0.016)
		while boss.attack == "windup":
			if boss.attack_time > float(moves.beam.lock): runner.pos = Vector2(720.0 - distance, 248)
			else: runner.pos += Vector2(0, -speed * 0.02)
			game._simulate_enemies(0.02)
		var hit := false
		while boss.attack == "active":
			runner.pos = game.Dungeon.move_actor(runner.pos, Vector2(0, -speed * 0.02), 12.0, game.current_layout)
			game._simulate_enemies(0.02)
			if runner.hp < runner.max_hp and not hit:
				hit = true
		check(boss.move == "beam" and not hit, "running sideways dodges the beam at %d px" % int(distance))
	game.players[200].hp = game.players[200].max_hp
	game.enemies.clear()
	game.current_layout = saved_layout
	game.phase = "explore"

## Mini-bosses: one room per floor holds a named demon with its own moves and
## ultimate, weaker than the floor boss, and leaves a chest. Rooms get props
## and lava pools from the floor's theme; after an endless boss a portal leads
## down.
func _test_minibosses_and_decor(game: Node) -> void:
	var saved_layouts: Array[Dictionary] = game.floor_layouts.duplicate()
	var saved_states: Dictionary = game.room_states.duplicate(true)
	var saved_layout: Dictionary = game.current_layout
	var saved_seed: int = game.run_seed
	var minis := 0
	var normals := 0
	for layout in game.floor_layouts:
		if layout.kind == "miniboss": minis += 1
		if layout.kind == "normal": normals += 1
	check(minis == 1 and normals >= 1, "a floor has one mini-boss room and keeps ordinary rooms")
	var mini_index := _first_index(game, "miniboss")
	check(str(game.floor_layouts[mini_index].miniboss) == str(game.balance.story_floor.miniboss), "the story floor's mini-boss is the one from its roster")
	game._enter_room(mini_index, "north")
	var demon: Dictionary = game.enemies[0] if not game.enemies.is_empty() else {}
	check(game.phase == "combat" and game.enemies.size() == 1 and demon.get("boss", false), "the mini-boss room locks with the mini-boss alone")
	var bar: Dictionary = game._make_snapshot().boss_bar
	check(bar.get("mini", false) and bar.name == game.balance.minibosses[demon.kind].name, "the mini-boss shows its name on a mini-boss bar")
	check(int(game.balance.minibosses[demon.kind].hp) < int(game.balance.boss.hp) * 0.8, "a mini-boss is clearly weaker than the floor boss")
	# With the ordinary chest chance at zero the mini-boss still leaves one.
	var chance: float = game.balance.chest.room_chance
	game.balance.chest.room_chance = 0.0
	game.enemies.clear()
	game._check_room_end()
	game.balance.chest.room_chance = chance
	check(game.phase == "explore" and game.loot.size() == 1, "a beaten mini-boss always leaves a chest")

	# Each demon uses every move, and its ultimate once below half health.
	var saved_open := _open_room(game)
	for kind in game.balance.minibosses:
		game.enemies.clear()
		game.bullets.clear()
		game.abilities.clear()
		var boss: Dictionary = game._spawn_enemy(kind, Vector2(600, 248), 0)
		var seen := {}
		for step in range(1600):
			for id in game.players:
				game.players[id].invulnerable = 99.0
				game.players[id].hp = game.players[id].max_hp
				game.players[id].pos = Vector2(300, 248)
			if step == 800: boss.hp = int(boss.max_hp * 0.4)
			game._simulate_enemies(0.05)
			game.abilities.update(0.05)
			game._simulate_bullets(0.05)
			if boss.attack != "": seen[boss.move] = true
			if game.enemies.size() > 4: game.enemies = [boss]
			boss.hp = maxi(boss.hp, 1)
		var moves: Array = game.balance.minibosses[kind].sequence.duplicate()
		moves.append(game.balance.minibosses[kind].ultimate.move)
		var missing: Array = []
		for move in moves:
			if not seen.has(move): missing.append(move)
		check(missing.is_empty(), "%s uses all its moves and its ultimate (missing %s)" % [kind, missing])
	game.enemies.clear()
	game.bullets.clear()
	game.abilities.clear()
	for id in game.players:
		game.players[id].invulnerable = 0.0
		game.players[id].hp = game.players[id].max_hp
	game.current_layout = saved_open

	# Props: seeded, off the cover and away from the doorways.
	var props_ok := true
	var any_props := false
	for layout in game.floor_layouts:
		for prop in layout.get("props", []):
			any_props = true
			if prop.get("wall", false): continue
			var point := Vector2(prop.x, prop.y)
			for side in layout.get("doors", {}):
				if point.distance_to(Dungeon.door_center(side, layout)) < 100.0: props_ok = false
			for value in layout.obstacles:
				if Rect2(value[0], value[1], value[2], value[3]).has_point(point): props_ok = false
	check(any_props and props_ok, "rooms get props that keep clear of cover and doorways")
	var first_props: Array = game.floor_layouts[1].props.duplicate(true)
	game._generate_floor(game.run_seed)
	check(game.floor_layouts[1].props == first_props, "the same seed furnishes the same rooms")

	# Lava on the infernal endless floor (hell, floor 3): only in combat rooms, and it burns.
	game.endless = true
	game.floor_number = 3
	game._generate_floor(13579)
	var pools := 0
	var pools_ok := true
	for layout in game.floor_layouts:
		pools += layout.lava.size()
		if not layout.lava.is_empty() and not layout.kind in ["normal", "miniboss"]: pools_ok = false
	check(pools > 0 and pools_ok, "infernal floors have lava pools, only in combat rooms")
	var hot: Dictionary = {}
	for layout in game.floor_layouts:
		if not layout.lava.is_empty(): hot = layout
	game.current_layout = hot
	var hero: Dictionary = game.players[1]
	var helper: Dictionary = game.players[200]
	helper.pos = Vector2(-500, -500)
	hero.invulnerable = 0.0
	hero.hp = hero.max_hp
	hero.pos = Vector2(hot.lava[0].x, hot.lava[0].y)
	game._burn_in_lava()
	check(hero.hp == hero.max_hp - int(game.balance.decor.lava_damage), "standing in lava burns")
	hero.invulnerable = 0.0
	hero.hp = hero.max_hp
	hero.pos = Vector2(hot.lava[0].x + hot.lava[0].r + 20.0, hot.lava[0].y)
	game._burn_in_lava()
	check(hero.hp == hero.max_hp, "next to the lava it is safe")

	# The portal after an endless boss.
	game.room_states.clear()
	for layout in game.floor_layouts: game.room_states[layout.id] = {"visited": false, "cleared": false}
	game._enter_room(_first_index(game, "boss"), "north")
	game.enemies.clear()
	game._check_room_end()
	var gate: Dictionary = game._make_snapshot().portal
	check(game.phase == "reward" and not gate.is_empty(), "an endless boss opens a portal")
	for id in game.players: game.players[id].picked = true
	hero.pos = Vector2(gate.x, gate.y)
	helper.pos = Vector2(gate.x + 200.0, gate.y)
	game._check_portal()
	check(hero.ready and not helper.ready and game.floor_number == 3, "a hero in the portal waits for the others")
	helper.pos = Vector2(gate.x, gate.y)
	game._check_portal()
	check(game.floor_number == 4 and game.portal == Vector2.INF, "when everyone is in the portal the party goes down")
	var labels: Array = []
	for entry in game._debug_entries():
		if entry.room == "miniboss": labels.append(entry.label)
	check(labels.size() == game.balance.floors.size() + 1, "the debug level list has every mini-boss")

	game.endless = false
	game.floor_number = 1
	game.enemies.clear()
	game.loot.clear()
	game.floor_layouts = saved_layouts
	game.room_states = saved_states
	game.current_layout = saved_layout
	game.run_seed = saved_seed
	game.rooms_cleared_before = 0
	for id in game.players:
		game.players[id].ready = false
		game.players[id].picked = false
		game.players[id].hp = game.players[id].max_hp
	game.phase = "explore"

func _first_index(game: Node, kind: String) -> int:
	for i in range(game.floor_layouts.size()):
		if game.floor_layouts[i].kind == kind: return i
	return -1
