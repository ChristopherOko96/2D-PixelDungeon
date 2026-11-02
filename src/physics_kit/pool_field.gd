class_name PoolField
extends RefCounted
## Pools of liquid on the floor as gameplay: the truth of what lies under a
## point (BAUPLAN M1d). A pool is thrown by a zone (a puddle of lava, a potion,
## a spell's poison) and runs out cell by cell over the art grid from where it
## landed along its flight, stopped by walls (the splat flood,
## src/vfx/splat_shape.gd / MatterKit.flood). Each cell of it is born while the
## pool spreads (spread_time) and goes rim first at its end (edge_time). Pools
## of one material that overlap are one sheet: where they meet, a cell keeps
## the earlier birth, the later end and the lower rank.
##
## What it answers (every call on the field's own clock, see advance()):
## - materials_at(point): the materials lying there (the exposure kit's pools_under);
## - covers(point, style): a pool of that style lies there (a monster's lava contact);
## - liquid_at / wet_at, pools_at (with their owner), centre (a pool's middle).
## What changes it: sync / add (zones come and go), finish (a pool ends early,
## rim first), freeze_near (the rules' frost turns liquid to ice one stands
## on), thaw_near (fire takes that ice again), evaporate (a reaction uses a pool up).
##
## Values: assets/data/vfx_pools.json (squash, momentum, spread_time,
## edge_time, materials, physics.freeze_time, physics.splash_window,
## thread_cells, shape_commit_s, shape_commit_per_1000_cells_s, purge_every_s;
## see its _field_note).
##
## Determinism: everything here runs on the host's clock (the `now` it passes
## to sync / advance), never on the drawing's frames or the machine's time. A
## pool of thread_cells cells or more is shaped on a worker thread; it counts
## from commit_delay(cells) s after the field first saw it (by its size), on
## every machine the same: at that moment the field waits for the worker if it
## is not done yet.
## clear() waits for every worker, so a world may be freed right after it.
##
## Drawing is someone else's: src/vfx/pool_paint.gd draws this field (with
## drop puddles, melt water and reaction looks of its own that never count
## here). With track_events on, the field lists what changed (take_events()).
##
## The host is a FieldHost (src/physics_kit/field_host.gd): it only says where
## the floor is open.
##
## [codeblock]
## var field := PoolField.new(3.0, PoolField.CallableHost.new(func(p: Vector2) -> bool: return p.x < 600.0))
## field.sync([{"id": 1, "k": "pool", "st": "poison", "x": 300.0, "y": 200.0, "r": 60.0, "p": 0.0, "L": 5.0}], 0.0)
## field.advance(1.0)
## print(field.materials_at(Vector2(300, 200)))  # ["poison"]
## [/codeblock]

const Host := preload("res://src/physics_kit/field_host.gd")
const CallableHost := preload("res://src/physics_kit/callable_field_host.gd")
const SplatShape := preload("res://src/vfx/splat_shape.gd")
const ElementRules := preload("res://src/combat/element_rules.gd")
const DATA_PATH := "res://assets/data/vfx_pools.json"

## World px per art cell (the grid the pools lie on).
var art := 2.0
## Where the floor is open (src/physics_kit/field_host.gd).
var host: RefCounted
## vfx_pools.json (shared with the painter; a test may set its own copy).
var cfg: Dictionary = {}
## True: the field lists every change for a painter (take_events()).
var track_events := false

## The field's clock: the host's time of the last sync / advance (s).
var _now := 0.0
## material -> {Vector2i art cell: [born, until, rank 0..1]} for a pool's cells,
## [born, until, rank, true] for ice frozen out of a liquid (freeze_near).
var _cells: Dictionary = {}
## "source:id" -> {key, id, source, style, mat, at, dir, r, start, end, owner,
## splash, cells: Array[Vector2i] (in the order the liquid reached them),
## shape: {Vector2i: rank}}: the pools laid.
var _pools: Dictionary = {}
## "source:id" -> a pool being shaped on a worker thread: its record so far,
## task, commit (the field's time it counts from), out {cells, timed}.
var _shaping: Dictionary = {}
var _events: Array = []
var _next_purge := 0.0
static var _data: Dictionary = {}


