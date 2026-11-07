extends SceneTree
## Pictures of the main menu's chapter system (docs/BEUTEORDNUNG.de.md 1) for production/qa/evidence/beuteordnung:
## the story choice of a fresh account (stories 2 and 3 locked), the choice after the mage won story 1 (story 2
## open, its hero waiting), the carry question and the DEBUG story choice. Uses the test progress file
## (StoryProgress.default_path() in a SceneTree script), never the player's own user://story_progress.json.
## Run (needs a window): godot --path . -s tools/capture/story_menu_shots.gd
const Game = preload("res://src/game.gd")
const StoryProgress = preload("res://src/progress/story_progress.gd")
const OUT := "res://production/qa/evidence/beuteordnung"


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	print("SHOT ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	StoryProgress.save_progress(StoryProgress.fresh())
	var game = Game.new()
	root.add_child(game)
	await process_frame
	var menu = game.main_menu
	menu._open_stories()
	await _shot("menu_story_gesperrt")
	var p := StoryProgress.fresh()
	StoryProgress.on_win(p, "mage", 1, {"gold": 342, "level": 9, "hp": 18, "max_hp": 24, "items": {"inventory": {"bag": [1, 2, 3, 4, 5, 6]}}}, 1, 3)
	StoryProgress.save_progress(p)
	menu._open_stories()
	await _shot("menu_story_held_wartet")
	menu._choose_story("frostgruft")
	for c: Dictionary in menu.story_run_requested.get_connections():
		menu.story_run_requested.disconnect(c.callable)
	menu._choose_class("mage")
	await _shot("menu_held_uebernehmen")
	menu._open_debug_stories()
	await _shot("menu_story_debug")
	# FORTSETZEN: the heroes of the Krypta's saves (this tool's own save folder)
	var store = load("res://src/save/save_store.gd").new("user://story_menu_shots_saves/")
	store.write("krypta", 1, {"class_id": "mage", "floor": 4, "level": 6, "title": "Knochengewölbe", "spec": "fire", "scene": "res://src/hell/krypta_dungeon.tscn", "keep": {"gold": 212, "hp": 14, "max_hp": 20}})
	store.write("krypta", 2, {"class_id": "archer", "floor": 7, "level": 9, "title": "Gruft der Wächter", "spec": "sniper", "scene": "res://src/hell/krypta_dungeon.tscn", "keep": {"gold": 455, "hp": 30, "max_hp": 36}})
	menu.saves = store
	menu._open_stories()
	await _shot("menu_story_fortsetzen")
	menu._continue_story("krypta")
	await _shot("menu_fortsetzen_helden")
	store.erase("krypta", 1)
	store.erase("krypta", 2)
	StoryProgress.save_progress(StoryProgress.fresh())
	quit(0)
