extends SceneTree
## Relics, level-up cards and the mission list of the Frostgruft:
## the run rolls its shrine floor and a relic from the class pool (none for the
## archer yet); the staff's ball beats the class staff; relic skills open with
## the level; the stone golem rises, walks and slams; the rock flies; the hammer
## smashes harder than the sword, its leap lands a pulling blow, its field drags
## enemies in, its rock wave and meteor strike; cards come in threes from the
## right sets, stop at their max, add hearts and damage in small steps; the
## mission names key, gate, guardian and stairs and ticks them off.

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const RelicKit = preload("res://src/hell/relic_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const FrostHud = preload("res://src/hell/frost_hud.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("RELIC_CARD_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await test_run_rolls_a_class_relic()
	await test_staff_is_stronger_and_opens_with_level()
	await test_golem_and_rock()
	await test_hammer()
	await test_cards()
	await test_mission()
	print("RELIC_CARD checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _new(class_id: String, floor_n := 1) -> Node:
	var game: Node = FrostScene.instantiate()
	game.start_floor = floor_n
	game.class_id = class_id
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.mobs.clear()
	return game


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame


func _mob(game: Node, offset: Vector2, kind := "ice_zombie") -> Dictionary:
	game._spawn_mob(game.state.room, Vector2(game.player.x, game.player.y) + offset, kind)
	var m: Dictionary = game.mobs[game.mobs.size() - 1]
	m.spawn = 0.0
	return m


func _wield(game: Node, item: String, level: int) -> void:
	game.state.relic = item
	game.state.relic_on = true
	game._relic_texture()
	while int(game.state.level) < level:
		HeroKit.gain(game, HeroKit.need(game.theme.leveling, int(game.state.level)) - int(game.state.exp))
	game.state.offer = []
	game.state.cards_due = 0


func test_run_rolls_a_class_relic() -> void:
	var floors: Array = []
	for id: String in ["mage", "swordsman", "archer"]:
		var game := await _new(id)
		var pool: Array = game.theme.relics.pools[id]
		if pool.is_empty():
			check(int(game.state.relic_floor) == 0 and str(game.state.relic_item) == "", "the %s has no relic yet, so no shrine" % id)
		else:
			check(str(game.state.relic_item) in pool and float(game.state.relic_floor) in game.theme.relics.floors, "the %s's run hides %s on floor %d" % [id, game.state.relic_item, int(game.state.relic_floor)])
		await _free(game)
	for i in range(6):
		var game := await _new("mage")
		floors.append(int(game.state.relic_floor))
		await _free(game)
	var differ := false
	for f: int in floors:
		if f != floors[0]:
			differ = true
	check(differ, "the shrine floor changes between runs (%s)" % [floors])
	var sw := await _new("swordsman")
	check(sw.state.relic_item == "gravity_hammer", "the swordsman's relic is the gravity hammer")
	await _free(sw)


func test_staff_is_stronger_and_opens_with_level() -> void:
	var game := await _new("mage")
	var ball: Dictionary = game.theme.gravity_staff.ball
	var staff_dps: float = float(game.weapon.damage) / float(game.weapon.cooldown)
	var ball_dps: float = float(ball.damage) / float(ball.cooldown)
	check(ball_dps > staff_dps * 1.5 and float(ball.burst) > float(game.weapon.splash), "the gravity ball hits clearly harder than the class staff (%.1f vs %.1f per s)" % [ball_dps, staff_dps])
	_wield(game, "gravity_staff", 1)
	game.aim_at = Vector2(game.player.x + 300, game.player.y - 40)
	check(RelicKit.press(game, "1") and game.gwalls.size() == 1, "the wall is open from level 1")
	RelicKit.press(game, "3")
	check(game.pending.is_empty() and str(game.state.toasts[-1].text).contains("ab Level 6"), "the rock throw waits for level 6")
	await _free(game)


func test_golem_and_rock() -> void:
	var game := await _new("mage")
	_wield(game, "gravity_staff", 10)
	game.aim_at = Vector2(game.player.x + 300, game.player.y - 40)
	var m := _mob(game, Vector2(400, 0))
	RelicKit.press(game, "4")
	check(game.allies.size() == 1, "key 4 raises the stone golem")
	var golem: Dictionary = game.allies[0]
	var p0: Vector2 = golem.p
	for i in range(40):
		RelicKit.update(game, 0.05)
	check(golem.p.distance_to(p0) > 30.0 or m.hp < m.max, "the golem walks to the enemy and slams it")
	for i in range(30):
		RelicKit.update(game, 0.05)
	check(m.hp < m.max, "the golem's slam hurts the enemy")
	game.allies[0].t = 0.01
	RelicKit.update(game, 0.05)
	check(game.allies.is_empty(), "when its time is up the golem crumbles")
	RelicKit.press(game, "3")
	check(game.pending.size() == 1 and game.fx.any(func(f: Dictionary) -> bool: return f.kind == "lift"), "the rock throw first lifts a boulder")
	RelicKit.update(game, 1.0)
	check(game.shots.any(func(s: Dictionary) -> bool: return s.kind == "rock"), "then the boulder flies")
	await _free(game)


func test_hammer() -> void:
	var game := await _new("swordsman")
	var atk: Dictionary = game.theme.gravity_hammer.attack
	check(float(atk.damage) / float(atk.cooldown) > float(game.weapon.damage) / float(game.weapon.cooldown), "the hammer beats the sword per second")
	_wield(game, "gravity_hammer", 10)
	game.aim_at = Vector2(game.player.x + 400, game.player.y - 40)
	var m := _mob(game, Vector2(120, 0))
	var hp: float = m.hp
	game._fire(Vector2.RIGHT)
	check(m.hp < hp and game.shots.is_empty(), "the hammer smashes what is in front")
	# leap slam
	var near := _mob(game, Vector2(450, 0))
	var x0: float = game.player.x
	RelicKit.press(game, "1")
	for i in range(10):
		HeroKit.update(game, 0.05)
	check(game.player.x > x0 + 100.0 and near.hp < near.max, "the leap slam jumps and hits where it lands")
	# gravity field drags in
	game.mobs.clear()
	var f := _mob(game, Vector2(150, 0))
	game.aim_at = Vector2(game.player.x + 300, game.player.y)
	RelicKit.press(game, "2")
	var d0: float = f.p.distance_to(game.aim_at)
	for i in range(5):
		RelicKit.update(game, 0.1)
	check(f.p.distance_to(game.aim_at) < d0, "the gravity field drags enemies to its middle")
	# rock wave and meteor
	game.mobs.clear()
	var w := _mob(game, Vector2(330, 0))
	game.aim_at = Vector2(game.player.x + 600, game.player.y)
	RelicKit.press(game, "3")
	for i in range(10):
		RelicKit.update(game, 0.05)
	check(w.hp < w.max, "the rock wave erupts along the line")
	var mm := _mob(game, Vector2(-500, 0))
	game.aim_at = mm.p
	RelicKit.press(game, "4")
	RelicKit.update(game, 1.2)
	check(mm.hp < mm.max, "the meteor strikes its marked circle")
	await _free(game)


func test_cards() -> void:
	var game := await _new("mage")
	HeroKit.gain(game, HeroKit.need(game.theme.leveling, 1))
	var offer: Array = game.state.offer
	check(offer.size() == 3, "a level-up offers three cards")
	var sets_ok := true
	for c: Dictionary in offer:
		if not (str(c.set) in ["all", "mage"]):
			sets_ok = false
	check(sets_ok, "the mage only sees shared and mage cards")
	var hearts: int = game.state.max_hp
	game.state.offer = [CardKit._all(game).filter(func(c: Dictionary) -> bool: return c.id == "vigor")[0]]
	CardKit.choose(game, 0)
	check(int(game.state.max_hp) == hearts + 2 and game.state.offer.is_empty(), "EISERNE HAUT adds a heart and closes the choice")
	game.state.upgrades = {"mg_focus": 3}
	check(is_equal_approx(CardKit.damage_mult(game), 1.45), "three FOKUS cards give +45 %, not more")
	check(not CardKit.pool(game).any(func(c: Dictionary) -> bool: return c.id == "mg_focus"), "a card at its max is never offered again")
	check(not CardKit.pool(game).any(func(c: Dictionary) -> bool: return c.id == "long_breath"), "cards for a locked skill wait (photon at level 10)")
	game.state.upgrades = {"twin_fire": 1}
	game.state.level = 3
	game.aim_at = Vector2(game.player.x + 300, game.player.y - 40)
	HeroKit.press(game, "1")
	check(game.shots.size() == 2, "ZWILLINGSFEUER doubles the fireball")
	await _free(game)


func test_mission() -> void:
	var game := await _new("archer", 2)
	var goals := FrostHud.goals(game)
	var mains: Array = goals.filter(func(g: Dictionary) -> bool: return g.main)
	check(mains.size() == 4 and str(mains[0].text).begins_with("Finde den") and str(mains[2].text).begins_with("Besiege"), "the mission names key, gate, guardian and stairs")
	game.state.boss_dead = true
	goals = FrostHud.goals(game)
	check(goals.filter(func(g: Dictionary) -> bool: return g.main)[2].done, "a felled guardian ticks its goal")
	check(goals.any(func(g: Dictionary) -> bool: return not g.main), "side goals (puzzles, secret room) follow")
	await _free(game)
