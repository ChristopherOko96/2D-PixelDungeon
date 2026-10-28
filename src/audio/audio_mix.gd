extends RefCounted
## The game's mix (assets/data/audio_mix.json): the audio buses under Master
## (Music, Ambience, SFX with its Focus part, UI), music ducking under Focus,
## a limiter on Master, the sound categories that give every event its bus and
## level, and the volume sliders. Everything is static so the menu, the sound
## player and the music can share it without a scene singleton.

const DATA_PATH := "res://assets/data/audio_mix.json"
## Lowest level a slider can set before it mutes.
const SILENT_DB := -80.0

static var _data: Dictionary = {}
## Slider values (0..1) by slider name ("volume", "music", "effects").
static var _sliders: Dictionary = {}


## audio_mix.json, cached.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {"buses": [], "categories": {}}
	return _data


## Creates the buses, the ducking and the limiter once (safe to call again).
static func ensure_buses() -> void:
	var settings := data()
	for bus: Dictionary in settings.get("buses", []):
		var name := str(bus.name)
		if AudioServer.get_bus_index(name) >= 0: continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, name)
	# Sends after all buses exist (Focus sends into SFX).
	for bus: Dictionary in settings.get("buses", []):
		AudioServer.set_bus_send(AudioServer.get_bus_index(str(bus.name)), StringName(str(bus.get("send", "Master"))))
	var duck: Dictionary = settings.get("duck", {})
	for name: String in duck.get("buses", []):
		var index := AudioServer.get_bus_index(name)
		if index < 0 or _has_effect(index, "AudioEffectCompressor"): continue
		var compressor := AudioEffectCompressor.new()
		compressor.sidechain = StringName(str(duck.get("key", "Focus")))
		compressor.threshold = float(duck.get("threshold_db", -30))
		compressor.ratio = float(duck.get("ratio", 6))
		compressor.attack_us = float(duck.get("attack_us", 2000))
		compressor.release_ms = float(duck.get("release_ms", 450))
		AudioServer.add_bus_effect(index, compressor)
	if not _has_effect(0, "AudioEffectHardLimiter"):
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = float(settings.get("limiter", {}).get("ceiling_db", -1.0))
		AudioServer.add_bus_effect(0, limiter)
	_apply_levels()


static func _has_effect(bus: int, type: String) -> bool:
	for index in range(AudioServer.get_bus_effect_count(bus)):
		if AudioServer.get_bus_effect(bus, index).is_class(type): return true
	return false


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
