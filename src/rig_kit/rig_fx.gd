class_name RigFx
extends RefCounted
## The part rigs' particles and boss effects, on the pixel grid: chips and
## embers of cuts, bursts, the matter a fresh corpse gives off (element looks),
## dust off walls, summoning pools, void flashes and rings, the void beam, the
## fx events of a snapshot (void_burst, slam), a swinging blade's pixel slash,
## and the lights all of these cast for the dark crypt. Pure presentation: it
## owns no game decisions and reads nothing of the game. Driven by
## src/rig/rig_renderer.gd, which hands in its random numbers so a fixed seed
## draws the same picture.

const RigPoses = preload("res://src/rig/rig_poses.gd")
const VIOLET := Color("a46fe0")
const VIOLET_DARK := Color("5f2d56")
const VIOLET_HOT := Color("f2b8ff")
## The core of a void beam: nothing, darker than the floor (vfx_pools.json void outline).
const VOID_CORE := Color("120a1c")
const INK := Color("222222")
## Pixel slash palettes (rigs.json "slash"), newest to oldest: the band a
## swinging blade sweeps, and how long its pixels stay (s).
const SLASH := {
	"fire": [Color("fdf7ed"), Color("facb3e"), Color("ee8e2e"), Color("da4e38")],
	"void": [Color("fdf7ed"), Color("f0b3dd"), Color("c278d0"), Color("8156aa")],
	"soul": [Color("fdf7ed"), Color("cfe86b"), Color("97da3f"), Color("4ba747")],
	"steel": [Color("fdf7ed"), Color("b6cbcf"), Color("7b8994"), Color("414859")],
}
const SLASH_LIFE := 0.2
## Most particles alive at once (the oldest go first).
const MAX_PARTICLES := 900
## Dust a debris piece knocks off a wall: below this floor speed (px/s) none.
const DUST_SPEED := 40.0
## Light radius (crypt px) along a burning void beam, one light every BEAM_LIGHT_STEP px.
const BEAM_LIGHT := 68.0
const BEAM_LIGHT_STEP := 40.0

## Square particles {x, y, vx, vy, life, max, color, grav}: drawn 2 px, fading.
var particles: Array[Dictionary] = []
## The world's particles (src/vfx/particles.gd) falling matter is handed to, where a story world set
## them (physics plan R18): there the chips and dust of the rigs land, lie, sink in lava and meet
## the walls; world_scale = world px per particle px. Weak: a freed world falls back to ours.
static var world_ref: WeakRef = null
static var world_scale := 1.0
## Summoning pools {x, y, r, life, max} on the floor.
var pools: Array[Dictionary] = []
## Flashes {x, y, r, life, max, color, kind ("ring" or "")}: rings are drawn,
## the rest only light the crypt.
var flashes: Array[Dictionary] = []
## Beams posed this frame {key, eye, beam, t, ct}, drawn by draw_over.
var beams: Array[Dictionary] = []
## Beams drawn in the last draw_over (for tests and capture checks).
var beams_drawn := 0
var rng: RandomNumberGenerator


## `random`: the random numbers every effect draws from (hand in the host's to keep one sequence).
func _init(random: RandomNumberGenerator = null) -> void:
	rng = random if random != null else RandomNumberGenerator.new()


## Clears every particle, pool, flash and beam.
func reset() -> void:
	particles.clear()
	pools.clear()
	flashes.clear()
	beams.clear()


## Moves particles (velocity, gravity "grav"), ages pools and flashes and drops
## the finished ones; above MAX_PARTICLES the oldest particles go.
func step(delta: float) -> void:
	var world: Object = world_ref.get_ref() if world_ref != null else null
	if world != null: _hand_over(world)
	for p: Dictionary in particles:
		p.life = float(p.life) + delta
		p.x = float(p.x) + float(p.vx) * delta
		p.y = float(p.y) + float(p.vy) * delta
		p.vy = float(p.vy) + float(p.get("grav", 0.0)) * delta
	particles = particles.filter(func(p: Dictionary) -> bool: return float(p.life) < float(p.max))
	if particles.size() > MAX_PARTICLES: particles = particles.slice(particles.size() - MAX_PARTICLES)
	for p: Dictionary in pools: p.life = float(p.life) + delta
	pools = pools.filter(func(p: Dictionary) -> bool: return float(p.life) < float(p.max))
	for f: Dictionary in flashes: f.life = float(f.life) + delta
	flashes = flashes.filter(func(f: Dictionary) -> bool: return float(f.life) < float(f.max))


