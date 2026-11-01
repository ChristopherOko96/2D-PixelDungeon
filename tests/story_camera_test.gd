extends SceneTree
## The story camera (src/hell/story_camera.gd): it leads the hero's run, leans
## toward a fight and widens for a boss, keeps the view inside the room, the
## punch and the kick return to rest, and "Kamerabewegung reduzieren" keeps
## only the follow.

const StoryCamera = preload("res://src/hell/story_camera.gd")
const STEP := 1.0 / 60.0
const VIEW := Vector2(1800, 1012.5)
var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("STORY_CAMERA_FAIL: ", label)


func _initialize() -> void:
	_test_leads_the_run()
	_test_leans_toward_the_fight_and_widens_for_a_boss()
	_test_stays_inside_the_room()
	_test_punch_and_kick_return_to_rest()
	_test_calm_keeps_only_the_follow()
	print("STORY_CAMERA checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## Runs the hero from `from` along `vel` for `seconds`, returns his last point.
func _run(cam: RefCounted, from: Vector2, vel: Vector2, seconds: float, extra := {}) -> Vector2:
	var hero := from
	for i in int(seconds / STEP):
		hero += vel * STEP
		var frame := {"hero": hero, "view": VIEW}
		frame.merge(extra)
		cam.step(STEP, frame)
	return hero


func _test_leads_the_run() -> void:
	# Arrange
	var cam := StoryCamera.new()
	cam.reset(Vector2.ZERO)
	# Act: two seconds running right at run speed
	var hero := _run(cam, Vector2.ZERO, Vector2(350, 0), 2.0)
	# Assert
	check(cam.position.x > hero.x + 20.0, "the view runs ahead of the hero")
	check(absf(cam.position.y - hero.y) < 2.0, "a run to the right does not lift the view")


func _test_leans_toward_the_fight_and_widens_for_a_boss() -> void:
	# Arrange
	var cam := StoryCamera.new()
	cam.reset(Vector2.ZERO)
	var boss := Vector2(600, 0)
	# Act: standing still with a boss to the right for three seconds
	_run(cam, Vector2.ZERO, Vector2.ZERO, 3.0, {"foes": [boss], "boss": true})
	# Assert
	check(cam.position.x > 60.0, "the view leans toward the boss")
	check(cam.zoom < 0.95, "the view widens for a boss")
	check(cam.zoom >= float(cam.cfg.zoom.min) - 0.001, "it never widens past the minimum")


func _test_stays_inside_the_room() -> void:
	# Arrange: a room 2400 wide; the hero runs into its right wall
	var cam := StoryCamera.new()
	var room := Rect2(0, 0, 2400, 1400)
	cam.reset(Vector2(1200, 700))
	# Act
	_run(cam, Vector2(1200, 700), Vector2(350, 0), 4.0, {"bounds": room})
	# Assert: the view's right edge stays at the room's edge
	check(cam.position.x + VIEW.x / cam.zoom / 2.0 <= room.end.x + 1.0, "the view never shows past the room")


func _test_punch_and_kick_return_to_rest() -> void:
	# Arrange
	var cam := StoryCamera.new()
	cam.reset(Vector2.ZERO)
	# Act
	cam.punch("ultimate")
	cam.kick(Vector2.RIGHT, "slam")
	_run(cam, Vector2.ZERO, Vector2.ZERO, 0.12)
	var peak_zoom: float = cam.zoom
	var peak_kick: float = cam.offset.length()
	# 1.5 s: long enough to settle, shorter than the rest zoom's delay
	_run(cam, Vector2.ZERO, Vector2.ZERO, 1.5)
	# Assert
	check(peak_zoom > 1.03, "an ultimate punches the zoom in")
	check(peak_kick > 4.0, "a slam kicks the view")
	check(absf(cam.zoom - 1.0) < 0.01, "the punch settles back")
	check(cam.offset.length() < 0.5, "the kick settles back")


func _test_calm_keeps_only_the_follow() -> void:
	# Arrange
	var cam := StoryCamera.new()
	cam.calm = true
	cam.reset(Vector2.ZERO)
	# Act: a run with a boss nearby and an ultimate
	cam.punch("ultimate")
	var hero := _run(cam, Vector2.ZERO, Vector2(350, 0), 2.0, {"foes": [Vector2(300, 300)], "boss": true})
	# Assert
	check(absf(cam.zoom - 1.0) < 0.001, "calm keeps the zoom still")
	check(cam.position.x <= hero.x + 1.0, "calm does not run ahead")
	cam.shake_on = false
	cam.step(STEP, {"hero": hero, "view": VIEW, "shake": 12.0, "t": 1.0})
	check(cam.offset == Vector2.ZERO, "shake off means a still view")
