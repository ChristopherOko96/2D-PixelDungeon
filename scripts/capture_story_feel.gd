extends SceneTree
## Captures the crypt's game feel in the story worlds (src/hero/story_feel.gd,
## docs/VFX-SYSTEM.de.md) from the real windowed game: in the Frostgruft and the
## Hell-Dungeon the archer fights a room: hits (flash, squash, sparks, drops),
## kills (burst, pool, the fall of a felled monster), the floor afterwards, the
## hero hurt (red flash, blood, shake).
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_story_feel.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const SAVE := "user://capture_story_feel.cfg"

var _out := "res://production/qa/evidence/vfx-story-feel"
var _game: Node
var _safe := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty() and _safe:
			_game.state.inv = 99.0
			_game.state.hp = maxi(_game.state.hp, 6)
		await process_frame


## Saves the frame; with `focus` (a world point) also a 2x close-up around it.
## The hero's invulnerability blink is switched off for the frame.
func _shot(name: String, focus := Vector2.INF) -> void:
	if _game != null and _safe:
		_game.state.inv = 0.0
	await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])
	if focus.is_finite() and _game != null:
		var screen: Vector2 = _game.get_viewport().get_canvas_transform() * focus
		var box := Rect2i(Vector2i(clampi(int(screen.x) - 240, 0, image.get_width() - 480), clampi(int(screen.y) - 150, 0, image.get_height() - 270)), Vector2i(480, 270))
		var crop := image.get_region(box)
		crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
		var close := _out.path_join(name + "-nah.png")
		print("CAPTURED %s result=%d" % [close, crop.save_png(close)])


func _fight_room() -> void:
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw >= 20:
			var mid := Vector2(r.bx + r.bw / 2.0, r.by + r.bh / 2.0)
			var best: Vector2i = r.cells[0]
			for c: Vector2i in r.cells:
				if _game.W.grid[c.y * _game.W.cols + c.x] == 1 and Vector2(c).distance_to(mid) < Vector2(best).distance_to(mid):
					best = c
			_game.player.x = (best.x + 0.5) * 96.0
			_game.player.y = (best.y + 0.8) * 96.0
			_game.camera.position = Vector2(_game.player.x, _game.player.y)
			_game.state.room = r.index
			_game._start_fight(r)
			return


func _foe() -> Dictionary:
	for m: Dictionary in _game.mobs:
		if float(m.get("spawn", 0.0)) <= 0.0 and float(m.hp) > 0.0:
			return m
	return {}


## Living foes on screen.
func _in_view() -> Array:
	var me := Vector2(_game.player.x, _game.player.y)
	return _game.mobs.filter(func(m: Dictionary) -> bool: return float(m.get("spawn", 0.0)) <= 0.0 and float(m.hp) > 0.0 and absf((m.p as Vector2).x - me.x) < 600.0 and absf((m.p as Vector2).y - me.y) < 330.0)


## A hit's push from the hero towards `m`.
func _push(m: Dictionary) -> Vector2:
	return ((m.p as Vector2) - Vector2(_game.player.x, _game.player.y)).normalized() * 600.0


func _shoot(frames: int) -> void:
	for i in range(frames):
		var m := _foe()
		if not m.is_empty():
			_game.state.cool = 0.0
			_game._fire((((m.p as Vector2) - Vector2(0, m.cy)) - Vector2(_game.player.x, _game.player.y - 40)).normalized())
		await _wait(1)


func _world(scene: PackedScene, prefix: String) -> void:
	_game = scene.instantiate()
	_game.class_id = "archer"
	_game.start_floor = 2
	_game.meta_path = SAVE
	root.add_child(_game)
	await _wait(5)
	_game.state.offer = []
	_fight_room()
	await _wait(100)
	await _shoot(16)
	_game.shots.clear()
	await _wait(30)
	# hits: the foes in view flash red, squash, lean and spray drops
	var foes := _in_view()
	foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.p as Vector2).distance_to(Vector2(_game.player.x, _game.player.y)) < (b.p as Vector2).distance_to(Vector2(_game.player.x, _game.player.y)))
	var focus: Vector2 = (foes[0].p as Vector2) - Vector2(0, 40) if not foes.is_empty() else Vector2.INF
	for m: Dictionary in foes:
		_game._damage_mob(m, _push(m))
	await _wait(1)
	await _shot(prefix + "-1-treffer", focus)
	await _wait(40)
	# kills: the picture holds, they burst in their material and fall
	for m: Dictionary in _in_view():
		m.hp = 0.01
		_game._damage_mob(m, _push(m))
	await _wait(3)
	await _shot(prefix + "-2-tod", focus)
	# the floor afterwards: pools and chips where they fell
	for m: Dictionary in _game.mobs:
		m.hp = 0.0
	_game.shots.clear()
	await _wait(90)
	_game.state.toasts = []
	await _wait(40)
	await _shot(prefix + "-3-boden", focus)
	# the hero is hurt: red flash, blood and a splat, shake
	_safe = false
	_game.state.inv = 0.0
	_game.state.hp = int(_game.state.max_hp)
	_game._hurt("Test", 1)
	await _wait(2)
	await _shot(prefix + "-4-held-getroffen", Vector2(_game.player.x, _game.player.y - 40))
	_safe = true
	_game.queue_free()
	_game = null
	await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _world(FrostScene, "frost")
	await _world(HellScene, "hoelle")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()
