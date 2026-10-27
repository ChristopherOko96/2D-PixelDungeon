extends Control
## Run HUD in the game's CanvasLayer, so screen shake and room changes never move
## it. Hearts sit top left (full = 2 HP, half = 1 HP, empty = lost capacity, new
## rows after HEARTS_PER_ROW); level, EXP bar and numbers in the top band; the
## stats column in the side panel. Everything shown is the local player's
## authoritative snapshot values (see src/player/progression.gd); the HUD only
## animates the changes it sees.

const HEART_FULL := preload("res://assets/sprites/0x72/ui_heart_full.png")
const HEART_HALF := preload("res://assets/sprites/0x72/ui_heart_half.png")
const HEART_EMPTY := preload("res://assets/sprites/0x72/ui_heart_empty.png")
const HEARTS_ORIGIN := Vector2(34, 16)
const HEART_STEP := Vector2(30, 27)
const HEARTS_PER_ROW := 8
const LEVEL_ORIGIN := Vector2(300, 22)
const BAR_SIZE := Vector2(560, 14)
const STATS_ORIGIN := Vector2(968, 412)
const STATS_WIDTH := 264.0
const STAT_ROW := 19.0
const STAT_ORDER := ["damage", "tears", "speed", "range", "shot_speed", "luck", "level"]
const STAT_NAMES := {"damage": "SCHADEN", "tears": "ANGRIFFSTEMPO", "speed": "BEWEGUNG", "range": "REICHWEITE", "shot_speed": "SCHUSSTEMPO", "luck": "GLÜCK", "level": "LEVEL"}
const STAT_COLORS := {"damage": Color("ef6a5c"), "tears": Color("6fb7ef"), "speed": Color("e8c46a"), "range": Color("b98be0"), "shot_speed": Color("f0a050"), "luck": Color("6fd27a"), "level": Color("efc76a")}
# 7 × 7 pixel icons, drawn at 2x with a dark drop shadow.
const ICONS := {
	"damage": ["......#", ".....#.", "#...#..", ".#.#...", "..#....", ".#.#...", "#......"],
	"tears": ["...#...", "..###..", ".#####.", "#######", "#######", ".#####.", "..###.."],
	"speed": ["..###..", "..###..", "..###..", "..####.", "..#####", "#######", "#######"],
	"range": ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
	"shot_speed": ["....#..", "....##.", "#######", "#######", "....##.", "....#..", "......."],
	"luck": [".##.##.", "#######", ".#####.", "..###..", ".#####.", "#######", ".##.##."],
	"level": ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "#.....#"],
}
const WEAPON_SPRITES := {"sword": "weapon_regular_sword", "greatsword": "weapon_lavish_sword", "bow": "weapon_bow", "longbow": "weapon_bow_2",
	"staff": "weapon_green_magic_staff", "firestaff": "weapon_red_magic_staff"}
const INK := Color("10101c")
const TEXT := Color("d9dceb")
const MUTED := Color("8e96ac")
const EXP_COLOR := Color("5fe3c0")
const GOLD := Color("efc76a")

var _player: Dictionary = {}
var _clock := 0.0
var _hp := -1
var _max_hp := -1
# Per heart: seconds left of its damage blink / heal sparkle.
var _hurt: Dictionary = {}
var _healed: Dictionary = {}
var _stats: Dictionary = {}
# Stat name -> {"time": seconds left, "up": bool} after a value changed.
var _stat_changes: Dictionary = {}
var _level := 0
var _level_flash := 0.0
var _exp_fill := 0.0
var _floor := 1
# Boss of the current room: {name, hp, max_hp}; empty outside boss fights.
var _boss: Dictionary = {}
# The trailing "damage taken" part of the boss bar, sinking after the real value.
var _boss_trail := 1.0
var _boss_hit := 0.0
var _endless := false
# Seconds left of the "STOCKWERK n" banner after reaching a new floor.
var _floor_banner := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## How each heart container is filled: 2 = full, 1 = half, 0 = empty. A player
## with `max_hp` HP has ceil(max_hp / 2) containers; hp is clamped to them.
static func heart_fills(hp: int, max_hp: int) -> Array[int]:
	var fills: Array[int] = []
	var capacity: int = maxi(max_hp, 0)
	var health: int = clampi(hp, 0, capacity)
	for i in range(ceili(capacity / 2.0)):
		fills.append(clampi(health - i * 2, 0, 2))
	return fills


## Top-left corner of heart `index`; hearts fill rows of HEARTS_PER_ROW.
static func heart_position(index: int) -> Vector2:
	return HEARTS_ORIGIN + Vector2(float(index % HEARTS_PER_ROW) * HEART_STEP.x, floorf(float(index) / HEARTS_PER_ROW) * HEART_STEP.y)


