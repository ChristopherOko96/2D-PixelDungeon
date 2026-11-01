extends SceneTree
## The pixel-grid kit (src/physics_kit/matter_kit.gd, MatterKit; BAUPLAN M1a)
## with fake hosts and fake walls, no game:
## - units: crypt and story art pixels from physics_matter.json, the crypt
##   scale, world px <-> crypt units, the art cell of a point;
## - the 4x4 ordered dither: the classic thresholds, coverage 0 and 1, half
##   the cells at 0.5, the same for negative cells as the old posmod lookups;
## - hashes and noise: the old copies' formulas (splat_shape, pool_paint,
##   gas, particles) give the same numbers, ranges, tiling;
## - the wall clip: asked once per art cell, forgotten when the host's
##   wall_revision changes, the bare Callable form, forget();
## - shapes cut by the clip; PixelPaint (the forwarder) draws the same cells
##   as MatterKit with an explicit clip and leaves no clip behind;
## - the splat flood: deterministic, its volume, stopped by walls (no leak
##   through a diagonal seam), the nearest open cell, SplatShape forwards.
## Deterministic; reads only res:// data, writes nothing.

const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const SplatShape = preload("res://src/vfx/splat_shape.gd")
const DATA := "res://assets/data/physics_matter.json"
var checked := 0
var failures: Array[String] = []


## A host whose walls are the cells x >= `wall_x` (world px), counting how often it is asked.
class FakeHost extends "res://src/physics_kit/matter_host.gd":
	var wall_x := 30.0
	var asked := 0
	var rev := 0

	func is_open(world_point: Vector2) -> bool:
		asked += 1
		return world_point.x < wall_x

	func wall_revision() -> int:
		return rev


## A canvas that records what is drawn on it (draw_rect only).
class Canvas extends RefCounted:
	var rects: Array = []

	func draw_rect(rect: Rect2, color: Color, _filled := true, _width := -1.0, _antialiased := false) -> void:
		rects.append([rect, color])


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("MATTER_KIT_FAIL: ", label)


func _initialize() -> void:
	test_units()
	test_dither()
	test_hashes_and_noise()
	test_clip()
	test_shapes()
	test_pixel_paint_forwards()
	test_flood()
	print("MATTER_KIT checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return parsed if parsed is Dictionary else {}


func test_units() -> void:
	var units: Dictionary = _data().get("units", {})
	check(not units.is_empty(), "physics_matter.json has its units")
	check(is_equal_approx(MatterKit.crypt_art(), float(units.crypt_art_px)), "crypt art px from the data")
	check(is_equal_approx(MatterKit.story_art(), float(units.story_art_px)), "story art px from the data")
	var s := MatterKit.crypt_scale(MatterKit.story_art())
	check(is_equal_approx(s, float(units.story_art_px) / float(units.crypt_art_px)), "a story world px is story/crypt crypt px")
	check(is_equal_approx(MatterKit.crypt_scale(MatterKit.crypt_art()), 1.0), "the crypt's own scale is 1")
	var p := Vector2(30.0, -15.0)
	var c: Vector2 = MatterKit.to_crypt(p, MatterKit.story_art())
	check(c.is_equal_approx(p / s), "world px -> crypt units divides by the scale")
	check((MatterKit.from_crypt(c, MatterKit.story_art()) as Vector2).is_equal_approx(p), "crypt units -> world px round trip")
	check(is_equal_approx(float(MatterKit.to_crypt(9.0, MatterKit.story_art())), 9.0 / s), "lengths convert too")
	check(MatterKit.at(Vector2(-0.5, 5.9), 3.0) == Vector2i(-1, 1), "the art cell of a point floors (negative too)")
	check(MatterKit.cell_centre(Vector2i(-1, 1), 3.0).is_equal_approx(Vector2(-1.5, 4.5)), "the middle of an art cell")


func test_dither() -> void:
	var classic := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	check(MatterKit.BAYER == classic, "the 4x4 Bayer thresholds")
	check(PixelPaint.BAYER == MatterKit.BAYER, "PixelPaint.BAYER is MatterKit's")
	var half := 0
	var none := 0
	var all := 0
	for y in range(4):
		for x in range(4):
			var q := Vector2i(x, y)
			half += 1 if MatterKit.shown(q, 0.5) else 0
			none += 1 if MatterKit.shown(q, 0.0) else 0
			all += 1 if MatterKit.shown(q, 1.0) else 0
	check(half == 8 and none == 0 and all == 16, "coverage 0 shows none, 1 all, 0.5 half of a tile")
	var same := true
	for y in range(-9, 9):
		for x in range(-9, 9):
			var old := float(classic[posmod(y, 4) * 4 + posmod(x, 4)])
			if MatterKit.bayer(Vector2i(x, y)) != old or MatterKit.bayer_xy(x, y) != old:
				same = false
			if MatterKit.shown(Vector2i(x, y), 0.37) != (old < 0.37 * 16.0):
				same = false
	check(same, "bayer/shown equal the old posmod lookups, negative cells too")


## The old hash every copy used.
static func _old_hash(x: int, y: int, s := 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) % 1000


## The old smooth noise (splat_shape.gd _noise with size 3, pool_paint.gd _noise).
static func _old_noise(x: int, y: int, size: int, s: int) -> float:
	var fx := float(x) / float(size)
	var fy := float(y) / float(size)
	var gx := floori(fx)
	var gy := floori(fy)
	var u := fx - float(gx)
	var v := fy - float(gy)
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var a := float(_old_hash(gx, gy, s)) / 1000.0
	var b := float(_old_hash(gx + 1, gy, s)) / 1000.0
	var c := float(_old_hash(gx, gy + 1, s)) / 1000.0
	var e := float(_old_hash(gx + 1, gy + 1, s)) / 1000.0
	return lerpf(lerpf(a, b, u), lerpf(c, e, u), v)


## The old particles.gd _cell_noise.
static func _old_cell_noise(q: Vector2i, seed: int) -> float:
	var h := (q.x * 374761393 + q.y * 668265263 + seed * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) % 1024) / 1024.0


