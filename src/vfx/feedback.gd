extends RefCounted
## Game-feel layer between host snapshots and the dungeon view. Watches the
## host's counters (hits, attacks, impacts, shots, hurts, level_ups, pickups) and
## dying state, and turns each change into one combined, timed reaction: hit
## flash, squash & stretch on a damped spring (overshoot gives follow-through),
## particles, stains, sound, screen shake and hitstop. Each boss move has its own
## anticipation, action and recovery pose plus continuous effects (dust, charge
## trail, beam sparks) emitted in update(). Owns no gameplay state; the host
## stays authoritative. Counters instead of one-shot events: a client that misses
## an unreliable snapshot still sees the counter move and reacts once.

const Particles = preload("res://src/vfx/particles.gd")

const BLOOD := {"chaser": Color("6fbf4f"), "shooter": Color("b4543f"), "boss": Color("9b4fd4"), "player": Color("d8484f"),
	"golem": Color("7fd9c4"), "molgrax": Color("ff6a2a"), "glutling": Color("d8402f"), "schattling": Color("8b4fd0"), "funkenball": Color("ff7a3c"),
	"blutqualle": Color("a8202f"), "stachelwaechter": Color("b8402f"), "leerenpriester": Color("8b4fd0"), "krabbenteufel": Color("c8402f"), "fackelteufel": Color("ff8a3c"), "imp": Color("d6503f"), "skelet": Color("e8e2d0"), "necromancer": Color("8b5fd0"), "tiny_zombie": Color("7fae4f"),
	"n_axe": Color("c8302f"), "n_hex": Color("9b4fd4"), "n_crab": Color("d8502f"), "n_wing": Color("ff6a3c")}
## Seconds a turn takes: the sprite narrows and widens again (heavier for bosses).
const TURN_TIME := 0.1
const BOSS_TURN_TIME := 0.22
const SPARK := Color("fff1c2")
const HIT_FLASH := Color("ff6a5c")
const DUST := Color("8e8496")
const FIRE := Color("ff7a3c")
const BEAM := Color("ff5a4a")
const EXP_GLOW := Color("5fe3c0")
const LEVEL_GOLD := Color("ffd76a")
const HEAL := Color("7be38a")
# Spring for squash & stretch: underdamped, so deformations overshoot once.
const STIFFNESS := 320.0
const DAMPING := 13.0
## Seconds the level-up pillar and text stay on screen.
const LEVEL_UP_TIME := 1.1
## Seconds a sword swing is drawn.
const SWING_TIME := 0.16
## Seconds a chest boost's text floats above the hero.
const BOOST_TIME := 1.6
## Boss sound and pose per move: [windup sound, active sound].
const MOVE_SOUNDS := {"volley": ["inflate", "enemy_shoot"], "rings": ["windup", "enemy_shoot"], "charge": ["roar", "dash"], "slam": ["windup", "jump"], "beam": ["charge", "beam"],
	"cleave": ["windup", "dash"], "barrage": ["windup", "enemy_shoot"], "quake": ["roar", "slam"], "axe": ["windup", "dash"],
	"boulder": ["inflate", "jump"], "channel": ["charge", "enemy_shoot"], "thorns": ["roar", "slam"],
	"swipe": ["windup", "dash"], "fireball": ["inflate", "enemy_shoot"], "eruption": ["roar", "slam"], "void": ["charge", "slam"], "inferno": ["roar", "slam"]}
## Creatures whose own frames show their death; the generic flatten is skipped.
const OWN_DEATH := ["golem", "molgrax", "glutling", "schattling", "funkenball", "blutqualle", "stachelwaechter", "leerenpriester", "krabbenteufel", "fackelteufel"]

var particles := Particles.new()
## Optional sound player with play(name); null in tests and headless runs.
var sfx: Node = null
## Screen-shake trauma 0..1; the view squares it for the offset.
var shake := 0.0
## Seconds left in which the view holds the current frame (hitstop).
var hitstop := 0.0
## Fading copies of a charging boss: {pos, face, life}.
var ghosts: Array[Dictionary] = []

var _actors: Dictionary = {}
var _room_id := ""
# Orb id -> last seen position, to burst where an orb was collected.
var _orbs: Dictionary = {}
# Hazard id -> last seen state, to burst once when a warning erupts.
var _hazards: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 3


