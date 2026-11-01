extends Node
## Sound effects of every world (docs/KLANG-KONZEPT.de.md; the keys the story
## worlds ask for: docs/KLANG-EREIGNISSE.de.md).
## Files: every event of assets/data/audio_sfx.json lists its variants, a
## category from assets/data/audio_mix.json (bus and level) and optionally a
## layer ("with"); a play picks a variant at random, never the same twice in a
## row, at base + category + event trim + the file's gain (audio_library.json
## levels every file). An event with "sets" (schema 3) adds one key per set:
## "<event>@<set>" for set_by voice or world, else "<event>_<set>".
## Resolver (assets/data/audio_rules.json): a requested event tries
## prefer[event], the event, fallback[event], the caller's fallbacks and the
## prefix fallback; each of them as <name>_<set> (material, element, surface,
## kind) before <name>, then down the material chain (hit_stone -> hit_bone);
## each such name as <name>@<voice profile>, <name>@<world>, <name>. The first
## key with files plays; none plays nothing and is counted in `misses`. A strict
## voice profile (the archer's "female") never falls back to another voice for
## the voice events. Synthesized beeps answer only outside the story worlds.
## Voice pool: voice_pool.size slots, each with a centred AudioStreamPlayer and
## an AudioStreamPlayer2D. Priority 1 has its own reserve and is never stolen,
## priority 4 never steals; caps per event (max_voices) and per bus. A full
## pool gives up the least important voice, then the farthest, then the oldest.
## Space: a sound with a world position plays on its slot's 2D player, heard
## from the AudioListener2D at the hero (listen): distance attenuation, pan by
## the screen x (the story camera follows the hero), beyond far_from_tiles on
## the Far bus (duller, more reverb). Priority 1, focus, stinger, UI and the
## hero's own sounds stay centred. A call without a position (the crypt's
## src/vfx/feedback.gd) takes the point of the particle burst raised just before
## it in the same frame (hint) when it is a hint event (hits, kills, blocks).
## Loops (set_loop), particle sounds (particle, settle) and delayed plays
## (ctx.delay) run in _process. Debug: misses, fired, recent. The Klangwerkstatt
## previews files and reloads edited tables.

const AudioMix = preload("res://src/audio/audio_mix.gd")
const MIX_RATE := 22050
## Voice slots when audio_rules.json names no pool.
const VOICES := 40
const TABLE_PATH := "res://assets/data/audio_sfx.json"
const LIBRARY_PATH := "res://assets/data/audio_library.json"
const RULES_PATH := "res://assets/data/audio_rules.json"
## Layers deeper than this are ignored (a table that names itself never loops).
const MAX_LAYERS := 2
## Plays kept in `recent`.
const RECENT := 200

## Bumped by the Klangwerkstatt after it saved the table; players reload then.
static var table_version := 0

var _streams: Dictionary = {}
## event -> Array of {stream, gain_db, path} variants (recorded effects).
var _files: Dictionary = {}
## event -> {volume_db, spread, pitch, min_interval, category, with, priority,
## positional, max_voices, chance, vol_spread_db, max_distance, loop}.
var _meta: Dictionary = {}
var _last_variant: Dictionary = {}
var _last_time: Dictionary = {}
## The centred player of every voice slot (index = slot).
var _players: Array[AudioStreamPlayer] = []
## The positional player of every voice slot.
var _players_2d: Array[AudioStreamPlayer2D] = []
## What each slot plays: {event, bus, cap_bus, priority, start, end, dist, positional}.
var _slots: Array[Dictionary] = []
## The slot after the last one used (tests read the last player through it).
var _next := 0
var _rng := RandomNumberGenerator.new()
var _loaded_version := -1
## The table read at load (the Klangwerkstatt may hand an edited one in).
var table: Dictionary = {}
## path -> gain_db of every library file.
var gains: Dictionary = {}
## assets/data/audio_rules.json.
var rules: Dictionary = {}
var last_effect := ""
var play_count := 0
## Bus of the last play (for tests and the Klangwerkstatt).
var last_bus := ""
## Which material a rigged figure sounds like (audio_sfx.json rig_materials,
## then audio_rules.json materials on top): read by src/vfx/feedback.gd.
var rig_materials: Dictionary = {}
## The story world ("krypta", "frost", "hell"; "" elsewhere): its "@world" sets.
var world := ""
## The hero's voice profile ("female", "male_knight", ...): "@profile" sets of
## the hero's own events (voices.hero_events).
var hero_voice := ""
## The hero's floor ("stone", "snow", "ice", "wet", "ash"): sets of the step events.
var surface := ""
## False in the story worlds: no synthesized beeps there.
var synth_on := true
## Requested names that found no file, with counts (debug, the probe).
var misses: Dictionary = {}
## Keys that played, with counts (debug, the probe).
var fired: Dictionary = {}
## The last plays: {event, as, x, y, bus, priority, positional, kind, t}.
var recent: Array[Dictionary] = []
## The ear of the positional sounds; story_sound.gd moves it to the hero.
var listener: AudioListener2D
## Where the listener stands (world px; INF before the first listen).
var listener_at := Vector2.INF
var _hint := Vector2.INF
var _hint_frame := -1
var _particle_scale := 1.0
var _particle_last := {"t": -INF, "p": Vector2.INF}
var _tick_tokens := 0.0
var _tick_window := {"t": -INF, "n": 0}
var _queue: Array[Dictionary] = []
var _loops: Dictionary = {}
var _loop_missed: Dictionary = {}
var _resolved: Dictionary = {}
var _defaults_cache: Dictionary = {}


