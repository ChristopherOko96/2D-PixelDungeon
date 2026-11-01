class_name MatterKit
extends RefCounted
## The pixel-grid primitives every matter system draws and spreads with (BAUPLAN
## M1a), in one home:
## - units: world px, art px (`art` world px per art pixel: the crypt 2, the
##   story worlds 3; assets/data/physics_matter.json) and crypt units;
## - the 4x4 ordered (Bayer) dither: shapes fade or fill by whole pixels, never
##   by transparency;
## - hashes and smooth cell noise (fixed per cell, so nothing flickers);
## - the wall clip (Clip): where pixels may show, asked of the game once per art
##   cell and remembered;
## - whole-pixel shapes (cell, paint, bake, ellipse, disc, warning, burst, lane,
##   cone, ball) that take the clip as an argument;
## - the splat flood: the cells a splat of liquid covers on the art grid.
##
## Pure and static: no global state, no game access. The game talks to it only
## through a clip built from a Callable(world point) -> bool or from a host
## (src/physics_kit/matter_host.gd, the contract). src/vfx/pixel_paint.gd and
## src/vfx/splat_shape.gd forward to it for their old consumers.
##
## [codeblock]
## var clip := MatterKit.clip_of(func(p: Vector2) -> bool: return p.x < 300.0)
## MatterKit.disc(self, Vector2(280, 100), 60, 40, Color.RED, 3.0, 0.5, clip)
## var splat := MatterKit.flood(Vector2(100, 100), Vector2.RIGHT, 300, 3.0, clip.open, 7)
## [/codeblock]

const DATA_PATH := "res://assets/data/physics_matter.json"
## The host contract (extend it in a game adapter; see clip_for).
const Host := preload("res://src/physics_kit/matter_host.gd")
## 4x4 ordered dither thresholds (0..15), row by row.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## Frames per second of crawling rims and blinks.
const FPS := 12.0
## The splat flood's steps to the eight neighbours.
const FLOOD_STEPS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
## The splat flood's cost buckets per unit of path cost.
const FLOOD_QUANT := 4.0
## Art px per cell of the splat rim's noise.
const FLOOD_NOISE_CELLS := 3
## Where a landing splat looks for open floor (art px round its landing cell).
const FLOOD_SEARCH := 8


## physics_matter.json (shared and read-only, src/core/data_cache.gd).
static func settings() -> Dictionary:
	return DataCache.load_dict(DATA_PATH)


# ---------- units ----------

## World px per art pixel in the crypt (the crypt px all crypt effects use).
static func crypt_art() -> float:
	return float((settings().get("units", {}) as Dictionary).get("crypt_art_px", 2.0))


## World px per art pixel in the story worlds (their floor tiles' art pixel).
static func story_art() -> float:
	return float((settings().get("units", {}) as Dictionary).get("story_art_px", 3.0))


## World px per crypt px in a world whose art pixel is `world_art` world px
## (1 in the crypt, 1.5 in the story worlds).
static func crypt_scale(world_art: float) -> float:
	return world_art / crypt_art()


## A length or point in world px of a world with art pixel `world_art`, in crypt units.
static func to_crypt(world: Variant, world_art: float) -> Variant:
	return world / crypt_scale(world_art)


## A length or point in crypt units, in world px of a world with art pixel `world_art`.
static func from_crypt(crypt: Variant, world_art: float) -> Variant:
	return crypt * crypt_scale(world_art)


## The art cell holding world point `p` (`art` world px per art pixel).
static func at(p: Vector2, art: float) -> Vector2i:
	return Vector2i((p / art).floor())


## The world point in the middle of art cell `q`.
static func cell_centre(q: Vector2i, art: float) -> Vector2:
	return (Vector2(q) + Vector2(0.5, 0.5)) * art


# ---------- the ordered dither ----------

## The dither threshold (0..15) of art cell `q`.
static func bayer(q: Vector2i) -> float:
	return float(BAYER[((q.y & 3) << 2) | (q.x & 3)])


