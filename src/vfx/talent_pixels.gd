extends RefCounted
## Procedural pixel art of the active talents (src/vfx/talent_fx.gd): novas,
## shouts, blink and dash trails, bursts, shields, the rage aura, poison
## puffs, the target mark, pixel words and shot trails. Everything is whole art
## cells drawn through PixelPaint.cell (so PixelPaint.clip stops it at walls),
## opaque, fading and thinning by the 4x4 ordered dither, with a dark outline
## or underlay, a lit north rim and spec colour only in single highlight cells
## (palette: src/vfx/talent_palette.gd). Decorative sizes are in art cells
## (crypt 2 world px, story worlds 3), hit radii in exact world px. Presentation only.

const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## The hero figure in art cells (16 x 28 around his chest).
const HERO_HALF := Vector2(8.0, 14.0)
## A 3x5 pixel font: five rows of three bits per glyph.
const FONT := {
	"A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"], "C": ["011", "100", "100", "100", "011"],
	"D": ["110", "101", "101", "101", "110"], "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
	"G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"], "I": ["111", "010", "010", "010", "111"],
	"J": ["001", "001", "001", "101", "010"], "K": ["101", "101", "110", "101", "101"], "L": ["100", "100", "100", "100", "111"],
	"M": ["101", "111", "101", "101", "101"], "N": ["110", "101", "101", "101", "101"], "O": ["010", "101", "101", "101", "010"],
	"P": ["110", "101", "110", "100", "100"], "Q": ["010", "101", "101", "110", "011"], "R": ["110", "101", "110", "101", "101"],
	"S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"], "U": ["101", "101", "101", "101", "111"],
	"V": ["101", "101", "101", "101", "010"], "W": ["101", "101", "101", "111", "101"], "X": ["101", "101", "010", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
	"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"], "2": ["110", "001", "010", "100", "111"],
	"3": ["110", "001", "010", "001", "110"], "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "110", "001", "110"],
	"6": ["011", "100", "110", "101", "010"], "7": ["111", "001", "010", "010", "010"], "8": ["010", "101", "010", "101", "010"],
	"9": ["010", "101", "011", "001", "110"], "!": ["010", "010", "010", "000", "010"], " ": ["000", "000", "000", "000", "000"],
}


# ---------- helpers ----------

## A deterministic 0..1 value for (`seed`, `k`).
static func _rnd(seed: int, k: int) -> float:
	var h := seed * 374761393 + k * 668265263 + 1013904223
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


## Ease-out (cubic): fast start, soft landing.
static func _out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


## Ease-out with an overshoot past 1 (the "pop").
static func _back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


static func _frame(clock: float) -> int:
	return int(floorf(clock * PixelPaint.FPS))


## The art cells of a ring between `r_out` (world px) and `width` cells inside
## it round `c`, gap-free: [cell, layer (0 outermost), angle].
static func _ring_cells(c: Vector2, r_out: float, width: float, art: float) -> Array:
	var out: Array = []
	var cc := c / art
	var big := r_out / art
	if big < 1.0:
		return out
	var small := maxf(0.0, big - width)
	var layers := maxi(1, ceili(width))
	for gy in range(floori(cc.y - big), ceili(cc.y + big) + 1):
		var dy := float(gy) + 0.5 - cc.y
		if absf(dy) > big:
			continue
		var xo := sqrt(big * big - dy * dy)
		var spans: Array = []
		if absf(dy) < small:
			var xi := sqrt(small * small - dy * dy)
			spans = [Vector2(cc.x - xo, cc.x - xi), Vector2(cc.x + xi, cc.x + xo)]
		else:
			spans = [Vector2(cc.x - xo, cc.x + xo)]
		for span: Vector2 in spans:
			for gx in range(floori(span.x) - 1, ceili(span.y) + 1):
				var rel := Vector2(float(gx) + 0.5 - cc.x, dy)
				var d := rel.length()
				if d > big or d < small:
					continue
				out.append([Vector2i(gx, gy), clampi(int(big - d), 0, layers - 1), rel.angle()])
	return out


## Rings asked of _ring, by [centre, outer radius, width, art].
static var _rings: Dictionary = {}


