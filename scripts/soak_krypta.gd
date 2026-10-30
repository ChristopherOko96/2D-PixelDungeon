extends SceneTree
## Soak run of Story 1 (the crypt world): on every floor the hero fights for a while in a fight room,
## wakes a mimic chest, breaks crates (undead), steps plates wrongly and rightly and fights the
## floor's boss, attacking all the time. Prints SOAK lines; a script error (e.g. a stack overflow)
## shows in the output. Usage:
##   godot --headless --path . -s res://scripts/soak_krypta.gd -- [class_id] [seconds per scene]
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")

var _game: Node
var _class := "swordsman"
var _secs := 8.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_class = args[0]
	if args.size() > 1:
		_secs = float(args[1])
	_run.call_deferred()


func _fight(seconds: float) -> void:
	var frames := int(seconds * 60)
	for i in range(frames):
		if _game.state.is_empty():
			return
		_game.state.inv = 0.0
		_game.state.hp = _game.state.max_hp
		_game.state.dead = 0.0
		# attack the nearest monster, walk towards it
		var me := Vector2(_game.player.x, _game.player.y)
		var best: Dictionary = {}
		var bd := INF
		for m: Dictionary in _game.mobs:
			var d: float = me.distance_to(m.p)
			if d < bd:
				bd = d
				best = m
		if not best.is_empty():
			var dir: Vector2 = (best.p - me).normalized()
			_game.state.cool = 0.0
			_game._attack(dir)
			if bd > 140:
				_game.player.x += dir.x * 4
				_game.player.y += dir.y * 4
		await process_frame


func _go(x: float, y: float) -> void:
	_game.player.x = x
	_game.player.y = y
	_game.camera.position = Vector2(x, y)


func _run() -> void:
	_game = KryptaScene.instantiate()
	_game.class_id = _class
	root.add_child(_game)
	await process_frame
	for n in range(1, 11):
		_game.load_floor(n, true)
		await process_frame
		print("SOAK floor %d world %d" % [n, int(_game.state.world_run)])
		# a fight room fight
		for r: Dictionary in _game.W.rooms:
			if r.type == "combat" and not r.get("seq", false):
				_go((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0) * 96.0)
				break
		await _fight(_secs)
		print("SOAK fight done mobs=%d" % _game.mobs.size())
		# mimic chests
		for e: Dictionary in _game.W.ents.duplicate():
			if e.type == "chest" and e.get("mimic", false) and not e.get("taken", false):
				_go(e.x, e.y + 80.0)
				await process_frame
				_game.act()
				await _fight(_secs)
				print("SOAK mimic room=%d mobs=%d" % [e.room, _game.mobs.size()])
				break
		# crates, undead first
		var broke := 0
		for e: Dictionary in _game.breakables:
			if e.type == "crate" and not e.get("broken", false) and (str(e.drop) == "undead" or broke < 2):
				_go(e.x, e.y + 70.0)
				for k in range(4):
					_game.state.cool = 0.0
					_game._attack(Vector2.UP)
					await process_frame
				broke += 1
				await _fight(_secs * 0.5)
		print("SOAK crates %d" % broke)
		# plates: one wrong, then the order
		var g: Dictionary = _game.W.groups.seq
		var plates: Array = _game.W.ents.filter(func(e: Dictionary) -> bool: return e.type == "plate")
		plates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.pos) < int(b.pos))
		for r: Dictionary in _game.W.rooms:
			r.fight = false
			r.cleared = true
		_game.mobs = []
		var room: Dictionary = _game.W.rooms[plates[0].room]
		var away := Vector2((room.bx + room.bw / 2.0) * 96.0, (room.by + room.bh / 2.0 + 1.2) * 96.0)
		var wrong: int = g.sequence[2]
		for p: int in [g.sequence[0], wrong] + Array(g.sequence):
			_go(away.x, away.y)
			for k in range(70):
				await process_frame
			_go(plates[p - 1].x, plates[p - 1].y + 10.0)
			for k in range(6):
				await process_frame
		print("SOAK plates solved=%s" % str(g.solved))
		# the boss
		_game.enter_boss_room()
		await _fight(_secs * 2)
		print("SOAK boss mobs=%d" % _game.mobs.size())
	print("SOAK done")
	quit()
