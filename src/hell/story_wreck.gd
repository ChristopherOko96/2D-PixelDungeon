extends RefCounted
## Light destruction of the story worlds (Krypta, Frostgruft, Hölle on src/hell/hell_game.gd),
## "leicht zerstörbar, nicht komplett" like the old crypt (src/game.gd wall_hit / walls_broken):
## - wall wear: shots, blades, blasts and slams that meet a wall bite pixels out of its face and
##   crack it where they land (deeper on the same spot, up to wall.max_depth); chips and dust in
##   the wall's material fly, fall, bounce and settle as pixel matter. Walls stay solid: the cell
##   grid and the collision are never touched, the marks are paint on the face.
## - smashable props: the non-critical decorative props (props.kinds by name; props.never_break
##   wins) shatter into shards cut from their own sprite that fly with the blow, bounce off walls
##   and floor and settle as debris; the world's crates/urns/barrels (breakable ents) do too.
## Everything scales with the blow's power (a sword chip 1, a boss slam 3+), nothing blocks input,
## everything comes to rest. Data: assets/data/story_wreck.json. Shards and chips fly by the shared
## debris physics (src/rig_kit/rig_debris.gd, RigDebris), each with its material's values.
## Hooks: hell_game.gd _ready (new), load_floor (reset), _update (update), _update_shots (shot,
## hit_dir, hit_line), _swing (swing), _explode (blast), _hit_breakable (smash_ent), _slams_after
## (hit_line); src/hero/story_feel.gd wall_hit (every wall contact) and on_blast (enemy blasts).

const DATA_PATH := "res://assets/data/story_wreck.json"
## World px per art pixel (hell_game.gd PIXEL_WORLD): bites, chips and dust sit on this grid.
const PX := 3.0
## hell_walls.gd: north faces rise this high over the floor line, side columns are this wide.
const NORTH_HEIGHT := 74.0
const SIDE_WIDTH := 62.0


## The floor grid as RigDebris' world: a debris piece is thrown back by a blocked cell.
## Holds the wreck weakly (the wreck owns the debris).
class WreckFloor extends RigDebrisHost:
	var _wreck: WeakRef

	func _init(wreck: RefCounted) -> void:
		_wreck = weakref(wreck)

	## True on a blocked cell of the floor (story_wreck _blocked).
	func solid(point: Vector2) -> bool:
		var wreck: Variant = _wreck.get_ref()
		return wreck != null and bool(wreck._blocked(point))


## One drawing layer of the wreck (marks_back, marks_front, rest, air).
class WreckLayer extends Node2D:
	var kit: RefCounted
	var mode := ""
	func _draw() -> void:
		kit.draw(self, mode)


var g: Node
var cfg: Dictionary = {}
## Which world block of the data applies (from the theme file: krypta, frost, hell).
var world_key := "hell"
## Direction of the blow that is about to hit a breakable ent (set by hell_game hooks).
var hit_dir := Vector2.ZERO
## Persistent wall marks: {p, face, line, depth, seed, cells, colors}.
var marks: Array = []
## Flying or sliding debris (RigDebris pieces: x, y, z, vx, vy, vz, ang, spin, phys = m), settled
## debris, crumbling debris, dust puffs.
var pieces: Array = []
var rest: Array = []
var crumbs: Array = []
var dust: Array = []

var _mark_at: Dictionary = {}
## Wall decorations bites stay off (_index_decor) and those near the mark being built.
var _decor: Array = []
var _mask_now: Array = []
var _layers: Dictionary = {}
var _dirty := true
var _air_was := false
var _drawn_at := Vector2.INF
var _images: Dictionary = {}
var _palettes: Dictionary = {}
var _shards: Dictionary = {}
var _kinds: Dictionary = {}
var _prop_cells: Dictionary = {}
var _sound_at: Dictionary = {}
var _clock := 0.0
var _seed := 1
var _rng := RandomNumberGenerator.new()
## The shared debris physics the pieces fly by (each piece brings its material as "phys").
var _debris: RigDebris


func _init(game: Node) -> void:
	g = game
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	cfg = parsed if parsed is Dictionary else {}
	var base := str(g.get("theme_path")).get_file().get_basename().trim_suffix("_theme")
	world_key = base if _sect("worlds").has(base) else str(cfg.get("default_world", "hell"))
	_rng.seed = 7919
	_debris = RigDebris.new({}, WreckFloor.new(self))
	for spec: Array in [["marks_back", 3], ["rest", 4], ["air", 13], ["marks_front", 22]]:
		var layer := WreckLayer.new()
		layer.kit = self
		layer.mode = str(spec[0])
		layer.z_index = int(spec[1])
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.add_child(layer)
		_layers[layer.mode] = layer


# ---------- public API ----------

## A new floor: marks and debris go, the floor's smashable props are indexed.
func reset() -> void:
	marks.clear()
	_mark_at.clear()
	pieces.clear()
	rest.clear()
	crumbs.clear()
	dust.clear()
	hit_dir = Vector2.ZERO
	_index_props()
	_index_decor()
	_dirty = true


## Per frame (hell_game _update): debris physics, dust, crumbling, redraws.
func update(dt: float) -> void:
	_clock += dt
	if not pieces.is_empty():
		var keep: Array = []
		for q: Dictionary in pieces:
			if _step(q, dt):
				keep.append(q)
		pieces = keep
	if not dust.is_empty():
		var keep_d: Array = []
		for d: Dictionary in dust:
			d.t = float(d.t) + dt
			d.p = (d.p as Vector2) + (d.v as Vector2) * dt
			d.v = (d.v as Vector2) * exp(-3.0 * dt) + Vector2(0.0, float(d.fall)) * dt
			d.r = float(d.r) + float(d.grow) * dt
			if float(d.t) < float(d.life):
				keep_d.append(d)
		dust = keep_d
	if not crumbs.is_empty():
		var keep_c: Array = []
		for q: Dictionary in crumbs:
			q.fade = float(q.fade) - dt
			if float(q.fade) > 0.0:
				keep_c.append(q)
		crumbs = keep_c
	var busy := not pieces.is_empty() or not dust.is_empty() or not crumbs.is_empty()
	if busy or _air_was:
		(_layers.air as Node2D).queue_redraw()
	_air_was = busy
	var cam: Vector2 = (g.get("camera") as Camera2D).position if g.get("camera") != null else Vector2.ZERO
	if _dirty or not _drawn_at.is_finite() or cam.distance_to(_drawn_at) > float(_sect("debris").get("redraw_move", 360.0)):
		for mode: String in ["marks_back", "marks_front", "rest"]:
			(_layers[mode] as Node2D).queue_redraw()
		_drawn_at = cam
		_dirty = false


