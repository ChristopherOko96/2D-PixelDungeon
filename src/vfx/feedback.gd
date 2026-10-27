extends RefCounted
## Game-feel layer between host snapshots and the dungeon view. Watches the
## host's counters (hits, attacks, shots, hurts) and dying state, and turns each
## change into one combined, timed reaction: hit flash, squash & stretch on a
## damped spring (overshoot gives follow-through), particles, stains, sound,
## screen shake and hitstop. Owns no gameplay state; the host stays authoritative.
## Counters instead of one-shot events: a client that misses an unreliable
## snapshot still sees the counter move and reacts once.

const Particles = preload("res://src/vfx/particles.gd")

const BLOOD := {"chaser": Color("6fbf4f"), "shooter": Color("b4543f"), "boss": Color("9b4fd4"), "player": Color("d8484f"),"skeleton_archer":Color("c5b68c"),"skeleton_guard":Color("c5b68c"),"necromancer":Color("786c8a")}
const SPARK := Color("fff1c2")
const HIT_FLASH := Color("ff6a5c")
const DUST := Color("8e8496")
# Spring for squash & stretch: underdamped, so deformations overshoot once.
const STIFFNESS := 320.0
const DAMPING := 13.0

var particles := Particles.new()
## Optional sound player with play(name); null in tests and headless runs.
var sfx: Node = null
## Screen-shake trauma 0..1; the view squares it for the offset.
var shake := 0.0
## Seconds left in which the view holds the current frame (hitstop).
var hitstop := 0.0

var _actors: Dictionary = {}
var _room_id := ""
## Sound flow (assets/data/audio_sfx.json): room phase, one boss sting per room,
## fx/perk events played once, the local hero's footsteps.
const STEP_INTERVAL := 0.3
var _phase := ""
var _boss_announced := false
var _fx_seen: Dictionary = {}
var _blasts: Dictionary = {}
var _local_moving := false
var _step_timer := 0.0
var _clock := 0.0


## Compares a snapshot with the last one and fires the reactions for anything
## that changed. Safe to call every frame with the same snapshot.
func observe(snapshot: Dictionary, local_peer: int) -> void:
	var layout: Variant = snapshot.get("room_layout", {})
	var room_id: String = str(layout.get("id", "")) if layout is Dictionary else ""
	if not room_id.is_empty():
		room_id = "%s:%s:%s:%s" % [snapshot.get("run_seed",0),snapshot.get("floor_index",0),room_id,snapshot.get("room_layout_revision",0)]
	var phase := str(snapshot.get("phase", ""))
	if room_id != _room_id:
		# The room-transition controller chooses door versus stairs explicitly.
		# Snapshot changes never replay a second or incorrect transition sound.
		_room_id = room_id
		_actors.clear()
		particles.clear()
		shake = 0.0
		hitstop = 0.0
		_boss_announced = false
		_fx_seen.clear()
		# A fresh fight locks the doors behind the party.
		if not room_id.is_empty() and phase == "combat": _play("doors_lock")
		_phase = phase
	if phase != _phase:
		if _phase == "combat" and phase == "reward": _play("room_clear")
		elif phase == "dead": _play("team_wipe")
		_phase = phase
	for event: Dictionary in snapshot.get("fx_events", []):
		var id := int(event.get("id", 0))
		if _fx_seen.has(id): continue
		_fx_seen[id] = true
		if str(event.get("kind", "")) == "void_burst": _play("void_burst")
	for event: Dictionary in snapshot.get("perk_events", []):
		if str(event.get("kind", "")) != "blast": continue
		var key := "%d:%d" % [int(event.get("x", 0)), int(event.get("y", 0))]
		if _blasts.has(key): continue
		_blasts[key] = _clock
		_play("blast")
	var seen: Dictionary = {}
	for value: Variant in snapshot.get("enemies", []):
		var enemy: Dictionary = value
		var key := "e%d" % int(enemy.get("id", -1))
		seen[key] = true
		_observe_enemy(_actor(key, enemy, "hits", "attacks"), enemy)
	var players: Dictionary = snapshot.get("players", {})
	for peer: Variant in players:
		var key := "p%d" % int(peer)
		seen[key] = true
		_observe_player(_actor(key, players[peer], "shots", "hurts"), players[peer], int(peer) == local_peer)
	for key: String in _actors.keys():
		if not seen.has(key):
			_actors.erase(key)