func test_hashes_and_noise() -> void:
	var same_hash := true
	var in_range := true
	var same_noise := true
	var noise_range := true
	var same_cell := true
	for y in range(-20, 20, 3):
		for x in range(-20, 20, 3):
			for s in [0, 5, 41, 997]:
				var h := MatterKit.hash3(x, y, s)
				same_hash = same_hash and h == _old_hash(x, y, s) and MatterKit.hash01(x, y, s) == float(h) / 1000.0
				in_range = in_range and h >= 0 and h < 1000
				for size in [2, 3, 5, 8]:
					var n := MatterKit.value_noise(x, y, size, s)
					same_noise = same_noise and n == _old_noise(x, y, size, s)
					noise_range = noise_range and n >= 0.0 and n <= 1.0
				var cn := MatterKit.cell_noise(Vector2i(x, y), s)
				same_cell = same_cell and cn == _old_cell_noise(Vector2i(x, y), s) and cn >= 0.0 and cn < 1.0
	check(same_hash, "hash3/hash01 are the old copies' hash")
	check(in_range, "hash3 is 0..999")
	check(same_noise, "value_noise is the old smooth noise (splat, pools, the monsters' 2 px noise)")
	check(noise_range, "value_noise stays in 0..1")
	check(same_cell, "cell_noise is the particles' old cell noise, 0..1")
	check(MatterKit.value_noise(9, 6, 3, 7) == float(_old_hash(3, 2, 7)) / 1000.0, "on a lattice point the noise is its hash")
	var tiles := true
	for y in range(0, 64, 5):
		for x in range(0, 64, 5):
			for size in [4, 8]:
				tiles = tiles and MatterKit.tiling_noise(x, y, size, 64) == MatterKit.tiling_noise(x + 64, y + 64, size, 64)
	check(tiles, "tiling_noise repeats every period (the gas churn)")


func test_clip() -> void:
	var host := FakeHost.new()
	var clip := MatterKit.clip_for(host)
	check(clip.open_cell(Vector2i(0, 0), 3.0), "an open cell shows")
	check(not clip.open_cell(Vector2i(20, 0), 3.0), "a wall cell does not")
	var asked := host.asked
	for i in range(5):
		clip.open_cell(Vector2i(0, 0), 3.0)
		clip.open_cell(Vector2i(20, 0), 3.0)
	check(host.asked == asked, "the clip asks the host once per art cell")
	check(clip.memo().has(Vector3i(0, 0, 3)), "remembered as Vector3i(x, y, art)")
	host.wall_x = 1000.0
	check(not clip.open_cell(Vector2i(20, 0), 3.0), "without a new wall_revision it keeps its answer")
	host.rev += 1
	check(clip.open_cell(Vector2i(20, 0), 3.0), "a new wall_revision makes it ask again (the wall broke)")
	clip.forget()
	check(clip.memo().is_empty(), "forget drops every answer")
	var by_callable := MatterKit.clip_of(func(p: Vector2) -> bool: return p.y < 10.0)
	check(by_callable.open_cell(Vector2i(0, 2), 3.0) and not by_callable.open_cell(Vector2i(0, 4), 3.0), "a clip from a bare Callable asks it at the cell's middle")
	check(by_callable.is_open(Vector2(0, 5)) and not by_callable.is_open(Vector2(0, 15)), "is_open asks now")
	var settings: Dictionary = _data().get("clip", {})
	check(by_callable.memo_max == int(settings.memo_max) and by_callable.refresh_ms == int(float(settings.refresh_s) * 1000.0), "the clip's limits come from physics_matter.json")
	var empty := MatterKit.clip_for(MatterKit.Host.new())
	check(empty.open_cell(Vector2i(-50, 99), 2.0), "the contract's defaults are open floor")


