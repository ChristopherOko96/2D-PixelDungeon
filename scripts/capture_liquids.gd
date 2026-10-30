extends SceneTree
## Captures how liquids behave in the crypt: a glob of `style` landing on open
## floor (the splash and the spread), the hero wading through the pool and out
## of it (wake and wet steps), and a blast at the pool's edge (ripples). Each
## moment is a 2x close-up of the same floor patch. Uses the test profile like
## every capture script (Profile.default_path for a SceneTree script).
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_liquids.gd -- <output_dir> [style]
const Game = preload("res://src/game.gd")
const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const Profile = preload("res://src/progress/profile.gd")

var _out := "res://production/qa/evidence/liquids/vorher"
var _style := "poison"
var _game: Node
var _spot := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _style = args[1]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(6, int(_game.players[1].hp))
		await process_frame


func _wait_s(seconds: float, walk := Vector2.INF, to := Vector2.INF) -> void:
	var start := Time.get_ticks_msec()
	var until := start + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if walk.is_finite():
			# the hero walks from `walk` to `to` over the wait
			var k := clampf(float(Time.get_ticks_msec() - start) / (seconds * 1000.0), 0.0, 1.0)
			_game.players[1].pos = walk.lerp(to, k)
			_game.players[1].moving = true
		await _wait(1)


func _shot(name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var xf: Transform2D = _game.view.get_global_transform_with_canvas()
	var a: Vector2 = xf * (_spot + Vector2(-150, -95))
	var b: Vector2 = xf * (_spot + Vector2(150, 75))
	var box := Rect2i(Vector2i(int(a.x), int(a.y)), Vector2i(int(b.x - a.x), int(b.y - a.y))).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(box)
	crop.resize(box.size.x * 2, box.size.y * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join("%s-%s.png" % [_style, name]))
	print("CAPTURED ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	_game.player_classes[1] = "swordsman"
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
	# an open patch of floor: 9 x 6 walkable cells
	var walk := FxSprites.walkable_cells(_game.current_layout)
	var corner := Vector2i(1 << 30, 0)
	for c: Vector2i in walk:
		var open := true
		for y in range(0, 6):
			for x in range(0, 9):
				if not walk.has(c + Vector2i(x, y)): open = false
		if open and (corner.x == 1 << 30 or c.y * 1000 + c.x < corner.y * 1000 + corner.x): corner = c
	_spot = Vector2(corner) * 32.0 + Vector2(144, 96)
	_game.players[1].pos = _spot + Vector2(-120, 40)
	# the room camera follows him there
	await _wait(150)
	if _style == "reaktionen":
		await _reactions()
		return
	if _style == "gore":
		await _gore()
		return
	var spec := {"style": _style, "radius": 40, "time": 9.0, "dps": 0}
	# 1. a glob lands, thrown from the left
	_game.boss_moves._pool(_spot, spec, Vector2(1, 0.25))
	var last := 0.0
	for t: float in [0.04, 0.08, 0.12, 0.18, 0.3, 0.6]:
		await _wait_s(t - last)
		last = t
		await _shot("1-landet-%.2f" % t)
	await _wait_s(0.6)
	# 2. the hero wades through it and out
	await _wait_s(0.7, _spot + Vector2(-110, 6), _spot + Vector2(0, 6))
	await _shot("2-waten")
	await _wait_s(0.7, _spot + Vector2(0, 6), _spot + Vector2(110, 6))
	await _shot("2-raus")
	await _wait_s(0.6)
	await _shot("2-spuren")
	# 3. a blast at the pool's edge
	var particles: RefCounted = _game.view._feedback.particles
	particles.kick(_spot + Vector2(-30, 10), 40.0, 1.0)
	last = 0.0
	for t: float in [0.04, 0.12, 0.25]:
		await _wait_s(t - last)
		last = t
		await _shot("3-explosion-%.2f" % t)
	await _finish()


## Materials meeting (vfx_pools.json reactions): poison onto lava (left), poison
## onto ice (middle), ice onto fire (right); each second thrown 0.4 s after the first.
func _reactions() -> void:
	var pairs := [["lava", "poison", Vector2(-95, -25)], ["ice", "poison", Vector2(0, 20)], ["fire", "ice", Vector2(95, -25)]]
	for pair: Array in pairs:
		_game.boss_moves._pool(_spot + Vector2(pair[2]), {"style": pair[0], "radius": 34, "time": 9.0, "dps": 0}, Vector2(1, 0))
	await _wait_s(0.5)
	await _shot("4-erstes")
	for pair: Array in pairs:
		_game.boss_moves._pool(_spot + Vector2(pair[2]) + Vector2(14, 6), {"style": pair[1], "radius": 26, "time": 9.0, "dps": 0}, Vector2(-1, 0.2))
	var last := 0.0
	for t: float in [0.15, 0.4, 1.0, 3.0, 4.5]:
		await _wait_s(t - last)
		last = t
		await _shot("4-reaktion-%.2f" % t)
	await _finish()


## Blood of the fallen: three necromancers (blood gore) die one after the other,
## struck from the left; their blood flies and lands.
func _gore() -> void:
	var foes: Array = []
	for k in range(3):
		var foe: Dictionary = _game._create_enemy("necromancer", _spot + Vector2(-60 + k * 60, -10 + k * 20))
		foe.move_timer = 99.0
		foe.shot_timer = 99.0
		_game.enemies.append(foe)
		foes.append(foe)
	await _wait_s(0.6)
	for foe: Dictionary in foes:
		_game._damage_enemy(foe, 99999.0, Vector2.RIGHT, 1)
		await _wait_s(0.25)
	await _shot("5-blut-0.1")
	await _wait_s(0.5)
	await _shot("5-blut-0.6")
	await _wait_s(1.5)
	await _shot("5-blut-2.1")
	await _finish()


func _finish() -> void:
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
