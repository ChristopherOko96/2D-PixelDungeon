extends "res://scripts/capture_necro_rigs.gd"
## Actual game/UI captures of the requested loop; controlled fixture, not a campaign.
const CYCLE_OUT := "res://production/qa/evidence/necro-blood-cycle"
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CYCLE_OUT))
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://necro_cycle_capture.json"
	game.session_bind_ip = "127.0.0.1"
	var probe := PacketPeerUDP.new()
	probe.bind(0,"127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game._host_session()
	# Finish the ordinary local profile admission before applying the fixture build.
	for draw in range(120): await process_frame
	game.player_classes[1] = "necromancer"
	game.requested_seed = 4242
	game._begin_run()
	game.set_process(false)
	game.set_physics_process(false)
	game.hordes.enabled = false
	game.phase = "combat"
	game.main_menu.hide()
	game.current_layout = {"id":"blood-cycle","template_id":"blood-cycle","generator_version":4,"world_size":[896,480],"tile_size":32,"play_bounds":[32,32,832,416],"obstacles":[],"exits":[],"boss":false,"render_style":"classic_quiet","decoration_enabled":false}
	game._room_layout_revision += 1
	game.players[1].pos = Vector2(350,250)
	game.players[1].aim = Vector2.RIGHT
	game.players[1].cheat_god = true
	game.enemies.clear()
	game.bullets.clear()
	game.boss_moves.zones.clear()
	var tc = game.talent_combat
	tc.reset(19)
	_build(tc,0,["minion_1","minion_9","minion_5","minion_7"])
	tc.runtime(1).pet_auto = [false,false]
	for step in range(1201):
		var age := step/60.0
		if step == 6: assert(tc.cast(1,"minion_1",{"aim":Vector2.RIGHT}))
		if step == 72:
			assert(tc.cast(1,"minion_9",{"aim":Vector2.RIGHT}))
		if step == 90:
			for offset: Vector2 in [Vector2(130,-20),Vector2(145,20)]:
				var mob: Dictionary = game._create_enemy("skelet",Vector2(game.players[1].pos)+offset)
				mob.hp = 500
				mob.max_hp = 500
				mob.speed = 0
				game.enemies.append(mob)
		if step == 144: assert(tc.cast(1,"minion_5",{"aim":Vector2.RIGHT,"target":Vector2(485,250)}))
		if step == 180:
			for mob: Dictionary in game.enemies.duplicate(): game._damage_enemy(mob,99999,Vector2.RIGHT,1,true,false)
		if step == 450:
			assert(float(tc.permanent_pet(1).get("blood",0))>=50,"marked deaths must have filled at least half blood")
			assert(tc.cast(1,"minion_14"),"R spends the collected blood, no fixture blood grant")
		if step == 540: assert(tc.pet_cast(1,0,true))
		if step == 600: assert(tc.pet_cast(1,1,true))
		if step == 1080: assert(str(tc.permanent_pet(1).kind)=="bone_warrior" and float(tc.permanent_pet(1).blood)==0,"half gauge must return to normal")
		tc.step(1.0/60)
		game._simulate_bullets(1.0/60)
		game.perk_combat.step_statuses(1.0/60)
		game.boss_moves.update(1.0/60)
		if step in [0,30,90,150,181,240,440,480,640,950,980,1080]:
			game.view._clock = 20+age
			game._apply_snapshot(game._make_snapshot())
			game.view.set_state(game.state,1)
			game._refresh_ui()
			for draw in range(2): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(CYCLE_OUT.path_join("game-%04d.png" % step))
			print("NECRO_CYCLE_CAPTURE step=",step," blood=",tc.permanent_pet(1).get("blood",0)," archers=",tc.pets.filter(func(p:Dictionary)->bool:return str(p.kind)=="bone_archer").size())
	var data: Dictionary = tc.data
	var profile: Dictionary = preload("res://src/progress/profile.gd").fresh(data)
	var hero: Dictionary = preload("res://src/progress/profile.gd").class_state(profile,"necromancer")
	hero.level = 30
	hero.ranks = tc.runtime(1).ranks.duplicate()
	hero.bar = tc.runtime(1).bar.duplicate()
	hero.ultimate = "minion_14"
	var screen = preload("res://src/ui/talent_screen.gd").new()
	game.ui.add_child(screen)
	screen.open(data,profile,"user://necro_cycle_capture_unused.json","necromancer")
	for id: String in ["minion_1","minion_5","minion_9","minion_14"]:
		screen.selected = id
		screen._refresh()
		for draw in range(2): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(CYCLE_OUT.path_join("talent-%s.png" % id))
	print("NECRO_CYCLE_CAPTURE complete")
	game._leave_session()
	game.queue_free()
	await process_frame
	quit()
