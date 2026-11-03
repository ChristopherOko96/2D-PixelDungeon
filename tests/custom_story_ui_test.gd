extends SceneTree
## Isolated UI/authoring checks and current-world skin screenshots.
const PanelScript = preload("res://src/custom/custom_story_panel.gd")
const Data = preload("res://src/custom/custom_story_data.gd")
const StorySave = preload("res://src/save/story_save.gd")
var _checks: int = 0
var _failures: int = 0
var _panel: Control
var _dir: String
var _out := "res://production/qa/evidence/custom-story"


func _initialize() -> void:
	_dir = "res://tests/.tmp_custom_ui_%d" % Time.get_ticks_usec()
	_run.call_deferred()


func _check(ok: bool, name: String) -> void:
	_checks += 1
	if not ok: _failures += 1; printerr("CUSTOM_UI_FAIL " + name)


func _wait() -> void:
	for i in range(4): await process_frame


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for world: String in ["krypta", "frost", "hell"]:
		var value: Dictionary = Data.fresh_story(world, "Meine %s-Geschichte" % world)
		_check(str(Data.save_story(value, _dir).get("error", "")) == "", world + " saves in isolated library")
	_panel = PanelScript.new()
	_panel.storage_dir = _dir
	root.add_child(_panel)
	_panel.open()
	await _wait()
	_check(_panel._library.get_child_count() == 3, "hub lists all three saved stories")
	await _capture("ui-custom-library")
	for world: String in ["krypta", "frost", "hell"]:
		var value: Dictionary = Data.fresh_story(world, "Werkstatt · %s" % world)
		_panel.edit_story(value, str(value.rooms[1].id))
		await _wait()
		_check(_panel._canvas.world == world and _panel._props.item_count > 5, world + " current-world props and canvas")
		_check(_panel._canvas.size.x >= 360 and _panel._canvas.size.y >= 250, world + " canvas has usable space")
		_check(_panel._props.get_global_rect().end.x <= 1280, world + " palette stays inside window")
		await _capture("ui-custom-" + world)
	# Act: the floor preview runs the run's own generator on the open draft.
	var fresh: Dictionary = Data.fresh_story("krypta", "Vorschau")
	_panel.edit_story(fresh, str(fresh.rooms[1].id))
	_panel._seed.value = 4711
	_panel.show_preview(true)
	await _wait()
	_check(_panel._preview.visible and not _panel._canvas.visible and _panel._preview.raw.get("rooms", []).size() == int(fresh.rooms_per_floor), "floor preview builds a whole floor from the draft")
	await _capture("ui-custom-preview")
	_panel.show_preview(false)
	_check(_panel._canvas.visible and not _panel._preview.visible, "the preview button returns to the room canvas")
	# Act: the empty-room button creates a genuinely blank authoring canvas.
	_panel._new_room()
	_check(_panel._room().floor.is_empty() and _panel._room().ports.is_empty(), "new room has no inherited floor or doors")
	var canvas: Control = _panel._canvas
	canvas._checkpoint()
	canvas._erasing = false
	canvas._paint(Vector2i(3, 3))
	canvas._paint(Vector2i(4, 3))
	_check(_panel._room().floor.size() == 2, "floor brush changes the isolated draft")
	canvas.undo()
	_check(_panel._room().floor.is_empty(), "one undo restores the room")
	_panel.dirty = true
	_panel.go_back()
	_check(_panel._confirm.visible and _panel._editing, "back asks before losing an unsaved room")
	_panel._confirm.hide()
	# Act: deleting a story removes its file and its own save slots, nothing else.
	_panel.save_root = _dir
	var doomed: Dictionary = Data.list_stories(_dir)[0]
	var slots := StorySave.custom_saves_dir(doomed, false, _dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(slots))
	var slot_file := FileAccess.open(slots + "slot_1.json", FileAccess.WRITE)
	slot_file.store_string("{}")
	slot_file.close()
	_check(_panel.delete_story(doomed) and Data.list_stories(_dir).size() == 2, "delete removes exactly the chosen story")
	_check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(slots)), "delete removes the story's own save slots")
	_panel.queue_free()
	await process_frame
	Data.remove_tree(_dir)
	print("CUSTOM_STORY_UI checked=%d failures=%d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