## A wall contact (story_feel.gd wall_hit: every shot, blade and charge meeting a wall) at world
## point `at`, `normal` pointing back to the floor; `style` the hit's look, `owner` 1 the hero.
## `power` < 0 takes the style's power. Contacts on gates or solid props leave no mark.
func wall_hit(at: Vector2, normal: Vector2, style: String, owner := 0, power := -1.0) -> void:
	if power < 0.0:
		power = _power(style, owner)
	if _wall_cell(at, normal):
		_chip(at, normal, power)
	elif owner == 1:
		# a hero blow on a solid smashable prop
		var p := _prop_at(at, 24.0)
		if not p.is_empty():
			_hit_prop(p, -normal, power, at)


## A blow from `from` towards `to` (frost shards, thrown bodies): finds the wall contact by
## bisection like story_feel.gd wall_hit and wears the wall there.
func hit_line(from: Vector2, to: Vector2, style: String, owner := 0, power := -1.0) -> void:
	var travel := to - from
	if travel.length() < 1.0:
		return
	if not _blocked(to):
		to += travel.normalized() * 16.0
		if not _blocked(to):
			return
	var low := 0.0
	var high := 1.0
	for i in range(7):
		var mid := (low + high) * 0.5
		if _blocked(from.lerp(to, mid)):
			high = mid
		else:
			low = mid
	var contact := from.lerp(to, low)
	wall_hit(contact, _normal(contact, to - from), style, owner, power)


## A hero shot (hell_game _update_shots): true when it met a smashable prop (the shot ends there
## unless it pierces).
func shot(s: Dictionary) -> bool:
	var at: Vector2 = s.p
	var hit := {}
	for p: Dictionary in _props_near(at, 60.0):
		if bool(p.get("low", false)):
			continue
		if _prop_box(p).has_point(at):
			hit = p
			break
	if hit.is_empty():
		return false
	var kind := str(s.get("kind", "arrow"))
	var power := float((_sect("powers").get("shots", {}) as Dictionary).get(kind, _sect("powers").get("default", 1.0))) * float(s.get("big", 1.0))
	_hit_prop(hit, (s.v as Vector2).normalized(), power, at)
	if bool(s.get("pierce", false)):
		return false
	s.t = 0.0
	return true


## A blade's swing (hell_game _swing): smashable props in its arc break along `dir`.
func swing(from: Vector2, dir: Vector2, reach: float, half: float) -> void:
	for p: Dictionary in _props_near(from, reach + 60.0):
		var centre := _prop_centre(p)
		var to := centre - from
		if to.length() < reach + 40.0 and absf(angle_difference(dir.angle(), to.angle())) <= half:
			_hit_prop(p, dir, _power("metal", 1), centre)


## A blast at `at` with `radius` (hero bursts: _explode; enemy blasts and slams: story_feel
## on_blast): props in reach shatter away from it, the nearest wall faces take bites.
func blast(at: Vector2, radius: float, style := "blast", hero := true) -> void:
	var b := _sect("blast")
	var power := _power(style, 1 if hero else 0)
	var reach := maxf(radius, float(b.get("prop_reach", 30.0)))
	for p: Dictionary in _props_near(at, reach + 60.0):
		var c := _prop_centre(p)
		if c.distance_to(at) < reach + 24.0:
			_hit_prop(p, (c - at).normalized() if c.distance_to(at) > 1.0 else Vector2.UP, power, c)
	if radius < float(b.get("min_radius", 24.0)):
		return
	var hits: Array = []
	var rays := int(b.get("rays", 10))
	for k in range(rays):
		var a := TAU * float(k) / float(rays) + _rng.randf() * 0.3
		var d := Vector2(cos(a), sin(a))
		var dist := 12.0
		while dist <= radius:
			if _blocked(at + d * dist):
				hits.append([dist, at + d * maxf(0.0, dist - 12.0), at + d * dist])
				break
			dist += 12.0
	hits.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for i in range(mini(hits.size(), int(b.get("max_bites", 4)))):
		var h: Array = hits[i]
		var fall := 1.0 - 0.5 * float(h[0]) / maxf(1.0, radius)
		hit_line(h[1], h[2], style, 1 if hero else 0, power * fall)


## A breakable ent of the world (crate, urn, barrel; seal, skull heap) that just broke
## (hell_game _hit_breakable): crates shatter from their sprite, seals and heaps spit chips.
func smash_ent(e: Dictionary, at: Vector2) -> void:
	var dir := hit_dir.normalized() if hit_dir.length() > 0.1 else (Vector2(float(e.x), float(e.y) - 30.0) - _hero()).normalized()
	hit_dir = Vector2.ZERO
	var type := str(e.get("type", ""))
	if type == "crate":
		var look := str(e.get("look", ""))
		var kind := _kind(look)
		var m := _mat(str(kind.get("material", "wood")))
		_shatter(look, Vector2(float(e.x), float(e.y)), false, dir, 2.0, kind, m, at)
		_sound(str(m.get("break", "")), at, 0.05)
		return
	var tex_name := "skull_heap" if type == "skullheap" else "demon_plate"
	var m2 := _mat("bone" if type == "skullheap" else "stone")
	var pal := _palette(tex_name)
	var foot := Vector2(float(e.x), float(e.y))
	for k in range(14):
		var c: Color = pal[_rng.randi() % 3]
		var size := PX * float(1 + _rng.randi() % 3)
		_spawn_chip(foot + Vector2(_rng.randf_range(-36.0, 36.0), _rng.randf_range(-4.0, 4.0)), _rng.randf_range(10.0, 50.0),
			(dir * 160.0 + Vector2(_rng.randf_range(-170.0, 170.0), _rng.randf_range(-90.0, 90.0))), _rng.randf_range(120.0, 320.0), c, size, m2)
	_puff(foot - Vector2(0.0, 20.0), 6, (pal[1] as Color).lightened(0.2), 1.6)


