extends SceneTree
## Pictures of the Frostgruft's puzzle rooms in the real game, HD view, for production/qa/evidence:
## each room is loaded on its own (as F5 in the Weltbauer does), the hero stands in the puzzle, the
## picture is saved. Uses its own view setting file, never the player's user://settings.cfg.
## Run (needs a window): godot --path . -s tools/frost_dungeon/puzzles/shots.gd
## FR_SHOTS=<id>:<cell x>,<cell y>[:<act>[:<class>]];... to choose rooms, where the hero stands, "use" to
## use what is nearest and the hero's class (the picture is then named <id>_<class>); FR_OUT=<folder>.
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const Graphics = preload("res://src/core/graphics_settings.gd")
const VIEW := "user://shot_frost_hd.cfg"
const M := 2
const C := 96.0

var game: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Graphics.store("hd", VIEW)
	var out := OS.get_environment("FR_OUT") if OS.get_environment("FR_OUT") != "" else "res://production/qa/evidence/frost-raetsel"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for part: String in OS.get_environment("FR_SHOTS").split(";", false):
		var bits := part.split(":")
		var at := bits[1].split(",")
		await _shot(bits[0], Vector2(float(at[0]), float(at[1])), out, bits[2] if bits.size() > 2 else "", bits[3] if bits.size() > 3 else "")
	quit(0)


func _shot(id: String, at: Vector2, out: String, act: String, hero: String) -> void:
	game = FrostScene.instantiate()
	game.class_id = hero if hero != "" else "swordsman"
	game.graphics_path = VIEW
	game.world_room_path = "res://assets/data/world_rooms/frost/%s.json" % id
	root.add_child(game)
	for i in range(40):
		await process_frame
	game.place_player(Vector2((at.x + M + 0.5) * C, (at.y + M + 0.5) * C + 10.0))
	if act == "use":
		game.act()
	for i in range(40):
		game.state.hp = game.state.max_hp
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var name := "%s/%s%s.png" % [out, id, "_" + hero if hero != "" else ""]
	img.save_png(ProjectSettings.globalize_path(name))
	print("SHOT ", name)
	game.queue_free()
	await process_frame
	await process_frame
