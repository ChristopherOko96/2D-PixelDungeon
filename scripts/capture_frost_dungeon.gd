extends SceneTree
## Captures evidence of Story 2, the Frostgruft, from the real windowed game:
## floor 1 start room, a locked combat room, the key chest of the key room
## before and after opening, the big map, glaze ice on floor 5 and the deepest
## floor. The hero is kept at full hearts.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_dungeon.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")

var _out := "res://production/qa/evidence/frost-floors"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		# full hearts instead of invulnerability: the invulnerable hero blinks and can miss the shot
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 0.0
			_game.state.hp = _game.state.max_hp
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _go(x: float, y: float) -> void:
	_game.player.x = x
	_game.player.y = y
	_game.camera.position = Vector2(x, y)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = FrostScene.instantiate()
	root.add_child(_game)
	await _wait(40)
	await _shot("10-spiel-etage1-start.png")
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw >= 20 and not r.on_path == false:
			_go((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0 + 0.8) * 96.0)
			break
	await _wait(90)
	print("FIGHT mobs=%d" % _game.mobs.size())
	await _shot("11-spiel-kampf-verriegelt.png")
	for m: Dictionary in _game.mobs:
		m.hp = 0.0
	await _wait(30)
	var chest: Dictionary = {}
	for e: Dictionary in _game.W.ents:
		if e.type == "chest" and e.get("loot", {}).has("key"):
			chest = e
	_game.W.rooms[chest.room].cleared = true
	_go(chest.x, chest.y + 90.0)
	await _wait(60)
	await _shot("12-spiel-schluesseltruhe.png")
	_game.act()
	await _wait(20)
	print("KEY %s=%s" % [chest.loot.key, _game.state.keys[chest.loot.key]])
	await _shot("13-spiel-schluessel-genommen.png")
	for r: Dictionary in _game.W.rooms:
		_game.state.visited[r.index] = true
	_game.state.map = true
	await _wait(5)
	await _shot("14-spiel-karte.png")
	_game.state.map = false
	_game.load_floor(5, false)
	await _wait(5)
	var best := Vector2i(-1, -1)
	for y in range(_game.W.rows):
		for x in range(_game.W.cols):
			if best.x < 0 and _game.W.grid[y * _game.W.cols + x] == 2 and _game.W.room_at[y * _game.W.cols + x] >= 0:
				best = Vector2i(x, y)
	var room: Dictionary = _game.W.rooms[_game.W.room_at[best.y * _game.W.cols + best.x]]
	room.cleared = true
	_go((best.x + 0.5) * 96.0, (best.y + 0.6) * 96.0)
	await _wait(90)
	await _shot("15-spiel-etage5-glatteis.png")
	_game.load_floor(10, false)
	await _wait(5)
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw >= 20:
			r.cleared = true
			_go((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0 + 0.9) * 96.0)
			break
	await _wait(90)
	await _shot("16-spiel-etage10.png")
	quit()
