extends SceneTree
## Captures the Hell's void beams in the real windowed game: Ignaroth in his
## last form (drache4) spawned in a big combat room beside the hero, his
## "strahlen" (three void beams turning through the room) forced and shot as
## they burn. The hero is kept invulnerable; the run keeps its meta in its own
## file (removed after), never the player's.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_hell_void_beam.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const SAVE := "user://capture_hell_void_beam.cfg"
const ID := "drache4"

var _out := "res://production/qa/evidence/void/fein/hoelle"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and is_instance_valid(_game) and not _game.state.is_empty():
			_game.state.inv = 5.0
			_game.state.hp = maxi(int(_game.state.hp), 6)
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


## A big combat room, the hero in its middle, its fight started.
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


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = HellScene.instantiate()
	_game.meta_path = SAVE
	_game.start_floor = 1
	root.add_child(_game)
	current_scene = _game
	await _wait(10)
	_fight_room()
	await _wait(30)
	for o: Dictionary in _game.mobs.duplicate():
		if o.room == int(_game.state.room): _game.mobs.erase(o)
	var me := Vector2(_game.player.x, _game.player.y)
	var m: Dictionary = _game.monsters.spawn(int(_game.state.room), me + Vector2(330.0, -60.0), ID)
	# until he has arrived
	var guard := 0
	while (m.get("intro") != null or float(m.get("spawn", 0.0)) > 0.0) and guard < 900:
		await _wait(1)
		guard += 1
	await _wait(20)
	for i in range(m.st.attacks.size()):
		if str(m.st.attacks[i].get("id", "")) == "strahlen":
			var to: Vector2 = Vector2(_game.player.x, _game.player.y) - m.p
			_game.monsters._start_act(m, i, to, to.length())
	for step: Array in [[1.0, "1-strahlen-1.0"], [1.6, "2-strahlen-1.6"], [2.4, "3-strahlen-2.4"]]:
		guard = 0
		while m.act != null and float(m.act.t) < float(step[0]) and guard < 900:
			await _wait(1)
			guard += 1
		print("BEAM %s act=%s" % [step[1], "none" if m.act == null else "%s t=%.2f" % [str(m.act.a.get("id", "?")), float(m.act.t)]])
		await _shot(str(step[1]))
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)
