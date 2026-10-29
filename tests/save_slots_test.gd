extends SceneTree
## Local save slots (src/save/): three per mode, saving the start of a floor.
## The store itself; a crypt run saved on floor 3 and loaded again; a hell run
## saved after the portal and continued; the story pause menu; the main menu's
## LADEN / LÖSCHEN. Uses its own folder, never the player's saves.

const Game = preload("res://src/game.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const SaveStore = preload("res://src/save/save_store.gd")
const DIR := "user://save_slots_test/"

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("SAVE_SLOTS_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	_test_store_round_trip()
	_test_store_refuses_bad_input()
	await _test_crypt_floor_saved_and_loaded()
	await _test_hell_floor_saved_and_continued()
	await _test_main_menu_loads_and_erases()
	_clean()
	print("SAVE_SLOTS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _clean() -> void:
	var store := SaveStore.new(DIR)
	for mode: String in SaveStore.MODE_NAMES:
		for slot in range(1, SaveStore.SLOTS + 1):
			store.erase(mode, slot)


func _test_store_round_trip() -> void:
	# Arrange
	var store := SaveStore.new(DIR)
	var data := {"class_id": "mage", "floor": 3, "level": 7, "player": {"inventory": {"bag": [{"id": "ruby_staff"}]}, "spot": Vector2(4, 5)}}
	# Act
	var empty := store.summaries("crypt")
	var written := store.write("crypt", 2, data)
	var back := store.read("crypt", 2)
	var rows := store.summaries("crypt")
	# Assert
	check(empty.size() == 3 and empty.all(func(r: Dictionary) -> bool: return r.empty), "three empty slots to begin with")
	check(written and back.player == data.player and back.floor == 3 and back.mode == "crypt" and int(back.saved_at) > 0, "a slot gives back what was written, plus mode and time")
	check(not rows[1].empty and str(rows[1].text).contains("MAGIER") and str(rows[1].text).contains("LV 7") and str(rows[1].text).contains("EBENE 3"), "the slot line names class, level and floor (%s)" % rows[1].text)
	check(store.read("hell", 2).is_empty(), "modes keep their own slots")
	check(store.erase("crypt", 2) and store.read("crypt", 2).is_empty(), "a deleted slot is empty again")


func _test_store_refuses_bad_input() -> void:
	var store := SaveStore.new(DIR)
	check(not store.write("crypt", 0, {}) and not store.write("crypt", 4, {}) and not store.write("arena", 1, {}), "only slots 1 to 3 of known modes")
	var f := FileAccess.open(store.path("frost", 1), FileAccess.WRITE)
	f.store_string("kein Spielstand")
	f.close()
	check(store.read("frost", 1).is_empty(), "a broken file reads as an empty slot")
	store.erase("frost", 1)


func _new_game() -> Node:
	var game: Node = Game.new()
	game.saves = SaveStore.new(DIR)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	return game


func _test_crypt_floor_saved_and_loaded() -> void:
	# Arrange: a mage run on floor 3 with a level and a found staff
	var game: Node = await _new_game()
	game.main_menu.selected_story = "krypta"
	game.requested_seed = 777
	game._start_solo(false, "mage")
	game.floor_index = 2
	game._enter_next_floor()
	var hero: Dictionary = game.players[1]
	game.team_progress.team.level = 6
	game.inventory.add(hero, game.inventory.make_weapon("ruby_staff", true, ""))
	game.floor_save = game.CryptSave.capture(game)
	var floor_seed: int = game.floor_seed
	var bag: Array = hero.inventory.bag.map(func(item: Dictionary) -> String: return str(item.get("id", item.get("kind", ""))))
	# Act: save, then change the hero after the floor start
	var saved: bool = game.save_slot(1)
	hero.hp = 1
	game._leave_session()
	game.queue_free()
	await process_frame
	var loaded: Node = await _new_game()
	loaded._load_save("crypt", 1)
	# Assert
	var back: Dictionary = loaded.players.get(1, {})
	check(saved, "the host saves the floor start")
	check(loaded.floor_index == 3 and loaded.floor_seed == floor_seed and loaded.run_seed == 777, "loading rebuilds floor 3 from the run seed")
	check(str(back.get("class_id", "")) == "mage" and int(loaded.team_progress.team.level) == 6, "class and team level come back")
	check(back.inventory.bag.map(func(item: Dictionary) -> String: return str(item.get("id", item.get("kind", "")))) == bag, "the bag comes back item for item")
	check(int(back.hp) > 1, "the floor start counts, not what happened after it")
	check(not loaded.floor_save.is_empty() and int(loaded.floor_save.floor) == 3, "the loaded floor can be saved again")
	loaded._leave_session()
	loaded.queue_free()
	await process_frame


func _test_hell_floor_saved_and_continued() -> void:
	# Arrange: a hell run that leaves floor 1 with runestones and a level
	var game: Node = HellScene.instantiate()
	game.saves = SaveStore.new(DIR)
	game.class_id = "mage"
	root.add_child(game)
	await process_frame
	game.state.gems = 5
	game.state.level = 3
	game.load_floor(2, true)
	# Act
	var saved: bool = game.save_slot(1)
	game.state.gems = 0
	game._unhandled_input(_key(KEY_ESCAPE))
	var t: float = game.state.t
	game._process(0.05)
	var paused: bool = game.pause_menu.visible and is_equal_approx(float(game.state.t), t)
	game._unhandled_input(_key(KEY_ESCAPE))
	game.queue_free()
	await process_frame
	var again: Node = HellScene.instantiate()
	again.saves = SaveStore.new(DIR)
	var data: Dictionary = again.saves.read("hell", 1)
	again.class_id = str(data.get("class_id", ""))
	again.resume = data
	root.add_child(again)
	await process_frame
	# Assert
	check(saved and str(data.get("class_id", "")) == "mage", "the hell saves the start of floor 2")
	check(paused, "Esc pauses the world")
	check(int(again.state.floor) == 2 and int(again.state.gems) == 5 and int(again.state.level) == 3, "the save continues on floor 2 with its runestones and level")
	check(not again.pause_menu.visible, "a loaded world starts unpaused")
	again.queue_free()
	await process_frame


func _test_main_menu_loads_and_erases() -> void:
	# Arrange
	var game: Node = await _new_game()
	game.saves.write("frost", 3, {"class_id": "archer", "floor": 4, "level": 2, "scene": "res://src/hell/frost_dungeon.tscn", "keep": {}})
	var menu: Node = game.main_menu
	menu.saves = SaveStore.new(DIR)
	var asked: Array = []
	menu.save_load_requested.connect(func(mode: String, slot: int) -> void: asked.append([mode, slot]))
	# Act
	menu._open_saves()
	menu._show_save_mode("frost")
	var line: String = menu._save_lines[2].text
	var loadable: bool = not menu._save_load[2].disabled and menu._save_load[0].disabled
	menu._save_load[2].pressed.emit()
	menu._open_saves()
	menu._erase_slot(3)
	var armed: String = menu._save_erase[2].text
	var kept: bool = not menu.saves.read("frost", 3).is_empty()
	menu._erase_slot(3)
	# Assert
	check(line.contains("BOGENSCHÜTZE") and line.contains("ETAGE 4") and loadable, "the menu lists the slot and only full slots load (%s)" % line)
	check(asked == [["frost", 3]], "LADEN asks the game to load that slot")
	check(armed == "SICHER?" and kept and menu.saves.read("frost", 3).is_empty(), "LÖSCHEN asks once more, then deletes")
	game.queue_free()
	await process_frame


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e
