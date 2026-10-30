extends RefCounted
## Host-side talents in a run (assets/data/talents.json, rules in
## src/progress/talent_rules.gd): each hero's resource (mana, stamina, rage),
## the active talents on the talent bar (keys 1-4) and the ultimate (R),
## cooldowns with a shared 1 s global cooldown, buffs, shields, wolves, traps
## and poison zones, and every passive bonus. Damage goes through the game's
## `_damage_enemy`, so body parts, kills, EXP and perks keep working; statuses
## use the perk status system (burn, poison, bleed, slow, freeze).
## The game calls `outgoing` / `dealt` from `_damage_enemy`, `incoming` from
## `_damage_player`, `enemy_killed` from `_enemy_fell`, and `forced_target`
## while picking enemy targets. Bosses ignore freeze, root and taunts.
## Clients draw `snapshot()` and `player_state(id)`.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const Aggro = preload("res://src/combat/aggro.gd")
const Profile = preload("res://src/progress/profile.gd")
const Rules = preload("res://src/progress/talent_rules.gd")

## Input bits: 4-7 talent bar slots (keys 1-4), 8 the ultimate (R), 9-10 the
## companion's two abilities (keys 5 and 6), 11-12 toggle their auto-cast
## (right-click on the icon), 13 Shift (the class's defense: dodge or block).
const BAR_BIT := 4
const ULT_BIT := 8
const PET_BIT := 9
const PET_AUTO_BIT := 11
const DEFEND_BIT := 13
## Threat key of a companion in an enemy's tally (the same id a decoy gets).
const PET_KEY := -100000
const STATUS_TALENTS := ["burn", "poison", "bleed"]

## The host: the crypt game, or an object with the same members (src/hell/hell_talents.gd).
var game: Object
var data: Dictionary = {}
## Peer id -> runtime {class, ranks, ultimate, soul_tier, bar, res, res_max, regen, cds, gcd, buffs, ...}.
var runtimes: Dictionary = {}
var pets: Array = []
var traps: Array = []
var zones: Array = []
## Mana on the ground: {id, pos, potion, life} (talents.json "mana_orbs").
var orbs: Array = []
## Short visual events: {id, kind, x, y, r, life, ...}.
var events: Array = []
var _next_id := 1
var _rng := RandomNumberGenerator.new()
## True while a talent deals its own damage (not a basic attack).
var _talent_hit := false
## True while a mage talent deals damage (Zeitbruch and Echo apply).
var _spell_hit := false
## The talent dealing the current hit ("" for basic attacks), for talent_pct.
var _cur_talent := ""
## The companion dealing the current hit (-1: a hero), for the threat tally.
var _pet_source := -1


## The class's Shift defense (talents.json "defense"): a fresh state with full charges or hits.
func _defense_state(class_id: String) -> Dictionary:
	var info: Dictionary = data.get("defense", {}).get(class_id, {})
	if info.is_empty(): return {}
	var full := float(info.get("charges", info.get("hits", 1)))
	return {"type": str(info.type), "left": full, "max": full, "timer": 0.0, "broken": 0.0, "up": false, "iframes": 0.0, "held": false}


## Injects the game (no singleton) and loads the talent data once.
func bind(owner: Object, talent_data: Dictionary = {}) -> void:
	game = owner
	if not talent_data.is_empty(): data = talent_data
	elif data.is_empty(): data = Profile.data()


## New run: everything transient goes; builds are set again per player.
func reset(seed_value: int = 0) -> void:
	_rng.seed = seed_value + 5381
	runtimes.clear()
	pets.clear()
	traps.clear()
	zones.clear()
	orbs.clear()
	events.clear()


## Leaving a room: summons, traps and zones stay behind, channels end. A
## permanent companion comes along and appears beside its hero.
func room_changed() -> void:
	orbs.clear()
	pets = pets.filter(func(p: Dictionary) -> bool: return bool(p.get("permanent", false)))
	for pet: Dictionary in pets:
		var owner: Dictionary = game.players.get(int(pet.owner), {})
		if not owner.is_empty(): pet.pos = Vector2(owner.pos) + Vector2(-24, 14)
		pet.target = -1
	traps.clear()
	zones.clear()
	for rt: Dictionary in runtimes.values():
		rt.channel = {}
		rt.counter = {}
		rt.after = []


## Sets a hero's talents from a profile build ({class, level, ranks, ultimate,
## soul_tier, bar}); the build is checked against the rules first, so a forged
## build never gives more than the level allows.
## `keep`: a new build mid-run (talent menu on K) keeps the hero's resource and
## cooldowns, so changing talents never refills mana.
func set_build(id: int, build: Dictionary, keep: bool = false) -> void:
	var class_id := str(build.get("class", ""))
	if not data.get("resources", {}).has(class_id): return
	var profile := Profile.fresh(data)
	var state := Profile.class_state(profile, class_id)
	state.level = clampi(int(build.get("level", 1)), 1, int(data.max_level))
	for talent: Variant in build.get("ranks", {}):
		var info: Dictionary = data.talents.get(str(talent), {})
		if not info.is_empty() and str(info["class"]) == class_id: state.ranks[str(talent)] = clampi(int(build.ranks[talent]), 0, int(info.ranks))
	Rules.repair(data, profile, class_id)
	var ultimate := ""
	for talent: String in state.ranks:
		if str(data.talents[talent].kind) == "ultimate": ultimate = talent
	var bar: Array = []
	for talent: Variant in build.get("bar", []):
		if state.ranks.has(str(talent)) and str(data.talents[str(talent)].kind) == "active" and bar.size() < int(data.bar_slots): bar.append(str(talent))
	var res: Dictionary = data.resources[class_id]
	var rt := {"class": class_id, "ranks": state.ranks, "ultimate": ultimate, "soul_tier": clampi(int(build.get("soul_tier", 0)), 0, (data.soul_shards.tier_costs as Array).size()) if not ultimate.is_empty() else 0,
		"bar": bar, "level": state.level, "res_kind": str(res.kind), "res_max": float(res.max), "regen": float(res.regen), "cds": {}, "gcd": 0.0,
		"buffs": {}, "shield": 0.0, "shield_time": 0.0, "counter": {}, "channel": {}, "after": [], "echo": 0.0, "casts": 0, "prev_bits": 0,
		"debt_in": 0.0, "debt_heal": 0.0, "debt_ally": 0.0, "guard_cd": 0.0, "pet_target": -1, "companion": _companion(str(build.get("companion", ""))),
		"pet_auto": [true, true], "pet_cds": {}, "hero_target": -1, "defense": _defense_state(class_id)}
	var bonus := _passive(rt, "resource_bonus")
	if not bonus.is_empty():
		rt.res_max += _value(bonus, "max", rt)
		rt.regen *= 1.0 + _value(bonus, "regen_pct", rt) / 100.0
	rt.res = float(res.start) if str(res.kind) == "rage" else rt.res_max
	var before: Dictionary = runtimes.get(id, {})
	if not before.is_empty():
		rt.pet_auto = before.pet_auto
		rt.pet_cds = before.pet_cds
		# a new build mid-run (talent menu on K): no free refill, no reset cooldowns
		if keep and str(before["class"]) == class_id:
			rt.res = minf(float(before.res), float(rt.res_max))
			rt.cds = before.cds
			rt.gcd = float(before.gcd)
	runtimes[id] = rt
	# A learned permanent companion is there from the start of a run (and stays).
	for talent: String in state.ranks:
		if bool(data.talents[talent].get("permanent", false)): rt.permanent = talent
	for pet: Dictionary in _own_pets(id).filter(func(p: Dictionary) -> bool: return bool(p.get("permanent", false))):
		if str(pet.talent) != str(rt.get("permanent", "")): pets.erase(pet)
	if rt.has("permanent") and permanent_pet(id).is_empty() and game.players.has(id) and not bool(before.get("pet_fell", false)):
		_spawn_pet(id, rt, str(rt.permanent), data.talents[str(rt.permanent)], Vector2(game.players[id].pos) + Vector2(-24, 14), false, INF)


func runtime(id: int) -> Dictionary:
	return runtimes.get(id, {})


## Reads the talent bits of a hero's command (edge-triggered: one cast per press).
func handle_input(id: int, player: Dictionary, command: Dictionary) -> void:
	var rt := runtime(id)
	if rt.is_empty() or int(player.hp) <= 0: return
	var bits := int(command.get("skills", 0))
	var pressed := bits & ~int(rt.prev_bits)
	rt.prev_bits = bits
	var target: Vector2 = Vector2(command.get("target", Vector2.INF))
	var drawing: Dictionary = rt.get("drawing", {})
	var draw_held := not drawing.is_empty() and bits & (1 << (BAR_BIT + int(drawing.get("slot", 0)))) != 0
	hold(id, draw_held, bits & (1 << DEFEND_BIT) != 0, target, Vector2(command.get("move", Vector2.ZERO)))
	for slot in range(int(data.bar_slots)):
		if pressed & (1 << (BAR_BIT + slot)) and slot < rt.bar.size():
			var keyed := command.duplicate()
			keyed.slot = slot
			cast(id, str(rt.bar[slot]), keyed)
	if pressed & (1 << ULT_BIT) and not str(rt.ultimate).is_empty(): cast(id, str(rt.ultimate), command)
	for slot in range(2):
		if pressed & (1 << (PET_BIT + slot)): pet_cast(id, slot, true)
		if pressed & (1 << (PET_AUTO_BIT + slot)): toggle_pet_auto(id, slot)


## Keys held down: a drawn talent (Flammenmeer) follows the mouse `target`
## while its key stays down; Shift (`defend`) rolls out of the way or holds
## the block up (talents.json "defense"). Called every input tick.
func hold(id: int, draw_held: bool, defend: bool, target: Vector2, move: Vector2) -> void:
	var rt := runtime(id)
	if rt.is_empty() or not game.players.has(id): return
	var player: Dictionary = game.players[id]
	if rt.has("drawing"): _draw_step(id, player, rt, draw_held, target)
	var guard: Dictionary = rt.get("defense", {})
	if guard.is_empty(): return
	var info: Dictionary = data.defense[str(rt["class"])]
	var pressed := defend and not bool(guard.held)
	guard.held = defend
	if str(guard.type) == "dodge":
		if not pressed or float(guard.left) < 1.0 or int(player.hp) <= 0: return
		var dir := move if move.length() > 0.1 else Vector2(player.get("aim", Vector2.RIGHT))
		if dir.length() < 0.1: dir = Vector2.RIGHT
		var from: Vector2 = player.pos
		player.pos = _move(player.pos, dir.normalized() * float(info.dist_m) * float(data.meter_px), float(game.balance.player.radius), game.current_layout)
		guard.left = float(guard.left) - 1.0
		guard.iframes = float(info.iframes)
		_event("dodge", from, 0.0, {"tx": player.pos.x, "ty": player.pos.y, "life": 0.35})
		return
	guard.up = defend and float(guard.broken) <= 0.0 and float(guard.left) >= 1.0 and int(player.hp) > 0


## While a drawn talent's key is held, its line grows towards the mouse until
## its length (the fill bar) is used up; on release (or when used up, or after
## draw_time) the fire takes hold along the line.
func _draw_step(id: int, player: Dictionary, rt: Dictionary, held: bool, target: Vector2) -> void:
	var drawing: Dictionary = rt.drawing
	var meter := float(data.meter_px)
	if held and target.is_finite() and float(drawing.left) > 0.0:
		var point := Vector2(player.pos) + (target - Vector2(player.pos)).limit_length(9.0 * meter)
		var last: Vector2 = drawing.points[-1]
		var gap := last.distance_to(point)
		if gap >= 6.0:
			var reach := minf(gap, float(drawing.left))
			drawing.points.append(last + (point - last).normalized() * reach)
			drawing.left = float(drawing.left) - reach
	if not held or float(drawing.left) <= 0.0 or float(drawing.time) <= 0.0: _finish_draw(id, player, rt)


