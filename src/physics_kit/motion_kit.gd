class_name MotionKit
extends RefCounted
## How bodies move physically (BAUPLAN M1b), in one module:
## - the hero's knockback: eased out over its time, squashed on the floor's
##   depth, never a step longer than knock.step_max (so it never tunnels),
##   walls stopping each axis (knock_hero, step_knock);
## - walking with grip: on ice, blood, glaze tiles or under the slip condition
##   the old velocity gives way to the wanted one slowly (slide, step_hero);
## - the void's pull towards its heart (pull);
## - a monster's push velocity that decays, added to its walk (step_body);
## - axis-by-axis integration against a solid(x, y) Callable (integrate):
##   a wall stops one axis, the body slides along it.
## Values: assets/data/physics_motion.json; the knock speeds per blow kind
## stay with each world and come in as a table.
##
## The kit reaches the game only through its host (src/physics_kit/motion_host.gd,
## the contract; the story worlds' adapter is src/hell/story_motion_host.gd).
## Monsters need no host: step_body takes numbers and gives numbers back.
##
## [codeblock]
## var kit := MotionKit.new(my_host)
## kit.knock_hero(blow_from, "slam", {"slam": 620, "time": 0.22}, false)
## # every frame:
## kit.step_knock(dt)
## kit.step_hero(wanted_velocity, MotionKit.FIRM, Vector2.ZERO, dt)
## var r := kit.step_body(m.p, m.sv, wanted, 0.35, Vector2.ZERO, m.k, dt, my_solid)
## m.p = r.p; m.sv = r.vel; m.k = r.push
## [/codeblock]

const DATA_PATH := "res://assets/data/physics_motion.json"
## The host contract (extend it in a game adapter).
const Host := preload("res://src/physics_kit/motion_host.gd")
## Grip of firm floor: the wanted velocity at once.
const FIRM := 1.0
## The least grip slide() works with (pow(0, dt) would freeze a body for good).
const GRIP_FLOOR := 0.0001

## The game's side (extends src/physics_kit/motion_host.gd); null for step_body and the static helpers only.
var host: RefCounted = null
## physics_motion.json (shared, read-only).
var cfg: Dictionary = {}
## Seconds until the hero's boots scratch the ice again (skid).
var skid_left := 0.0


## A kit for `the_host` with the values of `data` (physics_motion.json when empty).
func _init(the_host: RefCounted = null, data: Dictionary = {}) -> void:
	host = the_host
	cfg = data if not data.is_empty() else DataCache.load_dict(DATA_PATH)


# ---------- the hero's knockback ----------

## Starts the hero's knockback away from `from` for a blow of `kind`: its start
## speed from `table` (the world's knock table: px/s per kind, "time",
## "mob_scale"), a share mob_scale of it when `weaker` (a mob's blow), squashed
## on the floor's depth. True when it pushes (the kind has a speed).
func knock_hero(from: Vector2, kind: String, table: Dictionary, weaker: bool) -> bool:
	var knock := knock_start(Vector2(host.hero_x(), host.hero_y()), from, kind, table, weaker)
	if knock.is_empty():
		return false
	# on ice the blow sends him gliding (decision D9): knock.ice_glide of it goes into his own
	# sliding speed, which the ice keeps; the rest eases out as on stone
	if host.has_method("hero_grip") and float(host.hero_grip()) < FIRM:
		var glide := float((cfg.get("knock", {}) as Dictionary).get("ice_glide", 0.6))
		host.set_hero_velocity(host.hero_velocity() + (knock.v as Vector2) * glide)
		knock.v = (knock.v as Vector2) * (1.0 - glide)
	host.set_knock_state(knock)
	return true


## A knockback for a body at `at` hit from `from` ({} when the kind has no
## speed): {"v": start velocity px/s, "t": 0, "T": its time s}. Exactly on top
## of the blow it flies off in a random direction (randf()).
func knock_start(at: Vector2, from: Vector2, kind: String, table: Dictionary, weaker: bool) -> Dictionary:
	var spec: Dictionary = cfg.get("knock", {})
	var speed := float(table.get(kind, 0.0))
	if speed <= 0.0:
		return {}
	if weaker:
		speed *= float(table.get("mob_scale", spec.get("mob_scale", 0.7)))
	var away := at - from
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	var squash: Array = spec.get("squash", [1.0, 0.75])
	return {"v": away.normalized() * Vector2(float(squash[0]), float(squash[1])) * speed, "t": 0.0,
		"T": float(table.get("time", spec.get("time", 0.22)))}


## Moves the hero along his running knockback by `dt` s (host.knock_state):
## axis by axis, so a wall stops one axis and he slides along it; ends it when its time is up.
func step_knock(dt: float) -> void:
	var knock: Dictionary = host.knock_state()
	if knock.is_empty():
		return
	var mv := knock_step(knock, dt)
	if float(knock.t) / maxf(float((cfg.get("knock", {}) as Dictionary).get("time_min", 0.01)), float(knock.T)) >= 1.0:
		host.set_knock_state({})
		return
	move_hero(mv)


