extends RefCounted
## Host-owned alchemy: armed capsules, finite real media and ordered reactions.
var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/alchemist_rules.json"))
var fields: Array = []
var pulses: Array = []
const ORDER := ["water", "poison", "frost", "shatter", "fire"]

## Room/run boundaries discard pending reactions; native media retain their own lifetime.
func clear() -> void:
	fields.clear()
	pulses.clear()

## Dispatch only the alchemist's learned casts after the shared cost/cooldown checks.
func cast(tc: RefCounted, owner: int, player: Dictionary, rt: Dictionary, talent: String, info: Dictionary, target: Vector2, base: float) -> bool:
	if not str(info.type).begins_with("alchemy_"): return false
	var at: Vector2 = tc._spot(player, target, info)
	at = tc._move(player.pos, at - Vector2(player.pos), 10.0)
	if str(info.type) == "alchemy_trap":
		var own: Array = tc.traps.filter(func(t: Dictionary) -> bool: return int(t.owner) == owner)
		while own.size() >= tc.trap_limit(rt): tc.traps.erase(own.pop_front())
		tc.traps.append({"id":tc._take_id(), "owner":owner, "talent":talent, "pos":at,
			"recipe":str(info.recipe), "info":info.duplicate(true), "base":base,
			"dmg":tc._value(info,"dmg",rt,talent)*base*(1+tc._sum(rt,"trap_bonus","pct")/100.0),
			"r":float(info.radius_m)*float(tc.data.meter_px), "root":0.0,
			"arm":float(info.arm_s), "life":float(tc.data.trap_life)})
	elif str(info.type) == "alchemy_detonate":
		detonate(tc, owner, at, float(info.radius_m)*float(tc.data.meter_px))
		tc._event("alchemy_trigger", at, float(info.radius_m)*float(tc.data.meter_px), {"recipe":"detonate", "owner":owner, "talent":talent, "life":0.55})
	else:
		var r := float(info.radius_m)*float(tc.data.meter_px)*float(info.get("field_radius",1))
		fields.append({"owner":owner, "talent":talent, "at":at, "r":r, "age":0.0, "phase":0, "base":base, "power":float(info.get("field_power",1))})
		tc._event("alchemy_field", at, r, {"owner":owner, "talent":talent, "life":float(info.time), "recipe":"detonate", "ult":true, "stage":int(rt.soul_tier)})
	return true

## Ready poison bait attracts visible normal enemies, never bosses or through walls.
func target(tc: RefCounted, enemy: Dictionary) -> Dictionary:
	if tc._boss(enemy): return {}
	var best: Dictionary = {}
	var gap := INF
	for trap: Dictionary in tc.traps:
		if str(trap.get("recipe","")) != "poison" or float(trap.arm) > 0: continue
		var owner: Dictionary = tc.game.players.get(int(trap.owner), {})
		if owner.is_empty() or float(owner.hp) <= 0: continue
		var d: float = Vector2(enemy.pos).distance_to(trap.pos)
		if d < gap and d <= float(trap.info.get("lure_m",0))*float(tc.data.meter_px) and not tc._blocked(enemy.pos, trap.pos, 1):
			gap = d
			best = {"id":-200000-int(trap.id), "pos":Vector2(trap.pos)}
	return best

## A swept friendly arrow may open only its owner's ready, visible capsules.
func arrow(tc: RefCounted, owner: int, from: Vector2, to: Vector2) -> void:
	var found: Array = []
	for trap: Dictionary in tc.traps:
		if not trap.has("recipe") or int(trap.owner) != owner or float(trap.arm) > 0: continue
		var hit := false
		for height: float in [0.0,0.5,1.0]:
			var anchor: Vector2 = trap.pos-Vector2(0,height*float(cfg.arrow_height_m)*float(tc.data.meter_px))
			if Geometry2D.get_closest_point_to_segment(anchor,from,to).distance_to(anchor) <= float(cfg.arrow_trigger_m)*float(tc.data.meter_px): hit = true
		if hit and not tc._blocked(from, trap.pos, 1): found.append(trap)
	found.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return from.distance_squared_to(a.pos) < from.distance_squared_to(b.pos))
	for trap: Dictionary in found: _trigger(tc, trap)

