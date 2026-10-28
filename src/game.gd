extends Node2D
## A small host-authoritative development slice. No gameplay objects are accepted from peers.

const DESIGN_SIZE := Vector2(1280, 720)
const WORLD_SIZE := DESIGN_SIZE
const WORLD_OFFSET := Vector2.ZERO
const LOBBY_WORLD_SIZE := Vector2(896,480)
const LOBBY_WORLD_OFFSET := Vector2(32, 156)
const WORLD_ZOOM := Vector2.ONE
const PLAYER_COLORS := [Color("72dcc8"), Color("edb563"), Color("bc91de"), Color("ed8a91")]
const PLAYER_SKINS := ["player_warden", "player_ranger", "player_arcanist", "player_lizard"]
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const RoomPool = preload("res://src/editor/room_pool.gd")
const OpenFloor = preload("res://src/dungeon/open_floor.gd")
const RunHud = preload("res://src/ui/run_hud.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
const LevelCards = preload("res://src/ui/level_cards.gd")
const InventoryPanel = preload("res://src/ui/inventory_panel.gd")
const PauseMenu = preload("res://src/pause_menu.gd")
const RewardOverlay = preload("res://src/reward_overlay.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const RoomTransition = preload("res://src/room_transition.gd")
const RoomCamera = preload("res://src/room_camera.gd")
const SnapshotInterpolator = preload("res://src/snapshot_interpolator.gd")
const SessionProtocol = preload("res://src/session_protocol.gd")
const PerkRules = preload("res://src/perk_rules.gd")
const PerkCombat = preload("res://src/perk_combat.gd")
const CryptEnemyAI = preload("res://src/crypt_enemy_ai.gd")
const MainMenu = preload("res://src/main_menu.gd")
const HellFloorData = preload("res://src/hell/hell_floor_data.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const HeroClass = preload("res://src/player/hero_class.gd")
const TeamProgress = preload("res://src/player/team_progress.gd")
const HeroSkills = preload("res://src/combat/hero_skills.gd")
const Chests = preload("res://src/dungeon/chests.gd")
const Hordes = preload("res://src/dungeon/hordes.gd")
const Aggro = preload("res://src/combat/aggro.gd")
const BodyParts = preload("res://src/combat/body_parts.gd")
const VoidBossAI = preload("res://src/combat/void_boss_ai.gd")
const BossMoves = preload("res://src/combat/boss_moves.gd")
const PlayerEffects = preload("res://src/combat/player_effects.gd")
const Inventory = preload("res://src/items/inventory.gd")

var balance: Dictionary = {}
var dungeon_config: Dictionary = {}
var dungeon_file_path := "res://assets/data/dungeon_rooms.json"
var floor_layouts: Array[Dictionary] = []
var current_layout: Dictionary = {}
var requested_seed := -1
var last_layout_id := ""
var floor_index := 1
var floor_seed := 0
var last_floor_seen := 0
var cleared_room_ids: Array[String] = []
var interact_held := false
var smoke_floor_limit := 2
var state: Dictionary = {}
var players: Dictionary = {}
var commands: Dictionary = {}
var enemies: Array = []
var bullets: Array = []
var perk_options: Array = []
var perk_offers: Dictionary = {}
var perk_combat := PerkCombat.new()
## Shared team EXP, orbs and level-up/boss card choices (host).
var team_progress := TeamProgress.new()
## Hero skills on keys 1-4 (host).
var hero_skills := HeroSkills.new()
## Breakable loot chests and their drops, per room of the floor (host).
var chests := Chests.new()
## Enemy hordes: waves per room until its quota is spent (host).
var hordes := Hordes.new()
## True once this floor's boss or mini-boss fell (opens the stairs on boss floors).
var floor_boss_down := false
## Endless runs play open floors (src/dungeon/open_floor.gd): one map per floor
## with rooms, corridors, chests and sleeping groups. Set by the menu and by
## `--endless`; tests and network smoke runs keep the chain of rooms.
var open_floors := false
## The story being played (assets/data/story_campaigns.json). Only "krypta" is
## playable so far; it runs on dungeon_rooms.json like every room-chain run.
var story_id := "krypta"
var open_floor_data: Dictionary = {}
var _perk_rng := RandomNumberGenerator.new()
var crypt_ai := CryptEnemyAI.new()
## Host-side body parts of rigged enemies (part HP, lost parts, regrowth).
var body_parts := BodyParts.new()
var void_ai := VoidBossAI.new()
## Extra moves of bosses and crypt enemies, and their floor zones (host).
var boss_moves := BossMoves.new()
## Timed conditions on heroes: slow, poison, burn, freeze, slip, blind... (host).
var player_effects := PlayerEffects.new()
## Weapons, potions, crystals and stones of each hero; potion colours of the run (host).
var inventory := Inventory.new()
## Capture tools only: held skill keys and mouse point instead of the real
## keyboard and mouse (-1 / INF = off). Never set in play.
var scripted_skills := -1
var scripted_target := Vector2.INF
var scripted_fire := false
## Mirror-image decoys enemies may chase this step: negative id -> {pos, hp}.
var decoys: Dictionary = {}
## Short-lived host effects for clients (void bursts, slams): id, kind, x, y, r, life.
var fx_events: Array[Dictionary] = []
var _next_fx_id := 1
var peer: ENetMultiplayerPeer
var hosting := false
var session_bind_ip := "*"
var active := false
var phase := "menu"
var room := 1
var run_seed := 0
var run_serial := 0
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
var wait_players := 0
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
## The run HUD (hearts, boss bar, floor and map, skill slots).
var run_hud: Control
## Level-up / boss card choice at the right edge (mouse).
var level_cards: Control
## The hero's inventory window (I / Tab) and the potion slot armed for a throw (-1: none).
var inventory_panel: Control
var throw_slot := -1
var status_label: Label
var session_label: Label
var address_input: LineEdit
var port_input: LineEdit
var host_button: Button
var join_button: Button
var solo_button: Button
var action_button: Button
var leave_button: Button
var lobby_ui: Control
var pause_menu: Control
var pause_open := false
var reward_overlay: Control
var reward_open := false
var menu_button: Button
## Title screen (ported from main). Shown while no session runs and the player
## has not switched to the multiplayer lobby; leaving a session returns to it.
var main_menu: MainMenu
var menu_open := true
var lobby_menu_button: Button
## Host-side hero class per peer id, chosen in the menu (solo) or the lobby.
## Survives run restarts; cleared when the peer leaves or the session ends.
var player_classes: Dictionary = {}
var class_button: Button
var context_hint: Label
var _fire_needs_release := false
var _ui_phase := "menu"
var transition_view: Control
var _transition_state: Dictionary = {}
var _last_transition_state: Dictionary = {}
var _transition_request: Dictionary = {}
var _transition_token := 0
var _next_enemy_id := 1
var _next_bullet_id := 1
var world_clip: Control
## Screen-space camera vignette over the world (balance lighting.vignette).
var vignette: ColorRect
var room_camera := RoomCamera.new()
var _camera_room_id := ""
var _auto_reward_key := ""
signal editor_return_requested
var editor_preview_mode := false
## Dungeon-Werkstatt test play: the room forced into its floor, and whether
## leaving the run reopens the editor.
var test_room_id := ""
var test_room_floor := 0
var return_to_room_editor := false
var _editor_preview_layout: Dictionary = {}
var _editor_preview_notice := ""
# Room geometry is immutable after generation. Only its small revision travels
# with ordinary simulation snapshots; reliable packets seed each client's cache.
var _room_layout_revision := 0
## Counts room entries (not wall breaks), so visual feedback resets per entry only.
var _room_serial := 0
var _sent_layout_by_peer: Dictionary = {}
var _received_layouts: Dictionary = {}
var _received_layout_epoch := ""
var _local_visual_state: Dictionary = {}
var _local_visual_tick := 0
var modal_guard: Control
var _display_size := Vector2.ZERO
var _display_in_run := false
var _windowed_rect := Rect2i()
var _windowed_mode: Window.Mode = Window.MODE_WINDOWED
var _session_identity: Dictionary = {}
var _admitted_peers: Dictionary = {}
var _pending_hello: Dictionary = {}
var _rejected_peers: Dictionary = {}
var _client_admitted := false
var _admission_started_msec := 0
var snapshot_interpolator := SnapshotInterpolator.new()

## Configure before add_child: skip active-library/CLI initialization for one exact room.
func configure_editor_preview(config: Dictionary, layout: Dictionary, notice: String = "") -> void:
	editor_preview_mode = true
	dungeon_config = config.duplicate(true)
	dungeon_config.crypt_procedural = false
	_editor_preview_layout = layout.duplicate(true)
	_editor_preview_notice = notice

## Starts normal solo combat/exploration with an offline peer and no open sockets.
func start_editor_preview() -> void:
	if not editor_preview_mode or _editor_preview_layout.is_empty(): return
	pause_open = false
	reward_open = false
	_ui_phase = "menu"
	_camera_room_id = ""
	_fire_needs_release = true
	input_clock = 0
	snapshot_clock = 0
	ui_clock = 0
	hosting = true
	active = true
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_transition_state.clear()
	_last_transition_state.clear()
	_transition_request.clear()
	transition_view.reset()
	view.reset_feedback()
	players.clear()
	commands.clear()
	action_times.clear()
	packet_sequence = 0
	received_sequence = -1
	_reset_layout_sync()
	seen_snapshot = false
	room = 1
	run_seed = 3
	run_serial += 1
	floor_seed = 3
	floor_index = 1
	perk_options.clear()
	perk_offers.clear()
	_perk_rng.seed = run_seed+65537
	perk_combat.reset()
	last_floor_seen = 0
	last_layout_id = ""
	_auto_reward_key = ""
	cleared_room_ids.clear()
	floor_layouts = [_editor_preview_layout.duplicate(true)]
	_add_player(1)
	_spawn_room()
	status_message = "Einzelraum-Vorschau · "+_editor_preview_notice
	_broadcast_state(true)
	_refresh_ui()



func _ready() -> void:
	var launch_args := OS.get_cmdline_user_args()
	for index in range(launch_args.size()-1):
		if launch_args[index] == "--dungeon" and launch_args[index+1].begins_with("res://assets/data/") and launch_args[index+1].ends_with(".json"):
			dungeon_file_path = launch_args[index+1]
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	if not parsed is Dictionary:
		push_error("Missing or invalid src/data/balance.json")
		get_tree().quit(1)
		return
	balance = parsed
	perk_combat.bind(self)
	team_progress.bind(self)
	hero_skills.bind(self)
	chests.bind(self)
	hordes.bind(self)
	crypt_ai.bind(self)
	void_ai.bind(self)
	boss_moves.bind(self)
	player_effects.bind(self)
	inventory.bind(self)
	if not snapshot_interpolator.configure(balance.get("network",{})):
		push_error("Invalid network presentation settings in src/data/balance.json")
		get_tree().quit(1)
		return
	snapshot_interpolator.set_motion_validator(_presentation_motion_is_clear)
	if not editor_preview_mode:
		var room_data = JSON.parse_string(FileAccess.get_file_as_string(dungeon_file_path))
		if not room_data is Dictionary or not Dungeon.validate_config(room_data).is_empty():
			push_error("Missing or invalid dungeon: "+dungeon_file_path)
			get_tree().quit(1)
			return
		dungeon_config = room_data
	if dungeon_config.has("campaign_title"):
		var title_suffix := " · Raumvorschau" if editor_preview_mode else " · Vorschau" if dungeon_file_path != "res://assets/data/dungeon_rooms.json" else ""
		get_window().title = CryptUI.GAME_TITLE+title_suffix
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
	view.show_player_health = false
	# Live runs: 0x72 crypt rooms and the dark crypt (balance.json "lighting").
	view.lighting = balance.get("lighting",{})
	view._skill_fx.balance = balance
	view.crypt_0x72_enabled = not editor_preview_mode
	world_clip = Control.new()
	world_clip.position = WORLD_OFFSET
	world_clip.size = WORLD_SIZE
	world_clip.clip_contents = true
	world_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world_clip)
	view.scale = WORLD_ZOOM
	world_clip.add_child(view)
	# Camera vignette over the world (not the HUD): only the view edges darken.
	vignette = ColorRect.new()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = preload("res://assets/shaders/canvas_post_vignette.gdshader")
	var vignette_settings: Dictionary = balance.get("lighting",{}).get("vignette",{})
	for key: String in ["strength","inner","outer"]:
		if vignette_settings.has(key): vignette_material.set_shader_parameter(key,float(vignette_settings[key]))
	vignette.material = vignette_material
	vignette.visible = false
	world_clip.add_child(vignette)
	view.set_audio_enabled(true)
	_build_ui()
	# Every button in the menus, lobby and pause screen clicks (assets/data/audio_sfx.json).
	for node: Node in find_children("*", "BaseButton", true, false): _hook_button_sound(node)
	get_tree().node_added.connect(_on_node_added)
	var transition_layer := CanvasLayer.new()
	transition_layer.layer = 100
	add_child(transition_layer)
	transition_view = RoomTransition.new()
	transition_layer.add_child(transition_view)
	transition_view.configure(balance.transition)
	transition_view.sound_requested.connect(view.play_transition_sound)
	get_viewport().size_changed.connect(_apply_display_layout)
	_apply_display_layout(true)
	if not editor_preview_mode: _read_arguments()
	# Command-line sessions (smoke tests) and the editor preview skip the menu.
	if editor_preview_mode or active: menu_open = false
	else: _apply_menu_settings(main_menu.settings)
	_refresh_ui()
	queue_redraw()


func _draw() -> void:
	draw_rect(get_viewport_rect(), CryptUI.INK)
	if _in_run(): return
	var origin := ((get_viewport_rect().size-DESIGN_SIZE)*0.5).floor()
	CryptUI.draw_box(self,"panel",Rect2(origin+Vector2(24,18),Vector2(1232,74)))
	CryptUI.draw_box(self,"inset",Rect2(origin+LOBBY_WORLD_OFFSET-Vector2(8,8),LOBBY_WORLD_SIZE+Vector2(16,16)))


func _in_run() -> bool:
	return active and phase in ["combat","reward","explore","dead","victory"]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.alt_pressed and event.keycode in [KEY_ENTER,KEY_KP_ENTER]):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
	# I or Tab opens the inventory; ESC first cancels a throw or closes it.
	if _in_run() and not pause_open and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_I, KEY_TAB] and inventory_panel != null:
		inventory_panel.set_open(not inventory_panel.open)
		get_viewport().set_input_as_handled()
		return
	if _in_run() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and inventory_panel != null and (throw_slot >= 0 or inventory_panel.open):
		throw_slot = -1
		inventory_panel.set_open(false)
		get_viewport().set_input_as_handled()
		return
	if _in_run() and not is_transitioning() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_pause_open(not pause_open,"reward" if phase == "reward" else "overview")
		get_viewport().set_input_as_handled()


## Local display mode only. Restores the prior window rectangle/maximized mode.
func toggle_fullscreen() -> void:
	var window := get_window()
	if is_fullscreen():
		window.mode = Window.MODE_WINDOWED
		if _windowed_mode == Window.MODE_MAXIMIZED:
			window.mode = Window.MODE_MAXIMIZED
		elif _windowed_rect.has_area():
			window.size = _windowed_rect.size
			window.position = _windowed_rect.position
	else:
		_windowed_mode = window.mode
		_windowed_rect = Rect2i(window.position,window.size)
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	if is_instance_valid(main_menu): main_menu.set_fullscreen_checked(is_fullscreen())
	_fire_needs_release = true
	_apply_display_layout(true)
	_refresh_ui()


