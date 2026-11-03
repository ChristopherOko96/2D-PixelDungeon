extends RefCounted
## The drawing of gas on the floor (poison clouds, breath, fumes, smoke, steam,
## void and frost mist). The gas itself, its puffs and their physics and what
## a creature breathes, is the gameplay field src/physics_kit/gas_field.gd
## (GasField, BAUPLAN M1d: the truth); this painter owns one (`gas_field`) and
## draws it. Its old API stays: sync, emit, impulse, suck, ripple_near, part,
## cut, step, at, around, thickness, extent, clouds_of, end_cloud, covers,
## count and clear forward to the field, so the hosts keep working.
##
## Drawn on the art grid (`art` world px per art pixel) as one shape per
## material: overlapping puffs merge, density shows by the 4x4 ordered dither,
## a lit top and a dark underside; it is a see-through veil (review A6
## 2026-11-01): every pixel lets the floor show through by its thickness, even
## its thickest part keeps holes, and its grain churns and frays at the rim
## (two noises drifting apart). It lies under the actors (they always stay
## readable in it). Drawing only reads the field; the drawing's own clock
## (draw's `now`, the frames) never moves the gas.

const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const DATA_PATH := "res://assets/data/vfx_gas.json"

## World px per art pixel of the canvas it draws on.
var art := 2.0
## Callable(world point) -> bool: floor gas may be on (false inside walls).
var open: Callable
## vfx_gas.json (the field's, shared).
var cfg: Dictionary = {}
## The gas this draws: puffs, physics and the gameplay answers (src/physics_kit/gas_field.gd).
var gas_field: GasField
var _ramps: Dictionary = {}
var _drawn_frame := -1
## material -> {tex: ImageTexture, at: Vector2i first art cell, size: Vector2i}
var _layers: Dictionary = {}
## block of 8 x 8 art cells -> where gas may show in it (_open_block), and since when (ms).
var _open_memo: Dictionary = {}
var _open_since := 0
## The churn noise (_churn_table), made once.
static var _churn := PackedFloat32Array()


## A painter on a canvas of `art_px` world px per art pixel with its own gas
## field; `open_floor` (Callable(world point) -> bool) is where gas may lie.
func _init(art_px: float, open_floor: Callable) -> void:
	art = art_px
	open = open_floor
	gas_field = GasField.new(art_px, GasField.CallableHost.new(open_floor))
	cfg = gas_field.cfg
	for mat: String in cfg.get("materials", {}):
		var ramp := {}
		var spec: Dictionary = cfg.materials[mat].get("ramp", {})
		for role: String in spec:
			ramp[role] = Color(str(spec[role]))
		_ramps[mat] = ramp


## vfx_gas.json, cached (GasField.settings).
static func settings() -> Dictionary:
	return GasField.settings()


func _f(key: String, fallback: float) -> float:
	return float(cfg.get(key, fallback))


# ---------- the old gameplay API: forwarded to the field ----------

## GasField.sync: a source's gas zones at the host's time `now`.
func sync(zones: Array, now: float, source := "") -> void:
	gas_field.sync(zones, now, source)


## GasField.emit: a cloud that is not a zone (a breath, a burst of smoke).
func emit(key: String, mat: String, at: Vector2, r: float, length: float, now: float, push := Vector2.ZERO, dense := 1.0) -> void:
	gas_field.emit(key, mat, at, r, length, now, push, dense)


## GasField.impulse: a blast blows the gas away and thins it.
func impulse(at: Vector2, radius: float, strength: float) -> void:
	gas_field.impulse(at, radius, strength)


## GasField.suck: the void sucks the gas in; true while any puff was touched.
func suck(at: Vector2, radius: float, pull: float, thin: float, dt: float, now: float) -> bool:
	return gas_field.suck(at, radius, pull, thin, dt, now)


## GasField.ripple_near: the particles' blast hook (the gas is blown away; false).
func ripple_near(at: Vector2, radius: float, strength: float) -> bool:
	return gas_field.ripple_near(at, radius, strength)


## The particles ask the layers they touch whether a liquid lies somewhere:
## gas is none.
func wet_at(point: Vector2) -> bool:
	return gas_field.wet_at(point)


## GasField.part: someone standing at `at`, `radius` wide, parts the gas.
func part(at: Vector2, radius: float, dt: float = 1.0 / 60.0) -> void:
	gas_field.part(at, radius, dt)


## GasField.cut: a shot cuts a lane through the gas.
func cut(at: Vector2, dir: Vector2, width: float, dt: float = 1.0 / 60.0) -> void:
	gas_field.cut(at, dir, width, dt)


## GasField.at: the thickest material at `point` and its thickness.
func at(point: Vector2) -> Dictionary:
	return gas_field.at(point)


## GasField.around: what someone standing at `point` breathes.
func around(point: Vector2, radius: float, samples := 8) -> Dictionary:
	return gas_field.around(point, radius, samples)


## GasField.clouds_of: the clouds of `mat` alive at `now`.
func clouds_of(mat: String, now := -INF) -> Array:
	return gas_field.clouds_of(mat, now)


## GasField.end_cloud: cloud `key` thins out from now.
func end_cloud(key: String, now: float) -> void:
	gas_field.end_cloud(key, now)


