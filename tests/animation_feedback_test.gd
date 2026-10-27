extends SceneTree
## Source-frame, freeze, synthesized PCM and explicit transition-sound checks.
const View = preload("res://src/dungeon_view.gd")
const Tiles = preload("res://src/dungeon_tiles.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ANIMATION_AUDIO_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view = View.new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	check(view.has_method("actor_frame"),"the renderer exposes animated source frames")
	if not view.has_method("actor_frame"):
		view.queue_free()
		finish()
		return
	check(not view.audio_enabled and view._sfx == null,"editor/reference renderers start silently")
	for name: String in ["knight_m","elf_f","wizzard_m","lizard_m","goblin","orc_shaman","big_demon"]:
		var sprite: Dictionary = view._sprites.get(name,{})
		check(sprite.get("idle",[]).size() == 4 and sprite.get("run",[]).size() == 4,"four original idle/run frames exist for "+name)
	view._clock = 0.0
	var first: Texture2D = view.actor_frame("knight_m",true)
	view._clock = 0.13
	var next: Texture2D = view.actor_frame("knight_m",true)
	check(first != next and first.get_image().get_data() != next.get_image().get_data(),"running advances actual distinct PNG frames")
	check(first.get_width() == 16 and first.get_height() == 28,"original16x28 hero art is retained rather than falsely relabelled native32")
	view.set_animation_enabled(false)
	var before: float = view._clock
	view._process(0.25)
	view.set_animation_enabled(false)
	check(view._clock == before,"pausing preserves the exact current animation frame")
	var layout := {"tile_size":32,"world_size":[896,480],"play_bounds":[32,48,832,400],"obstacles":[[352,96,64,64]],"exits":[{"rect":[432,48,32,32],"kind":"door","side":"north"}],"art_style":{"pillar_height":24,"north_wall_height":48}}
	var source: Dictionary = layout.duplicate(true)
	var atlas: Dictionary = Tiles._native_layout(layout,2.0)
	check(atlas.world_size == [448.0,240.0] and atlas.play_bounds == [16.0,24.0,416.0,200.0],"native32 bounds project exactly to the unchanged16px wall atlas")
	check(atlas.obstacles[0] == [176.0,48.0,32.0,32.0] and atlas.art_style.pillar_height == 12.0 and atlas.art_style.north_wall_height == 24.0,"wall collision footprints and native32 heights share one source projection")
	check(layout == source,"wall presentation never mutates authoritative geometry")
	view.set_audio_enabled(true)
	check(view._sfx != null and view._sfx._streams.size() >= 10,"the brother's synthesized sound pool plus stairs is available")
	var door: AudioStreamWAV = view._sfx.effect_stream("door")
	var stairs: AudioStreamWAV = view._sfx.effect_stream("stairs")
	check(door != null and stairs != null and door.mix_rate == 22050 and stairs.mix_rate == 22050,"door and stair audio are real22kHz PCM streams")
	check(door.data.size() > 1000 and stairs.data.size() > door.data.size() and stairs.data != door.data,"stairs have a distinct longer descending-step waveform")
	var peak := 0
	for index in range(0,stairs.data.size(),2): peak = maxi(peak,absi(stairs.data.decode_s16(index)))
	check(peak > 1000,"the generated staircase stream contains audible nonzero samples")
	view.play_transition_sound("stairs")
	check(view._sfx.last_effect == "stairs" and view._sfx.play_count == 1,"an explicit staircase transition selects the staircase sound once")
	if DisplayServer.get_name() == "headless": check(view._sfx._players.all(func(player: AudioStreamPlayer): return not player.playing),"headless bot processes do not create hardware audio playback")
	view.set_state({"room_layout":{"id":"old","tile_size":32},"players":{},"enemies":[]},1)
	view.set_state({"room_layout":{"id":"new","tile_size":32},"players":{},"enemies":[]},1)
	check(view._sfx.play_count == 1,"room snapshots never add a duplicate automatic door sound")
	view.set_audio_enabled(false)
	view.play_transition_sound("door")
	check(view._sfx.play_count == 1,"silent previews suppress transition requests")
	view._feedback.shake = 1.0
	view._feedback.hitstop = 0.2
	view.set_state({"room_layout":{"id":"third","tile_size":32},"players":{},"enemies":[]},1)
	check(view._feedback.shake == 0 and view._feedback.hitstop == 0,"a newly revealed room does not inherit old-room shake or hitstop")
	view._feedback.shake = 1.0
	view._feedback.hitstop = 1.0
	view.reset_feedback()
	check(view._feedback.shake == 0 and view._feedback.hitstop == 0 and view._feedback.particles.count() == 0,"reset removes feedback from previous runs")
	view.queue_free()
	await process_frame
	# Let the audio mixer retire its stopped playback before the test process exits.
	await create_timer(0.12).timeout
	finish()

func finish() -> void:
	print("ANIMATION_AUDIO checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
