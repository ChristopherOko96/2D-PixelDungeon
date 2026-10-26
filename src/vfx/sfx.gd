extends Node
## Small synthesized sound effects, generated once at startup so the game needs
## no audio files. A fixed pool of players lets rapid hits overlap without
## cutting each other off; each play gets a slight pitch variation.

const MIX_RATE := 22050
const VOICES := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
# Long boss sounds get their own voice, so rapid shots never cut them off.
var _long_voice: AudioStreamPlayer
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	for i in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		_players.append(player)
	_long_voice = AudioStreamPlayer.new()
	_long_voice.volume_db = -8.0
	add_child(_long_voice)
	# name: [seconds, start Hz, end Hz, wave, noise share, volume, sustained?]
	var recipes := {
		"shoot": [0.07, 920.0, 520.0, "square", 0.0, 0.35],
		"enemy_shoot": [0.12, 420.0, 210.0, "square", 0.15, 0.4],
		"windup": [0.16, 160.0, 320.0, "sine", 0.0, 0.3],
		"hit": [0.07, 180.0, 90.0, "square", 0.55, 0.55],
		"boss_hit": [0.1, 110.0, 60.0, "square", 0.5, 0.65],
		"kill": [0.3, 300.0, 55.0, "square", 0.6, 0.6],
		"boss_kill": [0.9, 160.0, 30.0, "square", 0.7, 0.8],
		"hurt": [0.2, 240.0, 110.0, "square", 0.25, 0.6],
		"door": [0.18, 90.0, 60.0, "sine", 0.35, 0.6],
		"pickup": [0.06, 1250.0, 1900.0, "sine", 0.0, 0.28],
		"swing": [0.13, 700.0, 180.0, "sine", 0.65, 0.35],
		"shield": [0.3, 900.0, 380.0, "sine", 0.2, 0.4],
		"heal": [0.3, 520.0, 880.0, "sine", 0.0, 0.3],
		"inflate": [0.5, 140.0, 420.0, "sine", 0.15, 0.4],
		"roar": [0.6, 150.0, 70.0, "square", 0.5, 0.6],
		"dash": [0.3, 260.0, 110.0, "square", 0.65, 0.5],
		"jump": [0.25, 180.0, 460.0, "sine", 0.1, 0.45],
		"slam": [0.55, 110.0, 30.0, "square", 0.75, 0.9],
		"charge": [1.5, 70.0, 560.0, "square", 0.35, 0.4, true],
		"beam": [2.4, 95.0, 70.0, "square", 0.55, 0.5, true],
	}
	for name: String in recipes:
		var recipe: Array = recipes[name]
		_streams[name] = _synthesize(recipe[0], recipe[1], recipe[2], recipe[3], recipe[4], recipe[5], recipe.size() > 6 and recipe[6])
	# Level-up: a rising major arpeggio (C E G C).
	_streams["level_up"] = _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.09, 0.4)


## Plays a named effect; unknown names are ignored.
func play(name: String, pitch_spread: float = 0.08) -> void:
	if not _streams.has(name) or _players.is_empty():
		return
	var player: AudioStreamPlayer = _long_voice
	if not name in ["charge", "beam"]:
		player = _players[_next]
		_next = (_next + 1) % _players.size()
	player.stream = _streams[name]
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	player.play()


func _synthesize(seconds: float, start_hz: float, end_hz: float, wave: String, noise: float, volume: float, sustained: bool = false) -> AudioStreamWAV:
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
		phase = fmod(phase + frequency / MIX_RATE, 1.0)
		var tone: float = signf(sin(phase * TAU)) if wave == "square" else sin(phase * TAU)
		# Sample-and-hold noise reads as a crunchy retro hit rather than hiss.
		if i % 4 == 0:
			held = noise_rng.randf_range(-1.0, 1.0)
		# Short effects decay at once; sustained ones (charge, beam) hold, then fade.
		var envelope: float = minf(1.0, t * 40.0) * (minf(1.0, (1.0 - t) * 6.0) if sustained else pow(1.0 - t, 2.0))
		var value: float = lerpf(tone, held, noise) * envelope * volume
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return _stream(data)


func _arpeggio(notes: Array, note_seconds: float, volume: float) -> AudioStreamWAV:
	var per_note := int(note_seconds * MIX_RATE)
	var tail := per_note * 3
	var data := PackedByteArray()
	data.resize((per_note * notes.size() + tail) * 2)
	for n in range(notes.size()):
		var length: int = per_note + (tail if n == notes.size() - 1 else 0)
		for i in range(length):
			var t := float(i) / length
			var tone: float = signf(sin(TAU * float(notes[n]) * i / MIX_RATE)) * 0.5 + sin(TAU * float(notes[n]) * 2.0 * i / MIX_RATE) * 0.3
			var value: float = tone * minf(1.0, t * 60.0) * pow(1.0 - t, 1.5) * volume
			data.encode_s16((n * per_note + i) * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return _stream(data)


func _stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
