extends SceneTree
## The crypt's heroes in the story worlds (src/hero/story_hero.gd): the
## swordsman steps into a swing; Rage swings a second time back the other way;
## the hero's arrows and spells take the crypt's look (and the world stops
## drawing its own for them); a body thrown into a wall takes slam damage and
## is stunned, a boss is never thrown; Hell-Dungeon and Frostgruft alike.

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const StoryHero = preload("res://src/hero/story_hero.gd")

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("STORY_HERO_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_sword(HellScene, "hell")
	await _test_sword(FrostScene, "frost")
	await _test_shots()
	await _test_slam()
	print("STORY_HERO checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _open(scene: PackedScene, class_id: String) -> Node:
	var game: Node = scene.instantiate()
	game.class_id = class_id
	root.add_child(game)
	await process_frame
	game.set_process(false)
	return game


func _test_sword(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "swordsman")
	var kit: RefCounted = game.story_hero
	check(kit is StoryHero, "%s: the world carries the crypt's hero kit" % world)
	var x: float = game.player.x
	game._swing(Vector2.RIGHT)
	check(kit.swings == 1 and float(game.player.x) > x, "%s: the swordsman steps into the swing" % world)
	game.state.rage = 5.0
	game._swing(Vector2.RIGHT)
	kit.update(0.2)
	check(kit.swings == 3 and kit.swing_dir == -1, "%s: Rage swings again, back the other way" % world)
	var view: Dictionary = kit.view_state()
	check(view.skills.has("rage") and bool(view.melee), "%s: the look sees Rage and the sword" % world)
	game.queue_free()
	await process_frame


func _test_shots() -> void:
	var game: Node = await _open(HellScene, "archer")
	game.state.cool = 0.0
	game._fire(Vector2.RIGHT)
	var kit: RefCounted = game.story_hero
	kit.update(0.016)
	check(kit.shots == 1 and kit.handles_shot(game.shots[0]), "the archer's arrow takes the crypt's look")
	check(kit._snapshot.bullets.size() == 1 and str(kit._snapshot.bullets[0].style) == "arrow", "attack_fx sees the arrow")
	game.queue_free()
	await process_frame


func _test_slam() -> void:
	var game: Node = await _open(HellScene, "swordsman")
	var kit: RefCounted = game.story_hero
	game.state.rage = 5.0
	var mob := {"p": Vector2(game.player.x, game.player.y), "hp": 50.0, "max": 50.0, "k": Vector2.ZERO, "kind": "gross", "r": 30.0, "cy": 30.0, "spawn": 0.0, "hit": 0.0,
		"def": {"material": "bone"}, "face": Vector2.LEFT}
	kit.rage_throw(mob, Vector2.LEFT)
	check(mob.has("slam") and (mob.k as Vector2).x < -300.0, "Rage throws a small body hard")
	# the wall stopped it: no movement this frame
	kit.check_slam(mob, mob.p, 1.0 / 60.0)
	check(float(mob.hp) < 50.0 and float(mob.get("stun", 0.0)) > 0.0 and not mob.has("slam"), "a body stopped by a wall takes slam damage and is stunned")
	var boss := {"p": Vector2.ZERO, "hp": 50.0, "kind": "boss", "k": Vector2.ZERO}
	kit.rage_throw(boss, Vector2.LEFT)
	check(not boss.has("slam") and boss.k == Vector2.ZERO, "a boss is never thrown")
	game.queue_free()
	await process_frame