## The drawn line becomes a burning zone along all its points.
func _finish_draw(id: int, player: Dictionary, rt: Dictionary) -> void:
	var drawing: Dictionary = rt.drawing
	rt.erase("drawing")
	var info: Dictionary = drawing.info
	var meter := float(data.meter_px)
	var points: Array = drawing.points
	if points.size() < 2:
		# a tap without drawing: a short line across the aim
		var aim := Vector2(player.get("aim", Vector2.RIGHT)).normalized()
		var at: Vector2 = points[0]
		points = [at - aim.orthogonal() * 1.5 * meter, at + aim.orthogonal() * 1.5 * meter]
	var middle := Vector2.ZERO
	for point: Vector2 in points: middle += point
	middle /= points.size()
	var reach := 0.0
	for point: Vector2 in points: reach = maxf(reach, middle.distance_to(point))
	zones.append({"id": _take_id(), "owner": id, "talent": str(drawing.talent), "pos": middle, "r": reach, "time": float(info.time), "every": float(info.every), "tick": 0.0,
		"dmg": float(drawing.dmg), "status": str(info.get("status", "")), "info": info, "look": str(info.get("look", "flames")),
		"path": points, "w": float(info.width_m) * meter * 0.5})
	_event("drawn", middle, reach, {"life": 0.5})


## Why `talent` cannot be cast now, or "".
func cast_blocker(id: int, talent: String) -> String:
	var rt := runtime(id)
	var info: Dictionary = data.talents.get(talent, {})
	if rt.is_empty() or info.is_empty() or int(rt.ranks.get(talent, 0)) <= 0: return "nicht gelernt"
	if str(info.kind) == "passive": return "passiv"
	if float(rt.cds.get(talent, 0.0)) > 0.0: return "Abklingzeit"
	if float(rt.gcd) > 0.0: return "Abklingzeit"
	if float(rt.res) < cost_of(rt, talent): return "zu wenig " + str(data.resources[rt["class"]].name)
	if str(info.type) == "pet_leap" and _own_pets(id).is_empty(): return "kein Begleiter aktiv"
	if bool(info.get("permanent", false)) and not permanent_pet(id).is_empty(): return "Begleiter lebt noch"
	return ""


## Casts an active talent or the ultimate: spends the resource, starts the
## cooldowns and runs the effect. Returns true when it fired.
func cast(id: int, talent: String, command: Dictionary = {}) -> bool:
	var blocked := cast_blocker(id, talent)
	if not blocked.is_empty():
		# a press without enough resource says so over the hero ("Wenig Mana"), at most every 0.8 s
		var rt_blocked := runtime(id)
		if blocked.begins_with("zu wenig") and not rt_blocked.is_empty() and float(rt_blocked.get("hint_cd", 0.0)) <= 0.0 and game.players.has(id):
			rt_blocked.hint_cd = 0.8
			_event("no_res", game.players[id].pos, 0.0, {"text": "Wenig " + str(data.resources[rt_blocked["class"]].name), "res": str(rt_blocked.res_kind), "life": 0.9})
		return false
	var player: Dictionary = game.players[id]
	var rt := runtime(id)
	var info := _info(rt, talent)
	# Mana is spent even in the talent test profile, so its feel can be tested
	# (user decision 30.10.2026). The ultimate keeps its full minute.
	rt.res = float(rt.res) - cost_of(rt, talent)
	var cooldown := float(info.cd)
	if str(info.kind) != "ultimate":
		cooldown *= maxf(0.4, 1.0 - _sum(rt, "cdr_pct", "pct") / 100.0)
		if rt.buffs.has("timebreak"): cooldown *= 1.0 - float(rt.buffs.timebreak.cdr_pct) / 100.0
	rt.cds[talent] = cooldown
	rt.gcd = float(data.global_cooldown)
	rt.cast_count = int(rt.get("cast_count", 0)) + 1
	var aim: Vector2 = Vector2(command.get("aim", player.get("aim", Vector2.RIGHT)))
	if aim.length_squared() < 0.01: aim = Vector2.RIGHT
	aim = aim.normalized()
	var target: Vector2 = Vector2(command.get("target", Vector2.INF))
	if not target.is_finite(): target = Vector2(player.pos) + aim * 160.0
	var spell: bool = str(rt["class"]) == "mage"
	rt._slot = int(command.get("slot", 0))
	_spell_hit = spell
	_run(id, player, rt, talent, info, aim, target, 1.0)
	_stage_effects(id, player, rt, talent, info)
	_spell_hit = false
	# Arkaner Kreislauf: every third spell that costs mana gives some back.
	var refund := _passive(rt, "refund")
	if not refund.is_empty() and float(info.cost) > 0.0:
		rt.casts = int(rt.casts) + 1
		if int(rt.casts) % int(refund.every) == 0: rt.res = minf(float(rt.res_max), float(rt.res) + _value(refund, "amount", rt))
	# Magisches Echo: the next damaging spell repeats once, free and without a new echo.
	if spell and float(rt.echo) > 0.0 and info.has("dmg") and str(info.type) != "echo":
		rt.echo_cast = {"talent": talent, "scale": float(rt.echo) / 100.0, "time": 0.35, "aim": aim, "target": target}
		rt.echo = 0.0
	_event("cast", player.pos, 0.0, {"talent": talent, "owner": id})
	return true


