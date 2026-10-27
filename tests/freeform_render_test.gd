extends SceneTree
## Real Compatibility-rendered pixels: no implicit floor, frame or gateways.
var checked := 0
var failures := 0
var view
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("FREEFORM_RENDER_FAIL ",label)
func _initialize() -> void: _run.call_deferred()
func photo() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func _run() -> void:
	view = load("res://src/dungeon_view.gd").new()
	view.position = Vector2(32,32)
	root.add_child(view)
	view.set_animation_enabled(false)
	var layout := {"id":"render-freeform","layout_mode":"freeform","tile_size":32,"world_size":[896,480],"play_bounds":[0,0,896,480],"obstacles":[[0,0,896,480]],"painted_tiles":[],"exits":[],"brazier_spawns":[]}
	var snapshot := {"room_layout":layout,"phase":"explore","players":{},"enemies":[],"bullets":[],"editor_background":Color.WHITE,"presentation_layers":{"actors":false,"props":false,"effects":false}}
	view.set_state(snapshot,0)
	var blank := await photo()
	var empty := true
	for y in range(32,512,8):
		for x in range(32,928,8):
			if blank.get_pixel(x,y) != Color.WHITE: empty = false
	check(empty,"empty canvas is uniformly white across interior and all edges")
	layout.painted_tiles = [{"x":2,"y":2,"tile":"violet_017","rotation":0,"solid":false,"layer":"floor"}]
	view.set_state(snapshot,0)
	var painted := await photo()
	check(painted.get_pixel(112,112) != Color.WHITE and painted.get_pixel(80,112) == Color.WHITE,"only deliberately painted cell changes")
	layout.exits = [{"kind":"door","side":"east","rect":[384,192,32,32],"tile":"items_002","rotation":1,"blocked":false}]
	snapshot.phase = "combat"
	view.set_state(snapshot,0)
	var doors := await photo()
	check(doors.get_pixel(432,240) != Color.WHITE and doors.get_pixel(912,240) == Color.WHITE,"authored interior door stays at exact position without border relocation")
	snapshot.editor_background = Color.BLACK
	view.set_state(snapshot,0)
	var black := await photo()
	check(black.get_pixel(80,112) == Color.BLACK,"dark canvas background is independent from authored art")
	print("FREEFORM_RENDER checked=%d failures=%d" % [checked,failures])
	view.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
