extends SceneTree
## A room's door spots decide its doors on a floor: only those exist, the floor moves its doors onto them
## where it can, and a spot marked entrance or exit is used that way unless nothing else fits. Usage:
##   godot --headless --path . --script res://tests/room_doors_test.gd
const Data = preload("res://src/world_editor/world_room_data.gd")
const Pack = preload("res://src/world_kit/world_pack.gd")
const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const EditorScene = preload("res://src/world_editor/world_editor.tscn")
const C := 96.0
const CFG := {"slot_size": [14, 11], "slot_gap": [3, 3], "jump_rooms": 0, "jump_share": 0.0}
## West end and east end of a room three slots long: (cell, side).
const WEST := {"side": "west", "cell": [0, 5]}
const EAST := {"side": "east", "cell": [47, 5]}

var _checked := 0
var _failed := 0


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
		printerr("ROOM_DOORS_FAIL: ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_few_doors_are_allowed()
	_test_direction_is_preferred()
	_test_reversed_only_when_nothing_else()
	_test_doors_move_along_the_shared_wall()
	_test_room_without_fit_stays_a_fight()
	_test_floor_reroutes_around_a_puzzle()
	_test_locked_chamber_moves_to_a_door()
	_test_floors_use_only_the_set_doors()
	await _test_editor_marks_doors()
	print("ROOM_DOORS checked=%d failed=%d" % [_checked, _failed])
	quit(1 if _failed > 0 else 0)


func _port(base: Dictionary, use: String) -> Dictionary:
	var p := base.duplicate(true)
	if use != "":
		p.use = use
	return p


func _file(id: String, role: String, slots: Array, ports: Array) -> Dictionary:
	return {"id": id, "role": role, "slots": slots, "ports": ports, "objects": [], "width": 48, "height": 11}


## Every outer side of every slot has a door spot.
func _open_file(id: String, role: String, slots: Array) -> Dictionary:
	var ports: Array = []
	for s: Array in slots:
		var x := int(s[0]) * 17
		var y := int(s[1]) * 14
		ports.append({"side": "north", "cell": [x + 6, y]})
		ports.append({"side": "south", "cell": [x + 6, y + 10]})
		ports.append({"side": "west", "cell": [x, y + 5]})
		ports.append({"side": "east", "cell": [x + 13, y + 5]})
	return _file(id, role, slots, ports)


## A start room, a long room right of or left of it, and a portal room on the long room's other end.
func _line_plan(start_on_left: bool) -> Dictionary:
	var start_at := 0 if start_on_left else 4
	var end_at := 4 if start_on_left else 0
	return {"rooms": [
		{"id": "s", "gtype": "start", "type": "start", "slots": [[start_at, 0]]},
		{"id": "m", "gtype": "combat", "type": "combat", "mobs": 4, "slots": [[1, 0], [2, 0], [3, 0]]},
		{"id": "e", "gtype": "portal", "type": "portal", "slots": [[end_at, 0]]},
	], "doors": [
		{"a": "s", "b": "m", "kind": "open", "slots": [[start_at, 0], [1 if start_on_left else 3, 0]]},
		{"a": "m", "b": "e", "kind": "open", "slots": [[3 if start_on_left else 1, 0], [end_at, 0]]},
	]}


func _ends() -> Array:
	return [_open_file("start", "start", [[0, 0]]), _open_file("portal", "portal", [[0, 0]])]


func _long() -> Array:
	return [[0, 0], [1, 0], [2, 0]]


func _test_few_doors_are_allowed() -> void:
	var r := Data.fresh("krypta", "Zwei Türen", Vector2i(48, 11))
	r.in_floors = true
	r.slots = _long()
	r.ports = [WEST.duplicate(true), EAST.duplicate(true)]
	_check(Data.floor_hints(r).is_empty(), "two door spots are enough for floors: %s" % [Data.floor_hints(r)])
	r.ports = []
	_check(not Data.floor_hints(r).is_empty(), "a room without any door spot cannot join a floor")


func _test_direction_is_preferred() -> void:
	var right := _file("right", "combat", _long(), [_port(WEST, "in"), _port(EAST, "out")])
	var wrong := _file("wrong", "combat", _long(), [_port(WEST, "out"), _port(EAST, "in")])
	for seed_value: int in range(1, 12):
		var picks := RoomFloor._pick_files(_line_plan(true), _ends() + [right, wrong], CFG, RoomFloor.Core.Rng.new(seed_value))
		_check(str(picks.get("m", {}).get("id", "")) == "right", "entered from the west: the room whose entrance is west (seed %d)" % seed_value)
		var back := RoomFloor._pick_files(_line_plan(false), _ends() + [right, wrong], CFG, RoomFloor.Core.Rng.new(seed_value))
		_check(str(back.get("m", {}).get("id", "")) == "wrong", "entered from the east: the room whose entrance is east (seed %d)" % seed_value)


func _test_reversed_only_when_nothing_else() -> void:
	var only := _file("only", "combat", _long(), [_port(WEST, "out"), _port(EAST, "in")])
	var picks := RoomFloor._pick_files(_line_plan(true), _ends() + [only], CFG, RoomFloor.Core.Rng.new(5))
	_check(str(picks.get("m", {}).get("id", "")) == "only", "with nothing else the exit may serve as entrance")


func _test_doors_move_along_the_shared_wall() -> void:
	# two long rooms one above the other; the plan's door is at the left end, the puzzle's only door at the right
	var cfg := CFG.duplicate(true)
	cfg.jump_rooms = 1
	cfg.jump_share = 1.0
	var plan := {"rooms": [
		{"id": "s", "gtype": "start", "type": "start", "slots": [[0, 0], [1, 0], [2, 0]]},
		{"id": "m", "gtype": "combat", "type": "combat", "mobs": 4, "slots": [[0, 1], [1, 1], [2, 1]]},
	], "doors": [{"a": "s", "b": "m", "kind": "open", "slots": [[0, 0], [0, 1]]}]}
	var right_end := _file("right_end", "jump", _long(), [{"side": "north", "cell": [40, 0]}])
	var start := _open_file("long_start", "start", _long())
	var picks := RoomFloor._pick_files(plan, [start, right_end], cfg, RoomFloor.Core.Rng.new(3))
	_check(str(picks.get("m", {}).get("id", "")) == "right_end", "the door moves to the puzzle's spot")
	_check(str(plan.doors[0].slots) == str([[2, 0], [2, 1]]), "and now joins the right end: %s" % str(plan.doors[0].slots))


func _test_room_without_fit_stays_a_fight() -> void:
	var cfg := CFG.duplicate(true)
	cfg.jump_rooms = 2
	cfg.jump_share = 1.0
	var plan := _line_plan(true)
	var puzzle := _file("puzzle", "jump", _long(), [{"side": "north", "cell": [6, 0]}])
	var fight := _open_file("fight", "combat", _long())
	var picks := RoomFloor._pick_files(plan, _ends() + [puzzle, fight], cfg, RoomFloor.Core.Rng.new(9))
	_check(str(picks.get("m", {}).get("id", "")) == "fight", "no puzzle fits these doors: a fight room instead")
	_check(str(plan.rooms[1].gtype) == "combat" and int(plan.rooms[1].mobs) == 4, "and it stays a fight with its enemies")
	var through := _file("through", "jump", _long(), [_port(WEST, "in"), _port(EAST, "out")])
	plan = _line_plan(true)
	picks = RoomFloor._pick_files(plan, _ends() + [through, fight], cfg, RoomFloor.Core.Rng.new(9))
	_check(str(picks.get("m", {}).get("id", "")) == "through" and str(plan.rooms[1].gtype) == "jump", "a puzzle that fits becomes the room")
	_check(int(plan.rooms[1].mobs) == 0, "without enemies")


## A plan below: the start room left, the long room above and the one below it both right of it, and
## a tall room on their right end. The plan enters the lower long room from above.
func _crossing_plan() -> Dictionary:
	return {"gc": 6, "gr": 4, "groups": {}, "rooms": [
		{"id": "s", "gtype": "start", "type": "start", "slots": [[0, 0]]},
		{"id": "w", "gtype": "combat", "type": "combat", "mobs": 2, "slots": [[0, 1]]},
		{"id": "a", "gtype": "combat", "type": "combat", "mobs": 4, "slots": [[1, 0], [2, 0], [3, 0]]},
		{"id": "m", "gtype": "combat", "type": "combat", "mobs": 4, "slots": [[1, 1], [2, 1], [3, 1]]},
		{"id": "b", "gtype": "combat", "type": "combat", "mobs": 4, "slots": [[4, 0], [4, 1]]},
	], "doors": [
		{"a": "s", "b": "a", "kind": "open", "slots": [[0, 0], [1, 0]]},
		{"a": "s", "b": "w", "kind": "open", "slots": [[0, 0], [0, 1]]},
		{"a": "a", "b": "m", "kind": "open", "slots": [[2, 0], [2, 1]]},
		{"a": "a", "b": "b", "kind": "open", "slots": [[3, 0], [4, 0]]},
	]}


func _crossing_files() -> Array:
	return [_open_file("s1", "start", [[0, 0]]), _open_file("c1", "combat", [[0, 0]]), _open_file("c3", "combat", _long()), _open_file("c2", "combat", [[0, 0], [0, 1]])]


func _links(plan: Dictionary) -> Array:
	var out: Array = (plan.doors as Array).map(func(d: Dictionary) -> String:
		var two: Array = [str(d.a), str(d.b)]
		two.sort()
		return "-".join(two))
	out.sort()
	return out


func _test_floor_reroutes_around_a_puzzle() -> void:
	var cfg := CFG.duplicate(true)
	cfg.jump_rooms = 1
	cfg.jump_share = 1.0
	var plan := _crossing_plan()
	# no door on top: only west and east, where other rooms lie too
	plan.rooms[2].drop = "A"
	var through := _file("through", "jump", _long(), [_port(WEST, "in"), _port(EAST, "out")])
	var picks := RoomFloor._pick_files(plan, _crossing_files() + [through], cfg, RoomFloor.Core.Rng.new(4))
	_check(str(picks.get("m", {}).get("id", "")) == "through", "the plan's door from above gives way to the puzzle's two doors")
	var links := _links(plan)
	_check(not links.has("a-m"), "the door from above is gone: %s" % [links])
	_check(links.has("m-w") and links.has("b-m"), "west and east are joined: %s" % [links])
	_check(RoomFloor._entry_doors(plan).has("b") and RoomFloor._entry_doors(plan).has("a"), "every room can still be reached")
	var entry: Dictionary = RoomFloor._entry_doors(plan).m
	_check(str(entry.a) == "w" or str(entry.b) == "w", "and the puzzle is entered by its entrance: %s" % str(entry))


func _test_locked_chamber_moves_to_a_door() -> void:
	var cfg := CFG.duplicate(true)
	cfg.jump_rooms = 0
	var plan := _crossing_plan()
	plan.rooms[3].seq = true
	plan.rooms.append({"id": "v", "gtype": "pvault", "type": "treasure", "slots": [[2, 2]]})
	plan.doors.append({"a": "m", "b": "v", "kind": "puzzle", "extra": "seq", "slots": [[2, 1], [2, 2]]})
	var plates: Array = []
	for i in range(6):
		plates.append({"kind": "plate", "group": "seq", "x": 96.0 * i, "y": 96.0})
	var riddle := _file("riddle", "combat", _long(), [_port(WEST, "in"), _port(EAST, "out"), {"side": "south", "cell": [6, 10]}])
	riddle.objects = plates
	var vault := _open_file("v1", "vault", [[0, 0]])
	var picks := RoomFloor._pick_files(plan, _crossing_files() + [riddle, vault], cfg, RoomFloor.Core.Rng.new(4))
	_check(str(picks.get("m", {}).get("id", "")) == "riddle", "a riddle room with its own doors fits")
	_check(str(plan.rooms[5].slots) == str([[1, 2]]), "the chamber behind it moved below its door: %s" % str(plan.rooms[5].slots))
	var spec: Dictionary = (plan.doors as Array).filter(func(d: Dictionary) -> bool: return str(d.kind) == "puzzle")[0]
	_check(str(spec.slots) == str([[1, 1], [1, 2]]), "and its gate went with it: %s" % str(spec.slots))


## On real floors with two-door puzzles: gates stand only on the set spots, floors still come together.
func _test_floors_use_only_the_set_doors() -> void:
	var base := "user://room_doors_floors"
	for t: Dictionary in RoomFloor.library("krypta"):
		var copy: Dictionary = t.duplicate(true)
		copy.erase("_path")
		if str(copy.role) == "jump" and (copy.slots as Array).size() == 3:
			var keep: Array = (copy.ports as Array).slice(0, 2)
			keep[0] = keep[0].merged({"use": "in"})
			keep[1] = keep[1].merged({"use": "out"})
			copy.ports = keep
		_check(Data.save(copy, base) == "", "a room saves")
	var pack := Pack.new("res://assets/data/krypta_world.json", "res://assets/sprites/krypta/manifest.json")
	pack.pack.room_library.folder = base
	RoomFloor.forget()
	var seen := 0
	for run: int in [11, 222, 3333, 44444, 5150, 616]:
		for n in range(1, 11):
			var W := RoomFloor.build(n, run, pack)
			_check(not W.is_empty(), "floor %d of run %d comes together" % [n, run])
			if W.is_empty():
				continue
			_check(_all_reached(W), "floor %d of run %d: every room can be reached" % [n, run])
			for r: Dictionary in W.rooms:
				if str(r.gtype) != "jump":
					continue
				seen += 1
				var spots := {}
				for p: Dictionary in r.file.ports:
					spots[Vector2i(int(p.cell[0]), int(p.cell[1])) + (r.origin as Vector2i)] = true
				for d: Dictionary in r.doors:
					if is_same(d.a, d.b):
						continue
					_check(spots.has(Vector2i(int(d.x0), int(d.y0))), "%s: every gate stands on a set spot" % r.file.id)
	_check(seen >= 3, "floors do use the two-door puzzles: %d" % seen)
	RoomFloor.forget()
	var dir := ProjectSettings.globalize_path(base.path_join("krypta"))
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base))


