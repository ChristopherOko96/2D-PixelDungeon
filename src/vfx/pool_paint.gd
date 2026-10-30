extends RefCounted
## Pools of liquid on the floor as opaque pixel materials (poison, void, ice,
## fire, lava, blood: assets/data/vfx_pools.json), shaped by the physics of the
## splat (src/vfx/splat_shape.gd: they run out along their flight and pile up
## against walls and props). All pools of one material are one field of art
## cells, shaded once into a texture (an outline, a lit north rim, a dark south
## lip, the body with its own pattern) whenever cells come or go, so overlapping
## pools never stack; living materials (fire, lava) are shaded again a few
## times a second. Each pool runs out from where it landed over spread_time and
## goes again rim first. Bubbles, flames and sparkles are drawn over it each
## frame. Pure drawing: the host hands it its zones and draws it on the floor,
## over the stains and under the props, actors and shadows.

const SplatShape = preload("res://src/vfx/splat_shape.gd")
const DATA_PATH := "res://assets/data/vfx_pools.json"
const FPS := 12.0

## World px per art pixel of the canvas it draws on.
var art := 2.0
## Callable(world point) -> bool: floor a pool may cover.
var open: Callable
var cfg: Dictionary = {}
## id -> {mat, cells: Array[Vector2i]}
var _pools: Dictionary = {}
## material -> field {cells: {Vector2i: [born, until, rank 0..1]}, img, tex, box, col, list, rim, next, dirty, baked}
var _fields: Dictionary = {}
var _ramps: Dictionary = {}
var _now := 0.0
static var _data: Dictionary = {}


func _init(art_px: float, open_floor: Callable) -> void:
	art = art_px
	open = open_floor
	cfg = settings()
	for mat: String in cfg.get("materials", {}):
		var ramp := {}
		var spec: Dictionary = cfg.materials[mat].get("ramp", {})
		for role: String in spec:
			ramp[role] = Color(str(spec[role]))
		_ramps[mat] = ramp


## vfx_pools.json, cached.
static func settings() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {"materials": {}}
	return _data


## The material a zone style is drawn in ("" when it has none).
func material_for(style: String) -> String:
	if cfg.get("materials", {}).has(style):
		return style
	return {"flesh": "blood", "curse": "void"}.get(style, "")


## True when `style` is drawn as a pool here.
func handles(style: String) -> bool:
	return material_for(style) != ""


## The cells a splat of `style` covers (rank 0..n-1), the same on server and clients.
static func shape(at: Vector2, dir: Vector2, radius: float, style: String, art_px: float, open_floor: Callable, seed: int) -> Dictionary:
	var c := settings()
	var squash := float(c.get("squash", 0.75))
	var mat: Dictionary = c.get("materials", {}).get(style, {})
	var drops := int(mat.get("droplets", 0)) if dir.length() > 0.01 else 0
	return SplatShape.flood(at, dir, SplatShape.cells_for(radius, art_px, squash), art_px, open_floor, seed, squash, float(c.get("momentum", 0.55)), drops)


## A pool `id` of `style` landing at `at` along `dir` (radius as its volume),
## from `start` until `end` (seconds on the host's clock). Known ids are kept.
func add(id: int, style: String, at: Vector2, dir: Vector2, radius: float, start: float, end: float) -> void:
	if _pools.has(id):
		return
	var mat := material_for(style)
	if mat == "":
		return
	var cells := shape(at, dir, radius, mat, art, open, id)
	if cells.is_empty():
		return
	var field: Dictionary = _field(mat)
	var n := float(maxi(1, cells.size()))
	var spread := float(cfg.get("spread_time", 0.35))
	var edge := minf(float(cfg.get("edge_time", 0.7)), maxf(0.1, (end - start) * 0.4))
	var list: Array[Vector2i] = []
	for q: Vector2i in cells:
		var k := float(cells[q]) / n
		var born := start + spread * pow(k, 0.7)
		var until := end - edge * k
		var have: Array = field.cells.get(q, [])
		if have.is_empty():
			field.cells[q] = [born, until, k]
		else:
			field.cells[q] = [minf(float(have[0]), born), maxf(float(have[1]), until), minf(float(have[2]), k)]
		list.append(q)
	_pools[id] = {"mat": mat, "cells": list, "end": end}
	field.next = minf(float(field.next), start)
	field.dirty = true


