extends SceneTree
## The mix, the music and the step timing (src/audio/audio_mix.gd,
## src/audio/music.gd, rig footfalls, src/ui/sound_workshop.gd): the buses
## exist with ducking and a limiter, sliders scale them, the music picks its
## state from the snapshot and calms down only after the hold, hero footsteps
## follow their speed, and the Klangwerkstatt edits and saves the tables.

const AudioMix = preload("res://src/audio/audio_mix.gd")
const Music = preload("res://src/audio/music.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const SoundWorkshop = preload("res://src/ui/sound_workshop.gd")
const Sfx = preload("res://src/vfx/sfx.gd")
const STEP := 1.0 / 60.0
var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("AUDIO_MUSIC_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_buses_duck_and_limit()
	_test_sliders_scale_and_mute()
	_test_music_state_follows_the_fight()
	await _test_music_calms_down_after_the_hold()
	_test_footfalls_follow_the_hero_speed()
	await _test_workshop_edits_and_saves()
	print("AUDIO_MUSIC checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_buses_duck_and_limit() -> void:
	# Act
	AudioMix.ensure_buses()
	AudioMix.ensure_buses()
	# Assert
	for name: String in ["Music", "Ambience", "SFX", "Focus", "UI"]:
		check(AudioServer.get_bus_index(name) >= 0, "the %s bus exists" % name)
	check(AudioServer.bus_count == 6, "calling it twice adds no extra buses (%d)" % AudioServer.bus_count)
	check(str(AudioServer.get_bus_send(AudioServer.get_bus_index("Focus"))) == "SFX", "Focus is a part of the effects")
	var music := AudioServer.get_bus_index("Music")
	var ducking: AudioEffect = AudioServer.get_bus_effect(music, 0) if AudioServer.get_bus_effect_count(music) > 0 else null
	check(ducking is AudioEffectCompressor and str(ducking.sidechain) == "Focus", "the music ducks under Focus")
	check(AudioServer.get_bus_effect_count(0) == 1 and AudioServer.get_bus_effect(0, 0) is AudioEffectHardLimiter, "a limiter guards the Master")


func _test_sliders_scale_and_mute() -> void:
	# Arrange
	var music := AudioServer.get_bus_index("Music")
	var base := -7.0
	for bus: Dictionary in AudioMix.data().buses:
		if str(bus.name) == "Music": base = float(bus.volume_db)
	# Act / Assert
	AudioMix.set_slider("music", 1.0)
	check(is_equal_approx(AudioServer.get_bus_volume_db(music), base) and not AudioServer.is_bus_mute(music), "a full slider leaves the music at its mix level")
	AudioMix.set_slider("music", 0.5)
	check(absf(AudioServer.get_bus_volume_db(music) - (base - 12.04)) < 0.1, "half the slider is a quarter of the power (-12 dB)")
	AudioMix.set_slider("music", 0.0)
	check(AudioServer.is_bus_mute(music) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")), "the music slider at 0 mutes music and ambience")
	AudioMix.set_slider("music", 1.0)


func _test_music_state_follows_the_fight() -> void:
	var skeleton := {"hp": 10, "dying_p": -1.0}
	var dead := {"hp": 0, "dying_p": 1.0}
	var boss := {"hp": 100, "boss": true, "dying_p": -1.0}
	var miniboss := {"hp": 100, "miniboss": true, "dying_p": -1.0}
	check(Music.decide({}, true) == "menu", "no snapshot: menu music")
	check(Music.decide({"phase": "combat", "enemies": [skeleton]}, false) == "menu", "outside a run (menu, lobby): menu music")
	check(Music.decide({"phase": "explore", "enemies": []}, true) == "explore", "a quiet room: exploring")
	check(Music.decide({"phase": "combat", "enemies": [skeleton]}, true) == "combat", "enemies alive: combat")
	check(Music.decide({"phase": "combat", "enemies": [dead], "horde": {"left": 4}}, true) == "combat", "a horde still coming: combat")
	check(Music.decide({"phase": "combat", "enemies": [dead], "horde": {"left": 0}}, true) == "explore", "all dead, nothing coming: exploring")
	check(Music.decide({"phase": "combat", "enemies": [skeleton, boss]}, true) == "boss", "the boss alive: boss music")
	check(Music.decide({"phase": "combat", "enemies": [miniboss]}, true) == "boss", "a mini-boss counts as a boss")
	check(Music.decide({"phase": "dead", "enemies": []}, true) == "menu", "a defeat falls back to the calm menu music")


func _test_music_calms_down_after_the_hold() -> void:
	# Arrange
	var music := Music.new()
	root.add_child(music)
	await process_frame
	var hold := float(music.table.get("calm_hold", 6.0))
	# Act: a fight starts.
	music.request("combat")
	music._process(STEP)
	var fighting: String = music.state
	var combat_track: String = music.track
	# The fight ends: the music waits before it calms down.
	music.request("explore")
	music._process(hold * 0.5)
	var during_hold: String = music.state
	music._process(hold * 0.6)
	# Assert
	check(fighting == "combat" and combat_track == str(music.table.states.combat.track), "a fight switches to the combat track at once")
	check(during_hold == "combat", "the music holds the fight a while after it ends")
	check(music.state == "explore" and music.track == str(music.table.states.explore.track), "after the hold it calms down to exploring")
	check(music._ambience_on, "exploring lays the ambience underneath")
	music.request("boss")
	music._process(STEP)
	check(music.state == "boss" and not music._ambience_on, "a boss switches at once and drops the ambience")
	Music.hush = true
	music._process(STEP)
	check(music.state == "menu" and music.track == str(music.table.states.menu.track) or music.track.is_empty(), "the Klangwerkstatt hushes the music")
	Music.hush = false
	music.queue_free()
	await process_frame


func _test_footfalls_follow_the_hero_speed() -> void:
	# Arrange: two heroes, one slow, one fast.
	var rigs := RigRenderer.new()
	var slow := {"moving": true, "step_time": 0.25}
	var fast := {"moving": true, "step_time": 0.2}
	var standing := {"moving": false, "step_time": 0.2}
	# Act: three seconds of walking.
	for frame in range(180):
		rigs.step(STEP)
		rigs.track_steps("p1", slow)
		rigs.track_steps("p2", fast)
		rigs.track_steps("p3", standing)
	# Assert
	var slow_steps := rigs.footfalls.count("p1")
	var fast_steps := rigs.footfalls.count("p2")
	check(absi(slow_steps - 12) <= 1, "a hero with 0.25 s steps touches down 12 times in 3 s (%d)" % slow_steps)
	check(absi(fast_steps - 15) <= 1, "a faster hero steps more often (%d)" % fast_steps)
	check(rigs.footfalls.count("p3") == 0, "a standing hero makes no steps")
	check(is_equal_approx(float(rigs._actors.p1.cycle), 0.5), "the legs swing over two steps")


func _test_workshop_edits_and_saves() -> void:
	# Arrange: the workshop on copies of the tables.
	var sfx_copy := "user://workshop_test_sfx.json"
	var music_copy := "user://workshop_test_music.json"
	for pair: Array in [["res://assets/data/audio_sfx.json", sfx_copy], ["res://assets/data/audio_music.json", music_copy]]:
		var file := FileAccess.open(pair[1], FileAccess.WRITE)
		file.store_string(FileAccess.get_file_as_string(pair[0]))
		file.close()
	var workshop := SoundWorkshop.new()
	workshop.sfx_path = sfx_copy
	workshop.music_path = music_copy
	root.add_child(workshop)
	await process_frame
	var events: int = workshop.sfx_table.events.size()
	var version := Sfx.table_version
	# Act: add a file to the skeleton hit, louder, then pick another combat track.
	workshop.select("hit_bone")
	var before: int = workshop._files.item_count
	var wanted := "res://assets/audio/library/kenney_impact/impact_wood_heavy_000.ogg"
	workshop._pack.select(0)
	workshop._search.text = "impact_wood_heavy_000"
	workshop._fill_library()
	workshop._library_list.select(0)
	workshop._add_library()
	workshop._volume.value = 3.0
	workshop.select("music:combat")
	workshop._pack.select(workshop._pack_ids.find("music"))
	workshop._search.text = "pursuit"
	workshop._fill_library()
	workshop._library_list.select(0)
	workshop._add_library()
	var saved: bool = workshop.save()
	# Assert
	check(workshop._events.item_count == events + 5, "the list shows every event plus four music states and the ambience")
	check(workshop._files.item_count == 1, "a music state shows its one track")
	var sfx_saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sfx_copy))
	var music_saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(music_copy))
	check(saved and sfx_saved.events.hit_bone.files.size() == before + 1 and sfx_saved.events.hit_bone.files.has(wanted), "an added file is saved with the event")
	check(is_equal_approx(float(sfx_saved.events.hit_bone.volume_db), 3.0), "the level is saved with the event")
	check(str(music_saved.states.combat.track) == "determined_pursuit", "the chosen combat track is saved")
	check(Sfx.table_version == version + 1, "saving tells the game's players to reload")
	check(not workshop.dirty, "nothing is left unsaved")
	workshop.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sfx_copy))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(music_copy))
	await process_frame
