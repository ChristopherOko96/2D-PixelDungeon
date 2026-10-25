extends Node2D
## A small host-authoritative development slice. No gameplay objects are accepted from peers.

const WORLD_SIZE := Vector2(896, 480)
const WORLD_OFFSET := Vector2(32, 156)
const PLAYER_COLORS := [Color("72dcc8"), Color("edb563"), Color("bc91de"), Color("ed8a91")]

var balance: Dictionary = {}
var state: Dictionary = {}
var players: Dictionary = {}
var commands: Dictionary = {}
var enemies: Array = []
var bullets: Array = []
var perk_options: Array = []
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


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	if not parsed is Dictionary:
		push_error("Missing or invalid src/data/balance.json")
		get_tree().quit(1)
		return
	balance = parsed
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
	if phase == "combat" and input_clock >= 1.0 / float(balance.network.input_hz):
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
	phase = "menu"
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
	players[id] = {"pos": Vector2(150 + index * 52, 210 + (index % 2) * 50), "hp": int(balance.player.hp), "max_hp": int(balance.player.hp), "color": PLAYER_COLORS[index % PLAYER_COLORS.size()], "ready": false, "picked": false, "perks": [], "damage": float(balance.player.damage), "speed": float(balance.player.speed), "shot_interval": float(balance.player.shot_interval), "shot_timer": 0.0, "invulnerable": 0.0}


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
		fire = true
	input_sequence += 1
	if hosting: _accept_input(1, movement, aim, fire, input_sequence)
	else: _input_packet.rpc_id(1, movement, aim, fire, input_sequence)


@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func _input_packet(movement: Vector2, aim: Vector2, fire: bool, sequence: int) -> void:
	if hosting: _accept_input(multiplayer.get_remote_sender_id(), movement, aim, fire, sequence)


func _accept_input(id: int, movement: Vector2, aim: Vector2, fire: bool, sequence: int) -> void:
	if not players.has(id) or phase != "combat" or players[id].hp <= 0: return
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
	peer.refuse_new_connections = true
	room = 1
	run_seed = randi_range(10000, 99999)
	var ids := players.keys()
	players.clear()
	for id in ids: _add_player(id)
	commands.clear()
	_spawn_room()
	print("RUN_STARTED seed=%d players=%d" % [run_seed, players.size()])


func _spawn_room() -> void:
	phase = "combat"
	enemies.clear()
	bullets.clear()
	commands.clear()
	var index := 0
	for id in players:
		var player: Dictionary = players[id]
		player.pos = Vector2(150 + index * 52, 210 + (index % 2) * 50)
		player.ready = false
		player.picked = false
		player.shot_timer = 0.0
		player.invulnerable = 1.0
		if player.hp <= 0: player.hp = maxi(1, int(ceil(player.max_hp * 0.5)))
		index += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + room * 997
	var counts: Array = balance.rooms.enemy_counts
	var boss_room := room == counts.size()
	var count := int(counts[room - 1])
	for i in range(count):
		var boss := boss_room and i == 0
		var definition: Dictionary = balance.boss if boss else balance.enemy
		var hp := int(definition.hp + maxi(0, players.size() - 1) * definition.hp_per_extra_player)
		enemies.append({"pos": Vector2(rng.randf_range(560, 800), rng.randf_range(100, 390)), "hp": hp, "max_hp": hp, "boss": boss, "radius": float(definition.radius), "speed": float(definition.speed), "shot_timer": 1.0})
	print("ROOM_STARTED room=%d enemies=%d boss=%s" % [room, count, boss_room])