## GasField.touching: the clouds of `mat` whose puffs reach `at`.
func touching(mat: String, at: Vector2, r: float, now := -INF) -> Array:
	return gas_field.touching(mat, at, r, now)


## GasField.touching_where: the clouds of `mat` with a puff where `here` holds.
func touching_where(mat: String, here: Callable, now := -INF) -> Array:
	return gas_field.touching_where(mat, here, now)


## GasField.ignite: a flame front runs through cloud `key` from `from`.
func ignite(key: String, from: Vector2, now: float, speed: float) -> void:
	gas_field.ignite(key, from, now, speed)


## GasField.take_burnt: the puffs that went up since the last call.
func take_burnt() -> Array:
	return gas_field.take_burnt()


## GasField.thickness: the thickness of `mat` alone at `point`.
func thickness(point: Vector2, mat: String) -> float:
	return gas_field.thickness(point, mat)


## GasField.extent: how far the gas of `mat` reaches round `point`.
func extent(point: Vector2, mat: String, thin: float, step: float, max_len: float) -> float:
	return gas_field.extent(point, mat, thin, step, max_len)


## GasField.step: the gas runs `dt` s on (the host's clock `now`).
func step(dt: float, now: float) -> void:
	gas_field.step(dt, now)


## GasField.covers: gas thick enough to see lies at `point`.
func covers(point: Vector2) -> bool:
	return gas_field.covers(point)


## Forgets every cloud and what the drawing remembered (a new room).
func clear() -> void:
	gas_field.clear()
	_layers.clear()
	_open_memo.clear()


## Clouds alive (for the debug overlay).
func count() -> int:
	return gas_field.count()


# ---------- drawing ----------

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
	var clouds := gas_field.clouds()
	if clouds.is_empty():
		_layers.clear()
		return
	var every := 1.0 / maxf(1.0, _f("draw_hz", 15.0))
	var alive := {}
	for key: String in clouds:
		alive[str(clouds[key].mat)] = true
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
	var clouds := gas_field.clouds()
	for key: String in clouds:
		var cloud: Dictionary = clouds[key]
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
	_build_layer(mat, list, now)
	_layers[mat].built = now


## One material's image at time `now`: the puffs' coverage added up
## (overlapping puffs make one cloud, thick where they crowd), frayed by two
## noises drifting apart (it churns: churn art cells/s, fray its strength,
## most at its thin rim), then per cell its colour by the dither and its
## neighbours above and below, seen through by its thickness (veil_alpha);
## even its thickest part keeps holes (max_cover).
func _build_layer(mat: String, list: PackedFloat32Array, now: float) -> void:
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
	var churn := _churn_table()
	var speed := _f("churn", 2.0)
	var fray := _f("fray", 0.9)
	var top := _f("max_cover", 0.72)
	var veil: Array = cfg.get("veil_alpha", [0.4, 0.78])
	var a_thin := float(veil[0]) * 255.0
	var a_thick := float(veil[1]) * 255.0
	# the two noises drift apart (whole art cells): the grain churns, it does not slide
	var ax := int(floor(now * speed))
	var ay := int(floor(now * speed * 0.4))
	var bx := -int(floor(now * speed * 0.7))
	var by := int(floor(now * speed * 0.8))
	# the ordered dither (MatterKit), its row picked once per row
	var bayer: Array = MatterKit.BAYER
	for y in range(1, h - 1):
		var qy := lo_y + y
		var bayer_row := (qy & 3) << 2
		var row_a := ((qy + ay) & 63) << 6
		var row_b := ((qy + by) & 63) << 6
		for x in range(w):
			var i := y * w + x
			var k := cover[i]
			if k < 0.03:
				continue
			var qx := lo_x + x
			var n := (churn[row_a | ((qx + ax) & 63)] + churn[row_b | ((qx + bx) & 63)]) * 0.5
			k += (n - 0.5) * fray * clampf(1.25 - k, 0.2, 1.0)
			# even its thickest part keeps holes: gas, not a solid
			if k < 0.06 or float(bayer[bayer_row | (qx & 3)]) >= minf(top, k * 1.1) * 16.0:
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
			# seen through: the thinner, the more of the floor and the figures shows
			bytes[b + 3] = int(lerpf(a_thin, a_thick, clampf(k, 0.0, 1.0)))
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


## A tiling 64 x 64 value noise 0..1 (two octaves over 8 and 4 art cells),
## made once: the churn of every cloud reads it (_build_layer).
static func _churn_table() -> PackedFloat32Array:
	if _churn.is_empty():
		_churn.resize(64 * 64)
		for y in range(64):
			for x in range(64):
				_churn[y * 64 + x] = MatterKit.tiling_noise(x, y, 8, 64) * 0.62 + MatterKit.tiling_noise(x, y, 4, 64) * 0.38
	return _churn


## Where gas may show in the block `b` of 8 x 8 art cells (`open` at each
## cell's middle; 1 open, 0 wall), remembered: asked once per cell, forgotten
## with the room (clear) and every open_memory_s s (a broken wall opens cells).
## The drawing's own memory: the gas's physics asks its field's host.
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
