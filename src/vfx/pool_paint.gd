extends RefCounted
## Pools of liquid on the floor as opaque pixel materials (poison, void, ice,
## fire, lava, blood: assets/data/vfx_pools.json), shaped by the physics of the
## splat (src/vfx/splat_shape.gd: they run out along their flight and pile up
## against walls and props). All pools of one material are one field of art
## cells, shaded once into a texture (an outline, a lit north rim, a dark south
## lip, the body with its own pattern) whenever cells come or go, so overlapping
## pools never stack; living materials (fire, lava) are shaded again a few
## times a second. Each pool runs out from where it landed over spread_time and
## goes again rim first. Bubbles, flames and sparkles are drawn over it each
## frame. Pure drawing: the host hands it its zones and draws it on the floor,
## over the stains and under the props, actors and shadows.
##
## The liquid lives (vfx_pools.json "physics"): a pool that lands throws drops
## of itself (chips of ice, sparks of fire) that fly in arcs through the
## host's particles and come down again: into the pool they ring it, next to it
## they join it, on dry floor they lie as small puddles that dry. Blows, drops
## and steps send rings over the surface (only where the liquid lies, so they
## break at its rim) with a crown jumping up for a strong one; whoever wades
## through leaves a wake and, out of it, a few wet steps. Drop puddles are
## drawing only: covers() (the game's hit test) sees the thrown pools alone.
## One layer per world: every source (boss moves, hero skills, talents) syncs
## its own pools into it, so the same liquid from two sources is one pool.
##
## Materials react where they meet (vfx_pools.json "reactions"; drawing only,
## covers() is untouched): a liquid on lava or on the hot floor (`hot`) hisses
## away in steam and leaves a dark crust that glows up again, a liquid puts out
## fire, a liquid on ice freezes, ice on fire or lava melts to water. A drop on
## lava hisses the same way.
##
## Fire and lava (materials "flames" / "spread_scale"): burning ground is
## charred floor with embers glowing in it, and the flames rise out of it as
## buoyant particles (with smoke and tumbling embers), not painted tongues.
## Lava runs out slowly (it is thick), its crust is plates of different sizes
## (more of them at the rim, where it cools first) drifting slowly over the melt
## with glowing seams; its bubbles swell, burst and spit glowing drops that cool
## where they land. Both breathe a warm light on the floor round them (draw_glow).
##
## Ice (materials "crack", "melt_to"): a blow cracks it (jagged dark lines with
## lit edges that heal after a while, chips flying), a frost burst freezes the
## liquid near it from its rim inwards (freeze_near), and ice that goes leaves
## a puddle of melt water that dries (drawing only).
##
## The void (style void): every pool turns round its own heart, bands of light
## winding inwards along a spiral (they drift in as it turns) and getting
## darker until its heart, where no light comes back out; it swallows the
## light round it (the floor up to four cells beyond its rim darkens by the
## dither, the darkness creeping in towards it) and pulls loose things, embers
## and drops into it (a particles well per pool, materials.void_pull).

const SplatShape = preload("res://src/vfx/splat_shape.gd")
const Glow = preload("res://src/vfx/glow.gd")
const DATA_PATH := "res://assets/data/vfx_pools.json"
const FPS := 12.0
## 4x4 ordered dither thresholds (rings thin out by it).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## World px per art pixel of the canvas it draws on.
var art := 2.0
## Callable(world point) -> bool: floor a pool may cover.
var open: Callable
var cfg: Dictionary = {}
## The particles (src/vfx/particles.gd) its drops fly in, null without; their
## units are this canvas's world px times to_particles (story worlds 1 / 1.5).
var particles: RefCounted = null
var to_particles := 1.0
## Callable(world point) -> bool: hot floor that is not a pool (the Hell's lava
## tiles); a liquid there reacts as on lava. Empty: none.
var hot := Callable()
## Crust on the hot floor where a liquid hissed away: art cell -> until (drawn over the tiles).
var _hot_crust: Dictionary = {}
var _reacted := -100.0
## The crust of the lava field being shaded (_bake -> _shade).
var _crust: Dictionary = {}
## The void field being shaded: cell -> Vector2(its share out from the heart,
## its spiral angle before the turn), kept while its cells and hearts stay.
var _void_cache: Dictionary = {}
## The lava plates of one shading: Vector3i(grid x, grid y, plate size) ->
## [the plate's point (art px), its crust number 0..99].
var _lava_sites: Dictionary = {}
## The burning ground's heat noise by drifted cell (it only moves over the field).
var _fire_noise: Dictionary = {}
## The middle of the field being shaded (_bake -> _shade, the void's spiral).
var _mid := Vector2.ZERO
## The hearts of the void pools being shaded, [middle in cells, radius in cells]
## each (_bake -> _shade: every pool turns round its own).
var _hearts: Array = []
## Bakes so far per material, and the time spent drawing (draw, bakes
## included) over how many frames: measures for scripts/bench_vfx.gd.
var bake_counts: Dictionary = {}
var draw_us := 0
var draw_parts: Dictionary = {}
var draw_frames := 0
## art cell -> open floor there (asked of `open` once, _open_cell), and since when (ms).
var _open_memo: Dictionary = {}
var _open_since := 0
## art cell -> hot floor there (asked of `hot` once, _hot_cell).
var _hot_memo: Dictionary = {}
## Melt water waiting to be laid (cells of ice that went this frame): [q, until].
var _melts: Array = []
## Liquid cells that freeze (are hidden) when their ice is born: [mat, q, born].
var _freezing: Array = []
## "source:id" -> {mat, cells: Array[Vector2i], end, source}
var _pools: Dictionary = {}
## "source:id" -> a pool whose shape a worker thread is working out (add, _collect_shapes).
var _shaping: Dictionary = {}
## Pools still being laid into their fields, oldest first (_lay, _lay_steps):
## {key, mat, timed, keys, i, finish?, finish_edge?}.
var _laying: Array = []
## material -> field {cells: {Vector2i: [born, until, rank 0..1, drawing only?]}, img, tex, box, col, list, rim, next, dirty, baked, ripples}
var _fields: Dictionary = {}
## Wading actors: key -> {mat, last, steps, at, side, seen}.
var _waders: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _drawn_frame := -1
var _ramps: Dictionary = {}
var _now := 0.0
static var _data: Dictionary = {}


func _init(art_px: float, open_floor: Callable) -> void:
	art = art_px
	open = open_floor
	cfg = settings()
	for mat: String in cfg.get("materials", {}):
		var ramp := {}
		var spec: Dictionary = cfg.materials[mat].get("ramp", {})
		for role: String in spec:
			ramp[role] = Color(str(spec[role]))
		_ramps[mat] = ramp


## vfx_pools.json, cached.
static func settings() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {"materials": {}}
	return _data


## The material a zone style is drawn in ("" when it has none).
func material_for(style: String) -> String:
	if cfg.get("materials", {}).has(style):
		return style
	return {"flesh": "blood", "curse": "void"}.get(style, "")


## True when `style` is drawn as a pool here.
func handles(style: String) -> bool:
	return material_for(style) != ""


## The cells a splat of `style` covers (rank 0..n-1), the same on server and clients.
static func shape(at: Vector2, dir: Vector2, radius: float, style: String, art_px: float, open_floor: Callable, seed: int) -> Dictionary:
	var c := settings()
	var squash := float(c.get("squash", 0.75))
	var mat: Dictionary = c.get("materials", {}).get(style, {})
	var drops := int(mat.get("droplets", 0)) if dir.length() > 0.01 else 0
	return SplatShape.flood(at, dir, SplatShape.cells_for(radius, art_px, squash), art_px, open_floor, seed, squash, float(c.get("momentum", 0.55)), drops)


## The key of pool `id` of a source (its ids are its own).
static func _key(source: String, id: int) -> String:
	return "%s:%d" % [source, id]


## A pool `id` of `style` from `source` landing at `at` along `dir` (radius
## as its volume), from `start` until `end` (seconds on the host's clock).
## Known pools are kept. With `splash` it has just landed: it throws drops.
## A pool of thread_cells cells or more gets its shape worked out on a worker
## thread (it is the same shape, a few frames later; the game never waits).
func add(id: int, style: String, at: Vector2, dir: Vector2, radius: float, start: float, end: float, source := "", splash := false) -> void:
	var key := _key(source, id)
	if _pools.has(key) or _shaping.has(key):
		return
	var mat := material_for(style)
	if mat == "":
		return
	var squash := float(cfg.get("squash", 0.75))
	if SplatShape.cells_for(radius, art, squash) >= int(cfg.get("thread_cells", 600)):
		# the worker also times its cells (_timings); the keys it fills are there already
		var job := {"key": key, "id": id, "mat": mat, "at": at, "dir": dir, "radius": radius, "start": start, "end": end, "source": source, "splash": splash, "cells": {}, "timed": {}}
		var feel := art
		var floor_open := open
		var spread := _spread_of(mat)
		var edge := _edge_of(start, end)
		job.task = WorkerThreadPool.add_task(func() -> void:
			var cells := shape(at, dir, radius, mat, feel, floor_open, id)
			job.timed = _timings(cells, start, end, spread, edge)
			job.cells = cells)
		_shaping[key] = job
		return
	_lay(key, id, mat, shape(at, dir, radius, mat, art, open, id), at, dir, radius, start, end, source, splash)


## Lays the pools whose shapes the worker threads have finished.
func _collect_shapes() -> void:
	for key: String in _shaping.keys():
		var job: Dictionary = _shaping[key]
		if not WorkerThreadPool.is_task_completed(int(job.task)):
			continue
		WorkerThreadPool.wait_for_task_completion(int(job.task))
		_shaping.erase(key)
		_lay(key, int(job.id), str(job.mat), job.cells, job.at, job.dir, float(job.radius), float(job.start), float(job.end), str(job.source), bool(job.splash), job.timed)


