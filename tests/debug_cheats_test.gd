extends SceneTree
## Debug cheats (src/debug/cheats.gd, assets/data/debug_cheats.json): only in a
## debug build during a solo run; all skills of each class open with every
## upgrade at full rank; level 10; invulnerable; no cooldown; full health;
## clearing the room; the item kit; legendary weapons; refused in multiplayer.

const Game = preload("res://src/game.gd")
const RunTree = preload("res://src/progress/run_tree.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const ItemRules = preload("res://src/items/item_rules.gd")
var checked := 0
var failures: Array[String] = []
var game


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("CHEATS_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game.player_classes[1] = "swordsman"
	game._host_session()
	game.requested_seed = 777
	game._begin_run()
	_test_all_skills_per_class()
	_test_toggles_and_helpers()
	_test_refused_in_multiplayer()
	print("CHEATS checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)


func _cheat(id: String, peer: int = 1) -> void:
	game.action_times.clear()
	game._server_action(peer, "cheat", Array(game.cheats.order()).find(id))


func _test_all_skills_per_class() -> void:
	check(OS.is_debug_build() and game.Cheats.enabled(game), "cheats are on in a solo debug run")
	for class_id: String in ["swordsman", "archer", "mage"]:
		var hero: Dictionary = game.players[1]
		game.HeroClass.apply(hero, class_id, game.balance)
		game.inventory.start_kit(hero)
		hero.class_perks = []
		game.team_progress.team.level = 1
		game.team_progress.team.exp = 0
		_cheat("all_skills")
		var skills: Array = ClassPerks.skills(class_id)
		var level := int(game.team_progress.team.level)
		# no class has standard skills any more (user decision 29.10.2026): the cheat has nothing to open
		check(skills.is_empty() and level >= 1, "%s: no standard class skills to unlock (level %d)" % [class_id, level])
		var missing: Array = []
		for skill: Dictionary in skills:
			for upgrade: Dictionary in skill.get("upgrades", []):
				if ClassPerks.rank(hero, str(upgrade.id)) != int(upgrade.get("max", 1)): missing.append(str(upgrade.id))
		check(missing.is_empty(), "%s: every skill upgrade at full rank (%s)" % [class_id, str(missing)])
		check(Array(hero.get("offer", [])).is_empty(), "%s: no stale level cards left" % class_id)


func _test_toggles_and_helpers() -> void:
	var hero: Dictionary = game.players[1]
	game.HeroClass.apply(hero, "mage", game.balance)
	game.inventory.start_kit(hero)
	hero.class_perks = []
	game.team_progress.team.level = 1
	game.team_progress.team.exp = 0
	_cheat("level_target")
	check(int(game.team_progress.team.level) == 10, "AUF LEVEL 10 reaches level 10 (%d)" % int(game.team_progress.team.level))
	# level-ups give run talent points now (docs/LAUF-DESIGN.de.md), no cards
	check(RunTree.points_left(ClassPerks.run_tree("mage"), ClassPerks.ranks(hero), int(game.team_progress.team.level)) > 0, "the run talent points wait to be spent")
	_cheat("auto_cards")
	check(Array(hero.get("offer", [])).is_empty() and RunTree.points_left(ClassPerks.run_tree("mage"), ClassPerks.ranks(hero), int(game.team_progress.team.level)) == 0, "the cards and points can be spent automatically")
	_cheat("god")
	hero.hp = int(hero.max_hp)
	hero.invulnerable = 0.0
	game._damage_player(1, 4, Vector2.RIGHT)
	game.dot_player(1, 2, "poison")
	check(int(hero.hp) == int(hero.max_hp), "invulnerable: no damage, no poison")
	check(bool(game._make_snapshot().players[1].cheats.god), "the menu sees the toggle")
	_cheat("god")
	check(not bool(hero.cheat_god), "invulnerable turns off again")
	_cheat("no_cooldown")
	game.hero_skills._cooldown(hero, 0, {"cooldown": 6.0})
	check(float(hero.skill_cd[0]) == 0.0, "no cooldown: a used skill is ready at once")
	hero.hp = 1
	_cheat("heal")
	check(int(hero.hp) == int(hero.max_hp), "full health")
	game.enemies.clear()
	game.phase = "combat"
	for offset: Vector2 in [Vector2(150, 0), Vector2(-150, 0)]: game.enemies.append(game._create_enemy("skeleton", Vector2(hero.pos) + offset))
	_cheat("clear_room")
	check(game.enemies.all(func(enemy: Dictionary) -> bool: return float(enemy.hp) <= 0.0), "the room is cleared")
	hero.inventory.bag = []
	_cheat("item_kit")
	var kinds: Array = hero.inventory.bag.map(func(item: Dictionary) -> String: return str(item.type))
	check(kinds.has("crystal") and kinds.has("stone") and kinds.count("potion") >= 5, "the item kit fills the bag (%s)" % str(kinds))
	game.inventory.add(hero, game.inventory.make_weapon("ruby_staff", false, "leaden"))
	game.inventory.act(1, "inv_equip", hero.inventory.bag.size() - 1, Vector2.INF)
	_cheat("legendary")
	check(str(ItemRules.weapon(str(hero.inventory.weapon.id)).rarity) == "legendary" and str(hero.inventory.weapon.curse).is_empty(), "a legendary weapon replaces even a cursed one")


func _test_refused_in_multiplayer() -> void:
	var hero: Dictionary = game.players[1]
	game.players[2] = hero.duplicate(true)
	check(not game.Cheats.enabled(game), "with a second player cheats are off")
	hero.hp = 1
	_cheat("heal")
	check(int(hero.hp) == 1, "the host cannot cheat in multiplayer")
	game.players[2].hp = 1
	_cheat("heal", 2)
	check(int(game.players[2].hp) == 1, "a client cannot cheat")
	game.players.erase(2)
