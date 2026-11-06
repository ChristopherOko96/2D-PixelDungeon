extends SceneTree
## The crypt's floors from room files (src/world_kit/room_floor.gd): every room comes from a file the
## Weltbauer can open, corridors join the gates, the key chamber is the generator's own, the boss is
## entered from below through the same dressing, nothing is cut off. Usage:
##   godot --headless --path . --script res://tests/room_floor_test.gd
const Core = preload("res://src/world_kit/world_core.gd")
const Pack = preload("res://src/world_kit/world_pack.gd")
const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const Data = preload("res://src/world_editor/world_room_data.gd")
const FloorData = preload("res://src/hell/hell_floor_data.gd")
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const C := 96.0
const RUNS := [4242, 1717, 90210, 7, 31337, 555, 2026, 987654]
const ROLES := ["start", "combat", "boss", "portal", "key", "treasure", "vault", "secret", "stairs", "jump"]

var _checked := 0
var _failed := 0
var _jump_rooms := 0


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
		printerr("ROOM_FLOOR_FAIL: ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pack := Pack.new("res://assets/data/krypta_world.json", "res://assets/sprites/krypta/manifest.json")
	_check_files()
	_check_key_room(pack)
	_check_other_worlds()
	for run: int in RUNS:
		for n in range(1, pack.floor_count() + 1):
			_check_floor(pack, n, run)
	_check(_jump_rooms >= 10, "floors have big jump puzzles: %d" % _jump_rooms)
	var a: Dictionary = pack.build_raw(3, 4242)
	var b: Dictionary = pack.build_raw(3, 4242)
	_check(str(a.grid) == str(b.grid) and str(a.ents) == str(b.ents) and str(a.props) == str(b.props), "same run, same floor")
	_check(str(pack.build_raw(3, 4243).grid) != str(a.grid), "another run, another floor")
	_check_redesign()
	await _check_in_game()
	print("ROOM_FLOOR checked=%d failed=%d" % [_checked, _failed])
	quit(1 if _failed > 0 else 0)


## A room redesigned and saved the Weltbauer's way is what floors build: new shape, new parts. A room
## of a wrong size or without the mark stays out, and the floor still comes together.
func _check_redesign() -> void:
	var base := "user://room_floor_redesign"
	for t: Dictionary in RoomFloor.library("krypta"):
		var copy: Dictionary = t.duplicate(true)
		copy.erase("_path")
		# of the wide fight rooms only the redesigned one stays
		if str(copy.role) == "combat" and str(copy.id).ends_with("_b2") and str(copy.id) != "k_wachstube_b2":
			copy.in_floors = false
		if str(copy.id) == "k_lager_b2":
			copy.in_floors = true
			copy.width = 20
		if str(copy.id) == "k_wachstube_b2":
			copy.objects.append({"kind": "prop", "asset": "gargoyle", "x": 5.5 * C, "y": 2.9 * C, "flip": false, "layer": "normal", "block": false, "scale": 1.0, "foot": [60, 30], "redesigned": true})
			Data.set_cell(copy, 6, 8, Data.WALL)
		_check(Data.save(copy, base) == "", "a room saves")
	var back := Data.load_file(Data.path_of("krypta", "k_wachstube_b2").replace(Data.DIR, base))
	_check(bool(back.get("in_floors", false)) and (back.slots as Array).size() == 2 and (back.ports as Array).size() == 6, "a saved room keeps its mark, slots and door spots")
	var pack := Pack.new("res://assets/data/krypta_world.json", "res://assets/sprites/krypta/manifest.json")
	pack.pack.room_library.folder = base
	RoomFloor.forget()
	var names: Array = RoomFloor.library("krypta", base).map(func(t: Dictionary) -> String: return str(t.id))
	_check(not names.has("k_lager_b2"), "a room of the wrong size stays out")
	var seen := false
	for n in range(1, 11):
		var W := RoomFloor.build(n, 4242, pack)
		_check(not W.is_empty(), "the floor comes together with the redesigned rooms")
		for r: Dictionary in W.rooms:
			# before the boss gate its dressing clears what stands there, by rule
			if str(r.file.id) != "k_wachstube_b2" or r.has("gate"):
				continue
			seen = true
			var o: Vector2i = r.origin
			var found := false
			for p: Dictionary in W.props:
				found = found or (str(p.name) == "gargoyle" and absf(float(p.x) - (o.x + 5.5) * C) < 1.0 and absf(float(p.y) - (o.y + 2.9) * C) < 1.0)
			_check(found, "the new part stands on the floor")
			_check(int(W.grid[(o.y + 8) * int(W.COLS) + o.x + 6]) == 0, "the new wall stands on the floor")
	_check(seen, "floors use the redesigned room")
	RoomFloor.forget()
	var dir := ProjectSettings.globalize_path(base.path_join("krypta"))
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base))


