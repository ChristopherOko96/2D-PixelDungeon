extends SceneTree
## Crypt floor plan and the new fights on the host: mini-bosses on floors
## 3/6/9, the Leerenrufer on floor 10, strong groups elsewhere; the
## Leerenbomber's fuse and burst; the Leerenrufer's beam, summons and the body
## parts that gate its moves; rigged enemies carry their parts in snapshots.

const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("CRYPT_BOSSES_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _clear_spot(game, origin: Vector2, distance: float) -> Vector2:
	for offset: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var spot: Vector2 = origin + offset * distance
		if not Dungeon.segment_blocked(origin, spot, 14.0, game.current_layout): return spot
	return origin

func _run() -> void:
	# Arrange: a solo host run on a fixed seed, simulated by hand.
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 4242
	game._begin_run()
	var final_room: int = game.floor_layouts.size()

	# Floor plan: which final room holds what.
	var roles: Array = []
	for floor_index in [1, 2, 3, 6, 9, 10, 13, 20]: roles.append(game.crypt_ai.final_room_role(floor_index))
	check(roles == ["strong_group", "strong_group", "moderkoloss", "frostleiche", "knochenkoloss", "boss", "moderkoloss", "boss"], "mini-bosses on 3/6/9, the boss on 10, repeating every 10 floors (%s)" % str(roles))
	game.room = final_room
	game._spawn_room()
	var kinds: Array = game.enemies.map(func(e: Dictionary) -> String: return str(e.kind))
	check(game.enemies.size() == 6 and kinds.count("void_bomber") == 2 and kinds.has("necromancer") and not game.enemies.any(func(e: Dictionary) -> bool: return bool(e.boss)), "floor 1 ends in a strong group with two bombers and a necromancer")
	game.floor_index = 3
	game._spawn_room()
	var mini: Dictionary = game.enemies[0]
	check(str(mini.kind) == "moderkoloss" and bool(mini.get("miniboss", false)) and str(mini.rig) == "big_zombie" and not bool(mini.boss), "floor 3's final room holds the Moderkoloss")
	var snapshot: Dictionary = game._make_snapshot()
	check(str(snapshot.enemies[0].get("rig", "")) == "big_zombie" and snapshot.enemies[0].get("lost") == [] and bool(snapshot.enemies[0].get("miniboss", false)), "snapshots carry the rig and lost parts")

	# Leerenbomber: fuse near a player, then a void burst that hurts and vanishes.
	game.floor_index = 2
	game.room = 2
	game._spawn_room()
	game.enemies.clear()
	var bomber: Dictionary = game._create_enemy("void_bomber", Vector2.ZERO)
	var player: Dictionary = game.players[1]
	bomber.pos = _clear_spot(game, Vector2(player.pos), 34.0)
	bomber.shot_timer = 0.0
	game.enemies.append(bomber)
	player.invulnerable = 0.0
	player.hp = 8
	game._simulate_enemies(0.01)
	check(str(bomber.attack) == "windup" and str(bomber.attack_kind) == "fuse", "a bomber next to a player lights its fuse")
	game._simulate_enemies(float(game.balance.enemy_roster.attacks.fuse.windup) + 0.01)
	check(int(player.hp) == 8 - int(game.balance.enemy_roster.attacks.fuse.damage), "the burst hurts the player in its radius")
	check(float(bomber.hp) <= 0.0 and bool(bomber.get("exploded", false)), "the bomber is gone after its burst")
	check(game.fx_events.any(func(e: Dictionary) -> bool: return str(e.kind) == "void_burst"), "clients receive one void burst effect")
	var shot: Dictionary = game._create_enemy("void_bomber", _clear_spot(game, Vector2(player.pos), 200.0))
	game.enemies.append(shot)
	game.fx_events.clear()
	game._damage_enemy(shot, 99.0, Vector2.RIGHT, 1)
	check(float(shot.hp) <= 0.0 and not bool(shot.get("exploded", false)) and game.fx_events.is_empty(), "a bomber shot down pops harmlessly")

	# Leerenrufer: telegraphed beam that hurts on contact and opens the eye.
	game.floor_index = 10
	game.room = final_room
	game._spawn_room()
	var boss: Dictionary = {}
	for enemy: Dictionary in game.enemies:
		if bool(enemy.boss): boss = enemy
	check(not boss.is_empty() and str(boss.rig) == "void" and str(boss.enemy_name) == "DER LEERENRUFER", "floor 10 holds Der Leerenrufer")
	game.enemies = [boss]
	player.pos = _clear_spot(game, Vector2(boss.pos), 140.0)
	player.invulnerable = 0.0
	player.hp = 8
	game.void_ai._begin(boss, 1, Vector2(player.pos), "beam")
	check(str(boss.get("exposed_action", "")) == "beam" and boss.has("beam_to"), "the beam's windup opens the eye and shows the beam line")
	game._simulate_enemies(float(game.balance.void_boss.attacks.beam.windup) + 0.01)
	check(str(boss.attack) == "active" and int(player.hp) == 8, "nothing hurts during the warning")
	# Regression: clients draw the beam's strength from attack_p; it must use the
	# Leerenrufer's own phase length, not the old boss table (0.12 s).
	game._simulate_enemies(0.5)
	var shown: Dictionary = game._make_snapshot().enemies[0]
	check(float(shown.attack_p) > 0.2 and float(shown.attack_p) < 0.5, "the snapshot reports the beam's real progress (%.2f)" % float(shown.attack_p))
	for i in range(30): game._simulate_enemies(1.0 / 30.0)
	check(int(player.hp) < 8, "a player in the beam is hurt")
	var beam_end: Vector2 = boss.beam_to
	# The beam runs on until it meets a wall (user request 2026-10-28).
	var beyond: Vector2 = beam_end + (beam_end - Vector2(boss.pos)).normalized() * 12.0
	check(Dungeon.segment_blocked(beam_end, beyond, 2.0, game.current_layout), "the beam ends at a wall")
	for i in range(80): game._simulate_enemies(1.0 / 30.0)
	check(not boss.has("exposed_action") and not boss.has("beam_to"), "after the beam the eye closes again")

	# Summon: skeleton archers and bombers rise next to it.
	player.invulnerable = 99.0
	boss.attack = ""
	game.void_ai._begin(boss, 1, Vector2(player.pos), "summon")
	game._simulate_enemies(float(game.balance.void_boss.attacks.summon.windup) + 0.01)
	var minions: Array = game.enemies.filter(func(e: Dictionary) -> bool: return int(e.get("caster_id", 0)) == int(boss.id))
	var minion_kinds: Array = minions.map(func(e: Dictionary) -> String: return str(e.kind))
	check(minions.size() >= 1 and minion_kinds.all(func(k: String) -> bool: return k in ["skeleton_archer", "void_bomber"]), "the boss summons archers and bombers (%s)" % str(minion_kinds))
	check(minions.all(func(e: Dictionary) -> bool: return bool(e.summoned) and game.body_parts.has_parts(e)), "summons are rigged and marked as summoned")

	# Parts gate the moves.
	game.body_parts.damage(boss, float(boss.parts.claw_r.hp), "claw_r")
	game.body_parts.damage(boss, float(boss.parts.claw_l.hp), "claw_l")
	boss.beam_cooldown = 0.0
	var moves := {}
	for i in range(12):
		boss.attacks = i
		moves[game.void_ai.choose_move(boss)] = true
	check(moves.keys() == ["beam"], "without claws only the beam is left")
	boss.exposed_action = "beam"
	game.body_parts.damage(boss, float(boss.parts.eye.hp), "eye")
	boss.erase("exposed_action")
	check(game.void_ai.choose_move(boss) == "", "without eye and claws the boss has no move until something grows back")
	game.body_parts.step(boss, 9.0)
	check(game.void_ai.choose_move(boss) in ["salve", "summon"], "the claws grow back after 8 s")

	# Precise hits: a shot that passes under the figure misses.
	game.enemies = [boss]
	game.bullets.clear()
	var hp_before: float = float(boss.hp)
	var below: Vector2 = Vector2(boss.pos) + Vector2(-240, game.body_parts.reach(boss) + 20.0)
	game._add_bullet(below, Vector2(900, 0), 1, 3.0, {"hit_ids": [], "primary": true, "life": 0.6})
	for i in range(12): game._simulate_bullets(1.0 / 60.0)
	check(is_equal_approx(float(boss.hp), hp_before), "a shot passing below the figure does not hit")
	print("CRYPT_BOSSES checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)
