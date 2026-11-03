extends SceneTree
## Captures the talent screen's footer from the real windowed game (src/ui/talent_screen.gd): the
## reset priced in rune stones and the purse of rune stones and soul shards, with a talent test
## profile (src/progress/profile.gd DEBUG_RUNES) and with a player's own profile.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_talent_reset.gd -- <output_dir>
const TalentScreenScript = preload("res://src/ui/talent_screen.gd")
const Profile = preload("res://src/progress/profile.gd")

var _out := "res://production/qa/evidence/rune-reset"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_run.call_deferred()


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


func _show(name: String, profile: Dictionary) -> void:
	var d := Profile.data()
	var screen: Control = TalentScreenScript.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	var path := "user://capture_talent_reset_%s.json" % name
	Profile.save_profile(profile, path)
	screen.open(d, Profile.load_profile(d, path), path, "mage")
	for k in range(20):
		await process_frame
	_shot(name)
	screen.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var d := Profile.data()
	# the talent test profile as it was written before rune stones paid the reset (2 stones)
	var test := Profile.fresh(d)
	test.debug_free = true
	test.runes = 2
	test.shards = {"have": 93, "earned": 93, "spent": 0}
	for id: String in test.classes:
		test.classes[id].level = 30
	test.classes.mage.ranks = {"fire_1": 3}
	await _show("01-talent-test-profil", test)
	# a player's own profile with too few rune stones for a reset at Heldenstufe 30
	var own := Profile.fresh(d)
	own.runes = 4
	own.classes.mage.level = 30
	own.classes.mage.ranks = {"fire_1": 3}
	await _show("02-eigenes-profil-zu-wenig", own)
	quit()
