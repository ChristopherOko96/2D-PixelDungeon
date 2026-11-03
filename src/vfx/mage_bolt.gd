extends RefCounted
## The mage's left-click follows his element (assets/data/mage_bolts.json):
## fire is the small fireball that bursts where it strikes (pyro, user wish
## 30.10.2026); frost an icicle from the staff, long and sharp, point first, its
## chill slowing what it strikes a little, shattering into ice splinters that fly
## on and skitter and a small frost patch that settles; void a small dark-violet
## orb that draws small enemies in as it passes and implodes where it strikes
## (its matter rushes in from a ring into one dark speck, violet traces settle);
## before any talent a plain arcane bolt (magic, the crypt look). Element physics:
## every bolt ends as the matter of its element. Wired in src/hell/hell_game.gd:
## _attack (arm), the shot update (fly, burst) and the shot drawing (draw, glow).

const PATH := "res://assets/data/mage_bolts.json"
const HeroKit = preload("res://src/hell/hero_kit.gd")
const ElementSkin = preload("res://src/hero/element_skin.gd")
const OUTLINE := Color("1c1117")
## The art grid in world px and its beat (the pixel shots' LASER_PX, LASER_FPS).
const PX := 3.0
const FPS := 12.0
const KINDS := ["icicle", "void_orb"]

static var _data: Dictionary = {}


## The bolts file, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"bolts": {"fire": {"kind": "pyro"}, "none": {"kind": "magic"}}}
	return _data


## The rules of element `element`'s bolt ("" -> the plain arcane bolt).
static func spec(element: String) -> Dictionary:
	var bolts: Dictionary = data().get("bolts", {})
	return bolts.get(element if element != "" else "none", bolts.get("none", {"kind": "magic"}))


## The mage's element now: "fire", "ice", "void" or "" before any talent. The
## build he plays with leads (the runtime talent ranks, read as
## hell_game._void_mind reads them), else his saved profile's main spec
## (src/hero/element_skin.gd). A probe or test may set it as the game's meta
## "mage_element".
static func element(g: Node) -> String:
	if g.has_meta("mage_element"):
		return str(g.get_meta("mage_element"))
	var lead := ""
	var talents: Variant = g.get("talents")
	if talents != null and talents.get("tc") != null:
		var ranks: Dictionary = talents.tc.runtime(1).get("ranks", {})
		var points := {}
		for talent: String in ranks:
			var own := talent.get_slice("_", 0)
			points[own] = int(points.get(own, 0)) + int(ranks[talent])
		var best := 0
		for own: String in points:
			if int(points[own]) > best:
				best = int(points[own])
				lead = own
	if lead.is_empty():
		var profile: Variant = g.get("profile")
		lead = ElementSkin.main_spec(profile if profile is Dictionary else {}, str(g.get("class_id")))
	return ElementSkin.element_of(lead)


## Gives the mage's shot `s` (hell_game._attack builds it from his weapon) his
## element's bolt: its kind, speed, splash and the bolt's own rules; sounds its cast.
static func arm(g: Node, s: Dictionary, element_override: Variant = null) -> void:
	var el: String=element(g) if element_override==null else str(element_override)
	var b := spec(el)
	s.kind = str(b.get("kind", "magic"))
	s.element = el
	s.v = (s.v as Vector2) * float(b.get("speed_mult", 1.0))
	s.splash = float(s.get("splash", 0.0)) * float(b.get("splash_mult", 1.0))
	if b.has("slow"):
		s.slow = float(b.slow)
		s.slow_time = float(b.get("slow_time", 0.8))
	s.seed = randf() * 9.0
	_cue(g, str(b.get("cast_sfx", "")), s.p)


## How far the mage's shot flies before it bursts on the floor (user wish 02.11.2026):
## `wanted` (to the mouse) held between land.min_px and `flight` (its whole flight).
static func land_reach(wanted: float, flight: float) -> float:
	var near := float(data().get("land", {}).get("min_px", 24.0))
	return clampf(wanted, minf(near, flight), flight)


## Shot `s` bursts `dist` px along its flight, on the floor there (hell_game _update_shots
## counts `left` down and stops it at `land`), unless an enemy or a wall stops it first.
static func aim(s: Dictionary, dist: float) -> void:
	s.left = dist
	s.land = (s.p as Vector2) + (s.v as Vector2).normalized() * dist


