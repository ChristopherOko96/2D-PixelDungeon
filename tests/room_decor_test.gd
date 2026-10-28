extends SceneTree
## Decor in the Dungeon-Werkstatt (decor_catalog.gd, room_doc.gd, the crypt
## renderer and the editor's DEKO tab): the catalog's art exists and is
## sorted; carpets frame any shape; wall pieces hang only on walls with floor
## below; solid pieces never block a gate, the start or split the floor and
## reach the game as obstacles; the first piece adopts the game's own decor;
## decor survives saving, undo and the generator's checks; the game draws it.

const Decor = preload("res://src/dungeon/decor_catalog.gd")
const RoomDoc = preload("res://src/editor/room_doc.gd")
const RoomEditor = preload("res://src/editor/room_editor.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const Crypt72 = preload("res://src/crypt_0x72_art.gd")
const LIBRARY := "res://assets/data/dungeon_rooms.json"
const COPY := "user://room_decor_test_library.json"
var checked := 0
var failures: Array[String] = []
var config: Dictionary = {}


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ROOM_DECOR_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(LIBRARY))
	_test_catalog_is_complete_and_sorted()
	_test_carpets_frame_any_shape()
	_test_wall_pieces_hang_on_walls_only()
	_test_solid_pieces_keep_the_room_passable()
	_test_first_piece_adopts_the_games_decor()
	_test_decor_reaches_the_game()
	_test_areas_paint_and_erase()
	_test_floor_changes_take_decor_along()
	_test_saved_rooms_keep_their_decor()
	_test_broken_decor_is_rejected()
	await _test_editor_mouse_path()
	print("ROOM_DECOR checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_catalog_is_complete_and_sorted() -> void:
	# Arrange
	var categories := Decor.categories().map(func(category: Dictionary) -> String: return str(category.id))
	var missing: Array[String] = []
	var unsorted: Array[String] = []
	# Act
	for item: Dictionary in Decor.data().items:
		var id := str(item.id)
		if not categories.has(str(item.get("category", ""))) or str(item.get("label", "")).is_empty() or str(item.get("kind", "")) not in ["floor", "carpet", "wall", "object"]: unsorted.append(id)
		if str(item.get("draw", "")) == "shaft":
			# Drawn, not cut from a tile: it only needs its preview.
			if Decor.preview(id).image == null: missing.append(id)
			continue
		for variant in range(Decor.variants(id)):
			if not ResourceLoader.exists(Decor.tile_path(id, variant)): missing.append("%s/%d" % [id, variant])
		if item.has("below") and not ResourceLoader.exists(Decor.SPRITES + str(item.below) + ".png"): missing.append(id + "/below")
	# Assert
	check(categories.size() == 6 and categories.all(func(id: String) -> bool: return not Decor.items_in(id).is_empty()), "six categories, none empty")
	check(unsorted.is_empty(), "every piece has a category, a label and a kind (%s)" % str(unsorted))
	check(missing.is_empty(), "every tile of every piece exists (%s)" % str(missing))
	check(Decor.image(Decor.tile_path("carpet_red")).get_size() == Vector2i(48, 48), "a carpet is a 3x3 sheet of 16 px tiles")
	check(Decor.is_solid("column") and not Decor.is_solid("skull") and Decor.gives_light("fire"), "solid and light flags come from the catalog")


## Numbers from JSON come back as floats: compare them as whole numbers.
func _cells(list: Array) -> Array:
	return list.map(func(entry: Array) -> Array: return entry.map(func(value: Variant) -> int: return int(value)))


func _region(image: Image, at: Vector2i) -> PackedByteArray:
	return image.get_region(Rect2i(at, Vector2i(8, 8))).get_data()


func _test_carpets_frame_any_shape() -> void:
	# Arrange
	var sheet := Decor.image(Decor.tile_path("carpet_red"))
	# Act: a lone cell, the top-left cell of a wide carpet and a middle cell.
	var lone := Decor.carpet_cell(sheet, false, false, false, false)
	var corner := Decor.carpet_cell(sheet, false, true, true, false)
	var middle := Decor.carpet_cell(sheet, true, true, true, true)
	# Assert
	check(_region(lone, Vector2i(0, 0)) == _region(sheet, Vector2i(0, 0)) and _region(lone, Vector2i(8, 8)) == _region(sheet, Vector2i(40, 40)), "a lone carpet cell has corners all round")
	check(_region(corner, Vector2i(0, 0)) == _region(sheet, Vector2i(0, 0)) and _region(corner, Vector2i(8, 0)) == _region(sheet, Vector2i(24, 0)) and _region(corner, Vector2i(8, 8)) == _region(sheet, Vector2i(24, 24)), "a corner cell takes the edge only where the carpet ends")
	check(_region(middle, Vector2i(0, 0)) == _region(sheet, Vector2i(16, 16)), "a middle cell has no border")


func _test_wall_pieces_hang_on_walls_only() -> void:
	# Arrange: the blank room's floor is (4,4)-(35,21); row 3 is the north wall.
	var doc = RoomDoc.blank("walls", "Wände")
	var gate: Vector2i = doc.gate_spots()[0]
	var spot := Vector2i(-1, -1)
	for x in range(4, 36):
		if doc.decor_problem("banner", Vector2i(x, 3)).is_empty():
			spot = Vector2i(x, 3)
			break
	# Act / Assert
	check(spot.x >= 0 and doc.place_decor("banner", spot, 2).is_empty() and doc.decor[spot] == ["banner", 2], "a banner hangs on a north wall")
	check(doc.decor_problem("banner", Vector2i(10, 10)) == "NUR AN WAND ÜBER BODEN", "wall pieces never stand on the floor")
	check(doc.decor_problem("banner", Vector2i(3, 10)) == "NUR AN WAND ÜBER BODEN", "nor on side walls without floor below")
	check(doc.decor_problem("banner", gate) == "HIER KOMMT EIN TOR HIN", "the gate's wall stays free")
	check(doc.decor_problem("crate", Vector2i(3, 3)) == "NUR AUF BODEN", "objects need floor")
	check(doc.decor_problem("wall_ring", spot) == "PLATZ BESETZT", "one piece per cell")


func _test_solid_pieces_keep_the_room_passable() -> void:
	# Arrange: two halls joined by a one-cell bridge at row 5.
	var doc = RoomDoc.blank("bridge", "Brücke")
	doc.fill_rect(Vector2i(1, 1), doc.size - Vector2i(2, 2), false)
	doc.fill_rect(Vector2i(2, 2), Vector2i(10, 9), true)
	doc.fill_rect(Vector2i(14, 2), Vector2i(24, 9), true)
	doc.fill_rect(Vector2i(11, 5), Vector2i(13, 5), true)
	doc.set_marker("start", Vector2i(5, 6))
	var open = RoomDoc.blank("open", "Offen")
	var gate: Vector2i = open.gate_spots()[0]
	# Act / Assert
	check(doc.decor_problem("crate", Vector2i(12, 5)) == "TEILT DEN RAUM", "a crate on the only bridge is refused")
	check(doc.decor_problem("skull", Vector2i(12, 5)).is_empty(), "a skull is not solid and may lie there")
	check(doc.decor_problem("column", Vector2i(6, 6)) == "VERSPERRT DEN START", "the start stays free")
	check(open.decor_problem("crate", gate + Vector2i(0, 1)) == "VERSPERRT DAS TOR", "the floor in front of a gate stays free")
	check(open.place_decor("column", Vector2i(20, 12)).is_empty() and not open.set_marker("chest", Vector2i(20, 12)), "no marker on a column")
	# An enemy spot needs a free ring for big enemies (the game refuses the room otherwise).
	var crowd = RoomDoc.blank("crowd", "Gedränge")
	crowd.set_marker("enemy", Vector2i(30, 8))
	check(crowd.decor_problem("column", Vector2i(30, 9)) == "ZU NAH AN EINEM GEGNER", "no column right next to an enemy spot")
	crowd.place_decor("column", Vector2i(26, 16))
	check(not crowd.set_marker("enemy", Vector2i(27, 16)), "no enemy spot right next to a column")
	check(crowd.generator_problems(config).is_empty(), "the room with both apart is accepted (%s)" % str(crowd.generator_problems(config)))
	crowd.decor[Vector2i(30, 9)] = ["column", 0]
	check(crowd.generator_problems(config).has("Ein Startplatz steht zu dicht an Wand oder Möbeln"), "the game's complaint reads in German (%s)" % str(crowd.generator_problems(config)))


func _bake(template: Dictionary) -> RefCounted:
	var layout := Dungeon._make_layout(template, {"tile_size": 32, "generator_version": Dungeon.GENERATOR_VERSION, "world_size": template.world_size, "play_bounds": template.play_bounds})
	var crypt = Crypt72.new()
	crypt.bake(layout, 99)
	return crypt


func _test_first_piece_adopts_the_games_decor() -> void:
	# Arrange
	var doc = RoomDoc.blank("adopt", "Übernahme")
	var crypt = _bake(doc.to_template())
	var auto: Array = crypt.auto_items
	# Act
	var problem: String = doc.place_decor("crate", Vector2i(20, 12), 0, auto)
	var again = _bake(doc.to_template())
	# Assert
	check(not auto.is_empty() and auto.all(func(entry: Array) -> bool: return not Decor.item(str(entry[2])).is_empty()), "the game's own decor uses catalog pieces (%d)" % auto.size())
	check(problem.is_empty() and not doc.auto_decor and doc.decor.size() == auto.size() + 1, "the first piece takes the game's decor over")
	check(again.auto_items.is_empty() and again.torches.size() == crypt.torches.size(), "the room looks the same, now as the author's decor")


func _test_decor_reaches_the_game() -> void:
	# Arrange
	var doc = RoomDoc.blank("game", "Spiel")
	doc.set_auto_decor(false)
	doc.place_decor("column", Vector2i(20, 10))
	doc.place_decor("fire", Vector2i(24, 14))
	doc.place_decor("wall_torch", Vector2i(12, 3))
	doc.place_decor("fountain_water", Vector2i(16, 3))
	doc.paint_area_rect("carpet_red", Vector2i(8, 8), Vector2i(11, 10), false)
	# Act
	var template: Dictionary = doc.to_template()
	var crypt = _bake(template)
	var layout := Dungeon._make_layout(template, config)
	# Assert
	check(_cells(template.obstacles_tiles) == [[20, 10, 1, 1]], "only solid pieces become obstacles")
	check(doc.generator_problems(config, template).is_empty(), "the game accepts the decorated room (%s)" % str(doc.generator_problems(config, template)))
	check(Dungeon.segment_blocked(Vector2(20 * 32 + 16, 10 * 32 + 16), Vector2(20 * 32 + 16, 10 * 32 + 16), 4.0, layout), "the column blocks movement in the game")
	check(crypt.flames.size() == 1 and crypt.torches.size() == 1 and crypt.fountain_colors == ["blue"], "fire, torch and water fountain are animated")
	check(crypt.light_points().size() == 2, "fire and torch shine, water does not")
	var image: Image = crypt.texture.get_image()
	var sheet := Decor.image(Decor.tile_path("carpet_red"))
	check(image.get_pixel(9 * 16 + 8, 9 * 16 + 8) == sheet.get_pixel(24, 24), "the carpet is baked into the floor")
	check(template.decor.size() == 4 and template.decor_areas.size() == 12 and template.auto_decor == false, "the room stores pieces, areas and the switch")


func _test_areas_paint_and_erase() -> void:
	# Arrange
	var doc = RoomDoc.blank("areas", "Flächen")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	# Act
	var painted: int = doc.paint_area("floor_cracks", Vector2i(10, 10), 2, false, 0, true, rng)
	var outside: int = doc.paint_area("carpet_beige", Vector2i(2, 2), 0, false)
	doc.paint_area_rect("carpet_beige", Vector2i(10, 10), Vector2i(12, 12), false)
	doc.paint_area("carpet_beige", Vector2i(11, 11), 0, true)
	# Assert
	check(painted == 25 and doc.floor_styles.values().all(func(value: Array) -> bool: return int(value[1]) >= 0 and int(value[1]) < 5), "a 5x5 brush paints 25 cracked cells with valid patterns")
	check(doc.floor_styles.values().map(func(value: Array) -> int: return int(value[1])).reduce(func(a: Array, b: int) -> Array: return a if a.has(b) else a + [b], []).size() > 1, "random patterns vary")
	check(outside == 0, "areas only go on floor")
	check(doc.carpets.size() == 8 and doc.floor_styles.size() == 25, "erasing a carpet cell leaves the floor style below")


func _test_floor_changes_take_decor_along() -> void:
	# Arrange
	var doc = RoomDoc.blank("erase", "Weg")
	doc.place_decor("crate", Vector2i(15, 15))
	doc.place_decor("wall_ring", Vector2i(16, 3))
	doc.paint_area("carpet_red", Vector2i(15, 15), 0, false)
	# Act
	doc.begin_change()
	doc.brush(Vector2i(15, 15), 0, true)
	doc.brush(Vector2i(16, 4), 0, true)
	# Assert
	check(not doc.decor.has(Vector2i(15, 15)) and not doc.carpets.has(Vector2i(15, 15)), "erasing floor removes the decor on it")
	check(not doc.decor.has(Vector2i(16, 3)), "a wall piece goes when the floor below it goes")
	check(doc.undo() and doc.decor.has(Vector2i(15, 15)) and doc.decor.has(Vector2i(16, 3)) and doc.carpets.has(Vector2i(15, 15)), "undo brings it all back")
	var recipe = RoomDoc.from_template(config.templates[1])
	recipe.place_decor("skull", recipe.floor_cells.keys()[30])
	check(not recipe.to_template().has("crypt_recipe"), "decorating a recipe room fixes its shape")


func _test_saved_rooms_keep_their_decor() -> void:
	# Arrange
	var doc = RoomDoc.blank("keep", "Bleibt")
	doc.place_decor("column", Vector2i(20, 10))
	doc.place_decor("banner", Vector2i(9, 3), 3)
	doc.paint_area("floor_moss", Vector2i(12, 12), 1, false)
	doc.paint_area("carpet_beige", Vector2i(12, 12), 0, false)
	var template: Dictionary = doc.to_template()
	# Act
	var loaded = RoomDoc.from_template(JSON.parse_string(JSON.stringify(template)))
	var again: Dictionary = loaded.to_template()
	# Assert
	check(loaded.decor == doc.decor and loaded.floor_styles == doc.floor_styles and loaded.carpets == doc.carpets and loaded.auto_decor == doc.auto_decor, "pieces, areas and the switch survive the file")
	check(again.obstacles_tiles == template.obstacles_tiles, "solid pieces are not counted twice")
	var plain = RoomDoc.blank("plain", "Schlicht").to_template()
	check(not plain.has("decor") and not plain.has("decor_areas") and not plain.has("auto_decor"), "rooms without decor keep their old format")


func _test_broken_decor_is_rejected() -> void:
	# Arrange
	var template: Dictionary = RoomDoc.blank("broken", "Kaputt").to_template()
	var single := config.duplicate()
	# Act
	template.decor = [[1, 2], [300, 2, "crate", 0]]
	single.templates = [template]
	var errors := Dungeon.validate_config(single)
	# Assert
	check(Array(errors).any(func(error: String) -> bool: return error.contains("invalid decor")), "malformed decor is refused before it is drawn")


func _mouse(at: Vector2, index: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = index
	event.pressed = pressed
	return event


func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event


func _test_editor_mouse_path() -> void:
	# Arrange: the editor on a copy of the library, a new room.
	var file := FileAccess.open(COPY, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(LIBRARY))
	file.close()
	var editor = RoomEditor.new()
	editor.config_path = COPY
	root.add_child(editor)
	await process_frame
	editor.open("")
	editor.new_room()
	var canvas: Control = editor._canvas
	var at := func(cell: Vector2i) -> Vector2: return canvas.offset + (Vector2(cell) * 32.0 + Vector2(16, 16)) * canvas.zoom
	# Act: tool 9, a crate from the library, click, drag it, right click.
	editor.select_tool("decor")
	editor.show_category("moebel")
	await process_frame
	check(editor.tab == "deko" and editor._item_grid.get_child_count() == Decor.items_in("moebel").size(), "tool 9 opens the DEKO tab with the category's pieces")
	editor.pick_decor("crate")
	canvas._gui_input(_mouse(at.call(Vector2i(20, 12)), MOUSE_BUTTON_LEFT, true))
	canvas._gui_input(_mouse(at.call(Vector2i(20, 12)), MOUSE_BUTTON_LEFT, false))
	check(editor.doc.decor.get(Vector2i(20, 12), [""])[0] == "crate" and not editor.doc.auto_decor, "a click sets the crate (the game's decor is adopted)")
	canvas._gui_input(_mouse(at.call(Vector2i(20, 12)), MOUSE_BUTTON_LEFT, true))
	canvas._gui_input(_motion(at.call(Vector2i(22, 14))))
	canvas._gui_input(_mouse(at.call(Vector2i(22, 14)), MOUSE_BUTTON_LEFT, false))
	check(not editor.doc.decor.has(Vector2i(20, 12)) and editor.doc.decor.has(Vector2i(22, 14)), "dragging a piece moves it")
	editor.pick_decor("banner")
	canvas._gui_input(_motion(at.call(Vector2i(22, 13))))
	check(not canvas.ghost_ok and editor._status.text.begins_with("HIER NICHT"), "the ghost turns red and says why on the floor")
	canvas._gui_input(_mouse(at.call(Vector2i(22, 14)), MOUSE_BUTTON_RIGHT, true))
	canvas._gui_input(_mouse(at.call(Vector2i(22, 14)), MOUSE_BUTTON_RIGHT, false))
	check(not editor.doc.decor.has(Vector2i(22, 14)), "a right click removes it")
	editor.undo()
	check(editor.doc.decor.has(Vector2i(22, 14)), "STRG+Z brings it back")
	editor._arm_pipette(true)
	canvas._gui_input(_mouse(at.call(Vector2i(22, 14)), MOUSE_BUTTON_LEFT, true))
	canvas._gui_input(_mouse(at.call(Vector2i(22, 14)), MOUSE_BUTTON_LEFT, false))
	check(editor.deco_id == "crate" and editor.recent[0] == "crate", "the pipette picks the piece up into the library")
	editor.pick_decor("carpet_red")
	canvas._gui_input(_mouse(at.call(Vector2i(8, 8)), MOUSE_BUTTON_LEFT, true))
	canvas._gui_input(_motion(at.call(Vector2i(10, 9))))
	canvas._gui_input(_mouse(at.call(Vector2i(10, 9)), MOUSE_BUTTON_LEFT, false))
	check(editor.doc.carpets.size() == 6, "a carpet is dragged out as a rectangle")
	var saved: bool = editor.save(false)
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COPY))
	var room: Dictionary = {}
	for entry: Dictionary in stored.templates:
		if entry.id == editor.doc.room.id: room = entry
	check(saved and room.get("decor_areas", []).size() == 6 and _cells(room.obstacles_tiles).has([22, 14, 1, 1]), "the decorated room is saved into the story pool")
	editor.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COPY))
	await process_frame
