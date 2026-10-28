extends SceneTree
## An endless run on open floors (game.gd open_floors, open_floor.gd): the run
## starts on one open map with the party in its start room, every enemy asleep
## until a hero sees it, chests and crates on the map, no horde waves, and the
## stairs lead to the next open floor with the next terrain theme.

const Game = preload("res://src/game.gd")
var checked := 0
var failures: Array[String] = []
var game

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("OPEN_FLOOR_GAME_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
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
	# Assert
	var layout: Dictionary = game.current_layout
	check(game.floor_layouts.size() == 1 and bool(layout.get("open_floor", false)), "an endless run starts on one open map")
	var rooms: Array = layout.rooms
	var start: Array = rooms[int(layout.start_room)]
	var start_rect := Rect2(Vector2(start[0], start[1]) * 32, Vector2(start[2], start[3]) * 32)
	check(start_rect.has_point(game.players[1].pos), "the hero starts in the start room")
	check(game.enemies.size() >= layout.enemy_spawns.size(), "every enemy group and the final group are placed (%d)" % game.enemies.size())
	check(game.enemies.all(func(enemy: Dictionary) -> bool: return not bool(enemy.get("aggro", false))), "every enemy, boss included, starts asleep")
	check(game.enemies.any(func(enemy: Dictionary) -> bool: return bool(enemy.get("asleep", false))), "the final group is marked asleep")
	var placed: Array = game.chests.chests.get(str(layout.id), [])
	var chest_count := placed.filter(func(item: Dictionary) -> bool: return str(item.kind) == "chest").size()
	check(chest_count >= int(layout.chest_range[0]) - 1 and chest_count <= int(layout.chest_range[1]), "the map holds its chests (%d)" % chest_count)
	check(placed.any(func(item: Dictionary) -> bool: return str(item.kind) == "crate"), "the map holds crates")
	var before: Array = game.enemies.map(func(enemy: Dictionary) -> Vector2: return enemy.pos)
	for i in range(60): game._simulate_enemies(1.0 / 30.0)
	var moved := 0
	for i in range(game.enemies.size()):
		if Vector2(game.enemies[i].pos).distance_to(before[i]) > 1.0: moved += 1
	check(moved == 0, "nobody walks towards the party before seeing it (%d moved)" % moved)
	game.hordes.step(10.0)
	check(game.enemies.size() == before.size(), "open floors send no horde waves")
	var theme: String = str(layout.theme)
	game._enter_next_floor()
	check(game.floor_index == 2 and game.floor_layouts.size() == 1 and bool(game.current_layout.get("open_floor", false)), "the stairs lead to the next open floor")
	check(str(game.current_layout.theme) != theme, "the next floor takes the next terrain theme")
	print("OPEN_FLOOR_GAME checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
