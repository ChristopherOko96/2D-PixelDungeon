class_name GasField
extends RefCounted
## Gas on the floor as gameplay (BAUPLAN M1d): poison clouds, breath, fumes,
## smoke, steam, void and frost mist as clouds of puffs that move by simple
## physics, and what a creature breathes where it stands. A cloud bursts out
## from where it appears, its puffs push each other apart (spread) so it fills
## the room around it, flows through gaps and gathers in corners; walls stop
## and deflect them; it rolls slowly and is held softly in its zone. A blast
## blows it away and thins it (impulse), the void sucks it in (suck), whoever
## walks through parts it (part), shots cut a lane that closes again (cut). An
## ended cloud thins out from its rim inwards.
##
## What it answers: at(point) and around(point, r) (the thickest material and
## its thickness 0..1: what is breathed, ElementExposure's gas_around),
## thickness, extent (how far the view reaches inside it), covers, clouds_of
## and end_cloud (the reactions: fire sets poison gas off).
##
## Values: assets/data/vfx_gas.json (puff physics; seed). Lengths in it are crypt
## px (art 2) and scale with the field's art pixel.
##
## Determinism: the puffs are data, moved only by step(dt, now) on the host's
## clock and by the calls above, in the order the host makes them; the dice
## (where a new cloud's puffs start, a blast's direction at its very middle)
## are one RandomNumberGenerator per field seeded from vfx_gas.json seed. The
## same calls give the same gas on every machine. The host's order each frame
## in the story worlds (src/hell/hell_game.gd _step_gas): step, then the hero
## parts it, then every monster.
##
## Drawing is someone else's: src/vfx/gas.gd draws this field as a see-through
## veil. The host is a FieldHost (src/physics_kit/field_host.gd): where the
## floor is open.
##
## [codeblock]
## var gas := GasField.new(3.0)
## gas.emit("breath:1", "poison", Vector2(200, 200), 60.0, 4.0, 0.0)
## for i in range(60): gas.step(1.0 / 60.0, i / 60.0)
## print(gas.around(Vector2(200, 200), 24.0, 4))  # {"mat": "poison", "d": ...}
## [/codeblock]

const Host := preload("res://src/physics_kit/field_host.gd")
const CallableHost := preload("res://src/physics_kit/callable_field_host.gd")
const DATA_PATH := "res://assets/data/vfx_gas.json"

## World px per art pixel of the world (the gas's lengths scale with it).
var art := 2.0
## Where the floor is open (src/physics_kit/field_host.gd).
var host: RefCounted
## vfx_gas.json (shared with the painter; a test may set its own copy).
var cfg: Dictionary = {}
## "source:id" -> {mat, puffs: Array[{p, v, r, d, g, s}], end, at, av, r, source, dense}
var _clouds: Dictionary = {}
## Clouds burnt or eaten (end_cloud) while their zone still lists them: a sync must not bring
## them back whole (physics plan F26); forgotten when their zone is gone.
var _spent: Dictionary = {}
## The world's wind (world px/s): the puffs drift with wind_share of it (physics plan F58).
var wind := Vector2.ZERO
## Puffs of burning clouds that just went up ({at, r, mat}; ignite, take_burnt).
var _burnt: Array = []
var _rng := RandomNumberGenerator.new()
static var _data: Dictionary = {}


## A gas field on a world of `art_px` world px per art pixel, its open floor
## told by `field_host` (a FieldHost; null: open everywhere).
func _init(art_px := 2.0, field_host: RefCounted = null) -> void:
	art = art_px
	host = field_host if field_host != null else Host.new()
	cfg = settings()
	_rng.seed = int(cfg.get("seed", 7))


## vfx_gas.json, read once and shared (the painter reads the same).
static func settings() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {"materials": {}}
	return _data


## True when `mat` is a gas here (vfx_gas.json materials).
func has_material(mat: String) -> bool:
	return (cfg.get("materials", {}) as Dictionary).has(mat)


func _f(key: String, fallback: float) -> float:
	return float(cfg.get(key, fallback))


## A crypt length (art 2) in world px of this field.
func _u(crypt_px: float) -> float:
	return crypt_px * art / MatterKit.crypt_art()


func _open(point: Vector2) -> bool:
	return host.is_open(point)


# ---------- clouds come and go ----------

