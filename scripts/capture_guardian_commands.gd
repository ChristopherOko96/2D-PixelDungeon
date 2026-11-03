extends SceneTree
## Actual game renderer: a controlled guardian encounter, not an earned
## run. Approved guardian rig, validated R/5 inputs, real host damage.
const Game = preload("res://src/game.gd")
const OUT := "res://production/qa/evidence/guardian-commands"
const FRAMES := "res://output/guardian-commands/game-frames"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://guardian_commands_capture_profile.json"
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
	game.current_layout = {"id": "guardian-capture", "template_id": "guardian-capture", "generator_version": 4, "world_size": [896, 480], "tile_size": 32, "play_bounds": [32, 32, 832, 416], "obstacles": [], "exits": [], "boss": false, "render_style": "classic_quiet", "decoration_enabled": false}
	game._room_layout_revision += 1
	var player: Dictionary = game.players[1]
	player.pos = Vector2(300, 240)
	player.aim = Vector2.RIGHT
	player.invulnerable = 1000.0
	var tc = game.talent_combat
	var ranks := {}
	var needed := int(tc.data.tiers[str(int(tc.data.talents.soul_14.tier))].points)
	var used := 0
	for id: String in tc.data.talents:
		var info: Dictionary = tc.data.talents[id]
		if str(info.spec) != "soul" or int(info.tier) >= int(tc.data.talents.soul_14.tier): continue
		if used >= needed: break
		var take := mini(int(info.ranks), needed - used)
		ranks[id] = take
		used += take
	ranks.soul_14 = 1
	tc.set_build(1, {"class": "necromancer", "level": 30, "ranks": ranks, "bar": ["soul_1"]})
	assert(tc.runtime(1).ultimate == "soul_14")
	for offset: Vector2 in [Vector2(155, 0), Vector2(205, 5), Vector2(230, -45)]:
		var enemy: Dictionary = game._create_enemy("skeleton_guard", Vector2(player.pos) + offset)
		enemy.hp = 0.8 if offset.y >= 0 else 5000.0
		enemy.max_hp = enemy.hp
		enemy.speed = 0.0
		game.enemies.append(enemy)
	for i in range(65): await process_frame
	tc.handle_input(1, player, {"skills": 1 << tc.ULT_BIT, "aim": Vector2.RIGHT})
	assert(tc.guardians.actors.size() == 1)
	var age := 0.0
	for frame in range(181):
		for tick in range(2 if frame > 0 else 0):
			age += 1.0 / 60.0
			tc.step(1.0 / 60.0)
			game._simulate_enemies(1.0 / 60.0)
			game._simulate_bullets(1.0 / 60.0)
			game.perk_combat.step_statuses(1.0 / 60.0)
			if age >= 0.8 and age < 0.82: tc.handle_input(1, player, {"skills": 1 << tc.PET_BIT, "aim": Vector2.RIGHT})
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
			picture.save_png(OUT.path_join("guardian-%03d.png" % frame))
			print("GUARDIAN_COMMAND_CAPTURE frame=%d age=%.3f guardians=%d underlings=%d" % [frame, age, tc.guardians.actors.size(), tc.pets.filter(func(p: Dictionary) -> bool: return bool(p.get("converted", false))).size()])
	assert(tc.pets.any(func(p: Dictionary) -> bool: return bool(p.get("converted", false))))
	game._leave_session()
	game.queue_free()
	await process_frame
	quit()
