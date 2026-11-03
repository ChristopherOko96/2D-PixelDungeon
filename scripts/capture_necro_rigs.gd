extends SceneTree
## Controlled GPU presentation fixture, not an earned run or performance test.
const Game = preload("res://src/game.gd")
const OUT := "res://production/qa/evidence/necro-rig-upgrade"
func _initialize() -> void:
	_run.call_deferred()
func _build(tc: RefCounted, spec_index: int, bar: Array) -> void:
	var ranks := {}
	var spec: Dictionary = tc.data.classes.necromancer.specs[spec_index]
	for id: String in spec.talents: ranks[id] = 1
	var remaining: int = tc.Rules.points_total(tc.data, 30) - ranks.size()
	for id: String in spec.talents:
		var extra := mini(remaining, int(tc.data.talents[id].ranks) - 1)
		ranks[id] = int(ranks[id]) + extra
		remaining -= extra
	tc.set_build(1, {"class": "necromancer", "level": 30, "ranks": ranks, "bar": bar})
	tc.runtime(1).res = 100.0
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://necro_branches_capture.json"
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
	game.phase = "combat"
	game.main_menu.hide()
	game.current_layout = {"id": "necro-rig-upgrade", "template_id": "necro-rig-upgrade", "generator_version": 4, "world_size": [896, 480], "tile_size": 32, "play_bounds": [32, 32, 832, 416], "obstacles": [], "exits": [], "boss": false, "render_style": "classic_quiet", "decoration_enabled": false}
	game._room_layout_revision += 1
	var player: Dictionary = game.players[1]
	player.pos = Vector2(390, 250)
	player.aim = Vector2.RIGHT
	player.cheat_god = true
	var tc = game.talent_combat
	for phase in range(2):
		tc.reset(19)
		game.boss_moves.zones.clear()
		game.enemies.clear()
		game.bullets.clear()
		_build(tc, phase, ["minion_3", "minion_5", "minion_7", "minion_11"] if phase == 0 else ["curse_1", "curse_3", "curse_7", "curse_9"])
		if phase == 0:
			var pet: Dictionary = tc.permanent_pet(1)
			for i in range(4): tc.necromancer.pool(tc, 1, "blood", Vector2(pet.pos) + Vector2(-10, 8), 65, 20)
		else:
			for offset: Vector2 in [Vector2(100, 0), Vector2(145, 30), Vector2(170, -35)]:
				var mob: Dictionary = game._create_enemy("skelet", Vector2(player.pos) + offset)
				mob.hp = 500
				mob.max_hp = 500
				mob.speed = 0.0
				game.enemies.append(mob)
		tc.runtime(1).pet_auto = [false,false]
		for i in range(60): await process_frame
		var frames := 451
		var dir := OUT.path_join("minion-frames" if phase == 0 else "curse-frames")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		for frame in range(frames):
			var age := float(frame) / 30.0
			for substep in range(2):
				tc.step(1.0 / 60.0)
				game._simulate_bullets(1.0 / 60.0)
				game.perk_combat.step_statuses(1.0 / 60.0)
				game.boss_moves.update(1.0 / 60.0)
			if phase == 1:
				var cast := {0: "curse_1", 45: "curse_3", 90: "curse_9", 150: "curse_7", 210: "curse_5", 270: "curse_11", 390: "curse_14"}
				if cast.has(frame):
					var target := Vector2(game.enemies[0].pos) if str(cast[frame]) == "curse_9" else Vector2(player.pos)+Vector2(130,0)
					assert(tc.cast(1,cast[frame],{"aim":Vector2.RIGHT,"target":target}),"presentation spell must really cast")
			if phase == 0 and frame == 260: tc.pet_cast(1, 0, true)
			if phase == 0 and frame == 300: tc.pet_cast(1, 1, true)
			if phase == 0 and frame == 80: tc.cast(1, "minion_11", {"aim":Vector2.RIGHT})
			if phase == 0 and frame == 130: tc.cast(1, "minion_9", {"aim":Vector2.RIGHT})
			if phase == 1 and age >= 3.0 and not game.enemies.is_empty():
				var t := age-3.0
				game.enemies[0].pos = Vector2(player.pos)+Vector2(100+sin(t*1.7)*45,sin(t*2.1)*60)
				for link: Dictionary in tc.snapshot().blood_links:
					if str(link.kind)=="blood": assert(int(link.target_id)==int(game.enemies[0].id),"blood channel must follow moving showcase target")
			if phase == 0 and frame == 240:
				var foe: Dictionary = game._create_enemy("skelet",Vector2(tc.command_pet(1).pos)+Vector2(55,0))
				foe.hp = 500
				foe.max_hp = 500
				foe.speed = 0.0
				game.enemies.append(foe)
			game.view._clock = 20.0 + phase * 20.0 + age
			game.view._feedback.hitstop = 0.0
			game._apply_snapshot(game._make_snapshot())
			game.view.set_state(game.state, 1)
			game._refresh_ui()
			for draw in range(2): await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			picture.save_png(dir.path_join("frame-%03d.png" % frame))
			if frame in [0,50,100,120,150,180,200,240,270,300,315,330,360,420,450]:
				picture.save_png(OUT.path_join("%s-%03d.png" % ["minion" if phase == 0 else "curse", frame]))
				print("NECRO_CAPTURE phase=%d frame=%d" % [phase, frame])
				if frame == 50:
					var pools: RefCounted = game.view._boss_fx.pools
					print("POOL_DEBUG zones=", game.boss_moves.snapshot(), " pools=", pools.pool_field.pools().keys(), " shaping=", pools.pool_field.pending(), " fields=", pools._fields.keys(), " solid=", game.view._feedback.particles.solid(Vector2(366,250)))
					for mat: String in pools._fields:
						var field: Dictionary = pools._fields[mat]
						print("POOL_FIELD ", mat, " cells=", field.cells.size(), " sample=", field.cells.values()[0] if not field.cells.is_empty() else [], " now=", pools._now, " box=", field.box, " image=", field.tex.get_image().get_used_rect() if field.tex != null else Rect2i())
	game._leave_session()
	game.queue_free()
	await process_frame
	quit()
