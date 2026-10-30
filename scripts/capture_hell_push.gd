extends SceneTree
## Captures the hell's pressure fronts and lava in the real windowed game:
## 1) the Klagender Hüter's scream running through floor embers and rubble
##    (they are shoved along with the sound, pixel for pixel),
## 2) a lava pool sloshing over its rim (drops that land as embers and cool),
## 3) a shockwave crossing the pool (lava thrown out along it).
## Full screen and a 2x close-up per shot. The run keeps its meta in its own file.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_hell_push.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const SAVE := "user://capture_hell_push.cfg"

var _out := "res://production/qa/evidence/hell-push"
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


func _wait_s(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await _wait(1)


func _shot(name: String, focus: Vector2) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])
	var screen: Vector2 = _game.get_viewport().get_canvas_transform() * focus
	var box := Rect2i(Vector2i(clampi(int(screen.x) - 320, 0, image.get_width() - 640), clampi(int(screen.y) - 180, 0, image.get_height() - 360)), Vector2i(640, 360))
	var crop := image.get_region(box)
	crop.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join(name + "-nah.png"))


## A big combat room with a lava pool, the hero in its middle, its fight started; its monsters gone.
func _fight_room() -> Dictionary:
	for r: Dictionary in _game.W.rooms:
		if r.type != "combat" or r.bw < 12 or _rim(r).is_empty():
			continue
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
		return r
	return {}


## A lava cell of room `r` with floor beyond it: {cell, dir}; {} when it has none.
func _rim(r: Dictionary) -> Dictionary:
	for c: Vector2i in r.cells:
		var t: int = _game._cell(c.x, c.y)
		if t != 2 and t != 3:
			continue
		for d: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			if _game._cell(c.x + d.x, c.y + d.y) == 1 and _game._cell(c.x + d.x * 2, c.y + d.y * 2) == 1:
				return {"cell": c, "dir": Vector2(d)}
	return {}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = HellScene.instantiate()
	_game.meta_path = SAVE
	_game.start_floor = 1
	root.add_child(_game)
	current_scene = _game
	await _wait(10)
	var room := _fight_room()
	await _wait(30)
	for o: Dictionary in _game.mobs.duplicate():
		if o.room == int(_game.state.room): _game.mobs.erase(o)
	var P: RefCounted = _game.feel.feedback.particles
	var s := float(_game.feel.scale)
	var me := Vector2(_game.player.x, _game.player.y)
	var m: Dictionary = _game.monsters.spawn(int(_game.state.room), me + Vector2(260.0, -40.0), "klagender_hueter", true)
	m.cds = m.cds.map(func(_c: Variant) -> float: return 99.0)
	await _wait(70)

	# 1) the scream through embers and rubble lying in its way
	var to: Vector2 = me - (m.p as Vector2)
	for k in range(9):
		var at: Vector2 = (m.p as Vector2) + to * (0.25 + 0.17 * float(k)) + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		P.embers(at / s, 34.0 / s, 16)
		for j in range(14):
			P.emit((at + Vector2(randf_range(-40, 40), randf_range(-30, 30))) / s, Vector2.ZERO, Color("a8806a"), 0.1, "debris", 2.0, 0.0, 0.0, 5.0)
	for e: Dictionary in P._embers:
		e.life = randf_range(6.0, 9.0)
		e.max = e.life
	await _wait(6)
	var scream := -1
	for i in range(m.st.attacks.size()):
		if str(m.st.attacks[i].id) == "schrei": scream = i
	_game.monsters._start_act(m, scream, to, to.length())
	var focus := me + Vector2(40.0, -30.0)
	for t: float in [0.5, 0.66, 0.74, 0.82, 0.95, 1.2, 1.8]:
		var guard := 0
		while m.act != null and float(m.act.t) < t and guard < 400:
			await _wait(1)
			guard += 1
		if m.act == null:
			await _wait(6)
		await _shot("schrei-%.2f" % t, focus)
	while m.act != null:
		await _wait(1)

	# 2) a lava pool sloshing over: the hero stands by its rim
	var rim := _rim(room)
	var cell: Vector2i = rim.cell
	var dir: Vector2 = rim.dir
	_game.monsters.cfg.feel.lava.slosh_rate = 0.0
	_game.mobs.erase(m)
	# a clean floor for the lava shots (the scream's embers lie elsewhere in this room)
	P.clear()
	_game.embers.clear()
	var edge := Vector2((cell.x + 0.5) * 96.0, (cell.y + 0.5) * 96.0) + dir * 96.0 * 0.4
	_game.player.x = edge.x + dir.x * 150.0 + dir.orthogonal().x * 120.0
	_game.player.y = edge.y + dir.y * 150.0 + dir.orthogonal().y * 120.0 + 30.0
	await _wait(60)
	_game.monsters.lava_splash(edge, dir, 6)
	await _wait_s(0.12)
	_game.monsters.lava_splash(edge + dir.orthogonal() * 40.0, dir, 5)
	var at_rim := edge + dir * 40.0
	var last := 0.12
	for t: float in [0.2, 0.32, 0.45, 0.7, 1.5, 3.0, 5.0]:
		await _wait_s(t - last)
		last = t
		await _shot("schwappen-%.2f" % t, at_rim)

	# 3) a shockwave crossing the pool
	var from := edge + dir * 120.0
	_game.monsters._zone({"kind": "wave", "p": from, "r": 320.0, "T": 0.6, "dmg": 0, "m": m, "c": "fire"})
	last = 0.0
	for t: float in [0.15, 0.3, 0.45, 0.6, 1.0, 2.0]:
		await _wait_s(t - last)
		last = t
		await _shot("welle-%.2f" % t, from - dir * 80.0)
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)
