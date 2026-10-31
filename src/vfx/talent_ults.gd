extends RefCounted
## The nine ultimates as pixel art (assets/data/talents.json; drawn by
## src/vfx/talent_fx.gd): each one's cast moment (the Meteor's call to the sky,
## Absoluter Nullpunkt's ice spikes, Zeitbruch's clock face, the Letzter
## Pfeil's aim line, the Todeszone flask, Alpharuf's spirit howl, Blutrausch's
## blood burst, Unbezwingbar's hex plates, Klingentanz's blades), the lasting
## auras on the hero, the delayed and closing waves, the zone overlays, the
## Letzter Pfeil in flight and the pack's spirit wisps. Every bought stage keeps
## the base form and adds a layer.
##
## Everything is whole art cells drawn through PixelPaint.cell, so the host's
## wall clip applies: opaque ramps (src/vfx/talent_palette.gd) with a dark
## outline or underlay, lit from the upper left, thinning by the ordered dither,
## no white-hot cores. Floor parts leave the hero's figure free. The nova ring,
## the bloom, the shake and the hitstop are the host's. Presentation only.

const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")

## The four neighbours of a cell (outlines).
const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Speed of an arrow (world px/s, src/combat/talent_combat.gd), so the Letzter
## Pfeil's aim line is eaten by the shot as it flies.
const ARROW_SPEED := 560.0
## From the hero's chest down to his feet in art cells (the figure is ~28 tall).
const CHEST_TO_FEET := 14.0
## Absoluter Nullpunkt's spikes: rings of [distance (share of r), count, height (cells)].
const ZERO_RINGS := [[0.3, 6, 24.0], [0.6, 8, 18.0], [0.88, 11, 13.0]]
## Feuersturm's flames: rings of [distance (share of r), count].
const STORM_RINGS := [[0.28, 5], [0.56, 7], [0.84, 9]]
## Spin of Klingentanz's blades round the hero (rad/s).
const BLADE_SPIN := 5.5
## The shield dome of src/vfx/talent_dome.gd (Unbezwingbar) standing on the feet, in art
## cells: its base ellipse DOME_W × DOME_D, its top DOME_H above the feet.
const DOME_W := 18.0
const DOME_D := 8.0
const DOME_H := 40.0
## Running length along the dome's outline (_dome_point), built on first use.
static var _dome_lengths := PackedFloat32Array()
## A hex plate, 8 cells (x filled; centred on its cell 4,4).
const HEX := ["...xx...", ".xxxxxx.", "xxxxxxxx", "xxxxxxxx", "xxxxxxxx", "xxxxxxxx", ".xxxxxx.", "...xx..."]
## Seuchenherz's heart (x filled).
const HEART := ["..xxx...xxx..", ".xxxxx.xxxxx.", "xxxxxxxxxxxxx", "xxxxxxxxxxxxx", "xxxxxxxxxxxxx", ".xxxxxxxxxxx.",
	"..xxxxxxxxx..", "...xxxxxxx...", "....xxxxx....", ".....xxx.....", "......x......"]
## Arcane runes (x filled).
const RUNES := [["x.x", ".x.", "x.x"], ["xxx", "x..", "xxx"], [".x.", "xxx", ".x."], ["x..", "xxx", "..x"],
	["xx.", "x.x", ".xx"], ["x.x", "xxx", "x.x"], ["xxx", ".x.", ".x."], [".xx", "x..", "xx."]]


# ---------- the cast moments ----------

## The cast moment (1.0 s) of ultimate `talent` at the hero standing at `at`
## (chest at at+body); `r` its hit radius in world px (0 when none), `angle` the
## aim in radians, `p` 0..1 through the event, `stage` 0..2 bought stages, `art`
## world px per art pixel, `clock` seconds, `seed` the event id, `feet` the
## offset from `at` to the hero's feet (world px: crypt (0, 16), story worlds
## zero; the shield dome of src/vfx/talent_dome.gd stands on them). The nova
## shock ring is the host's; this adds the ultimate's own form.
static func cast(canvas: CanvasItem, talent: String, at: Vector2, body: Vector2, r: float, p: float, stage: int, angle: float, art: float, clock: float, seed: int, feet: Vector2 = Vector2.ZERO) -> void:
	p = clampf(p, 0.0, 1.0)
	match talent:
		"fire_14": _meteor_call(canvas, at, body, at + feet, r, p, stage, art, clock, seed)
		"frost_14": _zero(canvas, at, body, r, p, stage, art, clock, seed)
		"arcane_14": _clock_face(canvas, at, body, p, stage, art, clock)
		"sniper_14": _aim(canvas, at, body, p, stage, angle, art, clock)
		"trapper_14": _flask(canvas, at, body, p, angle, art, seed)
		"beast_14": _howl(canvas, at, body, p, stage, art, clock, seed)
		"berserk_14": _blood_burst(canvas, at, body, at + feet, p, stage, art, seed)
		"guard_14": _plates_in(canvas, at + feet, p, stage, art, clock)
		"blade_14":
			# the blades fly out to their orbit and hand over to the aura (same spin, same radius)
			if p < 0.25:
				_burst_sparks(canvas, at + body * 0.5, 4.0 + 10.0 * _out(p / 0.25), 1.0 - p / 0.25, Pal.ramp("steel"), art, seed)
			_blade_ring(canvas, at, body, r, _out(p / 0.35), 3 + stage, art, clock, 1.0 - _span(p, 0.4, 0.65), false, false)


## Meteor's call (user feedback 2026-10-31, the fire in one language): the
## hero's hand gathers embers that stream up into the sky as a column of
## rising ember cells (dense at the hand, thinning upwards, flickering on the
## beat), a flash at the hand when the call goes out, embers raining back down
## round him as it fades; Glutkrater adds the ember core glowing on the floor,
## Meteorschauer three thin side streams (the shower's call).
static func _meteor_call(canvas: CanvasItem, at: Vector2, body: Vector2, foot: Vector2, r: float, p: float, stage: int, art: float, clock: float, seed: int) -> void:
	var fire: Array = Pal.ramp("fire")
	var hole := _hole(at, body, art)
	if stage >= 1:
		_ember_core(canvas, at, r, p, art, clock, seed, hole)
	var hand := at + body + Vector2(0.0, -6.0 * art)
	if stage >= 2:
		for k in range(3):
			var a := -PI * 0.5 + TAU * float(k) / 3.0 + PI / 3.0
			_sky_stream(canvas, foot + Vector2.from_angle(a) * r * 0.45, _span(p, 0.12 + 0.06 * float(k), 1.0), 1.5, 40.0, fire, art, clock, seed + 17 * (k + 1))
	_sky_stream(canvas, hand, p, 3.0, 70.0, fire, art, clock, seed)
	# the flash at the hand as the call goes out
	var f := _span(p, 0.1, 0.3)
	if f > 0.0 and f < 1.0:
		var rr := 4.0 * art * minf(1.0, f * 3.0)
		PixelPaint.disc(canvas, hand, rr, rr * 0.8, fire[3], art, (1.0 - f) * 0.8)
		if f < 0.3:
			PixelPaint.cell(canvas, PixelPaint.at(hand, art), fire[4], art)


## A stream of embers rising from `base` into the sky: `half` cells wide at
## its root, `top` cells high, its cells climbing on the beat and thinning
## upwards; it rises over the first third of `p`, holds and burns down.
static func _sky_stream(canvas: CanvasItem, base: Vector2, p: float, half: float, top: float, fire: Array, art: float, clock: float, seed: int) -> void:
	if p <= 0.0 or p >= 1.0:
		return
	var b := PixelPaint.at(base, art)
	var frame := int(clock * PixelPaint.FPS)
	var rise := _out(_span(p, 0.0, 0.3))
	var fade := _span(p, 0.6, 1.0)
	var h := top * rise
	var cells := {}
	for j in range(int(h)):
		var v := float(j) / maxf(1.0, top)
		var w := half * (1.0 - v * 0.7)
		var sway := sin(v * 4.0 + float(frame) * 0.9 + float(seed)) * 1.5 * v
		for x in range(roundi(sway - w), roundi(sway + w) + 1):
			var q := b + Vector2i(x, -j)
			# climbing: the dither phase runs up with the beat; sparser towards the top and the end
			if not PixelPaint.shown(q + Vector2i(0, frame), (1.0 - v * 0.75) * (1.0 - fade)):
				continue
			var u := absf(float(x) - sway) / maxf(0.5, w)
			cells[q] = fire[4] if u < 0.3 and v < 0.3 and posmod(j + frame, 5) == 0 else (fire[3] if u < 0.5 else (fire[2] if v < 0.6 else fire[1]))
	_flush_under(canvas, cells, art)
	# embers raining back down round the stream as it fades
	if fade > 0.0:
		var rain := {}
		for i in range(10):
			var ph := fposmod(fade * 1.6 + _h(seed, i), 1.0)
			var q := b + Vector2i(roundi((_h(seed, 40 + i) - 0.5) * half * 6.0), -roundi((1.0 - ph * ph) * top * 0.8))
			if PixelPaint.shown(q, 1.0 - ph):
				rain[q] = fire[3] if ph < 0.4 else fire[2]
		_flush_under(canvas, rain, art)


## Glutkern: the floor under the column glows (dithered rings of the fire ramp, flickering glints).
static func _ember_core(canvas: CanvasItem, at: Vector2, r: float, p: float, art: float, clock: float, seed: int, hole: Rect2i) -> void:
	var k := _out(_span(p, 0.04, 0.2)) * (1.0 - _span(p, 0.7, 1.0))
	if k <= 0.0:
		return
	var fire: Array = Pal.ramp("fire")
	var rad := minf(r * 0.35, 34.0 * art)
	var cells := {}
	_disc(cells, at, rad, fire[1], art, 0.3 * k, hole)
	_disc(cells, at, rad * 0.75, fire[2], art, 0.4 * k, hole)
	_disc(cells, at, rad * 0.45, fire[3], art, 0.45 * k, hole)
	var frame := int(clock * PixelPaint.FPS)
	for i in range(18):
		if _h(seed + frame / 2, i) < 0.45:
			var q := PixelPaint.at(at + Vector2.from_angle(TAU * _h(seed, 60 + i)) * rad * 0.85 * sqrt(_h(seed, 80 + i)), art)
			if not hole.has_point(q):
				cells[q] = fire[4] if i % 4 == 0 else fire[3]
	_paint(canvas, cells, art)


