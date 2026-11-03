extends "res://tests/soul_guardian_test.gd"
## Real host death callback and validated 5/6 routing, not cosmetic summons.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://guardian_commands_test.json"
	game.players[1] = {"pos": Vector2(300, 240), "class_id": "necromancer", "hp": 100, "max_hp": 100, "damage": 10.0, "aim": Vector2.RIGHT}
	game.current_layout = {"id": "guardian-commands", "tile_size": 32, "play_bounds": [0, 0, 1280, 720], "world_size": [1280, 720], "obstacles": []}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	test_lethal_hit_converts_once_for_fifteen_seconds()
	test_expired_marks_bosses_and_caps()
	test_beam_input_windup_direction_and_walls()
	test_guardian_owns_two_slots_only_while_present()
	test_respec_restores_normal_companion_commands()
	game.queue_free()
	await process_frame
	print("GUARDIAN_COMMANDS checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_lethal_hit_converts_once_for_fifteen_seconds() -> void:
	var rt := _setup(d.talents.soul_14)
	var victim := _dummy(Vector2(360, 240))
	victim.hp = 1.0
	victim.rig = "skel_guard"
	_cast(d.talents.soul_14)
	_tick(1.2)
	var army: Array = tc.pets.filter(func(p: Dictionary) -> bool: return bool(p.get("converted", false)))
	check(army.size() == 1, "lethal guardian hit marks before host death callback")
	if army.is_empty(): return
	check(str(army[0].rig) == "skel_guard", "underling retains defeated enemy rig")
	check(float(army[0].life) > 14 and float(army[0].life) <= 15, "underling has fifteen-second lifetime")
	tc.enemy_killed(victim, 1)
	check(tc.pets.size() == 1, "duplicate death notification cannot duplicate underling")
	var foe := _dummy(Vector2(380, 240))
	_tick(1.6)
	check(foe.hp < foe.max_hp, "converted enemy actually attacks host enemies")
	tc.guardians.actors.clear()
	_tick(13.6)
	check(not tc.pets.any(func(p: Dictionary) -> bool: return bool(p.get("converted", false))), "underling expires independently after guardian is gone")
	check(float(rt.res) <= float(rt.res_max), "conversion cannot overfill souls")

func test_expired_marks_bosses_and_caps() -> void:
	_setup(d.talents.soul_14)
	_cast(d.talents.soul_14)
	var guardian: Dictionary = tc.guardians.actors[0]
	var stale := _dummy(Vector2(600, 240))
	tc.guardians.mark(tc, guardian, stale)
	tc.guardians.actors.clear()
	_tick(8.2)
	stale.hp = 0.0
	tc.enemy_killed(stale, 1)
	check(tc.pets.is_empty(), "expired mark cannot raise an enemy")
	for i in range(6):
		var victim := _dummy(Vector2(370, 240 + i * 8))
		tc.guardians.mark(tc, guardian, victim)
		victim.hp = 0.0
		tc.enemy_killed(victim, 1)
	check(tc.pets.size() == 4, "per-owner underling population bounded at four")
	var boss := _dummy(Vector2(370, 240), true)
	tc.guardians.mark(tc, guardian, boss)
	check(not boss.has("soul_claim"), "boss cannot receive conversion mark")
	var summon := _dummy(Vector2(370, 240))
	summon.summoned = true
	tc.guardians.mark(tc, guardian, summon)
	check(not summon.has("soul_claim"), "hostile summoned units cannot be farmed into underlings")
	tc.room_changed()
	check(tc.pets.is_empty(), "room transition clears underlings")

func test_beam_input_windup_direction_and_walls() -> void:
	_setup(d.talents.soul_14)
	var front := _dummy(Vector2(460, 240))
	var behind := _dummy(Vector2(200, 240))
	var side := _dummy(Vector2(460, 330))
	_cast(d.talents.soul_14)
	_tick(0.7)
	var before := float(front.hp)
	tc.handle_input(1, game.players[1], {"skills": 1 << tc.PET_BIT, "aim": Vector2.RIGHT})
	check(str(tc.guardians.actors[0].motion) == "beam", "key five routes to active soul guardian")
	_tick(0.3)
	check(is_equal_approx(float(front.hp), before), "beam cannot damage before windup")
	game.players[1].aim = Vector2.LEFT
	_tick(0.6)
	check(front.hp < before and behind.hp == behind.max_hp and side.hp == side.max_hp, "beam keeps locked direction and real width")
	check(front.has("soul_claim"), "beam applies conversion debuff")
	check(not tc.pet_cast(1, 0, true), "held five cannot restart cooldown/channel")
	_setup(d.talents.soul_14)
	game.current_layout.obstacles = [[400, 0, 16, 720]]
	var hidden := _dummy(Vector2(460, 240))
	_cast(d.talents.soul_14)
	_tick(0.7)
	tc.handle_input(1, game.players[1], {"skills": 1 << tc.PET_BIT, "aim": Vector2.RIGHT})
	_tick(1.5)
	check(hidden.hp == hidden.max_hp and not hidden.has("soul_claim"), "beam stops at wall before hidden target")
	game.current_layout.obstacles = []

func test_guardian_owns_two_slots_only_while_present() -> void:
	_setup(d.talents.soul_14)
	_cast(d.talents.soul_14)
	_tick(0.7)
	var hud: Dictionary = tc.player_state(1).pet
	check(str(hud.kind) == "soul_guardian" and hud.abilities.size() == 2, "shared companion HUD exposes both guardian commands")
	check(hud.abilities[0].key == "5" and hud.abilities[1].key == "6", "beam five / wave six")
	check(not bool(hud.abilities[0].auto) and bool(hud.abilities[1].auto), "beam manual by default; existing wave remains automatic")
	check(tc.pet_cast(1, 1, true), "key six can trigger existing soul wave manually")
	tc.guardians.actors.clear()
	check(tc.player_state(1).pet.is_empty(), "guardian command bar goes when summon ends")

func test_respec_restores_normal_companion_commands() -> void:
	var rt := _setup(d.talents.soul_14)
	var before: Array = rt.pet_auto.duplicate()
	_cast(d.talents.soul_14)
	_tick(0.7)
	tc.toggle_pet_auto(1, 0)
	check(rt.pet_auto == before and bool(tc.guardians.actors[0].autos[0]), "guardian toggle never overwrites permanent companion's auto flags")
	# The live tree permits only one branch. Test the actual reset/build switch,
	# rather than claiming that a soul/minion mixed build can be learned.
	tc.set_build(1, {"class": "necromancer", "level": 30, "ranks": {"minion_1": 1}, "bar": ["minion_1"]})
	check(tc.cast(1,"minion_1"),"respec warrior must be explicitly summoned")
	_tick(0.1)
	var bone: Dictionary = tc.permanent_pet(1)
	check(not bone.is_empty() and tc.guardians.actors.is_empty(), "respec replaces guardian with legal bone companion")
	check(str(tc.player_state(1).pet.kind) == "bone_warrior" and tc.runtime(1).pet_auto == before, "normal companion HUD and flags return after respec")
