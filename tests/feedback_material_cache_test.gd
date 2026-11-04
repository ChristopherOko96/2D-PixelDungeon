extends SceneTree
const Feedback = preload("res://src/vfx/feedback.gd")
func _initialize() -> void:
	var feedback := Feedback.new()
	if not feedback.has_method("_enemy_material"):
		printerr("MATERIAL_CACHE_FAIL: repeated enemy material preparation")
		quit(1)
		return
	var failures := 0
	var checks := 0
	for kind: String in ["bone", "blood", "soul", "frost", "unknown", "player"]:
		var original: Dictionary = Feedback.gore(kind)
		var prepared: Dictionary = feedback._enemy_material(kind)
		checks += 3
		if prepared.material != original: failures += 1
		if prepared.blood != Color(str(original.get("color", "c8323a"))) or prepared.stain != Color(str(original.get("stain", "7a1a22"))): failures += 1
		original.color = "ffffff"
		if not is_same(prepared, feedback._enemy_material(kind)) or prepared.material.get("color") == "ffffff": failures += 1
	print("MATERIAL_CACHE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
