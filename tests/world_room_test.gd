extends SceneTree
## The Weltbauer's rooms in the real story game: a room file builds a floor, Sprungplatten throw the
## hero over a wall and on from pad to pad, blocked landings give way, plates in order open a gate,
## what was put in a vase comes out, pits grow together, and rooms show in Pixel and HD alike.
## Usage:
##   godot --headless --path . --script res://tests/world_room_test.gd
const Data = preload("res://src/world_editor/world_room_data.gd")
const RoomWorld = preload("res://src/world_editor/world_room_world.gd")
const LaunchPads = preload("res://src/hell/launch_pads.gd")
const Art = preload("res://src/world_editor/world_art.gd")
const SCENES := {"krypta": "res://src/hell/krypta_dungeon.tscn", "frost": "res://src/hell/frost_dungeon.tscn", "hell": "res://src/hell/hell_dungeon.tscn"}
const C := 96.0
const DT := 1.0 / 60.0

var _failed := 0
var _checked := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
		print("WORLD_ROOM_FAIL: ", what)


func _run() -> void:
	_test_files()
	_test_arc_and_target()
	for world: String in SCENES:
		await _test_world(world)
	await _test_throw_over_wall()
	await _test_blocked_landing()
	await _test_chain()
	await _test_gate_by_plates()
	await _test_vase_loot()
	await _test_openers()
	await _test_item_loot()
	await _test_exact_chest()
	await _test_pit_cells()
	await _test_placed_enemy()
	await _test_graphics_views()
	print("WORLD_ROOM checked=%d failed=%d" % [_checked, _failed])
	print("WORLD_ROOM_TEST_PASS" if _failed == 0 else "WORLD_ROOM_TEST_FAILED %d" % _failed)
	quit(1 if _failed > 0 else 0)


func _at(x: float, y: float) -> Vector2:
	return Vector2((x + 0.5) * C, (y + 0.5) * C)


## A room of plain floor with a wall column at `wall_x` (-1: none) and the start at cell (2, 2).
func _room(world: String = "krypta", wall_x: int = -1) -> Dictionary:
	var room := Data.fresh(world, "Test", Vector2i(20, 12))
	room.objects = [{"kind": "start", "x": 2.5 * C, "y": 2.7 * C}]
	if wall_x >= 0:
		for y in range(room.height):
			Data.set_cell(room, wall_x, y, Data.WALL)
	return room


func _game(room: Dictionary) -> Node:
	var game: Node = (load(SCENES[str(room.world)]) as PackedScene).instantiate()
	game.world_room = room
	game.custom_storage_root = "user://world_room_test"
	root.add_child(game)
	await process_frame
	return game


func _done(game: Node) -> void:
	game.queue_free()
	await process_frame


## The hero's spot in world px for a room cell's middle (the floor keeps a margin of cells).
func _world(cell_x: float, cell_y: float) -> Vector2:
	return (Vector2(cell_x, cell_y) + Vector2.ONE * (0.5 + RoomWorld.MARGIN)) * C


func _steps(game: Node, seconds: float) -> void:
	for i in range(int(seconds / DT)):
		game._update_player(DT)
		game._update_hazards(DT)


func _stand(game: Node, spot: Vector2) -> void:
	game.player.x = spot.x
	game.player.y = spot.y + 10.0


func _test_files() -> void:
	var room := _room()
	var folder := "user://world_room_test/rooms"
	_check(Data.save(room, folder) == "", "a room can be saved")
	var back := Data.load_file(folder.path_join("krypta").path_join(str(room.id) + ".json"))
	_check(str(back.get("id", "")) == str(room.id) and (back.cells as Array).size() == 12, "and read again")
	_check(Data.list_rooms("krypta", folder).size() >= 1, "it is listed under its world")
	Data.remove(room, folder)
	_check(Data.problems(room).is_empty(), "a fresh room can be played")
	room.objects = []
	_check(not Data.problems(room).is_empty(), "without a start it says so")