## Takes in a source's gas zones ({id, k "gas", st material, x, y, r, p 0..1,
## L its length in s, d density 0..1, dx, dy a push}) at the host's time
## `now`; that source's clouds that left the list thin out.
func sync(zones: Array, now: float, source := "") -> void:
	var seen := {}
	for zone: Dictionary in zones:
		if str(zone.get("k", "")) != "gas":
			continue
		var mat := str(zone.get("st", "poison"))
		if not has_material(mat):
			continue
		var key := "%s:%d" % [source, int(zone.get("id", -1))]
		seen[key] = true
		if _spent.has(key):
			continue
		var at := Vector2(float(zone.x), float(zone.y))
		if _clouds.has(key):
			_clouds[key].at = at
			continue
		var length := float(zone.get("L", 4.0))
		var start := now - float(zone.get("p", 0.0)) * length
		_add(key, mat, at, float(zone.r), start + length, source, float(zone.get("d", 1.0)), Vector2(float(zone.get("dx", 0.0)), float(zone.get("dy", 0.0))), now - start < 0.3)
	for key: String in _spent.keys():
		if key.begins_with(source + ":") and not seen.has(key):
			_spent.erase(key)
	for key: String in _clouds.keys():
		var cloud: Dictionary = _clouds[key]
		if str(cloud.source) == source and not seen.has(key) and float(cloud.end) > now:
			cloud.end = now


## A cloud that is not a zone (a breath, a burst of smoke): `mat` at `at`,
## radius `r` (world px), for `length` s from `now`, thrown along `push`
## (world px/s), `dense` 0..1. A key already known is ignored.
func emit(key: String, mat: String, at: Vector2, r: float, length: float, now: float, push := Vector2.ZERO, dense := 1.0) -> void:
	if not has_material(mat) or _clouds.has("fx:" + key):
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
		if not _open(spot):
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


## Ends cloud `key` at `now`: it thins out from its rim (a reaction used it up).
func end_cloud(key: String, now: float) -> void:
	_spent[key] = true
	if _clouds.has(key):
		_clouds[key].end = minf(float(_clouds[key].end), now)


## Forgets every cloud (a new room, the end of a world).
func clear() -> void:
	_clouds.clear()
	_spent.clear()


# ---------- what moves it ----------

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


## The void at `at` sucks the gas within `radius` (world px) toward it: the
## puffs stream inward at up to `pull` px/s, inside the mouth they thin by
## `thin` per second and the cloud's own density goes with them, so a cloud
## eaten whole ends. Returns true while any puff was touched.
func suck(at: Vector2, radius: float, pull: float, thin: float, dt: float, now: float) -> bool:
	var any := false
	for key: String in _clouds:
		var cloud: Dictionary = _clouds[key]
		var touched := false
		for puff: Dictionary in cloud.puffs:
			var off: Vector2 = Vector2(puff.p) - at
			var dist := off.length()
			var reach := radius + float(puff.r)
			if dist >= reach:
				continue
			touched = true
			var k := 1.0 - dist / reach
			var inward := -off / dist if dist > 0.01 else Vector2.ZERO
			puff.v = Vector2(puff.v) + inward * pull * (0.5 + k) * dt * 3.0
			if dist < radius * 0.4:
				puff.d = float(puff.d) - thin * dt
				cloud.dense = maxf(0.0, float(cloud.dense) - thin * dt * 0.5)
		if touched:
			any = true
			# its middle follows what is left of it; eaten to nothing, it ends
			cloud.at = Vector2(cloud.at).lerp(at, clampf(dt * 1.2, 0.0, 1.0))
			if float(cloud.dense) <= 0.06 or (cloud.puffs as Array).size() <= 1:
				cloud.end = minf(float(cloud.end), now)
	return any


## The blast hook of the particles (src/vfx/particles.gd kick): gas has no
## surface to ring, it is blown away. Returns false (no liquid rang).
func ripple_near(at: Vector2, radius: float, strength: float) -> bool:
	impulse(at, radius * 1.4, strength)
	return false


## The particles ask the layers they touch whether a liquid lies somewhere:
## gas is none.
func wet_at(_point: Vector2) -> bool:
	return false


## Someone standing at `at` (world px), `radius` wide, parts the gas round them over `dt` s
## (per second, so the parting and the dose do not change with the frame rate; F22).
func part(at: Vector2, radius: float, dt: float = 1.0 / 60.0) -> void:
	var speed := _u(_f("part_speed", 70.0))
	for key: String in _clouds:
		for puff: Dictionary in _clouds[key].puffs:
			var off: Vector2 = Vector2(puff.p) - at
			var reach := radius + float(puff.r) * 0.6
			var dist := off.length()
			if dist >= reach or dist < 0.01:
				continue
			var k := 1.0 - dist / reach
			puff.v = Vector2(puff.v) + off / dist * speed * k * 12.0 * dt
			puff.p = Vector2(puff.p) + off / dist * k * 36.0 * dt


## A shot at `at` flying along `dir` cuts a lane `width` wide through the gas:
## the puffs it passes are pushed aside (the lane closes again by itself), over `dt` s.
func cut(at: Vector2, dir: Vector2, width: float, dt: float = 1.0 / 60.0) -> void:
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
			puff.v = Vector2(puff.v) + side * signf(across if absf(across) > 0.01 else 1.0) * speed * (1.0 - absf(across) / reach) * 15.0 * dt


