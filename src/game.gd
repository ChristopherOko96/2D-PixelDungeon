extends Node2D
## A small host-authoritative development slice. No gameplay objects are accepted from peers.

const WORLD_SIZE := Vector2(896, 480)
const WORLD_OFFSET := Vector2(32, 156)
const PLAYER_COLORS := [Color("72dcc8"), Color("edb563"), Color("bc91de"), Color("ed8a91")]
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

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
		if not smoke_role.is_empty() and active and phase == "reward":
			var local_player: Dictionary = state.get("players", {}).get(multiplayer.get_unique_id(), {})
			if not local_player.is_empty() and local_player.get("hp", 0) > 0:
				if not local_player.get("picked", false): _send_action("perk", 0)
				elif not local_player.get("ready", false): _send_action("ready")
	if not state.is_empty(): view.set_state(state, multiplayer.get_unique_id() if active else 0)


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
		_simulate_bullets(delta)
		_check_room_end()
	elif phase == "explore":
		_simulate_players(delta)
		_simulate_bullets(delta)
		_check_doors()
	snapshot_clock += delta
	if snapshot_clock >= 1.0 / float(balance.network.snapshot_hz):
		snapshot_clock = 0.0
		_broadcast_state(false)


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
	floor_layouts.clear()
	current_layout.clear()
	room_states.clear()
	last_layout_id = ""
	phase = "menu"
	# A solo run returns to the title screen; a multiplayer session stays in the
	# lobby controls so connection errors remain readable.
	if solo_session: menu_open = true
	solo_session = false
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
	players[id] = {"pos": Vector2(150 + index * 52, 210 + (index % 2) * 50), "hp": int(balance.player.hp), "max_hp": int(balance.player.hp), "color": PLAYER_COLORS[index % PLAYER_COLORS.size()], "ready": false, "picked": false, "perks": [], "damage": float(balance.player.damage), "speed": float(balance.player.speed), "shot_interval": float(balance.player.shot_interval), "shot_timer": 0.0, "invulnerable": 0.0, "aim": Vector2.RIGHT, "move": Vector2.ZERO, "knock": Vector2.ZERO}


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
		movement = aim if distance > 250.0 * 250.0 else -aim if distance < 150.0 * 150.0 else Vector2.ZERO
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
	elif action == "ready" and phase == "reward" and players[id].hp > 0 and players[id].picked:
		players[id].ready = true
		_advance_if_ready()
	else: return
	_broadcast_state(true)


func _begin_run() -> void:
	var seed_value := requested_seed if requested_seed >= 0 else randi_range(10000, 99999)
	var count := Dungeon.room_count_for_seed(seed_value, int(balance.rooms.min_count), int(balance.rooms.max_count))
	var generated := Dungeon.generate(seed_value, count, dungeon_config)
	if generated.is_empty():
		status_message = "Dungeon konnte nicht erstellt werden. Raumdaten prüfen."
		return
	peer.refuse_new_connections = true
	run_seed = seed_value
	floor_layouts = generated
	room_states.clear()
	for layout in floor_layouts: room_states[layout.id] = {"visited": false, "cleared": false}
	last_layout_id = ""
	var ids := players.keys()
	players.clear()
	for id in ids: _add_player(id)
	commands.clear()
	print("RUN_STARTED seed=%d players=%d rooms=%d" % [run_seed, players.size(), floor_layouts.size()])
	_enter_room(0, "")


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
		var kinds: Array[String] = ["boss"]
		if kind != "boss": kinds = _enemy_kinds_for(current_layout)
		count = kinds.size()
		for i in range(count):
			var definition: Dictionary = balance.boss if kinds[i] == "boss" else balance.shooter if kinds[i] == "shooter" else balance.enemy
			var hp := int(definition.hp + maxi(0, players.size() - 1) * definition.hp_per_extra_player)
			# Shooters wait a moment before their first shot, so arrivals can react.
			enemies.append({"pos": Dungeon.spawn_for_enemy(i, current_layout, entry_side), "hp": hp, "max_hp": hp, "boss": kinds[i] == "boss", "kind": kinds[i], "radius": float(definition.radius), "speed": float(definition.speed), "shot_timer": 1.0 + 0.4 * i, "nav_timer": 0.0, "nav_path": PackedVector2Array(), "knock": Vector2.ZERO, "hit_timer": 0.0, "face": -1.0, "moving": false, "id": next_enemy_id, "attack": "", "attack_time": 0.0})
			next_enemy_id += 1
	print("ROOM_STARTED room=%d kind=%s enemies=%d boss=%s" % [room, kind, count, kind == "boss"])


