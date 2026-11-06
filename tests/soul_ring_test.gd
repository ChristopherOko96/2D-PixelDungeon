extends "res://tests/talent_combat_test.gd"
## Real host cast, empty middle, delayed rim, shared crowd-control lockout.
const Targets = preload("res://src/combat/companion_targets.gd")

func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://soul_ring_test_profile.json"
	game.players[1] = {"pos": Vector2(300, 240), "class_id": "necromancer", "hp": 100, "max_hp": 100, "damage": 10.0, "aim": Vector2.RIGHT}
	tc = game.talent_combat
	d = tc.data
	game.current_layout = {"id": "ring-test", "tile_size": 32, "play_bounds": [0, 0, 896, 480], "world_size": [896, 480], "obstacles": []}
	game.phase = "combat"
	test_ring_leaves_a_delayed_hollow_field()
	test_ring_uses_shared_grasp_lockout_and_wall_checks()
	test_pending_ring_clears_on_room_change()
	game.queue_free()
	await process_frame
	print("SOUL_RING checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_ring_leaves_a_delayed_hollow_field() -> void:
	var rt := _setup(d.talents.soul_3)
	var center := _dummy(Vector2(300, 240))
	var edge := _dummy(Vector2(400, 240))
	var outside := _dummy(Vector2(500, 240))
	var res := float(rt.res)
	check(_cast(d.talents.soul_3), "normal learned soul nova cast accepted")
	check(is_equal_approx(res - float(rt.res), 22.0) and is_equal_approx(float(rt.cds.soul_3), 11.0), "existing cost/cooldown retained")
	check(center.hp < center.max_hp and edge.hp < edge.max_hp and outside.hp == outside.max_hp, "original nova damage respects ten metre diameter")
	check(tc.zones.size() == 1, "nova creates one pending rim")
	if tc.zones.is_empty(): return
	var zone: Dictionary = tc.zones[0]
	check(is_equal_approx(float(zone.r), 160.0) and is_equal_approx(float(zone.inner_r), 96.0), "5m outer radius, 2m wide band")
	check(tc.snapshot().zones.is_empty(), "rim hidden while rig souls expand outward")
	_tick(0.3)
	check(not edge.statuses.has("soul_bind"), "rim has no control before wave arrives")
	# The current class revamp expands for ring_expand=1s; old 0.75s
	# assumptions observed a still-pending field. Follow the shared data.
	_tick(float(d.talents.soul_3.ring_expand)-0.3+0.1)
	check(tc.snapshot().zones.size() == 1, "host publishes rim after expansion")
	check(not center.statuses.has("soul_bind") and edge.statuses.has("soul_bind"), "only annulus binds, center stays free")
	rt.hero_target = -1
	var preferred: Dictionary = Targets.pick(tc, {"owner": 1, "pos": Vector2(300, 240), "target": -1}, rt, true)
	check(int(preferred.get("id", -1)) == int(edge.id), "guardian prefers an enemy in its owner's ring over a closer enemy in the hole")
	if not tc.snapshot().zones.is_empty(): check(is_equal_approx(float(tc.snapshot().zones[0].inner_r), 96.0), "inner boundary survives authoritative snapshot")
	var hp := float(edge.hp)
	_tick(0.9)
	check(is_equal_approx(float(edge.hp), hp), "rim adds control without multiplying nova damage")
	game.players[1].pos = Vector2(500, 240)
	check(Vector2(zone.pos) == Vector2(300, 240), "cast ring remains at its original ground position")
	_tick(float(d.talents.soul_3.ring_time)-0.9+0.2)
	check(tc.zones.is_empty(), "rim expires five seconds after expansion")

func test_ring_uses_shared_grasp_lockout_and_wall_checks() -> void:
	_setup(d.talents.soul_3)
	var enemy := _dummy(Vector2(400, 240))
	var boss := _dummy(Vector2(300, 340), true)
	_cast(d.talents.soul_3)
	_tick(float(d.talents.soul_3.ring_expand)+0.1)
	if tc.zones.is_empty():
		check(false, "rim exists for shared control checks")
		return
	check(not boss.statuses.has("soul_bind"), "boss ignores ring stun")
	var wait := float(enemy.get("soul_grasp_wait", 0.0))
	tc._soul_grasp(tc.zones[0], enemy)
	check(is_equal_approx(float(enemy.get("soul_grasp_wait", 0.0)), wait), "ring shares existing field/guardian lockout")
	var event: Dictionary = tc.events.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "soul_grasp" and int(e.target_id) == int(enemy.id))[0]
	check(Vector2(float(event.from_x), float(event.from_y)).distance_to(Vector2(300, 240)) >= 96.0, "grasp originates at rim rather than in empty center")
	_setup(d.talents.soul_3)
	game.current_layout.obstacles = [[335, 0, 12, 480]]
	var hidden := _dummy(Vector2(400, 240))
	_cast(d.talents.soul_3)
	_tick(float(d.talents.soul_3.ring_expand)+0.1)
	check(not hidden.statuses.has("soul_bind") and hidden.hp == hidden.max_hp, "nova and rim cannot affect enemies behind wall")
	game.current_layout.obstacles = []

func test_pending_ring_clears_on_room_change() -> void:
	_setup(d.talents.soul_3)
	_cast(d.talents.soul_3)
	tc.room_changed()
	_tick(1.0)
	check(tc.zones.is_empty(), "room change cancels pending rim")
