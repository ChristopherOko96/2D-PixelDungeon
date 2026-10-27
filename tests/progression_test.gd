extends SceneTree
## Headless checks for EXP, levels and displayed stats (src/player/progression.gd)
## and the heart layout of the HUD (src/ui/hud.gd).

const Progression = preload("res://src/player/progression.gd")
const Hud = preload("res://src/ui/hud.gd")
const LEVELING := {"base": 100, "exponent": 1.5}
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("PROGRESSION_FAIL: ", description)

func _initialize() -> void:
	check(Progression.exp_to_next(1, LEVELING) == 100, "level 1 needs 100 EXP (100 × 1^1.5)")
	check(Progression.exp_to_next(2, LEVELING) == 283, "level 2 needs 283 EXP (100 × 2^1.5)")
	check(Progression.exp_to_next(4, LEVELING) == 800, "level 4 needs 800 EXP")
	for level in range(1, 20):
		check(Progression.exp_to_next(level + 1, LEVELING) > Progression.exp_to_next(level, LEVELING), "each level needs more EXP than the one before (%d)" % level)

	var player := {"level": 1, "exp": 0}
	check(Progression.add_exp(player, 60, LEVELING) == 0 and player.exp == 60 and player.level == 1, "EXP adds up below the threshold")
	check(Progression.add_exp(player, 50, LEVELING) == 1 and player.level == 2 and player.exp == 10, "surplus EXP carries into the next level")
	player = {"level": 1, "exp": 0}
	check(Progression.add_exp(player, 100 + 283 + 520 + 5, LEVELING) == 3 and player.level == 4 and player.exp == 5, "one big pickup processes every level-up")
	check(Progression.add_exp(player, 0, LEVELING) == 0 and Progression.add_exp(player, -50, LEVELING) == 0 and player.exp == 5, "zero or negative EXP changes nothing")

	for value in [1, 2, 5, 10, 25, 100, 333]:
		var orbs := Progression.split_exp(value, 12)
		var total := 0
		for orb in orbs: total += orb
		check(total == value and orbs.size() >= 1 and orbs.size() <= 12 and orbs.min() >= 1, "%d EXP splits into 1-12 orbs that add up exactly" % value)
	check(Progression.split_exp(100, 12).size() > Progression.split_exp(5, 12).size(), "the boss drops more orbs than a goblin")
	check(Progression.split_exp(0, 12).is_empty(), "no EXP drops no orbs")

	var balance := {"player": {"damage": 2, "speed": 190, "shot_interval": 0.2}, "bullet": {"speed": 600, "lifetime": 1.2}}
	var hero := {"damage": 3.0, "speed": 190.0, "shot_interval": 0.25, "range": 1.5, "shot_speed": 600.0, "luck": 1.0, "level": 3}
	var stats := Progression.display_stats(hero, balance)
	check(is_equal_approx(stats.damage, 3.0) and is_equal_approx(stats.tears, 4.0) and is_equal_approx(stats.speed, 1.0), "damage, tears (shots per second) and relative speed come from the player")
	check(is_equal_approx(stats.range, 9.0) and is_equal_approx(stats.shot_speed, 1.0) and is_equal_approx(stats.luck, 1.0) and stats.level == 3, "range, shot speed, luck and level come from the player")
	hero.damage += 1.0
	check(is_equal_approx(Progression.display_stats(hero, balance).damage, 4.0), "a damage upgrade shows at once")

	check(Hud.heart_fills(3, 6) == [2, 1, 0], "3 of 6 HP: one full, one half, one empty heart")
	check(Hud.heart_fills(8, 8) == [2, 2, 2, 2], "full health shows only full hearts")
	check(Hud.heart_fills(0, 8) == [0, 0, 0, 0], "0 HP keeps the empty containers")
	check(Hud.heart_fills(12, 8) == [2, 2, 2, 2], "over-healing never adds hearts beyond the maximum")
	check(Hud.heart_fills(10, 10).size() == 5, "a bigger maximum adds containers")
	check(Hud.heart_position(8).y > Hud.heart_position(7).y and Hud.heart_position(8).x == Hud.heart_position(0).x, "the ninth heart starts a new row")

	var hud = Hud.new()
	root.add_child(hud)
	hud.show_player({"hp": 8, "max_hp": 8, "level": 1, "exp": 0, "exp_next": 100, "stats": {"damage": 2.0}})
	hud.show_player({"hp": 5, "max_hp": 8, "level": 1, "exp": 0, "exp_next": 100, "stats": {"damage": 3.0}})
	check(hud._hurt.has(2) and hud._hurt.has(3) and not hud._hurt.has(1), "damage blinks exactly the hearts that lost health")
	check(hud._stat_changes.has("damage") and hud._stat_changes.damage.up, "a raised stat is highlighted as an increase")
	hud.show_player({"hp": 7, "max_hp": 8, "level": 2, "exp": 4, "exp_next": 283, "stats": {"damage": 3.0}})
	check(hud._healed.has(2) and hud._healed.has(3) and hud._level_flash > 0.0, "healing and level-ups start their effects")
	hud.show_player({})
	check(not hud.showing(), "an empty player hides the HUD")
	hud.free()

	print("PROGRESSION checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
