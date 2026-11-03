extends SceneTree
## The loading screens (src/ui/loading_screen.gd, assets/data/ui_loading.json): what is rolled, which
## hints come, whose hero runs, that the world waits behind a screen and that a screen ends.
## Usage:
##   godot --headless --path . --script res://tests/loading_screen_test.gd
const LoadingScreen = preload("res://src/ui/loading_screen.gd")
const SCENES := {"krypta": "res://src/hell/krypta_dungeon.tscn", "hell": "res://src/hell/hell_dungeon.tscn", "frost": "res://src/hell/frost_dungeon.tscn"}

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
		print("LOADING_SCREEN_FAIL: ", what)


func _run() -> void:
	_test_variant_rolls()
	_test_data()
	_test_hints()
	_test_sprites()
	await _test_screen_ends()
	await _test_in_game()
	await _test_walking_down()
	await _test_menu()
	await _test_way_back()
	print("LOADING_SCREEN_TEST_PASS" if _failed == 0 else "LOADING_SCREEN_TEST_FAILED %d" % _failed)
	quit(1 if _failed > 0 else 0)


func _data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LoadingScreen.DATA_PATH))


func _test_variant_rolls() -> void:
	var w := {"A": 42, "B": 12, "C": 46}
	_check(LoadingScreen.pick_variant(w, 0.0) == "A", "roll 0 lands on the first")
	_check(LoadingScreen.pick_variant(w, 0.419) == "A", "just below A's share")
	_check(LoadingScreen.pick_variant(w, 0.42) == "B", "A's share ends at 0.42")
	_check(LoadingScreen.pick_variant(w, 0.54) == "C", "B's share ends at 0.54")
	_check(LoadingScreen.pick_variant(w, 1.0) == "C", "roll 1 lands on the last")
	# the user's wish: often a hint, now and then none
	var data := _data()
	var weights: Dictionary = data.weights
	var hinted := float(weights.A) + float(weights.C)
	_check(hinted / (hinted + float(weights.B)) >= 0.75, "screens with a hint are the rule")
	_check(float(weights.B) > 0.0, "a screen without a hint still comes")


func _test_data() -> void:
	var data := _data()
	for world: String in SCENES:
		var info: Dictionary = data.worlds.get(world, {})
		_check(not str(info.get("title", "")).is_empty(), "%s has a title" % world)
		_check(not (info.get("mobs", []) as Array).is_empty(), "%s has monsters for the chase" % world)
		for mob: Dictionary in info.get("mobs", []):
			for f in range(int(mob.frames)):
				_check(ResourceLoader.exists(str(mob.path) % f), "%s frame %s" % [world, str(mob.path) % f])
		_check((data.hints.get(world, []) as Array).size() >= 10, "%s has its own hints" % world)
	_check((data.hints.general as Array).size() >= 20, "plenty of general hints")
	for pool: String in data.hints:
		for h: Dictionary in data.hints[pool]:
			_check(not str(h.get("t", "")).is_empty() and not str(h.get("x", "")).is_empty(), "%s: heading and text" % pool)
			_check(str(h.get("x", "")).length() <= 130, "%s/%s fits the plate" % [pool, h.get("t", "")])


func _test_hints() -> void:
	var all := {"general": [{"t": "g1", "x": "."}, {"t": "g2", "x": "."}], "frost": [{"t": "f1", "x": "."}, {"t": "f2", "x": "."}], "mage": [{"t": "m1", "x": "."}]}
	var shares := {"world_share": 0.5, "class_share": 0.2}
	var seen: Array = []
	_check(str(LoadingScreen.next_hint(all, shares, "frost", "mage", seen, 0.1, 0.0).t) == "f1", "a low roll takes the world's")
	_check(str(LoadingScreen.next_hint(all, shares, "frost", "mage", seen, 0.6, 0.0).t) == "m1", "the next share takes the class's")
	_check(str(LoadingScreen.next_hint(all, shares, "frost", "mage", seen, 0.9, 0.0).t) == "g1", "the rest takes the general ones")
	# no hint twice until the pool has been through
	_check(str(LoadingScreen.next_hint(all, shares, "frost", "mage", seen, 0.1, 0.0).t) == "f2", "the world's second comes next")
	var again := str(LoadingScreen.next_hint(all, shares, "frost", "mage", seen, 0.1, 0.0).t)
	_check(again == "f1", "a pool through starts over, was %s" % again)
	# a class or world without hints falls back
	_check(str(LoadingScreen.next_hint(all, shares, "nowhere", "", [], 0.1, 0.0).t) == "g1", "an unknown world takes the general ones")
	_check(LoadingScreen.next_hint({}, shares, "frost", "mage", [], 0.1, 0.0).is_empty(), "no hints at all: none")


func _test_sprites() -> void:
	for sprite: String in ["knight_m", "elf_f", "wizzard_m", "necromancer"]:
		_check(LoadingScreen.frames_of(sprite, "run").size() == 4, "%s runs" % sprite)
		_check(LoadingScreen.frames_of(sprite, "idle").size() == 4, "%s stands" % sprite)
	_check(LoadingScreen.frames_of("nobody", "run").is_empty(), "no sprite, no frames")


