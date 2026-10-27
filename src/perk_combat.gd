extends RefCounted
## Host-owned perk effects. Secondary damage never recursively triggers hit procs.
## The game injects its current encounter, collision helpers and damage boundary.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
var _game: Node
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _events: Array[Dictionary] = []
var _secondary_left: int = 24

## Bind once after balance loading; no network state or global singleton is used.
func bind(game: Node) -> void:
	_game = game

## A fresh run discards transient visuals and resets the host's effect RNG.
func reset() -> void:
	_events.clear()
	_rng.seed = int(_game.run_seed) + 104729
	_secondary_left = int(_mechanics().get("max_secondary_per_tick",24))

func _mechanics() -> Dictionary:
	return _game.balance.get("perk_rules",{}).get("mechanics",{})

func _m(key: String, fallback: float) -> float:
	return float(_mechanics().get(key,fallback))

func _b(player: Dictionary, key: String) -> float:
	return float(player.get("build",{}).get(key,0.0))

func _runtime(player: Dictionary) -> Dictionary:
	if not player.has("perk_runtime"):
		player.perk_runtime = {"kills":0,"hits":0,"volleys":0,"shield":0,"soul_shield":0,"stone_hits":0,"mark_target":-1,"mark_hits":0,"second_wind_floor":-1}
	return player.perk_runtime

## New encounters replenish room shields; revisits never regenerate resources.
func enter_room(revisiting: bool) -> void:
	_events.clear()
	if revisiting: return
	for player: Dictionary in _game.players.values():
		var runtime: Dictionary = _runtime(player)
		runtime.shield = mini(int(_m("shield_max_charges",3)),int(_b(player,"shield")))
		runtime.mark_target = -1
		runtime.mark_hits = 0

## A newly acquired room shield is immediately usable, without resetting counters.
func granted(id: int, definition: Dictionary) -> void:
	if not _game.players.has(id): return
	var player: Dictionary = _game.players[id]
	if str(definition.get("id","")) == "shield":
		var runtime: Dictionary = _runtime(player)
		runtime.shield = mini(int(_m("shield_max_charges",3)),int(runtime.shield) + int(definition.get("amount",1)))

## Cooldown modifiers are conditional on the actual current movement/health.
func shot_interval(player: Dictionary) -> float:
	var interval: float = float(player.shot_interval)
	if _b(player,"heavy") > 0: interval *= _m("heavy_interval_scale",1.3)
	if bool(player.get("moving",false)): interval *= maxf(0.1,1.0-_b(player,"momentum"))
	if _low_health(player): interval *= maxf(0.1,1.0-_b(player,"adrenaline"))
	return maxf(float(_game.balance.get("perk_rules",{}).get("min_shot_interval",0.06)),interval)

func _low_health(player: Dictionary) -> bool:
	return float(player.hp)/maxf(1.0,float(player.max_hp)) <= _m("low_hp_threshold",0.35)

## Creates actual projectiles for each owned pattern. All patterns share hard caps.
func shoot(id: int, aim: Vector2) -> void:
	if not _game.players.has(id): return
	var before_count: int = _game.bullets.size()
	var player: Dictionary = _game.players[id]
	var runtime: Dictionary = _runtime(player)
	runtime.volleys = int(runtime.volleys)+1
	var direction: Vector2 = aim.normalized()
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	var damage: float = float(player.damage)
	if _b(player,"heavy") > 0: damage *= 1.0+_b(player,"heavy")
	if not bool(player.get("moving",false)): damage *= 1.0+_b(player,"focus")
	if _low_health(player): damage *= 1.0+_b(player,"berserk")
	var critical: bool = _rng.randf() < _b(player,"crit")
	if critical: damage *= _m("crit_multiplier",1.75)
	damage = minf(damage,float(player.damage)*_m("damage_multiplier_cap",8))
	var speed: float = float(_game.balance.bullet.speed)
	if _b(player,"heavy") > 0: speed *= _m("heavy_speed_scale",0.8)
	var patterns: Array[Dictionary] = [{"aim":direction,"scale":1.0,"offset":Vector2.ZERO}]
	if _b(player,"twin") > 0:
		var offset: Vector2 = direction.orthogonal()*_m("twin_offset",7)
		patterns = [{"aim":direction,"scale":_b(player,"twin"),"offset":offset},{"aim":direction,"scale":_b(player,"twin"),"offset":-offset}]
	if _b(player,"scatter") > 0:
		for sign_value: float in [-1.0,1.0]: patterns.append({"aim":direction.rotated(_m("scatter_angle",0.25)*sign_value),"scale":_b(player,"scatter"),"offset":Vector2.ZERO,"short":true})
	if _b(player,"backshot") > 0: patterns.append({"aim":-direction,"scale":_b(player,"backshot"),"offset":Vector2.ZERO})
	if _b(player,"sidewinder") > 0:
		for sign_value: float in [-1.0,1.0]: patterns.append({"aim":direction.orthogonal()*sign_value,"scale":_b(player,"sidewinder"),"offset":Vector2.ZERO})
	var limit: int = int(_m("max_pellets_per_volley",9))
	for index: int in range(mini(limit,patterns.size())):
		var pattern: Dictionary = patterns[index]
		_spawn_projectile(player,id,pattern.aim,pattern.offset,damage*float(pattern.scale),speed,critical,true,bool(pattern.get("short",false)))
	if _game.bullets.size() == before_count:
		runtime.volleys = int(runtime.volleys)-1
		return
	if _b(player,"echo") > 0 and int(runtime.volleys)%maxi(1,int(_m("echo_every",4))) == 0:
		# The echo is a separate weaker projectile; it cannot spawn another echo.
		for index: int in range(mini(limit,patterns.size())):
			var pattern: Dictionary = patterns[index]
			_spawn_projectile(player,id,pattern.aim,pattern.offset,damage*float(pattern.scale)*_b(player,"echo"),speed*_m("echo_speed_scale",0.85),critical,false,bool(pattern.get("short",false)))
	player.shots = int(player.get("shots",0))+1

