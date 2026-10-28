extends SceneTree
## Captures evidence of the Delve Disaster UI from the real windowed game:
## title screen, hero choice, options, multiplayer lobby (before and after
## hosting), the run HUD in a normal room and in the floor 3 mini-boss and
## floor 10 boss rooms, the pause menu and the reward cards. Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_ui.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

var _out := "res://production/qa/evidence/ui-delve-disaster"
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
	await _wait(3)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])

func _entry(label: String) -> Dictionary:
	for entry: Dictionary in _game.main_menu.debug_entries:
		if str(entry.label).contains(label): return entry
	return {}

func _start(entry: Dictionary, class_id: String) -> void:
	_game.requested_seed = 4242
	_game.main_menu._pick_debug(entry)
	_game.main_menu._choose_class(class_id)
	await _wait(30)

## Staged: the hero stands in clear sight of the first enemy matching `which`.
func _near(which: Callable, distance: float) -> void:
	for enemy: Dictionary in _game.enemies:
		if not which.call(enemy): continue
		for offset: Vector2 in [Vector2(-1, 0.2), Vector2(1, 0.2), Vector2(0, 1), Vector2(0, -1)]:
			var spot: Vector2 = Vector2(enemy.pos) + offset * distance
			if not Dungeon.segment_blocked(enemy.pos, spot, 14.0, _game.current_layout):
				_game.players[1].pos = spot
				return
		return

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(40)
	await _shot("01-hauptmenue.png")
	_game.main_menu._open_classes(false)
	await _wait(20)
	await _shot("02-heldenwahl.png")
	_game.main_menu._open_options()
	await _wait(10)
	await _shot("03-optionen.png")
	_game.main_menu._close_panels()
	_game.main_menu.multiplayer_requested.emit()
	await _wait(20)
	await _shot("04-lobby.png")
	_game._host_session()
	await _wait(40)
	await _shot("05-lobby-gehostet.png")
	_game._leave_session()
	await _wait(20)
	# Run HUD in a normal room: some damage so half hearts show.
	await _start(_entry("RAUM 02"), "archer")
	_game.players[1].hp = 5
	await _wait(90)
	await _shot("06-hud-raum.png")
	_game.set_pause_open(true, "overview")
	await _wait(15)
	await _shot("07-pause.png")
	_game.set_pause_open(false)
	# Reward cards: clear the room by hand.
	for enemy: Dictionary in _game.enemies: enemy.hp = 0.0
	await _wait(120)
	if _game.reward_overlay.visible: await _shot("08-belohnung.png")
	_game._leave_session()
	await _wait(20)
	# Mini-boss and boss rooms: the top bar with the name.
	await _start(_entry("MODERKOLOSS"), "swordsman")
	_near(func(e: Dictionary) -> bool: return bool(e.get("miniboss", false)), 260.0)
	await _wait(120)
	for enemy: Dictionary in _game.enemies:
		if bool(enemy.get("miniboss", false)): enemy.hp = float(enemy.max_hp) * 0.62
	await _wait(60)
	await _shot("09-hud-nebenboss.png")
	_game._leave_session()
	await _wait(20)
	await _start(_entry("LEERENRUFER"), "mage")
	_near(func(e: Dictionary) -> bool: return bool(e.get("boss", false)), 300.0)
	await _wait(150)
	await _shot("10-hud-endboss.png")
	_game._leave_session()
	await _wait(10)
	quit(0)
