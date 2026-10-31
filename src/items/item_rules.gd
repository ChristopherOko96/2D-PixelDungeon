extends RefCounted
## Static item rules (data: assets/data/items.json): weapon and gear
## definitions (armour, ring, amulet; docs/ITEM-SYSTEM-V2.de.md), stages, and
## what the equipped pieces do to a hero's stats every time PerkRules rebuilds
## them: the weapon's base values and effects, gear stats and effects (all
## scaled by their stage), the effects of potions drunk this run (augments),
## and every equipped piece's curse or, once broken, its blessing (slower
## attacks, slower walking, a sealed skill, heavier hits taken, a dim light,
## faster cooldowns...), and the items' Elementsprache: which element a piece
## or potion fights in (items.json "element", else its effects through
## effect_elements) and the glow colour its shots and held blade take from it.
## Pure functions on the player dictionary; the inventory (inventory.gd) owns
## finding, carrying and using items.

const DATA_PATH := "res://assets/data/items.json"

## The four equipment slots of a hero, in order.
const EQUIP_SLOTS := ["weapon", "armor", "ring", "amulet"]

static var _data: Dictionary = {}
static var _weapons: Dictionary = {}
static var _gear: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
		_weapons.clear()
		_gear.clear()
		for entry: Dictionary in _data.get("weapons", []): _weapons[str(entry.id)] = entry
		for entry: Dictionary in _data.get("gear", []): _gear[str(entry.id)] = entry
	return _data


static func weapon(id: String) -> Dictionary:
	data()
	return _weapons.get(id, {})


static func curse(id: String) -> Dictionary:
	return data().get("curses", {}).get(id, {})


## A piece of armour, a ring or an amulet by id ({} when unknown).
static func gear(id: String) -> Dictionary:
	data()
	return _gear.get(id, {})


## The definition behind a weapon or gear item.
static func spec_of(item: Dictionary) -> Dictionary:
	match str(item.get("type", "")):
		"weapon": return weapon(str(item.get("id", "")))
		"gear": return gear(str(item.get("id", "")))
	return {}


## Which equipment slot an item goes into ("" for none).
static func slot_of(item: Dictionary) -> String:
	match str(item.get("type", "")):
		"weapon": return "weapon"
		"gear": return str(gear(str(item.get("id", ""))).get("slot", ""))
	return ""


## The hero's equipped pieces (weapon, armour, ring, amulet), empty slots left out.
static func equipped(player: Dictionary) -> Array:
	var inventory: Dictionary = player.get("inventory", {})
	var out: Array = []
	for slot: String in EQUIP_SLOTS:
		var item: Dictionary = inventory.get(slot, {})
		if not item.is_empty(): out.append(item)
	return out


## An item's stage (-3 .. +3; 0 for items without one).
static func stage(item: Dictionary) -> int:
	return int(item.get("stage", 0))


## How much a stage changes a value: 1 + per_stage x stage, or for values
## where less is better (attack pauses) 1 - per_stage_less x stage.
static func stage_factor(item: Dictionary, less: bool = false) -> float:
	var rules: Dictionary = data().get("stage", {})
	if less: return 1.0 - float(rules.get("per_stage_less", 0.08)) * stage(item)
	return 1.0 + float(rules.get("per_stage", 0.15)) * stage(item)


## A stage rolled around the mean (lower when cursed), clamped to min..max.
static func roll_stage(rng: RandomNumberGenerator, cursed: bool) -> int:
	var rules: Dictionary = data().get("stage", {})
	var mean := float(rules.get("mean_cursed", -1.5)) if cursed else float(rules.get("mean", 0.5))
	return clampi(roundi(rng.randfn(mean, float(rules.get("spread", 1.0)))), int(rules.get("min", -3)), int(rules.get("max", 3)))


## "+2" / "-1" for a known stage, "" for 0.
static func stage_text(item: Dictionary) -> String:
	var value := stage(item)
	if value == 0: return ""
	return ("+%d" % value) if value > 0 else ("-%d" % absi(value))


## The class's starting weapon (common, known, never cursed).
static func start_weapon(class_id: String) -> Dictionary:
	for entry: Dictionary in data().get("weapons", []):
		if str(entry.get("class", "")) == class_id and bool(entry.get("start", false)): return entry
	return {}


## True when a curse holds an equipped piece: known, not yet broken.
static func stuck(item: Dictionary) -> bool:
	return str(item.get("type", "")) in ["weapon", "gear"] and not str(item.get("curse", "")).is_empty() and bool(item.get("identified", false)) and not bool(item.get("blessed", false))


# --- elements ------------------------------------------------------------------------

## The elements table (items.json elements): element -> {name, ramp, glow, motes}.
static func elements() -> Dictionary:
	return data().get("elements", {})


## One element's row ({} for an unknown element): name (shown), ramp (palette
## ramp, src/vfx/talent_palette.gd), glow (hex), motes (how its pixels move).
static func element_info(element: String) -> Dictionary:
	return elements().get(element, {})


## The element a set of effects implies (a spec's, a blessing's or a hero's
## whole build): the first key of items.json effect_elements, in its order,
## that is present and above zero; "" for none.
static func element_of_effects(effects: Dictionary) -> String:
	var table: Dictionary = data().get("effect_elements", {})
	for key: String in table:
		if float(effects.get(key, 0.0)) > 0.0: return str(table[key])
	return ""


## The element of a weapon or gear definition: its explicit "element", else
## what its effects imply; "" for a plain piece.
static func element_of_spec(spec: Dictionary) -> String:
	var explicit := str(spec.get("element", ""))
	return explicit if not explicit.is_empty() else element_of_effects(spec.get("effects", {}))