func _spawn_projectile(player: Dictionary, id: int, aim: Vector2, offset: Vector2, damage: float, speed: float, critical: bool, primary: bool, short_range: bool = false) -> void:
	var muzzle: Vector2 = player.pos + offset + aim*(float(_game.balance.player.radius)+1.5)
	if Dungeon.segment_blocked(player.pos,muzzle,float(_game.balance.bullet.radius),_game.current_layout): return
	var metadata: Dictionary = {"pierce":int(_b(player,"piercer")),"bounces":int(_b(player,"ricochet")),"hit_ids":[],"origin":Vector2(player.pos),"distance":0.0,"primary":primary,"critical":critical,"age":0.0,"base_angle":aim.angle(),"element":element(player)}
	if short_range: metadata.life = float(_game.balance.bullet.lifetime)*_m("scatter_lifetime_scale",0.7)
	_game._add_bullet(muzzle,aim*clampf(speed,_m("projectile_speed_min",120),_m("projectile_speed_max",900)),id,damage,metadata)

## The projectile's element is a small presentation hint, never a damage command.
func element(player: Dictionary) -> String:
	for key: String in ["storm","frost","venom","cinder"]:
		if _b(player,key) > 0: return key
	return ""

## Curved and homing bullets keep their speed and cannot target through walls.
func steer(bullet: Dictionary, delta: float) -> void:
	bullet.age = float(bullet.get("age",0.0))+delta
	var player: Dictionary = _game.players.get(int(bullet.owner),{})
	if player.is_empty(): return
	var velocity: Vector2 = bullet.velocity
	var angle: float = velocity.angle()
	if _b(player,"homing") > 0:
		bullet.seek_timer = float(bullet.get("seek_timer",0.0))-delta
		if float(bullet.seek_timer) <= 0:
			var targets: Array[Dictionary] = _nearby(bullet.pos,_m("homing_range",280),[])
			bullet.seek_point = Vector2(targets[0].pos) if not targets.is_empty() else Vector2(bullet.pos)+Vector2(bullet.velocity)
			bullet.seek_timer = _m("homing_retarget_interval",0.1)
		if bullet.has("seek_point"):
			var desired: float = (Vector2(bullet.seek_point)-Vector2(bullet.pos)).angle()
			angle += clampf(wrapf(desired-angle,-PI,PI),-_b(player,"homing")*delta,_b(player,"homing")*delta)
	if _b(player,"orbit") > 0:
		angle += sin(float(bullet.age)*_m("orbit_frequency",10.0))*_b(player,"orbit")*delta
	bullet.velocity = Vector2.from_angle(angle)*velocity.length()

## Swept actor collision prevents fast projectiles tunneling through small targets.
func segment_hits(from: Vector2, to: Vector2, center: Vector2, radius: float) -> bool:
	var segment: Vector2 = to-from
	var along: float = clampf((center-from).dot(segment)/maxf(segment.length_squared(),0.00001),0.0,1.0)
	return center.distance_squared_to(from+segment*along) <= radius*radius