## The cells of _ring_cells as a flat list [x, y, layer, lit, ...] in the same
## order (lit 1 where sin(angle) < -0.2: the north rim; always 0 without
## `north`), remembered while the same ring is asked again (a nova's front
## holding its radius).
static func _ring(c: Vector2, r_out: float, width: float, art: float, north := true) -> PackedInt32Array:
	var key := [c, r_out, width, art, north]
	var held: Variant = _rings.get(key)
	if held != null:
		return held
	var out := PackedInt32Array()
	var cc := c / art
	var big := r_out / art
	if big >= 1.0:
		var small := maxf(0.0, big - width)
		var layers := maxi(1, ceili(width))
		for gy in range(floori(cc.y - big), ceili(cc.y + big) + 1):
			var dy := float(gy) + 0.5 - cc.y
			if absf(dy) > big:
				continue
			var xo := sqrt(big * big - dy * dy)
			var spans: Array = []
			if absf(dy) < small:
				var xi := sqrt(small * small - dy * dy)
				spans = [Vector2(cc.x - xo, cc.x - xi), Vector2(cc.x + xi, cc.x + xo)]
			else:
				spans = [Vector2(cc.x - xo, cc.x + xo)]
			for span: Vector2 in spans:
				for gx in range(floori(span.x) - 1, ceili(span.y) + 1):
					var rel := Vector2(float(gx) + 0.5 - cc.x, dy)
					var d := rel.length()
					if d > big or d < small:
						continue
					out.append(gx)
					out.append(gy)
					out.append(clampi(int(big - d), 0, layers - 1))
					out.append(1 if north and sin(rel.angle()) < -0.2 else 0)
	if _rings.size() > 64:
		_rings.clear()
	_rings[key] = out
	return out


## Draws a cell map (cell -> colour) with a Pal.INK outline round it; `open_below`
## leaves the bottom edge without outline (soft gas).
static func _flush(canvas: CanvasItem, cells: Dictionary, art: float, open_below := false) -> void:
	var ink := {}
	for q: Vector2i in cells:
		for o: Vector2i in SIDES:
			if open_below and o.y > 0:
				continue
			if not cells.has(q + o):
				ink[q + o] = Pal.INK
	PixelPaint.paint(canvas, ink, art)
	PixelPaint.paint(canvas, cells, art)


## Keeps only the cells of a map shown at dither coverage `cover`.
static func _thin(cells: Dictionary, cover: float) -> Dictionary:
	if cover >= 1.0:
		return cells
	var out := {}
	for q: Vector2i in cells:
		if PixelPaint.shown(q, cover):
			out[q] = cells[q]
	return out


## One piece of debris of `element` on a nova's rim at cell `q` (outward
## `dir`), `t` 0..1 of its own life.
static func _debris(canvas: CanvasItem, q: Vector2i, dir: Vector2, t: float, element: String, cols: Array, art: float, k: int, seed: int, frame: int) -> void:
	var cover := 1.0 - t
	match element:
		"fire":
			# embers rising and cooling
			var rise := int(t * (5.0 + _rnd(seed, k) * 8.0))
			var e := q + Vector2i(int(round(sin(t * 9.0 + float(k)) * 1.2)), -rise)
			if PixelPaint.shown(e, cover):
				PixelPaint.cell(canvas, e, cols[3] if t < 0.3 else (cols[2] if t < 0.65 else cols[1]), art)
		"ice":
			# chips thrown out, tumbling
			var e := q + Vector2i((dir * t * 5.0).round())
			if PixelPaint.shown(e, 1.0 - t * t):
				var turn := Vector2i(1, -1) if posmod(frame / 2 + k, 2) == 0 else Vector2i(1, 1)
				PixelPaint.cell(canvas, e + Vector2i(0, 1), Pal.INK, art)
				PixelPaint.cell(canvas, e, cols[3], art)
				PixelPaint.cell(canvas, e + turn, cols[4] if k % 3 == 0 else cols[3], art)
		"arcane", "spirit":
			# motes drifting round and up, blinking
			if posmod(frame + k, 3) == 0:
				return
			var e := q + Vector2i(int(round(-dir.y * t * 3.0)), -int(t * 4.0))
			if PixelPaint.shown(e, cover):
				PixelPaint.cell(canvas, e, cols[4] if k % 2 == 0 else cols[3], art)
		"steel":
			# sparks streaking out
			if t > 0.6:
				return
			var head := Vector2(q) + dir * t * 9.0
			for s in range(3):
				var e := Vector2i((head - dir * float(s)).round())
				PixelPaint.cell(canvas, e, [cols[4], cols[3], cols[2]][s], art)
		"poison", "blood":
			# droplets flung up and falling
			var arc := 4.0 * t - 4.0 * t * t
			var e := q + Vector2i((dir * t * 4.0).round()) + Vector2i(0, -int(arc * 6.0))
			if PixelPaint.shown(e, cover + 0.3):
				PixelPaint.cell(canvas, e + Vector2i(0, 1), Pal.INK, art)
				PixelPaint.cell(canvas, e, cols[3] if t < 0.4 else cols[2], art)
		"gold":
			# glints blinking on the rim
			if posmod(frame + k * 2, 4) >= 2 or t > 0.8:
				return
			PixelPaint.cell(canvas, q, cols[4], art)
			for o: Vector2i in SIDES:
				PixelPaint.cell(canvas, q + o, cols[3], art)
		_:
			# dust lifting
			var e := q + Vector2i(0, -int(t * 3.0))
			if PixelPaint.shown(e, cover * 0.8):
				PixelPaint.cell(canvas, e, cols[1], art)


