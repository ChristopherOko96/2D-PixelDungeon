extends SceneTree
## What the Weltbauer's settings of a part do, in the editor and the game: size, width and height reach
## every picture (standing, flat on the floor, on a wall), and a room's enemies come by chance or stand
## where they were set. Usage:
##   godot --headless --path . --script res://tests/world_part_settings_test.gd
const Data = preload("res://src/world_editor/world_room_data.gd")
const RoomWorld = preload("res://src/world_editor/world_room_world.gd")
const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const Core = preload("res://src/world_kit/world_core.gd")
const Pack = preload("res://src/world_kit/world_pack.gd")
const Canvas = preload("res://src/world_editor/world_room_canvas.gd")
const EditorScene = preload("res://src/world_editor/world_editor.tscn")
const C := 96.0

var _checked := 0
var _failed := 0


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
		printerr("WORLD_PART_FAIL: ", what)


func _initialize() -> void:
	_run.call_deferred()


func _room() -> Dictionary:
	var r := Data.fresh("krypta", "Test", Vector2i(16, 12))
	r.objects.append({"kind": "prop", "asset": "rug_red", "x": 3.0 * C, "y": 5.0 * C, "flip": false, "layer": "floor", "block": false, "scale": 1.0, "foot": [60, 30], "decal": {"dy": 84.0, "w": 170.0, "h": 300.0, "a": 1.0}})
	r.objects.append({"kind": "prop", "asset": "statue_angel", "x": 8.0 * C, "y": 5.0 * C, "flip": false, "layer": "normal", "block": true, "scale": 1.0, "foot": [50, 26]})
	r.objects.append({"kind": "prop", "asset": "banner_1", "x": 8.0 * C, "y": C + 6.0, "flip": false, "layer": "floor", "block": false, "scale": 1.0, "foot": [60, 30], "wall_decor": true})
	return r


func _run() -> void:
	_test_sizes_in_editor()
	_test_sizes_in_game_data()
	_test_spawn_mode_alone()
	_test_spawn_mode_on_floors()
	await _test_editor_controls()
	await _test_sizes_on_screen()
	await _test_zoom_stays()
	print("WORLD_PART checked=%d failed=%d" % [_checked, _failed])
	quit(1 if _failed > 0 else 0)


func _test_sizes_in_editor() -> void:
	var editor: Node = EditorScene.instantiate()
	root.add_child(editor)
	var canvas: Node = editor.canvas
	var room := _room()
	editor.rooms.append(room)
	editor._open_room(room)
	var rug: Dictionary = room.objects[1]
	var statue: Dictionary = room.objects[2]
	var base_rug: Vector2 = canvas.box_of(rug).size
	var base_statue: Vector2 = canvas.box_of(statue).size
	rug.scale = 2.0
	_check(canvas.box_of(rug).size.is_equal_approx(base_rug * 2.0), "Größe grows a carpet in the editor")
	rug.scale = 1.0
	rug.scale_w = 2.0
	rug.scale_h = 0.5
	_check(canvas.box_of(rug).size.is_equal_approx(base_rug * Vector2(2.0, 0.5)), "Breite and Höhe shape a carpet alone")
	statue.scale = 1.5
	statue.scale_h = 2.0
	_check(canvas.box_of(statue).size.is_equal_approx(base_statue * Vector2(1.5, 3.0)), "Größe and Höhe work together on a standing part")
	editor.queue_free()


func _test_sizes_in_game_data() -> void:
	var room := _room()
	room.objects[1].scale = 2.0
	room.objects[1].scale_w = 1.5
	room.objects[2].scale = 2.0
	room.objects[2].scale_h = 1.5
	room.objects[3].scale_w = 2.0
	var raw := RoomWorld.new(room).build_raw(1, 7)
	var rug: Dictionary = (raw.decals as Array).filter(func(d: Dictionary) -> bool: return str(d.name) == "rug_red")[0]
	_check(is_equal_approx(float(rug.sx), 3.0) and is_equal_approx(float(rug.sy), 2.0), "a carpet's size reaches the game: %s" % rug)
	var statue: Dictionary = (raw.props as Array).filter(func(p: Dictionary) -> bool: return str(p.name) == "statue_angel")[0]
	_check(is_equal_approx(float(statue.sx), 2.0) and is_equal_approx(float(statue.sy), 3.0), "a standing part's size reaches the game: %s" % statue)
	var banner: Dictionary = (raw.wall_decor as Array)[0]
	_check(is_equal_approx(float(banner.sx), 2.0), "a wall picture's size reaches the game: %s" % banner)