func _test_arc_and_target() -> void:
	_check(LaunchPads.target_of(Vector2(100, 100), "e", 4, C) == Vector2(100 + 4 * C, 100), "east is to the right")
	_check(LaunchPads.target_of(Vector2(100, 500), "n", 2, C) == Vector2(100, 500 - 2 * C), "north is up")
	_check(is_zero_approx(LaunchPads.arc(0.0, 100.0)) and is_zero_approx(LaunchPads.arc(1.0, 100.0)), "the arc starts and ends on the floor")
	_check(is_equal_approx(LaunchPads.arc(0.5, 100.0), 100.0), "and peaks at its height")


## Each world plays a room with its walls, liquid, a pad and a pit.
func _test_world(world: String) -> void:
	var room := _room(world)
	Data.set_cell(room, 8, 5, Data.LIQUID)
	Data.set_cell(room, 9, 5, Data.LIQUID)
	Data.set_cell(room, 12, 5, Data.PIT)
	room.objects.append({"kind": "launch", "x": 5.5 * C, "y": 5.5 * C, "dir": "e", "cells": 3})
	var game: Node = await _game(room)
	_check(game.W != null and (game.W.rooms as Array).size() == 1, "%s: the room is the floor" % world)
	_check(not game.walls.north.is_empty(), "%s: walls grew round it" % world)
	_check(int(game.W.grid[int(5 + RoomWorld.MARGIN) * int(game.W.cols) + 8 + RoomWorld.MARGIN]) == 2, "%s: liquid is liquid" % world)
	await process_frame
	await _done(game)


func _test_throw_over_wall() -> void:
	var room := _room("krypta", 6)
	room.objects.append({"kind": "launch", "x": 4.5 * C, "y": 5.5 * C, "dir": "e", "cells": 4})
	var game: Node = await _game(room)
	_stand(game, _world(4, 5))
	game.state.inv = 0.0
	_steps(game, 0.2)
	_check(game.launch_pads.flying(), "stepping on the pad throws him")
	var high: float = 0.0
	for i in range(120):
		high = maxf(high, float(game.launch_pads.lift()))
		_steps(game, DT)
		if not game.launch_pads.flying():
			break
	_check(high > 40.0, "he rises in an arc, %.0f px" % high)
	_check(not game.launch_pads.flying(), "he lands")
	_check(float(game.player.x) > _world(6, 5).x, "over the wall, at x %.0f" % float(game.player.x))
	_check(absf(float(game.player.x) - _world(8, 5).x) < 2.0, "exactly 4 cells on")
	await _done(game)


func _test_blocked_landing() -> void:
	var room := _room("krypta", 8)
	room.objects.append({"kind": "launch", "x": 4.5 * C, "y": 5.5 * C, "dir": "e", "cells": 4})
	var game: Node = await _game(room)
	_stand(game, _world(4, 5))
	_steps(game, 2.0)
	_check(not game.box_blocked(game._player_box(float(game.player.x), float(game.player.y))), "a pad aimed into a wall never leaves him stuck")
	_check(float(game.player.x) < _world(8, 5).x, "he comes down before the wall")
	await _done(game)


func _test_chain() -> void:
	var room := _room()
	room.objects.append({"kind": "launch", "x": 3.5 * C, "y": 5.5 * C, "dir": "e", "cells": 4})
	room.objects.append({"kind": "launch", "x": 7.5 * C, "y": 5.5 * C, "dir": "s", "cells": 3})
	var game: Node = await _game(room)
	_stand(game, _world(3, 5))
	_steps(game, 3.0)
	_check(absf(float(game.player.x) - _world(7, 8).x) < 2.0 and absf(float(game.player.y) - (_world(7, 8).y + 10.0)) < 2.0, "the second pad throws on, at %s" % Vector2(game.player.x, game.player.y))
	await _done(game)


func _test_gate_by_plates() -> void:
	var room := _room()
	room.objects.append({"kind": "plate", "x": 3.5 * C, "y": 3.5 * C, "group": "A", "order": 2})
	room.objects.append({"kind": "plate", "x": 5.5 * C, "y": 3.5 * C, "group": "A", "order": 1})
	room.objects.append({"kind": "gate", "x": 9.0 * C, "y": 4.0 * C, "dir": "h", "group": "A"})
	var game: Node = await _game(room)
	var gate: Dictionary = game.W.doors[0]
	_check(game._door_closed(gate), "the gate starts closed")
	_stand(game, _world(3, 3))
	_steps(game, 0.1)
	_check(game._door_closed(gate), "a wrong plate does not open it")
	_stand(game, _world(10, 8))
	_steps(game, 1.0)
	_stand(game, _world(5, 3))
	_steps(game, 0.1)
	_stand(game, _world(3, 3))
	_steps(game, 0.1)
	_check(not game._door_closed(gate), "the plates in order open it")
	await _done(game)