# ---------- wall wear ----------

func _chip(at: Vector2, normal: Vector2, power: float) -> void:
	var w := _sect("wall")
	var n := Vector2(signf(normal.x), 0.0) if absf(normal.x) > absf(normal.y) else Vector2(0.0, signf(normal.y))
	if n == Vector2.ZERO:
		return
	var jitter := float(w.get("jitter", 12.0))
	var p := at
	var face := ""
	var line := 0.0
	var C: float = g.C
	var ground := at
	var z := 0.0
	if n.y > 0.5:
		face = "n"
		line = roundf(at.y / C) * C
		p.y = clampf(line - float(w.get("face_lift_north", 28.0)) + _rng.randf_range(-jitter, jitter), line - NORTH_HEIGHT + 8.0, line - 6.0)
		p.x += _rng.randf_range(-jitter, jitter) * 0.5
		ground = Vector2(p.x, line + 4.0)
		z = ground.y - p.y
	elif n.y < -0.5:
		face = "s"
		line = roundf(at.y / C) * C
		p.y = clampf(line + float(w.get("face_lift_south", 24.0)) + _rng.randf_range(-jitter, jitter), line + 8.0, line + NORTH_HEIGHT - 10.0)
		p.x += _rng.randf_range(-jitter, jitter) * 0.5
		ground = Vector2(p.x, line - 4.0)
		z = 8.0
	else:
		face = "w" if n.x > 0.5 else "e"
		line = roundf(at.x / C) * C
		var inset := float(w.get("side_inset", 18.0)) + _rng.randf_range(0.0, jitter)
		p.x = line - inset if face == "w" else line + inset
		p.y += _rng.randf_range(-jitter, jitter)
		ground = Vector2(line + n.x * 4.0, p.y + 24.0)
		z = 24.0
	# the bite: the same spot deepens, a new one opens (oldest goes past marks_cap)
	var spot := float(w.get("spot", 26.0))
	# keyed by the contact along the face (not the jittered paint point): the same spot deepens
	var key := "%s:%d:%d" % [face, int(floor((at.x if face == "n" or face == "s" else at.y) / spot)), int(line)]
	var max_depth := float(w.get("max_depth", 4))
	var mark: Dictionary = _mark_at.get(key, {})
	if _masked(p):
		# wall decorations (banners, torches, posts, door frames) stay clean: the blow only chips
		mark = {"depth": clampf(roundf(power), 1.0, max_depth)}
	elif mark.is_empty():
		mark = {"p": p, "face": face, "line": line, "depth": clampf(roundf(power), 1.0, max_depth), "seed": _next_seed(), "key": key}
		marks.append(mark)
		_mark_at[key] = mark
		while marks.size() > int(w.get("marks_cap", 140)):
			var old: Dictionary = marks.pop_front()
			_mark_at.erase(str(old.get("key", "")))
	else:
		mark.depth = minf(max_depth, float(mark.depth) + maxf(1.0, roundf(power * 0.75)))
	if mark.has("p"):
		_build_mark(mark)
	_dirty = true
	# chips and dust of the wall's material fly off the face
	var m := _mat(str(_world().get("wall_material", "stone")))
	var pal := _palette("wall_h")
	var count := int(round(float(w.get("chips_per_power", 4)) * power))
	var speed := float(w.get("chip_speed", 230.0))
	var up := float(w.get("chip_up", 160.0))
	var tangent := Vector2(-n.y, n.x)
	for k in range(count):
		var big := power >= float(w.get("chunks_from_power", 2.0)) and k % 3 == 0
		# broken stone shows its lit and mid tones; only a few chips are shadow-dark
		var c: Color = pal[0] if _rng.randf() < 0.2 else pal[1 + _rng.randi() % 2]
		var v := n * speed * _rng.randf_range(0.35, 1.0) * (0.8 + 0.2 * power) + tangent * _rng.randf_range(-0.7, 0.7) * speed
		_spawn_chip(ground + tangent * _rng.randf_range(-8.0, 8.0), z + _rng.randf_range(-4.0, 4.0), v, up * _rng.randf_range(0.2, 1.0), c, PX * (2.0 if big else 1.0), m)
	var dust_c := _color(_world().get("dust", null), (pal[1] as Color).lightened(0.25))
	_puff(p + n * 6.0, int(round(float(w.get("dust_per_power", 2)) * power)), dust_c, power)
	var depth := float(mark.depth)
	var snd := str(w.get("sound_small", "chips"))
	if power >= 2.5:
		snd = str(w.get("sound_big", "rubble"))
	elif depth >= float(w.get("crack_from", 2)):
		snd = str(w.get("sound_crack", "wall_crack"))
	_sound(snd, p, float(w.get("sound_gap", 0.09)))


