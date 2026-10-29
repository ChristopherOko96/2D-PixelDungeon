extends SceneTree
## Captures the polished heroes in the real windowed crypt: the swordsman leaning
## into a swing, the whirl, the charge's afterimages, Rage's two blades and its
## crossed second swing, a skeleton cut in two, a body slammed into a wall; the
## archer pulling the string, a full Ballistapfeil draw, and arrows in flight.
## Usage: godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_hero_polish.gd -- <output_dir> [room_file]
## room_file: another dungeon_rooms.json (e.g. the committed one while the editor has the real one open).
const Game = preload("res://src/game.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

var _out := "res://production/qa/evidence/hero-polish"
var _game: Node
var _rooms := ""
## Where the hero stands at the start of each scene.
var _home := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	if args.size() > 1: _rooms = args[1]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 0.0
			_game.players[1].hp = int(_game.players[1].max_hp)
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


func _hero() -> Dictionary:
	return _game.players[1]


func _foes(offsets: Array, kind := "skeleton") -> Array:
	_game.enemies.clear()
	var out: Array = []
	for o: Vector2 in offsets:
		var e: Dictionary = _game._create_enemy(kind, Vector2(_hero().pos) + o)
		e.aware = true
		_game.enemies.append(e)
		out.append(e)
	return out


## Clears debris and effects of the last scene.
func _clean() -> void:
	_game.view.reset_feedback()
	_hero().pos = _home
	await _wait(4)


func _attack(aim: Vector2) -> void:
	_hero().aim = aim
	_game.perk_combat.melee(1, aim)
	_game.hero_skills.basic_attack(1, _hero(), aim)


func _skill(index: int, target: Vector2) -> void:
	var hero := _hero()
	_game.hero_skills._press(1, hero, index, ClassPerks.skill_at(str(hero.class_id), index), target)


func _class(class_id: String) -> void:
	var hero := _hero()
	_game.player_classes[1] = class_id
	_game.HeroClass.apply(hero, class_id, _game.balance)
	_game.inventory.start_kit(hero)
	# a fresh skill state for the new class (the run never changes class; only this staging does)
	_game.hero_skills._fresh(hero)
	_game.action_times.clear()
	_game._send_action("cheat", Array(_game.cheats.order()).find("all_skills"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	if not _rooms.is_empty(): _game.dungeon_file_path = _rooms
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	_game.player_classes[1] = "swordsman"
	_game._start_solo()
	await _wait(40)
	_game.hordes.enabled = false
	_class("swordsman")
	# let the level-up light of the cheat fade; scenes start a little into the room
	await _wait(150)
	_home = Dungeon.move_actor(_hero().pos, Vector2(120, 60), float(_game.balance.player.radius), _game.current_layout)
	await _clean()
	# 1 swing: the body leans in, the blade sweeps a crescent
	_foes([Vector2(70, -10), Vector2(80, 30)])
	await _wait(20)
	_attack(Vector2.RIGHT)
	await _wait(4)
	_shot("01-schwert-hieb-mit-koerper")
	await _wait(30)
	await _clean()
	# 2 whirl
	_foes([Vector2(60, 0), Vector2(-60, 10), Vector2(0, 60)])
	await _wait(10)
	_skill(0, Vector2(_hero().pos) + Vector2(80, 0))
	await _wait(8)
	_shot("02-wirbelklinge")
	await _wait(40)
	await _clean()
	# 3 charge: afterimages and speed lines
	_foes([Vector2(110, 0), Vector2(150, 24)])
	await _wait(10)
	_skill(2, Vector2(_hero().pos) + Vector2(200, 0))
	await _wait(6)
	_shot("03-ansturm-nachbilder")
	await _wait(40)
	await _clean()
	# 4 rage: two blades, crossed second swing, a skeleton cut in two
	_skill(3, Vector2(_hero().pos) + Vector2(80, 0))
	await _wait(20)
	_shot("04-raserei-zwei-klingen")
	var cut: Array = _foes([Vector2(48, 0)])
	cut[0].hp = 1.0
	await _wait(10)
	_attack(Vector2.RIGHT)
	await _wait(9)
	_shot("05-raserei-doppelschlag")
	await _wait(10)
	_shot("06-skelett-zerteilt")
	await _wait(40)
	await _clean()
	# 5 wall slam: a skeleton between the hero and the wall to the left
	var hero := _hero()
	hero.pos = Dungeon.move_actor(hero.pos, Vector2(-3000, 0), float(_game.balance.player.radius), _game.current_layout) + Vector2(150, 0)
	var thrown: Array = _foes([Vector2(-54, 0)])
	thrown[0].hp = float(thrown[0].max_hp) * 20.0
	thrown[0].max_hp = thrown[0].hp
	await _wait(10)
	_attack(Vector2.LEFT)
	await _wait(10)
	_shot("07-gegen-die-wand")
	await _wait(40)
	await _clean()
	# 6 archer: string pulled with a nocked arrow, then a full Ballistapfeil draw
	_class("archer")
	await _wait(150)
	_foes([Vector2(260, 0)])
	await _wait(20)
	_hero().aim = Vector2.RIGHT
	_game.perk_combat.shoot(1, Vector2.RIGHT)
	await _wait(16)
	_shot("08-bogen-spannen")
	await _wait(30)
	_game.hero_skills._hold_start(1, _hero(), 1, ClassPerks.skill_at("archer", 1))
	await _wait(60)
	_shot("09-ballista-voll-gespannt")
	_game.hero_skills._hold_end(1, _hero(), 1, ClassPerks.skill_at("archer", 1))
	await _wait(30)
	await _clean()
	# 7 arrows in flight: four frames in a row
	_foes([Vector2(420, 0)])
	await _wait(10)
	_game.perk_combat.shoot(1, Vector2.RIGHT)
	for i in range(4):
		await _wait(2)
		_shot("10-pfeil-flug-%d" % i)
	_game._leave_session()
	await _wait(10)
	quit(0)
