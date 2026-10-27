extends SceneTree
## One real ENet peer: bots win combat, cards request ordinary perk/ready actions.
var failed := false

func fail(message: String) -> void:
	failed = true
	printerr("REWARD_NET_FAIL: ",message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Arrange two peers through the companion PowerShell process harness.
	var args := OS.get_cmdline_user_args()
	var host := "--test-host" in args
	var port_index := args.find("--test-port")
	if port_index < 0 or port_index+1 >= args.size():
		fail("--test-port is required")
		print("REWARD_PEER role=%s result=FAIL" % ("host" if host else "client"))
		quit(1)
		return
	var game = load("res://src/game.gd").new()
	root.add_child(game)
	await process_frame
	game.session_bind_ip = "127.0.0.1"
	game.port_input.text = args[port_index+1]
	game.smoke_role = "host" if host else "client"
	game.requested_seed = 24680
	if host: game._host_session()
	else: game._join_session()
	var started := Time.get_ticks_msec()
	var selected_index := 0 if host else 1
	var selected_id := ""
	var offered_ids: Array[String] = []
	var opened := false
	var acknowledged := false
	var acknowledged_at := -1
	var ready_sent := false
	var explored := false
	var explored_at := -1
	while Time.get_ticks_msec()-started < 20000:
		# SceneTree emits process_frame before Game._process, so opening the
		# first actual reward blocks the existing bots' automatic reward path.
		await process_frame
		if failed: break
		if host and game.phase == "lobby" and game.players.size() == 2:
			game._begin_run()
		if game.phase == "dead":
			fail("ordinary combat ended in a team wipe")
			break
		if game.phase == "reward" and not opened:
			game.show_rewards()
			opened = true
			var player: Dictionary = game.state.get("players",{}).get(game.multiplayer.get_unique_id(),{})
			var options: Array = game.state.get("perk_options",[])
			if options.size() != 3 or player.is_empty() or player.get("hp",0) <= 0:
				fail("first reward lacks three offers or a living local player")
				break
			if not game.reward_overlay.visible or game.pause_menu.visible or not game.pause_open:
				fail("the independent card view did not replace the opaque pause view")
			if not game.reward_overlay.ready_button.disabled or player.get("picked",false):
				fail("Ready was enabled or a bot picked before card selection")
			if game.is_solo_paused() or paused:
				fail("the multiplayer reward view paused the shared world")
			if failed: break
			for option: Dictionary in options: offered_ids.append(str(option.id))
			selected_id = offered_ids[selected_index]
			# Act through the same visible card signal as mouse/keyboard users.
			game.reward_overlay.cards[selected_index].pressed.emit()
		if opened and game.phase == "reward" and not acknowledged:
			var local: Dictionary = game.state.get("players",{}).get(game.multiplayer.get_unique_id(),{})
			if local.get("picked",false):
				acknowledged = true
				acknowledged_at = Time.get_ticks_msec()
				game._refresh_ui()
				var owned: Array = local.get("perks",[])
				if owned.size() != 1 or str(owned.back()) != selected_id:
					fail("host acknowledgement granted a different or duplicate personal perk")
				if game.reward_overlay.selected_index != selected_index or game.reward_overlay.ready_button.disabled:
					fail("confirmed card selection did not unlock Ready")
		if acknowledged and not ready_sent and Time.get_ticks_msec()-acknowledged_at >= 150:
			# Keep normal 80ms server action rate limiting intact.
			game.reward_overlay.ready_button.pressed.emit()
			ready_sent = true
		if opened and game.phase == "explore" and not explored:
			# Stop ordinary exploration bots before they can walk to another room.
			game.smoke_role = ""
			game._refresh_ui()
			explored = true
			explored_at = Time.get_ticks_msec()
			if not acknowledged or not ready_sent or game.room != 1:
				fail("exploration started without this card/Ready flow or changed rooms")
			if game.pause_open or game.reward_open or game.reward_overlay.visible:
				fail("the acknowledged shared Ready transition left a modal open")
			var party: Dictionary = game.state.get("players",{})
			if party.size() != 2:
				fail("both participants must still be present after shared Ready")
			for id: Variant in party:
				var expected := offered_ids[0 if int(id) == 1 else 1]
				var owned: Array = party[id].get("perks",[])
				if owned.size() != 1 or str(owned.back()) != expected or not party[id].get("ready",false):
					fail("shared snapshot does not preserve each participant's distinct choice")
		if explored:
			if game.phase != "explore" or game.room != 1:
				fail("a bot transitioned after the card test finished")
			if Time.get_ticks_msec()-explored_at >= (1500 if host else 500): break
	if not opened or not acknowledged or not ready_sent or not explored:
		fail("card selection, host confirmation and shared exploration did not finish before the deadline")
	print("REWARD_PEER role=%s selected=%s acknowledged=%s explored=%s result=%s" % ["host" if host else "client",selected_id,acknowledged,explored,"FAIL" if failed else "PASS"])
	game._leave_session()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
