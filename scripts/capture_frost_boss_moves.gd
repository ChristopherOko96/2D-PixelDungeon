extends SceneTree
## Captures a Frostgruft guardian's attacks in the real windowed game: the
## guardian of a floor alone in a big combat room, the hero in front of it,
## each attack started in turn and shot at fixed points after its start, full
## screen and a 2x close-up between the two. Guardians without a kit run the
## frost moves (frost_moves.gd, theme.moves "guardian" or a kind's set),
## kit guardians their kit attacks (boss_kit.gd). The hero cannot be hurt
## ("hit": he can, he never dies); the run writes no meta.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_boss_moves.gd -- <output_dir> <floor> [ids|all] [hit] [kind] [times]
## kind: a mob kind instead of the guardian (its own move set); times: the
## seconds after the start to shoot at (comma list, default TIMES).
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
const BossKit = preload("res://src/hell/boss_kit.gd")
const TIMES := [0.2, 0.45, 0.7, 0.95, 1.2, 1.5, 1.9, 2.4, 3.0]

var _out := "res://production/qa/evidence/frost-boss-moves"
var _floor := 1
var _only: Array = []
var _hit := false
var _kind := "boss"
var _times: Array = TIMES
var _game: Node
var _hold := 0
## The guardian keeps its health while it is shot (a stray click must not kill it).
var _boss: Dictionary = {}
var _boss_hp := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _floor = int(args[1])
	if args.size() > 2 and args[2] != "all": _only = args[2].split(",")
	if args.size() > 3: _hit = args[3] == "hit"
	if args.size() > 4: _kind = args[4]
	if args.size() > 5:
		_times = []
		for v: String in args[5].split(","):
			_times.append(float(v))
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and is_instance_valid(_game) and not _game.state.is_empty():
			if not _hit or _hold > 0:
				_game.state.inv = 5.0
			_game.state.hp = maxi(int(_game.state.hp), 6)
			if not _boss.is_empty():
				_boss.hp = _boss_hp
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


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = FrostScene.instantiate()
	_game.class_id = "mage"
	_game.start_floor = _floor
	root.add_child(_game)
	await _wait(10)
	# a stretch of open floor (9 x 5 cells) in a combat room: nothing walls the attacks in
	var room: Dictionary = {}
	var mid := Vector2.ZERO
	for r: Dictionary in _game.W.rooms:
		if r.type != "combat" or not room.is_empty():
			continue
		for c: Vector2i in r.cells:
			var open := true
			for dy in range(-2, 3):
				for dx in range(-4, 5):
					if _game._cell(c.x + dx, c.y + dy) != 1:
						open = false
			if open:
				room = r
				mid = Vector2((c.x + 0.5) * 96.0, (c.y + 0.5) * 96.0)
				break
	print("ROOM ", room.get("index", -1), " at ", mid)
	room.cleared = true
	_game.player.x = mid.x - 160.0
	_game.player.y = mid.y + 120.0
	_game.state.room = room.index
	await _wait(30)
	for o: Dictionary in _game.mobs.duplicate():
		_game.mobs.erase(o)
	_game._spawn_mob(room.index, mid + Vector2(160.0, -60.0), _kind)
	var m: Dictionary = _game.mobs[_game.mobs.size() - 1]
	_boss = m
	_boss_hp = float(m.hp)
	var me := Vector2(_game.player.x, _game.player.y)
	_hold = 1
	await _wait(50)
	var list: Array = []
	if m.has("kit"):
		var seen := {}
		for ph: Dictionary in m.kit.phases:
			for a: Dictionary in ph.attacks:
				if not seen.has(str(a.do)):
					seen[str(a.do)] = true
					list.append({"id": str(a.do), "atk": a})
	else:
		for e: Dictionary in FrostMoves.set_for(_game, m).get("moves", []):
			list.append({"id": str(e.move), "move": e})
	for item: Dictionary in list:
		if not _only.is_empty() and not str(item.id) in _only:
			continue
		_game.player.x = me.x
		_game.player.y = me.y
		m.p = mid + Vector2(160.0, -60.0)
		# nothing else starts on its own while one attack is shot
		if m.has("kit"):
			m.atk_t = 99.0
			m.busy = {}
		if m.has("mv"):
			m.mv.next = 99.0
			m.mv.run = {}
		# no adds called and no plain rings shot in between
		m.summon = 999.0
		m.ring_t = 999.0
		_hold = 1
		await _wait(20)
		if _hit:
			_hold = 0
			_game.state.inv = 0.0
		if m.has("kit"):
			BossKit.start(_game, m, item.atk)
		else:
			FrostMoves._begin(_game, m, item.move)
		print("MOVE %s" % item.id)
		var focus: Vector2 = ((m.p as Vector2) + Vector2(_game.player.x, _game.player.y)) * 0.5
		var last := 0.0
		for t: float in _times:
			await _wait_s(t - last)
			last = t
			await _shot("etage%d-%s-%.2f" % [_floor, item.id, t], focus)
		await _wait_s(1.0)
		for o: Dictionary in _game.mobs.duplicate():
			if o != m:
				_game.mobs.erase(o)
		_game.eshots.clear()
	_game.queue_free()
	await process_frame
	quit(0)
