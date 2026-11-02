extends SceneTree
## Measures what a busy fight costs in the three story worlds (Krypta, Hölle,
## Frostgruft on src/hell/hell_game.gd): the fire mage (every fire talent at
## full rank) casts his bar talents and his ultimate in turn every CAST_EVERY s
## into MOBS monsters standing round him (stunned, the hero untouchable), for
## SECONDS s of real time after WARM_S s, V-Sync off. Prints and writes
## (<output_dir>/story-<label>.md) the frame time (avg, p95, max) and the parts
## the game marks (src/debug/perf_marks.gd: u.* update, d.* drawing, talent.*).
## Fixed seed per world. Uses the test profile and settings; removes them after.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/bench_story.gd -- <output_dir> [label]
const SaveStore = preload("res://src/save/save_store.gd")
const PerfMarks = preload("res://src/debug/perf_marks.gd")
const WORLDS := [["krypta", "res://src/hell/krypta_dungeon.tscn"], ["hoelle", "res://src/hell/hell_dungeon.tscn"], ["frostgruft", "res://src/hell/frost_dungeon.tscn"]]
const SECONDS := 8.0
const WARM_S := 1.0
const CAST_EVERY := 0.3
const MOBS := 8
const SEED := 4242

var _out := "res://production/qa/evidence/perf/story"
var _label := "jetzt"
var _rows: Array = []
## Main-loop phase clocks (usec): the frame's process start, before and after the render.
var _t_proc := 0
var _t_pre := 0
var _t_post := 0
var _phase := {"logic+draw": 0.0, "render": 0.0, "rest": 0.0, "n": 0}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _label = args[1]
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	process_frame.connect(func() -> void:
		var now := Time.get_ticks_usec()
		if _t_post > 0 and _t_pre > 0 and _t_proc > 0:
			_phase["logic+draw"] += float(_t_pre - _t_proc) / 1000.0
			_phase.render += float(_t_post - _t_pre) / 1000.0
			_phase.rest += float(now - _t_post) / 1000.0
			_phase.n += 1
		_t_proc = now)
	RenderingServer.frame_pre_draw.connect(func() -> void: _t_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _t_post = Time.get_ticks_usec())
	for world: Array in WORLDS:
		await _world(str(world[0]), str(world[1]))
	_write()
	for f in ["user://settings_test.cfg", "user://profile_test.json", "user://bench_meta.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	quit(0)


func _world(tag: String, scene: String) -> void:
	seed(SEED)
	var g: Node = (load(scene) as PackedScene).instantiate()
	g.class_id = "mage"
	g.meta_path = "user://bench_meta.cfg"
	g.saves = SaveStore.new("user://bench_saves_%s/" % tag)
	g.settings_path = "user://settings_test.cfg"
	g.graphics_path = "user://settings_test.cfg"
	root.add_child(g)
	await _frames(240)
	for r: Dictionary in g.W.rooms:
		r.fight = false
		r.cleared = true
	g.mobs.clear()
	var hero := Vector2(float(g.player.x), float(g.player.y))
	var room := int(g.state.room)
	for i in range(MOBS):
		var spot := hero + Vector2.from_angle(TAU * float(i) / float(MOBS)) * Vector2(170.0, 110.0)
		if g.monsters != null:
			var ids: Array = g.monsters.defs.keys()
			ids.sort()
			g.monsters.spawn(room, spot, str(ids[i % ids.size()]))
		else:
			g._spawn_mob(room, spot, ["frost_skeleton", "ice_zombie", "snowman", "ice_knight"][i % 4])
	var tc: RefCounted = g.talents.tc
	var ranks := {}
	var actives: Array = []
	for id: String in tc.data.talents:
		var info: Dictionary = tc.data.talents[id]
		if str(info.get("class", "")) == "mage" and str(info.get("spec", "")) == "fire":
			ranks[id] = int(info.get("ranks", 1))
			if str(info.get("kind", "")) == "active": actives.append(id)
	actives.sort()
	tc.set_build(1, {"class": "mage", "level": 30, "ranks": ranks, "bar": actives.slice(0, 4)})
	var slots: Array = [0, 1, 2, 3, -1]
	var frames: Array = []
	PerfMarks.clear()
	var last := Time.get_ticks_usec()
	var start := last
	var cast_at := 0.0
	var turn := 0
	var measuring := false
	var marks := {}
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var extra := {"process": 0.0, "render_cpu": 0.0, "render_gpu": 0.0, "draw_calls": 0.0, "objects": 0.0}
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var t := float(now - start) / 1000000.0
		var rt: Dictionary = tc.runtime(1)
		rt.res = 999.0
		rt.cds = {}
		rt.gcd = 0.0
		g.state.inv = 5.0
		for m: Dictionary in g.mobs:
			m.stun = 5.0
		if t >= cast_at:
			cast_at = t + CAST_EVERY
			var living: Array = g.mobs.filter(func(m: Dictionary) -> bool: return float(m.get("hp", 0.0)) > 0.0)
			g.aim_at = Vector2(living[turn % living.size()].p) if not living.is_empty() else hero + Vector2(160, 0)
			g.talents.press(int(slots[turn % slots.size()]))
			turn += 1
		if not measuring and t >= WARM_S:
			measuring = true
			_phase = {"logic+draw": 0.0, "render": 0.0, "rest": 0.0, "n": 0}
			PerfMarks.clear()
			frames.clear()
		elif measuring:
			frames.append(float(now - last) / 1000.0)
			extra.process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			extra.render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
			extra.render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			extra.draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			extra.objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		last = now
		if t >= WARM_S + SECONDS:
			marks = PerfMarks.totals.duplicate()
			break
	frames.sort()
	var n := maxi(1, frames.size())
	var total := 0.0
	for f: float in frames: total += f
	var row := {"world": tag, "frames": frames.size(), "avg": total / n, "p95": float(frames[int(n * 0.95)]) if not frames.is_empty() else 0.0,
		"max": float(frames[-1]) if not frames.is_empty() else 0.0, "parts": {}}
	var marked := 0.0
	for key: String in marks:
		row.parts[key] = float(marks[key]) / 1000.0 / n
		marked += float(row.parts[key])
	for key: String in extra:
		row["x_" + key] = float(extra[key]) / n
	row.marked = marked
	for key: String in ["logic+draw", "render", "rest"]:
		row["p_" + key] = float(_phase[key]) / maxf(1.0, float(_phase.n))
	_rows.append(row)
	print("BENCH %s phases: logic+draw=%.2f render=%.2f rest=%.2f" % [tag, row["p_logic+draw"], row.p_render, row.p_rest])
	print("BENCH %s frames=%d avg=%.2f p95=%.2f max=%.2f | process=%.2f render_cpu=%.2f render_gpu=%.2f marked=%.2f draw_calls=%.0f objects=%.0f" % [tag, row.frames, row.avg, row.p95, row.max, row.x_process, row.x_render_cpu, row.x_render_gpu, row.marked, row.x_draw_calls, row.x_objects])
	var keys: Array = row.parts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(row.parts[a]) > float(row.parts[b]))
	for key: String in keys:
		print("BENCH   %-24s %.2f ms" % [key, float(row.parts[key])])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out.path_join("%s-%s.png" % [tag, _label])))
	g.queue_free()
	await _frames(5)


func _write() -> void:
	var lines := ["# Story-Welten: Rechenzeit (%s)" % _label, "",
		"Feuermagier, alle Feuertalente voll, Leiste und Ultimate im Wechsel alle %.2f s, %d Gegner, %.0f s Messzeit nach %.0f s, V-Sync aus. ms je Frame." % [CAST_EVERY, MOBS, SECONDS, WARM_S], "",
		"| Welt | Frames | Mittel | p95 | Max | Skripte (process) | Render CPU | Render GPU | Draw-Calls |", "|---|---|---|---|---|---|---|---|---|"]
	for row: Dictionary in _rows:
		lines.append("| %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.0f |" % [row.world, row.frames, row.avg, row.p95, row.max, row.x_process, row.x_render_cpu, row.x_render_gpu, row.x_draw_calls])
	lines.append("")
	for row: Dictionary in _rows:
		lines.append("## %s" % row.world)
		lines.append("")
		var keys: Array = row.parts.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return float(row.parts[a]) > float(row.parts[b]))
		for key: String in keys:
			lines.append("- %s: %.2f ms" % [key, float(row.parts[key])])
		lines.append("")
	var f := FileAccess.open(ProjectSettings.globalize_path(_out.path_join("story-%s.md" % _label)), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
