extends SceneTree
## Story 1, the crypt world on the story runtime (docs/WELT-BAUKASTEN.de.md), regressions from play:
## - a wrongly stepped pressure plate clears once the hero steps off and can be stepped again;
## - a mimic chest that wakes leaves no solid behind: the mimic can move and takes hits;
## - undead from a broken crate at a wall stand on free floor, not in the wall;
## - a mimic of the room's roster waits as a chest instead of fighting as a monster.

const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
var checked := 0
var failures: Array[String] = []
var game: Node


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("KRYPTA_WORLD_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		if game != null and not game.state.is_empty():
			game.state.inv = 0.0
			game.state.hp = game.state.max_hp
		await process_frame


func _go(p: Vector2) -> void:
	game.player.x = p.x
	game.player.y = p.y


func _calm() -> void:
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true
	game.mobs = []


func _run() -> void:
	seed(7)
	game = KryptaScene.instantiate()
	game.class_id = "swordsman"
	root.add_child(game)
	await _frames(2)
	await _test_wrong_plate_clears_and_can_be_stepped_again()
	await _test_woken_mimic_moves_and_takes_hits()
	await _test_crate_undead_stand_on_free_floor()
	await _test_roster_mimic_waits_as_a_chest()
	game.queue_free()
	await process_frame
	print("KRYPTA_WORLD checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_wrong_plate_clears_and_can_be_stepped_again() -> void:
	# Arrange
	_calm()
	var g: Dictionary = game.W.groups.seq
	var plates: Array = game.W.ents.filter(func(e: Dictionary) -> bool: return e.type == "plate")
	plates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.pos) < int(b.pos))
	var room: Dictionary = game.W.rooms[plates[0].room]
	var away := Vector2((room.bx + room.bw / 2.0) * 96.0, (room.by + room.bh / 2.0 + 1.2) * 96.0)
	var first: Dictionary = plates[int(g.sequence[0]) - 1]
	var wrong: Dictionary = plates[int(g.sequence[2]) - 1]
	# Act: the first plate right, then the third of the order (wrong)
	for p: Dictionary in [first, wrong]:
		_go(away)
		await _frames(4)
		_go(Vector2(p.x, p.y + 10.0))
		await _frames(4)
	# Assert
	check(float(wrong.get("wrong", 0.0)) > 0.0, "a wrong plate is marked")
	check(not first.get("on", false), "a wrong plate clears the plates already lit")
	# Act: step off
	_go(away)
	for i in range(900):
		if float(wrong.get("wrong", 0.0)) == 0.0:
			break
		await _frames(1)
	# Assert
	check(float(wrong.get("wrong", 0.0)) == 0.0, "the wrong mark clears once the hero has stepped off")
	# Act: the full order, the formerly wrong plate included
	for p: int in g.sequence:
		_go(away)
		await _frames(4)
		_go(Vector2(plates[p - 1].x, plates[p - 1].y + 10.0))
		await _frames(4)
	# Assert
	check(bool(g.solved), "after a mistake the plates still solve in the right order")


func _test_woken_mimic_moves_and_takes_hits() -> void:
	# Arrange: a mimic chest in the middle of a cleared fight room
	_calm()
	var room: Dictionary = {}
	for r: Dictionary in game.W.rooms:
		if r.type == "combat" and int(r.bw) >= 20:
			room = r
			break
	var at := Vector2((room.bx + room.bw / 2.0) * 96.0, (room.by + room.bh / 2.0) * 96.0)
	# a spot of free floor for the chest (the room's middle can hold a pillar)
	for k in range(45):
		var p := at + Vector2((k % 9 - 4) * 96.0, (k / 9 - 2) * 96.0)
		if not game.box_blocked(Rect2(p.x - 70, p.y - 60, 140, 140), true):
			at = p
			break
	game.place_dormant_mimic(room.index, at)
	var chest: Dictionary = game.W.ents[game.W.ents.size() - 1]
	_go(at + Vector2(0, 80))
	await _frames(2)
	# Act
	game.act()
	await _frames(2)
	# Assert
	var mimic: Dictionary = {}
	for m: Dictionary in game.mobs:
		if m.id == "mimik":
			mimic = m
	check(not mimic.is_empty(), "the mimic chest wakes as a mimic")
	check(game.W.ents.all(func(e: Dictionary) -> bool: return not is_same(e, chest)), "the woken chest is gone")
	check(not game.box_blocked(Rect2(at.x - 40, at.y - 32, 80, 32)), "no solid of the chest is left where it stood")
	if not mimic.is_empty():
		var hp: float = mimic.hp
		mimic.hp = 100.0
		game._damage_mob(mimic, Vector2.ZERO, 1.0)
		check(float(mimic.hp) < 100.0, "the mimic takes hits")
		check(not game.box_blocked(Rect2((mimic.p as Vector2) - Vector2(20, 20), Vector2(40, 20))), "the mimic stands free to move")
		mimic.hp = hp


func _test_crate_undead_stand_on_free_floor() -> void:
	# Arrange: a crate with undead right at a north wall of a fight room
	_calm()
	var room: Dictionary = {}
	for r: Dictionary in game.W.rooms:
		if r.type == "combat" and int(r.bw) >= 20:
			room = r
			break
	var crate := {"type": "crate", "look": "crate_a", "hp": 1, "max_hp": 1, "drop": "undead", "x": (room.bx + 0.5) * 96.0, "y": (room.by + 0.85) * 96.0, "room": room.index}
	game.W.ents.append(crate)
	game.breakables.append(crate)
	# Act
	game._hit_breakable(crate, Vector2(crate.x, crate.y - 20))
	# Assert
	check(crate.get("broken", false), "the crate breaks")
	var undead: Array = game.mobs.filter(func(m: Dictionary) -> bool: return m.room == room.index)
	check(undead.size() == 2, "two undead climb out")
	for m: Dictionary in undead:
		var p: Vector2 = m.p
		check(game._room_at_world(p.x, p.y) == room.index and not game.box_blocked(Rect2(p.x - 30, p.y - 30, 60, 30), true), "an undead stands on free floor of the room, not in the wall (%s)" % str(p))


func _test_roster_mimic_waits_as_a_chest() -> void:
	# Arrange: floor 5 (its roster has mimics), a fight room whose roster draw gives only mimics
	game.load_floor(5, true)
	await _frames(2)
	_calm()
	var room: Dictionary = {}
	for r: Dictionary in game.W.rooms:
		if r.type == "combat":
			room = r
			break
	room.cleared = false
	var floors: Dictionary = game.monsters.floors
	var roster: Array = floors["5"].mobs
	floors["5"].mobs = ["mimik"]
	var chests_before: int = game.W.ents.filter(func(e: Dictionary) -> bool: return e.type == "chest" and e.get("mimic", false)).size()
	# Act
	game._start_fight(room)
	floors["5"].mobs = roster
	# Assert
	check(game.mobs.all(func(m: Dictionary) -> bool: return m.id != "mimik"), "no mimic of the roster fights as a monster")
	var chests_after: int = game.W.ents.filter(func(e: Dictionary) -> bool: return e.type == "chest" and e.get("mimic", false)).size()
	check(chests_after > chests_before, "the roster's mimics wait as chests")
