extends SceneTree
## Captures the Frostgruft monsters from the real windowed game: a still lineup
## of every kind in one room, a live fight on floor 6, and the guardians of
## floors 3, 6, 9 and 10. The hero is kept at full hearts.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_monsters.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const KINDS := ["ice_zombie", "frost_skeleton", "ice_slime", "ice_slime_m", "ice_slime_s", "frost_imp", "frost_whirl", "ice_knight", "ice_crystal"]

var _out := "res://production/qa/evidence/frost-floors"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 0.0
			_game.state.hp = _game.state.max_hp
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


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
	# lineup: every kind side by side, frozen so nobody moves or shoots
	await _start(7)
	var r := _big_room()
	r.cleared = true
	var cx: float = (r.bx + r.bw / 2.0) * 96.0
	var cy: float = (r.by + r.bh / 2.0) * 96.0
	_game.player.x = cx - 520.0
	_game.player.y = cy + 120.0
	_game.camera.position = Vector2(cx, cy)
	for i in range(KINDS.size()):
		_game._spawn_mob(r.index, Vector2(cx - 400.0 + i * 110.0, cy), KINDS[i])
		_game.mobs[i].spawn = 0.0
		_game.mobs[i].face = Vector2.LEFT
	await _wait(1)
	_game.set_process(false)
	_game.actors.queue_redraw()
	_game.dark.queue_redraw()
	_game.hud.queue_redraw()
	await _shot("30-spiel-monster-aufstellung.png")
	_game.set_process(true)
	# a live fight on floor 6
	await _start(6)
	r = _big_room()
	_game.player.x = (r.bx + r.bw / 2.0 - 3.0) * 96.0
	_game.player.y = (r.by + r.bh / 2.0 + 0.8) * 96.0
	_game.camera.position = Vector2(_game.player.x, _game.player.y)
	await _wait(150)
	print("FIGHT kinds=%s" % [_game.mobs.map(func(m: Dictionary) -> String: return m.kind)])
	await _shot("31-spiel-monster-kampf-etage6.png")
	# guardians
	for n: int in [3, 6, 9, 10]:
		await _start(n)
		var b: Dictionary = {}
		for room: Dictionary in _game.W.rooms:
			if room.type == "boss":
				b = room
		_game.state.boss_dead = false
		# the guardian rises in the middle of its hall; the hero stands a few steps below
		_game.player.x = (b.bx + b.bw / 2.0) * 96.0
		_game.player.y = (b.by + b.bh / 2.0 + 4.0) * 96.0
		_game.camera.position = Vector2(_game.player.x, _game.player.y - 200.0)
		_game.state.room = b.index
		_game._start_fight(b)
		await _wait(45)
		await _shot("%d-spiel-waechter-etage%02d.png" % [31 + [3, 6, 9, 10].find(n) + 1, n])
	quit()
