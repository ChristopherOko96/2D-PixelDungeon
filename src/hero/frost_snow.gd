extends RefCounted
## Snow underfoot in a snowy world (theme "snow", the Frostgruft; src/hell/hell_game.gd):
## - footprints: the hero and every walking monster leave prints in the snow, which is every floor
##   cell except where fire melted it (the world kit's thaw_* patches, src/world_kit/world_pack.gd
##   _winter); a print sits beside the track, left and right in turn, turned along the walk, and
##   fades after `life` s;
## - object embedding: a flat contact depression lies below things standing in snow. Large props
##   carry a few snow cushions baked onto their true lower silhouette by snowfoot() in the asset
##   generator; tiny loose items get one small foreground accent. Floor plates get a narrow inset
##   seam and at most two accents, never a four-sided ring of generic drifts;
## - walls: every wall rising out of the snow stands in it, a contact seam and a snow lip along its
##   foot (src/hero/frost_wall_snow.gd, theme block "wall_snow"; drawn in the world's own snow layers
##   of hell_game.gd, built once per floor);
## - thaw: a fire bowl that is lit melts the snow around it, the stone floor showing through in a
##   patch that grows over `thaw_time` s;
## - snowmen: a snowman (prop "snowman") is the Frostgruft's mimic; when the hero comes within
##   `wake` px it wakes as the snow monster (hell_game.gd wake_snowman);
## - sliding: on glaze ice (grid cell 2 with theme liquid.slide) the hero slides instead of walking:
##   the legs stop, the body leans into the slide (slide_lean), the boots scratch pale skid marks
##   into the ice and ice chips spray up behind.
## Presentation only: the world's rules stay in hell_game.gd.

const FrostWallSnow = preload("res://src/hero/frost_wall_snow.gd")

## theme "snow" keys of the same name override these: stride = px walked per print, life = s a
## print stays, max = prints kept at once, color = the prints' colour, skid_speed = px/s from which
## a slide scratches the ice, lean = rad the hero leans at full slide speed.
## wake = px from a snowman at which it wakes, thaw_time = s a lit fire bowl takes to melt its
## patch, thaw_size = px across that patch.
const DEFAULTS := {"stride": 28.0, "life": 9.0, "max": 520, "color": "#4a6a9c", "skid_speed": 90.0, "lean": 0.22, "wake": 120.0,
	"thaw_time": 2.6, "thaw_size": 220.0}
## Floor decals with a raised frame receive a narrow inset seam.
const FRAMED := ["rune_big", "rune_plate", "rune_small", "fire_plate", "demon_plate", "grate", "pit"]
const BAKED_FOOT := ["rune_pillar_a", "rune_pillar_b", "rune_pillar_c", "rune_pillar_d", "obelisk", "skull_obelisk",
	"skull_pile", "skull_heap", "coal_skulls", "rocks_a", "rocks_dark", "rocks_lava", "boulders", "spire_big", "spire_big_b",
	"spire_big_t", "spire_mid", "spire_small", "spires_t", "spires_lava", "spire_t", "altar", "stairs_down", "statue_angel",
	"statue_monk", "gargoyle", "barrel_a", "barrel_b", "barrel_c", "crate_a", "crate_b", "crate_c", "crate_pile", "urn_a",
	"urn_b", "urn_c", "urn_d", "urn_e", "table_a", "table_b", "table_c", "bench", "shelf", "shop_table", "sacks_a",
	"sacks_b", "sacks_c", "chest_closed", "chest_open", "chest_gold", "chest_empty", "chest_vault", "cage_small", "moss_rubble_a",
	"moss_rubble_b", "moss_ruin", "fountain", "portal", "portal_dark", "candelabra", "brazier_bowl", "brazier_pillar", "brazier_rune",
	"brazier_low", "brazier_low_b", "brazier_floor", "brazier_demon", "brazier_blue", "bowl_blue", "torch_pillar", "torch_pillar_blue",
	"snowman", "glacier_a", "glacier_b"]
const SMALL_FOOT := ["bone_a", "bone_b", "bone_c", "bone_d", "skull_a", "skull_b", "heart"]