## While shot `s` flies: the orb draws the small enemies near it in a little
## (never a boss) and sheds violet motes spiralling back into it; the icicle
## sheds frost glints.
static func fly(g: Node, s: Dictionary, dt: float) -> void:
	var kind := str(s.get("kind", ""))
	if not kind in KINDS:
		return
	var b := spec(str(s.get("element", "")))
	if kind == "void_orb":
		var reach := float(b.get("pull_radius", 110.0))
		for m: Dictionary in g.mobs:
			if float(m.get("spawn", 0.0)) > 0.0 or m.has("kit") or bool(m.get("boss", false)) or str(m.get("kind", "")) == "boss":
				continue
			var to: Vector2 = (s.p as Vector2) + Vector2(0, float(m.get("cy", 40.0))) - (m.p as Vector2)
			var d := to.length()
			if d > 10.0 and d < reach:
				var step := to / d * float(b.get("pull", 120.0)) * (1.0 - d / reach) * dt
				var r := float(m.get("r", 24.0))
				var feet: Vector2 = m.p
				if not g.box_blocked(Rect2(feet.x + step.x - r * 0.7, feet.y + step.y - r * 0.7, r * 1.4, r * 0.7), true):
					m.p = feet + step
	s.mote = float(s.get("mote", 0.0)) + dt
	if float(s.mote) < 0.05:
		return
	s.mote = 0.0
	var P := _particles(g)
	if P.is_empty():
		return
	var cols := _cols(b)
	var sc: float = P.scale
	var back := -(s.v as Vector2).normalized()
	if kind == "void_orb":
		var off := Vector2.from_angle(randf() * TAU) * 14.0
		P.p.emit(((s.p as Vector2) + off) / sc, (-off * 3.0 + back * 30.0) / sc, cols[1 + randi() % 2], 0.3, "ember", 2.0, 6.0, 0.0, 1.5)
	else:
		P.p.emit((s.p as Vector2) / sc, (back * 40.0 + Vector2(randf_range(-15.0, 15.0), randf_range(-10.0, 10.0))) / sc, cols[randi() % 2], 0.35, "spark", 2.0, 6.0, 5.0 / sc, 3.0)


## Shot `s` ended on enemy `m` ({}: on a wall, or on the floor at the mouse's
## point when `on_floor`). The icicle's chill slows `m` a little; it shatters into
## ice splinters (flying on through an enemy and over the floor, back off a wall)
## and a small frost patch settles below. The orb implodes: violet matter rushes
## in from a ring into one dark speck, traces settle on the floor. Any other
## shot: nothing.
static func burst(g: Node, s: Dictionary, m: Dictionary, on_floor := false) -> void:
	var kind := str(s.get("kind", ""))
	if not kind in KINDS:
		return
	var b := spec(str(s.get("element", "")))
	if not m.is_empty() and s.has("slow") and float(m.get("hp", 0.0)) > 0.0:
		HeroKit.slow_mob(g, m, float(s.slow), float(s.get("slow_time", 0.8)))
	_cue(g, str(b.get("wall_sfx" if m.is_empty() and not on_floor else "hit_sfx", "")), s.p)
	var at: Vector2 = s.p
	var dir := (s.v as Vector2).normalized()
	var out_dir := dir if not m.is_empty() or on_floor else -dir
	if kind == "icicle" and g.get("frost_fx") != null:
		g.frost_fx.shatter(at, 4, 8.0, out_dir, 110.0)
	var P := _particles(g)
	if P.is_empty():
		return
	var sc: float = P.scale
	# the mouse's point is a floor point: the patch and traces settle right there
	var ground := at if on_floor else at + Vector2(0, 34)
	var cols := _cols(b)
	if kind == "icicle":
		for k in range(int(b.get("splinters", 7))):
			var out := out_dir.rotated(randf_range(-1.1, 1.1))
			P.p.emit(at / sc, Vector2(out.x, out.y * 0.62) * randf_range(60.0, 180.0) / sc, cols[1 + randi() % 3], randf_range(1.0, 1.8), "shard", 2.0, randf_range(6.0, 14.0) / sc, randf_range(30.0, 90.0) / sc, 1.0)
		P.p.emit(at / sc, Vector2.ZERO, cols[0], 0.1, "spark", 4.0, 8.0 / sc, 0.0, 6.0)
		P.p.frost(ground / sc, float(b.get("patch_r", 20.0)) / sc, int(b.get("patch_n", 6)), Color(0.8, 0.95, 1.0, 0.55))
		return
	var R := float(b.get("implode_r", 42.0))
	var n := int(b.get("implode_n", 12))
	for k in range(n):
		var a := float(k) / float(n) * TAU + randf() * 0.3
		var from := at + Vector2(cos(a), sin(a) * 0.62) * R
		var life := randf_range(0.16, 0.24)
		P.p.emit(from / sc, (at - from) / life / sc, cols[k % 3], life, "spark", 2.0, 12.0 / sc, 0.0, 0.0)
	P.p.emit(at / sc, Vector2.ZERO, cols[3], 0.35, "spark", 5.0, 12.0 / sc, 0.0, 6.0)
	P.p.scatter(ground / sc, Color((cols[3] as Color).lightened(0.15), 0.55), 14.0 / sc, int(b.get("traces", 4)))
	for k in range(2):
		P.p.emit((ground + Vector2(randf_range(-10.0, 10.0), 0.0)) / sc, Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 6.0)) / sc, cols[1 + randi() % 2], randf_range(0.8, 1.4), "ember", 2.0, 2.0, randf_range(10.0, 30.0) / sc, 1.0)


