extends Control
## The talent screen (main menu): on the left the character (class, level,
## EXP, free points, soul shards, gold, difficulty, reset), in the middle the
## three branches of the class side by side (tiers I-IV top to bottom, lines
## between them, the ultimate larger at the end), on the right the chosen
## talent with its ranks, cost, cooldown, requirements and the buttons to
## learn it, take a point back, put it on the talent bar or raise its soul
## tier. States: locked (grey), available (glowing frame), learned (full
## colour), max rank (gold), ultimate (double frame), missing shards (cost).
## Rules: src/progress/talent_rules.gd; the profile is shared with the run.

const Profile = preload("res://src/progress/profile.gd")
const Rules = preload("res://src/progress/talent_rules.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const TalentIcons = preload("res://src/ui/talent_icons.gd")

## Emitted after every change that was saved (the game resends builds in multiplayer).
signal profile_changed
signal closed

const CLASS_NAMES := {"mage": "MAGIER", "archer": "BOGENSCHÜTZE", "swordsman": "KRIEGER"}
const TIER_NAMES := ["I", "II", "III", "IV"]
const LEFT := Rect2(16, 64, 228, 600)
const TREE := Rect2(256, 64, 690, 600)
const RIGHT := Rect2(958, 64, 306, 600)

var data: Dictionary = {}
var profile: Dictionary = {}
var save_path := Profile.SAVE_PATH
var class_id := "mage"
var selected := ""
var message := ""
var _font: Font
var _clock := 0.0
## Talent id -> time left of the "point invested" pulse.
var _pulses: Dictionary = {}
## Talent id -> clickable rect.
var _hits: Dictionary = {}
var _buttons: Dictionary = {}


## Shows the screen for `profile_ref` (shared with the run; changes save to `path`).
func open(talent_data: Dictionary, profile_ref: Dictionary, path: String = Profile.SAVE_PATH, start_class: String = "") -> void:
	data = talent_data
	profile = profile_ref
	save_path = path
	if not start_class.is_empty() and data.classes.has(start_class): class_id = start_class
	if selected.is_empty() or str(data.talents.get(selected, {}).get("class", "")) != class_id: selected = str(data.classes[class_id].specs[0].talents[0])
	visible = true
	_refresh()


func _ready() -> void:
	size = Vector2(1280, 720)
	theme = CryptUI.create_theme()
	_font = PixelStyle.create_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var x := 280.0
	for id: String in ["mage", "archer", "swordsman"]:
		_add_button("tab_" + id, CLASS_NAMES[id], Rect2(x, 14, 200, 36), func(): _pick_class(id))
		x += 212.0
	_add_button("close", "ZURÜCK", Rect2(1094, 14, 170, 36), func(): visible = false; closed.emit())
	_add_button("difficulty", "", Rect2(LEFT.position.x + 12, 548, LEFT.size.x - 24, 30), _cycle_difficulty)
	_add_button("reset", "", Rect2(LEFT.position.x + 12, 584, LEFT.size.x - 24, 30), _reset)
	_add_button("learn", "", Rect2(RIGHT.position.x + 12, 470, RIGHT.size.x - 24, 34), _learn)
	_add_button("unlearn", "PUNKT ZURÜCKNEHMEN", Rect2(RIGHT.position.x + 12, 510, RIGHT.size.x - 24, 30), _unlearn)
	_add_button("bar", "", Rect2(RIGHT.position.x + 12, 546, RIGHT.size.x - 24, 30), _cycle_bar)
	_add_button("soul", "", Rect2(RIGHT.position.x + 12, 582, RIGHT.size.x - 24, 30), _soul_up)
	for key: String in _buttons:
		# Tabs read at body size; the panel buttons use the small pixel size to fit.
		_buttons[key].add_theme_font_size_override("font_size", 16 if key.begins_with("tab_") or key == "close" else 8)


func _add_button(key: String, text: String, rect: Rect2, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	add_child(button)
	_buttons[key] = button


func _process(delta: float) -> void:
	if not visible: return
	_clock += delta
	for id: String in _pulses.keys():
		_pulses[id] = float(_pulses[id]) - delta
		if float(_pulses[id]) <= 0.0: _pulses.erase(id)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id: String in _hits:
			if Rect2(_hits[id]).has_point(event.position):
				selected = id
				message = ""
				_refresh()
				accept_event()
				return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		for id: String in _hits:
			if Rect2(_hits[id]).has_point(event.position):
				selected = id
				_unlearn()
				accept_event()
				return


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and event is InputEventKey and event.keycode == KEY_ESCAPE:
		visible = false
		closed.emit()
		get_viewport().set_input_as_handled()


func _state() -> Dictionary:
	return Profile.class_state(profile, class_id)


## Talent look: "locked", "available", "learned", "max" or "no_shards".
func talent_state(id: String) -> String:
	var state := _state()
	var rank := Rules.rank(state, id)
	var info: Dictionary = data.talents[id]
	if rank >= int(info.ranks): return "max"
	var why := Rules.check_rank_up(data, profile, class_id, id)
	if rank > 0: return "learned"
	if why.is_empty(): return "available"
	if str(info.kind) == "ultimate" and why.contains("Seelensplitter"): return "no_shards"
	return "locked"


func _refresh() -> void:
	if data.is_empty(): return
	for id: String in ["mage", "archer", "swordsman"]: _buttons["tab_" + id].disabled = id == class_id
	var state := _state()
	var info: Dictionary = data.talents[selected]
	var rank := Rules.rank(state, selected)
	var why := Rules.check_rank_up(data, profile, class_id, selected)
	var learn: Button = _buttons.learn
	learn.text = "FREISCHALTEN · %d SPLITTER" % int(data.soul_shards.ultimate_cost) if str(info.kind) == "ultimate" else ("RANG VERBESSERN" if rank > 0 else "PUNKT INVESTIEREN")
	learn.disabled = not why.is_empty()
	learn.tooltip_text = why
	_buttons.unlearn.disabled = not Rules.can_rank_down(data, profile, class_id, selected)
	var bar: Button = _buttons.bar
	bar.visible = str(info.kind) == "active"
	var slot: int = state.bar.find(selected)
	bar.text = ("LEISTE: SHIFT + %d" % (slot + 1)) if slot >= 0 else "AUF DIE LEISTE"
	bar.disabled = rank <= 0
	var soul: Button = _buttons.soul
	soul.visible = str(info.kind) == "ultimate"
	var tier := int(state.soul_tier)
	var owned: bool = str(state.ultimate) == selected
	soul.text = "SEELENSTUFE 3 ERREICHT" if tier >= 3 and owned else ("SEELENSTUFE %d · %d SPLITTER" % [tier + 1, int(data.soul_shards.tier_costs[mini(tier, 2)])] if owned else "ERST FREISCHALTEN")
	soul.disabled = not owned or tier >= 3 or int(profile.shards.have) < int(data.soul_shards.tier_costs[mini(tier, 2)])
	var difficulty := str(profile.get("difficulty", "normal"))
	_buttons.difficulty.text = "SCHWIERIGKEIT: %s" % str(data.difficulties[difficulty].name).to_upper()
	_buttons.reset.text = "ZURÜCKSETZEN · %d GOLD" % Rules.reset_cost(data, profile, class_id)
	_buttons.reset.disabled = state.ranks.is_empty() or int(profile.gold) < Rules.reset_cost(data, profile, class_id)
	queue_redraw()


func _pick_class(id: String) -> void:
	class_id = id
	selected = str(data.classes[id].specs[0].talents[0])
	message = ""
	_refresh()


func _commit(reason: String, ok_text: String) -> void:
	message = ok_text if reason.is_empty() else reason
	if reason.is_empty():
		Profile.save_profile(profile, save_path)
		profile_changed.emit()
	_refresh()


func _learn() -> void:
	var reason := Rules.rank_up(data, profile, class_id, selected)
	if reason.is_empty(): _pulses[selected] = 0.45
	_commit(reason, "%s: Rang %d." % [str(data.talents[selected].name), Rules.rank(_state(), selected)])


func _unlearn() -> void:
	_commit(Rules.rank_down(data, profile, class_id, selected), "Punkt zurückgenommen.")


func _cycle_bar() -> void:
	var state := _state()
	var slot: int = (state.bar.find(selected) + 1) % int(data.bar_slots)
	_commit(Rules.set_bar(data, profile, class_id, selected, slot), "Liegt jetzt auf Shift + %d." % (slot + 1))


func _soul_up() -> void:
	_commit(Rules.soul_up(data, profile, class_id), "Seelenstufe %d." % int(_state().soul_tier))


func _reset() -> void:
	_commit(Rules.reset(data, profile, class_id), "Alle Punkte und Seelensplitter sind erstattet.")


func _cycle_difficulty() -> void:
	var order: Array = data.difficulties.order
	profile.difficulty = order[(order.find(str(profile.get("difficulty", "normal"))) + 1) % order.size()]
	_commit("", "Schwierigkeit: %s (Splitterchance %d %%)." % [data.difficulties[profile.difficulty].name, int(data.difficulties[profile.difficulty].drop_pct)])


# ---------- drawing ----------

func _draw() -> void:
	if data.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.07))
	_text("TALENTE", Vector2(24, 40), 24, CryptUI.GOLD)
	for rect: Rect2 in [LEFT, TREE, RIGHT]: CryptUI.draw_box(self, "panel", rect)
	_draw_left()
	_draw_tree()
	_draw_right()