## Absoluter Nullpunkt: crystal spikes burst out of the floor ring by ring as
## the front passes, frost mist hangs low; Ewiges Eis adds a rime ring on the
## rim, Splitterbruch cracks spreading over the spikes.
static func _zero(canvas: CanvasItem, at: Vector2, body: Vector2, r: float, p: float, stage: int, art: float, clock: float, seed: int) -> void:
	var ice: Array = Pal.ramp("ice")
	var hole := _hole(at, body, art)
	var cover := 1.0 - _span(p, 0.8, 1.0)
	var mist := {}
	var k := 0.65 * _span(p, 0.05, 0.25) * (1.0 - _span(p, 0.5, 1.0))
	for i in range(44):
		var drift := Vector2(sin(clock * 1.3 + float(i)) * 2.0, -p * 6.0) * art
		var q := PixelPaint.at(at + Vector2.from_angle(TAU * _h(seed, 200 + i)) * r * sqrt(_h(seed, 300 + i)) + drift, art)
		if not hole.has_point(q) and PixelPaint.shown(q, k):
			mist[q] = ice[4] if i % 6 == 0 else ice[3]
	_paint(canvas, mist, art)
	if stage >= 1 and p > 0.3:
		# Ewiges Eis: small crystals all round the rim
		var rime := {}
		var count := maxi(12, int(TAU * r / art / 5.0))
		var g := _back(_span(p, 0.3, 0.42))
		for i in range(count):
			var b := PixelPaint.at(at + Vector2.from_angle(TAU * float(i) / float(count)) * r, art)
			_shard(rime, b, (2.0 + float(i % 2) + _h(seed, 500 + i)) * g, 1.0, 0.0, ice, cover, 0.0, i)
		_flush(canvas, rime, art, cover > 0.5)
	var spikes: Array = []
	for ring in range(ZERO_RINGS.size()):
		var spec: Array = ZERO_RINGS[ring]
		var frac := float(spec[0])
		var n := int(spec[1])
		for i in range(n):
			var id := ring * 31 + i
			var a := TAU * (float(i) + 0.37 * float(ring)) / float(n) + (_h(seed, id) - 0.5) * 0.4
			var dir := Vector2.from_angle(a)
			spikes.append({"pos": at + dir * r * frac * (0.92 + 0.16 * _h(seed, id + 7)), "h": float(spec[2]) * (0.8 + 0.4 * _h(seed, id + 13)),
				"half": 2.5 + roundf(2.0 * _h(seed, id + 3) * (1.0 - frac * 0.5)), "lean": clampf(dir.x * 3.0, -3.0, 3.0), "appear": 0.04 + 0.26 * frac, "id": id})
	spikes.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.pos.y) < float(y.pos.y))
	for s: Dictionary in spikes:
		var g := _back(_span(p, float(s.appear), float(s.appear) + 0.1))
		if g <= 0.0:
			continue
		var cells := {}
		var crack := _span(p, float(s.appear) + 0.3, 0.75) if stage >= 2 else 0.0
		var base := PixelPaint.at(s.pos, art)
		# a smaller crystal leaning off each spike: clusters, not single cones
		var side := 1 if _h(seed, int(s.id) + 91) < 0.5 else -1
		var half := float(s.half) * minf(1.0, g * 1.4)
		_shard(cells, base + Vector2i(side * roundi(half + 1.0), 1), float(s.h) * 0.45 * g, maxf(1.0, half * 0.6), float(s.lean) + float(side) * 2.0, ice, cover, 0.0, int(s.id))
		_shard(cells, base, float(s.h) * g, half, float(s.lean), ice, cover, crack, int(s.id) + seed)
		# a glint running up the ridge
		var j := int(fposmod(clock * 1.6 + float(s.id) * 0.3, 1.0) * float(s.h) * g)
		var q := PixelPaint.at(s.pos, art) + Vector2i(roundi(float(s.lean) * float(j) / maxf(1.0, float(s.h))), -j)
		if cells.has(q):
			cells[q] = ice[4]
		_flush(canvas, cells, art, cover > 0.5)


## A crystal standing on the floor at cell `b`: `h` cells tall, `half` wide at
## its base, its tip leaning `lean` cells; the lit left facet, a ridge, the
## shaded right facet; `crack` 0..1 a hairline crack spreading up it.
static func _shard(cells: Dictionary, b: Vector2i, h: float, half: float, lean: float, ice: Array, cover: float, crack: float, seed: int) -> void:
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
			var col: Color = ice[2]
			if j == 0:
				col = ice[1]
			elif float(x) < axis - 0.3:
				col = ice[3]
			elif float(x) <= axis + 0.3:
				col = ice[3] if v < 0.7 else ice[4]
			elif float(x) >= axis + w - 0.5:
				col = ice[1]
			cells[q] = col
	if crack > 0.0:
		for j in range(int(crack * float(top))):
			var zig: int = [-1, 0, 1, 0][posmod(j + seed, 4)]
			var q := b + Vector2i(roundi(lean * float(j) / h) + zig, -j)
			if cells.has(q):
				cells[q] = ice[0]


## Zeitbruch: a clock face round the hero draws itself from twelve o'clock
## over a faint glassy face, its hands spin backwards, runes circle it; the
## first stage adds a counter-turning rune ring, Zeitschleife a looping arrow.
static func _clock_face(canvas: CanvasItem, at: Vector2, body: Vector2, p: float, stage: int, art: float, clock: float) -> void:
	var arc: Array = Pal.ramp("arcane")
	var hole := _hole(at, body, art)
	var rad := 36.0 * art
	var drawn := _out(_span(p, 0.0, 0.18))
	var cover := 1.0 - _span(p, 0.75, 1.0)
	var closing := p > 0.16 and p < 0.24
	var frame := int(clock * PixelPaint.FPS)
	var face := {}
	_disc(face, at, (rad - 4.0 * art) * drawn, arc[0], art, 0.2 * cover, hole)
	_paint(canvas, face, art)
	var lines := {}
	_oval(lines, at, rad, rad, -PI * 0.5, TAU * drawn, arc[4] if closing else arc[3], art, cover, 0, 0, hole)
	_oval(lines, at, rad - art, rad - art, -PI * 0.5, TAU * drawn, arc[2], art, cover, 0, 0, hole)
	_oval(lines, at, rad - 5.0 * art, rad - 5.0 * art, -PI * 0.5, TAU * drawn, arc[2], art, cover, 0, 0, hole)
	for k in range(12):
		if float(k) / 12.0 > drawn:
			continue
		var dir := Vector2.from_angle(-PI * 0.5 + TAU * float(k) / 12.0)
		for j in range(4 if k % 3 == 0 else 2):
			var q := PixelPaint.at(at + dir * (rad - (2.0 + float(j)) * art), art)
			if not hole.has_point(q) and PixelPaint.shown(q, cover):
				lines[q] = arc[4] if k % 3 == 0 and j == 0 else arc[3]
	if p > 0.12:
		# the hands run backwards: the long one two and a half turns, slowing to a halt
		var turn := _out(_span(p, 0.12, 1.0))
		var long_dir := Vector2.from_angle(-PI * 0.5 - TAU * 2.5 * turn)
		var short_dir := Vector2.from_angle(-PI * 0.5 - TAU * 0.4 * turn)
		var side := long_dir.orthogonal() * art
		_seg(lines, at + long_dir * 6.0 * art, at + long_dir * (rad - 7.0 * art), arc[3], art, cover, 0, 0, hole)
		_seg(lines, at + long_dir * 6.0 * art + side, at + long_dir * (rad - 9.0 * art) + side, arc[2], art, cover, 0, 0, hole)
		_seg(lines, at + short_dir * 6.0 * art, at + short_dir * rad * 0.55, arc[3], art, cover, 0, 0, hole)
		var tip := PixelPaint.at(at + long_dir * (rad - 7.0 * art), art)
		if not hole.has_point(tip):
			lines[tip] = arc[4]
	if stage >= 2 and p > 0.15:
		# Zeitschleife: a dashed arrow looping backwards round the face
		var head := -PI * 0.5 - TAU * 1.5 * _span(p, 0.15, 1.0)
		var ring := rad + 2.5 * art
		_oval(lines, at, ring, ring, head, PI * 1.3, arc[3], art, cover, 3, frame, hole)
		var dir := Vector2.from_angle(head)
		var tangent := Vector2.from_angle(head - PI * 0.5)
		for o: Vector2 in [Vector2.ZERO, -tangent + dir, -tangent - dir, -tangent * 2.0 + dir * 2.0, -tangent * 2.0 - dir * 2.0]:
			var q := PixelPaint.at(at + dir * ring + o * art, art)
			if not hole.has_point(q) and PixelPaint.shown(q, cover):
				lines[q] = arc[4]
	_flush_under(canvas, lines, art)
	var runes := {}
	_rune_ring(runes, at, rad + 6.0 * art, 10, clock * 0.6, arc[3], art, cover * drawn, hole)
	if stage >= 1:
		_rune_ring(runes, at, rad + 11.0 * art, 12, -clock * 0.9 + 0.3, arc[2], art, cover * drawn, hole)
	_flush(canvas, runes, art)


