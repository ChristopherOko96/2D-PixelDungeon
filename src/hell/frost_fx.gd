extends RefCounted
## The Frostgruft's attacks on the pixel grid, in the look and feel of the
## Hell's (src/hell/hell_monsters.gd): telegraphs as a dot grid with a crawling
## dashed rim over a dark underlay and a growing inner ring, every impact
## through the crypt's pixel physics (src/vfx/particles.gd: ice chips that fly,
## bounce and settle, frost clumps that go again, snow dust), the weight of each
## impact by its importance (theme.vfx.feel: a smooth view shake, a white-hot
## pixel flash, a hitstop only for a guardian's heavy blow) and the hero
## knocked back by what hits him.
##
## Ice reads as solid, glossy ice, never as water (art review,
## production/qa/evidence/frost-vfx-review): an opaque ramp shifted to cyan
## against the blue floor (theme.vfx.ice), a dark outline, a lit north edge, a
## thick south lip, hard white gloss streaks and specular pixels, sparkles that
## pop, and fading by an ordered dither instead of transparency. All of it sits
## on the floor's own 3 world-px art pixel. The ice pools of the moves join into
## one slab, shaded once into a texture and drawn in the floor layer over old
## stains and under the hero's shadow (src/hero/story_feel.gd); its edges melt first. Owned by the game in a world with theme.vfx
## (src/hell/hell_game.gd); frost_moves.gd and boss_kit.gd call it. Purely
## visual apart from the knockback.

## World px per pixel block: the floor's, the figures' and the particles' art pixel.
const PX := 3.0
## The pixel animation's frame rate (crawling rims, glints, sparkles).
const FPS := 12.0
## 4x4 ordered dither (fading without transparency).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## The ice ramp (theme.vfx.ice overrides each role).
const ICE_DEFAULT := {"spec": "ffffff", "hi": "e6fbff", "lite": "a6e3f7", "body": "6fbde8", "shade": "3b84c4", "deep": "23599a", "outline": "0d1a38"}
## Snow and rime dust kicked off the floor.
const SNOW := [Color("eef7ff"), Color("c4dcf0"), Color("93b3d3")]
## No knockback step is longer than this (world px), so nothing tunnels.
const KNOCK_STEP := 24.0

var g: Node
## theme.vfx: feel tiers, knock speeds, ice ramp, floor ice, rime.
var cfg: Dictionary = {}
## The ice ramp by role (spec, hi, lite, body, shade, deep, outline).
var C: Dictionary = {}
## One ramp step brighter (the glint).
var _up: Dictionary = {}
## White-hot pixel flashes at impacts ({p, t, T, r}).
var flashes: Array = []
## Rings of frost running out from a burst ({p, r, T, t, front, emit}).
var waves: Array = []
## Rime goes without water (theme.vfx.rime.melt_to "vapor") or melts to water.
var _vapor := true
var _clock := 0.0

## The floor's ice: art cell -> its melt time (seconds on _clock).
var _ice: Dictionary = {}
## Gloss streak anchors of the pools: [cell, until].
var _ice_streaks: Array = []
## The baked slab: its texture, area in cells, colour per cell, cells per
## diagonal (for the glint and the mirrored bands: x + y, or x - y for a slab
## running up to the right, so they always cross it), its north-east rim
## cells and all cells.
var _ice_img: Image
var _ice_tex: ImageTexture
var _ice_box := Rect2i()
var _ice_col: Dictionary = {}
var _ice_diag: Dictionary = {}
var _ice_rim: Array = []
var _ice_cells: Array = []
var _ice_lo := 0
var _ice_hi := 0
var _ice_next := INF
var _ice_dirty := false
var _ice_baked := -100.0
## 1: diagonals are x + y; -1: x - y.
var _ice_way := 1


## game: the frost world; vfx: theme.vfx.
func _init(game: Node, vfx: Dictionary) -> void:
	g = game
	cfg = vfx
	var ramp: Dictionary = vfx.get("ice", {})
	for role: String in ICE_DEFAULT:
		C[role] = Color(str(ramp.get(role, ICE_DEFAULT[role])))
	_up = {C.deep: C.shade, C.shade: C.body, C.body: C.lite, C.lite: C.hi, C.hi: C.spec, C.spec: C.spec}
	_vapor = str(vfx.get("rime", {}).get("melt_to", "vapor")) == "vapor"


func reset() -> void:
	flashes = []
	waves = []
	g.state.knock = null
	_ice = {}
	_ice_streaks = []
	_ice_dirty = true


# ---------- the feel ----------

