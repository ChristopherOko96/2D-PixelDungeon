extends RefCounted
## Procedural pixel art of the active talents (src/vfx/talent_fx.gd): novas,
## shouts, blink and dash trails, bursts, shields, the rage aura, poison
## puffs, the target mark, pixel words and shot trails. Everything is whole art
## cells drawn through PixelPaint.cell (so PixelPaint.clip stops it at walls),
## opaque, fading and thinning by the 4x4 ordered dither, with a dark outline
## or underlay, a lit north rim and spec colour only in single highlight cells
## (palette: src/vfx/talent_palette.gd). Decorative sizes are in art cells
## (crypt 2 world px, story worlds 3), hit radii in exact world px. Presentation only.
##
## Shapes here, matter in the particles (review 2026-10-31, BEFUND.md 5): while
## the host has particles (paint_matter false, set by src/vfx/talent_fx.gd
## before it draws) these effects paint only what is a shape, not matter: the
## flash frames, rings and pressure rings, cores, tears, the fireball and its
## licks, the ice star, the void's gulp and the core's flash. Every flying bit
## (a nova's rim debris, the boom's sparks, the shatter's shards and mist, the
## blizzard's flakes and slivers, the crater's tongues and embers, the chain's
## sparks, the void's motes, the Gefuege's comets and streams) is thrown into
## src/vfx/particles.gd instead, where it falls, bounces, slides and lies.

const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## The hero figure in art cells (16 x 28 around his chest).
const HERO_HALF := Vector2(8.0, 14.0)
## The white-hot heart of fire (user feedback 2026-10-31: the Feuermagier's
## fire wants a white heart and a white flash frame; single cells and one frame only).
const WHITE_HOT := Color("fff6e6")
## Ash the Flammenmeer burns down to (dark to light).
const ASH := [Color("3a3330"), Color("6a625c"), Color("9a918a")]
## The white of a frost flash frame and a lance's glinting tip (single cells, one frame).
const FROST_WHITE := Color("f4feff")
## The void's black heart, deeper than any floor (its cores, tears and folds).
const VOID_BLACK := Color("0a0612")
## The 8 facings of an ice sliver (art cell steps).
const DIR8 := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
## False while the host's particles carry the flying matter (talent_fx sets it
## before every draw): the effects then paint their shapes only.
static var paint_matter := true
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
	# debris along the rim (the particles' when the host has them: talent_fx._rim)
	if not paint_matter:
		return
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


# ---------- the Elementsprache: cast, flight, impact, traps ----------

## A filled ball of radius `r` cells round `c` into a cell map, lit from the
## upper left (lite, body, shade), no outline (the caller flushes one).
static func _ball(cells: Dictionary, c: Vector2i, r: int, cols: Array) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := Vector2(x, y).length()
			if d > float(r) + 0.5:
				continue
			var lit := Vector2(float(x) + float(r) * 0.4, float(y) + float(r) * 0.4).length() / maxf(1.0, float(r))
			cells[c + Vector2i(x, y)] = cols[3] if lit < 0.55 else (cols[2] if lit < 1.15 else cols[1])


## The rim of an ellipse (`rx` by `ry` cells round `c`) into a cell map, lit
## on its north rim.
static func _oval_ring(cells: Dictionary, c: Vector2i, rx: float, ry: float, dark: Color, lit: Color) -> void:
	var n := maxi(12, int(TAU * rx))
	for k in range(n):
		var a := TAU * float(k) / float(n)
		var q := c + Vector2i(int(round(cos(a) * rx)), int(round(sin(a) * ry)))
		cells[q] = lit if sin(a) < -0.2 else dark


## FLIGHT: a talent shot at `at` flying along `dir` as the matter of its
## `element`: a core ball `core` cells round shaped by the element's kind
## (sparks a round ball with a hot heart and a lick of flame behind, shards a
## facetted lance, drops a teardrop, motes a dark heart with motes circling
## it, chips a rough lump), a dithered trail `trail` cells long behind it and,
## for fire, embers peeling off and sinking as they cool. Ink outline, lit from
## the upper left, the spec colour in single cells. `fire` (vfx_talents.json
## "fire"): heart = radius of a white-hot heart in the ball, tail = cells of
## ember tail behind it that cool down the ramp and sag as they fall, style
## "spear" = the Infernospeer (an ember spear with its heat shimmer). The same
## dictionary carries the other mages' looks: style "lance" = the Frostlanze
## (_lance: length cells, mist cover of its frost-mist trail), style "void" =
## the Leerengeschoss (_void_core: a dark core whose trail of motes is drawn
## in towards it; crack > 0 the Leerenlanze's tear behind it, no outward trail).
static func shot(canvas: CanvasItem, at: Vector2, dir: Vector2, element: String, art: float, core: int, trail: int, clock: float, seed: int, fire: Dictionary = {}) -> void:
	var cols := Pal.ramp(element)
	var kind := Pal.kind(element)
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var frame := _frame(clock)
	var style := str(fire.get("style", ""))
	if trail > 0 and style != "void":
		shot_trail(canvas, at, d, element, art, trail, clock)
	var c := PixelPaint.at(at, art)
	var cells := {}
	var r := maxi(1, core)
	var haze := {}
	var motes := {}
	if element == "fire" and style == "spear":
		kind = "spear"
	elif style == "lance" or style == "void":
		kind = style
	match kind:
		"lance":
			_lance(cells, haze, c, d, r, int(fire.get("length", 5)), float(fire.get("mist", 0.8)), cols, frame, seed)
		"void":
			_void_core(cells, motes, c, d, r, trail, int(fire.get("crack", 0)), cols, clock, frame, seed)
		"spear":
			_spear(cells, haze, c, d, r, int(fire.get("length", 7)), float(fire.get("shimmer", 0.4)), cols, frame, seed)
		"shard":
			# a lance: a diamond along the flight, r wide, its tip the brightest
			var length := r * 2 + 2
			for k in range(-length, length + 1):
				var f := 1.0 - absf(float(k)) / float(length)
				var hw := int(floor(float(r) * f + 0.3))
				for o in range(-hw, hw + 1):
					var q := c + Vector2i((d * float(k) + d.orthogonal() * float(o)).round())
					cells[q] = cols[4] if o == 0 and k > length / 2 else (cols[3] if o <= 0 else cols[2])
		"drop":
			_ball(cells, c, r, cols)
			for k in range(1, r + 2):
				cells[c - Vector2i((d * float(r + k)).round())] = cols[2] if k < r + 1 else cols[1]
		"mote":
			# a dark heart with a bright rim, motes circling it
			for y in range(-r, r + 1):
				for x in range(-r, r + 1):
					var dd := Vector2(x, y).length()
					if dd <= float(r) + 0.5:
						cells[c + Vector2i(x, y)] = cols[0] if dd < float(r) - 0.6 else cols[3]
			for k in range(3):
				var a := clock * 7.0 + float(k) * TAU / 3.0 + float(seed % 7)
				var q := c + Vector2i((Vector2.from_angle(a) * (float(r) + 1.5 + sin(clock * 5.0 + float(k))) * Vector2(1.0, 0.7)).round())
				cells[q] = cols[4] if k == frame % 3 else cols[3]
		"chip":
			for y in range(-r, r + 1):
				for x in range(-r, r + 1):
					if absi(x) + absi(y) <= r + (1 if posmod(x * 3 + y + seed, 3) == 0 else 0):
						cells[c + Vector2i(x, y)] = cols[3] if y < 0 and x <= 0 else (cols[2] if y <= 0 else cols[1])
		_:
			_ball(cells, c, r, cols)
			cells[c + Vector2i(-1 if r > 1 else 0, -1 if r > 1 else 0)] = cols[4]
			if element == "fire":
				# a white-hot heart: the ball burns brightest in its middle
				var heart := int(fire.get("heart", 0))
				if heart > 0:
					for y in range(-heart, heart + 1):
						for x in range(-heart, heart + 1):
							if absi(x) + absi(y) <= heart:
								cells[c + Vector2i(x, y)] = cols[4]
					cells[c] = WHITE_HOT
				# a lick of flame trailing the ball, flickering on the beat
				var lick := c - Vector2i((d * float(r + 1)).round()) + Vector2i(0, [0, -1, 0, 1][frame % 4])
				cells[lick] = cols[3]
				cells[lick - Vector2i(d.round())] = cols[2]
	if not haze.is_empty() and kind == "lance":
		# the frost mist lies behind the lance, under its outline
		PixelPaint.paint(canvas, haze, art)
	_flush(canvas, cells, art)
	if not haze.is_empty() and kind != "lance":
		PixelPaint.paint(canvas, haze, art)
	if not motes.is_empty():
		for q: Vector2i in motes:
			if not motes.has(q + Vector2i(0, 1)) and not cells.has(q + Vector2i(0, 1)):
				PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
		PixelPaint.paint(canvas, motes, art)
	if element == "fire":
		var side := d.orthogonal()
		var tail := int(fire.get("tail", 0))
		if tail > 0:
			# the ember tail: solid behind the ball, cooling down the ramp and
			# sagging as the embers fall, widest near the ball
			var tcells := {}
			for i in range(1, tail + 1):
				var f := float(i) / float(tail)
				var sag := f * f * float(tail) * 0.45
				var wob := sin(float(i) * 1.7 + clock * 9.0) * (0.4 + f * 1.1)
				var q := c - Vector2i((d * float(r + i)).round()) + Vector2i(int(round(wob * side.x)), int(round(wob * side.y + sag)))
				if not PixelPaint.shown(q + Vector2i(frame, 0), 1.0 - f * 0.7):
					continue
				tcells[q] = cols[4] if f < 0.15 else (cols[3] if f < 0.4 else (cols[2] if f < 0.7 else cols[1]))
				if f < 0.5:
					var w := q + Vector2i((side * (1.0 if i % 2 == 0 else -1.0)).round())
					if not tcells.has(w):
						tcells[w] = cols[2] if f < 0.3 else cols[1]
			for q: Vector2i in tcells:
				if not tcells.has(q + Vector2i(0, 1)):
					PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
			PixelPaint.paint(canvas, tcells, art)
		# embers peel off behind the ball, tumble and fall as they cool
		for k in range(3 + r * 2 + tail / 2):
			var age := fmod(clock * 2.4 + _rnd(seed, k), 1.0)
			var spot := at - d * (float(r) * art + age * (6.0 + float(trail)) * art) + side * sin(float(k) * 2.3 + clock * 7.0) * (1.0 + age * 3.0) * art + Vector2(0, age * age * (5.0 + float(tail)) * art)
			var q := PixelPaint.at(spot, art)
			if PixelPaint.shown(q, 1.0 - age):
				PixelPaint.cell(canvas, q, cols[3] if age < 0.3 else (cols[2] if age < 0.7 else cols[1]), art)


