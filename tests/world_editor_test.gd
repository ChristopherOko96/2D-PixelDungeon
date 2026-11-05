extends SceneTree
## The Weltbauer's editor itself, driven by mouse events: painting, placing, deleting, undo, picking
## a part, the Pixel/HD switch, templates, and that every picture of the project is in its lists.
## Usage:
##   godot --headless --path . --script res://tests/world_editor_test.gd
const Data = preload("res://src/world_editor/world_room_data.gd")
const Catalog = preload("res://src/world_editor/world_asset_catalog.gd")
const Art = preload("res://src/world_editor/world_art.gd")
const Canvas = preload("res://src/world_editor/world_room_canvas.gd")
const Templates = preload("res://src/world_editor/world_room_templates.gd")
const RoomWorld = preload("res://src/world_editor/world_room_world.gd")
const FloorData = preload("res://src/hell/hell_floor_data.gd")
const C := 96.0

var _failed := 0
var _checked := 0
var _canvas: Control


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
		print("WORLD_EDITOR_FAIL: ", what)


func _run() -> void:
	_test_catalog_has_everything()
	await _test_painting()
	await _test_pieces()
	_test_templates()
	_test_groups_and_hints()
	print("WORLD_EDITOR checked=%d failed=%d" % [_checked, _failed])
	print("WORLD_EDITOR_TEST_PASS" if _failed == 0 else "WORLD_EDITOR_TEST_FAILED %d" % _failed)
	quit(1 if _failed > 0 else 0)


## Every imported picture under assets/ is reachable from a tab, in one of its parts.
func _test_catalog_has_everything() -> void:
	var catalog := Catalog.new()
	_check(catalog.file_count() > 3000, "the catalog finds the project's pictures, %d" % catalog.file_count())
	var shown := {}
	var by_world := {}
	for tab: String in ["krypta", "frost", "hell", Catalog.OTHER]:
		var world: String = tab if tab != Catalog.OTHER else "krypta"
		var theme: Dictionary = Art.load_theme(world)
		var list: Array = catalog.entries(tab, theme)
		by_world[tab] = list.size()
		_check(not list.is_empty(), "tab %s has parts" % tab)
		var skin := Catalog.skin_folders(theme)
		for e: Dictionary in list:
			for n: Variant in e.get("frames", [e.asset]):
				var name := str(n)
				if name.begins_with("@"):
					shown[name.substr(1)] = true
				else:
					shown[str(skin.hd) + name + ".png"] = true
					shown[str(skin.pixel) + name + ".png"] = true
	var missing := 0
	for path: String in catalog._files:
		if not shown.has(path):
			missing += 1
			if missing <= 5:
				print("WORLD_EDITOR_MISSING: ", path)
	_check(missing == 0, "%d pictures are in no list" % missing)
	print("WORLD_EDITOR_COUNTS ", by_world, " files ", catalog.file_count())
	for world: String in ["krypta", "frost", "hell"]:
		var c := Catalog.coverage(Art.load_theme(world))
		print("WORLD_EDITOR_COVERAGE ", world, " both ", c.both, " hd_only ", (c.hd_only as Array).size(), " pixel_only ", (c.pixel_only as Array).size())
		_check(int(c.both) > 0, "%s has pictures in both views" % world)


func _new_canvas(world: String) -> Control:
	var art := Art.new(world, "pixel")
	var canvas: Control = Canvas.new()
	canvas.catalog = Catalog.new()
	canvas.size = Vector2(1000, 700)
	root.add_child(canvas)
	canvas.show_room(Data.fresh(world, "Test", Vector2i(16, 12)), art)
	await process_frame
	return canvas


