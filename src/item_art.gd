@tool
extends RefCounted
## Native 16px regions from the user's original item/animation sheets, and the
## items' Elementsprache in pixels (user wish 2026-10-31: every item effect
## pixelated but physical): an element's colour ramp and its motes - sparks
## that rise and cool (fire), drops that form and fall (poison, blood), shards
## that glint (ice), zaps that blink (lightning), motes that circle (void,
## soul), dust that lifts (bone) - drawn as whole art pixels over an ink
## underlay, time-based and deterministic from a seed (no state, no per-frame
## allocations), round an inventory icon (src/ui/inventory_panel.gd) or along
## a held weapon (src/hero/hero_look.gd). Which element an item has and how
## its motes move is data (assets/data/items.json elements: ramp, glow, motes).

const ItemRules = preload("res://src/items/item_rules.gd")
const TalentPalette = preload("res://src/vfx/talent_palette.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")

const ITEMS: Texture2D = preload("res://assets/items/item_sheet_items.png")
const ANIMATIONS: Texture2D = preload("res://assets/items/animation_sheet_items.png")
const CHEST_OPEN_REGION := Rect2(64, 16, 16, 16)
const CLOSED_DOOR_REGION := Rect2(32, 0, 16, 16)
const PERK_REGIONS := {
	"ember": Rect2(0, 48, 16, 16),
	"shadow": Rect2(32, 64, 16, 16),
	"heart": Rect2(16, 80, 16, 16),
	"quick": Rect2(64, 48, 16, 16),
	"mend": Rect2(80, 48, 16, 16)
}
## The dark outline under every mote (the 0x72 ink, as src/vfx/talent_palette.gd).
const INK := Color("1a1414")
## Beats per second of blinking and glinting motes (src/vfx/pixel_paint.gd FPS).
const FPS := 12.0
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Ramps built once for elements the palette has no ramp for (see ramp()).
static var _ramps: Dictionary = {}

## Stable icons for the five existing perks; unknown IDs use the scroll icon.
static func perk_icon_rect(perk_id: String) -> Rect2:
	return PERK_REGIONS.get(perk_id, Rect2(80, 80, 16, 16))


## Three original flame-and-urn frames, sampled at 8 FPS without interpolation.
static func fire_frame(time: float) -> Rect2:
	return Rect2(16 + posmod(int(time * 8.0), 3) * 16, 48, 16, 16)


## Three native impact cloud frames; the renderer calls this only on a hit.
static func impact_frame(time: float) -> Rect2:
	return Rect2(64 + posmod(int(time * 18.0), 3) * 16, 32, 16, 16)


## Original golden spark frames for the brief stun indicator.
static func stun_frame(time: float) -> Rect2:
	return Rect2(posmod(int(time * 12.0), 4) * 16, 64, 16, 16)


# --- the elements in pixels -----------------------------------------------------------

## The five colours (deep, shade, body, lite, spec) `element` is drawn in: its
## palette ramp (items.json elements.ramp -> src/vfx/talent_palette.gd RAMPS)
## when the palette has it, else a ramp built once round the element's glow
## colour (items.json elements.glow); steel for an unknown element.
static func ramp(element: String) -> Array:
	var info := ItemRules.element_info(element)
	var name := str(info.get("ramp", element))
	if TalentPalette.RAMPS.has(name): return TalentPalette.RAMPS[name]
	if _ramps.has(element): return _ramps[element]
	var glow_hex := str(info.get("glow", ""))
	if glow_hex.is_empty(): return TalentPalette.ramp("steel")
	var lite := Color(glow_hex)
	_ramps[element] = [lite.darkened(0.72), lite.darkened(0.5), lite.darkened(0.22), lite, lite.lightened(0.45)]
	return _ramps[element]


## The glow colour of `element` (its lite tone), or `fallback` for none.
static func glow(element: String, fallback: Color = Color(1, 0.95, 0.8)) -> Color:
	if element.is_empty() or ItemRules.element_info(element).is_empty(): return fallback
	return ramp(element)[3]


## A deterministic 0..1 value for (`seed`, `k`) (as src/vfx/talent_pixels.gd).
static func rnd(seed: int, k: int) -> float:
	var h := seed * 374761393 + k * 668265263 + 1013904223
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


