extends Node
## Background music and ambience (assets/data/audio_music.json, tracks in
## audio_library.json "music"). The view tells it the moment's state through
## `request` (see `decide`): menu, explore, combat or boss. A new track fades in
## over `crossfade` seconds while the old one fades out; the same track only
## changes its level. Leaving a fight waits `calm_hold` seconds, so the music
## does not flip between waves. The ambience (wind, drips) lies underneath on
## its own bus where the state asks for it. Music and Ambience duck under the
## Focus bus (audio_mix.gd), e.g. when your hero is hit.

const AudioMix = preload("res://src/audio/audio_mix.gd")
const TABLE_PATH := "res://assets/data/audio_music.json"
const LIBRARY_PATH := "res://assets/data/audio_library.json"
const SILENT := -60.0

## Bumped by the Klangwerkstatt after it saved the table; players reload then.
static var table_version := 0
## True while the Klangwerkstatt is open: the music fades out for previews.
static var hush := false

## The state that plays (after the calm hold).
var state := ""
## Track id that plays now ("" = none).
var track := ""
var table: Dictionary = {}
var library: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _current := 0
var _ambience: AudioStreamPlayer
var _ambience_on := false
var _wanted := ""
var _calm := 0.0
var _loaded_version := -1
var _tweens: Dictionary = {}


func _ready() -> void:
	AudioMix.ensure_buses()
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = SILENT
		add_child(player)
		_players.append(player)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"Ambience"
	_ambience.volume_db = SILENT
	add_child(_ambience)
	reload()


## Reads the music table and the library again.
func reload() -> void:
	_loaded_version = table_version
	table = _read(TABLE_PATH)
	library = _read(LIBRARY_PATH).get("music", {})
	if not state.is_empty():
		var playing := state
		state = ""
		track = ""
		_enter(playing)


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The musical state for a snapshot: menu outside a run, boss while a boss or
## mini-boss lives, combat while enemies live or a horde is still coming,
## explore otherwise. Pure (tested without audio).
static func decide(snapshot: Dictionary, in_run: bool) -> String:
	var phase := str(snapshot.get("phase", ""))
	if not in_run or snapshot.is_empty() or phase in ["", "lobby", "menu", "dead"]: return "menu"
	var alive := 0
	for enemy: Dictionary in snapshot.get("enemies", []):
		if float(enemy.get("hp", 0)) <= 0.0 or float(enemy.get("dying_p", -1.0)) >= 0.0: continue
		if bool(enemy.get("boss", false)) or bool(enemy.get("miniboss", false)): return "boss"
		alive += 1
	if phase == "combat" and (alive > 0 or int(snapshot.get("horde", {}).get("left", 0)) > alive): return "combat"
	return "explore"


## Asks for a state; calmer states wait for the calm hold.
func request(next: String) -> void:
	_wanted = next


func _process(delta: float) -> void:
	if _loaded_version != table_version: reload()
	var next := "menu" if hush else _wanted
	if next.is_empty() or next == state:
		_calm = 0.0
		return
	if _calmer(next) and not hush:
		_calm += delta
		if _calm < float(table.get("calm_hold", 6.0)): return
	_calm = 0.0
	_enter(next)


## True when `next` is a step down in intensity from the current state.
func _calmer(next: String) -> bool:
	var rank := {"menu": 0, "explore": 1, "combat": 2, "boss": 3}
	return state in ["combat", "boss"] and int(rank.get(next, 0)) < int(rank.get(state, 0))


func _enter(next: String) -> void:
	state = next
	var spec: Dictionary = table.get("states", {}).get(next, {})
	var fade := float(table.get("crossfade", 1.8))
	var wanted := "" if hush else str(spec.get("track", ""))
	var level := _level(wanted, float(spec.get("volume_db", 0.0)))
	if wanted == track and not wanted.is_empty():
		_fade(_players[_current], level, fade)
	else:
		var old := _players[_current]
		_fade(old, SILENT, fade, true)
		track = wanted
		if not wanted.is_empty() and _stream(wanted) != null:
			_current = 1 - _current
			var fresh := _players[_current]
			fresh.stream = _stream(wanted)
			fresh.volume_db = SILENT
			_start(fresh)
			_fade(fresh, level, fade)
	_set_ambience(bool(spec.get("ambience", false)) and not hush, fade)


func _set_ambience(on: bool, fade: float) -> void:
	var spec: Dictionary = table.get("ambience", {})
	var id := str(spec.get("track", ""))
	if on and _stream(id) != null:
		if not _ambience_on or _ambience.stream != _stream(id):
			_ambience.stream = _stream(id)
			if not _ambience.playing: _start(_ambience)
		_fade(_ambience, _level(id, float(spec.get("volume_db", 0.0))), fade)
	elif _ambience_on:
		_fade(_ambience, SILENT, fade, true)
	_ambience_on = on


## Level of a track: its library gain plus the state's trim.
func _level(id: String, trim: float) -> float:
	return float(library.get(id, {}).get("gain_db", 0.0)) + trim


## The looping stream of a library track (null when missing).
func _stream(id: String) -> AudioStream:
	var path := str(library.get(id, {}).get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis: stream.loop = true
	elif stream is AudioStreamWAV: stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _fade(player: AudioStreamPlayer, to_db: float, seconds: float, stop_after: bool = false) -> void:
	if _tweens.has(player) and _tweens[player].is_valid(): _tweens[player].kill()
	if not is_inside_tree():
		player.volume_db = to_db
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, maxf(0.01, seconds)).set_trans(Tween.TRANS_SINE)
	if stop_after: tween.tween_callback(player.stop)
	_tweens[player] = tween


func _start(player: AudioStreamPlayer) -> void:
	# Headless test processes own no output device (see sfx.gd).
	if DisplayServer.get_name() == "headless": return
	player.play()


## Stops everything at once (a session ends or audio is switched off).
func stop_all() -> void:
	for player: AudioStreamPlayer in _players: player.stop()
	_ambience.stop()
	state = ""
	track = ""
	_ambience_on = false
