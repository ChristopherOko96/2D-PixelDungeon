extends SceneTree
## Real story scenes: fixed-time scheduling, pause, hitstop and floor loading.
## Profiles/settings/saves are isolated under a disposable test directory.
## Optional --legacy loads the unmodified HEAD story script from the temporary
## fixtures/story_clock_baseline.gd file to prove the old low-FPS regression.
## --realtime instead observes the engine's real _process callbacks at 15/60 FPS.

const SaveStore = preload("res://src/save/save_store.gd")
const WORLDS := [
	["krypta", "res://src/hell/krypta_dungeon.tscn"],
	["frost", "res://src/hell/frost_dungeon.tscn"],
	["hell", "res://src/hell/hell_dungeon.tscn"],
]

var _checked: int = 0
var _failures: int = 0
var _legacy: bool = false
var _realtime: bool = false
var _scratch: String = ""


func _initialize() -> void:
	_legacy = "--legacy" in OS.get_cmdline_user_args()
	_realtime = "--realtime" in OS.get_cmdline_user_args()
	_scratch = "res://tests/.tmp_story_clock_%s_%d" % ["legacy" if _legacy else "fixed", Time.get_ticks_usec()]
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	_checked += 1
	if not ok:
		_failures += 1
		printerr("STORY_CLOCK_INTEGRATION_FAIL " + label)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_scratch))
	for spec: Array in WORLDS:
		seed(4711)
		var game: Node = (load(str(spec[1])) as PackedScene).instantiate()
		if _legacy:
			var theme_path: String = str(game.theme_path)
			game.set_script(load("res://tests/fixtures/story_clock_baseline.gd"))
			game.theme_path = theme_path
		game.class_id = "mage"
		game.profile_path = _scratch + "/profile_%s.json" % spec[0]
		game.meta_path = _scratch + "/meta_%s.cfg" % spec[0]
		game.settings_path = _scratch + "/settings_%s.cfg" % spec[0]
		game.graphics_path = game.settings_path
		game.saves = SaveStore.new(_scratch + "/saves")
		game.mouse_taken = true
		game.keys_taken = true
		root.add_child(game)
		current_scene = game
		game.set_process(false)
		if _realtime:
			await _test_realtime(game, str(spec[0]))
		else:
			_test_frame_rates(game, str(spec[0]))
			_test_pause(game, str(spec[0]))
			_test_hitstop(game, str(spec[0]))
			_test_floor_load(game, str(spec[0]))
		game.queue_free()
		await process_frame
	_cleanup()
	print("STORY_CLOCK_INTEGRATION mode=%s checked=%d failures=%d" % ["realtime" if _realtime else ("legacy" if _legacy else "fixed"), _checked, _failures])
	quit(1 if _failures > 0 else 0)


func _prime(game: Node) -> void:
	if not _legacy:
		game._simulation_clock.reset()
		game._skip_simulation_delta = true
	game._process(0.0)


func _test_frame_rates(game: Node, world: String) -> void:
	for fps: int in [15, 30, 60, 144, 240]:
		# Arrange: actual story cooldowns, no mouse/keyboard attacks in the start room.
		game.state.t = 0.0
		game.state.cool = 1.2
		_prime(game)
		# Act: one elapsed second at the chosen render rate.
		for frame in range(fps): game._process(1.0 / float(fps))
		# Assert: both the world clock and the real cooldown advance equally.
		_check(is_equal_approx(float(game.state.t), 1.0), "%s %d FPS: world time = 1 s (got %.6f)" % [world, fps, float(game.state.t)])
		_check(is_equal_approx(float(game.state.cool), 0.2), "%s %d FPS: cooldown retains 0.2 s (got %.6f)" % [world, fps, float(game.state.cool)])
		print("STORY_CLOCK_RATE world=%s fps=%d simulated=%.6f cooldown=%.6f" % [world, fps, float(game.state.t), float(game.state.cool)])


