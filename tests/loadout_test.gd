extends SceneTree
## Headless checks for hero classes, weapons and class abilities
## (src/player/loadout.gd) with the real balance data.

const Loadout = preload("res://src/player/loadout.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("LOADOUT_FAIL: ", description)

func _initialize() -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	var knight := {}
	Loadout.apply_class(knight, "swordsman", balance)
	check(knight.class_id == "swordsman" and knight.melee and knight.weapons == ["sword"] and knight.hp == int(balance.classes.swordsman.hp), "a swordsman starts with a sword, melee only, and his hearts")
	var archer := {}
	Loadout.apply_class(archer, "archer", balance)
	check(not archer.melee and archer.weapons == ["bow"] and is_equal_approx(archer.shot_speed, float(balance.weapons.bow.speed)), "an archer starts with a bow")
	var mage := {}
	Loadout.apply_class(mage, "mage", balance)
	check(mage.weapons == ["staff"] and mage.max_hp < archer.max_hp and archer.max_hp < knight.max_hp, "a mage has the fewest hearts, a swordsman the most")
	var nobody := {}
	Loadout.apply_class(nobody, "nonsense", balance)
	check(nobody.class_id == balance.default_class, "an unknown class falls back to the default")

	# Chest boosts change the class weapon's numbers, never the weapon.
	var bonus := {}
	Loadout.apply_class(bonus, "swordsman", balance)
	Loadout.apply_boost(bonus, {"stat": "damage", "amount": 1.0}, balance)
	check(is_equal_approx(bonus.damage, float(balance.weapons.sword.damage) + 1.0) and bonus.weapons == ["sword"], "+1 damage from a chest raises the sword's damage")
	Loadout.apply_boost(bonus, {"stat": "rate", "amount": 0.9}, balance)
	check(bonus.shot_interval < float(balance.weapons.sword.interval), "an attack-speed boost shortens the swing interval")
	var hp_before: int = bonus.max_hp
	Loadout.apply_boost(bonus, {"stat": "max_hp", "amount": 2}, balance)
	check(bonus.max_hp == hp_before + 2, "a heart boost adds a container")
	check(not balance.has("loot") and not balance.weapons.has("longbow"), "heroes keep their class weapon: no foreign weapons lie around")

	# Abilities: only from the own class, never past their maximum.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var offer := Loadout.offer(archer, balance, rng)
	var own := true
	for id in offer:
		if str(balance.abilities[id]["class"]) != "archer": own = false
	check(offer.size() == 3 and own, "level-ups offer three abilities of the own class")
	for i in range(int(balance.abilities.multishot.max)): Loadout.apply_ability(archer, "multishot", balance)
	var later: Array = []
	for attempt in range(30): later.append_array(Loadout.offer(archer, balance, rng))
	check(not later.has("multishot"), "a maxed ability is no longer offered")
	var before: float = mage.damage
	Loadout.apply_ability(mage, "focus", balance)
	check(mage.damage > before and Loadout.stacks(mage, "focus") == 1, "Focus raises the mage's damage")
	var interval: float = knight.shot_interval
	Loadout.apply_ability(knight, "swift", balance)
	check(knight.shot_interval < interval, "Swift Blade shortens the swing interval")
	var hearts: int = knight.max_hp
	Loadout.apply_ability(knight, "vigor", balance)
	check(knight.max_hp == hearts + 2, "Iron Skin adds a heart")
	Loadout.apply_boost(knight, {"stat": "damage", "amount": 0.5}, balance)
	check(knight.shot_interval < float(balance.weapons.sword.interval), "abilities survive a later boost")
	var maxed := {}
	Loadout.apply_class(maxed, "mage", balance)
	for id in balance.abilities:
		if balance.abilities[id]["class"] == "mage":
			for i in range(int(balance.abilities[id].max)): Loadout.apply_ability(maxed, id, balance)
	check(Loadout.offer(maxed, balance, rng).is_empty(), "a hero with every ability maxed gets no offer")
	print("LOADOUT checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
