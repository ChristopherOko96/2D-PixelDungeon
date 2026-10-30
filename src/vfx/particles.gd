extends RefCounted
## Pixel particles with simple physics, and the room's lasting floor marks, in
## the spirit of falling-sand games. A particle flies in the floor plane with a
## height above it: gravity pulls it down, it bounces on the floor and off walls
## (the room's floor cells; it never passes through a wall), and debris that
## comes to rest settles into the floor as pixels that stay until the room
## changes. Splats, drips and cracks are painted into the same pixel layer at
## the 0x72 art scale (2 world px per pixel): liquids only on the floor, cracks
## on the wall that was struck. Physics and modes: assets/data/vfx_particles.json;
## liquids: vfx_gore.json. Drawn by the owning CanvasItem in two passes (marks
## under the actors, particles over them). Purely visual; every player's
## client runs its own, nothing is sent over the network.
##
## The floor lives on (Noita stage 1): blasts lift loose pixels again (kick),
## liquid splats keep creeping outwards and then dry darker, fire leaves
## glowing embers that smoke and turn to soot, frost melts to water that dries.

const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const Glow = preload("res://src/vfx/glow.gd")
const DATA_PATH := "res://assets/data/vfx_particles.json"
## World px per art pixel.
const PIXEL := 2.0
## Art px per side of one floor-mark texture.
const CHUNK := 128
## Art px per room cell (32 world px).
const CELL_ART := 16
const MAX_PARTICLES := 600

## Room key of the floor cells in use (the view sets the layout when it changes).
var layout_key := ""
var _particles: Array[Dictionary] = []
## Floor-mark textures: Vector2i chunk -> {image, texture, dirty}.
var _chunks: Dictionary = {}
var _marks := 0
var _walkable: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _data: Dictionary = {}
static var _cached: Dictionary = {}
## Seconds since the room began (for melting and drying).
var _time := 0.0
## Loose debris pixels on the floor (Vector2i art px -> true); blasts lift them.
var _loose: Dictionary = {}
## Creeping liquid pools: {center, color, frontier, budget, carry, dir, reach, scan, done}.
var _pools: Array[Dictionary] = []
## Glowing embers on the floor: {art, life, max, smoke}.
var _embers: Array[Dictionary] = []
## Frost pixels waiting to melt and water pixels waiting to dry: [art, due time].
var _frost: Array = []
var _frost_head := 0
var _water: Array = []
var _water_head := 0
## Frost pixels on the floor (art px -> their colour when frozen) and water pixels.
var _frozen: Dictionary = {}
var _wet: Dictionary = {}
## Floor cells of a liquid that swallows what lands in it (set_sink).
var _sink: Dictionary = {}
const STEPS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


func _init() -> void:
	_rng.seed = 1
	_data = settings()


## vfx_particles.json, cached.
static func settings() -> Dictionary:
	if _cached.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_cached = parsed if parsed is Dictionary else {"modes": {}}
	return _cached


## The room whose floor cells bound the particles and marks. Keeps the marks
## (a broken wall changes the cells, not the room).
func set_layout(layout: Dictionary, key: String) -> void:
	_walkable = FxSprites.walkable_cells(layout)
	layout_key = key


## Sets the floor cells directly (Vector2i, 32 px -> true), for worlds without a
## crypt room layout (the story worlds, src/hero/story_skill_fx.gd).
func set_walkable(cells: Dictionary, key: String) -> void:
	_walkable = cells
	layout_key = key


## True when `point` (world px) is inside a wall. Without a room every point is open.
func solid(point: Vector2) -> bool:
	if _walkable.is_empty(): return false
	return not _walkable.has(Vector2i(floori(point.x / 32.0), floori(point.y / 32.0)))


## Throws `count` square particles from `origin` (where they are seen, `height`
## px above the floor point under it; -1 = spawn_height). `direction` biases the
## spread in the floor plane (Vector2.ZERO = all around); `drag` slows them.
## `mode` is one of vfx_particles.json "modes": debris lands and stays as floor
## pixels, spark and ember glow and fade, dust floats and fades.
func burst(origin: Vector2, color: Color, count: int, speed: float, life: float, direction: Vector2 = Vector2.ZERO, spread: float = PI, size: float = 3.0, drag: float = 5.0, mode: String = "debris", height: float = -1.0) -> void:
	var base_angle: float = direction.angle() if direction != Vector2.ZERO else 0.0
	var arc: float = spread if direction != Vector2.ZERO else PI
	var lift: Array = _mode(mode).get("lift", [0, 0])
	for i in range(count):
		var angle: float = base_angle + _rng.randf_range(-arc, arc)
		var velocity := Vector2.RIGHT.rotated(angle) * speed * _rng.randf_range(0.35, 1.0)
		var shade: float = _rng.randf_range(0.75, 1.1)
		emit(origin, velocity, Color(color.r * shade, color.g * shade, color.b * shade, color.a), life * _rng.randf_range(0.6, 1.0), mode, size * _rng.randf_range(0.6, 1.2), height, _rng.randf_range(float(lift[0]), float(lift[1])), drag)


