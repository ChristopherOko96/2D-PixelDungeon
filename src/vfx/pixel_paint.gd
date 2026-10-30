extends RefCounted
## Drawing on the art grid for warnings and effects, at any art pixel size
## (`art` world px per art pixel: the crypt 2, the story worlds 3): every
## shape is whole art pixels, opaque, fading or filling by a 4x4 ordered
## dither instead of transparency, rims as crawling dashes over a dark
## underlay one pixel lower (so they read on any floor). The crypt's boss
## warnings (src/vfx/boss_fx.gd) and the story worlds share it; the look is
## the Frostgruft's and the Hell's telegraphs (src/hell/frost_fx.gd).

## 4x4 ordered dither thresholds (0..15).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## Frames per second of crawling rims and blinks.
const FPS := 12.0
## Where pixels may show: Callable(world point) -> bool (false inside walls),
## set by the host around effects that must not shine through walls (the
## heroes' shots, floor warnings) and cleared after; empty draws everywhere.
static var clip := Callable()


## True when art cell `q` shows at coverage `k` (0..1).
static func shown(q: Vector2i, k: float) -> bool:
	return float(BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)]) < k * 16.0


static func cell(canvas: CanvasItem, q: Vector2i, col: Color, art: float) -> void:
	if clip.is_valid() and not clip.call((Vector2(q) + Vector2(0.5, 0.5)) * art):
		return
	canvas.draw_rect(Rect2(Vector2(q) * art, Vector2(art, art)), col)


static func at(p: Vector2, art: float) -> Vector2i:
	return Vector2i((p / art).floor())


## An ellipse rim of whole pixels; every `every`-th pixel (crawling with `phase`).
static func ellipse(canvas: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, art: float, every := 1, phase := 0) -> void:
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
		cell(canvas, q, col, art)


## A filled ellipse of whole pixels at dither coverage `cover`.
static func disc(canvas: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, art: float, cover := 1.0) -> void:
	if cover <= 0.0:
		return
	for gy in range(int(floor((c.y - ry) / art)), int(ceil((c.y + ry) / art)) + 1):
		for gx in range(int(floor((c.x - rx) / art)), int(ceil((c.x + rx) / art)) + 1):
			var p := (Vector2(gx, gy) + Vector2(0.5, 0.5)) * art
			if Vector2((p.x - c.x) / rx, (p.y - c.y) / ry).length() <= 1.0 and (cover >= 1.0 or shown(Vector2i(gx, gy), cover)):
				cell(canvas, Vector2i(gx, gy), col, art)


## A warning on the floor that strikes when `k` reaches 1: its area filling up
## by the dither (sparse to dense), a dashed rim crawling round over a dark
## underlay (blinking faster near the end) and a ring growing from the middle.
static func warning(canvas: CanvasItem, c: Vector2, rx: float, ry: float, k: float, col: Color, ink: Color, art: float, t: float) -> void:
	var fill := col.darkened(0.45)
	disc(canvas, c, rx, ry, fill, art, 0.12 + 0.38 * k)
	var crawl := int(floorf(t * FPS))
	var every := 3 if k < 0.7 else 2
	var lit := k < 0.75 or posmod(int(floorf(t * FPS * (1.0 + 2.0 * k))), 2) == 0
	ellipse(canvas, c + Vector2(0, art), rx, ry, ink, art, every, crawl)
	ellipse(canvas, c, rx, ry, col if lit else col.darkened(0.3), art, every, crawl)
	if k > 0.05:
		ellipse(canvas, c + Vector2(0, art), rx * k, ry * k, ink, art)
		ellipse(canvas, c, rx * k, ry * k, col.lightened(0.25), art)


