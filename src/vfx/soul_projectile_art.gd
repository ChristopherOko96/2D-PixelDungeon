extends RefCounted
## Approved four-part spirit cutouts form the spell itself. The head leads,
## delayed tail bones shed fragments; charge and impact use continuous curves.
const Spirit = preload("res://src/rig/soul_spirit_rig.gd")
const Fragments = preload("res://src/vfx/soul_fragments.gd")
const PALETTE := [Color("253b51"), Color("3a7289"), Color("65b7b5"), Color("a4e9cf"), Color("e3ffe5")]

static func _ghost(canvas: CanvasItem, at: Vector2, ground: Vector2, aim: Vector2, size: float, age: float, alpha: float, seed: float, renderer: RefCounted) -> void:
	var parts := Spirit.draw_parts(at + Vector2(0, 31.0 * size), size, age, alpha, seed)
	var rotation := Transform2D(aim.angle() + PI * 0.5, Vector2.ZERO)
	var around := Transform2D(0.0, at) * rotation * Transform2D(0.0, -at)
	for part: Dictionary in parts: part.transform = around * Transform2D(part.transform)
	renderer.draw_external_rig(canvas, parts, ground)

## A readable spirit head, articulated shedding tail and two charged satellites.
static func flight(canvas: CanvasItem, shot: Dictionary, clock: float, art: float, lift: Vector2, renderer: RefCounted) -> void:
	var at := Vector2(shot.x, shot.y)
	var ground := at + lift
	var aim := Vector2(shot.get("vx", 1.0), shot.get("vy", 0.0)).normalized()
	var power := clampf(float(shot.get("charge", 0.0)), 0.0, 1.0)
	var size := art * (0.46 + power * 0.55)
	_ghost(canvas, at, ground, aim, size, clock, 1.0, 0.0, renderer)
	if str(shot.talent) == "soul_9" and power > 0.05:
		for i in range(2):
			var phase := clock * 3.0 + i * PI
			var offset := -aim * art * 10.0 + aim.orthogonal() * sin(phase) * art * (4.0 + power * 6.0)
			_ghost(canvas, at + offset, ground + offset, aim, size * 0.45, clock + i * 0.7, power * 0.85, float(i) * 0.5, renderer)

## Souls tighten around the casting hand; the small bar shows paid power.
static func charge(canvas: CanvasItem, state: Dictionary, clock: float, art: float, renderer: RefCounted) -> void:
	var ground := Vector2(state.x, state.y)
	var aim := Vector2(state.ax, state.ay).normalized()
	var power := float(state.power)
	var hand := ground - Vector2(0, 13.0 * art) + aim * art * 10.0
	for i in range(3):
		var angle := clock * 2.0 + i * TAU / 3.0
		var radius := art * (12.0 - power * 5.0)
		var offset := Vector2.from_angle(angle) * radius
		_ghost(canvas, hand + offset, ground, -offset.normalized(), art * (0.20 + power * 0.16), clock + i, 0.7 + power * 0.3, float(i) / 3.0, renderer)
	for i in range(20):
		var p := fposmod(clock * 0.55 + i * 0.618034, 1.0)
		var at := hand + Vector2.from_angle(i * 2.39996 + clock) * (1.0 - p) * art * (18.0 + power * 8.0)
		canvas.draw_rect(Rect2(at, Vector2.ONE * art), Color(PALETTE[2 + i % 3], sin(p * PI)))
	canvas.draw_rect(Rect2(ground + Vector2(-12, 8) * art, Vector2(24, 2) * art), PALETTE[0])
	canvas.draw_rect(Rect2(ground + Vector2(-12, 8) * art, Vector2(24.0 * power, 2) * art), PALETTE[3])

## Wall-clipped radial fragments and escaping articulated souls, not a second
## damaging field. The host supplies one exact point for every contact.
static func impact(canvas: CanvasItem, event: Dictionary, progress: float, clock: float, art: float, renderer: RefCounted) -> void:
	Spirit.prepare()
	var at := Vector2(event.x, event.y)
	var p := clampf(progress, 0.0, 1.0)
	var radius := float(event.r)
	var fade := 1.0 - smoothstep(0.35, 1.0, p)
	var samples: Array = []
	for i in range(42):
		var angle := i * 2.39996
		var speed := 0.4 + fposmod(i * 0.618034, 1.0) * 0.6
		var offset := Vector2.from_angle(angle) * radius * speed * (1.0 - pow(1.0 - p, 3.0))
		var point := at + offset
		if not renderer.open(point): continue
		canvas.draw_rect(Rect2(point, Vector2.ONE * art * (2 if i % 5 == 0 else 1)), Color(PALETTE[2 + i % 3], fade))
		samples.append({"at": point - Vector2(0, sin(p * PI) * radius * 0.4), "alpha": fade * 0.6})
	renderer.draw_external_rig(canvas, Fragments.mote_parts(samples, art, 1.0), at)
	var count := 3 if str(event.talent) == "soul_9" else 2
	for i in range(count):
		var angle := i * TAU / count + float(event.id)
		var point := at + Vector2.from_angle(angle) * radius * p * 0.6
		if not renderer.open(point): continue
		_ghost(canvas, point - Vector2(0, p * art * 13.0), point, Vector2.UP, art * (0.3 + float(event.get("charge", 0.0)) * 0.2), clock + i, fade, float(i) / count, renderer)
