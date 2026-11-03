extends SceneTree
const Ghost = preload("res://src/rig/curse_spirit_rig.gd")
var checked := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok: failures.append(label); printerr("CURSE_RIG_FAIL: ",label)
func _initialize() -> void:
	Ghost.prepare()
	check(Ghost.rig.parts.size()==8,"approved creature has exactly eight independent layers")
	for part: Dictionary in Ghost.rig.parts:
		check(part.image.get_used_rect().has_area(),str(part.id)+" retains actual source pixels")
		check(str(part.parent).is_empty() or Ghost.rig.by_id.has(str(part.parent)),str(part.id)+" parent exists")
	var a := Ghost.parts(Vector2(150,100),2,0)
	var b := Ghost.parts(Vector2(150,100),2,0.5)
	check(a.size()==8 and a.all(func(p:Dictionary)->bool:return p.texture!=null),"actual skeleton solver emits all cutout textures")
	for id: String in ["jaw","claw_l","claw_r","tail_root","tail_mid","tail_tip"]:
		var first: Dictionary = a.filter(func(p:Dictionary)->bool:return str(p.id)==id)[0]
		var later: Dictionary = b.filter(func(p:Dictionary)->bool:return str(p.id)==id)[0]
		check(first.transform!=later.transform,id+" has genuine continuous articulated motion")
	check(Ghost.parts(Vector2.ZERO,1,0,1,0,Vector2.RIGHT).size()==8,"same anatomy supports directional curse flight")
	print("CURSE_SPIRIT_RIG checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
