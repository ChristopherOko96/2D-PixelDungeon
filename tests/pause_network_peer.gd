extends SceneTree
## One real peer for pause_network_smoke.ps1; bots use ordinary game inputs.
var failed := false

func fail(message: String) -> void:
	failed = true
	printerr("PAUSE_NET_FAIL: ",message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var host := "--test-host" in args
	var port := args[args.find("--test-port")+1]
	var game = load("res://src/game.gd").new()
	root.add_child(game)
	await process_frame
	game.session_bind_ip = "127.0.0.1"
	game.port_input.text = port
	game.smoke_role = "host" if host else "client"
	game.requested_seed = 24680
	if host: game._host_session()
	else: game._join_session()
	var started := Time.get_ticks_msec()
	var combat_at := -1
	var pause_at := -1
	var completed := false
	var initial_sequence := -1
	var before := ""
	var neutral_remote := false
	while Time.get_ticks_msec()-started < 15000:
		await process_frame
		if host and game.phase == "lobby" and game.players.size() == 2: game._begin_run()
		if combat_at < 0 and game.phase == "combat": combat_at = Time.get_ticks_msec()
		if combat_at < 0: continue
		var elapsed := (Time.get_ticks_msec()-combat_at)/1000.0
		if host and elapsed > 2.15 and elapsed < 2.6:
			for id: Variant in game.commands:
				if int(id) != 1 and game.commands[id].move == Vector2.ZERO and not game.commands[id].fire: neutral_remote = true
		if pause_at < 0 and elapsed >= (0.2 if host else 1.8):
			game.set_pause_open(true)
			pause_at = Time.get_ticks_msec()
			initial_sequence = game.received_sequence
			before = JSON.stringify(game.state.get("enemies",[]))
		if pause_at >= 0 and not completed and Time.get_ticks_msec()-pause_at >= 850:
			if not game.pause_open or game.is_solo_paused() or paused: fail("multiplayer menu froze or closed the shared world")
			if game.received_sequence <= initial_sequence+3: fail("snapshots stopped while menu was open")
			if JSON.stringify(game.state.get("enemies",[])) == before: fail("authoritative enemies did not progress during the menu")
			if host and (game.commands[1].move != Vector2.ZERO or game.commands[1].fire): fail("host menu leaked movement or fire")
			game.set_pause_open(false)
			completed = true
		if completed and elapsed > (5.0 if host else 4.0): break
	if not completed: fail("both participants did not reach the pause scenario before timeout")
	if host and not neutral_remote: fail("host never received the paused client's neutral input")
	print("PAUSE_PEER role=%s completed=%s neutral_remote=%s result=%s" % ["host" if host else "client",completed,neutral_remote,"FAIL" if failed else "PASS"])
	game._leave_session()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
