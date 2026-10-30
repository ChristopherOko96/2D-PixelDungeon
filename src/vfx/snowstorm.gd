extends Node2D
## A light, never-ending snowfall over the whole screen (the Frostgruft's theme "snowstorm"),
## drawn in screen space on its own canvas layer above the world, the HUD and the menus, so the
## cold is felt everywhere. Flakes fall in three depths (far: small, slow, faint; near: larger,
## faster), are carried by a steady light wind from the right that swells into gusts now and then,
## and sway a little. Faint wind lines sweep across the screen from right to left all the time, so
## the wind can be seen; during a gust some flakes draw as short streaks.
## Now and then, at random, a snowstorm rises: over a few seconds the snow thickens (extra flakes),
## the wind grows strong, more and longer wind lines race across, the flakes streak and a pale
## haze of blown snow veils the screen; then it dies down again.
## Square flakes on a pixel grid, so they suit both the pixel and the HD look. Presentation only;
## it keeps running while the game is paused.

## Look and motion (theme "snowstorm" keys of the same name override them):
## flakes = count, wind = base wind px/s [x, y], fall = fall speed px/s [far, near],
## size = flake size px [far, near], alpha = opacity [far, near], gust_every = s between gusts
## [min, max], gust = extra wind px/s at a gust's peak, gust_time = s a gust lasts, pixel = grid px;
## lines = wind lines on screen in calm weather, line_alpha = their opacity [min, max],
## line_length = their length px [min, max], line_speed = their speed as a multiple of the wind;
## storm_every = s between snowstorms [min, max], storm_time = s a storm lasts [min, max],
## storm_ramp = s it takes to rise and to die down, storm_flakes = extra flakes at its height,
## storm_wind = extra wind px/s (leftwards) at its height, storm_lines = extra wind lines,
## storm_haze = opacity of the blown-snow haze at its height.
const DEFAULTS := {"flakes": 240, "wind": [-70.0, 0.0], "fall": [55.0, 150.0], "size": [2.0, 4.0], "alpha": [0.35, 0.8],
	"gust_every": [5.0, 11.0], "gust": 260.0, "gust_time": 2.6, "pixel": 2.0,
	"lines": 7, "line_alpha": [0.05, 0.13], "line_length": [60.0, 170.0], "line_speed": 2.6,
	"storm_every": [70.0, 150.0], "storm_time": [16.0, 28.0], "storm_ramp": 5.0, "storm_flakes": 520,
	"storm_wind": 330.0, "storm_lines": 26, "storm_haze": 0.16}

var cfg: Dictionary = DEFAULTS.duplicate(true)
var _flakes: Array = []
var _lines: Array = []
var _t := 0.0
var _gust_at := 6.0
var _gust_t := -1.0
## The next snowstorm starts at _storm_at (s of _t); while one blows, _storm_t counts its seconds
## (-1 between storms) and _storm_len is how long it lasts.
var _storm_at := 0.0
var _storm_t := -1.0
var _storm_len := 20.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_spawn_all()


## Applies a theme "snowstorm" block over the defaults and refills the flakes.
func configure(theme_block: Dictionary) -> void:
	for k: String in theme_block:
		if DEFAULTS.has(k):
			cfg[k] = theme_block[k]
	_storm_at = _t + _rng.randf_range(float(cfg.storm_every[0]), float(cfg.storm_every[1]))
	_storm_t = -1.0
	_spawn_all()


func _screen() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)


func _spawn_all() -> void:
	_flakes = []
	_lines = []
	var s := _screen()
	# the calm flakes first, the storm's extra flakes after them (drawn by the storm's strength)
	for i in range(int(cfg.flakes) + int(cfg.storm_flakes)):
		_flakes.append(_new_flake(Vector2(_rng.randf() * s.x, _rng.randf() * s.y)))
	for i in range(int(cfg.lines) + int(cfg.storm_lines)):
		_lines.append(_new_line(_rng.randf() * (s.x + 400.0)))


func _new_flake(at: Vector2) -> Dictionary:
	var depth := _rng.randf()
	return {"p": at, "d": depth, "sway": _rng.randf() * TAU, "rate": 0.6 + _rng.randf() * 1.2}


## A wind line starting at screen x `x`, at a random height, length, depth and wave.
func _new_line(x: float) -> Dictionary:
	var s := _screen()
	return {"p": Vector2(x, _rng.randf() * s.y), "len": _rng.randf_range(float(cfg.line_length[0]), float(cfg.line_length[1])),
		"d": _rng.randf(), "wave": _rng.randf() * TAU, "a": _rng.randf_range(float(cfg.line_alpha[0]), float(cfg.line_alpha[1]))}


## Starts a snowstorm now (debug views and captures); it rises over storm_ramp s.
func start_storm(length := -1.0) -> void:
	_storm_t = 0.0
	_storm_len = length if length > 0.0 else _rng.randf_range(float(cfg.storm_time[0]), float(cfg.storm_time[1]))


