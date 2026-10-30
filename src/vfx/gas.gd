extends RefCounted
## Gas on the floor (poison clouds, breath, fumes, smoke, steam, void and
## frost mist) as clouds of puffs that move by simple physics
## (assets/data/vfx_gas.json). A cloud bursts out from where it appears, its
## puffs push each other apart, so it spreads into the room around it, flows
## through gaps and gathers in corners; walls stop and deflect them; it rolls
## slowly and is held softly in its zone. A blast blows it away and thins it
## (impulse), heroes and monsters walking through part it (part), shots cut
## a lane through it that closes again (cut). An ended cloud thins out from
## its rim inwards. Drawn on the art grid (`art` world px per art pixel) as
## one shape per material: overlapping puffs merge, density shows by the 4x4
## ordered dither, a lit top and a dark underside, never alpha. It lies under
## the actors (they always stay readable over it). Presentation only: every
## client runs its own; the zones the game hurts with are elsewhere.

const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const DATA_PATH := "res://assets/data/vfx_gas.json"

## World px per art pixel of the canvas it draws on.
var art := 2.0
## Callable(world point) -> bool: floor gas may be on (false inside walls).
var open: Callable
var cfg: Dictionary = {}
## "source:id" -> {mat, puffs: Array[{p, v, r, d, s}], end, at, r, source, dense}
var _clouds: Dictionary = {}
var _ramps: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _drawn_frame := -1
static var _data: Dictionary = {}


func _init(art_px: float, open_floor: Callable) -> void:
	art = art_px
	open = open_floor
	cfg = settings()
	_rng.seed = 7
	for mat: String in cfg.get("materials", {}):
		var ramp := {}
		var spec: Dictionary = cfg.materials[mat].get("ramp", {})
		for role: String in spec:
			ramp[role] = Color(str(spec[role]))
		_ramps[mat] = ramp


## vfx_gas.json, cached.
static func settings() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {"materials": {}}
	return _data


func _f(key: String, fallback: float) -> float:
	return float(cfg.get(key, fallback))


## A crypt size in world px of this canvas (the story worlds are 1.5 times larger).
func _u(crypt_px: float) -> float:
	return crypt_px * art / 2.0


## Takes in a source's gas zones ({id, k "gas", st material, x, y, r, p 0..1,
## L its length in s, d density 0..1, dx, dy a push}) and lets that source's
## clouds that left the list thin out.
func sync(zones: Array, now: float, source := "") -> void:
	var seen := {}
	for zone: Dictionary in zones:
		if str(zone.get("k", "")) != "gas":
			continue
		var mat := str(zone.get("st", "poison"))
		if not _ramps.has(mat):
			continue
		var key := "%s:%d" % [source, int(zone.get("id", -1))]
		seen[key] = true
		var at := Vector2(float(zone.x), float(zone.y))
		if _clouds.has(key):
			_clouds[key].at = at
			continue
		var length := float(zone.get("L", 4.0))
		var start := now - float(zone.get("p", 0.0)) * length
		_add(key, mat, at, float(zone.r), start + length, source, float(zone.get("d", 1.0)), Vector2(float(zone.get("dx", 0.0)), float(zone.get("dy", 0.0))), now - start < 0.3)
	for key: String in _clouds.keys():
		var cloud: Dictionary = _clouds[key]
		if str(cloud.source) == source and not seen.has(key) and float(cloud.end) > now:
			cloud.end = now


## A cloud that is not a zone (a breath, a burst of smoke): `mat` at `at`,
## radius `r`, for `length` s from `now`, thrown along `push` (world px/s).
func emit(key: String, mat: String, at: Vector2, r: float, length: float, now: float, push := Vector2.ZERO, dense := 1.0) -> void:
	if not _ramps.has(mat) or _clouds.has("fx:" + key):
		return
	_add("fx:" + key, mat, at, r, now + length, "fx", dense, push, true)