## One particle seen at `origin`, `height` px above the floor (-1 = spawn_height),
## moving with `velocity` in the floor plane and `lift` px/s upwards. Returns
## the particle (a "glut" one may carry "ember_life" and "soot" for its landing).
func emit(origin: Vector2, velocity: Vector2, color: Color, life: float, mode: String = "debris", size: float = 2.0, height: float = -1.0, lift: float = 0.0, drag: float = 5.0) -> Dictionary:
	var settings_for_mode: Dictionary = _mode(mode)
	if _particles.size() >= int(_data.get("max_particles", MAX_PARTICLES)): _evict()
	var lifted := height if height >= 0.0 else float(_data.get("spawn_height", 10))
	var ground := origin + Vector2(0, lifted)
	# A floor point inside a wall (a burst at a north-facing wall): start on the floor.
	if lifted > 0.0 and solid(ground) and not solid(origin):
		ground = origin
		lifted = 0.0
	var gravity: float = float(_data.get("gravity", 620)) * float(settings_for_mode.get("gravity", 1.0))
	var particle := {"pos": ground, "z": lifted, "vz": lift if gravity != 0.0 else 0.0, "vel": velocity,
		"life": life, "max_life": maxf(life, 0.01), "color": color, "size": maxf(PIXEL, roundf(size / PIXEL) * PIXEL), "drag": drag,
		"gravity": gravity, "settle": bool(settings_for_mode.get("settle", false)), "glow": bool(settings_for_mode.get("glow", false)),
		"fade": bool(settings_for_mode.get("fade", true)), "free": solid(ground), "mode": mode,
		"glow_a": float(settings_for_mode.get("glow_alpha", 0.32))}
	_particles.append(particle)
	return particle


func _mode(mode: String) -> Dictionary:
	return _data.get("modes", {}).get(mode, {"gravity": 1.0, "lift": [40, 150], "settle": true, "glow": false, "fade": false})


## Leaves a splat of a few overlapping rectangles on the floor.
func stain(origin: Vector2, color: Color, radius: float) -> void:
	_marks += 1
	var tint := Color(color.darkened(0.35), 0.55)
	for i in range(5):
		var offset := Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius * 0.5, radius * 0.5))
		var extent := Vector2(_rng.randf_range(radius * 0.4, radius), _rng.randf_range(radius * 0.25, radius * 0.5))
		var corner := _art(origin + offset - extent * 0.5)
		var size := Vector2i(maxi(1, roundi(extent.x / PIXEL)), maxi(1, roundi(extent.y / PIXEL)))
		for row in range(size.y): _span(corner.y + row, corner.x, corner.x + size.x - 1, tint, true)


## A liquid splat on the floor: one pool, smaller blobs around it, and drops
## thrown along `direction` (the hit's direction). `alpha` is the pool opacity.
func splat(origin: Vector2, color: Color, alpha: float, radius: float, direction: Vector2 = Vector2.ZERO) -> void:
	if radius <= 0.0: return
	_marks += 1
	var tint := Color(color, alpha)
	_disc(origin, radius * _rng.randf_range(0.7, 1.0), tint)
	for i in range(3):
		_disc(origin + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius) * 0.6), radius * _rng.randf_range(0.35, 0.6), tint)
	var along: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.from_angle(_rng.randf() * TAU)
	for i in range(5):
		var spot := origin + along.rotated(_rng.randf_range(-0.5, 0.5)) * radius * _rng.randf_range(1.1, 2.6)
		_disc(spot, maxf(PIXEL, radius * _rng.randf_range(0.12, 0.3)), tint)
	_add_pool(origin, tint, radius, direction)


## One drop of a drip trail behind a wounded enemy.
func drip(origin: Vector2, color: Color, alpha: float, size: float) -> void:
	_marks += 1
	var tint := Color(color, alpha)
	_disc(origin, maxf(PIXEL, size), tint)
	_disc(origin + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-2.0, 2.0)), maxf(PIXEL * 0.5, size * 0.5), tint)


## A small crack where something struck a wall: jagged dark lines spreading
## from the impact into the wall, away from the floor side.
func crack(origin: Vector2, normal: Vector2) -> void:
	_marks += 1
	var tint := Color(0.08, 0.06, 0.06, 0.75)
	for branch in range(3):
		var direction := (-normal).rotated(_rng.randf_range(-1.3, 1.3))
		var point := origin
		for step in range(3):
			var next := point + direction.rotated(_rng.randf_range(-0.5, 0.5)) * _rng.randf_range(2.0, 4.0)
			_line(point, next, tint)
			point = next


## Scatters `count` single floor pixels of `color` within `radius` of `point`,
## each a little fainter or stronger: frost crystals and soot under the
## Photoneneis. Repeated scatters build up like settling dust.
func scatter(point: Vector2, color: Color, radius: float, count: int) -> void:
	_marks += 1
	for i in range(count):
		var offset := Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf())
		offset.y *= 0.75
		_blend(_art(point + offset), Color(color, color.a * _rng.randf_range(0.5, 1.0)), true)


