extends SceneTree
## Captures the element physics and its reactions in the Testraum: a water
## puddle with a skeleton in it, chain lightning ending in it (the puddle is
## charged for 3 s: it crackles all over, the skeleton is hurt and stunned), a
## storm zone over a second puddle, a lava puddle next to water (crust and
## steam), fire into poison gas (it explodes), Glatteis that thaws, and water
## boiled to steam (src/combat/elements.gd).
## Uses the test profile and removes it and the Testraum's profile copy after.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_water_lightning.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const TestArena = preload("res://src/debug/test_arena.gd")

var _out := "res://production/qa/evidence/wasser-blitz"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(6, int(_game.players[1].hp))
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


func _place(label: String, at: Vector2) -> void:
	var bar: Control = _game._arena_bar
	for index in range(bar._tools.size()):
		if str(bar._tools[index].label) == label:
			bar._tool = index
	bar.place(at)


## Clears pools, clouds and enemies and lets the old pictures fade.
func _clear() -> void:
	_game.boss_moves.reset()
	_game.elements.reset()
	_game.enemies.clear()
	await _wait(80)


## A tough skeleton standing at `at`.
func _foe(at: Vector2) -> Dictionary:
	var foe: Dictionary = _game._create_enemy("skeleton", at)
	foe.pos = at
	foe.hp = 400.0
	foe.max_hp = 400.0
	_game.enemies.append(foe)
	return foe


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(40)
	_game.start_test_arena("swordsman")
	await _wait(90)
	var hero: Vector2 = _game.players[1].pos
	var water := hero + Vector2(110, 10)
	_place("PFÜTZE · WASSER", water)
	await _wait(70)
	var foe: Dictionary = _game._create_enemy("skeleton", water)
	foe.pos = water
	foe.hp = 400.0
	foe.max_hp = 400.0
	_game.enemies.append(foe)
	await _wait(2)
	_shot("1-wasserpfuetze")
	var hp_before := float(foe.hp)
	_place("BLITZ · KETTENBLITZ", water)
	await _wait(4)
	_shot("2-kettenblitz-in-wasser")
	await _wait(60)
	_shot("3-pfuetze-geladen")
	print("CHARGE foe hp %.1f -> %.1f hitstun=%.2f" % [hp_before, float(foe.hp), float(foe.get("hitstun", 0.0))])
	await _wait(150)
	_shot("3b-ladung-vorbei")
	var second := hero + Vector2(-110, 20)
	_place("PFÜTZE · WASSER", second)
	await _wait(60)
	_place("BLITZ · STURMZONE", second)
	await _wait(50)
	_shot("4-sturm-ueber-wasser")
	var lava := hero + Vector2(0, 90)
	_place("PFÜTZE · WASSER", lava + Vector2(-30, 0))
	_place("PFÜTZE · LAVA", lava + Vector2(30, 0))
	await _wait(90)
	_shot("5-wasser-trifft-lava")
	await _clear()
	# fire into poison gas over a poison puddle: it goes off, the puddle beside it too
	var poison := hero + Vector2(110, 0)
	_place("PFÜTZE · GIFT", poison)
	_place("PFÜTZE · GIFT", poison + Vector2(0, 80))
	_place("GAS · GIFT", poison + Vector2(0, -40))
	var victim := _foe(poison + Vector2(0, 40))
	await _wait(80)
	_shot("6-gift-vor-feuer")
	var victim_hp := float(victim.hp)
	_place("FEUER · FEUERSTOSS", poison + Vector2(0, -40))
	await _wait(3)
	_shot("7-gift-explodiert")
	await _wait(25)
	_shot("7b-explosion-danach")
	print("EXPLODE foe hp %.1f -> %.1f" % [victim_hp, float(victim.hp)])
	await _clear()
	# frost on water: Glatteis; then fire thaws it
	var ice := hero + Vector2(110, 10)
	_place("PFÜTZE · WASSER", ice)
	await _wait(70)
	var skater := _foe(ice)
	_place("EIS · SPLITTER, RAUREIF", ice)
	await _wait(50)
	_shot("8-glatteis")
	print("ICE slow=%s" % str((skater.get("statuses", {}) as Dictionary).has("slow")))
	_place("FEUER · FEUERSTOSS", ice)
	await _wait(30)
	_shot("9-glatteis-taut")
	await _clear()
	# fire on water: steam that blinds
	var boil := hero + Vector2(110, 10)
	_place("PFÜTZE · WASSER", boil)
	await _wait(70)
	_foe(boil)
	_place("FEUER · FEUERSTOSS", boil)
	await _wait(40)
	_shot("10-wasser-verdampft")
	_game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(TestArena._load(TestArena.DATA).get("profile_copy", "user://profile_testraum.json"))))
	quit()
