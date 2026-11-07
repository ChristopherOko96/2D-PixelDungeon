extends SceneTree
## The Beuteordnung der Welten (docs/BEUTEORDNUNG.de.md, src/progress/reward_rules.gd) and the story chapters
## (src/progress/story_progress.gd): depth, hit damage, life cap, hearts, loot value, the legendary map, tier
## shares, the inscription line, unlocking stories and carrying a hero on.
## Usage:
##   godot --headless --path . --script res://tests/reward_rules_test.gd
const R = preload("res://src/progress/reward_rules.gd")
const P = preload("res://src/progress/story_progress.gd")
const Inventory = preload("res://src/items/inventory.gd")

var _checked := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
		print("FAIL: ", what)


func _run() -> void:
	# depth and hits
	_check(R.depth(1, 0) == 1 and R.depth(10, 0) == 10 and R.depth(1, 1) == 11 and R.depth(5, 2) == 25, "depth = floor + 10 per chapter")
	var hits := [1, 1, 1, 2, 2, 2, 3, 3, 3, 3]
	for t in range(1, 11):
		_check(R.dmg(t) == hits[t - 1], "dmg(%d) = %d, got %d" % [t, hits[t - 1], R.dmg(t)])
	_check(R.dmg(11) == 4 and R.dmg(20) == 7 and R.dmg(30) == 10, "dmg past chapter 1 grows by 1 every 3 floors")
	_check(R.cap(1) == 20 and R.cap(5) == 40 and R.cap(10) == 60, "life cap = 20 hits")
	_check(R.heal(1) == 2 and R.heal(7) == 6, "heal heart = 2 hits")
	_check(R.guardian_life() == 4, "guardian life heart +4 LP")
	_check(R.puzzle_life(1, 2) == 0 and R.puzzle_life(1, 3) == 1 and R.puzzle_life(10, 5) == 7 and R.puzzle_life(7, 4) == 5, "puzzle life heart = ceil(T/2) + tier - 3")
	_check(is_equal_approx(R.chapter_hp(0), 1.0) and is_equal_approx(R.chapter_hp(1), 1.6) and is_equal_approx(R.chapter_hp(2), 2.2), "chapter hardness")
	# loot value, gold, rarity
	_check(R.value(1, 1) == 1 and R.value(10, 5) == 18 and R.value(1, 5) == 9, "loot value = T + 2 (tier - 1)")
	_check(R.gold(18) == 82 and R.gold(1) == 14, "gold = 10 + 4 W")
	_check(R.min_rarity(3) == "uncommon" and R.min_rarity(4) == "rare" and R.min_rarity(9) == "rare" and R.min_rarity(10) == "epic" and R.min_rarity(40) == "epic", "least rarity never legendary")
	_check(R.rarity_up("epic") == "epic" and R.rarity_up("rare") == "epic", "one rarity up stops at epic")
	var w: Dictionary = R.rarity_weights()
	_check(int((w.legendary as Array)[0]) == 0 and int((w.legendary as Array)[1]) == 0, "normal rolls never legendary")
	# the legendary map
	_check(is_equal_approx(float(R.legendary(10, 5).p), 1.0) and bool(R.legendary(10, 5).sure), "E10 S5 sure and clean")
	_check(is_equal_approx(float(R.legendary(10, 4).p), 0.35) and is_equal_approx(float(R.legendary(9, 5).p), 0.35), "E10 S4 and E9 S5: 35 %")
	for cell: Array in [[9, 3], [9, 4], [8, 4], [8, 5], [7, 4], [7, 5], [6, 5], [5, 5], [10, 3]]:
		_check(is_equal_approx(float(R.legendary(cell[0], cell[1]).p), 0.03) and not bool(R.legendary(cell[0], cell[1]).sure), "small cell E%d S%d" % cell)
	var none := 0
	for f in range(1, 11):
		for t in range(1, 6):
			if float(R.legendary(f, t).p) > 0.0: none += 1
	_check(none == 12, "exactly 12 legendary cells, got %d" % none)
	_check(R.legendary_curse_chance(0.0) >= 0.75 and R.legendary_curse_chance(1.0) <= 0.9 + 0.0001, "curse chance in 75..90 %")
	# tier shares
	_check(R.tier_for_floor(1, 0.0) == 1 and R.tier_for_floor(1, 0.99) == 2, "floor 1: tiers 1-2")
	_check(R.tier_for_floor(10, 0.99) == 5 and R.tier_for_floor(10, 0.0) == 2, "floor 10: tiers 2-5")
	_check(is_equal_approx(R.tier_chance(5, 5), 0.08), "floor 5: tier 5 at 8 %")
	# the inscription line
	var line := R.reward_line(10, 10, 5)
	_check(line.begins_with("Schwierigkeit ◆◆◆◆◆") and line.contains("legendäres Stück") and line.contains("Lebensherz +7"), "line of E10 S5: " + line)
	_check(R.reward_line(1, 1, 1).contains("◆◇◇◇◇") and not R.reward_line(1, 1, 1).contains("Lebensherz"), "line of E1 S1")
	# legendary pieces and reward pieces of the inventory
	var inv := Inventory.new()
	inv.data = (load("res://src/items/item_rules.gd") as GDScript).data()
	inv._rng.seed = 7
	var clean := 0
	var cursed := 0
	for i in range(200):
		var piece := inv.legendary_piece("mage", 0.0)
		_check(not piece.is_empty() and str(piece.curse) == "", "a clean legendary piece")
		clean += 1
		var bad := inv.legendary_piece("mage", 1.0)
		if str(bad.curse) != "": cursed += 1
	_check(clean == 200 and cursed == 200, "curse chance 1 always curses")
	var rarities := {}
	for i in range(400):
		var p := inv.reward_piece(10, "archer", "epic", true, true)
		var spec: Dictionary = (load("res://src/items/item_rules.gd") as GDScript).weapon(str(p.id)) if p.type == "weapon" else (load("res://src/items/item_rules.gd") as GDScript).gear(str(p.id))
		rarities[str(spec.rarity)] = true
		_check(str(p.curse) == "", "clean reward pieces are never cursed")
	_check(not rarities.has("legendary"), "a reward piece of least epic never rolls legendary: %s" % str(rarities.keys()))
	# story progress
	var prog := P.fresh()
	_check(P.is_open(prog, 1) and not P.is_open(prog, 2), "only story 1 open at first")
	P.on_win(prog, "mage", 1, {"gold": 120, "level": 6, "hp": 10, "max_hp": 16}, 1, 3, "Krypta")
	_check(P.is_open(prog, 2) and not P.is_open(prog, 3), "story 1 won opens story 2")
	_check(not P.waiting(prog, "mage", 2).is_empty() and P.waiting(prog, "archer", 2).is_empty(), "only the winning class waits for story 2")
	_check(int(P.waiting(prog, "mage", 2).keep.gold) == 120, "the hero keeps its gold")
	P.drop_hero(prog, "mage")
	_check(P.waiting(prog, "mage", 2).is_empty() and P.is_open(prog, 2), "a fallen hero is gone, the unlock stays")
	P.on_win(prog, "archer", 3, {"gold": 1}, 3, 3)
	_check(P.hero_of(prog, "archer").is_empty() and P.is_open(prog, 3), "past the last story no hero waits")
	var path := "user://story_progress_unit.json"
	P.on_win(prog, "mage", 2, {"gold": 77}, 2, 3)
	_check(P.save_progress(prog, path), "progress saves")
	var back := P.load_progress(path)
	_check(P.is_open(back, 3) and int(P.waiting(back, "mage", 3).keep.gold) == 77 and int(P.waiting(back, "mage", 3).done) == 2, "progress loads back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("checked=%d failures=%d" % [_checked, _failed])
	quit(1 if _failed > 0 else 0)
