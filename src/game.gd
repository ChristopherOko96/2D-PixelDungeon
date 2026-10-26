extends Node2D
## A small host-authoritative development slice. No gameplay objects are accepted from peers.

const WORLD_SIZE := Vector2(896, 480)
const WORLD_OFFSET := Vector2(32, 156)
const PLAYER_COLORS := [Color("72dcc8"), Color("edb563"), Color("bc91de"), Color("ed8a91")]
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const Progression = preload("res://src/player/progression.gd")
const Account = preload("res://src/online/account.gd")
const Abilities = preload("res://src/combat/abilities.gd")
const Loadout = preload("res://src/player/loadout.gd")

var balance: Dictionary = {}
var dungeon_config: Dictionary = {}
var floor_layouts: Array[Dictionary] = []
var current_layout: Dictionary = {}
var requested_seed := -1
var last_layout_id := ""
var state: Dictionary = {}
var players: Dictionary = {}
var commands: Dictionary = {}
var enemies: Array = []
var bullets: Array = []
var perk_options: Array = []
# Host-side floor progress, keyed by room id: {"visited": bool, "cleared": bool}.
var room_states: Dictionary = {}
var reward_kind := ""
# Stable per-run enemy ids let clients match snapshots to animation state.
var next_enemy_id := 0
# EXP orbs on the floor of the current room: {id, pos, vel, value, age}.
var orbs: Array = []
var next_orb_id := 0
# Seconds the current room has been free of combat; orbs fly to players after a moment.
var calm_clock := 0.0
# Development aid: `--debug-room boss` starts a run directly in that kind of room.
var debug_room := ""
# Endless mode: after each boss a new, harder floor follows until the party falls.
var endless := false
var floor_number := 1
# Development aid: `--debug-floor 2` starts an endless run on that floor.
var debug_floor := 1
# Rooms cleared on earlier floors of this run (the current floor counts separately).
var rooms_cleared_before := 0
var peer: ENetMultiplayerPeer
var hosting := false
var active := false
var phase := "menu"
var room := 1
var run_seed := 0
var packet_sequence := 0
var received_sequence := -1
var input_sequence := 0
var input_clock := 0.0
var snapshot_clock := 0.0
var membership_dirty := false
var ui_clock := 0.0
var launched_at := 0.0
var auto_exit := 0.0
var auto_start := false
var smoke_role := ""
var status_message := "Solo starten oder Freunde über LAN / direkte IP verbinden."
var seen_snapshot := false
var last_phase := ""
var action_times: Dictionary = {}
var view: Node2D
var ui: Control
var phase_label: Label
var party_label: Label
var floor_map: Control
var status_label: Label
var session_label: Label
var address_input: LineEdit
var port_input: LineEdit
var host_button: Button
var join_button: Button
var solo_button: Button
var action_button: Button
var leave_button: Button
var perk_buttons: Array[Button] = []
var main_menu: Control
var hud: Control
# Golem moves, mob abilities and floor hazards (host side).
var abilities: RefCounted
# Chosen hero class per peer; survives the player rebuild at run start.
var player_classes: Dictionary = {}
# Weapons lying in rooms: room id -> Array of {id, weapon, pos}; `loot` is the
# current room's list.
var room_loot: Dictionary = {}
var loot: Array = []
var next_loot_id := 0
var ability_buttons: Array[Button] = []
var ability_label: Label
var class_button: Button
var account: Node
# Progress tracking for the local player: one record per finished run.
var run_recorded := true
var run_seconds := 0.0
var title_labels: Array[Label] = []
var back_button: Button
# The title screen shows until the player picks solo or multiplayer.
var menu_open := true
var solo_session := false


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	if not parsed is Dictionary:
		push_error("Missing or invalid src/data/balance.json")
		get_tree().quit(1)
		return
	balance = parsed
	var room_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	if not room_data is Dictionary or not Dungeon.validate_config(room_data).is_empty():
		push_error("Missing or invalid assets/data/dungeon_rooms.json")
		get_tree().quit(1)
		return
	dungeon_config = room_data
	Engine.physics_ticks_per_second = 60
	launched_at = Time.get_ticks_msec() / 1000.0
	# Clients only talk to the host; membership comes from authoritative snapshots.
	# Disable engine relay announcements before connecting: simultaneous disconnects
	# can otherwise send internal peer-left packets to already-closed ENet channels.
	var scene_multiplayer := multiplayer as SceneMultiplayer
	scene_multiplayer.server_relay = false
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_lost)
	abilities = Abilities.new(self)
	account = Account.new()
	add_child(account)
	view = preload("res://src/dungeon_view.gd").new()
	view.position = WORLD_OFFSET
	add_child(view)
	_build_ui()
	_read_arguments()
	_refresh_ui()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("10131b"))
	draw_line(Vector2(32, 98), Vector2(1248, 98), Color("343747"), 1)


func _read_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	var address := ""
	var should_host := false
	for i in range(args.size()):
		match args[i]:
			"--host": should_host = true
			"--auto-start": auto_start = true
			"--join":
				if i + 1 < args.size(): address = args[i + 1]
			"--port":
				if i + 1 < args.size(): port_input.text = args[i + 1]
			"--auto-exit":
				if i + 1 < args.size(): auto_exit = maxf(0.0, args[i + 1].to_float())
			"--smoke-role":
				if i + 1 < args.size(): smoke_role = args[i + 1]
			"--seed":
				if i + 1 < args.size() and args[i + 1].is_valid_int(): requested_seed = maxi(0, args[i + 1].to_int())
			"--debug-room":
				if i + 1 < args.size(): debug_room = args[i + 1]
			"--endless": endless = true
			"--class":
				if i + 1 < args.size(): player_classes[1] = args[i + 1]
			"--debug-floor":
				if i + 1 < args.size() and args[i + 1].is_valid_int(): debug_floor = maxi(1, args[i + 1].to_int())
	if should_host:
		_host_session()
	elif not address.is_empty():
		address_input.text = address
		_join_session()


func _process(delta: float) -> void:
	var elapsed := Time.get_ticks_msec() / 1000.0 - launched_at
	if auto_exit > 0.0 and elapsed >= auto_exit:
		print("AUTO_EXIT phase=%s PLAYER_COUNT=%d" % [phase, state.get("players", {}).size()])
		get_tree().quit()
		return
	if active and hosting and auto_start and phase == "lobby" and elapsed > 2.0:
		if players.size() >= 2 or elapsed > 4.0: _server_action(1, "start", 0)
	ui_clock += delta
	if ui_clock >= 0.1:
		ui_clock = 0.0
		_refresh_ui()
		if not smoke_role.is_empty() and active and not state.get("players", {}).get(multiplayer.get_unique_id(), {}).get("choices", []).is_empty():
			_send_action("ability", 0)
		if not smoke_role.is_empty() and active and phase == "reward":
			var local_player: Dictionary = state.get("players", {}).get(multiplayer.get_unique_id(), {})
			if not local_player.is_empty() and local_player.get("hp", 0) > 0:
				if not local_player.get("picked", false): _send_action("perk", 0)
				elif not local_player.get("ready", false): _send_action("ready")
	if not state.is_empty(): view.set_state(state, multiplayer.get_unique_id() if active else 0)
	var local_player: Dictionary = state.get("players", {}).get(multiplayer.get_unique_id(), {}) if active else {}
	hud.show_player(local_player if phase in ["combat", "explore", "reward", "dead", "victory"] else {})
	hud.show_floor(int(state.get("floor", 1)), bool(state.get("endless", false)))
	hud.show_boss(state.get("boss_bar", {}) if hud.showing() else {})
	_track_run(local_player, delta)


## Saves the local player's finished run to their progress (local, and online
## when signed in): once per run, when it ends in victory or a wipe.
func _track_run(local_player: Dictionary, delta: float) -> void:
	if phase in ["combat", "explore", "reward"]:
		if run_recorded:
			run_recorded = false
			run_seconds = 0.0
		run_seconds += delta
	# Test bots never write into the player's real progress.
	elif phase in ["victory", "dead"] and not run_recorded and not local_player.is_empty() and smoke_role.is_empty():
		run_recorded = true
		var won: bool = phase == "victory"
		account.record_run({"won": won, "level": int(local_player.get("level", 1)), "exp": int(local_player.get("exp_total", 0)),
			"kills": int(local_player.get("kills", 0)), "bosses": int(state.get("floor", 1)) - 1 + (1 if won else 0), "rooms": int(state.get("rooms_total", state.get("rooms_cleared", 0))),
			"floor": int(state.get("floor", 1)) if bool(state.get("endless", false)) else 0, "seconds": int(run_seconds)})


func _physics_process(delta: float) -> void:
	if not active: return
	input_clock += delta
	if phase in ["combat", "explore"] and input_clock >= 1.0 / float(balance.network.input_hz):
		input_clock = 0.0
		_send_local_input()
	if not hosting: return
	if membership_dirty:
		membership_dirty = false
		_broadcast_state(true)
	if phase == "combat":
		_simulate_players(delta)
		_simulate_enemies(delta)
		abilities.update(delta)
		_simulate_bullets(delta)
		_simulate_orbs(delta)
		_check_room_end()
	elif phase == "explore":
		_simulate_players(delta)
		_simulate_bullets(delta)
		_simulate_orbs(delta)
		_open_chests()
		_check_doors()
	elif phase in ["reward", "victory"]:
		# Orbs still on the floor after the last kill keep flying to the players.
		_simulate_orbs(delta)
	snapshot_clock += delta
	if snapshot_clock >= 1.0 / float(balance.network.snapshot_hz):
		snapshot_clock = 0.0
		_broadcast_state(false)


func _unhandled_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_1: _send_action("ability", 0)
		KEY_2: _send_action("ability", 1)
		KEY_3: _send_action("ability", 2)


func _port() -> int:
	if not port_input.text.is_valid_int(): return 0
	var value := port_input.text.to_int()
	return value if value > 1023 and value <= 65535 else 0


func _host_session() -> void:
	if active: return
	var port := _port()
	if port == 0:
		status_message = "Port muss zwischen 1024 und 65535 liegen."
		return
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_server(port, int(balance.network.max_players) - 1)
	if result != OK:
		status_message = "Host konnte Port %d nicht öffnen (Fehler %d)." % [port, result]
		return
	hosting = true
	active = true
	phase = "lobby"
	players.clear()
	commands.clear()
	action_times.clear()
	packet_sequence = 0
	received_sequence = -1
	seen_snapshot = false
	floor_layouts.clear()
	current_layout.clear()
	room_states.clear()
	last_layout_id = ""
	multiplayer.multiplayer_peer = peer
	_add_player(1)
	status_message = "Lobby offen · UDP %d · Host + bis zu %d Freunde. Der Host startet." % [port, int(balance.network.max_players) - 1]
	print("SESSION_HOSTED port=%d max_players=%d" % [port, balance.network.max_players])
	_broadcast_state(true)


func _join_session() -> void:
	if active: return
	var address := address_input.text.strip_edges()
	if address.is_empty() or _port() == 0:
		status_message = "Gültige Host-IP und Port 1024–65535 eingeben."
		return
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_client(address, _port())
	if result != OK:
		status_message = "Verbindung konnte nicht gestartet werden (Fehler %d)." % result
		return
	hosting = false
	active = true
	phase = "connecting"
	received_sequence = -1
	seen_snapshot = false
	state.clear()
	last_layout_id = ""
	multiplayer.multiplayer_peer = peer
	status_message = "Verbinde mit %s:%d …" % [address, _port()]


func _connected() -> void:
	print("CLIENT_CONNECTED peer=%d" % multiplayer.get_unique_id())
	status_message = "Verbunden. Warte auf den Start durch den Host."


func _connection_failed() -> void:
	print("CONNECTION_FAILED")
	_leave_session("Verbindung fehlgeschlagen: Host-IP, Port, Firewall und freie Lobby prüfen.")