## Both fullscreen modes count as fullscreen if the engine/OS selects one.
func is_fullscreen() -> bool:
	return get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]


## Uses the whole visible canvas for play; fixed menu compositions stay centered.
func _apply_display_layout(force: bool = false) -> void:
	if not is_instance_valid(ui) or not is_instance_valid(world_clip): return
	var dimensions := get_viewport_rect().size
	var in_run := _in_run()
	if not force and dimensions == _display_size and in_run == _display_in_run: return
	_display_size = dimensions
	_display_in_run = in_run
	var origin := ((dimensions-DESIGN_SIZE)*0.5).floor()
	ui.size = dimensions
	lobby_ui.position = origin
	lobby_ui.size = DESIGN_SIZE
	world_clip.position = WORLD_OFFSET if in_run else origin+LOBBY_WORLD_OFFSET
	world_clip.size = dimensions if in_run else LOBBY_WORLD_SIZE
	run_hud.position = Vector2.ZERO
	run_hud.size = dimensions
	var map_panel: Rect2 = run_hud.map_panel_rect()
	menu_button.size = Vector2(map_panel.size.x,36)
	menu_button.position = Vector2(map_panel.position.x,map_panel.end.y+8)
	level_cards.position = Vector2(dimensions.x-level_cards.size.x-20,menu_button.position.y+menu_button.size.y+12)
	var hint_height := 72.0 if editor_preview_mode else 30.0
	context_hint.position = Vector2(24,run_hud.skill_bar_top()-hint_height-10)
	context_hint.size = Vector2(dimensions.x-48,hint_height)
	modal_guard.size = dimensions
	pause_menu.position = origin
	reward_overlay.position = origin
	pause_menu.set_canvas_size(dimensions,origin)
	reward_overlay.set_canvas_size(dimensions,origin)
	if is_instance_valid(main_menu): main_menu.set_canvas_size(dimensions,origin)
	pause_menu.set_display_state(is_fullscreen(),dimensions)
	_camera_room_id = ""
	_update_camera(0)
	queue_redraw()


## Opens a local information menu. Solo freezes simulation; peers keep polling.
func set_pause_open(open: bool, section: String = "overview") -> void:
	if open and is_transitioning(): return
	pause_open = open and _in_run()
	reward_open = pause_open and section == "reward"
	_fire_needs_release = true
	if pause_open:
		if not reward_open: pause_menu.select_section(section)
		_send_local_input()
	else:
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null: focus.release_focus()
	_refresh_ui()
	if pause_open:
		if reward_open: reward_overlay.focus_initial()
		else: pause_menu.resume_button.grab_focus()


## Shows rewards independently of the opaque information/pause menu.
func show_rewards() -> void:
	set_pause_open(true,"reward")


## A local menu may never freeze another participant's authoritative world.
func is_solo_paused() -> bool:
	return pause_open and hosting and players.size() == 1 and _in_run()


## Input stays neutral until both the host handoff and local fade are complete.
func is_transitioning() -> bool:
	return not _transition_state.is_empty() or state.get("transition",{}).get("active",false) or (transition_view != null and transition_view.is_active())


func _read_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	var address := ""
	var should_host := false
	for i in range(args.size()):
		match args[i]:
			"--host": should_host = true
			# Dungeon-Editor.cmd: straight into the Dungeon-Werkstatt.
			"--werkstatt": if is_instance_valid(main_menu): main_menu.open_room_editor.call_deferred("")
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
			"--endless": open_floors = true
			"--smoke-floors":
				if i + 1 < args.size(): smoke_floor_limit = clampi(args[i + 1].to_int(), 1, 3)
			"--wait-players":
				if i + 1 < args.size(): wait_players = clampi(args[i + 1].to_int(), 1, 4)
	# Network smoke runs keep single encounters, so bots finish rooms quickly.
	if not smoke_role.is_empty(): hordes.enabled = false
	if should_host:
		_host_session()
	elif not address.is_empty():
		address_input.text = address
		_join_session()


func _process(delta: float) -> void:
	_poll_session_admission()
	snapshot_interpolator.advance(delta)
	var elapsed := Time.get_ticks_msec() / 1000.0 - launched_at
	if auto_exit > 0.0 and elapsed >= auto_exit:
		print("AUTO_EXIT phase=%s PLAYER_COUNT=%d" % [phase, state.get("players", {}).size()])
		get_tree().quit()
		return
	if active and hosting and auto_start and phase == "lobby" and elapsed > 2.0:
		if (wait_players > 0 and players.size() >= wait_players) or (wait_players == 0 and (players.size() >= 2 or elapsed > 4.0)):
			_server_action(1, "start", 0)
	var interact_pressed := Input.is_physical_key_pressed(KEY_E)
	if interact_pressed and not interact_held and active and not pause_open and not is_transitioning(): _send_action("interact")
	interact_held = interact_pressed
	ui_clock += delta
	if ui_clock >= 0.1:
		ui_clock = 0.0
		_refresh_ui()
		if not pause_open and not smoke_role.is_empty() and active and phase == "reward":
			var local_player: Dictionary = state.get("players", {}).get(multiplayer.get_unique_id(), {})
			if not local_player.is_empty() and local_player.get("hp", 0) > 0:
				if not local_player.get("picked", false): _send_action("perk", 0)
				elif not local_player.get("ready", false): _send_action("ready")
		if not pause_open and not smoke_role.is_empty() and active and phase == "explore":
			_smoke_interact()
	transition_view.update(delta)
	# HUD corners fade while the local hero stands near them.
	if run_hud != null and run_hud.visible:
		var me: Dictionary = state.get("players", {}).get(multiplayer.get_unique_id() if active else 1, {})
		var to_screen := view.get_global_transform_with_canvas()
		var gates: Array = []
		for exit: Dictionary in state.get("room_layout", {}).get("exits", []):
			var rect: Array = exit.rect
			gates.append(to_screen * Vector2(float(rect[0]) + 16.0, float(rect[1]) - 32.0))
		run_hud.set_focus(to_screen * Vector2(float(me.get("x", 0)), float(me.get("y", 0))) if not me.is_empty() else Vector2.INF, gates)
		menu_button.modulate.a = run_hud.right_alpha()
	view.darkness_enabled = active and not editor_preview_mode and phase in ["combat","explore","reward","dead"]
	if vignette != null:
		vignette.visible = view.darkness_enabled
		vignette.size = world_clip.size
		vignette.material.set_shader_parameter("aspect",world_clip.size.x/maxf(1.0,world_clip.size.y))
	if not state.is_empty(): view.set_state(_presentation_state(), multiplayer.get_unique_id() if active else 0)
	_update_camera(delta)


func _presentation_state() -> Dictionary:
	var shown: Dictionary = transition_view.display_state()
	if active and not hosting:
		return snapshot_interpolator.sample(shown,is_transitioning())
	if not active or not hosting or _local_visual_state.is_empty() or is_transitioning(): return shown
	# Never reveal live geometry/entities ahead of the transition's black fence.
	if int(shown.get("room_layout_revision",-1)) != _room_layout_revision: return shown
	if str(shown.get("room_layout",{}).get("id","")) != str(current_layout.get("id","")): return shown
	if int(_local_visual_state.get("seq",-1)) < int(shown.get("seq",-1)): return shown
	return _local_visual_state


## Validate a new visual movement pair once, never sweep every rendered frame.
## A wall-cutting interpolation chord snaps; authoritative movement is untouched.
func _presentation_motion_is_clear(from: Vector2, to: Vector2, entity: Dictionary, layout: Dictionary) -> bool:
	return not Dungeon.segment_blocked(from,to,maxf(0.0,float(entity.get("radius",0.0))),layout)


func _refresh_local_visual_state() -> void:
	if not _in_run() or is_transitioning():
		_local_visual_state = {}
		return
	if is_solo_paused(): return
	_local_visual_tick += 1
	_local_visual_state = _make_snapshot(false)
	_local_visual_state.local_visual_tick = _local_visual_tick


func _update_camera(delta: float) -> void:
	if not _in_run():
		_camera_room_id = ""
		view.set_world_origin(Vector2.ZERO)
		return
	var shown := _presentation_state()
	var layout: Dictionary = shown.get("room_layout",{})
	if layout.is_empty(): return
	var world := Vector2(layout.world_size[0],layout.world_size[1])
	var local_id := multiplayer.get_unique_id() if active else 0
	var player: Dictionary = shown.get("players",{}).get(local_id,{})
	if player.is_empty(): return
	var point := Vector2(player.x,player.y)
	# Zoomed camera (balance camera.zoom): the room camera works in world pixels
	# of the visible area; the view scales them up (2x art becomes 3x at 1.5).
	var zoom: float = maxf(1.0,float(balance.get("camera",{}).get("zoom",1.0)))
	view.scale = Vector2(zoom,zoom)
	var visible: Vector2 = world_clip.size/zoom
	if _camera_room_id != str(layout.id):
		_camera_room_id = str(layout.id)
		room_camera.reset(point,world,visible)
	var mouse_delta := (get_global_mouse_position()-view.to_global(point))/zoom
	var frozen: bool = pause_open or is_transitioning() or player.get("hp",0) <= 0
	view.set_world_origin((room_camera.update(point,mouse_delta,world,visible,delta,balance.get("camera",{}),frozen)*zoom).round())


func _physics_process(delta: float) -> void:
	if not active: return
	input_clock += delta
	if phase in ["combat", "reward", "explore"] and input_clock >= 1.0 / float(balance.network.input_hz):
		input_clock = 0.0
		_send_local_input()
	if not hosting: return
	if membership_dirty:
		membership_dirty = false
		_broadcast_state(true)
	var handoff_active := not _transition_state.is_empty()
	_step_transition(delta)
	if not is_solo_paused() and not handoff_active and _transition_state.is_empty(): _step_world(delta)
	snapshot_clock += delta
	if snapshot_clock >= 1.0 / float(balance.network.snapshot_hz):
		snapshot_clock = 0.0
		_broadcast_state(false)
	_refresh_local_visual_state()


func _step_world(delta: float) -> void:
	perk_combat.step_events(delta)
	# Short effect events age in every phase (wall hits happen outside fights too).
	for event: Dictionary in fx_events: event.life = float(event.life)-delta
	fx_events = fx_events.filter(func(event: Dictionary) -> bool: return float(event.life) > 0.0)
	if phase in ["combat", "reward", "explore"]:
		_simulate_players(delta)
		hero_skills.step(delta)
		team_progress.step(delta)
		chests.step(delta)
		player_effects.step(delta)
		inventory.step(delta)
	if phase in ["combat", "explore"]:
		boss_moves.update(delta)
	if phase == "combat":
		hordes.step(delta)
		_simulate_enemies(delta)
	if phase in ["combat", "explore"]:
		_simulate_bullets(delta)
	if phase == "combat":
		_check_room_end()


func _port() -> int:
	if not port_input.text.is_valid_int(): return 0
	var value := port_input.text.to_int()
	return value if value > 1023 and value <= 65535 else 0


func _host_session() -> void:
	if active: return
	var identity := _build_session_identity()
	if identity.is_empty():
		status_message = "Spielversion konnte nicht bestimmt werden. Projektdateien prüfen."
		return
	var port := _port()
	if port == 0:
		status_message = "Port muss zwischen 1024 und 65535 liegen."
		return
	peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(session_bind_ip)
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
	_reset_layout_sync()
	_reset_session_admission()
	_session_identity = identity
	_admitted_peers[1] = true
	seen_snapshot = false
	floor_layouts.clear()
	current_layout = {}
	cleared_room_ids.clear()
	floor_index = 1
	last_floor_seen = 0
	last_layout_id = ""
	multiplayer.multiplayer_peer = peer
	_add_player(1)
	status_message = "Lobby offen · UDP %d · Host + bis zu %d Freunde. Der Host startet." % [port, int(balance.network.max_players) - 1]
	print("SESSION_HOSTED port=%d max_players=%d" % [port, balance.network.max_players])
	_broadcast_state(true)


func _join_session() -> void:
	if active: return
	var identity := _build_session_identity()
	if identity.is_empty():
		status_message = "Spielversion konnte nicht bestimmt werden. Projektdateien prüfen."
		return
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
	_reset_layout_sync()
	_reset_session_admission()
	_session_identity = identity
	_admission_started_msec = Time.get_ticks_msec()
	seen_snapshot = false
	state = {}
	last_layout_id = ""
	last_floor_seen = 0
	multiplayer.multiplayer_peer = peer
	status_message = "Verbinde mit %s:%d …" % [address, _port()]


func _connected() -> void:
	if not active or hosting: return
	print("CLIENT_CONNECTED peer=%d" % multiplayer.get_unique_id())
	_admission_started_msec = Time.get_ticks_msec()
	status_message = "Verbunden. Prüfe Spielversion und Raumdaten …"
	_session_hello.rpc_id(1,SessionProtocol.encode(_session_identity))


func _connection_failed() -> void:
	if not active: return
	print("CONNECTION_FAILED")
	_leave_session("Verbindung fehlgeschlagen: Host-IP, Port, Firewall und freie Lobby prüfen.")


func _server_lost() -> void:
	if not active: return
	print("SERVER_DISCONNECTED")
	_leave_session("Die Verbindung zum Host wurde beendet. Der Lauf ist vorbei; erneut verbinden.")


## Information menu returns to the authoring tool for a local preview.
func _leave_or_return() -> void:
	if editor_preview_mode: editor_return_requested.emit()
	else: _leave_session()


func _leave_session(message: String = "Verbindung beendet.") -> void:
	pause_open = false
	reward_open = false
	_transition_state.clear()
	_last_transition_state.clear()
	_transition_request.clear()
	transition_view.reset()
	view.reset_feedback()
	active = false
	hosting = false
	if peer != null: peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	player_classes.clear()
	perk_options.clear()
	perk_offers.clear()
	perk_combat.reset()
	commands.clear()
	state = {}
	enemies.clear()
	bullets.clear()
	floor_layouts.clear()
	current_layout = {}
	_reset_layout_sync()
	_reset_session_admission()
	cleared_room_ids.clear()
	last_layout_id = ""
	last_floor_seen = 0
	phase = "menu"
	# Every ended session (solo or multiplayer) returns to the main menu.
	menu_open = true
	status_message = message
	view.set_state({}, 0)
	_refresh_ui()
	# A test run from the Dungeon-Werkstatt goes back to the room it tested.
	if return_to_room_editor and is_instance_valid(main_menu):
		return_to_room_editor = false
		main_menu.open_room_editor.call_deferred(test_room_id)
	test_room_id = ""
	test_room_floor = 0


func _peer_connected(id: int) -> void:
	if not hosting: return
	_sent_layout_by_peer.erase(id)
	if phase != "lobby" or players.size() >= int(balance.network.max_players):
		_reject_session_peer(id,"Die Lobby ist geschlossen oder bereits voll.")
		return
	# A transport connection has no gameplay membership until compatibility passes.
	_pending_hello[id] = Time.get_ticks_msec()+_admission_timeout_msec()
	print("PEER_PENDING peer=%d" % id)


func _peer_disconnected(id: int) -> void:
	if not hosting: return
	_sent_layout_by_peer.erase(id)
	_pending_hello.erase(id)
	_rejected_peers.erase(id)
	_admitted_peers.erase(id)
	perk_offers.erase(id)
	player_classes.erase(id)
	if not players.has(id): return
	players.erase(id)
	commands.erase(id)
	action_times.erase(id)
	print("PEER_LEFT peer=%d count=%d" % [id, players.size()])
	if phase == "reward": _advance_if_ready()
	# Several peers may close in the same network poll; send after all disconnect signals.
	membership_dirty = true


