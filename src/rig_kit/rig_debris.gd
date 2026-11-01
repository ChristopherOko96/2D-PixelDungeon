class_name RigDebris
extends RefCounted
## Shared debris physics: pieces that fly, bounce off a top-down floor and the
## world's walls, slide with friction, shove each other and come to rest, and
## above a cap crumble away by a 4x4 dither. Used by the part rigs' cut and
## fallen parts (src/rig/rig_renderer.gd, the ragdoll), the story worlds' wreck
## shards and chips (src/hell/story_wreck.gd) and a fallen hero's weapon
## (src/hero/hero_look.gd). It knows nothing of the game: the world answers
## through a RigDebrisHost (src/rig_kit/rig_debris_host.gd), the numbers come
## from data (assets/data/vfx_gore.json "ragdoll" for the rigs, see its
## _ragdoll_note; story_wreck.json materials; vfx_gore.json ragdoll.hero_weapon).
##
## A piece is a Dictionary: x, y (its spot on the floor, world px), z (height
## above it), vx, vy (floor velocity px/s), vz (up, px/s), ang, spin (rad,
## rad/s), life (s), rest (bool). Optional: k (scales gravity, rest_vz and
## rest_speed: a bigger figure falls the same way in its own px), phys (its own
## physics, else the debris'), gone_at (crumbling since clock), broken (removed
## at the end of the step). It adds landed, bounced (count) and impact (the fall
## speed of its last landing). Every other key is the host's and rides along.
##
## Physics keys (a missing key is off: 0, false, no limit):
## gravity px/s2; bounce (share of the fall speed a landing faster than rest_vz
## throws back up), ground_keep (share of the floor speed kept then), spin_keep
## (share of the spin kept, negative turns it round), bounces (most bounces,
## then the next hard landing stops it dead; none: no limit); wall_bounce (share
## of the speed a wall throws back), wall_spin (factor on the spin at a wall);
## friction (share of the slide speed lost per s), drag (px/s2 the slide slows
## by), spin_drag (rad/s2 the spin slows by while sliding); rest_speed (below it
## a sliding piece lies still), rest_spin (and its spin below this; none: any);
## snap_turn (turns: a sliding or lying piece eases its angle to the nearest
## multiple, plus snap_offset turns, at snap_rate per s); max_air (s: a piece
## still moving then lies down); radius (px: pieces on the floor shove each
## other apart, a moving one bounces off by shove); cap (standing pieces; above
## it the oldest resting ones crumble), dither_time (s a crumble takes).
## Launching (launch, fling): speed, spread, jitter, pop, depth, lift, spin,
## scatter, loose (see vfx_gore.json _ragdoll_note).

## What step_piece() did with a piece.
enum Step { AIR, BOUNCE, SLIDE, REST, IDLE }

## The gore table: the rigs' ragdoll physics live in its "ragdoll" block.
const GORE_PATH := "res://assets/data/vfx_gore.json"
## A held item whose hand lies this close to the blow's axis (cross product of
## the unit vectors) picks its side at random.
const SIDE_AXIS := 0.15
## Pieces closer than this (px) to the body centre get no outward pop, and two
## pieces closer than this (px) are not shoved (no direction between them).
const NEAR := 0.5
const TOUCH := 0.01

## The world: walls and the look's hooks (neutral RigDebrisHost when null).
var host: RigDebrisHost
## Physics of every piece without its own "phys" (see the header).
var phys: Dictionary = {}
## The pieces, oldest first.
var pieces: Array[Dictionary] = []
## Seconds stepped so far (born, gone_at and crumbling are measured on it).
var clock := 0.0
## Random numbers for launch() and fling(); hand in the host's to keep its sequence.
var rng: RandomNumberGenerator


## `physics`: the debris-wide physics (the dictionary is kept, not copied, so a
## host that reloads it in place changes every debris on it); `debris_host`:
## the world (null: open floor); `random`: the random numbers to launch with.
func _init(physics: Dictionary = {}, debris_host: RigDebrisHost = null, random: RandomNumberGenerator = null) -> void:
	phys = physics
	host = debris_host if debris_host != null else RigDebrisHost.new()
	rng = random if random != null else RandomNumberGenerator.new()


## The `block` dictionary of the JSON file at `path` ({} when the file, the
## block or the JSON is missing): vfx_gore.json "ragdoll" by default.
static func load_physics(path: String = GORE_PATH, block: String = "ragdoll") -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var found: Variant = parsed.get(block, {}) if parsed is Dictionary else {}
	return found if found is Dictionary else {}


## A value of the debris-wide physics, else `neutral`.
func value(key: String, neutral: Variant = 0.0) -> Variant:
	return phys.get(key, neutral)


