extends SceneTree
const Shape = preload("res://src/combat/soul_ring_shape.gd")
const Pools = preload("res://src/vfx/pool_paint.gd")
const Art = preload("res://src/vfx/soul_ring.gd")
const Fx = preload("res://src/vfx/fx_sprites.gd")
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("RING_SHAPE_FAIL: ", label)
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var center := Vector2(300, 240)
	var open_floor := func(_p: Vector2) -> bool: return true
	for art: float in [2.0, 3.0]:
		var outer := 112.0
		var inner := 88.0
		var cells: Dictionary = Shape.cells(center, outer, inner, art, open_floor)
		check(cells.size() > 500, "ring has material cells at %sx" % art)
		var hollow := true
		var round_outer := true
		for cell: Vector2i in cells:
			for corner: Vector2 in [Vector2.ZERO, Vector2.ONE, Vector2.RIGHT, Vector2.DOWN]:
				var distance := center.distance_to((Vector2(cell) + corner) * art)
				if distance < inner - 0.001: hollow = false
				if distance > outer + 0.001: round_outer = false
		check(hollow and round_outer, "no material pixel can enter the hole or exceed 7m diameter at %sx" % art)
		check(not Shape.intersects(center, outer, inner, center, 13.0 * art / 2.0), "ordinary center actor is outside ring control")
	var blocked := func(p: Vector2) -> bool: return p.x < 335.0
	var clipped: Dictionary = Shape.cells(center, 112, 88, 2, blocked)
	var safe := true
	for cell: Vector2i in clipped:
		if (Vector2(cell) * 2.0).x >= 335: safe = false
	check(safe and not clipped.is_empty(), "annulus stops at walls without spreading around them into another room")
	var pool := Pools.new(2.0, open_floor)
	pool.add_ring(1, "soul", center, 112, 88, 0, 4, "test")
	var deadline := Time.get_ticks_msec() + 5000
	while not pool._shaping.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
		pool._collect_shapes()
	pool._now = 2.0
	check(not pool.covers(center, "soul") and pool.covers(center + Vector2(100, 0), "soul"), "real shared pool material has a hollow center and active rim")
	var before: int = pool._pools.size()
	pool.add_ring(1, "soul", center, 112, 88, 0, 4, "test")
	check(pool._pools.size() == before, "repeated snapshots reuse material geometry")
	var cfg := {"field_ghost_cycle": 3.4}
	var ghosts: Array = Art.rim_samples(center, 112, 88, 1.5, cfg)
	check(ghosts.size() == 6, "six rig spirits live around the rim")
	for ghost: Dictionary in ghosts:
		var distance := center.distance_to(ghost.base)
		check(distance >= 88 and distance <= 112, "ghost births stay on ring material")
	var cast: Array = Art.cast_samples(center, 80, 0.5)
	check(cast.size() == 6 and center.distance_to(cast[0].at) < 112, "souls expand from caster to rim")
	var fx := Fx.new()
	fx.floor_open = blocked
	var part := {"bounds": Rect2(0, 0, 20, 20), "transform": Transform2D(0.0, Vector2(320, 200))}
	var clip: PackedVector2Array = fx.external_rig_clip([part], center)
	var unique_edges := true
	for i in range(clip.size()):
		if clip[i].distance_squared_to(clip[(i + 1) % clip.size()]) < 0.000001: unique_edges = false
	check(clip.size() >= 3 and unique_edges, "clipped upward spirit fan contains no duplicate ground vertices")
	print("SOUL_RING_SHAPE checked=%d failures=%d" % [checked, failures])
	quit(1 if failures else 0)