func _simulate_players(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for id in players:
		var player: Dictionary = players[id]
		player.shot_timer = maxf(0.0, player.shot_timer - delta)
		player.invulnerable = maxf(0.0, player.invulnerable - delta)
		if player.hp <= 0: continue
		var command: Dictionary = commands.get(id, {})
		if command.is_empty() or now - command.time > float(balance.network.input_timeout): continue
		player.pos += command.move * player.speed * delta
		player.pos = player.pos.clamp(Vector2(32, 32), Vector2(864, 448))
		if command.fire and player.shot_timer <= 0.0:
			player.shot_timer = player.shot_interval
			_add_bullet(player.pos + command.aim * 15.0, command.aim * float(balance.bullet.speed), id, player.damage)


func _add_bullet(position: Vector2, velocity: Vector2, owner: int, damage: float) -> void:
	if bullets.size() >= int(balance.bullet.max_count): return
	bullets.append({"pos": position, "velocity": velocity, "owner": owner, "damage": damage, "life": float(balance.bullet.lifetime) if owner != 0 else 5.0})


func _simulate_enemies(delta: float) -> void:
	for enemy in enemies:
		var target := -1
		var distance := INF
		for id in players:
			if players[id].hp <= 0: continue
			var candidate: float = enemy.pos.distance_squared_to(players[id].pos)
			if candidate < distance:
				distance = candidate
				target = id
		if target < 0: continue
		var direction: Vector2 = (players[target].pos - enemy.pos).normalized()
		enemy.pos += direction * enemy.speed * delta
		if enemy.pos.distance_to(players[target].pos) < enemy.radius + 12.0: _damage_player(target, int(balance.enemy.damage))
		if enemy.boss:
			enemy.shot_timer -= delta
			if enemy.shot_timer <= 0.0:
				enemy.shot_timer = float(balance.boss.shot_interval)
				var count := int(balance.boss.bullet_count)
				for i in range(count):
					var aim := Vector2.RIGHT.rotated(TAU * i / count + Time.get_ticks_msec() * 0.0001)
					_add_bullet(enemy.pos + aim * enemy.radius, aim * float(balance.boss.bullet_speed), 0, float(balance.enemy.damage))


func _simulate_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		bullet.pos += bullet.velocity * delta
		bullet.life -= delta
		var removed: bool = bullet.life <= 0.0 or not Rect2(Vector2.ZERO, WORLD_SIZE).has_point(bullet.pos)
		if not removed and bullet.owner == 0:
			for id in players:
				if players[id].hp > 0 and bullet.pos.distance_to(players[id].pos) < 12.0 + float(balance.bullet.radius):
					_damage_player(id, int(bullet.damage))
					removed = true
					break
		elif not removed:
			for enemy in enemies:
				if enemy.hp > 0 and bullet.pos.distance_to(enemy.pos) < enemy.radius + float(balance.bullet.radius):
					enemy.hp -= bullet.damage
					removed = true
					break
		if removed: bullets.remove_at(i)
	enemies = enemies.filter(func(enemy): return enemy.hp > 0)


func _damage_player(id: int, damage: int) -> void:
	if players[id].invulnerable > 0.0 or players[id].hp <= 0: return
	players[id].hp = maxi(0, players[id].hp - damage)
	players[id].invulnerable = float(balance.player.invulnerability)


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
		phase = "reward"
		perk_options = balance.perks.duplicate(true)
		perk_options.shuffle()
		perk_options = perk_options.slice(0, 3)
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
		if room == balance.rooms.enemy_counts.size():
			phase = "victory"
			print("RUN_COMPLETED players=%d" % players.size())
		else:
			room += 1
			_spawn_room()


func _make_snapshot() -> Dictionary:
	var visible_players := {}
	for id in players:
		var player: Dictionary = players[id]
		visible_players[id] = {"x": player.pos.x, "y": player.pos.y, "hp": player.hp, "max_hp": player.max_hp, "color": player.color, "ready": player.ready, "picked": player.picked, "perks": player.perks.duplicate()}
	var visible_enemies: Array = []
	for enemy in enemies: visible_enemies.append({"x": enemy.pos.x, "y": enemy.pos.y, "hp": enemy.hp, "max_hp": enemy.max_hp, "boss": enemy.boss})
	var visible_bullets: Array = []
	for bullet in bullets: visible_bullets.append({"x": bullet.pos.x, "y": bullet.pos.y, "owner": bullet.owner})
	packet_sequence += 1
	return {"players": visible_players, "enemies": visible_enemies, "bullets": visible_bullets, "room": room, "phase": phase, "seed": run_seed, "seq": packet_sequence, "peer_count": players.size(), "perk_options": perk_options}


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
	phase = snapshot.phase
	room = snapshot.room
	if not seen_snapshot or phase != last_phase:
		print("SNAPSHOT_RECEIVED phase=%s players=%d room=%d" % [phase, snapshot.players.size(), room])
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
	address_input = LineEdit.new()
	address_input.position = Vector2(968, 366)
	address_input.size = Vector2(174, 36)
	address_input.text = "127.0.0.1"
	address_input.placeholder_text = "Host-IP"
	ui.add_child(address_input)
	port_input = LineEdit.new()
	port_input.position = Vector2(1150, 366)
	port_input.size = Vector2(82, 36)
	port_input.text = str(balance.network.port)
	ui.add_child(port_input)
	host_button = _button("HOSTEN", Vector2(968, 418), Vector2(126, 42), _host_session)
	join_button = _button("BEITRETEN", Vector2(1106, 418), Vector2(126, 42), _join_session)
	solo_button = _button("SOLO ERKUNDEN", Vector2(968, 474), Vector2(264, 46), func():
		_host_session()
		if active and hosting: _server_action(1, "start", 0))
	for i in range(3):
		var button := _button("", Vector2(968, 366 + i * 50), Vector2(264, 44), _send_action.bind("perk", i))
		button.add_theme_font_size_override("font_size", 13)
		perk_buttons.append(button)
	action_button = _button("RUN STARTEN", Vector2(968, 538), Vector2(264, 42), _main_action)
	leave_button = _button("LOBBY VERLASSEN", Vector2(968, 589), Vector2(264, 32), _leave_session.bind("Lobby verlassen."))
	_label("WASD  BEWEGEN     MAUS  ZIELEN     LINKE MAUSTASTE  FEUERN", Vector2(32, 656), Vector2(896, 28), 14, Color("8e96ac"))
	_label("01—03  /  EIN GEMEINSAMER LAUF", Vector2(952, 656), Vector2(296, 28), 12, Color("737d94"))


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
	var names := {"menu": "DIE LOBBY", "connecting": "VERBINDEN …", "lobby": "EURE GRUPPE", "combat": "RAUM %02d / 03" % room, "reward": "WÄHLE DEINEN PERK", "dead": "DIE TIEFE SIEGT", "victory": "BOSS BESIEGT"}
	phase_label.text = names.get(phase, phase.to_upper())
	party_label.text = ("Ein kurzer Dungeon-Lauf.\nDrei Räume. Fünf mögliche Perks.\nBis zu %d separate Clients.\n\nDirekte IP benötigt erreichbaren\nUDP-Port; kein Relay enthalten." % maximum_players) if not active else ""
	var index := 1
	for id in visible_players:
		var player: Dictionary = visible_players[id]
		var suffix := " · DU" if int(id) == local_id else ""
		var condition := "BEREIT" if player.ready else "%d/%d LP" % [player.hp, player.max_hp] if player.hp > 0 else "GEFALLEN"
		party_label.text += "SPIELER %02d%s  ·  %s\n" % [index, suffix, condition]
		index += 1
	status_label.text = status_message
	if phase == "combat": status_label.text = "Raum %d · Seed %d · Besiegt alle Gegner und wählt danach euren nächsten Perk." % [room, state.get("seed", 0)]
	elif phase == "reward": status_label.text = "Pro lebendem Spieler genau ein Perk. Danach müssen alle lebenden Spieler bereit sein."
	elif phase == "victory": status_label.text = "Geschafft. Ihr habt alle drei Räume und den Boss besiegt. Der Host kann einen neuen Lauf starten."
	elif phase == "dead": status_label.text = "Alle Wanderer sind gefallen. Der Host kann den Lauf mit einem neuen Seed neu starten."
	for node in [address_input, port_input, host_button, join_button, solo_button]: node.visible = not active
	leave_button.visible = active
	action_button.visible = active
	action_button.disabled = true
	action_button.text = "HOST STARTET" if phase == "lobby" else "RAUM SÄUBERN"
	if phase in ["lobby", "dead", "victory"] and hosting:
		action_button.text = "RUN STARTEN" if phase == "lobby" else "NEUER LAUF"
		action_button.disabled = false
	elif phase == "reward":
		action_button.text = "BEREIT ✓" if local_player.get("ready", false) else "BEREIT FÜR NÄCHSTEN RAUM"
		if room == balance.rooms.enemy_counts.size() and not local_player.get("ready", false): action_button.text = "LAUF ABSCHLIESSEN"
		action_button.disabled = not local_player.get("picked", false) or local_player.get("ready", false) or local_player.get("hp", 0) <= 0
	var options: Array = state.get("perk_options", [])
	for i in range(perk_buttons.size()):
		perk_buttons[i].visible = active and phase == "reward" and i < options.size()
		perk_buttons[i].disabled = local_player.get("picked", false) or local_player.get("hp", 0) <= 0
		if i < options.size(): perk_buttons[i].text = options[i].name + "\n" + options[i].description
