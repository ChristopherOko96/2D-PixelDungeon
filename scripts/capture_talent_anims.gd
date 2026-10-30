extends SceneTree
## Captures every branch's active talents with their own animations (user
## decision 30.10.2026): per branch a crypt run, a few skeletons in front of
## the hero, then its actives cast one right after the other and one shot
## while they play. Uses the test profile file, never the player's.
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_talent_anims.gd
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")

const BRANCHES := [["mage", "fire"], ["mage", "frost"], ["mage", "arcane"], ["archer", "sniper"], ["archer", "trapper"], ["archer", "beast"],
	["swordsman", "berserk"], ["swordsman", "guard"], ["swordsman", "blade"], ["necromancer", "minion"], ["necromancer", "curse"], ["necromancer", "soul"]]

var _out := "res://production/qa/evidence/talent-anims"
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.get("players") != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(1, int(_game.players[1].hp))
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


## Every talent of the branch at full rank up to 29 points (no ultimate).
func _build(state: Dictionary, d: Dictionary, spec: String) -> Array:
	state.level = 30
	state.ranks = {}
	state.bar = []
	state.ultimate = ""
	var actives: Array = []
	var spent := 0
	for id: String in d.talents:
		var info: Dictionary = d.talents[id]
		if str(info.spec) != spec or str(info.kind) == "ultimate" or spent >= 29: continue
		state.ranks[id] = mini(int(info.ranks), 29 - spent)
		spent += int(state.ranks[id])
		if str(info.kind) == "active": actives.append(id)
	return actives


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	var profile: Dictionary = _game.progress.profile
	var d: Dictionary = _game.progress.data
	var tc: RefCounted = _game.talent_combat
	var index := 0
	for pair: Array in BRANCHES:
		index += 1
		var actives := _build(Profile.class_state(profile, pair[0]), d, pair[1])
		_game.requested_seed = 4242
		_game._start_solo(false, pair[0])
		await _wait(60)
		var hero: Dictionary = _game.players[1]
		for offset: Vector2 in [Vector2(120, -30), Vector2(150, 30), Vector2(190, 0), Vector2(110, 60)]:
			var enemy: Dictionary = _game._create_enemy("skeleton", Vector2(hero.pos) + offset)
			enemy.hp = 900.0
			enemy.max_hp = 900.0
			enemy.aggro = true
			enemy.aggro_target = 1
			_game.enemies.append(enemy)
		# cast the branch's actives quickly one after the other, the last ones shortly before the shot
		var rt: Dictionary = tc.runtime(1)
		for talent: String in actives:
			if bool(d.talents[talent].get("permanent", false)): continue
			rt.cds.clear()
			rt.gcd = 0.0
			rt.res = float(rt.res_max)
			tc.cast(1, talent, {"aim": Vector2.RIGHT, "target": Vector2(hero.pos) + Vector2(150, 10)})
			await _wait(6)
		await _wait(4)
		await _shot("%02d-%s.png" % [index, pair[1]])
		_game._leave_session()
		await _wait(20)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
