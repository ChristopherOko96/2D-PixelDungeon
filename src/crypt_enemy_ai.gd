extends RefCounted
## Three host-owned crypt roles with locked telegraphs and bounded summoning.
## Presentation observes the ordinary attack/hit counters and owns no decisions.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
var _game: Node

## Inject the authoritative encounter instead of using an autoload or singleton.
func bind(game: Node) -> void:
	_game = game

func _settings() -> Dictionary:
	return _game.balance.get("enemy_roster",{})

## Return an independent merged definition; unknown legacy kinds remain unhandled.
func definition(kind: String) -> Dictionary:
	var data: Dictionary = _settings().get("definitions",{}).get(kind,{})
	if data.is_empty(): return {}
	var result: Dictionary = _game.balance.get("enemy",{}).duplicate()
	result.merge(data,true)
	result.kind = kind
	return result

## Floor plan of the crypt (balance "enemy_roster.floor_plan", repeating every
## `cycle` floors): the boss floor's last room holds the Leerenrufer, mini-boss
## floors a mini-boss, every other floor's last room a strong group.
func final_room_role(floor_index: int) -> String:
	var plan: Dictionary = _settings().get("floor_plan",{})
	var cycle: int = maxi(1,int(plan.get("cycle",10)))
	var step: int = posmod(floor_index-1,cycle)+1
	if step == int(plan.get("boss_floor",10)): return "boss"
	if plan.get("minibosses",{}).has(str(step)): return str(plan.minibosses[str(step)])
	return "strong_group"


## Keep boss slots intact and introduce new roles gradually with seeded variation.
func choose_kind(room: int, index: int, _count: int, boss_room: bool, rng: RandomNumberGenerator) -> String:
	var floor_index: int = int(_game.get("floor_index")) if _game != null and _game.get("floor_index") != null else 1
	var encounter: Dictionary = _settings().get("encounter",{})
	if boss_room:
		var role := final_room_role(floor_index)
		if role == "strong_group":
			var group: Array = _settings().get("floor_plan",{}).get("strong_group",["necromancer","void_bomber","void_bomber","skeleton_guard","skeleton_archer","skeleton"])
			return str(group[index%group.size()])
		if index == 0: return role
		return "skeleton_archer" if index%2 == 1 else "skeleton_guard"
	if index == 0: return "skeleton_guard"
	if index == 1: return "skeleton_archer"
	var necro_from: int = int(encounter.get("necromancer_from_room",3))
	var necro_max: int = int(encounter.get("necromancer_max_per_room",2))
	if room >= necro_from and index%3 == 2 and index/3 < necro_max: return "necromancer"
	if floor_index >= int(encounter.get("bomber_from_floor",2)) and index%4 == 3: return "void_bomber"
	var pool: Array = ["skeleton","skeleton_guard","skeleton_archer"]
	if floor_index >= int(encounter.get("zombies_from_floor",2)): pool.append_array(["tiny_zombie","ice_zombie"])
	return str(pool[rng.randi_range(0,pool.size()-1)])


func _parts() -> RefCounted:
	return _game.get("body_parts") if _game != null else null

