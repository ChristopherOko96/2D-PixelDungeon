extends SceneTree
## Host protocol integration: native32 actors, death cues and queued exits.
const Game = preload("res://src/game.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("PRESENTATION_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Game.new()
	check(game.has_method("_step_transition"),"room changes are queued for a black transition")
	if not game.has_method("_step_transition"):
		game.free()
		finish()
		return
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	var probe := PacketPeerUDP.new()
	probe.bind(0,"127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 3
	game._begin_run()
	# Since the fullscreen revision (Story018) the live world fills the 1280x720 design base.
	check(Game.WORLD_SIZE == Game.DESIGN_SIZE and Game.WORLD_ZOOM == Vector2.ONE,"32-pixel world is rendered one-to-one")
	check(game.dungeon_config.tile_size == 32 and game.dungeon_config.generator_version == 4,"game uses native32 authored-room templates")
	game.players[1].invulnerable = 0.0
	game._damage_player(1,1)
	var snapshot: Dictionary = game._make_snapshot()
	check(snapshot.players[1].get("hurts",0) == 1,"authoritative player damage emits one sound/animation counter")
	game.players[1].hitstun = 0.0
	game.commands[1] = {"move":Vector2.RIGHT,"aim":Vector2.RIGHT,"fire":true,"time":Time.get_ticks_msec()/1000.0}
	game._simulate_players(0.05)
	snapshot = game._make_snapshot()
	check(snapshot.players[1].get("shots",0) == 1 and snapshot.players[1].get("moving",false),"movement and shooting cues reach all clients")
	var enemy: Dictionary = game.enemies[0]
	var identity: int = enemy.get("id",-1)
	game._damage_enemy(enemy,999,Vector2.RIGHT)
	snapshot = game._make_snapshot()
	check(identity >= 0 and snapshot.enemies[0].id == identity and snapshot.enemies[0].hits == 1 and snapshot.enemies[0].dying_p == 0.0,"a killing hit retains its stable actor and death cue in snapshots")
	game._damage_enemy(enemy,999)
	check(enemy.hits == 1,"a dead enemy cannot create duplicate hit/death cues")
	game._simulate_enemies(float(game.balance.death.duration)+0.01)
	check(game.enemies.all(func(value: Dictionary): return value.id != identity),"dead actors leave only after the animation interval")
	# The boss lives in the final room of the ten-room crypt (Story015), with two
	# companions (encounter.boss_enemies); isolate the boss to count its burst.
	game.room = game.floor_layouts.size()
	game._spawn_room()
	var boss: Dictionary = {}
	for candidate: Dictionary in game.enemies:
		if bool(candidate.boss): boss = candidate
	check(not boss.is_empty(),"the final room spawns the boss")
	game.enemies = [boss]
	boss.shot_timer = 0.0
	game.bullets.clear()
	game._simulate_enemies(0.01)
	check(boss.attack == "windup" and game.bullets.is_empty(),"boss animation anticipates its radial shot")
	game._simulate_enemies(float(game.balance.attacks.boss.windup)+0.01)
	check(boss.attacks == 1 and game.bullets.size() == int(game.balance.boss.bullet_count),"active attack emits one burst and one feedback counter")
	game._begin_run()
	game.enemies.clear()
	game._check_room_end()
	game.players[1].picked = true
	game.players[1].ready = true
	game._advance_if_ready()
	var door: Dictionary = game.current_layout.exits[0]
	game.players[1].pos = game._exit_center(door)
	game._use_exit(1)
	var token: int = game._make_snapshot().transition.token
	check(game.room == 1 and game.is_transitioning(),"a door request starts fade-out without exposing the target room")
	game._use_exit(1)
	check(game._make_snapshot().transition.token == token,"repeated exit requests cannot queue duplicate transitions")
	game._step_transition(float(game.balance.transition.fade_out)-0.01)
	check(game.room == 1,"old room remains authoritative until blackout")
	game._step_transition(0.02)
	check(game.room == 2 and game.current_layout.id != door.get("from_id","") and game.is_transitioning(),"the target room is spawned under black cover")
	var enemy_position: Vector2 = game.enemies[0].pos
	game._physics_process(0.01)
	check(game.enemies[0].pos == enemy_position,"incoming enemies cannot attack during fade-in")
	game._step_transition(1.0)
	check(not game._make_snapshot().transition.active,"completed transition metadata remains identifiable for late clients")
	# Interior stairs exist only in the final (boss) room.
	game.room = game.floor_layouts.size()
	game._spawn_room()
	game.enemies.clear()
	game.cleared_room_ids.clear()
	for layout: Dictionary in game.floor_layouts: game.cleared_room_ids.append(str(layout.id))
	game.phase = "explore"
	var stairs: Dictionary = {}
	for exit: Dictionary in game.current_layout.exits:
		if exit.kind == "stairs": stairs = exit
	game.players[1].pos = game._exit_center(stairs)
	game._use_exit(1)
	check(game._make_snapshot().transition.kind == "stairs" and game.floor_index == 1,"stairs carry their own descent sound cue and wait for blackout")
	game._step_transition(float(game.balance.transition.fade_out)+0.01)
	check(game.floor_index == 2 and game.room == 1,"the next floor is created under cover")
	game._leave_session()
	check(not game.is_transitioning() and not game.transition_view.is_active(),"disconnect clears blackout and pending target state")
	game.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("SESSION_PRESENTATION checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
