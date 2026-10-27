extends SceneTree
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("FREE_UI_FAIL ",label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var editor = load("res://src/dungeon_editor.gd").new()
	root.add_child(editor)
	await process_frame
	editor.new_blank_room()
	check(not editor.view._snapshot.presentation_layers.actors and editor.model.template().brazier_spawns.is_empty() and editor.model.template().player_spawns.is_empty() and editor.model.template().enemy_spawns.is_empty(),"blank canvas has no inherited actors, starts or props")
	check(editor._preview_layout.exits.is_empty() and editor.model.template().painted_tiles.is_empty(),"blank preview contains no floor or four automatic entrances")
	editor.width_input.value = 40
	editor.height_input.value = 24
	editor._resize_selected()
	check(editor._canvas_zoom == 0.5 and editor.model.room_size() == Vector2(1280,768),"large canvas fits editor without cropping")
	var Palette = load("res://src/tile_palette.gd")
	check(Palette.has_method("cell_center"),"ghost brush shares scaled canvas transform")
	if Palette.has_method("cell_center"):
		check(Palette.cell_center({"x":32,"y":18},Vector2(32,156),0.5) == Vector2(552,452),"ghost aligns exactly with pointer in half-size large-room canvas")
	editor.select_tile("violet_017")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_E
	editor._unhandled_input(key)
	check(editor.tile_rotation == 1,"E rotates brush clockwise")
	key.keycode = KEY_Q
	editor._unhandled_input(key)
	check(editor.tile_rotation == 0,"Q rotates brush counterclockwise")
	editor.rotate_brush(-1)
	check(editor.tile_rotation == 3,"rotation wraps through four directions")
	editor.tile_layer.select(1)
	editor.tile_solid.button_pressed = true
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = editor.OFFSET+Vector2(1040,592)*0.5
	editor._unhandled_input(click)
	click.pressed = false
	editor._input(click)
	var cell: Dictionary = editor.model.template().painted_tiles[0]
	check(cell.x == 32 and cell.y == 18 and cell.rotation == 3 and cell.solid,"real scaled pointer gesture past old room edge stores chosen art and collision")
	editor._undo()
	check(editor.model.template().painted_tiles.is_empty(),"UI undo erases whole stroke")
	editor._redo()
	var Store = load("res://src/dungeon_editor_store.gd")
	var path := "user://free_room_ui_draft.json"
	Store.write_config(path,editor.model.config)
	var loaded: Dictionary = Store.read_config(path)
	check(loaded.error.is_empty() and loaded.config.templates[-1].painted_tiles[0].rotation == 3,"file boundary retains rotated tile")
	DirAccess.remove_absolute(path)
	check(not editor.model.validate().is_empty(),"art alone does not silently create playable ground or start slots")
	# A playable fixture now needs deliberately authored floor, starts and a port.
	editor.model.begin_edit()
	for y in range(24):
		for x in range(40): editor.model.paint_floor(Vector2i(x,y),"violet_017",0)
	for index in range(4): editor.model.set_spawn("player_spawns",index,Vector2(96+index*32,128))
	for index in range(5): editor.model.set_spawn("enemy_spawns",index,Vector2(1152+(index%2)*32,192+(index/2)*32))
	editor.model.set_authored_door(Vector2i(38,12),"east","items_002",1)
	editor.model.end_edit()
	editor._refresh_room()
	check(editor.model.validate().is_empty(),"explicit authored geometry passes publication checks")
	editor._test_room()
	check(is_instance_valid(editor._test_game) and not editor.visible,"selected variable room starts actual isolated playtest")
	if is_instance_valid(editor._test_game):
		var game = editor._test_game
		check(Vector2(game.current_layout.world_size[0],game.current_layout.world_size[1]) == Vector2(1280,768),"game consumes authored dimensions")
		var structures: Array = game.current_layout.painted_tiles.filter(func(tile: Dictionary): return tile.get("layer","") == "structure")
		check(game.current_layout.painted_tiles.size() == 961 and structures.size() == 1 and structures[0].rotation == 3,"game consumes the full authored floor and rotated structure")
		var Dungeon = load("res://src/dungeon/dungeon_generator.gd")
		check(Dungeon.segment_blocked(Vector2(1040,592),Vector2(1040,592),12,game.current_layout),"authored solid structure blocks gameplay after entering the room")
		check(not Dungeon.segment_blocked(Vector2(1072,592),Vector2(1072,592),12,game.current_layout),"adjacent painted floor remains walkable")
		game._broadcast_state(true)
		game._refresh_ui()
		game.transition_view.update(0.016)
		game._update_camera(0.016)
		check(game.world_clip.clip_contents and game.view.get_parent() == game.world_clip,"camera crops world independently from HUD")
		editor._return_from_test()
	check(editor.visible and editor.model.template().painted_tiles.size() == 961,"playtest return preserves complete authored draft")
	editor.queue_free()
	await process_frame
	print("FREE_ROOM_UI checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