## Handle one living enemy after the caller has applied stun/freeze/knockback.
## Returning true prevents legacy contact damage or chase AI from running again.
func step(enemy: Dictionary, target_id: int, delta: float) -> bool:
	# Boss authority takes precedence over a reused/template kind label.
	if bool(enemy.get("boss",false)): return false
	var data: Dictionary = definition(str(enemy.get("kind","")))
	if data.is_empty(): return false
	if float(enemy.get("hp",0)) <= 0: return true
	# Negative ids are mirror-image decoys (HeroSkills); they draw but never take hits.
	var target: Dictionary = _game.players.get(target_id,_game.decoys.get(target_id,{})) if "decoys" in _game else _game.players.get(target_id,{})
	if target.is_empty() or int(target.get("hp",0)) <= 0: return true
	if float(enemy.get("hitstun",0.0)) > 0 or enemy.get("statuses",{}).has("freeze"): return true
	var attack: String = str(enemy.get("attack",""))
	if not attack.is_empty():
		_step_attack(enemy,delta)
		return true
	var to_target: Vector2 = Vector2(target.pos)-Vector2(enemy.pos)
	var distance: float = to_target.length()
	_face(enemy,to_target)
	enemy.shot_timer = maxf(0.0,float(enemy.get("shot_timer",0.0))-delta)
	var visible: bool = not Dungeon.segment_blocked(enemy.pos,target.pos,0.0,_game.current_layout)
	if float(enemy.shot_timer) <= 0 and distance <= float(data.attack_range) and visible:
		var kind: String = str(data.attack)
		if str(enemy.kind) == "necromancer" and _can_summon(enemy): kind = "summon"
		# Mini-bosses roar every few attacks, and always when their arm is gone.
		var parts := _parts()
		var roar_every: int = int(data.get("roar_every",0))
		if roar_every > 0 and (int(enemy.get("attacks",0))%roar_every == roar_every-1 or (parts != null and not parts.can(enemy,"attack"))): kind = "roar"
		var need: String = "cast" if kind in ["soul","summon"] else "" if kind in ["roar","fuse"] else "attack"
		if need.is_empty() or parts == null or parts.can(enemy,need):
			_begin_attack(enemy,target_id,target.pos,kind)
			return true
	_move(enemy,target.pos,data,visible,delta)
	return true

func _face(enemy: Dictionary, vector: Vector2) -> void:
	if vector.length_squared() <= 0.00001: return
	enemy.facing_dir = vector.normalized()
	if absf(vector.x) > 0.01: enemy.face = signf(vector.x)

func _attack(kind: String) -> Dictionary:
	return _settings().get("attacks",{}).get(kind,{})

func _begin_attack(enemy: Dictionary, target_id: int, target_point: Vector2, kind: String) -> void:
	enemy.attack_target = target_id
	enemy.attack_point = target_point
	enemy.attack_aim = (target_point-Vector2(enemy.pos)).normalized()
	if Vector2(enemy.attack_aim).is_zero_approx(): enemy.attack_aim = Vector2.RIGHT
	_face(enemy,enemy.attack_aim)
	if kind == "summon":
		var side: float = -1.0 if int(enemy.get("summons_cast",0))%2 == 0 else 1.0
		var free_site: bool = false
		var summon_radius: float = float(definition("skeleton_guard").get("radius",13))
		for direction: float in [side,-side]:
			var candidate: Vector2 = Vector2(enemy.pos)+Vector2(enemy.attack_aim).orthogonal()*float(_attack(kind).get("summon_offset",72))*direction
			if not Dungeon.segment_blocked(candidate,candidate,summon_radius,_game.current_layout):
				enemy.summon_point = candidate
				free_site = true
				break
		if not free_site: kind = "soul"
	if kind != "summon": enemy.erase("summon_point")
	enemy.attack_kind = kind
	_set_phase(enemy,"windup")

func _set_phase(enemy: Dictionary, phase: String) -> void:
	var data: Dictionary = _attack(str(enemy.attack_kind))
	enemy.attack = phase
	enemy.attack_length = float(data.get(phase,0.1))
	enemy.attack_time = enemy.attack_length

func _step_attack(enemy: Dictionary, delta: float) -> void:
	enemy.attack_time = maxf(0.0,float(enemy.get("attack_time",0.0))-delta)
	if float(enemy.attack_time) > 0: return
	match str(enemy.attack):
		"windup":
			if _release(enemy): enemy.attacks = int(enemy.get("attacks",0))+1
			_set_phase(enemy,"active")
		"active": _set_phase(enemy,"recovery")
		_:
			enemy.attack = ""
			enemy.attack_time = 0.0
			enemy.attack_length = 0.0
			enemy.shot_timer = float(_attack(str(enemy.attack_kind)).get("cooldown",1.0))

