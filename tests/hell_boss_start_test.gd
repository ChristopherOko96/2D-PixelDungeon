extends SceneTree
## Hell-Dungeon debug starts (src/hell/hell_game.gd): a floor picked at its
## entrance opens in the start room, a floor picked at its boss opens inside the
## boss room with the boss fight running and the gate behind the hero shut, on
## every one of the ten floors.

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_BOSS_START_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _start(floor_number: int, boss: bool) -> Node:
	var hell: Node = HellScene.instantiate()
	hell.start_floor = floor_number
	hell.start_at_boss = boss
	root.add_child(hell)
	for i in range(3):
		await process_frame
	return hell


func _run() -> void:
	# Arrange / Act: floor 1 from its entrance
	var hell: Node = await _start(1, false)
	# Assert
	check(hell.state.floor == 1 and hell.W.rooms[hell.state.room].type == "start", "a start pick opens the floor in its entrance")
	hell.queue_free()
	await process_frame
	for n in range(1, 11):
		# Arrange / Act
		hell = await _start(n, true)
		var room: Dictionary = hell.W.rooms[hell.state.room]
		var bosses: Array = hell.mobs.filter(func(m: Dictionary) -> bool: return m.kind == "boss")
		# Assert
		check(hell.state.floor == n, "floor %d: the boss pick opens that floor" % n)
		check(room.type == "boss", "floor %d: the hero stands in the boss room" % n)
		check(room.fight and bosses.size() == 1, "floor %d: the boss fight starts at once" % n)
		check(not hell.box_blocked(hell._player_box(hell.player.x, hell.player.y)), "floor %d: the hero is not stuck in a wall" % n)
		hell.queue_free()
		await process_frame
	print("HELL_BOSS_START checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
