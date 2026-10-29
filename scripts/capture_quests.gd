extends SceneTree
## Captures the Auftragsliste in the pause menu of every story from the real
## windowed game: the crypt (Story 1), the Frostgruft (Story 2) and the Hölle
## (Story 3), each opened with Esc. Uses the test profile file, never the player's.
##   godot --path . --resolution 1280x720 -s res://scripts/capture_quests.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")

var _out := "res://production/qa/evidence/quests"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()

func _wait(frames: int) -> void:
	for i in range(frames): await process_frame

func _shot(name: String) -> void:
	await _wait(2)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])

func _esc(game: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game._unhandled_input(event)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var game: Node = Game.new()
	root.add_child(game)
	game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	game.requested_seed = 4242
	game._start_solo(false, "swordsman")
	await _wait(60)
	game.set_pause_open(true, "quests")
	await _wait(10)
	await _shot("01-gruft-pausenmenue-auftrag.png")
	game.set_pause_open(false)
	game.queue_free()
	await _wait(5)
	var index := 2
	for entry: Array in [[FrostScene, "frostgruft"], [HellScene, "hoelle"]]:
		var story: Node = (entry[0] as PackedScene).instantiate()
		story.start_floor = 1
		root.add_child(story)
		await _wait(60)
		await _shot("%02d-%s-spiel.png" % [index, entry[1]])
		_esc(story)
		await _wait(10)
		await _shot("%02d-%s-pausenmenue-auftrag.png" % [index + 1, entry[1]])
		story.queue_free()
		await _wait(5)
		index += 2
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit()
