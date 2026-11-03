extends SceneTree
## Two real ENet processes with ordinary validated R input and live host ticks.
## Synthetic builds/enemies only; no campaign, LAN or performance claim.
const Game = preload("res://src/game.gd")
var failures: Array[String] = []
var observed: Dictionary = {}
var motions: Dictionary = {}
var max_guardians := 0
var damaged := false
var wave := false
var expired := false
var input_sent := false
var retained := false
var souls := false

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("GUARDIAN_NET_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var host := "--guardian-host" in args
	var port := args.find("--guardian-port")
	var result := args.find("--guardian-result")
	if port < 0 or result < 0:
		quit(2)
		return
	var game := Game.new()
	game.name = "Main"
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://soul_guardian_network_profile.json"
	game.session_bind_ip = "127.0.0.1"
	game.address_input.text = "127.0.0.1"
	game.port_input.text = args[port + 1]
	game.requested_seed = 4242
	if host: game._host_session()
	else: game._join_session()
	print("GUARDIAN_NET_START role=%s port=%s active=%s phase=%s message=%s" % ["host" if host else "client", args[port + 1], game.active, game.phase, game.status_message])
	var ready_at := -1
	var started_at := -1
	var cast_at := -1
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and failures.is_empty():
		await process_frame
		if host and started_at < 0 and game.phase == "lobby" and game.players.size() == 2:
			if ready_at < 0: ready_at = Time.get_ticks_msec()
			if Time.get_ticks_msec() - ready_at < 400: continue
			game._begin_run()
			game.hordes.enabled = false
			game.current_layout = {"id": "soul-guardian-network-fixture", "template_id": "soul-guardian-network-fixture", "generator_version": 4,
				"world_size": [896, 480], "tile_size": 32, "play_bounds": [32, 32, 832, 416], "obstacles": [], "exits": [],
				"boss": false, "title": "Controlled soul guardian fixture", "grid_x": 0, "grid_y": 0,
				"render_style": "classic_quiet", "decoration_enabled": false}
			game._room_layout_revision += 1
			game.enemies.clear()
			game.bullets.clear()
			game.talent_combat.reset(17)
			var ranks := {}
			var points := 0
			for id: String in game.talent_combat.data.talents:
				var info: Dictionary = game.talent_combat.data.talents[id]
				if str(info.spec) != "soul" or int(info.tier) >= 6 or points >= 20: continue
				var take := mini(3, 20 - points)
				ranks[id] = take
				points += take
			ranks.soul_14 = 1
			var row := 0
			for id: int in game.players:
				game.players[id].class_id = "necromancer"
				game.players[id].pos = Vector2(300, 220 + row * 100)
				game.players[id].invulnerable = 99.0
				game.talent_combat.set_build(id, {"class": "necromancer", "level": 30, "ranks": ranks, "bar": ["soul_1"]})
				var dummy := game._create_enemy("skelet", Vector2(370, 220 + row * 100))
				dummy.hp = 5000.0
				dummy.max_hp = 5000.0
				dummy.speed = 0.0
				game.enemies.append(dummy)
				row += 1
			game._broadcast_state(true)
			started_at = Time.get_ticks_msec()
		var state: Dictionary = game.state
		if str(state.get("room_layout", {}).get("id", "")) != "soul-guardian-network-fixture": continue
		if not input_sent:
			# Uses the same local command builder, admission and sender-owned
			# RPC path as a held R key; no client spawn/damage call is available.
			game.scripted_target = Vector2(370, 270)
			game.scripted_skills = 1 << game.talent_combat.ULT_BIT
			input_sent = true
			cast_at = Time.get_ticks_msec()
		if Time.get_ticks_msec() - cast_at > 2500: game.scripted_skills = 0
		if host and Time.get_ticks_msec() - cast_at > 3000:
			for id: int in game.players: game.players[id].pos.x = 820.0
		var guardians: Array = state.get("talents", {}).get("guardians", [])
		max_guardians = maxi(max_guardians, guardians.size())
		for guardian: Dictionary in guardians:
			observed[str(guardian.owner)] = true
			motions[str(guardian.motion)] = true
			check(is_finite(float(guardian.x)) and is_finite(float(guardian.age)), "finite replicated motion")
			var hero: Dictionary = state.get("players", {}).get(int(guardian.owner), {})
			if float(hero.get("x", 0.0)) > 700.0 and float(guardian.x) < 600.0: retained = true
			if str(hero.get("talents", {}).get("res_kind", "")) == "souls": souls = true
		for enemy: Dictionary in state.get("enemies", []):
			if float(enemy.hp) < 5000.0: damaged = true
		for event: Dictionary in state.get("talents", {}).get("events", []):
			if str(event.get("kind", "")) == "guardian_wave": wave = true
		if max_guardians > 0 and guardians.is_empty() and Time.get_ticks_msec() - cast_at > 11500: expired = true
		if expired and Time.get_ticks_msec() - cast_at > (14000 if host else 13300): break
	check(input_sent and observed.size() == 2, "both admitted owners' guardians reach this process (final phase=%s status=%s)" % [game.phase, game.status_message])
	check(max_guardians == 2, "holding R never creates duplicate summons")
	for motion: String in ["spawn", "hover", "grasp", "dissolve"]: check(motions.has(motion), "replicated phase " + motion)
	check(damaged and wave, "real host damage and directional wave observed")
	check(expired, "host-owned lifetime removal reaches client")
	check(retained, "guardian remains fighting after owner runs beyond former leash")
	check(souls, "authoritative souls resource reaches admitted client")
	var summary := {"passed": failures.is_empty(), "role": "host" if host else "client", "scope": "two real local ENet processes, synthetic encounter, validated R input",
		"owners": observed.keys(), "motions": motions.keys(), "max_guardians": max_guardians, "damage": damaged, "wave": wave, "expired": expired, "retained": retained, "souls": souls, "failures": failures}
	var file := FileAccess.open(args[result + 1], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()
	else: check(false, "writable result file")
	print("GUARDIAN_NETWORK_PEER role=%s passed=%s" % [summary.role, failures.is_empty()])
	game._leave_session()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
