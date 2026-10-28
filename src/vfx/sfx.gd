extends Node
## Sound effects. Every event of assets/data/audio_sfx.json lists its files
## (variants), a category from assets/data/audio_mix.json (which bus, how loud)
## and optionally a layer played with it. A play picks a variant at random,
## never the same twice in a row; its level is the mix base plus category,
## event trim and the file's own gain (assets/data/audio_library.json levels
## every file). Events without files fall back to the small synthesized sounds
## below. A fixed pool of players lets rapid hits overlap without cutting each
## other off. The Klangwerkstatt previews files and reloads edited tables.

const AudioMix = preload("res://src/audio/audio_mix.gd")
const MIX_RATE := 22050
const VOICES := 24
const TABLE_PATH := "res://assets/data/audio_sfx.json"
const LIBRARY_PATH := "res://assets/data/audio_library.json"
## Layers deeper than this are ignored (a table that names itself never loops).
const MAX_LAYERS := 2

## Bumped by the Klangwerkstatt after it saved the table; players reload then.
static var table_version := 0

var _streams: Dictionary = {}
## event -> Array of {stream, gain_db} variants (recorded effects).
var _files: Dictionary = {}
## event -> {volume_db, spread, pitch, min_interval, category, with}.
var _meta: Dictionary = {}
var _last_variant: Dictionary = {}
var _last_time: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()
var _loaded_version := -1
## The table read at load (the Klangwerkstatt may hand an edited one in).
var table: Dictionary = {}
## path -> gain_db of every library file.
var gains: Dictionary = {}
var last_effect := ""
var play_count := 0
## Bus of the last play (for tests and the Klangwerkstatt).
var last_bus := ""
## Which material a rigged enemy sounds like ("bone", "flesh", "void").
var rig_materials: Dictionary = {}


func _ready() -> void:
	_rng.seed = 7
	AudioMix.ensure_buses()
	for i in range(VOICES):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	reload()
	# name: [seconds, start Hz, end Hz, wave, noise share, volume]
	var recipes := {
		"shoot": [0.07, 920.0, 520.0, "square", 0.0, 0.35],
		# Swordsman swing (step 2): a short airy whoosh.
		"swing": [0.12, 620.0, 180.0, "sine", 0.6, 0.4],
		"enemy_shoot": [0.12, 420.0, 210.0, "square", 0.15, 0.4],
		"windup": [0.16, 160.0, 320.0, "sine", 0.0, 0.3],
		"hit": [0.07, 180.0, 90.0, "square", 0.55, 0.55],
		"boss_hit": [0.1, 110.0, 60.0, "square", 0.5, 0.65],
		"kill": [0.3, 300.0, 55.0, "square", 0.6, 0.6],
		"boss_kill": [0.9, 160.0, 30.0, "square", 0.7, 0.8],
		"hurt": [0.2, 240.0, 110.0, "square", 0.25, 0.6],
		"door": [0.18, 90.0, 60.0, "sine", 0.35, 0.6],
		"stairs": [0.46, 330.0, 110.0, "steps", 0.16, 0.55],
	}
	for name: String in recipes:
		var recipe: Array = recipes[name]
		_streams[name] = _synthesize(recipe[0], recipe[1], recipe[2], recipe[3], recipe[4], recipe[5])


func _process(_delta: float) -> void:
	if _loaded_version != table_version: reload()


## Reads the sound table and the library gains again (missing files are
## skipped, so an incomplete asset folder never breaks the game). `edited`
## replaces the table file (the Klangwerkstatt's unsaved choices).
func reload(edited: Dictionary = {}) -> void:
	_loaded_version = table_version
	_files.clear()
	_meta.clear()
	table = edited if not edited.is_empty() else _read(TABLE_PATH)
	gains.clear()
	var library := _read(LIBRARY_PATH)
	for pack: Dictionary in library.get("packs", {}).values():
		for file: Dictionary in pack.get("files", []): gains[str(file.path)] = float(file.get("gain_db", 0.0))
	rig_materials = table.get("rig_materials", {})
	for name: String in table.get("events", {}):
		var spec: Dictionary = table.events[name]
		var variants: Array = []
		for path: String in spec.get("files", _legacy_files(name, spec)):
			if not ResourceLoader.exists(path): continue
			var stream: AudioStream = load(path)
			if stream != null: variants.append({"stream": stream, "gain_db": float(gains.get(path, 0.0)), "path": path})
		_meta[name] = {"volume_db": float(spec.get("volume_db", 0.0)), "spread": float(spec.get("spread", 0.04)),
			"pitch": float(spec.get("pitch", 1.0)), "min_interval": float(spec.get("min_interval", 0.0)),
			"category": str(spec.get("category", "world")), "with": str(spec.get("with", ""))}
		if not variants.is_empty(): _files[name] = variants


