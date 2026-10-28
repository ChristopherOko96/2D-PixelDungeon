extends SceneTree
## Captures evidence of the Hell-Dungeon mode from the real windowed game:
## floor 1 start room, a locked combat room, the big map, the vault on floor 2
## and a deep floor (10) with its red grade. The hero is kept invulnerable.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_hell_dungeon.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")

var _out := "res://production/qa/evidence/hell-dungeon"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 5.0
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _go(room: Dictionary, lx: float, ly: float) -> void:
	_game.player.x = (room.bx + lx) * 96.0
	_game.player.y = (room.by + ly) * 96.0
	_game.camera.position = Vector2(_game.player.x, _game.player.y)


func _room(kind: String) -> Dictionary:
	for r: Dictionary in _game.W.rooms:
		if r.type == kind or r.get("name", "") == kind:
			return r
	return {}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = HellScene.instantiate()
	root.add_child(_game)
	await _wait(40)
	await _shot("01-etage1-eingang.png")
	var hall := _room("Säulenhalle")
	_go(hall, 13.0, 6.9)
	await _wait(90)
	print("FIGHT hall=%s mobs=%d" % [hall.fight, _game.mobs.size()])
	await _shot("02-etage1-kampf-verriegelt.png")
	for m: Dictionary in _game.mobs:
		m.hp = 0.0
	await _wait(30)
	print("CLEARED hall=%s" % hall.cleared)
	for r: Dictionary in _game.W.rooms:
		_game.state.visited[r.index] = true
	_game.state.map = true
	await _wait(5)
	await _shot("03-etage1-karte.png")
	_game.state.map = false
	_game.load_floor(2, false)
	await _wait(5)
	_game.W.groups.feuer.solved = true
	for e: Dictionary in _game.W.ents:
		if e.type == "vault":
			var r: Dictionary = _game.W.rooms[e.room]
			r.cleared = true
			_game.player.x = e.x - 160.0
			_game.player.y = e.y + 140.0
			_game.camera.position = Vector2(_game.player.x, _game.player.y)
	await _wait(90)
	await _shot("04-etage2-riesentresor.png")
	_game.load_floor(10, false)
	await _wait(5)
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw >= 20:
			r.cleared = true
			_go(r, r.bw / 2.0, r.bh / 2.0 + 0.9)
			break
	await _wait(90)
	await _shot("05-etage10-tiefe.png")
	print("HELL_CAPTURE done")
	quit(0)