# ---------- the effects ----------

## A shockwave on the floor round `at`: its front runs out (ease-out) and
## reaches exactly `r` (world px) by p 0.3, then holds there thinning by the
## dither until p 1. Two cells thick (three when `heavy`, for ultimates) over a
## dark underlay, lit on the north rim, a wake glowing on the floor behind the
## front early on and debris of the `element` along the rim.
static func nova(canvas: CanvasItem, at: Vector2, r: float, p: float, element: String, art: float, seed: int, heavy := false) -> void:
	if r < art * 2.0 or p >= 1.0:
		return
	var cols := Pal.ramp(element)
	var frame := int(p * 60.0)
	var k := clampf(p / 0.3, 0.0, 1.0)
	var rad := r * (0.25 + 0.75 * _out(k))
	var cover := 1.0 if p <= 0.3 else 1.0 - (p - 0.3) / 0.7
	var width := 3.0 if heavy else 2.0
	# per cell: the dither first (PixelPaint.shown inline), then the wall clip
	# from its memo, then the pixel (as PixelPaint.cell draws it)
	var bayer: Array = PixelPaint.BAYER
	var clipped := PixelPaint.clip.is_valid()
	var memo: Dictionary = PixelPaint.clip_memo() if clipped else {}
	var ai := int(art)
	var size := Vector2(art, art)
	# the wake: the floor lit just behind the front, only while it runs
	if p < 0.4:
		var glow := 1.0 - p / 0.4
		var wake := clampf(rad / art * 0.3, 2.0, 6.0)
		var cells := _ring(at, rad - width * art, wake, art, false)
		for i in range(0, cells.size(), 4):
			var x := cells[i]
			var y := cells[i + 1]
			var depth := float(cells[i + 2]) / wake
			if not (float(bayer[((y & 3) << 2) | (x & 3)]) < glow * 0.55 * (1.0 - depth) * 16.0):
				continue
			if clipped:
				var open: Variant = memo.get(Vector3i(x, y, ai))
				if open == null: open = PixelPaint.open_cell(Vector2i(x, y), art)
				if not open: continue
			canvas.draw_rect(Rect2(Vector2(x, y) * art, size), cols[2] if depth < 0.3 else cols[1])
	# a flash where it started
	if p < 0.15:
		PixelPaint.disc(canvas, at, 4.0 * art, 3.0 * art, cols[2], art, 1.0 - p / 0.15)
		PixelPaint.disc(canvas, at, 2.0 * art, 1.5 * art, cols[3], art, 1.0 - p / 0.15)
	# the ring of the front: its dark underlay one cell lower and the lit
	# layers, row by row (each row's underlay lands on the next row before
	# that row's own cells cover it: the same as all underlay first)
	var ring := _ring(at, rad, width, art)
	for i in range(0, ring.size(), 4):
		var x := ring[i]
		var y := ring[i + 1]
		var layer := ring[i + 2]
		if not (float(bayer[((y & 3) << 2) | (x & 3)]) < (cover - (0.0 if p <= 0.3 else 0.15 * layer)) * 16.0):
			continue
		var below := true
		var here := true
		if clipped:
			var open: Variant = memo.get(Vector3i(x, y + 1, ai))
			if open == null: open = PixelPaint.open_cell(Vector2i(x, y + 1), art)
			below = open
			open = memo.get(Vector3i(x, y, ai))
			if open == null: open = PixelPaint.open_cell(Vector2i(x, y), art)
			here = open
		if below:
			canvas.draw_rect(Rect2(Vector2(x, y + 1) * art, size), Pal.INK)
		if not here:
			continue
		var north := ring[i + 3] == 1
		var col: Color
		match layer:
			0: col = cols[3]
			1: col = cols[2] if north else cols[1]
			_: col = cols[1] if north else cols[0]
		if layer == 0 and north and posmod(x * 7 + y * 3 + seed, 7) == 0:
			col = cols[4]
		canvas.draw_rect(Rect2(Vector2(x, y) * art, size), col)
	# an ultimate's second, darker ring lingering inside
	if heavy and p > 0.12 and p < 0.75:
		var echo := 1.0 - (p - 0.12) / 0.63
		var cells := _ring(at, r * 0.8 * (0.3 + 0.7 * _out((p - 0.12) / 0.3)), 1.5, art)
		for i in range(0, cells.size(), 4):
			var x := cells[i]
			var y := cells[i + 1]
			if not (float(bayer[((y & 3) << 2) | (x & 3)]) < echo * 0.8 * 16.0):
				continue
			if clipped:
				var open: Variant = memo.get(Vector3i(x, y, ai))
				if open == null: open = PixelPaint.open_cell(Vector2i(x, y), art)
				if not open: continue
			canvas.draw_rect(Rect2(Vector2(x, y) * art, size), cols[2] if cells[i + 3] == 1 else cols[1])
	# debris along the rim
	var count := clampi(int(rad / art / (2.5 if heavy else 3.5)), 10, 40 if heavy else 30)
	for i in range(count):
		var born := 0.04 + _rnd(seed, i) * 0.18
		if p < born:
			continue
		var t := (p - born) / (1.0 - born)
		var a := TAU * (float(i) + _rnd(seed, i + 101) * 0.6) / float(count)
		var dir := Vector2.from_angle(a)
		var q := PixelPaint.at(at + dir * (rad - art), art)
		_debris(canvas, q, dir, t, element, cols, art, i, seed, frame)


