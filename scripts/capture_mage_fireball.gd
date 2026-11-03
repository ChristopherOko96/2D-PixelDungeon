extends SceneTree
## Windowed GPU fixture of the real fireball. Not an earned campaign.
const Game = preload("res://src/game.gd")
var game: Node
var out := "res://production/qa/evidence/mage-fireball-step-01"
var fixture_age := 0.0

func _initialize() -> void:
	if "--soul" in OS.get_cmdline_user_args(): out = "res://production/qa/evidence/necromancer-soul-field-24"
	if "--soul-detail" in OS.get_cmdline_user_args(): out = "res://production/qa/evidence/necromancer-soul-detail"
	if "--soul-lava" in OS.get_cmdline_user_args(): out = "res://production/qa/evidence/necromancer-soul-lava"
	if "--soul-bind" in OS.get_cmdline_user_args(): out = "res://production/qa/evidence/necromancer-soul-bind"
	_run.call_deferred()

func shot(label: String) -> void:
	if "--soul-bind" in OS.get_cmdline_user_args(): game.view._clock = 10.0 + fixture_age
	game._apply_snapshot(game._make_snapshot())
	game.view.set_state(game.state, 1)
	# Fixtures hold host time; do not let a local hitstop retain the prior snapshot.
	game.view._feedback.hitstop = 0.0
	game.view.set_state(game.state, 1)
	game._refresh_ui()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(out.path_join(label + ".png"))
	if "--soul-bind" in OS.get_cmdline_user_args():
		var white := 0
		for y in range(180, mini(630, image.get_height())):
			for x in range(260, mini(720, image.get_width())):
				var pixel := image.get_pixel(x, y)
				if pixel.r > 0.96 and pixel.g > 0.96 and pixel.b > 0.96: white += 1
		assert(white < 10000, "faded ghost textures must not render as a solid white polygon")
	print("FIREBALL_CAPTURE ", label, " result=", result)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.session_bind_ip = "127.0.0.1"
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game._host_session()
	game.player_classes[1] = "necromancer" if "--soul" in OS.get_cmdline_user_args() else "mage"
	game.requested_seed = 4242
	game._begin_run()
	game.set_process(false)
	game.set_physics_process(false)
	game.hordes.enabled = false
	game.enemies.clear()
	game.bullets.clear()
	game.phase = "combat"
	game.menu_open = false
	game.main_menu.hide()
	var player: Dictionary = game.players[1]
	player.aim = Vector2.RIGHT
	if "--soul" in OS.get_cmdline_user_args():
		var ranks := {}
		var spent := 0
		var needed := 20 if "--soul-detail" in OS.get_cmdline_user_args() else 14
		for id: String in game.talent_combat.data.talents:
			var info: Dictionary = game.talent_combat.data.talents[id]
			if str(info.spec) != "soul" or int(info.tier) >= 6 or spent >= needed: continue
			var take := mini(3, needed - spent)
			ranks[id] = take
			spent += take
		ranks.soul_11 = 1
		if "--soul-detail" in OS.get_cmdline_user_args():
			ranks.soul_14 = 1
			ranks.soul_9 = 1
		game.talent_combat.set_build(1, {"class": "necromancer", "level": 30, "ranks": ranks, "bar": ["soul_11"]})
		for i in range(65): await process_frame
		var target := Vector2(player.pos) + Vector2(100, 100)
		if "--soul-detail" in OS.get_cmdline_user_args():
			var origin := Vector2(player.pos)
			for talent: String in ["soul_1", "soul_3", "soul_5", "soul_7", "soul_9", "soul_14"]:
				player.pos = origin
				game.bullets.clear()
				game.talent_combat.events.clear()
				var rt: Dictionary = game.talent_combat.runtime(1)
				rt.shield = 0.0
				rt.shield_time = 0.0
				rt.cds.clear()
				rt.gcd = 0.0
				rt.res = float(rt.res_max)
				assert(game.talent_combat.cast(1, talent, {"aim": Vector2.RIGHT, "target": target}))
				game.talent_combat.step(0.18)
				if talent in ["soul_1", "soul_9"]: game._simulate_bullets(0.08)
				await shot(talent + "-detail")
			player.pos = origin
			game.bullets.clear()
			game.talent_combat.runtime(1).shield = 0.0
			game.talent_combat.runtime(1).shield_time = 0.0
			game.talent_combat.events.clear()
			game.talent_combat.runtime(1).cds.clear()
			game.talent_combat.runtime(1).gcd = 0.0
			game.talent_combat.runtime(1).res = 100.0
		assert(game.talent_combat.cast(1, "soul_11", {"aim": Vector2.RIGHT, "target": target}))
		if "--soul-bind" in OS.get_cmdline_user_args():
			game.enemies.append(game._create_enemy("skeleton_guard", target + Vector2(-10, -10)))
			game.enemies.append(game._create_enemy("skeleton_archer", target + Vector2(35, 10)))
		for frame in range(96 if "--soul-bind" in OS.get_cmdline_user_args() else 24):
			var delta := 0.001 if frame == 0 else 0.055
			fixture_age += delta
			game.talent_combat.step(delta)
			if "--soul-bind" in OS.get_cmdline_user_args():
				game._simulate_enemies(delta)
				game._simulate_bullets(delta)
				game.perk_combat.step_statuses(delta)
			await shot("soul-field-%02d" % frame)
		if "--soul-bind" in OS.get_cmdline_user_args():
			await shot("fade-out")
		game._leave_session()
		game.queue_free()
		for i in range(3): await process_frame
		quit()
		return
	game.talent_combat.set_build(1, {"class": "mage", "level": 3, "ranks": {"fire_1": 1}, "bar": ["fire_1"]})
	for i in range(65): await process_frame
	if "--basic" in OS.get_cmdline_user_args():
		await shot("06-basic-idle")
		game.perk_combat.shoot(1, Vector2.RIGHT)
		await shot("07-basic-release")
		game._simulate_bullets(0.08)
		await shot("08-basic-flight")
		if not game.bullets.is_empty(): game.perk_combat.splash(game.bullets[0])
		game.bullets.clear()
		await shot("09-basic-impact")
		game._leave_session()
		game.queue_free()
		for i in range(3): await process_frame
		quit()
		return
	await shot("01-idle")
	game.talent_combat.cast(1, "fire_1", {"aim": Vector2.RIGHT})
	game.talent_combat.step(0.09)
	await shot("02-charge")
	game.talent_combat.step(0.09)
	await shot("03-release")
	game.talent_combat.step(0.08)
	game._simulate_bullets(0.08)
	await shot("04-flight")
	# Use the real impact handler against a disposable target beside the shot.
	if not game.bullets.is_empty():
		var bullet: Dictionary = game.bullets[0]
		var enemy: Dictionary = game._create_enemy("skeleton", bullet.pos)
		enemy.hp = 50.0
		enemy.max_hp = 50.0
		game.enemies.append(enemy)
		game.talent_combat.bullet_hit(bullet, enemy)
		game.bullets.clear()
		game.talent_combat.step(0.17)
		await shot("05-impact")
	game._leave_session()
	game.queue_free()
	for i in range(3): await process_frame
	quit()
