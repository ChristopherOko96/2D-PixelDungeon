extends SceneTree
## Controlled actual-story renderer capture; a synthetic kill, not a campaign playtest.
const Scene = preload("res://src/hell/krypta_dungeon.tscn")
const OUT := "res://output/soul-absorption"
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = Scene.instantiate()
	game.class_id = "necromancer"
	game.profile_path = OUT.path_join("capture-profile.json")
	game.meta_path = OUT.path_join("capture-meta.json")
	game.start_floor = 1
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	if game.loading_screen != null:
		game.loading_screen.queue_free()
		game.loading_screen = null
	game.mobs.clear()
	# Use the current generated story floor and a real unobstructed combat area.
	var room: Dictionary = {}
	for r: Dictionary in game.W.rooms:
		r.cleared = true
		r.fight = false
		if str(r.type) == "combat" and (room.is_empty() or r.cells.size() > room.cells.size()): room = r
	assert(not room.is_empty())
	var center := Vector2((room.bx + room.bw * 0.5) * 96, (room.by + room.bh * 0.5) * 96)
	var me := Vector2.ZERO
	var closest := INF
	for cell: Vector2i in room.cells:
		var at := (Vector2(cell) + Vector2(0.5, 0.8)) * 96
		if game._cell(cell.x, cell.y) != 1 or game.box_blocked(game._player_box(at.x, at.y)): continue
		if at.distance_to(center) < closest:
			me = at
			closest = at.distance_to(center)
	if me == Vector2.ZERO:
		printerr("CAPTURE_FAIL: no free authored floor cell in room ", room.get("name", ""))
		game.queue_free()
		quit(1)
		return
	var source := me
	var score := INF
	for cell: Vector2i in room.cells:
		var at := (Vector2(cell) + Vector2(0.5, 0.8)) * 96
		if game._cell(cell.x, cell.y) != 1 or game.box_blocked(game._player_box(at.x, at.y)): continue
		if at.distance_to(me + Vector2(-240, 0)) < score:
			source = at
			score = at.distance_to(me + Vector2(-240, 0))
	assert(source.distance_to(me) > 96)
	game.player.x = me.x
	game.player.y = me.y
	game.player.face = -1.0
	game.player.aim = Vector2.LEFT
	game.camera.position = me + Vector2(-50, -20)
	game.camera.reset_smoothing()
	game.state.room = room.index
	game.state.toasts = []
	game.state.banner.t = 99.0
	game.state.inv = 0.0
	game.state.t = 20.0
	await _capture(me,source,room)
	game.queue_free()
	await process_frame
	for file: String in ["capture-profile.json", "capture-meta.json"]:
		var path := ProjectSettings.globalize_path(OUT.path_join(file))
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit()

func _capture(me: Vector2, source: Vector2, _room: Dictionary) -> void:
	# A real line of sight: guided pixel matter now correctly stops at walls,
	# unlike the old illustrative sprite that could cross a closed corridor.
	var best := INF
	for angle in range(16):
		var point := me+Vector2.from_angle(angle*TAU/16)*180
		if game.talents.talent_blocked(me,point,2): continue
		var score := point.distance_to(me+Vector2(-180,0))
		if score<best:
			best=score
			source=point
	var tc = game.talents.tc
	tc.runtime(1).res = 0.0
	game.talents.killed({"hp": 0.0, "p": source, "kind": "skeleton", "boss": false})
	var paid: Array = tc.events.filter(func(e: Dictionary) -> bool: return str(e.kind) == "souls")
	assert(paid.size() == 1 and float(tc.runtime(1).res) == 8.0)
	var event: Dictionary = paid[0]
	var duration:=float(game.talents.fx.cfg.get("soul_absorption",{}).get("release_duration",1.4))
	for frame in range(ceili((duration+0.1)*60)):
		var age := float(frame) / 60.0
		game.state.t = 20.0 + age
		var moved_y:=me.y-age*42.0
		if not game.box_blocked(game._player_box(me.x,moved_y)): game.player.y=moved_y
		event.life = maxf(0.0, 0.7 - age)
		if age>=0.7:tc.events.erase(event)
		game.talents._sync_hero()
		game.feel.update(1.0/60)
		game.story_hero.update(1.0 / 60.0)
		game.actors.queue_redraw()
		game.hud.queue_redraw()
		game.story_glow.frame()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png(OUT.path_join("frame-%03d.png" % frame))
		if frame in [8, 22, 35, 42]:
			var point: Dictionary = game.talents.fx.soul_absorption(event, game.state.t)
			print("SOUL_CAPTURE frame=%d soul=%s target=%s resource=%.1f" % [frame, str(point.get("at", "done")), str(point.get("to", "done")), float(tc.runtime(1).res)])