## Stable compatibility identity: loaded JSON only, so exports need no source files.
func _build_session_identity() -> Dictionary:
	var engine := Engine.get_version_info()
	var engine_version := "%d.%d.%d" % [engine.major,engine.minor,engine.patch]
	return SessionProtocol.manifest(balance,dungeon_config,Dungeon.GENERATOR_VERSION,engine_version)


func _reset_session_admission() -> void:
	_session_identity = {}
	_admitted_peers.clear()
	_pending_hello.clear()
	_rejected_peers.clear()
	_client_admitted = false
	_admission_started_msec = 0


func _admission_timeout_msec() -> int:
	return int(maxf(1.0,float(balance.network.get("admission_timeout",8.0)))*1000)


func _poll_session_admission() -> void:
	if not active: return
	var now := Time.get_ticks_msec()
	if not hosting:
		if not _client_admitted and now-_admission_started_msec >= _admission_timeout_msec():
			_leave_session("Verbindung oder Versionsprüfung dauerte zu lange. Host und Spielstand prüfen.")
		return
	for id: int in _pending_hello.keys():
		if now >= int(_pending_hello[id]): _reject_session_peer(id,"Versionsprüfung dauerte zu lange. Bitte denselben Spielstand verwenden.")
	for id: int in _rejected_peers.keys():
		if now < int(_rejected_peers[id]): continue
		_rejected_peers.erase(id)
		var transport := peer.get_peer(id)
		if transport != null and transport.get_state() == ENetPacketPeer.STATE_CONNECTED: peer.disconnect_peer(id)


func _session_result_payload(accepted: bool, message: String) -> PackedByteArray:
	return JSON.stringify({"accepted":accepted,"message":message,"manifest":_session_identity},"",true).to_utf8_buffer()


func _reject_session_peer(id: int, message: String) -> void:
	_pending_hello.erase(id)
	if _rejected_peers.has(id): return
	var transport := peer.get_peer(id)
	if transport == null or transport.get_state() != ENetPacketPeer.STATE_CONNECTED: return
	_session_result.rpc_id(id,_session_result_payload(false,message))
	var grace := maxf(0.05,float(balance.network.get("admission_reject_grace",0.3)))
	_rejected_peers[id] = Time.get_ticks_msec()+int(grace*1000)
	print("SESSION_REJECTED peer=%d reason=%s" % [id,message])


@rpc("any_peer", "call_remote", "reliable", 1)
func _session_hello(payload: PackedByteArray) -> void:
	if not active or not hosting: return
	var id := multiplayer.get_remote_sender_id()
	if not _pending_hello.has(id): return
	var message := SessionProtocol.rejection(_session_identity,SessionProtocol.decode(payload))
	if phase != "lobby" or players.size() >= int(balance.network.max_players): message = "Die Lobby ist geschlossen oder bereits voll."
	if not message.is_empty():
		_reject_session_peer(id,message)
		return
	_pending_hello.erase(id)
	_admitted_peers[id] = true
	_add_player(id)
	_session_result.rpc_id(id,_session_result_payload(true,"Spielversion und Daten stimmen überein."))
	print("SESSION_ADMITTED peer=%d protocol=%d rules=%d count=%d" % [id,SessionProtocol.PROTOCOL_VERSION,SessionProtocol.RULESET_VERSION,players.size()])
	print("PEER_JOINED peer=%d count=%d" % [id,players.size()])
	_broadcast_state(true)


@rpc("authority", "call_remote", "reliable", 1)
func _session_result(payload: PackedByteArray) -> void:
	if not active or hosting or _client_admitted or multiplayer.get_remote_sender_id() != 1: return
	if payload.is_empty() or payload.size() > 1024: return
	var parser := JSON.new()
	if parser.parse(payload.get_string_from_utf8()) != OK: return
	var result: Variant = parser.data
	if not result is Dictionary or result.size() != 3 or not result.has_all(["accepted","message","manifest"]): return
	if not result.accepted is bool or not result.message is String or result.message.length() > 256 or not result.manifest is Dictionary: return
	if not result.accepted:
		_leave_session("Beitritt abgelehnt: "+result.message)
		return
	var mismatch := SessionProtocol.rejection(_session_identity,result.manifest)
	if not mismatch.is_empty():
		_leave_session("Beitritt abgelehnt: "+mismatch)
		return
	_client_admitted = true
	status_message = "Spielversion geprüft. Warte auf den Start durch den Host."
	print("SESSION_COMPATIBLE protocol=%d rules=%d" % [SessionProtocol.PROTOCOL_VERSION,SessionProtocol.RULESET_VERSION])


func _add_player(id: int) -> void:
	var index := players.size()
	var occupied: Dictionary = {}
	for member: Dictionary in players.values(): occupied[member.color] = true
	var color: Color = PLAYER_COLORS[0]
	for candidate: Color in PLAYER_COLORS:
		if not occupied.has(candidate):
			color = candidate
			break
	players[id] = {"pos": Vector2(150 + index * 52, 210 + (index % 2) * 50), "hp": int(balance.player.hp), "max_hp": int(balance.player.hp), "color": color, "ready": false, "picked": false, "perks": [], "damage": float(balance.player.damage), "speed": float(balance.player.speed), "shot_interval": float(balance.player.shot_interval), "shot_timer": 0.0, "invulnerable": 0.0, "hitstun": 0.0, "hit_flash": 0.0, "knockback": Vector2.ZERO,"shots":0,"hurts":0,"moving":false,"aim":Vector2.RIGHT,"face":1.0}
	players[id].merge({"skin":PLAYER_SKINS[PLAYER_COLORS.find(color)],"motion":Vector2.ZERO,"blocks":0,"interacts":0,"hit_direction":Vector2.ZERO,"last_hit_damage":0})
	PerkRules.initialize_player(players[id],balance)
	HeroClass.apply(players[id],str(player_classes.get(id,"")),balance)
	inventory.start_kit(players[id])
	perk_combat.bind(self)


func _send_local_input() -> void:
	var local_player: Dictionary = state.get("players", {}).get(multiplayer.get_unique_id(), {})
	if local_player.is_empty() or local_player.get("hp", 0) <= 0: return
	if pause_open or is_transitioning():
		if hosting and commands.has(1):
			commands[1].move = Vector2.ZERO
			commands[1].fire = false
		input_sequence += 1
		if hosting: _accept_input(1,Vector2.ZERO,Vector2.RIGHT,false,input_sequence,0)
		elif peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED: _input_packet.rpc_id(1,Vector2.ZERO,Vector2.RIGHT,false,input_sequence)
		return
	var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length()
	var position := Vector2(local_player.x, local_player.y)
	var mouse := view.to_local(get_global_mouse_position())
	if scripted_target.is_finite(): mouse = scripted_target
	var aim := (mouse - position).normalized()
	var mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not mouse_pressed: _fire_needs_release = false
	# Buttons now sit above the full-world view. A click on any interactive UI
	# (including the editor-return button) must not leak into combat fire.
	if mouse_pressed and get_viewport().gui_get_hovered_control() != null:
		_fire_needs_release = true
	var dimensions: Array = state.get("room_layout",{}).get("world_size",[896,480])
	var fire := mouse_pressed and not _fire_needs_release and Rect2(Vector2.ZERO,Vector2(dimensions[0],dimensions[1])).has_point(mouse) and world_clip.get_global_rect().has_point(get_global_mouse_position())
	# An armed potion goes where the next click lands, instead of an attack.
	if throw_slot >= 0 and fire:
		_send_action("inv_throw", throw_slot)
		throw_slot = -1
		fire = false
		_fire_needs_release = true
	var live_targets: Array = state.get("enemies",[]).filter(func(enemy: Dictionary): return enemy.get("hp",0) > 0)
	if not smoke_role.is_empty() and not live_targets.is_empty():
		var nearest := Vector2.ZERO
		var distance := INF
		for enemy in live_targets:
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
				var path := Dungeon.find_path(position, nearest, float(balance.player.radius), layout)
				movement = (path[0] - position).normalized() if not path.is_empty() else Vector2.ZERO
			elif Dungeon.segment_blocked(position, position + movement * 16.0, float(balance.player.radius), layout):
				movement = Vector2.ZERO
		fire = true
	elif not smoke_role.is_empty():
		movement = Vector2.ZERO
		fire = false
		var exit := _smoke_exit()
		if phase == "explore" and not exit.is_empty():
			var destination := _exit_center(exit)
			if position.distance_to(destination) > 10.0:
				var path := Dungeon.find_path(position, destination, float(balance.player.radius), state.get("room_layout", {}))
				if not path.is_empty(): movement = (path[0] - position).normalized()
	# Keys 1-4 as a bitmask, and the mouse point in world pixels (skill targets).
	var skill_keys := 0
	for index in range(4):
		if Input.is_physical_key_pressed(KEY_1 + index): skill_keys |= 1 << index
	if not smoke_role.is_empty(): skill_keys = 0
	if scripted_skills >= 0: skill_keys = scripted_skills
	if scripted_fire:
		fire = true
		aim = (mouse - position).normalized()
	input_sequence += 1
	if hosting: _accept_input(1, movement, aim, fire, input_sequence, skill_keys, mouse)
	else: _input_packet.rpc_id(1, movement, aim, fire, input_sequence, skill_keys, mouse)


func _smoke_exit() -> Dictionary:
	var visible_room := int(state.get("room", room))
	for exit: Dictionary in state.get("room_layout", {}).get("exits", []):
		if exit.kind == "door" and int(exit.target_room) > visible_room: return exit
		if exit.kind == "stairs" and int(state.get("floor_index", 1)) < smoke_floor_limit: return exit
	return {}


func _smoke_interact() -> void:
	var exit := _smoke_exit()
	var player: Dictionary = state.get("players", {}).get(multiplayer.get_unique_id(), {})
	if exit.is_empty() or player.is_empty() or player.hp <= 0: return
	if Vector2(player.x, player.y).distance_to(_exit_center(exit)) <= float(balance.exploration.interaction_radius):
		_send_action("interact")


func _exit_center(exit: Dictionary) -> Vector2:
	var rect: Array = exit.rect
	return Vector2(float(rect[0]) + float(rect[2]) * 0.5, float(rect[1]) + float(rect[3]) * 0.5)


@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func _input_packet(movement: Vector2, aim: Vector2, fire: bool, sequence: int, skill_keys: int = 0, target: Vector2 = Vector2.INF) -> void:
	var id := multiplayer.get_remote_sender_id()
	if hosting and _admitted_peers.has(id): _accept_input(id, movement, aim, fire, sequence, skill_keys, target)


func _accept_input(id: int, movement: Vector2, aim: Vector2, fire: bool, sequence: int, skill_keys: int = 0, target: Vector2 = Vector2.INF) -> void:
	if not players.has(id) or phase not in ["combat", "reward", "explore"] or players[id].hp <= 0: return
	if not movement.is_finite() or not aim.is_finite() or sequence < 0: return
	var now := Time.get_ticks_msec() / 1000.0
	var previous: Dictionary = commands.get(id, {})
	if sequence <= int(previous.get("sequence", -1)) or now - float(previous.get("time", -1.0)) < 0.025: return
	commands[id] = {"move": movement.limit_length(), "aim": aim.normalized() if aim.length_squared() > 0.0001 else Vector2.RIGHT, "fire": fire, "sequence": sequence, "time": now, "skills": clampi(skill_keys, 0, 15)}
	if target.is_finite(): commands[id].target = target


func _send_action(action: String, value: int = 0) -> void:
	if not active: return
	if (pause_open or is_transitioning()) and action == "interact": return
	if hosting: _server_action(1, action, value)
	elif _client_admitted and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED: _action_packet.rpc_id(1, action, value)