## How long material `mat` takes to spread out from its middle (s).
func _spread_of(mat: String) -> float:
	return float(cfg.get("spread_time", 0.35)) * float(cfg.materials[mat].get("spread_scale", 1.0))


## How long before its end a pool lasting `start`..`end` begins to go, rim first (s).
func _edge_of(start: float, end: float) -> float:
	return minf(float(cfg.get("edge_time", 0.7)), maxf(0.1, (end - start) * 0.4))


## When each cell of a pool's shape (`cells`: art cell -> rank) is born and
## goes, with its share of the rank: {cell: [born, until, k]} in the shape's
## order. Born spreading out from the middle over `spread` s, gone rim first
## over the last `edge` s. Touches nothing else (a worker thread may ask it).
static func _timings(cells: Dictionary, start: float, end: float, spread: float, edge: float) -> Dictionary:
	var out := {}
	var n := float(maxi(1, cells.size()))
	for q: Vector2i in cells:
		var k := float(cells[q]) / n
		out[q] = [start + spread * pow(k, 0.7), end - edge * k, k]
	return out


## Waits for the shapes still being worked out and drops them (a new room).
func _drop_shapes() -> void:
	for key: String in _shaping:
		WorkerThreadPool.wait_for_task_completion(int(_shaping[key].task))
	_shaping.clear()


## Puts pool `key` (its `cells`: art cell -> rank; `timed` their _timings when
## a worker worked them out) into its material's field.
func _lay(key: String, id: int, mat: String, cells: Dictionary, at: Vector2, dir: Vector2, radius: float, start: float, end: float, source: String, splash: bool, timed: Dictionary = {}) -> void:
	if cells.is_empty() or _pools.has(key):
		return
	var field: Dictionary = _field(mat)
	if timed.is_empty():
		timed = _timings(cells, start, end, _spread_of(mat), _edge_of(start, end))
	var keys := timed.keys()
	_pools[key] = {"mat": mat, "cells": keys, "end": end, "source": source, "at": at, "r": radius}
	if (field.cells as Dictionary).is_empty() and _laying.is_empty():
		# nothing lies there: all of it at once
		(field.cells as Dictionary).merge(timed)
	else:
		# it meets what lies there cell by cell (_lay_step), a big pool over a
		# few frames from its middle out (far ahead of its spreading), after
		# the pools still being laid
		var job := {"key": key, "mat": mat, "timed": timed, "keys": keys, "i": 0, "since": Time.get_ticks_msec()}
		if _laying.is_empty() and keys.size() <= int(cfg.get("lay_now_cells", 1500)):
			_lay_step(job, 1 << 62)
		else:
			_laying.append(job)
	field.next = minf(float(field.next), start)
	field.dirty = true
	if splash:
		_splash(mat, at, dir, radius, id)


## Lays the pools waiting to be laid (_lay) until the clock passes `until` (usec).
func _lay_steps(until: int) -> void:
	while not _laying.is_empty():
		if not _lay_step(_laying[0], until):
			return
		_laying.pop_front()


## Lays the cells of a waiting pool `job` into its field, in its order, until
## the clock passes `until` (usec); true when all are. Where the field has a
## cell already, a drop puddle there (more than three entries) gives way, else
## the earlier birth, the later end and the lower rank of both hold; a pool
## that ended early meanwhile (finish) goes rim first from then (as if laid at once).
func _lay_step(job: Dictionary, until: int) -> bool:
	var field: Dictionary = _field(str(job.mat))
	var cells: Dictionary = field.cells
	var timed: Dictionary = job.timed
	var keys: Array = job.keys
	var ended := job.has("finish")
	var i := int(job.i)
	while i < keys.size():
		var q: Vector2i = keys[i]
		i += 1
		# (the new pool's entries are its own: changed in place)
		var fresh: Array = timed[q]
		var have: Variant = cells.get(q)
		if have != null and not (have as Array).is_empty() and (have as Array).size() <= 3:
			fresh[0] = minf(float(have[0]), float(fresh[0]))
			fresh[1] = maxf(float(have[1]), float(fresh[1]))
			fresh[2] = minf(float(have[2]), float(fresh[2]))
		if ended:
			fresh[1] = minf(float(fresh[1]), float(job.finish) + float(job.finish_edge) * (1.0 - float(fresh[2])))
		cells[q] = fresh
		if i & 63 == 0 and Time.get_ticks_usec() >= until:
			break
	job.i = i
	field.dirty = true
	return i >= keys.size()


## A pool (its key) that ended early (its zone was removed): it goes rim first from now.
func finish(key: String, now: float) -> void:
	var pool: Dictionary = _pools.get(key, {})
	if pool.is_empty() or float(pool.end) <= now:
		return
	var field: Dictionary = _field(str(pool.mat))
	var edge := float(cfg.get("edge_time", 0.7)) * 0.5
	# its cells not laid yet go the same way when they are
	for job: Dictionary in _laying:
		if str(job.key) == key:
			job.finish = minf(float(job.get("finish", INF)), now)
			job.finish_edge = edge
	for q: Vector2i in pool.cells:
		var have: Array = field.cells.get(q, [])
		if not have.is_empty():
			have[1] = minf(float(have[1]), now + edge * (1.0 - float(have[2])))
	pool.end = now
	field.next = now
	field.dirty = true


## Takes in a source's zones ({id, k "pool", st style, x, y, r, dx, dy, p 0..1,
## L its length in s}) and lets that source's pools that left the list go. A
## pool first seen within physics.splash_window of its landing splashes.
func sync(zones: Array, now: float, source := "") -> void:
	# the host's clock now: a splash, its crown and its drops start from it
	_now = now
	var seen := {}
	var window := float(cfg.get("physics", {}).get("splash_window", 0.25))
	for zone: Dictionary in zones:
		if str(zone.get("k", "")) != "pool" or not handles(str(zone.get("st", ""))):
			continue
		var id := int(zone.get("id", -1))
		var key := _key(source, id)
		seen[key] = true
		if not _pools.has(key):
			var length := float(zone.get("L", 4.0))
			var start := now - float(zone.get("p", 0.0)) * length
			add(id, str(zone.st), Vector2(float(zone.x), float(zone.y)), Vector2(float(zone.get("dx", 0.0)), float(zone.get("dy", 0.0))), float(zone.r), start, start + length, source, now - start <= window)
	for key: String in _pools.keys():
		if str(_pools[key].source) != source or seen.has(key):
			continue
		finish(key, now)
		if float(_pools[key].end) + float(cfg.get("edge_time", 0.7)) < now:
			_pools.erase(key)


func clear() -> void:
	_drop_shapes()
	_laying.clear()
	_pools.clear()
	_fields.clear()
	_waders.clear()
	_hot_crust.clear()
	_open_memo.clear()
	_hot_memo.clear()


## True when `point` (world px) lies in a pool of `style` (any when "").
func covers(point: Vector2, style := "") -> bool:
	var q := Vector2i((point / art).floor())
	for mat: String in _fields:
		if style != "" and mat != material_for(style):
			continue
		var have: Array = _fields[mat].cells.get(q, [])
		# drop puddles are drawing only: the game's hit test never sees them
		if have.size() == 3 and float(have[0]) <= _now and _now < float(have[1]):
			return true
	return false


func _field(mat: String) -> Dictionary:
	if not _fields.has(mat):
		_fields[mat] = {"cells": {}, "img": null, "tex": null, "box": Rect2i(), "col": {}, "list": [], "rim": [], "next": 0.0, "dirty": true, "baked": -100.0, "frame": -1, "ripples": [], "hide": {}, "crust": {}, "cracks": [], "zaps": []}
	return _fields[mat]


# ---------- drawing ----------