func _ready() -> void:
	_rng.seed = 7
	AudioMix.ensure_buses()
	reload()
	for i in range(maxi(1, int(_pool().get("size", VOICES)))):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
		var spatial := AudioStreamPlayer2D.new()
		add_child(spatial)
		_players_2d.append(spatial)
		_slots.append({})
	listener = AudioListener2D.new()
	add_child(listener)
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


func _process(delta: float) -> void:
	if _loaded_version != table_version: reload()
	var rate := float(_settle_rules().get("ticks_per_s", 14))
	_tick_tokens = minf(rate, _tick_tokens + delta * rate)
	_run_queue()
	_step_loops(delta)


## Reads the sound table, the rules and the library gains again (missing files
## are skipped, so an incomplete asset folder never breaks the game). `edited`
## replaces the table file (the Klangwerkstatt's unsaved choices).
func reload(edited: Dictionary = {}) -> void:
	_loaded_version = table_version
	_files.clear()
	_meta.clear()
	_resolved.clear()
	_defaults_cache.clear()
	table = edited if not edited.is_empty() else _read(TABLE_PATH)
	rules = _read(RULES_PATH)
	gains.clear()
	var library := _read(LIBRARY_PATH)
	for pack: Dictionary in library.get("packs", {}).values():
		for file: Dictionary in pack.get("files", []): gains[str(file.path)] = float(file.get("gain_db", 0.0))
	rig_materials = {}
	var legacy: Dictionary = table.get("rig_materials", {})
	for rig: String in legacy: rig_materials[rig] = _mat_name(legacy[rig])
	var own: Dictionary = rules.get("materials", {})
	for rig: String in own:
		var mat := _mat_name(own[rig])
		if mat != "": rig_materials[rig] = mat
	var events: Dictionary = table.get("events", {})
	for name: String in events:
		var spec: Dictionary = events[name]
		_add_event(name, spec, spec.get("files", _legacy_files(name, spec)))
		var sets: Variant = spec.get("sets")
		if not sets is Dictionary: continue
		var by := str(spec.get("set_by", ""))
		for set_name: String in (sets as Dictionary):
			var key := ("%s@%s" if by in ["voice", "world"] else "%s_%s") % [name, set_name]
			if not events.has(key): _add_event(key, spec, (sets as Dictionary)[set_name])


func _add_event(name: String, spec: Dictionary, paths: Variant) -> void:
	var variants: Array = []
	for path: Variant in _list(paths):
		var file := str(path)
		if not ResourceLoader.exists(file): continue
		var stream: AudioStream = load(file)
		if stream != null: variants.append({"stream": stream, "gain_db": float(gains.get(file, 0.0)), "path": file})
	_meta[name] = {"volume_db": float(spec.get("volume_db", 0.0)), "spread": float(spec.get("spread", 0.04)),
		"pitch": float(spec.get("pitch", 1.0)), "min_interval": float(spec.get("min_interval", 0.0)),
		"category": str(spec.get("category", "world")), "with": str(spec.get("with", "")),
		"priority": int(spec.get("priority", 0)), "positional": spec.get("positional"), "max_voices": int(spec.get("max_voices", 0)),
		"chance": float(spec.get("chance", -1.0)), "vol_spread_db": float(spec.get("vol_spread_db", 0.0)), "max_distance": float(spec.get("max_distance", 0.0)),
		"loop": bool(spec.get("loop", false))}
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


# --- the story world's context ---------------------------------------------------------

## Sets the story world, the hero's voice profile and story mode (no
## synthesized beeps). src/hero/story_sound.gd calls it once per world.
func configure(world_id: String, voice: String, story: bool = true) -> void:
	world = world_id
	hero_voice = voice
	synth_on = not story
	_resolved.clear()


