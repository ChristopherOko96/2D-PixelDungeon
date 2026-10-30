extends SceneTree
## Captures the Hell's small monsters as part rigs in the real windowed game
## (assets/data/hell_rigs.json via src/hell/drake_rig_host.gd): per monster
## standing, winding up and striking, its weapon cut off, and falling apart when
## it dies. Each shot also gets a 3x close-up around the monster. The hero is
## kept invulnerable; the run keeps its meta in its own file.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_hell_mob_rigs.gd -- <output_dir> [id,id] [floor]
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const SAVE := "user://capture_hell_mob_rigs.cfg"

var _out := "res://production/qa/evidence/hell-mob-rigs"
var _ids: Array = ["brandskelett"]
var _floor := 1
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _ids = args[1].split(",")
	if args.size() > 2: _floor = int(args[2])
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and is_instance_valid(_game) and not _game.state.is_empty():
			_game.state.inv = 5.0
			_game.state.hp = maxi(int(_game.state.hp), 6)
		await process_frame


func _shot(name: String, focus: Vector2) -> void:
	_game.state.inv = 0.0
	await process_frame
	var image := root.get_texture().get_image()
	var screen: Vector2 = _game.get_viewport().get_canvas_transform() * focus
	var box := Rect2i(Vector2i(clampi(int(screen.x) - 213, 0, image.get_width() - 427), clampi(int(screen.y) - 120, 0, image.get_height() - 240)), Vector2i(427, 240))
	var crop := image.get_region(box)
	crop.resize(1281, 720, Image.INTERPOLATE_NEAREST)
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, crop.save_png(path)])


## A combat room big enough, the hero in its middle, its fight started.
func _fight_room() -> void:
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw >= 12:
			var mid := Vector2((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0) * 96.0)
			var best := INF
			for c: Vector2i in r.cells:
				var p := Vector2((c.x + 0.5) * 96.0, (c.y + 0.8) * 96.0)
				if _game._cell(c.x, c.y) == 1 and p.distance_to(mid) < best and not _game.box_blocked(_game._player_box(p.x, p.y).grow(40)):
					best = p.distance_to(mid)
					_game.player.x = p.x
					_game.player.y = p.y
			_game.camera.position = Vector2(_game.player.x, _game.player.y)
			_game.state.room = r.index
			_game._start_fight(r)
			return


func _find(id: String) -> Dictionary:
	for m: Dictionary in _game.mobs:
		if str(m.id) == id and float(m.hp) > 0.0 and float(m.get("spawn", 0.0)) <= 0.0:
			return m
	return {}


func _focus(m: Dictionary) -> Vector2:
	return _game.drake_rig.centre(m) if _game.drake_rig.has_rig(m) else (m.p as Vector2) - Vector2(0, 40)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = HellScene.instantiate()
	_game.meta_path = SAVE
	_game.start_floor = _floor
	root.add_child(_game)
	current_scene = _game
	await _wait(10)
	_fight_room()
	await _wait(60)
	for id: String in _ids:
		var m := _find(id)
		if m.is_empty():
			# none here: spawn one next to the hero
			m = _game.monsters.spawn(int(_game.state.room), Vector2(_game.player.x + 220.0, _game.player.y), id)
			await _wait(40)
		print("HELL_MOB_RIG %s rig=%s parts=%s" % [id, str(m.get("rig", "")), str((m.get("parts", {}) as Dictionary).keys())])
		# bring the hero close so it attacks
		_game.player.x = float(m.p.x) - 120.0
		_game.player.y = float(m.p.y)
		_game.camera.position = Vector2(_game.player.x, _game.player.y)
		await _shot(id + "-1-steht", _focus(m))
		for k in range(4):
			await _wait(12)
			await _shot("%s-2-angriff-%d" % [id, k], _focus(m))
		var parts: Dictionary = m.get("parts", {})
		if parts.has("weapon"):
			_game.drake_rig.damage(m, float(parts.weapon.hp) + 1.0, "weapon")
			await _wait(3)
			await _shot(id + "-3-waffe-ab", _focus(m))
			await _wait(30)
			await _shot(id + "-4-ohne-waffe", _focus(m))
		var at := _focus(m)
		var head := "skull" if parts.has("skull") else "head"
		_game.drake_rig.damage(m, float(m.hp) + 1.0, head)
		for k in range(5):
			await _wait(8)
			await _shot("%s-5-zerfall-%d" % [id, k], at)
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)