## Manual ignition is owner-scoped and ordered, never a recursive graph traversal.
func detonate(tc: RefCounted, owner: int, at: Vector2, radius: float) -> void:
	for recipe: String in ORDER:
		for trap: Dictionary in tc.traps.duplicate():
			if int(trap.owner) == owner and str(trap.get("recipe","")) == recipe and float(trap.arm) <= 0 and Vector2(trap.pos).distance_to(at) <= radius and not tc._blocked(at,trap.pos,1): _trigger(tc,trap)

## One host tick, including a staggered ultimate and media-bound poison pulses.
func step(tc: RefCounted, dt: float) -> void:
	for enemy: Dictionary in tc.game.enemies:
		if enemy.has("alchemy_thaw_s"): enemy.alchemy_thaw_s = maxf(0,float(enemy.alchemy_thaw_s)-dt)
	for trap: Dictionary in tc.traps.duplicate():
		if not trap.has("recipe"): continue
		trap.life = float(trap.life)-dt
		trap.arm = maxf(0,float(trap.arm)-dt)
		if float(trap.life) <= 0: tc.traps.erase(trap); continue
		if float(trap.arm) > 0: continue
		for enemy: Dictionary in tc._living():
			if Vector2(enemy.pos).distance_to(trap.pos) <= float(trap.info.trigger_m)*float(tc.data.meter_px)+float(enemy.radius) and not tc._blocked(trap.pos,enemy.pos,1):
				_trigger(tc,trap)
				break
	for pulse: Dictionary in pulses.duplicate():
		if not tc.necromancer._live(pulse.medium) or tc.necromancer._mat(pulse.medium) != str(pulse.mat): pulses.erase(pulse); continue
		pulse.left = float(pulse.left)-dt
		pulse.tick = float(pulse.tick)-dt
		if float(pulse.left) <= 0: pulses.erase(pulse); continue
		if float(pulse.tick) > 0: continue
		pulse.tick = float(pulse.tick)+float(cfg.pulse_s)
		for enemy: Dictionary in tc._living():
			if tc._blocked(pulse.at,enemy.pos,1) or not _in_pool(tc,pulse.medium,enemy): continue
			if str(pulse.mat) == "water":
				if not bool(pulse.medium.get("frozen",false)): _wet(tc,enemy,int(pulse.owner),float(cfg.pulse_s)*1.5)
			elif str(pulse.mat) == "ice":
				_freeze(tc,enemy,int(pulse.owner),float(cfg.field.freeze_s))
				tc._status(enemy,"slow",float(cfg.boss_slow),float(cfg.pulse_s)*1.5,int(pulse.owner))
			else:
				var old: bool = tc._talent_hit
				tc._talent_hit = true
				tc._hit(int(pulse.owner),enemy,float(pulse.damage),{"status":"burn" if str(pulse.mat)=="fire" else "poison"},tc.runtime(int(pulse.owner)),str(pulse.talent))
				tc._talent_hit = old
	for field: Dictionary in fields.duplicate():
		var player: Dictionary = tc.game.players.get(int(field.owner),{})
		if player.is_empty() or float(player.hp) <= 0: fields.erase(field); continue
		field.age = float(field.age)+dt
		var times := [float(cfg.field.water_at_s),float(cfg.field.poison_at_s),float(cfg.field.frost_at_s),float(cfg.field.fire_at_s)]
		while int(field.phase) < times.size() and float(field.age) >= float(times[int(field.phase)]):
			_field_phase(tc, field, int(field.phase))
			field.phase = int(field.phase)+1
		if int(field.phase) == times.size(): fields.erase(field)