## In the real game: a fight shuts both gates of its corridors, its end opens them; a locked gate
## keeps the hero out until unlocked; the boss room is reached; each room file plays on its own.
func _check_in_game() -> void:
	var game: Node = KryptaScene.instantiate()
	game.custom_storage_root = "user://room_floor_test"
	root.add_child(game)
	for i in range(8):
		await process_frame
	game.state.world_run = 4242
	game.load_floor(3, true)
	for i in range(6):
		await process_frame
	var W: Dictionary = game.W
	_check((W.doors as Array).any(func(d: Dictionary) -> bool: return d.get("far_end", false)), "the game plays the floor with corridors")
	var fight: Dictionary = {}
	for r: Dictionary in W.rooms:
		if str(r.type) == "combat" and str(r.gtype) == "combat" and not r.get("seq", false):
			fight = r
			break
	var ours: Array = (W.doors as Array).filter(func(d: Dictionary) -> bool: return int(d.a) == int(fight.index) or int(d.b) == int(fight.index))
	var near_open: Array = ours.filter(func(d: Dictionary) -> bool: return d.kind == "open")
	_check(near_open.size() >= 2, "the fight room has open gates")
	var door: Dictionary = near_open[0]
	_check(not game._door_closed(door), "an open gate is open before the fight")
	var spot := Vector2i(fight.cells[0])
	for c: Vector2i in fight.cells:
		if int(W.grid[c.y * int(W.cols) + c.x]) == 1 and game._fully_inside(fight, (c.x + 0.5) * C, (c.y + 0.7) * C) and not game.box_blocked(game._player_box((c.x + 0.5) * C, (c.y + 0.7) * C)):
			spot = c
			break
	game.player.x = (spot.x + 0.5) * C
	game.player.y = (spot.y + 0.7) * C
	for i in range(4):
		await process_frame
	_check(bool(fight.fight), "walking in starts the fight")
	_check(not (game.mobs as Array).is_empty(), "the fight has its monsters")
	for d: Dictionary in near_open:
		_check(game._door_closed(d), "both gates of the corridor shut in the fight")
	var cell: Vector2i = door.cells[0]
	_check(game._cell_blocked(cell.x, cell.y, false), "a shut gate blocks the way")
	fight.fight = false
	fight.cleared = true
	game.mobs.clear()
	_check(not game._door_closed(door) and not game._cell_blocked(cell.x, cell.y, false), "the gates open after the fight")
	var gate: Dictionary = {}
	for d: Dictionary in W.doors:
		if d.get("boss_gate", false):
			gate = d
	_check(not gate.is_empty() and game._door_closed(gate), "the boss gate waits for its key")
	var far: Array = (W.doors as Array).filter(func(d: Dictionary) -> bool: return d.get("far_end", false) and int(d.a) == int(gate.a) and int(d.b) == int(gate.b))
	_check(not far.is_empty() and not game._door_closed(far[0]), "only the near gate holds the lock")
	gate.unlocked = true
	_check(not game._door_closed(gate), "the key opens the boss gate")
	game.enter_boss_room()
	for i in range(4):
		await process_frame
	var boss: Dictionary = W.rooms[int(gate.b)]
	_check(int(game.state.room) == int(boss.index) and str(boss.type) == "boss", "the hero reaches the boss room")
	# a wrong throw into a pit costs the fall and puts the hero back on the pad
	var jumping := -1
	for n in range(1, 11):
		game.load_floor(n, true)
		for i in range(3):
			await process_frame
		for r: Dictionary in game.W.rooms:
			if str(r.type) == "jump":
				jumping = int(r.index)
		if jumping >= 0:
			break
	_check(jumping >= 0, "a floor with a jump room")
	if jumping >= 0:
		var pad := {"type": "launch", "x": 500.0, "y": 600.0, "dir": "n", "cells": 4}
		game.state.room = jumping
		game.state.hp = 9
		game.player.x = 900.0
		game.player.y = 900.0
		game.launch_pads.last_pad = pad
		game._fall_into_pit()
		_check(is_equal_approx(float(game.player.x), 500.0) and is_equal_approx(float(game.player.y), 610.0), "the hero stands on the pad again")
		_check(int(game.state.hp) < 9, "the fall hurts")
		_check(int(game.state.room) == jumping, "and stays in the room")
	game.queue_free()
	for i in range(3):
		await process_frame
	for name: String in ["k_wachstube_b2", "k_modereck_la_gs", "k_schluesselkammer", "k_portal_tempel", "k_tresor_graben", "k_boss_arena", "k_sprung_grubensteg", "k_labyrinth_lang"]:
		var one: Node = KryptaScene.instantiate()
		var room := Data.load_file(Data.path_of("krypta", name))
		one.world_room = room
		one.custom_storage_root = "user://room_floor_test"
		root.add_child(one)
		for i in range(5):
			await process_frame
		_check(one.W != null and str(one.W.rooms[0].id) == name, name + " plays on its own, as the Weltbauer's test does")
		one.queue_free()
		for i in range(2):
			await process_frame