## The Infernospeer into a cell map: a spear of embers `length` cells before
## and behind cell `c` along `d`, `r` wide behind its point, the point white-hot
## and the shaft cooling down the ramp towards its butt, its tail cells
## flickering on the beat; `haze` takes the heat shimmer beside it (dark cells
## wobbling along the shaft, shown at `shimmer` cover, drawn without outline).
static func _spear(cells: Dictionary, haze: Dictionary, c: Vector2i, d: Vector2, r: int, length: int, shimmer: float, cols: Array, frame: int, seed: int) -> void:
	var side := d.orthogonal()
	for k in range(-length, length + 1):
		var f := float(k + length) / float(2 * length)
		# widest a third behind the point, tapering to the point and the butt
		var hw: int
		if k > length * 0.3:
			hw = int(floor(float(r) * (float(length) - float(k)) / (float(length) * 0.7) + 0.3))
		else:
			hw = int(floor(float(r) * (0.45 + 0.55 * (float(k + length) / (float(length) * 1.3))) + 0.3))
		if f < 0.3 and posmod(k + frame, 3) == 0:
			hw = maxi(0, hw - 1)
		for o in range(-hw, hw + 1):
			var q := c + Vector2i((d * float(k) + side * float(o)).round())
			var col: Color
			if k >= length - 1:
				col = WHITE_HOT if o == 0 else cols[4]
			elif f > 0.6:
				col = cols[4] if o == 0 else cols[3]
			elif f > 0.3:
				col = cols[3] if o <= 0 else cols[2]
			else:
				col = cols[2] if o == 0 else cols[1]
			cells[q] = col
	# the heat shimmer: dark cells beside the shaft hopping on the beat, dithered
	for k in range(-length, length - 1, 2):
		var off := float(r) + 2.0 + float((frame + k) & 1)
		for sgn: int in [-1, 1]:
			var q := c + Vector2i((d * float(k) + side * off * float(sgn)).round())
			if cells.has(q):
				continue
			if PixelPaint.shown(q + Vector2i(frame, k), shimmer):
				haze[q] = cols[1] if (k + frame) % 4 < 2 else cols[0]


## IMPACT of fire, in pushes (user feedback 2026-10-31, "fette Explosionen"):
## a white flash frame, the fireball swelling out of it, lumpy and cooling
## down the ramp as it thins, licks of flame standing off its top, `pulses`
## pressure rings running out one after another within `pulse_span` of the
## life (ink underlay, lit north rim) and sparks flung in arcs that fall; `p`
## 0..1 over its life, `size` art cells its reach, `dir` the hit's flight
## (zero: all round). The sparks that bounce and lie as embers, the scorch
## and the soot are the particles' (src/vfx/particles.gd ember_sparks).
static func boom(canvas: CanvasItem, at: Vector2, dir: Vector2, p: float, art: float, size: int, seed: int, spec: Dictionary = {}) -> void:
	if p >= 1.0 or p < 0.0:
		return
	var cols := Pal.ramp("fire")
	var c := PixelPaint.at(at, art)
	var frame := int(p * 60.0)
	var flash := float(spec.get("flash", 0.09))
	var pulses := int(spec.get("pulses", 3))
	var pulse_span := float(spec.get("pulse_span", 0.4))
	var reach := float(size) * art
	# the white flash: one hard frame of white heat, the ramp's top round it
	if p < flash:
		var fr := reach * (0.7 + 0.3 * p / flash)
		PixelPaint.disc(canvas, at, fr, fr * 0.85, cols[4], art)
		PixelPaint.disc(canvas, at, fr * 0.6, fr * 0.5, WHITE_HOT, art)
	# the fireball swelling and cooling
	var swell := clampf((p - flash * 0.5) / 0.4, 0.0, 1.0)
	if p < 0.6 and swell > 0.0:
		var rc := reach / art * (0.35 + 0.65 * _out(swell))
		var cover := 1.0 - smoothstep(0.25, 0.6, p)
		var cool := clampf(p / 0.6, 0.0, 1.0)
		var cells := {}
		for y in range(-int(rc * 0.8) - 1, int(rc * 0.8) + 2):
			for x in range(-int(rc) - 1, int(rc) + 2):
				var dd := Vector2(float(x), float(y) / 0.8).length() / maxf(1.0, rc)
				if dd > 1.0:
					continue
				var q := c + Vector2i(x, y)
				if not PixelPaint.shown(q, cover * (1.2 - dd * 0.5)):
					continue
				# hotter inside, cooling with age, lumpy so it reads as fire and not a disc
				var heat := (1.0 - dd) * (1.0 - cool * 0.8) + _rnd(seed + frame / 3, x * 31 + y) * 0.25
				cells[q] = cols[4] if heat > 0.75 else (cols[3] if heat > 0.5 else (cols[2] if heat > 0.25 else cols[1]))
		# licks standing up off the top
		var licks := {}
		for i in range(3 + size / 2):
			var b := c + Vector2i(int(round((_rnd(seed, i) - 0.5) * rc * 1.6)), -int(rc * 0.5 * (1.0 - _rnd(seed, i + 7) * 0.5)))
			_tongue(licks, b, (2.0 + _rnd(seed, i + 9) * float(size) * 0.5) * (1.0 - p / 0.6), 1, 0, cols, int(p * 24.0), i)
		for q: Vector2i in licks:
			if not cells.has(q):
				cells[q] = licks[q]
		_flush(canvas, cells, art)
	# the pressure rings, one after another, each thinning as it runs out
	for j in range(pulses):
		var t0 := float(j) / float(pulses) * pulse_span * 0.6
		var t := (p - t0) / (pulse_span * 0.7)
		if t <= 0.0 or t >= 1.0:
			continue
		var rad := reach * (0.3 + 1.3 * _out(t)) * (1.0 - 0.12 * float(j))
		_pressure_ring(canvas, at, rad, 1.0 - t * t, cols, art, seed + j)
	# sparks flung out in arcs and falling (streaks while fast); the particles'
	# ember_sparks when the host has them (they bounce and lie as embers)
	if not paint_matter:
		return
	var sparks := {}
	var biased := dir.length() > 0.1
	for i in range(6 + size):
		var a := dir.angle() + (_rnd(seed, i + 200) - 0.5) * 2.6 if biased else _rnd(seed, i + 200) * TAU
		var born := _rnd(seed, i + 300) * 0.1
		var t := (p - born) / 0.7
		if t <= 0.0 or t >= 1.0:
			continue
		var v := Vector2.from_angle(a) * (0.6 + 0.6 * _rnd(seed, i + 400)) * reach * 1.8
		var pos := at + v * t * Vector2(1.0, 0.6) - Vector2(0.0, reach * 0.9 * (4.0 * t - 4.0 * t * t) * (0.4 + 0.6 * _rnd(seed, i + 500)))
		var q := PixelPaint.at(pos, art)
		if PixelPaint.shown(q, 1.0 - t):
			sparks[q] = cols[4] if t < 0.3 else (cols[3] if t < 0.6 else cols[2])
			if t < 0.5:
				var q2 := PixelPaint.at(pos - v * 0.04, art)
				if q2 != q and not sparks.has(q2):
					sparks[q2] = cols[2]
	PixelPaint.paint(canvas, sparks, art)


## One pressure ring of radius `rad` (world px) round `at`, two cells thick
## over an ink underlay one cell lower, lit on its north rim with glints,
## thinning by the dither at `cover`.
static func _pressure_ring(canvas: CanvasItem, at: Vector2, rad: float, cover: float, cols: Array, art: float, seed: int) -> void:
	if rad < art * 2.0 or cover <= 0.0:
		return
	var ring := _ring(at, rad, 2.0, art)
	var cells := {}
	var ink := {}
	for i in range(0, ring.size(), 4):
		var q := Vector2i(ring[i], ring[i + 1])
		if not PixelPaint.shown(q, cover - 0.15 * float(ring[i + 2])):
			continue
		var north := ring[i + 3] == 1
		var col: Color = cols[3] if ring[i + 2] == 0 else (cols[2] if north else cols[1])
		if ring[i + 2] == 0 and north and posmod(q.x * 7 + q.y * 3 + seed, 7) == 0:
			col = cols[4]
		cells[q] = col
		ink[q + Vector2i(0, 1)] = Pal.INK
	for q: Vector2i in cells:
		ink.erase(q)
	PixelPaint.paint(canvas, ink, art)
	PixelPaint.paint(canvas, cells, art)


## Flammenmeer: fire along a drawn `path` (points [x, y] world px) without a
## drawn line: an ember core along the stroke (dark embers with bright cells
## crawling through them), tongues of flame `tongue` [min, max] cells tall
## every `every` cells, flickering on the 12 fps beat and leaning the way the
## stroke runs, spread over `w` world px half width; `burn` 0..1 how far it
## has burnt down (the tongues shrink, ash greys the stroke by the dither).
## `thin` draws the line still being drawn: a one-cell ember trail with small
## tongues. The charred floor and the buoyant flames under it are the fire
## pool's (src/vfx/pool_paint.gd); the smoke is the gas layer's.
static func fire_line(canvas: CanvasItem, path: Array, w: float, art: float, clock: float, seed: int, burn: float, tongue: Array, every: float, thin := false) -> void:
	if path.size() < 2:
		return
	var cols := Pal.ramp("fire")
	var frame := _frame(clock)
	var cells := {}
	var tongues := {}
	var walked := 0.0
	var step := maxf(2.0, every) * art
	var half := 0 if thin else 1
	var alive := 1.0 - clampf(burn, 0.0, 1.0)
	var index := 0
	for i in range(path.size() - 1):
		var a := Vector2(float(path[i][0]), float(path[i][1]))
		var b := Vector2(float(path[i + 1][0]), float(path[i + 1][1]))
		var length := a.distance_to(b)
		if length < 0.5:
			continue
		var d := (b - a) / length
		var side := d.orthogonal()
		# the ember core: a narrow band of embers, the brightest crawling along it
		var s := 0.0
		while s < length:
			var pt := a + d * s
			var along := int((walked + s) / art)
			for o in range(-half, half + 1):
				var q := PixelPaint.at(pt + side * float(o) * art, art)
				if cells.has(q):
					continue
				var crawl := posmod(along + o * 3 - frame, 7)
				var col: Color = cols[1]
				if o == 0 and crawl == 0:
					col = cols[4] if posmod(along, 3) == 0 else cols[3]
				elif crawl < 3:
					col = cols[2]
				if burn > 0.0 and PixelPaint.shown(q + Vector2i(1, 0), burn):
					col = ASH[1] if crawl < 3 else ASH[0]
				cells[q] = col
			s += art
		# tongues every `step` px across the width, leaning the way the stroke runs
		var spot := fmod(step - fmod(walked, step), step)
		while spot <= length:
			var pt := a + d * spot + side * ((_rnd(seed, index) - 0.5) * (art * 1.5 if thin else w * 1.4))
			var tall := lerpf(float(tongue[0]), float(tongue[1]), _rnd(seed, index + 50)) * (0.8 + 0.2 * sin(clock * 7.0 + float(index))) * alive
			if thin:
				tall *= 0.6
			if tall >= 1.0:
				_tongue(tongues, PixelPaint.at(pt, art), tall, 0 if thin or tall < 3.0 else 1, int(signf(d.x)), cols, frame, index + seed)
			spot += step
			index += 1
		walked += length
	# the stroke with its outline first, the tongues over it
	_flush(canvas, cells, art)
	if not tongues.is_empty():
		_flush(canvas, tongues, art)


