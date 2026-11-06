extends SceneTree
## Broad-phase work budget plus deterministic full-scan oracle. No scene or saves.
const Gas = preload("res://src/physics_kit/gas_field.gd")
const DT := 1.0 / 60.0
var checked := 0
var failures: Array[String] = []

class FullScan extends "res://src/physics_kit/gas_field.gd":
	func _may_touch(_cloud: Dictionary, _point: Vector2, _padding: float = 0.0) -> bool:
		return true

class Counted extends "res://src/physics_kit/gas_field.gd":
	var covered_puffs := 0
	func _cover(puffs: Array, point: Vector2) -> float:
		covered_puffs += puffs.size()
		return super._cover(puffs, point)

class Walls extends "res://src/physics_kit/field_host.gd":
	func is_open(point: Vector2) -> bool:
		return point.x < 410.0 and point.y > -260.0

func _initialize() -> void:
	_test_far_air_skips_particle_work()
	_test_mixed_operations_match_full_scan()
	_test_parting_updates_bounds_between_actors()
	_test_diagonal_cut_and_boundary_contacts()
	print("GAS_QUERIES checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures.append(label)
		printerr("GAS_QUERIES_FAIL: ", label)

func _test_far_air_skips_particle_work() -> void:
	var gas := Counted.new(3.0)
	for i in range(12):
		gas.emit(str(i), "poison", Vector2(i * 180, 100), 100.0, 30.0, 0.0)
	var clear_air := true
	for i in range(128):
		var sample: Dictionary = gas.around(Vector2(i * 17, -1000), 24, 8)
		clear_air = clear_air and sample == {"mat": "", "d": 0.0}
	check(clear_air, "128 distant actors breathe clear air")
	check(gas.covered_puffs == 0, "distant actors never enter puff coverage loops (visited %d)" % gas.covered_puffs)
	gas.around(Vector2(0, 100), 24, 8)
	check(gas.covered_puffs > 0 and gas.covered_puffs <= 8 * 9,
		"nearby actor samples its cloud, skips the eleven distant clouds")

func _fill(gas: RefCounted) -> void:
	gas.wind = Vector2(90, -35)
	for i in range(12):
		var point := Vector2((i % 4) * 180 - 250, (i / 4) * 230 - 140)
		gas.emit(str(i), ["poison", "smoke", "steam", "void", "frost"][i % 5], point,
			70.0 + i * 8, 2.0 + i * 0.15, 0.0, Vector2(80, -15))

func _same_clouds(a: RefCounted, b: RefCounted) -> bool:
	if a.clouds().keys() != b.clouds().keys():
		return false
	for key: String in a.clouds():
		var left: Dictionary = a.clouds()[key]
		var right: Dictionary = b.clouds()[key]
		for field: String in ["puffs", "at", "av", "end", "dense", "mat", "r"]:
			if left[field] != right[field]: return false
	return true

func _test_mixed_operations_match_full_scan() -> void:
	var gas := Gas.new(3.0, Walls.new())
	var oracle := FullScan.new(3.0, Walls.new())
	_fill(gas)
	_fill(oracle)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33981
	for tick in range(210):
		var now := (tick + 1) * DT
		var point := Vector2(rng.randf_range(-400, 500), rng.randf_range(-200, 650))
		var direction := Vector2.from_angle(rng.randf() * TAU)
		for field: RefCounted in [gas, oracle]:
			field.step(DT, now)
			field.part(point, 22, DT)
			field.part(point + Vector2(12, -8), 36, DT)
			field.cut(point, direction, 8, DT)
			if tick % 12 == 0: field.impulse(point, 120, 0.8)
			field.suck(point + Vector2(50, 20), 75, 40, 0.9, DT, now)
			if tick == 25: field.ignite("fx:0", point, now, 210)
			if tick == 40: field.end_cloud("fx:3", now)
			if tick == 60: field.emit("later", "poison", point, 210, 1.0, now)
		check(_same_clouds(gas, oracle), "tick %d: positions, velocities, growth, fading, wall response match" % tick)
		check(gas.take_burnt() == oracle.take_burnt(), "tick %d: flame front matches" % tick)
		check(gas.at(point) == oracle.at(point) and gas.around(point, 28, 8) == oracle.around(point, 28, 8),
			"tick %d: material/density/ring samples match" % tick)
		check(gas.thickness(point, "poison") == oracle.thickness(point, "poison") and gas.covers(point) == oracle.covers(point),
			"tick %d: coverage matches" % tick)
		check(gas.touching("poison", point, 100, now) == oracle.touching("poison", point, 100, now),
			"tick %d: reaction candidates match" % tick)
		if tick % 30 == 0:
			check(gas.extent(point, "poison", 0.1, 8, 200) == oracle.extent(point, "poison", 0.1, 8, 200), "view distance matches")
	for field: RefCounted in [gas, oracle]:
		field.clear()
		field.emit("new-room", "frost", Vector2(-900, -600), 100, 20, 0)
	check(_same_clouds(gas, oracle) and gas.around(Vector2(-900, -600), 22) == oracle.around(Vector2(-900, -600), 22), "room reset and immediate spawn queries")

func _test_parting_updates_bounds_between_actors() -> void:
	var gas := Gas.new(3.0)
	var oracle := FullScan.new(3.0)
	for field: RefCounted in [gas, oracle]:
		field.emit("walk", "poison", Vector2.ZERO, 40, 30, 0)
	# More than a cloud width between steps: later actors must see earlier displacement.
	for i in range(180):
		var puff: Dictionary = oracle.clouds()["fx:walk"].puffs[0]
		var point: Vector2 = Vector2(puff.p) - Vector2(1, 0)
		gas.part(point, 22, DT)
		oracle.part(point, 22, DT)
		check(_same_clouds(gas, oracle), "sequential actor %d sees moved gas" % i)
	check(gas.at(oracle.clouds()["fx:walk"].puffs[0].p) == oracle.at(oracle.clouds()["fx:walk"].puffs[0].p), "density query after long displacement without step")

func _test_diagonal_cut_and_boundary_contacts() -> void:
	for angle: float in [0.0, PI * 0.25, PI * 0.5, PI * 0.75]:
		var gas := Gas.new(2.0)
		var oracle := FullScan.new(2.0)
		for field: RefCounted in [gas, oracle]:
			field.emit("edge", "poison", Vector2(-100, -100), 100, 30, 0)
		var puff: Dictionary = oracle.clouds()["fx:edge"].puffs[0]
		var along := Vector2.from_angle(angle)
		var point: Vector2 = Vector2(puff.p) + along * (float(puff.r) + 8.0) * 0.999 + along.orthogonal() * (float(puff.r) * 0.7 + 8.0) * 0.999
		gas.cut(point, along, 8)
		oracle.cut(point, along, 8)
		check(_same_clouds(gas, oracle), "rotated shot cut reaches its rectangular corner")
		point = Vector2(puff.p) + Vector2(float(puff.r) * float(puff.g) + 15.0, 0)
		check(gas.touching("poison", point, 15) == oracle.touching("poison", point, 15), "inclusive reaction at puff boundary")
