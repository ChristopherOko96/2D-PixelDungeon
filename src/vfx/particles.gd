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
##
## Fire rises: a flame particle is buoyant (it climbs faster and faster), runs
## down its colour ramp as it ages (white-yellow, orange, red), gets thinner,
## flickers by changing its shape on the 12 fps beat (a sideways hop, never a
## brightness pulse) and may leave a puff of smoke where it dies; rising embers
## tumble the same way (flames, fire_burst; vfx_particles.json "fire").
##
## Ice is rigid (shatter; vfx_particles.json "ice"): a shard is a short line of
## pixels in one of 8 facings that turns in steps while it flies, hardly
## bounces, leaves a fleck of frost where it strikes the floor, skids a short
## way over the stones (dry friction, knocked round as it goes) and stops,
## clinks off a wall or, hitting it hard, breaks into chips; at rest it lies as
## frost that melts. Rime is a frost crust spreading from where the cold struck
## (thick in its middle, loose crystals at its rim) with frost ferns growing out
## of it tip first, barbed to both sides; it stops at walls (rime_grow).
##
## The void pulls (vfx_particles.json "void"): a well swirls everything in its
## reach inwards, faster the closer it gets (like water down a drain), lifts
## loose pixels and embers off the floor into it and swallows what reaches its
## core; motes of it circle in as short streaks (well). An implosion pulls hard
## for a moment, shows one frame of void (a dark core with a bright rim), then
## throws a pressure ring outwards (implode).
##
## The rest (vfx_particles.json "elements"): sparks fly as short streaks;
## rubble is heavy (one low bounce, it stops hard; lit top, dark bottom);
## dust creeps flat over the floor; floor cracks and lightning's scorch stars
## stay; holy light falls in shafts that sparkle where they land while gold
## motes rise; shadow is ink that crawls over the floor tip first with a cold
## violet rim and goes again, its motes sinking.

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
## Frost that goes without water (vapor): [art, due time], checked every frame
## so it leaves in its dither order.
var _vapor: Array = []
var _frost_head := 0
var _water: Array = []
var _water_head := 0
## Frost pixels on the floor (art px -> their colour when frozen) and water pixels.
var _frozen: Dictionary = {}
var _wet: Dictionary = {}
## Floor cells of a liquid that swallows what lands in it (set_sink).
var _sink: Dictionary = {}
## Void wells: key -> {p, r, pull, spin, core, until, motes, carry, suck, cols} (well).
var _wells: Dictionary = {}
## Implosions: {p, r, t0, cols, fired} (implode).
var _implosions: Array = []
## Rime growing over the floor: {p (art px), d (direction), left, carry, col, gen} (rime_grow).
var _growth: Array = []
## The 8 facings of an ice shard (art px steps).
const DIR8 := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
## Wet steps and dots that dry away: [art, due time, colour] (wet()).
var _damp: Array = []
var _damp_head := 0
## The pool layers blasts ring (src/vfx/pool_paint.gd ripple_near): [WeakRef, scale to their px].
var _liquids: Array = []
const STEPS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
## 4x4 ordered dither (vapor frost leaves in this order).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


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
	if mode == "spark": particle.streak = true
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


## Frost clumps (opaque, Frostgruft rime): `count` crystals within `radius` of
## `point`, each a core pixel with 0-2 neighbours (plus or L shapes) in
## `colors` (the first for the cores, the rest for the arms). One melt time
## per clump; with `vapor` the clump goes without water, its pixels leaving in
## ordered-dither order over frost.vapor_spread s (vfx_particles.json).
func frost_clumps(point: Vector2, radius: float, count: int, colors: Array, vapor := false) -> void:
	if colors.is_empty(): return
	_marks += 1
	var settings_for_frost: Dictionary = _data.get("frost", {})
	var melt: Array = settings_for_frost.get("melt_after", [6.0, 10.0])
	for i in range(count):
		var offset := Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf())
		offset.y *= 0.75
		var core := _art(point + offset)
		var due := _time + _rng.randf_range(float(melt[0]), float(melt[1]))
		var cells: Array[Vector2i] = [core]
		for j in range(_rng.randi_range(0, 2)):
			cells.append(core + STEPS[_rng.randi_range(0, 3)])
		for k in range(cells.size()):
			var art: Vector2i = cells[k]
			if art.x < 0 or art.y < 0 or solid(_world(art)): continue
			var color: Color = colors[0] if k == 0 or colors.size() == 1 else colors[1 + _rng.randi_range(0, colors.size() - 2)]
			_put(art, color)
			_freeze(art, vapor, due)


## Up to `n` art pixels of vapor frost still lying (picked at random), for
## twinkles drawn over them.
func frost_sample(n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _vapor.is_empty(): return out
	for i in range(n):
		var spot: Vector2i = _vapor[_rng.randi_range(0, _vapor.size() - 1)][0]
		if _frozen.has(spot): out.append(spot)
	return out


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


## `count` flames rising from around `point` (within `radius` px; seen
## `height` px over the floor), each running down `ramp` (hot to cool colours;
## vfx_particles.json fire.ramp when empty) and pushed along by `push`.
func flames(point: Vector2, count: int, ramp: Array = [], radius: float = 3.0, height: float = 0.0, push: Vector2 = Vector2.ZERO) -> void:
	var spec: Dictionary = _data.get("fire", {})
	var colours: Array = ramp if not ramp.is_empty() else _fire_ramp()
	var life: Array = spec.get("life", [0.3, 0.55])
	var size: Array = spec.get("size", [2, 4])
	var lift: Array = _mode("flame").get("lift", [10, 30])
	for i in range(count):
		var spot := point + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius) * 0.5)
		var flame := emit(spot, push + Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-4.0, 4.0)), colours[0], _rng.randf_range(float(life[0]), float(life[1])),
			"flame", float([float(size[0]), float(size[1])][_rng.randi_range(0, 1)]), height, _rng.randf_range(float(lift[0]), float(lift[1])), 1.5)
		flame.ramp = colours
		flame.smoke_p = float(spec.get("smoke_chance", 0.25))
		flame.seed = _rng.randi() % 997


func _fire_ramp() -> Array:
	var out: Array = []
	for hex: Variant in _data.get("fire", {}).get("ramp", ["fff2a0", "ffc24a", "ff7a2a", "b8321a", "5a1a0a"]):
		out.append(Color(str(hex)))
	return out


## A fire bursting out at `point` (radius `radius` px): flames thrown out and
## up from it, embers rising and tumbling, smoke rolling off, the floor kicked,
## scorched and left with glowing embers.
func fire_burst(point: Vector2, radius: float, ramp: Array = []) -> void:
	var spec: Dictionary = _data.get("fire", {})
	var count := clampi(int(radius * float(spec.get("burst_per_px", 0.5))), 6, int(spec.get("burst_max", 36)))
	var colours: Array = ramp if not ramp.is_empty() else _fire_ramp()
	for i in range(count):
		var out := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.2, 1.0)
		flames(point + out * radius * 0.4, 1, colours, 2.0, _rng.randf_range(0.0, 6.0), out * radius * _rng.randf_range(1.2, 2.4))
	for i in range(count / 3):
		var ember := emit(point, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(30.0, 120.0), colours[1], _rng.randf_range(0.6, 1.2), "ember", 2.0, 4.0, _rng.randf_range(40.0, 110.0), 1.2)
		ember.seed = _rng.randi() % 997
	smoke(point, maxi(2, count / 6), radius * 0.4)
	embers(point, radius * 0.5, maxi(3, int(radius * 0.25)))
	stain(point, Color(str(_data.get("ember", {}).get("soot", "1c1416"))), radius * 0.35)


