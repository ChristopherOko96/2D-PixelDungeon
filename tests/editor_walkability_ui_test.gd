extends SceneTree
## Selection-level collision edits preserve art and use one reversible action.
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("WALKABILITY_UI_FAIL ",label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var editor = load("res://src/dungeon_editor.gd").new()
	root.add_child(editor)
	await process_frame
	check(editor.has_method("apply_selection_walkability"),"selection has explicit walkable and blocked actions")
	if not editor.has_method("apply_selection_walkability"):
		editor.queue_free()
		await process_frame
		finish()
		return
	editor.new_blank_room()
	editor.tool_menu.select(9)
	editor._select_tool(9)
	check(editor.selection_walkable_button.visible and editor.selection_block_button.visible and editor.selection_walkable_button.disabled and editor.selection_block_button.disabled,"collision controls are visible but disabled without a selection")
	check(editor.selection_walkable_button.size.x <= 128 and editor.selection_walkable_button.position.x+editor.selection_walkable_button.size.x <= editor.selection_block_button.position.x,"collision buttons fit beside each other without clipping")
	check(not editor.apply_selection_walkability(true).error.is_empty(),"missing selection never modifies the room")
	editor.model.begin_edit()
	for y in range(4,7):
		for x in range(4,8): editor.model.paint_tile(Vector2i(x,y),"violet_017",0,false,"structure")
	editor.model.end_edit()
	editor._refresh_room()
	editor.selection_cells = Rect2i(4,4,4,3)
	editor._refresh_selection_controls()
	var art_before: Array = editor.model.template().painted_tiles.duplicate(true)
	var selection_before: Rect2i = editor.selection_cells
	check(not editor.selection_walkable_button.disabled and not editor.selection_block_button.disabled,"selection enables both collision controls")
	editor.selection_walkable_button.pressed.emit()
	check(editor.model.template().painted_tiles == art_before and editor.selection_cells == selection_before,"making area walkable keeps all art and selection")
	check(not editor.grid_cell_info(Vector2i(5,5)).blocked,"walkable action immediately updates visible grid state")
	check(editor.status.text.contains("begehbar"),"walkable result is explained in UI")
	editor.selection_block_button.pressed.emit()
	check(editor.model.template().painted_tiles == art_before and editor.grid_cell_info(Vector2i(5,5)).blocked,"blocking changes collision and keeps art")
	check(editor.selection_cells == selection_before and editor.status.text.contains("blockiert"),"blocking keeps selection and explains result")
	editor._undo()
	check(not editor.grid_cell_info(Vector2i(5,5)).blocked,"one Undo restores previous walkability")
	editor._redo()
	check(editor.grid_cell_info(Vector2i(5,5)).blocked,"one Redo restores whole blocked area")
	editor.clear_selection()
	check(editor.selection_walkable_button.disabled and editor.selection_block_button.disabled,"clearing selection disables collision actions")
	editor.tool_menu.select(1)
	editor._select_tool(1)
	check(not editor.selection_walkable_button.visible and not editor.selection_block_button.visible,"normal paint mode has no active area collision controls")
	editor.queue_free()
	await process_frame
	finish()
func finish() -> void:
	print("EDITOR_WALKABILITY_UI checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