## The weight of an impact at `p` by its importance (`tier`: tiny, small,
## medium, large from theme.vfx.feel): a smooth view shake, a white-hot pixel
## flash, and only for the large tier a short hold of the picture. A mob's
## impact is one tier lower than the same blow of a guardian (`boss` false).
func impact(p: Vector2, tier: String, boss := true) -> void:
	var feel: Dictionary = cfg.get("feel", {})
	var order := ["tiny", "small", "medium", "large"]
	var at := order.find(tier)
	if at < 0:
		return
	if not boss:
		at = maxi(0, at - 1)
	var spec: Dictionary = feel.get(order[at], {})
	var shake := float(spec.get("shake", 0.0)) * float(feel.get("shake_scale", 1.0))
	if shake > 0.0:
		g.state.shake = maxf(float(g.state.get("shake", 0.0)), shake)
	if float(spec.get("flash", 0.0)) > 0.0:
		flashes.append({"p": p, "t": 0.0, "T": float(spec.flash), "r": float(spec.get("flash_r", 30.0))})
	var hold := float(spec.get("hitstop", 0.0))
	if hold > 0.0 and g.feel != null:
		g.feel.feedback.hitstop = maxf(float(g.feel.feedback.hitstop), hold)


## Pushes the hero away from `from` when a blow of `kind` (theme.vfx.knock)
## lands; eased out over knock.time in update. A mob pushes less.
func knock(from: Vector2, kind: String, boss := true) -> void:
	var spec: Dictionary = cfg.get("knock", {})
	var speed := float(spec.get(kind, 0.0)) * (1.0 if boss else float(spec.get("mob_scale", 0.7)))
	if speed <= 0.0:
		return
	var away := Vector2(g.player.x, g.player.y) - from
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	g.state.knock = {"v": away.normalized() * Vector2(1.0, 0.75) * speed, "t": 0.0, "T": float(spec.get("time", 0.22))}


## A blow of `kind` from `from` landed on the hero: pushed back, felt at its tier.
func hit_hero(from: Vector2, kind: String, tier: String, boss := true) -> void:
	knock(from, kind, boss)
	impact(Vector2(g.player.x, g.player.y - 30.0), tier, boss)


## Ages flashes and frost waves, moves the hero along his knockback and keeps
## the floor's ice in step with the moves' ice pools.
func update(dt: float) -> void:
	_clock += dt
	for f: Dictionary in flashes:
		f.t = float(f.t) + dt
	flashes = flashes.filter(func(f: Dictionary) -> bool: return float(f.t) < float(f.T))
	for w: Dictionary in waves:
		w.t = float(w.t) + dt
		_wave_front(w, dt)
	waves = waves.filter(func(w: Dictionary) -> bool: return float(w.t) < float(w.T))
	var K: Variant = g.state.get("knock")
	if K is Dictionary:
		K.t = float(K.t) + dt
		var k := float(K.t) / maxf(0.01, float(K.T))
		if k >= 1.0:
			g.state.knock = null
		else:
			var mv: Vector2 = (K.v as Vector2) * pow(1.0 - k, 2.0) * dt
			if mv.length() > KNOCK_STEP:
				mv = mv.normalized() * KNOCK_STEP
			if not g.box_blocked(g._player_box(g.player.x + mv.x, g.player.y)):
				g.player.x += mv.x
			if not g.box_blocked(g._player_box(g.player.x, g.player.y + mv.y)):
				g.player.y += mv.y
	_ice_update()


# ---------- the pixel physics ----------

func _phys() -> RefCounted:
	return g.feel.feedback.particles if g.feel != null else null


func _s() -> float:
	return maxf(0.1, float(g.feel.scale)) if g.feel != null else 1.0


## Ice bursting at `p`: `n` chips thrown out (along `dir` when given, else all
## round) that fly, bounce and settle as ice pixels that go again later, white
## sparkles that flash out, snow dust puffing up, and frost clumps left within `r`.
func shatter(p: Vector2, n: int, r: float, dir := Vector2.ZERO, speed := 240.0) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _s()
	var chips: Array = [C.hi, C.lite, C.body]
	for i in range(n):
		var out := dir.rotated(randf_range(-1.0, 1.0)) if dir != Vector2.ZERO else Vector2.from_angle(randf() * TAU)
		var v := Vector2(out.x, out.y * 0.7) * speed * randf_range(0.35, 1.0)
		if i % 3 == 0:
			P.emit(p / s, v * 1.2 / s, C.spec, randf_range(0.15, 0.35), "spark", 2.0, randf_range(4.0, 14.0), randf_range(30.0, 110.0) / s, 2.0)
		else:
			var chip: Dictionary = P.emit(p / s, v / s, chips[randi() % chips.size()], randf_range(0.8, 1.6), "debris", 2.0 * float(1 + int(randf() < 0.3)), randf_range(4.0, 12.0), randf_range(80.0, 220.0) / s, 2.5)
			# a chip lying on the floor goes again like the rime
			chip["melts"] = true
			chip["vapor"] = _vapor
	for i in range(maxi(2, n / 3)):
		var at := p + Vector2.from_angle(randf() * TAU) * r * 0.5 * randf()
		P.emit(at / s, Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 10.0)) / s, SNOW[randi() % SNOW.size()], randf_range(0.6, 1.1), "dust", 4.0, 3.0, 0.0, 1.5)
	rime(p, r, n)


