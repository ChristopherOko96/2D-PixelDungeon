extends RefCounted
## Pooled pixel particles and floor stains for the dungeon view. Purely visual:
## bursts outlive the enemy that caused them, and stains stay until the room
## changes. Drawn by the owning CanvasItem in two passes (stains under actors,
## particles over them).

const MAX_PARTICLES := 420
const MAX_STAINS := 48

var _particles: Array[Dictionary] = []
var _stains: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1


## Throws `count` square particles from `origin`. `direction` biases the spread
## (Vector2.ZERO = all around); `drag` slows them like debris on a stone floor.
func burst(origin: Vector2, color: Color, count: int, speed: float, life: float, direction: Vector2 = Vector2.ZERO, spread: float = PI, size: float = 3.0, drag: float = 5.0) -> void:
	var base_angle: float = direction.angle() if direction != Vector2.ZERO else 0.0
	var arc: float = spread if direction != Vector2.ZERO else PI
	for i in range(count):
		if _particles.size() >= MAX_PARTICLES:
			_particles.pop_front()
		var angle: float = base_angle + _rng.randf_range(-arc, arc)
		var velocity := Vector2.RIGHT.rotated(angle) * speed * _rng.randf_range(0.35, 1.0)
		var shade: float = _rng.randf_range(0.75, 1.1)
		_particles.append({"pos": origin, "vel": velocity, "life": life * _rng.randf_range(0.6, 1.0), "max_life": life,
			"color": Color(color.r * shade, color.g * shade, color.b * shade, color.a), "size": maxf(1.0, roundf(size * _rng.randf_range(0.6, 1.2))), "drag": drag})


## Leaves a splat of a few overlapping rectangles that stays until clear().
func stain(origin: Vector2, color: Color, radius: float) -> void:
	if _stains.size() >= MAX_STAINS:
		_stains.pop_front()
	var blobs: Array[Rect2] = []
	for i in range(5):
		var offset := Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius * 0.5, radius * 0.5))
		var extent := Vector2(_rng.randf_range(radius * 0.4, radius), _rng.randf_range(radius * 0.25, radius * 0.5)).round()
		blobs.append(Rect2((origin + offset - extent * 0.5).round(), extent))
	_stains.append({"color": Color(color.darkened(0.35), 0.55), "blobs": blobs})


func clear() -> void:
	_particles.clear()
	_stains.clear()


func update(delta: float) -> void:
	for i in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[i]
		particle.life -= delta
		if particle.life <= 0.0:
			_particles.remove_at(i)
			continue
		particle.pos += particle.vel * delta
		particle.vel *= maxf(0.0, 1.0 - particle.drag * delta)


func draw_stains(canvas: CanvasItem) -> void:
	for stain_value in _stains:
		for blob: Rect2 in stain_value.blobs:
			canvas.draw_rect(blob, stain_value.color)


func draw_particles(canvas: CanvasItem) -> void:
	for particle in _particles:
		var fade: float = clampf(particle.life / (particle.max_life * 0.5), 0.0, 1.0)
		var size: float = particle.size
		canvas.draw_rect(Rect2((particle.pos - Vector2(size, size) * 0.5).round(), Vector2(size, size)), Color(particle.color, particle.color.a * fade))


func count() -> int:
	return _particles.size()
