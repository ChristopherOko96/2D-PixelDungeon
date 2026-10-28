extends Control
## The hero's inventory (key I or Tab; the game keeps running): the weapon in
## hand, the bag's slots with rarity frames, the chosen item's text and the
## actions that fit it (equip, identify with a crystal, break a curse with a
## stone, drink, throw, drop). Throwing arms the next click in the world as the
## target. Also shows a short note when something is found or happens, and a
## small INVENTAR button. Sends actions only; the host decides (inventory.gd).

signal acted(action: String, value: int)
signal throw_armed(slot: int)

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const HAND := 99
const SLOT := 60.0
const GAP := 6.0
const PANEL := Rect2(300, 96, 680, 492)

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	_font = PixelStyle.create_font()
	# The toggle sits in the bottom-right corner, as wide as its longest text.
	_toggle = _button("INVENTAR · I  12/12", Rect2(0, 664, 10, 40), func(): set_open(not open))
	_toggle.add_theme_font_size_override("font_size", 16)
	_toggle.size.x = _toggle.get_combined_minimum_size().x + 16.0
	_toggle.position.x = 1264.0 - _toggle.size.x
	# Action buttons in two rows of three, wide enough for every label.
	var width := (PANEL.size.x - 32.0 - 8.0) / 3.0
	var entries := [["inv_equip", "ANLEGEN"], ["inv_identify", "IDENTIFIZIEREN"], ["inv_cleanse", "FLUCH BRECHEN"], ["inv_drink", "TRINKEN"], ["inv_throw", "WERFEN"], ["inv_drop", "ABLEGEN"]]
	for index in range(entries.size()):
		var action: String = entries[index][0]
		var at := Vector2(PANEL.position.x + 16.0 + float(index % 3) * (width + 4.0), PANEL.end.y - 92.0 + float(index / 3) * 42.0)
		var button := _button(str(entries[index][1]), Rect2(at, Vector2(width, 36)), func(): _act(action))
		button.add_theme_font_size_override("font_size", 13)
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
	_view = player.get("inventory", {})
	var notes := int(_view.get("notes", 0))
	if notes != _notes_seen:
		if _notes_seen >= 0 and not str(_view.get("note", "")).is_empty():
			_toast = str(_view.note)
			_toast_time = 3.5
		_notes_seen = notes
	var bag: Array = _view.get("bag", [])
	if selected != HAND and selected >= bag.size(): selected = HAND
	_toggle.text = "INVENTAR · I  %d/%d" % [bag.size(), int(_view.get("size", 12))]
	_refresh_buttons()
	queue_redraw()


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		queue_redraw()


func _item(slot: int) -> Dictionary:
	if slot == HAND: return _view.get("weapon", {})
	var bag: Array = _view.get("bag", [])
	return bag[slot] if slot >= 0 and slot < bag.size() else {}


func _has(type: String) -> bool:
	return Array(_view.get("bag", [])).any(func(item: Dictionary) -> bool: return str(item.get("type", "")) == type)


func _refresh_buttons() -> void:
	if _buttons.is_empty(): return
	var item := _item(selected)
	var type := str(item.get("type", ""))
	var known: bool = bool(item.get("identified", false))
	_buttons.inv_equip.disabled = selected == HAND or type != "weapon"
	_buttons.inv_identify.disabled = item.is_empty() or known or type not in ["weapon", "potion"] or not _has("crystal")
	_buttons.inv_cleanse.disabled = type != "weapon" or not bool(item.get("cursed", false)) or not _has("stone")
	_buttons.inv_drink.disabled = type != "potion"
	_buttons.inv_throw.disabled = type != "potion"
	_buttons.inv_drop.disabled = selected == HAND or item.is_empty()


func _act(action: String) -> void:
	if action == "inv_throw":
		throw_armed.emit(selected)
		set_open(false)
		return
	acted.emit(action, selected)


# --- Layout and input ----------------------------------------------------------------

func _hand_rect() -> Rect2:
	return Rect2(PANEL.position + Vector2(16, 64), Vector2(96, 96))


func _slot_rect(index: int) -> Rect2:
	var origin := PANEL.position + Vector2(132, 64)
	return Rect2(origin + Vector2((index % 4) * (SLOT + GAP), (index / 4) * (SLOT + GAP)), Vector2(SLOT, SLOT))