## Each file is a playable Weltbauer room that says nothing is missing for floors.
func _check_files() -> void:
	var files := RoomFloor.library("krypta")
	_check(files.size() >= 60, "the crypt has its room files: %d" % files.size())
	var seen := {}
	for t: Dictionary in files:
		seen[str(t.role)] = int(seen.get(str(t.role), 0)) + 1
		_check(Data.problems(t).is_empty(), "%s opens and plays: %s" % [t.id, Data.problems(t)])
		var hints := Data.floor_hints(t)
		_check(hints.is_empty(), "%s fits floors: %s" % [t.id, hints])
	for role: String in ROLES:
		_check(int(seen.get(role, 0)) >= 1, "a room file for %s" % role)
		if role not in ["key", "stairs"]:
			_check(int(seen.get(role, 0)) >= 2, "several variants of %s" % role)


## The key chamber from its file stands exactly as the generator lays it out.
func _check_key_room(pack: Pack) -> void:
	var made: Dictionary = pack.build_generated(2, 4242)
	var mine: Dictionary = pack.build_raw(2, 4242)
	var ref := _key_view(made)
	var got := _key_view(mine)
	for key: String in ["props", "ents", "wall", "decals", "lights"]:
		_check(ref[key] == got[key], "key chamber %s as generated\n  generated %s\n  from file %s" % [key, ref[key], got[key]])
	_check(ref.size == got.size and ref.cells == got.cells, "key chamber's shape as generated")
	var r := _room_of(mine, "key")
	_check(bool(r.tidy), "the key chamber stays tidy")


