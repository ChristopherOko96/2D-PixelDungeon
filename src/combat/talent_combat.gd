extends RefCounted
## Host-side talents in a run (assets/data/talents.json, rules in
## src/progress/talent_rules.gd): each hero's resource (mana, stamina, rage),
## the active talents on the talent bar (Shift + 1-4) and the ultimate (R),
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

## Input bits: 4-7 talent bar slots (Shift + 1-4), 8 the ultimate (R).
const BAR_BIT := 4
const ULT_BIT := 8
const STATUS_TALENTS := ["burn", "poison", "bleed"]

## The host: the crypt game, or an object with the same members (src/hell/hell_talents.gd).
var game: Object
var data: Dictionary = {}
## Peer id -> runtime {class, ranks, ultimate, soul_tier, bar, res, res_max, regen, cds, gcd, buffs, ...}.
var runtimes: Dictionary = {}
var pets: Array = []
var traps: Array = []
var zones: Array = []
## Short visual events: {id, kind, x, y, r, life, ...}.
var events: Array = []
var _next_id := 1
var _rng := RandomNumberGenerator.new()
## True while a talent deals its own damage (not a basic attack).
var _talent_hit := false
## True while a mage talent deals damage (Zeitbruch and Echo apply).
var _spell_hit := false


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
	events.clear()


## Leaving a room: wolves, traps and zones stay behind, channels end.
func room_changed() -> void:
	pets.clear()
	traps.clear()
	zones.clear()
	for rt: Dictionary in runtimes.values():
		rt.channel = {}
		rt.counter = {}
		rt.after = []


## Sets a hero's talents from a profile build ({class, level, ranks, ultimate,
## soul_tier, bar}); the build is checked against the rules first, so a forged
## build never gives more than the level allows.
func set_build(id: int, build: Dictionary) -> void:
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
		"free": bool(build.get("free", false)) and OS.is_debug_build()}
	var bonus := _passive(rt, "resource_bonus")
	if not bonus.is_empty():
		rt.res_max += _value(bonus, "max", rt)
		rt.regen *= 1.0 + _value(bonus, "regen_pct", rt) / 100.0
	rt.res = float(res.start) if str(res.kind) == "rage" else rt.res_max
	runtimes[id] = rt


func runtime(id: int) -> Dictionary:
	return runtimes.get(id, {})


## Reads the talent bits of a hero's command (edge-triggered: one cast per press).
func handle_input(id: int, player: Dictionary, command: Dictionary) -> void:
	var rt := runtime(id)
	if rt.is_empty() or int(player.hp) <= 0: return
	var bits := int(command.get("skills", 0))
	var pressed := bits & ~int(rt.prev_bits)
	rt.prev_bits = bits
	for slot in range(int(data.bar_slots)):
		if pressed & (1 << (BAR_BIT + slot)) and slot < rt.bar.size(): cast(id, str(rt.bar[slot]), command)
	if pressed & (1 << ULT_BIT) and not str(rt.ultimate).is_empty(): cast(id, str(rt.ultimate), command)


## Why `talent` cannot be cast now, or "".
func cast_blocker(id: int, talent: String) -> String:
	var rt := runtime(id)
	var info: Dictionary = data.talents.get(talent, {})
	if rt.is_empty() or info.is_empty() or int(rt.ranks.get(talent, 0)) <= 0: return "nicht gelernt"
	if str(info.kind) == "passive": return "passiv"
	if float(rt.cds.get(talent, 0.0)) > 0.0: return "Abklingzeit"
	if float(rt.gcd) > 0.0: return "Abklingzeit"
	if float(rt.res) < float(info.cost) and not bool(rt.get("free", false)): return "zu wenig " + str(data.resources[rt["class"]].name)
	if str(info.type) == "pet_leap" and _own_pets(id).is_empty(): return "kein Begleiter aktiv"
	return ""


