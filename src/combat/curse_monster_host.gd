extends RefCounted
## Authoritative curse-giant manifestation, corpse reservations and delayed commands.
const Rig = preload("res://src/rig/curse_monster_rig.gd")
const Library = preload("res://src/rig/rig_library.gd")

## Ultimate calls one giant immediately; the spent pool never duplicates it.
static func manifest(tc: RefCounted, zone: Dictionary, owner: int, rt: Dictionary) -> void:
	if bool(zone.get("curse_manifested",false)): return
	if tc.pets.any(func(p:Dictionary)->bool:return int(p.owner)==owner and str(p.kind)=="curse_colossus" and float(p.hp)>0 and float(p.life)>0): return
	var rule: Dictionary = tc.necromancer.cfg.curse.ultimate_monster
	zone.curse_manifested = true
	Rig.prepare(Library.shared())
	tc._spawn_pet(owner,rt,"curse_14",{"pet_kind":"curse_colossus","hp":rule.hp,"dmg":rule.damage,"every":rule.every,"cleave_m":rule.cleave_m},zone.pos,false,float(rule.time))
	tc.pets[-1].morph = 1.0
	tc.pets[-1].speed = float(rule.speed)
	tc.pets[-1].total_life = float(rule.time)
	tc._event("summon",zone.pos,36,{"kind":"curse_colossus","owner":owner,"talent":"curse_14","life":1.0})

## Its three attacks (basic, wave, brood command) share one passive on damage.
static func dealt(tc: RefCounted, owner: int, enemy: Dictionary, resolved: float) -> void:
	if resolved<=0 or float(enemy.hp)<=0 or tc._pet_source<0: return
	for pet: Dictionary in tc.pets:
		if int(pet.id)!=int(tc._pet_source) or str(pet.kind)!="curse_colossus" or int(pet.owner)!=owner: continue
		var rule: Dictionary = tc.necromancer.cfg.curse.ultimate_monster.on_hit_curse
		tc.necromancer.tag(tc,owner,enemy,{"mark_time":rule.time,"mark_pct":rule.pct},"curse_14")
		return

## One normal corpse per owner/death identity, finite lifetime and population.
static func remember(tc: RefCounted, enemy: Dictionary, owner: int) -> void:
	if int(tc.runtime(owner).get("ranks",{}).get("curse_14",0))<=0: return
	var hero: Dictionary = tc.game.players.get(owner,{})
	if hero.is_empty() or float(hero.hp)<=0: return
	var paid: Array = enemy.get("curse_corpse_owners",[])
	if owner in paid: return
	paid.append(owner)
	enemy.curse_corpse_owners = paid
	var cfg: Dictionary = tc.necromancer.cfg.corpses
	var all: Array = tc.necromancer.corpses
	var mine := all.filter(func(c:Dictionary)->bool:return int(c.owner)==owner and bool(c.get("curse",false)))
	while mine.size()>=int(cfg.max_per_owner): all.erase(mine.pop_front())
	all.append({"id":tc._take_id(),"owner":owner,"pos":Vector2(enemy.pos),"time":float(cfg.time),"curse":true})

## Reserve genuine corpse identities before the casting animation begins.
static func command(tc: RefCounted, pet: Dictionary, ability: Dictionary) -> bool:
	if pet.has("curse_command"): return false
	var chosen: Array = []
	if str(ability.type)=="curse_brood":
		var active := _brood_count(tc,int(pet.owner))
		var cap := mini(int(ability.max),int(tc.necromancer.cfg.curse.ultimate_monster.brood.max_per_owner)-active)
		for c: Dictionary in tc.necromancer.corpses:
			if chosen.size()>=cap: break
			if not bool(c.get("curse",false)) or int(c.owner)!=int(pet.owner) or float(c.time)<=float(ability.windup) or c.has("reserved"): continue
			if Vector2(c.pos).distance_to(pet.pos)>float(ability.radius_m)*float(tc.data.meter_px) or tc._blocked(pet.pos,c.pos,1): continue
			c.reserved = int(pet.id)
			chosen.append(int(c.id))
		if chosen.is_empty(): return false
	pet.curse_command = {"ability":ability.duplicate(true),"left":float(ability.windup),"corpses":chosen}
	pet.cast = float(ability.windup)
	tc._event("necro_monster_cast",pet.pos,float(ability.radius_m)*float(tc.data.meter_px),{"talent":"curse_14","owner":pet.owner,"pet_id":pet.id,"brood":str(ability.type)=="curse_brood","life":float(ability.windup)})
	return true

