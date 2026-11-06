extends SceneTree
const Adapter = preload("res://src/hell/hell_talents.gd")
class Counted extends "res://src/combat/talent_combat.gd":
	var calls := 0
	func snapshot() -> Dictionary:
		calls += 1
		return {"events": events.duplicate(true)}
class Host extends RefCounted:
	var players: Dictionary = {}
	var enemies: Array = []
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("RENDER_CACHE_FAIL: ", label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var adapter := Adapter.new()
	var counted := Counted.new()
	adapter.tc = counted
	check(adapter.has_method("_render_state"), "render layers share a snapshot")
	if failures:
		quit(1)
		return
	counted.events = [{"id": 1, "x": 20.0}]
	var first: Dictionary = adapter._render_state(1.0)
	check(is_same(first, adapter._render_state(1.0)) and counted.calls == 1, "same frame builds once")
	counted.events[0].x = 99.0
	check(first.events[0].x == 20.0, "snapshot detached from simulation")
	adapter._invalidate_render_state()
	check(adapter._render_state(1.0).events[0].x == 99.0 and counted.calls == 2, "same-frame mutation invalidates")
	adapter._render_state(2.0)
	check(counted.calls == 3, "changed clock rebuilds")
	var frame := Engine.get_process_frames()
	while Engine.get_process_frames() == frame:
		await process_frame
	adapter._render_state(2.0)
	check(counted.calls == 4, "paused clock still refreshes next rendered frame")
	# Actual TalentCombat serialization with a deterministic event-heavy fixture.
	adapter.tc = preload("res://src/combat/talent_combat.gd").new()
	adapter.tc.game = Host.new()
	for i in range(256):
		adapter.tc.events.append({"id": i, "kind": "soul", "x": float(i), "y": 20.0, "path": [[1, 2], [3, 4]]})
	var before := 0
	var after := 0
	var equal := true
	for i in range(40):
		for cached: bool in ([false, true] if i % 2 == 0 else [true, false]):
			adapter._invalidate_render_state()
			var start := Time.get_ticks_usec()
			var result: Dictionary
			for layer in range(3):
				result = adapter._render_state(3.0) if cached else adapter.tc.snapshot()
			var elapsed := Time.get_ticks_usec() - start
			if cached: after += elapsed
			else: before += elapsed
			equal = equal and result.events == adapter.tc.events
	check(equal, "actual serialized event payload unchanged")
	check(after < before * 0.8, "shared preparation meets 20 percent reduction budget")
	print("RENDER_CACHE_CPU before_us=", before / 40.0, " after_us=", after / 40.0)
	print("RENDER_CACHE checks=8 failures=", failures)
	quit(1 if failures else 0)
