extends SceneTree
## Baked hell floors (assets/data/hell_floors.json): ten floors load, every floor
## has one start, boss and portal room, doors join valid rooms, the quickest way
## to the boss never needs every room, every lock's key exists on its floor, a
## vault always has at least two fire braziers, deeper floors get harder, demon
## seals appear from floor 4 (four from floor 7) in combat rooms, every secret
## wall has its skull heap and no secret is hidden or grouped, and pits are
## walkable traps rather than solid props.

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
		var seals := 0
		var seal_rooms := {}
		var heaps := {}
		var pits_ok := true
		for e: Dictionary in W.ents:
			if e.type == "seal":
				seals += 1
				seal_rooms[e.room] = W.rooms[e.room].type
				check(int(e.get("hp", 0)) > 0, "floor %d: a seal has hit points" % n)
			elif e.type == "skullheap":
				heaps[int(e.door)] = int(e.hp)
			elif e.type == "pit":
				for p: Dictionary in W.props:
					if p.name == "pit" and p.solid != null:
						pits_ok = false
		var want := 0 if n < 4 else (3 if n < 7 else 4)
		check(seals == want and seal_rooms.size() == want, "floor %d: %d demon seals, one per room (got %d)" % [n, want, seals])
		check(seal_rooms.values().all(func(t: String) -> bool: return t == "combat"), "floor %d: seals sit in combat rooms" % n)
		var secrets_ok := true
		for d: Dictionary in W.doors:
			if d.kind == "secret" and (heaps.get(d.index, 0) != 3 or d.hidden or d.group != ""):
				secrets_ok = false
		check(secrets_ok, "floor %d: every secret wall hides behind a three-hit skull heap" % n)
		check(pits_ok, "floor %d: pits are not solid" % n)
		check(float(W.diff.hp) >= last_hp, "floor %d: enemies are at least as tough as one floor above" % n)
		last_hp = float(W.diff.hp)
	print("HELL_FLOOR_DATA checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
