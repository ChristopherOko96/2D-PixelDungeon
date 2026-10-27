extends SceneTree
func _initialize() -> void:
	if not FileAccess.file_exists("res://src/room_camera.gd"):
		printerr("CAMERA_FAIL missing following camera")
		quit(1)
		return
	var camera = load("res://src/room_camera.gd").new()
	var world := Vector2(1600,960)
	var viewport := Vector2(896,480)
	var tuning := {"follow_speed":5.0,"look_ahead":24.0,"small_room_follow":0.18,"edge_margin":32.0}
	camera.reset(Vector2(600,400),world,viewport)
	var before: Vector2 = camera.center
	var offset: Vector2 = camera.update(Vector2(700,400),Vector2(300,0),world,viewport,0.016,tuning,false)
	assert(camera.center.x > before.x and camera.center.x < 724,"smooth follow does not jump")
	assert(offset == (viewport*0.5-camera.center).round(),"integer translation preserves pixels")
	var saved: Vector2 = camera.center
	camera.update(Vector2(1400,800),Vector2(500,0),world,viewport,1,tuning,true)
	assert(camera.center == saved,"pause/transition freezes following")
	for frame in range(120): camera.update(Vector2(1500,850),Vector2(10000,10000),world,viewport,0.016,tuning,false)
	assert(camera.center.x <= world.x-viewport.x*0.5+32 and camera.center.y <= world.y-viewport.y*0.5+32,"camera stays near room bounds")
	print("ROOM_CAMERA checked=4 failures=0")
	quit()
