extends SceneTree
## Dedicated Custom menu, hero selection, unsaved preview handoff and legacy launcher target.
const Menu = preload("res://src/main_menu.gd")
const Data = preload("res://src/custom/custom_story_data.gd")
const Progress = preload("res://src/progress/run_progress.gd")
const Profile = preload("res://src/progress/profile.gd")
var checked: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("CUSTOM_MENU_FAIL " + message)

func _run() -> void:
	var folder: String = "res://tests/.tmp_custom_menu_%d" % Time.get_ticks_usec()
	var menu: Control = Menu.new()
	menu.custom_story_directory = folder
	menu.progress = Progress.new()
	menu.progress.data = Profile.data()
	menu.progress.profile = Profile.fresh(menu.progress.data)
	menu.progress.save_path = folder + "/profile.json"
	var balance: Dictionary = DataCache.load_dict("res://src/data/balance.json")
	menu.classes = balance.get("classes", {})
	menu.class_order = balance.get("class_order", [])
	menu.weapons = balance.get("weapons", {})
	root.add_child(menu)
	await process_frame
	menu.set_process(false)
	var titles: Array = menu._buttons.map(func(button: Button) -> String: return button.text)
	check(titles == ["SPIELEN", "CUSTOM STORYS", "TALENTE", "OPTIONEN", "BEENDEN"], "Custom Stories are a normal title entry")
	menu.open_custom_stories()
	var panel: Control = menu.custom_story_panel
	check(panel.visible and menu._panel_open() and not menu._buttons[0].visible, "opening the hub dims and hides the title")
	var story: Dictionary = Data.fresh_story("krypta", "Menü-Fixture")
	panel.edit_story(story)
	check(panel.dirty, "an unsaved story stays marked unsaved")
	panel._new_room()
	check(panel.story.rooms[-1].floor.is_empty(), "a newly added room is a blank canvas")
	check(Data.list_stories(folder).is_empty(), "opening and editing do not autosave")
	panel._room_index = 0
	panel._sync_room()
	var chosen: Array = []
	menu.custom_story_requested.connect(func(value: Dictionary, hero: String, room: String) -> void: chosen.append({"story": value, "hero": hero, "room": room}))
	panel._start_play(true)
	check(menu._class_panel.visible, "a complete selected module can be tested with an unrelated unfinished room")
	check(not menu._pending_custom_room.is_empty(), "preview retains the exact selected room id")
	menu._class_back()
	check(panel.visible and panel.dirty and panel.story.rooms.size() == story.rooms.size() + 1, "cancelling hero choice keeps the unsaved draft")
	panel._start_play(true)
	menu._choose_class("mage")
	check(chosen.size() == 1 and str(chosen[0].hero) == "mage" and str(chosen[0].room) == str(story.rooms[0].id), "hero choice emits the custom runtime request, not a main story request")
	menu.open_custom_stories({"edit": true, "story": chosen[0].story, "room_id": chosen[0].room})
	check(panel.visible and panel.dirty and str(panel._room().id) == str(story.rooms[0].id), "returning from preview restores the unsaved room")
	menu.queue_free()
	await process_frame
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		for file: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("CUSTOM_MENU checked=%d failures=%d" % [checked, failures])
	quit(1 if failures > 0 else 0)
