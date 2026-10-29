extends RefCounted
## The slim skill bar at the bottom of the screen, shared by the crypt
## (src/ui/run_hud.gd) and the story worlds (src/hell/hell_game.gd): one low
## strip in the neutral HUD look (src/ui/hud_style.gd) close to the edge with small square slots. Each slot shows the
## skill's icon, its key in the corner, the cooldown as a shade that shrinks
## from the top with the seconds left, "LV n" while locked, a pulsing frame
## while the skill runs (Rage, beam) and a thin charge line (ballista). The
## name appears above the strip only while the mouse rests on a slot. An
## optional level chip leads the row and a thin EXP line runs along its foot.
## Sizes: assets/data/ui_run_hud.json "skill_bar".

const HudStyle = preload("res://src/ui/hud_style.gd")
const DATA_PATH := "res://assets/data/ui_run_hud.json"
const DEFAULTS := {"slot": 44, "gap": 4, "bottom": 10, "pad": 3, "icon": 32, "key_size": 10, "number_size": 16, "label_size": 14, "exp_height": 3}

static var _layout: Dictionary = {}


## The bar's sizes (px), with defaults when the file or a key is missing.
static func layout() -> Dictionary:
	if _layout.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		var data: Dictionary = parsed.get("skill_bar", {}) if parsed is Dictionary else {}
		for key: String in DEFAULTS:
			_layout[key] = float(data.get(key, DEFAULTS[key]))
	return _layout


## Height of the whole strip (slots, padding and the EXP line).
static func height(with_exp: bool = true) -> float:
	var l := layout()
	return float(l.slot) + float(l.pad) * 2.0 + (float(l.exp_height) + 1.0 if with_exp else 0.0)


## Top edge of the strip on a screen of `screen` px (hints sit above it).
static func top(screen: Vector2, with_exp: bool = true) -> float:
	return screen.y - float(layout().bottom) - height(with_exp)


## Draws the bar. `slots`: {key, name, icon (Texture2D or null), cd, max,
## locked, unlock, active (Color, alpha 0 = not running), charge (-1 = none),
## second (bool), ultimate (bool)}. `options`: level (int, -1 = no chip), exp
## (0..1, -1 = no line), mouse (Vector2, screen px), accent (Color). Returns
## the strip's rectangle.
static func draw(canvas: CanvasItem, font: Font, screen: Vector2, slots: Array, clock: float, options: Dictionary = {}) -> Rect2:
	var l := layout()
	var slot := float(l.slot)
	var gap := float(l.gap)
	var pad := float(l.pad)
	var level := int(options.get("level", -1))
	var experience := float(options.get("exp", -1.0))
	var accent: Color = options.get("accent", HudStyle.color("accent"))
	var count := slots.size() + (1 if level >= 0 else 0)
	if count == 0: return Rect2()
	var row := slot * count + gap * (count - 1)
	var x := floorf((screen.x - row) * 0.5)
	var y := top(screen, experience >= 0.0) + pad
	var strip := Rect2(x - pad, y - pad, row + pad * 2.0, height(experience >= 0.0))
	HudStyle.panel(canvas, strip)
	if level >= 0:
		var chip := Rect2(x, y, slot, slot)
		canvas.draw_rect(chip, Color(HudStyle.color("slot"), 0.9))
		_centered(canvas, font, Vector2(chip.get_center().x, chip.position.y + 13), "LV", 10, HudStyle.color("text_dim"))
		_centered(canvas, font, Vector2(chip.get_center().x, chip.end.y - 6), str(level), 18, HudStyle.color("accent"))
		x += slot + gap
	var mouse: Vector2 = options.get("mouse", Vector2(-1, -1))
	var hovered: Dictionary = {}
	var hovered_rect := Rect2()
	for entry: Dictionary in slots:
		var rect := Rect2(x, y, slot, slot)
		_slot(canvas, font, rect, entry, clock, accent)
		if rect.has_point(mouse):
			hovered = entry
			hovered_rect = rect
		x += slot + gap
	if experience >= 0.0:
		var line := Rect2(strip.position.x + pad, strip.end.y - pad - float(l.exp_height), strip.size.x - pad * 2.0, float(l.exp_height))
		canvas.draw_rect(line, Color(HudStyle.color("slot"), 0.9))
		canvas.draw_rect(Rect2(line.position, Vector2(line.size.x * clampf(experience, 0.0, 1.0), line.size.y)), HudStyle.color("exp"))
	if not hovered.is_empty() and not str(hovered.get("name", "")).is_empty():
		_label(canvas, font, Vector2(hovered_rect.get_center().x, strip.position.y - 6), str(hovered.name), screen)
	return strip


