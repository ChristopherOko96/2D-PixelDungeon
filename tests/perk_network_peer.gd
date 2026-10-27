extends SceneTree
## Controlled two-process reward fixture. Enemy clearing is test setup, not a run.

var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		printerr("PERK_NET_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var host: bool = "--perk-host" in args
	var port_index: int = args.find("--perk-port")
	var result_index: int = args.find("--perk-result")
	if port_index < 0 or port_index+1 >= args.size() or result_index < 0 or result_index+1 >= args.size():
		printerr("PERK_NET_FAIL: port and result path are required")
		quit(2)
		return
	var game: Node = load("res://src/game.gd").new()
	root.add_child(game)
	await process_frame
	game.session_bind_ip = "127.0.0.1"
	game.port_input.text = args[port_index+1]
	game.requested_seed = 42026
	if host: game._host_session()
	else: game._join_session()
	var deadline: int = Time.get_ticks_msec()+15000
	var fixture_started: bool = false
	var selection_sent: bool = false
	var duplicate_sent: bool = false
	var ready_sent: bool = false
	var explored: bool = false
	var acknowledged_at: int = -1
	var duplicate_at: int = -1
	var explored_at: int = -1
	var selected_id: String = ""
	var initial_owned: int = -1
	var observed_offer_ids: Array[String] = []
	while Time.get_ticks_msec() < deadline and failures.is_empty():
		await process_frame
		if host and not fixture_started and game.phase == "lobby" and game.players.size() == 2:
			# Arrange a genuinely admitted pair and a controlled reward fixture.
			game._begin_run()
			var ember: Dictionary = {}
			for definition: Dictionary in game.balance.perks:
				if str(definition.id) == "ember": ember = definition
			check(not ember.is_empty(), "the catalogue supplies ember for the max-stack fixture")
			for stack: int in range(int(ember.get("max_stacks",1))):
				game._grant_perk(1, ember)
			game.players[1].picked = false
			game.players[1].ready = false
			game.enemies.clear()
			game._check_room_end()
			fixture_started = true
			print("PERK_NET_FIXTURE controlled_enemy_clear=true host_ember_stacks=%d" % game.players[1].perks.size())
		if game.phase == "reward" and not selection_sent:
			game.show_rewards()
			game._refresh_ui()
			var local_id: int = int(game.multiplayer.get_unique_id())
			var local: Dictionary = game.state.get("players",{}).get(local_id,{})
			var options: Array = game.state.get("perk_options",[])
			check(options.size() == 3, "each admitted peer receives three eligible personal offers")
			check(not local.is_empty(), "personal offer identifies a replicated participant")
			if not failures.is_empty(): break
			initial_owned = local.get("perks",[]).size()
			for definition: Dictionary in options: observed_offer_ids.append(str(definition.id))
			check(observed_offer_ids.size() == 3 and observed_offer_ids[0] != observed_offer_ids[1] and observed_offer_ids[0] != observed_offer_ids[2] and observed_offer_ids[1] != observed_offer_ids[2], "personal cards have no duplicate IDs")
			if host: check("ember" not in observed_offer_ids, "the host's capped ember never reappears in its offer")
			var all_offers: Dictionary = game.state.get("perk_offers",{})
			check(all_offers.has(local_id), "snapshot retains per-player authoritative offer mapping")
			if all_offers.has(local_id):
				check(JSON.stringify(all_offers[local_id]) == JSON.stringify(options), "visible cards are this peer's offer, not the host's offer")
			selected_id = observed_offer_ids[0 if host else 1]
			# Act through the same visible card signal used by a human.
			game.reward_overlay.cards[0 if host else 1].pressed.emit()
			selection_sent = true
		if selection_sent and game.phase == "reward":
			var local_id: int = int(game.multiplayer.get_unique_id())
			var local: Dictionary = game.state.get("players",{}).get(local_id,{})
			var owned: Array = local.get("perks",[])
			if bool(local.get("picked",false)) and acknowledged_at < 0:
				check(owned.size() == initial_owned+1 and str(owned.back()) == selected_id, "the host confirms exactly the selected personal perk")
				acknowledged_at = Time.get_ticks_msec()
			if acknowledged_at >= 0 and not duplicate_sent and Time.get_ticks_msec()-acknowledged_at >= 150:
				# Malformed/stale requests still pass through ordinary action authority.
				game._send_action("perk",99)
				duplicate_sent = true
				duplicate_at = Time.get_ticks_msec()
			if duplicate_sent and not ready_sent and Time.get_ticks_msec()-duplicate_at >= 150:
				game._send_action("perk",0)
				ready_sent = true
				duplicate_at = Time.get_ticks_msec()
			elif ready_sent and Time.get_ticks_msec()-duplicate_at >= 150 and not bool(local.get("ready",false)):
				check(owned.size() == initial_owned+1, "malformed and repeated perk actions cannot grant additional items")
				game.reward_overlay.ready_button.pressed.emit()
				duplicate_at = Time.get_ticks_msec()
		if selection_sent and game.phase == "explore":
			if not explored:
				explored = true
				explored_at = Time.get_ticks_msec()
				check(game.room == 1 and game.state.get("players",{}).size() == 2, "both peers enter shared exploration without changing rooms")
				for peer_id: Variant in game.state.get("players",{}):
					var member: Dictionary = game.state.players[peer_id]
					var offers: Array = game.state.get("perk_offers",{}).get(peer_id,[])
					var choice: int = 0 if int(peer_id) == 1 else 1
					check(offers.size() == 3 and str(member.perks.back()) == str(offers[choice].id), "replicated party inventory matches each owner's selected card")
			if Time.get_ticks_msec()-explored_at >= (900 if host else 300): break
	check(selection_sent and acknowledged_at >= 0 and duplicate_sent and ready_sent and explored, "personal selection/acknowledgement/rejection/readiness completed before deadline")
	var result: Dictionary = {"passed":failures.is_empty(), "role":"host" if host else "client", "scope":"controlled loopback reward fixture, not played campaign/LAN/benchmark", "selected":selected_id, "offer_ids":observed_offer_ids, "explored":explored, "failures":failures}
	var file: FileAccess = FileAccess.open(args[result_index+1],FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"\t"))
	else: check(false,"result file could not be written")
	print("PERK_PEER role=%s selected=%s result=%s" % [result.role,selected_id,"PASS" if failures.is_empty() else "FAIL"])
	game._leave_session()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
