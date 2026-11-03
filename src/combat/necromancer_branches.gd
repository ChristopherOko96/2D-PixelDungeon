extends RefCounted
## Host-only Grabrufer/Fluch rules. All liquids are actual existing element media.
## Each pool is spent atomically; clients receive primitives, never this state.
const RULES := "res://assets/data/necromancer_rules.json"
const Targets = preload("res://src/combat/companion_targets.gd")
const MonsterHost = preload("res://src/combat/curse_monster_host.gd")
const RigLibrary = preload("res://src/rig/rig_library.gd")
var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES))
var corpses: Array = []
var links: Array = []
var absorptions: Dictionary = {}
var secondary := false

## Fresh run or room: no remote corpse farming and no stale drain marks.
func clear() -> void:
	secondary = false
	for id: int in absorptions.keys(): _release_blood(id)
	corpses.clear()
	links.clear()

## Actual native/story puddle dictionaries, retaining reference identity.
func media(tc: RefCounted) -> Array:
	if tc.game.has_method("talent_media"): return tc.game.talent_media()
	var moves: Variant = tc.game.get("boss_moves")
	return moves.zones if moves != null else []

func _live(z: Dictionary) -> bool:
	return (str(z.get("kind", "")) == "puddle" and float(z.t) < float(z.T)) if z.has("p") else (str(z.get("kind", "")) == "pool" and float(z.get("timer", 0)) > 0)

func _mat(z: Dictionary) -> String:
	return str(z.get("st", z.get("style", "")))

func _at(z: Dictionary) -> Vector2:
	return Vector2(z.get("p", z.get("pos", Vector2.ZERO)))

func _radius(z: Dictionary) -> float:
	return float(z.get("r", z.get("radius", 0)))

func _end(tc: RefCounted, z: Dictionary) -> void:
	for field: Dictionary in tc.zones:
		if int(field.id) == int(z.get("necro_zone", -1)):
			field.time = 0.0
			field.dmg = 0.0
	if tc.game.has_method("talent_consume_pool"): tc.game.talent_consume_pool(z)
	elif z.has("timer"): z.timer = 0.0

## A field is gameplay material first. Avoid duplicate hand-drawn field overlays.
func pool(tc: RefCounted, owner: int, mat: String, at: Vector2, radius: float, life: float, small := false) -> void:
	if small:
		var own := media(tc).filter(func(z: Dictionary) -> bool: return _live(z) and _mat(z) == mat and int(z.get("fed_by", z.get("hostile", -1))) == owner and bool(z.get("necro_small", false)))
		while own.size() >= int(cfg.curse.small_pool_max): _end(tc, own.pop_front())
	tc._pool_at(owner, mat, at, radius, life, 0.0, "")
	var all := media(tc)
	if not all.is_empty():
		all[-1].necro_small = small
		all[-1].necro_owner = owner

## Existing corpse art and blood; no second enemy or repeated kill rewards.
func killed(tc: RefCounted, enemy: Dictionary, owner: int) -> void:
	if float(enemy.get("hp", 1)) > 0 or tc._boss(enemy) or bool(enemy.get("summoned", false)) or bool(enemy.get("converted", false)) or enemy.has("summoner"): return
	if not secondary:
		for link: Dictionary in links.duplicate():
			if str(link.kind)=="blood" and int(link.target_id)==tc._eid(enemy): _death_curse(tc,enemy,int(link.owner))
		if tc._pet_source < 0:
			_raise_runner(tc,enemy)
			MonsterHost.remember(tc,enemy,owner)
	for key: String in enemy.get("blood_marks",{}):
		var caster := int(key)
		var hero: Dictionary = tc.game.players.get(caster,{})
		if float(enemy.blood_marks[key]) <= 0 or hero.is_empty() or float(hero.hp) <= 0 or int(tc.runtime(caster).get("ranks",{}).get("minion_5",0)) <= 0: continue
		var sources := media(tc).filter(func(z:Dictionary)->bool:return _live(z) and bool(z.get("necro_mark_pool",false)) and int(z.get("necro_owner",-1))==caster)
		while sources.size() >= int(cfg.blood_mark.max_pools_per_owner): _end(tc,sources.pop_front())
		pool(tc,caster,"blood",enemy.pos,float(cfg.blood_mark.pool_radius_m)*float(tc.data.meter_px),float(cfg.blood_mark.pool_time))
		var all := media(tc)
		if not all.is_empty(): all[-1].necro_mark_pool = true
		# One marked enemy is one blood source, even when several players marked it.
		break
	var rt: Dictionary = tc.runtime(owner)
	if int(rt.get("ranks", {}).get("minion_7", 0)) > 0:
		var mine := corpses.filter(func(c: Dictionary) -> bool: return int(c.owner) == owner)
		if mine.size() >= int(cfg.corpses.max_per_owner): corpses.erase(mine[0])
		corpses.append({"id": tc._take_id(), "owner": owner, "pos": Vector2(enemy.pos), "time": float(cfg.corpses.time)})
	for entry: Dictionary in enemy.get("necro_curses", {}).values():
		var caster := int(entry.owner)
		var r: Dictionary = tc.runtime(caster)
		if float(entry.get("mark", 0)) <= 0 or int(r.get("ranks", {}).get("curse_13", 0)) <= 0 or int(entry.get("hops", 0)) >= int(cfg.curse.propagate_max): continue
		for next: Dictionary in tc._living():
			if next == enemy or Vector2(next.pos).distance_to(enemy.pos) > float(cfg.curse.propagate_radius_m) * float(tc.data.meter_px) or tc._blocked(enemy.pos, next.pos, 1): continue
			var entries: Dictionary = next.get("necro_curses", {})
			if entries.has(str(caster)): continue
			var copy := entry.duplicate(true)
			copy.hops = int(entry.get("hops", 0)) + 1
			copy.mark = minf(float(copy.mark), 6.0)
			entries[str(caster)] = copy
			next.necro_curses = entries
			break

