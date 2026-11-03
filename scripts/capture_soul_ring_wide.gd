extends SceneTree
## Actual normal game renderer with a controlled build/encounter, not an earned
## run. Only the normal learned Seelenring input is cast; no guardian/filled pool.
const Game = preload("res://src/game.gd")
const OUT := "res://production/qa/evidence/soul-ring-wide"
const FRAMES := "res://output/soul-ring-wide/game-frames"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	if "--arena-only" in OS.get_cmdline_user_args():
		game.start_test_arena("necromancer")
		game.set_process(false)
		game.set_physics_process(false)
		game.main_menu.hide()
		game._arena_bar._spec_pick.selected = 2
		game._arena_bar.apply_spec()
		var runtime: Dictionary = game.talent_combat.runtime(1)
		assert(runtime.bar[1] == "soul_3" and runtime.bar[3] == "soul_11")
		var player: Dictionary = game.players[1]
		game.talent_combat.handle_input(1, player, {"skills": 1 << (game.talent_combat.BAR_BIT + 1), "aim": Vector2.RIGHT, "target": player.pos})
		game.talent_combat.step(1.6)
		game.view._clock = 21.6
		game._apply_snapshot(game._make_snapshot())
		game.view.set_state(game.state, 1)
		game._refresh_ui()
		game._camera_room_id = ""
		game._update_camera(0.0)
		for i in range(65): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT.path_join("testraum-ring.png"))
		print("RING_ARENA_CAPTURE ring_slot=2 field_slot=4 ultimate=%s" % runtime.ultimate)
		game._leave_session()
		game.queue_free()
		await process_frame
		quit()
		return
	game.progress.save_path = "user://soul_ring_capture_profile.json"
	game.session_bind_ip = "127.0.0.1"
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game._host_session()
	game.player_classes[1] = "necromancer"
	game.requested_seed = 4242
	game._begin_run()
	game.set_process(false)
	game.set_physics_process(false)
	game.hordes.enabled = false
	game.enemies.clear()
	game.bullets.clear()
	game.phase = "combat"
	game.main_menu.hide()
	var player: Dictionary = game.players[1]
	player.pos = Vector2(300, 240)
	player.aim = Vector2.RIGHT
	player.invulnerable = 1000.0
	for offset: Vector2 in [Vector2(100, 0), Vector2(10, 20), Vector2(-100, 0)]:
		var enemy: Dictionary = game._create_enemy("skeleton_guard", Vector2(player.pos) + offset)
		enemy.hp = 150.0
		enemy.max_hp = 150.0
		enemy.speed = 12.0
		game.enemies.append(enemy)
	var tc = game.talent_combat
	tc.set_build(1, {"class": "necromancer", "level": 30, "ranks": {"soul_1": 3, "soul_3": 3}, "bar": ["soul_1", "soul_3"]})
	assert(tc.runtime(1).bar[1] == "soul_3")
	# Actual fifty-soul start is sufficient; no resource refill.
	for i in range(65): await process_frame
	tc.handle_input(1, player, {"skills": 1 << (tc.BAR_BIT + 1), "aim": Vector2.RIGHT, "target": Vector2(player.pos) + Vector2.RIGHT * 70})
	assert(tc.zones.size() == 1)
	var age := 0.0
	for frame in range(181):
		for tick in range(2 if frame > 0 else 0):
			age += 1.0 / 60.0
			tc.step(1.0 / 60.0)
			game._simulate_enemies(1.0 / 60.0)
			game._simulate_bullets(1.0 / 60.0)
			game.perk_combat.step_statuses(1.0 / 60.0)
			if age > 2.2 and age < 3.4: player.pos = tc._move(player.pos, Vector2.DOWN * 32.0 / 60.0, 14.0)
		game.view._clock = 20.0 + age
		game.view._feedback.hitstop = 0.0
		game._apply_snapshot(game._make_snapshot())
		game.view.set_state(game.state, 1)
		game._refresh_ui()
		for draw in range(2): await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_png(FRAMES.path_join("frame-%03d.png" % frame))
		if frame in [0, 5, 10, 20, 35, 60, 90, 120, 140, 180]:
			picture.save_png(OUT.path_join("ring-%03d.png" % frame))
			print("SOUL_RING_CAPTURE frame=%d age=%.3f active_rims=%d" % [frame, age, tc.snapshot().zones.size()])
	assert(tc.zones.is_empty())
	game._leave_session()
	game.queue_free()
	await process_frame
	quit()