## Glutkette: a chain of ember sparks from `from` to `to` (world px, at chest
## height) run out to `reach` 0..1: a jagged string of ember cells hopping on
## the beat, white-hot at its head, sparks leaping off the links and falling
## back; `fade` 0..1 thins it by the dither.
static func ember_chain(canvas: CanvasItem, from: Vector2, to: Vector2, reach: float, fade: float, art: float, clock: float, seed: int) -> void:
	var end := from.lerp(to, clampf(reach, 0.0, 1.0))
	var length := from.distance_to(end)
	if length < art or fade <= 0.0:
		return
	var cols := Pal.ramp("fire")
	var frame := _frame(clock)
	var d := (to - from).normalized()
	var side := d.orthogonal()
	var cells := {}
	var steps := int(length / art)
	for k in range(steps + 1):
		var f := float(k) / float(maxi(1, steps))
		var zig := sin(f * 14.0 + float(seed)) * 2.0 + (0.5 if posmod(k / 3 + frame, 2) == 0 else -0.5)
		var q := PixelPaint.at(from + d * float(k) * art + side * zig * art, art)
		if not PixelPaint.shown(q, fade * (0.6 + 0.4 * f)):
			continue
		if k >= steps - 1:
			cells[q] = WHITE_HOT
		elif k > steps - 4:
			cells[q] = cols[4]
		else:
			cells[q] = cols[3] if posmod(k + frame, 3) == 0 else cols[2]
	# sparks leaping off the links (the particles' when the host has them)
	for i in range(maxi(2, steps / 4) if paint_matter else 0):
		var f := _rnd(seed, i)
		var ph := fmod(clock * 3.0 + _rnd(seed, i + 40), 1.0)
		var q := PixelPaint.at(from + d * f * length + side * (_rnd(seed, i + 80) - 0.5) * 6.0 * art - Vector2(0, (ph - ph * ph * 0.5) * 6.0 * art), art)
		if not cells.has(q) and PixelPaint.shown(q, fade * (1.0 - ph)):
			cells[q] = cols[4] if ph < 0.3 else cols[3]
	for q: Vector2i in cells:
		if not cells.has(q + Vector2i(0, 1)):
			PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	PixelPaint.paint(canvas, cells, art)


## The phoenix's ember wings round `at` (chest height): two fans of flame
## tongues leaning outwards, each `span` cells wide; `k` 0..1 spreads them
## with a pop, `fade` 0..1 thins them by the dither.
static func wings(canvas: CanvasItem, at: Vector2, span: int, k: float, fade: float, art: float, clock: float, seed: int) -> void:
	if fade <= 0.0 or k <= 0.0:
		return
	var cols := Pal.ramp("fire")
	var frame := _frame(clock)
	var c := PixelPaint.at(at, art)
	var cells := {}
	var spread := _back(k)
	for sgn: int in [-1, 1]:
		for i in range(4):
			var f := (float(i) + 0.5) / 4.0
			# the wing arcs: high beside the body, dipping towards its tip
			var base := c + Vector2i(sgn * int(round(float(span) * spread * f)), int(round(-2.0 + f * f * 6.0)))
			var tall := float(span) * 0.9 * (1.0 - f * 0.55) * spread
			_tongue(cells, base, tall, 1 if i < 2 else 0, sgn * (1 + i), cols, frame, i + (0 if sgn < 0 else 4) + seed)
	_flush(canvas, _thin(cells, fade), art)


## The meteor's crater at `at` (radius `r` world px) over the host's lava
## pool: glowing cracks running out from the middle (jagged, pulsing on the
## beat and darkest at their ends), tongues of flame at a few spots and embers
## rising; `k` 0..1 how much of it still glows (it cools towards its end).
static func crater(canvas: CanvasItem, at: Vector2, r: float, k: float, art: float, clock: float, seed: int) -> void:
	if k <= 0.0 or r < art * 4.0:
		return
	var cols := Pal.ramp("fire")
	var frame := _frame(clock)
	var c := PixelPaint.at(at, art)
	var rc := r / art
	var cracks := {}
	for i in range(7):
		var a := TAU * float(i) / 7.0 + _rnd(seed, i) * 0.6
		var length := rc * (0.55 + 0.4 * _rnd(seed, i + 10))
		var pos := Vector2(c) + Vector2(0.5, 0.5)
		var dir := Vector2.from_angle(a)
		var s := rc * 0.12
		while s < length:
			var jag := sin(s * 0.9 + float(i) * 3.0) * 1.5
			var q := Vector2i((pos + dir * s + dir.orthogonal() * jag).floor())
			var pulse := 0.5 + 0.5 * sin(clock * 3.0 + s * 0.3 + float(i))
			var hot := (1.0 - s / length) * k * (0.6 + 0.4 * pulse)
			if PixelPaint.shown(q, 0.4 + hot * 0.6):
				cracks[q] = cols[4] if hot > 0.75 else (cols[3] if hot > 0.45 else (cols[2] if hot > 0.2 else cols[1]))
			s += 1.0
	for q: Vector2i in cracks:
		if not cracks.has(q + Vector2i(0, 1)):
			PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	PixelPaint.paint(canvas, cracks, art)
	# tongues at a few spots, embers rising off the field: the particles'
	# buoyant flames and embers when the host has them (talent_fx._zone_matter)
	if not paint_matter:
		return
	var tongues := {}
	for i in range(4):
		var b := PixelPaint.at(at + Vector2.from_angle(TAU * float(i) / 4.0 + 0.8 + _rnd(seed, i + 30)) * r * (0.3 + 0.35 * _rnd(seed, i + 40)), art)
		_tongue(tongues, b, (4.0 + 4.0 * _rnd(seed, i + 50)) * k * (0.8 + 0.2 * sin(clock * 8.0 + float(i) * 2.0)), 1, 0, cols, frame, i + seed)
	_flush(canvas, tongues, art)
	for i in range(8):
		var ph := fmod(clock * 0.7 + _rnd(seed, i + 60), 1.0)
		var q := PixelPaint.at(at + Vector2(sin(float(i) * 2.1 + clock) * r * 0.6, -ph * 24.0 * art), art)
		if PixelPaint.shown(q, (1.0 - ph) * k):
			PixelPaint.cell(canvas, q, cols[3] if ph < 0.5 else cols[2], art)


## CAST: `cells` pixels of the `element` gathering at `hand` (world px) from
## `reach` art cells away over `p` 0..1 (slow start, a snap at the end),
## brightening as they close, then a flash `flash` cells wide that dithers
## out. The weight of a talent shows in how many come and from how far.
static func gather(canvas: CanvasItem, hand: Vector2, p: float, element: String, art: float, cells: int, reach: float, flash: int, seed: int) -> void:
	if p >= 1.0 or p < 0.0:
		return
	var cols := Pal.ramp(element)
	var h := PixelPaint.at(hand, art)
	var come := clampf(p / 0.7, 0.0, 1.0)
	var k := come * come
	var out := {}
	if come < 1.0:
		for i in range(cells):
			var a := _rnd(seed, i) * TAU
			var dist := reach * (0.6 + 0.4 * _rnd(seed, i + 31))
			var late := _rnd(seed, i + 62) * 0.3
			var kk := clampf((k - late) / (1.0 - late), 0.0, 1.0)
			if kk >= 1.0:
				continue
			var pos := Vector2.from_angle(a) * dist * (1.0 - kk) * Vector2(1.0, 0.75)
			var q := h + Vector2i(pos.round())
			out[q] = cols[4] if kk > 0.75 and i % 3 == 0 else (cols[3] if kk > 0.4 else cols[2])
			if kk > 0.3 and kk < 0.9:
				var tail := h + Vector2i((pos * 1.15).round())
				if not out.has(tail):
					out[tail] = cols[1]
	_flush(canvas, out, art)
	if p > 0.6:
		# the flash at the hand, popping out and thinning away
		var f := (p - 0.6) / 0.4
		var rr := float(flash) * minf(1.0, f * 3.0) * art
		var cover := 1.0 - f
		PixelPaint.disc(canvas, hand, rr, rr * 0.8, cols[2], art, cover * 0.7)
		PixelPaint.disc(canvas, hand, rr * 0.55, rr * 0.45, cols[3], art, cover)
		if f < 0.3:
			PixelPaint.cell(canvas, h, cols[4], art)