var g: Node
var cfg: Dictionary = DEFAULTS.duplicate(true)
## Cells (index y * cols + x) covered by snow (floor cells, not melted).
var snow: Dictionary = {}
## Prints and skid marks: {p, ang, side, t, kind ("boot", "paw", "skid"), size}.
var prints: Array = []
## Ice chips in the air: {p, v, t}.
var chips: Array = []
## Foot of each sprite: [left, right] px from its centre where it touches the ground (cached).
var _feet: Dictionary = {}
## Framed floor features: [centre, half size]. They get an inset seam, not a snow ring.
var frame_insets: Array = []
var _hero_last := Vector2.INF
var _hero_side := 1.0
## The snow at the walls (src/hero/frost_wall_snow.gd).
var walls: RefCounted
## True when the snow cells changed (a fire bowl thawed its patch): the wall snow is built anew.
var _walls_dirty := false


func _init(game: Node, theme_block: Dictionary) -> void:
	g = game
	for k: String in theme_block:
		if DEFAULTS.has(k):
			cfg[k] = theme_block[k]
	walls = FrostWallSnow.new(game, game.theme.get("wall_snow", {}))


## A new floor: its snow fields, no prints yet.
func reset() -> void:
	snow = {}
	prints = []
	chips = []
	_hero_last = Vector2.INF
	var C: float = g.C
	var cols: int = g.W.cols
	var thaws: Array = []
	for d: Dictionary in g.W.decals:
		if str(d.name).begins_with("thaw_"):
			thaws.append([Vector2(float(d.x), float(d.y)), float(d.w) * 0.34])
	for i in range(g.W.grid.size()):
		if int(g.W.grid[i]) != 1 or int(g.W.room_at[i]) < 0:
			continue
		var at := Vector2((i % cols + 0.5) * C, (i / cols + 0.5) * C)
		if thaws.all(func(t: Array) -> bool: return at.distance_to(t[0]) > t[1]):
			snow[i] = true
	_lay_drifts(thaws)
	walls.build(snow)
	_walls_dirty = false


## The floor's walls changed (a secret wall opened): their snow is built anew and redrawn.
func walls_changed() -> void:
	walls.build(snow)
	for node: CanvasItem in g._chunk_nodes:
		node.queue_redraw()


## The floor's fixed inset seams around framed floor decals and plates. The walls have their own
## directional contact pieces (frost_wall_snow.gd); thaw patches already contain their own edge.
func _lay_drifts(_thaws: Array) -> void:
	frame_insets = []
	var C: float = g.C
	for d: Dictionary in g.W.decals:
		if str(d.name) in FRAMED and on_snow(Vector2(float(d.x), float(d.y) + C * 0.6)):
			var size := Vector2(C, C)
			if float(d.get("w", 0.0)) > 0.0:
				size = Vector2(float(d.w), float(d.h))
			elif g.tex.has(d.name):
				size = (g.tex[d.name] as Texture2D).get_size()
			frame_insets.append([Vector2(float(d.x), float(d.y)), size / 2.0])
	for e: Dictionary in g.W.ents:
		if e.type == "plate":
			frame_insets.append([Vector2(float(e.x), float(e.y)), Vector2(40, 40)])


func _hash(p: Vector2) -> float:
	var v := int(p.x * 7.0) * 374761393 + int(p.y * 3.0) * 668265263
	v = (v ^ (v >> 13)) * 1274126177
	return float((v ^ (v >> 16)) & 0xFFFF) / 65535.0


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
	if _walls_dirty:
		walls_changed()
		_walls_dirty = false
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
	# a snowman the hero comes close to wakes as the snow monster
	for p: Dictionary in g.W.props:
		if p.name == "snowman" and hero.distance_to(Vector2(p.x, p.y)) < float(cfg.wake):
			g.wake_snowman(p)
			break
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