func _server_lost() -> void:
	print("SERVER_DISCONNECTED")
	_leave_session("Die Verbindung zum Host wurde beendet. Der Lauf ist vorbei; erneut verbinden.")


func _leave_session(message: String = "Verbindung beendet.") -> void:
	active = false
	hosting = false
	if peer != null: peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	commands.clear()
	state.clear()
	enemies.clear()
	bullets.clear()
	orbs.clear()
	floor_layouts.clear()
	current_layout.clear()
	room_states.clear()
	last_layout_id = ""
	phase = "menu"
	# A solo run returns to the title screen; a multiplayer session stays in the
	# lobby controls so connection errors remain readable.
	if solo_session: menu_open = true
	solo_session = false
	endless = false
	status_message = message
	view.set_state({}, 0)
	_refresh_ui()


func _peer_connected(id: int) -> void:
	if not hosting: return
	if phase != "lobby" or players.size() >= int(balance.network.max_players):
		peer.disconnect_peer(id)
		return
	_add_player(id)
	print("PEER_JOINED peer=%d count=%d" % [id, players.size()])
	_broadcast_state(true)


func _peer_disconnected(id: int) -> void:
	if not hosting: return
	players.erase(id)
	commands.erase(id)
	action_times.erase(id)
	print("PEER_LEFT peer=%d count=%d" % [id, players.size()])
	if phase == "reward": _advance_if_ready()
	# Several peers may close in the same network poll; send after all disconnect signals.
	membership_dirty = true


func _add_player(id: int) -> void:
	var index := players.size()
	players[id] = {"pos": Vector2(150 + index * 52, 210 + (index % 2) * 50), "hp": int(balance.player.hp), "max_hp": int(balance.player.hp), "color": PLAYER_COLORS[index % PLAYER_COLORS.size()], "ready": false, "picked": false, "perks": [], "damage": float(balance.player.damage), "speed": float(balance.player.speed), "shot_interval": float(balance.player.shot_interval), "range": float(balance.bullet.lifetime), "shot_speed": float(balance.bullet.speed), "luck": 0.0, "level": 1, "exp": 0, "level_ups": 0, "pickups": 0, "kills": 0, "exp_total": 0, "shot_timer": 0.0, "invulnerable": 0.0, "aim": Vector2.RIGHT, "move": Vector2.ZERO, "knock": Vector2.ZERO, "swings": 0, "swing_angle": 0.0, "shield_timer": 0.0, "shield_breaks": 0}
	Loadout.apply_class(players[id], str(player_classes.get(id, balance.default_class)), balance)


func _send_local_input() -> void:
	var local_player: Dictionary = state.get("players", {}).get(multiplayer.get_unique_id(), {})
	if local_player.is_empty() or local_player.get("hp", 0) <= 0: return
	var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length()
	var position := Vector2(local_player.x, local_player.y)
	var mouse := get_global_mouse_position() - WORLD_OFFSET
	var aim := (mouse - position).normalized()
	var fire := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Rect2(Vector2.ZERO, WORLD_SIZE).has_point(mouse)
	if not smoke_role.is_empty() and not state.get("enemies", []).is_empty():
		var nearest := Vector2.ZERO
		var distance := INF
		for enemy in state.enemies:
			var target := Vector2(enemy.x, enemy.y)
			if position.distance_squared_to(target) < distance:
				distance = position.distance_squared_to(target)
				nearest = target
		aim = (nearest - position).normalized()
		# Ranged bots keep their distance; a sword bot has to close in.
		var reach: float = float(local_player.get("reach", 0.0))
		var far: float = reach * 0.7 if reach > 0.0 else 250.0
		var near: float = 0.0 if reach > 0.0 else 150.0
		movement = aim if distance > far * far else -aim if distance < near * near else Vector2.ZERO
		var layout: Dictionary = state.get("room_layout", {})
		if not layout.is_empty():
			# Test clients use the received geometry, just like the renderer. Their
			# inputs still pass through the same authoritative simulation as keys.
			if Dungeon.segment_blocked(position, nearest, float(balance.bullet.radius), layout):
				var path := Dungeon.find_path(position, nearest, 12.0, layout)
				movement = (path[0] - position).normalized() if not path.is_empty() else Vector2.ZERO
			elif Dungeon.segment_blocked(position, position + movement * 32.0, 12.0, layout):
				movement = Vector2.ZERO
		fire = true
	elif not smoke_role.is_empty() and phase == "explore":
		# Test clients walk to the next door on the known map: the boss once it is
		# visible, otherwise the nearest unvisited room. Input stays authoritative.
		var side := _smoke_door()
		var layout: Dictionary = state.get("room_layout", {})
		if not side.is_empty() and not layout.is_empty():
			var goal := Dungeon.door_center(side, layout)
			var path := Dungeon.find_path(position, goal, 12.0, layout)
			movement = (path[0] - position).normalized() if not path.is_empty() else (goal - position).normalized()
		fire = false
	input_sequence += 1
	if hosting: _accept_input(1, movement, aim, fire, input_sequence)
	else: _input_packet.rpc_id(1, movement, aim, fire, input_sequence)


## Smoke-test navigation: first door on the shortest known route to the boss, or
## to the nearest unvisited visible room while the boss is still unseen.
func _smoke_door() -> String:
	var rooms: Array = state.get("floor_map", [])
	var current_id := str(state.get("room_layout", {}).get("id", ""))
	var by_cell := {}
	var start := Vector2i.ZERO
	for entry in rooms:
		var cell := Vector2i(int(entry.grid_x), int(entry.grid_y))
		by_cell[cell] = entry
		if str(entry.id) == current_id: start = cell
	var first_step := {start: ""}
	var queue: Array[Vector2i] = [start]
	var fallback := ""
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		var entry: Dictionary = by_cell.get(cell, {})
		if cell != start:
			if entry.get("kind", "") == "boss": return first_step[cell]
			if fallback.is_empty() and not entry.get("visited", false): fallback = first_step[cell]
		for side in entry.get("doors", []):
			var next: Vector2i = cell + Dungeon.DIRECTION_VECTORS[Dungeon.DIRECTION_NAMES.find(side)]
			if by_cell.has(next) and not first_step.has(next):
				first_step[next] = side if cell == start else first_step[cell]
				queue.append(next)
	return fallback


@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func _input_packet(movement: Vector2, aim: Vector2, fire: bool, sequence: int) -> void:
	if hosting: _accept_input(multiplayer.get_remote_sender_id(), movement, aim, fire, sequence)


func _accept_input(id: int, movement: Vector2, aim: Vector2, fire: bool, sequence: int) -> void:
	if not players.has(id) or not phase in ["combat", "explore"] or players[id].hp <= 0: return
	if not movement.is_finite() or not aim.is_finite() or sequence < 0: return
	var now := Time.get_ticks_msec() / 1000.0
	var previous: Dictionary = commands.get(id, {})
	if sequence <= int(previous.get("sequence", -1)) or now - float(previous.get("time", -1.0)) < 0.025: return
	commands[id] = {"move": movement.limit_length(), "aim": aim.normalized() if aim.length_squared() > 0.0001 else Vector2.RIGHT, "fire": fire, "sequence": sequence, "time": now}


func _send_action(action: String, value: int = 0) -> void:
	if not active: return
	if hosting: _server_action(1, action, value)
	elif peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED: _action_packet.rpc_id(1, action, value)


@rpc("any_peer", "call_remote", "reliable", 2)
func _action_packet(action: String, value: int) -> void:
	if hosting: _server_action(multiplayer.get_remote_sender_id(), action, value)


func _server_action(id: int, action: String, value: int) -> void:
	if not players.has(id): return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(action_times.get(id, -1.0)) < 0.08: return
	action_times[id] = now
	if action == "start" and id == 1 and phase in ["lobby", "dead", "victory"]:
		_begin_run()
	elif action == "perk" and phase == "reward" and players[id].hp > 0 and not players[id].picked:
		if value < 0 or value >= perk_options.size(): return
		_grant_perk(id, perk_options[value])
	elif action == "class" and phase == "lobby":
		var order: Array = balance.class_order
		if value < 0 or value >= order.size(): return
		player_classes[id] = str(order[value])
		Loadout.apply_class(players[id], str(order[value]), balance)
	elif action == "ability" and players[id].hp > 0 and value >= 0 and value < players[id].get("choices", []).size():
		Loadout.apply_ability(players[id], str(players[id].choices[value]), balance)
		print("ABILITY_TAKEN peer=%d ability=%s" % [id, players[id].choices[value]])
		players[id].choices = []
		players[id].pending_choices = maxi(0, int(players[id].pending_choices) - 1)
		if players[id].pending_choices > 0: _offer_abilities(id)
	elif action == "ready" and phase == "reward" and players[id].hp > 0 and players[id].picked:
		players[id].ready = true
		_advance_if_ready()
	else: return
	_broadcast_state(true)


## Chests: sometimes one stands in a cleared room. Walking into it opens it
## and grants that hero a small random boost (balance.chest.boosts).
func _maybe_place_chest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chest:%d:%s" % [run_seed, current_layout.get("id", "")])
	if rng.randf() > float(balance.chest.room_chance): return
	var spot: Vector2 = Dungeon.move_actor(Dungeon.spawn_for_player(0, current_layout), Vector2(70, 0), 16.0, current_layout)
	loot.append({"id": next_loot_id, "pos": spot, "open": false})
	next_loot_id += 1


func _open_chests() -> void:
	for chest in loot:
		if chest.open: continue
		for id in players:
			var player: Dictionary = players[id]
			if player.hp > 0 and player.pos.distance_to(chest.pos) < float(balance.chest.reach) + 12.0:
				chest.open = true
				var rng := RandomNumberGenerator.new()
				rng.seed = hash("boost:%d:%d" % [run_seed, int(chest.id)])
				var boosts: Array = balance.chest.boosts
				var boost: Dictionary = boosts[rng.randi_range(0, boosts.size() - 1)]
				Loadout.apply_boost(player, boost, balance)
				player.boosts = int(player.get("boosts", 0)) + 1
				player.boost_text = str(boost.text)
				print("CHEST_OPENED peer=%d boost=%s" % [id, boost.stat])
				break


func _begin_run() -> void:
	var seed_value := requested_seed if requested_seed >= 0 else randi_range(10000, 99999)
	floor_number = debug_floor if endless else 1
	rooms_cleared_before = 0
	if not _generate_floor(seed_value): return
	peer.refuse_new_connections = true
	var ids := players.keys()
	players.clear()
	for id in ids: _add_player(id)
	commands.clear()
	orbs.clear()
	room_loot.clear()
	print("RUN_STARTED seed=%d players=%d rooms=%d" % [run_seed, players.size(), floor_layouts.size()])
	if endless: print("ENDLESS_STARTED floor=1")
	var first_room := 0
	for i in range(floor_layouts.size()):
		if not debug_room.is_empty() and str(floor_layouts[i].get("kind", "")) == debug_room: first_room = i
	_enter_room(first_room, "")


## Builds the floor for `seed_value`. Deeper endless floors get more rooms.
func _generate_floor(seed_value: int) -> bool:
	var extra: int = floori(float(floor_number - 1) * float(balance.endless.rooms_step)) if endless else 0
	var maximum: int = mini(int(balance.rooms.max_count) + extra, Dungeon.MAX_ROOMS)
	var minimum: int = mini(int(balance.rooms.min_count) + extra, maximum)
	var generated := Dungeon.generate(seed_value, Dungeon.room_count_for_seed(seed_value, minimum, maximum), dungeon_config)
	if generated.is_empty():
		status_message = "Dungeon konnte nicht erstellt werden. Raumdaten prüfen."
		return false
	run_seed = seed_value
	floor_layouts = generated
	room_states.clear()
	for layout in floor_layouts: room_states[layout.id] = {"visited": false, "cleared": false}
	last_layout_id = ""
	return true


