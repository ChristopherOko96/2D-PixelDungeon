extends SceneTree
## Headless checks for accounts and progress without a network: progress rules
## (src/online/progress.gd), Firestore field encoding and error texts
## (src/online/firebase.gd), the guest account's local save and the menu.

const Progress = preload("res://src/online/progress.gd")
const Firebase = preload("res://src/online/firebase.gd")
const Account = preload("res://src/online/account.gd")
const Menu = preload("res://src/main_menu.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("ONLINE_FAIL: ", description)

func _initialize() -> void:
	var fresh := Progress.normalized({})
	check(fresh.runs == 0 and fresh.best_level == 1 and fresh.size() == Progress.DEFAULTS.size(), "new progress starts empty with every field")
	var after := Progress.record_run(fresh, {"won": true, "level": 3, "exp": 140, "kills": 22, "bosses": 1, "rooms": 7, "seconds": 300}, 1000)
	check(after.runs == 1 and after.wins == 1 and after.deaths == 0 and after.kills == 22 and after.best_level == 3 and after.total_exp == 140 and after.updated == 1000, "a won run is counted with its kills, EXP and level")
	after = Progress.record_run(after, {"won": false, "level": 2, "kills": 5, "rooms": 3}, 2000)
	check(after.runs == 2 and after.deaths == 1 and after.best_level == 3 and after.best_rooms == 7 and after.kills == 27, "a lost run adds a death and never lowers a best")
	var deep := Progress.record_run(after, {"won": false, "level": 5, "floor": 6}, 3000)
	check(deep.best_floor == 6 and Progress.record_run(deep, {"floor": 2}, 4000).best_floor == 6 and Progress.summary(deep).contains("Stockwerk 6"), "the deepest endless floor is kept and shown")
	var merged := Progress.merge({"runs": 5, "wins": 1, "best_level": 2}, {"runs": 3, "wins": 2, "best_level": 6})
	check(merged.runs == 5 and merged.wins == 2 and merged.best_level == 6, "merging keeps the larger value of each field")
	check(Progress.normalized({"runs": "7", "kills": -4, "junk": 1}).runs == 7 and Progress.normalized({"kills": -4}).kills == 0 and not Progress.normalized({"junk": 1}).has("junk"), "bad or foreign values from the cloud are cleaned up")

	var fields := Firebase.to_fields({"runs": 4, "ratio": 0.5, "name": "x", "flag": true})
	check(fields.runs == {"integerValue": "4"} and fields.ratio.has("doubleValue") and fields.name == {"stringValue": "x"} and fields.flag == {"booleanValue": true}, "progress encodes to Firestore field types")
	check(Firebase.from_fields(fields) == {"runs": 4, "ratio": 0.5, "name": "x", "flag": true}, "Firestore fields decode back to the same values")
	check(Firebase.error_message({"code": 400, "body": {"error": {"message": "EMAIL_EXISTS"}}}) == "Diese E-Mail ist schon registriert.", "a taken e-mail gets a clear message")
	check(Firebase.error_message({"code": 400, "body": {"error": {"message": "WEAK_PASSWORD : Password should be at least 6 characters"}}}).begins_with("Passwort zu schwach"), "a weak password gets a clear message")
	check(Firebase.error_message({"code": 400, "body": {"error": {"message": "INVALID_LOGIN_CREDENTIALS"}}}) == "E-Mail oder Passwort falsch.", "wrong credentials get one message that reveals nothing")
	check(Firebase.error_message({"code": 0, "body": {}}).begins_with("Keine Verbindung"), "no network is reported as such")

	var firebase = Firebase.new()
	firebase.api_key = ""
	check(not firebase.configured() and not firebase.is_signed_in(), "without keys Firebase is off and nobody is signed in")
	firebase.free()

	var account = Account.new()
	account.storage_prefix = "user://test_progress_"
	root.add_child(account)
	await process_frame
	account.firebase.api_key = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_progress_guest.json"))
	account.progress = account._load_local()
	check(account.display_name() == "Gast" and account.progress.runs == 0, "without an account the player is a guest")
	account.record_run({"won": true, "level": 2, "kills": 9})
	var reloaded: Dictionary = account._load_local()
	check(reloaded.runs == 1 and reloaded.kills == 9 and FileAccess.file_exists("user://test_progress_guest.json"), "a guest's run is saved locally")
	account._on_cloud_progress({"runs": 4, "wins": 3})
	check(account.progress.runs == 4 and account.progress.wins == 3 and account.progress.kills == 9, "cloud progress merges into the local copy")

	var menu = Menu.new()
	menu.account = account
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	menu.classes = balance.classes
	menu.class_order = balance.class_order
	menu.weapons = balance.weapons
	menu.debug_entries = [{"label": "ENDLOS 3 · BOSS", "endless": true, "floor": 3, "room": "boss"}]
	root.add_child(menu)
	await process_frame
	check(menu._buttons[0].text == "STORY-MODUS" and menu._buttons[1].text == "ENDLOS-MODUS" and menu._buttons[0].position.y < menu._buttons[1].position.y, "Story mode sits above Endless mode")
	check(menu._account_label.text == "Gast" and menu._progress_label.text.contains("4 Läufe"), "the menu shows the guest and the saved progress")
	var version_found := false
	for child in menu.get_children():
		if child is Label and child.text == "v" + str(ProjectSettings.get_setting("application/config/version")) and child.position.x > 900 and child.position.y > 650: version_found = true
	check(version_found, "the version stands bottom right")
	menu._open_login()
	check(menu._login_panel.visible and menu._login_status.text.contains("firebase.local.json"), "login explains when Firebase is not set up")
	menu._close_panels()
	var started: Array = []
	menu.start_requested.connect(func(endless: bool, class_id: String): started.append([endless, class_id]))
	menu._buttons[1].pressed.emit()
	check(menu._class_panel.visible and menu._class_heroes.size() == 3, "Endless opens the hero choice with three heroes")
	menu._choose_class("mage")
	check(started == [[true, "mage"]] and not menu._class_panel.visible, "choosing a hero starts the run in the chosen mode")
	check(menu.take_debug_start().is_empty(), "a normal start carries no debug jump")
	menu._open_debug()
	check(menu._debug_panel.visible, "the debug level list opens from the menu")
	menu._pick_debug(menu.debug_entries[0])
	check(menu._class_panel.visible, "a debug level still asks for the hero")
	menu._choose_class("swordsman")
	var jump: Dictionary = menu.take_debug_start()
	check(jump.get("floor", 0) == 3 and jump.get("room", "") == "boss" and menu.take_debug_start().is_empty(), "the chosen level is handed to the game once")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_progress_guest.json"))
	menu.free()
	account.free()

	print("ONLINE checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
