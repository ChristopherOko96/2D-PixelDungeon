extends SceneTree
const Companions = preload("res://src/vfx/companion_rigs.gd")
class PoseSpy extends RefCounted:
	var library = preload("res://src/rig/rig_library.gd").shared()
	var actors := {"p1":{"rig":"necro"}}
	func register_family(_id: String,_pose: Callable,_attack: Callable) -> void: pass
	func is_ready() -> bool: return true
	func observe_one(e: Dictionary) -> void: actors[str(e.actor_key)] = e
	func draw_enemy(_canvas: CanvasItem,_e: Dictionary,_at: Vector2) -> float: return 0.0
	func forget(key: String) -> void: actors.erase(key)
func _initialize() -> void:
	var renderer := PoseSpy.new()
	var painter := Companions.new()
	painter.draw(null,{"id":1,"kind":"bone_warrior","rig":"bone_warrior"},Vector2.ZERO,1,2,0,renderer)
	var preserved := str(renderer.actors.p1.rig) == "necro"
	var independent := renderer.actors.has("pet:1")
	print("COMPANION_NAMESPACE player_preserved=%s separate_pet_pose=%s" % [preserved,independent])
	quit(0 if preserved and independent else 1)