## Endless mode: the party keeps level, stats, perks and EXP, heals a little
## (the fallen get back up) and goes down to a new, harder floor.
func _next_floor() -> void:
	rooms_cleared_before += _rooms_cleared()
	floor_number += 1
	if not _generate_floor(absi(hash("floor:%d:%d" % [run_seed, floor_number])) % 90000 + 10000): return
	for player in players.values():
		if player.hp > 0: player.hp = mini(player.max_hp, player.hp + int(balance.endless.heal_per_floor))
		else: player.hp = maxi(1, int(ceil(player.max_hp * 0.5)))
	print("FLOOR_STARTED floor=%d seed=%d rooms=%d" % [floor_number, run_seed, floor_layouts.size()])
	_enter_room(0, "")


## Endless difficulty for the current floor: enemy health, speed and the boss's
## pause between moves. Floor 1 (and every story run) is the base game.
func _floor_scaling() -> Dictionary:
	var depth: float = float(floor_number - 1) if endless else 0.0
	var config: Dictionary = balance.endless
	return {"hp": 1.0 + depth * float(config.hp_step),
		"speed": minf(1.0 + depth * float(config.speed_step), float(config.speed_max)),
		"pause": maxf(1.0 - depth * float(config.pause_step), float(config.pause_min))}


## Moves the whole party into floor room `index`. `entry_side` is the wall of the
## new room they come through ("" for the run start). Uncleared combat rooms lock
## and spawn enemies; the treasure room opens its perk choice once; revisits of
## cleared rooms are free to walk through.
func _enter_room(index: int, entry_side: String) -> void:
	if index < 0 or index >= floor_layouts.size(): return
	room = index + 1
	current_layout = floor_layouts[index]
	var status: Dictionary = room_states[current_layout.id]
	var first_visit: bool = not status.visited
	status.visited = true
	# EXP still on the old floor is not lost: it goes to the nearest living player.
	for orb in orbs:
		var collector := _nearest_living_player(orb.pos)
		if collector >= 0: _collect_orb(collector, orb)
	orbs.clear()
	calm_clock = 0.0
	abilities.clear()
	if not room_loot.has(current_layout.id): room_loot[current_layout.id] = []
	loot = room_loot[current_layout.id]
	enemies.clear()
	bullets.clear()
	commands.clear()
	var arrivals: Array[Vector2] = []
	if not entry_side.is_empty(): arrivals = Dungeon.entry_spawns(entry_side, current_layout)
	var slot := 0
	for id in players:
		var player: Dictionary = players[id]
		player.pos = arrivals[slot % arrivals.size()] if not arrivals.is_empty() else Dungeon.spawn_for_player(slot, current_layout)
		player.ready = false
		player.picked = false
		player.shot_timer = 0.0
		player.invulnerable = 1.0
		# Fallen players rejoin when the party reaches a room nobody has seen yet.
		if first_visit and player.hp <= 0: player.hp = maxi(1, int(ceil(player.max_hp * 0.5)))
		slot += 1
	var kind: String = str(current_layout.get("kind", "normal"))
	var count := 0
	if kind == "start":
		status.cleared = true
	if status.cleared:
		phase = "explore"
	elif kind == "treasure":
		_open_reward("treasure")
	else:
		phase = "combat"
		var kinds: Array[String] = [str(_floor_roster().boss)]
		if kind != "boss": kinds = _enemy_kinds_for(current_layout)
		count = kinds.size()
		var spawns: int = current_layout.get("enemy_spawns", []).size()
		var elite_rng := RandomNumberGenerator.new()
		elite_rng.seed = hash("elite:%d:%s" % [run_seed, current_layout.id])
		var elite_chance: float = minf(float(balance.depth.elite_max), float(balance.depth.elite_per_floor) * float(floor_number - 1)) if endless else 0.0
		for i in range(count):
			var spot: Vector2 = Dungeon.spawn_for_enemy(i, current_layout, entry_side)
			# More creatures than spawn points: spread the extras around them.
			if spawns > 0 and i >= spawns: spot = Dungeon.move_actor(spot, Vector2.RIGHT.rotated(float(i) * 2.3) * 34.0, 14.0, current_layout)
			var creature := _spawn_enemy(kinds[i], spot, i)
			if not creature.boss and elite_rng.randf() < elite_chance: _make_elite(creature)
	print("ROOM_STARTED room=%d kind=%s enemies=%d boss=%s" % [room, kind, count, kind == "boss"])


## Adds one enemy of `kind` at `pos`, scaled for the party size and floor.
## `index` staggers the first attacks so a room does not fire all at once.
func _spawn_enemy(kind: String, pos: Vector2, index: int) -> Dictionary:
	var definition := _definition(kind)
	var scaling := _floor_scaling()
	var hp := int(round((float(definition.hp) + maxi(0, players.size() - 1) * float(definition.hp_per_extra_player)) * float(scaling.hp)))
	var boss: bool = kind in ["boss", "golem", "molgrax", "o_warlord"]
	# Ranged enemies wait a moment before their first shot, so arrivals can react.
	var enemy := {"pos": pos, "hp": hp, "max_hp": hp, "boss": boss, "kind": kind, "extra_shots": floori(float(floor_number - 1) / 3.0) if endless else 0, "radius": float(definition.radius), "speed": float(definition.speed) * float(scaling.speed), "shot_timer": 1.0 + 0.4 * index, "nav_timer": 0.0, "nav_path": PackedVector2Array(), "knock": Vector2.ZERO, "hit_timer": 0.0, "face": -1.0, "moving": false, "id": next_enemy_id, "attack": "", "attack_time": 0.0}
	next_enemy_id += 1
	enemies.append(enemy)
	return enemy


## Elite: tougher, larger, and after each of its attacks it also bursts a ring
## of shots (its extra attack). Deeper floors also add shots to every fan.
func _make_elite(enemy: Dictionary) -> void:
	var config: Dictionary = balance.depth
	enemy.elite = true
	enemy.max_hp = int(round(float(enemy.max_hp) * float(config.elite_hp)))
	enemy.hp = enemy.max_hp
	enemy.radius = float(enemy.radius) * 1.15


## An enemy's kind; older fixtures without one are the demon boss or a chaser.
func _kind(enemy: Dictionary) -> String:
	return str(enemy.get("kind", "boss" if enemy.get("boss", false) else "chaser"))


## Stats of an enemy kind: the original three have their own sections in
## balance.json, the deeper floors' kinds live in `mobs`.
func _definition(kind: String) -> Dictionary:
	match kind:
		"boss": return balance.boss
		"golem": return balance.golem
		"molgrax": return balance.molgrax
		"o_warlord": return balance.o_warlord
		"shooter": return balance.shooter
		"chaser": return balance.enemy
	return balance.mobs.get(kind, balance.enemy)


## The current floor's boss and mob mix from balance.floors (cycling).
func _floor_roster() -> Dictionary:
	var floors: Array = balance.floors
	return floors[(floor_number - 1) % floors.size()] if endless else balance.story_floor


## Seeded encounter for a normal room: 3-5 enemies, of which up to
## `rooms.shooters_max` are ranged; the first enemy is always a melee kind.
## Which melee and ranged kinds appear depends on the floor.
func _enemy_kinds_for(layout: Dictionary) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("enemies:%d:%s" % [run_seed, layout.id])
	# Deeper endless floors: more creatures per room, more of them ranged.
	var depth: int = floor_number - 1 if endless else 0
	var extra: int = floori(float(depth) * float(balance.depth.extra_per_floor))
	var count := mini(rng.randi_range(int(balance.rooms.enemies_min) + extra, int(balance.rooms.enemies_max) + extra), int(balance.depth.max_enemies))
	var shooters := rng.randi_range(0, mini(int(balance.rooms.shooters_max) + depth / 2, count - 1))
	var roster := _floor_roster()
	var melee: Array = roster.melee
	var ranged: Array = roster.ranged
	var kinds: Array[String] = []
	for i in range(count):
		var pool: Array = ranged if i >= count - shooters else melee
		kinds.append(str(pool[rng.randi_range(0, pool.size() - 1)] if pool.size() > 1 else pool[0]))
	return kinds


func _open_reward(kind: String) -> void:
	phase = "reward"
	reward_kind = kind
	for player in players.values():
		player.picked = false
		player.ready = false
	perk_options = balance.perks.duplicate(true)
	perk_options.shuffle()
	perk_options = perk_options.slice(0, 3)


## Host: a living player standing in an open doorway takes the whole party through.
func _check_doors() -> void:
	if phase != "explore": return
	var doors: Dictionary = current_layout.get("doors", {})
	for player in players.values():
		if player.hp <= 0: continue
		for side in doors:
			if Dungeon.at_door(player.pos, side, Dungeon.DOOR_ACTOR_RADIUS, current_layout):
				var target := _room_index(str(doors[side]))
				if target < 0: return
				print("ROOM_TRAVEL from=%d to=%d side=%s" % [room, target + 1, side])
				_enter_room(target, Dungeon.OPPOSITE[side])
				_broadcast_state(true)
				return


func _room_index(id: String) -> int:
	for i in range(floor_layouts.size()):
		if str(floor_layouts[i].id) == id: return i
	return -1


