extends SceneTree
## Main menu flow: the title shows SPIELEN · CUSTOM STORYS · TALENTE · OPTIONEN · BEENDEN (Mehrspieler,
## Editor and the saves sit in the DEBUG hub); story cards start NEU through the hero
## choice or continue their world's newest save; Esc / Pad-B goes back one level in
## every panel and each panel dims the title; the hero cards come from the story
## classes; the talent screen marks the open class and shows only the run's class in a
## run; the old crypt run still starts and returns to the menu; the level choice lists
## the worlds. Uses a disposable loopback host like pause_menu_test; saves go to its
## own folder, never the player's.
## Run: godot --headless --path . -s res://tests/main_menu_flow_test.gd
const Game = preload("res://src/game.gd")
const SaveStore = preload("res://src/save/save_store.gd")
const TalentScreen = preload("res://src/ui/talent_screen.gd")
const Profile = preload("res://src/progress/profile.gd")
const SAVE_DIR := "user://main_menu_flow_test/"
var checked := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("MAIN_MENU_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _new_game() -> Node:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var port := PacketPeerUDP.new()
	port.bind(0, "127.0.0.1")
	game.port_input.text = str(port.get_local_port())
	port.close()
	game.session_bind_ip = "127.0.0.1"
	game.requested_seed = 24680
	return game

## An empty save folder of this test only.
func _empty_store() -> RefCounted:
	var store := SaveStore.new(SAVE_DIR)
	for mode: String in ["krypta", "frost", "hell"]:
		for slot in range(1, SaveStore.SLOTS + 1): store.erase(mode, slot)
	return store

func _cancel() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event

func _run() -> void:
	await _test_default_port_field_is_a_valid_port()
	await _test_title_shows_four_entries_and_the_hub_the_rest()
	await _test_story_choice_lists_numbered_stories_and_locks_unfinished_ones()
	await _test_story_card_continues_the_newest_save_of_its_world()
	await _test_story_two_frostgruft_requests_its_own_scene_with_the_hero()
	await _test_story_three_hell_dungeon_starts_with_the_hero_and_story_four_is_coming()
	await _test_back_goes_one_level_and_panels_dim_the_title()
	await _test_hero_cards_come_from_the_story_classes()
	await _test_talent_screen_marks_the_class_and_shows_only_the_run_class_in_a_run()
	await _test_multiplayer_opens_lobby_and_lobby_returns_to_menu()
	await _test_story_one_starts_solo_run_and_leaving_returns_to_menu()
	await _test_debug_room_jump_starts_in_that_room_with_earlier_rooms_cleared()
	await _test_debug_floor_two_starts_on_the_next_floor()
	await _test_level_choice_lists_story_worlds_and_floors()
	await _test_shake_option_scales_view_shake()
	finish()

## Regression: JSON numbers load as floats, so the port field read "7777.0",
## _port() returned 0 and every solo/story start failed outside the tests
## (which always overwrite the field).
func _test_default_port_field_is_a_valid_port() -> void:
	# Arrange
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	# Act
	var port: int = game._port()
	# Assert
	check(game.port_input.text == str(int(game.balance.network.port)), "the port field shows the configured port as a whole number")
	check(port == int(game.balance.network.port), "the untouched port field yields the configured port")
	game.queue_free()
	await process_frame

func _test_title_shows_four_entries_and_the_hub_the_rest() -> void:
	# Arrange / Act
	var game = await _new_game()
	var menu = game.main_menu
	# Assert
	var texts: Array = menu._buttons.map(func(b: Button) -> String: return b.text)
	var hub: Array = menu._hub_buttons.map(func(b: Button) -> String: return b.text)
	check(menu.visible and not game.lobby_ui.visible and not game.active, "the game opens on the main menu, not the lobby")
	check(texts == ["SPIELEN", "CUSTOM STORYS", "TALENTE", "OPTIONEN", "BEENDEN"], "the title includes the normal Custom Story entry (%s)" % [texts])
	check(hub.has("MEHRSPIELER (ALT)") and hub.has("CUSTOM-EDITOR") and hub.has("SPIELSTÄNDE"), "the debug editor opens the new custom area (%s)" % [hub])
	check(not menu._account_button.visible and not menu._account_label.visible, "without online accounts the account row is hidden")
	check(not game.solo_button.visible, "solo starts from the menu, not from the lobby")
	game.queue_free()
	await process_frame

func _test_story_choice_lists_numbered_stories_and_locks_unfinished_ones() -> void:
	# Arrange
	var game = await _new_game()
	var menu = game.main_menu
	# Act
	menu._open_stories()
	# Assert
	check(menu._story_panel.visible and menu._story_cards.size() == menu.stories.size() and menu.stories.size() >= 3, "the story button lists every story (%d)" % menu.stories.size())
	check(str(menu.stories[0].id) == "krypta" and menu._story_new.has("krypta"), "story 1, the crypt, is playable (NEU)")
	var locked_ok := true
	for story: Dictionary in menu.stories:
		if menu._story_new.has(str(story.id)) != bool(story.get("playable", false)): locked_ok = false
	check(locked_ok, "only playable stories get NEU; unfinished ones are locked")
	game.queue_free()
	await process_frame

func _test_story_card_continues_the_newest_save_of_its_world() -> void:
	# Arrange: one Frostgruft save in this test's own folder; only this test listens
	var game = await _new_game()
	var menu = game.main_menu
	var store = _empty_store()
	store.write("frost", 2, {"class_id": "archer", "floor": 4, "level": 2, "scene": "res://src/hell/frost_dungeon.tscn", "keep": {}})
	menu.saves = store
	for c: Dictionary in menu.save_load_requested.get_connections():
		menu.save_load_requested.disconnect(c.callable)
	var asked: Array = []
	menu.save_load_requested.connect(func(mode: String, slot: int) -> void: asked.append([mode, slot]))
	# Act
	menu._open_stories()
	var resume: Button = menu._story_continue["frostgruft"]
	var none: Button = menu._story_continue["krypta"]
	var focus: Control = menu.get_viewport().gui_get_focus_owner()
	# Assert
	check(resume.visible and resume.text == "FORTSETZEN · ETAGE 4", "a world with a save offers FORTSETZEN · ETAGE n (%s)" % resume.text)
	check(not none.visible and none.focus_mode == Control.FOCUS_NONE and menu._story_new["krypta"].visible, "a world without a save shows NEU alone; the hidden button takes no focus")
	check(focus == menu._story_new["krypta"], "the story choice focuses the first playable card")
	# Act
	resume.pressed.emit()
	# Assert
	check(asked == [["frost", 2]] and menu.selected_story == "frostgruft" and not menu._story_panel.visible, "FORTSETZEN loads that world's save slot")
	store.erase("frost", 2)
	game.queue_free()
	await process_frame

func _test_story_two_frostgruft_requests_its_own_scene_with_the_hero() -> void:
	# Arrange: the game's own handler would swap the scene, so only this test listens.
	var game = await _new_game()
	var menu = game.main_menu
	for c: Dictionary in menu.story_scene_requested.get_connections():
		menu.story_scene_requested.disconnect(c.callable)
	var requested: Array = []
	menu.story_scene_requested.connect(func(path: String, class_id: String): requested.append([path, class_id]))
	menu._open_stories()
	# Act: NEU first shows the hero cards, the hero choice opens the scene
	menu._choose_story("frostgruft")
	var heroes_first: bool = menu._class_panel.visible and requested.is_empty()
	menu._choose_class("mage")
	# Assert
	check(menu._story_new.has("frostgruft"), "story 2, the Frostgruft, is playable")
	check(heroes_first, "story 2 first shows the hero cards")
	check(requested == [["res://src/hell/frost_dungeon.tscn", "mage"]] and not menu._class_panel.visible and not game.active, "the hero choice asks for the frost scene with that class instead of the crypt run")
	check(ResourceLoader.exists("res://src/hell/frost_dungeon.tscn"), "the frost scene exists")
	game.queue_free()
	await process_frame

func _test_story_three_hell_dungeon_starts_with_the_hero_and_story_four_is_coming() -> void:
	# Arrange: only this test listens for the scene request
	var game = await _new_game()
	var menu = game.main_menu
	for c: Dictionary in menu.story_scene_requested.get_connections():
		menu.story_scene_requested.disconnect(c.callable)
	var requested: Array = []
	menu.story_scene_requested.connect(func(path: String, class_id: String): requested.append([path, class_id]))
	menu._open_stories()
	var ids: Array = menu.stories.map(func(story: Dictionary) -> String: return str(story.id))
	var three: int = ids.find("hell_dungeon")
	var four: int = ids.find("story_4")
	# Act
	menu._choose_story("hell_dungeon")
	var heroes_first: bool = menu._class_panel.visible and requested.is_empty()
	menu._choose_class("swordsman")
	# Assert
	check(three == 2 and int(menu.stories[three].number) == 3 and menu._story_new.has("hell_dungeon"), "story 3 is the playable Hell-Dungeon")
	check(heroes_first, "story 3 first shows the hero cards")
	check(requested == [["res://src/hell/hell_dungeon.tscn", "swordsman"]], "the hero choice opens the hell scene with that class")
	check(four == 3 and int(menu.stories[four].number) == 4 and not menu._story_new.has("story_4"), "story 4 is listed and locked")
	var texts: Array = menu._story_cards[four].get_children().map(func(n: Node) -> String: return (n as Label).text if n is Label else "")
	check(texts.any(func(t: String) -> bool: return t.begins_with("BALD VERFÜGBAR")), "story 4 says it is coming soon")
	var last: Control = menu._story_cards[menu._story_cards.size() - 1]
	check(last.position.y + last.size.y <= menu._story_panel.size.y - 40.0, "all four story cards fit in the panel above the back button")
	game.queue_free()
	await process_frame

func _test_back_goes_one_level_and_panels_dim_the_title() -> void:
	# Arrange
	var game = await _new_game()
	var menu = game.main_menu
	menu.saves = _empty_store()
	# Act: title → story → hero
	menu._open_stories()
	var dimmed: bool = menu._debug_dim.visible and not menu._buttons[0].visible and not menu._title_nodes[0].visible
	menu._choose_story("krypta")
	var focus: Control = menu.get_viewport().gui_get_focus_owner()
	# Assert
	check(dimmed, "a player panel dims the scene and hides the title card and buttons")
	check(focus == menu._class_cards[0], "the hero choice focuses the first hero card")
	check(menu._buttons[0].focus_mode == Control.FOCUS_NONE, "hidden title buttons take no focus")
	# Act / Assert: Esc one level at a time
	menu._unhandled_input(_cancel())
	check(menu._story_panel.visible and not menu._class_panel.visible, "Esc in the hero choice leads back to the story choice")
	check(menu.get_viewport().gui_get_focus_owner() == menu._story_new["krypta"], "back in the story choice that story's card has the focus")
	menu._unhandled_input(_cancel())
	check(not menu._panel_open() and menu._buttons[0].visible and not menu._debug_dim.visible, "Esc in the story choice leads back to the title")
	check(menu.get_viewport().gui_get_focus_owner() == menu._buttons[0], "back on the title SPIELEN has the focus")
	check(not menu.go_back(), "the bare title has nothing to go back to")
	# Act: debug hub → level choice → world, then back up
	var world: Dictionary = menu.story_worlds[0]
	menu._open_debug_hub()
	menu._open_debug()
	menu._open_world(str(world.id))
	menu.go_back()
	var at_list: bool = menu._debug_panel.visible
	menu.go_back()
	var at_hub: bool = menu._hub_panel.visible
	menu.go_back()
	check(at_list and at_hub and not menu._panel_open(), "Welt → Level-Auswahl → Debug-Hub → Titel, one level per Esc")
	# Act: a floor start's hero choice leads back to that world
	menu._open_world(str(world.id))
	menu._pick_story_floor(world, world.floors[0], false)
	menu.go_back()
	check((menu._world_panels[str(world.id)] as Panel).visible, "back from a floor start's hero choice shows that world again")
	# Act: options go straight back to the title
	menu._open_options()
	menu._unhandled_input(_cancel())
	check(not menu._options_panel.visible and menu._buttons[0].visible, "Esc closes the options")
	game.queue_free()
	await process_frame

func _test_hero_cards_come_from_the_story_classes() -> void:
	# Arrange
	var game = await _new_game()
	var menu = game.main_menu
	var story: Dictionary = TalentScreen.story_classes()
	# Act
	var texts: Array = []
	for node: Node in menu._class_panel.get_children():
		if node is Label: texts.append((node as Label).text)
	var joined := " | ".join(PackedStringArray(texts))
	# Assert
	check(not story.is_empty() and int(menu.hero_cards.mage.hp) == int(story.mage.hp), "the hero cards use the story classes' LP")
	check((menu.hero_cards.mage.paths as Array).size() == (Profile.data().classes.mage.specs as Array).size(), "the mage card lists every talent path")
	check(joined.contains("%d LP" % int(story.swordsman.hp)) and not joined.contains("HERZEN") and not joined.contains("TEMPO"), "the cards show LP, not the old crypt hearts and speed")
	check(joined.contains(str(story.swordsman.name)) and not joined.to_upper().contains("KRIEGER"), "the sword hero is the Schwertkämpfer")
	game.queue_free()
	await process_frame

func _test_talent_screen_marks_the_class_and_shows_only_the_run_class_in_a_run() -> void:
	# Arrange
	var game = await _new_game()
	var menu = game.main_menu
	# Act
	menu._open_talents()
	var screen = menu._talent_screen
	var tab: Button = screen._buttons["tab_" + str(screen.class_id)]
	# Assert
	check(screen.visible and menu._debug_dim.visible and not menu._buttons[0].visible, "the talent screen hides the title")
	check(tab.visible and not tab.disabled and tab.get_theme_color("font_color") == TalentScreen.TAB_GOLD, "the open class tab is gold, not greyed out")
	check(str(screen._class_names.get("swordsman", "")) == str(TalentScreen.story_classes().swordsman.name), "the class tabs take their names from the class data")
	check(not screen._buttons.has("difficulty") and screen._buttons.reset.position.y > 600.0, "the difficulty left the talent screen and the reset sits in the footer")
	# Act: opened from a run with a run page
	var page := {"title": "Lauf-Talente", "draw": func(_canvas: CanvasItem, _rect: Rect2) -> void: pass, "click": func(_pos: Vector2) -> bool: return true}
	screen.open(game.progress.data, game.progress.profile, game.progress.save_path, "mage", true, page)
	var only_run_class: bool = not screen._buttons.tab_archer.visible and screen._buttons.tab_mage.visible and screen._buttons.tab_run.visible
	screen.show_run_page()
	# Assert
	check(only_run_class, "in a run only the run's class and LAUF are tabs")
	check(screen._page == "run" and not screen._buttons.learn.visible and not screen._buttons.reset.visible, "show_run_page opens the LAUF tab without the class buttons")
	# Act
	screen.close()
	# Assert
	check(not screen.visible and not menu._panel_open() and menu._buttons[0].visible, "closing the talents returns to the title")
	game.queue_free()
	await process_frame

func _test_multiplayer_opens_lobby_and_lobby_returns_to_menu() -> void:
	# Arrange
	var game = await _new_game()
	# Act: MEHRSPIELER in the DEBUG hub
	game.main_menu._open_multiplayer()
	# Assert
	check(not game.main_menu.visible and game.lobby_ui.visible and game.host_button.visible and game.lobby_menu_button.visible, "multiplayer shows the host/join lobby")
	# Act
	game.lobby_menu_button.pressed.emit()
	# Assert
	check(game.main_menu.visible and not game.lobby_ui.visible and not game.main_menu._panel_open(), "the lobby's main menu button returns to the bare title screen")
	game.queue_free()
	await process_frame

func _test_story_one_starts_solo_run_and_leaving_returns_to_menu() -> void:
	# Arrange
	var game = await _new_game()
	# Act: story 1 opens the hero choice; picking a hero opens the crypt world (docs/WELT-BAUKASTEN.de.md)
	game.main_menu._open_stories()
	game.main_menu._choose_story("krypta")
	check(game.main_menu._class_panel.visible and not game.main_menu._story_panel.visible and not game.active, "a story first shows the hero cards")
	game.main_menu._choose_class("swordsman")
	await process_frame
	# Assert
	var world: Node = current_scene
	check(world != null and str(world.scene_file_path) == "res://src/hell/krypta_dungeon.tscn", "story 1 opens the crypt world scene")
	check(world != null and str(world.class_id) == "swordsman" and int(world.state.floor) == 1 and int(world.state.get("world_run", 0)) > 0, "the crypt starts on floor 1 of a freshly rolled world with the chosen hero")
	if world != null:
		world.queue_free()
	await process_frame
	# Act: the old endless run still runs the crypt's chain of rooms with the chosen class
	game = await _new_game()
	game.main_menu._open_classes(true)
	game.main_menu._choose_class("swordsman")
	game._refresh_ui()
	# Assert
	check(game.active and game.hosting and game.phase == "combat" and game.floor_index == 1, "the endless mode starts a solo run on floor 1")
	check(game.players[1].class_id == "swordsman" and game.players[1].melee and game.players[1].max_hp == 10, "the chosen hero class is applied to the solo player")
	check(not game.main_menu.visible and not game.lobby_ui.visible and game.run_hud.visible, "during the run neither menu nor lobby is visible")
	# Act
	game._leave_session()
	# Assert
	check(game.main_menu.visible and not game.lobby_ui.visible and not game.active, "leaving the run returns to the main menu")
	game.queue_free()
	await process_frame

func _test_debug_room_jump_starts_in_that_room_with_earlier_rooms_cleared() -> void:
	# Arrange
	var game = await _new_game()
	var entries: Array = game.main_menu.debug_entries
	var count: int = game._run_room_count()
	# Floor 1 rooms, floor 2, the three mini-boss floors and the Leerenrufer's floor.
	check(entries.size() == count + 5, "the debug list has every room of floor 1, floor 2, the mini-bosses and the boss")
	check(str(entries[count - 1].label).contains("ENDRAUM"), "floor 1's last room is labelled as its final room")
	check(str(entries[-1].label).contains("LEERENRUFER") and int(entries[-1].floor) == 10, "the last entry is the Leerenrufer on floor 10")
	# Act: a debug pick also goes through the hero choice.
	game.main_menu._pick_debug(entries[-1])
	game.main_menu._choose_class("mage")
	# Assert
	var bosses := 0
	for enemy: Dictionary in game.enemies:
		if bool(enemy.boss) and str(enemy.get("rig","")) == "void": bosses += 1
	check(game.phase == "combat" and game.room == count and game.floor_index == 10, "the boss entry starts in floor 10's last room")
	check(game.cleared_room_ids.size() == count - 1, "all rooms before the jump target count as cleared")
	check(bosses == 1, "the jumped-to boss room spawns exactly one Leerenrufer")
	check(game.main_menu.take_debug_start().is_empty(), "a debug jump is consumed once")
	game.queue_free()
	await process_frame

func _test_debug_floor_two_starts_on_the_next_floor() -> void:
	# Arrange
	var game = await _new_game()
	var entries: Array = game.main_menu.debug_entries
	var floor_two: Dictionary = {}
	for entry: Dictionary in entries:
		if int(entry.floor) == 2: floor_two = entry
	# Act
	game.main_menu._pick_debug(floor_two)
	game.main_menu._choose_class("archer")
	# Assert
	check(game.floor_index == 2 and game.room == 1 and game.phase == "combat", "the floor 2 entry starts in room 1 of floor 2")
	game.queue_free()
	await process_frame

func _test_level_choice_lists_story_worlds_and_floors() -> void:
	# Arrange
	var game = await _new_game()
	var menu = game.main_menu
	# Act: the debug level choice opens on the world list.
	menu._open_debug()
	# Assert: the three story worlds, each with its ten floors
	check(menu._debug_panel.visible, "the level choice opens on the world list")
	check(menu.story_worlds.size() == 3, "the level choice lists the three story worlds")
	for world: Dictionary in menu.story_worlds:
		check((world.floors as Array).size() == 10, "%s lists its ten floors" % str(world.title))
	var first: Dictionary = menu.story_worlds[0]
	menu._open_world(str(first.id))
	var panel: Panel = menu._world_panels[str(first.id)]
	check(panel.visible and not menu._debug_panel.visible, "a world shows its floor list")
	var buttons: Array = []
	for node: Node in panel.get_children():
		if node is Button: buttons.append(node)
	check(buttons.size() == 21, "each floor has a start and a boss button, plus back")
	check((buttons[1] as Button).text.begins_with("BOSS · "), "the boss button names the floor's boss")
	# Act: press floor 3's boss button (the hero choice comes first)
	(buttons[5] as Button).pressed.emit()
	# Assert
	check(int(menu._story_jump.get("floor", 0)) == 3 and bool(menu._story_jump.get("boss", false)), "the boss button asks for floor 3 at its boss after the hero choice")
	game.queue_free()
	await process_frame

func _test_shake_option_scales_view_shake() -> void:
	# Arrange
	var game = await _new_game()
	# Act
	game._apply_menu_settings({"shake": false, "fullscreen": false})
	# Assert
	check(is_zero_approx(game.view.shake_scale), "turning shake off removes camera shake")
	# Act
	game._apply_menu_settings({"shake": true, "fullscreen": false})
	# Assert
	check(is_equal_approx(game.view.shake_scale, 1.0), "turning shake on restores camera shake")
	game.queue_free()
	await process_frame

func finish() -> void:
	print("MAIN_MENU checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if not failures.is_empty() else 0)
