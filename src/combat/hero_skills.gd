extends RefCounted
## Host-side hero skills on keys 1-4 (docs/KLASSEN-FAEHIGKEITEN.de.md, values in
## assets/data/hero_skills.json). Reads the held keys and the mouse point from
## each player's input, runs cooldowns, dashes, channels and timed effects, and
## deals damage through the game's normal damage path, so body parts, perks,
## kills and EXP work as for the basic attack. Upgrades come from level-up cards
## (ClassPerks). Ultimates break inner walls (WallBreaker). Clients draw what
## `snapshot()` and the per-player `player_state()` report.

const ClassPerks = preload("res://src/player/class_perks.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const WallBreaker = preload("res://src/dungeon/wall_breaker.gd")

var game: Node
## Ground effects: {id, kind, pos, radius, time, owner, ...}. Kinds: caltrops,
## poison, lava, storm, decoy.
var zones: Array = []
## Short visual events for clients: {kind, points, time, ...}.
var events: Array = []
var _delayed: Array = []
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func bind(owner: Node) -> void:
	game = owner


func reset(seed_value: int) -> void:
	zones.clear()
	events.clear()
	_delayed.clear()
	_rng.seed = seed_value + 5021
	for player: Dictionary in game.players.values(): _fresh(player)


## Leaving a room ends ground effects, channels and windups.
func room_changed() -> void:
	zones.clear()
	_delayed.clear()
	for player: Dictionary in game.players.values():
		var state := _state(player)
		state.erase("photon")
		state.erase("fist")
		state.erase("ballista")
		state.erase("dash")


func _fresh(player: Dictionary) -> void:
	player.skill_cd = [0.0, 0.0, 0.0, 0.0]
	player.skill_cd_max = [1.0, 1.0, 1.0, 1.0]
	player.skill_second = [0.0, 0.0, 0.0, 0.0]
	player.skill_keys = 0
	player.skill = {}


func _state(player: Dictionary) -> Dictionary:
	if not player.has("skill"): _fresh(player)
	return player.skill


func _level() -> int:
	return int(game.team_progress.team.level)


func _skill(player: Dictionary, index: int) -> Dictionary:
	return ClassPerks.skill_at(str(player.get("class_id", "")), index)


func _data(key: String) -> Dictionary:
	return ClassPerks.data().get(key, {})


# --- Input -------------------------------------------------------------------

## Reads keys 1-4 (bitmask `command.skills`) and the mouse point `command.target`.
func handle_input(id: int, player: Dictionary, command: Dictionary) -> void:
	if int(player.hp) <= 0: return
	var state := _state(player)
	var keys := int(command.get("skills", 0))
	var previous := int(player.get("skill_keys", 0))
	player.skill_keys = keys
	var target: Vector2 = command.get("target", Vector2(player.pos) + Vector2(command.get("aim", Vector2.RIGHT)) * 120.0)
	if not target.is_finite(): target = Vector2(player.pos) + Vector2(command.get("aim", Vector2.RIGHT)) * 120.0
	state.target = target
	for index in range(4):
		var bit := 1 << index
		var skill := _skill(player, index)
		if skill.is_empty() or not ClassPerks.unlocked(str(player.class_id), index, _level()): continue
		if int(player.get("sealed_skill", -1)) == index: continue
		if bool(skill.get("hold", false)):
			if keys & bit and not (previous & bit): _hold_start(id, player, index, skill)
			elif previous & bit and not (keys & bit): _hold_end(id, player, index, skill)
		elif keys & bit:
			# A new press always tries; a held key keeps trying while the skill is
			# ready (e.g. Kettenblitz without a target in sight). A second charge
			# needs a new press, so one long press never spends both.
			var fresh := not (previous & bit)
			if fresh or (float(player.skill_cd[index]) <= 0.0 and float(player.skill_second[index]) <= 0.0):
				_press(id, player, index, skill, target)


func _ready_to_cast(player: Dictionary, index: int) -> bool:
	return float(player.skill_cd[index]) <= 0.0 or float(player.skill_second[index]) > 0.0


## Starts the cooldown, or opens the second-use window of a "second charge" upgrade.
func _spent(player: Dictionary, index: int, skill: Dictionary) -> void:
	if float(player.skill_second[index]) > 0.0:
		player.skill_second[index] = 0.0
		_cooldown(player, index, skill)
		return
	for second: String in ["second_charge", "second_leap", "second_blink"]:
		if ClassPerks.has(player, second) and not ClassPerks.upgrade(skill, second).is_empty():
			player.skill_second[index] = float(ClassPerks.upgrade(skill, second).get("window", 1.5))
			return
	_cooldown(player, index, skill)


func _cooldown(player: Dictionary, index: int, skill: Dictionary) -> void:
	var scale := float(player.get("cooldown_scale", 1.0))
	# Debug cheat (src/debug/cheats.gd): skills are ready again at once.
	if bool(player.get("cheat_no_cooldown", false)): scale = 0.0
	player.skill_cd[index] = float(skill.get("cooldown", 5.0)) * scale
	player.skill_cd_max[index] = float(skill.get("cooldown", 5.0)) * scale


func _press(id: int, player: Dictionary, index: int, skill: Dictionary, target: Vector2) -> void:
	if not _ready_to_cast(player, index) or _busy(player): return
	var aim: Vector2 = (target - Vector2(player.pos)).normalized()
	if aim.is_zero_approx(): aim = Vector2(player.get("aim", Vector2.RIGHT))
	match str(skill.id):
		"whirl": _whirl(id, player, skill, 1.0)
		"wave": _wave(id, player, skill, aim)
		"charge": _dash(id, player, skill, aim, "charge")
		"rage": _rage(player, skill)
		"volley": _volley(id, player, skill, aim, 1.0)
		"backflip": _backflip(id, player, skill, target)
		"fist":
			_state(player).fist = {"time": float(skill.windup), "aim": aim}
			_event("fist_warning", [Vector2(player.pos), Vector2(player.pos) + aim * float(skill.range)], float(skill.windup))
		"fireball": _fireball(id, player, skill, aim)
		"chain": if not _chain(id, player, skill, target, index): return
		"blink": _blink(id, player, skill, target)
		_: return
	_spent(player, index, skill)
	player.skill_casts = int(player.get("skill_casts", 0)) + 1
	player.last_skill = str(skill.id)


## A dash, windup or channel blocks other skills until it ends.
func _busy(player: Dictionary) -> bool:
	var state := _state(player)
	return state.has("dash") or state.has("fist") or state.has("photon") or state.has("ballista")


func _hold_start(_id: int, player: Dictionary, index: int, skill: Dictionary) -> void:
	if float(player.skill_cd[index]) > 0.0 or _busy(player): return
	var state := _state(player)
	if str(skill.id) == "ballista":
		state.ballista = {"charge": 0.0, "index": index}
	elif str(skill.id) == "photon":
		var aim: Vector2 = Vector2(player.get("aim", Vector2.RIGHT))
		var length := float(skill.duration) + float(ClassPerks.bonus(player, skill, "long_breath", "time"))
		state.photon = {"time": 0.0, "max": length, "angle": aim.angle(), "tick": 0.0, "wall": 0.0, "index": index}
		player.last_skill = "photon"
		player.skill_casts = int(player.get("skill_casts", 0)) + 1


func _hold_end(id: int, player: Dictionary, index: int, skill: Dictionary) -> void:
	var state := _state(player)
	if str(skill.id) == "ballista" and state.has("ballista"):
		_ballista_fire(id, player, skill, float(state.ballista.charge))
		state.erase("ballista")
		_cooldown(player, index, skill)
		player.last_skill = "ballista"
		player.skill_casts = int(player.get("skill_casts", 0)) + 1
	elif str(skill.id) == "photon" and state.has("photon"):
		state.erase("photon")
		_cooldown(player, index, skill)


# --- Hooks used by the game ---------------------------------------------------

## Movement speed factor this step; 0 while a dash moves the hero itself.
func move_scale(player: Dictionary) -> float:
	var state := _state(player)
	if state.has("dash"): return 0.0
	var scale := 1.0
	var class_id := str(player.get("class_id", ""))
	if float(state.get("whirl_time", 0.0)) > 0.0: scale *= float(ClassPerks.skill_at(class_id, 0).get("move_scale", 0.5))
	if state.has("ballista"): scale *= float(ClassPerks.skill_at(class_id, 1).get("move_scale", 0.5))
	if state.has("photon"): scale *= float(ClassPerks.skill_at(class_id, 3).get("move_scale", 0.3))
	return scale


## False while channelling, charging, dashing or winding up.
func can_attack(player: Dictionary) -> bool:
	return not _busy(player)


## After a basic attack: Rage breaks walls, Parade breaks shots, Doppelzauber echoes.
func basic_attack(id: int, player: Dictionary, aim: Vector2) -> void:
	var build: Dictionary = player.get("build", {})
	if bool(player.get("melee", false)):
		var reach := float(player.get("reach", 64.0))
		if float(_state(player).get("rage", 0.0)) > 0.0:
			var point: Vector2 = Vector2(player.pos) + aim * reach * 0.75
			_break_walls(point, reach * 0.55 + float(_data("walls").get("rage_reach_bonus", 10)))
		if float(build.get("parry", 0.0)) > 0.0:
			for index in range(game.bullets.size() - 1, -1, -1):
				var bullet: Dictionary = game.bullets[index]
				if int(bullet.owner) != 0: continue
				var offset: Vector2 = Vector2(bullet.pos) - Vector2(player.pos)
				if offset.length() <= reach + 12.0 and absf(aim.angle_to(offset)) <= float(player.get("arc", 2.0)) * 0.5 + 0.2:
					game.bullets.remove_at(index)
					_event("parry", [Vector2(bullet.pos)], 0.25)
		# Rage swings twice: the second blade comes back the other way.
		if rage_active(player):
			_delayed.append({"time": float(_data("sword_feel").get("rage_second_delay", 0.12)), "kind": "rage_swing", "id": id, "aim": aim})
	elif float(build.get("double_cast", 0.0)) > 0.0 and str(player.get("class_id", "")) == "mage":
		_delayed.append({"time": 0.12, "kind": "echo", "id": id, "aim": aim, "scale": float(build.double_cast)})


## Extra attack speed (Rage, Kampfrausch, Rückenwind) as an interval factor.
func interval_scale(player: Dictionary) -> float:
	var state := _state(player)
	var scale := 1.0
	var class_id := str(player.get("class_id", ""))
	if float(state.get("rage", 0.0)) > 0.0: scale *= float(ClassPerks.skill_at(class_id, 3).get("rate", 0.5))
	if float(state.get("frenzy", 0.0)) > 0.0: scale *= 1.0 - float(state.get("frenzy_rate", 0.3))
	if float(state.get("tailwind", 0.0)) > 0.0: scale *= 1.0 - float(state.get("tailwind_rate", 0.3))
	return scale


## Rage crit: [chance, multiplier]; [0, 0] outside Rage.
func crit(player: Dictionary) -> Array:
	if float(_state(player).get("rage", 0.0)) <= 0.0: return [0.0, 0.0]
	var skill := ClassPerks.skill_at(str(player.class_id), 3)
	return [float(skill.crit) + ClassPerks.bonus(player, skill, "sharp_blades", "crit"), float(skill.crit_mult) + ClassPerks.bonus(player, skill, "executioner", "crit_mult")]


## Damage factor on an enemy (Jägermal).
func damage_scale(enemy: Dictionary) -> float:
	return 1.0 + float(enemy.get("mark_bonus", 0.0)) if float(enemy.get("marked", 0.0)) > 0.0 else 1.0


## Shields from Phasenschild and Arkanschild; true absorbs the hit.
func absorbs(player: Dictionary) -> bool:
	var state := _state(player)
	if float(state.get("phase_shield", 0.0)) > 0.0:
		state.phase_shield = 0.0
		_event("shield", [Vector2(player.pos)], 0.3)
		return true
	if float(player.get("build", {}).get("arcane_shield", 0.0)) > 0.0 and float(state.get("arcane_cd", 0.0)) <= 0.0:
		state.arcane_cd = 12.0
		_event("shield", [Vector2(player.pos)], 0.3)
		return true
	return false


## A kill: Blutrausch extends Rage, Brandmal makes burning enemies burst.
func enemy_killed(enemy: Dictionary, owner: int) -> void:
	var player: Dictionary = game.players.get(owner, {})
	if not player.is_empty() and str(player.get("class_id", "")) == "swordsman" and float(_state(player).get("rage", 0.0)) > 0.0 and ClassPerks.has(player, "bloodrush"):
		var skill := ClassPerks.skill_at("swordsman", 3)
		var state := _state(player)
		var extend := float(ClassPerks.upgrade(skill, "bloodrush").get("extend", 0.5))
		if float(state.get("rage_bonus", 0.0)) + extend <= float(ClassPerks.upgrade(skill, "bloodrush").get("cap", 3.0)) + 0.001:
			state.rage = float(state.rage) + extend
			state.rage_bonus = float(state.get("rage_bonus", 0.0)) + extend
	var burn: Dictionary = enemy.get("statuses", {}).get("burn", {})
	if burn.is_empty(): return
	var burner: Dictionary = game.players.get(int(burn.get("owner", 0)), {})
	if burner.is_empty() or not ClassPerks.has(burner, "brand"): return
	var fire := ClassPerks.skill_at("mage", 0)
	var brand := ClassPerks.upgrade(fire, "brand")
	_area(int(burn.owner), Vector2(enemy.pos), float(brand.get("radius", 48)), float(burner.damage) * float(fire.damage) * float(brand.get("damage", 0.8)), [int(enemy.id)])
	_event("burst", [Vector2(enemy.pos)], 0.3, {"radius": float(brand.get("radius", 48)), "color": "fire"})


# --- Swordsman ---------------------------------------------------------------

func _whirl(id: int, player: Dictionary, skill: Dictionary, scale: float) -> void:
	var radius := float(skill.radius) * (1.0 + ClassPerks.bonus(player, skill, "wide_swing", "radius"))
	var center := Vector2(player.pos)
	if ClassPerks.has(player, "pull") and scale >= 1.0:
		var pull := ClassPerks.upgrade(skill, "pull")
		for enemy: Dictionary in _enemies_near(center, float(pull.radius)):
			var toward: Vector2 = center - Vector2(enemy.pos)
			if toward.length() > 8.0 and not _heavy(enemy):
				enemy.pos = Dungeon.move_actor(enemy.pos, toward.normalized() * minf(float(pull.distance), toward.length() - 8.0), float(enemy.radius), game.current_layout)
	var damage := float(player.damage) * float(skill.damage) * scale
	game.chests.hit_circle(center, radius, id)
	for enemy: Dictionary in _enemies_near(center, radius):
		var away: Vector2 = (Vector2(enemy.pos) - center).normalized()
		if away.is_zero_approx(): away = Vector2.RIGHT
		_hit(id, enemy, damage, away, center)
		_push(enemy, away * float(skill.knockback))
		if ClassPerks.has(player, "ember_whirl"):
			var ember := ClassPerks.upgrade(skill, "ember_whirl")
			game.perk_combat._status(enemy, "burn", float(ember.dps), float(ember.time), id)
	_state(player).whirl_time = float(skill.duration)
	_event("whirl", [center], float(skill.duration), {"radius": radius})
	if scale >= 1.0 and ClassPerks.has(player, "double_whirl"):
		_delayed.append({"time": float(skill.duration), "kind": "whirl", "id": id, "scale": float(ClassPerks.upgrade(skill, "double_whirl").damage)})


func _wave(id: int, player: Dictionary, skill: Dictionary, aim: Vector2) -> void:
	var heavy := ClassPerks.has(player, "heavy_wave")
	var heavy_data := ClassPerks.upgrade(skill, "heavy_wave")
	var speed := float(skill.speed) * (1.0 + (float(heavy_data.speed) if heavy else 0.0))
	var reach := float(skill.range) * (1.0 + ClassPerks.bonus(player, skill, "far_throw", "range"))
	var size := float(skill.width) * 0.5 * (1.0 + (float(heavy_data.size) if heavy else 0.0))
	var damage := float(player.damage) * float(skill.damage) * (1.0 + (float(heavy_data.damage) if heavy else 0.0))
	var directions: Array = [[aim, 1.0]]
	if ClassPerks.has(player, "wave_fan"):
		var fan := ClassPerks.upgrade(skill, "wave_fan")
		directions = [[aim, float(fan.damage)], [aim.rotated(float(fan.spread)), float(fan.damage)], [aim.rotated(-float(fan.spread)), float(fan.damage)]]
	for entry: Array in directions:
		var direction: Vector2 = entry[0]
		game._add_bullet(Vector2(player.pos) + direction * 18.0, direction * speed, id, damage * float(entry[1]), {
			"skill": "wave", "style": "wave", "radius": size, "wall_radius": 6.0, "pierce": 999, "bounces": 0, "hit_ids": [], "primary": false,
			"no_steer": true, "life": reach / speed, "distance": 0.0, "boomerang": ClassPerks.has(player, "boomerang")})


func _dash(id: int, player: Dictionary, skill: Dictionary, aim: Vector2, kind: String) -> void:
	var distance := float(skill.distance)
	var duration := float(skill.duration)
	_state(player).dash = {"kind": kind, "dir": aim, "speed": distance / duration, "time": duration, "hit": [], "start": Vector2(player.pos)}
	player.invulnerable = maxf(float(player.invulnerable), duration + 0.05)
	_event(kind, [Vector2(player.pos)], duration)


func _dash_step(id: int, player: Dictionary, delta: float) -> void:
	var state := _state(player)
	var dash: Dictionary = state.dash
	var step := minf(delta, float(dash.time))
	var before := Vector2(player.pos)
	player.pos = Dungeon.move_actor(player.pos, Vector2(dash.dir) * float(dash.speed) * step, float(game.balance.player.radius), game.current_layout)
	player.moving = true
	player.motion = (Vector2(player.pos) - before) / maxf(delta, 0.0001)
	dash.time = float(dash.time) - delta
	if str(dash.kind) == "charge":
		var skill := ClassPerks.skill_at("swordsman", 2)
		for enemy: Dictionary in _enemies_near(Vector2(player.pos), float(game.balance.player.radius) + 18.0):
			if int(enemy.id) in dash.hit: continue
			dash.hit.append(int(enemy.id))
			_hit(id, enemy, float(player.damage) * float(skill.damage), Vector2(dash.dir), Vector2(player.pos))
			# the charge flings bodies off its path (Schulterstoß: hard forward, a little aside);
			# one that meets a wall slams into it
			var side := Vector2(dash.dir).orthogonal()
			if side.dot(Vector2(enemy.pos) - Vector2(player.pos)) < 0.0: side = -side
			var side_push := float(_data("sword_feel").get("charge_side_push", 380.0))
			var fling := (side + Vector2(dash.dir) * 0.35).normalized() * side_push
			if ClassPerks.has(player, "shoulder"):
				var shoulder := ClassPerks.upgrade(skill, "shoulder")
				fling = Vector2(dash.dir) * float(shoulder.knockback) + side * side_push * 0.5
				_stun(enemy, float(shoulder.stun))
			_throw(id, player, enemy, fling)
			_event("charge_hit", [Vector2(enemy.pos)], 0.25)
	var blocked := Vector2(player.pos).distance_to(before) < float(dash.speed) * step * 0.3
	if float(dash.time) > 0.0 and not blocked: return
	state.erase("dash")
	if str(dash.kind) == "charge":
		var skill := ClassPerks.skill_at("swordsman", 2)
		if ClassPerks.has(player, "shockwave"):
			var wave := ClassPerks.upgrade(skill, "shockwave")
			for enemy: Dictionary in _enemies_near(Vector2(player.pos), float(wave.radius)):
				_hit(id, enemy, float(player.damage) * float(wave.damage), (Vector2(enemy.pos) - Vector2(player.pos)).normalized(), Vector2(player.pos))
				_stun(enemy, float(wave.stun))
			_event("burst", [Vector2(player.pos)], 0.3, {"radius": float(wave.radius), "color": "stone"})
		if ClassPerks.has(player, "battle_frenzy"):
			var frenzy := ClassPerks.upgrade(skill, "battle_frenzy")
			state.frenzy = float(frenzy.time)
			state.frenzy_rate = float(frenzy.rate)
	elif str(dash.kind) == "backflip":
		var skill := ClassPerks.skill_at("archer", 2)
		if ClassPerks.has(player, "tailwind"):
			var wind := ClassPerks.upgrade(skill, "tailwind")
			state.tailwind = float(wind.time)
			state.tailwind_rate = float(wind.rate)


## True while the swordsman's Rage runs.
func rage_active(player: Dictionary) -> bool:
	return float(_state(player).get("rage", 0.0)) > 0.0


## How far the hero steps into a sword swing (more in Rage); 0 for other classes.
func lunge(player: Dictionary) -> float:
	if not bool(player.get("melee", false)): return 0.0
	var feel := _data("sword_feel")
	return float(feel.get("rage_lunge", 12.0) if rage_active(player) else feel.get("lunge", 8.0))


## A Rage swing hit `enemy`: it is thrown hard and may slam into a wall; a small
## enemy it kills is cut in two along the blade's path (`slice` = cut angle).
func rage_hit(owner: int, player: Dictionary, enemy: Dictionary, direction: Vector2) -> void:
	if float(enemy.hp) <= 0.0:
		if not _heavy(enemy): enemy.slice = direction.angle() + PI * 0.5
		return
	_throw(owner, player, enemy, direction * float(_data("sword_feel").get("rage_push", 520.0)))


## Throws an enemy; for a moment it slams into a wall it is flung against (check_slam).
func _throw(owner: int, player: Dictionary, enemy: Dictionary, velocity: Vector2) -> void:
	_push(enemy, velocity)
	if _heavy(enemy): return
	enemy.slam = {"owner": owner, "time": float(_data("sword_feel").get("slam_window", 0.45)), "damage": float(player.damage) * float(_data("sword_feel").get("slam_damage", 0.8))}


## Called after an enemy's knockback step: a thrown body stopped by a wall
## takes slam damage, is stunned and leaves a dust crack (event "wall_slam").
func check_slam(enemy: Dictionary, before: Vector2, push: Vector2, delta: float) -> void:
	if not enemy.has("slam"): return
	var slam: Dictionary = enemy.slam
	slam.time = float(slam.time) - delta
	if float(slam.time) <= 0.0 or float(enemy.hp) <= 0.0:
		enemy.erase("slam")
		return
	var speed := push.length()
	if speed < float(_data("sword_feel").get("slam_speed", 220.0)): return
	if Vector2(enemy.pos).distance_to(before) >= speed * delta * 0.5: return
	enemy.erase("slam")
	var direction := push.normalized()
	var contact := Vector2(enemy.pos) + direction * float(enemy.get("radius", 12.0))
	_hit(int(slam.owner), enemy, float(slam.damage), -direction, contact)
	_stun(enemy, float(_data("sword_feel").get("slam_stun", 0.6)))
	enemy.knockback = Vector2.ZERO
	_event("wall_slam", [contact], 0.4, {"angle": direction.angle()})


func _rage(player: Dictionary, skill: Dictionary) -> void:
	var state := _state(player)
	state.rage = float(skill.duration)
	state.rage_bonus = 0.0
	_event("rage", [Vector2(player.pos)], 0.5)


# --- Archer ------------------------------------------------------------------

func _arrow(id: int, player: Dictionary, aim: Vector2, damage: float, extra: Dictionary) -> void:
	var build: Dictionary = player.get("build", {})
	var critical := _rng.randf() < float(build.get("crit", 0.0))
	if critical: damage *= float(game.balance.get("perk_rules", {}).get("mechanics", {}).get("crit_multiplier", 1.75))
	var speed := float(player.get("shot_speed", 600.0))
	var metadata := {"pierce": int(build.get("piercer", 0.0)), "bounces": int(build.get("ricochet", 0.0)), "hit_ids": [], "primary": true, "critical": critical,
		"distance": 0.0, "style": "arrow", "life": float(player.get("shot_life", 1.2)), "no_steer": true, "origin": Vector2(player.pos)}
	metadata.merge(extra, true)
	game._add_bullet(Vector2(player.pos) + aim * 14.0, aim * speed, id, damage, metadata)


func _volley(id: int, player: Dictionary, skill: Dictionary, aim: Vector2, scale: float) -> void:
	var count := int(skill.count) + int(ClassPerks.bonus(player, skill, "wide_volley", "count"))
	var spread := float(skill.spread)
	var extra := {"skill": "volley"}
	if ClassPerks.has(player, "poison_tips"):
		var tips := ClassPerks.upgrade(skill, "poison_tips")
		extra.poison = [float(tips.dps), float(tips.time)]
	if ClassPerks.has(player, "splinter"): extra.splinter = true
	for index in range(count):
		var t := (float(index) / float(maxi(count - 1, 1))) - 0.5
		_arrow(id, player, aim.rotated(t * spread), float(player.damage) * float(skill.damage) * scale, extra.duplicate(true))
	_event("volley", [Vector2(player.pos)], 0.2)
	if scale >= 1.0 and ClassPerks.has(player, "double_volley"):
		var double := ClassPerks.upgrade(skill, "double_volley")
		_delayed.append({"time": float(double.delay), "kind": "volley", "id": id, "aim": aim, "scale": float(double.damage)})


func _ballista_fire(id: int, player: Dictionary, skill: Dictionary, charged: float) -> void:
	var charge_time := float(skill.charge) * (1.0 + ClassPerks.bonus(player, skill, "quick_draw", "charge"))
	var ratio := clampf(charged / maxf(charge_time, 0.05), 0.0, 1.0)
	var multiplier := lerpf(float(skill.damage_min), float(skill.damage_max), ratio) * (1.0 + ClassPerks.bonus(player, skill, "heavy_tip", "damage"))
	var aim: Vector2 = Vector2(player.get("aim", Vector2.RIGHT))
	var extra := {"skill": "ballista", "style": "ballista", "pierce": 999, "radius": float(skill.radius), "life": float(skill.range) / float(skill.speed), "charge": ratio}
	if ClassPerks.has(player, "hunters_mark"): extra.mark = true
	if ClassPerks.has(player, "poison_trail"): extra.trail = "poison"
	var build: Dictionary = player.get("build", {})
	var critical := _rng.randf() < float(build.get("crit", 0.0))
	var damage := float(player.damage) * multiplier * (float(game.balance.get("perk_rules", {}).get("mechanics", {}).get("crit_multiplier", 1.75)) if critical else 1.0)
	var metadata := {"bounces": 0, "hit_ids": [], "primary": true, "critical": critical, "distance": 0.0, "no_steer": true}
	metadata.merge(extra, true)
	game._add_bullet(Vector2(player.pos) + aim * 16.0, aim * float(skill.speed), id, damage, metadata)
	_event("ballista", [Vector2(player.pos)], 0.2)


func _backflip(id: int, player: Dictionary, skill: Dictionary, target: Vector2) -> void:
	var away: Vector2 = (Vector2(player.pos) - target).normalized()
	if away.is_zero_approx(): away = -Vector2(player.get("aim", Vector2.RIGHT))
	var slow := float(skill.slow)
	if ClassPerks.has(player, "ice_thorns"): slow = float(ClassPerks.upgrade(skill, "ice_thorns").slow)
	var zone := {"kind": "caltrops", "pos": Vector2(player.pos), "radius": float(skill.caltrop_radius), "time": float(skill.caltrop_time), "owner": id, "slow": slow}
	if ClassPerks.has(player, "blast_trap"):
		var trap := ClassPerks.upgrade(skill, "blast_trap")
		zone.trap = {"radius": float(trap.radius), "damage": float(player.damage) * float(trap.damage)}
	_zone(zone)
	_dash(id, player, skill, away, "backflip")


func _fist_launch(id: int, player: Dictionary, aim: Vector2) -> void:
	var skill := ClassPerks.skill_at("archer", 3)
	game._add_bullet(Vector2(player.pos) + aim * 20.0, aim * float(skill.speed), id, float(player.damage) * float(skill.damage), {
		"skill": "fist", "style": "fist", "radius": float(skill.width) * 0.5, "wall_radius": 8.0, "pierce": 999, "bounces": 0, "hit_ids": [], "primary": false,
		"no_steer": true, "life": float(skill.range) / float(skill.speed), "distance": 0.0, "pushed": []})
	_event("fist", [Vector2(player.pos)], 0.3)


## Pfeilfaust: bursts with slow, breaks walls; `wall` false only with Sprengspitze.
func _fist_burst(owner: int, point: Vector2, wall: bool) -> void:
	var player: Dictionary = game.players.get(owner, {})
	if player.is_empty(): return
	var skill := ClassPerks.skill_at("archer", 3)
	var damage := float(player.damage) * float(skill.burst_damage) * (1.0 + ClassPerks.bonus(player, skill, "wall_breaker", "burst"))
	if not wall: damage *= float(ClassPerks.upgrade(skill, "blast_tip").get("damage", 0.6))
	var slow := float(skill.slow)
	var slow_time := float(skill.slow_time)
	if ClassPerks.has(player, "frost_core"):
		slow = float(ClassPerks.upgrade(skill, "frost_core").slow)
		slow_time += float(ClassPerks.upgrade(skill, "frost_core").time)
	game.chests.hit_circle(point, float(skill.burst_radius), owner)
	for enemy: Dictionary in _enemies_near(point, float(skill.burst_radius)):
		_hit(owner, enemy, damage, (Vector2(enemy.pos) - point).normalized(), point)
		_slow(enemy, slow, slow_time, slow_time, owner)
	if ClassPerks.has(player, "shard_hail"):
		var hail := ClassPerks.upgrade(skill, "shard_hail")
		for index in range(int(hail.count)):
			var direction := Vector2.from_angle(TAU * float(index) / float(hail.count) + 0.3)
			game._add_bullet(point + direction * 10.0, direction * 520.0, owner, float(player.damage) * float(hail.damage), {"style": "shard", "pierce": 0, "bounces": 0, "hit_ids": [], "primary": false, "no_steer": true, "life": 0.5, "distance": 0.0})
	if wall: _break_walls(point, float(_data("walls").get("fist_radius", 52)))
	_event("burst", [point], 0.45, {"radius": float(skill.burst_radius), "color": "frost"})


# --- Mage --------------------------------------------------------------------

func _fireball(id: int, player: Dictionary, skill: Dictionary, aim: Vector2) -> void:
	var count := 1 + ClassPerks.rank(player, "twin_fire")
	var spread := float(ClassPerks.upgrade(skill, "twin_fire").get("spread", 0.22))
	for index in range(count):
		var direction := aim.rotated((float(index) - float(count - 1) * 0.5) * spread)
		var extra := {"skill": "fireball", "style": "fireball", "radius": 7.0, "pierce": 0, "bounces": 0, "hit_ids": [], "primary": false,
			"no_steer": true, "life": float(skill.range) / float(skill.speed), "distance": 0.0}
		if ClassPerks.has(player, "lava_trail"): extra.trail = "lava"
		game._add_bullet(Vector2(player.pos) + direction * 16.0, direction * float(skill.speed), id, float(player.damage) * float(skill.damage), extra)


func _fireball_burst(owner: int, point: Vector2) -> void:
	var player: Dictionary = game.players.get(owner, {})
	if player.is_empty(): return
	var skill := ClassPerks.skill_at("mage", 0)
	var radius := float(skill.radius) * (1.0 + ClassPerks.bonus(player, skill, "wildfire", "radius"))
	game.chests.hit_circle(point, radius, owner)
	for enemy: Dictionary in _enemies_near(point, radius):
		_hit(owner, enemy, float(player.damage) * float(skill.damage), (Vector2(enemy.pos) - point).normalized(), point)
		game.perk_combat._status(enemy, "burn", float(skill.burn_dps), float(skill.burn_time), owner)
	_event("burst", [point], 0.4, {"radius": radius, "color": "fire"})
	game.elements.fire_at(point, radius, owner)


func _chain(id: int, player: Dictionary, skill: Dictionary, target: Vector2, index: int) -> bool:
	var first: Dictionary = {}
	var best := INF
	for enemy: Dictionary in _living():
		if Vector2(enemy.pos).distance_to(player.pos) > float(skill.range): continue
		if Dungeon.segment_blocked(player.pos, enemy.pos, 0.0, game.current_layout): continue
		var d := Vector2(enemy.pos).distance_squared_to(target)
		if d < best:
			best = d
			first = enemy
	if first.is_empty(): return false
	var jumps := int(skill.jumps) + int(ClassPerks.bonus(player, skill, "more_jumps", "jumps"))
	var points: Array = [Vector2(player.pos)]
	var hit: Array = []
	var current := first
	var damage := float(player.damage) * float(skill.damage)
	for step in range(jumps + 1):
		hit.append(int(current.id))
		points.append(Vector2(current.pos))
		var amount := damage * maxf(0.1, 1.0 - float(skill.falloff) * step)
		var statuses: Dictionary = current.get("statuses", {})
		if ClassPerks.has(player, "overload") and (statuses.has("slow") or statuses.has("freeze")): amount *= 1.0 + float(ClassPerks.upgrade(skill, "overload").bonus)
		_hit(id, current, amount, (Vector2(current.pos) - Vector2(points[points.size() - 2])).normalized(), Vector2(current.pos))
		_stun(current, float(skill.stun))
		var next: Dictionary = {}
		var near := INF
		for enemy: Dictionary in _living():
			if int(enemy.id) in hit: continue
			var d := Vector2(enemy.pos).distance_to(current.pos)
			if d <= float(skill.jump_range) and d < near and not Dungeon.segment_blocked(current.pos, enemy.pos, 0.0, game.current_layout):
				near = d
				next = enemy
		if next.is_empty(): break
		current = next
	if ClassPerks.has(player, "storm_field"):
		var field := ClassPerks.upgrade(skill, "storm_field")
		_zone({"kind": "storm", "pos": Vector2(points.back()), "radius": float(field.radius), "time": float(field.time), "owner": id, "dps": float(field.dps), "tick": 0.0})
	_event("chain", points, 0.45)
	# where it struck, a puddle conducts it (boss_moves.electrify)
	for point_index in range(1, points.size()):
		game.boss_moves.electrify(Vector2(points[point_index]), float(game.balance.element.reach), id)
	# Rückkopplung shortens the cooldown that _spent starts next.
	if ClassPerks.has(player, "feedback"):
		_delayed.append({"time": 0.0, "kind": "refund", "id": id, "index": index, "amount": float(ClassPerks.upgrade(skill, "feedback").refund) * float(hit.size() - 1)})
	return true


func _blink(id: int, player: Dictionary, skill: Dictionary, target: Vector2) -> void:
	var start := Vector2(player.pos)
	var offset: Vector2 = target - start
	var distance := minf(offset.length(), float(skill.distance))
	var direction := offset.normalized() if offset.length() > 0.1 else Vector2(player.get("aim", Vector2.RIGHT))
	var radius := float(game.balance.player.radius)
	var landing := start
	var travelled := 8.0
	while travelled <= distance:
		var candidate := start + direction * travelled
		if Dungeon.segment_blocked(start, candidate, radius, game.current_layout): break
		landing = candidate
		travelled += 8.0
	player.pos = landing
	player.invulnerable = maxf(float(player.invulnerable), float(skill.invulnerable))
	_event("blink", [start, landing], 0.35)
	if ClassPerks.has(player, "arcane_rift"):
		var rift := ClassPerks.upgrade(skill, "arcane_rift")
		_area(id, start, float(rift.radius), float(player.damage) * float(rift.damage), [])
		_event("burst", [start], 0.35, {"radius": float(rift.radius), "color": "arcane"})
	if ClassPerks.has(player, "mirror_image"):
		_zone({"kind": "decoy", "pos": start, "radius": 260.0, "time": float(ClassPerks.upgrade(skill, "mirror_image").time), "owner": id})
	if ClassPerks.has(player, "phase_shield"):
		_state(player).phase_shield = float(ClassPerks.upgrade(skill, "phase_shield").time)


func _photon_step(id: int, player: Dictionary, delta: float) -> void:
	var state := _state(player)
	var beam: Dictionary = state.photon
	var skill := ClassPerks.skill_at("mage", 3)
	var desired: float = Vector2(player.get("aim", Vector2.RIGHT)).angle()
	var turn := float(skill.turn) * delta
	beam.angle = float(beam.angle) + clampf(wrapf(desired - float(beam.angle), -PI, PI), -turn, turn)
	beam.time = float(beam.time) + delta
	var direction := Vector2.from_angle(float(beam.angle))
	var start: Vector2 = Vector2(player.pos) + direction * 12.0
	var end := _ray_end(start, direction, float(skill.length))
	beam.from = start
	beam.to = end
	beam.tick = float(beam.tick) + delta
	if float(beam.tick) >= float(skill.tick):
		beam.tick = float(beam.tick) - float(skill.tick)
		var damage := float(player.damage) * float(skill.dps) * float(skill.tick)
		var ignite := float(skill.ignite_dps) * (1.0 + ClassPerks.bonus(player, skill, "ember_core", "ignite"))
		var slow := float(skill.slow)
		var decay := float(skill.slow_decay)
		if ClassPerks.has(player, "frostbite"):
			slow = float(ClassPerks.upgrade(skill, "frostbite").slow)
			decay = float(ClassPerks.upgrade(skill, "frostbite").decay)
		game.chests.hit_segment(start, end, float(skill.width) * 0.5, id)
		var touched := _enemies_on_segment(start, end, float(skill.width) * 0.5)
		for enemy: Dictionary in touched:
			_hit(id, enemy, damage, direction, _closest_on_segment(start, end, enemy.pos))
			game.perk_combat._status(enemy, "burn", ignite, float(skill.ignite_time), id)
			_slow(enemy, slow, decay, decay, id)
		beam.prisms = []
		if ClassPerks.has(player, "prism") and not touched.is_empty():
			var prism := ClassPerks.upgrade(skill, "prism")
			var origin: Vector2 = touched[0].pos
			for side in [-1.0, 1.0]:
				var side_direction := direction.rotated(float(prism.angle) * side)
				var side_end := _ray_end(origin, side_direction, float(prism.length))
				beam.prisms.append([origin.x, origin.y, side_end.x, side_end.y])
				for enemy: Dictionary in _enemies_on_segment(origin, side_end, float(skill.width) * 0.4):
					if int(enemy.id) == int(touched[0].id): continue
					_hit(id, enemy, damage * float(prism.damage), side_direction, enemy.pos)
	# The beam melts an inner wall it rests on.
	if end.distance_to(start) < float(skill.length) - 4.0:
		beam.wall = float(beam.wall) + delta
		if float(beam.wall) >= float(_data("walls").get("beam_break_time", 0.6)):
			beam.wall = 0.0
			_break_walls(end + direction * 14.0, float(_data("walls").get("beam_radius", 34)))
	else:
		beam.wall = 0.0
	if float(beam.time) >= float(beam.max):
		state.erase("photon")
		_cooldown(player, int(beam.index), skill)


# --- Shared helpers -------------------------------------------------------------

func _living() -> Array:
	return game.enemies.filter(func(enemy: Dictionary) -> bool: return float(enemy.hp) > 0.0)


func _enemies_near(point: Vector2, radius: float) -> Array:
	var result: Array = []
	for enemy: Dictionary in _living():
		if Vector2(enemy.pos).distance_to(point) > radius + float(enemy.radius): continue
		if Dungeon.segment_blocked(point, enemy.pos, 0.0, game.current_layout): continue
		result.append(enemy)
	return result


func _enemies_on_segment(from: Vector2, to: Vector2, half_width: float) -> Array:
	var result: Array = []
	for enemy: Dictionary in _living():
		if game.perk_combat.segment_hits(from, to, enemy.pos, half_width + float(enemy.radius)): result.append(enemy)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return from.distance_squared_to(a.pos) < from.distance_squared_to(b.pos))
	return result