## Compares a snapshot with the last one and fires the reactions for anything
## that changed. Safe to call every frame with the same snapshot.
func observe(snapshot: Dictionary, local_peer: int) -> void:
	var layout: Variant = snapshot.get("room_layout", {})
	var room_id: String = str(layout.get("id", "")) if layout is Dictionary else ""
	if room_id != _room_id:
		if not _room_id.is_empty() and not room_id.is_empty():
			_play("door")
		_room_id = room_id
		_actors.clear()
		_orbs.clear()
		_hazards.clear()
		ghosts.clear()
		particles.clear()
	var seen: Dictionary = {}
	for value: Variant in snapshot.get("enemies", []):
		var enemy: Dictionary = value
		var key := "e%d" % int(enemy.get("id", -1))
		seen[key] = true
		var state := _actor(key, enemy, "hits", "attacks")
		_observe_enemy(state, enemy)
		state.entity = enemy
	var players: Dictionary = snapshot.get("players", {})
	for peer: Variant in players:
		var key := "p%d" % int(peer)
		seen[key] = true
		var state := _actor(key, players[peer], "shots", "hurts")
		_observe_player(state, players[peer], int(peer) == local_peer)
		state.entity = players[peer]
	for key: String in _actors.keys():
		if not seen.has(key):
			_actors.erase(key)
	_observe_orbs(snapshot.get("orbs", []))
	_observe_hazards(snapshot.get("hazards", []))


## Advances springs, flashes, shake, particles and continuous move effects.
## Hitstop freezes all of it.
func update(delta: float) -> void:
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - delta)
		return
	shake = maxf(0.0, shake - delta * 1.8)
	particles.update(delta)
	for i in range(ghosts.size() - 1, -1, -1):
		ghosts[i].life = float(ghosts[i].life) - delta
		if ghosts[i].life <= 0.0: ghosts.remove_at(i)
	for state: Dictionary in _actors.values():
		var force: Vector2 = -state.squash * STIFFNESS - state.squash_vel * DAMPING
		state.squash_vel += force * delta
		state.squash += state.squash_vel * delta
		state.lean_vel += (-state.lean * STIFFNESS - state.lean_vel * DAMPING) * delta
		state.lean += state.lean_vel * delta
		state.flash = maxf(0.0, state.flash - delta)
		state.level_up = maxf(0.0, float(state.get("level_up", 0.0)) - delta)
		state.turn = maxf(0.0, float(state.get("turn", 0.0)) - delta)
		state.swing = maxf(0.0, float(state.get("swing", 0.0)) - delta)
		state.boost = maxf(0.0, float(state.get("boost", 0.0)) - delta)
		state.clock = float(state.get("clock", 0.0)) + delta
		var entity: Dictionary = state.get("entity", {})
		if bool(entity.get("boss", false)):
			_emit_boss(state, entity, delta)