## IMPACT: the painted part of a hit at `at` (world px; the particles carry
## the physics) over `p` 0..1, `size` art cells wide, in the `element`: a
## flash and rays for sparks and chips (fire's rays stand up as licks of
## flame), a frost disc under the shard star, a splat ring with drops flung
## for liquids, and for motes an inward pull (the void gathers its motes for
## a moment round a dark heart) before they scatter.
static func impact(canvas: CanvasItem, at: Vector2, dir: Vector2, p: float, element: String, art: float, size: int, seed: int) -> void:
	if p >= 1.0 or p < 0.0:
		return
	var cols := Pal.ramp(element)
	var kind := Pal.kind(element)
	var fade := 1.0 - smoothstep(0.4, 1.0, p)
	match kind:
		"mote":
			var c := PixelPaint.at(at, art)
			var cells := {}
			var n := 6 + size
			for i in range(n):
				var a := _rnd(seed, i) * TAU
				var far := float(size) * (0.8 + 0.5 * _rnd(seed, i + 40))
				var dist := far * (1.0 - _out(p / 0.3)) if p < 0.3 else far * 1.4 * _out((p - 0.3) / 0.7)
				var q := c + Vector2i((Vector2.from_angle(a + (p * 4.0 if p < 0.3 else 1.2)) * dist * Vector2(1.0, 0.75)).round())
				if PixelPaint.shown(q, fade):
					cells[q] = cols[4] if i % 3 == 0 else cols[3]
			if p < 0.45:
				var rr := float(size) * 0.35 * (1.0 if p < 0.3 else 1.0 - (p - 0.3) / 0.15) * art
				PixelPaint.disc(canvas, at, rr, rr * 0.8, cols[0], art)
				PixelPaint.ellipse(canvas, at, rr + art, rr * 0.8 + art, cols[3], art, 2, int(p * 30.0))
			_flush(canvas, cells, art)
		"drop":
			var rad := float(size) * art * _out(p / 0.5)
			var cover := 1.0 - smoothstep(0.3, 1.0, p)
			var cells := {}
			for e: Array in _ring_cells(at, rad, 1.5, art):
				var q: Vector2i = e[0]
				if PixelPaint.shown(q, cover):
					cells[q] = cols[3] if sin(float(e[2])) < -0.2 else cols[2]
			# drops flung past the rim, falling
			for i in range(4 + size):
				var a := _rnd(seed, i) * TAU
				var arc := 4.0 * p - 4.0 * p * p
				var q := PixelPaint.at(at + Vector2.from_angle(a) * (rad + float(size) * art * 0.8 * p) * Vector2(1.0, 0.7) - Vector2(0, arc * float(size) * art * 0.6), art)
				if PixelPaint.shown(q, cover + 0.2):
					cells[q] = cols[3] if p < 0.4 else cols[2]
			_flush(canvas, cells, art)
		"shard":
			if p < 0.6:
				PixelPaint.disc(canvas, at, float(size) * art * 0.7, float(size) * art * 0.45, cols[1], art, (1.0 - p / 0.6) * 0.7)
			burst(canvas, at, size, p, element, art, seed)
		"chip":
			if p < 0.7:
				var k := _out(p / 0.5)
				PixelPaint.disc(canvas, at, float(size) * art * 0.8 * k, float(size) * art * 0.5 * k, cols[1], art, (1.0 - p / 0.7) * 0.5)
			burst(canvas, at, size, p, element, art, seed)
		_:
			burst(canvas, at, size, p, element, art, seed)
			if element == "fire" and p < 0.5:
				# licks of flame standing up out of the flash
				var cells := {}
				var frame := int(p * 24.0)
				var c := PixelPaint.at(at, art)
				for i in range(3 + size / 2):
					var b := c + Vector2i(int(round((_rnd(seed, i) - 0.5) * float(size) * 1.2)), 0)
					_tongue(cells, b, (2.0 + _rnd(seed, i + 9) * float(size) * 0.6) * (1.0 - p / 0.5), 1, 0, cols, frame, i)
				_flush(canvas, _thin(cells, 1.0 - p / 0.5), art)


## A set trap at `at` (its floor point) of `kind` thorn, iron or net, `half`
## art cells wide (an ellipse 0.6 as deep), armed and pulsing `pulse` times a
## second: a ring of thorn wood with thorns leaning out and poison dripping
## off them over a dark pit, an iron trap with teeth and an ember glowing in
## its jaws, a rope net with knots at its crossings. With `spring` 0..1 the
## trap has just gone off: the thorns stand up, the jaws snap shut, the net
## flies up, and it thins away.
static func trap(canvas: CanvasItem, at: Vector2, kind: String, half: float, pulse: float, art: float, clock: float, seed: int, spring := 0.0) -> void:
	var c := PixelPaint.at(at, art)
	var frame := _frame(clock)
	var pul := 0.5 + 0.5 * sin(clock * TAU * pulse)
	var cells := {}
	var wood := Pal.ramp("beast")
	var steel := Pal.ramp("steel")
	var fire := Pal.ramp("fire")
	var poison := Pal.ramp("poison")
	var ry := half * 0.6
	match kind:
		"thorn":
			var n := maxi(8, int(half * 1.5))
			_oval_ring(cells, c, half, ry, wood[1], wood[2])
			for i in range(n):
				var a := TAU * float(i) / float(n) + _rnd(seed, i) * 0.3
				var base := c + Vector2i(int(round(cos(a) * half)), int(round(sin(a) * ry)))
				var tall := 2 + (1 if i % 3 == 0 else 0) + int(round(spring * 2.0))
				var lean := Vector2(cos(a), sin(a) * 0.4)
				for k in range(1, tall + 1):
					var q := base + Vector2i((lean * float(k) * 0.6).round()) + Vector2i(0, -k)
					cells[q] = wood[4] if k == tall else wood[3]
				if i % 4 == seed % 4 or spring > 0.0:
					# a drop of poison gathering at the tip and falling
					var phase := fmod(clock * (0.5 + 0.2 * _rnd(seed, i + 50)) + _rnd(seed, i + 70), 1.0)
					var tip := base + Vector2i((lean * float(tall) * 0.6).round()) + Vector2i(0, -tall)
					var q := tip + Vector2i(0, int(phase * float(tall + 1))) if phase > 0.4 else tip
					cells[q] = poison[3] if phase < 0.9 else poison[2]
			# the pit inside, dark, the poison glowing in it on the pulse
			for y in range(-int(ry) + 1, int(ry)):
				for x in range(-int(half) + 1, int(half)):
					if Vector2(float(x) / half, float(y) / ry).length() < 0.8:
						var q := c + Vector2i(x, y)
						if not cells.has(q):
							cells[q] = poison[1] if posmod(x + y + frame / 4, 5) == 0 and pul > 0.5 else poison[0]
		"iron":
			# two jaws of iron closing on an ember core
			var open := 1.0 - spring
			for sgn: int in [-1, 1]:
				for x in range(-int(half), int(half) + 1):
					var f := absf(float(x)) / half
					var depth := sqrt(maxf(0.0, 1.0 - f * f)) * ry * open
					var q := c + Vector2i(x, sgn * int(round(depth)))
					cells[q] = steel[2] if sgn > 0 else steel[3]
					cells[q + Vector2i(0, 1)] = steel[1]
					if posmod(x + seed, 3) == 0 and depth > 1.0:
						cells[q - Vector2i(0, sgn)] = steel[4]
			for x in range(-2, 3):
				cells[c + Vector2i(x, 0)] = steel[1]
			var hot := pul > 0.5 or spring > 0.0
			cells[c] = fire[4] if hot else fire[3]
			for o: Vector2i in SIDES:
				cells[c + o] = fire[3] if hot else fire[2]
			if spring > 0.0:
				for o: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					cells[c + o] = fire[2]
		_:
			# a rope net: ropes over the oval, knots at the crossings, a rope rim
			var sway := int(round(sin(clock * TAU * pulse)))
			var lift := int(round(spring * 6.0))
			var step := 3
			for y in range(-int(ry), int(ry) + 1):
				for x in range(-int(half), int(half) + 1):
					if Vector2(float(x) / half, float(y) / ry).length() > 1.0:
						continue
					var on_x := posmod(x + sway * (1 if y % 2 == 0 else 0), step) == 0
					var on_y := posmod(y, step) == 0
					if not (on_x or on_y):
						continue
					var q := c + Vector2i(x, y - lift)
					cells[q] = wood[3] if on_x and on_y else (wood[2] if y < 0 else wood[1])
			_oval_ring(cells, c + Vector2i(0, -lift), half, ry, wood[1], wood[2])
	if spring > 0.0:
		cells = _thin(cells, 1.0 - spring)
	_flush(canvas, cells, art)


# ---------- frost: the Frostmagier's language (2026-10-31) ----------

## A crystal standing on the floor at cell `b` into a cell map: `h` cells
## tall, `half` wide at its base, its tip leaning `lean` cells; the lit left
## facet, a ridge brightest towards the tip, the shaded right facet and a dark
## root; `cover` thins it by the dither.
static func _crystal(cells: Dictionary, b: Vector2i, h: float, half: float, lean: float, cols: Array, cover: float) -> void:
	if h < 1.0:
		return
	var top := roundi(h)
	for j in range(top + 1):
		var v := float(j) / h
		var w := half * (1.0 - v)
		var axis := lean * v
		for x in range(roundi(axis - w), roundi(axis + w) + 1):
			var q := b + Vector2i(x, -j)
			if cover < 1.0 and not PixelPaint.shown(q, cover):
				continue
			var col: Color = cols[2]
			if j == 0:
				col = cols[1]
			elif float(x) < axis - 0.3:
				col = cols[3]
			elif float(x) <= axis + 0.3:
				col = cols[3] if v < 0.6 else cols[4]
			elif float(x) >= axis + w - 0.5:
				col = cols[1]
			cells[q] = col


## One ice sliver into a cell map at cell `q`: `length` cells back along
## facing `facing` (0..7 of DIR8), its leading cell lit (spec when `glint`).
static func _sliver(cells: Dictionary, q: Vector2i, facing: int, length: int, cols: Array, glint: bool) -> void:
	var step: Vector2i = DIR8[posmod(facing, 8)]
	for i in range(length):
		cells[q - step * i] = ((cols[4] if glint else cols[3]) if i == 0 else (cols[2] if i < length - 1 else cols[1]))


## The Frostlanze into a cell map: a lance of ice `length` cells before and
## behind cell `c` along `d`, `r` wide a third behind its point, faceted (the
## upper facet lit, a bright ridge, the lower facet shaded), its tip glinting
## white on the beat with a glint running down the ridge; `mist` takes the
## frost-mist trail behind it (pale cells drifting apart and sinking as they
## fall behind, shown at `cover`, drawn without outline).
static func _lance(cells: Dictionary, mist: Dictionary, c: Vector2i, d: Vector2, r: int, length: int, cover: float, cols: Array, frame: int, seed: int) -> void:
	var side := d.orthogonal()
	for k in range(-length, length + 1):
		var hw: int
		if k > length / 3:
			hw = int(floor(float(r) * float(length - k) / (float(length) * 0.67) + 0.35))
		else:
			hw = int(floor(float(r) * (0.35 + 0.65 * float(k + length) / (float(length) * 1.33)) + 0.35))
		for o in range(-hw, hw + 1):
			var q := c + Vector2i((d * float(k) + side * float(o)).round())
			var lit := float(o) * side.y < 0.0
			var col: Color
			if k >= length - 1:
				col = ((FROST_WHITE if posmod(frame + seed, 4) == 0 else cols[4]) if o == 0 else cols[3])
			elif o == 0:
				col = cols[4] if k > length / 2 else cols[3]
			elif lit:
				col = cols[3] if k > -length / 2 else cols[2]
			else:
				col = cols[1] if absi(o) == hw else cols[2]
			cells[q] = col
	var g := length - 1 - posmod(frame * 2 + seed, 2 * length + 6)
	if g >= -length:
		var gq := c + Vector2i((d * float(g)).round())
		if cells.has(gq):
			cells[gq] = FROST_WHITE
	for i in range(length + 1, length * 3 + 6):
		var f := float(i - length - 1) / float(length * 2 + 5)
		var spread := 0.5 + f * 2.8
		for s in range(2):
			var off := (_rnd(seed + frame / 2, i * 2 + s) - 0.5) * 2.0 * spread
			var q := c - Vector2i((d * float(i)).round()) + Vector2i((side * off).round()) + Vector2i(0, int(f * 2.5))
			if mist.has(q) or cells.has(q) or not PixelPaint.shown(q + Vector2i(frame, 0), cover * (1.0 - f) * 0.9):
				continue
			mist[q] = cols[4] if f < 0.2 and s == 0 else (cols[3] if f < 0.6 else cols[2])


