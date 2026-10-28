extends SceneTree
## Run HUD and crypt theme (src/ui/run_hud.gd, src/ui/crypt_ui.gd): half
## hearts from HP, the top bar follows a boss before a mini-boss and ignores
## the dead, every class has four skill slots, and the shared theme frames
## buttons, panels and fields.

const RunHud = preload("res://src/ui/run_hud.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("RUN_HUD_FAIL: ", description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Hearts: two HP per heart, odd HP is a half heart, overflow is clamped.
	check(RunHud.hearts(7, 8) == ["full", "full", "full", "half"], "7 of 8 HP: three full hearts and a half")
	check(RunHud.hearts(0, 6) == ["empty", "empty", "empty"], "0 HP: all hearts empty")
	check(RunHud.hearts(12, 10).count("full") == 5, "HP above the maximum fills every heart, no more")

	# Boss bar target: the boss wins over a mini-boss; dead or dying ones are skipped.
	var snapshot := {"enemies": [
		{"id": 1, "hp": 30.0, "max_hp": 40.0, "miniboss": true},
		{"id": 2, "hp": 0.0, "max_hp": 200.0, "boss": true},
		{"id": 3, "hp": 10.0, "max_hp": 10.0}]}
	check(int(RunHud.boss_target(snapshot).get("id", -1)) == 1, "with the boss dead the bar follows the mini-boss")
	snapshot.enemies[1].hp = 150.0
	check(int(RunHud.boss_target(snapshot).get("id", -1)) == 2, "a living boss takes the bar")
	snapshot.enemies[1].dying_p = 0.2
	check(int(RunHud.boss_target(snapshot).get("id", -1)) == 1, "a dying boss leaves the bar")
	check(RunHud.boss_target({"enemies": [{"id": 3, "hp": 5.0}]}).is_empty(), "normal enemies show no top bar")

	# Data: every class from balance.json has four slots with keys 1-4.
	var hud = RunHud.new()
	root.add_child(hud)
	await process_frame
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	for class_id: String in balance.get("class_order", []):
		var keys: Array = hud.skills_for(class_id).map(func(skill: Dictionary) -> String: return str(skill.key))
		check(keys == ["1", "2", "3", "4"], "%s has skill slots 1-4 (%s)" % [class_id, str(keys)])
	hud.size = Vector2(1280, 720)
	hud.set_state({"players": {1: {"hp": 7, "max_hp": 8, "class_id": "archer"}}, "floor_map": [], "floor_index": 3, "room": 4, "enemies": []}, 1)
	check(hud.local_hearts() == ["full", "full", "full", "half"], "the HUD reads the local player's hearts from the snapshot")
	var panel: Rect2 = hud.map_panel_rect()
	check(panel.end.x <= 1280.0 and panel.position.y >= 0.0 and panel.position.x > 900.0, "the floor panel sits in the top-right corner")
	check(hud.skill_bar_top() > 600.0 and hud.skill_bar_top() < 720.0, "the skill bar sits at the bottom")

	# Theme: one crypt frame per widget state, cached across calls.
	var theme: Theme = CryptUI.create_theme()
	check(theme == CryptUI.create_theme(), "one shared theme per process")
	for item: Array in [["normal", "Button"], ["hover", "Button"], ["pressed", "Button"], ["disabled", "Button"], ["focus", "Button"], ["panel", "Panel"], ["normal", "LineEdit"]]:
		check(theme.has_stylebox(item[0], item[1]), "the theme frames %s.%s" % [item[1], item[0]])
	check(theme.get_stylebox("normal", "Button") is StyleBoxTexture, "buttons use the bevelled pixel frame")
	check(CryptUI.GAME_TITLE == "DELVE DISASTER", "the game is called Delve Disaster")
	print("RUN_HUD checked=%d failures=%d" % [checked, failures.size()])
	hud.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)