## Frost left on the floor at `p` within `r`: about `n` crystals as opaque clumps
## (highlight ice, a few lighter arms) that go again (theme.vfx.rime).
func rime(p: Vector2, r: float, n: int) -> void:
	var P := _phys()
	if P == null or n <= 0:
		return
	var s := _s()
	P.frost_clumps(p / s, r / s, maxi(1, n / 2), [C.hi, C.hi, C.hi, C.lite], _vapor)


## Frost clumps on the band between `r0` and `r1` round `p` (squashed to the floor).
func _rime_ring(p: Vector2, r0: float, r1: float, n: int) -> void:
	var P := _phys()
	if P == null or n <= 0:
		return
	var s := _s()
	for i in range(n):
		var a := randf() * TAU
		var at := p + Vector2(cos(a), sin(a) * 0.62) * randf_range(r0, r1)
		P.frost_clumps(at / s, 0.0, 1, [C.hi, C.hi, C.lite], _vapor)


## A ring of frost bursting out from `p` to `r` over `T` s: its front is a band
## of sparkles and snow running outward, it shoves the pixels it passes
## (particles.gd blow) and leaves a ring of rime behind it.
func nova(p: Vector2, r: float, T := 0.45) -> void:
	waves.append({"p": p, "r": r, "T": T, "t": 0.0, "front": 0.0, "emit": 0.0})


func _wave_front(w: Dictionary, dt: float) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _s()
	var k := clampf(float(w.t) / float(w.T), 0.0, 1.0)
	var r1 := float(w.r) * (1.0 - pow(1.0 - k, 2.0))
	var r0 := float(w.front)
	w.front = r1
	if r1 <= r0:
		return
	P.blow((w.p as Vector2) / s, r0 / s, r1 / s, 0.0, TAU, 300.0 / s, 0.62)
	w.emit = float(w.emit) + (r1 - r0) * 1.6
	while float(w.emit) >= 1.0:
		w.emit = float(w.emit) - 1.0
		var a := randf() * TAU
		var out := Vector2(cos(a), sin(a) * 0.62)
		var at: Vector2 = (w.p as Vector2) + out * r1
		if randf() < 0.55:
			P.emit(at / s, out * randf_range(90.0, 200.0) / s, [C.spec, C.hi, C.lite][randi() % 3], randf_range(0.12, 0.3), "spark", 2.0, 3.0, randf_range(20.0, 60.0) / s, 1.0)
		else:
			P.emit(at / s, out * randf_range(30.0, 90.0) / s, SNOW[randi() % SNOW.size()], randf_range(0.5, 0.9), "dust", 4.0, 2.0, 0.0, 1.5)
	# the rime stays as a ring in the outer part of the burst
	if r1 > float(w.r) * 0.7:
		_rime_ring(w.p, maxf(r0, float(w.r) * 0.7), r1, int((r1 - r0) * 0.9))


## A breath of frost from `from` along `dir` (reach `r`, opening `arc`): cold
## mist and sparkles streaming out through the cone, slowing as they go, and
## frost laid down on the floor it swept.
func breath(from: Vector2, dir: Vector2, r: float, arc: float) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _s()
	for i in range(int(r / 5.0)):
		var a := dir.angle() + randf_range(-0.5, 0.5) * arc
		var out := Vector2.from_angle(a)
		var v := out * randf_range(0.5, 1.0) * r * 2.2
		if i % 4 == 0:
			P.emit(from / s, v / s, [C.spec, C.hi][randi() % 2], randf_range(0.2, 0.4), "spark", 2.0, 8.0, randf_range(10.0, 40.0) / s, 2.5)
		else:
			P.emit(from / s, v / s, SNOW[randi() % SNOW.size()], randf_range(0.4, 0.8), "dust", 2.0 * float(1 + int(randf() < 0.5)), 8.0, 0.0, 2.5)
	for i in range(6):
		var at := from + Vector2.from_angle(dir.angle() + randf_range(-0.4, 0.4) * arc) * r * randf_range(0.35, 0.95)
		rime(at, r * 0.18, 6)