## Fresh falling particles (gravity > 0) go to the world's particles: seen at their point, moving
## along the floor by their x speed, thrown up by their upward speed; beams and sparks stay here.
func _hand_over(world: Object) -> void:
	var keep: Array[Dictionary] = []
	var s := maxf(0.01, world_scale)
	for p: Dictionary in particles:
		if float(p.get("grav", 0.0)) > 0.0 and float(p.life) <= 0.0:
			world.emit(Vector2(float(p.x), float(p.y)) / s, Vector2(float(p.vx), 0.0) / s, p.color, float(p.max) + 1.5, "debris", 2.0, 4.0, maxf(0.0, -float(p.vy)) / s, 1.0)
		else:
			keep.append(p)
	particles = keep


## Adds one particle (see `particles` for its keys).
func add(particle: Dictionary) -> void:
	particles.append(particle)


## `count` particles in `color` flying out of `point` all round at up to `speed` px/s.
func burst(point: Vector2, color: Color, count: int, speed: float) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(count) + rng.randf_range(-0.2, 0.2)
		var velocity := Vector2(cos(angle), sin(angle)) * speed * rng.randf_range(0.5, 1.0)
		particles.append({"x": point.x, "y": point.y, "vx": velocity.x, "vy": velocity.y, "life": 0.0, "max": rng.randf_range(0.3, 0.7), "color": color})


## A summoning pool of radius `r` at `at` for `seconds` (a summoned figure rising).
func pool(at: Vector2, r: float, seconds: float) -> void:
	pools.append({"x": at.x, "y": at.y, "r": r, "life": 0.0, "max": seconds})


## A flash at (`x`, `y`) of radius `r` for `seconds` in `color`: a growing
## ring of pixels with kind "ring", else only light.
func flash(x: float, y: float, r: float, seconds: float, color: Color, kind: String = "") -> void:
	var f := {"x": x, "y": y, "r": r, "life": 0.0, "max": seconds, "color": color}
	if not kind.is_empty(): f = {"kind": kind, "x": x, "y": y, "r": r, "life": 0.0, "max": seconds, "color": color}
	flashes.append(f)


## Plays a snapshot fx event once: "void_burst" (violet rings, a flash, a
## burst) or "slam" (a dust ring and grit); x, y, r (radius px).
func play(event: Dictionary) -> void:
	var point := Vector2(float(event.get("x", 0)), float(event.get("y", 0)))
	var radius := float(event.get("r", 64))
	match str(event.get("kind", "")):
		"void_burst":
			flash(point.x, point.y, radius, 0.45, VIOLET, "ring")
			flash(point.x, point.y, radius * 0.6, 0.35, VIOLET_HOT, "ring")
			flash(point.x, point.y, radius * 1.6, 0.5, VIOLET)
			burst(point, VIOLET, 36, 220.0)
			burst(point, INK, 18, 140.0)
		"slam":
			flash(point.x, point.y, radius, 0.4, Color("a99d93"), "ring")
			for i in range(24): particles.append({"x": point.x + rng.randf_range(-radius, radius) * 0.5, "y": point.y, "vx": rng.randf_range(-100, 100), "vy": rng.randf_range(-90, -10), "life": 0.0, "max": rng.randf_range(0.3, 0.6), "color": [Color("7b6a5e"), Color("a99d93")][rng.randi_range(0, 1)], "grav": 280.0})


## The element matter a debris piece `d` gives off while it is fresh: its look
## (d.look "matter": [{rate per s, until s, colors (cols), vx, vy [lo, hi],
## grav, life [lo, hi]}]) at `age` s after it was born; nothing once it crumbles.
func matter(d: Dictionary, age: float, delta: float) -> void:
	var look: Dictionary = d.get("look", {})
	if look.is_empty() or float(d.get("gone_at", -1.0)) >= 0.0: return
	for m: Dictionary in look.get("matter", []):
		if age > float(m.get("until", 2.0)) or rng.randf() >= float(m.get("rate", 1.0)) * delta: continue
		var vy: Array = m.get("vy", [-30, -15])
		var life: Array = m.get("life", [0.5, 0.9])
		var cols: Array = m.cols
		var spread := float(m.get("vx", 6.0))
		particles.append({"x": float(d.x) + rng.randf_range(-3.0, 3.0), "y": float(d.y) - float(d.z) - rng.randf_range(1.0, 5.0), "vx": rng.randf_range(-spread, spread),
			"vy": rng.randf_range(float(vy[0]), float(vy[1])), "life": 0.0, "max": rng.randf_range(float(life[0]), float(life[1])), "color": cols[rng.randi_range(0, cols.size() - 1)],
			"grav": float(m.get("grav", 0.0))})


