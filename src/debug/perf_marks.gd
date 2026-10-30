extends RefCounted
## Named time totals for the benches (scripts/bench_vfx.gd, scripts/bench_spells.gd):
## code marks the start of a part with begin() and adds the time since to a
## name with add(name); the bench reads totals and clears them. It only adds
## numbers up (two clock reads per part); nothing in the game reads them.

## name -> microseconds so far.
static var totals: Dictionary = {}
static var _started := 0


## The part being timed begins now.
static func begin() -> void:
	_started = Time.get_ticks_usec()


## Adds the time since begin() (or the last add) to `name`; the next part begins now.
static func add(name: String) -> void:
	var now := Time.get_ticks_usec()
	totals[name] = int(totals.get(name, 0)) + now - _started
	_started = now


static func clear() -> void:
	totals.clear()
