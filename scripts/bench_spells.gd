extends SceneTree
## Measures what the spells cost in the crypt: the Testraum (seed 4242, its
## big room) with three training dummies beside the hero; per class and
## specialisation (every talent at full rank, ultimate stage 3, free casts)
## the hero casts his bar talents and his ultimate in turn, one every
## CAST_EVERY s (one still reloading is tried again until it fires, so every
## spell comes in its turn), for SECONDS s of real time after WARM_S s (the same
## casts for every specialisation, however slow its frames). Prints and writes
## (<output_dir>/bench.md) the frame time (avg, p95, max) and what the crypt
## view's systems cost per frame (src/dungeon_view.gd frame_stats), vsync off.
## Uses the test profile and the Testraum's profile copy; removes both after.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/bench_spells.gd -- <output_dir> [label]
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const TestArena = preload("res://src/debug/test_arena.gd")
const PerfMarks = preload("res://src/debug/perf_marks.gd")
## Seconds each specialisation is measured, after WARM_S seconds of casting.
const SECONDS := 6.0
const WARM_S := 0.6
const CAST_EVERY := 0.26
## Frames at least this slow (ms) are broken down (SPIKE lines).
const SPIKE_MS := 45.0
const SECTIONS := ["talent.ground", "talent.pets", "talent.events", "talent.auras", "skill.ground+pools", "skill.over", "particles", "gas", "boss+pools", "rigs", "sprites"]

var _out := "res://production/qa/evidence/perf/zauber-vorher"
var _label := "vorher"
## Only these classes (third argument, comma separated); empty: all.
var _only: Array = []
var _game: Node
var _rows: Array = []
var _casts: Array = []
var _next := 0
var _cast_at := 0.0
var _dummies: Array = []
## casts that fired and why the others did not (per specialisation)
var _cast_ok := 0
var _blocked: Dictionary = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _label = args[1]
	if args.size() > 2: _only = Array(args[2].split(","))
	_run.call_deferred()


func _wait(frames: int, casting := false) -> void:
	for i in range(frames):
		_tick(casting)
		await process_frame


## Keeps the hero alive and the dummies still; casts the next spell when due.
func _tick(casting: bool) -> void:
	if _game == null or not _game.players.has(1):
		return
	_game.players[1].invulnerable = 5.0
	_game.players[1].hp = maxi(6, int(_game.players[1].hp))
	for dummy: Dictionary in _dummies:
		dummy.hp = float(dummy.max_hp)
		dummy.move_timer = 99.0
		dummy.shot_timer = 99.0
	if not casting or _casts.is_empty():
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now < _cast_at:
		return
	_cast_at = now + CAST_EVERY
	var hero: Vector2 = _game.players[1].pos
	var target: Vector2 = Vector2(_dummies[_next % _dummies.size()].pos) if not _dummies.is_empty() else hero + Vector2(150, 0)
	var id := str(_casts[_next % _casts.size()])
	var why := str(_game.talent_combat.cast_blocker(1, id))
	if _game.talent_combat.cast(1, id, {"aim": (target - hero).normalized(), "target": target}):
		_cast_ok += 1
		_next += 1
	else:
		_blocked[id + ": " + why] = int(_blocked.get(id + ": " + why, 0)) + 1
		# still reloading: the same spell again next time (every spell in its
		# turn, the same order however slow the frames); anything else: the next
		if why != "Abklingzeit":
			_next += 1


func _measure(name: String) -> void:
	var warm_until := Time.get_ticks_msec() + int(WARM_S * 1000.0)
	while Time.get_ticks_msec() < warm_until:
		await _wait(1, true)
	_game.view.frame_stats = {"process": 0, "draw": 0, "glow": 0, "frames": 0}
	PerfMarks.clear()
	_cast_ok = 0
	_blocked.clear()
	var times: Array = []
	var spikes: Array = []
	var until := Time.get_ticks_msec() + int(SECONDS * 1000.0)
	while Time.get_ticks_msec() < until:
		_tick(true)
		var stats_before: Dictionary = _game.view.frame_stats.duplicate()
		var marks_before: Dictionary = PerfMarks.totals.duplicate()
		var skill_pools: RefCounted = _game.view._skill_fx.pools
		if skill_pools != null:
			for key: String in skill_pools.draw_parts: marks_before["pool." + key] = int(skill_pools.draw_parts[key])
		var t0 := Time.get_ticks_usec()
		await process_frame
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		times.append(ms)
		if ms >= SPIKE_MS and spikes.size() < 10:
			spikes.append(_spike(ms, stats_before, marks_before))
	for line: String in spikes:
		print("SPIKE %-18s %s" % [name, line])
	times.sort()
	var sum := 0.0
	for t: float in times: sum += t
	var stats: Dictionary = _game.view.frame_stats
	var n := maxf(1.0, float(stats.get("frames", 1)))
	var row := {"name": name, "avg": sum / times.size(), "p95": times[int(times.size() * 0.95)], "max": times.back()}
	var parts := ""
	for key: String in SECTIONS:
		row[key] = float(stats.get(key, 0)) / 1000.0 / n
		parts += "  %s %.2f" % [key, row[key]]
	_rows.append(row)
	var marks := {}
	for key: String in PerfMarks.totals:
		var ms := float(PerfMarks.totals[key]) / 1000.0 / n
		if ms >= 0.05: marks[key] = snappedf(ms, 0.01)
	print("MARKS %-18s %s" % [name, str(marks)])
	print("CASTS %-18s ok %d  blocked %s" % [name, _cast_ok, str(_blocked)])
	var pools: RefCounted = _game.view._boss_fx.pools
	if pools != null:
		var pn := maxf(1.0, float(pools.draw_frames))
		var pp := {}
		for key: String in pools.draw_parts: pp[key] = snappedf(float(pools.draw_parts[key]) / 1000.0 / pn, 0.01)
		print("POOLS %-18s %s bakes %s" % [name, str(pp), str(pools.bake_counts)])
		pools.draw_parts.clear()
		pools.bake_counts.clear()
		pools.draw_us = 0
		pools.draw_frames = 0
	print("SPELL %-18s avg %6.2f  p95 %6.2f  max %6.2f |%s" % [name, row.avg, row.p95, row.max, parts])


