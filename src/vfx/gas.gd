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
## material -> {tex: ImageTexture, at: Vector2i first art cell, size: Vector2i}
var _layers: Dictionary = {}
## block of 8 x 8 art cells -> where gas may show in it (_open_block), and since when (ms).
var _open_memo: Dictionary = {}
var _open_since := 0
## 4x4 ordered dither thresholds (PixelPaint.BAYER).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
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


## How thick the gas is at `point` (world px), for the game's rules
## (src/combat/element_rules.gd): the material lying thickest there and its
## thickness 0..1, the puffs' coverage added up as the drawing adds it (a puff
## is an ellipse, three quarters as high as wide). {"mat": "", "d": 0} in clear air.
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


## The clouds of `mat` alive (for the game's reactions: fire sets poison gas
## off): {key, at, r} each, `at` the middle of its puffs now.
func clouds_of(mat: String, now := -INF) -> Array:
	var out: Array = []
	for key: String in _clouds:
		var cloud: Dictionary = _clouds[key]
		if str(cloud.mat) != mat or (cloud.puffs as Array).is_empty():
			continue
		# a cloud already ended (used up by a reaction) only thins out: it is gone for the rules
		if float(cloud.end) <= now:
			continue
		var at := Vector2.ZERO
		for puff: Dictionary in cloud.puffs:
			at += Vector2(puff.p)
		out.append({"key": key, "at": at / float((cloud.puffs as Array).size()), "r": float(cloud.r)})
	return out


## Ends cloud `key` now: it thins out from its rim (a reaction used it up).
func end_cloud(key: String, now: float) -> void:
	if _clouds.has(key):
		_clouds[key].end = minf(float(_clouds[key].end), now)


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
## `max_len`. The view inside a cloud reaches that far (element_rules.gd vision).
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
## underneath; cells stop at walls (`open`). The shape is worked out at most
## draw_hz times a second into one image per material (the pixel look moves
## on a beat anyway; one material a frame, the one waiting longest, a new one
## at once) and drawn as one texture every frame. Once a frame.
func draw(canvas: CanvasItem, now: float) -> void:
	var frame_now := Engine.get_process_frames()
	if frame_now == _drawn_frame:
		return
	_drawn_frame = frame_now
	if _clouds.is_empty():
		_layers.clear()
		return
	var every := 1.0 / maxf(1.0, _f("draw_hz", 15.0))
	var alive := {}
	for key: String in _clouds:
		alive[str(_clouds[key].mat)] = true
	for mat: String in _layers.keys():
		if not alive.has(mat):
			_layers.erase(mat)
	var next := ""
	var waited := -1.0
	for mat: String in alive:
		var built := float((_layers.get(mat, {}) as Dictionary).get("built", -1.0))
		if built < 0.0 or now < built:
			next = mat
			break
		if now - built >= every and now - built > waited:
			next = mat
			waited = now - built
	if next != "":
		_build(next, now)
	for mat: String in _layers:
		var layer: Dictionary = _layers[mat]
		canvas.draw_texture_rect(layer.tex, Rect2(Vector2(layer.at) * art, Vector2(layer.size) * art), false)


## Works out material `mat`'s shape into its image (see draw).
func _build(mat: String, now: float) -> void:
	var list := PackedFloat32Array()
	for key: String in _clouds:
		var cloud: Dictionary = _clouds[key]
		if str(cloud.mat) != mat:
			continue
		for puff: Dictionary in cloud.puffs:
			# a puff breathes a little as it rolls
			var rc := float(puff.r) * float(puff.get("g", 1.0)) / art * (1.0 + 0.08 * sin(now * 1.7 + float(puff.s)))
			if rc <= 0.01:
				continue
			list.append(Vector2(puff.p).x / art)
			list.append(Vector2(puff.p).y / art)
			list.append(rc)
			list.append(float(puff.d))
	if list.is_empty():
		_layers.erase(mat)
		return
	_build_layer(mat, list)
	_layers[mat].built = now


