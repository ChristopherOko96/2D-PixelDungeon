extends SceneTree
## Captures the user's second effects round (30.10.2026): the beast master's
## falcon in flight, its Sturzflug with blood and its blinding Augenhacker,
## the bigger Pfeilhagel with its hail arrows and closing volley, the new
## meteor falling, landing and leaving its crater, and the Feuerball's embers
## and explosion sparks.
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_falcon_hail_meteor.gd
const Game = preload("res://src/game.gd")

var _out := "res://production/qa/evidence/falcon-hail-meteor"
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.get("players") != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(1, int(_game.players[1].hp))
		await process_frame


## Waits real seconds (rendering the effects slows the frames down).
func _wait_s(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until: await _wait(1)


func _shot(name: String) -> void:
	await _wait(1)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _foe(tc: RefCounted, at: Vector2) -> Dictionary:
	var enemy: Dictionary = _game._create_enemy("skeleton", at)
	enemy.hp = 4000.0
	enemy.max_hp = 4000.0
	_game.enemies.append(enemy)
	return enemy


## A level 30 build: two ranks in each of the branch's first ten talents open
## its upper rows, plus the wanted ranks and ultimate.
func _build(tc: RefCounted, class_id: String, branch: String, ranks: Dictionary, companion: String = "wolf", ultimate: String = "") -> Dictionary:
	var all := {}
	for i in range(1, 11): all["%s_%d" % [branch, i]] = 2
	all.merge(ranks, true)
	tc.set_build(1, {"class": class_id, "level": 30, "ranks": all, "bar": [], "companion": companion, "ultimate": ultimate, "soul_tier": 1})
	var rt: Dictionary = tc.runtime(1)
	rt.res = float(rt.res_max)
	return rt


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	_game.requested_seed = 4242
	_game._start_solo(false, "archer")
	await _wait(60)
	var hero: Dictionary = _game.players[1]
	var tc: RefCounted = _game.talent_combat
	var home := Vector2(hero.pos)
	var left := Vector2(1, 1)  # the hero stands in the left half of a narrow room
	# 1) The falcon beside the hero, then its dive and blinding blow
	_build(tc, "archer", "beast", {"beast_1": 3}, "falcon")
	await _wait_s(0.67)
	await _shot("01-falke-fliegt.png")
	var prey := _foe(tc, home + left * Vector2(150, 10))
	var falcon: Dictionary = tc.permanent_pet(1)
	falcon.target = int(prey.id)
	tc.pet_cast(1, 0, true)
	await _wait_s(0.12)
	await _shot("02-falke-sturzflug-blutung.png")
	await _wait_s(0.42)
	tc.pet_cast(1, 1, true)
	await _wait_s(0.13)
	await _shot("03-falke-augenhacker.png")
	# 2) Pfeilhagel: the field, then the closing volley
	_game.enemies.clear()
	_build(tc, "archer", "sniper", {"sniper_11": 3})  # one branch per hero
	for k in range(4): _foe(tc, home + left * Vector2(130 + 30 * (k % 2), -40 + 30 * k))
	tc.runtime(1).cds.clear()
	tc.runtime(1).gcd = 0.0
	print("CAST sniper_11 ", tc.cast_blocker(1, "sniper_11"))
	tc.cast(1, "sniper_11", {"aim": Vector2.RIGHT, "target": home + left * Vector2(145, 0)})
	await _wait_s(0.67)
	await _shot("04-pfeilhagel.png")
	await _wait_s(1.97)
	await _shot("05-pfeilhagel-schlusssalve.png")
	# 3) Meteor: falling, impact, crater
	_game.enemies.clear()
	tc.zones.clear()
	for k in range(3): _foe(tc, home + left * Vector2(150 + 20 * k, -20 + 25 * k))
	_build(tc, "mage", "fire", {"fire_1": 3, "fire_14": 1}, "wolf", "fire_14")
	print("CAST fire_14 ", tc.cast_blocker(1, "fire_14"))
	tc.cast(1, "fire_14", {"aim": Vector2.RIGHT, "target": home + left * Vector2(160, 0)})
	await _wait_s(0.67)
	await _shot("06-meteor-faellt.png")
	await _wait_s(0.43)
	await _shot("07-meteor-einschlag.png")
	await _wait_s(0.30)
	await _shot("08-meteor-pilz.png")
	await _wait_s(0.83)
	await _shot("09-meteor-krater.png")
	# 4) Feuerball: embers in flight, then sparks and smoke
	_game.enemies.clear()
	_foe(tc, home + left * Vector2(180, 0))
	tc.zones.clear()
	tc.runtime(1).cds.clear()
	tc.runtime(1).gcd = 0.0
	tc.runtime(1).res = 100.0
	tc.cast(1, "fire_1", {"aim": Vector2.RIGHT, "target": home + left * Vector2(180, 0)})
	await _wait_s(0.13)
	await _shot("10-feuerball-glut.png")
	await _wait_s(0.17)
	await _shot("11-feuerball-funken.png")
	quit(0)
