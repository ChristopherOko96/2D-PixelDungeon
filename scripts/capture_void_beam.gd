extends SceneTree
## Captures the Leerenrufer's void beam in the crypt (seed 4242, the biggest
## room, the hero in its most open spot, the boss in rage beside him on the
## side with the most open floor): the twin beam while it burns, full screen
## and as a 2x close-up between the boss and the hero. Uses the test profile
## (Profile.default_path for a SceneTree script) and removes it after.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_void_beam.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const Profile = preload("res://src/progress/profile.gd")

var _out := "res://production/qa/evidence/void/fein/strahl"
var _game: Node
var _from := Vector2.ZERO
var _to := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(6, int(_game.players[1].hp))
		await process_frame


func _shot(name: String) -> void:
	await _wait(1)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])
	var xf: Transform2D = _game.view.get_global_transform_with_canvas()
	var a: Vector2 = xf * _from
	var b: Vector2 = xf * _to
	var mid := (a + b) * 0.5
	var box := Rect2i(Vector2i(int(mid.x) - 240, int(mid.y) - 135), Vector2i(480, 270)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(box)
	crop.resize(box.size.x * 2, box.size.y * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join(name + "-nah.png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	_game.player_classes[1] = "swordsman"
	_game.requested_seed = 4242
	_game._start_solo()
	await _wait(60)
	# the biggest room, no horde, no enemies; the hero in its most open spot
	var best := 0
	for index in range(_game.floor_layouts.size()):
		var a: Array = _game.floor_layouts[index].world_size
		var b: Array = _game.floor_layouts[best].world_size
		if float(a[0]) * float(a[1]) > float(b[0]) * float(b[1]): best = index
	_game.room = best + 1
	_game._spawn_room()
	_game.enemies.clear()
	_game.bullets.clear()
	_game.hordes.enabled = false
	_game.phase = "combat"
	var hero: Dictionary = _game.players[1]
	var open := Vector2.ZERO
	var room := 0.0
	for entry: Dictionary in _game.current_layout.painted_tiles:
		if str(entry.get("layer", "")) != "floor": continue
		var point := Vector2(float(entry.x) * 32.0 + 16.0, float(entry.y) * 32.0 + 16.0)
		var free := 0.0
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var reach := 0.0
			while reach < 320.0 and not Dungeon.segment_blocked(point, point + direction * (reach + 16.0), 30.0, _game.current_layout): reach += 16.0
			free += minf(reach, 220.0)
		if free > room:
			room = free
			open = point
	hero.pos = open
	# the boss on the side with the most open floor
	var side := Vector2.RIGHT
	var most := -1.0
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var reach := 0.0
		while reach < 320.0 and not Dungeon.segment_blocked(open, open + direction * (reach + 16.0), 30.0, _game.current_layout): reach += 16.0
		if reach > most:
			most = reach
			side = direction
	var lord: Dictionary = _game._create_enemy("boss", open + side * minf(260.0, most - 40.0))
	lord.rig = "void"
	_game.body_parts.attach(lord, "void")
	lord.move_timer = 99.0
	lord.shot_timer = 0.0
	lord.hp = float(lord.max_hp) * 0.3
	lord.rage = true
	lord.twin_beam = 0.35
	lord.force_beam = true
	_game.enemies.append(lord)
	# the room is a fight again (it counted as cleared while it was empty)
	_game.phase = "combat"
	_from = Vector2(lord.pos)
	_to = open
	await _wait(20)
	_game.void_ai._begin(lord, 1, Vector2(hero.pos), "beam")
	var guard := 0
	while str(lord.get("attack", "")) != "active" and guard < 600:
		await _wait(1)
		guard += 1
	await _wait(8)
	await _shot("1-strahl")
	await _wait(14)
	await _shot("2-strahl-spaeter")
	_game._leave_session()
	await _wait(10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