## Frost crystals: `count` floor pixels of `color` within `radius` of `point`
## that melt to water after a while (vfx_particles.json "frost").
func frost(point: Vector2, radius: float, count: int, color: Color) -> void:
	_marks += 1
	for i in range(count):
		var offset := Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf())
		offset.y *= 0.75
		var art := _art(point + offset)
		if art.x < 0 or art.y < 0 or solid(_world(art)): continue
		_blend(art, Color(color, color.a * _rng.randf_range(0.5, 1.0)), false)
		_freeze(art)


## Glowing embers left by fire: `count` floor pixels within `radius` of `point`
## that flicker, cool from yellow to dark red, give off smoke and leave soot.
func embers(point: Vector2, radius: float, count: int) -> void:
	var settings_for_embers: Dictionary = _data.get("ember", {})
	var life: Array = settings_for_embers.get("life", [1.5, 4.0])
	for i in range(count):
		var offset := Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf())
		offset.y *= 0.75
		var art := _art(point + offset)
		if art.x < 0 or art.y < 0 or solid(_world(art)): continue
		if _embers.size() >= int(settings_for_embers.get("max", 500)): _cool(_embers.pop_front())
		var span := _rng.randf_range(float(life[0]), float(life[1]))
		_embers.append({"art": art, "life": span, "max": span, "smoke": _rng.randf()})


## `count` puffs of smoke rising from `point` (spread `radius` px).
func smoke(point: Vector2, count: int, radius: float = 6.0) -> void:
	var color := Color(str(_data.get("smoke_color", "2e2a2c")), 0.55)
	var lift: Array = _mode("smoke").get("lift", [10, 30])
	for i in range(count):
		var spot := point + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius) * 0.6)
		emit(spot, Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-10.0, 4.0)), Color(color, color.a * _rng.randf_range(0.6, 1.0)), _rng.randf_range(1.2, 2.2), "smoke", 4.0, 2.0, _rng.randf_range(float(lift[0]), float(lift[1])), 0.6)


## A blast at `point` lifts what lies on the floor within `radius`: every loose
## debris pixel flies off again, pools and stains splash apart a little.
## `strength` 1 is an ordinary explosion (vfx_particles.json "kick").
func kick(point: Vector2, radius: float, strength: float = 1.0) -> void:
	var settings_for_kick: Dictionary = _data.get("kick", {})
	var share := float(settings_for_kick.get("stain_share", 0.25))
	var limit := int(settings_for_kick.get("max_particles", 140))
	var lift: Array = settings_for_kick.get("lift", [60, 200])
	var speed := float(settings_for_kick.get("speed", 260)) * strength
	var middle := _art(point)
	var reach := maxi(1, int(radius / PIXEL))
	var thrown := 0
	for y in range(maxi(0, middle.y - reach), middle.y + reach + 1):
		for x in range(maxi(0, middle.x - reach), middle.x + reach + 1):
			var art := Vector2i(x, y)
			var offset := Vector2(art - middle)
			var distance := offset.length()
			if distance > float(reach): continue
			var key := Vector2i(x / CHUNK, y / CHUNK)
			if not _chunks.has(key): continue
			var local := art - key * CHUNK
			var color: Color = _chunks[key].image.get_pixelv(local)
			if color.a <= 0.05: continue
			var frozen := _frozen.has(art)
			if not _loose.has(art) and not frozen and _rng.randf() > share: continue
			if solid(_world(art)): continue
			_chunks[key].image.set_pixelv(local, Color(0, 0, 0, 0))
			_chunks[key].dirty = true
			_loose.erase(art)
			_frozen.erase(art)
			# Water splashes away; everything else flies.
			if _wet.has(art):
				_wet.erase(art)
				continue
			if thrown >= limit: continue
			thrown += 1
			var push := 1.0 - distance / float(reach + 1)
			var away := offset.normalized() if distance > 0.0 else Vector2.from_angle(_rng.randf() * TAU)
			# Frost stays frost when thrown, so it still melts where it lands.
			var mode := "frost" if frozen else "debris"
			emit(_world(art), away.rotated(_rng.randf_range(-0.4, 0.4)) * speed * push * _rng.randf_range(0.5, 1.0), Color(color, maxf(color.a, 0.85)), 0.8, mode, PIXEL, 0.0, _rng.randf_range(float(lift[0]), float(lift[1])) * push * strength, 3.0)


