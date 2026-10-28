extends SceneTree
## Captures the bosses' new moves from the real windowed game: the
## Moderkoloss (quake line, rot globs, charge lane), the Frostleiche (hail,
## ice wall, frozen hero), the Knochenkoloss (bone cage, spike line, collapsed
## with its skull) and the Leerenrufer (void rifts, vortex, twin beam in
## rage). Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_boss_moves.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

var _out := "res://production/qa/evidence/boss-moves"
var _game: Node


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
	await _wait(2)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


## A calm room: the biggest of the floor, no horde, the hero in its most open spot.
func _arena() -> Dictionary:
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
	return hero


func _foe(kind: String, offset: Vector2, boss: bool = false) -> Dictionary:
	var hero: Dictionary = _game.players[1]
	var enemy: Dictionary = _game._create_enemy("boss" if boss else kind, Vector2(hero.pos) + offset)
	if boss:
		enemy.rig = "void"
		_game.body_parts.attach(enemy, "void")
	enemy.move_timer = 99.0
	enemy.shot_timer = 99.0
	_game.enemies.append(enemy)
	return enemy


func _move(enemy: Dictionary, id: String) -> void:
	_game.boss_moves._begin(enemy, id, _game.boss_moves.move(id), 1, _game.players[1])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	_game.player_classes[1] = "swordsman"
	_game._start_solo()
	await _wait(60)
	# Moderkoloss: quake line and rot globs at once.
	_arena()
	var brute := _foe("moderkoloss", Vector2(170, 0))
	_move(brute, "quake_line")
	await _wait(30)
	brute.erase("move")
	_move(brute, "rot_globs")
	await _wait(55)
	await _shot("01-moderkoloss-beben-und-giftklumpen")
	await _wait(60)
	_move(brute, "charge")
	await _wait(30)
	await _shot("02-moderkoloss-sturmlauf-warnung")
	# Frostleiche: hail and an ice wall.
	_arena()
	var frost := _foe("frostleiche", Vector2(190, 0))
	_move(frost, "ice_wall")
	await _wait(50)
	_move(frost, "hail")
	await _wait(40)
	await _shot("03-frostleiche-hagel-und-eiswand")
	_game.player_effects.apply(_game.players[1], "freeze", 2.0, 1.0)
	_move(frost, "ice_armor")
	await _wait(50)
	await _shot("04-frostleiche-eispanzer-held-gefroren")
	# Knochenkoloss: cage and spike line, then collapsed with its skull.
	_arena()
	var bones := _foe("knochenkoloss", Vector2(200, 0))
	_move(bones, "bone_cage")
	await _wait(55)
	bones.erase("move")
	_move(bones, "spike_line")
	await _wait(25)
	await _shot("05-knochenkoloss-kaefig-und-spitzen")
	_game._damage_enemy(bones, float(bones.max_hp) * 3.0, Vector2.RIGHT, 1)
	await _wait(40)
	await _shot("06-knochenkoloss-zerfallen-schaedel")
	# Leerenrufer: rifts under the hero and the vortex; then rage with the twin beam.
	_arena()
	var lord := _foe("", Vector2(230, 0), true)
	_move(lord, "void_rift")
	await _wait(45)
	await _shot("07-leerenrufer-risse")
	_game.enemies.clear()
	_game.boss_moves.reset()
	lord = _foe("", Vector2(260, 0), true)
	lord.hp = float(lord.max_hp) * 0.3
	lord.rage = true
	lord.twin_beam = 0.35
	lord.shot_timer = 0.0
	lord.force_beam = true
	_game.void_ai._begin(lord, 1, Vector2(_game.players[1].pos), "beam")
	# Shot while the twin beam burns (between windup and recovery).
	while str(lord.get("attack", "")) != "active": await _wait(1)
	await _wait(8)
	await _shot("08-leerenrufer-doppelstrahl-wut")
	_game._leave_session()
	await _wait(10)
	quit(0)