## Adds a piece (see the header for its keys); it is stepped from the next step on.
func add(piece: Dictionary) -> void:
	pieces.append(piece)


## Forgets every piece (a new floor); the clock runs on.
func reset() -> void:
	pieces.clear()


## One step of every piece: the host's on_tick, the move (step_piece), the first
## bouncing landing's on_land (its new pieces join after the step), the shove
## between pieces on the floor, then broken and crumbled pieces go and the
## oldest resting ones above cap start to crumble.
func step(delta: float) -> void:
	clock += delta
	var born: Array[Dictionary] = []
	for d: Dictionary in pieces:
		host.on_tick(d, delta)
		if step_piece(d, delta) == Step.BOUNCE and not bool(d.get("landed", false)):
			d.landed = true
			born.append_array(host.on_land(d))
	_separate()
	if not born.is_empty(): pieces.append_array(born)
	var dither := float(phys.get("dither_time", 0.0))
	pieces = pieces.filter(func(d: Dictionary) -> bool: return not bool(d.get("broken", false)) and not (float(d.get("gone_at", -1.0)) >= 0.0 and clock - float(d.gone_at) > dither))
	_cap()


## Moves one piece by `delta` s under its physics (d.phys, else the debris'):
## gravity, the walls (host.solid; a piece that starts inside one leaves it
## freely; host.on_wall after a wall throws it back), its turn, then on the
## floor a bounce, a dead stop after its last bounce, or a slide with friction
## until it rests. Returns a Step: AIR, BOUNCE, SLIDE, REST (lay down this step)
## or IDLE (was resting). It neither ticks the host nor shatters (see step()).
func step_piece(d: Dictionary, delta: float) -> int:
	var p: Dictionary = d.phys if d.get("phys") is Dictionary else phys
	d.life = float(d.get("life", 0.0)) + delta
	if bool(d.get("rest", false)):
		_ease_snap(d, p, delta)
		return Step.IDLE
	var k := float(d.get("k", 1.0))
	var wall := float(p.get("wall_bounce", 0.0))
	var wall_spin := float(p.get("wall_spin", 0.0))
	d.vz = float(d.get("vz", 0.0)) - float(p.get("gravity", 0.0)) * k * delta
	d.z = float(d.get("z", 0.0)) + float(d.vz) * delta
	var at := Vector2(float(d.x), float(d.y))
	# a piece that starts inside a wall (cut at the wall) may leave it freely
	var inside := host.solid(at)
	var nx := at.x + float(d.get("vx", 0.0)) * delta
	if not inside and host.solid(Vector2(nx, at.y)):
		d.vx = -float(d.get("vx", 0.0)) * wall
		d.spin = float(d.get("spin", 0.0)) * wall_spin
		host.on_wall(d)
	else: d.x = nx
	var ny := at.y + float(d.get("vy", 0.0)) * delta
	if not inside and host.solid(Vector2(float(d.x), ny)):
		d.vy = -float(d.get("vy", 0.0)) * wall
		d.spin = float(d.get("spin", 0.0)) * wall_spin
		host.on_wall(d)
	else: d.y = ny
	d.ang = float(d.get("ang", 0.0)) + float(d.get("spin", 0.0)) * delta
	if float(d.z) > 0.0: return _aired(d, p, Step.AIR)
	d.z = 0.0
	var hard := float(d.vz) < -float(p.get("rest_vz", 0.0)) * k
	var most := int(p.get("bounces", -1))
	if hard and (most < 0 or int(d.get("bounced", 0)) < most):
		# a hard landing: it bounces back up and loses energy
		d.impact = -float(d.vz)
		var keep := float(p.get("ground_keep", 0.0))
		d.vz = -float(d.vz) * float(p.get("bounce", 0.0))
		d.vx = float(d.get("vx", 0.0)) * keep
		d.vy = float(d.get("vy", 0.0)) * keep
		d.spin = float(d.get("spin", 0.0)) * float(p.get("spin_keep", 0.0))
		d.bounced = int(d.get("bounced", 0)) + 1
		return _aired(d, p, Step.BOUNCE)
	if hard:
		# no bounce left: it stops dead where it lands
		d.impact = -float(d.vz)
		lie(d)
		return Step.REST
	# on the floor: it slides with friction until it lies still
	d.vz = 0.0
	var slide := maxf(0.0, 1.0 - float(p.get("friction", 0.0)) * delta)
	d.vx = float(d.get("vx", 0.0)) * slide
	d.vy = float(d.get("vy", 0.0)) * slide
	var drag := float(p.get("drag", 0.0))
	if drag > 0.0:
		var v := Vector2(float(d.vx), float(d.get("vy", 0.0))).move_toward(Vector2.ZERO, drag * delta)
		d.vx = v.x
		d.vy = v.y
	d.spin = float(d.get("spin", 0.0)) * slide
	var spin_drag := float(p.get("spin_drag", 0.0))
	if spin_drag > 0.0: d.spin = move_toward(float(d.spin), 0.0, spin_drag * delta)
	_ease_snap(d, p, delta)
	if Vector2(float(d.vx), float(d.vy)).length() < float(p.get("rest_speed", 0.0)) * k and absf(float(d.spin)) < float(p.get("rest_spin", INF)):
		lie(d)
		return Step.REST
	return _aired(d, p, Step.SLIDE)