func _draw_left() -> void:
	var state := _state()
	var x := LEFT.position.x + 14
	var y := LEFT.position.y + 30
	_text("CHARAKTER", Vector2(x, y), 16, CryptUI.MUTED)
	_text(CLASS_NAMES[class_id], Vector2(x, y + 26), 24 if str(CLASS_NAMES[class_id]).length() <= 8 else 16, CryptUI.CREAM)
	_text("LEVEL %d / %d" % [int(state.level), int(data.max_level)], Vector2(x, y + 60), 16, CryptUI.CREAM)
	var need := Rules.exp_to_next(data, int(state.level))
	var bar_w := LEFT.size.x - 28
	draw_rect(Rect2(x, y + 70, bar_w, 8), CryptUI.INK)
	draw_rect(Rect2(x, y + 70, bar_w * (1.0 if int(state.level) >= int(data.max_level) else clampf(float(state.exp) / need, 0.0, 1.0)), 8), CryptUI.GOLD)
	_text("%d / %d EXP" % [int(state.exp), need] if int(state.level) < int(data.max_level) else "HÖCHSTES LEVEL", Vector2(x, y + 96), 16, CryptUI.MUTED)
	var free := Rules.free_points(data, state)
	_text("TALENTPUNKTE", Vector2(x, y + 132), 16, CryptUI.MUTED)
	_text("%d frei von %d" % [free, Rules.points_total(data, int(state.level))], Vector2(x, y + 154), 16, CryptUI.GOLD if free > 0 else CryptUI.CREAM)
	_text("SEELENSPLITTER", Vector2(x, y + 190), 16, CryptUI.MUTED)
	draw_crystal(self, Vector2(x + 12, y + 214), 1.0, _clock)
	_text(str(int(profile.shards.have)), Vector2(x + 34, y + 222), 24, CryptUI.VOID)
	_text("erhalten %d, ausgegeben %d" % [int(profile.shards.earned), int(profile.shards.spent)], Vector2(x, y + 260), 8, CryptUI.MUTED)
	_text("GOLD  %d" % int(profile.gold), Vector2(x, y + 284), 16, CryptUI.GOLD)
	var res: Dictionary = data.resources[class_id]
	_text(str(res.name).to_upper(), Vector2(x, y + 318), 16, CryptUI.MUTED)
	_text(("0-%d, +%d pro Treffer" % [int(res.max), int(res.per_hit)]) if str(res.kind) == "rage" else ("%d, +%d pro s" % [int(res.max), int(res.regen)]), Vector2(x, y + 340), 16, CryptUI.CREAM)
	var spec_y := y + 368
	for spec: Dictionary in data.classes[class_id].specs:
		draw_rect(Rect2(x, spec_y - 10, 4, 12), Color(str(spec.color)))
		_text("%s  %d" % [str(spec.name), Rules.spec_points(data, state, str(spec.id))], Vector2(x + 10, spec_y), 16, CryptUI.CREAM)
		spec_y += 20
	_text("Leiste: Shift + 1-4 · Ultimate: R", Vector2(x, LEFT.end.y - 16), 8, CryptUI.MUTED)


