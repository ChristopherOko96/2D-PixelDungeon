extends SceneTree
## Physical overrides must not add/remove/reshape any authored room artwork.
var checked := 0
var failures := 0
var view
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("WALKABILITY_RENDER_FAIL ",label)
func _initialize() -> void: _run.call_deferred()
func photo(layout: Dictionary) -> PackedByteArray:
	view.set_state({"room_layout":layout,"phase":"combat","seed":24680,"players":{},"enemies":[],"bullets":[],"presentation_layers":{"actors":false,"props":false,"effects":false}},0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_data()
func _run() -> void:
	view = load("res://src/dungeon_view.gd").new()
	view.position = Vector2(32,32)
	root.add_child(view)
	view.set_animation_enabled(false)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	var Dungeon = load("res://src/dungeon/dungeon_generator.gd")
	var base: Dictionary = Dungeon.preview_template(config.templates[0],config)
	base.exits = []
	var original := await photo(base)
	var opened := base.duplicate(true)
	opened.visual_obstacles = base.obstacles.duplicate(true)
	opened.collision_overrides = [{"x":11,"y":3,"blocked":false}]
	opened.obstacles = []
	check(await photo(opened) == original,"walkable legacy wall keeps exactly the same rendered pixels")
	var blocked := base.duplicate(true)
	blocked.visual_obstacles = base.obstacles.duplicate(true)
	blocked.collision_overrides = [{"x":5,"y":5,"blocked":true}]
	blocked.obstacles.append([160.0,160.0,32.0,32.0])
	check(await photo(blocked) == original,"invisible collision never invents wall artwork or shadow")
	var free := {"id":"free-mask-render","layout_mode":"freeform","tile_size":32,"world_size":[896,480],"play_bounds":[0,0,896,480],"exits":[],"obstacles":[],"painted_tiles":[{"x":5,"y":5,"tile":"violet_002","rotation":1,"solid":true,"layer":"structure"}]}
	var free_original := await photo(free)
	free.collision_overrides = [{"x":5,"y":5,"blocked":false}]
	free.visual_obstacles = [[160.0,160.0,32.0,32.0]]
	check(await photo(free) == free_original,"freeform wall keeps chosen graphic and rotation")
	view.queue_free()
	await process_frame
	print("WALKABILITY_RENDER checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)
