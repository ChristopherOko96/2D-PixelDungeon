extends SceneTree
## Story 1's combat system in the Frostgruft (src/hell/frost_combat.gd and its
## parts): hits freeze the game for a moment, squash the enemy and stain the
## floor; conditions slow, freeze, poison and heal the hero; the crypt's moves
## warn before they hurt and put their condition on; items: the start weapon,
## a stronger weapon lifts every hit (also a subclass's), curses slow attacks,
## seal a skill or make hits heavier, crystals identify, stones break a curse,
## potions are learned by drinking or throwing, loot is taken by walking over
## it, the bag holds the game still. The Hell-Dungeon stays without all of it.

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const HeroFx = preload("res://src/hell/hero_fx.gd")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
const FrostItems = preload("res://src/hell/frost_items.gd")
const FrostBag = preload("res://src/hell/frost_bag.gd")
const FrostFeel = preload("res://src/hell/frost_feel.gd")
const MetaStore = preload("res://src/hell/meta_store.gd")
const SAVE := "user://frost_combat_test.cfg"
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("FROST_COMBAT_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	await test_hell_has_none()
	await test_feel()
	await test_conditions()
	await test_moves()
	await test_items_and_weapons()
	await test_curses()
	await test_potions_and_loot()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("FROST_COMBAT checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _new(class_id := "swordsman", scene: PackedScene = FrostScene) -> Node:
	var game: Node = scene.instantiate()
	game.start_floor = 2
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


func _mob(game: Node, offset: Vector2, kind := "ice_zombie") -> Dictionary:
	game._spawn_mob(game.state.room, Vector2(game.player.x, game.player.y) + offset, kind)
	var m: Dictionary = game.mobs[game.mobs.size() - 1]
	m.spawn = 0.0
	m.hp = 400.0
	m.max = 400.0
	return m


func test_hell_has_none() -> void:
	var game := await _new("swordsman", HellScene)
	check(game.feel == null and not game.state.has("bag"), "the Hell-Dungeon keeps its own combat")
	await _free(game)


func test_feel() -> void:
	var game := await _new()
	check(game.feel != null, "the Frostgruft has Story 1's feel")
	var m := _mob(game, Vector2(100, 0))
	game._damage_mob(m, Vector2.RIGHT * 600.0)
	check(game.feel.hitstop > 0.0, "a hit freezes the game for a moment (hitstop)")
	check(FrostFeel.squash(m) != Vector2.ONE, "a hit squashes the enemy")
	m.hp = 0.0
	game._update_mobs(0.01)
	check(game.feel._stains.size() > 0, "a kill leaves a stain on the floor")
	game.state.inv = 0.0
	var hp: int = game.state.hp
	game._hurt("Test")
	check(int(game.state.hp) < hp and float(game.state.shake) > 0.0, "a hurt shakes the camera")
	game.feel.hitstop = 0.2
	var t0: float = game.state.t
	game._process(0.05)
	check(is_equal_approx(float(game.state.t), t0), "during hitstop the game stands still")
	await _free(game)


func test_conditions() -> void:
	var game := await _new()
	HeroFx.apply(game, "slow", 3.0, 0.5)
	check(is_equal_approx(HeroFx.move_scale(game), 0.5), "slow halves the walking speed")
	HeroFx.apply(game, "freeze", 1.0, 1.0)
	game.state.cool = 0.0
	game._fire(Vector2.RIGHT)
	check(float(game.state.cool) <= 0.0, "frozen, the hero cannot attack")
	check(not game.FrostCombat.can_cast(game, "1"), "frozen, the hero cannot cast")
	HeroFx.clear(game)
	var hp: int = game.state.hp
	game.state.inv = 5.0
	HeroFx.apply(game, "poison", 3.0, 1.0)
	for i in range(11):
		HeroFx.step(game, 0.1)
	check(int(game.state.hp) == hp - 1, "poison hurts once a second, through the short invulnerability")
	HeroFx.clear(game)
	HeroFx.apply(game, "regen", 10.0, 1.0)
	for i in range(11):
		HeroFx.step(game, 0.1)
	check(int(game.state.hp) == hp, "regeneration heals half a heart")
	HeroFx.apply(game, "silence", 3.0, 1.0)
	check(not game.FrostCombat.can_cast(game, "2"), "silenced, no skills")
	await _free(game)


func test_moves() -> void:
	var game := await _new()
	var z := _mob(game, Vector2(150, 0), "ice_zombie")
	check(not FrostMoves.set_for(game, z).is_empty(), "the ice zombie has Story 1's move set")
	z.mv = {"next": 99.0, "cd": {}, "used": {}, "rage": false, "run": {}}
	FrostMoves._begin(game, z, {"move": "frost_breath"})
	check(z.mv_hold and (game.state.mzones as Array).any(func(q: Dictionary) -> bool: return q.kind == "cone"), "the frost breath warns with a cone while the zombie winds up")
	game.state.inv = 0.0
	var hp: int = game.state.hp
	for i in range(12):
		FrostMoves.update(game, 0.1)
	check(int(game.state.hp) < hp and HeroFx.has(game, "slow"), "the breath hurts and slows the hero standing in it")
	game.mobs.clear()
	game.state.mzones = []
	HeroFx.clear(game)
	# a guardian without a boss kit uses the guardian set: hail warns, then hits
	var b := _mob(game, Vector2(300, 0), "ice_zombie")
	b.kind = "boss"
	check(str(FrostMoves.set_for(game, b).moves[0].move) == "ice_fan", "guardians without a kit use the frost guardian set")
	b.mv = {"next": 99.0, "cd": {}, "used": {}, "rage": false, "run": {}}
	FrostMoves._begin(game, b, {"move": "hail"})
	var strikes: Array = (game.state.mzones as Array).filter(func(q: Dictionary) -> bool: return q.kind == "strike")
	check(strikes.size() == 5, "hail marks five circles")
	game.state.inv = 0.0
	hp = game.state.hp
	FrostMoves.update(game, 0.2)
	check(int(game.state.hp) == hp, "nothing hurts before the warning ends")
	for i in range(20):
		FrostMoves.update(game, 0.1)
	check(int(game.state.hp) < hp, "the hail hits the hero who stayed in the circle")
	# a move's enemy shot carries its condition
	HeroFx.clear(game)
	game.state.inv = 0.0
	game.eshots.append({"p": Vector2(game.player.x, game.player.y - 34), "v": Vector2.ZERO, "t": 1.0, "dmg": 1, "effect": {"slow": [0.5, 2.0]}, "style": "ice"})
	game._update_shots(0.01)
	check(HeroFx.has(game, "slow"), "an ice shard slows the hero it hits")
	# ice armour halves damage
	var a := _mob(game, Vector2(100, 0))
	a.armor_t = 2.0
	a.armor = 0.5
	game._damage_mob(a, Vector2.ZERO)
	var d1: float = 400.0 - a.hp
	a.armor_t = 0.0
	a.hp = 400.0
	game._damage_mob(a, Vector2.ZERO)
	check(d1 < 400.0 - a.hp, "ice armour takes part of the damage")
	await _free(game)


func test_items_and_weapons() -> void:
	var game := await _new()
	var held: Dictionary = game.state.bag.weapon
	check(str(held.id) == "short_sword" and held.identified, "a run starts with the class's start weapon, known")
	check(is_equal_approx(FrostItems.power(game), 1.0), "the start weapon keeps the class damage")
	var m := _mob(game, Vector2(100, 0))
	m.face = Vector2.LEFT
	game._damage_mob(m, Vector2.ZERO)
	var base: float = 400.0 - m.hp
	game.state.bag.bag.append(FrostItems.make_weapon("waraxe", false, ""))
	FrostItems.act(game, "equip", 0)
	check(str(game.state.bag.weapon.id) == "waraxe" and str(game.state.bag.bag[0].id) == "short_sword", "equipping swaps the weapon with the bag slot")
	check(game.state.bag.weapon.identified, "equipping reveals the weapon")
	m.hp = 400.0
	game._damage_mob(m, Vector2.ZERO)
	check(400.0 - m.hp > base * 1.5, "the war axe hits much harder than the short sword")
	game.state.bag.bag.append(FrostItems.make_weapon("short_bow", true, ""))
	FrostItems.act(game, "equip", 1)
	check(str(game.state.bag.weapon.id) == "waraxe", "a bow is not for the swordsman")
	# identify with a crystal
	game.state.bag.bag.append(FrostItems.make_weapon("katana", false, "night"))
	game.state.bag.bag.append(FrostItems.make_stack("crystal"))
	var i: int = game.state.bag.bag.size() - 2
	check(FrostItems.name_of(game, game.state.bag.bag[i]) == str(FrostItems.weapon_spec("katana").unknown_name), "unknown weapons only show what they look like")
	FrostItems.act(game, "identify", i)
	check(game.state.bag.bag[i].identified and not game.state.bag.bag.any(func(x: Dictionary) -> bool: return x.type == "crystal"), "a crystal identifies and is used up")
	await _free(game)


func test_curses() -> void:
	var game := await _new()
	game.state.bag.weapon = FrostItems.make_weapon("short_sword", true, "leaden")
	game.state.cool = 0.0
	game._fire(Vector2.RIGHT)
	check(float(game.state.cool) > float(game.state.rate) * 1.3, "the leaden hand slows attacks")
	game.state.bag.bag.append(FrostItems.make_weapon("knight_sword", false, ""))
	FrostItems.act(game, "equip", 0)
	check(str(game.state.bag.weapon.id) == "short_sword", "a known curse keeps the weapon in hand")
	game.state.bag.bag.append(FrostItems.make_stack("stone"))
	FrostItems.act(game, "cleanse", FrostItems.EQUIPPED)
	check(game.state.bag.weapon.blessed and FrostItems.rate(game) < 1.0, "a curse-breaker stone turns the leaden hand into the quick hand")
	game.state.bag.weapon = FrostItems.make_weapon("short_sword", true, "sealed")
	game.state.bag.weapon.seal = 2
	check(not game.FrostCombat.can_cast(game, "2") and game.FrostCombat.can_cast(game, "1"), "the seal locks one skill key")
	game.state.bag.weapon = FrostItems.make_weapon("short_sword", true, "fragile")
	var hp: int = game.state.hp
	game.state.inv = 0.0
	game._hurt("Test")
	check(int(game.state.hp) == hp - 2, "fragile: every hit weighs half a heart more")
	await _free(game)


func test_potions_and_loot() -> void:
	var game := await _new("mage")
	game.state.bag.bag.append(FrostItems.make_stack("potion", "healing", 2))
	var item: Dictionary = game.state.bag.bag[0]
	check(FrostItems.name_of(game, item).ends_with("TRANK") and FrostItems.name_of(game, item) != "HEILTRANK", "an unknown potion shows its colour")
	game.state.hp = 2
	FrostItems.act(game, "drink", 0)
	check(int(game.state.hp) == 6 and FrostItems.name_of(game, item) == "HEILTRANK", "drinking heals and teaches the potion")
	game.state.bag.bag.append(FrostItems.make_stack("potion", "ice"))
	var m := _mob(game, Vector2(300, 0))
	FrostItems.act(game, "throw", 1, m.p)
	check(float(m.get("stun", 0.0)) > 1.0, "a thrown ice potion freezes the enemies it hits")
	game.state.bag.bag.clear()
	FrostItems.drop_loot(game, [FrostItems.make_stack("crystal")], Vector2(game.player.x + 20, game.player.y))
	FrostItems.update(game, 0.5)
	check(game.state.bag.bag.size() == 1 and (game.state.bag.ground as Array).is_empty(), "walking over loot picks it up")
	FrostBag.toggle(game)
	check(FrostBag.is_open(game), "I opens the bag")
	var t0: float = game.state.t
	game._process(0.05)
	check(is_equal_approx(float(game.state.t), t0), "the open bag holds the game still")
	FrostBag.toggle(game)
	await _free(game)


