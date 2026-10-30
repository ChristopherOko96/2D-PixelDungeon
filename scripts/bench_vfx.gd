extends SceneTree
## Measures what the element effects cost in the crypt: the frame time with
## vsync off while the load is built up step by step in one room (seed 4242,
## the biggest room, no enemies): empty, + six pools of different materials,
## + three big gas clouds, + a steady stream of particle bursts (blasts, fire,
## ice shards, sparks, rubble), + a boss vortex and a storm zone. Each step
## is measured over FRAMES frames after WARM frames; it prints avg, p95 and
## max frame ms per step, writes them to <output_dir>/bench.md and keeps a
## screenshot of the full load (the look must not change when it gets
## faster). Uses the test profile and removes it after.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/bench_vfx.gd -- <output_dir> [label]
const Game = preload("res://src/game.gd")
const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const Profile = preload("res://src/progress/profile.gd")
const WARM := 30
const FRAMES := 240

var _out := "res://production/qa/evidence/perf/vorher"
var _label := "vorher"
var _game: Node
var _spot := Vector2.ZERO
var _rows: Array = []
## particle bursts per frame of the busy steps (0: none)
var _busy := false
var _tick := 0
## single costs measured at full load: [name, ms per call]
var _costs: Array = []


## Times one drawing job inside a real draw callback (canvas commands count).
class Probe extends Node2D:
	var job: Callable
	var spent: Array = []

	func _draw() -> void:
		if not job.is_valid():
			return
		var t0 := Time.get_ticks_usec()
		job.call(self)
		spent.append(float(Time.get_ticks_usec() - t0) / 1000.0)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _label = args[1]
	_run.call_deferred()


func _hold_hero() -> void:
	if _game != null and _game.players.has(1):
		_game.players[1].invulnerable = 5.0
		_game.players[1].hp = maxi(6, int(_game.players[1].hp))


func _wait(frames: int) -> void:
	for i in range(frames):
		_hold_hero()
		_load()
		await process_frame


## The steady particle load of the busy steps: a burst every few frames.
func _load() -> void:
	if not _busy or _game == null:
		return
	_tick += 1
	var particles: RefCounted = _game.view._feedback.particles
	var at := _spot + Vector2(float((_tick * 37) % 240) - 120.0, float((_tick * 53) % 140) - 70.0)
	match _tick % 6:
		0: particles.kick(at, 40.0, 1.0)
		1: particles.fire_burst(at, 30.0)
		2: particles.shatter(at, 10, Vector2.ZERO, 180.0)
		3: particles.sparks(at, Vector2.UP, 8)
		4: particles.rubble(at, 8)
		5: particles.embers(at, 20.0, 8)


func _measure(name: String) -> void:
	await _wait(WARM)
	_game.view.frame_stats = {"process": 0, "draw": 0, "glow": 0, "frames": 0}
	var times: Array = []
	var proc := 0.0
	var calls := 0.0
	var prims := 0.0
	for i in range(FRAMES):
		_hold_hero()
		_load()
		var t0 := Time.get_ticks_usec()
		await process_frame
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("MON   %-26s process %6.2f ms  draw calls %7.0f  primitives %8.0f" % [name, proc / FRAMES, calls / FRAMES, prims / FRAMES])
	times.sort()
	var sum := 0.0
	for t: float in times: sum += t
	var row := {"name": name, "avg": sum / times.size(), "p95": times[int(times.size() * 0.95)], "max": times.back()}
	var stats: Dictionary = _game.view.frame_stats
	var n := maxf(1.0, float(stats.frames))
	print("VIEW  %-26s process %5.2f ms  draw %5.2f ms  glow %5.2f ms" % [name, float(stats.process) / 1000.0 / n, float(stats.draw) / 1000.0 / n, float(stats.glow) / 1000.0 / n])
	_game.view.frame_stats = {"process": 0, "draw": 0, "glow": 0, "frames": 0}
	var pools_now: RefCounted = _game.view._boss_fx.pools
	if pools_now != null:
		var total := 0
		for mat: String in pools_now.bake_counts: total += int(pools_now.bake_counts[mat])
		print("BAKES %-24s %s (gesamt %d)" % [name, str(pools_now.bake_counts), total])
		pools_now.bake_counts.clear()
		print("DRAW  %-26s Pfuetzen draw je Frame %6.2f ms" % [name, float(pools_now.draw_us) / 1000.0 / maxf(1.0, float(pools_now.draw_frames))])
		var parts := {}
		for part: String in pools_now.draw_parts: parts[part] = snappedf(float(pools_now.draw_parts[part]) / 1000.0 / maxf(1.0, float(pools_now.draw_frames)), 0.01)
		print("PARTS %-26s %s" % [name, str(parts)])
		pools_now.draw_parts.clear()
		pools_now.draw_us = 0
		pools_now.draw_frames = 0
	_rows.append(row)
	print("BENCH %-28s avg %6.2f ms  p95 %6.2f ms  max %6.2f ms" % [name, row.avg, row.p95, row.max])


