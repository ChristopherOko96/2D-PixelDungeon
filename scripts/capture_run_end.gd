extends SceneTree
## Captures the end of a run in every world (docs/LAUF-DESIGN.de.md): the hero
## falls in the Hell-Dungeon and the Frostgruft and the result panel waits for a
## new run; a floor won in the Hell-Dungeon; the crypt's team falls. Uses its
## own save and talent files, so the player's data stays as it is.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_run_end.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const SaveStore = preload("res://src/save/save_store.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")

var _out := "res://production/qa/evidence/run-end"
var _node: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame


## Waits until the run has ended (the fall pause runs on game time).
func _until_over() -> void:
	for i in range(900):
		if not (_node.state.get("over", {}) as Dictionary).is_empty():
			break
		await process_frame
	await _wait(20)


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _story(scene: PackedScene, class_id: String) -> void:
	if _node != null:
		_node.queue_free()
		await process_frame
	_node = scene.instantiate()
	_node.class_id = class_id
	_node.meta_path = "user://run_end_capture_meta.cfg"
	_node.saves = SaveStore.new("user://run_end_capture_saves/")
	_node.start_floor = 3
	root.add_child(_node)
	await _wait(5)
	_node.state.offer = []
	for i in range(4):
		HeroKit.gain(_node, HeroKit.need(_node.theme.leveling, int(_node.state.level)) - int(_node.state.exp))
	_node.state.offer = []
	_node.state.cards_due = 0
	await _wait(120)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	# Hell-Dungeon: a floor won, then death
	await _story(HellScene, "mage")
	_node.state.won = true
	_node.state.crystals_floor = 2
	await _wait(10)
	await _shot("01-hoelle-etage-geschafft")
	_node.state.won = false
	_node.state.inv = 0.0
	_node._hurt("vom Glutwächter zermalmt", 999)
	await _until_over()
	await _shot("02-hoelle-lauf-beendet")
	# Frostgruft: death in a pit
	await _story(FrostScene, "archer")
	_node._fall_into_pit()
	_node.state.hp = 0
	_node.state.dead = 0.1
	await _until_over()
	await _shot("03-frost-lauf-beendet")
	_node.queue_free()
	_node = null
	await process_frame
	# crypt: the team falls
	var game: Node = Game.new()
	game.saves = SaveStore.new("user://run_end_capture_saves/")
	root.add_child(game)
	await _wait(40)
	var entry: Dictionary = {}
	for e: Dictionary in game.main_menu.debug_entries:
		if str(e.label).contains("RAUM 02"):
			entry = e
	game.requested_seed = 4242
	game.main_menu._pick_debug(entry)
	game.main_menu._choose_class("swordsman")
	await _wait(60)
	for id: int in game.players:
		game.players[id].hp = 0
	game._check_room_end()
	await _wait(30)
	await _shot("04-krypta-lauf-beendet")
	quit()