func _run(id: int, player: Dictionary, rt: Dictionary, talent: String, info: Dictionary, aim: Vector2, target: Vector2, scale: float) -> void:
	var meter := float(data.meter_px)
	var base := float(player.get("damage", 1.0)) * scale * _soul(rt, talent, "damage")
	var dmg := _value(info, "dmg", rt, talent) * base
	_talent_hit = true
	match str(info.type):
		"projectile":
			var style := str(info.get("style", "arcane"))
			# an ultimate stage may fan the shot out (Pfeilsturm)
			var fan: Dictionary = info.get("fan", {})
			var count := maxi(1, int(fan.get("count", 1)))
			for k in range(count):
				var dir := aim.rotated((float(k) - float(count - 1) * 0.5) * float(fan.get("spread", 0.0)))
				var shot: Dictionary = game._add_bullet(Vector2(player.pos) + dir * 16.0, dir * (560.0 if style == "arrow" else 440.0), id, dmg,
					{"talent": talent, "style": style, "primary": false, "radius": 6.0, "pierce": int(info.get("pierce", 1)) - 1, "life": 1.6})
				if not shot.is_empty(): shot.always_crit = bool(info.get("always_crit", false))
		"nova":
			var radius := float(info.radius_m) * meter
			_area(id, rt, talent, info, Vector2(player.pos), radius, dmg)
			# ultimates play longer (the inferno column, absolute zero)
			_event("nova", player.pos, radius, {"fx": str(info.get("fx", "fire")), "talent": talent, "life": 0.9 if str(info.kind) == "ultimate" else 0.5})
		"blink":
			var origin: Vector2 = player.pos
			var distance := _value(info, "dist_m", rt, talent) * meter
			player.pos = _move(player.pos, aim * distance, float(game.balance.player.radius), game.current_layout)
			if info.has("dmg"): _area(id, rt, talent, info, origin, float(info.get("radius_m", 2)) * meter, dmg)
			if info.has("dmg") and bool(info.get("arrive", false)): _area(id, rt, talent, info, Vector2(player.pos), float(info.get("radius_m", 2)) * meter, dmg)
			if bool(info.get("cleanse", false)) and game.has_method("cleanse_slows"): game.cleanse_slows(id)
			_event("blink", origin, 0.0, {"tx": player.pos.x, "ty": player.pos.y, "fx": str(info.get("fx", "arcane")), "talent": talent, "life": 0.8 if talent == "fire_5" else 0.5})
		"dash":
			var from: Vector2 = player.pos
			player.pos = _move(player.pos, aim * _value(info, "dist_m", rt, talent) * meter, float(game.balance.player.radius), game.current_layout)
			for enemy: Dictionary in _living():
				if Geometry2D.get_closest_point_to_segment(enemy.pos, from, player.pos).distance_to(enemy.pos) <= float(enemy.radius) + 22.0:
					_hit(id, enemy, dmg, info, rt, talent)
			_event("dash", from, 0.0, {"tx": player.pos.x, "ty": player.pos.y, "talent": talent})
		"melee":
			var reach := float(info.reach_m) * meter
			for enemy: Dictionary in _living():
				var offset: Vector2 = enemy.pos - player.pos
				if offset.length() > reach + float(enemy.radius) or absf(aim.angle_to(offset)) > float(info.arc) * 0.5: continue
				if _blocked(player.pos, enemy.pos, 0.0, game.current_layout): continue
				_hit(id, enemy, dmg, info, rt, talent)
				if info.has("taunt"): _taunt(enemy, id, float(info.taunt))
			_event("swing", player.pos, reach, {"angle": aim.angle(), "arc": float(info.arc), "talent": talent})
		"shield":
			rt.shield = _value(info, "base_pct", rt, talent) / 100.0 * float(player.get("damage", 1.0))
			rt.shield_time = float(info.time)
		"buff":
			var buff: Dictionary = {"time": float(info.time)}
			for key: String in ["spell_pct", "cdr_pct", "attack_speed_pct", "damage_pct", "lifesteal_pct", "taken_pct", "reduction_pct", "ally_pct", "solo_reduction_pct", "range_m"]:
				if info.has(key): buff[key] = _value(info, key, rt, talent) * (_soul(rt, talent, "power") if key in ["damage_pct", "lifesteal_pct"] else 1.0)
			buff.cc_immune = bool(info.get("cc_immune", false))
			rt.buffs[str(info.buff)] = buff
			_event("buff", player.pos, 30.0, {"buff": str(info.buff)})
		"echo":
			rt.echo = _value(info, "pct", rt, talent)
		"wall":
			# Flammenwall: a line of fire across the aim at the target; it burns what touches it
			var spot := _spot(player, target, info)
			var across := aim.orthogonal() * float(info.length_m) * meter * 0.5
			zones.append({"id": _take_id(), "owner": id, "talent": talent, "pos": spot, "r": float(info.length_m) * meter * 0.5, "time": float(info.time),
				"every": float(info.every), "tick": 0.0, "dmg": dmg, "status": str(info.get("status", "")), "info": {"status": str(info.get("status", ""))},
				"wall": {"a": spot - across, "b": spot + across, "w": float(info.width_m) * meter * 0.5}, "look": "firewall"})
		"chain":
			# Glutkette: hits the enemy at the target, then jumps on to the nearest ones
			var first := _nearest(target, 3.0 * meter)
			if first.is_empty(): first = _nearest(player.pos, float(info.reach_m) * meter)
			var points: Array = [[player.pos.x, player.pos.y]]
			var hit_ids := {}
			var current := first
			var strength := dmg
			for k in range(int(info.jumps) + 1):
				if current.is_empty(): break
				_hit(id, current, strength, info, rt, talent)
				hit_ids[int(current.id)] = true
				points.append([current.pos.x, current.pos.y])
				var next := {}
				var best := float(info.jump_m) * meter
				for other: Dictionary in _living():
					if hit_ids.has(int(other.id)): continue
					var gap: float = Vector2(other.pos).distance_to(current.pos)
					if gap <= best:
						best = gap
						next = other
				current = next
				strength *= float(info.falloff)
			_event("chain", player.pos, 0.0, {"points": points, "life": 0.7})
		"meteor":
			# Meteor: a shadow grows at the target, the rock lands after `delay`
			var spot := _spot(player, target, info)
			var radius := float(info.radius_m) * meter
			_event("meteor_fall", spot, radius, {"life": float(info.delay), "big": true})
			rt.after.append({"time": float(info.delay), "pos": spot, "dmg": dmg, "r": radius, "fx": "fire", "status": str(info.get("status", "")), "talent": talent,
				"crater": info.get("crater", {}), "shower": info.get("shower", {}), "base": base, "impact": true})
		"glacier":
			# Gletschergrab: an ice block that slows and chills; its middle freezes
			var spot := _spot(player, target, info)
			var radius := float(info.radius_m) * meter
			var shatter: Dictionary = info.get("shatter", {})
			zones.append({"id": _take_id(), "owner": id, "talent": talent, "pos": spot, "r": radius, "time": float(info.time), "every": float(info.every), "tick": 0.0,
				"dmg": dmg, "status": "", "look": "ice", "info": {"slow": float(info.slow), "slow_time": float(info.slow_time)},
				"on_end": {} if shatter.is_empty() else {"dmg": float(shatter.dmg) * base, "r": float(shatter.radius_m) * meter, "fx": "ice",
					"info": {"freeze": float(shatter.freeze), "boss_slow": float(shatter.boss_slow), "boss_slow_time": float(shatter.boss_slow_time)}}})
			for enemy: Dictionary in _living():
				if Vector2(enemy.pos).distance_to(spot) <= float(info.freeze_center_m) * meter + float(enemy.radius):
					_apply_status(id, enemy, {"freeze": float(info.freeze), "boss_slow": float(info.boss_slow), "boss_slow_time": float(info.boss_slow_time)}, rt, talent)
			_event("nova", spot, radius, {"fx": "ice", "talent": talent, "life": 0.7})
		"singularity":
			# Singularität: a whirl that pulls (never bosses), then collapses
			var spot := _spot(player, target, info)
			var collapse: Dictionary = info.collapse
			zones.append({"id": _take_id(), "owner": id, "talent": talent, "pos": spot, "r": float(info.radius_m) * meter, "time": float(info.time), "every": float(info.every),
				"tick": 0.0, "dmg": dmg, "status": "", "look": "arcane", "pull": float(info.pull), "info": {},
				"on_end": {"dmg": float(collapse.dmg) * base, "r": float(collapse.radius_m) * meter, "fx": "arcane", "reset_cds": bool(collapse.get("reset_cds", false)), "info": {}}})
		"line":
			# Himmelsspeer: a giant arrow through everything in a line, up to a wall
			var end := _move(player.pos, aim * float(info.length_m) * meter, 4.0, game.current_layout)
			var half := float(info.width_m) * meter * 0.5
			rt.force_crit = bool(info.get("always_crit", false))
			var mark: Dictionary = info.get("mark", {})
			for enemy: Dictionary in _living():
				if Geometry2D.get_closest_point_to_segment(enemy.pos, player.pos, end).distance_to(enemy.pos) > half + float(enemy.radius): continue
				_hit(id, enemy, dmg, info, rt, talent)
				if not mark.is_empty() and float(enemy.hp) > 0.0: enemy.talent_mark = {"owner": id, "pct": float(mark.pct), "time": float(mark.time)}
			rt.force_crit = false
			_event("spear", player.pos, 0.0, {"tx": end.x, "ty": end.y, "life": 0.6})
			var burst: Dictionary = info.get("end_burst", {})
			if not burst.is_empty():
				_area(id, rt, talent, {}, end, float(burst.radius_m) * meter, float(burst.dmg) * base)
				_event("nova", end, float(burst.radius_m) * meter, {"fx": str(burst.get("fx", "fire")), "talent": talent, "life": 0.7})
		"net":
			# Jagdgrund: a net holds everything (bosses slow down), traps around it
			var spot := _spot(player, target, info)
			var radius := float(info.radius_m) * meter
			for enemy: Dictionary in _living():
				if Vector2(enemy.pos).distance_to(spot) > radius + float(enemy.radius): continue
				if _boss(enemy): _status(enemy, "slow", float(info.boss_slow), float(info.boss_slow_time), id)
				else: _status(enemy, "slow", 1.0, float(info.root), id)
			var count := int(_value(info, "traps", rt, talent))
			var cloud: Dictionary = info.get("trap_cloud", {})
			for k in range(count):
				var at := spot + Vector2.from_angle(TAU * k / count) * radius * 0.65
				traps.append({"id": _take_id(), "owner": id, "talent": talent, "pos": at, "r": float(info.trap_radius_m) * meter, "trigger": 28.0,
					"dmg": _value(info, "trap_dmg", rt, talent) * base * (1.0 + _sum(rt, "trap_bonus", "pct") / 100.0), "root": 0.0, "life": float(data.trap_life),
					"cloud": {} if cloud.is_empty() else {"time": float(cloud.time), "every": float(cloud.every), "dmg": float(cloud.dmg) * base, "r": float(cloud.radius_m) * meter, "status": str(cloud.status)}})
			_event("net", spot, radius, {"life": 0.9})
		"awaken":
			_awaken(id, player, rt, talent, info, base)
		"leap":
			# Erdspalter: a leap onto the target, the impact, then the fury
			var from: Vector2 = player.pos
			player.pos = _move(player.pos, (target - Vector2(player.pos)).limit_length(float(info.reach_m) * meter), float(game.balance.player.radius), game.current_layout)
			var radius := float(info.radius_m) * meter
			_area(id, rt, talent, info, Vector2(player.pos), radius, dmg)
			_event("leap_slam", from, radius, {"tx": player.pos.x, "ty": player.pos.y, "life": 0.6})
			var fury: Dictionary = info.get("fury", {})
			if not fury.is_empty(): rt.buffs["fury"] = {"time": float(fury.time), "damage_pct": float(fury.damage_pct), "lifesteal_pct": float(fury.get("lifesteal_pct", 0.0))}
		"bulwark":
			# Bollwerk: everyone near is taunted, the hero hardens (and maybe bites back)
			var radius := float(info.radius_m) * meter
			for enemy: Dictionary in _living():
				if Vector2(enemy.pos).distance_to(player.pos) <= radius: _taunt(enemy, id, float(info.taunt))
			rt.buffs["unbreakable"] = {"time": float(info.time), "reduction_pct": float(info.reduction_pct), "cc_immune": true, "thorns": float(info.get("thorns", 0.0)) * base}
			_event("shout", player.pos, radius, {})
			_event("buff", player.pos, 30.0, {"buff": "unbreakable"})
		"harvest":
			# Seelenernte: every hit heals and gives mana; weak normal enemies fall at once
			var radius := float(info.radius_m) * meter
			for enemy: Dictionary in _living():
				if Vector2(enemy.pos).distance_to(player.pos) > radius + float(enemy.radius): continue
				_hit(id, enemy, dmg, info, rt, talent)
				_heal(id, rt, float(player.get("max_hp", 1)) * float(info.heal_pct) / 100.0)
				if str(rt.res_kind) == "mana": rt.res = minf(float(rt.res_max), float(rt.res) + float(info.mana))
				if float(enemy.hp) > 0.0 and not _boss(enemy) and not bool(enemy.get("miniboss", false)) and float(enemy.hp) <= float(enemy.get("max_hp", enemy.hp)) * float(info.execute_pct) / 100.0:
					game._damage_enemy(enemy, float(enemy.hp) + 1.0, (Vector2(enemy.pos) - Vector2(player.pos)).normalized(), id, true)
				_event("soul", enemy.pos, 0.0, {"tx": player.pos.x, "ty": player.pos.y, "life": 0.7})
			_event("nova", player.pos, radius, {"fx": "arcane", "talent": talent, "life": 0.9})
		"mark":
			var enemy := _nearest(target, 96.0)
			if enemy.is_empty(): enemy = _nearest(player.pos, 420.0)
			if not enemy.is_empty():
				enemy.talent_mark = {"owner": id, "pct": _value(info, "pct", rt, talent), "time": _value(info, "time", rt, talent)}
				_event("mark", enemy.pos, 20.0, {"talent": talent})
		"trap":
			var spot: Vector2 = player.pos + (target - player.pos).limit_length(6.0 * meter)
			spot = _move(player.pos, spot - player.pos, 10.0, game.current_layout)
			var mine := traps.filter(func(t: Dictionary) -> bool: return int(t.owner) == id)
			if mine.size() >= int(data.max_traps): traps.erase(mine[0])
			traps.append({"id": _take_id(), "owner": id, "talent": talent, "pos": spot, "r": float(info.radius_m) * meter, "trigger": 28.0,
				"dmg": dmg * (1.0 + _sum(rt, "trap_bonus", "pct") / 100.0), "root": _value(info, "root", rt, talent), "life": float(data.trap_life)})
		"drawn":
			# Flammenmeer: the line starts at the mouse; hold() draws the rest
			var start: Vector2 = player.pos + (target - player.pos).limit_length(9.0 * meter)
			rt.drawing = {"talent": talent, "slot": int(rt.get("_slot", 0)), "points": [start], "left": float(info.length_m) * meter, "max": float(info.length_m) * meter,
				"time": float(info.get("draw_time", 2.5)), "info": info, "dmg": dmg}
		"zone":
			var spot: Vector2 = player.pos + (target - player.pos).limit_length(7.0 * meter)
			zones.append({"id": _take_id(), "owner": id, "talent": talent, "pos": spot, "r": float(info.radius_m) * meter, "time": float(info.time),
				"every": maxf(0.25, float(info.every)), "tick": 0.0, "dmg": dmg, "status": str(info.get("status", "")), "info": info,
				"weaken": float(info.get("weaken", 0.0)), "raise": info.get("raise", {}), "look": str(info.get("look", ""))})
		"summon":
			if bool(info.get("permanent", false)):
				# a permanent companion: called anew only after it fell (cast_blocker)
				for pet: Dictionary in _own_pets(id).filter(func(p: Dictionary) -> bool: return bool(p.get("permanent", false))): pets.erase(pet)
				rt.pet_fell = false
				_spawn_pet(id, rt, talent, info, player.pos + aim * 24.0, false, INF)
				_event("summon", player.pos + aim * 24.0, 22.0, {"kind": str(info.get("pet_kind", rt.get("companion", "wolf")))})
				_talent_hit = false
				return
			var mine := _own_pets(id).filter(func(p: Dictionary) -> bool: return not bool(p.get("permanent", false)))
			var wanted := int(info.count)
			if bool(info.get("pack", false)) and mine.filter(func(p: Dictionary) -> bool: return not bool(p.pack)).is_empty() and permanent_pet(id).is_empty():
				_spawn_pet(id, rt, talent, info, player.pos, false, float(info.time))
			if not bool(info.get("pack", false)):
				for pet: Dictionary in mine.filter(func(p: Dictionary) -> bool: return not bool(p.pack)): pets.erase(pet)
			for i in range(wanted): _spawn_pet(id, rt, talent, info, player.pos + Vector2.RIGHT.rotated(TAU * i / wanted) * 20.0, bool(info.get("pack", false)), float(info.time))
		"pet_leap":
			var enemy := _nearest(target, 120.0)
			if enemy.is_empty(): enemy = _nearest(player.pos, 360.0)
			if not enemy.is_empty():
				var pet: Dictionary = _own_pets(id)[0]
				var from: Vector2 = pet.pos
				pet.pos = _move(pet.pos, (enemy.pos - pet.pos) * 0.85, 10.0, game.current_layout)
				pet.target = int(enemy.id)
				rt.pet_target = int(enemy.id)
				_hit(id, enemy, dmg, info, rt, talent)
				for other: Dictionary in _living():
					if not _boss(other) and other.pos.distance_to(pet.pos) < 5.0 * meter: other.pet_taunt = {"pet": int(pet.id), "time": float(info.taunt)}
				_event("leap", from, 0.0, {"tx": pet.pos.x, "ty": pet.pos.y})
		"taunt_area":
			var radius := float(info.radius_m) * meter
			for enemy: Dictionary in _living():
				if enemy.pos.distance_to(player.pos) <= radius: _taunt(enemy, id, float(info.taunt))
			rt.res = minf(float(rt.res_max), float(rt.res) + _value(info, "rage", rt, talent))
			_event("shout", player.pos, radius, {})
		"counter":
			rt.counter = {"time": float(info.window), "dmg": dmg, "radius": float(info.radius_m) * meter, "talent": talent}
		"channel":
			rt.channel = {"left": int(info.hits), "every": float(info.time) / float(info.hits), "timer": 0.0, "dmg": dmg, "radius": float(info.radius_m) * meter, "talent": talent,
				"info": {"status": str(info.get("status", ""))}, "radial": info.get("radial", {}), "base": base}
	_talent_hit = false