func _closest_on_segment(from: Vector2, to: Vector2, point: Vector2) -> Vector2:
	var segment := to - from
	return from + segment * clampf((point - from).dot(segment) / maxf(segment.length_squared(), 0.0001), 0.0, 1.0)


## The last free point of a ray from `start` (walls stop it).
func _ray_end(start: Vector2, direction: Vector2, length: float) -> Vector2:
	var low := 0.0
	var high := length
	if not Dungeon.segment_blocked(start, start + direction * length, 0.0, game.current_layout): return start + direction * length
	for i in range(10):
		var middle := (low + high) * 0.5
		if Dungeon.segment_blocked(start, start + direction * middle, 0.0, game.current_layout): high = middle
		else: low = middle
	return start + direction * low


func _hit(owner: int, enemy: Dictionary, damage: float, direction: Vector2, point: Vector2) -> void:
	if float(enemy.hp) <= 0.0: return
	game.perk_combat._pending_part(enemy, point)
	game._damage_enemy(enemy, damage, direction, owner, true)


func _area(owner: int, point: Vector2, radius: float, damage: float, excluded: Array) -> void:
	game.chests.hit_circle(point, radius, owner)
	for enemy: Dictionary in _enemies_near(point, radius):
		if int(enemy.id) in excluded: continue
		_hit(owner, enemy, damage, (Vector2(enemy.pos) - point).normalized(), point)