## Files of a first-pass table entry without a "files" list (<event>_<n>.wav).
func _legacy_files(name: String, spec: Dictionary) -> Array:
	var folder: String = str(table.get("output", "res://assets/audio/sfx/"))
	var result: Array = []
	for index in range(int(spec.get("variants", 1))): result.append("%s%s_%d.wav" % [folder, name, index])
	return result


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## True when `name` can be played (recorded or synthesized).
func has_effect(name: String) -> bool:
	return _files.has(name) or _streams.has(name)


## Number of recorded variants of an event (0 for synthesized ones).
func variant_count(name: String) -> int:
	return _files.get(name, []).size()


## Plays a named effect; unknown names are ignored. Recorded effects use their
## table spread; `pitch_spread` only applies to synthesized ones. `category`
## overrides the event's own (a hero skill borrowing an enemy sound).
func play(name: String, pitch_spread: float = 0.08, category: String = "") -> void:
	if _play(name, pitch_spread, category, 0):
		last_effect = name
		play_count += 1


func _play(name: String, pitch_spread: float, category: String, depth: int) -> bool:
	if not has_effect(name) or _players.is_empty(): return false
	var now := Time.get_ticks_msec() / 1000.0
	var meta: Dictionary = _meta.get(name, {})
	if float(meta.get("min_interval", 0.0)) > 0.0 and now - float(_last_time.get(name, -INF)) < float(meta.min_interval): return false
	_last_time[name] = now
	var group := AudioMix.category(category if not category.is_empty() else str(meta.get("category", "world")))
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.bus = StringName(str(group.get("bus", "SFX")))
	last_bus = str(player.bus)
	var level := AudioMix.base_db() + float(group.get("volume_db", 0.0))
	if _files.has(name):
		var variants: Array = _files[name]
		var index := _rng.randi_range(0, variants.size() - 1)
		if variants.size() > 1 and index == int(_last_variant.get(name, -1)): index = (index + 1) % variants.size()
		_last_variant[name] = index
		player.stream = variants[index].stream
		player.volume_db = level + float(meta.volume_db) + float(variants[index].gain_db)
		var spread := float(meta.spread)
		player.pitch_scale = float(meta.pitch) * (1.0 + _rng.randf_range(-spread, spread))
	else:
		player.stream = _streams[name]
		player.volume_db = level
		player.pitch_scale = 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	_start(player)
	# A layer plays at the same moment (punch + grunt, clack + rattle).
	var layer := str(meta.get("with", ""))
	if not layer.is_empty() and layer != name and depth < MAX_LAYERS: _play(layer, pitch_spread, category, depth + 1)
	return true


## Plays one file as the Klangwerkstatt would hear it in the game: the file's
## gain, `volume_db` on top of the base level, on `bus`.
func preview(path: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	if not ResourceLoader.exists(path) or _players.is_empty(): return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = load(path)
	player.bus = StringName(bus)
	player.volume_db = AudioMix.base_db() + volume_db + float(gains.get(path, 0.0))
	player.pitch_scale = pitch
	last_effect = path
	last_bus = bus
	_start(player)


func _start(player: AudioStreamPlayer) -> void:
	# Dedicated/headless test processes select the real PCM but own no output
	# device. Avoid starting mixer playback that can outlive their short lifetime.
	if DisplayServer.get_name() == "headless": return
	player.play()


## Stops outstanding voices when a preview is muted or its session ends.
func stop_all() -> void:
	for player: AudioStreamPlayer in _players: player.stop()


## Read-only access for asset checks and developer previews: the first
## recorded variant, else the synthesized stream.
func effect_stream(name: String) -> AudioStream:
	if _files.has(name): return _files[name][0].stream
	return _streams.get(name)


func _synthesize(seconds: float, start_hz: float, end_hz: float, wave: String, noise: float, volume: float) -> AudioStreamWAV:
	var samples := int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = hash(wave) + samples
	var held := 0.0
	for i in range(samples):
		var t := float(i) / samples
		var frequency: float = lerpf(start_hz, end_hz, t)
		if wave == "steps": frequency = lerpf(start_hz,end_hz,floorf(t*3.0)/2.0)
		phase = fmod(phase + frequency / MIX_RATE, 1.0)
		var tone: float = signf(sin(phase * TAU)) if wave == "square" else sin(phase * TAU)
		# Sample-and-hold noise reads as a crunchy retro hit rather than hiss.
		if i % 4 == 0:
			held = noise_rng.randf_range(-1.0, 1.0)
		var envelope: float = minf(1.0, t * 40.0) * pow(1.0 - t, 2.0)
		if wave == "steps":
			var step_time := fmod(t*3.0,1.0)
			envelope *= minf(1.0,step_time*16.0)*pow(1.0-step_time,0.65)
		var value: float = lerpf(tone, held, noise) * envelope * volume
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