@rpc("any_peer", "call_remote", "reliable", 2)
func _action_packet(action: String, value: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if hosting and _admitted_peers.has(id): _server_action(id, action, value)


func _server_action(id: int, action: String, value: int) -> void:
	if not players.has(id): return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(action_times.get(id, -1.0)) < 0.08: return
	action_times[id] = now
	if action == "start" and id == 1 and phase in ["lobby", "dead", "victory"]:
		_begin_run()
	elif action == "perk" and phase == "reward" and players[id].hp > 0 and not players[id].picked:
		var offered: Array = perk_offers.get(id,perk_options)
		if value < 0 or value >= offered.size(): return
		if not _grant_perk(id,offered[value]): return
	elif action == "ready" and phase == "reward" and players[id].hp > 0 and players[id].picked:
		players[id].ready = true
		_advance_if_ready()
	elif action == "interact" and phase in ["explore", "combat"]:
		# E opens a chest within reach (also mid-fight); otherwise it takes a gate.
		if players.has(id) and chests.interact(id): return
		if phase == "explore": _use_exit(id)
	elif action.begins_with("inv_") and phase in ["combat", "explore", "reward"]:
		inventory.act(id, action, value, Vector2(commands.get(id, {}).get("target", Vector2.INF)))
	elif action == "card" and phase in ["combat", "explore", "reward"]:
		# Level-up or boss card, picked by mouse while the game runs.
		if not team_progress.pick(players[id], value): return
		print("CARD_PICKED peer=%d card=%s level=%d" % [id, str(players[id].get("last_card","")), int(team_progress.team.level)])
	elif action == "class" and phase == "lobby":
		# Each peer picks only its own class, by index into balance.class_order.
		var order: Array = balance.get("class_order", [])
		if value < 0 or value >= order.size(): return
		player_classes[id] = str(order[value])
		HeroClass.apply(players[id], player_classes[id], balance)
		inventory.start_kit(players[id])
	else: return
	_broadcast_state(true)


## Candidate campaigns choose their own room count without changing the original balance.
func _run_room_count() -> int:
	if dungeon_config.has("room_order"): return dungeon_config.room_order.size()
	return clampi(int(dungeon_config.get("campaign_room_count",balance.rooms.enemy_counts.size())),Dungeon.MIN_ROOMS,Dungeon.MAX_ROOMS)


## Host-only seeded spawn placement: clear cells, spaced enemies and safe arrival zone.
func _crypt_enemy_positions(rng: RandomNumberGenerator, count: int, encounter: Dictionary) -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	var picked: Array[Vector2] = []
	var minimum := float(encounter.get("spawn_min_distance",288))
	var spacing := float(encounter.get("enemy_spacing",80))
	var dimensions: Array = current_layout.world_size
	for y in range(2,int(dimensions[1]/32)-2,2):
		for x in range(2,int(dimensions[0]/32)-2,2):
			var point := Vector2(x*32,y*32)
			if Dungeon.segment_blocked(point,point,float(balance.boss.radius),current_layout): continue
			var arrival_safe := true
			for player: Dictionary in players.values():
				if point.distance_to(player.pos) < minimum: arrival_safe = false
			for exit: Dictionary in current_layout.exits:
				if point.distance_to(_exit_center(exit)) < minimum*0.5: arrival_safe = false
			if arrival_safe: candidates.append(point)
	for index in range(candidates.size()-1,0,-1):
		var other := rng.randi_range(0,index)
		var swap := candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = swap
	for point: Vector2 in candidates:
		var separated := true
		for other: Vector2 in picked:
			if point.distance_to(other) < spacing: separated = false
		if separated: picked.append(point)
		if picked.size() >= count: break
	# The authored five spawn anchors remain a conservative fallback.
	if picked.is_empty():
		for point: Vector2 in current_layout.enemy_spawns: picked.append(point)
	return picked


## The floor `number` of this run: an open map in endless runs, otherwise the
## chain of rooms from the room library.
func _generate_floor(seed_value: int, number: int) -> Array[Dictionary]:
	# A Dungeon-Werkstatt room test always plays the authored rooms.
	if open_floors and test_room_id.is_empty():
		if open_floor_data.is_empty(): open_floor_data = OpenFloor.load_data()
		return Dungeon.generate_open_floor(seed_value, number, dungeon_config, open_floor_data)
	# Rooms come from the Werkstatt pool for this floor; a room test puts its room in.
	return Dungeon.generate(seed_value, _run_room_count(), _floor_pool(number), test_room_id if test_room_floor == number else "")


func _begin_run() -> void:
	if editor_preview_mode:
		start_editor_preview()
		return
	var seed_value := requested_seed if requested_seed >= 0 else randi_range(10000, 99999)
	var generated := _generate_floor(seed_value, 1)
	if generated.is_empty():
		status_message = "Dungeon konnte nicht erstellt werden. Raumdaten prüfen."
		return
	_transition_state.clear()
	_last_transition_state.clear()
	_transition_request.clear()
	transition_view.reset()
	view.reset_feedback()
	_reset_layout_sync()
	peer.refuse_new_connections = true
	room = 1
	run_seed = seed_value
	run_serial += 1
	floor_seed = seed_value
	floor_index = 1
	perk_options.clear()
	perk_offers.clear()
	_perk_rng.seed = seed_value+65537
	perk_combat.reset()
	inventory.new_run(seed_value)
	body_parts.reset(seed_value+131071)
	fx_events.clear()
	cleared_room_ids.clear()
	_auto_reward_key = ""
	floor_layouts = generated
	last_layout_id = ""
	var ids := players.keys()
	var previous_players := players.duplicate()
	players.clear()
	for id in ids:
		_add_player(id)
		# A vacant lobby slot may have been reused out of Dictionary order.
		# Reset the build, while keeping each participant's visible identity.
		players[id].color = previous_players[id].color
		players[id].skin = str(previous_players[id].get("skin",PLAYER_SKINS[PLAYER_COLORS.find(players[id].color)]))
	commands.clear()
	team_progress.reset(seed_value)
	hero_skills.reset(seed_value)
	chests.place_floor(floor_layouts, seed_value)
	hordes.reset(seed_value)
	floor_boss_down = false
	_spawn_room()
	print("RUN_STARTED seed=%d players=%d" % [run_seed, players.size()])
	print("FLOOR_ENTERED floor=%d seed=%d" % [floor_index, floor_seed])


func _spawn_room(from_room: int = 0) -> void:
	crypt_ai.bind(self)
	void_ai.bind(self)
	boss_moves.reset()
	fx_events.clear()
	if room < 1 or room > floor_layouts.size(): return
	if phase == "combat": hordes.leave()
	current_layout = floor_layouts[room - 1]
	_room_layout_revision += 1
	_room_serial += 1
	# EXP left on the floor is collected; ground effects and channels end.
	team_progress.collect_all()
	hero_skills.room_changed()
	_local_visual_state = {}
	var revisiting := cleared_room_ids.has(str(current_layout.id))
	phase = "explore" if revisiting else "combat"
	enemies.clear()
	bullets.clear()
	commands.clear()
	var index := 0
	for id in players:
		var player: Dictionary = players[id]
		player.pos = Dungeon.entry_for_player(from_room, index, current_layout) if from_room > 0 else Dungeon.spawn_for_player(index, current_layout)
		if not revisiting:
			player.ready = false
			player.picked = false
		player.shot_timer = 0.0
		player.hitstun = 0.0
		player.hit_flash = 0.0
		player.knockback = Vector2.ZERO
		player.moving = false
		player.motion = Vector2.ZERO
		if not revisiting:
			player.invulnerable = 1.0
			if player.hp <= 0: player.hp = maxi(1, int(ceil(player.max_hp * 0.5)))
		index += 1
	perk_combat.enter_room(revisiting)
	if revisiting:
		print("ROOM_REVISITED room=%d floor=%d" % [room, floor_index])
		return
	if current_layout.get("open_floor", false) and not editor_preview_mode:
		_spawn_open_floor()
		return
	var counts: Array = balance.rooms.enemy_counts
	var boss_room: bool = current_layout.boss
	var count := int(counts[mini(room-1,counts.size()-1)])
	var returning: bool = hordes.enabled and hordes.known(str(current_layout.id)) and not (boss_room and not floor_boss_down)
	var spawn_points: Array[Vector2] = []
	if current_layout.get("crypt_profile",false) and not editor_preview_mode:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(current_layout.get("encounter_seed",floor_seed))
		var encounter: Dictionary = current_layout.get("encounter",{})
		count = maxi(1,int(encounter.get("boss_enemies",3))) if boss_room else rng.randi_range(int(encounter.get("min_enemies",5)),int(encounter.get("max_enemies",8)))
		# Floors without (mini-)boss end in a strong group instead.
		if boss_room and crypt_ai.final_room_role(floor_index) == "strong_group":
			count = int(balance.get("enemy_roster",{}).get("floor_plan",{}).get("strong_group_count",6))
		spawn_points = _crypt_enemy_positions(rng,count,encounter)
		count = mini(count,spawn_points.size())
	if returning: count = 0
	if editor_preview_mode:
		count = mini(count,current_layout.enemy_spawns.size())
		if count == 0:
			phase = "explore"
			cleared_room_ids.append(str(current_layout.id))
	if count > 0:
		var radii: Array = [float(balance.enemy.radius)]
		for definition: Dictionary in balance.get("enemy_roster",{}).get("definitions",{}).values():
			var radius: float = float(definition.get("radius",balance.enemy.radius))
			if radius not in radii: radii.append(radius)
		if boss_room: radii.append(float(balance.boss.radius))
		Dungeon.prepare_navigation(current_layout,radii)
	for i in range(count):
		var roster_rng := RandomNumberGenerator.new()
		roster_rng.seed = int(current_layout.get("encounter_seed",floor_seed))+i
		var kind: String = crypt_ai.choose_kind(room,i,count,boss_room,roster_rng)
		enemies.append(_create_enemy(kind,spawn_points[i] if not spawn_points.is_empty() else Dungeon.spawn_for_enemy(i,current_layout)))
	# Every enemy starts with a valid path, then refreshes at the same cadence
	# with a different phase instead of all rebuilding on one physics frame.
	var repath_interval := _navigation_interval()
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		var target := -1
		var distance := INF
		for id in players:
			if players[id].hp <= 0: continue
			var candidate: float = enemy.pos.distance_squared_to(players[id].pos)
			if candidate < distance:
				distance = candidate
				target = id
		if target >= 0:
			enemy.nav_path = Dungeon.find_path(enemy.pos,players[target].pos,enemy.radius,current_layout)
		enemy.nav_timer = repath_interval*float(i+1)/float(enemies.size())
	hordes.enter(count, boss_room)
	print("ROOM_STARTED room=%d enemies=%d boss=%s" % [room, count, boss_room])


## Fills an open floor: a sleeping group in every middle room, the floor's
## final group (boss, mini-boss or strong group) in the boss room, also asleep
## until a hero comes into sight (src/combat/aggro.gd). No hordes on open floors.
func _spawn_open_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_seed + 4099
	var radii: Array = [float(balance.enemy.radius), float(balance.boss.radius)]
	for definition: Dictionary in balance.get("enemy_roster",{}).get("definitions",{}).values():
		var radius: float = float(definition.get("radius",balance.enemy.radius))
		if radius not in radii: radii.append(radius)
	Dungeon.prepare_navigation(current_layout,radii)
	var points: Array = current_layout.enemy_spawns
	for i in range(points.size()):
		enemies.append(_create_enemy(crypt_ai.choose_kind(floor_index+1,i,points.size(),false,rng),points[i]))
	var guards: Array = current_layout.boss_spawns
	var plan: Dictionary = balance.get("enemy_roster",{}).get("floor_plan",{})
	var final_count: int = int(plan.get("strong_group_count",6)) if crypt_ai.final_room_role(floor_index) == "strong_group" else int(current_layout.get("encounter",{}).get("boss_enemies",3))
	for i in range(mini(final_count,guards.size())):
		var guard: Dictionary = _create_enemy(crypt_ai.choose_kind(floor_index+1,i,final_count,true,rng),guards[i])
		guard.aggro = false
		guard.asleep = true
		enemies.append(guard)
	for i in range(enemies.size()): enemies[i].nav_timer = _navigation_interval()*float(i+1)/float(enemies.size())
	print("ROOM_STARTED room=%d enemies=%d boss=true open_floor=true" % [room, enemies.size()])


## One host-side factory supplies both initial enemies and validated summons.
func _create_enemy(kind: String, point: Vector2) -> Dictionary:
	var definition: Dictionary = balance.boss.duplicate() if kind == "boss" else balance.enemy.duplicate()
	if kind != "boss": definition.merge(crypt_ai.definition(kind),true)
	var multiplier: float = minf(float(balance.exploration.max_hp_multiplier),1.0+(floor_index-1)*float(balance.exploration.floor_hp_step))
	var hp: int = int(ceil((float(definition.hp)+maxi(0,players.size()-1)*float(definition.hp_per_extra_player))*multiplier))
	var result: Dictionary = {"pos":point,"hp":hp,"max_hp":hp,"boss":kind == "boss","radius":float(definition.radius),"speed":float(definition.speed),"shot_timer":1.0,"nav_timer":0.0,"nav_path":PackedVector2Array(),"hitstun":0.0,"hit_flash":0.0,"knockback":Vector2.ZERO,"stun_cooldown":0.0,"id":_next_enemy_id,"kind":kind,"hits":0,"attacks":0,"blocks":0,"moving":false,"face":-1.0,"direction":Vector2.ZERO,"attack":"","attack_time":0.0,"attack_kind":"","attack_length":1.0,"attack_aim":Vector2.LEFT,"facing_dir":Vector2.LEFT,"summons_cast":0,"caster_id":0,"summoned":false,"enemy_name":str(definition.get("name",definition.get("display_name","Kryptawesen"))),"dying":0.0}
	_next_enemy_id += 1
	# Bosses start angry; everyone else waits until a hero is noticed (see Aggro).
	result.aggro = result.boss
	result.shot_timer = float(definition.get("initial_cooldown",1.0))
	if bool(definition.get("miniboss",false)): result.miniboss = true
	# Rigged figures split their HP over body parts (src/combat/body_parts.gd).
	if not str(definition.get("rig","")).is_empty(): body_parts.attach(result,str(definition.rig))
	return result


## Queues a short host effect for clients (void burst, slam); clients play each id once.
func add_fx(kind: String, point: Vector2, radius: float, extra: Dictionary = {}) -> void:
	var event := {"id":_next_fx_id,"kind":kind,"x":point.x,"y":point.y,"r":radius,"life":0.6}
	event.merge(extra,true)
	fx_events.append(event)
	_next_fx_id += 1


## A shot or blade met a wall: the contact point on the wall, its normal (back
## towards the floor) and what struck it, for chips, sparks and splashes.
## owner > 0: the hero whose shot it was (clients splash in that weapon's glow).
func wall_hit(from: Vector2, to: Vector2, style: String, owner: int = 0) -> void:
	var recent := 0
	for event: Dictionary in fx_events:
		if str(event.kind) == "wall_hit" and float(event.life) > 0.5: recent += 1
	if recent >= 8: return
	var low := 0.0
	var high := 1.0
	for step in range(7):
		var middle := (low + high) * 0.5
		if Dungeon.segment_blocked(from,from.lerp(to,middle),0.0,current_layout): high = middle
		else: low = middle
	var contact := from.lerp(to,low)
	var travel := to-from
	var normal := -travel.normalized()
	if Dungeon.segment_blocked(contact,contact+Vector2(signf(travel.x)*6.0,0.0),0.0,current_layout) and not Dungeon.segment_blocked(contact,contact+Vector2(0.0,signf(travel.y)*6.0),0.0,current_layout): normal = Vector2(-signf(travel.x),0.0)
	elif Dungeon.segment_blocked(contact,contact+Vector2(0.0,signf(travel.y)*6.0),0.0,current_layout) and not Dungeon.segment_blocked(contact,contact+Vector2(signf(travel.x)*6.0,0.0),0.0,current_layout): normal = Vector2(0.0,-signf(travel.y))
	var extra: Dictionary = {"style":style,"nx":normal.x,"ny":normal.y}
	if owner > 0: extra.o = owner
	add_fx("wall_hit",contact,8.0,extra)


## What a shot is made of, for its wall effect.
func _shot_style(bullet: Dictionary) -> String:
	var skill := str(bullet.get("skill",""))
	if skill == "fireball": return "fire"
	if skill == "fist": return "frost"
	if skill == "wave": return "metal"
	match str(bullet.get("element","")):
		"cinder": return "fire"
		"frost": return "frost"
		"storm": return "arcane"
		"venom": return "poison"
	match str(bullet.get("style","")):
		"magic": return "magic"
		"soul","void_skull": return "void"
		"roar": return "stone"
	return "arrow"


## The room's collision changed (a chest or crate broke): clients get the
## new layout; navigation follows the obstacles automatically.
func layout_changed() -> void:
	_room_layout_revision += 1
	_broadcast_state(true)


## An ultimate broke inner wall cells (WallBreaker already changed the layout):
## clients get the new layout with rubble effects; navigation follows the new
## obstacles automatically.
func walls_broken(points: Array[Vector2]) -> void:
	_room_layout_revision += 1
	for point: Vector2 in points: add_fx("wall_break", point, 16.0)
	print("WALL_BROKEN room=%d cells=%d" % [room, points.size()])
	_broadcast_state(true)


## Summons must originate from a live caster and an unoccupied, reachable floor.
## Lifetime and active limits are checked here, not entrusted to the AI caller.
func spawn_crypt_minion(caster_id: int, point: Vector2, kind: String = "skeleton_guard", forced: bool = false) -> bool:
	if not hosting or not active or phase != "combat" or not point.is_finite(): return false
	var caster: Dictionary = {}
	var alive: int = 0
	var active_summons: int = 0
	for enemy: Dictionary in enemies:
		if float(enemy.hp) <= 0: continue
		alive += 1
		if int(enemy.id) == caster_id: caster = enemy
		if int(enemy.get("caster_id",0)) == caster_id: active_summons += 1
	if caster.is_empty(): return false
	# Necromancers raise shield skeletons; the Leerenrufer calls archers and bombers.
	var boss_caster: bool = void_ai.handles(caster)
	if not forced and not boss_caster and (str(caster.kind) != "necromancer" or kind != "skeleton_guard"): return false
	var limits: Dictionary = balance.get("enemy_roster",{}).get("limits",{})
	var boss_limits: Dictionary = balance.get("void_boss",{}).get("limits",{})
	var max_active: int = int(boss_limits.get("max_active_summons",4)) if boss_caster else int(limits.get("max_active_summons",2))
	var max_total: int = int(boss_limits.get("max_summons",24)) if boss_caster else int(limits.get("max_summons_per_caster",2))
	if alive >= int(limits.get("max_enemies",12)): return false
	if not forced and (active_summons >= max_active or int(caster.get("summons_cast",0)) >= max_total): return false
	var definition: Dictionary = crypt_ai.definition(kind)
	if definition.is_empty(): return false
	var radius: float = float(definition.get("radius",balance.enemy.radius))
	if Dungeon.segment_blocked(point,point,radius,current_layout): return false
	for player: Dictionary in players.values():
		if int(player.hp) > 0 and point.distance_to(player.pos) < float(limits.get("min_spawn_distance",112)): return false
	for enemy: Dictionary in enemies:
		if float(enemy.hp) > 0 and point.distance_to(enemy.pos) < maxf(radius+float(enemy.radius),float(limits.get("summon_enemy_spacing",32))): return false
	if Dungeon.find_path(caster.pos,point,radius,current_layout).is_empty(): return false
	var minion: Dictionary = _create_enemy(kind,point)
	minion.caster_id = caster_id
	minion.summoned = true
	minion.aggro = true
	minion.nav_timer = _navigation_interval()
	enemies.append(minion)
	caster.summons_cast = int(caster.get("summons_cast",0))+1
	return true


## Line of sight for aggro: nothing solid lies between the two points.
func _sees(from: Vector2, to: Vector2) -> bool:
	return not Dungeon.segment_blocked(from, to, 0.0, current_layout)


func _navigation_interval() -> float:
	return maxf(1.0/Engine.physics_ticks_per_second,float(balance.get("navigation",{}).get("repath_interval",0.3)))


func _simulate_players(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for id in players:
		var player: Dictionary = players[id]
		player.moving = false
		player.motion = Vector2.ZERO
		player.shot_timer = maxf(0.0, player.shot_timer - delta)
		player.invulnerable = maxf(0.0, player.invulnerable - delta)
		player.hitstun = maxf(0.0, float(player.get("hitstun", 0.0)) - delta)
		player.hit_flash = maxf(0.0, float(player.get("hit_flash", 0.0)) - delta)
		if player.hp <= 0: continue
		var push: Vector2 = player.get("knockback", Vector2.ZERO)
		player.pos = Dungeon.move_actor(player.pos, push * delta, float(balance.player.radius), current_layout)
		player.knockback = push.move_toward(Vector2.ZERO, float(balance.feedback.player_knockback) * float(balance.feedback.knockback_decay) * delta)
		if player.hitstun > 0.0: continue
		var command: Dictionary = commands.get(id, {})
		if command.is_empty() or now - command.time > float(balance.network.input_timeout): continue
		player.aim = command.aim
		if absf(command.aim.x) > 0.01: player.face = signf(command.aim.x)
		var acting: bool = player_effects.can_act(player)
		if acting and not player_effects.skills_sealed(player): hero_skills.handle_input(id, player, command)
		var move_scale: float = hero_skills.move_scale(player) * player_effects.move_scale(player)
		var wanted: Vector2 = command.move * player.speed * move_scale
		# On ice the hero keeps sliding: the new direction only takes over slowly.
		var slip: float = player_effects.slip(player)
		if slip > 0.0: wanted = Vector2(player.get("slide", Vector2.ZERO)).lerp(wanted, 1.0 - pow(slip, delta * 60.0))
		player.slide = wanted
		if wanted.length_squared() > 0.01:
			var before: Vector2 = player.pos
			player.pos = Dungeon.move_actor(player.pos, wanted * delta, float(balance.player.radius), current_layout)
			player.moving = player.pos.distance_squared_to(before) > 0.001
			player.motion = (player.pos-before)/maxf(delta,0.000001)
		if acting and command.fire and phase != "reward" and player.shot_timer <= 0.0 and hero_skills.can_attack(player):
			player.shot_timer = perk_combat.shot_interval(player) * player_effects.attack_scale(player)
			inventory.on_attack(player)
			if bool(player.get("melee",false)): perk_combat.melee(id,command.aim)
			else: perk_combat.shoot(id,command.aim)
			hero_skills.basic_attack(id, player, command.aim)


func _add_bullet(position: Vector2, velocity: Vector2, owner: int, damage: float, metadata: Dictionary = {}) -> Dictionary:
	var limits: Dictionary = balance.get("perk_rules",{}).get("mechanics",{})
	var total_limit: int = int(limits.get("max_projectiles",balance.bullet.max_count))
	if bullets.size() >= total_limit: return {}
	if owner > 0:
		var owned: int = 0
		for bullet: Dictionary in bullets:
			if int(bullet.owner) == owner: owned += 1
		if owned >= int(limits.get("max_player_projectiles",24)): return {}
		if bullets.size() >= total_limit-int(limits.get("reserved_enemy_projectiles",32)): return {}
	var result: Dictionary = {"id":_next_bullet_id,"pos": position, "velocity": velocity, "owner": owner, "damage": damage, "life": float(balance.bullet.lifetime) if owner != 0 else 5.0}
	result.merge(metadata,true)
	bullets.append(result)
	_next_bullet_id += 1
	return result


func _simulate_enemies(delta: float) -> void:
	perk_combat.step_statuses(delta)
	decoys.clear()
	# Summoning may append a new actor; it first participates on the next tick.
	for enemy in enemies.duplicate():
		enemy.moving = false
		enemy.motion = Vector2.ZERO
		var simulation_start: Vector2 = enemy.pos
		if enemy.hp <= 0:
			enemy.dying = maxf(0.0,float(enemy.get("dying",0.0))-delta)
			var death_push: Vector2 = enemy.get("knockback",Vector2.ZERO)
			enemy.pos = Dungeon.move_actor(enemy.pos,death_push*delta,enemy.radius,current_layout)
			enemy.knockback = death_push.move_toward(Vector2.ZERO,float(balance.death.kick)*delta*4.0)
			continue
		enemy.hitstun = maxf(0.0, float(enemy.get("hitstun", 0.0)) - delta)
		enemy.hit_flash = maxf(0.0, float(enemy.get("hit_flash", 0.0)) - delta)
		enemy.stun_cooldown = maxf(0.0, float(enemy.get("stun_cooldown", 0.0)) - delta)
		body_parts.step(enemy, delta)
		var push: Vector2 = enemy.get("knockback", Vector2.ZERO)
		enemy.pos = Dungeon.move_actor(enemy.pos, push * delta, enemy.radius, current_layout)
		enemy.knockback = push.move_toward(Vector2.ZERO, float(balance.feedback.enemy_knockback) * float(balance.feedback.knockback_decay) * delta)
		if enemy.hitstun > 0.0: continue
		if perk_combat.frozen(enemy): continue
		# Aggro: unaware enemies stand still; a locked one hunts its hero to the end.
		var target: int = Aggro.pick_target(enemy, players, _sees, balance.aggro)
		if target < 0: continue
		Aggro.alert_pack(enemy, enemies, balance.aggro)
		# Spiegelbild: normal enemies near a decoy chase the decoy instead.
		if not enemy.boss and not bool(enemy.get("miniboss",false)):
			for zone: Dictionary in hero_skills.zones:
				if str(zone.kind) == "decoy" and enemy.pos.distance_to(zone.pos) <= float(zone.radius):
					target = -int(zone.id)
					decoys[target] = {"pos": Vector2(zone.pos), "hp": 1}
		if target < 0:
			if crypt_ai.step(enemy,target,delta): enemy.motion = (enemy.pos-simulation_start)/maxf(delta,0.000001)
			continue
		if void_ai.step(enemy,target,delta) or crypt_ai.step(enemy,target,delta):
			enemy.motion = (enemy.pos-simulation_start)/maxf(delta,0.000001)
			continue
		enemy.nav_timer = float(enemy.get("nav_timer", 0.0)) - delta
		if enemy.nav_timer <= 0.0:
			enemy.nav_path = Dungeon.find_path(enemy.pos, players[target].pos, enemy.radius, current_layout)
			enemy.nav_timer = _navigation_interval()
		var path: PackedVector2Array = enemy.get("nav_path", PackedVector2Array())
		while not path.is_empty() and enemy.pos.distance_to(path[0]) < 8.0:
			path.remove_at(0)
		enemy.nav_path = path
		var direction: Vector2 = (path[0] - enemy.pos).normalized() if not path.is_empty() else Vector2.ZERO
		var before: Vector2 = enemy.pos
		enemy.pos = Dungeon.move_actor(enemy.pos, direction * enemy.speed * perk_combat.speed_scale(enemy) * body_parts.speed_scale(enemy) * delta, enemy.radius, current_layout)
		enemy.moving = enemy.pos.distance_squared_to(before) > 0.001
		enemy.motion = (enemy.pos-simulation_start)/maxf(delta,0.000001)
		if direction.length_squared() > 0.001: enemy.facing_dir = direction
		if enemy.boss: enemy.attack_aim = (players[target].pos-enemy.pos).normalized()
		if absf(direction.x) > 0.01: enemy.face = signf(direction.x)
		if enemy.pos.distance_to(players[target].pos) < enemy.radius + float(balance.player.radius) and not Dungeon.segment_blocked(enemy.pos, players[target].pos, 0.0, current_layout):
			_damage_player(target, int(balance.enemy.damage), (players[target].pos - enemy.pos).normalized())
		if enemy.boss and enemy.hp > 0:
			_update_boss_attack(enemy,delta)
	enemies = enemies.filter(func(enemy: Dictionary): return enemy.hp > 0 or float(enemy.get("dying",0.0)) > 0.0)


func _update_boss_attack(enemy: Dictionary, delta: float) -> void:
	var attack: String = enemy.get("attack","")
	if attack.is_empty():
		enemy.shot_timer -= delta
		if enemy.shot_timer <= 0.0:
			enemy.attack = "windup"
			enemy.attack_time = float(balance.attacks.boss.windup)
		return
	enemy.attack_time = maxf(0.0,float(enemy.get("attack_time",0.0))-delta)
	if enemy.attack_time > 0.0: return
	if attack == "windup":
		enemy.attack = "active"
		enemy.attack_time = float(balance.attacks.boss.active)
		enemy.attacks = int(enemy.get("attacks",0))+1
		var count := int(balance.boss.bullet_count)
		for index in range(count):
			var aim := Vector2.RIGHT.rotated(TAU*index/count+Time.get_ticks_msec()*0.0001)
			_add_bullet(enemy.pos+aim*enemy.radius,aim*float(balance.boss.bullet_speed),0,float(balance.enemy.damage))
	elif attack == "active":
		enemy.attack = "recovery"
		enemy.attack_time = float(balance.attacks.boss.recovery)
	else:
		enemy.attack = ""
		enemy.attack_time = 0.0
		enemy.shot_timer = float(balance.boss.shot_interval)


func _simulate_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		var radius: float = float(bullet.get("radius",balance.bullet.radius))
		var previous: Vector2 = bullet.pos
		if int(bullet.owner) > 0: perk_combat.steer(bullet,delta)
		bullet.pos += bullet.velocity * delta
		bullet.distance = float(bullet.get("distance",0.0))+previous.distance_to(bullet.pos)
		bullet.life -= delta
		# Wide skill shots (blade wave, Pfeilfaust) hit enemies with their full width
		# but meet walls with a thin core, so they fly through corridors.
		var wall_radius: float = float(bullet.get("wall_radius",radius))
		var blocked: bool = Dungeon.segment_blocked(previous,bullet.pos,wall_radius,current_layout)
		var removed: bool = bullet.life <= 0.0
		# A player shot that runs into a chest or crate strikes it.
		if blocked and int(bullet.owner) > 0 and chests.hit_segment(previous,bullet.pos,radius+10.0,int(bullet.owner),bullet):
			if int(bullet.get("pierce",0)) <= 0: removed = true
			blocked = false
		if blocked and not removed:
			wall_hit(previous,bullet.pos,_shot_style(bullet),int(bullet.owner))
			if int(bullet.get("bounces",0)) > 0:
				var blocked_x: bool = Dungeon.segment_blocked(previous,Vector2(bullet.pos.x,previous.y),wall_radius,current_layout)
				var blocked_y: bool = Dungeon.segment_blocked(previous,Vector2(previous.x,bullet.pos.y),wall_radius,current_layout)
				if blocked_x: bullet.velocity.x = -bullet.velocity.x
				if blocked_y: bullet.velocity.y = -bullet.velocity.y
				if not blocked_x and not blocked_y: bullet.velocity = -bullet.velocity
				bullet.bounces = int(bullet.bounces)-1
				bullet.pos = previous
			else: removed = true
		if not removed and bullet.owner == 0:
			for id in players:
				if players[id].hp > 0 and perk_combat.segment_hits(previous,bullet.pos,players[id].pos,float(balance.player.radius)+radius):
					if id in Array(bullet.get("player_hits", [])): continue
					_damage_player(id, int(bullet.damage), bullet.velocity.normalized())
					boss_moves.bullet_hit(bullet, id)
					if bool(bullet.get("pierce_players", false)):
						bullet.player_hits = Array(bullet.get("player_hits", [])) + [id]
						continue
					removed = true
					break
		elif not removed:
			if not bullet.has("hit_ids"): bullet.hit_ids = []
			var targets: Array[Dictionary] = []
			var impact_parts: Dictionary = {}
			for enemy: Dictionary in enemies:
				if enemy.hp <= 0 or int(enemy.id) in bullet.hit_ids: continue
				if body_parts.has_parts(enemy):
					# Rigged figures: the shot must cross a living part's pixels.
					if not perk_combat.segment_hits(previous,bullet.pos,enemy.pos,body_parts.reach(enemy)+radius): continue
					var part: String = body_parts.segment_part(enemy,previous,bullet.pos,radius)
					if part.is_empty(): continue
					impact_parts[int(enemy.id)] = part
					targets.append(enemy)
				elif perk_combat.segment_hits(previous,bullet.pos,enemy.pos,float(enemy.radius)+radius): targets.append(enemy)
			targets.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return previous.distance_squared_to(a.pos) < previous.distance_squared_to(b.pos))
			for enemy: Dictionary in targets:
				if enemy.hp <= 0: continue
				bullet.hit_ids.append(int(enemy.id))
				body_parts.set_pending(enemy,str(impact_parts.get(int(enemy.id),"")))
				perk_combat.hit(bullet,enemy)
				if bullet.has("skill") or bool(bullet.get("splinter",false)): hero_skills.bullet_hit(bullet,enemy)
				if int(bullet.get("pierce",0)) <= 0:
					removed = true
					break
				bullet.pierce = int(bullet.pierce)-1
		if not removed and int(bullet.owner) > 0:
			# Player shots break chests (each chest once per shot).
			if chests.hit_segment(previous,bullet.pos,radius,int(bullet.owner),bullet):
				if int(bullet.get("pierce",0)) <= 0: removed = true
		if removed:
			if int(bullet.owner) == 0: boss_moves.bullet_end(bullet)
			# Skill shots: fireball and Pfeilfaust bursts, the returning blade wave.
			if bullet.has("skill") and hero_skills.bullet_end(bullet,blocked,previous): continue
			# Mage orbs burst wherever they end (hit, wall or flight time).
			if int(bullet.owner) > 0 and float(bullet.get("splash",0.0)) > 0.0: perk_combat.splash(bullet)
			bullets.remove_at(i)


func _damage_player(id: int, damage: int, direction: Vector2 = Vector2.ZERO) -> void:
	if not players.has(id) or damage <= 0 or players[id].invulnerable > 0.0 or players[id].hp <= 0: return
	damage += int(players[id].get("item_extra_damage",0))
	damage = perk_combat.incoming(id,damage,direction)
	if damage <= 0: return
	players[id].hp = maxi(0, players[id].hp - damage)
	perk_combat.hurt(id)
	if players[id].hp <= 0: perk_combat.rescue(players[id])
	players[id].hurts = int(players[id].get("hurts",0))+1
	players[id].last_hit_damage = damage
	players[id].hit_direction = direction.normalized()
	players[id].invulnerable = float(balance.player.invulnerability)+float(players[id].get("build",{}).get("desperation",0.0))
	players[id].hitstun = float(balance.feedback.player_hitstun)
	players[id].hit_flash = float(balance.feedback.hit_flash)
	players[id].knockback = direction.normalized() * float(balance.feedback.player_knockback)


func _damage_enemy(enemy: Dictionary, damage: float, direction: Vector2 = Vector2.ZERO, owner: int = 0, kill_effects: bool = true, feedback: bool = true) -> float:
	if damage <= 0.0 or enemy.hp <= 0: return 0.0
	# A hurt enemy turns on the hero who hurt it, even from out of sight.
	if players.has(owner): Aggro.lock(enemy, owner)
	if feedback and kill_effects:
		var guard: float = crypt_ai.guard_multiplier(enemy,direction,true)
		if guard < 1.0:
			enemy.blocks = int(enemy.get("blocks",0))+1
			damage *= guard
	if float(enemy.get("collapsed",0.0)) > 0.0:
		# The Knochenkoloss lies in pieces: only its skull can still be smashed.
		if boss_moves.hit_skull(enemy,damage):
			enemy.hp = 0.0
			_enemy_fell(enemy,direction,owner,kill_effects)
		return damage
	var boss: bool = enemy.boss
	damage *= hero_skills.damage_scale(enemy) * boss_moves.damage_scale(enemy)
	if body_parts.has_parts(enemy):
		# The part at the impact point takes the damage; all of it counts against the total HP.
		var impact: String = body_parts.take_pending(enemy)
		var result: Dictionary = body_parts.damage(enemy,damage,impact)
		enemy.last_hit_part = str(result.part)
		if bool(result.killed): enemy.hp = 0.0
	else: enemy.hp = maxf(0.0, enemy.hp - damage)
	if feedback:
		enemy.hits = int(enemy.get("hits",0))+1
		enemy.last_hit_damage = damage
		enemy.direction = direction.normalized()
		enemy.hit_flash = float(balance.feedback.hit_flash)
	if feedback and float(enemy.get("stun_cooldown", 0.0)) <= 0.0:
		enemy.hitstun = float(balance.feedback.boss_hitstun if boss else balance.feedback.enemy_hitstun)
		enemy.stun_cooldown = float(balance.feedback.boss_stun_cooldown if boss else balance.feedback.enemy_stun_cooldown)
		var heavy: float = float(players.get(owner,{}).get("build",{}).get("heavy",0.0))
		var knockback_scale: float = float(balance.get("perk_rules",{}).get("mechanics",{}).get("heavy_knockback_scale",1.7)) if heavy > 0 else 1.0
		enemy.knockback = direction.normalized() * float(balance.feedback.boss_knockback if boss else balance.feedback.enemy_knockback)*knockback_scale
	if enemy.hp <= 0 and boss_moves.hold_death(enemy): return damage
	if enemy.hp <= 0: _enemy_fell(enemy,direction,owner,kill_effects)
	# Return resolved damage before HP clamping, so lethal surplus remains measurable.
	return damage


## An enemy has fallen: death push, kill effects, EXP, boss flag, Mimik loot.
func _enemy_fell(enemy: Dictionary, direction: Vector2, owner: int, kill_effects: bool) -> void:
	var boss: bool = enemy.boss
	enemy.dying = float(balance.death.boss_duration if boss else balance.death.duration)
	enemy.knockback = direction.normalized()*float(balance.death.boss_kick if boss else balance.death.kick)
	perk_combat.killed(enemy,owner,kill_effects)
	team_progress.enemy_killed(enemy)
	if bool(enemy.get("boss",false)) or bool(enemy.get("miniboss",false)): floor_boss_down = true
	hero_skills.enemy_killed(enemy,owner)
	if str(enemy.get("kind","")) == "mimic": chests.mimic_defeated(enemy,owner)


## Damage over time (poison, burns, pools): lands even right after a hit, one
## tick at a time, without stun or knockback.
func dot_player(id: int, amount: int, _kind: String = "") -> void:
	if not players.has(id) or amount <= 0 or int(players[id].hp) <= 0: return
	players[id].hp = maxi(0, int(players[id].hp) - amount)
	players[id].hurts = int(players[id].get("hurts",0))+1
	players[id].last_hit_damage = amount
	players[id].hit_flash = float(balance.feedback.hit_flash)
	if int(players[id].hp) <= 0: perk_combat.rescue(players[id])


func _check_room_end() -> void:
	if phase != "combat": return
	var living := 0
	for player in players.values():
		if player.hp > 0: living += 1
	if living == 0:
		phase = "dead"
		bullets.clear()
		print("TEAM_WIPE room=%d" % room)
		_broadcast_state(true)
	elif enemies.is_empty() and not hordes.pending():
		if str(current_layout.id) not in cleared_room_ids: cleared_room_ids.append(str(current_layout.id))
		bullets.clear()
		perk_combat.room_cleared()
		if not bool(balance.get("perk_rules",{}).get("room_rewards",false)):
			# Perks come from level-ups and bosses now; a cleared room opens at once.
			phase = "explore"
			print("ROOM_CLEARED room=%d phase=%s" % [room, phase])
			if cleared_room_ids.size() == floor_layouts.size(): print("FLOOR_CLEARED floor=%d players=%d" % [floor_index, players.size()])
			_broadcast_state(true)
			return
		phase = "reward"
		perk_offers.clear()
		for id in players:
			perk_offers[id] = PerkRules.offer(players[id],balance,_perk_rng,3) if int(players[id].hp) > 0 else []
		perk_options = perk_offers.get(1,[])
		print("ROOM_CLEARED room=%d phase=%s" % [room, phase])
		_broadcast_state(true)


func _grant_perk(id: int, perk: Dictionary) -> bool:
	if not players.has(id): return false
	var player: Dictionary = players[id]
	if not PerkRules.grant(player,perk,balance): return false
	perk_combat.granted(id,PerkRules.find(balance,str(perk.id)))
	player.picked = true
	print("PERK_SELECTED peer=%d room=%d perk=%s floor=%d" % [id, room, perk.id, floor_index])
	return true


func _advance_if_ready() -> void:
	if phase != "reward": return
	var living := 0
	for player in players.values():
		if player.hp <= 0: continue
		living += 1
		if not player.picked or not player.ready: return
	if living > 0:
		phase = "explore"
		if cleared_room_ids.size() == floor_layouts.size():
			print("FLOOR_CLEARED floor=%d players=%d" % [floor_index, players.size()])


func _use_exit(id: int) -> void:
	if editor_preview_mode:
		status_message = "Einzelraum-Vorschau: Zurück zum Editor beendet diesen Raum. Die Raumfolge wird hier nicht gestartet."
		return
	if not _transition_state.is_empty() or phase not in ["explore", "combat"] or not players.has(id) or players[id].hp <= 0: return
	var nearest: Dictionary = {}
	var distance := INF
	for exit: Dictionary in current_layout.get("exits", []):
		var candidate: float = players[id].pos.distance_to(_exit_center(exit))
		if candidate < distance:
			nearest = exit
			distance = candidate
	if nearest.is_empty() or distance > float(balance.exploration.interaction_radius): return
	var center := _exit_center(nearest)
	for player: Dictionary in players.values():
		if player.hp > 0 and (player.pos.distance_to(center) > float(balance.exploration.party_radius) or player.hitstun > 0.0): return
	if nearest.kind == "stairs":
		if not stairs_open(): return
		_queue_transition(id,nearest)
		return
	var target := int(nearest.target_room)
	if target < 1 or target > floor_layouts.size(): return
	_queue_transition(id,nearest)


## The stairs down: open, except on boss floors (3, 6, 9, 10, ...) until the
## floor's boss or mini-boss has fallen. Without hordes the old rule holds:
## every room of the floor must be cleared.
func stairs_open() -> bool:
	if not hordes.enabled: return cleared_room_ids.size() == floor_layouts.size()
	if crypt_ai.final_room_role(floor_index) == "strong_group": return true
	return floor_boss_down


func _queue_transition(id: int, exit: Dictionary) -> void:
	if players.has(id): players[id].interacts = int(players[id].get("interacts",0))+1
	_transition_token += 1
	_transition_request = {"peer":id,"from_room":room,"target_room":int(exit.target_room),"kind":str(exit.kind),"swapped":false}
	_transition_state = {"token":_transition_token,"kind":str(exit.kind),"from_id":str(current_layout.id),"elapsed":0.0,"active":true}
	commands.clear()
	for player: Dictionary in players.values():
		player.moving = false
		player.motion = Vector2.ZERO
	print("TRANSITION_STARTED token=%d kind=%s floor=%d room=%d" % [_transition_token,exit.kind,floor_index,room])
	_broadcast_state(true)


func _step_transition(delta: float) -> void:
	if not hosting or _transition_state.is_empty(): return
	_transition_state.elapsed = float(_transition_state.elapsed)+maxf(0.0,delta)
	if not _transition_request.swapped and _transition_state.elapsed >= float(balance.transition.fade_out):
		_transition_request.swapped = true
		if _transition_request.kind == "stairs": _enter_next_floor()
		else:
			room = int(_transition_request.target_room)
			_spawn_room(int(_transition_request.from_room))
			print("EXIT_USED peer=%d from=%d to=%d floor=%d" % [_transition_request.peer,_transition_request.from_room,room,floor_index])
		print("TRANSITION_COVERED token=%d floor=%d room=%d" % [_transition_state.token,floor_index,room])
		_broadcast_state(true)
	var duration := float(balance.transition.fade_out)+float(balance.transition.black_hold)+float(balance.transition.fade_in)
	if _transition_state.elapsed >= duration:
		_last_transition_state = _transition_state.duplicate()
		_last_transition_state.active = false
		_transition_state.clear()
		_transition_request.clear()
		print("TRANSITION_FINISHED token=%d" % _last_transition_state.token)
		_broadcast_state(true)


func _enter_next_floor() -> void:
	if editor_preview_mode: return
	var next_floor := floor_index + 1
	var next_seed := int((run_seed + (next_floor - 1) * int(balance.exploration.seed_stride)) % 2147483647)
	var generated := _generate_floor(next_seed, next_floor)
	if generated.is_empty(): return
	floor_index = next_floor
	floor_seed = next_seed
	floor_layouts = generated
	cleared_room_ids.clear()
	room = 1
	chests.place_floor(floor_layouts, next_seed)
	hordes.reset(next_seed)
	floor_boss_down = false
	_spawn_room()
	print("FLOOR_ENTERED floor=%d seed=%d" % [floor_index, floor_seed])


func _make_snapshot(advance_sequence: bool = true) -> Dictionary:
	var visible_players := {}
	for id in players:
		var player: Dictionary = players[id]
		var aim: Vector2 = player.get("aim",Vector2.RIGHT)
		visible_players[id] = {"x": player.pos.x, "y": player.pos.y, "hp": player.hp, "max_hp": player.max_hp, "color": player.color, "ready": player.ready, "picked": player.picked, "perks": player.perks.duplicate(), "hitstun": player.get("hitstun", 0.0), "hit_flash": player.get("hit_flash", 0.0), "invulnerable": player.invulnerable,"shots":player.get("shots",0),"hurts":player.get("hurts",0),"step_time":float(balance.player.get("stride", 32)) / maxf(1.0, float(player.get("speed", 152.0))),"moving":player.get("moving",false),"face":player.get("face",1.0),"ax":aim.x,"ay":aim.y}
		visible_players[id].build = player.get("build",{}).duplicate()
		# Hero skills, class cards and the open card choice (level-up / boss).
		visible_players[id].skills = hero_skills.player_state(player)
		visible_players[id].class_perks = Array(player.get("class_perks",[])).duplicate()
		visible_players[id].offer = Array(player.get("offer",[])).duplicate(true)
		visible_players[id].offer_kind = str(player.get("offer_kind",""))
		visible_players[id].offer_pending = Array(player.get("offer_queue",[])).size()
		visible_players[id].skill_casts = int(player.get("skill_casts",0))
		visible_players[id].last_skill = str(player.get("last_skill",""))
		visible_players[id].last_card = str(player.get("last_card",""))
		visible_players[id].last_perk = str(player.get("last_perk",""))
		visible_players[id].shield = int(player.get("perk_runtime",{}).get("shield",0))+int(player.get("perk_runtime",{}).get("soul_shield",0))
		visible_players[id].reserve_shield = int(player.get("reserve_shield",0))
		visible_players[id].radius = float(balance.player.radius)
		visible_players[id].effects = player_effects.kinds(player)
		visible_players[id].glow = str(player.get("attack_glow",""))
		visible_players[id].inventory = inventory.snapshot(player)
		var motion: Vector2 = player.get("motion",Vector2.ZERO)
		var hit_direction: Vector2 = player.get("hit_direction",Vector2.ZERO)
		visible_players[id].merge({"skin":str(player.get("skin",PLAYER_SKINS[0])),"mx":motion.x,"my":motion.y,"blocks":int(player.get("blocks",0)),"interacts":int(player.get("interacts",0)),"last_hit_damage":float(player.get("last_hit_damage",0)),"hit_dx":hit_direction.x,"hit_dy":hit_direction.y,"shot_interval":perk_combat.shot_interval(player)})
		# Hero class presentation (step 2): class, held weapon and melee swing cue.
		visible_players[id].merge({"class_id":str(player.get("class_id","")),"weapons":Array(player.get("weapons",[])).duplicate(),"weapon_index":int(player.get("weapon_index",0)),"melee":bool(player.get("melee",false)),"reach":float(player.get("reach",0.0)),"swings":int(player.get("swings",0)),"swing_angle":float(player.get("swing_angle",0.0)),"swing_arc":float(player.get("swing_arc",0.0))})
	var visible_enemies: Array = []
	for enemy in enemies:
		var direction: Vector2 = enemy.get("direction",Vector2.ZERO)
		var attack: String = enemy.get("attack","")
		var attack_length: float = float(balance.attacks.boss.get(attack,1.0)) if enemy.boss and not void_ai.handles(enemy) else float(enemy.get("attack_length",1.0))
		var death_length := float(balance.death.boss_duration if enemy.boss else balance.death.duration)
		visible_enemies.append({"x": enemy.pos.x, "y": enemy.pos.y, "hp": enemy.hp, "max_hp": enemy.max_hp, "boss": enemy.boss, "hitstun": enemy.get("hitstun", 0.0), "hit_flash": enemy.get("hit_flash", 0.0),"id":enemy.get("id",-1),"kind":enemy.get("kind","chaser"),"hits":enemy.get("hits",0),"attacks":enemy.get("attacks",0),"moving":enemy.get("moving",false),"face":enemy.get("face",-1.0),"dx":direction.x,"dy":direction.y,"attack":attack,"attack_p":clampf(1.0-float(enemy.get("attack_time",0.0))/maxf(0.001,attack_length),0.0,1.0),"dying_p":clampf(1.0-float(enemy.get("dying",0.0))/death_length,0.0,1.0) if enemy.hp <= 0 else -1.0})
		visible_enemies[-1].radius = float(enemy.radius)
		var motion: Vector2 = enemy.get("motion",Vector2.ZERO)
		var facing: Vector2 = enemy.get("facing_dir",Vector2.LEFT)
		visible_enemies[-1].merge({"mx":motion.x,"my":motion.y,"facing_x":facing.x,"facing_y":facing.y,"last_hit_damage":float(enemy.get("last_hit_damage",0))})
		visible_enemies[-1].statuses = enemy.get("statuses",{}).keys()
		var attack_aim: Vector2 = enemy.get("attack_aim",Vector2.LEFT)
		var point: Vector2 = enemy.get("summon_point",enemy.pos) if str(enemy.get("attack_kind","")) == "summon" else enemy.get("attack_point",enemy.pos)
		# Part rigs: which figure, which parts are gone, the open eye and the beam.
		if body_parts.has_parts(enemy):
			visible_enemies[-1].merge({"rig":str(enemy.rig),"lost":Array(enemy.parts_lost).duplicate(),"exposed":str(enemy.get("exposed_action","")),"part_breaks":int(enemy.get("part_breaks",0)),"part_regrows":int(enemy.get("part_regrows",0))})
		if bool(enemy.get("miniboss",false)): visible_enemies[-1].miniboss = true
		if bool(enemy.get("summoned",false)): visible_enemies[-1].summoned = true
		if bool(enemy.get("exploded",false)): visible_enemies[-1].exploded = true
		if float(enemy.get("collapsed",0.0)) > 0.0: visible_enemies[-1].collapsed = true
		if float(enemy.get("armor_time",0.0)) > 0.0: visible_enemies[-1].armor = true
		if bool(enemy.get("rage",false)): visible_enemies[-1].rage = true
		if enemy.has("beam_to") and float(enemy.hp) > 0:
			visible_enemies[-1].beam = [enemy.pos.x,enemy.pos.y,Vector2(enemy.beam_to).x,Vector2(enemy.beam_to).y]
			if enemy.has("beam_to_b"): visible_enemies[-1].beam_b = [enemy.pos.x,enemy.pos.y,Vector2(enemy.beam_to_b).x,Vector2(enemy.beam_to_b).y]
		visible_enemies[-1].merge({"enemy_name":str(enemy.get("enemy_name","Kryptawesen")),"attack_kind":str(enemy.get("attack_kind","")),"attack_length":attack_length,"aim_x":attack_aim.x,"aim_y":attack_aim.y,"tx":point.x,"ty":point.y,"blocks":int(enemy.get("blocks",0)),"cast_count":int(enemy.get("summons_cast",0)),"caster_id":int(enemy.get("caster_id",0))})
	var visible_bullets: Array = []
	for bullet in bullets: visible_bullets.append({"id":bullet.get("id",-1),"radius":float(bullet.get("radius",balance.bullet.radius)),"x": bullet.pos.x, "y": bullet.pos.y, "owner": bullet.owner,"element":str(bullet.get("element","")),"critical":bool(bullet.get("critical",false)),"style":str(bullet.get("style","")),"vx":float(bullet.velocity.x),"vy":float(bullet.velocity.y)})
	if advance_sequence: packet_sequence += 1
	var map_rooms: Array[Dictionary] = []
	for i in range(floor_layouts.size()):
		var layout: Dictionary = floor_layouts[i]
		map_rooms.append({"id": layout.id, "title": layout.title, "boss": layout.boss, "grid_x": layout.grid_x, "grid_y": layout.grid_y, "cleared": str(layout.id) in cleared_room_ids})
	return {"server_time":Time.get_ticks_usec()/1000000.0,"players": visible_players, "enemies": visible_enemies, "bullets": visible_bullets, "room": room, "phase": phase, "seed": floor_seed, "run_seed": run_seed, "run_serial": run_serial, "floor_index": floor_index, "cleared_room_ids": cleared_room_ids.duplicate(), "seq": packet_sequence, "peer_count": players.size(), "max_players":int(balance.network.max_players), "perk_options": perk_options, "perk_offers":perk_offers.duplicate(), "perk_events":perk_combat.visual_events(), "room_layout": current_layout, "room_layout_revision": _room_layout_revision, "room_serial": _room_serial, "floor_map": map_rooms, "generator_version": Dungeon.GENERATOR_VERSION, "boss_name":balance.boss.get("display_name","BOSS"),"fx_events":fx_events.duplicate(true),"team":team_progress.snapshot(),"loot_chests":chests.snapshot(),"boss_zones":boss_moves.snapshot(),"horde":hordes.snapshot(),"stairs_open":stairs_open(),"skill_fx":hero_skills.snapshot(),"transition":(_transition_state if not _transition_state.is_empty() else _last_transition_state).duplicate()}


func _broadcast_state(reliable: bool) -> void:
	if not active or not hosting: return
	var snapshot := _make_snapshot()
	_apply_snapshot(snapshot)
	if multiplayer.get_peers().is_empty(): return
	var layout_id := str(current_layout.get("id",""))
	var layout_key := "%s:%d" % [layout_id,_room_layout_revision]
	var full_payload := PackedByteArray()
	var dynamic_payload := PackedByteArray()
	for id in multiplayer.get_peers():
		if not _admitted_peers.has(id): continue
		# SceneMultiplayer can still list a peer whose ENet channel teardown has begun.
		var transport := peer.get_peer(id)
		if transport == null or transport.get_state() != ENetPacketPeer.STATE_CONNECTED: continue
		if layout_id.is_empty() or _sent_layout_by_peer.get(id,"") != layout_key:
			if full_payload.is_empty(): full_payload = var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE)
			# Reliable ordering also puts new-room event snapshots behind geometry.
			_reliable_state.rpc_id(id,full_payload)
			_sent_layout_by_peer[id] = layout_key
			continue
		if dynamic_payload.is_empty():
			var dynamic := snapshot.duplicate()
			dynamic.erase("room_layout")
			dynamic.room_layout_id = layout_id
			dynamic_payload = var_to_bytes(dynamic).compress(FileAccess.COMPRESSION_DEFLATE)
		# Oversized dynamic packets still use reliable ENet fragmentation.
		if reliable or dynamic_payload.size() > 1100: _reliable_state.rpc_id(id,dynamic_payload)
		else: _state_packet.rpc_id(id,dynamic_payload)


