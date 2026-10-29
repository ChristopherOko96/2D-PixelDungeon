extends SceneTree
## Captures the crypt's heroes in the story worlds (src/hero/story_hero.gd): in
## the Hell-Dungeon the swordsman's swing and Rage's two blades, the archer's
## drawn bow and glowing arrows, the mage's spell orb; in the Frostgruft the archer.
## Usage: godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_story_heroes.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")

var _out := "res://production/qa/evidence/story-heroes"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 0.0
			_game.state.hp = int(_game.state.max_hp)
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


func _open(scene: PackedScene, class_id: String) -> void:
	if _game != null:
		_game.queue_free()
		await _wait(5)
	_game = scene.instantiate()
	_game.class_id = class_id
	root.add_child(_game)
	await _wait(60)


func _fire(dir: Vector2) -> void:
	_game.state.cool = 0.0
	_game._fire(dir)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _open(HellScene, "swordsman")
	_fire(Vector2.RIGHT)
	await _wait(4)
	_shot("01-hoelle-schwert-hieb")
	await _wait(30)
	_game.state.rage = 6.0
	await _wait(10)
	_shot("02-hoelle-raserei-zwei-klingen")
	_fire(Vector2.RIGHT)
	await _wait(10)
	_shot("03-hoelle-raserei-doppelschlag")
	await _open(HellScene, "archer")
	_fire(Vector2.RIGHT)
	await _wait(10)
	_fire(Vector2(1, -0.2))
	await _wait(8)
	_shot("04-hoelle-bogen-und-pfeile")
	await _open(HellScene, "mage")
	_fire(Vector2.RIGHT)
	await _wait(12)
	_shot("05-hoelle-magier-kugel")
	await _open(FrostScene, "archer")
	_fire(Vector2.RIGHT)
	await _wait(10)
	_fire(Vector2(1, 0.2))
	await _wait(8)
	_shot("06-frost-bogen-und-pfeile")
	quit(0)
