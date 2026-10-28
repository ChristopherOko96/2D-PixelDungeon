extends SceneTree
## Captures the Frostgruft hero growth from the real windowed game: a level-up
## with its flash, the skill bar, skills in action (whirl, volley, chain and
## photon), the sealed gravity staff in its secret room on floor 4, the staff
## in hand with its dark skill bar, wall and bar in a fight, and the boss bar
## at the top. The hero is kept invulnerable and drawn on a visible blink frame.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_skills.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")

var _out := "res://production/qa/evidence/frost-floors"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 99.0
			_game.state.hp = _game.state.max_hp
		await process_frame


func _shot(name: String) -> void:
	_game.state.t = floorf(_game.state.t * 10.0) / 10.0
	await _wait(1)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d level=%d" % [path, image.save_png(path), int(_game.state.level)])


func _start(class_id: String, floor_n: int) -> void:
	if _game != null:
		_game.queue_free()
		await process_frame
	_game = FrostScene.instantiate()
	_game.class_id = class_id
	_game.start_floor = floor_n
	root.add_child(_game)
	await _wait(5)


func _fight_room() -> void:
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw >= 20:
			_game.player.x = (r.bx + r.bw / 2.0 - 2.0) * 96.0
			_game.player.y = (r.by + r.bh / 2.0 + 0.8) * 96.0
			_game.camera.position = Vector2(_game.player.x, _game.player.y)
			return


func _level_to(n: int) -> void:
	while int(_game.state.level) < n:
		HeroKit.gain(_game, HeroKit.need(_game.theme.leveling, int(_game.state.level)) - int(_game.state.exp))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	# level-up flash with the new skill
	await _start("mage", 1)
	_level_to(2)
	await _wait(30)
	_level_to(3)
	await _wait(12)
	await _shot("50-spiel-levelup.png")
	# skills in a fight: one per class
	for spec: Array in [["swordsman", "1", "51-spiel-skill-wirbelklinge.png"], ["archer", "1", "52-spiel-skill-salve.png"], ["mage", "2", "53-spiel-skill-kettenblitz.png"], ["mage", "4", "54-spiel-skill-photoneneis.png"]]:
		await _start(spec[0], 3)
		_level_to(10)
		await _wait(40)
		_fight_room()
		await _wait(120)
		var target := Vector2(_game.player.x + 300.0, _game.player.y - 40.0)
		for m: Dictionary in _game.mobs:
			if m.spawn <= 0.0:
				target = m.p - Vector2(0, m.cy)
				break
		_game.aim_at = target
		HeroKit.press(_game, spec[1])
		await _wait(8 if spec[1] != "4" else 20)
		await _shot(spec[2])
		HeroKit.release(_game, spec[1])
	# the sealed staff on floor 4
	await _start("mage", 4)
	var relic: Dictionary = {}
	for e: Dictionary in _game.W.ents:
		if e.type == "relic":
			relic = e
	_game.player.x = relic.x
	_game.player.y = relic.y + 240.0
	_game.camera.position = Vector2(relic.x, relic.y)
	_game.state.room = relic.room
	await _wait(100)
	await _shot("55-spiel-stab-versiegelt.png")
	# solve the seal and take the staff
	var plates: Array = _game.W.ents.filter(func(e: Dictionary) -> bool: return e.type == "plate" and e.get("group", "") == relic.seal)
	plates.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.order) < int(y.order))
	for pl: Dictionary in plates:
		_game.player.x = pl.x
		_game.player.y = pl.y + 10.0
		await _wait(3)
	_game.player.x = relic.x
	_game.player.y = relic.y + 60.0
	await _wait(5)
	_game.act()
	await _wait(30)
	await _shot("56-spiel-stab-genommen.png")
	# the staff in a fight: wall, bar and gravity ball
	_level_to(6)
	_fight_room()
	await _wait(150)
	var foe := Vector2(_game.player.x + 320.0, _game.player.y)
	for m: Dictionary in _game.mobs:
		if m.spawn <= 0.0:
			foe = m.p
			break
	_game.aim_at = (Vector2(_game.player.x, _game.player.y) + foe) / 2.0
	HeroKit.press(_game, "1")
	HeroKit.gravity_bar(_game, Vector2(_game.player.x - 200.0, _game.player.y - 200.0), Vector2(_game.player.x + 200.0, _game.player.y - 200.0))
	_game._fire(foe - Vector2(_game.player.x, _game.player.y - 40))
	await _wait(10)
	await _shot("57-spiel-gravitation-wand-leiste.png")
	# the boss bar at the top
	await _start("mage", 10)
	var hall: Dictionary = {}
	for r: Dictionary in _game.W.rooms:
		if r.type == "boss":
			hall = r
	_game.player.x = (hall.bx + hall.bw / 2.0) * 96.0
	_game.player.y = (hall.by + hall.bh / 2.0 + 3.0) * 96.0
	_game.state.room = hall.index
	_game._start_fight(hall)
	await _wait(60)
	await _shot("58-spiel-bossbalken-oben.png")
	quit()
