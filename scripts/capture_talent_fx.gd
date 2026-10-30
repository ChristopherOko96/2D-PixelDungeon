extends SceneTree
## Captures every active talent and ultimate of the nine specialisations in the
## crypt (assets/data/talents.json): a hero of the class on level 30 with all
## of the spec's talents, three dummies in front of him, each bar slot cast in
## turn and the ultimate last, shot shortly after each cast with a 2x close-up
## around the hero. Uses the test profile file (Profile.default_path for a
## SceneTree script), never the player's, and removes it after.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_talent_fx.gd -- <output_dir> [spec,spec|all] [stage 0..2]
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const TalentCombat = preload("res://src/combat/talent_combat.gd")
const SPECS := {"fire": "mage", "frost": "mage", "arcane": "mage", "sniper": "archer", "trapper": "archer", "beast": "archer", "berserk": "swordsman", "guard": "swordsman", "blade": "swordsman"}

var _out := "res://production/qa/evidence/talent-vfx-review/vorher"
var _only: Array = []
## The ultimate's bought stage (0..2) for every spec.
var _tier := 0
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _only = [] if args[1] == "all" else Array(args[1].split(","))
	if args.size() > 2: _tier = int(args[2])
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(1, int(_game.players[1].hp))
		await process_frame


## Waits real seconds (the game may run at a few hundred frames a second, and
## the talents' global cooldown is in seconds).
func _wait_s(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await _wait(1)


func _shot(name: String) -> void:
	await _wait(1)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(name + ".png"))
	var hero: Dictionary = _game.players.get(1, {})
	if not hero.is_empty():
		var c: Vector2 = _game.view.get_global_transform_with_canvas() * (Vector2(hero.pos) + Vector2(70, -20))
		var box := Rect2i(Vector2i(clampi(int(c.x) - 240, 0, 1280 - 480), clampi(int(c.y) - 135, 0, 720 - 270)), Vector2i(480, 270))
		var crop := image.get_region(box)
		crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
		crop.save_png(_out.path_join(name + "-nah.png"))
	print("CAPTURED ", name)


func _cast(bits: int) -> void:
	_game.scripted_skills = bits
	await _wait(3)
	_game.scripted_skills = 0


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	var talents: Dictionary = TalentCombat.new().data.get("talents", {}) if TalentCombat.new().get("data") != null else {}
	if talents.is_empty():
		talents = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/talents.json")) as Dictionary).get("talents", {})
	for spec: String in SPECS:
		if not _only.is_empty() and not spec in _only:
			continue
		var cls: String = SPECS[spec]
		var profile: Dictionary = _game.progress.profile
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
		# (a swordsman starts with 0 rage, so his ultimate would never fire here)
		profile.debug_free = true
		# the run reads the profile from its (test) file: store the build first
		_game.progress.save()
		_game.requested_seed = 4242
		_game._start_solo(false, cls)
		await _wait(60)
		_game.enemies.clear()
		_game.hordes.enabled = false
		var hero: Dictionary = _game.players[1]
		for k in range(3):
			var foe: Dictionary = _game._create_enemy("skeleton", Vector2(hero.pos) + Vector2(70 + k * 18, -36 + k * 36))
			foe.move_timer = 99.0
			foe.shot_timer = 99.0
			foe.hp = 9999.0
			foe.max_hp = 9999.0
			_game.enemies.append(foe)
		await _wait_s(1.2)
		for slot in range(bar.size()):
			await _cast(1 << (TalentCombat.BAR_BIT + slot))
			await _wait_s(0.25)
			await _shot("%s-%d-%s" % [spec, slot + 1, bar[slot]])
			await _wait_s(1.2)
		if ult != "":
			# the ultimate at its start, its peak, later (its aura) and after its
			# delayed waves (Feuersturm 1.5 s, Splitterbruch 3 s)
			await _cast(1 << TalentCombat.ULT_BIT)
			await _wait_s(0.1)
			await _shot("%s-ult-%s-frueh" % [spec, ult])
			await _wait_s(0.2)
			await _shot("%s-ult-%s" % [spec, ult])
			await _wait_s(1.0)
			await _shot("%s-ult-%s-spaeter" % [spec, ult])
			await _wait_s(1.9)
			await _shot("%s-ult-%s-wellen" % [spec, ult])
		_game._leave_session()
		await _wait(20)
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
