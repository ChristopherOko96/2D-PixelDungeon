extends SceneTree
## Captures the fire mage's run after the user's second wish list (30.10.2026):
## the pyromancer figure, the big Feuerball in flight and its explosion, the
## "Wenig Mana" hint, the bigger skill bar icons, the talent menu opened mid-run
## with K and the pyromancer in the Frostgruft. Uses the test profile file.
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_fire_mage_run.gd
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")

var _out := "res://production/qa/evidence/fire-mage"
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


func _build(profile: Dictionary) -> void:
	var mage := Profile.class_state(profile, "mage")
	mage.level = 30
	mage.ranks = {"fire_1": 3, "fire_2": 3, "fire_3": 2, "fire_4": 3, "fire_5": 2, "fire_6": 1, "fire_7": 2, "fire_9": 2, "fire_11": 2, "fire_13": 1, "fire_14": 1}
	mage.ultimate = "fire_14"
	mage.soul_tier = 2
	mage.bar = ["fire_1", "fire_3", "fire_7", "fire_11"]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	_build(_game.progress.profile)
	_game.requested_seed = 4242
	_game._start_solo(false, "mage")
	await _wait(60)
	var hero: Dictionary = _game.players[1]
	var tc: RefCounted = _game.talent_combat
	var enemy: Dictionary = _game._create_enemy("skeleton", Vector2(hero.pos) + Vector2(150, 0))
	enemy.hp = 2000.0
	enemy.max_hp = 2000.0
	_game.enemies.append(enemy)
	var near: Dictionary = _game._create_enemy("skeleton", Vector2(hero.pos) + Vector2(165, 30))
	near.hp = 2000.0
	near.max_hp = 2000.0
	_game.enemies.append(near)
	# 1) The big Feuerball in flight
	tc.cast(1, "fire_1", {"aim": Vector2.RIGHT, "target": Vector2(hero.pos) + Vector2(150, 0)})
	await _wait(8)
	await _shot("08-pyromant-feuerball-flug.png")
	# 2) Its explosion
	await _wait(10)
	await _shot("09-feuerball-explosion.png")
	# 3) No mana: the hint over the hero
	await _wait(30)
	tc.runtime(1).res = 3.0
	tc.runtime(1).cds.clear()
	tc.runtime(1).gcd = 0.0
	tc.cast(1, "fire_3", {"aim": Vector2.RIGHT, "target": Vector2(hero.pos) + Vector2(120, 0)})
	await _wait(12)
	await _shot("10-wenig-mana.png")
	# 4) K: the talent menu over the run
	_game.toggle_run_talents()
	await _wait(20)
	await _shot("11-talentmenue-im-lauf.png")
	_game.toggle_run_talents()
	_game._leave_session()
	await _wait(20)
	# 5) The pyromancer in the Frostgruft
	Profile.save_profile(_game.progress.profile, Profile.default_path())
	_game.queue_free()
	_game = null
	var frost: Node = FrostScene.instantiate()
	frost.class_id = "mage"
	root.add_child(frost)
	await _wait(50)
	await _shot("12-frostgruft-pyromant.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
