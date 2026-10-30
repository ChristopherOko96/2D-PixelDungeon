extends SceneTree
## Permanent companions and threat (talents.json "pet", user decision
## 30.10.2026): the frost mage's water elemental, the beast master's wolf or
## bear and the necromancer's bone warrior come with a learned talent, stay
## across rooms, heal between fights and are only called again after they
## fell. Their two abilities fire on keys 5 and 6 and by themselves while
## auto-cast is on (right-click toggles it); the HUD shows them after R and
## the companion's life. Enemies fight whoever hurt them most (hero or
## companion), switching only for 10 % more; taunts win.

const Game = preload("res://src/game.gd")
const TalentCombat = preload("res://src/combat/talent_combat.gd")
const TalentBar = preload("res://src/ui/talent_bar.gd")
const SkillBar = preload("res://src/ui/skill_bar.gd")
var checked := 0
var failures: Array[String] = []
var game
var tc
var d: Dictionary


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("TALENT_PET_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _start()
	test_learned_elemental_is_there_from_the_start()
	test_companion_follows_into_the_next_room()
	test_fallen_companion_waits_for_its_talent()
	test_quiet_companion_heals()
	test_ice_lance_slows_and_frost_nova_freezes()
	test_auto_cast_fires_by_itself_until_toggled_off()
	test_keys_five_and_six_cast_and_toggle_bits_switch_auto()
	test_enemy_fights_whoever_hurt_it_most()
	test_threat_needs_ten_percent_more_to_switch()
	test_taunt_beats_threat_and_enemies_hurt_the_companion()
	test_hud_shows_companion_slots_and_life()
	test_bone_warrior_and_wolf_have_their_abilities()
	test_falcon_dives_bleeds_and_blinds()
	test_wolf_and_bear_wounds_bleed()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	game.queue_free()
	print("TALENT_PET checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _start() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://talent_pet_test_profile.json"
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 5151
	game._begin_run()
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	game.players[1].max_hp = 999
	game.players[1].hp = 999


## A frost mage (or another class) with the companion talent learned.
func _hero(class_id: String = "mage", ranks: Dictionary = {"frost_1": 2, "frost_3": 1}, companion: String = "") -> Dictionary:
	var player: Dictionary = game.players[1]
	player.class_id = class_id
	player.pos = Vector2(300, 240)
	game.enemies.clear()
	tc.reset(3)
	tc.set_build(1, {"class": class_id, "level": 30, "ranks": ranks, "bar": [], "companion": companion})
	return tc.runtime(1)


func _foe(offset: Vector2) -> Dictionary:
	var enemy: Dictionary = game._create_enemy("skeleton", Vector2(game.players[1].pos) + offset)
	enemy.hp = 999.0
	enemy.max_hp = 999.0
	enemy.aggro = true
	enemy.aggro_target = 1
	game.enemies.append(enemy)
	return enemy


func _tick(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		tc.step(1.0 / 30.0)
		t += 1.0 / 30.0


func test_learned_elemental_is_there_from_the_start() -> void:
	# Arrange / Act
	_hero()
	var pet: Dictionary = tc.permanent_pet(1)
	# Assert
	check(not pet.is_empty() and str(pet.kind) == "water_elemental", "a learned water elemental stands beside the hero at once")
	check(tc.cast_blocker(1, "frost_3") == "Begleiter lebt noch", "it cannot be called twice while it lives")
	_hero("mage", {"frost_1": 2})
	check(tc.permanent_pet(1).is_empty(), "without the talent there is no elemental")


func test_companion_follows_into_the_next_room() -> void:
	# Arrange
	_hero()
	var id := int(tc.permanent_pet(1).id)
	game.players[1].pos = Vector2(900, 500)
	# Act
	tc.room_changed()
	# Assert
	var pet: Dictionary = tc.permanent_pet(1)
	check(not pet.is_empty() and int(pet.id) == id, "the same companion comes into the next room")
	check(Vector2(pet.pos).distance_to(game.players[1].pos) < 40.0, "and appears beside its hero")


func test_fallen_companion_waits_for_its_talent() -> void:
	# Arrange
	var rt := _hero()
	tc.permanent_pet(1).hp = 0.0
	# Act
	_tick(0.1)
	tc.set_build(1, {"class": "mage", "level": 30, "ranks": {"frost_1": 2, "frost_3": 1}, "bar": []})
	# Assert
	check(tc.permanent_pet(1).is_empty(), "a fallen companion does not come back by itself mid-run")
	rt = tc.runtime(1)
	rt.res = float(rt.res_max)
	check(tc.cast(1, "frost_3", {"aim": Vector2.RIGHT}) and not tc.permanent_pet(1).is_empty(), "the talent calls it again")
	check(is_equal_approx(float(rt.cds.frost_3), float(d.talents.frost_3.cd)), "calling it again starts the talent's 30 s cooldown")


func test_quiet_companion_heals() -> void:
	# Arrange
	_hero()
	var pet: Dictionary = tc.permanent_pet(1)
	pet.hp = float(pet.hp_max) * 0.5
	# Act
	_tick(6.0)
	# Assert
	check(float(pet.hp) > float(pet.hp_max) * 0.6, "out of a fight the companion heals (%.1f / %.1f)" % [pet.hp, pet.hp_max])


func test_ice_lance_slows_and_frost_nova_freezes() -> void:
	# Arrange
	_hero()
	var pet: Dictionary = tc.permanent_pet(1)
	var far := _foe(Vector2(120, 0))
	pet.target = int(far.id)
	# Act
	var lanced: bool = tc.pet_cast(1, 0, true)
	# Assert
	check(lanced and Dictionary(far.get("statuses", {})).has("slow"), "Eislanze hits from afar and slows")
	check(not tc.pet_cast(1, 0, true), "Eislanze waits for its cooldown")
	var near := _foe(Vector2(pet.pos) - Vector2(game.players[1].pos) + Vector2(20, 0))
	check(tc.pet_cast(1, 1, true) and Dictionary(near.get("statuses", {})).has("freeze"), "Frostnova freezes an enemy beside the elemental")


func test_auto_cast_fires_by_itself_until_toggled_off() -> void:
	# Arrange
	var rt := _hero()
	var foe := _foe(Vector2(90, 0))
	# Act
	_tick(0.5)
	# Assert
	check(float(rt.pet_cds.get("ice_lance", 0.0)) > 0.0, "with auto-cast on the elemental casts Eislanze by itself")
	rt = _hero()
	tc.toggle_pet_auto(1, 0)
	tc.toggle_pet_auto(1, 1)
	foe = _foe(Vector2(90, 0))
	_tick(1.0)
	check(rt.pet_cds.is_empty() and float(foe.hp) < 999.0, "with auto-cast off it only shoots its normal bolts")


func test_keys_five_and_six_cast_and_toggle_bits_switch_auto() -> void:
	# Arrange
	var rt := _hero()
	var foe := _foe(Vector2(100, 0))
	tc.permanent_pet(1).target = int(foe.id)
	# Act
	tc.handle_input(1, game.players[1], {"skills": 1 << TalentCombat.PET_BIT})
	tc.handle_input(1, game.players[1], {"skills": 1 << (TalentCombat.PET_AUTO_BIT + 1)})
	# Assert
	check(float(rt.pet_cds.get("ice_lance", 0.0)) > 0.0, "key 5 casts the companion's first ability")
	check(not bool(rt.pet_auto[1]) and bool(rt.pet_auto[0]), "the toggle bit switches only that ability's auto-cast")


func test_enemy_fights_whoever_hurt_it_most() -> void:
	# Arrange
	_hero()
	var pet: Dictionary = tc.permanent_pet(1)
	var foe := _foe(Vector2(60, 0))
	# Act
	foe.threat = {1: 10.0, TalentCombat.PET_KEY - int(pet.id): 30.0}
	var forced: Dictionary = tc.forced_target(foe)
	# Assert
	check(int(forced.get("id", 0)) == TalentCombat.PET_KEY - int(pet.id), "the companion that hurt it most draws the enemy")
	check(int(foe.pet_focus) == int(pet.id), "the enemy now fights the companion")
	foe.threat = {1: 80.0, TalentCombat.PET_KEY - int(pet.id): 30.0}
	foe.threat_target = -1
	check(tc.forced_target(foe).is_empty() and int(foe.aggro_target) == 1, "a hero ahead in damage keeps it on the hero")


func test_threat_needs_ten_percent_more_to_switch() -> void:
	# Arrange
	_hero()
	var pet: Dictionary = tc.permanent_pet(1)
	var foe := _foe(Vector2(60, 0))
	var pet_key: int = TalentCombat.PET_KEY - int(pet.id)
	foe.threat = {1: 100.0, pet_key: 50.0}
	tc.forced_target(foe)
	# Act
	foe.threat[pet_key] = 105.0
	var close: Dictionary = tc.forced_target(foe)
	foe.threat[pet_key] = 115.0
	var ahead: Dictionary = tc.forced_target(foe)
	# Assert
	check(close.is_empty(), "5 % more is not enough to switch")
	check(int(ahead.get("id", 0)) == pet_key, "more than 10 % more switches the target")


func test_taunt_beats_threat_and_enemies_hurt_the_companion() -> void:
	# Arrange
	_hero()
	var pet: Dictionary = tc.permanent_pet(1)
	var foe := _foe(Vector2(pet.pos) - Vector2(game.players[1].pos) + Vector2(14, 0))
	foe.threat = {1: 500.0}
	foe.pet_taunt = {"pet": int(pet.id), "time": 3.0}
	# Act
	var forced: Dictionary = tc.forced_target(foe)
	var before := float(pet.hp)
	tc._step_pets(1.0)
	# Assert
	check(int(forced.get("id", 0)) == TalentCombat.PET_KEY - int(pet.id), "a taunt wins over the damage tally")
	check(float(pet.hp) < before, "an enemy fighting the companion in reach hurts it")


func test_hud_shows_companion_slots_and_life() -> void:
	# Arrange
	var rt := _hero()
	rt.pet_auto[1] = false
	# Act
	var state: Dictionary = tc.player_state(1)
	var slots: Array = TalentBar.new().skill_slots(state)
	# Assert
	check(str(state.pet.name) == "Wasserelementar" and float(state.pet.hp) > 0.0, "the HUD knows the companion and its life")
	# 1-4, R, Shift (the defense), then the companion on 5 and 6
	check(slots.size() == 8 and str(slots[6].key) == "5" and str(slots[7].key) == "6", "the companion's abilities sit on 5 and 6 after R and Shift")
	check(bool(slots[6].auto) and not bool(slots[7].auto), "the slot shows whether auto-cast is on")
	check(TalentBar.pet_slot(slots, 7) == 1 and TalentBar.pet_slot(slots, 4) == -1 and TalentBar.pet_slot(slots, 5) == -1, "a click on slot 6 is the second ability, R and Shift are none")
	var screen := Vector2(1280, 720)
	var found := -1
	for x in range(0, 1280, 4):
		if SkillBar.slot_at(screen, slots, Vector2(x, SkillBar.top(screen, false) + 20.0)) == 6:
			found = x
			break
	check(found > 0, "the HUD finds the companion icon under the mouse")


func test_bone_warrior_and_wolf_have_their_abilities() -> void:
	# Arrange / Act
	_hero("necromancer", {"minion_1": 1})
	var warrior: Dictionary = tc.permanent_pet(1)
	_hero("archer", {"beast_1": 1}, "bear")
	var bear: Dictionary = tc.permanent_pet(1)
	# Assert
	check(not warrior.is_empty() and str(tc.pet_ability(str(warrior.kind), 0).name) == "Schildschlag", "the necromancer's bone warrior bashes with its shield")
	check(not bear.is_empty() and str(tc.pet_ability(str(bear.kind), 1).name) == "Brüllen", "the bear roars")
	check(float(bear.life) == INF, "the beast master's companion stays for good")


func test_falcon_dives_bleeds_and_blinds() -> void:
	# Arrange (user wish 30.10.2026: a falcon beside wolf and bear)
	check(d.pet.kinds.has("falcon") and not bool(d.pet.kinds.falcon.get("summon_only", false)), "the beast master can choose a falcon")
	_hero("archer", {"beast_1": 1}, "falcon")
	var falcon: Dictionary = tc.permanent_pet(1)
	check(not falcon.is_empty() and str(falcon.kind) == "falcon", "the chosen falcon flies beside the hero")
	var prey := _foe(Vector2(150, 0))
	falcon.target = int(prey.id)
	tc.events.clear()
	# Act
	var dived: bool = tc.pet_cast(1, 0, true)
	# Assert
	check(dived and Dictionary(prey.get("statuses", {})).has("bleed"), "Sturzflug reaches 5 m away and makes it bleed")
	check(tc.events.any(func(e: Dictionary) -> bool: return str(e.kind) == "dive"), "the falcon swoops down (dive event)")
	check(tc.events.any(func(e: Dictionary) -> bool: return str(e.kind) == "pet_strike" and str(e.wound) == "blood"), "the wound shows blood")
	var blind: bool = tc.pet_cast(1, 1, true)
	check(blind and Dictionary(prey.get("statuses", {})).has("freeze"), "Augenhacker blinds: the enemy stands still")


func test_wolf_and_bear_wounds_bleed() -> void:
	# Arrange
	_hero("archer", {"beast_1": 1}, "wolf")
	var wolf: Dictionary = tc.permanent_pet(1)
	var prey := _foe(Vector2(wolf.pos) - Vector2(game.players[1].pos) + Vector2(20, 0))
	wolf.target = int(prey.id)
	# Act / Assert
	check(tc.pet_cast(1, 0, true) and Dictionary(prey.get("statuses", {})).has("bleed") and Dictionary(prey.get("statuses", {})).has("slow"), "Zerfleischen bleeds and slows")
	_hero("archer", {"beast_1": 1}, "bear")
	var bear: Dictionary = tc.permanent_pet(1)
	var victim := _foe(Vector2(bear.pos) - Vector2(game.players[1].pos) + Vector2(20, 0))
	check(tc.pet_cast(1, 0, true) and Dictionary(victim.get("statuses", {})).has("bleed"), "Prankenhieb makes everyone it hits bleed")
