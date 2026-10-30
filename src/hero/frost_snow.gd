extends RefCounted
## Snow underfoot in a snowy world (theme "snow", the Frostgruft; src/hell/hell_game.gd):
## - footprints: the hero and every walking monster leave prints on the floor's snow fields (the
##   world kit's snow_* decals, src/world_kit/world_pack.gd _winter); a print sits beside the
##   track, left and right in turn, turned along the walk, and fades after `life` s;
## - sliding: on glaze ice (grid cell 2 with theme liquid.slide) the hero slides instead of walking:
##   the legs stop, the body leans into the slide (slide_lean), the boots scratch pale skid marks
##   into the ice and ice chips spray up behind.
## Presentation only: the world's rules stay in hell_game.gd.

## theme "snow" keys of the same name override these: stride = px walked per print, life = s a
## print stays, max = prints kept at once, color = the prints' colour, skid_speed = px/s from which
## a slide scratches the ice, lean = rad the hero leans at full slide speed.
const DEFAULTS := {"stride": 28.0, "life": 9.0, "max": 520, "color": "#4a6a9c", "skid_speed": 90.0, "lean": 0.22}

var g: Node
var cfg: Dictionary = DEFAULTS.duplicate(true)
## Cells (index y * cols + x) under a snow field.
var snow: Dictionary = {}
## Prints and skid marks: {p, ang, side, t, kind ("boot", "paw", "skid"), size}.
var prints: Array = []
## Ice chips in the air: {p, v, t}.
var chips: Array = []
var _hero_last := Vector2.INF
var _hero_side := 1.0


func _init(game: Node, theme_block: Dictionary) -> void:
	g = game
	for k: String in theme_block:
		if DEFAULTS.has(k):
			cfg[k] = theme_block[k]


## A new floor: its snow fields, no prints yet.
func reset() -> void:
	snow = {}
	prints = []
	chips = []
	_hero_last = Vector2.INF
	var C: float = g.C
	var cols: int = g.W.cols
	for d: Dictionary in g.W.decals:
		if str(d.name).begins_with("snow_"):
			snow[int(floor(float(d.y) / C)) * cols + int(floor(float(d.x) / C))] = true


## True when world point p lies on a snow field.
func on_snow(p: Vector2) -> bool:
	var C: float = g.C
	return snow.has(int(floor(p.y / C)) * int(g.W.cols) + int(floor(p.x / C)))


## True while the hero slides on glaze ice.
func sliding() -> bool:
	if not bool(g.theme.liquid.get("slide", false)) or g.state.is_empty():
		return false
	var p := Vector2(g.player.x, g.player.y)
	return g._cell(int(floor(p.x / g.C)), int(floor((p.y - 10.0) / g.C))) == 2 and (g.player.vel as Vector2).length() > 30.0


## The hero's lean while sliding (rad, into the slide), 0 otherwise.
func slide_lean() -> float:
	if not sliding():
		return 0.0
	var v: Vector2 = g.player.vel
	return clampf(v.x / 360.0, -1.0, 1.0) * float(cfg.lean)


func update(dt: float) -> void:
	for f: Dictionary in prints:
		f.t += dt
	prints = prints.filter(func(f: Dictionary) -> bool: return f.t < float(cfg.life))
	for c: Dictionary in chips:
		c.t += dt
		c.v += Vector2(0, 520) * dt
		c.p += c.v * dt
	chips = chips.filter(func(c: Dictionary) -> bool: return c.t < 0.5)
	if g.state.is_empty() or float(g.state.get("dead", 0.0)) > 0.0:
		return
	var hero := Vector2(g.player.x, g.player.y)
	if sliding():
		var v: Vector2 = g.player.vel
		if v.length() > float(cfg.skid_speed):
			_add({"p": hero, "ang": v.angle(), "side": 0.0, "t": 0.0, "kind": "skid", "size": 1.0})
			if randf() < 0.6:
				chips.append({"p": hero + Vector2(randf_range(-10, 10), -4), "v": -v.normalized() * randf_range(40, 120) + Vector2(randf_range(-40, 40), randf_range(-200, -90)), "t": 0.0})
		_hero_last = hero
	elif _hero_last == Vector2.INF or hero.distance_to(_hero_last) > 200.0:
		_hero_last = hero
	elif hero.distance_to(_hero_last) >= float(cfg.stride):
		if on_snow(hero):
			_hero_side = -_hero_side
			_add({"p": hero, "ang": (hero - _hero_last).angle(), "side": _hero_side, "t": 0.0, "kind": "boot", "size": 1.0})
		_hero_last = hero
	for m: Dictionary in g.mobs:
		if float(m.get("spawn", 0.0)) > 0.0 or float(m.get("alt", 0.0)) > 0.0 or m.get("fly", false):
			continue
		var p: Vector2 = m.p
		var last: Variant = m.get("fp")
		if last == null or p.distance_to(last) > 240.0:
			m.fp = p
			continue
		var r := float(m.get("r", 24.0))
		if p.distance_to(last) >= maxf(18.0, r * 0.9):
			if on_snow(p):
				m.fp_side = -float(m.get("fp_side", 1.0))
				_add({"p": p, "ang": (p - (last as Vector2)).angle(), "side": m.fp_side, "t": 0.0, "kind": "paw", "size": clampf(r / 26.0, 0.7, 1.8)})
			m.fp = p


func _add(f: Dictionary) -> void:
	prints.append(f)
	if prints.size() > int(cfg.max):
		prints.pop_front()


## Prints and skid marks on the floor (under the actors).
func draw_floor(l: CanvasItem, view: Rect2) -> void:
	var base := Color(str(cfg.color))
	var life := float(cfg.life)
	for f: Dictionary in prints:
		var p: Vector2 = f.p
		if not view.has_point(p):
			continue
		var fade := 1.0 - pow(float(f.t) / life, 2.0)
		var ang: float = f.ang
		var across := Vector2.from_angle(ang + PI / 2.0)
		match str(f.kind):
			"skid":
				l.draw_set_transform(p, ang)
				l.draw_rect(Rect2(-9, -2, 18, 2), Color(0.92, 0.97, 1.0, 0.5 * fade))
				l.draw_rect(Rect2(-7, 1, 14, 1), Color(0.55, 0.72, 0.95, 0.35 * fade))
			"boot":
				l.draw_set_transform(p + across * 7.0 * float(f.side) + Vector2(0, -2), ang)
				_oval(l, Vector2(3, 0), Vector2(9, 5), Color(base, 0.7 * fade))
				_oval(l, Vector2(-8, 0), Vector2(5, 4.4), Color(base, 0.65 * fade))
			_:
				var s: float = f.size
				l.draw_set_transform(p + across * 9.0 * s * float(f.side), ang)
				_oval(l, Vector2.ZERO, Vector2(6, 5) * s, Color(base, 0.65 * fade))
				for k in [-1.0, 0.0, 1.0]:
					_oval(l, Vector2(6 * s, k * 4 * s), Vector2(1.8, 1.6) * s, Color(base, 0.45 * fade))
	l.draw_set_transform(Vector2.ZERO)


## Ice chips spraying up behind a slide (over the floor, with the actors).
func draw_chips(l: CanvasItem) -> void:
	for c: Dictionary in chips:
		var a := 1.0 - float(c.t) / 0.5
		l.draw_rect(Rect2(c.p - Vector2(2, 2), Vector2(4, 4)), Color(0.9, 0.97, 1.0, a))


func _oval(l: CanvasItem, at: Vector2, radius: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := TAU * i / 10.0
		pts.append(at + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	l.draw_colored_polygon(pts, col)
