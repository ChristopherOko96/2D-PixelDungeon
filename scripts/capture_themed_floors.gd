extends SceneTree
## Captures evidence of the themed endless floors from the real windowed game:
## for every theme (Gruft, Orklager, Hölle, Himmel) the start room under the
## fog of war and a woken group of the theme's sheet monsters, then each floor
## boss and mini-boss mid-move. The hero is kept invulnerable; monsters act on
## their own (AI). Placing the hero or a boss next to each other is staged.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_themed_floors.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const SheetMonsters = preload("res://src/combat/sheet_monsters.gd")

var _out := "res://production/qa/evidence/themed-floors"
var _game: Node

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()

func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(1, int(_game.players[1].hp))
		await process_frame

func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])

## A run seed whose first endless floor draws `theme`.
func _seed_for(theme: String, data: Dictionary) -> int:
	var names: Array = data.floors.map(func(entry: Dictionary) -> String: return str(entry.theme))
	for candidate in range(1000, 5000):
		if SheetMonsters.theme_for(names, candidate, 1) == theme: return candidate
	return 1000

## Staged: the hero stands in clear sight `distance` away from `enemy`.
func _beside(enemy: Dictionary, distance: float) -> void:
	for offset: Vector2 in [Vector2(-1, 0.2), Vector2(1, 0.2), Vector2(-1, -0.2), Vector2(0, 1), Vector2(0, -1)]:
		var spot: Vector2 = Vector2(enemy.pos) + offset * distance
		if not Dungeon.segment_blocked(enemy.pos, spot, 14.0, _game.current_layout):
			_game.players[1].pos = spot
			return

func _start(seed_value: int) -> void:
	_game.requested_seed = seed_value
	_game._start_solo(true, "swordsman")
	await _wait(40)

func _leave() -> void:
	_game._leave_session()
	await _wait(10)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	var data: Dictionary = SheetMonsters.load_data()
	var index := 1
	for entry: Dictionary in data.floors:
		var theme := str(entry.theme)
		await _start(_seed_for(theme, data))
		# 1) The start room: theme tint, banners and details, fog all around.
		await _wait(60)
		await _shot("%02d-%s-start-nebel.png" % [index, theme])
		index += 1
		# 2) Staged: the hero walks up to the first sheet group; it wakes and fights.
		var target: Dictionary = {}
		for enemy: Dictionary in _game.enemies:
			if bool(enemy.get("sheet", false)) and not bool(enemy.get("asleep", false)):
				target = enemy
				break
		if not target.is_empty():
			_beside(target, 150.0)
			await _wait(150)
			await _shot("%02d-%s-monster.png" % [index, theme])
		index += 1
		# 3) Staged: the theme's boss and mini-boss next to the hero, mid-move.
		for kind: String in [str(entry.boss), str(entry.miniboss)]:
			var hero: Vector2 = _game.players[1].pos
			_game.enemies = _game.enemies.filter(func(enemy: Dictionary) -> bool: return Vector2(enemy.pos).distance_to(hero) > 500.0)
			var spot: Vector2 = Dungeon.move_actor(hero, Vector2(170, 0), 26.0, _game.current_layout)
			var boss: Dictionary = _game._create_enemy(kind, spot)
			boss.aggro = true
			boss.aggro_target = 1
			_game.enemies.append(boss)
			await _wait(200)
			await _shot("%02d-%s-%s.png" % [index, theme, kind])
			index += 1
			_game.enemies.erase(boss)
		await _leave()
	quit(0)
