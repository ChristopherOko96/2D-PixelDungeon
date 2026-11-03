extends SceneTree
## Actual game GPU fixture, synthetic build/encounter, not an earned campaign.
const Game = preload("res://src/game.gd")
var game: Node
var age := 0.0
const OUT := "res://production/qa/evidence/soul-guardian-rig"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/soul-guardian-rig/game-frames"))
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://soul_guardian_capture_profile.json"
	game.session_bind_ip = "127.0.0.1"
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	if "--arena-only" in OS.get_cmdline_user_args():
		await capture_arena()
		game._leave_session()
		game.queue_free()
		await process_frame
		quit()
		return
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
	# A bounded open encounter in the actual current room, with real enemy AI.
	var target := Vector2(player.pos) + Vector2(70, 0)
	assert(not game.talent_combat._blocked(player.pos, target, 12.0), "fixture combat must be on reachable floor")
	for offset: Vector2 in [Vector2.ZERO, Vector2(-20, 30), Vector2(-35, -50)]:
		var enemy: Dictionary = game._create_enemy("skeleton_archer" if offset.y < 0 else "skeleton_guard", target + offset)
		enemy.hp = 16.0
		enemy.max_hp = 16.0
		game.enemies.append(enemy)
	var tc = game.talent_combat
	var ranks := {}
	var spent := 0
	for id: String in tc.data.talents:
		var info: Dictionary = tc.data.talents[id]
		if str(info.spec) != "soul" or int(info.tier) >= 6 or spent >= 20: continue
		var take := mini(3, 20 - spent)
		ranks[id] = take
		spent += take
	ranks.soul_11 = 1
	ranks.soul_14 = 1
	tc.set_build(1, {"class": "necromancer", "level": 30, "ranks": ranks, "bar": ["soul_1", "soul_3", "soul_5", "soul_11"]})
	# Explicit visual fixture reserve, not a claim of earned souls. Separate
	# economy tests verify the actual fifty-soul start and real kill income.
	tc.runtime(1).res = float(tc.runtime(1).res_max)
	assert(str(tc.runtime(1).ultimate) == "soul_14")
	for i in range(65): await process_frame
	tc.handle_input(1, player, {"skills": 1 << tc.ULT_BIT, "aim": Vector2.RIGHT, "target": target})
	assert(tc.guardians.actors.size() == 1)
	for frame in range(381):
		for tick in range(2 if frame > 0 else 0):
			age += 1.0 / 60.0
			tc.step(1.0 / 60.0)
			game._simulate_enemies(1.0 / 60.0)
			game._simulate_bullets(1.0 / 60.0)
			game.perk_combat.step_statuses(1.0 / 60.0)
			if age > 2.8 and age < 5.0:
				player.pos = tc._move(player.pos, Vector2(-0.25, 1.0).normalized() * 50.0 / 60.0, 14.0)
		# A demonstration of the existing field alongside the summon, later in
		# the encounter. Its cast still spends souls and uses the normal runtime.
		if frame == 75:
			tc.handle_input(1, player, {"skills": 1 << (tc.BAR_BIT + 3), "aim": Vector2.RIGHT, "target": target})
		game.view._clock = 20.0 + age
		game.view._feedback.hitstop = 0.0
		game._apply_snapshot(game._make_snapshot())
		game.view.set_state(game.state, 1)
		game._refresh_ui()
		for draw in range(2): await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_png("res://output/soul-guardian-rig/game-frames/frame-%03d.png" % frame)
		if frame in [0, 8, 20, 33, 75, 155, 338, 350, 358, 365, 380]:
			picture.save_png(OUT.path_join("guardian-%03d.png" % frame))
			print("GUARDIAN_CAPTURE frame=%d age=%.3f guardians=%d" % [frame, age, tc.guardians.actors.size()])
	assert(tc.guardians.actors.is_empty(), "summon must be gone after its duration")
	game._leave_session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	game.queue_free()
	await process_frame
	quit()

## Real main-menu Testraum entry and its real control panel, not a mockup.
func capture_arena() -> void:
	game.start_test_arena("necromancer")
	game.set_process(false)
	game.set_physics_process(false)
	game.main_menu.hide()
	var arena = game._arena_bar
	assert(arena != null and game.test_arena)
	arena._spec_pick.selected = 2
	arena.apply_spec()
	var tc = game.talent_combat
	tc.runtime(1).res = float(tc.runtime(1).res_max)
	assert(str(tc.runtime(1).ultimate) == "soul_14" and tc.runtime(1).bar[3] == "soul_11")
	for i in range(65): await process_frame
	var player: Dictionary = game.players[1]
	var target := Vector2(player.pos) + Vector2(60, 0)
	tc.handle_input(1, player, {"skills": 1 << tc.ULT_BIT, "aim": Vector2.RIGHT, "target": target})
	tc.step(1.05)
	tc.handle_input(1, player, {"skills": 1 << (tc.BAR_BIT + 3), "aim": Vector2.RIGHT, "target": target})
	tc.step(0.05)
	game.view._feedback.hitstop = 0.0
	game._apply_snapshot(game._make_snapshot())
	game.view.set_state(game.state, 1)
	game._refresh_ui()
	game._camera_room_id = ""
	game._update_camera(0.0)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.path_join("testraum-seele.png"))
	print("GUARDIAN_ARENA_CAPTURE ultimate=%s field_slot=4 guardians=%d" % [tc.runtime(1).ultimate, tc.guardians.actors.size()])
