extends RefCounted
## Fixed simulation time fed by rendered frame time (physics_clock.json).
## begin_frame() adds real elapsed time; take_step() spends exactly one tick.
## Excess beyond the per-frame work budget stays pending, up to max_pending_steps
## ticks; time beyond that limit is dropped (0 = keep all time), so an overloaded
## frame cannot pile up more catch-up work for the next ones (the world slows instead).
## reset() is only for deliberate suspension (menus, floor loads), not slow FPS.

const DATA_PATH := "res://assets/data/physics_clock.json"
## Only absorbs floating-point summation error at a tick boundary (seconds).
const EPSILON := 0.000000001

var step_seconds: float = 1.0 / 60.0
var max_steps_per_frame: int = 8
## The most ticks of time that may wait; more is dropped. 0 keeps all elapsed time.
var max_pending_steps: int = 0
var pending_seconds: float = 0.0
var _steps_left: int = 0


## `config` lets callers use private settings without touching files.
func _init(config: Dictionary = {}) -> void:
	var settings: Dictionary = config if not config.is_empty() else DataCache.load_dict(DATA_PATH)
	var hz: float = float(settings.get("tick_hz", 60.0))
	if not is_finite(hz) or hz <= 0.0: hz = 60.0
	step_seconds = 1.0 / clampf(hz, 1.0, 240.0)
	max_steps_per_frame = clampi(int(settings.get("max_steps_per_frame", 8)), 1, 64)
	max_pending_steps = clampi(int(settings.get("max_pending_steps", 0)), 0, 64)


## Adds this frame's elapsed seconds and replenishes its work budget.
## A zero delta may drain previous debt; invalid elapsed time is ignored.
## With max_pending_steps, time beyond that many ticks is dropped here.
func begin_frame(delta: float) -> void:
	_steps_left = max_steps_per_frame
	if is_finite(delta) and delta > 0.0:
		pending_seconds += delta
		if max_pending_steps > 0:
			pending_seconds = minf(pending_seconds, step_seconds * float(max_pending_steps))


## True exactly once for each due tick, up to this frame's budget.
## Call the simulation with step_seconds for each true result.
func take_step() -> bool:
	if _steps_left <= 0 or pending_seconds + EPSILON < step_seconds:
		return false
	pending_seconds = maxf(0.0, pending_seconds - step_seconds)
	_steps_left -= 1
	return true


## Discards suspended time and cancels any remaining ticks in the current batch.
func reset() -> void:
	pending_seconds = 0.0
	_steps_left = 0
