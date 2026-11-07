extends SceneTree
## The hell's puzzle rules (src/world_kit/hell_puzzles.gd, docs/HOELLE-RAETSEL.de.md) and its room files:
## - valve formulas, pipe ways, vent waves, flood rounds and eye beats as pure functions;
## - every hell room file is playable, the puzzle rooms carry a Schatz of tier 1-5 and all eight riddles
##   turn up in all five tiers; the price rooms (Opferstein, Teufelspakt, Opfergrube) are there;
## - in the real game a burnt hero stands again at the rune and loses one hit of LP.
## Usage:
##   godot --headless --path . --script res://tests/hell_puzzles_test.gd
const HP = preload("res://src/world_kit/hell_puzzles.gd")
const Data = preload("res://src/world_editor/world_room_data.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const KINDS := ["ketten", "takt", "flut", "blut", "schleuse", "augen", "werk", "wacht"]

var _checked := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
		printerr("HELL_PUZZLES_FAIL: ", what)


func _run() -> void:
	_test_rules()
	_test_files()
	await _test_burn_in_game()
	print("HELL_PUZZLES checked=%d failures=%d" % [_checked, _failed])
	quit(1 if _failed > 0 else 0)


func _test_rules() -> void:
	# valve formulas: OR of AND terms, "!" negates, empty = always lava
	_check(HP.wet_of("", {}), "an empty formula is always wet")
	_check(HP.wet_of("!A", {"A": false}) and not HP.wet_of("!A", {"A": true}), "!A is wet while A is shut")
	_check(HP.wet_of("A|B", {"B": true}) and not HP.wet_of("A|B", {}), "A|B")
	_check(HP.wet_of("A&!B", {"A": true}) and not HP.wet_of("A&!B", {"A": true, "B": true}), "A&!B")
	# pipes: I turns between east-west and north-south, L through its four corners
	_check(HP.pipe_open("I", 0) == [1, 3] and HP.pipe_open("I", 1) == [0, 2] and HP.pipe_open("I", 2) == [1, 3], "I pipe turns")
	_check(HP.pipe_open("L", 3) == [3, 0], "L pipe turns")
	var pipes := {Vector2i(1, 0): {"shape": "I", "rot": 0}, Vector2i(2, 0): {"shape": "L", "rot": 2}, Vector2i(2, 1): {"shape": "I", "rot": 1}}
	var at := func(c: Vector2i) -> Dictionary: return pipes.get(c, {})
	var way := HP.trace_flow(Vector2i(1, 0), 3, at, Vector2i(2, 2))
	_check(bool(way.ok) and (way.cells as Array).size() == 3, "the lava runs east, turns south and reaches the forge: %s" % str(way))
	pipes[Vector2i(2, 0)] = {"shape": "L", "rot": 0}
	_check(not bool(HP.trace_flow(Vector2i(1, 0), 3, at, Vector2i(2, 2)).ok), "a wrongly turned corner spills the lava")
	# vents fire on beat 0 of their wave and glow the beat before
	_check(HP.vent_phase(Vector2i(0, 0), 0, 3) == 0 and HP.vent_phase(Vector2i(1, 0), 0, 3) == 2, "the wave runs down and right")
	_check(HP.vent_phase(Vector2i(1, 0), 1, 3) == 0, "a beat later the next vent fires")
	# the flood: ebb, then warn, then flood, round again
	_check(HP.flood_phase(0.5, 3.2, 1.1, 1.6) == "ebb" and HP.flood_phase(1.3, 3.2, 1.1, 1.6) == "warn" and HP.flood_phase(2.0, 3.2, 1.1, 1.6) == "flood" and HP.flood_phase(3.3, 3.2, 1.1, 1.6) == "ebb", "flood round")
	# eyes: open beats, shut beats, the last shut beat glows
	_check(HP.eye_state(0, 2, 2, 0) == 2 and HP.eye_state(1, 2, 2, 0) == 2 and HP.eye_state(2, 2, 2, 0) == 0 and HP.eye_state(3, 2, 2, 0) == 1, "eye beats")


func _test_files() -> void:
	var files := Data.list_rooms("hell")
	_check(files.size() >= 100, "the hell has its room files (%d)" % files.size())
	var seen := {}
	var price := {}
	# every picture a hell room names is in the hell's set (a frost name like snow_c breaks the drawing)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/hell/manifest.json"))
	for t: Dictionary in files:
		_check(Data.problems(t).is_empty(), "%s is playable: %s" % [t.id, str(Data.problems(t))])
		for o: Dictionary in t.get("objects", []):
			if o.has("asset"):
				_check(manifest.has(str(o.asset)), "%s: the picture %s is in the hell's set" % [t.id, str(o.asset)])
		var id := str(t.id)
		for k: String in ["opferstein", "teufelspakt", "opfergrube"]:
			if id == "h_" + k: price[k] = true
		if str(t.role) != "jump":
			continue
		for o: Dictionary in t.get("objects", []):
			if str(o.get("kind", "")) == "chest" and str((o.get("loot", {}) as Dictionary).get("type", "")) == "hoard":
				var tier := int((o.loot as Dictionary).get("tier", 0))
				_check(tier >= 1 and tier <= 5, "%s pays a Schatz of tier 1-5 (%d)" % [id, tier])
				for k: String in KINDS:
					if id.begins_with("h_%s_s" % k): seen["%s%d" % [k, tier]] = true
	for k: String in KINDS:
		for tier in range(1, 6):
			_check(seen.has("%s%d" % [k, tier]), "the riddle %s has a room of tier %d" % [k, tier])
	_check(price.size() == 3, "the three price rooms are there (%s)" % str(price.keys()))


## A hero standing in a firing vent: one hit lost, back at the rune.
func _test_burn_in_game() -> void:
	var game: Node = HellScene.instantiate()
	game.class_id = "swordsman"
	game.graphics_path = "user://hell_puzzles_test_graphics.cfg"
	game.world_room_path = "res://assets/data/world_rooms/hell/h_takt_s1_la.json"
	root.add_child(game)
	for i in range(30):
		await process_frame
	var hp: RefCounted = game.hell_puzzles
	var vent: Dictionary = {}
	var rune: Dictionary = {}
	for e: Dictionary in hp.pieces:
		if str(e.type) == "hell_vent" and vent.is_empty(): vent = e
		if str(e.type) == "hell_rune": rune = e
	_check(not vent.is_empty() and not rune.is_empty(), "the Flammentakt room has vents and a rune")
	if vent.is_empty() or rune.is_empty():
		game.queue_free()
		return
	var c: Vector2i = HP.cell_of(vent)
	var before := int(game.state.hp)
	var burnt := false
	for i in range(240):
		game.state.inv = 0.0
		game.place_player(HP.centre(c) + Vector2(0, 10))
		hp.last_cell = c
		await process_frame
		if int(game.state.hp) < before:
			burnt = true
			break
	_check(burnt, "a firing vent burns the hero")
	_check(before - int(game.state.hp) == int(game.hit_scale()), "a burn costs one hit of LP (%d)" % (before - int(game.state.hp)))
	_check(game.player_cell() == HP.cell_of(rune), "the burnt hero stands at the rune again")
	game.queue_free()
	await process_frame
