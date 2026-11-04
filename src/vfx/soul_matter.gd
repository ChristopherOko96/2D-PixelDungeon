extends RefCounted
## Soul VFX emit real shared-solver pixels. No frame-based sprite trajectories.
const Pal = preload("res://src/vfx/talent_palette.gd")
var emitted: Dictionary = {}
var ticks: Dictionary = {}
var scope := ""
var last_clock := -1.0

func _prepare(particles: RefCounted, clock: float) -> void:
	if scope != str(particles.layout_key) or clock < last_clock:
		emitted.clear()
		ticks.clear()
		scope = str(particles.layout_key)
	last_clock = clock
	if emitted.size() > 256:
		for key: String in emitted.keys():
			if clock-float(emitted[key]) > 3: emitted.erase(key)
	if ticks.size() > 256: ticks.clear()

func _tick(key: String, clock: float, every: float) -> bool:
	var tick := floori(clock/maxf(every,0.02))
	if int(ticks.get(key,-1)) == tick: return false
	ticks[key] = tick
	return true

func _pixel(particles: RefCounted, at: Vector2, velocity: Vector2, life: float, i: int, lift: float) -> void:
	var colours := Pal.ramp("soul")
	var mote: Dictionary = particles.emit(at,velocity,colours[2+i%3],life,"mote",2.0,2.0,0,0.7)
	mote.z_to = lift
	mote.soul_matter = true

## Stateful motes are born on the actual ring, capsule or floor material.
func field(zone: Dictionary, clock: float, particles: RefCounted, scale: float, pools: RefCounted, cfg: Dictionary) -> void:
	_prepare(particles,clock)
	var key := "field:%d"%int(zone.id)
	var every := float(cfg.get("field_every",0.08))
	if not _tick(key,clock,every): return
	var at := Vector2(zone.x,zone.y)
	var radius := float(zone.r)
	var look := str(zone.get("look",""))
	var batch := floori(clock/every)
	for i in range(particles.room(int(cfg.get("field_count",4)))):
		var n := batch*7+i+int(zone.id)*13
		var phase := fposmod(n*0.61803399,1.0)
		var angle := n*2.39996
		var inner := float(zone.get("inner_r",0))
		var point := at+Vector2.from_angle(angle)*sqrt(lerpf(inner*inner,radius*radius,phase))
		var path: Array = zone.get("path",[])
		if look == "souls_trail" and path.size()>=2:
			var a := Vector2(path[0][0],path[0][1])
			var b := Vector2(path[-1][0],path[-1][1])
			point = a.lerp(b,phase)+(b-a).normalized().orthogonal()*sin(angle)*float(zone.get("w",12))
		if pools != null and not pools.covers(point,"soul"): continue
		if pools != null: point += pools.surface_offset(point)
		var velocity := Vector2.from_angle(angle)*float(cfg.get("field_drift",14))
		_pixel(particles,point*scale,velocity,float(cfg.get("field_life",1.4)),n,float(cfg.get("field_lift",28)))

## A pulse, impact or bind releases independent pixels once per host event.
func event(event: Dictionary, clock: float, particles: RefCounted, scale: float, cfg: Dictionary) -> void:
	_prepare(particles,clock)
	var key := "event:%d"%int(event.get("id",0))
	if emitted.has(key): return
	emitted[key] = clock
	var kind := str(event.get("kind",""))
	var at := Vector2(event.x,event.y)*scale
	var count := int(cfg.get("burst_count",32))
	var speed := maxf(40,float(event.get("r",24))*scale/float(cfg.get("burst_travel",0.55)))
	var bind := kind == "soul_grasp"
	if bind: count = int(cfg.get("bind_count",18))
	for i in range(particles.room(count)):
		var angle := i*2.39996+float(int(event.get("id",0))%31)
		var out := Vector2.from_angle(angle)
		var point: Vector2 = at+out*(float(event.get("r",12))*scale*0.6 if bind else 3.0)
		var velocity := out*speed*(0.4+0.6*float(i%7)/6)
		if bind: velocity = out.orthogonal()*65-out*25
		_pixel(particles,point,velocity,float(cfg.get("burst_life",0.9)),i,float(cfg.get("burst_lift",18)))

## Real particle wakes around an authoritative shot; its small pixel core stays readable.
func projectile(bullet: Dictionary, clock: float, particles: RefCounted, scale: float, _lift: Vector2, cfg: Dictionary) -> void:
	_prepare(particles,clock)
	var key := "shot:%s:%s"%[str(bullet.get("owner",0)),str(bullet.get("id",0))]
	if not _tick(key,clock,float(cfg.get("shot_every",0.04))): return
	# The caller's bullet is already lifted into the spell's drawing plane.
	var at := Vector2(bullet.x,bullet.y)
	var velocity := Vector2(float(bullet.get("vx",0)),float(bullet.get("vy",0)))*scale
	for i in range(particles.room(int(cfg.get("shot_count",3)))):
		var spread := Vector2.from_angle(clock*31+i*2.39996)*4
		_pixel(particles,at*scale+spread,velocity*0.15+spread*6,float(cfg.get("shot_life",0.55)),i,6)

## Charging sheds physically simulated motes; no orbiting whole-spirit pictures.
func charge(charge: Dictionary, clock: float, particles: RefCounted, scale: float, cfg: Dictionary) -> void:
	_prepare(particles,clock)
	var key := "charge:%d"%int(charge.get("owner",0))
	if not _tick(key,clock,0.08): return
	var at := Vector2(charge.x,charge.y)*scale-Vector2(0,float(cfg.get("charge_hand_lift",26)))
	for i in range(particles.room(int(cfg.get("charge_count",3)))):
		var out := Vector2.from_angle(clock*15+i*2.39996)
		_pixel(particles,at+out*20,-out*50,0.4,i,24)

## A summoned guardian keeps its actor rig; its surrounding dust is real matter.
func aura(actor: Dictionary, clock: float, particles: RefCounted, scale: float, cfg: Dictionary) -> void:
	_prepare(particles,clock)
	if not _tick("guardian:%d"%int(actor.id),clock,0.1): return
	var at := Vector2(actor.x,actor.y)*scale
	for i in range(particles.room(int(cfg.get("guardian_count",2)))):
		var out := Vector2.from_angle(clock*7+i*2.39996)
		_pixel(particles,at+out*float(cfg.get("guardian_radius",20)),out*8,1.1,i,float(cfg.get("guardian_lift",72)))
