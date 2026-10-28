extends SceneTree
## Captures the three hero classes in the Frostgruft from the real windowed game:
## each class in a locked combat room of floor 1, attacking to the right
## (sword swing, arrows, magic bolts). The hero is kept at full hearts.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_classes.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")

var _out := "res://production/qa/evidence/frost-floors"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int, attack := Vector2.ZERO) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 0.0
			_game.state.hp = _game.state.max_hp
			if attack != Vector2.ZERO:
				_game._fire(attack)
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var n := 20
	for id: String in ["swordsman", "archer", "mage"]:
		_game = FrostScene.instantiate()
		_game.class_id = id
		root.add_child(_game)
		await _wait(10)
		for r: Dictionary in _game.W.rooms:
			if r.type == "combat" and r.bw >= 20:
				_game.player.x = (r.bx + r.bw / 2.0 - 2.0) * 96.0
				_game.player.y = (r.by + r.bh / 2.0 + 0.8) * 96.0
				_game.camera.position = Vector2(_game.player.x, _game.player.y)
				break
		await _wait(60)
		# one enemy just right of the hero, so the weapon meets something
		_game._spawn_mob(_game.state.room, Vector2(_game.player.x + 230.0, _game.player.y), "glut")
		await _wait(40, Vector2.RIGHT)
		await _wait(3, Vector2.RIGHT)
		var image := root.get_texture().get_image()
		var path := _out.path_join("%d-spiel-klasse-%s.png" % [n, id])
		print("CAPTURED %s result=%d hp=%d weapon=%s" % [path, image.save_png(path), _game.state.max_hp, _game.weapon.name])
		n += 1
		_game.queue_free()
		await process_frame
	quit()
