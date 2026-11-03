extends RefCounted
const Spirit = preload("res://src/rig/soul_spirit_rig.gd")
const Shape = preload("res://src/combat/soul_ring_shape.gd")

## A capsule of actual ground cells; neither a row of round decals nor a large
## bounding disc. Built once per trail, then shared material shading animates it.
static func cells(from: Vector2, to: Vector2, half: float, art: float, open_floor: Callable) -> Dictionary:
	var result := {}
	var low := Vector2i(((from.min(to) - Vector2.ONE * half) / art).floor())
	var high := Vector2i(((from.max(to) + Vector2.ONE * half) / art).ceil())
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var p := (Vector2(x, y) + Vector2.ONE * 0.5) * art
			var base := Geometry2D.get_closest_point_to_segment(p, from, to)
			if base.distance_to(p) > half - art * 0.7072: continue
			if open_floor.is_valid() and (not open_floor.call(p) or not Shape.visible(base, p, open_floor, art)): continue
			result[Vector2i(x, y)] = result.size()
	return result

## Independently rising four-part spirits follow the real narrow footprint.
static func draw(canvas: CanvasItem, zone: Dictionary, age: float, art: float, sprites: RefCounted) -> void:
	var path: Array = zone.get("path", [])
	if path.size() < 2: return
	var from := Vector2(float(path[0][0]), float(path[0][1]))
	var to := Vector2(float(path[-1][0]), float(path[-1][1]))
	var fade := smoothstep(0.0, 0.25, age) * clampf((float(zone.total) - age) / 0.5, 0.0, 1.0)
	for i in range(7):
		var seed := i / 7.0
		var base := from.lerp(to, (i + 0.5) / 7.0)
		var p := fposmod(maxf(0.0, age - seed * 0.7) / 2.8, 1.0)
		var opacity := smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.65, 1.0, p)) * fade
		if age < seed * 0.7: opacity = 0.0
		var parts := Spirit.draw_parts(base - Vector2(0, p * art * 14), art * 0.5, age, opacity, seed, p)
		sprites.draw_external_rig(canvas, parts, base)
