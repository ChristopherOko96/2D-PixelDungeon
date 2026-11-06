extends SceneTree
## Actual feedback counter boundaries plus source-textured joint motion and bounded lifetime.
const Feedback = preload("res://src/vfx/feedback.gd")
const Rig = preload("res://src/rig/hit_burst_rig.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("HIT_RIG_FAIL ",message)

func snapshot(enemy: Dictionary, room := "a") -> Dictionary:
	return {"room_layout":{"id":room},"enemies":[enemy],"players":{}}

func _initialize() -> void:
	var feedback := Feedback.new()
	var enemy := {"id":1,"x":300.0,"y":200.0,"hp":10,"max_hp":10,"hits":4,"attacks":0,"blocks":0,"dying_p":-1.0,"dx":1.0,"dy":0.0,"kind":"skeleton_archer"}
	feedback.observe(snapshot(enemy),1)
	check(feedback.hit_rigs.live.is_empty(),"joining mid-fight never replays hits")
	enemy.hits = 5
	feedback.observe(snapshot(enemy),1)
	check(feedback.hit_rigs.live.size()==1,"confirmed direct hit starts one articulated burst")
	feedback.observe(snapshot(enemy),1)
	check(feedback.hit_rigs.live.size()==1,"repeated snapshot never duplicates burst")
	enemy.blocks = 1
	feedback.observe(snapshot(enemy),1)
	check(feedback.hit_rigs.live.size()==1,"block alone never claims a damaging impact")
	var event: Dictionary = feedback.hit_rigs.live[0].duplicate()
	var first := Rig.parts(event)
	event.age = 0.1
	var later := Rig.parts(event)
	check(first.size()==9,"source is split into core, four rays and four chips")
	check(later.size()==8,"white core disappears before the rays and chips")
	for part: Dictionary in later:
		var before: Dictionary = first.filter(func(p: Dictionary)->bool:return p.id==part.id)[0]
		check(before.texture==part.texture,"native part texture is cached: "+str(part.id))
		check(before.transform!=part.transform,"joint moves independently: "+str(part.id))
		check(str(Rig.rig.by_id[part.id].parent)=="core","real parent hierarchy: "+str(part.id))
	check(Vector2(event.at).x<Vector2(event.ground).x,"contact reads on the incoming side")
	feedback.hitstop = 0.1
	feedback.update(0.01)
	check(float(feedback.hit_rigs.live[0].age)==0,"existing hitstop freezes impact with the world")
	feedback.hitstop = 0
	feedback.update(0.4)
	check(feedback.hit_rigs.live.is_empty(),"burst fully expires after configured life")
	enemy.hp = 0
	enemy.hits = 6
	enemy.dying_p = 0
	feedback.observe(snapshot(enemy),1)
	check(feedback.hit_rigs.live.size()==1 and bool(feedback.hit_rigs.live[0].strong),"lethal direct hit gets one stronger burst")
	feedback.observe(snapshot(enemy),1)
	check(feedback.hit_rigs.live.size()==1,"death snapshot cannot replay killing impact")
	feedback.observe(snapshot(enemy,"b"),1)
	check(feedback.hit_rigs.live.is_empty(),"room change clears old bursts")
	for n in range(int(Rig.config.cap)+10): feedback.hit_rigs.spawn(Vector2.ZERO,Vector2.RIGHT,n)
	check(feedback.hit_rigs.live.size()==int(Rig.config.cap),"crowds cannot exceed simultaneous burst budget")
	feedback.hit_rigs.clear()
	check(feedback.hit_rigs.live.is_empty(),"explicit reset clears every retained part")
	# Source ownership: not one opaque source pixel is duplicated by another joint.
	var source: Image = (load(str(Rig.config.source)) as Texture2D).get_image()
	var pixels := 0
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x,y).a>0.5: pixels += 1
	var owned := 0
	for part: Dictionary in Rig.rig.parts:
		var image: Image = part.texture.get_image()
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y).a>0.5: owned += 1
	check(owned==pixels,"all native source pixels belong to exactly one rig part")
	print("HIT_BURST_RIG checked=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
