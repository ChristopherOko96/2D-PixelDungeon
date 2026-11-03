extends RefCounted
## Host-owned fifteen-second wyrms; spit travels before real liquid lands.
var flights: Array = []

## Keep the permanent beast, replace only an earlier temporary worm pair.
func summon(tc: RefCounted, owner: int, rt: Dictionary, info: Dictionary) -> void:
	for pet: Dictionary in tc.pets.duplicate():
		if int(pet.owner)==owner and str(pet.kind) in ["poison_worm","fire_worm"]: tc.pets.erase(pet)
	var cfg: Dictionary = tc.data.pet.forest_worms
	var hero: Dictionary = tc.game.players[owner]
	for n in range(2):
		var kind: String = ["poison_worm","fire_worm"][n]
		var point: Vector2 = tc._move(hero.pos,Vector2(-32 if n==0 else 32,28),float(tc.data.pet.radius))
		tc._spawn_pet(owner,rt,"beast_14",{"pet_kind":kind,"hp":float(cfg.hp)*(1+float(info.get("worm_hp_pct",0))/100),"dmg":0,"every":cfg.every},point,false,float(info.time))
		tc.pets[-1].total_life = float(info.time)
		tc.pets[-1].pool_mult = 1+float(info.get("worm_pool_pct",0))/100
		tc._event("summon",point,24,{"kind":kind,"owner":owner,"life":0.6})

## Locked landing point, swept against walls, rather than damage at launch.
func spit(tc: RefCounted, pet: Dictionary, enemy: Dictionary) -> void:
	var cfg: Dictionary = tc.data.pet.forest_worms
	var at: Vector2 = tc._move(pet.pos,Vector2(enemy.pos)-Vector2(pet.pos),4)
	flights.append({"owner":int(pet.owner),"pet":int(pet.id),"from":Vector2(pet.pos),"to":at,"kind":str(pet.kind),"left":float(cfg.flight_s),"base":float(pet.base)*float(pet.get("pool_mult",1))})
	tc._event("forest_spit",pet.pos,0,{"owner":pet.owner,"tx":at.x,"ty":at.y,"kind_name":str(pet.kind),"life":float(cfg.flight_s)})

## Landing pays once, with owner/death guards and bounded live pool count.
func step(tc: RefCounted, delta: float) -> void:
	var cfg: Dictionary = tc.data.pet.get("forest_worms",{})
	if cfg.is_empty(): return
	for f: Dictionary in flights.duplicate():
		f.left = float(f.left)-delta
		if float(f.left)>0: continue
		flights.erase(f)
		var hero: Dictionary = tc.game.players.get(int(f.owner),{})
		if hero.is_empty() or float(hero.hp)<=0: continue
		if not tc.pets.any(func(p:Dictionary)->bool:return int(p.id)==int(f.pet) and float(p.hp)>0 and float(p.life)>0): continue
		var style := "poison" if str(f.kind)=="poison_worm" else "fire"
		var live: Array = tc.necromancer.media(tc).filter(func(z:Dictionary)->bool:return tc.necromancer._live(z) and str(z.get("forest_worm",""))==str(f.kind) and int(z.get("fed_by",z.get("hostile",-1)))==int(f.owner))
		while live.size()>=int(cfg.max_pools): tc.necromancer._end(tc,live.pop_front())
		var point: Vector2 = tc._move(f.from,Vector2(f.to)-Vector2(f.from),4)
		tc._pool_at(int(f.owner),style,point,float(cfg.pool_radius_m)*float(tc.data.meter_px),float(cfg.pool_time),float(cfg.pool_dps)*float(f.base),"poison" if style=="poison" else "burn")
		var all: Array = tc.necromancer.media(tc)
		if not all.is_empty(): all[-1].forest_worm = str(f.kind)
		tc._event("nova",point,float(cfg.pool_radius_m)*float(tc.data.meter_px),{"fx":style,"life":0.45})
