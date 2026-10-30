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

const CLASS_NAMES := {"mage": "MAGIER", "archer": "BOGENSCHÜTZE", "swordsman": "KRIEGER", "necromancer": "NEKROMANT"}
const CLASS_ORDER := ["mage", "archer", "swordsman", "necromancer"]
const TIER_NAMES := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
## Smooth, crisp text for names, values and descriptions.
const TEXT_FACE: FontFile = preload("res://assets/fonts/pixelify_sans.ttf")
const BG := Color("0d0b10")
const CARD := Color("17141c")
const CARD_EDGE := Color(1, 1, 1, 0.10)
const WELL := Color("100e14")
## Layout after the user's concept sheet (30.10.2026): branch banners on top,
## the row tablets on the left, the tree in the middle (actives left, passives
## right, joined by a glowing spine), the detail card on the right.
const BADGES := Rect2(16, 118, 64, 590)
const TREE := Rect2(92, 118, 772, 590)
const RIGHT := Rect2(876, 118, 388, 590)
const BANNERS := Rect2(92, 52, 772, 58)
const INFO := Rect2(876, 52, 388, 58)

var data: Dictionary = {}
var profile: Dictionary = {}
var save_path := Profile.SAVE_PATH
var class_id := "mage"
var selected := ""
var message := ""
## The branch shown in the tree (one at a time; user decision 29.10.2026:
## a character follows one branch, the first point picks it).
var shown_spec := ""
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
	if selected.is_empty() or str(data.talents.get(selected, {}).get("class", "")) != class_id:
		var chosen := Rules.chosen_spec(data, _state())
		selected = str(_spec(chosen).talents[0]) if not chosen.is_empty() else str(data.classes[class_id].specs[0].talents[0])
	visible = true
	_refresh()


func _ready() -> void:
	size = Vector2(1280, 720)
	theme = CryptUI.create_theme()
	_font = PixelStyle.create_font()
	_sans = TEXT_FACE.duplicate()
	_sans.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	mouse_filter = Control.MOUSE_FILTER_STOP
	var x := 150.0
	for id: String in CLASS_ORDER:
		_add_button("tab_" + id, CLASS_NAMES[id], Rect2(x, 10, 134, 32), func(): _pick_class(id))
		x += 140.0
	_add_button("difficulty", "", Rect2(718, 10, 186, 32), _cycle_difficulty)
	_add_button("reset", "", Rect2(910, 10, 196, 32), _reset)
	_add_button("close", "ZURÜCK", Rect2(1112, 10, 152, 32), func(): visible = false; closed.emit())
	var inner := RIGHT.size.x - 32
	_add_button("companion", "", Rect2(RIGHT.position.x + 16, 548, inner, 30), _cycle_companion)
	_add_button("learn", "", Rect2(RIGHT.position.x + 16, 584, inner, 36), _learn)
	_add_button("unlearn", "Punkt zurücknehmen", Rect2(RIGHT.position.x + 16, 626, inner, 34), _unlearn)
	_add_button("bar", "", Rect2(RIGHT.position.x + 16, 666, inner, 34), _cycle_bar)
	_add_button("soul", "", Rect2(RIGHT.position.x + 16, 666, inner, 34), _soul_up)
	for key: String in _buttons:
		# Tabs keep the pixel heading face; the panel buttons read in Pixelify Sans
		# on bronze plates like the concept sheet.
		if key.begins_with("tab_") or key == "close":
			_buttons[key].add_theme_font_size_override("font_size", 12)
		else:
			_buttons[key].add_theme_font_override("font", _sans)
			_buttons[key].add_theme_font_size_override("font_size", 17 if key == "learn" else 15)
		if key in ["learn", "unlearn", "bar", "soul", "companion", "difficulty", "reset"]: _bronze(_buttons[key], key == "learn")