## One material's image: the puffs' coverage added up (overlapping puffs make
## one cloud, thick where they crowd), then per cell its colour by the dither
## and its neighbours above and below.
func _build_layer(mat: String, list: PackedFloat32Array) -> void:
	var lo_x := 1 << 30
	var lo_y := 1 << 30
	var hi_x := -(1 << 30)
	var hi_y := -(1 << 30)
	for n in range(0, list.size(), 4):
		var rc := list[n + 2]
		lo_x = mini(lo_x, int(floor(list[n] - rc)))
		hi_x = maxi(hi_x, int(ceil(list[n] + rc)))
		lo_y = mini(lo_y, int(floor(list[n + 1] - rc * 0.75)))
		hi_y = maxi(hi_y, int(ceil(list[n + 1] + rc * 0.75)))
	# a row of air above and below for the neighbour tests
	lo_y -= 1
	hi_y += 1
	var w := hi_x - lo_x + 1
	var h := hi_y - lo_y + 1
	var cover := PackedFloat32Array()
	cover.resize(w * h)
	for n in range(0, list.size(), 4):
		var cx := list[n]
		var cy := list[n + 1]
		var rc := list[n + 2]
		var ry := rc * 0.75
		var dense := list[n + 3]
		for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
			var dy := (float(y) + 0.5 - cy) / ry
			var dy2 := dy * dy
			if dy2 >= 1.0:
				continue
			var half := rc * sqrt(1.0 - dy2)
			var row := (y - lo_y) * w - lo_x
			for x in range(int(floor(cx - half)), int(ceil(cx + half)) + 1):
				var dx := (float(x) + 0.5 - cx) / rc
				var e := dx * dx + dy2
				if e >= 1.0:
					continue
				var i := row + x
				cover[i] = minf(1.2, cover[i] + dense * minf(1.0, (1.0 - e) * 1.25) * 0.75)
	var R: Dictionary = _ramps[mat]
	var cols := [_rgb(R.body), _rgb(R.deep), _rgb(R.hi), _rgb(R.lite), _rgb(R.shade)]
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	var block := PackedByteArray()
	var block_key := Vector2i(1 << 30, 0)
	for y in range(1, h - 1):
		var qy := lo_y + y
		var bayer_row := (qy & 3) << 2
		for x in range(w):
			var i := y * w + x
			var k := cover[i]
			var qx := lo_x + x
			# even its thickest part keeps a few holes: gas, not a solid
			if k < 0.06 or float(BAYER[bayer_row | (qx & 3)]) >= minf(0.9, k * 1.1) * 16.0:
				continue
			# walls: asked by blocks of 8 x 8 cells, remembered
			var key := Vector2i(qx >> 3, qy >> 3)
			if key != block_key:
				block_key = key
				block = _open_block(key)
			if block[((qy & 7) << 3) | (qx & 7)] == 0:
				continue
			# lit on top only where it is thick, dark underneath, thinner parts in shade
			var c: int = 0
			if cover[i + w] < 0.08:
				c = 1
			elif k > 0.85 and cover[i - w] < k * 0.55:
				c = 2
			elif k > 0.8:
				c = 3
			elif k < 0.4:
				c = 4
			var rgb: PackedByteArray = cols[c]
			var b := i * 4
			bytes[b] = rgb[0]
			bytes[b + 1] = rgb[1]
			bytes[b + 2] = rgb[2]
			bytes[b + 3] = 255
	var image := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	var layer: Dictionary = _layers.get(mat, {})
	if layer.has("tex") and Vector2i(layer.size) == Vector2i(w, h):
		(layer.tex as ImageTexture).update(image)
	else:
		layer.tex = ImageTexture.create_from_image(image)
	layer.at = Vector2i(lo_x, lo_y)
	layer.size = Vector2i(w, h)
	_layers[mat] = layer


static func _rgb(c: Color) -> PackedByteArray:
	return PackedByteArray([c.r8, c.g8, c.b8])


## Where gas may show in the block `b` of 8 x 8 art cells (`open` at each
## cell's middle; 1 open, 0 wall), remembered: asked once per cell, forgotten
## with the room (clear) and every open_memory_s s (a broken wall opens cells).
func _open_block(b: Vector2i) -> PackedByteArray:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _open_since > int(_f("open_memory_s", 3.0) * 1000.0) or _open_memo.size() > 20000:
		_open_memo.clear()
		_open_since = now_ms
	var known: Variant = _open_memo.get(b)
	if known != null:
		return known
	var bits := PackedByteArray()
	bits.resize(64)
	for y in range(8):
		for x in range(8):
			var q := Vector2(b.x * 8 + x, b.y * 8 + y) + Vector2(0.5, 0.5)
			bits[y * 8 + x] = 1 if not open.is_valid() or bool(open.call(q * art)) else 0
	_open_memo[b] = bits
	return bits


## True when gas of any kind lies at `point` (world px), thick enough to see.
func covers(point: Vector2) -> bool:
	for key: String in _clouds:
		for puff: Dictionary in _clouds[key].puffs:
			if Vector2(puff.p).distance_to(point) < float(puff.r) * 0.8 and float(puff.d) > 0.2:
				return true
	return false


func clear() -> void:
	_clouds.clear()
	_layers.clear()
	_open_memo.clear()


## Clouds alive (for the debug overlay).
func count() -> int:
	return _clouds.size()
