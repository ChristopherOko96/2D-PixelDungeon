extends Control
## The hero's inventory (key I or Tab; the game keeps running), the same in
## every world and in the neutral HUD look (src/ui/hud_style.gd): the four
## equipment slots (weapon, armour, ring, amulet), the bag's slots with rarity
## frames, the chosen item's text and the actions that fit it: equip or take
## off, identify with a crystal, break a curse with a stone, raise a stage
## (Aufwertungsstein), reroll a stage (Würfelstein), use (drink a potion, break
## a clone seal, look into a mirror crystal), throw, drop. Throwing arms the
## next click in the world as the target. Also shows a short note when
## something is found or happens, and a small INVENTAR button. Sends actions
## only; the rules decide (src/items/inventory.gd, docs/ITEM-SYSTEM-V2.de.md).
## An identified item of an element wears its glow frame and sheds a few of its
## pixel motes (src/item_art.gd: embers, drops, rime, zaps, orbiting motes),
## redrawn on the pixel beat, not every frame; unknown items stay unknown.

signal acted(action: String, value: int)
signal throw_armed(slot: int)

const PixelStyle = preload("res://src/pixel_style.gd")
const HudStyle = preload("res://src/ui/hud_style.gd")
const ItemArt = preload("res://src/item_art.gd")
const HAND := 99
## Slot values of the equipment slots (the bag uses 0..size-1), as inventory.gd.
const EQUIP := {"weapon": 99, "armor": 98, "ring": 97, "amulet": 96}
const EQUIP_LABELS := {"weapon": "WAFFE", "armor": "RÜSTUNG", "ring": "RING", "amulet": "AMULETT"}
const SLOT := 60.0
const GAP := 6.0
const PANEL := Rect2(280, 72, 720, 560)

var open := false
var selected := HAND
var _view: Dictionary = {}
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	_font = PixelStyle.create_font()
	# The toggle sits in the bottom-right corner, as wide as its longest text.
	_toggle = _button("INVENTAR · I  12/12", Rect2(0, 676, 10, 28), func(): set_open(not open))
	_toggle.add_theme_font_size_override("font_size", 12)
	# the HUD's neutral look, like the menu button (src/ui/hud_style.gd)
	HudStyle.style_button(_toggle)
	_toggle.size.x = _toggle.get_combined_minimum_size().x + 16.0
	_toggle.position.x = 1264.0 - _toggle.size.x
	# Action buttons in two rows of four, wide enough for every label.
	var width := (PANEL.size.x - 32.0 - 12.0) / 4.0
	var entries := [["inv_equip", "ANLEGEN"], ["inv_identify", "IDENTIFIZIEREN"], ["inv_cleanse", "FLUCH BRECHEN"], ["inv_upgrade", "AUFWERTEN"],
		["inv_use", "BENUTZEN"], ["inv_throw", "WERFEN"], ["inv_reroll", "NEU WÜRFELN"], ["inv_drop", "WEGWERFEN"]]
	for index in range(entries.size()):
		var action: String = entries[index][0]
		var at := Vector2(PANEL.position.x + 16.0 + float(index % 4) * (width + 4.0), PANEL.end.y - 92.0 + float(index / 4) * 42.0)
		var button := _button(str(entries[index][1]), Rect2(at, Vector2(width, 36)), func(): _act(action))
		button.add_theme_font_size_override("font_size", 12)
		HudStyle.style_button(button)
		_buttons[action] = button
	set_open(false)