## Per-owner marks make cooperative curses independent.
func tag(tc: RefCounted, id: int, enemy: Dictionary, info: Dictionary, talent: String) -> void:
	if float(enemy.hp) <= 0: return
	var rt: Dictionary = tc.runtime(id)
	var entries: Dictionary = enemy.get("necro_curses", {})
	var c: Dictionary = entries.get(str(id), {"owner": id, "decay": 0.0, "tick": 0.0, "mark": 0.0, "drain": 0.0, "hops": 0})
	if info.has("decay"):
		c.decay = float(info.decay_time)
		var bonus: float = tc._dot_bonus(rt, "poison")
		c.power = float(info.decay) * float(tc.game.players[id].get("damage", 1)) * (1.0 + bonus / 100.0)
	if talent == "curse_3":
		c.mark = tc._value(info, "time", rt, talent)
		c.pct = tc._value(info, "pct", rt, talent)
		c.hops = 0
	elif float(info.get("mark_time",0))>0:
		c.mark = float(info.mark_time)
		c.pct = float(info.get("mark_pct",10))
	if info.has("blood_drain"):
		c.drain = float(info.drain_time)
		c.drain_pct = tc._value(info, "blood_drain", rt, talent)
	entries[str(id)] = c
	enemy.necro_curses = entries

## Only resolved own damage drains; aggregate token bucket across all victims.
func dealt(tc: RefCounted, owner: int, enemy: Dictionary, resolved: float) -> void:
	if resolved <= 0 or tc._pet_source >= 0: return
	var rt: Dictionary = tc.runtime(owner)
	if int(rt.get("ranks", {}).get("curse_9", 0)) <= 0: return
	var c: Dictionary = enemy.get("necro_curses", {}).get(str(owner), {})
	var hero: Dictionary = tc.game.players.get(owner, {})
	if c.is_empty() or float(c.get("drain", 0)) <= 0 or hero.is_empty() or int(hero.hp) <= 0: return
	var cap := float(hero.max_hp) * float(cfg.curse.drain_cap_hp_pct) / 100.0
	var available := float(rt.get("drain_credit", cap))
	var heal := minf(available, resolved * float(c.drain_pct) / 100.0)
	if heal <= 0: return
	rt.drain_credit = available - heal
	if int(hero.hp) < int(hero.max_hp): tc._heal(owner, rt, heal)
	if float(rt.get("drain_fx", 0)) <= 0:
		rt.drain_fx = 0.22
		tc._event("necro_drain", enemy.pos, 0, {"tx": hero.pos.x, "ty": hero.pos.y, "target_id": tc._eid(enemy), "life": 0.65, "owner": owner})

