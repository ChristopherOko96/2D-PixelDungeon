extends SceneTree
## The loot of the story worlds (src/hell/gold_loot.gd, assets/data/loot_gold.json,
## assets/data/loot_runes.json), always seen. Gold: amounts below a bag fall as coins, from a bag on
## as bags plus coins; thrown gold lands, flies to the hero and is his in full; a slain enemy's gold
## rises as a '+N' shortly after its fall. Gold is the character's: each class its own, gone when it
## dies. Rune stones are the account's: from a slain enemy at once with a rising '+N', from a chest
## thrown out and picked up; their drop rates sit between rare and common and pay a reset or two a
## run. In a real floor no old rune stone finds are left, a chest throws its gold out, a death
## takes the character's gold and keeps the rune stones.

const GoldLoot = preload("res://src/hell/gold_loot.gd")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const Profile = preload("res://src/progress/profile.gd")
const TalentRulesRef = preload("res://src/progress/talent_rules.gd")
var checked := 0
var failures: Array[String] = []


## A stand-in for the game: the hero, the clock and the profile's gold.
class FakeGame extends Node:
	var player := {"x": 0.0, "y": 0.0}
	var state := {"t": 0.0, "hp": 5}
	var graphics := "hd"
	var sound = null
	var taken := 0
	var runes := 0

	func add_gold(n: int) -> void:
		taken += n

	func add_runes(n: int) -> void:
		runes += n


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
	test_character_gold_is_its_own_and_lost_on_death()
	test_rune_from_a_slain_enemy_is_taken_at_once_with_a_rising_plus_one()
	test_rune_from_a_chest_is_thrown_out_and_picked_up()
	test_rune_rates_between_rare_and_common_pay_a_reset()
	test_talent_test_profile_has_rune_stones_enough()
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


func test_character_gold_is_its_own_and_lost_on_death() -> void:
	# Arrange
	var d := Profile.data()
	var profile := Profile.fresh(d)
	# Act
	Profile.add_gold(profile, "mage", 30)
	Profile.add_gold(profile, "archer", 5)
	Profile.add_runes(profile, 4)
	var lost := Profile.lose_gold(profile, "mage")
	# Assert
	check(Profile.gold(profile, "swordsman") == 0, "a new character starts with 0 gold")
	check(lost == 30 and Profile.gold(profile, "mage") == 0, "the mage's death takes all its 30 gold")
	check(Profile.gold(profile, "archer") == 5, "the archer keeps its own gold")
	check(int(profile.runes) == 4, "the rune stones are the account's and stay")
	var saved := Profile.sanitize(profile, d)
	check(Profile.gold(saved, "archer") == 5 and int(saved.runes) == 4, "character gold and rune stones survive saving")
	check(not saved.has("gold") or int(Profile.sanitize({"gold": 500}, d).get("runes", 0)) == 0, "an old account gold becomes no rune stones")


func test_rune_from_a_slain_enemy_is_taken_at_once_with_a_rising_plus_one() -> void:
	# Arrange
	var game := FakeGame.new()
	var loot := GoldLoot.new(game)
	# Act: a roll above the chance, then one under it
	var missed := loot.roll_rune("mob", Vector2(200, 200), 0.99)
	var after_miss := game.runes
	var dropped := loot.roll_rune("mob", Vector2(200, 200), 0.0)
	# Assert
	check(not missed and after_miss == 0, "most enemies drop no rune stone")
	check(dropped and game.runes == 1, "a dropped rune stone of a slain enemy is the account's at once")
	check(loot.pieces.is_empty(), "it does not lie on the floor")
	check(loot.pops.size() == 1 and bool(loot.pops[0].get("rune", false)) and int(loot.pops[0].amount) == 1, "a '+1' with the rune stone rises where it fell")
	check(loot.roll_rune("boss", Vector2.ZERO) and game.runes == 2, "a floor guardian always drops one")
	game.free()


