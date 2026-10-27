extends Node
## Small synthesized sound effects, generated once at startup so the game needs
## no audio files. A fixed pool of players lets rapid hits overlap without
## cutting each other off; each play gets a slight pitch variation.

const MIX_RATE := 22050
const VOICES := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()
var last_effect := ""
var play_count := 0


func _ready() -> void:
	_rng.seed = 7
	for i in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		_players.append(player)
	# name: [seconds, start Hz, end Hz, wave, noise share, volume]
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
		"stairs": [0.46, 330.0, 110.0, "steps", 0.16, 0.55],
	}
	for name: String in recipes:
		var recipe: Array = recipes[name]
		_streams[name] = _synthesize(recipe[0], recipe[1], recipe[2], recipe[3], recipe[4], recipe[5])


## Plays a named effect; unknown names are ignored.
func play(name: String, pitch_spread: float = 0.08) -> void:
	if not _streams.has(name) or _players.is_empty():
		return
	last_effect = name
	play_count += 1
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[name]
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	# Dedicated/headless test processes select the real PCM but own no output
	# device. Avoid starting mixer playback that can outlive their short lifetime.
	if DisplayServer.get_name() == "headless": return
	player.play()


## Stops outstanding voices when a preview is muted or its session ends.
func stop_all() -> void:
	for player: AudioStreamPlayer in _players: player.stop()


## Read-only PCM access for asset verification and developer audio previews.
func effect_stream(name: String) -> AudioStreamWAV:
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
