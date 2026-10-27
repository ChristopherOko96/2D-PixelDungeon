extends SceneTree
## Replacement through real pointer events and successive authoring gestures.
## Uses in-memory drafts; never writes active room configuration.
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("TILE_REPLACEMENT_FAIL ",label)
func _initialize() -> void: _run.call_deferred()
func click(editor: Node, point: Vector2, erase: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT if erase else MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = editor.OFFSET+point*editor._canvas_zoom
	editor._unhandled_input(event)
	event.pressed = false
	editor._input(event)
	editor._unhandled_input(event)
func cell(editor: Node, layer: String) -> Dictionary:
	for value: Dictionary in editor.model.template().painted_tiles:
		if value.x == 6 and value.y == 5 and value.get("layer","") == layer: return value
	return {}
func _run() -> void:
	var editor = load("res://src/dungeon_editor.gd").new()
	root.add_child(editor)
	await process_frame
	editor.new_blank_room()
	var point := Vector2(208,176)
	editor._select_tool(1)
	editor.select_tile("violet_017")
	click(editor,point)
	check(cell(editor,"floor").get("tile") == "violet_017","first real floor click stores selected tile")
	editor.select_tile("amber_018")
	click(editor,point)
	check(cell(editor,"floor").get("tile") == "amber_018","next real click replaces previous tile in same floor cell")
	check(editor.model.template().painted_tiles.size() == 1,"replacement does not accumulate duplicates")
	editor._undo()
	check(cell(editor,"floor").get("tile") == "violet_017","undo restores the actual replaced tile")
	editor._redo()
	check(cell(editor,"floor").get("tile") == "amber_018","redo restores replacement")
	editor._select_tool(0)
	editor.select_tile("violet_007")
	click(editor,point)
	editor.select_tile("rose_008")
	editor.rotate_brush(1)
	click(editor,point)
	check(cell(editor,"structure").get("tile") == "rose_008" and cell(editor,"structure").get("rotation") == 1,"new wall tile and rotation replace prior wall")
	check(cell(editor,"floor").get("tile") == "amber_018","wall replacement retains deliberate underlying floor")
	editor.tile_solid.button_pressed = false
	click(editor,point)
	check(cell(editor,"structure").get("solid") == false,"same tile click updates collision property")
	click(editor,point,true)
	check(cell(editor,"structure").is_empty() and cell(editor,"floor").get("tile") == "amber_018","erasing overlay reveals retained floor")
	# New brush selection must be a new editing gesture even on the last cell.
	editor._select_tool(1)
	editor.select_tile("moss_017")
	editor.model.begin_edit()
	editor.paint_at(point)
	editor.model.end_edit()
	check(cell(editor,"floor").get("tile") == "moss_017","new brush gesture replaces last visited cell without leaving it")
	editor.rotate_brush(1)
	editor.model.begin_edit()
	editor.paint_at(point)
	editor.model.end_edit()
	check(cell(editor,"floor").get("rotation") == editor.tile_rotation,"rotation update applies to last cell in a new gesture")
	editor._undo()
	check(cell(editor,"floor").get("tile") == "moss_017" and cell(editor,"floor").get("rotation") != editor.tile_rotation,"each replacement gesture remains independently undoable")
	# During a drag, Q/E plus motion inside this cell must refresh its placement.
	editor._select_tool(0)
	editor.select_tile("amber_007")
	var press := InputEventMouseButton.new()
	press.pressed = true
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = editor.OFFSET+point*editor._canvas_zoom
	editor._unhandled_input(press)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_E
	editor._unhandled_input(key)
	var motion := InputEventMouseMotion.new()
	motion.position = press.position+Vector2.ONE
	editor._unhandled_input(motion)
	check(cell(editor,"structure").get("rotation") == editor.tile_rotation,"Q/E inside current drag cell refreshes its visible tile")
	press.pressed = false
	editor._input(press)
	# Default visible replacement clears art above the chosen floor, atomically.
	editor.new_blank_room()
	check(editor.replace_toggle.button_pressed,"visible replacement is enabled by default")
	editor.model.paint_floor(Vector2i(6,5),"violet_017",0)
	editor.model.set_authored_door(Vector2i(6,5),"east","items_002",1)
	editor.model.paint_tile(Vector2i(6,5),"rose_008",0,true,"structure")
	editor.model.template().stairs_spawn = [point.x,point.y]
	editor.model.template().stairs_art = {"tile":"violet_000","rotation":0}
	editor.model.template().player_spawns = [[point.x,point.y]]
	editor.model.template().brazier_spawns = [[point.x,point.y]]
	editor.model.template().reward_spawn = [point.x,point.y]
	var before_replacement: Dictionary = editor.model.template().duplicate(true)
	editor._select_tool(1)
	editor.select_tile("moss_018")
	click(editor,point)
	check(cell(editor,"floor").get("tile") == "moss_018" and cell(editor,"structure").is_empty(),"default floor replacement clears covering wall art")
	check(editor.model.template().authored_doors.is_empty() and not editor.model.template().has("stairs_spawn") and not editor.model.template().has("stairs_art"),"replacement removes overwritten door and stair graphics")
	check(editor.model.template().player_spawns == [[point.x,point.y]] and editor.model.template().brazier_spawns == [[point.x,point.y]] and editor.model.template().reward_spawn == [point.x,point.y],"replacement preserves independent spawn fire and reward positions")
	editor._undo()
	check(editor.model.template() == before_replacement,"one undo restores floor wall door and stair together")
	editor._redo()
	check(cell(editor,"floor").get("tile") == "moss_018" and cell(editor,"structure").is_empty(),"redo restores complete visible replacement")
	editor._undo()
	editor.replace_toggle.button_pressed = false
	editor.select_tile("amber_018")
	click(editor,point)
	check(cell(editor,"floor").get("tile") == "amber_018" and cell(editor,"structure").get("tile") == "rose_008","disabled replacement edits only chosen layer")
	check(editor.model.template().authored_doors.size() == 1 and editor.model.template().has("stairs_spawn"),"layer-only edit retains deliberate door and stair overlays")
	editor.replace_toggle.button_pressed = true
	editor._select_tool(0)
	editor.select_tile("moss_007")
	click(editor,point)
	check(cell(editor,"structure").get("tile") == "moss_007" and cell(editor,"floor").get("tile") == "amber_018","structure replacement always preserves underlying floor")
	check(editor.model.template().authored_doors.is_empty() and not editor.model.template().has("stairs_spawn"),"structure replacement clears overwritten door and stair")
	# Existing rectangular templates may have automatically rendered collision pillars.
	editor.model.selected = 0
	editor._refresh_controls()
	editor._refresh_room()
	var legacy_before: Dictionary = editor.model.template().duplicate(true)
	check(editor.model.wall_cells().has(Vector2i(11,3)) and editor.model.wall_cells().has(Vector2i(12,3)),"legacy fixture contains two adjacent pillar cells")
	editor._select_tool(1)
	editor.select_tile("violet_017")
	var pillar_point := Vector2(368,112)
	click(editor,pillar_point)
	check(not editor.model.wall_cells().has(Vector2i(11,3)),"legacy visible replacement clears only overwritten automatic wall cell")
	check(editor.model.wall_cells().has(Vector2i(12,3)) and editor.model.wall_cells().has(Vector2i(11,4)),"legacy replacement preserves adjoining pillar cells")
	var replacement_found := false
	for value: Dictionary in editor.model.template().get("painted_tiles",[]):
		if value.x == 11 and value.y == 3 and value.tile == "violet_017": replacement_found = true
	check(replacement_found,"legacy replacement stores chosen surface tile")
	var Dungeon = load("res://src/dungeon/dungeon_generator.gd")
	check(not Dungeon.segment_blocked(pillar_point,pillar_point,12,editor.model.preview()),"legacy replaced floor becomes actually walkable")
	editor._undo()
	check(editor.model.template() == legacy_before,"legacy undo restores wall geometry and previous artwork together")
	editor.queue_free()
	await process_frame
	print("EDITOR_TILE_REPLACEMENT checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