## A shout (Kampfschrei, a taunt, Alpharuf): three dashed bands running out
## to `r` one after another and thinning as they go, read as sound rather than
## as a hit ring.
static func waves(canvas: CanvasItem, at: Vector2, r: float, p: float, element: String, art: float, seed: int) -> void:
	var cols := Pal.ramp(element)
	for band in range(3):
		var q0 := (p - float(band) * 0.17) / 0.6
		if q0 <= 0.0 or q0 >= 1.0:
			continue
		var rad := r * (0.18 + 0.82 * _out(q0))
		var cover := 1.0 - q0 * q0
		var cells := _ring_cells(at, rad, 2.0, art)
		var big := rad / art
		var phase := band * 3 + seed
		for e: Array in cells:
			var q: Vector2i = e[0]
			var step := int(round(float(e[2]) * big))
			if posmod(step + phase, 8) >= 5 or not PixelPaint.shown(q, cover):
				continue
			PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
		for e: Array in cells:
			var q: Vector2i = e[0]
			var step := int(round(float(e[2]) * big))
			if posmod(step + phase, 8) >= 5 or not PixelPaint.shown(q, cover):
				continue
			var north := sin(float(e[2])) < -0.2
			PixelPaint.cell(canvas, q, (cols[3] if north else cols[2]) if int(e[1]) == 0 else cols[1], art)


## The path of a blink, dash or leap from `from` to `to` (ground points): a
## streak of pixels widening towards the end, dissolving from the start end
## first, with sparkles of the `element` beside it.
static func trail(canvas: CanvasItem, from: Vector2, to: Vector2, p: float, element: String, art: float, seed: int) -> void:
	var length := from.distance_to(to)
	if length < art * 2.0 or p >= 1.0:
		return
	var cols := Pal.ramp(element)
	var dir := (to - from) / length
	var side := dir.orthogonal()
	var steps := int(length / art)
	var cells := {}
	for i in range(steps + 1):
		var f := float(i) / float(maxi(1, steps))
		var cover := 1.0 - p * 1.6 + f * 0.9
		if cover <= 0.0:
			continue
		var half := 0 if f < 0.35 else (1 if f < 0.85 else 2)
		var base := from + dir * float(i) * art
		for o in range(-half, half + 1):
			var q := PixelPaint.at(base + side * float(o) * art, art)
			if cells.has(q) or not PixelPaint.shown(q, cover):
				continue
			cells[q] = cols[3] if o == 0 else cols[2]
	var head := PixelPaint.at(to, art)
	if p < 0.5 and cells.has(head):
		cells[head] = cols[4]
	for q: Vector2i in cells:
		PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	for q: Vector2i in cells:
		PixelPaint.cell(canvas, q, cells[q], art)
	# sparkles beside the streak
	var frame := int(p * 24.0)
	for i in range(int(steps / 5)):
		var f := (float(i) + _rnd(seed, i)) * 5.0 / float(maxi(1, steps))
		if f > 1.0 or 1.0 - p * 1.6 + f * 0.9 < 0.4 or posmod(frame + i, 3) == 0:
			continue
		var off := (_rnd(seed, i + 50) * 2.0 - 1.0) * 4.0
		var q := PixelPaint.at(from + dir * f * length + side * off * art - Vector2(0, p * 4.0 * art), art)
		PixelPaint.cell(canvas, q, cols[4] if i % 2 == 0 else cols[3], art)


