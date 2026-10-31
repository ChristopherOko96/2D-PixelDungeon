extends Control
## The story Testraum's fold-out column under the mini-map (src/debug/story_testraum.gd):
## the arrow chip under "ESC · MENÜ" (src/ui/hud_kit.gd menu_rect) folds it out
## (F1 too); then the rows of StoryTestraum.rows(), culled to the column and
## scrolled by the wheel: the live line (frame time), the DPS meter (two
## lines) with its RESET, the search field (it filters MONSTER, BOSSE and NPCS), ZULETZT (the
## last entries used), then the sections folding on their headers. Every row
## and button is at least panel.min_row px high. A list entry can carry a
## button of its own at its right end (HELD: spawn beside the hero). Clicks
## outside the column reach the world. Layout: debug_story_testraum.json "panel".

const HudKit = preload("res://src/ui/hud_kit.gd")
const HudStyle = preload("res://src/ui/hud_style.gd")
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")

## The Testraum node (rows(), act(), opts(), search_on, live texts).
var host: Node
var items: Array = []
var scroll := 0.0
var _content := 0.0
## [Rect2 in content coordinates, action, arg, greyed out]
var _hits: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit()
	rebuild()


## Covers the whole screen: anchors set under the HUD's CanvasLayer left it 0 x 0
## (probe 2026-10-31), so its size follows the viewport by hand.
func _fit() -> void:
	var screen := get_viewport_rect().size
	if position != Vector2.ZERO or size != screen:
		position = Vector2.ZERO
		size = screen


func _p(key: String, fallback: float) -> float:
	return float((host.cfg.get("panel", {}) as Dictionary).get(key, fallback))


func _fs() -> int:
	return int(HudStyle.size("font_small"))


func is_open() -> bool:
	return bool(host.opts().get("open", false))


## Folds the column out or in (the chip, F1).
func toggle() -> void:
	host.opts().open = not is_open()
	queue_redraw()


## True while the mouse is over the chip or the open column (the hero's mouse attack waits then).
func covers_mouse() -> bool:
	return _has_point(get_local_mouse_position())


## Takes the host's rows anew and lays them out.
func rebuild() -> void:
	items = host.rows()
	_layout()
	scroll = clampf(scroll, 0.0, maxf(0.0, _content + _p("pad", 6.0) * 2.0 - body_rect().size.y))
	queue_redraw()


func chip_rect() -> Rect2:
	var m := HudKit.menu_rect(size)
	return Rect2(m.position.x, m.end.y + _p("gap", 4.0), m.size.x, _p("chip_height", 26.0))


func body_rect() -> Rect2:
	var chip := chip_rect()
	var top := chip.end.y + _p("gap", 4.0)
	var room := maxf(40.0, size.y - top - _p("bottom_margin", 92.0))
	return Rect2(chip.position.x, top, chip.size.x, clampf(_content + _p("pad", 6.0) * 2.0, 40.0, room))


func _line_h() -> float:
	return maxf(float(_fs()) + _p("row_pad", 10.0), _p("min_row", 26.0))


func _btn_w(label: String) -> float:
	return HudStyle.width(FONT, label, _fs()) + _p("box_pad", 14.0)


func _layout() -> void:
	_hits = []
	var w := chip_rect().size.x - _p("pad", 6.0) * 2.0
	var fs := _fs()
	var line := _line_h()
	var y := line
	for row: Dictionary in items:
		row.y = y
		match str(row.kind):
			"head":
				row.h = line + 2.0
				_hits.append([Rect2(0, y, w, row.h), row.act, row.arg, false])
			"item":
				row.h = line
				var right := w
				if row.has("btn"):
					var b: Dictionary = row.btn
					var bw := _btn_w(str(b.label))
					row.btn_rect = Rect2(w - bw, y + 2.0, bw, line - 4.0)
					_hits.append([row.btn_rect, b.act, b.arg, bool(b.get("off", false))])
					right = w - bw - 4.0
				row.right = right
				_hits.append([Rect2(0, y, right, line), row.act, row.arg, bool(row.off)])
			"live":
				row.h = line + float(fs) + 4.0
				var lb: Dictionary = row.btn
				var lw := _btn_w(str(lb.label))
				row.btn_rect = Rect2(w - lw, y + 2.0, lw, line - 4.0)
				_hits.append([row.btn_rect, lb.act, lb.arg, false])
			"search":
				row.h = line + 2.0
				row.clear = Rect2(w - line, y, line, line)
				row.box = Rect2(0, y, w - line - 4.0, line)
				_hits.append([row.clear, "search_clear", null, false])
				_hits.append([row.box, "search_focus", null, false])
			"text":
				row.lines = _wrap(str(row.label), w)
				row.h = float((row.lines as Array).size()) * (fs + 3.0) + 4.0
			"opts":
				var x := 0.0
				var yy := y
				if str(row.label) != "":
					yy += fs + 5.0
				var boxes: Array = []
				for o: Dictionary in row.opts:
					var bw := minf(_btn_w(str(o.label)), w)
					if x > 0.0 and x + bw > w:
						x = 0.0
						yy += line + 3.0
					var r := Rect2(x, yy, bw, line)
					boxes.append(r)
					_hits.append([r, o.act, o.arg, bool(o.off)])
					x += bw + 4.0
				row.boxes = boxes
				row.h = yy + line - y + 2.0
		y += float(row.h) + _p("row_gap", 3.0)
	_content = y