## Explicit spell dispatch; returns false for existing shared spell types.
func cast(tc: RefCounted, id: int, player: Dictionary, rt: Dictionary, talent: String, info: Dictionary, target: Vector2, dmg: float) -> bool:
	var meter := float(tc.data.meter_px)
	match str(info.type):
		"curse_aura":
			for e: Dictionary in tc._living():
				if Vector2(e.pos).distance_to(player.pos)>float(info.radius_m)*meter+float(e.radius) or tc._blocked(player.pos,e.pos,1): continue
				tag(tc,id,e,info,"curse_3")
				tc._event("mark",e.pos,20,{"talent":talent})
			tc._event("necro_curse_aura",player.pos,float(info.radius_m)*meter,{"owner":id,"talent":talent,"life":0.7})
		"blood_mark":
			var at: Vector2 = tc._move(player.pos,(target-Vector2(player.pos)).limit_length(float(info.reach_m)*meter),2)
			for e: Dictionary in tc._living():
				if Vector2(e.pos).distance_to(at)>float(info.radius_m)*meter+float(e.radius) or tc._blocked(player.pos,e.pos,1): continue
				var marks: Dictionary = e.get("blood_marks",{})
				marks[str(id)] = float(info.time)
				e.blood_marks = marks
		"blood_beam":
			links = links.filter(func(l: Dictionary) -> bool: return not (int(l.owner) == id and str(l.kind) == "blood"))
			var rule: Dictionary = cfg.curse.beam
			var time := float(rule.time)
			var reach: float = tc._value(info,"radius_m",rt,talent)*meter
			var victims: Array = tc._living().filter(func(e:Dictionary)->bool:return Vector2(e.pos).distance_to(player.pos)<=reach and not tc._blocked(player.pos,e.pos,1))
			victims.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return Vector2(a.pos).distance_squared_to(player.pos)<Vector2(b.pos).distance_squared_to(player.pos))
			for victim: Dictionary in victims.slice(0,int(rule.max_targets)):
				links.append({"id":tc._take_id(),"owner":id,"target_id":tc._eid(victim),"talent":talent,"kind":"blood","left":time,"total":time,"every":float(rule.every),"tick":float(rule.every),"dmg":dmg*(1.0-float(rule.initial_share))*float(rule.every)/time,"reach":reach+float(rule.break_slack_m)*meter})
				tc._hit(id, victim, dmg * float(rule.initial_share), info, rt, talent)
				pool(tc,id,"blood",victim.pos,float(cfg.curse.small_pool_radius_m)*meter,float(cfg.curse.small_pool_time),true)
		"corpse_burst":
			var chosen := {}
			var best := float(info.reach_m) * meter
			for c: Dictionary in corpses:
				if int(c.owner) != id or tc._blocked(player.pos, c.pos, 1): continue
				var gap := Vector2(c.pos).distance_to(target)
				if Vector2(c.pos).distance_to(player.pos) <= float(info.reach_m) * meter and gap < best: chosen = c; best = gap
			var at: Vector2 = Vector2(chosen.pos) if not chosen.is_empty() else tc._move(player.pos, (target - Vector2(player.pos)).limit_length(float(info.reach_m) * meter), 10)
			if not chosen.is_empty():
				corpses.erase(chosen)
				pool(tc, id, "blood", at, float(cfg.corpses.blood_radius_m) * meter, float(cfg.corpses.blood_time))
			tc._area(id, rt, talent, {}, at, float(info.radius_m) * meter, dmg * (1.0 if not chosen.is_empty() else float(cfg.corpses.fallback_damage)))
			tc._event("necro_bones", at, float(info.radius_m) * meter, {"life": 0.8, "talent": talent})
		"siege_command":
			var pet: Dictionary = tc.permanent_pet(id)
			var enemy: Dictionary = tc._nearest(target, 4.0 * meter)
			if pet.is_empty() or enemy.is_empty(): return true
			pet.target = tc._eid(enemy)
			rt.hero_target = tc._eid(enemy)
			pet.protect = float(info.time)
			pet.protect_pct = float(info.protect_pct)
			if not tc._boss(enemy): enemy.pet_taunt = {"pet": int(pet.id), "time": float(info.taunt)}
		"death_pact":
			rt.buffs.death_pact = {"time": float(info.time), "transfer_pct": tc._value(info, "transfer_pct", rt, talent)}
		"bone_ascension":
			var pet: Dictionary = tc.permanent_pet(id)
			if not pet.is_empty():
				transform(tc, pet, float(info.get("time",cfg.blood.form_time)))
				var ratio := float(pet.hp) / float(pet.hp_max)
				pet.hp_max = maxf(float(pet.hp_max), float(info.hp))
				pet.dmg = maxf(float(pet.dmg), dmg)
				pet.blood_base.burst = pet.get("death_burst", {})
				pet.death_burst = info.get("death_burst", {})
				_reattach(tc, pet, "blood_colossus", ratio)
		"blood_tether":
			var end: Vector2 = tc._move(player.pos, (target - Vector2(player.pos)).limit_length(float(info.reach_m) * meter), 2)
			for e: Dictionary in tc._living():
				if Geometry2D.get_closest_point_to_segment(e.pos, player.pos, end).distance_to(e.pos) > float(e.radius) + float(info.width_m) * meter * 0.5 or tc._blocked(player.pos, e.pos, 1): continue
				tc._hit(id, e, dmg, info, rt, talent)
				e.talent_weak = {"pct": 20.0, "time": float(info.time)}
				links.append({"id":tc._take_id(),"owner":id,"target_id":tc._eid(e),"talent":talent,"kind":"fessel","left":float(info.time),"total":float(info.time),"dmg":0.0,"reach":(float(info.reach_m)+float(cfg.curse.beam.break_slack_m))*meter})
		"curse_harvest":
			var bonus := consume_poison(tc, id, player.pos, float(info.radius_m) * meter, int(cfg.curse.harvest_pool_max)) * float(cfg.curse.harvest_bonus_per_pool)
			for e: Dictionary in tc._living():
				if Vector2(e.pos).distance_to(player.pos) > float(info.radius_m) * meter + float(e.radius) or tc._blocked(player.pos, e.pos, 1): continue
				var own: Dictionary = e.get("necro_curses", {}).get(str(id), {})
				var prepared := not own.is_empty() and (float(own.get("decay", 0)) > 0 or float(own.get("mark", 0)) > 0)
				var mult := 1.0 + minf(float(cfg.curse.harvest_bonus_cap), bonus + (float(cfg.curse.harvest_bonus_per_mark) if prepared else 0.0))
				if prepared: own.decay = 0.0; own.mark = 0.0
				if int(e.get("talent_mark", {}).get("owner", -1)) == id: e.erase("talent_mark")
				tc._hit(id, e, dmg * mult, {}, rt, talent)
			tc._event("necro_bones", player.pos, float(info.radius_m) * meter, {"life": 0.8, "talent": talent, "fx": "poison"})
		_: return false
	return true

