extends SceneTree
## Actual game renderer: controlled rig jump, trail and ring, not an earned run.
## Legal Seele build, fifty-soul start, ordinary inputs. Debug god flag avoids
## combat deaths without the visual invulnerability flicker; no campaign claim.
const Game = preload("res://src/game.gd")
const OUT := "res://production/qa/evidence/soul-leap"
const FRAMES := "res://output/soul-leap/game-frames"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://soul_leap_capture_profile.json"
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
	game.current_layout = {"id": "soul-attacks-capture", "template_id": "soul-attacks-capture", "generator_version": 4, "world_size": [896, 480], "tile_size": 32, "play_bounds": [32, 32, 832, 416], "obstacles": [], "exits": [], "boss": false, "render_style": "classic_quiet", "decoration_enabled": false}
	game._room_layout_revision += 1
	var player: Dictionary = game.players[1]
	player.pos = Vector2(300, 240)
	player.aim = Vector2.RIGHT
	player.invulnerable = 0.0
	player.cheat_god = true
	var tc = game.talent_combat
	var ranks := {}
	var spec: Dictionary = tc.data.classes.necromancer.specs[2]
	for id: String in spec.talents: ranks[id] = 1
	var remaining: int = tc.Rules.points_total(tc.data, 30) - ranks.size()
	for id: String in spec.talents:
		var extra := mini(remaining, int(tc.data.talents[id].ranks) - 1)
		ranks[id] = int(ranks[id]) + extra
		remaining -= extra
	tc.set_build(1, {"class": "necromancer", "level": 30, "ranks": ranks, "bar": ["soul_7", "soul_3", "soul_9", "soul_11"]})
	assert(tc.runtime(1).bar.size() == 4)
	player.pos = Vector2(220, 240)
	for offset: Vector2 in [Vector2(80, 90), Vector2(220, 0), Vector2(320, 0)]:
		var enemy: Dictionary = game._create_enemy("skelet", Vector2(player.pos) + offset)
		enemy.hp = 0.2 if offset.y > 0 else 1.5
		enemy.max_hp = enemy.hp
		enemy.speed = 0.0
		game.enemies.append(enemy)
	for i in range(65): await process_frame
	tc.handle_input(1, player, {"skills": 1 << tc.BAR_BIT, "aim": Vector2.RIGHT})
	assert(tc.runtime(1).has("soul_leap"))
	var age := 0.0
	for frame in range(241):
		for tick in range(2 if frame > 0 else 0):
			age += 1.0 / 60.0
			tc.step(1.0 / 60.0)
			game._simulate_enemies(1.0 / 60.0)
			game._simulate_bullets(1.0 / 60.0)
			game.perk_combat.step_statuses(1.0 / 60.0)
			if age >= 0.9 and age < 1.3: player.pos = tc._move(player.pos, Vector2.RIGHT * 100.0 / 60.0, float(game.balance.player.radius))
			if age >= 1.5 and age < 1.55: tc.handle_input(1, player, {"skills": 1 << (tc.BAR_BIT + 1), "aim": Vector2.RIGHT})
			else: tc.handle_input(1, player, {"skills": 0, "aim": Vector2.RIGHT})
		game.view._clock = 20.0 + age
		game.view._feedback.hitstop = 0.0
		game._apply_snapshot(game._make_snapshot())
		game.view.set_state(game.state, 1)
		game._refresh_ui()
		for draw in range(2): await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_png(FRAMES.path_join("frame-%03d.png" % frame))
		if frame in [0, 5, 10, 20, 35, 60, 90, 120, 140, 180, 210, 240]:
			picture.save_png(OUT.path_join("soul-%03d.png" % frame))
			print("SOUL_LEAP_CAPTURE frame=%d age=%.3f guardians=%d underlings=%d" % [frame, age, tc.guardians.actors.size(), tc.pets.filter(func(p: Dictionary) -> bool: return bool(p.get("converted", false))).size()])
	assert(tc.zones.is_empty() and not tc.runtime(1).has("soul_leap"))
	game._leave_session()
	game.queue_free()
	await process_frame
	quit()