## Resolve direct impact, elements and nonrecursive secondary effects on the host.
func hit(bullet: Dictionary, enemy: Dictionary) -> void:
	var owner: int = int(bullet.owner)
	var player: Dictionary = _game.players.get(owner,{})
	if player.is_empty() or float(enemy.hp) <= 0: return
	var runtime: Dictionary = _runtime(player)
	var damage: float = float(bullet.damage)
	if float(enemy.hp)/maxf(1.0,float(enemy.max_hp)) <= _m("execution_threshold",0.3): damage *= 1.0+_b(player,"execution")
	if float(enemy.hp) >= float(enemy.max_hp): damage *= 1.0+_b(player,"first_strike")
	if Vector2(player.pos).distance_to(enemy.pos) <= _m("close_range",110): damage *= 1.0+_b(player,"close_quarters")
	damage *= 1.0+_b(player,"longshot")*clampf(float(bullet.get("distance",0.0))/_m("longshot_range",400),0,1)
	var statuses: Dictionary = enemy.get("statuses",{})
	if statuses.has("slow") or statuses.has("freeze"): damage *= 1.0+_b(player,"shatter")
	var elements: int = int(statuses.has("burn"))+int(statuses.has("poison"))+int(statuses.has("slow") or statuses.has("freeze"))
	damage *= 1.0+elements*_b(player,"convergence")
	if _b(player,"mark") > 0:
		if int(runtime.mark_target) != int(enemy.id):
			runtime.mark_target = int(enemy.id)
			runtime.mark_hits = 0
		damage *= 1.0+minf(_m("mark_bonus_cap",1.0),int(runtime.mark_hits)*_b(player,"mark"))
		runtime.mark_hits = int(runtime.mark_hits)+1
	damage = minf(damage,float(bullet.damage)*_m("damage_multiplier_cap",8))
	# Follow-up bonuses inspect pre-existing statuses; this hit then applies its own.
	if bool(bullet.get("primary",true)): _apply_elements(player,enemy,owner)
	var previous_hp: float = float(enemy.hp)
	var resolved_damage: float = _game._damage_enemy(enemy,damage,Vector2(bullet.velocity).normalized(),owner,true)
	runtime.hits = int(runtime.hits)+1
	if _b(player,"leech") > 0 and int(runtime.hits)%maxi(1,int(_b(player,"leech"))) == 0: _heal(player,1)
	if bool(bullet.get("critical",false)): _event("crit",enemy.pos,enemy.pos)
	if not bool(bullet.get("primary",true)): return
	if _b(player,"blast") > 0: _area(enemy.pos,_m("blast_radius",70),damage*_b(player,"blast"),owner,[int(enemy.id)])
	if _b(player,"overkill") > 0 and float(enemy.hp) <= 0 and resolved_damage > previous_hp:
		_area(enemy.pos,_m("blast_radius",70),(resolved_damage-previous_hp)*_b(player,"overkill"),owner,[int(enemy.id)])
	if _b(player,"storm") > 0:
		var targets: Array[Dictionary] = _nearby(enemy.pos,_m("chain_range",170),[int(enemy.id)])
		for index: int in range(mini(int(_m("chain_targets",2)),targets.size())):
			if _secondary_left <= 0: break
			_secondary_left -= 1
			var target: Dictionary = targets[index]
			var chain_damage: float = damage*_b(player,"storm")
			if not target.get("statuses",{}).is_empty(): chain_damage *= 1.0+_b(player,"conductor")
			_game._damage_enemy(target,chain_damage,(Vector2(target.pos)-Vector2(enemy.pos)).normalized(),owner,false)
			_event("chain",enemy.pos,target.pos)
	if _b(player,"split") > 0 and _secondary_left > 0:
		for sign_value: float in [-1.0,1.0]:
			if _secondary_left <= 0: break
			_secondary_left -= 1
			var aim: Vector2 = Vector2(bullet.velocity).normalized().rotated(sign_value*_m("split_angle",0.55))
			_game._add_bullet(Vector2(enemy.pos)+aim*(float(enemy.radius)+float(_game.balance.bullet.radius)+1),aim*Vector2(bullet.velocity).length(),owner,damage*_b(player,"split"),{"primary":false,"hit_ids":[int(enemy.id)],"pierce":0,"bounces":0,"distance":0.0,"element":str(bullet.get("element",""))})