## Advances springs, flashes, shake and particles. Hitstop freezes all of it.
func update(delta: float) -> void:
	_clock += delta
	for key: String in _blasts.keys():
		if _clock - float(_blasts[key]) > 1.0: _blasts.erase(key)
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - delta)
		return
	# The local hero's footsteps while walking.
	if _local_moving:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = STEP_INTERVAL
			_play("step")
	else:
		_step_timer = 0.05
	shake = maxf(0.0, shake - delta * 1.8)
	particles.update(delta)
	for state: Dictionary in _actors.values():
		var force: Vector2 = -state.squash * STIFFNESS - state.squash_vel * DAMPING
		state.squash_vel += force * delta
		state.squash += state.squash_vel * delta
		state.lean_vel += (-state.lean * STIFFNESS - state.lean_vel * DAMPING) * delta
		state.lean += state.lean_vel * delta
		state.flash = maxf(0.0, state.flash - delta)


## Deformation and overlays for one actor at time `clock`: scale, lean (radians),
## vertical offset, flash strength 0..1 with its colour, and alpha.
func pose(key: String, entity: Dictionary, clock: float, authored_animation: bool = false) -> Dictionary:
	var state: Dictionary = _actors.get(key, {})
	var scale := Vector2.ONE + Vector2(state.get("squash", Vector2.ZERO))
	var lean: float = float(state.get("lean", 0.0))
	var offset := Vector2.ZERO
	var alpha := 1.0
	var phase: float = float(absi(hash(key)) % 100) * 0.1
	var face: float = float(entity.get("face", 1.0))
	var dying: float = float(entity.get("dying_p", -1.0))
	if dying >= 0.0:
		# Death: flatten and widen, tip over in the push direction, then fade.
		if not authored_animation:
			scale *= Vector2(1.0 + 0.55 * dying, 1.0 - 0.75 * dying)
			lean += signf(float(entity.get("dx", 0.0)) + 0.001) * 0.35 * dying
		alpha = 1.0 - smoothstep(0.55, 1.0, dying)
	elif authored_animation:
		# Authored limbs perform the action; the event spring still adds hit wobble.
		pass
	elif str(entity.get("attack", "")) == "windup":
		# Anticipation: rise up and lean back, growing until the shot.
		var charge: float = ease(float(entity.get("attack_p", 0.0)), 0.6)
		scale *= Vector2(1.0 - 0.16 * charge, 1.0 + 0.2 * charge)
		lean -= face * 0.16 * charge
		offset.x -= face * 2.0 * charge
	elif bool(entity.get("moving", false)):
		# Running: a light hop with a squash on each landing.
		var step: float = absf(sin(clock * 13.0 + phase))
		offset.y -= roundf(step * 3.0)
		scale *= Vector2(1.0 + 0.06 * (1.0 - step), 1.0 - 0.06 * (1.0 - step))
	else:
		# Idle breathing keeps standing actors alive.
		var breath: float = sin(clock * 3.2 + phase)
		scale *= Vector2(1.0 - 0.03 * breath, 1.0 + 0.04 * breath)
	var flash: float = float(state.get("flash", 0.0))
	return {"scale": scale, "lean": lean, "offset": offset, "alpha": alpha,
		"flash": clampf(flash / maxf(float(state.get("flash_length", 0.1)), 0.001), 0.0, 1.0) * float(state.get("flash_strength", 1.0)),
		"flash_color": state.get("flash_color", Color.WHITE)}