## Letzter Pfeil: the aim line along `angle`, blinking and eaten from the hero
## outwards by the shot, a mark where it ends, a muzzle flash at the bow;
## Durchschlag a longer solid red-gold line, Pfeilsturm three lines in a fan.
static func _aim(canvas: CanvasItem, at: Vector2, body: Vector2, p: float, stage: int, angle: float, art: float, clock: float) -> void:
	var gold: Array = Pal.ramp("gold")
	var blood: Array = Pal.ramp("blood")
	var frame := int(clock * PixelPaint.FPS)
	var chest := at + body
	var length := (130.0 if stage == 0 else 170.0) * art
	var eaten := ARROW_SPEED * p
	var aims: Array = [angle] if stage < 2 else [angle - 0.28, angle, angle + 0.28]
	var blink := posmod(frame, 3) != 2
	var lines := {}
	var marks := {}
	for a: float in aims:
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal()
		if side.y > 0.0:
			side = -side
		var bow := chest + dir * 6.0 * art
		if eaten >= length:
			continue
		var from := bow + dir * maxf(eaten, 2.0 * art)
		var to := bow + dir * length
		if stage == 0:
			# dashed, crawling outward, blinking
			if blink:
				_seg(lines, from, to, gold[3], art, 1.0, 4, frame)
				_seg(lines, from - side * art, to - side * art, gold[2], art, 1.0, 4, frame)
		else:
			_seg(lines, from, to, gold[3], art)
			_seg(lines, from - side * art, to - side * art, blood[3], art)
			_seg(lines, from + side * art, to + side * art, blood[2], art, 0.5)
		if blink or stage >= 1:
			# the mark where the shot will land: four short arms round the spot
			for arm: Vector2 in [dir, -dir, side, -side]:
				for j in range(3, 6):
					marks[PixelPaint.at(to + arm * float(j) * art, art)] = gold[3] if stage == 0 else blood[3]
	_flush_under(canvas, lines, art)
	_flush(canvas, marks, art)
	if p < 0.24:
		# the muzzle flash: a star of rays at the bow, biggest along the shot
		var dir := Vector2.from_angle(angle)
		var bow := chest + dir * 6.0 * art
		var k := _out(_span(p, 0.0, 0.05)) * (1.0 - _span(p, 0.1, 0.24))
		var star := {}
		for i in range(8):
			var ray := dir.rotated(TAU * float(i) / 8.0)
			var reach := (14.0 if i == 0 else (7.0 if i % 2 == 0 else 4.0)) * k * (1.3 if stage >= 1 else 1.0)
			for j in range(int(reach) + 1):
				star[PixelPaint.at(bow + ray * float(j) * art, art)] = gold[3] if j < 3 else (gold[2] if float(j) < reach * 0.7 else gold[1])
		star[PixelPaint.at(bow, art)] = gold[4]
		_flush(canvas, star, art)
		var ring := {}
		var rad := (3.0 + 8.0 * _out(p / 0.24)) * art
		_oval(ring, bow, rad, rad, 0.0, TAU, gold[2], art, 1.0 - p / 0.24)
		_flush_under(canvas, ring, art)


## Todeszone's cast: the flask bursts at the hero's hand, glass and poison
## drops fly, a puff of gas rises (the zone itself is the host's pool).
static func _flask(canvas: CanvasItem, at: Vector2, body: Vector2, p: float, angle: float, art: float, seed: int) -> void:
	var poison: Array = Pal.ramp("poison")
	var steel: Array = Pal.ramp("steel")
	var hand := at + body + Vector2.from_angle(angle) * 7.0 * art
	var t := p * 0.7
	var bits := {}
	for i in range(18):
		var dir := Vector2.from_angle(TAU * _h(seed, i))
		var v := (24.0 + 30.0 * _h(seed, 20 + i)) * art
		var pos := hand + dir * v * t + Vector2(0.0, -v * 0.6 * t + 70.0 * art * t * t)
		var q := PixelPaint.at(pos, art)
		if PixelPaint.shown(q, 1.0 - _span(p, 0.4, 0.8)):
			bits[q] = steel[3] if i < 5 else poison[3 if i % 2 == 0 else 2]
			if i >= 5:
				bits[q + Vector2i(0, 1)] = poison[2]
	_flush_under(canvas, bits, art)
	# a lumpy puff of gas drifting off along the throw: shaded bellies, lit tops
	var puff := {}
	var k := 1.0 - _span(p, 0.25, 0.7)
	var aim := Vector2.from_angle(angle)
	var grow := _out(_span(p, 0.0, 0.3))
	for i in range(4):
		var c := hand + (aim * (2.0 + 4.0 * float(i)) + Vector2(0.0, -1.0 - 2.5 * float(i % 2))) * art * (0.4 + 0.6 * _out(p))
		var rad := (3.6 - 0.5 * float(i)) * grow * art
		_disc(puff, c + Vector2(0.0, 0.8) * art, rad, poison[1], art, k)
	for i in range(4):
		var c := hand + (aim * (2.0 + 4.0 * float(i)) + Vector2(0.0, -1.0 - 2.5 * float(i % 2))) * art * (0.4 + 0.6 * _out(p))
		var rad := (3.6 - 0.5 * float(i)) * grow * art
		_disc(puff, c, rad * 0.85, poison[2], art, k)
		_disc(puff, c + Vector2(-0.8, -0.8) * art, rad * 0.4, poison[3], art, k)
	_flush(canvas, puff, art, k > 0.5)


## Alpharuf: a spirit wolf's head pops up above the hero and howls (howl
## streaks bursting off it), spirit wisps rise; each stage more wisps.
static func _howl(canvas: CanvasItem, at: Vector2, body: Vector2, p: float, stage: int, art: float, clock: float, seed: int) -> void:
	var spirit: Array = Pal.ramp("spirit")
	var chest := PixelPaint.at(at + body, art)
	var rise := _back(_span(p, 0.02, 0.22))
	var cover := _span(p, 0.0, 0.08) * (1.0 - _span(p, 0.55, 1.0))
	var c := chest + Vector2i(0, -29 + roundi((1.0 - rise) * 10.0))
	var lines := {}
	for w in range(2):
		var k := _span(p, 0.12 + 0.16 * float(w), 0.5 + 0.16 * float(w))
		if k <= 0.0 or k >= 1.0:
			continue
		for i in range(9):
			var dir := Vector2.from_angle(-PI * 0.95 + PI * 0.9 * float(i) / 8.0)
			var r0 := 17.0 + 14.0 * _out(k)
			for j in range(4):
				var q := c + Vector2i(roundi(dir.x * (r0 + float(j)) * 1.15), roundi(dir.y * (r0 + float(j))))
				if PixelPaint.shown(q, 1.0 - k):
					lines[q] = spirit[4] if j == 0 else spirit[3]
	_flush_under(canvas, lines, art)
	var head := {}
	_wolf_head(head, c, spirit, cover)
	_flush(canvas, head, art, cover > 0.5)
	var wisps := {}
	for i in range(6 + 4 * stage):
		var start := 0.4 * _h(seed, i)
		var ph := _span(p, start, start + 0.6)
		if ph <= 0.0 or ph >= 1.0:
			continue
		var x := (_h(seed, 30 + i) - 0.5) * 32.0 + sin(clock * 3.0 + float(i)) * 1.5
		var q := chest + Vector2i(roundi(x), roundi(CHEST_TO_FEET - ph * 46.0))
		if PixelPaint.shown(q, 1.0 - ph):
			wisps[q] = spirit[4] if ph < 0.35 else spirit[3]
			wisps[q + Vector2i(1, 0)] = spirit[3]
			wisps[q + Vector2i(0, 1)] = spirit[2]
	_flush_under(canvas, wisps, art)


## The spirit wolf's head (about 23 × 26 cells) centred on cell `c`: pointed
## ears, a jagged ruff, glowing eyes, a long muzzle with the mouth open in a
## howl; lit from the upper left.
static func _wolf_head(cells: Dictionary, c: Vector2i, spirit: Array, cover: float) -> void:
	for y in range(-15, 11):
		for x in range(-11, 12):
			var fx := float(x)
			var fy := float(y)
			var ax := absf(fx)
			var head := (fx / 8.5) * (fx / 8.5) + ((fy + 1.0) / 7.0) * ((fy + 1.0) / 7.0) <= 1.0
			var ear := _in_tri(Vector2(ax, fy), Vector2(2.5, -5.0), Vector2(8.5, -4.0), Vector2(6.5, -15.0))
			var snout := fy >= 0.0 and fy <= 9.0 and ax <= 4.6 - 0.28 * fy
			var ruff := fy >= 0.0 and fy <= 6.0 and ax <= (10.5 if y % 2 == 0 else 9.0) - 0.7 * fy
			if not (head or ear or snout or ruff):
				continue
			var q := c + Vector2i(x, y)
			if cover < 1.0 and not PixelPaint.shown(q, cover):
				continue
			var col: Color = spirit[2]
			var light := fx * 0.8 + fy
			if light < -8.0:
				col = spirit[3]
			elif light > 6.0:
				col = spirit[1]
			if ear and not head and _in_tri(Vector2(ax, fy), Vector2(3.8, -5.5), Vector2(7.4, -5.0), Vector2(6.3, -12.0)):
				col = spirit[1]
			if ax <= 1.0 and fy >= -7.0 and fy <= 1.0:
				col = spirit[3]
			if (x == -4 or x == -3 or x == 3 or x == 4) and y == -2:
				col = spirit[4]
			if ax <= 1.0 and (y == 3 or y == 4):
				col = spirit[0]
			if fy >= 6.0 and ax <= 2.2 - 0.25 * (fy - 6.0):
				col = Pal.INK
			cells[q] = col


