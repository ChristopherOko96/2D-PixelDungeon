extends SceneTree
## Captures the Frostgruft's enemies as part rigs (src/hell/frost_rigs.gd) in
## the real windowed game: every kind side by side walking up to the hero,
## attacking, hit, and felled; then the ten guardians in two rows of five.
## Full screen and a 2x close-up per shot. The hero cannot be hurt; the run
## writes no meta (a SceneTree script with the default meta path, hell_game.gd).
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_rigs.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const KINDS := ["ice_zombie", "frost_skeleton", "ice_slime", "ice_slime_m", "ice_slime_s", "frost_imp", "frost_whirl", "ice_knight", "ice_crystal"]

var _out := "res://production/qa/evidence/frost-rigs"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and is_instance_valid(_game) and not _game.state.is_empty():
			_game.state.inv = 5.0
			_game.state.hp = _game.state.max_hp
		await process_frame


func _shot(name: String, focus: Vector2) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])
	var screen: Vector2 = _game.get_viewport().get_canvas_transform() * focus
	var box := Rect2i(Vector2i(clampi(int(screen.x) - 320, 0, image.get_width() - 640), clampi(int(screen.y) - 180, 0, image.get_height() - 360)), Vector2i(640, 360))
	var crop := image.get_region(box)
	crop.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join(name + "-nah.png"))


func _big_room() -> Dictionary:
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw >= 20:
			return r
	return {}


func _start(floor_n: int) -> void:
	if _game != null:
		_game.queue_free()
		await process_frame
	_game = FrostScene.instantiate()
	_game.class_id = "mage"
	_game.start_floor = floor_n
	root.add_child(_game)
	await _wait(5)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _start(7)
	var r := _big_room()
	r.cleared = true
	var mid := Vector2((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0) * 96.0)
	_game.player.x = mid.x
	_game.player.y = mid.y + 260.0
	await _wait(20)
	for i in range(KINDS.size()):
		_game._spawn_mob(r.index, mid + Vector2(-560.0 + i * 140.0, -120.0), KINDS[i])
	print("RIGS ", _game.mobs.map(func(m: Dictionary) -> String: return "%s=%s" % [m.kind, _game.frost_rigs.rig_of(m)]))
	await _wait(40)
	await _shot("01-stehen", mid)
	await _wait(25)
	await _shot("02-laufen", mid + Vector2(0, 80))
	await _wait(60)
	await _shot("03-angriff", mid + Vector2(0, 150))
	# every one hit once
	for m: Dictionary in _game.mobs.duplicate():
		_game._damage_mob(m, Vector2.RIGHT * 20.0)
	await _wait(3)
	await _shot("04-getroffen", Vector2(_game.player.x, _game.player.y - 120.0))
	# every one felled
	for m: Dictionary in _game.mobs.duplicate():
		m.hp = 0.01
		_game._damage_mob(m, Vector2.RIGHT * 20.0)
	await _wait(6)
	await _shot("05-fallen", Vector2(_game.player.x, _game.player.y - 120.0))
	await _wait(18)
	await _shot("06-zerfallen", Vector2(_game.player.x, _game.player.y - 120.0))
	# the guardians of floors 1-5 and 6-10, each with its floor's look and kit
	for row in range(2):
		await _start(10)
		r = _big_room()
		r.cleared = true
		mid = Vector2((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0) * 96.0)
		_game.player.x = mid.x
		_game.player.y = mid.y + 300.0
		await _wait(20)
		for k in range(5):
			_game.state.floor = row * 5 + k + 1
			_game._spawn_mob(r.index, mid + Vector2(-680.0 + k * 340.0, -60.0), "boss")
		_game.state.floor = 10
		await _wait(40)
		await _shot("%02d-waechter-%d-%d" % [10 + row * 2, row * 5 + 1, row * 5 + 5], mid)
		await _wait(70)
		await _shot("%02d-waechter-%d-%d-angriff" % [11 + row * 2, row * 5 + 1, row * 5 + 5], mid)
	_game.queue_free()
	await process_frame
	quit(0)
