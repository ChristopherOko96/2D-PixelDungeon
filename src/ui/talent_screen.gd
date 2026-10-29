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
## Look: soft-edged cards with a branch-coloured header, icons at 3x (4x for
## ultimates), rank pips, and Pixelify Sans for names and text so it reads
## crisp; the pixel font stays for headings.

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
## Smooth, crisp text for names, values and descriptions.
const TEXT_FACE: FontFile = preload("res://assets/fonts/pixelify_sans.ttf")
const BG := Color("0d0b10")
const CARD := Color("17141c")
const CARD_EDGE := Color(1, 1, 1, 0.10)
const WELL := Color("100e14")
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
## Pixelify Sans, antialiased (names, values, descriptions).
var _sans: FontFile
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
	_sans = TEXT_FACE.duplicate()
	_sans.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	mouse_filter = Control.MOUSE_FILTER_STOP
	var x := 280.0
	for id: String in ["mage", "archer", "swordsman"]:
		_add_button("tab_" + id, CLASS_NAMES[id], Rect2(x, 14, 200, 36), func(): _pick_class(id))
		x += 212.0
	_add_button("close", "ZURÜCK", Rect2(1094, 14, 170, 36), func(): visible = false; closed.emit())
	_add_button("difficulty", "", Rect2(LEFT.position.x + 12, 554, LEFT.size.x - 24, 32), _cycle_difficulty)
	_add_button("reset", "", Rect2(LEFT.position.x + 12, 592, LEFT.size.x - 24, 32), _reset)
	_add_button("learn", "", Rect2(RIGHT.position.x + 12, 470, RIGHT.size.x - 24, 36), _learn)
	_add_button("unlearn", "Punkt zurücknehmen", Rect2(RIGHT.position.x + 12, 512, RIGHT.size.x - 24, 32), _unlearn)
	_add_button("bar", "", Rect2(RIGHT.position.x + 12, 550, RIGHT.size.x - 24, 32), _cycle_bar)
	_add_button("soul", "", Rect2(RIGHT.position.x + 12, 588, RIGHT.size.x - 24, 32), _soul_up)
	_add_button("companion", "", Rect2(RIGHT.position.x + 12, 428, RIGHT.size.x - 24, 32), _cycle_companion)
	for key: String in _buttons:
		# Tabs keep the pixel heading face; the panel buttons read in Pixelify Sans.
		if key.begins_with("tab_") or key == "close":
			_buttons[key].add_theme_font_size_override("font_size", 16)
		else:
			_buttons[key].add_theme_font_override("font", _sans)
			_buttons[key].add_theme_font_size_override("font_size", 15)


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
	learn.text = "Freischalten · %d Seelensplitter" % int(data.soul_shards.ultimate_cost) if str(info.kind) == "ultimate" else ("Rang verbessern" if rank > 0 else "Punkt investieren")
	learn.disabled = not why.is_empty()
	learn.tooltip_text = why
	_buttons.unlearn.disabled = not Rules.can_rank_down(data, profile, class_id, selected)
	var bar: Button = _buttons.bar
	bar.visible = str(info.kind) == "active"
	var slot: int = state.bar.find(selected)
	bar.text = ("Leiste: Shift + %d" % (slot + 1)) if slot >= 0 else "Auf die Leiste legen"
	bar.disabled = rank <= 0
	var soul: Button = _buttons.soul
	soul.visible = str(info.kind) == "ultimate"
	var tier := int(state.soul_tier)
	var owned: bool = str(state.ultimate) == selected
	soul.text = "Seelenstufe 3 erreicht" if tier >= 3 and owned else ("Seelenstufe %d · %d Splitter" % [tier + 1, int(data.soul_shards.tier_costs[mini(tier, 2)])] if owned else "Erst freischalten")
	soul.disabled = not owned or tier >= 3 or int(profile.shards.have) < int(data.soul_shards.tier_costs[mini(tier, 2)])
	# the beast master picks the companion (wolf or bear) on any of its talents
	var companion: Button = _buttons.companion
	companion.visible = str(info.spec) == "beast"
	var kinds: Dictionary = data.get("pet", {}).get("kinds", {})
	companion.text = "Begleiter: %s (wechseln)" % str(kinds.get(str(state.get("companion", "wolf")), {}).get("name", "Wolf"))
	var difficulty := str(profile.get("difficulty", "normal"))
	_buttons.difficulty.text = "Schwierigkeit: %s" % str(data.difficulties[difficulty].name)
	_buttons.reset.text = "Zurücksetzen · %d Gold" % Rules.reset_cost(data, profile, class_id)
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