## One host tick: resources, cooldowns, buffs, echo, channels, wolves, traps, zones.
func step(delta: float) -> void:
	for id: Variant in runtimes:
		var rt: Dictionary = runtimes[id]
		var player: Dictionary = game.players.get(id, {})
		if player.is_empty(): continue
		if str(rt.res_kind) != "rage": rt.res = minf(float(rt.res_max), float(rt.res) + float(rt.regen) * delta)
		for talent: String in rt.cds.keys():
			rt.cds[talent] = maxf(0.0, float(rt.cds[talent]) - delta)
		rt.gcd = maxf(0.0, float(rt.gcd) - delta)
		rt.hint_cd = maxf(0.0, float(rt.get("hint_cd", 0.0)) - delta)
		if rt.has("drawing"):
			rt.drawing.time = float(rt.drawing.time) - delta
			if float(rt.drawing.time) <= 0.0: _finish_draw(int(id), player, rt)
		_step_defense(rt, delta)
		rt.guard_cd = maxf(0.0, float(rt.guard_cd) - delta)
		for name: String in rt.buffs.keys():
			rt.buffs[name].time = float(rt.buffs[name].time) - delta
			if float(rt.buffs[name].time) <= 0.0: rt.buffs.erase(name)
		if float(rt.shield_time) > 0.0:
			rt.shield_time = float(rt.shield_time) - delta
			if float(rt.shield_time) <= 0.0: rt.shield = 0.0
		if not rt.counter.is_empty():
			rt.counter.time = float(rt.counter.time) - delta
			if float(rt.counter.time) <= 0.0: rt.counter = {}
		if rt.has("echo_cast"):
			rt.echo_cast.time = float(rt.echo_cast.time) - delta
			if float(rt.echo_cast.time) <= 0.0 and int(player.hp) > 0:
				var echo: Dictionary = rt.echo_cast
				rt.erase("echo_cast")
				_spell_hit = true
				_run(int(id), player, rt, str(echo.talent), data.talents[str(echo.talent)], echo.aim, echo.target, float(echo.scale))
				_spell_hit = false
				_event("echo", player.pos, 26.0, {})
		if not rt.channel.is_empty() and int(player.hp) > 0:
			rt.channel.timer = float(rt.channel.timer) - delta
			if float(rt.channel.timer) <= 0.0:
				rt.channel.timer = float(rt.channel.every)
				rt.channel.left = int(rt.channel.left) - 1
				_talent_hit = true
				for enemy: Dictionary in _living():
					if enemy.pos.distance_to(player.pos) <= float(rt.channel.radius): _hit(int(id), enemy, float(rt.channel.dmg), rt.channel.get("info", {}), rt, str(rt.channel.talent))
				_talent_hit = false
				_event("swing", player.pos, float(rt.channel.radius), {"angle": _rng.randf() * TAU, "arc": 2.4})
				if int(rt.channel.left) <= 0:
					var radial: Dictionary = rt.channel.get("radial", {})
					for k in range(int(radial.get("count", 0))):
						var dir := Vector2.from_angle(TAU * k / int(radial.count))
						game._add_bullet(Vector2(player.pos) + dir * 16.0, dir * 420.0, int(id), float(radial.dmg) * float(rt.channel.base),
							{"talent": str(rt.channel.talent), "style": str(radial.get("style", "blade")), "primary": false, "radius": 8.0, "pierce": 3, "life": 0.8})
					rt.channel = {}
		_step_after(int(id), player, rt, delta)
	_step_pets(delta)
	_step_traps(delta)
	_step_zones(delta)
	_step_orbs(delta)
	for enemy: Dictionary in game.enemies:
		for key: String in ["talent_mark", "pet_taunt", "talent_taunt", "talent_weak"]:
			if enemy.has(key):
				enemy[key].time = float(enemy[key].time) - delta
				if float(enemy[key].time) <= 0.0: enemy.erase(key)
	for i in range(events.size() - 1, -1, -1):
		events[i].life = float(events[i].life) - delta
		if float(events[i].life) <= 0.0: events.remove_at(i)


## Shift defense over time: dodge charges come back one by one, a broken
## block mends after its wait, a lowered one regains a hit every `regen` s.
func _step_defense(rt: Dictionary, delta: float) -> void:
	var guard: Dictionary = rt.get("defense", {})
	if guard.is_empty(): return
	var info: Dictionary = data.defense[str(rt["class"])]
	guard.iframes = maxf(0.0, float(guard.iframes) - delta)
	if float(guard.broken) > 0.0:
		guard.broken = float(guard.broken) - delta
		if float(guard.broken) <= 0.0: guard.left = float(guard.max)
		return
	if float(guard.left) >= float(guard.max) or bool(guard.up):
		guard.timer = 0.0
		return
	guard.timer = float(guard.timer) + delta
	var every := float(info.get("recharge", info.get("regen", 3.0)))
	if float(guard.timer) >= every:
		guard.timer = 0.0
		guard.left = minf(float(guard.max), float(guard.left) + 1.0)


## Damage a hero deals, after talent bonuses and crits. `feedback` false for
## damage over time (no crit, no rage).
func outgoing(owner: int, enemy: Dictionary, damage: float, feedback: bool = true) -> float:
	var rt := runtime(owner)
	if rt.is_empty(): return damage
	var pct := 0.0
	var statuses: Dictionary = enemy.get("statuses", {})
	for talent: String in rt.ranks:
		var info: Dictionary = data.talents[talent]
		if str(info.type) == "bonus_vs_status" and Array(info.statuses).any(func(s: String) -> bool: return statuses.has(s)): pct += _value(info, "pct", rt, talent)
		elif str(info.type) == "bonus_vs_pet_target" and int(enemy.get("id", -1)) == int(rt.pet_target): pct += _value(info, "pct", rt, talent)
	pct += _sum(rt, "damage_pct", "pct")
	if not _cur_talent.is_empty():
		for talent: String in rt.ranks:
			var boost: Dictionary = data.talents[talent]
			if str(boost.type) == "talent_pct" and str(boost.target) == _cur_talent: pct += _value(boost, "pct", rt, talent)
	var mark: Dictionary = enemy.get("talent_mark", {})
	if int(mark.get("owner", -1)) == owner: pct += float(mark.pct)
	for buff: Dictionary in rt.buffs.values(): pct += float(buff.get("damage_pct", 0.0))
	if _spell_hit and rt.buffs.has("timebreak"): pct += float(rt.buffs.timebreak.spell_pct)
	damage *= 1.0 + pct / 100.0
	if feedback:
		var chance := float(data.base_crit.chance_pct) + _sum(rt, "crit_chance", "pct")
		if bool(rt.get("force_crit", false)) or _rng.randf() * 100.0 < chance:
			damage *= (float(data.base_crit.damage_pct) + _sum(rt, "crit_damage", "pct")) / 100.0
			_event("crit", enemy.pos, 0.0, {})
	return damage


## After a hit landed: rage from basic hits, lifesteal, the boss damage tally.
func dealt(owner: int, enemy: Dictionary, amount: float, feedback: bool = true) -> void:
	var rt := runtime(owner)
	if rt.is_empty() or amount <= 0.0: return
	# Threat: who hurt this enemy how much (a companion under its own key).
	var threat: Dictionary = enemy.get("threat", {})
	var key := PET_KEY - _pet_source if _pet_source >= 0 else owner
	threat[key] = float(threat.get(key, 0.0)) + amount
	enemy.threat = threat
	# the companion goes for what its hero attacks (a hero's own hit, not damage over time)
	if _pet_source < 0 and feedback: rt.hero_target = int(enemy.get("id", -1))
	if bool(enemy.get("boss", false)):
		var tally: Dictionary = enemy.get("damage_by", {})
		tally[owner] = float(tally.get(owner, 0.0)) + amount
		enemy.damage_by = tally
	if feedback and not _talent_hit and str(rt.res_kind) == "rage":
		rt.res = minf(float(rt.res_max), float(rt.res) + float(data.resources[rt["class"]].per_hit) + _sum(rt, "rage_per_hit", "amount"))
	if feedback:
		for buff: Dictionary in rt.buffs.values():
			if float(buff.get("lifesteal_pct", 0.0)) > 0.0: _heal(owner, rt, amount * float(buff.lifesteal_pct) / 100.0)


## Damage a hero takes after counters, reductions, the wolf's guard and
## shields; also rage from being hit and Wächtereid between allies.
func incoming(id: int, damage: int, _direction: Vector2) -> int:
	var rt := runtime(id)
	if rt.is_empty() or damage <= 0: return damage
	var player: Dictionary = game.players[id]
	var defense: Dictionary = rt.get("defense", {})
	if not defense.is_empty() and float(defense.iframes) > 0.0:
		_event("dodged", player.pos, 0.0, {"life": 0.5})
		return 0
	if not defense.is_empty() and bool(defense.up) and float(defense.left) >= 1.0:
		# the block takes the whole hit; the last hit breaks it
		defense.left = float(defense.left) - 1.0
		var look := str(data.defense[str(rt["class"])].get("look", "mana_bubble"))
		if float(defense.left) < 1.0:
			defense.up = false
			defense.broken = float(data.defense[str(rt["class"])].broken)
			_event("block_break", player.pos, 30.0, {"look": look, "life": 0.6})
		else:
			_event("block_hit", player.pos, 30.0, {"look": look, "life": 0.35})
		return 0
	if not rt.counter.is_empty():
		var counter: Dictionary = rt.counter
		rt.counter = {}
		_talent_hit = true
		for enemy: Dictionary in _living():
			if enemy.pos.distance_to(player.pos) <= float(counter.radius) + float(enemy.radius): _hit(id, enemy, float(counter.dmg), {}, rt, str(counter.talent))
		_talent_hit = false
		_event("parry", player.pos, 24.0, {})
		return 0
	var reduction := _sum(rt, "damage_reduction", "pct")
	for name: String in ["bulwark", "unbreakable"]:
		if rt.buffs.has(name): reduction += float(rt.buffs[name].reduction_pct)
	if rt.buffs.has("oath") and game.players.size() <= 1: reduction += float(rt.buffs.oath.solo_reduction_pct)
	var factor: float = maxf(0.1, 1.0 - reduction / 100.0)
	var striker := _nearest(player.pos, 2.5 * float(data.meter_px))
	if not striker.is_empty() and striker.has("talent_weak"): factor *= 1.0 - float(striker.talent_weak.pct) / 100.0
	if not striker.is_empty() and float(rt.buffs.get("unbreakable", {}).get("thorns", 0.0)) > 0.0:
		_talent_hit = true
		game._damage_enemy(striker, float(rt.buffs.unbreakable.thorns), (Vector2(striker.pos) - Vector2(player.pos)).normalized(), id, true)
		_talent_hit = false
	if rt.buffs.has("bloodlust"): factor *= 1.0 + float(rt.buffs.bloodlust.taken_pct) / 100.0
	var guard := _passive(rt, "pet_guard")
	if not guard.is_empty() and float(rt.guard_cd) <= 0.0 and not _own_pets(id).is_empty():
		factor *= 1.0 - float(guard.reduce_pct) / 100.0
		rt.guard_cd = _value(guard, "every", rt)
		_event("guard", player.pos, 20.0, {})
	# Wächtereid of an ally nearby takes part of this hit.
	for other_id: Variant in runtimes:
		if int(other_id) == id: continue
		var other: Dictionary = runtimes[other_id]
		var hero: Dictionary = game.players.get(other_id, {})
		if other.buffs.has("oath") and not hero.is_empty() and int(hero.hp) > 0 and Vector2(hero.pos).distance_to(player.pos) <= float(other.buffs.oath.range_m) * float(data.meter_px):
			var share := float(other.buffs.oath.ally_pct) / 100.0
			other.debt_ally = float(other.debt_ally) + float(damage) * factor * share
			factor *= 1.0 - share
			var moved := floori(float(other.debt_ally))
			if moved > 0:
				other.debt_ally = float(other.debt_ally) - moved
				game._damage_player(int(other_id), moved, Vector2.ZERO)
			break
	var exact := float(damage) * factor + float(rt.debt_in)
	var taken := floori(exact)
	rt.debt_in = exact - taken
	if float(rt.shield) > 0.0 and taken > 0:
		var absorbed := mini(taken, floori(float(rt.shield) + 0.001))
		rt.shield = float(rt.shield) - absorbed
		taken -= absorbed
		if absorbed > 0: _event("shield", player.pos, 22.0, {})
	if str(rt.res_kind) == "rage": rt.res = minf(float(rt.res_max), float(rt.res) + float(data.resources[rt["class"]].per_hurt))
	return taken


## Unbezwingbar: no knockback, stun or freeze for this hero.
func cc_immune(id: int) -> bool:
	var rt := runtime(id)
	return not rt.is_empty() and rt.buffs.has("unbreakable")