func _draw_tree() -> void:
	_hits.clear()
	var state := _state()
	var column_w := (TREE.size.x - 24) / 3.0
	for i in range(3):
		var spec: Dictionary = data.classes[class_id].specs[i]
		var color := Color(str(spec.color))
		var cx := TREE.position.x + 12 + column_w * i + column_w * 0.5
		var top := TREE.position.y + 14
		draw_rect(Rect2(cx - column_w * 0.5 + 4, top, column_w - 8, 4), color)
		_text_centered(str(spec.name).to_upper(), Vector2(cx, top + 30), 16, CryptUI.CREAM)
		_text_centered("%d Punkte" % Rules.spec_points(data, state, str(spec.id)), Vector2(cx, top + 50), 16, CryptUI.MUTED)
		var rows := [[0, 1], [2, 3], [4], [5]]
		var row_y := [top + 110, top + 236, top + 362, top + 480]
		var centers := {}
		for r in range(4):
			var ids: Array = rows[r]
			for k in range(ids.size()):
				var id := str(spec.talents[ids[k]])
				var ult: bool = str(data.talents[id].kind) == "ultimate"
				var offset := (k - (ids.size() - 1) * 0.5) * 104.0
				centers[id] = Vector2(cx + offset, row_y[r])
		# Lines first, so icons sit on top: each tier hangs from the one above.
		for r in range(1, 4):
			for id_above: int in rows[r - 1]:
				for id_below: int in rows[r]:
					var a: Vector2 = centers[str(spec.talents[id_above])]
					var b: Vector2 = centers[str(spec.talents[id_below])]
					var lit: bool = Rules.rank(state, str(spec.talents[id_below])) > 0
					draw_line(a + Vector2(0, 30), b - Vector2(0, 34), color if lit else Color(color, 0.25), 3.0 if lit else 2.0)
		for r in range(4):
			var tier: Dictionary = data.tiers[str(r + 1)]
			_text("%s" % TIER_NAMES[r], Vector2(cx - column_w * 0.5 + 10, row_y[r] - 18), 16, CryptUI.MUTED)
			_text("Lv %d" % int(tier.level), Vector2(cx - column_w * 0.5 + 10, row_y[r] + 2), 8, CryptUI.MUTED)
		for id: String in centers: _draw_talent(id, centers[id], spec, color)