func _test_vase_loot() -> void:
	var room := _room()
	room.objects.append({"kind": "prop", "asset": "urn_a", "x": 6.5 * C, "y": 6.5 * C, "layer": "normal", "loot": {"type": "key", "id": "B"}})
	var game: Node = await _game(room)
	var p: Dictionary = game.W.props[0]
	game.wreck._hit_prop(p, Vector2.RIGHT, 5.0, Vector2(float(p.x), float(p.y)))
	var keys: Array = (game.W.ents as Array).filter(func(e: Dictionary) -> bool: return e.type == "key")
	_check(keys.size() == 1 and str(keys[0].key) == "B", "the vase holds the key that was put in it")
	await _done(game)


## Every other way to open: a lever and a skull heap open secret walls, a smashed prop a gate.
func _test_openers() -> void:
	var room := _room()
	room.objects.append({"kind": "lever", "x": 5.5 * C, "y": 5.5 * C, "group": "A"})
	room.objects.append({"kind": "secret", "x": 12.0 * C, "y": 1.0 * C, "dir": "v", "group": "A"})
	room.objects.append({"kind": "skullheap", "x": 5.5 * C, "y": 8.5 * C, "group": "B", "hp": 2})
	room.objects.append({"kind": "secret", "x": 14.0 * C, "y": 1.0 * C, "dir": "v", "group": "B"})
	room.objects.append({"kind": "prop", "asset": "urn_a", "x": 9.5 * C, "y": 9.5 * C, "layer": "normal", "opens": "C"})
	room.objects.append({"kind": "gate", "x": 16.0 * C, "y": 4.0 * C, "dir": "h", "group": "C"})
	var game: Node = await _game(room)
	var by_group := {}
	for d: Dictionary in game.W.doors:
		by_group[str(d.group)] = d
	for g: String in ["A", "B", "C"]:
		_check(game._door_closed(by_group[g]), "group %s starts closed" % g)
	var lever: Dictionary = (game.W.ents as Array).filter(func(e: Dictionary) -> bool: return e.type == "lever")[0]
	game.player.x = float(lever.x)
	game.player.y = float(lever.y) + 20.0
	game.act()
	_check(bool(lever.lit), "the hero uses the lever")
	_check(not game._door_closed(by_group["A"]), "the lever opens its secret wall")
	var cell: Vector2i = by_group["A"].cells[0]
	_check(int(game.W.grid[cell.y * int(game.W.cols) + cell.x]) == 1, "the wall is floor now")
	var heap: Dictionary = (game.W.ents as Array).filter(func(e: Dictionary) -> bool: return e.type == "skullheap")[0]
	game._hit_breakable(heap, Vector2(heap.x, heap.y))
	_check(game._door_closed(by_group["B"]), "the heap holds after one blow")
	game._hit_breakable(heap, Vector2(heap.x, heap.y))
	_check(not game._door_closed(by_group["B"]), "the fallen heap opens its secret wall")
	var urn: Dictionary = game.W.props[0]
	game.wreck._hit_prop(urn, Vector2.RIGHT, 5.0, Vector2(float(urn.x), float(urn.y)))
	_check(not game._door_closed(by_group["C"]), "the smashed urn opens its gate")
	await _done(game)