## A small radial burst `cells` art cells round (blink ends, parry, cast
## flashes, a trap's boom): pixel rays shooting out of a short flash and
## dissolving, long and short ones in turn.
static func burst(canvas: CanvasItem, at: Vector2, cells: int, p: float, element: String, art: float, seed: int) -> void:
	if p >= 1.0:
		return
	var cols := Pal.ramp(element)
	var cover := 1.0 - smoothstep(0.45, 1.0, p)
	var go := _out(p / 0.55)
	var c := PixelPaint.at(at, art)
	var rays := {}
	for k in range(8):
		var a := TAU * float(k) / 8.0 + (_rnd(seed, k) - 0.5) * 0.25 + float(seed % 7) * 0.1
		var reach := float(cells) * (1.0 if k % 2 == 0 else 0.6) * go
		var length := maxf(2.0, float(cells) * 0.45 * (1.0 - p * 0.6))
		var dir := Vector2.from_angle(a)
		var s := maxf(0.0, reach - length)
		while s <= reach:
			var q := c + Vector2i((dir * s).round())
			var into := (reach - s) / length
			if not rays.has(q):
				rays[q] = cols[4] if into < 0.15 and k % 2 == 0 else (cols[3] if into < 0.5 else cols[2])
			s += 1.0
	if p < 0.3:
		var flash := (1.0 - p / 0.3) * float(cells) * 0.35 + 1.0
		for y in range(-int(flash), int(flash) + 1):
			for x in range(-int(flash), int(flash) + 1):
				var d := Vector2(x, y).length()
				if d <= flash:
					rays[c + Vector2i(x, y)] = cols[3] if d < flash * 0.5 else cols[2]
	rays = _thin(rays, cover)
	for q: Vector2i in rays:
		PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	for q: Vector2i in rays:
		PixelPaint.cell(canvas, q, rays[q], art)


## A shield round the hero standing at `at` (its centre at at + body): size 0
## the absorb flash and guard, 1 Kristallschild, Bollwerk and Eid, 2
## Unbezwingbar (bigger, a double rim and hex plates). Only its rim and a
## band inside it are drawn, never the hero's middle: outline, lit upper-left
## arc with a crawling shimmer, a gloss streak and sparse facets. `grow` 0..1
## pops it in with an overshoot, `fade` 0..1 shows it by the dither.
static func dome(canvas: CanvasItem, at: Vector2, body: Vector2, size: int, grow: float, fade: float, element: String, art: float, clock: float) -> void:
	if fade <= 0.0 or grow <= 0.0:
		return
	var cols := Pal.ramp(element)
	var half: Vector2 = [Vector2(12.0, 17.0), Vector2(14.0, 19.0), Vector2(18.0, 23.0)][clampi(size, 0, 2)]
	var s := maxf(0.2, _back(grow))
	var rx := half.x * s
	var ry := half.y * s
	var cc := (at + body) / art
	var frame := _frame(clock)
	var avg := (rx + ry) * 0.5
	var big := size >= 2
	for gy in range(floori(cc.y - ry - 2.0), ceili(cc.y + ry + 2.0) + 1):
		for gx in range(floori(cc.x - rx - 2.0), ceili(cc.x + rx + 2.0) + 1):
			var rel := Vector2(float(gx) + 0.5 - cc.x, float(gy) + 0.5 - cc.y)
			var sn := Vector2(rel.x / rx, rel.y / ry).length()
			if sn < 0.55:
				continue
			var depth := (1.0 - sn) * avg
			if depth < -1.0:
				continue
			var q := Vector2i(gx, gy)
			var ang := rel.angle()
			var lit := ang > -2.7 and ang < -0.9
			var col := Color(0, 0, 0, 0)
			var cover := fade
			if depth < 0.0:
				col = Pal.INK
			elif depth < 1.0:
				col = cols[3] if lit else cols[2]
				if lit and posmod(gx + gy + frame, 9) == 0:
					col = cols[4]
				elif posmod(int(round(ang * avg)) - frame, 15) == 0:
					col = cols[3]
			elif depth < 2.0:
				col = cols[2] if ang < 0.0 else cols[1]
			elif big and depth >= 3.0 and depth < 4.0:
				# the inner of the double rim
				col = cols[2] if ang < 0.0 else cols[1]
				cover = fade * 0.8
			elif depth >= 2.0 and sn > 0.6:
				if ang > -2.55 and ang < -1.95 and depth < (5.0 if big else 4.0):
					# the gloss streak
					col = cols[3]
				elif big:
					var id := _hex(rel.x, rel.y, 4.5)
					if id != _hex(rel.x + 1.0, rel.y, 4.5) or id != _hex(rel.x, rel.y + 1.0, 4.5):
						col = cols[2] if ang < 0.0 else cols[1]
						cover = fade * 0.6
				elif posmod(gx - gy + frame / 3, 8) == 0:
					col = cols[2]
					cover = fade * 0.4
			if col.a <= 0.0 or not PixelPaint.shown(q, cover):
				continue
			PixelPaint.cell(canvas, q, col, art)