## A bronze plate with a gold rim for the detail card's buttons.
func _bronze(button: Button, main: bool) -> void:
	var looks := {"normal": [Color("4a2c16") if main else Color("2c2018"), Color("d8a24a") if main else Color("8a6a3a")],
		"hover": [Color("62391c") if main else Color("3c2a1e"), Color("f2c66d")], "pressed": [Color("2e1a0c"), Color("f2c66d")],
		"disabled": [Color("1e1a18"), Color("4a4038")], "focus": [Color(0, 0, 0, 0), Color("f2c66d")]}
	for state: String in looks:
		var box := StyleBoxFlat.new()
		box.bg_color = looks[state][0]
		box.border_color = looks[state][1]
		box.set_border_width_all(2)
		box.set_corner_radius_all(3)
		if state == "focus": box.draw_center = false
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color("f6e3bf"))
	button.add_theme_color_override("font_hover_color", Color("fff2d0"))
	button.add_theme_color_override("font_disabled_color", Color("6a6058"))


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
				if id.begins_with("spec:"):
					_show_spec(id.trim_prefix("spec:"))
					accept_event()
					return
				selected = id
				message = ""
				_refresh()
				accept_event()
				return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		for id: String in _hits:
			if Rect2(_hits[id]).has_point(event.position) and not id.begins_with("spec:"):
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
	# the tree shows the branch of the selected talent
	if data.talents.has(selected) and str(data.talents[selected]["class"]) == class_id: shown_spec = str(data.talents[selected].spec)
	for id: String in CLASS_ORDER: _buttons["tab_" + id].disabled = id == class_id
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
	bar.text = ("Leiste: Taste %d" % (slot + 1)) if slot >= 0 else "Auf die Leiste legen"
	bar.disabled = rank <= 0
	var soul: Button = _buttons.soul
	soul.visible = str(info.kind) == "ultimate"
	var tier := int(state.soul_tier)
	var owned: bool = str(state.ultimate) == selected
	var costs: Array = data.soul_shards.tier_costs
	var top := tier >= costs.size()
	var next_cost := int(costs[mini(tier, costs.size() - 1)])
	soul.text = ("Stufe %d erreicht" % (costs.size() + 1) if top else "Stufe %d · %d Seelensplitter" % [tier + 2, next_cost]) if owned else "Erst freischalten"
	soul.disabled = not owned or top or int(profile.shards.have) < next_cost
	# an owned ultimate needs no unlock button: the stage button moves up into
	# the talent bar's place, so the three stages have room above
	learn.visible = not (str(info.kind) == "ultimate" and owned)
	soul.position.y = 626.0 if owned else 666.0
	_buttons.unlearn.visible = not owned
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
	var chosen := Rules.chosen_spec(data, _state())
	shown_spec = chosen if not chosen.is_empty() else str(data.classes[id].specs[0].id)
	selected = _spec(shown_spec).talents[0]
	message = ""
	_refresh()


## Shows another branch of the class (its first talent selected).
func _show_spec(spec_id: String) -> void:
	shown_spec = spec_id
	selected = str(_spec(spec_id).talents[0])
	message = ""
	_refresh()


func _spec(spec_id: String) -> Dictionary:
	for spec: Dictionary in data.classes[class_id].specs:
		if str(spec.id) == spec_id: return spec
	return data.classes[class_id].specs[0]


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
	_commit(Rules.set_bar(data, profile, class_id, selected, slot), "Liegt jetzt auf Taste %d." % (slot + 1))


func _soul_up() -> void:
	var reason := Rules.soul_up(data, profile, class_id)
	var stages: Array = data.talents[selected].get("stages", [])
	var tier := int(_state().soul_tier)
	if reason.is_empty(): _pulses[selected] = 0.45
	_commit(reason, "Stufe %d: %s." % [tier + 1, str(stages[tier - 1].name)] if tier > 0 and tier <= stages.size() else "")


func _reset() -> void:
	_commit(Rules.reset(data, profile, class_id), "Alle Punkte und Seelensplitter sind erstattet.")