func _test_screen_ends() -> void:
	for variant: String in ["A", "B", "C"]:
		var screen := LoadingScreen.new()
		root.add_child(screen)
		screen.start_story({"world": "frost", "floor_line": "Etage 2", "hero": "elf_f", "class_id": "archer", "seen": [], "variant": variant})
		_check(screen.variant == variant, "the asked variant")
		_check(screen.title == "FROSTGRUFT", "the world's title")
		_check(screen.hero_sprite == "elf_f", "the played hero")
		_check(screen.hint.is_empty() == (variant == "B"), "%s: hint only in A and C" % variant)
		_check(not screen._run.is_empty() and not screen._mobs.is_empty(), "%s: hero and monsters are there" % variant)
		screen.hold = 0.05
		var ended := [false]
		screen.finished.connect(func(_s: PackedScene) -> void: ended[0] = true)
		var frames := 0
		while not ended[0] and frames < 3000:
			frames += 1
			await process_frame
		_check(ended[0], "%s ends on its own" % variant)
		await process_frame
		_check(not is_instance_valid(screen), "%s removes itself" % variant)
	var skip := LoadingScreen.new()
	root.add_child(skip)
	skip.start_story({"world": "hell", "hero": "knight_m", "seen": [], "variant": "A"})
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	skip._input(key)
	_check(skip._fade < 0.0, "no skip in the first moment")
	skip._t = 1.0
	skip._input(key)
	_check(skip._fade >= 0.0, "E skips afterwards")
	skip.queue_free()
	await process_frame


func _test_in_game() -> void:
	for world: String in SCENES:
		var game: Node = (load(SCENES[world]) as PackedScene).instantiate()
		game.loading_forced = true
		root.add_child(game)
		await process_frame
		_check(game.loading_screen != null, "%s: a screen on entering" % world)
		if game.loading_screen == null:
			game.queue_free()
			continue
		_check(game.loading_screen.title == str(_data().worlds[world].title), "%s: the world's title, was %s" % [world, game.loading_screen.title])
		_check(game.loading_screen.hero_sprite == str(game.hero.get("sprite", "knight_m")), "%s: the played hero" % world)
		_check(game._simulation_paused(), "%s: the world waits" % world)
		game.loading_screen.hold = 0.0
		game.loading_screen._end()
		game.loading_screen._finish()
		_check(game.loading_screen == null, "%s: the screen is gone" % world)
		_check(not game._simulation_paused(), "%s: the world goes on" % world)
		# a debug jump shows none, a real floor does
		game._no_loading_once = true
		game.load_floor(2, true)
		_check(game.loading_screen == null, "%s: no screen on a debug jump" % world)
		game.load_floor(2, true)
		_check(game.loading_screen != null, "%s: a screen on the next floor" % world)
		_check(str(game.loading_screen.floor_line).contains("2"), "%s: the floor on it" % world)
		game.queue_free()
		await process_frame
	# without the flag (every other test, every capture) no screen comes
	var quiet: Node = (load(SCENES.krypta) as PackedScene).instantiate()
	root.add_child(quiet)
	await process_frame
	_check(quiet.loading_screen == null, "no screen in a script run")
	quiet.queue_free()
	await process_frame


## On foot the screen stands before the floor is built, and gets the floor's name afterwards.
func _test_walking_down() -> void:
	var game: Node = (load(SCENES.krypta) as PackedScene).instantiate()
	game.loading_forced = true
	root.add_child(game)
	await process_frame
	game.loading_screen.queue_free()
	game.loading_screen = null
	var before: int = int(game.state.floor)
	var walking: Dictionary = game.state
	game._enter_floor(3, true)
	_check(game.loading_screen != null, "the screen comes first")
	_check(game.state == walking and int(game.state.floor) == before, "the floor is not built yet")
	_check(str(game.loading_screen.floor_line) == "Etage 3", "it names the floor, was %s" % game.loading_screen.floor_line)
	var first: Node = game.loading_screen
	await process_frame
	await process_frame
	await process_frame
	_check(int(game.state.floor) == 3, "then the floor is built")
	_check(game.loading_screen == first, "under the same screen")
	_check(str(first.floor_line).begins_with("Etage 3") and str(first.floor_line).length() > 7, "with its name, was %s" % first.floor_line)
	game.queue_free()
	await process_frame


## Leaving the game: the parade, once, however often it is asked for.
func _test_way_back() -> void:
	var game: Node = (load(SCENES.krypta) as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._return_to_menu()
	var parade: Node = game.loading_screen
	_check(parade != null and parade.variant == "menu", "the way back shows the parade")
	_check(game._simulation_paused(), "the world waits on the way back")
	game._return_to_menu()
	_check(game.loading_screen == parade, "a second call changes nothing")
	game.load_floor(2, true)
	_check(game.loading_screen == parade, "no floor screen over the parade")
	parade.hold = 9999.0
	var frames := 0
	while parade._menu_scene == null and not parade._menu_failed and frames < 2400:
		frames += 1
		await process_frame
	_check(parade._menu_scene != null, "the menu loads behind it")
	game.queue_free()
	await process_frame


func _test_menu() -> void:
	var screen := LoadingScreen.new()
	root.add_child(screen)
	screen.start_menu("res://src/main.tscn")
	_check(screen.variant == "menu", "the parade")
	_check(screen._parade.size() == 4, "four heroes, %d" % screen._parade.size())
	var got: Array = []
	screen.finished.connect(func(scene: PackedScene) -> void: got.append(scene))
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	screen._t = 5.0
	screen._input(key)
	_check(got.is_empty(), "the way back is not skipped past its loading")
	var frames := 0
	while got.is_empty() and frames < 2400:
		frames += 1
		await process_frame
		screen.hold = 0.0
	_check(not got.is_empty(), "the parade ends once the menu is loaded")
	if not got.is_empty():
		_check(got[0] is PackedScene, "the menu scene comes with it")
	screen.queue_free()
	await process_frame