@rpc("authority", "call_remote", "unreliable_ordered", 0)
func _state_packet(payload: PackedByteArray) -> void:
	if active and not hosting and _client_admitted: _apply_encoded_state(payload)


@rpc("authority", "call_remote", "reliable", 1)
func _reliable_state(payload: PackedByteArray) -> void:
	if active and not hosting and _client_admitted: _apply_encoded_state(payload)


func _apply_encoded_state(payload: PackedByteArray) -> void:
	if payload.is_empty() or payload.size() > 262144: return
	var decoded := payload.decompress_dynamic(2097152, FileAccess.COMPRESSION_DEFLATE)
	if decoded.is_empty(): return
	var snapshot = bytes_to_var(decoded)
	if not snapshot is Dictionary or int(snapshot.get("seq",-1)) <= received_sequence: return
	var epoch := "%d:%d" % [int(snapshot.get("run_seed",0)),int(snapshot.get("floor_index",1))]
	if epoch != _received_layout_epoch:
		_received_layouts.clear()
		_received_layout_epoch = epoch
	var revision := int(snapshot.get("room_layout_revision",0))
	if snapshot.has("room_layout"):
		if not snapshot.room_layout is Dictionary: return
		var layout: Dictionary = snapshot.room_layout
		if not layout.is_empty():
			_received_layouts[str(layout.get("id",""))] = {"revision":revision,"layout":layout}
	else:
		var cached: Dictionary = _received_layouts.get(str(snapshot.get("room_layout_id","")),{})
		# Unreliable packets may arrive before their reliable geometry. Do not
		# advance sequence or display a new room until its complete layout arrives.
		if cached.is_empty() or int(cached.revision) != revision: return
		snapshot.room_layout = cached.layout
	_apply_snapshot(snapshot)