## A pressure front (a shockwave's ring, a scream's sound) running from `r0`
## to `r1` px around `origin`, within `arc` around `angle` (TAU: all round;
## `squash` < 1 flattens the ring's height, as the hell draws its rings) shoves
## the pixels it passes outward at about `speed` px/s: flying pixels are pushed
## along and hop, glowing embers on the floor lift and fly as glowing pixels
## that lie down again as embers further on, loose rubble hops along with it.
## At most `limit` floor pixels lift per call (vfx_particles.json "blow").
## Returns how many pixels it moved.
func blow(origin: Vector2, r0: float, r1: float, angle: float, arc: float, speed: float, squash: float = 1.0, limit: int = -1) -> int:
	if r1 <= r0 or speed <= 0.0: return 0
	var settings_for_blow: Dictionary = _data.get("blow", {})
	var hop: Array = settings_for_blow.get("hop", [30, 90])
	var cap: int = limit if limit >= 0 else int(settings_for_blow.get("max_lift", 60))
	var moved := 0
	# what flies already is shoved along, what lies on the floor hops
	for particle: Dictionary in _particles:
		var out := _front_dir(Vector2(particle.pos), origin, r0, r1, angle, arc, squash)
		if out == Vector2.ZERO: continue
		particle.vel = Vector2(particle.vel) * 0.35 + out * speed * _rng.randf_range(0.7, 1.1)
		if float(particle.gravity) > 0.0 and float(particle.z) <= 1.0:
			particle.vz = maxf(float(particle.vz), _rng.randf_range(float(hop[0]), float(hop[1])))
		moved += 1
	# glowing embers lift and fly on as glowing pixels (they lie down again as embers)
	var colors: Array = _data.get("ember", {}).get("colors", ["ffe08a", "ff8a2a", "a8361c"])
	var lifted := 0
	for index in range(_embers.size() - 1, -1, -1):
		if lifted >= cap: break
		var ember: Dictionary = _embers[index]
		var at := _world(ember.art)
		var out := _front_dir(at, origin, r0, r1, angle, arc, squash)
		if out == Vector2.ZERO: continue
		_embers.remove_at(index)
		lifted += 1
		var heat := float(ember.life) / float(ember.max)
		var flung := emit(at, out.rotated(_rng.randf_range(-0.3, 0.3)) * speed * _rng.randf_range(0.5, 1.0), Color(str(colors[0 if heat > 0.66 else 1 if heat > 0.33 else 2])),
			2.0, "glut", PIXEL, 0.0, _rng.randf_range(float(hop[0]), float(hop[1])), 2.0)
		flung.ember_life = float(ember.life)
		flung.ember_max = float(ember.max)
		flung.soot = float(ember.get("soot", 1.0))
	# loose rubble in the band hops along: row by row over the ring's band only
	var flat := maxf(0.05, squash)
	var middle := origin / PIXEL
	var rows := int(ceil(r1 * flat / PIXEL))
	for row in range(-rows, rows + 1):
		if lifted >= cap: break
		var y := floori(middle.y) + row
		if y < 0: continue
		var dy := (float(y) + 0.5 - middle.y) * PIXEL / flat
		if absf(dy) > r1: continue
		var outer := sqrt(r1 * r1 - dy * dy) / PIXEL
		var inner := sqrt(maxf(0.0, r0 * r0 - dy * dy)) / PIXEL if absf(dy) < r0 else 0.0
		for side: float in [-1.0, 1.0]:
			var from := floori(middle.x + side * inner) if side > 0.0 else floori(middle.x - outer)
			var to := floori(middle.x + outer) if side > 0.0 else floori(middle.x - inner)
			for x in range(maxi(0, from), to + 1):
				var art := Vector2i(x, y)
				if not _loose.has(art): continue
				var out := _front_dir(_world(art), origin, r0, r1, angle, arc, squash)
				if out == Vector2.ZERO: continue
				var key := Vector2i(x / CHUNK, y / CHUNK)
				if not _chunks.has(key): continue
				var local := art - key * CHUNK
				var color: Color = _chunks[key].image.get_pixelv(local)
				_chunks[key].image.set_pixelv(local, Color(0, 0, 0, 0))
				_chunks[key].dirty = true
				_loose.erase(art)
				var frozen := _frozen.has(art)
				_frozen.erase(art)
				if color.a <= 0.05: continue
				emit(_world(art), out.rotated(_rng.randf_range(-0.3, 0.3)) * speed * _rng.randf_range(0.4, 0.9), Color(color, maxf(color.a, 0.85)), 0.8,
					"frost" if frozen else "debris", PIXEL, 0.0, _rng.randf_range(float(hop[0]), float(hop[1])), 3.0)
				lifted += 1
				if lifted >= cap: break
	return moved + lifted


## The outward direction at `point` when it lies in a front's band (see blow), else zero.
func _front_dir(point: Vector2, origin: Vector2, r0: float, r1: float, angle: float, arc: float, squash: float) -> Vector2:
	var offset := point - origin
	var distance := Vector2(offset.x, offset.y / maxf(0.05, squash)).length()
	if distance < r0 or distance > r1 or distance <= 0.0: return Vector2.ZERO
	if arc < TAU and absf(wrapf(offset.angle() - angle, -PI, PI)) > arc * 0.5: return Vector2.ZERO
	return offset.normalized()


## Floor cells (32 px, like the walkable ones) of a liquid that swallows what
## lands in it (the hell's lava): debris and glowing pixels sink instead of
## settling there. Empty: nothing sinks.
func set_sink(cells: Dictionary) -> void:
	_sink = cells


## True when `point` lies over a sinking liquid (set_sink).
func sinks(point: Vector2) -> bool:
	return not _sink.is_empty() and _sink.has(Vector2i(floori(point.x / 32.0), floori(point.y / 32.0)))


