extends SceneTree
## Captures the debug cheats in the real windowed game: the ESC menu's Cheats
## page, and the skill bar of each class after "ALLE FÄHIGKEITEN".
## Usage: godot --path . --resolution 1280x720 -s res://scripts/capture_cheats.gd -- <output_dir>
const Game = preload("res://src/game.gd")

var _out := "res://production/qa/evidence/cheats"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames): await process_frame


func _shot(name: String) -> void:
	await _wait(3)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


func _cheat(id: String) -> void:
	_game.action_times.clear()
	_game._send_action("cheat", Array(_game.cheats.order()).find(id))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	_game.player_classes[1] = "swordsman"
	_game._start_solo()
	await _wait(60)
	_game.hordes.enabled = false
	_game.enemies.clear()
	_cheat("god")
	_game.set_pause_open(true)
	await _wait(10)
	_game.pause_menu.select_section("cheats")
	await _wait(4)
	await _shot("01-esc-menue-cheats")
	_game.set_pause_open(false)
	for entry: Array in [["swordsman", "02-schwertkaempfer-alle-faehigkeiten"], ["archer", "03-bogenschuetze-alle-faehigkeiten"], ["mage", "04-magier-alle-faehigkeiten"]]:
		var hero: Dictionary = _game.players[1]
		_game.player_classes[1] = str(entry[0])
		_game.HeroClass.apply(hero, str(entry[0]), _game.balance)
		_game.inventory.start_kit(hero)
		_cheat("all_skills")
		await _wait(30)
		await _shot(str(entry[1]))
	_game._leave_session()
	await _wait(10)
	quit(0)
