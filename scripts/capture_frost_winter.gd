extends SceneTree
## Captures the Frostgruft's winter details from the real windowed game (src/hero/frost_snow.gd,
## src/vfx/snowstorm.gd, the world kit's snow): footprints walked across a snow field, a slide on
## glaze ice, the ice trap firing, a snowman and a glacier. Prints a CHECK line per step.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_winter.gd -- <output_dir> [pixel|hd]
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const GRAPHICS_FILE := "user://capture_frost_graphics.cfg"

var _out := "res://production/qa/evidence/frost-welt/winter"
var _graphics := "hd"
var _game: Node
var _fails := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_graphics = args[1]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 0.0
			_game.state.hp = _game.state.max_hp
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _check(ok: bool, what: String) -> void:
	print("CHECK %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _go(p: Vector2) -> void:
	_game.player.x = p.x
	_game.player.y = p.y
	_game.camera.position = p


func _calm() -> void:
	for r: Dictionary in _game.W.rooms:
		r.fight = false
		r.cleared = true
	_game.mobs = []


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var cfg := ConfigFile.new()
	cfg.set_value("options", "graphics", _graphics)
	cfg.save(GRAPHICS_FILE)
	_game = FrostScene.instantiate()
	_game.class_id = "swordsman"
	_game.graphics_path = GRAPHICS_FILE
	root.add_child(_game)
	await _wait(30)
	var snow: Object = _game.frost_snow
	_check(snow != null and snow.snow.size() > 200, "the floor has snow fields (%d cells)" % (snow.snow.size() if snow != null else 0))
	# footprints: walk across the biggest snow field of a fight room
	_calm()
	var C: float = _game.C
	var cols: int = _game.W.cols
	var best: Array = []
	for k: int in snow.snow:
		var x := k % cols
		var y := k / cols
		var run: Array = []
		while snow.snow.has(y * cols + x + run.size()):
			run.append(Vector2((x + run.size() + 0.5) * C, (y + 0.6) * C))
		if run.size() > best.size():
			best = run
	var start: Vector2 = best[0]
	_go(start)
	await _wait(3)
	var steps := int((best.size() - 1) * C / 6.0)
	for i in range(steps):
		_go(start + Vector2(i * 6.0, sin(i * 0.15) * 10.0))
		_game.player.moving = true
		await _wait(1)
	_check(snow.prints.size() >= 6, "the hero leaves footprints in the snow (%d)" % snow.prints.size())
	await _shot("01-fussspuren.png")
	# a slide on glaze ice
	var ice := Vector2.ZERO
	for y in range(_game.W.rows):
		for x in range(cols):
			if _game._cell(x, y) == 2 and _game._cell(x + 1, y) == 2 and _game._cell(x + 2, y) == 2 and ice == Vector2.ZERO:
				ice = Vector2((x + 0.5) * C, (y + 0.7) * C)
	_check(ice != Vector2.ZERO, "there is glaze ice on the floor")
	if ice != Vector2.ZERO:
		_go(ice)
		_game.player.vel = Vector2(320, 0)
		for i in range(10):
			_game.player.vel = Vector2(320, 0)
			_game.player.x = ice.x + i * 9.0
			await _wait(1)
		_check(snow.sliding() and absf(snow.slide_lean()) > 0.05, "the hero slides on the ice, leaning into it")
		await _shot("02-rutschen.png")
	# the ice trap firing
	var trap: Dictionary = {}
	for e: Dictionary in _game.W.ents:
		if e.type == "spikes" and trap.is_empty():
			trap = e
	if not trap.is_empty():
		_go(Vector2(trap.x, trap.y + 160))
		_game.camera.position = Vector2(trap.x, trap.y)
		var period := float(_game.balance.hazards.spike_period)
		# a period in which this trap stands up (int(t / period) % 2 == its phase), 0.3 s after it fired
		var n := int(_game.state.t / period) + 2
		if n % 2 != int(trap.phase):
			n += 1
		_game.state.t = n * period + 0.3
		await _wait(4)
		_check(bool(trap.get("up", false)), "the ice trap fires")
		await _shot("03-eisfalle.png")
	else:
		print("CHECK skip no ice trap on floor 1")
	# a snowman and a glacier
	for name: String in ["snowman", "glacier_a", "glacier_b"]:
		var found: Dictionary = {}
		for p: Dictionary in _game.W.props:
			if p.name == name and found.is_empty():
				found = p
		if found.is_empty():
			print("CHECK skip no %s on floor 1" % name)
			continue
		_go(Vector2(found.x, found.y + 150))
		_game.camera.position = Vector2(found.x, found.y - 40)
		await _wait(20)
		await _shot("04-%s.png" % name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GRAPHICS_FILE))
	print("FROST_WINTER fails=%d" % _fails)
	quit(1 if _fails > 0 else 0)
