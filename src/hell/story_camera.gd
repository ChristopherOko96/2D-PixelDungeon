extends RefCounted
## The story camera (Krypta, Frostgruft, Hölle; hell_game.gd `_update_camera`).
## It follows the hero with a light lead in his run and aim direction, leans a
## little toward the fight he is in, breathes its zoom (wider for crowds and
## bosses, a touch closer at rest), punches in on ultimates and kicks along big
## impacts. The skill bar covers the bottom of the screen ("hud_bottom", a share
## of the view height): the view sits that much lower (view_shift), so the hero
## and his fight stay in the free part above it and a room's bottom wall stops
## right above the bar. Pure logic: feed one frame to step(), then read position,
## zoom, offset and view_shift. Values: assets/data/story_camera.json. The option "Kamerabewegung
## reduzieren" (calm) keeps only the follow, the room bounds and a softer shake;
## "Bildschirmwackeln" off (shake_on false) drops shake and kicks.

const DATA_PATH := "res://assets/data/story_camera.json"
const GraphicsSettings = preload("res://src/core/graphics_settings.gd")
## The one options file of the game (src/core/graphics_settings.gd SETTINGS_PATH).
const SETTINGS_PATH: String = GraphicsSettings.SETTINGS_PATH

## Tuning values (the json); tests may pass their own.
var cfg: Dictionary = {}
## "Kamerabewegung reduzieren": no lead, no framing, no zoom breathing or punch.
var calm := false
## "Bildschirmwackeln": false drops the shake and the impact kicks.
var shake_on := true
## Where the camera looks (world px), the zoom factor on top of the base zoom,
## and the screen offset (shake plus kick).
var position := Vector2.ZERO
var zoom := 1.0
var offset := Vector2.ZERO
## How far the view sits below `position` (world px) so the bottom HUD strip
## covers no part of the fight; the game adds it to the camera's offset.
var view_shift := Vector2.ZERO

var _started := false
var _last_hero := Vector2.ZERO
var _vel := Vector2.ZERO
var _lead := Vector2.ZERO
var _pull := Vector2.ZERO
var _zoom_base := 1.0
var _rest := 0.0
var _punch := 0.0
var _punch_goal := 0.0
var _kick := Vector2.ZERO
var _kick_v := Vector2.ZERO


func _init(config: Dictionary = {}) -> void:
	cfg = config if not config.is_empty() else load_config()


## Reads assets/data/story_camera.json (empty when it is missing).
static func load_config(path := DATA_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}


## Reads the two camera options from the options file ([options] shake, camera_calm).
func read_options(path := SETTINGS_PATH) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	shake_on = bool(file.get_value("options", "shake", true))
	calm = bool(file.get_value("options", "camera_calm", false))


## Applies one changed option (the pause menu's options page).
func set_option(key: String, value: Variant) -> void:
	if key == "shake": shake_on = bool(value)
	elif key == "camera_calm": calm = bool(value)


## Jumps straight to `at` (floor load, respawn, debug jump): no smoothing left over.
func reset(at: Vector2) -> void:
	position = at
	_last_hero = at
	_vel = Vector2.ZERO
	_lead = Vector2.ZERO
	_pull = Vector2.ZERO
	_kick = Vector2.ZERO
	_kick_v = Vector2.ZERO
	_rest = 0.0
	_started = true


## Zooms in for a moment: "ultimate" or "heavy" from the json, or a number.
func punch(kind: Variant = "ultimate") -> void:
	var p: Dictionary = cfg.get("punch", {})
	var amount := float(p.get(kind, 0.0)) if kind is String else float(kind)
	_punch_goal = minf(maxf(_punch_goal, amount), float(p.get("max", 0.1)))


## Shoves the view along `dir` by about `px` world pixels (a json kick name such
## as "hero_hit" or a number); it springs back with a small overshoot.
func kick(dir: Vector2, px: Variant = "hero_hit") -> void:
	if not shake_on or dir == Vector2.ZERO:
		return
	var k: Dictionary = cfg.get("kick", {})
	var amount := float(k.get(px, 0.0)) if px is String else float(px)
	var scale := float(cfg.get("calm", {}).get("kick", 0.35)) if calm else 1.0
	_kick_v += dir.normalized() * amount * scale * float(k.get("speed", 14.0))


