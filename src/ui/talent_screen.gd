extends Control
## The talent screen (main menu): on the left the character (class, level,
## EXP, free points, soul shards, gold; the reset in the footer), in the middle the
## three branches of the class side by side (tiers I-IV top to bottom, lines
## between them, the ultimate larger at the end), on the right the chosen
## talent with its ranks, cost, cooldown, requirements and the buttons to
## learn it, take a point back, put it on the talent bar or raise its soul
## tier. States: locked (grey), available (glowing frame), learned (full
## colour), max rank (gold), ultimate (double frame), missing shards (cost).
## Rules: src/progress/talent_rules.gd; the profile is shared with the run.
## Look: soft-edged cards with a branch-coloured header, icons at 3x (4x in the
## detail card), rank pips. All text is Pixel Operator 8 at 16 px or more (whole
## multiples of its 8 px grid, so 5 and S, I and 1 stay apart); the detail card
## scrolls (mouse wheel, Bild auf / Bild ab) when a long text does not fit.
##
## open(data, profile, path, class, from_run, run_page): `from_run` (K mid-run) hides
## the other classes' tabs; the difficulty belongs to the story start (main_menu.gd
## hero choice). The run page is optional:
##   run_page = {"title": String, "draw": Callable(canvas: CanvasItem, rect: Rect2),
##               "click": Callable(pos: Vector2) -> bool}
## With it the header gets a LAUF tab next to the class talents. On that tab the
## screen calls `draw` every frame with itself as canvas and the content area under
## the header as `rect` (local coordinates); a left click calls `click` with the
## local position (return true when it used the click, the screen then redraws).
## show_run_page() after open() starts on that tab. ZURÜCK, Esc and Pad-B close the
## screen (signal closed).