## Raserei: attack interval factor (< 1 attacks faster).
func interval_scale(player: Dictionary, id: int) -> float:
	var rt := runtime(id)
	if rt.is_empty() or not rt.buffs.has("frenzy"): return 1.0
	return 1.0 / (1.0 + float(rt.buffs.frenzy.attack_speed_pct) / 100.0)


## Blutdurst heals the killer, res_on_kill refills its resource; the enemy
## may leave mana on the ground (a mana orb; a boss or mini-boss a potion).
func enemy_killed(enemy: Dictionary, owner: int) -> void:
	_drop_mana(enemy)
	for zone: Dictionary in zones:
		var raise: Dictionary = zone.get("raise", {})
		if raise.is_empty() or Vector2(enemy.pos).distance_to(zone.pos) > float(zone.r) or bool(enemy.get("boss", false)): continue
		if pets.filter(func(p: Dictionary) -> bool: return int(p.get("raised_by", -1)) == int(zone.id)).size() >= int(raise.max): continue
		var zone_rt := runtime(int(zone.owner))
		if zone_rt.is_empty() or not game.players.has(int(zone.owner)): continue
		_spawn_pet(int(zone.owner), zone_rt, str(zone.talent), {"every": 1.5, "dmg": 0.35, "hp": 6, "pet_kind": "skeleton"}, Vector2(enemy.pos), true, float(raise.time))
		pets[-1].raised_by = int(zone.id)
		_event("summon", enemy.pos, 18.0, {"kind": "skeleton"})
	var rt := runtime(owner)
	if rt.is_empty(): return
	var refill := _sum(rt, "res_on_kill", "amount")
	if refill > 0.0: rt.res = minf(float(rt.res_max), float(rt.res) + refill)
	var thirst := _passive(rt, "heal_on_kill")
	if thirst.is_empty(): return
	var player: Dictionary = game.players.get(owner, {})
	_heal(owner, rt, float(player.get("max_hp", 1)) * _value(thirst, "pct", rt) / 100.0)


## A taunted enemy's forced target: a hero's peer id, or a wolf as a decoy
## {id (negative), pos}. Empty when nothing forces it. Bosses are immune.
## Without a taunt the enemy goes for whoever dealt it the most damage (hero
## or companion); a new target needs talents.json pet.threat.switch_pct more.
func forced_target(enemy: Dictionary) -> Dictionary:
	enemy.pet_focus = -1
	if _boss(enemy): return {}
	if enemy.has("pet_taunt"):
		for pet: Dictionary in pets:
			if int(pet.id) == int(enemy.pet_taunt.pet):
				enemy.pet_focus = int(pet.id)
				return {"id": PET_KEY - int(pet.id), "pos": pet.pos}
	if enemy.has("talent_taunt") and game.players.has(int(enemy.talent_taunt.owner)): return {"id": int(enemy.talent_taunt.owner), "pos": game.players[int(enemy.talent_taunt.owner)].pos}
	var focus := threat_focus(enemy)
	if focus == -1: return {}
	if focus <= PET_KEY:
		for pet: Dictionary in pets:
			if PET_KEY - int(pet.id) == focus:
				enemy.pet_focus = int(pet.id)
				return {"id": focus, "pos": pet.pos}
		return {}
	if int(enemy.get("aggro_target", -1)) != focus: Aggro.lock(enemy, focus)
	return {}


## The threat key an enemy fights (a hero's peer id, or PET_KEY - pet id), -1
## without a tally. Only living heroes and companions count; the current one
## keeps the enemy until someone else is switch_pct ahead.
func threat_focus(enemy: Dictionary) -> int:
	var threat: Dictionary = enemy.get("threat", {})
	if threat.is_empty(): return -1
	var alive := {}
	for pet: Dictionary in pets: alive[PET_KEY - int(pet.id)] = true
	for id: Variant in game.players:
		if int(game.players[id].hp) > 0: alive[int(id)] = true
	var best := -1
	var best_amount := 0.0
	for key: Variant in threat:
		if alive.has(int(key)) and float(threat[key]) > best_amount:
			best = int(key)
			best_amount = float(threat[key])
	var current := int(enemy.get("threat_target", -1))
	var margin := 1.0 + float(data.get("pet", {}).get("threat", {}).get("switch_pct", 10)) / 100.0
	if current != best and alive.has(current) and best_amount < float(threat.get(current, 0.0)) * margin: best = current
	enemy.threat_target = best
	return best


## The hero's living permanent companion, or {}.
func permanent_pet(id: int) -> Dictionary:
	for pet: Dictionary in pets:
		if int(pet.owner) == id and bool(pet.get("permanent", false)) and float(pet.hp) > 0.0: return pet
	return {}


## The companion ability on key 5 (`slot` 0) or 6 (1) of a kind, or {}.
func pet_ability(kind: String, slot: int) -> Dictionary:
	var names: Array = data.get("pet", {}).get("kinds", {}).get(kind, {}).get("abilities", [])
	if slot < 0 or slot >= names.size(): return {}
	var ability: Dictionary = data.pet.abilities.get(str(names[slot]), {}).duplicate()
	ability.id = str(names[slot])
	return ability


## Right-click on a companion icon: its auto-cast on or off.
func toggle_pet_auto(id: int, slot: int) -> void:
	var rt := runtime(id)
	if rt.is_empty() or slot < 0 or slot > 1: return
	rt.pet_auto[slot] = not bool(rt.pet_auto[slot])


## The companion uses the ability on key 5 or 6 (`manual`: the hero pressed
## it, so it also fires without a target in reach). Returns true when it fired.
func pet_cast(id: int, slot: int, manual: bool = false) -> bool:
	var pet := permanent_pet(id)
	var rt := runtime(id)
	if pet.is_empty() or rt.is_empty(): return false
	var ability := pet_ability(str(pet.kind), slot)
	if ability.is_empty() or float(rt.pet_cds.get(ability.id, 0.0)) > 0.0: return false
	var meter := float(data.meter_px)
	var prey := {}
	for enemy: Dictionary in _living():
		if int(enemy.id) == int(pet.target): prey = enemy
	var reach := float(data.pet.attack_range_m) * meter
	if prey.is_empty(): prey = _nearest(pet.pos, float(ability.get("range_m", 6)) * meter)
	var dmg := float(ability.get("dmg", 0.0)) * float(pet.base)
	var hit := false
	match str(ability.type):
		"lance":
			if prey.is_empty() or Vector2(pet.pos).distance_to(prey.pos) > float(ability.range_m) * meter + float(prey.radius): return false
			_pet_hit(pet, rt, prey, dmg, ability)
			_event("pet_lance", pet.pos, 0.0, {"tx": prey.pos.x, "ty": prey.pos.y, "kind": str(pet.kind)})
			hit = true
		"nova", "cleave":
			var radius := float(ability.radius_m) * meter
			var inside := _living().filter(func(e: Dictionary) -> bool: return Vector2(e.pos).distance_to(pet.pos) <= radius + float(e.radius))
			if inside.is_empty() and not manual: return false
			for enemy: Dictionary in inside:
				_pet_hit(pet, rt, enemy, dmg, ability)
				_pet_strike(pet, enemy, ability)
			_event("nova" if str(ability.type) == "nova" else "pet_cleave", pet.pos, radius, {"fx": str(ability.get("fx", "ice")) if str(ability.type) == "nova" else "steel", "talent": str(ability.id), "life": 0.5})
			hit = true
		"bite":
			if prey.is_empty() or Vector2(pet.pos).distance_to(prey.pos) > float(ability.get("range_m", 4.0)) * meter: return false
			var diving := bool(ability.get("dive", false))
			if diving or Vector2(pet.pos).distance_to(prey.pos) > reach + float(prey.radius):
				var from: Vector2 = pet.pos
				pet.pos = _move(pet.pos, (Vector2(prey.pos) - Vector2(pet.pos)) * 0.85, 10.0, game.current_layout)
				_event("dive" if diving else "leap", from, 0.0, {"tx": pet.pos.x, "ty": pet.pos.y, "life": 0.45})
			pet.target = int(prey.id)
			_pet_hit(pet, rt, prey, dmg, ability)
			_pet_strike(pet, prey, ability)
			hit = true
		"taunt":
			var radius := float(ability.radius_m) * meter
			var drawn := 0
			for enemy: Dictionary in _living():
				if not _boss(enemy) and Vector2(enemy.pos).distance_to(pet.pos) <= radius:
					enemy.pet_taunt = {"pet": int(pet.id), "time": float(ability.taunt)}
					drawn += 1
			if drawn == 0 and not manual: return false
			_event("shout", pet.pos, radius, {"pet": true})
			hit = true
	if not hit: return false
	rt.pet_cds[ability.id] = float(ability.cd)
	pet.cast = 0.45
	pet.cast_slot = slot
	return true


## What a companion's ability leaves on its victim, drawn by talent_fx: blood
## for a bleeding wound, stars for a blinding or stunning blow.
func _pet_strike(pet: Dictionary, enemy: Dictionary, ability: Dictionary) -> void:
	var wound := "blood" if str(ability.get("status", "")) == "bleed" else "burn" if str(ability.get("status", "")) == "burn" else "daze" if float(ability.get("freeze", 0.0)) > 0.0 else ""
	if not wound.is_empty(): _event("pet_strike", enemy.pos, 0.0, {"wound": wound, "pet_kind": str(pet.kind), "life": 0.6})


## One hit of a companion's ability: damage under the companion's threat key,
## plus the ability's status, slow or freeze.
func _pet_hit(pet: Dictionary, rt: Dictionary, enemy: Dictionary, dmg: float, ability: Dictionary) -> void:
	_talent_hit = true
	_pet_source = int(pet.id)
	_hit(int(pet.owner), enemy, dmg, ability, rt, str(pet.talent))
	_pet_source = -1
	_talent_hit = false


## What clients draw: wolves, traps, poison zones and short events.
func snapshot() -> Dictionary:
	var out := {"pets": [], "traps": [], "zones": [], "orbs": [], "events": events.duplicate(true), "drawings": [], "guards": []}
	for id: Variant in runtimes:
		var rt: Dictionary = runtimes[id]
		var hero: Dictionary = game.players.get(id, {})
		if hero.is_empty(): continue
		if rt.has("drawing"):
			var line: Array = []
			for point: Vector2 in rt.drawing.points: line.append([point.x, point.y])
			out.drawings.append({"owner": id, "points": line, "left": float(rt.drawing.left), "max": float(rt.drawing.max), "x": hero.pos.x, "y": hero.pos.y})
		var guard: Dictionary = rt.get("defense", {})
		if not guard.is_empty() and (bool(guard.up) or float(guard.iframes) > 0.0):
			out.guards.append({"owner": id, "x": hero.pos.x, "y": hero.pos.y, "type": str(guard.type), "left": float(guard.left), "max": float(guard.max),
				"look": str(data.defense[str(rt["class"])].get("look", "")), "dodge": float(guard.iframes) > 0.0})
	for orb: Dictionary in orbs: out.orbs.append({"id": orb.id, "x": orb.pos.x, "y": orb.pos.y, "potion": bool(orb.potion), "life": float(orb.life)})
	for pet: Dictionary in pets: out.pets.append({"id": pet.id, "x": pet.pos.x, "y": pet.pos.y, "face": pet.face, "owner": pet.owner, "bite": float(pet.bite), "pack": bool(pet.pack), "moving": bool(pet.moving), "kind": str(pet.get("kind", "wolf")),
		"permanent": bool(pet.get("permanent", false)), "hp": float(pet.hp) / maxf(0.1, float(pet.get("hp_max", pet.hp))), "cast": float(pet.get("cast", 0.0)), "cast_slot": int(pet.get("cast_slot", 0)), "hurt": float(pet.get("hurt", 0.0)),
		"awake": float(pet.get("awake", 0.0)) > 0.0})
	for trap: Dictionary in traps: out.traps.append({"id": trap.id, "x": trap.pos.x, "y": trap.pos.y, "r": trap.r, "owner": trap.owner, "boom": float(trap.root) <= 0.0, "cloud": not Dictionary(trap.get("cloud", {})).is_empty()})
	for zone: Dictionary in zones: out.zones.append({"id": zone.id, "x": zone.pos.x, "y": zone.pos.y, "r": zone.r, "time": zone.time, "status": str(zone.get("status", "")), "look": str(zone.get("look", "")),
		"ax": Vector2(zone.wall.a).x if zone.has("wall") else 0.0, "ay": Vector2(zone.wall.a).y if zone.has("wall") else 0.0,
		"bx": Vector2(zone.wall.b).x if zone.has("wall") else 0.0, "by": Vector2(zone.wall.b).y if zone.has("wall") else 0.0,
		"path": (zone.path as Array).map(func(p: Vector2) -> Array: return [p.x, p.y]) if zone.has("path") else [], "w": float(zone.get("w", 0.0))})
	return out