## The dither threshold (0..15) of art cell (`x`, `y`).
static func bayer_xy(x: int, y: int) -> float:
	return float(BAYER[((y & 3) << 2) | (x & 3)])


## True when art cell `q` shows at coverage `k` (0..1).
static func shown(q: Vector2i, k: float) -> bool:
	return float(BAYER[((q.y & 3) << 2) | (q.x & 3)]) < k * 16.0


# ---------- hashes and noise ----------

## A fixed hash 0..999 of (`x`, `y`) under seed `s`.
static func hash3(x: int, y: int, s := 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) % 1000


## hash3 as 0..0.999.
static func hash01(x: int, y: int, s := 0) -> float:
	return float(absi((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) % 1000) / 1000.0


## Smooth value noise 0..1 at art cell (`x`, `y`) over cells of `size` art px.
static func value_noise(x: int, y: int, size: int, s: int) -> float:
	var fx := float(x) / float(size)
	var fy := float(y) / float(size)
	var gx := floori(fx)
	var gy := floori(fy)
	var u := fx - float(gx)
	var v := fy - float(gy)
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var a := float(hash3(gx, gy, s)) / 1000.0
	var b := float(hash3(gx + 1, gy, s)) / 1000.0
	var c := float(hash3(gx, gy + 1, s)) / 1000.0
	var e := float(hash3(gx + 1, gy + 1, s)) / 1000.0
	return lerpf(lerpf(a, b, u), lerpf(c, e, u), v)


## Smooth value noise 0..1 at (`x`, `y`) (0..period-1) over cells of `size`
## that tiles every `period` (a multiple of `size`); its lattice is hash01 seeded by `size`.
static func tiling_noise(x: int, y: int, size: int, period: int) -> float:
	var span := period / size
	var fx := float(x) / float(size)
	var fy := float(y) / float(size)
	var gx := int(floor(fx))
	var gy := int(floor(fy))
	var u := fx - float(gx)
	var v := fy - float(gy)
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var a := hash01(gx % span, gy % span, size)
	var b := hash01((gx + 1) % span, gy % span, size)
	var c := hash01(gx % span, (gy + 1) % span, size)
	var e := hash01((gx + 1) % span, (gy + 1) % span, size)
	return lerpf(lerpf(a, b, u), lerpf(c, e, u), v)


## A fixed 0..1 value per art cell `q` under `seed` (so crystals and grain do not flicker).
static func cell_noise(q: Vector2i, seed: int) -> float:
	var h := (q.x * 374761393 + q.y * 668265263 + seed * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) % 1024) / 1024.0


# ---------- the wall clip ----------

## A wall clip: where pixels may show and liquid may flow, asked of the game
## once per art cell (at its middle) and remembered. Built by clip_of (a bare
## Callable: it forgets after physics_matter.json clip.refresh_s, since it
## cannot tell when a wall breaks) or clip_for (a host: it forgets when the
## host's wall_revision changes). Every MatterKit shape takes one; null draws everywhere.
class Clip extends RefCounted:
	## Callable(world point) -> bool, true on open floor (asked when `host` is null).
	var open: Callable
	## The host (src/physics_kit/matter_host.gd) or null.
	var host: RefCounted = null
	## Answers remembered at most (then it starts afresh).
	var memo_max := 200000
	## Milliseconds a clip without a host keeps its answers.
	var refresh_ms := 3000
	var _memo: Dictionary = {}
	var _rev := 0
	var _since := 0

	## What the clip said per art cell (Vector3i(x, y, art) -> open), started
	## afresh when the walls may have changed and when full. For loops over many
	## cells that ask it themselves.
	func memo() -> Dictionary:
		if host != null:
			var rev: int = host.wall_revision()
			if rev != _rev or _memo.size() > memo_max:
				_rev = rev
				_memo.clear()
		else:
			var now := Time.get_ticks_msec()
			if now - _since > refresh_ms or _memo.size() > memo_max:
				_since = now
				_memo.clear()
		return _memo

	## True when `world_point` is open floor (asked now, not remembered).
	func is_open(world_point: Vector2) -> bool:
		return bool(host.is_open(world_point)) if host != null else bool(open.call(world_point))

	## True when art cell `q` (`art` world px each) shows, remembered.
	func open_cell(q: Vector2i, art: float) -> bool:
		var m := memo()
		var key := Vector3i(q.x, q.y, int(art))
		var ok: Variant = m.get(key)
		if ok == null:
			ok = host.is_open((Vector2(q) + Vector2(0.5, 0.5)) * art) if host != null else open.call((Vector2(q) + Vector2(0.5, 0.5)) * art)
			m[key] = ok
		return bool(ok)

	## Drops every remembered answer (a host that cannot count its walls may call it).
	func forget() -> void:
		_memo.clear()