## Casts an active talent or the ultimate: spends the resource, starts the
## cooldowns and runs the effect. Returns true when it fired.
func cast(id: int, talent: String, command: Dictionary = {}) -> bool:
	if not cast_blocker(id, talent).is_empty(): return false
	var player: Dictionary = game.players[id]
	var rt := runtime(id)
	var info := _info(rt, talent)
	# the talent test profile (debug builds): no cost, half a second to reload
	var free := bool(rt.get("free", false))
	if not free: rt.res = float(rt.res) - float(info.cost)
	var cooldown := 0.5 if free else float(info.cd)
	if rt.buffs.has("timebreak"): cooldown *= 1.0 - float(rt.buffs.timebreak.cdr_pct) / 100.0
	rt.cds[talent] = cooldown
	rt.gcd = 0.25 if free else float(data.global_cooldown)
	rt.cast_count = int(rt.get("cast_count", 0)) + 1
	var aim: Vector2 = Vector2(command.get("aim", player.get("aim", Vector2.RIGHT)))
	if aim.length_squared() < 0.01: aim = Vector2.RIGHT
	aim = aim.normalized()
	var target: Vector2 = Vector2(command.get("target", Vector2.INF))
	if not target.is_finite(): target = Vector2(player.pos) + aim * 160.0
	var spell: bool = str(rt["class"]) == "mage"
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
			if bool(info.get("cleanse", false)) and game.has_method("cleanse_slows"): game.cleanse_slows(id)
			_event("blink", origin, 0.0, {"tx": player.pos.x, "ty": player.pos.y, "fx": str(info.get("fx", "arcane"))})
		"dash":
			var from: Vector2 = player.pos
			player.pos = _move(player.pos, aim * _value(info, "dist_m", rt, talent) * meter, float(game.balance.player.radius), game.current_layout)
			for enemy: Dictionary in _living():
				if Geometry2D.get_closest_point_to_segment(enemy.pos, from, player.pos).distance_to(enemy.pos) <= float(enemy.radius) + 22.0:
					_hit(id, enemy, dmg, info, rt, talent)
			_event("dash", from, 0.0, {"tx": player.pos.x, "ty": player.pos.y})
		"melee":
			var reach := float(info.reach_m) * meter
			for enemy: Dictionary in _living():
				var offset: Vector2 = enemy.pos - player.pos
				if offset.length() > reach + float(enemy.radius) or absf(aim.angle_to(offset)) > float(info.arc) * 0.5: continue
				if _blocked(player.pos, enemy.pos, 0.0, game.current_layout): continue
				_hit(id, enemy, dmg, info, rt, talent)
				if info.has("taunt"): _taunt(enemy, id, float(info.taunt))
			_event("swing", player.pos, reach, {"angle": aim.angle(), "arc": float(info.arc)})
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
		"mark":
			var enemy := _nearest(target, 96.0)
			if enemy.is_empty(): enemy = _nearest(player.pos, 420.0)
			if not enemy.is_empty():
				enemy.talent_mark = {"owner": id, "pct": _value(info, "pct", rt, talent), "time": _value(info, "time", rt, talent)}
				_event("mark", enemy.pos, 20.0, {})
		"trap":
			var spot: Vector2 = player.pos + (target - player.pos).limit_length(6.0 * meter)
			spot = _move(player.pos, spot - player.pos, 10.0, game.current_layout)
			var mine := traps.filter(func(t: Dictionary) -> bool: return int(t.owner) == id)
			if mine.size() >= int(data.max_traps): traps.erase(mine[0])
			traps.append({"id": _take_id(), "owner": id, "talent": talent, "pos": spot, "r": float(info.radius_m) * meter, "trigger": 28.0,
				"dmg": dmg * (1.0 + _sum(rt, "trap_bonus", "pct") / 100.0), "root": _value(info, "root", rt, talent), "life": float(data.trap_life)})
		"zone":
			var spot: Vector2 = player.pos + (target - player.pos).limit_length(7.0 * meter)
			zones.append({"id": _take_id(), "owner": id, "talent": talent, "pos": spot, "r": float(info.radius_m) * meter, "time": float(info.time),
				"every": maxf(0.25, float(info.every)), "tick": 0.0, "dmg": dmg, "status": str(info.get("status", "")), "info": info})
		"summon":
			var mine := _own_pets(id)
			var wanted := int(info.count)
			if bool(info.get("pack", false)) and mine.filter(func(p: Dictionary) -> bool: return not bool(p.pack)).is_empty():
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
				"info": {"status": str(info.get("status", ""))}}
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
				if int(rt.channel.left) <= 0: rt.channel = {}
		_step_after(int(id), player, rt, delta)
	_step_pets(delta)
	_step_traps(delta)
	_step_zones(delta)
	for enemy: Dictionary in game.enemies:
		for key: String in ["talent_mark", "pet_taunt", "talent_taunt"]:
			if enemy.has(key):
				enemy[key].time = float(enemy[key].time) - delta
				if float(enemy[key].time) <= 0.0: enemy.erase(key)
	for i in range(events.size() - 1, -1, -1):
		events[i].life = float(events[i].life) - delta
		if float(events[i].life) <= 0.0: events.remove_at(i)


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
	var mark: Dictionary = enemy.get("talent_mark", {})
	if int(mark.get("owner", -1)) == owner: pct += float(mark.pct)
	if rt.buffs.has("bloodlust"): pct += float(rt.buffs.bloodlust.damage_pct)
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
	if bool(enemy.get("boss", false)):
		var tally: Dictionary = enemy.get("damage_by", {})
		tally[owner] = float(tally.get(owner, 0.0)) + amount
		enemy.damage_by = tally
	if feedback and not _talent_hit and str(rt.res_kind) == "rage":
		rt.res = minf(float(rt.res_max), float(rt.res) + float(data.resources[rt["class"]].per_hit) + _sum(rt, "rage_per_hit", "amount"))
	if rt.buffs.has("bloodlust") and feedback: _heal(owner, rt, amount * float(rt.buffs.bloodlust.lifesteal_pct) / 100.0)


