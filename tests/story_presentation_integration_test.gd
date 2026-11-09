extends SceneTree
## Real Krypta: shared body/camera phase, screen snapping after resizing, aiming,
## pause and teleports. Optional --capture writes GPU screenshots to QA evidence.
var checks := 0
var failures := 0
var scratch := ""
var capture := false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PRESENTATION_INTEGRATION_FAIL: ", label)

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	scratch = "res://tests/.tmp_presentation_%d" % Time.get_ticks_usec()
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	seed(4242)
	var game: Node = load("res://src/hell/krypta_dungeon.tscn").instantiate()
	game.class_id = "swordsman"
	game.profile_path = scratch.path_join("profile.json")
	game.meta_path = scratch.path_join("meta.cfg")
	game.settings_path = scratch.path_join("settings.cfg")
	game.graphics_path = game.settings_path
	game.saves = preload("res://src/save/save_store.gd").new(scratch.path_join("saves"))
	game.mouse_taken = true
	game.keys_taken = true
	root.add_child(game)
	game.set_process(false)
	await process_frame
	if game.loading_screen != null:
		game.loading_screen.queue_free()
		game.loading_screen = null
	game._process(0.0)
	var start := Vector2(game.player.x, game.player.y)
	game.cam_rig.calm = true
	game.cam_rig.shake_on = false
	game.talents._sync_mobs()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1365, 767), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1024, 768)]:
		root.size = size
		await process_frame
		for i in range(24):
			game.presentation.begin_tick(game.player, game.mobs)
			game.player.x += 3.0
			game.presentation.frame(1.0 / 240.0, 1.0 / 60.0)
			var before := Vector2(game.player.x, game.player.y)
			game._update_camera(1.0 / 144.0)
			var stretch := root.get_stretch_transform()
			var transform := stretch * root.canvas_transform
			check(transform.origin.is_equal_approx(transform.origin.round()), "actual canvas aligns with physical pixels at " + str(size))
			check(game.cam_rig._last_hero.is_equal_approx(game.render_hero_position() - Vector2(0, 40)), "camera and rendered body share the same interpolated target")
			check(before == Vector2(game.player.x, game.player.y), "camera does not modify gameplay coordinates")
			var point := before + Vector2(170, 45)
			var screen: Vector2 = game._to_screen(point, root.get_visible_rect().size)
			check(screen.is_equal_approx(root.canvas_transform * point), "HUD/aim conversion matches the current camera transform")
			var visible: Rect2 = game._view_rect()
			var inverse := root.canvas_transform.affine_inverse()
			check(visible.position.is_equal_approx(inverse * Vector2.ZERO) and visible.end.is_equal_approx(inverse * root.get_visible_rect().size), "culling rectangle covers the actual expanded viewport at " + str(size))
			check(is_equal_approx(game.camera.zoom.x, float(game.balance.view.base_width) / float(game.balance.view.width)), "pixel base zoom remains fixed")
			game.actors.queue_redraw()
			game.story_glow.frame()
			await process_frame
		if capture:
			await RenderingServer.frame_post_draw
			var output := "res://production/qa/evidence/camera-stability"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			check(root.get_texture().get_image().save_png(output.path_join("krypta-%dx%d.png" % [size.x, size.y])) == OK, "GPU screenshot saved")
	game.player.x = start.x
	game.player.y = start.y
	game.camera.position = start
	game._update_camera(1.0 / 144.0)
	check(game.render_hero_position() == start, "external room/debug teleport clears presentation history")
	check(game.presentation._bodies.is_empty(), "teleport releases old mob history")
	game.presentation.begin_tick(game.player, game.mobs)
	game.player.x += 4.0
	game.pause_menu.visible = true
	var now := Vector2(game.player.x, game.player.y)
	game._process(2.0)
	check(game.render_hero_position() == now, "pause uses the current position without old interpolation")
	game.pause_menu.visible = false
	_test_special_room_zoom(game)
	if "--profile" in OS.get_cmdline_user_args(): await _profile(game)
	game.queue_free()
	await process_frame
	for name: String in ["profile.json", "meta.cfg", "settings.cfg"]:
		var path := ProjectSettings.globalize_path(scratch.path_join(name))
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch.path_join("saves")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	print("PRESENTATION_INTEGRATION checks=", checks, " failures=", failures)
	quit(1 if failures else 0)