## Runs the gas `dt` seconds on (the host's clock `now`): puffs spread, roll,
## are held in their zone, slow down and slide along walls; ended clouds thin
## out rim first and are forgotten when gone.
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
		# each gas moves like its material (vfx_gas.json materials.<mat>.physics; physics plan
		# R11/F16): steam light and quickly gone, smoke drifting, poison heavy and slow, frost mist
		# spreading flat; a missing factor is 1
		var phys: Dictionary = ((cfg.get("materials", {}) as Dictionary).get(str(cloud.mat), {}) as Dictionary).get("physics", {})
		var c_hold := hold * float(phys.get("hold_k", 1.0))
		var c_drift := drift * float(phys.get("drift_k", 1.0))
		var c_damp := damping * float(phys.get("damping_k", 1.0))
		var c_wind := _f("wind_share", 0.5) * float(phys.get("wind_k", 1.0))
		if not cloud.has("born"):
			cloud.born = now
			if phys.has("life"): cloud.end = minf(float(cloud.end), now + float(phys.life))
		var at: Vector2 = cloud.at
		# a thrown cloud's middle travels on, slows, and stops at a wall (sliding along it)
		var av: Vector2 = cloud.get("av", Vector2.ZERO)
		if av.length_squared() > 1.0:
			var to := at + av * dt
			if not _open(to):
				if _open(Vector2(to.x, at.y)):
					to = Vector2(to.x, at.y)
					av.y = 0.0
				elif _open(Vector2(at.x, to.y)):
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
			# a burning cloud: the flame front reaches this puff and it goes up (ignite)
			if puff.has("burn_at") and float(puff.burn_at) <= now:
				_burnt.append({"at": Vector2(puff.p), "r": float(puff.r) * float(puff.get("g", 1.0)), "mat": str(cloud.mat)})
				puffs.remove_at(index)
				continue
			puff.g = minf(1.0, float(puff.get("g", 1.0)) + grow)
			var p: Vector2 = puff.p
			var v: Vector2 = puff.v
			var off := p - at
			var dist := Vector2(off.x, off.y / 0.75).length()
			# held softly in its zone, rolling slowly
			if not fading and dist > r * hold_from:
				v -= off.normalized() * (dist - r * hold_from) * c_hold * dt * 4.0
			var s := float(puff.s)
			v += Vector2(sin(now * 0.7 + s), cos(now * 0.53 + s * 1.3) * 0.6) * c_drift * dt * 2.0
			v += wind * c_wind * c_damp * dt
			v *= maxf(0.0, 1.0 - c_damp * dt)
			# walls stop it: what runs into a wall fans out along it (the way it already
			# leans, else to its own side) and only a little bounces back
			var next := p + v * dt
			if not _open(next):
				var side := signf(sin(s * 7.0)) if absf(sin(s * 7.0)) > 0.01 else 1.0
				if _open(Vector2(next.x, p.y)):
					next = Vector2(next.x, p.y)
					v.x += (signf(v.x) if absf(v.x) > 2.0 else side) * absf(v.y) * fan
					v.y = -v.y * 0.15
				elif _open(Vector2(p.x, next.y)):
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


# ---------- what lies where ----------

## How thick the gas is at `point` (world px), for the game's rules: the
## material lying thickest there and its thickness 0..1, the puffs' coverage
## added up (a puff is an ellipse, three quarters as high as wide).
## {"mat": "", "d": 0} in clear air.
func at(point: Vector2) -> Dictionary:
	var best_mat := ""
	var best := 0.0
	for key: String in _clouds:
		var cloud: Dictionary = _clouds[key]
		var sum := _cover(cloud.puffs, point)
		if sum > best:
			best = sum
			best_mat = str(cloud.mat)
	return {"mat": best_mat, "d": clampf(best, 0.0, 1.0)}


## The gas round someone standing at `point`: whoever stands in a cloud parts
## it (part), so right under the feet it is thin; the thickest of `samples`
## points on a ring of `radius` round the feet (and the feet themselves) is
## what they breathe. Same result as at().
func around(point: Vector2, radius: float, samples := 8) -> Dictionary:
	var best := at(point)
	for i in range(samples):
		var sample := at(point + Vector2.from_angle(TAU * float(i) / float(samples)) * radius)
		if float(sample.d) > float(best.d):
			best = sample
	return best