func _actor(key: String, entity: Dictionary, first_counter: String, second_counter: String) -> Dictionary:
	if not _actors.has(key):
		# A new actor starts from its current counters, so joining mid-fight or
		# entering a room never replays old hits.
		_actors[key] = {"squash": Vector2.ZERO, "squash_vel": Vector2.ZERO, "lean": 0.0, "lean_vel": 0.0,
			"flash": 0.0, "flash_length": 0.1, "flash_color": Color.WHITE, "attack": str(entity.get("attack", "")),
			first_counter: int(entity.get(first_counter, 0)), second_counter: int(entity.get(second_counter, 0)),
			"dying": float(entity.get("dying_p", -1.0)) >= 0.0}
		_actors[key].blocks = int(entity.get("blocks",0))
		_actors[key].part_breaks = int(entity.get("part_breaks",0))
		_actors[key].part_regrows = int(entity.get("part_regrows",0))
		_actors[key].last_perk = str(entity.get("last_perk",""))
		# A boss or mini-boss announces itself once per room.
		if (bool(entity.get("boss",false)) or bool(entity.get("miniboss",false))) and not _actors[key].dying and not _boss_announced:
			_boss_announced = true
			_play("boss_intro")
	return _actors[key]


func _observe_enemy(state: Dictionary, enemy: Dictionary) -> void:
	var kind: String = "boss" if bool(enemy.get("boss", false)) else str(enemy.get("kind", "chaser"))
	var boss: bool = kind == "boss"
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
		_play_death(enemy, boss)
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
		_play_any(["hit_" + _material(enemy), "boss_hit" if boss else "hit"])
		# No hitstop on ordinary boss hits: under sustained fire it would freeze
		# the picture several times a second. Hitstop is kept for kills and hurts.
		_add_shake(0.14 if boss else 0.08)
	var attacks := int(enemy.get("attacks", 0))
	var blocks: int = int(enemy.get("blocks",0))
	if blocks > int(state.get("blocks",0)):
		state.blocks = blocks
		_flash(state,Color("dfd7b6"),0.12,0.65)
		_kick(state,Vector2(0.18,-0.12),direction.x*0.12)
		particles.burst(origin-direction*8,SPARK,5,130,0.22,-direction,0.8,2,6)
		_play("block")
	# Body parts: a part breaks off (bone snaps, flesh tears) or grows back.
	var breaks: int = int(enemy.get("part_breaks",0))
	if breaks > int(state.get("part_breaks",0)):
		state.part_breaks = breaks
		if not dying: _play_any(["break_" + _material(enemy)])
	var regrows: int = int(enemy.get("part_regrows",0))
	if regrows > int(state.get("part_regrows",0)):
		state.part_regrows = regrows
		_play("regrow")
	if attacks > int(state.get("attacks", 0)):
		# Active frame: snap forward out of the windup and overshoot back.
		state.attacks = attacks
		_kick(state, Vector2(0.32, -0.28) * (0.6 if boss else 1.0), float(enemy.get("face", 1.0)) * 0.35)
		var attack_color: Color = Color("89b4a7") if kind == "necromancer" else Color("d2bf94") if kind in ["skeleton_archer","skeleton_guard"] else Color("f19791")
		particles.burst(origin, attack_color, 14 if boss else 7, 150.0, 0.3, Vector2.ZERO, PI, 2.0, 7.0)
		# Each move sounds like itself; the bomber's fuse ends in its burst (fx event).
		var move := str(enemy.get("attack_kind", ""))
		if move != "fuse": _play_any(["attack_" + move, "enemy_shoot"], 0.12)
		if boss:
			_add_shake(0.2)
	var attack := str(enemy.get("attack", ""))
	if attack == "windup" and state.attack != "windup":
		# Important telegraphs (beam, fuse, summoning) have their own sound;
		# rigged figures stay quiet otherwise, older figures keep the beep.
		var telegraph := "windup_" + str(enemy.get("attack_kind", ""))
		if _has(telegraph): _play(telegraph)
		elif not enemy.has("rig"): _play("windup", 0.05)
	state.attack = attack