## A debris piece `d` knocking against a wall throws up a little dust of its chips.
func wall_dust(d: Dictionary) -> void:
	if Vector2(float(d.vx), float(d.get("vy", 0.0))).length() < DUST_SPEED: return
	var look: Dictionary = d.get("look", {})
	var color: Color = look.get("chip_c", Color("a99d93")) if not look.is_empty() else Color("a99d93")
	for i in range(3): particles.append({"x": float(d.x), "y": float(d.y) - float(d.z), "vx": rng.randf_range(-30, 30), "vy": rng.randf_range(-50, -10), "life": 0.0, "max": rng.randf_range(0.2, 0.4), "color": color, "grav": 200.0})


## Summoning pools on the floor (under the actors).
func draw_pools(canvas: CanvasItem) -> void:
	for p: Dictionary in pools: _draw_pool(canvas, p)


## Over the actors: `posed` beams ([[beam {eye, beam, t, ct}, ends [x0, y0,
## x1, y1]], ...] in the snapshot's order, see RigRenderer.draw_over), then
## particles and rings; forgets this frame's beams (the host sets beams_drawn).
func draw_over(canvas: CanvasItem, posed: Array) -> void:
	for pair: Array in posed: _draw_beam(canvas, pair[0], pair[1])
	beams.clear()
	for p: Dictionary in particles:
		var k := 1.0 - float(p.life) / float(p.max)
		canvas.draw_rect(Rect2(Vector2(float(p.x), float(p.y)).round(), Vector2(2, 2)), Color(p.color, k))
	for f: Dictionary in flashes:
		var k := float(f.life) / float(f.max)
		if str(f.get("kind", "")) == "ring":
			var radius := lerpf(6.0, float(f.r), RigPoses.ease_out(k))
			for i in range(48):
				var angle := TAU * i / 48.0
				canvas.draw_rect(Rect2(Vector2(float(f.x), float(f.y)) + Vector2(cos(angle), sin(angle) * 0.55) * radius, Vector2(2, 2)), Color(f.color, 1.0 - k))


## A swing's slash on the pixel grid (`px` world px per block): the band the
## blade swept between its inner point (q) and its tip (p) over the last
## frames (`trail` [{p, q, age, life}]), filled block by block in `pal`
## (SLASH). The newest edge is white-hot, older parts cool through yellow and
## orange to red, and every block fades with its age; the inner part of older
## segments drops out, so it tapers like a crescent.
static func draw_slash(canvas: CanvasItem, trail: Array, px: float, pal: Array) -> void:
	var n := trail.size()
	if n < 2: return
	for i in range(1, n):
		var a0: Dictionary = trail[i - 1]
		var a1: Dictionary = trail[i]
		if not a0.has("q") or not a1.has("q"): continue
		var age := clampf(float(a1.age) / maxf(0.01, float(a1.get("life", SLASH_LIFE))), 0.0, 1.0)
		var newest := float(i) / float(n - 1)
		var col: Color = pal[0] if newest > 0.88 else pal[1] if newest > 0.6 else pal[2] if newest > 0.3 else pal[3]
		col.a = 1.0 - age
		var p0: Vector2 = a0.p
		var p1: Vector2 = a1.p
		var q0: Vector2 = a0.q
		var q1: Vector2 = a1.q
		var steps := clampi(int(maxf(p0.distance_to(p1), q0.distance_to(q1)) / px) + 1, 1, 40)
		var across := clampi(int(p1.distance_to(q1) / px) + 1, 1, 30)
		var keep_from := 0.0 if newest > 0.7 else 0.45
		for s in range(steps + 1):
			var f := float(s) / float(steps)
			var tip := p0.lerp(p1, f)
			var inner := q0.lerp(q1, f)
			for c in range(across + 1):
				var u := float(c) / float(across)
				if u < keep_from: continue
				canvas.draw_rect(Rect2((inner.lerp(tip, u) / px).floor() * px, Vector2(px, px)), col)


