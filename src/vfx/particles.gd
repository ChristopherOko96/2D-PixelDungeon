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
## liquid splats are pixel matter (a grain of shades, ragged lobed rims, drops
## and streaks along the throw) that keeps creeping outwards, dries darker and
## then fades rim first to a few faint specks; fire leaves glowing embers that
## smoke and turn to soot, frost melts to water that dries; a frost crust
## (frost_crust) lies lit along its edges, glints and melts rim first.
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
##
## A body flung against a wall bursts in its material (splat_burst, the
## Leerenmagier's Urknall; vfx_gore.json "splat"): flesh sprays blood back off
## the wall, its chunks fly, bounce and lie, and blood splats on the floor and
## runs down the wall (wall_splat); bone throws splinters and a dust cloud and
## its skull rolls away (a 3x3 skull turning a quarter every few px, lying
## where it stops); the void throws motes; gold coins bounce and glint.
##
## The Leerenmagier's Gefüge fuses (fuse_feed, user 2026-11-01): blobs of its elements float in
## the Singularität's well and swirl in with the rest, but the core keeps them; two that touch
## fuse into one heavier blob holding both their elements (lumps of each, flickering fire, glinting
## ice), and where their elements react they do it in matter (steam, sparks, splinters). Each
## blob throws off bits of its own elements (flames, drops, slivers) that the well swirls in again;
## at the collapse the host takes the fused matter out (fuse_take) and throws it as comets.
##
## Matter, not paint (review 2026-10-31, BEFUND.md 5/7): the talents' flying
## bits live here. Snow flakes (snow; modes.flake) float down nearly
## weightless, flutter on the beat, lie as frost and melt. Lying ice shards
## glint now and then while their frost lasts (ice.glint_*). A comet (comet;
## the Urknall's Gefuege units) flies a ballistic arc solved for its landing
## spot and lands by what it is: a liquid or fire blob splashes (a crown of
## droplets thrown on, the rest a small puddle in the pool layer through
## drop_landed), ice breaks into chips, bone and gold bounce and lie, a soul
## streak puffs into motes. Cosmetic emitters ask room() first: above
## soft_cap of max_particles they throw fewer, at the cap none, so the
## collapse of an ultimate stays under the limit. Glow is tight to the pixel
## (glow: radius, per_size, alpha_cap).

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
## The gore table (materials' colours and the splat classes).
const GORE_PATH := "res://assets/data/vfx_gore.json"
## A rolling skull's 3x3 cells, row by row: 0 bone, 1 shade, 2 socket.
const SKULL := ["000", "202", "101"]
## The gore table, read on first use.
static var _gore: Dictionary = {}

## Room key of the floor cells in use (the view sets the layout when it changes).
var layout_key := ""
var _particles: Array[Dictionary] = []
## The world's wind (particle px/s; the Frostgruft's snowstorm, physics plan F58/D12): light
## matter drifts towards it by its mode's "wind" share (vfx_particles.json modes), heavy matter
## not at all.
var wind := Vector2.ZERO
## Floor cells (32 px) where something solid stands: closed gates, solid props, unbroken crates and
## urns (set by the host when they change; physics plan R16): matter stops there like at a wall.
var blocked_cells: Dictionary = {}
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
## Creeping liquid pools: {center, color, ramp, px, frontier, budget, carry, dir, reach, scan, done}.
var _pools: Array[Dictionary] = []
## Dried marks fading rim first (_fade_later): {px, col, i, t0, t1, keep}.
var _fading: Array[Dictionary] = []
## Glowing embers on the floor: {art, life, max, smoke}.
var _embers: Array[Dictionary] = []
## Frost pixels waiting to melt and water pixels waiting to dry: [art, due time].
var _frost: Array = []
## Frost that goes without water (vapor): [art, due time], checked every frame
## so it leaves in its dither order.
var _vapor: Array = []
## The earliest due time in _vapor (INF when empty): the list is scanned only once it comes
## (physics plan R19).
var _vapor_next := INF
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
## Glints on lying ice shards: [art px, until, seed] (a spec pixel flashing on
## the beat while its frost lies; ice.glint_*).
var _glints: Array = []
## The 8 facings of an ice shard (art px steps).
const DIR8 := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
## Wet steps and dots that dry away: [art, due time, colour] (wet()).
var _damp: Array = []
var _damp_head := 0
## The pool layers blasts ring (src/vfx/pool_paint.gd ripple_near): [WeakRef, scale to their px].
var _liquids: Array = []
## Sound sink (src/vfx/sfx.gd attach_particles): one sound per call below, the
## landing ticks of _settle; null keeps the particles silent (tests, the crypt).
var sound: Object = null
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


## True when nothing solid lies on the straight line from `from` to `to` (world px): a walk over
## the 32 px floor cells (DDA) that stops at the first wall cell. Blasts, pushes and wells act
## only on what they can reach (physics plan R16/F5). `seen` caches cell -> answer for one call.
func sees(from: Vector2, to: Vector2, seen: Dictionary = {}) -> bool:
	if _walkable.is_empty(): return true
	var goal := Vector2i(floori(to.x / 32.0), floori(to.y / 32.0))
	if seen.has(goal): return bool(seen[goal])
	var cell := Vector2i(floori(from.x / 32.0), floori(from.y / 32.0))
	var d := to - from
	var step := Vector2i(1 if d.x > 0.0 else -1, 1 if d.y > 0.0 else -1)
	var next := Vector2((float(cell.x) + (1.0 if d.x > 0.0 else 0.0)) * 32.0, (float(cell.y) + (1.0 if d.y > 0.0 else 0.0)) * 32.0)
	var t_max := Vector2((next.x - from.x) / d.x if absf(d.x) > 0.0001 else INF, (next.y - from.y) / d.y if absf(d.y) > 0.0001 else INF)
	var t_delta := Vector2(32.0 / absf(d.x) if absf(d.x) > 0.0001 else INF, 32.0 / absf(d.y) if absf(d.y) > 0.0001 else INF)
	var ok := true
	for i in range(64):
		if cell == goal: break
		if t_max.x < t_max.y:
			cell.x += step.x
			t_max.x += t_delta.x
		else:
			cell.y += step.y
			t_max.y += t_delta.y
		if not _walkable.has(cell):
			ok = false
			break
	seen[goal] = ok
	return ok


## True when `point` (world px) is inside a wall. Without a room every point is open.
func solid(point: Vector2) -> bool:
	if _walkable.is_empty(): return false
	var cell := Vector2i(floori(point.x / 32.0), floori(point.y / 32.0))
	return not _walkable.has(cell) or blocked_cells.has(cell)


## Throws `count` square particles from `origin` (where they are seen, `height`
## px above the floor point under it; -1 = spawn_height). `direction` biases the
## spread in the floor plane (Vector2.ZERO = all around); `drag` slows them.
## `mode` is one of vfx_particles.json "modes": debris lands and stays as floor
## pixels, spark and ember glow and fade, dust floats and fades.
## Sound hook: one sound for this call at `point` (particle units), its level by `count`.
func _sound(kind: String, point: Vector2, count: int) -> void:
	if sound != null: sound.particle(kind, point, count)


func burst(origin: Vector2, color: Color, count: int, speed: float, life: float, direction: Vector2 = Vector2.ZERO, spread: float = PI, size: float = 3.0, drag: float = 5.0, mode: String = "debris", height: float = -1.0) -> void:
	_sound("burst_" + mode, origin, count)
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
	# snow lies as frost that melts
	if bool(settings_for_mode.get("melts", false)): particle.melts = true
	_particles.append(particle)
	return particle


func _mode(mode: String) -> Dictionary:
	return _data.get("modes", {}).get(mode, {"gravity": 1.0, "lift": [40, 150], "settle": true, "glow": false, "fade": false})


## How many of `count` cosmetic particles may still be thrown: all of them
## while fewer than soft_cap x max_particles fly, fewer and fewer above that
## and none at the limit, rounded by chance so small asks still get some
## (vfx_particles.json soft_cap). `weight` > 0 (an ultimate's own matter)
## always gets its full share.
func room(count: int, weight := 0) -> int:
	if weight > 0 or count <= 0: return count
	var most := float(_data.get("max_particles", MAX_PARTICLES))
	var soft := most * float(_data.get("soft_cap", 0.8))
	var have := float(_particles.size())
	if have <= soft: return count
	var keep := float(count) * clampf((most - have) / maxf(1.0, most - soft), 0.0, 1.0)
	return int(keep) + (1 if _rng.randf() < keep - floorf(keep) else 0)


## Leaves a splat of a few overlapping rectangles on the floor.
func stain(origin: Vector2, color: Color, radius: float) -> void:
	# a liquid that swallows what lands in it (lava, a pit) takes no mark (physics plan R2)
	if sinks(origin): return
	_marks += 1
	var tint := Color(color.darkened(0.35), 0.55)
	for i in range(5):
		var offset := Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius * 0.5, radius * 0.5))
		var extent := Vector2(_rng.randf_range(radius * 0.4, radius), _rng.randf_range(radius * 0.25, radius * 0.5))
		var corner := _art(origin + offset - extent * 0.5)
		var size := Vector2i(maxi(1, roundi(extent.x / PIXEL)), maxi(1, roundi(extent.y / PIXEL)))
		for row in range(size.y): _span(corner.y + row, corner.x, corner.x + size.x - 1, tint, true)


## A liquid splat on the floor as pixel matter (vfx_particles.json liquid): a
## ragged, lobed body of single pixels in a grain of `color`'s shades (a wet
## glint or two), its rim thinner; a few smaller blobs round it; drops and
## short streaks thrown along `direction` (the hit's direction). `alpha` is
## the rim's opacity, the body a little more (core_alpha). It creeps on,
## dries darker and then fades rim first, leaving a few faint specks.
func splat(origin: Vector2, color: Color, alpha: float, radius: float, direction: Vector2 = Vector2.ZERO) -> void:
	_sound("splat", origin, int(radius))
	if radius <= 0.0: return
	_marks += 1
	var liquid: Dictionary = _data.get("liquid", {})
	var ramp := _splat_ramp(color, alpha)
	var painted: Array[Vector2i] = []
	var seed := _rng.randi() % 9973
	_blob(origin, radius * _rng.randf_range(0.75, 1.0), ramp, seed, painted)
	for i in range(int(liquid.get("blobs", 3))):
		_blob(origin + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius) * 0.6), radius * _rng.randf_range(0.3, 0.55), ramp, seed + 11 * (i + 1), painted)
	var along: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.from_angle(_rng.randf() * TAU)
	var span: Array = liquid.get("drops", [4, 12])
	var count := clampi(int(radius * float(liquid.get("drops_per_px", 0.5))), int(span[0]), int(span[1]))
	# a streak runs along the throw: its step in art px (one of 8 facings)
	var step := Vector2i(int(signf(along.x)) if absf(along.x) > 0.38 else 0, int(signf(along.y)) if absf(along.y) > 0.38 else 0)
	for i in range(count):
		var spot := origin + along.rotated(_rng.randf_range(-0.6, 0.6)) * radius * _rng.randf_range(1.05, 2.8)
		var head := _art(spot)
		var length := 1 if _rng.randf() < float(liquid.get("single_drops", 0.6)) else _rng.randi_range(2, 3)
		for j in range(length):
			var q := head - step * j
			if q.x < 0 or q.y < 0 or solid(_world(q)): break
			_put(q, ramp[1] if j == 0 else ramp[0])
			painted.append(q)
	_add_pool(origin, ramp, radius, direction, painted)


