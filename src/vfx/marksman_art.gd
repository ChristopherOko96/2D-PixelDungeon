extends RefCounted
## Approved golden arrow cutouts, cached once, posed through the actual joint solver.
const Library=preload("res://src/rig/rig_library.gd")
const Renderer=preload("res://src/rig/rig_renderer.gd")
const Poses=preload("res://src/rig/rig_poses.gd")
const Sprites=preload("res://src/vfx/marksman_sprites.gd")
const Impact=preload("res://src/rig/hit_burst_rig.gd")
static var rig: Dictionary={}
static var spear_rig: Dictionary={}
static var wake_rig: Dictionary={}
static var ultimate: Dictionary={}
static var solver: RefCounted

## Cache the two native rigs and the presentation settings before posing.
static func prepare() -> void:
	if not rig.is_empty(): return
	var library:=Library.new()
	library.load_data("","","res://assets/data/marksman_rig.json","")
	rig=library.rig("marksman_arrow")
	spear_rig=library.rig("marksman_spear")
	solver=Renderer.new(library)
	ultimate=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/marksman_ultimate_fx.json"))
	wake_rig=spear_rig.duplicate()
	wake_rig.parts=[]
	wake_rig.by_id={}
	wake_rig.ground=Vector2.ZERO
	for side in range(2):
		for n in range(int(ultimate.wake_links)):
			var part: Dictionary=spear_rig.by_id["feather_l" if side==0 else "feather_r"].duplicate()
			part.id="wake_%d_%d"%[side,n]
			part.parent="" if n==0 else "wake_%d_%d"%[side,n-1]
			wake_rig.parts.append(part)
			wake_rig.by_id[part.id]=part

## Native head, shaft and two separate fletching masks.
static func parts(at: Vector2, aim: Vector2, clock: float, art: float, alpha:=1.0) -> Array:
	prepare()
	var pose:=Poses.blank()
	pose.whole.rot=aim.angle()+PI*0.5
	Poses.P(pose,"feather_l").rot=sin(clock*9)*0.10
	Poses.P(pose,"feather_r").rot=-sin(clock*9+0.4)*0.10
	var world: Dictionary=solver.solve_pose(rig,pose,at,1,art)
	var out: Array=[]
	for part: Dictionary in rig.parts:
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":Color(1,1,1,alpha)})
	return out

## Nine actual source masks: hinged head, segmented shaft, nock and separate feathers.
static func spear_parts(at: Vector2, aim: Vector2, clock: float, art: float, power := 1.0, alpha := 1.0) -> Array:
	prepare()
	var pose:=Poses.blank()
	pose.whole.rot=aim.angle()+PI*0.5
	var beat:=clock*TAU*float(ultimate.flutter_hz)
	Poses.P(pose,"blade_l").rot=-float(ultimate.fin_open)*power
	Poses.P(pose,"blade_r").rot=float(ultimate.fin_open)*power
	Poses.P(pose,"shaft_front").rot=sin(beat)*float(ultimate.shaft_bend)*power
	Poses.P(pose,"shaft_back").rot=sin(beat-0.8)*float(ultimate.shaft_bend)*power
	Poses.P(pose,"feather_l").rot=(-float(ultimate.feather_open)+sin(beat-1.6)*0.12)*power
	Poses.P(pose,"feather_r").rot=(float(ultimate.feather_open)-sin(beat-1.4)*0.12)*power
	Poses.P(pose,"nock").rot=sin(beat-2.0)*0.06*power
	var world: Dictionary=solver.solve_pose(spear_rig,pose,at,1,art)
	var out: Array=[]
	for part: Dictionary in spear_rig.parts:
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":Color(1,1,1,alpha)})
	return out