func _heavy(enemy: Dictionary) -> bool:
	return bool(enemy.get("boss", false)) or bool(enemy.get("miniboss", false))


func _push(enemy: Dictionary, velocity: Vector2) -> void:
	if float(enemy.hp) <= 0.0: return
	enemy.knockback = velocity * (float(_data("status").get("boss_push_scale", 0.25)) if _heavy(enemy) else 1.0)


func _stun(enemy: Dictionary, time: float) -> void:
	if float(enemy.hp) <= 0.0: return
	enemy.hitstun = maxf(float(enemy.get("hitstun", 0.0)), time * (0.5 if _heavy(enemy) else 1.0))


## Slow that fades linearly from `power` to 0 over `decay` seconds.
func _slow(enemy: Dictionary, power: float, time: float, decay: float, owner: int) -> void:
	if _heavy(enemy): power *= float(_data("status").get("boss_slow_scale", 0.5))
	game.perk_combat._status(enemy, "slow", power, time, owner)
	var status: Dictionary = enemy.get("statuses", {}).get("slow", {})
	if not status.is_empty() and is_equal_approx(float(status.power), power):
		status.start = power
		status.decay = maxf(decay, 0.01)


func _break_walls(point: Vector2, radius: float) -> void:
	var broken := WallBreaker.break_circle(game.current_layout, point, radius)
	if broken.is_empty(): return
	game.walls_broken(broken)