## One drop of a drip trail behind a wounded enemy: a pixel or three of its
## liquid that dry and fade like a splat.
func drip(origin: Vector2, color: Color, alpha: float, size: float) -> void:
	_sound("drip", origin, 1)
	_marks += 1
	var ramp := _splat_ramp(color, alpha)
	var painted: Array[Vector2i] = []
	var middle := _art(origin)
	var cells: Array[Vector2i] = [middle]
	for i in range(clampi(int(size), 0, 2)):
		cells.append(middle + STEPS[_rng.randi_range(0, 3)])
	for k in range(cells.size()):
		var q: Vector2i = cells[k]
		if q.x < 0 or q.y < 0 or solid(_world(q)): continue
		_put(q, ramp[1] if k == 0 else ramp[0])
		painted.append(q)
	_add_pool(origin, ramp, PIXEL, Vector2.ZERO, painted)


## The shades a splat of `color` is made of: deep, body, lite, a wet glint
## (all at the body's opacity: `alpha` + liquid.core_alpha) and its rim (`alpha`).
func _splat_ramp(color: Color, alpha: float) -> Array:
	var core := clampf(alpha + float(_data.get("liquid", {}).get("core_alpha", 0.25)), 0.0, 1.0)
	return [Color(color.darkened(0.28), core), Color(color, core), Color(color.lightened(0.16), core), Color(color.lightened(0.45), core), Color(color, alpha)]


## One ragged body of a splat: the pixels within `radius` of `centre` (floor
## perspective: flatter than wide), its outline lobed and its rim frayed by
## fixed noise (liquid.ragged), its grain from `ramp` (_splat_ramp); stops
## at walls. The pixels it paints are added to `painted`.
func _blob(centre: Vector2, radius: float, ramp: Array, seed: int, painted: Array[Vector2i]) -> void:
	var middle := _art(centre)
	var across := maxf(1.0, radius / PIXEL)
	var rows := int(ceil(across * 0.75)) + 1
	var cols := int(ceil(across)) + 1
	var rag := float(_data.get("liquid", {}).get("ragged", 0.5))
	var turn := float(seed % 628) / 100.0
	for y in range(-rows, rows + 1):
		for x in range(-cols, cols + 1):
			var q := middle + Vector2i(x, y)
			if q.x < 0 or q.y < 0:
				continue
			var d := Vector2(float(x), float(y) / 0.75).length() / across
			var angle := atan2(float(y), float(x))
			var lobes := sin(angle * 3.0 + turn) * 0.12 + sin(angle * 5.0 + turn * 1.7) * 0.07
			if d + lobes + (MatterKit.cell_noise(q, seed) - 0.5) * rag > 1.0 or solid(_world(q)):
				continue
			var grain := MatterKit.cell_noise(q, seed + 7)
			var col: Color = ramp[1]
			if d > 0.78:
				col = ramp[4] if grain > 0.3 else ramp[0]
			elif grain < 0.2:
				col = ramp[0]
			elif grain > 0.97 and d < 0.6:
				col = ramp[3]
			elif grain > 0.8:
				col = ramp[2]
			_put(q, col)
			painted.append(q)


## A small crack where something struck a wall: jagged dark lines spreading
## from the impact into the wall, away from the floor side.
func crack(origin: Vector2, normal: Vector2) -> void:
	_sound("wall_crack", origin, 4)
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
	if sinks(point): return
	_marks += 1
	for i in range(count):
		var offset := Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf())
		offset.y *= 0.75
		_blend(_art(point + offset), Color(color, color.a * _rng.randf_range(0.5, 1.0)), true)


## Frost crystals: `count` floor pixels of `color` within `radius` of `point`
## that melt to water after a while (vfx_particles.json "frost").
func frost(point: Vector2, radius: float, count: int, color: Color) -> void:
	if sinks(point): return
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


## A crust of ice where frost struck the floor (a thrown ice potion;
## vfx_particles.json ice.crust_*): a ragged, lobed patch of single pixels in
## the ice ramp, lit along its north edges, dark on its south lip, cracks of
## deep ice running through it, a few tips glinting; `splinters` shards fly
## off it, slide and lie. It goes again rim first, thinning by the dither
## (vapor frost: no flat sheet of water is left on the snow).
func frost_crust(point: Vector2, radius: float, splinters := 6) -> void:
	if radius <= 0.0: return
	# (its sound is the splinters' shatter)
	_marks += 1
	var ramp := _ice_ramp()
	var middle := _art(point)
	var across := maxf(2.0, radius / PIXEL)
	var rows := int(ceil(across * 0.75)) + 1
	var cols := int(ceil(across)) + 1
	var seed := _rng.randi() % 9973
	var turn := float(seed % 628) / 100.0
	var rag := _ice("crust_ragged", 0.45)
	var melt: Array = _data.get("frost", {}).get("melt_after", [6.0, 10.0])
	var lasts := _rng.randf_range(float(melt[0]), float(melt[1])) * _ice("crust_melt", 1.5)
	var cells := {}
	for y in range(-rows, rows + 1):
		for x in range(-cols, cols + 1):
			var q := middle + Vector2i(x, y)
			if q.x < 0 or q.y < 0:
				continue
			var d := Vector2(float(x), float(y) / 0.75).length() / across
			var angle := atan2(float(y), float(x))
			var lobes := sin(angle * 3.0 + turn) * 0.12 + sin(angle * 5.0 + turn * 1.3) * 0.07
			if d + lobes + (MatterKit.cell_noise(q, seed) - 0.5) * rag > 1.0 or solid(_world(q)) or sinks(_world(q)):
				continue
			cells[q] = d
	var glint_life: Array = _data.get("ice", {}).get("glint_life", [2.0, 4.5])
	for q: Vector2i in cells:
		var d := float(cells[q])
		var grain := MatterKit.cell_noise(q, seed + 3)
		var col: Color = ramp[2]
		if not cells.has(q + Vector2i.UP):
			# its lit north edge, a spec pixel here and there
			col = ramp[0] if grain > 0.7 else ramp[1]
		elif not cells.has(q + Vector2i.DOWN):
			col = ramp[3]
		elif not cells.has(q + Vector2i.LEFT) or not cells.has(q + Vector2i.RIGHT):
			col = ramp[1]
		elif absi(posmod(q.x - q.y * 2 + seed, 11)) == 0 and grain > 0.35:
			# a crack of deep ice through it
			col = ramp[4]
		elif grain > 0.86:
			col = ramp[1]
		elif grain < 0.12:
			col = ramp[3]
		_put(q, col)
		# it goes rim first (its middle holds longest), thinning by the dither: no flat water sheet
		_freeze(q, true, _time + lasts * (0.55 + 0.45 * (1.0 - d)))
		if (col == ramp[0] or col == ramp[1]) and grain > 0.93 and _glints.size() < int(_ice("glint_max", 80)):
			_glints.append([q, _time + _rng.randf_range(float(glint_life[0]), float(glint_life[1])) * 2.0, _rng.randi() % 97])
	if splinters > 0:
		shatter(point, splinters, Vector2.ZERO, 70.0 + radius, ramp, 2, 2.0)


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
	# embers over lava or a pit hiss out instead of lying on it
	if sinks(point):
		steam(point, 1, radius)
		return
	_sound("embers", point, count)
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
	count = room(count)
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
	_sound("fire_burst", point, int(radius))
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
	_sound("embers", point, count)
	count = room(count)
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
## a glint where they burst; `height` px over the floor where they start
## (-1: 2..10, a hit near the floor; a hand or a dome sets its own).
func shatter(point: Vector2, count: int, dir: Vector2 = Vector2.ZERO, speed: float = 160.0, ramp: Array = [], big: int = 3, height := -1.0) -> void:
	_sound("shatter", point, count)
	count = room(count)
	var colours: Array = ramp if ramp.size() >= 5 else _ice_ramp()
	var lift: Array = _mode("shard").get("lift", [40, 120])
	for i in range(count):
		var out := dir.normalized().rotated(_rng.randf_range(-1.0, 1.0)) if dir.length() > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
		var high := _rng.randf_range(2.0, 10.0) if height < 0.0 else height + _rng.randf_range(0.0, 3.0)
		var shard := emit(point, out * speed * _rng.randf_range(0.4, 1.0), colours[2], _rng.randf_range(2.5, 4.0), "shard", 2.0, high, _rng.randf_range(float(lift[0]), float(lift[1])), 0.2)
		shard.shard = _rng.randi() % 8
		shard.spin = 1 if _rng.randf() < 0.5 else -1
		shard.len = _rng.randi_range(mini(2, big), maxi(1, big))
		shard.ice = colours
	for i in range(mini(3, maxi(1, count / 3))):
		emit(point, Vector2.from_angle(_rng.randf() * TAU) * 60.0, colours[0], 0.12, "spark", 2.0, 6.0 if height < 0.0 else height, 40.0, 4.0)


## `count` snow flakes over the disc of `radius` round `point` (its floor
## point), seen ice.flake_height px over the floor and driven round it at
## `spin` px/s with a pull of ice.flake_pull towards its middle: each a
## single pixel (spec or lite of `ramp`, ice.ramp when empty) that floats down
## nearly weightless with much drag (modes.flake), flutters on the beat,
## lies where it lands as frost and melts later.
func snow(point: Vector2, radius: float, count: int, spin: float, ramp: Array = []) -> void:
	_sound("snow_puff", point, count)
	count = room(count)
	var colours: Array = ramp if ramp.size() >= 5 else _ice_ramp()
	var high: Array = _data.get("ice", {}).get("flake_height", [14, 40])
	var pull := _ice("flake_pull", 0.25)
	var drag := float(_mode("flake").get("drag", 1.2))
	for i in range(count):
		var off := Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf())
		off.y *= 0.75
		var turn := off.orthogonal().normalized() if off.length() > 0.5 else Vector2.RIGHT
		var near := 1.0 - clampf(off.length() / maxf(1.0, radius), 0.0, 1.0)
		var velocity := turn * spin * (0.5 + 0.8 * near) - off.normalized() * absf(spin) * pull * _rng.randf()
		var h := _rng.randf_range(float(high[0]), float(high[1]))
		var flake := emit(point + off - Vector2(0.0, h), velocity, colours[0] if _rng.randf() < 0.3 else colours[1], _rng.randf_range(2.5, 4.5), "flake", 2.0, h, 0.0, drag)
		flake.seed = _rng.randi() % 997