## `count` glowing sparks of a fire blast from `point` (biased along `dir`, all
## round when zero), the talents' fat explosions (user feedback 2026-10-31):
## they fly as glowing pixels at fire.spark_speed px/s (x `scale`), bounce on
## the floor and lie down as embers that die over fire.ember_lie s, leaving a
## faint soot pixel each (vfx_particles.json "fire").
func ember_sparks(point: Vector2, count: int, dir: Vector2 = Vector2.ZERO, scale: float = 1.0) -> void:
	var spec: Dictionary = _data.get("fire", {})
	var speed: Array = spec.get("spark_speed", [120, 260])
	var lie: Array = spec.get("ember_lie", [1.0, 1.8])
	var colours: Array = _fire_ramp()
	var lift: Array = _mode("glut").get("lift", [30, 90])
	for i in range(count):
		var angle := _rng.randf() * TAU if dir == Vector2.ZERO else dir.angle() + _rng.randf_range(-1.3, 1.3)
		var velocity := Vector2.from_angle(angle) * _rng.randf_range(float(speed[0]), float(speed[1])) * scale
		var spark := emit(point, velocity, colours[_rng.randi_range(0, 1)], _rng.randf_range(0.45, 0.9), "glut", 2.0, 4.0, _rng.randf_range(float(lift[0]), float(lift[1])) * scale, 2.5)
		spark.ember_life = _rng.randf_range(float(lie[0]), float(lie[1]))
		spark.soot = float(spec.get("spark_soot", 0.5))


func _ice(key: String, fallback: float) -> float:
	return float(_data.get("ice", {}).get(key, fallback))


func _ice_ramp() -> Array:
	var out: Array = []
	for hex: Variant in _data.get("ice", {}).get("ramp", ["e8fbff", "a6e3f7", "6fbde8", "3b84c4", "1e3a52"]):
		out.append(Color(str(hex)))
	return out


## `count` rigid ice shards bursting from `point` along `dir` (all round when
## zero) at about `speed` px/s, each `2..big` pixels long, coloured by `ramp`
## (spec, lite, body, shade, deep; vfx_particles.json ice.ramp when empty), and
## a glint where they burst.
func shatter(point: Vector2, count: int, dir: Vector2 = Vector2.ZERO, speed: float = 160.0, ramp: Array = [], big: int = 3) -> void:
	var colours: Array = ramp if ramp.size() >= 5 else _ice_ramp()
	var lift: Array = _mode("shard").get("lift", [40, 120])
	for i in range(count):
		var out := dir.normalized().rotated(_rng.randf_range(-1.0, 1.0)) if dir.length() > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
		var shard := emit(point, out * speed * _rng.randf_range(0.4, 1.0), colours[2], _rng.randf_range(2.5, 4.0), "shard", 2.0, _rng.randf_range(2.0, 10.0), _rng.randf_range(float(lift[0]), float(lift[1])), 0.2)
		shard.shard = _rng.randi() % 8
		shard.spin = 1 if _rng.randf() < 0.5 else -1
		shard.len = _rng.randi_range(mini(2, big), maxi(1, big))
		shard.ice = colours
	for i in range(mini(3, maxi(1, count / 3))):
		emit(point, Vector2.from_angle(_rng.randf() * TAU) * 60.0, colours[0], 0.12, "spark", 2.0, 6.0, 40.0, 4.0)


## A shard that hit a wall hard breaks into 3-5 chips flying back off it.
func _break_shard(particle: Dictionary) -> void:
	var colours: Array = particle.ice
	var back := -Vector2(particle.vel).normalized() if Vector2(particle.vel).length() > 1.0 else Vector2.UP
	for i in range(_rng.randi_range(3, 5)):
		var chip := emit(Vector2(particle.pos), back.rotated(_rng.randf_range(-1.1, 1.1)) * _rng.randf_range(40.0, 110.0), colours[1], _rng.randf_range(1.5, 2.5), "shard", 2.0, maxf(2.0, float(particle.z)), _rng.randf_range(30.0, 80.0), 0.3)
		chip.shard = _rng.randi() % 8
		chip.spin = 1 if _rng.randf() < 0.5 else -1
		chip.len = 1
		chip.ice = colours
	emit(Vector2(particle.pos), Vector2.ZERO, colours[0], 0.1, "spark", 2.0, maxf(2.0, float(particle.z)), 30.0, 4.0)


## A sliding shard scratches a short frost line into the floor (goes later).
func _scratch(point: Vector2, particle: Dictionary) -> void:
	var art := _art(point)
	if art.x < 0 or art.y < 0 or solid(_world(art)) or sinks(point): return
	var colours: Array = particle.ice
	_put(art, colours[1])
	_freeze(art, true)


## Hoarfrost growing over the floor from `point`: a frost crust that spreads
## from the middle (thick there, breaking up into loose crystals towards its
## rim, ice.rime_core of `reach` wide) and `branches` frost ferns
## (ice.rime_branches times as many, ice.rime_reach of `reach` long) growing
## out of it tip first (ice.rime_rate px/s), each a stem with short barbs to
## both sides, longest near the root, now and then a side fern; they stop at
## walls and liquids, and the frost goes later (thinning in a dither).
func rime_grow(point: Vector2, branches: int, reach: float, color: Color = Color(0, 0, 0, 0)) -> void:
	var colours := _ice_ramp()
	var col: Color = color if color.a > 0.0 else colours[2]
	var start := Vector2(_art(point)) + Vector2(0.5, 0.5)
	var core := reach * _ice("rime_core", 0.4) / PIXEL
	if core >= 1.5 and _growth.size() < int(_ice("rime_max", 160)):
		_growth.append({"patch": true, "c": start, "R": core, "r": 0.0, "col": col, "lite": colours[1], "spec": colours[0], "seed": _rng.randi() % 9973})
	var count := maxi(1, roundi(float(branches) * _ice("rime_branches", 1.6)))
	var long := reach * _ice("rime_reach", 0.65) / PIXEL
	for i in range(count):
		if _growth.size() >= int(_ice("rime_max", 160)): break
		var left := long * _rng.randf_range(0.55, 1.0)
		# ferns start at the crust's edge, not in its middle
		var d := Vector2.from_angle(TAU * float(i) / float(count) + _rng.randf_range(-0.3, 0.3))
		_growth.append({"p": start + d * core * 0.6, "d": d, "left": left, "len": left, "carry": 0.0, "col": col, "lite": colours[1], "gen": 0, "lean": _ice("rime_axis", 0.06)})


## A fixed 0..1 value per floor pixel (so a crust's crystals do not flicker).
static func _cell_noise(q: Vector2i, seed: int) -> float:
	var h := (q.x * 374761393 + q.y * 668265263 + seed * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) % 1024) / 1024.0


