extends RefCounted
## Items of a run on the host (data assets/data/items.json, rules item_rules.gd).
## Every hero carries a weapon, an armour, a ring and an amulet slot and a bag
## (player.inventory = {weapon, armor, ring, amulet, bag}; item system 2,
## docs/ITEM-SYSTEM-V2.de.md). Weapons and gear have a stage (-3..+3) rolled
## when found; gear is found unknown and can be cursed like weapons. New
## consumables: Klonsiegel (a clone fights beside the hero for a while),
## Aufwertungsstein (+1 stage; may fail on cursed pieces), Würfelstein
## (rerolls a stage), Spiegelkristall (reveals the bag's potions). Every floor
## also has fixed finds (a crystal; a stone on per_floor.stone_floors, an extra
## potion on potion_floors) and mini guardians drop a rare piece.
## Gameplay review 2026-11 (production/qa/evidence/gameplay-review/BEWERTUNG.md
## R1, R3, R5, R6, R7): potions drop by their weight; a hero whose class has no
## weapon of a rarity finds gear instead; unknown pieces show their curse risk,
## unknown potions how many kinds are left and how many of them hurt, and the
## last unknown colour is learned by itself; drunk harmful potions keep their
## harm and leave a small benefit (after: a while immune to their element;
## blind: monsters lose the hero's track; explosion: it also hits the monsters
## round the drinker); thrown strength, haste and shield work weaker on everyone
## in the radius, thrown healing and regeneration also on companions.
## Items: weapons (class-bound, five rarities, found unidentified and often
## cursed), potions (known only by colour until identified; colours shuffled
## per run, knowledge shared by the team), identification crystals and
## curse-breaker stones (consumables stack). Heroes act through `act`: equip,
## identify (spends a crystal), cleanse (spends a stone; the curse turns into
## its blessing), drink, throw (at the mouse point) and drop. A cursed weapon,
## once equipped, cannot be swapped until its curse is broken. Also rolls the
## loot of crates, chests, Mimiks and gold crates, and runs the curses that act
## over time (thorns, blood toll, the burning blade). The views (view, snapshot)
## carry an identified item's element (ItemRules.element_of, items.json
## elements) for the inventory window's glow and motes and the hero look.