## The clouds of `mat` alive at `now` (for the reactions: fire sets poison gas
## off): {key, at, r} each, `at` the middle of its puffs now. A cloud already
## ended (used up by a reaction) only thins out: it is gone for the rules.
## The clouds of `mat` whose puffs (where the gas really is, not its middle) reach within `r` of
## `at`: [{key, at: the nearest puff, r}] (physics plan F14).
func touching(mat: String, at: Vector2, r: float, now := -INF) -> Array:
	var out: Array = []
	for key: String in _clouds:
		var cloud: Dictionary = _clouds[key]
		if str(cloud.mat) != mat or float(cloud.end) <= now or bool(cloud.get("burning", false)):
			continue
		var best := INF
		var near := Vector2.ZERO
		for puff: Dictionary in cloud.puffs:
			var d := Vector2(puff.p).distance_to(at) - float(puff.r) * float(puff.get("g", 1.0))
			if d < best:
				best = d
				near = puff.p
		if best <= r:
			out.append({"key": key, "at": near, "r": float(cloud.r)})
	return out


## The clouds of `mat` with a puff where `here` (Callable(at) -> bool) holds: [{key, at: that
## puff, r}] (gas drifting over heat; physics plan R13).
func touching_where(mat: String, here: Callable, now := -INF) -> Array:
	var out: Array = []
	for key: String in _clouds:
		var cloud: Dictionary = _clouds[key]
		if str(cloud.mat) != mat or float(cloud.end) <= now or bool(cloud.get("burning", false)):
			continue
		for puff: Dictionary in cloud.puffs:
			if here.call(Vector2(puff.p)):
				out.append({"key": key, "at": Vector2(puff.p), "r": float(cloud.r)})
				break
	return out


## Sets cloud `key` burning from `from` (physics plan F14): a flame front runs through its puffs
## at `speed` px/s (each goes up at its distance from `from`, on the host clock), every puff that
## burns leaves the cloud as {at, r, mat} for take_burnt; burnt gas never comes back (_spent).
func ignite(key: String, from: Vector2, now: float, speed: float) -> void:
	if not _clouds.has(key):
		return
	_spent[key] = true
	var cloud: Dictionary = _clouds[key]
	cloud.burning = true
	for puff: Dictionary in cloud.puffs:
		puff.burn_at = now + Vector2(puff.p).distance_to(from) / maxf(1.0, speed)


## The puffs that went up since the last call ({at, r, mat}).
func take_burnt() -> Array:
	var out := _burnt
	_burnt = []
	return out


func clouds_of(mat: String, now := -INF) -> Array:
	var out: Array = []
	for key: String in _clouds:
		var cloud: Dictionary = _clouds[key]
		if str(cloud.mat) != mat or (cloud.puffs as Array).is_empty():
			continue
		if float(cloud.end) <= now:
			continue
		var middle := Vector2.ZERO
		for puff: Dictionary in cloud.puffs:
			middle += Vector2(puff.p)
		out.append({"key": key, "at": middle / float((cloud.puffs as Array).size()), "r": float(cloud.r)})
	return out


## The thickness of `mat` alone at `point` (0..1).
func thickness(point: Vector2, mat: String) -> float:
	var sum := 0.0
	for key: String in _clouds:
		var cloud: Dictionary = _clouds[key]
		if str(cloud.mat) == mat:
			sum += _cover(cloud.puffs, point)
	return clampf(sum, 0.0, 1.0)


func _cover(puffs: Array, point: Vector2) -> float:
	var sum := 0.0
	for puff: Dictionary in puffs:
		var rc := float(puff.r) * float(puff.get("g", 1.0))
		if rc <= 0.01:
			continue
		var off: Vector2 = point - Vector2(puff.p)
		var k := sqrt((off.x * off.x) / (rc * rc) + (off.y * off.y) / (rc * rc * 0.5625))
		if k < 1.0:
			sum += (1.0 - k) * float(puff.d)
	return sum


## How far the gas of `mat` reaches round `point` (world px): the farthest a
## ray in eight directions gets before the cloud thins below `thin`, at most
## `max_len`, in steps of `step`. The view inside a cloud reaches that far.
func extent(point: Vector2, mat: String, thin: float, step: float, max_len: float) -> float:
	var far := 0.0
	for i in range(8):
		var dir := Vector2.from_angle(TAU * float(i) / 8.0)
		var l := 0.0
		while l < max_len:
			var next := l + step
			if thickness(point + dir * next, mat) < thin:
				break
			l = next
		far = maxf(far, l)
	return far


## True when gas of any kind lies at `point` (world px), thick enough to see.
func covers(point: Vector2) -> bool:
	for key: String in _clouds:
		for puff: Dictionary in _clouds[key].puffs:
			if Vector2(puff.p).distance_to(point) < float(puff.r) * 0.8 and float(puff.d) > 0.2:
				return true
	return false


## Clouds alive (for the debug overlay).
func count() -> int:
	return _clouds.size()


## Every cloud, key -> {mat, puffs [{p, v, r, d, g, s}], end, at, r, ...}; read
## only (a painter draws them).
func clouds() -> Dictionary:
	return _clouds
