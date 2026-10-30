extends SceneTree
## Captures the void in the crypt: a void pool with debris and embers thrown
## beside it (does it pull them in?), the devour vortex (does it swirl?), and
## a void burst (does it implode?). Each moment is a 2x close-up of the same
## floor patch. Uses the test profile (Profile.default_path for a SceneTree
## script) and removes it after.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_void.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const Profile = preload("res://src/progress/profile.gd")

var _out := "res://production/qa/evidence/void/vorher"
var _game: Node
var _spot := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(6, int(_game.players[1].hp))
		await process_frame


func _wait_s(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await _wait(1)


func _shot(name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var xf: Transform2D = _game.view.get_global_transform_with_canvas()
	var a: Vector2 = xf * (_spot + Vector2(-170, -110))
	var b: Vector2 = xf * (_spot + Vector2(170, 85))
	var box := Rect2i(Vector2i(int(a.x), int(a.y)), Vector2i(int(b.x - a.x), int(b.y - a.y))).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(box)
	crop.resize(box.size.x * 2, box.size.y * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join("leere-%s.png" % name))
	print("CAPTURED ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	_game.player_classes[1] = "swordsman"
	# the same floors every run (the gas and ice captures use this seed too)
	_game.requested_seed = 4242
	_game._start_solo()
	await _wait(60)
	# the biggest room, no horde, no enemies
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
	await _wait(20)
	# an open 10 x 6 patch
	var walk := FxSprites.walkable_cells(_game.current_layout)
	var corner := Vector2i(1 << 30, 0)
	for c: Vector2i in walk:
		var open := true
		for y in range(0, 6):
			for x in range(0, 10):
				if not walk.has(c + Vector2i(x, y)): open = false
		if open and (corner.x == 1 << 30 or c.y * 1000 + c.x < corner.y * 1000 + corner.x): corner = c
	_spot = Vector2(corner) * 32.0 + Vector2(160, 96)
	_game.players[1].pos = _spot + Vector2(-140, 60)
	await _wait(150)
	var particles: RefCounted = _game.view._feedback.particles
	# 1. a void pool, debris and embers thrown beside it
	_game.boss_moves._pool(_spot + Vector2(-50, -10), {"style": "void", "radius": 36, "time": 9.0, "dps": 0}, Vector2(1, 0))
	await _wait_s(0.4)
	particles.burst(_spot + Vector2(20, -10), Color("b08a5a"), 24, 120.0, 1.2, Vector2.LEFT, 1.2, 3.0, 2.0)
	particles.embers(_spot + Vector2(-50, 45), 22.0, 14)
	await _wait_s(0.3)
	await _shot("1-lache-0.3")
	await _wait_s(1.0)
	await _shot("1-lache-1.3")
	# 2. the devour vortex
	_game.boss_moves._zone("vortex", "void", _spot + Vector2(90, 10), 110.0, 2.0)
	await _wait_s(0.5)
	await _shot("2-sog-0.5")
	await _wait_s(1.0)
	await _shot("2-sog-1.5")
	await _wait_s(0.7)
	await _shot("2-sog-ende")
	# 3. a void burst
	_game.add_fx("void_burst", _spot + Vector2(20, 50), 56.0)
	await _wait_s(0.1)
	await _shot("3-implosion-0.1")
	await _wait_s(0.2)
	await _shot("3-implosion-0.3")
	await _wait_s(0.3)
	await _shot("3-implosion-0.6")
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