## Deformation and overlays for one actor at time `clock`: scale, lean (radians),
## vertical offset, flash strength 0..1 with its colour, alpha, and `level_up`
## (0..1 while the level-up pillar shows).
func pose(key: String, entity: Dictionary, clock: float) -> Dictionary:
	var state: Dictionary = _actors.get(key, {})
	var scale := Vector2.ONE + Vector2(state.get("squash", Vector2.ZERO))
	var lean: float = float(state.get("lean", 0.0))
	var offset := Vector2.ZERO
	var alpha := 1.0
	var phase: float = float(absi(hash(key)) % 100) * 0.1
	var face: float = float(entity.get("face", 1.0))
	var dying: float = float(entity.get("dying_p", -1.0))
	var boss: bool = bool(entity.get("boss", false))
	var attack: String = str(entity.get("attack", ""))
	var p: float = float(entity.get("attack_p", 0.0))
	if dying >= 0.0 and str(entity.get("kind", "")) in OWN_DEATH:
		# The golem's own frames crumble it; only fade the rubble at the very end.
		alpha = 1.0 - smoothstep(0.85, 1.0, dying)
	elif dying >= 0.0:
		# Death: flatten and widen, tip over in the push direction, then fade.
		# The boss first shudders on its feet before it collapses.
		if boss and dying < 0.5:
			offset.x += roundf(sin(clock * 60.0) * 3.0 * (1.0 - dying))
			scale *= Vector2(1.0 + 0.1 * dying, 1.0 + 0.08 * dying)
		else:
			scale *= Vector2(1.0 + 0.55 * dying, 1.0 - 0.75 * dying)
		lean += signf(float(entity.get("dx", 0.0)) + 0.001) * 0.35 * dying
		alpha = 1.0 - smoothstep(0.55, 1.0, dying)
	elif boss and not attack.is_empty() and not str(entity.get("move", "")).is_empty() and str(entity.get("kind", "boss")) == "boss":
		var move_pose: Dictionary = _boss_pose(str(entity.move), attack, p, face, clock)
		scale *= Vector2(move_pose.scale)
		lean += float(move_pose.lean)
		offset += Vector2(move_pose.offset)
	elif boss and str(entity.get("kind", "")) in ["golem", "molgrax"]:
		# Their sheets animate every move; only the breath and kicks apply.
		pass
	elif boss and attack == "windup":
		# Bosses without move frames (the orc warlord): a heavy rise and lean back,
		# trembling more as the attack nears.
		var heave: float = ease(p, 0.5)
		scale *= Vector2(1.0 - 0.1 * heave, 1.0 + 0.16 * heave)
		lean -= face * 0.22 * heave
		offset.x += roundf(sin(clock * 60.0) * 2.0 * smoothstep(0.6, 1.0, p)) - face * 4.0 * heave
	elif boss and attack == "active":
		scale *= Vector2(1.18, 0.88)
		lean += face * 0.2
	elif attack == "windup":
		# Anticipation: rise up and lean back, growing until the shot.
		var charge: float = ease(p, 0.6)
		scale *= Vector2(1.0 - 0.16 * charge, 1.0 + 0.2 * charge)
		lean -= face * 0.16 * charge
		offset.x -= face * 2.0 * charge
	elif bool(entity.get("moving", false)):
		# Running: a light hop with a squash on each landing. The boss stomps:
		# slower, lower and heavier.
		var step: float = absf(sin(clock * (7.0 if boss else 13.0) + phase))
		offset.y -= roundf(step * (2.0 if boss else 3.0))
		var landing: float = (0.1 if boss else 0.06) * (1.0 - step)
		scale *= Vector2(1.0 + landing, 1.0 - landing)
	else:
		# Idle breathing keeps standing actors alive; the boss breathes deep and slow.
		var breath: float = sin(clock * (2.0 if boss else 3.2) + phase)
		scale *= Vector2(1.0 - (0.04 if boss else 0.03) * breath, 1.0 + (0.06 if boss else 0.04) * breath)
	# Turning: the body narrows to a sliver and widens facing the new way.
	var turn: float = float(state.get("turn", 0.0))
	if turn > 0.0:
		var length: float = BOSS_TURN_TIME if boss else TURN_TIME
		scale.x *= lerpf(0.15, 1.0, smoothstep(0.0, 1.0, 1.0 - turn / length))
	var flash: float = float(state.get("flash", 0.0))
	return {"scale": scale, "lean": lean, "offset": offset, "alpha": alpha,
		"flash": clampf(flash / maxf(float(state.get("flash_length", 0.1)), 0.001), 0.0, 1.0) * float(state.get("flash_strength", 1.0)),
		"flash_color": state.get("flash_color", Color.WHITE),
		"level_up": float(state.get("level_up", 0.0)) / LEVEL_UP_TIME,
		"swing": float(state.get("swing", 0.0)) / SWING_TIME,
		"boost": float(state.get("boost", 0.0)) / BOOST_TIME}


