extends SceneTree
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("AREA_UI_FAIL ",label)
func _initialize() -> void: _run.call_deferred()
func pointer(editor: Node, kind: String, cell: Vector2, pressed: bool = true, right: bool = false) -> void:
	var point: Vector2 = editor.OFFSET+cell*editor.TILE*editor._canvas_zoom
	if kind == "motion":
		var event := InputEventMouseMotion.new()
		event.position = point
		editor._unhandled_input(event)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
		if not pressed: editor._input(event)
		editor._unhandled_input(event)
func _run() -> void:
	var editor = load("res://src/dungeon_editor.gd").new()
	root.add_child(editor)
	await process_frame
	check(editor.has_method("apply_selection"),"area editor actions exist")
	if not editor.has_method("apply_selection"):
		editor.queue_free()
		await process_frame
		finish()
		return
	editor.new_blank_room()
	editor.width_input.value = 40
	editor.height_input.value = 24
	editor._resize_selected()
	editor.tool_menu.select(9)
	editor._select_tool(9)
	check(editor.selection_replace_button.visible and editor.selection_replace_button.disabled and editor.selection_erase_button.disabled,"area tools are visible and safe before selection")
	pointer(editor,"button",Vector2(8.5,6.5))
	pointer(editor,"motion",Vector2(5.5,4.5))
	pointer(editor,"button",Vector2(5.5,4.5),false)
	check(editor.selection_cells == Rect2i(5,4,4,3),"reverse drag includes both endpoint cells at half zoom")
	check(editor.model.template().painted_tiles.is_empty(),"selecting never paints")
	check(not editor.selection_replace_button.disabled and not editor.selection_erase_button.disabled,"selection enables area actions")
	editor.tile_layer.select(0)
	editor.select_tile("amber_017")
	check(editor.tool_menu.selected == 9 and editor.selection_cells == Rect2i(5,4,4,3),"palette selection preserves region and selection tool")
	var result: Dictionary = editor.apply_selection(false)
	check(result.error.is_empty() and editor.model.template().painted_tiles.size() == 12,"one fill replaces full selected rectangle")
	editor._undo()
	check(editor.model.template().painted_tiles.is_empty() and editor.selection_cells.size == Vector2i.ZERO,"one undo reverses whole area and clears stale selection")
	editor._redo()
	check(editor.model.template().painted_tiles.size() == 12,"one redo restores whole filled area")
	editor.select_all_cells()
	check(editor.selection_cells == Rect2i(0,0,40,24),"select all covers entire current canvas")
	editor.selection_erase_button.pressed.emit()
	check(editor.model.template().painted_tiles.is_empty(),"delete clears all selected tiles")
	editor._undo()
	check(editor.model.template().painted_tiles.size() == 12,"bulk delete remains a single reversible edit")
	editor.select_all_cells()
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_DELETE
	editor.id_input.grab_focus()
	editor._unhandled_input(key)
	check(editor.model.template().painted_tiles.size() == 12,"typing focus protects selection from Delete")
	editor.id_input.release_focus()
	editor.message.popup_centered()
	editor._unhandled_input(key)
	check(editor.model.template().painted_tiles.size() == 12,"modal protects selection from Delete")
	editor.message.hide()
	editor.clear_selection()
	editor._select_tool(9)
	pointer(editor,"button",Vector2(1.5,1.5))
	pointer(editor,"motion",Vector2(100,100))
	var release := InputEventMouseButton.new()
	release.pressed = false
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(1250,700)
	editor._input(release)
	check(not editor._selecting and editor.selection_cells.end == Vector2i(40,24),"drag clamps and release over UI finishes selection")
	var before := var_to_str(editor.model.config)
	pointer(editor,"button",Vector2(2.5,2.5),true,true)
	check(var_to_str(editor.model.config) == before,"right click selection never deletes authored content")
	pointer(editor,"button",Vector2(2.5,2.5))
	pointer(editor,"button",Vector2(2.5,2.5),false)
	check(editor.selection_cells == Rect2i(2,2,1,1),"single click is an inclusive one-cell selection")
	editor.clear_selection()
	key.ctrl_pressed = true
	key.keycode = KEY_A
	editor._unhandled_input(key)
	check(editor.selection_cells == Rect2i(0,0,40,24),"Ctrl+A uses whole current canvas")
	editor.select_all_cells()
	key.ctrl_pressed = false
	key.keycode = KEY_ESCAPE
	editor._unhandled_input(key)
	check(editor.selection_cells.size == Vector2i.ZERO,"Escape only clears selection")
	editor.select_all_cells()
	editor.model.selected = 0
	editor._refresh_controls()
	check(editor.selection_cells.size == Vector2i.ZERO,"room change clears prior room selection")
	editor.queue_free()
	await process_frame
	finish()
func finish() -> void:
	print("EDITOR_AREA_UI checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