func test_shapes() -> void:
	var host := FakeHost.new()
	host.wall_x = 0.0
	var clip := MatterKit.clip_for(host)
	var free := Canvas.new()
	var cut := Canvas.new()
	MatterKit.disc(free, Vector2.ZERO, 30, 20, Color.RED, 3.0, 1.0)
	MatterKit.disc(cut, Vector2.ZERO, 30, 20, Color.RED, 3.0, 1.0, clip)
	check(free.rects.size() > 100, "a full disc fills its cells")
	var left := 0
	for r: Array in free.rects:
		if (r[0] as Rect2).get_center().x < 0.0:
			left += 1
	check(cut.rects.size() == left, "the clip cuts the disc at the wall exactly")
	var only_open := true
	for r: Array in cut.rects:
		only_open = only_open and (r[0] as Rect2).get_center().x < 0.0
	check(only_open, "nothing is drawn in the wall")
	var thin := Canvas.new()
	MatterKit.disc(thin, Vector2.ZERO, 30, 20, Color.RED, 3.0, 0.5)
	check(absi(thin.rects.size() * 2 - free.rects.size()) <= free.rects.size() / 8, "a disc at 0.5 coverage keeps about half its cells")
	var cells := {Vector2i(-2, 0): Color.RED, Vector2i(2, 0): Color.BLUE, Vector2i(-1, 1): Color.GREEN}
	var painted := Canvas.new()
	MatterKit.paint(painted, cells, 3.0, clip)
	check(painted.rects.size() == 2 and (painted.rects[0][1] as Color) == Color.RED and (painted.rects[1][1] as Color) == Color.GREEN, "paint keeps the map's order and cuts by the clip")
	var rec := MatterKit.Recorder.new()
	rec.art = 3.0
	MatterKit.cell(rec, Vector2i(-3, 4), Color.WHITE, 3.0, clip)
	MatterKit.cell(rec, Vector2i(3, 4), Color.WHITE, 3.0, clip)
	check(rec.cells.size() == 2 and rec.cells[0] == Vector2i(-3, 4), "the Recorder keeps the cells drawn on it")
	var baked := MatterKit.bake([Vector2i(-3, 4), Color.WHITE, Vector2i(-1, 6), Color.RED], 3.0)
	check(baked.get("at") == Vector2i(-3, 4) and baked.get("size") == Vector2i(3, 3), "bake spans the cells")
	check(MatterKit.bake([], 3.0).is_empty(), "nothing to bake: empty")
	var warn := Canvas.new()
	MatterKit.warning(warn, Vector2(-60, 0), 40, 30, 0.6, Color.RED, Color.BLACK, 3.0, 1.0, clip)
	var warn_open := not warn.rects.is_empty()
	for r: Array in warn.rects:
		warn_open = warn_open and (r[0] as Rect2).get_center().x < 0.0
	check(warn_open, "a warning reaching into the wall is cut by the clip")


