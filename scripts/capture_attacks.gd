extends SceneTree
## Captures the archer's and mage's basic attacks in the real windowed game:
## arrows with their light streaks and release flashes (start bow, ember bow,
## a critical volley), arrows striking, the mage's orbs in flight with rune
## rings and motes, and spells bursting on foes. Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_attacks.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

var _out := "res://production/qa/evidence/attacks"
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
	await _wait(1)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


## The biggest room of the floor, empty, the hero where it is most open to the right.
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
	_game.chests.loot[str(_game.current_layout.id)] = []
	_game.hordes.enabled = false
	_game.phase = "combat"
	var hero: Dictionary = _game.players[1]
	var open := Vector2.ZERO
	var room := 0.0
	for entry: Dictionary in _game.current_layout.painted_tiles:
		if str(entry.get("layer", "")) != "floor": continue
		var point := Vector2(float(entry.x) * 32.0 + 16.0, float(entry.y) * 32.0 + 16.0)
		var reach := 0.0
		while reach < 420.0 and not Dungeon.segment_blocked(point, point + Vector2.RIGHT * (reach + 16.0), 30.0, _game.current_layout): reach += 16.0
		if reach > room:
			room = reach
			open = point
	hero.pos = open
	return hero


func _foe(kind: String, offset: Vector2) -> Dictionary:
	var enemy: Dictionary = _game._create_enemy(kind, Vector2(_game.players[1].pos) + offset)
	enemy.move_timer = 99.0
	enemy.shot_timer = 99.0
	enemy.speed = 0.0
	enemy.hp = 9999.0
	enemy.max_hp = 9999.0
	_game.enemies.append(enemy)
	return enemy


func _arm(class_id: String, weapon: String) -> Dictionary:
	_game.player_classes[1] = class_id
	var hero: Dictionary = _game.players[1]
	_game.HeroClass.apply(hero, class_id, _game.balance)
	_game.inventory.start_kit(hero)
	if not weapon.is_empty():
		_game.inventory.add(hero, _game.inventory.make_weapon(weapon, true, ""))
		_game.inventory.act(1, "inv_equip", 0, Vector2.INF)
	hero.shot_timer = 99.0
	return hero


## Fires `count` volleys at the aim, `gap` frames apart (the hero's own timer stays off).
func _fire(aim: Vector2, count: int, gap: int) -> void:
	for volley in range(count):
		_game.players[1].shot_timer = 99.0
		_game.perk_combat.shoot(1, aim)
		await _wait(gap)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	_game.player_classes[1] = "archer"
	_game._start_solo()
	await _wait(60)
	# 1. Start bow: arrows in flight with streaks, one just leaving the bow.
	_arena()
	_arm("archer", "")
	for offset: Vector2 in [Vector2(330, 0), Vector2(360, 50)]: _foe("skeleton", offset)
	await _wait(10)
	await _fire(Vector2.RIGHT, 3, 5)
	await _shot("01-bogen-pfeile-im-flug")
	await _wait(14)
	await _shot("02-bogen-pfeile-treffen")
	# 2. Ember bow, critical volley (golden streaks and stars).
	_arena()
	var archer := _arm("archer", "ember_bow")
	for offset: Vector2 in [Vector2(320, -40), Vector2(330, 40)]: _foe("skeleton_guard", offset)
	await _wait(10)
	archer.build.crit = 1.0
	await _fire(Vector2.RIGHT.rotated(-0.08), 1, 4)
	archer.build.crit = 0.0
	await _fire(Vector2.RIGHT.rotated(0.1), 2, 5)
	await _shot("03-glutbogen-kritischer-pfeil")
	# 3. Mage: emerald orbs in flight.
	_arena()
	_arm("mage", "")
	for offset: Vector2 in [Vector2(300, -30), Vector2(320, 35)]: _foe("skeleton", offset)
	await _wait(10)
	await _fire(Vector2.RIGHT.rotated(-0.06), 1, 9)
	await _fire(Vector2.RIGHT.rotated(0.08), 1, 6)
	await _shot("04-magier-kugeln-im-flug")
	# 4. Void staff: orbs bursting on foes.
	_arena()
	_arm("mage", "void_staff")
	for offset: Vector2 in [Vector2(170, -20), Vector2(190, 30)]: _foe("skeleton", offset)
	await _wait(10)
	await _fire(Vector2.RIGHT, 3, 6)
	await _wait(4)
	await _shot("05-leerenstab-einschlag")
	# 5. Sun staff: a burning orb leaving the staff (cast circle) next to a burst.
	_arena()
	_arm("mage", "sun_staff")
	_foe("skeleton_guard", Vector2(150, 0))
	await _wait(10)
	await _fire(Vector2.RIGHT, 1, 16)
	await _fire(Vector2.RIGHT.rotated(-0.25), 1, 3)
	await _shot("06-sonnenstab-wirken-und-explosion")
	_game._leave_session()
	await _wait(10)
	quit(0)