func _wrap(text: String, width: float) -> Array:
	var lines: Array = []
	var cur := ""
	for word: String in text.split(" "):
		var test := word if cur == "" else cur + " " + word
		if cur != "" and HudStyle.width(FONT, test, _fs()) > width:
			lines.append(cur)
			cur = word
		else:
			cur = test
	if cur != "":
		lines.append(cur)
	return lines


func _has_point(point: Vector2) -> bool:
	if not visible:
		return false
	return chip_rect().has_point(point) or (is_open() and body_rect().has_point(point))


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	accept_event()
	if not mb.pressed:
		return
	var step := _p("scroll_step", 52.0)
	var most := maxf(0.0, _content + _p("pad", 6.0) * 2.0 - body_rect().size.y)
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			scroll = clampf(scroll - step, 0.0, most)
		MOUSE_BUTTON_WHEEL_DOWN:
			scroll = clampf(scroll + step, 0.0, most)
		MOUSE_BUTTON_LEFT:
			if chip_rect().has_point(mb.position):
				host.search(false)
				toggle()
			elif is_open():
				_click(mb.position)
	queue_redraw()


## A click at panel point `point`: the first hit box under it acts (greyed
## ones do nothing); anything but the search field takes its focus away.
func _click(point: Vector2) -> void:
	var body := body_rect()
	var pad := _p("pad", 6.0)
	var q := point - (body.position + Vector2(pad, pad - scroll))
	for hit: Array in _hits:
		if (hit[0] as Rect2).has_point(q):
			if str(hit[1]) != "search_focus":
				host.search(false)
			if not bool(hit[3]):
				host.act(str(hit[1]), hit[2])
			return
	host.search(false)


func _process(_delta: float) -> void:
	_fit()
	visible = not host.hidden_now()
	queue_redraw()


func _arrow(at: Vector2, up: bool, tint: Color) -> void:
	var s := 4.0
	var pts := PackedVector2Array([at + Vector2(-s, -s * 0.5), at + Vector2(s, -s * 0.5), at + Vector2(0, s * 0.6)]) if not up \
		else PackedVector2Array([at + Vector2(-s, s * 0.5), at + Vector2(s, s * 0.5), at + Vector2(0, -s * 0.6)])
	draw_colored_polygon(pts, tint)


func _label(at: Vector2, text: String, tint: Color) -> void:
	HudStyle.text(self, FONT, at, text, _fs(), tint)


## A button box (option, HELD, RESET): filled when on, outlined in the accent when hovered or on.
func _button(r: Rect2, label: String, on: bool, off: bool, over: bool) -> void:
	var accent := HudStyle.color("accent")
	var dim := HudStyle.color("text_dim")
	draw_rect(r, Color(accent, 0.35) if on else Color(0, 0, 0, 0.28))
	draw_rect(r, Color(accent, 0.9) if (over and not off) or on else Color(dim, 0.4), false, 1.0)
	var lw := HudStyle.width(FONT, label, _fs())
	_label(Vector2(r.get_center().x - lw / 2.0, r.get_center().y + _fs() * 0.35), label, Color(dim, 0.4) if off else HudStyle.color("text"))