## Snow and rime kicked up at `p` (a dash, a landing): `n` dust pixels drifting out.
func kick(p: Vector2, n: int, dir := Vector2.ZERO) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _s()
	for i in range(n):
		var out := (-dir).rotated(randf_range(-0.9, 0.9)) if dir != Vector2.ZERO else Vector2.from_angle(randf() * TAU)
		P.emit((p + Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 4.0))) / s, Vector2(out.x, out.y * 0.6) * randf_range(30.0, 120.0) / s,
			SNOW[randi() % SNOW.size()], randf_range(0.4, 0.8), "dust", 2.0 * float(1 + int(randf() < 0.4)), 2.0, 0.0, 2.0)


# ---------- the floor's ice ----------

## Takes in new ice pools of the moves and lets due cells melt (edges first).
func _ice_update() -> void:
	var spec: Dictionary = cfg.get("ice_floor", {})
	for z: Dictionary in g.state.get("mzones", []):
		if str(z.get("kind", "")) == "pool" and str(z.get("style", "")) in ["ice", "frost"] and not z.has("iced"):
			z["iced"] = true
			_ice_add(z.p, float(z.r), _clock + float(z.t), float(spec.get("edge_melt", 0.6)))
	if _ice.is_empty() and not _ice_dirty:
		return
	if _clock >= _ice_next and _clock - _ice_baked >= 1.0 / float(spec.get("rebake_hz", 15.0)):
		var gone: Array = []
		for q: Vector2i in _ice:
			if float(_ice[q]) <= _clock:
				gone.append(q)
		var P := _phys()
		for q: Vector2i in gone:
			_ice.erase(q)
			# a wisp of cold mist now and then where the ice goes
			if P != null and randf() < float(spec.get("mist", 0.03)):
				P.emit((Vector2(q) + Vector2(0.5, 0.5)) * PX / _s(), Vector2(randf_range(-8.0, 8.0), -12.0) / _s(), SNOW[0], randf_range(0.5, 0.9), "dust", 2.0, 2.0, 0.0, 1.0)
		_ice_dirty = true
	if _ice_dirty:
		_ice_bake()


## One ice pool (ellipse squashed to the floor) joins the slab: faceted (an
## octagon-ish distance and a one-pixel step per angle sector, so the rim reads
## as broken ice), each cell melting `edge` s earlier the nearer the rim;
## it covers only walkable floor, so it stops at the walls.
func _ice_add(c: Vector2, r: float, until: float, edge: float) -> void:
	var ry := r * 0.62
	var seed := randi() % 997
	for gy in range(int(floor((c.y - ry) / PX)) - 1, int(ceil((c.y + ry) / PX)) + 2):
		for gx in range(int(floor((c.x - r) / PX)) - 1, int(ceil((c.x + r) / PX)) + 2):
			var q := Vector2(gx + 0.5, gy + 0.5) * PX
			var x := (q.x - c.x) / r
			var y := (q.y - c.y) / ry
			var d := 0.7 * Vector2(x, y).length() + 0.3 * maxf(absf(x), absf(y))
			var sector := int(floor((atan2(y, x) + PI) / TAU * 9.0))
			if d <= 1.0 + (float(_h(sector, seed, 5) % 3) - 1.0) * PX / r:
				# the ice lies on the floor only: it stops at the walls
				if not g._walkable(g._cell(int(floor(q.x / g.C)), int(floor(q.y / g.C)))):
					continue
				var cell := Vector2i(gx, gy)
				_ice[cell] = maxf(float(_ice.get(cell, 0.0)), until - edge * clampf(d, 0.0, 1.0))
	_ice_streaks.append([Vector2i(((c + Vector2(-r * 0.42, -r * 0.05)) / PX).floor()), until])
	_ice_dirty = true