## The mark's pixels, all in the wall's own sampled shades (wall_h: dark, mid, light): broken
## stone, not ink. A shallow bite is a scuff of lighter fresh stone; deeper ones open a hollow
## shaded under its upper lip and lit towards its floor, with a lit lower lip of freshly broken
## stone; only deep bites (core_from on) show a small dark core (in the hell an ember). Loose
## pixel crumbs lie around it, cracks (crack_from on) walk out in the wall's dark shade with a
## lit pixel under each step. Clipped to the drawn face, never on wall decorations (_decor).
## The shape keeps its seed, so a deeper hit grows the same bite.
func _build_mark(mark: Dictionary) -> void:
	var w := _sect("wall")
	var wd := _world()
	var pal := _palette("wall_h")
	var dark: Color = pal[0]
	var mid: Color = pal[1]
	var light: Color = pal[2]
	var fresh := light.lerp(Color.WHITE, float(wd.get("rim_light", 0.18)))
	var scuff := mid.lerp(light, 0.6)
	var shade := dark.lerp(mid, 0.4)
	var core := _color(wd.get("hole", null), dark.darkened(0.25))
	var crack := _color(wd.get("crack", null), dark.lerp(mid, 0.15))
	var ember: Variant = wd.get("ember_core", null)
	var d := float(mark.depth)
	var max_d := maxf(2.0, float(w.get("max_depth", 4)))
	var r := float(w.get("bite_base", 1.2)) + d * float(w.get("bite_grow", 0.95))
	var core_from := float(w.get("core_from", 3))
	var core_r := 0.0 if d < core_from else (d - core_from + 1.0) * float(w.get("core_grow", 0.7))
	var depth_share := clampf((d - 1.0) / (max_d - 1.0), 0.0, 1.0)
	var sd := int(mark.seed)
	var face := str(mark.face)
	var line := float(mark.line)
	var p: Vector2 = mark.p
	var clip := Rect2()
	match face:
		"n": clip = Rect2(p.x - 400.0, line - NORTH_HEIGHT + 3.0, 800.0, NORTH_HEIGHT - 4.0)
		"s": clip = Rect2(p.x - 400.0, line + 3.0, 800.0, NORTH_HEIGHT - 6.0)
		"w": clip = Rect2(line - SIDE_WIDTH + 3.0, p.y - 400.0, SIDE_WIDTH - 5.0, 800.0)
		_: clip = Rect2(line + 2.0, p.y - 400.0, SIDE_WIDTH - 5.0, 800.0)
	var reach := (r + 14.0) * PX
	var near := Rect2(p - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
	_mask_now = []
	for m: Rect2 in _decor:
		if m.intersects(near):
			_mask_now.append(m)
	var cells := PackedVector2Array()
	var colors := PackedColorArray()
	var origin := (p / PX).floor()
	var stretch := Vector2(1.0, 0.8) if face == "n" or face == "s" else Vector2(0.8, 1.0)
	var ri := int(ceil(r)) + 1
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var q := Vector2(float(dx) / stretch.x, float(dy) / stretch.y)
			var edge := r * (0.62 + 0.5 * _hash(sd, dx, dy))
			var dist := q.length()
			if dist > edge:
				continue
			var grain := _hash(sd, dx + 17, dy + 5)
			var c := scuff
			if dist > edge - 1.0:
				# the ragged edge: lit lower lip of fresh stone, shaded upper lip once it is a hollow
				if dy > 0:
					c = fresh
				elif dy < 0 and d >= 2.0:
					c = shade
				else:
					c = scuff if grain > 0.4 else light
			elif d < 2.0:
				# a scuff: lighter fresh stone with a few grains of the wall's mid shade
				c = scuff if grain > 0.3 else (light if grain > 0.12 else mid)
			elif dist <= core_r:
				c = core
				if ember != null and d >= float(w.get("ember_from", 3)) and dist <= core_r * 0.6:
					c = _color(ember, core)
			else:
				# the hollow: shaded under its upper lip, catching light towards its floor
				var down := clampf(0.5 + float(dy) / maxf(1.0, r), 0.0, 1.0)
				c = shade.lerp(mid, down * (1.0 - 0.35 * depth_share))
				if grain < 0.18:
					c = c.lerp(dark, 0.4)
				elif grain > 0.85:
					c = c.lerp(light, 0.5)
			_put(cells, colors, (origin + Vector2(dx, dy)) * PX, c, clip)
	# loose crumbs of broken stone around the bite (mostly fresh and mid, a few shaded)
	for k in range(int(3.0 + d * 3.0)):
		var a := _hash(sd, k, 91) * TAU
		var rr := r + 0.8 + _hash(sd, k, 37) * 2.6
		var h := _hash(sd, k, 53)
		var cc := fresh if h < 0.45 else (mid if h < 0.8 else shade)
		_put(cells, colors, (origin + (Vector2(cos(a), sin(a) * 0.8) * rr).floor()) * PX, cc, clip)
	var crack_from := float(w.get("crack_from", 2))
	if d >= crack_from:
		var n := mini(3, 1 + int(d - crack_from))
		for k in range(n):
			var a := _hash(sd, k, 7) * TAU
			var cur := Vector2(cos(a), sin(a)) * (r * 0.8)
			var length := int((d - crack_from + 1.0) * float(w.get("crack_len", 4)) * (0.6 + 0.6 * _hash(sd, k, 11)))
			for s in range(length):
				a += (_hash(sd, k * 31 + s, 5) - 0.5) * 1.1
				cur += Vector2(cos(a), sin(a))
				var cell := (origin + cur.round()) * PX
				_put(cells, colors, cell, crack, clip)
				if s % 2 == 0:
					_put(cells, colors, cell + Vector2(0.0, PX), Color(fresh, 0.6), clip)
	_mask_now = []
	mark.cells = cells
	mark.colors = colors


func _put(cells: PackedVector2Array, colors: PackedColorArray, at: Vector2, c: Color, clip: Rect2) -> void:
	var centre := at + Vector2(PX, PX) * 0.5
	if not clip.has_point(centre):
		return
	for m: Rect2 in _mask_now:
		if m.has_point(centre):
			return
	cells.append(at)
	colors.append(c)


## Wall decorations that stay clean (no bites painted on them): wall_decor sprites (banners,
## torches, signs), the glowing posts and side lamps, doorways with their frames and the boss arch.
func _index_decor() -> void:
	_decor = []
	var tex: Dictionary = g.tex
	var W: Dictionary = g.W
	var C: float = g.C
	for wdec: Dictionary in W.get("wall_decor", []):
		var t: Texture2D = tex.get(str(wdec.get("name", "")))
		if t != null:
			_decor.append(Rect2(float(wdec.x) - t.get_width() / 2.0, float(wdec.y), t.get_width(), t.get_height()).grow(4.0))
	var walls: Dictionary = g.walls
	var post: Texture2D = tex.get("wall_h_glowpost")
	if post != null:
		for at: Vector2 in walls.get("posts", []):
			_decor.append(Rect2(at - Vector2(post.get_width() / 2.0, post.get_height()), post.get_size()).grow(4.0))
	var lamp: Texture2D = tex.get("wall_v_glow")
	if lamp != null:
		for s: Dictionary in walls.get("side", []):
			if bool(s.get("glow", false)):
				_decor.append(Rect2(Vector2(float(s.x) + 31.0, float(s.y)) - lamp.get_size() / 2.0, lamp.get_size()).grow(4.0))
	var arch: Texture2D = tex.get("boss_arch")
	for d: Dictionary in W.get("doors", []):
		for c: Vector2i in d.get("cells", []):
			_decor.append(Rect2(c.x * C - 30.0, c.y * C - NORTH_HEIGHT - 30.0, C + 60.0, C + NORTH_HEIGHT * 2.0 + 60.0))
		if arch != null and bool(d.get("boss_gate", false)):
			_decor.append(Rect2(float(d.cx) - arch.get_width() / 2.0, (float(d.y1) + 1.0) * C + 6.0 - arch.get_height(), arch.get_width(), arch.get_height()).grow(4.0))
	for e: Dictionary in W.get("ents", []):
		if str(e.get("type", "")) == "lever" and e.has("wy"):
			_decor.append(Rect2(float(e.x) - 40.0, float(e.wy) - 100.0, 80.0, 140.0))


## True when world point `p` lies on a wall decoration (_decor).
func _masked(p: Vector2) -> bool:
	for m: Rect2 in _decor:
		if m.has_point(p):
			return true
	return false


# ---------- props ----------

func _index_props() -> void:
	_prop_cells = {}
	var W: Dictionary = g.W
	if W.is_empty():
		return
	var C: float = g.C
	for p: Dictionary in W.get("props", []):
		if str(p.get("name", "")) == "" or _kind(str(p.name)).is_empty():
			continue
		var box := _prop_rect(p)
		if box.size == Vector2.ZERO:
			continue
		for cy in range(int(floor(box.position.y / C)), int(floor(box.end.y / C)) + 1):
			for cx in range(int(floor(box.position.x / C)), int(floor(box.end.x / C)) + 1):
				var k := cy * int(W.cols) + cx
				if not _prop_cells.has(k):
					_prop_cells[k] = []
				(_prop_cells[k] as Array).append(p)


func _props_near(at: Vector2, r: float) -> Array:
	var out: Array = []
	if _prop_cells.is_empty():
		return out
	var C: float = g.C
	var cols := int(g.W.cols)
	for cy in range(int(floor((at.y - r) / C)), int(floor((at.y + r) / C)) + 1):
		for cx in range(int(floor((at.x - r) / C)), int(floor((at.x + r) / C)) + 1):
			for p: Dictionary in _prop_cells.get(cy * cols + cx, []):
				if not bool(p.get("smashed", false)) and not out.has(p):
					out.append(p)
	return out


func _prop_at(at: Vector2, grow: float) -> Dictionary:
	for p: Dictionary in _props_near(at, 60.0):
		if _prop_box(p).grow(grow).has_point(at):
			return p
	return {}


func _prop_rect(p: Dictionary) -> Rect2:
	var t: Texture2D = (g.tex as Dictionary).get(str(p.get("name", "")))
	if t == null:
		return Rect2()
	var size := t.get_size()
	return Rect2(float(p.x) - size.x / 2.0, float(p.y) - size.y, size.x, size.y)


func _prop_box(p: Dictionary) -> Rect2:
	var r := _prop_rect(p)
	return Rect2(r.position.x + r.size.x * 0.1, r.position.y + r.size.y * 0.15, r.size.x * 0.8, r.size.y * 0.85 + 10.0)


func _prop_centre(p: Dictionary) -> Vector2:
	var r := _prop_rect(p)
	return Vector2(float(p.x), float(p.y) - r.size.y * 0.4)


## A blow of `power` on prop `p` along `dir`: props with more hits chip first, then shatter.
func _hit_prop(p: Dictionary, dir: Vector2, power: float, at: Vector2) -> void:
	if bool(p.get("smashed", false)):
		return
	var kind := _kind(str(p.name))
	if kind.is_empty():
		return
	var m := _mat(str(kind.get("material", "stone")))
	p.wreck_hits = float(p.get("wreck_hits", 0.0)) + power
	if float(p.wreck_hits) < float(kind.get("hits", 1.0)):
		var pal := _palette(str(p.name))
		for k in range(3 + int(power * 2.0)):
			_spawn_chip(Vector2(at.x, float(p.y) + 2.0), maxf(0.0, float(p.y) - at.y), dir * 120.0 + Vector2(_rng.randf_range(-120.0, 120.0), _rng.randf_range(-60.0, 60.0)), _rng.randf_range(80.0, 220.0), pal[_rng.randi() % 3], PX, m)
		_sound("breakable_hit", at, 0.06)
		return
	_smash_prop(p, kind, m, dir, power, at)


func _smash_prop(p: Dictionary, kind: Dictionary, m: Dictionary, dir: Vector2, power: float, at: Vector2) -> void:
	var name := str(p.name)
	var rect := _prop_rect(p)
	p.smashed = true
	_shatter(name, Vector2(float(p.x), float(p.y)), bool(p.get("flip", false)), dir, power, kind, m, at)
	# gone from the world: no longer drawn (hell_game draws named props only), its foot no longer
	# blocks, a light that hung over it (a candle's flame) goes out
	p.name = ""
	if p.get("solid") != null:
		p.solid = null
		g._index_solids()
	var lights: Array = g.W.get("lights", [])
	var near := rect.grow(30.0)
	g.W.lights = lights.filter(func(li: Dictionary) -> bool: return not near.has_point(Vector2(float(li.x), float(li.y))))
	_sound(str(m.get("break", "")), at, 0.05)
	var loot: Dictionary = kind.get("loot", {})
	if not loot.is_empty() and _rng.randf() < float(loot.get("chance", 0.0)):
		var room: int = g._room_at_world(float(p.x), float(p.y))
		if room >= 0:
			g._drop(str(loot.get("drop", "gem")), room, Vector2(float(p.x), float(p.y) + 6.0))


## Shards cut from texture `name` (drawn with its foot at `foot`): a jittered lattice whose
## neighbours share corners, so the pieces tile the sprite; they fly with `dir`, spread from
## the impact `at`, bounce and settle. Without the sprite's pixels: chunks in its colours.
func _shatter(name: String, foot: Vector2, flip: bool, dir: Vector2, power: float, kind: Dictionary, m: Dictionary, at: Vector2) -> void:
	var t: Texture2D = (g.tex as Dictionary).get(name)
	var sm := _sect("smash")
	var pal := _palette(name)
	if t == null:
		return
	var size := t.get_size()
	var origin := foot - Vector2(size.x / 2.0, size.y)
	var shard_list := _shard_set(name, float(kind.get("piece", 15.0)), int(kind.get("max_pieces", 14)), bool(m.get("splinter", false)))
	var speed := float(sm.get("speed", 250.0)) * (0.8 + 0.25 * power)
	var spread := float(sm.get("spread", 150.0))
	var up := float(sm.get("up", 270.0))
	for s: Dictionary in shard_list:
		var c: Vector2 = s.c
		var drawn := origin + Vector2(size.x - c.x if flip else c.x, c.y)
		var away := (drawn - at).normalized() if drawn.distance_to(at) > 1.0 else Vector2(_rng.randf_range(-1.0, 1.0), -1.0).normalized()
		var v := dir * speed * _rng.randf_range(0.4, 1.1) + Vector2(away.x, away.y * 0.5) * spread * _rng.randf_range(0.3, 1.0)
		var height := maxf(0.0, foot.y - drawn.y)
		var q := {"kind": "shard", "x": drawn.x, "y": foot.y + _rng.randf_range(-4.0, 4.0), "z": height, "vx": v.x, "vy": v.y, "vz": up * _rng.randf_range(0.4, 1.0) * (1.0 - 0.4 * height / maxf(1.0, size.y)),
			"ang": 0.0, "spin": _rng.randf_range(-1.0, 1.0) * float(m.get("spin", 10.0)), "m": m, "phys": m, "tex": t, "pts": s.pts, "uvs": s.uvs, "flip": flip, "r": float(s.r), "life": 0.0, "heat": 0.0, "rest": false}
		_add_piece(q)
	if shard_list.is_empty():
		for k in range(10):
			_spawn_chip(foot + Vector2(_rng.randf_range(-size.x * 0.4, size.x * 0.4), 0.0), _rng.randf_range(0.0, size.y * 0.8), dir * speed * 0.6 + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread) * 0.5), up * _rng.randf_range(0.3, 1.0), pal[_rng.randi() % 3], PX * 2.0, m)
	for k in range(int(sm.get("chips", 6))):
		_spawn_chip(Vector2(at.x, foot.y) + Vector2(_rng.randf_range(-10.0, 10.0), 0.0), maxf(0.0, foot.y - at.y), dir * speed * _rng.randf_range(0.3, 1.0) + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-60.0, 60.0)), up * _rng.randf_range(0.3, 1.2), pal[_rng.randi() % 3], PX, m)
	var puff_c := (pal[2] as Color).lerp(_color(_world().get("dust", null), pal[1]), 0.5)
	if str(m.get("break", "")) == "wall_snow_puff":
		puff_c = Color(0.95, 0.98, 1.0)
	_puff(foot - Vector2(0.0, size.y * 0.3), int(sm.get("dust", 6)), puff_c, 1.0 + power * 0.3)


