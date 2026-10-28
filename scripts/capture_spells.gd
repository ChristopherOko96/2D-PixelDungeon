extends SceneTree
## Captures evidence of the spell look pass from the real windowed game: the
## Photoneneis rebuilt from the Leerenrufer's beam (igniting, burning, swept
## into a wall, fading, the frost and scorch it leaves), bloom over the dark
## crypt, and pixel particles that bounce off walls and settle on the floor.
## Input is scripted (game.scripted_*); the hero is kept alive. Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_spells.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

var _out := "res://production/qa/evidence/spells-bloom"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(2, int(_game.players[1].hp))
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name))])


func _entry(label: String) -> Dictionary:
	for entry: Dictionary in _game.main_menu.debug_entries:
		if str(entry.label).contains(label): return entry
	return {}


func _start(entry: Dictionary, class_id: String, level_exp: int) -> void:
	_game.requested_seed = 4242
	_game.main_menu._pick_debug(entry)
	_game.main_menu._choose_class(class_id)
	await _wait(20)
	if level_exp > 0:
		_game.team_progress.add_exp(level_exp)
		_game.players[1].offer_queue = []
		_game.players[1].offer = []


func _nearest_enemy() -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	for enemy: Dictionary in _game.enemies:
		if float(enemy.hp) <= 0.0: continue
		var d := Vector2(enemy.pos).distance_to(_game.players[1].pos)
		if d < distance:
			distance = d
			best = enemy
	return best


func _face(enemy: Dictionary, distance: float) -> void:
	for angle in [PI, 0.0, PI * 0.5, -PI * 0.5, PI * 0.75, -PI * 0.75]:
		var spot: Vector2 = Vector2(enemy.pos) + Vector2.from_angle(angle) * distance
		if not Dungeon.segment_blocked(enemy.pos, spot, 16.0, _game.current_layout):
			_game.players[1].pos = spot
			return


## The sideways direction from the hero in which a wall is closest (120-300 px),
## so the impact stays on screen.
func _wall_direction() -> Vector2:
	var hero: Vector2 = _game.players[1].pos
	var best := Vector2.RIGHT
	var best_distance := INF
	for index in range(24):
		var direction := Vector2.from_angle(TAU * float(index) / 24.0)
		if absf(direction.y) > 0.6: continue
		var distance := 8.0
		while distance < 300.0 and not Dungeon.segment_blocked(hero, hero + direction * distance, 0.0, _game.current_layout): distance += 8.0
		if distance >= 120.0 and distance < 300.0 and distance < best_distance:
			best_distance = distance
			best = direction
	return best


func _beam_on() -> bool:
	return _game.state.get("players", {}).get(1, {}).get("skills", {}).has("beam")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	# 1) Mage on floor 2: the Photoneneis from ignition to the marks it leaves.
	await _start(_entry("EBENE 2"), "mage", 4000)
	var target := _nearest_enemy()
	if not target.is_empty():
		_face(target, 190.0)
		await _wait(30)
		await _frame_times("no beam")
		_game.scripted_target = Vector2(target.pos)
		_game.scripted_skills = 8
		for i in range(40):
			await _wait(1)
			if _beam_on(): break
		await _wait(1)
		await _shot("01-photoneneis-zuendet.png")
		await _wait(30)
		await _shot("02-photoneneis-brennt.png")
		await _frame_times("beam")
		_game.scripted_target = _game.players[1].pos + _wall_direction() * 400.0
		await _wait(100)
		await _shot("03-photoneneis-an-wand.png")
		_game.scripted_skills = 0
		for i in range(30):
			await _wait(1)
			if not _beam_on(): break
		await _wait(4)
		await _shot("04-photoneneis-verblasst.png")
		await _wait(70)
		await _shot("05-frost-und-brandspuren.png")
		# 2) A fireball into the nearest wall: bloom, clipped burst, embers.
		_game.players[1].skill_cd = [0.0, 0.0, 0.0, 0.0]
		_game.scripted_target = _game.players[1].pos + _wall_direction() * 400.0
		var known: Array = _game.hero_skills.events.map(func(e: Dictionary) -> int: return int(e.get("id", -1)))
		_game.scripted_skills = 1
		for i in range(90):
			await _wait(1)
			if _game.hero_skills.events.any(func(e: Dictionary) -> bool: return str(e.kind) == "burst" and not known.has(int(e.get("id", -1)))): break
		_game.scripted_skills = 0
		await _wait(3)
		await _shot("06-feuerball-bloom.png")
	_game._leave_session()
	await _wait(10)
	# 3) Sword on floor 2 (zombies): slime and blood droplets bounce off the
	# walls and stay on the floor as pixels.
	await _start(_entry("EBENE 2"), "swordsman", 4000)
	for round_index in range(6):
		target = _nearest_enemy()
		if target.is_empty(): break
		_face(target, 40.0)
		_game.scripted_target = Vector2(target.pos)
		_game.scripted_skills = 1
		_game.scripted_fire = true
		await _wait(30)
		_game.scripted_skills = 0
		_game.players[1].skill_cd = [0.0, 0.0, 0.0, 0.0]
	_game.scripted_fire = false
	await _wait(90)
	await _shot("07-blut-pixel.png")
	_game._leave_session()
	await _wait(10)
	quit(0)


## Prints the mean and worst frame time over 90 frames (performance evidence).
func _frame_times(label: String) -> void:
	var worst := 0
	var total := 0
	var last := Time.get_ticks_usec()
	for i in range(90):
		await _wait(1)
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		total += now - last
		last = now
	print("FRAME_TIMES %s mean=%.2fms worst=%.2fms particles=%d" % [label, total / 90.0 / 1000.0, worst / 1000.0, _game.view._feedback.particles.count()])
