extends SceneTree
## Captures the run talent tree (B) in the Hell-Dungeon, the Frostgruft and
## the crypt: a hero on level 8 with a few points spent and the rest open, the
## "+n" beside the level in the hero strip. The hero stays unhurt.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_run_tree.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")

var _out := "res://production/qa/evidence/run-tree"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _story(scene: PackedScene, class_id: String, take: Array, name: String) -> void:
	var game: Node = scene.instantiate()
	game.class_id = class_id
	root.add_child(game)
	await _wait(5)
	while int(game.state.level) < 8:
		HeroKit.gain(game, HeroKit.need(game.theme.leveling, int(game.state.level)) - int(game.state.exp))
	game.state.toasts = []
	for id: String in take:
		CardKit.take_node(game, id)
	game.state.toasts = []
	await _wait(60)
	await _shot(name + "-leiste")
	game.state.tree_open = true
	await _wait(10)
	await _shot(name + "-baum")
	game.queue_free()
	await _wait(3)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _story(HellScene, "mage", ["twin_fire", "wildfire", "twin_fire", "mg_focus"], "01-hoelle-magier")
	await _story(FrostScene, "swordsman", ["sw_heavy", "double_whirl", "wide_swing"], "02-frost-schwert")
	# crypt
	var game: Node = Game.new()
	root.add_child(game)
	await _wait(40)
	var entry: Dictionary = {}
	for e: Dictionary in game.main_menu.debug_entries:
		if str(e.label).contains("RAUM 02"):
			entry = e
	game.requested_seed = 4242
	game.main_menu._pick_debug(entry)
	game.main_menu._choose_class("archer")
	await _wait(30)
	while int(game.team_progress.team.level) < 8:
		game.team_progress.add_exp(game.team_progress.next_level_exp())
	var hero: Dictionary = game.players[1]
	for id: String in ["wide_volley", "double_volley", "ar_rapid", "splinter"]:
		game.team_progress.take_talent(hero, id)
	for i in range(30):
		hero.invulnerable = 5.0
		await process_frame
	game.tree_open = true
	game.run_hud.tree_open = true
	game.menu_button.visible = false
	await _wait(10)
	await _shot("03-krypta-bogen-baum")
	quit()