## Removes every particle and floor mark (a new room).
func clear() -> void:
	_particles.clear()
	_chunks.clear()
	_marks = 0
	_time = 0.0
	_loose.clear()
	_pools.clear()
	_embers.clear()
	_frost.clear()
	_frost_head = 0
	_water.clear()
	_water_head = 0
	_frozen.clear()
	_wet.clear()


## Loose debris pixels lying on the floor (blasts can lift them).
func loose_count() -> int:
	return _loose.size()


## Liquid pools still creeping or waiting to dry.
func pool_count() -> int:
	return _pools.size()


## Embers still glowing on the floor.
func ember_count() -> int:
	return _embers.size()


## Floor marks painted since the room began (splats, drips, cracks, stains).
func stain_count() -> int:
	return _marks


## Painted floor-mark textures (for tests and the debug overlay).
func chunk_count() -> int:
	return _chunks.size()


## The floor pixel at `point` (world px); transparent when nothing lies there.
func mark_at(point: Vector2) -> Color:
	var art := _art(point)
	var key := Vector2i(floori(float(art.x) / CHUNK), floori(float(art.y) / CHUNK))
	if not _chunks.has(key): return Color(0, 0, 0, 0)
	return _chunks[key].image.get_pixelv(art - key * CHUNK)


func update(delta: float) -> void:
	_time += delta
	_spread_pools(delta)
	_burn_embers(delta)
	_melt()
	var settle_speed := float(_data.get("settle_speed", 12))
	for i in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[i]
		particle.life = float(particle.life) - delta
		var grounded: bool = float(particle.z) <= 0.0 and float(particle.vz) <= 0.0
		if bool(particle.settle):
			# Debris lives until it lies still on the floor, then becomes part of it.
			if grounded and (Vector2(particle.vel).length() < settle_speed or float(particle.life) <= 0.0):
				_settle(particle)
				_particles.remove_at(i)
				continue
			if float(particle.life) < -2.0:
				_particles.remove_at(i)
				continue
		elif float(particle.life) <= 0.0:
			_particles.remove_at(i)
			continue
		_move(particle, delta)


## Floor-plane motion with wall bounces, then height with gravity and floor bounces.
func _move(particle: Dictionary, delta: float) -> void:
	var position: Vector2 = particle.pos
	var velocity: Vector2 = particle.vel
	var next := position + velocity * delta
	if bool(particle.free):
		# Born inside a wall: it may leave, and walls count from then on.
		if not solid(next): particle.free = false
	elif solid(next):
		var keep := float(_data.get("wall_bounce", 0.4))
		if not solid(Vector2(next.x, position.y)):
			next = Vector2(next.x, position.y)
			velocity.y = -velocity.y * keep
		elif not solid(Vector2(position.x, next.y)):
			next = Vector2(position.x, next.y)
			velocity.x = -velocity.x * keep
		else:
			next = position
			velocity = -velocity * keep
	particle.pos = next
	var gravity := float(particle.gravity)
	if gravity != 0.0:
		particle.vz = float(particle.vz) - gravity * delta
		particle.z = float(particle.z) + float(particle.vz) * delta
		if gravity > 0.0 and float(particle.z) <= 0.0:
			particle.z = 0.0
			if float(particle.vz) < -float(_data.get("bounce_min", 70)):
				particle.vz = -float(particle.vz) * float(_data.get("bounce", 0.35))
				velocity *= 0.6
			else:
				particle.vz = 0.0
	var on_floor: bool = float(particle.z) <= 0.0 and float(particle.vz) == 0.0 and gravity > 0.0
	var drag := float(particle.drag) + (float(_data.get("ground_friction", 9)) if on_floor else 0.0)
	particle.vel = velocity * maxf(0.0, 1.0 - drag * delta)


## The oldest particle makes room: debris lands where it is, the rest vanishes.
func _evict() -> void:
	var oldest: Dictionary = _particles.pop_front()
	if bool(oldest.settle): _settle(oldest)


## A resting debris particle becomes loose floor pixels (only on the floor);
## settled frost melts later.
func _settle(particle: Dictionary) -> void:
	if bool(particle.free): return
	# what falls into a sinking liquid (lava) is gone
	if sinks(Vector2(particle.pos)): return
	# a glowing pixel lies down as an ember again, as hot as it still is
	if str(particle.get("mode", "")) == "glut":
		var settings_for_embers: Dictionary = _data.get("ember", {})
		var range_of_life: Array = settings_for_embers.get("life", [1.5, 4.0])
		var span := float(particle.get("ember_life", _rng.randf_range(float(range_of_life[0]), float(range_of_life[1]))))
		# a big drop lies as a little block of embers
		var side := maxi(1, roundi(float(particle.size) / PIXEL))
		var first := _art(Vector2(particle.pos)) - Vector2i(side / 2, side / 2)
		for y in range(side):
			for x in range(side):
				var spot := first + Vector2i(x, y)
				if spot.x < 0 or spot.y < 0 or solid(_world(spot)) or sinks(_world(spot)): continue
				if _embers.size() >= int(settings_for_embers.get("max", 500)): _cool(_embers.pop_front())
				var own := span * _rng.randf_range(0.8, 1.0)
				_embers.append({"art": spot, "life": own, "max": maxf(own, float(particle.get("ember_max", own))), "smoke": _rng.randf(), "soot": float(particle.get("soot", 1.0))})
		return
	var color: Color = particle.color
	var tint := Color(color.darkened(0.15), minf(0.95, color.a))
	var cells := maxi(1, roundi(float(particle.size) / PIXEL))
	var frozen: bool = str(particle.get("mode", "")) == "frost"
	# The pixel under the particle, grown up-left for bigger chunks.
	var corner := _art(Vector2(particle.pos)) - Vector2i(cells / 2, cells / 2)
	for y in range(cells):
		for x in range(cells):
			var art := corner + Vector2i(x, y)
			if art.x < 0 or art.y < 0 or solid(_world(art)): continue
			_blend(art, tint, false)
			_loose[art] = true
			if frozen: _freeze(art)


