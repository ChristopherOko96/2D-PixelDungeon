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
	check(snapshot.room_count == game.floor_layouts.size() and snapshot.room_count >= 6, "snapshot reports the 6-10 room floor size")
	check(snapshot.floor_map.size() == layout.doors.size() + 1, "minimap starts with the start room and its neighbours only")
	check(snapshot.floor_map.all(func(item: Dictionary) -> bool: return item.kind != "boss" or layout.doors.values().has(item.id)), "the boss stays hidden until the party sees it")
	check(snapshot.doors_open and snapshot.floor_map[0].cleared, "the start room is cleared and its doors are open")
	check(snapshot.generator_version == 2, "snapshot identifies the generator version")
	check(game.players[1].pos == layout.player_spawns[0], "host spawns at its clear template slot")
	var normal: int = -1
	for i in range(game.floor_layouts.size()):
		if game.floor_layouts[i].kind == "normal": normal = i; break
	game._enter_room(normal, "west")
	check(game.enemies[0].pos == game.current_layout.enemy_spawns[0], "enemy spawns at its clear template slot")
	game._enter_room(normal, "east")
	check(game.enemies[0].pos.x < 448.0, "an east arrival meets mirrored enemy spawns")
	layout = game.current_layout
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
	game.enemies.clear()
	game._check_room_end()
	var boss: int = -1
	for i in range(game.floor_layouts.size()):
		if game.floor_layouts[i].boss: boss = i
	game._enter_room(boss, "north")
	check(game.current_layout.id != first_id, "room transition selects a new stable room ID")
	check(game.bullets.is_empty(), "room transition clears prior projectiles")
	check(game.current_layout.boss and game.enemies[0].boss, "boss template and encounter agree on boss room")
	snapshot = game._make_snapshot()
	var entries := {}
	for item: Dictionary in snapshot.floor_map: entries[item.id] = item
	check(entries.has(first_id) and entries[first_id].cleared, "minimap keeps the cleared start room")
	check(entries.has(game.current_layout.id) and entries[game.current_layout.id].kind == "boss", "minimap marks the boss once the party is there")
	check(not snapshot.doors_open, "boss room doors are locked during the fight")
	game._begin_run()
	check(game.current_layout.id == first_id, "fixed-seed restart reproduces the first room ID")
	check(game.room_states.values().all(func(item: Dictionary) -> bool: return item.visited == (item == game.room_states[first_id])), "a restart forgets the previous floor progress")
