extends SceneTree
## A gate locked with a room's own key (room_floor.gd own_key: "15A" = key A of room 15) shows on the
## map in the colour of its letter, like a floor key; the map never fails on such a key.

const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")

var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("ROOM_KEY_MAP_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = KryptaScene.instantiate()
	game.class_id = "swordsman"
	game.graphics_path = "user://room_key_map_graphics.cfg"
	root.add_child(game)
	for i in range(3):
		await process_frame
	# Arrange: a locked gate of room 15's own key A, between two calm rooms
	for r: Dictionary in game.W.rooms:
		r.fight = false
	var gate := {"a": 0, "b": 0, "kind": "lock", "unlocked": false, "key": "15A"}
	# Act
	var colour: Variant = game._door_color(gate)
	# Assert
	check(colour is Color and colour == game.key_color["A"], "the gate of key 15A has key A's colour (%s)" % str(colour))
	check(game.key_letter("15B") == "B" and game.key_letter("A") == "A", "a room key looks like its letter on gates and on the floor (%s, %s)" % [game.key_letter("15B"), game.key_letter("A")])
	game.queue_free()
	await process_frame
	print("ROOM_KEY_MAP checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