## The frost crust spreads one ring further: thick near the middle (its lightest
## crystals there), broken up towards its rim.
func _grow_crust(patch: Dictionary, delta: float, rate: float) -> void:
	var c: Vector2 = patch.c
	var big := float(patch.R)
	var from := float(patch.r)
	var to := minf(big, from + rate * 0.7 * delta)
	patch.r = to
	for y in range(int(floor(c.y - to)), int(ceil(c.y + to)) + 1):
		for x in range(int(floor(c.x - to)), int(ceil(c.x + to)) + 1):
			var q := Vector2i(x, y)
			var dist := (Vector2(q) + Vector2(0.5, 0.5) - c).length()
			if dist < from or dist >= to or q.x < 0 or q.y < 0:
				continue
			var keep := 1.0 - dist / big
			var n := _cell_noise(q, int(patch.seed))
			if n > keep * _ice("rime_fill", 1.1) + 0.1 or solid(_world(q)) or sinks(_world(q)):
				continue
			var col: Color = patch.spec if n < 0.025 else (patch.lite if n < keep * 0.4 else patch.col)
			_put(q, col)
			_freeze(q, true)


func _grow_rime(delta: float) -> void:
	var rate := _ice("rime_rate", 40.0)
	for index in range(_growth.size() - 1, -1, -1):
		var branch: Dictionary = _growth[index]
		if branch.has("patch"):
			_grow_crust(branch, delta, rate)
			if float(branch.r) >= float(branch.R):
				_growth.remove_at(index)
			continue
		branch.carry = float(branch.carry) + rate * delta
		var d: Vector2 = branch.d
		var p: Vector2 = branch.p
		while float(branch.carry) >= 1.0 and float(branch.left) > 0.0:
			branch.carry = float(branch.carry) - 1.0
			branch.left = float(branch.left) - 1.0
			# it leans a little towards the floor's joints and wanders
			var axis := Vector2(signf(d.x), 0.0) if absf(d.x) >= absf(d.y) else Vector2(0.0, signf(d.y))
			d = (d + axis * float(branch.get("lean", 0.18)) + Vector2(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35))).normalized()
			p += d
			var art := Vector2i(p.floor())
			if art.x < 0 or art.y < 0 or solid(_world(art)) or sinks(_world(art)):
				branch.left = 0.0
				break
			_put(art, branch.col)
			branch.step = int(branch.get("step", 0)) + 1
			if branch.has("len") and int(branch.step) % 2 == 0:
				# a fern: short light barbs to alternate sides, longest near the root
				var barb := roundi(2.0 * float(branch.left) / maxf(1.0, float(branch.len))) + (1 if int(branch.gen) == 0 else 0)
				var bd := d.rotated(0.8 if int(branch.step) % 4 == 0 else -0.8)
				for k in range(1, barb + 1):
					var q := Vector2i((p + bd * float(k)).floor())
					if q.x < 0 or q.y < 0 or solid(_world(q)) or sinks(_world(q)):
						break
					if _pixel(q).a > 0.05:
						continue
					_put(q, branch.lite)
					_freeze(q, true)
			if branch.has("rim"):
				# shadow: thick (a cold violet rim both sides) near its root, thin at
				# its tip; once grown it holds a moment, then draws back tip first
				var whole := maxf(1.0, float(branch.get("whole", branch.left)))
				var share := float(branch.left) / whole
				var due := _time + float(branch.left) / rate + float(branch.get("hold", 0.5)) + float(branch.get("back", 0.6)) * share
				if share > 0.35:
					var side := Vector2i(roundi(d.orthogonal().x), roundi(d.orthogonal().y))
					for s: Vector2i in [side, -side]:
						var rim := art + s
						if not solid(_world(rim)) and _pixel(rim).a < 0.05:
							_put(rim, branch.rim)
							_freeze(rim, true, due - 0.05, 0.15)
				_freeze(art, true, due, 0.15)
			else:
				_freeze(art, true)
			if int(branch.gen) < 1 and _rng.randf() < 0.12 and _growth.size() < int(_ice("rime_max", 160)):
				var twig := {"p": p, "d": d.rotated(0.8 if _rng.randf() < 0.5 else -0.8), "left": float(branch.left) * 0.45, "carry": 0.0, "col": branch.col, "gen": int(branch.gen) + 1, "lean": branch.get("lean", 0.18)}
				if branch.has("len"):
					twig.len = twig.left
					twig.lite = branch.lite
				if branch.has("rim"):
					# a shadow's side tendril goes with it (not as frost)
					for key: String in ["rim", "hold", "back", "shadow"]:
						if branch.has(key):
							twig[key] = branch[key]
					twig.whole = twig.left
				_growth.append(twig)
		branch.d = d
		branch.p = p
		if float(branch.left) <= 0.0:
			_growth.remove_at(index)


func _void(key: String, fallback: float) -> float:
	return float(_data.get("void", {}).get(key, fallback))


func _void_ramp() -> Array:
	var out: Array = []
	for hex: Variant in _data.get("void", {}).get("ramp", ["f2d9ff", "c27bff", "7a3fb8", "3a1f5c", "1a0d2a"]):
		out.append(Color(str(hex)))
	return out


## A well of the void at `point` (key `key`, kept while it is called again
## within `ttl` s): within `radius` everything swirls in (`pull` inwards,
## `spin` round, both px/s and stronger the closer), what reaches `core` is
## swallowed, loose pixels and embers are lifted into it, and `motes` streaks
## a second circle in. `ramp`: spec, lite, body, shade, deep (void when empty).
func well(key: String, point: Vector2, radius: float, pull: float, spin: float, core: float, ttl: float = 0.2, motes: float = 0.0, ramp: Array = []) -> void:
	var w: Dictionary = _wells.get(key, {"carry": 0.0, "suck": 0.0})
	w.p = point
	w.r = maxf(radius, 1.0)
	w.pull = pull
	w.spin = spin
	w.core = core
	w.until = _time + ttl
	w.motes = motes
	w.cols = ramp if ramp.size() >= 5 else _void_ramp()
	_wells[key] = w


## An implosion at `point` reaching `radius`: a hard pull for a moment
## (void.implode_time s), then one frame of void and a pressure ring outwards.
func implode(point: Vector2, radius: float, ramp: Array = []) -> void:
	var cols: Array = ramp if ramp.size() >= 5 else _void_ramp()
	var hold := _void("implode_time", 0.28)
	well("implode:%d" % _implosions.size() + str(_time), point, radius * 1.5, _void("implode_pull", 420.0), _void("implode_spin", 160.0), radius * 0.12, hold, 0.0, cols)
	for i in range(int(radius * 0.4)):
		var at := point + Vector2.from_angle(_rng.randf() * TAU) * radius * _rng.randf_range(0.6, 1.1) * Vector2(1.0, 0.75)
		var mote := emit(at, (point - at).orthogonal().normalized() * 40.0, cols[1] if i % 3 else cols[0], hold + 0.1, "mote", 2.0, 4.0, 0.0, 0.5)
		mote.streak = true
	_implosions.append({"p": point, "r": radius, "t0": _time, "cols": cols, "fired": false})