func _aim_target(tc: RefCounted, origin: Vector2, target: Vector2, reach: float) -> Dictionary:
	var best := {}
	var gap := INF
	for e: Dictionary in tc._living():
		if Vector2(e.pos).distance_to(origin) > reach or tc._blocked(origin,e.pos,1): continue
		var distance := Vector2(e.pos).distance_to(target)
		if distance < gap: best = e; gap = distance
	return best

func _target(tc: RefCounted, id: int) -> Dictionary:
	for e: Dictionary in tc._living():
		if tc._eid(e) == id: return e
	return {}

func _raise_runner(tc: RefCounted, enemy: Dictionary) -> void:
	for zone: Dictionary in tc.zones:
		if str(zone.talent) not in ["curse_7","curse_14"] or float(zone.time)<=0 or Vector2(enemy.pos).distance_to(zone.pos)>float(zone.r) or tc._blocked(zone.pos,enemy.pos,1): continue
		var owner := int(zone.owner)
		var rt: Dictionary = tc.runtime(owner)
		var hero: Dictionary = tc.game.players.get(owner,{})
		if hero.is_empty() or float(hero.hp)<=0 or int(rt.get("ranks",{}).get(str(zone.talent),0))<=0: continue
		if not media(tc).any(func(z:Dictionary)->bool:return _live(z) and _mat(z)=="poison" and int(z.get("necro_zone",-1))==int(zone.id)): continue
		if str(zone.talent)=="curse_14":
			MonsterHost.manifest(tc,zone,owner,rt)
			MonsterHost.remember(tc,enemy,owner)
			var burst := {"id":tc._take_id(),"owner":owner,"talent":"curse_14","pos":enemy.pos,"base":float(hero.get("damage",1)),"death_burst":{"dmg":cfg.curse.runners.damage,"radius_m":cfg.curse.runners.radius_m},"plague_runner":true}
			tc._pet_death_burst(burst)
			return
		if tc.pets.filter(func(p:Dictionary)->bool:return int(p.owner)==owner and bool(p.get("plague_runner",false)) and float(p.hp)>0).size()>=int(cfg.curse.runners.max_per_owner): return
		var rule: Dictionary = cfg.curse.runners
		tc._spawn_pet(owner,rt,str(zone.talent),{"pet_kind":"plague_runner","every":1,"dmg":0,"hp":float(rule.hp),"death_burst":{"dmg":rule.damage,"radius_m":rule.radius_m}},enemy.pos,false,float(rule.time))
		tc.pets[-1].plague_runner = true
		tc.pets[-1].speed = float(rule.speed)
		tc.pets[-1].plague_fuse = -1.0
		tc._event("summon",enemy.pos,20,{"kind":"skeleton","owner":owner,"talent":str(zone.talent)})
		return

## Corpse runners pursue on the ordinary navigation path, then commit their fuse.
func runner(tc: RefCounted, pet: Dictionary, prey: Dictionary, delta: float) -> void:
	pet.moving = false
	if prey.is_empty(): return
	var rule: Dictionary = cfg.curse.runners
	var before := Vector2(pet.pos)
	if float(pet.plague_fuse)<0 and (Vector2(pet.pos).distance_to(prey.pos)>float(rule.contact_m)*float(tc.data.meter_px)+float(prey.radius) or tc._blocked(pet.pos,prey.pos,1)):
		Targets.follow(tc,pet,prey.pos,delta,tc.data.pet,float(tc.data.pet.speed)*float(pet.speed)*tc._world_scale(),float(tc.data.pet.radius))
	else:
		if float(pet.plague_fuse)<0: pet.plague_fuse = float(rule.fuse_s)
		pet.plague_fuse = maxf(0,float(pet.plague_fuse)-delta)
		if float(pet.plague_fuse)<=0:
			pet.hp = 0.0
			tc._pet_death_burst(pet)
			pet.dying = 0.0
	pet.moving = before.distance_squared_to(pet.pos)>0.01
	if absf(Vector2(prey.pos).x-Vector2(pet.pos).x)>1: pet.face = signf(Vector2(prey.pos).x-Vector2(pet.pos).x)

