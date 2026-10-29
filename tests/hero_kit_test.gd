extends SceneTree
## The hero's growth in the Frostgruft (src/hell/hero_kit.gd): experience from
## kills and level-ups with heal, banner and flash; the four class skills per
## class open at their level and each does its part; the guardian of the
## run's relic floor (here forced onto floor 4) drops a relic chest only its
## class can open, and the staff's ball pulls, its wall stops enemies and
## shots, and its bar holds shots for a while.
## Every theme sound names a real sound event and the frost run plays sounds.

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const Rules = preload("res://src/hell/hell_rules.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HERO_KIT_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await test_kills_give_experience_and_level_ups_heal()
	await test_skills_open_at_their_level()
	await test_swordsman_skills()
	await test_archer_skills()
	await test_mage_skills()
	await test_gravity_staff_is_sealed_and_mage_only()
	await test_gravity_staff_abilities()
	await test_sounds_name_real_events()
	print("HERO_KIT checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _new(class_id: String, floor_n := 1) -> Node:
	var game: Node = FrostScene.instantiate()
	game.start_floor = floor_n
	game.class_id = class_id
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.mobs.clear()
	return game


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame


func _mob(game: Node, offset: Vector2, kind := "ice_zombie") -> Dictionary:
	game._spawn_mob(game.state.room, Vector2(game.player.x, game.player.y) + offset, kind)
	var m: Dictionary = game.mobs[game.mobs.size() - 1]
	m.spawn = 0.0
	return m


func _level(game: Node, n: int) -> void:
	while int(game.state.level) < n:
		HeroKit.gain(game, HeroKit.need(game.theme.leveling, int(game.state.level)) - int(game.state.exp))


func test_kills_give_experience_and_level_ups_heal() -> void:
	# Arrange
	var game := await _new("archer")
	var cfg: Dictionary = game.theme.leveling
	check(HeroKit.need(cfg, 1) == 60 and HeroKit.need(cfg, 2) > HeroKit.need(cfg, 1), "each level needs more experience (60 for the first)")
	var z := _mob(game, Vector2(400, 0))
	_mob(game, Vector2(-900, 0))
	z.hp = 0.0
	# Act
	game._update_mobs(0.01)
	# Assert
	check(int(game.state.exp) == int(game.theme.mobs.ice_zombie.exp), "a felled ice zombie gives its experience")
	game.state.hp = 2
	var ups := HeroKit.gain(game, 500)
	check(ups >= 2 and int(game.state.level) == 1 + ups, "enough experience gives several levels at once (%d)" % ups)
	check(int(game.state.hp) > 2 and not game.levelfx.is_empty() and str(game.state.banner.text).begins_with("LEVEL"), "a level-up heals, flashes and shows LEVEL")
	await _free(game)


func test_skills_open_at_their_level() -> void:
	for id: String in ["swordsman", "archer", "mage"]:
		var game := await _new(id)
		check(game.skills.size() == 4 and [1, 3, 6, 10] == game.skills.map(func(s: Dictionary) -> int: return int(s.unlock)), "%s has four skills opening at 1, 3, 6 and 10" % id)
		# Act: key 2 at level 1 is still locked
		HeroKit.press(game, "2")
		check(float(game.state.skill_cd.get("2", 0.0)) == 0.0 and str(game.state.toasts[-1].text).contains("ab Level 3"), "%s: a locked skill only says when it opens" % id)
		await _free(game)


func test_swordsman_skills() -> void:
	var game := await _new("swordsman")
	_level(game, 10)
	game.aim_at = Vector2(game.player.x + 400, game.player.y - 40)
	# whirl hits all around
	var a := _mob(game, Vector2(120, 0))
	var b := _mob(game, Vector2(-120, 0))
	var ha: float = a.hp
	HeroKit.press(game, "1")
	check(a.hp < ha and b.hp < ha and float(game.state.skill_cd["1"]) > 0.0, "the whirl blade hits enemies on both sides and cools down")
	HeroKit.press(game, "1")
	check(float(game.state.skill_cd["1"]) > 5.0, "a cooling skill cannot be used again")
	# blade wave pierces
	game.mobs.clear()
	HeroKit.press(game, "2")
	check(game.shots.size() == 1 and game.shots[0].kind == "wave" and game.shots[0].get("pierce", false), "the blade wave flies as a piercing shot")
	# charge dashes
	var x0: float = game.player.x
	HeroKit.press(game, "3")
	for i in range(10):
		HeroKit.update(game, 0.05)
	check(game.player.x > x0 + 100.0 and game.dash.is_empty(), "the charge rushes towards the aim")
	# rage halves the attack pause
	HeroKit.press(game, "4")
	check(is_equal_approx(HeroKit.rate_scale(game), 0.5), "rage makes attacks twice as fast")
	await _free(game)


func test_archer_skills() -> void:
	var game := await _new("archer")
	_level(game, 10)
	game.aim_at = Vector2(game.player.x + 400, game.player.y - 40)
	HeroKit.press(game, "1")
	check(game.shots.size() == 5, "the volley fires five arrows")
	game.shots.clear()
	# ballista: hold, then release
	HeroKit.press(game, "2")
	for i in range(30):
		HeroKit.update(game, 0.05)
	HeroKit.release(game, "2")
	var s: Dictionary = game.shots[0] if not game.shots.is_empty() else {}
	check(not s.is_empty() and s.get("pierce", false) and float(s.mult) >= 7.9, "a fully charged ballista arrow pierces at full damage")
	game.shots.clear()
	# backflip leaves caltrops that slow
	var x0: float = game.player.x
	HeroKit.press(game, "3")
	for i in range(8):
		HeroKit.update(game, 0.05)
	var caltrop: Array = game.zones.filter(func(z: Dictionary) -> bool: return z.kind == "caltrop")
	check(game.player.x < x0 - 80.0 and caltrop.size() == 1, "the back flip jumps away from the aim and leaves caltrops")
	var m := _mob(game, Vector2(0, 0))
	m.p = caltrop[0].p
	check(HeroKit.tick_mob(game, m, 0.05) < 1.0, "caltrops slow an enemy standing in them")
	HeroKit.press(game, "4")
	check(game.shots.size() == 1 and game.shots[0].kind == "fist", "the arrow fist flies")
	await _free(game)


func test_mage_skills() -> void:
	var game := await _new("mage")
	_level(game, 10)
	game.aim_at = Vector2(game.player.x + 400, game.player.y - 40)
	# fireball bursts and burns
	var a := _mob(game, Vector2(300, 0))
	var hp: float = a.hp
	HeroKit.press(game, "1")
	var fb: Dictionary = game.shots[0]
	fb.p = a.p - Vector2(0, a.cy)
	game._update_shots(0.0)
	check(a.hp < hp and float(a.get("burn_t", 0.0)) > 0.0, "the fireball bursts and sets enemies burning")
	# chain lightning jumps
	game.mobs.clear()
	var c1 := _mob(game, Vector2(300, 0))
	var c2 := _mob(game, Vector2(380, 60))
	var c3 := _mob(game, Vector2(460, 0))
	game.aim_at = c1.p - Vector2(0, c1.cy)
	HeroKit.press(game, "2")
	check(c1.hp < c1.max and c2.hp < c2.max and c3.hp < c3.max, "chain lightning jumps from enemy to enemy")
	# blink stops at walls, never through them
	game.mobs.clear()
	game.aim_at = Vector2(game.player.x + 2000, game.player.y - 40)
	var p0 := Vector2(game.player.x, game.player.y)
	HeroKit.press(game, "3")
	var moved := Vector2(game.player.x, game.player.y).distance_to(p0)
	check(moved > 0.0 and moved <= float(HeroKit._skill(game, "blink").distance) + 1.0 and not game.box_blocked(game._player_box(game.player.x, game.player.y)), "blink teleports up to its distance and lands free")
	# photon beam: hold to burn a line (back from the wall blink ran into: the beam stops at walls)
	game.player.x = p0.x
	game.player.y = p0.y
	game.aim_at = Vector2(game.player.x + 400, game.player.y - 40)
	var d := _mob(game, Vector2(250, 0))
	var dh: float = d.hp
	HeroKit.press(game, "4")
	for i in range(8):
		HeroKit.update(game, 0.1)
	HeroKit.release(game, "4")
	check(d.hp < dh and float(game.state.skill_cd["4"]) > 0.0 and game.hold.is_empty(), "the photon beam burns along its line while held")
	await _free(game)


func _relic(game: Node) -> Dictionary:
	for e: Dictionary in game.W.ents:
		if e.type == "relic":
			return e
	return {}


## Makes floor 4 this run's relic floor with the given relic and fells its guardian.
func _boss_drop(game: Node, item: String) -> void:
	game.state.relic_floor = 4
	game.state.relic_item = item
	game.load_floor(4, true)
	game.mobs.clear()
	for r: Dictionary in game.W.rooms:
		if r.type == "boss":
			game.state.room = r.index
			game._clear_room(r, Vector2((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0) * 96.0))


func test_gravity_staff_is_sealed_and_mage_only() -> void:
	# the guardian of the relic floor drops a relic chest
	var game := await _new("archer", 4)
	_boss_drop(game, "gravity_staff")
	var relic := _relic(game)
	check(not relic.is_empty() and relic.get("chest", false) and game.W.rooms[relic.room].type == "boss", "the guardian of the relic floor drops a relic chest")
	game.player.x = relic.x
	game.player.y = relic.y + 60.0
	game.act()
	check(str(game.state.relic) == "", "an archer cannot take the mage's staff")
	await _free(game)
	# a mage opens the chest and takes the staff
	game = await _new("mage", 4)
	_boss_drop(game, "gravity_staff")
	relic = _relic(game)
	game.player.x = relic.x
	game.player.y = relic.y + 60.0
	game.act()
	check(str(game.state.relic) == "gravity_staff" and game.relic_on(), "the mage opens the chest and holds the gravity staff")
	await _free(game)


func test_gravity_staff_abilities() -> void:
	var game := await _new("mage")
	game.state.relic = "gravity_staff"
	game.state.relic_on = true
	game.aim_at = Vector2(game.player.x + 400, game.player.y - 40)
	# the ball replaces the attack and pulls enemies
	var m := _mob(game, Vector2(300, 140))
	game._fire(Vector2.RIGHT)
	check(game.shots.size() == 1 and game.shots[0].kind == "gravity", "with the staff the attack is a gravity ball")
	game.shots[0].p = m.p + Vector2(-120, 0)
	var before: Vector2 = m.p
	game._update_shots(0.05)
	check(m.p.distance_to(game.shots[0].p) < before.distance_to(game.shots[0].p) if not game.shots.is_empty() else m.p != before, "the gravity ball pulls enemies towards itself")
	# key 1: a wall no enemy passes and no shot crosses
	RelicKit.press(game, "1")
	check(game.gwalls.size() == 1 and HeroKit.wall_blocks(game, game.aim_at, 20.0), "key 1 raises a gravity wall at the aim")
	var shot := {"p": game.aim_at + Vector2(10, 0), "v": Vector2(-300, 0), "t": 2.0}
	HeroKit.catch_shot(game, shot, 0.01)
	check(float(shot.t) <= 0.0, "the wall swallows enemy shots")
	# right mouse drag: a bar that holds shots, then lets them fly on
	var a: Vector2 = game.aim_at + Vector2(-200, 300)
	HeroKit.gravity_bar(game, a, a + Vector2(400, 0))
	var held := {"p": a + Vector2(100, 0), "v": Vector2(0, 300), "t": 2.0}
	HeroKit.catch_shot(game, held, 0.01)
	check(held.v == Vector2.ZERO and float(held.held) > 0.0, "the gravity bar stops an enemy shot")
	for i in range(30):
		HeroKit.catch_shot(game, held, 0.1)
	check(held.v == Vector2(0, 300) and held.get("passed", false), "after a while the shot flies on and is not caught again")
	check(game.gbars.size() == 1 and float(game.state.skill_cd.get("g_bar", 0.0)) > 0.0, "the bar cools down after use")
	await _free(game)


func test_sounds_name_real_events() -> void:
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/audio_sfx.json")).events
	var game := await _new("mage")
	var ok := true
	for k: String in game.theme.sounds:
		var name := str(game.theme.sounds[k])
		if name != "" and not events.has(name):
			ok = false
	check(ok, "every theme sound names an event of audio_sfx.json")
	check(game.sfx != null and game.music != null, "the Frostgruft plays sounds and music")
	var before: int = game.sfx.play_count
	game._sound("chest")
	check(game.sfx.play_count > before, "a game event plays its sound")
	await _free(game)