func _release(enemy: Dictionary) -> bool:
	var kind: String = str(enemy.attack_kind)
	var data: Dictionary = _attack(kind)
	if float(enemy.hp) <= 0: return false
	if kind == "summon":
		if not _can_summon(enemy): return false
		var spawned: bool = _game.spawn_crypt_minion(int(enemy.id),Vector2(enemy.summon_point))
		# The host's placement boundary increments summons_cast exactly once.
		if not spawned: enemy.summon_failures = int(enemy.get("summon_failures",0))+1
		return spawned
	var aim: Vector2 = enemy.attack_aim
	if kind in ["slash","bite","slam"]:
		# Melee: every living player in range and arc in front (slam hits all of them).
		var hit_all: bool = kind == "slam"
		var targets: Array = _game.players.keys() if hit_all else [int(enemy.attack_target)]
		for target_id: int in targets:
			var target: Dictionary = _game.players.get(target_id,{})
			if target.is_empty() or int(target.get("hp",0)) <= 0: continue
			var offset: Vector2 = Vector2(target.pos)-Vector2(enemy.pos)
			if offset.length() <= float(data.get("range",56)) and offset.normalized().dot(aim) >= float(data.get("arc_dot",0.35)) and not Dungeon.segment_blocked(enemy.pos,target.pos,0.0,_game.current_layout):
				_game._damage_player(target_id,int(data.get("damage",1)),aim if offset.is_zero_approx() else offset.normalized())
		if kind == "slam": _game.add_fx("slam",Vector2(enemy.pos)+aim*float(data.get("range",56))*0.5,float(data.get("range",56)))
		return true
	if kind == "fuse":
		# Leerenbomber: burst in a void explosion, hurting players nearby (not
		# through walls), and vanish without a kill reward.
		var radius: float = float(data.get("radius",72))
		for target_id in _game.players:
			var target: Dictionary = _game.players[target_id]
			if int(target.get("hp",0)) <= 0: continue
			var offset: Vector2 = Vector2(target.pos)-Vector2(enemy.pos)
			if offset.length() <= radius+float(_game.balance.player.radius) and not Dungeon.segment_blocked(enemy.pos,target.pos,0.0,_game.current_layout):
				_game._damage_player(target_id,int(data.get("damage",2)),offset.normalized() if not offset.is_zero_approx() else aim)
		_game.add_fx("void_burst",Vector2(enemy.pos),radius)
		enemy.exploded = true
		enemy.hp = 0.0
		enemy.dying = float(_game.balance.death.duration)
		return true
	if kind == "roar":
		# Mini-boss shockwave: a ring of slow bullets around the body.
		var count: int = int(data.get("bullet_count",10))
		var fired := false
		for index in range(count):
			var direction := Vector2.from_angle(TAU*index/count+float(enemy.get("attacks",0))*0.31)
			var bullet: Dictionary = _game._add_bullet(Vector2(enemy.pos)+direction*float(enemy.radius),direction*float(data.get("bullet_speed",150)),0,float(data.get("damage",1)),{"style":"roar","radius":float(data.get("bullet_radius",6)),"life":float(data.get("bullet_lifetime",3)),"caster_id":int(enemy.id)})
			fired = fired or not bullet.is_empty()
		return fired
	var radius: float = float(data.get("bullet_radius",5))
	var muzzle: Vector2 = Vector2(enemy.pos)+aim*float(data.get("muzzle_offset",18))
	if Dungeon.segment_blocked(enemy.pos,muzzle,radius,_game.current_layout): return false
	var bullet: Dictionary = _game._add_bullet(muzzle,aim*float(data.get("bullet_speed",155)),0,float(data.get("damage",1)),{"style":kind,"radius":radius,"life":float(data.get("bullet_lifetime",4)),"caster_id":int(enemy.id)})
	return not bullet.is_empty()

