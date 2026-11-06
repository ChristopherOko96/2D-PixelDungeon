extends SceneTree
## Plays every Frostgruft puzzle room's way (tools/frost_dungeon/puzzles/steps.json, written by
## rooms/build_frost_rooms.js) in the real game: the hero walks cell by cell over thin ice, leans into
## blocks and snowballs with the real keys, carries ember, turns prisms, strikes crystals, walks with
## the mirror ghost and watches the mirror's show. Checks that the puzzle's group is solved and the
## Schatz chest opens.
## Run: godot --headless --path . -s tools/frost_dungeon/puzzles/replay.gd   (FR_ONLY=<room id> for one room)
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const M := 2
const C := 96.0
const STEPS := "res://tools/frost_dungeon/puzzles/steps.json"
const KEYS := {"e": KEY_D, "w": KEY_A, "s": KEY_S, "n": KEY_W}

var game: Node
var bad := 0
var fails := 0
var room_id := ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		if game != null and not game.state.is_empty():
			game.state.hp = game.state.max_hp
			game.state.inv = 5.0
			game.mobs = []
			for r: Dictionary in game.W.rooms:
				r.fight = false
		await process_frame


func _centre(c: Array) -> Vector2:
	return Vector2((float(c[0]) + M + 0.5) * C, (float(c[1]) + M + 0.5) * C + 10.0)


func _place(c: Array) -> void:
	game.place_player(_centre(c))


## Waits until the game's puzzle step has seen the hero on cell c: the fixed 60 Hz story clock may run no
## step in a frame, and a cell left unseen would be one long step to the next (ember counts it by its end).
func _seen(c: Array) -> void:
	for i in range(30):
		if game.frost_puzzles.last_cell == Vector2i(int(c[0]) + M, int(c[1]) + M):
			return
		await _frames(1)


func _cell() -> Vector2i:
	var p: Vector2i = game.player_cell()
	return p - Vector2i(M, M)


func _fail(text: String) -> void:
	fails += 1
	printerr("REPLAY %s: %s" % [room_id, text])


func _key(k: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


func _run() -> void:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STEPS))
	var only := OS.get_environment("FR_ONLY")
	for id: String in all:
		if only != "" and id != only:
			continue
		await _room(id, all[id].steps)
	print("FROST_REPLAY done bad=%d" % bad)
	quit(1 if bad > 0 else 0)


func _room(id: String, steps: Array) -> void:
	room_id = id
	fails = 0
	game = FrostScene.instantiate()
	game.class_id = "swordsman"
	game.graphics_path = "user://replay_graphics.cfg"
	game.world_room_path = "res://assets/data/world_rooms/frost/%s.json" % id
	root.add_child(game)
	await _frames(30)
	var k := 0
	for st: Dictionary in steps:
		k += 1
		if fails > 0:
			break
		if st.has("at"):
			_place(st.at)
			await _frames(3)
			await _seen(st.at)
		elif st.has("walk"):
			for c: Array in st.walk:
				_place(c)
				await _frames(2)
				await _seen(c)
				if OS.get_environment("FR_DEBUG") != "":
					print("  at ", c, " cell ", _cell(), " seen ", game.frost_puzzles.last_cell - Vector2i(M, M), " carry ", game.frost_puzzles.carry.get("left", "-"))
				if _cell() != Vector2i(int(c[0]), int(c[1])):
					_fail("step %d: walking to %s the hero stands at %s (fell?)" % [k, str(c), str(_cell())])
					break
		elif st.has("use"):
			_place(st.use)
			await _frames(2)
			await _seen(st.use)
			var near: Dictionary = game._nearest()
			var label := str(near.get("label", ""))
			if st.has("what") and not label.begins_with(str(st.what)):
				_fail("step %d at %s: nearest is '%s', wanted '%s'" % [k, str(st.use), label, str(st.what)])
				break
			game.act()
			await _frames(4)
		elif st.has("push"):
			_place(st.push)
			await _frames(2)
			await _seen(st.push)
			var before := _pieces()
			var key: Key = KEYS[str(st.dir)]
			_key(key, true)
			var moved := false
			for i in range(60):
				await _frames(1)
				if _pieces() != before:
					moved = true
					break
			_key(key, false)
			await _frames(30)
			if not moved:
				_fail("step %d: the push %s from %s moved nothing" % [k, str(st.dir), str(st.push)])
		elif st.has("show"):
			await _show(st.show)
		elif st.has("chest"):
			await _chest(st.chest)
	var solved: Array = (game.W.groups as Dictionary).keys().filter(func(g: String) -> bool: return bool(game.W.groups[g].get("solved", false)))
	print("REPLAY %s steps=%d fails=%d solved=%s" % [id, steps.size(), fails, solved])
	bad += fails
	game.queue_free()
	await process_frame
	await process_frame


## Where the blocks and balls stand and how big, as one text.
func _pieces() -> String:
	var out: Array = []
	for e: Dictionary in game.frost_puzzles.pieces:
		if str(e.type) in ["ice_block", "snowball"]:
			out.append("%s:%d,%d:%d:%s" % [e.type, int(e.x), int(e.y), int(e.get("size", 1)), e.get("gone", false)])
	return ";".join(out)


## Pulls the mirror's lever once its time is up and checks that hero and ghost stand where they did.
func _show(at: Array) -> void:
	_place(at)
	await _frames(2)
	var fp: RefCounted = game.frost_puzzles
	var ghost: Dictionary = {}
	for e: Dictionary in fp.pieces:
		if str(e.type) == "mirror_ghost":
			ghost = e
	var before := Vector2(float(game.player.x), float(game.player.y))
	var ghost_before := Vector2(float(ghost.x), float(ghost.y))
	fp.ghost_time[int(game.state.room)] = 9999.0
	game.act()
	await _frames(2)
	if not fp.showing():
		_fail("the mirror's lever showed nothing")
		return
	var reached := false
	for i in range(3000):
		await _frames(1)
		var gh := FrostPuzzlesCell.of(ghost)
		if not fp.showing():
			break
		for e: Dictionary in fp.pieces:
			if str(e.type) == "ghost_plate" and str(e.get("who", "")) == "ghost" and FrostPuzzlesCell.of(e) == gh:
				reached = true
	if fp.showing():
		_fail("the mirror's show never ends")
		return
	if not reached:
		_fail("in the show the ghost never reached its plate")
	if Vector2(float(game.player.x), float(game.player.y)).distance_to(before) > 1.0 or Vector2(float(ghost.x), float(ghost.y)).distance_to(ghost_before) > 1.0:
		_fail("after the show hero and ghost are not back")


## Opens the Schatz from the cell `at` next to it.
func _chest(at: Array) -> void:
	_place(at)
	await _frames(3)
	var chest: Dictionary = {}
	for e: Dictionary in game.W.ents:
		if e.type == "chest" and e.has("hoard"):
			chest = e
	if chest.is_empty():
		_fail("no Schatz in the room")
		return
	var near: Dictionary = game._nearest()
	if not is_same(near.get("e"), chest):
		_fail("at %s the nearest is '%s', not the Schatz" % [str(at), str(near.get("label", ""))])
		return
	game.act()
	await _frames(4)
	if str(chest.get("state", "")) == "":
		_fail("the Schatz did not open")


class FrostPuzzlesCell:
	static func of(e: Dictionary) -> Vector2i:
		return Vector2i(int(floor(float(e.x) / 96.0)), int(floor(float(e.y) / 96.0)))