## "bone", "flesh" or "void" for rigged enemies (audio_sfx.json), else "".
func _material(enemy: Dictionary) -> String:
	if sfx == null or not "rig_materials" in sfx: return ""
	return str(sfx.rig_materials.get(str(enemy.get("rig", "")), ""))


func _play_death(enemy: Dictionary, boss: bool) -> void:
	var rig := str(enemy.get("rig", ""))
	if boss:
		_play("boss_kill")
		if rig == "void": _play("boss_defeated")
		return
	if rig == "bomber":
		# A burst already sounds through its fx event; shot down it only pops.
		if not bool(enemy.get("exploded", false)): _play("bomber_pop")
		return
	if rig == "necro": _play_any(["kill_necro", "kill"])
	else: _play_any(["kill_" + _material(enemy), "kill"])
	if bool(enemy.get("miniboss", false)): _play("boss_defeated")


func _observe_player(state: Dictionary, player: Dictionary, local: bool) -> void:
	var origin := Vector2(float(player.get("x", 0.0)), float(player.get("y", 0.0)))
	var shots := int(player.get("shots", 0))
	# A new run recreates players with counters at 0 (and a fixed seed can keep the
	# same room id); a counter that went backwards is a reset, not an event.
	if shots < int(state.shots): state.shots = shots
	if int(player.get("hurts", 0)) < int(state.hurts): state.hurts = int(player.get("hurts", 0))
	if shots > int(state.shots):
		state.shots = shots
		# Recoil: a quick squash against the shot, settling with a small wobble.
		var aim := Vector2(float(player.get("ax", 1.0)), float(player.get("ay", 0.0)))
		_kick(state, Vector2(0.12, -0.1), -aim.x * 0.12)
		if local:
			# The class weapon decides the sound: bow string, magic orb, else the old blip.
			var class_id := str(player.get("class_id", ""))
			_play_any(["shoot_arrow" if class_id == "archer" else "shoot_magic" if class_id == "mage" else "", "shoot"], 0.1)
	# Melee swings (swordsman) count separately from shots.
	var swings := int(player.get("swings", 0))
	if swings < int(state.get("swings", 0)): state.swings = swings
	if swings > int(state.get("swings", 0)):
		state.swings = swings
		var swing_aim := Vector2(float(player.get("ax", 1.0)), float(player.get("ay", 0.0)))
		_kick(state, Vector2(0.1, -0.08), swing_aim.x * 0.16)
		if local:
			_play("swing", 0.1)
	var hurts := int(player.get("hurts", 0))
	if hurts > int(state.hurts):
		state.hurts = hurts
		_flash(state, Color("ff4a4a"), 0.18)
		_kick(state, Vector2(0.3, -0.32), 0.0)
		particles.burst(origin, BLOOD.player, 10, 160.0, 0.5, Vector2.ZERO, PI, 3.0)
		_play("hurt", 0.05)
		_add_shake(0.5 if local else 0.15)
		hitstop = maxf(hitstop, 0.05 if local else 0.0)
	if local:
		_local_moving = bool(player.get("moving", false)) and float(player.get("hp", 1)) > 0
		# A newly picked perk chimes for the player who took it.
		var perk := str(player.get("last_perk", ""))
		if perk != str(state.get("last_perk", "")):
			state.last_perk = perk
			if not perk.is_empty(): _play("perk")


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
	if sfx != null:
		sfx.play(name, spread)


func _has(name: String) -> bool:
	return sfx != null and sfx.has_method("has_effect") and sfx.has_effect(name)


## Plays the first of `names` that exists (a specific sound before its fallback).
func _play_any(names: Array, spread: float = 0.08) -> void:
	if sfx == null: return
	for name: String in names:
		if name.is_empty(): continue
		if not sfx.has_method("has_effect") or sfx.has_effect(name):
			sfx.play(name, spread)
			return
