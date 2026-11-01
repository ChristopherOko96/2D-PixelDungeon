extends SceneTree
## Captures the gold (src/hell/gold_loot.gd) from the real windowed game, in one world and one
## graphics set: a chest with 23 gold (2 bags, 3 coins) opening beside the hero, its gold in the
## air and lying, a slain enemy's '+1' rising, and the HUD's gold row. Each picture is the frame's
## centre, enlarged 2x with nearest filtering.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_gold_loot.gd -- <output_dir> <frost|hell|krypta> [hd|pixel]
const SCENES := {"frost": "res://src/hell/frost_dungeon.tscn", "hell": "res://src/hell/hell_dungeon.tscn", "krypta": "res://src/hell/krypta_dungeon.tscn"}
const GRAPHICS_FILE := "user://capture_gold_loot.cfg"

var _out := "res://production/qa/evidence/gold-loot"
var _world := "frost"
var _graphics := "hd"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_world = args[1]
	if args.size() > 2:
		_graphics = args[2]
	_run.call_deferred()


func _hold() -> void:
	if _game != null and not _game.state.is_empty():
		_game.state.inv = 0.0
		_game.state.hp = _game.state.max_hp
		_game.state.banner.t = 99.0


## Waits `seconds` of real time (the game runs on).
func _wait_s(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		_hold()
		await process_frame


func _shot(name: String, at: Vector2, full := false) -> void:
	var image := root.get_texture().get_image()
	if not full:
		var zoom: Vector2 = _game.camera.zoom
		var c: Vector2 = (at - _game.camera.get_screen_center_position()) * zoom + Vector2(image.get_width(), image.get_height()) / 2.0
		var r := Rect2i(Vector2i(c - Vector2(240, 150)), Vector2i(480, 300))
		r.position = r.position.clamp(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height()) - r.size)
		image = image.get_region(r)
		image.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join("%s-%s-%s.png" % [_world, _graphics, name]))])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var cfg := ConfigFile.new()
	cfg.set_value("options", "graphics", _graphics)
	cfg.save(GRAPHICS_FILE)
	_game = (load(SCENES[_world]) as PackedScene).instantiate()
	_game.class_id = "swordsman"
	_game.graphics_path = GRAPHICS_FILE
	root.add_child(_game)
	await _wait_s(0.3)
	_game.state.world_run = 4242
	_game.load_floor(1, true)
	await _wait_s(0.5)
	for r: Dictionary in _game.W.rooms:
		r.fight = false
		r.cleared = true
	_game.mobs = []
	# a chest with 23 gold beside the hero; once it is open the hero steps back, out of the magnet
	var hero := Vector2(_game.player.x, _game.player.y)
	var chest := {"type": "chest", "x": hero.x, "y": hero.y - 30.0, "room": int(_game.state.room), "loot": {"gems": 23}}
	_game.W.ents.append(chest)
	_game.act()
	_game.player.y = hero.y + 260.0
	await _wait_s(0.22)
	_shot("01-auswurf", Vector2(chest.x, chest.y - 20))
	await _wait_s(1.3)
	_shot("02-gelandet", Vector2(chest.x, chest.y))
	# a slain enemy's gold
	_game.gold_loot.kill_popup(Vector2(chest.x + 150, chest.y + 40), 1)
	await _wait_s(0.3)
	_shot("03-kill-plus-eins", Vector2(chest.x + 150, chest.y))
	# the hero walks into the gold: taken, '+N' over him, the HUD's gold row
	_game.player.y = chest.y + 30.0
	await _wait_s(0.5)
	_shot("04-aufgesammelt", Vector2(_game.player.x, _game.player.y - 60), true)
	quit()
