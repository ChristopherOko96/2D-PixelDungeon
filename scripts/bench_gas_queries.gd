extends SceneTree
## Alternating old/new CPU benchmark: whole gas step + actor contacts and exposure.
## First run production/qa/evidence/gas-queries/recreate-baseline.ps1 from repo root.
## --headless --path . -s res://scripts/bench_gas_queries.gd
## A targeted performance gate, not a rendered-frame/FPS measurement.
const Gas = preload("res://src/physics_kit/gas_field.gd")
const BASELINE := "res://output/gas-query-baseline/gas_field.gd"
const OUT := "res://output/gas-query-bench"
const DT := 1.0 / 60.0
var failures: Array[String] = []
var monster_profile: Dictionary = preload("res://src/combat/element_rules.gd").data().exposure.monster

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not FileAccess.file_exists(BASELINE):
		printerr("Run production/qa/evidence/gas-queries/recreate-baseline.ps1 first.")
		quit(2)
		return
	var previous: Script = load(BASELINE)
	var rows: Array = []
	for spec: Dictionary in [
		{"actors": 128, "clouds": 0, "dense": false},
		{"actors": 32, "clouds": 4, "dense": false},
		{"actors": 64, "clouds": 12, "dense": false},
		{"actors": 128, "clouds": 12, "dense": false},
		{"actors": 128, "clouds": 24, "dense": false},
		{"actors": 128, "clouds": 4, "dense": true},
		{"actors": 8, "clouds": 4, "dense": true}
	]:
		var fields: Array[RefCounted] = [previous.new(3.0), Gas.new(3.0)]
		for field: RefCounted in fields: _fill(field, spec)
		var times: Array = [[], []]
		var ratios: Array = []
		var same := true
		for tick in range(64):
			var answers: Array = [[], []]
			for which: int in ([0, 1] if tick % 2 == 0 else [1, 0]):
				var start := Time.get_ticks_usec()
				answers[which] = _tick(fields[which], spec, tick)
				if tick >= 8: times[which].append(float(Time.get_ticks_usec() - start) / 1000.0)
			same = same and answers[0] == answers[1] and _same_clouds(fields[0], fields[1])
			if tick >= 8: ratios.append(float(times[1].back()) / maxf(0.001, times[0].back()))
		var row := spec.duplicate()
		row.before = _stats(times[0])
		row.after = _stats(times[1])
		ratios.sort()
		row.median_ratio = ratios[ratios.size() / 2]
		row.exact_match = same
		# Require a meaningful reduction in scattered 64/128-actor stress cases;
		# allow 15% jitter/maintenance cost when all actors touch all clouds.
		row.ratio_budget = 0.7 if int(spec.clouds) >= 12 else 1.15
		if not same: failures.append("State mismatch: " + str(spec))
		if row.median_ratio > row.ratio_budget: failures.append("CPU ratio over budget: " + str(row))
		rows.append(row)
		print("GAS_PAIRED ", JSON.stringify(row))
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var file := FileAccess.open(OUT.path_join("paired.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	for failure: String in failures: printerr("GAS_PAIRED_FAIL: ", failure)
	print("GAS_PAIRED_DONE cases=%d failures=%d" % [rows.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _fill(field: RefCounted, spec: Dictionary) -> void:
	field.wind = Vector2(25, -18)
	for i in range(int(spec.clouds)):
		var point := Vector2((i % 6) * 240, (i / 6) * 240)
		if spec.dense: point = Vector2(i % 2, i / 2) * 12.0
		field.emit(str(i), ["poison", "smoke", "frost", "void"][i % 4], point, 160, 60, 0)

func _tick(field: RefCounted, spec: Dictionary, tick: int) -> Array:
	var now := (tick + 1) * DT
	field.step(DT, now)
	var answers: Array = []
	for i in range(int(spec.actors)):
		var point := Vector2((i % 16) * 110 - 100, (i / 16) * 115 - 100)
		if spec.dense: point = Vector2((i % 8) * 4 - 14, (i / 8) * 4 - 30)
		point += Vector2(sin(now + i), cos(now + i)) * 8.0
		field.part(point, 18, DT)
		answers.append(field.around(point, float(monster_profile.gas_body) + float(monster_profile.gas_pad), int(monster_profile.gas_samples)))
		if i % 16 == 0:
			field.cut(point, Vector2(1, 1), 8, DT)
			answers.append(field.touching("poison", point, 60, now))
	return answers

func _same_clouds(a: RefCounted, b: RefCounted) -> bool:
	if a.clouds().keys() != b.clouds().keys(): return false
	for key: String in a.clouds():
		for property: String in ["puffs", "at", "av", "end", "dense"]:
			if a.clouds()[key][property] != b.clouds()[key][property]: return false
	return true

func _stats(values: Array) -> Dictionary:
	values.sort()
	var total := 0.0
	for value: float in values: total += value
	return {"mean_ms": total / values.size(), "p95_ms": values[int(values.size() * 0.95)]}
