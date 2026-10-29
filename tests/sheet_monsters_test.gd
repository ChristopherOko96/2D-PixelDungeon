extends SceneTree
## Themed endless floors with the sheet monsters (src/combat/sheet_monsters.gd,
## assets/data/themed_monsters.json): themes never repeat on consecutive
## floors, a floor carries its look, roster and fog, its groups come from the
## theme, sheet monsters attack once awake, and every floor boss and
## mini-boss runs its move sequence without errors.

const Game = preload("res://src/game.gd")
const SheetMonsters = preload("res://src/combat/sheet_monsters.gd")
var checked := 0
var failures: Array[String] = []
var game

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("SHEET_MONSTERS_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_theme_order_never_repeats()
	await _test_themed_floor_and_monsters()
	print("SHEET_MONSTERS checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_theme_order_never_repeats() -> void:
	# Arrange
	var themes: Array = ["gruft", "orklager", "hoelle", "himmel"]
	# Act
	var order: Array = []
	for number in range(1, 21): order.append(SheetMonsters.theme_for(themes, 777, number))
	# Assert
	var repeats := 0
	for i in range(1, order.size()):
		if order[i] == order[i - 1]: repeats += 1
	check(repeats == 0, "consecutive floors never share a theme (%s)" % [order])
	check(SheetMonsters.theme_for(themes, 777, 7) == order[6], "the theme of a floor is stable for its seed")


func _test_themed_floor_and_monsters() -> void:
	# Arrange: a solo host on an endless run.
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
	game._host_session()
	game.requested_seed = 4242
	game.open_floors = true
	# Act
	game._begin_run()
	# Assert: look, roster and fog travel with the layout.
	var layout: Dictionary = game.current_layout
	var theme: Dictionary = layout.get("floor_theme", {})
	check(not theme.is_empty() and not str(theme.get("name", "")).is_empty(), "an endless floor carries its theme")
	check(not Dictionary(layout.get("floor_roster", {})).is_empty() and not Dictionary(layout.get("floor_fog", {})).is_empty(), "an endless floor carries its roster and fog")
	var roster: Dictionary = layout.floor_roster
	var allowed: Array = Array(roster.melee) + Array(roster.ranged) + [roster.boss, roster.miniboss]
	var crypt_plan: Array = game.balance.enemy_roster.floor_plan.strong_group
	var foreign: Array = game.enemies.filter(func(enemy: Dictionary) -> bool: return not allowed.has(str(enemy.kind)) and not crypt_plan.has(str(enemy.kind)))
	check(foreign.is_empty(), "every monster on the floor belongs to its theme (%s)" % [foreign.map(func(enemy: Dictionary) -> String: return str(enemy.kind))])
	check(game.enemies.any(func(enemy: Dictionary) -> bool: return bool(enemy.get("sheet", false))), "the themed floor places sheet monsters")
	var snapshot: Dictionary = game._make_snapshot(false)
	check(snapshot.has("hazards") and snapshot.enemies.any(func(enemy: Dictionary) -> bool: return bool(enemy.get("sheet", false))), "the snapshot carries sheet monsters and hazards")

	# Act: one awake sheet monster next to the hero.
	var hero: Dictionary = game.players[1]
	var theme_name := str(theme.name)
	game.enemies.clear()
	var mob: Dictionary = game._create_enemy("skelet", hero.pos + Vector2(120, 0))
	game.enemies.append(mob)
	mob.aggro = true
	mob.aggro_target = 1
	game.phase = "combat"
	hero.cheat_god = true
	for frame in range(150):
		game._simulate_enemies(1.0 / 30.0)
		game.sheet_monsters.update(1.0 / 30.0)
		game._simulate_bullets(1.0 / 30.0)
	# Assert
	check(int(mob.get("attacks", 0)) > 0, "an awake sheet monster attacks (skelet fan)")

	# Act + assert: every boss and mini-boss runs its moves, ultimate included.
	for kind: String in Array(game.sheet_monsters.data.bosses.keys()) + Array(game.sheet_monsters.data.minibosses.keys()):
		game.enemies.clear()
		game.bullets.clear()
		game.sheet_monsters.reset()
		var boss: Dictionary = game._create_enemy(kind, hero.pos + Vector2(200, 0))
		game.enemies.append(boss)
		boss.asleep = false
		boss.aggro = true
		boss.aggro_target = 1
		boss.hp = int(boss.max_hp * 0.4)
		var moves := {}
		for frame in range(30 * 25):
			game._simulate_enemies(1.0 / 30.0)
			game.sheet_monsters.update(1.0 / 30.0)
			game._simulate_bullets(1.0 / 30.0)
			if not str(boss.get("move", "")).is_empty(): moves[str(boss.move)] = true
		var expected: int = Dictionary(game.sheet_monsters.definition(kind).moves).size()
		check(int(boss.get("attacks", 0)) >= 3 and moves.size() >= mini(3, expected), "%s uses its moves (%s)" % [kind, moves.keys()])
		check(bool(boss.get("ultimate_used", false)), "%s uses its ultimate below its threshold" % kind)

	# Act: the next floor.
	game._enter_next_floor()
	# Assert
	check(str(game.current_layout.floor_theme.name) != theme_name, "the next floor takes another theme")
	game.queue_free()
