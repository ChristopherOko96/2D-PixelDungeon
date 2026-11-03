extends RefCounted
## Soul nova: rig spirits travel outward, then a true annular field remains.
## Ground material comes from PoolPaint, never from overlapping round decals.
const Spirit = preload("res://src/rig/soul_spirit_rig.gd")
const Fragments = preload("res://src/vfx/soul_fragments.gd")
const Shape = preload("res://src/combat/soul_ring_shape.gd")
const Patterns = preload("res://src/vfx/soul_patterns.gd")

## Continuous rig positions on the expanding ring, preserving a readable face.
static func cast_samples(at: Vector2, radius: float, progress: float) -> Array:
	var result: Array = []
	var p := clampf(progress, 0.0, 1.0)
	var reach := lerpf(8.0, radius, smoothstep(0.0, 1.0, p))
	var alpha := smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.75, 1.0, p))
	for i in range(6):
		var angle := TAU * float(i) / 6.0 + p * 0.6
		result.append({"at": at + Vector2.from_angle(angle) * reach, "alpha": alpha, "seed": float(i) / 6.0})
	return result

## Bases stay inside the outer band, with fresh births on the actual surface.
static func rim_samples(at: Vector2, outer: float, inner: float, age: float, cfg: Dictionary = {}) -> Array:
	var result: Array = []
	var cycle := maxf(1.0, float(cfg.get("field_ghost_cycle", 3.4)))
	for i in range(6):
		var seed := fposmod(float(i) * 0.6180339, 1.0)
		var elapsed := maxf(0.0, age) - seed * cycle * 0.45
		var p := fposmod(maxf(0.0, elapsed) / cycle, 1.0)
		var angle := TAU * float(i) / 6.0 + age * 0.15
		var base := at + Vector2.from_angle(angle) * (inner + outer) * 0.5
		result.append({"base": base, "at": base - Vector2(0, outer * 0.22 * p), "phase": p, "seed": seed,
			"alpha": smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.64, 1.0, p)) if elapsed >= 0.0 else 0.0})
	return result

## Existing nova animation plus six articulated souls, clipped at walls.
static func draw_cast(canvas: CanvasItem, at: Vector2, radius: float, progress: float, age: float, art: float, sprites: RefCounted, cfg: Dictionary = {}) -> void:
	Patterns.wave(canvas, at, radius, progress, art, sprites)
	for ghost: Dictionary in cast_samples(at, radius, progress):
		if not Shape.visible(at, ghost.at, sprites.open): continue
		var parts := Spirit.draw_parts(ghost.at, art * 0.5, age, float(ghost.alpha), float(ghost.seed), 1.0, cfg)
		sprites.draw_external_rig(canvas, parts, at)

## Rising motes and rig ghosts originate only on the ring's outer material.
static func draw_field(canvas: CanvasItem, at: Vector2, outer: float, inner: float, age: float, opacity: float, art: float, sprites: RefCounted, cfg: Dictionary = {}) -> void:
	Spirit.prepare()
	var samples: Array = []
	for i in range(36):
		var seed := fposmod(float(i) * 0.6180339, 1.0)
		var phase := fposmod(age / 2.6 + seed, 1.0)
		var angle := float(i) * 2.39996 + age * 0.12
		var base := at + Vector2.from_angle(angle) * lerpf(inner + art, outer - art, seed)
		if not Shape.visible(at, base, sprites.open): continue
		samples.append({"at": base - Vector2(0, phase * outer * 0.3), "alpha": smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.5, 1.0, phase)) * 0.65})
	sprites.draw_external_rig(canvas, Fragments.mote_parts(samples, art, opacity), at)
	var ghosts := rim_samples(at, outer, inner, age, cfg)
	ghosts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.base).y < Vector2(b.base).y)
	for ghost: Dictionary in ghosts:
		if not Shape.visible(at, ghost.base, sprites.open): continue
		var parts := Spirit.draw_parts(ghost.at, art * 0.5, age, float(ghost.alpha) * opacity, float(ghost.seed), float(ghost.phase), cfg)
		sprites.draw_external_rig(canvas, parts, ghost.base)