func _death_curse(tc: RefCounted, dead: Dictionary, owner: int) -> void:
	var hero: Dictionary = tc.game.players.get(owner,{})
	var rt: Dictionary = tc.runtime(owner)
	if hero.is_empty() or float(hero.hp)<=0 or int(rt.get("ranks",{}).get("curse_9",0))<=0: return
	if tc.game.bullets.filter(func(b:Dictionary)->bool:return int(b.owner)==owner and bool(b.get("curse_spirit",false))).size()>=int(cfg.curse.flight.max_per_owner): return
	var victims: Array = tc._living().filter(func(e:Dictionary)->bool:return Vector2(e.pos).distance_to(dead.pos)<=float(cfg.curse.flight.range_m)*float(tc.data.meter_px) and not tc._blocked(dead.pos,e.pos,1))
	var linked_ids: Array = links.filter(func(l:Dictionary)->bool:return str(l.kind)=="blood" and int(l.owner)==owner).map(func(l:Dictionary)->int:return int(l.target_id))
	victims.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		if linked_ids.has(tc._eid(a))!=linked_ids.has(tc._eid(b)): return not linked_ids.has(tc._eid(a))
		return Vector2(a.pos).distance_squared_to(dead.pos)<Vector2(b.pos).distance_squared_to(dead.pos))
	if victims.is_empty(): return
	var target: Dictionary = victims[0]
	tc.game._add_bullet(dead.pos,(Vector2(target.pos)-Vector2(dead.pos)).normalized()*float(cfg.curse.flight.speed),owner,float(hero.get("damage",1))*float(cfg.curse.flight.damage),{"talent":"curse_1","style":"curse_spirit","curse_spirit":true,"curse_target":tc._eid(target),"primary":false,"radius":7,"pierce":0,"life":float(cfg.curse.flight.time)})

## Death curses cannot recursively create runners or further death curses.
func flight_hit(tc: RefCounted, bullet: Dictionary, enemy: Dictionary) -> void:
	var previous := secondary
	var previous_hit: bool = tc._talent_hit
	secondary = true
	tc._talent_hit = true
	var owner := int(bullet.owner)
	var rt: Dictionary = tc.runtime(owner)
	tag(tc,owner,enemy,{"time":float(cfg.curse.flight.mark_time),"pct":float(cfg.curse.flight.mark_pct)},"curse_3")
	tc._hit(owner,enemy,float(bullet.damage),{},rt,"curse_9")
	tc._talent_hit = previous_hit
	secondary = previous

func _step_links(tc: RefCounted, delta: float) -> void:
	for l: Dictionary in links.duplicate():
		var hero: Dictionary = tc.game.players.get(int(l.owner),{})
		var victim := _target(tc,int(l.target_id))
		var rt: Dictionary = tc.runtime(int(l.owner))
		if hero.is_empty() or int(hero.hp) <= 0 or victim.is_empty() or int(rt.get("ranks",{}).get(str(l.talent),0)) <= 0 or Vector2(hero.pos).distance_to(victim.pos) > float(l.reach) or tc._blocked(hero.pos,victim.pos,1):
			links.erase(l)
			continue
		var active := minf(delta,float(l.left))
		l.left = float(l.left)-delta
		if str(l.kind) == "blood":
			l.tick = float(l.tick)-active
			while float(l.tick) <= 0.000001:
				l.tick = float(l.tick)+float(l.every)
				tc._hit(int(l.owner),victim,float(l.dmg),{},rt,str(l.talent))
				if float(victim.hp) <= 0: break
		if float(l.left) <= 0.000001 or float(victim.hp) <= 0: links.erase(l)

## Only current endpoint coordinates and stable ids go over the wire.
func link_snapshot(tc: RefCounted) -> Array:
	var out: Array = []
	for l: Dictionary in links:
		var hero: Dictionary = tc.game.players.get(int(l.owner),{})
		var victim := _target(tc,int(l.target_id))
		if hero.is_empty() or victim.is_empty(): continue
		out.append({"id":l.id,"owner":l.owner,"target_id":l.target_id,"kind":l.kind,"talent":l.talent,"x":hero.pos.x,"y":hero.pos.y,"tx":victim.pos.x,"ty":victim.pos.y,"left":l.left,"total":l.total})
	for owner: Variant in tc.runtimes:
		var rt: Dictionary = tc.runtime(int(owner))
		if not rt.buffs.has("death_pact"): continue
		var pet: Dictionary = tc.permanent_pet(int(owner))
		var hero: Dictionary = tc.game.players.get(owner,{})
		if pet.is_empty() or hero.is_empty() or int(hero.hp) <= 0: continue
		out.append({"id":-int(owner),"owner":owner,"pet_id":pet.id,"target_id":-1,"kind":"pact","talent":"minion_11","x":hero.pos.x,"y":hero.pos.y,"tx":pet.pos.x,"ty":pet.pos.y,"left":rt.buffs.death_pact.time,"total":5.0})
	return out

