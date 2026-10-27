@tool
extends Node2D
## Editor-visible, F6-runnable art comparison. It never starts a game or peer.

const HealthStrip = preload("res://src/health_strip.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const COLORS := [Color("72dcc8"), Color("edb563"), Color("bc91de"), Color("ed8a91")]

@export_enum("Gesamtbild", "Raum", "Figuren und Effekte", "HUD") var view_mode := 0:
	set(value):
		view_mode = clampi(value, 0, 3)
		_request_refresh()
@export_enum("violet", "rose", "moss", "amber") var palette := "violet":
	set(value):
		palette = value
		_request_refresh()
@export_range(0, 60, 1) var health := 7:
	set(value):
		health = clampi(value, 0, maximum_health)
		_request_refresh()
@export_range(2, 60, 2) var maximum_health := 8:
	set(value):
		maximum_health = clampi(value, 2, 60)
		health = mini(health, maximum_health)
		_request_refresh()
@export var animate := true:
	set(value):
		animate = value
		_request_refresh()
@export var effects := true:
	set(value):
		effects = value
		_request_refresh()
@export var open_exits := true:
	set(value):
		open_exits = value
		_request_refresh()
@export var style_profile: Resource = preload("res://assets/data/art_style_reference.tres"):
	set(value):
		if style_profile != null and style_profile.changed.is_connected(_request_refresh):
			style_profile.changed.disconnect(_request_refresh)
		style_profile = value
		if style_profile != null: style_profile.changed.connect(_request_refresh)
		_request_refresh()

var _refresh_queued := false
var _clock := 0.0
var _snapshot: Dictionary = {}
var _hit_pulse := false

func _ready() -> void:
	$Controls/Footer.text = "F6: STILANSICHT · F5: SPIEL · 32×32 RASTER · ANIMATION-STUDIO.CMD: ALLE48 ABLÄUFE"
	if style_profile != null and not style_profile.changed.is_connected(_request_refresh):
		style_profile.changed.connect(_request_refresh)
	for index in range(4):
		get_node("Controls/Mode%d" % index).pressed.connect(_select_mode.bind(index))
	var palette_menu: OptionButton = $Controls/Palette
	palette_menu.clear()
	for name in ["violet", "rose", "moss", "amber"]: palette_menu.add_item(name.to_upper())
	palette_menu.disabled = true
	palette_menu.tooltip_text = "Festgelegter Stil: ruhige Schieferkrypta mit warmem Feuer."
	palette_menu.item_selected.connect(func(index: int): palette = ["violet", "rose", "moss", "amber"][index])
	$Controls/Health.value_changed.connect(func(value: float): health = int(value))
	$Controls/Maximum.value_changed.connect(func(value: float): maximum_health = int(value))
	$Controls/Animate.toggled.connect(func(value: bool): animate = value)
	$Controls/Effects.toggled.connect(func(value: bool): effects = value)
	$Controls/Doors.toggled.connect(func(value: bool): open_exits = value)
	_refresh()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("170d24"))
	draw_rect(Rect2(24, 16, 1232, 114), Color("291538"))
	draw_rect(Rect2(24, 16, 1232, 114), Color("764890"), false, 2)
	draw_rect(Rect2(944, 156, 312, 480), Color("291538"))
	draw_rect(Rect2(944, 156, 312, 480), Color("764890"), false, 2)
	if view_mode in [2, 3]:
		for y in range(156, 636, 16):
			for x in range(32, 928, 16):
				var tint := Color("21172c") if ((x / 16 + y / 16) as int) % 2 == 0 else Color("291e35")
				draw_rect(Rect2(x, y, 16, 16), tint)

func _process(delta: float) -> void:
	if not animate or _snapshot.is_empty(): return
	_clock += delta
	# Deliberate art demonstration, not simulated combat or a claimed playtest.
	var player: Dictionary = _snapshot.players[2]
	var pulse := fmod(_clock,3.0) < 0.16
	if pulse and not _hit_pulse: player.hurts = int(player.get("hurts",0))+1
	_hit_pulse = pulse
	player.hit_flash = 0.16 if fmod(_clock, 3.0) < 0.16 else 0.0
	player.hitstun = 0.18 if fmod(_clock, 3.0) < 0.18 else 0.0
	player.ax = cos(_clock)
	player.ay = sin(_clock)
	for index: int in range(_snapshot.enemies.size()):
		var enemy: Dictionary = _snapshot.enemies[index]
		var cycle: float = fmod(_clock+index*0.65,4.0)
		var attack: String = "windup" if cycle >= 1.0 and cycle < 1.7 else "active" if cycle >= 1.7 and cycle < 1.9 else "recovery" if cycle >= 1.9 and cycle < 2.5 else ""
		if attack == "active" and str(enemy.get("attack","")) != "active": enemy.attacks += 1
		var hurt: bool = cycle >= 3.5 and cycle < 3.65
		if hurt and not bool(enemy.get("reference_hurt",false)): enemy.hits += 1
		enemy.reference_hurt = hurt
		enemy.attack = attack
		enemy.attack_p = clampf((cycle-1.0)/0.7,0,1) if attack == "windup" else 0.0
		enemy.moving = cycle < 1.0
	$Dungeon.set_state(_snapshot, 1)

