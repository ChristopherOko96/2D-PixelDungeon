extends SceneTree
class Host extends Node:
	var theme := {"hero_scale": 3.0}
	var sound: RefCounted
	var monsters: RefCounted
	var mobs: Array = []
class Counted extends "res://src/hero/story_feel.gd":
	var calls := 0
	func _enemy(m: Dictionary) -> Dictionary:
		calls += 1
		return super._enemy(m)
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("STORY_FEEDBACK_FAIL: ", label)
func _initialize() -> void:
	var host := Host.new()
	var feel := Counted.new(host, {})
	check(feel.has_method("_feedback_enemies"), "one preparation per enemy, including corpses")
	if failures:
		host.free()
		quit(1)
		return
	for i in range(128):
		var mob := {"p": Vector2(i * 3, 30), "hp": 0.0, "kind": "skeleton", "spawn": 0.0}
		host.mobs.append(mob)
		feel.on_kill(mob)
		mob.feel_e.dying_p = 0.5
	var live := {"p": Vector2(0, 30), "hp": 10.0, "kind": "skeleton", "spawn": 0.0}
	host.mobs.append(live)
	feel.calls = 0
	var views: Array = feel._feedback_enemies()
	check(feel.calls == 1, "128 corpses skip live preparation; living enemy still refreshed")
	check(views.size() == 129, "each corpse and living enemy occurs exactly once")
	check(views[0].get("dying_p", -1.0) == 0.5 and host.mobs[0].feel_e.get("dying_p", -1.0) == 0.5, "collecting snapshot preserves death progress for rig renderer")
	check(not views.back().has("dying_p"), "living enemy stays alive in view")
	var old_x: float = views.back().x
	live.p += Vector2(9, 0)
	live.feel_hits = 3
	views = feel._feedback_enemies()
	check(views.back().hits == 3 and views.back().x > old_x, "living movement and hits update immediately")
	host.mobs.clear()
	check(feel._feedback_enemies().size() == 128, "removed corpses remain visible while falling")
	feel.reset()
	check(feel._feedback_enemies().is_empty(), "floor reset releases all fallen views")
	host.free()
	print("STORY_FEEDBACK checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
