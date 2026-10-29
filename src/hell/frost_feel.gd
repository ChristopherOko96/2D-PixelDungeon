extends RefCounted
## Story 1's combat feel for the Frostgruft (theme.feel, values there): every hit
## flashes and squashes the enemy on a damped spring, throws chips in the
## enemy's colour and plays the crypt's pixel effects (src/vfx/fx_sprites.gd);
## kills burst and leave a stain; heavy blows and hurts freeze the game for a
## moment (hitstop) and shake the camera. Shots get Story 1's look: a muzzle
## flash, a light streak behind every arrow (golden on a critical hit), a
## burning orb with orbiting motes and a turning rune ring for spells, and a
## burst where a shot ends. Sounds follow the crypt: footsteps, idle growls of
## enemies close by, windups. Presentation only; the game stays authoritative.

const FxSprites = preload("res://src/vfx/fx_sprites.gd")
## Spring of the squash & stretch (as in src/vfx/feedback.gd).
const STIFFNESS := 320.0
const DAMPING := 13.0
const MAX_BITS := 400
const MAX_STAINS := 160

var g: Node
var cfg: Dictionary = {}
var sprites := FxSprites.new()
## Seconds the game stands still (hitstop).
var hitstop := 0.0
var _bits: Array = []
var _stains: Array = []
var _trails: Dictionary = {}
var _step := 0.0
var _idle := 0.0
var _clock := 0.0


func _init(game: Node, config: Dictionary) -> void:
	g = game
	cfg = config


## A new floor: nothing of the last one lingers.
func reset() -> void:
	_bits.clear()
	_stains.clear()
	_trails.clear()
	sprites.clear()
	hitstop = 0.0


func _k() -> float:
	return float(cfg.get("scale", 3.0))


func _color(key: String, fallback: String) -> Color:
	return Color(str(cfg.get("colors", {}).get(key, fallback)))


## The enemy's chip colour by its material (theme.feel.blood).
func blood(m: Dictionary) -> Color:
	var mat := str((m.def as Dictionary).get("material", "void"))
	return Color(str(cfg.get("blood", {}).get(mat, "9fe3ee")))


# ---------- reactions ----------

## A hero's hit landed on an enemy.
func on_hit(m: Dictionary, push: Vector2, crit: bool) -> void:
	var at: Vector2 = (m.p as Vector2) - Vector2(0, m.cy)
	var dir := push.normalized() if push.length() > 0.1 else Vector2.RIGHT.rotated(randf() * TAU)
	kick(m, Vector2(1.25, 0.8), dir)
	burst(at, blood(m), 6 if not crit else 11, 340.0, 0.45, dir, 0.9)
	sprites.spawn("crit_spark" if crit else "hit_spark", at, dir.angle(), _k() * (1.3 if crit else 1.0))
	_hitstop(float(cfg.get("hitstop_crit", 0.07)) if crit else float(cfg.get("hitstop_hit", 0.03)))
	if crit:
		_shake(float(cfg.get("shake_crit", 6.0)))
		g._sound_raw("attack_slash")


## An enemy fell: a burst in its colour, chips and a stain on the floor.
func on_kill(m: Dictionary) -> void:
	var at: Vector2 = (m.p as Vector2) - Vector2(0, m.cy)
	var c := blood(m)
	burst(at, c, 18 if m.kind != "boss" else 50, 420.0, 0.7, Vector2.ZERO, PI)
	sprites.spawn("blood_burst" if str((m.def as Dictionary).get("material", "")) == "flesh" else "frost_burst", at, 0.0, _k() * (0.8 if m.kind != "boss" else 1.8), c.lightened(0.2))
	stain(m.p, c.darkened(0.35), 26.0 * float(m.get("s", 1.0)))
	_hitstop(float(cfg.get("hitstop_kill", 0.05)) * (2.5 if m.kind == "boss" else 1.0))
	_shake(float(cfg.get("shake_kill", 5.0)) * (4.0 if m.kind == "boss" else 1.0))


## The hero lost a heart.
func on_hurt() -> void:
	var at := Vector2(g.player.x, g.player.y - 40)
	kick(g.player, Vector2(0.75, 1.25), Vector2.UP)
	burst(at, _color("hurt", "d8484f"), 12, 300.0, 0.5, Vector2.ZERO, PI)
	_hitstop(float(cfg.get("hitstop_hurt", 0.09)))
	_shake(float(cfg.get("shake_hurt", 14.0)))


## A shot leaves the bow or staff: a flash at the muzzle.
func on_shot(from: Vector2, dir: Vector2, kind: String) -> void:
	var magic := kind in ["magic", "fireball", "sub_ice", "sub_soul", "gravity"]
	sprites.spawn("hit_spark", from + dir * 30.0, dir.angle(), _k() * (1.1 if magic else 0.8), tint_of(kind, false))
	kick(g.player, Vector2(0.9, 1.1), dir)