## A clip asking `open` (Callable(world point) -> bool, true on open floor).
static func clip_of(open: Callable) -> Clip:
	var clip := Clip.new()
	clip.open = open
	_configure(clip)
	return clip


## A clip asking `host` (extends src/physics_kit/matter_host.gd), forgetting on its wall_revision.
static func clip_for(host: RefCounted) -> Clip:
	var clip := Clip.new()
	clip.host = host
	clip.open = Callable(host, "is_open")
	clip._rev = int(host.wall_revision())
	_configure(clip)
	return clip


static func _configure(clip: Clip) -> void:
	var c: Dictionary = settings().get("clip", {})
	clip.memo_max = int(c.get("memo_max", 200000))
	clip.refresh_ms = int(float(c.get("refresh_s", 3.0)) * 1000.0)
	clip._since = Time.get_ticks_msec()


# ---------- whole-pixel shapes ----------

## Draws art cell `q` in `col` on `canvas` (a CanvasItem or a Recorder), unless `clip` hides it.
static func cell(canvas: Object, q: Vector2i, col: Color, art: float, clip: Clip = null) -> void:
	if clip != null and not clip.open_cell(q, art):
		return
	canvas.draw_rect(Rect2(Vector2(q) * art, Vector2(art, art)), col)


## Draws a map of art cells (Vector2i -> Color) as cell() would draw each of
## them, in its order and cut by `clip`; the clip's memo asked here, not per
## call (a third of the cost for many cells).
static func paint(canvas: Object, cells: Dictionary, art: float, clip: Clip = null) -> void:
	var size := Vector2(art, art)
	if clip == null:
		for q: Vector2i in cells:
			canvas.draw_rect(Rect2(Vector2(q) * art, size), cells[q])
		return
	var memo := clip.memo()
	var a := int(art)
	for q: Vector2i in cells:
		var key := Vector3i(q.x, q.y, a)
		var open: Variant = memo.get(key)
		if open == null:
			open = clip.is_open((Vector2(q) + Vector2(0.5, 0.5)) * art)
			memo[key] = open
		if open:
			canvas.draw_rect(Rect2(Vector2(q) * art, size), cells[q])


## A drawing target that records the cells drawn on it ([cell, colour, ...]
## in cells) instead of drawing them, for bake(): the shapes here take it
## where they take a CanvasItem (only draw_rect).
class Recorder extends RefCounted:
	## World px per art pixel of what is drawn on it.
	var art := 2.0
	## [cell, colour, cell, colour, ...] in drawing order.
	var cells: Array = []

	## Records the art cell of `rect` with `color` (the other arguments as CanvasItem.draw_rect).
	func draw_rect(rect: Rect2, color: Color, _filled := true, _width := -1.0, _antialiased := false) -> void:
		cells.append(Vector2i((rect.position / art).round()))
		cells.append(color)


