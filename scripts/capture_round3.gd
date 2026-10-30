extends SceneTree
## Captures the user's third wish list (30.10.2026) through the real input:
## the Flammenmeer drawn with the mouse (its fill bar, then the burning line),
## the Pyro-Monster in a fight, the magic block (whole, cracked, breaking),
## the archer's roll, the skill card on hover and the mage's left-click
## fireball bursting.
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_round3.gd
const Game = preload("res://src/game.gd")
const TalentCombat = preload("res://src/combat/talent_combat.gd")

var _out := "res://production/qa/evidence/round3-flammenmeer-block"
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.get("players") != null and _game.players.has(1):
			_game.players[1].hp = maxi(1, int(_game.players[1].hp))
		await process_frame


func _wait_s(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until: await _wait(1)


func _shot(name: String) -> void:
	await _wait(1)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


## Puts the real mouse on a world point.
func _mouse_at(world: Vector2) -> void:
	root.warp_mouse(_game.view.get_global_transform_with_canvas() * world)


func _foe(at: Vector2) -> Dictionary:
	var enemy: Dictionary = _game._create_enemy("skeleton", at)
	enemy.hp = 4000.0
	enemy.max_hp = 4000.0
	_game.enemies.append(enemy)
	return enemy


func _build(class_id: String, branch: String, ranks: Dictionary, bar: Array) -> Dictionary:
	var all := {}
	for i in range(1, 11): all["%s_%d" % [branch, i]] = 2
	all.merge(ranks, true)
	_game.talent_combat.set_build(1, {"class": class_id, "level": 30, "ranks": all, "bar": bar})
	_game.players[1].class_id = class_id
	var rt: Dictionary = _game.talent_combat.runtime(1)
	rt.res = float(rt.res_max)
	return rt


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	_game.requested_seed = 4242
	_game._start_solo(false, "mage")
	await _wait(60)
	var hero: Dictionary = _game.players[1]
	var tc: RefCounted = _game.talent_combat
	var home := Vector2(hero.pos)
	# 1) The Pyro-Monster fights the enemy the hero attacks
	_build("mage", "fire", {"fire_1": 3, "fire_3": 2, "fire_7": 3}, ["fire_1", "fire_3", "fire_7"])
	var foe := _foe(home + Vector2(130, 10))
	_game._damage_enemy(foe, 1.0, Vector2.RIGHT, 1, true)
	await _wait_s(1.4)
	await _shot("01-pyro-monster-kaempft.png")
	# 2) Flammenmeer: key 3 held, the mouse draws a curve
	_game.enemies.clear()
	for k in range(3): _foe(home + Vector2(150 + 20 * k, -60 + 50 * k))
	tc.runtime(1).cds.clear()
	tc.runtime(1).gcd = 0.0
	var curve: Array = []
	for k in range(24): curve.append(home + Vector2(120 + 50.0 * sin(k * 0.3), -90 + k * 9.0))
	_mouse_at(curve[0])
	await _wait(2)
	_game.scripted_skills = 1 << (TalentCombat.BAR_BIT + 2)
	for k in range(14):
		_mouse_at(curve[k])
		await _wait(3)
	await _shot("02-flammenmeer-ziehen-fuellleiste.png")
	for k in range(14, 24):
		_mouse_at(curve[k])
		await _wait(3)
	_game.scripted_skills = 0
	await _wait_s(0.8)
	await _shot("03-flammenmeer-brennt.png")
	# 3) Magischer Block: up, a hit cracks it, the next breaks it
	_game.scripted_skills = 1 << TalentCombat.DEFEND_BIT
	await _wait(6)
	await _shot("04-magischer-block.png")
	tc.incoming(1, 5, Vector2.ZERO)
	await _wait(10)
	await _shot("05-block-angeknackst.png")
	tc.incoming(1, 5, Vector2.ZERO)
	await _wait(8)
	await _shot("06-block-zerbricht.png")
	_game.scripted_skills = 0
	# 4) The skill card on hover
	await _wait(4)
	var screen: Vector2 = root.get_visible_rect().size
	var SkillBar = load("res://src/ui/skill_bar.gd")
	var slots: Array = _game.run_hud._talent_bar.skill_slots(tc.player_state(1)) if _game.get("run_hud") != null else []
	var found := Vector2(screen.x * 0.5, SkillBar.top(screen, false) + 24.0)
	for x in range(0, int(screen.x), 4):
		if SkillBar.slot_at(screen, slots, Vector2(x, SkillBar.top(screen, false) + 24.0)) == 2:
			found = Vector2(x + 20, SkillBar.top(screen, false) + 24.0)
			break
	root.warp_mouse(found)
	await _wait(6)
	await _shot("07-tooltip-flammenmeer.png")
	# 5) The mage's left-click fireball
	_game.enemies.clear()
	tc.zones.clear()
	_foe(home + Vector2(170, 0))
	_mouse_at(home + Vector2(170, 0))
	_game.scripted_fire = true
	await _wait(9)
	await _shot("08-linksklick-feuerball.png")
	await _wait(10)
	await _shot("09-feuerball-platzt.png")
	_game.scripted_fire = false
	# 6) The archer rolls away
	_game.enemies.clear()
	_build("archer", "sniper", {}, [])
	await _wait(4)
	_mouse_at(home + Vector2(150, 0))
	_game.scripted_skills = 1 << TalentCombat.DEFEND_BIT
	await _wait(5)
	await _shot("10-bogenschuetze-ausweichen.png")
	_game.scripted_skills = 0
	quit(0)