## Shades what changed and draws every field with its living overlay, in world px.
## Drawn once a frame: when several sources share this layer, the first draws it.
func draw(canvas: CanvasItem, now: float) -> void:
	var frame_now := Engine.get_process_frames()
	if frame_now == _drawn_frame:
		return
	_drawn_frame = frame_now
	var started := Time.get_ticks_usec()
	_collect_shapes()
	# a pool or picture that has been waiting longer than catch_up_after_ms gets
	# catch_up_ms a frame instead (it does not lag far behind what happens)
	var late := int(cfg.get("catch_up_after_ms", 100))
	var lay_ms := float(cfg.get("lay_budget_ms", 2.0))
	if not _laying.is_empty() and Time.get_ticks_msec() - int(_laying[0].get("since", 0)) > late:
		lay_ms = maxf(lay_ms, float(cfg.get("catch_up_ms", 8.0)))
	_lay_steps(Time.get_ticks_usec() + int(lay_ms * 1000.0))
	var after_collect := Time.get_ticks_usec()
	_now = now
	_react(now)
	var after_react := Time.get_ticks_usec()
	var rate := 1.0 / float(cfg.get("rebake_hz", 15))
	var anim := float(cfg.get("anim_hz", 6))
	# shading again is spread over the frames: work in progress goes on first,
	# then the material waiting longest starts, while bake_budget_ms lasts; a
	# new material always starts. Until its new picture is done the old shows.
	var bake_ms := float(cfg.get("bake_budget_ms", 3.0))
	for mat: String in _fields:
		var waiting_field: Dictionary = _fields[mat]
		if waiting_field.has("work") and Time.get_ticks_msec() - int(waiting_field.work.get("since", 0)) > late:
			bake_ms = maxf(bake_ms, float(cfg.get("catch_up_ms", 8.0)))
	var until := Time.get_ticks_usec() + int(bake_ms * 1000.0)
	for mat: String in _fields:
		var field: Dictionary = _fields[mat]
		if field.has("work"):
			_bake_step(field, until)
	var waiting: Array = []
	for mat: String in _fields:
		var field: Dictionary = _fields[mat]
		if field.has("work"):
			continue
		var style := str(cfg.materials[mat].get("style", "liquid"))
		var frame := int(floor(now * anim)) if style in ["fire", "lava", "void"] else 0
		var due: bool = now >= float(field.next) or bool(field.dirty) or frame != int(field.frame)
		if not due or now - float(field.baked) < rate:
			continue
		var fresh := field.tex == null and float(field.baked) < -50.0
		waiting.append([-1000.0 if fresh else float(field.baked), mat, style, frame, fresh])
	waiting.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for entry: Array in waiting:
		if Time.get_ticks_usec() >= until and not bool(entry[4]):
			break
		var field: Dictionary = _fields[entry[1]]
		_bake(field, str(entry[1]), str(entry[2]), now, int(entry[3]))
		if field.has("work"):
			_bake_step(field, until)
	var after_bake := Time.get_ticks_usec()
	for mat: String in _fields:
		var field: Dictionary = _fields[mat]
		var style := str(cfg.materials[mat].get("style", "liquid"))
		if field.tex != null:
			var box: Rect2i = field.box
			canvas.draw_texture_rect(field.tex, Rect2(Vector2(box.position) * art, Vector2(box.size) * art), false)
			_overlay(canvas, field, mat, style, now)
		# rings and the landing crown (the crown shows before the pool has run out)
		_draw_ripples(canvas, field, mat, now)
		_draw_cracks(canvas, field, mat, now)
		_draw_zaps(canvas, field, now)
	var after_layers := Time.get_ticks_usec()
	_draw_hot_crust(canvas, now)
	_pull(now)
	# ice that went this frame leaves melt water (laid after the loop over the fields)
	if not _melts.is_empty():
		for entry: Array in _melts:
			var into: Dictionary = _field(str(entry[2]))
			if not into.cells.has(entry[0]):
				into.cells[entry[0]] = [now, float(entry[1]), 1.0, true]
				into.dirty = true
				into.next = minf(float(into.next), now)
		_melts.clear()
	# fields that are empty for good go
	for mat: String in _fields.keys():
		if (_fields[mat].cells as Dictionary).is_empty() and (_fields[mat].ripples as Array).is_empty() and (_fields[mat].cracks as Array).is_empty() and (_fields[mat].zaps as Array).is_empty():
			_fields.erase(mat)
	# waders not seen for a while are forgotten
	for key: String in _waders.keys():
		if now - float(_waders[key].get("seen", now)) > 3.0:
			_waders.erase(key)
	var ended := Time.get_ticks_usec()
	draw_us += ended - started
	draw_frames += 1
	draw_parts.collect = int(draw_parts.get("collect", 0)) + after_collect - started
	draw_parts.react = int(draw_parts.get("react", 0)) + after_react - after_collect
	draw_parts.bake = int(draw_parts.get("bake", 0)) + after_bake - after_react
	draw_parts.layers = int(draw_parts.get("layers", 0)) + after_layers - after_bake
	draw_parts.rest = int(draw_parts.get("rest", 0)) + ended - after_layers


## Begins shading field `mat` again for time `now` and animation frame
## `frame`: which cells are liquid now, its outline, lip and swallowed light
## (or the last ones when nothing but the animation changed), then the cells
## are shaded; all of it in slices (_bake_step), the picture changing when
## all is done (the last one shows till then).
func _bake(field: Dictionary, mat: String, style: String, now: float, frame: int) -> void:
	bake_counts[mat] = int(bake_counts.get(mat, 0)) + 1
	var was_dirty := bool(field.dirty)
	field.dirty = false
	field.baked = now
	field.frame = frame
	var kept: Dictionary = field.get("shape", {})
	if not was_dirty and not kept.is_empty() and now < float(kept.next) and float(field.next) >= float(kept.next) and str(kept.mat) == mat:
		# only the animation moved on: the same cells, outline and lip
		_begin_work(field, kept, style, now, frame)
		return
	field.work = {"phase": "scan", "mat": mat, "style": style, "now": now, "frame": frame, "i": 0, "since": Time.get_ticks_msec(), "keys": (field.cells as Dictionary).keys(),
		"live": {}, "next": INF, "gone": [], "sum": Vector2.ZERO, "lo": Vector2i(1 << 30, 1 << 30), "hi": Vector2i(-(1 << 30), -(1 << 30))}


## Works the field's shape out until the clock passes `until` (usec), a step
## at a time: "scan" (which cells live now, which went, when the next changes,
## the box and middle of the living ones), then the byte grid of the living
## cells, the outline round them, the lip under them and the void's swallowed
## light; then the shading begins (_begin_work). As _bake did it in one go.
func _shape_step(field: Dictionary, until: int) -> void:
	var work: Dictionary = field.work
	var now := float(work.now)
	if str(work.phase) == "scan":
		var cells: Dictionary = field.cells
		var hidden: Dictionary = field.hide
		var keys: Array = work.keys
		var live: Dictionary = work.live
		var gone: Array = work.gone
		var next := float(work.next)
		var sum: Vector2 = work.sum
		var lo: Vector2i = work.lo
		var hi: Vector2i = work.hi
		var i := int(work.i)
		while i < keys.size():
			var q: Vector2i = keys[i]
			i += 1
			var held: Variant = cells.get(q)
			if held != null:
				var c: Array = held
				if now >= float(c[1]):
					gone.append(q)
				elif now >= float(c[0]):
					if not hidden.has(q):
						live[q] = float(c[2])
						sum += Vector2(q)
						lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
						hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
					next = minf(next, float(c[1]))
				else:
					next = minf(next, float(c[0]))
			if i & 63 == 0 and Time.get_ticks_usec() >= until:
				break
		work.i = i
		work.next = next
		work.sum = sum
		work.lo = lo
		work.hi = hi
		if i < keys.size():
			return
		work.phase = "gone"
		work.i = 0
	if str(work.phase) == "gone":
		if not _shape_gone(field, work, until):
			return
		_shape_scanned(field, work)
		if not field.has("work"):
			return
	var phase := str(work.phase)
	var keys: Array = work.live_keys
	var live: Dictionary = work.live
	var grid: PackedByteArray = work.grid
	var gw := int(work.gw)
	var box: Rect2i = work.box
	var w := box.size.x
	var ox := box.position.x
	var oy := box.position.y
	var px: PackedByteArray = work.base
	var i := int(work.i)
	while phase != "done":
		match phase:
			"grid":
				# which cells are liquid, as a byte grid over the box with a margin
				# of two (quicker to ask than the dictionary; every neighbour test is one index)
				while i < keys.size():
					var q: Vector2i = keys[i]
					i += 1
					grid[(q.y - oy + 2) * gw + q.x - ox + 2] = 1
					if i & 255 == 0 and Time.get_ticks_usec() >= until:
						break
			"outline":
				# the outline round it (beside it and above, where nothing lies there nor under that)
				var outline: Color = work.outline
				while i < keys.size():
					var q: Vector2i = keys[i]
					i += 1
					var x := q.x - ox
					var y := q.y - oy
					var gi := (y + 2) * gw + x + 2
					if grid[gi + 1] == 0 and grid[gi + 1 + gw] == 0:
						_px(px, (y * w + x + 1) * 4, outline)
					if grid[gi - 1] == 0 and grid[gi - 1 + gw] == 0:
						_px(px, (y * w + x - 1) * 4, outline)
					if i & 127 == 0 and Time.get_ticks_usec() >= until:
						break
			"lip":
				# the dark lip under its south edge
				var outline: Color = work.outline
				var deep: Color = work.deep
				while i < keys.size():
					var q: Vector2i = keys[i]
					i += 1
					var x := q.x - ox
					var y := q.y - oy
					var gi := (y + 2) * gw + x + 2
					if grid[gi + gw] == 0:
						_px(px, ((y + 1) * w + x) * 4, deep)
						if grid[gi + 2 * gw] == 0:
							_px(px, ((y + 2) * w + x) * 4, outline)
					if i & 127 == 0 and Time.get_ticks_usec() >= until:
						break
			"halo":
				# the light round the void is swallowed: floor cells up to 4 beyond its rim
				var halo: Dictionary = work.halo
				while i < keys.size():
					var q: Vector2i = keys[i]
					i += 1
					var gi := (q.y - oy + 2) * gw + q.x - ox + 2
					if not (grid[gi + 1] == 1 and grid[gi - 1] == 1 and grid[gi + gw] == 1 and grid[gi - gw] == 1):
						for dy in range(-4, 5):
							for dx in range(-4, 5):
								var c := q + Vector2i(dx, dy)
								if live.has(c): continue
								var d := maxi(absi(dx), absi(dy))
								if d < int(halo.get(c, 9)) and _open_cell(c): halo[c] = d
					if i & 15 == 0 and Time.get_ticks_usec() >= until:
						break
		if i < keys.size():
			work.i = i
			work.phase = phase
			work.grid = grid
			work.base = px
			return
		i = 0
		match phase:
			"grid": phase = "outline"
			"outline": phase = "lip"
			"lip": phase = "halo" if str(work.style) == "void" else "done"
			_: phase = "done"
	# the shape stays for the bakes that only move the animation on (until a
	# cell is born or goes, or a crust cools: field.next)
	var shape := {"mat": str(work.mat), "next": float(work.next), "live": live, "keys": keys, "grid": grid, "gw": gw, "box": box, "base": px,
		"halo": work.halo, "mid": work.mid, "hearts": work.hearts, "void_cache": work.void_cache}
	field.shape = shape
	_begin_work(field, shape, str(work.style), now, int(work.frame), int(work.since))


