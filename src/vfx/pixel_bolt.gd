extends RefCounted
## Lightning on the art grid (`art` world px per art pixel): it is there at
## once, no flight. A bolt is a zigzag of 3-6 segments whose bends are drawn
## anew every two frames; a one-pixel core in the spec colour with a body
## pixel beside it, short branches that die before the main strand. It lives
## a fifth of a second: bright for its first third, then an afterimage in the
## deep colour, then it is gone (no long glow, no smooth curve). Cells stop at
## walls (PixelPaint.clip). Its hit sparks (sparks) are pixel particles that
## fall, bounce once and lie glowing before they go out, like every element's
## burst (src/vfx/attack_fx.gd element_burst). Presentation only; the drawing
## is stateless (age-based), so it can be drawn from a snapshot.

const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
## Storm colours: spec (core), body, deep (afterimage).
const STORM := [Color("f4f6ff"), Color("8fa4ff"), Color("3a3a8a")]
## Dice of the sparks.
static var _dice := RandomNumberGenerator.new()


## `count` sparks of lightning off a hit at `point` (seen `height` px above the
## floor) into `particles` (src/vfx/particles.gd): short streaks thrown up and
## out in `cols` (spec, body) that fall, bounce once and lie glowing on the
## floor before they go out by the dither (about a second), like the other
## elements' bursts; no floor mark of their own (scorch_star leaves that).
static func sparks(particles: RefCounted, point: Vector2, count: int, cols: Array = STORM, height: float = 12.0) -> void:
	if particles == null or cols.size() < 2: return
	for i in range(count):
		var out := Vector2.UP.rotated(_dice.randf_range(-1.4, 1.4)) * _dice.randf_range(60.0, 200.0)
		particles.emit(point, out, cols[0] if i % 3 == 0 else cols[1], _dice.randf_range(0.8, 1.3), "spark", 2.0, height, _dice.randf_range(40.0, 140.0), 2.5)


## Draws a bolt from `from` to `to` that is `age` s old (nothing before 0 or
## after `life`), its bends from `seed`; `cols`: spec, body, deep.
static func draw(canvas: Object, from: Vector2, to: Vector2, age: float, seed: int, art: float, cols: Array = STORM, life: float = 0.2, branches: int = 2) -> void:
	if age < 0.0 or age > life or from.distance_to(to) < art:
		return
	var bright := age < life * 0.35
	var beat := int(age * 30.0) / 2
	var points := _zigzag(from, to, seed * 31 + beat, art)
	_strand(canvas, points, cols[0] if bright else cols[2], cols[1] if bright else cols[2], art, bright)
	if not bright or age > life * 0.25:
		return
	# branches fork off the bends and die before the main strand
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 17 + beat
	for b in range(branches):
		var i := rng.randi_range(1, points.size() - 2) if points.size() > 2 else 0
		var start: Vector2 = points[i]
		var along := (points[mini(i + 1, points.size() - 1)] - start).normalized()
		var end := start + along.rotated(rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)) * rng.randf_range(6.0, 14.0) * art / 2.0
		_strand(canvas, _zigzag(start, end, seed * 13 + b + beat, art), cols[1], cols[2], art, false)


## The bends of a bolt: 3-6 segments of about 8 crypt px, each bend pushed
## sideways at random (the ends stay put).
static func _zigzag(from: Vector2, to: Vector2, seed: int, art: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var length := from.distance_to(to)
	var n := clampi(int(length / (8.0 * art / 2.0)), 3, 6)
	var side := (to - from).orthogonal().normalized()
	var out := PackedVector2Array([from])
	for k in range(1, n):
		out.append(from.lerp(to, float(k) / float(n)) + side * rng.randf_range(-1.0, 1.0) * rng.randf_range(4.0, 10.0) * art / 2.0)
	out.append(to)
	return out


## One strand along `points`: core cells, a body cell beside each when `thick`.
static func _strand(canvas: Object, points: PackedVector2Array, core: Color, body: Color, art: float, thick: bool) -> void:
	for k in range(points.size() - 1):
		var a := points[k] / art
		var b := points[k + 1] / art
		var steps := maxi(1, int(ceil(maxf(absf(b.x - a.x), absf(b.y - a.y)))))
		var side := Vector2i(0, 1) if absf(b.x - a.x) >= absf(b.y - a.y) else Vector2i(1, 0)
		for s in range(steps + 1):
			var q := Vector2i(a.lerp(b, float(s) / float(steps)).floor())
			if thick:
				PixelPaint.cell(canvas, q + side, body, art)
			PixelPaint.cell(canvas, q, core, art)
