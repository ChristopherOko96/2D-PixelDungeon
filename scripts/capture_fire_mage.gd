extends SceneTree
## Captures the fire mage after the user's concept sheet (30.10.2026): the
## talent screen with Lavafeld selected, then a crypt run with the attacks:
## Feuerball with its charge and the Flammenwall, Lavafeld and Glutkette,
## Phönixschritt in flight, the Meteor's rune and fall, the Infernospeer. Uses
## the test profile file, never the player's.
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_fire_mage.gd
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")

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


func _cast(talent: String, target: Vector2) -> void:
	var rt: Dictionary = _game.talent_combat.runtime(1)
	rt.cds.clear()
	rt.gcd = 0.0
	rt.res = float(rt.res_max)
	_game.talent_combat.cast(1, talent, {"aim": (target - Vector2(_game.players[1].pos)).normalized(), "target": target})


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	var profile: Dictionary = _game.progress.profile
	profile.shards = {"have": 4, "earned": 10, "spent": 6}
	profile.gold = 900
	var mage := Profile.class_state(profile, "mage")
	mage.level = 30
	mage.ranks = {"fire_1": 2, "fire_2": 3, "fire_3": 2, "fire_4": 3, "fire_5": 2, "fire_6": 1, "fire_7": 2, "fire_9": 2, "fire_11": 2, "fire_13": 1, "fire_14": 1}
	mage.ultimate = "fire_14"
	mage.soul_tier = 2
	mage.bar = ["fire_1", "fire_3", "fire_7", "fire_11"]
	# 1) The fire tree, Lavafeld selected
	_game.main_menu._open_talents()
	var screen: Control = _game.main_menu._talent_screen
	screen._pick_class("mage")
	screen.selected = "fire_7"
	screen._refresh()
	await _wait(30)
	await _shot("01-feuerbaum-lavafeld.png")
	screen.selected = "fire_14"
	screen._refresh()
	await _wait(10)
	await _shot("02-feuerbaum-meteor.png")
	screen.visible = false
	# 2) A crypt run with the attacks
	_game.requested_seed = 4242
	_game._start_solo(false, "mage")
	await _wait(60)
	var hero: Dictionary = _game.players[1]
	for offset: Vector2 in [Vector2(130, -40), Vector2(170, 20), Vector2(210, -10), Vector2(150, 70), Vector2(240, 50)]:
		var enemy: Dictionary = _game._create_enemy("skeleton", Vector2(hero.pos) + offset)
		enemy.hp = 2000.0
		enemy.max_hp = 2000.0
		enemy.aggro = true
		enemy.aggro_target = 1
		_game.enemies.append(enemy)
	var at := Vector2(hero.pos)
	_cast("fire_3", at + Vector2(110, 0))
	await _wait(8)
	_cast("fire_1", at + Vector2(200, -10))
	await _wait(9)
	await _shot("03-feuerball-flammenwall.png")
	await _wait(40)
	_cast("fire_7", at + Vector2(170, 20))
	await _wait(20)
	_cast("fire_11", at + Vector2(130, -40))
	await _wait(14)
	await _shot("04-lavafeld-glutkette.png")
	await _wait(30)
	_cast("fire_5", at + Vector2(-200, 60))
	await _wait(16)
	await _shot("05-phoenixschritt.png")
	await _wait(30)
	_cast("fire_14", Vector2(hero.pos) + Vector2(220, 0))
	await _wait(42)
	await _shot("06-meteor-rune-fall.png")
	await _wait(30)
	_cast("fire_9", Vector2(hero.pos) + Vector2(300, 0))
	await _wait(10)
	await _shot("07-infernospeer-krater.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