## Shades the slab once into a texture: body, diagonal bands of mirrored light,
## a lit north edge, a shaded south row, cracks, gloss streaks, a dark outline
## round it and the deep side of the ice under its south lip.
func _ice_bake() -> void:
	_ice_dirty = false
	_ice_baked = _clock
	_ice_streaks = _ice_streaks.filter(func(e: Array) -> bool: return float(e[1]) > _clock)
	_ice_col = {}
	_ice_diag = {}
	_ice_rim = []
	_ice_cells = []
	_ice_next = INF
	if _ice.is_empty():
		_ice_tex = null
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	_ice_lo = 1 << 30
	_ice_hi = -(1 << 30)
	for q: Vector2i in _ice:
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
		_ice_next = minf(_ice_next, float(_ice[q]))
	var box := Rect2i(lo - Vector2i(1, 1), hi - lo + Vector2i(3, 5))
	# the bands cross the slab: a slab running up to the right gets x - y
	var mean := Vector2.ZERO
	for q: Vector2i in _ice:
		mean += Vector2(q)
	mean /= float(_ice.size())
	var cov := 0.0
	var spread := 0.0
	for q: Vector2i in _ice:
		var o := Vector2(q) - mean
		cov += o.x * o.y
		spread += o.length_squared()
	_ice_way = -1 if cov < -0.15 * spread else 1
	# the ice's colours
	for q: Vector2i in _ice:
		var col: Color = C.body
		var diag := posmod(q.x + _ice_way * q.y, 30)
		if diag < 3 or diag == 5:
			col = C.lite
		if not _ice.has(q + Vector2i(0, -1)):
			col = C.hi
		elif not _ice.has(q + Vector2i(0, -2)):
			col = C.lite
		if not _ice.has(q + Vector2i(0, 1)):
			col = C.shade
		_ice_col[q] = col
	for q: Vector2i in _ice:
		if _h(q.x, q.y, 11) >= 3:
			continue
		var p := q
		for i in range(3 + _h(q.x, q.y, 12) % 3):
			if not (_ice.has(p + Vector2i(0, 2)) and _ice.has(p + Vector2i(0, -2)) and _ice.has(p + Vector2i(2, 0)) and _ice.has(p + Vector2i(-2, 0))):
				break
			_ice_col[p] = C.deep
			if _ice_col.get(p + Vector2i(1, 1), C.body) != C.deep:
				_ice_col[p + Vector2i(1, 1)] = C.hi
			p += Vector2i(1, (_h(p.x, p.y, 13) % 3) - 1)
	for e: Array in _ice_streaks:
		var at: Vector2i = e[0]
		for line: Array in [[at, 5], [at + Vector2i(2, 0), 3]]:
			for i in range(int(line[1])):
				var q: Vector2i = line[0] + Vector2i(i, -i)
				if _ice.has(q) and _ice.has(q + Vector2i(0, -1)) and _ice.has(q + Vector2i(0, 1)):
					_ice_col[q] = C.spec if i == int(line[1]) - 1 else C.hi
	if _ice_img == null or _ice_img.get_size() != box.size:
		_ice_img = Image.create_empty(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	else:
		_ice_img.fill(Color(0, 0, 0, 0))
	# outline on the sides and the top, then the deep side under the south lip, then the ice
	for q: Vector2i in _ice:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			if not _ice.has(q + d) and not _ice.has(q + d + Vector2i(0, 1)):
				_ice_img.set_pixelv(q + d - box.position, C.outline)
	for q: Vector2i in _ice:
		if not _ice.has(q + Vector2i(0, 1)):
			_ice_img.set_pixelv(q + Vector2i(0, 1) - box.position, C.deep)
			if not _ice.has(q + Vector2i(0, 2)):
				_ice_img.set_pixelv(q + Vector2i(0, 2) - box.position, C.outline)
	for q: Vector2i in _ice:
		_ice_img.set_pixelv(q - box.position, _ice_col[q])
		var key := q.x + _ice_way * q.y
		if not _ice_diag.has(key):
			_ice_diag[key] = []
		_ice_diag[key].append(q)
		_ice_lo = mini(_ice_lo, key)
		_ice_hi = maxi(_ice_hi, key)
		_ice_cells.append(q)
		if not _ice.has(q + Vector2i(1, 0)) and not _ice.has(q + Vector2i(0, -1)):
			_ice_rim.append(q)
	if _ice_tex == null or _ice_box.size != box.size:
		_ice_tex = ImageTexture.create_from_image(_ice_img)
	else:
		_ice_tex.update(_ice_img)
	_ice_box = box


## In the floor layer (story_feel.gd, between the old stains and the hero's
## shadow, in world px): the ice slab, its glint sweeping across it in a few
## frames (one ramp step brighter, two in its middle) and a sparkle popping
## where it ends, a few sparkles on the ice and twinkles on the lying rime.
func draw_floor(l: CanvasItem) -> void:
	var spec: Dictionary = cfg.get("ice_floor", {})
	if _ice_tex != null:
		l.draw_texture_rect(_ice_tex, Rect2(Vector2(_ice_box.position) * PX, Vector2(_ice_box.size) * PX), false)
		var frames := clampi((_ice_hi - _ice_lo) / 10, 4, 8)
		var f := int(floor(fmod(_clock, float(spec.get("glint_period", 2.8))) * FPS))
		if f < frames:
			var band := _ice_lo + int(float(_ice_hi - _ice_lo) * float(f) / float(frames - 1))
			for key in range(band - 2, band + 3):
				for q: Vector2i in _ice_diag.get(key, []):
					var col: Color = _ice_col[q]
					_cell(l, q, _up.get(_up.get(col, col), C.spec) if absi(key - band) <= 1 else _up.get(col, col))
		elif f < frames + 3 and not _ice_rim.is_empty():
			_pop(l, _ice_rim[_ice_rim.size() / 2], f - frames)
		_twinkle(l, _ice_cells, int(spec.get("twinkles", 3)), 0)
	var P := _phys()
	if P != null:
		var spots: Array = P.frost_sample(int(spec.get("rime_twinkles", 2)))
		for i in range(spots.size()):
			var slot := int(floor(_clock * 6.0)) + i
			if posmod(slot * 7 + i * 3, 5) == 0 and not _ice.has(spots[i]):
				_pop(l, spots[i], 1)


## Sparkles: now and then one of `cells` pops a four-point star (plus, cross, dot).
func _twinkle(l: CanvasItem, cells: Array, n: int, salt: int) -> void:
	if cells.is_empty():
		return
	for i in range(n):
		var phase := fmod(_clock * 0.9 + float(i) * 0.37 + float(salt) * 0.11, 1.0)
		if phase >= 0.25:
			continue
		var slot := int(floor(_clock * 0.9 + float(i) * 0.37 + float(salt) * 0.11))
		_pop(l, cells[posmod(slot * 7919 + i * 104729, cells.size())], mini(int(phase / 0.25 * 3.0), 2))


## A four-point sparkle in three frames at art cell `q`: plus, cross, dot.
func _pop(l: CanvasItem, q: Vector2i, frame: int) -> void:
	_cell(l, q, C.spec)
	if frame == 0:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_cell(l, q + d, C.spec)
		for d: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			_cell(l, q + d, C.hi)
	elif frame == 1:
		for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			_cell(l, q + d, C.hi)


# ---------- drawing ----------

func _h(x: int, y: int, s := 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) % 1000


## True when art cell `q` shows at coverage `k` (0..1) of the ordered dither.
func _shown(q: Vector2i, k: float) -> bool:
	return float(BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)]) < k * 16.0