## Damage a hero takes after counters, reductions, the wolf's guard and
## shields; also rage from being hit and Wächtereid between allies.
func incoming(id: int, damage: int, _direction: Vector2) -> int:
	var rt := runtime(id)
	if rt.is_empty() or damage <= 0: return damage
	var player: Dictionary = game.players[id]
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


## Blutdurst heals the killer.
func enemy_killed(_enemy: Dictionary, owner: int) -> void:
	var rt := runtime(owner)
	if rt.is_empty(): return
	var thirst := _passive(rt, "heal_on_kill")
	if thirst.is_empty(): return
	var player: Dictionary = game.players.get(owner, {})
	_heal(owner, rt, float(player.get("max_hp", 1)) * _value(thirst, "pct", rt) / 100.0)


## A taunted enemy's forced target: a hero's peer id, or a wolf as a decoy
## {id (negative), pos}. Empty when nothing forces it. Bosses are immune.
func forced_target(enemy: Dictionary) -> Dictionary:
	if _boss(enemy): return {}
	if enemy.has("pet_taunt"):
		for pet: Dictionary in pets:
			if int(pet.id) == int(enemy.pet_taunt.pet): return {"id": -100000 - int(pet.id), "pos": pet.pos}
	if enemy.has("talent_taunt") and game.players.has(int(enemy.talent_taunt.owner)): return {"id": int(enemy.talent_taunt.owner), "pos": game.players[int(enemy.talent_taunt.owner)].pos}
	return {}


## What clients draw: wolves, traps, poison zones and short events.
func snapshot() -> Dictionary:
	var out := {"pets": [], "traps": [], "zones": [], "events": events.duplicate(true)}
	for pet: Dictionary in pets: out.pets.append({"id": pet.id, "x": pet.pos.x, "y": pet.pos.y, "face": pet.face, "owner": pet.owner, "bite": float(pet.bite), "pack": bool(pet.pack), "moving": bool(pet.moving), "kind": str(pet.get("kind", "wolf"))})
	for trap: Dictionary in traps: out.traps.append({"id": trap.id, "x": trap.pos.x, "y": trap.pos.y, "r": trap.r, "owner": trap.owner, "boom": float(trap.root) <= 0.0})
	for zone: Dictionary in zones: out.zones.append({"id": zone.id, "x": zone.pos.x, "y": zone.pos.y, "r": zone.r, "time": zone.time, "status": str(zone.get("status", ""))})
	return out


## The HUD's view of one hero: resource, bar slots with cooldowns, ultimate, buffs, shield.
func player_state(id: int) -> Dictionary:
	var rt := runtime(id)
	if rt.is_empty(): return {}
	var slots: Array = []
	for talent: String in rt.bar: slots.append(_slot(id, rt, talent))
	return {"res": snappedf(float(rt.res), 0.1), "res_max": float(rt.res_max), "res_kind": str(rt.res_kind), "slots": slots,
		"ult": _slot(id, rt, str(rt.ultimate)) if not str(rt.ultimate).is_empty() else {}, "buffs": rt.buffs.keys(), "shield": float(rt.shield),
		"counter": not rt.counter.is_empty(), "channel": not rt.channel.is_empty()}


func _slot(id: int, rt: Dictionary, talent: String) -> Dictionary:
	var info: Dictionary = data.talents[talent]
	return {"id": talent, "name": str(info.name), "icon": str(info.icon), "spec": str(info.spec), "cd": snappedf(float(rt.cds.get(talent, 0.0)), 0.05),
		"cd_max": float(info.cd), "gcd": float(rt.gcd), "cost": float(info.cost), "ready": cast_blocker(id, talent).is_empty()}


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
	if dmg > 0.0: game._damage_enemy(enemy, dmg, direction, id, true)
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
	_talent_hit = false
	_spell_hit = false


## The companion kind of a build ("wolf", "bear"; talents.json "pet.kinds"), the default when unknown.
func _companion(kind: String) -> String:
	var kinds: Dictionary = data.get("pet", {}).get("kinds", {})
	return kind if kinds.has(kind) else str(data.get("pet", {}).get("default_kind", "wolf"))