## Endless mode: which floor the party is on. A deeper floor shows a banner.
func show_floor(floor_number: int, endless: bool) -> void:
	if endless and floor_number > _floor and _endless:
		_floor_banner = 2.6
	_floor = floor_number
	_endless = endless


## Boss fight bar at the top of the room: name and draining health.
func show_boss(boss: Dictionary) -> void:
	if boss.is_empty():
		_boss = {}
		_boss_trail = 1.0
		return
	if not _boss.is_empty() and int(boss.get("hp", 0)) < int(_boss.get("hp", 0)):
		_boss_hit = 0.15
	if _boss.is_empty():
		_boss_trail = 1.0
	_boss = boss


func showing() -> bool:
	return not _player.is_empty()


## Shows the local player's snapshot entry; an empty dictionary hides the HUD.
## Changes since the last call start their animations.
func show_player(player: Dictionary) -> void:
	if player.is_empty():
		_player = {}
		_hp = -1
		_level = 0
		_stats = {}
		return
	var hp := int(player.get("hp", 0))
	var max_hp := int(player.get("max_hp", 0))
	if _hp >= 0:
		var before := heart_fills(_hp, _max_hp)
		var after := heart_fills(hp, max_hp)
		for i in range(after.size()):
			var old_fill: int = before[i] if i < before.size() else 0
			if after[i] < old_fill: _hurt[i] = 0.6
			elif after[i] > old_fill or i >= before.size(): _healed[i] = 0.7
	_hp = hp
	_max_hp = max_hp
	var stats: Dictionary = player.get("stats", {})
	for name: String in STAT_ORDER:
		if not stats.has(name): continue
		if _stats.has(name) and not is_equal_approx(float(stats[name]), float(_stats[name])):
			_stat_changes[name] = {"time": 1.6, "up": float(stats[name]) > float(_stats[name])}
	_stats = stats.duplicate()
	var level := int(player.get("level", 1))
	if _level > 0 and level > _level:
		_level_flash = 1.4
		_exp_fill = 0.0
	_level = level
	_player = player


func _process(delta: float) -> void:
	_clock += delta
	_level_flash = maxf(0.0, _level_flash - delta)
	_floor_banner = maxf(0.0, _floor_banner - delta)
	_boss_hit = maxf(0.0, _boss_hit - delta)
	if not _boss.is_empty():
		var ratio: float = clampf(float(_boss.get("hp", 0)) / maxf(float(_boss.get("max_hp", 1)), 1.0), 0.0, 1.0)
		# The trail waits a moment after a hit, then drains to the real value.
		if _boss_hit <= 0.0: _boss_trail = move_toward(_boss_trail, ratio, delta * 0.6)
		_boss_trail = maxf(_boss_trail, ratio)
	for timers: Dictionary in [_hurt, _healed]:
		for key: Variant in timers.keys():
			timers[key] = float(timers[key]) - delta
			if timers[key] <= 0.0: timers.erase(key)
	for name: Variant in _stat_changes.keys():
		_stat_changes[name].time = float(_stat_changes[name].time) - delta
		if _stat_changes[name].time <= 0.0: _stat_changes.erase(name)
	if not _player.is_empty():
		var target: float = clampf(float(_player.get("exp", 0)) / maxf(float(_player.get("exp_next", 1)), 1.0), 0.0, 1.0)
		_exp_fill = move_toward(_exp_fill, target, delta * 1.5)
	queue_redraw()


func _draw() -> void:
	if _player.is_empty():
		return
	_draw_hearts()
	_draw_weapons()
	_draw_level()
	_draw_stats()
	_draw_floor()
	_draw_boss_bar()