func _cell(l: CanvasItem, q: Vector2i, col: Color) -> void:
	l.draw_rect(Rect2(Vector2(q) * PX, Vector2(PX, PX)), col)


func _px(l: CanvasItem, p: Vector2, col: Color, size := 1) -> void:
	l.draw_rect(Rect2((p / PX).floor() * PX, Vector2.ONE * PX * float(size)), col)


## An ellipse outline on the pixel grid: one block per step, every `every`-th
## block (crawling with `phase`).
func px_ellipse(l: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, every := 1, phase := 0) -> void:
	if rx < PX or ry <= 0.0:
		return
	var n := maxi(12, int(TAU * maxf(rx, ry) / PX))
	var last := Vector2i(1 << 30, 0)
	for k in range(n):
		if every > 1 and posmod(k + phase, every) != 0:
			continue
		var a := float(k) / float(n) * TAU
		var q := Vector2i(((c + Vector2(cos(a) * rx, sin(a) * ry)) / PX).floor())
		if q == last:
			continue
		last = q
		l.draw_rect(Rect2(Vector2(q) * PX, Vector2.ONE * PX), col)


## A round warning (squashed to the floor): a dot grid filling it, a dashed rim
## crawling round it over a dark underlay and an inner ring growing out to it
## as `k` runs 0..1.
func ring(l: CanvasItem, c: Vector2, r: float, k: float, col: Color, t: float) -> void:
	var ry := r * 0.62
	var step := 4 if k > 0.6 else 5
	var x0 := int(floor((c.x - r) / PX / step))
	var x1 := int(ceil((c.x + r) / PX / step))
	var y0 := int(floor((c.y - ry) / PX / step))
	var y1 := int(ceil((c.y + ry) / PX / step))
	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			var q := Vector2(gx, gy) * PX * float(step)
			if Vector2((q.x - c.x) / r, (q.y - c.y) / ry).length() <= 1.0:
				l.draw_rect(Rect2(q, Vector2.ONE * PX), Color(col, 0.22 + 0.25 * k))
	var every := 3 if k < 0.7 else 2
	var crawl := int(floorf(t * FPS))
	px_ellipse(l, c + Vector2(0, PX), r, ry, Color(C.outline, 0.8), every, crawl)
	px_ellipse(l, c, r, ry, Color(col, 0.95), every, crawl)
	px_ellipse(l, c + Vector2(0, PX), r * k, ry * k, Color(C.outline, 0.6))
	px_ellipse(l, c, r * k, ry * k, Color(col, 0.8))


## A lane warning from `from` along `dir`: dashed edges crawling over a dark
## underlay, a dot grid inside and a bar filling it as `k` runs 0..1.
func strip(l: CanvasItem, from: Vector2, dir: Vector2, length: float, half: float, k: float, col: Color, t: float) -> void:
	var side := dir.orthogonal()
	var crawl := int(floorf(t * FPS))
	var steps := int(length / PX)
	var lit := {}
	for i in range(steps):
		var p := from + dir * float(i) * PX
		if posmod(i - crawl, 3) != 2:
			for e: float in [-half, half]:
				_px(l, p + side * e + Vector2(0, PX), Color(C.outline, 0.8))
				_px(l, p + side * e, Color(col, 0.95))
		for o in range(int(-half / PX) + 1, int(half / PX)):
			var q := Vector2i(((p + side * float(o) * PX) / PX).floor())
			if posmod(q.x, 4) == 0 and posmod(q.y, 4) == 0 and not lit.has(q):
				lit[q] = true
				l.draw_rect(Rect2(Vector2(q) * PX, Vector2.ONE * PX), Color(col, 0.22 + 0.25 * k))
		if float(i) / float(maxi(1, steps)) <= k:
			_px(l, p, Color(col, 0.8))