## Seeded encounter for a normal room: 3-5 enemies, of which up to
## `rooms.shooters_max` are shooters; the first enemy always chases.
func _enemy_kinds_for(layout: Dictionary) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("enemies:%d:%s" % [run_seed, layout.id])
	var count := rng.randi_range(int(balance.rooms.enemies_min), int(balance.rooms.enemies_max))
	var shooters := rng.randi_range(0, mini(int(balance.rooms.shooters_max), count - 1))
	var kinds: Array[String] = []
	for i in range(count): kinds.append("shooter" if i >= count - shooters else "chaser")
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
		if player.hp <= 0: continue
		_apply_knockback(player, 12.0, delta)
		var command: Dictionary = commands.get(id, {})
		if command.is_empty() or now - command.time > float(balance.network.input_timeout):
			player.move = Vector2.ZERO
			continue
		player.move = command.move
		player.aim = command.aim
		player.pos = Dungeon.move_actor(player.pos, command.move * player.speed * delta, 12.0, current_layout)
		if command.fire and player.shot_timer <= 0.0:
			player.shot_timer = player.shot_interval
			var muzzle: Vector2 = player.pos + command.aim * 15.0
			if not Dungeon.segment_blocked(player.pos, muzzle, float(balance.bullet.radius), current_layout):
				_add_bullet(muzzle, command.aim * float(balance.bullet.speed), id, player.damage)
				# Counters, not flags: a client that misses a snapshot still sees the change.
				player.shots = int(player.get("shots", 0)) + 1


func _add_bullet(position: Vector2, velocity: Vector2, owner: int, damage: float) -> void:
	if bullets.size() >= int(balance.bullet.max_count): return
	bullets.append({"pos": position, "velocity": velocity, "owner": owner, "damage": damage, "life": float(balance.bullet.lifetime) if owner != 0 else 5.0})


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
		if enemy.get("kind", "chaser") == "shooter" and in_sight:
			# Shooters hold a firing range: back off when crowded, close in when far.
			var gap: float = enemy.pos.distance_to(target_pos)
			var away: Vector2 = (enemy.pos - target_pos).normalized()
			direction = away if gap < float(balance.shooter.keep_min) else -away if gap > float(balance.shooter.keep_max) else Vector2.ZERO
		# Attackers plant their feet while winding up and firing (readable anticipation).
		if enemy.get("attack", "") in ["windup", "active"]: direction = Vector2.ZERO
		enemy.pos = Dungeon.move_actor(enemy.pos, direction * enemy.speed * delta, enemy.radius, current_layout)
		enemy.moving = direction != Vector2.ZERO
		if absf(target_pos.x - enemy.pos.x) > 2.0: enemy.face = signf(target_pos.x - enemy.pos.x)
		if enemy.pos.distance_to(target_pos) < enemy.radius + 12.0 and not Dungeon.segment_blocked(enemy.pos, target_pos, 0.0, current_layout):
			_damage_player(target, int(balance.enemy.damage), enemy.pos)
		if balance.attacks.has(enemy.get("kind", "chaser")):
			_update_attack(enemy, delta, target_pos, in_sight)


