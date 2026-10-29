extends SceneTree
## A dungeon crawler (docs/LAUF-DESIGN.de.md): death ends the run in every
## world. In the Hell-Dungeon and the Frostgruft the hero no longer stands up
## on the floor; the run's saves are deleted (other runs' saves stay); the
## result panel waits for E, which starts a fresh run on floor 1; R no longer
## restarts a floor; a run in a slot keeps that slot at its newest floor start;
## the crypt deletes its run's saves when the team falls.

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const SaveStore = preload("res://src/save/save_store.gd")
const StorySave = preload("res://src/save/story_save.gd")
const DIR := "user://run_end_test_saves/"
const META := "user://run_end_test_meta.cfg"

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("RUN_END_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_story(HellScene, "hell")
	await _test_story(FrostScene, "frost")
	_test_store()
	_clean()
	print("RUN_END checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _clean() -> void:
	var store := SaveStore.new(DIR)
	for mode: String in ["hell", "frost", "crypt"]:
		for slot in range(1, 4):
			store.erase(mode, slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META))


func _open(scene: PackedScene) -> Node:
	var game: Node = scene.instantiate()
	game.class_id = "swordsman"
	game.meta_path = META
	game.saves = SaveStore.new(DIR)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	return game


func _test_story(scene: PackedScene, world: String) -> void:
	_clean()
	var game: Node = await _open(scene)
	var mode := StorySave.mode(game)
	check(str(game.state.get("run_id", "")) != "", "%s: a run has its own id" % world)
	# another run's save in slot 3 must survive this run's death
	var other: Dictionary = game.floor_save.duplicate(true)
	other.run_id = "someone-else"
	game.saves.write(mode, 3, other)
	check(game.save_slot(1), "%s: the run saves into slot 1" % world)
	check(game.run_slot == 1, "%s: the run remembers its slot" % world)
	# the next floor start updates the run's slot
	game.load_floor(2, true)
	check(int(game.saves.read(mode, 1).get("floor", 0)) == 2, "%s: the run's slot follows to the next floor" % world)
	# death: no standing up on the floor any more
	game.state.inv = 0.0
	game._hurt("vom Test erschlagen", 999)
	check(float(game.state.dead) > 0.0, "%s: the hero falls" % world)
	game._update(2.0)
	check(not (game.state.get("over", {}) as Dictionary).is_empty(), "%s: death ends the run" % world)
	check(int(game.state.hp) == 0, "%s: no full hearts on the same floor" % world)
	check(game.saves.read(mode, 1).is_empty(), "%s: the run's save is deleted" % world)
	check(not game.saves.read(mode, 3).is_empty(), "%s: another run's save stays" % world)
	var result: Dictionary = game.run_result(game.state.over)
	check(str(result.title) == "LAUF BEENDET" and str(result.hints).contains("NEUER LAUF"), "%s: the result panel offers a new run" % world)
	check((result.lines as Array).any(func(row: Array) -> bool: return str(row[0]) == "URSACHE"), "%s: the panel names the cause" % world)
	# R does nothing now; E starts a fresh run on floor 1
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	game._unhandled_input(key)
	check(not (game.state.get("over", {}) as Dictionary).is_empty(), "%s: R no longer restarts the floor" % world)
	var count := root.get_child_count()
	var script: Script = game.get_script()
	var old_id := str(game.state.run_id)
	game.act()
	await process_frame
	await process_frame
	var fresh: Node = root.get_child(root.get_child_count() - 1)
	var started: bool = is_instance_valid(fresh) and fresh.get_script() == script and not fresh.is_queued_for_deletion()
	check(started and not is_instance_valid(game), "%s: E starts a new run and the old one goes" % world)
	if started:
		check(int(fresh.state.floor) == 1 and int(fresh.state.level) == 1 and str(fresh.class_id) == "swordsman", "%s: the new run begins on floor 1 at level 1 with the same class" % world)
		check(str(fresh.state.run_id) != old_id, "%s: the new run has a new id" % world)
		fresh.queue_free()
	check(count >= 1, "%s: the tree kept its nodes" % world)
	await process_frame


func _test_store() -> void:
	_clean()
	var store := SaveStore.new(DIR)
	store.write("crypt", 1, {"run_id": "crypt-111", "floor": 2})
	store.write("crypt", 2, {"run_id": "crypt-222", "floor": 4})
	store.write("crypt", 3, {"run_id": "crypt-111", "floor": 3})
	check(store.erase_run("crypt", "crypt-111") == 2, "a run's every slot goes")
	check(store.read("crypt", 1).is_empty() and store.read("crypt", 3).is_empty() and not store.read("crypt", 2).is_empty(), "only that run's slots go")
	check(store.erase_run("crypt", "") == 0, "an empty id deletes nothing")