const ItemRules = preload("res://src/items/item_rules.gd")
const PerkRules = preload("res://src/perk_rules.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
## Slot value meaning "the weapon in hand" for identify / cleanse.
const EQUIPPED := 99
## Slot values of all equipment slots (the bag uses 0..size-1).
const SLOT_CODES := {"weapon": 99, "armor": 98, "ring": 97, "amulet": 96}
## Stacking consumables of item system 2.
const CONSUMABLES := ["clone_seal", "upgrade_stone", "dice_stone", "mirror_crystal"]

var game: Node
var data: Dictionary = {}
## Potion kind -> colour id (this run) and the kinds the team has learned.
var colors: Dictionary = {}
var known: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _next_uid := 1


func bind(owner: Node) -> void:
	game = owner
	data = ItemRules.data()


## A new run: potion colours are shuffled, nothing is known.
func new_run(seed_value: int) -> void:
	_rng.seed = seed_value + 424242
	known.clear()
	var kinds: Array = data.get("potions", {}).keys()
	var palette: Array = data.get("potion_colors", {}).keys()
	for index in range(palette.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var held: Variant = palette[index]
		palette[index] = palette[other]
		palette[other] = held
	colors.clear()
	for index in range(kinds.size()): colors[str(kinds[index])] = str(palette[index % palette.size()])


## A fresh hero: the class's common weapon in hand, an empty bag.
func start_kit(player: Dictionary) -> void:
	var spec := ItemRules.start_weapon(str(player.get("class_id", "")))
	player.inventory = {"weapon": make_weapon(str(spec.get("id", "")), true, "", 0) if not spec.is_empty() else {}, "armor": {}, "ring": {}, "amulet": {}, "bag": []}
	player.augments = {}
	player.item_note = ""
	# The note counter keeps running so a new note after a class change still shows.
	player.item_notes = int(player.get("item_notes", 0))
	equip_apply(player)


# --- Making items --------------------------------------------------------------------

## A weapon; `stage` -99 rolls one (cursed ones lower).
func make_weapon(id: String, identified: bool, curse: String, stage: int = -99) -> Dictionary:
	var item := {"uid": _next_uid, "type": "weapon", "id": id, "identified": identified, "curse": curse, "blessed": false,
		"stage": stage if stage != -99 else ItemRules.roll_stage(_rng, not curse.is_empty())}
	if curse == "sealed": item.seal = _rng.randi_range(0, 3)
	_next_uid += 1
	return item


## An armour, ring or amulet; `stage` -99 rolls one.
func make_gear(id: String, identified: bool, curse: String, stage: int = -99) -> Dictionary:
	var item := {"uid": _next_uid, "type": "gear", "id": id, "identified": identified, "curse": curse, "blessed": false,
		"stage": stage if stage != -99 else ItemRules.roll_stage(_rng, not curse.is_empty())}
	if curse == "sealed": item.seal = _rng.randi_range(0, 3)
	_next_uid += 1
	return item


func make_stack(type: String, potion: String = "", count: int = 1) -> Dictionary:
	var item := {"uid": _next_uid, "type": type, "count": count}
	if type == "potion": item.potion = potion
	# some clone seals hold longer
	if type == "clone_seal" and _rng.randf() < float(data.get("clone_seal", {}).get("rare_chance", 0.2)): item.rare = true
	_next_uid += 1
	return item


## What a source drops for a hero of `class_id` on `floor_number` ([] for nothing).
func roll(source: String, floor_number: int, class_id: String) -> Array:
	var spec: Dictionary = data.get("drops", {}).get(source, {})
	if spec.is_empty(): return []
	var depth := clampf((float(floor_number) - 1.0) / 9.0, 0.0, 1.0)
	var chance: Array = spec.get("chance", [0.2, 0.2])
	if _rng.randf() > lerpf(float(chance[0]), float(chance[1]), depth): return []
	var result: Array = [_roll_kind(spec, depth, class_id)]
	for extra: String in spec.get("extra", []): result.append(make_stack(extra))
	return result


func _roll_kind(spec: Dictionary, depth: float, class_id: String) -> Dictionary:
	var kinds: Dictionary = spec.get("kinds", {"potion": 1})
	var total := 0.0
	for kind: String in kinds: total += float(kinds[kind])
	var roll := _rng.randf() * total
	var chosen := "potion"
	for kind: String in kinds:
		roll -= float(kinds[kind])
		if roll <= 0.0:
			chosen = kind
			break
	match chosen:
		"weapon": return _roll_weapon(depth, class_id, str(spec.get("min_rarity", "common")), _gear_class(spec, class_id), bool(spec.get("clean", false)))
		"gear": return _roll_gear(depth, str(spec.get("min_rarity", "common")), _gear_class(spec, class_id), bool(spec.get("clean", false)))
		"potion": return make_stack("potion", _roll_potion())
	return make_stack(chosen)


## A potion kind by the potions' drop weights (items.json potions.*.weight, 1 when
## unset): healing often, the run potions rarely (gameplay review R3).
func _roll_potion() -> String:
	var potions: Dictionary = data.get("potions", {})
	var total := 0.0
	for kind: String in potions: total += maxf(0.0, float(potions[kind].get("weight", 1.0)))
	var roll := _rng.randf() * total
	var chosen := ""
	for kind: String in potions:
		chosen = kind
		roll -= maxf(0.0, float(potions[kind].get("weight", 1.0)))
		if roll <= 0.0: break
	return chosen


## The class a source's gear must be made for: the hero's with own_class, else "" (any piece).
func _gear_class(spec: Dictionary, class_id: String) -> String:
	return class_id if bool(spec.get("own_class", false)) else ""


## A weapon of the hero's class of a rolled rarity; own and clean pass to the gear rolled in its
## place when the class has none of that rarity (clean: never cursed).
func _roll_weapon(depth: float, class_id: String, minimum: String, own := "", clean := false) -> Dictionary:
	var weights: Dictionary = data.get("rarity_weights", {})
	var lowest := RARITIES.find(minimum)
	var total := 0.0
	for index in range(lowest, RARITIES.size()):
		var pair: Array = weights.get(RARITIES[index], [1, 1])
		total += lerpf(float(pair[0]), float(pair[1]), depth)
	var roll := _rng.randf() * total
	var rarity: String = RARITIES[lowest]
	for index in range(lowest, RARITIES.size()):
		var pair: Array = weights.get(RARITIES[index], [1, 1])
		roll -= lerpf(float(pair[0]), float(pair[1]), depth)
		if roll <= 0.0:
			rarity = RARITIES[index]
			break
	var pool: Array = data.get("weapons", []).filter(func(entry: Dictionary) -> bool: return str(entry.rarity) == rarity and str(entry["class"]) == class_id and not bool(entry.get("start", false)))
	# no weapon of the hero's class at this rarity (the necromancer has only his start staff):
	# a piece of gear he can wear instead of another class's weapon (gameplay review R1)
	if pool.is_empty(): return _roll_gear(depth, minimum, own, clean)
	var spec: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
	return make_weapon(str(spec.id), false, "" if clean else _roll_curse("weapon"))


## A rarity from the floor's weights, at least `minimum`.
func _roll_rarity(depth: float, minimum: String) -> String:
	var weights: Dictionary = data.get("rarity_weights", {})
	var lowest := RARITIES.find(minimum)
	var total := 0.0
	for index in range(lowest, RARITIES.size()):
		var pair: Array = weights.get(RARITIES[index], [1, 1])
		total += lerpf(float(pair[0]), float(pair[1]), depth)
	var roll := _rng.randf() * total
	for index in range(lowest, RARITIES.size()):
		var pair: Array = weights.get(RARITIES[index], [1, 1])
		roll -= lerpf(float(pair[0]), float(pair[1]), depth)
		if roll <= 0.0: return RARITIES[index]
	return RARITIES[lowest]


## An armour, ring or amulet of a rolled rarity (the nearest one that exists). With own a class: a
## piece made for that class, else one made for no class. clean: never cursed.
func _roll_gear(depth: float, minimum: String, own := "", clean := false) -> Dictionary:
	var rarity := _roll_rarity(depth, minimum)
	var all: Array = data.get("gear", [])
	var pool: Array = all.filter(func(entry: Dictionary) -> bool: return str(entry.rarity) == rarity)
	if own != "":
		var mine := pool.filter(func(entry: Dictionary) -> bool: return str(entry.get("class", "")) == own)
		pool = mine if not mine.is_empty() else pool.filter(func(entry: Dictionary) -> bool: return str(entry.get("class", "")) == "")
	if pool.is_empty(): pool = all
	var spec: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
	return make_gear(str(spec.id), false, "" if clean else _roll_curse(str(spec.slot)))


## A curse for a found piece in `slot` ("" for none); gear never gets the burning blade.
func _roll_curse(slot: String) -> String:
	var chance := float(data.get("curse_by_slot", {}).get(slot, data.get("curse_chance", 0.6)))
	if _rng.randf() >= chance: return ""
	var curses: Array = data.get("curses", {}).keys()
	if slot != "weapon": curses.erase("burning_blade")
	return str(curses[_rng.randi_range(0, curses.size() - 1)])


## The fixed finds of a floor (docs/LAUF-DESIGN.de.md 3.5): an identification
## crystal; a curse-breaker stone on the floors per_floor.stone_floors (the old
## stone_every when that list is missing) and an extra potion on potion_floors, so
## trying pieces and potions is cheap from floor 1 on (gameplay review R3, R6).
func floor_finds(floor_number: int) -> Array:
	var rules: Dictionary = data.get("per_floor", {})
	var out: Array = []
	if int(rules.get("crystal", 1)) > 0: out.append(make_stack("crystal", "", int(rules.get("crystal", 1))))
	var stone := _listed(rules.get("stone_floors"), floor_number)
	if not rules.has("stone_floors"):
		var every := int(rules.get("stone_every", 2))
		stone = every > 0 and floor_number % every == 0
	if stone: out.append(make_stack("stone"))
	if _listed(rules.get("potion_floors"), floor_number): out.append(make_stack("potion", _roll_potion()))
	return out


## True when the floor list `list` (JSON numbers) holds `floor_number`.
func _listed(list: Variant, floor_number: int) -> bool:
	if not (list is Array): return false
	for entry: Variant in list:
		if int(entry) == floor_number: return true
	return false


## What a mini guardian drops: a piece of gear or a weapon, at least rare.
func guardian_drop(floor_number: int, class_id: String) -> Dictionary:
	var spec: Dictionary = data.get("per_floor", {}).get("mini_drop", {"kinds": {"gear": 2, "weapon": 1}, "min_rarity": "rare"})
	return _roll_kind(spec, clampf((float(floor_number) - 1.0) / 9.0, 0.0, 1.0), class_id)


# --- The bag -------------------------------------------------------------------------

## Puts an item in the hero's bag (consumables stack). False when it is full.
func add(player: Dictionary, item: Dictionary) -> bool:
	var bag: Array = player.inventory.bag
	if str(item.type) not in ["weapon", "gear"]:
		for held: Dictionary in bag:
			if str(held.type) == str(item.type) and str(held.get("potion", "")) == str(item.get("potion", "")) and bool(held.get("rare", false)) == bool(item.get("rare", false)):
				held.count = int(held.count) + int(item.get("count", 1))
				note(player, "Gefunden: " + name_of(item))
				return true
	if bag.size() >= int(data.get("bag", 12)):
		note(player, "Inventar voll.")
		return false
	bag.append(item)
	note(player, "Gefunden: " + name_of(item))
	return true


## A message for the hero (the last one, a running count, and the last few in
## `item_note_log` so a burst of finds in one frame is seen whole; items.json
## "note_log" sets how many, default 8).
func note(player: Dictionary, text: String) -> void:
	player.item_note = text
	player.item_notes = int(player.get("item_notes", 0)) + 1
	var recent: Array = player.get("item_note_log", [])
	recent.append(text)
	while recent.size() > maxi(1, int(data.get("note_log", 8))): recent.pop_front()
	player.item_note_log = recent


## The name a hero sees: unknown weapons, gear and potions show only what they look like.
func name_of(item: Dictionary) -> String:
	match str(item.get("type", "")):
		"weapon", "gear":
			var spec := ItemRules.spec_of(item)
			if not bool(item.get("identified", false)): return str(spec.get("unknown_name", "UNBEKANNTES STÜCK"))
			var title := str(spec.get("name", "WAFFE"))
			if not ItemRules.stage_text(item).is_empty(): title += " " + ItemRules.stage_text(item)
			if bool(item.get("blessed", false)): return title + " · " + str(ItemRules.curse(str(item.curse)).get("blessing", {}).get("name", ""))
			if not str(item.get("curse", "")).is_empty(): return title + " · " + str(ItemRules.curse(str(item.curse)).get("name", "VERFLUCHT"))
			return title
		"potion":
			var kind := str(item.get("potion", ""))
			if known.has(kind): return str(data.potions[kind].get("name", "TRANK"))
			return str(data.get("potion_colors", {}).get(str(colors.get(kind, "red")), "TRANK"))
		"crystal": return str(data.get("crystal", {}).get("name", "KRISTALL"))
		"stone": return str(data.get("stone", {}).get("name", "STEIN"))
		"clone_seal": return str(data.get("clone_seal", {}).get("name", "KLONSIEGEL")) + (" (SELTEN)" if bool(item.get("rare", false)) else "")
		"upgrade_stone", "dice_stone", "mirror_crystal": return str(data.get(str(item.type), {}).get("name", "?"))
	return "?"


# --- Acting --------------------------------------------------------------------------

## A hero's item action from the client: equip / identify / cleanse / drink /
## throw / drop, `value` the bag slot (99 = the weapon in hand).
func act(id: int, action: String, value: int, target: Vector2 = Vector2.INF) -> void:
	var player: Dictionary = game.players.get(id, {})
	if player.is_empty() or int(player.get("hp", 0)) <= 0 or not player.has("inventory"): return
	match action:
		"inv_equip": _equip(player, value)
		"inv_identify": _identify(player, value)
		"inv_cleanse": _cleanse(player, value)
		"inv_drink": _drink(id, player, value)
		"inv_throw": _throw(id, player, value, target)
		"inv_drop": _drop(player, value)
		"inv_unequip": _unequip(player, value)
		"inv_use": _use(id, player, value)
		"inv_upgrade": _upgrade(player, value)
		"inv_reroll": _reroll(player, value)


func _slot(player: Dictionary, value: int) -> Dictionary:
	for slot: String in SLOT_CODES:
		if value == int(SLOT_CODES[slot]): return player.inventory.get(slot, {})
	var bag: Array = player.inventory.bag
	return bag[value] if value >= 0 and value < bag.size() else {}


## True when `value` names an equipment slot, not a bag place.
func _is_equipped_code(value: int) -> bool:
	return SLOT_CODES.values().has(value)


func _spend(player: Dictionary, type: String) -> bool:
	var bag: Array = player.inventory.bag
	for index in range(bag.size()):
		if str(bag[index].type) == type:
			bag[index].count = int(bag[index].count) - 1
			if int(bag[index].count) <= 0: bag.remove_at(index)
			return true
	return false


func _equip(player: Dictionary, value: int) -> void:
	var item := _slot(player, value)
	if _is_equipped_code(value) or item.is_empty() or str(item.type) not in ["weapon", "gear"]: return
	var slot := ItemRules.slot_of(item)
	if slot.is_empty(): return
	if slot == "weapon":
		var spec := ItemRules.weapon(str(item.id))
		if str(spec.get("class", "")) != str(player.get("class_id", "")):
			note(player, "Nur für %s." % str(game.balance.get("classes", {}).get(str(spec.get("class", "")), {}).get("name", "eine andere Klasse")))
			return
	var held: Dictionary = player.inventory.get(slot, {})
	if ItemRules.stuck(held):
		note(player, "Verflucht! %s lässt sich nicht ablegen. Ein Fluchbrecherstein hilft." % ("Die Waffe" if slot == "weapon" else "Das Stück"))
		return
	if held.is_empty(): player.inventory.bag.remove_at(value)
	else: player.inventory.bag[value] = held
	player.inventory[slot] = item
	var first_look: bool = not bool(item.get("identified", false))
	item.identified = true
	equip_apply(player)
	if first_look and not str(item.get("curse", "")).is_empty():
		var rules := ItemRules.curse(str(item.curse))
		note(player, "VERFLUCHT: %s. %s" % [str(rules.get("name", "")), str(rules.get("text", ""))])
		game.add_fx("curse", Vector2(player.pos), 30.0)
	else: note(player, "Angelegt: " + name_of(item))


## Takes a piece of armour, a ring or an amulet off (into the bag), unless a curse holds it.
func _unequip(player: Dictionary, value: int) -> void:
	if value == EQUIPPED or not _is_equipped_code(value): return
	var item := _slot(player, value)
	if item.is_empty(): return
	if ItemRules.stuck(item):
		note(player, "Verflucht! Das Stück lässt sich nicht ablegen. Ein Fluchbrecherstein hilft.")
		return
	if player.inventory.bag.size() >= int(data.get("bag", 12)):
		note(player, "Inventar voll.")
		return
	player.inventory.bag.append(item)
	player.inventory[ItemRules.slot_of(item)] = {}
	equip_apply(player)
	note(player, "Abgenommen: " + name_of(item))


func _identify(player: Dictionary, value: int) -> void:
	var item := _slot(player, value)
	if item.is_empty() or str(item.type) not in ["weapon", "gear", "potion"]: return
	if str(item.type) in ["weapon", "gear"] and bool(item.get("identified", false)): return
	if str(item.type) == "potion" and known.has(str(item.potion)): return
	if not _spend(player, "crystal"):
		note(player, "Dafür brauchst du einen Identifizierungskristall.")
		return
	if str(item.type) == "potion":
		_learn(player, str(item.potion))
		return
	item.identified = true
	var curse_id := str(item.get("curse", ""))
	note(player, "%s: %s" % [name_of(item), "Verflucht! " + str(ItemRules.curse(curse_id).get("text", "")) if not curse_id.is_empty() else "kein Fluch."])
	game.add_fx("identify", Vector2(player.pos), 24.0)


func _cleanse(player: Dictionary, value: int) -> void:
	var item := _slot(player, value)
	if item.is_empty() or str(item.type) not in ["weapon", "gear"]: return
	if str(item.get("curse", "")).is_empty() or bool(item.get("blessed", false)) or not bool(item.get("identified", false)):
		note(player, "Auf diesem Stück liegt kein bekannter Fluch.")
		return
	if not _spend(player, "stone"):
		note(player, "Dafür brauchst du einen Fluchbrecherstein.")
		return
	item.blessed = true
	if _is_equipped_code(value): equip_apply(player)
	var blessing: Dictionary = ItemRules.curse(str(item.curse)).get("blessing", {})
	note(player, "Fluch gebrochen! Segen: %s. %s" % [str(blessing.get("name", "")), str(blessing.get("text", ""))])
	game.add_fx("cleanse", Vector2(player.pos), 34.0)


## Aufwertungsstein on a weapon or piece of gear: +1 stage; on a known, unbroken
## curse it fails with fail_chance and the stage drops instead. Shows the piece.
func _upgrade(player: Dictionary, value: int) -> void:
	var item := _slot(player, value)
	if item.is_empty() or str(item.type) not in ["weapon", "gear"]: return
	var rules: Dictionary = data.get("stage", {})
	if ItemRules.stage(item) >= int(rules.get("max", 3)):
		note(player, "Höher geht es nicht.")
		return
	if not _spend(player, "upgrade_stone"):
		note(player, "Dafür brauchst du einen Aufwertungsstein.")
		return
	item.identified = true
	var cursed := not str(item.get("curse", "")).is_empty() and not bool(item.get("blessed", false))
	if cursed and _rng.randf() < float(data.get("upgrade_stone", {}).get("fail_chance", 0.5)):
		item.stage = maxi(int(rules.get("min", -3)), ItemRules.stage(item) - 1)
		note(player, "Der Fluch frisst den Stein: %s" % name_of(item))
	else:
		item.stage = ItemRules.stage(item) + 1
		note(player, "Aufgewertet: %s" % name_of(item))
	if _is_equipped_code(value): equip_apply(player)
	game.add_fx("identify", Vector2(player.pos), 24.0)


## Würfelstein: the piece's stage is rolled anew (-3..+3, every value alike). Shows the piece.
func _reroll(player: Dictionary, value: int) -> void:
	var item := _slot(player, value)
	if item.is_empty() or str(item.type) not in ["weapon", "gear"]: return
	if not _spend(player, "dice_stone"):
		note(player, "Dafür brauchst du einen Würfelstein.")
		return
	var rules: Dictionary = data.get("stage", {})
	item.identified = true
	item.stage = _rng.randi_range(int(rules.get("min", -3)), int(rules.get("max", 3)))
	note(player, "Neu gewürfelt: %s" % name_of(item))
	if _is_equipped_code(value): equip_apply(player)
	game.add_fx("identify", Vector2(player.pos), 24.0)


## Uses a consumable from the bag: drinks a potion, breaks a clone seal, looks into a mirror crystal.
func _use(id: int, player: Dictionary, value: int) -> void:
	var item := _slot(player, value)
	if item.is_empty() or _is_equipped_code(value): return
	match str(item.type):
		"potion": _drink(id, player, value)
		"clone_seal":
			var rare := bool(item.get("rare", false))
			_take_one(player, value)
			var spec: Dictionary = data.get("clone_seal", {})
			summon_clone(id, player, float(spec.get("clone_time_rare", 35)) if rare else float(spec.get("clone_time", 20)))
		"mirror_crystal":
			var unknown: Array = []
			for held: Dictionary in player.inventory.bag:
				if str(held.type) == "potion" and not known.has(str(held.potion)) and not unknown.has(str(held.potion)): unknown.append(str(held.potion))
			if unknown.is_empty():
				note(player, "Kein unbekannter Trank im Inventar.")
				return
			_take_one(player, value)
			for kind: String in unknown: known[kind] = true
			note(player, ("Der Spiegel zeigt %d Tränke." % unknown.size()) + _learn_last())
			game.add_fx("identify", Vector2(player.pos), 30.0)


## Takes one of a stack (or the item) out of bag place `value`.
func _take_one(player: Dictionary, value: int) -> void:
	var item := _slot(player, value)
	item.count = int(item.get("count", 1)) - 1
	if int(item.count) <= 0: player.inventory.bag.remove_at(value)


## A clone of the hero fights for `time` s: enemies near it chase it (the
## mirror-image decoy of hero_skills.gd) and it shoots at the nearest enemy.
func summon_clone(id: int, player: Dictionary, time: float) -> void:
	# a world with its own clone (story worlds) calls that one
	if game.has_method("summon_clone"):
		game.summon_clone(id, player, time)
		return
	var side := -1.0 if Vector2(player.get("aim", Vector2.RIGHT)).x >= 0.0 else 1.0
	var at := Vector2(player.pos) + Vector2(side * 44.0, 6.0)
	game.hero_skills._zone({"kind": "decoy", "pos": at, "radius": 260.0, "time": time, "owner": id, "look": str(player.get("class_id", ""))})
	player.clone = {"pos": at, "time": time, "cool": 0.3}
	note(player, "Ein Klon kämpft %d s mit dir." % int(time))
	game.add_fx("cleanse", at, 30.0)


## Learning a potion colour for the whole team (crystal, drinking or throwing).
func _learn(player: Dictionary, kind: String) -> void:
	if known.has(kind): return
	known[kind] = true
	var colour: String = str(data.get("potion_colors", {}).get(str(colors.get(kind, "")), "TRANK"))
	note(player, ("%s ist ein %s." % [colour, str(data.potions[kind].get("name", ""))]) + _learn_last())


## When only one potion kind is still unknown it needs no test: it is learned too
## (gameplay review R5). Returns the hint for the note ("" when nothing was learned).
func _learn_last() -> String:
	var left: Array = []
	for kind: String in data.get("potions", {}):
		if not known.has(kind): left.append(kind)
	if left.size() != 1: return ""
	var last := str(left[0])
	known[last] = true
	return " Damit bleibt eine Farbe: %s ist ein %s." % [str(data.get("potion_colors", {}).get(str(colors.get(last, "")), "TRANK")), str(data.potions[last].get("name", ""))]


func _take_potion(player: Dictionary, value: int) -> Dictionary:
	var item := _slot(player, value)
	if item.is_empty() or str(item.type) != "potion": return {}
	var kind := str(item.potion)
	item.count = int(item.count) - 1
	if int(item.count) <= 0: player.inventory.bag.remove_at(value)
	return {"kind": kind, "spec": data.potions.get(kind, {})}


func _drink(id: int, player: Dictionary, value: int) -> void:
	var taken := _take_potion(player, value)
	if taken.is_empty(): return
	var kind: String = taken.kind
	var spec: Dictionary = taken.spec
	_learn(player, kind)
	var effects = game.player_effects
	match kind:
		"healing": player.hp = mini(int(player.max_hp), int(player.hp) + int(spec.get("heal", 4)))
		"strength": effects.apply(player, "strength", float(spec.get("time", 20)), float(spec.get("value", 1.4)))
		"haste": effects.apply(player, "haste", float(spec.get("time", 15)), float(spec.get("value", 1.35)))
		"shield": _add_shield(player, int(spec.get("charges", 2)), int(spec.get("max_charges", 99)))
		"regeneration": effects.apply(player, "regen", float(spec.get("time", 18)), float(spec.get("every", 3)))
		"aftershock", "chainlight":
			for key: String in spec.get("effects", {}): player.augments[key] = float(player.augments.get(key, 0.0)) + float(spec.effects[key])
			PerkRules.rebuild(player, game.balance)
		"fire": effects.apply(player, "burn", float(spec.get("time", 4)), 1.0)
		# slower for a while but no weaker blows (items.json ice.slow)
		"ice": effects.apply(player, "slow", float(spec.get("time", 6)), float(spec.get("slow", 0.75)))
		"blind":
			effects.apply(player, "blind", float(spec.get("time", 10)), 1.0)
			# monsters near the drinker lose his track (story worlds: story_items.gd lose_track)
			if game.has_method("lose_track"): game.lose_track(player, spec)
		"poison": effects.apply(player, "poison", float(spec.get("time", 5)), 1.0)
		"explosion":
			game.add_fx("potion_blast", Vector2(player.pos), float(spec.get("radius", 92)))
			game._damage_player(id, int(spec.get("self_damage", 3)), Vector2.RIGHT.rotated(_rng.randf() * TAU))
			# an emergency nova: the blast also hits the monsters round the drinker (drink_damage)
			if float(spec.get("drink_damage", 0)) > 0.0:
				for enemy: Dictionary in _enemies_near(Vector2(player.pos), float(spec.get("radius", 92))):
					game._damage_enemy(enemy, float(spec.drink_damage), (Vector2(enemy.pos) - Vector2(player.pos)).normalized(), id)
	# a harmful potion's after-effect: a while immune to its elements once its own harm is
	# over (items.json after / after_time / after_delay; worlds without immunity skip it)
	if spec.has("after") and effects.has_method("immunity"):
		effects.immunity(Array(spec.after), float(spec.get("after_time", 0)), float(spec.get("after_delay", 0)))
	game.add_fx("drink", Vector2(player.pos), 20.0, {"color": str(colors.get(kind, "red"))})


## A thrown potion bursts where the hero aims (within throw_range, stopped by walls).
func _throw(id: int, player: Dictionary, value: int, target: Vector2) -> void:
	var taken := _take_potion(player, value)
	if taken.is_empty(): return
	var kind: String = taken.kind
	var spec: Dictionary = taken.spec
	_learn(player, kind)
	var from: Vector2 = player.pos
	if not target.is_finite(): target = from + Vector2(player.get("aim", Vector2.RIGHT)) * 160.0
	var offset := target - from
	if offset.length() > float(data.get("throw_range", 320)): target = from + offset.normalized() * float(data.get("throw_range", 320))
	var point := from
	var steps := maxi(1, int(from.distance_to(target) / 8.0))
	for step in range(1, steps + 1):
		var next := from.lerp(target, float(step) / float(steps))
		# a world without crypt rooms (story worlds) checks its own walls
		var blocked: bool = game.segment_blocked(point, next) if game.has_method("segment_blocked") else Dungeon.segment_blocked(point, next, 4.0, game.current_layout)
		if blocked: break
		point = next
	game.add_fx("potion_throw", point, float(spec.get("radius", 60)), {"fx": from.x, "fy": from.y, "color": str(colors.get(kind, "red")), "potion": kind})
	var radius := float(spec.get("radius", 60))
	match kind:
		"healing", "regeneration", "strength", "haste", "shield":
			# heroes in the radius; strength, haste and shield weaker than drunk
			for other: Dictionary in game.players.values():
				if int(other.hp) <= 0 or Vector2(other.pos).distance_to(point) > radius: continue
				_bless(other, kind, spec)
			# the clone and the companions in the radius (story worlds: story_items.gd bless_allies)
			if game.has_method("bless_allies"): game.bless_allies(kind, spec, point, radius)
		"fire": game.boss_moves.hero_pool(point, {"style": "fire", "radius": radius, "time": float(spec.get("pool_time", 5)), "dps": float(spec.get("dps", 2)), "status": "burn"}, id)
		"poison": game.boss_moves.hero_pool(point, {"style": "poison", "radius": radius, "time": float(spec.get("pool_time", 5)), "dps": float(spec.get("dps", 1.5)), "status": "poison"}, id)
		"ice":
			for enemy: Dictionary in _enemies_near(point, radius): game.perk_combat._status(enemy, "freeze", 1, float(spec.get("freeze", 2.5)), id)
			# frost is frost: the water it lands on freezes to Glatteis like every other frost source
			# (src/combat/elements.gd); the story worlds have no crypt pools and no `elements`
			if game.get("elements") != null: game.elements.frost_at(point, radius, id)
		"blind":
			for enemy: Dictionary in _enemies_near(point, radius):
				var daze := float(spec.get("daze", 4)) * (0.35 if bool(enemy.get("boss", false)) or bool(enemy.get("miniboss", false)) else 1.0)
				if game.has_method("daze"): game.daze(enemy, daze)
				else: enemy.hitstun = maxf(float(enemy.get("hitstun", 0.0)), daze)
		"explosion":
			for enemy: Dictionary in _enemies_near(point, radius): game._damage_enemy(enemy, float(spec.get("damage", 12)), (Vector2(enemy.pos) - point).normalized(), id)
		"aftershock":
			for index in range(3):
				var spot := point + Vector2.from_angle(TAU * index / 3.0) * 34.0
				game.add_fx("potion_blast", spot, float(spec.get("radius", 50)))
				for enemy: Dictionary in _enemies_near(spot, float(spec.get("radius", 50))): game._damage_enemy(enemy, float(spec.get("damage", 3)), (Vector2(enemy.pos) - spot).normalized(), id)
		"chainlight":
			var hit := 0
			for enemy: Dictionary in _enemies_near(point, radius):
				if hit >= 4: break
				game._damage_enemy(enemy, float(spec.get("damage", 4)), Vector2.ZERO, id)
				game.perk_combat._event("storm", point, Vector2(enemy.pos))
				hit += 1
		_: note(player, "Der Trank zerplatzt wirkungslos.")


## A thrown good potion on one hero in its radius (gameplay review R7): healing
## throw_heal LP, regeneration as drunk, strength / haste throw_value for throw_time
## s, shield throw_charges charges.
func _bless(other: Dictionary, kind: String, spec: Dictionary) -> void:
	var effects = game.player_effects
	match kind:
		"healing": other.hp = mini(int(other.max_hp), int(other.hp) + int(spec.get("throw_heal", 2)))
		"regeneration": effects.apply(other, "regen", float(spec.get("time", 18)), float(spec.get("every", 3)))
		"strength": effects.apply(other, "strength", float(spec.get("throw_time", 12)), float(spec.get("throw_value", 1.25)))
		"haste": effects.apply(other, "haste", float(spec.get("throw_time", 10)), float(spec.get("throw_value", 1.25)))
		"shield": _add_shield(other, int(spec.get("throw_charges", 1)), int(spec.get("max_charges", 99)))


## Shield charges onto a hero, up to `cap` (items.json shield.max_charges: no
## endless stacking); charges above the cap from elsewhere are not taken away.
func _add_shield(player: Dictionary, charges: int, cap: int) -> void:
	var runtime: Dictionary = player.get("perk_runtime", {})
	var held := int(runtime.get("shield", 0))
	runtime.shield = maxi(held, mini(cap, held + charges))
	player.perk_runtime = runtime


func _enemies_near(point: Vector2, radius: float) -> Array:
	return game.enemies.filter(func(enemy: Dictionary) -> bool: return float(enemy.hp) > 0 and Vector2(enemy.pos).distance_to(point) <= radius + float(enemy.radius))


func _drop(player: Dictionary, value: int) -> void:
	var item := _slot(player, value)
	if value == EQUIPPED or item.is_empty(): return
	player.inventory.bag.remove_at(value)
	game.chests.drop_item(item, Vector2(player.pos) + Vector2(player.get("aim", Vector2.RIGHT)) * 28.0)
	note(player, "Abgelegt: " + name_of(item))


## Puts the weapon's values and effects on the hero and rebuilds the stats.
func equip_apply(player: Dictionary) -> void:
	ItemRules.set_base(player)
	PerkRules.rebuild(player, game.balance)


# --- Curses over time ----------------------------------------------------------------

## Thorns under the cursed hero, the blood toll, the thorn ward of the blessing
## (each equipped piece keeps its own timer); the clones of clone seals shoot.
func step(delta: float) -> void:
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		if int(player.get("hp", 0)) <= 0 or not player.has("inventory"): continue
		_step_clone(id, player, delta)
		for item: Dictionary in ItemRules.equipped(player): _step_curse(id, player, item, delta)


func _step_clone(id: int, player: Dictionary, delta: float) -> void:
	var clone: Dictionary = player.get("clone", {})
	if clone.is_empty(): return
	clone.time = float(clone.time) - delta
	if float(clone.time) <= 0.0:
		player.erase("clone")
		return
	clone.cool = float(clone.cool) - delta
	if float(clone.cool) > 0.0: return
	clone.cool = float(data.get("clone_seal", {}).get("fire_every", 0.6))
	var target: Dictionary = {}
	var distance := 320.0
	for enemy: Dictionary in game.enemies:
		var gap: float = Vector2(enemy.pos).distance_to(clone.pos)
		if float(enemy.hp) > 0 and gap < distance:
			target = enemy
			distance = gap
	if target.is_empty(): return
	var aim := (Vector2(target.pos) - Vector2(clone.pos)).normalized()
	var style := "magic" if str(player.get("class_id", "")) == "mage" else "arrow"
	game._add_bullet(Vector2(clone.pos) + aim * 12.0, aim * 520.0, id, float(player.get("damage", 1.0)) * 0.6,
		{"style": style, "pierce": 0, "bounces": 0, "hit_ids": [], "primary": false, "no_steer": true, "life": 0.7, "distance": 0.0})


func _step_curse(id: int, player: Dictionary, item: Dictionary, delta: float) -> void:
	var curse_id := str(item.get("curse", ""))
	if curse_id.is_empty() or not bool(item.get("identified", false)): return
	var rules := ItemRules.curse(curse_id)
	var blessed: bool = bool(item.get("blessed", false))
	var every := float(rules.get("blessing", {}).get("every", 0.0)) if blessed else float(rules.get("every", 0.0))
	if every <= 0.0: return
	var timers: Dictionary = player.get("curse_timers", {})
	var key := str(item.get("uid", 0))
	timers[key] = float(timers.get(key, every)) - delta
	player.curse_timers = timers
	if float(timers[key]) > 0.0: return
	timers[key] = every
	match curse_id:
		"thorns":
			if blessed:
				var target: Dictionary = {}
				var distance := 260.0
				for enemy: Dictionary in game.enemies:
					var gap: float = Vector2(enemy.pos).distance_to(player.pos)
					if float(enemy.hp) > 0 and gap < distance:
						target = enemy
						distance = gap
				if not target.is_empty(): game.boss_moves.hero_strike(Vector2(target.pos), 30.0, 0.35, float(rules.blessing.get("damage", 5)), "spikes", id)
			else: game.boss_moves.strike_at(Vector2(player.pos), 26.0, float(rules.get("warn", 0.7)), int(rules.get("damage", 1)), "spikes")
		"bloodthirst":
			if not blessed: game.dot_player(id, int(rules.get("damage", 1)), "blood")


## A hero attacked: the burning blade sometimes burns its bearer.
func on_attack(player: Dictionary) -> void:
	var item: Dictionary = player.get("inventory", {}).get("weapon", {})
	if str(item.get("curse", "")) != "burning_blade" or bool(item.get("blessed", false)): return
	var rules := ItemRules.curse("burning_blade")
	if _rng.randf() < float(rules.get("chance", 0.18)): game.player_effects.apply(player, "burn", float(rules.get("time", 2.0)), 1.0)


# --- Views for clients ---------------------------------------------------------------

## One item as a hero sees it: name, rarity colour, sprite, count and lines of text.
func view(item: Dictionary) -> Dictionary:
	if item.is_empty(): return {}
	var result := {"uid": int(item.uid), "type": str(item.type), "name": name_of(item), "count": int(item.get("count", 1))}
	match str(item.type):
		"weapon":
			var spec := ItemRules.weapon(str(item.id))
			var rarity: Dictionary = data.rarities.get(str(spec.get("rarity", "common")), {})
			result.merge({"sprite": "res://assets/sprites/" + str(spec.sprite) + ".png", "rarity": str(spec.get("rarity", "common")), "rarity_label": str(rarity.get("label", "")), "color": str(rarity.get("color", "c9c0b6")), "slot": "weapon",
				"class": str(spec.get("class", "")), "identified": bool(item.get("identified", false)), "cursed": ItemRules.stuck(item), "blessed": bool(item.get("blessed", false)),
				"element": ItemRules.element_of(item) if bool(item.get("identified", false)) else ""})
			var lines: Array[String] = []
			var known_weapon := bool(item.get("identified", false))
			lines.append("SCHADEN %s · %.2f s" % [str(snappedf(float(spec.get("damage", 0)) * (ItemRules.stage_factor(item) if known_weapon else 1.0), 0.1)), float(spec.get("interval", 0.4)) * (ItemRules.stage_factor(item, true) if known_weapon else 1.0)])
			if known_weapon and ItemRules.stage(item) != 0: lines.append("STUFE " + ItemRules.stage_text(item))
			if bool(item.get("identified", false)):
				var effects: Array[String] = []
				for key: String in spec.get("effects", {}): effects.append(_effect_name(key))
				if not effects.is_empty(): lines.append("EFFEKT: " + ", ".join(effects))
				if not _element_line(item).is_empty(): lines.append(_element_line(item))
				var curse_id := str(item.get("curse", ""))
				if not curse_id.is_empty():
					var rules := ItemRules.curse(curse_id)
					if bool(item.get("blessed", false)): lines.append("SEGEN: " + str(rules.blessing.get("text", "")))
					else: lines.append("FLUCH: " + str(rules.get("text", "")))
				else: lines.append("Kein Fluch.")
			else:
				lines.append("Unbekannt: Wirkung und Fluch zeigt ein Kristall oder das Anlegen.")
				lines.append(_risk_line("weapon"))
			result.lines = lines
		"potion":
			var kind := str(item.potion)
			result.merge({"sprite": "res://assets/sprites/items/potion_%s.png" % str(colors.get(kind, "red")), "rarity": "common", "color": "d3bfa9", "identified": known.has(kind),
				"element": ItemRules.element_of(item) if known.has(kind) else ""})
			result.lines = ["TRINKEN: " + str(data.potions[kind].get("drink", "")), "WERFEN: " + str(data.potions[kind].get("throw", ""))] if known.has(kind) else ["Unbekannter Trank. Ein Kristall verrät ihn, oder du probierst ihn.", _unknown_line()]
			if known.has(kind) and not _element_line(item).is_empty(): result.lines.append(_element_line(item))
		"gear":
			var spec := ItemRules.gear(str(item.id))
			var rarity: Dictionary = data.rarities.get(str(spec.get("rarity", "common")), {})
			var known_piece := bool(item.get("identified", false))
			result.merge({"sprite": "res://assets/sprites/" + str(spec.sprite) + ".png", "rarity": str(spec.get("rarity", "common")), "rarity_label": str(rarity.get("label", "")) + " · " + str(data.get("slots", {}).get(str(spec.slot), "")),
				"color": str(rarity.get("color", "c9c0b6")), "slot": str(spec.slot), "identified": known_piece, "cursed": ItemRules.stuck(item), "blessed": bool(item.get("blessed", false)),
				"element": ItemRules.element_of(item) if known_piece else ""})
			var lines: Array[String] = []
			lines.append(_stats_text(spec.get("stats", {}), ItemRules.stage_factor(item) if known_piece else 1.0))
			if known_piece:
				var effects: Array[String] = []
				for key: String in spec.get("effects", {}): effects.append(_effect_name(key))
				if not effects.is_empty(): lines.append("EFFEKT: " + ", ".join(effects))
				if not _element_line(item).is_empty(): lines.append(_element_line(item))
				lines.append("STUFE %s" % (ItemRules.stage_text(item) if ItemRules.stage(item) != 0 else "0"))
				var curse_id := str(item.get("curse", ""))
				if not curse_id.is_empty():
					var rules := ItemRules.curse(curse_id)
					if bool(item.get("blessed", false)): lines.append("SEGEN: " + str(rules.blessing.get("text", "")))
					else: lines.append("FLUCH: " + str(rules.get("text", "")))
				else: lines.append("Kein Fluch.")
			else:
				lines.append("Unbekannt: Stufe und Fluch zeigt ein Kristall oder das Anlegen.")
				lines.append(_risk_line(str(spec.slot)))
			result.lines = lines
		"crystal", "stone", "clone_seal", "upgrade_stone", "dice_stone", "mirror_crystal":
			var spec: Dictionary = data.get(str(item.type), {})
			var colours := {"crystal": "8fd8e6", "stone": "edbf75", "clone_seal": "e57a6a", "upgrade_stone": "7ed66f", "dice_stone": "e9e2d4", "mirror_crystal": "b38cf0"}
			result.merge({"sprite": "res://assets/sprites/" + str(spec.get("sprite", "")) + ".png", "rarity": "rare", "color": str(colours.get(str(item.type), "d3bfa9")), "identified": true,
				"usable": str(item.type) in ["clone_seal", "mirror_crystal"]})
			result.lines = [str(spec.get("text", ""))]
	return result


## A share as signed percent: "+10 %", "−5 %".
func _percent(share: float) -> String:
	var value := roundi(share * 100.0)
	return ("+%d %%" % value) if value >= 0 else ("-%d %%" % absi(value))


## "FLUCHRISIKO 60 %": the chance a found piece of `slot` carries a curse
## (items.json curse_by_slot; gameplay review R5).
func _risk_line(slot: String) -> String:
	return "FLUCHRISIKO %d %%" % roundi(float(data.get("curse_by_slot", {}).get(slot, data.get("curse_chance", 0.6))) * 100.0)


## "NOCH UNBEKANNT: 7 SORTEN, 3 SCHADEN BEIM TRINKEN": the potion kinds not learned
## yet and how many of them hurt their drinker (items.json potions.*.harmful).
func _unknown_line() -> String:
	var left := 0
	var harmful := 0
	for kind: String in data.get("potions", {}):
		if known.has(kind): continue
		left += 1
		if bool(data.potions[kind].get("harmful", false)): harmful += 1
	return "NOCH UNBEKANNT: %d SORTEN, %d SCHADEN BEIM TRINKEN" % [left, harmful]


## The stats of a piece in words ("SCHADEN +10 % · +2 LP"), scaled by its stage.
func _stats_text(stats: Dictionary, factor: float) -> String:
	var parts: Array[String] = []
	if stats.has("max_hp"): parts.append("+%d LP" % roundi(float(stats.max_hp) * factor))
	if stats.has("damage"): parts.append("SCHADEN " + _percent(float(stats.damage) * factor))
	if stats.has("rate"): parts.append("ANGRIFFE " + _percent(float(stats.rate) * factor))
	if stats.has("speed"): parts.append("TEMPO " + _percent(float(stats.speed) * factor))
	if stats.has("cooldown"): parts.append("ABKLINGEN " + _percent(float(stats.cooldown) * factor))
	return " · ".join(parts) if not parts.is_empty() else "Keine Werte, nur Wirkung."


func _effect_name(key: String) -> String:
	for perk: Dictionary in game.balance.get("perks", []):
		if str(perk.get("id", "")) == key: return str(perk.get("name", key))
	return key.to_upper()


## "ELEMENT: FEUER" for an item of an element (items.json elements.name), "" for none.
func _element_line(item: Dictionary) -> String:
	var element := ItemRules.element_of(item)
	if element.is_empty(): return ""
	return "ELEMENT: " + str(data.get("elements", {}).get(element, {}).get("name", element.to_upper()))


## The hero's inventory for clients.
func snapshot(player: Dictionary) -> Dictionary:
	if not player.has("inventory"): return {}
	var bag: Array = []
	for item: Dictionary in player.inventory.bag: bag.append(view(item))
	return {"weapon": view(player.inventory.weapon), "armor": view(player.inventory.get("armor", {})), "ring": view(player.inventory.get("ring", {})), "amulet": view(player.inventory.get("amulet", {})),
		"bag": bag, "size": int(data.get("bag", 12)), "note": str(player.get("item_note", "")), "notes": int(player.get("item_notes", 0)), "note_log": (player.get("item_note_log", []) as Array).duplicate(), "clone": float(player.get("clone", {}).get("time", 0.0)),
		"sealed": int(player.get("sealed_skill", -1)), "dim": bool(player.get("dim", false))}