## The cells the scan of the field's shape found gone leave it (ice leaving
## melt water) until the clock passes `until` (usec); true when all have.
func _shape_gone(field: Dictionary, work: Dictionary, until: int) -> bool:
	var cells: Dictionary = field.cells
	var hidden: Dictionary = field.hide
	var now := float(work.now)
	var gone: Array = work.gone
	var mat := str(work.mat)
	var melt := str(cfg.materials[mat].get("melt_to", ""))
	var melts: bool = melt != "" and cfg.materials.has(melt)
	var dry: Array = _phys("water_dry", [2.5, 4.0]) if melts else []
	var i := int(work.i)
	while i < gone.size():
		var q: Vector2i = gone[i]
		i += 1
		var held: Variant = cells.get(q)
		# still gone (a pool laid since may have filled it again)
		if held != null and now >= float((held as Array)[1]):
			if melts and (held as Array).size() == 3 and not hidden.has(q):
				_melts.append([q, now + _rng.randf_range(float(dry[0]), float(dry[1])), melt])
			cells.erase(q)
			hidden.erase(q)
		if i & 63 == 0 and Time.get_ticks_usec() >= until:
			break
	work.i = i
	return i >= gone.size()


## The scan of the field's shape is done and the cells that went have left
## (_shape_step): cooled crust goes, the middle, the void's hearts and the
## next change are known; the grid and picture of the box are made ready for
## the next steps (or the field shows nothing when none live).
func _shape_scanned(field: Dictionary, work: Dictionary) -> void:
	var mat := str(work.mat)
	var style := str(work.style)
	var now := float(work.now)
	var live: Dictionary = work.live
	var next := float(work.next)
	var crust: Dictionary = field.crust
	for q: Vector2i in crust.keys():
		if now >= float(crust[q]): crust.erase(q)
		else: next = minf(next, float(crust[q]))
	_crust = crust
	if _lava_sites.size() > 50000:
		_lava_sites.clear()
	_mid = Vector2(work.sum) / float(maxi(1, live.size()))
	_hearts = []
	if style == "void":
		for key: String in _pools:
			var pool: Dictionary = _pools[key]
			if str(pool.mat) == mat:
				_hearts.append([Vector2(pool.get("at", Vector2.ZERO)) / art, maxf(2.0, float(pool.get("r", 30.0)) / art)])
		# the spiral's places stay while its cells and hearts stay
		var sig := "%d|%s|%s" % [live.size(), str(_mid), str(_hearts)]
		if str(field.get("void_sig", "")) != sig:
			field.void_sig = sig
			field.void_cache = {}
		_void_cache = field.void_cache
	field.next = next
	work.next = next
	if live.is_empty():
		field.tex = null
		field.col = {}
		field.list = []
		field.rim = []
		field.erase("shape")
		field.erase("work")
		return
	var lo: Vector2i = work.lo
	var hi: Vector2i = work.hi
	var box := Rect2i(lo - Vector2i(1, 1), hi - lo + Vector2i(3, 5))
	var R: Dictionary = _ramps[mat]
	var gw := box.size.x + 4
	var grid := PackedByteArray()
	grid.resize(gw * (box.size.y + 4))
	var px := PackedByteArray()
	px.resize(box.size.x * box.size.y * 4)
	work.erase("keys")
	work.erase("gone")
	work.phase = "grid"
	work.i = 0
	work.live_keys = live.keys()
	work.box = box
	work.gw = gw
	work.grid = grid
	work.base = px
	work.outline = R.outline
	work.deep = R.deep
	work.halo = {}
	work.mid = _mid
	work.hearts = _hearts
	work.void_cache = _void_cache


## Starts the slices of shading `shape` (see _bake); `since` when this bake
## began (msec; now when -1), for the catch-up budget in draw.
func _begin_work(field: Dictionary, shape: Dictionary, style: String, now: float, frame: int, since := -1) -> void:
	field.work = {"shape": shape, "style": style, "now": now, "frame": frame, "i": 0, "px": (shape.base as PackedByteArray).duplicate(),
		"col": {}, "list": [], "rim": [], "since": since if since >= 0 else Time.get_ticks_msec()}


## Shades the cells of the field's work in progress until the clock passes
## `until` (usec); when all are, its picture, colours and outline change at once.
func _bake_step(field: Dictionary, until: int) -> void:
	if (field.work as Dictionary).has("phase"):
		_shape_step(field, until)
		if not field.has("work") or (field.work as Dictionary).has("phase") or Time.get_ticks_usec() >= until:
			return
	var work: Dictionary = field.work
	var shape: Dictionary = work.shape
	var mat := str(shape.mat)
	var style := str(work.style)
	var now := float(work.now)
	var frame := int(work.frame)
	var R: Dictionary = _ramps[mat]
	# what _shade reads of the field being shaded
	_mid = shape.mid
	_hearts = shape.hearts
	_void_cache = shape.void_cache
	_crust = field.crust
	var keys: Array = shape.keys
	var live: Dictionary = shape.live
	var grid: PackedByteArray = shape.grid
	var gw := int(shape.gw)
	var box: Rect2i = shape.box
	var w := box.size.x
	var ox := box.position.x
	var oy := box.position.y
	var px: PackedByteArray = work.px
	var col_map: Dictionary = work.col
	var list: Array = work.list
	var rim: Array = work.rim
	var i := int(work.i)
	while i < keys.size():
		var q: Vector2i = keys[i]
		i += 1
		var x := q.x - ox
		var y := q.y - oy
		var gi := (y + 2) * gw + x + 2
		# its neighbours as bits: up, up 2, down, right, left, down 2, right 2, left 2
		var nb := grid[gi - gw] | (grid[gi - 2 * gw] << 1) | (grid[gi + gw] << 2) | (grid[gi + 1] << 3) \
			| (grid[gi - 1] << 4) | (grid[gi + 2 * gw] << 5) | (grid[gi + 2] << 6) | (grid[gi - 2] << 7)
		var col := _shade(q, nb, float(live[q]), R, style, now, frame)
		_px(px, (y * w + x) * 4, col)
		col_map[q] = col
		list.append(q)
		if nb & 9 == 0:
			rim.append(q)
		if i & 63 == 0 and Time.get_ticks_usec() >= until:
			break
	work.i = i
	work.px = px
	if i < keys.size():
		return
	# all shaded: the new picture
	field.erase("work")
	field.col = col_map
	field.list = list
	field.rim = rim
	field.halo = shape.halo
	field.halo_tick = -1
	var img: Image = field.img
	if img != null and img.get_size() == box.size:
		img.set_data(w, box.size.y, false, Image.FORMAT_RGBA8, px)
	else:
		img = Image.create_from_data(w, box.size.y, false, Image.FORMAT_RGBA8, px)
	field.img = img
	if field.tex == null or (field.tex as ImageTexture).get_size() != Vector2(box.size):
		field.tex = ImageTexture.create_from_image(img)
	else:
		(field.tex as ImageTexture).update(img)
	field.box = box


## The void's swallowed light round its rim (field.halo: cell -> rings out)
## at time `t` into field.halo_tex: darkest at the rim, waves creeping in.
func _halo_image(field: Dictionary, col: Color, t: float) -> void:
	var halo: Dictionary = field.get("halo", {})
	if halo.is_empty():
		field.erase("halo_tex")
		return
	var box: Rect2i = field.box
	var at := box.position - Vector2i(4, 4)
	var size := box.size + Vector2i(8, 8)
	var keep: Array = []
	for d in range(5):
		keep.append((0.95 - 0.2 * float(d)) * (0.7 + 0.3 * (0.5 + 0.5 * sin(float(d) * 1.6 + t * 5.0))) * 16.0)
	var px := PackedByteArray()
	px.resize(size.x * size.y * 4)
	for h: Vector2i in halo:
		var x := h.x - at.x
		var y := h.y - at.y
		if x < 0 or y < 0 or x >= size.x or y >= size.y:
			continue
		if float(BAYER[posmod(h.y, 4) * 4 + posmod(h.x, 4)]) < float(keep[mini(4, int(halo[h]))]):
			_px(px, (y * size.x + x) * 4, col)
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, px)
	if field.get("halo_tex") != null and Vector2i(field.halo_size) == size:
		(field.halo_tex as ImageTexture).update(image)
	else:
		field.halo_tex = ImageTexture.create_from_image(image)
	field.halo_at = at
	field.halo_size = size


## Writes colour `c` opaque into the byte image `px` at byte `at`.
static func _px(px: PackedByteArray, at: int, c: Color) -> void:
	px[at] = c.r8
	px[at + 1] = c.g8
	px[at + 2] = c.b8
	px[at + 3] = 255


## Whether art cell `q` is open floor (`open` at its middle), remembered: asked
## once per cell, forgotten every few seconds (a broken wall opens cells) and
## with clear().
func _open_cell(q: Vector2i) -> bool:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _open_since > 3000 or _open_memo.size() > 200000:
		_open_memo.clear()
		_open_since = now_ms
	var known: Variant = _open_memo.get(q)
	if known != null:
		return bool(known)
	var free := bool(open.call((Vector2(q) + Vector2(0.5, 0.5)) * art))
	_open_memo[q] = free
	return free


