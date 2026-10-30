extends RefCounted
## A shield as a dome of light over a hero that gives like rubber. Its
## outline is a ring of points on springs: each is pulled back to its rest
## shape and tied to its neighbours, so a dent runs round the dome as a wave,
## and the ring keeps its volume, so the far side bulges out a little. The
## whole dome also squashes and springs back. A blow dents it on the side it
## came from (`hit`); the dent lights up, sparks, wobbles out and settles.
## Drawn on the art grid (`art` world px per art pixel), standing on the hero's
## feet: a rim lit on top, a dark line round it, a glassy dither fill that
## thickens towards the rim (the hero stays readable inside), a highlight band
## upper left, gold hex plates on the big dome. Fades by the ordered dither,
## never see-through. Tuning: assets/data/vfx_talents.json "dome". Presentation
## only (src/vfx/talent_fx.gd keeps one per hero).

const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")
## Points on the outline.
const N := 48

## Which dome: 0 a short flash (guard), 1 a shield (Kristallschild, Schutzwall,
## Wächtereid), 2 Unbezwingbar (bigger, hex plates).
var size := 1
## Each point's dent (art cells, inwards positive) and its speed.
var dent := PackedFloat32Array()
var speed := PackedFloat32Array()
## The whole dome's squash (positive: lower and wider) and its speed.
var squash := 0.0
var squash_speed := 0.0

var _cfg: Dictionary = {}
var _sizes: Array = [Vector3(17, 7, 30), Vector3(20, 8, 34), Vector3(25, 10, 40)]
var _time := -1.0
## Light where blows landed: {i, t0, power}.
var _sparks: Array = []
## The shape as last worked out (_build_shape) and what it was worked out for.
var _shape_key := PackedInt32Array()
var _poly := PackedVector2Array()
var _rim: Dictionary = {}
var _glass: Array = []
var _line: Array = []


## `cfg`: assets/data/vfx_talents.json "dome" (defaults without it).
func _init(cfg: Dictionary = {}) -> void:
	_cfg = cfg
	dent.resize(N)
	speed.resize(N)
	var sizes: Array = cfg.get("sizes", [])
	if sizes.size() == 3:
		_sizes = []
		for s: Array in sizes: _sizes.append(Vector3(float(s[0]), float(s[1]), float(s[2])))


func _f(key: String, fallback: float) -> float:
	return float(_cfg.get(key, fallback))


## The rest outline: point `i` (art cells from the feet; 0 the right foot of the
## dome, then up over the top, the left foot and along the front) and its
## outward normal. Top half: the dome W x H; bottom half: the floor ellipse W x D.
func _rest(i: int) -> Array:
	var s: Vector3 = _sizes[clampi(size, 0, 2)]
	var th := TAU * float(i) / float(N)
	var up := sin(th) >= 0.0
	var h := s.z if up else s.y
	return [Vector2(s.x * cos(th), -h * sin(th)), Vector2(cos(th) / s.x, -sin(th) / h).normalized()]


## A blow travelling along `dir` (world) with `power` (about 1) lands on the
## side it came from at `clock`: the points there are pushed in, the dome squashes.
func hit(dir: Vector2, power: float, clock: float) -> void:
	var from := -dir.normalized() if dir.length() > 0.01 else Vector2.UP
	var s: Vector3 = _sizes[clampi(size, 0, 2)]
	var centre := Vector2(0, -s.z * 0.4)
	var best := 0
	var best_dot := -INF
	for i in range(N):
		var k := (Vector2(_rest(i)[0]) - centre).normalized().dot(from)
		if k > best_dot:
			best_dot = k
			best = i
	var push := _f("push", 150.0) * power
	for j in range(-8, 9):
		var at := posmod(best + j, N)
		speed[at] += push * exp(-float(j * j) / 12.0)
	squash_speed += _f("squash_push", 3.0) * power
	_sparks.append({"i": best, "t0": clock, "power": power})


