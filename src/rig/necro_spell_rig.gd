extends RefCounted
## Existing source sprites cut once by RigLibrary, animated by the skeleton solver.
## No per-frame Image operations or cycling whole spritesheets.
const DATA := "res://assets/data/necro_spell_rigs.json"
const Library = preload("res://src/rig/rig_library.gd")
const Renderer = preload("res://src/rig/rig_renderer.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
const Curse = preload("res://src/rig/curse_spirit_rig.gd")
static var data: Dictionary = {}
static var library: RefCounted
static var solver: RefCounted
static var bone_solver: RefCounted
static var bone_rigs: Dictionary = {}

## Cached source masks, textures and the actual parent hierarchy.
static func prepare() -> void:
	if not data.is_empty(): return
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	library = Library.new()
	library.load_data(DATA,"","","")
	solver = Renderer.new(library)
	var base: Dictionary = library.rig("necro_blood")
	var chain: Dictionary = base.duplicate()
	chain.parts = []
	chain.items = []
	chain.by_id = {}
	chain.ground = Vector2.ZERO
	for n in range(int(data.motion.beam_segments)):
		var part: Dictionary = base.by_id.core.duplicate()
		part.id = "link_%d" % n
		part.parent = "link_%d" % (n-1) if n > 0 else ""
		part.z = n
		chain.parts.append(part)
		chain.by_id[part.id] = part
	library.rigs.necro_chain = chain

## Every active and companion command has an explicit rig/motion binding.
static func skill(id: String) -> Dictionary:
	prepare()
	return data.skills.get(id,{})

## Physical skeleton fragments still travel through the same joint solver.
static func bone_parts(id: String, at: Vector2, angle: float, art: float, alpha := 1.0) -> Array:
	prepare()
	if not bone_rigs.has(id):
		var source: Dictionary = Library.shared().rig("skeleton")
		var part: Dictionary = source.by_id.get(id,{})
		if part.is_empty(): return []
		var own: Dictionary = source.duplicate()
		part = part.duplicate()
		part.parent = ""
		own.parts = [part]
		own.by_id = {id:part}
		own.items = []
		own.ground = Vector2(part.center)
		bone_rigs[id] = own
	if bone_solver == null: bone_solver = Renderer.new(Library.shared())
	var rig: Dictionary = bone_rigs[id]
	var pose := Poses.blank()
	pose.whole.rot = angle
	return _draw_parts(rig,bone_solver.solve_pose(rig,pose,at,1.0,art),alpha)

## Continuous head/jaw/tail and hilt/blade poses, using real cutout joints.
static func parts(name: String, at: Vector2, aim: Vector2, age: float, art: float, alpha := 1.0) -> Array:
	if name=="curse_spirit": return Curse.parts(at,art,age,alpha)
	prepare()
	var rig: Dictionary = library.rig(name)
	if rig.is_empty(): return []
	var pose := Poses.blank()
	var phase := age*TAU/float(data.motion.cycle)
	pose.whole.rot = aim.angle()
	if name == "necro_curse":
		Poses.P(pose,"head").rot = sin(phase)*float(data.motion.head_turn)
		Poses.P(pose,"jaw").rot = (0.5+0.5*sin(phase+0.7))*float(data.motion.jaw_open)
		Poses.P(pose,"jaw").dy = 0.35+sin(phase+0.7)*0.25
		Poses.P(pose,"tail_root").rot = sin(phase-0.5)*float(data.motion.tail_root)
		Poses.P(pose,"tail_tip").rot = sin(phase-1.1)*float(data.motion.tail_tip)
	elif name == "necro_spear":
		Poses.P(pose,"shaft").rot = sin(phase)*0.035
		Poses.P(pose,"tail").rot = sin(phase-0.6)*0.09
	elif name == "necro_blade":
		Poses.P(pose,"blade").rot = sin(phase)*0.07
		Poses.P(pose,"pommel").rot = -sin(phase-0.3)*0.08
	else:
		Poses.P(pose,"root").rot = sin(phase)*0.13
		Poses.P(pose,"tip").rot = sin(phase-0.8)*0.18
	return _draw_parts(rig,solver.solve_pose(rig,pose,at,1.0,art),alpha)

static func _draw_parts(rig: Dictionary, world: Dictionary, alpha: float) -> Array:
	var out: Array = []
	for part: Dictionary in rig.parts:
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":Color(1,1,1,clampf(alpha,0,1))})
	return out

## A skinned sixteen-bone fluid spine. Its ends exactly meet both actor sockets.
## Each desired segment is converted to its parent's local affine pose, then
## solved by RigRenderer.solve_pose just like actor limbs.
static func beam_parts(from: Vector2, to: Vector2, clock: float, art: float, alpha := 1.0) -> Array:
	prepare()
	var rig: Dictionary = library.rig("necro_chain")
	var pose := Poses.blank()
	var count: int = rig.parts.size()
	var normal := (to-from).orthogonal().normalized()
	var parent := Transform2D(0,from)*Transform2D(Vector2(art,0),Vector2(0,art),Vector2.ZERO)
	var previous := from
	for i in range(count):
		var u := float(i+1)/float(count)
		var next := from.lerp(to,u)+normal*sin(u*PI)*sin(clock*float(data.motion.beam_wave)-u*7.0)*art*float(data.motion.beam_amplitude_px)
		var bone: Dictionary = rig.parts[i]
		var bounds: Rect2 = bone.bounds
		var centre := bounds.get_center()
		var length := maxf(0.001,previous.distance_to(next))
		var thickness := art*(2.8+0.4*sin(clock*4.0-u*8.0))
		var desired := Transform2D((next-previous).angle(),(previous+next)*0.5)*Transform2D(Vector2(length/bounds.size.x,0),Vector2(0,thickness/bounds.size.y),Vector2.ZERO)*Transform2D(0,-centre)
		Poses.P(pose,str(bone.id)).local_transform = parent.affine_inverse()*desired
		parent = desired
		previous = next
	return _draw_parts(rig,solver.solve_pose(rig,pose,from,1.0,art),alpha)

## Mathematically exact skin endpoints, used by regression tests and capture QA.
static func endpoints(parts_list: Array) -> PackedVector2Array:
	if parts_list.is_empty(): return PackedVector2Array()
	var first: Dictionary = parts_list[0]
	var last: Dictionary = parts_list[-1]
	var a: Rect2 = first.bounds
	var b: Rect2 = last.bounds
	return PackedVector2Array([Transform2D(first.transform)*Vector2(a.position.x,a.get_center().y),Transform2D(last.transform)*Vector2(b.end.x,b.get_center().y)])

## A drop starts in the existing puddle and arrives inside the live torso socket.
static func absorption_point(from: Vector2, into: Vector2, phase: float, art: float) -> Vector2:
	prepare()
	var u := smoothstep(0,1,clampf(phase,0,1))
	return from.lerp(into,u)-Vector2(0,sin(PI*u)*float(data.motion.absorption.lift_px)*art)
