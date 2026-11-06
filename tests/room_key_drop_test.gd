extends SceneTree
## A key a cleared room drops (hell_game.gd _drop) always lies on free floor of that room that the hero
## can walk to, even when the last monster fell over a pit, in the Moder, against a wall or among the
## floor's fall pits (pit pieces: coming near one drops the hero back to the start): else the floor
## could not be finished.

const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const C := 96.0

var checked := 0
var failures: Array[String] = []
var game: Node


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("ROOM_KEY_DROP_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(3)
	game = KryptaScene.instantiate()
	game.class_id = "swordsman"
	game.graphics_path = "user://room_key_drop_graphics.cfg"
	root.add_child(game)
	for i in range(3):
		await process_frame
	_test_key_over_a_wall_lands_on_floor()
	_test_key_among_fall_pits_lands_away_from_them()
	game.queue_free()
	await process_frame
	print("ROOM_KEY_DROP checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## A wall cell right next to a floor cell of room `r`, as a world point: where a monster against the
## wall may fall.
func _wall_by(r: Dictionary) -> Vector2:
	for c: Vector2i in r.cells:
		for d: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			if game._cell(c.x + d.x, c.y + d.y) == 0:
				return Vector2((c.x + d.x + 0.5) * C, (c.y + d.y + 0.5) * C)
	return Vector2.INF


func _test_key_over_a_wall_lands_on_floor() -> void:
	var tried := 0
	for r: Dictionary in game.W.rooms:
		if str(r.type) != "combat":
			continue
		# Arrange: the last monster fell inside the wall
		var at := _wall_by(r)
		if at == Vector2.INF:
			continue
		tried += 1
		var before: int = game.W.ents.size()
		# Act
		game._drop("key", int(r.index), at, {"key": "B"})
		# Assert
		var e: Dictionary = game.W.ents[before]
		var box := Rect2(float(e.x) - 22.0, float(e.y) - 12.0, 44.0, 24.0)
		check(not game.box_blocked(box, true), "room %s: the key lies on free floor, not in the wall (%s)" % [r.name, Vector2(e.x, e.y)])
		check(game._room_at_world(float(e.x), float(e.y)) == int(r.index), "room %s: the key stays in its room" % r.name)
		game.W.ents.remove_at(before)
		if tried >= 6:
			break
	check(tried >= 3, "rooms to try (%d)" % tried)


func _test_key_among_fall_pits_lands_away_from_them() -> void:
	# Arrange: a fight room with fall pits set round the spot where its last monster fell
	var room: Dictionary = {}
	for r: Dictionary in game.W.rooms:
		if str(r.type) == "combat" and (r.cells as Array).size() > 40:
			room = r
			break
	var c: Vector2i = room.cells[(room.cells as Array).size() / 2]
	var at := Vector2((c.x + 0.5) * C, (c.y + 0.5) * C)
	var added: Array = []
	for d: Vector2 in [Vector2.ZERO, Vector2(60, 0), Vector2(-60, 0), Vector2(0, 50), Vector2(0, -50)]:
		var pit := {"type": "pit", "x": at.x + d.x, "y": at.y + d.y, "room": int(room.index)}
		game.W.ents.append(pit)
		game.pits.append(pit)
		added.append(pit)
	var before: int = game.W.ents.size()
	# Act
	game._drop("key", int(room.index), at, {"key": "B"})
	# Assert: the hero can stand on the key without coming near a pit
	var e: Dictionary = game.W.ents[before]
	var reach_x := float(game.balance.pit.reach_x)
	var reach_y := float(game.balance.pit.reach_y)
	var near: Array = (game.pits as Array).filter(func(p: Dictionary) -> bool: return absf(float(e.x) - float(p.x)) < reach_x + 20.0 and absf(float(e.y) - 8.0 - float(p.y)) < reach_y + 20.0)
	check(near.is_empty(), "the key lies clear of the fall pits (%s, %d pits near)" % [Vector2(e.x, e.y), near.size()])
	check(not game.box_blocked(Rect2(float(e.x) - 22.0, float(e.y) - 12.0, 44.0, 24.0), true), "the key lies on free floor")
	game.W.ents.remove_at(before)
	for p: Dictionary in added:
		game.W.ents.erase(p)
		game.pits.erase(p)