## A comet of matter flung from the floor point `from` (leaving `height` px
## over it) to land on the floor point `to` after `time` s: a ballistic arc
## (no drag; its speed and lift solved for the landing), `n` drops of it
## following a little behind and short (comet.trail_*). How it lands is what
## it is (`kind`): "drop" liquid and "glut" fire splash where they hit (a
## crown of droplets thrown on along the flight, the rest a small puddle of
## `mat` in the pool `layer` through its drop_landed; floor pixels or embers
## without one), "shard" ice breaks into chips there and lies as frost (its
## puddle the layer's too), "chip" bone or gold bounces and lies, "mote" a
## soul streak flies straight, sinks and puffs into motes. `cols` spec, lite,
## body, shade, deep (the particles' order). The units it carries (`n`)
## size its splash. Never skipped: it is the matter of a landing that hurts.
func comet(from: Vector2, to: Vector2, time: float, cols: Array, kind: String, n: int = 1, layer: Object = null, mat := "", height := 10.0) -> void:
	_sound("comet", from, n)
	if cols.size() < 5: return
	var t := maxf(0.08, time)
	var mode: String = {"drop": "drop", "glut": "glut", "shard": "shard", "chip": "debris", "mote": "mote"}.get(kind, "drop")
	var g := float(_data.get("gravity", 620)) * float(_mode(mode).get("gravity", 1.0))
	var spec: Dictionary = _data.get("comet", {})
	var trail := clampi(n, 0, int(spec.get("trail_max", 3)))
	var back := (from - to).normalized() if from.distance_to(to) > 1.0 else Vector2.ZERO
	for k in range(trail + 1):
		# the lead, then its drops: each a little later and a little short of it
		var tk := t * (1.0 + float(k) * float(spec.get("trail_lag", 0.06)))
		var land := to + back * float(k) * float(spec.get("trail_gap", 3.0)) + Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-1.5, 1.5)) * float(k)
		var velocity := (land - from) / tk
		var lift := (0.5 * g * tk * tk - height) / tk if g > 0.0 else 0.0
		var colour: Color = cols[1] if k == 0 else cols[2 + (k % 2)]
		var p := emit(from - Vector2(0.0, height), velocity, colour, tk + 2.0 if g > 0.0 else tk, mode, 4.0 if k == 0 else 2.0, height, lift, 0.0)
		p.free = false
		match kind:
			"drop", "glut":
				p.splash = n if k == 0 else 0
				if layer != null:
					p.land_ref = weakref(layer)
					p.land_mat = mat
				if kind == "glut": p.ember_life = _rng.randf_range(1.2, 2.2)
			"shard":
				p.shard = _rng.randi() % 8
				p.spin = 1 if _rng.randf() < 0.5 else -1
				p.len = 3 if k == 0 else 2
				p.ice = cols
				# the lead breaks where it strikes; the chips behind it skid and lie
				if k == 0:
					p.splash = n
					if layer != null:
						p.land_ref = weakref(layer)
						p.land_mat = mat
			"mote":
				p.streak = true
				p.z_to = 2.0
				if k == 0: p.pop = cols


## A comet's blob striking the floor (comet): a crown of droplets thrown on
## along its flight (comet.crown plus one per unit, fewer when the room is
## full), the rest lying as a small puddle round the spot, comet.cells per
## unit (at most cells_max): pool cells of its layer, else floor pixels, fire
## as embers, ice as frost; ice breaks into chips.
func _land_splash(particle: Dictionary) -> void:
	_sound("land_splash", Vector2(particle.pos), 1)
	var spec: Dictionary = _data.get("comet", {})
	var at: Vector2 = particle.pos
	var units := int(particle.get("splash", 0))
	var vel: Vector2 = particle.vel
	var mode := str(particle.get("mode", "drop"))
	var ice := particle.has("shard")
	var layer: Object = (particle.land_ref as WeakRef).get_ref() if particle.has("land_ref") else null
	var crown := room(int(spec.get("crown", 3)) + mini(units, 4)) if units > 0 else 0
	var ahead := vel.normalized() if vel.length() > 1.0 else Vector2.ZERO
	for i in range(crown):
		var out := ahead.rotated(_rng.randf_range(-1.2, 1.2)) * vel.length() * _rng.randf_range(0.12, 0.35) if ahead != Vector2.ZERO else Vector2.from_angle(_rng.randf() * TAU) * 40.0
		var drop := emit(at, out, particle.color if i % 2 else Color(particle.color).lightened(0.2), 1.5, mode, 2.0, 1.0, _rng.randf_range(40.0, 100.0), 1.0)
		drop.free = false
		if ice:
			drop.shard = _rng.randi() % 8
			drop.spin = 1
			drop.len = 1
			drop.ice = particle.ice
		elif layer != null:
			drop.land_ref = particle.land_ref
			drop.land_mat = particle.get("land_mat", "")
	if units <= 0 and not ice:
		_settle(particle)
		return
	var cells := mini(int(spec.get("cells", 4)) * maxi(1, units), int(spec.get("cells_max", 18)))
	var reach := PIXEL * (1.0 + sqrt(float(cells)) * float(spec.get("spread", 0.8)))
	var colour: Color = particle.color
	for k in range(cells):
		var spot := at + (Vector2.from_angle(_rng.randf() * TAU) * reach * sqrt(_rng.randf()) + ahead * reach * 0.5 * _rng.randf()) * Vector2(1.0, 0.75)
		if solid(spot): continue
		if layer != null: layer.drop_landed(spot, str(particle.get("land_mat", "")))
		elif mode == "glut": embers(spot, PIXEL, 1)
		elif ice:
			var q := _art(spot)
			_put(q, (particle.ice as Array)[1 if k % 3 == 0 else 2])
			_freeze(q)
		else: _disc(spot, PIXEL * 0.6, Color(colour.darkened(0.2), 1.0))
	if mode == "glut": embers(at, reach * 0.6, 2 + units)
	if ice: _settle(particle)


## A shard that hit a wall hard breaks into 3-5 chips flying back off it.
func _break_shard(particle: Dictionary) -> void:
	_sound("shard_break", Vector2(particle.pos), 1)
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
	_sound("rime_grow", point, branches)
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
			var n := MatterKit.cell_noise(q, int(patch.seed))
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
## `suck` false leaves the floor alone (a wind, the Blizzard's swirl).
func well(key: String, point: Vector2, radius: float, pull: float, spin: float, core: float, ttl: float = 0.2, motes: float = 0.0, ramp: Array = [], suck := true) -> void:
	var w: Dictionary = _wells.get(key, {"carry": 0.0, "suck": 0.0})
	w.floor = suck
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
	_sound("implode", point, int(radius))
	var cols: Array = ramp if ramp.size() >= 5 else _void_ramp()
	var hold := _void("implode_time", 0.28)
	well("implode:%d" % _implosions.size() + str(_time), point, radius * 1.5, _void("implode_pull", 420.0), _void("implode_spin", 160.0), radius * 0.12, hold, 0.0, cols)
	for i in range(room(int(radius * 0.4))):
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
		var seen_cells := {}
		# everything in reach swirls in, faster the closer it gets; the core swallows it
		for index in range(_particles.size() - 1, -1, -1):
			var particle: Dictionary = _particles[index]
			# Gefüge matter (fuse_feed) answers only its own well
			var own := particle.has("fuse")
			if own and str(particle.fuse) != key: continue
			var off: Vector2 = p - Vector2(particle.pos)
			var d := off.length()
			if d >= r: continue
			# the well pulls only what it reaches, not what lies behind a wall (F5)
			if not sees(p, Vector2(particle.pos), seen_cells): continue
			if own and d <= core + float(particle.size) * 0.5:
				# the core keeps Gefüge matter: it sinks into it and stays there, nearly still
				particle.vel = (Vector2(particle.vel) + off * _fuse("center", 6.0) * delta) * maxf(0.0, 1.0 - _fuse("hold", 8.0) * delta)
				continue
			# the core swallows what reaches it, also what would fly across it within this step
			# (physics plan F4: fast matter no longer slingshots through it)
			var ahead := Vector2(particle.pos) + Vector2(particle.vel) * delta
			if d <= core or Geometry2D.get_closest_point_to_segment(p, Vector2(particle.pos), ahead).distance_to(p) <= core:
				_particles.remove_at(index)
				continue
			var inward := off / d
			var near := clampf(r / (d + 12.0), 0.0, 6.0)
			var scale := _fuse("pull_scale", 0.4) if own else 1.0
			# heavier Gefüge matter is turned less by the swirl (fuse_feed): it sinks in
			var swirl := float(w.spin) / maxf(1.0, float(particle.n)) if own else float(w.spin)
			particle.vel = Vector2(particle.vel) + (inward * float(w.pull) + inward.orthogonal() * swirl) * near * delta * scale
			if float(particle.gravity) > 0.0 and float(particle.z) <= 1.0:
				particle.vz = maxf(float(particle.vz), 30.0 * near)
		# motes circle in as streaks
		w.carry = float(w.carry) + float(w.motes) * delta
		while float(w.carry) >= 1.0:
			w.carry = float(w.carry) - 1.0
			if room(1) == 0: continue
			var at := p + Vector2.from_angle(_rng.randf() * TAU) * r * _rng.randf_range(0.6, 1.0) * Vector2(1.0, 0.75)
			var mote := emit(at, (p - at).orthogonal().normalized() * float(w.spin) * 0.5, (w.cols as Array)[1 if _rng.randf() < 0.7 else 0], _rng.randf_range(0.8, 1.4), "mote", 2.0, _rng.randf_range(2.0, 8.0), 0.0, 0.3)
			mote.streak = true
		# now and then the floor is lifted into it: loose pixels and embers
		w.suck = float(w.suck) - delta
		if float(w.suck) <= 0.0 and bool(w.get("floor", true)):
			w.suck = 0.25
			_suck(p, r * 0.8)


func _fuse(key: String, fallback: float) -> float:
	return float(_data.get("fuse", {}).get(key, fallback))