func _add(key: String, mat: String, at: Vector2, r: float, end: float, source: String, dense: float, push: Vector2, fresh: bool) -> void:
	var count := clampi(int(r / _u(_f("px_per_puff", 13.0))), int(_f("min_puffs", 5)), int(_f("max_puffs", 16)))
	var size := clampf(r * _f("puff_share", 0.3), _u(_f("puff_min", 7.0)), _u(_f("puff_max", 16.0)))
	var puffs: Array = []
	for i in range(count):
		var out := Vector2.from_angle(_rng.randf() * TAU)
		# a fresh cloud bursts out from its middle; a known one is already spread
		var spot := at + out * r * (_rng.randf_range(0.0, 0.25) if fresh else _rng.randf_range(0.2, 0.8)) * Vector2(1.0, 0.75)
		if not open.call(spot):
			spot = at
		var speed := _u(_f("spawn_speed", 70.0)) * _rng.randf_range(0.5, 1.0) if fresh else 0.0
		# a thrown cloud flies as one glob (its puffs keep pace with its middle, which
		# slows by travel_damping) and only spreads where it lands
		var carry := _f("damping", 1.6) / maxf(0.1, _f("travel_damping", 2.0))
		if push.length() > 1.0:
			speed *= _f("thrown_burst", 0.5)
		# fresh gas is at its thickest: a puff starts small and dense and swells (g 0..1 of its size)
		puffs.append({"p": spot, "v": out * speed + push * carry * _rng.randf_range(0.85, 1.1), "r": size * _rng.randf_range(0.75, 1.15), "d": dense, "g": _f("grow_from", 0.35) if fresh else 1.0, "s": _rng.randf() * 100.0})
	# a thrown cloud (not a zone) travels as a whole along its push until it slows or meets a wall
	var travel := push if source == "fx" else Vector2.ZERO
	_clouds[key] = {"mat": mat, "puffs": puffs, "end": end, "at": at, "av": travel, "r": r, "source": source, "dense": dense}


## A blast at `at` reaching `radius` (world px, `strength` 1 an explosion)
## blows the gas away from it and thins it there.
func impulse(at: Vector2, radius: float, strength: float) -> void:
	var speed := _u(_f("blast_speed", 220.0)) * strength
	var thin := _f("blast_thin", 0.3) * strength
	for key: String in _clouds:
		for puff: Dictionary in _clouds[key].puffs:
			var off: Vector2 = Vector2(puff.p) - at
			var reach := radius + float(puff.r)
			var dist := off.length()
			if dist >= reach:
				continue
			var k := 1.0 - dist / reach
			var away := off / dist if dist > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
			puff.v = Vector2(puff.v) + away * speed * k
			puff.d = float(puff.d) * (1.0 - thin * k)


## The blast hook of the particles (src/vfx/particles.gd kick): gas has no
## surface to ring, it is blown away. Returns false (no liquid rang).
func ripple_near(at: Vector2, radius: float, strength: float) -> bool:
	impulse(at, radius * 1.4, strength)
	return false


## The particles ask the layers they touch whether a liquid lies somewhere:
## gas is none.
func wet_at(_point: Vector2) -> bool:
	return false


## Someone standing at `at` (world px), `radius` wide, parts the gas round them.
func part(at: Vector2, radius: float) -> void:
	var speed := _u(_f("part_speed", 70.0))
	for key: String in _clouds:
		for puff: Dictionary in _clouds[key].puffs:
			var off: Vector2 = Vector2(puff.p) - at
			var reach := radius + float(puff.r) * 0.6
			var dist := off.length()
			if dist >= reach or dist < 0.01:
				continue
			var k := 1.0 - dist / reach
			puff.v = Vector2(puff.v) + off / dist * speed * k * 0.2
			puff.p = Vector2(puff.p) + off / dist * k * 0.6


## A shot at `at` flying along `dir` cuts a lane `width` wide through the gas:
## the puffs it passes are pushed aside (the lane closes again by itself).
func cut(at: Vector2, dir: Vector2, width: float) -> void:
	if dir.length() < 0.01:
		return
	var along := dir.normalized()
	var side := along.orthogonal()
	var speed := _u(_f("cut_speed", 110.0))
	for key: String in _clouds:
		for puff: Dictionary in _clouds[key].puffs:
			var off: Vector2 = Vector2(puff.p) - at
			if absf(off.dot(along)) > float(puff.r) + width:
				continue
			var across := off.dot(side)
			var reach := float(puff.r) * 0.7 + width
			if absf(across) >= reach:
				continue
			puff.v = Vector2(puff.v) + side * signf(across if absf(across) > 0.01 else 1.0) * speed * (1.0 - absf(across) / reach) * 0.25


