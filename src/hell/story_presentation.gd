extends RefCounted
## Render-only positions between fixed story ticks. Never writes combat bodies.
## One tick of display latency; no extrapolation through walls or into attacks.
var alpha := 1.0
var teleport_distance := 192.0
var _hero: Dictionary = {}
var _hero_from := Vector2.ZERO
var _previous: Dictionary = {}
var _bodies: Dictionary = {}

## Retains only the positions immediately before the next simulation tick.
func begin_tick(hero: Dictionary, mobs: Array) -> void:
	_hero = hero
	_hero_from = Vector2(hero.x, hero.y)
	_previous.clear()
	_bodies.clear()
	for mob: Dictionary in mobs:
		var id := int(mob.get("tid", -1))
		if id < 0: continue # Newly spawned bodies render at their current position.
		_previous[id] = Vector2(mob.p)
		_bodies[id] = mob

## The scheduler's leftover time determines the shared actor/camera blend.
func frame(pending: float, tick: float) -> void:
	alpha = clampf(pending / maxf(tick, 0.000001), 0.0, 1.0)

## Clears history on pause, floor change, respawn or an explicit camera jump.
func reset() -> void:
	_hero = {}
	_previous.clear()
	_bodies.clear()
	alpha = 1.0

## Drawn feet; a replacement player dictionary cannot inherit another run's pose.
func hero_position(hero: Dictionary) -> Vector2:
	var at := Vector2(hero.x, hero.y)
	return _blend(_hero_from, at) if is_same(hero, _hero) else at

## Drawn feet with identity validation; deaths retain the existing corpse pose.
func mob_position(mob: Dictionary) -> Vector2:
	var at := Vector2(mob.p)
	var id := int(mob.get("tid", -1))
	if float(mob.get("hp", 1.0)) <= 0.0 or mob.get("dying") != null: return at
	if not _bodies.has(id) or not is_same(_bodies[id], mob): return at
	return _blend(_previous[id], at)

func _blend(before: Vector2, now: Vector2) -> Vector2:
	if before.distance_squared_to(now) > teleport_distance * teleport_distance: return now
	return before.lerp(now, alpha)

## Snap the combined camera translation (including shake/HUD offset) in physical
## screen pixels, after window stretch. Keeps the internal follow state unrounded.
static func pixel_center(center: Vector2, zoom: Vector2, view: Vector2, stretch: Transform2D) -> Vector2:
	var scale := stretch.get_scale() * zoom
	if scale.x <= 0.0 or scale.y <= 0.0: return center
	var origin := stretch * (view * 0.5) - center * scale
	return center + (origin - origin.round()) / scale
