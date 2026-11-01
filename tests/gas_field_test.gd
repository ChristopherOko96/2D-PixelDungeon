extends SceneTree
## The gas field (src/physics_kit/gas_field.gd, GasField; BAUPLAN M1d) on a
## fake host, no game:
## - walls stop the puffs (none ever lies in a wall), a thrown cloud piles up
##   against them;
## - at / around: the thickest material and its thickness; a walker parts the
##   gas round him so it is thinner under his feet than at arm's length;
## - impulse blows it away and thins it, suck draws it in and ends an eaten
##   cloud, end_cloud and clouds_of (a used-up cloud is gone for the rules),
##   sync lets a zone that left the list thin out and go;
## - extent: the view reaches as far as the cloud;
## - the same calls give the same gas (one seeded dice per field);
## - the painter (src/vfx/gas.gd) draws its field and its old API answers from it.
## Values come from assets/data/vfx_gas.json. Deterministic; writes nothing.

const Gas = preload("res://src/vfx/gas.gd")
## World px per art pixel in the tests (the story worlds' art pixel).
const ART := 3.0
const DT := 1.0 / 60.0
## The wall: everything at x >= WALL_X world px is solid.
const WALL_X := 300.0
var checked := 0
var failures: Array[String] = []


## A fake floor: open left of WALL_X.
class FakeHost extends "res://src/physics_kit/field_host.gd":
	func is_open(point: Vector2) -> bool:
		return point.x < 300.0


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("GAS_FIELD_FAIL: ", label)


