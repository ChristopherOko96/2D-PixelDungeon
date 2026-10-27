extends RefCounted
## Client-only positional presentation. Simulation values always come from the
## latest authorized shown state; no prediction, collision, or entity ownership.
## Only small position summaries are buffered. Room geometry is never copied.

var _delay: float = 0.1
var _limit: int = 8
var _max_gap: float = 0.25
var _teleport_distance: float = 128.0
var _clock: float = 0.0
var _server_offset: float = 0.0
var _room_key: String = ""
var _last_sequence: int = -1
var _last_stamp: float = -INF
var _frames: Array[Dictionary] = []
var _visual_tick: int = 0
var _generation: int = 0
var _continuity: int = 0
var _after_fade: bool = false
var _cache_key: String = ""
var _cached: Dictionary = {}
var _motion_validator: Callable

## Installs an optional local collision/continuity predicate:
## (from:Vector2,to:Vector2,entity:Dictionary,layout:Dictionary)->bool.
## It runs for new moving sample pairs only. Replacing it cuts unchecked history
## while preserving sequence/time admission so old packets remain stale.
func set_motion_validator(validator: Callable) -> void:
	_motion_validator = validator
	_frames = []
	_after_fade = false
	_invalidate()

## Reads local rendering limits, not simulation rules. Invalid settings leave
## the previous configuration/history intact. Call once with balance.network.
func configure(settings: Dictionary) -> bool:
	var delay_value: Variant = settings.get("interpolation_delay",_delay)
	var limit_value: Variant = settings.get("interpolation_max_snapshots",_limit)
	var gap_value: Variant = settings.get("interpolation_max_gap",_max_gap)
	var teleport_value: Variant = settings.get("interpolation_teleport_distance",_teleport_distance)
	for value: Variant in [delay_value,limit_value,gap_value,teleport_value]:
		if not _number(value): return false
	if float(delay_value) < 0.0 or float(delay_value) > 1.0: return false
	if int(limit_value) != float(limit_value) or int(limit_value) < 2 or int(limit_value) > 32: return false
	if float(gap_value) <= 0.0 or float(teleport_value) <= 0.0: return false
	_delay = float(delay_value)
	_limit = int(limit_value)
	_max_gap = float(gap_value)
	_teleport_distance = float(teleport_value)
	reset()
	return true

## Clears prior-session history. Call at connect/disconnect/restart; a new
## server may legitimately reuse sequence numbers and room identifiers.
func reset() -> void:
	_clock = 0.0
	_server_offset = 0.0
	_room_key = ""
	_last_sequence = -1
	_last_stamp = -INF
	_frames = []
	_after_fade = false
	_visual_tick += 1
	_invalidate()

## Buffers a complete, already-authorized snapshot after geometry is restored.
## server_time is monotone host seconds; only relative intervals are used.
## Returns false for stale/invalid packets without changing current history.
func push(snapshot: Dictionary) -> bool:
	var key: String = _key(snapshot)
	var sequence: Variant = snapshot.get("seq",-1)
	var stamp_value: Variant = snapshot.get("server_time")
	if key.is_empty() or not _number(sequence) or not _number(stamp_value): return false
	if int(sequence) != float(sequence) or int(sequence) <= _last_sequence: return false
	var stamp: float = float(stamp_value)
	if stamp < 0.0 or stamp < _last_stamp: return false
	var arrival_offset: float = stamp-_clock
	var long_gap: bool = not _frames.is_empty() and stamp-_last_stamp > _max_gap
	var starved: bool = not _frames.is_empty() and _server_offset-arrival_offset > maxf(_delay,0.001)
	if key != _room_key or long_gap or starved:
		_room_key = key
		_frames = []
		_server_offset = arrival_offset
	# An outage or sustained latency increase re-seeds at the newest position.
	# Otherwise a future delayed bracket could replay motion backwards, or an
	# obsolete clock estimate would leave every later packet beyond the buffer.
	# The least-delayed observed clock offset cannot rewind as packets jitter.
	# There is no requirement for synchronized client/server system clocks.
	_server_offset = maxf(_server_offset,arrival_offset)
	var previous: Dictionary = _frames.back() if not _frames.is_empty() else {}
	var frame: Dictionary = _capture(snapshot,stamp,previous)
	if not _frames.is_empty() and stamp == float(_frames.back().stamp):
		_frames[-1] = frame
	else: _frames.append(frame)
	while _frames.size() > _limit: _frames.pop_front()
	_last_sequence = int(sequence)
	_last_stamp = stamp
	_invalidate()
	return true