## A cone warning from `from` (reach `r`, opening `arc` round `ang`): a dot
## grid inside, crawling dashed edges and arc over a dark underlay, a front
## growing out with `k`.
func cone(l: CanvasItem, from: Vector2, r: float, ang: float, arc: float, k: float, col: Color, t: float) -> void:
	var crawl := int(floorf(t * FPS))
	var step := 4 if k > 0.6 else 5
	var x0 := int(floor((from.x - r) / PX / step))
	var x1 := int(ceil((from.x + r) / PX / step))
	var y0 := int(floor((from.y - r) / PX / step))
	var y1 := int(ceil((from.y + r) / PX / step))
	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			var q := Vector2(gx, gy) * PX * float(step)
			var rel := q - from
			if rel.length() <= r and absf(angle_difference(rel.angle(), ang)) < arc / 2.0:
				l.draw_rect(Rect2(q, Vector2.ONE * PX), Color(col, 0.22 + 0.25 * k))
	for pass_i in range(2):
		var under := pass_i == 0
		var off := Vector2(0, PX) if under else Vector2.ZERO
		for e: float in [ang - arc / 2.0, ang + arc / 2.0]:
			var dir := Vector2.from_angle(e)
			for i in range(int(r / PX)):
				if posmod(i - crawl, 3) != 2:
					_px(l, from + dir * float(i) * PX + off, Color(C.outline, 0.8) if under else Color(col, 0.95))
		for rr: float in [r, r * k]:
			var n := maxi(6, int(arc * rr / PX))
			for i in range(n + 1):
				if rr == r and posmod(i - crawl, 3) == 2:
					continue
				_px(l, from + Vector2.from_angle(ang - arc / 2.0 + arc * float(i) / float(n)) * rr + off, Color(C.outline, 0.7) if under else Color(col, 0.95 if rr == r else 0.8))


## An ice shard in flight at `p` along `v` (`size` blocks of the old 4 px grid,
## drawn about as long on the art pixel): a pointed blade, white tip with a
## specular block behind it, lit upper face, shaded lower face, an outline on
## its underside, opaque; frost sparkles flicker behind it.
func shard(l: CanvasItem, p: Vector2, v: Vector2, size: int, t: float, seed: float) -> void:
	var d := v.normalized() if v.length() > 1.0 else Vector2.RIGHT
	var side := d.orthogonal()
	if side.y > 0.0:
		side = -side
	var n := int(round(float(size) * 4.0 / 3.0)) + 1
	var cells := {}
	for i in range(n + 1):
		var c := Vector2i(((p - d * float(i) * PX) / PX).floor())
		var col: Color = C.spec if i <= 1 else C.hi if i <= 3 else C.lite if i <= n / 2 else C.body if i < n else C.shade
		cells[c] = col
		if i >= 1 and i <= n - 2:
			var up := Vector2i(((p - d * float(i) * PX + side * PX) / PX).floor())
			var dn := Vector2i(((p - d * float(i) * PX - side * PX) / PX).floor())
			if not cells.has(up):
				cells[up] = C.hi if i <= 3 else C.lite
			if not cells.has(dn):
				cells[dn] = C.shade
	for c: Vector2i in cells:
		if not cells.has(c + Vector2i(0, 1)):
			_cell(l, c + Vector2i(0, 1), C.outline)
	for c: Vector2i in cells:
		_cell(l, c, cells[c])
	var tq := floorf(t * FPS)
	for i in range(3):
		if sin(tq * 2.3 + float(i) * 1.9 + seed) > 0.1:
			_px(l, p - d * float(n + 2 + i * 2) * PX + side * PX * sin(float(i) * 2.0 + seed), Color(C.hi, 0.9 - 0.25 * float(i)))