## Gefüge matter (the Leerenmagier's Singularität, user 2026-11-01: its particles fuse in the
## whirl, everything simulated): a blob of element `el` (`cols` spec, lite, body, shade, deep)
## seen at `point`, its floor point fuse.height px under it, thrown in with `velocity` and held by
## the well `key`: it swirls in with the rest (fuse.pull_scale of the pull, the swirl divided by
## its units: heavy matter sinks in) but the core does not swallow it, it sinks into it and stays
## (fuse.center, hold), it lives while the well does, throws off bits of its own matter (_blob_matter) and
## fuses with the others of its well it touches (_step_fusion).
func fuse_feed(key: String, point: Vector2, velocity: Vector2, el: String, cols: Array) -> void:
	if cols.size() < 5: return
	var height := _fuse("height", 8.0)
	var blob := emit(point, velocity, cols[2], 1.0, "fuse", PIXEL * 2.0, height, 0.0, _fuse("drag", 0.4))
	blob.gravity = 0.0
	blob.vz = 0.0
	blob.z_to = height
	blob.free = false
	blob.settle = false
	blob.fade = false
	blob.glow = false
	blob.fuse = key
	blob.parts = {el: 1.0}
	blob.ramps = {el: cols}
	blob.n = 1.0
	blob.size = _fuse_size(1.0)
	blob.spin = _rng.randf() * TAU
	blob.bits = _rng.randf() * _fuse("bits_every", 0.2)
	blob.flash = 0.0
	blob.mix_seed = _rng.randi() % 100000


## Takes the Gefüge matter of the well `key` out of the air (the Singularität collapsing):
## {pos: the middle of its blobs (weighted by their units), z, parts: {el: units}, ramps, n};
## empty when there is none.
func fuse_take(key: String) -> Dictionary:
	var sum := 0.0
	var at := Vector2.ZERO
	var z := 0.0
	var parts := {}
	var ramps := {}
	for index in range(_particles.size() - 1, -1, -1):
		var blob: Dictionary = _particles[index]
		if not blob.has("fuse") or str(blob.fuse) != key: continue
		var n := float(blob.n)
		sum += n
		at += Vector2(blob.pos) * n
		z = maxf(z, float(blob.z))
		for el: String in blob.parts:
			parts[el] = float(parts.get(el, 0.0)) + float(blob.parts[el])
			ramps[el] = blob.ramps[el]
		_particles.remove_at(index)
	if sum <= 0.0: return {}
	return {"pos": at / sum, "z": z, "parts": parts, "ramps": ramps, "n": sum}


## How many blobs of Gefüge matter the well `key` holds in the air (x) and how many units (y).
func fuse_blobs(key: String) -> Vector2i:
	var out := Vector2i.ZERO
	for blob: Dictionary in _particles:
		if blob.has("fuse") and str(blob.fuse) == key:
			out.x += 1
			out.y += roundi(float(blob.n))
	return out


## A blob of `n` units is PIXEL x (fuse.size + fuse.grow x sqrt(n)) px across, at most size_max.
func _fuse_size(n: float) -> float:
	return clampf(PIXEL * (_fuse("size", 1.5) + _fuse("grow", 2.2) * sqrt(maxf(1.0, n))), PIXEL * 2.0, _fuse("size_max", 30.0))


## Gefüge matter (fuse_feed) each frame: kept alive while its well lasts, turning (fuse.spin
## rad/s), throwing off bits of its own matter (_blob_matter); it holds together: the smaller
## blobs of a well are drawn to its heaviest one (fuse.cohesion px/s^2, stronger with the units
## it holds); two blobs of one well that touch (closer than fuse.reach x their radii summed)
## fuse into one (_fuse_pair).
func _step_fusion(delta: float) -> void:
	var groups := {}
	for particle: Dictionary in _particles:
		if not particle.has("fuse"): continue
		var key := str(particle.fuse)
		if not groups.has(key): groups[key] = []
		(groups[key] as Array).append(particle)
	if groups.is_empty(): return
	var reach := _fuse("reach", 1.0)
	var fused := false
	for key: String in groups:
		var blobs: Array = groups[key]
		var held := _wells.has(key)
		var heavy: Dictionary = blobs[0]
		for blob: Dictionary in blobs:
			if held: blob.life = 1.0
			blob.spin = float(blob.spin) + delta * _fuse("spin", 2.5)
			blob.flash = maxf(0.0, float(blob.flash) - delta)
			_blob_matter(blob, delta)
			if float(blob.n) > float(heavy.n): heavy = blob
		var cling := _fuse("cohesion", 260.0) * sqrt(float(heavy.n))
		for blob: Dictionary in blobs:
			if blob == heavy: continue
			var to: Vector2 = Vector2(heavy.pos) - Vector2(blob.pos)
			if to.length() > 0.5: blob.vel = Vector2(blob.vel) + to.normalized() * cling * delta
		for i in range(blobs.size()):
			var a: Dictionary = blobs[i]
			if a.has("dead"): continue
			for j in range(i + 1, blobs.size()):
				var b: Dictionary = blobs[j]
				if b.has("dead"): continue
				if Vector2(a.pos).distance_to(b.pos) > (float(a.size) + float(b.size)) * 0.5 * reach: continue
				_fuse_pair(a, b)
				b.dead = true
				fused = true
	if not fused: return
	for index in range(_particles.size() - 1, -1, -1):
		if (_particles[index] as Dictionary).has("dead"): _particles.remove_at(index)


## Blob `b` fuses into blob `a`: one blob where they met (weighted by their units), holding the
## units and elements of both, as big as its units make it (_fuse_size), its rim flashing for
## fuse.flash s; where elements meet that react, they do it in matter (_fuse_reaction: steam
## rising, sparks flying, ice splintering), and a few motes of the void fly off.
func _fuse_pair(a: Dictionary, b: Dictionary) -> void:
	var na := float(a.n)
	var nb := float(b.n)
	var sum := na + nb
	var at := (Vector2(a.pos) * na + Vector2(b.pos) * nb) / sum
	var what := _fuse_reaction(a.parts, b.parts)
	a.pos = at
	a.vel = (Vector2(a.vel) * na + Vector2(b.vel) * nb) / sum
	var parts: Dictionary = a.parts
	var ramps: Dictionary = a.ramps
	for el: String in b.parts:
		parts[el] = float(parts.get(el, 0.0)) + float(b.parts[el])
		ramps[el] = b.ramps[el]
	a.n = sum
	a.size = _fuse_size(sum)
	a.flash = _fuse("flash", 0.12)
	_sound("fuse", at, 1)
	var z := float(a.z)
	match what:
		"steam": steam(at, 2 + mini(int(sum / 4.0), 3), float(a.size) * 0.4)
		"spark": sparks(at - Vector2(0.0, z), Vector2.UP, 4 + mini(int(sum / 3.0), 4))
		"frost":
			var ice: Variant = ramps.get("ice", [])
			shatter(at, 2, Vector2.ZERO, 50.0, ice if ice is Array else [], 1, z)
	var cols := _void_ramp()
	motes(at, 2, [cols[0], cols[1], cols[2]], 6.0, z)


## How the matter of two blobs reacts where they fuse (`pa`, `pb`: their {el: units}): "spark"
## when fire or lava meets poison (it goes off), "steam" when it meets water, ice or blood,
## "frost" when ice meets water, "" for none (the strongest of their pairs).
static func _fuse_reaction(pa: Dictionary, pb: Dictionary) -> String:
	var best := ""
	for x: String in pa:
		for y: String in pb:
			var what := _pair_reaction(x, y)
			if what == "spark": return what
			if what == "steam" or (what == "frost" and best.is_empty()): best = what
	return best


static func _pair_reaction(x: String, y: String) -> String:
	var hot := ["fire", "lava"]
	if hot.has(x) != hot.has(y):
		var other := y if hot.has(x) else x
		if other == "poison": return "spark"
		if other in ["water", "ice", "blood"]: return "steam"
	if (x == "ice" and y == "water") or (x == "water" and y == "ice"): return "frost"
	return ""


## A blob of Gefüge matter throws off a bit of its own elements now and then (every
## fuse.bits_every s, more often the bigger it is), picked by their shares and by what it is:
## fire and lava a flame rising off it, water, poison and blood a drop that falls, ice a sliver,
## bone and gold a chip, the rest a mote; its well swirls them in again.
func _blob_matter(blob: Dictionary, delta: float) -> void:
	blob.bits = float(blob.bits) - delta
	if float(blob.bits) > 0.0: return
	blob.bits = _fuse("bits_every", 0.2) / sqrt(maxf(1.0, float(blob.n)))
	if room(1) == 0: return
	var parts: Dictionary = blob.parts
	var pick := _rng.randf() * float(blob.n)
	var el := ""
	for name: String in parts:
		el = name
		pick -= float(parts[name])
		if pick <= 0.0: break
	if el.is_empty(): return
	var cols: Array = blob.ramps[el]
	var r := float(blob.size) * 0.5
	var out := Vector2.from_angle(_rng.randf() * TAU)
	var spot := Vector2(blob.pos) + out * r * 0.5 * Vector2(1.0, 0.6)
	var z := float(blob.z)
	match el:
		"fire", "lava":
			flames(spot, 1, cols, r * 0.3, z + r * 0.3)
		"water", "poison", "blood":
			emit(spot, out * _rng.randf_range(30.0, 70.0), cols[1 + _rng.randi() % 2], _rng.randf_range(1.2, 2.0), "drop", PIXEL, z, _rng.randf_range(30.0, 70.0), 1.5)
		"ice":
			shatter(spot, 1, out, 50.0, cols, 1, z)
		"bone", "gold":
			chips(spot, 1, out, [cols[1], cols[2]])
		_:
			motes(spot, 1, [cols[0], cols[1]], 8.0, z)