func _reset_layout_sync() -> void:
	_sent_layout_by_peer.clear()
	_received_layouts.clear()
	_received_layout_epoch = ""
	_local_visual_state = {}
	snapshot_interpolator.reset()


func _apply_snapshot(snapshot: Dictionary) -> void:
	var sequence := int(snapshot.get("seq", -1))
	if sequence <= received_sequence: return
	received_sequence = sequence
	if snapshot.has("perk_offers"):
		snapshot.perk_options = snapshot.perk_offers.get(multiplayer.get_unique_id(),snapshot.get("perk_options",[]))
	state = snapshot
	if not hosting: snapshot_interpolator.push(snapshot)
	transition_view.apply_state(snapshot)
	if transition_view.is_active() and pause_open:
		pause_open = false
		reward_open = false
		_fire_needs_release = true
		_refresh_ui()
	phase = snapshot.phase
	room = snapshot.room
	if int(snapshot.get("floor_index", 1)) != last_floor_seen:
		last_floor_seen = int(snapshot.get("floor_index", 1))
		print("FLOOR_RECEIVED floor=%d seed=%d" % [last_floor_seen, snapshot.get("seed", 0)])
	var layout: Dictionary = snapshot.get("room_layout", {})
	if not layout.is_empty() and str(layout.id) != last_layout_id:
		last_layout_id = layout.id
		var signature := var_to_bytes(layout).hex_encode().sha256_text()
		print("ROOM_LAYOUT id=%s template=%s version=%d signature=%s" % [layout.id, layout.template_id, layout.generator_version, signature])
	if not seen_snapshot or phase != last_phase:
		print("SNAPSHOT_RECEIVED phase=%s players=%d room=%d" % [phase, snapshot.players.size(), room])
		seen_snapshot = true
		last_phase = phase


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = CryptUI.create_theme()
	canvas.add_child(ui)
	var panel := Panel.new()
	panel.position = Vector2(944, 156)
	panel.size = Vector2(304, 480)
	ui.add_child(panel)
	var title := _label(CryptUI.GAME_TITLE, Vector2(44, 26), Vector2(600, 38), 32, CryptUI.GOLD)
	title.add_theme_color_override("font_outline_color", CryptUI.INK)
	title.add_theme_constant_override("outline_size", 6)
	_label("MEHRSPIELER · " + str(dungeon_config.get("campaign_title","Die Krypta")).to_upper(), Vector2(46, 62), Vector2(600, 22), 16, CryptUI.SAND)
	session_label = _label("ENTWICKLUNGSPROTOTYP", Vector2(944, 30), Vector2(296, 50), 16, CryptUI.SAND)
	session_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label = _label("", Vector2(32, 110), Vector2(1216, 36), 16, CryptUI.BONE)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_label = _label("DIE LOBBY", Vector2(968, 178), Vector2(264, 30), 24, CryptUI.GOLD)
	party_label = _label("", Vector2(968, 219), Vector2(264, 140), 16, CryptUI.BONE)
	party_label.add_theme_font_size_override("font_size", 16)
	party_label.add_theme_constant_override("line_spacing", 2)
	floor_map = preload("res://src/dungeon/dungeon_map.gd").new()
	floor_map.position = Vector2(968, 312)
	floor_map.size = Vector2(264, 40)
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
	# JSON numbers load as floats; "7777.0" would fail _port() (fix from main 2adbc07).
	port_input.text = str(int(balance.network.port))
	ui.add_child(port_input)
	host_button = _button("HOSTEN", Vector2(968, 418), Vector2(126, 42), _host_session)
	join_button = _button("BEITRETEN", Vector2(1106, 418), Vector2(126, 42), _join_session)
	solo_button = _button("SOLO ERKUNDEN", Vector2(968, 474), Vector2(264, 46), func():
		_host_session()
		if active and hosting: _server_action(1, "start", 0))
	# Solo now starts from the main menu's story button; the lobby leads back there.
	solo_button.visible = false
	lobby_menu_button = _button("HAUPTMENÜ", Vector2(968, 474), Vector2(264, 46), _open_main_menu)
	# In a running lobby each player cycles their own hero class (host-validated).
	class_button = _button("KLASSE", Vector2(968, 418), Vector2(264, 42), _cycle_class)
	action_button = _button("RUN STARTEN", Vector2(968, 538), Vector2(264, 42), _main_action)
	leave_button = _button("LOBBY VERLASSEN", Vector2(968, 589), Vector2(264, 32), _leave_or_return)
	_label("WASD BEWEGEN · MAUS ZIELEN · LINKSKLICK ANGREIFEN · E TÜR / TREPPE", Vector2(32, 656), Vector2(896, 28), 16, CryptUI.MUTED)
	_label("%d RÄUME JE EBENE" % _run_room_count(), Vector2(952, 656), Vector2(296, 28), 16, CryptUI.MUTED)
	# Preserve the connection/lobby UI as one hideable group.
	var lobby_children := ui.get_children()
	lobby_ui = Control.new()
	lobby_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(lobby_ui)
	for child: Node in lobby_children: child.reparent(lobby_ui)
	run_hud = RunHud.new()
	run_hud.classes = balance.get("classes",{})
	run_hud.room_count = _run_room_count()
	run_hud.visible = false
	ui.add_child(run_hud)
	level_cards = LevelCards.new()
	ui.add_child(level_cards)
	level_cards.picked.connect(func(index: int): _send_action("card", index))
	inventory_panel = InventoryPanel.new()
	ui.add_child(inventory_panel)
	inventory_panel.acted.connect(func(action: String, value: int): _send_action(action, value))
	inventory_panel.throw_armed.connect(func(slot: int): throw_slot = slot)
	menu_button = _button("MENÜ · ESC",Vector2(960,76),Vector2(244,36),func(): set_pause_open(true,"reward" if phase == "reward" else "overview"))
	context_hint = _label("",Vector2(192,620),Vector2(896,30),16,CryptUI.GOLD)
	context_hint.add_theme_color_override("font_outline_color", CryptUI.INK)
	context_hint.add_theme_constant_override("outline_size", 4)
	context_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if editor_preview_mode:
		context_hint.size = Vector2(896,72)
		context_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_guard = Control.new()
	modal_guard.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_guard.visible = false
	ui.add_child(modal_guard)
	pause_menu = PauseMenu.new()
	modal_guard.add_child(pause_menu)
	pause_menu.configure(balance.perks)
	pause_menu.resume_pressed.connect(func(): set_pause_open(false))
	pause_menu.leave_pressed.connect(_leave_or_return)
	pause_menu.reward_requested.connect(show_rewards)
	pause_menu.main_action_pressed.connect(_menu_action)
	pause_menu.display_mode_requested.connect(toggle_fullscreen)
	reward_overlay = RewardOverlay.new()
	modal_guard.add_child(reward_overlay)
	reward_overlay.configure(balance.get("reward_presentation",{}))
	reward_overlay.perk_selected.connect(func(index: int): _send_action("perk",index); _refresh_ui())
	reward_overlay.ready_requested.connect(_menu_action)
	reward_overlay.close_requested.connect(func(): set_pause_open(false))
	reward_overlay.menu_requested.connect(func(): set_pause_open(true,"overview"))
	_build_main_menu()


