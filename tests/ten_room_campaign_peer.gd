extends SceneTree
## End-to-end peer: normal combat/input/UI actions, never direct state grants.

class CampaignGame extends "res://src/game.gd":
	var campaign_backtrack_seen := false
	func _smoke_exit() -> Dictionary:
		var visible_room := int(state.get("room",room))
		if int(state.get("floor_index",1)) == 1 and visible_room == 2 and not campaign_backtrack_seen:
			for exit: Dictionary in state.get("room_layout",{}).get("exits",[]):
				if exit.kind == "door" and int(exit.target_room) == 1: return exit
		return super._smoke_exit()

class LateProbe extends Node:
	var visit: Callable
	func _process(_delta: float) -> void:
		if visit.is_valid(): visit.call()

var game
var is_host := false
var wanted_players := 1
var timeout_seconds := 900
var seed_value := 42026
var scenario := "campaign"
var bind_address := "127.0.0.1"
var host_address := "127.0.0.1"
var report_path := ""
var failed := false
var errors: Array[String] = []
var layouts: Array[Dictionary] = []
var layout_keys: Dictionary = {}
var reward_rooms: Dictionary = {}
var sounds: Dictionary = {}
var sound_kinds: Array[String] = []
var black_frames: Dictionary = {}
var swaps: Dictionary = {}
var last_displayed := ""
var prior_room := 0
var backtrack_returned := false
var perks_before_backtrack := -1
var next_ui_action_at := 0
var observed_wipe := false
var wipe_seen_at := -1
var restart_requested := false
var stopped_after_reward := false
var earned_before_wipe := 0
var starting_enemy_count := -1
var finished_at := -1
var started_at := 0
var last_progress_at := 0
var last_transition_audio_count := 0
var actual_view_frames := 0
var probe: LateProbe

func _initialize() -> void:
	_run.call_deferred()

