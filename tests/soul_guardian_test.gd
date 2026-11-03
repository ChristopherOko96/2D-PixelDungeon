extends "res://tests/talent_combat_test.gd"
## Real talent runtime: summon timing, damage ownership, collision, shared CC,
## lifetime, stages and serializable client state. No earned campaign claim.

func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://soul_guardian_test_profile.json"
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 4242
	game._begin_run()
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	game.players[1].max_hp = 999
	game.players[1].hp = 999
	check(str(d.talents.soul_14.type) == "soul_guardian", "Seele ultimate is the approved summon")
	if str(d.talents.soul_14.type) == "soul_guardian":
		test_summon_has_windup_cost_and_bounded_lifetime()
		test_grasp_shares_field_lockout_and_boss_immunity()
		test_target_priority_wall_checks_and_owner_cleanup()
		test_field_priority_and_directional_wave_bounds()
		test_stages_and_snapshot_roundtrip()
		test_actual_arena_preset_exposes_guardian_and_field()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	game._leave_session()
	game.queue_free()
	await process_frame
	print("SOUL_GUARDIAN checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_summon_has_windup_cost_and_bounded_lifetime() -> void:
	var rt := _setup(d.talents.soul_14)
	var prey := _dummy(Vector2(370, 240))
	var resource := float(rt.res)
	check(_cast(d.talents.soul_14), "ultimate casts")
	check(tc.guardians.actors.size() == 1 and tc.pets.is_empty(), "one guardian, separate from bone/animal companions")
	check(is_equal_approx(float(rt.res), resource - float(d.talents.soul_14.cost)), "summon spends real mana")
	check(is_equal_approx(float(rt.cds.soul_14), 60.0), "minute cooldown retained")
	check(not tc.cast(1, "soul_14"), "holding/repeating R cannot create another guardian")
	_tick(0.3)
	check(float(prey.hp) == float(prey.max_hp), "no instant harvest or damage while emerging")
	_tick(2.2)
	check(float(prey.hp) < float(prey.max_hp), "guardian deals real delayed combat damage")
	check(int(prey.get("last_hit_owner", -1)) == 1 or int(prey.get("last_damage_owner", -1)) == 1 or int(prey.get("talent_mark", {}).get("owner", -1)) == 1 or not prey.get("threat", {}).is_empty(), "damage goes through host credit/threat")
	check(not tc.events.any(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "soul"), "removed harvest does not heal/drain on cast")
	_tick(8.8)
	var hp_before := float(prey.hp)
	_tick(0.4)
	check(float(prey.hp) == hp_before, "dissolve phase deals no damage")
	_tick(0.5)
	check(tc.guardians.actors.is_empty(), "guardian disappears after configured twelve seconds")

func test_grasp_shares_field_lockout_and_boss_immunity() -> void:
	_setup(d.talents.soul_14)
	var prey := _dummy(Vector2(360, 240))
	_cast(d.talents.soul_14)
	_tick(1.05)
	check(prey.statuses.has("soul_bind"), "grasp briefly binds normal target on impact")
	var left := float(prey.get("soul_grasp_wait", 0.0))
	tc._soul_grasp({"owner": 1, "pos": prey.pos, "talent": "soul_11", "info": d.talents.soul_11}, prey)
	check(is_equal_approx(float(prey.soul_grasp_wait), left), "field cannot restart guardian stun lockout")
	check(float(prey.statuses.get("soul_bind", {}).get("time", 0.0)) <= float(d.talents.soul_14.bind_stun), "stun remains short")
	_setup(d.talents.soul_14)
	var boss := _dummy(Vector2(360, 240), true)
	_cast(d.talents.soul_14)
	_tick(2.0)
	check(float(boss.hp) < float(boss.max_hp) and not boss.statuses.has("soul_bind"), "boss takes damage without being stunned")

func test_target_priority_wall_checks_and_owner_cleanup() -> void:
	var rt := _setup(d.talents.soul_14)
	_dummy(Vector2(350, 240))
	var chosen := _dummy(Vector2(410, 240))
	rt.hero_target = int(chosen.id)
	_cast(d.talents.soul_14)
	_tick(0.7)
	check(int(tc.guardians.actors[0].target) == int(chosen.id), "guardian prioritizes the hero's attack target")
	var original_layout: Dictionary = game.current_layout
	game.current_layout = {"world_size": [896, 480], "play_bounds": [32, 32, 832, 416], "obstacles": [[380, 32, 32, 416]], "exits": []}
	var before := float(chosen.hp)
	_tick(3.0)
	check(float(chosen.hp) == before, "attacks and waves never cross a wall")
	check(Vector2(tc.guardians.actors[0].pos).x < 380.0, "guardian collision prevents crossing the wall")
	game.players[1].hp = 0
	_tick(0.1)
	check(tc.guardians.actors.is_empty(), "dead owner cancels the summon")
	game.current_layout = original_layout
	_setup(d.talents.soul_14)
	_cast(d.talents.soul_14)
	tc._event("guardian_wave", Vector2(320, 240), 128.0, {"talent": "soul_14", "owner": 1, "angle": 0.0, "arc": 1.2, "life": 0.55})
	tc.room_changed()
	check(tc.guardians.actors.is_empty(), "room change removes transient guardian")
	check(not tc.events.any(func(e: Dictionary) -> bool: return str(e.get("talent", "")) == "soul_14"), "room change removes guardian cast/wave presentation too")

func test_field_priority_and_directional_wave_bounds() -> void:
	var original: Dictionary = game.current_layout
	game.current_layout = {"world_size": [896, 480], "play_bounds": [32, 32, 832, 416], "obstacles": [], "exits": []}
	var rt := _setup(d.talents.soul_14)
	var near := _dummy(Vector2(350, 240))
	var in_field := _dummy(Vector2(440, 240))
	tc.zones.append({"owner": 1, "talent": "soul_11", "pos": in_field.pos, "r": 20.0, "time": 3.0, "tick": 10.0, "every": 0.8, "dmg": 0.0, "info": d.talents.soul_11})
	_cast(d.talents.soul_14)
	_tick(0.7)
	check(int(tc.guardians.actors[0].target) == int(in_field.id), "own field target beats a closer uncommanded enemy")
	rt.hero_target = int(near.id)
	check(int(tc.guardians._prey(tc, tc.guardians.actors[0], game.players[1], rt).id) == int(near.id), "explicit hero target beats field preference")
	rt = _setup(d.talents.soul_14)
	game.current_layout = {"world_size": [896, 480], "play_bounds": [32, 32, 832, 416], "obstacles": [[380, 248, 32, 32]], "exits": []}
	var front := _dummy(Vector2(430, 240))
	var rear := _dummy(Vector2(290, 240))
	var outside := _dummy(Vector2(600, 240))
	var occluded := _dummy(Vector2(420, 268))
	rt.hero_target = int(front.id)
	_cast(d.talents.soul_14)
	tc.guardians.actors[0].wave_wait = 0.0
	_tick(1.1)
	check(float(front.hp) < float(front.max_hp), "forward wave deals actual damage")
	check(float(rear.hp) == float(rear.max_hp), "wave cone leaves enemies behind unharmed")
	check(float(outside.hp) == float(outside.max_hp), "wave range is bounded")
	check(float(occluded.hp) == float(occluded.max_hp), "wave cannot hit an occluded target inside its cone")
	check(int(rt.hero_target) == int(front.id), "secondary hits preserve the hero's commanded target")
	check(tc.events.any(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "guardian_wave"), "wave emits authoritative presentation event")
	game.current_layout = original

func test_stages_and_snapshot_roundtrip() -> void:
	var rt := _setup(d.talents.soul_14)
	rt.soul_tier = 2
	_cast(d.talents.soul_14)
	var guardian: Dictionary = tc.guardians.actors[0]
	check(is_equal_approx(float(guardian.total), 16.0), "second stage extends service to sixteen seconds")
	check(float(guardian.info.wave_damage) > float(d.talents.soul_14.wave_damage), "third stage strengthens the soul wave")
	var snap: Dictionary = tc.snapshot()
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(snap))
	check(decoded.guardians.size() == 1 and str(decoded.guardians[0].motion) == "spawn", "clients receive guardian and current animation phase")
	check(not decoded.guardians[0].has("info") and not decoded.guardians[0].has("damage"), "snapshot contains presentation, not mutable combat config")
	snap.guardians[0].x = -999.0
	check(Vector2(guardian.pos).x != -999.0, "client snapshot does not alias host state")
	tc.reset()
	check(tc.guardians.actors.is_empty(), "new run clears guardians")