## A list of opaque cells and colours ([cell, colour, cell, colour, ...], later
## ones over earlier ones, as cell() would draw them; cut by `clip` now) as one
## picture: {tex, at (first art cell), size}; empty for no cells. For effects
## that change on a beat: bake once per beat, draw_baked every frame.
static func bake(draw: Array, art: float, clip: Clip = null) -> Dictionary:
	if draw.is_empty():
		return {}
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for i in range(0, draw.size(), 2):
		var q: Vector2i = draw[i]
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	var w := hi.x - lo.x + 1
	var h := hi.y - lo.y + 1
	var px := PackedByteArray()
	px.resize(w * h * 4)
	for i in range(0, draw.size(), 2):
		var q: Vector2i = draw[i]
		if clip != null and not clip.open_cell(q, art):
			continue
		var c: Color = draw[i + 1]
		var b := ((q.y - lo.y) * w + q.x - lo.x) * 4
		px[b] = c.r8
		px[b + 1] = c.g8
		px[b + 2] = c.b8
		px[b + 3] = 255
	return {"tex": ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)), "at": lo, "size": Vector2i(w, h)}


## Draws a picture from bake().
static func draw_baked(canvas: CanvasItem, baked: Dictionary, art: float) -> void:
	if baked.is_empty():
		return
	canvas.draw_texture_rect(baked.tex, Rect2(Vector2(baked.at) * art, Vector2(baked.size) * art), false)


## An ellipse rim of whole pixels; every `every`-th pixel (crawling with `phase`).
static func ellipse(canvas: Object, c: Vector2, rx: float, ry: float, col: Color, art: float, every := 1, phase := 0, clip: Clip = null) -> void:
	if rx < art or ry < art:
		return
	var n := maxi(12, int(TAU * maxf(rx, ry) / art))
	var last := Vector2i(1 << 30, 0)
	for k in range(n):
		if every > 1 and posmod(k + phase, every) != 0:
			continue
		var a := float(k) / float(n) * TAU
		var q := at(c + Vector2(cos(a) * rx, sin(a) * ry), art)
		if q == last:
			continue
		last = q
		cell(canvas, q, col, art, clip)


## A filled ellipse of whole pixels at dither coverage `cover`.
static func disc(canvas: Object, c: Vector2, rx: float, ry: float, col: Color, art: float, cover := 1.0, clip: Clip = null) -> void:
	if cover <= 0.0:
		return
	for gy in range(int(floor((c.y - ry) / art)), int(ceil((c.y + ry) / art)) + 1):
		for gx in range(int(floor((c.x - rx) / art)), int(ceil((c.x + rx) / art)) + 1):
			var p := (Vector2(gx, gy) + Vector2(0.5, 0.5)) * art
			if Vector2((p.x - c.x) / rx, (p.y - c.y) / ry).length() <= 1.0 and (cover >= 1.0 or shown(Vector2i(gx, gy), cover)):
				cell(canvas, Vector2i(gx, gy), col, art, clip)


## A warning on the floor that strikes when `k` reaches 1: its area filling up
## by the dither (sparse to dense), a dashed rim crawling round over a dark
## underlay (blinking faster near the end) and a ring growing from the middle.
static func warning(canvas: Object, c: Vector2, rx: float, ry: float, k: float, col: Color, ink: Color, art: float, t: float, clip: Clip = null) -> void:
	var fill := col.darkened(0.45)
	disc(canvas, c, rx, ry, fill, art, 0.12 + 0.38 * k, clip)
	var crawl := int(floorf(t * FPS))
	var every := 3 if k < 0.7 else 2
	var lit := k < 0.75 or posmod(int(floorf(t * FPS * (1.0 + 2.0 * k))), 2) == 0
	ellipse(canvas, c + Vector2(0, art), rx, ry, ink, art, every, crawl, clip)
	ellipse(canvas, c, rx, ry, col if lit else col.darkened(0.3), art, every, crawl, clip)
	if k > 0.05:
		ellipse(canvas, c + Vector2(0, art), rx * k, ry * k, ink, art, 1, 0, clip)
		ellipse(canvas, c, rx * k, ry * k, col.lightened(0.25), art, 1, 0, clip)


