extends SceneTree
## Captures the ultimate stages (talents.json "stages", docs/TALENTE-SEELENSPLITTER.de.md):
## the talent screen on Inferno at Stufe 2 with Stufe 3 next, on Klingentanz
## fully raised, then runs with Inferno at Stufe 3 (second explosion and
## burning ground) and Letzter Pfeil at Stufe 3 (three piercing arrows).
## Uses the test profile file, never the player's.
##   godot --path . --resolution 1280x720 -s res://scripts/capture_ultimate_stages.gd
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const TalentCombat = preload("res://src/combat/talent_combat.gd")

var _out := "res://production/qa/evidence/ultimate-stages"
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(1, int(_game.players[1].hp))
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _cast(bits: int, frames: int) -> void:
	_game.scripted_skills = bits
	await _wait(3)
	_game.scripted_skills = 0
	await _wait(frames)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	var profile: Dictionary = _game.progress.profile
	profile.gold = 900
	profile.shards = {"have": 4, "earned": 7, "spent": 3}
	var mage := Profile.class_state(profile, "mage")
	mage.level = 20
	mage.ranks = {"fire_1": 3, "fire_2": 3, "fire_3": 3, "fire_4": 3, "fire_5": 1, "fire_6": 1}
	mage.ultimate = "fire_6"
	mage.soul_tier = 1
	mage.soul_paid = 3
	mage.bar = ["fire_1", "fire_3", "fire_5"]
	var sword := Profile.class_state(profile, "swordsman")
	sword.level = 30
	sword.ranks = {"blade_1": 3, "blade_2": 3, "blade_3": 3, "blade_4": 3, "blade_5": 1, "blade_6": 1}
	sword.ultimate = "blade_6"
	sword.soul_tier = 2
	sword.soul_paid = 6
	var archer := Profile.class_state(profile, "archer")
	archer.level = 30
	archer.ranks = {"sniper_1": 3, "sniper_2": 3, "sniper_3": 3, "sniper_4": 3, "sniper_5": 1, "sniper_6": 1}
	archer.ultimate = "sniper_6"
	archer.soul_tier = 2
	archer.soul_paid = 6
	archer.bar = ["sniper_1"]
	_game.main_menu._open_talents()
	var screen: Control = _game.main_menu._talent_screen
	screen.selected = "fire_6"
	screen._refresh()
	await _wait(20)
	await _shot("01-inferno-stufe-2.png")
	screen._pick_class("swordsman")
	screen.selected = "blade_6"
	screen._refresh()
	await _wait(10)
	await _shot("02-klingentanz-stufe-3.png")
	screen.visible = false
	# Inferno at Stufe 3: the first blast, then the second one on burning ground.
	mage.soul_tier = 2
	_game.requested_seed = 4242
	_game._start_solo(false, "mage")
	await _wait(60)
	await _cast(1 << TalentCombat.ULT_BIT, 4)
	await _shot("03-inferno-stufe-3-explosion.png")
	await _wait(85)
	await _shot("04-inferno-stufe-3-zweite-explosion-glutboden.png")
	_game._leave_session()
	await _wait(20)
	# Letzter Pfeil at Stufe 3: three arrows in a fan.
	_game.requested_seed = 4242
	_game._start_solo(false, "archer")
	await _wait(60)
	await _cast(1 << TalentCombat.ULT_BIT, 5)
	await _shot("05-letzter-pfeil-stufe-3-faecher.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