## Lays piece `d` still where it is (on the floor, no speed, no spin).
func lie(d: Dictionary) -> void:
	d.rest = true
	d.vx = 0.0
	d.vy = 0.0
	d.spin = 0.0


## `result`, or REST when piece `d` has been moving longer than its max_air
## (it lies down on the floor at once).
func _aired(d: Dictionary, p: Dictionary, result: int) -> int:
	var most := float(p.get("max_air", 0.0))
	if most <= 0.0 or float(d.life) <= most: return result
	d.z = 0.0
	d.vz = 0.0
	lie(d)
	return Step.REST


## The angle a piece settles to under `p` (the multiple of snap_turn nearest
## its angle, shifted by snap_offset turns); its own angle without snap_turn.
static func snapped_angle(angle: float, p: Dictionary) -> float:
	var turn := float(p.get("snap_turn", 0.0)) * TAU
	if turn <= 0.0: return angle
	var offset := float(p.get("snap_offset", 0.0)) * TAU
	return roundf((angle - offset) / turn) * turn + offset


## Eases the angle of a sliding or lying piece toward snapped_angle at snap_rate per s.
func _ease_snap(d: Dictionary, p: Dictionary, delta: float) -> void:
	var rate := float(p.get("snap_rate", 0.0))
	if rate <= 0.0 or float(p.get("snap_turn", 0.0)) <= 0.0: return
	var angle := float(d.get("ang", 0.0))
	d.ang = lerp_angle(angle, snapped_angle(angle, p), 1.0 - exp(-rate * delta))


## Pieces on the floor shove each other apart (circles of radius): a moving one
## is pushed out and bounces off by shove, a resting one stays put, so they
## knock and pile up; a crumbling one is passed through.
func _separate() -> void:
	var r2 := float(phys.get("radius", 0.0)) * 2.0
	if r2 <= 0.0: return
	var shove := float(phys.get("shove", 0.0))
	for d: Dictionary in pieces:
		if bool(d.get("rest", false)) or float(d.get("z", 0.0)) > r2: continue
		for o: Dictionary in pieces:
			if is_same(o, d) or float(o.get("z", 0.0)) > r2 or float(o.get("gone_at", -1.0)) >= 0.0: continue
			var gap := Vector2(float(d.x) - float(o.x), float(d.y) - float(o.y))
			var dist := gap.length()
			if dist >= r2 or dist < TOUCH: continue
			var n := gap / dist
			# each of the two takes half the overlap
			var to := Vector2(float(d.x), float(d.y)) + n * (r2 - dist) * 0.5
			if not host.solid(to):
				d.x = to.x
				d.y = to.y
			var v := Vector2(float(d.get("vx", 0.0)), float(d.get("vy", 0.0)))
			var into := v.dot(n)
			if into < 0.0:
				v -= n * into * shove
				d.vx = v.x
				d.vy = v.y


## Above cap standing pieces, the oldest resting ones start to crumble (gone_at).
func _cap() -> void:
	var cap := int(phys.get("cap", -1))
	if cap < 0: return
	var standing := 0
	for d: Dictionary in pieces:
		if float(d.get("gone_at", -1.0)) < 0.0: standing += 1
	var over := standing - cap
	if over <= 0: return
	for d: Dictionary in pieces:
		if over <= 0: break
		if float(d.get("gone_at", -1.0)) >= 0.0 or not bool(d.get("rest", false)): continue
		d.gone_at = clock
		over -= 1


## How far piece `d` has crumbled: 0 standing, 1..3 quarters of its pixels gone
## (the 4x4 dither level to draw it with), 4 or more gone.
func crumble_level(d: Dictionary) -> int:
	var gone := float(d.get("gone_at", -1.0))
	if gone < 0.0: return 0
	var dither := maxf(0.01, float(phys.get("dither_time", 0.0)))
	return int((clock - gone) / dither * 4.0) + 1