## IMPACT of ice, in pushes (the Frostmagier's language): one white flash
## frame, the lance breaking into a star of ice that thins away, cold
## pressure rings running out, a ring of shards flung out in low arcs and
## tumbling (one of eight facings, turning on the beat) that land and lie as
## rime flecks glinting now and then, and frost mist settling low round the
## spot; `p` 0..1 over its life, `size` art cells its reach, `dir` the flight
## (the shards fly on round it; zero all round). spec: vfx_talents.json
## frost.shatter (flash, pulses, shards, fly). The shards that skid, the rime
## that grows and the pools that freeze are the particles' (src/vfx/particles.gd
## shatter, rime_grow, freeze_liquids).
static func shatter(canvas: CanvasItem, at: Vector2, dir: Vector2, p: float, art: float, size: int, seed: int, spec: Dictionary = {}) -> void:
	if p >= 1.0 or p < 0.0:
		return
	var cols := Pal.ramp("ice")
	var c := PixelPaint.at(at, art)
	var frame := int(p * 60.0)
	var flash := float(spec.get("flash", 0.08))
	var reach := float(size) * art
	if p < flash:
		var fr := reach * (0.55 + 0.25 * p / flash)
		PixelPaint.disc(canvas, at, fr, fr * 0.8, cols[4], art)
		PixelPaint.disc(canvas, at, fr * 0.5, fr * 0.4, FROST_WHITE, art)
	if p < 0.45:
		var star := {}
		var go := _out(p / 0.2)
		for k in range(8):
			var a := TAU * float(k) / 8.0 + _rnd(seed, k) * 0.3
			var long := float(size) * (0.8 if k % 2 == 0 else 0.45) * go
			var ray := Vector2.from_angle(a)
			var s := 0.0
			while s <= long:
				var w := 1 if s < long * 0.5 and k % 2 == 0 else 0
				for o in range(-w, w + 1):
					var q := c + Vector2i((ray * s + ray.orthogonal() * float(o)).round())
					star[q] = cols[4] if s > long - 1.0 else (cols[3] if o <= 0 else cols[2])
				s += 1.0
		_flush(canvas, _thin(star, 1.0 - smoothstep(0.15, 0.45, p)), art)
	var pulses := int(spec.get("pulses", 2))
	for j in range(pulses):
		var tj := (p - float(j) * 0.08) / 0.4
		if tj <= 0.0 or tj >= 1.0:
			continue
		_pressure_ring(canvas, at, reach * (0.3 + 1.1 * _out(tj)) * (1.0 - 0.15 * float(j)), 1.0 - tj * tj, cols, art, seed + j)
	# the shards and the mist: the particles' when the host has them (they skid and lie as frost)
	if not paint_matter:
		return
	var shards := {}
	var biased := dir.length() > 0.1
	var n := int(spec.get("shards", 8)) + size
	var fly := float(spec.get("fly", 0.32))
	var t := clampf(p / fly, 0.0, 1.0)
	var lie := 1.0 - smoothstep(0.7, 1.0, p)
	for i in range(n):
		var a := dir.angle() + (_rnd(seed, i + 200) - 0.5) * 3.6 if biased else TAU * (float(i) + _rnd(seed, i + 200) * 0.7) / float(n)
		var far := reach * (0.9 + 0.8 * _rnd(seed, i + 400))
		var pos := at + Vector2.from_angle(a) * far * _out(t) * Vector2(1.0, 0.7) - Vector2(0.0, reach * 0.5 * (4.0 * t - 4.0 * t * t) * _rnd(seed, i + 500))
		var q := PixelPaint.at(pos, art)
		if not PixelPaint.shown(q, lie):
			continue
		if t < 1.0:
			_sliver(shards, q, posmod(int(round(a / (TAU / 8.0))) + (frame / 3) * (1 if i % 2 == 0 else -1), 8), 2 + i % 2, cols, i % 3 == 0)
		else:
			shards[q] = cols[3]
			shards[q + Vector2i(1, 0)] = cols[2]
			if posmod(frame / 4 + i, 5) == 0:
				shards[q] = FROST_WHITE
	_flush(canvas, shards, art)
	if p > 0.1:
		var mist := {}
		var k := 1.0 - smoothstep(0.5, 1.0, p)
		for i in range(10 + size * 2):
			var a := _rnd(seed, i + 600) * TAU
			var rad := reach * (0.3 + 0.9 * _rnd(seed, i + 700)) * (0.6 + 0.4 * p)
			var q := PixelPaint.at(at + Vector2.from_angle(a) * rad * Vector2(1.0, 0.45) + Vector2(sin(p * 6.0 + float(i)) * art, -p * 3.0 * art), art)
			if PixelPaint.shown(q, k * 0.7):
				mist[q] = cols[4] if i % 5 == 0 else cols[3]
		PixelPaint.paint(canvas, mist, art)


## Blizzard over its frost pools (the pools, the rime and the frost gas are
## the host's layers): frost mist crawling low over the floor, snow flakes
## driven round the middle in a swirl (each on its own orbit, faster near the
## middle, bobbing, the inner ones whipping past as short streaks) and ice
## slivers tumbling with them; `k` 0..1 its strength (it builds up and dies
## down), `r` world px its hit radius. spec: vfx_talents.json frost.blizzard.
static func blizzard(canvas: CanvasItem, at: Vector2, r: float, k: float, art: float, clock: float, seed: int, spec: Dictionary = {}) -> void:
	if k <= 0.0 or r < art * 4.0:
		return
	var cols := Pal.ramp("ice")
	var frame := _frame(clock)
	var rc := r / art
	var spin := float(spec.get("spin", 1.6))
	var mist := {}
	for i in range(int(rc * 1.6)):
		var a := _rnd(seed, i + 900) * TAU + clock * spin * 0.25
		var rad := r * sqrt(_rnd(seed, i + 950))
		var q := PixelPaint.at(at + Vector2.from_angle(a) * rad * Vector2(1.0, 0.6), art)
		if PixelPaint.shown(q + Vector2i(frame / 3, 0), 0.45 * k):
			mist[q] = cols[3] if i % 4 else cols[4]
	PixelPaint.paint(canvas, mist, art)
	# flakes and slivers: the particles' when the host has them (they fall and lie as frost)
	if not paint_matter:
		return
	var snow := {}
	for i in range(int(spec.get("flakes", 70))):
		var orbit := 0.15 + 0.85 * _rnd(seed, i)
		var w := spin * (1.45 - orbit)
		var a := _rnd(seed, i + 100) * TAU + clock * w
		var rad := r * orbit * (1.0 + 0.12 * sin(clock * 1.7 + float(i)))
		var lift := (6.0 + 10.0 * _rnd(seed, i + 200)) * art * (1.0 - orbit * 0.5) * (0.5 + 0.5 * sin(clock * 2.0 + float(i)))
		var pos := at + Vector2(cos(a), sin(a) * 0.6) * rad - Vector2(0, lift)
		var q := PixelPaint.at(pos, art)
		if not PixelPaint.shown(q, k):
			continue
		snow[q] = FROST_WHITE if i % 7 == 0 else cols[4]
		if orbit < 0.6:
			var back := PixelPaint.at(pos - Vector2(-sin(a), cos(a) * 0.6) * art * 1.5, art)
			if not snow.has(back):
				snow[back] = cols[3]
	for q: Vector2i in snow:
		if not snow.has(q + Vector2i(0, 1)):
			PixelPaint.cell(canvas, q + Vector2i(0, 1), cols[1], art)
	PixelPaint.paint(canvas, snow, art)
	var slivers := {}
	for i in range(int(spec.get("shards", 14))):
		var orbit := 0.3 + 0.65 * _rnd(seed, i + 300)
		var a := _rnd(seed, i + 400) * TAU + clock * spin * (1.2 - orbit * 0.6)
		var pos := at + Vector2(cos(a), sin(a) * 0.6) * r * orbit - Vector2(0, (4.0 + 6.0 * _rnd(seed, i + 500)) * art)
		var q := PixelPaint.at(pos, art)
		if PixelPaint.shown(q, k):
			_sliver(slivers, q, posmod(int(a * 4.0 / PI) + 2 + frame / 2, 8), 2, cols, i % 3 == 0)
	_flush(canvas, slivers, art)


## The path of the Frostsprung from `from` to `to` (ground points): a band of
## frost along it and rime crystals (2-5 cells) shooting up one after another
## from the start with a pop, glinting on the beat, then thinning by the
## dither from the start end first; `every` cells between crystals. The shard
## bursts at both ends are shatter's.
static func ice_trail(canvas: CanvasItem, from: Vector2, to: Vector2, p: float, art: float, seed: int, every := 4.0) -> void:
	var length := from.distance_to(to)
	if length < art * 2.0 or p >= 1.0:
		return
	var cols := Pal.ramp("ice")
	var d := (to - from) / length
	var side := d.orthogonal()
	var steps := int(length / art)
	var frame := int(p * 60.0)
	var band := {}
	for i in range(steps + 1):
		var f := float(i) / float(maxi(1, steps))
		var cover := clampf((p * 3.0 - f) * 2.0, 0.0, 1.0) * (1.0 - smoothstep(0.5 + f * 0.3, 1.0, p))
		if cover <= 0.0:
			continue
		for o in range(-1, 2):
			var q := PixelPaint.at(from + d * float(i) * art + side * float(o) * art, art)
			if not band.has(q) and PixelPaint.shown(q, cover * (1.0 if o == 0 else 0.6)):
				band[q] = cols[3] if o == 0 else cols[2]
	_flush(canvas, band, art)
	var crystals := {}
	var n := maxi(2, int(float(steps) / maxf(1.0, every)))
	for i in range(n + 1):
		var f := (float(i) + 0.5 * _rnd(seed, i)) / float(n + 1)
		var g := _back(clampf((p - f * 0.33) / 0.12, 0.0, 1.0))
		if g <= 0.0:
			continue
		var b := PixelPaint.at(from + d * f * length + side * (_rnd(seed, i + 40) - 0.5) * 4.0 * art, art)
		var h := (2.0 + 3.0 * _rnd(seed, i + 80)) * g
		_crystal(crystals, b, h, 1.0 + float(i % 2), (_rnd(seed, i + 120) - 0.5) * 2.0, cols, 1.0 - smoothstep(0.5 + f * 0.3, 1.0, p))
		var tip := b + Vector2i(0, -roundi(h))
		if posmod(frame / 3 + i, 4) == 0 and crystals.has(tip):
			crystals[tip] = FROST_WHITE
	_flush(canvas, crystals, art)


# ---------- the void: the Leerenmagier's language (2026-10-31) ----------

