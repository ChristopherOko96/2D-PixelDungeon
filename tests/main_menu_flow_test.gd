extends SceneTree
## Main menu wiring (step 1 of the main port): the game opens on the title
## screen, story starts a solo crypt run, multiplayer opens the lobby, leaving
## returns to the menu, and the debug level list jumps to rooms and floor 2.
## Uses a disposable loopback host like pause_menu_test.
const Game = preload("res://src/game.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("MAIN_MENU_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _new_game() -> Node:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var port := PacketPeerUDP.new()
	port.bind(0, "127.0.0.1")
	game.port_input.text = str(port.get_local_port())
	port.close()
	game.session_bind_ip = "127.0.0.1"
	game.requested_seed = 24680
	return game

func _run() -> void:
	await _test_default_port_field_is_a_valid_port()
	await _test_opens_on_menu_with_endless_disabled_and_no_account()
	await _test_multiplayer_opens_lobby_and_lobby_returns_to_menu()
	await _test_story_starts_solo_run_and_leaving_returns_to_menu()
	await _test_debug_room_jump_starts_in_that_room_with_earlier_rooms_cleared()
	await _test_debug_floor_two_starts_on_the_next_floor()
	await _test_shake_option_scales_view_shake()
	finish()

## Regression: JSON numbers load as floats, so the port field read "7777.0",
## _port() returned 0 and every solo/story start failed outside the tests
## (which always overwrite the field).
func _test_default_port_field_is_a_valid_port() -> void:
	# Arrange
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	# Act
	var port: int = game._port()
	# Assert
	check(game.port_input.text == str(int(game.balance.network.port)), "the port field shows the configured port as a whole number")
	check(port == int(game.balance.network.port), "the untouched port field yields the configured port")
	game.queue_free()
	await process_frame

func _test_opens_on_menu_with_endless_disabled_and_no_account() -> void:
	# Arrange / Act
	var game = await _new_game()
	# Assert
	check(game.main_menu.visible and not game.lobby_ui.visible and not game.active, "the game opens on the main menu, not the lobby")
	check(game.main_menu._endless_button.disabled and game.main_menu._endless_button.text.ends_with("BALD"), "endless is shown as coming soon")
	check(not game.main_menu._account_button.visible and not game.main_menu._account_label.visible, "without online accounts the account row is hidden")
	check(not game.solo_button.visible, "solo starts from the menu, not from the lobby")
	game.queue_free()
	await process_frame

func _test_multiplayer_opens_lobby_and_lobby_returns_to_menu() -> void:
	# Arrange
	var game = await _new_game()
	# Act
	game.main_menu.multiplayer_requested.emit()
	# Assert
	check(not game.main_menu.visible and game.lobby_ui.visible and game.host_button.visible and game.lobby_menu_button.visible, "multiplayer shows the host/join lobby")
	# Act
	game.lobby_menu_button.pressed.emit()
	# Assert
	check(game.main_menu.visible and not game.lobby_ui.visible, "the lobby's main menu button returns to the title screen")
	game.queue_free()
	await process_frame

func _test_story_starts_solo_run_and_leaving_returns_to_menu() -> void:
	# Arrange
	var game = await _new_game()
	# Act: story opens the hero choice (step 2); picking a hero starts the run.
	game.main_menu._open_classes(false)
	check(game.main_menu._class_panel.visible and not game.active, "story first shows the hero cards")
	game.main_menu._choose_class("swordsman")
	game._refresh_ui()
	# Assert
	check(game.active and game.hosting and game.phase == "combat" and game.room == 1 and game.floor_index == 1, "story starts a solo run in room 1 of floor 1")
	check(game.players[1].class_id == "swordsman" and game.players[1].melee and game.players[1].max_hp == 10, "the chosen hero class is applied to the solo player")
	check(not game.main_menu.visible and not game.lobby_ui.visible and game.heart_hud.visible, "during the run neither menu nor lobby is visible")
	# Act
	game._leave_session()
	# Assert
	check(game.main_menu.visible and not game.lobby_ui.visible and not game.active, "leaving the run returns to the main menu")
	game.queue_free()
	await process_frame

func _test_debug_room_jump_starts_in_that_room_with_earlier_rooms_cleared() -> void:
	# Arrange
	var game = await _new_game()
	var entries: Array = game.main_menu.debug_entries
	var count: int = game._run_room_count()
	check(entries.size() == count + 1, "the debug list has every room of floor 1 plus floor 2")
	check(str(entries[count - 1].label).contains("BOSS"), "the last room entry is labelled as the boss room")
	# Act: a debug pick also goes through the hero choice.
	game.main_menu._pick_debug(entries[count - 1])
	game.main_menu._choose_class("mage")
	# Assert
	var bosses := 0
	for enemy: Dictionary in game.enemies:
		if bool(enemy.boss): bosses += 1
	check(game.phase == "combat" and game.room == count and game.floor_index == 1, "the boss entry starts in the last room")
	check(game.cleared_room_ids.size() == count - 1, "all rooms before the jump target count as cleared")
	check(bosses == 1, "the jumped-to boss room spawns exactly one boss")
	check(game.main_menu.take_debug_start().is_empty(), "a debug jump is consumed once")
	game.queue_free()
	await process_frame

func _test_debug_floor_two_starts_on_the_next_floor() -> void:
	# Arrange
	var game = await _new_game()
	var entries: Array = game.main_menu.debug_entries
	# Act
	game.main_menu._pick_debug(entries[entries.size() - 1])
	game.main_menu._choose_class("archer")
	# Assert
	check(game.floor_index == 2 and game.room == 1 and game.phase == "combat", "the floor 2 entry starts in room 1 of floor 2")
	game.queue_free()
	await process_frame

func _test_shake_option_scales_view_shake() -> void:
	# Arrange
	var game = await _new_game()
	# Act
	game._apply_menu_settings({"shake": false, "fullscreen": false})
	# Assert
	check(is_zero_approx(game.view.shake_scale), "turning shake off removes camera shake")
	# Act
	game._apply_menu_settings({"shake": true, "fullscreen": false})
	# Assert
	check(is_equal_approx(game.view.shake_scale, 1.0), "turning shake on restores camera shake")
	game.queue_free()
	await process_frame

func finish() -> void:
	print("MAIN_MENU checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if not failures.is_empty() else 0)
