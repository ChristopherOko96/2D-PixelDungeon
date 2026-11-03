extends "res://tests/soul_guardian_commands_test.gd"
## Current shared host runtime, controlled layout, no network/campaign claim.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos": Vector2(300, 240), "class_id": "necromancer", "hp": 100, "max_hp": 100, "damage": 10.0, "aim": Vector2.RIGHT}
	game.current_layout = {"id": "soul-attacks", "tile_size": 32, "play_bounds": [0, 0, 1408, 704], "world_size": [1408, 704], "obstacles": []}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	test_lance_holds_spends_souls_and_releases_once()
	test_ring_is_large_hollow_and_pushes_without_crossing_walls()
	test_story_ids_hold_targets_and_cover_is_routed()
	test_soul_shots_stop_at_first_contact_even_on_long_ticks()
	test_full_charge_is_bounded_and_cancelled_by_modal_or_death()
	test_every_companion_strikes_promptly_and_pursues_away_from_owner()
	game.queue_free()
	await process_frame
	print("NECRO_SOUL_ATTACKS checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_lance_holds_spends_souls_and_releases_once() -> void:
	var rt := _setup(d.talents.soul_9)
	rt.bar = ["soul_9"]
	var start := float(rt.res)
	tc.handle_input(1, game.players[1], {"skills": 1 << tc.BAR_BIT, "aim": Vector2.RIGHT})
	check(game.bullets.is_empty() and rt.has("soul_charge"), "lance prepares while held instead of firing immediately")
	if not rt.has("soul_charge"): return
	_tick(0.8)
	check(float(rt.res) < start - float(d.talents.soul_9.cost) and float(rt.res) >= 0, "charge consumes additional real souls without negative balance")
	check(game.bullets.is_empty(), "held partial charge remains at caster")
	tc.handle_input(1, game.players[1], {"skills": 0, "aim": Vector2.RIGHT})
	check(game.bullets.size() == 1 and not rt.has("soul_charge"), "release fires exactly one lance")
	if game.bullets.is_empty(): return
	var shot: Dictionary = game.bullets[0]
	check(float(shot.radius) > 8 and int(shot.pierce) == 0 and float(shot.damage) > 20, "charged attack grows and stops at enemy contact")
	tc.handle_input(1, game.players[1], {"skills": 0, "aim": Vector2.RIGHT})
	check(game.bullets.size() == 1, "repeated release does not duplicate shot")
	rt = _setup(d.talents.soul_9)
	rt.bar = ["soul_9"]
	rt.res = float(d.talents.soul_9.cost) + 1.0
	tc.handle_input(1, game.players[1], {"skills": 1 << tc.BAR_BIT, "aim": Vector2.RIGHT})
	_tick(0.4)
	check(float(rt.res) >= 0 and not rt.has("soul_charge"), "insufficient extra souls release only an affordable partial charge")
	rt = _setup(d.talents.soul_9)
	tc.cast(1, "soul_9")
	tc.room_changed()
	_tick(2.0)
	check(not rt.has("soul_charge") and game.bullets.is_empty(), "room change cancels unfinished charge")

func test_ring_is_large_hollow_and_pushes_without_crossing_walls() -> void:
	_setup(d.talents.soul_3)
	var enemy := _dummy(Vector2(380, 240))
	var boss := _dummy(Vector2(300, 320), true)
	_cast(d.talents.soul_3)
	check(float(tc.zones[0].r) == 160 and float(tc.zones[0].inner_r) == 96, "ten metre diameter, two metre wide puddle, six metre clear middle")
	_tick(0.35)
	check(Vector2(enemy.pos).x > 400 and Vector2(boss.pos) == Vector2(300, 320), "nova pushes normal enemies outward while boss remains grounded")
	check(not tc._in_zone(tc.zones[0], {"pos": Vector2(300, 240), "radius": 14}), "caster's center remains outside puddle")
	_setup(d.talents.soul_3)
	game.current_layout.obstacles = [[425, 0, 16, 704]]
	enemy = _dummy(Vector2(395, 240))
	_cast(d.talents.soul_3)
	_tick(0.4)
	check(Vector2(enemy.pos).x < 425 - float(enemy.radius), "outward push never tunnels through wall")
	game.current_layout.obstacles = []

func test_full_charge_is_bounded_and_cancelled_by_modal_or_death() -> void:
	var rt := _setup(d.talents.soul_9)
	var before := float(rt.res)
	check(tc.cast(1, "soul_9", {"charge": 999999, "damage": 999999, "aim": Vector2.RIGHT}), "normal learned lance accepts charge request without trusting supplied power")
	tc.SoulCharge.step(tc, 1, 10.0)
	check(game.bullets.size() == 1 and not rt.has("soul_charge"), "large time step releases one maximum charge")
	if not game.bullets.is_empty():
		check(float(game.bullets[0].charge) == 1 and float(game.bullets[0].radius) == 19 and float(game.bullets[0].damage) <= 50, "host clamps charge, radius and damage independently of packet extras")
	check(is_equal_approx(before - float(rt.res), 42.0), "full charge pays exactly twenty-two plus twenty souls")
	rt = _setup(d.talents.soul_9)
	tc.cast(1, "soul_9")
	rt.defense.held = true
	tc.handle_input(1, game.players[1], {"skills": 1 << tc.CANCEL_BIT})
	tc.step(2.0)
	check(not rt.has("soul_charge") and game.bullets.is_empty() and not bool(rt.defense.held), "modal cancel never fires a charge or retains held defense")
	rt = _setup(d.talents.soul_9)
	tc.cast(1, "soul_9")
	game.players[1].hp = 0
	tc.step(2.0)
	check(not rt.has("soul_charge") and game.bullets.is_empty(), "dead caster cannot release a delayed shot")

func test_every_companion_strikes_promptly_and_pursues_away_from_owner() -> void:
	for kind: String in d.pet.kinds:
		var rt := _setup(d.talents.soul_1)
		tc._spawn_pet(1, rt, "soul_1", {"pet_kind": kind, "hp": 50, "every": 1.0, "dmg": 1.0}, Vector2(300, 240), false, 30.0)
		var pet: Dictionary = tc.pets[0]
		var victim := _dummy(Vector2(335, 240))
		_tick(0.3)
		if kind in ["poison_worm","fire_worm"]:
			check(not tc.forest_summons.flights.is_empty(), "%s launches its delayed spit after wind-up" % kind)
			_tick(0.6)
			var hp := float(victim.hp)
			game.boss_moves.update(1.0)
			check(float(victim.hp)<hp,"%s landed pool actually damages the victim"%kind)
		else:
			check(float(victim.hp) < float(victim.max_hp), "%s starts attacking after its short rig wind-up" % kind)
		game.players[1].pos = Vector2(100, 240)
		victim.pos = Vector2(800, 240)
		var before: Vector2 = pet.pos
		_tick(0.15)
		check(int(pet.target) == int(victim.id) and Vector2(pet.pos).x > before.x, "%s pursues its enemy while owner leaves in opposite direction" % kind)

func test_story_ids_hold_targets_and_cover_is_routed() -> void:
	var rt := _setup(d.talents.soul_1)
	var actor := {"owner": 1, "pos": Vector2(300, 240), "target": -1}
	var victim := _dummy(Vector2(350, 240))
	victim.id = "skeleton"
	victim.tid = 42
	tc._pet_prey(actor, game.players[1])
	check(int(actor.target) == 42, "story companion stores stable numeric tid rather than species string")
	victim.pos = Vector2(800, 240)
	game.players[1].pos = Vector2(1200, 240)
	check(is_same(tc._pet_prey(actor, game.players[1]), victim), "stable target remains locked when hero runs away")
	_setup(d.talents.soul_1)
	game.current_layout.obstacles = [[330, 200, 16, 80]]
	victim = _dummy(Vector2(380, 240))
	actor = {"owner": 1, "pos": Vector2(300, 240), "target": -1}
	check(not tc._pet_prey(actor, game.players[1]).is_empty(), "nearby reachable enemy behind small cover is acquired without owner attacking")
	game.current_layout.obstacles = []
	rt.hero_target = -1

func test_soul_shots_stop_at_first_contact_even_on_long_ticks() -> void:
	_setup(d.talents.soul_1)
	game.current_layout.obstacles = [[500, 0, 16, 704]]
	var front := _dummy(Vector2(420, 240))
	var behind := _dummy(Vector2(550, 240))
	_cast(d.talents.soul_1)
	game._simulate_bullets(0.7)
	check(front.hp < front.max_hp and behind.hp == behind.max_hp, "first enemy before wall is hit during a long host tick")
	check(game.bullets.is_empty(), "bolt is consumed by first enemy")
	check(tc.events.any(func(e: Dictionary) -> bool: return str(e.kind) == "soul_impact"), "host supplies exact impact event for soul particles")
	_setup(d.talents.soul_1)
	var hidden := _dummy(Vector2(550, 240))
	_cast(d.talents.soul_1)
	game._simulate_bullets(0.7)
	check(hidden.hp == hidden.max_hp and game.bullets.is_empty(), "large soul bolt cannot cross thin wall")
	game.current_layout.obstacles = []