func _trigger(tc: RefCounted, trap: Dictionary) -> void:
	if not tc.traps.has(trap): return
	tc.traps.erase(trap) # Consume before damage, death callbacks or reactions.
	var rt: Dictionary = tc.runtime(int(trap.owner))
	if rt.is_empty(): return
	var info: Dictionary = trap.info
	var damage: float = tc._value(info,"dmg",rt,str(trap.talent))*float(trap.base)*(1+tc._sum(rt,"trap_bonus","pct")/100.0)
	var recipe := str(trap.recipe)
	if recipe in ["water","poison"]:
		_pool(tc,int(trap.owner),recipe,trap.pos,float(trap.r),float(info.pool_time),float(trap.base),str(trap.talent))
	if recipe == "fire": tc._react("fire",trap.pos,float(trap.r),int(trap.owner))
	if recipe == "frost": tc._react("frost",trap.pos,float(trap.r),int(trap.owner))
	if recipe in ["fire","frost"]:
		_pool(tc,int(trap.owner),"ice" if recipe == "frost" else "fire",trap.pos,float(trap.r),float(info.pool_time),float(trap.base),str(trap.talent))
	var old: bool = tc._talent_hit
	tc._talent_hit = true
	for enemy: Dictionary in tc._living():
		if Vector2(enemy.pos).distance_to(trap.pos) > float(trap.r)+float(enemy.radius) or tc._blocked(trap.pos,enemy.pos,1): continue
		var extra := damage
		if recipe == "water": _wet(tc,enemy,int(trap.owner),float(info.wet_time))
		elif recipe == "frost": _freeze(tc,enemy,int(trap.owner),tc._value(info,"freeze_wet",rt,str(trap.talent)))
		elif recipe == "shatter" and not tc._boss(enemy) and _has(enemy,"freeze"):
			extra += tc._value(info,"shatter_bonus",rt,str(trap.talent))*float(trap.base)*(1+tc._sum(rt,"trap_bonus","pct")/100.0)
			_clear_freeze(enemy)
			tc._event("alchemy_burst",enemy.pos,float(trap.r)*0.3,{"recipe":"shatter","owner":int(trap.owner),"life":0.55})
		tc._hit(int(trap.owner),enemy,extra,info,rt,str(trap.talent))
	tc._talent_hit = old
	tc._event("alchemy_burst",trap.pos,float(trap.r),{"recipe":recipe,"owner":int(trap.owner),"talent":str(trap.talent),"life":float(cfg.art.open_s)})

func _pool(tc: RefCounted, owner: int, mat: String, at: Vector2, radius: float, life: float, base: float, talent: String) -> void:
	var own: Array = tc.necromancer.media(tc).filter(func(z: Dictionary) -> bool: return tc.necromancer._live(z) and int(z.get("alchemy_owner",-1)) == owner)
	while own.size() >= int(cfg.pool_limit): tc.necromancer._end(tc,own.pop_front())
	tc._pool_at(owner,mat,at,radius,life,0,"")
	var medium: Dictionary = {}
	for z: Dictionary in tc.necromancer.media(tc):
		if not z.has("alchemy_owner") and tc.necromancer._live(z) and tc.necromancer._mat(z) == mat and tc.necromancer._at(z).distance_to(at)<0.1 and int(z.get("fed_by",-1)) == owner: medium = z
	if medium.is_empty(): return
	medium.alchemy_owner = owner
	if mat == "water": tc._react("water",at,radius,owner)
	var damage := 0.0
	if mat == "poison":
		var rt: Dictionary = tc.runtime(owner)
		var rank := clampi(int(rt.ranks.get("trapper_1",1)),1,3)
		damage = base*float(cfg.poison_tick[rank-1])*(1+tc._sum(rt,"trap_bonus","pct")/100.0)
	elif mat == "fire": damage = base*float(cfg.fire_tick)
	pulses.append({"owner":owner,"talent":talent,"medium":medium,"mat":mat,"at":at,"r":radius,"left":life,"tick":float(cfg.pulse_s),"damage":damage})

func _in_pool(tc: RefCounted, medium: Dictionary, enemy: Dictionary) -> bool:
	if tc.game.has_method("talent_stands_in"): return tc.game.talent_stands_in(medium,enemy)
	return tc.game.boss_moves._in_pool(medium,enemy.pos,float(enemy.radius))

