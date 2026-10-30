extends SceneTree
## Captures evidence of a world on the world kit (Story 1 the crypt, Story 3 the hell) from the real windowed game
## (docs/WELT-BAUKASTEN.de.md): the start, the key room (shop, merchant, fountain), the dressed boss
## gate, a breakable crate hit by the hero's own attack, a mimic chest waking, the plate puzzle,
## the hidden stairs behind the extinguished torch and the floor choice, a new world on floor 1,
## and the blue gate on floor 10. Prints a CHECK line per step. The hero is kept at full hearts.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_krypta_dungeon.gd -- <output_dir> [class_id] [scene] [pixel|hd]
## scene defaults to the crypt; the hell: res://src/hell/hell_dungeon.tscn. The graphics set defaults to
## the player's setting; pixel or hd pick one for this capture (its own user:// file, deleted after).

var _out := "res://production/qa/evidence/krypta-welt"
var _class := "swordsman"
var _scene := "res://src/hell/krypta_dungeon.tscn"
var _graphics := ""
const GRAPHICS_FILE := "user://capture_graphics.cfg"
var _game: Node
var _fails := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_class = args[1]
	if args.size() > 2:
		_scene = args[2]
	if args.size() > 3:
		_graphics = args[3]
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


func _check(ok: bool, what: String) -> void:
	print("CHECK %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _go(x: float, y: float) -> void:
	_game.player.x = x
	_game.player.y = y
	_game.camera.position = Vector2(x, y)


func _room(gtype: String) -> Dictionary:
	for r: Dictionary in _game.W.rooms:
		if str(r.get("gtype", "")) == gtype:
			return r
	return {}


func _calm() -> void:
	for r: Dictionary in _game.W.rooms:
		r.cleared = true
		r.fight = false
	_game.mobs = []


func _signature() -> String:
	var s := ""
	for r: Dictionary in _game.W.rooms:
		s += "%d,%d,%d,%d,%s|" % [r.bx, r.by, r.bw, r.bh, r.get("gtype", "")]
	return s


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = (load(_scene) as PackedScene).instantiate()
	_game.class_id = _class
	if _graphics != "":
		var cfg := ConfigFile.new()
		cfg.set_value("options", "graphics", _graphics)
		cfg.save(GRAPHICS_FILE)
		_game.graphics_path = GRAPHICS_FILE
	root.add_child(_game)
	await _wait(40)
	_check(_game.world != null and int(_game.state.get("world_run", 0)) > 0, "floor 1 built live, world %d" % int(_game.state.get("world_run", 0)))
	await _shot("01-start.png")
	# key room: shop with merchant, fountain, key on the rug; entered from the bottom right
	_calm()
	var key := _room("key")
	_go((key.bx + 6) * 96.0, (key.by + 7.6) * 96.0)
	await _wait(50)
	await _shot("02-schluesselkammer.png")
	_go((key.bx + 6) * 96.0, (key.by + 5.0) * 96.0)
	await _wait(10)
	_check(bool(_game.state.keys.C), "boss key picked up in the key room")
	var well: Dictionary = {}
	for e: Dictionary in _game.W.ents:
		if e.type == "well":
			well = e
	_game.state.skill_cd = {"1": 9.0}
	_go(well.x, well.y + 80.0)
	await _wait(5)
	_game.act()
	_check(well.get("used", false) and (_game.state.skill_cd as Dictionary).is_empty(), "mana fountain used once, skills refilled")
	# the dressed boss gate, approached from below
	var gate_room: Dictionary = {}
	var gate: Dictionary = {}
	for d: Dictionary in _game.W.doors:
		if d.get("boss_gate", false):
			gate = d
	_check(not gate.is_empty() and gate.dir == "v", "boss gate in a north wall (entered from below)")
	_go(gate.cx, (gate.y1 + 4.5) * 96.0)
	await _wait(40)
	_game.camera.position = Vector2(gate.cx, (gate.y1 + 1.6) * 96.0)
	await _shot("03-bosstor.png")
	# a crate broken by the hero's own attack
	var crate: Dictionary = {}
	for e: Dictionary in _game.breakables:
		if e.type == "crate" and not e.get("broken", false):
			crate = e
			break
	if not crate.is_empty():
		_go(crate.x, crate.y + 70.0)
		await _wait(20)
		await _shot("04-kiste-vorher.png")
		for k in range(6):
			_game.state.cool = 0.0
			_game._attack(Vector2.UP)
			await _wait(12)
		_check(crate.get("broken", false), "crate (%s) broken by the hero's attack" % crate.look)
		await _shot("05-kiste-zerbrochen.png")
	# a mimic chest wakes when opened
	var mimic: Dictionary = {}
	for e: Dictionary in _game.W.ents:
		if e.type == "chest" and e.get("mimic", false):
			mimic = e
			break
	if not mimic.is_empty():
		_calm()
		_go(mimic.x, mimic.y + 80.0)
		await _wait(20)
		await _shot("06-mimik-truhe.png")
		_game.act()
		await _wait(30)
		var woke: bool = _game.mobs.any(func(m: Dictionary) -> bool: return m.id == "mimik")
		_check(woke and _game.W.rooms[mimic.room].fight, "mimic chest woke and locked the room")
		await _shot("07-mimik-erwacht.png")
	else:
		print("CHECK skip no mimic chest on this floor")
	# plates in their order
	_calm()
	var g: Dictionary = _game.W.groups.seq
	var plates: Array = _game.W.ents.filter(func(e: Dictionary) -> bool: return e.type == "plate")
	plates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.pos) < int(b.pos))
	var seq_room: Dictionary = _game.W.rooms[plates[0].room]
	for p: int in g.sequence:
		_go((seq_room.bx + seq_room.bw / 2.0) * 96.0, (seq_room.by + seq_room.bh / 2.0 + 1.2) * 96.0)
		await _wait(4)
		_go(plates[p - 1].x, plates[p - 1].y + 10.0)
		await _wait(4)
	_go((seq_room.bx + seq_room.bw / 2.0) * 96.0, (seq_room.by + seq_room.bh / 2.0 + 1.2) * 96.0)
	await _wait(10)
	_check(bool(g.solved), "%d plates solved in the order %s" % [plates.size(), str(g.sequence)])
	await _shot("08-druckplatten.png")
	# hidden stairs: roll worlds on floor 4 until one has them
	var tries := 0
	while _room("stairs").is_empty() and tries < 30:
		_game.state.world_run = 0
		_game.load_floor(4, false)
		tries += 1
	await _wait(10)
	var lever: Dictionary = {}
	for e: Dictionary in _game.W.ents:
		if e.type == "lever":
			lever = e
	_check(not lever.is_empty(), "floor 4 world with hidden stairs and its torch (%d tries)" % tries)
	if not lever.is_empty():
		_calm()
		_go(lever.x, lever.y + 70.0)
		await _wait(30)
		await _shot("09-erloschene-fackel.png")
		_game.act()
		await _wait(10)
		var opened := false
		for d: Dictionary in _game.W.doors:
			if d.get("group", "") == "stiege":
				opened = d.broken
		_check(opened and lever.lit, "lighting the torch opened the hidden wall")
		await _shot("10-fackel-brennt.png")
		var stairs: Dictionary = {}
		for e: Dictionary in _game.W.ents:
			if e.type == "stairs":
				stairs = e
		_go(stairs.x, stairs.y + 90.0)
		await _wait(30)
		_game.act()
		await _wait(5)
		await _shot("11-etagenwahl.png")
		var old_world := int(_game.state.world_run)
		_game.load_floor(1, false)
		var old_floor1 := _signature()
		_game.load_floor(4, true)
		_game.state.world_run = old_world
		_game._open_stairs()
		_game.choose_stairs(1)
		await _wait(30)
		_check(int(_game.state.floor) == 1 and int(_game.state.world_run) != old_world and _signature() != old_floor1, "stairs to floor 1: a new world with a new floor 1")
		await _shot("12-neue-welt-etage1.png")
	# floor 10: the gate burns blue
	_game.load_floor(10, false)
	_calm()
	for d: Dictionary in _game.W.doors:
		if d.get("boss_gate", false):
			gate = d
	_go(gate.cx, (gate.y1 + 4.5) * 96.0)
	await _wait(40)
	_game.camera.position = Vector2(gate.cx, (gate.y1 + 1.6) * 96.0)
	await _shot("13-etage10-bosstor.png")
	if _graphics != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GRAPHICS_FILE))
	print("KRYPTA_CAPTURE fails=%d" % _fails)
	quit(1 if _fails > 0 else 0)
