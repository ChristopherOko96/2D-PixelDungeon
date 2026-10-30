extends SceneTree
## Captures the class heroes as the crypt's part rigs in the story worlds
## (src/hero/story_hero.gd): swordsman, archer and mage in the Hell-Dungeon and
## the Frostgruft, standing and walking, each with a 2x close-up. The run keeps
## its meta in its own file.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_story_hero_rigs.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const SAVE := "user://capture_story_hero_rigs.cfg"

var _out := "res://production/qa/evidence/story-hero-rigs"
var _game: Node
var _walk := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and is_instance_valid(_game) and not _game.state.is_empty():
			_game.state.inv = 0.0
			if _walk:
				_game.player.moving = true
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])
	var screen: Vector2 = _game.get_viewport().get_canvas_transform() * Vector2(_game.player.x, _game.player.y - 40.0)
	var box := Rect2i(Vector2i(clampi(int(screen.x) - 160, 0, image.get_width() - 320), clampi(int(screen.y) - 90, 0, image.get_height() - 180)), Vector2i(320, 180))
	var crop := image.get_region(box)
	crop.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	print("CAPTURED %s result=%d" % [_out.path_join(name + "-nah.png"), crop.save_png(_out.path_join(name + "-nah.png"))])


func _start(scene: PackedScene, class_id: String) -> void:
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
		await process_frame
	_game = scene.instantiate()
	_game.meta_path = SAVE
	_game.class_id = class_id
	root.add_child(_game)
	current_scene = _game
	await _wait(30)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for world: Array in [["hoelle", HellScene], ["frost", FrostScene]]:
		for class_id: String in ["swordsman", "archer", "mage"]:
			await _start(world[1], class_id)
			print("STORY_HERO_RIG %s %s rig=%s" % [world[0], class_id, _game.story_hero.rig_name({"frames": _game.hero_frames}) if _game.story_hero != null else "-"])
			_walk = false
			await _wait(20)
			await _shot("%s-%s-steht" % [world[0], class_id])
			_walk = true
			await _wait(13)
			await _shot("%s-%s-laeuft" % [world[0], class_id])
			_walk = false
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)
