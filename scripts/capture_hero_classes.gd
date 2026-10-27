extends SceneTree
## Captures step 2 evidence from the real windowed game: the hero choice, each
## class's basic attack and the multiplayer lobby's class button. The attack
## shots are STAGED (an enemy is moved next to the hero and one attack is
## triggered); they show presentation, not a played run. Usage:
##   godot --path . -s res://scripts/capture_hero_classes.gd -- <output_dir>
const Game = preload("res://src/game.gd")

var _out := "res://production/qa/evidence/hero-classes-step2"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()

func _wait(frames: int) -> void:
	for i in range(frames): await process_frame

func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])

## Starts a solo story run with `class_id` and freezes the world simulation so
## staged scenes stay put; presentation keeps animating.
func _start(game: Node, class_id: String) -> void:
	game.main_menu._open_classes(false)
	game.main_menu._choose_class(class_id)
	game.set_physics_process(false)
	await _wait(20)

## Moves the first living enemy to `offset` from the hero and clears bullets.
func _stage_enemy(game: Node, offset: Vector2) -> Dictionary:
	var player: Dictionary = game.players[1]
	for enemy: Dictionary in game.enemies:
		if enemy.hp > 0:
			enemy.pos = player.pos + offset
			enemy.hp = enemy.max_hp
			game.bullets.clear()
			return enemy
	return {}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var game = Game.new()
	root.add_child(game)
	game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	game.main_menu._open_classes(false)
	await _wait(20)
	await _shot("01-heldenwahl.png")
	game.main_menu._close_panels()
	# Swordsman: one swing at an enemy in front.
	await _start(game, "swordsman")
	_stage_enemy(game, Vector2(56, 0))
	game.players[1].aim = Vector2.RIGHT
	game.perk_combat.melee(1, Vector2.RIGHT)
	game._broadcast_state(true)
	await _wait(4)
	await _shot("02-schwertkaempfer-hieb.png")
	game._leave_session()
	await _wait(5)
	# Archer: a few arrows in flight toward an enemy.
	await _start(game, "archer")
	_stage_enemy(game, Vector2(260, 0))
	game.players[1].aim = Vector2.RIGHT
	for volley in range(3):
		game.perk_combat.shoot(1, Vector2.RIGHT)
		game._simulate_bullets(0.07)
	game._broadcast_state(true)
	await _wait(3)
	await _shot("03-bogenschuetze-pfeile.png")
	game._leave_session()
	await _wait(5)
	# Mage: an orb in flight, then its burst at the enemy.
	await _start(game, "mage")
	_stage_enemy(game, Vector2(150, 0))
	game.players[1].aim = Vector2.RIGHT
	game.perk_combat.shoot(1, Vector2.RIGHT)
	game._simulate_bullets(0.15)
	game._broadcast_state(true)
	await _wait(3)
	await _shot("04-magier-kugel.png")
	for step in range(10):
		if game.bullets.is_empty(): break
		game._simulate_bullets(0.05)
	game._broadcast_state(true)
	await _wait(2)
	await _shot("05-magier-explosion.png")
	game._leave_session()
	await _wait(5)
	# Multiplayer lobby with the class button.
	game.main_menu.multiplayer_requested.emit()
	game._host_session()
	game._refresh_ui()
	await _wait(10)
	await _shot("06-lobby-klassenwahl.png")
	quit(0)