## One cell's colour: the north rim lit, the row under it lighter, the south
## row deep, and inside the material's own pattern.
## `nb`: which neighbours are liquid too, as bits (1 up, 2 two up, 4 down,
## 8 right, 16 left, 32 two down, 64 two right, 128 two left); `rank` its
## place from the middle (0) to the rim (1).
func _shade(q: Vector2i, nb: int, rank: float, R: Dictionary, style: String, now: float, frame: int) -> Color:
	var up := nb & 1 != 0
	var up2 := nb & 2 != 0
	var dn := nb & 4 != 0
	var inner := nb & 29 == 29
	match style:
		"void":
			# dark in its heart, a bright rim of light where it meets the floor
			if not inner:
				return R.hi if not up else R.lite
			if not (up2 and nb & 224 == 224):
				return R.lite if not up2 else R.body
			# it turns round its own heart (the nearest pool's middle); where each
			# cell sits on the spiral is worked out once (_void_cache)
			var spot: Variant = _void_cache.get(q)
			if spot == null:
				var heart := _mid
				var big := 8.0
				var best := INF
				for h: Array in _hearts:
					var gap := (Vector2(q) - Vector2(h[0])).length_squared()
					if gap < best:
						best = gap
						heart = h[0]
						big = float(h[1])
				var rel := Vector2(q) + Vector2(0.5, 0.5) - heart
				rel.y /= 0.75
				var dist := rel.length()
				spot = Vector2(clampf(dist / big, 0.0, 1.0), atan2(rel.y, rel.x) * 3.0 + log(dist + 1.0) * 4.5)
				_void_cache[q] = spot
			var k: float = (spot as Vector2).x
			# its heart: no light comes back out
			if k < 0.2:
				return R.outline
			# bands of light winding in along a spiral, drifting inwards as it turns
			var arm := sin((spot as Vector2).y + float(frame) * 0.9)
			if k < 0.36:
				return R.shade if arm > 0.75 else R.deep
			if arm > 0.8:
				return R.hi if k > 0.72 and arm > 0.96 else R.lite
			if arm > 0.3:
				return R.body
			return R.shade if k > 0.55 else R.deep
		"ice":
			if not up:
				return R.hi
			if not up2:
				return R.lite
			if not dn:
				return R.shade
			var diag := posmod(q.x + q.y, 26)
			if diag < 2 or diag == 4:
				return R.lite
			return R.body
		"fire":
			# burning ground: charred floor, embers glowing in it and slowly
			# shifting; the flames are particles rising out of it
			if not up:
				return R.body if _h(q.x, q.y, 2) % 3 == 0 else R.shade
			if not dn:
				return R.deep
			# the heat drifts over the field: the same noise cell by cell, worked out once
			var spot := Vector2i(q.x + frame / 2, q.y - frame / 3)
			var known: Variant = _fire_noise.get(spot)
			if known == null:
				if _fire_noise.size() > 200000:
					_fire_noise.clear()
				known = _noise(spot.x, spot.y, 3, 9)
				_fire_noise[spot] = known
			var heat: float = known
			if heat > 0.84:
				return R.hi
			if heat > 0.77:
				return R.lite
			if heat > 0.69:
				return R.body
			return R.shade if _h(q.x, q.y, 4) % 5 != 0 else R.deep
		"lava":
			# a crust where a liquid hissed on it: dark plates with glowing seams
			if _crust.has(q):
				return _crust_colour(q, float(_crust[q]) - now, R)
			return _lava_colour(q, rank, up, inner, R, frame)
		_:
			# a liquid: one calm body, a lit north rim, a deeper band before the
			# south lip, and short level glints of light lying on its surface
			if not up:
				return R.hi
			if not up2:
				return R.lite
			if not dn:
				return R.shade
			if nb & 32 == 0:
				return R.shade if posmod(q.x, 3) != 0 else R.body
			var gx := floori(float(q.x) / 7.0)
			var gy := floori(float(q.y) / 5.0)
			var h := _h(gx, gy, 17)
			if h % 3 == 0:
				var sx := gx * 7 + h % 4
				var sy := gy * 5 + (h / 7) % 3
				var len := 2 + h % 3
				if q.y == sy and q.x >= sx and q.x < sx + len:
					return R.spec if q.x == sx and h % 2 == 0 else R.lite
			return R.body


## Lava at cell `q` (`rank` 0 middle .. 1 rim, cooling first): crust plates
## of different sizes (cells of a jittered grid, smaller at the rim) drifting
## slowly over the melt, more of them crusted towards the rim, their seams
## glowing; the melt between them bright and slowly shifting.
func _lava_colour(q: Vector2i, rank: float, up: bool, inner: bool, R: Dictionary, frame: int) -> Color:
	if not inner:
		return R.shade if up else R.body
	var drift := Vector2(float(frame) * 0.06, float(frame) * 0.025)
	var p := Vector2(q) + drift
	var size := 5.0 if rank > 0.6 else 8.0
	var g := Vector2i((p / size).floor())
	var d1 := INF
	var d2 := INF
	var near := Vector2i.ZERO
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var c := g + Vector2i(ox, oy)
			# the plate's point and crust number, worked out once per shading
			var key := Vector3i(c.x, c.y, int(size))
			var site: Variant = _lava_sites.get(key)
			if site == null:
				var h := _h(c.x, c.y, 31)
				site = [(Vector2(c) + Vector2(float(h % 10) / 10.0, float((h / 10) % 10) / 10.0)) * size, _h(c.x, c.y, 47) % 100]
				_lava_sites[key] = site
			var d := p.distance_to(site[0])
			if d < d1:
				d2 = d1
				d1 = d
				near = c
			elif d < d2:
				d2 = d
	var crust := float(_lava_sites[Vector3i(near.x, near.y, int(size))][1]) / 100.0 < 0.45 + 0.45 * rank
	if d2 - d1 < 1.0:
		return R.hi if crust else R.lite
	if crust:
		return R.body if d2 - d1 < 1.8 else (R.deep if _h(q.x, q.y, 3) % 5 == 0 else R.shade)
	# the melt: mostly deep orange-red, hotter swirls running slowly through it
	var heat := 0.5 + 0.5 * sin(float(q.x) * 0.3 - float(q.y) * 0.22 + float(frame) * 0.35)
	if heat > 0.93 and _h(q.x, q.y, frame % 5) % 7 == 0:
		return R.spec
	return R.hi if heat > 0.82 else R.lite if heat > 0.45 else R.body


## Each frame over a field: bubbles that swell and pop (liquid, void, lava;
## lava's spit glowing drops), flames rising out of burning ground (particles),
## a gloss streak and a sparkle (liquid, ice, void).
func _overlay(canvas: CanvasItem, field: Dictionary, mat: String, style: String, now: float) -> void:
	var list: Array = field.list
	if list.is_empty():
		return
	var R: Dictionary = _ramps[mat]
	var spec: Dictionary = cfg.materials[mat]
	var n := int(spec.get("bubbles", 0))
	var tq := floorf(now * FPS)
	if style == "fire" and particles != null:
		_burn(field, R, spec, now)
		return
	if style == "void":
		# darkest at its rim, the darkness creeping in towards it in waves (worked
		# out on the 12 fps beat into one texture, drawn every frame)
		var tick := int(floor(now * FPS))
		if int(field.get("halo_tick", -1)) != tick:
			field.halo_tick = tick
			_halo_image(field, R.outline, float(tick) / FPS)
		if field.get("halo_tex") != null:
			canvas.draw_texture_rect(field.halo_tex, Rect2(Vector2(field.halo_at) * art, Vector2(field.halo_size) * art), false)
	if style == "fire":
		for i in range(n * 2):
			var slot := int(floor(now * 3.0 + float(i) * 0.41))
			var q: Vector2i = list[posmod(slot * 7919 + i * 104729, list.size())]
			var tall := 2 + posmod(int(tq) + i * 3, 4)
			for j in range(tall):
				var col: Color = R.spec if j == 0 else R.hi if j < tall - 1 else R.lite
				_cell(canvas, q + Vector2i(posmod(j + int(tq) + i, 3) - 1 if j > 1 else 0, -j), col)
		return
	for i in range(n):
		var phase := fmod(now * 0.8 + float(i) * 0.33, 1.0)
		var slot := int(floor(now * 0.8 + float(i) * 0.33))
		var q: Vector2i = list[posmod(slot * 7919 + i * 104729, list.size())]
		if not (field.col.has(q + Vector2i(0, 2)) and field.col.has(q + Vector2i(0, -2)) and field.col.has(q + Vector2i(2, 0)) and field.col.has(q + Vector2i(-2, 0))):
			continue
		if phase < 0.5:
			_cell(canvas, q, R.hi)
			_cell(canvas, q + Vector2i(1, 0), R.lite)
		elif phase < 0.7:
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(2, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 1), Vector2i(1, 1)]:
				_cell(canvas, q + d, R.hi)
			_cell(canvas, q, R.shade)
			_cell(canvas, q + Vector2i(1, 0), R.shade)
			# lava spits when its bubble bursts: glowing drops in arcs that cool where they land
			if style == "lava" and particles != null and int((field.get("spat", {}) as Dictionary).get(i, -1)) != slot:
				if not field.has("spat"): field.spat = {}
				field.spat[i] = slot
				_spit((Vector2(q) + Vector2(1.0, 0.5)) * art, R, 1 + posmod(slot * 3 + i, 3))
		elif phase < 0.8:
			_cell(canvas, q + Vector2i(-1, -1), R.spec)
			_cell(canvas, q + Vector2i(2, -1), R.spec)
	# a sparkle pops on the north-east rim now and then
	var rim: Array = field.rim
	if not rim.is_empty() and style in ["liquid", "ice", "void"]:
		var f := posmod(int(tq), 30)
		if f < 3:
			var q: Vector2i = rim[posmod(int(floor(now / 2.5)) * 31, rim.size())]
			_cell(canvas, q, R.spec)
			if f == 0:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					_cell(canvas, q + d, R.spec)
			elif f == 1:
				for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					_cell(canvas, q + d, R.hi)


