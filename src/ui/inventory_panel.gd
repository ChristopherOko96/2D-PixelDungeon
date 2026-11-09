extends Control
## The hero's character & inventory window (keys C, Tab or I: one window, no
## stack; the story worlds pause while it is open), the same in every world and
## in the neutral HUD look (src/ui/hud_style.gd). With a character view
## (set_character_view) a left column shows the hero's numbers; then the four
## equipment slots (weapon, armour, ring, amulet), the bag's slots with rarity
## frames, the chosen item's text and the actions that fit it: equip or take
## off, identify with a crystal, break a curse with a stone, raise a stage
## (Aufwertungsstein), reroll a stage (Würfelstein), use (drink a potion, break
## a clone seal, look into a mirror crystal), throw, drop. Throwing arms the
## next click in the world as the target. Also shows a short note when
## something is found or happens (handed to the game's message channel through
## `noted` while closed, when connected), and a small INVENTAR chip (with
## auto_hide_chip only for a while after the bag changed or under the mouse;
## off while the game sets chip_blocked). Only the actions that fit the chosen
## item show. Sends actions
## only; the rules decide (src/items/inventory.gd, docs/ITEM-SYSTEM-V2.de.md).
## An identified item of an element wears its glow frame and sheds a few of its
## pixel motes (src/item_art.gd: embers, drops, rime, zaps, orbiting motes),
## redrawn on the pixel beat, not every frame; unknown items stay unknown.

signal acted(action: String, value: int)
signal throw_armed(slot: int)
## A note for the game's message channel (the bag closed); unconnected, the panel shows it itself.
signal noted(text: String)
## A right-click on a potion: that bag slot becomes the quick potion (keys H / G,
## src/hero/story_items.gd set_quick).
signal quick_chosen(slot: int)
## The window closed (any way: a key, Esc, a click outside, a throw).
signal closed

