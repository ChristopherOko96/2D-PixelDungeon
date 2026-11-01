extends RefCounted
## Drawing on the art grid for warnings and effects, at any art pixel size
## (`art` world px per art pixel: the crypt 2, the story worlds 3): every
## shape is whole art pixels, opaque, fading or filling by a 4x4 ordered
## dither instead of transparency, rims as crawling dashes over a dark
## underlay one pixel lower (so they read on any floor). The crypt's boss
## warnings (src/vfx/boss_fx.gd) and the story worlds share it; the look is
## the Frostgruft's and the Hell's telegraphs (src/hell/frost_fx.gd).
##
## The drawing lives in MatterKit (src/physics_kit/matter_kit.gd), which takes
## its wall clip as an argument. This file keeps the old API for its consumers:
## each function forwards to MatterKit with the clip set here (PixelPaint.clip).
## New code calls MatterKit with a MatterKit.Clip of its own instead.

## 4x4 ordered dither thresholds (0..15): MatterKit.BAYER.
const BAYER := MatterKit.BAYER
## Frames per second of crawling rims and blinks: MatterKit.FPS.
const FPS := MatterKit.FPS
## A drawing target that records cells for bake(): MatterKit.Recorder.
const Recorder := MatterKit.Recorder
## Where pixels may show: Callable(world point) -> bool (false inside walls),
## set by the host around effects that must not shine through walls (the
## heroes' shots, floor warnings) and cleared after; empty draws everywhere.
## The legacy entry point: every Callable set here gets one MatterKit.Clip of
## its own (current()), which remembers its answers per art cell.
static var clip := Callable()
## Callable -> its MatterKit.Clip (at most physics_matter.json clip.cache_max).
static var _clips: Dictionary = {}
## The last clip looked up, for the next lookup of the same Callable.
static var _last_of := Callable()
static var _last: MatterKit.Clip = null


## The MatterKit.Clip of the Callable set as `clip` now (null without one).
static func current() -> MatterKit.Clip:
	if not clip.is_valid():
		return null
	if _last != null and clip == _last_of:
		return _last
	var found: Variant = _clips.get(clip)
	if found == null:
		if _clips.size() >= int((MatterKit.settings().get("clip", {}) as Dictionary).get("cache_max", 16)):
			_clips.clear()
		found = MatterKit.clip_of(clip)
		_clips[clip] = found
	_last_of = clip
	_last = found
	return _last


## Drops every clip kept for the Callables set as `clip` (and the clip set now).
## Hosts that set a lambda (not a bound method) as `clip` call it when they are
## done: a lambda kept in a static past its script's end crashes the engine at exit.
static func forget_clips() -> void:
	clip = Callable()
	_clips.clear()
	_last_of = Callable()
	_last = null


## True when art cell `q` shows at coverage `k` (0..1).
static func shown(q: Vector2i, k: float) -> bool:
	return MatterKit.shown(q, k)


## Draws art cell `q` in `col`, unless `clip` hides it.
static func cell(canvas: Object, q: Vector2i, col: Color, art: float) -> void:
	MatterKit.cell(canvas, q, col, art, current())


## True when `clip` lets art cell `q` show (always without a clip), remembered.
static func open_cell(q: Vector2i, art: float) -> bool:
	var c := current()
	return c == null or c.open_cell(q, art)


## What `clip` said per art cell (Vector3i(x, y, art) -> open), started afresh
## when the walls may have changed and when full. For loops over many cells
## that ask it themselves (talent_pixels.gd); empty without a clip.
static func clip_memo() -> Dictionary:
	var c := current()
	return c.memo() if c != null else {}


## Draws a map of art cells (Vector2i -> Color) as cell() would, cut by `clip`.
static func paint(canvas: Object, cells: Dictionary, art: float) -> void:
	MatterKit.paint(canvas, cells, art, current())


## A list of opaque cells and colours as one picture (MatterKit.bake), cut by `clip` now.
static func bake(draw: Array, art: float) -> Dictionary:
	return MatterKit.bake(draw, art, current())


## Draws a picture from bake().
static func draw_baked(canvas: CanvasItem, baked: Dictionary, art: float) -> void:
	MatterKit.draw_baked(canvas, baked, art)


## The art cell holding world point `p`.
static func at(p: Vector2, art: float) -> Vector2i:
	return MatterKit.at(p, art)


## An ellipse rim of whole pixels; every `every`-th pixel (crawling with `phase`).
static func ellipse(canvas: Object, c: Vector2, rx: float, ry: float, col: Color, art: float, every := 1, phase := 0) -> void:
	MatterKit.ellipse(canvas, c, rx, ry, col, art, every, phase, current())


## A filled ellipse of whole pixels at dither coverage `cover`.
static func disc(canvas: Object, c: Vector2, rx: float, ry: float, col: Color, art: float, cover := 1.0) -> void:
	MatterKit.disc(canvas, c, rx, ry, col, art, cover, current())


## A warning on the floor that strikes when `k` reaches 1 (MatterKit.warning).
static func warning(canvas: Object, c: Vector2, rx: float, ry: float, k: float, col: Color, ink: Color, art: float, t: float) -> void:
	MatterKit.warning(canvas, c, rx, ry, k, col, ink, art, t, current())


## The moment a warning strikes (MatterKit.burst).
static func burst(canvas: CanvasItem, c: Vector2, rx: float, ry: float, k: float, col: Color, art: float) -> void:
	MatterKit.burst(canvas, c, rx, ry, k, col, art, current())


## A lane warning from `from` to `to` (MatterKit.lane).
static func lane(canvas: CanvasItem, from: Vector2, to: Vector2, half: float, k: float, col: Color, ink: Color, art: float, t: float) -> void:
	MatterKit.lane(canvas, from, to, half, k, col, ink, art, t, current())


## A cone warning from `from` (MatterKit.cone).
static func cone(canvas: CanvasItem, from: Vector2, r: float, ang: float, arc: float, k: float, col: Color, ink: Color, art: float, t: float) -> void:
	MatterKit.cone(canvas, from, r, ang, arc, k, col, ink, art, t, current())


## A ball of the ramp `cols` with an outline `ink` (MatterKit.ball).
static func ball(canvas: CanvasItem, p: Vector2, r: int, cols: Array, ink: Color, art: float) -> void:
	MatterKit.ball(canvas, p, r, cols, ink, art, current())
