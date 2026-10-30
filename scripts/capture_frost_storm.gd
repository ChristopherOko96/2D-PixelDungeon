extends SceneTree
## Captures the Frostgruft's weather from the real windowed game (src/vfx/snowstorm.gd): the start
## room in calm weather (light snow, the steady wind's lines from the right), then the same view
## at the height of a snowstorm (started at once, not waited for).
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_storm.gd -- <output_dir> [pixel|hd]
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const GRAPHICS_FILE := "user://capture_frost_storm.cfg"

var _out := "res://production/qa/evidence/frost-wetter/hd"
var _graphics := "hd"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_graphics = args[1]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 0.0
			_game.state.hp = _game.state.max_hp
			_game.state.banner.t = 99.0
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var cfg := ConfigFile.new()
	cfg.set_value("options", "graphics", _graphics)
	cfg.save(GRAPHICS_FILE)
	_game = FrostScene.instantiate()
	_game.class_id = "swordsman"
	_game.graphics_path = GRAPHICS_FILE
	root.add_child(_game)
	await _wait(10)
	_game.state.world_run = 4242
	_game.load_floor(1, true)
	for r: Dictionary in _game.W.rooms:
		r.fight = false
		r.cleared = true
	_game.mobs = []
	await _wait(90)
	_shot("01-ruhig-wind")
	_game.snowstorm.start_storm(40.0)
	# past the storm's rise (storm_ramp s) at the frame rate the window runs at
	var until := Time.get_ticks_msec() + int(float(_game.snowstorm.cfg.storm_ramp) * 1000.0) + 1500
	while Time.get_ticks_msec() < until:
		await _wait(1)
	print("STORM strength=%.2f wind=%.0f" % [_game.snowstorm.storm(), _game.snowstorm.wind().x])
	_shot("02-schneesturm")
	quit()