func _test_pause(game: Node, world: String) -> void:
	# Arrange / act: pause, then close it after a long rendered interval.
	var before: float = float(game.state.t)
	game.pause_menu.visible = true
	game._process(4.0)
	_check(is_equal_approx(float(game.state.t), before), world + ": pause freezes the real world")
	game.pause_menu.visible = false
	game._process(4.0)
	_check(is_equal_approx(float(game.state.t), before), world + ": resuming drops menu time")
	game._process(1.0 / 60.0)
	_check(is_equal_approx(float(game.state.t), before + 1.0 / 60.0), world + ": the next tick resumes normally")


func _test_hitstop(game: Node, world: String) -> void:
	# Arrange: all three real story themes use the crypt's StoryFeel hitstop.
	_check(game.feel != null, world + ": StoryFeel is present")
	if game.feel == null: return
	_prime(game)
	var before: float = float(game.state.t)
	game.feel.feedback.hitstop = 0.11
	# Act: six held ticks, then a final held tick and one normal tick.
	game._process(0.1)
	_check(is_equal_approx(float(game.state.t), before), world + ": hitstop consumes time without combat updates")
	game._process(1.0 / 60.0)
	_check(is_equal_approx(float(game.state.t), before), world + ": the last partial hitstop tick stays frozen")
	game._process(1.0 / 60.0)
	_check(is_equal_approx(float(game.state.t), before + 1.0 / 60.0), world + ": hitstop ends without fast-forwarding combat")


func _test_floor_load(game: Node, world: String) -> void:
	# Arrange: old-floor debt is still waiting.
	# Isolate loading from the preceding test's hitstop, especially on the old code.
	if game.feel != null: game.feel.feedback.hitstop = 0.0
	if game.drake_rig != null: game.drake_rig.hitstop_left = 0.0
	if not _legacy: game._simulation_clock.begin_frame(0.1)
	# Act: real generation of floor 2, followed by a long loading-time sample.
	game.load_floor(2, true)
	_check(int(game.state.floor) == 2, world + ": the real next floor loads")
	if not _legacy:
		_check(not game._simulation_clock.take_step(), world + ": loading cancels old-floor catch-up")
	var before: float = float(game.state.t)
	game._process(2.0)
	_check(is_equal_approx(float(game.state.t), before), world + ": loading time is not played as combat")
	game._process(1.0 / 60.0)
	_check(is_equal_approx(float(game.state.t), before + 1.0 / 60.0), world + ": the new floor begins with one normal tick")


func _cleanup() -> void:
	# This unique directory holds only files created by this fixture.
	for file: String in DirAccess.get_files_at(_scratch):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_scratch.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_scratch))


## Headless timing observation, not a GPU benchmark: normal engine callbacks,
## two seconds per cap, within 0.1 s of wall time (well below the old 25% loss).
func _test_realtime(game: Node, world: String) -> void:
	var old_cap: int = Engine.max_fps
	for cap: int in [15, 60]:
		Engine.max_fps = cap
		game.set_process(true)
		for warm in range(3): await process_frame
		var started: int = Time.get_ticks_usec()
		var before: float = float(game.state.t)
		var frames: int = 0
		while float(Time.get_ticks_usec() - started) / 1000000.0 < 2.0:
			await process_frame
			frames += 1
		var wall: float = float(Time.get_ticks_usec() - started) / 1000000.0
		var simulated: float = float(game.state.t) - before
		game.set_process(false)
		_check(absf(simulated - wall) <= 0.1, "%s cap %d: real callbacks keep wall time (wall %.4f, sim %.4f)" % [world, cap, wall, simulated])
		print("STORY_CLOCK_REALTIME world=%s cap=%d frames=%d wall=%.6f simulated=%.6f drift=%.6f" % [world, cap, frames, wall, simulated, simulated - wall])
	Engine.max_fps = old_cap