static func _brood_count(tc: RefCounted, owner: int) -> int:
	return tc.pets.filter(func(p:Dictionary)->bool:return int(p.owner)==owner and str(p.kind)=="curse_spawn" and float(p.hp)>0 and float(p.life)>0).size()

## Dead owner/giant, missing corpse or a new wall cancels the delayed effect.
static func step(tc: RefCounted, pet: Dictionary, delta: float) -> void:
	if not pet.has("curse_command"): return
	var cmd: Dictionary = pet.curse_command
	var hero: Dictionary = tc.game.players.get(int(pet.owner),{})
	if float(pet.hp)<=0 or float(pet.life)<=delta or hero.is_empty() or float(hero.hp)<=0:
		for c: Dictionary in tc.necromancer.corpses:
			if int(c.get("reserved",-1))==int(pet.id): c.erase("reserved")
		pet.erase("curse_command")
		return
	cmd.left = float(cmd.left)-delta
	if float(cmd.left)>0: return
	pet.erase("curse_command")
	var ability: Dictionary = cmd.ability
	var owner := int(pet.owner)
	var rt: Dictionary = tc.runtime(owner)
	var radius := float(ability.radius_m)*float(tc.data.meter_px)
	if str(ability.type) in ["curse_wave","bone_wave"]:
		for e: Dictionary in tc._living():
			if Vector2(e.pos).distance_to(pet.pos)>radius+float(e.radius) or tc._blocked(pet.pos,e.pos,1): continue
			tc._pet_hit(pet,rt,e,float(ability.get("dmg",0))*float(pet.base),{})
			tc.necromancer.tag(tc,owner,e,ability,"curse_3")
			e.talent_weak = {"pct":float(ability.pct),"time":float(ability.time)}
		tc._event("necro_bone_wave",pet.pos,radius,{"owner":owner,"talent":"curse_14","life":0.8})
	else:
		var rule: Dictionary = tc.necromancer.cfg.curse.ultimate_monster.brood
		for c: Dictionary in tc.necromancer.corpses.duplicate():
			if int(c.id) not in cmd.corpses: continue
			c.erase("reserved")
			if float(c.time)<=0 or Vector2(c.pos).distance_to(pet.pos)>radius or tc._blocked(pet.pos,c.pos,1): continue
			if _brood_count(tc,owner)>=int(rule.max_per_owner): break
			tc.necromancer.corpses.erase(c)
			Rig.prepare(Library.shared())
			tc._spawn_pet(owner,rt,"curse_14",{"pet_kind":"curse_spawn","hp":rule.hp,"dmg":rule.damage,"every":rule.every},c.pos,false,float(rule.time))
			tc.pets[-1].morph = 1.0
			tc.pets[-1].total_life = float(rule.time)
			tc._event("summon",c.pos,20,{"kind":"curse_spawn","talent":"curse_14","owner":owner,"life":1.0})

## Fixed paid windup for Knochenball; cancellation never refunds or fires it.
static func charge(tc: RefCounted, id: int, info: Dictionary, aim: Vector2) -> void:
	tc.runtime(id).bone_charge = {"time":float(info.cast_time),"total":float(info.cast_time),"info":info.duplicate(true),"aim":aim}

## Advance host-owned windup independently of client frame rate.
static func step_charge(tc: RefCounted, id: int, rt: Dictionary, delta: float) -> void:
	if not rt.has("bone_charge"): return
	var hero: Dictionary = tc.game.players.get(id,{})
	if hero.is_empty() or float(hero.hp)<=0:
		rt.erase("bone_charge")
		return
	var c: Dictionary = rt.bone_charge
	c.time = float(c.time)-delta
	if float(c.time)>0: return
	rt.erase("bone_charge")
	tc._run(id,hero,rt,"curse_1",c.info,c.aim,Vector2(hero.pos)+Vector2(c.aim)*160,1)
	tc._event("necro_bone_release",hero.pos,0,{"owner":id,"talent":"curse_1","angle":Vector2(c.aim).angle(),"life":0.35})