func _shard_set(name: String, piece: float, max_pieces: int, splinter: bool) -> Array:
	var key := "%s:%d:%d:%d" % [name, int(piece), max_pieces, int(splinter)]
	if _shards.has(key):
		return _shards[key]
	var out: Array = []
	var t: Texture2D = (g.tex as Dictionary).get(name)
	if t == null:
		return out
	var size := t.get_size()
	var img := _image(name)
	var cell := maxf(piece, sqrt(size.x * size.y / maxf(1.0, float(max_pieces) / 1.5)))
	var cw := cell * (0.6 if splinter else 1.0)
	var ch := cell * (1.6 if splinter else 1.0)
	var nx := maxi(1, int(round(size.x / cw)))
	var ny := maxi(1, int(round(size.y / ch)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var grid: Array = []
	for j in range(ny + 1):
		var row: Array = []
		for i in range(nx + 1):
			var pt := Vector2(size.x * i / nx, size.y * j / ny)
			if i > 0 and i < nx:
				pt.x += rng.randf_range(-0.3, 0.3) * size.x / nx
			if j > 0 and j < ny:
				pt.y += rng.randf_range(-0.3, 0.3) * size.y / ny
			row.append(pt.round())
		grid.append(row)
	for j in range(ny):
		for i in range(nx):
			var quad: Array = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
			var polys: Array = [quad]
			if not splinter and rng.randf() < 0.6:
				# a diagonal split: triangles like broken clay or stone
				if rng.randf() < 0.5:
					polys = [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]
				else:
					polys = [[quad[0], quad[1], quad[3]], [quad[1], quad[2], quad[3]]]
			for poly: Array in polys:
				var c := Vector2.ZERO
				for v: Vector2 in poly:
					c += v
				c /= float(poly.size())
				if img != null and not _opaque(img, poly, c):
					continue
				var pts := PackedVector2Array()
				var uvs := PackedVector2Array()
				var r := 0.0
				for v: Vector2 in poly:
					pts.append(v - c)
					uvs.append(v / size)
					r = maxf(r, v.distance_to(c))
				out.append({"pts": pts, "uvs": uvs, "c": c, "r": r})
	_shards[key] = out
	return out


func _opaque(img: Image, poly: Array, c: Vector2) -> bool:
	var probes: Array = [c]
	for v: Vector2 in poly:
		probes.append(c.lerp(v, 0.55))
	var solid := 0
	for q: Vector2 in probes:
		var x := clampi(int(q.x), 0, img.get_width() - 1)
		var y := clampi(int(q.y), 0, img.get_height() - 1)
		if img.get_pixel(x, y).a > 0.5:
			solid += 1
	return solid >= 2


# ---------- debris and dust ----------

func _spawn_chip(ground: Vector2, z: float, v: Vector2, vz: float, c: Color, size: float, m: Dictionary) -> void:
	var heat := 0.0
	if _rng.randf() < float(m.get("ember_share", 0.0)):
		heat = 1.0
	_add_piece({"kind": "chip", "x": ground.x, "y": ground.y, "z": maxf(0.0, z), "vx": v.x, "vy": v.y, "vz": vz, "ang": 0.0, "spin": 0.0, "m": m, "phys": m,
		"c": c, "s": size, "life": 0.0, "heat": heat, "seed": _next_seed(), "rest": false})


func _add_piece(q: Dictionary) -> void:
	if pieces.size() >= int(_sect("debris").get("air_cap", 260)):
		return
	pieces.append(q)


## One debris step of piece `q` (RigDebris.step_piece with its material: gravity, bounces that
## lose energy, walls that throw it back, its slide until it rests); a shard landing hard ticks,
## one landing on lava sinks into it. False once it has settled (it moved to `rest`).
func _step(q: Dictionary, dt: float) -> bool:
	var m: Dictionary = q.m
	if q.has("sink"):
		q.life = float(q.life) + dt
		q.sink = float(q.sink) - dt
		q.z = float(q.z) - float(_sect("debris").get("sink_speed", 0.0)) * dt
		return float(q.sink) > 0.0
	if float(q.heat) > 0.0:
		q.heat = maxf(0.0, float(q.heat) - dt / maxf(0.1, float(m.get("cool_time", 1.6))))
	var got := _debris.step_piece(q, dt)
	if got == RigDebris.Step.AIR:
		return true
	if got == RigDebris.Step.BOUNCE and float(q.get("impact", 0.0)) > float(m.get("tick_vz", 160.0)) and str(q.kind) == "shard":
		_sound(str(m.get("tick", "")), _at(q), 0.07)
	if _lava(_at(q)):
		q.sink = float(_sect("debris").get("lava_sink", 0.7))
		q.heat = 1.0
		q.z = 0.0
		return true
	if got == RigDebris.Step.REST:
		_settle(q)
		return false
	return true


## Where piece `q` lies on the floor plane (world px).
static func _at(q: Dictionary) -> Vector2:
	return Vector2(float(q.x), float(q.y))


func _settle(q: Dictionary) -> void:
	if str(q.kind) == "shard":
		q.ang = RigDebris.snapped_angle(float(q.ang), q.m)
	q.heat = 0.0
	rest.append(q)
	var cap := int(_sect("debris").get("rest_cap", 340))
	while rest.size() > cap:
		var old: Dictionary = rest.pop_front()
		old.fade = float(_sect("debris").get("crumble_time", 0.7))
		crumbs.append(old)
	_dirty = true


func _puff(at: Vector2, n: int, c: Color, power: float) -> void:
	var cap := int(_sect("debris").get("dust_cap", 140))
	var fall := float(_world().get("dust_fall", -18.0))
	for k in range(n):
		if dust.size() >= cap:
			return
		dust.append({"p": at + Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-8.0, 8.0)), "v": Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(-50.0, 20.0)) * (0.7 + 0.3 * power),
			"r": 4.0 + 2.0 * power, "grow": 14.0 + 6.0 * power, "t": 0.0, "life": _rng.randf_range(0.6, 1.1) * (0.8 + 0.2 * power), "c": c, "fall": fall, "seed": _next_seed()})


