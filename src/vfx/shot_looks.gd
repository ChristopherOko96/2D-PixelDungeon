extends RefCounted
## Enemy shots whose look is more than their element (assets/data/shot_looks.json):
## the Skelettschütze's and the Frost-Skelett's bone arrows. An arrow is drawn on
## the 3 px art grid along its flight: a cream bone shaft with knuckle joints, a
## plain iron head with two barbs, two small vanes of fletching, outlined like the
## other pixel shots. Where it strikes, a few bone splinters fly back off the head,
## fall and stay, a little dust puffs up and the iron tip sparks once; the
## Frostgruft's arrow is rimed and leaves rime and a few ice chips (element
## physics: it ends as matter). Used by src/hell/hell_monsters.gd (Krypta, Hölle),
## src/hell/frost_moves.gd and src/hell/hell_game.gd (Frostgruft).

const PATH := "res://assets/data/shot_looks.json"
const OUTLINE := Color("1c1117")
const Pixel = preload("res://src/vfx/pixel_paint.gd")
## Beats per second of the vanes' flicker (the pixel shots' LASER_FPS).
const FPS := 12.0

static var _data: Dictionary = {}


## The looks file, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"monsters": {}, "looks": {}}
	return _data


## The look rule of the shots of monster `id` firing attack `attack`:
## {look, tint}, {} when its shots keep their element's own look.
static func look_for(id: String, attack := "") -> Dictionary:
	var rule: Variant = (data().get("monsters", {}) as Dictionary).get(id)
	if not rule is Dictionary:
		return {}
	var only: Array = (rule as Dictionary).get("attacks", [])
	if not only.is_empty() and not attack in only:
		return {}
	return {"look": str(rule.get("look", "")), "tint": str(rule.get("tint", ""))}


## Gives enemy shot `s` the look `rule` (from look_for); nothing for an empty
## rule or a shot that has a look of its own already.
static func apply(s: Dictionary, rule: Dictionary) -> void:
	if str(rule.get("look", "")) == "" or s.has("look"):
		return
	s.look = rule.look
	if str(rule.get("tint", "")) != "":
		s.tint = rule.tint


## Gives enemy shot `s` the look of monster `id` (attack `attack`).
static func tag(s: Dictionary, id: String, attack := "") -> void:
	apply(s, look_for(id, attack))


## True for a bone arrow.
static func is_arrow(s: Dictionary) -> bool:
	return str(s.get("look", "")) == "arrow"


## Two high-contrast brackets frame the shot without obscuring its own sprite.
## Their opening points forward, including on ice and bright lava.
static func draw_hostile_cue(canvas: CanvasItem, point: Vector2, velocity: Vector2, extent: float, art: float) -> void:
	var forward := velocity.normalized() if velocity.length_squared() > 1.0 else Vector2.RIGHT
	var across := forward.orthogonal()
	var reach := maxf(extent, art * 2.0) + art * 2.0
	for side: float in [-1.0, 1.0]:
		var edge := point + across * reach * side
		var front := Pixel.at(edge + forward * art * 1.2, art)
		var back := Pixel.at(edge - forward * art, art)
		var tail := Pixel.at(edge - forward * art * 2.0 - across * art * side, art)
		for cell: Vector2i in [front, back, tail]:
			for offset: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
				Pixel.cell(canvas, cell + offset, OUTLINE, art)
		Pixel.cell(canvas, tail, Color("e87582"), art)
		Pixel.cell(canvas, back, Color("ff9d9c"), art)
		Pixel.cell(canvas, front, Color("fff2db"), art)


static func _arrow() -> Dictionary:
	return (data().get("looks", {}) as Dictionary).get("arrow", {})


## Colours of `list` (hex strings), `fallback` where the list is short.
static func _colors(list: Variant, fallback: Array) -> Array:
	var out: Array = []
	for i in range(fallback.size()):
		out.append(Color(str(list[i])) if list is Array and i < (list as Array).size() else fallback[i])
	return out


## The arrow's colours {shaft, head, fletch}, rimed for `frost`.
static func palette(frost: bool) -> Dictionary:
	var A := _arrow()
	var shaft := _colors(A.get("shaft"), [Color("fdf7ed"), Color("e8dcc8"), Color("c9b49a"), Color("8f7f70")])
	var head := _colors(A.get("frost_head" if frost else "head"), [Color("e9eef2"), Color("9aa3ad"), Color("5d6670")])
	var fletch := _colors(A.get("frost_fletch" if frost else "fletch"), [Color("c8443a"), Color("8a2b25")])
	if frost:
		var tint: Array = A.get("frost_shaft_tint", ["bfeaff", 0.3])
		for i in range(shaft.size()):
			shaft[i] = (shaft[i] as Color).lerp(Color(str(tint[0])), float(tint[1]))
	return {"shaft": shaft, "head": head, "fletch": fletch}