func test_pixel_paint_forwards() -> void:
	var open := func(p: Vector2) -> bool: return p.x < 10.0
	var a := Canvas.new()
	var b := Canvas.new()
	PixelPaint.clip = open
	PixelPaint.warning(a, Vector2(0, 0), 50, 30, 0.7, Color.RED, Color.BLACK, 2.0, 0.4)
	PixelPaint.ellipse(a, Vector2(-10, 20), 40, 12, Color.BLUE, 2.0, 2, 1)
	PixelPaint.disc(a, Vector2(4, 4), 14, 9, Color.WHITE, 2.0, 0.6)
	PixelPaint.paint(a, {Vector2i(1, 9): Color.RED, Vector2i(9, 9): Color.GREEN}, 2.0)
	var memo := PixelPaint.clip_memo()
	check(not memo.is_empty() and memo == PixelPaint.clip_memo(), "PixelPaint.clip_memo is the memo of the clip set now")
	check(not PixelPaint.open_cell(Vector2i(10, 0), 2.0) and PixelPaint.open_cell(Vector2i(0, 0), 2.0), "PixelPaint.open_cell asks the clip set now")
	PixelPaint.clip = Callable()
	var clip := MatterKit.clip_of(open)
	MatterKit.warning(b, Vector2(0, 0), 50, 30, 0.7, Color.RED, Color.BLACK, 2.0, 0.4, clip)
	MatterKit.ellipse(b, Vector2(-10, 20), 40, 12, Color.BLUE, 2.0, 2, 1, clip)
	MatterKit.disc(b, Vector2(4, 4), 14, 9, Color.WHITE, 2.0, 0.6, clip)
	MatterKit.paint(b, {Vector2i(1, 9): Color.RED, Vector2i(9, 9): Color.GREEN}, 2.0, clip)
	check(a.rects == b.rects, "PixelPaint with PixelPaint.clip draws what MatterKit draws with the same clip")
	check(PixelPaint.current() == null and PixelPaint.open_cell(Vector2i(99, 0), 2.0) and PixelPaint.clip_memo().is_empty(), "without a clip PixelPaint draws everywhere")
	check(PixelPaint.at(Vector2(-1, 7), 2.0) == MatterKit.at(Vector2(-1, 7), 2.0) and PixelPaint.shown(Vector2i(1, 2), 0.4) == MatterKit.shown(Vector2i(1, 2), 0.4), "PixelPaint.at/shown forward")
	var rec := PixelPaint.Recorder.new()
	check(rec is MatterKit.Recorder, "PixelPaint.Recorder is MatterKit's")
	# this test set a lambda as PixelPaint.clip: drop the kept clips (else the engine crashes at exit)
	PixelPaint.forget_clips()
	check(PixelPaint.current() == null and PixelPaint._clips.is_empty() and PixelPaint._last == null, "forget_clips drops every kept clip")


func test_flood() -> void:
	var art := 3.0
	var open := func(p: Vector2) -> bool: return p.x < 90.0 and p.y < 60.0
	var count := MatterKit.cells_for(30.0, art)
	check(count == maxi(4, int(PI * 30.0 * 30.0 * 0.75 / (art * art))), "cells_for keeps a circle's volume on the slanted floor")
	var a := MatterKit.flood(Vector2(30, 20), Vector2(1, 0.2), count, art, open, 7, 0.75, 0.55, 3)
	var b := MatterKit.flood(Vector2(30, 20), Vector2(1, 0.2), count, art, open, 7, 0.75, 0.55, 3)
	check(a == b, "the flood is deterministic")
	check(a.size() <= count and a.size() >= count * 3 / 4, "it spends about its volume")
	var inside := true
	for q: Vector2i in a:
		inside = inside and bool(open.call(MatterKit.cell_centre(q, art)))
	check(inside, "no cell lies in a wall")
	var ranks := a.values()
	ranks.sort()
	check(ranks[0] == 0 and ranks.size() == a.size(), "ranks run from 0 in the order it was reached")
	check(SplatShape.flood(Vector2(30, 20), Vector2(1, 0.2), count, art, open, 7, 0.75, 0.55, 3) == a, "SplatShape.flood forwards")
	check(SplatShape.cells_for(30.0, art) == count and SplatShape.STEPS == MatterKit.FLOOD_STEPS, "SplatShape keeps its API")
	# a diagonal seam: walls on (1,0) and (0,1) of the start must not let it leak to (1,1)
	var seam := func(p: Vector2) -> bool:
		var q := MatterKit.at(p, art)
		return q == Vector2i(0, 0) or (q.x >= 1 and q.y >= 1)
	var leak := MatterKit.flood(Vector2(1.5, 1.5), Vector2.ZERO, 50, art, seam, 3)
	check(leak.size() == 1, "nothing leaks through a diagonal wall seam")
	var on_wall := MatterKit.flood(Vector2(95, 20), Vector2.ZERO, 30, art, open, 3)
	var near := true
	for q: Vector2i in on_wall:
		near = near and bool(open.call(MatterKit.cell_centre(q, art)))
	check(not on_wall.is_empty() and near, "a splat landing on a wall's edge starts on the nearest open cell")
	check(MatterKit.flood(Vector2(500, 500), Vector2.ZERO, 30, art, open, 3).is_empty(), "deep in a wall nothing lands")
