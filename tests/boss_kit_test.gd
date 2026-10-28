extends SceneTree
## Frostgruft guardians with their own fight (src/hell/boss_kit.gd on the
## Hell-Dungeon runtime): Hrimgar has three bars with his phase look, an empty
## bar starts the next phase with a shard ring, invulnerability and a push,
## kit bosses take no knockback, crystals guard the core, the last stand hurts
## outside the safe circles only, every attack does its part, the three mini
## bosses have two phases (the commander's shield blocks from the front), the
## last bar ends the fight, and hell guardians keep their old fight.

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const BossKit = preload("res://src/hell/boss_kit.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("BOSS_KIT_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await test_hrimgar_has_three_bars_and_phase_looks()
	await test_empty_bar_starts_next_phase_with_break()
	await test_crystals_guard_the_core()
	await test_attacks_do_their_part()
	await test_last_stand_spares_the_safe_circles()
	await test_mini_bosses_have_two_phases()
	await test_last_bar_ends_the_fight()
	await test_hell_guardian_keeps_old_fight()
	print("BOSS_KIT checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## A game on floor n with its guardian spawned in the boss hall, hero below it.
func _boss_game(scene: PackedScene, n: int) -> Array:
	var game: Node = scene.instantiate()
	game.start_floor = n
	game.class_id = "archer"
	root.add_child(game)
	await process_frame
	var hall: Dictionary = {}
	for r: Dictionary in game.W.rooms:
		if r.type == "boss":
			hall = r
	game.player.x = (hall.bx + hall.bw / 2.0) * 96.0
	game.player.y = (hall.by + hall.bh / 2.0 + 3.0) * 96.0
	game.state.room = hall.index
	hall.fight = true
	game._spawn_mob(hall.index, Vector2((hall.bx + hall.bw / 2.0) * 96.0, (hall.by + hall.bh / 2.0) * 96.0), "boss")
	var boss: Dictionary = game.mobs[game.mobs.size() - 1]
	boss.spawn = 0.0
	return [game, boss]


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame


func test_hrimgar_has_three_bars_and_phase_looks() -> void:
	# Arrange / Act
	var g := await _boss_game(FrostScene, 10)
	var game: Node = g[0]
	var boss: Dictionary = g[1]
	# Assert
	check(boss.has("kit") and boss.phase_hp.size() == 3 and is_equal_approx(boss.hp, float(boss.phase_hp[0])), "Hrimgar starts on bar 1 of 3")
	check(str(boss.look.sprite) == "boss_golem_p1_f", "bar 1 wears the ice armour look")
	var before: float = boss.hp
	game._damage_mob(boss, Vector2.UP * 900.0)
	check(boss.hp < before and boss.k == Vector2.ZERO, "hits hurt him but push him nowhere (no knockback)")
	await _free(game)


func test_empty_bar_starts_next_phase_with_break() -> void:
	# Arrange
	var g := await _boss_game(FrostScene, 10)
	var game: Node = g[0]
	var boss: Dictionary = g[1]
	game.eshots.clear()
	game.player.y = boss.p.y + 60.0
	var near: float = Vector2(game.player.x, game.player.y).distance_to(boss.p)
	boss.hp = 0.0
	# Act
	game._update_mobs(0.01)
	# Assert
	check(game.mobs.has(boss) and int(boss.phase) == 1 and is_equal_approx(boss.hp, float(boss.phase_hp[1])), "an empty bar starts bar 2 instead of killing him")
	check(str(boss.look.sprite) == "boss_golem_p2_f" and game.eshots.size() >= 10, "bar 2 shows the core look and bursts a shard ring")
	check(Vector2(game.player.x, game.player.y).distance_to(boss.p) > near + 40.0, "the break pushes the hero away")
	var hp: float = boss.hp
	game._damage_mob(boss, Vector2.UP * 900.0)
	check(boss.hp == hp, "he is invulnerable right after the break")
	await _free(game)


func test_crystals_guard_the_core() -> void:
	# Arrange: bar 2 summons guarding crystals
	var g := await _boss_game(FrostScene, 10)
	var game: Node = g[0]
	var boss: Dictionary = g[1]
	boss.hp = 0.0
	game._update_mobs(0.01)
	boss.inv = 0.0
	# Act
	BossKit.start(game, boss, {"do": "summon", "kind": "ice_crystal", "count": 4, "around": 220, "guard": true})
	# Assert
	check(is_equal_approx(BossKit.damage_factor(game, boss), 0.5), "while his crystals stand he takes half damage")
	game.mobs = game.mobs.filter(func(m: Dictionary) -> bool: return m.get("guard_of", null) != boss)
	check(is_equal_approx(BossKit.damage_factor(game, boss), 1.0), "with the crystals gone he takes full damage")
	await _free(game)


func test_attacks_do_their_part() -> void:
	var g := await _boss_game(FrostScene, 10)
	var game: Node = g[0]
	var boss: Dictionary = g[1]
	# fist: a boomerang that turns back
	game.eshots.clear()
	BossKit.start(game, boss, {"do": "fist", "speed": 620, "back": 0.75})
	check(game.eshots.size() == 1 and game.eshots[0].get("fist", false) and game.eshots[0].has("back"), "the fist flies as a returning boomerang")
	# stomp: rings with a gap
	game.eshots.clear()
	BossKit.start(game, boss, {"do": "stomp", "rings": 3, "count": 24, "gap": 0.8, "speed": 300, "pause": 0.5})
	for i in range(12):
		BossKit.update(game, boss, 0.1)
	check(game.eshots.size() > 3 * 18 and game.eshots.size() < 3 * 24, "the stomp sends three rings, each with a gap (%d shots)" % game.eshots.size())
	# icicles: hurt only who stands in the circle when it falls
	game.zones.clear()
	game.state.inv = 0.0
	var hp: int = game.state.hp
	BossKit.start(game, boss, {"do": "icicles", "count": 1, "radius": 80, "delay": 0.2, "spread": 0})
	game._update_zones(0.3)
	check(game.state.hp < hp, "an icicle hurts the hero standing in its circle")
	# charge: winds up, then rushes
	boss.busy = {}
	var p0: Vector2 = boss.p
	BossKit.start(game, boss, {"do": "charge", "speed": 900, "time": 0.4, "windup": 0.2})
	BossKit.update(game, boss, 0.1)
	check(boss.p == p0 and boss.hold, "the charge holds still while winding up")
	for i in range(4):
		BossKit.update(game, boss, 0.1)
	check(boss.p.distance_to(p0) > 50.0, "then the charge rushes forward")
	# teleport: lands in the middle of the hall
	boss.busy = {}
	boss.p += Vector2(300, 0)
	BossKit.start(game, boss, {"do": "teleport_center", "windup": 0.2, "push": 160})
	BossKit.update(game, boss, 0.3)
	check(boss.p.distance_to(boss.busy.get("to", boss.p)) < 1.0 and (boss.busy as Dictionary).is_empty(), "the jump ends in the middle of the hall")
	# breath: a turning stream of chilling shots
	game.eshots.clear()
	BossKit.start(game, boss, {"do": "breath", "duration": 0.5, "turn": 3.0, "rate": 0.05, "speed": 340, "chill": 2.0})
	for i in range(6):
		BossKit.update(game, boss, 0.1)
	check(game.eshots.size() >= 8 and game.eshots[0].has("chill"), "the frost breath streams chilling shots")
	# fist hunt: homing fists
	game.eshots.clear()
	BossKit.start(game, boss, {"do": "fist_hunt", "count": 2, "time": 5.0, "speed": 260})
	check(game.eshots.size() == 2 and game.eshots[0].has("home"), "two fists hunt the hero")
	await _free(game)


func test_last_stand_spares_the_safe_circles() -> void:
	for safe: bool in [true, false]:
		# Arrange: bar 3 below 15 %
		var g := await _boss_game(FrostScene, 10)
		var game: Node = g[0]
		var boss: Dictionary = g[1]
		boss.phase = 2
		boss.hp = 10.0
		boss.max = 150.0
		boss.atk_t = 99.0
		BossKit.update(game, boss, 0.01)
		var zone: Dictionary = {}
		for z: Dictionary in game.zones:
			if z.kind == "safe":
				zone = z
		check(not zone.is_empty() and str(boss.busy.get("do", "")) == "last_stand", "below 15 %% the eternal frost shows safe circles")
		game.player.x = zone.p.x if safe else boss.p.x + 900.0
		game.player.y = zone.p.y if safe else boss.p.y + 900.0
		game.state.inv = 0.0
		var hp: int = game.state.hp
		# Act
		BossKit.update(game, boss, 2.0)
		# Assert
		check((game.state.hp == hp) == safe, "the eternal frost %s" % ("spares the hero in a safe circle" if safe else "hurts the hero outside"))
		check(float(boss.rest) > 0.0 and BossKit.damage_factor(game, boss) > 1.0, "afterwards he rests and takes more damage")
		await _free(game)


func test_mini_bosses_have_two_phases() -> void:
	for n: int in [3, 6, 9]:
		var g := await _boss_game(FrostScene, n)
		var game: Node = g[0]
		var boss: Dictionary = g[1]
		check(boss.has("kit") and boss.phase_hp.size() == 2, "the floor %d mini boss has two phases" % n)
		if n == 9:
			boss.face = Vector2.LEFT
			var hp: float = boss.hp
			check(not game._damage_mob(boss, Vector2.RIGHT * 900.0) and boss.hp == hp, "the commander's shield blocks from the front")
		await _free(game)


func test_last_bar_ends_the_fight() -> void:
	# Arrange
	var g := await _boss_game(FrostScene, 10)
	var game: Node = g[0]
	var boss: Dictionary = g[1]
	game.mobs = [boss]
	boss.phase = 2
	boss.hp = 0.0
	# Act
	game._update_mobs(0.01)
	# Assert
	check(not game.mobs.has(boss) and game.state.boss_dead, "the last empty bar fells Hrimgar and opens the way")
	await _free(game)


func test_hell_guardian_keeps_old_fight() -> void:
	var g := await _boss_game(HellScene, 10)
	var game: Node = g[0]
	var boss: Dictionary = g[1]
	check(not boss.has("kit"), "hell guardians have no kit")
	var before: Vector2 = boss.k
	game._damage_mob(boss, Vector2.UP * 900.0)
	check(boss.k != before, "hell guardians still get a little knockback")
	await _free(game)