func _key_view(raw: Dictionary) -> Dictionary:
	var r := _room_of(raw, "key")
	var o := Vector2(int(r.bx), int(r.by)) * C
	var rel := func(p: Dictionary, name_key: String) -> String:
		return "%s@%d,%d" % [p[name_key], roundi(float(p.x) - o.x), roundi(float(p.y) - o.y)]
	var inside := func(p: Dictionary) -> bool:
		return float(p.x) >= o.x and float(p.x) < o.x + int(r.bw) * C and float(p.y) >= o.y - C and float(p.y) < o.y + int(r.bh) * C
	var props: Array = (raw.props as Array).filter(inside).map(func(p: Dictionary) -> String: return rel.call(p, "name"))
	var ents: Array = (raw.ents as Array).filter(func(e: Dictionary) -> bool: return int(e.room) == int(r.index)).map(func(e: Dictionary) -> String: return rel.call(e, "type"))
	var wall: Array = (raw.wall_decor as Array).filter(inside).map(func(w: Dictionary) -> String: return "%s@%d" % [str(w.name).left(6), roundi(float(w.x) - o.x)])
	var decals: Array = (raw.decals as Array).filter(func(d: Dictionary) -> bool: return inside.call(d) and str(d.name) in ["mat", "rug_square", "rug_red"]).map(func(d: Dictionary) -> String: return rel.call(d, "name"))
	var lights: Array = (raw.lights as Array).filter(inside).map(func(l: Dictionary) -> String: return "%d,%d,%d" % [roundi(float(l.x) - o.x), roundi(float(l.y) - o.y), roundi(float(l.r))])
	for list: Array in [props, ents, wall, decals, lights]:
		list.sort()
	var cells := 0
	for v: Variant in raw.room_at:
		if int(v) == int(r.index):
			cells += 1
	return {"props": props, "ents": ents, "wall": wall, "decals": decals, "lights": lights, "size": [r.bw, r.bh], "cells": cells}


## The hell has no room files and stays as it is (the Frostgruft builds from its own since 06.11.2026,
## tests/frost_room_floors_test.gd).
func _check_other_worlds() -> void:
	for world: String in ["hell"]:
		var p: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/%s_world.json" % world))
		_check(not p.has("room_library"), world + " still comes from the generator")


func _check_floor(pack: Pack, n: int, run: int) -> void:
	var tag := "E%d run %d" % [n, run]
	var W := RoomFloor.build(n, run, pack)
	_check(not W.is_empty(), tag + " is built from room files")
	if W.is_empty():
		return
	pack.dress_library(W)
	var names := {}
	for r: Dictionary in W.rooms:
		_check(str(r.file.get("id", "")).begins_with("k_"), "%s room %s comes from a file" % [tag, r.id])
		var t: Dictionary = r.file
		if str(t.role) == "combat" and names.has(t.id):
			pass
		names[t.id] = true
		for key: String in ["bx", "by"]:
			_check(int(r[key]) >= 1, "%s room %s on the map" % [tag, r.id])
		# a jump puzzle blocks ways on purpose; build_room_library.js proves its doors and chests in reach
		if str(r.type) == "jump":
			_jump_rooms += 1
			_check(int(r.mobs) == 0 and bool(r.cleared), "%s room %s: no fight in a jump puzzle" % [tag, r.id])
			# a labyrinth keeps its dark part (file key maze)
			if bool(t.get("maze", false)):
				_check(not (r.get("maze_zone", []) as Array).is_empty(), "%s room %s: a labyrinth knows its dark part" % [tag, r.id])
			_check(not r.has("drop") and not r.get("seq", false) and not r.has("gate"), "%s room %s holds nothing the floor needs" % [tag, r.id])
			continue
		_check(Core.blocked_ways(W, r).is_empty(), "%s room %s (%s): every door and thing reachable" % [tag, r.id, t.id])
	# a corridor between every two gates; its cells belong to no room
	var near := (W.doors as Array).filter(func(d: Dictionary) -> bool: return d.has("corridor"))
	var far := (W.doors as Array).filter(func(d: Dictionary) -> bool: return d.get("far_end", false))
	_check(near.size() == far.size() and near.size() >= int(W.rooms.size()) - 1, "%s doors come in pairs: %d %d" % [tag, near.size(), far.size()])
	for d: Dictionary in near:
		_check((d.corridor as Array).size() >= 4, "%s a corridor between the gates" % tag)
		for c: Array in d.corridor:
			var k: int = int(c[1]) * int(W.COLS) + int(c[0])
			_check(int(W.roomAt[k]) == -1 and int(W.grid[k]) == 1, "%s corridor cell %s is free ground" % [tag, c])
	_check(_all_rooms_linked(W), tag + " every room can be walked to")
	_check(int(Core.critical_rooms(W).size() if Core.critical_rooms(W) != null else -1) >= 2, tag + " there is a way to the boss")
	_check_boss_gate(W, tag)
	var raw := Core.to_raw(W)
	raw.run = run
	var ready := FloorData.prepare(raw)
	_check((ready.doors as Array).size() == (W.doors as Array).size(), tag + " prepares for the game")
	_check((raw.doorways as Array).size() >= near.size(), tag + " walls run past the gates")


