extends RefCounted
## Approved guardian art, shared across worlds. Original atlas retained for
## provenance; live animation uses cutout bones through the skeleton solver.
const GuardianRig = preload("res://src/rig/soul_guardian_rig.gd")
const Fragments = preload("res://src/vfx/soul_fragments.gd")
const Beam = preload("res://src/vfx/soul_beam.gd")
const SOURCE := "res://assets/vfx/soul_guardian/guardian_atlas.png"
const CELL := Vector2i(128, 80)
const ANCHOR := Vector2(48, 64)
const ROWS := {"spawn": 0, "hover": 1, "grasp": 2, "dissolve": 3}
static var frames: Array[Texture2D] = []
static var mirrored: Array[Texture2D] = []

## Reuses imported native textures, preserving hard pixels and dark eyes.
static func prepare() -> void:
	GuardianRig.prepare()
	for part: Dictionary in GuardianRig.rig.get("parts", []):
		if str(part.id) in ["tail_mid", "tail_tip"]: Fragments.prepare_part("guardian:" + str(part.id), part)
	if not frames.is_empty(): return
	var tex := load(SOURCE) as Texture2D
	if tex == null: return
	var source := tex.get_image()
	if source == null or source.get_size() != CELL * Vector2i(8, 4): return
	for index in range(32):
		var image := source.get_region(Rect2i((index % 8) * CELL.x, (index / 8) * CELL.y, CELL.x, CELL.y))
		frames.append(ImageTexture.create_from_image(image))
		image.flip_x()
		mirrored.append(ImageTexture.create_from_image(image))

## Host phase time selects the pose, so late/rejoined clients do not restart it.
static func frame_index(motion: String, age: float, duration: float) -> int:
	var phase := maxf(0.0, age) / maxf(0.01, duration)
	if motion == "hover": phase = fposmod(phase, 1.0)
	return int(ROWS.get(motion, 1)) * 8 + clampi(int(phase * 8.0), 0, 7)

## Continuous articulated poses; textures remain nearest-filtered.
static func draw(canvas: CanvasItem, actor: Dictionary, age: float, art: float, renderer: RefCounted, lifetime: float = -1.0, motion_cfg: Dictionary = {}) -> void:
	var duration := maxf(0.01, float(actor.get("duration", 1.0)))
	var at := Vector2(float(actor.x), float(actor.y))
	var life := maxf(0.0, lifetime if lifetime >= 0.0 else age)
	var dust: Array = aura_samples(maxf(0.0, lifetime), int(actor.get("id", 0)), motion_cfg) if not motion_cfg.is_empty() else []
	var dust_fade := smoothstep(0.0, 0.6, maxf(0.0, lifetime)) * clampf(float(actor.get("left", 1.0)) / 0.8, 0.0, 1.0)
	_draw_dust(canvas, at, dust, art, dust_fade, renderer, false)
	var parts := GuardianRig.draw_parts(actor, age, duration, life, at, art)
	for part: Dictionary in parts:
		if str(part.id) == "hand_r": Beam.draw(canvas, actor, age, Transform2D(part.transform) * Vector2(65, 42), art, renderer)
	renderer.draw_external_rig(canvas, Fragments.parts(parts, life, "guardian", motion_cfg), at)
	_draw_dust(canvas, at, dust, art, dust_fade, renderer, true)

## Mint seal above marked enemies and a floor halo on friendly underlings.
static func seal(canvas: CanvasItem, at: Vector2, clock: float, art: float, friendly: bool = false, fade: float = 1.0) -> void:
	var center := at if friendly else at - Vector2(0, 24.0 * art)
	for i in range(12):
		var angle := i * TAU / 12.0 + clock * 0.55
		var p := center + Vector2(cos(angle) * 6.0, sin(angle) * (2.0 if friendly else 4.0)) * art
		canvas.draw_rect(Rect2(p, Vector2.ONE * art), Color("83d1ca", fade * 0.8))
	if not friendly:
		canvas.draw_rect(Rect2(center - Vector2(0, art), Vector2(art, 3.0 * art)), Color("d9f5dc", fade))

## Stable loops use lifetime, not action age: casting cannot restart the aura.
## Native particle coordinates are presentation only and never enter snapshots.
static func aura_samples(age: float, id: int, cfg: Dictionary) -> Array:
	var out: Array = []
	var count := clampi(int(cfg.get("aura_count", 24)), 0, 48)
	var radius := float(cfg.get("aura_radius", 23.0))
	var height := float(cfg.get("aura_height", 48.0))
	var cycle := maxf(0.5, float(cfg.get("aura_cycle", 3.2)))
	for i in range(count):
		var seed := fposmod(float(i) * 0.6180339 + float(id) * 0.137, 1.0)
		var phase := fposmod(age / (cycle * (0.85 + seed * 0.3)) + seed, 1.0)
		var angle := age * 0.45 + float(i) * 2.39996 + float(id)
		var depth := sin(angle)
		var offset := Vector2(cos(angle) * radius * (0.65 + seed * 0.35), -height * phase + depth * radius * 0.17)
		out.append({"offset": offset, "depth": depth, "alpha": pow(sin(phase * PI), 1.5) * float(cfg.get("aura_opacity", 0.46)),
			"size": 2.0 if i % 7 == 0 else 1.0, "shade": i % 3})
	return out

static func _draw_dust(canvas: CanvasItem, at: Vector2, dust: Array, art: float, fade: float, renderer: RefCounted, front: bool) -> void:
	var shades := [Color("35526e"), Color("679aab"), Color("83d1ca")]
	for mote: Dictionary in dust:
		if (float(mote.depth) >= 0.0) != front: continue
		var offset: Vector2 = mote.offset * art
		if not renderer.open(at + Vector2(offset.x, float(mote.depth) * art * 3.0)): continue
		var color: Color = shades[int(mote.shade)]
		color.a = float(mote.alpha) * fade
		canvas.draw_rect(Rect2(at + offset, Vector2.ONE * float(mote.size) * art), color)

## Short directional spirit wave matching the authoritative cone, wall-clipped.
static func wave(canvas: CanvasItem, at: Vector2, radius: float, angle: float, arc: float, progress: float, art: float, renderer: RefCounted) -> void:
	var paint = preload("res://src/vfx/pixel_paint.gd")
	var pal = preload("res://src/vfx/talent_palette.gd")
	var colors: Array = pal.ramp("soul")
	var edge := radius * sqrt(clampf(progress, 0.0, 1.0))
	var fade := 1.0 - smoothstep(0.65, 1.0, progress)
	for ray in range(19):
		var direction := Vector2.from_angle(angle + (float(ray) / 18.0 - 0.5) * arc)
		var limit := radius
		var distance := 0.0
		while distance < radius:
			distance = minf(radius, distance + art)
			if not renderer.open(at + direction * distance):
				limit = maxf(0.0, distance - art)
				break
		for depth in range(4):
			var reach := maxf(0.0, edge - depth * art * 2.0)
			if reach > limit: continue
			var p := at + direction * reach
			paint.cell(canvas, paint.at(p, art), Color(colors[3 if depth == 0 else 2 if depth < 3 else 1], fade), art)