## Two genuine parent chains stream behind the spear, never ahead of its flight origin.
static func wake_parts(from: Vector2, tip: Vector2, aim: Vector2, clock: float, art: float) -> Array:
	prepare()
	var pose:=Poses.blank()
	var wanted: Dictionary={}
	var visible: Dictionary={}
	for part: Dictionary in wake_rig.parts:
		var tags:=str(part.id).split("_")
		var side:=-1.0 if int(tags[1])==0 else 1.0
		var n:=int(tags[2])
		var distance:=float(n+1)*float(ultimate.wake_spacing)*art
		var point:=tip-aim*distance
		visible[part.id]=(point-from).dot(aim)>=0
		point+=aim.orthogonal()*side*(float(ultimate.wake_width)+sin(clock*15-n*0.9)*float(ultimate.wake_wave))*art
		var angle:=aim.angle()+PI*0.5+side*sin(clock*12-n)*0.22
		var factor:=1.0-float(n)/float(ultimate.wake_links+1)
		var desired:=Transform2D(angle,Vector2.ONE*factor,0,(point-tip)/art)*Transform2D(0,-Vector2(part.center))
		Poses.P(pose,str(part.id)).local_transform=desired if str(part.parent).is_empty() else Transform2D(wanted[part.parent]).affine_inverse()*desired
		wanted[part.id]=desired
	var world: Dictionary=solver.solve_pose(wake_rig,pose,tip,1,art)
	var out: Array=[]
	for part: Dictionary in wake_rig.parts:
		if not bool(visible[part.id]): continue
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":Color(1.2,1.05,0.75,0.75)})
	return out

## Paid charge grows at the actual hero's hand, with a visible fill indicator.
static func charge(canvas: CanvasItem, state: Dictionary, clock: float, art: float, sprites: RefCounted, socket := Vector2.INF) -> void:
	var ground:=Vector2(state.x,state.y)
	var aim:=Vector2(state.ax,state.ay).normalized()
	var power:=clampf(float(state.power),0,1)
	var hand:=ground-Vector2(0,12*art)+aim*art*(7+power*5)
	if socket.is_finite(): hand=socket
	var charge_scale:=art*(0.8+power*0.7)*float(ultimate.get("charge_art_scale",1.0))
	sprites.draw_external_rig(canvas,spear_parts(hand,aim,clock,charge_scale,power),ground)
	for n in range(int(ultimate.charge_orbits)):
		var p:=fposmod(clock+n*0.618,1)
		var pos:=hand+Vector2.from_angle(n*2.39996+clock)*art*float(ultimate.charge_radius)*(1-p)
		var part:=Sprites.part("hit_small",pos,clock+n,art*0.4,sin(p*PI)*power)
		sprites.draw_external_rig(canvas,[part],ground)
	canvas.draw_rect(Rect2(ground+Vector2(-12,8)*art,Vector2(24,2)*art),Color("33251c"))
	canvas.draw_rect(Rect2(ground+Vector2(-12,8)*art,Vector2(24*power,2)*art),Color("f6cf78"))

## The massive arrow reaches only the host-clamped endpoint; tail stays behind.
static func spear(canvas: CanvasItem, event: Dictionary, p: float, clock: float, art: float, sprites: RefCounted, config: Dictionary = {}) -> void:
	prepare()
	var from:=Vector2(event.x,event.y)
	var to:=Vector2(event.tx,event.ty)
	var aim:=(to-from).normalized()
	var flight:=float(event.get("flight",config.get("flight_share",0.3)))
	var width:=arrow_scale(event,art,config)
	var fade:=1-smoothstep(flight,1,p)
	var age:=p*float(event.get("span",0.93))
	if age<float(ultimate.release_life_s):
		sprites.draw_external_rig(canvas,Impact.parts({"at":from,"aim":aim,"age":age,"pixel":art,"seed":int(event.get("id",0)),"strong":true}),from)
	if bool(event.get("wall",false)) and p>=flight:
		var shock:=Impact.parts({"at":to,"aim":Vector2(event.get("nx",-aim.x),event.get("ny",-aim.y)),"age":(p-flight)*float(event.get("span",0.93)),"pixel":art*2,"seed":int(event.get("id",0)),"strong":true})
		_wall_side(shock,to,Vector2(event.get("nx",-aim.x),event.get("ny",-aim.y)),false)
		sprites.draw_external_rig(canvas,shock,to)
		sprites.draw_external_rig(canvas,fragments(event,(p-flight)*float(event.get("span",0.93)),clock,art,config),to)
		return
	var tip:=from.lerp(to,clampf(p/maxf(0.001,flight),0,1))
	var half_length:=float(spear_rig.ground.y)
	var tail:=tip-aim*half_length*2*width
	var wake:=wake_parts(from,tail,aim,clock,art)
	for part: Dictionary in wake: part.tint.a*=fade
	if bool(event.get("wall",false)): _wall_side(wake,to,Vector2(event.get("nx",-aim.x),event.get("ny",-aim.y)),true)
	sprites.draw_external_rig(canvas,wake,tip)
	var arrow:=spear_parts(tip-aim*half_length*width,aim,clock,width,1,fade)
	if bool(event.get("wall",false)): _wall_side(arrow,to,Vector2(event.get("nx",-aim.x),event.get("ny",-aim.y)),true)
	sprites.draw_external_rig(canvas,arrow,tip)