## The Leerengeschoss into cell maps: a dark core `r` cells round (an
## ink-black heart, deeper than the floor) with a violet rim whose lit cell
## crawls round on the beat; `motes` takes its trail, which bends towards
## it: motes behind and beside it are drawn in along a narrowing funnel,
## slow far out and fast near the rim, each with a short streak behind it;
## `crack` > 0 (the Leerenlanze) tears a jagged line of split space behind it.
static func _void_core(cells: Dictionary, motes: Dictionary, c: Vector2i, d: Vector2, r: int, trail: int, crack: int, cols: Array, clock: float, frame: int, seed: int) -> void:
	var side := d.orthogonal()
	for y in range(-r - 1, r + 2):
		for x in range(-r - 1, r + 2):
			var dd := Vector2(x, y).length()
			if dd > float(r) + 0.6:
				continue
			var q := c + Vector2i(x, y)
			if dd < float(r) - 0.7:
				cells[q] = VOID_BLACK if dd < float(r) - 1.5 or r < 2 else cols[0]
			else:
				var lit := posmod(int(round(atan2(float(y), float(x)) * 3.0)) + frame, 6) == 0
				cells[q] = cols[4] if lit else (cols[3] if y <= 0 else cols[2])
	for i in range(4 + trail):
		var age := fmod(clock * 2.2 + _rnd(seed, i), 1.0)
		var pull := age * age
		var far := float(trail) * (0.5 + 0.6 * _rnd(seed, i + 30)) + float(r)
		var lateral := (_rnd(seed, i + 60) - 0.5) * 2.0 * (2.0 + float(trail) * 0.45) * (1.0 - pull)
		var swing := sin(pull * PI) * 1.5 * signf(lateral + 0.01)
		var spot := Vector2(c) - d * far * (1.0 - pull) + side * (lateral + swing)
		var q := Vector2i(spot.round())
		if cells.has(q) or motes.has(q):
			continue
		motes[q] = cols[4] if pull > 0.7 else (cols[3] if pull > 0.35 else cols[2])
		if pull > 0.15 and pull < 0.9:
			var tail := Vector2i((spot - (Vector2(c) - spot).normalized()).round())
			if not cells.has(tail) and not motes.has(tail):
				motes[tail] = cols[1]
	if crack > 0:
		for k in range(r + 1, r + 2 + crack * 4):
			var zig: int = [0, 1, 0, -1, -1, 0, 1][posmod(k + seed, 7)]
			var q := c - Vector2i((d * float(k)).round()) + Vector2i((side * float(zig)).round())
			if not cells.has(q):
				cells[q] = VOID_BLACK if k % 3 else cols[0]
			var lip := q + Vector2i((side * (1.0 if zig >= 0 else -1.0)).round())
			if not cells.has(lip) and posmod(k + frame, 4) == 0:
				motes[lip] = cols[3]


## A tear in space into a cell map: a jagged line `half` cells to both sides
## of cell `c` along `d`, `open` cells wide in its middle (black inside, a
## violet lip lit on its upper edge), narrowing to its ends; `cover` thins it.
static func _tear(cells: Dictionary, c: Vector2i, d: Vector2, half: float, open: float, cols: Array, cover: float, seed: int) -> void:
	var side := d.orthogonal()
	var s := -half
	while s <= half:
		var zig := sin(s * 1.3 + float(seed % 13)) * 1.2 + (_rnd(seed, int(s + 200.0)) - 0.5) * 1.4
		var w := open * (1.0 - absf(s) / maxf(1.0, half))
		var base := Vector2(c) + d * s + side * zig
		for o in range(-int(w) - 1, int(w) + 2):
			var q := Vector2i((base + side * float(o)).round())
			if cover < 1.0 and not PixelPaint.shown(q, cover):
				continue
			if absf(float(o)) <= w - 0.5:
				cells[q] = VOID_BLACK
			elif not cells.has(q):
				cells[q] = cols[3] if float(o) * side.y < 0.0 else cols[2]
		s += 1.0


## The void's ramp one step darker (its ghost and its pressure rings).
static func _shade(cols: Array) -> Array:
	return [VOID_BLACK, cols[0], cols[1], cols[2], cols[3]]


## IMPACT of the void (the Leerenmagier's language): the pull first, then the
## burst. Over the first `pull` of its life motes are drawn in from a ring
## round the hit on tightening spirals while a dark core gathers (a violet
## rim crawling round a black heart); then one frame of void (the core at its
## biggest, its rim spec-bright), violet motes flung out as streaks, a dark
## pressure ring and the core closing. `size` art cells its reach, `crack` > 0
## tears a jagged line of split space across it (the Leerenlanze). spec:
## vfx_talents.json void.implode (pull, motes). The pull on the host's dust,
## the stain and the swallowing are the particles', the pools' and the host's.
static func implosion(canvas: CanvasItem, at: Vector2, p: float, art: float, size: int, seed: int, spec: Dictionary = {}, crack := 0) -> void:
	if p >= 1.0 or p < 0.0:
		return
	var cols := Pal.ramp("void")
	var c := PixelPaint.at(at, art)
	var frame := int(p * 60.0)
	var pull := float(spec.get("pull", 0.25))
	var reach := float(size)
	var n := int(spec.get("motes", 10)) + size
	var cells := {}
	var motes := {}
	if crack > 0 and p > pull * 0.5:
		var tear := {}
		var span := reach * (0.9 + 0.25 * float(crack)) * _out((p - pull * 0.5) / 0.2)
		_tear(tear, c, Vector2.from_angle(_rnd(seed, 777) * PI), span, 1.0 + 0.5 * float(crack), cols, 1.0 - smoothstep(0.6, 1.0, p), seed)
		_flush(canvas, tear, art)
	if p < pull:
		var k := p / pull
		var kk := k * k
		# the motes drawn in and flung out: the particles' implode when the host has them
		for i in range(n if paint_matter else 0):
			var a := _rnd(seed, i) * TAU + kk * 2.4
			var pos := Vector2(c) + Vector2.from_angle(a) * reach * (1.1 + 0.6 * _rnd(seed, i + 40)) * (1.0 - kk) * Vector2(1.0, 0.75)
			var q := Vector2i(pos.round())
			motes[q] = cols[4] if kk > 0.6 and i % 2 == 0 else cols[3]
			var tail := Vector2i((Vector2(c) + (pos - Vector2(c)) * 1.18).round())
			if tail != q and not motes.has(tail):
				motes[tail] = cols[2]
	var core := 0.0
	if p < pull:
		core = 1.0 + reach * 0.28 * p / pull
	elif p < pull + 0.3:
		core = (1.0 + reach * 0.32) * (1.0 - (p - pull) / 0.3)
	if core >= 1.0:
		var bright := p >= pull and p < pull + 0.06
		for y in range(-int(core) - 1, int(core) + 2):
			for x in range(-int(core) - 1, int(core) + 2):
				var dd := Vector2(float(x), float(y) / 0.8).length()
				if dd > core + 0.5:
					continue
				var q := c + Vector2i(x, y)
				if dd > core - 0.8:
					var crawl := posmod(int(round(atan2(float(y), float(x)) * 4.0)) - frame, 8) == 0
					cells[q] = cols[4] if bright or crawl else cols[3]
				else:
					cells[q] = VOID_BLACK if dd < core - 1.8 else cols[0]
	if p >= pull:
		var t := (p - pull) / (1.0 - pull)
		for i in range(n + 4 if paint_matter else 0):
			var a := _rnd(seed, i + 300) * TAU
			var pos := Vector2(c) + Vector2.from_angle(a) * reach * (1.0 + 0.9 * _rnd(seed, i + 340)) * _out(t / 0.7) * Vector2(1.0, 0.75) - Vector2(0, t * 3.0)
			var q := Vector2i(pos.round())
			if not PixelPaint.shown(q, 1.0 - t):
				continue
			motes[q] = cols[4] if t < 0.25 else (cols[3] if t < 0.6 else cols[2])
			if t < 0.5:
				var back := Vector2i((Vector2(c) + (pos - Vector2(c)) * 0.82).round())
				if not motes.has(back):
					motes[back] = cols[2]
		var rt := t / 0.55
		if rt < 1.0:
			_pressure_ring(canvas, at, reach * art * (0.3 + 1.2 * _out(rt)), 1.0 - rt * rt, _shade(cols), art, seed)
	_flush(canvas, cells, art)
	for q: Vector2i in motes:
		if not motes.has(q + Vector2i(0, 1)) and not cells.has(q + Vector2i(0, 1)):
			PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	PixelPaint.paint(canvas, motes, art)


## Leerenriss: a tear in the floor at `at` that opens into a ring and ends in
## a pressure ring reaching exactly `r` (world px). Up to spec.open of its life
## a jagged black line rips open across the spot (violet lip); up to spec.ring
## it bends round into a torn ring, the floor inside going dark, while motes
## stream in from past the hit radius on spirals (everything is drawn in);
## then the pressure ring runs out to `r` and thins and the dark closes.
static func rift(canvas: CanvasItem, at: Vector2, r: float, p: float, art: float, seed: int, spec: Dictionary = {}) -> void:
	if p >= 1.0 or p < 0.0 or r < art * 3.0:
		return
	var cols := Pal.ramp("void")
	var c := PixelPaint.at(at, art)
	var rc := r / art
	var frame := int(p * 60.0)
	var open_end := float(spec.get("open", 0.22))
	var ring_end := float(spec.get("ring", 0.42))
	var a0 := _rnd(seed, 1) * PI
	var d := Vector2.from_angle(a0)
	var cells := {}
	var half := rc * float(spec.get("tear", 0.5))
	if p < open_end:
		_tear(cells, c, d, half * _out(p / open_end), 1.0 + 1.5 * _out(p / open_end), cols, 1.0, seed)
	else:
		var k := _out(clampf((p - open_end) / (ring_end - open_end), 0.0, 1.0))
		var close := clampf((p - ring_end) / (1.0 - ring_end), 0.0, 1.0)
		var cover := 1.0 - smoothstep(0.3, 1.0, close)
		var rad := half * 0.8 * (1.0 - 0.6 * close)
		var count := maxi(24, int(TAU * rad))
		for i in range(count):
			var s := float(i) / float(count) * 2.0 - 1.0
			var line := Vector2(c) + d * s * half
			var ring := Vector2(c) + Vector2.from_angle(a0 + PI * (s + 1.0)) * rad * Vector2(1.0, 0.75)
			var pos := line.lerp(ring, k) + Vector2(sin(s * 9.0 + float(seed % 7)), cos(s * 7.0)) * 0.9
			var q := Vector2i(pos.round())
			if not PixelPaint.shown(q, cover):
				continue
			cells[q] = cols[4] if posmod(i + frame / 2, 9) == 0 else (cols[3] if (pos - Vector2(c)).y < 0.0 else cols[2])
			var inner := Vector2i((Vector2(c) + (pos - Vector2(c)) * 0.85).round())
			if not cells.has(inner):
				cells[inner] = VOID_BLACK
		if k > 0.2:
			var dark := {}
			for y in range(-int(rad), int(rad) + 1):
				for x in range(-int(rad), int(rad) + 1):
					var q := c + Vector2i(x, y)
					if Vector2(float(x), float(y) / 0.75).length() < rad * 0.8 * k and not cells.has(q) and PixelPaint.shown(q, 0.7 * cover):
						dark[q] = VOID_BLACK if PixelPaint.shown(q, 0.5) else cols[0]
			PixelPaint.paint(canvas, dark, art)
	var motes := {}
	var pull := clampf((p - open_end * 0.5) / (ring_end + 0.1 - open_end * 0.5), 0.0, 1.0)
	if pull > 0.0 and pull < 1.0:
		# the motes streaming in: the particles' well when the host has them
		for i in range(int(spec.get("motes", 18)) if paint_matter else 0):
			var ph := fmod(pull + _rnd(seed, i + 50), 1.0)
			var ease := ph * ph
			var a := _rnd(seed, i + 90) * TAU + ease * 2.2
			var pos := Vector2(c) + Vector2.from_angle(a) * rc * (1.25 - ease * 1.1) * Vector2(1.0, 0.75)
			var q := Vector2i(pos.round())
			motes[q] = cols[4] if ease > 0.6 else cols[3]
			var tail := Vector2i((Vector2(c) + (pos - Vector2(c)) * 1.1).round())
			if tail != q and not motes.has(tail):
				motes[tail] = cols[1]
	_flush(canvas, cells, art)
	for q: Vector2i in motes:
		PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	PixelPaint.paint(canvas, motes, art)
	if p > ring_end:
		var t := (p - ring_end) / (1.0 - ring_end)
		_pressure_ring(canvas, at, r * (0.35 + 0.65 * _out(t / 0.5)), 1.0 - t, _shade(cols) if t > 0.3 else cols, art, seed)