## The hex plate (axial coordinates) a point (art cells from the centre) lies on.
static func _hex(x: float, y: float, size: float) -> Vector2i:
	var qf := (sqrt(3.0) / 3.0 * x - y / 3.0) / size
	var rf := (2.0 / 3.0 * y) / size
	var sf := -qf - rf
	var qr := roundf(qf)
	var rr := roundf(rf)
	var sr := roundf(sf)
	var dq := absf(qr - qf)
	var dr := absf(rr - rf)
	var ds := absf(sr - sf)
	if dq > dr and dq > ds:
		qr = -rr - sr
	elif dr > ds:
		rr = -qr - sr
	return Vector2i(int(qr), int(rr))


## The rage aura (Raserei, Blutrausch; `element` blood or fire): outlined flame
## tongues licking up along the hero's sides and over his head, never over his
## middle, flickering with `clock`; `strength` 0..1 (0.6 frenzy, 1 bloodlust)
## sets their height and count; embers circle his feet and rise.
static func flames(canvas: CanvasItem, at: Vector2, body: Vector2, strength: float, element: String, art: float, clock: float, seed: int) -> void:
	var cols := Pal.ramp(element)
	var chest := PixelPaint.at(at + body, art)
	var feet := chest + Vector2i(0, int(HERO_HALF.y))
	var frame := _frame(clock)
	strength = clampf(strength, 0.0, 1.0)
	var grow := 0.75 + 0.55 * strength
	# the floor under him glows in the rage's colour (dithered)
	PixelPaint.disc(canvas, (Vector2(feet) + Vector2(0.5, 0.5)) * art, 11.0 * art, 3.5 * art, cols[1], art, 0.35 + 0.15 * strength)
	var cells := {}
	# tongues rising from the floor round his feet, tallest at his sides, none
	# in front of his legs; the outer ones lean out
	var roots: Array = [[6, 2, 8.0], [8, 2, 11.0], [10, 1, 9.0], [12, 1, 5.0]]
	if strength < 0.8:
		roots.resize(3)
	var index := 0
	for root: Array in roots:
		for sgn: int in [-1, 1]:
			var base := feet + Vector2i(sgn * int(root[0]), -int(_rnd(seed, index) * 2.0))
			var tall := (float(root[2]) + _rnd(seed, index + 20) * 3.0) * grow
			_tongue(cells, base, tall, int(root[1]), sgn * (1 if int(root[0]) < 10 else 2), cols, frame, index)
			index += 1
	# loose licks breaking off the tips and rising past his shoulders
	for k in range(2 + int(round(strength * 2.0))):
		var phase := fmod(clock * 1.3 + _rnd(seed, k + 140), 1.0)
		var sgn := -1 if k % 2 == 0 else 1
		var base := feet + Vector2i(sgn * (7 + int(_rnd(seed, k + 150) * 4.0)), -10 - int(phase * 16.0 * grow))
		if phase < 0.8:
			_tongue(cells, base, 3.0 * (1.0 - phase) + 1.0, 1 if phase < 0.3 else 0, sgn, cols, frame, index + k)
	# a small crown of flame over his head
	var tops: Array = [0, -3, 3]
	for i in range(int(round(strength * 3.0))):
		var base := chest + Vector2i(int(tops[i]), -int(HERO_HALF.y) + 4)
		_tongue(cells, base, (4.0 - float(i)) * grow, 1, int(signf(float(tops[i]))), cols, frame, index + 9 + i)
	# keep his middle clear
	for q: Vector2i in cells.keys():
		var rel := q - chest
		if absi(rel.x) < 6 and rel.y > -int(HERO_HALF.y) + 4 and rel.y < int(HERO_HALF.y) - 1:
			cells.erase(q)
	# a ring of embers round the feet, crawling
	var n := 26
	for k in range(n):
		if posmod(k + frame, 3) != 0:
			continue
		var a := TAU * float(k) / float(n)
		var q := feet + Vector2i(int(round(cos(a) * 10.0)), int(round(sin(a) * 2.5)))
		if not cells.has(q):
			cells[q] = cols[3] if sin(a) > 0.0 else cols[2]
	_flush(canvas, cells, art)
	# loose embers rising beside him (no outline: they are sparks)
	for k in range(3 + int(strength * 3.0)):
		var phase := fmod(clock * (0.7 + 0.3 * _rnd(seed, k + 60)) + _rnd(seed, k + 70), 1.0)
		var sgn := -1 if k % 2 == 0 else 1
		var q := feet + Vector2i(sgn * (7 + int(_rnd(seed, k + 80) * 5.0)), -int(phase * 34.0 * grow))
		if PixelPaint.shown(q, 1.0 - phase):
			PixelPaint.cell(canvas, q, cols[4] if phase < 0.2 else (cols[3] if phase < 0.6 else cols[2]), art)