func _button(text: String, area: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = area.position
	button.size = area.size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	add_child(button)
	return button


func set_open(value: bool) -> void:
	open = value
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	for button: Button in _buttons.values(): button.visible = open
	_refresh_buttons()
	queue_redraw()


## The local hero's part of the snapshot.
func set_state(snapshot: Dictionary, local_peer: int) -> void:
	var player: Dictionary = snapshot.get("players", {}).get(local_peer, {})
	set_view(player.get("inventory", {}))


## The inventory view itself (inventory.gd snapshot); the story worlds hand it in directly.
func set_view(view: Dictionary) -> void:
	_view = view
	var notes := int(_view.get("notes", 0))
	if notes != _notes_seen:
		if _notes_seen >= 0 and not str(_view.get("note", "")).is_empty():
			_toast = str(_view.note)
			_toast_time = 3.5
		_notes_seen = notes
	var bag: Array = _view.get("bag", [])
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
	if _toast_time > 0.0:
		_toast_time -= delta
		queue_redraw()
	# the element motes move on the pixel beat (src/item_art.gd FPS), not every frame
	if open and _animated:
		var beat := int(_clock * ItemArt.FPS)
		if beat != _beat:
			_beat = beat
			queue_redraw()


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
	return Rect2(PANEL.position + Vector2(16, 72 + index * (SLOT + 22.0)), Vector2(SLOT, SLOT))


func _slot_rect(index: int) -> Rect2:
	var origin := PANEL.position + Vector2(112, 72)
	return Rect2(origin + Vector2((index % 6) * (SLOT + GAP), (index / 6) * (SLOT + GAP)), Vector2(SLOT, SLOT))


func _gui_input(event: InputEvent) -> void:
	if not open or not event is InputEventMouseButton or not event.pressed: return
	var click := (event as InputEventMouseButton).position
	if not PANEL.has_point(click):
		set_open(false)
		accept_event()
		return
	var keys := EQUIP.keys()
	for index in range(keys.size()):
		if _equip_rect(index).has_point(click): selected = int(EQUIP[keys[index]])
	for index in range(int(_view.get("size", 12))):
		if _slot_rect(index).has_point(click) and index < Array(_view.get("bag", [])).size(): selected = index
	# A double click is the item's natural action: equip a weapon or piece, use a consumable.
	if (event as InputEventMouseButton).double_click and not _is_equip(selected):
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
	draw_rect(PANEL, Color(HudStyle.color("outline"), 0.85))
	HudStyle.panel(self, PANEL)
	_text(PANEL.position + Vector2(18, 38), "INVENTAR", 24, HudStyle.color("text"))
	var title_width := _font.get_string_size("INVENTAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_text(PANEL.position + Vector2(18.0 + title_width + 24.0, 36), "Doppelklick: anlegen / benutzen", 12, HudStyle.color("text_dim"))
	if float(_view.get("clone", 0.0)) > 0.0:
		_text(Vector2(PANEL.end.x - 18 - _font.get_string_size("KLON %d s" % int(_view.clone), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, PANEL.position.y + 36), "KLON %d s" % int(_view.clone), 12, HudStyle.color("accent"))
	var keys := EQUIP.keys()
	for index in range(keys.size()):
		var rect := _equip_rect(index)
		_draw_slot(rect, _view.get(keys[index], {}), selected == int(EQUIP[keys[index]]))
		_text(rect.position + Vector2(0, SLOT + 14), str(EQUIP_LABELS[keys[index]]), 10, HudStyle.color("text_dim"))
	var bag: Array = _view.get("bag", [])
	for index in range(int(_view.get("size", 12))):
		_draw_slot(_slot_rect(index), bag[index] if index < bag.size() else {}, selected == index)
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
	if int(item.get("count", 1)) > 1: _text(rect.end - Vector2(18, 6), str(item.count), 14, HudStyle.color("text"))
	if str(item.get("type", "")) in ["weapon", "gear", "potion"] and not bool(item.get("identified", false)): _text(rect.position + Vector2(5, 17), "?", 16, HudStyle.color("accent"))
	if bool(item.get("blessed", false)): draw_circle(rect.position + Vector2(rect.size.x - 9, 9), 4.0, HudStyle.color("accent"))


func _draw_details(item: Dictionary) -> void:
	var at := PANEL.position + Vector2(112, 72 + 2.0 * (SLOT + GAP) + 34.0)
	if item.is_empty():
		_text(at, "Leerer Platz.", 16, HudStyle.color("text_dim"))
		return
	_text(at, str(item.get("name", "")), 18, Color(str(item.get("color", "d3bfa9"))))
	if not str(item.get("rarity_label", "")).is_empty(): _text(at + Vector2(0, 20), str(item.rarity_label), 12, Color(str(item.get("color", "d3bfa9"))))
	var y := 44.0
	var room := PANEL.end.x - at.x - 18.0
	for line: String in item.get("lines", []):
		var colour := HudStyle.color("danger") if line.begins_with("FLUCH") else HudStyle.color("accent") if line.begins_with("SEGEN") or line.begins_with("STUFE") else HudStyle.color("text")
		# the element line in the element's own light
		if line.begins_with("ELEMENT"): colour = ItemArt.glow(str(item.get("element", "")), colour)
		# long lines wrap inside the panel
		for part: String in _wrap(line, 14, room):
			_text(at + Vector2(0, y), part, 14, colour)
			y += 20.0


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
	var text := _toast
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	# Above the world while playing; above the open panel so it never hides behind it.
	var top := PANEL.position.y - 40.0 if open else 128.0
	var rect := Rect2(Vector2(640 - width * 0.5 - 14, top), Vector2(width + 28, 30))
	var alpha := clampf(_toast_time, 0.0, 1.0)
	HudStyle.panel(self, rect, alpha)
	draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), Color(HudStyle.color("accent"), alpha))
	draw_string(_font, rect.position + Vector2(14, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(HudStyle.color("text"), alpha))


func _text(at: Vector2, value: String, font_size: int, colour: Color) -> void:
	draw_string_outline(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(HudStyle.color("outline"), colour.a))
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