## How a piece flies off a blow (the ragdoll): `dir` the blow's unit direction
## (ZERO: it scatters at random by scatter [x, y] px/s), `out` from the body
## centre to the piece, `impulse` the blow's weight, `k` the figure's scale
## (world px per source px over the base scale), `held` a weapon or shield
## coming loose from the hand (loose: off the blow's axis to its hand's side,
## slower and lower, always turning over). Returns {vx, vy, vz, spin}.
func launch(dir: Vector2, out: Vector2, impulse: float, k: float, held: bool) -> Dictionary:
	var loose: Dictionary = loose_spec() if held else {}
	var v := Vector2.ZERO
	if dir == Vector2.ZERO:
		var scatter: Array = phys.get("scatter", [0.0, 0.0])
		v = Vector2(rng.randf_range(-float(scatter[0]), float(scatter[0])), rng.randf_range(-float(scatter[1]), float(scatter[1]))) * impulse
	else:
		var jitter: Array = phys.get("jitter", [1.0, 1.0])
		var spread := float(phys.get("spread", 0.0))
		var aim := dir.rotated(rng.randf_range(-spread, spread))
		if held:
			var across := dir.cross(out.normalized()) if out.length() > NEAR else 0.0
			var side := signf(across) if absf(across) > SIDE_AXIS else (1.0 if rng.randf() < 0.5 else -1.0)
			aim = dir.rotated(side * float(loose.get("side", 0.0)) + rng.randf_range(-spread, spread) * 0.5)
		v = aim * float(phys.get("speed", 0.0)) * impulse * rng.randf_range(float(jitter[0]), float(jitter[1])) * (float(loose.get("speed", 1.0)) if held else 1.0)
		if out.length() > NEAR: v += out.normalized() * float(phys.get("pop", 0.0)) * sqrt(impulse)
	# a bigger figure (story worlds) throws in proportion: the same flight in its own source px
	v *= k
	var lift: Array = phys.get("lift", [0.0, 0.0])
	var vz := rng.randf_range(float(lift[0]), float(lift[1])) * sqrt(maxf(0.1, impulse)) * k * (float(loose.get("lift", 1.0)) if held else 1.0)
	var spin := rng.randf_range(-1.0, 1.0) * float(phys.get("spin", 0.0)) * impulse
	if held: spin = loose_spin(loose, impulse)
	return {"vx": v.x, "vy": v.y * float(phys.get("depth", 1.0)), "vz": vz, "spin": spin}


## The physics' "loose" block: how a held item comes loose (side rad, speed and
## lift factors, spin [min, max] rad/s); {} without one.
func loose_spec() -> Dictionary:
	var spec: Variant = phys.get("loose", {})
	return spec if spec is Dictionary else {}


## The turn of a loose item: loose.spin [min, max] rad/s either way, times the
## root of the impulse (never below the minimum).
func loose_spin(loose: Dictionary, impulse: float) -> float:
	var turn: Array = loose.spin if loose.get("spin") is Array and (loose.spin as Array).size() >= 2 else [0.0, 0.0]
	return (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(float(turn[0]), float(turn[1])) * maxf(1.0, sqrt(maxf(0.0, impulse)))


## Throws piece `d` again along unit `dir` (a body flung against a wall comes
## apart along the rebound): `spec` gives speed px/s, spread rad round `dir`,
## jitter [lo, hi] on the speed, lift [lo, hi] px/s up, spin rad/s either way
## and depth (factor on the floor's y); all times `power`. A held piece leaves
## the line by the loose side and turns over (loose_spin).
func fling(d: Dictionary, dir: Vector2, power: float, spec: Dictionary) -> void:
	var spread := float(spec.get("spread", 0.0))
	var jitter: Array = spec.get("jitter", [1.0, 1.0])
	var lift: Array = spec.get("lift", [0.0, 0.0])
	var turn := float(spec.get("spin", 0.0))
	var out := dir.rotated(rng.randf_range(-spread, spread)) * float(spec.get("speed", 0.0)) * power * rng.randf_range(float(jitter[0]), float(jitter[1]))
	d.vz = rng.randf_range(float(lift[0]), float(lift[1])) * power
	d.spin = rng.randf_range(-turn, turn)
	if bool(d.get("held", false)):
		var loose := loose_spec()
		out = out.rotated((1.0 if rng.randf() < 0.5 else -1.0) * float(loose.get("side", 0.0))) * float(loose.get("speed", 1.0))
		d.vz = float(d.vz) * float(loose.get("lift", 1.0))
		d.spin = loose_spin(loose, power)
	d.vx = out.x
	d.vy = out.y * float(spec.get("depth", 1.0))
	d.rest = false