## The boss's body for each move and phase. `p` runs 0 → 1 through the phase.
## Anticipation always reads the move: the volley inflates, the rings crouch and
## tremble, the charge rears back, the jump squats deep, the beam rises and shakes.
func _boss_pose(move: String, attack: String, p: float, face: float, clock: float) -> Dictionary:
	var scale := Vector2.ONE
	var lean := 0.0
	var offset := Vector2.ZERO
	var charge: float = ease(p, 0.5)
	match move + ":" + attack:
		"volley:windup":
			# Breathes in: swells, leans back, the cheeks tremble at the end.
			scale = Vector2(1.0 + 0.14 * charge, 1.0 + 0.18 * charge)
			lean = -face * 0.12 * charge
			offset.x = roundf(sin(clock * 55.0) * 1.5 * smoothstep(0.6, 1.0, p))
		"volley:active":
			scale = Vector2(1.12 - 0.12 * p, 0.9 + 0.1 * p)
			lean = face * 0.1 * (1.0 - p)
		"rings:windup":
			scale = Vector2(1.0 + 0.2 * charge, 1.0 - 0.18 * charge)
			offset.x = roundf(sin(clock * 70.0) * 2.5 * charge)
		"rings:active":
			scale = Vector2(0.9 + 0.1 * p, 1.16 - 0.16 * p)
		"charge:windup":
			# Rears back away from the target and paws the ground.
			scale = Vector2(1.0 - 0.08 * charge, 1.0 + 0.12 * charge)
			lean = -face * 0.3 * charge
			offset.x = -face * 7.0 * charge
			offset.y = -roundf(absf(sin(clock * 18.0)) * 2.0 * charge)
		"charge:active":
			scale = Vector2(1.28, 0.84)
			lean = face * 0.22
			offset.y = -roundf(absf(sin(clock * 30.0)) * 3.0)
		"charge:recovery":
			# Dazed after the crash: a slow wobble that dies away.
			lean = sin(clock * 9.0) * 0.2 * (1.0 - p)
			scale = Vector2(1.0 + 0.06 * (1.0 - p), 1.0 - 0.06 * (1.0 - p))
		"slam:windup":
			scale = Vector2(1.0 + 0.34 * charge, 1.0 - 0.36 * charge)
			offset.x = roundf(sin(clock * 50.0) * 1.5 * smoothstep(0.7, 1.0, p))
		"slam:active":
			# Leaves the ground stretched thin, tucks at the top, stretches again to land.
			var height: float = sin(PI * p)
			offset.y = -roundf(height * 150.0)
			var stretch: float = absf(cos(PI * p))
			scale = Vector2(1.0 - 0.2 * stretch, 1.0 + 0.3 * stretch)
		"slam:recovery":
			scale = Vector2(1.0 + 0.1 * (1.0 - p), 1.0 - 0.1 * (1.0 - p))
		"beam:windup":
			# Rises and gathers power; the shaking grows until the beam fires.
			scale = Vector2(1.0 - 0.08 * charge, 1.0 + 0.16 * charge)
			offset = Vector2(roundf(sin(clock * 80.0) * 3.0 * charge), -roundf(8.0 * charge))
		"beam:active":
			# Held back by the recoil, pulsing with the beam.
			scale = Vector2(1.04 + 0.04 * sin(clock * 40.0), 1.08)
			lean = -face * 0.12
			offset = Vector2(-face * 3.0 + roundf(sin(clock * 90.0)), -8.0)
		"beam:recovery":
			# Spent: slumps and pants.
			var tired: float = 1.0 - p
			scale = Vector2(1.0 + 0.12 * tired, 1.0 - 0.14 * tired + 0.03 * sin(clock * 12.0) * tired)
	return {"scale": scale, "lean": lean, "offset": offset}


func _actor(key: String, entity: Dictionary, first_counter: String, second_counter: String) -> Dictionary:
	if not _actors.has(key):
		# A new actor starts from its current counters, so joining mid-fight or
		# entering a room never replays old hits.
		_actors[key] = {"squash": Vector2.ZERO, "squash_vel": Vector2.ZERO, "lean": 0.0, "lean_vel": 0.0,
			"flash": 0.0, "flash_length": 0.1, "flash_color": Color.WHITE, "attack": str(entity.get("attack", "")),
			first_counter: int(entity.get(first_counter, 0)), second_counter: int(entity.get(second_counter, 0)),
			"impacts": int(entity.get("impacts", 0)), "level_ups": int(entity.get("level_ups", 0)),
			"pickups": int(entity.get("pickups", 0)), "hp": int(entity.get("hp", 0)), "swings": int(entity.get("swings", 0)), "shield_breaks": int(entity.get("shield_breaks", 0)), "boosts": int(entity.get("boosts", 0)),
			"dying": float(entity.get("dying_p", -1.0)) >= 0.0, "emit": 0.0}
	return _actors[key]