func _cycle_companion() -> void:
	# the beast master picks among the companions; skeletons belong to the necromancer
	var all_kinds: Dictionary = data.get("pet", {}).get("kinds", {})
	var kinds: Array = all_kinds.keys().filter(func(k: String) -> bool: return not bool(all_kinds[k].get("summon_only", false)))
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
	var spec := _spec(shown_spec) if not shown_spec.is_empty() else _spec(str(data.classes[class_id].specs[0].id))
	var color := Color(str(spec.color))
	var light := Color(str(spec.color2))
	_draw_backdrop(color, light)
	_text("TALENTE", Vector2(16, 34), 20, CryptUI.GOLD)
	_draw_info()
	_draw_badges(color)
	_frame(TREE, Color(0.03, 0.02, 0.03, 0.72), color)
	_frame(RIGHT, Color(0.04, 0.03, 0.04, 0.9), color)
	_draw_tree()
	_draw_right()


## The backdrop: dark, tinted with the branch's colour from below, embers
## rising and a dark rim around the screen (the concept sheet's mood).
func _draw_backdrop(color: Color, light: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for i in range(12):
		var band := Rect2(0, size.y * (1.0 - (i + 1) / 12.0), size.x, size.y / 12.0 + 1.0)
		draw_rect(band, Color(color.darkened(0.55), 0.16 * (1.0 - i / 12.0)))
	for i in range(5):
		draw_circle(TREE.get_center() + Vector2(0, 160), 520.0 - i * 90.0, Color(color, 0.025))
	for i in range(46):
		var seed_x := fmod(float(i) * 97.31, size.x)
		var speed := 18.0 + float(i % 7) * 6.0
		var y := size.y - fmod(_clock * speed + float(i) * 53.0, size.y + 40.0)
		var x := seed_x + sin(_clock * 0.9 + i) * 10.0
		var fade := clampf(y / size.y, 0.0, 1.0)
		draw_rect(Rect2(Vector2(x, y).round(), Vector2(2, 2)), Color(light, 0.55 * fade))
	for i in range(8):
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.0), false, 0.0)
		draw_rect(Rect2(i * 3, i * 3, size.x - i * 6, size.y - i * 6), Color(0, 0, 0, 0.09), false, 3.0)


## A panel in the concept's look: a dark fill, a rim in the branch colour and
## small diamonds on the corners.
func _frame(rect: Rect2, fill: Color, color: Color) -> void:
	_card(rect, fill, Color(color, 0.55), 4, 8)
	draw_rect(rect.grow(-4), Color(color, 0.18), false, 1.0)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		_diamond(corner, 5.0, CryptUI.GOLD)


func _diamond(at: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), color)
	draw_polyline(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0), at + Vector2(0, -r)]), Color("1a1010"), 1.0)


## Top right: level, free points, soul shards and gold of the class.
func _draw_info() -> void:
	var state := _state()
	_card(INFO, Color(0.05, 0.04, 0.05, 0.9), Color(1, 1, 1, 0.1), 4, 4)
	var level := int(state.level)
	var free := Rules.free_points(data, state)
	_say("%s · Level %d" % [CLASS_NAMES[class_id], level], INFO.position + Vector2(14, 22), 15, CryptUI.CREAM)
	_say("%d Talentpunkte frei" % free, INFO.position + Vector2(14, 44), 14, CryptUI.GOLD if free > 0 else CryptUI.MUTED)
	draw_crystal(self, INFO.position + Vector2(236, 30), 0.65, _clock)
	_say(str(int(profile.shards.have)), INFO.position + Vector2(254, 38), 20, Color("e2d4ff"))
	_say("Gold %d" % int(profile.gold), INFO.position + Vector2(300, 38), 14, CryptUI.GOLD)