## The HUD's view of one hero: resource, bar slots with cooldowns, ultimate, buffs, shield.
func player_state(id: int) -> Dictionary:
	var rt := runtime(id)
	if rt.is_empty(): return {}
	var slots: Array = []
	for talent: String in rt.bar: slots.append(_slot(id, rt, talent))
	return {"res": snappedf(float(rt.res), 0.1), "res_max": float(rt.res_max), "res_kind": str(rt.res_kind), "slots": slots,
		"ult": _slot(id, rt, str(rt.ultimate)) if not str(rt.ultimate).is_empty() else {}, "buffs": rt.buffs.keys(), "shield": float(rt.shield),
		"counter": not rt.counter.is_empty(), "channel": not rt.channel.is_empty(), "pet": _pet_state(id, rt), "defense": _defense_hud(rt),
		"drawing": {} if not rt.has("drawing") else {"left": float(rt.drawing.left), "max": float(rt.drawing.max)}}


## The Shift defense for the HUD: name, text, charges or hits left, and the wait.
func _defense_hud(rt: Dictionary) -> Dictionary:
	var guard: Dictionary = rt.get("defense", {})
	if guard.is_empty(): return {}
	var info: Dictionary = data.defense[str(rt["class"])]
	var every := float(info.get("recharge", info.get("regen", 3.0)))
	return {"type": str(guard.type), "name": str(info.name), "icon": str(info.get("icon", "shield")), "text": str(info.text), "left": int(floorf(float(guard.left))), "max": int(guard.max),
		"up": bool(guard.up), "cd": snappedf(float(guard.broken), 0.05) if float(guard.broken) > 0.0 else 0.0, "cd_max": float(info.get("broken", every)),
		"refill": clampf(float(guard.timer) / every, 0.0, 1.0)}


## The permanent companion for the HUD: name, life, the respawn wait while it
## is dead and its two abilities with cooldown and auto-cast. {} without one.
func _pet_state(id: int, rt: Dictionary) -> Dictionary:
	if not rt.has("permanent"): return {}
	var talent := str(rt.permanent)
	var info: Dictionary = data.talents[talent]
	var kind := str(info.get("pet_kind", rt.get("companion", "wolf")))
	var pet := permanent_pet(id)
	var out := {"kind": kind, "name": str(data.pet.kinds.get(kind, {}).get("name", kind)), "spec": str(info.spec), "alive": not pet.is_empty(),
		"hp": snappedf(float(pet.get("hp", 0.0)), 0.1), "hp_max": float(pet.get("hp_max", 1.0)), "respawn": snappedf(float(rt.cds.get(talent, 0.0)), 0.05), "abilities": []}
	for slot in range(2):
		var ability := pet_ability(kind, slot)
		if ability.is_empty(): continue
		out.abilities.append({"id": str(ability.id), "name": str(ability.name), "icon": str(ability.icon), "text": str(ability.get("text", "")), "cd": snappedf(float(rt.pet_cds.get(ability.id, 0.0)), 0.05),
			"cd_max": float(ability.cd), "auto": bool(rt.pet_auto[slot]), "key": str(5 + slot)})
	return out


func _slot(id: int, rt: Dictionary, talent: String) -> Dictionary:
	var info: Dictionary = data.talents[talent]
	return {"id": talent, "name": str(info.name), "icon": str(info.icon), "spec": str(info.spec), "cd": snappedf(float(rt.cds.get(talent, 0.0)), 0.05),
		"cd_max": float(info.cd), "gcd": float(rt.gcd), "cost": cost_of(rt, talent), "ready": cast_blocker(id, talent).is_empty(),
		"text": str(info.get("text", "")), "res_name": str(data.resources[rt["class"]].name)}


# ---------- effects ----------

func _area(id: int, rt: Dictionary, talent: String, info: Dictionary, center: Vector2, radius: float, dmg: float) -> void:
	for enemy: Dictionary in _living():
		if enemy.pos.distance_to(center) > radius + float(enemy.radius): continue
		_hit(id, enemy, dmg, info, rt, talent)


## One talent hit on an enemy: damage plus the talent's status, slow, freeze or root.
func _hit(id: int, enemy: Dictionary, dmg: float, info: Dictionary, rt: Dictionary, talent: String) -> void:
	if float(enemy.hp) <= 0.0: return
	var player: Dictionary = game.players.get(id, {})
	var direction: Vector2 = (Vector2(enemy.pos) - Vector2(player.get("pos", enemy.pos))).normalized()
	_cur_talent = talent
	if dmg > 0.0: game._damage_enemy(enemy, dmg, direction, id, true)
	_cur_talent = ""
	_apply_status(id, enemy, info, rt, talent)


func _apply_status(id: int, enemy: Dictionary, info: Dictionary, rt: Dictionary, talent: String) -> void:
	if info.is_empty() or float(enemy.hp) <= 0.0: return
	var base := float(game.players.get(id, {}).get("damage", 1.0))
	var status := str(info.get("status", ""))
	if status in STATUS_TALENTS:
		var config: Dictionary = data.statuses[status]
		var dps := base * float(config.pct) / 100.0 * (1.0 + _dot_bonus(rt, status) / 100.0)
		_status(enemy, status, dps, float(info.get("status_time", config.time)), id)
	if info.has("slow"): _status(enemy, "slow", _value(info, "slow", rt, talent), float(info.get("slow_time", 4)), id)
	if info.has("freeze"):
		if _boss(enemy):
			if info.has("boss_slow"): _status(enemy, "slow", float(info.boss_slow), float(info.boss_slow_time), id)
		else: _status(enemy, "freeze", 1.0, _value(info, "freeze", rt, talent), id)


func _status(enemy: Dictionary, key: String, power: float, duration: float, owner: int) -> void:
	# Same effect again refreshes its duration instead of stacking (perk status system).
	game.perk_combat._status(enemy, key, power, duration, owner)


func _taunt(enemy: Dictionary, id: int, time: float) -> void:
	if _boss(enemy): return
	Aggro.lock(enemy, id)
	enemy.talent_taunt = {"owner": id, "time": time}


func _heal(id: int, rt: Dictionary, amount: float) -> void:
	var player: Dictionary = game.players.get(id, {})
	if player.is_empty() or int(player.hp) <= 0: return
	rt.debt_heal = float(rt.debt_heal) + amount
	var whole := floori(float(rt.debt_heal))
	if whole <= 0: return
	rt.debt_heal = float(rt.debt_heal) - whole
	player.hp = mini(int(player.max_hp), int(player.hp) + whole)


## Projectile talents land here instead of the perk hit path.
func bullet_hit(bullet: Dictionary, enemy: Dictionary) -> void:
	var id := int(bullet.owner)
	var rt := runtime(id)
	var talent := str(bullet.get("talent", ""))
	if rt.is_empty() or not data.talents.has(talent): return
	var info: Dictionary = data.talents[talent]
	_talent_hit = true
	_spell_hit = str(rt["class"]) == "mage"
	rt.force_crit = bool(bullet.get("always_crit", false))
	_hit(id, enemy, float(bullet.damage), info, rt, talent)
	rt.force_crit = false
	if info.has("splash_m"):
		var reach := float(info.splash_m) * float(data.meter_px)
		for other: Dictionary in _living():
			if other != enemy and Vector2(other.pos).distance_to(enemy.pos) <= reach + float(other.radius):
				_hit(id, other, float(bullet.damage) * float(info.splash), info, rt, talent)
		_event("explosion", enemy.pos, reach, {"fx": "fire", "life": 0.6})
	_talent_hit = false
	_spell_hit = false


## The companion kind of a build ("wolf", "bear"; talents.json "pet.kinds"), the default when unknown.
func _companion(kind: String) -> String:
	var kinds: Dictionary = data.get("pet", {}).get("kinds", {})
	return kind if kinds.has(kind) else str(data.get("pet", {}).get("default_kind", "wolf"))


func _spawn_pet(id: int, rt: Dictionary, talent: String, info: Dictionary, at: Vector2, pack: bool, life: float) -> void:
	var bond := _passive(rt, "pet_bonus")
	# the necromancer's skeletons name their kind; the beast master's companion is the chosen one
	var kind := str(info.get("pet_kind", rt.get("companion", "wolf")))
	var traits: Dictionary = data.get("pet", {}).get("kinds", {}).get(kind, {})
	var hp := float(info.get("hp", 6)) * float(traits.get("hp", 1.0)) * (1.0 + (_value(bond, "hp_pct", rt) / 100.0 if not bond.is_empty() else 0.0))
	var dmg_scale := float(traits.get("dmg", 1.0)) * (1.0 + (_value(bond, "dmg_pct", rt) / 100.0 if not bond.is_empty() else 0.0))
	var base := float(game.players[id].get("damage", 1.0)) if game.players.has(id) else 1.0
	pets.append({"id": _take_id(), "owner": id, "talent": talent, "pos": at, "hp": hp, "hp_max": hp, "life": life,
		"every": float(info.every) * float(traits.get("every", 1.0)), "timer": 0.6, "dmg": _value(info, "dmg", rt, talent) * base * dmg_scale * _soul(rt, talent, "damage"),
		"base": base * dmg_scale, "permanent": bool(info.get("permanent", false)), "ranged": bool(traits.get("ranged", false)), "range_m": float(traits.get("range_m", 0.0)),
		"calm": 0.0, "cast": 0.0, "hurt": 0.0, "cleave_m": float(info.get("cleave_m", 0.0)), "taunt_m": float(info.get("taunt_m", 0.0)), "taunt": float(info.get("taunt", 0.0)),
		"death_burst": info.get("death_burst", {}),
		"pack": pack, "target": -1, "face": 1.0, "bite": 0.0, "moving": false, "kind": kind, "speed": float(traits.get("speed", 1.0))})


