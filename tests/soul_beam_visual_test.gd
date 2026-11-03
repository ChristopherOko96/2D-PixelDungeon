extends SceneTree
## Numerical pose/stream continuity complements the retained GPU recording.
const Rig = preload("res://src/rig/soul_guardian_rig.gd")
const Beam = preload("res://src/vfx/soul_beam.gd")
var checked := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failed += 1
		printerr("SOUL_BEAM_VISUAL_FAIL: ", message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	Rig.prepare()
	var actor := {"motion": "beam", "duration": 2.3, "face": 1.0, "beam_windup": 0.45, "beam_time": 1.6}
	var previous: Array = []
	var max_step := 0.0
	var poses := {}
	for frame in range(139):
		var t := frame / 60.0
		var parts: Array = Rig.draw_parts(actor, t, 2.3, 10.0 + t, Vector2(300, 240), 2.0)
		check(parts.size() == 9, "channel retains all nine articulated parts")
		for i in range(parts.size()):
			var xform: Transform2D = parts[i].transform
			var palm := xform * Vector2(65, 42)
			check(palm.is_finite(), "finite bone transform")
			if not previous.is_empty(): max_step = maxf(max_step, palm.distance_to(Transform2D(previous[i].transform) * Vector2(65, 42)))
		poses[str(parts[7].transform)] = true
		previous = parts
	check(max_step < 7.0 and poses.size() > 90, "continuous distinct poses at sixty frames per second")
	var ground := Vector2(300, 240)
	var palm := Vector2(390, 130)
	check(Beam.point(ground, palm, Vector2.RIGHT, 0, 2, 256).is_equal_approx(palm), "stream anchored at actual animated hand")
	check(Beam.point(ground, palm, Vector2.RIGHT, 256, 2, 256).is_equal_approx(Vector2(556, 216)), "stream ends at bounded host trace in enemy torso plane")
	var last := palm
	for i in range(1, 129):
		var p := Beam.point(ground, palm, Vector2.RIGHT, i * 2.0, 2, 256)
		check(p.distance_to(last) < 5 and p.x >= last.x, "smooth forward curve without abrupt elbow")
		last = p
	check(Beam.envelope(actor, 0.44) == 0 and Beam.envelope(actor, 1.0) > 0.99 and Beam.envelope(actor, 2.3) == 0, "host channel envelope matches preparation and release")
	print("SOUL_BEAM_VISUAL checked=%d failures=%d max_step=%.3f" % [checked, failed, max_step])
	quit(1 if failed else 0)
