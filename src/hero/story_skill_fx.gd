extends RefCounted
## The crypt's skill effects in the story worlds (src/hell/hell_game.gd:
## Hell-Dungeon and Frostgruft). The world keeps its skill rules; this file
## reads what they leave behind (fx entries, shots, zones, the held beam, rage
## and dashes) and draws it through the crypt's src/vfx/skill_fx.gd, with its
## pixel-art sprites (fx_sprites.gd), pixel particles and floor marks
## (particles.gd) and bloom:
## - whirl: the blade circling the hero (hero_look.gd) and dust from the floor;
## - blade wave, fireball and arrow fist: the crypt's projectiles, the fireball
##   in the shots' pixel language (src/vfx/attack_fx.gd fireball); fireball and
##   fist bursts as pixel matter of their element: embers that land and die,
##   frost shards and rime on the floor (skill_fx.gd, attack_fx element_burst);
## - chain lightning: forked bolts with an afterglow and sparks at every hit;
## - blink: violet flashes at both ends; Rage: the red aura and its burst;
## - Photoneneis: the ice-and-fire beam, stopped at the first wall;
## - backflip caltrops, charge and backflip dust.
## Everything is drawn in crypt units (story world px / scale) on layers scaled
## by `scale`, and stops at the world's walls (its floor cells become the
## crypt's 32 px cells). Presentation only.

const SkillFx = preload("res://src/vfx/skill_fx.gd")
const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const Particles = preload("res://src/vfx/particles.gd")
const Glow = preload("res://src/vfx/glow.gd")
## Crypt units per crypt cell (fx_sprites and particles work in 32 px cells).
const CELL := 32.0
## Hero shots drawn here (the rest: attack_fx or the world).
const SHOT_STYLES := {"wave": "wave", "fireball": "fireball", "fist": "fist"}
## Crypt size of each skill shot (the look, not the hit area).
const SHOT_RADIUS := {"wave": 30.0, "fireball": 7.0, "fist": 32.0}
## World blasts that become crypt bursts (shot kind -> burst colour, skill_fx.gd
## BURST_ELEMENTS); a fireball dying without a blast bursts along its flight ("dir").
const BLASTS := {"fireball": "fire", "fist": "frost", "sub_ice": "frost"}
## World effects drawn here (the world skips them).
const FX_KINDS := ["whirl", "bolt", "blink"]
## Largest whirl radius for the floor dust (crypt units; bigger whirls would bury the hero).
const WHIRL_DUST := 56.0
## How long each crypt event lasts (seconds, as in hero_skills.gd).
const EVENT_TIME := {"whirl": 0.35, "chain": 0.45, "blink": 0.35, "burst": 0.4, "charge": 0.3, "backflip": 0.3, "rage": 0.5, "fist": 0.3, "ballista": 0.2, "volley": 0.2}

var g: Node
## Story world px per crypt unit.
var scale := 1.5
var skill := SkillFx.new()
var fx := FxSprites.new()
var particles := Particles.new()
var glow := Glow.new()
## The crypt snapshot this frame: players, skill_fx zones and events.
var snapshot: Dictionary = {"players": {}, "skill_fx": {"zones": [], "events": []}}
## Skill projectiles this frame (crypt bullets).
var bullets: Array = []
var _events: Array = []
var _next_id := 1
var _world: Dictionary = {}
var _rage := false
var _dashing := false
var _shots: Dictionary = {}
var _clock := 0.0


func _init(game: Node, world_scale: float) -> void:
	g = game
	scale = world_scale
	skill.fx = fx
	skill.particles = particles
	# only its strengths (vfx_glow.json) are used; hidden, it goes with the world
	glow.visible = false
	g.add_child(glow)


# --- coordinates ---------------------------------------------------------------------

## A world point on the floor (feet, zone centres) in crypt units.
func ground(p: Vector2) -> Vector2:
	return p / scale


## A world point at body height (chests, mob centres, shots) in crypt units: the
## crypt lifts these effects 12 px off the floor point it is given.
func body(p: Vector2) -> Vector2:
	return p / scale + Vector2(0, 12)


## The hero's crypt point (the crypt draws its hero around it).
func hero_point() -> Vector2:
	return Vector2(float(g.player.x), float(g.player.y) - 21.0) / scale