## A melee swing: the crypt's slash crescent along the arc.
func on_swing(angle: float, reach: float) -> void:
	var at := Vector2(g.player.x, g.player.y - 40) + Vector2(cos(angle), sin(angle)) * reach * 0.45
	sprites.spawn("slash", at, angle, _k() * clampf(reach / 150.0, 0.8, 1.6))
	kick(g.player, Vector2(1.15, 0.9), Vector2(cos(angle), sin(angle)))


## A shot ended (hit, wall or out of time): a burst in its colour.
func on_shot_end(p: Vector2, kind: String) -> void:
	match kind:
		"arrow", "sub_hawk", "sub_knife", "sub_axe", "":
			sprites.spawn("arrow_hit", p, randf() * TAU, _k())
		"sub_ice":
			sprites.spawn("frost_burst", p, 0.0, _k() * 0.45)
		"fireball":
			sprites.spawn("fire_burst", p, 0.0, _k() * 0.6)
		_:
			sprites.spawn("magic_burst", p, 0.0, _k() * 0.55, tint_of(kind, false))


## A blast (splash, explosion): dust ring and a short shake.
func on_blast(p: Vector2, radius: float, style := "magic") -> void:
	var name: String = {"fire": "fire_burst", "ice": "frost_burst", "frost": "frost_burst", "void": "void_burst", "poison": "poison_burst", "stone": "stone_burst"}.get(style, "magic_burst")
	sprites.spawn(name, p, 0.0, _k() * clampf(radius / 130.0, 0.5, 2.0))
	_shake(float(cfg.get("shake_blast", 8.0)) * clampf(radius / 150.0, 0.5, 2.0))


## Any named effect of the crypt sheets (level-up, pickup, dust, blink ...).
func spawn(name: String, p: Vector2, scale := 1.0, tint := Color.WHITE) -> void:
	sprites.spawn(name, p, 0.0, _k() * scale, tint)


static func tint_of(kind: String, crit: bool) -> Color:
	if crit:
		return Color(1.0, 0.82, 0.35)
	match kind:
		"magic":
			return Color(0.45, 1.0, 0.7)
		"fireball":
			return Color(1.0, 0.6, 0.25)
		"sub_ice", "gravity":
			return Color(0.65, 0.9, 1.0) if kind == "sub_ice" else Color(0.75, 0.6, 1.0)
		"sub_soul":
			return Color(0.75, 0.55, 1.0)
	return Color(1.0, 0.95, 0.8)


# ---------- building blocks ----------

## Squash & stretch kick on an actor (enemy or hero dictionary).
func kick(who: Dictionary, squash: Vector2, _dir: Vector2) -> void:
	who.sq = (squash - Vector2.ONE)
	who.sqv = Vector2.ZERO


## The actor's current draw scale (1, 1 at rest).
static func squash(who: Dictionary) -> Vector2:
	return Vector2.ONE + (who.get("sq", Vector2.ZERO) as Vector2)


func burst(at: Vector2, color: Color, count: int, speed: float, life: float, dir := Vector2.ZERO, spread := PI) -> void:
	for i in range(count):
		var a := (dir.angle() if dir != Vector2.ZERO else 0.0) + randf_range(-spread, spread)
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.35, 1.0)
		_bits.append({"p": at, "v": v, "z": randf_range(10.0, 40.0), "vz": randf_range(120.0, 360.0), "t": life * randf_range(0.6, 1.2),
			"c": color.lightened(randf_range(-0.15, 0.25)), "s": randf_range(3.0, 7.0)})
	while _bits.size() > MAX_BITS:
		_bits.pop_front()


func stain(at: Vector2, color: Color, radius: float) -> void:
	_stains.append({"p": at + Vector2(randf_range(-8, 8), randf_range(-4, 4)), "c": Color(color, 0.55), "r": radius * randf_range(0.8, 1.2)})
	while _stains.size() > MAX_STAINS:
		_stains.pop_front()


func _hitstop(t: float) -> void:
	hitstop = maxf(hitstop, t)


func _shake(amount: float) -> void:
	g.state.shake = maxf(float(g.state.get("shake", 0.0)), amount)


# ---------- per frame ----------