## One flame tongue into a cell map: `tall` cells high from `base`, `width`
## its half width at the root, leaning `lean` cells at the tip, flickering.
static func _tongue(cells: Dictionary, base: Vector2i, tall: float, width: int, lean: int, cols: Array, frame: int, index: int) -> void:
	var h := maxi(2, int(round(tall * (0.7 + 0.3 * float(posmod(frame + index * 5, 4)) / 3.0))))
	var sway: int = lean + [0, 1, 0, -1][posmod(frame / 2 + index, 4)]
	for j in range(h):
		var f := float(j) / float(h)
		var hw := int(floor(float(width) * (1.0 - f) + 0.35))
		# the tongue wavers: an S-bend along its height plus the lean at the tip
		var dx := int(round(float(sway) * f * f + sin(f * 5.0 + float(frame + index) * 0.9) * f * 0.9))
		for x in range(-hw, hw + 1):
			var q := base + Vector2i(dx + x, -j)
			var edge := hw > 0 and absi(x) == hw
			var col: Color = cols[3] if (not edge and f < 0.6) else (cols[2] if f < 0.85 else cols[1])
			if j <= 1 and x == 0:
				col = cols[4]
			# where tongues overlap the brighter one wins (a merged sheet)
			if cells.has(q) and _rank(cells[q], cols) >= _rank(col, cols):
				continue
			cells[q] = col


## A ramp colour's brightness rank (its index in the ramp, -1 when foreign).
static func _rank(col: Color, cols: Array) -> int:
	return cols.find(col)


## Gas over a zone of radius `r` (world px), on top of its pool: lumpy
## outlined clouds churning and drifting slowly, light on top and wispy
## (dithered, without outline) underneath, never past `r`.
static func puffs(canvas: CanvasItem, at: Vector2, r: float, art: float, clock: float, seed: int, element := "poison") -> void:
	var cols := Pal.ramp(element)
	var big := r / art
	if big < 4.0:
		return
	var tick := floorf(clock * PixelPaint.FPS) / PixelPaint.FPS
	var cc := at / art
	var count := clampi(int(big / 4.5), 5, 8)
	var clouds: Array = []
	for i in range(count):
		var spin := (1.0 if i % 2 == 0 else -1.0) * 0.08
		# spread evenly over the zone: rings of clouds round a middle one
		var a := TAU * (float(i) + _rnd(seed, i) * 0.6) / float(count - 1) + tick * spin
		var dist := big * (0.3 + 0.42 * _rnd(seed, i + 10) + 0.05 * sin(tick * 0.6 + float(i)))
		if i == 0:
			dist = big * 0.06
		var centre := cc + Vector2.from_angle(a) * dist * Vector2(1.0, 0.85)
		var size := clampf(big * 0.12, 2.5, 5.5) * (0.8 + 0.4 * _rnd(seed, i + 20))
		# each puff breathes: it swells and thins in turn
		var breath := 0.5 + 0.5 * sin(tick * (1.1 + 0.3 * _rnd(seed, i + 40)) + float(i) * 1.7)
		clouds.append([centre, size * (0.85 + 0.25 * breath), i, breath])
	clouds.sort_custom(func(x: Array, y: Array) -> bool: return (x[0] as Vector2).y < (y[0] as Vector2).y)
	for cloud: Array in clouds:
		var centre: Vector2 = cloud[0]
		var size: float = cloud[1]
		var i: int = cloud[2]
		var breath: float = cloud[3]
		# a little cumulus: a round head over two smaller lumps that roll slowly
		var roll := sin(tick * 1.3 + float(i) * 2.1)
		var blobs: Array = [[centre + Vector2(roll * 0.4, -size * 0.25), size * 0.78]]
		for k in range(2):
			var sgn := -1.0 if k == 0 else 1.0
			var lump := size * (0.5 + 0.18 * _rnd(seed, i * 3 + k + 30))
			blobs.append([centre + Vector2(sgn * size * (0.62 + 0.1 * roll * sgn), size * 0.3), lump])
		var cells := {}
		for gy in range(floori(centre.y - size * 1.5), ceili(centre.y + size * 1.3) + 1):
			for gx in range(floori(centre.x - size * 1.5), ceili(centre.x + size * 1.5) + 1):
				var pt := Vector2(float(gx) + 0.5, float(gy) + 0.5)
				if pt.distance_to(cc) > big - 1.0:
					continue
				# shaded per lump: lit up-left, shade down-right, a rim of the deep colour
				var best := -1.0
				var lit := 0.0
				for blob: Array in blobs:
					var rel: Vector2 = (pt - blob[0]) / float(blob[1])
					var inside := 1.0 - rel.length()
					if inside > best:
						best = inside
						lit = -(rel.x * 0.6 + rel.y * 0.8)
				if best < 0.0:
					continue
				var q := Vector2i(gx, gy)
				# glowing gas: the light half of the ramp, a darker rim and belly
				var col: Color = cols[2]
				if best < 0.2:
					col = cols[1] if lit < 0.3 else cols[2]
				elif lit > 0.55 and best > 0.45:
					col = cols[4] if posmod(gx * 3 + gy, 5) == 0 else cols[3]
				elif lit > -0.2:
					col = cols[3]
				cells[q] = col
		# a puff thins out (by the dither) as it breathes out
		cells = _thin(cells, 0.7 + 0.3 * breath)
		for q: Vector2i in cells:
			if not cells.has(q + Vector2i(0, 1)):
				PixelPaint.cell(canvas, q + Vector2i(0, 1), cols[0], art)
		for q: Vector2i in cells:
			PixelPaint.cell(canvas, q, cells[q], art)
		# a wisp rising off the top now and then
		var phase := fmod(clock * 0.6 + _rnd(seed, i + 90), 1.0)
		var wisp := Vector2i((centre + Vector2(sin(phase * 6.0 + float(i)) * 1.5, -size * 1.3 - phase * 6.0)).floor())
		if PixelPaint.shown(wisp, 1.0 - phase) and Vector2(wisp).distance_to(cc) < big - 1.0:
			PixelPaint.cell(canvas, wisp, cols[3] if phase < 0.4 else cols[2], art)