func _observe_enemy(state: Dictionary, enemy: Dictionary) -> void:
	var kind: String = str(enemy.get("kind", "chaser"))
	var boss: bool = bool(enemy.get("boss", false))
	var face: float = float(enemy.get("face", -1.0))
	if state.has("face") and signf(face) != signf(float(state.face)):
		state.turn = BOSS_TURN_TIME if boss else TURN_TIME
	state.face = face
	var origin := Vector2(float(enemy.get("x", 0.0)), float(enemy.get("y", 0.0)))
	var direction := Vector2(float(enemy.get("dx", 0.0)), float(enemy.get("dy", 0.0)))
	var blood: Color = BLOOD.get(kind, BLOOD.chaser)
	var hits := int(enemy.get("hits", 0))
	var dying: bool = float(enemy.get("dying_p", -1.0)) >= 0.0
	if dying and not state.dying:
		# Killing blow: everything at once, strongest on the boss.
		state.dying = true
		state.hits = hits
		_flash(state, Color.WHITE, 0.14)
		_kick(state, Vector2(0.45, -0.4) * (0.5 if boss else 1.0), direction.x * 0.5)
		particles.burst(origin, blood, 70 if boss else 24, 260.0 if boss else 190.0, 0.9 if boss else 0.6, direction, 1.3, 4.0 if boss else 3.0)
		particles.burst(origin, DUST, 30 if boss else 10, 120.0, 0.7, Vector2.ZERO, PI, 4.0, 3.0)
		particles.stain(origin + Vector2(0, 12), blood, 34.0 if boss else 16.0)
		_play("boss_kill" if boss else "kill")
		_add_shake(0.95 if boss else 0.32)
		hitstop = maxf(hitstop, 0.18 if boss else 0.07)
	elif hits > int(state.hits):
		state.hits = hits
		# Ordinary hits flash red and short; only the killing blow goes full white.
		# Bosses take a stream of shots, so their flash is weaker to stay readable.
		if boss:
			_flash(state, HIT_FLASH, 0.06, 0.5)
		else:
			_flash(state, HIT_FLASH, 0.08, 0.85)
		_kick(state, Vector2(0.14, -0.12) if boss else Vector2(0.34, -0.3), direction.x * (0.1 if boss else 0.3))
		particles.burst(origin - direction * 6.0, SPARK, 6, 170.0, 0.22, -direction, 0.7, 2.0, 8.0)
		particles.burst(origin, blood, 6 if boss else 4, 130.0, 0.45, direction, 0.6, 3.0)
		_play("boss_hit" if boss else "hit")
		# No hitstop on ordinary boss hits: under sustained fire it would freeze
		# the picture several times a second. Hitstop is kept for kills and hurts.
		_add_shake(0.14 if boss else 0.08)
	var move := str(enemy.get("move", ""))
	var healed := int(enemy.get("healed", 0))
	if healed > int(state.get("healed", healed)):
		particles.burst(origin + Vector2(0, -10), Color("7be38a"), 12, 90.0, 0.6, Vector2.UP, 0.8, 2.0, 2.0)
		_flash(state, Color("7be38a"), 0.2, 0.6)
	state.healed = healed
	var blocks := int(enemy.get("blocks", 0))
	if blocks > int(state.get("blocks", blocks)):
		# A shot bounces off the shield: sparks and a metallic tick.
		particles.burst(origin + Vector2(float(enemy.get("face", -1.0)) * 12.0, -6), SPARK, 8, 180.0, 0.2, Vector2(float(enemy.get("face", -1.0)), -0.2), 0.8, 2.0, 8.0)
		_kick(state, Vector2(0.08, -0.06), -float(enemy.get("face", -1.0)) * 0.1)
		_play("pickup", 0.3)
	state.blocks = blocks
	var attacks := int(enemy.get("attacks", 0))
	if attacks > int(state.get("attacks", 0)):
		# Active frame: snap forward out of the windup and overshoot back.
		state.attacks = attacks
		if boss:
			_boss_release(state, enemy, move, origin)
		else:
			_kick(state, Vector2(0.32, -0.28), float(enemy.get("face", 1.0)) * 0.35)
			particles.burst(origin, Color("f19791"), 7, 150.0, 0.3, Vector2.ZERO, PI, 2.0, 7.0)
			_play("enemy_shoot", 0.12)
	var impacts := int(enemy.get("impacts", 0))
	if impacts > int(state.get("impacts", 0)):
		# Landing or wall crash: the heaviest moment of the fight.
		state.impacts = impacts
		_kick(state, Vector2(0.5, -0.45), 0.0)
		particles.burst(origin + Vector2(0, 18), DUST, 46, 300.0, 0.7, Vector2.ZERO, PI, 4.0, 4.0)
		particles.burst(origin + Vector2(0, 18), Color("5a4e5e"), 18, 200.0, 0.9, Vector2.UP, 1.2, 4.0, 3.0)
		particles.stain(origin + Vector2(0, 20), Color("2a2433"), 30.0)
		_play("slam")
		_add_shake(0.75)
		hitstop = maxf(hitstop, 0.06)
	var attack := str(enemy.get("attack", ""))
	if attack == "windup" and state.attack != "windup":
		_play(MOVE_SOUNDS.get(move, ["windup"])[0] if boss else "windup", 0.05)
	state.attack = attack


