extends SceneTree
## Paired full simulation ticks in real Krypta scenes, only gas field differs.
## Both keep the already implemented enemy index. No rendering/FPS claim.
## First run production/qa/evidence/gas-queries/recreate-baseline.ps1.
const SCENE = preload("res://src/hell/krypta_dungeon.tscn")
const OUT := "res://output/gas-story-bench"
const DT := 1.0 / 60.0
var games: Array[Node] = []
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not FileAccess.file_exists("res://output/gas-query-baseline/gas.gd"):
		printerr("Run production/qa/evidence/gas-queries/recreate-baseline.ps1 first.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for legacy: bool in [true, false]:
		seed(4242)
		var game: Node = SCENE.instantiate()
		var label := "before" if legacy else "after"
		game.class_id = "necromancer"
		game.profile_path = OUT.path_join(label + "-profile.json")
		game.meta_path = OUT.path_join(label + "-meta.json")
		game.settings_path = OUT.path_join(label + "-settings.cfg")
		game.graphics_path = game.settings_path
		root.add_child(game)
		game.set_process(false)
		await process_frame
		if game.loading_screen != null:
			game.loading_screen.queue_free()
			game.loading_screen = null
		# Preserve particle links when installing the frozen reference painter.
		if legacy:
			var old_gas: RefCounted = game.gas
			game.gas = load("res://output/gas-query-baseline/gas.gd").new(game.PIXEL_WORLD, game._floor_open)
			for link: Array in game.feel.feedback.particles._liquids:
				if (link[0] as WeakRef).get_ref() == old_gas: link[0] = weakref(game.gas)
			if game.talents.fx.gas == old_gas: game.talents.fx.gas = game.gas
		var room: Dictionary = {}
		for candidate: Dictionary in game.W.rooms:
			candidate.cleared = true
			candidate.fight = false
			if str(candidate.type) == "combat" and (room.is_empty() or candidate.cells.size() > room.cells.size()):
				room = candidate
		var points: Array[Vector2] = []
		for cell: Vector2i in room.cells:
			var point: Vector2 = (Vector2(cell) + Vector2(0.5, 0.8)) * game.C
			if not game.box_blocked(game._player_box(point.x, point.y)): points.append(point)
		if points.size() < 10:
			printerr("Not enough free floor in fixture")
			quit(2)
			return
		game.set_meta("room", room)
		game.set_meta("points", points)
		games.append(game)
		print("GAS_STORY_READY ", label)
	var rows: Array = []
	for spec: Dictionary in [{"mobs": 32, "clouds": 4}, {"mobs": 128, "clouds": 0}, {"mobs": 128, "clouds": 12}]:
		for game: Node in games: _reset(game, spec)
		var times: Array = [[], []]
		var ratios: Array = []
		var same := true
		for tick in range(32):
			for which: int in ([0, 1] if tick % 2 == 0 else [1, 0]):
				seed(7341 + tick)
				var start := Time.get_ticks_usec()
				games[which]._update(DT)
				if tick >= 8: times[which].append(float(Time.get_ticks_usec() - start) / 1000.0)
			same = same and _same_state()
			if tick >= 8: ratios.append(float(times[1].back()) / maxf(0.001, times[0].back()))
		var row := spec.duplicate()
		row.before = _stats(times[0])
		row.after = _stats(times[1])
		ratios.sort()
		row.median_ratio = ratios[ratios.size() / 2]
		row.exact_match = same
		row.affected_mobs = 0
		for mob: Dictionary in games[1].mobs:
			if float(mob.hp) < 100000.0 or float(mob.get("blind", 0.0)) > 0.0:
				row.affected_mobs += 1
		row.ratio_budget = 0.9 if int(spec.clouds) >= 12 else 1.15
		if not same: failures.append("Gameplay state differs: " + str(spec))
		if int(spec.clouds) > 0 and int(row.affected_mobs) == 0: failures.append("Fixture did not expose enemies to gas")
		if row.median_ratio > row.ratio_budget: failures.append("CPU budget exceeded: " + str(row))
		rows.append(row)
		print("GAS_STORY_PAIRED ", JSON.stringify(row))
	var file := FileAccess.open(OUT.path_join("paired.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	for game: Node in games: game.queue_free()
	await process_frame
	for label: String in ["before", "after"]:
		for suffix: String in ["-profile.json", "-meta.json", "-settings.cfg"]:
			var path := ProjectSettings.globalize_path(OUT.path_join(label + suffix))
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	for failure: String in failures: printerr("GAS_STORY_FAIL: ", failure)
	print("GAS_STORY_DONE cases=%d failures=%d" % [rows.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _reset(game: Node, spec: Dictionary) -> void:
	seed(8242 + int(spec.mobs))
	game.mobs.clear()
	game.shots.clear()
	game.eshots.clear()
	game.monsters.reset()
	game.feel.reset()
	game.feel.feedback.particles.clear()
	game.gas.clear()
	game.state.t = 20.0
	game.state.inv = 9999.0
	game.state.dead = 0.0
	var room: Dictionary = game.get_meta("room")
	var points: Array = game.get_meta("points")
	var hero: Vector2 = points[points.size() / 2]
	game.player.x = hero.x
	game.player.y = hero.y
	for i in range(int(spec.mobs)):
		var mob: Dictionary = game.monsters.spawn(room.index, points[(i * 31) % points.size()], "skelett")
		mob.hp = 100000.0
		mob.max = 100000.0
		mob.spawn = 0.0
		mob.cds.fill(99.0)
	game.talents._sync_mobs()
	for i in range(int(spec.clouds)):
		game.gas.emit("bench%d" % i, ["poison", "smoke"][i % 2], points[(i * 29) % points.size()], 160, 60, 20.0)

func _same_state() -> bool:
	var a: Node = games[0]
	var b: Node = games[1]
	if a.mobs.size() != b.mobs.size(): return false
	for i in range(a.mobs.size()):
		for property: String in ["p", "hp", "env", "gas_tick", "poison", "burn", "freeze", "statuses", "blind"]:
			if a.mobs[i].get(property) != b.mobs[i].get(property): return false
	for property: String in ["x", "y"]:
		if a.player.get(property) != b.player.get(property): return false
	for property: String in ["hp", "dot"]:
		if a.state.get(property) != b.state.get(property): return false
	if a.hero_gas != b.hero_gas or a.hero_gas_mat != b.hero_gas_mat: return false
	var clouds_a: Dictionary = a.gas.gas_field.clouds()
	var clouds_b: Dictionary = b.gas.gas_field.clouds()
	if clouds_a.keys() != clouds_b.keys(): return false
	for key: String in clouds_a:
		if clouds_a[key].puffs != clouds_b[key].puffs: return false
	return true

func _stats(values: Array) -> Dictionary:
	values.sort()
	var total := 0.0
	for value: float in values: total += value
	return {"mean_ms": total / values.size(), "p95_ms": values[int(values.size() * 0.95)]}
