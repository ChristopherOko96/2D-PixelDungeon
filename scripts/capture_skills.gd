extends SceneTree
## Captures evidence of hero skills, team EXP, level-up cards, gore and broken
## walls from the real windowed game. Skill keys and the mouse point are
## scripted (game.scripted_skills / scripted_target); enemies act on their own.
## The hero is kept alive. Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_skills.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const WallBreaker = preload("res://src/dungeon/wall_breaker.gd")

var _out := "res://production/qa/evidence/hero-skills"
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
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])

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

func _press(keys: int, target: Vector2, hold_frames: int) -> void:
	_game.scripted_target = target
	_game.scripted_skills = keys
	await _wait(hold_frames)
	_game.scripted_skills = 0
	await _wait(2)

## Puts the hero a given distance from an enemy, with a clear line of sight.
func _face(enemy: Dictionary, distance: float) -> void:
	for angle in [PI, 0.0, PI * 0.5, -PI * 0.5, PI * 0.75, -PI * 0.75, PI * 0.25, -PI * 0.25]:
		var spot: Vector2 = Vector2(enemy.pos) + Vector2.from_angle(angle) * distance
		if not Dungeon.segment_blocked(enemy.pos, spot, 18.0, _game.current_layout):
			_game.players[1].pos = spot
			return

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

## Puts the hero `distance` px left of an inner divider wall, if the room has one.
func _beside_inner_wall(distance: float) -> Vector2:
	var layout: Dictionary = _game.current_layout
	var grid := WallBreaker._grid(layout)
	for cell: Vector2i in grid:
		if WallBreaker.inner(layout, cell, grid) and grid.get(cell + Vector2i.LEFT, "") == "floor" and grid.get(cell + Vector2i.LEFT * 5, "") == "floor":
			var center := Vector2(cell) * 32.0 + Vector2(16, 16)
			var spot := center + Vector2(-distance, 0)
			if Dungeon.segment_blocked(spot, center + Vector2(-24, 0), 4.0, layout): continue
			_game.players[1].pos = spot
			return center
	return Vector2.INF

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	# 1) Swordsman, level 1: fight, orbs fly, the first level-up cards appear.
	await _start(_entry("RAUM 02"), "swordsman", 0)
	var target := _nearest_enemy()
	if not target.is_empty(): _game.players[1].pos = Vector2(target.pos) + Vector2(-50, 0)
	await _wait(10)
	await _press(1, _game.players[1].pos + Vector2(60, 0), 6)
	await _wait(30)
	_game.team_progress.add_exp(_game.team_progress.next_level_exp())
	await _wait(40)
	await _shot("01-schwert-wirbel-level-karten.png")
	# 2) Swordsman at level 10: Rage with the second blade, blood on the floor.
	_game.players[1].offer_queue = []
	_game.players[1].offer = []
	_game.team_progress.add_exp(4000)
	_game.players[1].offer_queue = []
	_game.players[1].offer = []
	await _press(8, _game.players[1].pos + Vector2(80, 0), 4)
	target = _nearest_enemy()
	if not target.is_empty():
		_game.players[1].pos = Vector2(target.pos) + Vector2(-40, 0)
		_game.scripted_target = Vector2(target.pos)
	await _wait(70)
	await _shot("02-schwert-rage-blut.png")
	_game._leave_session()
	await _wait(10)
	# 3) Archer at level 10: Salve, then the Pfeilfaust's warning and flight into a wall.
	await _start(_entry("RAUM 02"), "archer", 4000)
	target = _nearest_enemy()
	if not target.is_empty(): await _press(1, Vector2(target.pos), 8)
	await _wait(6)
	await _shot("03-bogen-salve.png")
	var wall := _beside_inner_wall(180.0)
	if wall.is_finite():
		await _press(0, wall, 2)
		_game.scripted_target = wall
		_game.scripted_skills = 8
		await _wait(11)
		await _shot("04-bogen-pfeilfaust-warnung.png")
		_game.scripted_skills = 0
		# The shot right when the wall gives way (layout revision changes).
		var revision := int(_game._room_layout_revision)
		for i in range(90):
			await _wait(1)
			if int(_game._room_layout_revision) != revision: break
		await _wait(3)
		await _shot("05-bogen-pfeilfaust-wand-bricht.png")
		await _wait(40)
		await _shot("06-durchbruch.png")
	_game._leave_session()
	await _wait(10)
	# 4) Mage at level 10: chain lightning, then the Photoneneis beam on an inner wall.
	await _start(_entry("RAUM 04"), "mage", 4000)
	target = _nearest_enemy()
	if not target.is_empty():
		_face(target, 170.0)
		await _wait(40)
		_game.scripted_target = Vector2(target.pos)
		_game.scripted_skills = 2
		for i in range(60):
			var nearest := _nearest_enemy()
			if not nearest.is_empty(): _game.scripted_target = Vector2(nearest.pos)
			await _wait(1)
			if float(_game.players[1].skill_cd[1]) > 0.0: break
		# Wait until the cast reached the snapshot the HUD and view draw.
		for k in range(30):
			await _wait(1)
			if float(_game.state.get("players", {}).get(1, {}).get("skills", {}).get("cd", [0, 0])[1]) > 0.0: break
		await _wait(2)
		await _shot("07-magier-kettenblitz.png")
		_game.scripted_skills = 0
		await _wait(2)
		_game.scripted_target = Vector2(target.pos)
		_game.scripted_skills = 8
		await _wait(40)
		await _shot("08-magier-photoneneis.png")
		_game.scripted_skills = 0
	_game._leave_session()
	await _wait(10)
	# 5) Floor 2 (zombies): slime and blood splats, drip trails of the wounded.
	await _start(_entry("EBENE 2"), "swordsman", 4000)
	for round_index in range(6):
		target = _nearest_enemy()
		if target.is_empty(): break
		_face(target, 40.0)
		await _press(1, Vector2(target.pos), 8)
		_game.scripted_target = Vector2(target.pos)
		await _wait(25)
		for enemy: Dictionary in _game.enemies:
			if float(enemy.hp) > 0.0: enemy.hp = minf(float(enemy.hp), float(enemy.max_hp) * 0.5)
		_game.players[1].skill_cd = [0.0, 0.0, 0.0, 0.0]
	await _wait(60)
	await _shot("10-blut-schleim.png")
	_game._leave_session()
	await _wait(10)
	# 6) Mini-boss kill: boss loot cards with class-matching icons.
	await _start(_entry("MODERKOLOSS"), "swordsman", 900)
	for enemy: Dictionary in _game.enemies:
		if bool(enemy.get("miniboss", false)):
			_game.players[1].pos = Vector2(enemy.pos) + Vector2(-200, 40)
			_game._damage_enemy(enemy, 9999.0, Vector2.RIGHT, 1)
	await _wait(60)
	await _shot("09-boss-beute-karten.png")
	_game._leave_session()
	await _wait(10)
	quit(0)