func _mouse(canvas: Control, cell: Vector2, button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = canvas._world.position + cell * C * canvas._world.scale.x
	canvas._gui_input(e)


func _click(canvas: Control, cell: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	_mouse(canvas, cell, button, true)
	_mouse(canvas, cell, button, false)


func _test_painting() -> void:
	var canvas := await _new_canvas("krypta")
	var room: Dictionary = canvas.room
	canvas.tool = "liquid"
	_click(canvas, Vector2(5.5, 5.5))
	_check(Data.cell_at(room, 5, 5) == Data.LIQUID, "a click paints liquid")
	_click(canvas, Vector2(5.5, 5.5), MOUSE_BUTTON_RIGHT)
	_check(Data.cell_at(room, 5, 5) == Data.FLOOR, "the right button takes it back")
	canvas.undo()
	_check(Data.cell_at(room, 5, 5) == Data.LIQUID, "undo brings it back")
	canvas.redo()
	_check(Data.cell_at(room, 5, 5) == Data.FLOOR, "redo again")
	var north_before: int = (canvas._walls.north as Array).size()
	canvas.tool = "wall"
	_click(canvas, Vector2(8.5, 6.5))
	_check(Data.cell_at(room, 8, 6) == Data.WALL, "a wall can be set")
	_check((canvas._walls.north as Array).size() > north_before, "the walls grow round it by themselves")
	canvas.tool = "pit"
	canvas.brush_size = 2
	_click(canvas, Vector2(11.5, 4.5))
	var pits := 0
	for y in range(12):
		pits += str(room.cells[y]).count(Data.PIT)
	_check(pits == 4, "a 2-brush paints four pit cells, %d" % pits)
	canvas.brush_size = 1
	canvas.tool = "area"
	canvas.brush = {"asset": "floor_03"}
	_click(canvas, Vector2(3.5, 3.5))
	_check(str(room.areas.get("3,3", "")) == "floor_03", "an area cell is painted")
	canvas.queue_free()
	await process_frame


func _test_pieces() -> void:
	var canvas := await _new_canvas("krypta")
	var room: Dictionary = canvas.room
	var start_count: int = (room.objects as Array).size()
	canvas.tool = "place"
	canvas.brush = {"kind": "launch", "defaults": {"dir": "e", "cells": 5}}
	_click(canvas, Vector2(3.2, 3.2))
	var pad: Dictionary = canvas.picked
	_check(str(pad.kind) == "launch" and int(pad.cells) == 5, "a pad is placed with its defaults")
	_check(is_equal_approx(float(pad.x), 3.5 * C) and is_equal_approx(float(pad.y), 3.5 * C), "on the middle of its cell")
	canvas.brush = {"kind": "prop", "asset": "barrel_a", "label": "barrel_a"}
	_click(canvas, Vector2(7.5, 7.5))
	var barrel: Dictionary = canvas.picked
	_check(bool(barrel.block), "a barrel blocks by default")
	_check(str(barrel.layer) == "normal", "and stands in the normal layer")
	canvas.tool = "select"
	_click(canvas, Vector2(7.5, 7.4))
	_check(is_same(canvas.picked, barrel), "a click selects it")
	_click(canvas, Vector2(7.5, 7.4), MOUSE_BUTTON_RIGHT)
	_check((room.objects as Array).size() == start_count + 1, "the right button removes it")
	canvas.undo()
	_check((canvas.room.objects as Array).size() == start_count + 2, "undo restores it")
	canvas.queue_free()
	await process_frame


## Templates become rooms that still build a floor.
func _test_templates() -> void:
	for world: String in Data.WORLDS:
		var room := Templates.make(world, "key", "Schlüsselkammer")
		_check(not room.is_empty(), "%s has a key chamber to load" % world)
		if room.is_empty():
			continue
		_check(Data.problems(room).is_empty(), "%s's key chamber can be played: %s" % [world, str(Data.problems(room))])
		_check((room.objects as Array).size() > 2, "%s's key chamber is furnished" % world)
		var raw: Dictionary = RoomWorld.new(room).build_raw(1, 77)
		_check(not raw.is_empty(), "%s's key chamber builds a floor" % world)
		_check(FloorData.prepare(raw).rooms.size() == 1, "%s: one room" % world)


func _test_groups_and_hints() -> void:
	var room := Data.fresh("krypta", "Test", Vector2i(12, 10))
	room.objects.append({"kind": "launch", "x": 2.5 * C, "y": 2.5 * C, "dir": "n", "cells": 5})
	room.objects.append({"kind": "lever", "x": 5.5 * C, "y": 5.5 * C, "group": "C"})
	var hints := Data.hints(room)
	_check(hints.size() == 2, "a pad into the wall and a lever without a gate are named, %s" % str(hints))
	room.objects.append({"kind": "secret", "x": 6.0 * C, "y": 1.0 * C, "dir": "v", "group": "C"})
	var raw: Dictionary = RoomWorld.new(room).build_raw(1, 77)
	_check(str(raw.groups.C.kind) == "lever", "a lever makes a lever group")
	_check(str(raw.doors[0].kind) == "secret", "a secret passage stays wall until opened")
	var cols := int(raw.cols)
	var c: Array = raw.doors[0].cells[0]
	_check(str(raw.grid)[int(c[1]) * cols + int(c[0])] == "0", "its cells start as wall")
