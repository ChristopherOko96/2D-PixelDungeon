extends RefCounted
## Game-feel layer between host snapshots and the dungeon view. Watches the
## host's counters (hits, attacks, shots, hurts) and dying state, and turns each
## change into one combined, timed reaction: hit flash, squash & stretch on a
## damped spring (overshoot gives follow-through), particles, stains, sound,
## screen shake and hitstop. Owns no gameplay state; the host stays authoritative.
## Counters instead of one-shot events: a client that misses an unreliable
## snapshot still sees the counter move and reacts once.

const Particles = preload("res://src/vfx/particles.gd")
const GORE_PATH := "res://assets/data/vfx_gore.json"
const SKILLS_PATH := "res://assets/data/hero_skills.json"
static var _gore: Dictionary = {}
static var _skill_sounds: Dictionary = {}

const BLOOD := {"chaser": Color("6fbf4f"), "shooter": Color("b4543f"), "boss": Color("9b4fd4"), "player": Color("d8484f"),"skeleton_archer":Color("c5b68c"),"skeleton_guard":Color("c5b68c"),"necromancer":Color("786c8a"),
	"imp":Color("d6503f"),"skelet":Color("e8e2d0"),"o_brute":Color("b4543f"),"o_berserker":Color("b4543f"),"o_chieftain":Color("b4543f"),
	"chort":Color("c8302f"),"wogol":Color("7fae4f"),"doc":Color("b4543f"),"pumpkin_dude":Color("e88a2f"),"big_zombie":Color("7fae4f"),"angel":Color("f4e8b0"),
	"seraph":Color("ffd76a"),"rot_king":Color("7fae4f"),"hell_prince":Color("ff6a2a"),"ogre_warchief":Color("b4543f"),
	"winged_chort":Color("c8302f"),"soul_caller":Color("8b5fd0"),"crystal_wogol":Color("78e6f0"),"golden_angel":Color("ffd76a")}
const SPARK := Color("fff1c2")
const HIT_FLASH := Color("ff6a5c")
const DUST := Color("8e8496")
# Spring for squash & stretch: underdamped, so deformations overshoot once.
const STIFFNESS := 320.0
const DAMPING := 13.0

var particles := Particles.new()
## Effect animations (FxSprites), set by the view; null in tests.
var fx: RefCounted = null
## Optional sound player with play(name); null in tests and headless runs.
var sfx: Node = null
## Screen-shake trauma 0..1; the view squares it for the offset.
var shake := 0.0
## Trauma held while the local hero's Photoneneis burns (a 1 px rumble).
const BEAM_RUMBLE := 0.3
## Seconds left in which the view holds the current frame (hitstop).
var hitstop := 0.0

var _actors: Dictionary = {}
var _room_id := ""
## Sound flow (assets/data/audio_sfx.json): room phase, one boss sting per room,
## fx/perk events played once, the local hero's footsteps.
## Footstep gap when no rig reports touch-downs (the snapshot step_time wins).
const STEP_INTERVAL := 0.21
var _phase := ""
var _boss_announced := false
var _fx_seen: Dictionary = {}
var _blasts: Dictionary = {}
var _local_moving := false
var _step_timer := 0.0
var _step_time := STEP_INTERVAL
## True while the view's hero rigs report the touch-downs (they play the steps).
var rig_footsteps := false
## Where the local hero stands (idle enemy sounds only near it).
var _local_point := Vector2.INF
## Next moment an idle rattle or groan may sound (one at a time, room-wide).
var _idle_ready := 0.0
const IDLE_RANGE := 320.0
const IDLE_GAP := 1.4
var _clock := 0.0
var _team_level := 0


## Gore table (vfx_gore.json), cached.
static func _gore_data() -> Dictionary:
	if _gore.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GORE_PATH)) if FileAccess.file_exists(GORE_PATH) else null
		_gore = parsed if parsed is Dictionary else {"materials": {}, "kinds": {}}
	return _gore