func test_rune_from_a_chest_is_thrown_out_and_picked_up() -> void:
	# Arrange
	var game := FakeGame.new()
	var loot := GoldLoot.new(game)
	# Act
	loot.roll_rune("chest", Vector2(40, 0), 0.0)
	check(loot.pieces.size() == 1 and bool(loot.pieces[0].get("rune", false)), "a chest's rune stone is thrown out")
	for k in range(600):
		game.state.t = float(game.state.t) + 1.0 / 60.0
		loot.update(1.0 / 60.0)
		if k > 90 and not loot.pieces.is_empty():
			var at := Vector2(game.player.x, game.player.y).move_toward(loot.pieces[0].p, 6.0)
			game.player.x = at.x
			game.player.y = at.y
	# Assert
	check(game.runes == 1 and game.taken == 0, "picked up it is one rune stone, no gold")
	game.free()


func test_rune_rates_between_rare_and_common_pay_a_reset() -> void:
	# Arrange
	var game := FakeGame.new()
	var loot := GoldLoot.new(game)
	var chance: Dictionary = loot.runes.chance
	var count: Dictionary = loot.runes.count
	var d := Profile.data()
	var profile := Profile.fresh(d)
	Profile.class_state(profile, "mage").level = 30
	# Act: what a 10-floor run finds (600 kills, 100 breakables, 40 chests, 9 guardians, the last boss, a vault)
	var run := 600.0 * float(chance.mob) * int(count.mob) + 100.0 * float(chance.breakable) + 40.0 * float(chance.chest) \
		+ 9.0 * int(count.boss) + int(count.final) + int(count.vault)
	var reset := TalentRulesRef.reset_cost(d, profile, "mage")
	# Assert
	check(float(chance.mob) > 0.0 and float(chance.mob) <= 0.05, "an enemy drops one now and then, rarely")
	check(float(chance.breakable) > float(chance.mob) and float(chance.chest) > float(chance.breakable) and float(chance.chest) < 0.5, "breakables and chests more often, never always")
	check(run >= reset * 2.0 and run <= reset * 5.0, "a run finds enough for 2 to 5 resets at Heldenstufe 30, not more (%.0f stones, reset %d)" % [run, reset])
	game.free()


func test_talent_test_profile_has_rune_stones_enough() -> void:
	# Arrange: a talent test profile written before rune stones paid the reset, and a player's own
	var d := Profile.data()
	var debug_path := "user://gold_loot_test_debug_profile.json"
	var own_path := "user://gold_loot_test_own_profile.json"
	var old := Profile.fresh(d)
	old.debug_free = true
	old.runes = 2
	Profile.save_profile(old, debug_path)
	var own := Profile.fresh(d)
	own.runes = 2
	Profile.save_profile(own, own_path)
	# Act
	var loaded_debug := Profile.load_profile(d, debug_path)
	var loaded_own := Profile.load_profile(d, own_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(debug_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(own_path))
	# Assert
	check(not OS.is_debug_build() or int(loaded_debug.runes) == Profile.DEBUG_RUNES, "the talent test profile has 999999 rune stones to reset with")
	check(int(loaded_own.runes) == 2, "a player's own profile keeps its rune stones")


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
	game.gold_loot.runes.chance.chest = 0.0
	var before: int = game.gold_loot.pieces.size()
	var chest := {"type": "chest", "x": float(game.player.x), "y": float(game.player.y) - 20.0, "room": int(game.state.room), "loot": {"gems": 7}}
	game.W.ents.append(chest)
	game.act()
	# Assert
	check(game.gold_loot.pieces.size() - before == 7, "the chest throws its 7 gold out as coins")
	check(str(chest.get("state", "")) == "empty", "a chest without a heart is empty at once")
	check(game.gold_count() == Profile.gold(game.profile, "swordsman"), "the HUD's gold is the character's gold")
	# a death: the character's gold is gone, the account's rune stones stay
	Profile.add_gold(game.profile, "swordsman", 12)
	Profile.add_runes(game.profile, 3)
	var runes_before: int = game.rune_count()
	game._gold_lost()
	check(game.gold_count() == 0 and int(game.state.gold_lost) >= 12, "the hero's death takes the character's gold")
	check(game.rune_count() == runes_before, "the hero's death keeps the rune stones")
	game.queue_free()
	await process_frame
