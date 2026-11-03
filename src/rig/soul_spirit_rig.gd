extends RefCounted
## Small approved field spirit animated by the same bone solver as skeletons.
const Library = preload("res://src/rig/rig_library.gd")
const Renderer = preload("res://src/rig/rig_renderer.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
const Fragments = preload("res://src/vfx/soul_fragments.gd")
static var rig: Dictionary = {}
static var solver: RefCounted

## Prepare the four approved cutouts and their fragment textures once.
static func prepare() -> void:
	if not rig.is_empty(): return
	var library := Library.new()
	if not library.load_data("", "res://assets/data/soul_spirit_rig.json"): return
	rig = library.rig("soul_spirit")
	rig.parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.z) < int(b.z))
	solver = Renderer.new(library)
	for part: Dictionary in rig.parts:
		if str(part.id) in ["tail_mid", "tail_tip"]: Fragments.prepare_part("spirit:" + str(part.id), part)

## Five (bounded to six) independently seeded births within the existing field.
static func field_samples(at: Vector2, radius: float, age: float, cfg: Dictionary = {}) -> Array:
	var result: Array = []
	var count := clampi(int(cfg.get("field_ghost_count", 5)), 0, 6)
	var cycle := maxf(1.0, float(cfg.get("field_ghost_cycle", 3.4)))
	for i in range(count):
		var seed := fposmod(float(i) * 0.6180339, 1.0)
		var elapsed := maxf(0.0, age) - seed * cycle * 0.45
		var p := fposmod(maxf(0.0, elapsed) / cycle, 1.0)
		var angle := float(i) * 2.39996 + 0.4
		var base := at + Vector2(cos(angle) * radius * 0.60, sin(angle) * radius * 0.32)
		var alpha := smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.64, 1.0, p)) * smoothstep(0.0, 0.35, age) if elapsed >= 0.0 else 0.0
		var lift := radius * float(cfg.get("field_ghost_rise", 0.32)) * p
		result.append({"base": base, "at": base + Vector2(sin(p * TAU + seed * TAU) * radius * 0.045, -lift),
			"phase": p, "alpha": alpha, "scale": radius / 112.0 * float(cfg.get("field_ghost_scale", 1.35)), "seed": seed})
	return result

## Shared hierarchy, with a living face and delayed, shedding tail sections.
static func draw_parts(at: Vector2, scale: float, age: float, alpha: float, seed: float = 0.0, birth: float = 1.0, cfg: Dictionary = {}) -> Array:
	prepare()
	if rig.is_empty(): return []
	var pose := Poses.blank()
	var ph := age * TAU / 2.8 + seed * TAU
	Poses.P(pose, "body").rot = sin(ph) * 0.06
	Poses.P(pose, "head").rot = -sin(ph + 0.4) * 0.08
	Poses.P(pose, "tail_mid").rot = sin(ph - 0.6) * 0.18
	Poses.P(pose, "tail_tip").rot = sin(ph - 1.2) * 0.28
	var emerge := smoothstep(0.0, 0.18, birth)
	pose.whole.sx = 0.7 + emerge * 0.3
	pose.whole.sy = 0.4 + emerge * 0.6
	var world: Dictionary = solver.solve_pose(rig, pose, at, 1.0, scale)
	var result: Array = []
	for part: Dictionary in rig.parts:
		result.append({"id": part.id, "texture": part.texture, "bounds": part.bounds, "transform": world[part.id], "tint": Color(1, 1, 1, clampf(alpha, 0.0, 1.0))})
	return Fragments.parts(result, age + seed * 2.0, "spirit", cfg)