## One frame. `frame`: hero (focus point, world px), aim (world point of the mouse
## or Vector2.INF), foes (Array of Vector2: live foes of the fight he is in, the
## boss first), boss (bool: a boss among them), bounds (Rect2 the view stays
## inside, empty for none), view (visible world size at zoom 1), shake (px,
## decaying) and t (clock).
func step(dt: float, frame: Dictionary) -> void:
	dt = clampf(dt, 0.0, 0.1)
	var hero: Vector2 = frame.get("hero", Vector2.ZERO)
	if not _started or hero.distance_to(_last_hero) > float(cfg.get("snap_distance", 1400.0)):
		reset(hero)
	var view: Vector2 = frame.get("view", Vector2(1800, 1012.5))
	if dt > 0.0:
		_vel = _vel.lerp((hero - _last_hero) / dt, _ease(float(cfg.get("velocity_rate", 8.0)), dt))
	_last_hero = hero
	var foes: Array = _near(frame.get("foes", []), hero)
	var boss := bool(frame.get("boss", false)) and not foes.is_empty()
	_step_lead(dt, hero, frame.get("aim", Vector2.INF))
	_step_pull(dt, hero, foes, boss)
	_step_zoom(dt, hero, foes, boss, view)
	_step_kick(dt)
	# lead and lean together stay within max_offset, flatter vertically (16:9)
	var lean := _lead + _pull
	var most := float(cfg.get("max_offset", 240.0))
	if lean.length() > most:
		lean = lean.normalized() * most
	lean.y *= float(cfg.get("vertical_scale", 0.75))
	# the bottom HUD strip: the view sits half its height lower; the bounds grow by
	# that on both ends, so the shifted view still stops at the room's top wall
	# and its bottom wall can rise above the strip
	var visible := view / zoom
	var lift := visible.y * clampf(float(cfg.get("hud_bottom", 0.0)), 0.0, 0.4) * 0.5
	view_shift = Vector2(0.0, lift)
	var bounds: Rect2 = frame.get("bounds", Rect2())
	if bounds.size != Vector2.ZERO and lift > 0.0:
		bounds = bounds.grow_individual(0.0, lift, 0.0, lift)
	var target := _clamp(hero + lean, bounds, visible)
	position = position.lerp(target, _ease(float(cfg.get("follow_rate", 6.5)), dt))
	offset = _shake(float(frame.get("shake", 0.0)), float(frame.get("t", 0.0))) + _kick


## The hero's run direction plus a little of where he aims.
func _step_lead(dt: float, hero: Vector2, aim: Vector2) -> void:
	var l: Dictionary = cfg.get("lead", {})
	var want := (_vel / maxf(1.0, float(l.get("run_speed", 350.0)))).limit_length(1.0) * float(l.get("move", 90.0))
	if aim.is_finite():
		var to := aim - hero
		var dead := float(l.get("aim_dead", 140.0))
		if to.length() > dead:
			var amount := clampf((to.length() - dead) / maxf(1.0, float(l.get("aim_range", 360.0))), 0.0, 1.0)
			want += to.normalized() * amount * float(l.get("aim", 60.0))
	if calm:
		want *= float(cfg.get("calm", {}).get("lead", 0.0))
	_lead = _lead.lerp(want, _ease(float(l.get("rate", 2.5)), dt))


## Leans toward the middle of the fight (a boss counts more), never far.
func _step_pull(dt: float, hero: Vector2, foes: Array, boss: bool) -> void:
	var f: Dictionary = cfg.get("frame", {})
	var want := Vector2.ZERO
	if not foes.is_empty():
		var sum := Vector2.ZERO
		var weight := 0.0
		for i in foes.size():
			var w := float(f.get("boss_weight", 3.0)) if boss and i == 0 else 1.0
			sum += (foes[i] as Vector2) * w
			weight += w
		want = ((sum / weight) - hero) * float(f.get("weight", 0.3))
		want = want.limit_length(float(f.get("max_pull", 200.0)))
	if calm:
		want *= float(cfg.get("calm", {}).get("frame", 0.0))
	_pull = _pull.lerp(want, _ease(float(f.get("rate", 2.0)), dt))