## Runs the rubber up to `clock` (seconds) in small fixed steps.
func step(clock: float) -> void:
	if _time < 0.0 or clock < _time: _time = clock
	var left := clampf(clock - _time, 0.0, 0.1)
	_time = clock
	var spring := _f("spring", 110.0)
	var damping := _f("damping", 6.0)
	var tension := _f("tension", 300.0)
	var keep := _f("keep_volume", 25.0)
	var most := _f("max_dent", 0.5) * Vector3(_sizes[clampi(size, 0, 2)]).x
	var squash_spring := _f("squash_spring", 200.0)
	var squash_damping := _f("squash_damping", 9.0)
	while left > 0.0:
		var e := minf(1.0 / 120.0, left)
		left -= e
		for i in range(N):
			var pull := dent[posmod(i - 1, N)] + dent[posmod(i + 1, N)] - 2.0 * dent[i]
			speed[i] += (-spring * dent[i] - damping * speed[i] + tension * pull) * e
		var mean := 0.0
		for i in range(N):
			dent[i] = clampf(dent[i] + speed[i] * e, -most, most)
			mean += dent[i]
		# the ring keeps its volume: a dent pushes the rest of it out
		mean *= minf(1.0, keep * e) / float(N)
		for i in range(N): dent[i] -= mean
		squash_speed += (-squash_spring * squash - squash_damping * squash_speed) * e
		squash += squash_speed * e


## Draws the dome standing on `feet` (world px): `grow` 0..1 its pop-in (with
## an overshoot), `fade` 0..1 its visibility by the dither.
func draw(canvas: CanvasItem, feet: Vector2, grow: float, fade: float, element: String, art: float, clock: float) -> void:
	var g := _back(clampf(grow, 0.0, 1.0))
	if g <= 0.05 or fade <= 0.02: return
	var cols: Array = Pal.ramp(element)
	# the shape is worked out again only when it changed: a dent to 1/20 cell,
	# the squash to 1/200, the pop-in to 1/100 (finer than a pixel shows)
	var quant := PackedInt32Array()
	quant.resize(N + 4)
	for i in range(N):
		quant[i] = roundi(dent[i] * 20.0)
	quant[N] = roundi(squash * 200.0)
	quant[N + 1] = roundi(g * 100.0)
	quant[N + 2] = size
	quant[N + 3] = element.hash()
	if quant != _shape_key:
		_shape_key = quant
		_build_shape(cols)
	var o := PixelPaint.at(feet, art)
	# glass: a fill that thickens towards the rim, a highlight band upper left, plates
	for cell: Array in _glass:
		var q: Vector2i = o + Vector2i(cell[0])
		if PixelPaint.shown(q, float(cell[2]) * fade):
			PixelPaint.cell(canvas, q, cell[1], art)
	# the dark line round it (the floor's front edge in ink, the rest deep)
	for cell: Array in _line:
		var q: Vector2i = o + Vector2i(cell[0])
		if fade >= 1.0 or PixelPaint.shown(q, fade):
			PixelPaint.cell(canvas, q, cols[0] if bool(cell[1]) else Pal.INK, art)
	# the rim: every cell the outline passes, lit by its dent
	var crawl := posmod(int(clock * PixelPaint.FPS), N / 2)
	for q0: Vector2i in _rim:
		var i := int(_rim[q0])
		var push := absf(dent[i])
		var col: Color = cols[3] if q0.y < 0 else cols[2]
		if push > 2.0: col = cols[4]
		elif push > 0.8: col = cols[3]
		if i == crawl or i == (crawl + 1) % N: col = cols[4]
		var q := o + q0
		if fade >= 1.0 or PixelPaint.shown(q, fade):
			PixelPaint.cell(canvas, q, col, art)
	# sparks where blows landed: a small star on the dent, gone in a moment
	for k in range(_sparks.size() - 1, -1, -1):
		var spark: Dictionary = _sparks[k]
		var age := clock - float(spark.t0)
		if age > 0.2 or age < 0.0:
			_sparks.remove_at(k)
			continue
		var c := o + Vector2i(roundi(_poly[int(spark.i)].x), roundi(_poly[int(spark.i)].y))
		var reach := 1 + int(age / 0.2 * 4.0 * float(spark.power))
		for r in range(1, reach + 1):
			var col: Color = cols[4] if r < 2 else cols[3]
			for step: Vector2i in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
				PixelPaint.cell(canvas, c + step, col, art)
		PixelPaint.cell(canvas, c, cols[4], art)