## Blutrausch: blood bursts out of the hero's chest, drops fly in arcs and
## splat on the floor, a red pulse runs out from his feet; the first stage
## throws them farther, Blutgericht cracks the floor dark red.
static func _blood_burst(canvas: CanvasItem, at: Vector2, body: Vector2, foot: Vector2, p: float, stage: int, art: float, seed: int) -> void:
	var blood: Array = Pal.ramp("blood")
	var hole := _hole(at, body, art)
	var cover := 1.0 - _span(p, 0.72, 1.0)
	if stage >= 2:
		var cracks := {}
		var grow := _out(_span(p, 0.0, 0.25))
		for i in range(7):
			var dir := (Vector2.from_angle(TAU * (float(i) + 0.4 * _h(seed, 90 + i)) / 7.0) * Vector2(1.0, 0.6)).normalized()
			var side := dir.orthogonal()
			var n := int((16.0 + 10.0 * _h(seed, 100 + i)) * grow)
			for j in range(5, 5 + n):
				var zig := float([0, 1, 0, -1][(j + i) % 4])
				var base := foot + (dir * float(j) + side * zig) * art
				var q := PixelPaint.at(base, art)
				if hole.has_point(q) or not PixelPaint.shown(q, cover):
					continue
				cracks[q] = blood[3] if j % 5 == 0 else blood[0]
				var q2 := PixelPaint.at(base + side * art, art)
				if not hole.has_point(q2) and j < 2 + n:
					cracks[q2] = blood[1]
		_flush_under(canvas, cracks, art)
	var ring := {}
	var rad := (5.0 + 18.0 * _out(_span(p, 0.0, 0.35))) * art
	var rk := 1.0 - _span(p, 0.1, 0.45)
	_oval(ring, foot, rad, rad * 0.5, 0.0, TAU, blood[3], art, rk, 0, 0, hole)
	_oval(ring, foot, rad - art, (rad - art) * 0.5, 0.0, TAU, blood[2], art, rk, 0, 0, hole)
	_flush_under(canvas, ring, art)
	if p < 0.2:
		# the burst out of the chest: a star of blood
		var k := _out(_span(p, 0.0, 0.06)) * (1.0 - _span(p, 0.08, 0.2))
		var star := {}
		for i in range(10):
			var ray := Vector2.from_angle(TAU * (float(i) + _h(seed, 130 + i) * 0.5) / 10.0)
			var reach := (5.0 + 6.0 * _h(seed, 140 + i)) * k * (1.3 if stage >= 1 else 1.0)
			for j in range(3, int(reach) + 4):
				star[PixelPaint.at(at + body + ray * float(j) * art, art)] = blood[3] if j < 5 else blood[2]
		_flush(canvas, star, art)
	var drops := {}
	var far := 1.4 if stage >= 1 else 1.0
	var t := p * 0.9
	var height := float(foot.y - (at.y + body.y)) / art
	for i in range(24 + 8 * stage):
		var dir := Vector2.from_angle(TAU * _h(seed, i))
		var speed := (60.0 + 70.0 * _h(seed, 40 + i)) * far
		var vz := 40.0 + 50.0 * _h(seed, 70 + i)
		var g := 260.0
		var z := height + vz * t - 0.5 * g * t * t
		var land := (vz + sqrt(vz * vz + 2.0 * g * height)) / g
		var floor_at := foot + dir * Vector2(1.0, 0.7) * speed * minf(t, land) * art
		if z > 0.0:
			var q := PixelPaint.at(floor_at + Vector2(0.0, -z * art), art)
			drops[q] = blood[3]
			drops[q + Vector2i(1, 0)] = blood[2]
			drops[q + Vector2i(0, 1)] = blood[2]
			drops[q + Vector2i(1, 1)] = blood[1]
		else:
			var q := PixelPaint.at(floor_at, art)
			for o: Vector2i in [Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
				if PixelPaint.shown(q + o, cover):
					drops[q + o] = blood[0] if o.y == 1 else (blood[2] if absi(o.x) <= 1 else blood[1])
	_flush(canvas, drops, art)


## Unbezwingbar: hex plates fly in from round the hero, overshoot and lock
## onto the shield dome's silhouette by p≈0.4 (a flash and sparks each, the
## outline flashes when all are on), then hand over to the dome's own plates;
## Vergeltung's rivets flash on them.
static func _plates_in(canvas: CanvasItem, foot: Vector2, p: float, stage: int, art: float, clock: float) -> void:
	var gold: Array = Pal.ramp("gold")
	var steel: Array = Pal.ramp("steel")
	var cover := 1.0 - _span(p, 0.55, 0.85)
	var frame := int(clock * PixelPaint.FPS)
	var centre := foot + Vector2(0.0, -DOME_H * 0.45) * art
	var spots: Array = []
	for i in range(10):
		spots.append(_dome_point(foot, (float(i) + 0.5) / 10.0, art))
	for i in range(3):
		var t := PI * float(i + 1) / 4.0
		spots.append(foot + Vector2(cos(t) * DOME_W, sin(t) * DOME_D) * art)
	var cells := {}
	var sparks := {}
	for k in range(spots.size()):
		var rim: Vector2 = spots[k]
		var land := 0.16 + 0.018 * float(k)
		var go := _span(p, land - 0.16, land)
		if go <= 0.0:
			continue
		var from := centre + (rim - centre) * 2.6
		var flash := p >= land and p < land + 0.06
		_plate(cells, PixelPaint.at(from.lerp(rim, _back(go)), art), gold, steel, false, flash, 2 if stage >= 2 and posmod(frame + k, 4) < 2 else 0, cover)
		if flash:
			var out := (rim - centre).normalized()
			for j in range(3):
				sparks[PixelPaint.at(rim + out.rotated((float(j) - 1.0) * 0.6) * (6.0 + 3.0 * (p - land) / 0.06) * art, art)] = gold[3]
	if p > 0.4 and p < 0.52:
		# all locked: the dome's outline flashes once
		_oval(sparks, foot, DOME_W * art, DOME_H * art, PI, PI, gold[3], art, 1.0 - _span(p, 0.4, 0.52), 2, frame)
		_oval(sparks, foot, DOME_W * art, DOME_D * art, 0.0, PI, gold[3], art, 1.0 - _span(p, 0.4, 0.52), 2, frame)
	_flush_under(canvas, sparks, art)
	_flush(canvas, cells, art, cover > 0.5)


# ---------- the lasting auras ----------

## A lasting ultimate on the hero standing at `at` while it runs (`left` of
## `total` seconds; dithers in over the first 0.3 s, out over the last 0.6 s;
## `feet` the offset from `at` to his feet, world px). kind: "timebreak" (a
## ticking clock ring at his feet, sand rising), "bloodlust" (a blood ripple,
## drops, a pulsing glint; over the host's rage flames), "unbreakable" (gold
## sparks crawling over the host's shield dome, rivets flashing),
## "blade_dance" (extra.radius world px: steel blades orbiting with trails).
static func aura(canvas: CanvasItem, kind: String, at: Vector2, body: Vector2, left: float, total: float, stage: int, art: float, clock: float, extra: Dictionary, feet: Vector2 = Vector2.ZERO) -> void:
	var cover := _life_cover(left, total)
	if cover <= 0.0:
		return
	var age := total - left
	match kind:
		"timebreak": _tick_ring(canvas, at, body, at + feet, age, stage, art, clock, cover)
		"bloodlust": _blood_aura(canvas, at, body, at + feet, age, stage, art, clock, cover)
		"unbreakable": _dome_sparks(canvas, at + feet, stage, art, clock, cover)
		"blade_dance":
			# the same spin and radius as the cast's blades, so they hand over seamlessly
			_blade_ring(canvas, at, body, float(extra.get("radius", 128.0)), _out(age / 0.35), 3 + stage, art, clock, cover, true, stage >= 2)


## Zeitbruch running: a faint clock ring round the feet, its hand ticking back
## a step every quarter second, sand rising; brighter from the first stage, a
## second counter-turning ring at the second.
static func _tick_ring(canvas: CanvasItem, at: Vector2, body: Vector2, foot: Vector2, age: float, stage: int, art: float, clock: float, cover: float) -> void:
	var arc: Array = Pal.ramp("arcane")
	var hole := _hole(at, body, art)
	var k := cover * (0.55 if stage == 0 else 0.9)
	var rad := 24.0 * art
	var frame := int(clock * PixelPaint.FPS)
	var cells := {}
	_oval(cells, foot, rad, rad, 0.0, TAU, arc[2] if stage == 0 else arc[3], art, k, 0, 0, hole)
	for t in range(12):
		var q := PixelPaint.at(foot + Vector2.from_angle(TAU * float(t) / 12.0) * (rad - 2.0 * art), art)
		if not hole.has_point(q) and PixelPaint.shown(q, k):
			cells[q] = arc[3]
	var hand := Vector2.from_angle(-PI * 0.5 - TAU * floorf(age * 4.0) / 12.0)
	_seg(cells, foot + hand * 5.0 * art, foot + hand * (rad - 3.0 * art), arc[3], art, k, 0, 0, hole)
	if stage >= 2:
		_oval(cells, foot, rad + 4.0 * art, rad + 4.0 * art, 0.0, TAU, arc[2], art, k, 3, -frame, hole)
	for i in range(8):
		var ph := fposmod(clock * 0.45 + _h(7, i), 1.0)
		var x := (_h(9, i) - 0.5) * 2.0 * rad * 0.7
		var q := PixelPaint.at(foot + Vector2(x, -ph * 50.0 * art), art)
		if not hole.has_point(q) and PixelPaint.shown(q, k * (1.0 - ph)):
			cells[q] = arc[4] if i % 3 == 0 else arc[3]
	_flush_under(canvas, cells, art)


## Blutrausch running: a dark ripple at the feet, drops dripping off the hero,
## a red glint round him on each pulse; Blutgericht darker and faster.
static func _blood_aura(canvas: CanvasItem, at: Vector2, body: Vector2, foot: Vector2, age: float, stage: int, art: float, clock: float, cover: float) -> void:
	var blood: Array = Pal.ramp("blood")
	var hole := _hole(at, body, art)
	var period := 0.8 if stage < 2 else 0.5
	var rings := {}
	for w in range(2):
		var ph := fposmod(age / period + 0.5 * float(w), 1.0)
		var rad := (5.0 + 13.0 * ph) * art
		_oval(rings, foot, rad, rad * 0.5, 0.0, TAU, blood[1] if stage < 2 else blood[0], art, cover * (1.0 - ph), 0, 0, hole)
	if fposmod(age / period, 1.0) < 0.18:
		_oval(rings, at + body, 10.0 * art, 16.0 * art, 0.0, TAU, blood[3] if stage < 2 else blood[2], art, cover, 3, int(clock * PixelPaint.FPS))
	_flush_under(canvas, rings, art)
	var drops := {}
	var chest := PixelPaint.at(at + body, art)
	var floor_y := PixelPaint.at(foot, art).y
	for i in range(5):
		var ph := fposmod(age / 0.6 + _h(11, i), 1.0)
		var start := chest + Vector2i(roundi((_h(12, i) - 0.5) * 12.0), roundi((_h(13, i) - 0.4) * 14.0))
		var q := Vector2i(start.x, start.y + roundi(ph * ph * float(floor_y - start.y)))
		if not PixelPaint.shown(q, cover):
			continue
		if ph < 0.85:
			drops[q] = blood[3]
			drops[q + Vector2i(0, 1)] = blood[2]
		else:
			drops[Vector2i(start.x, floor_y)] = blood[1]
			drops[Vector2i(start.x + 1, floor_y)] = blood[0]
	_flush(canvas, drops, art)


## Unbezwingbar running, over the host's shield dome: gold glints crawling
## over its silhouette, more per stage; rivets on it from the first stage,
## flashing at the second.
static func _dome_sparks(canvas: CanvasItem, foot: Vector2, stage: int, art: float, clock: float, cover: float) -> void:
	var gold: Array = Pal.ramp("gold")
	var frame := int(clock * PixelPaint.FPS)
	var cells := {}
	var n := 2 + stage
	for k in range(n):
		var s := fposmod(clock * 0.3 + float(k) / float(n), 1.0)
		var k2 := cover * sin(PI * s)
		for j in range(6):
			var q := PixelPaint.at(_dome_point(foot, clampf(s - 0.01 * float(j), 0.0, 1.0), art), art)
			if PixelPaint.shown(q, k2 * (1.0 - 0.14 * float(j))):
				cells[q] = gold[4] if j == 0 else (gold[3] if j < 3 else gold[2])
	if stage >= 1:
		var rivets: Array = [0.2, 0.5, 0.8] if stage == 1 else [0.12, 0.3, 0.5, 0.7, 0.88]
		for i in range(rivets.size()):
			var q := PixelPaint.at(_dome_point(foot, float(rivets[i]), art), art)
			if PixelPaint.shown(q, cover):
				var lit := stage >= 2 and posmod(frame + i * 3, 8) < 2
				cells[q] = gold[4] if lit else gold[3]
				if lit:
					for o: Vector2i in N4:
						cells[q + o] = gold[3]
	_flush_under(canvas, cells, art)


## Klingentanz's blades: `n` blades `radius` × `grow` out from the hero's waist,
## spinning round him, each with a dithered sweep behind (`trail`) and blood
## on its edge and dripping (`bleed`).
static func _blade_ring(canvas: CanvasItem, at: Vector2, body: Vector2, radius: float, grow: float, n: int, art: float, clock: float, cover: float, trail: bool, bleed: bool) -> void:
	if cover <= 0.0:
		return
	var steel: Array = Pal.ramp("steel")
	var gold: Array = Pal.ramp("gold")
	var blood: Array = Pal.ramp("blood")
	var centre := at + body * 0.5
	var dist := radius * grow
	if dist < 2.0 * art:
		return
	var frame := int(clock * PixelPaint.FPS)
	if trail:
		var sweep := {}
		var steps := maxi(6, int(0.9 * dist / art))
		for k in range(n):
			var a0 := TAU * float(k) / float(n) + clock * BLADE_SPIN
			for i in range(steps):
				var a := a0 - 0.2 - 0.9 * float(i) / float(steps)
				var fade := cover * 0.8 * (1.0 - float(i) / float(steps))
				for w in range(2):
					var q := PixelPaint.at(centre + Vector2.from_angle(a) * (dist - float(w) * art), art)
					if PixelPaint.shown(q, fade * (1.0 - 0.4 * float(w))):
						sweep[q] = steel[3] if i < steps / 3 and w == 0 else steel[2]
		_flush_under(canvas, sweep, art)
	var cells := {}
	for k in range(n):
		var a := TAU * float(k) / float(n) + clock * BLADE_SPIN
		var pos := centre + Vector2.from_angle(a) * dist
		var along := Vector2.from_angle(a + PI * 0.5)
		var out := Vector2.from_angle(a)
		_blade(cells, pos, along, out, art, cover, steel, gold)
		if bleed:
			cells[PixelPaint.at(pos + along * 4.0 * art + out * art, art)] = blood[3]
			cells[PixelPaint.at(pos + along * 6.0 * art + out * art, art)] = blood[2]
			var drip := PixelPaint.at(pos + Vector2(0.0, float(3 + posmod(frame + k * 3, 6))) * art, art)
			if PixelPaint.shown(drip, cover):
				cells[drip] = blood[3]
				cells[drip + Vector2i(0, 1)] = blood[2]
	_flush(canvas, cells, art, cover > 0.5)


## One blade (about 20 cells) at `pos` flying along `along`, its edge towards
## `out`: pommel, grip, a wide crossguard, a steel blade whose edge catches the
## light, its back in shade, a lit point.
static func _blade(cells: Dictionary, pos: Vector2, along: Vector2, out: Vector2, art: float, cover: float, steel: Array, gold: Array) -> void:
	for i in range(-7, 13):
		var base := pos + along * float(i) * art
		var q := PixelPaint.at(base, art)
		if cover < 1.0 and not PixelPaint.shown(q, cover):
			continue
		if i >= -2:
			cells[q] = steel[3] if i >= 10 else steel[2]
			if i < 11:
				cells[PixelPaint.at(base + out * art, art)] = steel[4] if posmod(i, 5) == 0 else steel[3]
			if i < 9:
				cells[PixelPaint.at(base - out * art, art)] = steel[1]
		elif i == -3:
			for j in range(-3, 4):
				cells[PixelPaint.at(base + out * float(j) * art, art)] = gold[3] if j > 0 else gold[2]
		elif i == -7:
			cells[q] = gold[3]
		else:
			cells[q] = gold[1]


# ---------- the waves ----------

## The extra of an ultimate's delayed or closing wave (0.7 s; `p` 0..1; the
## ring itself is the host's): Feuersturm's flames bursting across `r`,
## Splitterbruch's ice shards flung out, Zeitschleife's runes flung out,
## Blutgericht's blood crown, Schildstoß's and Vergeltung's plates flung out,
## Klingentanz's Finale as a big X slash.
static func wave(canvas: CanvasItem, talent: String, at: Vector2, r: float, p: float, stage: int, art: float, clock: float, seed: int) -> void:
	p = clampf(p, 0.0, 1.0)
	match talent:
		"fire_14": _firestorm(canvas, at, r, p, art, clock, seed)
		"frost_14": _shatter(canvas, at, r, p, art, clock, seed)
		"arcane_14": _rune_burst(canvas, at, r, p, art, seed)
		"berserk_14": _blood_crown(canvas, at, r, p, art, seed)
		"guard_14": _plates_out(canvas, at, r, p, stage, art, clock, seed)
		"blade_14": _finale(canvas, at, r, p, art, seed)


static func _firestorm(canvas: CanvasItem, at: Vector2, r: float, p: float, art: float, clock: float, seed: int) -> void:
	var fire: Array = Pal.ramp("fire")
	var ranks := {}
	var cover := 1.0 - _span(p, 0.6, 1.0)
	var id := 0
	for ring: Array in STORM_RINGS:
		var frac := float(ring[0])
		for i in range(int(ring[1])):
			id += 1
			var a := TAU * (float(i) + _h(seed, id)) / float(ring[1])
			var b := PixelPaint.at(at + Vector2.from_angle(a) * r * frac, art)
			var start := 0.3 * frac
			var g := _back(_span(p, start, start + 0.14))
			if g <= 0.0:
				continue
			var half := 4.8 - 1.4 * frac
			var h := (27.0 - 9.0 * frac) * g * (1.0 - 0.6 * _span(p, 0.55, 1.0))
			# a low, wide burst first, the tongue shooting out of it
			_flame(ranks, b, half * 1.7, h * 0.3, clock, seed + id * 17, cover)
			_flame(ranks, b, half, h, clock, seed + id * 13, cover)
	_flush_ramp(canvas, ranks, fire, art, cover > 0.5)
	var embers := {}
	for i in range(26):
		var ph := _span(p, 0.15 + 0.3 * _h(seed, 70 + i), 1.0)
		if ph <= 0.0:
			continue
		var q := PixelPaint.at(at + Vector2.from_angle(TAU * _h(seed, 90 + i)) * r * sqrt(_h(seed, 110 + i)) + Vector2(0.0, -ph * 32.0 * art), art)
		if PixelPaint.shown(q, 1.0 - ph):
			embers[q] = fire[3] if i % 3 else fire[4]
	_flush_under(canvas, embers, art)


static func _shatter(canvas: CanvasItem, at: Vector2, r: float, p: float, art: float, clock: float, seed: int) -> void:
	var ice: Array = Pal.ramp("ice")
	var frame := int(clock * PixelPaint.FPS)
	var cover := 1.0 - _span(p, 0.6, 1.0)
	var u := _out(_span(p, 0.0, 0.75))
	var cells := {}
	var axes: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, -1)]
	for i in range(22):
		var dir := Vector2.from_angle(TAU * (float(i) + 0.6 * _h(seed, i)) / 22.0)
		var d := lerpf(r * 0.12, r * (0.45 + 0.55 * _h(seed, 30 + i)), u)
		var z := 4.0 * (10.0 + 10.0 * _h(seed, 60 + i)) * u * (1.0 - u)
		var c := PixelPaint.at(at + dir * d + Vector2(0.0, -z * art), art)
		var axis: Vector2i = axes[posmod(frame + i, 4)]
		var side := Vector2i(-axis.y, axis.x)
		for j in range(-3, 4):
			var q := c + axis * j
			if cover < 1.0 and not PixelPaint.shown(q, cover):
				continue
			cells[q] = ice[3] if j < 0 else (ice[4] if j == 0 else ice[2])
			if j >= -1 and j <= 2:
				cells[q + side] = ice[1] if j > 0 else ice[2]
	_flush(canvas, cells, art, cover > 0.5)
	var chips := {}
	for i in range(30):
		var k := _span(p, 0.15 + 0.2 * _h(seed, 120 + i), 0.9)
		if k <= 0.0:
			continue
		var q := PixelPaint.at(at + Vector2.from_angle(TAU * _h(seed, 150 + i)) * r * (0.3 + 0.7 * _h(seed, 180 + i)) * _out(k), art)
		if PixelPaint.shown(q, 1.0 - k):
			chips[q] = ice[3] if i % 4 else ice[4]
	_flush_under(canvas, chips, art)