## Attack phases shared by every ranged enemy: idle (cooldown) → windup → active
## (projectiles spawn on this frame) → recovery → idle. Timings and the pattern
## come from balance.attacks[kind]; clients animate from `attack`/`attack_time`.
func _update_attack(enemy: Dictionary, delta: float, target_pos: Vector2, in_sight: bool) -> void:
	var attack: Dictionary = balance.attacks[enemy.kind]
	enemy.attack_time = float(enemy.get("attack_time", 0.0)) - delta
	match str(enemy.get("attack", "")):
		"":
			enemy.shot_timer -= delta
			if enemy.shot_timer <= 0.0 and (in_sight or attack.pattern == "ring"):
				enemy.attack = "windup"
				enemy.attack_time = float(attack.windup)
		"windup":
			if enemy.attack_time <= 0.0:
				_fire_pattern(enemy, attack, target_pos)
				enemy.attack = "active"
				enemy.attack_time = float(attack.active)
		"active":
			if enemy.attack_time <= 0.0:
				enemy.attack = "recovery"
				enemy.attack_time = float(attack.recovery)
		"recovery":
			if enemy.attack_time <= 0.0:
				enemy.attack = ""
				enemy.shot_timer = float(attack.interval)


func _fire_pattern(enemy: Dictionary, attack: Dictionary, target_pos: Vector2) -> void:
	var speed := float(attack.bullet_speed)
	match str(attack.pattern):
		"aimed":
			var aim_at: Vector2 = (target_pos - enemy.pos).normalized()
			_add_bullet(enemy.pos + aim_at * (enemy.radius + 4.0), aim_at * speed, 0, float(attack.damage))
		"ring":
			var count := int(attack.count)
			# Each volley turns a little, so the gaps move and the ring stays dodgeable.
			enemy.volley = int(enemy.get("volley", 0)) + 1
			for i in range(count):
				var aim := Vector2.RIGHT.rotated(TAU * i / count + enemy.volley * 0.35)
				_add_bullet(enemy.pos + aim * enemy.radius, aim * speed, 0, float(attack.damage))
	enemy.attacks = int(enemy.get("attacks", 0)) + 1


func _simulate_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		var previous: Vector2 = bullet.pos
		bullet.pos += bullet.velocity * delta
		bullet.life -= delta
		var removed: bool = bullet.life <= 0.0 or Dungeon.segment_blocked(previous, bullet.pos, float(balance.bullet.radius), current_layout)
		if not removed and bullet.owner == 0:
			for id in players:
				if players[id].hp > 0 and bullet.pos.distance_to(players[id].pos) < 12.0 + float(balance.bullet.radius):
					_damage_player(id, int(bullet.damage), bullet.pos - bullet.velocity)
					removed = true
					break
		elif not removed:
			for enemy in enemies:
				if enemy.hp > 0 and bullet.pos.distance_to(enemy.pos) < enemy.radius + float(balance.bullet.radius):
					_hit_enemy(enemy, bullet.damage, bullet.velocity.normalized())
					removed = true
					break
		if removed: bullets.remove_at(i)
	# Dead enemies stay until their death animation has run (see _simulate_enemies).
	enemies = enemies.filter(func(enemy): return enemy.hp > 0 or float(enemy.get("dying", 0.0)) > 0.0)


## Applies a landed hit: damage, knockback along the shot, hit flash, and on the
## killing blow the dying state (no more attacks, contact damage or hits).
func _hit_enemy(enemy: Dictionary, damage: float, direction: Vector2) -> void:
	enemy.hp -= damage
	var strength: float = float(balance.knockback.boss if enemy.boss else balance.knockback.enemy)
	enemy.hit_timer = float(balance.knockback.flash)
	enemy.hits = int(enemy.get("hits", 0)) + 1
	enemy.hit_dir = direction
	if enemy.hp <= 0:
		enemy.hp = 0
		enemy.attack = ""
		enemy.dying = float(balance.death.boss_duration if enemy.boss else balance.death.duration)
		strength = float(balance.death.boss_kick if enemy.boss else balance.death.kick)
	enemy.knock = direction * strength


