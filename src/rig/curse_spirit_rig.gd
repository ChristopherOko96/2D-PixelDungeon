extends RefCounted
## Eight cutouts of the user-approved curse creature; no Soul-spirit source reuse.
const Library = preload("res://src/rig/rig_library.gd")
const Renderer = preload("res://src/rig/rig_renderer.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
static var rig: Dictionary = {}
static var solver: RefCounted

## Cache each source mask and texture once, using the existing layered rig loader.
static func prepare() -> void:
	if not rig.is_empty(): return
	var library := Library.new()
	assert(library.load_data("","res://assets/data/curse_spirit_rig.json","",""))
	rig = library.rig("curse_spirit")
	rig.ground = Vector2(16,20)
	rig.parts.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.z)<int(b.z))
	solver = Renderer.new(library)

## Jaw, hands and a delayed three-joint cloth tail move continuously.
static func parts(at: Vector2, art: float, clock: float, alpha := 1.0, seed := 0.0, aim := Vector2.ZERO, burst := -1.0) -> Array:
	prepare()
	var p := Poses.blank()
	var t := clock*2.4+seed
	Poses.P(p,"core").dy = sin(t)*0.7
	Poses.P(p,"core").rot = sin(t)*0.045
	Poses.P(p,"head").rot = -sin(t+0.4)*0.09
	Poses.P(p,"jaw").rot = (0.5+0.5*sin(t*1.2))*0.2
	Poses.P(p,"jaw").dy = (0.5+0.5*sin(t*1.2))*0.6
	Poses.P(p,"claw_l").rot = -0.15+sin(t+0.3)*0.2
	Poses.P(p,"claw_r").rot = 0.15-sin(t+0.7)*0.2
	for n in range(3):
		var id: String = ["tail_root","tail_mid","tail_tip"][n]
		Poses.P(p,id).rot = sin(t-0.5-n*0.6)*(0.12+0.07*n)
	if aim.length_squared()>0.01:
		p.whole.rot = aim.angle()+PI*0.5
		p.whole.sx = 0.88
		p.whole.sy = 1.1
	if burst>=0:
		for n in range(rig.parts.size()):
			var part: Dictionary = rig.parts[n]
			var angle := n*2.39996+seed
			Poses.P(p,str(part.id)).dx += cos(angle)*burst*16
			Poses.P(p,str(part.id)).dy += sin(angle)*burst*16
			Poses.P(p,str(part.id)).rot += burst*sin(angle)*1.2
	var world: Dictionary = solver.solve_pose(rig,p,at,1,art)
	var out: Array = []
	for part: Dictionary in rig.parts:
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":Color(1,1,1,clampf(alpha,0,1))})
	return out