static func _rune_burst(canvas: CanvasItem, at: Vector2, r: float, p: float, art: float, seed: int) -> void:
	var arc: Array = Pal.ramp("arcane")
	var cover := 1.0 - _span(p, 0.5, 1.0)
	var u := _out(_span(p, 0.0, 0.7))
	var lines := {}
	for i in range(6):
		var rad := lerpf(10.0 * art, r, _out(_span(p, 0.0, 0.6)))
		_oval(lines, at, rad, rad, TAU * float(i) / 6.0 + p * 1.5, 0.45, arc[3], art, cover)
		_oval(lines, at, rad - art, rad - art, TAU * float(i) / 6.0 + p * 1.5, 0.3, arc[2], art, cover)
	_flush_under(canvas, lines, art)
	var runes := {}
	for i in range(12):
		var dir := Vector2.from_angle(TAU * (float(i) + _h(seed, i)) / 12.0)
		var q := PixelPaint.at(at + dir * r * (0.5 + 0.5 * _h(seed, 20 + i)) * u, art) - Vector2i(1, 1)
		_glyph_fill(runes, RUNES[posmod(i + seed, RUNES.size())], q, arc[4] if p < 0.15 else arc[3], cover)
	_flush(canvas, runes, art, cover > 0.5)


static func _blood_crown(canvas: CanvasItem, at: Vector2, r: float, p: float, art: float, seed: int) -> void:
	var blood: Array = Pal.ramp("blood")
	var cover := 1.0 - _span(p, 0.75, 1.0)
	var up := sin(PI * _span(p, 0.0, 0.55))
	var pool := {}
	var spread := _out(_span(p, 0.0, 0.3))
	_oval_fill(pool, at, (6.0 + 8.0 * spread) * art, (3.0 + 4.0 * spread) * art, blood[1], art, cover)
	_oval_fill(pool, at + Vector2(-1.0, -0.5) * art, (3.0 + 4.0 * spread) * art, (1.5 + 2.0 * spread) * art, blood[2], art, cover)
	_flush(canvas, pool, art, cover > 0.5)
	# the crown: spikes splaying out of a ring, a drop on each tip
	var spikes: Array = []
	for i in range(12):
		var a := TAU * float(i) / 12.0 + 0.2 * _h(seed, i)
		spikes.append([a, sin(a)])
	spikes.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) < float(y[1]))
	for spike: Array in spikes:
		var a: float = spike[0]
		var cells := {}
		var base := at + Vector2(cos(a) * 12.0, sin(a) * 5.0) * art
		var h := 15.0 * up * (0.6 + 0.4 * _h(seed, 20 + int(a * 10.0)))
		var lean := cos(a) * 0.4
		for j in range(int(h) + 1):
			var row := base + Vector2(lean * float(j), -float(j)) * art
			var wide := 2 if float(j) < h * 0.5 else 1
			for w in range(wide):
				var q := PixelPaint.at(row + Vector2(float(w), 0.0) * art, art)
				if PixelPaint.shown(q, cover):
					cells[q] = blood[3] if float(j) > h - 2.0 else (blood[2] if j > 1 else blood[1])
		if up > 0.55:
			var tip := PixelPaint.at(base + Vector2(lean * (h + 3.0), -(h + 3.0 + 4.0 * (up - 0.55))) * art, art)
			for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				cells[tip + o] = blood[3] if o == Vector2i.ZERO else blood[2]
		_flush(canvas, cells, art, cover > 0.5)
	var drops := {}
	var u := _span(p, 0.0, 0.65)
	for i in range(22):
		var dir := Vector2.from_angle(TAU * _h(seed, 40 + i))
		var d := r * (0.35 + 0.65 * _h(seed, 70 + i))
		var z := 4.0 * 20.0 * (0.6 + 0.4 * _h(seed, 100 + i)) * u * (1.0 - u)
		var q := PixelPaint.at(at + dir * d * u + Vector2(0.0, -z * art), art)
		if u < 1.0:
			drops[q] = blood[3]
			drops[q + Vector2i(1, 0)] = blood[2]
			drops[q + Vector2i(0, 1)] = blood[2]
		else:
			for o: Vector2i in [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				if PixelPaint.shown(q + o, cover):
					drops[q + o] = blood[1] if o == Vector2i.ZERO else blood[0]
	_flush(canvas, drops, art)


static func _plates_out(canvas: CanvasItem, at: Vector2, r: float, p: float, stage: int, art: float, clock: float, seed: int) -> void:
	var gold: Array = Pal.ramp("gold")
	var steel: Array = Pal.ramp("steel")
	var frame := int(clock * PixelPaint.FPS)
	var cover := 1.0 - _span(p, 0.55, 1.0)
	var u := _out(_span(p, 0.0, 0.6))
	var cells := {}
	var trail := {}
	for k in range(10):
		var from := _dome_point(at, (float(k) + 0.5) / 10.0, art)
		var a := (from - (at + Vector2(0.0, -DOME_H * 0.45) * art)).angle()
		var to := at + Vector2.from_angle(a) * r * (0.75 + 0.25 * _h(seed, k))
		var z := 4.0 * 12.0 * u * (1.0 - u)
		var pos := from.lerp(to, u) + Vector2(0.0, -z * art)
		_plate(cells, PixelPaint.at(pos, art), gold, steel, posmod(frame + k, 2) == 1, p < 0.08, 1 if stage >= 2 else 0, cover)
		for j in range(1, 4):
			var back := PixelPaint.at(from.lerp(to, maxf(0.0, u - 0.06 * float(j))) + Vector2(0.0, -z * art), art)
			if PixelPaint.shown(back, cover * (0.8 - 0.2 * float(j))):
				trail[back] = gold[3] if j == 1 else gold[2]
	_flush_under(canvas, trail, art)
	_flush(canvas, cells, art, cover > 0.5)


static func _finale(canvas: CanvasItem, at: Vector2, r: float, p: float, art: float, seed: int) -> void:
	var steel: Array = Pal.ramp("steel")
	var blood: Array = Pal.ramp("blood")
	var cover := 1.0 - _span(p, 0.5, 1.0)
	var cells := {}
	var drops := {}
	for s in range(2):
		var dir := Vector2(1.0, 1.0 if s == 0 else -1.0).normalized()
		var lit := dir.orthogonal()
		if lit.y > 0.0:
			lit = -lit
		var sweep := _out(_span(p, 0.1 * float(s), 0.1 * float(s) + 0.16))
		if sweep <= 0.0:
			continue
		var from := at - dir * r * 0.85
		var length := 2.0 * r * 0.85
		var steps := int(length * sweep / art)
		for i in range(steps):
			var t := float(i) * art / length
			var w := sin(PI * t)
			var base := from + dir * float(i) * art
			for o in range(-2, 3):
				if absi(o) == 2 and w < 0.75:
					continue
				if absi(o) == 1 and w < 0.3:
					continue
				var q := PixelPaint.at(base + lit * float(o) * art, art)
				if cover < 1.0 and not PixelPaint.shown(q, cover):
					continue
				var col: Color = steel[3]
				if o == 0:
					col = steel[4] if i % 4 == 0 else steel[3]
				elif o < 0:
					col = steel[2] if o == -1 else steel[1]
				cells[q] = col
			# blood drips off the cut once the sweep has passed
			if i % 9 == 4 + (seed % 2):
				var since := p - (0.1 * float(s) + 0.16 * t)
				if since > 0.0:
					var q := PixelPaint.at(base + Vector2(0.0, 220.0 * since * since * art + 2.0 * art), art)
					if PixelPaint.shown(q, cover):
						drops[q] = blood[3]
						drops[q + Vector2i(0, 1)] = blood[2]
	_flush(canvas, cells, art, cover > 0.5)
	_flush(canvas, drops, art)


# ---------- the zones ----------

## Overlay of a lasting zone at `at` (radius `r` world px, `left` of `total`
## seconds, ticking every `every` s) over the host's pool: Todeszone's crawling
## rim, a pulse on each tick and bubbles (Sumpfgift murk and reeds, Seuchenherz
## a beating heart in the middle); Feuersturm's burning ground as flickering flames.
static func zone(canvas: CanvasItem, talent: String, at: Vector2, r: float, left: float, total: float, stage: int, every: float, art: float, clock: float, seed: int) -> void:
	match talent:
		"trapper_14": _death_zone(canvas, at, r, left, total, stage, every, art, clock, seed)
		"fire_14": _burning_ground(canvas, at, r, left, total, art, clock, seed)


## The Todeszones' cells of the current beat, by zone (seed): {tick, at, r, stage, layers}.
static var _zone_cells: Dictionary = {}


## The Todeszone: its picture is worked out once per 12 fps beat (its look
## moves on that beat; PixelPaint.bake) and drawn as it is in the frames between.
static func _death_zone(canvas: CanvasItem, at: Vector2, r: float, left: float, total: float, stage: int, every: float, art: float, clock: float, seed: int) -> void:
	var tick := int(clock * PixelPaint.FPS)
	var held: Dictionary = _zone_cells.get(seed, {})
	if int(held.get("tick", -1)) != tick or Vector2(held.get("at", Vector2.INF)) != at or float(held.get("r", -1.0)) != r or int(held.get("stage", -1)) != stage:
		# the zone at the beat's own time
		var back := clock - float(tick) / PixelPaint.FPS
		held = {"tick": tick, "at": at, "r": r, "stage": stage,
			"baked": PixelPaint.bake(_draw_list(_death_zone_layers(at, r, left + back, total, stage, every, art, float(tick) / PixelPaint.FPS, seed)), art)}
		if _zone_cells.size() > 32:
			_zone_cells.clear()
		_zone_cells[seed] = held
	PixelPaint.draw_baked(canvas, held.baked, art)


## Layers (["paint" | "under" | "flush", cells, outline]) as the cells and
## colours they paint, in order (as _paint, _flush_under and _flush would):
## [cell, colour, cell, colour, ...].
static func _draw_list(layers: Array) -> Array:
	var out: Array = []
	for layer: Array in layers:
		var cells: Dictionary = layer[1]
		match str(layer[0]):
			"under":
				for q: Vector2i in cells:
					if not cells.has(q + Vector2i(0, 1)):
						out.append_array([q + Vector2i(0, 1), Pal.INK])
			"flush":
				if bool(layer[2]):
					var ink := {}
					for q: Vector2i in cells:
						for o: Vector2i in N4:
							if not cells.has(q + o):
								ink[q + o] = true
					for q: Vector2i in ink:
						out.append_array([q, Pal.INK])
		for q: Vector2i in cells:
			out.append_array([q, cells[q]])
	return out


## The Todeszone's cells at `clock` as layers to paint in order:
## ["paint" | "under" | "flush", cells, outline].
static func _death_zone_layers(at: Vector2, r: float, left: float, total: float, stage: int, every: float, art: float, clock: float, seed: int) -> Array:
	var layers: Array = []
	var poison: Array = Pal.ramp("poison")
	var age := total - left
	var cover := clampf(age / 0.4, 0.0, 1.0) * clampf(left / 0.6, 0.0, 1.0)
	if cover <= 0.0:
		return layers
	var frame := int(clock * PixelPaint.FPS)
	var ph := fposmod(age, maxf(0.1, every)) / maxf(0.1, every)
	if stage >= 1:
		# Sumpfgift: dark murk patches in the pool
		var murk := {}
		for i in range(5):
			var c := at + Vector2.from_angle(TAU * _h(seed, 200 + i)) * r * 0.65 * sqrt(_h(seed, 210 + i))
			_disc(murk, c, (4.0 + 3.0 * _h(seed, 220 + i)) * art, poison[0], art, 0.45 * cover)
		layers.append(["paint", murk, false])
	var lines := {}
	_oval(lines, at, r * _out(ph), r * _out(ph), 0.0, TAU, poison[3] if ph < 0.2 else poison[2], art, cover * (1.0 - ph) * 0.85)
	_oval(lines, at, r, r, 0.0, TAU, poison[4] if ph < 0.1 else poison[3], art, cover, 3, frame)
	_oval(lines, at, r - art, r - art, 0.0, TAU, poison[2], art, cover, 3, frame + 1)
	for i in range(9):
		var spot := PixelPaint.at(at + Vector2.from_angle(TAU * _h(seed, i)) * r * 0.8 * sqrt(_h(seed, 20 + i)), art)
		var bp := fposmod(clock / 1.4 + _h(seed, 40 + i), 1.0)
		var shape: Array = []
		if bp < 0.5:
			shape = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		elif bp < 0.8:
			shape = [Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1),
				Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2), Vector2i(-2, -1), Vector2i(-2, 0), Vector2i(-2, 1)]
		elif bp < 0.9:
			shape = [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2), Vector2i(0, -3)]
		for o: Vector2i in shape:
			if PixelPaint.shown(spot + o, cover):
				lines[spot + o] = poison[4] if bp >= 0.8 else poison[3]
	layers.append(["under", lines, false])
	var solid := {}
	if stage >= 1:
		# reeds swaying in the murk
		for i in range(10):
			var b := PixelPaint.at(at + Vector2.from_angle(TAU * _h(seed, 300 + i)) * r * 0.85 * sqrt(_h(seed, 310 + i)), art)
			var h := 3 + int(4.0 * _h(seed, 320 + i))
			for j in range(h):
				var sway := roundi(sin(clock * 2.0 + float(i)) * float(j) / float(h))
				var q := b + Vector2i(sway, -j)
				if PixelPaint.shown(q, cover):
					solid[q] = poison[2] if j == h - 1 else poison[1]
	if stage >= 2:
		# Seuchenherz: a dark heart beating in the middle on every tick
		var beat := ph < 0.15
		var c := PixelPaint.at(at, art) - Vector2i(6, 5)
		var heart := {}
		_glyph_fill(heart, HEART, c, poison[1] if beat else poison[0], cover)
		if beat:
			for q: Vector2i in heart.keys():
				for o: Vector2i in N4:
					if not heart.has(q + o):
						solid[q + o] = poison[2]
		for q: Vector2i in heart:
			solid[q] = heart[q]
		for o: Vector2i in [Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2)]:
			solid[c + o] = poison[3] if beat else poison[2]
	layers.append(["flush", solid, cover > 0.5])
	return layers


