extends RefCounted
## The Frostgruft's enemies as the crypt's part rigs (assets/data/rigs.json, cut
## by tools/frost_dungeon/export_frost_rigs.js), drawn by the crypt's rig
## renderer (src/rig/rig_renderer.gd) so they move like the crypt's and the
## Hell's figures: legs walk, heads bob, weapons and shields swing, a slime
## wobbles and hops, a whirl swirls, a hit knocks them back, and a felled one
## falls apart or melts. theme.rigs says which rig a look's sprite draws with;
## a look without one keeps its sprite. Purely visual: the frost world's rules,
## hit boxes and moves stay as they are (src/hell/hell_game.gd, frost_moves.gd,
## boss_kit.gd); this only reads them.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
## How long a boss kit attack shows its strike and recovery (s): kit attacks fire at once.
const KIT_CLIP := 0.6
## How long a shooter shows its release after a shot (s).
const SHOT_CLIP := 0.4
## Below this speed (world px/s) a figure stands.
const WALK_SPEED := 20.0
## Clip kinds of the frost moves (combat_boss_moves.json "type") and the kit attacks ("do").
const MOVE_KINDS := {"strikes": "slam", "lob": "slam", "bullets": "attack", "dash": "dash", "blink": "attack", "vortex": "roar",
	"cone": "attack", "spin": "roar", "summon": "summon", "armor": "roar"}
const KIT_KINDS := {"summon": "summon", "ring": "ring", "fan": "attack", "fist": "attack", "fist_hunt": "summon", "icicles": "slam",
	"chill_zones": "roar", "stomp": "slam", "breath": "attack", "spiral": "roar", "charge": "dash", "teleport_center": "roar", "last_stand": "roar"}

var g: Node
var renderer: RigRenderer
var library: RefCounted
## Look sprite -> rig name (theme.rigs).
var map: Dictionary = {}
var _next_uid := 1
var _snapshot: Dictionary = {"enemies": []}


## game: the frost world (src/hell/hell_game.gd); rigs: theme.rigs.
func _init(game: Node, rigs: Dictionary) -> void:
	g = game
	library = RigLibrary.shared()
	renderer = RigRenderer.new(library)
	map = rigs


## Forgets every figure, its debris and effects (a new floor, a new run).
func reset() -> void:
	renderer.reset()
	_snapshot = {"enemies": []}


## The rig monster `m` draws with now (its look's sprite in theme.rigs), "" when none.
func rig_of(m: Dictionary) -> String:
	var look: Variant = m.get("look")
	if not look is Dictionary:
		return ""
	var name := str(map.get(str((look as Dictionary).get("sprite", "")), ""))
	if name.is_empty() or library.rig(name).is_empty():
		return ""
	return name


## Once per update after the monsters moved: what every figure does now
## (walking, its move's windup, strike and recovery, a hit, its fall) goes to
## the renderer, whose clocks, clips and debris then advance.
func frame(dt: float) -> void:
	if not renderer.is_ready():
		return
	var enemies: Array = []
	var seen := {}
	for m: Dictionary in g.mobs:
		var e := _entry(m, dt)
		if not e.is_empty():
			enemies.append(e)
			seen[int(e.uid)] = true
	if g.feel != null:
		for m: Dictionary in g.feel.fallen():
			if seen.has(int(m.get("rig_uid", -1))):
				continue
			var e := _entry(m, dt)
			if not e.is_empty():
				enemies.append(e)
	_snapshot = {"enemies": enemies}
	renderer.observe(_snapshot)
	renderer.step(dt)


## Draws `m` by its rig with its feet at `feet`, `size` x its rig scale (the
## look's scale while it grows in), `tint` (rgb multiplier, alpha fades it)
## and the crypt feel's `pose` (its hit flash). False when `m` has no rig
## (the caller draws the sprite); true when the rig owns it, also while a
## felled figure lies in pieces and nothing of it is drawn.
func draw(l: CanvasItem, m: Dictionary, feet: Vector2, size: float, tint: Color, pose: Dictionary) -> bool:
	if not renderer.is_ready():
		return false
	var name := rig_of(m)
	if name.is_empty() or not m.has("rig_e"):
		return false
	var rig: Dictionary = library.rig(name)
	var e: Dictionary = (m.rig_e as Dictionary).duplicate()
	e.tint = Color(tint.r, tint.g, tint.b, 1.0)
	e.alpha = tint.a
	e.size = size
	e.hit_flash = float(pose.get("flash", 0.0)) * 0.16
	var S := float(rig.scale) * size
	renderer.draw_enemy(l, e, feet - Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * S))
	return true