## A hailstone falling to `to` (`size` blocks of the old 4 px grid): a faceted
## lump of ice at height `h` above it, lit facets top-left, shaded bottom-right,
## outlined, with a specular pixel and a short streak; its shadow on the floor
## (dithered, growing as it nears with `k`).
func hailstone(l: CanvasItem, to: Vector2, h: float, size: int, k: float) -> void:
	var n := size + 1
	var base := Vector2i((to / PX).floor())
	var cover := 0.35 + 0.5 * k
	for gy in range(-n, n + 1):
		for gx in range(-n - 1, n + 2):
			if Vector2(float(gx) / (float(n) + 1.0), float(gy) / (float(n) * 0.45 + 0.5)).length() <= 0.6 + 0.4 * k:
				var q := base + Vector2i(gx, gy)
				if _shown(q, cover):
					_cell(l, q, C.outline)
	var c := Vector2i(((to - Vector2(0, h)) / PX).floor())
	var m := {}
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			if maxf(absf(float(x)) * 0.87 + absf(float(y)) * 0.5, absf(float(y))) <= float(n) + 0.3:
				m[Vector2i(x, y)] = true
	for q: Vector2i in m:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not m.has(q + d):
				_cell(l, c + q + d, C.outline)
	for q: Vector2i in m:
		var lit := q.x + q.y
		_cell(l, c + q, C.hi if lit <= -n else C.lite if lit < 0 else C.body if lit < n else C.shade)
	_cell(l, c + Vector2i(-n / 2, -n / 2), C.spec)
	_cell(l, c + Vector2i(-n / 2 + 1, -n / 2 - 1), C.spec)
	_cell(l, c + Vector2i(1, 1), C.hi)
	_cell(l, c + Vector2i(2, 0), C.hi)
	# a streak of falling frost above it
	for i in range(1, 4):
		_cell(l, c - Vector2i(0, n + i * 2), Color(C.hi, 0.7 - 0.18 * float(i)))


## A guardian's ice armour round `c` (radius `r`): a cage of pointed crystals
## standing round it on the floor, each with a white ridge, a lit and a shaded
## face and an outline, the back ones a ramp step deeper, glinting one after
## another with a sparkle at the tip; `k` 0..1 its strength (it thins out as
## it runs down), `tall_base` the crystals' height in blocks of the old 4 px grid.
func armor(l: CanvasItem, c: Vector2, r: float, k: float, t: float, tall_base := 3) -> void:
	var tq := int(floorf(t * FPS))
	var n := 8 + tall_base
	var order: Array = []
	for i in range(n):
		order.append(i)
	# back crystals first, the front ones over them
	order.sort_custom(func(a: int, b: int) -> bool: return sin(TAU * float(a) / float(n) + 0.3) < sin(TAU * float(b) / float(n) + 0.3))
	for i: int in order:
		if float(i) / float(n) > k + 0.05:
			continue
		var a := TAU * float(i) / float(n) + 0.3
		var base := Vector2i(((c + Vector2(cos(a) * r, sin(a) * r * 0.62)) / PX).floor())
		var back := sin(a) < 0.0
		var tall := int(round(float(tall_base + (i * 7) % 3 + 2) * 4.0 / 3.0))
		var wide := maxi(1, tall / 3)
		var lean := 0.25 * cos(a)
		var glint := posmod(tq - i * 2, n * 2) < 2
		var cells := {}
		for j in range(tall):
			var w := maxi(0, int(round(float(wide) * (1.0 - float(j) / float(tall)))))
			var row := base + Vector2i(int(round(lean * float(j))), -j)
			for x in range(-w, w + 1):
				var col: Color = C.hi if x == 0 else C.lite if x > 0 else C.shade
				if back:
					col = C.lite if x == 0 else C.body if x > 0 else C.deep
				cells[row + Vector2i(x, 0)] = col
			if j == tall - 1:
				cells[row] = C.spec if glint else C.hi
		for q: Vector2i in cells:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if not cells.has(q + d):
					_cell(l, q + d, C.outline)
		for q: Vector2i in cells:
			_cell(l, q, cells[q])
		if glint:
			_pop(l, base + Vector2i(int(round(lean * float(tall))), -tall), posmod(tq - i * 2, n * 2))


## The white-hot flashes of impacts: a disc of blocks shrinking as it fades,
## thinned by the ordered dither instead of turning transparent.
func draw_flashes(l: CanvasItem) -> void:
	for f: Dictionary in flashes:
		var k := float(f.t) / maxf(0.01, float(f.T))
		var r := float(f.r) * (1.0 - 0.5 * k)
		var ry := r * 0.7
		var c: Vector2 = f.p
		for gy in range(int(floor((c.y - ry) / PX)), int(ceil((c.y + ry) / PX)) + 1):
			for gx in range(int(floor((c.x - r) / PX)), int(ceil((c.x + r) / PX)) + 1):
				var q := Vector2(gx, gy) * PX
				var d := Vector2((q.x - c.x) / r, (q.y - c.y) / ry).length()
				if d <= 1.0 and _shown(Vector2i(gx, gy), (1.0 - k) * (1.0 - d * 0.6)):
					l.draw_rect(Rect2(q, Vector2.ONE * PX), C.spec if d < 0.5 else C.hi)