# ---------- drawing ----------

## Draws the layer `mode` (WreckLayer._draw).
func draw(l: Node2D, mode: String) -> void:
	var view := _view()
	match mode:
		"marks_back", "marks_front":
			var front := mode == "marks_front"
			for mark: Dictionary in marks:
				if (str(mark.face) == "s") != front or not mark.has("cells") or not view.has_point(mark.p):
					continue
				var cells: PackedVector2Array = mark.cells
				var colors: PackedColorArray = mark.colors
				for i in range(cells.size()):
					l.draw_rect(Rect2(cells[i], Vector2(PX, PX)), colors[i])
		"rest":
			for q: Dictionary in rest:
				if view.has_point(_at(q)):
					_draw_piece(l, q, 1.0)
		"air":
			for q: Dictionary in crumbs:
				# dither crumble: the alpha steps down in quarters
				var a := ceilf(float(q.fade) / float(_sect("debris").get("crumble_time", 0.7)) * 4.0) / 4.0
				_draw_piece(l, q, a)
			for q: Dictionary in pieces:
				if float(q.z) > 4.0:
					var sw := clampf(float(q.get("r", PX)) * 0.9, PX, 18.0)
					l.draw_rect(Rect2((_at(q) - Vector2(sw * 0.5, 1.0) / 1.0).snapped(Vector2(PX, PX)), Vector2(sw, PX)), Color(0, 0, 0, 0.22))
				_draw_piece(l, q, 1.0)
			for d: Dictionary in dust:
				var life := 1.0 - float(d.t) / float(d.life)
				var a := snappedf(life * 0.42, 0.06)
				if a <= 0.0:
					continue
				var c: Color = d.c
				c.a = a
				var sd := int(d.seed)
				for k in range(5):
					var off := Vector2(_hash(sd, k, 1) - 0.5, _hash(sd, k, 2) - 0.5) * 2.0 * float(d.r)
					var s := PX * (2.0 if k < 2 else 1.0)
					l.draw_rect(Rect2(((d.p as Vector2) + off).snapped(Vector2(PX, PX)), Vector2(s, s)), c)