## The icicle or orb `s` burst on the floor: its frost or void touches what lies
## within its touch_r (src/hell/story_elements.gd: water freezes, steam falls, the
## void eats puddles and gas). The fireball's fire does it in its explosion.
static func touch(g: Node, s: Dictionary) -> void:
	var kind := str(s.get("kind", ""))
	if not kind in KINDS:
		return
	var talents: Variant = g.get("talents")
	var reactions: Variant = talents.get("elements") if talents != null else null
	if reactions == null:
		return
	var r := float(spec(str(s.get("element", ""))).get("touch_r", 20.0))
	if kind == "icicle":
		reactions.frost_at(s.p, r, 1)
	elif reactions.has_method("void_at"):
		reactions.void_at(s.p, r, 1)


## The small mark where the mage's shot will burst (user wish 02.11.2026): four
## short arms on the 3 px grid round an open centre (the exact point stays
## visible), outlined, in his element's colours (mark_colors, else the bolt's);
## it breathes softly in alpha on an eased cosine, never blinking.
static func draw_mark(l: CanvasItem, at: Vector2, el: String, t: float) -> void:
	var m: Dictionary = data().get("mark", {})
	var b := spec(el)
	var cols := _cols({"colors": b.get("mark_colors", b.get("colors", ["ffffff", "d0c4ff", "8f6bd8", "3a2470"]))})
	var arm := int(m.get("arm", 2))
	var gap := int(m.get("gap", 1))
	var a: Array = m.get("alpha", [0.55, 0.9])
	var breath := 0.5 - 0.5 * cos(t * TAU / maxf(0.1, float(m.get("period", 1.4))))
	var c := Vector2i((at / PX).floor())
	var cells := {}
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		for k in range(gap, gap + arm):
			cells[c + d * k] = cols[0] if k == gap else cols[1]
	_flush(l, cells, lerpf(float(a[0]), float(a[1]), breath))


## Draws the mage's icicle or orb `s` on the 3 px grid (true); false for other shots.
static func draw(l: CanvasItem, s: Dictionary, t: float) -> bool:
	match str(s.get("kind", "")):
		"icicle":
			_draw_icicle(l, s, t)
			return true
		"void_orb":
			_draw_orb(l, s, t)
			return true
	return false


## The icicle's or orb's soft glow on the world's glow layer (true); false for other shots.
static func glow(l: CanvasItem, s: Dictionary) -> bool:
	var kind := str(s.get("kind", ""))
	if not kind in KINDS:
		return false
	var g0: Array = spec(str(s.get("element", ""))).get("glow", ["ffffff", 0.25])
	l.draw_circle(s.p, 22.0 if kind == "void_orb" else 18.0, Color(Color(str(g0[0])), float(g0[1])))
	return true