static func _burning_ground(canvas: CanvasItem, at: Vector2, r: float, left: float, total: float, art: float, clock: float, seed: int) -> void:
	var fire: Array = Pal.ramp("fire")
	var age := total - left
	var k := _out(clampf(age / 0.3, 0.0, 1.0)) * clampf(left, 0.0, 1.0)
	if k <= 0.0:
		return
	var ranks := {}
	for i in range(11):
		var b := PixelPaint.at(at + Vector2.from_angle(TAU * _h(seed, i)) * r * 0.85 * sqrt(_h(seed, 20 + i)), art)
		var h := (9.0 + 6.0 * _h(seed, 40 + i)) * (0.75 + 0.25 * sin(clock * 9.0 + float(i) * 1.7)) * k
		_flame(ranks, b, 2.5 + _h(seed, 60 + i), h, clock, seed + i * 7, 1.0)
	_flush_ramp(canvas, ranks, fire, art)


# ---------- shots and spirits ----------

## The Letzter Pfeil in flight at `at` (already at shot height) along `dir`: a
## big outlined arrow (~22 cells: fletching, a gold shaft, a steel head) with a
## gold dither trail; from the first stage red fletching, red glints on the
## shaft and a longer trail.
static func arrow(canvas: CanvasItem, at: Vector2, dir: Vector2, stage: int, art: float, clock: float) -> void:
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	var n := d.orthogonal()
	if n.y > 0.0:
		n = -n
	var gold: Array = Pal.ramp("gold")
	var steel: Array = Pal.ramp("steel")
	var blood: Array = Pal.ramp("blood")
	var frame := int(clock * PixelPaint.FPS)
	var trail := {}
	var length := 28 if stage == 0 else 42
	for i in range(length):
		var k := 1.0 - float(i) / float(length)
		var base := at - d * float(12 + i) * art
		var q := PixelPaint.at(base, art)
		if PixelPaint.shown(q, k):
			trail[q] = gold[3] if i < 6 else gold[2]
		var side := PixelPaint.at(base + n * art * (1.0 if posmod(i + frame, 2) == 0 else -1.0), art)
		if PixelPaint.shown(side, k * 0.5):
			trail[side] = gold[2] if stage == 0 else blood[3]
	_flush_under(canvas, trail, art)
	var cells := {}
	var at_cell := func(i: float, j: float) -> Vector2i: return PixelPaint.at(at + d * i * art + n * j * art, art)
	for i in range(-11, -6):
		var spread := 3 if i <= -10 else (2 if i <= -8 else 1)
		for j in range(1, spread + 1):
			cells[at_cell.call(float(i), float(j))] = blood[3] if stage >= 1 else gold[3]
			cells[at_cell.call(float(i), float(-j))] = blood[2] if stage >= 1 else gold[2]
		cells[at_cell.call(float(i), 0.0)] = gold[1]
	for i in range(-8, 5):
		cells[at_cell.call(float(i), 0.0)] = blood[3] if stage >= 1 and posmod(i + frame, 4) == 0 else gold[2]
		cells[at_cell.call(float(i), 1.0)] = gold[3]
	var widths := {5: 3, 6: 3, 7: 2, 8: 2, 9: 1, 10: 1, 11: 0}
	for i: int in widths:
		var w: int = widths[i]
		for j in range(-w, w + 1):
			cells[at_cell.call(float(i), float(j))] = steel[3] if j > 0 else (steel[4] if i == 11 else (steel[3] if j == 0 else steel[2]))
	_flush(canvas, cells, art)