## Raumsprung: space folding at `at` (chest height), `size` art cells at its
## widest. `closing`: a dark ring collapsing to a point (violet rim with a
## crawling glint, black inside, motes drawn into it, a spec cell where it
## shuts); else a ring opening out of a point and thinning, motes flung out.
## `k` 0..1 over the fold.
static func fold(canvas: CanvasItem, at: Vector2, k: float, closing: bool, size: int, art: float, seed: int) -> void:
	if k >= 1.0 or k < 0.0:
		return
	var cols := Pal.ramp("void")
	var c := PixelPaint.at(at, art)
	var rad := float(size) * ((1.0 - _out(k)) if closing else _out(k))
	var cover := 1.0 - (smoothstep(0.7, 1.0, k) * 0.5 if closing else smoothstep(0.4, 1.0, k))
	var frame := int(k * 40.0)
	var cells := {}
	if rad >= 1.0:
		for e: Array in _ring_cells(at, rad * art, 1.6, art):
			var q: Vector2i = e[0]
			if PixelPaint.shown(q, cover):
				cells[q] = cols[4] if posmod(int(float(e[2]) * 5.0) + frame, 6) == 0 else (cols[3] if int(e[1]) == 0 else cols[2])
		for y in range(-int(rad), int(rad) + 1):
			for x in range(-int(rad), int(rad) + 1):
				var q := c + Vector2i(x, y)
				if Vector2(x, y).length() < rad - 1.6 and not cells.has(q) and PixelPaint.shown(q, cover * (0.95 if closing else 0.6)):
					cells[q] = VOID_BLACK
	elif closing and k > 0.8:
		cells[c] = cols[4]
		for o: Vector2i in SIDES:
			cells[c + o] = cols[3]
	# its motes: the particles' (implode where he leaves, flung out where he lands) when the host has them
	for i in range(8 if paint_matter else 0):
		var a := _rnd(seed, i) * TAU + k * (2.0 if closing else -1.0)
		var dist := float(size) * ((1.7 * (1.0 - k) + 0.2) if closing else (0.4 + 1.5 * k))
		var q := c + Vector2i((Vector2.from_angle(a) * dist * Vector2(1.0, 0.8)).round())
		if not cells.has(q) and PixelPaint.shown(q, cover):
			cells[q] = cols[4] if i % 3 == 0 else cols[3]
	_flush(canvas, cells, art)


## The dotted void trail of a Raumsprung from `from` to `to`: a dot every
## `every` cells (black with a violet cell beside it, alternating sides),
## appearing from the start and thinning by the dither from the start end.
static func void_dots(canvas: CanvasItem, from: Vector2, to: Vector2, p: float, art: float, seed: int, every := 3) -> void:
	var length := from.distance_to(to)
	if length < art * 2.0 or p >= 1.0:
		return
	var cols := Pal.ramp("void")
	var d := (to - from) / length
	var side := d.orthogonal()
	var steps := int(length / art)
	var cells := {}
	var i := 0
	while i <= steps:
		var f := float(i) / float(maxi(1, steps))
		var cover := clampf((p * 3.0 - f) * 3.0, 0.0, 1.0) * (1.0 - smoothstep(0.35 + f * 0.4, 1.0, p))
		var q := PixelPaint.at(from + d * float(i) * art, art)
		if PixelPaint.shown(q, cover):
			cells[q] = VOID_BLACK
			cells[q + Vector2i((side * (1.0 if (i / maxi(1, every)) % 2 == 0 else -1.0)).round())] = cols[3] if posmod(i + seed, 4) else cols[4]
		i += maxi(1, every)
	_flush(canvas, cells, art)


## Magisches Echo: a darker violet ghost of the hero's last spell (`at`
## chest height, `angle` its aim) in the void's ramp one step down: `kind`
## "shot" a ghost of the shot flying out along the aim and dissolving with a
## lagging double behind it, "ring" a ghost ring running out to `r` world px,
## else a ghost of the gather at the hand; `p` 0..1 over the echo.
static func echo(canvas: CanvasItem, at: Vector2, angle: float, kind: String, r: float, p: float, art: float, seed: int) -> void:
	if p >= 1.0 or p < 0.0:
		return
	var ghost := _shade(Pal.ramp("void"))
	var d := Vector2.from_angle(angle)
	var cover := 1.0 - smoothstep(0.45, 1.0, p)
	match kind:
		"shot":
			for lag in range(2):
				var cells := {}
				var head := PixelPaint.at(at + d * (_out(p) * 70.0 - float(lag) * 5.0) * art * 0.5, art)
				_ball(cells, head, 2, ghost)
				for i in range(1, 7):
					var q := head - Vector2i((d * float(i + 2)).round())
					if PixelPaint.shown(q, (1.0 - float(i) / 7.0) * cover):
						cells[q] = ghost[2] if i < 3 else ghost[1]
				_flush(canvas, _thin(cells, cover * (1.0 if lag == 0 else 0.4)), art)
		"ring":
			var rad := maxf(art * 3.0, r * _out(p / 0.6))
			var cells := {}
			for e: Array in _ring_cells(at, rad, 2.0, art):
				var q: Vector2i = e[0]
				if PixelPaint.shown(q, cover):
					cells[q] = ghost[3] if int(e[1]) == 0 else ghost[1]
			for e: Array in _ring_cells(at, rad * 0.85, 1.0, art):
				var q: Vector2i = e[0]
				if not cells.has(q) and PixelPaint.shown(q, cover * 0.4):
					cells[q] = ghost[2]
			_flush(canvas, cells, art)
		_:
			gather(canvas, at + d * 5.0 * art, p, "void", art, 9, 9.0, 4, seed)


## Singularität at `at` reaching `r` (world px): a black core with a thin
## spec-bright horizon and a dark lensing ring round it, a violet accretion
## ring of motes spiralling in (tightening orbits on a tilted disc, brighter
## and streaking as they near the core, then gone), spiral arms of darkened
## floor crawling inward (the floor bends in) and, from stage 1 (Ereignis-
## horizont), a wider ring of slow motes; `k` 0..1 its strength (grows in,
## sinks at its end: the collapse is the closing wave). The pull on the dust
## and the swallowing are the particles' well and the host's.
static func singularity(canvas: CanvasItem, at: Vector2, r: float, k: float, art: float, clock: float, seed: int, stage: int, spec: Dictionary = {}) -> void:
	if k <= 0.0 or r < art * 4.0:
		return
	var cols := Pal.ramp("void")
	var c := PixelPaint.at(at, art)
	var rc := r / art
	var frame := _frame(clock)
	var spin := float(spec.get("spin", 1.4))
	var arms := {}
	var n_arms := int(spec.get("arms", 3))
	for arm in range(n_arms):
		var steps := int(rc * 1.2)
		for s in range(steps):
			var f := float(s) / float(maxi(1, steps))
			var rad := rc * 0.95 * (1.0 - f)
			var a := TAU * float(arm) / float(n_arms) + f * 3.6 + clock * spin * 0.5
			var q := c + Vector2i((Vector2(cos(a), sin(a) * 0.6) * rad).round())
			if posmod(s - frame, 5) < 2 and PixelPaint.shown(q, (0.25 + 0.5 * f) * k):
				arms[q] = cols[0] if f < 0.6 else VOID_BLACK
	PixelPaint.paint(canvas, arms, art)
	var core := maxf(2.0, rc * float(spec.get("core", 0.12))) * clampf(k * 1.3, 0.0, 1.0)
	var cells := {}
	for y in range(-int(core) - 3, int(core) + 4):
		for x in range(-int(core) - 3, int(core) + 4):
			var dd := Vector2(float(x), float(y) / 0.8).length()
			var q := c + Vector2i(x, y)
			if dd <= core - 0.5:
				cells[q] = VOID_BLACK
			elif dd <= core + 0.5:
				var lit := posmod(int(round(atan2(float(y), float(x)) * 5.0)) + frame, 10) < 2
				cells[q] = cols[4] if lit else cols[3]
			elif dd <= core + 2.0 and PixelPaint.shown(q, 0.6 * k):
				cells[q] = cols[0]
	var motes := {}
	# the motes falling in: the particles' well (void.singularity.mote_rate) when the host has them
	for i in range(int(spec.get("motes", 40)) if paint_matter else 0):
		var ph := fmod(clock * float(spec.get("fall", 0.45)) + _rnd(seed, i), 1.0)
		var ease := ph * ph
		var rad := core + (rc * 0.6 * (0.6 + 0.4 * _rnd(seed, i + 70)) - core) * (1.0 - ease)
		var a := _rnd(seed, i + 30) * TAU + ease * 5.0 + clock * spin
		var pos := Vector2(c) + Vector2(cos(a), sin(a) * 0.45) * rad
		var q := Vector2i(pos.round())
		if cells.has(q) or not PixelPaint.shown(q, k):
			continue
		motes[q] = cols[4] if ease > 0.7 else (cols[3] if ease > 0.3 else cols[2])
		if ease > 0.35:
			var back := Vector2i((Vector2(c) + Vector2(cos(a - 0.35), sin(a - 0.35) * 0.45) * rad).round())
			if not motes.has(back) and not cells.has(back):
				motes[back] = cols[2]
	if stage >= 1:
		for i in range(18):
			var a := TAU * float(i) / 18.0 - clock * spin * 0.35
			var q := c + Vector2i((Vector2(cos(a), sin(a) * 0.55) * rc * (0.9 + 0.05 * sin(clock * 3.0 + float(i)))).round())
			if PixelPaint.shown(q, k * 0.8):
				motes[q] = cols[3] if i % 3 else cols[4]
	for q: Vector2i in motes:
		if not motes.has(q + Vector2i(0, 1)):
			PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	_flush(canvas, cells, art)
	PixelPaint.paint(canvas, motes, art)