## A pool that ended early (its zone was removed): it goes rim first from now.
func finish(id: int, now: float) -> void:
	var pool: Dictionary = _pools.get(id, {})
	if pool.is_empty() or float(pool.end) <= now:
		return
	var field: Dictionary = _field(str(pool.mat))
	var edge := float(cfg.get("edge_time", 0.7)) * 0.5
	for q: Vector2i in pool.cells:
		var have: Array = field.cells.get(q, [])
		if not have.is_empty():
			have[1] = minf(float(have[1]), now + edge * (1.0 - float(have[2])))
	pool.end = now
	field.next = now
	field.dirty = true


## Takes in a host's zones ({id, k "pool", st style, x, y, r, dx, dy, p 0..1,
## L its length in s}) and lets pools that left the list go.
func sync(zones: Array, now: float) -> void:
	var seen := {}
	for zone: Dictionary in zones:
		if str(zone.get("k", "")) != "pool" or not handles(str(zone.get("st", ""))):
			continue
		var id := int(zone.get("id", -1))
		seen[id] = true
		if not _pools.has(id):
			var length := float(zone.get("L", 4.0))
			var start := now - float(zone.get("p", 0.0)) * length
			add(id, str(zone.st), Vector2(float(zone.x), float(zone.y)), Vector2(float(zone.get("dx", 0.0)), float(zone.get("dy", 0.0))), float(zone.r), start, start + length)
	for id: int in _pools.keys():
		if not seen.has(id):
			finish(id, now)
			if float(_pools[id].end) + float(cfg.get("edge_time", 0.7)) < now:
				_pools.erase(id)


func clear() -> void:
	_pools.clear()
	_fields.clear()


## True when `point` (world px) lies in a pool of `style` (any when "").
func covers(point: Vector2, style := "") -> bool:
	var q := Vector2i((point / art).floor())
	for mat: String in _fields:
		if style != "" and mat != material_for(style):
			continue
		var have: Array = _fields[mat].cells.get(q, [])
		if not have.is_empty() and float(have[0]) <= _now and _now < float(have[1]):
			return true
	return false


func _field(mat: String) -> Dictionary:
	if not _fields.has(mat):
		_fields[mat] = {"cells": {}, "img": null, "tex": null, "box": Rect2i(), "col": {}, "list": [], "rim": [], "next": 0.0, "dirty": true, "baked": -100.0, "frame": -1}
	return _fields[mat]


# ---------- drawing ----------

## Shades what changed and draws every field with its living overlay, in world px.
func draw(canvas: CanvasItem, now: float) -> void:
	_now = now
	var rate := 1.0 / float(cfg.get("rebake_hz", 15))
	var anim := float(cfg.get("anim_hz", 6))
	for mat: String in _fields:
		var field: Dictionary = _fields[mat]
		var style := str(cfg.materials[mat].get("style", "liquid"))
		var frame := int(floor(now * anim)) if style in ["fire", "lava"] else 0
		var due: bool = now >= float(field.next) or bool(field.dirty) or frame != int(field.frame)
		if due and now - float(field.baked) >= rate:
			_bake(field, mat, style, now, frame)
		if field.tex != null:
			var box: Rect2i = field.box
			canvas.draw_texture_rect(field.tex, Rect2(Vector2(box.position) * art, Vector2(box.size) * art), false)
			_overlay(canvas, field, mat, style, now)
	# fields that are empty for good go
	for mat: String in _fields.keys():
		if (_fields[mat].cells as Dictionary).is_empty():
			_fields.erase(mat)


