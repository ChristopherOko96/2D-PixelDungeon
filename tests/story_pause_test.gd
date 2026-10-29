extends SceneTree
## One pause menu for every world (src/pause_menu.gd): Esc in the Hell-Dungeon
## and the Frostgruft opens the crypt's menu in its story mode (overview, quest,
## map, controls, display, save) and stops the world; the floor's goals sit on
## the quest page instead of the screen; a finished goal shows a short note; the
## crypt keeps its own pages (party, reward, session) and no quest page.

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const PauseMenu = preload("res://src/pause_menu.gd")
const FrostHud = preload("res://src/hell/frost_hud.gd")
const SaveStore = preload("res://src/save/save_store.gd")

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("STORY_PAUSE_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_world_opens_the_shared_menu(HellScene, "hell")
	await _test_world_opens_the_shared_menu(FrostScene, "frost")
	await _test_finished_goal_shows_a_note()
	await _test_crypt_keeps_its_pages()
	print("STORY_PAUSE checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _shown(menu: Control) -> Array:
	var out: Array = []
	for key: String in PauseMenu.SECTIONS:
		if menu.navigation[key].visible: out.append(key)
	return out


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e


func _test_world_opens_the_shared_menu(scene: PackedScene, world: String) -> void:
	# Arrange
	var game: Node = scene.instantiate()
	game.saves = SaveStore.new("user://story_pause_test/")
	root.add_child(game)
	await process_frame
	# Act
	game._unhandled_input(_esc())
	var t: float = game.state.t
	game._process(0.05)
	var menu: Control = game.pause_menu
	var quests: int = menu.quest_view.goals.size()
	# Assert
	check(menu is PauseMenu and menu.visible and menu.mode == "story", "%s: Esc opens the crypt's pause menu in story mode" % world)
	check(_shown(menu) == ["overview", "quest", "map", "controls", "display", "save"], "%s: overview, quest, map, controls, display, save (%s)" % [world, str(_shown(menu))])
	check(is_equal_approx(float(game.state.t), t), "%s: the world stands still" % world)
	check(quests == FrostHud.goals(game).size() and quests > 0, "%s: the floor's goals are on the quest page (%d)" % [world, quests])
	check(str(menu.overview_label.text).contains("Etage 1"), "%s: the overview names the floor" % world)
	menu.select_section("save")
	check(not menu.save_buttons[0].disabled, "%s: the save page can save" % world)
	game._unhandled_input(_esc())
	check(not menu.visible, "%s: Esc closes it again" % world)
	game.queue_free()
	await process_frame


func _test_finished_goal_shows_a_note() -> void:
	var game: Node = HellScene.instantiate()
	root.add_child(game)
	await process_frame
	game.state.t = 5.0
	FrostHud.track(game)
	game.state.boss_dead = true
	FrostHud.track(game)
	var notes: Array = (game.state.toasts as Array).map(func(t: Dictionary) -> String: return str(t.text))
	check(notes.any(func(n: String) -> bool: return n.begins_with("Auftrag erfüllt:")), "a finished goal shows a short note (%s)" % str(notes))
	game.queue_free()
	await process_frame


func _test_crypt_keeps_its_pages() -> void:
	var menu: Control = PauseMenu.new()
	root.add_child(menu)
	await process_frame
	var shown := _shown(menu)
	# the Auftragsliste is in every story, the crypt included (assignment, 29.10.2026)
	check("party" in shown and "session" in shown and "save" in shown and "quest" in shown, "the crypt keeps party, session and save, and has the quest page too (%s)" % str(shown))
	menu.queue_free()
	await process_frame
