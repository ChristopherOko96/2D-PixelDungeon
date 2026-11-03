extends RefCounted
## Host-owned transient Seele ultimate. Shared talent runtime in Crypt/Hell/Frost.
## No client input or sprite state can apply damage. Configuration is captured
## at cast time; animation phases and their hit moments use the same clock.
const Targets = preload("res://src/combat/companion_targets.gd")
const Rigs = preload("res://src/rig/rig_library.gd")
var actors: Array = []

## One guardian per owner; replacing it never creates extra attacks.
func summon(tc: RefCounted, owner: int, info: Dictionary, aim: Vector2, damage: float) -> void:
	actors = actors.filter(func(g: Dictionary) -> bool: return int(g.owner) != owner)
	var hero: Dictionary = tc.game.players[owner]
	var radius := float(info.body_radius)
	var at: Vector2 = tc._move(hero.pos, aim * float(info.spawn_offset), radius)
	actors.append({"id": tc._take_id(), "owner": owner, "pos": at, "info": info.duplicate(true), "damage": damage,
		"total": float(info.time), "left": float(info.time), "age": 0.0, "motion": "spawn", "phase": 0.0,
		"phase_seq": 0, "target": -1, "face": -1.0 if aim.x < 0 else 1.0, "aim": aim,
		"cooldown": 0.0, "wave_wait": float(info.wave_every), "hit": false, "wave": false,
		"cds": [0.0, 0.0], "autos": [false, true], "beam_length": 0.0, "beam_tick": 0.0,
		"beam_target": -1, "beam_end": at, "beam_broken": false,
		"route": PackedVector2Array(), "route_wait": 0.0, "route_goal": at})

## Timers never catch up by dealing multiple hits in one tick. A fading/dead
## owner's summon cannot hit, and missing owners are removed immediately.
func step(tc: RefCounted, delta: float) -> void:
	for enemy: Dictionary in tc.game.enemies:
		if not enemy.has("soul_claim"): continue
		enemy.soul_claim.time = float(enemy.soul_claim.time) - delta
		if float(enemy.soul_claim.time) <= 0.0: enemy.erase("soul_claim")
	for i in range(actors.size() - 1, -1, -1):
		var g: Dictionary = actors[i]
		var hero: Dictionary = tc.game.players.get(int(g.owner), {})
		var rt: Dictionary = tc.runtime(int(g.owner))
		if hero.is_empty() or int(hero.hp) <= 0 or rt.is_empty() or str(rt.get("ultimate", "")) != "soul_14":
			actors.remove_at(i)
			continue
		var cfg: Dictionary = g.info
		g.left = maxf(0.0, float(g.left) - delta)
		g.age = float(g.age) + delta
		g.phase = float(g.phase) + delta
		g.cooldown = maxf(0.0, float(g.cooldown) - delta)
		g.wave_wait = maxf(0.0, float(g.wave_wait) - delta)
		for slot in range(2): g.cds[slot] = maxf(0.0, float(g.cds[slot]) - delta)
		if float(g.left) <= 0.0:
			actors.remove_at(i)
			continue
		if float(g.left) <= float(cfg.dissolve_time):
			if str(g.motion) != "dissolve": _phase(g, "dissolve", float(cfg.dissolve_time) - float(g.left))
			continue
		if str(g.motion) == "spawn":
			if float(g.phase) < float(cfg.spawn_time): continue
			_phase(g, "hover")
		if str(g.motion) == "beam":
			_beam_step(tc, g, rt)
			var beam: Dictionary = cfg.commands[0]
			if float(g.phase) < float(beam.windup) + float(beam.time) + float(beam.recovery): continue
			_phase(g, "hover")
		if str(g.motion) == "grasp":
			if not bool(g.hit) and float(g.phase) >= float(cfg.hit_time):
				g.hit = true
				_impact(tc, g, rt)
			if float(g.phase) < float(cfg.attack_time): continue
			_phase(g, "hover")
		var prey := _prey(tc, g, hero, rt)
		g.target = tc._eid(prey) if not prey.is_empty() else -1
		var goal: Vector2 = Vector2(hero.pos) + Vector2(-float(cfg.follow_offset) * float(hero.get("face", 1.0)), float(cfg.follow_y))
		if not prey.is_empty(): goal = prey.pos
		var offset: Vector2 = goal - Vector2(g.pos)
		if not prey.is_empty() and offset.length_squared() > 0.01:
			g.aim = offset.normalized()
			if absf(offset.x) > 2.0: g.face = signf(offset.x)
		if bool(g.autos[0]) and not prey.is_empty() and float(g.cds[0]) <= 0.0 and offset.length() <= float(cfg.commands[0].range_m) * float(tc.data.meter_px):
			if command(tc, int(g.owner), 0, (Vector2(prey.pos) - Vector2(g.pos)).normalized()): continue
		var wave := bool(g.autos[1]) and float(g.wave_wait) <= 0.0 and not prey.is_empty()
		var reach := float(cfg.wave_range_m if wave else cfg.reach_m) * float(tc.data.meter_px)
		if not prey.is_empty() and offset.length() <= reach + float(prey.radius) and not tc._blocked(g.pos, prey.pos, 1.0):
			if float(g.cooldown) <= 0.0:
				g.wave = wave
				g.hit = false
				g.cooldown = float(cfg.every)
				if wave:
					g.wave_wait = float(cfg.wave_every)
					g.cds[1] = float(cfg.wave_every)
				_phase(g, "grasp")
			continue
		if offset.length() > float(cfg.follow_stop): _follow(tc, g, goal, delta)

