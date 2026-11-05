extends SceneTree
## Pixel-camera regression: rest, crowds and ultimates cannot rescale the floor.
const Camera = preload("res://src/hell/story_camera.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("CAMERA_JITTER_FAIL: ", label)

func _initialize() -> void:
	var cam := Camera.new()
	cam.reset(Vector2.ZERO)
	for i in range(300): cam.step(1.0 / 60.0, {"hero": Vector2.ZERO, "pixel": true})
	check(is_equal_approx(cam.zoom, 1.0), "pixel rest keeps fixed zoom")
	cam.punch("ultimate")
	for i in range(60): cam.step(1.0 / 60.0, {"hero": Vector2.ZERO, "pixel": true, "foes": [Vector2(500, 100)], "boss": true})
	check(is_equal_approx(cam.zoom, 1.0), "pixel combat/punch keeps fixed zoom")
	cam.step(1.0 / 60.0, {"hero": Vector2.ZERO, "pixel": false, "foes": [Vector2(500, 100)], "boss": true})
	check(cam.zoom < 1.0, "HD camera retains dynamic zoom")
	print("CAMERA_JITTER checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
