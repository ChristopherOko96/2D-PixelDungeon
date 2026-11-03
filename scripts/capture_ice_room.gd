extends SceneTree
## Captures the Frostgruft's rooms of nothing but ice in the real game: the hero sliding in the
## middle with monsters round him, and the edge towards a snow room, on a few floors.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_ice_room.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const FLOORS := [1, 3, 6]

var _out := "res://production/qa/evidence/ice-rooms"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s" % [_out, file])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.size = Vector2i(1280, 720)
	for n: int in FLOORS:
		seed(4711 + n)
		var game: Node = FrostScene.instantiate()
		game.start_floor = n
		game.class_id = "swordsman"
		root.add_child(game)
		current_scene = game
		await process_frame
		var rooms: Array = (game.W.rooms as Array).filter(func(r: Dictionary) -> bool: return bool(r.get("ice", false)))
		print("ICE_ROOM_SHOT floor ", n, " rooms ", rooms.size(), " of ", (game.W.rooms as Array).size())
		if rooms.is_empty():
			game.queue_free()
			await process_frame
			continue
		var room: Dictionary = rooms[0]
		var cell: Vector2i = room.cells[(room.cells as Array).size() / 2]
		var at := Vector2((cell.x + 0.5) * game.C, (cell.y + 0.5) * game.C)
		game.player.x = at.x
		game.player.y = at.y
		game.state.inv = 99.0
		game.player.vel = Vector2(260.0, 40.0)
		for i in range(40):
			game.state.inv = 99.0
			await process_frame
		await _shot("floor%d_ice_room.png" % n)
		# the room's edge: its door towards the next room
		if not (room.doors as Array).is_empty():
			var door: Dictionary = game.W.doors[int(room.doors[0])]
			game.player.x = float(door.cx)
			game.player.y = float(door.cy) + 10.0
			game.player.vel = Vector2.ZERO
			for i in range(30):
				game.state.inv = 99.0
				await process_frame
			await _shot("floor%d_ice_door.png" % n)
		game.queue_free()
		await process_frame
	print("ICE_ROOM_SHOTS_DONE")
	quit()
