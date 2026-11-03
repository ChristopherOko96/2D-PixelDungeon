extends SceneTree
## Real cutout pixels and shared skeleton solver, not a new combat simulation.
const Guardian = preload("res://src/rig/soul_guardian_rig.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
const Fx = preload("res://src/vfx/fx_sprites.gd")
var checked := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("GUARDIAN_RIG_FAIL: ", label)

func _initialize() -> void:
	Guardian.prepare()
	var rig: Dictionary = Guardian.rig
	check(rig.get("parts", []).size() == 9, "nine real cutouts: head, torso, arms, hands and three tail sections")
	if rig.is_empty():
		quit(1)
		return
	var reconstructed := Image.create(128, 80, false, Image.FORMAT_RGBA8)
	var source := load("res://assets/vfx/soul_guardian/rig/bind.png").get_image() as Image
	for part: Dictionary in rig.parts:
		check(Rect2(part.bounds).has_area(), "%s owns visible source pixels" % part.id)
		var image: Image = part.image
		var exact := true
		for y in range(80):
			for x in range(128):
				var c := image.get_pixel(x, y)
				if c.a < 0.5: continue
				if c != source.get_pixel(x, y): exact = false
				reconstructed.set_pixel(x, y, c)
		check(exact, "%s preserves approved pixels, including joint underlap" % part.id)
	var same := true
	for y in range(80):
		for x in range(128):
			if source.get_pixel(x, y).a >= 0.5 and reconstructed.get_pixel(x, y) != source.get_pixel(x, y): same = false
	check(same, "neutral rig reconstructs the entire cleaned bind silhouette")
	var origin := Vector2(300, 240)
	var neutral: Dictionary = Guardian.solve(Poses.blank(), origin, 1.0, 2.0)
	for part: Dictionary in rig.parts:
		check((neutral[part.id] * Vector2(48, 64)).is_equal_approx(origin), "shared solver preserves ground anchor: %s" % part.id)
	var a: Dictionary = Guardian.pose("hover", 0.3, 1.6, 2.0)
	var b: Dictionary = Guardian.pose("hover", 0.3, 1.6, 2.0 + 1.0 / 60.0)
	var aw: Dictionary = Guardian.solve(a, origin, 1.0, 2.0)
	var bw: Dictionary = Guardian.solve(b, origin, 1.0, 2.0)
	var animated := 0
	for part: Dictionary in rig.parts:
		var point: Vector2 = part.center
		var distance: float = (aw[part.id] * point).distance_to(bw[part.id] * point)
		if distance > 0.001: animated += 1
		check(distance < 1.5, "%s changes continuously between 60 Hz samples" % part.id)
	check(animated == 9, "all nine bones animate between former sheet keys")
	check(not is_equal_approx(float(a.parts.arm_l.rot), float(a.parts.arm_r.rot)), "arms have independent delayed motion")
	var parent_pose := Poses.blank()
	Poses.P(parent_pose, "arm_r").rot = -0.5
	var parent_world: Dictionary = Guardian.solve(parent_pose, origin, 1.0, 2.0)
	var wrist: Vector2 = rig.by_id.hand_r.pivot
	check((parent_world.hand_r * wrist).is_equal_approx(parent_world.arm_r * wrist), "hand stays attached when shoulder moves")
	var left: Dictionary = Guardian.solve(a, origin, -1.0, 2.0)
	for id: String in ["head", "hand_l", "hand_r", "tail_tip"]:
		var p: Vector2 = rig.by_id[id].center
		var right_point: Vector2 = aw[id] * p
		var left_point: Vector2 = left[id] * p
		check(absf(right_point.x + left_point.x - origin.x * 2.0) < 0.001 and absf(right_point.y - left_point.y) < 0.001, "left-facing joints mirror around feet: %s" % id)
	var start: Dictionary = Guardian.pose("grasp", 0, 0.64, 2)
	var hit: Dictionary = Guardian.pose("grasp", 0.32, 0.64, 2)
	var end: Dictionary = Guardian.pose("grasp", 0.64, 0.64, 2)
	var start_w: Dictionary = Guardian.solve(start, origin, 1, 2)
	var hit_w: Dictionary = Guardian.solve(hit, origin, 1, 2)
	var tip: Vector2 = rig.by_id.hand_r.center
	check((hit_w.hand_r * tip).x > (start_w.hand_r * tip).x + 20, "reach visibly extends at the authoritative hit moment")
	check(is_equal_approx(float(start.parts.arm_r.rot), float(end.parts.arm_r.rot)), "attack recovers to idle without phase jump")
	var prior: Dictionary = Guardian.pose("hover", 1.6 - 0.0001, 1.6, 5)
	var next: Dictionary = Guardian.pose("hover", 0, 1.6, 5)
	check(prior == next, "hover phase reset does not restart lifetime-based bone motion")
	check(Guardian.pose("spawn", 0, 0.64, 0).whole.alpha == 0.0, "spawn begins invisible")
	check(Guardian.pose("dissolve", 0.8, 0.8, 12).whole.alpha == 0.0, "dissolve ends invisible")
	test_rotating_rig_stops_at_walls(origin)
	# World scale is shared presentation data: story worlds use 3x rather than 2x.
	var story: Dictionary = Guardian.solve(a, origin, 1.0, 3.0)
	check(((story.head * Vector2(rig.by_id.head.center)) - origin).is_equal_approx(((aw.head * Vector2(rig.by_id.head.center)) - origin) * 1.5), "story-world scale applies to the entire joint chain")
	var texture: Texture2D = rig.parts[0].texture
	Guardian.prepare()
	check(Guardian.rig.parts[0].texture == texture, "rig textures are prepared once")
	print("GUARDIAN_RIG checked=%d failures=%d" % [checked, failures])
	quit(1 if failures else 0)

func test_rotating_rig_stops_at_walls(origin: Vector2) -> void:
	var fx := Fx.new()
	for face: float in [1.0, -1.0]:
		var actor := {"motion": "grasp", "face": face}
		var parts: Array = Guardian.draw_parts(actor, 0.32, 0.64, 2.0, origin, 2.0)
		fx.floor_open = func(_p: Vector2) -> bool: return true
		check(fx.external_rig_clip(parts, origin).is_empty(), "open floor keeps complete rig, face %s" % face)
		fx.floor_open = func(p: Vector2) -> bool: return p.x < 340.0 if face > 0.0 else p.x > 260.0
		var boundary: PackedVector2Array = fx.external_rig_clip(parts, origin)
		check(boundary.size() >= 3, "nearby wall clips the articulated reach, face %s" % face)
		var safe := true
		var visible := 0
		for part: Dictionary in parts:
			var quad: PackedVector2Array = fx._rig_quad(part)
			if Geometry2D.is_polygon_clockwise(quad): quad.reverse()
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(quad, boundary):
				visible += 1
				for p: Vector2 in polygon:
					if (face > 0.0 and p.x >= 340.001) or (face < 0.0 and p.x <= 259.999): safe = false
		check(safe and visible > 0, "mirrored/rotated polygons remain visible only on near side of wall, face %s" % face)