## A real potion and a real weapon out of a chest and a vase reach the hero.
func _test_item_loot() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/items.json"))
	var weapon_id := str((data.weapons as Array)[0].id) if data.weapons is Array else str((data.weapons as Dictionary).keys()[0])
	var potion_id := str((data.potions as Array)[0].id) if data.potions is Array else str((data.potions as Dictionary).keys()[0])
	var room := _room()
	room.objects.append({"kind": "chest", "x": 6.5 * C, "y": 6.5 * C, "loot": {"type": "potion", "id": potion_id, "amount": 2}})
	room.objects.append({"kind": "prop", "asset": "urn_a", "x": 9.5 * C, "y": 9.5 * C, "layer": "normal", "loot": {"type": "weapon", "id": weapon_id}})
	var game: Node = await _game(room)
	var hero: Dictionary = game.story_items.players[1]
	var before: int = (hero.inventory.bag as Array).size()
	var chest: Dictionary = (game.W.ents as Array).filter(func(e: Dictionary) -> bool: return e.type == "chest")[0]
	game.player.x = float(chest.x)
	game.player.y = float(chest.y) + 40.0
	game.act()
	_check((hero.inventory.bag as Array).size() == before + 1, "the chest's potion is in the bag")
	_check(str(hero.inventory.bag[before].get("potion", hero.inventory.bag[before].get("id", ""))) != "", "and it is the set one")
	var urn: Dictionary = game.W.props[0]
	game.wreck._hit_prop(urn, Vector2.RIGHT, 5.0, Vector2(float(urn.x), float(urn.y)))
	_check((hero.inventory.bag as Array).size() == before + 2, "the vase's weapon too")
	await _done(game)


func _test_exact_chest() -> void:
	var room := _room()
	room.objects.append({"kind": "chest", "x": 6.5 * C, "y": 6.5 * C, "loot": {"type": "gold", "amount": 9}})
	var game: Node = await _game(room)
	var chest: Dictionary = (game.W.ents as Array).filter(func(e: Dictionary) -> bool: return e.type == "chest")[0]
	_check(bool(chest.exact) and int(chest.loot.gems) == 9, "a placed chest pays what was set")
	await _done(game)


func _test_pit_cells() -> void:
	var room := _room()
	for x in range(8, 11):
		Data.set_cell(room, x, 5, Data.PIT)
	var game: Node = await _game(room)
	_check((game.W.pit_cells as Dictionary).size() == 3, "pit cells stay one shape")
	_check((game.pits as Array).size() == 3, "and each one is a fall")
	var hp := int(game.state.hp)
	game.player.x = _world(9, 5).x
	game.player.y = _world(9, 5).y + 8.0
	game._update_player(DT)
	_check(int(game.state.hp) < hp, "walking in hurts")
	await _done(game)


func _test_placed_enemy() -> void:
	var room := _room()
	room.objects.append({"kind": "enemy", "x": 10.5 * C, "y": 6.5 * C, "mob": "skelett"})
	var game: Node = await _game(room)
	_check((game.mobs as Array).size() == 1 and str(game.mobs[0].id) == "skelett", "the placed monster stands there")
	_check(bool(game.W.rooms[0].fight), "and the fight is on")
	await _done(game)


## Pictures of only one set still show in both views; the Pixel view cuts them to its grid.
func _test_graphics_views() -> void:
	for world: String in Data.WORLDS:
		var theme: Dictionary = Art.load_theme(world)
		var skins: Dictionary = theme.get("skins", {})
		_check(skins.has("pixel") and skins.has("hd"), "%s has both sets" % world)
		var hd_only := _only_in(str(skins.hd.sprites), str(skins.pixel.sprites))
		var as_pixel := theme.duplicate()
		as_pixel.sprites = skins.pixel.sprites
		var as_hd := theme.duplicate()
		as_hd.sprites = skins.hd.sprites
		_check(RoomWorld.pixel_mode(as_pixel) and not RoomWorld.pixel_mode(as_hd), "%s: the view is known" % world)
		_check(RoomWorld.resolve("floor_00", as_pixel) != null and RoomWorld.resolve("floor_00", as_hd) != null, "%s: both sets show the floor" % world)
		if hd_only != "":
			var t: Texture2D = RoomWorld.resolve(hd_only, as_pixel)
			var source: Texture2D = load(str(skins.hd.sprites) + hd_only + ".png")
			_check(t != null and t.get_size() == source.get_size(), "%s: %s shows in Pixel at its size" % [world, hd_only])


func _only_in(a: String, b: String) -> String:
	for name: String in DirAccess.get_files_at(a):
		if name.ends_with(".png") and not FileAccess.file_exists(b + name):
			return name.trim_suffix(".png")
	return ""