## The boss's active frame differs per move: a muzzle blast for shots, a dust
## kick for the charge, a launch puff for the jump, a flash for the beam.
func _boss_release(state: Dictionary, enemy: Dictionary, move: String, origin: Vector2) -> void:
	var face: float = float(enemy.get("face", 1.0))
	var mouth := Vector2(float(enemy.get("ox", origin.x)), float(enemy.get("oy", origin.y - 22.0)))
	_play(MOVE_SOUNDS.get(move, ["", "enemy_shoot"])[1], 0.08)
	match move:
		"volley":
			_kick(state, Vector2(0.3, -0.26), face * 0.3)
			var aim := Vector2(float(enemy.get("aim_x", face)), float(enemy.get("aim_y", 0.0)))
			particles.burst(mouth, FIRE, 18, 220.0, 0.35, aim, 0.5, 3.0, 6.0)
			_add_shake(0.22)
		"rings":
			_kick(state, Vector2(-0.18, 0.28), 0.0)
			particles.burst(origin, Color("f19791"), 22, 200.0, 0.4, Vector2.ZERO, PI, 3.0, 5.0)
			_add_shake(0.25)
		"charge":
			_kick(state, Vector2(0.25, -0.2), face * 0.3)
			particles.burst(origin + Vector2(0, 18), DUST, 20, 180.0, 0.5, Vector2(-face, -0.3), 0.6, 4.0, 4.0)
			_add_shake(0.3)
		"slam":
			_kick(state, Vector2(-0.25, 0.35), 0.0)
			particles.burst(origin + Vector2(0, 18), DUST, 24, 160.0, 0.5, Vector2.ZERO, PI, 3.0, 5.0)
			_add_shake(0.2)
		"cleave":
			_kick(state, Vector2(0.28, -0.24), face * 0.25)
			var aim := Vector2(float(enemy.get("aim_x", face)), float(enemy.get("aim_y", 0.0)))
			particles.burst(origin + aim * 40.0, Color("7fe8e0"), 24, 240.0, 0.35, aim, 0.9, 3.0, 6.0)
			_add_shake(0.4)
			hitstop = maxf(hitstop, 0.05)
		"quake", "thorns", "slam", "eruption", "inferno", "void":
			_kick(state, Vector2(0.35, -0.3), 0.0)
			particles.burst(origin + Vector2(0, 24), DUST, 30, 220.0, 0.6, Vector2.ZERO, PI, 4.0, 4.0)
			_add_shake(0.45)
		"warcry":
			_kick(state, Vector2(-0.2, 0.3), 0.0)
			particles.burst(origin + Vector2(0, -30), Color("ffd76a"), 26, 220.0, 0.5, Vector2.ZERO, PI, 3.0, 5.0)
			_add_shake(0.35)
		"swipe":
			_kick(state, Vector2(0.28, -0.24), face * 0.25)
			particles.burst(origin + Vector2(face * 40.0, -10), Color("ff8a3c"), 26, 240.0, 0.35, Vector2(face, 0), 0.9, 3.0, 6.0)
			_add_shake(0.4)
			hitstop = maxf(hitstop, 0.05)
		"barrage", "boulder", "axe", "channel", "fireball", "charge":
			_kick(state, Vector2(0.2, -0.18), face * 0.2)
			particles.burst(origin + Vector2(face * 24.0, -14), Color("a9e4a0") if move == "channel" else DUST, 10, 160.0, 0.35, Vector2(face, -0.3), 0.8, 3.0, 5.0)
			_add_shake(0.18)
		"beam":
			_flash(state, Color("ffd2a0"), 0.18, 0.8)
			particles.burst(mouth, Color.WHITE, 30, 260.0, 0.35, Vector2.ZERO, PI, 3.0, 6.0)
			_add_shake(0.6)
			hitstop = maxf(hitstop, 0.05)