## A field on an art grid of `art_px` world px per cell, its open floor told by
## `field_host` (a FieldHost; null: open everywhere).
func _init(art_px := 2.0, field_host: RefCounted = null) -> void:
	art = art_px
	host = field_host if field_host != null else Host.new()
	cfg = settings()


## vfx_pools.json, read once and shared (the painter reads the same).
static func settings() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {"materials": {}}
	return _data


## The cells (Vector2i art cell -> rank 0..n-1, the order the liquid reached
## them) a splat of material `style` covers, landing at `at` (world px) along
## `dir` with the volume of a circle of `radius`; the same on every machine.
## `open_floor`: Callable(world point) -> bool.
static func shape(at: Vector2, dir: Vector2, radius: float, style: String, art_px: float, open_floor: Callable, seed: int) -> Dictionary:
	var c := settings()
	var squash := float(c.get("squash", 0.75))
	var mat: Dictionary = c.get("materials", {}).get(style, {})
	var drops := int(mat.get("droplets", 0)) if dir.length() > 0.01 else 0
	return SplatShape.flood(at, dir, SplatShape.cells_for(radius, art_px, squash), art_px, open_floor, seed, squash, float(c.get("momentum", 0.55)), drops)


## The key of pool `id` of `source` (each source numbers its own pools).
static func key_of(source: String, id: int) -> String:
	return "%s:%d" % [source, id]


## When each cell of a shape (`cells`: art cell -> rank) is born and goes:
## {cell: [born, until, k]} in the shape's order, born spreading out from the
## middle over `spread` s, gone rim first over the last `edge` s. Pure: a
## worker thread may ask it.
static func timings(cells: Dictionary, start: float, end: float, spread: float, edge: float) -> Dictionary:
	var out := {}
	var n := float(maxi(1, cells.size()))
	for q: Vector2i in cells:
		var k := float(cells[q]) / n
		out[q] = [start + spread * pow(k, 0.7), end - edge * k, k]
	return out


# ---------- materials ----------

## The material a zone style lies as here ("" when vfx_pools.json has none):
## the style itself, else its material by the element rules (flesh is blood,
## curse is void, magma is lava).
func material_for(style: String) -> String:
	var mats: Dictionary = cfg.get("materials", {})
	if mats.has(style):
		return style
	var mat := ElementRules.material(style)
	return mat if mats.has(mat) else ""


## True when `style` lies as a pool here.
func handles(style: String) -> bool:
	return material_for(style) != ""


## A material's style (liquid, void, ice, fire, lava; vfx_pools.json).
func style_of(mat: String) -> String:
	return str((cfg.get("materials", {}) as Dictionary).get(mat, {}).get("style", "liquid"))


# ---------- the clock and the zones ----------

## The field's clock (s, the host's time of the last sync / advance).
func clock() -> float:
	return _now


## Moves the field's clock to `now` (the host's time): the pools whose shape
## a worker thread worked out count from now when their moment has come, and
## cells long gone are forgotten (every purge_every_s s).
func advance(now: float) -> void:
	_now = now
	if not _shaping.is_empty():
		_commit(false)
	if now >= _next_purge or now < _next_purge - float(cfg.get("purge_every_s", 1.0)) * 2.0:
		_purge(now)


## Takes in a source's zones ({id, k "pool", st style, x, y, r, dx, dy, p 0..1
## of its time gone, L its length in s, owner}) at the host's time `now`: new
## ones are laid, that source's pools that left the list go rim first.
func sync(zones: Array, now: float, source := "") -> void:
	advance(now)
	var seen := {}
	for zone: Dictionary in zones:
		var key := sync_zone(zone, now, source)
		if key != "":
			seen[key] = true
	end_missing(seen, now, source)


