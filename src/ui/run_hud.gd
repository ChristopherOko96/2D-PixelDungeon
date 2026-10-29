extends Control
## The run HUD, drawn over the playfield from host snapshots (display only),
## with the HUD parts every world shares (src/ui/hud_kit.gd, neutral look of
## src/ui/hud_style.gd): the hero strip top left (hearts, team level and EXP;
## team-mates below), the boss or mini-boss bar top centre, floor, room and
## mini-map top right, and the four class skill slots in the slim bar at the
## bottom (src/ui/skill_bar.gd). Layout: assets/data/ui_run_hud.json and
## assets/data/ui_hud_style.json.

const PixelStyle = preload("res://src/pixel_style.gd")
const FloorMap = preload("res://src/dungeon/dungeon_map.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const SkillIcons = preload("res://src/ui/skill_icons.gd")
const SkillBar = preload("res://src/ui/skill_bar.gd")
const TalentBar = preload("res://src/ui/talent_bar.gd")
const HudKit = preload("res://src/ui/hud_kit.gd")
const HudStyle = preload("res://src/ui/hud_style.gd")
const RunTree = preload("res://src/progress/run_tree.gd")
const RunTreeView = preload("res://src/ui/run_tree_view.gd")
const DATA_PATH := "res://assets/data/ui_run_hud.json"
const HEART_FULL := preload("res://assets/sprites/0x72/ui_heart_full.png")
const HEART_HALF := preload("res://assets/sprites/0x72/ui_heart_half.png")
const HEART_EMPTY := preload("res://assets/sprites/0x72/ui_heart_empty.png")
const PLAYER_COLORS := [Color("72dcc8"), Color("edb563"), Color("bc91de"), Color("ed8a91")]

## Hero class names by id (balance.classes), set by the game.
var classes: Dictionary = {}
## The floor's room count for "RAUM 03 / 10".
var room_count := 10
## The run talent tree window is open (the game toggles it with B).
var tree_open := false

var _data: Dictionary = {}
var _snapshot: Dictionary = {}
var _local_peer := 0
var _font: Font
var _map: Control
## Where draw calls go: self, or one of the two top corner layers, which fade
## out while the local hero stands near them (a gate behind a panel stays visible).
var _canvas: CanvasItem
var _left: Control
var _right: Control
var _top: Control
var _focus := Vector2.INF
var _marks: Array = []
# Boss bar: the shown ratio trails real damage (white chip), per boss id.
var _boss_id := -1
var _chip := 1.0
var _flash := 0.0
var _last_ratio := 1.0
var _pulse := 0.0
## The talent bar (Shift + 1-4, R) and reward banner, the same in every map.
var _talent_bar := TalentBar.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = PixelStyle.create_font()
	_data = load_data()
	_canvas = self
	_left = _layer()
	_left.draw.connect(func(): _on_layer(_left, "left"))
	_right = _layer()
	_right.draw.connect(func(): _on_layer(_right, "right"))
	# the talent tree and the run's result sit over everything else
	_top = _layer()
	_top.draw.connect(func(): _on_layer(_top, "top"))
	_map = FloorMap.new()
	_right.add_child(_map)
	resized.connect(_layout)
	_layout()


## The HUD's layout and skill table, with defaults when the file is missing.
static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	var data: Dictionary = parsed if parsed is Dictionary else {}
	for key: String in ["margin", "heart_scale", "hearts_per_row", "map_panel_width", "boss_bar_width", "slot_height", "slot_gap"]:
		data[key] = int(data.get(key, {"margin": 20, "heart_scale": 2, "hearts_per_row": 10, "map_panel_width": 244, "boss_bar_width": 560, "slot_height": 72, "slot_gap": 8}[key]))
	data.boss_chip_speed = float(data.get("boss_chip_speed", 0.35))
	if not data.get("skills") is Dictionary: data.skills = {}
	return data


## Shows one host snapshot; called by the game whenever its UI refreshes.
func set_state(snapshot: Dictionary, local_peer: int) -> void:
	_snapshot = snapshot
	_local_peer = local_peer
	var rooms: Array = snapshot.get("floor_map", [])
	_map.visible = not rooms.is_empty()
	_map.set_floor(rooms, str(snapshot.get("room_layout", {}).get("id", "")))
	queue_redraw()


## Heart icons for `hp` of `max_hp` (two HP per heart): "full", "half", "empty".
static func hearts(hp: int, max_hp: int) -> Array[String]:
	return HudKit.heart_icons(hp, max_hp)


## The local player's heart icons from the last snapshot.
func local_hearts() -> Array[String]:
	var local: Dictionary = _snapshot.get("players", {}).get(_local_peer, {})
	return hearts(int(local.get("hp", 0)), int(local.get("max_hp", 0)))


## The enemy the top bar follows: a living boss first, else a mini-boss.
static func boss_target(snapshot: Dictionary) -> Dictionary:
	var fallback: Dictionary = {}
	for enemy: Dictionary in snapshot.get("enemies", []):
		if float(enemy.get("hp", 0)) <= 0.0 or float(enemy.get("dying_p", -1.0)) >= 0.0: continue
		if bool(enemy.get("boss", false)): return enemy
		if fallback.is_empty() and bool(enemy.get("miniboss", false)): fallback = enemy
	return fallback


## The four skill slots of a class: {key, name, unlock, ultimate}.
func skills_for(class_id: String) -> Array:
	return ClassPerks.skills(class_id)


## Bottom edge of the top-right panel; the game puts its menu button below it.
func map_panel_rect() -> Rect2:
	return HudKit.floor_rect(size)


## Top of the skill bar; the game puts its context hint above it.
func skill_bar_top() -> float:
	return SkillBar.top(size, false)


func _layer() -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	return layer


func _on_layer(layer: Control, side: String) -> void:
	if _font == null or _snapshot.is_empty(): return
	_canvas = layer
	if side == "left": _draw_hero(_snapshot.get("players", {}))
	elif side == "top":
		_draw_tree(_snapshot.get("players", {}).get(_local_peer, {}))
		_draw_result()
	else: _draw_floor_panel()
	_canvas = self


## The local hero's screen point; top corner panels fade while it is near them.
func set_focus(screen_point: Vector2, marks: Array = []) -> void:
	_focus = screen_point
	_marks = marks


## True when the hero is near the rectangle or a gate on screen lies under it.
func _covers(rect: Rect2) -> bool:
	if _focus.is_finite() and rect.grow(90).has_point(_focus): return true
	for mark: Vector2 in _marks:
		if rect.grow(24).has_point(mark): return true
	return false


## Opacity of the right corner (the game fades its menu button with it).
func right_alpha() -> float:
	return _right.modulate.a if _right != null else 1.0


func _layout() -> void:
	if _map == null: return
	var area := HudKit.map_area(size)
	_map.position = area.position
	_map.size = area.size


func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_pulse += delta
	_talent_bar.step(delta)
	var margin := float(_data.get("margin", 20))
	var left_rect := Rect2(margin, margin, 320, 110)
	var near_left := _covers(left_rect)
	var near_right := _covers(Rect2(map_panel_rect().position, map_panel_rect().size + Vector2(0, 50)))
	_left.modulate.a = move_toward(_left.modulate.a, 0.25 if near_left else 1.0, delta * 4.0)
	_right.modulate.a = move_toward(_right.modulate.a, 0.25 if near_right else 1.0, delta * 4.0)
	queue_redraw()
	var boss := boss_target(_snapshot)
	if boss.is_empty():
		_boss_id = -1
		return
	var ratio := clampf(float(boss.hp) / maxf(float(boss.get("max_hp", 1.0)), 1.0), 0.0, 1.0)
	if int(boss.get("id", -1)) != _boss_id:
		_boss_id = int(boss.get("id", -1))
		_chip = ratio
		_last_ratio = ratio
	if ratio < _last_ratio - 0.0001: _flash = 0.18
	_last_ratio = ratio
	_chip = ratio if ratio > _chip else move_toward(_chip, ratio, delta * float(_data.get("boss_chip_speed", 0.35)))
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func _draw() -> void:
	if _font == null or _snapshot.is_empty(): return
	var players: Dictionary = _snapshot.get("players", {})
	_left.queue_redraw()
	_right.queue_redraw()
	_draw_boss_bar()
	_draw_skills(players.get(_local_peer, {}))
	_draw_talents(players.get(_local_peer, {}))
	_draw_reward()
	_top.queue_redraw()


# --- Top left: hearts, hero, team -------------------------------------------

func _draw_hero(players: Dictionary) -> void:
	var local: Dictionary = players.get(_local_peer, {})
	if local.is_empty(): return
	var margin := HudStyle.size("margin")
	var order := players.keys()
	var class_name_text := str(classes.get(str(local.get("class_id", "")), {}).get("name", "WANDERER")).to_upper()
	var team: Dictionary = _snapshot.get("team", {})
	var status: Array = []
	var shield := int(local.get("shield", 0))
	if shield > 0: status.append({"text": "+%d SCHILD" % shield, "color": HudStyle.color("ok")})
	var panel := HudKit.hero_panel(_canvas, _font, Vector2(margin, margin), {"title": "P%d · %s" % [order.find(_local_peer) + 1, class_name_text],
		"hp": int(local.get("hp", 0)), "max_hp": int(local.get("max_hp", 0)), "hearts": {"full": HEART_FULL, "half": HEART_HALF, "empty": HEART_EMPTY},
		"level": int(team.get("level", 1)), "exp": float(team.get("exp", 0)) / maxf(1.0, float(team.get("next", 1))), "status": status,
		"points": RunTree.points_left(ClassPerks.run_tree(str(local.get("class_id", "")), local.get("meta", {})), ClassPerks.ranks(local), int(team.get("level", 1))),
		"low": int(local.get("hp", 0)) <= 2 and int(local.get("hp", 0)) > 0, "clock": _pulse})
	# Team-mates: one compact row each under the strip.
	var y := panel.end.y + 6.0
	for id: Variant in order:
		if id == _local_peer: continue
		var mate: Dictionary = players[id]
		var row := Rect2(margin, y, panel.size.x, 30)
		HudStyle.panel(_canvas, row)
		var tint: Color = PLAYER_COLORS[order.find(id) % PLAYER_COLORS.size()]
		_canvas.draw_rect(Rect2(row.position + Vector2(10, 10), Vector2(10, 10)), tint)
		HudStyle.text(_canvas, _font, row.position + Vector2(28, 20), "P%d" % (order.find(id) + 1), 12, HudStyle.color("text_dim"))
		var mate_icons := hearts(int(mate.get("hp", 0)), int(mate.get("max_hp", 0)))
		for index in range(mini(mate_icons.size(), 10)):
			var texture: Texture2D = HEART_FULL if mate_icons[index] == "full" else HEART_HALF if mate_icons[index] == "half" else HEART_EMPTY
			_canvas.draw_texture_rect(texture, Rect2(row.position + Vector2(56 + index * 16, 9), Vector2(13, 12)), false)
		if int(mate.get("hp", 0)) <= 0: HudStyle.text(_canvas, _font, Vector2(row.end.x - 10, row.position.y + 20), "GEFALLEN", 12, HudStyle.color("danger"), 2)
		y += 36.0


# --- Top right: floor, room, mini-map ---------------------------------------

func _draw_floor_panel() -> void:
	var floor_index := int(_snapshot.get("floor_index", 1))
	var room_text := "RAUM %02d / %02d" % [int(_snapshot.get("room", 1)), maxi(room_count, int(_snapshot.get("room", 1)))]
	# An open floor is one map without numbered rooms.
	if bool(_snapshot.get("room_layout", {}).get("open_floor", false)): room_text = "OFFENE KARTE"
	var phase := str(_snapshot.get("phase", ""))
	var tag: String = {"combat": "KAMPF", "reward": "GESICHERT", "explore": "ERKUNDEN", "dead": "GEFALLEN", "victory": "SIEG"}.get(phase, "")
	var horde: Dictionary = _snapshot.get("horde", {})
	if phase == "combat" and not horde.is_empty(): tag = "HORDE %d" % int(horde.get("left", 0))
	HudKit.floor_panel(_canvas, _font, size, {"title": "EBENE %d" % floor_index, "subtitle": room_text, "tag": tag,
		"tag_color": HudStyle.color("danger") if phase in ["combat", "dead"] else HudStyle.color("text_dim")})


# --- Middle: the run talent tree (B) ----------------------------------------

## The run talent tree window of the local hero, the same in every world
## (src/ui/run_tree_view.gd); the game sends the clicks.
func _draw_tree(local: Dictionary) -> void:
	if not tree_open or local.is_empty(): return
	var class_id := str(local.get("class_id", ""))
	var tree := ClassPerks.run_tree(class_id, local.get("meta", {}))
	for b: Dictionary in tree.branches:
		for n: Dictionary in b.nodes:
			n.icon = SkillIcons.card(ClassPerks.find(class_id, str(n.id)), class_id)
	var title := str(classes.get(class_id, {}).get("name", class_id))
	RunTreeView.draw(_canvas, _font, size, tree, ClassPerks.ranks(local), int(_snapshot.get("team", {}).get("level", 1)), {"title": title, "mouse": get_local_mouse_position()})


# --- Middle: the run's end ------------------------------------------------

## The result panel every world shares (src/ui/hud_kit.gd) once the run ended:
## the team fell (a new run begins on floor 1) or the crypt's boss is beaten.
func _draw_result() -> void:
	var phase := str(_snapshot.get("phase", ""))
	if phase not in ["dead", "victory"]: return
	var won := phase == "victory"
	var team: Dictionary = _snapshot.get("team", {})
	var lines: Array = [["ZONE", "KRYPTA"], ["ERREICHT", "EBENE %d · RAUM %02d" % [int(_snapshot.get("floor_index", 1)), int(_snapshot.get("room", 1))]],
		["TEAM-LEVEL", str(int(team.get("level", 1)))]]
	var hints := "E · NEUER LAUF   ESC · MENÜ" if _local_peer == 1 else "DER HOST STARTET DEN NEUEN LAUF   ESC · MENÜ"
	# soul crystals of this run (the host's lasting talents, main menu TALENTE)
	var crystals: Array = _snapshot.get("meta_crystals", [])
	var note := "" if won else "ALLE WANDERER SIND GEFALLEN"
	if _local_peer == 1 and crystals.size() == 2:
		note = "+%d SEELENKRISTALLE IN DIESEM LAUF · ZUSAMMEN %d" % [int(crystals[0]), int(crystals[1])]
	HudKit.result_panel(_canvas, _font, size, {"title": "KRYPTA BEZWUNGEN" if won else "LAUF BEENDET", "tone": "win" if won else "loss",
		"lines": lines, "note": note, "hints": hints})


# --- Top centre: boss bar ---------------------------------------------------

func _draw_boss_bar() -> void:
	var boss := boss_target(_snapshot)
	if boss.is_empty(): return
	var is_boss := bool(boss.get("boss", false))
	var ratio := clampf(float(boss.hp) / maxf(float(boss.get("max_hp", 1.0)), 1.0), 0.0, 1.0)
	HudKit.boss_bar(_canvas, _font, size, {"name": str(boss.get("enemy_name", "BOSS")).to_upper(), "tag": "ENDBOSS" if is_boss else "WÄCHTER DER EBENE",
		"ratio": ratio, "chip": _chip, "flash": clampf(_flash / 0.18, 0.0, 1.0), "value": "%d / %d" % [ceili(float(boss.hp)), int(boss.get("max_hp", 0))], "boss": is_boss})


# --- Bottom centre: team level, skill slots, EXP bar ------------------------

func _draw_skills(local: Dictionary) -> void:
	if local.is_empty(): return
	var class_id := str(local.get("class_id", ""))
	var skills := skills_for(class_id)
	if skills.is_empty(): return
	var state: Dictionary = local.get("skills", {})
	var cooldowns: Array = state.get("cd", [])
	var maxima: Array = state.get("max", [])
	var locked: Array = state.get("locked", [])
	var second: Array = state.get("second", [])
	var slots: Array = []
	for index in range(skills.size()):
		var skill: Dictionary = skills[index]
		var ballista := state.has("charge") and str(skill.get("id", "")) == "ballista"
		var running := (index == 3 and (state.has("rage") or state.has("beam"))) or ballista
		slots.append({"key": str(skill.get("key", index + 1)), "name": str(skill.get("name", "")), "icon": SkillIcons.skill(class_id, index),
			"cd": float(cooldowns[index]) if index < cooldowns.size() else 0.0, "max": float(maxima[index]) if index < maxima.size() else 1.0,
			"locked": bool(locked[index]) if index < locked.size() else true, "unlock": int(skill.get("unlock", 1)),
			"active": (HudStyle.color("danger") if index == 3 else HudStyle.color("accent")) if running else Color(0, 0, 0, 0),
			"charge": float(state.charge) if ballista else -1.0, "second": index < second.size() and float(second[index]) > 0.0,
			"ultimate": bool(skill.get("ultimate", false))})
	# level and EXP sit with the hearts at the top (_draw_hero)
	SkillBar.draw(_canvas, _font, size, slots, _pulse, {"mouse": get_local_mouse_position()})


# --- Talent bar and rewards (src/ui/talent_bar.gd, the same in every map) -----

func _draw_talents(local: Dictionary) -> void:
	_talent_bar.draw_bar(_canvas, local.get("talents", {}), size.x * 0.5, skill_bar_top() - 74.0)


## Shows a reward on this machine (soul shard, level up); queued, one at a time.
func show_reward(event: Dictionary) -> void:
	_talent_bar.show_reward(event)


func _draw_reward() -> void:
	_talent_bar.draw_reward(_canvas, Vector2(size.x * 0.5, size.y * 0.24))