func _bake(field: Dictionary, mat: String, style: String, now: float, frame: int) -> void:
	field.dirty = false
	field.baked = now
	field.frame = frame
	var cells: Dictionary = field.cells
	var live := {}
	var next := INF
	var gone: Array = []
	for q: Vector2i in cells:
		var c: Array = cells[q]
		if now >= float(c[1]):
			gone.append(q)
			continue
		if now >= float(c[0]):
			live[q] = float(c[2])
			next = minf(next, float(c[1]))
		else:
			next = minf(next, float(c[0]))
	for q: Vector2i in gone:
		cells.erase(q)
	field.next = next
	field.col = {}
	field.list = []
	field.rim = []
	if live.is_empty():
		field.tex = null
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for q: Vector2i in live:
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	var box := Rect2i(lo - Vector2i(1, 1), hi - lo + Vector2i(3, 5))
	var R: Dictionary = _ramps[mat]
	var img: Image = field.img
	if img == null or img.get_size() != box.size:
		img = Image.create_empty(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	else:
		img.fill(Color(0, 0, 0, 0))
	# the outline round it and the dark lip under its south edge
	for q: Vector2i in live:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			if not live.has(q + d) and not live.has(q + d + Vector2i(0, 1)):
				img.set_pixelv(q + d - box.position, R.outline)
	for q: Vector2i in live:
		if not live.has(q + Vector2i(0, 1)):
			img.set_pixelv(q + Vector2i(0, 1) - box.position, R.deep)
			if not live.has(q + Vector2i(0, 2)):
				img.set_pixelv(q + Vector2i(0, 2) - box.position, R.outline)
	for q: Vector2i in live:
		var col := _shade(q, live, R, style, now, frame)
		img.set_pixelv(q - box.position, col)
		field.col[q] = col
		field.list.append(q)
		if not live.has(q + Vector2i(0, -1)) and not live.has(q + Vector2i(1, 0)):
			field.rim.append(q)
	field.img = img
	if field.tex == null or (field.tex as ImageTexture).get_size() != Vector2(box.size):
		field.tex = ImageTexture.create_from_image(img)
	else:
		(field.tex as ImageTexture).update(img)
	field.box = box


## One cell's colour: the north rim lit, the row under it lighter, the south
## row deep, and inside the material's own pattern.
func _shade(q: Vector2i, live: Dictionary, R: Dictionary, style: String, now: float, frame: int) -> Color:
	var up := live.has(q + Vector2i(0, -1))
	var up2 := live.has(q + Vector2i(0, -2))
	var dn := live.has(q + Vector2i(0, 1))
	var inner := up and dn and live.has(q + Vector2i(1, 0)) and live.has(q + Vector2i(-1, 0))
	match style:
		"void":
			# dark in its heart, a bright rim of light where it meets the floor
			if not inner:
				return R.hi if not up else R.lite
			if not (up2 and live.has(q + Vector2i(0, 2)) and live.has(q + Vector2i(2, 0)) and live.has(q + Vector2i(-2, 0))):
				return R.lite if not up2 else R.body
			# slow thin wisps of light in the dark (long bands, not spots)
			var swirl := sin(float(q.x) * 0.22 + float(q.y) * 0.5) + 0.6 * sin(float(q.x) * 0.09 - float(q.y) * 0.21 + 1.3)
			return R.body if swirl > 1.25 else R.deep if swirl < -1.35 else R.shade
		"ice":
			if not up:
				return R.hi
			if not up2:
				return R.lite
			if not dn:
				return R.shade
			var diag := posmod(q.x + q.y, 26)
			if diag < 2 or diag == 4:
				return R.lite
			return R.body
		"fire":
			# burning ground: charred, embers glowing and shifting between frames
			if not up:
				return R.lite
			if not dn:
				return R.deep
			var heat := _noise(q.x + frame * 2, q.y - frame, 3, 9)
			if heat > 0.72:
				return R.hi
			if heat > 0.55:
				return R.lite
			if heat > 0.35:
				return R.body
			return R.shade
		"lava":
			# crust plates drifting slowly over molten rock
			if not inner:
				return R.shade if up else R.body
			var plate := _noise(q.x + frame / 3, q.y, 7, 3)
			if plate > 0.62:
				return R.deep if plate > 0.76 else R.shade
			var heat := clampf((1.0 - plate / 0.62) * 0.8 + 0.25 * sin(float(q.x) * 0.35 - float(q.y) * 0.2 + float(frame) * 0.6), 0.0, 1.0)
			if heat > 0.85 and _h(q.x, q.y, frame % 4) % 9 == 0:
				return R.spec
			return R.hi if heat > 0.62 else R.lite if heat > 0.3 else R.body
		_:
			# a liquid: one calm body, a lit north rim, a deeper band before the
			# south lip, and short level glints of light lying on its surface
			if not up:
				return R.hi
			if not up2:
				return R.lite
			if not dn:
				return R.shade
			if not live.has(q + Vector2i(0, 2)):
				return R.shade if posmod(q.x, 3) != 0 else R.body
			var gx := floori(float(q.x) / 7.0)
			var gy := floori(float(q.y) / 5.0)
			var h := _h(gx, gy, 17)
			if h % 3 == 0:
				var sx := gx * 7 + h % 4
				var sy := gy * 5 + (h / 7) % 3
				var len := 2 + h % 3
				if q.y == sy and q.x >= sx and q.x < sx + len:
					return R.spec if q.x == sx and h % 2 == 0 else R.lite
			return R.body


## Each frame over a field: bubbles that swell and pop (liquid, void, lava),
## flames licking up (fire), a gloss streak and a sparkle (liquid, ice, void).
func _overlay(canvas: CanvasItem, field: Dictionary, mat: String, style: String, now: float) -> void:
	var list: Array = field.list
	if list.is_empty():
		return
	var R: Dictionary = _ramps[mat]
	var spec: Dictionary = cfg.materials[mat]
	var n := int(spec.get("bubbles", 0))
	var tq := floorf(now * FPS)
	if style == "fire":
		for i in range(n * 2):
			var slot := int(floor(now * 3.0 + float(i) * 0.41))
			var q: Vector2i = list[posmod(slot * 7919 + i * 104729, list.size())]
			var tall := 2 + posmod(int(tq) + i * 3, 4)
			for j in range(tall):
				var col: Color = R.spec if j == 0 else R.hi if j < tall - 1 else R.lite
				_cell(canvas, q + Vector2i(posmod(j + int(tq) + i, 3) - 1 if j > 1 else 0, -j), col)
		return
	for i in range(n):
		var phase := fmod(now * 0.8 + float(i) * 0.33, 1.0)
		var slot := int(floor(now * 0.8 + float(i) * 0.33))
		var q: Vector2i = list[posmod(slot * 7919 + i * 104729, list.size())]
		if not (field.col.has(q + Vector2i(0, 2)) and field.col.has(q + Vector2i(0, -2)) and field.col.has(q + Vector2i(2, 0)) and field.col.has(q + Vector2i(-2, 0))):
			continue
		if phase < 0.5:
			_cell(canvas, q, R.hi)
			_cell(canvas, q + Vector2i(1, 0), R.lite)
		elif phase < 0.7:
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(2, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 1), Vector2i(1, 1)]:
				_cell(canvas, q + d, R.hi)
			_cell(canvas, q, R.shade)
			_cell(canvas, q + Vector2i(1, 0), R.shade)
		elif phase < 0.8:
			_cell(canvas, q + Vector2i(-1, -1), R.spec)
			_cell(canvas, q + Vector2i(2, -1), R.spec)
	# a sparkle pops on the north-east rim now and then
	var rim: Array = field.rim
	if not rim.is_empty() and style in ["liquid", "ice", "void"]:
		var f := posmod(int(tq), 30)
		if f < 3:
			var q: Vector2i = rim[posmod(int(floor(now / 2.5)) * 31, rim.size())]
			_cell(canvas, q, R.spec)
			if f == 0:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					_cell(canvas, q + d, R.spec)
			elif f == 1:
				for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					_cell(canvas, q + d, R.hi)


func _cell(canvas: CanvasItem, q: Vector2i, col: Color) -> void:
	canvas.draw_rect(Rect2(Vector2(q) * art, Vector2(art, art)), col)


static func _h(x: int, y: int, s := 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) % 1000


## Smooth value noise 0..1 over cells of `size` art px.
static func _noise(x: int, y: int, size: int, s: int) -> float:
	var fx := float(x) / float(size)
	var fy := float(y) / float(size)
	var gx := floori(fx)
	var gy := floori(fy)
	var u := fx - float(gx)
	var v := fy - float(gy)
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var a := float(_h(gx, gy, s)) / 1000.0
	var b := float(_h(gx + 1, gy, s)) / 1000.0
	var c := float(_h(gx, gy + 1, s)) / 1000.0
	var e := float(_h(gx + 1, gy + 1, s)) / 1000.0
	return lerpf(lerpf(a, b, u), lerpf(c, e, u), v)