func _zone(zone: Dictionary) -> void:
	zone.id = _next_id
	_next_id += 1
	zones.append(zone)


func _event(kind: String, points: Array, time: float, extra: Dictionary = {}) -> void:
	var event := {"kind": kind, "points": points.map(func(p: Vector2) -> Array: return [p.x, p.y]), "time": time, "length": time, "id": _next_id}
	_next_id += 1
	event.merge(extra, true)
	events.append(event)
	if events.size() > 48: events.pop_front()


# --- Per step -------------------------------------------------------------------

## Cooldowns, timed states, dashes, channels, windups, ground effects, echoes.
func step(delta: float) -> void:
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		var state := _state(player)
		var rage_active := float(state.get("rage", 0.0)) > 0.0
		for index in range(4):
			var rate := 1.0
			if rage_active and index < 3 and ClassPerks.has(player, "unleashed"): rate = float(ClassPerks.upgrade(ClassPerks.skill_at("swordsman", 3), "unleashed").recharge)
			player.skill_cd[index] = maxf(0.0, float(player.skill_cd[index]) - delta * rate)
			if float(player.skill_second[index]) > 0.0:
				player.skill_second[index] = float(player.skill_second[index]) - delta
				if float(player.skill_second[index]) <= 0.0:
					player.skill_second[index] = 0.0
					_cooldown(player, index, _skill(player, index))
		for key: String in ["whirl_time", "rage", "frenzy", "tailwind", "phase_shield", "arcane_cd"]:
			if state.has(key): state[key] = maxf(0.0, float(state[key]) - delta)
		var rage_crit := crit(player)
		player.skill_crit = rage_crit[0]
		player.skill_crit_mult = rage_crit[1]
		player.skill_rate = interval_scale(player)
		if int(player.hp) <= 0:
			for key: String in ["dash", "photon", "ballista", "fist"]: state.erase(key)
			continue
		if state.has("dash"): _dash_step(id, player, delta)
		if state.has("photon"): _photon_step(id, player, delta)
		if state.has("ballista"):
			var skill := ClassPerks.skill_at("archer", 1)
			state.ballista.charge = minf(float(skill.charge) * (1.0 + ClassPerks.bonus(player, skill, "quick_draw", "charge")), float(state.ballista.charge) + delta)
		if state.has("fist"):
			state.fist.time = float(state.fist.time) - delta
			if float(state.fist.time) <= 0.0:
				var aim: Vector2 = state.fist.aim
				state.erase("fist")
				_fist_launch(id, player, aim)
	_step_delayed(delta)
	_step_zones(delta)
	_step_bullets(delta)
	for enemy: Dictionary in game.enemies:
		if float(enemy.get("marked", 0.0)) > 0.0: enemy.marked = maxf(0.0, float(enemy.marked) - delta)
	for index in range(events.size() - 1, -1, -1):
		events[index].time = float(events[index].time) - delta
		if float(events[index].time) <= -0.05: events.remove_at(index)