func _gui_input(event: InputEvent) -> void:
	if not open or not event is InputEventMouseButton or not event.pressed: return
	var click := (event as InputEventMouseButton).position
	if not PANEL.has_point(click):
		set_open(false)
		accept_event()
		return
	if _hand_rect().has_point(click): selected = HAND
	for index in range(int(_view.get("size", 12))):
		if _slot_rect(index).has_point(click) and index < Array(_view.get("bag", [])).size(): selected = index
	# A double click is the item's natural action: equip a weapon, drink a potion.
	if (event as InputEventMouseButton).double_click:
		var type := str(_item(selected).get("type", ""))
		if type == "weapon" and selected != HAND: acted.emit("inv_equip", selected)
		elif type == "potion": acted.emit("inv_drink", selected)
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
	CryptUI.draw_box(self, "panel", PANEL)
	_text(PANEL.position + Vector2(18, 38), "INVENTAR", 24, CryptUI.GOLD)
	var title_width := _font.get_string_size("INVENTAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_text(PANEL.position + Vector2(18.0 + title_width + 24.0, 36), "Doppelklick: anlegen / trinken", 13, CryptUI.MUTED)
	_text(PANEL.position + Vector2(16, 182), "IN DER HAND", 13, CryptUI.MUTED)
	_draw_slot(_hand_rect(), _view.get("weapon", {}), selected == HAND)
	var bag: Array = _view.get("bag", [])
	for index in range(int(_view.get("size", 12))):
		_draw_slot(_slot_rect(index), bag[index] if index < bag.size() else {}, selected == index)
	_draw_details(_item(selected))
	if _toast_time > 0.0: _draw_toast()


func _draw_slot(rect: Rect2, item: Dictionary, chosen: bool) -> void:
	draw_rect(rect, Color("241c1c"))
	var frame := Color(str(item.get("color", "4a3d3c"))) if not item.is_empty() else Color("4a3d3c")
	if bool(item.get("cursed", false)): frame = Color("8a2a5a")
	draw_rect(rect, frame, false, 3.0 if chosen else 2.0)
	if chosen: draw_rect(rect.grow(3), CryptUI.GOLD, false, 2.0)
	if item.is_empty(): return
	var texture := _texture(str(item.get("sprite", "")))
	if texture != null:
		var scale := minf((rect.size.x - 12.0) / texture.get_width(), (rect.size.y - 12.0) / texture.get_height())
		scale = floorf(scale) if scale >= 1.0 else scale
		var size := Vector2(texture.get_width(), texture.get_height()) * scale
		draw_texture_rect(texture, Rect2(rect.get_center() - size * 0.5, size), false)
	if int(item.get("count", 1)) > 1: _text(rect.end - Vector2(18, 6), str(item.count), 14, CryptUI.CREAM)
	if str(item.get("type", "")) in ["weapon", "potion"] and not bool(item.get("identified", false)): _text(rect.position + Vector2(5, 17), "?", 16, CryptUI.GOLD)
	if bool(item.get("blessed", false)): draw_circle(rect.position + Vector2(rect.size.x - 9, 9), 4.0, Color("f4d27a"))


func _draw_details(item: Dictionary) -> void:
	var at := PANEL.position + Vector2(16, 290)
	if item.is_empty():
		_text(at, "Leerer Platz.", 16, CryptUI.MUTED)
		return
	_text(at, str(item.get("name", "")), 18, Color(str(item.get("color", "d3bfa9"))))
	if not str(item.get("rarity_label", "")).is_empty(): _text(at + Vector2(0, 20), str(item.rarity_label), 13, Color(str(item.get("color", "d3bfa9"))))
	var y := 42.0
	for line: String in item.get("lines", []):
		var colour := Color("ef8a6a") if line.begins_with("FLUCH") else Color("f4d27a") if line.begins_with("SEGEN") else CryptUI.BONE
		_text(at + Vector2(0, y), line, 14, colour)
		y += 18.0


func _draw_toast() -> void:
	var text := _toast
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	# Above the world while playing; under the open panel so it never hides behind it.
	var top := PANEL.position.y - 40.0 if open else 128.0
	var rect := Rect2(Vector2(640 - width * 0.5 - 14, top), Vector2(width + 28, 30))
	var alpha := clampf(_toast_time, 0.0, 1.0)
	draw_rect(rect, Color(CryptUI.INK, 0.85 * alpha))
	draw_rect(rect, Color(CryptUI.GOLD, alpha), false, 2.0)
	draw_string(_font, rect.position + Vector2(14, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(CryptUI.CREAM, alpha))


func _text(at: Vector2, value: String, font_size: int, colour: Color) -> void:
	draw_string_outline(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, CryptUI.INK)
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