## The moment a warning strikes (`k` 0..1 of the burst): a bright ring
## running out and a flash in the middle, both thinning by the dither.
static func burst(canvas: CanvasItem, c: Vector2, rx: float, ry: float, k: float, col: Color, art: float, clip: Clip = null) -> void:
	var grow := 0.6 + 0.6 * k
	disc(canvas, c, rx * grow, ry * grow, col.lightened(0.5), art, 0.9 * (1.0 - k), clip)
	for w in range(2):
		var s := 1.0 + 0.5 * k + float(w) * art / maxf(rx, 1.0)
		ellipse(canvas, c, rx * s, ry * s, col if w == 0 else col.darkened(0.3), art, 1 if k < 0.5 else 2, 0, clip)


## A lane warning from `from` to `to` (`half` its half width): dashed edges
## crawling over a dark underlay, its area filling by the dither, a bar
## running down it as `k` runs 0..1.
static func lane(canvas: CanvasItem, from: Vector2, to: Vector2, half: float, k: float, col: Color, ink: Color, art: float, t: float, clip: Clip = null) -> void:
	var length := from.distance_to(to)
	if length < art:
		return
	var dir := (to - from) / length
	var side := dir.orthogonal()
	var crawl := int(floorf(t * FPS))
	var steps := int(length / art)
	var seen := {}
	var fill := col.darkened(0.45)
	for i in range(steps):
		var p := from + dir * float(i) * art
		for o in range(int(-half / art) + 1, int(half / art)):
			var q := at(p + side * float(o) * art, art)
			if not seen.has(q):
				seen[q] = true
				if shown(q, 0.12 + 0.38 * k):
					cell(canvas, q, fill, art, clip)
		if posmod(i - crawl, 3) != 2:
			for e: float in [-half, half]:
				cell(canvas, at(p + side * e + Vector2(0, art), art), ink, art, clip)
				cell(canvas, at(p + side * e, art), col, art, clip)
		if float(i) / float(maxi(1, steps)) <= k:
			cell(canvas, at(p, art), col.lightened(0.25), art, clip)


## A cone warning from `from` (reach `r`, opening `arc` round `ang`): its area
## filling by the dither, crawling dashed edges and arc over a dark underlay,
## a front running out with `k`.
static func cone(canvas: CanvasItem, from: Vector2, r: float, ang: float, arc: float, k: float, col: Color, ink: Color, art: float, t: float, clip: Clip = null) -> void:
	var crawl := int(floorf(t * FPS))
	var fill := col.darkened(0.45)
	for gy in range(int(floor((from.y - r) / art)), int(ceil((from.y + r) / art)) + 1):
		for gx in range(int(floor((from.x - r) / art)), int(ceil((from.x + r) / art)) + 1):
			var p := (Vector2(gx, gy) + Vector2(0.5, 0.5)) * art
			var rel := p - from
			if rel.length() <= r and absf(angle_difference(rel.angle(), ang)) < arc / 2.0 and shown(Vector2i(gx, gy), 0.12 + 0.38 * k):
				cell(canvas, Vector2i(gx, gy), fill, art, clip)
	for pass_i in range(2):
		var off := Vector2(0, art) if pass_i == 0 else Vector2.ZERO
		var c: Color = ink if pass_i == 0 else col
		for e: float in [ang - arc / 2.0, ang + arc / 2.0]:
			var dir := Vector2.from_angle(e)
			for i in range(int(r / art)):
				if posmod(i - crawl, 3) != 2:
					cell(canvas, at(from + dir * float(i) * art + off, art), c, art, clip)
		for rr: float in [r, r * k]:
			if rr < art:
				continue
			var n := maxi(6, int(arc * rr / art))
			for i in range(n + 1):
				if rr == r and posmod(i - crawl, 3) == 2:
					continue
				cell(canvas, at(from + Vector2.from_angle(ang - arc / 2.0 + arc * float(i) / float(n)) * rr + off, art), c if rr == r or pass_i == 0 else col.lightened(0.25), art, clip)


