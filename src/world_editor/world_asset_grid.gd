extends Control
## The Weltbauer's list of parts: pictures in a grid, already moving (numbered frames, film strips,
## fires, fountains), loaded only when they scroll into view. A click picks a part.

signal picked(entry: Dictionary)
signal hovered(text: String)

const Terrain = preload("res://src/world_editor/world_terrain.gd")
const Canvas = preload("res://src/world_editor/world_room_canvas.gd")
const THUMB := 84.0
const GAP := 6.0
const LABEL := 16.0

var art: RefCounted
var entries: Array = []
var current: Dictionary = {}
var scroll: ScrollContainer
var _hover := -1
var _time := 0.0
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _process(delta: float) -> void:
	_time += delta
	_clock += delta
	if art != null:
		art.flush(24)
	if _clock >= 1.0 / 12.0:
		_clock = 0.0
		queue_redraw()


## Shows `list`, drawn with `pictures`.
func show_entries(list: Array, pictures: RefCounted) -> void:
	entries = list
	art = pictures
	current = {}
	_hover = -1
	_layout()
	queue_redraw()


func _columns() -> int:
	return maxi(1, int((maxf(size.x, 200.0) + GAP) / (THUMB + GAP)))


func _layout() -> void:
	var rows := ceili(float(entries.size()) / _columns())
	custom_minimum_size.y = rows * (THUMB + LABEL + GAP)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _slot(i: int) -> Rect2:
	var columns := _columns()
	return Rect2(Vector2((i % columns) * (THUMB + GAP), (i / columns) * (THUMB + LABEL + GAP)), Vector2(THUMB, THUMB))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _index_at((event as InputEventMouseMotion).position)
		if i != _hover:
			_hover = i
			hovered.emit(_describe(entries[i]) if i >= 0 else "")
			queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var i := _index_at((event as InputEventMouseButton).position)
		if i >= 0:
			_prepare(entries[i])
			current = entries[i]
			picked.emit(entries[i])
			queue_redraw()


func _describe(e: Dictionary) -> String:
	var text := str(e.label)
	if e.has("frames"):
		text += " · %d Bilder" % (e.frames as Array).size()
	if e.has("folder"):
		text += " · " + str(e.folder)
	return text


func _index_at(p: Vector2) -> int:
	var columns := _columns()
	var x := int(p.x / (THUMB + GAP))
	var y := int(p.y / (THUMB + LABEL + GAP))
	if x < 0 or x >= columns or y < 0 or p.x - x * (THUMB + GAP) > THUMB:
		return -1
	var i := y * columns + x
	return i if i < entries.size() else -1


## A wide picture in an effects folder is a film strip: its pictures become the part's frames.
func _prepare(e: Dictionary) -> void:
	if not e.has("maybe_strip"):
		return
	e.erase("maybe_strip")
	var t: Texture2D = art.picture(str(e.asset))
	if t == null:
		e.maybe_strip = true
		return
	if t.get_height() == 0:
		return
	var n := t.get_width() / t.get_height()
	if n >= 3 and n <= 64 and t.get_width() % t.get_height() == 0:
		var frames: Array = []
		for k in range(n):
			frames.append("%s#%d/%d" % [str(e.asset), k, n])
		e.frames = frames
		e.fps = 12.0
		e.strip = true


func _draw() -> void:
	if art == null:
		return
	var first := 0
	var last := entries.size()
	if scroll != null:
		var columns := _columns()
		var row_h := THUMB + LABEL + GAP
		first = maxi(0, int(scroll.scroll_vertical / row_h) * columns)
		last = mini(entries.size(), first + (int(scroll.size.y / row_h) + 2) * columns)
	var font := get_theme_default_font()
	var cfg := Terrain.config()
	for i in range(first, last):
		var e: Dictionary = entries[i]
		var r := _slot(i)
		draw_rect(r, Color("1c1e27"))
		_prepare(e)
		_draw_entry(e, r, cfg)
		var line: Color = Color("ffe08a") if is_same(e, current) else (Color("9aa4c0") if i == _hover else Color("343746"))
		draw_rect(r, line, false, 2.0)
		if e.has("frames"):
			draw_circle(r.position + Vector2(9, 9), 4.0, Color("7fe08a"))
		draw_string(font, r.position + Vector2(0, THUMB + 12.0), str(e.label), HORIZONTAL_ALIGNMENT_LEFT, THUMB, 11, Color("b8bfd2"))


func _draw_entry(e: Dictionary, r: Rect2, cfg: Dictionary) -> void:
	var kind := str(e.get("kind", "prop"))
	var box := r.grow(-4.0)
	if kind == "launch":
		draw_set_transform(r.get_center(), 0.0, Vector2.ONE * 0.8)
		Terrain.draw_pad(self, Vector2.ZERO, "n", _time, 0.0, art.tex.get("rune_plate"), cfg.pad)
		draw_set_transform(Vector2.ZERO)
		return
	if kind == "pit":
		draw_rect(box, Color("07060a"))
		draw_rect(Rect2(box.position, Vector2(box.size.x, 14.0)), Color("1b1820"))
		draw_rect(box, Color("4a4348"), false, 3.0)
		return
	if kind == "start":
		draw_arc(r.get_center(), 26.0, 0.0, TAU, 24, Color("7fe08a"), 3.0)
		_fit(art.picture("@res://assets/sprites/0x72/knight_m_idle_anim_f%d.png" % (int(_time * 6.0) % 4)), box, Rect2())
		return
	if kind == "enemy":
		var look: Dictionary = Canvas.enemy_look_in(art, str(e.mob))
		if look.has("frames"):
			_fit(art.picture(str((look.frames as Array)[int(_time * 6.0) % (look.frames as Array).size()])), box, Rect2())
		elif look.has("sheet"):
			var f := int(_time * 6.0) % int(look.count)
			var px := float(look.get("px", 1.0))
			_fit(art.picture(str(look.sheet)), box, Rect2(f * float(look.w) * px, 0.0, float(look.w) * px, float(look.h) * px))
		else:
			draw_circle(r.get_center(), 20.0, Color("a33a30"))
		return
	var name := str(e.get("asset", e.get("preview", "")))
	if e.has("frames"):
		name = str((e.frames as Array)[int(_time * float(e.get("fps", 8.0))) % (e.frames as Array).size()])
	var t: Texture2D = art.moving(name, r.position, _time)
	_fit(t, box, Rect2())


func _fit(t: Texture2D, box: Rect2, region: Rect2) -> void:
	if t == null:
		return
	var src := region.size if region.size != Vector2.ZERO else t.get_size()
	var s := minf(box.size.x / src.x, box.size.y / src.y)
	s = minf(s, 3.0)
	var shown := src * s
	var at := box.position + (box.size - shown) * 0.5
	if region.size != Vector2.ZERO:
		draw_texture_rect_region(t, Rect2(at, shown), region)
	else:
		draw_texture_rect(t, Rect2(at, shown), false)