# --- rules of what is drawn here -----------------------------------------------------

## True for world fx entries drawn here (the world skips them).
func handles_fx(f: Dictionary) -> bool:
	var kind := str(f.get("kind", ""))
	return kind in FX_KINDS or (kind == "blast" and BLASTS.has(str(f.get("shot", ""))))


## True for world zones drawn here.
func handles_zone(z: Dictionary) -> bool:
	return str(z.get("kind", "")) == "caltrop"


## True for the hero's skill shots drawn here.
func handles_shot(s: Dictionary) -> bool:
	return SHOT_STYLES.has(str(s.get("kind", "")))


## True for held skills whose look is drawn here (beam, ballista draw).
func handles_hold(id: String) -> bool:
	return id in ["photon", "ballista"]


# --- per frame -----------------------------------------------------------------------

## Reads the world's skills into the crypt snapshot and runs the effects.
func update(dt: float, clock: float) -> void:
	_clock = clock
	if not is_same(_world, g.W):
		_world = g.W
		_set_floor()
	for e: Dictionary in _events:
		e.time = float(e.time) - dt
	_events = _events.filter(func(e: Dictionary) -> bool: return float(e.time) > 0.0)
	var blasts: Array = []
	for f: Dictionary in g.fx:
		if f.has("crypt_seen") or not handles_fx(f): continue
		f.crypt_seen = true
		_from_fx(f, blasts)
	_states()
	_read_shots(blasts)
	var zones: Array = []
	for z: Dictionary in g.zones:
		if not handles_zone(z): continue
		if not z.has("crypt_id"):
			z.crypt_id = _next_id
			_next_id += 1
		var at := ground(z.p)
		zones.append({"id": int(z.crypt_id), "kind": "caltrops", "x": at.x, "y": at.y, "r": float(z.r) / scale, "t": float(z.t)})
	snapshot = {"players": {1: _player()}, "skill_fx": {"zones": zones, "events": _events}}
	fx.update(dt)
	particles.update(dt)


## A crypt event (as hero_skills.gd sends it).
func event(kind: String, points: Array, extra: Dictionary = {}) -> void:
	var time := float(EVENT_TIME.get(kind, 0.3))
	var e := {"kind": kind, "points": points.map(func(p: Vector2) -> Array: return [p.x, p.y]), "time": time, "length": time, "id": _next_id}
	_next_id += 1
	e.merge(extra, true)
	_events.append(e)
	if _events.size() > 48: _events.pop_front()


func _from_fx(f: Dictionary, blasts: Array) -> void:
	match str(f.kind):
		"whirl":
			# the floor dust grows with the radius, up to the crypt's largest whirl
			event("whirl", [ground(Vector2(float(g.player.x), float(g.player.y)))], {"radius": minf(float(f.r) / scale, WHIRL_DUST)})
		"bolt":
			event("chain", [body(f.p), body(f.q)])
		"blink":
			event("blink", [body(f.p), body(f.q)])
		"blast":
			var at := body(f.p) - Vector2(0, 12)
			blasts.append(at)
			event("burst", [at], {"radius": maxf(24.0, float(f.r) / scale), "color": BLASTS[str(f.shot)]})


## Rage and dashes starting: their bursts and dust.
func _states() -> void:
	var rage := float(g.state.get("rage", 0.0)) > 0.0
	if rage and not _rage: event("rage", [hero_point()])
	_rage = rage
	var dashing := not (g.dash as Dictionary).is_empty()
	if dashing and not _dashing: event("charge" if float(g.dash.get("mult", 0.0)) > 0.0 else "backflip", [hero_point()])
	_dashing = dashing