func _step_wells(delta: float) -> void:
	for key: String in _wells.keys():
		var w: Dictionary = _wells[key]
		if float(w.until) < _time:
			_wells.erase(key)
			continue
		var p: Vector2 = w.p
		var r := float(w.r)
		var core := float(w.core)
		# everything in reach swirls in, faster the closer it gets; the core swallows it
		for index in range(_particles.size() - 1, -1, -1):
			var particle: Dictionary = _particles[index]
			var off: Vector2 = p - Vector2(particle.pos)
			var d := off.length()
			if d >= r: continue
			if d <= core:
				_particles.remove_at(index)
				continue
			var inward := off / d
			var near := clampf(r / (d + 12.0), 0.0, 6.0)
			particle.vel = Vector2(particle.vel) + (inward * float(w.pull) + inward.orthogonal() * float(w.spin)) * near * delta
			if float(particle.gravity) > 0.0 and float(particle.z) <= 1.0:
				particle.vz = maxf(float(particle.vz), 30.0 * near)
		# motes circle in as streaks
		w.carry = float(w.carry) + float(w.motes) * delta
		while float(w.carry) >= 1.0:
			w.carry = float(w.carry) - 1.0
			var at := p + Vector2.from_angle(_rng.randf() * TAU) * r * _rng.randf_range(0.6, 1.0) * Vector2(1.0, 0.75)
			var mote := emit(at, (p - at).orthogonal().normalized() * float(w.spin) * 0.5, (w.cols as Array)[1 if _rng.randf() < 0.7 else 0], _rng.randf_range(0.8, 1.4), "mote", 2.0, _rng.randf_range(2.0, 8.0), 0.0, 0.3)
			mote.streak = true
		# now and then the floor is lifted into it: loose pixels and embers
		w.suck = float(w.suck) - delta
		if float(w.suck) <= 0.0:
			w.suck = 0.25
			_suck(p, r * 0.8)


## Lifts loose floor pixels and glowing embers within `radius` of `point` so
## a well can take them (a few at a time).
func _suck(point: Vector2, radius: float) -> void:
	var lifted := 0
	for index in range(_embers.size() - 1, -1, -1):
		if lifted >= 8: break
		var ember: Dictionary = _embers[index]
		var at := _world(ember.art)
		if at.distance_to(point) > radius or _rng.randf() < 0.5: continue
		_embers.remove_at(index)
		emit(at, Vector2.ZERO, Color(str(_data.get("ember", {}).get("colors", ["ffe08a"])[0])), 1.0, "glut", 2.0, 0.0, 30.0, 1.0)
		lifted += 1
	var middle := _art(point)
	var reach := int(radius / PIXEL)
	for i in range(24):
		if lifted >= 16: break
		var art := middle + Vector2i(_rng.randi_range(-reach, reach), _rng.randi_range(-reach, reach))
		if not _loose.has(art) or _frozen.has(art): continue
		var color := _pixel(art)
		_put(art, Color(0, 0, 0, 0))
		_loose.erase(art)
		if color.a > 0.05:
			emit(_world(art), Vector2.ZERO, Color(color, 1.0), 1.0, "debris", PIXEL, 0.0, 30.0, 1.0)
			lifted += 1


func _step_implosions() -> void:
	for index in range(_implosions.size() - 1, -1, -1):
		var imp: Dictionary = _implosions[index]
		var age := _time - float(imp.t0)
		if not bool(imp.fired) and age >= _void("implode_time", 0.28):
			imp.fired = true
			var p: Vector2 = imp.p
			var r := float(imp.r)
			# the release: a pressure ring outwards, the floor kicked, motes flung out
			blow(p, 0.0, r, 0.0, TAU, r * 4.0)
			kick(p, r * 0.6, 0.7)
			var cols: Array = imp.cols
			for i in range(int(r * 0.3)):
				var mote := emit(p, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(80.0, 200.0), cols[1], _rng.randf_range(0.3, 0.6), "mote", 2.0, 4.0, 0.0, 2.0)
				mote.streak = true
		if age > 0.7:
			_implosions.remove_at(index)


## The implosions' moment of void and their pressure ring (over the particles).
func _draw_implosions(canvas: CanvasItem) -> void:
	for imp: Dictionary in _implosions:
		var age := _time - float(imp.t0)
		var hold := _void("implode_time", 0.28)
		var cols: Array = imp.cols
		var c := Vector2(_art(imp.p))
		var r := float(imp.r) / PIXEL
		if age >= hold - 0.05 and age < hold + 0.06:
			# one frame of void: a dark core with a bright rim
			var core := maxf(2.0, r * 0.3)
			for y in range(int(-core), int(core) + 1):
				for x in range(int(-core), int(core) + 1):
					var e := Vector2(x, float(y) / 0.75).length()
					if e > core + 0.5: continue
					var col: Color = cols[4] if e < core - 1.0 else cols[0]
					canvas.draw_rect(Rect2((c + Vector2(x, y)) * PIXEL, Vector2(PIXEL, PIXEL)), col)
		elif age >= hold and age < 0.7:
			# the pressure ring running out, thinning by the dither
			var k := (age - hold) / (0.7 - hold)
			var rr := r * (0.3 + 0.9 * k)
			var n := maxi(16, int(TAU * rr))
			for i in range(n):
				var q := Vector2i(c + Vector2(cos(TAU * i / n) * rr, sin(TAU * i / n) * rr * 0.75))
				if float(BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)]) >= (1.0 - k) * 16.0: continue
				if solid(_world(q)): continue
				canvas.draw_rect(Rect2(Vector2(q) * PIXEL, Vector2(PIXEL, PIXEL)), cols[1] if i % 3 else cols[0])


func _el(key: String) -> Array:
	var out: Array = []
	for hex: Variant in _data.get("elements", {}).get(key, ["ffffff", "c0c0c0", "808080"]):
		out.append(Color(str(hex)))
	return out


## `count` sparks off a hit at `point`: short streaks in a cone round
## `normal` (away from the struck surface), quick and gone; `colors` their
## colours (elements.spark, hot metal, when empty; lightning gives its own).
func sparks(point: Vector2, normal: Vector2, count: int, colors: Array = []) -> void:
	var cols: Array = colors if colors.size() > 0 else _el("spark")
	var away := normal.normalized() if normal.length() > 0.01 else Vector2.UP
	for i in range(count):
		emit(point, away.rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(120.0, 280.0), cols[_rng.randi_range(0, cols.size() - 1)], _rng.randf_range(0.08, 0.18), "spark", 2.0, 6.0, _rng.randf_range(20.0, 60.0), 3.0)


func _shot(key: String, fallback: Array) -> Array:
	return _data.get("shot", {}).get(key, fallback)


## `count` drops of a liquid (poison, blood, water) flung from `point` along
## `dir` (all round when zero) in `colors` (body first): they fly in arcs,
## land and lie as floor pixels (vfx_particles.json "shot").
func drops(point: Vector2, count: int, dir: Vector2, colors: Array) -> void:
	if colors.is_empty(): return
	var speed: Array = _shot("drops", [60, 160])
	var life: Array = _shot("drop_life", [1.5, 3.0])
	var lift: Array = _mode("drop").get("lift", [50, 140])
	for i in range(count):
		var out := dir.normalized().rotated(_rng.randf_range(-1.2, 1.2)) if dir.length() > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
		emit(point, out * _rng.randf_range(float(speed[0]), float(speed[1])), colors[_rng.randi_range(0, colors.size() - 1)],
			_rng.randf_range(float(life[0]), float(life[1])), "drop", 2.0 if i % 3 else 4.0, _rng.randf_range(2.0, 8.0), _rng.randf_range(float(lift[0]), float(lift[1])), 2.0)


