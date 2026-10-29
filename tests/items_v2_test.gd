extends SceneTree
## Item system 2 in the crypt (docs/ITEM-SYSTEM-V2.de.md, src/items/*):
## armour, ring and amulet slots with fifteen pieces in five rarities and their
## own sprites; every weapon and piece has a stage -3..+3 rolled around its
## mean (lower when cursed) that scales its values; gear can be cursed like
## weapons (never the burning blade), sticks until a stone breaks the curse and
## can be taken off otherwise; the Aufwertungsstein raises a stage (may fail on
## a cursed piece), the Würfelstein rerolls it, the Spiegelkristall reveals the
## bag's potions, the Klonsiegel calls a fighting clone; every floor has fixed
## finds and mini guardians drop rare pieces.

const Game = preload("res://src/game.gd")
const ItemRules = preload("res://src/items/item_rules.gd")
const CryptSave = preload("res://src/save/crypt_save.gd")
var checked := 0
var failures: Array[String] = []
var game
var inv


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ITEMS_V2_FAIL: ", label)


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
	game.requested_seed = 5151
	game._begin_run()
	inv = game.inventory
	_test_catalog()
	_test_rolls()
	_test_equip_gear()
	_test_stones()
	_test_seal_and_mirror()
	_test_fixed_finds()
	print("ITEMS_V2 checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)


func _fresh(class_id: String) -> Dictionary:
	var hero: Dictionary = game.players[1]
	game.HeroClass.apply(hero, class_id, game.balance)
	inv.start_kit(hero)
	hero.effects = {}
	hero.hp = int(hero.max_hp)
	return hero


func _act(action: String, value: int) -> void:
	inv.act(1, action, value)


func _test_catalog() -> void:
	var gear: Array = inv.data.gear
	var slots := {}
	var rarities := {}
	var missing: Array[String] = []
	for entry: Dictionary in gear:
		slots[str(entry.slot)] = int(slots.get(str(entry.slot), 0)) + 1
		rarities[str(entry.rarity)] = true
		if not ResourceLoader.exists("res://assets/sprites/" + str(entry.sprite) + ".png"): missing.append(str(entry.id))
	check(int(slots.get("armor", 0)) == 5 and int(slots.get("ring", 0)) == 5 and int(slots.get("amulet", 0)) == 5, "five armours, rings and amulets")
	check(rarities.size() == 5, "gear in all five rarities")
	check(missing.is_empty(), "every piece has its own sprite (%s)" % str(missing))
	for kind: String in ["clone_seal", "upgrade_stone", "dice_stone", "mirror_crystal"]:
		check(ResourceLoader.exists("res://assets/sprites/" + str(inv.data[kind].sprite) + ".png"), "%s has a sprite" % kind)
	var hero := _fresh("swordsman")
	check(hero.inventory.has("armor") and hero.inventory.has("ring") and hero.inventory.has("amulet"), "a hero has armour, ring and amulet slots")
	check(int(hero.inventory.weapon.stage) == 0 and bool(hero.inventory.weapon.identified), "the starting weapon is known at stage 0")


func _test_rolls() -> void:
	var cursed := {"armor": 0, "ring": 0, "amulet": 0}
	var count := {"armor": 0, "ring": 0, "amulet": 0}
	var blade := 0
	var plain_stages := 0.0
	var plain_n := 0
	var cursed_stages := 0.0
	var cursed_n := 0
	var low := 0
	var high := 0
	for index in range(600):
		var piece: Dictionary = inv._roll_gear(0.5, "common")
		var slot := ItemRules.slot_of(piece)
		count[slot] += 1
		if not str(piece.curse).is_empty():
			cursed[slot] += 1
			cursed_stages += float(piece.stage)
			cursed_n += 1
		else:
			plain_stages += float(piece.stage)
			plain_n += 1
		if str(piece.curse) == "burning_blade": blade += 1
		low = mini(low, int(piece.stage))
		high = maxi(high, int(piece.stage))
		check(not bool(piece.identified), "found gear is unknown") if index == 0 else null
	check(blade == 0, "gear never carries the burning blade")
	check(absf(float(cursed.armor) / count.armor - 0.5) < 0.12 and absf(float(cursed.amulet) / count.amulet - 0.35) < 0.12, "curse chances follow the slot (armour %.2f, amulet %.2f)" % [float(cursed.armor) / count.armor, float(cursed.amulet) / count.amulet])
	check(plain_stages / plain_n > cursed_stages / cursed_n + 1.0, "cursed pieces roll lower stages (%.2f vs %.2f)" % [plain_stages / plain_n, cursed_stages / cursed_n])
	check(low >= -3 and high <= 3 and low < 0 and high > 0, "stages stay within -3..+3 and reach both sides")
	var mimic: Array = inv.roll("mimic", 5, "swordsman")
	check(not mimic.is_empty() and str(ItemRules.spec_of(mimic[0]).rarity) in ["rare", "epic", "legendary"], "a Mimik drops a rare or better weapon or piece")


func _test_equip_gear() -> void:
	var hero := _fresh("swordsman")
	var max_before := int(hero.max_hp)
	var vest: Dictionary = inv.make_gear("dragon_scale", false, "", 2)
	inv.add(hero, vest)
	_act("inv_equip", 0)
	check(str(hero.inventory.armor.get("id", "")) == "dragon_scale" and hero.inventory.bag.is_empty(), "armour goes into its slot")
	check(bool(hero.inventory.armor.identified), "wearing it shows what it is")
	# +6 HP at stage +2: 6 x 1.3 = 8 (rounded)
	check(int(hero.max_hp) == max_before + 8, "its stats count, scaled by the stage (%d -> %d)" % [max_before, int(hero.max_hp)])
	var damage := float(hero.damage)
	_act("inv_unequip", 98)
	check(hero.inventory.armor.is_empty() and hero.inventory.bag.size() == 1 and int(hero.max_hp) == max_before, "armour comes off into the bag")
	check(float(hero.damage) < damage, "its damage share goes with it")
	# a cursed ring sticks until a stone breaks it
	var ring: Dictionary = inv.make_gear("ring_haste", false, "sluggish", -1)
	inv.add(hero, ring)
	var speed := float(hero.speed)
	_act("inv_equip", 1)
	check(float(hero.speed) < speed, "the ring's curse slows the hero")
	_act("inv_unequip", 97)
	check(not hero.inventory.ring.is_empty(), "a cursed ring cannot come off")
	inv.add(hero, inv.make_stack("stone"))
	_act("inv_cleanse", 97)
	check(bool(hero.inventory.ring.blessed) and float(hero.speed) > speed, "the stone turns the ring's curse into its blessing")
	_act("inv_unequip", 97)
	check(hero.inventory.ring.is_empty(), "then it can come off")
	# a weapon's stage scales its hits
	hero = _fresh("swordsman")
	var plain := float(hero.damage)
	inv.add(hero, inv.make_weapon("short_sword", true, "", 3))
	_act("inv_equip", 0)
	check(is_equal_approx(float(hero.damage), plain * 1.45), "a weapon at +3 hits 45 %% harder (%.2f vs %.2f)" % [float(hero.damage), plain])
	var view: Dictionary = inv.snapshot(hero)
	check(view.has("armor") and view.has("ring") and view.has("amulet") and str(view.weapon.name).contains("+3"), "the snapshot shows all four slots and the stage")


func _test_stones() -> void:
	var hero := _fresh("swordsman")
	inv.add(hero, inv.make_gear("ring_might", false, "", 0))
	inv.add(hero, inv.make_stack("upgrade_stone", "", 2))
	_act("inv_upgrade", 0)
	var ring: Dictionary = hero.inventory.bag[0]
	check(int(ring.stage) == 1 and bool(ring.identified), "an upgrade stone raises the stage by one and shows the piece")
	inv.add(hero, inv.make_stack("dice_stone", "", 30))
	var seen := {}
	for index in range(30):
		_act("inv_reroll", 0)
		seen[int(hero.inventory.bag[0].stage)] = true
	check(seen.size() >= 5 and seen.keys().all(func(s: int) -> bool: return s >= -3 and s <= 3), "the dice stone rerolls the stage across -3..+3 (%s)" % str(seen.keys()))
	# on a cursed piece the stone can fail: the stage drops instead
	var drops := 0
	var rises := 0
	for index in range(40):
		hero = _fresh("swordsman")
		inv.add(hero, inv.make_gear("ring_might", true, "night", 0))
		inv.add(hero, inv.make_stack("upgrade_stone"))
		_act("inv_upgrade", 0)
		if int(hero.inventory.bag[0].stage) < 0: drops += 1
		else: rises += 1
	check(drops > 5 and rises > 5, "on a cursed piece the stone sometimes fails (%d down, %d up)" % [drops, rises])


func _test_seal_and_mirror() -> void:
	var hero := _fresh("archer")
	inv.add(hero, inv.make_stack("potion", "healing"))
	inv.add(hero, inv.make_stack("potion", "fire"))
	inv.add(hero, inv.make_stack("mirror_crystal"))
	inv.known.clear()
	_act("inv_use", 2)
	check(inv.known.has("healing") and inv.known.has("fire"), "the mirror crystal shows every potion in the bag")
	var seal: Dictionary = inv.make_stack("clone_seal")
	seal.erase("rare")
	inv.add(hero, seal)
	var place: int = hero.inventory.bag.find(seal)
	_act("inv_use", place)
	check(not hero.get("clone", {}).is_empty() and is_equal_approx(float(hero.clone.time), 20.0), "a clone seal calls a clone for 20 s")
	var decoys: Array = game.hero_skills.zones.filter(func(z: Dictionary) -> bool: return str(z.kind) == "decoy" and str(z.get("look", "")) == "archer")
	check(not decoys.is_empty(), "the clone draws enemies like a mirror image, in the archer's look")
	game.enemies.clear()
	var enemy: Dictionary = game._spawn_enemy("skeleton", Vector2(hero.clone.pos) + Vector2(120, 0)) if game.has_method("_spawn_enemy") else {}
	if enemy.is_empty():
		game.enemies.append({"id": 9001, "pos": Vector2(hero.clone.pos) + Vector2(120, 0), "hp": 50.0, "max_hp": 50.0, "radius": 10.0, "kind": "skeleton"})
	var shots := (game.bullets as Array).size()
	hero.clone.cool = 0.0
	inv.step(0.02)
	check((game.bullets as Array).size() > shots, "the clone shoots at the nearest enemy")
	hero.clone.time = 0.01
	inv.step(0.02)
	check(not hero.has("clone"), "the clone fades when its time runs out")
	game.enemies.clear()
	check(not CryptSave.plain_player(hero).has("clone"), "a clone is not saved")


func _test_fixed_finds() -> void:
	var one: Array = inv.floor_finds(1)
	var two: Array = inv.floor_finds(2)
	check(one.size() == 1 and str(one[0].type) == "crystal", "every floor has a crystal")
	check(two.size() == 2 and two.any(func(i: Dictionary) -> bool: return str(i.type) == "stone"), "every second floor adds a curse-breaker stone")
	var rare := 0
	for index in range(30):
		var drop: Dictionary = inv.guardian_drop(3, "mage")
		if str(ItemRules.spec_of(drop).get("rarity", "")) in ["rare", "epic", "legendary"]: rare += 1
	check(rare == 30, "a mini guardian always drops a rare or better piece")