## Burning ground: flames rise out of random burning cells (physics.fire_flames
## per cell and second, at most fire_flames_max), now and then an ember tumbles
## up or smoke rolls off; the ground itself is the baked charred floor.
func _burn(field: Dictionary, R: Dictionary, spec: Dictionary, now: float) -> void:
	var list: Array = field.list
	var last := float(field.get("burn_t", now))
	field.burn_t = now
	var dt := clampf(now - last, 0.0, 0.1)
	var rate := minf(float(list.size()) * float(_phys("fire_flames", 0.04)), float(_phys("fire_flames_max", 45)))
	var due := float(field.get("burn_carry", 0.0)) + rate * dt
	var ramp: Array = [R.spec, R.hi, R.lite, R.body, R.shade]
	while due >= 1.0:
		due -= 1.0
		var q: Vector2i = list[_rng.randi_range(0, list.size() - 1)]
		var at := (Vector2(q) + Vector2(0.5, 0.5)) * art * to_particles
		# two or three flames from one spot rise as one tongue
		particles.flames(at, 2 + _rng.randi_range(0, 1), ramp, 1.0)
		if _rng.randf() < 0.12:
			var ember: Dictionary = particles.emit(at, Vector2(_rng.randf_range(-20.0, 20.0), 0.0), R.hi, _rng.randf_range(0.6, 1.1), "ember", 2.0, 2.0, _rng.randf_range(30.0, 70.0), 1.2)
			ember.seed = _rng.randi() % 997
		if _rng.randf() < 0.06:
			particles.smoke(at, 1, 2.0)
	field.burn_carry = due


## Glowing drops spat from a lava bubble at `at` (world px): they fly in arcs
## and lie down as embers that cool to soot (particles "glut").
func _spit(at: Vector2, R: Dictionary, count: int) -> void:
	for i in range(count):
		var drop: Dictionary = particles.emit(at * to_particles, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(20.0, 60.0) * to_particles, R.hi if i == 0 else R.lite,
			1.5, "glut", 2.0, 2.0, _rng.randf_range(60.0, 120.0), 1.5)
		drop.ember_life = _rng.randf_range(0.8, 1.6)
		drop.soot = 0.6


## The warm light of fire and lava on the floor round them (the host's
## additive glow layer, `level` its strength): a soft glow over each pool that
## breathes slowly (no flicker). In world px.
func draw_glow(canvas: CanvasItem, level: float, now: float) -> void:
	if level <= 0.0:
		return
	for key: String in _pools:
		var pool: Dictionary = _pools[key]
		var mat := str(pool.mat)
		var glow := float(cfg.materials[mat].get("glow", 0.0))
		if glow <= 0.0 or now > float(pool.end) + 0.5:
			continue
		var breathe := 1.0 + 0.08 * sin(now * 1.3 + float(key.hash() % 100))
		var at: Vector2 = pool.get("at", Vector2.ZERO)
		Glow.dot(canvas, at, float(pool.get("r", 30.0)) * 1.7 * breathe, Color(_ramps[mat].lite, glow * level))


func _cell(canvas: CanvasItem, q: Vector2i, col: Color) -> void:
	canvas.draw_rect(Rect2(Vector2(q) * art, Vector2(art, art)), col)


static func _shown(q: Vector2i, k: float) -> bool:
	return float(BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)]) < k * 16.0


# ---------- the living liquid ----------

func _phys(key: String, fallback: Variant) -> Variant:
	return cfg.get("physics", {}).get(key, fallback)


## The moment a pool lands: a ring and a crown where it struck, and drops of it
## (vfx_pools.json materials.splash: drops, chips of ice, embers of fire) thrown
## up along its flight that come down again (drop_landed).
func _splash(mat: String, at: Vector2, dir: Vector2, radius: float, seed: int) -> void:
	var spec: Dictionary = cfg.materials[mat]
	var field: Dictionary = _field(mat)
	_ripple_in(field, Vector2i((at / art).floor()), 1.0, _now)
	var kind := str(spec.get("splash", "drops"))
	if particles == null or kind == "none":
		return
	_rng.seed = seed * 7919 + 13
	var R: Dictionary = _ramps[mat]
	var count := clampi(int(radius * float(_phys("drops_per_px", 0.4))), 4, int(_phys("drop_max", 22)))
	var speed: Array = _phys("drop_speed", [50, 150])
	var lift: Array = _phys("drop_lift", [50, 140])
	var flight := dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	var from := at * to_particles
	for i in range(count):
		var angle := flight.angle() + _rng.randf_range(-1.2, 1.2) if flight != Vector2.ZERO else _rng.randf() * TAU
		var fast := _rng.randf_range(float(speed[0]), float(speed[1]))
		# the liquid keeps some of its flight: more of it flies on ahead
		var velocity := (Vector2.from_angle(angle) * fast + flight * fast * 0.5) * to_particles
		var up := _rng.randf_range(float(lift[0]), float(lift[1]))
		var big := 4.0 if _rng.randf() < 0.45 else 2.0
		match kind:
			"drops":
				var drop: Dictionary = particles.emit(from, velocity, R.lite if _rng.randf() < 0.4 else R.body, 2.0, "drop", big, 2.0, up, 0.5)
				drop.land_ref = weakref(self)
				drop.land_mat = mat
			"chips":
				particles.emit(from, velocity, R.hi if _rng.randf() < 0.5 else R.lite, 1.2, "frost", 2.0, 2.0, up, 2.0)
			"embers":
				particles.emit(from, velocity, R.hi, 1.4, "glut", 2.0, 2.0, up, 2.0)


## A drop of `mat` came down at `point` (the particles' units): into its pool
## it rings it, next to it it joins it (one field, one rim), on dry floor it
## lies as a small puddle that dries (vfx_pools.json physics.drop_dry). The
## puddles are drawing only (covers() never sees them).
func drop_landed(point: Vector2, mat: String) -> void:
	if not _ramps.has(mat):
		return
	var at := point / to_particles
	var q := Vector2i((at / art).floor())
	var field: Dictionary = _field(mat)
	var have: Array = field.cells.get(q, [])
	if not have.is_empty() and float(have[0]) <= _now and _now < float(have[1]):
		_ripple_in(field, q, 0.3, _now)
		return
	# on lava, fire or the hot floor a drop of liquid hisses away and crusts it
	if _style(mat) == "liquid":
		for other: String in _fields:
			if _style(other) in ["lava", "fire"] and _live(_fields[other], q, _now):
				_hiss(at, 2)
				if _style(other) == "lava": _turn("crust", _fields[other], q, _fields[other].cells[q], _now)
				return
		if hot.is_valid() and hot.call(at):
			_hiss(at, 2)
			_hot_crust[q] = _now + float(cfg.get("reactions", {}).get("crust_time", 4.0)) * 0.5
			return
	if not open.call((Vector2(q) + Vector2(0.5, 0.5)) * art):
		return
	var dry: Array = _phys("drop_dry", [2.0, 3.5])
	var until := _now + _rng.randf_range(float(dry[0]), float(dry[1]))
	var spots: Array[Vector2i] = [q]
	if _rng.randf() < 0.6:
		spots.append(q + [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)][_rng.randi_range(0, 2)])
	for c: Vector2i in spots:
		if field.cells.has(c) or not open.call((Vector2(c) + Vector2(0.5, 0.5)) * art):
			continue
		field.cells[c] = [_now, until, 1.0, true]
	field.next = minf(float(field.next), _now)
	field.dirty = true


## A blow, a drop or a step at `at` (world px) rings the liquid lying there:
## rings run out over its surface, a crown jumps up for a strong one
## (`strength` about 0.3 a step, 1 a blast). False when no liquid lies there.
func ripple(at: Vector2, strength: float, now := -1.0) -> bool:
	var q := Vector2i((at / art).floor())
	for mat: String in _fields:
		var cracks := bool(cfg.materials[mat].get("crack", false))
		if float(cfg.materials[mat].get("ripple", 0.0)) <= 0.0 and not cracks:
			continue
		var have: Array = _fields[mat].cells.get(q, [])
		if have.is_empty():
			continue
		if cracks: _crack_in(_fields[mat], q, strength, now if now >= 0.0 else _now)
		else: _ripple_in(_fields[mat], q, strength, now if now >= 0.0 else _now)
		return true
	return false


## A blast at `at` reaching `radius` (world px) rings the liquid nearest to it
## within that reach (a blast at a pool's rim rings it from there).
func ripple_near(at: Vector2, radius: float, strength: float) -> bool:
	if ripple(at, strength):
		return true
	var middle := Vector2i((at / art).floor())
	var reach := int(radius / art)
	for mat: String in _fields:
		var cracks := bool(cfg.materials[mat].get("crack", false))
		if float(cfg.materials[mat].get("ripple", 0.0)) <= 0.0 and not cracks:
			continue
		var cells: Dictionary = _fields[mat].cells
		var best := Vector2i(1 << 30, 0)
		var best_d := INF
		for step in range(1, reach + 1, 2):
			for d: Vector2i in [Vector2i(step, 0), Vector2i(-step, 0), Vector2i(0, step), Vector2i(0, -step), Vector2i(step, step), Vector2i(-step, step), Vector2i(step, -step), Vector2i(-step, -step)]:
				var c := middle + d
				if cells.has(c) and Vector2(d).length() < best_d:
					best_d = Vector2(d).length()
					best = c
			if best_d < INF:
				break
		if best_d < INF:
			var amp := strength * (1.0 - 0.5 * best_d / float(maxi(1, reach)))
			if cracks: _crack_in(_fields[mat], best, amp, _now)
			else: _ripple_in(_fields[mat], best, amp, _now)
			return true
	return false