## One zone of a sync (see sync): laid when it is new. Returns its key, "" when
## it is no pool of a known material.
func sync_zone(zone: Dictionary, now: float, source := "") -> String:
	if str(zone.get("k", "")) != "pool" or not handles(str(zone.get("st", ""))):
		return ""
	var id := int(zone.get("id", -1))
	var key := key_of(source, id)
	if not _pools.has(key) and not _shaping.has(key):
		var length := float(zone.get("L", 4.0))
		var start := now - float(zone.get("p", 0.0)) * length
		var window := float((cfg.get("physics", {}) as Dictionary).get("splash_window", 0.25))
		add(id, str(zone.st), Vector2(float(zone.x), float(zone.y)), Vector2(float(zone.get("dx", 0.0)), float(zone.get("dy", 0.0))),
			float(zone.r), start, start + length, source, now - start <= window, int(zone.get("owner", 0)))
	return key


## The end of a sync: `source`'s pools not in `seen` (key -> true) end now,
## rim first; edge_time s after their end they are forgotten.
func end_missing(seen: Dictionary, now: float, source := "") -> void:
	var edge := float(cfg.get("edge_time", 0.7))
	for key: String in _pools.keys():
		if str(_pools[key].source) != source or seen.has(key):
			continue
		finish(key, now)
		if float(_pools[key].end) + edge < now:
			_pools.erase(key)


## A pool `id` of `style` from `source` landing at `at` along `dir` (radius as
## its volume), lasting from `start` until `end` (the host's clock); `splash`:
## it has just landed (a painter throws its drops); `owner`: who threw it (0
## none). A known pool is kept. A small one lies at once; one of thread_cells
## cells or more is shaped on a worker thread and counts from commit_delay s
## after now.
func add(id: int, style: String, at: Vector2, dir: Vector2, radius: float, start: float, end: float, source := "", splash := false, owner := 0) -> void:
	var key := key_of(source, id)
	if _pools.has(key) or _shaping.has(key):
		return
	var mat := material_for(style)
	if mat == "":
		return
	var job := {"key": key, "id": id, "source": source, "style": style, "mat": mat, "at": at, "dir": dir, "r": radius,
		"start": start, "end": end, "owner": owner, "splash": splash}
	var squash := float(cfg.get("squash", 0.75))
	var count := SplatShape.cells_for(radius, art, squash)
	if count >= int(cfg.get("thread_cells", 600)):
		# the worker only writes into `out`; the field reads it once the task is done
		var out := {}
		var cell_px := art
		var floor_open := Callable(host, "is_open")
		var spread := _spread_of(mat)
		var edge := _edge_of(start, end)
		job.out = out
		job.commit = _now + commit_delay(count)
		# a big pool spreads from the moment it is laid, not from its zone's start (it would pop in
		# already spread; physics plan R12/F19). commit depends only on the cell count: the same
		# on every machine
		var born := maxf(start, float(job.commit))
		job.task = WorkerThreadPool.add_task(func() -> void:
			var cells := shape(at, dir, radius, mat, cell_px, floor_open, id)
			out.timed = timings(cells, born, end, spread, edge)
			out.cells = cells)
		_shaping[key] = job
		return
	_lay(job, shape(at, dir, radius, mat, art, Callable(host, "is_open"), id), {})


## How long after the field first sees it a pool of `cells` cells shaped on a
## worker thread counts (s of the host's clock): shape_commit_s at least,
## shape_commit_per_1000_cells_s for every thousand cells (a big pool takes
## its worker longer; the field waits for it only when even that was too short).
func commit_delay(cells: int) -> float:
	return maxf(float(cfg.get("shape_commit_s", 0.05)), float(cells) / 1000.0 * float(cfg.get("shape_commit_per_1000_cells_s", 0.066)))