## The moment a warning strikes (`k` 0..1 of the burst): a bright ring
## running out and a flash in the middle, both thinning by the dither.
static func burst(canvas: CanvasItem, c: Vector2, rx: float, ry: float, k: float, col: Color, art: float) -> void:
	var grow := 0.6 + 0.6 * k
	disc(canvas, c, rx * grow, ry * grow, col.lightened(0.5), art, 0.9 * (1.0 - k))
	for w in range(2):
		var s := 1.0 + 0.5 * k + float(w) * art / maxf(rx, 1.0)
		ellipse(canvas, c, rx * s, ry * s, col if w == 0 else col.darkened(0.3), art, 1 if k < 0.5 else 2)


## A lane warning from `from` to `to` (`half` its half width): dashed edges
## crawling over a dark underlay, its area filling by the dither, a bar
## running down it as `k` runs 0..1.
static func lane(canvas: CanvasItem, from: Vector2, to: Vector2, half: float, k: float, col: Color, ink: Color, art: float, t: float) -> void:
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
					cell(canvas, q, fill, art)
		if posmod(i - crawl, 3) != 2:
			for e: float in [-half, half]:
				cell(canvas, at(p + side * e + Vector2(0, art), art), ink, art)
				cell(canvas, at(p + side * e, art), col, art)
		if float(i) / float(maxi(1, steps)) <= k:
			cell(canvas, at(p, art), col.lightened(0.25), art)


## A cone warning from `from` (reach `r`, opening `arc` round `ang`): its area
## filling by the dither, crawling dashed edges and arc over a dark underlay,
## a front running out with `k`.
static func cone(canvas: CanvasItem, from: Vector2, r: float, ang: float, arc: float, k: float, col: Color, ink: Color, art: float, t: float) -> void:
	var crawl := int(floorf(t * FPS))
	var fill := col.darkened(0.45)
	for gy in range(int(floor((from.y - r) / art)), int(ceil((from.y + r) / art)) + 1):
		for gx in range(int(floor((from.x - r) / art)), int(ceil((from.x + r) / art)) + 1):
			var p := (Vector2(gx, gy) + Vector2(0.5, 0.5)) * art
			var rel := p - from
			if rel.length() <= r and absf(angle_difference(rel.angle(), ang)) < arc / 2.0 and shown(Vector2i(gx, gy), 0.12 + 0.38 * k):
				cell(canvas, Vector2i(gx, gy), fill, art)
	for pass_i in range(2):
		var off := Vector2(0, art) if pass_i == 0 else Vector2.ZERO
		var c: Color = ink if pass_i == 0 else col
		for e: float in [ang - arc / 2.0, ang + arc / 2.0]:
			var dir := Vector2.from_angle(e)
			for i in range(int(r / art)):
				if posmod(i - crawl, 3) != 2:
					cell(canvas, at(from + dir * float(i) * art + off, art), c, art)
		for rr: float in [r, r * k]:
			if rr < art:
				continue
			var n := maxi(6, int(arc * rr / art))
			for i in range(n + 1):
				if rr == r and posmod(i - crawl, 3) == 2:
					continue
				cell(canvas, at(from + Vector2.from_angle(ang - arc / 2.0 + arc * float(i) / float(n)) * rr + off, art), c if rr == r or pass_i == 0 else col.lightened(0.25), art)


## A ball of the ramp `cols` (white-hot first, edge last) `r` art px round at
## `p` with an outline `ink` (an orb, a glob in flight).
static func ball(canvas: CanvasItem, p: Vector2, r: int, cols: Array, ink: Color, art: float) -> void:
	var c := at(p, art)
	for y in range(-r - 1, r + 2):
		for x in range(-r - 1, r + 2):
			var d := Vector2(x, y).length()
			if d <= float(r) + 0.5:
				var lit := Vector2(float(x) + float(r) * 0.35, float(y) + float(r) * 0.35).length() / maxf(1.0, float(r))
				cell(canvas, c + Vector2i(x, y), cols[clampi(int(lit * float(cols.size() - 1)), 0, cols.size() - 1)], art)
			elif d <= float(r) + 1.5:
				cell(canvas, c + Vector2i(x, y), ink, art)
