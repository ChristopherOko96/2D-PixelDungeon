extends RefCounted
## Shared circular annulus geometry. Gameplay uses actor footprints; art uses
## cells wholly inside the band, so no pixel of the material fills its hole.

## Actor footprint touches the band; actors wholly inside the hole are free.
static func intersects(center: Vector2, outer: float, inner: float, point: Vector2, radius: float) -> bool:
	var distance := center.distance_to(point)
	return distance <= outer + radius and distance + radius >= inner

## A ring sees only the floor reachable in a straight line from its caster.
static func visible(center: Vector2, point: Vector2, open_floor: Callable, step: float = 4.0) -> bool:
	if not open_floor.is_valid(): return true
	var count := maxi(1, ceili(center.distance_to(point) / maxf(1.0, step)))
	for index in range(count + 1):
		if not open_floor.call(center.lerp(point, float(index) / count)): return false
	return true

## Same world-space circular band as the host; no liquid squash or volume flood
## can fill the middle. One bounded build per field, with memoized floor tests.
static func cells(center: Vector2, outer: float, inner: float, art: float, open_floor: Callable) -> Dictionary:
	var result := {}
	if outer <= inner or inner < 0.0 or art <= 0.0: return result
	var low := Vector2i(((center - Vector2.ONE * outer) / art).floor())
	var high := Vector2i(((center + Vector2.ONE * outer) / art).ceil())
	var margin := art * sqrt(0.5)
	var floor_cache := {}
	var ordered: Array = []
	var floor_test := func(p: Vector2) -> bool:
		var q := Vector2i((p / art).floor())
		if not floor_cache.has(q): floor_cache[q] = not open_floor.is_valid() or bool(open_floor.call((Vector2(q) + Vector2.ONE * 0.5) * art))
		return bool(floor_cache[q])
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var q := Vector2i(x, y)
			var p := (Vector2(q) + Vector2.ONE * 0.5) * art
			var distance := center.distance_to(p)
			if distance < inner + margin or distance > outer - margin: continue
			if visible(center, p, floor_test, art): ordered.append({"cell": q, "depth": distance})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) < float(b.depth))
	for entry: Dictionary in ordered: result[entry.cell] = result.size()
	return result