## Light sources for the dark crypt: [Vector3(x, y, radius)] along burning
## void beams of `snapshot` enemies, round void figures, pools and flashes.
func lights(snapshot: Dictionary) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for enemy: Dictionary in snapshot.get("enemies", []):
		if enemy.get("beam") is Array and str(enemy.get("attack", "")) == "active" and str(enemy.get("attack_kind", "")) == "beam":
			var ends: Array = enemy.beam
			var from := Vector2(float(ends[0]), float(ends[1]))
			var to := Vector2(float(ends[2]), float(ends[3]))
			var steps := maxi(1, int(from.distance_to(to) / BEAM_LIGHT_STEP))
			for i in range(steps + 1): result.append(Vector3(lerpf(from.x, to.x, float(i) / steps), lerpf(from.y, to.y, float(i) / steps) - 16.0, BEAM_LIGHT))
			if enemy.get("beam_b") is Array:
				var other := Vector2(float(enemy.beam_b[2]), float(enemy.beam_b[3]))
				for i in range(steps + 1): result.append(Vector3(lerpf(from.x, other.x, float(i) / steps), lerpf(from.y, other.y, float(i) / steps) - 16.0, BEAM_LIGHT))
		elif str(enemy.get("rig", "")) in ["void", "bomber"] and float(enemy.get("dying_p", -1.0)) < 0.0:
			result.append(Vector3(float(enemy.get("x", 0)), float(enemy.get("y", 0)) - 8.0, 72.0 if str(enemy.rig) == "void" else 40.0))
	for p: Dictionary in pools: result.append(Vector3(float(p.x), float(p.y), 44.0))
	for f: Dictionary in flashes:
		if str(f.get("kind", "")) != "ring": result.append(Vector3(float(f.x), float(f.y), float(f.r) * (1.0 - float(f.life) / float(f.max))))
	return result