func _draw_talent(id: String, center: Vector2, spec: Dictionary, color: Color) -> void:
	var info: Dictionary = data.talents[id]
	var state := _state()
	var ult: bool = str(info.kind) == "ultimate"
	var look := talent_state(id)
	var side := 64.0 if ult else 48.0
	var rect := Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	_hits[id] = rect.grow(6)
	var lit: bool = look in ["learned", "max", "available"]
	var pulse: float = float(_pulses.get(id, 0.0))
	if pulse > 0.0:
		var grow := (0.45 - pulse) / 0.45
		draw_circle(center, side * (0.6 + grow * 0.6), Color(Color(str(spec.color2)), 0.5 * (1.0 - grow)))
	if look == "available": draw_rect(rect.grow(4 + 1.5 * sin(_clock * 5.0)), Color(color, 0.55))
	if id == selected: draw_rect(rect.grow(7), CryptUI.CREAM, false, 2.0)
	draw_texture_rect(_icon(spec, str(info.icon), lit), rect, false, Color(1, 1, 1, 0.4) if look == "locked" else Color.WHITE)
	var frame := CryptUI.GOLD if look == "max" else color if lit else CryptUI.DISABLED
	draw_rect(rect, frame, false, 3.0)
	if ult: draw_rect(rect.grow(5), frame, false, 2.0)
	var rank := Rules.rank(state, id)
	var badge := Rect2(rect.end - Vector2(26, 14), Vector2(30, 18))
	draw_rect(badge, CryptUI.GOLD if look == "max" else CryptUI.INK)
	_text_centered("%d/%d" % [rank, int(info.ranks)], badge.get_center() + Vector2(0, 6), 8, CryptUI.INK if look == "max" else CryptUI.CREAM)
	if look == "no_shards":
		draw_crystal(self, rect.position + Vector2(-4, -6), 0.6, _clock)
		_text("%d" % int(data.soul_shards.ultimate_cost), rect.position + Vector2(6, 4), 16, CryptUI.VOID)
	# Names wrap onto two lines so neighbours never run into each other.
	var name_lines := _wrap_lines(str(info.name), 92.0, 8)
	for n in range(name_lines.size()):
		_text_centered(name_lines[n], center + Vector2(0, side * 0.5 + 16 + n * 10), 8, CryptUI.CREAM if lit else CryptUI.MUTED)