## Skill shots: crypt bullets, cast flashes for new ones, a small burst where a
## fireball dies on a wall (an explosion has its own).
func _read_shots(blasts: Array) -> void:
	bullets = []
	var alive := {}
	var new_arrows := 0
	for s: Dictionary in g.shots:
		var kind := str(s.get("kind", ""))
		if not s.has("crypt_id"):
			s.crypt_id = _next_id
			_next_id += 1
			if kind == "fist": event("fist", [hero_point()])
			elif kind == "arrow" and bool(s.get("pierce", false)): event("ballista", [hero_point()])
			elif kind == "arrow": new_arrows += 1
		if not handles_shot(s): continue
		var at := (s.p as Vector2) / scale
		var v: Vector2 = s.v
		alive[int(s.crypt_id)] = {"at": at, "kind": kind, "v": v}
		bullets.append({"id": int(s.crypt_id), "x": at.x, "y": at.y, "vx": v.x, "vy": v.y, "owner": 1, "style": SHOT_STYLES[kind], "radius": float(SHOT_RADIUS[kind])})
	if new_arrows >= 3: event("volley", [hero_point()])
	for id: int in _shots:
		if alive.has(id): continue
		var last: Dictionary = _shots[id]
		if str(last.kind) != "fireball": continue
		var exploded := blasts.any(func(b: Vector2) -> bool: return b.distance_to(last.at) < 60.0)
		if not exploded:
			# it died on a wall or ran out: its embers fly on the way it flew
			var along := (last.v as Vector2).normalized()
			event("burst", [Vector2(last.at)], {"radius": 22.0, "color": "fire", "dir": [along.x, along.y]})
	_shots = alive


## The hero as the crypt sees it: point, aim and running skill states.
func _player() -> Dictionary:
	var at := hero_point()
	var aim: Vector2 = g.HeroKit._aim(g)
	var skills := {}
	if float(g.state.get("rage", 0.0)) > 0.0: skills.rage = float(g.state.rage)
	var hold: Dictionary = g.hold
	match str(hold.get("id", "")):
		"photon":
			var s: Dictionary = g.HeroKit._skill(g, "photon")
			var me := Vector2(float(g.player.x), float(g.player.y) - 40.0)
			var dir := Vector2.from_angle(float(hold.get("angle", aim.angle())))
			var from := body(me)
			var to := body(g.HeroKit.beam_end(g, me, dir, float(s.get("length", 600.0))))
			skills.beam = [from.x, from.y, to.x, to.y]
		"ballista":
			var charge := float(g.HeroKit._skill(g, "ballista").get("charge", 1.0))
			skills.charge = clampf(float(hold.get("t", 0.0)) / maxf(0.1, charge), 0.0, 1.0)
	return {"x": at.x, "y": at.y, "ax": aim.x, "ay": aim.y, "hp": float(g.state.get("hp", 1)), "class_id": str(g.class_id), "skills": skills}


## A new floor: its floor cells bound the effects, its old marks go.
func _set_floor() -> void:
	var cells := {}
	var C: float = g.C
	var per := int(round(C / scale / CELL))
	for cy in range(int(g.W.rows)):
		for cx in range(int(g.W.cols)):
			if not g._walkable(int(g.W.grid[cy * int(g.W.cols) + cx])): continue
			for y in range(per):
				for x in range(per):
					cells[Vector2i(cx * per + x, cy * per + y)] = true
	fx.clear()
	fx.set_walkable(cells)
	particles.clear()
	particles.set_walkable(cells, "story_%d" % _next_id)
	_next_id += 1
	_events.clear()
	_shots.clear()


# --- drawing (on layers scaled by `scale`) -------------------------------------------

## Under the actors: floor marks, caltrops, the Rage aura.
func draw_ground(canvas: CanvasItem) -> void:
	particles.draw_stains(canvas)
	skill.draw_ground(canvas, snapshot, _clock)


## Over the actors: skill shots, events, the beam, sprites and particles.
func draw_over(canvas: CanvasItem) -> void:
	for b: Dictionary in bullets:
		skill.draw_bullet(canvas, b, _clock)
	skill.draw_over(canvas, snapshot, _clock)
	fx.draw(canvas)
	particles.draw_particles(canvas)


## Bloom of the skills (additive layer).
func draw_glow(canvas: CanvasItem) -> void:
	for b: Dictionary in bullets:
		skill.bullet_glow(canvas, b, Vector2(float(b.x), float(b.y)), _clock, glow.level("bullets"))
	skill.draw_glow(canvas, snapshot, _clock, glow)
	fx.draw_glow(canvas, glow.level("spells"))
	particles.draw_glow(canvas, glow.level("particles"))