## Per-owner curses attach their rigs to the target, independent of movement.
func mark_snapshot(tc: RefCounted) -> Array:
	var out: Array = []
	for enemy: Dictionary in tc._living():
		for key: String in enemy.get("blood_marks",{}):
			out.append({"target_id":tc._eid(enemy),"owner":int(key),"x":enemy.pos.x,"y":enemy.pos.y,"left":enemy.blood_marks[key],"blood":true})
	for e: Dictionary in tc._living():
		for mark: Dictionary in e.get("necro_curses",{}).values():
			if float(mark.get("mark",0)) > 0: out.append({"target_id":tc._eid(e),"owner":mark.owner,"x":e.pos.x,"y":e.pos.y,"left":mark.mark})
	for pet: Dictionary in tc.pets:
		if float(pet.get("protect",0)) <= 0: continue
		var victim := _target(tc,int(pet.get("target",-1)))
		if not victim.is_empty(): out.append({"target_id":tc._eid(victim),"owner":pet.owner,"x":victim.pos.x,"y":victim.pos.y,"left":pet.protect,"command":true})
	return out

## Consumes own actual poison at most once; environment and allies are untouched.
func consume_poison(tc: RefCounted, id: int, at: Vector2, radius: float, cap: int) -> int:
	var count := 0
	for z: Dictionary in media(tc):
		if count >= cap: break
		if not _live(z) or _mat(z) != "poison" or int(z.get("necro_owner", -1)) != id or _at(z).distance_to(at) > radius + _radius(z) or tc._blocked(at, _at(z), 1): continue
		_end(tc, z)
		count += 1
	return count

## A large existing skeletal source, reattached to real body-part HP at same HP ratio.
func transform(tc: RefCounted, pet: Dictionary, time: float) -> void:
	if str(pet.kind) != "bone_warrior" or float(pet.hp) <= 0 or float(pet.get("blood",0)) < float(cfg.blood.min_activation): return
	_release_blood(int(pet.id))
	pet.blood_base = {"hp": float(pet.hp_max), "dmg": float(pet.dmg), "speed": float(pet.speed), "cleave": float(pet.cleave_m), "lost": Array(pet.get("parts_lost", [])).duplicate()}
	var ratio := clampf(float(pet.hp) / float(pet.hp_max), 0, 1)
	pet.kind = "blood_colossus"
	pet.hp_max = float(pet.hp_max) * float(cfg.blood.form_hp)
	pet.hp = float(pet.hp_max) * ratio
	pet.dmg = float(pet.dmg) * float(cfg.blood.form_damage)
	pet.speed = 0.7
	pet.cleave_m = float(cfg.blood.form_cleave_m)
	pet.blood = minf(float(pet.blood),float(cfg.blood.capacity))
	pet.blood_pending = 0.0
	pet.blood_drain_rate = float(cfg.blood.capacity)/maxf(0.1,time)
	pet.blood_form = float(pet.blood)/float(pet.blood_drain_rate)
	pet.morph = float(cfg.blood.form_rise)
	_reattach(tc, pet, "blood_colossus", ratio)
	tc._event("necro_bones", pet.pos, 42, {"life": float(cfg.blood.form_rise), "talent": "minion_14"})

func _reattach(tc: RefCounted, pet: Dictionary, rig: String, ratio: float) -> void:
	var lost: Array = Array(pet.get("parts_lost", [])).duplicate()
	pet.max_hp = float(pet.hp_max)
	tc.pet_parts.attach(pet, rig)
	for p: Dictionary in pet.parts.values(): p.hp = float(p.max) * ratio
	# A form never resurrects a lost limb or grants a second life.
	for key: String in lost:
		if pet.parts.has(key): pet.parts[key].hp = 0.0; pet.parts_lost.append(key)
	pet.hp = float(pet.hp_max) * ratio

## Damage transfer is paid by the actual living companion. Never eats overflow.
func pact(tc: RefCounted, id: int, damage: float) -> float:
	var rt: Dictionary = tc.runtime(id)
	var pet: Dictionary = tc.permanent_pet(id)
	if pet.is_empty() or not rt.buffs.has("death_pact"): return damage
	var hero: Dictionary = tc.game.players.get(id, {})
	if hero.is_empty() or Vector2(hero.pos).distance_to(pet.pos) > float(cfg.curse.pact_range_m) * float(tc.data.meter_px): return damage
	var moved := minf(float(pet.hp), damage * float(rt.buffs.death_pact.transfer_pct) / 100.0)
	var before := float(pet.hp)
	tc._hurt_pet(pet, moved, Vector2(hero.pos))
	return maxf(0.0, damage - minf(moved, maxf(0.0, before - float(pet.hp))))