const PixelStyle = preload("res://src/pixel_style.gd")
const HudStyle = preload("res://src/ui/hud_style.gd")
const HudKit = preload("res://src/ui/hud_kit.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
const ItemArt = preload("res://src/item_art.gd")
const HAND := 99
## Slot values of the equipment slots (the bag uses 0..size-1), as inventory.gd.
const EQUIP := {"weapon": 99, "armor": 98, "ring": 97, "amulet": 96}
const EQUIP_LABELS := {"weapon": "WAFFE", "armor": "RÜSTUNG", "ring": "RING", "amulet": "AMULETT"}
const SLOT := 60.0
const GAP := 6.0
## The equipment column: wide enough for its 16 px labels under the slots; the bag sits right of it.
const EQUIP_COLUMN := 112.0
## The character column left of the inventory, while a character view is set.
const CHARACTER_W := 300.0
const BAG_X := 16.0 + EQUIP_COLUMN + 12.0
## Ends above the resource label over the skill bar (y 637), never covering it.
## Where the window sits unless fit_below() moves it under the HUD's left column.
const PANEL := Rect2(280, 64, 720, 552)
## The window with the character column: centred, the inventory part as wide as PANEL.
const PANEL_WIDE := Rect2(130, 64, 720 + CHARACTER_W, 552)
## Height the equipment column needs besides its three steps between slots:
## its top row (72), the last slot, its label under it, the footer line and a
## few px between the label and the footer.
const EQUIP_ROOM := 190.0
## The item actions in the order they line up: id, label.
const ACTIONS := [["inv_equip", "ANLEGEN"], ["inv_use", "BENUTZEN"], ["inv_identify", "IDENTIFIZIEREN"], ["inv_cleanse", "FLUCH BRECHEN"],
	["inv_upgrade", "AUFWERTEN"], ["inv_reroll", "NEU WÜRFELN"], ["inv_throw", "WERFEN"], ["inv_drop", "WEGWERFEN"]]

var open := false
var selected := HAND
## Where the window sits now: PANEL, or below the HUD's hero strip (fit_below).
var panel: Rect2 = PANEL
## Px from one equipment slot's top to the next (the slot and its label under it).
var equip_step := SLOT + 30.0
var _view: Dictionary = {}
## The character column (src/hell/frost_hud.gd status_sheet): name, level, rows
## [label, value], cards; empty = no column (the window is PANEL wide).
var _character: Dictionary = {}
var _textures: Dictionary = {}
var _buttons: Dictionary = {}
var _toggle: Button
var _toast := ""
var _toast_time := 0.0
var _notes_seen := -1
var _font: Font
## The clock of the element motes, and the pixel beat last drawn.
var _clock := 0.0
var _beat := -1
## True while the view holds an identified item of an element (something moves).
var _animated := false
## The chip's rules: auto_hide_chip (story worlds) shows it only after a bag
## change or under the mouse; chip_blocked (a window, the pause, a result) hides it.
var auto_hide_chip := false
var chip_blocked := false
var _chip_time := 0.0
var _bag_sig := ""
## The bag slot of the quick potion (H drinks, G throws), -1 for none; the game
## sets it from story_items.gd quick_slot(), the panel only shows it.
var quick := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	_font = PixelStyle.create_font()
	# The toggle sits in the bottom-right corner, as wide as its longest text.
	_toggle = _button("INVENTAR · I  12/12", Rect2(0, 676, 10, 28), func(): set_open(not open))
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.add_theme_font_size_override("font_size", 16)
	# the HUD's neutral look, like the menu button (src/ui/hud_style.gd)
	HudStyle.style_button(_toggle)
	_toggle.size = Vector2(_toggle.get_combined_minimum_size().x + 16.0, maxf(28.0, _toggle.get_combined_minimum_size().y))
	_toggle.position = Vector2(1264.0 - _toggle.size.x, 704.0 - _toggle.size.y)
	# the action buttons; only those that fit the chosen item show (_refresh_buttons)
	for entry: Array in ACTIONS:
		var action: String = entry[0]
		var button := _button(str(entry[1]), Rect2(panel.position, Vector2(120, 36)), func(): _act(action))
		button.add_theme_font_size_override("font_size", 16)
		HudStyle.style_button(button)
		_buttons[action] = button
	set_open(false)


## Moves the window's top to `top` (screen px: the bottom of the HUD's hero
## strip and companion bar plus a gap, ui_hud_style.json inventory_gap) so it
## never covers them; its bottom goes down to inventory_bottom, still above the
## resource label over the skill bar. The equipment column closes up to fit (a
## slot every inventory_equip_step_min px at least); the actions line up right
## of it. A `top` at or above PANEL's top keeps PANEL.
func fit_below(top: float) -> void:
	var base := _base_panel()
	var next := base
	if top > base.position.y:
		var bottom := maxf(base.end.y, HudStyle.size("inventory_bottom"))
		next = Rect2(base.position.x, top, base.size.x, maxf(0.0, bottom - top))
	var step := clampf(floorf((next.size.y - EQUIP_ROOM) / 3.0), HudStyle.size("inventory_equip_step_min"), SLOT + 30.0)
	if next == panel and is_equal_approx(step, equip_step): return
	panel = next
	equip_step = step
	_refresh_buttons()
	queue_redraw()


## PANEL, or PANEL_WIDE while the character column shows.
func _base_panel() -> Rect2:
	return PANEL_WIDE if not _character.is_empty() else PANEL


## The hero's numbers for the character column (frost_hud.gd status_sheet); {} drops the column.
func set_character_view(sheet: Dictionary) -> void:
	var had := not _character.is_empty()
	_character = sheet
	if had != (not sheet.is_empty()):
		panel = Rect2(_base_panel().position.x, panel.position.y, _base_panel().size.x, panel.size.y)
		_refresh_buttons()
	if open: queue_redraw()


## Where the inventory part starts: right of the character column when it shows.
func _inner() -> Vector2:
	return panel.position + Vector2(CHARACTER_W if not _character.is_empty() else 0.0, 0.0)


func _button(text: String, area: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = area.position
	button.size = area.size
	# keyboard and pad reach the actions too (Enter on the focused one); the bag chip only by mouse
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	add_child(button)
	return button


func set_open(value: bool) -> void:
	var was := open
	open = value
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	_refresh_buttons()
	_update_chip(0.0)
	queue_redraw()
	if was and not open: closed.emit()


## The local hero's part of the snapshot.
func set_state(snapshot: Dictionary, local_peer: int) -> void:
	var player: Dictionary = snapshot.get("players", {}).get(local_peer, {})
	set_view(player.get("inventory", {}))


## The start of a find note (inventory.gd add).
const FIND_PREFIX := "Gefunden: "


## The item name of a find note ("Gefunden: ROTER TRANK" -> "ROTER TRANK"), "" for any other note.
static func found_name(note: String) -> String:
	return note.trim_prefix(FIND_PREFIX).strip_edges() if note.begins_with(FIND_PREFIX) else ""


## One line for finds: one stays "Gefunden: NAME", several become
## "3 Funde: ROTER TRANK, 2× BLAUER TRANK" (in the order found).
static func finds_line(names: Array) -> String:
	if names.size() == 1:
		return FIND_PREFIX + str(names[0])
	var order: Array = []
	var counts := {}
	for item: Variant in names:
		if not counts.has(item): order.append(item)
		counts[item] = int(counts.get(item, 0)) + 1
	var parts := PackedStringArray()
	for item: Variant in order:
		parts.append(("%d× %s" % [int(counts[item]), str(item)]) if int(counts[item]) > 1 else str(item))
	return "%d Funde: %s" % [names.size(), ", ".join(parts)]


## Several notes as one line: the finds joined (finds_line), else the last note.
static func summary(notes: Array) -> String:
	var finds: Array = []
	var last := ""
	for text: Variant in notes:
		var found := found_name(str(text))
		if found.is_empty(): last = str(text)
		else: finds.append(found)
	return finds_line(finds) if not finds.is_empty() else last


# The notes new since the last view: the last `count` of the view's note_log
# (every one of a burst in one frame), or just the last note without a log.
func _fresh_notes(count: int) -> Array:
	var recent: Array = _view.get("note_log", [])
	var out: Array = recent.slice(maxi(0, recent.size() - maxi(1, count))) if not recent.is_empty() else [str(_view.get("note", ""))]
	return out.filter(func(text: Variant) -> bool: return not str(text).is_empty())


## The inventory view itself (inventory.gd snapshot); the story worlds hand it in directly.
func set_view(view: Dictionary) -> void:
	_view = view
	var notes := int(_view.get("notes", 0))
	if notes != _notes_seen:
		var fresh := _fresh_notes(notes - _notes_seen) if _notes_seen >= 0 else []
		if not fresh.is_empty():
			# closed: the game's one message channel takes every note (it joins
			# finds close together into one); open: one line over the panel
			if not open and not noted.get_connections().is_empty():
				for text: String in fresh: noted.emit(text)
			else:
				_toast = summary(fresh)
				_toast_time = 3.5
		_notes_seen = notes
	var bag: Array = _view.get("bag", [])
	# a change in the bag shows the chip for a while
	var sig := ""
	for item: Dictionary in bag: sig += "%s:%d," % [str(item.get("uid", item.get("name", ""))), int(item.get("count", 1))]
	if sig != _bag_sig:
		_bag_sig = sig
		_chip_time = HudKit.rule("inventory_chip_hold", 3.0)
	_animated = false
	for key: String in EQUIP:
		if not str((_view.get(key, {}) as Dictionary).get("element", "")).is_empty(): _animated = true
	for item: Dictionary in bag:
		if not str(item.get("element", "")).is_empty(): _animated = true
	if not _is_equip(selected) and selected >= bag.size(): selected = HAND
	_toggle.text = "INVENTAR · I  %d/%d" % [bag.size(), int(_view.get("size", 12))]
	_refresh_buttons()
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	_update_chip(delta)
	if _toast_time > 0.0:
		_toast_time -= delta
		queue_redraw()
	# the element motes move on the pixel beat (src/item_art.gd FPS), not every frame
	if open and _animated:
		var beat := int(_clock * ItemArt.FPS)
		if beat != _beat:
			_beat = beat
			queue_redraw()


## The INVENTAR chip: off while blocked or while the bag is open (story
## worlds); with auto_hide_chip only after a bag change or under the mouse.
func _update_chip(delta: float) -> void:
	if _toggle == null: return
	_chip_time = maxf(0.0, _chip_time - delta)
	if not auto_hide_chip:
		_toggle.visible = not chip_blocked
		_toggle.modulate.a = 1.0
		return
	_toggle.visible = not chip_blocked and not open
	var near := _toggle.get_global_rect().grow(12.0).has_point(get_global_mouse_position())
	_toggle.modulate.a = 1.0 if near else clampf(_chip_time / 0.4, 0.0, 1.0)


func _is_equip(slot: int) -> bool:
	return EQUIP.values().has(slot)


func _item(slot: int) -> Dictionary:
	for key: String in EQUIP:
		if slot == int(EQUIP[key]): return _view.get(key, {})
	var bag: Array = _view.get("bag", [])
	return bag[slot] if slot >= 0 and slot < bag.size() else {}


func _has(type: String) -> bool:
	return Array(_view.get("bag", [])).any(func(item: Dictionary) -> bool: return str(item.get("type", "")) == type)


func _refresh_buttons() -> void:
	if _buttons.is_empty(): return
	var item := _item(selected)
	var type := str(item.get("type", ""))
	var known: bool = bool(item.get("identified", false))
	var piece := type in ["weapon", "gear"]
	var worn := _is_equip(selected)
	# an equipped armour, ring or amulet can come off (the weapon always stays in hand)
	_buttons.inv_equip.text = "ABNEHMEN" if worn and selected != HAND else "ANLEGEN"
	_buttons.inv_equip.disabled = item.is_empty() or (worn and selected == HAND) or (not worn and not piece)
	_buttons.inv_identify.disabled = item.is_empty() or known or type not in ["weapon", "gear", "potion"] or not _has("crystal")
	_buttons.inv_cleanse.disabled = not piece or not bool(item.get("cursed", false)) or not _has("stone")
	_buttons.inv_upgrade.disabled = not piece or not _has("upgrade_stone")
	_buttons.inv_reroll.disabled = not piece or not _has("dice_stone")
	_buttons.inv_use.disabled = worn or not (type == "potion" or bool(item.get("usable", false)))
	_buttons.inv_throw.disabled = type != "potion"
	_buttons.inv_drop.disabled = worn or item.is_empty()
	# only the actions that fit the chosen item, in rows from the left; a full row pushes up
	var rows: Array = [[]]
	var used := 0.0
	for entry: Array in ACTIONS:
		var button: Button = _buttons[entry[0]]
		button.visible = open and not button.disabled
		if not button.visible: continue
		button.size = Vector2(maxf(120.0, button.get_combined_minimum_size().x + 16.0), 36.0)
		if used > 0.0 and used + button.size.x > panel.end.x - _inner().x - BAG_X - 16.0:
			rows.append([])
			used = 0.0
		(rows[rows.size() - 1] as Array).append(button)
		used += button.size.x + 8.0
	for index in range(rows.size()):
		var x := _inner().x + BAG_X
		for button: Button in rows[index]:
			button.position = Vector2(x, panel.end.y - 92.0 - (rows.size() - 1 - index) * 42.0)
			x += button.size.x + 8.0


func _act(action: String) -> void:
	if action == "inv_throw":
		throw_armed.emit(selected)
		set_open(false)
		return
	if action == "inv_equip" and _is_equip(selected) and selected != HAND:
		acted.emit("inv_unequip", selected)
		return
	acted.emit(action, selected)


# --- Layout and input ----------------------------------------------------------------

func _equip_rect(index: int) -> Rect2:
	return Rect2(_inner() + Vector2(16.0 + (EQUIP_COLUMN - SLOT) * 0.5, 72 + index * equip_step), Vector2(SLOT, SLOT))


func _slot_rect(index: int) -> Rect2:
	var origin := _inner() + Vector2(BAG_X, 72)
	return Rect2(origin + Vector2((index % 6) * (SLOT + GAP), (index / 6) * (SLOT + GAP)), Vector2(SLOT, SLOT))


func _gui_input(event: InputEvent) -> void:
	if not open or not event is InputEventMouseButton or not event.pressed: return
	var click := (event as InputEventMouseButton).position
	if not panel.has_point(click):
		set_open(false)
		accept_event()
		return
	var keys := EQUIP.keys()
	for index in range(keys.size()):
		if _equip_rect(index).has_point(click): selected = int(EQUIP[keys[index]])
	for index in range(int(_view.get("size", 12))):
		if _slot_rect(index).has_point(click) and index < Array(_view.get("bag", [])).size(): selected = index
	var button := (event as InputEventMouseButton).button_index
	# A right-click on a potion makes it the quick potion (H drinks, G throws at the mouse).
	if button == MOUSE_BUTTON_RIGHT and not _is_equip(selected) and str(_item(selected).get("type", "")) == "potion":
		quick_chosen.emit(selected)
	# A double click is the item's natural action: equip a weapon or piece, use a consumable.
	if button == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).double_click and not _is_equip(selected):
		var item := _item(selected)
		var type := str(item.get("type", ""))
		if type in ["weapon", "gear"]: acted.emit("inv_equip", selected)
		elif type == "potion" or bool(item.get("usable", false)): acted.emit("inv_use", selected)
	_refresh_buttons()
	queue_redraw()
	accept_event()


# --- Drawing -------------------------------------------------------------------------

func _texture(path: String) -> Texture2D:
	if path.is_empty(): return null
	if not _textures.has(path): _textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


func _draw() -> void:
	if not open:
		if _toast_time > 0.0: _draw_toast()
		return
	# the world behind steps back: one window, nothing of the HUD reads through it
	if not _character.is_empty():
		draw_rect(Rect2(-size, size * 3.0), Color(HudStyle.color("outline"), 0.55))
	# the pause menu's panel look (src/ui/crypt_ui.gd)
	draw_rect(panel, Color(HudStyle.color("outline"), 0.6))
	draw_style_box(CryptUI.box("panel"), panel)
	if not _character.is_empty(): _draw_character()
	var inner := _inner()
	_text(inner + Vector2(18, 38), "INVENTAR", 24, HudStyle.color("text"))
	if float(_view.get("clone", 0.0)) > 0.0 and _toast_time <= 0.0:
		_text(Vector2(panel.end.x - 18 - _font.get_string_size("KLON %d s" % int(_view.clone), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, panel.position.y + 36), "KLON %d s" % int(_view.clone), 16, HudStyle.color("accent"))
	# one footer line: how to close left, the mouse hint right; both in the same small dim type
	var close_hint := "C / Tab / I / Esc schließt" if not _character.is_empty() else "I / Esc schließt"
	_text(Vector2(panel.position.x + 18, panel.end.y - 20), close_hint, 16, HudStyle.color("text_dim"))
	var mouse_hint := "Doppelklick: anlegen / benutzen"
	_text(Vector2(panel.end.x - 18 - _font.get_string_size(mouse_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, panel.end.y - 20), mouse_hint, 16, HudStyle.color("text_dim"))
	var keys := EQUIP.keys()
	for index in range(keys.size()):
		var rect := _equip_rect(index)
		_draw_slot(rect, _view.get(keys[index], {}), selected == int(EQUIP[keys[index]]))
		var label := str(EQUIP_LABELS[keys[index]])
		var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_text(Vector2(rect.get_center().x - width * 0.5, rect.end.y + 20.0), label, 16, HudStyle.color("text_dim"))
	var bag: Array = _view.get("bag", [])
	for index in range(int(_view.get("size", 12))):
		_draw_slot(_slot_rect(index), bag[index] if index < bag.size() else {}, selected == index)
		if index == quick and index < bag.size(): _draw_quick_badge(_slot_rect(index))
	_draw_details(_item(selected))
	if _toast_time > 0.0: _draw_toast()


func _draw_slot(rect: Rect2, item: Dictionary, chosen: bool) -> void:
	draw_rect(rect, HudStyle.color("slot"))
	var frame := Color(str(item.get("color", "3a3a40"))) if not item.is_empty() else HudStyle.color("panel_edge")
	if bool(item.get("cursed", false)): frame = HudStyle.color("danger")
	draw_rect(rect, frame, false, 2.0 if chosen else 1.0)
	if chosen: draw_rect(rect.grow(3), HudStyle.color("accent"), false, 2.0)
	if item.is_empty(): return
	var texture := _texture(str(item.get("sprite", "")))
	if texture != null:
		var scale := minf((rect.size.x - 12.0) / texture.get_width(), (rect.size.y - 12.0) / texture.get_height())
		scale = floorf(scale) if scale >= 1.0 else scale
		var size := Vector2(texture.get_width(), texture.get_height()) * scale
		draw_texture_rect(texture, Rect2(rect.get_center() - size * 0.5, size), false)
		var element := str(item.get("element", ""))
		if not element.is_empty() and bool(item.get("identified", false)):
			# the element's glow frame round the icon and its motes drifting over the slot (src/item_art.gd)
			var art := maxf(1.0, floorf(scale))
			ItemArt.draw_frame(self, Rect2(rect.get_center() - size * 0.5, size).grow(art), element, _clock, art)
			ItemArt.draw_motes(self, rect.grow(-4.0), element, _clock, art, int(item.get("uid", 0)), 3 + int(item.get("uid", 0)) % 3)
	if int(item.get("count", 1)) > 1: _text(rect.end - Vector2(20, 6), str(item.count), 16, HudStyle.color("text"))
	if str(item.get("type", "")) in ["weapon", "gear", "potion"] and not bool(item.get("identified", false)): _text(rect.position + Vector2(5, 17), "?", 16, HudStyle.color("accent"))
	if bool(item.get("blessed", false)): draw_circle(rect.position + Vector2(rect.size.x - 9, 9), 4.0, HudStyle.color("accent"))


## The character column: the hero's name and level, the numbers right-aligned
## under each other, then the run's cards as far as there is room ("+n" for the rest).
func _draw_character() -> void:
	var x := panel.position.x + 18.0
	var right := panel.position.x + CHARACTER_W - 14.0
	var room := right - x
	_text(Vector2(x, panel.position.y + 38), "CHARAKTER", 24, HudStyle.color("text"))
	_text(Vector2(x, panel.position.y + 86), HudKit.ellipsis(_font, str(_character.get("name", "")), 18, room), 18, HudStyle.color("accent"))
	_text(Vector2(x, panel.position.y + 110), HudKit.ellipsis(_font, str(_character.get("level", "")), 16, room), 16, HudStyle.color("text_dim"))
	var y := panel.position.y + 150.0
	for row: Array in _character.get("rows", []):
		var value := str(row[1])
		var value_w := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_text(Vector2(x, y), HudKit.ellipsis(_font, str(row[0]), 16, room - value_w - 12.0), 16, HudStyle.color("text_dim"))
		_text(Vector2(right - value_w, y), value, 16, HudStyle.color("text"))
		y += 26.0
	if bool(_character.get("has_cards", false)):
		y += 14.0
		_text(Vector2(x, y), "KARTEN", 16, HudStyle.color("accent"))
		y += 26.0
		var cards: Array = _character.get("cards", [])
		if cards.is_empty(): cards = ["noch keine"]
		var limit := panel.end.y - 48.0
		for index in range(cards.size()):
			var last := y + 26.0 > limit and index < cards.size() - 1
			var line := ("+%d weitere" % (cards.size() - index)) if last else str(cards[index])
			_text(Vector2(x, y), HudKit.ellipsis(_font, line, 16, room), 16, HudStyle.color("text"))
			y += 26.0
			if last or y > limit: break
	# a thin line between the column and the inventory
	draw_rect(Rect2(panel.position.x + CHARACTER_W - 1.0, panel.position.y + 16.0, 1.0, panel.size.y - 52.0), Color(HudStyle.color("panel_edge"), 0.8))


## Top of the action rows (or the footer): the details text ends above it.
func _details_end() -> float:
	var top := panel.end.y - 40.0
	for button: Button in _buttons.values():
		if button.visible: top = minf(top, button.position.y)
	return top - 6.0


func _draw_details(item: Dictionary) -> void:
	var at := _inner() + Vector2(BAG_X, 72 + 2.0 * (SLOT + GAP) + 34.0)
	if item.is_empty():
		_text(at, "Leerer Platz.", 16, HudStyle.color("text_dim"))
		return
	_text(at, str(item.get("name", "")), 18, Color(str(item.get("color", "d3bfa9"))))
	if not str(item.get("rarity_label", "")).is_empty(): _text(at + Vector2(0, 22), str(item.rarity_label), 16, Color(str(item.get("color", "d3bfa9"))))
	var y := 48.0
	var room := panel.end.x - at.x - 18.0
	# the text never runs into the action buttons: what does not fit ends in "..."
	var limit := _details_end() - at.y
	var lines: Array = []
	for line: String in item.get("lines", []):
		var colour := HudStyle.color("danger") if line.begins_with("FLUCH") else HudStyle.color("accent") if line.begins_with("SEGEN") or line.begins_with("STUFE") else HudStyle.color("text")
		# the element line in the element's own light
		if line.begins_with("ELEMENT"): colour = ItemArt.glow(str(item.get("element", "")), colour)
		# long lines wrap inside the panel
		for part: String in _wrap(line, 16, room): lines.append([part, colour])
	# a potion says how it becomes the quick potion, or that it is one
	if str(item.get("type", "")) == "potion" and not _is_equip(selected):
		var hint := "SCHNELLTRANK · H trinken · G werfen" if selected == quick else "Rechtsklick: Schnelltrank (H trinken · G werfen)"
		for part: String in _wrap(hint, 16, room): lines.append([part, HudStyle.color("accent") if selected == quick else HudStyle.color("text_dim")])
	for index in range(lines.size()):
		if y + 22.0 > limit and index < lines.size() - 1:
			_text(at + Vector2(0, y), "...", 16, HudStyle.color("text_dim"))
			break
		_text(at + Vector2(0, y), str(lines[index][0]), 16, lines[index][1])
		y += 22.0


## The quick potion's mark: a small "H" plate in the slot's lower left corner.
func _draw_quick_badge(rect: Rect2) -> void:
	var plate := Rect2(rect.position + Vector2(3, rect.size.y - 17), Vector2(14, 14))
	draw_rect(plate, Color(HudStyle.color("outline"), 0.9))
	draw_rect(plate, HudStyle.color("accent"), false, 1.0)
	var width := _font.get_string_size("H", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(_font, plate.position + Vector2((plate.size.x - width) * 0.5, 11), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HudStyle.color("accent"))


## Splits a line into pieces no wider than `width` at `size`.
func _wrap(line: String, size: int, width: float) -> Array[String]:
	var out: Array[String] = []
	var current := ""
	for word: String in line.split(" "):
		var next := word if current.is_empty() else current + " " + word
		if not current.is_empty() and _font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append(current)
			current = word
		else:
			current = next
	if not current.is_empty(): out.append(current)
	return out


func _draw_toast() -> void:
	# with the window closed its messages run in the HUD's one toast channel (hell_game noted)
	if not open: return
	var text := _toast
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	# In the open window it sits in the header beside the title (never over the HUD), in
	# up to two lines; a longer note sits centred above the panel, as wide as it needs.
	var title_width := _font.get_string_size("INVENTAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var at := _inner() + Vector2(18.0 + title_width + 16.0, 14.0)
	var room := panel.end.x - 18.0 - (at.x + 14.0)
	var lines: Array[String] = [text]
	if width > room:
		lines = _wrap(text, 16, room)
		if lines.size() > 2:
			lines = _wrap(text, 16, 1280.0 - 64.0)
			at = Vector2.INF
		width = 0.0
		for line: String in lines: width = maxf(width, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var height := 30.0 + 22.0 * (lines.size() - 1)
	var rect := Rect2(at, Vector2(width + 28, height))
	if lines.size() > 1 and at.is_finite():
		rect.position.y = panel.position.y + 8.0
	elif not at.is_finite():
		rect.position = Vector2(640 - (width + 28) * 0.5, panel.position.y - 6.0 - height)
	var alpha := clampf(_toast_time, 0.0, 1.0)
	HudStyle.panel(self, rect, alpha)
	draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), Color(HudStyle.color("accent"), alpha))
	for i in range(lines.size()):
		draw_string(_font, rect.position + Vector2(14, 21 + 22 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(HudStyle.color("text"), alpha))


func _text(at: Vector2, value: String, font_size: int, colour: Color) -> void:
	draw_string_outline(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(HudStyle.color("outline"), colour.a))
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
