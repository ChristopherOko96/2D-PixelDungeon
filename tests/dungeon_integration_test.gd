extends SceneTree
## Verifies authoritative geometry at the game boundary, separately from pure generation.

const Game = preload("res://src/game.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("DUNGEON_INTEGRATION_FAIL: ", description)

func _initialize() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.port_input.text = "18891"
	game._host_session()
	check(game.hosting, "test host starts")
	if not game.hosting:
		quit(1)
		return
	game.set("requested_seed", 24680)
	game._begin_run()
	var layout_value: Variant = game.get("current_layout")
	check(layout_value is Dictionary and not layout_value.is_empty(), "run has an authoritative room template")
	if layout_value is Dictionary and not layout_value.is_empty():
		_test_room_and_geometry(game, layout_value)
	game._leave_session()
	check(game.get("current_layout") == {}, "leaving clears the old room geometry")
	game.queue_free()
	print("DUNGEON_INTEGRATION checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_room_and_geometry(game: Node, layout: Dictionary) -> void:
	var first_id: String = layout.id
	var snapshot: Dictionary = game._make_snapshot()
	check(game.run_seed == 24680, "explicit seed is used by the host")
	check(snapshot.room_layout == layout, "snapshot carries the chosen geometry")
	check(snapshot.floor_map.size() == 3, "snapshot carries the bounded three-room floor")
	check(snapshot.floor_map[2].boss and not snapshot.floor_map[0].boss, "only the final room is the boss")
	check(not snapshot.floor_map[0].cleared, "active room is initially uncleared")
	check(snapshot.generator_version == 1, "snapshot identifies the generator version")
	check(game.players[1].pos == layout.player_spawns[0], "host spawns at its clear template slot")
	check(game.enemies[0].pos == layout.enemy_spawns[0], "enemy spawns at its clear template slot")
	# An authored fixture isolates the game simulation from randomized selection.
	var fixture := layout.duplicate(true)
	fixture.obstacles = [[384, 160, 64, 96]]
	game.current_layout = fixture
	game.players[1].pos = Vector2(350, 200)
	game.commands[1] = {"move": Vector2.RIGHT, "aim": Vector2.RIGHT, "fire": false, "time": Time.get_ticks_msec() / 1000.0}
	game._simulate_players(0.5)
	check(game.players[1].pos.x <= 372.001, "player cannot cross a pillar in a long frame")
	game.enemies = [{"pos": Vector2(350, 200), "hp": 8, "max_hp": 8, "boss": false, "radius": 13.0, "speed": 55.0, "shot_timer": 1.0, "nav_timer": 0.0, "nav_path": PackedVector2Array()}]
	game.players[1].pos = Vector2(500, 200)
	game._simulate_enemies(0.5)
	check(game.enemies[0].pos.x <= 371.001, "chasing enemy respects pillar collision")
	check(game.enemies[0].pos.distance_to(Vector2(350, 200)) > 1.0, "chasing enemy starts following a route around cover")
	# Both projectile owners must hit the pillar before an actor behind it.
	game.enemies[0].pos = Vector2(500, 200)
	game.bullets.clear()
	game._add_bullet(Vector2(350, 200), Vector2(600, 0), 1, 2)
	game._simulate_bullets(0.25)
	check(game.bullets.is_empty() and game.enemies[0].hp == 8, "player bullet sweep stops at cover before the enemy")
	game.players[1].invulnerable = 0.0
	var health: int = game.players[1].hp
	game._add_bullet(Vector2(350, 200), Vector2(600, 0), 0, 1)
	game._simulate_bullets(0.25)
	check(game.bullets.is_empty() and game.players[1].hp == health, "hostile bullet sweep stops at cover before the player")
	game.room = 2
	game._spawn_room()
	check(game.current_layout.id != first_id, "room transition selects a new stable room ID")
	snapshot = game._make_snapshot()
	check(snapshot.floor_map[0].cleared and not snapshot.floor_map[1].cleared, "floor map records completed rooms")
	check(game.bullets.is_empty(), "room transition clears prior projectiles")
	game.room = 3
	game._spawn_room()
	check(game.current_layout.boss and game.enemies[0].boss, "final template and encounter agree on boss room")
	game.phase = "victory"
	snapshot = game._make_snapshot()
	check(snapshot.floor_map.all(func(item: Dictionary) -> bool: return item.cleared), "victory marks the entire floor cleared")
	game._begin_run()
	check(game.current_layout.id == first_id, "fixed-seed restart reproduces the first room ID")