## Pool `key` ends at `now` (its zone was removed, or a reaction used it up):
## it goes rim first from then (half edge_time). Nothing when it ended already.
func finish(key: String, now: float) -> void:
	if _shaping.has(key):
		# not laid yet: it ends the moment it is
		_shaping[key].finish = minf(float(_shaping[key].get("finish", INF)), now)
		return
	var pool: Dictionary = _pools.get(key, {})
	if pool.is_empty() or float(pool.end) <= now:
		return
	var into: Dictionary = _cells.get(str(pool.mat), {})
	var edge := float(cfg.get("edge_time", 0.7)) * 0.5
	for q: Vector2i in pool.cells:
		var have: Variant = into.get(q)
		if have != null and (have as Array).size() == 3:
			have[1] = minf(float(have[1]), now + edge * (1.0 - float(have[2])))
	pool.end = now
	_note({"kind": "finished", "key": key, "mat": str(pool.mat), "now": now})


## Same as finish: pool `key` goes rim first from `now`.
func remove(key: String, now: float) -> void:
	finish(key, now)


# ---------- what lies where ----------

## True when `point` (world px) lies in a pool of `style` (any pool when "").
## Ice frozen out of a liquid is ground, not a pool: it does not count here.
func covers(point: Vector2, style := "") -> bool:
	var want := ""
	if style != "":
		want = material_for(style)
		if want == "":
			return false
	var q := Vector2i((point / art).floor())
	for mat: String in _cells:
		if want != "" and mat != want:
			continue
		var c: Variant = _cells[mat].get(q)
		if c != null and (c as Array).size() == 3 and float(c[0]) <= _now and _now < float(c[1]):
			return true
	return false


## The materials of everything lying under `point` (world px), for the game's
## rules (ElementRules.top picks the one that counts); [] on firm floor.
## A pool's own cells and the ice frozen out of a liquid count.
func materials_at(point: Vector2) -> Array:
	var q := Vector2i((point / art).floor())
	var out: Array = []
	for mat: String in _cells:
		var c: Variant = _cells[mat].get(q)
		if c != null and float(c[0]) <= _now and _now < float(c[1]):
			out.append(mat)
	return out


## The material of a pool lying at `point` (world px), "" on dry floor.
func liquid_at(point: Vector2) -> String:
	var q := Vector2i((point / art).floor())
	for mat: String in _cells:
		var c: Variant = _cells[mat].get(q)
		if c != null and (c as Array).size() == 3 and float(c[0]) <= _now and _now < float(c[1]):
			return mat
	return ""


## True when a liquid (style liquid: poison, blood, water) lies at `point`.
func wet_at(point: Vector2) -> bool:
	var mat := liquid_at(point)
	return mat != "" and style_of(mat) == "liquid"


## The pools whose own liquid lies at `point` (world px) now: their records
## ({key, style, mat, owner, source, at, r, start, end, ...}; read only).
func pools_at(point: Vector2) -> Array:
	var q := Vector2i((point / art).floor())
	var out: Array = []
	for key: String in _pools:
		var pool: Dictionary = _pools[key]
		if not (pool.shape as Dictionary).has(q):
			continue
		var c: Variant = (_cells.get(str(pool.mat), {}) as Dictionary).get(q)
		if c != null and float(c[0]) <= _now and _now < float(c[1]):
			out.append(pool)
	return out


## The landing point of the nearest pool of `style`'s material round `at`
## that has not ended (a void pulls towards it); `at` itself when none lies.
func centre(at: Vector2, style: String) -> Vector2:
	var mat := material_for(style)
	var best := at
	var best_d := INF
	for key: String in _pools:
		var pool: Dictionary = _pools[key]
		if str(pool.mat) != mat or float(pool.end) <= _now:
			continue
		var d := at.distance_squared_to(pool.at)
		if d < best_d:
			best_d = d
			best = pool.at
	return best


## True when pool `key` lies in the field (shaped and laid).
func has_pool(key: String) -> bool:
	return _pools.has(key)


