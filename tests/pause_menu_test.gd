extends SceneTree
## UI/input/simulation integration against a disposable loopback host.
const Game = preload("res://src/game.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("PAUSE_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.has_method("set_pause_open"), "the game provides an Escape menu")
	if not game.has_method("set_pause_open"):
		game.queue_free()
		finish()
		return
	var port := PacketPeerUDP.new()
	port.bind(0,"127.0.0.1")
	game.port_input.text = str(port.get_local_port())
	port.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 24680
	game._begin_run()
	game._broadcast_state(true)
	game._refresh_ui()
	check(not game.pause_open and not game.pause_menu.visible and not game.lobby_ui.visible, "combat hides all permanent lobby/info panels")
	check(game.heart_hud.visible and game.heart_hud.health_only and game.heart_hud.position.x < 300 and game.heart_hud.position.y < 120, "only a compact upper-left heart HUD remains")
	check(not game.floor_map.is_visible_in_tree() and not game.party_label.is_visible_in_tree(), "map and player details are absent from the playfield")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	check(game.pause_open and game.pause_menu.visible and game.is_solo_paused(), "Escape opens the menu and pauses a solo simulation")
	check(root.gui_get_focus_owner() == game.pause_menu.resume_button, "the opened menu supports keyboard navigation immediately")
	escape.echo = true
	game._input(escape)
	check(game.pause_open, "holding Escape does not repeatedly toggle the menu")
	escape.echo = false
	game.pause_menu.select_section("map")
	check(game.pause_menu.map_view.is_visible_in_tree(), "the map has a separate menu section")
	game.pause_menu.select_section("overview")
	check(not game.pause_menu.map_view.is_visible_in_tree() and game.pause_menu.overview_label.text.to_upper().contains("BOSS"), "overview shows boss details without mixing in the map")
	game.commands[1] = {"move":Vector2.RIGHT,"aim":Vector2.RIGHT,"fire":true,"sequence":-1,"time":Time.get_ticks_msec()/1000.0}
	game._send_local_input()
	check(game.commands[1].move == Vector2.ZERO and not game.commands[1].fire, "menu input sends a neutral command instead of held movement/fire")
	var player_position: Vector2 = game.players[1].pos
	var enemy_position: Vector2 = game.enemies[0].pos
	var shot_timer: float = game.enemies[0].shot_timer
	game._physics_process(0.2)
	check(game.players[1].pos == player_position and game.enemies[0].pos == enemy_position and game.enemies[0].shot_timer == shot_timer, "solo pause freezes movement, enemies and cooldowns")
	check(not paused and game.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "pause keeps the tree and transport alive")
	game._input(escape)
	check(not game.pause_open and not game.is_solo_paused(), "Escape resumes play")
	game.enemies.clear()
	game._check_room_end()
	game._broadcast_state(true)
	game._refresh_ui()
	check(game.phase == "reward" and not game.pause_open and game.context_hint.visible, "room completion stays uncluttered and offers a reward hint")
	game._input(escape)
	check(game.reward_overlay.visible and not game.pause_menu.visible and game.reward_overlay.cards[0].is_visible_in_tree(), "Escape opens separate reward cards after a clear")
	game.action_times.clear()
	game.reward_overlay.cards[0].pressed.emit()
	game._refresh_ui()
	check(game.players[1].picked and not game.reward_overlay.ready_button.disabled, "the cards grant a normal authoritative personal perk")
	game.action_times.clear()
	game.reward_overlay.ready_button.pressed.emit()
	check(game.phase == "explore" and not game.pause_open, "ready returns to free exploration without teleporting")
	game.set_pause_open(true,"reward")
	game._refresh_ui()
	check(game.pause_open, "the reward page remains inspectable while freely exploring")
	game._add_player(200)
	game.set_pause_open(true)
	check(not game.is_solo_paused() and game.pause_menu.pause_note.text.contains("WEITER"), "a multiplayer menu clearly leaves the shared world running")
	var remote_position: Vector2 = game.players[200].pos
	game._accept_input(200,Vector2.RIGHT,Vector2.RIGHT,false,1)
	game._physics_process(0.1)
	check(game.players[200].pos != remote_position, "another participant can keep moving while the host menu is open")
	var old_room: int = game.room
	game._send_action("interact")
	check(game.room == old_room, "menu keyboard input cannot activate a doorway")
	game.phase = "dead"
	game._broadcast_state(true)
	game._refresh_ui()
	game.pause_menu.select_section("session")
	check(game.pause_menu.main_action_button.visible and not game.pause_menu.main_action_button.disabled, "the host can restart a finished run from the menu")
	game.action_times.clear()
	game.pause_menu.main_action_button.pressed.emit()
	check(game.phase == "combat" and not game.pause_open, "restart closes the menu and starts a clean run")
	game.players[1].hp = 7
	game._broadcast_state(true)
	game._refresh_ui()
	check(game.heart_hud.get_health_image().get_data() == load("res://src/health_strip.gd").make_image(7,8).get_data(), "the compact HUD receives authoritative damage as a half-heart image")
	game.set_pause_open(true)
	game._leave_session()
	check(not game.pause_open and not game.pause_menu.visible and game.lobby_ui.visible and not game.heart_hud.visible, "leaving restores the lobby and clears local pause state")
	game.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("PAUSE_MENU checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