## The row tablets on the left: numeral, the level it opens at and the
## points the branch needs; lit as far as the branch reaches.
func _draw_badges(color: Color) -> void:
	var state := _state()
	var points := Rules.spec_points(data, state, shown_spec)
	var row_h := BADGES.size.y / 8.0
	for t in range(1, 9):
		var tier: Dictionary = data.tiers[str(t)]
		var open := points >= int(tier.points) and int(state.level) >= int(tier.level)
		var badge := Rect2(BADGES.position.x, BADGES.position.y + row_h * (t - 1) + 4, BADGES.size.x, row_h - 8)
		_card(badge, Color(0.07, 0.05, 0.05, 0.92), Color(color, 0.7) if open else Color(1, 1, 1, 0.12), 6, 4)
		draw_rect(badge.grow(-3), Color(color, 0.15 if open else 0.04), false, 1.0)
		_text_centered(TIER_NAMES[t - 1], badge.get_center() + Vector2(0, -6), 20, CryptUI.BONE if open else CryptUI.MUTED)
		_say_centered("Lv %d" % int(tier.level), badge.get_center() + Vector2(0, 12), 12, CryptUI.CREAM if open else CryptUI.MUTED)
		if int(tier.points) > 0: _say_centered("%d P" % int(tier.points), badge.get_center() + Vector2(0, 26), 11, CryptUI.MUTED)


## One branch at a time under its banner (the chosen one "dein Zweig", the
## others locked once a point is spent). Rows I-VI: the active left, the
## passive right, a line through a diamond on the spine between them; row VII
## and the ultimate stand on the spine. The spine glows as deep as the branch
## reaches.
func _draw_tree() -> void:
	_hits.clear()
	var state := _state()
	if shown_spec.is_empty() or str(_spec(shown_spec).id) != shown_spec:
		var chosen := Rules.chosen_spec(data, state)
		shown_spec = chosen if not chosen.is_empty() else str(data.classes[class_id].specs[0].id)
	var chosen_spec := Rules.chosen_spec(data, state)
	# the branch banners
	var specs: Array = data.classes[class_id].specs
	var tab_w := (BANNERS.size.x - 12.0 * (specs.size() - 1)) / float(specs.size())
	for i in range(specs.size()):
		var spec: Dictionary = specs[i]
		var tint := Color(str(spec.color))
		var tab := Rect2(BANNERS.position.x + i * (tab_w + 12.0), BANNERS.position.y, tab_w, BANNERS.size.y)
		var shown: bool = str(spec.id) == shown_spec
		var locked: bool = not chosen_spec.is_empty() and chosen_spec != str(spec.id)
		_card(tab, Color(tint.darkened(0.6), 0.95 if shown else 0.55), CryptUI.GOLD if shown else Color(tint, 0.45), 4, 6 if shown else 2)
		if shown:
			draw_rect(tab.grow(-3), Color(Color(str(spec.color2)), 0.5), false, 1.0)
			for k in range(6): draw_circle(tab.get_center() + Vector2(0, 30), 60.0 - k * 9.0, Color(tint, 0.05))
		var icon_rect := Rect2(tab.position + Vector2(14, 11), Vector2(36, 36))
		draw_texture_rect(_icon(spec, _banner_motif(str(spec.id)), not locked or shown), icon_rect, false)
		_text(str(spec.name).to_upper(), Vector2(icon_rect.end.x + 12, tab.position.y + 27), 16, CryptUI.CREAM if not locked else CryptUI.MUTED)
		var note := "gesperrt" if locked else ("dein Zweig" if str(spec.id) == chosen_spec else "noch frei wählbar")
		if str(spec.id) == chosen_spec and not chosen_spec.is_empty(): note = "dein Zweig · %d Punkte" % Rules.spec_points(data, state, str(spec.id))
		_say(note, Vector2(icon_rect.end.x + 12, tab.position.y + 46), 12, Color(str(spec.color2)) if not locked else CryptUI.MUTED)
		_hits["spec:" + str(spec.id)] = tab
	var spec: Dictionary = _spec(shown_spec)
	var color := Color(str(spec.color))
	var light := Color(str(spec.color2))
	var area := TREE.grow(-8)
	var row_h := area.size.y / 8.0
	var spine_x := area.position.x + area.size.x * 0.5
	var left_x := area.position.x + 150.0
	var right_x := spine_x + 110.0
	var per_tier := {}
	for id: String in spec.talents:
		var tier := int(data.talents[id].tier)
		if not per_tier.has(tier): per_tier[tier] = []
		per_tier[tier].append(id)
	# actives to the left, passives to the right, as on the concept sheet
	for tier: int in per_tier:
		per_tier[tier].sort_custom(func(a: String, b: String) -> bool: return str(data.talents[a].kind) == "active" and str(data.talents[b].kind) != "active")
	var points := Rules.spec_points(data, state, shown_spec)
	var reached := 0
	for t in range(1, 9):
		if points >= int(data.tiers[str(t)].points) and int(state.level) >= int(data.tiers[str(t)].level): reached = t
	var top_y := area.position.y + row_h * 0.5
	var bottom_y := area.position.y + row_h * 7.5
	draw_line(Vector2(spine_x, top_y), Vector2(spine_x, bottom_y), Color(0, 0, 0, 0.7), 7.0, true)
	draw_line(Vector2(spine_x, top_y), Vector2(spine_x, bottom_y), Color(color, 0.25), 3.0, true)
	if reached > 0:
		var lit_y := top_y + row_h * (reached - 1)
		draw_line(Vector2(spine_x, top_y), Vector2(spine_x, lit_y), Color(light, 0.35), 9.0, true)
		draw_line(Vector2(spine_x, top_y), Vector2(spine_x, lit_y), color, 3.0, true)
	for t in range(1, 9):
		var y := area.position.y + row_h * (t - 0.5)
		var ids: Array = per_tier.get(t, [])
		var open := t <= reached
		if ids.size() > 1:
			var learned: bool = ids.any(func(id: String) -> bool: return Rules.rank(state, id) > 0)
			draw_line(Vector2(left_x + 30, y), Vector2(right_x - 30, y), Color(0, 0, 0, 0.6), 5.0, true)
			draw_line(Vector2(left_x + 30, y), Vector2(right_x - 30, y), color if learned else Color(color, 0.3 if open else 0.12), 2.0, true)
		if ids.size() != 1 or t < 7: _diamond(Vector2(spine_x, y), 7.0, color if open else Color("3a3238"))
		for k in range(ids.size()):
			var x: float = spine_x if ids.size() == 1 else (left_x if k == 0 else right_x)
			_draw_talent(str(ids[k]), Vector2(x, y), spec, color)


