extends SceneTree
## Captures a Hell boss's attacks in the real windowed game: the boss alone in a
## big combat room, the hero invulnerable in front of it, each attack started in
## turn and shot at fixed points of its own clock (wind-up, strike, aftermath),
## full screen and a 2x close-up around the boss. The run keeps its meta in its
## own file.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_hell_boss_moves.gd -- <output_dir> <boss id> [attack id,attack id]
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const SAVE := "user://capture_hell_boss_moves.cfg"
const TIMES := [0.25, 0.42, 0.55, 0.8, 0.9, 1.0, 1.15, 1.3, 1.7, 2.2, 2.8, 3.4]

var _out := "res://production/qa/evidence/hell-boss-moves"
var _id := "glutwaechter"
var _only: Array = []
var _boss := true
var _hit := false
## Frames the hero stays untouchable while the scene is set up (hit mode).
var _hold := 0
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _id = args[1]
	if args.size() > 2 and args[2] != "all": _only = args[2].split(",")
	# "mob" as 4th argument: the monster as a regular one (its lighter game feel)
	if args.size() > 3: _boss = args[3] != "mob"
	# "hit" as 5th argument: the hero can be hit (knockback, hurt feel); he never dies
	if args.size() > 4: _hit = args[4] == "hit"
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and is_instance_valid(_game) and not _game.state.is_empty():
			if not _hit or _hold > 0:
				_game.state.inv = 5.0
			_game.state.hp = maxi(int(_game.state.hp), 6)
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


## A big combat room, the hero in its middle, its fight started; its monsters gone.
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
	var m: Dictionary = _game.monsters.spawn(int(_game.state.room), me + Vector2(260.0, -40.0), _id, _boss)
	m.cds = m.cds.map(func(_c: Variant) -> float: return 99.0)
	_hold = 1
	await _wait(70)
	for i in range(m.st.attacks.size()):
		var a: Dictionary = m.st.attacks[i]
		if not _only.is_empty() and not str(a.id) in _only: continue
		if str(a.kind) == "trail": continue
		_game.player.x = me.x
		_game.player.y = me.y
		_hold = 1
		await _wait(20)
		var to: Vector2 = Vector2(_game.player.x, _game.player.y) - m.p
		_game.monsters._start_act(m, i, to, to.length())
		if _hit:
			_hold = 0
			_game.state.inv = 0.0
		print("MOVE %s %s act=%s" % [a.id, a.kind, str(m.act != null)])
		var focus: Vector2 = (m.p + Vector2(_game.player.x, _game.player.y)) * 0.5
		for t: float in TIMES:
			var guard := 0
			while m.act != null and float(m.act.t) < t and guard < 400:
				await _wait(1)
				guard += 1
			if m.act == null:
				await _wait(int((t - TIMES[0]) * 20.0))
			await _shot("%s-%s-%.2f" % [_id, a.id, t], focus)
		while m.act != null:
			await _wait(1)
		m.cds = m.cds.map(func(_c: Variant) -> float: return 99.0)
		await _wait(60)
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)