## The snowstorm's strength now: 0 calm, 1 at its height (eased in and out over storm_ramp s).
func storm() -> float:
	if _storm_t < 0.0:
		return 0.0
	var ramp := maxf(0.01, float(cfg.storm_ramp))
	var k := minf(_storm_t / ramp, (_storm_len - _storm_t) / ramp)
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## The wind now: the base wind, a gust that swells and fades (sine shaped) and the storm's wind.
func wind() -> Vector2:
	var w := Vector2(float(cfg.wind[0]), float(cfg.wind[1]))
	if _gust_t >= 0.0:
		w.x -= float(cfg.gust) * sin(PI * clampf(_gust_t / float(cfg.gust_time), 0.0, 1.0))
	w.x -= float(cfg.storm_wind) * storm()
	return w


func _process(dt: float) -> void:
	_t += dt
	if _gust_t >= 0.0:
		_gust_t += dt
		if _gust_t > float(cfg.gust_time):
			_gust_t = -1.0
			_gust_at = _t + _rng.randf_range(float(cfg.gust_every[0]), float(cfg.gust_every[1]))
	elif _t >= _gust_at:
		_gust_t = 0.0
	if _storm_t >= 0.0:
		_storm_t += dt
		if _storm_t > _storm_len:
			_storm_t = -1.0
			_storm_at = _t + _rng.randf_range(float(cfg.storm_every[0]), float(cfg.storm_every[1]))
	elif _t >= _storm_at:
		start_storm()
	var s := _screen()
	var w := wind()
	var st := storm()
	for f: Dictionary in _flakes:
		var d: float = f.d
		var fall := lerpf(float(cfg.fall[0]), float(cfg.fall[1]), d) * (1.0 - st * 0.35)
		var sway := sin(_t * float(f.rate) + float(f.sway)) * 18.0 * (1.0 - st * 0.6)
		f.p += Vector2(w.x * (0.5 + d * 0.7) + sway, fall + w.y) * dt
		# off one edge: back in at the opposite one
		if f.p.y > s.y + 8.0:
			f.p = Vector2(_rng.randf() * s.x, -6.0)
		if f.p.x < -12.0:
			f.p.x += s.x + 20.0
		elif f.p.x > s.x + 12.0:
			f.p.x -= s.x + 20.0
	for l: Dictionary in _lines:
		var d: float = l.d
		l.p.x += w.x * float(cfg.line_speed) * (0.6 + d * 0.6) * dt
		l.p.y += (sin(_t * 0.8 + float(l.wave)) * 6.0 + 4.0) * dt
		# out at the left: a new line comes in from the right
		if l.p.x + float(l.len) < -10.0:
			var fresh := _new_line(s.x + _rng.randf() * 300.0)
			l.merge(fresh, true)
	queue_redraw()


func _draw() -> void:
	var px := float(cfg.pixel)
	var w := wind()
	var st := storm()
	var s := _screen()
	# the blown-snow haze of a storm, under the flakes
	if st > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.86, 0.92, 1.0, float(cfg.storm_haze) * st))
	var streak := clampf((-w.x - absf(float(cfg.wind[0]))) / maxf(float(cfg.gust), 1.0), 0.0, 1.0)
	# the wind lines: thin, tapering, faint; the storm's extra lines join as it grows
	var n_lines := int(cfg.lines) + int(round(float(cfg.storm_lines) * st))
	for i in range(mini(n_lines, _lines.size())):
		var l: Dictionary = _lines[i]
		var length: float = float(l.len) * (1.0 + st * 0.8)
		var a: float = float(l.a) * (1.0 + st * 1.4)
		var p := Vector2(snappedf(l.p.x, px), snappedf(l.p.y, px))
		# three segments, the head brightest (the line moves left); a cold blue edge under the
		# white, so the line also reads over the white snow
		for k in range(3):
			var seg := length / 3.0
			var fade := 1.0 - k * 0.3
			draw_rect(Rect2(p + Vector2(seg * k, px), Vector2(snappedf(seg, px), px)), Color(0.42, 0.56, 0.8, a * 0.8 * fade))
			draw_rect(Rect2(p + Vector2(seg * k, 0), Vector2(snappedf(seg, px), px)), Color(0.9, 0.95, 1.0, a * fade))
	var n_flakes := int(cfg.flakes) + int(round(float(cfg.storm_flakes) * st))
	for i in range(mini(n_flakes, _flakes.size())):
		var f: Dictionary = _flakes[i]
		var d: float = f.d
		var size := maxf(px, snappedf(lerpf(float(cfg.size[0]), float(cfg.size[1]), d), px))
		var a := lerpf(float(cfg.alpha[0]), float(cfg.alpha[1]), d)
		var p := Vector2(snappedf(f.p.x, px), snappedf(f.p.y, px))
		var col := Color(0.93, 0.97, 1.0, a)
		draw_rect(Rect2(p, Vector2(size, size)), col)
		# in a gust or a storm the near flakes draw a short streak behind them
		if streak > 0.15 and d > 0.55:
			var len := streak * 26.0 * d
			draw_rect(Rect2(p + Vector2(size, 0), Vector2(snappedf(len, px), px)), Color(col, a * 0.45))
