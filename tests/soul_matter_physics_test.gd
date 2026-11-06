extends SceneTree
const Particles = preload("res://src/vfx/particles.gd")
const Pools = preload("res://src/vfx/pool_paint.gd")
const Matter = preload("res://src/vfx/soul_matter.gd")
var checked := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("SOUL_MATTER_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var p := Particles.new()
	var layer := Pools.new(2.0, Callable())
	check(p.has_method("soul_stream"), "soul stream lives in the shared particle solver")
	check(layer.has_method("pressure_front"), "pool surface accepts the actual pressure front")
	if p.has_method("soul_stream"):
		test_stream_is_stateful_and_responds_to_environment()
	if layer.has_method("pressure_front"):
		test_pool_pressure_deforms_then_settles_and_respects_walls()
		test_particles_forward_forces_in_scaled_world_units()
		test_surface_is_independent_of_render_rate()
		test_soul_wind_and_well_act_independently()
	test_soul_events_are_physical_once_and_bounded()
	layer.clear()
	print("SOUL_MATTER checked=%d failures=%d" % [checked, failures])
	quit(0 if failures == 0 else 1)

func test_stream_is_stateful_and_responds_to_environment() -> void:
	var a := Particles.new()
	var b := Particles.new()
	a.call("soul_stream", "pickup", Vector2(100,100), Vector2(230,100), 18, 0.65)
	b.call("soul_stream", "pickup", Vector2(100,100), Vector2(230,100), 18, 0.65)
	check(a.count() > 4 and a.count() == b.count(), "soul consists of multiple real simulated pixels")
	var count := a.count()
	a.call("soul_stream", "pickup", Vector2(100,100), Vector2(230,100), 18, 0.65)
	check(a.count() == count, "rendering the same event does not respawn its pixels")
	b.wind = Vector2(0,150)
	b.blow(Vector2(100,30), 0, 160, 0, TAU, 250)
	for i in range(12):
		a.update(1.0/60)
		b.update(1.0/60)
	var pa: Dictionary = a._particles[0]
	var pb: Dictionary = b._particles[0]
	check(Vector2(pa.pos).distance_to(pb.pos) > 4, "pressure and wind alter actual soul trajectories")
	check(Vector2(pa.pos).x > 100, "soul pixels still steer toward the staff")
	for i in range(24): a.update(1.0/60)
	check((Vector2(a._particles[0].pos)-Vector2(0,float(a._particles[0].z))).distance_to(Vector2(230,100))<12,"unopposed soul pixels actually reach the staff during the event")
	for i in range(120): a.update(1.0/60)
	check(a.count() == 0, "stream pixels expire without floor stains")
	a.clear()
	check(a._soul_targets.is_empty(), "room reset forgets guides and collected stream ids")
	# Real closed wall: a guided stream cannot tunnel through while seeking its staff.
	var c := Particles.new()
	var tiles: Array = []
	for y in range(8):
		for x in range(12):
			if x != 5: tiles.append({"x":x,"y":y,"layer":"floor"})
	c.set_layout({"id":"soul-wall","painted_tiles":tiles}, "soul-wall")
	c.call("soul_stream", "wall", Vector2(125,100), Vector2(240,100), 12, 1.0)
	for i in range(25): c.update(1.0/60)
	check(c._particles.all(func(q: Dictionary) -> bool: return Vector2(q.pos).x < 160), "guided soul pixels collide with the closed wall")
	c.clear()
	c.soul_stream("wall-low-fps",Vector2(125,100),Vector2(240,100),12,1)
	for i in range(6): c.update(1.0/15)
	check(c._particles.all(func(q: Dictionary) -> bool: return Vector2(q.pos).x<160),"guided pickup cannot tunnel through a wall at 15 FPS")

func test_pool_pressure_deforms_then_settles_and_respects_walls() -> void:
	var layer := Pools.new(2, func(p: Vector2) -> bool: return p.x < 260)
	layer.advance(1.0)
	var point := Vector2(150,120)
	layer.call("surface_offset", point)
	layer.call("pressure_front", Vector2(70,120), 0, 130, 0, TAU, 320, 1.0)
	layer.advance(1.1)
	var pushed: Vector2 = layer.call("surface_offset", point)
	check(pushed.x > 1, "pressure displaces stored surface mass outward")
	check(pushed.length() < 20, "surface displacement is bounded")
	for i in range(300): layer.advance(1.1 + (i+1)/60.0)
	check((layer.call("surface_offset", point) as Vector2).length() < pushed.length()*0.2, "spring and damping settle the surface after the wave")
	var walled := Pools.new(2, func(p: Vector2) -> bool: return p.x < 110 or p.x > 130)
	walled.advance(1)
	walled.call("surface_offset", point)
	walled.call("pressure_front", Vector2(70,120), 0, 150, 0, TAU, 320, 1)
	walled.advance(1.1)
	check((walled.call("surface_offset", point) as Vector2).is_zero_approx(), "wall shields pool surface from the pressure source")
	layer.clear()
	walled.clear()

func test_particles_forward_forces_in_scaled_world_units() -> void:
	var p := Particles.new()
	var layer := Pools.new(3, Callable())
	layer.advance(1)
	layer.call("surface_offset", Vector2(225,180))
	p.set_liquids([[layer,1.5,true]])
	p.blow(Vector2(70,120),0,130,0,TAU,320)
	layer.advance(1.1)
	check((layer.call("surface_offset",Vector2(225,180)) as Vector2).x > 1, "actual particle blow reaches a 3px story surface with unit conversion")
	layer.clear()
	p.set_liquids([])

func test_surface_is_independent_of_render_rate() -> void:
	var offsets: Array[Vector2] = []
	for hz: int in [30,60,144]:
		var layer := Pools.new(2,Callable())
		layer.advance(1)
		layer.call("surface_offset",Vector2(150,120))
		layer.call("pressure_front",Vector2(70,120),0,130,0,TAU,320)
		for i in range(hz):
			layer.advance(1+float(i+1)/hz)
			layer.call("surface_offset",Vector2(150,120))
		offsets.append(layer.call("surface_offset",Vector2(150,120)))
		layer.clear()
	check(offsets[0].distance_to(offsets[1])<0.001 and offsets[1].distance_to(offsets[2])<0.001,"surface simulation agrees at 30,60 and 144 render frames/s")

func test_soul_events_are_physical_once_and_bounded() -> void:
	var p := Particles.new()
	var m := Matter.new()
	var event := {"id":12,"kind":"soul_impact","talent":"soul_1","x":200,"y":200,"r":35}
	m.event(event,1,p,1,{})
	var count := p.count()
	m.event(event,1.01,p,1,{})
	check(count>4 and p.count()==count,"one hit emits simulated matter once across repeated render passes")
	var layer := Pools.new(2,Callable())
	layer.add_ring(4,"soul",Vector2(200,200),100,65,0,5,"talent")
	layer.advance(1)
	var before := layer.pool_field.cells_of("soul").keys()
	var zone := {"id":4,"look":"souls_ring","x":200,"y":200,"r":100,"inner_r":65}
	for i in range(20): m.field(zone,1+i*0.08,p,1,layer,{})
	check(p.count()>count,"ring emits live pixels from its hollow material footprint")
	layer.surface_offset(Vector2(280,200))
	layer.pressure_front(Vector2(130,200),0,200,0,TAU,320)
	layer.advance(1.1)
	check(before==layer.pool_field.cells_of("soul").keys(),"surface response does not change authoritative damage cells")
	for i in range(50):
		m.event({"id":i+20,"kind":"soul_impact","x":200,"y":200,"r":35},3,p,1,{})
	check(p.count()<=int(p._data.max_particles),"multiple simultaneous soul effects honor the shared particle cap")
	var shot_particles := Particles.new()
	m.projectile({"id":90,"owner":1,"x":200,"y":100,"vx":80,"vy":0},4,shot_particles,1,Vector2(0,30),{})
	check(shot_particles._particles.all(func(q: Dictionary) -> bool: return absf(Vector2(q.pos).y-float(q.z)-100)<6),"projectile pixels retain the already-lifted shot position")
	layer.clear()

func test_soul_wind_and_well_act_independently() -> void:
	var still := Particles.new()
	var windy := Particles.new()
	var sucked := Particles.new()
	for p: RefCounted in [still,windy,sucked]:
		p.soul_stream("environment",Vector2(100,100),Vector2(230,100),12,1)
	windy.wind=Vector2(0,180)
	sucked.well("foreign",Vector2(120,40),130,300,80,4,1,0,[],false)
	for i in range(15):
		still.update(1.0/60)
		windy.update(1.0/60)
		sucked.update(1.0/60)
	var base: Vector2=still._particles[0].pos
	check(base.distance_to(windy._particles[0].pos)>0.5,"world wind acts on soul pixels without any shockwave")
	check(sucked.count()<still.count() or base.distance_to(sucked._particles[0].pos)>1,"another class's well deflects or consumes soul pixels")