## Runs the gas `dt` seconds on: puffs spread, roll, are held in their zone,
## slow down and slide along walls; ended clouds thin out rim first.
func step(dt: float, now: float) -> void:
	if dt <= 0.0:
		return
	dt = minf(dt, 0.05)
	var spread := _f("spread", 5.0)
	var hold := _f("hold", 2.2)
	var hold_from := _f("hold_from", 0.85)
	var drift := _u(_f("drift", 7.0))
	var damping := _f("damping", 1.6)
	var fade := maxf(0.1, _f("fade", 1.4))
	var edge := _f("edge_fade", 1.5)
	var travel_damping := _f("travel_damping", 2.0)
	var fan := _f("wall_fan", 0.6)
	var overlap := _f("overlap", 0.55)
	var grow := dt / maxf(0.05, _f("grow_time", 0.45))
	for key: String in _clouds.keys():
		var cloud: Dictionary = _clouds[key]
		var puffs: Array = cloud.puffs
		var at: Vector2 = cloud.at
		# a thrown cloud's middle travels on, slows, and stops at a wall (sliding along it)
		var av: Vector2 = cloud.get("av", Vector2.ZERO)
		if av.length_squared() > 1.0:
			var to := at + av * dt
			if not open.call(to):
				if open.call(Vector2(to.x, at.y)):
					to = Vector2(to.x, at.y)
					av.y = 0.0
				elif open.call(Vector2(at.x, to.y)):
					to = Vector2(at.x, to.y)
					av.x = 0.0
				else:
					to = at
					av = Vector2.ZERO
			at = to
			cloud.at = at
			cloud.av = av * maxf(0.0, 1.0 - travel_damping * dt)
		var r := maxf(1.0, float(cloud.r))
		var fading := now > float(cloud.end)
		# puffs push each other apart: the cloud spreads into the room
		for i in range(puffs.size()):
			var a: Dictionary = puffs[i]
			for j in range(i + 1, puffs.size()):
				var b: Dictionary = puffs[j]
				var delta: Vector2 = Vector2(b.p) - Vector2(a.p)
				var d := delta.length()
				# by their swollen size: a fresh cloud swells apart, it does not burst
				var least := (float(a.r) * float(a.get("g", 1.0)) + float(b.r) * float(b.get("g", 1.0))) * overlap
				if d >= least:
					continue
				var push := (delta / d if d > 0.01 else Vector2.from_angle(float(i + j))) * (least - d) * spread * dt
				a.v = Vector2(a.v) - push * 8.0
				b.v = Vector2(b.v) + push * 8.0
		for index in range(puffs.size() - 1, -1, -1):
			var puff: Dictionary = puffs[index]
			puff.g = minf(1.0, float(puff.get("g", 1.0)) + grow)
			var p: Vector2 = puff.p
			var v: Vector2 = puff.v
			var off := p - at
			var dist := Vector2(off.x, off.y / 0.75).length()
			# held softly in its zone, rolling slowly
			if not fading and dist > r * hold_from:
				v -= off.normalized() * (dist - r * hold_from) * hold * dt * 4.0
			var s := float(puff.s)
			v += Vector2(sin(now * 0.7 + s), cos(now * 0.53 + s * 1.3) * 0.6) * drift * dt * 2.0
			v *= maxf(0.0, 1.0 - damping * dt)
			# walls stop it: what runs into a wall fans out along it (the way it already
			# leans, else to its own side) and only a little bounces back
			var next := p + v * dt
			if not open.call(next):
				var side := signf(sin(s * 7.0)) if absf(sin(s * 7.0)) > 0.01 else 1.0
				if open.call(Vector2(next.x, p.y)):
					next = Vector2(next.x, p.y)
					v.x += (signf(v.x) if absf(v.x) > 2.0 else side) * absf(v.y) * fan
					v.y = -v.y * 0.15
				elif open.call(Vector2(p.x, next.y)):
					next = Vector2(p.x, next.y)
					v.y += (signf(v.y) if absf(v.y) > 2.0 else side) * absf(v.x) * fan
					v.x = -v.x * 0.15
				else:
					# a corner: it stays, packed in
					next = p
					v = -v * 0.15
			puff.p = next
			puff.v = v
			# thinning: an ended cloud goes, its rim first; puffs far out are thinner
			var d := float(puff.d)
			if fading:
				d -= dt / fade * (1.0 + edge * clampf(dist / r, 0.0, 2.0))
			else:
				d = minf(lerpf(d, float(cloud.dense), clampf(dt * 0.8, 0.0, 1.0)), float(cloud.dense) * clampf(1.6 - dist / r, 0.25, 1.0))
			puff.d = d
			if d <= 0.02:
				puffs.remove_at(index)
		if puffs.is_empty() and fading:
			_clouds.erase(key)