## The element an item fights in: a weapon's or gear piece's own, else that of
## its curse (the burning blade burns either way; blessed, its blessing's),
## a potion's kind's; "" for none. Whether the item is identified is the
## caller's business (an unknown piece shows nothing, inventory.gd view).
static func element_of(item: Dictionary) -> String:
	match str(item.get("type", "")):
		"weapon", "gear":
			var own := element_of_spec(spec_of(item))
			if not own.is_empty(): return own
			var rules := curse(str(item.get("curse", "")))
			if rules.is_empty(): return ""
			if bool(item.get("blessed", false)):
				var blessing: Dictionary = rules.get("blessing", {})
				var blessed := str(blessing.get("element", ""))
				return blessed if not blessed.is_empty() else element_of_effects(blessing.get("effects", {}))
			return str(rules.get("element", ""))
		"potion":
			return str(data().get("potions", {}).get(str(item.get("potion", "")), {}).get("element", ""))
	return ""


## The glow colour of an element as hex without "#" (its lite tone; "" for an
## unknown element).
static func element_glow(element: String) -> String:
	return str(element_info(element).get("glow", ""))


## The colour a weapon's shots and held blade glow in, as hex: the weapon's own
## "glow" first (its look), else its element's; "" leaves the class default.
static func glow_of(item: Dictionary) -> String:
	var own := str(spec_of(item).get("glow", ""))
	return own if not own.is_empty() else element_glow(element_of(item))


## The weapon's base values replace the class weapon's (call before PerkRules.rebuild).
static func set_base(player: Dictionary) -> void:
	var item: Dictionary = player.get("inventory", {}).get("weapon", {})
	var spec := weapon(str(item.get("id", "")))
	if spec.is_empty() or not player.has("_perk_base"): return
	# the weapon's stage scales its hits and its pause
	player._perk_base.damage = float(spec.get("damage", player._perk_base.damage)) * stage_factor(item)
	player._perk_base.shot_interval = float(spec.get("interval", player._perk_base.shot_interval)) * stage_factor(item, true)
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
	# The colour the weapon's shots glow in (src/vfx/attack_fx.gd tint_for reads it as the
	# player's "glow"): the weapon's own glow, else its element's; empty: build element or default.
	player.attack_glow = glow_of(item)
	# The element the held weapon fights in ("" for none), for the hero look and the HUD.
	player.attack_element = element_of(item)


## After PerkRules has rebuilt the stats: weapon and gear effects, gear stats
## (scaled by their stage), drunk augments, and the curse or blessing of every
## equipped piece. Called from PerkRules.rebuild.
static func apply(player: Dictionary) -> void:
	player.cooldown_scale = 1.0
	player.item_extra_damage = 0
	player.dim = false
	player.erase("sealed_skill")
	var build: Dictionary = player.get("build", {})
	for key: String in player.get("augments", {}): build[key] = float(build.get(key, 0.0)) + float(player.augments[key])
	for item: Dictionary in equipped(player):
		var spec := spec_of(item)
		for key: String in spec.get("effects", {}): build[key] = float(build.get(key, 0.0)) + float(spec.effects[key])
		if str(item.type) == "gear": _gear_stats(player, spec.get("stats", {}), stage_factor(item))
		_curse(player, build, item)
	player.build = build


## Armour, ring and amulet values: shares of damage, attack rate, speed and
## cooldowns, and extra HP; all grow or shrink with the piece's stage.
static func _gear_stats(player: Dictionary, stats: Dictionary, factor: float) -> void:
	if stats.has("damage"): player.damage = float(player.damage) * (1.0 + float(stats.damage) * factor)
	if stats.has("rate"): player.shot_interval = float(player.shot_interval) * (1.0 - float(stats.rate) * factor)
	if stats.has("speed"): player.speed = float(player.speed) * (1.0 + float(stats.speed) * factor)
	if stats.has("cooldown"): player.cooldown_scale = float(player.cooldown_scale) * (1.0 + float(stats.cooldown) * factor)
	if stats.has("max_hp"): player.max_hp = int(player.max_hp) + maxi(0, roundi(float(stats.max_hp) * factor))


## One piece's curse, or its blessing once the curse is broken.
static func _curse(player: Dictionary, build: Dictionary, item: Dictionary) -> void:
	var curse_id := str(item.get("curse", ""))
	if curse_id.is_empty(): return
	var rules := curse(curse_id)
	if bool(item.get("blessed", false)):
		var blessing: Dictionary = rules.get("blessing", {})
		for key: String in blessing.get("effects", {}): build[key] = float(build.get(key, 0.0)) + float(blessing.effects[key])
		if blessing.has("interval"): player.shot_interval = float(player.shot_interval) * float(blessing.interval)
		if blessing.has("speed"): player.speed = float(player.speed) * float(blessing.speed)
		if blessing.has("cooldown"): player.cooldown_scale = float(player.cooldown_scale) * float(blessing.cooldown)
		return
	match curse_id:
		"leaden": player.shot_interval = float(player.shot_interval) * float(rules.get("interval", 1.4))
		"sluggish": player.speed = float(player.speed) * float(rules.get("speed", 0.8))
		"sealed": if not player.has("sealed_skill"): player.sealed_skill = int(item.get("seal", 1))
		"fragile": player.item_extra_damage = int(player.item_extra_damage) + int(rules.get("extra_damage", 1))
		"night": player.dim = true
