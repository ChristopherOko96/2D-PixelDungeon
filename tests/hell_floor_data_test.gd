extends SceneTree
## Baked hell floors (assets/data/hell_floors.json): ten floors load, every floor
## has one start, boss and portal room, doors join valid rooms, the quickest way
## to the boss never needs every room, every lock's key exists on its floor, a
## vault always has at least two fire braziers, and deeper floors get harder.

const FloorData = preload("res://src/hell/hell_floor_data.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_FLOOR_DATA_FAIL: ", description)


func _count(rooms: Array, kind: String) -> int:
	var n := 0
	for r: Dictionary in rooms:
		if r.type == kind:
			n += 1
	return n


func _initialize() -> void:
	var raw := FloorData.load_all()
	check(raw.size() == 10, "ten floors are baked")
	var last_hp := 0.0
	for f: Dictionary in raw:
		var W := FloorData.prepare(f)
		var n: int = W.n
		check(_count(W.rooms, "start") == 1 and _count(W.rooms, "boss") == 1 and _count(W.rooms, "portal") == 1, "floor %d has one start, boss and portal room" % n)
		check(W.grid.size() == W.cols * W.rows and W.room_at.size() == W.grid.size(), "floor %d cell arrays match its size" % n)
		var doors_ok := true
		for d: Dictionary in W.doors:
			if d.a < 0 or d.a >= W.rooms.size() or d.b < 0 or d.b >= W.rooms.size() or d.cells.size() != 4:
				doors_ok = false
		check(doors_ok, "floor %d doors join valid rooms through a 2x2 passage" % n)
		check(W.quick > 0 and W.quick < W.rooms.size(), "floor %d: the quickest way (%d rooms) skips some of the %d rooms" % [n, W.quick, W.rooms.size()])
		var keys := {}
		for r: Dictionary in W.rooms:
			if r.drop != "":
				keys[r.drop] = true
		for e: Dictionary in W.ents:
			if e.type == "key":
				keys[e.key] = true
		var locks_ok := true
		for d: Dictionary in W.doors:
			if d.kind == "lock" and not keys.has(d.key):
				locks_ok = false
		check(locks_ok, "floor %d: every locked gate's key exists" % n)
		var has_vault := false
		var fire := 0
		for e: Dictionary in W.ents:
			if e.type == "vault":
				has_vault = true
			if e.type == "brazier" and e.get("group", "") == "feuer":
				fire += 1
		check(not has_vault or fire >= 2, "floor %d: a vault comes with at least two spread fire braziers" % n)
		var cell_ok := true
		for r: Dictionary in W.rooms:
			if r.cells.is_empty():
				cell_ok = false
		check(cell_ok, "floor %d: every room owns floor cells" % n)
		check(float(W.diff.hp) >= last_hp, "floor %d: enemies are at least as tough as one floor above" % n)
		last_hp = float(W.diff.hp)
	print("HELL_FLOOR_DATA checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