## What an enemy (or "player") is made of: {material, color, stain, ...}.
## `kind` is an enemy kind of the table, or a material name itself.
static func gore(kind: String) -> Dictionary:
	var data := _gore_data()
	var fallback: String = kind if (data.get("materials", {}) as Dictionary).has(kind) else str(data.get("default", "blood"))
	var name := str(data.get("kinds", {}).get(kind, fallback))
	var material: Dictionary = data.get("materials", {}).get(name, {}).duplicate()
	material.material = name
	return material


## Sound event of a hero skill (hero_skills.json "sound"), cached.
static func skill_sound(skill_id: String) -> String:
	if _skill_sounds.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SKILLS_PATH)) if FileAccess.file_exists(SKILLS_PATH) else null
		_skill_sounds["_"] = ""
		if parsed is Dictionary:
			for block: Dictionary in parsed.get("classes", {}).values():
				for skill: Dictionary in block.get("skills", []): _skill_sounds[str(skill.id)] = str(skill.get("sound", ""))
	return str(_skill_sounds.get(skill_id, ""))


## Compares a snapshot with the last one and fires the reactions for anything
## that changed. Safe to call every frame with the same snapshot.
func observe(snapshot: Dictionary, local_peer: int) -> void:
	var layout: Variant = snapshot.get("room_layout", {})
	var room_id: String = str(layout.get("id", "")) if layout is Dictionary else ""
	if not room_id.is_empty():
		# Room entries, not wall breaks (which also bump the layout revision), reset effects.
		room_id = "%s:%s:%s:%s" % [snapshot.get("run_seed",0),snapshot.get("floor_index",0),room_id,snapshot.get("room_serial",snapshot.get("room_layout_revision",0))]
	var phase := str(snapshot.get("phase", ""))
	if room_id != _room_id:
		# The room-transition controller chooses door versus stairs explicitly.
		# Snapshot changes never replay a second or incorrect transition sound.
		_room_id = room_id
		_actors.clear()
		particles.clear()
		if fx != null: fx.clear()
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
		var fx_kind := str(event.get("kind", ""))
		var fx_point := Vector2(float(event.get("x", 0.0)), float(event.get("y", 0.0)))
		if fx_kind == "void_burst":
			# the void implodes: a hard pull, a frame of void, a pressure ring (src/vfx/particles.gd)
			particles.implode(fx_point, 56.0)
			_play("void_burst")
		elif fx_kind == "wall_hit": _wall_hit(fx_point, Vector2(float(event.get("nx", 0.0)), float(event.get("ny", 0.0))), str(event.get("style", "arrow")), str(snapshot.get("players", {}).get(int(event.get("o", 0)), {}).get("glow", "")))
		elif fx_kind == "crate_break":
			particles.kick(fx_point, 20.0, 0.6)
			particles.burst(fx_point, Color("a8743e"), 18, 210.0, 0.7, Vector2.ZERO, PI, 4.0, 4.0)
			particles.burst(fx_point, Color("5e3c22"), 10, 140.0, 0.8, Vector2.ZERO, PI, 3.0, 3.0)
			particles.splat(fx_point + Vector2(0, 6), Color("4a3020"), 0.5, 9.0)
			_fx_spawn("wood_burst", fx_point, 0.0, 1.5)
			_fx_spawn("dust", fx_point + Vector2(0, 4), 0.0, 1.6)
			_play_any(["crate_break", "break_bone"], 0.05)
		elif fx_kind == "enemy_spawn":
			_fx_spawn("dust", fx_point + Vector2(0, 6), 0.0, 2.2)
			particles.burst(fx_point, Color("5a4e48"), 8, 90.0, 0.5, Vector2.UP, 1.2, 3.0, 3.0, "dust")
		elif fx_kind == "level_up":
			_fx_spawn("level_up", fx_point + Vector2(0, 12), 0.0, 1.2)
			# holy light: shafts falling that sparkle where they land, gold motes rising
			particles.holy(fx_point + Vector2(0, 8), 10, 18.0)
		elif fx_kind == "chest_open":
			particles.burst(fx_point, Color("b8864a"), 16, 200.0, 0.6, Vector2.ZERO, PI, 3.0, 4.0)
			_fx_spawn("wood_burst", fx_point, 0.0, 1.4)
			_fx_spawn("pickup", fx_point + Vector2(0, -8), 0.0, 1.5)
			_play_any(["chest_open", "break_bone"], 0.05)
		elif fx_kind in ["potion_throw", "potion_blast", "drink", "curse", "cleanse", "identify"]:
			# Items: a potion bursts in its colour, a curse flares dark, a cleanse shines.
			var potion_colours := {"red": Color("d23c3c"), "orange": Color("e8812e"), "yellow": Color("f2d24a"), "lime": Color("9be04a"), "green": Color("3fbf5a"), "teal": Color("38c9b0"), "sky": Color("6cc6f0"), "blue": Color("3b5fe0"), "violet": Color("9a4fe0"), "pink": Color("ef7ab8"), "white": Color("f2efe8"), "black": Color("3a3436")}
			var tint: Color = potion_colours.get(str(event.get("color", "")), Color("c8323a"))
			match fx_kind:
				"potion_throw":
					particles.burst(fx_point, tint, 22, 200.0, 0.6, Vector2.ZERO, PI, 3.0, 3.0)
					particles.splat(fx_point + Vector2(0, 4), tint.darkened(0.3), 0.6, float(event.get("r", 50.0)) * 0.5)
					_play_any(["potion_break", "crate_break", "break_bone"], 0.08)
				"potion_blast":
					particles.kick(fx_point, 30.0, 0.8)
					particles.burst(fx_point, Color("f7a23a"), 26, 260.0, 0.6, Vector2.ZERO, PI, 4.0, 4.0)
					_fx_spawn("explosion", fx_point, 0.0, 1.0)
					_add_shake(0.3)
					_play_any(["blast"], 0.05)
				"drink":
					particles.burst(fx_point + Vector2(0, -16), tint, 10, 70.0, 0.6, Vector2.UP, 1.0, 3.0, 3.0)
					_play_any(["drink", "perk"], 0.05)
				"curse":
					particles.burst(fx_point, Color("5a2a7a"), 20, 120.0, 0.8, Vector2.UP, 1.4, 4.0, 4.0)
					_play_any(["attack_roar", "blast"], 0.05)
				"cleanse":
					particles.burst(fx_point, Color("f4d27a"), 24, 160.0, 0.8, Vector2.UP, 1.6, 3.0, 3.0)
					_fx_spawn("level_up", fx_point + Vector2(0, 12), 0.0, 1.0)
					_play_any(["room_clear", "perk"], 0.0)
				"identify":
					particles.burst(fx_point, Color("8fd8e6"), 16, 120.0, 0.6, Vector2.UP, 1.4, 3.0, 3.0)
					_play_any(["perk"], 0.05)
		elif fx_kind == "zone_burst":
			# A boss move lands: dust, ice, poison, void or bone, by its style.
			var colours := {"void": Color("c06bd8"), "poison": Color("8fc84a"), "ice": Color("9fe3ee"), "frost": Color("bff0f7"), "quake": Color("b08a5a"), "spikes": Color("e6dcc6"), "bone": Color("e6dcc6"), "flesh": Color("c8323a"), "fire": Color("f7883a"), "curse": Color("8a6be0")}
			var style := str(event.get("style", "quake"))
			var tint: Color = colours.get(style, Color("b08a5a"))
			var size := float(event.get("r", 30.0))
			if style in ["ice", "frost"]:
				# ice is rigid: shards burst and slide, rime grows, liquid near it freezes
				particles.shatter(fx_point, clampi(int(size * 0.15), 4, 12), Vector2.ZERO, 120.0 + size)
				particles.rime_grow(fx_point, 4, size * 0.35)
				particles.freeze_liquids(fx_point, size)
			elif style in ["quake", "spikes", "bone"]:
				# stone is heavy: rubble that stops hard, dust creeping flat, cracks that stay
				particles.rubble(fx_point, clampi(int(size * 0.2), 4, 14), Vector2.ZERO, 100.0 + size)
				particles.dust_flat(fx_point, size * 0.5, clampi(int(size * 0.25), 6, 18))
				particles.floor_crack(fx_point, size * 0.6, 4 if size >= 60.0 else 3)
			else:
				particles.burst(fx_point, tint, clampi(int(size * 0.4), 6, 28), 120.0 + size, 0.5, Vector2.ZERO, PI, 3.0, 3.0)
			if style in ["quake", "spikes", "bone"]: particles.kick(fx_point, size * 0.6, 0.5)
			if size >= 80.0: _add_shake(0.25)
			_play_any(["blast", "break_bone"] if style in ["quake", "spikes", "bone"] else ["frost", "blast"] if style in ["ice", "frost"] else ["blast"], 0.08)
		elif fx_kind in ["rage", "collapse"]:
			particles.burst(fx_point, Color("ff4a3a") if fx_kind == "rage" else Color("e6dcc6"), 24, 220.0, 0.7, Vector2.ZERO, PI, 4.0, 4.0)
			_add_shake(0.5)
			_play_any(["attack_roar", "blast"], 0.0)
		elif fx_kind == "armor":
			particles.burst(fx_point, Color("bff0f7"), 14, 90.0, 0.6, Vector2.UP, 1.4, 3.0, 3.0)
			_play_any(["frost", "perk"], 0.05)
		elif fx_kind == "blink":
			particles.burst(fx_point, Color("c06bd8"), 16, 160.0, 0.5, Vector2.ZERO, PI, 3.0, 3.0)
			_fx_spawn("void_burst", fx_point, 0.0, 0.8)
		elif fx_kind in ["ice_block_break", "bone_cage_break"]:
			if fx_kind == "ice_block_break":
				# the block breaks into big shards that slide off and scratch the floor
				particles.shatter(fx_point, 12, Vector2.ZERO, 170.0, [], 4)
			else:
				particles.burst(fx_point, Color("e6dcc6"), 14, 180.0, 0.6, Vector2.ZERO, PI, 3.0, 3.0)
			_play_any(["frost", "break_bone"] if fx_kind == "ice_block_break" else ["break_bone"], 0.08)
		elif fx_kind == "mimic_spring":
			# The chest was a Mimik: splinters, a snap and a hard shake.
			particles.kick(fx_point, 24.0, 0.8)
			particles.burst(fx_point, Color("b8864a"), 14, 220.0, 0.6, Vector2.ZERO, PI, 3.0, 4.0)
			particles.burst(fx_point, Color("c8323a"), 6, 160.0, 0.5, Vector2.UP, 1.0, 3.0, 3.0)
			_fx_spawn("wood_burst", fx_point, 0.0, 1.6)
			_add_shake(0.4)
			_play_any(["attack_bite", "chest_open"], 0.0)
			_play_any(["attack_roar", "hurt"], 0.05)
		elif fx_kind == "loot_taken":
			_fx_spawn("pickup", fx_point, 0.0, 1.6)
			_play("perk")
		elif fx_kind == "wall_break":
			particles.kick(fx_point, 48.0, 1.3)
			# Rubble: stone chunks and dust where an inner wall gave way.
			particles.burst(fx_point, Color("8f7f70"), 18, 220.0, 0.7, Vector2.ZERO, PI, 4.0, 4.0)
			particles.burst(fx_point, Color("c9b49a"), 12, 120.0, 0.9, Vector2.ZERO, PI, 3.0, 2.0)
			particles.stain(fx_point, Color("5a4e48"), 14.0)
			_add_shake(0.35)
			_fx_spawn("stone_burst", fx_point, 0.0, 0.9)
			_play_any(["break_bone", "blast"], 0.05)
	# Team level-up fanfare, once per new level.
	var team_level := int(snapshot.get("team", {}).get("level", 0))
	if team_level > _team_level and _team_level > 0: _play("room_clear")
	if team_level > 0: _team_level = team_level
	for event: Dictionary in snapshot.get("perk_events", []):
		if str(event.get("kind", "")) != "blast": continue
		var key := "%d:%d" % [int(event.get("x", 0)), int(event.get("y", 0))]
		if _blasts.has(key): continue
		_blasts[key] = _clock
		# A found staff's splash bursts in its own glow colour; otherwise the emerald burst.
		var glow := str(snapshot.get("players", {}).get(int(event.get("o", 0)), {}).get("glow", ""))
		if not glow.is_empty(): _fx_spawn("spell_burst", Vector2(float(event.get("x", 0)), float(event.get("y", 0))), 0.0, 1.1, Color(glow).lightened(0.15))
		else: _fx_spawn("magic_burst", Vector2(float(event.get("x", 0)), float(event.get("y", 0))), 0.0, 1.2)
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
	if _local_moving and not rig_footsteps:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = _step_time
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


