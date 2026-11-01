extends SceneTree
## The talents' damage over time and Raumsprung's cleanse in the story worlds
## (src/hell/hell_talents.gd, the story adapter of src/combat/talent_combat.gd;
## BAUPLAN F2 and F4).
## - F4, on a fake game: a talent's poison, bleed and burn reach the monster
##   as their own kinds (HeroKit poison_mob / bleed_mob / burn_mob), scaled by
##   the hero's damage once (talents.json statuses pct), poison and bleed are
##   not stopped by wet and set nothing on fire, the health bar's kind follows;
## - F2, on a fake game: cleanse_slows takes the slow condition, the frost
##   chill, the scream's slow and this frame's pool/gas slow off the hero and
##   leaves the rest (poison, the shared gas rule);
## - both in a real story world (Hölle, Krypta): a talent bleed and poison lose
##   exactly their data per second, Raumsprung (arcane_5) frees the hero.
## Uses the test profile; deletes it and the test settings afterwards.

const HellTalents = preload("res://src/hell/hell_talents.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const HeroFx = preload("res://src/hell/hero_fx.gd")
const Profile = preload("res://src/progress/profile.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const STEP := 1.0 / 60.0
## The story game's fields the adapter and HeroKit read (src/hell/hell_game.gd).
class FakeGame extends Node:
	var state: Dictionary = {}
	var zones: Array = []
	var theme: Dictionary = {}
	var hero_medium: Dictionary = {}
	var hero_gas: Dictionary = {}

var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("STORY_DOT_CLEANSE_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_talent_dots_scale_once_on_a_fake_game()
	test_cleanse_slows_on_a_fake_game()
	await test_talent_dots_in_the_hoelle()
	await test_raumsprung_frees_the_hero_in_the_krypta()
	for path: String in [Profile.default_path(), "user://settings_test.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("STORY_DOT_CLEANSE checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## An adapter on a fake game whose hero hits for `dmg`, its talents bound.
func _adapter(fake: FakeGame, class_id: String) -> RefCounted:
	var t: RefCounted = HellTalents.new()
	t.g = fake
	t.perk_combat = t
	t.tc.bind(t, Profile.data())
	t.tc.set_build(1, {"class": class_id, "level": 1})
	t.players[1] = {"pos": Vector2.ZERO, "hp": 10, "max_hp": 10, "damage": float(fake.state.dmg), "aim": Vector2.RIGHT, "face": 1.0}
	return t


func _hp_lost(fake: FakeGame, m: Dictionary, seconds: float) -> float:
	var before := float(m.hp)
	for k in range(roundi(seconds / STEP)): HeroKit.tick_mob(fake, m, STEP)
	return before - float(m.hp)


func test_talent_dots_scale_once_on_a_fake_game() -> void:
	# Arrange: a swordsman who hits for 2.3 (the Frostgruft's weapon), a monster
	var fake := FakeGame.new()
	fake.state = {"dmg": 2.3}
	var t := _adapter(fake, "swordsman")
	var statuses: Dictionary = t.tc.data.statuses
	for pick: Array in [["blade_1", "bleed"], ["curse_1", "poison"], ["fire_1", "burn"]]:
		var talent: String = pick[0]
		var kind: String = pick[1]
		for wet: bool in [false, true]:
			var m := {"id": 7, "kind": "mob", "hp": 100.0, "max": 100.0, "p": Vector2.ZERO, "pos": Vector2.ZERO, "statuses": {}}
			if wet: m.wet_t = 30.0
			# Act: the talent's status through talent_combat into the adapter, then one second of ticks
			t.tc._apply_status(1, m, t.tc.data.talents[talent], t.tc.runtime(1), talent)
			var lost := _hp_lost(fake, m, 1.0)
			# Assert
			var want := 2.3 * float(statuses[kind].pct) / 100.0
			if wet and kind == "burn":
				check(is_zero_approx(lost) and float(m.get("fire_t", 0.0)) <= 0.0, "%s: a wet monster cannot be set burning" % talent)
				continue
			check(absf(lost - want) < 0.001, "%s (%s%s): %.4f HP per second, the data's %.4f (hero damage counted once)" % [talent, kind, ", wet" if wet else "", lost, want])
			check(float(m.get(kind + "_t", 0.0)) > 0.0, "%s runs as its own kind %s" % [talent, kind])
			check(HeroKit.dot_kind(m) == kind, "%s: the health bar shows %s (%s)" % [talent, kind, HeroKit.dot_kind(m)])
			if kind != "burn":
				check(float(m.get("burn_t", 0.0)) <= 0.0 and float(m.get("fire_t", 0.0)) <= 0.0, "%s: %s is no burn and sets nothing on fire" % [talent, kind])
	t.release()
	fake.free()


func test_cleanse_slows_on_a_fake_game() -> void:
	# Arrange: every story slow on the hero, plus a poison that must stay
	var fake := FakeGame.new()
	var gas_rule := {"slow": 0.7, "hurt": 0.4}
	fake.state = {"dmg": 1.0, "hp": 10, "chill": 3.0, "slow": 2.0, "effects": {}}
	fake.state.effects = {"slow": {"time": 4.0, "value": 0.5, "tick": 1.0}, "poison": {"time": 4.0, "value": 0.3, "tick": 1.0}}
	fake.hero_medium = {"slow": 0.85, "hurt": 0.45}
	fake.hero_gas = gas_rule
	var t: RefCounted = HellTalents.new()
	t.g = fake
	# Act
	t.cleanse_slows(1)
	# Assert
	check(not fake.state.effects.has("slow"), "the slow condition is gone")
	check(fake.state.effects.has("poison"), "a poison is no slow: it stays")
	check(is_zero_approx(float(fake.state.chill)) and is_zero_approx(float(fake.state.slow)), "the frost chill and the scream's slow end")
	check(not fake.hero_medium.has("slow") and fake.hero_medium.has("hurt"), "this frame's pool slow is gone, its hurt stays")
	check(not fake.hero_gas.has("slow") and gas_rule.has("slow"), "this frame's gas slow is gone, the shared gas rule keeps its slow")
	fake.free()


func _game(scene: PackedScene, class_id: String) -> Node:
	var game: Node = scene.instantiate()
	game.class_id = class_id
	game.settings_path = "user://settings_test.cfg"
	root.add_child(game)
	for i in range(2):
		await process_frame
	game.set_process(false)
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true
	game.mobs.clear()
	game.state.hp = 99
	game.state.max_hp = 99
	return game


func test_talent_dots_in_the_hoelle() -> void:
	for pick: Array in [["swordsman", "blade_1"], ["necromancer", "curse_1"]]:
		# Arrange
		var game := await _game(HellScene, pick[0])
		var tc: RefCounted = game.talents.tc
		var info: Dictionary = tc.data.talents[pick[1]]
		game.monsters.spawn(game.state.room, Vector2(game.player.x + 80.0, game.player.y), str(game.monsters.defs.keys()[0]))
		var m: Dictionary = game.mobs[-1]
		m.spawn = 0.0
		m.hp = 400.0
		m.max = 400.0
		game.talents._sync_hero()
		game.talents._sync_mobs()
		# Act: the status, then one second of the game's own clock through the monsters' tick
		tc._apply_status(1, m, info, tc.runtime(1), str(pick[1]))
		var before := float(m.hp)
		var t0 := float(game.state.t)
		for k in range(roundi(1.0 / STEP)):
			game.state.t += STEP
			HeroKit.tick_mob(game, m, STEP)
		# Assert
		var per_s := (before - float(m.hp)) / (float(game.state.t) - t0)
		var want := float(game.state.dmg) * float(tc.data.statuses[str(info.status)].pct) / 100.0
		check(absf(per_s - want) < 0.001, "Hölle %s %s: %.4f HP/s, the data's %.4f" % [pick[0], pick[1], per_s, want])
		game.queue_free()
		await process_frame


func test_raumsprung_frees_the_hero_in_the_krypta() -> void:
	# Arrange: the Leerenmagier with Raumsprung, slowed every way the story slows him
	var game := await _game(KryptaScene, "mage")
	var tc: RefCounted = game.talents.tc
	tc.set_build(1, {"class": "mage", "level": 30})
	var rt: Dictionary = tc.runtime(1)
	rt.ranks["arcane_5"] = 3
	rt.bar = ["arcane_5"]
	rt.res = 100.0
	HeroFx.apply(game, "slow", 4.0, 0.5)
	game.state.chill = 4.0
	game.state.slow = 4.0
	var x0 := float(game.player.x)
	# Act
	var fired: bool = game.talents.press(0)
	# Assert
	check(fired and absf(float(game.player.x) - x0) > 20.0, "Raumsprung fires and moves the hero")
	check(not HeroFx.has(game, "slow"), "Raumsprung takes the slow condition off")
	check(is_zero_approx(float(game.state.chill)) and is_zero_approx(float(game.state.slow)), "Raumsprung ends the chill and the scream's slow")
	game.queue_free()
	await process_frame