## A blob of fused Gefüge matter (fuse_feed): its units as lumps of their own elements packed
## into one (a sunflower of up to fuse.lumps lumps turning with it, each its element's colours,
## lit at its top left and dark at its foot: fire flickering on the beat, ice with a glinting
## facet, water with a shine, poison bubbling; a dark seam where two elements meet), an ink rim
## round it (white the moment it fused) and its shadow on the floor under it.
func _draw_fused(canvas: CanvasItem, blob: Dictionary) -> void:
	var size := float(blob.size)
	var ground: Vector2 = blob.pos
	var mid := (ground - Vector2(0.0, float(blob.z))) / PIXEL
	var r := size * 0.5 / PIXEL
	canvas.draw_rect(Rect2(_snap(ground - Vector2(size * 0.5, 0.0)), Vector2(size, PIXEL)), Color(0, 0, 0, 0.22))
	var parts: Dictionary = blob.parts
	var ramps: Dictionary = blob.ramps
	var names: Array = parts.keys()
	if names.is_empty(): return
	var beat_now := int(_time * 12.0)
	var ext_now := int(ceil(r)) + 2
	var c_now := Vector2i(mid.floor())
	# baked into a picture on the 12 fps beat (or when it fuses or flashes), only moved between
	# (physics plan F7: the per-pixel lumps every frame were the cost)
	var key := "%d:%d:%d:%d" % [beat_now, roundi(float(blob.n) * 10.0), 1 if float(blob.flash) > 0.0 else 0, ext_now]
	if str(blob.get("bake_key", "")) == key and blob.has("bake_tex"):
		var tex: Texture2D = blob.bake_tex
		canvas.draw_texture_rect(tex, Rect2(Vector2(c_now - Vector2i(ext_now, ext_now)) * PIXEL, Vector2(tex.get_size()) * PIXEL), false)
		return
	var img := Image.create_empty(ext_now * 2 + 1, ext_now * 2 + 1, false, Image.FORMAT_RGBA8)
	var total := maxf(0.001, float(blob.n))
	var count := clampi(roundi(total), 1, int(_fuse("lumps", 14)))
	var spin := float(blob.spin)
	# its lumps' elements by their shares, shuffled by the blob's own seed (the same every frame):
	# the elements lie mixed all through it, never in rings or wedges
	var order: Array = []
	var acc := 0.0
	for name: Variant in names:
		acc += float(parts[name])
		while order.size() < mini(count, roundi(acc / total * float(count))): order.append(str(name))
	while order.size() < count: order.append(str(names[-1]))
	var h := int(blob.get("mix_seed", 7)) + count * 7919
	for j in range(order.size() - 1, 0, -1):
		h = (h * 1103515245 + 12345) & 0x7fffffff
		var k := h % (j + 1)
		var keep: Variant = order[j]
		order[j] = order[k]
		order[k] = keep
	var lumps: Array = []
	for j in range(count):
		var rr := r * 0.62 * sqrt((float(j) + 0.5) / float(count))
		var a := float(j) * 2.39996 + spin
		lumps.append([mid + Vector2(cos(a), sin(a) * 0.85) * rr, str(order[j])])
	var lr := maxf(1.0, r * 0.75 / sqrt(float(count)))
	var beat := int(_time * 12.0)
	var flash := float(blob.flash) > 0.0
	var ink := Color("1a1414")
	var ext := int(ceil(r)) + 2
	var c := Vector2i(mid.floor())
	for y in range(-ext, ext + 1):
		for x in range(-ext, ext + 1):
			var q := c + Vector2i(x, y)
			var pt := Vector2(q) + Vector2(0.5, 0.5)
			var off := pt - mid
			var dd := off.length()
			var edge := r * (1.0 + 0.08 * sin(off.angle() * 5.0 + _time * 3.0 + total))
			if dd > edge + 1.0: continue
			if dd > edge:
				img.set_pixel(x + ext, y + ext, Color.WHITE if flash else ink)
				continue
			var best := 0
			var d1 := INF
			for k in range(lumps.size()):
				var dk := pt.distance_to(lumps[k][0])
				if dk < d1:
					d1 = dk
					best = k
			var el := str(lumps[best][1])
			var d2 := INF
			for k in range(lumps.size()):
				if str(lumps[k][1]) != el: d2 = minf(d2, pt.distance_to(lumps[k][0]))
			var cols: Array = ramps.get(el, [])
			if cols.size() < 5: continue
			var col: Color = cols[4] if d2 - d1 < 0.7 else _lump_colour(el, cols, pt - (lumps[best][0] as Vector2), lr, q, beat)
			img.set_pixel(x + ext, y + ext, col)
	var baked := ImageTexture.create_from_image(img)
	blob.bake_tex = baked
	blob.bake_key = key
	canvas.draw_texture_rect(baked, Rect2(Vector2(c - Vector2i(ext, ext)) * PIXEL, Vector2(baked.get_size()) * PIXEL), false)


## The colour of art pixel `q` in a lump of element `el` (`cols` spec..deep), `local` from the
## lump's middle, `lr` its radius, on the 12 fps `beat` (_draw_fused).
static func _lump_colour(el: String, cols: Array, local: Vector2, lr: float, q: Vector2i, beat: int) -> Color:
	var lit := local.x + local.y < -lr * 0.5
	var foot := local.y > lr * 0.45
	var idx := 3 if foot else (1 if lit else 2)
	match el:
		"fire", "lava":
			# hot: white-yellow at its heart, yellow, orange at its foot, flickering on the beat
			idx = 2 if foot else (0 if local.length() < lr * 0.45 else 1)
			if posmod(beat + q.x * 3 + q.y * 5, 5) == 0: idx = maxi(0, idx - 1)
		"ice":
			# pale and hard: spec and lite in facets, a glint now and then
			idx = 2 if foot else (0 if local.x - local.y < 0.0 else 1)
			if lit and posmod(beat + q.x + q.y, 9) == 0: idx = 0
		"water":
			# deep: body and shade, a shine at its top left
			idx = 4 if foot else (2 if lit else 3)
			if (local - Vector2(-lr * 0.4, -lr * 0.4)).length() < 0.8: idx = 0
		"poison":
			if posmod(beat / 2 + q.x * 7 + q.y * 3, 11) == 0: idx = 1
	return cols[idx]


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
			for i in range(room(int(r * 0.3))):
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
				if MatterKit.bayer(q) >= (1.0 - k) * 16.0: continue
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
	_sound("sparks", point, count)
	count = room(count)
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
	_sound("burst_drops", point, count)
	if colors.is_empty(): return
	count = room(count)
	var speed: Array = _shot("drops", [60, 160])
	var life: Array = _shot("drop_life", [1.5, 3.0])
	var lift: Array = _mode("drop").get("lift", [50, 140])
	for i in range(count):
		var out := dir.normalized().rotated(_rng.randf_range(-1.2, 1.2)) if dir.length() > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
		emit(point, out * _rng.randf_range(float(speed[0]), float(speed[1])), colors[_rng.randi_range(0, colors.size() - 1)],
			_rng.randf_range(float(life[0]), float(life[1])), "drop", 2.0 if i % 3 else 4.0, _rng.randf_range(2.0, 8.0), _rng.randf_range(float(lift[0]), float(lift[1])), 2.0)


## `count` motes of a spirit element (soul, curse, spirit) drifting out of
## `point` as short glowing streaks in `colors`, rising a little, soon gone
## (they thin out by the dither); `height` px over the floor (-1: 4..14),
## `speed` x shot.motes px/s.
func motes(point: Vector2, count: int, colors: Array, rise := 12.0, height := -1.0, speed := 1.0) -> void:
	if colors.is_empty(): return
	count = room(count)
	var fast: Array = _shot("motes", [20, 60])
	var life: Array = _shot("mote_life", [0.35, 0.7])
	for i in range(count):
		var out := Vector2.from_angle(_rng.randf() * TAU)
		var mote := emit(point + out * _rng.randf_range(0.0, 6.0), out * _rng.randf_range(float(fast[0]), float(fast[1])) * speed + Vector2(0, -rise),
			colors[_rng.randi_range(0, colors.size() - 1)], _rng.randf_range(float(life[0]), float(life[1])), "mote", 2.0, _rng.randf_range(4.0, 14.0) if height < 0.0 else height + _rng.randf_range(0.0, 4.0), 0.0, 0.8)
		mote.streak = true


## `count` chips of a hard element (bone, steel, gold, stone) from `point`
## along `dir` (all round when zero) in `colors`: they fall, bounce and settle
## as floor pixels that stay.
func chips(point: Vector2, count: int, dir: Vector2, colors: Array) -> void:
	_sound("chips", point, count)
	if colors.is_empty(): return
	count = room(count)
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
	_sound("scorch_star", point, int(size))
	var soot := Color(str(_data.get("ember", {}).get("soot", "1c1416")))
	for i in range(6):
		var dir := Vector2.from_angle(TAU * float(i) / 6.0 + _rng.randf_range(-0.3, 0.3)) * Vector2(1.0, 0.75)
		_line(point, point + dir * size * _rng.randf_range(0.5, 1.0), Color(soot, 0.8))
	embers(point, size * 0.3, 3)


## `count` chunks of rubble from `point` along `dir` (all round when zero):
## heavy, one low bounce, they stop hard and lie as loose pixels.
func rubble(point: Vector2, count: int, dir: Vector2 = Vector2.ZERO, speed: float = 140.0) -> void:
	_sound("rubble", point, count)
	# cosmetic: it asks for room under the cap like the other emitters (physics plan R19)
	count = room(count)
	var cols := _el("stone")
	var lift: Array = _mode("rock").get("lift", [40, 110])
	for i in range(count):
		var out := dir.normalized().rotated(_rng.randf_range(-1.0, 1.0)) if dir.length() > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
		var rock := emit(point, out * speed * _rng.randf_range(0.4, 1.0), cols[1], 3.0, "rock", float([2, 4, 4, 6][_rng.randi_range(0, 3)]), 4.0, _rng.randf_range(float(lift[0]), float(lift[1])), 0.5)
		rock.rock = cols


## Dust creeping flat over the floor from `point` (within `radius`), settling soon.
func dust_flat(point: Vector2, radius: float, count: int) -> void:
	_sound("burst_dust", point, count)
	count = room(count)
	var cols := _el("dust")
	for i in range(count):
		var out := Vector2.from_angle(_rng.randf() * TAU) * Vector2(1.0, 0.7)
		emit(point + out * radius * 0.3, out * _rng.randf_range(40.0, 90.0), cols[_rng.randi_range(0, cols.size() - 1)], _rng.randf_range(0.8, 1.6), "dust", 4.0, 0.0, 0.0, 3.0)


## Cracks radiating from a heavy blow at `point` (`branches` jagged lines up
## to `length` px) out of the dent the blow pressed into the floor (dark in
## its middle, its far rim catching the light); each crack is lit along its
## lower lip near the dent, where it is widest. They stay.
func floor_crack(point: Vector2, length: float, branches: int) -> void:
	_sound("floor_crack", point, branches * 4)
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
			elif e < 0.55 or MatterKit.bayer(q) < (1.0 - e) * 30.0:
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
	_sound("holy_motes", point, count)
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
	_sound("shadow", point, branches)
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
			if e > 0.6 and MatterKit.bayer(q) >= (1.0 - e) * 40.0:
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
	_sound("liquid_freeze", point, int(radius))
	for link: Array in _liquids:
		# a layer the rules read freezes only through the rules (story_elements.gd frost_at;
		# physics plan F17): the drawing never makes Glatteis there
		if link.size() > 2 and bool(link[2]): continue
		var layer: Object = (link[0] as WeakRef).get_ref()
		if layer != null and layer.has_method("freeze_near"): layer.freeze_near(point * float(link[1]), radius * float(link[1]))


