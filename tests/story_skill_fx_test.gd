extends SceneTree
## The crypt's skill effects in the story worlds (src/hero/story_skill_fx.gd)
## and the slim shared skill bar (src/ui/skill_bar.gd): the world hands its
## skill shots, chain lightning, blink, whirl, fire bursts, caltrops, Rage and
## the Photoneneis to the crypt look and stops drawing them itself; the beam
## (look and damage) ends at the first wall; effects know the world's walls;
## the bar is low and slim, uses the crypt's skill icons and sits where the
## crypt's hint expects it.

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const SkillBar = preload("res://src/ui/skill_bar.gd")
const SkillIcons = preload("res://src/ui/skill_icons.gd")
const RunHud = preload("res://src/ui/run_hud.gd")

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("STORY_SKILL_FX_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_mage(HellScene, "hell")
	await _test_mage(FrostScene, "frost")
	await _test_beam_wall()
	await _test_sword()
	await _test_archer()
	_test_bar()
	print("STORY_SKILL_FX checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _open(scene: PackedScene, class_id: String) -> Node:
	var game: Node = scene.instantiate()
	game.class_id = class_id
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state.level = 10
	return game


func _events(game: Node, kind: String) -> Array:
	return (game.story_hero.skill_fx.snapshot.skill_fx.events as Array).filter(func(e: Dictionary) -> bool: return str(e.kind) == kind)


func _test_mage(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "mage")
	var look: RefCounted = game.story_hero.skill_fx
	var me := Vector2(game.player.x, game.player.y)
	game.story_hero.update(0.016)
	check(look.fx.open(look.ground(me)), "%s: the hero stands on an open floor cell of the effects" % world)
	check(not look.fx.open(Vector2(-200, -200)), "%s: outside the floor the effects see a wall" % world)
	# fireball: the crypt's projectile, the world skips it
	game.aim_at = me + Vector2(400, -40)
	HeroKit.press(game, "1")
	var ball: Dictionary = game.shots.back()
	check(str(ball.kind) == "fireball" and game.story_hero.handles_shot(ball), "%s: the fireball is drawn by the crypt look" % world)
	game.story_hero.update(0.016)
	check(look.bullets.size() == 1 and str(look.bullets[0].style) == "fireball", "%s: skill_fx sees the fireball" % world)
	# its explosion: a crypt fire burst, not the world's blast
	game._explode(ball, {})
	var blast: Dictionary = game.fx.back()
	check(str(blast.get("shot", "")) == "fireball" and game.story_hero.handles_fx(blast), "%s: the fireball's blast goes to the crypt look" % world)
	game.story_hero.update(0.016)
	var bursts := _events(game, "burst")
	check(bursts.size() == 1 and str(bursts[0].color) == "fire", "%s: a crypt fire burst marks the explosion" % world)
	# chain lightning and blink
	game.fx.append({"kind": "bolt", "p": me - Vector2(0, 40), "q": me + Vector2(200, -40), "t": 0.25, "max": 0.25})
	game.fx.append({"kind": "blink", "p": me - Vector2(0, 40), "q": me + Vector2(100, -40), "t": 0.3, "max": 0.3})
	game.story_hero.update(0.016)
	check(_events(game, "chain").size() == 1 and _events(game, "blink").size() == 1, "%s: chain lightning and blink become crypt events" % world)
	# events fade out
	for i in range(40): game.story_hero.update(0.05)
	check(_events(game, "chain").is_empty(), "%s: finished events are gone" % world)
	# the gravity ball's blast stays the world's
	check(not game.story_hero.handles_fx({"kind": "blast", "shot": "gravity"}), "%s: relic blasts keep the world's look" % world)
	game.queue_free()
	await process_frame


func _test_beam_wall() -> void:
	var game: Node = await _open(HellScene, "mage")
	var C: float = game.C
	# find a floor cell with a wall right of it, a few cells on
	var spot := Vector2i(-1, -1)
	for cy in range(int(game.W.rows)):
		for cx in range(int(game.W.cols) - 4):
			if not game._cell_blocked(cx, cy, true) and not game._cell_blocked(cx + 1, cy, true) and game._cell_blocked(cx + 2, cy, false):
				spot = Vector2i(cx, cy)
				break
		if spot.x >= 0: break
	check(spot.x >= 0, "a floor cell with a wall two cells to its right exists")
	var from := Vector2((spot.x + 0.5) * C, (spot.y + 0.5) * C)
	var end: Vector2 = HeroKit.beam_end(game, from, Vector2.RIGHT, 2000.0)
	check(end.x < (spot.x + 2) * C + 1.0 and end.x > from.x + C, "the Photoneneis ends at the first wall")
	game.player.x = from.x
	game.player.y = from.y + 40.0
	game.aim_at = from + Vector2(500, 0)
	game.state.skill_cd.clear()
	HeroKit.press(game, "4")
	check(str(game.hold.get("id", "")) == "photon", "the beam is held")
	game.story_hero.update(0.016)
	var player: Dictionary = game.story_hero.skill_fx.snapshot.players[1]
	check(player.skills.has("beam"), "the crypt look draws the beam")
	var beam: Array = player.skills.beam
	check(float(beam[2]) * game.story_hero.skill_fx.scale < (spot.x + 2) * C + 1.0, "the drawn beam stops at the wall")
	check(game.story_hero.handles_hold("photon"), "the world no longer draws its own beam")
	# a monster behind the wall is not burnt by the beam
	var behind := {"p": Vector2((spot.x + 3.5) * C, from.y + 30.0), "cy": 30.0, "r": 30.0, "hp": 50.0, "max": 50.0, "spawn": 0.0, "kind": "gross", "k": Vector2.ZERO, "hit": 0.0, "def": {}}
	game.mobs.append(behind)
	game.hold.tick = 0.0
	HeroKit._update_hold(game, 0.016)
	check(is_equal_approx(float(behind.hp), 50.0), "the beam does not hit through the wall")
	game.queue_free()
	await process_frame


func _test_sword() -> void:
	var game: Node = await _open(FrostScene, "swordsman")
	game.aim_at = Vector2(game.player.x + 300, game.player.y)
	HeroKit.press(game, "1")
	check(game.story_hero.handles_fx(game.fx.back()), "the whirl is drawn by the crypt look")
	game.state.skill_cd.clear()
	HeroKit.press(game, "4")
	game.story_hero.update(0.016)
	check(_events(game, "whirl").size() == 1 and float(_events(game, "whirl")[0].radius) <= 56.0, "the whirl raises crypt dust, no bigger than the crypt's")
	check(_events(game, "rage").size() == 1, "Rage starts with the crypt's burst")
	check(game.story_hero.skill_fx.snapshot.players[1].skills.has("rage"), "the Rage aura is drawn")
	game.queue_free()
	await process_frame


func _test_archer() -> void:
	var game: Node = await _open(HellScene, "archer")
	game.aim_at = Vector2(game.player.x + 300, game.player.y)
	HeroKit.press(game, "3")
	game.story_hero.update(0.016)
	var zones: Array = game.story_hero.skill_fx.snapshot.skill_fx.zones
	check(zones.size() == 1 and str(zones[0].kind) == "caltrops", "backflip caltrops take the crypt look")
	check(game.story_hero.handles_zone(game.zones.back()), "the world skips its caltrops")
	check(_events(game, "backflip").size() == 1, "the backflip kicks up crypt dust")
	game.queue_free()
	await process_frame


func _test_bar() -> void:
	var screen := Vector2(1280, 720)
	check(SkillBar.height() <= 56.0, "the skill bar is slim (at most 56 px high)")
	check(SkillBar.top(screen) >= 720.0 - 72.0, "the skill bar sits low at the bottom edge")
	var hud: Control = RunHud.new()
	hud.size = screen
	check(is_equal_approx(hud.skill_bar_top(), SkillBar.top(screen, false)), "the crypt's hint sits above the shared bar")
	hud.free()
	check(SkillIcons.for_id("mage", "chain") != null and SkillIcons.for_id("archer", "fist") != null, "story skills show the crypt's icons")
	check(SkillIcons.for_id("swordsman", "blade_storm") != null, "master skills get an icon")
	check(SkillIcons.for_id("mage", "nothing") == null, "unknown skills have no icon")