func _apply_elements(player: Dictionary, enemy: Dictionary, owner: int) -> void:
	if not enemy.has("statuses"): enemy.statuses = {}
	var duration: float = minf(_m("status_max_duration",8),_m("status_duration",3)*(1.0+_b(player,"catalyst")))
	if _b(player,"cinder") > 0: _status(enemy,"burn",minf(_m("status_dps_cap",20),_b(player,"cinder")),duration,owner)
	if _b(player,"venom") > 0: _status(enemy,"poison",minf(_m("status_dps_cap",20),_b(player,"venom")),duration,owner)
	if _b(player,"frost") > 0:
		_status(enemy,"slow",minf(_m("slow_cap",0.65),_b(player,"frost")),duration,owner)
		if _b(player,"permafrost") > 0:
			enemy.frost_hits = int(enemy.get("frost_hits",0))+1
			if int(enemy.frost_hits) >= int(_m("freeze_hits",4)) and float(enemy.get("freeze_lockout",0.0)) <= 0:
				var freeze_time: float = _b(player,"permafrost")*(_m("freeze_boss_scale",0.25) if bool(enemy.boss) else 1.0)
				_status(enemy,"freeze",1,freeze_time,owner)
				enemy.freeze_lockout = freeze_time+_m("freeze_lockout",2)
				enemy.frost_hits = 0

func _status(enemy: Dictionary, key: String, power: float, duration: float, owner: int) -> void:
	if not enemy.has("statuses"): enemy.statuses = {}
	var existing: Dictionary = enemy.statuses.get(key,{})
	# Strongest source owns the tick. Weaker attacks may refresh but never steal a kill.
	if not existing.is_empty() and float(existing.power) > power:
		existing.time = maxf(float(existing.time),duration)
		return
	enemy.statuses[key] = {"power":power,"time":duration,"owner":owner,"tick":float(existing.get("tick",0.0))}

## Status clocks run only with combat simulation, never while a solo menu pauses.
func step_events(delta: float) -> void:
	for index: int in range(_events.size()-1,-1,-1):
		_events[index].time = float(_events[index].time)-delta
		if float(_events[index].time) <= 0: _events.remove_at(index)

## Periodic damage preserves its source and expires instead of stacking forever.
func step_statuses(delta: float) -> void:
	_secondary_left = int(_m("max_secondary_per_tick",24))
	for enemy: Dictionary in _game.enemies:
		enemy.freeze_lockout = maxf(0.0,float(enemy.get("freeze_lockout",0.0))-delta)
		if float(enemy.hp) <= 0: continue
		var statuses: Dictionary = enemy.get("statuses",{})
		for key: String in statuses.keys():
			var status: Dictionary = statuses[key]
			var elapsed: float = minf(delta,float(status.time))
			status.time = maxf(0.0,float(status.time)-delta)
			if key in ["burn","poison"]:
				status.tick = float(status.tick)+elapsed
				var period: float = _m("status_tick",0.5)
				if float(status.tick) >= period or float(status.time) <= 0:
					_game._damage_enemy(enemy,float(status.power)*float(status.tick),Vector2.ZERO,int(status.owner),true,false)
					status.tick = 0.0
			if float(status.time) <= 0: statuses.erase(key)

## Freezing pauses attacks too; boss duration is shorter and has a re-freeze gap.
func frozen(enemy: Dictionary) -> bool:
	return enemy.get("statuses",{}).has("freeze")

## Slow modifies only this step's movement; authored base speed stays intact.
func speed_scale(enemy: Dictionary) -> float:
	return 1.0-float(enemy.get("statuses",{}).get("slow",{}).get("power",0.0))

## Credit one real death once; area/chain kills cannot recursively emit more areas.
func killed(enemy: Dictionary, owner: int, allow_effects: bool) -> void:
	var player: Dictionary = _game.players.get(owner,{})
	if player.is_empty() or int(player.hp) <= 0: return
	var runtime: Dictionary = _runtime(player)
	runtime.kills = int(runtime.kills)+1
	if _b(player,"vampire") > 0 and int(runtime.kills)%maxi(1,int(_b(player,"vampire"))) == 0: _heal(player,int(_m("heal_amount",1)))
	if _b(player,"soul_guard") > 0 and int(runtime.kills)%maxi(1,int(_b(player,"soul_guard"))) == 0:
		runtime.soul_shield = mini(int(_m("soul_guard_max_shields",2)),int(runtime.get("soul_shield",0))+1)
	if not allow_effects: return
	var statuses: Dictionary = enemy.get("statuses",{})
	if statuses.has("burn") and _b(player,"combustion") > 0:
		_area(enemy.pos,_m("blast_radius",70),float(player.damage)*_b(player,"combustion"),owner,[int(enemy.id)])
	if statuses.has("poison") and _b(player,"plague") > 0:
		for target: Dictionary in _nearby(enemy.pos,_m("spread_radius",120),[int(enemy.id)]):
			if _secondary_left <= 0: break
			_secondary_left -= 1
			_status(target,"poison",float(statuses.poison.power)*_b(player,"plague"),minf(_m("status_max_duration",8),_m("status_duration",3)*(1.0+_b(player,"catalyst"))),owner)
		_event("poison",enemy.pos,enemy.pos)

