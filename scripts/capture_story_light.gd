extends SceneTree
## Captures the light round the hero in the story worlds (src/hero/story_glow.gd
## darkness, the HUD rim of src/hell/hell_game.gd _draw_hud): the start room of
## the Krypta and the Hell on floors 1 and 6 and of the Frostgruft on floor 1
## (its frost fog). The hero stays unhurt.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_story_light.gd -- <output_dir>
const SCENES := {
	"krypta": "res://src/hell/krypta_dungeon.tscn",
	"hoelle": "res://src/hell/hell_dungeon.tscn",
	"frostgruft": "res://src/hell/frost_dungeon.tscn",
}
const SHOTS := [["krypta", 1], ["krypta", 6], ["hoelle", 1], ["hoelle", 6], ["frostgruft", 1]]

var _out := "res://production/qa/evidence/story-light"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and is_instance_valid(_game) and not _game.state.is_empty():
			_game.state.inv = 99.0
			_game.state.banner.t = 99.0
			_game.state.toasts = []
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for spec: Array in SHOTS:
		if _game != null and is_instance_valid(_game):
			_game.queue_free()
			await process_frame
		# a fixed run (src/world_kit/world_pack.gd new_run), so before and after show the same room
		seed(4711)
		_game = (load(SCENES[spec[0]]) as PackedScene).instantiate()
		_game.start_floor = int(spec[1])
		root.add_child(_game)
		current_scene = _game
		await _wait(120)
		# the shot without the blink of the unhurt hero
		_game.state.inv = 0.0
		await process_frame
		await RenderingServer.frame_post_draw
		var path := _out.path_join("%s-etage%d.png" % [spec[0], spec[1]])
		print("CAPTURED %s result=%d" % [path, root.get_texture().get_image().save_png(path)])
	print("STORY_LIGHT_CAPTURE done")
	quit(0)