func _argument(key: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(key)
	return args[index+1] if index >= 0 and index+1 < args.size() else fallback

func _fail(message: String) -> void:
	if message in errors: return
	errors.append(message)
	failed = true
	printerr("CAMPAIGN_FAIL ",message)

func _run() -> void:
	is_host = _argument("--campaign-role","host") == "host"
	wanted_players = int(_argument("--campaign-players","1"))
	timeout_seconds = int(_argument("--campaign-seconds","900"))
	seed_value = int(_argument("--campaign-seed","42026"))
	scenario = _argument("--campaign-scenario","campaign")
	bind_address = _argument("--campaign-bind","127.0.0.1")
	host_address = _argument("--campaign-address","127.0.0.1")
	report_path = _argument("--campaign-report","")
	var port := _argument("--campaign-port","")
	if not port.is_valid_int() or wanted_players not in [1,2,4] or scenario not in ["campaign","restart","restart_after_reward"]:
		_fail("Valid port, player count and scenario are required")
		quit(1)
		return
	game = CampaignGame.new()
	game.name = "Game"
	root.add_child(game)
	current_scene = game
	game.session_bind_ip = bind_address
	game.address_input.text = host_address
	game.port_input.text = port
	game.requested_seed = seed_value
	game.smoke_floor_limit = 2
	game.smoke_role = ("host" if is_host else "client") if scenario in ["campaign","restart_after_reward"] else ""
	game.transition_view.sound_requested.connect(_on_sound)
	probe = LateProbe.new()
	probe.process_priority = 100
	probe.visit = _observe_frame
	root.add_child(probe)
	if is_host: game._host_session()
	else: game._join_session()
	started_at = Time.get_ticks_msec()
	while Time.get_ticks_msec()-started_at < timeout_seconds*1000:
		await process_frame
		if failed: break
		if is_host and game.phase == "lobby" and game.players.size() == wanted_players and game.action_button.visible and not game.action_button.disabled:
			game.action_button.pressed.emit()
		if starting_enemy_count < 0 and game.phase == "combat" and game.room == 1:
			starting_enemy_count = game.state.get("enemies",[]).size()
		if scenario == "restart_after_reward" and game.room == 2 and game.phase == "combat" and not stopped_after_reward:
			var local_id: int = game.multiplayer.get_unique_id()
			earned_before_wipe = game.state.get("players",{}).get(local_id,{}).get("perks",[]).size()
			if earned_before_wipe < 1: _fail("Restart-after-reward did not earn a real perk first")
			stopped_after_reward = true
			game.smoke_role = ""
			print("CAMPAIGN_BUILD_BEFORE_WIPE peer=%d perks=%d room=%d" % [local_id,earned_before_wipe,game.room])
		if game.active and game.phase == "reward": _drive_reward()
		if scenario == "campaign" and game.phase == "dead":
			_fail("Ordinary-input combat reached a team wipe before the campaign completed")
			break
		if scenario in ["restart","restart_after_reward"]: _drive_restart()
		if scenario == "campaign" and int(game.state.get("floor_index",0)) == 2 and game.room == 1 and game.phase == "combat" and not game.is_transitioning():
			if finished_at < 0:
				finished_at = Time.get_ticks_msec()
				game.smoke_role = ""
		if finished_at >= 0 and Time.get_ticks_msec()-finished_at >= (1800 if is_host else 500): break
		if Time.get_ticks_msec()-last_progress_at >= 10000:
			last_progress_at = Time.get_ticks_msec()
			var member: Dictionary = game.state.get("players",{}).get(game.multiplayer.get_unique_id(),{}) if game.active else {}
			print("CAMPAIGN_PROGRESS role=%s seconds=%d floor=%d room=%d phase=%s hp=%s enemies=%d" % ["host" if is_host else "client",(Time.get_ticks_msec()-started_at)/1000,game.state.get("floor_index",0),game.room,game.phase,member.get("hp",-1),game.state.get("enemies",[]).size()])
	if finished_at < 0 and not failed: _fail("Scenario did not finish within%d seconds" % timeout_seconds)
	probe.set_process(false)
	if scenario == "campaign" and not failed: _assert_campaign()
	if scenario in ["restart","restart_after_reward"] and not failed:
		if not observed_wipe or (is_host and not restart_requested): _fail("Restart must follow an observed wipe and an enabled host menu action")
		if scenario == "restart_after_reward" and earned_before_wipe < 1: _fail("No built character was observed before the wipe")
	var local_id: int = game.multiplayer.get_unique_id() if game.active else 0
	var member: Dictionary = game.state.get("players",{}).get(local_id,{})
	var report := {"result":"FAIL" if failed else "PASS","scope":"normal authoritative bot inputs and actual reward button signals; independent local process; not LAN or subjective play acceptance","role":"host" if is_host else "client","scenario":scenario,"players":wanted_players,"peer_id":local_id,"seed":seed_value,"elapsed_seconds":float(Time.get_ticks_msec()-started_at)/1000.0,"layouts":layouts,"reward_rooms":reward_rooms.keys(),"reward_eligibility":reward_rooms,"expected_reward_grants":reward_rooms.values().count(true),"earned_perks":member.get("perks",[]).size(),"earned_before_wipe":earned_before_wipe,"starting_enemy_count":starting_enemy_count,"backtrack_returned":backtrack_returned,"sounds":sounds,"sound_kinds":sound_kinds,"black_frames":black_frames,"swaps":swaps,"actual_view_frames":actual_view_frames,"observed_wipe":observed_wipe,"restart_requested":restart_requested,"errors":errors}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path,FileAccess.WRITE)
		if file == null: _fail("Cannot write campaign report")
		else:
			file.store_string(JSON.stringify(report,"\t",true)+"\n")
			file.close()
	print("CAMPAIGN_RESULT ",JSON.stringify(report))
	game._leave_session()
	game.queue_free()
	probe.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _drive_reward() -> void:
	if Time.get_ticks_msec() < next_ui_action_at: return
	next_ui_action_at = Time.get_ticks_msec()+120
	var local_id: int = game.multiplayer.get_unique_id()
	var player: Dictionary = game.state.get("players",{}).get(local_id,{})
	if player.is_empty() or player.get("hp",0) <= 0: return
	# Let the ordinary automatic offer open first; no UI flags are patched.
	if not game.reward_overlay.is_visible_in_tree(): return
	if not player.get("picked",false):
		var options: Array = game.state.get("perk_options",[])
		var preferred := ["ember","quick","heart","mend","shadow"]
		if int(player.hp) <= 3: preferred = ["heart","mend","ember","quick","shadow"]
		for id: String in preferred:
			for index in range(options.size()):
				if options[index].id == id and not game.reward_overlay.cards[index].disabled:
					game.reward_overlay.cards[index].pressed.emit()
					return
	elif not player.get("ready",false) and not game.reward_overlay.ready_button.disabled:
		game.reward_overlay.ready_button.pressed.emit()