## `count` motes of a spirit element (soul, curse, spirit) drifting out of
## `point` as short glowing streaks in `colors`, rising a little, soon gone.
func motes(point: Vector2, count: int, colors: Array, rise := 12.0) -> void:
	if colors.is_empty(): return
	var speed: Array = _shot("motes", [20, 60])
	var life: Array = _shot("mote_life", [0.35, 0.7])
	for i in range(count):
		var out := Vector2.from_angle(_rng.randf() * TAU)
		var mote := emit(point + out * _rng.randf_range(0.0, 6.0), out * _rng.randf_range(float(speed[0]), float(speed[1])) + Vector2(0, -rise),
			colors[_rng.randi_range(0, colors.size() - 1)], _rng.randf_range(float(life[0]), float(life[1])), "mote", 2.0, _rng.randf_range(4.0, 14.0), 0.0, 0.8)
		mote.streak = true


## `count` chips of a hard element (bone, steel, gold, stone) from `point`
## along `dir` (all round when zero) in `colors`: they fall, bounce and settle
## as floor pixels that stay.
func chips(point: Vector2, count: int, dir: Vector2, colors: Array) -> void:
	if colors.is_empty(): return
	var speed: Array = _shot("chips", [80, 180])
	var life: Array = _shot("chip_life", [2.0, 3.5])
	var lift: Array = _mode("debris").get("lift", [40, 150])
	for i in range(count):
		var out := dir.normalized().rotated(_rng.randf_range(-1.0, 1.0)) if dir.length() > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
		emit(point, out * _rng.randf_range(float(speed[0]), float(speed[1])), colors[_rng.randi_range(0, colors.size() - 1)],
			_rng.randf_range(float(life[0]), float(life[1])), "debris", 2.0 if i % 2 else 4.0, _rng.randf_range(2.0, 8.0), _rng.randf_range(float(lift[0]), float(lift[1])), 3.0)


## Where lightning struck: a star of scorch lines burnt into the floor and a
## few embers glowing in it.
func scorch_star(point: Vector2, size: float) -> void:
	var soot := Color(str(_data.get("ember", {}).get("soot", "1c1416")))
	for i in range(6):
		var dir := Vector2.from_angle(TAU * float(i) / 6.0 + _rng.randf_range(-0.3, 0.3)) * Vector2(1.0, 0.75)
		_line(point, point + dir * size * _rng.randf_range(0.5, 1.0), Color(soot, 0.8))
	embers(point, size * 0.3, 3)


## `count` chunks of rubble from `point` along `dir` (all round when zero):
## heavy, one low bounce, they stop hard and lie as loose pixels.
func rubble(point: Vector2, count: int, dir: Vector2 = Vector2.ZERO, speed: float = 140.0) -> void:
	var cols := _el("stone")
	var lift: Array = _mode("rock").get("lift", [40, 110])
	for i in range(count):
		var out := dir.normalized().rotated(_rng.randf_range(-1.0, 1.0)) if dir.length() > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
		var rock := emit(point, out * speed * _rng.randf_range(0.4, 1.0), cols[1], 3.0, "rock", float([2, 4, 4, 6][_rng.randi_range(0, 3)]), 4.0, _rng.randf_range(float(lift[0]), float(lift[1])), 0.5)
		rock.rock = cols


## Dust creeping flat over the floor from `point` (within `radius`), settling soon.
func dust_flat(point: Vector2, radius: float, count: int) -> void:
	var cols := _el("dust")
	for i in range(count):
		var out := Vector2.from_angle(_rng.randf() * TAU) * Vector2(1.0, 0.7)
		emit(point + out * radius * 0.3, out * _rng.randf_range(40.0, 90.0), cols[_rng.randi_range(0, cols.size() - 1)], _rng.randf_range(0.8, 1.6), "dust", 4.0, 0.0, 0.0, 3.0)


## Cracks radiating from a heavy blow at `point` (`branches` jagged lines up
## to `length` px) out of the dent the blow pressed into the floor (dark in
## its middle, its far rim catching the light); each crack is lit along its
## lower lip near the dent, where it is widest. They stay.
func floor_crack(point: Vector2, length: float, branches: int) -> void:
	var dark := Color(0.08, 0.06, 0.06, 0.8)
	var lit := Color(_el("stone")[0], 0.4)
	var hollow := maxf(PIXEL * 3.0, length * 0.28)
	var c := _art(point)
	var reach := int(ceil(hollow / PIXEL))
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var q := c + Vector2i(x, y)
			var e := Vector2(float(x), float(y) / 0.75).length() * PIXEL / hollow
			if e > 1.0:
				continue
			if e > 0.7 and y > 0:
				_blend(q, lit, true)
			elif e < 0.55 or float(BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)]) < (1.0 - e) * 30.0:
				_blend(q, dark, true)
	for b in range(branches):
		var p := point
		var d := Vector2.from_angle(TAU * float(b) / float(branches) + _rng.randf_range(-0.4, 0.4))
		var whole := length * _rng.randf_range(0.6, 1.0)
		var left := whole
		while left > 0.0:
			var step := _rng.randf_range(4.0, 8.0)
			var next := p + d * step * Vector2(1.0, 0.75)
			if solid(next): break
			_line(p, next, dark)
			if left > whole * 0.45:
				_line(p + Vector2(0.0, PIXEL), next + Vector2(0.0, PIXEL), lit)
			p = next
			d = d.rotated(_rng.randf_range(-0.5, 0.5))
			left -= step


## Holy light at `point`: `count` shafts falling from above that sparkle where
## they land, and gold motes rising slowly round it (within `radius`).
func holy(point: Vector2, count: int, radius: float) -> void:
	var cols := _el("holy")
	for i in range(count):
		var at := point + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius) * 0.5)
		var shaft := emit(at, Vector2.ZERO, cols[0] if i % 2 == 0 else cols[1], 0.6, "shaft", 2.0, _rng.randf_range(40.0, 90.0), 0.0, 0.0)
		shaft.shaft = true
	for i in range(count * 2):
		var at := point + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius) * 0.5)
		emit(at, Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-24.0, -10.0)), cols[_rng.randi_range(0, cols.size() - 1)], _rng.randf_range(0.8, 1.5), "mote", 2.0, _rng.randf_range(0.0, 8.0), 0.0, 0.2)


## Shadow at `point`: a pool of ink welling up there (its top edge catching a
## cold violet light) and `branches` tendrils of ink reaching out of it over
## the floor tip first, up to `reach` px, thick near the pool and thin at
## their tips (a violet rim, else unseen on a dark floor); they hold a moment
## and draw back into the pool tip first, then the pool shrinks from its rim
## (elements.shadow_hold, shadow_back s). Dark motes sink round it.
func shadow(point: Vector2, branches: int, reach: float) -> void:
	var cols := _el("shadow")
	var hold := float(_data.get("elements", {}).get("shadow_hold", 0.5))
	var back := float(_data.get("elements", {}).get("shadow_back", 0.6))
	var start := Vector2(_art(point)) + Vector2(0.5, 0.5)
	# the pool: it lasts until the tendrils are back in it
	var core := maxf(2.0, reach * 0.2 / PIXEL)
	var gone := _time + reach / PIXEL / _ice("rime_rate", 40.0) + hold + back
	var c := _art(point)
	var n := int(ceil(core))
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var q := c + Vector2i(x, y)
			var e := Vector2(float(x), float(y) / 0.75).length() / core
			if e > 1.0 or q.x < 0 or q.y < 0 or solid(_world(q)):
				continue
			# a ragged edge
			if e > 0.6 and float(BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)]) >= (1.0 - e) * 40.0:
				continue
			_put(q, cols[1] if e > 0.65 and y < 0 else cols[0])
			_freeze(q, true, gone + 0.6 * (1.0 - e), 0.15)
	for i in range(branches):
		if _growth.size() >= int(_ice("rime_max", 160)): break
		var left := reach / PIXEL * _rng.randf_range(0.6, 1.0)
		var d := Vector2.from_angle(TAU * float(i) / float(maxi(1, branches)) + _rng.randf_range(-0.3, 0.3))
		_growth.append({"p": start + d * core * 0.7, "d": d, "left": left, "whole": left, "carry": 0.0, "col": cols[0], "rim": cols[1], "gen": 0, "shadow": true, "hold": hold, "back": back})
	for i in range(branches * 2):
		var at := point + Vector2(_rng.randf_range(-reach, reach), _rng.randf_range(-reach, reach) * 0.5) * 0.5
		emit(at, Vector2(_rng.randf_range(-6.0, 6.0), 0.0), cols[1], _rng.randf_range(0.8, 1.4), "sink", 2.0, _rng.randf_range(14.0, 26.0), 0.0, 0.5)


