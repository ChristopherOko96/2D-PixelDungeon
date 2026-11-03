extends SceneTree
## Real hierarchy endpoint/continuity checks, not a replacement beam simulation.
const BeamRig = preload("res://src/rig/soul_beam_rig.gd")
var failed := 0
var checked := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failed += 1
		printerr("GUARDIAN_BEAM_RIG_FAIL: ",label)
func _initialize() -> void:
	BeamRig.prepare()
	check(BeamRig.rig.parts.size()==48,"two real 24-joint textured parent chains")
	var from := Vector2(300,170)
	var to := Vector2(500,250)
	var prior: Array = []
	var texture: Texture2D = BeamRig.rig.parts[0].texture
	for n in range(60):
		var end := to+Vector2(0,n*0.4)
		var parts: Array = BeamRig.parts(from,end,n/60.0,2.0)
		for strand in range(2):
			var first: Dictionary = parts[strand*24]
			var last: Dictionary = parts[strand*24+23]
			var a: Rect2 = first.bounds
			var b: Rect2 = last.bounds
			check((Transform2D(first.transform)*Vector2(a.position.x,a.get_center().y)).distance_to(from)<0.001,"source pinned to animated palm")
			check((Transform2D(last.transform)*Vector2(b.end.x,b.get_center().y)).distance_to(end)<0.001,"tip pinned to moving enemy socket")
		if not prior.is_empty():
			var part: Dictionary = parts[12]
			var center: Vector2 = Rect2(part.bounds).get_center()
			check((Transform2D(part.transform)*center).distance_to(Transform2D(prior[12].transform)*center)<1.0,"continuous inner joints between 60 Hz poses")
		prior = parts
	BeamRig.prepare()
	check(BeamRig.rig.parts[0].texture==texture,"approved source texture cached once")
	print("GUARDIAN_BEAM_RIG checked=%d failures=%d" % [checked,failed])
	quit(1 if failed else 0)