func _cycle_companion() -> void:
	var kinds: Array = data.get("pet", {}).get("kinds", {}).keys()
	var state := _state()
	state.companion = kinds[(kinds.find(str(state.get("companion", "wolf"))) + 1) % kinds.size()]
	_commit("", "Dein Begleiter ist jetzt: %s." % str(data.pet.kinds[state.companion].name))


func _cycle_difficulty() -> void:
	var order: Array = data.difficulties.order
	profile.difficulty = order[(order.find(str(profile.get("difficulty", "normal"))) + 1) % order.size()]
	_commit("", "Schwierigkeit: %s (Bosssieg %d Seelensplitter, %d %% Chance auf einen mehr)." % [data.difficulties[profile.difficulty].name, int(data.soul_shards.get("per_boss", 2)), int(data.difficulties[profile.difficulty].get("extra_pct", 0))])


# ---------- drawing ----------

func _draw() -> void:
	if data.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# a faint warm glow behind the tree
	for i in range(6):
		draw_circle(TREE.get_center(), 420.0 - i * 60.0, Color(0.35, 0.25, 0.45, 0.025))
	_text("TALENTE", Vector2(24, 42), 24, CryptUI.GOLD)
	_card(LEFT, CARD)
	_card(TREE, Color(CARD, 0.75))
	_card(RIGHT, CARD)
	_draw_left()
	_draw_tree()
	_draw_right()


## A label over a value, the way every row of the side cards reads.
func _row(label: String, value: String, y: float, color: Color = CryptUI.CREAM) -> void:
	var x := LEFT.position.x + 16
	_say(label, Vector2(x, y), 13, CryptUI.MUTED)
	_say(value, Vector2(x, y + 22), 18, color)


func _draw_left() -> void:
	var state := _state()
	var x := LEFT.position.x + 16
	var w := LEFT.size.x - 32
	var y := LEFT.position.y + 32
	_say("Charakter", Vector2(x, y), 13, CryptUI.MUTED)
	_text(CLASS_NAMES[class_id], Vector2(x, y + 28), 24 if str(CLASS_NAMES[class_id]).length() <= 8 else 16, CryptUI.CREAM)
	# level with its EXP track
	var level := int(state.level)
	var need := Rules.exp_to_next(data, level)
	_say("Level %d / %d" % [level, int(data.max_level)], Vector2(x, y + 62), 18, CryptUI.CREAM)
	var track := Rect2(x, y + 72, w, 8)
	_card(track, WELL, CARD_EDGE, 4, 0)
	var share := 1.0 if level >= int(data.max_level) else clampf(float(state.exp) / need, 0.0, 1.0)
	if share > 0.0: _card(Rect2(track.position, Vector2(maxf(8.0, w * share), 8)), CryptUI.GOLD, Color(0, 0, 0, 0), 4, 0)
	_say("%d / %d EXP" % [int(state.exp), need] if level < int(data.max_level) else "Höchstes Level", Vector2(x, y + 98), 13, CryptUI.MUTED)
	var free := Rules.free_points(data, state)
	_row("Talentpunkte", "%d frei von %d" % [free, Rules.points_total(data, level)], y + 128, CryptUI.GOLD if free > 0 else CryptUI.CREAM)
	# soul shards: the crystal, the count big, earned and spent small
	var shard_box := Rect2(x - 4, y + 182, w + 8, 84)
	_card(shard_box, Color(0.22, 0.12, 0.38, 0.55), Color(0.69, 0.42, 0.85, 0.45), 8, 0)
	_say("Seelensplitter", Vector2(x + 6, y + 202), 13, Color("c9b6ff"))
	draw_crystal(self, Vector2(x + 22, y + 230), 0.9, _clock)
	_say(str(int(profile.shards.have)), Vector2(x + 46, y + 240), 28, Color("e2d4ff"))
	_say("erhalten %d · ausgegeben %d" % [int(profile.shards.earned), int(profile.shards.spent)], Vector2(x + 48, y + 258), 11, CryptUI.MUTED)
	_row("Gold", str(int(profile.gold)), y + 290, CryptUI.GOLD)
	var res: Dictionary = data.resources[class_id]
	_row(str(res.name), ("0–%d, +%d pro Treffer" % [int(res.max), int(res.per_hit)]) if str(res.kind) == "rage" else ("%d, +%d pro Sekunde" % [int(res.max), int(res.regen)]), y + 340)
	var spec_y := y + 400
	for spec: Dictionary in data.classes[class_id].specs:
		var points := Rules.spec_points(data, state, str(spec.id))
		_card(Rect2(x, spec_y - 12, 4, 14), Color(str(spec.color)), Color(0, 0, 0, 0), 2, 0)
		_say(str(spec.name), Vector2(x + 12, spec_y), 15, CryptUI.CREAM)
		var label := str(points)
		_say(label, Vector2(x + w - _sans.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, spec_y), 15, Color(str(spec.color2)) if points > 0 else CryptUI.MUTED)
		spec_y += 24
	_say("Leiste: Shift + 1–4 · Ultimate: R", Vector2(x, LEFT.end.y - 14), 11, CryptUI.MUTED)