func _draw_piece(l: CanvasItem, q: Dictionary, alpha: float) -> void:
	var at: Vector2 = _at(q) - Vector2(0.0, float(q.z))
	var m: Dictionary = q.m
	var heat := float(q.get("heat", 0.0))
	var ember := _color(m.get("ember", null), Color(1.0, 0.5, 0.15))
	if q.has("sink"):
		alpha *= clampf(float(q.sink) / float(_sect("debris").get("lava_sink", 0.7)), 0.0, 1.0)
	if str(q.kind) == "shard":
		var tint := Color(1, 1, 1, alpha)
		if heat > 0.0:
			tint = Color(1.0, 1.0 - 0.4 * heat, 1.0 - 0.7 * heat, alpha)
		l.draw_set_transform(at, float(q.ang), Vector2(-1.0 if bool(q.flip) else 1.0, 1.0))
		l.draw_polygon(q.pts, PackedColorArray([tint]), q.uvs, q.tex)
		l.draw_set_transform(Vector2.ZERO)
		return
	var c: Color = q.c
	if heat > 0.0:
		c = c.lerp(ember, heat)
	c.a *= alpha
	var s := float(q.s)
	var cell := (at - Vector2(s, s) * 0.5).snapped(Vector2(PX, PX))
	l.draw_rect(Rect2(cell, Vector2(s, s)), c)
	# ice glints: now and then a chip catches the light
	if bool(m.get("glint", false)) and int(_clock * 9.0 + float(q.get("seed", 0))) % 7 == 0:
		l.draw_rect(Rect2(cell, Vector2(PX, PX)), Color(1, 1, 1, 0.9 * alpha))