## Continuous effects of the boss's current move, frame-rate independent.
func _emit_boss(state: Dictionary, entity: Dictionary, delta: float) -> void:
	var origin := Vector2(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)))
	var face: float = float(entity.get("face", 1.0))
	var p: float = float(entity.get("attack_p", 0.0))
	var dying: float = float(entity.get("dying_p", -1.0))
	var rate := 0.0
	var key := str(entity.get("move", "")) + ":" + str(entity.get("attack", ""))
	if dying >= 0.0:
		key = "dying"
	match key:
		"volley:windup": rate = 26.0 * p
		"charge:windup": rate = 16.0
		"charge:active": rate = 40.0
		"beam:windup":
			rate = 45.0
			shake = maxf(shake, 0.25 * p)
		"beam:active":
			rate = 70.0
			shake = maxf(shake, 0.32)
		"dying": rate = 6.0 * (1.0 - dying)
		_: return
	state.emit = float(state.emit) + rate * delta
	var mouth := Vector2(float(entity.get("ox", origin.x)), float(entity.get("oy", origin.y - 22.0)))
	while state.emit >= 1.0:
		state.emit -= 1.0
		match key:
			"volley:windup":
				# Embers gather in the mouth.
				particles.implode(mouth, FIRE, 1, 26.0, 0.25)
			"charge:windup":
				particles.burst(origin + Vector2(-face * 14.0, 20), DUST, 2, 90.0, 0.4, Vector2(-face, -0.6), 0.5, 3.0, 4.0)
			"charge:active":
				particles.burst(origin + Vector2(0, 18), DUST, 2, 60.0, 0.45, Vector2(-face, -0.2), 0.8, 4.0, 3.0)
				ghosts.append({"pos": origin, "face": face, "life": 0.22})
			"beam:windup":
				particles.implode(mouth, Color("ffb070"), 2, _rng.randf_range(60.0, 110.0), 0.4)
			"beam:active":
				var end := Vector2(float(entity.get("bx", mouth.x)), float(entity.get("by", mouth.y)))
				var back: Vector2 = (mouth - end).normalized()
				particles.burst(end, SPARK, 2, 240.0, 0.3, back, 1.1, 3.0, 5.0)
				particles.burst(end, BEAM, 1, 120.0, 0.4, back, 1.4, 4.0, 4.0)
			"dying":
				# The boss bursts apart in several pops before it falls.
				var spot: Vector2 = origin + Vector2(_rng.randf_range(-22.0, 22.0), _rng.randf_range(-50.0, 0.0))
				particles.burst(spot, BLOOD.boss, 14, 200.0, 0.5, Vector2.ZERO, PI, 3.0, 4.0)
				particles.burst(spot, SPARK, 6, 160.0, 0.25, Vector2.ZERO, PI, 2.0, 6.0)
				_play("boss_hit", 0.2)
				_add_shake(0.3)


func _observe_player(state: Dictionary, player: Dictionary, local: bool) -> void:
	var origin := Vector2(float(player.get("x", 0.0)), float(player.get("y", 0.0)))
	# A new run recreates players with counters at 0 (and a fixed seed can keep the
	# same room id); a counter that went backwards is a reset, not an event.
	for counter: String in ["shots", "hurts", "level_ups", "pickups", "swings", "shield_breaks", "boosts"]:
		if int(player.get(counter, 0)) < int(state.get(counter, 0)): state[counter] = int(player.get(counter, 0))
	var shots := int(player.get("shots", 0))
	if shots > int(state.shots):
		state.shots = shots
		# Recoil: a quick squash against the shot, settling with a small wobble.
		var aim := Vector2(float(player.get("ax", 1.0)), float(player.get("ay", 0.0)))
		_kick(state, Vector2(0.12, -0.1), -aim.x * 0.12)
		if local:
			_play("shoot", 0.1)
	var swings := int(player.get("swings", 0))
	if swings > int(state.get("swings", 0)):
		# Sword swing: a quick lunge, a whoosh and sparks along the blade's path.
		state.swings = swings
		state.swing = SWING_TIME
		var angle: float = float(player.get("swing_a", 0.0))
		_kick(state, Vector2(0.16, -0.12), cos(angle) * 0.25)
		particles.burst(origin + Vector2.RIGHT.rotated(angle) * float(player.get("reach", 50.0)) * 0.7, Color("dff6ff"), 6, 140.0, 0.2, Vector2.RIGHT.rotated(angle), 0.9, 2.0, 8.0)
		_play("swing", 0.12)
	var boosts := int(player.get("boosts", 0))
	if boosts > int(state.get("boosts", 0)):
		# A chest boost: golden sparks and the stat floating up (drawn by the view).
		state.boosts = boosts
		state.boost = BOOST_TIME
		particles.burst(origin + Vector2(0, -10), LEVEL_GOLD, 18, 160.0, 0.6, Vector2.UP, 0.9, 2.0, 3.0)
		_play("heal" if local else "pickup", 0.0)
	var breaks := int(player.get("shield_breaks", 0))
	if breaks > int(state.get("shield_breaks", 0)):
		state.shield_breaks = breaks
		particles.burst(origin, Color("8fd8ff"), 24, 200.0, 0.4, Vector2.ZERO, PI, 3.0, 5.0)
		_play("shield", 0.0)
	var hurts := int(player.get("hurts", 0))
	if hurts > int(state.hurts):
		state.hurts = hurts
		_flash(state, Color("ff4a4a"), 0.18)
		_kick(state, Vector2(0.3, -0.32), 0.0)
		particles.burst(origin, BLOOD.player, 10, 160.0, 0.5, Vector2.ZERO, PI, 3.0)
		_play("hurt", 0.05)
		_add_shake(0.5 if local else 0.15)
		hitstop = maxf(hitstop, 0.05 if local else 0.0)
	var pickups := int(player.get("pickups", 0))
	if pickups > int(state.pickups):
		state.pickups = pickups
		particles.burst(origin + Vector2(0, -8), EXP_GLOW, 5, 90.0, 0.3, Vector2.UP, 1.2, 2.0, 5.0)
		if local:
			_play("pickup", 0.15)
	var level_ups := int(player.get("level_ups", 0))
	if level_ups > int(state.level_ups):
		state.level_ups = level_ups
		state.level_up = LEVEL_UP_TIME
		_flash(state, LEVEL_GOLD, 0.3, 0.9)
		_kick(state, Vector2(-0.25, 0.35), 0.0)
		particles.burst(origin, LEVEL_GOLD, 36, 230.0, 0.8, Vector2.UP, 0.9, 3.0, 3.0)
		particles.burst(origin + Vector2(0, 14), Color.WHITE, 20, 200.0, 0.5, Vector2.ZERO, PI, 2.0, 6.0)
		_play("level_up", 0.0)
		_add_shake(0.25 if local else 0.0)
	var hp := int(player.get("hp", 0))
	if hp > int(state.hp) and int(state.hp) > 0:
		# Healing: a soft green glow and rising sparks.
		_flash(state, HEAL, 0.25, 0.6)
		particles.burst(origin + Vector2(0, -6), HEAL, 10, 80.0, 0.6, Vector2.UP, 0.8, 2.0, 2.0)
		if local:
			_play("heal", 0.0)
	state.hp = hp


