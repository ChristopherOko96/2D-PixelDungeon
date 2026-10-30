extends SceneTree
## Captures gas in the crypt: an archer (Fallensteller, level 30) casts the
## Todeszone into a room corner, the cloud spreads, the hero walks into it, a
## blast goes off in it, then a poison breath cone strikes beside it. Each
## moment is a 2x close-up of the same floor patch. Uses the test profile
## (Profile.default_path for a SceneTree script) and removes it after.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_gas.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const Profile = preload("res://src/progress/profile.gd")
const TalentCombat = preload("res://src/combat/talent_combat.gd")

var _out := "res://production/qa/evidence/gas/vorher"
## "" the full run; "wand" only clouds thrown at a wall and into a corner on dry floor.
var _mode := ""
var _game: Node
var _spot := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _mode = args[1]
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
			var k := clampf(float(Time.get_ticks_msec() - start) / (seconds * 1000.0), 0.0, 1.0)
			_game.players[1].pos = walk.lerp(to, k)
			_game.players[1].moving = true
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
	crop.save_png(_out.path_join("gas-%s.png" % name))
	print("CAPTURED ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	# a Fallensteller with every talent of the spec (the talent system's test switch: no cost)
	var talents: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/talents.json")) as Dictionary).get("talents", {})
	var profile: Dictionary = _game.progress.profile
	profile.shards = {"have": 3, "earned": 9, "spent": 6}
	var state := Profile.class_state(profile, "archer")
	state.level = 30
	state.ranks = {}
	var bar: Array = []
	for id: String in talents:
		var t: Dictionary = talents[id]
		if str(t.get("spec", "")) != "trapper": continue
		state.ranks[id] = 1 if str(t.get("kind", "")) == "ultimate" else 3
		if str(t.get("kind", "")) == "active" and bar.size() < 4: bar.append(id)
		elif str(t.get("kind", "")) == "ultimate": state.ultimate = id
	state.bar = bar
	state.soul_paid = 6
	profile.debug_free = true
	_game.progress.save()
	_game.requested_seed = 4242
	_game._start_solo(false, "archer")
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
	# a top-left inner corner with open floor below and to the right of it
	var walk := FxSprites.walkable_cells(_game.current_layout)
	var corner := Vector2i(1 << 30, 0)
	for c: Vector2i in walk:
		if walk.has(c + Vector2i(-1, 0)) or walk.has(c + Vector2i(0, -1)): continue
		var open := true
		for y in range(0, 6):
			for x in range(0, 10):
				if not walk.has(c + Vector2i(x, y)): open = false
		if open and (corner.x == 1 << 30 or c.y * 1000 + c.x < corner.y * 1000 + corner.x): corner = c
	if corner.x == 1 << 30:
		# no such corner here: the first open 10 x 6 patch
		for c: Vector2i in walk:
			var open := true
			for y in range(0, 6):
				for x in range(0, 10):
					if not walk.has(c + Vector2i(x, y)): open = false
			if open and (corner.x == 1 << 30 or c.y * 1000 + c.x < corner.y * 1000 + corner.x): corner = c
	print("CORNER ", corner)
	var p := Vector2(corner) * 32.0
	_spot = p + Vector2(150, 100)
	_game.players[1].pos = p + Vector2(200, 150)
	await _wait(150)
	if _mode == "wand":
		await _walls(p)
		return
	# 1. the Todeszone cast into the corner
	var target := p + Vector2(60, 40)
	var fired: bool = _game.talent_combat.cast(1, str(state.ultimate), {"aim": (target - Vector2(_game.players[1].pos)).normalized(), "target": target})
	print("CAST ", fired)
	await _wait_s(0.5)
	await _shot("1-wolke-0.5")
	await _wait_s(1.0)
	await _shot("1-wolke-1.5")
	# 2. the hero walks into it
	await _wait_s(0.9, Vector2(_game.players[1].pos), p + Vector2(60, 60))
	await _shot("2-held-drin")
	# 3. a blast in the cloud
	_game.view._feedback.particles.kick(p + Vector2(70, 40), 48.0, 1.0)
	await _wait_s(0.12)
	await _shot("3-explosion-0.12")
	await _wait_s(0.4)
	await _shot("3-explosion-0.5")
	# 4. a poison breath cone to the right of it
	var cone: Dictionary = _game.boss_moves._zone("cone", "poison", p + Vector2(160, 120), 150.0, 0.6)
	cone.angle = 1.05
	cone.aim = 0.0
	await _wait_s(0.35)
	await _shot("4-atem-warnung")
	await _wait_s(0.4)
	await _shot("4-atem-0.15")
	await _wait_s(0.8)
	await _shot("4-atem-0.95")
	# 5. a small cloud beside the room's wall (does it gather and slide along it?)
	var gas: RefCounted = _game.view.get("_gas")
	if gas != null:
		_spot = p + Vector2(60, 40)
		gas.emit("wand", "poison", p + Vector2(20, 20), 50.0, 6.0, float(_game.view._clock), Vector2(-60, -40), 1.0)
		await _wait_s(0.6)
		await _shot("5-wand-0.6")
		await _wait_s(1.4)
		await _shot("5-wand-2.0")
	await _finish()


## Dry floor, no zone: a poison cloud thrown into the corner at `p` (the room's
## top-left inner corner) and a smoke cloud thrown up at the top wall right of
## it. Do they hit, spread along the wall and gather in the corner?
func _walls(_p: Vector2) -> void:
	var gas: RefCounted = _game.view.get("_gas")
	if gas == null:
		print("NO GAS LAYER")
		await _finish()
		return
	# a real inner corner (wall left and above), the one with the most open floor
	# in the 9 x 5 cells right and below it (obstacles may stand in it)
	var walk := FxSprites.walkable_cells(_game.current_layout)
	var corner := Vector2i(1 << 30, 0)
	var most := -1
	for c: Vector2i in walk:
		if walk.has(c + Vector2i(-1, 0)) or walk.has(c + Vector2i(0, -1)): continue
		var score := 0
		for y in range(0, 5):
			for x in range(0, 9):
				if walk.has(c + Vector2i(x, y)): score += 1
		if score > most or (score == most and c.y * 1000 + c.x < corner.y * 1000 + corner.x):
			most = score
			corner = c
	print("WALL CORNER ", corner, " open ", most)
	var p := Vector2(corner) * 32.0
	_spot = p + Vector2(150, 100)
	_game.players[1].pos = p + Vector2(260, 175)
	await _wait(90)
	var now := float(_game.view._clock)
	gas.emit("ecke", "poison", p + Vector2(90, 75), 42.0, 8.0, now, Vector2(-95, -70), 1.0)
	gas.emit("decke", "smoke", p + Vector2(235, 90), 38.0, 8.0, now, Vector2(0, -120), 1.0)
	var last := 0.0
	for t: float in [0.25, 0.7, 1.5, 3.0, 5.0]:
		await _wait_s(t - last)
		last = t
		await _shot("6-wand-%.2f" % t)
	await _finish()


func _finish() -> void:
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