func _can_summon(enemy: Dictionary) -> bool:
	var limits: Dictionary = _settings().get("limits",{})
	if int(enemy.get("summons_cast",0)) >= int(limits.get("max_summons_per_caster",2)): return false
	if int(enemy.get("summon_failures",0)) >= int(limits.get("max_summon_failures",2)): return false
	var cadence: int = maxi(1,int(_settings().get("encounter",{}).get("summon_every_attacks",3)))
	if int(enemy.get("attacks",0))%cadence != cadence-1: return false
	var alive: int = 0
	var summoned: int = 0
	for other: Dictionary in _game.enemies:
		if float(other.get("hp",0)) <= 0: continue
		alive += 1
		if int(other.get("caster_id",-1)) == int(enemy.id): summoned += 1
	return alive < int(limits.get("max_enemies",12)) and summoned < int(limits.get("max_active_summons",2))

func _move(enemy: Dictionary, target_point: Vector2, data: Dictionary, visible: bool, delta: float) -> void:
	var offset: Vector2 = target_point-Vector2(enemy.pos)
	var distance: float = offset.length()
	var goal: Vector2 = target_point
	var encounter: Dictionary = _settings().get("encounter",{})
	if visible and distance < float(data.range_min):
		goal = Vector2(enemy.pos)-offset.normalized()*float(encounter.get("retreat_distance",144))
	elif visible and distance <= float(data.range_max): return
	var bounds_data: Array = _game.current_layout.get("play_bounds",[0,0,768,512])
	var radius: float = float(enemy.radius)
	var bounds: Rect2 = Rect2(float(bounds_data[0])+radius,float(bounds_data[1])+radius,float(bounds_data[2])-radius*2,float(bounds_data[3])-radius*2)
	goal = goal.clamp(bounds.position,bounds.end)
	enemy.nav_timer = float(enemy.get("nav_timer",0.0))-delta
	if float(enemy.nav_timer) <= 0:
		enemy.nav_path = Dungeon.find_path(enemy.pos,goal,radius,_game.current_layout)
		enemy.nav_timer = maxf(float(encounter.get("minimum_repath_interval",0.2)),float(_game.balance.get("navigation",{}).get("repath_interval",0.3)))
	var path: PackedVector2Array = enemy.get("nav_path",PackedVector2Array())
	while not path.is_empty() and Vector2(enemy.pos).distance_to(path[0]) < float(encounter.get("path_arrival_distance",8)): path.remove_at(0)
	enemy.nav_path = path
	if path.is_empty(): return
	var direction: Vector2 = (path[0]-Vector2(enemy.pos)).normalized()
	var before: Vector2 = enemy.pos
	var scale: float = 1.0
	var combat: Variant = _game.get("perk_combat")
	if combat != null: scale = float(combat.speed_scale(enemy))
	var parts := _parts()
	if parts != null: scale *= float(parts.speed_scale(enemy))
	enemy.pos = Dungeon.move_actor(enemy.pos,direction*float(enemy.speed)*scale*delta,radius,_game.current_layout)
	enemy.moving = before.distance_squared_to(enemy.pos) > 0.001
	# Skeletons face their target, so a pursuing guard's shield orientation is clear.
	_face(enemy,offset)

## Frontal physical hits are reduced only while the small shield is raised.
## Status/area damage, rear hits, stun, freeze and all attack phases bypass it.
func guard_multiplier(enemy: Dictionary, incoming_direction: Vector2, feedback: bool = true) -> float:
	if bool(enemy.get("boss",false)): return 1.0
	if not feedback or str(enemy.get("kind","")) != "skeleton_guard" or float(enemy.get("hp",0)) <= 0: return 1.0
	if not str(enemy.get("attack","")).is_empty() or float(enemy.get("hitstun",0.0)) > 0 or enemy.get("statuses",{}).has("freeze"): return 1.0
	if incoming_direction.length_squared() <= 0.00001: return 1.0
	# A broken shield no longer blocks.
	var parts := _parts()
	if parts != null and not parts.can(enemy,"block"): return 1.0
	var facing: Vector2 = enemy.get("facing_dir",Vector2(float(enemy.get("face",1.0)),0))
	var data: Dictionary = definition("skeleton_guard")
	return float(data.get("guard_multiplier",0.35)) if facing.normalized().dot(-incoming_direction.normalized()) >= float(data.get("guard_cone_dot",0.5)) else 1.0