## Advances once per render frame, independently of packet arrival and physics.
## sample() may then be called for both the View and camera without double time.
func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	_clock += delta
	_visual_tick += 1
	_invalidate()

## Returns the transition controller's current room with only x/y interpolated.
## Feed transition_active through the entire fade, including local fade-in.
## HP, perks, counters, entity membership, layout and seq remain authoritative.
## Returned dictionaries are read-only presentation values, just like snapshots.
func sample(shown: Dictionary, transition_active: bool = false) -> Dictionary:
	if transition_active:
		_after_fade = true
		return shown
	if _frames.is_empty() or _key(shown) != _room_key: return shown
	if _after_fade:
		_after_fade = false
		_cut_to(shown)
		return shown
	if _frames.size() < 2: return shown
	var cache_key: String = "%s:%s:%d:%d" % [_room_key,shown.get("seq",-1),_visual_tick,_generation]
	if _cache_key == cache_key: return _cached
	var target: float = _clock+_server_offset-_delay
	var lower: Dictionary = _frames.front()
	var upper: Dictionary = _frames.back()
	if target <= float(lower.stamp): upper = lower
	elif target >= float(upper.stamp): lower = upper
	else:
		for index: int in range(1,_frames.size()):
			if float(_frames[index].stamp) >= target:
				lower = _frames[index-1]
				upper = _frames[index]
				break
	var span: float = float(upper.stamp)-float(lower.stamp)
	if span > _max_gap:
		return shown
	var ratio: float = clampf((target-float(lower.stamp))/span,0.0,1.0) if span > 0.0 else 1.0
	var latest: Dictionary = _frames.back()
	var result: Dictionary = shown.duplicate()
	var players: Dictionary = {}
	for peer: Variant in shown.get("players",{}):
		var entity: Variant = shown.players[peer]
		players[peer] = _render_entity(entity,str(peer),lower.players,upper.players,latest.players,ratio) if entity is Dictionary else entity
	result.players = players
	result.enemies = _render_list(shown.get("enemies",[]),lower.enemies,upper.enemies,latest.enemies,ratio)
	result.bullets = _render_list(shown.get("bullets",[]),lower.bullets,upper.bullets,latest.bullets,ratio)
	result.local_visual_tick = _visual_tick
	_cache_key = cache_key
	_cached = result
	return result

## Exposes only the bounded queue length for diagnostics, never mutable history.
func buffered_snapshots() -> int:
	return _frames.size()

func _invalidate() -> void:
	_generation += 1
	_cache_key = ""
	_cached = {}

func _key(snapshot: Dictionary) -> String:
	var layout: Variant = snapshot.get("room_layout")
	if not layout is Dictionary or str(layout.get("id","")).is_empty(): return ""
	return "%s:%s:%s:%s" % [snapshot.get("run_seed",0),snapshot.get("floor_index",0),layout.id,snapshot.get("room_layout_revision",0)]

func _capture(snapshot: Dictionary, stamp: float, previous: Dictionary) -> Dictionary:
	var players: Dictionary = {}
	var layout: Dictionary = snapshot.get("room_layout",{})
	for peer: Variant in snapshot.get("players",{}):
		var entity: Variant = snapshot.players[peer]
		if entity is Dictionary and _point(entity).is_finite():
			players[str(peer)] = _capture_entity(entity,previous.get("players",{}).get(str(peer),{}),layout)
	return {"stamp":stamp,"players":players,"enemies":_capture_list(snapshot.get("enemies",[]),previous.get("enemies",{}),layout),"bullets":_capture_list(snapshot.get("bullets",[]),previous.get("bullets",{}),layout)}