func _phase(g: Dictionary, motion: String, age: float = 0.0) -> void:
	g.motion = motion
	g.phase = age
	g.phase_seq = int(g.phase_seq) + 1

func _prey(tc: RefCounted, g: Dictionary, _hero: Dictionary, rt: Dictionary) -> Dictionary:
	return Targets.pick(tc, g, rt, true)

func _follow(tc: RefCounted, g: Dictionary, goal: Vector2, delta: float) -> void:
	var cfg: Dictionary = g.info
	var before: Vector2 = g.pos
	Targets.follow(tc, g, goal, delta, cfg, float(cfg.speed), float(cfg.body_radius))
	var offset: Vector2 = Vector2(g.pos) - before
	if absf(offset.x) > 2.0: g.face = signf(offset.x)

func _impact(tc: RefCounted, g: Dictionary, rt: Dictionary) -> void:
	var cfg: Dictionary = g.info
	var reach := float(cfg.wave_range_m if bool(g.wave) else cfg.reach_m) * float(tc.data.meter_px)
	var arc := float(cfg.wave_arc if bool(g.wave) else cfg.grasp_arc)
	var victims: Array = []
	for enemy: Dictionary in tc._living():
		if not bool(g.wave) and tc._eid(enemy) != int(g.target): continue
		var offset: Vector2 = Vector2(enemy.pos) - Vector2(g.pos)
		if offset.length() > reach + float(enemy.radius) or absf(Vector2(g.aim).angle_to(offset)) > arc * 0.5: continue
		if tc._blocked(g.pos, enemy.pos, 1.0): continue
		victims.append(enemy)
	# A secondary talent source cannot become the hero's commanded target.
	var saved_target := int(rt.get("hero_target", -1))
	var saved_talent_hit: bool = tc._talent_hit
	var saved_pet_source: int = tc._pet_source
	tc._talent_hit = true
	for enemy: Dictionary in victims:
		mark(tc, g, enemy)
		tc._hit(int(g.owner), enemy, float(g.damage) * (float(cfg.wave_damage) if bool(g.wave) else 1.0), {}, rt, "soul_14")
		if float(enemy.hp) > 0.0: tc._soul_grasp({"owner": g.owner, "pos": g.pos, "talent": "soul_14", "info": cfg}, enemy)
	tc._talent_hit = saved_talent_hit
	tc._pet_source = saved_pet_source
	rt.hero_target = saved_target
	if bool(g.wave): tc._event("guardian_wave", g.pos, reach, {"owner": g.owner, "talent": "soul_14", "angle": Vector2(g.aim).angle(), "arc": arc, "life": float(cfg.wave_visual_time)})

## Primitive, independent snapshot data only: no textures, routes or stats.
func snapshot() -> Array:
	var out: Array = []
	for g: Dictionary in actors:
		var duration := float(g.info.get("spawn_time", 0.64))
		if str(g.motion) == "hover": duration = float(g.info.hover_time)
		elif str(g.motion) == "grasp": duration = float(g.info.attack_time)
		elif str(g.motion) == "dissolve": duration = float(g.info.dissolve_time)
		elif str(g.motion) == "beam":
			var beam: Dictionary = g.info.commands[0]
			duration = float(beam.windup) + float(beam.time) + float(beam.recovery)
		out.append({"id": g.id, "owner": g.owner, "x": Vector2(g.pos).x, "y": Vector2(g.pos).y, "face": g.face,
			"radius": float(g.info.body_radius), "motion": str(g.motion), "age": float(g.phase), "duration": duration, "phase_seq": g.phase_seq, "left": g.left, "total": g.total,
			"aim_x": Vector2(g.aim).x, "aim_y": Vector2(g.aim).y, "beam_length": float(g.beam_length),
			"beam_target_id": int(g.beam_target), "beam_tx": Vector2(g.beam_end).x, "beam_ty": Vector2(g.beam_end).y,
			"beam_attached": int(g.beam_target)>=0 and not bool(g.beam_broken),
			"beam_windup": float(g.info.commands[0].windup), "beam_time": float(g.info.commands[0].time), "beam_width": float(g.info.commands[0].width_m)})
	return out

