extends SceneTree
## Real rendered editor overlay, toggled through the same checkbox as the user.
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("GRID_RENDER_FAIL ",label)
func _initialize() -> void: _run.call_deferred()
func photo() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func _run() -> void:
	root.gui_embed_subwindows = true
	var editor = load("res://src/dungeon_editor.gd").new()
	root.add_child(editor)
	await process_frame
	editor.new_blank_room()
	editor.set_canvas_background(true)
	editor.model.begin_edit()
	for x in range(4,7): editor.model.paint_floor(Vector2i(x,4),"violet_017",0)
	editor.model.paint_tile(Vector2i(5,4),"violet_017",0,true,"structure")
	editor.model.end_edit()
	editor._refresh_room()
	check(editor.grid_cell_info(Vector2i(4,4)).kind == "walkable" and editor.grid_cell_info(Vector2i(5,4)).kind == "wall" and editor.grid_cell_info(Vector2i(3,4)).kind == "void","UI cache follows actual floor wall and void")
	editor.grid_toggle.button_pressed = false
	var plain := await photo()
	editor.grid_toggle.button_pressed = true
	var marked := await photo()
	var floor_point := Vector2i(32+4*32+10,156+4*32+16)
	var wall_point := Vector2i(32+5*32+10,156+4*32+16)
	var void_point := Vector2i(32+3*32+10,156+4*32+16)
	var clean_floor := plain.get_pixelv(floor_point)
	var tinted_floor := marked.get_pixelv(floor_point)
	var clean_wall := plain.get_pixelv(wall_point)
	var tinted_wall := marked.get_pixelv(wall_point)
	check(tinted_floor.g > clean_floor.g and tinted_floor.r < clean_floor.r,"walkable tile has visible green overlay")
	check(tinted_wall.r > clean_wall.r and tinted_wall.g < clean_wall.g,"solid tile has visible red overlay")
	check(plain.get_pixelv(void_point) == Color.WHITE and marked.get_pixelv(void_point) != Color.WHITE,"void shading appears only with grid enabled")
	check(editor.grid_legend.visible,"grid legend explains colors")
	editor.grid_toggle.button_pressed = false
	check(not editor.grid_legend.visible and not editor.cell_hint.visible,"grid disabled hides collision explanations as well")
	editor.queue_free()
	await process_frame
	print("EDITOR_GRID_RENDER checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