func _initialize() -> void:
	_test_walls_stop_puffs()
	_test_density_and_parting()
	_test_blow_suck_and_end()
	_test_sync_and_extent()
	_test_same_calls_same_gas()
	_test_painter_forwards()
	print("GAS_FIELD checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _run(gas: GasField, from: float, seconds: float) -> float:
	var t := from
	for i in range(int(seconds / DT)):
		t += DT
		gas.step(DT, t)
	return t


func _puffs(gas: GasField) -> Array:
	var out: Array = []
	for key: String in gas.clouds():
		out.append_array(gas.clouds()[key].puffs)
	return out


func _test_walls_stop_puffs() -> void:
	var gas := GasField.new(ART, FakeHost.new())
	# thrown at the wall: it travels as a glob, stops there and piles up
	gas.emit("breath:1", "poison", Vector2(WALL_X - 120.0, 200.0), 60.0, 6.0, 0.0, Vector2(260.0, 0.0))
	_run(gas, 0.0, 2.0)
	var inside := 0
	var near := 0
	for puff: Dictionary in _puffs(gas):
		if Vector2(puff.p).x >= WALL_X: inside += 1
		if Vector2(puff.p).x >= WALL_X - 60.0: near += 1
	check(inside == 0, "walls: no puff lies in the wall (%d did)" % inside)
	check(near > 0, "walls: the thrown cloud piled up against the wall")
	check(gas.at(Vector2(WALL_X + 20.0, 200.0)).d == 0.0, "walls: no gas behind the wall")


func _test_density_and_parting() -> void:
	var gas := GasField.new(ART, FakeHost.new())
	var at := Vector2(120.0, 200.0)
	gas.sync([{"id": 1, "k": "gas", "st": "poison", "x": at.x, "y": at.y, "r": 80.0, "p": 0.0, "L": 10.0, "d": 1.0}], 0.0, "talent")
	var t := _run(gas, 0.0, 1.0)
	var middle: Dictionary = gas.at(at)
	check(str(middle.mat) == "poison" and float(middle.d) > 0.3, "at: thick poison in its middle (%.2f)" % float(middle.d))
	check(gas.at(Vector2(120.0, 700.0)).mat == "" and float(gas.at(Vector2(120.0, 700.0)).d) == 0.0, "at: clear air far away")
	check(gas.covers(at), "covers: the cloud is there to see")
	# a walker standing in it parts it: thinner at his feet than at arm's length
	var feet := at + Vector2(10.0, 0.0)
	for i in range(60):
		t += DT
		gas.step(DT, t)
		gas.part(feet, 22.0)
	var under := float(gas.at(feet).d)
	var breathed: Dictionary = gas.around(feet, 24.0, 4)
	check(under < float(breathed.d), "part: the gas is thinner under the feet (%.2f) than round them (%.2f)" % [under, float(breathed.d)])
	check(str(breathed.mat) == "poison", "around: he breathes the poison")
	check(gas.thickness(feet + Vector2(24, 0), "poison") > 0.0 and gas.thickness(feet, "smoke") == 0.0, "thickness: by material")


func _test_blow_suck_and_end() -> void:
	var gas := GasField.new(ART, FakeHost.new())
	var at := Vector2(120.0, 200.0)
	gas.emit("a", "poison", at, 60.0, 8.0, 0.0)
	var t := _run(gas, 0.0, 1.0)
	var before := float(gas.at(at).d)
	gas.impulse(at, 60.0, 1.0)
	t = _run(gas, t, 0.3)
	check(float(gas.at(at).d) < before, "impulse: a blast blows the gas away (%.2f -> %.2f)" % [before, float(gas.at(at).d)])
	# the void eats a cloud whole: it ends and is gone for the rules
	var eaten := false
	for i in range(240):
		t += DT
		eaten = gas.suck(at, 120.0, 170.0, 1.3, DT, t) or eaten
		gas.step(DT, t)
	check(eaten, "suck: the void touched the gas")
	check(gas.clouds_of("poison", t).is_empty(), "suck: the eaten cloud is gone for the rules")
	# a reaction uses a cloud up: clouds_of no longer lists it, it thins out and goes
	gas.emit("b", "steam", at, 50.0, 8.0, t)
	t = _run(gas, t, 0.5)
	var steam: Array = gas.clouds_of("steam", t)
	check(steam.size() == 1 and str(steam[0].key) == "fx:b" and float(steam[0].r) == 50.0, "clouds_of: the steam cloud, its key and radius")
	gas.end_cloud("fx:b", t)
	check(gas.clouds_of("steam", t).is_empty(), "end_cloud: used up at once for the rules")
	t = _run(gas, t, 4.0)
	check(gas.count() == 0, "end_cloud: it thins out and goes (%d left)" % gas.count())


func _test_sync_and_extent() -> void:
	var gas := GasField.new(ART, FakeHost.new())
	var at := Vector2(120.0, 200.0)
	var zone := {"id": 3, "k": "gas", "st": "frost", "x": at.x, "y": at.y, "r": 90.0, "p": 0.0, "L": 20.0, "d": 1.0}
	gas.sync([zone], 0.0, "boss")
	var t := _run(gas, 0.0, 1.5)
	var reach := gas.extent(at, "frost", 0.12, 6.0, 400.0)
	check(reach > 30.0 and reach < 400.0, "extent: the view reaches as far as the cloud (%.0f px)" % reach)
	check(gas.extent(Vector2(120.0, 900.0), "frost", 0.12, 6.0, 400.0) == 0.0, "extent: nothing outside it")
	# another source's sync leaves it alone; its own source's empty sync ends it
	gas.sync([], t, "talent")
	check(gas.clouds_of("frost", t).size() == 1, "sync: another source leaves the cloud alone")
	gas.sync([], t, "boss")
	check(gas.clouds_of("frost", t).is_empty(), "sync: its zone left the list: it is gone for the rules")
	t = _run(gas, t, 4.0)
	check(gas.count() == 0, "sync: and thins out")
	check(not gas.has_material("lava") and gas.has_material("poison"), "materials: from vfx_gas.json")
	gas.sync([{"id": 4, "k": "gas", "st": "lava", "x": 0.0, "y": 0.0, "r": 40.0}], t, "boss")
	check(gas.count() == 0, "sync: an unknown material is no gas")


func _test_same_calls_same_gas() -> void:
	var runs: Array = []
	for n in range(2):
		var gas := GasField.new(ART, FakeHost.new())
		gas.emit("x", "smoke", Vector2(150.0, 150.0), 70.0, 5.0, 0.0, Vector2(40.0, 10.0))
		var t := _run(gas, 0.0, 0.5)
		gas.impulse(Vector2(150.0, 150.0), 0.0, 1.0)
		_run(gas, t, 0.5)
		var sig := ""
		for puff: Dictionary in _puffs(gas):
			sig += "%.4f,%.4f,%.4f;" % [Vector2(puff.p).x, Vector2(puff.p).y, float(puff.d)]
		runs.append(sig)
	check(runs[0] == runs[1] and runs[0] != "", "determinism: the same calls give the same gas")


func _test_painter_forwards() -> void:
	var painter := Gas.new(ART, func(p: Vector2) -> bool: return p.x < WALL_X)
	var at := Vector2(120.0, 200.0)
	painter.emit("y", "poison", at, 60.0, 5.0, 0.0)
	for i in range(30):
		painter.step(DT, float(i + 1) * DT)
	var field: GasField = painter.gas_field
	check(field.count() == 1 and painter.count() == 1, "painter: its cloud lives in its field")
	check(painter.at(at) == field.at(at) and painter.around(at, 24.0, 4) == field.around(at, 24.0, 4), "painter: at / around answer from the field")
	check(painter.covers(at) == field.covers(at) and painter.thickness(at, "poison") == field.thickness(at, "poison"), "painter: covers / thickness from the field")
	check(not painter.wet_at(at) and not painter.ripple_near(at, 10.0, 0.1), "painter: gas is no liquid")
	painter.clear()
	check(field.count() == 0, "painter: clear forgets the field's clouds")