func _step_delayed(delta: float) -> void:
	for index in range(_delayed.size() - 1, -1, -1):
		var entry: Dictionary = _delayed[index]
		entry.time = float(entry.time) - delta
		if float(entry.time) > 0.0: continue
		_delayed.remove_at(index)
		var player: Dictionary = game.players.get(int(entry.id), {})
		if player.is_empty() or int(player.hp) <= 0: continue
		match str(entry.kind):
			"whirl": _whirl(int(entry.id), player, ClassPerks.skill_at("swordsman", 0), float(entry.scale))
			"volley": _volley(int(entry.id), player, ClassPerks.skill_at("archer", 0), Vector2(entry.aim), float(entry.scale))
			"refund": player.skill_cd[int(entry.index)] = maxf(0.0, float(player.skill_cd[int(entry.index)]) - float(entry.amount))
			"rage_swing":
				if rage_active(player): game.perk_combat.melee(int(entry.id), Vector2(entry.aim), true)
			"echo":
				var saved := float(player.damage)
				player.damage = saved * float(entry.scale)
				game.perk_combat.shoot(int(entry.id), Vector2(entry.aim))
				player.damage = saved


func _step_zones(delta: float) -> void:
	for index in range(zones.size() - 1, -1, -1):
		var zone: Dictionary = zones[index]
		zone.time = float(zone.time) - delta
		var inside := _enemies_near(Vector2(zone.pos), float(zone.radius)) if str(zone.kind) != "decoy" else []
		match str(zone.kind):
			"caltrops":
				for enemy: Dictionary in inside: _slow(enemy, float(zone.slow), 0.3, 0.0, int(zone.owner))
				if zone.has("trap") and not inside.is_empty():
					_area(int(zone.owner), Vector2(zone.pos), float(zone.trap.radius), float(zone.trap.damage), [])
					_event("burst", [Vector2(zone.pos)], 0.35, {"radius": float(zone.trap.radius), "color": "fire"})
					zone.time = 0.0
			"poison":
				for enemy: Dictionary in inside: game.perk_combat._status(enemy, "poison", float(zone.dps), 1.0, int(zone.owner))
			"lava":
				for enemy: Dictionary in inside: game.perk_combat._status(enemy, "burn", float(zone.dps), 1.0, int(zone.owner))
				game.elements.fire_at(Vector2(zone.pos), float(zone.radius), int(zone.owner))
			"storm":
				zone.tick = float(zone.get("tick", 0.0)) + delta
				if float(zone.tick) >= 0.5:
					zone.tick = 0.0
					# the storm's lightning charges the puddles under it
					game.boss_moves.electrify(Vector2(zone.pos), float(zone.radius), int(zone.owner))
					for enemy: Dictionary in inside: _hit(int(zone.owner), enemy, float(zone.dps) * 0.5, Vector2.ZERO, enemy.pos)
		if float(zone.time) <= 0.0: zones.remove_at(index)