## True when the floor's doors lead from its start room to every room.
func _all_reached(W: Dictionary) -> bool:
	var seen := {}
	var todo: Array = (W.rooms as Array).filter(func(r: Dictionary) -> bool: return str(r.gtype) == "start")
	while not todo.is_empty():
		var here: Dictionary = todo.pop_back()
		if seen.has(here.index):
			continue
		seen[here.index] = true
		for d: Dictionary in here.doors:
			todo.append(d.b if is_same(d.a, here) else d.a)
	return seen.size() == (W.rooms as Array).size()


func _test_editor_marks_doors() -> void:
	var editor: Node = EditorScene.instantiate()
	root.add_child(editor)
	for i in range(4):
		await process_frame
	var room := Data.fresh("krypta", "Tür", Vector2i(14, 11))
	editor.rooms.append(room)
	editor._open_room(room)
	var canvas: Node = editor.canvas
	canvas.port_use = "in"
	canvas._toggle_port(Vector2i(0, 5))
	_check(str((room.ports as Array)[0].get("use", "")) == "in", "a door spot can be an entrance")
	canvas.port_use = "out"
	canvas._toggle_port(Vector2i(0, 5))
	_check((room.ports as Array).size() == 1 and str(room.ports[0].get("use", "")) == "out", "clicking it with another kind changes it")
	canvas._toggle_port(Vector2i(0, 5))
	_check((room.ports as Array).is_empty(), "clicking it with the same kind takes it away")
	canvas.port_use = ""
	canvas._toggle_port(Vector2i(0, 5))
	_check(not room.ports[0].has("use"), "either way stays without a mark")
	editor.queue_free()
	for i in range(3):
		await process_frame
