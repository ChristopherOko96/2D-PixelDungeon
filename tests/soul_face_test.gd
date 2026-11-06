extends SceneTree
const Particles = preload("res://src/vfx/particles.gd")
var checked := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("SOUL_FACE_FAIL: ",label)

func _initialize() -> void:
	var p := Particles.new()
	p.soul_stream("face",Vector2(100,100),Vector2(240,100),18,0.7)
	var heads: Array=p._particles.filter(func(q:Dictionary)->bool:return bool(q.get("soul_head",false)))
	var tail: Array=p._particles.filter(func(q:Dictionary)->bool:return q.has("soul_parent"))
	check(heads.size()==1,"one coherent soul head is part of the real particle simulation")
	check(tail.size()>=3 and tail.size()<=8,"a small bounded chain of physical tail pixels accompanies the head")
	if heads.size()==1 and tail.size()>0:
		var head:Dictionary=heads[0]
		var before:Vector2=tail[-1].pos
		for i in range(12): p.update(1.0/60)
		check(Vector2(tail[-1].pos).distance_to(before)>4,"tail follows through simulated velocity rather than a baked picture")
		var normal:Vector2=head.pos
		p.blow(Vector2(100,30),0,200,0,TAU,320)
		p.update(1.0/60)
		check(absf(Vector2(head.pos).y-normal.y)>0.5,"head still responds to the existing pressure solver")
		check(tail.all(func(q:Dictionary)->bool:return Vector2(q.pos).is_finite() and Vector2(q.vel).length()<2000),"tail springs remain bounded after external pressure")
		var count:=p.count()
		p.soul_stream("face",Vector2.ZERO,Vector2(270,90),18,0.7)
		check(p.count()==count,"updating a moving staff does not duplicate the face or tail")
	for i in range(90):p.update(1.0/60)
	check(p.count()==0,"the face and tail leave no permanent particles after collection")
	print("SOUL_FACE checked=%d failures=%d"%[checked,failures])
	quit(0 if failures==0 else 1)