## A warning that turned into a burst erupts once: dust, sparks, shake, sound.
func _observe_hazards(hazards: Array) -> void:
	var current: Dictionary = {}
	for value: Variant in hazards:
		var hazard: Dictionary = value
		var id := int(hazard.get("id", -1))
		var state := str(hazard.get("s", ""))
		current[id] = state
		if state == "burst" and str(_hazards.get(id, "")) != "burst":
			var point := Vector2(float(hazard.get("x", 0.0)), float(hazard.get("y", 0.0)))
			var kind := str(hazard.get("k", ""))
			var colors := {"trap": Color("c8a87a"), "quake": Color("7fe8e0"), "fire": Color("ff8a3c"), "lava": Color("ff6a2a"), "flame": Color("ff9a3c"), "blood": Color("d8484f"), "spike": Color("b8a89a"), "void": Color("a77be8")}
			var color: Color = colors.get(kind, Color("9be05a"))
			particles.burst(point, color, 16 if kind == "blast" else 8, 200.0, 0.4, Vector2.UP, 1.2, 3.0, 5.0)
			particles.burst(point + Vector2(0, 6), DUST, 6, 120.0, 0.5, Vector2.ZERO, PI, 3.0, 4.0)
			if kind == "blast":
				particles.stain(point + Vector2(0, 6), Color("3f6a2a"), 26.0)
				_add_shake(0.5)
				_play("slam", 0.1)
			else:
				_add_shake(0.12)
				_play("hit", 0.2)
	_hazards = current


## Orbs that vanished while the room stayed the same were collected: a small
## burst where they were. New orbs are remembered from their first sighting.
func _observe_orbs(orbs: Array) -> void:
	var current: Dictionary = {}
	for value: Variant in orbs:
		var orb: Dictionary = value
		current[int(orb.get("id", -1))] = Vector2(float(orb.get("x", 0.0)), float(orb.get("y", 0.0)))
	for id: int in _orbs:
		if not current.has(id):
			particles.burst(_orbs[id], EXP_GLOW, 6, 120.0, 0.25, Vector2.ZERO, PI, 2.0, 6.0)
	_orbs = current


func _flash(state: Dictionary, color: Color, seconds: float, strength: float = 1.0) -> void:
	state.flash = seconds
	state.flash_length = seconds
	state.flash_color = color
	state.flash_strength = strength


## Sets an instant deformation the spring then releases (with overshoot).
## Restarting a kick mid-wobble replaces it, so rapid hits never stack up.
func _kick(state: Dictionary, squash: Vector2, lean: float) -> void:
	state.squash = squash
	state.squash_vel = Vector2.ZERO
	state.lean = lean
	state.lean_vel = 0.0


func _add_shake(amount: float) -> void:
	shake = minf(1.0, shake + amount)


func _play(name: String, spread: float = 0.08) -> void:
	if sfx != null and not name.is_empty():
		sfx.play(name, spread)
