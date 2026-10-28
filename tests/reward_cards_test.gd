extends SceneTree
## Real game actions and independently delayed reward acknowledgements.
const Game = preload("res://src/game.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("REWARD_CARDS_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.has_method("show_rewards"), "rewards have a separate card overlay")
	if not game.has_method("show_rewards"):
		game.queue_free()
		finish()
		return
	var probe := PacketPeerUDP.new()
	probe.bind(0,"127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	# The per-room reward flow is tested on single encounters (no hordes).
	game.hordes.enabled = false
	# This test covers the per-room reward cards, now an optional mode.
	game.balance.perk_rules.room_rewards = true
	game.requested_seed = 3
	game._begin_run()
	game.enemies.clear()
	game._check_room_end()
	# Since Story021 every player gets personal offers (perk_offers); the cards
	# show and grant those, so the test no longer overrides perk_options.
	var offers: Array = game.perk_offers.get(1, [])
	game._broadcast_state(true)
	game.show_rewards()
	check(game.reward_overlay.visible and not game.pause_menu.visible, "reward cards hide the complete opaque pause panel")
	check(game.pause_open and game.is_solo_paused(), "the card view retains solo pause and input protection")
	check(game.reward_overlay.shade.color.a > 0 and game.reward_overlay.shade.color.a < 0.6, "the world remains visible through the reward backdrop")
	var cards: Array = game.reward_overlay.cards
	check(cards.size() == 3 and cards[0].position.x < cards[1].position.x and cards[1].position.x < cards[2].position.x and cards[0].position.y == cards[2].position.y, "three upright cards form one horizontal choice")
	check(cards[0].get_theme_stylebox("normal").bg_color.a < 1.0, "card bodies are translucent too")
	var icon = cards[0].get_node("Icon")
	check(icon.texture != null and icon.size.x >= 80 and icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "a large centered sprite stays clickable through its image")
	# Pixel Operator 8 replaced Pixelify Sans in the 2026-10-26 typography revision.
	check(not game.ui.theme.default_font is SystemFont and game.ui.theme.default_font.get_font_name().contains("Pixel Operator"), "game menus use the bundled pixel font")
	check(root.gui_get_focus_owner() == cards[0], "first available card receives keyboard focus")
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	Input.parse_input_event(right)
	await process_frame
	right.pressed = false
	Input.parse_input_event(right)
	await process_frame
	check(root.gui_get_focus_owner() == cards[1], "Right moves keyboard focus to the second card")
	game.action_times.clear()
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	await process_frame
	accept.pressed = false
	Input.parse_input_event(accept)
	await process_frame
	game._refresh_ui()
	check(offers.size() == 3 and game.players[1].perks == [offers[1].id], "a card requests the matching authoritative perk")
	cards[1].pressed.emit()
	check(game.players[1].perks.size() == 1, "duplicate card activation grants no duplicate perk")
	check(not game.reward_overlay.ready_button.disabled and root.gui_get_focus_owner() == game.reward_overlay.ready_button, "acknowledged selection enables and focuses Ready")
	game.set_pause_open(false)
	game.show_rewards()
	check(game.reward_overlay.selected_index == 1 and game.reward_overlay.cards[0].disabled, "closing and reopening retains the actual chosen card")
	game.action_times.clear()
	game.reward_overlay.ready_button.pressed.emit()
	check(game.phase == "explore" and not game.pause_open and not game.reward_overlay.visible and game.room == 1, "ready returns to exploration without a room teleport")
	game.pause_menu.select_section("reward")
	check(game.reward_overlay.visible and not game.pause_menu.visible, "the information menu routes rewards to the independent view")
	game._leave_session()
	check(not game.reward_overlay.visible and not game.pause_open, "disconnect clears both modal views")
	game.queue_free()
	await process_frame
	var overlay = load("res://src/reward_overlay.gd").new()
	root.add_child(overlay)
	overlay.visible = true
	var fixture := {"phase":"reward","floor_index":1,"room_layout":{"id":"ack-fixture"},"players":{1:{"hp":8,"max_hp":8,"picked":false,"ready":false,"perks":[]}},"perk_options":[{"id":"ember","name":"Glutkern","description":"+1 Schaden","stat":"damage"},{"id":"shadow","name":"Schattenschritt","description":"Schneller laufen","stat":"speed"},{"id":"heart","name":"Blutherz","description":"Mehr Leben","stat":"max_hp"}]}
	overlay.set_state(fixture,1,true)
	overlay.cards[2].pressed.emit()
	overlay.set_state(fixture,1,true)
	check(overlay.cards.all(func(card: Button): return card.disabled) and overlay.ready_button.disabled, "in-flight selection waits for a host acknowledgement")
	fixture.players[1].picked = true
	fixture.players[1].perks = ["heart"]
	overlay.set_state(fixture,1,true)
	check(overlay.selected_index == 2 and not overlay.ready_button.disabled, "only the confirmed host state unlocks Ready and marks the selected card")
	overlay.close_button.grab_focus()
	overlay.set_state(fixture,1,true)
	check(root.gui_get_focus_owner() == overlay.close_button, "repeated network snapshots do not steal keyboard focus")
	overlay.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("REWARD_CARDS checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