## Renewal triggers exactly once at combat completion, never on cleared-room entry.
func room_cleared() -> void:
	for player: Dictionary in _game.players.values():
		if int(player.hp) > 0 and _b(player,"renewal") > 0: _heal(player,int(_b(player,"renewal")))

## Apply shields, stationary armor and retaliation before subtracting hearts.
func incoming(id: int, damage: int, direction: Vector2) -> int:
	var player: Dictionary = _game.players[id]
	var runtime: Dictionary = _runtime(player)
	if int(player.get("reserve_shield",0)) > 0:
		player.reserve_shield = int(player.reserve_shield)-1
		_absorb(player)
		return 0
	if int(runtime.shield) > 0:
		runtime.shield = int(runtime.shield)-1
		_absorb(player)
		return 0
	if int(runtime.get("soul_shield",0)) > 0:
		runtime.soul_shield = int(runtime.soul_shield)-1
		_absorb(player)
		return 0
	if _b(player,"stone_skin") > 0 and not bool(player.get("moving",false)):
		runtime.stone_hits = int(runtime.stone_hits)+1
		if int(runtime.stone_hits)%maxi(1,int(_b(player,"stone_skin"))) == 0:
			_absorb(player)
			return 0
	return damage

## Retaliation requires actual lost hearts; an absorbed hit cannot farm damage.
func hurt(id: int) -> void:
	var player: Dictionary = _game.players[id]
	if _b(player,"thorns") > 0: _area(player.pos,_m("thorns_range",90),_b(player,"thorns"),id,[])

func _absorb(player: Dictionary) -> void:
	player.invulnerable = float(_game.balance.player.invulnerability)
	player.blocks = int(player.get("blocks",0))+1
	_event("shield",player.pos,player.pos)

## One rescue per floor; a second lethal blow remains lethal.
func rescue(player: Dictionary) -> bool:
	var runtime: Dictionary = _runtime(player)
	if _b(player,"second_wind") <= 0 or int(runtime.second_wind_floor) == int(_game.floor_index): return false
	runtime.second_wind_floor = int(_game.floor_index)
	player.hp = maxi(1,int(ceil(float(player.max_hp)*_b(player,"second_wind"))))
	_event("revive",player.pos,player.pos)
	return true

func _heal(player: Dictionary, amount: int) -> void:
	if int(player.hp) <= 0: return
	var previous: int = int(player.hp)
	player.hp = mini(int(player.max_hp),previous+amount)
	if int(player.hp) > previous: _event("heal",player.pos,player.pos)

func _nearby(point: Vector2, radius: float, excluded: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in _game.enemies:
		if float(enemy.hp) <= 0 or int(enemy.id) in excluded: continue
		if point.distance_to(enemy.pos) > radius: continue
		if Dungeon.segment_blocked(point,enemy.pos,0.0,_game.current_layout): continue
		result.append(enemy)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return point.distance_squared_to(a.pos) < point.distance_squared_to(b.pos))
	return result

func _area(point: Vector2, radius: float, damage: float, owner: int, excluded: Array) -> void:
	if damage <= 0: return
	for target: Dictionary in _nearby(point,radius,excluded):
		if _secondary_left <= 0: break
		_secondary_left -= 1
		_game._damage_enemy(target,damage,(Vector2(target.pos)-point).normalized(),owner,false)
	_event("blast",point,point)

func _event(kind: String, from: Vector2, to: Vector2) -> void:
	var maximum: int = int(_m("max_effect_events",32))
	if _events.size() >= maximum: _events.pop_front()
	_events.append({"kind":kind,"x":from.x,"y":from.y,"tx":to.x,"ty":to.y,"time":_m("event_duration",0.22)})

## Small primitive-only events travel with the authoritative snapshot.
func visual_events() -> Array[Dictionary]:
	return _events.duplicate()
