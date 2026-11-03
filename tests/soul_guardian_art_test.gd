extends SceneTree
## Actual imported pixels, phase selection, mirrored anchors and cached drawing.
const Art = preload("res://src/vfx/soul_guardian_art.gd")
class Recorder extends RefCounted:
	var calls: Array = []
	func draw_external_rig(_canvas: CanvasItem, parts: Array, _at: Vector2) -> void:
		calls.append_array(parts)
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("GUARDIAN_ART_FAIL: ", label)
func _initialize() -> void:
	Art.prepare()
	check(Art.frames.size() == 32 and Art.mirrored.size() == 32, "all four native animation tracks ready")
	var unique := {}
	var hashes: Array = []
	for index in range(Art.frames.size()):
		var image := Art.frames[index].get_image()
		var opaque := 0
		var pale := 0
		var colors := {}
		var hard := true
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var p := image.get_pixel(x, y)
				if p.a > 0.0:
					opaque += 1
					colors[p.to_rgba32()] = true
					if p.g > 0.85 and p.r > 0.65: pale += 1
				if p.a > 0.0 and p.a < 1.0: hard = false
				if p.a == 0.0: image.set_pixel(x, y, Color.TRANSPARENT)
		var visible_hash := hash(image.get_data())
		unique[visible_hash] = true
		hashes.append(visible_hash)
		check(hard and colors.size() <= 18, "native crisp pixels and bounded palette %d" % index)
		check(opaque > 2 and image.get_pixel(0, 0).a == 0.0, "pose visible without opaque backdrop %d" % index)
		if index in range(8, 24): check(pale > 30, "face survives native import %d" % index)
	for row in range(4):
		var clip_poses := {}
		for key in range(8): clip_poses[hashes[row * 8 + key]] = true
		check(clip_poses.size() >= 7, "each motion has at least seven different native poses, row %d actual %d" % [row, clip_poses.size()])
	check(Art.frame_index("spawn", 0.0, 0.64) == 0 and Art.frame_index("spawn", 4, 0.64) == 7, "spawn clamps instead of looping")
	check(Art.frame_index("hover", 0.96, 0.96) == 8, "hover wraps cleanly")
	check(Art.frame_index("grasp", 0.32, 0.64) == 20, "hit moment selects fully extended grasp")
	check(Art.frame_index("dissolve", 0.8, 0.8) == 31, "dissolve ends with remaining motes")
	var first := Art.frames[0] if not Art.frames.is_empty() else null
	Art.prepare()
	check(not Art.frames.is_empty() and Art.frames[0] == first, "repeated preparation reuses textures")
	var canvas := Node2D.new()
	var recorder := Recorder.new()
	var actor := {"id": 1, "x": 100.0, "y": 100.0, "motion": "hover", "duration": 0.96, "face": -1.0}
	Art.draw(canvas, actor, 0.06, 2.0, recorder)
	check(recorder.calls.size() > 9 and recorder.calls.size() < 200, "live draw includes articulated parts and bounded tail fragments")
	if recorder.calls.size() > 9:
		var crisp := true
		var mirrored_parts := true
		var heads := 0
		for part: Dictionary in recorder.calls:
			if str(part.id) == "head": heads += 1
			if str(part.id) in ["head", "torso", "arm_l", "arm_r", "hand_l", "hand_r"] and not is_equal_approx(float(part.tint.a), 1.0): crisp = false
			if Transform2D(part.transform).determinant() >= 0.0: mirrored_parts = false
		check(crisp and heads == 1, "hover keeps one opaque face and body while the tail sheds particles")
		check(mirrored_parts, "left-facing rig mirrors every body part")
	canvas.free()
	print("GUARDIAN_ART checked=%d failures=%d distinct_native_poses=%d" % [checked, failures, unique.size()])
	quit(1 if failures else 0)
