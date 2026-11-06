extends RefCounted
## The weather of a Weltbauer room, drawn over the picture while the hero is in it: one thing falling
## (weather: snow, blizzard, hail) and any of the extras laid over it (weather_extra: fog, diamond
## dust, aurora, rime, night). The flakes live on the screen but move against the camera, so they
## seem to hang in the room. The Weltbauer draws a still view of the same (draw_preview).
## Values: assets/data/world_weather.json.

const DATA_PATH := "res://assets/data/world_weather.json"

var cfg: Dictionary = {}
var _fall := ""
var _extras: Array = []
var _shown := 0.0
var _flakes: Array = []
var _sparks: Array = []
var _banks: Array = []
var _camera := Vector2.INF
var _clock := 0.0
var _size := Vector2.ZERO


func _init(data: Dictionary = {}) -> void:
	cfg = data if not data.is_empty() else load_config()


static func load_config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


## What room `r` (a room file or a floor's room) asks for: {"fall": "", "extras": []}.
static func of_room(r: Dictionary) -> Dictionary:
	var extras: Array = []
	for x: Variant in r.get("weather_extra", []):
		extras.append(str(x))
	return {"fall": str(r.get("weather", "")), "extras": extras}


## True when `w` (of_room) shows anything.
static func any(w: Dictionary) -> bool:
	return str(w.get("fall", "")) != "" or not (w.get("extras", []) as Array).is_empty()


## Draws the weather of the hero's room into the HUD `h` of `size`; `g` is the game.
func draw(h: Control, size: Vector2, g: Node) -> void:
	var dt := minf(0.1, g.get_process_delta_time())
	_clock += dt
	var want := {"fall": "", "extras": []}
	var rooms: Array = g.W.get("rooms", [])
	var at := int(g.state.get("room", -1))
	if at >= 0 and at < rooms.size():
		want = of_room(rooms[at])
	var fade := maxf(0.05, float(cfg.get("fade", 0.8)))
	if str(want.fall) != _fall or str(want.extras) != str(_extras):
		_shown = maxf(0.0, _shown - dt / fade)
		if _shown <= 0.0:
			_fall = str(want.fall)
			_extras = want.extras
			_flakes = []
			_sparks = []
			_banks = []
	elif any(want):
		_shown = minf(1.0, _shown + dt / fade)
	if _shown <= 0.0 or (_fall == "" and _extras.is_empty()):
		return
	var cam: Vector2 = g.camera.position if g.get("camera") != null else Vector2.ZERO
	var zoom: float = (g.camera.zoom as Vector2).x if g.get("camera") != null else 1.0
	var shift := Vector2.ZERO if _camera == Vector2.INF else (cam - _camera) * zoom
	_camera = cam
	if size != _size:
		_size = size
		_flakes = []
		_sparks = []
		_banks = []
	paint(h, size, dt, shift, _shown)


## One frame of the weather on canvas `ci` over `size`: `shift` is how far the view moved (px).
func paint(ci: CanvasItem, size: Vector2, dt: float, shift: Vector2, alpha: float) -> void:
	var extras: Dictionary = cfg.get("extras", {})
	# the fog first, the night over it (a polar night stays dark, its fog too), then what shines in it
	if _extras.has("fog"):
		_fog(ci, size, dt, shift, extras.fog, alpha)
	if _extras.has("night"):
		var n: Dictionary = extras.night
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(str(n.get("color", "06101f")), float(n.get("alpha", 0.3)) * alpha))
	if _extras.has("aurora"):
		_aurora(ci, size, extras.aurora, alpha)
	if _fall != "" and (cfg.get("falls", {}) as Dictionary).has(_fall):
		_falling(ci, size, dt, shift, cfg.falls[_fall], alpha)
	if _extras.has("diamond"):
		_diamond(ci, size, dt, shift, extras.diamond, alpha)
	if _extras.has("rime"):
		_rime(ci, size, extras.rime, alpha)


