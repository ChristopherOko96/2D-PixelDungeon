extends SceneTree
## Potions in the story worlds (src/hero/story_items.gd over src/items/inventory.gd):
## what a potion does to the hero's life over time (regeneration heals, a drunk
## fire or poison potion hurts, the blasting potion hurts its drinker) reaches
## the story hero and is not written back over by the item rules' shadow hero.
## Gameplay review 2026-11 (production/qa/evidence/gameplay-review/BEWERTUNG.md
## checklist 1, 3, 4, 5, 7): necromancer finds, weighted potions and floor finds,
## curses that never kill, the risk lines, the last colour, and the second use of
## every potion (after-effects, thrown buffs, shield cap, haste attack rate).

const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
var checked := 0
var failures: Array[String] = []
var g: Node


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("STORY_POTIONS_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	g = KryptaScene.instantiate()
	g.class_id = "swordsman"
	g.settings_path = "user://settings_test.cfg"
	root.add_child(g)
	for i in range(30): await process_frame
	await _test_regeneration_heals_over_time()
	await _test_drunk_fire_burns_the_drinker()
	await _test_drunk_poison_hurts_the_drinker()
	await _test_blasting_potion_hurts_its_drinker()
	await _test_fire_leaves_fireproof_after_its_burn()
	await _test_ice_douses_and_slows_mildly()
	await _test_poison_leaves_poisonproof()
	await _test_blind_and_blast_reach_monsters()
	_test_thrown_strength_is_weaker_and_keeps_a_drunk_one()
	_test_shield_charges_are_capped()
	_test_haste_shortens_the_attack_pause()
	_test_ally_buff_runs_out()
	_test_curses_never_kill()
	_test_risk_lines()
	_test_last_colour_is_learned()
	_test_floor_finds()
	_test_necromancer_finds_only_what_he_can_wear()
	_test_potions_are_weighted()
	g.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile_test.json"))
	print("STORY_POTIONS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## Drinks `kind` with the hero at 10 of 20 life and no invulnerability
## (`fresh`: running potion effects are cleared first).
func _drink(kind: String, fresh := true) -> void:
	_use(kind, "inv_drink", fresh)


## Throws `kind` at the hero's own feet.
func _throw(kind: String, fresh := true) -> void:
	_use(kind, "inv_throw", fresh)


func _use(kind: String, action: String, fresh: bool) -> void:
	var items = g.story_items
	if fresh:
		items.effects.clear()
		g.state.max_hp = 20
		g.state.hp = 10
	g.state.inv = 0.0
	var inv = items.inventory
	inv.add(items.players[1], inv.make_stack("potion", kind))
	var bag: Array = items.players[1].inventory.bag
	for i in range(bag.size()):
		if str((bag[i] as Dictionary).get("type", "")) == "potion" and str(bag[i].potion) == kind:
			items.act(action, i, Vector2(float(g.player.x), float(g.player.y)))
			return


func _potion(kind: String) -> Dictionary:
	return g.story_items.inventory.data.potions[kind]


## Runs the world until `seconds` of game time passed (state.t; frames and game time
## differ headless), keeping the hero open to harm.
func _advance(seconds: float) -> void:
	var until := float(g.state.t) + seconds
	var guard := 0
	while float(g.state.t) < until and guard < 5000:
		g.state.inv = 0.0
		guard += 1
		await process_frame


func _test_regeneration_heals_over_time() -> void:
	# Arrange / Act
	_drink("regeneration")
	await _advance(3.6)
	# Assert
	check(int(g.state.hp) > 10, "regeneration heals the hero over time (hp %d)" % int(g.state.hp))


func _test_drunk_fire_burns_the_drinker() -> void:
	# Arrange / Act
	_drink("fire")
	await _advance(2.0)
	# Assert
	check(int(g.state.hp) < 10, "a drunk fire potion burns the drinker (hp %d)" % int(g.state.hp))


func _test_drunk_poison_hurts_the_drinker() -> void:
	# Arrange / Act
	_drink("poison")
	await _advance(2.0)
	# Assert
	check(int(g.state.hp) < 10, "a drunk poison potion hurts the drinker (hp %d)" % int(g.state.hp))


func _test_blasting_potion_hurts_its_drinker() -> void:
	# Arrange / Act
	_drink("explosion")
	await _advance(0.2)
	# Assert
	check(int(g.state.hp) < 10, "the blasting potion explodes in the drinker's hands (hp %d)" % int(g.state.hp))


func _test_fire_leaves_fireproof_after_its_burn() -> void:
	# Arrange / Act
	var items = g.story_items
	_drink("fire")
	var early: bool = items.immune("lava")
	await _advance(float(_potion("fire").after_delay) + 0.4)
	var hero_fx: Dictionary = g.state.get("effects", {})
	hero_fx["burn"] = {"time": 3.0, "value": 1.0, "tick": 1.0}
	g.state.effects = hero_fx
	await _advance(0.1)
	# Assert
	check(not early, "the fire potion's immunity waits for its own burn to end")
	check(items.immune("lava") and items.immune("burn"), "after its burn a drunk fire potion makes the hero immune to lava and burning")
	check(not items.immune("poison"), "fire immunity does not cover poison")
	check(not (g.state.get("effects", {}) as Dictionary).has("burn"), "an immune hero shakes off a burning put on him")


func _test_ice_douses_and_slows_mildly() -> void:
	# Arrange
	var items = g.story_items
	_drink("fire")
	await _advance(0.2)
	var burning: bool = items.effects.has("burn")
	# Act
	_drink("ice", false)
	await _advance(0.1)
	# Assert
	check(burning and not items.effects.has("burn"), "the ice potion puts a burn out at once")
	check(is_equal_approx(float(items.effects.get("slow", {}).get("value", 0.0)), float(_potion("ice").slow)), "a drunk ice potion slows by its slow share")
	check(not items.effects.has("weak"), "a drunk ice potion no longer weakens the blows")
	check(items.immune("freeze") and items.immune("burn"), "after ice the hero is immune to cold and burning")


func _test_poison_leaves_poisonproof() -> void:
	# Arrange / Act
	var items = g.story_items
	_drink("poison")
	await _advance(float(_potion("poison").after_delay) + 0.4)
	# Assert
	check(items.immune("poison"), "after its poison a drunk poison potion makes the hero immune to poison")


func _test_blind_and_blast_reach_monsters() -> void:
	# Arrange: a monster of the floor beside the hero
	var mob: Dictionary = {}
	for m: Dictionary in g.mobs:
		if g._hittable(m) and not m.has("kit") and str(m.get("kind", "")) != "boss":
			mob = m
			break
	if mob.is_empty():
		# the start room is empty: a sturdy, idle skeleton guard of the Krypta stands in
		mob = g.monsters.spawn(g.state.room, Vector2(float(g.player.x) + 60.0, float(g.player.y)), "skelettwache")
		mob.spawn = 0.0
		mob.ai_off = true
		mob.hp = 60.0
		mob.max = 60.0
		await _advance(0.1)
	mob.p = Vector2(float(g.player.x) + 60.0, float(g.player.y))
	mob.stun = 0.0
	# Act
	_drink("blind")
	var stunned := float(mob.get("stun", 0.0))
	mob.p = Vector2(float(g.player.x) + 60.0, float(g.player.y))
	var hp_before := float(mob.hp)
	_drink("explosion")
	await _advance(0.05)
	# Assert
	check(stunned >= float(_potion("blind").lost) - 0.01, "a drunk blinding potion makes nearby monsters lose the hero (stun %.2f)" % stunned)
	check(float(mob.hp) < hp_before, "a drunk blasting potion also hits the monsters round the drinker")


func _test_thrown_strength_is_weaker_and_keeps_a_drunk_one() -> void:
	# Arrange / Act
	var items = g.story_items
	_throw("strength")
	var thrown: Dictionary = items.effects.get("strength", {}).duplicate()
	_drink("strength")
	_throw("strength", false)
	# Assert
	check(is_equal_approx(float(thrown.get("value", 0.0)), float(_potion("strength").throw_value)) and is_equal_approx(float(thrown.get("t", 0.0)), float(_potion("strength").throw_time)), "a thrown strength potion works weaker on the hero in its radius %s" % str(thrown))
	check(is_equal_approx(float(items.effects.strength.value), float(_potion("strength").value)), "a thrown strength potion does not replace a stronger drunk one")
	items.effects.clear()


func _test_shield_charges_are_capped() -> void:
	# Arrange
	var hero: Dictionary = g.story_items.players[1]
	var runtime: Dictionary = hero.get("perk_runtime", {})
	runtime.shield = int(_potion("shield").max_charges) - 1
	hero.perk_runtime = runtime
	# Act
	_drink("shield")
	# Assert
	check(int(hero.perk_runtime.shield) == int(_potion("shield").max_charges), "shield charges stop at max_charges (%d)" % int(hero.perk_runtime.shield))
	# Arrange / Act: a throw gives throw_charges
	hero.perk_runtime.shield = 0
	_throw("shield")
	check(int(hero.perk_runtime.shield) == int(_potion("shield").throw_charges), "a thrown shield potion gives the hero throw_charges (%d)" % int(hero.perk_runtime.shield))
	hero.perk_runtime.shield = 0


func _test_haste_shortens_the_attack_pause() -> void:
	# Arrange
	var items = g.story_items
	items.effects.clear()
	var base: float = items.rate_mult()
	# Act
	_drink("haste")
	# Assert
	check(is_equal_approx(items.rate_mult(), base * float(_potion("haste").rate)), "haste also shortens the attack pause by its rate")
	items.effects.clear()


func _test_ally_buff_runs_out() -> void:
	# Arrange
	var items = g.story_items
	var pet := {"dmg": 2.0}
	# Act
	items._buff(pet, "dmg", 1.0, 1.25)
	var buffed := float(pet.dmg)
	items._step_allies(1.1)
	# Assert
	check(is_equal_approx(buffed, 2.5), "a companion's strength buff raises its bite")
	check(is_equal_approx(float(pet.dmg), 2.0), "the companion's bite returns when the buff runs out")


func _test_curses_never_kill() -> void:
	# Arrange / Act / Assert
	var items = g.story_items
	g.state.max_hp = 20
	g.state.hp = 1
	items.dot_player(1, 1, "blood")
	check(int(g.state.hp) == 1, "the blood toll never takes the last LP (hp %d)" % int(g.state.hp))
	g.state.hp = 2
	g.state.inv = 0.0
	items.strike_at(Vector2.ZERO, 26.0, 0.7, 3, "spikes")
	check(int(g.state.hp) == 1, "a thorn spike leaves 1 LP (hp %d)" % int(g.state.hp))
	g.state.hp = 6
	items.dot_player(1, 1, "blood")
	check(int(g.state.hp) == 5, "the blood toll still costs 1 LP above that (hp %d)" % int(g.state.hp))
	g.state.hp = 10


func _test_risk_lines() -> void:
	# Arrange
	var inv = g.story_items.inventory
	inv.known.clear()
	var weapon: Dictionary = inv.make_weapon(str(inv.data.weapons[0].id), false, "")
	var gear_spec: Dictionary = inv.data.gear[0]
	var gear: Dictionary = inv.make_gear(str(gear_spec.id), false, "")
	var kinds: int = inv.data.potions.size()
	var harmful := 0
	for kind: String in inv.data.potions:
		if bool(inv.data.potions[kind].get("harmful", false)): harmful += 1
	# Act
	var weapon_lines: Array = inv.view(weapon).lines
	var gear_lines: Array = inv.view(gear).lines
	var potion_lines: Array = inv.view(inv.make_stack("potion", "healing")).lines
	# Assert
	check(weapon_lines.has("FLUCHRISIKO %d %%" % roundi(float(inv.data.curse_by_slot.weapon) * 100.0)), "an unknown weapon shows its curse risk %s" % str(weapon_lines))
	check(gear_lines.has("FLUCHRISIKO %d %%" % roundi(float(inv.data.curse_by_slot[str(gear_spec.slot)]) * 100.0)), "an unknown piece shows its slot's curse risk %s" % str(gear_lines))
	check(harmful == 5 and potion_lines.has("NOCH UNBEKANNT: %d SORTEN, %d SCHADEN BEIM TRINKEN" % [kinds, harmful]), "an unknown potion shows the kinds left and the harmful ones %s" % str(potion_lines))


func _test_last_colour_is_learned() -> void:
	# Arrange: all but two kinds known
	var inv = g.story_items.inventory
	var hero: Dictionary = g.story_items.players[1]
	inv.known.clear()
	var kinds: Array = inv.data.potions.keys()
	for i in range(kinds.size() - 2): inv.known[str(kinds[i])] = true
	# Act
	inv._learn(hero, str(kinds[kinds.size() - 2]))
	# Assert
	check(inv.known.size() == kinds.size(), "learning the second-last colour learns the last one too")
	check(str(hero.item_note).contains("Damit bleibt eine Farbe"), "the note names the last colour (%s)" % str(hero.item_note))
	inv.known.clear()


func _types(items: Array) -> Array:
	return items.map(func(item: Dictionary) -> String: return str(item.type))


func _test_floor_finds() -> void:
	# Arrange
	var inv = g.story_items.inventory
	# Act
	var one := _types(inv.floor_finds(1))
	var two := _types(inv.floor_finds(2))
	var four := _types(inv.floor_finds(4))
	var nine := _types(inv.floor_finds(9))
	var ten := _types(inv.floor_finds(10))
	# Assert
	check(one.has("crystal") and one.has("stone") and one.has("potion"), "floor 1: crystal, stone and a potion %s" % str(one))
	check(two.has("potion") and not two.has("stone"), "floor 2: a potion, no stone %s" % str(two))
	check(four == ["crystal"], "floor 4: the crystal alone %s" % str(four))
	check(nine.has("stone") and not ten.has("stone"), "stones on floor 9, none on floor 10")


func _class_of(inv: Variant, id: String) -> String:
	for w: Dictionary in inv.data.weapons:
		if str(w.id) == id: return str(w["class"])
	return ""


func _test_necromancer_finds_only_what_he_can_wear() -> void:
	# Arrange
	var inv = g.story_items.inventory
	var foreign := 0
	var gear := 0
	# Act
	for i in range(300):
		var item: Dictionary = inv._roll_weapon(float(i % 10) / 9.0, "necromancer", "common")
		if str(item.type) == "gear": gear += 1
		elif _class_of(inv, str(item.id)) != "necromancer": foreign += 1
	for floor_number in range(1, 11):
		for i in range(10):
			var drop: Dictionary = inv.guardian_drop(floor_number, "necromancer")
			if str(drop.type) == "weapon" and _class_of(inv, str(drop.id)) != "necromancer": foreign += 1
	# Assert
	check(foreign == 0, "a necromancer never finds a weapon he cannot wear (%d)" % foreign)
	check(gear > 0, "the necromancer finds gear in place of weapons")


func _test_potions_are_weighted() -> void:
	# Arrange
	var inv = g.story_items.inventory
	var counts := {}
	# Act
	for i in range(3000):
		var kind: String = inv._roll_potion()
		counts[kind] = int(counts.get(kind, 0)) + 1
	# Assert
	var healing := float(counts.get("healing", 0)) / 3000.0
	check(healing > 0.16 and healing < 0.26, "about a fifth of the potions heal (%.3f)" % healing)
	check(int(counts.get("aftershock", 0)) * 3 < int(counts.get("healing", 0)), "run potions are rare beside healing")