## A glow frame of `element` on the rim of `rect` (canvas px, whole art pixels):
## the element's shade colour breathing by the dither, a lit pixel every fourth
## cell crawling round, ink under the bottom row. Subtle: it sits inside the
## rarity frame and tells the element at a glance.
static func draw_frame(canvas: Object, rect: Rect2, element: String, time: float, art: float) -> void:
	if ItemRules.element_info(element).is_empty(): return
	var cols := ramp(element)
	var lo := Vector2i((rect.position / art).floor())
	var hi := Vector2i((rect.end / art).ceil()) - Vector2i.ONE
	var breath := 0.4 + 0.2 * sin(time * 2.2)
	var crawl := int(floorf(time * FPS * 0.5))
	var step := -crawl
	# round the rim clockwise from the top-left corner
	for x in range(lo.x, hi.x + 1):
		_rim(canvas, Vector2i(x, lo.y), step, cols, breath, art, false)
		step += 1
	for y in range(lo.y + 1, hi.y + 1):
		_rim(canvas, Vector2i(hi.x, y), step, cols, breath, art, false)
		step += 1
	for x in range(hi.x - 1, lo.x - 1, -1):
		_rim(canvas, Vector2i(x, hi.y), step, cols, breath, art, true)
		step += 1
	for y in range(hi.y - 1, lo.y, -1):
		_rim(canvas, Vector2i(lo.x, y), step, cols, breath, art, false)
		step += 1


## `count` motes of `element` drifting over `rect` (canvas px) on the `art`
## grid at `time` s, their paths fixed by `seed` (the item's uid); `cover`
## thins them by the dither. For identified items only (the caller decides).
static func draw_motes(canvas: Object, rect: Rect2, element: String, time: float, art: float, seed: int, count: int = 4, cover: float = 1.0) -> void:
	var info := ItemRules.element_info(element)
	if info.is_empty(): return
	var cols := ramp(element)
	var kind := str(info.get("motes", "dust"))
	var frame := int(floorf(time * FPS))
	var lo := Vector2i((rect.position / art).floor())
	var hi := Vector2i((rect.end / art).floor()) - Vector2i.ONE
	var w := maxi(1, hi.x - lo.x)
	var h := maxi(1, hi.y - lo.y)
	for k in range(count):
		var r0 := rnd(seed, k * 3)
		var r1 := rnd(seed, k * 3 + 1)
		var r2 := rnd(seed, k * 3 + 2)
		# 0..1 of this mote's own cycle (periods differ, so they never march in step)
		var t := fmod(time / (1.1 + r2 * 1.1) + r1, 1.0)
		var x := lo.x + int(r0 * float(w))
		match kind:
			"sparks": _spark(canvas, Vector2i(x, hi.y), h, t, k, cols, art, cover)
			"drops": _drop(canvas, Vector2i(x, lo.y), hi.y, t, cols, art, cover)
			"shards": _shard(canvas, Vector2i(x, lo.y + int(r1 * float(h))), frame + int(r2 * 24.0), k, cols, art, cover)
			"zaps": _zap(canvas, Vector2i(x, lo.y + int(r1 * float(h))), frame + int(r2 * 18.0), k, cols, art, cover)
			"orbit": _orbit(canvas, rect.get_center(), rect.size * Vector2(0.46, 0.36), time * (0.8 + r2 * 0.6) * (1.0 if k % 2 == 0 else -1.0) + r0 * TAU, frame + k, cols, art, cover)
			_: _dust(canvas, Vector2i(x, hi.y), h, t, cols, art, cover)


## Motes of `element` leaving a held weapon: born along the `length` world px
## behind `tip` (toward -`along`), each a short burst every second or two,
## never a steady stream; `seed` per hero, `art` the world's art pixel.
static func draw_weapon_motes(canvas: Object, tip: Vector2, along: Vector2, length: float, element: String, time: float, art: float, seed: int, count: int = 3) -> void:
	var info := ItemRules.element_info(element)
	if info.is_empty(): return
	var cols := ramp(element)
	var kind := str(info.get("motes", "dust"))
	var frame := int(floorf(time * FPS))
	var rise := maxi(3, int(length / art * 0.6))
	for k in range(count):
		var r0 := rnd(seed, k * 3)
		var r1 := rnd(seed, k * 3 + 1)
		var r2 := rnd(seed, k * 3 + 2)
		# a mote shows for the first 35 % of its own cycle (1.6..3 s), then rests
		var cycle := fmod(time / (1.6 + r2 * 1.4) + r1, 1.0)
		if cycle >= 0.35: continue
		var t := cycle / 0.35
		var q := Vector2i(((tip - along * (r0 * length)) / art).floor())
		match kind:
			"sparks": _spark(canvas, q, rise, t, k, cols, art, 1.0)
			"drops": _drop(canvas, q, q.y + rise, t, cols, art, 1.0)
			"shards": _shard(canvas, q, int(t * 24.0), k, cols, art, 1.0 - t)
			"zaps": _zap(canvas, q, int(t * 18.0), k, cols, art, 1.0)
			"orbit": _orbit(canvas, tip, Vector2(3.0, 2.0) * art, t * TAU * 1.5 + r0 * TAU, frame + k, cols, art, 1.0)
			_: _dust(canvas, q, rise, t, cols, art, 1.0)