## The single costs at full load: drawing jobs inside a probe's draw callback,
## steps called directly (each a little extra simulation; it is a measurement).
func _probes() -> void:
	var probe := Probe.new()
	probe.modulate = Color(1, 1, 1, 0)
	root.add_child(probe)
	var view: Node = _game.view
	var gas: RefCounted = view.get("_gas")
	var pools: RefCounted = view._boss_fx.pools
	var particles: RefCounted = view._feedback.particles
	var jobs := {}
	if gas != null:
		jobs["Gas zeichnen"] = func(c: CanvasItem) -> void:
			gas._drawn_frame = -1
			gas.draw(c, float(view._clock))
	if pools != null:
		jobs["Pfuetzen zeichnen (ohne Backen)"] = func(c: CanvasItem) -> void:
			pools._drawn_frame = -1
			pools.draw(c, float(view._clock))
	if pools != null:
		jobs["  Pfuetzen: Ueberlagerung"] = func(c: CanvasItem) -> void:
			for mat: String in pools._fields:
				var fd: Dictionary = pools._fields[mat]
				if fd.tex != null: pools._overlay(c, fd, mat, str(pools.cfg.materials[mat].get("style", "liquid")), float(view._clock))
		jobs["  Pfuetzen: Ringe, Risse, Funken"] = func(c: CanvasItem) -> void:
			for mat: String in pools._fields:
				var fd: Dictionary = pools._fields[mat]
				pools._draw_ripples(c, fd, mat, float(view._clock))
				pools._draw_cracks(c, fd, mat, float(view._clock))
				pools._draw_zaps(c, fd, float(view._clock))
		jobs["  Pfuetzen: Kruste, Reaktion, Sog"] = func(c: CanvasItem) -> void:
			pools._draw_hot_crust(c, float(view._clock))
			pools._react(float(view._clock))
			pools._pull(float(view._clock))
	if gas != null:
		jobs["  Gas: ein Material neu aufbauen"] = func(c: CanvasItem) -> void:
			gas._drawn_frame = -1
			for m: String in gas._layers: gas._layers[m].built = -1.0
			gas.draw(c, float(view._clock))
	jobs["Sturm zeichnen"] = func(c: CanvasItem) -> void:
		for zone: Dictionary in view._snapshot.get("skill_fx", {}).get("zones", []):
			if str(zone.kind) == "storm":
				view._skill_fx._draw_storm(c, zone, Vector2(float(zone.x), float(zone.y)), float(zone.r), float(view._clock))
	jobs["Strudel zeichnen"] = func(c: CanvasItem) -> void:
		view._boss_fx._draw_vortex(c, _spot + Vector2(80, -20), 110.0, 1.0, "void", Color("c06bd8"), float(view._clock))
	jobs["Partikel zeichnen"] = func(c: CanvasItem) -> void:
		particles.draw_stains(c)
		particles.draw_particles(c)
	for name: String in jobs:
		probe.job = jobs[name]
		probe.spent.clear()
		for i in range(20):
			_hold_hero()
			probe.queue_redraw()
			await process_frame
		_cost(name, probe.spent)
	probe.job = Callable()
	# the steps, called directly
	var steps := {"Partikel-Schritt": func() -> void: particles.update(1.0 / 60.0)}
	if gas != null:
		steps["Gas-Schritt"] = func() -> void: gas.step(1.0 / 60.0, float(view._clock))
	if pools != null:
		steps["Pfuetzen backen (alle Felder)"] = func() -> void:
			for mat: String in pools._fields:
				var style := str(pools.cfg.materials[mat].get("style", "liquid"))
				pools._bake(pools._fields[mat], mat, style, float(view._clock), int(floor(float(view._clock) * 6.0)))
	if pools != null:
		for mat: String in pools._fields:
			var one := mat
			steps["  backen: " + one] = func() -> void:
				var style := str(pools.cfg.materials[one].get("style", "liquid"))
				pools._bake(pools._fields[one], one, style, float(view._clock), int(floor(float(view._clock) * 6.0)))
	for name: String in steps:
		var spent: Array = []
		for i in range(20):
			var t0 := Time.get_ticks_usec()
			(steps[name] as Callable).call()
			spent.append(float(Time.get_ticks_usec() - t0) / 1000.0)
			await process_frame
		_cost(name, spent)
	probe.queue_free()