func _falling(ci: CanvasItem, size: Vector2, dt: float, shift: Vector2, f: Dictionary, alpha: float) -> void:
	var count := int(float(f.get("count", 100)) * size.x / 1920.0)
	var speed: Array = f.get("speed", [40, 90])
	var sizes: Array = f.get("size", [1.5, 3.5])
	while _flakes.size() < count:
		_flakes.append({"p": Vector2(randf() * size.x, randf() * size.y), "v": randf_range(float(speed[0]), float(speed[1])), "r": randf_range(float(sizes[0]), float(sizes[1])), "w": randf() * TAU})
	var gust := float(f.get("gust", 0.0))
	var blow := 1.0 + (0.6 * sin(_clock * TAU / gust) if gust > 0.0 else 0.0)
	var drift := float(f.get("drift", 20.0)) * blow
	var haze := float(f.get("haze", 0.0))
	if haze > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.96, 1.0, haze * (0.55 + 0.45 * blow / 1.6) * alpha))
	var streak := float(f.get("streak", 0.0))
	var col := Color(1, 1, 1, float(f.get("alpha", 0.8)) * alpha)
	for fl: Dictionary in _flakes:
		var v := Vector2(drift + sin(_clock * 1.3 + float(fl.w)) * 14.0, float(fl.v))
		fl.p = (fl.p as Vector2) + v * dt - shift
		var p: Vector2 = fl.p
		if p.y > size.y + 30.0: p.y -= size.y + 60.0
		if p.y < -30.0: p.y += size.y + 60.0
		if p.x > size.x + 30.0: p.x -= size.x + 60.0
		if p.x < -30.0: p.x += size.x + 60.0
		fl.p = p
		if streak > 0.0:
			ci.draw_line(p, p - v.normalized() * streak, col, float(fl.r))
		else:
			ci.draw_circle(p, float(fl.r), col)


func _fog(ci: CanvasItem, size: Vector2, dt: float, shift: Vector2, f: Dictionary, alpha: float) -> void:
	var sizes: Array = f.get("size", [260, 520])
	while _banks.size() < int(f.get("count", 8)):
		_banks.append({"p": Vector2(randf() * size.x, randf() * size.y), "r": randf_range(float(sizes[0]), float(sizes[1])), "s": randf_range(0.6, 1.3)})
	var col := Color(str(f.get("color", "b8d4f2")))
	for b: Dictionary in _banks:
		b.p = (b.p as Vector2) + Vector2(float(f.get("speed", 20.0)) * float(b.s), 0.0) * dt - shift
		var p: Vector2 = b.p
		var r := float(b.r)
		if p.x - r > size.x: p.x = -r
		if p.x + r < 0.0: p.x = size.x + r
		if p.y - r > size.y: p.y = -r
		if p.y + r < 0.0: p.y = size.y + r
		b.p = p
		for k in range(4):
			ci.draw_circle(p + Vector2(cos(k * 1.7), sin(k * 2.3)) * r * 0.3, r * (1.0 - k * 0.18), Color(col, float(f.get("alpha", 0.1)) * alpha * 0.5))


func _diamond(ci: CanvasItem, size: Vector2, dt: float, shift: Vector2, f: Dictionary, alpha: float) -> void:
	while _sparks.size() < int(float(f.get("count", 60)) * size.x / 1920.0):
		_sparks.append({"p": Vector2(randf() * size.x, randf() * size.y), "t": randf() * TAU, "s": randf_range(1.5, 3.5)})
	var col := Color(str(f.get("color", "e6fbff")))
	for s: Dictionary in _sparks:
		s.t = float(s.t) + dt * 2.2
		s.p = (s.p as Vector2) + Vector2(4.0, 10.0) * dt - shift
		var p: Vector2 = s.p
		p.x = fposmod(p.x, size.x)
		p.y = fposmod(p.y, size.y)
		s.p = p
		var on := maxf(0.0, sin(float(s.t)))
		if on <= 0.05:
			continue
		var r := float(s.s) * (1.0 + on * 2.0)
		var c := Color(col, float(f.get("alpha", 0.9)) * on * alpha)
		ci.draw_line(p - Vector2(r * 2.0, 0), p + Vector2(r * 2.0, 0), c, 1.5)
		ci.draw_line(p - Vector2(0, r * 2.0), p + Vector2(0, r * 2.0), c, 1.5)
		ci.draw_circle(p, r * 0.5, c)