func _drive_restart() -> void:
	if game.phase == "dead":
		var wiped_players: Dictionary = game.state.get("players",{})
		if wiped_players.size() != wanted_players:
			_fail("Team wipe did not retain every expected participant")
			return
		for member: Dictionary in wiped_players.values():
			if member.get("hp",1) > 0:
				_fail("Dead phase still contained a living participant")
				return
		observed_wipe = true
		if wipe_seen_at < 0: wipe_seen_at = Time.get_ticks_msec()
		if is_host and not restart_requested and Time.get_ticks_msec()-wipe_seen_at >= 700:
			game.set_pause_open(true,"overview")
			if game.pause_menu.main_action_button.visible and not game.pause_menu.main_action_button.disabled:
				restart_requested = true
				game.pause_menu.main_action_button.pressed.emit()
	if observed_wipe and game.phase == "combat" and not game.is_transitioning():
		if game.room != 1 or int(game.state.get("floor_index",0)) != 1 or not game.state.get("cleared_room_ids",[]).is_empty():
			_fail("Restart did not reset to floor1/room1 with no cleared rooms")
			return
		var players: Dictionary = game.state.get("players",{})
		if players.size() != wanted_players: return
		for member: Dictionary in players.values():
			if member.hp != int(game.balance.player.hp) or member.max_hp != int(game.balance.player.hp) or not member.perks.is_empty():
				_fail("Restart did not restore ordinary base HP/empty build")
				return
		if game.state.get("enemies",[]).size() != starting_enemy_count:
			_fail("Restart did not create a fresh first encounter")
			return
		for enemy: Dictionary in game.state.get("enemies",[]):
			if enemy.hp != enemy.max_hp: _fail("Restart retained a damaged enemy")
		if is_host:
			for member: Dictionary in game.players.values():
				if member.damage != float(game.balance.player.damage) or member.speed != float(game.balance.player.speed) or member.shot_interval != float(game.balance.player.shot_interval): _fail("Restart retained a modified perk statistic")
		if finished_at < 0: finished_at = Time.get_ticks_msec()

func _on_sound(kind: String) -> void:
	var token: int = game.transition_view.current_token
	sounds[token] = int(sounds.get(token,0))+1
	sound_kinds.append(kind)
	if sounds[token] != 1: _fail("Transition sound repeated for token%d" % token)
	if game.view._sfx == null or game.view._sfx.last_effect != kind:
		_fail("Transition sound did not reach its ordinary audio player")
	elif int(game.view._sfx.play_count) <= last_transition_audio_count:
		_fail("Transition audio counter did not advance")
	else:
		last_transition_audio_count = int(game.view._sfx.play_count)