## Fire on Glatteis: the liquid layers' ice at `point` thaws (pool_paint thaw_near).
func thaw_liquids(point: Vector2, radius: float) -> void:
	_sound("liquid_thaw", point, int(radius))
	for link: Array in _liquids:
		if link.size() > 2 and bool(link[2]): continue
		var layer: Object = (link[0] as WeakRef).get_ref()
		if layer != null and layer.has_method("thaw_near"): layer.thaw_near(point * float(link[1]), radius * float(link[1]))


## `count` puffs of steam hissing up from `point` (a liquid on lava or fire,
## ice melting, an ember put out): light, quick, thinning by the dither.
func steam(point: Vector2, count: int, radius: float = 4.0) -> void:
	_sound("steam", point, count)
	count = room(count)
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
	_sound("smoke", point, count)
	count = room(count)
	var color := Color(str(_data.get("smoke_color", "2e2a2c")), 0.55)
	var lift: Array = _mode("smoke").get("lift", [10, 30])
	for i in range(count):
		var spot := point + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius) * 0.6)
		emit(spot, Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-10.0, 4.0)), Color(color, color.a * _rng.randf_range(0.6, 1.0)), _rng.randf_range(1.2, 2.2), "smoke", 4.0, 2.0, _rng.randf_range(float(lift[0]), float(lift[1])), 0.6)


## The pool layers (src/vfx/pool_paint.gd) whose liquid a blast rings, each
## with the scale from these particles' units to its world px (story worlds 1.5).
func add_liquid(layer: Object, scale: float) -> void:
	if layer != null: _liquids.append([weakref(layer), scale])


## Sets the layers anew (see add_liquid); a third entry true marks a layer the
## game's rules read (frost and fire change it only through the rules).
func set_liquids(layers: Array) -> void:
	_liquids = []
	for link: Array in layers:
		if link[0] != null: _liquids.append([weakref(link[0]), float(link[1]), link.size() > 2 and bool(link[2])])


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
	# what it may lift asks for room under the cap (the rest stays lying; physics plan R19)
	var limit := room(int(settings_for_kick.get("max_particles", 140)))
	var lift: Array = settings_for_kick.get("lift", [60, 200])
	var speed := float(settings_for_kick.get("speed", 260)) * strength
	var middle := _art(point)
	var reach := maxi(1, int(radius / PIXEL))
	var thrown := 0
	var seen_cells := {}
	for y in range(maxi(0, middle.y - reach), middle.y + reach + 1):
		for x in range(maxi(0, middle.x - reach), middle.x + reach + 1):
			var art := Vector2i(x, y)
			var offset := Vector2(art - middle)
			var distance := offset.length()
			if distance > float(reach): continue
			# a blast lifts only what it reaches, not what lies behind a wall (F5)
			if not sees(point, _world(art), seen_cells): continue
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
	_sound("blow", origin, 8)
	if r1 <= r0 or speed <= 0.0: return 0
	var settings_for_blow: Dictionary = _data.get("blow", {})
	var hop: Array = settings_for_blow.get("hop", [30, 90])
	var cap: int = limit if limit >= 0 else int(settings_for_blow.get("max_lift", 60))
	var moved := 0
	var seen_cells := {}
	# what flies already is shoved along, what lies on the floor hops; not behind a wall (F5)
	for particle: Dictionary in _particles:
		var out := _front_dir(Vector2(particle.pos), origin, r0, r1, angle, arc, squash)
		if out == Vector2.ZERO: continue
		if not sees(origin, Vector2(particle.pos), seen_cells): continue
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
	_fading.clear()
	_embers.clear()
	_frost.clear()
	_frost_head = 0
	_vapor.clear()
	_vapor_next = INF
	_water.clear()
	_water_head = 0
	_frozen.clear()
	_wet.clear()
	_damp.clear()
	_damp_head = 0
	_growth.clear()
	_glints.clear()
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
	_step_fusion(delta)
	_step_implosions()
	_spread_pools(delta)
	_fade_marks()
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
			# a soul comet puffs into motes where it arrives
			if particle.has("pop"):
				var pop: Array = particle.pop
				motes(Vector2(particle.pos), int(_data.get("comet", {}).get("pop", 4)), [pop[0], pop[1], pop[2]], 6.0, maxf(2.0, float(particle.z)))
			if particle.has("smoke_p") and _rng.randf() < float(particle.smoke_p):
				var color := Color(str(_data.get("smoke_color", "2e2a2c")))
				emit(Vector2(particle.pos), Vector2(particle.vel) * 0.3, color, _rng.randf_range(0.8, 1.4), "smoke", 4.0, float(particle.z), _rng.randf_range(10.0, 25.0), 0.6)
			_particles.remove_at(i)
			continue
		if particle.has("skull"): particle.roll = float(particle.get("roll", 0.0)) + Vector2(particle.vel).length() * delta
		_move(particle, delta)
		if bool(particle.get("landed", false)):
			# a comet's blob struck the floor: it splashes
			_particles.remove_at(i)
			_land_splash(particle)
			continue
		if bool(particle.get("burst", false)):
			_break_shard(particle)
			_particles.remove_at(i)


## Floor-plane motion with wall bounces, then height with gravity and floor bounces.
func _move(particle: Dictionary, delta: float) -> void:
	var position: Vector2 = particle.pos
	var velocity: Vector2 = particle.vel
	if wind != Vector2.ZERO and float(particle.z) > 0.5:
		var share := float(_mode(str(particle.get("mode", ""))).get("wind", 0.0))
		if share > 0.0:
			velocity += (wind * share - velocity) * minf(1.0, float(_data.get("wind_air", 1.5)) * delta)
	var next := position + velocity * delta
	# a comet's blob flying high passes over the walls on its arc (it lands on the gameplay spot)
	var over_walls := particle.has("splash") and float(particle.z) > 24.0
	if bool(particle.free):
		# Born inside a wall: it may leave, and walls count from then on.
		if not solid(next): particle.free = false
	elif not over_walls and solid(next):
		# a shard hitting a wall hard breaks; a slow one clinks off it
		if particle.has("shard") and velocity.length() > _ice("shatter_speed", 150.0) and int(particle.len) > 1:
			particle.burst = true
		var keep := float(_data.get("wall_bounce", 0.4))
		# flame, smoke and motes slide along a wall instead of bouncing off it (modes wall "slide",
		# physics plan F1): the part into the wall is gone, the part along it stays
		var slide := str(_mode(str(particle.get("mode", ""))).get("wall", "bounce")) == "slide"
		if not solid(Vector2(next.x, position.y)):
			next = Vector2(next.x, position.y)
			velocity.y = 0.0 if slide else -velocity.y * keep
		elif not solid(Vector2(position.x, next.y)):
			next = Vector2(position.x, next.y)
			velocity.x = 0.0 if slide else -velocity.x * keep
		else:
			next = position
			velocity = Vector2.ZERO if slide else -velocity * keep
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
		# the height on its exact arc (z += vz dt - g dt^2 / 2): comets land where they were aimed,
		# not early and short (physics plan F9)
		var air := float(_mode(str(particle.get("mode", ""))).get("air", 0.0))
		if air > 0.0 and not particle.has("splash"):
			# light matter meets the air (modes air 1/s, physics plan F2): it falls or rises no
			# faster than gravity / air, smoke and embers no longer shoot up for ever
			particle.vz = (float(particle.vz) - gravity * delta) * exp(-air * delta)
			particle.z = float(particle.z) + float(particle.vz) * delta
		else:
			particle.z = float(particle.z) + float(particle.vz) * delta - 0.5 * gravity * delta * delta
			particle.vz = float(particle.vz) - gravity * delta
		if gravity > 0.0 and float(particle.z) <= 0.0:
			# a comet's blob does not bounce: it splashes (update, _land_splash), where it touched down
			if particle.has("splash"):
				if float(particle.vz) < -0.01: particle.pos = Vector2(particle.pos) - velocity * (float(particle.z) / float(particle.vz))
				particle.z = 0.0
				particle.landed = true
				particle.vel = velocity
				return
			particle.z = 0.0
			# a drop splats where it lands instead of bouncing (modes floor "splat", F1): it stays
			# down, slows hard and lies as a floor pixel
			if str(_mode(str(particle.get("mode", ""))).get("floor", "bounce")) == "splat":
				particle.vz = 0.0
				velocity *= 0.15
			elif float(particle.vz) < -float(_data.get("bounce_min", 70)):
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
	elif particle.has("z_to"):
		# weightless matter sinks (or rises) to the height it is pulled to
		particle.z = lerpf(float(particle.z), float(particle.z_to), 1.0 - exp(-float(_data.get("z_ease", 5.0)) * delta))
	var on_floor: bool = float(particle.z) <= 0.0 and float(particle.vz) == 0.0 and gravity > 0.0
	if on_floor and particle.has("shard"):
		# ice on stone: an even grip (dry friction), so it skids a short way and stops
		var speed := velocity.length()
		if speed > 0.01:
			velocity *= maxf(0.0, speed - _ice("slide_decel", 280.0) * delta) / speed
	var friction := _ice("friction", 1.4) if particle.has("shard") else (18.0 if particle.has("rock") else float(_data.get("ground_friction", 9)))
	var drag := float(particle.drag) + (friction if on_floor else 0.0)
	particle.vel = velocity * maxf(0.0, 1.0 - drag * delta)


## A particle makes room at the cap (physics plan R19/F6): the oldest cosmetic one that is not
## landing matter goes first (a spark, a mote, smoke), then the oldest that lies or flies low;
## never Gefüge matter (fuse_feed), a comet's blob (splash, land_ref: it must land where gameplay
## put it) or debris in mid-air (it would teleport to the floor). Debris that goes lands where it is.
func _evict() -> void:
	var fallback := -1
	for index in range(mini(_particles.size(), 96)):
		var p: Dictionary = _particles[index]
		if p.has("fuse") or p.has("splash") or p.has("land_ref"): continue
		if bool(p.settle):
			if float(p.z) > 1.0: continue
			if fallback < 0: fallback = index
			continue
		_particles.remove_at(index)
		return
	if fallback >= 0:
		var oldest: Dictionary = _particles[fallback]
		_particles.remove_at(fallback)
		_settle(oldest)
		return
	_particles.pop_front()