func _step_pets(delta: float) -> void:
	var meter := float(data.meter_px)
	var config: Dictionary = data.pet
	for i in range(pets.size() - 1, -1, -1):
		var pet: Dictionary = pets[i]
		var owner: Dictionary = game.players.get(int(pet.owner), {})
		var permanent := bool(pet.get("permanent", false))
		if not permanent: pet.life = float(pet.life) - delta
		pet.bite = maxf(0.0, float(pet.bite) - delta)
		pet.cast = maxf(0.0, float(pet.get("cast", 0.0)) - delta)
		pet.hurt = maxf(0.0, float(pet.get("hurt", 0.0)) - delta)
		if float(pet.get("awake", 0.0)) > 0.0:
			pet.awake = float(pet.awake) - delta
			if float(pet.awake) <= 0.0 and pet.has("hp_base"):
				pet.hp_max = float(pet.hp_base)
				pet.hp = minf(float(pet.hp), float(pet.hp_max))
				pet.erase("hp_base")
		if pet.life <= 0.0 or float(pet.hp) <= 0.0 or owner.is_empty() or (int(owner.hp) <= 0 and not permanent):
			var burst: Dictionary = pet.get("death_burst", {})
			if not burst.is_empty():
				var burst_rt := runtime(int(pet.owner))
				_talent_hit = true
				if not burst_rt.is_empty(): _area(int(pet.owner), burst_rt, str(pet.talent), {}, Vector2(pet.pos), float(burst.radius_m) * meter, float(burst.dmg) * float(pet.base))
				_talent_hit = false
				_event("nova", pet.pos, float(burst.radius_m) * meter, {"fx": "steel", "talent": str(pet.talent), "life": 0.7})
			if permanent and float(pet.hp) <= 0.0:
				var fallen := runtime(int(pet.owner))
				if not fallen.is_empty(): fallen.pet_fell = true
				_event("pet_fell", pet.pos, 18.0, {"kind": str(pet.kind)})
			pets.remove_at(i)
			continue
		var prey := _pet_prey(pet, owner)
		if permanent: _care(pet, owner, prey, delta)
		var goal: Vector2 = owner.pos + Vector2(-28.0 * float(owner.get("face", 1.0)), 18.0)
		if not prey.is_empty(): goal = prey.pos
		var before: Vector2 = pet.pos
		if Vector2(pet.pos).distance_to(goal) > (_pet_reach(pet) * 0.8 if not prey.is_empty() else 14.0):
			pet.pos = _move(pet.pos, (goal - pet.pos).limit_length(float(config.speed) * float(pet.get("speed", 1.0)) * delta), float(config.radius), game.current_layout)
		pet.moving = Vector2(pet.pos).distance_squared_to(before) > 0.01
		if absf(goal.x - pet.pos.x) > 2.0: pet.face = signf(goal.x - pet.pos.x)
		pet.timer = float(pet.timer) - delta
		if not prey.is_empty() and Vector2(pet.pos).distance_to(prey.pos) <= _pet_reach(pet) + float(prey.radius) and float(pet.timer) <= 0.0:
			pet.timer = float(pet.every)
			pet.bite = 0.25
			var rt := runtime(int(pet.owner))
			rt.pet_target = int(prey.id)
			_talent_hit = true
			_cur_talent = str(pet.talent)
			_pet_source = int(pet.id)
			var bite := float(pet.dmg) * (float(pet.get("awake_mult", 1.0)) if float(pet.get("awake", 0.0)) > 0.0 else 1.0)
			var cleave := float(pet.get("cleave_m", 0.0)) if float(pet.get("awake", 0.0)) <= 0.0 else maxf(float(pet.get("cleave_m", 0.0)), float(pet.get("awake_cleave_m", 0.0)))
			if cleave > 0.0:
				for other: Dictionary in _living():
					if Vector2(other.pos).distance_to(prey.pos) <= cleave * meter + float(other.radius): game._damage_enemy(other, bite, (Vector2(other.pos) - Vector2(pet.pos)).normalized(), int(pet.owner), true)
				_event("pet_cleave", prey.pos, cleave * meter, {"life": 0.4})
			else:
				game._damage_enemy(prey, bite, (Vector2(prey.pos) - Vector2(pet.pos)).normalized(), int(pet.owner), true)
			if float(pet.get("taunt_m", 0.0)) > 0.0:
				for other: Dictionary in _living():
					if not _boss(other) and Vector2(other.pos).distance_to(pet.pos) <= float(pet.taunt_m) * meter: other.pet_taunt = {"pet": int(pet.id), "time": float(pet.taunt)}
			_pet_source = -1
			_cur_talent = ""
			_talent_hit = false
			if bool(pet.get("ranged", false)): _event("pet_bolt", pet.pos, 0.0, {"tx": prey.pos.x, "ty": prey.pos.y, "kind": str(pet.kind)})
		# Enemies that fight this companion (taunt or threat) hit it in reach.
		var cfg: Dictionary = config.get("permanent", {})
		for enemy: Dictionary in _living():
			if int(enemy.get("pet_focus", -1)) == int(pet.id) and enemy.pos.distance_to(pet.pos) < float(enemy.radius) + 16.0:
				var dps := float(cfg.get("boss_dps", 2.0)) if bool(enemy.get("miniboss", false)) else float(cfg.get("enemy_dps", 0.8))
				pet.hp = float(pet.hp) - dps * delta
				pet.calm = 0.0
				pet.hurt = 0.2


## Whom a companion fights (user wish 30.10.2026): the enemy its hero
## attacks, else the one it already fights, else the nearest enemy going for
## its hero or for itself. It stays on that enemy until it dies, however far
## the hero walks; only with no fight left does it come back to the hero.
func _pet_prey(pet: Dictionary, owner: Dictionary) -> Dictionary:
	var meter := float(data.meter_px)
	var rt := runtime(int(pet.owner))
	var living := _living()
	var by_id := {}
	for enemy: Dictionary in living: by_id[int(enemy.id)] = enemy
	var prey: Dictionary = by_id.get(int(rt.get("hero_target", -1)), {})
	if prey.is_empty(): prey = by_id.get(int(pet.target), {})
	if prey.is_empty():
		var best := 10.0 * meter
		for enemy: Dictionary in living:
			var on_hero := bool(enemy.get("aggro", true)) and int(enemy.get("aggro_target", int(pet.owner))) == int(pet.owner)
			var on_pet := int(enemy.get("pet_focus", -1)) == int(pet.id) or int(enemy.get("pet_taunt", {}).get("pet", -1)) == int(pet.id)
			var distance: float = minf(Vector2(enemy.pos).distance_to(owner.pos), Vector2(enemy.pos).distance_to(pet.pos))
			if (on_hero or on_pet) and distance <= best:
				best = distance
				prey = enemy
	if prey.is_empty(): prey = _nearest(owner.pos, 6.0 * meter)
	pet.target = int(prey.get("id", -1))
	return prey


## How close a companion has to be to attack: in melee, or its bolt range.
func _pet_reach(pet: Dictionary) -> float:
	var meter := float(data.meter_px)
	return float(pet.range_m) * meter if bool(pet.get("ranged", false)) else float(data.pet.attack_range_m) * meter


## A permanent companion between fights: it heals after a quiet spell, jumps
## back to a hero who ran far away, and uses its auto-cast abilities in a fight.
func _care(pet: Dictionary, owner: Dictionary, prey: Dictionary, delta: float) -> void:
	var cfg: Dictionary = data.pet.get("permanent", {})
	var meter := float(data.meter_px)
	pet.calm = float(pet.get("calm", 0.0)) + delta
	if not prey.is_empty(): pet.calm = minf(float(pet.calm), 1.0)
	if float(pet.calm) >= float(cfg.get("heal_after_s", 4)):
		pet.hp = minf(float(pet.hp_max), float(pet.hp) + float(pet.hp_max) * float(cfg.get("heal_pct_per_s", 8)) / 100.0 * delta)
	if prey.is_empty() and Vector2(pet.pos).distance_to(owner.pos) > float(cfg.get("teleport_m", 14)) * meter:
		pet.pos = Vector2(owner.pos) + Vector2(-24, 14)
		pet.target = -1
	var rt := runtime(int(pet.owner))
	for ability_id: String in rt.pet_cds.keys():
		rt.pet_cds[ability_id] = maxf(0.0, float(rt.pet_cds[ability_id]) - delta)
	if prey.is_empty(): return
	for slot in range(2):
		if bool(rt.pet_auto[slot]) and pet_cast(int(pet.owner), slot): break


func _step_traps(delta: float) -> void:
	for i in range(traps.size() - 1, -1, -1):
		var trap: Dictionary = traps[i]
		trap.life = float(trap.life) - delta
		if float(trap.life) <= 0.0:
			traps.remove_at(i)
			continue
		var sprung := false
		for enemy: Dictionary in _living():
			if enemy.pos.distance_to(trap.pos) <= float(trap.trigger) + float(enemy.radius):
				sprung = true
				break
		if not sprung: continue
		_talent_hit = true
		for enemy: Dictionary in _living():
			if enemy.pos.distance_to(trap.pos) > maxf(float(trap.r), float(trap.trigger)) + float(enemy.radius): continue
			game._damage_enemy(enemy, float(trap.dmg), (Vector2(enemy.pos) - Vector2(trap.pos)).normalized(), int(trap.owner), true)
			if float(trap.root) > 0.0 and not _boss(enemy): _status(enemy, "slow", 1.0, float(trap.root), int(trap.owner))
		_talent_hit = false
		_event("trap", trap.pos, float(trap.r), {"boom": float(trap.root) <= 0.0})
		var cloud: Dictionary = trap.get("cloud", {})
		if not cloud.is_empty():
			zones.append({"id": _take_id(), "owner": int(trap.owner), "talent": str(trap.talent), "pos": Vector2(trap.pos), "r": float(cloud.r), "time": float(cloud.time),
				"every": float(cloud.every), "tick": 0.0, "dmg": float(cloud.dmg), "status": str(cloud.status), "info": {"status": str(cloud.status)}})
		traps.remove_at(i)