## Skill projectiles: trails, the Pfeilfaust pushing what it hit.
func _step_bullets(delta: float) -> void:
	for bullet: Dictionary in game.bullets:
		if not bullet.has("skill"): continue
		if bullet.has("trail"):
			var last: Vector2 = bullet.get("trail_at", bullet.pos)
			if Vector2(bullet.pos).distance_to(last) >= 22.0 or not bullet.has("trail_at"):
				bullet.trail_at = Vector2(bullet.pos)
				var player: Dictionary = game.players.get(int(bullet.owner), {})
				if str(bullet.trail) == "poison":
					var trail := ClassPerks.upgrade(ClassPerks.skill_at("archer", 1), "poison_trail")
					_zone({"kind": "poison", "pos": Vector2(bullet.pos), "radius": float(trail.width) * 0.5 + 6.0, "time": float(trail.time), "owner": int(bullet.owner), "dps": float(trail.dps)})
				elif str(bullet.trail) == "lava" and not player.is_empty():
					var lava := ClassPerks.upgrade(ClassPerks.skill_at("mage", 0), "lava_trail")
					_zone({"kind": "lava", "pos": Vector2(bullet.pos), "radius": float(lava.width) * 0.5 + 6.0, "time": float(lava.time), "owner": int(bullet.owner), "dps": float(lava.dps)})
		if str(bullet.skill) == "fist":
			var skill := ClassPerks.skill_at("archer", 3)
			for enemy: Dictionary in game.enemies:
				if not int(enemy.id) in bullet.pushed or float(enemy.hp) <= 0.0: continue
				var push: Vector2 = Vector2(bullet.velocity) * delta
				if _heavy(enemy):
					var moved := float(enemy.get("fist_moved", 0.0))
					if moved >= float(skill.boss_push): continue
					push = push.limit_length(float(skill.boss_push) - moved)
					enemy.fist_moved = moved + push.length()
				enemy.pos = Dungeon.move_actor(enemy.pos, push, float(enemy.radius), game.current_layout)