## The weapon's glow colour at `at` (the shots' tint, src/vfx/attack_fx.gd): a
## lit core pixel with its four neighbours breathing by the dither.
static func draw_tip_glow(canvas: Object, at: Vector2, glow_col: Color, time: float, art: float) -> void:
	var q := Vector2i((at / art).floor())
	var breath := 0.35 + 0.3 * sin(time * 3.1)
	_cell(canvas, q, glow_col.lightened(0.25), art)
	for o: Vector2i in SIDES:
		if PixelPaint.shown(q + o, breath): _cell(canvas, q + o, glow_col, art)


static func _cell(canvas: Object, q: Vector2i, col: Color, art: float) -> void:
	canvas.draw_rect(Rect2(Vector2(q) * art, Vector2(art, art)), col)


## One rim pixel of draw_frame: lit every fourth `step`, else the shade colour
## shown by the dither at `breath`; ink below when asked.
static func _rim(canvas: Object, q: Vector2i, step: int, cols: Array, breath: float, art: float, ink_below: bool) -> void:
	var lit := posmod(step, 4) == 0
	if not lit and not PixelPaint.shown(q, breath): return
	if ink_below: _cell(canvas, q + Vector2i(0, 1), INK, art)
	_cell(canvas, q, cols[3] if lit else cols[1], art)


## An ember born at `foot` rising `height` cells over its life `t`: it sways,
## cools from spec to shade and thins out.
static func _spark(canvas: Object, foot: Vector2i, height: int, t: float, k: int, cols: Array, art: float, cover: float) -> void:
	var q := foot + Vector2i(int(round(sin(t * 7.0 + float(k) * 2.1) * 1.2)), -int(t * float(height)))
	if PixelPaint.shown(q, (1.0 - t) * cover):
		_cell(canvas, q, cols[4] if t < 0.15 else (cols[3] if t < 0.45 else (cols[2] if t < 0.75 else cols[1])), art)


## A drop forming at `top`, hanging a third of its life, then falling with a
## tail toward `floor_y` (no further); ink under its head.
static func _drop(canvas: Object, top: Vector2i, floor_y: int, t: float, cols: Array, art: float, cover: float) -> void:
	var fall := maxf(0.0, t - 0.35) / 0.65
	var q := top + Vector2i(0, int(fall * fall * float(floor_y - top.y)))
	if q.y > floor_y or not PixelPaint.shown(q, cover): return
	_cell(canvas, q + Vector2i(0, 1), INK, art)
	_cell(canvas, q, cols[3] if fall < 0.5 else cols[2], art)
	if fall > 0.2: _cell(canvas, q - Vector2i(0, 1), cols[2], art)


## A frost shard at `q` that glints for three beats in every 24: a cross of
## light, else a cold pixel over ink.
static func _shard(canvas: Object, q: Vector2i, beat: int, k: int, cols: Array, art: float, cover: float) -> void:
	if not PixelPaint.shown(q, cover): return
	if posmod(beat, 24) < 3:
		_cell(canvas, q, cols[4], art)
		for o: Vector2i in SIDES: _cell(canvas, q + o, cols[3], art)
	else:
		_cell(canvas, q + Vector2i(0, 1), INK, art)
		_cell(canvas, q, cols[3] if posmod(beat / 6 + k, 2) == 0 else cols[2], art)


## A zap at `q`: three pixels of a jagged bolt, on for two beats in every 18.
static func _zap(canvas: Object, q: Vector2i, beat: int, k: int, cols: Array, art: float, cover: float) -> void:
	if posmod(beat, 18) >= 2 or not PixelPaint.shown(q, cover): return
	var side := 1 if k % 2 == 0 else -1
	_cell(canvas, q, cols[4], art)
	_cell(canvas, q + Vector2i(side, 1), cols[3], art)
	_cell(canvas, q + Vector2i(0, 2), cols[3], art)


## A mote on an ellipse (`radii`) round `c` at angle `a`, bright in front and
## dim behind, dark for one beat in five.
static func _orbit(canvas: Object, c: Vector2, radii: Vector2, a: float, beat: int, cols: Array, art: float, cover: float) -> void:
	var q := Vector2i(((c + Vector2(cos(a) * radii.x, sin(a) * radii.y)) / art).floor())
	if posmod(beat, 5) == 0 or not PixelPaint.shown(q, cover): return
	_cell(canvas, q, cols[4] if sin(a) > 0.3 else (cols[3] if sin(a) > -0.3 else cols[2]), art)


## Dust lifting slowly from `foot` and thinning out.
static func _dust(canvas: Object, foot: Vector2i, height: int, t: float, cols: Array, art: float, cover: float) -> void:
	var q := foot - Vector2i(0, int(t * float(height) * 0.7))
	if PixelPaint.shown(q, (1.0 - t) * 0.7 * cover):
		_cell(canvas, q, cols[2] if t < 0.5 else cols[1], art)
