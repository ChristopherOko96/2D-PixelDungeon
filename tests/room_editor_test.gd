extends SceneTree
## Dungeon-Werkstatt (src/editor/*): painting a room yields walls, gates and
## spawn points the generator accepts; markers stay on floor; undo/redo; the
## room pool honours roles and floor ranges; the generator can force a room
## into a floor (test play) and keeps chest spots; saving never breaks the
## story mode (a room the game rejects becomes a draft) and deleting refuses
## to empty the pool.

const RoomDoc = preload("res://src/editor/room_doc.gd")
const RoomPool = preload("res://src/editor/room_pool.gd")
const RoomEditor = preload("res://src/editor/room_editor.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const LIBRARY := "res://assets/data/dungeon_rooms.json"
const COPY := "user://room_editor_test_library.json"
var checked := 0
var failures: Array[String] = []
var config: Dictionary = {}


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ROOM_EDITOR_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(LIBRARY))
	_test_blank_room_is_accepted_by_the_game()
	_test_walls_follow_the_floor()
	_test_markers_only_on_floor_and_undo()
	_test_boss_room_needs_stairs()
	_test_recipe_room_stays_varied_until_its_floor_changes()
	_test_pool_follows_roles_and_floors()
	_test_generator_forces_the_test_room_and_keeps_chests()
	await _test_saving_never_breaks_the_story_mode()
	print("ROOM_EDITOR checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_blank_room_is_accepted_by_the_game() -> void:
	# Arrange / Act
	var doc = RoomDoc.blank("test_room", "Testraum")
	var template: Dictionary = doc.to_template()
	# Assert
	check(doc.generator_problems(config, template).is_empty(), "a new room passes the generator's checks (%s)" % str(doc.generator_problems(config, template)))
	check(template.player_spawns.size() == 4 and template.enemy_spawns.size() >= 5, "spawn points are completed to 4 players and 5 enemies")
	check(template.authored_doors.size() >= 2 and doc.gate_cells(template).size() >= 2, "doors and gates are found by themselves")
	check(doc.ready_to_play(config), "every check of a new room is green")


func _test_walls_follow_the_floor() -> void:
	# Arrange
	var doc = RoomDoc.blank("walls", "Wände")
	doc.fill_rect(Vector2i(1, 1), doc.size - Vector2i(2, 2), false)
	# Act: one 3x3 brush stroke.
	doc.brush(Vector2i(10, 10), 1, false)
	var walls: Dictionary = doc.walls()
	# Assert
	check(doc.floor_cells.size() == 9, "a 3x3 brush paints nine floor cells")
	check(walls.size() == 16 and walls.has(Vector2i(8, 8)) and walls.has(Vector2i(12, 12)), "a ring of walls (corners too) surrounds the floor")
	doc.brush(Vector2i(0, 0), 1, false)
	check(not doc.floor_cells.has(Vector2i(0, 0)), "the outer border stays wall")
	doc.resize(Vector2i(12, 10))
	check(doc.floor_cells.keys().all(func(cell: Vector2i) -> bool: return doc.paintable(cell)), "shrinking the room drops floor outside the new edge")


func _test_markers_only_on_floor_and_undo() -> void:
	# Arrange
	var doc = RoomDoc.blank("markers", "Marker")
	# Act / Assert
	check(not doc.set_marker("chest", Vector2i(1, 1)), "markers cannot sit on wall")
	doc.begin_change()
	check(doc.set_marker("chest", Vector2i(10, 10)) and doc.chests == [Vector2i(10, 10)], "a chest spot goes on floor")
	doc.begin_change()
	doc.brush(Vector2i(10, 10), 0, true)
	check(doc.chests.is_empty(), "erasing the floor removes the marker on it")
	check(doc.undo() and doc.chests == [Vector2i(10, 10)], "undo brings floor and marker back")
	check(doc.redo() and doc.chests.is_empty(), "redo erases again")
	for index in range(20): doc.set_marker("torch", Vector2i(5 + index % 10, 6 + index / 10))
	check(doc.torches.size() == RoomDoc.MAX_TORCHES, "at most 16 candles")
	# A second click on a chest makes it a Mimik, a third makes it a chest again.
	doc.set_marker("chest", Vector2i(20, 15))
	doc.set_marker("chest", Vector2i(20, 15))
	var template: Dictionary = doc.to_template()
	check(doc.mimics == [Vector2i(20, 15)] and not doc.chests.has(Vector2i(20, 15)), "a second click turns the chest into a Mimik")
	check(Array(template.get("mimic_spawns", [])).size() == 1 and Dungeon._make_layout(template, config).get("mimic_spawns", []).size() == 1, "the Mimik reaches the game's room")
	doc.set_marker("chest", Vector2i(20, 15))
	check(doc.mimics.is_empty() and doc.chests.has(Vector2i(20, 15)) and not doc.to_template().has("mimic_spawns"), "a third click makes it a chest again")


func _test_boss_room_needs_stairs() -> void:
	# Arrange
	var doc = RoomDoc.blank("boss_room", "Thron")
	doc.set_role("boss")
	var without: Array = doc.checks(config)
	# Act
	doc.set_marker("stairs", Vector2i(30, 13))
	var template: Dictionary = doc.to_template()
	# Assert
	check(without.any(func(check: Dictionary) -> bool: return not check.ok and str(check.text).contains("Treppe")), "a boss room without stairs is flagged")
	check(template.boss and template.has("stairs_spawn") and doc.generator_problems(config, template).is_empty(), "with stairs the boss room is accepted")


func _test_recipe_room_stays_varied_until_its_floor_changes() -> void:
	# Arrange: a stored crypt room shaped by a recipe.
	var original: Dictionary = config.templates[1]
	var doc = RoomDoc.from_template(original)
	# Act / Assert
	check(doc.from_recipe and doc.to_template().has("crypt_recipe"), "an untouched recipe room keeps its recipe")
	doc.set_marker("chest", doc.floor_cells.keys()[40])
	check(doc.to_template().has("crypt_recipe") and doc.to_template().chest_spawns.size() == 1, "markers do not fix the shape")
	doc.brush(doc.floor_cells.keys()[0], 0, true)
	check(not doc.to_template().has("crypt_recipe"), "changing the floor fixes the room as painted")


func _test_pool_follows_roles_and_floors() -> void:
	# Arrange: floor 2 only for one normal room.
	var pool := config.duplicate(true)
	pool.templates[2].floors = [5, 6]
	# Act
	var floor_two := RoomPool.for_floor(pool, 2, 6)
	var floor_five := RoomPool.for_floor(pool, 5, 6)
	var tested := RoomPool.for_floor(pool, 2, 6, str(pool.templates[2].id))
	# Assert
	check(floor_two.templates.size() == pool.templates.size() - 1, "a room stays out of floors outside its range")
	check(floor_five.templates.size() == pool.templates.size(), "it appears on its own floors")
	check(tested.templates.size() == pool.templates.size(), "a room under test is always in the pool")
	var thin := config.duplicate(true)
	for room: Dictionary in thin.templates: room.floors = [9, 9]
	check(RoomPool.for_floor(thin, 1, 6).templates.size() == thin.templates.size(), "a floor without enough rooms falls back to the whole pool")
	var room := {"boss": false}
	RoomPool.set_role(room, "entrance")
	check(RoomPool.role(room) == "entrance" and room.crypt_entrance, "roles map to the generator's flags")


func _test_generator_forces_the_test_room_and_keeps_chests() -> void:
	# Arrange: a new room with chests, added to the pool.
	var doc = RoomDoc.blank("forced_room", "Probe")
	doc.set_marker("chest", Vector2i(20, 12))
	var pool := config.duplicate(true)
	pool.templates.append(doc.to_template())
	# Act
	var rooms := Dungeon.generate(4242, 6, pool, "forced_room")
	# Assert
	check(rooms.size() == 6 and str(rooms[0].template_id) == "forced_room", "the test room opens the floor")
	var spots: Array = rooms[0].get("chest_spawns", []).map(func(cell: Array) -> Vector2i: return Vector2i(int(cell[0]), int(cell[1])))
	check(spots == [Vector2i(20, 12)], "the room's chest spots reach the game (%s)" % str(spots))
	var boss = RoomDoc.blank("forced_boss", "Probethron")
	boss.set_role("boss")
	boss.set_marker("stairs", Vector2i(30, 13))
	pool.templates.append(boss.to_template())
	rooms = Dungeon.generate(777, 6, pool, "forced_boss")
	check(rooms.size() == 6 and str(rooms[5].template_id) == "forced_boss", "a boss room under test ends the floor")


func _mouse_button(at: Vector2, index: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = index
	event.pressed = pressed
	return event


func _mouse_motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event


func _test_saving_never_breaks_the_story_mode() -> void:
	# Arrange: the editor on a copy of the library.
	var file := FileAccess.open(COPY, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(LIBRARY))
	file.close()
	var editor = RoomEditor.new()
	editor.config_path = COPY
	root.add_child(editor)
	await process_frame
	editor.open("")
	# The mouse path: a click and a drag on the canvas paint, a right click erases.
	editor.new_room()
	editor.select_tool("floor")
	editor.set_brush(0)
	var canvas: Control = editor._canvas
	var cell := Vector2i(2, 6)  # left of the new room's floor, so it stays connected
	var at: Vector2 = canvas.offset + (Vector2(cell) * 32.0 + Vector2(16, 16)) * canvas.zoom
	var before_floor: int = editor.doc.floor_cells.size()
	canvas._gui_input(_mouse_button(at, MOUSE_BUTTON_LEFT, true))
	canvas._gui_input(_mouse_motion(at + Vector2(32, 0) * canvas.zoom))
	canvas._gui_input(_mouse_button(at + Vector2(32, 0) * canvas.zoom, MOUSE_BUTTON_LEFT, false))
	check(editor.doc.floor_cells.has(cell) and editor.doc.floor_cells.has(cell + Vector2i.RIGHT) and editor.doc.floor_cells.size() == before_floor + 2, "clicking and dragging on the canvas paints floor")
	canvas._gui_input(_mouse_button(at, MOUSE_BUTTON_RIGHT, true))
	canvas._gui_input(_mouse_button(at, MOUSE_BUTTON_RIGHT, false))
	check(not editor.doc.floor_cells.has(cell), "a right click erases it again")
	editor.undo()
	check(editor.doc.floor_cells.has(cell), "STRG+Z brings it back")
	# Act: a good new room, then a broken one (no floor left).
	var good_id := str(editor.doc.room.id)
	var good: bool = editor.save(false)
	editor.new_room()
	var broken_id := str(editor.doc.room.id)
	editor.doc.begin_change()
	editor.doc.fill_rect(Vector2i(1, 1), editor.doc.size - Vector2i(2, 2), false)
	var broken: bool = editor.save(false)
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COPY))
	# Assert
	check(good and stored.templates.any(func(room: Dictionary) -> bool: return room.id == good_id), "a good room joins the story pool")
	check(not broken and stored.draft_rooms.any(func(room: Dictionary) -> bool: return room.id == broken_id), "a room the game rejects is kept as a draft")
	check(Dungeon.validate_config(stored).is_empty(), "the stored library stays valid for the story mode")
	# Deleting rooms until the pool would break is refused.
	var before: int = stored.templates.size()
	for index in range(14):
		editor.select_room(0)
		editor.delete_room()
		editor.delete_room()
	stored = JSON.parse_string(FileAccess.get_file_as_string(COPY))
	check(Dungeon.validate_config(stored).is_empty() and stored.templates.size() >= 4 and stored.templates.size() < before, "deleting stops before the story mode lacks rooms")
	editor.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COPY))
	await process_frame