## Where a sprite touches the ground: [left, right] px from its centre, from the opaque pixels of
## its lowest fifth (heaps and piles are narrow at their very bottom; cached per sprite name).
func foot(name: String) -> Vector2:
	if _feet.has(name):
		return _feet[name]
	var out := Vector2(-20, 20)
	var t: Texture2D = g.tex.get(name)
	if t != null:
		var im := t.get_image()
		if im != null:
			if im.is_compressed():
				im.decompress()
			var w := im.get_width()
			var h := im.get_height()
			var lo := w
			var hi := -1
			for y in range(maxi(0, h - maxi(4, h / 5)), h):
				for x in range(w):
					if im.get_pixel(x, y).a > 0.4:
						lo = mini(lo, x)
						hi = maxi(hi, x)
			if hi >= lo:
				out = Vector2(lo - w / 2.0, hi + 1 - w / 2.0)
	_feet[name] = out
	return out


## Presentation contract used by tests and by the draw functions below.
static func embedding_style(name: String, kind: String) -> Dictionary:
	if kind == "frame" or name in FRAMED:
		return {"kind": "inset", "clumps": 2, "shadow": 0.0}
	if name in BAKED_FOOT:
		return {"kind": "baked", "clumps": 0, "shadow": 1.0}
	if name in SMALL_FOOT or kind == "small":
		return {"kind": "small", "clumps": 1, "shadow": 18.0}
	return {"kind": "contact", "clumps": 0, "shadow": 1.0}


func _object_name(kind: String, o: Dictionary) -> String:
	match kind:
		"prop": return str(o.get("name", ""))
		"breakable": return "" if o.get("broken", false) else str(o.get("look", ""))
		"ent":
			if o.get("taken", false): return ""
			match str(o.get("type", "")):
				"chest": return "chest_closed"
				"vault": return str(g.theme.get("vault_closed", "chest_gold"))
				"brazier": return "brazier_bowl"
				"well": return "fountain"
				"stairs": return "stairs_down"
				"key", "heart", "gem", "relic": return "heart"
	return ""


func _is_on_snow(p: Vector2) -> bool:
	var C: float = g.C
	return g._cell(int(floor(p.x / C)), int(floor((p.y - 6.0) / C))) == 2 or on_snow(p - Vector2(0, 6))


## True when the graphics set carries its snow in its drawings (theme "baked_snow", the Frostgruft's
## HD set from tools/frost_dungeon/snow_hd.py): props, plates and walls bring their own snow, so the
## drawn contact depressions, accents, inset seams and wall lips stay off.
func baked() -> bool:
	return bool(g.theme.get("baked_snow", false))


## A compressed, pixel-quantised contact depression behind an object's foot. Most of it is hidden
## by the object itself, unlike the old bright drift rows that floated around its outside.
func draw_foot_under(l: CanvasItem, kind: String, o: Dictionary) -> void:
	if baked(): return
	var name: String = _object_name(kind, o)
	if name == "" or not g.tex.has(name): return
	var p := Vector2(float(o.x), float(o.y))
	if not _is_on_snow(p): return
	var f: Vector2 = foot(name)
	var width: float = clampf(f.y - f.x + 8.0, 15.0, 62.0)
	if embedding_style(name, kind).kind == "small": width = minf(width, 18.0)
	_draw_contact_oval(l, p + Vector2(0, 2), width, clampf(width * 0.19, 4.0, 10.0))


func _draw_contact_oval(l: CanvasItem, c: Vector2, width: float, depth: float) -> void:
	var pts := PackedVector2Array()
	for k in range(12):
		var a := TAU * k / 12.0
		pts.append(Vector2(round((c.x + cos(a) * width * 0.5) / 2.0) * 2.0,
			round((c.y + sin(a) * depth * 0.5) / 2.0) * 2.0))
	l.draw_colored_polygon(pts, Color("5b76a5aa"))
	l.draw_line(Vector2(c.x - width * 0.34, c.y - 1), Vector2(c.x + width * 0.34, c.y - 1), Color("d7e7f5b8"), 2.0, false)


