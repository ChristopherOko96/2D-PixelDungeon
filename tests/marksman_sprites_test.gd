extends SceneTree
## Native assets and acknowledged motion boundaries; no synthetic campaign claim.
const Sprites = preload("res://src/vfx/marksman_sprites.gd")
const Motion = preload("res://src/hero/marksman_motion.gd")
const Library = preload("res://src/rig/rig_library.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("MARKSMAN_FAIL ",message)

func _initialize() -> void:
	for name: String in ["aimed_arrow","piercing_arrow","volley_arrow","hail_arrow","spear_arrow","hunters_mark","hit_small","hit_large","chips_a","chips_b","dust_a","dust_b"]:
		var tex := Sprites.texture(name)
		check(tex != null and tex == Sprites.texture(name),name+" uses cached imported texture")
		var image := tex.get_image()
		var soft := false
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var alpha := image.get_pixel(x,y).a
				if alpha > 0 and alpha < 1: soft = true
		check(not soft,name+" has hard alpha")
		check(image.get_size() == (Vector2i(7,21) if name.ends_with("arrow") else Vector2i(16,16)),name+" is native resolution")
	check(Sprites.texture("aimed_arrow").get_image().get_data() != Sprites.texture("piercing_arrow").get_image().get_data(),"precision and pierce have distinct art")
	check(Sprites.texture("aimed_arrow").get_image().get_data() != Sprites.texture("volley_arrow").get_image().get_data(),"volley is a separate sprite")
	var motion := Motion.new()
	var player := {"class_id":"archer","hp":8}
	var event := {"id":10,"owner":1,"kind":"cast","talent":"sniper_1","life":0.4,"span":0.5}
	motion.observe("p1",1,[event],10,true)
	check(is_equal_approx(float(motion.frame("p1",player,10).p),0.1/0.36),"late snapshot starts at host age")
	motion.observe("p1",1,[event],10.1,true)
	check(is_equal_approx(float(motion.frame("p1",player,10.1).p),0.2/0.36),"repeated snapshot never restarts motion")
	check(motion.frame("p1",player,11).is_empty(),"animation expires")
	motion.observe("p2",2,[event],10,true)
	check(motion.frame("p2",player,10).is_empty(),"other owner never receives the pose")
	player.talents = {"charge":{"talent":"sniper_14","power":0.7}}
	check(str(motion.frame("p1",player,11).talent)=="charge","actual charge supersedes recoil")
	player.hp = 0
	check(motion.frame("p1",player,11).is_empty(),"dead hero never charges visually")
	player.hp = 8
	player.talents = {}
	motion.observe("p1",1,[],12,true)
	event.id = 1
	motion.observe("p1",1,[event],12,true)
	check(not motion.frame("p1",player,12).is_empty(),"new run accepts lower event ID")
	motion.reset()
	check(motion.frame("p1",player,12).is_empty(),"explicit room reset clears motion")
	var library := Library.new()
	library.load_data()
	var rig := library.rig("elf")
	for talent: String in Motion.DURATIONS:
		var base := Poses.blank()
		Motion.apply(rig,{"talent":talent,"p":0.5},base)
		check(base.whole != Poses.blank().whole or not base.parts.is_empty(),talent+" changes the actual rig pose")
		for part: String in base.parts:
			check(rig.by_id.has(part),talent+" only animates real rig parts "+part)
	print("MARKSMAN_SPRITES checked=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