## The shape for _shape_key (dents, squash, pop-in, size, element as rounded
## there): the outline, the cells it passes (the rim, each with its point),
## the glass cells inside ([cell, colour, cover]) and the dark line round it
## ([cell, deep instead of ink]); cells from the feet.
func _build_shape(cols: Array) -> void:
	var s: Vector3 = _sizes[clampi(size, 0, 2)]
	var g := float(_shape_key[N + 1]) / 100.0
	var sq := float(_shape_key[N]) / 200.0
	var wide := g * (1.0 + 0.08 * sq)
	var tall := g * (1.0 - 0.14 * sq)
	var poly := PackedVector2Array()
	var normals: Array[Vector2] = []
	for i in range(N):
		var rest: Array = _rest(i)
		var p: Vector2 = rest[0]
		var n: Vector2 = rest[1]
		poly.append(Vector2(p.x * wide, p.y * (tall if p.y < 0.0 else g)) - n * (float(_shape_key[i]) / 20.0) * g)
		normals.append(n)
	_poly = poly
	var rim := {}
	for i in range(N):
		var a := poly[i]
		var b := poly[(i + 1) % N]
		var steps := maxi(1, int(ceil(maxf(absf(b.x - a.x), absf(b.y - a.y)))))
		for k in range(steps):
			var q := Vector2i(roundi(lerpf(a.x, b.x, float(k) / steps)), roundi(lerpf(a.y, b.y, float(k) / steps)))
			if not rim.has(q): rim[q] = i
	_rim = rim
	var low := Vector2i(int(floor(-s.x * wide)) - 2, int(floor(-s.z * tall)) - 2)
	var high := Vector2i(int(ceil(s.x * wide)) + 2, int(ceil(s.y * g)) + 2)
	var inside := {}
	var glass: Array = []
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var q := Vector2i(x, y)
			if rim.has(q) or not Geometry2D.is_point_in_polygon(Vector2(x, y), poly): continue
			inside[q] = true
			var e := Vector2(float(x) / (s.x * wide), float(y) / ((s.z * tall) if y < 0 else (s.y * g))).length()
			var angle := atan2(-float(y) / s.z, float(x) / s.x)
			# tinted glass: a few dots inside, denser and lighter towards the rim
			var col: Color = cols[2] if e > 0.86 else cols[1]
			var cover := 0.02 + 0.3 * smoothstep(0.66, 1.0, e)
			if y < 0 and e > 0.66 and e < 0.84 and angle > 1.95 and angle < 2.6:
				col = cols[4] if absf(angle - 2.25) < 0.07 and absf(e - 0.75) < 0.05 else cols[3]
				cover = 0.85
			elif size >= 2 and e > 0.68 and _plate_edge(x, y):
				col = cols[3]
				cover = 0.55
			glass.append([q, col, cover])
	_glass = glass
	var line: Array = []
	for q: Vector2i in rim:
		var n: Vector2 = normals[int(rim[q])]
		var out := q + Vector2i(roundi(n.x), roundi(n.y))
		if rim.has(out) or inside.has(out): continue
		line.append([out, q.y < 0])
	_line = line


## True when the cell lies on an edge of the hex plates (6 cells across).
static func _plate_edge(x: int, y: int) -> bool:
	var row := floori(float(y) / 5.0)
	var shift := 3 if posmod(row, 2) == 1 else 0
	var col := posmod(x + shift, 6)
	var line := posmod(y, 5)
	return line == 0 and col != 0 or col == 0 and line != 0


## Ease out with an overshoot (the pop of the dome).
static func _back(x: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


## True when the rubber has come to rest.
func still() -> bool:
	if absf(squash) > 0.02 or absf(squash_speed) > 0.05: return false
	for i in range(N):
		if absf(dent[i]) > 0.05 or absf(speed[i]) > 0.2: return false
	return true