## Hurts a player unless invulnerable. A finite `source` pushes them away from it.
func _damage_player(id: int, damage: int, source: Vector2 = Vector2.INF) -> void:
	if players[id].invulnerable > 0.0 or players[id].hp <= 0: return
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
		print("TEAM_WIPE room=%d" % room)
		_broadcast_state(true)
	elif enemies.is_empty():
		bullets.clear()
		room_states[current_layout.id].cleared = true
		if current_layout.get("kind", "") == "boss": _open_reward("boss")
		else: phase = "explore"
		print("ROOM_CLEARED room=%d phase=%s" % [room, phase])
		_broadcast_state(true)


func _grant_perk(id: int, perk: Dictionary) -> void:
	var player: Dictionary = players[id]
	match perk.stat:
		"damage": player.damage += perk.amount
		"speed": player.speed += perk.amount
		"max_hp":
			player.max_hp += int(perk.amount)
			player.hp = mini(player.max_hp, player.hp + int(perk.amount))
		"shot_interval": player.shot_interval = maxf(0.06, player.shot_interval * perk.amount)
		"heal": player.hp = mini(player.max_hp, player.hp + int(perk.amount))
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
		if reward_kind == "boss":
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
		visible_players[id] = {"x": player.pos.x, "y": player.pos.y, "hp": player.hp, "max_hp": player.max_hp, "color": player.color, "ready": player.ready, "picked": player.picked, "perks": player.perks.duplicate(), "ax": aim.x, "ay": aim.y, "moving": move != Vector2.ZERO, "hurt": player.invulnerable > 0.0, "shots": int(player.get("shots", 0)), "hurts": int(player.get("hurts", 0))}
	var visible_enemies: Array = []
	for enemy in enemies:
		var hit_dir: Vector2 = enemy.get("hit_dir", Vector2.ZERO)
		var attack: String = str(enemy.get("attack", ""))
		var attack_length: float = float(balance.attacks.get(enemy.get("kind", ""), {}).get(attack, 1.0)) if not attack.is_empty() else 1.0
		var dying_length: float = maxf(float(balance.death.boss_duration if enemy.boss else balance.death.duration), 0.001)
		visible_enemies.append({"x": enemy.pos.x, "y": enemy.pos.y, "hp": enemy.hp, "max_hp": enemy.max_hp, "boss": enemy.boss, "kind": enemy.get("kind", "chaser"), "face": enemy.get("face", -1.0), "moving": enemy.get("moving", false), "hit": float(enemy.get("hit_timer", 0.0)) > 0.0,
			"id": int(enemy.get("id", -1)), "hits": int(enemy.get("hits", 0)), "dx": hit_dir.x, "dy": hit_dir.y, "attacks": int(enemy.get("attacks", 0)),
			"attack": attack, "attack_p": clampf(1.0 - float(enemy.get("attack_time", 0.0)) / maxf(attack_length, 0.001), 0.0, 1.0),
			"dying_p": clampf(1.0 - float(enemy.get("dying", 0.0)) / dying_length, 0.0, 1.0) if enemy.hp <= 0 else -1.0})
	var visible_bullets: Array = []
	for bullet in bullets: visible_bullets.append({"x": bullet.pos.x, "y": bullet.pos.y, "owner": bullet.owner})
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
	return {"players": visible_players, "enemies": visible_enemies, "bullets": visible_bullets, "room": room, "phase": phase, "seed": run_seed, "seq": packet_sequence, "peer_count": players.size(), "perk_options": perk_options, "reward_kind": reward_kind, "room_layout": current_layout.duplicate(true), "floor_map": map_rooms, "room_count": floor_layouts.size(), "rooms_cleared": _rooms_cleared(), "doors_open": phase == "explore", "generator_version": Dungeon.GENERATOR_VERSION}


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
	_label("BASEMENT RUN", Vector2(32, 25), Vector2(650, 45), 34, Color("edbf75"))
	_label("IN DIE TIEFE. ZUSAMMEN.", Vector2(34, 70), Vector2(700, 22), 14, Color("8e96ac"))
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
	for i in range(3):
		var button := _button("", Vector2(968, 412 + i * 48), Vector2(264, 42), _send_action.bind("perk", i))
		button.add_theme_font_size_override("font_size", 13)
		perk_buttons.append(button)
	action_button = _button("RUN STARTEN", Vector2(968, 560), Vector2(264, 36), _main_action)
	leave_button = _button("LOBBY VERLASSEN", Vector2(968, 602), Vector2(264, 28), _leave_session.bind("Lobby verlassen."))
	_label("WASD  BEWEGEN     MAUS  ZIELEN     LINKE MAUSTASTE  FEUERN     OFFENE TÜR  NÄCHSTER RAUM", Vector2(32, 656), Vector2(896, 28), 14, Color("8e96ac"))
	_label("EIN STOCKWERK  /  EIN GEMEINSAMER LAUF", Vector2(952, 656), Vector2(296, 28), 12, Color("737d94"))
	main_menu = preload("res://src/main_menu.gd").new()
	canvas.add_child(main_menu)
	main_menu.solo_requested.connect(_start_solo)
	main_menu.multiplayer_requested.connect(func():
		menu_open = false
		_refresh_ui())
	main_menu.quit_requested.connect(func(): get_tree().quit())


