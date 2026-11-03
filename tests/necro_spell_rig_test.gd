extends SceneTree
const Bank = preload("res://src/rig/necro_spell_rig.gd")
var failures: Array[String] = []
var checked := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok: failures.append(label); printerr("NECRO_RIG_FAIL: ",label)
func _initialize() -> void:
	Bank.prepare()
	var frames := {"necro_curse":Vector2i(18,18),"necro_blood":Vector2i(14,14),"necro_spear":Vector2i(32,10),"necro_blade":Vector2i(10,21)}
	for name: String in frames:
		var rig: Dictionary = Bank.library.rig(name)
		check(rig.parts.size() >= 3,name+" owns independently cut parts")
		for part: Dictionary in rig.parts: check(part.image.get_used_rect().size.x > 0,name+":"+str(part.id)+" nonempty cutout")
		var source: Image = load(str(Bank.data.images[Bank.data.rigs[name].img])).get_image()
		if source.is_compressed(): source.decompress()
		var complete := true
		var size: Vector2i = frames[name]
		for y in range(mini(size.y,source.get_height())):
			for x in range(mini(size.x,source.get_width())):
				var count := 0
				for part: Dictionary in rig.parts:
					if part.image.get_pixel(x,y).a > 0.5: count += 1
				if count != (1 if source.get_pixel(x,y).a > 0.5 else 0): complete = false
		check(complete,name+" source pixels belong exactly once; no holes or duplicates")
		var a := Bank.parts(name,Vector2.ZERO,Vector2.RIGHT,0,2)
		var b := Bank.parts(name,Vector2.ZERO,Vector2.RIGHT,0.4,2)
		check(a[0].transform != b[0].transform or a[-1].transform != b[-1].transform,name+" really articulates")
	for time: float in [0.0,0.31,1.7,4.3]:
		var from := Vector2(25,50)+Vector2(6,-3)*time
		var to := Vector2(210,110)+Vector2(-5,15)*time
		var ends := Bank.endpoints(Bank.beam_parts(from,to,time,2))
		check(ends.size()==2 and ends[0].is_equal_approx(from) and ends[1].is_equal_approx(to),"all sixteen solved joints meet both moving endpoints")
	var talents: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/talents.json"))
	var start := Vector2(120,140)
	var end := Vector2(220,95)
	check(Bank.absorption_point(start,end,0,2).is_equal_approx(start),"uptake particles begin on the real pool surface")
	check(Bank.absorption_point(start,end,1,2).is_equal_approx(end),"uptake particles arrive exactly at the torso socket")
	check(Bank.absorption_point(start,end,0.5,2).y < start.lerp(end,0.5).y,"blood cutouts lift from ground into a curved continuous path")
	for id: String in talents.talents:
		var t: Dictionary = talents.talents[id]
		if str(t.spec) in ["minion","curse"] and str(t.kind) in ["active","ultimate"]: check(not Bank.skill(id).is_empty(),id+" has explicit rig motion")
	print("NECRO_SPELL_RIG checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
