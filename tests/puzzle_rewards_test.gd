extends SceneTree
## What a solved puzzle pays (docs/WELTBAUER.de.md "Schatz nach Schwierigkeit"):
## - a Schatz chest has a tier from 1 to 3, set by how hard its puzzle or labyrinth is;
## - every tier raises the life cap (heart containers), the higher the more;
## - tier 2 adds an epic find, tier 3 a legendary weapon or armour of the class being played, never cursed;
## - a chest without a tier pays tier 1.

const Contents = preload("res://src/world_kit/room_contents.gd")
const Inventory = preload("res://src/items/inventory.gd")
const ItemRules = preload("res://src/items/item_rules.gd")
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const Pack = preload("res://src/world_kit/world_pack.gd")
const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const CLASSES := ["swordsman", "archer", "mage", "necromancer"]
## Rolls per class: enough that one wrong pick among them would show.
const ROLLS := 40

var checked := 0
var failures: Array[String] = []
var game: Node


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("PUZZLE_REWARD_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(11)
	_test_tiers_pay_more_the_harder()
	_test_chest_without_tier_pays_tier_one()
	_test_legendary_find_fits_the_class()
	_test_puzzle_files_set_a_tier()
	_test_secret_rooms_pay_a_schatz()
	game =KryptaScene.instantiate()
	game.class_id = "archer"
	game.graphics_path = "user://puzzle_rewards_graphics.cfg"
	root.add_child(game)
	await _frames(3)
	await _test_top_tier_raises_life_and_gives_a_legendary()
	game.queue_free()
	await process_frame
	print("PUZZLE_REWARDS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _frames(n: int) -> void:
	for i in range(n):
		if game != null and not game.state.is_empty():
			game.state.inv = 5.0
		await process_frame


func _hoard(tier: int) -> Dictionary:
	var e := {"type": "chest", "state": "", "loot": {"gems": 0}}
	var o := {"kind": "chest", "loot": {"type": "hoard", "tier": tier}}
	if tier <= 0:
		o.loot.erase("tier")
	Contents.finish_chest(e, o, 3, func() -> float: return 0.5)
	return e


func _test_tiers_pay_more_the_harder() -> void:
	# Arrange / Act
	var one := _hoard(1)
	var two := _hoard(2)
	var three := _hoard(3)
	# Assert
	check(int(one.get("hoard_hearts", 0)) >= 1, "tier 1 raises the life cap (%d)" % int(one.get("hoard_hearts", 0)))
	check(int(three.get("hoard_hearts", 0)) > int(one.get("hoard_hearts", 0)), "tier 3 gives more heart containers than tier 1")
	check((two.get("hoard", []) as Array).has("puzzle_epic"), "tier 2 holds an epic find %s" % str(two.get("hoard", [])))
	check((three.get("hoard", []) as Array).has("puzzle_legendary"), "tier 3 holds a legendary find %s" % str(three.get("hoard", [])))
	check(not (one.get("hoard", []) as Array).has("puzzle_legendary"), "tier 1 holds no legendary find")
	check(int(three.loot.gems) > int(one.loot.gems), "tier 3 pays more gold (%d > %d)" % [int(three.loot.gems), int(one.loot.gems)])


func _test_chest_without_tier_pays_tier_one() -> void:
	# Arrange / Act
	var plain := _hoard(0)
	var one := _hoard(1)
	# Assert
	check(plain.get("hoard", []) == one.get("hoard", []) and int(plain.get("hoard_hearts", -1)) == int(one.get("hoard_hearts", -2)), "a Schatz without a tier pays tier 1")


func _test_legendary_find_fits_the_class() -> void:
	for cid: String in CLASSES:
		# Arrange
		var inv := Inventory.new()
		inv.data = ItemRules.data()
		inv.new_run(3)
		var wrong := 0
		var cursed := 0
		var found := 0
		# Act
		for i in range(ROLLS):
			for item: Dictionary in inv.roll("puzzle_legendary", 2, cid):
				found += 1
				var spec: Dictionary = ItemRules.weapon(str(item.id)) if str(item.type) == "weapon" else ItemRules.gear(str(item.id))
				if str(spec.get("rarity", "")) != "legendary" or str(spec.get("class", "")) != cid:
					wrong += 1
				if str(item.get("curse", "")) != "":
					cursed += 1
		# Assert
		check(found == ROLLS, "a %s finds a legendary piece every time (%d of %d)" % [cid, found, ROLLS])
		check(wrong == 0, "every legendary find of a %s is legendary and his own (%d wrong)" % [cid, wrong])
		check(cursed == 0, "a puzzle's legendary find is never cursed (%s: %d)" % [cid, cursed])


## Every puzzle and labyrinth room of the Krypta names the tier of its Schatz.
func _test_puzzle_files_set_a_tier() -> void:
	var dir := "res://assets/data/world_rooms/krypta/"
	for f: String in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
		if str(t.get("role", "")) != "jump":
			continue
		var hoards := (t.objects as Array).filter(func(o: Dictionary) -> bool: return str(o.kind) == "chest" and str((o.get("loot", {}) as Dictionary).get("type", "")) == "hoard")
		check(not hoards.is_empty(), "%s has a Schatz chest" % f)
		for o: Dictionary in hoards:
			var tier := int((o.loot as Dictionary).get("tier", 0))
			check(tier >= 1 and tier <= 3, "%s: its Schatz has a tier from 1 to 3 (%d)" % [f, tier])


## A floor's secret room (behind a secret wall or a plate riddle) holds a Schatz, never a Mimik.
func _test_secret_rooms_pay_a_schatz() -> void:
	# Arrange
	var pack := Pack.new("res://assets/data/krypta_world.json", "res://assets/sprites/krypta/manifest.json")
	var seen := 0
	for run: int in [11, 12, 13, 14, 15, 16]:
		for n in range(1, pack.floor_count() + 1):
			# Act
			var W := RoomFloor.build(n, run, pack)
			if W.is_empty():
				continue
			for r: Dictionary in W.rooms:
				if str(r.gtype) not in ["secret", "hidden"]:
					continue
				for e: Dictionary in W.ents:
					if str(e.type) != "chest" or int(e.get("room", -1)) != int(r.index):
						continue
					seen += 1
					# Assert
					check(e.has("hoard") and int(e.get("hoard_hearts", 0)) >= 1, "E%d run %d: the %s room's chest is a Schatz" % [n, run, r.gtype])
					check(not e.get("mimic", false), "E%d run %d: the %s room's chest never bites" % [n, run, r.gtype])
	check(seen >= 3, "floors have secret rooms with chests (%d)" % seen)


func _test_top_tier_raises_life_and_gives_a_legendary() -> void:
	# Arrange: a tier 3 Schatz before the hero, life below the cap
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true
	game.mobs = []
	game.state.max_hp = 8
	game.state.hp = 8
	var e := _hoard(3)
	e.x = float(game.player.x)
	e.y = float(game.player.y) - 80.0
	e.room = int(game._room_at_world(e.x, e.y))
	game.W.ents.append(e)
	game._index_solids()
	var bag_before := (game.story_items.players[1].inventory.bag as Array).duplicate()
	# Act
	game.act()
	await _frames(2)
	# Assert
	check(int(game.state.max_hp) >= 8 + 2 * int(e.hoard_hearts), "the Schatz raised the life cap (8 -> %d)" % int(game.state.max_hp))
	var found := (game.story_items.players[1].inventory.bag as Array).filter(func(item: Dictionary) -> bool:
		if bag_before.has(item) or str(item.type) not in ["weapon", "gear"]:
			return false
		var spec: Dictionary = ItemRules.weapon(str(item.id)) if str(item.type) == "weapon" else ItemRules.gear(str(item.id))
		return str(spec.get("rarity", "")) == "legendary" and str(spec.get("class", "")) == "archer")
	check(found.size() >= 1, "the archer found a legendary piece of his own (%d)" % found.size())