## Severed or shed pieces lying on the floor (under the actors).
func draw_under(l: CanvasItem) -> void:
	renderer.draw_under(l)


## Chips and flashes of the figures (over the actors).
func draw_over(l: CanvasItem) -> void:
	renderer.draw_over(l, _snapshot)


## The renderer's view of `m` this frame (also kept on m.rig_e for draw), {} without a rig.
func _entry(m: Dictionary, dt: float) -> Dictionary:
	var name := rig_of(m)
	if name.is_empty():
		return {}
	if not m.has("rig_uid"):
		m.rig_uid = _next_uid
		_next_uid += 1
	var p: Vector2 = m.p
	var last: Vector2 = m.get("rig_last", p)
	m.rig_last = p
	var speed := p.distance_to(last) / maxf(dt, 0.001)
	var face: Vector2 = m.get("face", Vector2.RIGHT)
	var e := {"rig": name, "uid": int(m.rig_uid), "x": p.x, "y": p.y, "face": -1.0 if face.x < 0.0 else 1.0,
		"moving": speed > WALK_SPEED, "hits": int(m.get("feel_hits", 0))}
	var act := _act(m, dt)
	if not act.is_empty():
		e.attack = act.phase
		e.attack_kind = act.kind
		e.attack_p = act.p
	# the feel keeps its view of every monster on m.feel_e; a felled one carries its fall there (dying_p 0..1)
	var dying := float((m.get("feel_e", {}) as Dictionary).get("dying_p", -1.0))
	if dying >= 0.0:
		e.dying_p = dying
	m.rig_e = e
	return e


## What `m` is doing as an attack clip: {phase windup|active|recovery, kind, p 0..1}, {} when nothing.
func _act(m: Dictionary, dt: float) -> Dictionary:
	# a frost move (frost_moves.gd): its own windup, active and recovery
	var run: Variant = (m.get("mv", {}) as Dictionary).get("run", {}) if m.get("mv") is Dictionary else {}
	if run is Dictionary and not (run as Dictionary).is_empty():
		var phase := str(run.phase)
		if str(m.get("rig_phase", "")) != phase:
			m.rig_phase = phase
			m.rig_len = maxf(0.05, float(run.t))
		var kind := str(MOVE_KINDS.get(str((run.spec as Dictionary).get("type", "")), "attack"))
		return {"phase": phase, "kind": kind, "p": clampf(1.0 - float(run.t) / float(m.rig_len), 0.0, 1.0)}
	m.rig_phase = ""
	# a boss kit attack (boss_kit.gd): a timed one runs while m.busy holds it, the others fire at once
	if m.has("kit"):
		var busy: Dictionary = m.get("busy", {})
		if not busy.is_empty():
			return {"phase": "active", "kind": str(KIT_KINDS.get(str(busy.get("do", "")), "attack")), "p": 0.5}
		if int(m.get("atk_i", 0)) != int(m.get("rig_atk_i", m.get("atk_i", 0))):
			var attacks: Array = ((m.kit as Dictionary).phases[int(m.get("phase", 0))] as Dictionary).get("attacks", [])
			var done: Dictionary = attacks[(int(m.atk_i) - 1) % attacks.size()] if not attacks.is_empty() else {}
			m.rig_kit = {"t": 0.0, "kind": str(KIT_KINDS.get(str(done.get("do", "")), "attack"))}
		m.rig_atk_i = int(m.get("atk_i", 0))
		return _clip(m, "rig_kit", dt, KIT_CLIP)
	# a shooter's shot: its timer jumps back up when it fires
	var shoot := float(m.get("shoot", 0.0))
	if shoot > float(m.get("rig_shoot", shoot)) + 0.2:
		m.rig_shot = {"t": 0.0, "kind": "attack"}
	m.rig_shoot = shoot
	if m.has("rig_shot"):
		return _clip(m, "rig_shot", dt, SHOT_CLIP)
	# a dash (Frostkobold): the lunge held while it flies
	if float(m.get("dash", 0.0)) > 0.0:
		return {"phase": "active", "kind": "dash", "p": 0.6}
	return {}


## A clip started on m[key] ({t, kind}) running `length` s: the strike in its first quarter, then the recovery.
func _clip(m: Dictionary, key: String, dt: float, length: float) -> Dictionary:
	if not m.has(key):
		return {}
	var c: Dictionary = m[key]
	c.t = float(c.t) + dt
	if float(c.t) >= length:
		m.erase(key)
		return {}
	var k := float(c.t) / length
	if k < 0.25:
		return {"phase": "active", "kind": c.kind, "p": k / 0.25}
	return {"phase": "recovery", "kind": c.kind, "p": (k - 0.25) / 0.75}
