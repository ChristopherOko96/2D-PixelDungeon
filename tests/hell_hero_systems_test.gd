extends SceneTree
## Hero systems in the Hell-Dungeon (Story 3, assets/data/hell_theme.json): each
## class plays with its own figure, weapon and skills while the hell keeps its
## look and monsters; felled hell monsters give experience and a level-up opens
## skills; stuns hold a monster still; gravity walls swallow enemy shots; and no
## hero blow reaches Ignaroth while he flies.

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const DT := 1.0 / 30.0
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_HERO_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _new(floor_n: int, class_id: String, boss := false) -> Node:
	var game: Node = HellScene.instantiate()
	game.start_floor = floor_n
	game.class_id = class_id
	game.start_at_boss = boss
	root.add_child(game)
	game.set_process(false)
	await process_frame
	return game


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame


## Starts the fight of the first combat room and keeps only one of its monsters.
func _one_monster(game: Node) -> Dictionary:
	var r: Dictionary = {}
	for room: Dictionary in game.W.rooms:
		if room.type == "combat":
			r = room
			break
	game._start_fight(r)
	var m: Dictionary = game.mobs[0]
	game.mobs = [m]
	m.spawn = 0.0
	m.cds = m.cds.map(func(_c: float) -> float: return 99.0)
	return m


func _run() -> void:
	for id: String in ["swordsman", "archer", "mage"]:
		# Arrange / Act
		var game := await _new(1, id)
		# Assert
		check(game.class_id == id and str(game.hero.name) == str(game.theme.classes[id].name), "%s: the hell plays the chosen class" % id)
		check(game.weapon_tex != null and game.skills.size() == 4, "%s: with its weapon and four skills" % id)
		check((game.hero_frames.idle[0] as Texture2D).resource_path.contains(str(game.theme.classes[id].sprite)), "%s: and its own figure" % id)
		check(game.theme.get("styled_hud", false) and not game.theme.get("leveling", {}).is_empty() and not game.theme.get("cards", {}).is_empty(), "%s: with levels, cards and the styled HUD" % id)
		check(str(game.key_name.A) == "Glutschlüssel" and game.monsters != null and not game.theme.has("mobs"), "%s: while keeping hell keys and hell monsters" % id)
		await _free(game)
	# relic and golem textures come from the shared sprite folder
	var mage := await _new(1, "mage")
	check(mage.tex.has("weapon_gravity_staff") and mage.tex.has("rock_throw") and mage.tex.has("ally_golem_walk_f0"), "relic, rock and golem textures are loaded in the hell")
	# experience: a felled hell monster pays its exp
	var m := _one_monster(mage)
	var exp_before := int(mage.state.exp) + int(mage.state.level) * 100000
	m.hp = 0.0
	mage._update(DT)
	check(int(mage.state.exp) + int(mage.state.level) * 100000 > exp_before and int(m.def.exp) > 0, "a felled %s gives experience" % m.id)
	# a level-up opens the next skill
	HeroKit.gain(mage, HeroKit.need(mage.theme.leveling, int(mage.state.level)) - int(mage.state.exp))
	check(int(mage.state.level) >= 2, "enough experience raises the level")
	await _free(mage)
	# a stunned monster stands still and does not attack
	var game := await _new(1, "archer")
	m = _one_monster(game)
	game.player.x = m.p.x + 90.0
	game.player.y = m.p.y
	m.cds = m.cds.map(func(_c: float) -> float: return -1.0)
	m.stun = 1.0
	var at: Vector2 = m.p
	for i in range(10):
		game.state.inv = 5.0
		game._update(DT)
	check(m.p.distance_to(at) < 1.0 and m.act == null, "a stunned %s neither moves nor attacks" % m.id)
	# a gravity wall swallows an enemy shot
	game.gwalls = [{"a": Vector2(game.player.x - 60, game.player.y - 300), "b": Vector2(game.player.x - 60, game.player.y + 300), "t": 5.0, "max": 5.0, "w": 40.0}]
	game.eshots = [{"p": Vector2(game.player.x - 60, game.player.y - 34), "v": Vector2(300, 0), "t": 2.0, "c": "fire"}]
	var hp: int = game.state.hp
	game.monsters.update_shots(DT)
	check(game.eshots.is_empty() and game.state.hp == hp, "a gravity wall swallows an enemy shot")
	await _free(game)
	# Ignaroth in the air takes no hero blow; on the ground he does
	game = await _new(9, "swordsman", true)
	game._update(DT)
	var boss: Dictionary = {}
	for x: Dictionary in game.mobs:
		if x.boss:
			boss = x
	boss.intro = null
	boss.alt = 300.0
	var hp_air: float = boss.hp
	var hit_air: bool = game._damage_mob(boss, Vector2(100, 0), 5.0)
	check(not hit_air and is_equal_approx(boss.hp, hp_air), "a skill cannot hurt Ignaroth while he flies")
	boss.alt = 0.0
	check(game._damage_mob(boss, Vector2(100, 0), 5.0) and boss.hp < hp_air, "on the ground the blow lands")
	await _free(game)
	print("HELL_HERO checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