## Title screen from main. Story opens the story choice
## (assets/data/story_campaigns.json), then the hero choice. Endless (open
## floors, src/dungeon/open_floor.gd) shows as coming soon. Online accounts
## (Firebase, not decided) are not wired yet.
func _build_main_menu() -> void:
	main_menu = MainMenu.new()
	main_menu.account = null
	main_menu.classes = balance.get("classes",{})
	main_menu.class_order = balance.get("class_order",[])
	main_menu.weapons = balance.get("weapons",{})
	main_menu.endless_available = false
	main_menu.stories = _load_stories()
	main_menu.debug_entries = _debug_entries()
	main_menu.hell_entries = _hell_entries()
	ui.add_child(main_menu)
	main_menu.start_requested.connect(_start_solo)
	main_menu.settings_changed.connect(_apply_menu_settings)
	main_menu.multiplayer_requested.connect(func():
		menu_open = false
		_refresh_ui())
	main_menu.quit_requested.connect(func(): get_tree().quit())
	main_menu.rooms_saved.connect(_use_saved_rooms)
	main_menu.room_test_requested.connect(_start_room_test)
	main_menu.hell_requested.connect(_start_hell)
	main_menu.story_scene_requested.connect(_open_story_scene)
	# Saved fullscreen is applied in _ready, only when the game opens on the menu.
	view.shake_scale = 1.0 if bool(main_menu.settings.get("shake", true)) else 0.0


## Hell-Dungeon world for the debug level choice: one entry per baked floor.
func _hell_entries() -> Array:
	var entries: Array = []
	for f: Dictionary in HellFloorData.load_all():
		entries.append({"floor": int(f.n), "title": str(f.title), "boss": str(f.boss.name)})
	return entries


