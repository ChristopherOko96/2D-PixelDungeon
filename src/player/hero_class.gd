extends RefCounted
## Hero classes on codex_v2 (step 2 of the main port, docs/KLASSEN-FAEHIGKEITEN.de.md).
## A class sets the player's base values (hearts, speed) and the class weapon
## (damage, attack interval, melee reach/arc or projectile speed/life/splash).
## The 48 perks then derive the final stats from these bases via PerkRules, so
## perk bonuses work for every class. Values live in balance.json (classes,
## weapons, class_order, default_class); this module only applies them.
## Pure static rules on a player dictionary, used by the host.

const PerkRules = preload("res://src/perk_rules.gd")


## The class id to use: `requested` when it exists, otherwise the default class.
static func resolve(requested: String, balance: Dictionary) -> String:
	var classes: Dictionary = balance.get("classes", {})
	if classes.has(requested): return requested
	return str(balance.get("default_class", "archer"))


## The weapon definition of a class ({} when the data is missing).
static func weapon_for(class_id: String, balance: Dictionary) -> Dictionary:
	var hero: Dictionary = balance.get("classes", {}).get(class_id, {})
	return balance.get("weapons", {}).get(str(hero.get("weapon", "")), {})


## Puts a class on a player: class id, weapon and attack shape, and the perk
## base values. Rebuilds perk-derived stats and refills health to the new
## maximum (classes are chosen in the lobby or at a fresh run start only).
static func apply(player: Dictionary, requested: String, balance: Dictionary) -> void:
	var class_id := resolve(requested, balance)
	var hero: Dictionary = balance.get("classes", {}).get(class_id, {})
	var held := weapon_for(class_id, balance)
	if hero.is_empty() or held.is_empty(): return
	player.class_id = class_id
	player.weapons = [str(hero.weapon)]
	player.weapon_index = 0
	player.melee = str(held.get("type", "projectile")) == "melee"
	player.reach = float(held.get("reach", 0.0)) if player.melee else 0.0
	player.arc = float(held.get("arc", 0.0)) if player.melee else 0.0
	player.shot_speed = 0.0 if player.melee else float(held.get("speed", 0.0))
	player.shot_life = 0.0 if player.melee else float(held.get("life", 0.0))
	player.splash = float(held.get("splash", 0.0))
	# Unmodified weapon values; class passives (Adlerauge, Nova) scale from these.
	player._class_shot_speed = player.shot_speed
	player._class_splash = player.splash
	player.projectile = str(held.get("projectile", ""))
	player._perk_base = {
		"damage": float(held.get("damage", 2.0)),
		"speed": float(hero.get("speed", 190.0)),
		"shot_interval": float(held.get("interval", 0.2)),
		"max_hp": int(hero.get("hp", 8))}
	PerkRules.rebuild(player, balance)
	player.hp = int(player.max_hp)


## Index of a class in balance.class_order (-1 when unknown).
static func order_index(class_id: String, balance: Dictionary) -> int:
	return Array(balance.get("class_order", [])).find(class_id)
