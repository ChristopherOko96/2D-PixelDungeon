extends RefCounted
## The Irrwisch: the mage's familiar, a small pixel wisp that floats round his
## head and follows him with a lag, so the player knows "that is my creature".
## Drawn on the art grid (src/vfx/pixel_paint.gd): a 2x2 core in the spec
## colour of the mage's element, a 1 px halo and a few trailing pixels fading
## behind it. Its place is the head plus a slow elliptical orbit with a bob;
## it follows that place with a critically damped spring (~0.15 s) and leans
## into the hero's movement. Colours by the main specialisation: fire ember,
## ice shard-blue, void violet, neutral pale white-blue. Mage class only.
## Values in assets/data/hero_skins.json "familiar". Presentation only: it
## reads positions and never touches game state.
##
## The story worlds keep one instance in src/hero/story_hero.gd (step in
## update, draw over the hero); the crypt view (src/dungeon_view.gd) calls
## draw_for with the local hero's snapshot and a key, and the wisp keeps its
## own clock from the view's.

const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const ElementSkin = preload("res://src/hero/element_skin.gd")

## The element the wisp burns in: "" (neutral), "fire", "ice" or "void".
var element := ""
## Where the core is (world px); INF until the first step.
var pos := Vector2.INF
var vel := Vector2.ZERO
## Recent core positions, newest first; the newest lies under the core.
var _trail: Array[Vector2] = []
var _trail_t := 0.0
## Orbit and bob phase, so two wisps never move in lockstep.
var _phase := 0.0
var _hero_last := Vector2.INF
var _hero_vel := Vector2.ZERO
var _last_t := -1.0

## Wisps of views that keep no instance of their own, by key ("crypt:p1").
static var _registry: Dictionary = {}


func _init() -> void:
	_phase = randf() * TAU


## The familiar's values (hero_skins.json "familiar").
static func config() -> Dictionary:
	return ElementSkin.data().get("familiar", {})


## True for the classes that have a familiar (hero_skins.json familiar.classes).
static func has_familiar(class_id: String) -> bool:
	return class_id in Array(config().get("classes", ["mage"]))


## The wisp kept under `key`, made on first use.
static func of(key: String) -> RefCounted:
	if not _registry.has(key): _registry[key] = load("res://src/hero/familiar.gd").new()
	return _registry[key]


## For a view without an instance (the crypt): the wisp of `key` follows the
## snapshot `player` (class_id, hp, talents) standing at `feet` (world px) at
## the view's time `t` and is drawn on the `art` px grid. Nothing for classes
## without a familiar or a fallen hero. The element is read from the snapshot's
## talents (src/hero/element_skin.gd element_from_talents).
static func draw_for(key: String, canvas: CanvasItem, feet: Vector2, t: float, art: float, player: Dictionary) -> void:
	if not has_familiar(str(player.get("class_id", ""))) or float(player.get("hp", 1)) <= 0.0: return
	var wisp: RefCounted = of(key)
	wisp.element = ElementSkin.element_from_talents(player.get("talents", {}))
	wisp.follow_and_draw(canvas, feet, t, art)


## Steps by this wisp's own clock (the gap since the last call, at most 0.1 s) and draws.
func follow_and_draw(canvas: CanvasItem, feet: Vector2, t: float, art: float, hero_vel: Vector2 = Vector2.INF) -> void:
	var dt := clampf(t - _last_t, 0.0, 0.1) if _last_t >= 0.0 else 0.0
	_last_t = t
	step(dt, t, feet, art, hero_vel)
	draw(canvas, art, t)