## Draws a bone arrow at `p` pointing along `vel` on the grid of `px` world px:
## shaft, iron head and fletching, outlined, its vanes flicking on the beat.
static func draw_arrow(l: CanvasItem, p: Vector2, vel: Vector2, t: float, px: float, frost := false) -> void:
	var A := _arrow()
	var cols := palette(frost)
	var bone: Array = cols.shaft
	var iron: Array = cols.head
	var vane: Array = cols.fletch
	var dir := vel.normalized() if vel.length() > 1.0 else Vector2.RIGHT
	var side := dir.orthogonal()
	if side.y > 0.0:
		side = -side
	var shaft := int(A.get("shaft_len", 7))
	var head := int(A.get("head_len", 2))
	var fletch := int(A.get("fletch_len", 2))
	var cells := {}
	var at := func(along: float, across: float) -> Vector2i:
		return Vector2i(((p + (dir * along + side * across) * px) / px).floor())
	# the shaft: bone, a knuckle joint every third cell, a knob at its butt
	for i in range(-shaft, 1):
		cells[at.call(float(i), 0.0)] = bone[2] if posmod(i, 3) == 0 else bone[1]
	cells[at.call(float(-shaft), 0.0)] = bone[0]
	cells[at.call(float(-shaft) - 1.0, 0.0)] = bone[3]
	# the iron head: a bright point and two barbs (lit above, shaded below)
	for i in range(1, head + 1):
		cells[at.call(float(i), 0.0)] = iron[0] if i == head else iron[1]
	cells[at.call(1.0, 1.0)] = iron[1]
	cells[at.call(1.0, -1.0)] = iron[2]
	# two small vanes at the butt, their trailing cells flicking on the beat
	var flick := int(floorf(t * FPS)) % 2
	for i in range(fletch):
		var along := float(-shaft + 1 + i)
		cells[at.call(along, 1.0)] = vane[0]
		cells[at.call(along, -1.0)] = vane[1]
		if i == 0 and flick == 0:
			cells[at.call(along - 1.0, 1.0)] = vane[1]
			cells[at.call(along - 1.0, -1.0)] = vane[1]
	_flush(l, cells, px)


## Grid cells (Vector2i -> Color) drawn opaque with the outline round them.
static func _flush(l: CanvasItem, cells: Dictionary, px: float) -> void:
	for q: Vector2i in cells:
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not cells.has(q + d):
				l.draw_rect(Rect2(Vector2(q + d) * px, Vector2.ONE * px), OUTLINE)
	for q: Vector2i in cells:
		l.draw_rect(Rect2(Vector2(q) * px, Vector2.ONE * px), cells[q])


## Bone arrow `s` struck at its point (a wall when `wall`, else the hero): bone
## splinters thrown back off the head that fall and stay, the tip's spark, a puff
## of dust; a rimed one leaves rime on the floor and chips of ice. With `cue` it
## also sounds (the Frostgruft; the crypt's shots sound on their own). False and
## nothing done for any other shot.
static func impact(g: Node, s: Dictionary, wall: bool, cue := true) -> bool:
	if not is_arrow(s):
		return false
	var I: Dictionary = _arrow().get("impact", {})
	var frost := str(s.get("tint", "")) == "frost"
	var at: Vector2 = s.p
	var v: Vector2 = s.get("v", Vector2.ZERO)
	var dir := v.normalized() if v.length() > 1.0 else Vector2.RIGHT
	var sound: Variant = g.get("sound")
	if cue and sound != null:
		var cue_name := str(I.get("sfx_wall" if wall else "sfx_hit", ""))
		if cue_name != "":
			sound.at(cue_name, at)
	if frost and g.get("frost_fx") != null:
		g.frost_fx.shatter(at, int(I.get("ice_chips", 3)), 6.0, -dir, 90.0)
	var feel: Variant = g.get("feel")
	if feel == null or feel.get("feedback") == null or feel.feedback.get("particles") == null:
		return true
	var P: Variant = feel.feedback.particles
	var sc := maxf(0.1, float(feel.scale))
	var bone: Array = palette(frost).shaft
	var ground := at + Vector2(0, 28)
	for k in range(int(I.get("splinters", 4))):
		var out := (-dir).rotated(randf_range(-1.3, 1.3))
		P.emit(at / sc, Vector2(out.x, out.y * 0.62) * randf_range(50.0, float(I.get("speed", 150.0))) / sc, bone[1 + randi() % 3],
			randf_range(1.6, 2.6), "debris", 2.0, randf_range(4.0, 12.0) / sc, randf_range(40.0, float(I.get("up", 140.0))) / sc, 2.5)
	# the iron tip sparks once
	P.emit(at / sc, -dir * 90.0 / sc, Color(1.0, 0.92, 0.72), 0.16, "spark", 2.0, 10.0 / sc, 20.0 / sc, 6.0)
	# a tiny puff of bone dust rising and fading, a trace of it on the floor
	for k in range(int(I.get("dust", 2))):
		P.emit(at / sc, Vector2(randf_range(-24.0, 24.0), randf_range(-12.0, 12.0)) / sc, Color(bone[2], 0.7), randf_range(0.4, 0.6), "ember", 2.0, 6.0, randf_range(10.0, 26.0) / sc, 1.5)
	P.scatter(ground / sc, Color(bone[3], 0.4), 10.0 / sc, 2)
	if frost:
		P.frost(ground / sc, 12.0 / sc, int(I.get("rime", 4)), Color(0.8, 0.95, 1.0, 0.55))
	return true
