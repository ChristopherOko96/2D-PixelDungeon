extends SceneTree
## Captures the shared UI in the story worlds: the Hell-Dungeon's clean screen
## (no goal list, no help line), its pause menu pages (overview, quest, map,
## save) and the Frostgruft's quest page.
## Usage: godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_story_ui.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const SaveStore = preload("res://src/save/save_store.gd")

var _out := "res://production/qa/evidence/story-ui"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames): await process_frame


func _shot(name: String) -> void:
	await _wait(3)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


func _esc(game: Node) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	game._unhandled_input(e)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var hell: Node = HellScene.instantiate()
	hell.saves = SaveStore.new("user://story_ui_capture/")
	hell.class_id = "mage"
	root.add_child(hell)
	await _wait(60)
	await _shot("01-hoelle-bildschirm-frei")
	_esc(hell)
	await _shot("02-hoelle-pause-uebersicht")
	hell.pause_menu.select_section("quest")
	await _shot("03-hoelle-pause-auftrag")
	hell.pause_menu.select_section("map")
	await _shot("04-hoelle-pause-karte")
	hell.pause_menu.select_section("save")
	await _shot("05-hoelle-pause-speichern")
	hell.queue_free()
	await _wait(5)
	var frost: Node = FrostScene.instantiate()
	frost.saves = SaveStore.new("user://story_ui_capture/")
	frost.class_id = "archer"
	root.add_child(frost)
	await _wait(60)
	await _shot("06-frost-bildschirm-frei")
	_esc(frost)
	frost.pause_menu.select_section("quest")
	await _shot("07-frost-pause-auftrag")
	quit(0)
