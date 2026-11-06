extends SceneTree
const Particles = preload("res://src/vfx/particles.gd")
const Fx = preload("res://src/vfx/talent_fx.gd")
var checked:=0
var failures:=0

func check(ok: bool,label: String)->void:
	checked+=1
	if not ok:
		failures+=1
		printerr("SOUL_RELEASE_FAIL: ",label)

func _initialize()->void:
	var p:=Particles.new()
	var fx:=Fx.new()
	check(p.has_method("release_soul"),"pickup has a corpse-gather and rise phase before flight")
	check(fx.has_method("soul_pickup_frames"),"cinematic pickup outlives the short host event locally")
	if p.has_method("release_soul"): test_rise_then_flight(p)
	if fx.has_method("soul_pickup_frames"): test_local_lifetime_follows_live_staff(fx)
	print("SOUL_RELEASE checked=%d failures=%d"%[checked,failures])
	quit(0 if failures==0 else 1)

func test_rise_then_flight(p:RefCounted)->void:
	p.call("release_soul","corpse",Vector2(100,150),Vector2(300,150),18,1.4)
	var head:Dictionary=p._particles[0]
	var starting_spread:=0.0
	for pixel:Dictionary in p._particles: starting_spread+=Vector2(pixel.pos).distance_to(head.pos)
	for i in range(15):p.update(1.0/60)
	check(absf(Vector2(head.pos).x-100)<3,"head stays over corpse during gathering instead of heading straight for hero")
	check(Vector2(head.pos).y-float(head.z)<145,"soul rises visibly before horizontal collection")
	var gathered_spread:=0.0
	for pixel:Dictionary in p._particles:gathered_spread+=Vector2(pixel.pos).distance_to(head.pos)
	check(gathered_spread<starting_spread,"body pixels converge during the rise")
	var count:int=p.count()
	p.call("release_soul","corpse",Vector2.ZERO,Vector2(340,150),18,1.4)
	check(p.count()==count,"moving staff does not restart the gathering phase")
	for i in range(36):p.update(1.0/60)
	check(Vector2(head.pos).x>145,"after rising, the soul accelerates toward the updated staff")
	for i in range(26):p.update(1.0/60)
	check((Vector2(head.pos)-Vector2(0,float(head.z))).distance_to(Vector2(340,150))<18,"the physical soul reaches the staff before its local lifetime ends")
	for i in range(60):p.update(1.0/60)
	check(p.count()==0,"cinematic pickup leaves no immortal particles")
	var blown:=Particles.new()
	blown.release_soul("rise-wind",Vector2(100,150),Vector2(300,150),18,1.4)
	blown.blow(Vector2(50,150),0,120,0,TAU,260)
	blown.update(1.0/60)
	check(Vector2(blown._particles[0].vel).x>30,"external pressure still moves the gathering soul instead of being overwritten")

func test_local_lifetime_follows_live_staff(fx:RefCounted)->void:
	var state:Dictionary={"events":[{"id":77,"owner":1,"kind":"souls","x":100,"y":150,"tx":300,"ty":150,"span":0.7,"life":0.7}]}
	var first:Array=fx.call("soul_pickup_frames",state,10.0)
	check(first.size()==1,"host death starts exactly one local presentation")
	fx.set_necro_actors({1:{"x":400,"y":150}},[])
	var later:Array=fx.call("soul_pickup_frames",{"events":[]},10.8)
	check(later.size()==1 and float(later[0].frame.to.x)==400,"flight continues beyond 0.7s toward the current recipient")
	var replay:Array=fx.call("soul_pickup_frames",state,10.9)
	check(replay.size()==1,"repeated host snapshot cannot duplicate the soul")
	check((fx.call("soul_pickup_frames",{"events":[]},11.6) as Array).is_empty(),"presentation ends after intake")
	check((fx.call("soul_pickup_frames",state,11.7) as Array).is_empty(),"finished pickup cannot replay from a stale snapshot")
	check((fx.call("soul_pickup_frames",{"events":[]},1.0) as Array).is_empty(),"new floor clock clears pending presentation")
