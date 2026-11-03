extends SceneTree
## Focused scheduling regressions; run separately from the story integration fixture.
## Run later with: godot --headless --path . -s res://tests/story_clock_test.gd

const Clock = preload("res://src/physics_kit/fixed_step_clock.gd")
const CONFIG := {"tick_hz": 60, "max_steps_per_frame": 8}

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_render_rates_produce_equal_game_time()
	_test_mixed_frames_keep_elapsed_time()
	_test_budget_keeps_time_for_later_frames()
	_test_pause_reset_drops_old_time()
	_test_floor_reset_stops_the_current_batch()
	_test_invalid_delta_adds_no_time()
	print("STORY_CLOCK checked=%d failures=%d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("STORY_CLOCK_FAIL " + message)


## One second must move a constant-speed body equally, including below the old 20-FPS clamp.
func _test_render_rates_produce_equal_game_time() -> void:
	for fps: int in [15, 30, 60, 144, 240]:
		# Arrange: a body and a cooldown independent of the render schedule.
		var clock: RefCounted = Clock.new(CONFIG)
		var distance: float = 0.0
		var cooldown: float = 0.75
		var ticks: int = 0
		# Act: the same elapsed second delivered at each display rate.
		for frame in range(fps):
			clock.begin_frame(1.0 / float(fps))
			while clock.take_step():
				distance += 360.0 * float(clock.step_seconds)
				cooldown = maxf(0.0, cooldown - float(clock.step_seconds))
				ticks += 1
		# Assert: time, movement and cooldown follow simulation time, not frame count.
		_check(ticks == 60, "%d FPS: one second has 60 simulation ticks" % fps)
		_check(is_equal_approx(distance, 360.0) and is_zero_approx(cooldown), "%d FPS: movement and cooldown keep their speed" % fps)


func _test_mixed_frames_keep_elapsed_time() -> void:
	# Arrange: one second with different frame lengths, including a 100-ms hitch.
	var clock: RefCounted = Clock.new(CONFIG)
	var ticks: int = 0
	var frames: Array[float] = [0.1, 0.025, 0.025, 0.05]
	for frame in range(8): frames.append(0.1)
	# Act.
	for delta: float in frames:
		clock.begin_frame(delta)
		while clock.take_step(): ticks += 1
	# Assert.
	_check(ticks == 60 and is_zero_approx(float(clock.pending_seconds)), "hitches and changing FPS lose no elapsed time")


func _test_budget_keeps_time_for_later_frames() -> void:
	# Arrange: a half-second hitch, too much work for one rendered frame.
	var clock: RefCounted = Clock.new(CONFIG)
	var ticks: int = 0
	# Act.
	clock.begin_frame(0.5)
	while clock.take_step(): ticks += 1
	var first_batch: int = ticks
	for frame in range(3):
		clock.begin_frame(0.0)
		while clock.take_step(): ticks += 1
	# Assert: bounded work, with the debt retained instead of silently clipped.
	_check(first_batch == 8, "a hitch runs at most the configured catch-up budget per frame")
	_check(ticks == 30 and is_zero_approx(float(clock.pending_seconds)), "later frames recover the entire half-second")


func _test_pause_reset_drops_old_time() -> void:
	# Arrange: time left over just before a pause.
	var clock: RefCounted = Clock.new(CONFIG)
	clock.begin_frame(0.1)
	clock.take_step()
	# Act: menus do not accumulate simulation time; a fresh partial frame follows.
	clock.reset()
	clock.begin_frame(0.005)
	# Assert.
	_check(not clock.take_step(), "resuming does not fast-forward the time left before the pause")
	_check(is_equal_approx(float(clock.pending_seconds), 0.005), "sub-tick time is kept for the next frame")


func _test_floor_reset_stops_the_current_batch() -> void:
	# Arrange: several old-floor ticks are due.
	var clock: RefCounted = Clock.new(CONFIG)
	clock.begin_frame(0.1)
	var first: bool = clock.take_step()
	# Act: a floor load resets the clock from inside its first update.
	clock.reset()
	# Assert.
	_check(first and not clock.take_step(), "a floor switch cancels the rest of the old-floor batch")
	_check(is_zero_approx(float(clock.pending_seconds)), "a new floor inherits no time debt")


func _test_invalid_delta_adds_no_time() -> void:
	# Arrange / act.
	var clock: RefCounted = Clock.new(CONFIG)
	for delta: float in [-1.0, INF, NAN]: clock.begin_frame(delta)
	# Assert.
	_check(not clock.take_step() and is_zero_approx(float(clock.pending_seconds)), "negative and non-finite frame times cannot poison the clock")
