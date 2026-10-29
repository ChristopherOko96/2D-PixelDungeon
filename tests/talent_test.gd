extends SceneTree
## Talents and soul crystals of the Frostgruft (src/hell/meta_store.gd and the
## TALENTE screen): a floor pays crystals at its stairs, banked and saved; tiers
## open only after enough ranks, a node costs its tier's price, master skills
## exclude each other, only one subclass per class is active and switching
## refunds; a full tree costs more than one whole run brings; the talents a run
## starts with raise damage, hearts and card levels; every standard master skill
## works on key 5 (phoenix lifts the hero once); the archer's relic is the
## shadow dagger (backstab, shadow step, smoke hides the hero); the menu screen
## buys a node.

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const MetaStore = preload("res://src/hell/meta_store.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")
const RunTree = preload("res://src/progress/run_tree.gd")
const MainMenu = preload("res://src/main_menu.gd")
const SAVE := "user://talent_test.cfg"
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("TALENT_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	test_store_rules()
	await test_floor_pays_crystals()
	await test_talents_in_the_run()
	await test_master_skills()
	await test_shadow_dagger()
	await test_menu_buys()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("TALENT checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _new(class_id: String, floor_n := 1) -> Node:
	var game: Node = FrostScene.instantiate()
	game.start_floor = floor_n
	game.class_id = class_id
	game.meta_path = SAVE
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.mobs.clear()
	return game


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame


func test_store_rules() -> void:
	var d := MetaStore.data()
	var store := MetaStore.fresh(d)
	store.crystals = 30
	check(MetaStore.why_not(d, store, "mage", "f_twin") == "ab 3 Punkten", "tier 2 waits for 3 points")
	check(MetaStore.buy(d, store, "mage", "f_core") and int(store.crystals) == 30 - int(d.cost[0]), "a tier 1 rank costs its price")
	MetaStore.buy(d, store, "mage", "f_core")
	MetaStore.buy(d, store, "mage", "f_spark")
	check(MetaStore.buy(d, store, "mage", "f_twin"), "with 3 points tier 2 opens")
	store.classes.mage.ranks = {"f_core": 4, "f_spark": 4, "f_twin": 2, "f_wild": 2, "f_chain": 1}
	store.crystals = 100
	check(MetaStore.why_not(d, store, "mage", "f_meteor") == "", "13 points open the master tier")
	MetaStore.buy(d, store, "mage", "f_meteor")
	check(MetaStore.why_not(d, store, "mage", "f_phoenix") == "andere Meisterfähigkeit gewählt", "only one master skill per tree")
	store.crystals = 0
	check(MetaStore.choose_sub(d, store, "mage", "frost") == "zu wenig Kristalle", "a further subclass costs crystals")
	var back := MetaStore.refund(d, store, "mage")
	check(back > 0 and int(store.crystals) == back and (store.classes.mage.ranks as Dictionary).is_empty(), "a reset gives every crystal back")
	# a full tree costs more than a whole run without side goals
	var run := 0
	for f in range(1, 11):
		run += MetaStore.floor_award(d, f, "final" if f == 10 else ("mini" if f in [3, 6, 9] else "guardian"), 0)
	var tree := 0
	for t in range(4):
		for n: Dictionary in d.classes.mage.subs.fire.tiers[t]:
			tree += int(n.max) * int(d.cost[t])
	tree += int(d.cost[4])
	check(tree > run, "a full tree (%d) costs more than a whole run brings (%d)" % [tree, run])


func test_floor_pays_crystals() -> void:
	var game := await _new("mage", 3)
	var before: int = game.meta.crystals
	game._bank_crystals()
	var gained: int = int(game.meta.crystals) - before
	check(gained == MetaStore.floor_award(game.meta_data, 3, "mini", 0), "floor 3 with its mini boss pays %d crystals" % gained)
	var saved := MetaStore.load_store(game.meta_data, SAVE)
	check(int(saved.crystals) == int(game.meta.crystals), "the crystals are saved at once")
	await _free(game)


func test_talents_in_the_run() -> void:
	var d := MetaStore.data()
	var store := MetaStore.load_store(d, SAVE)
	store.classes.mage.ranks = {"f_core": 4, "f_spark": 4, "f_twin": 1, "f_heart": 0}
	store.classes.mage.ranks.f_heart = 0
	MetaStore.save_store(store, SAVE)
	var game := await _new("mage")
	check(is_equal_approx(CardKit.damage_mult(game), 1.2), "4 x GLUTKERN give +20 % damage")
	# a talent card opens its run tree node (docs/LAUF-DESIGN.de.md 3.3), it gives no free level
	check(CardKit.level(game, "twin_fire") == 0 and RunTree.state_of(CardKit.tree(game), CardKit.ranks(game), 2, "twin_fire") == "open", "ZWILLINGSFEUER opens its node in the run tree")
	check(int(RunTree.node(CardKit.tree(game), "twin_fire").max) == 1, "the talent rank caps the node (rank 1: one point)")
	check(RunTree.state_of(CardKit.tree(game), CardKit.ranks(game), 9, "wildfire") == "meta_locked", "GROSSBRAND waits for its talent")
	game.state.level = 2
	check(CardKit.take_node(game, "twin_fire"), "a point goes into the opened node")
	game.aim_at = Vector2(game.player.x + 300, game.player.y - 40)
	HeroKit.press(game, "1")
	check(game.shots.size() == 2, "then the fireball doubles")
	await _free(game)


func _with_master(class_id: String, master: String) -> Node:
	var d := MetaStore.data()
	var store := MetaStore.fresh(d)
	var sub: String = d.classes[class_id].standard
	for t: Array in d.classes[class_id].subs[sub].tiers:
		for n: Dictionary in t:
			if str(n.get("master", "")) == master:
				store.classes[class_id].ranks[str(n.id)] = 1
	MetaStore.save_store(store, SAVE)
	return await _new(class_id)


func _mob(game: Node, offset: Vector2, kind := "ice_zombie") -> Dictionary:
	game._spawn_mob(game.state.room, Vector2(game.player.x, game.player.y) + offset, kind)
	var m: Dictionary = game.mobs[game.mobs.size() - 1]
	m.spawn = 0.0
	return m


func test_master_skills() -> void:
	var specs := [["mage", "meteor_rain"], ["mage", "phoenix"], ["swordsman", "blade_storm"], ["swordsman", "execute"], ["archer", "death_shot"], ["archer", "arrow_rain"]]
	for spec: Array in specs:
		var game := await _with_master(spec[0], spec[1])
		check(str(game.state.talent.master) == spec[1], "%s starts with %s on key 5" % [spec[0], spec[1]])
		var m := _mob(game, Vector2(160, 0))
		m.hp = 30.0
		m.max = 30.0
		game.aim_at = m.p - Vector2(0, m.cy)
		HeroKit.master_press(game)
		for i in range(50):
			HeroKit.update(game, 0.1)
			RelicKit.update(game, 0.1)
			game._update_shots(0.1)
			game._update_zones(0.1)
		check(m.hp < 30.0, "%s hurts the enemy" % spec[1])
		check(float(game.state.skill_cd.get("5", 0.0)) > 30.0, "%s has a long cooldown" % spec[1])
		if spec[1] == "phoenix":
			game.state.hp = 1
			game.state.inv = 0.0
			game.state.phoenix_life = true
			game._hurt("Test")
			check(int(game.state.hp) > 0 and float(game.state.dead) <= 0.0, "the phoenix lifts the hero once")
		await _free(game)


func test_shadow_dagger() -> void:
	var game := await _new("archer")
	check(str(game.state.relic_item) == "shadow_dagger", "the archer's relic is the shadow dagger")
	game.state.relic = "shadow_dagger"
	game.state.relic_on = true
	game._relic_texture()
	while int(game.state.level) < 6:
		HeroKit.gain(game, HeroKit.need(game.theme.leveling, int(game.state.level)) - int(game.state.exp))
	game.state.offer = []
	game.state.cards_due = 0
	var front := _mob(game, Vector2(100, 0))
	front.face = Vector2.LEFT
	var back := _mob(game, Vector2(100, 20))
	back.face = Vector2.RIGHT
	game._fire(Vector2.RIGHT)
	check(back.hp < front.hp, "a stab in the back hurts more (%.1f vs %.1f)" % [back.hp, front.hp])
	game.mobs.clear()
	var a := _mob(game, Vector2(300, 0))
	var b := _mob(game, Vector2(360, 120))
	game.aim_at = a.p
	RelicKit.press(game, "1")
	RelicKit.update(game, 0.5)
	check(a.hp < a.max and b.hp < b.max, "shadow step strikes several enemies")
	RelicKit.press(game, "3")
	check(float(game.state.stealth) > 0.0, "the smoke bomb hides the hero")
	var c := _mob(game, Vector2(400, 0))
	var p0: Vector2 = c.p
	game._update_mobs(0.3)
	check(c.p.distance_to(p0) < 1.0, "hidden, enemies stop chasing")
	await _free(game)


func test_menu_buys() -> void:
	var d := MetaStore.data()
	var store := MetaStore.fresh(d)
	store.crystals = 10
	MetaStore.save_store(store, SAVE)
	var menu: Control = MainMenu.new()
	menu.talent_path = SAVE
	root.add_child(menu)
	await process_frame
	menu._open_talents()
	check(menu._talent_panel.visible, "TALENTE opens the talent screen")
	menu._talent_buy("f_core")
	var saved := MetaStore.load_store(d, SAVE)
	check(int(saved.classes.mage.ranks.get("f_core", 0)) == 1 and int(saved.crystals) == 10 - int(d.cost[0]), "a click buys and saves the rank")
	menu.queue_free()
	await process_frame
