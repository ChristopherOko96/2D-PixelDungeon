extends RefCounted
## The game's mix (assets/data/audio_mix.json; docs/KLANG-KONZEPT.de.md section
## 3): the bus tree under Master (Music, Ambience, SFX with Focus, Voices and
## Room; Room holds Hero, Boss, Enemy, Impact, World, Step, Idle, Debris and
## Far; UI), each bus's effects by id (reverb, low-pass, high-pass, compressor),
## the ducking (sidechain compressors: a bus gets quieter while its key bus
## sounds), a limiter on Master, the per-world reverb (spaces, set_space), the
## low-pass the hero's gas drives (filters, set_muffle), the sound categories
## that give every event its bus and level, and the volume sliders. Everything
## is static so the menu, the sound player and the music share it without a
## scene singleton.
## Engine notes (docs/engine-reference/godot/modules/audio.md, Godot 4.7): a
## bus sends only to a bus with a lower index, so audio_mix.json lists parents
## before children; effects are found again by their resource_name (the id).

const DATA_PATH := "res://assets/data/audio_mix.json"
## Lowest level a slider can set before it mutes.
const SILENT_DB := -80.0

static var _data: Dictionary = {}
## Slider values (0..1) by slider name ("volume", "music", "effects").
static var _sliders: Dictionary = {}
## The world whose room the reverbs hold ("" before set_space).
static var _space := ""
## The last muffle value set (set_muffle skips repeats).
static var _muffle_k := -1.0
static var _muffle_mat := ""


## audio_mix.json, cached.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {"buses": [], "categories": {}}
	return _data


## Creates the buses, their effects, the ducking and the limiter once (safe to
## call again: present buses and effects are kept).
static func ensure_buses() -> void:
	var settings := data()
	for bus: Dictionary in settings.get("buses", []):
		var name := str(bus.name)
		if AudioServer.get_bus_index(name) >= 0: continue
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, name)
	# Sends after all buses exist (Focus sends into SFX, Hero into Room).
	for bus: Dictionary in settings.get("buses", []):
		AudioServer.set_bus_send(AudioServer.get_bus_index(str(bus.name)), StringName(str(bus.get("send", "Master"))))
	for bus: Dictionary in settings.get("buses", []):
		var index := AudioServer.get_bus_index(str(bus.name))
		for spec: Dictionary in bus.get("effects", []):
			_add_effect(index, spec)
	# ducking: one sidechain compressor per ducked bus and key
	for duck: Dictionary in settings.get("ducks", []):
		for name: String in duck.get("buses", []):
			var spec := duck.duplicate()
			spec.id = "duck:" + str(duck.get("key", "Focus"))
			spec.type = "compressor"
			spec.sidechain = str(duck.get("key", "Focus"))
			_add_effect(AudioServer.get_bus_index(name), spec)
	# the first mix's single duck block (schema 1)
	var legacy: Dictionary = settings.get("duck", {})
	for name: String in legacy.get("buses", []):
		var spec := legacy.duplicate()
		spec.id = "duck:" + str(legacy.get("key", "Focus"))
		spec.type = "compressor"
		spec.sidechain = str(legacy.get("key", "Focus"))
		_add_effect(AudioServer.get_bus_index(name), spec)
	if not _has_effect(0, "AudioEffectHardLimiter"):
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = float(settings.get("limiter", {}).get("ceiling_db", -1.0))
		AudioServer.add_bus_effect(0, limiter)
	_apply_levels()


## Adds effect `spec` ({id, type, ...}) to bus `index` unless one with its id is there.
static func _add_effect(index: int, spec: Dictionary) -> void:
	var id := str(spec.get("id", spec.get("type", "")))
	if index < 0 or id.is_empty() or _find(index, id) >= 0: return
	var effect: AudioEffect
	match str(spec.get("type", "")):
		"reverb":
			var reverb := AudioEffectReverb.new()
			for key: String in ["room_size", "damping", "spread", "hipass", "predelay_msec", "predelay_feedback"]:
				if spec.has(key): reverb.set(key, float(spec[key]))
			reverb.dry = float(spec.get("dry", 1.0))
			reverb.wet = float(spec.get("wet", 0.0))
			effect = reverb
		"lowpass":
			var low := AudioEffectLowPassFilter.new()
			low.cutoff_hz = float(spec.get("cutoff_hz", 20000))
			low.resonance = float(spec.get("resonance", 0.5))
			effect = low
		"highpass":
			var high := AudioEffectHighPassFilter.new()
			high.cutoff_hz = float(spec.get("cutoff_hz", 30))
			effect = high
		"compressor":
			var compressor := AudioEffectCompressor.new()
			compressor.threshold = float(spec.get("threshold_db", -20))
			compressor.ratio = float(spec.get("ratio", 4))
			compressor.attack_us = float(spec.get("attack_us", 2000))
			compressor.release_ms = float(spec.get("release_ms", 250))
			compressor.gain = float(spec.get("gain_db", 0))
			if str(spec.get("sidechain", "")) != "": compressor.sidechain = StringName(str(spec.sidechain))
			effect = compressor
		_:
			return
	effect.resource_name = id
	AudioServer.add_bus_effect(index, effect)
	var at := AudioServer.get_bus_effect_count(index) - 1
	var reverb_off := effect is AudioEffectReverb and float(spec.get("wet", 0.0)) <= 0.0
	if not bool(spec.get("enabled", true)) or reverb_off: AudioServer.set_bus_effect_enabled(index, at, false)