## An icicle point first: a white ridge, its upper flank lit and lower shaded,
## a needle at the front, a broken stub at the back, a glint running along it.
static func _draw_icicle(l: CanvasItem, s: Dictionary, t: float) -> void:
	var b := spec(str(s.get("element", "ice")))
	var cols := _cols(b)
	var v: Vector2 = s.get("v", Vector2.ZERO)
	var dir := v.normalized() if v.length() > 1.0 else Vector2.RIGHT
	var side := dir.orthogonal()
	if side.y > 0.0:
		side = -side
	var p: Vector2 = s.p
	var n := int(b.get("len", 6))
	var cells := {}
	for i in range(-n, 3):
		var w := 1 if i > -n + 1 and i < 0 else 0
		for o in range(-w, w + 1):
			var q := Vector2i(((p + (dir * float(i) + side * float(o)) * PX) / PX).floor())
			var c: Color = cols[2] if i <= -n + 1 else cols[0]
			if o > 0:
				c = cols[1]
			elif o < 0:
				c = cols[3]
			cells[q] = c
	var glint := -posmod(int(floorf(t * FPS)) + int(float(s.get("seed", 0.0))), n)
	cells[Vector2i(((p + dir * float(glint) * PX) / PX).floor())] = Color.WHITE
	_flush(l, cells)


## A small orb of void: a near-black core, a violet rim with a glint crawling
## round it, motes orbiting just outside it (drawn in by it).
static func _draw_orb(l: CanvasItem, s: Dictionary, t: float) -> void:
	var b := spec(str(s.get("element", "void")))
	var cols := _cols(b)
	var r := int(b.get("r", 3))
	var c := Vector2i(((s.p as Vector2) / PX).floor())
	var cells := {}
	var tq := floorf(t * FPS)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d2 := x * x + y * y
			if d2 > r * r + 1:
				continue
			cells[c + Vector2i(x, y)] = cols[2] if d2 >= r * r - 1 else cols[3]
	var a := tq * 0.9 + float(s.get("seed", 0.0))
	cells[c + Vector2i((Vector2(cos(a), sin(a)) * float(r)).round())] = cols[0]
	cells[c + Vector2i((Vector2(cos(a + PI), sin(a + PI)) * float(r)).round())] = cols[1]
	_flush(l, cells)
	for k in range(3):
		var ak := -a * 1.3 + float(k) * TAU / 3.0
		var rr := float(r) + 1.5 + float(posmod(int(tq) + k, 3)) * 0.6
		var q := Vector2i((Vector2(c) + Vector2(cos(ak), sin(ak)) * rr).floor())
		l.draw_rect(Rect2(Vector2(q) * PX, Vector2.ONE * PX), cols[1 if k == 0 else 2])


## Grid cells (Vector2i -> Color) drawn with the outline round them, opaque
## unless `alpha` says otherwise.
static func _flush(l: CanvasItem, cells: Dictionary, alpha := 1.0) -> void:
	var line := Color(OUTLINE, alpha)
	for q: Vector2i in cells:
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not cells.has(q + d):
				l.draw_rect(Rect2(Vector2(q + d) * PX, Vector2.ONE * PX), line)
	for q: Vector2i in cells:
		l.draw_rect(Rect2(Vector2(q) * PX, Vector2.ONE * PX), Color(cells[q] as Color, alpha))


## The bolt's colours lit to shade.
static func _cols(b: Dictionary) -> Array:
	var out: Array = []
	for hex: Variant in b.get("colors", ["ffffff", "d0c4ff", "8f6bd8", "3a2470"]):
		out.append(Color(str(hex)))
	while out.size() < 4:
		out.append(out[out.size() - 1] if not out.is_empty() else Color.WHITE)
	return out


## The crypt's pixel physics of the feel ({p, scale}), {} without the feel.
static func _particles(g: Node) -> Dictionary:
	var feel: Variant = g.get("feel")
	if feel == null or feel.get("feedback") == null or feel.feedback.get("particles") == null:
		return {}
	return {"p": feel.feedback.particles, "scale": maxf(0.1, float(feel.scale))}


static func _cue(g: Node, cue_name: String, at: Vector2) -> void:
	var sound: Variant = g.get("sound")
	if cue_name != "" and sound != null:
		sound.at(cue_name, at)
