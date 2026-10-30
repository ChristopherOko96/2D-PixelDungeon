extends RefCounted
## The shape of a splat of liquid on the art grid, from where it lands, which
## way it was flying and how much there is (vfx_pools.json). The liquid runs
## out cell by cell from the landing point, cheapest first (a Dijkstra flood
## over the art pixels): a step along the flight costs less (it keeps sliding
## that way), a step up or down the screen costs more (the floor seen at a
## slant), and a little smooth noise roughens the rim. Walls and solid props
## stop it; the volume it could not spend there runs on along them, so a splat
## thrown into a corner fills the corner and spreads along both walls, and one
## that lands in the open is a rounded, stretched blot. Fast splats fling a
## few droplets ahead. Pure and deterministic (same inputs, same cells), so
## the server's hit test and every client's drawing agree.

const STEPS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
## Cost buckets per unit of path cost.
const QUANT := 4.0


## Cells (Vector2i art px -> rank 0..n-1, the order the liquid reached them) of
## a splat of `count` cells landing at `origin` (world px) moving along `dir`
## (ZERO: straight down, a round blot). `art`: world px per art pixel; `open`:
## Callable(world point) -> bool, true on floor the liquid may cover; `seed`
## varies the rim; `squash` < 1 flattens it (the floor seen at a slant);
## `momentum` 0..1 how strongly it runs on along the flight; `droplets` how
## many drops a fast splat flings ahead.
static func flood(origin: Vector2, dir: Vector2, count: int, art: float, open: Callable, seed: int,
		squash := 0.75, momentum := 0.5, droplets := 0) -> Dictionary:
	var out := {}
	if count <= 0:
		return out
	var memo := {}
	var start := _nearest_open(Vector2i((origin / art).floor()), art, open, memo)
	if start == Vector2i(1 << 30, 1 << 30):
		return out
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	var main := count - _droplet_budget(count, droplets)
	_spread(out, start, d, main, art, open, memo, seed, squash, momentum)
	if droplets > 0 and d != Vector2.ZERO:
		_fling(out, start, d, count - main, droplets, art, open, memo, seed, squash)
	return out


## How many cells the droplets take from the volume.
static func _droplet_budget(count: int, droplets: int) -> int:
	return 0 if droplets <= 0 else mini(count / 5, droplets * maxi(3, count / 60))


static func _spread(out: Dictionary, start: Vector2i, d: Vector2, count: int, art: float, open: Callable, memo: Dictionary,
		seed: int, squash: float, momentum: float) -> void:
	# per step: its length on the slanted floor and how much it runs along the
	# flight, worked out once (the same numbers as working them out per step)
	var lengths: Array = []
	var alongs: Array = []
	for step: Vector2i in STEPS:
		var v := Vector2(step)
		lengths.append(Vector2(v.x, v.y / squash).length())
		alongs.append(d.dot(v.normalized()) if d != Vector2.ZERO else 0.0)
	# each cell's rim noise once (the walls are asked once per cell through `memo`)
	var rough := {}
	var best := {start: 0.0}
	var buckets: Array = [[start]]
	var at := 0
	var target := out.size() + count
	while out.size() < target and at < buckets.size():
		var bucket: Array = buckets[at]
		if bucket.is_empty():
			at += 1
			continue
		var q: Vector2i = bucket.pop_back()
		if out.has(q):
			continue
		out[q] = out.size()
		var here: float = best[q]
		for s in range(8):
			var step: Vector2i = STEPS[s]
			var n: Vector2i = q + step
			if out.has(n):
				continue
			var ok: Variant = memo.get(n)
			if ok == null:
				ok = open.call((Vector2(n) + Vector2(0.5, 0.5)) * art)
				memo[n] = ok
			if not ok:
				continue
			# a diagonal only through an open corner, so nothing leaks through a wall seam
			if step.x != 0 and step.y != 0:
				var side := q + Vector2i(step.x, 0)
				var free: Variant = memo.get(side)
				if free == null:
					free = open.call((Vector2(side) + Vector2(0.5, 0.5)) * art)
					memo[side] = free
				if not free:
					continue
				side = q + Vector2i(0, step.y)
				free = memo.get(side)
				if free == null:
					free = open.call((Vector2(side) + Vector2(0.5, 0.5)) * art)
					memo[side] = free
				if not free:
					continue
			var noise: Variant = rough.get(n)
			if noise == null:
				noise = _noise(n, seed)
				rough[n] = noise
			var cost: float = here + float(lengths[s]) * (1.0 - 0.6 * momentum * float(alongs[s])) * (0.7 + 0.6 * float(noise))
			if cost < float(best.get(n, INF)):
				best[n] = cost
				var k := int(cost * QUANT)
				while buckets.size() <= k:
					buckets.append([])
				buckets[k].append(n)


## A few drops flung ahead along `d`: each a small blot of its own where it
## lands, only where the flight there is not walled off.
static func _fling(out: Dictionary, start: Vector2i, d: Vector2, budget: int, n: int, art: float, open: Callable,
		memo: Dictionary, seed: int, squash: float) -> void:
	var reach := sqrt(float(out.size())) * 0.75
	var each := maxi(2, budget / maxi(1, n))
	for i in range(n):
		var h := _hash(i, seed, 41)
		var turn := (float(h % 100) / 100.0 - 0.5) * 0.9
		var far := reach * (1.25 + float(_hash(i, seed, 43) % 70) / 100.0)
		var land := start + Vector2i((d.rotated(turn) * far * Vector2(1.0, squash)).round())
		# the drop flies there over open floor only
		var ok := true
		for s in range(1, 9):
			var p := start + Vector2i((Vector2(land - start) * float(s) / 8.0).round())
			if not _open(p, art, open, memo):
				ok = false
				break
		if ok and not out.has(land):
			_spread(out, land, d, each, art, open, memo, seed + i * 7, squash, 0.2)


static func _open(q: Vector2i, art: float, open: Callable, memo: Dictionary) -> bool:
	if memo.has(q):
		return memo[q]
	var ok: bool = open.call((Vector2(q) + Vector2(0.5, 0.5)) * art)
	memo[q] = ok
	return ok


## The open cell nearest to `q` (within a few cells), for a splat landing on a wall's edge.
static func _nearest_open(q: Vector2i, art: float, open: Callable, memo: Dictionary) -> Vector2i:
	if _open(q, art, open, memo):
		return q
	for r in range(1, 9):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) == r and _open(q + Vector2i(x, y), art, open, memo):
					return q + Vector2i(x, y)
	return Vector2i(1 << 30, 1 << 30)


static func _hash(x: int, y: int, s := 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) % 1000


## Smooth value noise 0..1 over cells of 3 art px.
static func _noise(q: Vector2i, seed: int) -> float:
	var fx := float(q.x) / 3.0
	var fy := float(q.y) / 3.0
	var gx := floori(fx)
	var gy := floori(fy)
	var u := fx - float(gx)
	var v := fy - float(gy)
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var a := float(_hash(gx, gy, seed)) / 1000.0
	var b := float(_hash(gx + 1, gy, seed)) / 1000.0
	var c := float(_hash(gx, gy + 1, seed)) / 1000.0
	var e := float(_hash(gx + 1, gy + 1, seed)) / 1000.0
	return lerpf(lerpf(a, b, u), lerpf(c, e, u), v)


## Cell count for a splat that covers about the area of a circle of `radius`
## world px (squashed like the floor), so a pool keeps its old volume.
static func cells_for(radius: float, art: float, squash := 0.75) -> int:
	return maxi(4, int(PI * radius * radius * squash / (art * art)))
