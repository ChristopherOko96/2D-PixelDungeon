extends RefCounted
## Hero classes, their weapons, the class abilities offered on level-up and
## the small boosts from chests. Pure static rules on a player dictionary,
## used by the host:
## - a class sets hearts, move speed, its weapon and its ability pool; a hero
##   keeps the class weapon for the whole run;
## - the weapon sets damage, attack interval and how it attacks (melee swing or
##   projectile); modifiers from perks, abilities and chests scale it;
## - each level-up offers three abilities from the class pool the player can
##   still take; choosing one applies it at once.
## All numbers live in balance.json (classes, weapons, abilities).


## Puts class defaults on a fresh player and equips the class weapon.
static func apply_class(player: Dictionary, class_id: String, balance: Dictionary) -> void:
	var classes: Dictionary = balance.classes
	var hero: Dictionary = classes.get(class_id, classes[balance.default_class])
	player.class_id = class_id if classes.has(class_id) else str(balance.default_class)
	player.max_hp = int(hero.hp)
	player.hp = int(hero.hp)
	player.speed = float(hero.speed)
	player.weapons = [str(hero.weapon)]
	player.weapon_index = 0
	player.abilities = {}
	player.mods = {"damage_mult": 1.0, "damage_bonus": 0.0, "rate_mult": 1.0, "range_mult": 1.0, "speed_mult": 1.0}
	player.choices = []
	player.pending_choices = 0
	equip(player, balance)


## The weapon in the player's hand.
static func weapon(player: Dictionary, balance: Dictionary) -> Dictionary:
	var weapons: Array = player.get("weapons", [])
	if weapons.is_empty():
		return balance.weapons[balance.classes[balance.default_class].weapon]
	return balance.weapons.get(str(weapons[clampi(int(player.get("weapon_index", 0)), 0, weapons.size() - 1)]), {})


## Recomputes the attack stats from the held weapon and the player's modifiers.
## Gameplay and HUD read the results (damage, shot_interval, range, shot_speed).
static func equip(player: Dictionary, balance: Dictionary) -> void:
	var held := weapon(player, balance)
	var mods: Dictionary = player.get("mods", {})
	player.melee = str(held.get("type", "projectile")) == "melee"
	player.damage = (float(held.damage) + float(mods.get("damage_bonus", 0.0))) * float(mods.get("damage_mult", 1.0))
	player.shot_interval = maxf(0.06, float(held.interval) * float(mods.get("rate_mult", 1.0)))
	if player.melee:
		player.reach = float(held.reach) * float(mods.get("range_mult", 1.0))
		player.arc = float(held.arc)
		player.range = 0.0
		player.shot_speed = 0.0
	else:
		player.range = float(held.life) * float(mods.get("range_mult", 1.0))
		player.shot_speed = float(held.speed) * float(mods.get("speed_mult", 1.0))
		player.reach = 0.0


## A chest boost: a small permanent raise of one stat (see balance.chest).
static func apply_boost(player: Dictionary, boost: Dictionary, balance: Dictionary) -> void:
	var mods: Dictionary = player.mods
	var amount: float = float(boost.amount)
	match str(boost.stat):
		"damage": mods.damage_bonus = float(mods.damage_bonus) + amount
		"rate": mods.rate_mult = float(mods.rate_mult) * amount
		"range": mods.range_mult = float(mods.range_mult) * amount
		"shot_speed": mods.speed_mult = float(mods.speed_mult) * amount
		"speed": player.speed = float(player.speed) + amount
		"luck": player.luck = float(player.get("luck", 0.0)) + amount
		"max_hp":
			player.max_hp = int(player.max_hp) + int(amount)
			player.hp = mini(int(player.max_hp), int(player.hp) + int(amount))
		"heal": player.hp = mini(int(player.max_hp), int(player.hp) + int(amount))
	equip(player, balance)


## Three (or fewer) abilities of the player's class that are not maxed yet,
## picked with `rng` so every peer sees the same offer.
static func offer(player: Dictionary, balance: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for id: String in balance.abilities:
		var ability: Dictionary = balance.abilities[id]
		if str(ability["class"]) == str(player.get("class_id", "")) and int(player.abilities.get(id, 0)) < int(ability.max):
			pool.append(id)
	pool.sort()
	var picks: Array = []
	while not pool.is_empty() and picks.size() < 3:
		picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picks


## Applies one stack of an ability. Stat abilities change the modifiers;
## behaviour abilities are read by the attack code from `abilities`.
static func apply_ability(player: Dictionary, id: String, balance: Dictionary) -> void:
	var ability: Dictionary = balance.abilities[id]
	player.abilities[id] = int(player.abilities.get(id, 0)) + 1
	var mods: Dictionary = player.mods
	var amount: float = float(ability.get("amount", 0.0))
	match str(ability.get("stat", "")):
		"damage_mult": mods.damage_mult = float(mods.damage_mult) * amount
		"rate_mult": mods.rate_mult = float(mods.rate_mult) * amount
		"range_speed":
			mods.range_mult = float(mods.range_mult) * amount
			mods.speed_mult = float(mods.speed_mult) * amount
		"move_speed": player.speed = float(player.speed) + amount
		"max_hp":
			player.max_hp = int(player.max_hp) + int(amount)
			player.hp = mini(int(player.max_hp), int(player.hp) + int(amount))
	equip(player, balance)


## How many stacks of `id` the player has (0 when none).
static func stacks(player: Dictionary, id: String) -> int:
	return int(player.get("abilities", {}).get(id, 0))
