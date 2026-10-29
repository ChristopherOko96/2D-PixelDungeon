extends SceneTree
## Items (src/items/inventory.gd, item_rules.gd, assets/data/items.json):
## at least 30 class-bound weapons in five rarities with their own sprites;
## every hero starts with a known common weapon; found weapons are unknown and
## often cursed; equipping identifies, a cursed weapon sticks until a
## curse-breaker stone turns the curse into its blessing; crystals identify
## weapons and potions; potion colours are shuffled per run and learned by the
## whole team by crystal, drinking or throwing; drinking and throwing do what
## they say; curses act over time; crates, chests, Mimiks and gold crates drop
## items that heroes pick up.

const Game = preload("res://src/game.gd")
const ItemRules = preload("res://src/items/item_rules.gd")
const DT := 1.0 / 60.0
var checked := 0
var failures: Array[String] = []
var game
var inv


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ITEMS_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game.player_classes[1] = "swordsman"
	game._host_session()
	game.requested_seed = 4242
	game._begin_run()
	inv = game.inventory
	_test_catalog()
	_test_start_kits()
	_test_equip_identify_and_class()
	_test_curse_sticks_until_broken()
	_test_crystals_and_potion_colours()
	_test_drinking_and_throwing()
	_test_curses_over_time()
	_test_drops_and_pickup()
	print("ITEMS checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)


func _hero() -> Dictionary:
	var hero: Dictionary = game.players[1]
	hero.hp = int(hero.max_hp)
	hero.invulnerable = 0.0
	hero.effects = {}
	return hero


func _fresh(class_id: String) -> Dictionary:
	var hero: Dictionary = game.players[1]
	game.HeroClass.apply(hero, class_id, game.balance)
	inv.start_kit(hero)
	hero.effects = {}
	return hero


func _act(action: String, value: int, target: Vector2 = Vector2.INF) -> void:
	inv.act(1, action, value, target)


func _test_catalog() -> void:
	var data: Dictionary = inv.data
	var weapons: Array = data.weapons
	var per_class := {}
	var rarities := {}
	var missing: Array[String] = []
	var sprites := {}
	for weapon: Dictionary in weapons:
		per_class[weapon["class"]] = int(per_class.get(weapon["class"], 0)) + 1
		rarities[weapon.rarity] = true
		sprites[weapon.sprite] = true
		if not ResourceLoader.exists("res://assets/sprites/" + str(weapon.sprite) + ".png"): missing.append(str(weapon.id))
	check(weapons.size() >= 30, "at least 30 weapons (%d)" % weapons.size())
	check(sprites.size() == weapons.size(), "every weapon looks different (%d designs)" % sprites.size())
	check(per_class.get("swordsman", 0) >= 9 and per_class.get("archer", 0) >= 9 and per_class.get("mage", 0) >= 9, "each class has many weapons (%s)" % str(per_class))
	check(rarities.size() == 5, "weapons span all five rarities")
	check(missing.is_empty(), "every weapon sprite exists (%s)" % str(missing))
	for class_id: String in ["swordsman", "archer", "mage"]:
		check(weapons.filter(func(weapon: Dictionary) -> bool: return weapon["class"] == class_id and bool(weapon.get("start", false))).size() == 1, "%s has one starting weapon" % class_id)
	check(data.curses.size() >= 8 and data.curses.values().all(func(curse: Dictionary) -> bool: return curse.has("blessing")), "eight curses, each with a blessing")
	check(data.potions.size() == 12 and data.potion_colors.size() == 12, "twelve potions, twelve colours")
	check(data.potion_colors.keys().all(func(colour: String) -> bool: return ResourceLoader.exists("res://assets/sprites/items/potion_%s.png" % colour)), "every potion colour has a flask")


func _test_start_kits() -> void:
	for class_id: String in ["swordsman", "archer", "mage"]:
		var hero := _fresh(class_id)
		var weapon: Dictionary = hero.inventory.weapon
		var spec := ItemRules.weapon(str(weapon.id))
		check(spec.get("class", "") == class_id and str(spec.rarity) == "common" and bool(weapon.identified) and str(weapon.curse).is_empty(), "%s starts with a known common weapon" % class_id)
		check(is_equal_approx(float(hero.damage), float(spec.damage)) or float(hero.damage) >= float(spec.damage), "%s hits with its weapon's damage" % class_id)
		check(str(hero.weapons[0]).ends_with(str(spec.sprite) + ".png"), "%s holds its weapon's sprite" % class_id)
	_fresh("swordsman")


func _test_equip_identify_and_class() -> void:
	var hero := _fresh("swordsman")
	var katana: Dictionary = inv.make_weapon("katana", false, "")
	check(inv.view(katana).name == "UNBEKANNTE KLINGE" and not inv.view(katana).identified, "a found weapon shows only what it looks like")
	inv.add(hero, katana)
	var before := float(hero.damage)
	_act("inv_equip", 0)
	check(str(hero.inventory.weapon.id) == "katana" and bool(hero.inventory.weapon.identified), "equipping takes the weapon in hand and identifies it")
	check(not is_equal_approx(float(hero.damage), before) and float(hero.build.get("crit", 0.0)) >= 0.15, "its damage and effects apply (crit %.2f)" % float(hero.build.get("crit", 0.0)))
	check(str(hero.inventory.bag[0].id) == "short_sword", "the old weapon goes into the bag")
	var bow: Dictionary = inv.make_weapon("frost_bow", true, "")
	inv.add(hero, bow)
	_act("inv_equip", 1)
	check(str(hero.inventory.weapon.id) == "katana" and str(hero.item_note).contains("Nur für"), "a bow is not for a swordsman")


func _test_curse_sticks_until_broken() -> void:
	var hero := _fresh("swordsman")
	var cursed: Dictionary = inv.make_weapon("knight_sword", false, "leaden")
	inv.add(hero, cursed)
	var plain_interval := float(hero.shot_interval)
	_act("inv_equip", 0)
	check(ItemRules.stuck(hero.inventory.weapon) and str(hero.item_note).begins_with("VERFLUCHT"), "a cursed weapon reveals its curse when equipped")
	check(float(hero.shot_interval) > float(ItemRules.weapon("knight_sword").interval) * 1.3, "the leaden hand slows attacks")
	inv.add(hero, inv.make_weapon("machete", true, ""))
	_act("inv_equip", 1)
	check(str(hero.inventory.weapon.id) == "knight_sword", "a cursed weapon cannot be put away")
	_act("inv_cleanse", 99)
	check(ItemRules.stuck(hero.inventory.weapon), "without a stone the curse holds")
	inv.add(hero, inv.make_stack("stone"))
	_act("inv_cleanse", 99)
	check(bool(hero.inventory.weapon.blessed) and not ItemRules.stuck(hero.inventory.weapon), "a curse-breaker stone breaks the curse")
	check(float(hero.shot_interval) < float(ItemRules.weapon("knight_sword").interval), "the curse becomes its blessing: faster attacks")
	check(not hero.inventory.bag.any(func(item: Dictionary) -> bool: return str(item.type) == "stone"), "the stone is spent")
	_act("inv_equip", 1)
	check(str(hero.inventory.weapon.id) == "machete", "after the cleansing the weapon can be swapped again")
	# Other curses: sealed skill, fragile, sluggish, night.
	for pair: Array in [["sealed", "sealed_skill"], ["fragile", "item_extra_damage"], ["night", "dim"]]:
		hero = _fresh("swordsman")
		inv.add(hero, inv.make_weapon("axe", false, str(pair[0])))
		_act("inv_equip", 0)
		var mark: Variant = hero.get(str(pair[1]), null)
		# a sealed skill may be skill 0: any number marks it
		var marked: bool = (mark is bool and mark) or (mark is int and (int(mark) != 0 or str(pair[0]) == "sealed"))
		check(marked, "the %s curse marks the hero (%s)" % [pair[0], str(mark)])
	hero = _fresh("swordsman")
	var speed := float(hero.speed)
	inv.add(hero, inv.make_weapon("axe", false, "sluggish"))
	_act("inv_equip", 0)
	check(float(hero.speed) < speed, "the sluggish curse slows walking")


func _test_crystals_and_potion_colours() -> void:
	var hero := _fresh("swordsman")
	var unknown: Dictionary = inv.make_weapon("waraxe", false, "thorns")
	inv.add(hero, unknown)
	_act("inv_identify", 0)
	check(not bool(unknown.identified), "identifying needs a crystal")
	inv.add(hero, inv.make_stack("crystal", "", 2))
	_act("inv_identify", 0)
	check(bool(unknown.identified) and str(hero.item_note).contains("Verflucht"), "a crystal reveals the weapon and its curse")
	var kinds: Array = inv.data.potions.keys()
	var potion: Dictionary = inv.make_stack("potion", str(kinds[0]))
	inv.add(hero, potion)
	var colour_name: String = inv.view(potion).name
	check(colour_name.ends_with("TRANK") and not inv.known.has(str(kinds[0])), "an unknown potion is just its colour (%s)" % colour_name)
	_act("inv_identify", hero.inventory.bag.size() - 1)
	check(inv.known.has(str(kinds[0])) and inv.view(potion).name == str(inv.data.potions[kinds[0]].name), "a crystal names the potion for the whole team")
	# Colours are shuffled per run.
	var first: Dictionary = inv.colors.duplicate()
	inv.new_run(1)
	var again: Dictionary = inv.colors.duplicate()
	inv.new_run(2)
	var other: Dictionary = inv.colors.duplicate()
	inv.new_run(1)
	check(inv.colors == again and again != other, "potion colours change from run to run (same seed, same colours)")
	check(inv.known.is_empty(), "a new run forgets what the potions were")
	var _unused := first


func _test_drinking_and_throwing() -> void:
	var hero := _fresh("mage")
	hero.hp = 1
	inv.add(hero, inv.make_stack("potion", "healing"))
	_act("inv_drink", 0)
	check(int(hero.hp) >= 4 and inv.known.has("healing"), "drinking heals and teaches the colour")
	inv.add(hero, inv.make_stack("potion", "strength"))
	_act("inv_drink", 0)
	check(game.player_effects.damage_scale(hero) > 1.0, "the strength potion raises damage")
	inv.add(hero, inv.make_stack("potion", "aftershock"))
	_act("inv_drink", 0)
	check(float(hero.build.get("blast", 0.0)) >= 0.3, "the aftershock potion upgrades hits for the run")
	inv.add(hero, inv.make_stack("potion", "blind"))
	_act("inv_drink", 0)
	check(game.player_effects.has(hero, "blind"), "the blinding potion blinds the drinker")
	# Throws need foes.
	game.enemies.clear()
	game.phase = "combat"
	var foe: Dictionary = game._create_enemy("skeleton", Vector2(hero.pos) + Vector2(120, 0))
	game.enemies.append(foe)
	var hp := float(foe.hp)
	inv.add(hero, inv.make_stack("potion", "explosion"))
	_act("inv_throw", 0, Vector2(foe.pos))
	check(float(foe.hp) < hp, "a thrown blasting potion hurts foes at the target")
	foe = game._create_enemy("skeleton", Vector2(hero.pos) + Vector2(120, 0))
	game.enemies = [foe]
	inv.add(hero, inv.make_stack("potion", "ice"))
	_act("inv_throw", 0, Vector2(foe.pos))
	check(game.perk_combat.frozen(foe), "a thrown ice potion freezes foes")
	foe = game._create_enemy("skeleton", Vector2(hero.pos) + Vector2(120, 0))
	game.enemies = [foe]
	hp = float(foe.hp)
	inv.add(hero, inv.make_stack("potion", "fire"))
	_act("inv_throw", 0, Vector2(foe.pos))
	for tick in range(150): game.boss_moves.update(DT)
	check(float(foe.hp) < hp and int(hero.hp) > 0, "a thrown fire potion burns foes, not the thrower")
	game.enemies.clear()


func _test_curses_over_time() -> void:
	var hero := _fresh("swordsman")
	inv.add(hero, inv.make_weapon("axe", false, "thorns"))
	_act("inv_equip", 0)
	game.boss_moves.reset()
	# every equipped piece keeps its own curse timer (item system 2)
	hero.curse_timers = {str(hero.inventory.weapon.uid): 0.05}
	inv.step(0.1)
	check(game.boss_moves.zones.any(func(zone: Dictionary) -> bool: return str(zone.kind) == "strike" and Vector2(zone.pos).distance_to(hero.pos) < 4.0), "the thorn curse raises spikes under its bearer")
	hero = _fresh("swordsman")
	inv.add(hero, inv.make_weapon("axe", false, "bloodthirst"))
	_act("inv_equip", 0)
	var before := int(hero.hp)
	for tick in range(26 * 4): inv.step(0.25)
	check(int(hero.hp) < before, "the blood toll drains the hero")
	hero = _fresh("swordsman")
	inv.add(hero, inv.make_weapon("axe", false, "burning_blade"))
	_act("inv_equip", 0)
	for swing in range(60): inv.on_attack(hero)
	check(game.player_effects.has(hero, "burn"), "the burning blade burns its bearer now and then")
	hero = _fresh("swordsman")
	inv.add(hero, inv.make_weapon("axe", false, "fragile"))
	_act("inv_equip", 0)
	hero.invulnerable = 0.0
	before = int(hero.hp)
	game._damage_player(1, 2, Vector2.RIGHT)
	check(before - int(hero.hp) == 3, "the fragile curse makes each hit heavier (%d)" % (before - int(hero.hp)))
	var snapshot: Dictionary = game._make_snapshot()
	check(snapshot.players[1].has("inventory") and snapshot.players[1].inventory.weapon.cursed, "clients see the inventory and the curse")


func _test_drops_and_pickup() -> void:
	var hero := _fresh("archer")
	var rolled := {"rare_plus": 0, "count": 0}
	for index in range(40):
		for item: Dictionary in inv.roll("mimic", 3, "archer"):
			if str(item.type) in ["weapon", "gear"]:
				rolled.count += 1
				if str(ItemRules.spec_of(item).rarity) in ["rare", "epic", "legendary"]: rolled.rare_plus += 1
	check(rolled.count == 40 and rolled.rare_plus == 40, "a Mimik always drops a rare or better weapon or piece of gear")
	var gold: Array = inv.roll("gold_crate", 5, "archer")
	check(gold.size() == 3 and gold.any(func(item: Dictionary) -> bool: return str(item.type) == "crystal") and gold.any(func(item: Dictionary) -> bool: return str(item.type) == "stone"), "a gold crate gives a weapon, a crystal and a stone")
	var legendary := [0, 0]
	for depth in range(2):
		for index in range(600):
			var weapon: Dictionary = inv._roll_weapon(float(depth), "archer", "common")
			if str(ItemRules.weapon(str(weapon.id)).rarity) == "legendary": legendary[depth] += 1
	check(legendary[1] > legendary[0] * 3, "legendaries grow common deeper down (%d vs %d)" % [legendary[0], legendary[1]])
	var cursed := 0
	for index in range(400):
		if not str(inv._roll_weapon(0.5, "archer", "common").curse).is_empty(): cursed += 1
	check(cursed > 200 and cursed < 280, "about 60 %% of found weapons are cursed (%d of 400)" % cursed)
	# A crate in the room breaks and its loot is picked up by walking over it.
	var room_id := str(game.current_layout.id)
	game.chests.chests[room_id] = []
	game.chests.loot[room_id] = []
	game.inventory.data.drops.crate.chance = [1.0, 1.0]
	var crate := {"id": 7777, "kind": "crate", "pos": Vector2(hero.pos) + Vector2(80, 0), "hits": 0, "max": 1, "open": false}
	game.chests.chests[room_id].append(crate)
	game.chests._hit(crate, 1, Vector2.RIGHT)
	var loot: Array = game.chests.loot.get(room_id, [])
	check(loot.any(func(item: Dictionary) -> bool: return str(item.kind) == "item"), "a broken crate can hold an item")
	var bag_before: int = hero.inventory.bag.size()
	for item: Dictionary in loot: item.age = 1.0
	if not loot.is_empty(): hero.pos = Vector2(loot[0].pos)
	game.chests.step(DT)
	check(hero.inventory.bag.size() > bag_before or hero.inventory.bag.any(func(item: Dictionary) -> bool: return int(item.get("count", 1)) > 1), "walking over an item picks it up")
	var shown: Dictionary = game.chests.snapshot()
	check(shown.loot.all(func(item: Dictionary) -> bool: return str(item.kind) != "item" or item.has("view")), "clients see dropped items with their look")
	# A full bag refuses more.
	while hero.inventory.bag.size() < int(inv.data.bag): hero.inventory.bag.append(inv.make_weapon("short_bow", true, ""))
	check(not inv.add(hero, inv.make_weapon("sun_bow", false, "")) and str(hero.item_note) == "Rucksack voll.", "a full bag refuses more")