## Moves the wisp for `dt` seconds towards its place over the head of a hero
## standing at `feet` (world px) at time `t`, on the `art` px grid. `hero_vel`
## is the hero's speed in world px/s; Vector2.INF estimates it from the feet.
func step(dt: float, t: float, feet: Vector2, art: float, hero_vel: Vector2 = Vector2.INF) -> void:
	var c := config()
	if hero_vel == Vector2.INF:
		# estimated from the feet and smoothed, so a snapshot's steps do not jitter
		var raw := (feet - _hero_last) / dt if dt > 0.0 and _hero_last != Vector2.INF else _hero_vel
		_hero_vel = _hero_vel.lerp(raw, clampf(dt * 12.0, 0.0, 1.0))
	else:
		_hero_vel = hero_vel
	_hero_last = feet
	var orbit: Dictionary = c.get("orbit", {})
	var bob: Dictionary = c.get("bob", {})
	var head := feet - Vector2(0.0, (float(c.get("head_above_feet", 17)) + float(orbit.get("above", 4))) * art)
	var angle := t * float(orbit.get("speed", 0.9)) + _phase
	var ring := Vector2(cos(angle) * float(orbit.get("rx", 7)), sin(angle) * float(orbit.get("ry", 3))) * art
	var bobbing := Vector2(0.0, sin(t * TAU * float(bob.get("hz", 0.7)) + _phase) * float(bob.get("amp", 1.2)) * art)
	# leaning into the movement: the place runs a little ahead of the hero
	var target := head + ring + bobbing + _hero_vel * float(c.get("lead", 0.07))
	if pos == Vector2.INF or pos.distance_to(target) > float(c.get("snap_px", 160)):
		# first sight, or the hero changed rooms: no flight across the map
		pos = target
		vel = Vector2.ZERO
		_trail.clear()
	# critically damped spring (damping 2w, stiffness w^2), semi-implicit in small steps
	var w := 1.0 / maxf(0.02, float(c.get("lag", 0.15)))
	var h_max := maxf(0.005, float(c.get("max_step", 0.05)))
	var left := dt
	while left > 0.0:
		var h := minf(left, h_max)
		left -= h
		vel += (-2.0 * w * vel - w * w * (pos - target)) * h
		pos += vel * h
	var trail: Dictionary = c.get("trail", {})
	_trail_t -= dt
	if _trail_t <= 0.0 or _trail.is_empty():
		_trail_t = float(trail.get("every", 0.045))
		_trail.push_front(pos)
		while _trail.size() > int(trail.get("count", 3)) + 1: _trail.pop_back()


## Draws the wisp on `canvas` on the `art` px grid: the trail pixels (oldest
## first, darkest last), the 1 px halo pulsing round the 2x2 core, the core in
## the element's colours (hero_skins.json familiar.colors).
func draw(canvas: CanvasItem, art: float, t: float) -> void:
	if pos == Vector2.INF: return
	var c := config()
	var palettes: Dictionary = c.get("colors", {})
	var colors: Dictionary = palettes.get(element, palettes.get("", {}))
	var core := Color(str(colors.get("core", "ffffff")))
	var trail_cols: Array = colors.get("trail", [])
	for i in range(_trail.size() - 1, 0, -1):
		var col := Color(str(trail_cols[mini(i - 1, trail_cols.size() - 1)])) if not trail_cols.is_empty() else core
		PixelPaint.cell(canvas, PixelPaint.at(_trail[i], art), col, art)
	# the 2x2 core is centred on pos: its top-left cell is one cell up and left of the nearest corner
	var q := Vector2i((pos / art).round()) - Vector2i.ONE
	var halo := Color(str(colors.get("halo", "ffffff")))
	halo.a = clampf(float(c.get("halo_alpha", 0.4)) + float(c.get("halo_pulse", 0.12)) * sin(t * TAU * float(c.get("pulse_hz", 2.2)) + _phase), 0.0, 1.0)
	for dy in range(-1, 3):
		for dx in range(-1, 3):
			var inside := dx >= 0 and dx <= 1 and dy >= 0 and dy <= 1
			var corner := (dx == -1 or dx == 2) and (dy == -1 or dy == 2)
			if inside or corner: continue
			PixelPaint.cell(canvas, q + Vector2i(dx, dy), halo, art)
	for dy in range(2):
		for dx in range(2):
			PixelPaint.cell(canvas, q + Vector2i(dx, dy), core, art)