## A ball of the ramp `cols` (white-hot first, edge last) `r` art px round at
## `p` with an outline `ink` (an orb, a glob in flight).
static func ball(canvas: CanvasItem, p: Vector2, r: int, cols: Array, ink: Color, art: float, clip: Clip = null) -> void:
	var c := at(p, art)
	for y in range(-r - 1, r + 2):
		for x in range(-r - 1, r + 2):
			var d := Vector2(x, y).length()
			if d <= float(r) + 0.5:
				var lit := Vector2(float(x) + float(r) * 0.35, float(y) + float(r) * 0.35).length() / maxf(1.0, float(r))
				cell(canvas, c + Vector2i(x, y), cols[clampi(int(lit * float(cols.size() - 1)), 0, cols.size() - 1)], art, clip)
			elif d <= float(r) + 1.5:
				cell(canvas, c + Vector2i(x, y), ink, art, clip)


# ---------- the splat flood ----------

## Cells (Vector2i art px -> rank 0..n-1, the order the liquid reached them) of
## a splat of `count` cells landing at `origin` (world px) moving along `dir`
## (ZERO: straight down, a round blot). The liquid runs out cell by cell from
## the landing point, cheapest first (a Dijkstra flood over the art pixels): a
## step along the flight costs less (it keeps sliding that way), a step up or
## down the screen costs more (the floor seen at a slant), and a little smooth
## noise roughens the rim. Walls and solid props stop it; the volume it could
## not spend there runs on along them (a corner fills, open floor gets a
## stretched blot). `art`: world px per art pixel; `open`: Callable(world point)
## -> bool, true on floor the liquid may cover; `seed` varies the rim;
## `squash` < 1 flattens it; `momentum` 0..1 how strongly it runs on along the
## flight; `droplets` how many drops a fast splat flings ahead. Pure and
## deterministic (same inputs, same cells) and safe on a worker thread.
static func flood(origin: Vector2, dir: Vector2, count: int, art: float, open: Callable, seed: int,
		squash := 0.75, momentum := 0.5, droplets := 0) -> Dictionary:
	var out := {}
	if count <= 0:
		return out
	var memo := {}
	var start := _nearest_open(Vector2i((origin / art).floor()), art, open, memo)
	if start == Vector2i(1 << 30, 1 << 30):
		return out
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	var main := count - _droplet_budget(count, droplets)
	_spread(out, start, d, main, art, open, memo, seed, squash, momentum)
	if droplets > 0 and d != Vector2.ZERO:
		_fling(out, start, d, count - main, droplets, art, open, memo, seed, squash)
	return out


## Cell count for a splat that covers about the area of a circle of `radius`
## world px (squashed like the floor), so a pool keeps its old volume.
static func cells_for(radius: float, art: float, squash := 0.75) -> int:
	return maxi(4, int(PI * radius * radius * squash / (art * art)))


## How many cells the droplets take from the volume.
static func _droplet_budget(count: int, droplets: int) -> int:
	return 0 if droplets <= 0 else mini(count / 5, droplets * maxi(3, count / 60))


