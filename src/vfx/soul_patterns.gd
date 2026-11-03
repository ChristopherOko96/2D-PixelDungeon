extends RefCounted
## Detailed soul shock waves: shaded moving bands, thin highlights and rune breaks.
## Same opaque material treatment as pools; no gameplay or damage changes.
const Paint = preload("res://src/vfx/pixel_paint.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")
const Field = preload("res://src/vfx/soul_field.gd")
static var _waves: Dictionary = {}

## Native shaded wave pixels, cached into a texture by wave().
static func wave_cells(radius: int, phase: int, heavy: bool = false) -> Array:
	var out: Array = []
	var colors := Pal.ramp("soul")
	var p := (phase + 0.5) / 24.0
	var edge := maxf(2.0, radius * (0.12 + 0.88 * sqrt(p)))
	var width := 8.0 if not heavy else 12.0
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var v := Vector2(x, y)
			var d := v.length()
			var angle := v.angle()
			var ripple := sin(angle * 9.0 + p * TAU) * 0.8
			var depth := edge + ripple - d
			if depth < 0.0 or depth > width: continue
			# Lit crown, dark lip, veined body. Sparse highlights preserve the floor.
			var shade := 1 if depth < 1.0 or depth > width - 1.0 else 2
			if depth > 1.0 and depth < 2.0: shade = 3
			if posmod(x * 13 + y * 7 + phase, 23) == 0 and depth > 1.0: shade = 4
			if sin(angle * 18.0 + p * TAU) > 0.8 and depth > 2.0: shade = 1
			elif depth > 2.0 and sin(angle * 12.0 + depth * 1.6 - p * TAU * 2.0) > 0.2: shade = 3
			out.append(Vector2i(x, y))
			out.append(colors[shade])
	return out

## A cached 24-phase wave, clipped with the existing effect-sheet wall renderer.
static func wave(canvas: CanvasItem, at: Vector2, radius: float, p: float, art: float, sprites: RefCounted, heavy: bool = false) -> void:
	var phase := clampi(int(p * 24.0), 0, 23)
	var cells := maxi(4, roundi(radius / art))
	var key := "%d:%d:%s" % [cells, phase, heavy]
	if not _waves.has(key):
		if _waves.size() > 192: _waves.clear()
		var previous := Paint.clip
		Paint.clip = Callable()
		_waves[key] = Paint.bake(wave_cells(cells, phase, heavy), 1.0)
		Paint.clip = previous
	var baked: Dictionary = _waves[key]
	if baked.is_empty(): return
	sprites.draw_external_frame(canvas, "soul_wave_" + key, baked.tex, at, -Vector2(baked.at), art)

## Spirits approach, spiral around a target, then unravel and fade continuously.
static func grasp(canvas: CanvasItem, at: Vector2, origin: Vector2, radius: float, progress: float, art: float, turns: float = 0.55, renderer: RefCounted = null, cfg: Dictionary = {}) -> void:
	var p := clampf(progress, 0.0, 1.0)
	var approach := smoothstep(0.0, 0.28, p)
	var fade := smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.62, 1.0, p))
	var r := clampf(radius + 5.0 * art, 8.0 * art, 26.0 * art)
	for ghost in range(2):
		var angle := p * TAU * turns + ghost * PI
		var orbit := at + Vector2(cos(angle) * r, sin(angle) * r * 0.38 - 7.0 * art)
		var head := (origin - Vector2(0, 8.0 * art)).lerp(orbit, approach)
		var tail: Array = []
		for part in range(13):
			var a := angle - part * 0.14
			var target := at + Vector2(cos(a) * r, sin(a) * r * 0.38 - 7.0 * art)
			tail.append({"at": origin.lerp(target, approach), "alpha": pow(1.0 - float(part) / 13.0, 1.4), "size": 1.5 - float(part) / 16.0})
		Field.draw_motes(canvas, tail, at, art, fade, renderer)
		Field.draw_spirit(canvas, head, art, fade, p * 1.2 + ghost * 0.4, renderer, cfg)