## In the boss room only from below, through the locked gate, with banners, torches and carpet.
func _check_boss_gate(W: Dictionary, tag: String) -> void:
	var gates: Array = (W.doors as Array).filter(func(d: Dictionary) -> bool: return d.kind == "lock" and d.get("key", "") == "C")
	_check(gates.size() == 1, tag + " one boss gate")
	if gates.is_empty():
		return
	var d: Dictionary = gates[0]
	var boss: Dictionary = d.b
	var front: Dictionary = d.a
	_check(str(boss.type) == "boss", tag + " the gate leads to the boss")
	# the gate lies in a north wall of the room before: its floor below the gate, the boss room above
	var cols: int = W.COLS
	var below := int(W.roomAt[(int(d.y1) + 1) * cols + int(d.x0)])
	var other: Array = (W.doors as Array).filter(func(e: Dictionary) -> bool: return e.get("far_end", false) and is_same(e.a, d.a) and is_same(e.b, d.b))
	var above := int(W.roomAt[(int(other[0].y0) - 1) * cols + int(other[0].x0)]) if not other.is_empty() else -1
	_check(str(d.dir) == "v" and below == int(front.index) and above == int(boss.index) and int(other[0].y0) < int(d.y0), tag + " the boss is entered from below")
	var top := int(d.y1) + 1
	for pair: Array in [["banner", 1.85], ["torch", 3.05]]:
		for side: int in [-1, 1]:
			var x: float = float(d.cx) + float(pair[1]) * side * C
			var found := false
			for w: Dictionary in W.wallDecor:
				if absf(float(w.x) - x) < 1.0 and absf(float(w.y) - (top * C - 68.0)) < 1.0:
					found = true
			_check(found, "%s %s beside the boss gate" % [tag, pair[0]])
	var carpet := false
	for dec: Dictionary in W.decals:
		carpet = carpet or (str(dec.name) == "carpet" and absf(float(dec.x) - float(d.cx)) < 1.0)
	_check(carpet, tag + " the carpet before the boss gate")
	var clear := true
	for p: Dictionary in W.props:
		if p.has("solid") and absf(float(p.x) - float(d.cx)) < 3.0 * C and float(p.y) > top * C and float(p.y) < (top + 3) * C:
			clear = false
	_check(clear, tag + " nothing stands before the boss gate")


func _all_rooms_linked(W: Dictionary) -> bool:
	var seen := {0: true}
	var todo: Array = [0]
	while not todo.is_empty():
		var at: int = todo.pop_back()
		for d: Dictionary in W.doors:
			for pair: Array in [[d.a, d.b], [d.b, d.a]]:
				if int(pair[0].index) == at and not seen.has(int(pair[1].index)):
					seen[int(pair[1].index)] = true
					todo.append(int(pair[1].index))
	return seen.size() == W.rooms.size()


func _room_of(raw: Dictionary, gtype: String) -> Dictionary:
	for r: Dictionary in raw.rooms:
		if str(r.gtype) == gtype:
			return r
	return {}