## Living summon for one authoritative owner, never another player's guardian.
func owned(owner: int) -> Dictionary:
	for actor: Dictionary in actors:
		if int(actor.owner) == owner and float(actor.left) > 0.0: return actor
	return {}

## Existing validated companion input routes here while this summon is present.
func command(tc: RefCounted, owner: int, slot: int, aim: Vector2) -> bool:
	var g := owned(owner)
	var hero: Dictionary = tc.game.players.get(owner, {})
	if g.is_empty() or hero.is_empty() or int(hero.hp) <= 0 or slot < 0 or slot > 1: return false
	if str(g.motion) in ["spawn", "dissolve", "beam"] or float(g.cds[slot]) > 0.0: return false
	if not aim.is_finite() or aim.length_squared() < 0.001: aim = Vector2.RIGHT * float(g.face)
	g.aim = aim.normalized()
	if absf(aim.x) > 0.01: g.face = signf(aim.x)
	var ability: Dictionary = g.info.commands[slot]
	g.cds[slot] = float(ability.cd)
	g.cooldown = float(g.info.every)
	if str(ability.type) == "beam":
		g.beam_tick = float(ability.windup)
		g.beam_target = -1
		g.beam_broken = false
		_beam_trace(tc,g)
		_phase(g, "beam")
	else:
		g.wave = true
		g.hit = false
		g.wave_wait = float(g.info.wave_every)
		_phase(g, "grasp")
	return true

func _beam_length(tc: RefCounted, g: Dictionary) -> float:
	var cfg: Dictionary = g.info.commands[0]
	var reach := float(cfg.range_m) * float(tc.data.meter_px)
	var half := float(cfg.width_m) * float(tc.data.meter_px) * 0.5
	var length := 0.0
	while length < reach:
		var next := minf(reach, length + 4.0)
		if tc._blocked(g.pos, Vector2(g.pos) + Vector2(g.aim) * next, half): break
		length = next
	return length

func _beam_step(tc: RefCounted, g: Dictionary, rt: Dictionary) -> void:
	var cfg: Dictionary = g.info.commands[0]
	_beam_trace(tc,g)
	if bool(g.beam_broken): return
	if float(g.phase) < float(cfg.windup) or float(g.phase) >= float(cfg.windup) + float(cfg.time): return
	if float(g.phase) < float(g.beam_tick): return
	g.beam_tick = float(g.phase) + float(cfg.every)
	var end := Vector2(g.pos) + Vector2(g.aim) * float(g.beam_length)
	var half := float(cfg.width_m) * float(tc.data.meter_px) * 0.5
	var old_hit: bool = tc._talent_hit
	var old_target := int(rt.get("hero_target", -1))
	tc._talent_hit = true
	for enemy: Dictionary in tc._living():
		if (Vector2(enemy.pos) - Vector2(g.pos)).dot(Vector2(g.aim)) < 0.0: continue
		if Geometry2D.get_closest_point_to_segment(enemy.pos, g.pos, end).distance_to(enemy.pos) > half + float(enemy.radius): continue
		if tc._blocked(g.pos, enemy.pos, 1.0): continue
		mark(tc, g, enemy)
		tc._hit(int(g.owner), enemy, float(g.damage) * float(cfg.damage), {}, rt, "soul_14")
	tc._talent_hit = old_hit
	rt.hero_target = old_target

## Bind to the first visible body on the cast ray, then retain its stable ID.
## Missing/dead/occluded targets release this channel, never a new enemy slot.
func _beam_trace(tc: RefCounted, g: Dictionary) -> void:
	if bool(g.beam_broken):
		g.beam_length = 0.0
		return
	var cfg: Dictionary = g.info.commands[0]
	var target := {}
	if int(g.beam_target)>=0:
		for enemy: Dictionary in tc._living():
			if tc._eid(enemy)==int(g.beam_target):
				target = enemy
				break
		if target.is_empty() or Vector2(g.pos).distance_to(target.pos)>float(cfg.range_m)*float(tc.data.meter_px) or tc._blocked(g.pos,target.pos,1.0):
			g.beam_broken = true
			g.beam_length = 0.0
			return
	else:
		g.beam_length = _beam_length(tc,g)
		var end := Vector2(g.pos)+Vector2(g.aim)*float(g.beam_length)
		var nearest := INF
		for enemy: Dictionary in tc._living():
			var offset: Vector2 = Vector2(enemy.pos)-Vector2(g.pos)
			var distance := offset.dot(Vector2(g.aim))
			if distance<0 or offset.length()>float(cfg.range_m)*float(tc.data.meter_px) or distance>=nearest: continue
			if Geometry2D.get_closest_point_to_segment(enemy.pos,g.pos,end).distance_to(enemy.pos)>float(cfg.width_m)*float(tc.data.meter_px)*0.5+float(enemy.radius): continue
			if tc._blocked(g.pos,enemy.pos,1.0): continue
			target = enemy
			nearest = distance
		if not target.is_empty(): g.beam_target = tc._eid(target)
	if not target.is_empty():
		g.beam_end = Vector2(target.pos)
		g.beam_length = Vector2(g.pos).distance_to(target.pos)
		if float(g.beam_length)>0.01: g.aim = (Vector2(target.pos)-Vector2(g.pos)).normalized()
	else: g.beam_end = Vector2(g.pos)+Vector2(g.aim)*float(g.beam_length)