func _step_zones(delta: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var zone: Dictionary = zones[i]
		zone.time = float(zone.time) - delta
		zone.tick = float(zone.tick) - delta
		if float(zone.get("pull", 0.0)) > 0.0:
			# Singularität drags everything but bosses towards its heart
			for enemy: Dictionary in _living():
				if _boss(enemy) or enemy.pos.distance_to(zone.pos) > float(zone.r) + float(enemy.radius): continue
				_shove(enemy, _move(enemy.pos, (Vector2(zone.pos) - Vector2(enemy.pos)).limit_length(float(zone.pull) * delta), float(enemy.radius), game.current_layout))
		if float(zone.tick) <= 0.0:
			zone.tick = float(zone.every)
			var rt := runtime(int(zone.owner))
			_talent_hit = true
			for enemy: Dictionary in _living():
				if _in_zone(zone, enemy):
					_hit(int(zone.owner), enemy, float(zone.dmg), zone.get("info", data.talents[str(zone.talent)]), rt, str(zone.talent))
					if float(zone.get("weaken", 0.0)) > 0.0: enemy.talent_weak = {"pct": float(zone.weaken), "time": float(zone.every) + 0.5}
			_talent_hit = false
		if float(zone.time) <= 0.0:
			if str(zone.get("look", "")) == "arrows": _event("arrow_finale", zone.pos, float(zone.r), {"life": 0.9})
			var closing: Dictionary = zone.get("on_end", {})
			if not closing.is_empty():
				var owner_rt := runtime(int(zone.owner))
				_talent_hit = true
				if not owner_rt.is_empty(): _area(int(zone.owner), owner_rt, str(zone.talent), closing.get("info", {}), Vector2(zone.pos), float(closing.r), float(closing.dmg))
				_talent_hit = false
				_event("nova", zone.pos, float(closing.r), {"fx": str(closing.fx), "talent": str(zone.talent), "life": 0.8})
				if bool(closing.get("reset_cds", false)) and not owner_rt.is_empty():
					for other: String in owner_rt.cds.keys():
						if other != str(zone.talent): owner_rt.cds[other] = 0.0
			zones.remove_at(i)


# ---------- helpers ----------

## Rank value of `key` in a talent (the rank comes from the runtime).
func _value(info: Dictionary, key: String, rt: Dictionary, talent: String = "") -> float:
	var raw: Variant = info.get(key, 0.0)
	if not raw is Array: return float(raw)
	var id := talent if not talent.is_empty() else str(info.get("id", ""))
	var rank := clampi(int(rt.ranks.get(id, 1)), 1, raw.size())
	return float(raw[rank - 1])


## The first learned passive of `type` (with its id merged in), or {}.
func _passive(rt: Dictionary, type: String) -> Dictionary:
	for talent: String in rt.ranks:
		var info: Dictionary = data.talents[talent]
		if str(info.type) == type: return info
	return {}


## Sum of `key` over every learned passive of `type`.
func _sum(rt: Dictionary, type: String, key: String) -> float:
	var total := 0.0
	for talent: String in rt.ranks:
		var info: Dictionary = data.talents[talent]
		if str(info.type) == type: total += _value(info, key, rt, talent)
	return total


func _dot_bonus(rt: Dictionary, status: String) -> float:
	var total := 0.0
	for talent: String in rt.ranks:
		var info: Dictionary = data.talents[talent]
		if str(info.type) == "dot_bonus" and str(info.status) == status: total += _value(info, "pct", rt, talent)
	return total


## Soul tier factor of the ultimate for its bonus kind ("damage" or "power").
func _soul(rt: Dictionary, talent: String, kind: String) -> float:
	if talent != str(rt.ultimate) or str(data.talents[talent].get("soul", "")) != kind: return 1.0
	return Rules.soul_scale(data, rt)


## What `talent` costs this hero now (cost_pct passives make it cheaper).
func cost_of(rt: Dictionary, talent: String) -> float:
	var info: Dictionary = data.talents.get(talent, {})
	return float(info.get("cost", 0.0)) * maxf(0.5, 1.0 - _sum(rt, "cost_pct", "pct") / 100.0)


## Refills `share` (0..1) of a hero's mana; heroes with Ausdauer or Zorn are
## not refilled. Returns true when it took effect.
func restore_mana(id: int, share: float) -> bool:
	var rt := runtime(id)
	if rt.is_empty() or str(rt.res_kind) != "mana": return false
	rt.res = minf(float(rt.res_max), float(rt.res) + float(rt.res_max) * share)
	return true


func _drop_mana(enemy: Dictionary) -> void:
	var rules: Dictionary = data.get("mana_orbs", {})
	if rules.is_empty() or bool(enemy.get("summoned", false)) or orbs.size() >= int(rules.get("max_on_floor", 12)): return
	var potion := bool(enemy.get("boss", false)) or bool(enemy.get("miniboss", false)) or str(enemy.get("kind", "")) == "boss"
	if not potion and _rng.randf() * 100.0 >= float(rules.get("drop_pct", 0)): return
	var at: Vector2 = Vector2(enemy.get("pos", enemy.get("p", Vector2.ZERO)))
	orbs.append({"id": _take_id(), "pos": at, "potion": potion, "life": float(rules.get("life", 25))})


## A hero with mana who walks over an orb drinks it; old orbs fade.
func _step_orbs(delta: float) -> void:
	var rules: Dictionary = data.get("mana_orbs", {})
	for i in range(orbs.size() - 1, -1, -1):
		var orb: Dictionary = orbs[i]
		orb.life = float(orb.life) - delta
		var taken := false
		for id: Variant in runtimes:
			var hero: Dictionary = game.players.get(id, {})
			if hero.is_empty() or int(hero.get("hp", 0)) <= 0: continue
			if Vector2(hero.pos).distance_to(orb.pos) > float(rules.get("pickup_px", 28)): continue
			var rt: Dictionary = runtimes[id]
			if str(rt.res_kind) != "mana" or float(rt.res) >= float(rt.res_max) - 0.5: continue
			restore_mana(int(id), float(rules.get("potion_restore_pct" if bool(orb.potion) else "restore_pct", 20)) / 100.0)
			_event("mana", orb.pos, 18.0, {"potion": bool(orb.potion)})
			taken = true
			break
		if taken or float(orb.life) <= 0.0: orbs.remove_at(i)


## The talent as this hero plays it: the ultimate with its bought stages
## (Rules.staged), every other talent as it is.
func _info(rt: Dictionary, talent: String) -> Dictionary:
	if talent == str(rt.get("ultimate", "")): return Rules.staged(data, talent, int(rt.soul_tier))
	return data.talents[talent]


## What an ultimate stage adds around the cast: the burning ground where it
## was cast, the reloaded talents and the delayed or closing waves.
func _stage_effects(id: int, player: Dictionary, rt: Dictionary, talent: String, info: Dictionary) -> void:
	var base := float(player.get("damage", 1.0)) * _soul(rt, talent, "damage")
	var meter := float(data.meter_px)
	if info.has("ground"):
		var ground: Dictionary = info.ground
		zones.append({"id": _take_id(), "owner": id, "talent": talent, "pos": Vector2(player.pos), "r": float(ground.radius_m) * meter, "time": float(ground.time),
			"every": float(ground.every), "tick": float(ground.every), "dmg": float(ground.dmg) * base, "status": str(ground.get("status", "")),
			"info": {"status": str(ground.get("status", "")), "slow": ground.get("slow", null)} if ground.has("slow") else {"status": str(ground.get("status", ""))}})
	if bool(info.get("reset_cds", false)):
		for other: String in rt.cds.keys():
			if other != talent: rt.cds[other] = 0.0
	for wave: Dictionary in info.get("after", []):
		var on_end := bool(wave.get("on_end", false))
		rt.after.append({"time": float(info.get("time", 0.0)) if on_end else float(wave.get("delay", 0.0)), "pos": Vector2.INF if on_end else Vector2(player.pos),
			"dmg": float(wave.dmg) * base, "r": float(wave.radius_m) * meter, "fx": str(wave.get("fx", "fire")), "status": str(wave.get("status", "")), "talent": talent})


## Fires the ultimate's waves when their time has come (at the cast spot, or
## around the hero for waves that close a buff or channel).
func _step_after(id: int, player: Dictionary, rt: Dictionary, delta: float) -> void:
	var waves: Array = rt.get("after", [])
	for i in range(waves.size() - 1, -1, -1):
		var wave: Dictionary = waves[i]
		wave.time = float(wave.time) - delta
		if float(wave.time) > 0.0: continue
		waves.remove_at(i)
		if int(player.hp) <= 0: continue
		var at: Vector2 = Vector2(player.pos) if not Vector2(wave.pos).is_finite() else Vector2(wave.pos)
		_talent_hit = true
		_area(id, rt, str(wave.talent), {"status": str(wave.status)}, at, float(wave.r), float(wave.dmg))
		_talent_hit = false
		_event("nova", at, float(wave.r), {"fx": str(wave.fx), "talent": str(wave.talent), "life": 1.1 if bool(wave.get("impact", false)) else 0.7, "impact": bool(wave.get("impact", false))})
		_meteor_aftermath(id, wave, at)


## Whether an enemy stands in a zone: a circle, or the Flammenwall's line.
func _in_zone(zone: Dictionary, enemy: Dictionary) -> bool:
	if zone.has("path"):
		var path: Array = zone.path
		for i in range(path.size() - 1):
			if Geometry2D.get_closest_point_to_segment(enemy.pos, path[i], path[i + 1]).distance_to(enemy.pos) <= float(zone.w) + float(enemy.radius): return true
		return false
	if zone.has("wall"):
		var wall: Dictionary = zone.wall
		return Geometry2D.get_closest_point_to_segment(enemy.pos, wall.a, wall.b).distance_to(enemy.pos) <= float(wall.w) + float(enemy.radius)
	return Vector2(enemy.pos).distance_to(zone.pos) <= float(zone.r) + float(enemy.radius)


## Where a targeted ultimate lands: the mouse point, at most reach_m away.
func _spot(player: Dictionary, target: Vector2, info: Dictionary) -> Vector2:
	return Vector2(player.pos) + (target - Vector2(player.pos)).limit_length(float(info.get("reach_m", 8)) * float(data.meter_px))


## Moves an enemy in both worlds (the hell keeps its own position in "p").
func _shove(enemy: Dictionary, to: Vector2) -> void:
	enemy.pos = to
	if enemy.has("p"): enemy.p = to


## After a meteor lands: its crater burns, and Meteorschauer drops small
## meteors on enemies nearby (random spots when there are none).
func _meteor_aftermath(id: int, wave: Dictionary, at: Vector2) -> void:
	var meter := float(data.meter_px)
	var base := float(wave.get("base", 1.0))
	var crater: Dictionary = wave.get("crater", {})
	if not crater.is_empty():
		zones.append({"id": _take_id(), "owner": id, "talent": str(wave.talent), "pos": at, "r": float(crater.radius_m) * meter, "time": float(crater.time),
			"every": float(crater.every), "tick": float(crater.every), "dmg": float(crater.dmg) * base, "status": str(crater.status), "info": {"status": str(crater.status)}, "look": "crater"})
	var shower: Dictionary = wave.get("shower", {})
	if shower.is_empty(): return
	var near := _living().filter(func(e: Dictionary) -> bool: return Vector2(e.pos).distance_to(at) <= float(shower.search_m) * meter)
	var rt := runtime(id)
	for k in range(int(shower.count)):
		var spot := at + Vector2.from_angle(_rng.randf() * TAU) * meter * (2.0 + _rng.randf() * 3.0)
		if not near.is_empty(): spot = Vector2(near[k % near.size()].pos)
		var delay := float(shower.delay) + 0.25 * k
		_event("meteor_fall", spot, float(shower.radius_m) * meter, {"life": delay})
		rt.after.append({"time": delay, "pos": spot, "dmg": float(shower.dmg) * base, "r": float(shower.radius_m) * meter, "fx": "fire", "status": "burn", "talent": str(wave.talent)})


## Wildes Erwachen: the companion (called if missing) grows for a while:
## more damage and life, its bites hit an area, and it roars enemies onto itself.
func _awaken(id: int, player: Dictionary, rt: Dictionary, talent: String, info: Dictionary, base: float) -> void:
	var meter := float(data.meter_px)
	if permanent_pet(id).is_empty() and rt.has("permanent"):
		rt.pet_fell = false
		_spawn_pet(id, rt, str(rt.permanent), data.talents[str(rt.permanent)], Vector2(player.pos) + Vector2(-24, 14), false, INF)
	var pet := permanent_pet(id)
	if pet.is_empty():
		_spawn_pet(id, rt, talent, {"every": 2.0, "dmg": 0.45, "hp": 14}, Vector2(player.pos) + Vector2(-24, 14), false, float(info.time))
		pet = pets[-1]
	if not pet.has("hp_base"): pet.hp_base = float(pet.hp_max)
	var extra := float(pet.hp_base) * float(info.hp_pct) / 100.0
	pet.hp_max = float(pet.hp_base) + extra
	pet.hp = minf(float(pet.hp_max), float(pet.hp) + extra + float(pet.hp_max) * float(info.get("heal_pct", 0.0)) / 100.0)
	pet.awake = float(info.time)
	pet.awake_mult = float(info.dmg_mult)
	pet.awake_cleave_m = float(info.cleave_m)
	for enemy: Dictionary in _living():
		if not _boss(enemy) and Vector2(enemy.pos).distance_to(pet.pos) <= float(info.taunt_m) * meter: enemy.pet_taunt = {"pet": int(pet.id), "time": float(info.taunt)}
	_event("shout", pet.pos, float(info.taunt_m) * meter, {"pet": true})
	_event("buff", pet.pos, 30.0, {"buff": "frenzy"})
	var spirits: Dictionary = info.get("spirits", {})
	for k in range(int(spirits.get("count", 0))):
		_spawn_pet(id, rt, talent, {"every": float(spirits.every), "dmg": float(spirits.dmg), "hp": float(spirits.hp)}, Vector2(player.pos) + Vector2.from_angle(TAU * k / 2.0) * 30.0, true, float(spirits.time))
		pets[-1].kind = "wolf"


## Movement and line of sight of the host's world: the crypt's tile layout, or
## the host's own `talent_move` / `talent_blocked` (the hell runtime).
func _move(from: Vector2, step: Vector2, radius: float, layout: Variant = null) -> Vector2:
	if game.has_method("talent_move"): return game.talent_move(from, step, radius)
	return Dungeon.move_actor(from, step, radius, layout if layout != null else game.current_layout)


func _blocked(from: Vector2, to: Vector2, radius: float, layout: Variant = null) -> bool:
	if game.has_method("talent_blocked"): return game.talent_blocked(from, to, radius)
	return Dungeon.segment_blocked(from, to, radius, layout if layout != null else game.current_layout)


func _boss(enemy: Dictionary) -> bool:
	return bool(enemy.get("boss", false)) or bool(enemy.get("miniboss", false))


func _living() -> Array:
	return game.enemies.filter(func(e: Dictionary) -> bool: return float(e.hp) > 0.0)


func _nearest(point: Vector2, reach: float) -> Dictionary:
	var best := {}
	var best_distance := reach
	for enemy: Dictionary in _living():
		var distance: float = enemy.pos.distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best


func _own_pets(id: int) -> Array:
	return pets.filter(func(p: Dictionary) -> bool: return int(p.owner) == id)


func _take_id() -> int:
	_next_id += 1
	return _next_id


## A short effect from outside the talents (the mage's basic fireball bursting
## in the Hölle), drawn by src/vfx/talent_fx.gd like the talents' own.
func show_effect(kind: String, at: Vector2, radius: float, extra: Dictionary = {}) -> void:
	_event(kind, at, radius, extra)


func _event(kind: String, at: Vector2, radius: float, extra: Dictionary) -> void:
	var entry := {"id": _take_id(), "kind": kind, "x": at.x, "y": at.y, "r": radius, "life": 0.5}
	entry.merge(extra, true)
	# its whole length, so clients can play an animation over it
	entry.span = float(entry.life)
	events.append(entry)