## The motif shown on a branch banner.
func _banner_motif(spec_id: String) -> String:
	return {"fire": "flame", "frost": "snowflake", "arcane": "echo", "sniper": "arrow", "trapper": "trap", "beast": "paw", "berserk": "axe",
		"guard": "shield", "blade": "sword", "minion": "skull", "curse": "flask", "soul": "burst"}.get(spec_id, "burst")


func _draw_talent(id: String, center: Vector2, spec: Dictionary, color: Color) -> void:
	var info: Dictionary = data.talents[id]
	var state := _state()
	var ult: bool = str(info.kind) == "ultimate"
	var look := talent_state(id)
	var side := 62.0 if ult else 52.0
	var rect := Rect2((center - Vector2(side, side) * 0.5).round(), Vector2(side, side))
	var lit: bool = look in ["learned", "max", "available"]
	var light := Color(str(spec.color2))
	var pulse: float = float(_pulses.get(id, 0.0))
	if pulse > 0.0:
		var grow := (0.45 - pulse) / 0.45
		draw_circle(center, side * (0.6 + grow * 0.6), Color(light, 0.5 * (1.0 - grow)))
	if look == "available":
		var glow := 0.35 + 0.25 * sin(_clock * 4.0)
		draw_circle(center, side * 0.85, Color(color, glow * 0.25))
	if id == selected:
		draw_circle(center, side * 0.95, Color(CryptUI.GOLD, 0.16 + 0.06 * sin(_clock * 3.0)))
	# the ornate frame: dark plate, a rim (gold at max rank or when chosen), corner studs
	var rim := CryptUI.GOLD if look == "max" or id == selected or ult else (color if lit else Color("4a4450"))
	_card(rect.grow(5), Color("0a0708"), Color(rim, 0.9), 4, 4)
	draw_rect(rect.grow(2), Color(rim, 0.35), false, 1.0)
	for corner: Vector2 in [rect.position - Vector2(3, 3), Vector2(rect.end.x + 3, rect.position.y - 3), rect.end + Vector2(3, 3), Vector2(rect.position.x - 3, rect.end.y + 3)]:
		draw_rect(Rect2(corner - Vector2(2, 2), Vector2(4, 4)), rim)
	draw_texture_rect(_icon(spec, str(info.icon), lit, ult), rect, false, Color(1, 1, 1, 0.45) if look == "locked" else Color.WHITE)
	if look == "locked": draw_rect(rect, Color(0, 0, 0, 0.35))
	# name above the row's line, rank dots and the kind below it
	var ranks := int(info.ranks)
	var rank := Rules.rank(state, id)
	if ult:
		ranks = (info.get("stages", []) as Array).size() + 1
		rank = (int(state.soul_tier) + 1) if str(state.ultimate) == id else 0
	var text_x := rect.end.x + 16
	var name_lines := _wrap_lines(str(info.name), 150.0, 17)
	var name_y := center.y - 6 - (name_lines.size() - 1) * 18
	for n in range(name_lines.size()):
		_say(name_lines[n], Vector2(text_x, name_y + n * 18), 17, CryptUI.CREAM if lit else CryptUI.MUTED)
	var dot_y := center.y + 14
	for k in range(ranks):
		var on := k < rank
		var at := Vector2(text_x + 6 + k * 16, dot_y)
		draw_circle(at, 5.5, Color(0, 0, 0, 0.7))
		draw_circle(at, 4.5, (CryptUI.GOLD if look == "max" or ult else light) if on else Color(0.2, 0.18, 0.2))
		if on: draw_circle(at + Vector2(-1, -1), 1.5, Color(1, 1, 1, 0.7))
	var kind: String = {"active": "Aktiv", "passive": "Passiv", "ultimate": "Ultimate"}[str(info.kind)]
	_say(kind, Vector2(text_x + 6 + ranks * 16 + 4, dot_y + 5), 13, (light if not ult else CryptUI.GOLD) if lit else CryptUI.MUTED)
	if look == "no_shards":
		draw_crystal(self, rect.position + Vector2(-2, -4), 0.5, _clock)
		_say("%d" % int(data.soul_shards.ultimate_cost), rect.position + Vector2(8, 6), 13, Color("e2d4ff"))
	var name_w := 0.0
	for line: String in name_lines: name_w = maxf(name_w, _sans.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
	_hits[id] = Rect2(rect.position - Vector2(6, 6), Vector2(side + 28 + maxf(name_w, 90.0), side + 12))


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


## The detail card: the big framed icon with row, kind, name and rank; the
## text and its lore; a table of the numbers; the requirement; a red note
## why a point cannot go in; the buttons sit at the bottom.
func _draw_right() -> void:
	var info: Dictionary = data.talents[selected]
	var state := _state()
	var spec: Dictionary = data.classes[class_id].specs.filter(func(s: Dictionary) -> bool: return str(s.id) == str(info.spec))[0]
	var spec_color := Color(str(spec.color))
	var light := Color(str(spec.color2))
	var x := RIGHT.position.x + 16
	var ult: bool = str(info.kind) == "ultimate"
	var icon_rect := Rect2(RIGHT.position + Vector2(16, 16), Vector2(96, 96))
	draw_circle(icon_rect.get_center(), 64.0, Color(spec_color, 0.12))
	_card(icon_rect.grow(6), Color("0a0708"), CryptUI.GOLD, 4, 6)
	draw_rect(icon_rect.grow(3), Color(CryptUI.GOLD, 0.4), false, 1.0)
	draw_texture_rect(_icon(spec, str(info.icon), true, ult), icon_rect, false)
	var kind: String = {"active": "Aktiv", "passive": "Passiv", "ultimate": "Ultimate"}[str(info.kind)]
	var tx := icon_rect.end.x + 20
	_say("Reihe %s · %s" % [TIER_NAMES[int(info.tier) - 1], kind], Vector2(tx, RIGHT.position.y + 34), 15, light)
	var name_lines := _wrap_lines(str(info.name), RIGHT.end.x - tx - 12, 26)
	for n in range(name_lines.size()):
		_say(name_lines[n], Vector2(tx, RIGHT.position.y + 64 + n * 26), 26, CryptUI.CREAM)
	var rank := Rules.rank(state, selected)
	var stage_count: int = (info.get("stages", []) as Array).size() + 1
	var stage_now: int = (int(state.soul_tier) + 1) if str(state.ultimate) == selected else 0
	var name_bottom := RIGHT.position.y + 64 + (name_lines.size() - 1) * 26
	_say(("Stufe %d / %d" % [stage_now, stage_count]) if ult else ("Rang %d / %d" % [rank, int(info.ranks)]), Vector2(tx, name_bottom + 26), 16, CryptUI.GOLD)
	var dots := stage_count if ult else int(info.ranks)
	for k in range(dots):
		var at := Vector2(tx + 8 + k * 22, name_bottom + 44)
		draw_circle(at, 7.0, Color(0, 0, 0, 0.7))
		draw_circle(at, 6.0, CryptUI.GOLD if k < (stage_now if ult else rank) else Color(0.2, 0.18, 0.2))
	var line := RIGHT.position.y + 136.0
	_ornament(line, spec_color)
	line += 26.0
	line = _paragraph(_rank_text(str(info.text), rank if rank > 0 else 0), x, line, CryptUI.CREAM, 15)
	# the next rank's numbers, else the lore line: both do not fit above the buttons
	if rank > 0 and rank < int(info.ranks): line = _paragraph("Nächster Rang: " + _rank_text(str(info.text), rank + 1).get_slice(".", 0) + ".", x, line + 2, Color(light, 0.85), 13)
	elif info.has("lore"): line = _paragraph(str(info.lore), x, line + 2, CryptUI.MUTED, 13)
	line += 6.0
	var rows: Array = []
	if info.has("cost"): rows.append(["Kosten", "%d %s" % [int(info.cost), str(data.resources[class_id].name)]])
	if info.has("cd"): rows.append(["Abklingzeit", "%d s" % int(info.cd)])
	if info.has("time") and str(info.type) != "summon": rows.append(["Dauer", "%s s" % str(_at_rank(info.time, rank))])
	if info.has("slow"): rows.append(["Verlangsamung", "%d %%" % int(_at_rank(info.slow, rank) * 100.0)])
	if info.has("radius_m"): rows.append(["Radius", "%s m" % str(_at_rank(info.radius_m, rank))])
	if info.has("jumps"): rows.append(["Sprünge", str(int(info.jumps))])
	for k in range(rows.size()):
		var band := Rect2(x - 4, line + k * 26, RIGHT.size.x - 24, 24)
		draw_rect(band, Color(1, 1, 1, 0.04 if k % 2 == 0 else 0.015))
		_say(str(rows[k][0]), Vector2(x + 4, band.position.y + 17), 15, CryptUI.MUTED)
		var value := str(rows[k][1])
		_say(value, Vector2(band.end.x - 8 - _sans.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, band.position.y + 17), 15, CryptUI.CREAM)
	line += rows.size() * 26 + 18
	var tier: Dictionary = data.tiers[str(int(info.tier))]
	var requirement := "Level %d" % int(tier.level)
	if int(tier.points) > 0: requirement += ", %d Punkte im Zweig" % int(tier.points)
	if ult: requirement += ", %d Seelensplitter" % int(data.soul_shards.ultimate_cost)
	line = _paragraph("Voraussetzung: " + requirement, x, line, CryptUI.MUTED, 13)
	if ult: line = _draw_stages(info, state, x, line + 4)
	var why := Rules.check_rank_up(data, profile, class_id, selected)
	if ult and str(state.ultimate) == selected: why = ""
	var note := message if not message.is_empty() else why
	if not note.is_empty():
		var limit := 540.0 if str(info.spec) == "beast" else 576.0
		var y := minf(line + 8, limit - 40)
		_ornament(y - 10, spec_color)
		var warn := note == why and not why.is_empty()
		var tint := Color("e2584a") if warn else CryptUI.GOLD
		draw_arc(Vector2(x + 9, y + 9), 9.0, 0.0, TAU, 20, tint, 2.0)
		_say_centered("i", Vector2(x + 9, y + 14), 13, tint)
		var keep := RIGHT.size.x
		_paragraph_at(note, x + 28, y + 13, tint, 14, keep - 60)


## A value that may differ per rank ([r1, r2, r3]) at `rank` (the first for rank 0).
func _at_rank(value: Variant, rank: int) -> float:
	if value is Array: return float(value[clampi(rank, 1, (value as Array).size()) - 1])
	return float(value)


## A thin ornament line across the detail card with a diamond in the middle.
func _ornament(y: float, color: Color) -> void:
	var a := Vector2(RIGHT.position.x + 18, y)
	var b := Vector2(RIGHT.end.x - 18, y)
	draw_line(a, b, Color(color, 0.45), 1.0)
	_diamond((a + b) * 0.5, 5.0, CryptUI.GOLD)
	_diamond(a, 3.0, Color(color, 0.8))
	_diamond(b, 3.0, Color(color, 0.8))


func _paragraph_at(text: String, x: float, y: float, color: Color, font_size: int, width: float) -> float:
	var current := ""
	for word: String in text.split(" "):
		var trial := word if current.is_empty() else current + " " + word
		if _sans.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not current.is_empty():
			_say(current, Vector2(x, y), font_size, color)
			y += font_size + 4
			current = word
		else: current = trial
	if not current.is_empty():
		_say(current, Vector2(x, y), font_size, color)
		y += font_size + 4
	return y


## The ultimate's stages 2 and 3: reached ones lit ("aktiv"), the next with
## its shard cost, later ones dim. Stufe 1 is the unlock itself. Returns the
## y below the list.
func _draw_stages(info: Dictionary, state: Dictionary, x: float, y: float) -> float:
	var stages: Array = info.get("stages", [])
	if stages.is_empty(): return y
	var owned: bool = str(state.ultimate) == selected
	var reached := (int(state.soul_tier) + 1) if owned else 0
	var costs: Array = data.soul_shards.tier_costs
	var violet := Color("c9b6ff")
	for k in range(stages.size()):
		var stage: Dictionary = stages[k]
		var number := k + 2
		var lit := number <= reached
		var next := number == reached + 1 and owned
		var mark := "aktiv" if lit else ("%d Splitter" % int(costs[k]) if k < costs.size() else "")
		var tint := violet if lit else (CryptUI.CREAM if next else CryptUI.MUTED)
		_say("Stufe %d · %s" % [number, str(stage.name)], Vector2(x, y), 13, tint)
		_say(mark, Vector2(RIGHT.end.x - 16 - _sans.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, y), 13, violet if lit else CryptUI.GOLD if next else CryptUI.MUTED)
		y = _paragraph(str(stage.text), x + 8, y + 16, Color(tint, 0.85 if lit or next else 0.6), 12) + 4
	return y


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
