extends RefCounted
## Approved cutout art animated through the very same hierarchy solver used by
## skeletons. Local presentation only: no hit parts, attacks or timers here.
const Library = preload("res://src/rig/rig_library.gd")
const Renderer = preload("res://src/rig/rig_renderer.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
const DATA := "res://assets/data/soul_guardian_rig.json"
static var rig: Dictionary = {}
static var solver: RefCounted

static func prepare() -> void:
	if not rig.is_empty(): return
	var library := Library.new()
	if not library.load_data("", DATA): return
	rig = library.rig("soul_guardian")
	rig.parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.z) < int(b.z))
	solver = Renderer.new(library)

static func solve(pose_data: Dictionary, point: Vector2, face: float, art: float) -> Dictionary:
	return solver.solve_pose(rig, pose_data, point, face, art)

## Lifetime drives hovering even when a new host action resets its phase age.
## All curves meet the idle pose with zero action velocity at clip boundaries.
static func pose(motion: String, age: float, duration: float, lifetime: float, config: Dictionary = {}) -> Dictionary:
	var out := Poses.blank()
	var t := maxf(0.0, lifetime)
	var ph := t * TAU / 3.2
	out.whole.dy = sin(ph) * 1.4
	out.whole.alpha = 1.0
	Poses.P(out, "torso").rot = sin(ph) * 0.025
	Poses.P(out, "head").rot = sin(ph + 0.35) * -0.04
	Poses.P(out, "arm_l").rot = sin(ph + 0.7) * 0.10
	Poses.P(out, "arm_r").rot = sin(ph + 2.1) * 0.12
	Poses.P(out, "hand_l").rot = sin(ph + 1.2) * 0.09
	Poses.P(out, "hand_r").rot = sin(ph + 2.7) * 0.11
	Poses.P(out, "tail_root").rot = sin(ph - 0.4) * 0.08
	Poses.P(out, "tail_mid").rot = sin(ph - 1.1) * 0.13
	Poses.P(out, "tail_tip").rot = sin(ph - 1.8) * 0.20
	var u := clampf(age / maxf(0.01, duration), 0.0, 1.0)
	if motion == "grasp":
		var wind := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.25, 0.5, u))
		var reach := smoothstep(0.25, 0.5, u) * (1.0 - smoothstep(0.6, 1.0, u))
		Poses.P(out, "arm_r").rot += wind * 0.24 - reach * 0.95
		Poses.P(out, "arm_r").sy += reach * 0.65
		Poses.P(out, "hand_r").rot -= reach * 0.12
		Poses.P(out, "arm_l").rot += wind * 0.20 - reach * 0.12
		Poses.P(out, "torso").dx += reach * 1.5 - wind * 0.5
		Poses.P(out, "torso").rot -= reach * 0.05
		Poses.P(out, "head").rot += reach * 0.05
	elif motion == "beam":
		var wind := maxf(0.01, float(config.get("beam_windup", 0.45)))
		var end := wind + float(config.get("beam_time", 1.6))
		var charge := smoothstep(0.0, wind, age) * (1.0 - smoothstep(end, duration, age))
		var pulse := sin((age - wind) * TAU * 1.2) * smoothstep(wind, wind + 0.15, age) * charge
		var pitch := atan2(float(config.get("aim_y",0.0)),maxf(0.2,absf(float(config.get("aim_x",1.0)))))
		Poses.P(out, "arm_r").rot -= charge * 1.05
		Poses.P(out, "arm_r").rot += charge * pitch * 0.65
		Poses.P(out, "arm_r").sy += charge * 0.45
		Poses.P(out, "hand_r").rot -= charge * 0.18 + pulse * 0.035
		Poses.P(out, "arm_l").rot += charge * 0.48
		Poses.P(out, "hand_l").rot -= charge * 0.35
		Poses.P(out, "torso").dx -= charge * 1.2 + pulse * 0.3
		Poses.P(out, "torso").rot -= charge * 0.045
		Poses.P(out, "head").rot += charge * 0.06
	elif motion == "spawn":
		var rise := smoothstep(0.0, 1.0, u)
		out.whole.alpha = smoothstep(0.0, 0.45, u)
		out.whole.dy += (1.0 - rise) * 14.0
		out.whole.sx = 0.65 + rise * 0.35
		out.whole.sy = 0.65 + rise * 0.35
	elif motion == "dissolve":
		out.whole.alpha = 1.0 - smoothstep(0.1, 1.0, u)
		out.whole.dy -= smoothstep(0.0, 1.0, u) * 10.0
		for id: String in ["tail_tip", "tail_mid", "tail_root"]:
			Poses.P(out, id).alpha = 1.0 - smoothstep(0.0, 0.7, u)
	return out

static func draw_parts(actor: Dictionary, age: float, duration: float, lifetime: float, at: Vector2, art: float) -> Array:
	prepare()
	if rig.is_empty(): return []
	var pose_data := pose(str(actor.get("motion", "hover")), age, duration, lifetime, actor)
	var world := solve(pose_data, at, -1.0 if float(actor.get("face", 1.0)) < 0.0 else 1.0, art)
	var result: Array = []
	for part: Dictionary in rig.parts:
		var alpha := float(pose_data.whole.alpha) * float(pose_data.parts.get(part.id, {}).get("alpha", 1.0))
		result.append({"id": part.id, "texture": part.texture, "transform": world[part.id], "bounds": part.bounds, "tint": Color(1, 1, 1, alpha)})
	return result