## A target mark (Markieren) centred on `at` (the enemy's head): four gold
## corner brackets closing in, then pulsing, a red cell in the middle; `fade`
## 0..1 shows it by the dither.
static func reticle(canvas: CanvasItem, at: Vector2, p: float, fade: float, art: float, clock: float) -> void:
	if fade <= 0.0:
		return
	var gold := Pal.ramp("gold")
	var red := Pal.ramp("blood")
	var s := int(round(lerpf(15.0, 8.0, _back(p / 0.3))))
	if p >= 0.3 and posmod(_frame(clock), 6) < 3:
		s += 1
	var c := PixelPaint.at(at, art)
	var cells := {}
	for sx: int in [-1, 1]:
		for sy: int in [-1, 1]:
			var corner := c + Vector2i(sx * s, sy * s)
			for k in range(4):
				cells[corner - Vector2i(sx * k, 0)] = gold[3] if sy < 0 else gold[2]
				cells[corner - Vector2i(0, sy * k)] = gold[3] if sy < 0 else gold[2]
	cells[c] = red[3]
	_flush(canvas, _thin(cells, fade), art)


## `word` in a 3x5 pixel font (A-Z, 0-9, !) outlined in Pal.INK and centred
## on `at`, its top row lighter; `fade` 0..1: whole down to 0.5 (so it stays
## readable), then thinning out by the dither.
static func text(canvas: CanvasItem, at: Vector2, word: String, col: Color, art: float, fade: float) -> void:
	if fade <= 0.0 or word.is_empty():
		return
	word = word.to_upper()
	var width := word.length() * 4 - 1
	var start := PixelPaint.at(at, art) - Vector2i(width / 2, 2)
	var cells := {}
	for i in range(word.length()):
		var glyph: Array = FONT.get(word[i], FONT[" "])
		for y in range(5):
			var row: String = glyph[y]
			for x in range(3):
				if row[x] == "1":
					cells[start + Vector2i(i * 4 + x, y)] = col.lightened(0.3) if y == 0 else (col.darkened(0.2) if y == 4 else col)
	_flush(canvas, _thin(cells, fade * 2.0), art)


## The trail behind a talent shot at `at` flying along `dir`: `cells` art
## cells of the `element` behind it, densest and widest at the head, the
## dither shifting with `clock` so it sparkles.
static func shot_trail(canvas: CanvasItem, at: Vector2, dir: Vector2, element: String, art: float, cells: int, clock: float) -> void:
	var cols := Pal.ramp(element)
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var side := d.orthogonal()
	var frame := _frame(clock)
	var shown := {}
	for i in range(1, cells + 1):
		var f := float(i) / float(cells)
		var base := at - d * float(i) * art
		var half := 1 if f < 0.45 else 0
		for o in range(-half, half + 1):
			var q := PixelPaint.at(base + side * float(o) * art, art)
			if shown.has(q):
				continue
			var cover := (1.0 - f) * (0.75 if o != 0 else 1.0)
			if not PixelPaint.shown(q + Vector2i(frame, 0), cover):
				continue
			shown[q] = cols[3] if f < 0.25 and o == 0 else (cols[2] if f < 0.6 else cols[1])
	for q: Vector2i in shown:
		if not shown.has(q + Vector2i(0, 1)):
			PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	for q: Vector2i in shown:
		PixelPaint.cell(canvas, q, shown[q], art)