## Moves the ear of the positional sounds to `pos` (world px, the hero).
func listen(pos: Vector2) -> void:
	listener_at = pos
	if listener == null or not listener.is_inside_tree(): return
	listener.global_position = pos
	if not listener.is_current(): listener.make_current()


## The low-pass of the hero's gas or steam (audio_mix.json filters): `k` 0..1
## is the world's vision value, `mat` the gas.
func muffle(k: float, mat: String) -> void:
	AudioMix.set_muffle(k, mat)


## The point the next position-less hint event plays at (this frame only).
func hint(point: Vector2) -> void:
	_hint = point
	_hint_frame = Engine.get_process_frames()


# --- resolving ---------------------------------------------------------------------------

## The key `name` plays as under `ctx` ("voice", "set" and the world, see the
## file comment); "" when no candidate has files.
func resolve(name: String, ctx: Dictionary = {}) -> String:
	var cache_key := "%s|%s|%s|%s|%s|%s" % [name, ctx.get("voice", ""), ctx.get("set", ""), world, synth_on, ",".join(PackedStringArray(_list(ctx.get("fallback", []))))]
	if _resolved.has(cache_key): return str(_resolved[cache_key])
	var found := ""
	for candidate: String in candidates(name, ctx):
		if _files.has(candidate) or (synth_on and _streams.has(candidate)):
			found = candidate
			break
	_resolved[cache_key] = found
	return found