## Wider for crowds and bosses (and wide enough to keep the fight in view),
## a touch closer when he stands still with no fight; the punch rides on top.
func _step_zoom(dt: float, hero: Vector2, foes: Array, boss: bool, view: Vector2) -> void:
	var z: Dictionary = cfg.get("zoom", {})
	var want := 1.0
	_rest = _rest + dt if foes.is_empty() and _vel.length() < float(z.get("rest_speed", 30.0)) else 0.0
	if not foes.is_empty():
		var from := float(z.get("crowd_from", 2))
		var crowd := clampf((float(foes.size()) - from) / maxf(1.0, float(z.get("crowd_to", 8)) - from), 0.0, 1.0)
		want = lerpf(1.0, float(z.get("crowd", 0.92)), crowd)
		if boss:
			want = minf(want, float(z.get("boss", 0.88)))
		# every foe in the frame: the visible half size must cover the farthest one
		var reach := Vector2.ZERO
		for p: Vector2 in foes:
			reach = Vector2(maxf(reach.x, absf(p.x - hero.x)), maxf(reach.y, absf(p.y - hero.y)))
		reach += Vector2.ONE * float(z.get("fit_margin", 140.0))
		# only the part above the bottom HUD strip counts vertically
		var free_y := view.y * (1.0 - clampf(float(cfg.get("hud_bottom", 0.0)), 0.0, 0.4))
		want = minf(want, minf(view.x * 0.5 / reach.x, free_y * 0.5 / reach.y))
		want = maxf(want, float(z.get("min", 0.82)))
	elif _rest > float(z.get("rest_delay", 2.5)):
		want = float(z.get("rest", 1.05))
	var c: Dictionary = cfg.get("calm", {})
	if calm and not bool(c.get("zoom", false)):
		want = 1.0
	_zoom_base = lerpf(_zoom_base, want, _ease(float(z.get("rate", 1.2)), dt))
	var p: Dictionary = cfg.get("punch", {})
	if calm and not bool(c.get("punch", false)):
		_punch_goal = 0.0
	_punch_goal *= exp(-float(p.get("decay", 6.0)) * dt)
	_punch = lerpf(_punch, _punch_goal, _ease(float(p.get("attack", 25.0)), dt))
	zoom = _zoom_base * (1.0 + _punch)


## The kick: a damped spring back to rest, a little underdamped so it settles with life.
func _step_kick(dt: float) -> void:
	var k: Dictionary = cfg.get("kick", {})
	var spring := float(k.get("spring", 220.0))
	var damping := float(k.get("damping", 18.0))
	var steps := maxi(1, ceili(dt / (1.0 / 120.0)))
	var h := dt / float(steps)
	for i in steps:
		_kick_v += (-spring * _kick - damping * _kick_v) * h
		_kick += _kick_v * h
	_kick = _kick.limit_length(float(k.get("max", 26.0)))


## The layered-sine shake (smooth, self-ending as `amount` decays), behind the options.
func _shake(amount: float, t: float) -> Vector2:
	if not shake_on or amount <= 0.0:
		return Vector2.ZERO
	amount *= float(cfg.get("shake", {}).get("amount", 1.0)) * (float(cfg.get("calm", {}).get("shake", 0.5)) if calm else 1.0)
	var st := t * 30.0
	return Vector2(0.6 * sin(st * 1.7 + 1.3) + 0.4 * sin(st * 3.1 + 2.6), 0.6 * sin(st * 2.3 + 4.1) + 0.4 * sin(st * 3.7 + 0.7)) * amount


## Foes close enough to frame (the order stays: the boss first when there is one).
func _near(foes: Array, hero: Vector2) -> Array:
	var reach := float(cfg.get("frame", {}).get("range", 1100.0))
	return foes.filter(func(p: Variant) -> bool: return p is Vector2 and (p as Vector2).distance_to(hero) <= reach)


## Keeps the visible rect inside `bounds`; a room smaller than the view centres it.
static func _clamp(target: Vector2, bounds: Rect2, visible: Vector2) -> Vector2:
	if bounds.size == Vector2.ZERO:
		return target
	for axis in [0, 1]:
		if bounds.size[axis] <= visible[axis]:
			target[axis] = bounds.position[axis] + bounds.size[axis] / 2.0
		else:
			target[axis] = clampf(target[axis], bounds.position[axis] + visible[axis] / 2.0, bounds.end[axis] - visible[axis] / 2.0)
	return target


static func _ease(rate: float, dt: float) -> float:
	return 1.0 - exp(-rate * dt)