const Profile = preload("res://src/progress/profile.gd")
const Rules = preload("res://src/progress/talent_rules.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const TalentIcons = preload("res://src/ui/talent_icons.gd")
## The rune stone of the story worlds' loot (assets/sprites/loot, src/hell/gold_loot.gd): the same
## stone beside the reset's price and in the purse.
const RUNE := preload("res://assets/sprites/loot/rune_hd.png")
const RUNE_BLUE := Color("9edcff")

## Emitted after every change that was saved (the game resends builds in multiplayer).
signal profile_changed
signal closed

## The story theme whose hero classes (its own `classes` or those of the theme its
## `hero_from` names) give the class tabs their names and order.
const CLASS_SOURCE := "res://assets/data/krypta_theme.json"
## Classes added after the story ones when the class data lacks them.
const CLASS_ORDER := ["swordsman", "archer", "mage", "necromancer"]
## The open header tab: gold text on a lit plate and a gold bar under it.
const TAB_GOLD := Color("f2c66d")
const TIER_NAMES := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
## Text sizes: body and labels, the selected talent's name (when it fits).
const TEXT := 16
const TITLE := 24
## Line step of 16 px text.
const LINE := 20.0
const BG := Color("0d0b10")
const CARD := Color("17141c")
const CARD_EDGE := Color(1, 1, 1, 0.10)
const WELL := Color("100e14")
## Layout after the user's concept sheet (30.10.2026): branch banners on top,
## the row tablets on the left, the tree in the middle (actives left, passives
## right, joined by a glowing spine), the detail card on the right.
# The badges and the tree end at y 668: the footer below holds the reset.
const BADGES := Rect2(16, 118, 72, 550)
const TREE := Rect2(100, 118, 764, 550)
const RIGHT := Rect2(876, 118, 388, 590)
const BANNERS := Rect2(100, 52, 764, 58)
const INFO := Rect2(876, 52, 388, 58)
## The run page's area (badges, tree and detail card together).
const CONTENT := Rect2(16, 118, 1248, 590)

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
var _clock := 0.0
## The detail card's scroll (px from its top), how far it can scroll, its text
## area, and the talent the scroll belongs to (a new pick starts at the top).
var _detail_scroll := 0.0
var _detail_room := 0.0
var _detail_rect := Rect2()
var _scroll_for := ""
## Talent id -> time left of the "point invested" pulse.
var _pulses: Dictionary = {}
## Talent id -> clickable rect.
var _hits: Dictionary = {}
var _buttons: Dictionary = {}
## Opened mid-run (K): only the run's class, no other class tabs.
var _in_run := false
## The optional LAUF page given to open() (see the note at the top); empty without one.
var _run_page: Dictionary = {}
## "class" (the class talents) or "run" (the LAUF page).
var _page := "class"
## Class id -> tab name, and the tab order, from the story class data (story_classes).
var _class_names: Dictionary = {}
var _class_order: Array = []
## The highlighted header tab (a gold bar is drawn under it).
var _active_tab: Button


## Shows the screen for `profile_ref` (shared with the run; changes save to `path`) on
## `start_class`. `from_run`: opened mid-run, so no other class tabs. `run_page`: the
## optional LAUF tab (see the note at the top of this file).
func open(talent_data: Dictionary, profile_ref: Dictionary, path: String = Profile.SAVE_PATH, start_class: String = "", from_run := false, run_page: Dictionary = {}) -> void:
	data = talent_data
	profile = profile_ref
	save_path = path
	_in_run = from_run
	_run_page = run_page
	_page = "class"
	if not start_class.is_empty() and data.classes.has(start_class): class_id = start_class
	if selected.is_empty() or str(data.talents.get(selected, {}).get("class", "")) != class_id:
		var chosen := Rules.chosen_spec(data, _state())
		selected = str(_spec(chosen).talents[0]) if not chosen.is_empty() else str(data.classes[class_id].specs[0].talents[0])
	visible = true
	_refresh()
	_focus_default()


## Opens the LAUF tab given to open() (call open() first); nothing without a run page.
func show_run_page() -> void:
	if _run_page.is_empty():
		return
	_page = "run"
	visible = true
	_refresh()
	_focus_default()


## Hides the screen and reports it (ZURÜCK, Esc, Pad-B).
func close() -> void:
	visible = false
	closed.emit()


## The story hero classes by id ({name, sprite, hp, speed, weapon}) from `source` or the
## theme its `hero_from` names; {} when the files are missing. Static: the title's hero
## cards read it too (game.gd _hero_cards).
static func story_classes(source: String = CLASS_SOURCE) -> Dictionary:
	var theme: Variant = JSON.parse_string(FileAccess.get_file_as_string(source)) if FileAccess.file_exists(source) else null
	if theme is Dictionary and not (theme as Dictionary).has("classes") and (theme as Dictionary).has("hero_from"):
		var shared := str(theme.hero_from)
		theme = JSON.parse_string(FileAccess.get_file_as_string(shared)) if FileAccess.file_exists(shared) else null
	if not theme is Dictionary:
		return {}
	var classes: Variant = (theme as Dictionary).get("classes", {})
	return classes if classes is Dictionary else {}


## Focus for keys and pad: the main detail button when it can act, else ZURÜCK.
func _focus_default() -> void:
	if not is_inside_tree():
		return
	var learn: Button = _buttons.learn
	var target: Button = learn if _page == "class" and learn.visible and not learn.disabled else _buttons.close
	target.grab_focus()


func _ready() -> void:
	size = Vector2(1280, 720)
	theme = CryptUI.create_theme()
	_font = PixelStyle.create_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	# header tabs: one per class (names from the class data), LAUF for the run page
	var classes := story_classes()
	_class_order = classes.keys()
	for id: String in CLASS_ORDER:
		if not _class_order.has(id): _class_order.append(id)
	for id: String in _class_order:
		_class_names[id] = str((classes.get(id, {}) as Dictionary).get("name", id.to_upper()))
		_add_button("tab_" + id, str(_class_names[id]), Rect2(150, 10, 180, 32), _pick_class.bind(id))
	_add_button("tab_run", "LAUF", Rect2(150, 10, 120, 32), show_run_page)
	# the reset sits in the footer under the tree, out of the header
	_add_button("reset", "", Rect2(16, 676, 320, 32), _reset)
	_add_button("close", "ZURÜCK", Rect2(1112, 10, 152, 32), close)
	var inner := RIGHT.size.x - 32
	_add_button("companion", "", Rect2(RIGHT.position.x + 16, 548, inner, 30), _cycle_companion)
	_add_button("learn", "", Rect2(RIGHT.position.x + 16, 584, inner, 36), _learn)
	_add_button("unlearn", "Punkt zurücknehmen", Rect2(RIGHT.position.x + 16, 626, inner, 34), _unlearn)
	_add_button("bar", "", Rect2(RIGHT.position.x + 16, 666, inner, 34), _cycle_bar)
	_add_button("soul", "", Rect2(RIGHT.position.x + 16, 666, inner, 34), _soul_up)
	for key: String in _buttons:
		# one face and size everywhere; the panel buttons sit on bronze plates
		_buttons[key].add_theme_font_size_override("font_size", TEXT)
		if key in ["learn", "unlearn", "bar", "soul", "companion", "reset"]: _bronze(_buttons[key], key == "learn")


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
	if _page == "run":
		# the run page owns the clicks (see the note at the top)
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var click: Variant = _run_page.get("click")
			if click is Callable and (click as Callable).is_valid() and bool((click as Callable).call(event.position)):
				accept_event()
				queue_redraw()
		return
	# the wheel over the detail card scrolls a text that does not fit
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if RIGHT.has_point(event.position) and _scroll_detail(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1):
			accept_event()
		return
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
		close()
		get_viewport().set_input_as_handled()
	elif visible and _page == "class" and event.is_pressed() and event is InputEventKey and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		if _scroll_detail(-4 if event.keycode == KEY_PAGEUP else 4):
			get_viewport().set_input_as_handled()


## Scrolls the detail card by `lines` text lines; false when it has nothing to scroll.
func _scroll_detail(lines: int) -> bool:
	if _detail_room <= 0.0:
		return false
	_detail_scroll = clampf(_detail_scroll + lines * LINE, 0.0, _detail_room)
	queue_redraw()
	return true


func _unhandled_input(event: InputEvent) -> void:
	# Pad-B (ui_cancel from a joypad); Esc comes through _unhandled_key_input
	if visible and not (event is InputEventKey) and event.is_action_pressed("ui_cancel"):
		close()
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
	_refresh_tabs()
	var state := _state()
	var info: Dictionary = data.talents[selected]
	var rank := Rules.rank(state, selected)
	var why := Rules.check_rank_up(data, profile, class_id, selected)
	var learn: Button = _buttons.learn
	learn.text = "Freischalten · %d Splitter" % int(data.soul_shards.ultimate_cost) if str(info.kind) == "ultimate" else ("Rang verbessern" if rank > 0 else "Punkt investieren")
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
	soul.text = ("Stufe %d erreicht" % (costs.size() + 1) if top else "Stufe %d · %d Splitter" % [tier + 2, next_cost]) if owned else "Erst freischalten"
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
	if _font != null and _font.get_string_size(companion.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT).x > companion.size.x - 12.0:
		companion.text = "Begleiter: %s" % str(kinds.get(str(state.get("companion", "wolf")), {}).get("name", "Wolf"))
	companion.tooltip_text = "Auswahl ändern. Tiergefährte erneut wirken, um den lebenden Begleiter auszutauschen."
	var cost := Rules.reset_cost(data, profile, class_id)
	_buttons.reset.text = "Zurücksetzen · %d %s" % [cost, "Rune" if cost == 1 else "Runen"]
	_buttons.reset.disabled = state.ranks.is_empty() or int(profile.get("runes", 0)) < Rules.reset_cost(data, profile, class_id)
	_buttons.reset.visible = true
	if _page == "run":
		# the run page shows its own tree: no class talent buttons
		for key: String in ["learn", "unlearn", "bar", "soul", "companion", "reset"]: _buttons[key].visible = false
	# hidden or disabled buttons never keep the focus
	for key: String in _buttons:
		var button: Button = _buttons[key]
		button.focus_mode = Control.FOCUS_ALL if button.visible and not button.disabled else Control.FOCUS_NONE
	queue_redraw()


## Header tabs: one per class (in a run only the run's class, and only next to a LAUF
## tab), LAUF when a run page is given. The open tab is gold on a lit plate.
func _refresh_tabs() -> void:
	# right of the 24 px TALENTE heading
	var x := 176.0
	_active_tab = null
	for id: String in _class_order:
		var tab: Button = _buttons["tab_" + id]
		tab.visible = data.classes.has(id) and (not _in_run or (not _run_page.is_empty() and id == class_id))
		if not tab.visible:
			continue
		tab.position.x = x
		x += tab.size.x + 6.0
		_tab_look(tab, _page == "class" and id == class_id)
	var run_tab: Button = _buttons.tab_run
	run_tab.visible = not _run_page.is_empty()
	run_tab.position.x = x
	_tab_look(run_tab, _page == "run")


## The open tab: gold text on the lit plate (never greyed out); the others plain.
func _tab_look(tab: Button, active: bool) -> void:
	tab.disabled = false
	if not active:
		for look: String in ["normal", "hover"]: tab.remove_theme_stylebox_override(look)
		for color: String in ["font_color", "font_hover_color", "font_focus_color"]: tab.remove_theme_color_override(color)
		return
	_active_tab = tab
	for look: String in ["normal", "hover"]: tab.add_theme_stylebox_override(look, CryptUI.box("button_hover"))
	for color: String in ["font_color", "font_hover_color", "font_focus_color"]: tab.add_theme_color_override(color, TAB_GOLD)


func _pick_class(id: String) -> void:
	_page = "class"
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
	_commit("", "%s gewählt. Tiergefährte erneut wirken zum Wechseln." % str(data.pet.kinds[state.companion].name))


# ---------- drawing ----------

func _draw() -> void:
	if data.is_empty(): return
	var spec := _spec(shown_spec) if not shown_spec.is_empty() else _spec(str(data.classes[class_id].specs[0].id))
	var color := Color(str(spec.color))
	var light := Color(str(spec.color2))
	_draw_backdrop(color, light)
	_text("TALENTE", Vector2(16, 34), TITLE, CryptUI.GOLD)
	if _active_tab != null and _active_tab.visible:
		# a gold bar under the open tab
		draw_rect(Rect2(_active_tab.position + Vector2(6, _active_tab.size.y + 2), Vector2(_active_tab.size.x - 12, 3)), TAB_GOLD)
	_draw_info()
	if _page == "run":
		_draw_run_page()
		return
	_draw_badges(color)
	_frame(TREE, Color(0.03, 0.02, 0.03, 0.72), color)
	_frame(RIGHT, Color(0.04, 0.03, 0.04, 0.9), color)
	_draw_tree()
	_draw_right()
	_draw_purse()
	_draw_badge_hint()


## The LAUF page: the tab names it, so the banner row explains the two levels
## instead of repeating a title; run_page.draw paints the run tree in CONTENT.
func _draw_run_page() -> void:
	_card(BANNERS, Color(0.05, 0.04, 0.05, 0.9), Color(1, 1, 1, 0.1), 4, 4)
	var room := BANNERS.size.x - 32
	_text(_fit("Laufstufe: nur in diesem Lauf, verfällt beim Tod.", room), BANNERS.position + Vector2(16, 24), TEXT, CryptUI.CREAM)
	_text(_fit("Heldenstufe: bleibt und gibt die Klassen-Talente.", room), BANNERS.position + Vector2(16, 46), TEXT, CryptUI.MUTED)
	_frame(CONTENT, Color(0.03, 0.02, 0.03, 0.72), CryptUI.GOLD)
	var painter: Variant = _run_page.get("draw")
	if painter is Callable and (painter as Callable).is_valid():
		(painter as Callable).call(self, CONTENT.grow(-8))


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


## Top right: the class with its Heldenstufe and the free talent points
## (singular for one). Rune stones and soul shards sit in the footer (_draw_purse).
func _draw_info() -> void:
	var state := _state()
	_card(INFO, Color(0.05, 0.04, 0.05, 0.9), Color(1, 1, 1, 0.1), 4, 4)
	var level := int(state.level)
	var free := Rules.free_points(data, state)
	var room := INFO.size.x - 28
	# the profile level is the Heldenstufe (it stays); the run's level is the Laufstufe.
	# A long class name gives way (the open tab names the class anyway), never the level.
	var head := "%s · Heldenstufe %d" % [str(_class_names.get(class_id, class_id.to_upper())), level]
	if _width(head) > room: head = "Heldenstufe %d" % level
	_say(head, INFO.position + Vector2(14, 24), TEXT, CryptUI.CREAM)
	_say("1 Talentpunkt frei" if free == 1 else "%d Talentpunkte frei" % free, INFO.position + Vector2(14, 47), TEXT, CryptUI.GOLD if free > 0 else CryptUI.MUTED)


## The footer beside the reset (which costs rune stones): soul shards and rune stones (the stone and its count).
func _draw_purse() -> void:
	var y := 698.0
	# the rune stones: the stone and its count, right-aligned
	var runes := str(int(profile.get("runes", 0)))
	var runes_x := TREE.end.x - 4.0 - _width(runes)
	_say(runes, Vector2(runes_x, y), TEXT, RUNE_BLUE)
	var icon := RUNE.get_size() * (20.0 / RUNE.get_size().y)
	draw_texture_rect(RUNE, Rect2(Vector2(runes_x - icon.x - 6.0, y - 16.0), icon), false)
	var have := int(profile.shards.have)
	var shards := "1 Seelensplitter" if have == 1 else "%d Seelensplitter" % have
	var shard_x := runes_x - icon.x - 34.0 - _width(shards)
	_say(shards, Vector2(shard_x, y), TEXT, Color("e2d4ff"))
	draw_crystal(self, Vector2(shard_x - 16.0, y - 7.0), 0.55, _clock)


## The row tablet of tier `t` (1-8) in the left column.
func _badge_rect(t: int) -> Rect2:
	var row_h := BADGES.size.y / 8.0
	return Rect2(BADGES.position.x, BADGES.position.y + row_h * (t - 1) + 4, BADGES.size.x, row_h - 8)


## The row tablets on the left: numeral, the Heldenstufe the row opens at
## ("ab 8") and the points the branch needs; lit as far as the branch reaches.
## Hovering a tablet explains it (_draw_badge_hint).
func _draw_badges(color: Color) -> void:
	var state := _state()
	var points := Rules.spec_points(data, state, shown_spec)
	for t in range(1, 9):
		var tier: Dictionary = data.tiers[str(t)]
		var open := points >= int(tier.points) and int(state.level) >= int(tier.level)
		var badge := _badge_rect(t)
		_card(badge, Color(0.07, 0.05, 0.05, 0.92), Color(color, 0.7) if open else Color(1, 1, 1, 0.12), 6, 4)
		draw_rect(badge.grow(-3), Color(color, 0.15 if open else 0.04), false, 1.0)
		var c := badge.get_center()
		_text_centered(TIER_NAMES[t - 1], Vector2(c.x, c.y - 10), TEXT, CryptUI.GOLD if open else CryptUI.MUTED)
		_text_centered("ab %d" % int(tier.level), Vector2(c.x, c.y + 8), TEXT, CryptUI.CREAM if open else CryptUI.MUTED)
		if int(tier.points) > 0: _text_centered("%d P" % int(tier.points), Vector2(c.x, c.y + 26), TEXT, CryptUI.MUTED)


## The hovered row tablet in words: from which Heldenstufe and with how many
## points in the branch the row opens. Drawn last, over the tree.
func _draw_badge_hint() -> void:
	var mouse := get_local_mouse_position()
	if not BADGES.has_point(mouse):
		return
	for t in range(1, 9):
		var badge := _badge_rect(t)
		if not badge.has_point(mouse):
			continue
		var tier: Dictionary = data.tiers[str(t)]
		var lines: Array[String] = ["Reihe %s" % TIER_NAMES[t - 1], "ab Heldenstufe %d" % int(tier.level)]
		lines.append("%d Punkte im Zweig" % int(tier.points) if int(tier.points) > 0 else "ohne Punkte im Zweig")
		var wide := 0.0
		for line: String in lines: wide = maxf(wide, _width(line))
		var card := Rect2(badge.end.x + 10, badge.position.y, wide + 28, lines.size() * LINE + 16)
		_card(card, Color(0.06, 0.05, 0.06, 0.97), Color(CryptUI.GOLD, 0.7), 4, 6)
		for n in range(lines.size()):
			_say(lines[n], card.position + Vector2(14, 23 + n * LINE), TEXT, CryptUI.GOLD if n == 0 else CryptUI.CREAM)
		return


## One branch at a time under its banner (the chosen one "gewählt", the
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
		var icon_rect := Rect2(tab.position + Vector2(6, 11), Vector2(36, 36))
		draw_texture_rect(_icon(spec, _banner_motif(str(spec.id)), not locked or shown), icon_rect, false)
		var name_x := icon_rect.end.x + 8
		var room := tab.end.x - name_x - 6
		_text(_fit(str(spec.name), room), Vector2(name_x, tab.position.y + 26), TEXT, CryptUI.CREAM if not locked else CryptUI.MUTED)
		var note := "gesperrt" if locked else "frei wählbar"
		if str(spec.id) == chosen_spec and not chosen_spec.is_empty(): note = "gewählt · %d P" % Rules.spec_points(data, state, str(spec.id))
		_say(_fit(note, room), Vector2(name_x, tab.position.y + 47), TEXT, Color(str(spec.color2)) if not locked else CryptUI.MUTED)
		_hits["spec:" + str(spec.id)] = tab
	var spec: Dictionary = _spec(shown_spec)
	var color := Color(str(spec.color))
	var light := Color(str(spec.color2))
	var area := TREE.grow(-8)
	var row_h := area.size.y / 8.0
	var spine_x := area.position.x + area.size.x * 0.5
	var left_x := area.position.x + 44.0
	var right_x := spine_x + 64.0
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
			# the name runs to the spine (left talent) or to the tree's edge
			var edge: float = spine_x - 16.0 if ids.size() > 1 and k == 0 else area.end.x - 4.0
			_draw_talent(str(ids[k]), Vector2(x, y), spec, color, edge)


## The motif shown on a branch banner.
func _banner_motif(spec_id: String) -> String:
	return {"fire": "flame", "frost": "snowflake", "arcane": "echo", "sniper": "arrow", "trapper": "trap", "beast": "paw", "berserk": "axe",
		"guard": "shield", "blade": "sword", "minion": "skull", "curse": "flask", "soul": "burst"}.get(spec_id, "burst")


## One talent at `center`: framed icon (3x), name, rank dots and kind; the
## text may run up to `edge` (x), longer names wrap or end in "…".
func _draw_talent(id: String, center: Vector2, spec: Dictionary, color: Color, edge: float) -> void:
	var info: Dictionary = data.talents[id]
	var state := _state()
	var ult: bool = str(info.kind) == "ultimate"
	var look := talent_state(id)
	# the icon is 18 px art at 3x; an ultimate gets a wider frame around it
	var side := 58.0 if ult else 54.0
	var rect := Rect2((center - Vector2(side, side) * 0.5).round(), Vector2(side, side))
	var icon_rect := Rect2((center - Vector2(27, 27)).round(), Vector2(54, 54))
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
	draw_texture_rect(_icon(spec, str(info.icon), lit, ult), icon_rect, false, Color(1, 1, 1, 0.45) if look == "locked" else Color.WHITE)
	if look == "locked": draw_rect(icon_rect, Color(0, 0, 0, 0.35))
	# name above the row's line, rank dots and the kind below it
	var ranks := int(info.ranks)
	var rank := Rules.rank(state, id)
	if ult:
		ranks = (info.get("stages", []) as Array).size() + 1
		rank = (int(state.soul_tier) + 1) if str(state.ultimate) == id else 0
	var text_x := rect.end.x + 12
	var name_lines := _wrap_lines(str(info.name), edge - text_x, TEXT)
	var name_y := center.y - 6 - (name_lines.size() - 1) * 18
	for n in range(name_lines.size()):
		_say(name_lines[n], Vector2(text_x, name_y + n * 18), TEXT, CryptUI.CREAM if lit else CryptUI.MUTED)
	var dot_y := center.y + 10
	for k in range(ranks):
		var on := k < rank
		var at := Vector2(text_x + 6 + k * 16, dot_y)
		draw_circle(at, 5.5, Color(0, 0, 0, 0.7))
		draw_circle(at, 4.5, (CryptUI.GOLD if look == "max" or ult else light) if on else Color(0.2, 0.18, 0.2))
		if on: draw_circle(at + Vector2(-1, -1), 1.5, Color(1, 1, 1, 0.7))
	var kind: String = {"active": "Aktiv", "passive": "Passiv", "ultimate": "Ultimate"}[str(info.kind)]
	_say(kind, Vector2(text_x + 4 + ranks * 16 + 6, dot_y + 6), TEXT, (light if not ult else CryptUI.GOLD) if lit else CryptUI.MUTED)
	if look == "no_shards":
		draw_crystal(self, rect.position + Vector2(-2, -4), 0.5, _clock)
		_say("%d" % int(data.soul_shards.ultimate_cost), rect.position + Vector2(8, 10), TEXT, Color("e2d4ff"))
	var name_w := 0.0
	for line: String in name_lines: name_w = maxf(name_w, _width(line))
	_hits[id] = Rect2(rect.position - Vector2(6, 6), Vector2(side + 28 + maxf(name_w, 90.0), side + 12))


## `text` split into lines no wider than `width` at `font_size`; a single word
## that is wider ends in "…".
func _wrap_lines(text: String, width: float, font_size: int = TEXT) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word: String in text.split(" "):
		var trial := word if current.is_empty() else current + " " + word
		if _width(trial, font_size) > width and not current.is_empty():
			lines.append(_fit(current, width, font_size))
			current = word
		else: current = trial
	if not current.is_empty(): lines.append(_fit(current, width, font_size))
	return lines


## The detail card: the framed icon with row, kind, name and rank on top; below
## it the text, the numbers, the requirement and (ultimates) the stages. They
## scroll when they do not fit (wheel, Bild auf / Bild ab, a bar on the right
## edge shows it); the note why a point cannot go in stays fixed above the buttons.
func _draw_right() -> void:
	var info: Dictionary = data.talents[selected]
	var state := _state()
	var spec: Dictionary = data.classes[class_id].specs.filter(func(s: Dictionary) -> bool: return str(s.id) == str(info.spec))[0]
	var spec_color := Color(str(spec.color))
	var light := Color(str(spec.color2))
	var x := RIGHT.position.x + 16
	var width := RIGHT.size.x - 32
	var ult: bool = str(info.kind) == "ultimate"
	var icon_rect := Rect2(RIGHT.position + Vector2(16, 16), Vector2(72, 72))
	draw_circle(icon_rect.get_center(), 50.0, Color(spec_color, 0.12))
	_card(icon_rect.grow(6), Color("0a0708"), CryptUI.GOLD, 4, 6)
	draw_rect(icon_rect.grow(3), Color(CryptUI.GOLD, 0.4), false, 1.0)
	draw_texture_rect(_icon(spec, str(info.icon), true, ult), icon_rect, false)
	var kind: String = {"active": "Aktiv", "passive": "Passiv", "ultimate": "Ultimate"}[str(info.kind)]
	var tx := icon_rect.end.x + 18
	var room := RIGHT.end.x - 16 - tx
	_say(_fit("Reihe %s · %s" % [TIER_NAMES[int(info.tier) - 1], kind], room), Vector2(tx, RIGHT.position.y + 30), TEXT, light)
	# the name at 24 px when it fits beside the icon, else at 16 px
	var name_size := TITLE if _width(str(info.name), TITLE) <= room else TEXT
	_say(_fit(str(info.name), room, name_size), Vector2(tx, RIGHT.position.y + (58 if name_size == TITLE else 56)), name_size, CryptUI.CREAM)
	var rank := Rules.rank(state, selected)
	var stage_count: int = (info.get("stages", []) as Array).size() + 1
	var stage_now: int = (int(state.soul_tier) + 1) if str(state.ultimate) == selected else 0
	var rank_line := ("Stufe %d / %d" % [stage_now, stage_count]) if ult else ("Rang %d / %d" % [rank, int(info.ranks)])
	_say(rank_line, Vector2(tx, RIGHT.position.y + 84), TEXT, CryptUI.GOLD)
	var dots := stage_count if ult else int(info.ranks)
	var dots_x := tx + _width(rank_line) + 16
	for k in range(dots):
		var at := Vector2(dots_x + k * 18, RIGHT.position.y + 78)
		draw_circle(at, 7.0, Color(0, 0, 0, 0.7))
		draw_circle(at, 6.0, CryptUI.GOLD if k < (stage_now if ult else rank) else Color(0.2, 0.18, 0.2))
	_ornament(RIGHT.position.y + 106, spec_color)
	var top := RIGHT.position.y + 118.0
	# the body ends above the first visible button
	var bottom := RIGHT.end.y - 8.0
	for key: String in ["companion", "learn", "unlearn", "bar", "soul"]:
		var button: Button = _buttons[key]
		if button.visible: bottom = minf(bottom, button.position.y - 10.0)
	# the note (why not, or what just happened) is fixed at the body's foot
	var why := Rules.check_rank_up(data, profile, class_id, selected)
	if ult and str(state.ultimate) == selected: why = ""
	var note := message if not message.is_empty() else why
	if not note.is_empty():
		var note_lines := _wrap_lines(note, width - 28)
		var note_y := bottom - note_lines.size() * LINE - 14.0
		_ornament(note_y, spec_color)
		var warn := note == why and not why.is_empty()
		var tint := Color("e2584a") if warn else CryptUI.GOLD
		draw_arc(Vector2(x + 9, note_y + 17), 9.0, 0.0, TAU, 20, tint, 2.0)
		_text_centered("i", Vector2(x + 10, note_y + 24), TEXT, tint)
		for n in range(note_lines.size()):
			_say(note_lines[n], Vector2(x + 28, note_y + 24 + n * LINE), TEXT, tint)
		bottom = note_y - 6.0
	# the body: lines {y, h, kind, ...} from its top, drawn with the scroll
	var body: Array[Dictionary] = []
	var y := _push_paragraph(body, _rank_text(str(info.text), rank if rank > 0 else 0), 0.0, x, width, CryptUI.CREAM)
	# the next rank's numbers, else the lore line
	if rank > 0 and rank < int(info.ranks): y = _push_paragraph(body, "Nächster Rang: " + _rank_text(str(info.text), rank + 1).get_slice(".", 0) + ".", y + 4, x, width, Color(light, 0.85))
	elif info.has("lore"): y = _push_paragraph(body, str(info.lore), y + 4, x, width, CryptUI.MUTED)
	y += 8.0
	var rows: Array = []
	if info.has("cost"): rows.append(["Kosten", "%d %s" % [int(info.cost), str(data.resources[class_id].name)]])
	if info.has("cd"): rows.append(["Abklingzeit", "%d s" % int(info.cd)])
	if info.has("time") and str(info.type) != "summon": rows.append(["Dauer", "%s s" % str(_at_rank(info.time, rank))])
	if info.has("slow"): rows.append(["Verlangsamung", "%d %%" % int(_at_rank(info.slow, rank) * 100.0)])
	if info.has("radius_m"): rows.append(["Radius", "%s m" % str(_at_rank(info.radius_m, rank))])
	if info.has("jumps"): rows.append(["Sprünge", str(int(info.jumps))])
	for k in range(rows.size()):
		body.append({"y": y, "h": 24.0, "kind": "row", "label": str(rows[k][0]), "value": str(rows[k][1]), "band": k})
		y += 24.0
	y += 10.0
	var tier: Dictionary = data.tiers[str(int(info.tier))]
	var requirement := "Heldenstufe %d" % int(tier.level)
	if int(tier.points) > 0: requirement += ", %d Punkte im Zweig" % int(tier.points)
	if ult: requirement += ", %d Seelensplitter" % int(data.soul_shards.ultimate_cost)
	y = _push_paragraph(body, "Voraussetzung: " + requirement, y, x, width, CryptUI.MUTED)
	if ult: y = _push_stages(body, info, state, x, width, y + 8)
	_draw_body(body, y, Rect2(x, top, width, bottom - top))


## Draws the detail card's body lines in `area` with the scroll; lines cut by
## the area's edges are left out, a bar on the right shows the scroll.
func _draw_body(body: Array[Dictionary], total: float, area: Rect2) -> void:
	if _scroll_for != selected:
		_scroll_for = selected
		_detail_scroll = 0.0
	_detail_rect = area
	_detail_room = maxf(0.0, total - area.size.y)
	_detail_scroll = clampf(_detail_scroll, 0.0, _detail_room)
	for line: Dictionary in body:
		var y: float = area.position.y + float(line.y) - _detail_scroll
		if y < area.position.y - 0.5 or y + float(line.h) > area.end.y + 0.5:
			continue
		if line.kind == "text":
			_say(str(line.text), Vector2(float(line.x), y + 15), TEXT, line.color)
		elif line.kind == "row":
			var band := Rect2(area.position.x - 4, y, area.size.x + 8, 22)
			draw_rect(band, Color(1, 1, 1, 0.04 if int(line.band) % 2 == 0 else 0.015))
			_say(str(line.label), Vector2(area.position.x + 4, y + 16), TEXT, CryptUI.MUTED)
			_say(str(line.value), Vector2(band.end.x - 8 - _width(str(line.value)), y + 16), TEXT, CryptUI.CREAM)
		elif line.kind == "pair":
			_say(str(line.text), Vector2(float(line.x), y + 15), TEXT, line.color)
			_say(str(line.mark), Vector2(area.end.x - _width(str(line.mark)), y + 15), TEXT, line.mark_color)
	if _detail_room <= 0.0:
		return
	# the scroll bar: a dark track, a gold thumb as long as the visible share
	var track := Rect2(RIGHT.end.x - 9, area.position.y, 3, area.size.y)
	draw_rect(track, Color(1, 1, 1, 0.08))
	var share := area.size.y / total
	var thumb_h := maxf(16.0, track.size.y * share)
	var thumb_y := track.position.y + (track.size.y - thumb_h) * (_detail_scroll / _detail_room)
	draw_rect(Rect2(track.position.x, thumb_y, 3, thumb_h), CryptUI.GOLD)


## Wraps `text` into body lines from `y` (16 px, 20 px apart); returns the y below.
func _push_paragraph(body: Array[Dictionary], text: String, y: float, x: float, width: float, color: Color) -> float:
	for line: String in _wrap_lines(text, width):
		body.append({"y": y, "h": LINE, "kind": "text", "text": line, "x": x, "color": color})
		y += LINE
	return y


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


## The ultimate's stages 2 and 3 as body lines: reached ones lit ("aktiv"),
## the next with its shard cost, later ones dim. Stufe 1 is the unlock itself.
## Returns the y below the list.
func _push_stages(body: Array[Dictionary], info: Dictionary, state: Dictionary, x: float, width: float, y: float) -> float:
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
		var mark_tint := violet if lit else CryptUI.GOLD if next else CryptUI.MUTED
		var head := "Stufe %d · %s" % [number, str(stage.name)]
		if _width(head) + 16 + _width(mark) <= width:
			body.append({"y": y, "h": LINE, "kind": "pair", "text": head, "x": x, "color": tint, "mark": mark, "mark_color": mark_tint})
			y += LINE
		else:
			y = _push_paragraph(body, head, y, x, width, tint)
			body.append({"y": y, "h": LINE, "kind": "pair", "text": "", "x": x, "color": tint, "mark": mark, "mark_color": mark_tint})
			y += LINE
		y = _push_paragraph(body, str(stage.text), y, x + 8, width - 8, Color(tint, 0.85 if lit or next else 0.6)) + 6
	return y


## "125/145/165 %" -> the value of `rank` (1-3), or all values for rank 0.
func _rank_text(text: String, rank: int) -> String:
	if rank <= 0: return text
	var regex := RegEx.create_from_string("(\\d+(?:,\\d+)?)/(\\d+(?:,\\d+)?)/(\\d+(?:,\\d+)?)")
	var out := text
	for m: RegExMatch in regex.search_all(text): out = out.replace(m.get_string(0), m.get_string(clampi(rank, 1, 3)))
	return out


func _icon(spec: Dictionary, motif: String, on: bool, ultimate := false) -> Texture2D:
	return TalentIcons.make(spec, motif, on, ultimate)


## Width of `text` in px at `font_size`.
func _width(text: String, font_size: int = TEXT) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## `text` shortened with "…" until it is no wider than `width`.
func _fit(text: String, width: float, font_size: int = TEXT) -> String:
	if _width(text, font_size) <= width:
		return text
	var cut := text
	while cut.length() > 1 and _width(cut + "…", font_size) > width:
		cut = cut.left(cut.length() - 1)
	return cut.strip_edges() + "…"


func _text(text: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_centered(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, at - Vector2(floorf(width * 0.5), 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Body text (names, values, descriptions); the same face as the headings.
func _say(text: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


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
