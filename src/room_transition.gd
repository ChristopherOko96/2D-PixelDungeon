extends Control
## Client-local room presentation. Host snapshots retain simulation authority.
## Call update() once per rendered frame, before displaying display_state().
## A full-black frame fence protects room swaps even after delayed packets.
signal sound_requested(kind: String)

enum Phase { IDLE, OUT, BLACK, IN }
var opacity := 0.0
var current_token := -1
var _phase := Phase.IDLE
var _phase_time := 0.0
var _fade_out := 0.22
var _black_hold := 0.08
var _fade_in := 0.22
var _frame := 0
var _covered_frame := -1
var _from_id := ""
var _display: Dictionary = {}
var _pending: Dictionary = {}

func _ready() -> void:
	get_viewport().size_changed.connect(_resize_to_viewport)
	_resize_to_viewport()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sync_visual()

func _resize_to_viewport() -> void:
	size = get_viewport_rect().size
	queue_redraw()

func _draw() -> void:
	if opacity > 0.0: draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,opacity))

## Accepts finite seconds for fade_out/black_hold/fade_in. Invalid input leaves
## all prior timing values intact. The host supplies the same external settings.
func configure(timing: Dictionary) -> bool:
	var outgoing: Variant = timing.get("fade_out",_fade_out)
	var hold: Variant = timing.get("black_hold",_black_hold)
	var incoming: Variant = timing.get("fade_in",_fade_in)
	for value: Variant in [outgoing,hold,incoming]:
		if not _number(value): return false
	if float(outgoing) <= 0.0 or float(incoming) <= 0.0 or float(hold) < 0.0: return false
	_fade_out = float(outgoing)
	_black_hold = float(hold)
	_fade_in = float(incoming)
	return true

## Receives already-authorized host snapshots. A new token starts one local
## fade and sound; elapsed metadata never jumps over local black presentation.
## Target snapshots are copied and held until the old room has been covered.
func apply_state(snapshot: Dictionary) -> void:
	var incoming_id := _room_id(snapshot)
	if incoming_id.is_empty():
		reset()
		_display = _retain_snapshot(snapshot)
		return
	var metadata := _metadata(snapshot.get("transition",{}))
	if not metadata.is_empty():
		var token := int(metadata.token)
		if token < current_token: return
		if token > current_token: _begin(metadata)
		elif not is_active():
			# A late pre-swap packet cannot restore the completed source room.
			if incoming_id == _from_id and incoming_id != _room_id(_display): return
			_display = _retain_snapshot(snapshot)
			return
	if is_active():
		if incoming_id == _from_id:
			if _phase == Phase.OUT and _room_id(_display) == _from_id:
				_display = _retain_snapshot(snapshot)
		else:
			_pending = _retain_snapshot(snapshot)
			if _phase == Phase.IN:
				_display = _pending
				_pending = {}
	else:
		_display = _retain_snapshot(snapshot)

## Retains independent simulation values while sharing immutable tile geometry.
## The small layout header is copied so callers cannot alter its room identity.
func _retain_snapshot(snapshot: Dictionary) -> Dictionary:
	var envelope := snapshot.duplicate()
	var layout: Variant = envelope.get("room_layout",{})
	envelope.erase("room_layout")
	var retained := envelope.duplicate(true)
	retained.room_layout = layout.duplicate() if layout is Dictionary else {}
	return retained

## Advances one presentation frame. Stage changes deliberately do not consume
## a large delta across multiple phases: black is always presented before IN.
## Headless tests exercise the exact same frame fence without a GPU dependency.
func update(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	_frame += 1
	if _phase == Phase.IDLE: return
	match _phase:
		Phase.OUT:
			_phase_time += delta
			opacity = clampf(_phase_time/_fade_out,0.0,1.0)
			if _phase_time >= _fade_out:
				_phase = Phase.BLACK
				_phase_time = 0.0
				_covered_frame = _frame
				opacity = 1.0
		Phase.BLACK:
			_phase_time += delta
			opacity = 1.0
			if _frame > _covered_frame and _phase_time >= _black_hold and not _pending.is_empty():
				_display = _pending
				_pending = {}
				_phase = Phase.IN
				_phase_time = 0.0
		Phase.IN:
			_phase_time += delta
			opacity = clampf(1.0-_phase_time/_fade_in,0.0,1.0)
			if _phase_time >= _fade_in:
				_phase = Phase.IDLE
				_phase_time = 0.0
				opacity = 0.0
	_sync_visual()

## Snapshot to give the room renderer after update(). Treat it as read-only.
## It may be the old room while a newer authoritative room waits behind black.
func display_state() -> Dictionary:
	return _display

## Remains true through local fade-in even after the host cleared its metadata.
func is_active() -> bool:
	return _phase != Phase.IDLE

## Cancels presentation on disconnect/new run and permits fresh token numbering.
func reset() -> void:
	_phase = Phase.IDLE
	_phase_time = 0.0
	opacity = 0.0
	current_token = -1
	_from_id = ""
	_display = {}
	_pending = {}
	_covered_frame = -1
	_sync_visual()

func _begin(metadata: Dictionary) -> void:
	var previous_opacity := opacity if is_active() else 0.0
	current_token = int(metadata.token)
	_from_id = str(metadata.from_id)
	_pending = {}
	_phase = Phase.OUT
	_phase_time = previous_opacity*_fade_out
	_covered_frame = -1
	opacity = previous_opacity
	if _room_id(_display).is_empty() or previous_opacity >= 1.0:
		# Joining a transition without an old picture starts fully covered.
		# The next whole update frame must stay black before a target can swap.
		_phase = Phase.BLACK
		_phase_time = 0.0
		opacity = 1.0
		_covered_frame = _frame+1
	_sync_visual()
	sound_requested.emit(str(metadata.kind))

func _sync_visual() -> void:
	visible = is_active()
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active() else Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _room_id(snapshot: Dictionary) -> String:
	var layout: Variant = snapshot.get("room_layout",{})
	return str(layout.get("id","")) if layout is Dictionary else ""

func _metadata(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	if not value.get("token") is int or int(value.token) < 0: return {}
	if value.get("kind","") not in ["door","stairs"]: return {}
	if not value.get("from_id") is String or str(value.from_id).is_empty(): return {}
	if value.has("elapsed") and (not _number(value.elapsed) or float(value.elapsed) < 0.0): return {}
	return value

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
