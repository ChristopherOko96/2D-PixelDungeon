extends RefCounted
## Items of a run on the host (data assets/data/items.json, rules item_rules.gd).
## Every hero carries one weapon and a bag (player.inventory = {weapon, bag}).
## Items: weapons (class-bound, five rarities, found unidentified and often
## cursed), potions (known only by colour until identified; colours shuffled
## per run, knowledge shared by the team), identification crystals and
## curse-breaker stones (consumables stack). Heroes act through `act`: equip,
## identify (spends a crystal), cleanse (spends a stone; the curse turns into
## its blessing), drink, throw (at the mouse point) and drop. A cursed weapon,
## once equipped, cannot be swapped until its curse is broken. Also rolls the
## loot of crates, chests, Mimiks and gold crates, and runs the curses that act
## over time (thorns, blood toll, the burning blade).

const ItemRules = preload("res://src/items/item_rules.gd")
const PerkRules = preload("res://src/perk_rules.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
## Slot value meaning "the weapon in hand" for identify / cleanse.
const EQUIPPED := 99

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
	player.inventory = {"weapon": make_weapon(str(spec.get("id", "")), true, "") if not spec.is_empty() else {}, "bag": []}
	player.augments = {}
	player.item_note = ""
	# The note counter keeps running so a new note after a class change still shows.
	player.item_notes = int(player.get("item_notes", 0))
	equip_apply(player)


# --- Making items --------------------------------------------------------------------

func make_weapon(id: String, identified: bool, curse: String) -> Dictionary:
	var item := {"uid": _next_uid, "type": "weapon", "id": id, "identified": identified, "curse": curse, "blessed": false}
	if curse == "sealed": item.seal = _rng.randi_range(0, 3)
	_next_uid += 1
	return item


func make_stack(type: String, potion: String = "", count: int = 1) -> Dictionary:
	var item := {"uid": _next_uid, "type": type, "count": count}
	if type == "potion": item.potion = potion
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
		"weapon": return _roll_weapon(depth, class_id, str(spec.get("min_rarity", "common")))
		"potion":
			var potions: Array = data.get("potions", {}).keys()
			return make_stack("potion", str(potions[_rng.randi_range(0, potions.size() - 1)]))
	return make_stack(chosen)


func _roll_weapon(depth: float, class_id: String, minimum: String) -> Dictionary:
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
	if pool.is_empty(): pool = data.get("weapons", []).filter(func(entry: Dictionary) -> bool: return str(entry.rarity) == rarity)
	var spec: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
	var curse := ""
	if _rng.randf() < float(data.get("curse_chance", 0.6)):
		var curses: Array = data.get("curses", {}).keys()
		curse = str(curses[_rng.randi_range(0, curses.size() - 1)])
	return make_weapon(str(spec.id), false, curse)


# --- The bag -------------------------------------------------------------------------

## Puts an item in the hero's bag (consumables stack). False when it is full.
func add(player: Dictionary, item: Dictionary) -> bool:
	var bag: Array = player.inventory.bag
	if str(item.type) != "weapon":
		for held: Dictionary in bag:
			if str(held.type) == str(item.type) and str(held.get("potion", "")) == str(item.get("potion", "")):
				held.count = int(held.count) + int(item.get("count", 1))
				note(player, "Gefunden: " + name_of(item))
				return true
	if bag.size() >= int(data.get("bag", 12)):
		note(player, "Rucksack voll.")
		return false
	bag.append(item)
	note(player, "Gefunden: " + name_of(item))
	return true


func note(player: Dictionary, text: String) -> void:
	player.item_note = text
	player.item_notes = int(player.get("item_notes", 0)) + 1


## The name a hero sees: unknown weapons and potions show only what they look like.
func name_of(item: Dictionary) -> String:
	match str(item.get("type", "")):
		"weapon":
			var spec := ItemRules.weapon(str(item.id))
			if not bool(item.get("identified", false)): return str(spec.get("unknown_name", "UNBEKANNTE WAFFE"))
			var title := str(spec.get("name", "WAFFE"))
			if bool(item.get("blessed", false)): return title + " · " + str(ItemRules.curse(str(item.curse)).get("blessing", {}).get("name", ""))
			if not str(item.get("curse", "")).is_empty(): return title + " · " + str(ItemRules.curse(str(item.curse)).get("name", "VERFLUCHT"))
			return title
		"potion":
			var kind := str(item.get("potion", ""))
			if known.has(kind): return str(data.potions[kind].get("name", "TRANK"))
			return str(data.get("potion_colors", {}).get(str(colors.get(kind, "red")), "TRANK"))
		"crystal": return str(data.get("crystal", {}).get("name", "KRISTALL"))
		"stone": return str(data.get("stone", {}).get("name", "STEIN"))
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


func _slot(player: Dictionary, value: int) -> Dictionary:
	if value == EQUIPPED: return player.inventory.weapon
	var bag: Array = player.inventory.bag
	return bag[value] if value >= 0 and value < bag.size() else {}


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
	if value == EQUIPPED or item.is_empty() or str(item.type) != "weapon": return
	var spec := ItemRules.weapon(str(item.id))
	if str(spec.get("class", "")) != str(player.get("class_id", "")):
		note(player, "Nur für %s." % str(game.balance.get("classes", {}).get(str(spec.get("class", "")), {}).get("name", "eine andere Klasse")))
		return
	var held: Dictionary = player.inventory.weapon
	if ItemRules.stuck(held):
		note(player, "Verflucht! Die Waffe lässt sich nicht ablegen. Ein Fluchbrecherstein hilft.")
		return
	player.inventory.bag[value] = held
	player.inventory.weapon = item
	var first_look: bool = not bool(item.get("identified", false))
	item.identified = true
	equip_apply(player)
	if first_look and not str(item.get("curse", "")).is_empty():
		var rules := ItemRules.curse(str(item.curse))
		note(player, "VERFLUCHT: %s. %s" % [str(rules.get("name", "")), str(rules.get("text", ""))])
		game.add_fx("curse", Vector2(player.pos), 30.0)
	else: note(player, "Angelegt: " + name_of(item))


func _identify(player: Dictionary, value: int) -> void:
	var item := _slot(player, value)
	if item.is_empty() or str(item.type) not in ["weapon", "potion"]: return
	if str(item.type) == "weapon" and bool(item.get("identified", false)): return
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
	if item.is_empty() or str(item.type) != "weapon": return
	if str(item.get("curse", "")).is_empty() or bool(item.get("blessed", false)) or not bool(item.get("identified", false)):
		note(player, "Auf dieser Waffe liegt kein bekannter Fluch.")
		return
	if not _spend(player, "stone"):
		note(player, "Dafür brauchst du einen Fluchbrecherstein.")
		return
	item.blessed = true
	if item == player.inventory.weapon: equip_apply(player)
	var blessing: Dictionary = ItemRules.curse(str(item.curse)).get("blessing", {})
	note(player, "Fluch gebrochen! Segen: %s. %s" % [str(blessing.get("name", "")), str(blessing.get("text", ""))])
	game.add_fx("cleanse", Vector2(player.pos), 34.0)


## Learning a potion colour for the whole team (crystal, drinking or throwing).
func _learn(player: Dictionary, kind: String) -> void:
	if known.has(kind): return
	known[kind] = true
	var colour: String = str(data.get("potion_colors", {}).get(str(colors.get(kind, "")), "TRANK"))
	note(player, "%s ist ein %s." % [colour, str(data.potions[kind].get("name", ""))])


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
		"shield":
			var runtime: Dictionary = player.get("perk_runtime", {})
			runtime.shield = int(runtime.get("shield", 0)) + int(spec.get("charges", 2))
			player.perk_runtime = runtime
		"regeneration": effects.apply(player, "regen", float(spec.get("time", 18)), float(spec.get("every", 3)))
		"aftershock", "chainlight":
			for key: String in spec.get("effects", {}): player.augments[key] = float(player.augments.get(key, 0.0)) + float(spec.effects[key])
			PerkRules.rebuild(player, game.balance)
		"fire": effects.apply(player, "burn", float(spec.get("time", 4)), 1.0)
		"ice":
			effects.apply(player, "slow", float(spec.get("time", 6)), 0.6)
			effects.apply(player, "weak", float(spec.get("time", 6)), 0.5)
		"blind": effects.apply(player, "blind", float(spec.get("time", 10)), 1.0)
		"poison": effects.apply(player, "poison", float(spec.get("time", 5)), 1.0)
		"explosion":
			game.add_fx("potion_blast", Vector2(player.pos), 50.0)
			game._damage_player(id, int(spec.get("self_damage", 3)), Vector2.RIGHT.rotated(_rng.randf() * TAU))
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
		if Dungeon.segment_blocked(point, next, 4.0, game.current_layout): break
		point = next
	game.add_fx("potion_throw", point, float(spec.get("radius", 60)), {"fx": from.x, "fy": from.y, "color": str(colors.get(kind, "red")), "potion": kind})
	var radius := float(spec.get("radius", 60))
	match kind:
		"healing", "regeneration":
			for other: Dictionary in game.players.values():
				if int(other.hp) <= 0 or Vector2(other.pos).distance_to(point) > radius: continue
				if kind == "healing": other.hp = mini(int(other.max_hp), int(other.hp) + int(spec.get("throw_heal", 2)))
				else: game.player_effects.apply(other, "regen", float(spec.get("time", 18)), float(spec.get("every", 3)))
		"fire": game.boss_moves.hero_pool(point, {"style": "fire", "radius": radius, "time": float(spec.get("pool_time", 5)), "dps": float(spec.get("dps", 2)), "status": "burn"}, id)
		"poison": game.boss_moves.hero_pool(point, {"style": "poison", "radius": radius, "time": float(spec.get("pool_time", 5)), "dps": float(spec.get("dps", 1.5)), "status": "poison"}, id)
		"ice":
			for enemy: Dictionary in _enemies_near(point, radius): game.perk_combat._status(enemy, "freeze", 1, float(spec.get("freeze", 2.5)), id)
		"blind":
			for enemy: Dictionary in _enemies_near(point, radius):
				enemy.hitstun = maxf(float(enemy.get("hitstun", 0.0)), float(spec.get("daze", 4)) * (0.35 if bool(enemy.get("boss", false)) or bool(enemy.get("miniboss", false)) else 1.0))
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

## Thorns under the cursed hero, the blood toll, the thorn ward of the blessing.
func step(delta: float) -> void:
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		if int(player.get("hp", 0)) <= 0 or not player.has("inventory"): continue
		var item: Dictionary = player.inventory.weapon
		var curse_id := str(item.get("curse", ""))
		if curse_id.is_empty() or not bool(item.get("identified", false)): continue
		var rules := ItemRules.curse(curse_id)
		var blessed: bool = bool(item.get("blessed", false))
		var every := float(rules.get("blessing", {}).get("every", 0.0)) if blessed else float(rules.get("every", 0.0))
		if every <= 0.0: continue
		player.curse_timer = float(player.get("curse_timer", every)) - delta
		if float(player.curse_timer) > 0.0: continue
		player.curse_timer = every
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
			result.merge({"sprite": "res://assets/sprites/" + str(spec.sprite) + ".png", "rarity": str(spec.get("rarity", "common")), "rarity_label": str(rarity.get("label", "")), "color": str(rarity.get("color", "c9c0b6")),
				"class": str(spec.get("class", "")), "identified": bool(item.get("identified", false)), "cursed": ItemRules.stuck(item), "blessed": bool(item.get("blessed", false))})
			var lines: Array[String] = []
			lines.append("SCHADEN %s · %.2f s" % [str(snappedf(float(spec.get("damage", 0)), 0.1)), float(spec.get("interval", 0.4))])
			if bool(item.get("identified", false)):
				var effects: Array[String] = []
				for key: String in spec.get("effects", {}): effects.append(_effect_name(key))
				if not effects.is_empty(): lines.append("EFFEKT: " + ", ".join(effects))
				var curse_id := str(item.get("curse", ""))
				if not curse_id.is_empty():
					var rules := ItemRules.curse(curse_id)
					if bool(item.get("blessed", false)): lines.append("SEGEN: " + str(rules.blessing.get("text", "")))
					else: lines.append("FLUCH: " + str(rules.get("text", "")))
				else: lines.append("Kein Fluch.")
			else: lines.append("Unbekannt: Wirkung und Fluch zeigt ein Kristall oder das Anlegen.")
			result.lines = lines
		"potion":
			var kind := str(item.potion)
			result.merge({"sprite": "res://assets/sprites/items/potion_%s.png" % str(colors.get(kind, "red")), "rarity": "common", "color": "d3bfa9", "identified": known.has(kind)})
			result.lines = ["TRINKEN: " + str(data.potions[kind].get("drink", "")), "WERFEN: " + str(data.potions[kind].get("throw", ""))] if known.has(kind) else ["Unbekannter Trank. Ein Kristall verrät ihn, oder du probierst ihn."]
		"crystal", "stone":
			var spec: Dictionary = data.get(str(item.type), {})
			result.merge({"sprite": "res://assets/sprites/" + str(spec.get("sprite", "")) + ".png", "rarity": "rare", "color": "8fd8e6" if str(item.type) == "crystal" else "edbf75", "identified": true})
			result.lines = [str(spec.get("text", ""))]
	return result


func _effect_name(key: String) -> String:
	for perk: Dictionary in game.balance.get("perks", []):
		if str(perk.get("id", "")) == key: return str(perk.get("name", key))
	return key.to_upper()


## The hero's inventory for clients.
func snapshot(player: Dictionary) -> Dictionary:
	if not player.has("inventory"): return {}
	var bag: Array = []
	for item: Dictionary in player.inventory.bag: bag.append(view(item))
	return {"weapon": view(player.inventory.weapon), "bag": bag, "size": int(data.get("bag", 12)), "note": str(player.get("item_note", "")), "notes": int(player.get("item_notes", 0)),
		"sealed": int(player.get("sealed_skill", -1)), "dim": bool(player.get("dim", false))}
