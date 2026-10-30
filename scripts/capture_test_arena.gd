extends SceneTree
## Captures the Testraum as a player uses it: the main menu with its button,
## the room with the test bar as a mage, elements set by the tool (a poison
## pool, frost gas, a void pool, a storm zone, ice, shadow), the Leerenrufer
## and the Frostleiche fetched, the frost specialisation given, and the room
## room started again as an archer, and left again (the profile path must be
## the one from before). Uses the test
## profile (Profile.default_path for a SceneTree script) and removes it and
## the Testraum's profile copy after.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_test_arena.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const TestArena = preload("res://src/debug/test_arena.gd")

var _out := "res://production/qa/evidence/testraum"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(6, int(_game.players[1].hp))
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


## Picks tool `label` in the bar and sets it at `at`.
func _place(label: String, at: Vector2) -> void:
	var bar: Control = _game._arena_bar
	for index in range(bar._tools.size()):
		if str(bar._tools[index].label) == label:
			bar._tool = index
	bar.place(at)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(40)
	await _shot("1-hauptmenue")
	var path_before: String = _game.progress.save_path
	_game.start_test_arena("mage")
	await _wait(90)
	print("ARENA active=%s room=%d phase=%s enemies=%d bar=%s profile=%s" % [str(_game.test_arena), _game.room, _game.phase, _game.enemies.size(), str(is_instance_valid(_game._arena_bar)), _game.progress.save_path])
	await _shot("2-testraum")
	var hero: Vector2 = _game.players[1].pos
	_place("PFÜTZE · GIFT", hero + Vector2(-150, -60))
	_place("PFÜTZE · LEERE", hero + Vector2(150, -70))
	_place("GAS · FROST", hero + Vector2(-60, 110))
	_place("BLITZ · STURMZONE", hero + Vector2(170, 90))
	_place("EIS · SPLITTER, RAUREIF", hero + Vector2(40, -140))
	_place("SCHATTEN", hero + Vector2(-200, 60))
	await _wait(40)
	await _shot("3-elemente")
	var bar: Control = _game._arena_bar
	for index in range(bar._enemies.size()):
		if str(bar._enemies[index].kind) == "boss":
			bar._enemy_pick.selected = index
	bar._fetch_enemy()
	for index in range(bar._enemies.size()):
		if str(bar._enemies[index].kind) == "frostleiche":
			bar._enemy_pick.selected = index
	bar._fetch_enemy()
	await _wait(60)
	print("ARENA enemies=%d phase=%s" % [_game.enemies.size(), _game.phase])
	await _shot("4-gegner")
	bar._clear_enemies()
	for index in range(bar._specs.size()):
		if str(bar._specs[index].id) == "frost":
			bar._spec_pick.selected = index
	bar._stage_pick.selected = 2
	bar.apply_spec()
	await _wait(10)
	print("ARENA build=%s" % str(_game.talent_combat.call("snapshot").get("1", {}).keys() if _game.talent_combat.has_method("snapshot") else []))
	await _shot("5-frostmagier")
	# the class changed: the room starts again with an archer
	_game.restart_test_arena("archer")
	await _wait(90)
	print("ARENA restarted active=%s class=%s bar=%s profile=%s" % [str(_game.test_arena), str(_game.player_classes.get(1, "")), str(is_instance_valid(_game._arena_bar)), _game.progress.save_path])
	await _shot("6-bogenschuetze")
	_game._leave_session("Testraum verlassen.")
	await _wait(20)
	print("ARENA left active=%s profile_back=%s" % [str(_game.test_arena), str(_game.progress.save_path == path_before)])
	await _shot("7-zurueck-im-menue")
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(TestArena._load(TestArena.DATA).get("profile_copy", "user://profile_testraum.json"))))
	quit(0)
