extends RefCounted
## Shared soul-field overlay: individual cutout rigs and buoyant particles.
## The approved 24-frame source is retained; its eye pixels stay dark.
const SOURCE := "res://assets/vfx/soul_field/smooth_sheet_24.png"
const FRAME_SECONDS := 0.055
const COUNT := 24
const COLUMNS := 6
const ROWS := 4
const CELL := 256
const ANCHOR := Vector2(128, 180)
const FIELD_HALF_WIDTH := 112.0
const SpiritRig = preload("res://src/rig/soul_spirit_rig.gd")
const Fragments = preload("res://src/vfx/soul_fragments.gd")
static var _frames: Array[Texture2D] = []
static var _ghost_frames: Array[Texture2D] = []
static var _single_ghost: Texture2D

## Frame selected by authoritative zone age; late snapshots do not restart it.
static func frame_index(age: float) -> int:
	return posmod(int(floor(maxf(0.0, age) / FRAME_SECONDS)), COUNT)

## Cached native source frames with background alpha. No runtime regeneration.
static func prepare() -> void:
	if not _frames.is_empty(): return
	var texture := load(SOURCE) as Texture2D
	var source := texture.get_image() if texture != null else null
	if source == null or source.get_size() != Vector2i(CELL * COLUMNS, CELL * ROWS): return
	for index in range(COUNT):
		var image := source.get_region(Rect2i((index % COLUMNS) * CELL, (index / COLUMNS) * CELL, CELL, CELL))
		image.convert(Image.FORMAT_RGBA8)
		var queue: Array[Vector2i] = []
		var visited := PackedByteArray()
		visited.resize(CELL * CELL)
		for n in range(CELL):
			queue.append(Vector2i(n, 0))
			queue.append(Vector2i(n, CELL - 1))
			queue.append(Vector2i(0, n))
			queue.append(Vector2i(CELL - 1, n))
		var cursor := 0
		while cursor < queue.size():
			var p := queue[cursor]
			cursor += 1
			if p.x < 0 or p.y < 0 or p.x >= CELL or p.y >= CELL: continue
			var offset := p.y * CELL + p.x
			if visited[offset]: continue
			visited[offset] = 1
			var color := image.get_pixelv(p)
			if not backdrop(color): continue
			image.set_pixelv(p, Color.TRANSPARENT)
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: queue.append(p + step)
		_frames.append(ImageTexture.create_from_image(image))
		var ghosts := image.duplicate() as Image
		# The generated field's upper edge changes per frame. A fixed crop left
		# its horizontal rune band behind, creating a second surface in the game.
		var cut := CELL
		for y in range(96, CELL):
			var occupied := 0
			for x in range(CELL):
				if image.get_pixel(x, y).a > 0.0: occupied += 1
			if occupied >= 64:
				cut = maxi(0, y - 3)
				break
		if cut < CELL: ghosts.fill_rect(Rect2i(0, cut, CELL, CELL - cut), Color.TRANSPARENT)
		_ghost_frames.append(ImageTexture.create_from_image(ghosts))
	_single_ghost = ImageTexture.create_from_image(_frames[0].get_image().get_region(Rect2i(122, 44, 42, 86)))
	SpiritRig.prepare()

## Only the dark almost-neutral backdrop qualifies, never teal souls or violet ground.
static func backdrop(color: Color) -> bool:
	var high := maxf(color.r, maxf(color.g, color.b))
	var low := minf(color.r, minf(color.g, color.b))
	return high < 0.17 and high - low < 0.065

## Live pool overlay uses independently rising rigs. Full source-sheet mode is
## retained for historical previews; field geometry always remains host-owned.
static func draw(canvas: CanvasItem, at: Vector2, radius: float, age: float, renderer: RefCounted = null, key: String = "soul_field", ghosts_only: bool = false, opacity: float = 1.0, cfg: Dictionary = {}) -> void:
	if _frames.size() != COUNT: return
	var scale := radius / FIELD_HALF_WIDTH
	var frames := _ghost_frames if ghosts_only else _frames
	if ghosts_only:
		var ghosts: Array = SpiritRig.field_samples(at, radius, age, cfg)
		ghosts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.base).y < Vector2(b.base).y)
		_draw_parts(canvas, Fragments.mote_parts(mote_samples(at, radius, age, cfg), maxf(1.0, radius / 72.0), opacity), at, renderer)
		for ghost: Dictionary in ghosts:
			var parts := SpiritRig.draw_parts(ghost.at, float(ghost.scale), age, float(ghost.alpha) * opacity, float(ghost.seed), float(ghost.phase), cfg)
			_draw_parts(canvas, parts, ghost.base, renderer)
		return
	if renderer != null:
		renderer.draw_external_frame(canvas, key, frames[frame_index(age)], at, ANCHOR, scale)
		return
	canvas.draw_texture_rect(frames[frame_index(age)], Rect2((at - ANCHOR * scale).round(), Vector2.ONE * CELL * scale), false)

## A spirit from the approved art, used for the host-authorized grasp animation.
static func draw_spirit(canvas: CanvasItem, at: Vector2, art: float, opacity: float, age: float = 0.0, renderer: RefCounted = null, cfg: Dictionary = {}) -> void:
	if opacity <= 0.0: return
	var scale := art * 0.5
	var feet := at + Vector2(0, 19) * scale
	_draw_parts(canvas, SpiritRig.draw_parts(feet, scale, age, opacity, 0.0, 1.0, cfg), at, renderer)

## Small buoyant field particles, born on the existing material and faded
## before their cycle restarts. No new surface, collider or gameplay state.
static func mote_samples(at: Vector2, radius: float, age: float, cfg: Dictionary = {}) -> Array:
	var result: Array = []
	var count := clampi(int(cfg.get("field_mote_count", 42)), 0, 64)
	var cycle := maxf(0.5, float(cfg.get("field_mote_cycle", 2.6)))
	for i in range(count):
		var seed := fposmod(float(i) * 0.6180339, 1.0)
		var p := fposmod(maxf(0.0, age) / cycle + seed, 1.0)
		var angle := float(i) * 2.39996 + age * 0.12
		var r := radius * sqrt(fposmod(float(i) * 0.754877 + 0.1, 1.0)) * 0.82
		var base := at + Vector2(cos(angle) * r, sin(angle) * r * 0.58)
		result.append({"at": base + Vector2(sin(p * TAU + seed) * radius * 0.035, -p * radius * float(cfg.get("field_mote_rise", 0.42))),
			"alpha": smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.5, 1.0, p)) * 0.7 * smoothstep(0.0, 0.3, age), "size": 1.5 if i % 9 == 0 else 1.0})
	return result

## Existing grasp paths can shed the same little pixels as the field surface.
static func draw_motes(canvas: CanvasItem, samples: Array, ground: Vector2, art: float, opacity: float, renderer: RefCounted = null) -> void:
	SpiritRig.prepare()
	_draw_parts(canvas, Fragments.mote_parts(samples, art, opacity), ground, renderer)

static func _draw_parts(canvas: CanvasItem, parts: Array, ground: Vector2, renderer: RefCounted) -> void:
	if renderer != null:
		renderer.draw_external_rig(canvas, parts, ground)
		return
	for part: Dictionary in parts:
		canvas.draw_set_transform_matrix(part.transform)
		canvas.draw_texture(part.texture, Vector2.ZERO, part.tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
