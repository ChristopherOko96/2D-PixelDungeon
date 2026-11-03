extends RefCounted
## Eight cached arrow-cutout jaws, driven by the same parent-joint solver.
const Library = preload("res://src/rig/rig_library.gd")
const Renderer = preload("res://src/rig/rig_renderer.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
static var rig: Dictionary = {}
static var solver: RefCounted

## Build a source-textured hub with eight jaw children once per process.
static func prepare() -> void:
	if not rig.is_empty(): return
	var library := Library.new()
	library.load_data("","","res://assets/data/forest_trap_rig.json","")
	var source: Dictionary = library.rig("forest_tooth")
	rig = source.duplicate()
	rig.parts = []
	rig.by_id = {}
	rig.ground = Vector2.ZERO
	for n in range(9):
		var part: Dictionary = source.parts[0].duplicate()
		part.id = "hub" if n==0 else "jaw_%d"%n
		part.parent = "" if n==0 else "hub"
		rig.parts.append(part)
		rig.by_id[part.id] = part
	solver = Renderer.new(library)

## Independently breathing jaws spring outward on trigger, then fade.
static func parts(at: Vector2, art: float, clock: float, seed: int, progress := -1.0, spread := 1.0) -> Array:
	prepare()
	var pose := Poses.blank()
	var root_transform := Transform2D.IDENTITY
	for n in range(rig.parts.size()):
		var part: Dictionary = rig.parts[n]
		var angle := float(n-1)*TAU/8+seed*0.17
		var radius := 0.0 if n==0 else 6*spread+sin(clock*1.6+n)*0.3
		if progress>=0: radius += sin(progress*PI)*12
		var desired := Transform2D(angle,Vector2(cos(angle),sin(angle)*0.65)*radius)*Transform2D(0,Vector2.ONE*(0.35 if n==0 else 0.55),0,Vector2.ZERO)*Transform2D(0,-Vector2(part.center))
		Poses.P(pose,str(part.id)).local_transform = desired if n==0 else root_transform.affine_inverse()*desired
		if n==0: root_transform = desired
	var world: Dictionary = solver.solve_pose(rig,pose,at,1,art)
	var out: Array = []
	for part: Dictionary in rig.parts:
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":Color(1,1,1,1.0 if progress<0 else 1-progress)})
	return out
