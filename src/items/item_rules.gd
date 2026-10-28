extends RefCounted
## Static item rules (data: assets/data/items.json): weapon definitions, and
## what an equipped weapon does to a hero's stats every time PerkRules
## rebuilds them: the weapon's perk effects, the effects of potions drunk this
## run (augments), and the curse or, once broken, its blessing (slower attacks,
## slower walking, a sealed skill, heavier hits taken, a dim light, faster
## cooldowns...). Pure functions on the player dictionary; the inventory
## (inventory.gd) owns finding, carrying and using items.

const DATA_PATH := "res://assets/data/items.json"

static var _data: Dictionary = {}
static var _weapons: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
		_weapons.clear()
		for entry: Dictionary in _data.get("weapons", []): _weapons[str(entry.id)] = entry
	return _data


static func weapon(id: String) -> Dictionary:
	data()
	return _weapons.get(id, {})


static func curse(id: String) -> Dictionary:
	return data().get("curses", {}).get(id, {})


## The class's starting weapon (common, known, never cursed).
static func start_weapon(class_id: String) -> Dictionary:
	for entry: Dictionary in data().get("weapons", []):
		if str(entry.get("class", "")) == class_id and bool(entry.get("start", false)): return entry
	return {}


## True when a curse holds the hero's weapon: known, not yet broken.
static func stuck(item: Dictionary) -> bool:
	return str(item.get("type", "")) == "weapon" and not str(item.get("curse", "")).is_empty() and bool(item.get("identified", false)) and not bool(item.get("blessed", false))


## The weapon's base values replace the class weapon's (call before PerkRules.rebuild).
static func set_base(player: Dictionary) -> void:
	var item: Dictionary = player.get("inventory", {}).get("weapon", {})
	var spec := weapon(str(item.get("id", "")))
	if spec.is_empty() or not player.has("_perk_base"): return
	player._perk_base.damage = float(spec.get("damage", player._perk_base.damage))
	player._perk_base.shot_interval = float(spec.get("interval", player._perk_base.shot_interval))
	if bool(player.get("melee", false)):
		player.reach = float(spec.get("reach", player.get("reach", 64)))
		player.arc = float(spec.get("arc", player.get("arc", 2.0)))
	else:
		player.shot_speed = float(spec.get("speed", player.get("shot_speed", 500)))
		player.shot_life = float(spec.get("life", player.get("shot_life", 1.2)))
		player.splash = float(spec.get("splash", player.get("splash", 0.0)))
		player._class_shot_speed = player.shot_speed
		player._class_splash = player.splash
	player.weapons = ["res://assets/sprites/" + str(spec.get("sprite", "")) + ".png"]
	# The colour the weapon's shots glow in (src/vfx/attack_fx.gd); empty: element or default.
	player.attack_glow = str(spec.get("glow", ""))


## After PerkRules has rebuilt the stats: weapon effects, drunk augments, and
## the curse or blessing. Called from PerkRules.rebuild.
static func apply(player: Dictionary) -> void:
	player.cooldown_scale = 1.0
	player.item_extra_damage = 0
	player.dim = false
	player.erase("sealed_skill")
	var build: Dictionary = player.get("build", {})
	for key: String in player.get("augments", {}): build[key] = float(build.get(key, 0.0)) + float(player.augments[key])
	var item: Dictionary = player.get("inventory", {}).get("weapon", {})
	var spec := weapon(str(item.get("id", "")))
	for key: String in spec.get("effects", {}): build[key] = float(build.get(key, 0.0)) + float(spec.effects[key])
	player.build = build
	var curse_id := str(item.get("curse", ""))
	if curse_id.is_empty(): return
	var rules := curse(curse_id)
	if bool(item.get("blessed", false)):
		var blessing: Dictionary = rules.get("blessing", {})
		for key: String in blessing.get("effects", {}): build[key] = float(build.get(key, 0.0)) + float(blessing.effects[key])
		if blessing.has("interval"): player.shot_interval = float(player.shot_interval) * float(blessing.interval)
		if blessing.has("speed"): player.speed = float(player.speed) * float(blessing.speed)
		if blessing.has("cooldown"): player.cooldown_scale = float(blessing.cooldown)
		return
	match curse_id:
		"leaden": player.shot_interval = float(player.shot_interval) * float(rules.get("interval", 1.4))
		"sluggish": player.speed = float(player.speed) * float(rules.get("speed", 0.8))
		"sealed": player.sealed_skill = int(item.get("seal", 1))
		"fragile": player.item_extra_damage = int(rules.get("extra_damage", 1))
		"night": player.dim = true
