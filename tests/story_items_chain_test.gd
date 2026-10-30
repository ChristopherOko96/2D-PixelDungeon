extends SceneTree
## Regression: the run potions aftershock (blast) and chain lightning (storm) of item system 2
## (src/hero/story_items.gd) hit other monsters; those follow-up hits must not start a new
## aftershock or chain. Two monsters side by side bounced the hits back and forth until the
## script stack overflowed (reported in Story 1, the crypt world).

const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("STORY_ITEMS_CHAIN_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Arrange: the crypt world, a hero with both potions, three skeletons side by side
	var game: Node = KryptaScene.instantiate()
	game.class_id = "swordsman"
	root.add_child(game)
	await process_frame
	game.story_items.players[1]["build"] = {"blast": 1.0, "storm": 1.0}
	var room: int = game.state.room
	var at := Vector2(game.player.x + 300.0, game.player.y)
	var mobs: Array = []
	for k in range(3):
		var m: Dictionary = game.monsters.spawn(room, at + Vector2(k * 40.0, 0.0), "skelett")
		m.spawn = 0.0
		m.hp = 1000.0
		m.max = 1000.0
		mobs.append(m)
	var before: Array = mobs.map(func(m: Dictionary) -> float: return m.hp)
	# Act: one hit on the first skeleton
	game._damage_mob(mobs[0], Vector2.ZERO, 0.01)
	# Assert: it returns (no endless chain), and the neighbours took exactly the follow-up hits
	check(true, "a hit with aftershock and chain lightning returns")
	check(float(mobs[0].hp) < float(before[0]), "the struck skeleton takes the hit")
	check(float(mobs[1].hp) < float(before[1]), "the neighbour takes the aftershock or chain")
	var drop: float = float(before[1]) - float(mobs[1].hp)
	check(drop < float(game.state.dmg) * 10.0, "the neighbour is not hit over and over (lost %.2f)" % drop)
	game.queue_free()
	await process_frame
	print("STORY_ITEMS_CHAIN checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