## Pool `key`'s record ({} when it does not lie here); read only.
func pool(key: String) -> Dictionary:
	return _pools.get(key, {})


## Every pool laid, key -> record, in the order they were laid; read only.
func pools() -> Dictionary:
	return _pools


## The cells of material `mat` (Vector2i -> [born, until, rank(, frozen)]);
## read only (a painter draws them).
func cells_of(mat: String) -> Dictionary:
	return _cells.get(mat, {})


## The materials that have cells, in the order they first got them.
func materials() -> Array:
	return _cells.keys()


## How many pools a worker thread is still shaping.
func pending() -> int:
	return _shaping.size()


# ---------- what the rules do to it ----------

## The rules' frost at `at` (world px) reaching `radius`: the liquid lying
## there (style liquid) turns to ice one stands on, rim first, the middle last
## (physics.freeze_time s), lasting as long as the liquid would. Returns how
## many cells it froze.
func freeze_near(at: Vector2, radius: float) -> int:
	if not (cfg.get("materials", {}) as Dictionary).has("ice"):
		return 0
	var middle := Vector2i((at / art).floor())
	var reach := radius / art
	var span := float((cfg.get("physics", {}) as Dictionary).get("freeze_time", 0.45))
	var ice := _material("ice")
	var frozen: Array = []
	# only the liquids that freeze (cfg "freezes", water when absent; decision D4): frost no
	# longer turns poison or blood into Glatteis
	var freezes: Array = cfg.get("freezes", ["water"])
	for mat: String in _cells.keys():
		if style_of(mat) != "liquid" or not freezes.has(mat):
			continue
		var into: Dictionary = _cells[mat]
		for q: Vector2i in into:
			var c: Array = into[q]
			if not (float(c[0]) <= _now and _now < float(c[1])) or Vector2(q - middle).length() > reach:
				continue
			var born := _now + (1.0 - float(c[2])) * span
			if not ice.has(q):
				ice[q] = [born, float(c[1]), float(c[2]), true]
			frozen.append([mat, q, born])
	_note({"kind": "frozen", "cells": frozen})
	return frozen.size()


## Fire at `at` (world px) reaching `radius` takes the ice frozen out of a
## liquid there (the liquid under it is there again). Returns how many cells thawed.
func thaw_near(at: Vector2, radius: float) -> int:
	var ice: Dictionary = _cells.get("ice", {})
	if ice.is_empty():
		return 0
	var middle := Vector2i((at / art).floor())
	var reach := radius / art
	var gone: Array = []
	for q: Vector2i in ice:
		var c: Array = ice[q]
		if c.size() > 3 and bool(c[3]) and Vector2(q - middle).length() <= reach:
			gone.append(q)
	for q: Vector2i in gone:
		ice.erase(q)
	if not gone.is_empty():
		_note({"kind": "thawed", "cells": gone})
	return gone.size()


## A reaction uses the pools up that lie within `radius` of `at` (world px):
## those of the materials in `mats` (every liquid when empty) end now, rim
## first. Returns their keys.
func evaporate(at: Vector2, radius: float, mats: Array = []) -> Array:
	var middle := Vector2i((at / art).floor())
	var reach := radius / art
	var ended: Array = []
	for key: String in _pools:
		var pool: Dictionary = _pools[key]
		var mat := str(pool.mat)
		if float(pool.end) <= _now or (mats.is_empty() and style_of(mat) != "liquid") or (not mats.is_empty() and not mats.has(mat)):
			continue
		var into: Dictionary = _cells.get(mat, {})
		for q: Vector2i in pool.cells:
			var c: Variant = into.get(q)
			if c != null and float(c[0]) <= _now and _now < float(c[1]) and Vector2(q - middle).length() <= reach:
				ended.append(key)
				break
	for key: String in ended:
		finish(key, _now)
	return ended


# ---------- changes for a painter ----------