## What a slow frame (`ms`) spent its time on: the view's sections and marks
## that grew most in it (ms), "rest" what the view did not measure (the game's
## own step, rendering).
func _spike(ms: float, stats_before: Dictionary, marks_before: Dictionary) -> String:
	var parts: Array = []
	var stats: Dictionary = _game.view.frame_stats
	var view := 0.0
	for key: String in stats:
		if key in ["frames", "process", "draw", "glow"]:
			continue
		var d := float(int(stats[key]) - int(stats_before.get(key, 0))) / 1000.0
		if d >= 1.0: parts.append([key, d])
	for key: String in ["process", "draw", "glow"]:
		view += float(int(stats[key]) - int(stats_before.get(key, 0))) / 1000.0
	for key: String in PerfMarks.totals:
		var d := float(int(PerfMarks.totals[key]) - int(marks_before.get(key, 0))) / 1000.0
		if d >= 1.0: parts.append([key, d])
	var skill_pools: RefCounted = _game.view._skill_fx.pools
	if skill_pools != null:
		for key: String in skill_pools.draw_parts:
			var d := float(int(skill_pools.draw_parts[key]) - int(marks_before.get("pool." + key, 0))) / 1000.0
			if d >= 1.0: parts.append(["pool." + key, d])
	parts.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]))
	var text := "%.1f ms: view %.1f rest %.1f |" % [ms, view, ms - view]
	for part: Array in parts.slice(0, 8):
		text += " %s %.1f" % [part[0], part[1]]
	return text


## Clears what the last specialisation left (zones, traps, pets, clouds, pools, shots).
func _clear() -> void:
	_game.talent_combat.pets.clear()
	_game.talent_combat.traps.clear()
	_game.talent_combat.zones.clear()
	_game.hero_skills.zones.clear()
	_game.boss_moves.reset()
	_game.bullets.clear()
	var gas: RefCounted = _game.view.get("_gas")
	if gas != null: gas.clear()
	if _game.view._boss_fx.pools != null: _game.view._boss_fx.pools.clear()


## Three training dummies beside the hero, on open floor.
func _place_dummies() -> void:
	_game.enemies.clear()
	_dummies.clear()
	var hero: Vector2 = _game.players[1].pos
	var particles: RefCounted = _game.view._feedback.particles
	for offset: Vector2 in [Vector2(150, -40), Vector2(180, 30), Vector2(140, 90), Vector2(-150, -40), Vector2(-170, 40), Vector2(0, 150)]:
		if _dummies.size() >= 3:
			break
		if particles.solid(hero + offset):
			continue
		var dummy: Dictionary = _game._create_enemy("skeleton_guard", hero + offset)
		dummy.max_hp = 999999
		dummy.hp = 999999.0
		_game.enemies.append(dummy)
		_dummies.append(dummy)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(40)
	var talents: Dictionary = TestArena._load(TestArena.TALENTS).get("talents", {})
	var first := true
	for class_id: String in ["swordsman", "archer", "mage"]:
		if not _only.is_empty() and not _only.has(class_id):
			continue
		if first:
			_game.start_test_arena(class_id)
			first = false
		else:
			_game.restart_test_arena(class_id)
		await _wait(90)
		var bar: Control = _game._arena_bar
		for index in range(bar._specs.size()):
			var spec: Dictionary = bar._specs[index]
			bar._spec_pick.selected = index
			bar._stage_pick.selected = 2
			bar.apply_spec()
			_casts.clear()
			for id: String in spec.get("talents", []):
				var kind := str(talents.get(id, {}).get("kind", ""))
				if kind in ["active", "ultimate"]:
					_casts.append(id)
			_clear()
			_place_dummies()
			await _wait(20)
			await _measure("%s/%s" % [class_id, str(spec.id)])
			await _wait(1)
			var image := root.get_texture().get_image()
			image.save_png(_out.path_join("%s-%s.png" % [class_id, str(spec.id)]))
	var lines := ["# Zauber-Rechenzeit (%s)" % _label, "", "Krypta-Testraum, Seed 4242, je Spezialisierung alle Leistenzauber und das Ultimate (Stufe 3) im Wechsel alle %.2f s, %.0f s Messzeit nach %.1f s Aufwaermen, V-Sync aus. Systeme in ms je Frame." % [CAST_EVERY, SECONDS, WARM_S], ""]
	var head := "| Spezialisierung | Mittel | p95 | Max |"
	var line := "|---|---|---|---|"
	for key: String in SECTIONS:
		head += " %s |" % key
		line += "---|"
	lines.append_array([head, line])
	for row: Dictionary in _rows:
		var text := "| %s | %.2f | %.2f | %.2f |" % [row.name, row.avg, row.p95, row.max]
		for key: String in SECTIONS:
			text += " %.2f |" % float(row[key])
		lines.append(text)
	var file := FileAccess.open(_out.path_join("bench.md"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	_game._leave_session("Messung fertig.")
	await _wait(5)
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(TestArena._load(TestArena.DATA).get("profile_copy", "user://profile_testraum.json"))))
	quit(0)
