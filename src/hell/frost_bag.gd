extends RefCounted
## The bag screen of the Frostgruft (key I), Story 1's inventory in this
## runtime: the weapon in hand, twelve bag slots with sprites and rarity
## colours, the selected item's text and its actions (Anlegen, Trinken,
## Werfen, Identifizieren, Fluch brechen, Ablegen). The game stands still
## while it is open. Werfen closes it; the next left click throws there.

const FrostItems = preload("res://src/hell/frost_items.gd")
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")
const PANEL := Rect2(220, 110, 840, 500)
const CELL := 76.0
const LABELS := {"equip": "ANLEGEN", "identify": "IDENTIFIZIEREN", "cleanse": "FLUCH BRECHEN", "drink": "TRINKEN", "throw": "WERFEN", "drop": "ABLEGEN"}


static func is_open(g: Node) -> bool:
	return bool(g.state.get("bag_open", false))


static func toggle(g: Node) -> void:
	if FrostItems.inv(g).is_empty():
		return
	g.state.bag_open = not is_open(g)
	g.state.bag_sel = int(g.state.get("bag_sel", FrostItems.EQUIPPED))
	g._sound_raw("ui_click")


static func _origin(size: Vector2) -> Vector2:
	return (size - Vector2(1280, 720)) / 2.0


static func _slot_rect(i: int, size: Vector2) -> Rect2:
	var o := _origin(size) + PANEL.position
	if i == FrostItems.EQUIPPED:
		return Rect2(o + Vector2(30, 70), Vector2(CELL * 1.4, CELL * 1.4))
	return Rect2(o + Vector2(30 + (i % 4) * (CELL + 8), 210 + (i / 4) * (CELL + 8)), Vector2(CELL, CELL))


static func _button_rect(j: int, size: Vector2) -> Rect2:
	return Rect2(_origin(size) + PANEL.position + Vector2(400, 290 + j * 46), Vector2(400, 38))


## A left click while the bag is open: picks a slot or runs an action. True when used.
static func click(g: Node, at: Vector2, size: Vector2) -> bool:
	if not is_open(g):
		return false
	for i in [FrostItems.EQUIPPED] + range(int(FrostItems.data().get("bag", 12))):
		if _slot_rect(i, size).has_point(at) and not FrostItems.slot(g, i).is_empty():
			g.state.bag_sel = i
			g._sound_raw("ui_click")
			return true
	var sel := int(g.state.get("bag_sel", FrostItems.EQUIPPED))
	var acts := FrostItems.actions(g, sel)
	for j in range(acts.size()):
		if _button_rect(j, size).has_point(at):
			if str(acts[j]) == "throw":
				g.state.throw_slot = sel
				g.state.bag_open = false
				g._toast("Linksklick: Trank werfen · Rechtsklick: abbrechen")
			else:
				FrostItems.act(g, str(acts[j]), sel)
				if FrostItems.slot(g, sel).is_empty():
					g.state.bag_sel = FrostItems.EQUIPPED
			g._sound_raw("ui_click")
			return true
	return true


static func _icon(g: Node, h: CanvasItem, item: Dictionary, r: Rect2) -> void:
	var tex := FrostItems.texture_of(g, item)
	if tex == null:
		return
	var k := minf((r.size.x - 16.0) / tex.get_width(), (r.size.y - 16.0) / tex.get_height())
	var s := tex.get_size() * k
	h.draw_texture_rect(tex, Rect2(r.get_center() - s / 2.0, s), false)
	if int(item.get("count", 1)) > 1:
		h.draw_string(FONT, r.position + Vector2(r.size.x - 22, r.size.y - 8), str(item.count), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


static func draw(g: Node, h: CanvasItem, size: Vector2) -> void:
	var iv := FrostItems.inv(g)
	if iv.is_empty():
		return
	# throw targeting: a ring at the mouse, clamped to the throw range
	if int(g.state.get("throw_slot", -1)) >= 0:
		var mouse: Vector2 = g.get_viewport().get_mouse_position()
		h.draw_arc(mouse, 26.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.4, 0.9), 3.0)
	if not is_open(g):
		return
	var o := _origin(size)
	h.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var panel := Rect2(o + PANEL.position, PANEL.size)
	h.draw_rect(panel, Color(0.05, 0.07, 0.11, 0.97))
	h.draw_rect(panel, Color(0.55, 0.85, 1.0, 0.9), false, 3.0)
	h.draw_string(FONT, panel.position + Vector2(30, 42), "RUCKSACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.75, 0.92, 1.0))
	h.draw_string(FONT, panel.position + Vector2(30 + CELL * 1.4 + 16, 96), "IN DER HAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.8))
	var sel := int(g.state.get("bag_sel", FrostItems.EQUIPPED))
	var slots: Array = [FrostItems.EQUIPPED] + range(int(FrostItems.data().get("bag", 12)))
	for i: int in slots:
		var r := _slot_rect(i, size)
		var item := FrostItems.slot(g, i)
		h.draw_rect(r, Color(0.1, 0.13, 0.19))
		var c := FrostItems.color_of(item) if not item.is_empty() else Color(0.3, 0.35, 0.45)
		h.draw_rect(r, Color(c, 1.0 if i == sel else 0.6), false, 4.0 if i == sel else 2.0)
		if not item.is_empty():
			_icon(g, h, item, r)
	if iv.get("shield", 0) > 0:
		h.draw_string(FONT, panel.position + Vector2(30 + CELL * 1.4 + 16, 120), "SCHUTZ: %d Treffer" % int(iv.shield), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.4))
	var item := FrostItems.slot(g, sel)
	if item.is_empty():
		return
	var x := panel.position.x + 400.0
	h.draw_string(FONT, Vector2(x, panel.position.y + 90), FrostItems.name_of(g, item), HORIZONTAL_ALIGNMENT_LEFT, 410, 16, FrostItems.color_of(item))
	var y := panel.position.y + 124.0
	for line: String in FrostItems.lines_of(g, item):
		for part: String in _wrap(line, 40):
			h.draw_string(FONT, Vector2(x, y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.88, 0.92))
			y += 18.0
		y += 4.0
	var acts := FrostItems.actions(g, sel)
	for j in range(acts.size()):
		var b := _button_rect(j, size)
		h.draw_rect(b, Color(0.13, 0.18, 0.26))
		h.draw_rect(b, Color(0.55, 0.85, 1.0, 0.7), false, 2.0)
		h.draw_string(FONT, b.position + Vector2(14, 25), str(LABELS.get(str(acts[j]), str(acts[j]).to_upper())), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	h.draw_string(FONT, panel.position + Vector2(30, panel.size.y - 18), "I: schließen · Klick: wählen · Gegenstände nimmst du durch Darüberlaufen", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.8))


static func _wrap(text: String, width: int) -> Array:
	var out: Array = []
	var line := ""
	for word: String in text.split(" "):
		if line.length() + word.length() + 1 > width and line != "":
			out.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		out.append(line)
	return out