## Freezes the liquid lying within `radius` of `point` in the pool layers
## (src/vfx/pool_paint.gd freeze_near): it freezes from its rim inwards.
func freeze_liquids(point: Vector2, radius: float) -> void:
	for link: Array in _liquids:
		var layer: Object = (link[0] as WeakRef).get_ref()
		if layer != null and layer.has_method("freeze_near"): layer.freeze_near(point * float(link[1]), radius * float(link[1]))


## Fire on Glatteis: the liquid layers' ice at `point` thaws (pool_paint thaw_near).
func thaw_liquids(point: Vector2, radius: float) -> void:
	for link: Array in _liquids:
		var layer: Object = (link[0] as WeakRef).get_ref()
		if layer != null and layer.has_method("thaw_near"): layer.thaw_near(point * float(link[1]), radius * float(link[1]))


## `count` puffs of steam hissing up from `point` (a liquid on lava or fire,
## ice melting, an ember put out): light, quick, thinning by the dither.
func steam(point: Vector2, count: int, radius: float = 4.0) -> void:
	var color := Color(str(_data.get("steam_color", "d8dce6")))
	for i in range(count):
		var spot := point + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius) * 0.6)
		emit(spot, Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-8.0, 2.0)), color, _rng.randf_range(0.6, 1.1), "smoke", 4.0, 2.0, _rng.randf_range(40.0, 80.0), 0.8)


## True when a pool layer holds a liquid (poison, blood, water) under `point`.
func _in_liquid(point: Vector2) -> bool:
	for link: Array in _liquids:
		var layer: Object = (link[0] as WeakRef).get_ref()
		if layer != null and layer.wet_at(point * float(link[1])): return true
	return false


## `count` puffs of smoke rising from `point` (spread `radius` px).
func smoke(point: Vector2, count: int, radius: float = 6.0) -> void:
	var color := Color(str(_data.get("smoke_color", "2e2a2c")), 0.55)
	var lift: Array = _mode("smoke").get("lift", [10, 30])
	for i in range(count):
		var spot := point + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius) * 0.6)
		emit(spot, Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-10.0, 4.0)), Color(color, color.a * _rng.randf_range(0.6, 1.0)), _rng.randf_range(1.2, 2.2), "smoke", 4.0, 2.0, _rng.randf_range(float(lift[0]), float(lift[1])), 0.6)


## The pool layers (src/vfx/pool_paint.gd) whose liquid a blast rings, each
## with the scale from these particles' units to its world px (story worlds 1.5).
func add_liquid(layer: Object, scale: float) -> void:
	if layer != null: _liquids.append([weakref(layer), scale])


## Sets the layers anew (see add_liquid).
func set_liquids(layers: Array) -> void:
	_liquids = []
	for link: Array in layers:
		if link[0] != null: _liquids.append([weakref(link[0]), float(link[1])])


## A wet step or dot of `color` at `point` that dries away after `dry_after` s
## (left as it is when something was painted over it meanwhile).
func wet(point: Vector2, color: Color, dry_after: float) -> void:
	var art := _art(point)
	if art.x < 0 or art.y < 0 or solid(_world(art)): return
	_put(art, color)
	_damp.append([art, _time + dry_after, color])


## A blast at `point` lifts what lies on the floor within `radius`: every loose
## debris pixel flies off again, pools and stains splash apart a little, and
## the liquid of the pools nearby rings (set_liquids).
## `strength` 1 is an ordinary explosion (vfx_particles.json "kick").
func kick(point: Vector2, radius: float, strength: float = 1.0) -> void:
	for link: Array in _liquids:
		var layer: Object = (link[0] as WeakRef).get_ref()
		if layer != null: layer.ripple_near(point * float(link[1]), radius * float(link[1]), strength)
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
	_vapor.clear()
	_water.clear()
	_water_head = 0
	_frozen.clear()
	_wet.clear()
	_damp.clear()
	_damp_head = 0
	_growth.clear()
	_wells.clear()
	_implosions.clear()


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
	_grow_rime(delta)
	_step_wells(delta)
	_step_implosions()
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
		elif particle.has("shaft") and float(particle.z) <= 0.5:
			var star := emit(Vector2(particle.pos), Vector2.ZERO, particle.color, 0.1, "spark", 2.0, 0.0, 0.0, 0.0)
			star.erase("streak")
			star.plus = true
			_particles.remove_at(i)
			continue
		elif float(particle.life) <= 0.0:
			if particle.has("smoke_p") and _rng.randf() < float(particle.smoke_p):
				var color := Color(str(_data.get("smoke_color", "2e2a2c")))
				emit(Vector2(particle.pos), Vector2(particle.vel) * 0.3, color, _rng.randf_range(0.8, 1.4), "smoke", 4.0, float(particle.z), _rng.randf_range(10.0, 25.0), 0.6)
			_particles.remove_at(i)
			continue
		_move(particle, delta)
		if bool(particle.get("burst", false)):
			_break_shard(particle)
			_particles.remove_at(i)


