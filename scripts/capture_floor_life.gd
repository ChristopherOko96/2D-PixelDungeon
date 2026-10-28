extends SceneTree
## Captures evidence of the living floor (Noita stage 1) from the real windowed
## game: a fireball kill leaves blood that creeps and dries and embers that
## smoke and turn to soot, a second blast lifts what lies on the floor, and the
## Photoneneis leaves frost that melts to water. Every shot also gets a 4x
## close-up of the spot (name-nah.png). Input is scripted; the hero is kept
## alive. Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_floor_life.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

var _out := "res://production/qa/evidence/floor-life"
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


## A full screenshot and a 4x close-up around the world point `focus`.
func _shot(name: String, focus: Vector2) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])
	var screen: Vector2 = _game.view.get_global_transform_with_canvas() * focus
	var size := Vector2i(320, 180)
	var corner := Vector2i(clampi(int(screen.x) - size.x / 2, 0, image.get_width() - size.x), clampi(int(screen.y) - size.y / 2, 0, image.get_height() - size.y))
	var close := image.get_region(Rect2i(corner, size))
	close.resize(size.x * 4, size.y * 4, Image.INTERPOLATE_NEAREST)
	print("CAPTURED %s-nah result=%d" % [name, close.save_png(_out.path_join(name + "-nah.png"))])


func _entry(label: String) -> Dictionary:
	for entry: Dictionary in _game.main_menu.debug_entries:
		if str(entry.label).contains(label): return entry
	return {}


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


## Casts the fireball at `point` and waits for its explosion.
func _fireball(point: Vector2) -> void:
	_game.players[1].skill_cd = [0.0, 0.0, 0.0, 0.0]
	var known: Array = _game.hero_skills.events.map(func(e: Dictionary) -> int: return int(e.get("id", -1)))
	_game.scripted_target = point
	_game.scripted_skills = 1
	for i in range(90):
		await _wait(1)
		if _game.hero_skills.events.any(func(e: Dictionary) -> bool: return str(e.kind) == "burst" and not known.has(int(e.get("id", -1)))): break
	_game.scripted_skills = 0


## The sideways direction in which a wall is closest (120-300 px).
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


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	_game.requested_seed = 4242
	_game.main_menu._pick_debug(_entry("EBENE 2"))
	_game.main_menu._choose_class("mage")
	await _wait(20)
	_game.team_progress.add_exp(4000)
	_game.players[1].offer_queue = []
	_game.players[1].offer = []
	var target := _nearest_enemy()
	if target.is_empty():
		quit(1)
		return
	_face(target, 150.0)
	await _wait(20)
	# 1) A fireball kills a group: blood splats, embers, smoke.
	var spot: Vector2 = Vector2(target.pos)
	for enemy: Dictionary in _game.enemies:
		if Vector2(enemy.pos).distance_to(spot) < 120.0: enemy.hp = 1.0
	await _fireball(spot)
	await _wait(3)
	await _shot("01-feuerball-blut-glut", spot)
	await _frame_times("embers and pools", 120)
	await _shot("02-glut-raucht-blut-kriecht", spot)
	await _wait(360)
	await _shot("03-blut-getrocknet-russ", spot)
	# 2) A second blast on the same spot lifts what lies on the floor.
	await _fireball(spot)
	await _wait(4)
	await _shot("04-explosion-wirbelt-auf", spot)
	await _wait(90)
	await _shot("05-aufgewirbeltes-liegt-neu", spot)
	# 3) The Photoneneis into a wall: frost, then it melts to water.
	var direction := _wall_direction()
	_game.scripted_target = _game.players[1].pos + direction * 400.0
	_game.scripted_skills = 8
	await _wait(150)
	_game.scripted_skills = 0
	var impact: Vector2 = _game.players[1].pos + direction * 160.0
	for i in range(30):
		await _wait(1)
	var beam_end: Vector2 = impact
	var distance := 8.0
	while distance < 400.0 and not Dungeon.segment_blocked(_game.players[1].pos, _game.players[1].pos + direction * distance, 0.0, _game.current_layout): distance += 8.0
	beam_end = _game.players[1].pos + direction * (distance - 16.0)
	await _shot("06-frost-an-der-wand", beam_end)
	await _wait(660)
	await _shot("07-frost-geschmolzen", beam_end)
	_game._leave_session()
	await _wait(10)
	quit(0)


## Prints the mean and worst frame time over `frames` frames (performance evidence).
func _frame_times(label: String, frames: int) -> void:
	var worst := 0
	var total := 0
	var last := Time.get_ticks_usec()
	for i in range(frames):
		await _wait(1)
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		total += now - last
		last = now
	print("FRAME_TIMES %s mean=%.2fms worst=%.2fms particles=%d embers=%d pools=%d" % [label, total / float(frames) / 1000.0, worst / 1000.0, _game.view._feedback.particles.count(), _game.view._feedback.particles.ember_count(), _game.view._feedback.particles.pool_count()])