static func _slot(canvas: CanvasItem, font: Font, rect: Rect2, entry: Dictionary, clock: float, accent: Color) -> void:
	var l := layout()
	var locked := bool(entry.get("locked", false))
	var cooldown := float(entry.get("cd", 0.0))
	var maximum := maxf(float(entry.get("max", 1.0)), 0.01)
	var ready := not locked and cooldown <= 0.0
	canvas.draw_rect(rect, HudStyle.color("slot"))
	var icon: Texture2D = entry.get("icon", null)
	if icon != null:
		var size := Vector2(float(l.icon), float(l.icon))
		var tint := Color(0.32, 0.3, 0.3, 0.8) if locked else Color(0.62, 0.6, 0.6) if cooldown > 0.0 else Color.WHITE
		canvas.draw_texture_rect(icon, Rect2((rect.get_center() - size * 0.5).round(), size), false, tint)
	if not locked and cooldown > 0.0:
		# the shade shrinks from the top as the skill recharges
		var share := clampf(cooldown / maximum, 0.0, 1.0)
		canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, roundf(rect.size.y * share))), Color(HudStyle.color("outline"), 0.6))
		_centered(canvas, font, rect.get_center() + Vector2(0, 6), ("%d" % ceili(cooldown)) if cooldown >= 1.0 else ("%.1f" % cooldown), int(l.number_size), HudStyle.color("text"))
	if locked:
		_centered(canvas, font, Vector2(rect.get_center().x, rect.end.y - 4), "LV %d" % int(entry.get("unlock", 1)), 10, HudStyle.color("text_dim"))
	var frame := Color(accent, 0.85) if ready else HudStyle.color("panel_edge")
	if locked: frame = Color(HudStyle.color("panel_edge"), 0.08)
	canvas.draw_rect(rect, frame, false, 1.0)
	if bool(entry.get("second", false)):
		canvas.draw_rect(rect.grow(-2), Color(HudStyle.color("accent"), 0.5 + 0.4 * sin(clock * 12.0)), false, 1.0)
	var running: Color = entry.get("active", Color(0, 0, 0, 0))
	if running.a > 0.0:
		canvas.draw_rect(rect.grow(1), Color(running, 0.55 + 0.45 * sin(clock * 10.0)), false, 2.0)
	var charge := float(entry.get("charge", -1.0))
	if charge >= 0.0:
		canvas.draw_rect(Rect2(rect.position + Vector2(3, rect.size.y - 5), Vector2((rect.size.x - 6) * clampf(charge, 0.0, 1.0), 2)), HudStyle.color("accent"))
	var key := str(entry.get("key", ""))
	if not key.is_empty():
		_text(canvas, font, rect.position + Vector2(3, float(l.key_size) + 1), key, int(l.key_size), HudStyle.color("accent") if bool(entry.get("ultimate", false)) else HudStyle.color("text_dim"))


## The hovered skill's name on a small dark plate above the strip, kept on screen.
static func _label(canvas: CanvasItem, font: Font, foot: Vector2, text: String, screen: Vector2) -> void:
	var size := int(layout().label_size)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var plate := Rect2(foot.x - width * 0.5 - 6, foot.y - size - 6, width + 12, size + 8)
	plate.position.x = clampf(plate.position.x, 4.0, screen.x - plate.size.x - 4.0)
	canvas.draw_rect(plate, Color(HudStyle.color("outline"), 0.85))
	canvas.draw_rect(plate, Color(HudStyle.color("panel_edge"), 0.6), false, 1.0)
	_text(canvas, font, Vector2(plate.position.x + 6, plate.end.y - 5), text, size, HudStyle.color("text"))


static func _text(canvas: CanvasItem, font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
	canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, HudStyle.color("outline"))
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func _centered(canvas: CanvasItem, font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
	_text(canvas, font, at - Vector2(floorf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5), 0), text, size, color)
