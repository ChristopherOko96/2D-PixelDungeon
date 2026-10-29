extends SceneTree
## Story 1's combat system in the Frostgruft (src/hell/frost_combat.gd and its
## parts): hits freeze the game for a moment, squash the enemy and stain the
## floor; conditions slow, freeze, poison and heal the hero and show in the
## hero panel; the crypt's moves warn before they hurt and put their condition
## on. Items are item system 2's (src/hero/story_items.gd): the inventory on I,
## a stronger weapon lifts every hit, also a subclass's. The Hell-Dungeon
## stays without the combat feel.

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const HeroFx = preload("res://src/hell/hero_fx.gd")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
const FrostFeel = preload("res://src/hell/frost_feel.gd")
const FrostCombat = preload("res://src/hell/frost_combat.gd")
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
	await test_items_are_item_system_2()
	await test_subclass_with_weapon()
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


func _equip(game: Node, weapon: Dictionary) -> void:
	var items: Node = game.story_items
	items.give(weapon, Vector2.ZERO)
	var bag: Array = items.players[1].inventory.bag
	items.act("inv_equip", bag.find(weapon))


func test_hell_has_none() -> void:
	var game := await _new("swordsman", HellScene)
	HeroFx.apply(game, "poison", 3.0, 1.0)
	check(game.feel == null and FrostCombat.status_lines(game).is_empty(), "the Hell-Dungeon keeps its own combat")
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
	check(not FrostCombat.can_cast(game, "1"), "frozen, the hero cannot cast")
	HeroFx.clear(game)
	var hp: int = game.state.hp
	game.state.inv = 5.0
	HeroFx.apply(game, "poison", 3.0, 1.0)
	for i in range(11):
		HeroFx.step(game, 0.1)
	check(int(game.state.hp) == hp - 1, "poison hurts once a second, through the short invulnerability")
	var lines := FrostCombat.status_lines(game)
	check(lines.size() == 1 and str(lines[0].text).begins_with("GIFT"), "the hero panel lists the poison")
	HeroFx.clear(game)
	HeroFx.apply(game, "regen", 10.0, 1.0)
	for i in range(11):
		HeroFx.step(game, 0.1)
	check(int(game.state.hp) == hp, "regeneration heals half a heart")
	HeroFx.apply(game, "silence", 3.0, 1.0)
	check(not FrostCombat.can_cast(game, "2"), "silenced, no skills")
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


func test_items_are_item_system_2() -> void:
	var game := await _new()
	check(game.story_items != null and game.inventory_panel != null, "the Frostgruft runs item system 2")
	var ev := InputEventKey.new()
	ev.keycode = KEY_I
	ev.pressed = true
	game._unhandled_input(ev)
	check(game.inventory_panel.open, "I opens the inventory")
	game.inventory_panel.set_open(false)
	var m := _mob(game, Vector2(100, 0))
	m.face = Vector2.LEFT
	game._damage_mob(m, Vector2.ZERO)
	var base: float = 400.0 - m.hp
	_equip(game, game.story_items.inventory.make_weapon("waraxe", true, ""))
	m.hp = 400.0
	game._damage_mob(m, Vector2.ZERO)
	check(400.0 - m.hp > base * 1.5, "the war axe hits much harder than the start weapon")
	await _free(game)


func test_subclass_with_weapon() -> void:
	var d := MetaStore.data()
	var store := MetaStore.fresh(d)
	store.crystals = 99
	MetaStore.choose_sub(d, store, "swordsman", "axe")
	MetaStore.save_store(store, SAVE)
	var game := await _new()
	check(not game.sub_kit.is_empty(), "the axe warrior runs with items")
	var m := _mob(game, Vector2(100, 0))
	game._fire(Vector2.RIGHT)
	var base: float = 400.0 - m.hp
	_equip(game, game.story_items.inventory.make_weapon("waraxe", true, ""))
	m.hp = 400.0
	game.state.cool = 0.0
	game._fire(Vector2.RIGHT)
	check(400.0 - m.hp > base * 1.5, "a stronger weapon lifts the subclass attack too")
	await _free(game)