func _cost(name: String, spent: Array) -> void:
	var sum := 0.0
	for t: float in spent: sum += t
	var avg := sum / maxf(1.0, float(spent.size()))
	_costs.append([name, avg])
	print("COST %-32s %6.2f ms" % [name, avg])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	_game.player_classes[1] = "swordsman"
	_game.requested_seed = 4242
	_game._start_solo()
	await _wait(60)
	var best := 0
	for index in range(_game.floor_layouts.size()):
		var a: Array = _game.floor_layouts[index].world_size
		var b: Array = _game.floor_layouts[best].world_size
		if float(a[0]) * float(a[1]) > float(b[0]) * float(b[1]): best = index
	_game.room = best + 1
	_game._spawn_room()
	_game.enemies.clear()
	_game.bullets.clear()
	_game.hordes.enabled = false
	_game.phase = "combat"
	await _wait(20)
	var walk := FxSprites.walkable_cells(_game.current_layout)
	var corner := Vector2i(1 << 30, 0)
	for c: Vector2i in walk:
		var open := true
		for y in range(0, 6):
			for x in range(0, 10):
				if not walk.has(c + Vector2i(x, y)): open = false
		if open and (corner.x == 1 << 30 or c.y * 1000 + c.x < corner.y * 1000 + corner.x): corner = c
	_spot = Vector2(corner) * 32.0 + Vector2(160, 96)
	_game.players[1].pos = _spot + Vector2(-140, 60)
	await _wait(120)
	await _measure("1 leer")
	# six pools of different materials
	var mats := ["poison", "void", "lava", "ice", "blood", "water"]
	for i in range(mats.size()):
		var at := _spot + Vector2(-120.0 + float(i % 3) * 120.0, -40.0 + float(i / 3) * 80.0)
		_game.boss_moves._pool(at, {"style": mats[i], "radius": 46, "time": 120.0, "dps": 0}, Vector2(1, 0))
	await _measure("2 + 6 Pfuetzen")
	# three big gas clouds
	var gas: RefCounted = _game.view.get("_gas")
	if gas != null:
		for i in range(3):
			gas.emit("bench%d" % i, ["poison", "smoke", "frost"][i], _spot + Vector2(-110.0 + float(i) * 110.0, 0.0), 90.0, 120.0, float(_game.view._clock))
	await _measure("3 + 3 Gaswolken")
	_busy = true
	await _measure("4 + Partikel-Dauerlast")
	_game.boss_moves._zone("vortex", "void", _spot + Vector2(80, -20), 110.0, 120.0)
	_game.hero_skills._zone({"kind": "storm", "pos": _spot + Vector2(-80, 20), "radius": 50.0, "time": 120.0, "owner": 1, "dps": 0.0, "tick": 0.0})
	await _measure("5 + Strudel und Sturm")
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join("vollast.png"))
	await _probes()
	# and taken away again, to see what stays
	var gas_layer: RefCounted = _game.view.get("_gas")
	if gas_layer != null: gas_layer.clear()
	await _measure("6 - Gas")
	_game.boss_moves.reset()
	await _measure("7 - Pfuetzen und Strudel")
	_busy = false
	await _measure("8 - Partikel-Last (Sturm bleibt)")
	var lines := ["# VFX-Rechenzeit (%s)" % _label, "", "Krypta, Seed 4242, groesster Raum, V-Sync aus, %d Frames je Stufe nach %d Aufwaerm-Frames." % [FRAMES, WARM], "", "| Stufe | Mittel ms | p95 ms | Max ms |", "|---|---|---|---|"]
	for row: Dictionary in _rows:
		lines.append("| %s | %.2f | %.2f | %.2f |" % [row.name, row.avg, row.p95, row.max])
	lines.append_array(["", "Einzelkosten unter Volllast (ms je Aufruf, Mittel ueber 20):", "", "| Teil | ms |", "|---|---|"])
	for cost: Array in _costs:
		lines.append("| %s | %.2f |" % [cost[0], cost[1]])
	var file := FileAccess.open(_out.path_join("bench.md"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	_busy = false
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
