extends "res://scripts/capture_necro_rigs.gd"
## Actual GPU: marked death -> existing blood material -> rigged uptake particles.
const UPTAKE_OUT := "res://production/qa/evidence/necro-pool-uptake"
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UPTAKE_OUT.path_join("blood-frames")))
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://necro_uptake_capture.json"
	game.session_bind_ip = "127.0.0.1"
	var probe := PacketPeerUDP.new()
	probe.bind(0,"127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game._host_session()
	for draw in range(120): await process_frame
	game.player_classes[1] = "necromancer"
	game.requested_seed = 4242
	game._begin_run()
	game.set_process(false)
	game.set_physics_process(false)
	game.hordes.enabled = false
	game.phase = "combat"
	game.main_menu.hide()
	game.current_layout = {"id":"visible-blood-uptake","template_id":"visible-blood-uptake","generator_version":4,"world_size":[896,480],"tile_size":32,"play_bounds":[32,32,832,416],"obstacles":[],"exits":[],"boss":false,"render_style":"classic_quiet","decoration_enabled":false}
	game._room_layout_revision += 1
	game.players[1].pos = Vector2(330,290)
	game.players[1].aim = Vector2.RIGHT
	game.players[1].cheat_god = true
	game.enemies.clear()
	game.bullets.clear()
	game.boss_moves.zones.clear()
	var tc = game.talent_combat
	tc.reset(19)
	_build(tc,0,["minion_1","minion_9","minion_5","minion_7"])
	tc.runtime(1).pet_auto = [false,false]
	assert(tc.cast(1,"minion_1",{"aim":Vector2.RIGHT}))
	for frame in range(181):
		var age := frame/30.0
		if frame == 36:
			var at := Vector2(490,250)
			var foe: Dictionary = game._create_enemy("skelet",at)
			foe.hp = 500
			foe.max_hp = 500
			game.enemies.append(foe)
			assert(tc.cast(1,"minion_5",{"target":at,"aim":Vector2.RIGHT}))
			game._damage_enemy(foe,99999,Vector2.RIGHT,1,true,false)
		for substep in range(2):
			tc.step(1.0/60)
			game._simulate_bullets(1.0/60)
			game.perk_combat.step_statuses(1.0/60)
			game.boss_moves.update(1.0/60)
		game.view._clock = 20+age
		game._apply_snapshot(game._make_snapshot())
		game.view.set_state(game.state,1)
		game._refresh_ui()
		for draw in range(2): await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_png(UPTAKE_OUT.path_join("blood-frames/frame-%03d.png" % frame))
		if frame in [0,36,50,75,95,130,180]:
			picture.save_png(UPTAKE_OUT.path_join("blood-%03d.png" % frame))
			var pet: Dictionary = tc.permanent_pet(1)
			print("NECRO_UPTAKE_CAPTURE frame=",frame," blood=",pet.get("blood",0)," pending=",pet.get("blood_pending",0)," wait=",pet.get("blood_wait",0)," pools=",game.boss_moves.zones.size())
	assert(is_equal_approx(float(tc.permanent_pet(1).get("blood",0)),25),"one actual marked death must arrive as exactly twenty-five blood")
	print("NECRO_UPTAKE_CAPTURE complete frames=181")
	game._leave_session()
	game.queue_free()
	await process_frame
	quit()