## Floor-plane motion with wall bounces, then height with gravity and floor bounces.
func _move(particle: Dictionary, delta: float) -> void:
	var position: Vector2 = particle.pos
	var velocity: Vector2 = particle.vel
	var next := position + velocity * delta
	if bool(particle.free):
		# Born inside a wall: it may leave, and walls count from then on.
		if not solid(next): particle.free = false
	elif solid(next):
		# a shard hitting a wall hard breaks; a slow one clinks off it
		if particle.has("shard") and velocity.length() > _ice("shatter_speed", 150.0) and int(particle.len) > 1:
			particle.burst = true
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
	if particle.has("shard"):
		if float(particle.z) > 0.5:
			# a flying shard turns in steps, one facing at a time
			particle.turn = float(particle.get("turn", 0.0)) + delta * 12.0
			if float(particle.turn) >= 1.0:
				particle.turn = float(particle.turn) - 1.0
				particle.shard = posmod(int(particle.shard) + int(particle.spin), 8)
		elif velocity.length() > 40.0:
			# skittering over the stones it is knocked round now and then
			particle.turn = float(particle.get("turn", 0.0)) + delta * velocity.length() / 30.0
			if float(particle.turn) >= 1.0:
				particle.turn = float(particle.turn) - 1.0
				particle.shard = posmod(int(particle.shard) + int(particle.spin), 8)
			# a frost trail only when asked for (scratch_every 0: none)
			var every := _ice("scratch_every", 0.0)
			if every > 0.0:
				particle.scratch = float(particle.get("scratch", 0.0)) + velocity.length() * delta
				if float(particle.scratch) >= every:
					particle.scratch = 0.0
					_scratch(next, particle)
	var gravity := float(particle.gravity)
	if gravity != 0.0:
		particle.vz = float(particle.vz) - gravity * delta
		particle.z = float(particle.z) + float(particle.vz) * delta
		if gravity > 0.0 and float(particle.z) <= 0.0:
			particle.z = 0.0
			if float(particle.vz) < -float(_data.get("bounce_min", 70)):
				# ice hardly bounces and keeps sliding
				var shard := particle.has("shard")
				particle.vz = -float(particle.vz) * (_ice("bounce", 0.15) if shard else float(_data.get("bounce", 0.35)))
				velocity *= 0.9 if shard else 0.6
				# where ice strikes the floor it leaves a fleck of frost
				if shard:
					_scratch(next, particle)
				# rubble is heavy: one low bounce, then it stays down
				if particle.has("rock"):
					if bool(particle.get("bounced", false)): particle.vz = 0.0
					else: particle.vz = float(particle.vz) * 0.5
					particle.bounced = true
			else:
				particle.vz = 0.0
	var on_floor: bool = float(particle.z) <= 0.0 and float(particle.vz) == 0.0 and gravity > 0.0
	if on_floor and particle.has("shard"):
		# ice on stone: an even grip (dry friction), so it skids a short way and stops
		var speed := velocity.length()
		if speed > 0.01:
			velocity *= maxf(0.0, speed - _ice("slide_decel", 280.0) * delta) / speed
	var friction := _ice("friction", 1.4) if particle.has("shard") else (18.0 if particle.has("rock") else float(_data.get("ground_friction", 9)))
	var drag := float(particle.drag) + (friction if on_floor else 0.0)
	particle.vel = velocity * maxf(0.0, 1.0 - drag * delta)


## The oldest particle makes room: debris lands where it is, the rest vanishes.
func _evict() -> void:
	var oldest: Dictionary = _particles.pop_front()
	if bool(oldest.settle): _settle(oldest)


## A resting debris particle becomes loose floor pixels (only on the floor);
## settled frost melts later.
func _settle(particle: Dictionary) -> void:
	if bool(particle.free): return
	# a shard at rest lies as frost pixels along its facing (they melt later)
	if particle.has("shard"):
		if sinks(Vector2(particle.pos)):
			steam(Vector2(particle.pos), 1, 1.0)
			return
		var colours: Array = particle.ice
		var face: Vector2i = DIR8[int(particle.shard)]
		var n := int(particle.len)
		var middle := _art(Vector2(particle.pos))
		for k in range(n):
			var q := middle + face * (k - n / 2)
			if q.x < 0 or q.y < 0 or solid(_world(q)): continue
			_put(q, colours[1] if k == n - 1 else colours[2])
			_loose[q] = true
			_freeze(q)
		return
	# a drop of a pool comes down: its pool takes it (src/vfx/pool_paint.gd drop_landed)
	if particle.has("land_ref"):
		var layer: Object = (particle.land_ref as WeakRef).get_ref()
		if layer != null: layer.drop_landed(Vector2(particle.pos), str(particle.get("land_mat", "")))
		return
	# what falls into a sinking liquid (lava) is gone; frost hisses there
	if sinks(Vector2(particle.pos)):
		if str(particle.get("mode", "")) == "frost": steam(Vector2(particle.pos), 1, 1.0)
		return
	# a glowing pixel lies down as an ember again, as hot as it still is; in a
	# liquid it goes out with a hiss
	if str(particle.get("mode", "")) == "glut" and _in_liquid(Vector2(particle.pos)):
		steam(Vector2(particle.pos), 1, 1.0)
		return
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
	# a drop of a liquid lands as a small splat (it joins the stain it falls into)
	if str(particle.get("mode", "")) == "drop":
		var wet := Color(color.darkened(0.2), 1.0)
		_disc(Vector2(particle.pos), maxf(PIXEL, float(particle.size) * 0.6), wet)
		if _rng.randf() < 0.5:
			_disc(Vector2(particle.pos) + Vector2.from_angle(_rng.randf() * TAU) * float(particle.size), PIXEL * 0.6, wet)
		return
	var tint := Color(color.darkened(0.15), minf(0.95, color.a))
	var cells := maxi(1, roundi(float(particle.size) / PIXEL))
	var frozen: bool = str(particle.get("mode", "")) == "frost" or bool(particle.get("melts", false))
	# The pixel under the particle, grown up-left for bigger chunks.
	var corner := _art(Vector2(particle.pos)) - Vector2i(cells / 2, cells / 2)
	for y in range(cells):
		for x in range(cells):
			var art := corner + Vector2i(x, y)
			if art.x < 0 or art.y < 0 or solid(_world(art)): continue
			_blend(art, tint, false)
			_loose[art] = true
			if frozen: _freeze(art, bool(particle.get("vapor", false)))


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
	draw_rime_tips(canvas)
	_draw_implosions(canvas)
	var beat := int(_time * 12.0)
	for particle: Dictionary in _particles:
		var alpha := 1.0
		if bool(particle.fade): alpha = clampf(float(particle.life) / (float(particle.max_life) * 0.5), 0.0, 1.0)
		var size: float = particle.size
		var ground: Vector2 = particle.pos
		var height: float = particle.z
		var color: Color = particle.color
		if particle.has("ramp"):
			# a flame: hot to cool as it ages, thinner, and it changes its shape on the beat
			var age := 1.0 - clampf(float(particle.life) / float(particle.max_life), 0.0, 1.0)
			var ramp: Array = particle.ramp
			color = ramp[clampi(int(age * float(ramp.size())), 0, ramp.size() - 1)]
			size = maxf(PIXEL, roundf(size * (1.0 - 0.6 * age) / PIXEL) * PIXEL)
		if particle.has("seed"):
			ground.x += float(posmod((beat + int(particle.seed)) * 7, 3) - 1) * PIXEL * 0.5
		# Airborne chunks cast a pixel shadow on the floor under them.
		if size >= 4.0 and height > 3.0 and bool(particle.settle):
			canvas.draw_rect(Rect2(_snap(ground - Vector2(size * 0.5, 0.0)), Vector2(size, PIXEL)), Color(0, 0, 0, 0.22))
		if particle.has("rock"):
			# a chunk of rubble: lit top row, dark bottom row
			var rc: Array = particle.rock
			var w := maxi(1, roundi(size / PIXEL))
			var corner := Vector2i(((ground - Vector2(0.0, height)) / PIXEL).floor()) - Vector2i(w / 2, w / 2)
			if height > 3.0:
				canvas.draw_rect(Rect2(_snap(ground - Vector2(size * 0.5, 0.0)), Vector2(size, PIXEL)), Color(0, 0, 0, 0.22))
			for y in range(w):
				for x in range(w):
					canvas.draw_rect(Rect2(Vector2(corner + Vector2i(x, y)) * PIXEL, Vector2(PIXEL, PIXEL)), rc[0] if y == 0 else (rc[2] if y == w - 1 and w > 1 else rc[1]))
			continue
		if particle.has("shaft"):
			# a shaft of light falling: a short vertical streak
			var q := Vector2i(((ground - Vector2(0.0, height)) / PIXEL).floor())
			for k in range(3):
				canvas.draw_rect(Rect2(Vector2(q + Vector2i(0, -k)) * PIXEL, Vector2(PIXEL, PIXEL)), color if k == 0 else color.darkened(0.25 * float(k)))
			continue
		if particle.has("plus"):
			var q := Vector2i(((ground - Vector2(0.0, height)) / PIXEL).floor())
			for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				canvas.draw_rect(Rect2(Vector2(q + d) * PIXEL, Vector2(PIXEL, PIXEL)), color)
			continue
		if particle.has("streak"):
			# a mote of the void: a short streak along its flight, bright at its head
			var head := Vector2i(((ground - Vector2(0.0, height)) / PIXEL).floor())
			var back := -Vector2(particle.vel)
			var step := Vector2i(roundi(signf(back.x)) if absf(back.x) > absf(back.y) * 0.5 else 0, roundi(signf(back.y)) if absf(back.y) > absf(back.x) * 0.5 else 0)
			var shown := alpha
			for k in range(3 if Vector2(particle.vel).length() > 60.0 else 2):
				var q := head + step * k
				if float(BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)]) >= shown * 16.0: continue
				canvas.draw_rect(Rect2(Vector2(q) * PIXEL, Vector2(PIXEL, PIXEL)), color if k == 0 else color.darkened(0.35 * float(k)))
			continue
		if particle.has("shard"):
			# a shard: a line of pixels in its facing, a dark edge under it, its tip lit
			var cols: Array = particle.ice
			var face: Vector2i = DIR8[int(particle.shard)]
			var n := int(particle.len)
			var middle := Vector2i(((ground - Vector2(0.0, height)) / PIXEL).floor())
			if height > 3.0:
				canvas.draw_rect(Rect2(_snap(ground), Vector2(PIXEL, PIXEL)), cols[4])
			for k in range(n):
				var q := middle + face * (k - n / 2) + Vector2i(0, 1)
				canvas.draw_rect(Rect2(Vector2(q) * PIXEL, Vector2(PIXEL, PIXEL)), cols[4])
			for k in range(n):
				var q := middle + face * (k - n / 2)
				canvas.draw_rect(Rect2(Vector2(q) * PIXEL, Vector2(PIXEL, PIXEL)), cols[1] if k == n - 1 else cols[2])
			continue
		if particle.has("ramp"):
			# a flame is a tongue: one row taller than wide, its tip narrower
			var w := maxi(1, roundi(size / PIXEL))
			var base := _snap(ground - Vector2(0.0, height)) + Vector2(0.0, size * 0.5)
			# hotter at its root, cooler at its tip: a step of the ramp each way
			var tongue: Array = particle.ramp
			var step := clampi(int((1.0 - clampf(float(particle.life) / float(particle.max_life), 0.0, 1.0)) * float(tongue.size())), 0, tongue.size() - 1)
			for row in range(w + 1):
				var across := w if row < w else maxi(1, w - 2)
				if w >= 3 and row == w - 1: across = maxi(1, w - 1)
				var shade: Color = tongue[maxi(0, step - 1)] if row == 0 else (tongue[mini(tongue.size() - 1, step + 1)] if row >= w - 1 else color)
				canvas.draw_rect(Rect2(base + Vector2(-float(across) * PIXEL * 0.5, -float(row + 1) * PIXEL).snapped(Vector2(PIXEL, PIXEL)), Vector2(float(across) * PIXEL, PIXEL)), shade)
			continue
		var top := _snap(ground - Vector2(0.0, height) - Vector2(size, size) * 0.5)
		if alpha >= 1.0:
			canvas.draw_rect(Rect2(top, Vector2(size, size)), color)
			continue
		# fading (smoke, dust, sparks) thins out by the ordered dither, pixel by
		# pixel, instead of turning see-through
		var cells := maxi(1, roundi(size / PIXEL))
		var corner := Vector2i((top / PIXEL).round())
		for y in range(cells):
			for x in range(cells):
				var q := corner + Vector2i(x, y)
				if float(BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)]) < alpha * 16.0:
					canvas.draw_rect(Rect2(Vector2(q) * PIXEL, Vector2(PIXEL, PIXEL)), color)