func _capture_list(entities: Array, previous: Dictionary, layout: Dictionary) -> Dictionary:
	var captured: Dictionary = {}
	for value: Variant in entities:
		if not value is Dictionary: continue
		var id: String = _entity_id(value)
		if not id.is_empty() and _point(value).is_finite(): captured[id] = _capture_entity(value,previous.get(id,{}),layout)
	return captured

func _capture_entity(entity: Dictionary, previous: Dictionary, layout: Dictionary) -> Dictionary:
	var point: Vector2 = _point(entity)
	var alive: bool = _alive(entity)
	var signature: String = _signature(entity)
	var continuous: bool = not previous.is_empty() and previous.alive == alive and previous.signature == signature and point.distance_to(previous.point) <= _teleport_distance
	if continuous and point != previous.point and _motion_validator.is_valid():
		var accepted: Variant = _motion_validator.call(previous.point,point,entity,layout)
		continuous = accepted is bool and accepted
	if not continuous: _continuity += 1
	return {"point":point,"alive":alive,"signature":signature,"epoch":previous.epoch if continuous else _continuity}

func _render_list(entities: Array, lower: Dictionary, upper: Dictionary, latest: Dictionary, ratio: float) -> Array:
	var result: Array = []
	for value: Variant in entities:
		result.append(_render_entity(value,_entity_id(value),lower,upper,latest,ratio) if value is Dictionary else value)
	return result

func _render_entity(entity: Dictionary, id: String, lower: Dictionary, upper: Dictionary, latest: Dictionary, ratio: float) -> Dictionary:
	var result: Dictionary = entity.duplicate()
	if id.is_empty() or not _alive(entity) or not lower.has(id) or not upper.has(id) or not latest.has(id): return result
	var a: Dictionary = lower[id]
	var b: Dictionary = upper[id]
	var current: Dictionary = latest[id]
	var point: Vector2 = _point(entity)
	if not point.is_finite() or not a.alive or not b.alive: return result
	# A birth, death/revival, ID reuse or teleport anywhere after the bracket
	# invalidates that actor's older history, even while the timeline is delayed.
	if a.epoch != b.epoch or b.epoch != current.epoch or b.signature != _signature(entity): return result
	if point.distance_to(current.point) > _teleport_distance: return result
	var interpolated: Vector2 = a.point.lerp(b.point,ratio)
	result.x = interpolated.x
	result.y = interpolated.y
	return result

func _cut_to(shown: Dictionary) -> void:
	var stamp_value: Variant = shown.get("server_time")
	if not _number(stamp_value):
		_frames = []
		_invalidate()
		return
	var stamp: float = float(stamp_value)
	_frames = [_capture(shown,stamp,{})]
	_server_offset = stamp-_clock
	_invalidate()

func _entity_id(entity: Dictionary) -> String:
	var id: Variant = entity.get("id")
	if id is int and int(id) >= 0: return str(id)
	if id is String and not id.is_empty(): return id
	return ""

func _point(entity: Dictionary) -> Vector2:
	if not _number(entity.get("x")) or not _number(entity.get("y")): return Vector2(INF,INF)
	return Vector2(float(entity.x),float(entity.y))

func _alive(entity: Dictionary) -> bool:
	if entity.has("hp") and (not _number(entity.hp) or float(entity.hp) <= 0.0): return false
	return not entity.has("dying_p") or (_number(entity.dying_p) and float(entity.dying_p) < 0.0)

func _signature(entity: Dictionary) -> String:
	return "%s:%s:%s" % [entity.get("kind",""),entity.get("boss",false),entity.get("owner","")]

func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