func update(dt: float) -> void:
	_clock += dt
	sprites.update(dt)
	for b: Dictionary in _bits:
		b.t = float(b.t) - dt
		b.p += (b.v as Vector2) * dt
		b.v *= exp(-5.0 * dt)
		b.vz = float(b.vz) - 900.0 * dt
		b.z = maxf(0.0, float(b.z) + float(b.vz) * dt)
		if float(b.z) <= 0.0:
			b.v *= 0.6
	_bits = _bits.filter(func(b: Dictionary) -> bool: return float(b.t) > 0.0)
	var actors: Array = g.mobs.duplicate()
	actors.append(g.player)
	for a: Dictionary in actors:
		if not a.has("sq"):
			continue
		var sq: Vector2 = a.sq
		var v: Vector2 = a.sqv
		v += (-sq * STIFFNESS - v * DAMPING) * dt
		a.sqv = v
		a.sq = sq + v * dt
	_update_trails()
	_update_sounds(dt)


## Keeps each hero shot's recent path for its streak; a shot that is gone bursts.
func _update_trails() -> void:
	var alive := {}
	for s: Dictionary in g.shots:
		if not s.has("fid"):
			s.fid = randi()
			on_shot(s.p, (s.v as Vector2).normalized(), str(s.get("kind", "")))
		alive[s.fid] = true
		var tr: Dictionary = _trails.get(s.fid, {"pts": [], "kind": str(s.get("kind", ""))})
		tr.pts.append(s.p)
		if tr.pts.size() > 6:
			tr.pts.pop_front()
		_trails[s.fid] = tr
	for key: int in _trails.keys():
		if not alive.has(key):
			var tr: Dictionary = _trails[key]
			on_shot_end(tr.pts[tr.pts.size() - 1], str(tr.kind))
			_trails.erase(key)


## Footsteps while the hero walks; now and then a growl of an enemy close by.
func _update_sounds(dt: float) -> void:
	if g.player.get("moving", false):
		_step -= dt
		if _step <= 0.0:
			_step = float(cfg.get("step_every", 0.3))
			g._sound_raw("step")
	else:
		_step = 0.0
	_idle -= dt
	if _idle > 0.0:
		return
	_idle = float(cfg.get("idle_gap", 1.6)) * randf_range(0.8, 1.6)
	var me := Vector2(g.player.x, g.player.y)
	for m: Dictionary in g.mobs:
		if m.spawn <= 0.0 and (m.p as Vector2).distance_to(me) < float(cfg.get("idle_range", 760.0)) and randf() < 0.5:
			var mat := str((m.def as Dictionary).get("material", "void"))
			g._sound_raw("idle_bone" if mat == "bone" else ("idle_flesh" if mat == "flesh" else "rattle_bone"))
			return


# ---------- drawing ----------

## Under the actors: stains on the floor.
func draw_under(l: CanvasItem) -> void:
	for s: Dictionary in _stains:
		l.draw_set_transform(s.p, 0.0, Vector2(1.0, 0.5))
		l.draw_circle(Vector2.ZERO, float(s.r), s.c)
		l.draw_set_transform(Vector2.ZERO)


## Over the actors: shot streaks and orbs, chips and the crypt effect sprites.
func draw_over(l: CanvasItem, t: float) -> void:
	for s: Dictionary in g.shots:
		var tr: Array = _trails.get(s.get("fid", -1), {}).get("pts", [])
		var kind := str(s.get("kind", ""))
		var crit := bool(s.get("crit", false))
		var tint := tint_of(kind, crit)
		if kind in ["arrow", "sub_hawk", ""] and tr.size() >= 2:
			var tail: Vector2 = s.p - (s.v as Vector2).normalized() * (104.0 if crit else 64.0) * _k() / 2.0
			l.draw_line(tail, s.p, Color(tint, 0.0), 2.0)
			for i in range(6):
				var a := float(i) / 6.0
				l.draw_line(tail.lerp(s.p, a), tail.lerp(s.p, a + 1.0 / 6.0), Color(tint, a * 0.8), 2.0 + a * 4.0)
		elif kind in ["magic", "fireball", "sub_soul"]:
			# the spell orb: a burning core, orbiting motes and a turning rune ring
			var r := 26.0
			l.draw_circle(s.p, r * 1.4, Color(tint, 0.18))
			for i in range(3):
				var a := t * 7.0 + i * TAU / 3.0
				l.draw_circle(s.p + Vector2(cos(a), sin(a)) * r, 4.5, Color(tint.lightened(0.3), 0.9))
			for i in range(4):
				var a0 := -t * 3.0 + i * TAU / 4.0
				l.draw_arc(s.p, r * 0.95, a0, a0 + 0.9, 6, Color(tint, 0.75), 2.5)
			if tr.size() >= 2:
				l.draw_line(tr[0], s.p, Color(tint, 0.3), 10.0)
	for b: Dictionary in _bits:
		var c: Color = b.c
		c.a = clampf(float(b.t) * 3.0, 0.0, 1.0)
		var s := float(b.s)
		l.draw_rect(Rect2((b.p as Vector2) - Vector2(s / 2.0, s / 2.0 + float(b.z)), Vector2(s, s)), c)
	sprites.draw(l)
