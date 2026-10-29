extends SceneTree
## The Pixel / HD switch (src/core/graphics_settings.gd): one stored choice for
## every world; the Hell-Dungeon has both sets and switches at once (sprites,
## filtering, hero size), the Frostgruft and the crypt keep their pixel look and
## say so; the pause menu shows the choice; other options stay in the file.

const GraphicsSettings = preload("res://src/core/graphics_settings.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const PATH := "user://graphics_switch_test.cfg"

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("GRAPHICS_SWITCH_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_test_store()
	await _test_hell()
	await _test_frost()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("GRAPHICS_SWITCH checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_store() -> void:
	check(GraphicsSettings.mode(PATH) == "pixel", "without a file the game draws pixel art")
	var file := ConfigFile.new()
	file.set_value("options", "volume", 40)
	file.save(PATH)
	GraphicsSettings.store("hd", PATH)
	check(GraphicsSettings.mode(PATH) == "hd", "the choice is stored")
	var back := ConfigFile.new()
	back.load(PATH)
	check(int(back.get_value("options", "volume", 0)) == 40, "the other options stay in the file")
	GraphicsSettings.store("blurry", PATH)
	check(GraphicsSettings.mode(PATH) == "hd", "unknown modes are ignored")
	check(GraphicsSettings.other("hd") == "pixel" and GraphicsSettings.other("pixel") == "hd", "the switch flips between the two")
	var only_pixel := {"skins": {"pixel": {}}}
	check(GraphicsSettings.note(only_pixel, "hd").contains("nur PIXEL"), "a world without HD says it keeps pixel art")
	GraphicsSettings.store("pixel", PATH)


func _open(scene: PackedScene) -> Node:
	var game: Node = scene.instantiate()
	game.class_id = "mage"
	game.graphics_path = PATH
	root.add_child(game)
	await process_frame
	game.set_process(false)
	return game


func _test_hell() -> void:
	GraphicsSettings.store("hd", PATH)
	var game: Node = await _open(HellScene)
	check(game.graphics == "hd" and str(game.theme.sprites) == "res://assets/sprites/hell/", "a stored HD choice opens the Hell-Dungeon in its HD set")
	check(game.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and is_equal_approx(float(game.theme.hero_scale), 3.6), "HD draws smooth and at the HD hero size")
	var old_kit: RefCounted = game.story_hero
	check(game.apply_graphics("pixel"), "the Hell-Dungeon switches to pixel at once")
	check(str(game.theme.sprites) == "res://assets/sprites/hell_0x72/" and game.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pixel: the 0x72 hell set, crisp filtering")
	check(is_equal_approx(float(game.theme.hero_scale), 3.0) and game.story_hero != old_kit, "the hero's look follows the new size")
	check(game.tex.has("wall_top") or game.tex.size() > 50, "the pixel sprites are loaded")
	check(GraphicsSettings.mode(PATH) == "pixel", "the switch in the game stores the choice")
	game.open_pause()
	check(game.pause_menu.graphics_status.text == "Grafik: PIXEL" and game.pause_menu.graphics_button.text == "Zu HD wechseln", "the pause menu shows the choice and the way back")
	game.pause_menu.graphics_mode_requested.emit()
	check(game.graphics == "hd" and str(game.theme.sprites) == "res://assets/sprites/hell/", "the pause button switches to HD")
	game.queue_free()
	await process_frame


func _test_frost() -> void:
	GraphicsSettings.store("hd", PATH)
	var game: Node = await _open(FrostScene)
	check(str(game.theme.sprites) == "res://assets/sprites/frost/", "the Frostgruft keeps its own set (no hell sprites)")
	check(not game.apply_graphics("hd"), "the Frostgruft has no HD set yet")
	check(GraphicsSettings.note(game.theme, "hd").contains("nur PIXEL"), "the Frostgruft says it keeps pixel art")
	game.queue_free()
	await process_frame