func _draw_tree() -> void:
	_hits.clear()
	var state := _state()
	var column_w := (TREE.size.x - 32) / 3.0
	var rows := [[0, 1], [2, 3], [4], [5]]
	for i in range(3):
		var spec: Dictionary = data.classes[class_id].specs[i]
		var color := Color(str(spec.color))
		var light := Color(str(spec.color2))
		var column := Rect2(TREE.position.x + 8 + (column_w + 8) * i, TREE.position.y + 10, column_w, TREE.size.y - 20)
		var cx := column.get_center().x
		# the branch card with its coloured header
		_card(column, Color(WELL, 0.85), Color(color, 0.25), 8, 0)
		var head := Rect2(column.position, Vector2(column.size.x, 56))
		_card(head, Color(color.darkened(0.55), 0.9), Color(color, 0.6), 8, 0)
		draw_rect(Rect2(head.position + Vector2(8, head.size.y - 2), Vector2(head.size.x - 16, 2)), Color(light, 0.6))
		_text_centered(str(spec.name).to_upper(), Vector2(cx, head.position.y + 26), 16, CryptUI.CREAM)
		var points := Rules.spec_points(data, state, str(spec.id))
		_say_centered("%d Punkte" % points, Vector2(cx, head.position.y + 46), 13, light if points > 0 else CryptUI.MUTED)
		var row_y := [column.position.y + 116, column.position.y + 240, column.position.y + 364, column.position.y + 484]
		var centers := {}
		for r in range(4):
			var ids: Array = rows[r]
			for k in range(ids.size()):
				centers[str(spec.talents[ids[k]])] = Vector2(cx + 12.0 + (k - (ids.size() - 1) * 0.5) * 104.0, row_y[r])
		# lines first, so icons sit on top: each tier hangs from the one above
		for r in range(1, 4):
			for id_above: int in rows[r - 1]:
				for id_below: int in rows[r]:
					var a: Vector2 = centers[str(spec.talents[id_above])] + Vector2(0, 30)
					var b: Vector2 = centers[str(spec.talents[id_below])] - Vector2(0, 36 if r == 3 else 30)
					var lit: bool = Rules.rank(state, str(spec.talents[id_below])) > 0
					draw_line(a, b, Color(0, 0, 0, 0.6), 6.0, true)
					draw_line(a, b, color if lit else Color(color, 0.22), 3.0, true)
					if lit: draw_line(a, b, Color(light, 0.5), 1.0, true)
		# tier badges on the left edge of the column
		for r in range(4):
			var tier: Dictionary = data.tiers[str(r + 1)]
			var badge := Rect2(column.position.x + 5, row_y[r] - 26, 28, 36)
			_card(badge, Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.06), 5, 0)
			_say_centered(TIER_NAMES[r], badge.get_center() + Vector2(0, 0), 15, CryptUI.BONE)
			_say_centered("Lv %d" % int(tier.level), badge.get_center() + Vector2(0, 14), 10, CryptUI.MUTED)
		for id: String in centers: _draw_talent(id, centers[id], spec, color)