## The growing tips of the rime: a bright pixel where each branch grows.
func draw_rime_tips(canvas: CanvasItem) -> void:
	if _growth.is_empty(): return
	var tip: Color = _ice_ramp()[0]
	for branch: Dictionary in _growth:
		# a spreading crust has no tip
		if not branch.has("p"):
			continue
		canvas.draw_rect(Rect2(Vector2(Vector2i((branch.p as Vector2).floor())) * PIXEL, Vector2(PIXEL, PIXEL)), tip)


## Glowing particles (sparks, embers, frost) light up in the bloom layer.
func draw_glow(canvas: CanvasItem, level: float) -> void:
	if level <= 0.0: return
	for particle: Dictionary in _particles:
		if not bool(particle.glow): continue
		var alpha := clampf(float(particle.life) / (float(particle.max_life) * 0.5), 0.0, 1.0) if bool(particle.fade) else 1.0
		var point: Vector2 = Vector2(particle.pos) - Vector2(0.0, float(particle.z))
		# a spark seen against a wall does not light the wall up (no glow through walls)
		if solid(point): continue
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


## Marks the pixel at `art` as frost (as it looks now) and schedules its melting
## (at `due` when given); `vapor` frost goes without water, later by its place
## in a 4x4 ordered dither so a clump thins out in a pattern, not at once.
func _freeze(art: Vector2i, vapor := false, due := -1.0, spread := 1.0) -> void:
	var settings_for_frost: Dictionary = _data.get("frost", {})
	if _frost.size() - _frost_head >= int(settings_for_frost.get("max", 4000)): _frost_head += 1
	var melt: Array = settings_for_frost.get("melt_after", [6.0, 10.0])
	if due < 0.0: due = _time + _rng.randf_range(float(melt[0]), float(melt[1]))
	_frozen[art] = _pixel(art)
	if vapor:
		if _vapor.size() >= int(settings_for_frost.get("max", 4000)): _vapor.pop_front()
		_vapor.append([art, due + float(BAYER[posmod(art.y, 4) * 4 + posmod(art.x, 4)]) / 16.0 * float(settings_for_frost.get("vapor_spread", 1.2)) * spread])
		return
	_frost.append([art, due])


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
	# vapor frost: every due pixel goes, the rest keep their order
	if not _vapor.is_empty():
		var keep := 0
		for index in range(_vapor.size()):
			var entry: Array = _vapor[index]
			if float(entry[1]) > _time:
				_vapor[keep] = entry
				keep += 1
				continue
			var spot: Vector2i = entry[0]
			if not _frozen.has(spot): continue
			var same: bool = _pixel(spot) == _frozen[spot]
			_frozen.erase(spot)
			if same:
				_put(spot, Color(0, 0, 0, 0))
				_loose.erase(spot)
		_vapor.resize(keep)
	# wet steps and dots dry away in the order they were left
	while _damp_head < _damp.size() and float(_damp[_damp_head][1]) <= _time:
		var entry: Array = _damp[_damp_head]
		_damp_head += 1
		if _pixel(entry[0]) == entry[2]: _put(entry[0], Color(0, 0, 0, 0))
	if _damp_head > 256:
		_damp = _damp.slice(_damp_head)
		_damp_head = 0
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