## Draws every cloud on the art grid: per material the puffs' coverage merged
## into one shape, shown by the dither (dense = solid), lit on top, dark
## underneath; cells stop at walls (PixelPaint.clip). Once a frame.
func draw(canvas: CanvasItem, now: float) -> void:
	var frame_now := Engine.get_process_frames()
	if frame_now == _drawn_frame:
		return
	_drawn_frame = frame_now
	var cover: Dictionary = {}
	for key: String in _clouds:
		var cloud: Dictionary = _clouds[key]
		var mat := str(cloud.mat)
		if not cover.has(mat):
			cover[mat] = {}
		var map: Dictionary = cover[mat]
		for puff: Dictionary in cloud.puffs:
			var c := Vector2(puff.p) / art
			# a puff breathes a little as it rolls
			var rc := float(puff.r) * float(puff.get("g", 1.0)) / art * (1.0 + 0.08 * sin(now * 1.7 + float(puff.s)))
			var ry := rc * 0.75
			var dense := float(puff.d)
			for y in range(int(floor(c.y - ry)), int(ceil(c.y + ry)) + 1):
				for x in range(int(floor(c.x - rc)), int(ceil(c.x + rc)) + 1):
					var e := Vector2((float(x) + 0.5 - c.x) / rc, (float(y) + 0.5 - c.y) / ry).length_squared()
					if e >= 1.0:
						continue
					var k := dense * clampf((1.0 - e) * 1.25, 0.0, 1.0)
					# overlapping puffs add up: one cloud, thick where they crowd
					var q := Vector2i(x, y)
					map[q] = minf(1.2, float(map.get(q, 0.0)) + k * 0.75)
	for mat: String in cover:
		var map: Dictionary = cover[mat]
		var R: Dictionary = _ramps[mat]
		for q: Vector2i in map:
			var k := float(map[q])
			# even its thickest part keeps a few holes: gas, not a solid
			if k < 0.06 or not PixelPaint.shown(q, minf(0.9, k * 1.1)):
				continue
			# lit on top only where it is thick, dark underneath, thinner parts in shade
			var col: Color = R.body
			if float(map.get(q + Vector2i(0, 1), 0.0)) < 0.08:
				col = R.deep
			elif k > 0.85 and float(map.get(q + Vector2i(0, -1), 0.0)) < k * 0.55:
				col = R.hi
			elif k > 0.8:
				col = R.lite
			elif k < 0.4:
				col = R.shade
			PixelPaint.cell(canvas, q, col, art)


## True when gas of any kind lies at `point` (world px), thick enough to see.
func covers(point: Vector2) -> bool:
	for key: String in _clouds:
		for puff: Dictionary in _clouds[key].puffs:
			if Vector2(puff.p).distance_to(point) < float(puff.r) * 0.8 and float(puff.d) > 0.2:
				return true
	return false


func clear() -> void:
	_clouds.clear()


## Clouds alive (for the debug overlay).
func count() -> int:
	return _clouds.size()
