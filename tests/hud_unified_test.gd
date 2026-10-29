extends SceneTree
## One neutral HUD for every world (src/ui/hud_style.gd, src/ui/hud_kit.gd):
## the crypt, the Hell-Dungeon and the Frostgruft draw the hero strip (hearts
## with the level beside them and the EXP line), the floor panel with its
## mini-map area, the menu chip, the boss bar, banners and hints from the same
## code and colours; no world keeps its own HUD tint; the level left the skill
## bar for the hero strip.

const HudStyle = preload("res://src/ui/hud_style.gd")
const HudKit = preload("res://src/ui/hud_kit.gd")
const SkillBar = preload("res://src/ui/skill_bar.gd")
const RunHud = preload("res://src/ui/run_hud.gd")
const FrostHud = preload("res://src/hell/frost_hud.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HEART := preload("res://assets/sprites/0x72/ui_heart_full.png")

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("HUD_UNIFIED_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_style()
	await _test_hero_strip()
	_test_floor_panel()
	await _test_story_worlds()
	print("HUD_UNIFIED checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_style() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HudStyle.DATA_PATH))
	check(HudStyle.color("accent") == Color(str(data.colors.accent)), "HUD colours come from ui_hud_style.json")
	# the panel is neutral: no hue of its own
	var panel := HudStyle.color("panel")
	check(absf(panel.r - panel.g) < 0.03 and absf(panel.g - panel.b) < 0.03, "the panel colour is a neutral grey, not a world tint")
	var constants: Dictionary = FrostHud.new().get_script().get_script_constant_map()
	check(not constants.has("GLOW") and not constants.has("EDGE"), "the story worlds' ice frame colours are gone")


func _canvas() -> Control:
	var canvas := Control.new()
	canvas.size = Vector2(1280, 720)
	root.add_child(canvas)
	return canvas


func _test_hero_strip() -> void:
	var canvas := _canvas()
	var font: Font = ThemeDB.fallback_font
	var hearts := {"full": HEART, "half": HEART, "empty": HEART}
	var rects: Array = []
	# drawn inside the canvas's own draw pass, as the HUDs do
	canvas.draw.connect(func() -> void:
		rects.append(HudKit.hero_panel(canvas, font, Vector2(16, 16), {"title": "P1 · MAGIER", "hp": 6, "max_hp": 6, "hearts": hearts, "level": 13, "exp": 0.4}))
		rects.append(HudKit.hero_panel(canvas, font, Vector2(16, 16), {"title": "P1 · MAGIER", "hp": 6, "max_hp": 6, "hearts": hearts}))
		rects.append(HudKit.hero_panel(canvas, font, Vector2(16, 16), {"title": "P1 · MAGIER", "hp": 6, "max_hp": 6, "hearts": hearts, "level": 2, "exp": 0.1,
			"resources": [{"icon": HEART, "text": "3"}], "status": [{"text": "SEGEN · ZORN"}]})))
	canvas.queue_redraw()
	await process_frame
	await process_frame
	check(rects.size() >= 3, "the hero strip draws in a draw pass")
	if rects.size() < 3: return
	var plain: Rect2 = rects[0]
	check(plain.position == Vector2(16, 16), "the hero strip sits in the top-left corner")
	check(plain.size.y <= 90.0, "the hero strip is compact (hearts, level and EXP in one strip)")
	var heart_row := 3.0 * (HudStyle.size("heart_size") + HudStyle.size("heart_gap"))
	check(plain.size.x > heart_row + 40.0, "the level badge sits beside the hearts")
	check((rects[1] as Rect2).size.x < plain.size.x, "without a level the strip has no badge")
	check((rects[2] as Rect2).size.y > plain.size.y, "resources and status lines extend the same strip")
	check(HudKit.heart_icons(5, 8) == ["full", "full", "half", "empty"], "two HP per heart, halves shown")
	check(RunHud.hearts(5, 8) == HudKit.heart_icons(5, 8), "the crypt counts hearts with the shared code")
	canvas.queue_free()
	await process_frame


func _test_floor_panel() -> void:
	var screen := Vector2(1280, 720)
	var panel := HudKit.floor_rect(screen)
	var area := HudKit.map_area(screen)
	check(panel.end.x == screen.x - HudStyle.size("margin") and panel.position.y == HudStyle.size("margin"), "the floor panel sits in the top-right corner")
	check(panel.encloses(area) and area.position.y > panel.position.y + 40.0 and area.size.y > 40.0, "the mini-map has its area under the floor's lines")
	check(HudKit.menu_rect(screen).position.y > panel.end.y, "the menu chip sits under the floor panel")
	var hud: Control = RunHud.new()
	hud.size = screen
	check(hud.map_panel_rect() == panel, "the crypt's floor panel is the shared one")
	check(is_equal_approx(hud.skill_bar_top(), SkillBar.top(screen, false)), "the crypt's skill bar has no level chip or EXP line any more")
	hud.free()


func _test_story_worlds() -> void:
	for scene: PackedScene in [HellScene, FrostScene]:
		var game: Node = scene.instantiate()
		game.class_id = "mage"
		root.add_child(game)
		await process_frame
		await process_frame
		var source: String = game.get_script().source_code
		check(source.contains("HudKit.hero_panel(") and source.contains("HudKit.floor_panel(") and source.contains("HudKit.boss_bar("), "%s draws the shared hero strip, floor panel and boss bar" % game.name)
		check(not source.contains("\"level\": int(state.level), \"exp\": float(state.exp) / need})"), "%s no longer puts the level into the skill bar" % game.name)
		# a click on the menu chip opens the pause menu
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = HudKit.menu_rect(game.get_viewport_rect().size).get_center()
		game._unhandled_input(click)
		await process_frame
		check(game.pause_menu != null and game.pause_menu.visible, "%s: the menu chip opens the pause menu" % game.name)
		game.queue_free()
		await process_frame