func test_actual_arena_preset_exposes_guardian_and_field() -> void:
	game.player_classes[1] = "necromancer"
	game.players[1].class_id = "necromancer"
	var arena = load("res://src/debug/test_arena.gd").new()
	arena.game = game
	arena._specs = d.classes.necromancer.specs
	arena._spec_pick = OptionButton.new()
	arena.add_child(arena._spec_pick)
	arena._stage_pick = OptionButton.new()
	arena.add_child(arena._stage_pick)
	arena._note = Label.new()
	arena.add_child(arena._note)
	for i in range(3):
		arena._spec_pick.add_item(str(i))
		arena._stage_pick.add_item(str(i))
	arena._spec_pick.selected = 2
	arena._stage_pick.selected = 0
	arena.apply_spec()
	var rt: Dictionary = tc.runtime(1)
	check(str(rt.ultimate) == "soul_14", "actual Testraum Seele preset keeps guardian on R")
	check(str(rt.bar[2]) == "soul_7", "current Seele test preset exposes shadow jump on three")
	check(int(rt.ranks.get("soul_11", 0)) > 0 and rt.bar.has("soul_11"), "actual Testraum preset exposes field alongside guardian")
	check(tc.cast(1, "soul_14"), "guardian casts directly from the real test-room preset")
	for class_id: String in d.classes:
		game.player_classes[1] = class_id
		game.players[1].class_id = class_id
		arena._specs = d.classes[class_id].specs
		for branch in range(arena._specs.size()):
			arena._spec_pick.selected = branch
			arena.apply_spec()
			check(not str(tc.runtime(1).ultimate).is_empty(), "valid arena preset retains ultimate for %s/%s" % [class_id, arena._specs[branch].id])
	arena.free()
