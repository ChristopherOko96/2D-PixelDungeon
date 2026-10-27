extends SceneTree
## Captures evidence of the playable 0x72 crypt from the real windowed game:
## a normal room (rigged enemies, dark crypt with light circles, 0x72 tiles),
## a staged part loss, the floor 3 mini-boss, a void bomber burst and the
## Leerenrufer's beam and summons on floor 10. The hero is kept invulnerable
## so the fights keep going; enemies act on their own (AI), except where a
## shot says "staged". Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_crypt_0x72.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

var _out := "res://production/qa/evidence/0x72-playable"
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

func _entry(label: String) -> Dictionary:
	for entry: Dictionary in _game.main_menu.debug_entries:
		if str(entry.label).contains(label): return entry
	return {}

## Starts a solo run at a debug entry with a hero class on a fixed seed.
func _start(entry: Dictionary, class_id: String) -> void:
	_game.requested_seed = 4242
	_game.main_menu._pick_debug(entry)
	_game.main_menu._choose_class(class_id)
	await _wait(30)

func _leave() -> void:
	_game._leave_session()
	await _wait(10)

## Waits up to `seconds` until `condition` holds (checked every frame).
func _until(condition: Callable, seconds: float) -> bool:
	var frames := int(seconds * 60.0)
	for i in range(frames):
		if condition.call(): return true
		await _wait(1)
	return false

## Staged: puts the hero in the arena, in clear sight of the first enemy that
## matches `which`, and returns that enemy.
func _near_boss(which: Callable, distance: float) -> Dictionary:
	for enemy: Dictionary in _game.enemies:
		if not which.call(enemy): continue
		for offset: Vector2 in [Vector2(-1, 0.2), Vector2(1, 0.2), Vector2(-1, -0.2), Vector2(0, 1)]:
			var spot: Vector2 = Vector2(enemy.pos) + offset * distance
			if not Dungeon.segment_blocked(enemy.pos, spot, 14.0, _game.current_layout):
				_game.players[1].pos = spot
				break
		return enemy
	return {}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	# 1) A normal crypt room: enemies close in, the dark crypt with light circles.
	await _start(_entry("RAUM 02"), "swordsman")
	await _wait(150)
	await _shot("01-kryptaraum-dunkel.png")
	# 2) Staged: a skeleton loses its sword and a leg; the parts fall as debris.
	for enemy: Dictionary in _game.enemies:
		if str(enemy.get("rig", "")) in ["skeleton", "skel_guard", "skel_archer"] and float(enemy.hp) > 0:
			for part: String in ["weapon", "leg_l"]:
				if enemy.parts.has(part) and not part in enemy.parts_lost:
					_game.body_parts.set_pending(enemy, part)
					_game._damage_enemy(enemy, float(enemy.parts[part].hp), Vector2.RIGHT, 1)
			enemy.pos = Vector2(_game.players[1].pos) + Vector2(90, 0)
			break
	_game._broadcast_state(true)
	await _wait(40)
	await _shot("02-teile-abgeschlagen.png")
	# 3) A void bomber on its fuse, then its burst (staged next to the hero).
	var bomber: Dictionary = _game._create_enemy("void_bomber", Vector2(_game.players[1].pos) + Vector2(70, -20))
	bomber.shot_timer = 0.0
	_game.enemies.append(bomber)
	await _until(func() -> bool: return str(bomber.get("attack", "")) == "windup", 3.0)
	await _wait(18)
	await _shot("03-leerenbomber-zuendet.png")
	await _until(func() -> bool: return bool(bomber.get("exploded", false)), 3.0)
	await _wait(16)
	await _shot("04-leerenbomber-platzt.png")
	await _leave()
	# 4) Floor 3: the Moderkoloss.
	await _start(_entry("MODERKOLOSS"), "archer")
	_near_boss(func(e: Dictionary) -> bool: return bool(e.get("miniboss", false)), 170.0)
	await _wait(200)
	await _shot("05-ebene3-moderkoloss.png")
	await _leave()
	# 5) Floor 10: the Leerenrufer's beam and summons.
	await _start(_entry("LEERENRUFER"), "mage")
	var boss: Dictionary = _near_boss(func(e: Dictionary) -> bool: return bool(e.boss), 200.0)
	var beam := await _until(func() -> bool: return str(boss.get("attack_kind", "")) == "beam" and str(boss.get("attack", "")) == "active", 25.0)
	await _wait(25)
	await _shot("06-leerenrufer-strahl.png" if beam else "06-leerenrufer.png")
	await _until(func() -> bool: return _game.enemies.any(func(e: Dictionary) -> bool: return bool(e.get("summoned", false))), 25.0)
	await _wait(40)
	await _shot("07-leerenrufer-beschwoerung.png")
	await _leave()
	print("CAPTURE_DONE")
	quit()
