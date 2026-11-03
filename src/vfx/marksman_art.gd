extends RefCounted
## Existing arrow cutouts, cached once, posed through the actual joint solver.
const Library=preload("res://src/rig/rig_library.gd")
const Renderer=preload("res://src/rig/rig_renderer.gd")
const Poses=preload("res://src/rig/rig_poses.gd")
static var rig: Dictionary={}
static var solver: RefCounted

## Native head, shaft and two separate fletching masks.
static func parts(at: Vector2, aim: Vector2, clock: float, art: float, alpha:=1.0) -> Array:
	if rig.is_empty():
		var library:=Library.new()
		library.load_data("","","res://assets/data/marksman_rig.json","")
		rig=library.rig("marksman_arrow")
		solver=Renderer.new(library)
	var pose:=Poses.blank()
	pose.whole.rot=aim.angle()+PI*0.5
	Poses.P(pose,"feather_l").rot=sin(clock*9)*0.10
	Poses.P(pose,"feather_r").rot=-sin(clock*9+0.4)*0.10
	var world: Dictionary=solver.solve_pose(rig,pose,at,1,art)
	var out: Array=[]
	for part: Dictionary in rig.parts:
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":Color(1.3,1.2,0.95,alpha)})
	return out

## Paid charge grows at the actual hero's hand, with a visible fill indicator.
static func charge(canvas: CanvasItem, state: Dictionary, clock: float, art: float, sprites: RefCounted) -> void:
	var ground:=Vector2(state.x,state.y)
	var aim:=Vector2(state.ax,state.ay).normalized()
	var power:=clampf(float(state.power),0,1)
	var hand:=ground-Vector2(0,12*art)+aim*art*(7+power*5)
	sprites.draw_external_rig(canvas,parts(hand,aim,clock,art*(0.8+power*0.7)),ground)
	for n in range(8):
		var p:=fposmod(clock+n*0.618,1)
		var pos:=hand+Vector2.from_angle(n*2.39996)*art*20*(1-p)
		canvas.draw_rect(Rect2(pos,Vector2.ONE*art),Color(1,0.8,0.3,sin(p*PI)*power))
	canvas.draw_rect(Rect2(ground+Vector2(-12,8)*art,Vector2(24,2)*art),Color("33251c"))
	canvas.draw_rect(Rect2(ground+Vector2(-12,8)*art,Vector2(24*power,2)*art),Color("f6cf78"))

## The massive arrow reaches only the host-clamped endpoint; tail stays behind.
static func spear(canvas: CanvasItem, event: Dictionary, p: float, clock: float, art: float, sprites: RefCounted) -> void:
	var from:=Vector2(event.x,event.y)
	var to:=Vector2(event.tx,event.ty)
	var aim:=(to-from).normalized()
	var tip:=from.lerp(to,clampf(p/0.45,0,1))
	var fade:=1-smoothstep(0.5,1,p)
	canvas.draw_line(from,tip,Color(0.95,0.77,0.4,fade*0.4),art*2)
	for n in range(6,0,-1):
		var point:=tip-aim*float(n)*art*8
		if (point-from).dot(aim)<0: continue
		sprites.draw_external_rig(canvas,parts(point,aim,clock+n,art*0.7,fade*(1-float(n)/7)*0.45),point)
	sprites.draw_external_rig(canvas,parts(tip,aim,clock,art*(1.4+float(event.get("charge",0))*0.7),fade),tip)

## One-use gold sights and a shaft attached to each pinned victim.
static func statuses(canvas: CanvasItem, state: Dictionary, clock: float, art: float, sprites: RefCounted) -> void:
	for mark: Dictionary in state.get("archer_marks",[]):
		var at:=Vector2(mark.x,mark.y)-Vector2(0,12*art)
		var r:=art*(8+sin(clock*3)*0.5)
		for n in range(4):
			var angle:=n*PI*0.5
			canvas.draw_arc(at,r,angle+0.1,angle+0.6,5,Color("f6cf78"),art,false)
	for pin: Dictionary in state.get("archer_pins",[]):
		var ground:=Vector2(pin.x,pin.y)
		sprites.draw_external_rig(canvas,parts(ground-Vector2(0,8*art),Vector2(pin.ax,pin.ay),clock,art*0.8,clampf(float(pin.time),0,1)),ground)