# ---------- helpers ----------

func _sect(name: String) -> Dictionary:
	var v: Variant = cfg.get(name, {})
	return v if v is Dictionary else {}


func _world() -> Dictionary:
	var v: Variant = _sect("worlds").get(world_key, {})
	return v if v is Dictionary else {}


func _mat(name: String) -> Dictionary:
	var mats := _sect("materials")
	var out: Dictionary = (mats.get("default", {}) as Dictionary).duplicate()
	out.merge(mats.get(name, {}), true)
	return out


func _kind(name: String) -> Dictionary:
	if name == "":
		return {}
	if _kinds.has(name):
		return _kinds[name]
	var props := _sect("props")
	var found := {}
	if not _matches(name, props.get("never_break", [])):
		for k: Dictionary in props.get("kinds", []):
			if _matches(name, k.get("match", [])):
				found = k
				break
	_kinds[name] = found
	return found


static func _matches(name: String, patterns: Array) -> bool:
	for pat: String in patterns:
		if name.begins_with(pat) or name.contains("_" + pat):
			return true
	return false


func _power(style: String, owner: int) -> float:
	var pw := _sect("powers")
	var v := float(pw.get(style, pw.get("default", 1.0)))
	return v if owner == 1 or style in ["enemy_blast", "boss", "slam"] else v * float(pw.get("enemy_scale", 0.8))


func _blocked(p: Vector2) -> bool:
	var C: float = g.C
	return g._cell_blocked(int(floor(p.x / C)), int(floor(p.y / C)), false)


func _lava(p: Vector2) -> bool:
	var C: float = g.C
	var t: int = g._cell(int(floor(p.x / C)), int(floor(p.y / C)))
	return t == 2 or t == 3


## True when the contact at `at` (normal back to the floor) lies on a real wall cell: not a
## floor cell under a solid prop, not a gate.
func _wall_cell(at: Vector2, normal: Vector2) -> bool:
	var C: float = g.C
	var q := at - normal.normalized() * 6.0
	var cx := int(floor(q.x / C))
	var cy := int(floor(q.y / C))
	# outside the map is no wall face anyone sees
	if cx < 0 or cy < 0 or cx >= int(g.W.cols) or cy >= int(g.W.rows):
		return false
	if g._walkable(g._cell(cx, cy)):
		return false
	return not (g.door_at as Dictionary).has(cy * int(g.W.cols) + cx)


func _normal(contact: Vector2, travel: Vector2) -> Vector2:
	var normal := -travel.normalized()
	var side_x := _blocked(contact + Vector2(signf(travel.x) * 9.0, 0.0))
	var side_y := _blocked(contact + Vector2(0.0, signf(travel.y) * 9.0))
	if side_x and not side_y:
		normal = Vector2(-signf(travel.x), 0.0)
	elif side_y and not side_x:
		normal = Vector2(0.0, -signf(travel.y))
	return normal


func _hero() -> Vector2:
	var pl: Dictionary = g.player
	return Vector2(float(pl.get("x", 0.0)), float(pl.get("y", 0.0)) - 40.0)


func _view() -> Rect2:
	var margin := float(_sect("debris").get("view_margin", 520.0))
	if g.has_method("_view_rect") and g.get("camera") != null and not (g.balance as Dictionary).is_empty():
		return g._view_rect().grow(margin)
	return Rect2(-1e6, -1e6, 2e6, 2e6)


func _sound(name: String, at: Vector2, gap: float) -> void:
	if name == "" or g.get("sound") == null:
		return
	if _clock - float(_sound_at.get(name, -99.0)) < gap:
		return
	_sound_at[name] = _clock
	g.sound.at(name, at)


func _image(name: String) -> Image:
	if _images.has(name):
		return _images[name]
	var img: Image = null
	var t: Texture2D = (g.tex as Dictionary).get(name)
	if t != null:
		img = t.get_image()
		if img != null and img.is_compressed():
			img = img.duplicate()
			img.decompress()
		if img != null and img.is_empty():
			img = null
	_images[name] = img
	return img


## Dark, mid and light colours of texture `name` (its opaque pixels by luminance: 15/50/85 %).
func _palette(name: String) -> Array:
	if _palettes.has(name):
		return _palettes[name]
	var out: Array = [Color(0.18, 0.17, 0.2), Color(0.42, 0.4, 0.44), Color(0.68, 0.66, 0.7)]
	var img := _image(name)
	if img != null:
		var found: Array = []
		var w := img.get_width()
		var total := w * img.get_height()
		var stride := maxi(1, total / 1500)
		for i in range(0, total, stride):
			var c := img.get_pixel(i % w, i / w)
			if c.a > 0.6:
				found.append(Color(c, 1.0))
		if found.size() >= 6:
			found.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
			out = [found[int(found.size() * 0.15)], found[int(found.size() * 0.5)], found[int(found.size() * 0.85)]]
	_palettes[name] = out
	return out


static func _color(v: Variant, fallback: Color) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return fallback


func _next_seed() -> int:
	_seed += 1
	return _seed * 7919 + 13


static func _hash(sd: int, a: int, b: int) -> float:
	var h := (sd * 374761393 + a * 668265263 + b * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h % 10000) / 10000.0
