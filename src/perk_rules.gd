extends RefCounted
## Host-side catalog, derived build values and bounded personal reward offers.
## Combat consumes build coefficients; this module never simulates world effects.

## Captures immutable baseline stats once, then restores derived build fields.
## Calling this for an existing run neither heals nor compounds previous perks.
static func initialize_player(player: Dictionary, balance: Dictionary) -> void:
	if not player.has("perks"):
		player["perks"] = []
	if not player.has("_perk_base"):
		var defaults: Dictionary = balance.get("player",{})
		player["_perk_base"] = {
			"damage":float(defaults.get("damage",2.0)),
			"speed":float(defaults.get("speed",190.0)),
			"shot_interval":float(defaults.get("shot_interval",0.2)),
			"max_hp":int(defaults.get("hp",8))}
	if not player.has("hp"):
		player["hp"] = int(player._perk_base.max_hp)
	if not player.has("reserve_shield"):
		player["reserve_shield"] = 0
	rebuild(player,balance)

## Derives current stats and combat coefficients from owned canonical IDs.
## Recalculation is idempotent and never restores missing current health.
static func rebuild(player: Dictionary, balance: Dictionary) -> void:
	if not player.has("_perk_base"):
		initialize_player(player,balance)
		return
	var base: Dictionary = player._perk_base
	var settings: Dictionary = balance.get("perk_rules",{})
	var damage: float = float(base.damage)
	var speed: float = float(base.speed)
	var maximum_hp: int = int(base.max_hp)
	var interval: float = float(base.shot_interval)
	var build: Dictionary = {}
	for definition: Dictionary in balance.get("perks",[]):
		var id: String = str(definition.get("id",""))
		var owned: int = stack_count(player,id)
		var limit: int = int(definition.get("max_stacks",1))
		if limit > 0: owned = mini(owned,limit)
		if owned <= 0: continue
		var amount: float = float(definition.get("amount",0.0))
		match str(definition.get("stat","effect")):
			"damage": damage += amount*owned
			"speed": speed += amount*owned
			"max_hp": maximum_hp += int(amount)*owned
			"shot_interval": interval *= pow(amount,owned)
			"effect": build[id] = amount*owned
	player["damage"] = clampf(damage,0.1,float(settings.get("max_damage",16.0)))
	player["speed"] = clampf(speed,1.0,float(settings.get("max_speed",340.0)))
	player["shot_interval"] = maxf(float(settings.get("min_shot_interval",0.06)),interval)
	player["max_hp"] = clampi(maximum_hp,1,int(settings.get("max_hp",32)))
	player["hp"] = clampi(int(player.get("hp",maximum_hp)),0,int(player.max_hp))
	player["build"] = build

## Resolves IDs against host data, checks ownership caps and applies one grant.
## Caller-supplied effect fields are ignored, including spoofed amount/stat data.
static func grant(player: Dictionary, definition: Dictionary, balance: Dictionary) -> bool:
	var id: String = str(definition.get("id",""))
	var canonical: Dictionary = find(balance,id)
	if canonical.is_empty(): return false
	initialize_player(player,balance)
	var stat: String = str(canonical.get("stat","effect"))
	var amount: float = float(canonical.get("amount",0.0))
	if stat == "reserve":
		player["reserve_shield"] = 1
		player["last_perk"] = id
		return true
	var maximum: int = int(canonical.get("max_stacks",1))
	if maximum > 0 and stack_count(player,id) >= maximum: return false
	if stat == "heal" and int(player.hp) >= int(player.max_hp): return false
	var previous_maximum: int = int(player.max_hp)
	player.perks.append(id)
	rebuild(player,balance)
	if stat == "max_hp":
		player.hp = mini(int(player.max_hp),int(player.hp)+maxi(0,int(player.max_hp)-previous_maximum))
	elif stat == "heal":
		player.hp = mini(int(player.max_hp),int(player.hp)+int(amount))
	player["last_perk"] = id
	return true

## Produces distinct personal choices using rarity weight and bounded tag affinity.
## Capped, unmet prerequisite and full-health pure-healing choices are excluded.
## A canonical temporary shield is the only exhausted-pool fallback.
static func offer(player: Dictionary, balance: Dictionary, rng: RandomNumberGenerator, count: int = 3) -> Array:
	var result: Array = []
	if count <= 0: return result
	var settings: Dictionary = balance.get("perk_rules",{})
	var pool: Array = []
	var owned_tags: Dictionary = {}
	for definition: Dictionary in balance.get("perks",[]):
		if stack_count(player,str(definition.get("id",""))) <= 0: continue
		for tag: String in definition.get("tags",[]): owned_tags[tag] = true
	for definition: Dictionary in balance.get("perks",[]):
		var id: String = str(definition.get("id",""))
		var maximum: int = int(definition.get("max_stacks",1))
		if maximum > 0 and stack_count(player,id) >= maximum: continue
		# Projectile-only perks change shots and do nothing for a melee class.
		if bool(definition.get("projectile_only",false)) and bool(player.get("melee",false)): continue
		if str(definition.get("stat","")) == "heal" and int(player.get("hp",0)) >= int(player.get("max_hp",0)): continue
		var required: Array = definition.get("requires_any",[])
		var all_satisfied: bool = true
		for prerequisite: String in definition.get("requires_all",[]):
			if stack_count(player,prerequisite) <= 0: all_satisfied = false
		if not all_satisfied: continue
		if not required.is_empty():
			var satisfied: bool = false
			for prerequisite: String in required:
				if stack_count(player,prerequisite) > 0: satisfied = true
			if not satisfied: continue
		var shared: int = 0
		for tag: String in definition.get("tags",[]):
			if owned_tags.has(tag): shared += 1
		var affinity: float = minf(float(settings.get("max_synergy_bonus",1.0)),shared*float(settings.get("synergy_weight",0.35)))
		pool.append({"definition":definition,"weight":maxf(0.001,float(definition.get("weight",1.0)))*(1.0+affinity)})
	while not pool.is_empty() and result.size() < count:
		var total: float = 0.0
		for candidate: Dictionary in pool: total += float(candidate.weight)
		var roll: float = rng.randf()*total
		var selected: int = pool.size()-1
		for index: int in range(pool.size()):
			roll -= float(pool[index].weight)
			if roll <= 0.0:
				selected = index
				break
		result.append(pool[selected].definition.duplicate(true))
		pool.remove_at(selected)
	if result.is_empty():
		var fallback: Dictionary = settings.get("fallback",{})
		if not fallback.is_empty(): result.append(fallback.duplicate(true))
	return result

## Finds a canonical catalog definition or the explicitly configured fallback.
static func find(balance: Dictionary, id: String) -> Dictionary:
	if id.is_empty(): return {}
	for definition: Dictionary in balance.get("perks",[]):
		if str(definition.get("id","")) == id: return definition
	var fallback: Dictionary = balance.get("perk_rules",{}).get("fallback",{})
	return fallback if str(fallback.get("id","")) == id else {}

## Counts owned IDs; temporary exhausted-pool recovery never occupies a stack.
static func stack_count(player: Dictionary, id: String) -> int:
	return player.get("perks",[]).count(id)