static func _spread(out: Dictionary, start: Vector2i, d: Vector2, count: int, art: float, open: Callable, memo: Dictionary,
		seed: int, squash: float, momentum: float) -> void:
	# per step: its length on the slanted floor and how much it runs along the
	# flight, worked out once (the same numbers as working them out per step)
	var lengths: Array = []
	var alongs: Array = []
	for step: Vector2i in FLOOD_STEPS:
		var v := Vector2(step)
		lengths.append(Vector2(v.x, v.y / squash).length())
		alongs.append(d.dot(v.normalized()) if d != Vector2.ZERO else 0.0)
	# each cell's rim noise once (the walls are asked once per cell through `memo`)
	var rough := {}
	var best := {start: 0.0}
	var buckets: Array = [[start]]
	var at_bucket := 0
	var target := out.size() + count
	while out.size() < target and at_bucket < buckets.size():
		var bucket: Array = buckets[at_bucket]
		if bucket.is_empty():
			at_bucket += 1
			continue
		var q: Vector2i = bucket.pop_back()
		if out.has(q):
			continue
		out[q] = out.size()
		var here: float = best[q]
		for s in range(8):
			var step: Vector2i = FLOOD_STEPS[s]
			var n: Vector2i = q + step
			if out.has(n):
				continue
			var ok: Variant = memo.get(n)
			if ok == null:
				ok = open.call((Vector2(n) + Vector2(0.5, 0.5)) * art)
				memo[n] = ok
			if not ok:
				continue
			# a diagonal only through an open corner, so nothing leaks through a wall seam
			if step.x != 0 and step.y != 0:
				var side := q + Vector2i(step.x, 0)
				var free: Variant = memo.get(side)
				if free == null:
					free = open.call((Vector2(side) + Vector2(0.5, 0.5)) * art)
					memo[side] = free
				if not free:
					continue
				side = q + Vector2i(0, step.y)
				free = memo.get(side)
				if free == null:
					free = open.call((Vector2(side) + Vector2(0.5, 0.5)) * art)
					memo[side] = free
				if not free:
					continue
			var noise: Variant = rough.get(n)
			if noise == null:
				noise = value_noise(n.x, n.y, FLOOD_NOISE_CELLS, seed)
				rough[n] = noise
			var cost: float = here + float(lengths[s]) * (1.0 - 0.6 * momentum * float(alongs[s])) * (0.7 + 0.6 * float(noise))
			if cost < float(best.get(n, INF)):
				best[n] = cost
				var k := int(cost * FLOOD_QUANT)
				while buckets.size() <= k:
					buckets.append([])
				buckets[k].append(n)


## A few drops flung ahead along `d`: each a small blot of its own where it
## lands, only where the flight there is not walled off.
static func _fling(out: Dictionary, start: Vector2i, d: Vector2, budget: int, n: int, art: float, open: Callable,
		memo: Dictionary, seed: int, squash: float) -> void:
	var reach := sqrt(float(out.size())) * 0.75
	var each := maxi(2, budget / maxi(1, n))
	for i in range(n):
		var h := hash3(i, seed, 41)
		var turn := (float(h % 100) / 100.0 - 0.5) * 0.9
		var far := reach * (1.25 + float(hash3(i, seed, 43) % 70) / 100.0)
		var land := start + Vector2i((d.rotated(turn) * far * Vector2(1.0, squash)).round())
		# the drop flies there over open floor only
		var ok := true
		for s in range(1, 9):
			var p := start + Vector2i((Vector2(land - start) * float(s) / 8.0).round())
			if not _open(p, art, open, memo):
				ok = false
				break
		if ok and not out.has(land):
			_spread(out, land, d, each, art, open, memo, seed + i * 7, squash, 0.2)


static func _open(q: Vector2i, art: float, open: Callable, memo: Dictionary) -> bool:
	if memo.has(q):
		return memo[q]
	var ok: bool = open.call((Vector2(q) + Vector2(0.5, 0.5)) * art)
	memo[q] = ok
	return ok


## The open cell nearest to `q` (within FLOOD_SEARCH cells), for a splat landing on a wall's edge.
static func _nearest_open(q: Vector2i, art: float, open: Callable, memo: Dictionary) -> Vector2i:
	if _open(q, art, open, memo):
		return q
	for r in range(1, FLOOD_SEARCH + 1):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) == r and _open(q + Vector2i(x, y), art, open, memo):
					return q + Vector2i(x, y)
	return Vector2i(1 << 30, 1 << 30)