func _wrap_lines(text: String, width: float, font_size: int) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word: String in text.split(" "):
		var trial := word if current.is_empty() else current + " " + word
		if _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not current.is_empty():
			lines.append(current)
			current = word
		else: current = trial
	if not current.is_empty(): lines.append(current)
	return lines


func _draw_right() -> void:
	var info: Dictionary = data.talents[selected]
	var state := _state()
	var spec_color := Color(str(data.classes[class_id].specs.filter(func(s: Dictionary) -> bool: return str(s.id) == str(info.spec))[0].color))
	var x := RIGHT.position.x + 14
	var y := RIGHT.position.y + 30
	var kind: String = {"active": "AKTIV", "passive": "PASSIV", "ultimate": "ULTIMATE"}[str(info.kind)]
	_text("STUFE %s · %s" % [TIER_NAMES[int(info.tier) - 1], kind], Vector2(x, y), 16, spec_color)
	_text(str(info.name).to_upper(), Vector2(x, y + 28), 24, CryptUI.CREAM)
	var rank := Rules.rank(state, selected)
	_text("RANG %d / %d" % [rank, int(info.ranks)], Vector2(x, y + 58), 16, CryptUI.GOLD)
	var line := y + 86
	line = _paragraph(_rank_text(str(info.text), maxi(rank, 1) if rank > 0 else 0), x, line, CryptUI.CREAM)
	if rank > 0 and rank < int(info.ranks): line = _paragraph("Nächster Rang: " + _rank_text(str(info.text), rank + 1), x, line + 6, CryptUI.MUTED)
	line += 8
	if info.has("cost"):
		_text("Kosten: %d %s" % [int(info.cost), str(data.resources[class_id].name)], Vector2(x, line), 16, CryptUI.CREAM)
		line += 22
		_text("Abklingzeit: %d s" % int(info.cd), Vector2(x, line), 16, CryptUI.CREAM)
		line += 22
	var tier: Dictionary = data.tiers[str(int(info.tier))]
	var requirement := "Level %d" % int(tier.level)
	if int(tier.points) > 0: requirement += ", %d Punkte im Zweig" % int(tier.points)
	if str(info.kind) == "ultimate": requirement += ", %d Seelensplitter, nur eine Ultimate" % int(data.soul_shards.ultimate_cost)
	line = _paragraph("Voraussetzung: " + requirement, x, line + 4, CryptUI.MUTED)
	if str(info.kind) == "ultimate" and str(state.ultimate) == selected and int(state.soul_tier) > 0:
		_text("Seelenstufe %d: +%d %%" % [int(state.soul_tier), int(data.soul_shards.tier_bonus_pct[int(state.soul_tier) - 1])], Vector2(x, line + 6), 16, CryptUI.VOID)
	var why := Rules.check_rank_up(data, profile, class_id, selected)
	var note := message if not message.is_empty() else why
	if not note.is_empty(): _paragraph(note, x, 440, CryptUI.BLOOD if note == why and not why.is_empty() else CryptUI.GOLD)