func _aurora(ci: CanvasItem, size: Vector2, f: Dictionary, alpha: float) -> void:
	var colours: Array = f.get("colors", ["5dffb0"])
	var height := size.y * float(f.get("height", 0.3))
	for k in range(int(f.get("bands", 3))):
		var col := Color(str(colours[k % colours.size()]))
		var top := PackedVector2Array()
		var steps := 32
		for i in range(steps + 1):
			var x := size.x * i / steps
			top.append(Vector2(x, height * (0.25 + 0.18 * k) + sin(x * 0.004 + _clock * (0.35 + k * 0.12) + k * 2.0) * height * 0.18))
		for i in range(steps):
			var a := top[i]
			var b := top[i + 1]
			var glow := 0.6 + 0.4 * sin(_clock * 0.8 + i * 0.4 + k)
			var poly := PackedVector2Array([a, b, b + Vector2(0, height * 0.45), a + Vector2(0, height * 0.45)])
			var cols := PackedColorArray([Color(col, float(f.get("alpha", 0.2)) * glow * alpha), Color(col, float(f.get("alpha", 0.2)) * glow * alpha), Color(col, 0.0), Color(col, 0.0)])
			ci.draw_polygon(poly, cols)


func _rime(ci: CanvasItem, size: Vector2, f: Dictionary, alpha: float) -> void:
	var w := size.x * float(f.get("width", 0.08))
	var col := Color(str(f.get("color", "e9f6ff")))
	var a := float(f.get("alpha", 0.5)) * alpha
	var clear := Color(col, 0.0)
	var edge := Color(col, a)
	for side in range(4):
		var poly := PackedVector2Array()
		match side:
			0: poly = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x - w, w), Vector2(w, w)])
			1: poly = PackedVector2Array([Vector2(0, size.y), Vector2(w, size.y - w), Vector2(size.x - w, size.y - w), Vector2(size.x, size.y)])
			2: poly = PackedVector2Array([Vector2.ZERO, Vector2(w, w), Vector2(w, size.y - w), Vector2(0, size.y)])
			3: poly = PackedVector2Array([Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x - w, size.y - w), Vector2(size.x - w, w)])
		ci.draw_polygon(poly, PackedColorArray([edge, edge, clear, clear]) if side == 0 or side == 3 else PackedColorArray([edge, clear, clear, edge]))
	# frost ferns grow from the corners
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		var inward := (size * 0.5 - corner).normalized()
		for k in range(6):
			var dir := inward.rotated((k - 2.5) * 0.28)
			var from := corner
			var length := w * (0.9 + 0.25 * sin(k * 2.1))
			ci.draw_line(from, from + dir * length, Color(col, a * 0.8), 2.0)
			for j in range(1, 4):
				var p := from + dir * length * j / 4.0
				ci.draw_line(p, p + dir.rotated(0.7) * length * 0.18, Color(col, a * 0.6), 1.5)
				ci.draw_line(p, p + dir.rotated(-0.7) * length * 0.18, Color(col, a * 0.6), 1.5)


## A view of the weather over `rect` in the Weltbauer (room px, canvas `ci`), for `room` (a room file).
func draw_preview(ci: CanvasItem, rect: Rect2, room: Dictionary, dt: float) -> void:
	var w := of_room(room)
	if not any(w):
		return
	_clock += dt
	if str(w.fall) != _fall or str(w.extras) != str(_extras) or rect.size != _size:
		_fall = str(w.fall)
		_extras = w.extras
		_size = rect.size
		_flakes = []
		_sparks = []
		_banks = []
	# drawn as on a 1920 wide screen laid over the room
	var k := rect.size.x / 1920.0
	ci.draw_set_transform(rect.position, 0.0, Vector2(k, k))
	paint(ci, rect.size / k, dt, Vector2.ZERO, 1.0)
	ci.draw_set_transform(Vector2.ZERO)