## Time, decay, finite blood and form expiry. Only authoritative host calls this.
func step(tc: RefCounted, delta: float) -> void:
	_step_links(tc,delta)
	for id: int in absorptions.keys():
		var claim: Dictionary = absorptions[id]
		if not _blood_claim_valid(tc,claim): _release_blood(id)
	for c: Dictionary in corpses: c.time = float(c.time) - delta
	corpses = corpses.filter(func(c: Dictionary) -> bool: return float(c.time) > 0)
	for id: Variant in tc.runtimes:
		var rt: Dictionary = tc.runtime(int(id))
		var hero: Dictionary = tc.game.players.get(id, {})
		var cap := float(hero.get("max_hp", 1)) * float(cfg.curse.drain_cap_hp_pct) / 100.0
		rt.drain_credit = minf(cap, float(rt.get("drain_credit", cap)) + cap * delta)
		rt.drain_fx = maxf(0, float(rt.get("drain_fx", 0)) - delta)
	for e: Dictionary in tc._living():
		var blood_marks: Dictionary = e.get("blood_marks",{})
		for key: String in blood_marks.keys():
			blood_marks[key] = float(blood_marks[key])-delta
			if float(blood_marks[key]) <= 0: blood_marks.erase(key)
		var entries: Dictionary = e.get("necro_curses", {})
		for key: String in entries.keys():
			var c: Dictionary = entries[key]
			for effect: String in ["decay", "mark", "drain"]: c[effect] = maxf(0, float(c.get(effect, 0)) - delta)
			c.tick = float(c.tick) - delta
			if float(c.decay) > 0 and float(c.tick) <= 0 and tc.game.players.has(int(c.owner)) and int(tc.game.players[int(c.owner)].hp) > 0:
				c.tick = float(cfg.curse.decay_tick)
				# The generic poison immunity is deliberately preserved; this is magical decay.
				var old: String = tc._cur_talent
				tc._cur_talent = "curse_1"
				tc.game._damage_enemy(e, float(c.power) * float(cfg.curse.decay_tick), Vector2.ZERO, int(c.owner), true, false)
				tc._cur_talent = old
			if float(c.decay) + float(c.mark) + float(c.drain) <= 0: entries.erase(key)
	for pet: Dictionary in tc.pets:
		_step_whirl(tc,pet,delta)
		pet.protect = maxf(0, float(pet.get("protect", 0)) - delta)
		pet.morph = maxf(0, float(pet.get("morph", 0)) - delta)
		if float(pet.hp) <= 0 or pet.has("dying"): continue
		if str(pet.kind) == "blood_colossus" and not bool(pet.get("permanent", false)): pet.blood_form = maxf(0, float(pet.life))
		if pet.has("blood_base"):
			pet.blood = maxf(0,float(pet.blood)-float(pet.blood_drain_rate)*delta)
			pet.blood_form = float(pet.blood)/float(pet.blood_drain_rate)
			if float(pet.blood_form) <= 0:
				tc._pet_death_burst(pet)
				var ratio := float(pet.hp) / float(pet.hp_max)
				pet.hp_max = float(pet.blood_base.hp)
				pet.dmg = float(pet.blood_base.dmg)
				pet.speed = float(pet.blood_base.speed)
				pet.cleave_m = float(pet.blood_base.cleave)
				pet.kind = "bone_warrior"
				pet.blood = 0.0
				pet.death_burst = pet.blood_base.get("burst", {})
				for limb: String in pet.blood_base.get("lost", []):
					if not limb in pet.parts_lost: pet.parts_lost.append(limb)
				pet.erase("blood_base")
				pet.erase("whirl")
				pet.erase("blood_drain_rate")
				pet.erase("burst_paid")
				_reattach(tc, pet, "bone_warrior", ratio)
			continue
		if str(pet.kind) != "bone_warrior" or not bool(pet.get("permanent", false)): continue
		var hero: Dictionary = tc.game.players.get(int(pet.owner), {})
		if hero.is_empty() or int(hero.hp) <= 0: continue
		_absorb_blood(tc,pet,delta)
		# A full gauge is stored until the owner explicitly activates the ultimate.

func _blood_claim_valid(tc: RefCounted, claim: Dictionary) -> bool:
	var pet: Dictionary = claim.pet
	var hero: Dictionary = tc.game.players.get(int(pet.owner),{})
	if float(pet.hp)<=0 or pet.has("dying") or str(pet.kind)!="bone_warrior" or hero.is_empty() or float(hero.hp)<=0: return false
	if not tc.pets.any(func(p:Dictionary)->bool:return is_same(p,pet)): return false
	var source: Dictionary = claim.source
	if not _live(source) or _mat(source)!="blood" or not media(tc).any(func(z:Dictionary)->bool:return is_same(z,source)): return false
	return Vector2(pet.pos).distance_to(_at(source))<=_radius(source)+float(cfg.blood.pull_radius_m)*float(tc.data.meter_px) and not tc._blocked(pet.pos,_at(source),1)

