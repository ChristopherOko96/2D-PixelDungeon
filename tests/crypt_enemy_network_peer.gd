extends SceneTree
## Controlled two-process enemy replication fixture; not campaign/LAN/performance.

var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		printerr("CRYPT_NET_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _actor(id: int, kind: String, point: Vector2) -> Dictionary:
	return {"id":id,"kind":kind,"pos":point,"hp":100.0,"max_hp":100.0,"boss":false,"radius":13.0,"speed":0.0,"damage":1,"shot_timer":1.0,"nav_timer":10.0,"nav_path":PackedVector2Array(),"hitstun":0.0,"hit_flash":0.0,"knockback":Vector2.ZERO,"stun_cooldown":0.0,"hits":0,"attacks":0,"moving":false,"face":-1.0,"direction":Vector2.ZERO,"facing_dir":Vector2.RIGHT,"attack":"windup","attack_time":0.4,"attack_length":0.6,"attack_kind":"arrow" if kind == "skeleton_archer" else "summon" if kind == "necromancer" else "slash","attack_aim":Vector2.LEFT,"attack_target":1,"summon_point":Vector2(448,384),"summons_cast":0,"dying":0.0,"blocks":0}

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var host: bool = "--crypt-host" in args
	var port_index: int = args.find("--crypt-port")
	var result_index: int = args.find("--crypt-result")
	if port_index < 0 or port_index+1 >= args.size() or result_index < 0 or result_index+1 >= args.size():
		printerr("CRYPT_NET_FAIL: port and result path required")
		quit(2)
		return
	var game: Node = load("res://src/game.gd").new()
	game.name = "Main"
	root.add_child(game)
	await process_frame
	game.session_bind_ip = "127.0.0.1"
	game.port_input.text = args[port_index+1]
	game.requested_seed = 42026
	if host: game._host_session()
	else: game._join_session()
	var deadline: int = Time.get_ticks_msec()+15000
	var fixture_started: bool = false
	var observed: bool = false
	var observed_at: int = -1
	var last_broadcast: int = 0
	var seen_kinds: Array[String] = []
	var observed_run_serial: int = -1
	var observed_player_fields: Dictionary = {}
	while Time.get_ticks_msec() < deadline and failures.is_empty():
		await process_frame
		if host and not fixture_started and game.phase == "lobby" and game.players.size() == 2:
			check(game.has_method("spawn_crypt_minion"),"host has a validated minion spawn boundary")
			if not failures.is_empty(): break
			game._begin_run()
			game.run_serial = 2 # Explicit transport fixture; actual restart is tested separately.
			# Explicit synthetic encounter setup, not a claim of earned campaign progress.
			game.set_physics_process(false)
			game.current_layout = {"id":"crypt-network-fixture","template_id":"crypt-network-fixture","generator_version":4,"tile_size":32,"world_size":[1024,768],"play_bounds":[32,32,960,704],"obstacles":[],"exits":[],"boss":false,"title":"Controlled replication fixture","grid_x":0,"grid_y":0}
			game._room_layout_revision += 1
			var player_index: int = 0
			for player_id: int in game.players:
				var player: Dictionary = game.players[player_id]
				player.pos = Vector2(128,256+player_index*256)
				# Explicit transport fixtures: these values are not gameplay earnings.
				var first: bool = player_id == 1
				player.skin = "player_warden" if first else "player_ranger"
				player.motion = Vector2(48,-24) if first else Vector2(-72,36)
				player.moving = true
				player.hit_direction = Vector2.UP if first else Vector2.RIGHT
				player.last_hit_damage = 2.0 if first else 3.0
				player.blocks = 2 if first else 3
				player.interacts = 4 if first else 5
				player_index += 1
			var guard: Dictionary = _actor(9001,"skeleton_guard",Vector2(704,512))
			guard.enemy_name = str(game.crypt_ai.definition("skeleton_guard").get("display_name","SCHILDSKELETT"))
			guard.attack = ""
			var archer: Dictionary = _actor(9002,"skeleton_archer",Vector2(768,384))
			archer.enemy_name = str(game.crypt_ai.definition("skeleton_archer").get("display_name","SKELETTBOGENSCHÜTZE"))
			var necromancer: Dictionary = _actor(9003,"necromancer",Vector2(704,256))
			necromancer.enemy_name = str(game.crypt_ai.definition("necromancer").get("display_name","NEKROMANT"))
			game.enemies = [guard,archer,necromancer]
			game.bullets.clear()
			game._damage_enemy(guard,1.0,Vector2.LEFT,1)
			guard.facing_dir = Vector2.UP
			guard.motion = Vector2(0,-60)
			archer.facing_dir = Vector2.RIGHT
			archer.motion = Vector2(80,0)
			necromancer.facing_dir = Vector2.DOWN
			necromancer.motion = Vector2(0,36)
			check(game.spawn_crypt_minion(9003,Vector2(448,384)),"host fixture creates one actual wall-safe owned minion")
			game._add_bullet(Vector2(736,384),Vector2.LEFT*180,0,1,{"style":"arrow"})
			game._broadcast_state(true)
			fixture_started = true
			print("CRYPT_NET_FIXTURE controlled_encounter=true")
		if host and fixture_started and Time.get_ticks_msec()-last_broadcast >= 150:
			game._broadcast_state(true)
			last_broadcast = Time.get_ticks_msec()
		var snapshot: Dictionary = game.state
		if not observed and str(snapshot.get("room_layout",{}).get("id","")) == "crypt-network-fixture":
			observed_run_serial = int(snapshot.get("run_serial",-1))
			check(observed_run_serial == 2 and int(snapshot.get("run_seed",0)) == 42026,"the controlled run serial and fixed seed reach both peers")
			check(snapshot.get("players",{}).size() == 2,"both admitted player records reach the controlled fixture")
			for player_id: int in snapshot.get("players",{}):
				var player: Dictionary = snapshot.players[player_id]
				var first: bool = player_id == 1
				var expected_motion: Vector2 = Vector2(48,-24) if first else Vector2(-72,36)
				var expected_hit: Vector2 = Vector2.UP if first else Vector2.RIGHT
				check(str(player.get("skin","")) == ("player_warden" if first else "player_ranger"),"explicit player skin is identical on host and client")
				check(Vector2(float(player.get("mx",0)),float(player.get("my",0))).is_equal_approx(expected_motion),"explicit player motion is identical on host and client")
				check(Vector2(float(player.get("hit_dx",0)),float(player.get("hit_dy",0))).is_equal_approx(expected_hit),"explicit player damage direction reaches both peers")
				check(is_equal_approx(float(player.get("last_hit_damage",0)),2.0 if first else 3.0),"explicit player damage magnitude reaches both peers")
				check(int(player.get("blocks",0)) == (2 if first else 3) and int(player.get("interacts",0)) == (4 if first else 5),"explicit block and interaction counters reach both peers")
				observed_player_fields[str(player_id)] = {"skin":player.get("skin"),"mx":player.get("mx"),"my":player.get("my"),"blocks":player.get("blocks"),"interacts":player.get("interacts"),"hit_dx":player.get("hit_dx"),"hit_dy":player.get("hit_dy"),"last_hit_damage":player.get("last_hit_damage")}
			var by_id: Dictionary = {}
			for enemy: Dictionary in snapshot.get("enemies",[]):
				by_id[int(enemy.get("id",0))] = enemy
				if str(enemy.get("kind","")) not in seen_kinds: seen_kinds.append(str(enemy.get("kind","")))
			check(seen_kinds.has("skeleton_guard") and seen_kinds.has("skeleton_archer") and seen_kinds.has("necromancer"),"all three actual role IDs survive authoritative replication")
			check(by_id.has(9001) and by_id.has(9002) and by_id.has(9003),"stable enemy IDs survive the fixture snapshot")
			if by_id.has(9002):
				var ranged: Dictionary = by_id[9002]
				check(str(ranged.get("attack_kind","")) == "arrow" and str(ranged.get("attack","")) == "windup","client receives the prepared archer attack kind and phase")
				check(float(ranged.get("aim_x",0)) < 0 and ranged.has("tx") and ranged.has("ty"),"client receives locked aim and target coordinates for the telegraph")
				check(not str(ranged.get("enemy_name","")).is_empty(),"client receives the enemy's player-facing name")
			if by_id.has(9001): check(int(by_id[9001].get("blocks",0)) == 1,"actual directional block feedback counter survives replication")
			for enemy_id: int in [9001,9002,9003]:
				if not by_id.has(enemy_id): continue
				var facing: Vector2 = Vector2.UP if enemy_id == 9001 else Vector2.RIGHT if enemy_id == 9002 else Vector2.DOWN
				var motion: Vector2 = Vector2(0,-60) if enemy_id == 9001 else Vector2(80,0) if enemy_id == 9002 else Vector2(0,36)
				var actor: Dictionary = by_id[enemy_id]
				check(Vector2(float(actor.get("facing_x",0)),float(actor.get("facing_y",0))).is_equal_approx(facing),"explicit enemy facing survives on both peers for " + str(enemy_id))
				check(Vector2(float(actor.get("mx",0)),float(actor.get("my",0))).is_equal_approx(motion),"explicit enemy motion survives on both peers for " + str(enemy_id))
			if by_id.has(9003): check(int(by_id[9003].get("cast_count",0)) == 1,"successful summon count survives replication")
			var summoned: bool = false
			for enemy: Dictionary in snapshot.get("enemies",[]):
				if int(enemy.get("caster_id",0)) == 9003: summoned = str(enemy.get("kind","")) == "skeleton_guard" and not bool(enemy.get("boss",false))
			check(summoned,"summoned guard ownership survives the host-to-client snapshot")
			check(snapshot.get("bullets",[]).size() == 1 and str(snapshot.bullets[0].get("style","")) == "arrow","actual projectile style survives replication")
			observed = true
			observed_at = Time.get_ticks_msec()
		if observed and Time.get_ticks_msec()-observed_at >= (1800 if host else 500): break
	check(observed,"the admitted peer observed the controlled enemy fixture before the deadline")
	var result: Dictionary = {"passed":failures.is_empty(),"role":"host" if host else "client","scope":"controlled local two-process actor replication fixture; not played campaign/LAN/performance","observed":observed,"run_serial":observed_run_serial,"player_fields":observed_player_fields,"kinds":seen_kinds,"failures":failures}
	var file: FileAccess = FileAccess.open(args[result_index+1],FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"\t"))
	else: check(false,"result file could not be saved")
	print("CRYPT_PEER role=%s result=%s" % [result.role,"PASS" if failures.is_empty() else "FAIL"])
	game._leave_session()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
