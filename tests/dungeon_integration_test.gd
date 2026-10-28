extends SceneTree
## Verifies authoritative geometry at the game boundary, separately from pure generation.

const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
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
	game.set_process(false)
	game.set_physics_process(false)
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
	# The active crypt campaign has ten rooms (Story015), not the old three.
	var room_count: int = game.floor_layouts.size()
	check(room_count == game._run_room_count() and snapshot.floor_map.size() == room_count, "snapshot carries the whole configured floor")
	var boss_rooms: Array = snapshot.floor_map.filter(func(item: Dictionary) -> bool: return item.boss)
	check(boss_rooms.size() == 1 and snapshot.floor_map[room_count - 1].boss, "only the final room is the boss")
	check(not snapshot.floor_map[0].cleared, "active room is initially uncleared")
	check(snapshot.generator_version == 4, "snapshot identifies generator version four")
	# Crypt templates may set their own size (AGENTS.md); it stays on the 32 px grid.
	check(int(layout.tile_size) == 32 and int(layout.world_size[0]) % 32 == 0 and int(layout.world_size[1]) % 32 == 0, "room geometry uses the native thirty-two-pixel tile grid")
	check(game.players[1].pos == layout.player_spawns[0], "host spawns at its clear template slot")
	# Since Story022 the host picks seeded crypt spawn cells instead of fixed slots:
	# never inside geometry and never closer than spawn_min_distance to a player.
	var minimum := float(layout.get("encounter", {}).get("spawn_min_distance", 288))
	var spawns_clear: bool = not game.enemies.is_empty()
	for enemy: Dictionary in game.enemies:
		if Dungeon.segment_blocked(enemy.pos, enemy.pos, float(enemy.radius), layout) or enemy.pos.distance_to(game.players[1].pos) < minimum:
			spawns_clear = false
	check(spawns_clear, "enemies spawn on clear cells at a safe distance from the arriving player")
	# An authored fixture isolates the game simulation from randomized selection.
	var fixture := layout.duplicate(true)
	fixture.obstacles = [[384, 160, 64, 96]]
	game.current_layout = fixture
	game.players[1].pos = Vector2(350, 200)
	game.commands[1] = {"move": Vector2.RIGHT, "aim": Vector2.RIGHT, "fire": false, "time": Time.get_ticks_msec() / 1000.0}
	game._simulate_players(0.5)
	check(game.players[1].pos.x >= 371.99 and game.players[1].pos.x <= 372.001, "native player radius stops precisely before the pillar in a long frame")
	game.enemies = [{"pos": Vector2(350, 200), "hp": 8, "max_hp": 8, "boss": false, "radius": 13, "speed": 55, "shot_timer": 1.0, "nav_timer": 0.0, "nav_path": PackedVector2Array()}]
	game.players[1].pos = Vector2(500, 200)
	game._simulate_enemies(0.5)
	check(game.enemies[0].pos == Vector2(350, 200) and not bool(game.enemies[0].get("aggro", false)), "an enemy that cannot see the hero behind the pillar stays put")
	game.enemies[0].aggro = true
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
	# Map completion follows authoritative encounter IDs, never a room index jump.
	game.cleared_room_ids.append(first_id)
	game.room = 2
	game._spawn_room()
	check(game.current_layout.id != first_id, "room transition selects a new stable room ID")
	snapshot = game._make_snapshot()
	check(snapshot.floor_map[0].cleared and not snapshot.floor_map[1].cleared, "floor map records completed rooms")
	check(game.bullets.is_empty(), "room transition clears prior projectiles")
	game.room = game.floor_layouts.size()
	game._spawn_room()
	# Floor plan: the final room's boss template holds a strong group on floor 1
	# and the Leerenrufer on floor 10.
	check(game.current_layout.boss and not game.enemies.any(func(enemy: Dictionary) -> bool: return enemy.boss), "floor 1's final room is a strong group without a boss")
	game.floor_index = 10
	game._spawn_room()
	check(game.current_layout.boss and game.enemies.any(func(enemy: Dictionary) -> bool: return enemy.boss), "final template and encounter agree on boss room (floor 10)")
	game.floor_index = 1
	for floor_room: Dictionary in game.floor_layouts:
		if str(floor_room.id) not in game.cleared_room_ids: game.cleared_room_ids.append(str(floor_room.id))
	game.phase = "explore"
	snapshot = game._make_snapshot()
	check(snapshot.floor_map.all(func(item: Dictionary) -> bool: return item.cleared), "cleared IDs mark the entire completed floor while exploration remains active")
	game._begin_run()
	check(game.current_layout.id == first_id, "fixed-seed restart reproduces the first room ID")