func draw_stains(canvas: CanvasItem) -> void:
	for key: Vector2i in _chunks:
		var chunk: Dictionary = _chunks[key]
		if bool(chunk.dirty):
			chunk.dirty = false
			if chunk.texture == null: chunk.texture = ImageTexture.create_from_image(chunk.image)
			else: chunk.texture.update(chunk.image)
		canvas.draw_texture_rect(chunk.texture, Rect2(Vector2(key * CHUNK) * PIXEL, Vector2(CHUNK, CHUNK) * PIXEL), false)
	# Embers flicker on the floor, from yellow through orange to dark red.
	var colors: Array = _data.get("ember", {}).get("colors", ["ffe08a", "ff8a2a", "a8361c"])
	for ember: Dictionary in _embers:
		var art: Vector2i = ember.art
		var heat := float(ember.life) / float(ember.max)
		var color := Color(str(colors[0 if heat > 0.66 else 1 if heat > 0.33 else 2]))
		color.a = clampf(0.7 + 0.3 * sin(_time * 23.0 + float(art.x) * 1.7 + float(art.y) * 2.3), 0.4, 1.0)
		canvas.draw_rect(Rect2(Vector2(art) * PIXEL, Vector2(PIXEL, PIXEL)), color)


func draw_particles(canvas: CanvasItem) -> void:
	for particle: Dictionary in _particles:
		var alpha := 1.0
		if bool(particle.fade): alpha = clampf(float(particle.life) / (float(particle.max_life) * 0.5), 0.0, 1.0)
		var size: float = particle.size
		var ground: Vector2 = particle.pos
		var height: float = particle.z
		var color: Color = particle.color
		# Airborne chunks cast a pixel shadow on the floor under them.
		if size >= 4.0 and height > 3.0 and bool(particle.settle):
			canvas.draw_rect(Rect2(_snap(ground - Vector2(size * 0.5, 0.0)), Vector2(size, PIXEL)), Color(0, 0, 0, 0.22))
		canvas.draw_rect(Rect2(_snap(ground - Vector2(0.0, height) - Vector2(size, size) * 0.5), Vector2(size, size)), Color(color, color.a * alpha))


## Glowing particles (sparks, embers, frost) light up in the bloom layer.
func draw_glow(canvas: CanvasItem, level: float) -> void:
	if level <= 0.0: return
	for particle: Dictionary in _particles:
		if not bool(particle.glow): continue
		var alpha := clampf(float(particle.life) / (float(particle.max_life) * 0.5), 0.0, 1.0) if bool(particle.fade) else 1.0
		var point: Vector2 = Vector2(particle.pos) - Vector2(0.0, float(particle.z))
		Glow.dot(canvas, point, 6.0 + float(particle.size) * 1.5, Color(particle.color, float(particle.get("glow_a", 0.32)) * alpha * level))
	for ember: Dictionary in _embers:
		var heat := float(ember.life) / float(ember.max)
		Glow.dot(canvas, _world(ember.art), 5.0 + 5.0 * heat, Color(1.0, 0.5, 0.15, 0.3 * heat * level))


func count() -> int:
	return _particles.size()


# --- The living floor ------------------------------------------------------------------

## A splat keeps creeping outwards from its rim (more along the hit direction).
func _add_pool(origin: Vector2, color: Color, radius: float, direction: Vector2) -> void:
	var liquid: Dictionary = _data.get("liquid", {})
	if _pools.size() >= int(liquid.get("max_pools", 48)): _dry(_pools.pop_front())
	var middle := _art(origin)
	var across := maxf(1.0, radius / PIXEL)
	var frontier: Array[Vector2i] = []
	for index in range(12):
		var rim := Vector2.from_angle(TAU * float(index) / 12.0) * across * Vector2(1.0, 0.75)
		frontier.append(middle + Vector2i(roundi(rim.x), roundi(rim.y)))
	_pools.append({"center": middle, "color": color, "frontier": frontier, "budget": int(across * across * float(liquid.get("budget_scale", 0.9))),
		"carry": 0.0, "dir": direction.normalized(), "reach": across * float(liquid.get("reach_scale", 2.2)), "scan": across * 2.8, "done": -1.0})