## A resting debris particle becomes loose floor pixels (only on the floor);
## settled frost melts later.
func _settle(particle: Dictionary) -> void:
	if bool(particle.free): return
	if sound != null: sound.settle(particle)
	# a skull lies where it stopped rolling, turned as it came to rest
	if particle.has("skull"):
		var middle := _art(Vector2(particle.pos))
		for cell: Array in _skull_cells(int(float(particle.get("roll", 0.0)) / 6.0)):
			var q: Vector2i = middle + (cell[0] as Vector2i)
			if q.x < 0 or q.y < 0 or solid(_world(q)): continue
			_put(q, _skull_colour(particle, int(cell[1])))
			_loose[q] = true
		return
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
		# its tip catches the light now and then while it lies (draw_stains)
		if _glints.size() < int(_ice("glint_max", 80)) and _rng.randf() < _ice("glint_share", 0.6):
			var span: Array = _data.get("ice", {}).get("glint_life", [2.0, 4.5])
			_glints.append([middle + face * (n - 1 - n / 2), _time + _rng.randf_range(float(span[0]), float(span[1])), _rng.randi() % 97])
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
	# a drop of a liquid lands as a few pixels of it (it joins the stain it falls
	# into); they dry and fade like a splat
	if str(particle.get("mode", "")) == "drop":
		var wet := Color(color.darkened(0.2), 1.0)
		var landed: Array[Vector2i] = []
		var middle := _art(Vector2(particle.pos))
		var cells: Array[Vector2i] = [middle]
		for k in range(clampi(roundi(float(particle.size) / PIXEL) - 1 + _rng.randi_range(0, 1), 0, 3)):
			cells.append(middle + STEPS[_rng.randi_range(0, 3)] * (1 + int(k >= 2)))
		for q: Vector2i in cells:
			if q.x < 0 or q.y < 0 or solid(_world(q)): continue
			_put(q, wet if q == middle else Color(color.darkened(0.35), 1.0))
			landed.append(q)
		_fade_later(middle, landed)
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
	# lying ice shards glint: their tip flashes spec for one beat now and then
	if not _glints.is_empty():
		var spec_colour: Color = _ice_ramp()[0]
		var beat := int(_time * 12.0)
		var every := maxi(2, int(_ice("glint_every", 10)))
		for i in range(_glints.size() - 1, -1, -1):
			var glint: Array = _glints[i]
			if float(glint[1]) < _time or not _frozen.has(glint[0]):
				_glints.remove_at(i)
				continue
			if posmod(beat + int(glint[2]), every) == 0:
				canvas.draw_rect(Rect2(Vector2(glint[0] as Vector2i) * PIXEL, Vector2(PIXEL, PIXEL)), spec_colour)


## Depth bands (physics plan R22, decision D11): matter low over the floor is drawn by the host
## between its y-sorted actors (begin_bands, draw_band), so a monster, a pillar or the hero hides
## what lies behind it; only matter higher than depth_high px (and the rime tips and implosions)
## stays in the layer over them (draw_particles part 2). `_low` holds this frame's low matter by y.
var _low: Array = []
var _low_i := 0


## Collects this frame's low matter, sorted by its floor point's y, for draw_band.
func begin_bands() -> void:
	var high := float(_data.get("depth_high", 26.0))
	_low = _particles.filter(func(p: Dictionary) -> bool: return float(p.z) <= high)
	_low.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float((a.pos as Vector2).y) < float((b.pos as Vector2).y))
	_low_i = 0


## Draws the low matter whose floor point lies above `to_y` (particle px) and not drawn yet.
func draw_band(canvas: CanvasItem, to_y: float) -> void:
	var start := _low_i
	while _low_i < _low.size() and float((_low[_low_i].pos as Vector2).y) < to_y:
		_low_i += 1
	if _low_i > start: draw_particles(canvas, _low.slice(start, _low_i), 1)


## The particles over the actors. `part` 0: all of them; 1: only `only` (a depth band, without the
## rime tips and implosions); 2: only matter higher than depth_high (the rest is in the bands).
func draw_particles(canvas: CanvasItem, only: Array = [], part := 0) -> void:
	if part != 1:
		draw_rime_tips(canvas)
		_draw_implosions(canvas)
	var beat := int(_time * 12.0)
	var high := float(_data.get("depth_high", 26.0))
	var src: Array = only if part == 1 else _particles
	for particle: Dictionary in src:
		if part == 2 and float(particle.z) <= high: continue
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
		if particle.has("parts"):
			_draw_fused(canvas, particle)
			continue
		if particle.has("skull"):
			# a skull rolling: its 3x3 cells turned a quarter for every 6 px it rolls
			var middle := Vector2i(((ground - Vector2(0.0, height)) / PIXEL).floor())
			if height > 3.0:
				canvas.draw_rect(Rect2(_snap(ground - Vector2(3.0, 0.0)), Vector2(6.0, PIXEL)), Color(0, 0, 0, 0.22))
			for cell: Array in _skull_cells(int(float(particle.get("roll", 0.0)) / 6.0)):
				canvas.draw_rect(Rect2(Vector2(middle + (cell[0] as Vector2i)) * PIXEL, Vector2(PIXEL, PIXEL)), _skull_colour(particle, int(cell[1])))
			continue
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
				if MatterKit.bayer(q) >= shown * 16.0: continue
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
				if MatterKit.bayer(q) < alpha * 16.0:
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


## Glowing particles (sparks, embers, frost) light up in the bloom layer,
## tight round their pixel so they never wash it out (vfx_particles.json glow:
## radius + per_size x size px, alpha at most alpha_cap; embers ember_r
## [cold, hot] px at ember_alpha).
func draw_glow(canvas: CanvasItem, level: float) -> void:
	if level <= 0.0: return
	var spec: Dictionary = _data.get("glow", {})
	var base := float(spec.get("radius", 3.0))
	var per := float(spec.get("per_size", 1.0))
	var cap := float(spec.get("alpha_cap", 0.22))
	for particle: Dictionary in _particles:
		if not bool(particle.glow): continue
		var alpha := clampf(float(particle.life) / (float(particle.max_life) * 0.5), 0.0, 1.0) if bool(particle.fade) else 1.0
		var point: Vector2 = Vector2(particle.pos) - Vector2(0.0, float(particle.z))
		# a spark seen against a wall does not light the wall up (no glow through walls)
		if solid(point): continue
		Glow.dot(canvas, point, base + float(particle.size) * per, Color(particle.color, minf(cap, float(particle.get("glow_a", 0.32))) * alpha * level))
	var ember_r: Array = spec.get("ember_r", [2.0, 5.0])
	var ember_a := float(spec.get("ember_alpha", 0.2))
	for ember: Dictionary in _embers:
		var heat := float(ember.life) / float(ember.max)
		Glow.dot(canvas, _world(ember.art), lerpf(float(ember_r[0]), float(ember_r[1]), heat), Color(1.0, 0.5, 0.15, ember_a * heat * level))


func count() -> int:
	return _particles.size()


# --- The living floor ------------------------------------------------------------------

## A splat keeps creeping outwards from its rim (more along the hit direction).
## A splat's liquid (its shades `ramp`, _splat_ramp) creeping on from where
## it landed; `painted` its pixels so far (they dry and fade with it).
func _add_pool(origin: Vector2, ramp: Array, radius: float, direction: Vector2, painted: Array[Vector2i]) -> void:
	var liquid: Dictionary = _data.get("liquid", {})
	if _pools.size() >= int(liquid.get("max_pools", 48)): _dry(_pools.pop_front())
	var middle := _art(origin)
	var across := maxf(1.0, radius / PIXEL)
	var frontier: Array[Vector2i] = []
	for index in range(12):
		var rim := Vector2.from_angle(TAU * float(index) / 12.0) * across * Vector2(1.0, 0.75)
		frontier.append(middle + Vector2i(roundi(rim.x), roundi(rim.y)))
	_pools.append({"center": middle, "color": ramp[1], "ramp": ramp, "px": painted, "frontier": frontier, "budget": int(across * across * float(liquid.get("budget_scale", 0.9))),
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
	if _pixel(next).a < 0.05:
		# the creeping edge keeps the grain: now and then a deeper pixel
		var ramp: Array = pool.get("ramp", [pool.color, pool.color])
		_put(next, ramp[0] if _rng.randf() < 0.3 else pool.color)
		(pool.px as Array).append(next)
	frontier.append(next)
	if frontier.size() > 48: frontier.remove_at(0)


## A pool that stopped creeping dries: its pixels (those still its own)
## darken by liquid.dry_darken, then it fades (_fade_later).
func _dry(pool: Dictionary) -> void:
	var darken := float(_data.get("liquid", {}).get("dry_darken", 0.35))
	var ramp: Array = pool.get("ramp", [pool.color])
	var dried: Array = []
	for c: Color in ramp:
		dried.append(Color(c.darkened(darken), c.a * 0.9))
	var kept: Array[Vector2i] = []
	var seen := {}
	for q: Vector2i in pool.get("px", []):
		if seen.has(q): continue
		seen[q] = true
		var k := _shade_of(_pixel(q), ramp)
		if k < 0: continue
		_put(q, dried[k])
		kept.append(q)
	_fade_later(pool.center, kept)


## Which of `ramp`'s colours `here` is (as the floor image keeps it), -1 for none.
static func _shade_of(here: Color, ramp: Array) -> int:
	for k in range(ramp.size()):
		var c: Color = ramp[k]
		if absf(here.r - c.r) + absf(here.g - c.g) + absf(here.b - c.b) < 0.03 and absf(here.a - c.a) < 0.02:
			return k
	return -1


## Dried pixels `px` of a mark round `middle` (art px) fade after
## liquid.fade_after s over fade_time s, its rim first; the last fade_keep of
## them stay as faint specks (residue_alpha of their opacity).
func _fade_later(middle: Vector2i, px: Array[Vector2i]) -> void:
	if px.is_empty(): return
	var liquid: Dictionary = _data.get("liquid", {})
	var far := 1.0
	for q: Vector2i in px:
		far = maxf(far, Vector2(q - middle).length())
	# rim first: ten buckets by the distance from the middle, shuffled a little
	var buckets: Array = []
	for i in range(10): buckets.append([])
	for q: Vector2i in px:
		var level := clampi(int((1.0 - Vector2(q - middle).length() / far) * 7.0 + MatterKit.cell_noise(q, 5) * 3.0), 0, 9)
		(buckets[level] as Array).append(q)
	var order: Array[Vector2i] = []
	var cols: Array = []
	for bucket: Array in buckets:
		for q: Vector2i in bucket:
			order.append(q)
			cols.append(_pixel(q))
	var start := _time + float(liquid.get("fade_after", 8.0)) * _rng.randf_range(0.85, 1.15)
	_fading.append({"px": order, "col": cols, "i": 0, "t0": start, "t1": start + float(liquid.get("fade_time", 6.0)), "keep": int(float(order.size()) * float(liquid.get("fade_keep", 0.12)))})
	if _fading.size() > int(liquid.get("max_fading", 96)):
		var oldest: Dictionary = _fading.pop_front()
		oldest.t1 = _time
		_fade_mark(oldest)


## Dried marks fading away (_fade_later), each step only the pixels now due.
func _fade_marks() -> void:
	for index in range(_fading.size() - 1, -1, -1):
		var mark: Dictionary = _fading[index]
		if _time < float(mark.t0): continue
		if _fade_mark(mark): _fading.remove_at(index)


## Takes the due pixels of one fading `mark` (those still its own); true when
## it is done (its last specks then made faint).
func _fade_mark(mark: Dictionary) -> bool:
	var px: Array = mark.px
	var cols: Array = mark.col
	var share := clampf((_time - float(mark.t0)) / maxf(0.01, float(mark.t1) - float(mark.t0)), 0.0, 1.0)
	var keep := int(mark.keep)
	var upto := int(float(px.size() - keep) * share)
	var i := int(mark.i)
	while i < upto:
		if _pixel(px[i]) == cols[i]: _put(px[i], Color(0, 0, 0, 0))
		i += 1
	mark.i = i
	if share < 1.0: return false
	var faint := float(_data.get("liquid", {}).get("residue_alpha", 0.55))
	for k in range(px.size() - keep, px.size()):
		var c: Color = cols[k]
		if _pixel(px[k]) == c: _put(px[k], Color(c, c.a * faint))
	return true


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
	# at the cap the oldest frost melts now instead of staying frozen forever (physics plan F6)
	if _frost.size() - _frost_head >= int(settings_for_frost.get("max", 4000)): _frost[_frost_head][1] = minf(float(_frost[_frost_head][1]), _time)
	var melt: Array = settings_for_frost.get("melt_after", [6.0, 10.0])
	if due < 0.0: due = _time + _rng.randf_range(float(melt[0]), float(melt[1]))
	_frozen[art] = _pixel(art)
	if vapor:
		# at the cap the oldest vapor frost goes now instead of staying frozen forever (physics plan R19)
		if _vapor.size() >= int(settings_for_frost.get("max", 4000)): _vapor_go(_vapor.pop_front()[0])
		var when := due + MatterKit.bayer(art) / 16.0 * float(settings_for_frost.get("vapor_spread", 1.2)) * spread
		_vapor.append([art, when])
		_vapor_next = minf(_vapor_next, when)
		return
	_frost.append([art, due])


## A vapor frost pixel goes (unless something was painted over it meanwhile).
func _vapor_go(spot: Vector2i) -> void:
	if not _frozen.has(spot): return
	var same: bool = _pixel(spot) == _frozen[spot]
	_frozen.erase(spot)
	if same:
		_put(spot, Color(0, 0, 0, 0))
		_loose.erase(spot)


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
	# vapor frost: every due pixel goes, the rest keep their order (scanned only once the
	# earliest is due)
	if not _vapor.is_empty() and _time >= _vapor_next:
		var keep := 0
		_vapor_next = INF
		for index in range(_vapor.size()):
			var entry: Array = _vapor[index]
			if float(entry[1]) > _time:
				_vapor[keep] = entry
				keep += 1
				_vapor_next = minf(_vapor_next, float(entry[1]))
				continue
			_vapor_go(entry[0])
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


# --- Splats (a body flung against a wall) ---------------------------------------------

## The gore table (assets/data/vfx_gore.json), read once.
static func _gore_table() -> Dictionary:
	if _gore.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GORE_PATH)) if FileAccess.file_exists(GORE_PATH) else null
		_gore = parsed if parsed is Dictionary else {"materials": {}}
	return _gore


