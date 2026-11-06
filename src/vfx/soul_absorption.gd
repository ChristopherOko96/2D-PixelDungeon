extends RefCounted
## Cosmetic Seelensog: the existing field spirit flies into the posed staff orb.
const Spirit = preload("res://src/rig/soul_spirit_rig.gd")
const Paint = preload("res://src/vfx/pixel_paint.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")

## Sample a single flight and intake pulse from normalized host-event age.
## Sizes are art pixels; the exact current socket is reached before the pulse.
static func sample(from: Vector2, to: Vector2, progress: float, art: float, seed: int, cfg: Dictionary = {}) -> Dictionary:
	if progress < 0.0 or progress >= 1.0: return {}
	var arrival := clampf(float(cfg.get("arrival", 0.76)), 0.2, 0.95)
	var travel := clampf(progress / arrival, 0.0, 1.0)
	var q := travel * travel
	var arc := sin(PI * q)
	var side := 1.0 if seed % 2 == 0 else -1.0
	var at := from.lerp(to, q) + Vector2(side * float(cfg.get("bend", 3.0)), -float(cfg.get("rise", 8.0))) * art * arc
	var shrink := 1.0 - smoothstep(float(cfg.get("shrink_start", 0.62)), 1.0, travel)
	var pulse := sin(PI * clampf((progress - arrival) / (1.0 - arrival), 0.0, 1.0))
	return {"from": from, "to": to, "at": at, "progress": progress, "travel": travel,
		"scale": art * float(cfg.get("spirit_scale", 0.28)) * shrink,
		"alpha": smoothstep(0.0, 0.12, travel) * shrink, "pulse": pulse}

## Reuses cached cutout textures; the short trail and intake glint use soul pixels.
static func draw(canvas: CanvasItem, frame: Dictionary, clock: float, art: float, seed: int, sprites: RefCounted, cfg: Dictionary = {}, particles: RefCounted = null, to_particles := 1.0) -> void:
	if frame.is_empty(): return
	var colours := Pal.ramp("soul")
	var at: Vector2 = frame.at
	var target: Vector2 = frame.to
	var alpha := float(frame.alpha)
	if particles != null:
		particles.release_soul("pickup:%d"%seed,Vector2(frame.from)*to_particles,target*to_particles,int(cfg.get("particle_count",18)),maxf(0.05,float(frame.get("span",1.4))*(1-float(frame.progress))))
	elif alpha > 0.001:
		var trail := clampi(int(cfg.get("trail_count", 5)), 0, 8)
		for i in range(trail):
			var earlier := maxf(0.0, float(frame.progress) - (i + 1) * 0.025)
			var tail := sample(Vector2(frame.from), target, earlier, art, seed, cfg)
			if tail.is_empty(): continue
			var point := Vector2(tail.at) - Vector2(0, 7) * float(frame.scale)
			Paint.disc(canvas, point, art * 0.7, art * 0.7, colours[3 if i < 2 else 2], art, alpha * (1.0 - float(i) / maxi(1, trail)))
		# The rig's anchor is at its feet; center its face/body on the flight path.
		var feet := at + Vector2(0, 24) * float(frame.scale)
		sprites.draw_external_rig(canvas, Spirit.draw_parts(feet, float(frame.scale), clock, alpha, float(seed % 31) / 31.0, 1.0), at)
	var pulse := float(frame.pulse)
	if pulse > 0.001:
		var radius := art * float(cfg.get("pulse_radius", 3.0)) * pulse
		Paint.disc(canvas, target, radius, radius, colours[2], art, pulse)
		Paint.cell(canvas, Paint.at(target, art), colours[4], art)
		for axis: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			Paint.cell(canvas, Paint.at(target + axis * radius, art), colours[3], art)