func _draw() -> void:
	var fs := _fs()
	var ink := HudStyle.color("text")
	var dim := HudStyle.color("text_dim")
	var accent := HudStyle.color("accent")
	var mouse := get_local_mouse_position()
	var chip := chip_rect()
	var hot := chip.has_point(mouse)
	HudStyle.panel(self, chip, 1.0)
	if hot or is_open():
		draw_rect(chip, Color(accent, 0.8), false, 1.0)
	var title := str(host.cfg.texts.chip)
	var tw := HudStyle.width(FONT, title, fs)
	var mid := chip.get_center()
	_label(Vector2(mid.x - tw / 2.0 - 6.0, mid.y + fs * 0.35), title, ink if hot or is_open() else dim)
	_arrow(Vector2(chip.end.x - 12.0, mid.y), is_open(), accent if hot or is_open() else dim)
	if not is_open():
		return
	var body := body_rect()
	HudStyle.panel(self, body, 0.96)
	var pad := _p("pad", 6.0)
	var origin := body.position + Vector2(pad, pad - scroll)
	var top := body.position.y + 2.0
	var bottom := body.end.y - 2.0
	var line := _line_h()
	var w := body.size.x - pad * 2.0
	var local := mouse - origin
	if origin.y >= top:
		_label(origin + Vector2(0, line * 0.5 + fs * 0.35), str(host.stat), accent)
	for row: Dictionary in items:
		var ry := origin.y + float(row.y)
		if ry < top or ry + float(row.h) > bottom:
			continue
		match str(row.kind):
			"head":
				var hr := Rect2(origin.x, ry, w, float(row.h))
				draw_rect(hr, Color(accent, 0.22 if hr.has_point(mouse) else 0.12))
				_arrow(Vector2(hr.position.x + 6.0, hr.get_center().y), not bool(row.open), accent)
				_label(Vector2(hr.position.x + 16.0, hr.get_center().y + fs * 0.35), str(row.label), accent)
			"item":
				var ir := Rect2(origin.x, ry, float(row.right), line)
				var off := bool(row.off)
				if bool(row.on):
					draw_rect(ir, Color(accent, 0.3))
				elif ir.has_point(mouse) and not off:
					draw_rect(ir, Color(ink, 0.08))
				var tint := Color(dim, 0.45) if off else (ink if bool(row.on) or ir.has_point(mouse) else Color(ink, 0.85))
				_label(Vector2(ir.position.x + 4.0, ir.get_center().y + fs * 0.35), str(row.label), tint)
				var note := str(row.get("note", ""))
				if note != "":
					var nw := HudStyle.width(FONT, note, fs)
					_label(Vector2(ir.end.x - nw - 4.0, ir.get_center().y + fs * 0.35), note, Color(dim, 0.45 if off else 0.9))
				if row.has("btn"):
					var b: Dictionary = row.btn
					var br: Rect2 = row.btn_rect
					var boff := bool(b.get("off", false))
					_button(Rect2(origin + br.position, br.size), str(b.label), false, boff, br.has_point(local))
			"live":
				var ly := ry + line * 0.5 + fs * 0.35
				for t: Variant in host.live_lines(str(row.key)):
					_label(Vector2(origin.x, ly), str(t), ink if ly < ry + line else dim)
					ly += float(fs) + 6.0
				var lr: Rect2 = row.btn_rect
				_button(Rect2(origin + lr.position, lr.size), str(row.btn.label), false, false, lr.has_point(local))
			"search":
				var sb: Rect2 = row.box
				var box := Rect2(origin + sb.position, sb.size)
				var focus := bool(host.search_on)
				draw_rect(box, Color(0, 0, 0, 0.4))
				draw_rect(box, Color(accent, 0.95) if focus else (Color(accent, 0.6) if sb.has_point(local) else Color(dim, 0.5)), false, 1.0)
				var text := str(host.opts().get("filter", ""))
				var shown := text if text != "" else ("" if focus else str(host.cfg.texts.search))
				var tx := box.position.x + 6.0
				var ty := box.get_center().y + fs * 0.35
				_label(Vector2(tx, ty), shown, ink if text != "" else Color(dim, 0.8))
				if focus and int(float(Time.get_ticks_msec()) / 500.0) % 2 == 0:
					var cx := tx + HudStyle.width(FONT, text, fs) + 1.0
					draw_rect(Rect2(cx, box.get_center().y - fs * 0.6, 2.0, fs * 1.2), accent)
				var cr: Rect2 = row.clear
				_button(Rect2(origin + cr.position, cr.size), "X", false, text == "", cr.has_point(local))
			"text":
				var tyy := ry + fs + 1.0
				var ttint := accent if bool(row.get("group", false)) else dim
				for t: String in row.lines:
					_label(Vector2(origin.x, tyy), t, ttint)
					tyy += fs + 3.0
			"opts":
				if str(row.label) != "":
					_label(Vector2(origin.x, ry + fs + 1.0), str(row.label), dim)
				for i in range((row.opts as Array).size()):
					var o: Dictionary = row.opts[i]
					var bx: Rect2 = row.boxes[i]
					_button(Rect2(origin + bx.position, bx.size), str(o.label), bool(o.on), bool(o.off), bx.has_point(local))
