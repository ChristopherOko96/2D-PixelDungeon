extends SceneTree
## Captures the main menu (every button inside the card) from the real window.
##   godot --path . --resolution 1280x720 -s res://scripts/capture_menu_card.gd -- <output_dir>
const Game = preload("res://src/game.gd")
var _out := "res://production/qa/evidence/attacks"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var game: Node = Game.new()
	root.add_child(game)
	for i in range(40): await process_frame
	RenderingServer.force_draw(false)
	var path := _out.path_join("01-hauptmenue.png")
	print("CAPTURED %s result=%d" % [path, root.get_texture().get_image().save_png(path)])
	quit()