func _observe_frame() -> void:
	if game == null or not game.active: return
	var snapshot: Dictionary = game.state
	var layout: Dictionary = snapshot.get("room_layout",{})
	if not layout.is_empty():
		var key := "%d:%s" % [snapshot.get("floor_index",0),layout.id]
		if not layout_keys.has(key):
			layout_keys[key] = true
			var boss_count := 0
			for enemy: Dictionary in snapshot.get("enemies",[]):
				if enemy.get("boss",false): boss_count += 1
			if boss_count != (1 if layout.boss else 0): _fail("Actual boss entity count differs from the room layout")
			layouts.append({"id":layout.id,"floor":snapshot.get("floor_index",0),"room":snapshot.get("room",0),"template":layout.template_id,"boss":layout.boss,"boss_entities":boss_count,"signature":var_to_bytes(layout).hex_encode().sha256_text()})
			print("CAMPAIGN_LAYOUT ",JSON.stringify(layouts.back()))
		var local_id: int = game.multiplayer.get_unique_id()
		var player: Dictionary = snapshot.get("players",{}).get(local_id,{})
		if game.phase == "reward":
			reward_rooms[key] = player.get("hp",0) > 0
			if game.room == 2 and perks_before_backtrack < 0 and player.get("picked",false): perks_before_backtrack = player.get("perks",[]).size()
		if scenario == "campaign" and int(snapshot.get("floor_index",0)) == 1:
			if game.room == 2 and game.phase == "explore" and not game.campaign_backtrack_seen and perks_before_backtrack < 0:
				perks_before_backtrack = player.get("perks",[]).size()
			if game.room == 1 and prior_room == 2:
				game.campaign_backtrack_seen = true
				print("CAMPAIGN_BACKTRACK arrived_room=1")
			if game.room == 2 and prior_room == 1 and game.campaign_backtrack_seen and game.phase == "explore":
				backtrack_returned = true
				if player.get("perks",[]).size() != perks_before_backtrack: _fail("Backtracking granted an extra reward")
				print("CAMPAIGN_BACKTRACK returned_room=2 perks=%d" % player.get("perks",[]).size())
			prior_room = game.room
	var presenter = game.transition_view
	var shown: Dictionary = presenter.display_state()
	var shown_id := str(shown.get("room_layout",{}).get("id",""))
	var actual_view_id := str(game.view._snapshot.get("room_layout",{}).get("id",""))
	if actual_view_id != shown_id: _fail("Actual rendered room differs from the black-fenced controller room")
	if not shown_id.is_empty():
		actual_view_frames += 1
		if int(game.view._snapshot.get("room_layout_revision",0)) != int(shown.get("room_layout_revision",0)): _fail("Actual rendered room revision differs from the black-fenced controller revision")
	var token: int = presenter.current_token
	if not shown_id.is_empty() and shown_id != last_displayed:
		# A confirmed dead-to-new-run menu action resets the presentation directly;
		# only in-floor door/stair changes are required to pass through the fade.
		var restarted_run: bool = observed_wipe and scenario in ["restart","restart_after_reward"] and game.phase == "combat" and game.room == 1 and int(snapshot.get("floor_index",0)) == 1 and snapshot.get("cleared_room_ids",[]).is_empty() and not presenter.is_active() and shown_id == str(layout.get("id",""))
		if not last_displayed.is_empty() and not restarted_run:
			if presenter.opacity < 1.0 or int(black_frames.get(token,0)) < 1: _fail("Displayed room changed without a previous black frame")
			swaps[token] = int(swaps.get(token,0))+1
			if swaps[token] != 1: _fail("Transition exposed multiple room swaps")
		last_displayed = shown_id
	if token >= 0 and presenter.is_active() and presenter.opacity >= 1.0:
		black_frames[token] = int(black_frames.get(token,0))+1

func _assert_campaign() -> void:
	if not backtrack_returned: _fail("No ordinary-input backtrack1->2->1->2 was completed")
	if reward_rooms.size() != 10: _fail("Expected exactly ten distinct reward rooms")
	var member: Dictionary = game.state.get("players",{}).get(game.multiplayer.get_unique_id(),{})
	if member.get("perks",[]).size() != reward_rooms.values().count(true): _fail("Living-room eligibility and actual earned perks differ")
	if layouts.size() != 11: _fail("Expected ten original rooms and new-floor room1")
	var templates: Dictionary = {}
	for entry: Dictionary in layouts:
		if entry.floor != 1: continue
		templates[entry.template] = true
		if bool(entry.boss) != (int(entry.room) == 10): _fail("Boss layout must occur only in room10")
	if templates.size() != 10: _fail("Original floor reused a room template")
	if sound_kinds.count("door") != 11 or sound_kinds.count("stairs") != 1: _fail("Expected eleven doors (including backtrack) and one stair")
	for token: Variant in sounds:
		if int(sounds[token]) != 1 or int(swaps.get(token,0)) != 1 or int(black_frames.get(token,0)) < 1:
			_fail("Missing exactly-once sound, black frame or swap for transition%d" % token)