## Width uses the host's lane radius, so a wide attack also has wide native art.
static func arrow_scale(event: Dictionary, art: float, config: Dictionary = {}) -> float:
	prepare()
	return maxf(art*float(config.get("min_scale",1.4)),float(event.get("r",0))*2*float(config.get("width_share",0.82))/float(spear_rig.width))

## The original head, shaft and feathers separate at wall contact, then fall.
## Cached textures stay intact; only their joint transforms and alpha change.
static func fragments(event: Dictionary, age: float, clock: float, art: float, config: Dictionary = {}) -> Array:
	var life:=float(event.get("span",0.93))*(1-float(event.get("flight",0.3)))
	if age<0 or age>=life: return []
	var at:=Vector2(event.tx,event.ty)
	var aim:=(at-Vector2(event.x,event.y)).normalized()
	var scale:=arrow_scale(event,art,config)
	var out:=spear_parts(at-aim*float(spear_rig.ground.y)*scale,aim,clock-age,scale,1,1-smoothstep(life*0.35,life,age))
	for n in range(out.size()):
		var part: Dictionary=out[n]
		var side:=-1.0 if n%2==0 else 1.0
		var velocity:=(-aim*(0.6+n*0.16)+aim.orthogonal()*side*(0.5+n*0.15))*float(config.get("fragment_speed",26))*art
		var drift:=velocity*age+Vector2(0,(-float(config.get("fragment_lift",18))*age+float(config.get("fragment_gravity",46))*age*age)*art)
		drift+=(-aim*(0.5+n*0.3)+aim.orthogonal()*side*(0.8+n*0.1))*float(config.get("fragment_kick",9))*art*(1-exp(-age*float(config.get("fragment_kick_rate",32))))
		var center:=Transform2D(part.transform)*Rect2(part.bounds).get_center()
		part.transform=Transform2D(side*age*float(config.get("fragment_spin",5.5)),center+drift)*Transform2D(0,-center)*Transform2D(part.transform)
	_wall_side(out,at,Vector2(event.get("nx",-aim.x),event.get("ny",-aim.y)),false)
	return out

## Keep native quads in front of the host contact plane, including spinning tips.
## The intact arrow shifts as one rig; separated fragments bounce independently.
static func _wall_side(layers: Array, at: Vector2, normal: Vector2, together: bool) -> void:
	if normal.length_squared()<0.001: return
	normal=normal.normalized()
	var deepest:=0.0
	for layer: Dictionary in layers:
		var box: Rect2=layer.bounds
		var matrix: Transform2D=layer.transform
		var penetration:=0.0
		for corner: Vector2 in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
			penetration=maxf(penetration,-(matrix*corner-at).dot(normal))
		deepest=maxf(deepest,penetration)
		if not together:
			matrix.origin+=normal*penetration
			layer.transform=matrix
	if together and deepest>0:
		for layer: Dictionary in layers:
			var matrix: Transform2D=layer.transform
			matrix.origin+=normal*deepest
			layer.transform=matrix

## One-use gold sights and a shaft attached to each pinned victim.
static func statuses(canvas: CanvasItem, state: Dictionary, clock: float, art: float, sprites: RefCounted) -> void:
	for mark: Dictionary in state.get("archer_marks",[]):
		var at:=Vector2(mark.x,mark.y)-Vector2(0,12*art)
		Sprites.draw(canvas,"hunters_mark",at,0,art,null,1,Vector2(mark.x,mark.y))
	for pin: Dictionary in state.get("archer_pins",[]):
		var ground:=Vector2(pin.x,pin.y)
		sprites.draw_external_rig(canvas,parts(ground-Vector2(0,8*art),Vector2(pin.ax,pin.ay),clock,art*0.8,clampf(float(pin.time),0,1)),ground)