## A colour from a table: a hex string, else `fallback`.
static func _hex_or(value: Variant, fallback: Color) -> Color:
	if value is String and Color.html_is_valid(value): return Color.html(value)
	return fallback


## Colours from a list of hex strings, else `fallback`.
static func _hexes(values: Variant, fallback: Array) -> Array:
	var out: Array = []
	if values is Array:
		for value: Variant in values:
			if value is String and Color.html_is_valid(value): out.append(Color.html(value))
	return out if not out.is_empty() else fallback


## SPLAT (src/vfx/talent_fx.gd "splat": an enemy flung against a wall at the
## Urknall) in the enemy's `material`, `dir` pointing into the wall it struck,
## `radius` px the burst's reach. vfx_gore.json "splat": the material's class
## (class: flesh, bone, void, gold; unknown ones flesh) and that class's
## counts; colours from the material's own entry (color, stain) or the
## class's. flesh: drops sprayed back off the wall, chunks that fly, bounce
## and lie, a splat on the floor and one on the wall running down; bone:
## splinters off the wall, a dust cloud that rises and creeps, the skull
## rolling away and a crack in the wall; void: motes flung out over a dark
## stain; gold: coins that bounce and settle, with glints. Every class kicks
## the loose floor pixels round it.
func splat_burst(point: Vector2, dir: Vector2, material: String, radius: float = 16.0) -> void:
	var table: Dictionary = _gore_table().get("splat", {})
	var cls := str(table.get("class", {}).get(material, material))
	if not table.has(cls) or not table[cls] is Dictionary: cls = "flesh"
	var spec: Dictionary = table.get(cls, {})
	var mat: Variant = _gore_table().get("materials", {}).get(material, {})
	if not mat is Dictionary: mat = {}
	var color := _hex_or(mat.get("color", spec.get("color", "")), Color("c8323a"))
	var stain_color := _hex_or(mat.get("stain", spec.get("stain", "")), color.darkened(0.5))
	var into := dir.normalized() if dir.length() > 0.01 else Vector2.UP
	var back := -into
	var spray := float(spec.get("spray", 170))
	match cls:
		"flesh":
			drops(point, int(spec.get("drops", 24)), back, [color, color.darkened(0.3), color.lightened(0.15)])
			var flesh := _hexes(spec.get("chunk_colors", []), [color.darkened(0.4), color, color.lightened(0.3)])
			var lift: Array = spec.get("chunk_lift", [80, 170])
			for i in range(int(spec.get("chunks", 6))):
				var out := back.rotated(_rng.randf_range(-1.1, 1.1)) * _rng.randf_range(spray * 0.45, spray)
				emit(point, out, flesh[i % flesh.size()], _rng.randf_range(2.0, 3.5), "debris", [4.0, 4.0, 6.0][i % 3], 8.0, _rng.randf_range(float(lift[0]), float(lift[1])), 2.0)
			splat(point + back * radius * 0.5, stain_color, float(mat.get("stain_alpha", spec.get("stain_alpha", 0.9))), float(spec.get("floor_splat", 16)), back)
			wall_splat(point, into, color.darkened(0.15), float(spec.get("wall_splat", 9)))
		"bone":
			var bone := _hexes(spec.get("colors", []), [color, color.darkened(0.25), color.lightened(0.2)])
			chips(point, int(spec.get("splinters", 14)), back, bone)
			var dust := _el("dust")
			for i in range(int(spec.get("dust", 12))):
				var drift := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(20.0, 70.0) + back * 30.0
				emit(point + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-3.0, 3.0)), drift, dust[_rng.randi_range(0, dust.size() - 1)], _rng.randf_range(0.7, 1.3), "dust", 4.0, _rng.randf_range(2.0, 10.0), _rng.randf_range(10.0, 40.0), 2.5)
			dust_flat(point, radius, maxi(2, int(spec.get("dust", 12)) / 2))
			var roll: Array = spec.get("skull_roll", [90, 140])
			for i in range(int(spec.get("skull", 1))):
				var skull := emit(point + back * 4.0, back.rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(float(roll[0]), float(roll[1])), bone[0], 5.0, "debris", 6.0, 10.0, _rng.randf_range(60.0, 110.0), 0.8)
				skull.skull = true
				skull.eyes = _hex_or(spec.get("eyes", ""), Color("2a2420"))
			crack(point + into * PIXEL * 2.0, back)
			stain(point, stain_color, radius * 0.3)
		"void":
			var v := _void_ramp()
			motes(point, int(spec.get("motes", 20)), [v[0], v[1], v[2]], 14.0)
			splat(point + back * radius * 0.3, stain_color, 0.85, float(spec.get("stain_r", 10)), back)
		"gold":
			var gold := _hexes(spec.get("colors", []), [Color("f3ce7d"), Color("c89a3a"), Color("fff0c0")])
			for i in range(int(spec.get("coins", 10))):
				var out := back.rotated(_rng.randf_range(-1.3, 1.3)) * _rng.randf_range(spray * 0.35, spray)
				emit(point, out, gold[i % 2], _rng.randf_range(2.0, 3.0), "debris", 4.0, 8.0, _rng.randf_range(90.0, 180.0), 1.5)
			sparks(point, back, int(spec.get("glints", 6)), [gold[gold.size() - 1], gold[0]])
	kick(point, radius, float(spec.get("kick", 1.0)))


## A liquid of `color` splashed on the wall a body struck at `point` (`into`
## pointing into it): where the first wall pixel along `into` lies within
## `reach` px, a ragged blob `size` px across painted over the wall's foot
## and face (unmasked, like crack), drips running down from it and a few
## spots flung round it. Without a wall in reach (or without a room) nothing.
func wall_splat(point: Vector2, into: Vector2, color: Color, size: float, reach: float = 24.0) -> void:
	var dir := into.normalized() if into.length() > 0.01 else Vector2.UP
	var hit := Vector2.INF
	var s := 0.0
	while s <= reach:
		if solid(point + dir * s):
			hit = point + dir * s
			break
		s += PIXEL
	if not hit.is_finite(): return
	_marks += 1
	var c := _art(hit)
	var n := maxi(1, int(size / PIXEL))
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			if Vector2(float(x), float(y) * 1.3).length() <= float(n) * _rng.randf_range(0.55, 1.0):
				_blend(c + Vector2i(x, y), Color(color, 0.95), false)
	for i in range(maxi(2, n)):
		var x := _rng.randi_range(-n, n)
		var length := _rng.randi_range(2, n * 2 + 2)
		for k in range(length):
			_blend(c + Vector2i(x, k), Color(color.darkened(0.25 * float(k) / float(length)), 0.9), false)
	for i in range(4):
		_blend(c + Vector2i(_rng.randi_range(-n * 2, n * 2), _rng.randi_range(-n * 2, n)), Color(color, 0.9), false)


## A rolling skull's cells turned `turn` quarter turns: [offset, shade] (0 bone, 1 shade, 2 socket).
static func _skull_cells(turn: int) -> Array:
	var out: Array = []
	for y in range(3):
		for x in range(3):
			var o := Vector2i(x - 1, y - 1)
			for i in range(posmod(turn, 4)): o = Vector2i(-o.y, o.x)
			out.append([o, int(SKULL[y][x])])
	return out


## The colour of a skull cell: its bone, the bone's shade or the socket.
static func _skull_colour(particle: Dictionary, shade: int) -> Color:
	var bone: Color = particle.color
	if shade == 2: return particle.get("eyes", Color("2a2420"))
	return bone.darkened(0.3) if shade == 1 else bone
