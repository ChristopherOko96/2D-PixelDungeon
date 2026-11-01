extends SceneTree
## The gold of the story worlds (src/hell/gold_loot.gd, assets/data/loot_gold.json): one currency,
## always seen. Amounts below a bag fall as coins, from a bag on as bags plus coins; thrown gold
## lands, flies to the hero and goes into the profile in full; a slain enemy's gold rises as a
## '+N' shortly after its fall; in a real floor no rune stones are left, a chest throws its gold
## out and the HUD's row counts gold.

const GoldLoot = preload("res://src/hell/gold_loot.gd")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const Profile = preload("res://src/progress/profile.gd")
var checked := 0
var failures: Array[String] = []


## A stand-in for the game: the hero, the clock and the profile's gold.
class FakeGame extends Node:
	var player := {"x": 0.0, "y": 0.0}
	var state := {"t": 0.0, "hp": 5}
	var graphics := "hd"
	var sound = null
	var taken := 0

	func add_gold(n: int) -> void:
		taken += n


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("GOLD_LOOT_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_split_bags_from_ten_coins_below()
	test_thrown_gold_reaches_the_hero_in_full()
	test_kill_popup_shows_after_a_short_delay()
	await test_a_floor_has_gold_instead_of_rune_stones()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	print("GOLD_LOOT checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)


func test_split_bags_from_ten_coins_below() -> void:
	# Arrange / Act / Assert: the bag rule at its edges (bag_value 10 is the point)
	check(GoldLoot.split(0, 10) == Vector2i(0, 0), "no gold, nothing falls")
	check(GoldLoot.split(9, 10) == Vector2i(0, 9), "9 gold fall as 9 coins")
	check(GoldLoot.split(10, 10) == Vector2i(1, 0), "10 gold fall as one bag")
	check(GoldLoot.split(23, 10) == Vector2i(2, 3), "23 gold fall as 2 bags and 3 coins")


func test_thrown_gold_reaches_the_hero_in_full() -> void:
	# Arrange: a chest's 23 gold thrown out beside the hero
	var game := FakeGame.new()
	var loot := GoldLoot.new(game)
	# Act
	loot.spew(Vector2(40, 0), 23)
	check(loot.pieces.size() == 5, "23 gold are 5 pieces (2 bags, 3 coins)")
	var seen_pop := false
	for k in range(600):
		game.state.t = float(game.state.t) + 1.0 / 60.0
		loot.update(1.0 / 60.0)
		for pop: Dictionary in loot.pops:
			if bool(pop.get("hero", false)):
				seen_pop = true
		# after the throw the hero walks to gold lying out of the magnet's reach
		if k > 90 and not loot.pieces.is_empty():
			var to: Vector2 = loot.pieces[0].p
			var at := Vector2(game.player.x, game.player.y).move_toward(to, 6.0)
			game.player.x = at.x
			game.player.y = at.y
	# Assert
	check(loot.pieces.is_empty(), "all thrown gold was picked up")
	check(game.taken == 23, "the hero got all 23 gold (got %d)" % game.taken)
	check(seen_pop, "pickups show a '+N' over the hero")
	game.free()


func test_kill_popup_shows_after_a_short_delay() -> void:
	# Arrange
	var game := FakeGame.new()
	var loot := GoldLoot.new(game)
	# Act
	loot.kill_popup(Vector2(100, 100), 1)
	var hidden_at_once := float(loot.pops[0].t) < 0.0
	for k in range(15):
		loot.update(1.0 / 60.0)
	var shown_soon := not loot.pops.is_empty() and float(loot.pops[0].t) >= 0.0
	for k in range(90):
		loot.update(1.0 / 60.0)
	# Assert
	check(hidden_at_once and shown_soon, "a slain enemy's '+1' shows shortly after its fall")
	check(loot.pops.is_empty(), "the '+1' is gone within a second")
	game.free()


func test_a_floor_has_gold_instead_of_rune_stones() -> void:
	# Arrange: a real Frostgruft floor
	var game: Node = FrostScene.instantiate()
	game.class_id = "swordsman"
	root.add_child(game)
	for k in range(5):
		await process_frame
	game.state.world_run = 4242
	game.load_floor(1, true)
	await process_frame
	var loose := 0
	for e: Dictionary in game.W.ents:
		if e.type == "gem" and not e.get("taken", false):
			loose += 1
	check(loose == 0, "no rune stone is left to pick up")
	# Act: a chest with 7 gold right by the hero, opened
	for r: Dictionary in game.W.rooms:
		r.fight = false
	game.mobs = []
	var before: int = game.gold_loot.pieces.size()
	var chest := {"type": "chest", "x": float(game.player.x), "y": float(game.player.y) - 20.0, "room": int(game.state.room), "loot": {"gems": 7}}
	game.W.ents.append(chest)
	game.act()
	# Assert
	check(game.gold_loot.pieces.size() - before == 7, "the chest throws its 7 gold out as coins")
	check(str(chest.get("state", "")) == "empty", "a chest without a heart is empty at once")
	check(game.gold_count() == int(game.profile.get("gold", 0)), "the HUD's gold is the profile's gold")
	game.queue_free()
	await process_frame