## A skill projectile hit an enemy (after the normal damage).
func bullet_hit(bullet: Dictionary, enemy: Dictionary) -> void:
	var owner := int(bullet.owner)
	if bullet.has("poison"): game.perk_combat._status(enemy, "poison", float(bullet.poison[0]), float(bullet.poison[1]), owner)
	if bool(bullet.get("mark", false)):
		var mark := ClassPerks.upgrade(ClassPerks.skill_at("archer", 1), "hunters_mark")
		enemy.marked = float(mark.time)
		enemy.mark_bonus = float(mark.bonus)
	if bool(bullet.get("splinter", false)):
		var player: Dictionary = game.players.get(owner, {})
		var splinter := ClassPerks.upgrade(ClassPerks.skill_at("archer", 0), "splinter")
		if not player.is_empty():
			for side in [-1.0, 1.0]:
				var aim := Vector2(bullet.velocity).normalized().rotated(0.5 * side)
				_arrow(owner, player, aim, float(bullet.damage) * float(splinter.damage), {"skill": "splinter", "hit_ids": [int(enemy.id)], "life": 0.4})
				game.bullets.back().pos = Vector2(enemy.pos) + aim * (float(enemy.radius) + 4.0)
	if str(bullet.get("skill", "")) == "fist" and not int(enemy.id) in bullet.pushed:
		bullet.pushed.append(int(enemy.id))
		enemy.fist_moved = 0.0