func _draw_hearts() -> void:
	var fills := heart_fills(_hp, _max_hp)
	var last_filled: int = -1
	for i in range(fills.size()):
		if fills[i] > 0: last_filled = i
	for i in range(fills.size()):
		var texture: Texture2D = [HEART_EMPTY, HEART_HALF, HEART_FULL][fills[i]]
		var center: Vector2 = heart_position(i) + Vector2(13, 12)
		var scale := 1.0
		var offset := Vector2.ZERO
		var tint := Color.WHITE
		# Low health: the last heart beats.
		if i == last_filled and _hp <= 2 and _hp > 0:
			var beat: float = pow(maxf(0.0, sin(_clock * 7.0)), 6.0)
			scale += 0.18 * beat
		if _hurt.has(i):
			var t: float = float(_hurt[i]) / 0.6
			scale += 0.3 * t
			offset.x = roundf(sin(_clock * 70.0) * 2.0 * t)
			if fmod(_clock, 0.12) < 0.06: tint = Color(3, 3, 3)
		if _healed.has(i):
			var t: float = float(_healed[i]) / 0.7
			scale += 0.25 * sin(t * PI)
			tint = Color(1.0, 1.0 + 0.6 * t, 1.0)
		if _hp <= 0: tint = Color(0.45, 0.45, 0.5)
		draw_set_transform(center + offset, 0.0, Vector2(scale, scale))
		draw_texture_rect(texture, Rect2(Vector2(-13, -12), Vector2(26, 24)), false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _healed.has(i):
			# Small green plus signs rise from a healed heart.
			var t: float = 1.0 - float(_healed[i]) / 0.7
			for k in range(3):
				var p: Vector2 = center + Vector2(-8 + k * 8, -10 - t * 18 - k * 3)
				var color := Color(0.5, 1.0, 0.55, 1.0 - t)
				draw_rect(Rect2(p.x - 3, p.y - 1, 6, 2), color)
				draw_rect(Rect2(p.x - 1, p.y - 3, 2, 6), color)


## The carried weapons under the hearts; the held one is framed in gold.
func _draw_weapons() -> void:
	var weapons: Array = _player.get("weapons", [])
	if weapons.is_empty():
		return
	var rows: int = ceili(float(heart_fills(_hp, _max_hp).size()) / HEARTS_PER_ROW)
	var top := Vector2(HEARTS_ORIGIN.x, HEARTS_ORIGIN.y + rows * HEART_STEP.y + 2)
	var held: int = int(_player.get("weapon_index", 0))
	for i in range(weapons.size()):
		var box := Rect2(top + Vector2(i * 30, 0), Vector2(26, 26))
		draw_rect(box, Color(0.06, 0.06, 0.1, 0.8))
		draw_rect(box, GOLD if i == held else Color("4a4f66"), false, 1.0)
		var texture: Texture2D = load("res://assets/sprites/0x72/%s.png" % WEAPON_SPRITES.get(str(weapons[i]), "weapon_bow"))
		var size := Vector2(texture.get_width(), texture.get_height()) * 0.8
		draw_set_transform(box.get_center(), PI * 0.25, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if weapons.size() > 1:
		draw_string(ThemeDB.fallback_font, top + Vector2(weapons.size() * 30 + 4, 17), "Q", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)


func _draw_level() -> void:
	var font: Font = ThemeDB.fallback_font
	var level := int(_player.get("level", 1))
	var exp_value := int(_player.get("exp", 0))
	var exp_next := int(_player.get("exp_next", 1))
	var flash: float = _level_flash / 1.4
	var label_color: Color = GOLD.lerp(Color.WHITE, flash)
	draw_string(font, LEVEL_ORIGIN + Vector2(0, 20), "LV", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	draw_string(font, LEVEL_ORIGIN + Vector2(24, 22), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 26 + roundi(6.0 * flash), label_color)
	var bar := Rect2(LEVEL_ORIGIN + Vector2(70, 6), BAR_SIZE)
	draw_rect(bar.grow(2), INK)
	draw_rect(bar, Color("1f2433"))
	var fill := Rect2(bar.position, Vector2(floorf(bar.size.x * _exp_fill), bar.size.y))
	draw_rect(fill, EXP_COLOR.darkened(0.35))
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 5)), EXP_COLOR)
	for tick in range(1, 10):
		draw_rect(Rect2(bar.position.x + bar.size.x * tick / 10.0, bar.position.y, 1, bar.size.y), Color(0, 0, 0, 0.35))
	draw_rect(bar.grow(2), Color("4a4f66"), false, 1.0)
	if flash > 0.0:
		draw_rect(bar, Color(1, 1, 1, 0.6 * flash))
		draw_string(font, bar.position + Vector2(bar.size.x * 0.5 - 50, -6 - 6 * (1.0 - flash)), "LEVEL UP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(GOLD, minf(1.0, flash * 2.0)))
	draw_string(font, bar.position + Vector2(0, bar.size.y + 18), "%d / %d EXP" % [exp_value, exp_next], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	draw_string(font, bar.position + Vector2(0, bar.size.y + 18), "NOCH %d BIS LV %d" % [maxi(0, exp_next - exp_value), level + 1], HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x, 12, MUTED)


func _draw_floor() -> void:
	if not _endless:
		return
	var font: Font = ThemeDB.fallback_font
	draw_string(font, LEVEL_ORIGIN + Vector2(70, 0), "ENDLOS · STOCKWERK %d" % _floor, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	if _floor_banner > 0.0:
		var alpha: float = minf(1.0, _floor_banner) * minf(1.0, (2.6 - _floor_banner) * 4.0)
		var center := Vector2(32 + 448, 156 + 200)
		draw_rect(Rect2(center.x - 220, center.y - 46, 440, 84), Color(0.04, 0.05, 0.08, 0.75 * alpha))
		draw_string(font, center + Vector2(-220, 4), "STOCKWERK %d" % _floor, HORIZONTAL_ALIGNMENT_CENTER, 440, 40, Color(GOLD, alpha))
		draw_string(font, center + Vector2(-220, 30), "Die Gegner werden stärker.", HORIZONTAL_ALIGNMENT_CENTER, 440, 15, Color(MUTED, alpha))


func _draw_boss_bar() -> void:
	if _boss.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var ratio: float = clampf(float(_boss.get("hp", 0)) / maxf(float(_boss.get("max_hp", 1)), 1.0), 0.0, 1.0)
	var shake := Vector2(roundf(sin(_clock * 80.0) * 2.0), 0) if _boss_hit > 0.0 else Vector2.ZERO
	# A mini-boss gets a shorter bar, marked as such.
	var mini: bool = bool(_boss.get("mini", false))
	var bar := Rect2(Vector2(320 if mini else 220, 186) + shake, Vector2(320 if mini else 520, 10 if mini else 12))
	var name: String = ("NEBENBOSS · " if mini else "") + str(_boss.get("name", ""))
	draw_string(font, Vector2(220, 180) + shake + Vector2(1, 1), name, HORIZONTAL_ALIGNMENT_CENTER, 520, 14 if mini else 16, INK)
	draw_string(font, Vector2(220, 180) + shake, name, HORIZONTAL_ALIGNMENT_CENTER, 520, 14 if mini else 16, Color("e0a0ff") if mini else Color("ff9a7a"))
	draw_rect(bar.grow(3), INK)
	draw_rect(bar, Color("2a1418"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _boss_trail, bar.size.y)), Color("f4e2c8"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color("b8283a"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 4)), Color("ef5a5a"))
	for tick in range(1, 4):
		draw_rect(Rect2(bar.position.x + bar.size.x * tick / 4.0, bar.position.y, 1, bar.size.y), Color(0, 0, 0, 0.4))
	draw_rect(bar.grow(3), Color("8a5a3a"), false, 1.0)


func _draw_stats() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(font, STATS_ORIGIN + Vector2(0, 2), "WERTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	draw_rect(Rect2(STATS_ORIGIN + Vector2(46, -3), Vector2(STATS_WIDTH - 46, 1)), Color("343747"))
	for row in range(STAT_ORDER.size()):
		var name: String = STAT_ORDER[row]
		var top: Vector2 = STATS_ORIGIN + Vector2(0, 8 + row * STAT_ROW)
		var change: Dictionary = _stat_changes.get(name, {})
		var value_color := TEXT
		if not change.is_empty():
			var t: float = float(change.time) / 1.6
			var mark: Color = Color("6fd27a") if change.up else Color("ef6a5c")
			draw_rect(Rect2(top + Vector2(-4, 0), Vector2(STATS_WIDTH + 8, STAT_ROW - 2)), Color(mark, 0.18 * t))
			value_color = TEXT.lerp(mark, t)
			draw_string(font, top + Vector2(STATS_WIDTH - 70, 13), "▲" if change.up else "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(mark, t))
		_draw_icon(ICONS[name], top + Vector2(0, 2), STAT_COLORS[name])
		draw_string(font, top + Vector2(22, 13), STAT_NAMES[name], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
		draw_string(font, top + Vector2(0, 14), _format(name, _stats.get(name, 0)), HORIZONTAL_ALIGNMENT_RIGHT, STATS_WIDTH, 14, value_color)


func _format(name: String, value: Variant) -> String:
	if name == "level": return str(int(value))
	if name == "luck": return "%d" % int(value) if is_equal_approx(float(value), roundf(float(value))) else "%.1f" % float(value)
	return "%.2f" % float(value)


func _draw_icon(rows: Array, origin: Vector2, color: Color) -> void:
	for pass_index in range(2):
		var shift := Vector2(1, 1) if pass_index == 0 else Vector2.ZERO
		var tint: Color = INK if pass_index == 0 else color
		for y in range(rows.size()):
			var line: String = rows[y]
			for x in range(line.length()):
				if line[x] == "#":
					draw_rect(Rect2(origin + shift + Vector2(x * 2, y * 2), Vector2(2, 2)), tint)