## Leaves the crypt for the Hell-Dungeon scene on that floor, at its entrance
## or right in its boss room.
func _start_hell(floor_number: int, boss: bool) -> void:
	var hell: Node = HellScene.instantiate()
	hell.start_floor = floor_number
	hell.start_at_boss = boss
	var tree := get_tree()
	tree.root.add_child(hell)
	tree.current_scene = hell
	queue_free()

## Swaps the menu for a story's own scene (e.g. the Frostgruft) with the chosen hero class.
func _open_story_scene(path: String, class_id: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	if "class_id" in scene:
		scene.class_id = class_id
	var tree := get_tree()
	var old := tree.current_scene
	tree.root.add_child(scene)
	tree.current_scene = scene
	if old != null:
		old.queue_free()


## The story campaigns of the main menu; [] when the file is missing.
func _load_stories() -> Array:
	var path := "res://assets/data/story_campaigns.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return parsed.get("stories", []) if parsed is Dictionary else []


## Debug level list for the current crypt floor: every room of floor 1 (the
## last one is the boss) and the start of floor 2.
func _debug_entries() -> Array:
	var entries: Array = []
	var count := _run_room_count()
	for number in range(1, count + 1):
		var label := "KRYPTA · RAUM %02d" % number
		if number == 1: label += " · EINGANG"
		elif number == count: label += " · ENDRAUM"
		entries.append({"label": label, "endless": false, "floor": 1, "room": number})
	entries.append({"label": "EBENE 2 · START", "endless": false, "floor": 2, "room": 1})
	# Final rooms of the mini-boss floors and the boss floor (enemy_roster.floor_plan).
	var plan: Dictionary = balance.get("enemy_roster",{}).get("floor_plan",{})
	var names := {"moderkoloss":"MODERKOLOSS","frostleiche":"FROSTLEICHE","knochenkoloss":"KNOCHENKOLOSS"}
	var floors: Array = plan.get("minibosses",{}).keys()
	floors.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	for key: String in floors:
		entries.append({"label": "EBENE %d · %s" % [int(key), names.get(str(plan.minibosses[key]), str(plan.minibosses[key]).to_upper())], "endless": false, "floor": int(key), "room": count})
	entries.append({"label": "EBENE %d · LEERENRUFER" % int(plan.get("boss_floor",10)), "endless": false, "floor": int(plan.get("boss_floor",10)), "room": count})
	return entries


## The rooms a floor may use (room_pool.gd): each room's floor range, plus
## the room being test-played.
func _floor_pool(floor_number: int) -> Dictionary:
	return RoomPool.for_floor(dungeon_config, floor_number, _run_room_count(), test_room_id)


## The Dungeon-Werkstatt saved the room library: new runs use it at once.
func _use_saved_rooms(config: Dictionary) -> void:
	if Dungeon.validate_config(config).is_empty(): dungeon_config = config.duplicate(true)


## Dungeon-Werkstatt test play: a solo run on `floor_number` that contains
## `room_id` and starts in it (a boss room is the floor's last room).
func _start_room_test(room_id: String, floor_number: int, class_id: String) -> void:
	var boss := false
	for room: Dictionary in dungeon_config.get("templates", []):
		if str(room.id) == room_id: boss = bool(room.get("boss", false))
	test_room_id = room_id
	test_room_floor = maxi(1, floor_number)
	return_to_room_editor = true
	main_menu.queue_debug_start({"label": "TEST", "endless": false, "floor": test_room_floor, "room": _run_room_count() if boss else 1})
	_start_solo(false, class_id)


## Story button / debug pick: a solo host run, optionally jumping to a level.
func _start_solo(_endless_mode: bool = false, class_id: String = "") -> void:
	menu_open = false
	var jump: Dictionary = main_menu.take_debug_start()
	# Endless runs play open floors; stories and debug jumps play the chain of
	# rooms of their room library.
	open_floors = _endless_mode
	story_id = main_menu.selected_story if not main_menu.selected_story.is_empty() else "krypta"
	# The solo host is always peer 1; its class applies when the player is added.
	player_classes[1] = HeroClass.resolve(class_id, balance)
	_host_session()
	if not (active and hosting):
		menu_open = true
		main_menu.show_toast(status_message)
		_refresh_ui()
		return
	_server_action(1, "start", 0)
	if not jump.is_empty() and phase == "combat": _debug_jump(int(jump.floor), int(jump.room))
	_refresh_ui()


## Debug only: moves a fresh solo run to `target_room` of `target_floor`. Rooms
## before it count as cleared, so doors and the map behave as after playing them.
func _debug_jump(target_floor: int, target_room: int) -> void:
	if target_floor > 1:
		# Generate the target floor directly (its seed follows the run seed).
		floor_index = target_floor - 1
		_enter_next_floor()
	var number := clampi(target_room, 1, floor_layouts.size())
	if number == room: return
	for index in range(number - 1):
		var identifier := str(floor_layouts[index].id)
		if not cleared_room_ids.has(identifier): cleared_room_ids.append(identifier)
	room = number
	_spawn_room()
	_broadcast_state(true)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and is_ancestor_of(node): _hook_button_sound(node)


## Connects one button to the UI click sound; back/leave buttons sound softer.
func _hook_button_sound(button: BaseButton) -> void:
	var callback := _button_sound.bind(button)
	if not button.pressed.is_connected(callback): button.pressed.connect(callback)


func _button_sound(button: BaseButton) -> void:
	var label := str(button.get("text")).to_upper() if "text" in button else ""
	var back := label.contains("ZURÜCK") or label.contains("VERLASSEN") or label.contains("ABBRECHEN") or label.contains("SCHLIESSEN") or label.contains("BEENDEN")
	view.play_ui_sound("ui_back" if back else "ui_click")


func _open_main_menu() -> void:
	menu_open = true
	_refresh_ui()


## Lobby: asks the host for the next hero class in balance.class_order.
func _cycle_class() -> void:
	var order: Array = balance.get("class_order",[])
	if order.is_empty(): return
	var local: Dictionary = state.get("players",{}).get(multiplayer.get_unique_id(),{})
	var current: int = order.find(str(local.get("class_id","")))
	_send_action("class",(current+1)%order.size())


func _class_label(class_id: String) -> String:
	return str(balance.get("classes",{}).get(class_id,{}).get("name",class_id)).to_upper()


## Options from the main menu: fullscreen uses the game's own toggle (keeps the
## window rectangle), screen shake scales the view's camera shake.
func _apply_menu_settings(settings: Dictionary) -> void:
	view.shake_scale = 1.0 if bool(settings.get("shake", true)) else 0.0
	if DisplayServer.get_name() != "headless" and bool(settings.get("fullscreen", false)) != is_fullscreen():
		toggle_fullscreen()


func _label(text: String, position: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = dimensions
	label.add_theme_font_size_override("font_size", 16 if font_size < 20 else 24 if font_size < 28 else 32)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(label)
	return label


func _button(text: String, position: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 16)
	# Frames and colours come from the shared crypt theme (CryptUI).
	button.pressed.connect(callback)
	ui.add_child(button)
	return button


func _main_action() -> void:
	_send_action("ready" if phase == "reward" else "interact" if phase == "explore" else "start")


func _menu_action() -> void:
	_main_action()
	if phase in ["combat","explore"]: set_pause_open(false)
	else: _refresh_ui()


func _refresh_ui() -> void:
	var visible_players: Dictionary = state.get("players", {})
	var maximum_players := int(balance.network.max_players)
	var local_id := multiplayer.get_unique_id() if active else 0
	var local_player: Dictionary = visible_players.get(local_id, {})
	var in_run := _in_run()
	if not in_run: _refresh_lobby_ui(visible_players,local_id,local_player,maximum_players)
	var automatic_reward := false
	var offer_key := str(state.get("floor_index",1))+":"+str(state.get("room_layout",{}).get("id",""))
	if in_run and phase == "reward" and not is_transitioning() and offer_key != _auto_reward_key:
		_auto_reward_key = offer_key
		pause_open = true
		reward_open = true
		_fire_needs_release = true
		automatic_reward = true
		_send_local_input()
	var menu_visible := is_instance_valid(main_menu) and menu_open and not active and not editor_preview_mode
	if is_instance_valid(main_menu): main_menu.visible = menu_visible
	# Menu and lobby get the calm music; a run gets explore/combat/boss.
	view.music_in_run = in_run
	lobby_ui.visible = not in_run and not menu_visible
	_apply_display_layout()
	if pause_open and (not in_run or (_ui_phase == "reward" and phase == "explore" and reward_open)):
		pause_open = false
		reward_open = false
		_fire_needs_release = true
	# The run HUD steps aside while the pause or reward screen is open.
	run_hud.visible = in_run and not pause_open
	if run_hud.visible: run_hud.set_state(state,local_id)
	level_cards.set_state(state,local_id)
	if not run_hud.visible: level_cards.visible = false
	inventory_panel.visible = run_hud.visible
	if inventory_panel.visible: inventory_panel.set_state(state,local_id)
	elif inventory_panel.open: inventory_panel.set_open(false)
	menu_button.visible = in_run and not pause_open
	pause_menu.visible = in_run and pause_open and not reward_open
	if pause_menu.visible:
		pause_menu.set_state(state,local_id,hosting,_port(),is_solo_paused())
		pause_menu.set_display_state(is_fullscreen(),get_viewport_rect().size)
	reward_overlay.visible = in_run and pause_open and reward_open
	modal_guard.visible = in_run and pause_open
	if reward_overlay.visible: reward_overlay.set_state(state,local_id,is_solo_paused())
	if automatic_reward:
		reward_overlay.play_entrance()
		reward_overlay.focus_initial()
	view.set_animation_enabled(not is_solo_paused())
	context_hint.text = "BELOHNUNG · KARTE WÄHLEN" if phase == "reward" else "GEFALLEN · ESC FÜR DEN NÄCHSTEN SCHRITT" if phase == "dead" else ""
	if phase == "explore" and not local_player.is_empty() and local_player.get("hp",0) > 0:
		var position := Vector2(local_player.x,local_player.y)
		for exit: Dictionary in state.get("room_layout",{}).get("exits",[]):
			if position.distance_to(_exit_center(exit)) <= float(balance.exploration.interaction_radius):
				# Say where a door leads: on to the next room or back.
				var floor_number := int(state.get("floor_index", 1))
				if exit.kind == "stairs": context_hint.text = ("E · HINAB ZU EBENE %d" % (floor_number + 1)) if bool(state.get("stairs_open", true)) else "TREPPE VERSPERRT · BESIEGT DEN WÄCHTER DER EBENE"
				elif bool(exit.get("forward", false)): context_hint.text = "E · WEITER ZU RAUM %d / %d" % [int(exit.target_room), _run_room_count()]
				else: context_hint.text = "E · ZURÜCK ZU RAUM %d" % int(exit.target_room)
	if throw_slot >= 0 and in_run and not pause_open: context_hint.text = "KLICK: DORTHIN WERFEN · ESC BRICHT AB"
	context_hint.visible = in_run and not pause_open and not context_hint.text.is_empty()
	if editor_preview_mode and in_run and not pause_open:
		context_hint.text = "VORSCHAU · WASD bewegen · Maus zielen / schießen · Zurück oben\n"+_editor_preview_notice
		context_hint.visible = true
	if _ui_phase != phase: queue_redraw()
	_ui_phase = phase


func _refresh_lobby_ui(visible_players: Dictionary, local_id: int, local_player: Dictionary, maximum_players: int) -> void:
	session_label.text = "HOST · UDP %d\n%d / %d WANDERER" % [_port(), visible_players.size(), maximum_players] if active and hosting else "CLIENT · VERBUNDEN\n%d / %d WANDERER" % [visible_players.size(), maximum_players] if active else "GODOT 4.7.2\nENTWICKLUNGSPROTOTYP"
	if phase == "connecting": session_label.text = "CLIENT · VERBINDET …"
	var names := {"menu": "DIE LOBBY", "connecting": "VERBINDEN …", "lobby": "EURE GRUPPE", "combat": "RAUM %02d / %02d" % [room,_run_room_count()], "reward": "WÄHLE DEINEN PERK", "explore": "FREI ERKUNDEN", "dead": "DIE TIEFE SIEGT", "victory": "BOSS BESIEGT"}
	phase_label.text = names.get(phase, phase.to_upper())
	floor_map.visible = active and not state.get("floor_map", []).is_empty()
	floor_map.set_floor(state.get("floor_map", []), str(state.get("room_layout", {}).get("id", "")))
	party_label.text = ("%d Räume je Ebene.\n%d Perks.\nBis zu %d Wanderer.\n\nDirekte IP:\nUDP-Port nötig.\nKein Relay." % [_run_room_count(),balance.perks.size(),maximum_players]) if not active else ""
	var index := 1
	for id in visible_players:
		var player: Dictionary = visible_players[id]
		var suffix := (" · DU" if int(id) == local_id else "") + (" · HOST" if int(id) == 1 else "")
		var condition := "%d/%d LP" % [player.hp, player.max_hp] if player.hp > 0 else "GEFALLEN"
		if phase == "reward" and player.ready: condition += " · BEREIT"
		# Two lines per hero: slot and class, then health and role.
		party_label.text += "P%d · %s\n  %s%s\n" % [index, _class_label(str(player.get("class_id",""))), condition, suffix]
		index += 1
	if active:
		for free in range(index, maximum_players + 1): party_label.text += "P%d · FREIER PLATZ\n" % free
	status_label.text = status_message
	if phase == "combat": status_label.text = "Ebene %d · Raum %d · %s · Besiegt alle Gegner." % [state.get("floor_index", 1), room, state.get("room_layout", {}).get("title", "")]
	elif phase == "reward": status_label.text = "Raum gesichert. Wählt je einen Perk und bestätigt BEREIT. Ihr könnt weiterlaufen."
	elif phase == "explore": status_label.text = "Ebene %d frei erkunden · Team am Ausgang sammeln · E an einer Tür oder der Treppe drücken." % state.get("floor_index", 1)
	elif phase == "victory": status_label.text = "Geschafft. Ihr habt alle %d Räume und den Boss besiegt. Der Host kann einen neuen Lauf starten." % state.get("floor_map",[]).size()
	elif phase == "dead": status_label.text = "Alle Wanderer sind gefallen. Der Host kann den Lauf mit einem neuen Seed neu starten."
	for node in [address_input, port_input, host_button, join_button, lobby_menu_button]: node.visible = not active
	class_button.visible = active and phase == "lobby" and not local_player.is_empty()
	# Plain ASCII arrows: Pixel Operator 8 has no ► glyph.
	if class_button.visible: class_button.text = "< %s >" % _class_label(str(local_player.get("class_id","")))
	class_button.tooltip_text = "Klasse wechseln (gilt ab dem Laufstart)"
	leave_button.visible = active
	action_button.visible = active
	action_button.disabled = true
	action_button.text = "HOST STARTET" if phase == "lobby" else "RAUM SÄUBERN"
	if phase in ["lobby", "dead", "victory"] and hosting:
		action_button.text = "RUN STARTEN" if phase == "lobby" else "NEUER LAUF"
		action_button.disabled = false
	elif phase == "reward":
		action_button.text = "BEREIT" if local_player.get("ready", false) else "ERKUNDUNG FREIGEBEN"
		action_button.disabled = not local_player.get("picked", false) or local_player.get("ready", false) or local_player.get("hp", 0) <= 0
	elif phase == "explore":
		action_button.text = "TÜR / TREPPE NUTZEN [E]"
		action_button.disabled = local_player.get("hp", 0) <= 0