## Index of the effect named `id` on bus `bus`, or -1.
static func _find(bus: int, id: String) -> int:
	if bus < 0: return -1
	for index in range(AudioServer.get_bus_effect_count(bus)):
		if AudioServer.get_bus_effect(bus, index).resource_name == id: return index
	return -1


static func _has_effect(bus: int, type: String) -> bool:
	for index in range(AudioServer.get_bus_effect_count(bus)):
		if AudioServer.get_bus_effect(bus, index).is_class(type): return true
	return false


## The room of story world `world` (audio_mix.json spaces): every bus named in
## its "wet" gets the world's reverb at that wet share (dry stays 1).
static func set_space(world: String) -> void:
	var space: Dictionary = data().get("spaces", {}).get(world, {})
	if space.is_empty(): return
	_space = world
	var wet: Dictionary = space.get("wet", {})
	for bus_name: String in wet:
		var index := AudioServer.get_bus_index(bus_name)
		var at := _find(index, "reverb")
		if at < 0: continue
		var reverb := AudioServer.get_bus_effect(index, at) as AudioEffectReverb
		for key: String in ["room_size", "damping", "spread", "hipass", "predelay_msec", "predelay_feedback"]:
			if space.has(key): reverb.set(key, float(space[key]))
		reverb.dry = 1.0
		reverb.wet = float(wet[bus_name])
		AudioServer.set_bus_effect_enabled(index, at, reverb.wet > 0.0)


## The world whose room the reverbs hold now ("" before any).
static func space() -> String:
	return _space


## The hero's gas or steam dulls the world (KLANG-KONZEPT 3.7): every bus of
## filters.gas[mat] (else .default) gets its "muffle" low-pass, the cutoff
## gliding from open_hz to the gas's Hz as `k` (the vision value 0..1) grows;
## off at k = 0. Focus and UI are never filtered.
static func set_muffle(k: float, mat: String) -> void:
	k = clampf(k, 0.0, 1.0)
	if absf(k - _muffle_k) < 0.005 and mat == _muffle_mat: return
	_muffle_k = k
	_muffle_mat = mat
	var filters: Dictionary = data().get("filters", {})
	var gas: Dictionary = filters.get("gas", {})
	var spec: Dictionary = gas.get(mat, gas.get("default", {}))
	var open := float(filters.get("open_hz", 20000))
	var targets: Dictionary = spec.get("buses", {})
	for bus_name: String in targets:
		var index := AudioServer.get_bus_index(bus_name)
		var at := _find(index, "muffle")
		if at < 0: continue
		var on := k > 0.01
		if on:
			var filter := AudioServer.get_bus_effect(index, at) as AudioEffectFilter
			filter.cutoff_hz = open * pow(maxf(20.0, float(targets[bus_name])) / open, k)
		if AudioServer.is_bus_effect_enabled(index, at) != on: AudioServer.set_bus_effect_enabled(index, at, on)


## Bus and level of a sound category; unknown names fall back to plain SFX.
static func category(name: String) -> Dictionary:
	return data().get("categories", {}).get(name, {"bus": "SFX", "volume_db": 0})


## Names of all categories (for the Klangwerkstatt).
static func category_names() -> Array:
	return data().get("categories", {}).keys()


## Level every sound starts from before category, event and file gains.
static func base_db() -> float:
	return float(data().get("base_db", -6))


## Sets a player slider ("volume", "music" or "effects") from 0..1. The value
## is squared before it becomes decibels, so the whole travel is audible; 0 mutes.
static func set_slider(slider: String, value01: float) -> void:
	_sliders[slider] = clampf(value01, 0.0, 1.0)
	_apply_levels()


## Current slider value (1 when never set).
static func slider(slider_name: String) -> float:
	return float(_sliders.get(slider_name, 1.0))


## dB a 0..1 slider stands for (squared amplitude; SILENT_DB at 0).
static func slider_db(value01: float) -> float:
	var gain := clampf(value01, 0.0, 1.0)
	return SILENT_DB if gain <= 0.0 else linear_to_db(gain * gain)


## Bus level = its base level from the data plus every slider that covers it.
static func _apply_levels() -> void:
	var settings := data()
	var base: Dictionary = {"Master": 0.0}
	for bus: Dictionary in settings.get("buses", []): base[str(bus.name)] = float(bus.get("volume_db", 0))
	var muted: Dictionary = {}
	var offset: Dictionary = {}
	for slider_name: String in settings.get("sliders", {}):
		for bus_name: String in settings.sliders[slider_name]:
			var value := slider(slider_name)
			if value <= 0.0: muted[bus_name] = true
			offset[bus_name] = float(offset.get(bus_name, 0.0)) + (0.0 if value <= 0.0 else slider_db(value))
	for bus_name: String in base:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0: continue
		AudioServer.set_bus_mute(index, muted.has(bus_name))
		AudioServer.set_bus_volume_db(index, float(base[bus_name]) + float(offset.get(bus_name, 0.0)))