func _test_special_room_zoom(game: Node) -> void:
	# Exercise the final game camera, not only the rig: room effects used to
	# multiply a continuously changing zoom after the rig's pixel lock.
	var room: Dictionary = game.W.rooms[game.state.room]
	var had_zone := room.has("maze_zone")
	var saved_zone: Variant = room.get("maze_zone")
	var cell := Vector2i(floori(game.player.x / game.C), floori((game.player.y - 6.0) / game.C))
	room.maze_zone = [[cell.x, cell.y, cell.x, cell.y]]
	var base := float(game.balance.view.base_width) / float(game.balance.view.width)
	for i in range(12):
		game._update_camera(1.0 / 60.0)
		check(is_equal_approx(game.camera.zoom.x, base), "maze fade cannot rescale pixel floor, frame %d" % i)
	check(game.maze_dark > 0.0, "pixel zoom lock retains maze darkness")
	game.theme.pixel = false
	game._update_camera(1.0 / 60.0)
	check(game.camera.zoom.x > base, "non-pixel maze retains cinematic zoom")
	game.theme.pixel = true
	if had_zone: room.maze_zone = saved_zone
	else: room.erase("maze_zone")
	game.maze_dark = 0.0
	# The mirror needs its wider view to solve the puzzle, but not animated
	# fractional resampling. Keep the exact configured wider scale throughout.
	var saved_puzzles: Variant = game.frost_puzzles
	var puzzles := preload("res://src/world_kit/frost_puzzles.gd").new(game)
	puzzles.pieces = [{"type": "mirror_ghost", "room": int(game.state.room), "x": game.player.x + 400.0, "y": game.player.y}]
	game.frost_puzzles = puzzles
	for i in range(12):
		game._update_camera(1.0 / 60.0)
		check(is_equal_approx(game.camera.zoom.x, base * float(puzzles.cfg.ghost.zoom)), "mirror has stable wide pixel framing, frame %d" % i)
	puzzles.pieces.clear()
	game._update_camera(1.0 / 60.0)
	check(is_equal_approx(game.camera.zoom.x, base), "leaving mirror restores stable base zoom")
	game.theme.pixel = false
	puzzles.pieces = [{"type": "mirror_ghost", "room": int(game.state.room), "x": game.player.x + 400.0, "y": game.player.y}]
	game._update_camera(1.0 / 60.0)
	check(game.view_far < 1.0 and game.view_far > float(puzzles.cfg.ghost.zoom), "non-pixel mirror keeps its eased transition")
	game.theme.pixel = true
	game.frost_puzzles = saved_puzzles
	game._update_camera(1.0 / 60.0)


# Diagnostic, not a pass/fail FPS benchmark: one fixed tick per captured picture
# isolates work from catch-up and VSync. No user's save/profile is involved.
func _profile(game: Node) -> void:
	var room: Dictionary = {}
	for candidate: Dictionary in game.W.rooms:
		candidate.cleared = true
		candidate.fight = false
		if str(candidate.type) == "combat" and (room.is_empty() or candidate.cells.size() > room.cells.size()): room = candidate
	var points: Array[Vector2] = []
	for cell: Vector2i in room.cells:
		var at := (Vector2(cell) + Vector2(0.5, 0.8)) * float(game.C)
		if not game.box_blocked(game._player_box(at.x, at.y)): points.append(at)
	var reports: Array = []
	for spec: Array in [[0, 0], [32, 0], [128, 0], [128, 12]]:
		seed(8242)
		game.mobs.clear()
		game.monsters.reset()
		game.feel.reset()
		game.gas.clear()
		game.eshots.clear()
		game.shots.clear()
		game.state.room = room.index
		game.state.inv = 9999.0
		game.state.dead = 0.0
		game.state.hp = game.state.max_hp
		game.player.x = points[points.size() / 2].x
		game.player.y = points[points.size() / 2].y
		game.camera.position = Vector2(game.player.x, game.player.y)
		for i in range(spec[0]):
			var mob: Dictionary = game.monsters.spawn(room.index, points[(i * 31) % points.size()], "skelett")
			mob.hp = 100000.0
			mob.max = 100000.0
			mob.spawn = 0.0
			mob.cds.fill(99.0)
		game.talents._sync_mobs()
		for i in range(spec[1]): game.gas.emit("profile%d" % i, ["poison", "smoke"][i % 2], points[(i * 29) % points.size()], 160, 60, 20.0)
		game._simulation_clock.reset()
		game._skip_simulation_delta = false
		var samples: Array[float] = []
		var marks: Dictionary = {}
		for frame in range(50):
			game.PerfMarks.clear()
			var started := Time.get_ticks_usec()
			game._process(1.0 / 60)
			var elapsed := (Time.get_ticks_usec() - started) / 1000.0
			await RenderingServer.frame_post_draw
			if frame >= 10:
				samples.append(elapsed)
				for key: String in game.PerfMarks.totals: marks[key] = float(marks.get(key, 0.0)) + float(game.PerfMarks.totals[key]) / 40000.0
			await process_frame
		samples.sort()
		var sum := 0.0
		for value in samples: sum += value
		var report := {"mobs": spec[0], "clouds": spec[1], "process_mean_ms": sum / samples.size(), "process_p95_ms": samples[int(samples.size() * 0.95)], "named_cpu_mean_ms": marks}
		reports.append(report)
		print("CAMERA_PROFILE ", JSON.stringify(report))
	var file := FileAccess.open("res://production/qa/evidence/camera-stability/frame-profile.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(reports, "\t") + "\n")