## Applied before damage, so the same lethal hit can legitimately claim a soul.
func mark(tc: RefCounted, g: Dictionary, enemy: Dictionary) -> void:
	if tc._boss(enemy) or bool(enemy.get("summoned", false)) or float(enemy.hp) <= 0.0: return
	enemy.soul_claim = {"owner": int(g.owner), "time": float(g.info.claim.time)}

## Host-confirmed death callback. Uses separate friendly pets, never a living
## hostile slot, and never copies boss HP/damage or recursively marks targets.
func claim(tc: RefCounted, enemy: Dictionary) -> void:
	var seal: Dictionary = enemy.get("soul_claim", {})
	if seal.is_empty() or float(seal.get("time", 0.0)) <= 0.0 or tc._boss(enemy) or bool(enemy.get("summoned", false)): return
	var owner := int(seal.owner)
	var hero: Dictionary = tc.game.players.get(owner, {})
	var rt: Dictionary = tc.runtime(owner)
	if hero.is_empty() or int(hero.hp) <= 0 or rt.is_empty() or str(rt.get("ultimate", "")) != "soul_14": return
	var cfg: Dictionary = tc.data.talents.soul_14.claim
	var army: Array = tc.pets.filter(func(p: Dictionary) -> bool: return bool(p.get("converted", false)) and float(p.life) > 0 and float(p.hp) > 0)
	if army.size() >= int(cfg.total_max) or army.filter(func(p: Dictionary) -> bool: return int(p.owner) == owner).size() >= int(cfg.max): return
	var name := str(enemy.get("rig", enemy.get("def", {}).get("rig", "")))
	if name.is_empty(): name = str({"skeleton_archer": "skel_archer", "skeleton_guard": "skel_guard", "necromancer": "necro"}.get(str(enemy.get("kind", "")), "skeleton"))
	if Rigs.shared().rig(name).is_empty(): name = "skeleton"
	tc._spawn_pet(owner, rt, "soul_14", {"pet_kind": "skeleton", "every": float(cfg.every), "dmg": float(cfg.damage), "hp": float(cfg.hp)}, enemy.pos, false, float(cfg.life))
	var pet: Dictionary = tc.pets[-1]
	pet.converted = true
	pet.source_kind = str(enemy.get("kind", ""))
	pet.source_id = tc._eid(enemy)
	pet.total_life = float(cfg.life)
	pet.parts_lost = []
	tc._rig_pet(pet, {"rig": name})
	var family: Dictionary = Rigs.shared().rig(name)
	pet.ranged = str(family.get("variant", "")) == "bow" or str(family.get("family", "")) == "necro"
	pet.range_m = float(cfg.ranged_m) if bool(pet.ranged) else 0.0
	tc._event("soul_convert", enemy.pos, 18.0, {"owner": owner, "life": 0.8})

## Client HUD carries duration, cooldown and auto state, no combat authority.
func hud(tc: RefCounted, owner: int) -> Dictionary:
	var g := owned(owner)
	if g.is_empty(): return {}
	var out := {"kind": "soul_guardian", "name": "Seelenwächter", "spec": "soul", "alive": str(g.motion) != "dissolve", "hp": float(g.left), "hp_max": float(g.total), "duration": true, "abilities": [], "respawn": 0.0}
	for slot in range(2):
		var ability: Dictionary = g.info.commands[slot]
		out.abilities.append({"id": str(ability.id), "name": str(ability.name), "icon": str(ability.icon), "text": str(ability.text), "cd": float(g.cds[slot]), "cd_max": float(ability.cd), "auto": bool(g.autos[slot]), "key": str(5 + slot)})
	return out

## Debuffs are primitive presentation data; the host still owns the death claim.
func marks(tc: RefCounted) -> Array:
	var out: Array = []
	for enemy: Dictionary in tc._living():
		if not enemy.has("soul_claim"): continue
		out.append({"target_id": tc._eid(enemy), "owner": int(enemy.soul_claim.owner), "x": Vector2(enemy.pos).x, "y": Vector2(enemy.pos).y, "time": float(enemy.soul_claim.time)})
	return out