## Only tiny loose objects need a runtime foreground accent. Substantial props use snow baked onto
## their actual silhouette, so no generic mound can float beside them.
func draw_foot_over(l: CanvasItem, kind: String, o: Dictionary) -> void:
	if baked(): return
	var name: String = _object_name(kind, o)
	if name == "" or not g.tex.has(name): return
	var style: Dictionary = embedding_style(name, kind)
	if style.kind != "small": return
	var p := Vector2(float(o.x), float(o.y))
	if not _is_on_snow(p): return
	var h: float = _hash(p)
	var x: float = roundf((p.x + (h - 0.5) * 8.0) / 3.0) * 3.0
	var y: float = roundf((p.y + 2.0) / 3.0) * 3.0
	l.draw_rect(Rect2(x - 6, y - 3, 12, 3), Color("b5cae4"))
	l.draw_rect(Rect2(x - 3, y - 6, 6, 3), Color("f5faff"))


## The snow on the ground under the actors: lit-bowl thaw patches and inset floor-feature seams.
func draw_ground(l: CanvasItem, view: Rect2) -> void:
	var t := float(g.state.get("t", 0.0))
	for e: Dictionary in g.W.ents:
		if e.type == "brazier" and e.get("lit", false) and view.grow(200).has_point(Vector2(e.x, e.y)):
			_draw_thaw(l, e, t)
	if baked(): return
	var area := view.grow(60)
	for f: Array in frame_insets:
		if area.has_point(f[0]):
			_draw_inset_frame(l, f[0], f[1])


func _draw_inset_frame(l: CanvasItem, c: Vector2, half: Vector2) -> void:
	var x0: float = roundf(c.x - half.x)
	var x1: float = roundf(c.x + half.x)
	var y0: float = roundf(c.y - half.y)
	var y1: float = roundf(c.y + half.y)
	var seam := Color("526d9c92")
	l.draw_line(Vector2(x0 + 5, y0), Vector2(x1 - 5, y0), seam, 2.0, false)
	l.draw_line(Vector2(x0, y0 + 5), Vector2(x0, y1 - 5), seam, 2.0, false)
	l.draw_line(Vector2(x1, y0 + 5), Vector2(x1, y1 - 5), seam, 2.0, false)
	l.draw_line(Vector2(x0 + 5, y1), Vector2(x1 - 5, y1), Color("38527fba"), 3.0, false)
	# Two short, low accents at the front corners break the geometric outline without framing it.
	for sx: float in [-1.0, 1.0]:
		var x: float = c.x + sx * maxf(8.0, half.x - 10.0)
		l.draw_rect(Rect2(round(x - 5), y1 - 3, 10, 3), Color("c5d8ec"))
		l.draw_rect(Rect2(round(x - 2), y1 - 6, 4, 3), Color("f7fbff"))


## A lit fire bowl's thaw: the stone floor showing through, the patch growing from the bowl over
## thaw_time s (eased), its cells leaving the snow once it is through.
func _draw_thaw(l: CanvasItem, e: Dictionary, t: float) -> void:
	var tx: Texture2D = g.tex.get("thaw_a")
	if tx == null:
		return
	var k := clampf((t - float(e.get("lit_at", t - 99.0))) / float(cfg.thaw_time), 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - k, 3.0)
	var size := Vector2.ONE * float(cfg.thaw_size) * grow
	l.draw_texture_rect(tx, Rect2(Vector2(e.x, e.y - 24.0) - size / 2.0, size), false, Color(1, 1, 1, clampf(k * 3.0, 0.0, 1.0)))
	# thaw_a already has a hand-shaped slushy transition. Do not surround it with generic snowballs:
	# that was the conspicuous white ring around every fire bowl in the rejected implementation.
	if k >= 1.0 and not e.get("thawed", false):
		e.thawed = true
		var C: float = g.C
		var r := float(cfg.thaw_size) * 0.34
		for k2: int in snow.keys():
			var at := Vector2((k2 % int(g.W.cols) + 0.5) * C, (k2 / int(g.W.cols) + 0.5) * C)
			if at.distance_to(Vector2(e.x, e.y - 24.0)) < r:
				snow.erase(k2)
		_walls_dirty = true


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