## Ages knockback `knock` (from knock_start) by `dt` and gives this frame's
## move (world px): the speed eased out as (1 - t/T)^ease_power, no longer
## than step_max. ZERO once its time is up (then t/T >= 1).
func knock_step(knock: Dictionary, dt: float) -> Vector2:
	var spec: Dictionary = cfg.get("knock", {})
	knock.t = float(knock.t) + dt
	var k := float(knock.t) / maxf(float(spec.get("time_min", 0.01)), float(knock.T))
	if k >= 1.0:
		return Vector2.ZERO
	var mv: Vector2 = (knock.v as Vector2) * pow(1.0 - k, float(spec.get("ease_power", 2.0))) * dt
	var longest := float(spec.get("step_max", 24.0))
	if mv.length() > longest:
		mv = mv.normalized() * longest
	return mv


## Moves the hero by `mv` (world px) axis by axis: x first, then y; an axis
## whose new place is blocked stays.
func move_hero(mv: Vector2) -> void:
	var x: float = host.hero_x()
	var y: float = host.hero_y()
	if not host.hero_blocked(x + mv.x, y):
		x += mv.x
	if not host.hero_blocked(x, y + mv.y):
		y += mv.y
	host.place_hero(x, y)


# ---------- walking, sliding and the pull ----------

## One frame of the hero's walk: his velocity gives way to `want` by `grip`
## (slide), `pull` (px/s) is added, and he moves axis by axis; an axis a wall
## stops loses its velocity.
func step_hero(want: Vector2, grip: float, pull: Vector2, dt: float) -> void:
	var vel := slide(host.hero_velocity(), want, grip, dt)
	var v: Vector2 = (vel + pull) * dt
	if v != Vector2.ZERO:
		var x: float = host.hero_x()
		var y: float = host.hero_y()
		if not host.hero_blocked(x + v.x, y):
			x += v.x
		else:
			vel.x = 0.0
		if not host.hero_blocked(x, y + v.y):
			y += v.y
		else:
			vel.y = 0.0
		host.place_hero(x, y)
	host.set_hero_velocity(vel)


## One frame of a body that is not the hero (a monster) at `p`: on slippery
## ground (`grip` < 1) its sliding velocity `vel` gives way to `want`, else it
## takes `want`; `pull` and its push velocity `push` (px/s) are added, and it
## moves axis by axis against `solid` (Callable(x, y) -> bool, true when it may
## not stand there). Gives {"p": its new place, "v": the velocity it moved
## with (px/s, walls not counted), "vel": the sliding velocity to keep, "push":
## the push left for the next frame: push.decay of it per 60th of a second, so a throw carries
## as far at any frame rate (physics plan F35), "push_in": the push it moved with}.
func step_body(p: Vector2, vel: Vector2, want: Vector2, grip: float, pull: Vector2, push: Vector2, dt: float, solid: Callable) -> Dictionary:
	var v := want
	var kept := want
	if grip < FIRM:
		kept = slide(vel, want, grip, dt)
		v = kept
	v += pull
	v += push
	var spec: Dictionary = cfg.get("push", {})
	var left := push * pow(float(spec.get("decay", 0.86)), dt * 60.0)
	# on ice a push glides on: it fades by the floor's grip (at least push.ice_floor), not at the
	# stone's rate (decision D9; frost creatures are passed FIRM and keep stopping)
	if grip < FIRM: left = push * pow(maxf(grip, float(spec.get("ice_floor", 0.12))), dt)
	return {"p": integrate(p, v, dt, solid), "v": v, "vel": kept, "push": left, "push_in": push}


## A grip from physics_motion.json grip ("slip", "medium", "glaze").
func grip(name: String) -> float:
	return float((cfg.get("grip", {}) as Dictionary).get(name, FIRM))


## True when the hero's boots scratch the ice this frame: sliding at `speed`
## px/s faster than skid.speed, every skid.every s (the caller sprays the chips).
func skid(speed: float, dt: float) -> bool:
	var spec: Dictionary = cfg.get("skid", {})
	if speed <= float(spec.get("speed", 140.0)):
		return false
	skid_left -= dt
	if skid_left > 0.0:
		return false
	skid_left = float(spec.get("every", 0.09))
	return true


## Movement on slippery ground: the old velocity gives way to the wanted one
## slowly; `grip` = share of the momentum left after one second (0.015 glaze
## ice, 0.35 blood, 1 firm ground: the wanted velocity at once).
static func slide(velocity: Vector2, wanted: Vector2, grip: float, dt: float) -> Vector2:
	if grip >= FIRM:
		return wanted
	return velocity.lerp(wanted, 1.0 - pow(maxf(grip, GRIP_FLOOR), dt))


## The pull of strength `strength` (px/s) towards `centre` on something at `at`
## (ZERO without strength or right at the centre).
static func pull(strength: float, at: Vector2, centre: Vector2) -> Vector2:
	if strength <= 0.0 or at.distance_squared_to(centre) < 1.0:
		return Vector2.ZERO
	return (centre - at).normalized() * strength


## `p` moved by velocity `v` for `dt` s axis by axis against `solid`
## (Callable(x, y) -> bool, true when the body may not stand there): x first,
## then y from where x left it; a blocked axis stays.
static func integrate(p: Vector2, v: Vector2, dt: float, solid: Callable) -> Vector2:
	var nx: float = p.x + v.x * dt
	if not solid.call(nx, p.y):
		p = Vector2(nx, p.y)
	var ny: float = p.y + v.y * dt
	if not solid.call(p.x, ny):
		p = Vector2(p.x, ny)
	return p
