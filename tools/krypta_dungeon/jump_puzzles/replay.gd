extends SceneTree
## Run: node tools/krypta_dungeon/jump_puzzles/steps.js, then
##   godot --headless --path . -s tools/krypta_dungeon/jump_puzzles/replay.gd   (JP_ONLY=<room id> for one room)
## Plays each jump room's Schatz way (written by steps.js from the room files as they are) in the real game: the hero is set
## where the step starts, pads really throw, plates, bowls, torches, keys and gates really work. Checks
## that every throw lands where the checker said and that the Schatz chest opens at the end.
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
## The ways: JP_STEPS (a path), else the file steps.js writes by default.
var STEPS := OS.get_environment("JP_STEPS") if OS.get_environment("JP_STEPS") != "" else ProjectSettings.globalize_path("user://jump_steps.json")
const M := 2
const C := 96.0

var game: Node
var bad := 0


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


func _place(c: Array) -> void:
	game.player.x = (float(c[0]) + M + 0.5) * C
	game.player.y = (float(c[1]) + M + 0.5) * C + 10.0
	game.player.vel = Vector2.ZERO


func _cell() -> Vector2i:
	return Vector2i(int(floor(game.player.x / C)) - M, int(floor((game.player.y - 6.0) / C)) - M)


func _run() -> void:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STEPS))
	var only := OS.get_environment("JP_ONLY")
	for id: String in all:
		if only != "" and id != only:
			continue
		await _room(id, all[id])
	print("REPLAY done bad=%d" % bad)
	quit(1 if bad > 0 else 0)


func _room(id: String, plan: Dictionary) -> void:
	game = KryptaScene.instantiate()
	game.class_id = "swordsman"
	game.graphics_path = "user://replay_graphics.cfg"
	game.world_room_path = "res://assets/data/world_rooms/krypta/%s.json" % id
	root.add_child(game)
	await _frames(40)
	var fails := 0
	var k := 0
	for st: Dictionary in plan.steps:
		k += 1
		var how := str(st.how)
		if how.begins_with("Wurf"):
			var rx := RegEx.create_from_string("^Wurf ([0-9]+),([0-9]+)[nesw]")
			var m := rx.search(how)
			var cx := int(m.get_string(1))
			var cy := int(m.get_string(2))
			for e: Dictionary in game.W.ents:
				if e.type == "launch":
					e.armed = true
			_place([cx, cy])
			var flew := false
			var calm := 0
			for i in range(400):
				await _frames(1)
				if game.launch_pads.flying():
					flew = true
					calm = 0
				elif flew:
					# a pad under the landing throws on after its windup: wait for a quiet moment
					calm += 1
					if calm > 20:
						break
			await _frames(3)
			var got := _cell()
			var want := Vector2i(int(st.to[0]), int(st.to[1]))
			if not flew or got != want:
				fails += 1
				printerr("REPLAY %s step %d '%s': flew=%s landed %s, wanted %s" % [id, k, how, flew, got, want])
				_place(st.to)
				await _frames(2)
		elif how.begins_with("geht nach"):
			_place(st.to)
			await _frames(6)
		else:
			_place(st.from)
			if how.begins_with("Fackel"):
				for e: Dictionary in game.W.ents:
					if e.type == "lever":
						game.player.x = float(e.x)
						game.player.y = float(e.y) + 20.0
			await _frames(3)
			game.act()
			await _frames(6)
	# the Schatz
	var chest: Dictionary = {}
	for e: Dictionary in game.W.ents:
		if e.type == "chest" and e.has("hoard"):
			chest = e
	if chest.is_empty() or str(chest.get("state", "")) == "":
		fails += 1
		printerr("REPLAY %s: the Schatz did not open (%s)" % [id, chest.get("state", "none")])
	var solved := (game.W.groups as Dictionary).keys().filter(func(g: String) -> bool: return game.W.groups[g].get("solved", false))
	print("REPLAY %s steps=%d fails=%d solved=%s gold=%s" % [id, plan.steps.size(), fails, solved, chest.get("loot", {})])
	bad += fails
	game.queue_free()
	await process_frame
	await process_frame
