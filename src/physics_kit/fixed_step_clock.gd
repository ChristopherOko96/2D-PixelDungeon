extends RefCounted
## Fixed simulation time fed by rendered frame time (physics_clock.json).
## begin_frame() adds real elapsed time; take_step() spends exactly one tick.
## The per-frame work budget never discards time: excess remains pending.
## reset() is only for deliberate suspension (menus, floor loads), not slow FPS.

const DATA_PATH := "res://assets/data/physics_clock.json"
## Only absorbs floating-point summation error at a tick boundary (seconds).
const EPSILON := 0.000000001

var step_seconds: float = 1.0 / 60.0
var max_steps_per_frame: int = 8
var pending_seconds: float = 0.0
var _steps_left: int = 0


## `config` lets callers use private settings without touching files.
func _init(config: Dictionary = {}) -> void:
	var settings: Dictionary = config if not config.is_empty() else DataCache.load_dict(DATA_PATH)
	var hz: float = float(settings.get("tick_hz", 60.0))
	if not is_finite(hz) or hz <= 0.0: hz = 60.0
	step_seconds = 1.0 / clampf(hz, 1.0, 240.0)
	max_steps_per_frame = clampi(int(settings.get("max_steps_per_frame", 8)), 1, 64)


## Adds this frame's elapsed seconds and replenishes its work budget.
## A zero delta may drain previous debt; invalid elapsed time is ignored.
func begin_frame(delta: float) -> void:
	_steps_left = max_steps_per_frame
	if is_finite(delta) and delta > 0.0:
		pending_seconds += delta


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