## Every key `name` may play as under `ctx`, in the resolver's order.
func candidates(name: String, ctx: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	var voice := str(ctx.get("voice", ""))
	var strict := voice != "" and voice in _list(_voices().get("strict", []))
	var voice_events := _list(_voices().get("voice_events", []))
	var set_name := str(ctx.get("set", ""))
	for base: String in _bases(name, ctx):
		var names: Array[String] = []
		if set_name != "" and not base.ends_with("_" + set_name):
			names.append(base + "_" + set_name)
			# renamed sets of the library (set_alias: frost -> ice, poison -> slime, holy -> spirit)
			for alias: Variant in _list((rules.get("set_alias", {}) as Dictionary).get(set_name, [])): names.append(base + "_" + str(alias))
		names.append(base)
		for named: String in names:
			for key: String in _material_chain(named):
				var tries: Array[String] = []
				if voice != "": tries.append(key + "@" + voice)
				if not (strict and _matches(key, voice_events)):
					if world != "": tries.append(key + "@" + world)
					tries.append(key)
				for attempt: String in tries:
					if not seen.has(attempt):
						seen[attempt] = true
						out.append(attempt)
	return out


func _bases(name: String, ctx: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: Variant in _list((rules.get("prefer", {}) as Dictionary).get(name, [])): out.append(str(key))
	out.append(name)
	for key: Variant in _list((rules.get("fallback", {}) as Dictionary).get(name, [])): out.append(str(key))
	for key: Variant in _list(ctx.get("fallback", [])): out.append(str(key))
	var prefixes: Dictionary = rules.get("prefix_fallback", {})
	for prefix: String in prefixes:
		var to := str(prefixes[prefix])
		if name.begins_with(prefix) and name != to: out.append(to)
	return out


## `named` and the same event in the materials it falls back to (material_events).
func _material_chain(named: String) -> Array[String]:
	var out: Array[String] = [named]
	var fallback: Dictionary = rules.get("material_fallback", {})
	if fallback.is_empty(): return out
	for prefix: Variant in _list(rules.get("material_events", [])):
		var head := str(prefix) + "_"
		if not named.begins_with(head): continue
		var mat := named.substr(head.length())
		var guard := 0
		while fallback.has(mat) and guard < 4:
			mat = str(fallback[mat])
			out.append(head + mat)
			guard += 1
		break
	return out


## True when `name` is one of `prefixes` or starts with one ending in "_".
static func _matches(name: String, prefixes: Array) -> bool:
	for p: Variant in prefixes:
		var s := str(p)
		if name == s or (s.ends_with("_") and name.begins_with(s)): return true
	return false


## The caller's context plus what the world adds: the hero's voice for his own
## events, the floor for steps, the particle hint for position-less hits.
func _context(name: String, ctx: Dictionary, with_hint: bool) -> Dictionary:
	var out := ctx.duplicate()
	if not out.has("voice") and hero_voice != "" and _matches(name, _list(_voices().get("hero_events", []))):
		out.voice = hero_voice
		out.hero = true
	if not out.has("set") and surface != "" and name in _list(rules.get("surface_events", [])):
		out.set = surface
	if with_hint and not out.has("pos") and not bool(out.get("hero", false)) and _hint_frame == Engine.get_process_frames() and _matches(name, _list(_spatial().get("hint_events", []))):
		out.pos = _hint
		_hint_frame = -1
	return out


## True when `name` can be played (recorded or, outside the story, synthesized).
func has_effect(name: String) -> bool:
	return resolve(name, _context(name, {}, false)) != ""


## True when `name` can be played under `ctx`.
func can_play(name: String, ctx: Dictionary = {}) -> bool:
	return resolve(name, _context(name, ctx, false)) != ""


## Number of recorded variants of an exact key (0 for synthesized ones).
func variant_count(name: String) -> int:
	return _files.get(name, []).size()


# --- playing -----------------------------------------------------------------------------

## Plays a named effect; unknown names are ignored. Recorded effects use their
## table spread; `pitch_spread` only applies to synthesized ones. `category`
## overrides the event's own (a hero skill borrowing an enemy sound).
func play(name: String, pitch_spread: float = 0.08, category: String = "") -> void:
	var ctx := {"spread": pitch_spread}
	if not category.is_empty(): ctx.category = category
	play_ctx(name, ctx)


## Plays `name` from world point `pos` (world px).
func play_at(name: String, pos: Vector2, ctx: Dictionary = {}) -> bool:
	var full := ctx.duplicate()
	full.pos = pos
	return play_ctx(name, full)


## Plays `name` under `ctx`: pos (Vector2, world px), voice, set, category,
## priority, pitch (factor), volume_db (trim), size ("small", "big"), chance,
## delay (s), fallback (names), hero (the hero's own: centred), reach_scale,
## emitter (the id of what keeps a looping event going). An event with
## "loop": true sounds as one looped player per emitter (set_loop; without an
## emitter its name and tile) that fades out once the emitter stops asking.
## Returns true when it started (or was queued).
func play_ctx(name: String, ctx: Dictionary = {}) -> bool:
	if name.is_empty(): return false
	if float(ctx.get("delay", 0.0)) > 0.0:
		var later := ctx.duplicate()
		later.erase("delay")
		_queue.append({"at": _now() + float(ctx.delay), "name": name, "ctx": later})
		return true
	if _slots.is_empty(): return false
	var full := _context(name, ctx, true)
	var key := resolve(name, full)
	if key != "" and bool((_meta.get(key, {}) as Dictionary).get("loop", false)):
		var spot: Vector2 = full.get("pos", Vector2.INF)
		var emitter := str(full.get("emitter", "%s@%s" % [name, str(spot.snapped(Vector2(96, 96))) if spot.is_finite() else "hero"]))
		set_loop(emitter, name, true, full)
		return true
	var played := _play(name, full, 0)
	if played:
		last_effect = name
		play_count += 1
	return played


func _play(name: String, ctx: Dictionary, depth: int) -> bool:
	var key := resolve(name, ctx)
	if key.is_empty():
		_miss(name)
		return false
	var meta: Dictionary = _meta.get(key, {})
	var rule := _defaults(key, name)
	var now := _now()
	var gap := float(meta.get("min_interval", 0.0))
	if gap <= 0.0: gap = float(rule.get("min_interval", 0.0))
	if gap > 0.0 and now - float(_last_time.get(key, -INF)) < gap: return false
	var chance := float(ctx.get("chance", meta.get("chance", -1.0)))
	if chance < 0.0: chance = float(rule.get("chance", 1.0))
	if chance < 1.0 and _rng.randf() > chance: return false
	var category := str(ctx.get("category", ""))
	if category.is_empty(): category = str(meta.get("category", "world"))
	var group := AudioMix.category(category)
	var priority := _priority(meta, rule, category, ctx)
	var pos: Vector2 = ctx.get("pos", Vector2.INF)
	var positional := _positional(pos, category, priority, ctx, meta)
	var dist := pos.distance_to(listener_at) if positional and listener_at.is_finite() else 0.0
	var reach := _reach(category, meta, ctx)
	if positional and dist > reach: return false
	if positional and priority >= 4 and dist > float(_spatial().get("p4_cull_tiles", 9)) * _tile(): return false
	var cap_bus := str(group.get("bus", "SFX"))
	var bus := cap_bus
	if positional and dist > float(_spatial().get("far_from_tiles", 8)) * _tile() and cap_bus in _list(_spatial().get("far_from_buses", [])):
		bus = str(_spatial().get("far_bus", "Far"))
	var limit := int(meta.get("max_voices", 0))
	if limit <= 0: limit = int(rule.get("max_voices", _pool().get("max_voices", 3)))
	var slot := _take_slot(key, cap_bus, priority, limit)
	if slot < 0: return false
	_last_time[key] = now
	var level := AudioMix.base_db() + float(group.get("volume_db", 0.0)) + float(ctx.get("volume_db", 0.0))
	var pitch := float(ctx.get("pitch", 1.0)) * _size_pitch(str(ctx.get("size", "")))
	var stream: AudioStream
	if _files.has(key):
		var variants: Array = _files[key]
		var index := _rng.randi_range(0, variants.size() - 1)
		if variants.size() > 1 and index == int(_last_variant.get(key, -1)): index = (index + 1) % variants.size()
		_last_variant[key] = index
		var variant: Dictionary = variants[index]
		stream = variant.stream
		var vol_spread := float(meta.get("vol_spread_db", 0.0))
		level += float(meta.get("volume_db", 0.0)) + float(variant.gain_db) + _rng.randf_range(-vol_spread, vol_spread)
		var spread := float(meta.get("spread", 0.04))
		pitch *= float(meta.get("pitch", 1.0)) * (1.0 + _rng.randf_range(-spread, spread))
	else:
		stream = _streams[key]
		var synth_spread := float(ctx.get("spread", 0.08))
		pitch *= 1.0 + _rng.randf_range(-synth_spread, synth_spread)
	pitch = clampf(pitch, 0.25, 4.0)
	_players[slot].stop()
	_players_2d[slot].stop()
	if positional:
		var spatial := _players_2d[slot]
		spatial.stream = stream
		spatial.bus = StringName(bus)
		spatial.volume_db = level
		spatial.pitch_scale = pitch
		spatial.global_position = pos
		spatial.max_distance = reach
		spatial.attenuation = float(_spatial().get("attenuation", 1.6))
		spatial.panning_strength = float(_spatial().get("panning_strength", 0.5))
		_start(spatial)
	else:
		var player := _players[slot]
		player.stream = stream
		player.bus = StringName(bus)
		player.volume_db = level
		player.pitch_scale = pitch
		_start(player)
	var length := stream.get_length() if stream != null else 0.0
	_slots[slot] = {"event": key, "bus": bus, "cap_bus": cap_bus, "priority": priority, "start": now,
		"end": now + (length / pitch if length > 0.0 else 1.0), "dist": dist, "positional": positional}
	_next = (slot + 1) % _slots.size()
	last_bus = bus
	fired[key] = int(fired.get(key, 0)) + 1
	_log(name, key, pos if positional else Vector2.INF, bus, priority, positional, "play")
	# a layer plays at the same moment and place (punch + grunt, clack + rattle, step + foley)
	if depth < MAX_LAYERS:
		for layer: String in _layers(name, key, meta):
			if layer != name and layer != key: _play(layer, ctx, depth + 1)
	return true


## Layers of a play: the table's "with" and audio_rules.json layers of the
## requested name or the played key.
func _layers(name: String, key: String, meta: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var with := str(meta.get("with", ""))
	if with != "": out.append(with)
	var own: Dictionary = rules.get("layers", {})
	for subject: String in [name, key.get_slice("@", 0)]:
		for layer: Variant in _list(own.get(subject, [])):
			if not str(layer) in out: out.append(str(layer))
	return out


## True when a play sounds from its position (else centred).
func _positional(pos: Vector2, category: String, priority: int, ctx: Dictionary, meta: Dictionary) -> bool:
	if not pos.is_finite() or bool(ctx.get("hero", false)) or priority <= 1: return false
	if meta.get("positional") is bool and not bool(meta.positional): return false
	return not (category in _list(_spatial().get("centred_categories", [])))


## How far a sound carries (world px): the event's max_distance, else
## max_tiles scaled by its category, times ctx.reach_scale.
func _reach(category: String, meta: Dictionary, ctx: Dictionary) -> float:
	var reach := float(meta.get("max_distance", 0.0))
	if reach <= 0.0:
		reach = float(_spatial().get("max_tiles", 14)) * _tile() * float((_spatial().get("reach_by_category", {}) as Dictionary).get(category, 1.0))
	return reach * float(ctx.get("reach_scale", 1.0))


func _priority(meta: Dictionary, rule: Dictionary, category: String, ctx: Dictionary) -> int:
	if ctx.has("priority"): return int(ctx.priority)
	if int(meta.get("priority", 0)) > 0: return int(meta.priority)
	if rule.has("priority"): return int(rule.priority)
	var spec: Dictionary = rules.get("priorities", {})
	return int((spec.get("categories", {}) as Dictionary).get(category, spec.get("default", 3)))


## audio_rules.json event_defaults of a key (its longest matching prefix; the
## requested name when the key has none).
func _defaults(key: String, name: String) -> Dictionary:
	var cache := key + "|" + name
	if _defaults_cache.has(cache): return _defaults_cache[cache]
	var all: Dictionary = rules.get("event_defaults", {})
	var best := ""
	for subject: String in [key.get_slice("@", 0), name]:
		for prefix: String in all:
			if prefix.length() > best.length() and (subject == prefix or (prefix.ends_with("_") and subject.begins_with(prefix)) or subject.begins_with(prefix + "_")):
				best = prefix
		if best != "": break
	var out: Dictionary = all.get(best, {}) if best != "" else {}
	_defaults_cache[cache] = out
	return out


## A slot for a new voice, or -1: the event's and the bus's caps first, then a
## free slot (priority 1 also in the reserve), then a voice it may take over.
func _take_slot(key: String, cap_bus: String, priority: int, limit: int) -> int:
	var now := _now()
	var same: Array[int] = []
	var on_bus: Array[int] = []
	for i in range(_slots.size()):
		if not _active(i, now): continue
		if str(_slots[i].event) == key: same.append(i)
		if str(_slots[i].cap_bus) == cap_bus: on_bus.append(i)
	if same.size() >= maxi(1, limit):
		return -1 if priority >= 4 else _oldest(same)
	var caps: Dictionary = _pool().get("bus_caps", {})
	if caps.has(cap_bus) and on_bus.size() >= int(caps[cap_bus]):
		return -1 if priority >= 4 else _victim(on_bus, priority)
	var reserved := clampi(int(_pool().get("p1_reserved", 8)), 0, _slots.size() - 1)
	for i in range(reserved, _slots.size()):
		if not _active(i, now): return i
	if priority <= 1:
		for i in range(reserved):
			if not _active(i, now): return i
	if priority >= 4: return -1
	var shared: Array[int] = []
	for i in range(reserved, _slots.size()): shared.append(i)
	return _victim(shared, priority)


## The voice a new sound of `priority` may take: never priority 1, only one as
## important or less; the least important, then the farthest, then the oldest.
func _victim(indices: Array[int], priority: int) -> int:
	var best := -1
	for i: int in indices:
		var s: Dictionary = _slots[i]
		var p := int(s.priority)
		if p <= 1 or p < priority: continue
		if best < 0:
			best = i
			continue
		var b: Dictionary = _slots[best]
		var further := float(s.dist) > float(b.dist)
		var older := is_equal_approx(float(s.dist), float(b.dist)) and float(s.start) < float(b.start)
		if p > int(b.priority) or (p == int(b.priority) and (further or older)): best = i
	return best


func _oldest(indices: Array[int]) -> int:
	var best := indices[0]
	for i: int in indices:
		if float(_slots[i].start) < float(_slots[best].start): best = i
	return best


## True while slot `i` still sounds (its length; a stopped player frees it early).
func _active(i: int, now: float) -> bool:
	var s: Dictionary = _slots[i]
	if s.is_empty() or now >= float(s.end): return false
	if DisplayServer.get_name() != "headless" and now - float(s.start) > 0.1:
		var playing: bool = _players_2d[i].playing if bool(s.positional) else _players[i].playing
		if not playing: return false
	return true


func _start(player: Node) -> void:
	# Dedicated/headless test processes select the real PCM but own no output
	# device. Avoid starting mixer playback that can outlive their short lifetime.
	if DisplayServer.get_name() == "headless": return
	player.call("play")


func _run_queue() -> void:
	if _queue.is_empty(): return
	var now := _now()
	var due: Array[Dictionary] = []
	for i in range(_queue.size() - 1, -1, -1):
		if float(_queue[i].at) <= now:
			due.push_front(_queue[i])
			_queue.remove_at(i)
	for item: Dictionary in due: play_ctx(str(item.name), item.ctx)


# --- loops -------------------------------------------------------------------------------

## Keeps looping event `name` sounding under `id` while called every frame
## with `on` true (a zone, the gas, the heartbeat); it fades in and out over
## voice_pool.loop_fade_s and stops loop_idle_s after the last call. At most
## voice_pool.loops at once: the nearest win. ctx as in play_ctx.
func set_loop(id: String, name: String, on: bool, ctx: Dictionary = {}) -> void:
	if not on:
		if _loops.has(id): _loops[id].want = 0.0
		return
	var full := _context(name, ctx, false)
	var pos: Vector2 = full.get("pos", Vector2.INF)
	if _loops.has(id):
		var loop: Dictionary = _loops[id]
		loop.touched = _now()
		loop.want = 1.0
		loop.trim = float(full.get("volume_db", 0.0))
		var held: Node = loop.player
		held.set("pitch_scale", clampf(float(full.get("pitch", 1.0)) * float(loop.pitch), 0.25, 4.0))
		if pos.is_finite() and held is AudioStreamPlayer2D: (held as AudioStreamPlayer2D).global_position = pos
		loop.pos = pos
		return
	var key := resolve(name, full)
	if key.is_empty() or not _files.has(key):
		if not _loop_missed.has(id):
			_loop_missed[id] = true
			_miss(name)
		return
	_loop_missed.erase(id)
	var meta: Dictionary = _meta.get(key, {})
	var category := str(full.get("category", meta.get("category", "world")))
	var group := AudioMix.category(category)
	var priority := _priority(meta, _defaults(key, name), category, full)
	var positional := _positional(pos, category, priority, full, meta)
	var dist := pos.distance_to(listener_at) if positional and listener_at.is_finite() else 0.0
	var reach := _reach(category, meta, full)
	if positional and dist > reach: return
	if _loops.size() >= int(_pool().get("loops", 6)):
		var far := ""
		var far_dist := -1.0
		for other: String in _loops:
			var there: Vector2 = _loops[other].pos
			var d := there.distance_to(listener_at) if there.is_finite() and listener_at.is_finite() else 0.0
			if d > far_dist:
				far = other
				far_dist = d
		if far == "" or far_dist <= dist: return
		_drop_loop(far)
	var variants: Array = _files[key]
	var variant: Dictionary = variants[_rng.randi_range(0, variants.size() - 1)]
	var stream: AudioStream = variant.stream
	# Ogg and MP3 loop by themselves; a WAV without loop points restarts in _step_loops
	if "loop" in stream: stream.set("loop", true)
	var player: Node
	if positional:
		var spatial := AudioStreamPlayer2D.new()
		spatial.position = pos
		spatial.max_distance = reach
		spatial.attenuation = float(_spatial().get("attenuation", 1.6))
		spatial.panning_strength = float(_spatial().get("panning_strength", 0.5))
		player = spatial
	else:
		player = AudioStreamPlayer.new()
	var bus := str(group.get("bus", "SFX"))
	var pitch := float(meta.get("pitch", 1.0))
	player.set("stream", stream)
	player.set("bus", StringName(bus))
	player.set("pitch_scale", clampf(float(full.get("pitch", 1.0)) * pitch, 0.25, 4.0))
	player.set("volume_db", -80.0)
	add_child(player)
	_loops[id] = {"player": player, "key": key, "base": AudioMix.base_db() + float(group.get("volume_db", 0.0)) + float(meta.get("volume_db", 0.0)) + float(variant.gain_db),
		"trim": float(full.get("volume_db", 0.0)), "gain": 0.0, "want": 1.0, "touched": _now(), "pos": pos, "pitch": pitch}
	_start(player)
	fired[key] = int(fired.get(key, 0)) + 1
	_log(name, key, pos if positional else Vector2.INF, bus, priority, positional, "loop")


func _step_loops(delta: float) -> void:
	if _loops.is_empty(): return
	var now := _now()
	var fade := maxf(0.01, float(_pool().get("loop_fade_s", 0.2)))
	var idle := float(_pool().get("loop_idle_s", 0.25))
	for id: String in _loops.keys():
		var loop: Dictionary = _loops[id]
		if now - float(loop.touched) > idle: loop.want = 0.0
		loop.gain = move_toward(float(loop.gain), float(loop.want), delta / fade)
		if float(loop.gain) <= 0.0 and float(loop.want) <= 0.0:
			_drop_loop(id)
			continue
		var player: Node = loop.player
		player.set("volume_db", float(loop.base) + float(loop.trim) + linear_to_db(maxf(float(loop.gain), 0.0001)))
		if DisplayServer.get_name() != "headless" and not bool(player.get("playing")): player.call("play")


func _drop_loop(id: String) -> void:
	var player: Node = _loops[id].player
	player.queue_free()
	_loops.erase(id)


## Ids of the loops that sound now (debug, the probe).
func loop_ids() -> Array:
	return _loops.keys()


# --- particles ---------------------------------------------------------------------------

## Binds a particle system (src/vfx/particles.gd, its `sound`): its calls sound
## through particle() and settle(); `scale` turns its units into world px
## (the feel's crypt units: src/hero/story_feel.gd scale).
func attach_particles(particles: Object, scale: float) -> void:
	if particles == null or not "sound" in particles: return
	particles.set("sound", self)
	_particle_scale = scale


## One sound for one particle call, never per particle (KLANG-KONZEPT 3.9):
## `kind` maps through particles.events; calls within cluster_s and cluster_px
## of the last particle sound are part of it; the level follows `count`
## (db_per_doubling around base_count). Always leaves the point as the hint.
func particle(kind: String, point: Vector2, count: int = 8) -> void:
	var at := point * _particle_scale
	hint(at)
	var spec: Dictionary = rules.get("particles", {})
	var name := str((spec.get("events", {}) as Dictionary).get(kind, kind))
	if name.is_empty(): return
	var now := _now()
	var last: Vector2 = _particle_last.p
	if now - float(_particle_last.t) < float(spec.get("cluster_s", 0.06)) and at.distance_to(last) < float(spec.get("cluster_px", 60.0)): return
	var trim := float(spec.get("db_per_doubling", 4.0)) * log(maxf(1.0, float(count)) / maxf(1.0, float(spec.get("base_count", 8)))) / log(2.0)
	if play_ctx(name, {"pos": at, "category": "debris", "volume_db": clampf(trim, float(spec.get("min_db", -6.0)), float(spec.get("max_db", 3.0)))}):
		_particle_last = {"t": now, "p": at}


## A piece came to rest (src/vfx/particles.gd _settle): a landing tick in its
## material by chance (particles.settle.chance), within ticks_per_s; more than
## bundle_max in bundle_s become one patter instead.
func settle(particle: Dictionary) -> void:
	var spec := _settle_rules()
	var kinds: Dictionary = spec.get("materials", {})
	var mat := ""
	for marker: String in ["shard", "skull"]:
		if particle.has(marker): mat = str(kinds.get(marker, ""))
	if mat == "": mat = str(kinds.get(str(particle.get("mode", "")), ""))
	if mat == "": return
	var chances: Dictionary = spec.get("chance", {})
	if _rng.randf() > float(chances.get(mat, spec.get("chance_default", 0.2))): return
	var at: Vector2 = Vector2(particle.get("pos", Vector2.ZERO)) * _particle_scale
	var now := _now()
	if now - float(_tick_window.t) > float(spec.get("bundle_s", 0.1)): _tick_window = {"t": now, "n": 0}
	_tick_window.n = int(_tick_window.n) + 1
	var most := int(spec.get("bundle_max", 6))
	if int(_tick_window.n) > most:
		if int(_tick_window.n) == most + 1: play_ctx(str(spec.get("bundle_event", "settle_patter")), {"pos": at, "category": "debris"})
		return
	if _tick_tokens < 1.0: return
	_tick_tokens -= 1.0
	play_ctx("settle_tick", {"pos": at, "set": mat, "category": "debris", "volume_db": _rng.randf_range(-3.0, 3.0)})


# --- helpers -----------------------------------------------------------------------------

func _pool() -> Dictionary:
	return rules.get("voice_pool", {})


func _voices() -> Dictionary:
	return rules.get("voices", {})


func _spatial() -> Dictionary:
	return rules.get("spatial", {})


func _settle_rules() -> Dictionary:
	return (rules.get("particles", {}) as Dictionary).get("settle", {})


func _tile() -> float:
	return float(_spatial().get("tile_px", 96.0))


func _size_pitch(size: String) -> float:
	return 1.0 if size.is_empty() else float((rules.get("sizes", {}) as Dictionary).get(size, 1.0))


static func _list(v: Variant) -> Array:
	return v if v is Array else []


static func _mat_name(v: Variant) -> String:
	return str((v as Dictionary).get("mat", "")) if v is Dictionary else str(v)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _miss(name: String) -> void:
	misses[name] = int(misses.get(name, 0)) + 1


func _log(name: String, key: String, pos: Vector2, bus: String, priority: int, positional: bool, kind: String) -> void:
	recent.append({"event": name, "as": key, "x": pos.x if pos.is_finite() else 0.0, "y": pos.y if pos.is_finite() else 0.0,
		"bus": bus, "priority": priority, "positional": positional, "kind": kind, "t": _now()})
	if recent.size() > RECENT: recent.pop_front()


## Counts for the debug Testraum and the probe: fired, misses, recent, loops.
func report() -> Dictionary:
	return {"fired": fired.duplicate(), "misses": misses.duplicate(), "recent": recent.duplicate(), "loops": _loops.keys(), "world": world, "voice": hero_voice}


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


## Stops outstanding voices and loops when a preview is muted or its session ends.
func stop_all() -> void:
	for player: AudioStreamPlayer in _players: player.stop()
	for spatial: AudioStreamPlayer2D in _players_2d: spatial.stop()
	for id: String in _loops.keys(): _drop_loop(id)
	_queue.clear()


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