# ---------- the Arkanes Gefüge (the Leerenmagier) ----------

## A point on the quadratic curve from `a` over `ctrl` to `b` at `t` 0..1.
static func _bez(a: Vector2, ctrl: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + ctrl * 2.0 * u * t + b * t * t


## SWALLOW (the Arkanes Gefüge eats): the matter streams from `from` (the
## eaten spot, `spread` world px round it) into the mouth `to` as motes in the
## eaten elements' colours, one per entry of `els` (element names), each on
## its own curve bent to one side. They leave over spec.leave of the event,
## each takes spec.travel of it and is pulled (slow out, fast in), its lite
## cell leading (spec when nearly in), a body and a shade cell trailing over
## an ink underlay. At the mouth a small dark gulp opens while they come (a
## black heart with a violet rim whose glint steps on as they arrive) and
## closes after. `p` 0..1 over the event; spec: vfx_talents.json void.swallow.
static func stream(canvas: CanvasItem, from: Vector2, to: Vector2, spread: float, els: Array, p: float, art: float, seed: int, spec: Dictionary = {}) -> void:
	if p >= 1.0 or p < 0.0 or els.is_empty():
		return
	var a := from / art
	var b := to / art
	var length := a.distance_to(b)
	var side := (b - a).orthogonal() / maxf(0.01, length)
	var bend := float(spec.get("bend", 0.35))
	var leave := float(spec.get("leave", 0.55))
	var travel := maxf(0.05, float(spec.get("travel", 0.4)))
	var motes := {}
	var arrived := 0
	for i in range(els.size()):
		var t := (p - leave * _rnd(seed, i)) / travel
		if t < 0.0:
			continue
		if t >= 1.0:
			arrived += 1
			continue
		# the motes themselves: the particles' when the host has them (pulled into the mouth)
		if not paint_matter:
			continue
		var e := t * t
		var start := a + Vector2.from_angle(_rnd(seed, i + 50) * TAU) * (spread / art) * sqrt(_rnd(seed, i + 90)) * Vector2(1.0, 0.75)
		var ctrl := (start + b) * 0.5 + side * length * bend * (_rnd(seed, i + 130) * 2.0 - 1.0)
		var cols := Pal.ramp(str(els[i]))
		for s in range(3):
			var q := Vector2i(_bez(start, ctrl, b, maxf(0.0, e - float(s) * 0.07)).floor())
			if not motes.has(q):
				motes[q] = [cols[4] if e > 0.8 else cols[3], cols[2], cols[1]][s]
	var gulp := sin(clampf(p / maxf(0.1, leave + travel), 0.0, 1.0) * PI)
	var cells := {}
	if gulp > 0.15:
		var v := Pal.ramp("void")
		var mouth := Vector2i(b.floor())
		var rad := 1.0 + float(spec.get("mouth", 2)) * gulp
		for y in range(-int(rad) - 1, int(rad) + 2):
			for x in range(-int(rad) - 1, int(rad) + 2):
				var dd := Vector2(float(x), float(y) / 0.8).length()
				if dd > rad + 0.5:
					continue
				cells[mouth + Vector2i(x, y)] = VOID_BLACK if dd < rad - 0.6 else (v[4] if posmod(x + y + arrived, 5) == 0 else v[3])
	for q: Vector2i in motes:
		if not motes.has(q + Vector2i(0, 1)):
			PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	_flush(canvas, cells, art)
	PixelPaint.paint(canvas, motes, art)


## EJECT (the Gefüge bursting at the Urknall): the swallowed units burst out
## of `at` as comet pixels in their elements' colours on a spiral, one per
## entry of `els`. Each turns spec.turn rad as it flies out (ease-out) over
## spec.fly of the event to its landing within `r` world px, arcing up
## spec.arc cells: a spec head for its first quarter, then its lite colour,
## three tail cells darkening behind it along the spiral over an ink
## underlay; where it lands a splash of its colour thins away over
## spec.splash (the pool is the host's). The first spec.flash of the event
## shows one frame of void at the core (black heart, spec rim). `p` 0..1.
static func comets(canvas: CanvasItem, at: Vector2, r: float, els: Array, p: float, art: float, seed: int, spec: Dictionary = {}) -> void:
	if p >= 1.0 or p < 0.0 or els.is_empty():
		return
	var c := Vector2(PixelPaint.at(at, art))
	var reach := r / art
	var fly := maxf(0.1, float(spec.get("fly", 0.6)))
	var turn := float(spec.get("turn", 2.6)) * (1.0 if posmod(seed, 2) == 0 else -1.0)
	var arc := float(spec.get("arc", 6))
	var n := els.size()
	var cells := {}
	var splash := {}
	# the comets and their splashes: the particles' (particles.comet, landing on the
	# real spots) when the host has them; the core's flash stays a shape
	for i in range(n if paint_matter else 0):
		var cols := Pal.ramp(str(els[i]))
		var a0 := TAU * float(i) / float(n) + _rnd(seed, i) * 0.7
		var land := reach * (0.35 + 0.65 * _rnd(seed, i + 20))
		var t := (p - 0.1 * _rnd(seed, i + 40)) / fly
		if t < 0.0:
			continue
		if t < 1.0:
			var e := _out(t)
			for s in range(4):
				var es := maxf(0.0, e - float(s) * 0.07)
				var pos := c + Vector2.from_angle(a0 + turn * es) * land * es * Vector2(1.0, 0.75) - Vector2(0.0, sin(es * PI) * arc)
				var q := Vector2i(pos.round())
				if not cells.has(q):
					cells[q] = [cols[4] if t < 0.25 else cols[3], cols[3], cols[2], cols[1]][s]
		else:
			var k := (t - 1.0) * fly / maxf(0.05, float(spec.get("splash", 0.3)))
			if k >= 1.0:
				continue
			var spot := c + Vector2.from_angle(a0 + turn) * land * Vector2(1.0, 0.75)
			for j in range(5):
				var q := Vector2i((spot + Vector2.from_angle(_rnd(seed, i * 7 + j) * TAU) * (0.5 + 1.8 * k) * float(mini(j, 2))).round())
				if PixelPaint.shown(q, 1.0 - k):
					splash[q] = cols[3] if j == 0 else cols[2]
	if p < float(spec.get("flash", 0.1)):
		var v := Pal.ramp("void")
		var cq := Vector2i(c)
		for y in range(-3, 4):
			for x in range(-3, 4):
				var dd := Vector2(float(x), float(y)).length()
				if dd <= 3.2:
					cells[cq + Vector2i(x, y)] = VOID_BLACK if dd < 2.2 else v[4]
	PixelPaint.paint(canvas, splash, art)
	for q: Vector2i in cells:
		if not cells.has(q + Vector2i(0, 1)):
			PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	PixelPaint.paint(canvas, cells, art)


## A caught enemy of the Singularität (it cannot be moved, so it is drawn
## held): a dark violet tether from `from` (the enemy's chest) to the core
## `to`, swaying across its middle (still at both ends), black every few
## cells on the beat with a lit cell crawling along it, inked round; the
## enemy's essence (`essence`, a 5-step ramp) flowing along it into the core
## as motes pulled faster near the core; and the "being drained" shimmer:
## cells of its essence and the void flickering on a ring round the enemy at
## the pixel beat (spec.ring cells), drawn in towards it. `k` 0..1 the zone's
## strength. spec: vfx_talents.json void.tether.
static func tether(canvas: CanvasItem, from: Vector2, to: Vector2, k: float, essence: Array, art: float, clock: float, seed: int, spec: Dictionary = {}) -> void:
	if k <= 0.0 or essence.size() < 5:
		return
	var cols := Pal.ramp("void")
	var a := from / art
	var b := to / art
	var length := a.distance_to(b)
	if length < 2.0:
		return
	var side := (b - a).orthogonal() / length
	var sway := float(spec.get("sway", 2.0)) * sin(clock * 2.3 + float(posmod(seed, 17)))
	var frame := _frame(clock)
	var line := {}
	var steps := int(length)
	for s in range(steps + 1):
		var f := float(s) / float(maxi(1, steps))
		var q := Vector2i((a.lerp(b, f) + side * sway * sin(f * PI)).floor())
		if not PixelPaint.shown(q, k):
			continue
		line[q] = VOID_BLACK if posmod(s + frame, 4) == 0 else cols[1]
		if posmod(s - frame * 2, 7) == 0 and not line.has(q + Vector2i(0, -1)):
			line[q + Vector2i(0, -1)] = cols[2]
	var motes := {}
	# the essence flowing in: the particles' (pulled by the core's well) when the host has them
	for i in range(int(spec.get("motes", 5)) if paint_matter else 0):
		var e := pow(fmod(clock * float(spec.get("flow", 0.9)) + _rnd(seed, i), 1.0), 2.0)
		var q := Vector2i((a.lerp(b, e) + side * sway * sin(e * PI)).floor())
		motes[q] = essence[4] if e > 0.75 else essence[3]
		var eb := maxf(0.0, e - 0.05)
		var back := Vector2i((a.lerp(b, eb) + side * sway * sin(eb * PI)).floor())
		if back != q and not motes.has(back):
			motes[back] = essence[2]
	var ring: Array = spec.get("ring", [6, 9])
	var count := int(spec.get("shimmer", 10))
	for i in range(count):
		if posmod(frame + i, 3) == 0:
			continue
		var ph := fmod(clock * 1.3 + _rnd(seed, i + 60), 1.0)
		var ang := TAU * float(i) / float(maxi(1, count)) + clock * 1.6
		var q := Vector2i((a + Vector2(cos(ang) * float(ring[0]), sin(ang) * float(ring[1])) * (1.0 - 0.35 * ph)).floor())
		if not motes.has(q):
			motes[q] = essence[3] if i % 2 == 0 else cols[3]
	_flush(canvas, line, art)
	for q: Vector2i in motes:
		if not motes.has(q + Vector2i(0, 1)) and not line.has(q + Vector2i(0, 1)):
			PixelPaint.cell(canvas, q + Vector2i(0, 1), Pal.INK, art)
	PixelPaint.paint(canvas, motes, art)
