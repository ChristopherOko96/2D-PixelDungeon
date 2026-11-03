extends SceneTree
## Two real admitted peers cast normal input. Host alone owns delayed annuli.
const Game = preload("res://src/game.gd")
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("RING_NET_FAIL: ", label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var host := "--ring-host" in args
	var port := args.find("--ring-port")
	var result := args.find("--ring-result")
	if port < 0 or result < 0:
		quit(2)
		return
	var game := Game.new()
	game.name = "Main"
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://soul_ring_network_profile.json"
	game.session_bind_ip = "127.0.0.1"
	game.address_input.text = "127.0.0.1"
	game.port_input.text = args[port + 1]
	game.requested_seed = 4242
	if host: game._host_session()
	else: game._join_session()
	var started := false
	var ready_at := -1
	var cast_at := -1
	var owners := {}
	var max_rings := 0
	var damage := false
	var expired := false
	var charge_seen := false
	var flight_seen := false
	var impact_seen := false
	var leap_seen := false
	var trail_seen := false
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and failures.is_empty():
		await process_frame
		if host and not started and game.phase == "lobby" and game.players.size() == 2:
			if ready_at < 0: ready_at = Time.get_ticks_msec()
			if Time.get_ticks_msec() - ready_at < 400: continue
			game._begin_run()
			game.hordes.enabled = false
			game.current_layout = {"id": "soul-ring-network-fixture", "template_id": "soul-ring-network-fixture", "generator_version": 4,
				"world_size": [896, 480], "tile_size": 32, "play_bounds": [32, 32, 832, 416], "obstacles": [], "exits": [],
				"boss": false, "title": "Controlled soul ring fixture", "grid_x": 0, "grid_y": 0, "render_style": "classic_quiet", "decoration_enabled": false}
			game._room_layout_revision += 1
			game.enemies.clear()
			game.bullets.clear()
			game.talent_combat.reset(17)
			var row := 0
			for id: int in game.players:
				game.players[id].class_id = "necromancer"
				game.players[id].pos = Vector2(300 + row * 240, 240)
				game.players[id].invulnerable = 99.0
				var ranks := {}
				for talent: String in game.talent_combat.data.classes.necromancer.specs[2].talents: ranks[talent] = 1
				var remaining: int = game.talent_combat.Rules.points_total(game.talent_combat.data, 30) - ranks.size()
				for talent: String in game.talent_combat.data.classes.necromancer.specs[2].talents:
					var extra := mini(remaining, int(game.talent_combat.data.talents[talent].ranks) - 1)
					ranks[talent] = int(ranks[talent]) + extra
					remaining -= extra
				game.talent_combat.set_build(id, {"class": "necromancer", "level": 30, "ranks": ranks, "bar": ["soul_3", "soul_9", "soul_7"]})
				game.talent_combat.runtime(id).res = float(game.talent_combat.runtime(id).res_max)
				var dummy := game._create_enemy("skelet", Vector2(game.players[id].pos) + Vector2(100, 0))
				dummy.hp = 5000.0
				dummy.max_hp = 5000.0
				dummy.speed = 0.0
				game.enemies.append(dummy)
				row += 1
			game._broadcast_state(true)
			started = true
		var state: Dictionary = game.state
		if str(state.get("room_layout", {}).get("id", "")) != "soul-ring-network-fixture": continue
		if cast_at < 0:
			game.scripted_skills = 1 << game.talent_combat.BAR_BIT
			cast_at = Time.get_ticks_msec()
		var elapsed := Time.get_ticks_msec() - cast_at
		var own: Dictionary = state.get("players", {}).get(game.multiplayer.get_unique_id(), {})
		game.scripted_target = Vector2(850, float(own.get("y", 240.0)))
		if elapsed > 500: game.scripted_skills = 0
		if elapsed >= 1500 and elapsed < 2600: game.scripted_skills = 1 << (game.talent_combat.BAR_BIT + 1)
		if elapsed >= 4500 and elapsed < 4800: game.scripted_skills = 1 << (game.talent_combat.BAR_BIT + 2)
		for hero: Dictionary in state.get("players", {}).values():
			if not hero.get("talents", {}).get("leap", {}).is_empty(): leap_seen = true
		for zone: Dictionary in state.get("talents", {}).get("zones", []):
			if str(zone.get("look", "")) == "souls_trail":
				trail_seen = true
				check(zone.path.size() == 2 and float(zone.w) > 0 and float(zone.total) == 5.0, "host trail footprint and five-second lifetime")
		for charge: Dictionary in state.get("talents", {}).get("charges", []):
			if float(charge.power) > 0.1: charge_seen = true
			check(float(charge.power) <= 1 and float(charge.power) >= 0, "host-bounded charge reaches client")
		for shot: Dictionary in state.get("bullets", []):
			if str(shot.get("talent", "")) == "soul_9" and float(shot.get("charge", 0.0)) > 0: flight_seen = true
		for event: Dictionary in state.get("talents", {}).get("events", []):
			if str(event.get("kind", "")) == "soul_impact": impact_seen = true
		var rings: Array = state.get("talents", {}).get("zones", []).filter(func(z: Dictionary) -> bool: return str(z.get("look", "")) == "souls_ring")
		max_rings = maxi(max_rings, rings.size())
		for ring: Dictionary in rings:
			owners[str(ring.owner)] = true
			check(is_equal_approx(float(ring.r), 160.0) and is_equal_approx(float(ring.inner_r), 96.0), "host annulus boundaries arrive intact")
			check(float(ring.time) <= 5.0 and float(ring.time) > 0.0, "client sees only active delayed field")
		for enemy: Dictionary in state.get("enemies", []):
			if float(enemy.hp) < 5000: damage = true
		if max_rings > 0 and rings.is_empty() and Time.get_ticks_msec() - cast_at > 5700: expired = true
		if expired and Time.get_ticks_msec() - cast_at > (12000 if host else 11500): break
	check(cast_at >= 0 and owners.size() == 2 and max_rings == 2, "both admitted owners cast exactly one ring via normal held input")
	check(leap_seen and trail_seen, "hero leap progress and soul trail reach both admitted peers")
	check(charge_seen and flight_seen and impact_seen, "charge, charged flight and authoritative contact reach both admitted peers")
	check(damage and expired, "normal nova damage and authoritative field expiry observed")
	var summary := {"passed": failures.is_empty(), "role": "host" if host else "client", "owners": owners.keys(), "max_rings": max_rings, "damage": damage, "expired": expired, "charge": charge_seen, "flight": flight_seen, "impact": impact_seen, "leap": leap_seen, "trail": trail_seen,
		"scope": "two real local ENet processes, validated skill input, synthetic encounter", "failures": failures}
	var file := FileAccess.open(args[result + 1], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()
	else: check(false, "writable result")
	print("RING_NETWORK_PEER role=%s passed=%s" % [summary.role, failures.is_empty()])
	game._leave_session()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