func _spread_pools(delta: float) -> void:
	var liquid: Dictionary = _data.get("liquid", {})
	var rate := float(liquid.get("spread_rate", 45))
	var dry_after := float(liquid.get("dry_after", 5.0))
	for index in range(_pools.size() - 1, -1, -1):
		var pool: Dictionary = _pools[index]
		if float(pool.done) >= 0.0:
			if _time - float(pool.done) >= dry_after:
				_dry(pool)
				_pools.remove_at(index)
			continue
		pool.carry = float(pool.carry) + rate * delta
		while float(pool.carry) >= 1.0 and int(pool.budget) > 0:
			pool.carry = float(pool.carry) - 1.0
			_grow(pool)
		if int(pool.budget) <= 0: pool.done = _time


## One creeping step: from a random frontier pixel to a neighbour (along the
## hit direction more often). Every try costs budget, so a pool always stops.
func _grow(pool: Dictionary) -> void:
	pool.budget = int(pool.budget) - 1
	var frontier: Array = pool.frontier
	if frontier.is_empty(): return
	var from: Vector2i = frontier[_rng.randi_range(0, frontier.size() - 1)]
	var step: Vector2i = STEPS[_rng.randi_range(0, 3)]
	var direction: Vector2 = pool.dir
	if direction != Vector2.ZERO and _rng.randf() < 0.45:
		step = Vector2i(int(signf(direction.x)), 0) if absf(direction.x) >= absf(direction.y) else Vector2i(0, int(signf(direction.y)))
	var next := from + step
	if next.x < 0 or next.y < 0 or Vector2(next - Vector2i(pool.center)).length() > float(pool.reach) or solid(_world(next)): return
	if _pixel(next).a < 0.05: _put(next, pool.color)
	frontier.append(next)
	if frontier.size() > 48: frontier.remove_at(0)


## A pool that stopped creeping dries: its pixels darken.
func _dry(pool: Dictionary) -> void:
	var color: Color = pool.color
	var dried := Color(color.darkened(float(_data.get("liquid", {}).get("dry_darken", 0.35))), color.a * 0.9)
	var middle: Vector2i = pool.center
	var reach := int(ceil(float(pool.scan)))
	for y in range(maxi(0, middle.y - reach), middle.y + reach + 1):
		for x in range(maxi(0, middle.x - reach), middle.x + reach + 1):
			var key := Vector2i(x / CHUNK, y / CHUNK)
			if not _chunks.has(key): continue
			var local := Vector2i(x, y) - key * CHUNK
			var here: Color = _chunks[key].image.get_pixelv(local)
			if absf(here.r - color.r) + absf(here.g - color.g) + absf(here.b - color.b) < 0.04 and absf(here.a - color.a) < 0.03:
				_chunks[key].image.set_pixelv(local, dried)
				_chunks[key].dirty = true


func _burn_embers(delta: float) -> void:
	var rate := float(_data.get("ember", {}).get("smoke_rate", 1.2))
	for index in range(_embers.size() - 1, -1, -1):
		var ember: Dictionary = _embers[index]
		ember.life = float(ember.life) - delta
		if float(ember.life) <= 0.0:
			_cool(ember)
			_embers.remove_at(index)
			continue
		var heat := float(ember.life) / float(ember.max)
		ember.smoke = float(ember.smoke) - delta * rate * heat
		if float(ember.smoke) <= 0.0:
			ember.smoke = 1.0 + _rng.randf()
			smoke(_world(ember.art), 1, 1.0)


## A burnt-out ember leaves a soot pixel (fainter for an ember with "soot" < 1).
func _cool(ember: Dictionary) -> void:
	var settings_for_embers: Dictionary = _data.get("ember", {})
	var faint := float(ember.get("soot", 1.0))
	if faint <= 0.0: return
	_blend(ember.art, Color(str(settings_for_embers.get("soot", "1c1416")), float(settings_for_embers.get("soot_alpha", 0.6)) * faint), true)


## Marks the pixel at `art` as frost (as it looks now) and schedules its melting.
func _freeze(art: Vector2i) -> void:
	var settings_for_frost: Dictionary = _data.get("frost", {})
	if _frost.size() - _frost_head >= int(settings_for_frost.get("max", 4000)): _frost_head += 1
	var melt: Array = settings_for_frost.get("melt_after", [6.0, 10.0])
	_frozen[art] = _pixel(art)
	_frost.append([art, _time + _rng.randf_range(float(melt[0]), float(melt[1]))])


