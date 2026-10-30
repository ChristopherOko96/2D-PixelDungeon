extends SceneTree
## Captures the Hell's lava floor up close: the hero placed two cells from the
## nearest lava tile of floor 1, a few moments over two seconds (bubbles,
## spits, the warm rim), then a blast at the lava's edge. Uses a capture meta
## file and the test profile, never the player's.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_lava_hell.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const Profile = preload("res://src/progress/profile.gd")

var _out := "res://production/qa/evidence/fire-lava/vorher"
var _game: Node
var _lava := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	_run.call_deferred()


func _wait_s(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if _game != null and _game.get("state") != null:
			_game.state.inv = 5.0
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var xf: Transform2D = _game.get_viewport().get_canvas_transform()
	var c: Vector2 = xf * _lava
	var box := Rect2i(Vector2i(clampi(int(c.x) - 240, 0, 1280 - 480), clampi(int(c.y) - 135, 0, 720 - 270)), Vector2i(480, 270))
	var crop := image.get_region(box)
	crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join(name + ".png"))
	print("CAPTURED ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = HellScene.instantiate()
	_game.meta_path = "user://capture_lava_hell.cfg"
	_game.class_id = "mage"
	_game.start_floor = 1
	root.add_child(_game)
	await _wait_s(1.0)
	# the lava tile nearest to the hero with open floor two cells south of it
	var hero := Vector2(float(_game.player.x), float(_game.player.y))
	var best := Vector2i(-1, -1)
	var best_d := INF
	var cols := int(_game.W.cols)
	for cy in range(int(_game.W.rows)):
		for cx in range(cols):
			var t := int(_game.W.grid[cy * cols + cx])
			if t != 2 and t != 3: continue
			if not _game._walkable(_game._cell(cx, cy + 2)): continue
			var at := Vector2((cx + 0.5) * _game.C, (cy + 0.5) * _game.C)
			if at.distance_to(hero) < best_d:
				best_d = at.distance_to(hero)
				best = Vector2i(cx, cy)
	if best.x < 0:
		push_error("no lava on this floor")
		quit(1)
		return
	_lava = Vector2((best.x + 0.5) * _game.C, (best.y + 0.5) * _game.C)
	_game.player.x = _lava.x
	_game.player.y = _lava.y + 2.0 * _game.C
	await _wait_s(1.2)
	for t: float in [0.0, 0.7, 1.4]:
		await _wait_s(0.7 if t > 0.0 else 0.0)
		await _shot("lava-%.1f" % t)
	# a blast at the lava's edge (the feel's particles, crypt units)
	if _game.feel != null:
		_game.feel.feedback.particles.kick((_lava + Vector2(0, _game.C * 0.6)) / _game.feel.scale, 40.0, 1.0)
	await _wait_s(0.15)
	await _shot("explosion-0.15")
	await _wait_s(0.3)
	await _shot("explosion-0.45")
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_lava_hell.cfg"))
	quit(0)