## Tried alone: by chance only the count counts, by hand only the placed ones.
func _test_spawn_mode_alone() -> void:
	var room := _room()
	room.objects.append({"kind": "enemy", "mob": "skelett", "x": 5.0 * C, "y": 5.0 * C})
	room.auto_mobs = 4
	room.spawn_mode = "random"
	var raw := RoomWorld.new(room).build_raw(1, 7)
	_check((raw.rooms[0].placed_mobs as Array).is_empty() and int(raw.rooms[0].mobs) == 4, "by chance: the count, no placed enemy")
	room.spawn_mode = "manual"
	raw = RoomWorld.new(room).build_raw(1, 7)
	_check((raw.rooms[0].placed_mobs as Array).size() == 1 and int(raw.rooms[0].mobs) == 0, "by hand: the placed enemy, no count")
	_check(str(raw.rooms[0].placed_mobs[0].mob) == "skelett", "by hand: the chosen enemy")
	room.erase("spawn_mode")
	_check(Data.spawn_mode(room) == "manual", "an old room with enemies stays by hand")
	room.objects = (room.objects as Array).filter(func(o: Dictionary) -> bool: return str(o.kind) != "enemy")
	_check(Data.spawn_mode(room) == "random", "an old room without enemies stays by chance")


## On a real floor: a fight room of each kind of choice, its stand-ins for all wide fight rooms.
func _test_spawn_mode_on_floors() -> void:
	var base := "user://world_part_rooms"
	var results := {}
	for mode: String in ["manual", "random", "empty"]:
		for t: Dictionary in RoomFloor.library("krypta"):
			var copy: Dictionary = t.duplicate(true)
			copy.erase("_path")
			if str(copy.role) == "combat":
				copy.objects = (copy.objects as Array).filter(func(o: Dictionary) -> bool: return str(o.kind) != "enemy")
				copy.spawn_mode = "random" if mode == "random" else "manual"
				if mode != "empty":
					for s: Dictionary in copy.objects:
						if str(s.kind) == "start":
							copy.objects.append({"kind": "enemy", "mob": "skelettwache", "x": float(s.x), "y": float(s.y)})
							break
				if mode == "random":
					copy.auto_mobs = 2
			Data.save(copy, base)
		RoomFloor.forget()
		var pack := Pack.new("res://assets/data/krypta_world.json", "res://assets/sprites/krypta/manifest.json")
		pack.pack.room_library.folder = base
		var raw: Dictionary = pack.build_raw(4, 4242)
		results[mode] = (raw.rooms as Array).filter(func(r: Dictionary) -> bool: return str(r.gtype) == "combat")
		_check(not (results[mode] as Array).is_empty(), mode + ": the floor has fight rooms")
	for r: Dictionary in results.manual:
		_check((r.get("placed_mobs", []) as Array).size() == 1 and str(r.placed_mobs[0].mob) == "skelettwache" and not bool(r.cleared), "by hand on a floor: its enemy and a fight")
	for r: Dictionary in results.random:
		_check((r.get("placed_mobs", []) as Array).is_empty() and int(r.mobs) == 2, "by chance on a floor: its count")
	var without := 0
	for r: Dictionary in results.empty:
		if str(r.get("drop", "")) != "" or r.get("reward") != null:
			_check(not bool(r.cleared) and int(r.mobs) > 0, "by hand with none set: a room that pays a key keeps its fight")
		else:
			without += 1
			_check(int(r.mobs) == 0 and bool(r.cleared), "by hand with none set: a room without a fight")
	_check(without > 0, "rooms without a fight on that floor")
	RoomFloor.forget()
	var dir := ProjectSettings.globalize_path(base.path_join("krypta"))
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base))