func _request_refresh() -> void:
	if not is_inside_tree() or not is_node_ready() or _refresh_queued: return
	_refresh_queued = true
	_refresh.call_deferred()

func _select_mode(index: int) -> void:
	view_mode = index

func _refresh() -> void:
	_refresh_queued = false
	$Controls.theme = PixelStyle.create_theme()
	var art: Dictionary = style_profile.as_dictionary() if style_profile != null and style_profile.has_method("as_dictionary") else {}
	var layout := {
		"id": "reference-room", "theme": palette, "title": "REFERENZRAUM",
		"render_style":"classic_quiet","decoration_enabled":false,
		"world_size": [896, 480], "play_bounds": [32, 48, 832, 400], "tile_size": 32,
		"art_style": art,
		"brazier_spawns": [Vector2(72, 78), Vector2(792, 196), Vector2(72, 402), Vector2(824, 402)],
		"obstacles": [[32, 128, 96, 64], [288, 96, 96, 32], [672, 96, 192, 64], [256, 320, 64, 64], [480, 320, 96, 32]],
		"exits": [
			{"id": "north", "kind": "door", "side": "north", "rect": [432, 48, 32, 32], "target_room": 1},
			{"id": "east", "kind": "door", "side": "east", "rect": [832, 232, 32, 32], "target_room": 3},
			{"id": "descent", "kind": "stairs", "side": "south", "rect": [704, 352, 32, 32], "target_room": 0}]
	}
	var players := {}
	for index in range(4):
		players[index + 1] = {"x": 192 + index * 64, "y": 216, "hp": health if index == 0 else 8, "max_hp": maximum_health if index == 0 else 8, "color": COLORS[index], "ready": false, "picked": true, "perks": [], "ax": 1.0, "ay": 0.0,"hurts":0,"shots":0,"moving":index==1}
	var map_rooms := [{"id": "room-before", "grid_x": 0, "grid_y": 0, "boss": false, "cleared": true}, {"id": "reference-room", "grid_x": 1, "grid_y": 0, "boss": false, "cleared": true}, {"id": "room-after", "grid_x": 2, "grid_y": 0, "boss": true, "cleared": false}]
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	_snapshot = {"players": players, "enemies": [{"id":1,"x": 600, "y": 240, "hp": 5, "max_hp": 8, "boss": false}, {"id":2,"x": 736, "y": 280, "hp": 50, "max_hp": 70, "boss": true}], "bullets": [{"x": 544, "y": 224, "owner": 1}, {"x": 640, "y": 288, "owner": 0}], "room_layout": layout, "floor_map": map_rooms, "floor_index": 1, "seed": 3, "phase": "explore" if open_exits else "combat", "reference_reward": true, "perk_options": balance.get("perks", []).slice(0, 3), "presentation_layers": {"room": view_mode != 2, "actors": view_mode != 1, "props": view_mode != 2, "effects": effects}}
	_snapshot.enemies = []
	for index: int in range(3):
		_snapshot.enemies.append({"id":index+1,"kind":["skeleton_archer","necromancer","skeleton_guard"][index],"x":520+index*120,"y":380,"hp":8,"max_hp":8,"boss":false,"hits":0,"attacks":0,"blocks":0,"face":-1.0,"attack":"","attack_kind":["arrow","soul","slash"][index],"attack_p":0.0,"aim_x":-1.0,"aim_y":0.0,"tx":280,"ty":380,"dying_p":-1.0})
	_snapshot.bullets = [{"id":1,"x":480,"y":380,"owner":0,"style":"arrow","vx":-230,"vy":0},{"id":2,"x":600,"y":380,"owner":0,"style":"soul","vx":-155,"vy":0}]
	$Dungeon.visible = view_mode != 3
	$Dungeon.set_animation_enabled(animate)
	$Dungeon.reset_feedback()
	$Dungeon.set_state(_snapshot, 1)
	$HealthHUD.health_only = true
	$HealthHUD.position = Vector2(56,188)
	$HealthHUD.size = Vector2(432,38)
	$HealthHUD.visible = view_mode == 3
	$HealthHUD.set_state(_snapshot, 1)
	var health_image := HealthStrip.make_image(health, maximum_health)
	$Controls/HeartImage.texture = ImageTexture.create_from_image(health_image)
	var image_zoom := maxi(1, mini(4, int(264.0 / health_image.get_width())))
	var image_size := Vector2(health_image.get_size()) * image_zoom
	$Controls/HeartImage.size = image_size
	$Controls/HeartImage.position = Vector2(968, 520) + ((Vector2(264, 32) - image_size) * 0.5).floor()
	for index in range(4): get_node("Controls/Mode%d" % index).set_pressed_no_signal(index == view_mode)
	$Controls/Palette.select(["violet", "rose", "moss", "amber"].find(palette))
	$Controls/Health.max_value = maximum_health
	$Controls/Health.set_value_no_signal(health)
	$Controls/Maximum.set_value_no_signal(maximum_health)
	$Controls/Animate.set_pressed_no_signal(animate)
	$Controls/Effects.set_pressed_no_signal(effects)
	$Controls/Doors.set_pressed_no_signal(open_exits)
	queue_redraw()