## What changed since the last call, oldest first (only with track_events):
## {kind "laid", key} a pool lies now; {kind "finished", key, mat, now} it
## ends early; {kind "frozen", cells: [[liquid mat, cell, born]]};
## {kind "thawed", cells: [cell]}.
func take_events() -> Array:
	var out := _events
	_events = []
	return out


## Waits for the worker threads, then forgets every pool (a new room, the end of a world).
func clear() -> void:
	for key: String in _shaping:
		WorkerThreadPool.wait_for_task_completion(int(_shaping[key].task))
	_shaping.clear()
	_pools.clear()
	_cells.clear()
	_events.clear()


# ---------- inside ----------

func _note(event: Dictionary) -> void:
	if track_events:
		_events.append(event)


func _material(mat: String) -> Dictionary:
	if not _cells.has(mat):
		_cells[mat] = {}
	return _cells[mat]


## How long material `mat` takes to spread out from its middle (s).
func _spread_of(mat: String) -> float:
	return float(cfg.get("spread_time", 0.35)) * float((cfg.get("materials", {}) as Dictionary).get(mat, {}).get("spread_scale", 1.0))


## How long before its end a pool lasting `start`..`end` begins to go, rim first (s).
func _edge_of(start: float, end: float) -> float:
	return minf(float(cfg.get("edge_time", 0.7)), maxf(0.1, (end - start) * 0.4))


## Lays the worker-shaped pools whose moment has come (all of them with `every`),
## waiting for their workers when needed, in the order they were seen.
func _commit(every: bool) -> void:
	for key: String in _shaping.keys():
		var job: Dictionary = _shaping[key]
		if not every and _now < float(job.commit):
			continue
		WorkerThreadPool.wait_for_task_completion(int(job.task))
		_shaping.erase(key)
		var out: Dictionary = job.out
		_lay(job, out.get("cells", {}), out.get("timed", {}))
		if job.has("finish"):
			finish(key, float(job.finish))


## Puts pool `job` (its `cells`: art cell -> rank; `timed` their timings when a
## worker worked them out) into its material: where a pool cell of it lies or
## is still coming, they become one (the earlier birth, the later end, the
## lower rank); anything else there (ice frozen out of a liquid, a cell gone)
## gives way.
func _lay(job: Dictionary, cells: Dictionary, timed: Dictionary) -> void:
	var key := str(job.key)
	if cells.is_empty() or _pools.has(key):
		return
	var mat := str(job.mat)
	var into := _material(mat)
	if timed.is_empty():
		timed = timings(cells, float(job.start), float(job.end), _spread_of(mat), _edge_of(float(job.start), float(job.end)))
	var keys := timed.keys()
	for q: Vector2i in keys:
		var fresh: Array = timed[q]
		var have: Variant = into.get(q)
		if have != null and (have as Array).size() <= 3 and _now < float(have[1]):
			fresh[0] = minf(float(have[0]), float(fresh[0]))
			fresh[1] = maxf(float(have[1]), float(fresh[1]))
			fresh[2] = minf(float(have[2]), float(fresh[2]))
		into[q] = fresh
	var pool := {"key": key, "id": int(job.id), "source": str(job.source), "style": str(job.style), "mat": mat, "at": job.at, "dir": job.dir,
		"r": float(job.r), "start": float(job.start), "end": float(job.end), "owner": int(job.owner), "splash": bool(job.splash),
		"cells": keys, "shape": cells}
	_pools[key] = pool
	_note({"kind": "laid", "key": key})


## Forgets the cells whose time is over (they count nowhere any more) and the
## materials left without cells.
func _purge(now: float) -> void:
	for mat: String in _cells.keys():
		var into: Dictionary = _cells[mat]
		for q: Vector2i in into.keys():
			if now >= float(into[q][1]):
				into.erase(q)
		if into.is_empty():
			_cells.erase(mat)
	_next_purge = now + float(cfg.get("purge_every_s", 1.0))
