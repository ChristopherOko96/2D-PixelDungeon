extends SceneTree
## Captures evidence of the Hell-Dungeon mode from the real windowed game:
## floor 1 start room, a locked combat room, the big map, the vault on floor 2
## a deep floor (10) with its red grade, a demon seal shot open on floor 4, the
## skull heap and its secret corridor, a pit fall, and the clone skill won on
## floor 9 that pauses at the portal. The hero is kept invulnerable.
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


func _ent(kind: String) -> Dictionary:
	for e: Dictionary in _game.W.ents:
		if e.type == kind:
			return e
	return {}


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
	# demon seal on floor 4: shot from its left neighbour cell with real shots
	_game.load_floor(4, false)
	await _wait(5)
	var seal := _ent("seal")
	var seal_room: Dictionary = _game.W.rooms[seal.room]
	seal_room.cleared = true
	_game.player.x = seal.x - 90.0
	_game.player.y = seal.y + 10.0
	_game.camera.position = Vector2(_game.player.x, _game.player.y)
	var hits := 0
	while not seal.get("broken", false) and hits < 400:
		_game._fire(Vector2.RIGHT)
		hits += 1
		await _wait(1)
		if seal.hp == 4 and not FileAccess.file_exists(ProjectSettings.globalize_path(_out.path_join("06-etage4-siegel.png"))):
			await _shot("06-etage4-siegel.png")
	await _wait(40)
	print("SEAL broken=%s fight=%s mobs=%d buffs=%s" % [seal.get("broken", false), seal_room.fight, _game.mobs.size(), _game.state.buffs])
	await _shot("07-etage4-siegel-gebrochen.png")
	# skull heap on floor 1 opens its secret corridor after three hits
	_game.load_floor(1, false)
	await _wait(5)
	var heap := _ent("skullheap")
	var door: Dictionary = _game.W.doors[int(heap.door)]
	_game.player.x = heap.x + (150.0 if door.dir == "v" else 0.0)
	_game.player.y = heap.y + (10.0 if door.dir == "v" else 180.0)
	_game.camera.position = Vector2(_game.player.x, _game.player.y)
	await _wait(40)
	await _shot("08-etage1-schaedelhaufen.png")
	for k in range(3):
		print("HEAP hit %d open=%s" % [k + 1, door.broken])
		_game._hit_breakable(heap, Vector2(heap.x, heap.y - 30))
	await _wait(40)
	print("HEAP broken=%s door_open=%s" % [heap.get("broken", false), door.broken])
	await _shot("09-etage1-geheimgang.png")
	# pit: one heart lost, back in the start room
	var pit := _ent("pit")
	_game.state.inv = 0.0
	var hp_before: int = _game.state.hp
	_game.player.x = pit.x
	_game.player.y = pit.y + 8.0
	await process_frame
	await process_frame
	print("PIT hp %d -> %d room=%s start=%s" % [hp_before, _game.state.hp, _game.state.room, _room("start").index])
	# clone: floor-9 boss reward, fights, pauses at the portal, carries to floor 10
	_game.load_floor(9, false)
	await _wait(5)
	var boss := _room("boss")
	_game._clear_room(boss, Vector2((boss.bx + boss.bw / 2.0) * 96.0, (boss.by + boss.bh / 2.0) * 96.0))
	print("SKILL owned=%s" % _game.state.skill.owned)
	var arena: Dictionary = {}
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and not r.on_path and r.bw >= 12:
			arena = r
			break
	_go(arena, arena.bw / 2.0, arena.bh / 2.0 + 0.9)
	_game.use_skill()
	await _wait(120)
	var hurt := 0
	for m: Dictionary in _game.mobs:
		if m.hp < m.max:
			hurt += 1
	print("CLONE active=%s left=%.1f mobs=%d hurt=%d" % [_game.state.skill.active, _game.state.skill.left, _game.mobs.size(), hurt])
	await _shot("10-etage9-klon.png")
	_game.use_skill()
	print("CLONE second Q active=%s" % _game.state.skill.active)
	for m: Dictionary in _game.mobs:
		m.hp = 0.0
	await _wait(10)
	var portal := _ent("portal")
	_game.player.x = portal.x
	_game.player.y = portal.y + 120.0
	_game.act()
	var left: float = _game.state.skill.left
	print("PORTAL won=%s skill_active=%s left=%.1f" % [_game.state.won, _game.state.skill.active, left])
	_game.act()
	await _wait(5)
	print("FLOOR %d skill owned=%s active=%s left=%.1f" % [_game.state.floor, _game.state.skill.owned, _game.state.skill.active, _game.state.skill.left])
	print("HELL_CAPTURE done")
	quit(0)
