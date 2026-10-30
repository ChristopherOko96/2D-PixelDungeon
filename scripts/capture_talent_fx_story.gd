extends SceneTree
## Captures the talents in a story world (the Hölle or the Frostgruft,
## src/hell/hell_talents.gd): per specialisation a hero of the class on level
## 30 with all of the spec's talents, each bar slot cast in turn and the
## ultimate last, each shot full screen and as a 2x close-up round the hero.
## Uses the test profile file (Profile.default_path for a SceneTree script) and
## a capture meta file, never the player's, and removes the profile after.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_talent_fx_story.gd -- <output_dir> <hell|frost> [spec,spec|all] [stage 0..2]
const Profile = preload("res://src/progress/profile.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const SPECS := {"fire": "mage", "frost": "mage", "arcane": "mage", "sniper": "archer", "trapper": "archer", "beast": "archer", "berserk": "swordsman", "guard": "swordsman", "blade": "swordsman"}

var _out := "res://production/qa/evidence/talent-vfx-review/nachher-hoelle"
var _world := "hell"
var _only: Array = []
## The ultimate's bought stage (0..2) for every spec.
var _tier := 0
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _world = args[1]
	if args.size() > 2: _only = [] if args[2] == "all" else Array(args[2].split(","))
	if args.size() > 3: _tier = int(args[3])
	_run.call_deferred()


## Waits `seconds` of real time, the hero kept alive.
func _wait_s(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if _game != null and _game.get("state") != null:
			_game.state.inv = 5.0
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(name + ".png"))
	var xf: Transform2D = _game.get_viewport().get_canvas_transform()
	var c: Vector2 = xf * Vector2(float(_game.player.x), float(_game.player.y) - 40.0)
	var box := Rect2i(Vector2i(clampi(int(c.x) - 240, 0, 1280 - 480), clampi(int(c.y) - 135, 0, 720 - 270)), Vector2i(480, 270))
	var crop := image.get_region(box)
	crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join(name + "-nah.png"))
	print("CAPTURED ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var data := Profile.data()
	var talents: Dictionary = data.get("talents", {})
	var path := Profile.default_path()
	for spec: String in SPECS:
		if not _only.is_empty() and not spec in _only:
			continue
		var cls: String = SPECS[spec]
		# the build in the test profile: every talent of the spec, the ultimate with both stages
		var profile := Profile.load_profile(data, path)
		profile.shards = {"have": 3, "earned": 9, "spent": 6}
		var state := Profile.class_state(profile, cls)
		state.level = 30
		state.ranks = {}
		var bar: Array = []
		var ult := ""
		for id: String in talents:
			var t: Dictionary = talents[id]
			if str(t.get("spec", "")) != spec:
				continue
			state.ranks[id] = 1 if str(t.get("kind", "")) == "ultimate" else 3
			if str(t.get("kind", "")) == "active" and bar.size() < 4:
				bar.append(id)
			elif str(t.get("kind", "")) == "ultimate":
				ult = id
		state.bar = bar
		state.ultimate = ult
		state.soul_paid = 6
		state.soul_tier = _tier
		# the talent system's own test switch: no resource cost, short global cooldown
		profile.debug_free = true
		Profile.save_profile(profile, path)
		_game = (FrostScene if _world == "frost" else HellScene).instantiate()
		_game.meta_path = "user://capture_talent_fx_story.cfg"
		_game.class_id = cls
		_game.start_floor = 1
		root.add_child(_game)
		await _wait_s(1.6)
		if _game.talents == null:
			push_error("no talents in this world")
			break
		for slot in range(bar.size()):
			_game.talents.press(slot)
			await _wait_s(0.25)
			await _shot("%s-%d-%s" % [spec, slot + 1, bar[slot]])
			await _wait_s(1.0)
		if ult != "":
			_game.talents.press(-1)
			await _wait_s(0.1)
			await _shot("%s-ult-%s-frueh" % [spec, ult])
			await _wait_s(0.2)
			await _shot("%s-ult-%s" % [spec, ult])
			await _wait_s(1.0)
			await _shot("%s-ult-%s-spaeter" % [spec, ult])
			await _wait_s(1.9)
			await _shot("%s-ult-%s-wellen" % [spec, ult])
		_game.queue_free()
		await process_frame
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_talent_fx_story.cfg"))
	quit(0)