func _simulate_players(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for id in players:
		var player: Dictionary = players[id]
		player.shot_timer = maxf(0.0, player.shot_timer - delta)
		player.invulnerable = maxf(0.0, player.invulnerable - delta)
		player.shield_timer = maxf(0.0, float(player.get("shield_timer", 0.0)) - delta)
		if player.hp <= 0: continue
		_apply_knockback(player, 12.0, delta)
		# Double Cast's follow-up spell flies even if the button was let go.
		if int(player.get("echoes", 0)) > 0:
			player.echo_timer = float(player.echo_timer) - delta
			if player.echo_timer <= 0.0:
				player.echoes = int(player.echoes) - 1
				player.echo_timer = float(balance.abilities.double.delay)
				_shoot(id, Vector2(player.echo_aim), true)
		var command: Dictionary = commands.get(id, {})
		if command.is_empty() or now - command.time > float(balance.network.input_timeout):
			player.move = Vector2.ZERO
			continue
		player.rooted = maxf(0.0, float(player.get("rooted", 0.0)) - delta)
		player.move = command.move if player.rooted <= 0.0 else Vector2.ZERO
		player.aim = command.aim
		player.pos = Dungeon.move_actor(player.pos, player.move * player.speed * delta, 12.0, current_layout)
		if command.fire and player.shot_timer <= 0.0:
			player.shot_timer = player.shot_interval
			if player.get("melee", false): _swing(id, command.aim)
			else: _shoot(id, command.aim)


## Fires the held projectile weapon: one shot plus one per multishot stack in a
## fan, each carrying the abilities that change shots (pierce, splash, bounce,
## homing, critical hits). Double Cast fires the whole volley again a moment
## later (see _simulate_players).
func _shoot(id: int, aim: Vector2, echo: bool = false) -> void:
	var player: Dictionary = players[id]
	var held := Loadout.weapon(player, balance)
	var count: int = 1 + Loadout.stacks(player, "multishot")
	for i in range(count):
		var direction: Vector2 = aim.rotated((float(i) - float(count - 1) * 0.5) * 0.16)
		var muzzle: Vector2 = player.pos + direction * 15.0
		if Dungeon.segment_blocked(player.pos, muzzle, float(balance.bullet.radius), current_layout): continue
		var critical: bool = randf() < 0.15 * Loadout.stacks(player, "crit")
		var shot := _add_bullet(muzzle, direction * float(player.shot_speed), id, float(player.damage) * (2.0 if critical else 1.0), float(player.range), str(held.get("projectile", "")))
		if shot.is_empty(): continue
		shot.pierce = int(held.get("pierce", 0)) + Loadout.stacks(player, "pierce")
		shot.splash = float(held.get("splash", 0.0)) + (12.0 * Loadout.stacks(player, "nova") if held.has("splash") else 0.0)
		shot.bounces = Loadout.stacks(player, "ricochet")
		shot.seek = 1.6 * Loadout.stacks(player, "seeker")
		shot.critical = critical
	# Counters, not flags: a client that misses a snapshot still sees the change.
	player.shots = int(player.get("shots", 0)) + 1
	if not echo and Loadout.stacks(player, "double") > 0:
		player.echoes = Loadout.stacks(player, "double")
		player.echo_timer = float(balance.abilities.double.delay)
		player.echo_aim = aim


## A melee swing: every enemy in the arc in front (all around with Whirl) is
## hit at once. Abilities add a travelling blade wave or parry enemy shots.
func _swing(id: int, aim: Vector2) -> void:
	var player: Dictionary = players[id]
	var whirl: bool = Loadout.stacks(player, "whirl") > 0
	var arc: float = TAU if whirl else float(player.arc)
	var reach: float = float(player.reach)
	player.swings = int(player.get("swings", 0)) + 1
	player.swing_angle = aim.angle()
	player.swing_arc = arc
	for enemy in enemies:
		if enemy.hp <= 0 or enemy.get("airborne", false): continue
		var offset: Vector2 = enemy.pos - player.pos
		if offset.length() > reach + float(enemy.radius): continue
		if not whirl and absf(aim.angle_to(offset)) > arc * 0.5: continue
		var critical: bool = randf() < 0.15 * Loadout.stacks(player, "crit")
		_hit_enemy(enemy, float(player.damage) * (2.0 if critical else 1.0), offset.normalized() if offset.length() > 0.1 else aim, id)
	if Loadout.stacks(player, "parry") > 0:
		for i in range(bullets.size() - 1, -1, -1):
			var offset: Vector2 = bullets[i].pos - player.pos
			if bullets[i].owner == 0 and offset.length() < reach + 8.0 and (whirl or absf(aim.angle_to(offset)) < arc * 0.5):
				bullets.remove_at(i)
	for wave in range(Loadout.stacks(player, "wave")):
		var direction: Vector2 = aim.rotated((float(wave) - float(Loadout.stacks(player, "wave") - 1) * 0.5) * 0.3)
		var shot := _add_bullet(player.pos + direction * 20.0, direction * 420.0, id, float(player.damage) * 0.6, 0.55, "wave")
		if not shot.is_empty(): shot.pierce = 99


## `kind` only changes how clients draw it ("slash", "rock", "bolt", "bone",
## "arrow", "magic", ...). Returns the bullet, or {} when the cap is reached.
func _add_bullet(position: Vector2, velocity: Vector2, owner: int, damage: float, life: float = -1.0, kind: String = "") -> Dictionary:
	if bullets.size() >= int(balance.bullet.max_count): return {}
	if life <= 0.0: life = float(balance.bullet.lifetime) if owner != 0 else 5.0
	var bullet := {"pos": position, "velocity": velocity, "owner": owner, "damage": damage, "life": life, "kind": kind}
	bullets.append(bullet)
	return bullet


## Moves an actor along its knockback velocity (wall-safe) and lets it fade out.
func _apply_knockback(actor: Dictionary, radius: float, delta: float) -> void:
	var knock: Vector2 = actor.get("knock", Vector2.ZERO)
	if knock == Vector2.ZERO: return
	actor.pos = Dungeon.move_actor(actor.pos, knock * delta, radius, current_layout)
	actor.knock = knock.move_toward(Vector2.ZERO, float(balance.knockback.decay) * delta)


func _simulate_enemies(delta: float) -> void:
	for enemy in enemies:
		enemy.hit_timer = maxf(0.0, float(enemy.get("hit_timer", 0.0)) - delta)
		_apply_knockback(enemy, enemy.radius, delta)
		if enemy.hp <= 0:
			# Dying: the death animation plays out, but the enemy no longer acts.
			enemy.dying = float(enemy.get("dying", 0.0)) - delta
			enemy.moving = false
			continue
		var target := -1
		var distance := INF
		for id in players:
			if players[id].hp <= 0: continue
			var candidate: float = enemy.pos.distance_squared_to(players[id].pos)
			if candidate < distance:
				distance = candidate
				target = id
		if target < 0: continue
		enemy.nav_timer = float(enemy.get("nav_timer", 0.0)) - delta
		if enemy.nav_timer <= 0.0:
			enemy.nav_path = Dungeon.find_path(enemy.pos, players[target].pos, enemy.radius, current_layout)
			enemy.nav_timer = 0.3
		var path: PackedVector2Array = enemy.get("nav_path", PackedVector2Array())
		while not path.is_empty() and enemy.pos.distance_to(path[0]) < 4.0:
			path.remove_at(0)
		enemy.nav_path = path
		var direction: Vector2 = (path[0] - enemy.pos).normalized() if not path.is_empty() else Vector2.ZERO
		var target_pos: Vector2 = players[target].pos
		var in_sight: bool = not Dungeon.segment_blocked(enemy.pos, target_pos, float(balance.bullet.radius), current_layout)
		var definition := _definition(str(enemy.get("kind", "chaser")))
		if definition.has("keep_min") and in_sight:
			# Ranged kinds hold a firing range: back off when crowded, close in when far.
			var gap: float = enemy.pos.distance_to(target_pos)
			var away: Vector2 = (enemy.pos - target_pos).normalized()
			direction = away if gap < float(definition.keep_min) else -away if gap > float(definition.keep_max) else Vector2.ZERO
		# Attackers plant their feet while winding up and firing (readable anticipation);
		# the boss also holds still while recovering, which is the player's opening.
		if enemy.get("attack", "") in ["windup", "active"] or (enemy.boss and enemy.get("attack", "") != ""): direction = Vector2.ZERO
		enemy.haste = maxf(0.0, float(enemy.get("haste", 0.0)) - delta)
		# Berserkers rage below half health; a war cry hurries everyone around.
		if definition.get("rage", false) and enemy.hp * 2 < enemy.max_hp: enemy.raging = true
		var pace: float = (1.4 if enemy.haste > 0.0 else 1.0) * (1.5 if enemy.get("raging", false) else 1.0)
		enemy.pos = Dungeon.move_actor(enemy.pos, direction * enemy.speed * pace * delta, enemy.radius, current_layout)
		enemy.moving = direction != Vector2.ZERO
		var charging: bool = _kind(enemy) == "boss" and enemy.get("move", "") == "charge" and enemy.get("attack", "") == "active"
		_turn_toward(enemy, target_pos, delta)
		# Contact damage; a boss in the air touches nobody, a charging boss or a
		# dashing imp hits hard.
		var contact_damage: int = int(balance.boss_moves.charge.damage) if charging else int(enemy.get("dash_damage", 1)) if enemy.get("dashing", false) else int(balance.enemy.damage)
		if not enemy.get("airborne", false) and enemy.pos.distance_to(target_pos) < enemy.radius + 12.0 and not Dungeon.segment_blocked(enemy.pos, target_pos, 0.0, current_layout):
			_damage_player(target, contact_damage, enemy.pos)
		if enemy.boss or balance.attacks.has(enemy.get("kind", "chaser")):
			_update_attack(enemy, delta, target, in_sight)


## Facing: flips toward the target, but not while an attack is aimed (the
## swing or charge keeps its direction), and bosses turn with some weight: only
## when the target is clearly on the other side, at most every 0.4 s.
func _turn_toward(enemy: Dictionary, target_pos: Vector2, delta: float) -> void:
	enemy.turn_cooldown = maxf(0.0, float(enemy.get("turn_cooldown", 0.0)) - delta)
	var attack: String = str(enemy.get("attack", ""))
	var free_aim: bool = str(enemy.get("move", "")) in ["beam", "channel", "thorns", "rings"]
	if attack == "active" and not free_aim: return
	if attack == "windup" and not free_aim and not enemy.boss: return
	if enemy.get("dashing", false): return
	var dx: float = target_pos.x - enemy.pos.x
	var threshold: float = 24.0 if enemy.boss else 2.0
	if absf(dx) > threshold and signf(dx) != float(enemy.get("face", -1.0)) and enemy.turn_cooldown <= 0.0:
		enemy.face = signf(dx)
		enemy.turn_cooldown = 0.4 if enemy.boss else 0.12


## The attack an enemy is using right now: the boss's current move from
## balance.boss_moves, otherwise its kind's single attack from balance.attacks.
func _attack_for(enemy: Dictionary) -> Dictionary:
	if enemy.get("kind", "") == "golem": return balance.golem_moves.get(str(enemy.get("move", "cleave")), {})
	if enemy.get("kind", "") == "molgrax": return balance.molgrax_moves.get(str(enemy.get("move", "swipe")), {})
	if enemy.get("kind", "") == "o_warlord": return balance.warlord_moves.get(str(enemy.get("move", "cleave")), {})
	if enemy.get("boss", false): return balance.boss_moves.get(str(enemy.get("move", "volley")), {})
	return balance.attacks.get(str(enemy.get("kind", "")), {})


## Attack phases shared by every ranged enemy and every boss move: idle (cooldown)
## → windup (anticipation; the boss aims and telegraphs) → active (projectiles
## spawn on its first frame; charge, jump and beam act during it) → recovery
## (the opening) → idle. Clients animate from `move`, `attack` and `attack_time`.
func _update_attack(enemy: Dictionary, delta: float, target: int, in_sight: bool) -> void:
	var target_pos: Vector2 = players[target].pos
	var boss: bool = enemy.boss
	# The demon's moves live here; the golem and the mobs use the abilities module.
	var demon: bool = _kind(enemy) == "boss"
	enemy.attack_time = float(enemy.get("attack_time", 0.0)) - delta
	match str(enemy.get("attack", "")):
		"":
			enemy.shot_timer -= delta * ((1.5 if float(enemy.get("haste", 0.0)) > 0.0 else 1.0) * (1.6 if enemy.get("raging", false) else 1.0) * (1.25 if enemy.get("elite", false) else 1.0))
			var range_ok: bool = not _attack_for(enemy).has("range") or enemy.pos.distance_to(target_pos) <= float(_attack_for(enemy).range)
			if enemy.shot_timer <= 0.0 and (in_sight or boss) and range_ok and not enemy.get("axe_out", false):
				if boss: enemy.move = _next_boss_move(enemy)
				enemy.attack = "windup"
				enemy.attack_time = float(_attack_for(enemy).windup)
				if demon: _boss_begin(enemy, target_pos)
				else: abilities.begin(enemy, _attack_for(enemy), target_pos)
		"windup":
			var attack := _attack_for(enemy)
			if demon: _boss_windup(enemy, attack, target_pos, delta)
			else: abilities.windup(enemy, attack, target_pos, delta)
			if enemy.attack_time <= 0.0:
				_fire_pattern(enemy, attack, target)
				enemy.attack = "active"
				enemy.attack_time = float(attack.active)
		"active":
			var attack := _attack_for(enemy)
			if demon: _boss_active(enemy, attack, target_pos, delta)
			else: abilities.active(enemy, attack, target, delta)
			if enemy.attack_time <= 0.0:
				if demon: _boss_finish(enemy, attack, target)
				else: abilities.finish(enemy, attack, target)
				if enemy.get("elite", false):
					enemy.attacks = int(enemy.get("attacks", 0)) + 1
					_fire_ring(enemy, int(balance.depth.elite_ring), float(balance.depth.elite_ring_speed), 1.0, randf() * TAU)
				enemy.attack = "recovery"
				enemy.attack_time = float(attack.recovery)
		"recovery":
			if enemy.attack_time <= 0.0:
				enemy.attack = ""
				var attack := _attack_for(enemy)
				enemy.shot_timer = (float(attack.interval) if attack.has("interval") else float(_definition(_kind(enemy)).move_pause)) * float(_floor_scaling().pause)


## Picks the boss's next move: the authored sequence, interrupted by the beam
## ultimate once the boss is below `ultimate.hp_ratio` health, and again every
## `ultimate.every` moves after that.
func _next_boss_move(enemy: Dictionary) -> String:
	var config := _definition(_kind(enemy))
	var ultimate: Dictionary = config.ultimate
	var since := int(enemy.get("since_ultimate", 0))
	if float(enemy.hp) <= float(enemy.max_hp) * float(ultimate.hp_ratio) and (not enemy.get("ultimate_used", false) or since >= int(ultimate.every)):
		enemy.ultimate_used = true
		enemy.since_ultimate = 0
		return str(ultimate.move)
	enemy.since_ultimate = since + 1
	var sequence: Array = config.sequence
	var index := int(enemy.get("move_index", 0))
	enemy.move_index = index + 1
	return str(sequence[index % sequence.size()])


## Windup start: lock in the first aim so the telegraph has a direction at once.
func _boss_begin(enemy: Dictionary, target_pos: Vector2) -> void:
	var toward: Vector2 = target_pos - enemy.pos
	enemy.aim_dir = toward.normalized() if toward.length_squared() > 1.0 else Vector2(enemy.get("face", -1.0), 0.0)
	enemy.slam_target = target_pos
	enemy.beam_angle = enemy.aim_dir.angle()
	enemy.beam_end = _beam_end(enemy, enemy.beam_angle)


## Windup: charge, jump and beam keep tracking the target until `lock` seconds
## before they fire, so the final telegraph is honest and can be dodged.
func _boss_windup(enemy: Dictionary, attack: Dictionary, target_pos: Vector2, delta: float) -> void:
	var tracking: bool = enemy.attack_time > float(attack.get("lock", 0.0))
	match str(enemy.move):
		"charge":
			if tracking and enemy.pos.distance_squared_to(target_pos) > 1.0: enemy.aim_dir = (target_pos - enemy.pos).normalized()
		"slam":
			if tracking: enemy.slam_target = target_pos
		"beam":
			if tracking: enemy.beam_angle = rotate_toward(float(enemy.beam_angle), (target_pos - enemy.pos).angle(), float(attack.aim_rate) * delta)
			enemy.beam_end = _beam_end(enemy, enemy.beam_angle)


func _boss_active(enemy: Dictionary, attack: Dictionary, target_pos: Vector2, delta: float) -> void:
	match str(enemy.move):
		"charge":
			var before: Vector2 = enemy.pos
			var step: Vector2 = enemy.aim_dir * float(attack.speed) * delta
			enemy.pos = Dungeon.move_actor(enemy.pos, step, enemy.radius, current_layout)
			enemy.moving = true
			enemy.face = signf(enemy.aim_dir.x) if absf(enemy.aim_dir.x) > 0.05 else enemy.face
			# Ran into a wall or cover: crash, throw debris and stop early.
			if enemy.pos.distance_to(before) < step.length() * 0.5:
				_boss_impact(enemy, attack, false)
				enemy.attack_time = 0.0
		"slam":
			var progress: float = clampf(1.0 - enemy.attack_time / maxf(float(attack.active), 0.001), 0.0, 1.0)
			var goal: Vector2 = Vector2(enemy.slam_from).lerp(enemy.slam_target, smoothstep(0.0, 1.0, progress))
			enemy.pos = Dungeon.move_actor(enemy.pos, goal - enemy.pos, enemy.radius, current_layout)
			enemy.air = sin(PI * progress)
		"beam":
			# Fair to dodge: the beam first holds the telegraphed line, then turns at
			# most `dodge_ratio` of the angular speed a running player has at their
			# distance. Running sideways always outpaces it, near the boss or far away.
			var elapsed: float = float(attack.active) - enemy.attack_time
			if elapsed > float(attack.hold):
				var distance: float = maxf(enemy.pos.distance_to(target_pos), 1.0)
				var rate: float = minf(float(attack.turn_rate), float(attack.dodge_ratio) * float(balance.player.speed) / distance)
				var wanted: float = rotate_toward(float(enemy.beam_angle), (target_pos - enemy.pos).angle(), rate * delta)
				# It never sweeps more than `max_sweep` from where it fired, so a
				# player pressed against a wall far away is still out of reach.
				var swept: float = clampf(angle_difference(float(enemy.beam_fired), wanted), -float(attack.max_sweep), float(attack.max_sweep))
				enemy.beam_angle = float(enemy.beam_fired) + swept
			enemy.beam_end = _beam_end(enemy, enemy.beam_angle)
			var origin := _beam_origin(enemy, enemy.beam_angle)
			for id in players:
				# One hit per player per beam: it punishes standing in it, not grazing it twice.
				if players[id].hp <= 0 or enemy.beam_hits.has(id): continue
				var closest := Geometry2D.get_closest_point_to_segment(players[id].pos, origin, enemy.beam_end)
				if closest.distance_to(players[id].pos) < float(attack.width) * 0.5 + 12.0 and players[id].invulnerable <= 0.0:
					_damage_player(id, int(attack.damage), closest)
					enemy.beam_hits[id] = true


## End of the active phase: the second volley, the landing, or the beam fading.
func _boss_finish(enemy: Dictionary, attack: Dictionary, target: int) -> void:
	match str(enemy.move):
		"volley":
			# The second fan fills the gaps of the first, aimed at the new lead point.
			_fire_fan(enemy, attack, target, true)
		"rings":
			# A faster ring, offset by half a step, overtakes the slow one: the gaps
			# close behind the player instead of staying open.
			_fire_ring(enemy, int(attack.count), float(attack.second_speed), float(attack.damage), PI / float(attack.count))
		"slam":
			enemy.airborne = false
			enemy.air = 0.0
			_boss_impact(enemy, attack, true)


## A landing or a wall crash: a counted impact for the client's shockwave, area
## damage for a landing, and a debris ring of projectiles.
func _boss_impact(enemy: Dictionary, attack: Dictionary, landing: bool) -> void:
	enemy.impacts = int(enemy.get("impacts", 0)) + 1
	if landing:
		for id in players:
			if players[id].hp > 0 and players[id].pos.distance_to(enemy.pos) < float(attack.radius) + 12.0:
				_damage_player(id, int(attack.damage), enemy.pos)
	_fire_ring(enemy, int(attack.count), float(attack.bullet_speed), 1.0, randf() * TAU)


func _fire_pattern(enemy: Dictionary, attack: Dictionary, target: int) -> void:
	var speed := float(attack.get("bullet_speed", 0.0))
	match str(attack.pattern):
		"aimed":
			var aim_at: Vector2 = (_lead_point(enemy.pos, target, speed, float(attack.get("lead", 0.0))) - enemy.pos).normalized()
			_add_bullet(enemy.pos + aim_at * (enemy.radius + 4.0), aim_at * speed, 0, float(attack.damage), -1.0, str(attack.get("projectile", "")))
		"fan":
			_fire_fan(enemy, attack, target, false)
		"ring":
			# Each volley turns a little, so the gaps move between attacks.
			enemy.volley = int(enemy.get("volley", 0)) + 1
			_fire_ring(enemy, int(attack.count), speed, float(attack.damage), enemy.volley * 0.35)
		"slam":
			enemy.airborne = true
			enemy.slam_from = enemy.pos
		"beam":
			enemy.beam_hits = {}
			enemy.beam_fired = float(enemy.beam_angle)
		"charge":
			pass
		_:
			abilities.fire(enemy, attack, target)
	enemy.attacks = int(enemy.get("attacks", 0)) + 1


## Where a target will be when a projectile of `speed` reaches it, scaled by
## `lead` (0 = aim at the player, 1 = full prediction). Strafing in a straight
## line no longer dodges; changing direction does.
func _lead_point(origin: Vector2, target: int, speed: float, lead: float) -> Vector2:
	var player: Dictionary = players[target]
	if lead <= 0.0 or speed <= 0.0: return player.pos
	var velocity: Vector2 = Vector2(player.get("move", Vector2.ZERO)) * float(player.speed)
	return player.pos + velocity * (origin.distance_to(player.pos) / speed) * lead


## A spread of `count` shots around the lead point; `between` shoots the
## `count - 1` shots that sit in the gaps of a normal fan.
func _fire_fan(enemy: Dictionary, attack: Dictionary, target: int, between: bool) -> void:
	var speed := float(attack.bullet_speed)
	var base: float = (_lead_point(enemy.pos, target, speed, float(attack.lead)) - enemy.pos).angle()
	var count := int(attack.count) + int(enemy.get("extra_shots", 0))
	var spread := float(attack.spread) * (1.0 + 0.15 * int(enemy.get("extra_shots", 0)))
	var shots := count - 1 if between else count
	for i in range(shots):
		var angle: float = base - spread * 0.5 + spread * (float(i) + (0.5 if between else 0.0)) / float(maxi(count - 1, 1))
		var aim := Vector2.RIGHT.rotated(angle)
		_add_bullet(enemy.pos + aim * enemy.radius, aim * speed * (1.12 if between else 1.0), 0, float(attack.damage), -1.0, str(attack.get("projectile", "")))


func _fire_ring(enemy: Dictionary, count: int, speed: float, damage: float, offset: float) -> void:
	for i in range(count):
		var aim := Vector2.RIGHT.rotated(TAU * i / count + offset)
		_add_bullet(enemy.pos + aim * enemy.radius, aim * speed, 0, damage)


## The beam leaves the boss's mouth, not its feet.
func _beam_origin(enemy: Dictionary, angle: float) -> Vector2:
	return Vector2(enemy.pos) + Vector2(0, -22) + Vector2.RIGHT.rotated(angle) * 18.0


## Where the beam stops: the first wall or piece of cover along its line, so
## standing behind cover is a real way to survive it.
func _beam_end(enemy: Dictionary, angle: float) -> Vector2:
	var origin := _beam_origin(enemy, angle)
	var direction := Vector2.RIGHT.rotated(angle)
	if Dungeon.segment_blocked(origin, origin, 0.0, current_layout): return origin
	var reach := 0.0
	while reach < 1100.0 and not Dungeon.segment_blocked(origin + direction * reach, origin + direction * (reach + 12.0), 0.0, current_layout):
		reach += 12.0
	return origin + direction * reach


func _simulate_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		var previous: Vector2 = bullet.pos
		if float(bullet.get("homing", 0.0)) > 0.0 and bullet.owner == 0:
			var hunted := _nearest_living_player(bullet.pos)
			if hunted >= 0:
				var speed: float = Vector2(bullet.velocity).length()
				var angle: float = rotate_toward(Vector2(bullet.velocity).angle(), (players[hunted].pos - bullet.pos).angle(), float(bullet.homing) * delta)
				bullet.velocity = Vector2.RIGHT.rotated(angle) * speed
		if float(bullet.get("seek", 0.0)) > 0.0 and bullet.owner != 0:
			var prey := _nearest_enemy(bullet.pos, 260.0)
			if not prey.is_empty():
				var turned: float = rotate_toward(Vector2(bullet.velocity).angle(), (prey.pos - bullet.pos).angle(), float(bullet.seek) * delta)
				bullet.velocity = Vector2.RIGHT.rotated(turned) * Vector2(bullet.velocity).length()
		bullet.pos += bullet.velocity * delta
		bullet.life -= delta
		var blocked: bool = Dungeon.segment_blocked(previous, bullet.pos, float(balance.bullet.radius), current_layout)
		if blocked and int(bullet.get("bounces", 0)) > 0:
			# Ricochet: flip the axis that hit the wall and keep flying.
			bullet.bounces = int(bullet.bounces) - 1
			var step: Vector2 = Vector2(bullet.velocity) * delta
			if Dungeon.segment_blocked(previous, previous + Vector2(step.x, 0), float(balance.bullet.radius), current_layout): bullet.velocity.x = -bullet.velocity.x
			else: bullet.velocity.y = -bullet.velocity.y
			bullet.pos = previous
			blocked = false
		var removed: bool = bullet.life <= 0.0 or blocked
		if not removed and bullet.owner == 0:
			for id in players:
				if players[id].hp > 0 and bullet.pos.distance_to(players[id].pos) < 12.0 + float(balance.bullet.radius):
					_damage_player(id, int(bullet.damage), bullet.pos - bullet.velocity)
					removed = true
					break
		elif not removed:
			for enemy in enemies:
				# A jumping boss is out of reach: shots pass under it.
				if enemy.hp > 0 and not enemy.get("airborne", false) and bullet.pos.distance_to(enemy.pos) < enemy.radius + float(balance.bullet.radius):
					if bullet.has("hit_ids") and bullet.hit_ids.has(enemy.id): continue
					# A raised shield stops shots from the front (a sword still gets through).
					if _definition(_kind(enemy)).get("shield", false) and Vector2(bullet.velocity).normalized().dot(Vector2(float(enemy.get("face", -1.0)), 0.0)) < -0.3:
						enemy.blocks = int(enemy.get("blocks", 0)) + 1
						removed = true
						break
					_hit_enemy(enemy, bullet.damage, bullet.velocity.normalized(), int(bullet.owner))
					if int(bullet.get("pierce", 0)) > 0:
						bullet.pierce = int(bullet.pierce) - 1
						if not bullet.has("hit_ids"): bullet.hit_ids = {}
						bullet.hit_ids[enemy.id] = true
					else:
						removed = true
					break
		if removed and float(bullet.get("splash", 0.0)) > 0.0: _splash(bullet)
		if removed: bullets.remove_at(i)
	# Dead enemies stay until their death animation has run (see _simulate_enemies).
	enemies = enemies.filter(func(enemy): return enemy.hp > 0 or float(enemy.get("dying", 0.0)) > 0.0)


## A magic shot bursts where it ends: half damage to enemies around it.
func _splash(bullet: Dictionary) -> void:
	for enemy in enemies:
		if enemy.hp > 0 and not enemy.get("airborne", false) and bullet.pos.distance_to(enemy.pos) < float(bullet.splash) + enemy.radius:
			_hit_enemy(enemy, float(bullet.damage) * 0.5, (enemy.pos - bullet.pos).normalized(), int(bullet.owner))
	abilities.effect("arcane" if str(bullet.get("kind", "")) != "firemagic" else "fire_burst", bullet.pos, float(bullet.splash))


func _nearest_enemy(point: Vector2, limit: float) -> Dictionary:
	var best: Dictionary = {}
	var distance := limit * limit
	for enemy in enemies:
		if enemy.hp <= 0: continue
		var candidate: float = point.distance_squared_to(enemy.pos)
		if candidate < distance:
			distance = candidate
			best = enemy
	return best


## Applies a landed hit: damage, knockback along the shot, hit flash, and on the
## killing blow the dying state (no more attacks, contact damage or hits).
func _hit_enemy(enemy: Dictionary, damage: float, direction: Vector2, killer: int = 0) -> void:
	enemy.hp -= damage
	var strength: float = float(balance.knockback.boss if enemy.boss else balance.knockback.enemy)
	enemy.hit_timer = float(balance.knockback.flash)
	enemy.hits = int(enemy.get("hits", 0)) + 1
	enemy.hit_dir = direction
	if enemy.hp <= 0:
		enemy.hp = 0
		enemy.attack = ""
		enemy.airborne = false
		enemy.air = 0.0
		enemy.dying = float(balance.death.boss_duration if enemy.boss else balance.death.duration)
		strength = float(balance.death.boss_kick if enemy.boss else balance.death.kick)
		# Hits only land on living enemies, so this runs once per death.
		_drop_exp(enemy)
		var definition := _definition(_kind(enemy))
		if definition.has("death_burst"): abilities.death_burst(enemy, definition.death_burst)
		# Bloodlust: a kill can heal the swordsman.
		if players.has(killer) and players[killer].hp > 0 and randf() < 0.15 * Loadout.stacks(players[killer], "bloodlust"):
			players[killer].hp = mini(players[killer].max_hp, players[killer].hp + 1)
		if players.has(killer): players[killer].kills = int(players[killer].get("kills", 0)) + 1
	enemy.knock = direction * strength


## Drops the kill's EXP as orbs that pop out of the body. The amount comes from
## balance.exp[kind]; luck (the party's best) can add a seeded bonus.
func _drop_exp(enemy: Dictionary) -> void:
	if enemy.get("dropped", false): return
	enemy.dropped = true
	var config: Dictionary = balance.exp
	var value := int(config.get(str(enemy.get("kind", "")), config.default))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("exp:%d:%d" % [run_seed, int(enemy.get("id", -1))])
	var luck := 0.0
	for player in players.values(): luck = maxf(luck, float(player.get("luck", 0.0)))
	if rng.randf() < luck * float(config.luck_bonus): value += ceili(value * 0.5)
	for orb_value in Progression.split_exp(value, int(config.max_orbs)):
		var orb := {"id": next_orb_id, "pos": Vector2(enemy.pos), "vel": Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(90.0, 230.0), "value": orb_value, "age": 0.0}
		next_orb_id += 1
		if orbs.size() >= int(config.orb_cap):
			# Too many on the floor: credit it straight away instead of dropping it.
			var collector := _nearest_living_player(orb.pos)
			if collector >= 0: _collect_orb(collector, orb)
		else:
			orbs.append(orb)


## Orbs pop out, settle, then fly to the nearest living player once they are
## within the magnet radius (or anywhere, shortly after the room is calm) and
## are collected on contact.
func _simulate_orbs(delta: float) -> void:
	var config: Dictionary = balance.exp
	calm_clock = 0.0 if phase == "combat" else calm_clock + delta
	var vacuum: bool = calm_clock >= float(config.vacuum_after)
	for i in range(orbs.size() - 1, -1, -1):
		var orb: Dictionary = orbs[i]
		orb.age += delta
		var target := _nearest_living_player(orb.pos)
		var pulled: bool = target >= 0 and orb.age >= float(config.settle) and (vacuum or orb.pos.distance_to(players[target].pos) < float(config.magnet_radius))
		if pulled:
			var toward: Vector2 = (players[target].pos - orb.pos).normalized()
			orb.vel = Vector2(orb.vel).move_toward(toward * float(config.max_speed), float(config.magnet_accel) * delta)
			orb.pos += orb.vel * delta
		else:
			orb.vel = Vector2(orb.vel) * maxf(0.0, 1.0 - 6.0 * delta)
			orb.pos = Dungeon.move_actor(orb.pos, orb.vel * delta, 4.0, current_layout)
		if target >= 0 and orb.age >= float(config.settle) * 0.5 and orb.pos.distance_to(players[target].pos) < float(config.collect_radius) + 12.0:
			_collect_orb(target, orb)
			orbs.remove_at(i)


func _nearest_living_player(point: Vector2) -> int:
	var best := -1
	var distance := INF
	for id in players:
		if players[id].hp <= 0: continue
		var candidate: float = point.distance_squared_to(players[id].pos)
		if candidate < distance:
			distance = candidate
			best = id
	return best


## Credits an orb's EXP at once and applies every level-up it causes.
func _collect_orb(id: int, orb: Dictionary) -> void:
	var player: Dictionary = players[id]
	player.pickups = int(player.get("pickups", 0)) + 1
	player.exp_total = int(player.get("exp_total", 0)) + int(orb.value)
	var gained := Progression.add_exp(player, int(orb.value), balance.leveling)
	for level in range(gained): _on_level_up(id)


## Per-level reward. Today a small heal; later upgrade choices hook in here.
func _on_level_up(id: int) -> void:
	var player: Dictionary = players[id]
	player.level_ups = int(player.get("level_ups", 0)) + 1
	if player.hp > 0: player.hp = mini(player.max_hp, player.hp + int(balance.leveling.heal))
	player.pending_choices = int(player.get("pending_choices", 0)) + 1
	if player.get("choices", []).is_empty(): _offer_abilities(id)
	print("LEVEL_UP peer=%d level=%d" % [id, player.level])


## Three class abilities to choose from; nothing when the class pool is used up.
func _offer_abilities(id: int) -> void:
	var player: Dictionary = players[id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("abilities:%d:%d:%d" % [run_seed, id, int(player.get("level_ups", 0))])
	player.choices = Loadout.offer(player, balance, rng)
	if player.choices.is_empty(): player.pending_choices = 0


## Hurts a player unless invulnerable. A finite `source` pushes them away from it.
func _damage_player(id: int, damage: int, source: Vector2 = Vector2.INF) -> void:
	if players[id].invulnerable > 0.0 or players[id].hp <= 0 or damage <= 0: return
	# Arcane shield: swallows one hit, then recharges.
	if Loadout.stacks(players[id], "shield") > 0 and float(players[id].get("shield_timer", 0.0)) <= 0.0:
		players[id].shield_timer = float(balance.abilities.shield.recharge)
		players[id].shield_breaks = int(players[id].get("shield_breaks", 0)) + 1
		players[id].invulnerable = 0.5
		return
	players[id].hp = maxi(0, players[id].hp - damage)
	players[id].invulnerable = float(balance.player.invulnerability)
	players[id].hurts = int(players[id].get("hurts", 0)) + 1
	if source.is_finite() and source != players[id].pos:
		players[id].knock = (players[id].pos - source).normalized() * float(balance.knockback.player)


func _check_room_end() -> void:
	var living := 0
	for player in players.values():
		if player.hp > 0: living += 1
	if living == 0:
		phase = "dead"
		bullets.clear()
		abilities.clear()
		# The simulation stops here; end every attack so no beam or jump hangs in the picture.
		for enemy in enemies:
			enemy.attack = ""
			enemy.airborne = false
			enemy.air = 0.0
		print("TEAM_WIPE room=%d" % room)
		_broadcast_state(true)
	elif enemies.is_empty():
		bullets.clear()
		abilities.clear()
		room_states[current_layout.id].cleared = true
		if current_layout.get("kind", "") == "boss": _open_reward("boss")
		else:
			phase = "explore"
			_maybe_place_chest()
		print("ROOM_CLEARED room=%d phase=%s" % [room, phase])
		_broadcast_state(true)


func _grant_perk(id: int, perk: Dictionary) -> void:
	var player: Dictionary = players[id]
	match perk.stat:
		"damage": player.mods.damage_bonus = float(player.mods.damage_bonus) + float(perk.amount)
		"speed": player.speed += perk.amount
		"max_hp":
			player.max_hp += int(perk.amount)
			player.hp = mini(player.max_hp, player.hp + int(perk.amount))
		"shot_interval": player.mods.rate_mult = float(player.mods.rate_mult) * float(perk.amount)
		"heal": player.hp = mini(player.max_hp, player.hp + int(perk.amount))
		"range": player.mods.range_mult = float(player.mods.range_mult) * float(perk.amount)
		"shot_speed": player.mods.speed_mult = float(player.mods.speed_mult) * float(perk.amount)
		"luck": player.luck += float(perk.amount)
	Loadout.equip(player, balance)
	player.picked = true
	player.perks.append(perk.id)
	print("PERK_SELECTED peer=%d room=%d perk=%s" % [id, room, perk.id])


func _advance_if_ready() -> void:
	var living := 0
	for player in players.values():
		if player.hp <= 0: continue
		living += 1
		if not player.picked or not player.ready: return
	if living > 0:
		if reward_kind == "boss" and endless:
			_next_floor()
		elif reward_kind == "boss":
			phase = "victory"
			print("RUN_COMPLETED players=%d rooms_cleared=%d" % [players.size(), _rooms_cleared()])
		else:
			room_states[current_layout.id].cleared = true
			phase = "explore"
			print("TREASURE_TAKEN room=%d" % room)


func _rooms_cleared() -> int:
	var cleared := 0
	for status in room_states.values():
		if status.cleared: cleared += 1
	return cleared


func _make_snapshot() -> Dictionary:
	var visible_players := {}
	for id in players:
		var player: Dictionary = players[id]
		var aim: Vector2 = player.get("aim", Vector2.RIGHT)
		var move: Vector2 = player.get("move", Vector2.ZERO)
		# Animation hints only: clients pick frames and facing, the host owns the state.
		visible_players[id] = {"x": player.pos.x, "y": player.pos.y, "hp": player.hp, "max_hp": player.max_hp, "color": player.color, "ready": player.ready, "picked": player.picked, "perks": player.perks.duplicate(), "ax": aim.x, "ay": aim.y, "moving": move != Vector2.ZERO, "hurt": player.invulnerable > 0.0, "shots": int(player.get("shots", 0)), "hurts": int(player.get("hurts", 0)),
			"level": int(player.get("level", 1)), "exp": int(player.get("exp", 0)), "exp_next": Progression.exp_to_next(int(player.get("level", 1)), balance.leveling),
			"level_ups": int(player.get("level_ups", 0)), "pickups": int(player.get("pickups", 0)), "kills": int(player.get("kills", 0)), "exp_total": int(player.get("exp_total", 0)),
			"class": str(player.get("class_id", "")), "weapons": player.get("weapons", []).duplicate(), "weapon_index": int(player.get("weapon_index", 0)),
			"swings": int(player.get("swings", 0)), "swing_a": float(player.get("swing_angle", 0.0)), "swing_arc": float(player.get("swing_arc", 2.0)), "reach": float(player.get("reach", 0.0)),
			"choices": _choice_cards(player), "pending": int(player.get("pending_choices", 0)), "abilities": player.get("abilities", {}).duplicate(),
			"rooted": float(player.get("rooted", 0.0)) > 0.0, "boosts": int(player.get("boosts", 0)), "boost_text": str(player.get("boost_text", "")), "shield": Loadout.stacks(player, "shield") > 0 and float(player.get("shield_timer", 0.0)) <= 0.0, "shield_breaks": int(player.get("shield_breaks", 0)), "stats": Progression.display_stats(player, balance)}
	var visible_enemies: Array = []
	for enemy in enemies:
		var hit_dir: Vector2 = enemy.get("hit_dir", Vector2.ZERO)
		var attack: String = str(enemy.get("attack", ""))
		var attack_length: float = float(_attack_for(enemy).get(attack, 1.0)) if not attack.is_empty() else 1.0
		var dying_length: float = maxf(float(balance.death.boss_duration if enemy.boss else balance.death.duration), 0.001)
		var entry := {"x": enemy.pos.x, "y": enemy.pos.y, "hp": enemy.hp, "max_hp": enemy.max_hp, "boss": enemy.boss, "kind": enemy.get("kind", "chaser"), "face": enemy.get("face", -1.0), "moving": enemy.get("moving", false), "hit": float(enemy.get("hit_timer", 0.0)) > 0.0,
			"id": int(enemy.get("id", -1)), "hits": int(enemy.get("hits", 0)), "dx": hit_dir.x, "dy": hit_dir.y, "attacks": int(enemy.get("attacks", 0)),
			"attack": attack, "attack_p": clampf(1.0 - float(enemy.get("attack_time", 0.0)) / maxf(attack_length, 0.001), 0.0, 1.0),
			"dying_p": clampf(1.0 - float(enemy.get("dying", 0.0)) / dying_length, 0.0, 1.0) if enemy.hp <= 0 else -1.0}
		entry.elite = enemy.get("elite", false)
		entry.healed = int(enemy.get("healed", 0))
		entry.blocks = int(enemy.get("blocks", 0))
		entry.hasted = float(enemy.get("haste", 0.0)) > 0.0
		entry.raging = enemy.get("raging", false)
		if not enemy.boss and enemy.has("aim_dir"):
			entry.aim_x = Vector2(enemy.aim_dir).x
			entry.aim_y = Vector2(enemy.aim_dir).y
			entry.dash = enemy.get("dashing", false)
		if enemy.boss:
			entry.axe_out = enemy.get("axe_out", false)
			# Telegraph data for the boss's move animations: aim, jump target, beam line.
			var aim: Vector2 = enemy.get("aim_dir", Vector2.LEFT)
			var target: Vector2 = enemy.get("slam_target", enemy.pos)
			var beam_end: Vector2 = enemy.get("beam_end", enemy.pos)
			var origin := _beam_origin(enemy, float(enemy.get("beam_angle", 0.0)))
			entry.merge({"move": str(enemy.get("move", "")), "impacts": int(enemy.get("impacts", 0)), "air": float(enemy.get("air", 0.0)), "aim_x": aim.x, "aim_y": aim.y,
				"tx": target.x, "ty": target.y, "reach": float(balance.boss_moves.slam.radius), "ox": origin.x, "oy": origin.y, "bx": beam_end.x, "by": beam_end.y})
		visible_enemies.append(entry)
	var visible_bullets: Array = []
	for bullet in bullets:
		var shot := {"x": bullet.pos.x, "y": bullet.pos.y, "owner": bullet.owner}
		if not str(bullet.get("kind", "")).is_empty():
			shot.k = bullet.kind
			shot.a = Vector2(bullet.velocity).angle()
		visible_bullets.append(shot)
	var visible_loot: Array = []
	for chest in loot: visible_loot.append({"id": chest.id, "x": chest.pos.x, "y": chest.pos.y, "open": chest.open})
	var visible_orbs: Array = []
	for orb in orbs: visible_orbs.append({"id": orb.id, "x": orb.pos.x, "y": orb.pos.y, "v": orb.value})
	packet_sequence += 1
	# Clients only learn rooms the party has visited or stands next to (Isaac minimap).
	var map_rooms: Array[Dictionary] = []
	for layout in floor_layouts:
		var status: Dictionary = room_states.get(layout.id, {})
		var seen: bool = status.get("visited", false)
		if not seen:
			for neighbour_id in layout.get("doors", {}).values():
				if room_states.get(neighbour_id, {}).get("visited", false): seen = true
		if not seen: continue
		map_rooms.append({"id": layout.id, "title": layout.title, "kind": layout.get("kind", "normal"), "boss": layout.boss, "grid_x": layout.grid_x, "grid_y": layout.grid_y, "visited": status.get("visited", false), "cleared": status.get("cleared", false), "doors": layout.get("doors", {}).keys()})
	return {"players": visible_players, "enemies": visible_enemies, "bullets": visible_bullets, "orbs": visible_orbs, "loot": visible_loot, "hazards": abilities.snapshot(), "boss_bar": _boss_bar(), "room": room, "phase": phase, "seed": run_seed, "seq": packet_sequence, "peer_count": players.size(), "perk_options": perk_options, "reward_kind": reward_kind, "room_layout": current_layout.duplicate(true), "floor_map": map_rooms, "room_count": floor_layouts.size(), "rooms_cleared": _rooms_cleared(), "rooms_total": rooms_cleared_before + _rooms_cleared(), "floor": floor_number, "endless": endless, "doors_open": phase == "explore", "generator_version": Dungeon.GENERATOR_VERSION}


func _choice_cards(player: Dictionary) -> Array:
	var cards: Array = []
	for id in player.get("choices", []):
		var ability: Dictionary = balance.abilities[id]
		cards.append({"id": id, "name": ability.name, "description": ability.description, "stack": Loadout.stacks(player, id), "max": int(ability.max)})
	return cards


## The boss of the current room for the HUD's top bar: name and health.
func _boss_bar() -> Dictionary:
	for enemy in enemies:
		if enemy.get("boss", false):
			return {"name": str(_definition(_kind(enemy)).get("name", "")), "hp": enemy.hp, "max_hp": enemy.max_hp}
	return {}


func _broadcast_state(reliable: bool) -> void:
	if not active or not hosting: return
	var snapshot := _make_snapshot()
	_apply_snapshot(snapshot)
	if multiplayer.get_peers().is_empty(): return
	# Repeated dictionary keys compress well; keep ordinary snapshots under ENet's MTU.
	# Larger snapshots use reliable fragmentation rather than oversized unreliable datagrams.
	var payload := var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE)
	for id in multiplayer.get_peers():
		# SceneMultiplayer can still list a peer whose ENet channel teardown has begun.
		var transport := peer.get_peer(id)
		if transport == null or transport.get_state() != ENetPacketPeer.STATE_CONNECTED: continue
		if reliable or payload.size() > 1100: _reliable_state.rpc_id(id, payload)
		else: _state_packet.rpc_id(id, payload)


@rpc("authority", "call_remote", "unreliable_ordered", 0)
func _state_packet(payload: PackedByteArray) -> void:
	if active and not hosting: _apply_encoded_state(payload)


@rpc("authority", "call_remote", "reliable", 1)
func _reliable_state(payload: PackedByteArray) -> void:
	if active and not hosting: _apply_encoded_state(payload)


func _apply_encoded_state(payload: PackedByteArray) -> void:
	if payload.is_empty() or payload.size() > 16384: return
	var decoded := payload.decompress_dynamic(131072, FileAccess.COMPRESSION_DEFLATE)
	if decoded.is_empty(): return
	var snapshot = bytes_to_var(decoded)
	if snapshot is Dictionary: _apply_snapshot(snapshot)


func _apply_snapshot(snapshot: Dictionary) -> void:
	var sequence := int(snapshot.get("seq", -1))
	if sequence <= received_sequence: return
	received_sequence = sequence
	state = snapshot
	phase = str(snapshot.get("phase", phase))
	room = int(snapshot.get("room", room))
	var layout: Dictionary = snapshot.get("room_layout", {})
	if not layout.is_empty() and str(layout.id) != last_layout_id:
		last_layout_id = layout.id
		var signature := var_to_bytes(layout).hex_encode().sha256_text()
		print("ROOM_LAYOUT id=%s template=%s version=%d signature=%s" % [layout.id, layout.template_id, layout.generator_version, signature])
	if not seen_snapshot or phase != last_phase:
		print("SNAPSHOT_RECEIVED phase=%s players=%d room=%d" % [phase, snapshot.get("players", {}).size(), room])
		seen_snapshot = true
		last_phase = phase


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var panel := Panel.new()
	panel.position = Vector2(944, 156)
	panel.size = Vector2(304, 480)
	panel.add_theme_stylebox_override("panel", _style(Color("1a1d29"), Color("343747")))
	ui.add_child(panel)
	# The title band becomes the run HUD (hearts, level, EXP) once a run starts.
	title_labels.append(_label("BASEMENT RUN", Vector2(32, 25), Vector2(650, 45), 34, Color("edbf75")))
	title_labels.append(_label("IN DIE TIEFE. ZUSAMMEN.", Vector2(34, 70), Vector2(700, 22), 14, Color("8e96ac")))
	session_label = _label("ENTWICKLUNGSPROTOTYP", Vector2(952, 35), Vector2(296, 50), 14, Color("72dcc8"))
	status_label = _label("", Vector2(32, 112), Vector2(1216, 30), 15, Color("b6bdce"))
	phase_label = _label("DIE LOBBY", Vector2(968, 178), Vector2(264, 30), 22, Color("edbf75"))
	party_label = _label("", Vector2(968, 219), Vector2(264, 140), 15, Color("c7cbda"))
	party_label.add_theme_font_size_override("font_size", 13)
	party_label.add_theme_constant_override("line_spacing", -2)
	floor_map = preload("res://src/dungeon/dungeon_map.gd").new()
	floor_map.position = Vector2(968, 296)
	floor_map.size = Vector2(264, 108)
	ui.add_child(floor_map)
	address_input = LineEdit.new()
	address_input.position = Vector2(968, 366)
	address_input.size = Vector2(174, 36)
	address_input.text = "127.0.0.1"
	address_input.placeholder_text = "Host-IP"
	ui.add_child(address_input)
	port_input = LineEdit.new()
	port_input.position = Vector2(1150, 366)
	port_input.size = Vector2(82, 36)
	port_input.text = str(int(balance.network.port))
	ui.add_child(port_input)
	host_button = _button("HOSTEN", Vector2(968, 418), Vector2(126, 42), _host_session)
	join_button = _button("BEITRETEN", Vector2(1106, 418), Vector2(126, 42), _join_session)
	solo_button = _button("SOLO ERKUNDEN", Vector2(968, 474), Vector2(264, 46), _start_solo)
	back_button = _button("ZURÜCK ZUM MENÜ", Vector2(968, 560), Vector2(264, 36), func():
		menu_open = true
		_refresh_ui())
	# Perk choices lie over the bottom of the room (nobody moves while choosing),
	# so the side panel keeps its stats column visible.
	for i in range(3):
		var button := _button("", Vector2(46 + i * 290, 560), Vector2(276, 56), _send_action.bind("perk", i))
		button.add_theme_font_size_override("font_size", 13)
		perk_buttons.append(button)
	ability_label = _label("LEVEL UP · WÄHLE EINE FÄHIGKEIT  (1 / 2 / 3)", Vector2(46, 470), Vector2(856, 22), 15, Color("ffd76a"))
	for i in range(3):
		var card := _button("", Vector2(46 + i * 290, 494), Vector2(276, 58), _send_action.bind("ability", i))
		card.add_theme_font_size_override("font_size", 13)
		ability_buttons.append(card)
	class_button = _button("", Vector2(968, 412), Vector2(264, 40), func():
		var order: Array = balance.class_order
		var current: int = order.find(str(state.get("players", {}).get(multiplayer.get_unique_id(), {}).get("class", balance.default_class)))
		_send_action("class", (current + 1) % order.size()))
	action_button = _button("RUN STARTEN", Vector2(968, 560), Vector2(264, 36), _main_action)
	leave_button = _button("LOBBY VERLASSEN", Vector2(968, 602), Vector2(264, 28), _leave_session.bind("Lobby verlassen."))
	_label("WASD BEWEGEN · MAUS ZIELEN · LINKE MAUSTASTE ANGREIFEN · TRUHEN BERÜHREN · 1-3 FÄHIGKEIT WÄHLEN", Vector2(32, 656), Vector2(896, 28), 14, Color("8e96ac"))
	_label("EIN STOCKWERK  /  EIN GEMEINSAMER LAUF", Vector2(952, 656), Vector2(296, 28), 12, Color("737d94"))
	hud = preload("res://src/ui/hud.gd").new()
	canvas.add_child(hud)
	main_menu = preload("res://src/main_menu.gd").new()
	main_menu.account = account
	main_menu.classes = balance.classes
	main_menu.class_order = balance.class_order
	main_menu.weapons = balance.weapons
	main_menu.debug_entries = _debug_entries()
	canvas.add_child(main_menu)
	main_menu.start_requested.connect(_start_solo)
	main_menu.settings_changed.connect(_apply_settings)
	_apply_settings(main_menu.settings)
	main_menu.multiplayer_requested.connect(func():
		menu_open = false
		_refresh_ui())
	main_menu.quit_requested.connect(func(): get_tree().quit())


## Every level to jump straight into for testing: the story floor and each
## endless floor, its start or its boss room, and a deep floor.
func _debug_entries() -> Array:
	var entries: Array = [{"label": "STORY · START", "endless": false, "floor": 1, "room": ""},
		{"label": "STORY · BOSS %s" % str(balance.boss.name).split(",")[0], "endless": false, "floor": 1, "room": "boss"}]
	var floors: Array = balance.floors
	for i in range(floors.size()):
		var boss_name: String = str(_definition(str(floors[i].boss)).get("name", "")).split(",")[0]
		entries.append({"label": "ENDLOS %d · START" % (i + 1), "endless": true, "floor": i + 1, "room": ""})
		entries.append({"label": "ENDLOS %d · BOSS %s" % [i + 1, boss_name], "endless": true, "floor": i + 1, "room": "boss"})
	entries.append({"label": "ENDLOS 8 · TIEF (VIELE ELITEN)", "endless": true, "floor": 8, "room": ""})
	entries.append({"label": "ENDLOS 12 · SEHR TIEF", "endless": true, "floor": 12, "room": ""})
	return entries


func _apply_settings(settings: Dictionary) -> void:
	view.shake_scale = 1.0 if bool(settings.get("shake", true)) else 0.0


func _start_solo(endless_mode: bool = false, class_id: String = "") -> void:
	menu_open = false
	# A start from the debug level list jumps to its floor and room.
	var jump: Dictionary = main_menu.take_debug_start()
	if not jump.is_empty():
		endless_mode = bool(jump.endless)
		debug_floor = int(jump.floor)
		debug_room = str(jump.room)
	_host_session()
	endless = endless_mode
	if not class_id.is_empty() and active and hosting:
		player_classes[1] = class_id
		Loadout.apply_class(players[1], class_id, balance)
	if active and hosting:
		solo_session = true
		_server_action(1, "start", 0)
	_refresh_ui()


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _label(text: String, position: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(label)
	return label


func _button(text: String, position: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("edbf75"))
	button.add_theme_color_override("font_disabled_color", Color("767d91"))
	button.add_theme_stylebox_override("normal", _style(Color("292b37"), Color("61523a")))
	button.add_theme_stylebox_override("hover", _style(Color("383846"), Color("edbf75")))
	button.add_theme_stylebox_override("pressed", _style(Color("3e3a34"), Color("72dcc8")))
	button.add_theme_stylebox_override("disabled", _style(Color("222532"), Color("35394b")))
	button.pressed.connect(callback)
	ui.add_child(button)
	return button


func _main_action() -> void:
	_send_action("ready" if phase == "reward" else "start")


func _refresh_ui() -> void:
	var visible_players: Dictionary = state.get("players", {})
	var maximum_players := int(balance.network.max_players)
	var local_id := multiplayer.get_unique_id() if active else 0
	var local_player: Dictionary = visible_players.get(local_id, {})
	session_label.text = "HOST · UDP %d\n%d / %d WANDERER" % [_port(), visible_players.size(), maximum_players] if active and hosting else "CLIENT · VERBUNDEN\n%d / %d WANDERER" % [visible_players.size(), maximum_players] if active else "GODOT 4.7.2\nENTWICKLUNGSPROTOTYP"
	if phase == "connecting": session_label.text = "CLIENT · VERBINDET …"
	var cleared_label := "GERÄUMT %d / %d" % [int(state.get("rooms_cleared", 0)), int(state.get("room_count", 0))]
	var names := {"menu": "DIE LOBBY", "connecting": "VERBINDEN …", "lobby": "EURE GRUPPE", "combat": "KAMPF · " + cleared_label, "explore": "ERKUNDEN · " + cleared_label, "reward": "SCHATZKAMMER" if state.get("reward_kind", "") == "treasure" else "WÄHLE DEINEN PERK", "dead": "DIE TIEFE SIEGT", "victory": "BOSS BESIEGT"}
	phase_label.text = names.get(phase, phase.to_upper())
	floor_map.visible = active and not state.get("floor_map", []).is_empty()
	floor_map.set_floor(state.get("floor_map", []), str(state.get("room_layout", {}).get("id", "")))
	party_label.text = ("Ein Dungeon-Stockwerk.\n6–10 Räume, ein Schatz, ein Boss.\nBis zu %d separate Clients.\n\nDirekte IP benötigt erreichbaren\nUDP-Port; kein Relay enthalten." % maximum_players) if not active else ""
	var index := 1
	for id in visible_players:
		var player: Dictionary = visible_players[id]
		var suffix := " · DU" if int(id) == local_id else ""
		var condition := "BEREIT" if player.ready else "LV %d · %d/%d LP" % [int(player.get("level", 1)), player.hp, player.max_hp] if player.hp > 0 else "GEFALLEN"
		party_label.text += "SPIELER %02d%s  ·  %s\n" % [index, suffix, condition]
		index += 1
	status_label.text = status_message
	if phase == "combat": status_label.text = "%s · Seed %d · Die Türen bleiben zu, bis alle Gegner besiegt sind." % [state.get("room_layout", {}).get("title", ""), state.get("seed", 0)]
	elif phase == "explore": status_label.text = "%s · Die Türen sind offen. Wer hindurchgeht, nimmt die ganze Gruppe mit." % state.get("room_layout", {}).get("title", "")
	elif phase == "reward" and state.get("reward_kind", "") == "treasure": status_label.text = "Schatzkammer: Jeder lebende Spieler wählt einen Perk. Danach öffnen sich die Türen."
	elif phase == "reward": status_label.text = "Pro lebendem Spieler genau ein Perk. Danach müssen alle lebenden Spieler bereit sein."
	elif phase == "victory": status_label.text = "Geschafft. Ihr habt %d Räume geräumt und den Boss besiegt. Der Host kann einen neuen Lauf starten." % int(state.get("rooms_cleared", 0))
	elif phase == "dead" and bool(state.get("endless", false)): status_label.text = "Endlos-Modus: gefallen auf Stockwerk %d nach %d geräumten Räumen. Ein neuer Lauf beginnt wieder auf Stockwerk 1." % [int(state.get("floor", 1)), int(state.get("rooms_total", 0))]
	elif phase == "dead": status_label.text = "Alle Wanderer sind gefallen. Der Host kann den Lauf mit einem neuen Seed neu starten."
	for node in [address_input, port_input, host_button, join_button, solo_button]: node.visible = not active
	for label in title_labels: label.visible = not hud.showing()
	main_menu.visible = not active and menu_open
	back_button.visible = not active and not menu_open
	leave_button.visible = active
	action_button.visible = active
	action_button.disabled = true
	action_button.text = "HOST STARTET" if phase == "lobby" else "TÜR SUCHEN" if phase == "explore" else "RAUM SÄUBERN"
	if phase in ["lobby", "dead", "victory"] and hosting:
		action_button.text = "RUN STARTEN" if phase == "lobby" else "NEUER LAUF"
		action_button.disabled = false
	elif phase == "reward":
		action_button.text = "BEREIT ✓" if local_player.get("ready", false) else "BEREIT · TÜREN ÖFFNEN"
		if state.get("reward_kind", "") == "boss" and not local_player.get("ready", false): action_button.text = "TIEFER HINAB" if bool(state.get("endless", false)) else "LAUF ABSCHLIESSEN"
		action_button.disabled = not local_player.get("picked", false) or local_player.get("ready", false) or local_player.get("hp", 0) <= 0
	var cards: Array = local_player.get("choices", [])
	ability_label.visible = active and not cards.is_empty()
	for i in range(ability_buttons.size()):
		ability_buttons[i].visible = active and i < cards.size()
		if i < cards.size():
			var stack: String = " (%d/%d)" % [int(cards[i].stack) + 1, int(cards[i].max)] if int(cards[i].max) > 1 else ""
			ability_buttons[i].text = "[%d] %s%s\n%s" % [i + 1, cards[i].name, stack, cards[i].description]
	class_button.visible = active and phase == "lobby"
	var hero_class: Dictionary = balance.classes.get(str(local_player.get("class", balance.default_class)), {})
	class_button.text = "KLASSE: %s  ►" % str(hero_class.get("name", ""))
	var options: Array = state.get("perk_options", [])
	for i in range(perk_buttons.size()):
		perk_buttons[i].visible = active and phase == "reward" and i < options.size()
		perk_buttons[i].disabled = local_player.get("picked", false) or local_player.get("hp", 0) <= 0
		if i < options.size(): perk_buttons[i].text = options[i].name + "\n" + options[i].description
