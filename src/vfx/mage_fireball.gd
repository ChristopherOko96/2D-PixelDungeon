extends RefCounted
## The approved fireball: fixed-size flight, pixel explosion and six staff poses.
## Presentation only; the host supplies event age, locked aim and windup.
const Paint = preload("res://src/vfx/pixel_paint.gd")
const COLORS := [Color("c43c20"), Color("f56819"), Color("ffae28"), Color("fff2ad")]
static var _frames: Dictionary = {}

## Pose in native hero pixels. The grip never changes sides during a cast.
static func pose(age: float, windup: float, aim: Vector2) -> Dictionary:
	var side := -1.0 if aim.x < -0.1 else 1.0
	var release := clampf((age - windup) / 0.28, 0.0, 1.0)
	var charge := clampf(age / maxf(0.01, windup), 0.0, 1.0)
	var push := sin(release * PI) if age >= windup else -sin(charge * PI) * 0.35
	var tilt := lerpf(-0.45 * side, wrapf(aim.angle() + PI * 0.5, -PI, PI), smoothstep(0.65, 1.0, charge))
	if age >= windup: tilt = lerp_angle(wrapf(aim.angle() + PI * 0.5, -PI, PI), 0.12 * side, smoothstep(0.1, 1.0, release))
	return {"side": side, "hand": Vector2(5.0 * side + aim.x * push * 2.0, -2.5 * sin(charge * PI * 0.5) * (1.0 - release)),
		"tilt": tilt, "body": aim * push, "charge": charge if age < windup else 0.0,
		"flash": 1.0 - clampf((age - windup) / 0.09, 0.0, 1.0) if age >= windup else 0.0}

## Native cells; the flight core has exactly the same footprint in all four frames.
static func cells(frame: int, impact: bool = false) -> Array:
	var out: Array = []
	var radius: int = [3, 8, 5, 0][clampi(frame, 0, 3)] if impact else 5
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var d := x * x + y * y
			if d > radius * radius: continue
			var shade := 3 if d <= radius * radius * 0.22 else 2 if d <= radius * radius * 0.5 else 1 if d <= radius * radius * 0.8 else 0
			out.append(Vector2i(x, y))
			out.append(COLORS[shade])
	if not impact:
		for x in range(-12, -5):
			var half := 1 if x < -8 else 2
			for y in range(-half, half + 1):
				if posmod(x + y + frame, 4) == 0: continue
				out.append(Vector2i(x, y))
				out.append(COLORS[1 if x < -8 else 2])
	else:
		for k in range(8):
			var q := Vector2i((Vector2.from_angle(k * TAU / 8.0 + 0.2) * (4 + frame * 3)).round())
			if frame == 3 and k % 2 == 0: continue
			out.append(q)
			out.append(COLORS[1 if frame < 2 else 0])
	return out

## Four cached native frames; the sprite core never scales with flight time.
static func draw(canvas: CanvasItem, at: Vector2, aim: Vector2, art: float, clock: float, impact: bool = false, progress: float = 0.0) -> void:
	var index := mini(3, int(progress * 4.0)) if impact else posmod(int(clock * 12.0), 4)
	var key := "%s%d" % ["impact" if impact else "flight", index]
	if not _frames.has(key):
		# Bake local pixels without world clipping; the caller clips the transformed draw.
		var previous := Paint.clip
		Paint.clip = Callable()
		var pixels := cells(index, impact)
		_frames[key] = Paint.bake(pixels, 1.0)
		_frames[key].pixels = pixels
		Paint.clip = previous
	if Paint.clip.is_valid():
		var world: Dictionary = {}
		var origin := (at / art).round()
		var pixels: Array = _frames[key].pixels
		for i in range(0, pixels.size(), 2):
			var local := Vector2(pixels[i])
			if not impact: local = local.rotated(aim.angle())
			world[Vector2i((origin + local).round())] = pixels[i + 1]
		Paint.paint(canvas, world, art)
		return
	# Flight is snapped in world space; rotating the sprite leaves nearest filtering intact.
	canvas.draw_set_transform((at / art).round() * art, 0.0 if impact else aim.angle(), Vector2.ONE)
	Paint.draw_baked(canvas, _frames[key], art)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