## Spirit wisps round a pack wolf of Alpharuf (`at` its ground point): pale
## motes rising and dissolving.
static func spirit(canvas: CanvasItem, at: Vector2, art: float, clock: float, seed: int) -> void:
	var sp: Array = Pal.ramp("spirit")
	var cells := {}
	for k in range(7):
		var ph := fposmod(clock * 0.7 + float(k) / 7.0 + 0.3 * _h(seed, k), 1.0)
		var x := (_h(seed, k + 10) - 0.5) * 20.0 + sin(clock * 2.0 + float(k)) * 2.0
		var q := PixelPaint.at(at + Vector2(x, -2.0 - ph * 24.0) * art, art)
		if not PixelPaint.shown(q, 1.0 - ph * 0.85):
			continue
		cells[q] = sp[4] if ph < 0.4 else sp[3]
		if ph < 0.75:
			cells[q + Vector2i(1, 0)] = sp[3]
			cells[q + Vector2i(0, 1)] = sp[3]
			cells[q + Vector2i(1, 1)] = sp[2]
		if ph < 0.4:
			cells[q + Vector2i(0, 2)] = sp[2]
	_flush_under(canvas, cells, art)


# ---------- helpers ----------

## A deterministic 0..1 from a seed and an index.
static func _h(seed: int, k: int) -> float:
	var x := sin(float(seed) * 12.9898 + float(k) * 78.233) * 43758.5453
	return x - floorf(x)


static func _out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


## Ease out with an overshoot (a pop that settles).
static func _back(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)


## 0..1 as `p` runs from `a` to `b`.
static func _span(p: float, a: float, b: float) -> float:
	return clampf((p - a) / maxf(0.0001, b - a), 0.0, 1.0)


## How much of a lasting effect shows: in over 0.3 s, out over the last 0.6 s.
static func _life_cover(left: float, total: float) -> float:
	return clampf((total - left) / 0.3, 0.0, 1.0) * clampf(left / 0.6, 0.0, 1.0)


## A point of the shield dome's upper silhouette (src/vfx/talent_dome.gd)
## standing on `foot`: `s` 0..1 along its length (equal steps), 0 at its right
## foot, 0.5 at the top, 1 at its left foot.
static func _dome_point(foot: Vector2, s: float, art: float) -> Vector2:
	if _dome_lengths.is_empty():
		var lengths := PackedFloat32Array([0.0])
		var prev := Vector2(DOME_W, 0.0)
		for i in range(1, 129):
			var a := PI * float(i) / 128.0
			var point := Vector2(cos(a) * DOME_W, -sin(a) * DOME_H)
			lengths.append(lengths[i - 1] + point.distance_to(prev))
			prev = point
		_dome_lengths = lengths
	var target := clampf(s, 0.0, 1.0) * _dome_lengths[128]
	var i := clampi(_dome_lengths.bsearch(target), 1, 128)
	var f := (target - _dome_lengths[i - 1]) / maxf(0.0001, _dome_lengths[i] - _dome_lengths[i - 1])
	var t := PI * (float(i - 1) + f) / 128.0
	return foot + Vector2(cos(t) * DOME_W, -sin(t) * DOME_H) * art


## True when `p` lies in the triangle a, b, c.
static func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p - b).cross(a - b)
	var d2 := (p - c).cross(b - c)
	var d3 := (p - a).cross(c - a)
	return not ((d1 < 0.0 or d2 < 0.0 or d3 < 0.0) and (d1 > 0.0 or d2 > 0.0 or d3 > 0.0))


## The cells the hero's figure covers (chest at at+body): floor parts leave them free.
static func _hole(at: Vector2, body: Vector2, art: float) -> Rect2i:
	var c := PixelPaint.at(at + body, art)
	return Rect2i(c.x - 8, c.y - 15, 17, 30)


static func _paint(canvas: CanvasItem, cells: Dictionary, art: float) -> void:
	PixelPaint.paint(canvas, cells, art)


