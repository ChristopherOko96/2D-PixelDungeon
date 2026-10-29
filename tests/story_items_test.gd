extends SceneTree
## Item system 2 in the story worlds (src/hero/story_items.gd): the crypt's
## item rules run in the Hell-Dungeon and the Frostgruft. A class hero carries
## the bag and four equipment slots; the first chest of a floor holds its fixed
## finds; gear raises the hearts and the damage; a cursed piece seals a skill
## or makes hits heavier; potions heal, strengthen and shield; a thrown
## explosion hurts monsters; the clone seal calls the world's clone; burning
## gear sets monsters alight; a full bag leaves finds on the floor; the bag
## travels to the next floor and into a save.

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")
const StorySave = preload("res://src/save/story_save.gd")

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("STORY_ITEMS_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_world(HellScene, "hell")
	await _test_world(FrostScene, "frost")
	print("STORY_ITEMS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _open(scene: PackedScene) -> Node:
	var game: Node = scene.instantiate()
	game.class_id = "mage"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	return game


func _bag(game: Node) -> Array:
	return game.story_items.players[1].inventory.bag


func _index(game: Node, type: String, id: String = "") -> int:
	var bag := _bag(game)
	for i in range(bag.size()):
		if str(bag[i].type) == type and (id == "" or str(bag[i].get("id", bag[i].get("potion", ""))) == id): return i
	return -1


func _mob(game: Node, offset: Vector2) -> Dictionary:
	var m := {"p": Vector2(game.player.x, game.player.y) + offset, "hp": 400.0, "max": 400.0, "cy": 30.0, "r": 30.0, "spawn": 0.0, "kind": "gross",
		"k": Vector2.ZERO, "hit": 0.0, "def": {"material": "bone"}, "face": Vector2.LEFT, "room": game.state.room}
	game.mobs.append(m)
	return m


func _test_world(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene)
	var items: Node = game.story_items
	check(items != null and game.inventory_panel != null, "%s: a class hero carries the bag and its window" % world)
	var view: Dictionary = items.view()
	check(view.has("weapon") and view.has("armor") and view.has("ring") and view.has("amulet"), "%s: four equipment slots" % world)
	# the first chest of a floor holds its fixed finds
	items.loot("chest", Vector2(game.player.x, game.player.y))
	check(_index(game, "crystal") >= 0, "%s: the first chest holds the floor's crystal" % world)
	# gear: hearts and damage
	var hearts := int(game.state.max_hp)
	items.give(items.inventory.make_gear("dragon_scale", true, "", 0), Vector2.ZERO)
	items.act("inv_equip", _index(game, "gear", "dragon_scale"))
	check(int(game.state.max_hp) == hearts + 6, "%s: armour adds its hearts (%d -> %d)" % [world, hearts, int(game.state.max_hp)])
	var damage := CardKit.damage_mult(game)
	items.give(items.inventory.make_gear("ring_might", true, "", 0), Vector2.ZERO)
	items.act("inv_equip", _index(game, "gear", "ring_might"))
	check(CardKit.damage_mult(game) > damage * 1.05, "%s: a ring of might raises the damage" % world)
	items.act("inv_unequip", 98)
	check(int(game.state.max_hp) == hearts, "%s: taking the armour off takes its hearts" % world)
	# a cursed amulet: a sealed skill and heavier hits are the curses' work
	var amulet: Dictionary = items.inventory.make_gear("amulet_life", true, "fragile", 0)
	items.give(amulet, Vector2.ZERO)
	items.act("inv_equip", _index(game, "gear", "amulet_life"))
	game.state.inv = 0.0
	var hp := int(game.state.hp)
	game._hurt("Test", 1)
	check(int(game.state.hp) == hp - 2, "%s: the fragile curse makes a hit cost one more" % world)
	game.state.hp = int(game.state.max_hp)
	# potions: healing, strength, shield
	items.give(items.inventory.make_stack("potion", "healing"), Vector2.ZERO)
	game.state.hp = 2
	items.act("inv_use", _index(game, "potion", "healing"))
	check(int(game.state.hp) == 6, "%s: a healing potion heals two hearts" % world)
	items.give(items.inventory.make_stack("potion", "strength"), Vector2.ZERO)
	var before := CardKit.damage_mult(game)
	items.act("inv_use", _index(game, "potion", "strength"))
	check(CardKit.damage_mult(game) > before * 1.3, "%s: a strength potion hits harder for a while" % world)
	items.give(items.inventory.make_stack("potion", "shield"), Vector2.ZERO)
	items.act("inv_use", _index(game, "potion", "shield"))
	game.state.inv = 0.0
	hp = int(game.state.hp)
	game._hurt("Test", 1)
	check(int(game.state.hp) == hp, "%s: a shield potion stops the next hit" % world)
	# a thrown explosion hurts a monster
	var m := _mob(game, Vector2(200, 0))
	items.give(items.inventory.make_stack("potion", "explosion"), Vector2.ZERO)
	items.act("inv_throw", _index(game, "potion", "explosion"), (m.p as Vector2) - Vector2(0, 30))
	check(float(m.hp) < 400.0, "%s: a thrown explosion hurts the monster" % world)
	# burning gear sets monsters alight
	items.give(items.inventory.make_gear("amulet_ember", true, "", 0), Vector2.ZERO)
	items.players[1].inventory.amulet.curse = ""
	items.act("inv_unequip", 96)
	items.act("inv_equip", _index(game, "gear", "amulet_ember"))
	game._damage_mob(m, Vector2.ZERO, 0.1)
	check(float(m.get("burn_t", 0.0)) > 0.0, "%s: the ember amulet sets monsters alight" % world)
	game.mobs.clear()
	# the clone seal calls the world's clone
	var seal: Dictionary = items.inventory.make_stack("clone_seal")
	seal.erase("rare")
	items.give(seal, Vector2.ZERO)
	items.act("inv_use", _index(game, "clone_seal"))
	check(bool(game.state.skill.active) and float(game.state.skill.left) >= 19.0, "%s: the clone seal calls the clone for 20 s" % world)
	# a full bag leaves finds on the floor, picked up on contact
	while _bag(game).size() < 12:
		items.give(items.inventory.make_gear("leather_vest", false, "", 0), Vector2.ZERO)
	items.give(items.inventory.make_gear("ring_storm", true, "", 0), Vector2(game.player.x + 40, game.player.y))
	check(items.floor_items.size() == 1, "%s: a full bag leaves the find on the floor" % world)
	# a find is announced once, by the inventory window, as in the crypt
	game.state.toasts = []
	items.update(0.016)
	check((game.state.toasts as Array).filter(func(t: Dictionary) -> bool: return str(t.text).contains("Rucksack voll")).is_empty(), "%s: an item note is not toasted a second time by the world" % world)
	_bag(game).pop_back()
	items.update(0.016)
	check(items.floor_items.is_empty() and _index(game, "gear", "ring_storm") >= 0, "%s: walking over it picks it up" % world)
	# the bag travels to the next floor and into a save
	var count := _bag(game).size()
	game.load_floor(2, true)
	check(_bag(game).size() == count and not (game.state.get("items", {}) as Dictionary).is_empty(), "%s: the bag goes to the next floor" % world)
	check(StorySave.capture(game).keep.has("items"), "%s: the bag is saved with the run" % world)
	game.queue_free()
	await process_frame