func _draw_talent(id: String, center: Vector2, spec: Dictionary, color: Color) -> void:
	var info: Dictionary = data.talents[id]
	var state := _state()
	var ult: bool = str(info.kind) == "ultimate"
	var look := talent_state(id)
	var side := 72.0 if ult else 54.0
	var rect := Rect2((center - Vector2(side, side) * 0.5).round(), Vector2(side, side))
	_hits[id] = rect.grow(8)
	var lit: bool = look in ["learned", "max", "available"]
	var light := Color(str(spec.color2))
	var pulse: float = float(_pulses.get(id, 0.0))
	if pulse > 0.0:
		var grow := (0.45 - pulse) / 0.45
		draw_circle(center, side * (0.6 + grow * 0.6), Color(light, 0.5 * (1.0 - grow)))
	# the frame: gold at max rank, glowing when it can take a point
	var frame := CryptUI.GOLD if look == "max" else color if lit else Color("4a4450")
	if look == "available":
		var glow := 0.35 + 0.25 * sin(_clock * 4.0)
		_card(rect.grow(7), Color(color, glow * 0.35), Color(light, glow), 10, 0)
	if id == selected: _card(rect.grow(10), Color(0, 0, 0, 0), CryptUI.CREAM, 12, 0)
	_card(rect.grow(3), Color("0a090c"), frame, 7, 4)
	draw_texture_rect(_icon(spec, str(info.icon), lit, ult), rect, false, Color(1, 1, 1, 0.45) if look == "locked" else Color.WHITE)
	if look == "locked": draw_rect(rect, Color(0, 0, 0, 0.35))
	# rank pips under the icon
	var ranks := int(info.ranks)
	var rank := Rules.rank(state, id)
	var pip := Vector2(10, 5)
	var span := ranks * pip.x + (ranks - 1) * 4.0
	for k in range(ranks):
		var at := Vector2(center.x - span * 0.5 + k * (pip.x + 4.0), rect.end.y + 7)
		var on := k < rank
		_card(Rect2(at, pip), (CryptUI.GOLD if look == "max" else light) if on else Color(0, 0, 0, 0.6), Color(1, 1, 1, 0.15) if not on else Color(0, 0, 0, 0), 2, 0)
	if look == "no_shards":
		draw_crystal(self, rect.position + Vector2(-2, -4), 0.55, _clock)
		_say("%d" % int(data.soul_shards.ultimate_cost), rect.position + Vector2(8, 6), 15, Color("e2d4ff"))
	# names in Pixelify, wrapped to two lines so neighbours never touch
	var name_lines := _wrap_lines(str(info.name), 96.0, 11)
	for n in range(name_lines.size()):
		_say_centered(name_lines[n], center + Vector2(0, side * 0.5 + 28 + n * 13), 11, CryptUI.CREAM if lit else CryptUI.MUTED)


func _wrap_lines(text: String, width: float, font_size: int) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word: String in text.split(" "):
		var trial := word if current.is_empty() else current + " " + word
		if _sans.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not current.is_empty():
			lines.append(current)
			current = word
		else: current = trial
	if not current.is_empty(): lines.append(current)
	return lines