func _start_solo() -> void:
	menu_open = false
	_host_session()
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
		var condition := "BEREIT" if player.ready else "%d/%d LP" % [player.hp, player.max_hp] if player.hp > 0 else "GEFALLEN"
		party_label.text += "SPIELER %02d%s  ·  %s\n" % [index, suffix, condition]
		index += 1
	status_label.text = status_message
	if phase == "combat": status_label.text = "%s · Seed %d · Die Türen bleiben zu, bis alle Gegner besiegt sind." % [state.get("room_layout", {}).get("title", ""), state.get("seed", 0)]
	elif phase == "explore": status_label.text = "%s · Die Türen sind offen. Wer hindurchgeht, nimmt die ganze Gruppe mit." % state.get("room_layout", {}).get("title", "")
	elif phase == "reward" and state.get("reward_kind", "") == "treasure": status_label.text = "Schatzkammer: Jeder lebende Spieler wählt einen Perk. Danach öffnen sich die Türen."
	elif phase == "reward": status_label.text = "Pro lebendem Spieler genau ein Perk. Danach müssen alle lebenden Spieler bereit sein."
	elif phase == "victory": status_label.text = "Geschafft. Ihr habt %d Räume geräumt und den Boss besiegt. Der Host kann einen neuen Lauf starten." % int(state.get("rooms_cleared", 0))
	elif phase == "dead": status_label.text = "Alle Wanderer sind gefallen. Der Host kann den Lauf mit einem neuen Seed neu starten."
	for node in [address_input, port_input, host_button, join_button, solo_button]: node.visible = not active
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
		if state.get("reward_kind", "") == "boss" and not local_player.get("ready", false): action_button.text = "LAUF ABSCHLIESSEN"
		action_button.disabled = not local_player.get("picked", false) or local_player.get("ready", false) or local_player.get("hp", 0) <= 0
	var options: Array = state.get("perk_options", [])
	for i in range(perk_buttons.size()):
		perk_buttons[i].visible = active and phase == "reward" and i < options.size()
		perk_buttons[i].disabled = local_player.get("picked", false) or local_player.get("hp", 0) <= 0
		if i < options.size(): perk_buttons[i].text = options[i].name + "\n" + options[i].description
