extends RefCounted
## Bounded local ultimate matter. Snapshot age controls the flight; render rate cannot multiply emission.
const Art=preload("res://src/vfx/marksman_art.gd")
var shots: Dictionary={}
var charges: Dictionary={}
var _scope:=""
var _clock:=-1.0
var socket:=Callable()
var socket_key:=""

## Interpolate the host event age without restarting when a repeated snapshot arrives.
func age_for(event: Dictionary, clock: float) -> float:
	Art.prepare()
	var id:=int(event.id)
	var host_age:=maxf(0,float(event.get("span",0.93))-float(event.get("life",0)))
	if not shots.has(id): shots[id]={"born":clock-host_age,"last":clock,"carry":0.0,"total":0,"released":false,"last_age":host_age}
	var track: Dictionary=shots[id]
	track.born=minf(float(track.born),clock-host_age)
	return clampf(minf(clock-float(track.born),host_age+float(Art.ultimate.max_extrapolate_s)),0,float(event.get("span",0.93)))

## Forget clocks, emission debt and event IDs at a room or run boundary.
func reset() -> void:
	shots.clear()
	charges.clear()
	_clock=-1

## Emit through the existing physical particle world, with no per-draw burst or hidden gameplay.
func update(state: Dictionary, clock: float, particles: RefCounted, to_particles: float, art: float) -> void:
	if particles==null or not particles.has_method("emit"): return
	Art.prepare()
	var cfg: Dictionary=Art.ultimate
	var scope:=str(particles.get("layout_key"))
	if scope!=_scope or clock<_clock: reset()
	_scope=scope
	_clock=clock
	var soft_full:=particles.has_method("count") and int(particles.count())>=int(cfg.particle_soft_cap)
	var charge_ids: Dictionary={}
	for charge: Dictionary in state.get("charges",[]):
		if str(charge.get("talent",""))!="sniper_14": continue
		var id:=int(charge.owner)
		charge_ids[id]=true
		var power:=clampf(float(charge.power),0,1)
		var age:=float(charge.get("age",power*1.5))
		var track: Dictionary=charges.get(id,{"last":clock,"carry":0.0,"age":age,"serial":0})
		if age<float(track.age): track={"last":clock,"carry":0.0,"age":age,"serial":0}
		var dt:=clampf(clock-float(track.last),0,0.1)
		track.carry=float(track.carry)+dt*float(cfg.charge_rate)*(0.3+0.7*power)
		var n:=mini(int(track.carry),int(cfg.charge_cap_per_frame))
		track.carry=float(track.carry)-floorf(float(track.carry))
		track.last=clock
		track.age=age
		charges[id]=track
		if soft_full: continue
		var aim:=Vector2(charge.ax,charge.ay).normalized()
		var hand:=Vector2(charge.x,charge.y)-Vector2(0,12*art)+aim*art*(7+power*5)
		if socket.is_valid(): hand=socket.call(socket_key if not socket_key.is_empty() else "p%d"%id,hand,clock)
		for index in range(n):
			var seed:=int(track.serial)
			track.serial=seed+1
			var offset:=Vector2.from_angle(seed*2.39996+clock)*float(cfg.charge_radius)*art
			particles.emit((hand+offset)*to_particles,-offset.normalized()*float(cfg.charge_speed)*art*to_particles,Color("f6cf78"),float(cfg.charge_particle_life_s),"spark",art*to_particles,0,0,1.0)
	for id: Variant in charges.keys():
		if not charge_ids.has(id): charges.erase(id)
	var shot_ids: Dictionary={}
	for event: Dictionary in state.get("events",[]):
		if str(event.get("kind",""))!="spear" or str(event.get("talent",""))!="sniper_14": continue
		var id:=int(event.id)
		shot_ids[id]=true
		var age:=age_for(event,clock)
		var track: Dictionary=shots[id]
		var from:=Vector2(event.x,event.y)
		var to:=Vector2(event.tx,event.ty)
		var aim:=(to-from).normalized()
		var flight:=float(event.get("flight",0.3))*float(event.get("span",0.93))
		if not bool(track.released):
			track.released=true
			if not soft_full and age<float(cfg.release_life_s): particles.sparks(from*to_particles,-aim,int(cfg.release_sparks),[Color("f6cf78"),Color("fff1ca")])
		var dt:=clampf(clock-float(track.last),0,0.1)
		track.last=clock
		if age>=flight or soft_full: continue
		track.carry=float(track.carry)+dt*float(cfg.trail_rate)
		var n:=mini(mini(int(track.carry),int(cfg.trail_cap_per_frame)),int(cfg.trail_cap)-int(track.total))
		track.carry=float(track.carry)-floorf(float(track.carry))
		for index in range(maxi(0,n)):
			var along:=lerpf(float(track.last_age),age,float(index+1)/float(n+1))
			var at:=from.lerp(to,clampf(along/maxf(0.001,flight),0,1))
			var sign_value:=-1.0 if int(track.total)%2 else 1.0
			var velocity:=(-aim*float(cfg.trail_speed)+aim.orthogonal()*sign_value*float(cfg.trail_speed)*0.6)*art*to_particles
			particles.emit(at*to_particles,velocity,Color("fff1ca") if int(track.total)%3==0 else Color("f6cf78"),float(cfg.trail_life_s),"spark",art*to_particles,0,0,3.0)
			track.total=int(track.total)+1
		track.last_age=age
	for id: Variant in shots.keys():
		if not shot_ids.has(id): shots.erase(id)
