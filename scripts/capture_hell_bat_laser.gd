extends SceneTree
## Captures the Hell's Blutfledermaus in the real windowed game: flying, aiming
## its pixel laser (the crawling aim line, then locked) and firing it. The hero
## is kept invulnerable; the run keeps its meta in its own file.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_hell_bat_laser.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const SAVE := "user://capture_hell_bat_laser.cfg"
const ID := "blutfledermaus"

var _out := "res://production/qa/evidence/hell-bat-laser"
var _game: Node
var _room: Dictionary = {}


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
	# a 3x close-up of the laser's wall burn while there is one
	if _game.monsters.scorches.is_empty():
		return
	var screen: Vector2 = _game.get_viewport().get_canvas_transform() * (_game.monsters.scorches[0].p as Vector2)
	var box := Rect2i(Vector2i(clampi(int(screen.x) - 213, 0, image.get_width() - 427), clampi(int(screen.y) - 150, 0, image.get_height() - 240)), Vector2i(427, 240))
	var crop := image.get_region(box)
	crop.resize(1281, 720, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join(name + "-nah.png"))


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
			_room = r
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
	# only the bat in the room; the hero near the room's left wall, the bat to its right,
	# so the laser passes the hero and burns into that wall in view
	for o: Dictionary in _game.mobs.duplicate():
		if o.room == int(_game.state.room): _game.mobs.erase(o)
	var row := int(floor(_game.player.y / 96.0))
	var x := int(floor(_game.player.x / 96.0))
	while _game._walkable(_game._cell(x - 1, row)) and x > 0:
		x -= 1
	_game.player.x = (x + 2.2) * 96.0
	var bat_at := Vector2(340.0, -40.0)
	# "lava" (second arg): the hero below the room's lava pool, the bat above it,
	# so the laser crosses the pool (lava is floor that burns, not a wall)
	var pool := Rect2()
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "lava":
		for c: Vector2i in _room.cells:
			if _game._cell(c.x, c.y) == 2:
				var cell := Rect2(c.x * 96.0, c.y * 96.0, 96.0, 96.0)
				pool = cell if not pool.has_area() else pool.merge(cell)
		if pool.has_area():
			_game.player.x = pool.get_center().x - 60.0
			_game.player.y = pool.end.y + 110.0
			bat_at = Vector2(pool.get_center().x + 40.0, pool.position.y - 150.0) - Vector2(_game.player.x, _game.player.y)
	_game.camera.position = Vector2(_game.player.x, _game.player.y)
	await _wait(10)
	var me := Vector2(_game.player.x, _game.player.y)
	var m: Dictionary = _game.monsters.spawn(int(_game.state.room), me + bat_at, ID)
	await _wait(50)
	await _shot("1-fliegt")
	# its laser now: aim, lock, fire
	for i in range(m.st.attacks.size()):
		if str(m.st.attacks[i].kind) == "beam":
			var to: Vector2 = Vector2(_game.player.x, _game.player.y) - m.p
			_game.monsters._start_act(m, i, to, to.length())
	# by the act's own clock (a fresh monster appears first, the act waits for it)
	for step: Array in [[0.3, "2-zielt"], [0.7, "3-gesperrt"], [0.86, "4-schiesst"], [1.05, "5-schiesst"], [1.2, "6-ende"]]:
		var guard := 0
		while m.act != null and float(m.act.t) < float(step[0]) and guard < 600:
			await _wait(1)
			guard += 1
		print("BAT %s act=%s" % [step[1], "none" if m.act == null else "t=%.2f warn=%s" % [float(m.act.t), str(m.act.get("warn", "-"))]])
		await _shot(str(step[1]))
	# the wall burn glowing on after the laser
	await _wait(30)
	await _shot("6b-abgluehen")
	# and it falls apart
	_game.drake_rig.damage(m, float(m.hp) + 1.0, "head")
	await _wait(14)
	await _shot("7-zerfall")
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)