## A beam of void from the eye to the far end of `ends` (where it stops at a
## wall): the warning before it a flickering dotted line; then a tube of
## nothing with the light torn bright round it, wavering, what it swallowed
## running back up its core; light and dust beside it are drawn into it and
## vanish, and where it strikes it tears a hole of void that sucks the floor's
## dust in, swirling. On the 2 px grid.
func _draw_beam(canvas: CanvasItem, drawn: Dictionary, ends: Array) -> void:
	var eye: Vector2 = drawn.eye
	var end := Vector2(float(ends[2]), float(ends[3]) - 16.0)
	var beam: Dictionary = drawn.beam
	var t: float = drawn.t
	var length := maxf(1.0, eye.distance_to(end))
	var direction := (end - eye) / length
	var warn := float(beam.get("warn", 0.0))
	if warn > 0.0:
		var flick := 0.35 + 0.35 * sin(float(drawn.ct) * 40.0)
		var s := 8.0
		while s < length:
			if int(s / 4.0) % 3 != 0: canvas.draw_rect(Rect2((eye + direction * s).round(), Vector2(2, 2)), Color(VIOLET, flick * warn))
			s += 4.0
	var k := float(beam.get("k", 0.0))
	if k <= 0.0: return
	# a tube of void: outside in the dark outline, the light torn bright at its
	# rim, the violet body and a core of nothing (darker than the floor); it wavers
	for layer: Array in [[8.0, INK], [6.6, VIOLET_HOT], [5.0, VIOLET], [3.0, VOID_CORE]]:
		var s := 0.0
		while s <= length:
			var wobble := 1.1 * sin(s * 0.16 - t * 38.0) + 0.7 * sin(s * 0.055 + t * 21.0)
			var radius := (float(layer[0]) + wobble) * k * (lerpf(0.5, 1.0, s / 12.0) if s < 12.0 else 1.0)
			if radius >= 0.9:
				var side := maxf(2.0, roundf(radius * 2.0 / 2.0) * 2.0)
				canvas.draw_rect(Rect2((eye + direction * s - Vector2(side, side) * 0.5).round(), Vector2(side, side)), layer[1])
			s += 2.0
	# what it swallowed runs back up its core to the eye
	if k > 0.5:
		var s := fposmod(-t * 260.0, 14.0)
		while s <= length:
			canvas.draw_rect(Rect2((eye + direction * s - Vector2(1, 1)).round(), Vector2(2, 2)), VIOLET)
			s += 14.0
	# the eye burns; where it strikes it tears a hole of void with the light torn round it
	var flare := 6.0 + 2.0 * sin(t * 50.0)
	_px_disc(canvas, eye, (flare + 1.0) * k, VIOLET)
	_px_disc(canvas, eye, flare * 0.55 * k, VIOLET_HOT)
	_px_disc(canvas, end, (flare + 3.0) * k, INK)
	_px_disc(canvas, end, (flare + 1.5) * k, VIOLET_HOT)
	_px_disc(canvas, end, flare * k, VOID_CORE)
	# light and dust beside it are drawn in and vanish in its core
	var across := Vector2(-direction.y, direction.x)
	for i in range(2):
		var off := rng.randf_range(10.0, 24.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var speed := rng.randf_range(90.0, 160.0)
		var from := eye + direction * rng.randf_range(12.0, length) + across * off
		particles.append({"x": from.x, "y": from.y, "vx": -across.x * signf(off) * speed + direction.x * 20.0, "vy": -across.y * signf(off) * speed + direction.y * 20.0,
			"life": 0.0, "max": (absf(off) - 3.0) / speed, "color": [VIOLET_HOT, VIOLET, Color("a99d93")][rng.randi_range(0, 2)], "grav": 0.0})
	# and the floor round the hole is sucked into it, swirling
	if rng.randf() < 0.8:
		var out := Vector2.from_angle(rng.randf() * TAU)
		var dist := rng.randf_range(12.0, 26.0)
		var speed := rng.randf_range(110.0, 180.0)
		var from := end + out * dist
		var pull := -out * speed + out.orthogonal() * speed * 0.35
		particles.append({"x": from.x, "y": from.y, "vx": pull.x, "vy": pull.y,
			"life": 0.0, "max": (dist - 3.0) / speed, "color": [VIOLET_HOT, Color("7b6a5e"), Color("a99d93")][rng.randi_range(0, 2)], "grav": 0.0})


## A filled disc on the 2 px grid (no smooth circle: the pixel look).
static func _px_disc(canvas: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r < 1.0:
		return
	var n := int(ceil(r / 2.0))
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var cell := (c / 2.0).floor() + Vector2(gx, gy)
			if ((cell + Vector2(0.5, 0.5)) * 2.0 - c).length() <= r:
				canvas.draw_rect(Rect2(cell * 2.0, Vector2(2, 2)), col)


func _draw_pool(canvas: CanvasItem, p: Dictionary) -> void:
	var k := float(p.life) / float(p.max)
	var grow := RigPoses.ease_out(RigPoses.seg(k, 0.0, 0.12)) * (1.0 - RigPoses.ease_in(RigPoses.seg(k, 0.7, 1.0)))
	var rx := float(p.r) * grow
	var ry := rx * 0.45
	if rx < 2.0: return
	var rows := int(ceil(ry / 2.0))
	for row in range(-rows, rows + 1):
		var y := float(row) * 2.0
		var half := rx * sqrt(maxf(0.0, 1.0 - pow(y / (ry + 1.0), 2.0)))
		if half < 1.0: continue
		canvas.draw_rect(Rect2(Vector2(float(p.x) - half, float(p.y) + y).round(), Vector2(roundf(half * 2.0), 2)), VIOLET_DARK)
		if half > 3.0: canvas.draw_rect(Rect2(Vector2(float(p.x) - half + 2.0, float(p.y) + y).round(), Vector2(roundf(half * 2.0 - 4.0), 2)), Color("13111c"))
	for i in range(3):
		var angle := float(p.life) * 2.0 + i * TAU / 3.0
		canvas.draw_rect(Rect2(Vector2(float(p.x) + cos(angle) * rx * 0.6, float(p.y) + sin(angle) * ry * 0.6).round(), Vector2(2, 2)), Color(VIOLET, 0.8))
	if rng.randf() < 0.3:
		particles.append({"x": float(p.x) + rng.randf_range(-rx, rx) * 0.7, "y": float(p.y), "vx": rng.randf_range(-6, 6), "vy": rng.randf_range(-60, -28), "life": 0.0, "max": 0.55, "color": [Color("efe6d6"), VIOLET, VIOLET_DARK][rng.randi_range(0, 2)]})
