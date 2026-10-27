extends SceneTree
## Real four-peer rendering sample. Headless peers are workload, never GPU FPS.
const Game = preload("res://src/game.gd")
var game
var role := "client"
var visible_probe := false
var port := 0
var out_path := ""
var expected_players := 4
var full_campaign := false
var bot_navigation_warmup: Dictionary = {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()-1):
		match args[index]:
			"--render-role": role = args[index+1]
			"--render-port": port = int(args[index+1])
			"--render-output": out_path = args[index+1]
	visible_probe = "--render-visible" in args
	full_campaign = "--render-campaign" in args
	_run.call_deferred()

func _run() -> void:
	game = Game.new()
	game.name = "Game"
	root.add_child(game)
	current_scene = game
	game.session_bind_ip = "127.0.0.1"
	game.port_input.text = str(port)
	game.requested_seed = 42026
	game.smoke_role = role
	# Human clients do not run the Smoke bot's local A* planner. Prepare only
	# that private test workload before joining; live state and geometry still
	# come from the host and pass the normal content/admission checks.
	var navigation_started := Time.get_ticks_usec()
	var bot_layouts: Array[Dictionary] = Game.Dungeon.generate(game.requested_seed,game._run_room_count(),game.dungeon_config)
	if bot_layouts.size() != game._run_room_count():
		push_error("Render probe could not prepare bot navigation")
		quit(1)
		return
	var bot_radius: float = float(game.balance.player.radius)
	for layout: Dictionary in bot_layouts:
		Game.Dungeon.prepare_navigation(layout,[bot_radius])
	bot_navigation_warmup = {"purpose":"testbot-only private navigation; no game state changes","seed":game.requested_seed,"rooms":bot_layouts.size(),"radius":bot_radius,"duration_ms":float(Time.get_ticks_usec()-navigation_started)/1000.0}
	print("RENDER_BOT_NAVIGATION_PREPARED ",JSON.stringify(bot_navigation_warmup))
	if role == "host": game._host_session()
	else: game._join_session()
	if visible_probe:
		root.title = "Crypt of the Damned · Koop-Darstellungsmessung"
		game.toggle_fullscreen()
	var started := Time.get_ticks_msec()
	var combat_start := -1
	var sample_start := -1
	var last_tick := 0
	var frames: Array = []
	var sequences: Dictionary = {}
	var visual_ticks: Dictionary = {}
	var steps_between_packets := 0
	var interpolated_frames := 0
	var previous_sequence := -1
	var previous_point := Vector2.INF
	var max_enemies := 0
	var max_bullets := 0
	var room_frames: Dictionary = {}
	var room_enemy_max: Dictionary = {}
	var room_bullet_max: Dictionary = {}
	var room_combat_frames: Dictionary = {}
	var room_combat_samples: Dictionary = {}
	var boss_photo_taken := false
	var floor_two_at := -1
	var seen_layouts: Dictionary = {}
	var rows := PackedStringArray(["time_ms,seq,auth_x,auth_y,view_x,view_y"])
	while Time.get_ticks_msec()-started < (480000 if full_campaign else 45000):
		await process_frame
		if role == "host" and game.phase == "lobby" and game.players.size() == expected_players:
			game.action_button.pressed.emit()
		if game.phase == "reward" and game.reward_overlay.visible:
			var player: Dictionary = game.state.get("players",{}).get(game.multiplayer.get_unique_id(),{})
			if not player.get("picked",false):
				for card: Button in game.reward_overlay.cards:
					if not card.disabled:
						card.pressed.emit()
						break
			elif not game.reward_overlay.ready_button.disabled: game.reward_overlay.ready_button.pressed.emit()
		if game.phase == "combat" and game.state.get("players",{}).size() == expected_players:
			if combat_start < 0: combat_start = Time.get_ticks_msec()
		if combat_start < 0: continue
		if game.phase == "dead": break
		if int(game.state.get("floor_index",0)) == 2 and not game.is_transitioning():
			if floor_two_at < 0: floor_two_at = Time.get_ticks_msec()
		if not visible_probe:
			if full_campaign:
				if floor_two_at >= 0 and Time.get_ticks_msec()-floor_two_at >= 8000: break
			elif Time.get_ticks_msec()-combat_start >= 17000: break
			continue
		if Time.get_ticks_msec()-combat_start < 2000: continue
		var now := Time.get_ticks_usec()
		if sample_start < 0:
			sample_start = now
			last_tick = now
			continue
		frames.append(float(now-last_tick)/1000.0)
		var observed_room: int = int(game.state.get("room",0))
		if int(game.state.get("floor_index",0)) == 1:
			if not room_frames.has(observed_room): room_frames[observed_room] = []
			room_frames[observed_room].append(float(now-last_tick)/1000.0)
			room_enemy_max[observed_room] = maxi(int(room_enemy_max.get(observed_room,0)),game.state.get("enemies",[]).size())
			room_bullet_max[observed_room] = maxi(int(room_bullet_max.get(observed_room,0)),game.state.get("bullets",[]).size())
			if game.phase == "combat":
				room_combat_frames[observed_room] = int(room_combat_frames.get(observed_room,0))+1
				if not room_combat_samples.has(observed_room): room_combat_samples[observed_room] = []
				room_combat_samples[observed_room].append(float(now-last_tick)/1000.0)
		seen_layouts[str(game.state.get("room_layout",{}).get("id",""))] = true
		last_tick = now
		var local_id: int = game.multiplayer.get_unique_id()
		var authoritative: Dictionary = game.state.get("players",{}).get(local_id,{})
		var rendered: Dictionary = game.view._snapshot.get("players",{}).get(local_id,{})
		if not authoritative.is_empty() and not rendered.is_empty():
			var point := Vector2(rendered.x,rendered.y)
			var sequence: int = game.state.get("seq",-1)
			if previous_sequence == sequence and point != previous_point: steps_between_packets += 1
			if point.distance_to(Vector2(authoritative.x,authoritative.y)) > 0.1: interpolated_frames += 1
			sequences[sequence] = true
			visual_ticks[game.view._snapshot.get("local_visual_tick",-1)] = true
			if rows.size() < 5000:
				rows.append("%.3f,%d,%.4f,%.4f,%.4f,%.4f" % [float(now-sample_start)/1000.0,sequence,authoritative.x,authoritative.y,rendered.x,rendered.y])
			previous_sequence = sequence
			previous_point = point
		max_enemies = maxi(max_enemies,game.state.get("enemies",[]).size())
		max_bullets = maxi(max_bullets,game.state.get("bullets",[]).size())
		if full_campaign and observed_room == 10 and not boss_photo_taken and not game.is_transitioning():
			for enemy: Dictionary in game.state.get("enemies",[]):
				if enemy.get("boss",false) and enemy.get("hp",0) > 0 and game.world_clip.get_global_rect().grow(-48).has_point(game.view.to_global(Vector2(enemy.x,enemy.y))):
					await RenderingServer.frame_post_draw
					DirAccess.make_dir_recursive_absolute(out_path)
					root.get_texture().get_image().save_png(out_path.path_join("four-player-boss.png"))
					boss_photo_taken = true
					break
		if full_campaign:
			if floor_two_at >= 0: break
		elif now-sample_start >= 8000000: break
	if visible_probe:
		var duration: float = float(Time.get_ticks_usec()-sample_start)/1000000.0 if sample_start >= 0 else 0.0
		frames.sort()
		var p95: float = frames[int(frames.size()*0.95)] if not frames.is_empty() else INF
		var passed: bool = frames.size() >= 400 and p95 <= 16.667 and steps_between_packets > 20 and game.state.get("players",{}).size() == expected_players and root.has_focus()
		var rooms: Dictionary = {}
		for number: int in room_frames:
			var samples: Array = room_frames[number]
			samples.sort()
			var room_p95: float = samples[int(samples.size()*0.95)]
			var combat_samples: Array = room_combat_samples.get(number,[])
			combat_samples.sort()
			var combat_p95: float = combat_samples[int(combat_samples.size()*0.95)] if not combat_samples.is_empty() else 0.0
			rooms[str(number)] = {"frames":samples.size(),"p95_ms":room_p95,"combat_p95_ms":combat_p95,"max_ms":samples[-1],"enemies_max":room_enemy_max.get(number,0),"bullets_max":room_bullet_max.get(number,0),"combat_frames":room_combat_frames.get(number,0)}
			if full_campaign and room_p95 > 16.667: passed = false
			if full_campaign and combat_p95 > 16.667: passed = false
		if full_campaign and (rooms.size() != 10 or floor_two_at < 0 or int(room_combat_frames.get(10,0)) == 0): passed = false
		var report := {"passed":passed,"scope":"visible real client with3 other loopback processes;2s warmup/8s sample; normal host-authoritative bot combat, no stat changes; not LAN/WAN or long-term load", "players":expected_players,"window_size":root.size,"fullscreen":game.is_fullscreen(),"window_focused":root.has_focus(),"gpu":RenderingServer.get_video_adapter_name(),"duration_s":duration,"frames":frames.size(),"average_fps":frames.size()/duration if duration > 0 else 0,"p95_ms":p95,"median_ms":frames[frames.size()/2] if not frames.is_empty() else 0,"max_ms":frames[-1] if not frames.is_empty() else 0,"target_p95_ms":16.667,"enemies_max":max_enemies,"bullets_max":max_bullets,"authoritative_updates":sequences.size(),"visual_updates":visual_ticks.size(),"position_steps_between_packets":steps_between_packets,"interpolated_frames":interpolated_frames,"buffer_size":game.snapshot_interpolator.buffered_snapshots()}
		report.rooms = rooms
		report.layout_ids = seen_layouts.keys()
		report.full_campaign = full_campaign
		report.boss_photo_taken = boss_photo_taken
		report.bot_navigation_warmup = bot_navigation_warmup
		if full_campaign: report.scope = "visible real client through all10 rooms/boss/stairs with3 other loopback processes;2s initial warmup; normal host-authoritative bot inputs; not real LAN/WAN"
		DirAccess.make_dir_recursive_absolute(out_path)
		var file := FileAccess.open(out_path.path_join("client-frame-times.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t",true)+"\n")
		file.close()
		file = FileAccess.open(out_path.path_join("client-positions.csv"),FileAccess.WRITE)
		file.store_string("\n".join(rows)+"\n")
		file.close()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_path.path_join("client-four-player.png"))
		print("CLIENT_RENDER_PROFILE ",JSON.stringify(report))
		game._leave_session()
		quit(0 if passed else 1)
	else:
		game._leave_session()
		quit(0 if combat_start >= 0 else 1)