## A skill projectile ends. Returns true when it keeps flying (boomerang).
func bullet_end(bullet: Dictionary, hit_wall: bool, previous: Vector2) -> bool:
	var owner := int(bullet.owner)
	match str(bullet.get("skill", "")):
		"wave":
			if bool(bullet.get("boomerang", false)) and not bool(bullet.get("returned", false)) and not hit_wall:
				bullet.returned = true
				bullet.velocity = -Vector2(bullet.velocity)
				bullet.life = float(bullet.get("distance", 200.0)) / maxf(Vector2(bullet.velocity).length(), 1.0)
				bullet.hit_ids = []
				return true
		"fireball": _fireball_burst(owner, Vector2(bullet.pos) if not hit_wall else previous)
		"fist":
			var direction := Vector2(bullet.velocity).normalized()
			if hit_wall: _fist_burst(owner, previous + direction * (float(bullet.get("wall_radius", 8)) + 14.0), true)
			elif ClassPerks.has(game.players.get(owner, {}), "blast_tip"): _fist_burst(owner, Vector2(bullet.pos), false)
	return false


# --- Snapshot ---------------------------------------------------------------------

## HUD and view data of one hero: cooldowns, locks, active states.
func player_state(player: Dictionary) -> Dictionary:
	var state := _state(player)
	var class_id := str(player.get("class_id", ""))
	var locked: Array = []
	for index in range(4): locked.append(not ClassPerks.unlocked(class_id, index, _level()))
	var result := {"cd": Array(player.get("skill_cd", [0, 0, 0, 0])).duplicate(), "max": Array(player.get("skill_cd_max", [1, 1, 1, 1])).duplicate(), "second": Array(player.get("skill_second", [0, 0, 0, 0])).duplicate(), "locked": locked}
	for key: String in ["rage", "whirl_time", "frenzy", "tailwind", "phase_shield"]:
		if float(state.get(key, 0.0)) > 0.0: result[key] = float(state[key])
	# a running dash (Ansturm, Rücksprung): the look draws afterimages
	if state.has("dash"): result.dash = str(state.dash.kind)
	if state.has("ballista"):
		var skill := ClassPerks.skill_at("archer", 1)
		result.charge = clampf(float(state.ballista.charge) / maxf(0.05, float(skill.charge) * (1.0 + ClassPerks.bonus(player, skill, "quick_draw", "charge"))), 0.0, 1.0)
	if state.has("photon"):
		var beam: Dictionary = state.photon
		if beam.has("to"): result.beam = [Vector2(beam.from).x, Vector2(beam.from).y, Vector2(beam.to).x, Vector2(beam.to).y]
		result.beam_prisms = Array(beam.get("prisms", [])).duplicate(true)
		result.beam_left = float(beam.max) - float(beam.time)
	if state.has("fist"):
		var aim: Vector2 = state.fist.aim
		result.fist_aim = [aim.x, aim.y, float(state.fist.time)]
	if state.has("dash"): result.dash = str(state.dash.kind)
	return result


## Ground effects and short events for every client.
func snapshot() -> Dictionary:
	var visible_zones: Array = []
	for zone: Dictionary in zones: visible_zones.append({"id": int(zone.id), "kind": str(zone.kind), "x": Vector2(zone.pos).x, "y": Vector2(zone.pos).y, "r": float(zone.radius), "t": float(zone.time), "look": str(zone.get("look", ""))})
	return {"zones": visible_zones, "events": events.duplicate(true)}
