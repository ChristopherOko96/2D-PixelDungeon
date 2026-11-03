extends RefCounted
## Actual parented skins, solved by the same hierarchy used for skeleton limbs.
## Textures are approved guardian cutouts, cached once; no per-frame image work.
const Guardian = preload("res://src/rig/soul_guardian_rig.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
static var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/soul_beam_rig.json"))
static var rig: Dictionary = {}

static func prepare() -> void:
	if not rig.is_empty(): return
	Guardian.prepare()
	rig = Guardian.rig.duplicate()
	rig.ground = Vector2.ZERO
	rig.parts = []
	rig.by_id = {}
	rig.items = []
	for strand in range(2):
		for n in range(int(cfg.segments)):
			var part: Dictionary = Guardian.rig.by_id[str(cfg.source_parts[strand])].duplicate()
			part.id = "strand_%d_%d" % [strand,n]
			part.parent = "strand_%d_%d" % [strand,n-1] if n>0 else ""
			part.z = strand
			rig.parts.append(part)
			rig.by_id[part.id] = part

## Both ends are pinned to their live rig sockets; only the inner joints wave.
static func sample(from: Vector2, to: Vector2, u: float, age: float, art: float, strand := 0) -> Vector2:
	var offset := to-from
	var normal := offset.orthogonal().normalized()
	var handle := offset*0.33
	var center := from.bezier_interpolate(from+handle,to-handle,to,u)
	return center+normal*sin(u*PI)*sin(age*float(cfg.wave_rate)-u*TAU*1.5+strand*PI)*float(cfg.amplitude_px)*art

## Convert world segment transforms into local parent poses before solving.
static func parts(from: Vector2, to: Vector2, age: float, art: float, alpha := 1.0) -> Array:
	prepare()
	var pose := Poses.blank()
	for strand in range(2):
		var parent := Transform2D(0,from)*Transform2D(Vector2(art,0),Vector2(0,art),Vector2.ZERO)
		var previous := from
		for n in range(int(cfg.segments)):
			var u := float(n+1)/float(cfg.segments)
			var next := sample(from,to,u,age,art,strand)
			var id := "strand_%d_%d" % [strand,n]
			var bounds: Rect2 = rig.by_id[id].bounds
			var width := art*float(cfg.width_px)*(0.8+0.2*sin(u*PI))*(1.0 if strand==0 else float(cfg.core_width))
			var size := Vector2(maxf(0.001,previous.distance_to(next))/bounds.size.x,width/bounds.size.y)
			var desired := Transform2D((next-previous).angle(),(previous+next)*0.5)*Transform2D(Vector2(size.x,0),Vector2(0,size.y),Vector2.ZERO)*Transform2D(0,-bounds.get_center())
			Poses.P(pose,id).local_transform = parent.affine_inverse()*desired
			previous = next
			parent = desired
	var solved: Dictionary = Guardian.solver.solve_pose(rig,pose,from,1.0,art)
	var result: Array = []
	for part: Dictionary in rig.parts:
		result.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":solved[part.id],"tint":Color(1,1,1,alpha)})
	return result
