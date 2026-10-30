extends Node2D
## A light, never-ending snowstorm over the whole screen (the Frostgruft's theme "snowstorm"),
## drawn in screen space on its own canvas layer above the world, the HUD and the menus, so the
## cold is felt everywhere. Flakes fall in three depths (far: small, slow, faint; near: larger,
## faster), are carried by a wind that swells into gusts now and then, and sway a little. During a
## gust some flakes draw as short streaks. Square flakes on a pixel grid, so they suit both the
## pixel and the HD look. Presentation only; it keeps running while the game is paused.

## Look and motion (theme "snowstorm" keys of the same name override them):
## flakes = count, wind = base wind px/s [x, y], fall = fall speed px/s [far, near],
## size = flake size px [far, near], alpha = opacity [far, near], gust_every = s between gusts
## [min, max], gust = extra wind px/s at a gust's peak, gust_time = s a gust lasts, pixel = grid px.
const DEFAULTS := {"flakes": 240, "wind": [-70.0, 0.0], "fall": [55.0, 150.0], "size": [2.0, 4.0], "alpha": [0.35, 0.8],
	"gust_every": [5.0, 11.0], "gust": 260.0, "gust_time": 2.6, "pixel": 2.0}

var cfg: Dictionary = DEFAULTS.duplicate(true)
var _flakes: Array = []
var _t := 0.0
var _gust_at := 6.0
var _gust_t := -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7
	_spawn_all()


## Applies a theme "snowstorm" block over the defaults and refills the flakes.
func configure(theme_block: Dictionary) -> void:
	for k: String in theme_block:
		if DEFAULTS.has(k):
			cfg[k] = theme_block[k]
	_spawn_all()


func _screen() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)


func _spawn_all() -> void:
	_flakes = []
	var s := _screen()
	for i in range(int(cfg.flakes)):
		_flakes.append(_new_flake(Vector2(_rng.randf() * s.x, _rng.randf() * s.y)))


func _new_flake(at: Vector2) -> Dictionary:
	var depth := _rng.randf()
	return {"p": at, "d": depth, "sway": _rng.randf() * TAU, "rate": 0.6 + _rng.randf() * 1.2}


## The wind now: the base wind plus a gust that swells and fades (sine shaped).
func wind() -> Vector2:
	var w := Vector2(float(cfg.wind[0]), float(cfg.wind[1]))
	if _gust_t >= 0.0:
		w.x -= float(cfg.gust) * sin(PI * clampf(_gust_t / float(cfg.gust_time), 0.0, 1.0))
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
	var s := _screen()
	var w := wind()
	for f: Dictionary in _flakes:
		var d: float = f.d
		var fall := lerpf(float(cfg.fall[0]), float(cfg.fall[1]), d)
		var sway := sin(_t * float(f.rate) + float(f.sway)) * 18.0
		f.p += Vector2(w.x * (0.5 + d * 0.7) + sway, fall + w.y) * dt
		# off one edge: back in at the opposite one
		if f.p.y > s.y + 8.0:
			f.p = Vector2(_rng.randf() * s.x, -6.0)
		if f.p.x < -12.0:
			f.p.x += s.x + 20.0
		elif f.p.x > s.x + 12.0:
			f.p.x -= s.x + 20.0
	queue_redraw()


func _draw() -> void:
	var px := float(cfg.pixel)
	var w := wind()
	var streak := clampf((-w.x - absf(float(cfg.wind[0]))) / maxf(float(cfg.gust), 1.0), 0.0, 1.0)
	for f: Dictionary in _flakes:
		var d: float = f.d
		var size := maxf(px, snappedf(lerpf(float(cfg.size[0]), float(cfg.size[1]), d), px))
		var a := lerpf(float(cfg.alpha[0]), float(cfg.alpha[1]), d)
		var p := Vector2(snappedf(f.p.x, px), snappedf(f.p.y, px))
		var col := Color(0.93, 0.97, 1.0, a)
		draw_rect(Rect2(p, Vector2(size, size)), col)
		# in a gust the near flakes draw a short streak behind them
		if streak > 0.15 and d > 0.55:
			var len := streak * 26.0 * d
			draw_rect(Rect2(p + Vector2(size, 0), Vector2(snappedf(len, px), px)), Color(col, a * 0.45))
