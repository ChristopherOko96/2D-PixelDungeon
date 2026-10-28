extends SceneTree
## The six further subclasses (src/hell/sub_kit.gd, assets/data/frost_talents.json):
## each can be bought for its price and then brings its own look, attack, the four
## skills on keys 1-4 and both master skills on key 5, every one of which does
## its work in the run; tree nodes change skill values; bone shield, shield wall
## and fortress take hits; the beast form turns the hero into an ogre; the first
## stab out of hiding hits hardest; taunting allies draw enemies; a subclass gets
## no class cards for the standard skills; every full tree costs more than a run.

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const MetaStore = preload("res://src/hell/meta_store.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")
const SubKit = preload("res://src/hell/sub_kit.gd")
const SAVE := "user://subclass_test.cfg"
const SUBS := [["mage", "frost"], ["mage", "necro"], ["swordsman", "tank"], ["swordsman", "axe"], ["archer", "shadow"], ["archer", "beast"]]
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("SUBCLASS_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	test_every_tree_costs_more_than_a_run()
	for spec: Array in SUBS:
		await test_kit_works(spec[0], spec[1])
	await test_mods_change_values()
	await test_hits_are_taken()
	await test_beast_form_and_ambush()
	await test_taunting_ally_draws_enemies()
	await test_no_class_cards()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("SUBCLASS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## A run of class_id with the subclass bought and the given ranks.
func _with_sub(class_id: String, sub: String, ranks := {}) -> Node:
	var d := MetaStore.data()
	var store := MetaStore.fresh(d)
	store.crystals = 999
	check(MetaStore.choose_sub(d, store, class_id, sub) == "", "%s can be bought" % sub)
	check(int(store.crystals) == 999 - int(d.classes[class_id].subs[sub].price), "%s costs its price" % sub)
	store.classes[class_id].ranks = ranks
	MetaStore.save_store(store, SAVE)
	var game: Node = FrostScene.instantiate()
	game.start_floor = 1
	game.class_id = class_id
	game.meta_path = SAVE
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.mobs.clear()
	game.state.level = 10
	return game


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame


func _mob(game: Node, offset: Vector2, kind := "ice_zombie") -> Dictionary:
	game._spawn_mob(game.state.room, Vector2(game.player.x, game.player.y) + offset, kind)
	var m: Dictionary = game.mobs[game.mobs.size() - 1]
	m.spawn = 0.0
	m.hp = 500.0
	m.max = 500.0
	return m


func _tick(game: Node, steps: int) -> void:
	for i in range(steps):
		HeroKit.update(game, 0.1)
		RelicKit.update(game, 0.1)
		SubKit.update(game, 0.1)
		game._update_shots(0.1)
		game._update_zones(0.1)


## Whether a skill (or master) did its work: enemies hurt, allies up, a wall, a buff.
func _did_work(game: Node, s: Dictionary, m: Dictionary, hp0: float, allies0: int, walls0: int) -> bool:
	match str(s.do):
		"summon":
			return game.allies.size() > allies0 and m.hp < hp0
		"wall":
			return game.gwalls.size() > walls0
		"buff", "rally":
			# still running, or (vengeance) already given back as a blast
			return (game.state.sbuff as Dictionary).has(str(s.get("buff", "rally"))) or m.hp < hp0
		"stealth":
			return float(game.state.stealth) > 0.0 or float(game.state.get("ambush", 0.0)) > 0.0
		"taunt":
			return float(m.get("vuln_t", 0.0)) > 0.0
	return m.hp < hp0


func test_kit_works(class_id: String, sub: String) -> void:
	var d := MetaStore.data()
	var data: Dictionary = d.classes[class_id].subs[sub]
	var masters: Array = []
	for n: Dictionary in data.tiers[4]:
		masters.append(str(n.id))
	for master: String in masters:
		var game := await _with_sub(class_id, sub, {master: 1})
		check(str(game.sub_kit.get("id", "")) == sub, "%s: the run carries the subclass kit" % sub)
		if master == masters[0]:
			check(game.skills.size() == 4 and str(game.skills[0].id) == str(data.skills[0].id), "%s: keys 1-4 hold its own skills" % sub)
			check(is_equal_approx(float(game.state.dmg), float(data.attack.damage)), "%s: the attack sets the weapon damage" % sub)
			check(str(game.hero_frames.run[0].resource_path).contains(str(data.sprite)), "%s: the hero looks like %s" % [sub, data.sprite])
			# the attack
			var a := _mob(game, Vector2(110, 0))
			a.face = Vector2.RIGHT
			game._fire(Vector2.RIGHT)
			_tick(game, 4)
			check(a.hp < 500.0, "%s: the attack (%s) hurts" % [sub, data.attack.name])
			game.mobs.clear()
			# the skills on 1-4
			for s: Dictionary in game.skills:
				var m := _mob(game, Vector2(170, 0))
				game.state.corpses = [{"p": m.p + Vector2(20, 0), "t": 10.0}]
				game.aim_at = m.p - Vector2(0, m.cy)
				var allies0: int = game.allies.size()
				var walls0: int = game.gwalls.size()
				game.state.skill_cd = {}
				SubKit.press(game, str(s.key))
				_tick(game, 30)
				check(_did_work(game, s, m, 500.0, allies0, walls0), "%s: %s does its work" % [sub, s.name])
				check(float(game.state.skill_cd.get(str(s.key), 0.0)) > 0.0 or float(s.cooldown) <= 3.0, "%s: %s goes on cooldown" % [sub, s.name])
				game.mobs.clear()
				game.state.stealth = 0.0
		# the master skill on key 5
		var mm := _mob(game, Vector2(170, 0))
		game.aim_at = mm.p - Vector2(0, mm.cy)
		var n: Dictionary = game.sub_kit.masters[master]
		var allies1: int = game.allies.size()
		check(SubKit.master(game), "%s: key 5 casts %s" % [sub, n.name])
		_tick(game, 40)
		check(_did_work(game, n, mm, 500.0, allies1, game.gwalls.size()), "%s: %s does its work" % [sub, n.name])
		check(float(game.state.skill_cd.get("5", 0.0)) > 30.0, "%s: %s has the long cooldown" % [sub, n.name])
		await _free(game)


func test_mods_change_values() -> void:
	var game := await _with_sub("mage", "frost", {"fr_thick": 2, "fr_storm": 1})
	var wall: Dictionary = game.skills[0]
	check(is_equal_approx(float(wall.time), 6.0 * 1.8), "DICKE WAND x2 makes the ice wall last 80 %% longer (%.1f s)" % float(wall.time))
	check(is_equal_approx(float(game.skills[1].radius), 220.0 * 1.2), "SCHNEEGESTÖBER widens the blizzard")
	await _free(game)
	game = await _with_sub("mage", "necro", {"ne_horde": 2})
	SubKit.press(game, "1")
	check(game.allies.size() == 4, "GRÖSSERE HORDE x2 raises four skeletons at once")
	game.state.skill_cd = {}
	SubKit.press(game, "1")
	check(game.allies.filter(func(a: Dictionary) -> bool: return float(a.t) > 0.0).size() == 6, "the horde is capped at six")
	await _free(game)


func test_hits_are_taken() -> void:
	var game := await _with_sub("mage", "necro")
	var hp: int = game.state.hp
	SubKit.press(game, "2")
	for i in range(3):
		game.state.inv = 0.0
		game._hurt("Test")
	check(int(game.state.hp) == hp - 1, "the bone shield takes two hits, the third one hurts")
	await _free(game)
	game = await _with_sub("swordsman", "tank", {"ta_fortress": 1})
	hp = game.state.hp
	SubKit.master(game)
	for i in range(5):
		game.state.inv = 0.0
		game._hurt("Test")
	check(int(game.state.hp) == hp, "FESTUNG: no hit gets through")
	game.state.sbuff = {}
	var m := _mob(game, Vector2(90, 0))
	game.player.aim = Vector2.RIGHT
	SubKit.press(game, "2")
	game.state.inv = 0.0
	game._hurt("Test")
	check(int(game.state.hp) == hp, "the shield wall blocks an enemy in front")
	m.p = Vector2(game.player.x - 90, game.player.y)
	game.state.inv = 0.0
	game._hurt("Test")
	check(int(game.state.hp) == hp - 1, "the shield wall does not cover the back")
	await _free(game)


func test_beast_form_and_ambush() -> void:
	var game := await _with_sub("swordsman", "axe", {"ax_beast": 1})
	var m := _mob(game, Vector2(80, 0))
	check(is_equal_approx(SubKit.factor(game, m), 1.0), "no bonus damage outside the beast form")
	SubKit.master(game)
	var look: Dictionary = SubKit.look(game)
	check(look.scale > 1.0 and str(look.frames.run[0].resource_path).contains("ogre"), "BESTIENFORM: the hero becomes a big ogre")
	check(is_equal_approx(SubKit.factor(game, m), 1.5), "BESTIENFORM: +50 % damage")
	await _free(game)
	game = await _with_sub("archer", "shadow")
	var plain := _mob(game, Vector2(80, 0))
	plain.face = Vector2.LEFT
	game._fire(Vector2.RIGHT)
	var first: float = 500.0 - plain.hp
	game.mobs.clear()
	var hidden := _mob(game, Vector2(80, 0))
	hidden.face = Vector2.LEFT
	SubKit.press(game, "1")
	check(float(game.state.stealth) > 0.0 and SubKit.look(game).tint.a < 1.0, "TARNUNG hides the hero (drawn faint)")
	game.state.cool = 0.0
	game._fire(Vector2.RIGHT)
	check(500.0 - hidden.hp > first * 2.5, "the first stab out of hiding hits about three times as hard")
	check(float(game.state.stealth) <= 0.0, "the stab ends the hiding")
	await _free(game)


func test_taunting_ally_draws_enemies() -> void:
	var game := await _with_sub("archer", "beast", {"be_bear": 1})
	var m := _mob(game, Vector2(400, 0))
	SubKit.master(game)
	_tick(game, 6)
	var bear: Dictionary = game.allies[0]
	check(SubKit.chase(game, m, Vector2(game.player.x, game.player.y)) == bear.p, "URBÄR: enemies run at the bear, not the hero")
	await _free(game)


func test_no_class_cards() -> void:
	var game := await _with_sub("mage", "frost")
	var sets := CardKit.pool(game).map(func(c: Dictionary) -> String: return str(c.set))
	check(not sets.has("mage") and sets.has("all"), "a subclass gets shared cards, not the fire mage's")
	await _free(game)


func test_every_tree_costs_more_than_a_run() -> void:
	var d := MetaStore.data()
	var run := 0
	for f in range(1, 11):
		run += MetaStore.floor_award(d, f, "final" if f == 10 else ("mini" if f in [3, 6, 9] else "guardian"), 0)
	for spec: Array in SUBS:
		var sub: Dictionary = d.classes[spec[0]].subs[spec[1]]
		var tree := int(sub.price)
		for t in range(4):
			for n: Dictionary in sub.tiers[t]:
				tree += int(n.max) * int(d.cost[t])
		tree += int(d.cost[4])
		check(sub.get("ready", false) and tree > run, "%s with its full tree (%d) costs more than a run (%d)" % [spec[1], tree, run])