## Local source references never enter snapshots. A claim keeps the real puddle
## alive until its finite contents arrive; cancellation leaves only the remainder.
func _absorb_blood(tc: RefCounted, pet: Dictionary, delta: float) -> void:
	var id := int(pet.id)
	if not absorptions.has(id) and float(pet.get("blood",0)) < float(cfg.blood.capacity):
		for z: Dictionary in media(tc):
			if not _live(z) or _mat(z)!="blood" or z.has("blood_claim") or Vector2(pet.pos).distance_to(_at(z))>_radius(z)+float(cfg.blood.absorb_radius_m)*float(tc.data.meter_px) or tc._blocked(pet.pos,_at(z),1): continue
			var left := float(z.get("blood_left",cfg.blood.pool_units))
			if left <= 0.000001: continue
			z.blood_left = left
			z.blood_claim = id
			absorptions[id] = {"pet":pet,"source":z,"delay":float(cfg.blood.form_before_pull_s),"total":left}
			pet.blood_from = _at(z)
			pet.blood_pool_r = _radius(z)
			break
	if not absorptions.has(id): return
	var c: Dictionary = absorptions[id]
	var room := float(cfg.blood.capacity)-float(pet.get("blood",0))
	var before := float(c.delay)
	c.delay = maxf(0,before-delta)
	var rt: Dictionary = tc.runtime(int(pet.owner))
	var passive: Dictionary = tc._passive(rt,"blood_provision")
	var speed: float = 1.0+(tc._value(passive,"speed_pct",rt)/100.0 if not passive.is_empty() else 0.0)
	var add := minf(minf(float(c.source.blood_left),room),float(cfg.blood.units_per_second)*speed*maxf(0,delta-before))
	c.source.blood_left = maxf(0,float(c.source.blood_left)-add)
	pet.blood = minf(float(cfg.blood.capacity),float(pet.get("blood",0))+add)
	pet.blood_wait = c.delay
	pet.blood_pending = minf(float(c.source.blood_left),float(cfg.blood.capacity)-float(pet.blood))
	pet.blood_draw = 1.0-float(c.source.blood_left)/float(c.total)
	if float(c.source.blood_left)<=0.000001 or float(pet.blood_pending)<=0.000001:
		pet.blood = snappedf(float(pet.blood),0.000001)
		if float(c.source.blood_left)<=0.000001:
			c.source.blood_left = 0.0
			_end(tc,c.source)
			if not passive.is_empty(): tc._heal_pet(pet,float(pet.hp_max)*tc._value(passive,"heal_pct",rt)/100.0)
		_release_blood(id)

func _release_blood(id: int) -> void:
	if not absorptions.has(id): return
	var c: Dictionary = absorptions[id]
	c.source.erase("blood_claim")
	c.pet.blood_pending = 0.0
	c.pet.blood_wait = 0.0
	c.pet.blood_draw = 0.0
	absorptions.erase(id)

## Between fights, walk to visible nearby blood. Combat targeting keeps priority.
func blood_goal(tc: RefCounted, pet: Dictionary) -> Vector2:
	if absorptions.has(int(pet.id)): return Vector2(pet.pos)
	if str(pet.kind) != "bone_warrior" or not bool(pet.get("permanent",false)) or float(pet.get("blood",0))+float(pet.get("blood_pending",0)) >= float(cfg.blood.capacity): return Vector2.INF
	var best := Vector2.INF
	var distance := float(cfg.blood.seek_radius_m)*float(tc.data.meter_px)
	for z: Dictionary in media(tc):
		if not _live(z) or _mat(z) != "blood" or z.has("blood_claim"): continue
		var gap := Vector2(pet.pos).distance_to(_at(z))
		if gap >= distance or tc._blocked(pet.pos,_at(z),float(tc.data.pet.radius)): continue
		distance = gap
		best = _at(z)
	return best

## A companion-centred sustained attack; ordinary pursuit keeps running.
func whirl(tc: RefCounted, pet: Dictionary, ability: Dictionary) -> void:
	pet.whirl = {"age":0.0,"time":float(ability.time),"windup":float(ability.windup),"every":float(ability.every),"tick":float(ability.windup),"r":float(ability.radius_m)*float(tc.data.meter_px),"dmg":float(ability.dmg)*float(pet.base)}

func _step_whirl(tc: RefCounted, pet: Dictionary, delta: float) -> void:
	if not pet.has("whirl"): return
	var w: Dictionary = pet.whirl
	if float(pet.hp) <= 0 or float(pet.get("blood_form",0)) <= 0 or pet.has("dying") or not tc.game.players.has(int(pet.owner)) or int(tc.game.players[int(pet.owner)].hp) <= 0:
		pet.erase("whirl")
		return
	var active := minf(delta,float(w.time)-float(w.age))
	w.age = float(w.age)+delta
	w.tick = float(w.tick)-active
	while float(w.tick) <= 0.000001:
		w.tick = float(w.tick)+float(w.every)
		var rt: Dictionary = tc.runtime(int(pet.owner))
		for e: Dictionary in tc._living():
			if Vector2(e.pos).distance_to(pet.pos) <= float(w.r)+float(e.radius) and not tc._blocked(pet.pos,e.pos,1): tc._pet_hit(pet,rt,e,float(w.dmg),{})
	if float(w.age) >= float(w.time): pet.erase("whirl")

## Transport only live lightweight markers. No actor references enter an RPC.
func snapshot() -> Array:
	return corpses.map(func(c: Dictionary) -> Dictionary: return {"id": c.id, "owner": c.owner, "x": c.pos.x, "y": c.pos.y, "time": c.time})
