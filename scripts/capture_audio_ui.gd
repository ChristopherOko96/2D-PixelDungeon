extends SceneTree
## Captures the audio screens from the real windowed game: the options with
## the three volume sliders, and the Klangwerkstatt (debug menu) with a
## skeleton sound and the music states. Also prints the music state during a
## run (menu, then the fight). Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_audio_ui.gd -- <output_dir>
const Game = preload("res://src/game.gd")

var _out := "res://production/qa/evidence/audio-mix"
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


func _entry(label: String) -> Dictionary:
	for entry: Dictionary in _game.main_menu.debug_entries:
		if str(entry.label).contains(label): return entry
	return {}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(40)
	print("MUSIC menu state=%s track=%s" % [_game.view._music.state, _game.view._music.track])
	_game.main_menu._open_options()
	await _shot("01-optionen-lautstaerke")
	_game.main_menu._close_panels()
	_game.main_menu.open_sound_workshop()
	var workshop: Control = _game.main_menu.sound_workshop
	workshop.select("hit_bone")
	workshop._pack.select(workshop._pack_ids.find("bones"))
	workshop._fill_library()
	await _shot("02-klangwerkstatt-skelett")
	workshop.select("music:combat")
	await _shot("03-klangwerkstatt-musik")
	workshop.close()
	await _wait(10)
	_game.requested_seed = 4242
	_game.main_menu._pick_debug(_entry("RAUM 02"))
	_game.main_menu._choose_class("swordsman")
	await _wait(120)
	print("MUSIC run state=%s track=%s ambience=%s" % [_game.view._music.state, _game.view._music.track, _game.view._music._ambience_on])
	await _shot("04-kampf-mit-musik")
	_game._leave_session()
	await _wait(10)
	quit(0)