## "125/145/165 %" -> the value of `rank` (1-3), or all values for rank 0.
func _rank_text(text: String, rank: int) -> String:
	if rank <= 0: return text
	var regex := RegEx.create_from_string("(\\d+(?:,\\d+)?)/(\\d+(?:,\\d+)?)/(\\d+(?:,\\d+)?)")
	var out := text
	for m: RegExMatch in regex.search_all(text): out = out.replace(m.get_string(0), m.get_string(clampi(rank, 1, 3)))
	return out


func _paragraph(text: String, x: float, y: float, color: Color) -> float:
	var width := RIGHT.size.x - 28
	var words := text.split(" ")
	var current := ""
	for word: String in words:
		var trial := word if current.is_empty() else current + " " + word
		if _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > width and not current.is_empty():
			_text(current, Vector2(x, y), 16, color)
			y += 20
			current = word
		else: current = trial
	if not current.is_empty():
		_text(current, Vector2(x, y), 16, color)
		y += 20
	return y


func _icon(spec: Dictionary, motif: String, on: bool) -> Texture2D:
	return TalentIcons.make(spec, motif, on)


func _text(text: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_centered(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## The soul shard: a glowing violet crystal with a dark core and drifting motes.
static func draw_crystal(canvas: CanvasItem, at: Vector2, scale: float, clock: float) -> void:
	var s := 3.0 * scale
	var bob := Vector2(0, roundf(sin(clock * 1.6) * 2.0 * scale))
	canvas.draw_circle(at + bob, 16.0 * scale, Color(0.6, 0.4, 1.0, 0.18 + 0.06 * sin(clock * 3.0)))
	for i in range(6):
		var angle := clock * (0.6 + i * 0.13) + i
		canvas.draw_rect(Rect2((at + Vector2(cos(angle) * 14.0, sin(angle) * 6.0 - fmod(clock * 6.0 + i * 3.0, 16.0)) * Vector2(scale, scale)).round(), Vector2(2, 2)), Color(0.84, 0.75, 1.0, 0.6))
	var points := [Vector2(0, -11), Vector2(5, -4), Vector2(4, 6), Vector2(0, 11), Vector2(-4, 6), Vector2(-5, -4)]
	var shell := PackedVector2Array()
	for p: Vector2 in points: shell.append(at + bob + p * s)
	canvas.draw_colored_polygon(shell, Color("8a5cf0"))
	canvas.draw_colored_polygon(PackedVector2Array([at + bob + Vector2(0, -11) * s, at + bob + Vector2(5, -4) * s, at + bob + Vector2(0, -1) * s]), Color("c9b0ff"))
	canvas.draw_colored_polygon(PackedVector2Array([at + bob + Vector2(0, -3) * s, at + bob + Vector2(2, 1) * s, at + bob + Vector2(0, 5) * s, at + bob + Vector2(-2, 1) * s]), Color("170a30"))
	canvas.draw_polyline(shell + PackedVector2Array([shell[0]]), Color("d9c8ff"), 1.0)
