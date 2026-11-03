extends RefCounted
## Cached skeleton skull/ribs/limbs assembled through the real parent-joint solver.
## Reuses approved source pixels; no new sheet or per-frame image manipulation.
const Library = preload("res://src/rig/rig_library.gd")
const Renderer = preload("res://src/rig/rig_renderer.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
static var rig: Dictionary = {}
static var solver: RefCounted

## Prepare seven cached cutouts with a skull-rooted hierarchy.
static func prepare() -> void:
	if not rig.is_empty(): return
	var library := Library.shared()
	var source: Dictionary = library.rig("skeleton")
	rig = source.duplicate()
	rig.name = "necro_bone_ball"
	rig.ground = Vector2.ZERO
	rig.parts = []
	rig.items = []
	rig.by_id = {}
	var ids := ["skull","torso","leg_l","leg_r","leg_l","leg_r","torso"]
	for n in range(ids.size()):
		var original: Dictionary = source.by_id.get(ids[n],source.by_id.skull)
		var part: Dictionary = original.duplicate()
		part.id = "core" if n==0 else "bone_%d"%n
		part.parent = "" if n==0 else "core"
		part.z = n
		rig.parts.append(part)
		rig.by_id[part.id] = part
	solver = Renderer.new(library)

## Assemble during windup; independently rotate each orbiting rib during flight.
static func parts(at: Vector2, age: float, art: float, alpha := 1.0, assembly := 1.0) -> Array:
	prepare()
	var pose := Poses.blank()
	var parent := Transform2D.IDENTITY
	for n in range(rig.parts.size()):
		var part: Dictionary = rig.parts[n]
		var angle := age*2.2+n*TAU/6.0
		var radius := lerpf(17,6.0,smoothstep(0,1,assembly))
		var point := Vector2.ZERO if n==0 else Vector2(cos(angle),sin(angle)*0.85)*radius
		var size := Vector2.ONE*(0.8 if n==0 else 0.62)
		var desired := Transform2D(sin(age*1.6)*0.1 if n==0 else angle+PI*0.5,point)*Transform2D(0,size,0,Vector2.ZERO)*Transform2D(0,-Vector2(part.center))
		Poses.P(pose,str(part.id)).local_transform = desired if n==0 else parent.affine_inverse()*desired
		if n==0: parent = desired
	var world: Dictionary = solver.solve_pose(rig,pose,at,1,art)
	var out: Array = []
	for part: Dictionary in rig.parts:
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":Color(1,1,1,clampf(alpha,0,1))})
	return out
