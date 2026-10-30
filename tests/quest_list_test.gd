extends SceneTree
## The Auftragsliste is a page of the pause menu, the same in every story:
## the crypt (src/game.gd), the Frostgruft and the Hölle (src/hell/hell_game.gd)
## all open src/pause_menu.gd with Esc, and its "Auftrag" page (section "quest")
## (src/ui/quest_view.gd) lists the floor's main goals in order and the side
## goals below. The world stands still while the menu is open in a solo run.

const Game = preload("res://src/game.gd")
const PauseMenu = preload("res://src/pause_menu.gd")
const QuestView = preload("res://src/ui/quest_view.gd")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const Profile = preload("res://src/progress/profile.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("QUEST_LIST_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_crypt_goals_from_a_snapshot()
	await test_crypt_menu()
	await test_story_menu(FrostScene, "Frostgruft")
	await test_story_menu(HellScene, "Hölle")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	print("QUEST_LIST checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _snapshot(cleared: int, boss_cleared: bool, phase: String) -> Dictionary:
	var rooms: Array = []
	for i in range(4):
		rooms.append({"id": "r%d" % i, "boss": i == 3, "cleared": i < cleared or (i == 3 and boss_cleared)})
	return {"floor_map": rooms, "floor_index": 2, "boss_name": "LEERENRUFER", "phase": phase,
		"horde": {"left": 3, "total": 10}, "loot_chests": {"chests": [{"kind": "chest", "open": true}, {"kind": "chest", "open": false}, {"kind": "urn", "open": false}]}}


func test_crypt_goals_from_a_snapshot() -> void:
	# Arrange / Act
	var goals := QuestView.crypt_goals(_snapshot(1, false, "combat"))
	var mains := goals.filter(func(g: Dictionary): return g.main)
	var sides := goals.filter(func(g: Dictionary): return not g.main)
	# Assert
	check(mains.size() == 3, "the crypt names rooms, boss and stairs as main goals")
	check(str(mains[0].text) == "Säubere die Räume (1/4)" and not mains[0].done, "room progress counts the cleared rooms")
	check(str(mains[1].text).begins_with("Besiege") and not mains[1].done, "the boss is a main goal")
	check(str(mains[2].text).ends_with("Ebene 3") and not mains[2].done, "the stairs lead to the next floor")
	check(sides.size() == 2 and str(sides[0].text) == "Halte die Horde auf (7/10)" and str(sides[1].text) == "Öffne die Truhen im Raum (1/2)", "horde and chests (not urns) are side goals")
	var done := QuestView.crypt_goals(_snapshot(3, true, "victory"))
	check(done.filter(func(g: Dictionary): return g.main and g.done).size() == 3, "a won floor ticks every main goal")
	var boss_only := QuestView.crypt_goals(_snapshot(0, true, "explore"))
	check(boss_only[1].done and not boss_only[0].done, "a beaten boss ticks off on its own")


func test_crypt_menu() -> void:
	var game: Node = Game.new()
	root.add_child(game)
	game.session_bind_ip = "127.0.0.1"
	await process_frame
	game.requested_seed = 4242
	game._start_solo(false, "swordsman")
	for i in range(40): await process_frame
	# Act
	game.set_pause_open(true, "quest")
	for i in range(3): await process_frame
	# Assert
	check(game.pause_menu.visible and game.pause_menu.quest_view.is_visible_in_tree(), "the crypt's pause menu has the Auftrag page")
	check(game.pause_menu.quest_view.goals.size() >= 3 and game.pause_menu.quest_view.title == "EBENE 1", "the crypt's Auftrag page lists the floor's goals")
	check(game.pause_menu.navigation.quest.text == "Auftrag", "the section is called Auftrag")
	game.set_pause_open(false)
	game.queue_free()
	await process_frame


func _esc(game: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game._unhandled_input(event)


func test_story_menu(scene: PackedScene, story: String) -> void:
	# Arrange
	var game: Node = scene.instantiate()
	game.start_floor = 1
	root.add_child(game)
	await process_frame
	check(game.pause_menu is PauseMenu and not game.pause_menu.visible, "%s uses the crypt's pause menu, closed at start" % story)
	# Act
	_esc(game)
	await process_frame
	game.pause_menu.select_section("quest")
	# Assert
	check(game.pause_menu.visible and game.pause_menu.section == "quest" and game.pause_menu.quest_view.is_visible_in_tree(), "Esc opens the pause menu with the Auftrag page in the %s" % story)
	var goals: Array = game.pause_menu.quest_view.goals
	var mains := goals.filter(func(g: Dictionary): return g.main)
	check(mains.size() >= 2 and mains.any(func(g: Dictionary): return str(g.text).begins_with("Besiege")), "the %s lists its main goals with the boss" % story)
	check(game.pause_menu.quest_view.title == "ETAGE 1", "the %s's page names the floor" % story)
	check(game.pause_menu.navigation.quest.visible and game.pause_menu.navigation.controls.visible and not game.pause_menu.navigation.party.visible, "the %s shows the story pages with Auftrag, without the crypt's party page" % story)
	check(game.pause_menu.controls_label.text.contains("Talente: 1 2 3 4"), "the %s's Steuerung page names its keys" % story)
	var t: float = game.state.t
	var x: float = game.player.x
	for i in range(10): await process_frame
	check(game.state.t == t and game.player.x == x, "the %s stands still while the menu is open" % story)
	_esc(game)
	await process_frame
	check(not game.pause_menu.visible, "Esc closes the menu in the %s" % story)
	for i in range(5): await process_frame
	check(game.state.t > t, "the %s runs again after closing" % story)
	game.queue_free()
	await process_frame