func _hits(tc: RefCounted, owner: int, talent: String, at: Vector2, radius: float, damage: float, info: Dictionary) -> void:
	var old: bool = tc._talent_hit
	tc._talent_hit = true
	for enemy: Dictionary in tc._living():
		if Vector2(enemy.pos).distance_to(at) <= radius+float(enemy.radius) and not tc._blocked(at,enemy.pos,1): tc._hit(owner,enemy,damage,info,tc.runtime(owner),talent)
	tc._talent_hit = old

func _field_phase(tc: RefCounted, field: Dictionary, phase: int) -> void:
	var owner := int(field.owner)
	var at: Vector2 = field.at
	var radius := float(field.r)
	var mat := "water" if phase == 0 else "poison" if phase == 1 else "frost" if phase == 2 else "fire"
	if phase < 2:
		var count := int(cfg.field.capsules)
		for n in range(phase,count,2):
			var spot := at+Vector2.from_angle(TAU*n/count)*radius*float(cfg.field.spread)
			spot = tc._move(at,spot-at,10)
			_pool(tc,owner,mat,spot,float(cfg.field.capsule_radius_m)*float(tc.data.meter_px),float(cfg.field.pool_s),float(field.base),str(field.talent))
			if phase == 0:
				for enemy: Dictionary in tc._living():
					if Vector2(enemy.pos).distance_to(spot) <= float(cfg.field.capsule_radius_m)*float(tc.data.meter_px)+float(enemy.radius) and not tc._blocked(spot,enemy.pos,1): _wet(tc,enemy,owner,float(cfg.field.pool_s))
	else:
		tc._react(mat,at,radius,owner)
		if phase == 2:
			for enemy: Dictionary in tc._living():
				if Vector2(enemy.pos).distance_to(at) <= radius+float(enemy.radius) and not tc._blocked(at,enemy.pos,1): _freeze(tc,enemy,owner,float(cfg.field.freeze_s))
		else: _hits(tc,owner,str(field.talent),at,radius,float(field.base)*float(cfg.field.fire_damage)*float(field.power),{"status":"burn","status_time":3})
	tc._event("alchemy_burst",at,radius,{"recipe":mat,"owner":owner,"talent":str(field.talent),"life":0.65,"ult":true})

func _has(enemy: Dictionary, status: String) -> bool:
	if status == "wet" and float(enemy.get("wet_t",0)) > 0: return true
	if status == "freeze" and float(enemy.get("frozen",0)) > 0: return true
	var value: Dictionary = enemy.get("statuses",{}).get(status,{})
	return float(value.get("time",0)) > 0

func _wet(tc: RefCounted, enemy: Dictionary, owner: int, life: float) -> void:
	tc._status(enemy,"wet",1,life,owner)
	if enemy.has("p"):
		enemy.wet_t = maxf(float(enemy.get("wet_t",0)),life)
		enemy.burn_t = 0.0
		enemy.fire_t = 0.0
	(enemy.get("statuses",{}) as Dictionary).erase("burn")

func _freeze(tc: RefCounted, enemy: Dictionary, owner: int, life: float) -> void:
	if tc._boss(enemy): tc._status(enemy,"slow",float(cfg.boss_slow),float(cfg.boss_slow_s),owner)
	elif float(enemy.get("alchemy_thaw_s",0))<=0 and _has(enemy,"wet"): tc._status(enemy,"freeze",1,life,owner)

func _clear_freeze(enemy: Dictionary) -> void:
	enemy.alchemy_thaw_s = float(cfg.shatter_thaw_s)
	(enemy.get("statuses",{}) as Dictionary).erase("freeze")
	if enemy.has("frozen"):
		var frozen := float(enemy.frozen)
		if float(enemy.get("stun",0)) <= frozen+0.001: enemy.stun = float(enemy.get("rooted",0))
		enemy.frozen = 0.0
		# Do not erase an independent stun/root; only remove the actual frost marker.