## The controls: enemies in their own categories, a set enemy can change its kind, choosing one sets the room to by hand.
func _test_editor_controls() -> void:
	var editor: Node = EditorScene.instantiate()
	root.add_child(editor)
	for i in range(4):
		await process_frame
	var room := _room()
	room.spawn_mode = "random"
	editor.rooms.append(room)
	editor._open_room(room)
	var parts: Array = editor._monster_parts()
	var cats := {}
	for p: Dictionary in parts:
		cats[str(p.cat)] = int(cats.get(str(p.cat), 0)) + 1
	_check(int(cats.get("Gegner", 0)) >= 5 and int(cats.get("Bossgegner", 0)) >= 5, "enemies and bosses in their own categories: %s" % cats)
	var skeleton: Array = parts.filter(func(p: Dictionary) -> bool: return str(p.mob) == "skelett")
	_check(str(skeleton[0].label) == "Skelett", "enemies go by their names: %s" % skeleton[0].label)
	editor._on_part(skeleton[0])
	_check(str(room.spawn_mode) == "manual", "choosing an enemy to set makes the room by hand")
	_check(editor.get("_spawn_pick") != null and str(editor.get("_spawn_pick").get_item_metadata(editor.get("_spawn_pick").selected)) == "manual", "the control shows it")
	# every setting that needs words has them
	var texts := func(o: Dictionary) -> String:
		editor.canvas.picked = o
		editor._fill_inspector()
		var out := ""
		for c: Node in editor._inspector.get_children():
			if c is Label:
				out += (c as Label).text + " "
		return out
	var spikes: String = texts.call({"kind": "spikes", "x": 0.0, "y": 0.0, "phase": 0})
	_check(spikes.contains("Takt 0") and spikes.contains("Takt 1") and spikes.contains("Beispiel"), "the spikes' Takt is explained: " + spikes)
	# the floor's riddle plates can be chosen, show as chosen and say what they open
	var plate: Dictionary = {"kind": "plate", "x": 0.0, "y": 0.0, "group": "seq", "order": 0}
	var plate_text: String = texts.call(plate)
	var shown := ""
	for row: Node in editor._inspector.get_children():
		for c: Node in row.get_children():
			if c is OptionButton and (c as OptionButton).selected >= 0:
				shown += (c as OptionButton).get_item_text((c as OptionButton).selected) + " "
	_check(shown.contains("Rätsel der Etage"), "a plate of the floor's riddle shows its group: " + shown)
	_check(plate_text.contains("Riesentresor") and plate_text.contains("Sechs"), "and says what it opens: " + plate_text)
	var vent: String = texts.call({"kind": "vent", "x": 0.0, "y": 0.0})
	_check(vent.contains("Beispiel"), "the vent's Versatz is explained")
	var prop: String = texts.call({"kind": "prop", "asset": "statue_angel", "x": 0.0, "y": 0.0, "layer": "normal", "foot": [50, 26]})
	_check(prop.contains("Breite") and prop.contains("Höhe"), "width and height are explained")
	editor.queue_free()
	for i in range(3):
		await process_frame


## A view zoomed in stays when a part is picked and the side panel changes the canvas's size; only
## EINPASSEN and another room fit it again.
func _test_zoom_stays() -> void:
	var editor: Node = EditorScene.instantiate()
	root.add_child(editor)
	for i in range(4):
		await process_frame
	var room := _room()
	editor.rooms.append(room)
	editor._open_room(room)
	var canvas: Control = editor.canvas
	canvas.size = Vector2(800.0, 600.0)
	var world: Node2D = canvas._world
	var fitted: float = world.scale.x
	canvas.size = Vector2(700.0, 600.0)
	_check(not is_equal_approx(world.scale.x, fitted), "an untouched view still fits a new size")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(300.0, 300.0)
	for i in range(6):
		canvas._gui_input(wheel)
	var zoomed: float = world.scale.x
	var at: Vector2 = world.position
	canvas.picked = room.objects[2]
	editor._fill_inspector()
	for i in range(3):
		await process_frame
	canvas.size = Vector2(640.0, 600.0)
	_check(is_equal_approx(world.scale.x, zoomed), "the zoom stays when the panel changes the canvas: %f vs %f" % [world.scale.x, zoomed])
	_check(world.position.is_equal_approx(at + Vector2(-30.0, 0.0)), "what was in the middle stays there: %s vs %s" % [world.position, at])
	canvas.fit()
	_check(not is_equal_approx(world.scale.x, zoomed), "EINPASSEN fits again")
	var fit_again: float = world.scale.x
	canvas.size = Vector2(800.0, 600.0)
	_check(not is_equal_approx(world.scale.x, fit_again), "after EINPASSEN the view follows the size again")
	for i in range(6):
		canvas._gui_input(wheel)
	var other := _room()
	editor.rooms.append(other)
	editor._open_room(other)
	_check(world.scale.x < zoomed * 1.0, "another room starts fitted")
	editor.queue_free()
	for i in range(3):
		await process_frame


## In the game a stretched carpet draws at its new size: the decal's size is what the drawing uses.
func _test_sizes_on_screen() -> void:
	var game: Node = load("res://src/hell/krypta_dungeon.tscn").instantiate()
	var room := _room()
	room.objects[1].scale_w = 2.0
	room.objects[3].scale_h = 1.5
	room.objects[2].scale_w = 2.0
	game.world_room = room
	game.custom_storage_root = "user://world_part_test"
	game.graphics_path = "user://world_part_test.cfg"
	root.add_child(game)
	for i in range(8):
		await process_frame
	_check(game.W != null and not (game.W.decals as Array).is_empty(), "the game plays a room with stretched parts")
	game.queue_free()
	for i in range(3):
		await process_frame
