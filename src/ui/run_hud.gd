extends Control
## The run HUD, drawn over the playfield from host snapshots (display only):
## hearts and hero top left (team-mates below), the boss or mini-boss bar with
## its name top centre, floor, room and mini-map top right, and the four class
## skill slots bottom centre. Layout and skill names: assets/data/ui_run_hud.json.

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const FloorMap = preload("res://src/dungeon/dungeon_map.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const SkillIcons = preload("res://src/ui/skill_icons.gd")
const DATA_PATH := "res://assets/data/ui_run_hud.json"
const HEART_FULL := preload("res://assets/sprites/0x72/ui_heart_full.png")
const HEART_HALF := preload("res://assets/sprites/0x72/ui_heart_half.png")
const HEART_EMPTY := preload("res://assets/sprites/0x72/ui_heart_empty.png")
const PLAYER_COLORS := [Color("72dcc8"), Color("edb563"), Color("bc91de"), Color("ed8a91")]

## Hero class names by id (balance.classes), set by the game.
var classes: Dictionary = {}
## The floor's room count for "RAUM 03 / 10".
var room_count := 10

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
var _focus := Vector2.INF
var _marks: Array = []
# Boss bar: the shown ratio trails real damage (white chip), per boss id.
var _boss_id := -1
var _chip := 1.0
var _flash := 0.0
var _last_ratio := 1.0
var _pulse := 0.0


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
	var result: Array[String] = []
	var health := clampi(hp, 0, maxi(max_hp, 0))
	for index in range(ceili(maxi(max_hp, 0) / 2.0)):
		var left := health - index * 2
		result.append("full" if left >= 2 else "half" if left == 1 else "empty")
	return result


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
	var margin := float(_data.get("margin", 20))
	var width := float(_data.get("map_panel_width", 244))
	return Rect2(size.x - margin - width, margin, width, 152)


## Top of the skill bar; the game puts its context hint above it.
func skill_bar_top() -> float:
	return size.y - float(_data.get("margin", 20)) - float(_data.get("slot_height", 72)) - 12.0


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
	var panel := map_panel_rect()
	_map.position = panel.position + Vector2(12, 86)
	_map.size = Vector2(panel.size.x - 24, panel.size.y - 96)


func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_pulse += delta
	var margin := float(_data.get("margin", 20))
	var left_rect := Rect2(margin, margin, 320, 140)
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


# --- Top left: hearts, hero, team -------------------------------------------

func _draw_hero(players: Dictionary) -> void:
	var local: Dictionary = players.get(_local_peer, {})
	if local.is_empty(): return
	var margin := float(_data.margin)
	var scale_factor := float(_data.heart_scale)
	var heart := Vector2(HEART_FULL.get_width(), HEART_FULL.get_height()) * scale_factor
	var icons := hearts(int(local.get("hp", 0)), int(local.get("max_hp", 0)))
	var per_row := maxi(1, int(_data.hearts_per_row))
	var rows := maxi(1, ceili(icons.size() / float(per_row)))
	var order := players.keys()
	var class_name_text := str(classes.get(str(local.get("class_id", "")), {}).get("name", "WANDERER")).to_upper()
	var title := "P%d · %s" % [order.find(_local_peer) + 1, class_name_text]
	var health_text := "%d / %d" % [int(local.get("hp", 0)), int(local.get("max_hp", 0))] if int(local.get("hp", 0)) > 0 else "GEFALLEN"
	# The panel grows to fit the name line and the heart row with its HP number.
	var heart_row := minf(icons.size(), per_row) * (heart.x + 4.0)
	var width := maxf(232.0, maxf(_width(title, 16) + 28.0, heart_row + _width(health_text, 16) + 44.0))
	var height := 44.0 + rows * (heart.y + 4.0) + 8.0
	var panel := Rect2(margin, margin, width, height)
	CryptUI.draw_box(_canvas, "panel", panel)
	_text(Vector2(panel.position.x + 14, panel.position.y + 26), title, 16, CryptUI.GOLD)
	_text_right(Vector2(panel.end.x - 14, panel.position.y + 38 + heart.y - 4), health_text, 16, CryptUI.BONE if int(local.get("hp", 0)) > 0 else CryptUI.BLOOD)
	for index in range(icons.size()):
		var at := panel.position + Vector2(14 + (index % per_row) * (heart.x + 4.0), 38 + (index / per_row) * (heart.y + 4.0))
		_canvas.draw_texture_rect(HEART_FULL if icons[index] == "full" else HEART_HALF if icons[index] == "half" else HEART_EMPTY, Rect2(at, heart), false)
	var shield := int(local.get("shield", 0))
	if shield > 0:
		_text_right(Vector2(panel.end.x - 14, panel.end.y - 10), "+%d SCHILD" % shield, 16, CryptUI.FROST)
	# Team-mates: one compact row each under the panel.
	var y := panel.end.y + 8.0
	for id: Variant in order:
		if id == _local_peer: continue
		var mate: Dictionary = players[id]
		var row := Rect2(margin, y, width, 34)
		CryptUI.draw_box(_canvas, "inset", row)
		var tint: Color = PLAYER_COLORS[order.find(id) % PLAYER_COLORS.size()]
		_canvas.draw_rect(Rect2(row.position + Vector2(10, 11), Vector2(12, 12)), tint)
		_text(row.position + Vector2(30, 23), "P%d" % (order.find(id) + 1), 16, CryptUI.BONE)
		var mate_icons := hearts(int(mate.get("hp", 0)), int(mate.get("max_hp", 0)))
		for index in range(mini(mate_icons.size(), 10)):
			var texture: Texture2D = HEART_FULL if mate_icons[index] == "full" else HEART_HALF if mate_icons[index] == "half" else HEART_EMPTY
			_canvas.draw_texture_rect(texture, Rect2(row.position + Vector2(64 + index * 16, 10), Vector2(13, 12)), false)
		if int(mate.get("hp", 0)) <= 0: _text_right(Vector2(row.end.x - 10, row.position.y + 23), "GEFALLEN", 16, CryptUI.BLOOD)
		y += 40.0


# --- Top right: floor, room, mini-map ---------------------------------------

func _draw_floor_panel() -> void:
	var panel := map_panel_rect()
	CryptUI.draw_box(_canvas, "panel", panel)
	var floor_index := int(_snapshot.get("floor_index", 1))
	_text(panel.position + Vector2(14, 32), "EBENE %d" % floor_index, 24, CryptUI.GOLD)
	var room_text := "RAUM %02d / %02d" % [int(_snapshot.get("room", 1)), maxi(room_count, int(_snapshot.get("room", 1)))]
	# An open floor is one map without numbered rooms.
	if bool(_snapshot.get("room_layout", {}).get("open_floor", false)): room_text = "OFFENE KARTE"
	_text(panel.position + Vector2(14, 54), room_text, 16, CryptUI.BONE)
	var phase := str(_snapshot.get("phase", ""))
	var tag: String = {"combat": "KAMPF", "reward": "GESICHERT", "explore": "ERKUNDEN", "dead": "GEFALLEN", "victory": "SIEG"}.get(phase, "")
	var horde: Dictionary = _snapshot.get("horde", {})
	if phase == "combat" and not horde.is_empty(): tag = "HORDE %d" % int(horde.get("left", 0))
	if not tag.is_empty():
		_text(panel.position + Vector2(14, 76), tag, 16, CryptUI.BLOOD if phase in ["combat", "dead"] else CryptUI.SAND)


# --- Top centre: boss bar ---------------------------------------------------

func _draw_boss_bar() -> void:
	var boss := boss_target(_snapshot)
	if boss.is_empty(): return
	var width := minf(float(_data.boss_bar_width), size.x - 2.0 * (float(_data.map_panel_width) + float(_data.margin) * 2.0))
	if width < 200.0: return
	var top := float(_data.margin)
	var frame := Rect2((size.x - width) * 0.5, top + 34, width, 32)
	var is_boss := bool(boss.get("boss", false))
	_text_centered(Vector2(size.x * 0.5, top + 26), str(boss.get("enemy_name", "BOSS")).to_upper(), 24, CryptUI.CREAM)
	var tag := "ENDBOSS" if is_boss else "WÄCHTER DER EBENE"
	_text_centered(Vector2(size.x * 0.5, frame.end.y + 20), tag, 16, CryptUI.VOID if is_boss else CryptUI.SAND)
	CryptUI.draw_box(_canvas, "inset", frame)
	var inner := Rect2(frame.position + Vector2(6, 6), frame.size - Vector2(12, 12))
	var ratio := clampf(float(boss.hp) / maxf(float(boss.get("max_hp", 1.0)), 1.0), 0.0, 1.0)
	_canvas.draw_rect(inner, CryptUI.BLOOD_DARK)
	_canvas.draw_rect(Rect2(inner.position, Vector2(floorf(inner.size.x * maxf(_chip, ratio)), inner.size.y)), CryptUI.CREAM)
	var fill_color := (CryptUI.VOID if is_boss else CryptUI.BLOOD).lerp(CryptUI.CREAM, clampf(_flash / 0.18, 0.0, 1.0) * 0.6)
	_canvas.draw_rect(Rect2(inner.position, Vector2(floorf(inner.size.x * ratio), inner.size.y)), fill_color)
	_canvas.draw_rect(Rect2(inner.position, Vector2(floorf(inner.size.x * ratio), 4)), Color(1, 1, 1, 0.18))
	# Quarter marks help read the phases at a glance.
	for quarter in [0.25, 0.5, 0.75]:
		_canvas.draw_rect(Rect2(inner.position + Vector2(floorf(inner.size.x * quarter), 0), Vector2(2, inner.size.y)), Color(CryptUI.INK, 0.6))
	_text_centered(Vector2(size.x * 0.5, inner.end.y - 3), "%d / %d" % [ceili(float(boss.hp)), int(boss.get("max_hp", 0))], 16, CryptUI.CREAM)


# --- Bottom centre: team level, skill slots, EXP bar ------------------------

func _draw_skills(local: Dictionary) -> void:
	if local.is_empty(): return
	var class_id := str(local.get("class_id", ""))
	var skills := skills_for(class_id)
	if skills.is_empty(): return
	var state: Dictionary = local.get("skills", {})
	var slot := float(_data.slot_height)
	var gap := float(_data.slot_gap)
	var count := skills.size() + 1
	var total := slot * count + gap * (count - 1)
	var x := floorf((size.x - total) * 0.5)
	var y := skill_bar_top()
	# Team level chip.
	var team: Dictionary = _snapshot.get("team", {})
	var chip := Rect2(x, y, slot, slot)
	CryptUI.draw_box(_canvas, "slot_ready", chip)
	_text_centered(Vector2(chip.get_center().x, chip.position.y + 24), "LV", 16, CryptUI.SAND)
	_text_centered(Vector2(chip.get_center().x, chip.position.y + 54), str(int(team.get("level", 1))), 32, CryptUI.GOLD)
	x += slot + gap
	var cooldowns: Array = state.get("cd", [])
	var maxima: Array = state.get("max", [])
	var locked: Array = state.get("locked", [])
	var second: Array = state.get("second", [])
	for index in range(skills.size()):
		var skill: Dictionary = skills[index]
		var rect := Rect2(x, y, slot, slot)
		var is_locked: bool = bool(locked[index]) if index < locked.size() else true
		var cooldown: float = float(cooldowns[index]) if index < cooldowns.size() else 0.0
		var maximum: float = maxf(float(maxima[index]) if index < maxima.size() else 1.0, 0.01)
		var ready := not is_locked and cooldown <= 0.0
		var active := (index == 3 and (state.has("rage") or state.has("beam"))) or (state.has("charge") and str(skill.get("id", "")) == "ballista")
		CryptUI.draw_box(_canvas, "slot_ready" if ready else "slot", rect)
		var icon := SkillIcons.skill(class_id, index)
		var tint := Color(0.3, 0.28, 0.28) if is_locked else Color(0.62, 0.6, 0.6) if cooldown > 0.0 else Color.WHITE
		_canvas.draw_texture_rect(icon, Rect2(rect.position + Vector2(4, 4), Vector2(slot - 8, slot - 8)), false, tint)
		if not is_locked and cooldown > 0.0:
			# Cooldown sweep: the dark part shrinks from the top as it recharges.
			var share := clampf(cooldown / maximum, 0.0, 1.0)
			_canvas.draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(slot - 8, (slot - 8) * share)), Color(CryptUI.INK, 0.6))
			_text_centered(rect.get_center() + Vector2(0, 8), ("%d" % ceili(cooldown)) if cooldown >= 1.0 else ("%.1f" % cooldown), 24, CryptUI.CREAM)
		if is_locked: _text_centered(rect.get_center() + Vector2(0, 26), "LV %d" % int(skill.get("unlock", 1)), 16, CryptUI.SAND)
		if index < second.size() and float(second[index]) > 0.0:
			_canvas.draw_rect(rect.grow(-2), Color(CryptUI.GOLD, 0.5 + 0.4 * sin(_pulse * 12.0)), false, 2.0)
		if active: _canvas.draw_rect(rect.grow(1), Color(CryptUI.BLOOD if index == 3 else CryptUI.GOLD, 0.6 + 0.4 * sin(_pulse * 10.0)), false, 3.0)
		if state.has("charge") and str(skill.get("id", "")) == "ballista":
			_canvas.draw_rect(Rect2(rect.position + Vector2(6, slot - 12), Vector2((slot - 12) * float(state.charge), 6)), CryptUI.GOLD)
		var key := Rect2(rect.position + Vector2(-4, -6), Vector2(22, 22))
		CryptUI.draw_box(_canvas, "button", key)
		_text_centered(key.get_center() + Vector2(0, 6), str(skill.get("key", index + 1)), 16, CryptUI.GOLD if bool(skill.get("ultimate", false)) else CryptUI.CREAM)
		x += slot + gap
	# Shared EXP bar under the row.
	var bar := Rect2(floorf((size.x - total) * 0.5), y + slot + 4, total, 8)
	_canvas.draw_rect(bar, CryptUI.INK)
	var next := maxf(1.0, float(team.get("next", 1)))
	_canvas.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * clampf(float(team.get("exp", 0)) / next, 0.0, 1.0), bar.size.y - 2)), Color("5fe0a0"))


# --- Text -------------------------------------------------------------------

func _text(at: Vector2, value: String, font_size: int, color: Color) -> void:
	_canvas.draw_string_outline(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, CryptUI.INK)
	_canvas.draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _width(value: String, font_size: int) -> float:
	return _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _text_right(at: Vector2, value: String, font_size: int, color: Color) -> void:
	_text(at - Vector2(_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, 0), value, font_size, color)


func _text_centered(at: Vector2, value: String, font_size: int, color: Color) -> void:
	_text(at - Vector2(floorf(_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5), 0), value, font_size, color)