## A blow cracks the ice at `q`: jagged lines run out from it (drawn while
## they last, see _draw_cracks) and chips of it fly.
func _crack_in(field: Dictionary, q: Vector2i, amp: float, now: float) -> void:
	var list: Array = field.cracks
	if list.size() >= int(_phys("crack_max", 8)):
		list.pop_front()
	list.append({"q": q, "t0": now, "amp": clampf(amp, 0.2, 1.5), "seed": _rng.randi() % 997})
	if particles != null and particles.has_method("shatter"):
		particles.shatter((Vector2(q) + Vector2(0.5, 0.5)) * art * to_particles, 2 + int(amp * 3.0), Vector2.ZERO, 90.0 * to_particles, [], 2)


## The cracks in an ice field: from each blow 3-5 jagged lines (dark, a lit
## edge above them) snap out, only over the ice; they heal by the dither.
func _draw_cracks(canvas: CanvasItem, field: Dictionary, mat: String, now: float) -> void:
	var list: Array = field.cracks
	if list.is_empty():
		return
	var R: Dictionary = _ramps[mat]
	var life := float(_phys("crack_life", 2.4))
	var keep: Array = []
	for crack: Dictionary in list:
		var age := now - float(crack.t0)
		if age < 0.0 or age > life:
			continue
		keep.append(crack)
		var amp := float(crack.amp)
		var seed := int(crack.seed)
		var heal := clampf((life - age) / 0.6, 0.0, 1.0)
		var grow := minf(1.0, age / 0.08)
		for b in range(3 + int(amp * 2.0)):
			var angle := TAU * float(b) / float(3 + int(amp * 2.0)) + float(_h(seed, b, 3) % 100) / 100.0
			var length := int((4.0 + amp * 9.0) * grow * (0.6 + float(_h(seed, b, 5) % 40) / 100.0))
			var p := Vector2(crack.q) + Vector2(0.5, 0.5)
			var d := Vector2.from_angle(angle)
			for k in range(length):
				d = d.rotated(float(_h(seed + k, b, 7) % 3 - 1) * 0.35)
				p += d
				var cell := Vector2i(p.floor())
				if not field.col.has(cell) or not _shown(cell, heal):
					continue
				_cell(canvas, cell, R.deep)
				if field.col.has(cell + Vector2i(0, -1)):
					_cell(canvas, cell + Vector2i(0, -1), R.hi)
	field.cracks = keep


## A frost burst at `at` (world px) reaching `radius` freezes the liquid lying
## there (drawing only): each cell turns to ice, the pool's rim first, the
## middle last (physics.freeze_time s).
func freeze_near(at: Vector2, radius: float) -> void:
	if not cfg.materials.has("ice"):
		return
	var middle := Vector2i((at / art).floor())
	var reach := radius / art
	var span := float(_phys("freeze_time", 0.45))
	var ice: Dictionary = _field("ice")
	for mat: String in _fields.keys():
		if _style(mat) != "liquid":
			continue
		var field: Dictionary = _fields[mat]
		for q: Vector2i in field.cells:
			if not _live(field, q, _now) or Vector2(q - middle).length() > reach:
				continue
			var c: Array = field.cells[q]
			var born := _now + (1.0 - float(c[2])) * span
			if not ice.cells.has(q):
				ice.cells[q] = [born, float(c[1]), float(c[2]), true]
			_freezing.append([mat, q, born])
	ice.next = minf(float(ice.next), _now)
	ice.dirty = true


## Lightning at `at` (world px) reaching `radius`: a liquid there conducts it
## (style liquid; ice insulates): small arcs creep over the whole pool for a
## moment (physics.zap_time).
func electrify(at: Vector2, radius: float) -> void:
	var q := Vector2i((at / art).floor())
	var reach := int(radius / art)
	for mat: String in _fields:
		if _style(mat) != "liquid":
			continue
		var field: Dictionary = _fields[mat]
		var hit := false
		for dy in range(-reach, reach + 1, 2):
			for dx in range(-reach, reach + 1, 2):
				if _live(field, q + Vector2i(dx, dy), _now):
					hit = true
					break
			if hit: break
		if hit:
			(field.zaps as Array).append({"t0": _now, "seed": _rng.randi() % 997})


## The arcs crawling over a pool that conducts: short zigzags between its own
## cells, drawn anew every two frames, only over the liquid.
func _draw_zaps(canvas: CanvasItem, field: Dictionary, now: float) -> void:
	var list: Array = field.zaps
	if list.is_empty() or (field.list as Array).is_empty():
		return
	var life := float(_phys("zap_time", 0.6))
	var cols: Array = _phys("zap_cols", ["f4f6ff", "8fa4ff"])
	var keep: Array = []
	var cells: Array = field.list
	for zap: Dictionary in list:
		var age := now - float(zap.t0)
		if age < 0.0 or age > life:
			continue
		keep.append(zap)
		var beat := int(age * 30.0) / 2
		for a in range(5):
			var h := _h(int(zap.seed), beat * 7 + a, 9)
			var q: Vector2i = cells[h % cells.size()]
			var p := Vector2(q)
			for k in range(4):
				var cell := Vector2i(p.floor())
				if field.col.has(cell):
					_cell(canvas, cell, Color(str(cols[0])) if k % 2 == 0 else Color(str(cols[1])))
				p += Vector2(float(_h(h, k, 3) % 3 - 1), float(_h(h, k, 5) % 3 - 1))
	field.zaps = keep


func _ripple_in(field: Dictionary, q: Vector2i, amp: float, now: float) -> void:
	var list: Array = field.ripples
	if list.size() >= int(_phys("ripple_max", 12)):
		list.pop_front()
	list.append({"q": q, "t0": now, "amp": clampf(amp, 0.1, 1.5)})


## The rings and crowns on a field: each ring a line of light running out
## (a dark trough just inside it) only where the liquid lies, thinning by the
## dither; a strong one has a second ring and a crown of liquid jumping up.
func _draw_ripples(canvas: CanvasItem, field: Dictionary, mat: String, now: float) -> void:
	var list: Array = field.ripples
	if list.is_empty():
		return
	var R: Dictionary = _ramps[mat]
	var scale := float(cfg.materials[mat].get("ripple", 1.0))
	var speed := float(_phys("ripple_speed", 26.0)) * scale
	var life := float(_phys("ripple_life", 0.7))
	var crown := float(_phys("crown_time", 0.14))
	var keep: Array = []
	for rp: Dictionary in list:
		var age := now - float(rp.t0)
		var amp := float(rp.amp)
		var span := life * (0.5 + 0.5 * minf(1.0, amp))
		if age < 0.0 or age > span:
			continue
		keep.append(rp)
		var c: Vector2i = rp.q
		var fade := 1.0 - age / span
		if amp >= 0.5 and age < crown:
			# the crown: a spout and two leaning spikes jumping up and falling back
			var k := 1.0 - age / crown
			var tall := 1 + int(round(amp * 4.0 * k))
			for j in range(1, tall + 1):
				_cell(canvas, c + Vector2i(0, -j), R.spec if j == tall else R.hi)
				_cell(canvas, c + Vector2i(1, -j), R.lite if j < tall else R.hi)
			var side := int(round(amp * 3.0 * k))
			for j in range(1, side + 1):
				_cell(canvas, c + Vector2i(-1 - j / 2 - 1, -j + 1), R.lite)
				_cell(canvas, c + Vector2i(2 + j / 2 + 1, -j + 1), R.lite)
			# a dark ring of the splash on the floor round the spout
			for d: Vector2i in [Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]:
				_cell(canvas, c + d, R.deep)
		for ring in range(2 if amp > 0.55 else 1):
			var rr := speed * (age - float(ring) * 0.1) * (0.6 + 0.4 * minf(1.0, amp))
			if rr < 1.0:
				continue
			var n := maxi(10, int(TAU * rr))
			var last := Vector2i(1 << 30, 0)
			for i in range(n):
				var ang := TAU * float(i) / float(n)
				var cell := c + Vector2i(roundi(cos(ang) * rr), roundi(sin(ang) * rr * 0.7))
				if cell == last:
					continue
				last = cell
				if not field.col.has(cell) or not _shown(cell, minf(1.0, fade * 2.0)):
					continue
				_cell(canvas, cell, (R.spec if amp >= 0.8 and fade > 0.6 else R.hi) if ring == 0 else R.lite)
				if ring == 0:
					var inner := c + Vector2i(roundi(cos(ang) * (rr - 1.0)), roundi(sin(ang) * (rr - 1.0) * 0.7))
					if inner != cell and field.col.has(inner):
						_cell(canvas, inner, R.shade)
	field.ripples = keep


func _style(mat: String) -> String:
	return str(cfg.materials.get(mat, {}).get("style", "liquid"))