## Frost that is due melts to water; water that is due dries away. A frost
## pixel painted over in the meantime (a blood pool, soot) is left as it is.
func _melt() -> void:
	var settings_for_frost: Dictionary = _data.get("frost", {})
	var water := Color(str(settings_for_frost.get("water", "3a6a9e")), float(settings_for_frost.get("water_alpha", 0.45)))
	var evaporate := float(settings_for_frost.get("evaporate_after", 8.0))
	while _frost_head < _frost.size() and float(_frost[_frost_head][1]) <= _time:
		var art: Vector2i = _frost[_frost_head][0]
		_frost_head += 1
		if not _frozen.has(art): continue
		var unchanged: bool = _pixel(art) == _frozen[art]
		_frozen.erase(art)
		if not unchanged: continue
		_put(art, water)
		_loose.erase(art)
		_wet[art] = true
		_water.append([art, _time + evaporate * _rng.randf_range(0.7, 1.3)])
	while _water_head < _water.size() and float(_water[_water_head][1]) <= _time:
		var art: Vector2i = _water[_water_head][0]
		_water_head += 1
		if not _wet.has(art): continue
		_wet.erase(art)
		var here := _pixel(art)
		if absf(here.r - water.r) + absf(here.g - water.g) + absf(here.b - water.b) < 0.04: _put(art, Color(0, 0, 0, 0))
	if _frost_head > 512:
		_frost = _frost.slice(_frost_head)
		_frost_head = 0
	if _water_head > 512:
		_water = _water.slice(_water_head)
		_water_head = 0


# --- Floor-mark pixels ----------------------------------------------------------------

func _art(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / PIXEL), floori(point.y / PIXEL))


## The world point in the middle of art pixel `art`.
func _world(art: Vector2i) -> Vector2:
	return Vector2(art) * PIXEL + Vector2(PIXEL, PIXEL) * 0.5


func _pixel(art: Vector2i) -> Color:
	if art.x < 0 or art.y < 0: return Color(0, 0, 0, 0)
	var key := Vector2i(art.x / CHUNK, art.y / CHUNK)
	if not _chunks.has(key): return Color(0, 0, 0, 0)
	return _chunks[key].image.get_pixelv(art - key * CHUNK)


## Sets one art pixel to `color` exactly (no blending).
func _put(art: Vector2i, color: Color) -> void:
	if art.x < 0 or art.y < 0: return
	var chunk := _chunk(art)
	chunk.image.set_pixelv(art - Vector2i(art.x / CHUNK, art.y / CHUNK) * CHUNK, color)
	chunk.dirty = true


func _snap(point: Vector2) -> Vector2:
	return (point / PIXEL).round() * PIXEL


## A filled pixel ellipse (floor perspective: flatter than wide) at `centre`.
func _disc(centre: Vector2, radius: float, color: Color) -> void:
	var middle := _art(centre)
	var across := maxf(0.5, radius / PIXEL)
	var rows := maxi(0, int(across * 0.75))
	for row in range(-rows, rows + 1):
		var share := float(row) / maxf(across * 0.75, 0.5)
		var half := int(across * sqrt(maxf(0.0, 1.0 - share * share)))
		# A ragged rim so splats never look stamped.
		if absi(row) == rows and half > 1: half -= _rng.randi_range(0, 1)
		_span(middle.y + row, middle.x - half, middle.x + half, color, true)


## A one-pixel line in art pixels (cracks may run into the wall).
func _line(from: Vector2, to: Vector2, color: Color) -> void:
	var start := _art(from)
	var end := _art(to)
	var steps := maxi(absi(end.x - start.x), absi(end.y - start.y))
	for index in range(steps + 1):
		var t := float(index) / maxf(1.0, float(steps))
		_blend(Vector2i(roundi(lerpf(start.x, end.x, t)), roundi(lerpf(start.y, end.y, t))), color, false)


## Row `y` from `x0` to `x1` (art px), cut at wall cells when `masked`.
func _span(y: int, x0: int, x1: int, color: Color, masked: bool) -> void:
	if y < 0 or x1 < 0 or x1 < x0: return
	var x := maxi(x0, 0)
	while x <= x1:
		var end := mini(x1, (x / CELL_ART + 1) * CELL_ART - 1)
		if not masked or not solid(Vector2(x * PIXEL + 1.0, y * PIXEL + 1.0)):
			var chunk := _chunk(Vector2i(x, y))
			var key := Vector2i(x / CHUNK, y / CHUNK)
			chunk.image.fill_rect(Rect2i(Vector2i(x, y) - key * CHUNK, Vector2i(end - x + 1, 1)), color)
			chunk.dirty = true
		x = end + 1


## Paints one art pixel over what lies there (alpha blended).
func _blend(art: Vector2i, color: Color, masked: bool) -> void:
	if art.x < 0 or art.y < 0: return
	if masked and solid(Vector2(art.x * PIXEL + 1.0, art.y * PIXEL + 1.0)): return
	var chunk := _chunk(art)
	var local := art - Vector2i(art.x / CHUNK, art.y / CHUNK) * CHUNK
	chunk.image.set_pixelv(local, chunk.image.get_pixelv(local).blend(color))
	chunk.dirty = true


func _chunk(art: Vector2i) -> Dictionary:
	var key := Vector2i(art.x / CHUNK, art.y / CHUNK)
	if not _chunks.has(key):
		_chunks[key] = {"image": Image.create_empty(CHUNK, CHUNK, false, Image.FORMAT_RGBA8), "texture": null, "dirty": true}
	return _chunks[key]
