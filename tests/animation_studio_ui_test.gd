extends SceneTree
## Focused real-scene UI integration. No encounter, network or gameplay is run.

var checked: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("ANIMATION_STUDIO_UI_FAIL ", message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Arrange: instantiate the actual studio, and control its clock explicitly.
	var studio = load("res://src/animation_studio.tscn").instantiate()
	root.add_child(studio)
	studio.set_process(false)
	await process_frame
	check(studio.bank != null, "the complete animation package loads in the studio scene")
	if studio.bank == null:
		studio.queue_free()
		await process_frame
		_finish()
		return
	_test_actor_clip_direction_controls_select_all_authored_tracks(studio)
	_test_pause_and_frame_buttons_preserve_the_displayed_loop_frame(studio)
	_test_timeline_playback_and_restart_use_the_selected_clip_clock(studio)
	_test_prepared_and_bound_actions_have_distinct_labels(studio)
	_test_boss_at_six_times_zoom_is_confined_to_the_preview(studio)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var capture_index: int = arguments.find("--capture")
	if capture_index >= 0 and capture_index + 1 < arguments.size():
		await process_frame
		await RenderingServer.frame_post_draw
		var capture: Image = root.get_texture().get_image()
		var capture_path: String = arguments[capture_index + 1]
		check(capture != null and capture.save_png(capture_path) == OK, "save the actual rendered boss-6x studio preview")
		print("ANIMATION_STUDIO_CAPTURE ", capture_path)
	studio.queue_free()
	await process_frame
	_finish()

func _test_actor_clip_direction_controls_select_all_authored_tracks(studio) -> void:
	# Act through the actual menu/list signals, not just bank sampling APIs.
	check(studio._actor_menu.item_count == 8 and studio.actor_ids.size() == 8, "all eight actors are selectable")
	check(studio.actions.size() == 48, "48 actions are counted independently of directions")
	check(studio._direction_menu.item_count == 4, "four directions have their own selector")
	studio.playing = false
	for actor_index: int in range(studio.actor_ids.size()):
		studio._actor_menu.select(actor_index)
		studio._actor_menu.item_selected.emit(actor_index)
		check(studio.actor_id == studio.actor_ids[actor_index], "actor menu selects " + studio.actor_ids[actor_index])
		check(studio._list.item_count == 48, "the selected actor exposes all 48 clips")
		for clip_index: int in range(studio.visible_ids.size()):
			studio._list.select(clip_index)
			studio._list.item_selected.emit(clip_index)
			check(studio.clip_id == studio.visible_ids[clip_index], "clip list selects the requested independent track")
			for direction_index: int in range(4):
				studio._direction_menu.select(direction_index)
				studio._direction_menu.item_selected.emit(direction_index)
				studio._process(0.0)
				check(studio.direction == ["south", "east", "north", "west"][direction_index] and not studio._record.is_empty(), "selected actor/clip/direction produces a preview frame")

func _test_pause_and_frame_buttons_preserve_the_displayed_loop_frame(studio) -> void:
	# Arrange: pause after two complete loop cycles, while frame four is visible.
	studio.choose_actor("player_warden")
	studio.choose_clip("idle_breathe")
	var duration: float = studio.bank.duration(studio.clip_id)
	studio.playing = true
	studio.elapsed = duration * 2.5
	studio._process(0.0)
	check(int(studio._record.frame) == 3, "a loop shows its current frame after multiple cycles")
	studio._play.pressed.emit()
	studio._process(0.0)
	check(not studio.playing and int(studio._record.frame) == 3, "Pause freezes the visible loop frame instead of jumping to the final frame")
	var pause_time: float = studio.elapsed
	studio._process(20.0)
	check(is_equal_approx(studio.elapsed, pause_time) and int(studio._record.frame) == 3, "paused time and pose remain fixed")
	_button(studio, "Bild zurück").pressed.emit()
	studio._process(0.0)
	check(not studio.playing and int(studio._record.frame) == 2, "one backward step selects the previous displayed frame")
	_button(studio, "Bild weiter").pressed.emit()
	studio._process(0.0)
	check(int(studio._record.frame) == 3, "one forward step selects the next displayed frame")
	studio._timeline.value = 0.0
	_button(studio, "Bild zurück").pressed.emit()
	studio._process(0.0)
	check(int(studio._record.frame) == 0, "backward stepping clamps at the first frame")
	studio._timeline.value = 1.0
	_button(studio, "Bild weiter").pressed.emit()
	studio._process(0.0)
	check(int(studio._record.frame) == 5, "forward stepping clamps at the final frame")

func _test_timeline_playback_and_restart_use_the_selected_clip_clock(studio) -> void:
	# Act: scrub, resume at two-times speed, then play a one-shot to its end.
	studio.choose_clip("idle_breathe")
	var duration: float = studio.bank.duration(studio.clip_id)
	studio._timeline.value = 0.5
	studio._process(0.0)
	check(not studio.playing and int(studio._record.frame) == 3 and is_equal_approx(studio.elapsed, duration * 0.5), "timeline scrubbing pauses on the requested clip time")
	check(_select_option(studio, "2× Tempo"), "the playback-speed menu selects two-times speed")
	studio._play.pressed.emit()
	studio._process(duration / 12.0)
	check(studio.playing and int(studio._record.frame) == 4, "playback resumes from scrub time and honors speed")
	check(absf(studio._timeline.value - 2.0 / 3.0) <= studio._timeline.step * 0.5 + 0.00001, "playback updates the timeline without pausing itself")
	_button(studio, "Neustart").pressed.emit()
	studio._process(0.0)
	check(int(studio._record.frame) == 0 and is_zero_approx(studio.elapsed), "restart begins the selected clip at frame one")
	studio.choose_clip("death_fall")
	studio.playing = true
	studio._process(studio.bank.duration(studio.clip_id) * 2.0)
	check(int(studio._record.frame) == 5 and is_equal_approx(studio._timeline.value, 1.0), "a nonlooping clip holds its final frame at timeline end")
	check(not studio.playing and studio._play.text == "Abspielen", "completed one-shot playback returns the button to Abspielen")
	_select_option(studio, "1× Tempo")

func _test_prepared_and_bound_actions_have_distinct_labels(studio) -> void:
	studio.choose_clip("attack_primary")
	check("An Spielzustände angebunden" in studio._description.text, "implemented gameplay bindings are labeled as bound")
	studio.choose_clip("dodge_left")
	check("Vorbereitete Animation" in studio._description.text and "Spielmechanik noch nicht vorhanden" in studio._description.text, "prepared-only clips do not promise an implemented gameplay ability")
	studio._search.text = "ausweichen"
	studio._search.text_changed.emit(studio._search.text)
	check(studio._list.item_count == 3, "action search filters the three prepared dodge tracks")
	studio._search.clear()
	studio._search.text_changed.emit("")
	check(studio._list.item_count == 48, "clearing search restores the complete action list")

func _test_boss_at_six_times_zoom_is_confined_to_the_preview(studio) -> void:
	studio.choose_actor("boss")
	studio.choose_clip("heavy_hit")
	check(_select_option(studio, "6× Ansicht"), "the zoom menu selects six-times view")
	studio.playing = false
	studio.elapsed = studio.bank.duration(studio.clip_id) * 0.5
	studio._process(0.0)
	var preview: Control = studio.get("_preview") as Control
	check(preview != null and preview.clip_contents, "boss preview has its own clipping Control")
	if preview != null:
		check(preview.get_child_count() == 1 and preview.get_child(0).name == "ActorCanvas", "sprite drawing is a child of the clipping boundary")
		check(preview.position == Vector2(348, 244) and preview.size == Vector2(900, 304), "preview clipping matches only the designated preview area")
		check(preview.get_parent() == studio._design, "sprite drawing shares the clipped design-space preview coordinates")
		check(preview.position.y >= studio._description.position.y + studio._description.size.y and preview.position.y + preview.size.y <= studio._play.position.y, "preview cannot paint over descriptions or playback buttons")
	check(not studio._record.is_empty(), "boss six-times zoom uses the actual cached boss frame")

func _button(studio, label: String) -> Button:
	for candidate: Node in studio.find_children("*", "Button", true, false):
		if candidate is Button and candidate.text == label:
			return candidate
	return null

func _select_option(studio, label: String) -> bool:
	for candidate: Node in studio.find_children("*", "OptionButton", true, false):
		for index: int in range(candidate.item_count):
			if candidate.get_item_text(index) == label:
				candidate.select(index)
				candidate.item_selected.emit(index)
				return true
	return false

func _finish() -> void:
	print("ANIMATION_STUDIO_UI checked=%d failures=%d" % [checked, failures])
	quit(0 if failures == 0 else 1)