func _draw_right() -> void:
	var info: Dictionary = data.talents[selected]
	var state := _state()
	var spec: Dictionary = data.classes[class_id].specs.filter(func(s: Dictionary) -> bool: return str(s.id) == str(info.spec))[0]
	var spec_color := Color(str(spec.color))
	var x := RIGHT.position.x + 16
	var y := RIGHT.position.y + 18
	var ult: bool = str(info.kind) == "ultimate"
	# header: the big icon beside name and kind
	var head := Rect2(RIGHT.position + Vector2(8, 8), Vector2(RIGHT.size.x - 16, 96))
	_card(head, Color(spec_color.darkened(0.6), 0.85), Color(spec_color, 0.5), 8, 0)
	var icon_rect := Rect2(head.position + Vector2(12, 12), Vector2(72, 72))
	_card(icon_rect.grow(2), Color("0a090c"), CryptUI.GOLD if ult else spec_color, 7, 0)
	draw_texture_rect(_icon(spec, str(info.icon), true, ult), icon_rect, false)
	var kind: String = {"active": "Aktiv", "passive": "Passiv", "ultimate": "Ultimate"}[str(info.kind)]
	_say("Stufe %s · %s" % [TIER_NAMES[int(info.tier) - 1], kind], Vector2(head.position.x + 96, head.position.y + 26), 13, Color(str(spec.color2)))
	var name_lines := _wrap_lines(str(info.name), head.size.x - 108, 20)
	for n in range(name_lines.size()):
		_say(name_lines[n], Vector2(head.position.x + 96, head.position.y + 52 + n * 22), 20, CryptUI.CREAM)
	var rank := Rules.rank(state, selected)
	_say("Rang %d / %d" % [rank, int(info.ranks)], Vector2(head.position.x + 96, head.end.y - 12), 13, CryptUI.GOLD)
	var line := head.end.y + 30
	line = _paragraph(_rank_text(str(info.text), maxi(rank, 1) if rank > 0 else 0), x, line, CryptUI.CREAM)
	if rank > 0 and rank < int(info.ranks): line = _paragraph("Nächster Rang: " + _rank_text(str(info.text), rank + 1), x, line + 4, CryptUI.MUTED, 13)
	line += 10
	if info.has("cost"):
		_stat("Kosten", "%d %s" % [int(info.cost), str(data.resources[class_id].name)], line)
		_stat("Abklingzeit", "%d s" % int(info.cd), line + 22)
		line += 50
	var tier: Dictionary = data.tiers[str(int(info.tier))]
	var requirement := "Level %d" % int(tier.level)
	if int(tier.points) > 0: requirement += ", %d Punkte im Zweig" % int(tier.points)
	if ult: requirement += ", %d Seelensplitter, nur eine Ultimate" % int(data.soul_shards.ultimate_cost)
	line = _paragraph("Voraussetzung: " + requirement, x, line + 4, CryptUI.MUTED, 13)
	if ult and str(state.ultimate) == selected and int(state.soul_tier) > 0:
		_say("Seelenstufe %d: +%d %%" % [int(state.soul_tier), int(data.soul_shards.tier_bonus_pct[int(state.soul_tier) - 1])], Vector2(x, line + 8), 15, Color("c9b6ff"))
	var why := Rules.check_rank_up(data, profile, class_id, selected)
	var note := message if not message.is_empty() else why
	if not note.is_empty(): _paragraph(note, x, 404 if str(info.spec) == "beast" else 440, CryptUI.BLOOD if note == why and not why.is_empty() else CryptUI.GOLD, 13)


## A stat row of the detail card: label left, value right.
func _stat(label: String, value: String, y: float) -> void:
	var x := RIGHT.position.x + 16
	var right := RIGHT.end.x - 16
	_say(label, Vector2(x, y), 15, CryptUI.MUTED)
	_say(value, Vector2(right - _sans.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, y), 15, CryptUI.CREAM)
	draw_line(Vector2(x, y + 7), Vector2(right, y + 7), Color(1, 1, 1, 0.05), 1.0)


## "125/145/165 %" -> the value of `rank` (1-3), or all values for rank 0.
func _rank_text(text: String, rank: int) -> String:
	if rank <= 0: return text
	var regex := RegEx.create_from_string("(\\d+(?:,\\d+)?)/(\\d+(?:,\\d+)?)/(\\d+(?:,\\d+)?)")
	var out := text
	for m: RegExMatch in regex.search_all(text): out = out.replace(m.get_string(0), m.get_string(clampi(rank, 1, 3)))
	return out


func _paragraph(text: String, x: float, y: float, color: Color, font_size: int = 15) -> float:
	var width := RIGHT.size.x - 28
	var current := ""
	for word: String in text.split(" "):
		var trial := word if current.is_empty() else current + " " + word
		if _sans.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not current.is_empty():
			_say(current, Vector2(x, y), font_size, color)
			y += font_size + 5
			current = word
		else: current = trial
	if not current.is_empty():
		_say(current, Vector2(x, y), font_size, color)
		y += font_size + 5
	return y


func _icon(spec: Dictionary, motif: String, on: bool, ultimate := false) -> Texture2D:
	return TalentIcons.make(spec, motif, on, ultimate)


func _text(text: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_centered(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Pixelify Sans text (names, values, descriptions).
func _say(text: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(_sans, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _say_centered(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var width := _sans.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_sans, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## A card: rounded, filled, a faint edge and a soft shadow below.
func _card(rect: Rect2, fill: Color, edge: Color = CARD_EDGE, radius: int = 8, shadow: int = 6) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = shadow
	box.shadow_offset = Vector2(0, 3)
	box.anti_aliasing = true
	draw_style_box(box, rect)


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