## Where two materials meet, they react (vfx_pools.json "reactions", keyed
## "<style>+<style>"): a_to / b_to "gone" hides the cell (drawing only),
## "crust" crusts lava there, a material name turns it into that material (a
## drawing-only cell); "steam" hisses. A liquid on the hot floor reacts as on lava.
func _react(now: float) -> void:
	if not _freezing.is_empty():
		var later: Array = []
		for entry: Array in _freezing:
			if float(entry[2]) > now:
				later.append(entry)
			elif _fields.has(str(entry[0])):
				var field: Dictionary = _fields[str(entry[0])]
				field.hide[entry[1]] = true
				field.dirty = true
				field.next = minf(float(field.next), now)
		_freezing = later
	var rules: Dictionary = cfg.get("reactions", {})
	if rules.is_empty() or now - _reacted < 1.0 / float(cfg.get("rebake_hz", 15)):
		return
	_reacted = now
	var mats: Array = _fields.keys()
	for a: String in mats:
		for b: String in mats:
			if a != b:
				var rule: Dictionary = rules.get(_style(a) + "+" + _style(b), {})
				if not rule.is_empty():
					_react_pair(a, b, rule, now)
		if hot.is_valid():
			var on_hot: Dictionary = rules.get(_style(a) + "+lava", {})
			if not on_hot.is_empty():
				_react_hot(a, on_hot, now)


func _live(field: Dictionary, q: Vector2i, now: float) -> bool:
	var c: Array = field.cells.get(q, [])
	return not c.is_empty() and float(c[0]) <= now and now < float(c[1]) and not (field.hide as Dictionary).has(q)


func _react_pair(a: String, b: String, rule: Dictionary, now: float) -> void:
	var fa: Dictionary = _fields[a]
	var fb: Dictionary = _fields[b]
	# only where the two lie over each other (their boxes of the last shading)
	var box_a: Rect2i = fa.get("box", Rect2i())
	var box_b: Rect2i = fb.get("box", Rect2i())
	if not box_a.has_area() or not box_b.has_area() or not box_a.intersects(box_b):
		return
	var both := box_a.intersection(box_b)
	var count := 0
	for q: Vector2i in fa.cells:
		if not both.has_point(q) or not _live(fa, q, now) or not _live(fb, q, now):
			continue
		if str(rule.get("b_to", "")) == "crust" and (fb.crust as Dictionary).has(q) and str(rule.get("a_to", "")) == "":
			continue
		_turn(str(rule.get("a_to", "")), fa, q, fa.cells[q], now)
		_turn(str(rule.get("b_to", "")), fb, q, fb.cells[q], now)
		if bool(rule.get("steam", false)) and count % int(cfg.reactions.get("steam_every", 5)) == 0:
			_hiss((Vector2(q) + Vector2(0.5, 0.5)) * art, 2)
		count += 1


func _react_hot(a: String, rule: Dictionary, now: float) -> void:
	var fa: Dictionary = _fields[a]
	var count := 0
	var crust_time := float(cfg.reactions.get("crust_time", 4.0))
	for q: Vector2i in fa.cells:
		if not _hot_cell(q) or not _live(fa, q, now):
			continue
		_turn(str(rule.get("a_to", "")), fa, q, fa.cells[q], now)
		if str(rule.get("b_to", "")) == "crust":
			_hot_crust[q] = now + crust_time
		if bool(rule.get("steam", false)) and count % int(cfg.reactions.get("steam_every", 5)) == 0:
			_hiss((Vector2(q) + Vector2(0.5, 0.5)) * art, 2)
		count += 1


## Whether art cell `q` lies on a hot floor (`hot` at its middle: the Hell's
## lava tiles), remembered like _open_cell (the tiles do not move).
func _hot_cell(q: Vector2i) -> bool:
	if _hot_memo.size() > 200000:
		_hot_memo.clear()
	var known: Variant = _hot_memo.get(q)
	if known != null:
		return bool(known)
	var burns := bool(hot.call((Vector2(q) + Vector2(0.5, 0.5)) * art))
	_hot_memo[q] = burns
	return burns


## Turns the cell `q` of `field` (its record `c`): "gone", "crust" or into a material.
func _turn(to: String, field: Dictionary, q: Vector2i, c: Array, now: float) -> void:
	match to:
		"":
			return
		"gone":
			field.hide[q] = true
		"crust":
			field.crust[q] = now + float(cfg.reactions.get("crust_time", 4.0))
		_:
			if not cfg.materials.has(to):
				return
			field.hide[q] = true
			var into: Dictionary = _field(to)
			if not into.cells.has(q):
				into.cells[q] = [now, maxf(float(c[1]), now + 1.0), float(c[2]), true]
				into.next = minf(float(into.next), now)
				into.dirty = true
	field.dirty = true
	field.next = minf(float(field.next), now)


## Every void pool pulls: a well in the particles over it (materials.void_pull
## [pull, spin] px/s, reaching 1.8 of its radius, its middle swallowing).
func _pull(now: float) -> void:
	if particles == null or not particles.has_method("well"):
		return
	for key: String in _pools:
		var pool: Dictionary = _pools[key]
		var spec: Dictionary = cfg.materials.get(str(pool.mat), {})
		var pull: Array = spec.get("void_pull", [])
		if pull.size() < 2 or now > float(pool.end):
			continue
		var r := float(pool.get("r", 30.0)) * to_particles
		particles.well("pool:" + key, Vector2(pool.get("at", Vector2.ZERO)) * to_particles, r * 1.8, float(pull[0]), float(pull[1]), r * 0.45, 0.25, float(spec.get("void_motes", 6.0)))


## Steam hissing up at `at` (world px) in the particles.
func _hiss(at: Vector2, count: int) -> void:
	if particles != null and particles.has_method("steam"):
		particles.steam(at * to_particles, count)


## The crust left on the hot floor: dark plates that glow at their seams and
## melt back into it (lit cells) before they go.
func _draw_hot_crust(canvas: CanvasItem, now: float) -> void:
	if _hot_crust.is_empty() or not _ramps.has("lava"):
		return
	var R: Dictionary = _ramps["lava"]
	for q: Vector2i in _hot_crust.keys():
		var left := float(_hot_crust[q]) - now
		if left <= 0.0:
			_hot_crust.erase(q)
			continue
		_cell(canvas, q, _crust_colour(q, left, R))


## True when a liquid (style liquid: poison, blood, water) lies at `point` (world px).
func wet_at(point: Vector2) -> bool:
	var mat := liquid_at(point)
	return mat != "" and _style(mat) == "liquid"


## A crust cell: plates of cooled rock (by value noise, a few art px across),
## bright seams of the melt between them; in its last 0.8 s the seams widen
## and it melts back in.
static func _crust_colour(q: Vector2i, left: float, R: Dictionary) -> Color:
	var n := _noise(q.x, q.y, 3, 11)
	var seam := 0.05 + (0.12 * (1.0 - left / 0.8) if left < 0.8 else 0.0)
	if absf(n - 0.5) < seam:
		return R.lite if left < 0.8 else R.body
	return R.shade if n > 0.5 else R.deep


## The material of a thrown pool lying at `point` (world px), "" on dry floor.
func liquid_at(point: Vector2) -> String:
	var q := Vector2i((point / art).floor())
	for mat: String in _fields:
		var have: Array = _fields[mat].cells.get(q, [])
		if have.size() == 3 and float(have[0]) <= _now and _now < float(have[1]):
			return mat
	return ""


## Actor `key` standing at `feet` (world px), `moving` or not: in a liquid it
## leaves a wake of small rings; out of one (materials with "steps"), a few wet
## steps behind it on alternating feet that dry (physics.steps, stride, step_dry).
func wade(key: String, feet: Vector2, moving: bool, now: float) -> void:
	var state: Dictionary = _waders.get(key, {})
	state.seen = now
	# moving also when its point moved since the last call (monsters without a flag)
	moving = moving or feet.distance_to(state.get("pos", feet)) > 0.2
	state.pos = feet
	var mat := liquid_at(feet)
	if mat != "":
		state.mat = mat
		state.steps = int(_phys("steps", 4)) if bool(cfg.materials[mat].get("steps", false)) else 0
		state.at = feet
		if moving and now - float(state.get("last", -9.0)) >= float(_phys("wade_every", 0.22)):
			state.last = now
			ripple(feet, 0.45, now)
	elif moving and int(state.get("steps", 0)) > 0 and particles != null and state.has("mat"):
		var from: Vector2 = state.get("at", feet)
		if from.distance_to(feet) >= float(_phys("stride", 12.0)) * art / 2.0:
			state.at = feet
			state.steps = int(state.steps) - 1
			state.side = -float(state.get("side", 1.0))
			var R: Dictionary = _ramps[str(state.mat)]
			var dry: float = float(_phys("step_dry", 2.5)) * (0.6 + 0.4 * float(state.steps) / maxf(1.0, float(_phys("steps", 4))))
			var foot := (feet + Vector2(float(state.side) * art, 0.0)) * to_particles
			# a wet sole: 2 x 2 of the liquid, its upper left cell glinting
			particles.wet(foot + Vector2(2.0, 0.0), R.body, dry)
			particles.wet(foot + Vector2(0.0, 2.0), R.body, dry * 0.9)
			particles.wet(foot + Vector2(2.0, 2.0), R.shade, dry * 0.8)
			particles.wet(foot, R.lite, dry * 0.6)
	_waders[key] = state


static func _h(x: int, y: int, s := 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) % 1000


## Smooth value noise 0..1 over cells of `size` art px.
static func _noise(x: int, y: int, size: int, s: int) -> float:
	var fx := float(x) / float(size)
	var fy := float(y) / float(size)
	var gx := floori(fx)
	var gy := floori(fy)
	var u := fx - float(gx)
	var v := fy - float(gy)
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var a := float(_h(gx, gy, s)) / 1000.0
	var b := float(_h(gx + 1, gy, s)) / 1000.0
	var c := float(_h(gx, gy + 1, s)) / 1000.0
	var e := float(_h(gx + 1, gy + 1, s)) / 1000.0
	return lerpf(lerpf(a, b, u), lerpf(c, e, u), v)