## Starts an effect animation when the view supplied the player; effects are
## cut at walls (they never show through to the other side).
func _fx_spawn(name: String, point: Vector2, rotation: float = 0.0, scale: float = 1.0, tint: Color = Color.WHITE, speed: float = 1.0) -> void:
	if fx != null: fx.spawn(name, point, rotation, scale, tint, speed, true)


const WALL_STYLES := {"fire": ["fire_burst", Color("ff9a3a"), Color("3a2418")], "frost": ["frost_burst", Color("bfeaf2"), Color("3a6a7a")], "arcane": ["arcane_burst", Color("c8a8ff"), Color("3a2a5a")], "magic": ["magic_burst", Color("8ff0b8"), Color("244a3a")], "void": ["void_burst", Color("c890f0"), Color("3a1e4a")], "poison": ["poison_burst", Color("a8e05a"), Color("2a4a1a")]}


## Something struck a wall at `point` (normal back to the floor): stone chips
## drop, a crack remains; metal and arrows spark, magic splashes along the wall.
## glow: a found bow's or staff's colour; its shots splash in that colour.
func _wall_hit(point: Vector2, normal: Vector2, style: String, glow: String = "") -> void:
	if normal == Vector2.ZERO: normal = Vector2.DOWN
	var out := point + normal * 4.0
	var along := normal.orthogonal()
	particles.burst(out, Color("8f7f70"), 5, 120.0, 0.55, normal + Vector2(0, 0.6), 0.9, 2.0, 2.5)
	particles.burst(out, Color("c9b49a"), 3, 70.0, 0.7, Vector2(0, 1), 0.5, 2.0, 1.5)
	particles.crack(point, normal)
	if not glow.is_empty() and style == "magic":
		var tint := Color(glow)
		_fx_spawn("spell_burst", out, 0.0, 0.6, tint.lightened(0.15))
		for side in [-1.0, 1.0]: particles.burst(out, tint.lightened(0.2), 6, 150.0, 0.45, along * side + normal * 0.25, 0.35, 2.0, 4.0, "spark")
		particles.splat(point, tint.darkened(0.6), 0.35, 4.0, along)
	elif WALL_STYLES.has(style):
		var data: Array = WALL_STYLES[style]
		_fx_spawn(str(data[0]), out, 0.0, 0.55)
		if style == "fire":
			particles.embers(out, 6.0, 3)
			particles.smoke(out, 2, 3.0)
		for side in [-1.0, 1.0]: particles.burst(out, data[1], 6, 150.0, 0.45, along * side + normal * 0.25, 0.35, 2.0, 4.0, "spark")
		particles.splat(point, data[2], 0.35, 4.0, along)
	else:
		particles.burst(out, Color("fff2b0"), 7, 260.0, 0.22, normal, 0.8, 2.0, 7.0, "spark")
		_fx_spawn("hit_spark", out, randf() * TAU, 0.7, Color(1.0, 0.95, 0.75))
		_fx_spawn("dust", out, 0.0, 0.7)
		if style == "metal": _play_any(["block"], 0.08)


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
	# the story worlds name their monsters' material directly (src/hero/story_feel.gd)
	var material := gore(str(enemy.get("gore", kind)))
	var blood: Color = Color(str(material.get("color", "c8323a")))
	var stain_color: Color = Color(str(material.get("stain", "7a1a22")))
	var stain_alpha: float = float(material.get("stain_alpha", 0.6))
	var hits := int(enemy.get("hits", 0))
	var dying: bool = float(enemy.get("dying_p", -1.0)) >= 0.0
	if dying and not state.dying:
		# Killing blow: everything at once, strongest on the boss.
		particles.kick(origin + Vector2(0, 10), 48.0 if boss else 20.0, 1.0 if boss else 0.5)
		state.dying = true
		state.hits = hits
		_flash(state, Color.WHITE, 0.14)
		_kick(state, Vector2(0.45, -0.4) * (0.5 if boss else 1.0), direction.x * 0.5)
		# a liquid flies as drops that land as small splats (bone flies as chips)
		var flies := "debris" if bool(material.get("chips", false)) else "drop"
		particles.burst(origin, blood, 70 if boss else 24, 260.0 if boss else 190.0, 0.9 if boss else 0.6, direction, 1.3, 4.0 if boss else 3.0, 5.0, flies)
		particles.burst(origin, DUST, 30 if boss else 10, 120.0, 0.7, Vector2.ZERO, PI, 4.0, 3.0, "dust")
		particles.splat(origin + Vector2(0, 10), stain_color, stain_alpha, float(material.get("death_splat", 18)) * (2.0 if boss else 1.0), direction)
		if bool(material.get("chips", false)): particles.burst(origin, blood, 16 if boss else 10, 210.0, 0.8, direction, 1.2, 4.0, 4.0)
		var death_fx: String = str(material.get("death_fx", {"bone": "stone_burst", "slime": "poison_burst", "frost": "frost_burst", "void": "void_burst", "blood": "blood_burst"}.get(str(material.get("material", "blood")), "blood_burst")))
		_fx_spawn(death_fx, origin + Vector2(0, -8), 0.0, 2.2 if boss else 1.0)
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
		particles.burst(origin - direction * 6.0, SPARK, 6, 170.0, 0.22, -direction, 0.7, 2.0, 8.0, "spark")
		_fx_spawn("hit_spark", origin - direction * 10.0 + Vector2(0, -10), float(hits) * 0.7, 1.3 if boss else 1.0)
		particles.burst(origin, blood, 6 if boss else 4, 130.0, 0.45, direction, 0.6, 3.0, 5.0, "debris" if bool(material.get("chips", false)) else "drop")
		# Liquids spray onto the floor behind the target; bone only chips.
		if float(material.get("hit_splat", 0)) > 0.0: particles.splat(origin + Vector2(0, 8) + direction * 10.0, stain_color, stain_alpha * 0.85, float(material.hit_splat) * (1.6 if boss else 1.0), direction)
		elif bool(material.get("chips", false)): particles.burst(origin, blood, 5, 160.0, 0.5, direction, 0.8, 3.0, 5.0)
		_play_any(["hit_" + _material(enemy), "boss_hit" if boss else "hit"])
		# No hitstop on ordinary boss hits: under sustained fire it would freeze
		# the picture several times a second. Hitstop is kept for kills and hurts.
		_add_shake(0.14 if boss else 0.08)
	# Walking skeletons rattle, zombies groan, now and then near the hero.
	if not dying and bool(enemy.get("moving", false)) and _clock >= _idle_ready and _local_point.is_finite() and origin.distance_to(_local_point) < IDLE_RANGE:
		var idle := "idle_" + _material(enemy)
		if _has(idle) and randf() < 0.35:
			_idle_ready = _clock + IDLE_GAP * randf_range(0.8, 1.6)
			_play(idle, 0.1)
	# Wounded enemies leave a drip trail where they walk.
	var health_share := float(enemy.get("hp", 1.0)) / maxf(float(enemy.get("max_hp", 1.0)), 1.0)
	if not dying and float(material.get("drip_every", 0)) > 0.0 and health_share < float(material.get("drip_below", 0.0)):
		var last: Vector2 = state.get("drip_at", origin)
		if not state.has("drip_at") or origin.distance_to(last) >= float(material.drip_every):
			state.drip_at = origin
			particles.drip(origin + Vector2(0, 10), stain_color, stain_alpha, 3.0 if boss else 2.0)
	var attacks := int(enemy.get("attacks", 0))
	var blocks: int = int(enemy.get("blocks",0))
	if blocks > int(state.get("blocks",0)):
		state.blocks = blocks
		_flash(state,Color("dfd7b6"),0.12,0.65)
		_kick(state,Vector2(0.18,-0.12),direction.x*0.12)
		particles.burst(origin-direction*8,SPARK,5,130,0.22,-direction,0.8,2,6,"spark")
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
		particles.burst(origin, attack_color, 14 if boss else 7, 150.0, 0.3, Vector2.ZERO, PI, 2.0, 7.0, "dust")
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
		var raging: bool = player.get("skills", {}).has("rage")
		var swing_angle := float(player.get("swing_angle", swing_aim.angle()))
		var reach := maxf(40.0, float(player.get("reach", 64.0)))
		_fx_spawn("slash_rage" if raging else "slash", origin + Vector2(0, -12), swing_angle, reach / 52.0, Color.WHITE, 1.6 if raging else 1.0)
		if local:
			_play("swing", 0.1)
	var hurts := int(player.get("hurts", 0))
	if hurts > int(state.hurts):
		state.hurts = hurts
		_flash(state, Color("ff4a4a"), 0.18)
		_kick(state, Vector2(0.3, -0.32), 0.0)
		particles.burst(origin, BLOOD.player, 10, 160.0, 0.5, Vector2.ZERO, PI, 3.0)
		var hero_blood := gore("player")
		particles.splat(origin + Vector2(0, 8), Color(str(hero_blood.get("stain", "7a1a22"))), float(hero_blood.get("stain_alpha", 0.6)), 5.0, Vector2(float(player.get("hit_dx", 0.0)), float(player.get("hit_dy", 0.0))))
		_play("hurt" if local else "hurt_ally", 0.05)
		_add_shake(0.5 if local else 0.15)
		hitstop = maxf(hitstop, 0.05 if local else 0.0)
	# Hero skills: each cast sounds like itself (hero_skills.json "sound").
	var casts := int(player.get("skill_casts", 0))
	if casts < int(state.get("skill_casts", 0)): state.skill_casts = casts
	if casts > int(state.get("skill_casts", 0)):
		state.skill_casts = casts
		var cast_sound := skill_sound(str(player.get("last_skill", "")))
		if not cast_sound.is_empty(): _play(cast_sound, 0.05, "hero")
		_kick(state, Vector2(0.2, -0.18), 0.0)
	# Photoneneis: a jolt when it ignites, then a steady rumble while it burns.
	var beaming: bool = player.get("skills", {}).has("beam") and float(player.get("hp", 0)) > 0
	if beaming and not bool(state.get("beaming", false)): _add_shake(0.45 if local else 0.15)
	if beaming and local: shake = maxf(shake, BEAM_RUMBLE)
	state.beaming = beaming
	if local:
		var card := str(player.get("last_card", ""))
		if card != str(state.get("last_card", card)) and not card.is_empty(): _play("perk")
		state.last_card = card
		_local_moving = bool(player.get("moving", false)) and float(player.get("hp", 1)) > 0
		_step_time = float(player.get("step_time", STEP_INTERVAL))
		_local_point = origin
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


## Plays an event; `category` overrides its mix group (a hero skill that
## borrows an enemy sound stays at the hero's level).
func _play(name: String, spread: float = 0.08, category: String = "") -> void:
	if sfx != null:
		sfx.play(name, spread, category)


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