func _spawn_pet(id: int, rt: Dictionary, talent: String, info: Dictionary, at: Vector2, pack: bool, life: float) -> void:
	var bond := _passive(rt, "pet_bonus")
	var kind := str(rt.get("companion", "wolf"))
	var traits: Dictionary = data.get("pet", {}).get("kinds", {}).get(kind, {})
	var hp := float(info.get("hp", 6)) * float(traits.get("hp", 1.0)) * (1.0 + (_value(bond, "hp_pct", rt) / 100.0 if not bond.is_empty() else 0.0))
	var dmg_scale := float(traits.get("dmg", 1.0)) * (1.0 + (_value(bond, "dmg_pct", rt) / 100.0 if not bond.is_empty() else 0.0))
	var base := float(game.players[id].get("damage", 1.0))
	pets.append({"id": _take_id(), "owner": id, "talent": talent, "pos": at, "hp": hp, "life": life,
		"every": float(info.every) * float(traits.get("every", 1.0)), "timer": 0.6, "dmg": _value(info, "dmg", rt, talent) * base * dmg_scale * _soul(rt, talent, "damage"),
		"pack": pack, "target": -1, "face": 1.0, "bite": 0.0, "moving": false, "kind": kind, "speed": float(traits.get("speed", 1.0))})


func _step_pets(delta: float) -> void:
	var meter := float(data.meter_px)
	var config: Dictionary = data.pet
	for i in range(pets.size() - 1, -1, -1):
		var pet: Dictionary = pets[i]
		var owner: Dictionary = game.players.get(int(pet.owner), {})
		pet.life = float(pet.life) - delta
		pet.bite = maxf(0.0, float(pet.bite) - delta)
		if pet.life <= 0.0 or float(pet.hp) <= 0.0 or owner.is_empty() or int(owner.hp) <= 0:
			pets.remove_at(i)
			continue
		var prey := {}
		for enemy: Dictionary in _living():
			if int(enemy.id) == int(pet.target): prey = enemy
		if prey.is_empty() or prey.pos.distance_to(owner.pos) > 8.0 * meter:
			prey = _nearest(owner.pos, 6.0 * meter)
			pet.target = int(prey.get("id", -1))
		var goal: Vector2 = owner.pos + Vector2(-28.0 * float(owner.get("face", 1.0)), 18.0)
		if not prey.is_empty(): goal = prey.pos
		var before: Vector2 = pet.pos
		if Vector2(pet.pos).distance_to(goal) > (float(config.attack_range_m) * meter if not prey.is_empty() else 14.0):
			pet.pos = _move(pet.pos, (goal - pet.pos).limit_length(float(config.speed) * float(pet.get("speed", 1.0)) * delta), float(config.radius), game.current_layout)
		pet.moving = Vector2(pet.pos).distance_squared_to(before) > 0.01
		if absf(goal.x - pet.pos.x) > 2.0: pet.face = signf(goal.x - pet.pos.x)
		pet.timer = float(pet.timer) - delta
		if not prey.is_empty() and Vector2(pet.pos).distance_to(prey.pos) <= float(config.attack_range_m) * meter + float(prey.radius) and float(pet.timer) <= 0.0:
			pet.timer = float(pet.every)
			pet.bite = 0.25
			var rt := runtime(int(pet.owner))
			rt.pet_target = int(prey.id)
			_talent_hit = true
			game._damage_enemy(prey, float(pet.dmg), (Vector2(prey.pos) - Vector2(pet.pos)).normalized(), int(pet.owner), true)
			_talent_hit = false
		# Enemies drawn to the wolf (Fass!) bite back.
		for enemy: Dictionary in _living():
			if enemy.has("pet_taunt") and int(enemy.pet_taunt.pet) == int(pet.id) and enemy.pos.distance_to(pet.pos) < float(enemy.radius) + 14.0:
				pet.hp = float(pet.hp) - 2.0 * delta


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
		traps.remove_at(i)


func _step_zones(delta: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var zone: Dictionary = zones[i]
		zone.time = float(zone.time) - delta
		zone.tick = float(zone.tick) - delta
		if float(zone.tick) <= 0.0:
			zone.tick = float(zone.every)
			var rt := runtime(int(zone.owner))
			_talent_hit = true
			for enemy: Dictionary in _living():
				if enemy.pos.distance_to(zone.pos) <= float(zone.r) + float(enemy.radius):
					_hit(int(zone.owner), enemy, float(zone.dmg), zone.get("info", data.talents[str(zone.talent)]), rt, str(zone.talent))
			_talent_hit = false
		if float(zone.time) <= 0.0: zones.remove_at(i)


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
		_event("nova", at, float(wave.r), {"fx": str(wave.fx), "talent": str(wave.talent), "life": 0.7})


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


func _event(kind: String, at: Vector2, radius: float, extra: Dictionary) -> void:
	var entry := {"id": _take_id(), "kind": kind, "x": at.x, "y": at.y, "r": radius, "life": 0.5}
	entry.merge(extra, true)
	# its whole length, so clients can play an animation over it
	entry.span = float(entry.life)
	events.append(entry)
