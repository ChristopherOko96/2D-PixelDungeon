extends SceneTree
## Suggestions in the Dungeon-Werkstatt: the layout suggestion (room_shaper.gd)
## builds chambers joined by narrow corridors with dead ends holding chests, or
## a symmetric throne hall in a boss room, and the game accepts them; the decor
## suggestion (room_stylist.gd) centres carpets, mirrors columns, torches and
## fires, puts a light shaft on the throne and never breaks the game's rules;
## the editor buttons apply both as one undo step each.

const RoomDoc = preload("res://src/editor/room_doc.gd")
const RoomEditor = preload("res://src/editor/room_editor.gd")
const RoomShaper = preload("res://src/editor/room_shaper.gd")
const RoomStylist = preload("res://src/editor/room_stylist.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const Decor = preload("res://src/dungeon/decor_catalog.gd")
const Crypt72 = preload("res://src/crypt_0x72_art.gd")
const LIBRARY := "res://assets/data/dungeon_rooms.json"
const COPY := "user://room_suggest_test_library.json"
var checked := 0
var failures: Array[String] = []
var config: Dictionary = {}


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ROOM_SUGGEST_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(LIBRARY))
	_test_labyrinth_has_narrow_corridors_and_dead_ends()
	_test_throne_hall_is_symmetric_and_accepted()
	_test_decor_suggestion_is_symmetric_and_accepted()
	_test_throne_decor_leads_to_the_throne()
	await _test_editor_buttons()
	print("ROOM_SUGGEST checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## The first suggestion of a round the game accepts (as the editor does).
func _accepted(role: String, style: String, round_seed: int) -> RefCounted:
	var doc = RoomDoc.blank("suggest_%s_%d" % [style, round_seed], "Vorschlag")
	doc.set_role(role)
	var data := RoomShaper.settings()
	var cells := RoomShaper.room_size(style, doc.size, data)
	for attempt in range(int(data.attempts)):
		var trial = RoomDoc.blank(str(doc.room.id), "Vorschlag")
		trial.set_role(role)
		trial.apply_shape(RoomShaper.suggest(style, cells, round_seed + attempt * 31, data), cells)
		if trial.ready_to_play(config): return trial
	return null


func _test_labyrinth_has_narrow_corridors_and_dead_ends() -> void:
	var accepted := 0
	for round_seed: int in [11, 222, 3333]:
		# Arrange / Act
		var shape := RoomShaper.suggest("labyrinth", Vector2i(48, 32), round_seed)
		var again := RoomShaper.suggest("labyrinth", Vector2i(48, 32), round_seed)
		var map := RoomStylist.analyse(shape.floor, shape.start)
		var areas: Array = map.chambers.map(func(chamber: Dictionary) -> int: return int(chamber.area))
		# Assert
		check(again.floor == shape.floor, "the same seed gives the same layout (%d)" % round_seed)
		check(Array(shape.main).size() >= 3 and map.chambers.size() >= 3, "several chambers on the way (%d)" % round_seed)
		check(map.corridor.size() >= 6, "narrow corridors join them (%d)" % round_seed)
		check(not areas.is_empty() and areas.max() >= 2 * areas.min(), "big and small chambers alternate (%s)" % str(areas))
		check(Array(shape.chests).size() == Array(shape.side).size() and Array(shape.chests).all(func(cell: Vector2i) -> bool: return shape.floor.has(cell)), "every dead end holds a chest spot (%d)" % round_seed)
		var floor_cells: Dictionary = shape.floor
		check(floor_cells.keys().all(func(cell: Vector2i) -> bool: return cell.x >= 1 and cell.y >= 1 and cell.x <= 46 and cell.y <= 30), "the layout stays inside the room's walls")
		if _accepted("normal", "labyrinth", round_seed) != null: accepted += 1
	check(accepted == 3, "every round finds a layout the game accepts (%d of 3)" % accepted)


func _test_throne_hall_is_symmetric_and_accepted() -> void:
	# Arrange / Act
	var doc = _accepted("boss", "throne", 77)
	# Assert
	check(doc != null, "a throne hall the game accepts is found")
	if doc == null: return
	var middle: int = doc.size.x / 2
	var mirrored: bool = doc.floor_cells.keys().all(func(cell: Vector2i) -> bool: return doc.floor_cells.has(Vector2i(2 * middle - cell.x, cell.y)))
	check(mirrored, "the throne hall mirrors around its middle")
	check(doc.stairs.x == middle and doc.enemies.size() == 1 and doc.enemies[0].x == middle and doc.stairs.y < doc.enemies[0].y, "throne and stairs lie on the axis, the stairs behind the throne")
	check(doc.start.x == middle and doc.start.y > doc.enemies[0].y, "the heroes arrive opposite the throne")


func _mirror_ok(doc: RefCounted, cells: Array, rect: Rect2i, horizontal_mirror: bool) -> bool:
	for cell: Vector2i in cells:
		var other := Vector2i(rect.position.x + rect.end.x - 1 - cell.x, cell.y) if horizontal_mirror else Vector2i(cell.x, rect.position.y + rect.end.y - 1 - cell.y)
		if not cells.has(other): return false
	return true


func _test_decor_suggestion_is_symmetric_and_accepted() -> void:
	# Arrange
	var doc = _accepted("normal", "labyrinth", 222)
	check(doc != null, "a layout to decorate")
	if doc == null: return
	# Act
	doc.begin_change()
	var report := RoomStylist.style(doc, 5)
	var map := RoomStylist.analyse(doc.floor_cells, doc.start)
	# Assert
	check(doc.generator_problems(config).is_empty(), "the decorated room is still accepted (%s)" % str(doc.generator_problems(config)))
	check(int(report.carpets) >= 1 and not doc.carpets.is_empty(), "at least one carpet runner")
	check(doc.decor.values().any(func(piece: Array) -> bool: return str(piece[0]) == "wall_torch"), "torches light the walls")
	var centred := 0
	var columns_mirrored := true
	for chamber: Dictionary in map.chambers:
		var rect: Rect2i = chamber.rect
		var carpet: Array = chamber.cells.keys().filter(func(cell: Vector2i) -> bool: return doc.carpets.has(cell))
		if not carpet.is_empty() and _mirror_ok(doc, carpet, rect, not bool(chamber.horizontal)): centred += 1
		var columns: Array = chamber.cells.keys().filter(func(cell: Vector2i) -> bool: return doc.decor.has(cell) and str(doc.decor[cell][0]) == "column")
		if not columns.is_empty() and not _mirror_ok(doc, columns, rect, not bool(chamber.horizontal)): columns_mirrored = false
	check(centred >= 1, "carpets lie in the middle of their chamber")
	check(columns_mirrored, "columns stand in mirrored pairs")
	var dead_ends: Array = map.chambers.filter(func(chamber: Dictionary) -> bool: return bool(chamber.dead_end))
	check(dead_ends.is_empty() or dead_ends.any(func(chamber: Dictionary) -> bool: return chamber.cells.keys().any(func(cell: Vector2i) -> bool: return doc.floor_styles.has(cell))), "dead ends look old (cracks, moss)")
	check(doc.undo() and doc.decor.is_empty() and doc.carpets.is_empty(), "one undo takes the whole suggestion back")


func _test_throne_decor_leads_to_the_throne() -> void:
	# Arrange
	var doc = _accepted("boss", "throne", 77)
	if doc == null: return
	var throne: Vector2i = doc.enemies[0]
	var middle: int = throne.x
	# Act
	RoomStylist.style(doc, 9)
	var template: Dictionary = doc.to_template()
	var crypt = Crypt72.new()
	crypt.bake(Dungeon._make_layout(template, {"tile_size": 32, "generator_version": Dungeon.GENERATOR_VERSION, "world_size": template.world_size, "play_bounds": template.play_bounds}), 3)
	# Assert
	check(doc.generator_problems(config).is_empty(), "the decorated throne hall is accepted (%s)" % str(doc.generator_problems(config)))
	check(doc.decor.get(throne, [""])[0] == "light_shaft" and crypt.shafts.size() == 1, "a light shaft falls on the throne")
	var hall_bottom := 0
	for cell: Vector2i in doc.carpets:
		if cell.x == middle: hall_bottom = maxi(hall_bottom, cell.y)
	check(doc.carpets.has(throne) and hall_bottom >= throne.y + 8, "the carpet runs from the hall's entrance to the throne")
	check(doc.carpets.keys().all(func(cell: Vector2i) -> bool: return doc.carpets.has(Vector2i(2 * middle - cell.x, cell.y))), "the carpet is centred on the axis")
	var fires: Array = doc.decor.keys().filter(func(cell: Vector2i) -> bool: return str(doc.decor[cell][0]) == "fire" and cell.y == throne.y)
	check(fires.size() == 2 and fires.all(func(cell: Vector2i) -> bool: return fires.has(Vector2i(2 * middle - cell.x, cell.y))), "fires stand on both sides of the throne")
	var columns: Array = doc.decor.keys().filter(func(cell: Vector2i) -> bool: return str(doc.decor[cell][0]) == "column")
	check(columns.size() >= 4 and columns.all(func(cell: Vector2i) -> bool: return columns.has(Vector2i(2 * middle - cell.x, cell.y))), "column rows mirror each other (%d)" % columns.size())


func _test_editor_buttons() -> void:
	# Arrange
	var file := FileAccess.open(COPY, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(LIBRARY))
	file.close()
	var editor = RoomEditor.new()
	editor.config_path = COPY
	root.add_child(editor)
	await process_frame
	editor.open("")
	editor.new_room()
	var before: Dictionary = editor.doc.floor_cells.duplicate()
	# Act
	editor.suggest_layout()
	var shaped: Dictionary = editor.doc.floor_cells.duplicate()
	editor.suggest_decor()
	# Assert
	check(shaped != before and editor.doc.ready_to_play(editor.config), "GRUNDRISS gives a new layout the game accepts")
	check(not editor.doc.decor.is_empty() and editor.doc.generator_problems(editor.config).is_empty(), "DEKORIEREN decorates it within the rules")
	editor.undo()
	check(editor.doc.decor.is_empty() and editor.doc.floor_cells == shaped, "STRG+Z takes the decor back")
	editor.undo()
	check(editor.doc.floor_cells == before, "and then the layout")
	editor.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COPY))
	await process_frame