## Draws `cells` (Vector2i -> Color) with a Pal.INK outline round them (or
## plain without); no outline cells inside `hole`.
static func _flush(canvas: CanvasItem, cells: Dictionary, art: float, outline := true, hole := Rect2i()) -> void:
	if outline:
		var ink := {}
		var holed := hole.has_area()
		for q: Vector2i in cells:
			var n := q + Vector2i(1, 0)
			if not cells.has(n) and not (holed and hole.has_point(n)): ink[n] = Pal.INK
			n = q + Vector2i(-1, 0)
			if not cells.has(n) and not (holed and hole.has_point(n)): ink[n] = Pal.INK
			n = q + Vector2i(0, 1)
			if not cells.has(n) and not (holed and hole.has_point(n)): ink[n] = Pal.INK
			n = q + Vector2i(0, -1)
			if not cells.has(n) and not (holed and hole.has_point(n)): ink[n] = Pal.INK
		PixelPaint.paint(canvas, ink, art)
	PixelPaint.paint(canvas, cells, art)


## Thin lines and dots: a dark underlay one cell lower instead of an outline.
static func _flush_under(canvas: CanvasItem, cells: Dictionary, art: float) -> void:
	var ink := {}
	for q: Vector2i in cells:
		var n := q + Vector2i(0, 1)
		if not cells.has(n):
			ink[n] = Pal.INK
	PixelPaint.paint(canvas, ink, art)
	PixelPaint.paint(canvas, cells, art)


## Draws ramp ranks (Vector2i -> 0..4) with their ramp colours.
static func _flush_ramp(canvas: CanvasItem, ranks: Dictionary, ramp: Array, art: float, outline := true, hole := Rect2i()) -> void:
	var cells := {}
	for q: Vector2i in ranks:
		cells[q] = ramp[int(ranks[q])]
	_flush(canvas, cells, art, outline, hole)


## A flame tongue into `ranks` (the brighter rank wins where flames overlap):
## its base centred on cell `b`, `half` cells wide at the base, `h` tall,
## swaying and flickering with `clock`; inside `hole` shown at `hole_cover`.
static func _flame(ranks: Dictionary, b: Vector2i, half: float, h: float, clock: float, seed: int, cover := 1.0, hole := Rect2i(), hole_cover := 1.0) -> void:
	if h < 1.0 or half < 0.5:
		return
	var frame := int(clock * PixelPaint.FPS)
	var bayer: Array = PixelPaint.BAYER
	var holed := hole.has_area()
	for j in range(int(ceilf(h)) + 1):
		var v := float(j) / h
		var w := half * pow(maxf(0.0, 1.0 - v), 0.65) * (1.0 + 0.14 * sin(v * 8.0 + float(frame) * 1.3 + float(seed)))
		var sway := sin(v * 3.0 + float(frame) * 0.8 + float(seed) * 1.7) * 1.8 * v
		for x in range(roundi(sway - w), roundi(sway + w) + 1):
			var q := b + Vector2i(x, -j)
			var k := cover
			if holed and hole.has_point(q):
				# sparse over the hero, thickening towards the hole's edge (no hard box)
				var rel := (Vector2(q) - Vector2(hole.get_center())) / (Vector2(hole.size) * 0.5)
				k *= lerpf(hole_cover, 1.0, smoothstep(0.55, 1.0, maxf(absf(rel.x), absf(rel.y) * 0.8)))
			# the dither inline (PixelPaint.shown)
			if k < 1.0 and not (float(bayer[((q.y & 3) << 2) | (q.x & 3)]) < k * 16.0):
				continue
			var u := absf(float(x) - sway) / maxf(0.5, w + 0.5)
			var rank := 2
			if u > 0.72 or v > 0.86:
				rank = 1
			elif u < 0.38 and v < 0.7:
				rank = 3
				if v < 0.25 and u < 0.2 and _h(seed + frame, x * 7 + j) < 0.3:
					rank = 4
			if int(ranks.get(q, -1)) < rank:
				ranks[q] = rank


## An ellipse arc (radii in world px) of cells into `cells`: from `a0` over
## `length` radians, every cell at dither `cover`, dashes when `gap` > 0
## (`gap`-1 on, 1 off, crawling with `phase`), never inside `hole`.
static func _oval(cells: Dictionary, c: Vector2, rx: float, ry: float, a0: float, length: float, col: Color, art: float, cover := 1.0, gap := 0, phase := 0, hole := Rect2i()) -> void:
	if rx < art or ry < art or absf(length) < 0.001 or cover <= 0.0:
		return
	var n := maxi(6, int(absf(length) * maxf(rx, ry) / art))
	var last := Vector2i(1 << 30, 0)
	for k in range(n + 1):
		if gap > 0 and posmod(k - phase, gap) == gap - 1:
			continue
		var a := a0 + length * float(k) / float(n)
		var q := PixelPaint.at(c + Vector2(cos(a) * rx, sin(a) * ry), art)
		if q == last or hole.has_point(q):
			continue
		last = q
		if cover < 1.0 and not PixelPaint.shown(q, cover):
			continue
		cells[q] = col


## A filled ellipse (radii in world px) of cells at dither `cover`.
static func _oval_fill(cells: Dictionary, c: Vector2, rx: float, ry: float, col: Color, art: float, cover: float) -> void:
	if rx < art * 0.5 or ry < art * 0.5 or cover <= 0.0:
		return
	var lo := PixelPaint.at(c - Vector2(rx, ry), art)
	var hi := PixelPaint.at(c + Vector2(rx, ry), art)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var q := Vector2i(x, y)
			var d := (Vector2(q) + Vector2(0.5, 0.5)) * art - c
			if (d.x / rx) * (d.x / rx) + (d.y / ry) * (d.y / ry) > 1.0:
				continue
			if cover < 1.0 and not PixelPaint.shown(q, cover):
				continue
			cells[q] = col


## Cells along the segment a→b (world px), dashed like _oval.
static func _seg(cells: Dictionary, a: Vector2, b: Vector2, col: Color, art: float, cover := 1.0, gap := 0, phase := 0, hole := Rect2i()) -> void:
	var qa := PixelPaint.at(a, art)
	var qb := PixelPaint.at(b, art)
	var n := maxi(absi(qb.x - qa.x), absi(qb.y - qa.y))
	for i in range(n + 1):
		if gap > 0 and posmod(i - phase, gap) == gap - 1:
			continue
		var t := float(i) / float(maxi(1, n))
		var q := Vector2i(roundi(lerpf(float(qa.x), float(qb.x), t)), roundi(lerpf(float(qa.y), float(qb.y), t)))
		if hole.has_point(q) or (cover < 1.0 and not PixelPaint.shown(q, cover)):
			continue
		cells[q] = col


## A filled disc (radius world px) of cells at dither `cover`, never inside `hole`.
static func _disc(cells: Dictionary, c: Vector2, rad: float, col: Color, art: float, cover: float, hole := Rect2i()) -> void:
	if rad < art * 0.5 or cover <= 0.0:
		return
	var lo := PixelPaint.at(c - Vector2(rad, rad), art)
	var hi := PixelPaint.at(c + Vector2(rad, rad), art)
	# the dither asked first (cheap, most cells of a faint disc stop there)
	var all := cover >= 1.0
	var thr := cover * 16.0
	var bayer: Array = PixelPaint.BAYER
	var holed := hole.has_area()
	var rr := rad * rad
	for y in range(lo.y, hi.y + 1):
		var row := (y & 3) << 2
		for x in range(lo.x, hi.x + 1):
			if not all and not (float(bayer[row | (x & 3)]) < thr):
				continue
			var q := Vector2i(x, y)
			if ((Vector2(q) + Vector2(0.5, 0.5)) * art - c).length_squared() > rr or (holed and hole.has_point(q)):
				continue
			cells[q] = col


## A one-colour pattern ("x" filled), its top-left at `q0`.
static func _glyph_fill(cells: Dictionary, rows: Array, q0: Vector2i, col: Color, cover := 1.0) -> void:
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var q := q0 + Vector2i(x, y)
			if row[x] == "x" and (cover >= 1.0 or PixelPaint.shown(q, cover)):
				cells[q] = col


## `count` runes on a ring of `rad` world px round `c`, turned by `turn`.
static func _rune_ring(cells: Dictionary, c: Vector2, rad: float, count: int, turn: float, col: Color, art: float, cover: float, hole := Rect2i()) -> void:
	for i in range(count):
		var q := PixelPaint.at(c + Vector2.from_angle(TAU * float(i) / float(count) + turn) * rad, art) - Vector2i(1, 1)
		if hole.size.x > 0 and hole.intersects(Rect2i(q, Vector2i(3, 3))):
			continue
		_glyph_fill(cells, RUNES[i % RUNES.size()], q, col, cover)


## A hex plate (8 cells) centred on cell `q`: lit upper left, shaded lower
## right (`flip` swaps them: a tumbling plate), all bright when it `flash`es;
## `rivet` 1 a steel rivet, 2 a flashing one.
static func _plate(cells: Dictionary, q: Vector2i, gold: Array, steel: Array, flip: bool, flash: bool, rivet: int, cover: float) -> void:
	for y in range(8):
		var row: String = HEX[y]
		for x in range(8):
			if row[x] != "x":
				continue
			var c := q + Vector2i(x - 4, y - 4)
			if cover < 1.0 and not PixelPaint.shown(c, cover):
				continue
			var s := x + y
			if flip:
				s = 14 - s
			var col: Color = gold[2]
			if flash:
				col = gold[4] if s <= 7 else gold[3]
			elif s <= 5:
				col = gold[3]
			elif s >= 10:
				col = gold[1]
			cells[c] = col
	if rivet > 0 and cells.has(q + Vector2i(-1, -1)):
		cells[q + Vector2i(-1, -1)] = steel[4] if rivet == 2 else steel[3]
		cells[q] = steel[1]


## A small spray of `rad` art cells round `c` (cast sparks), thinning at `cover`.
static func _burst_sparks(canvas: CanvasItem, c: Vector2, rad: float, cover: float, ramp: Array, art: float, seed: int) -> void:
	var cells := {}
	for i in range(10):
		var dir := Vector2.from_angle(TAU * (float(i) + _h(seed, i)) / 10.0)
		for j in range(2):
			var q := PixelPaint.at(c + dir * (rad - float(j) * 1.5) * art, art)
			if PixelPaint.shown(q, cover):
				cells[q] = ramp[4] if j == 0 and i % 3 == 0 else ramp[3]
	_flush_under(canvas, cells, art)
