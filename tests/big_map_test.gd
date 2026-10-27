extends SceneTree
## Big-map mode in the running host simulation: the floor is one tile map,
## the party starts in the start room, rooms are pre-filled, bosses sleep until
## the party walks into their arena, the leash keeps the party in view, and
## the boss's fall ends the floor.

const Game = preload("res://src/game.gd")
const FloorMap = preload("res://src/dungeon/floor_map_generator.gd")
var failures: Array[String] = []
var checked := 0

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("BIG_MAP_FAIL: ", description)

func _initialize() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.port_input.text = "18891"
	game._host_session()
	game._add_player(200)
	game.big_map = true
	game.endless = true
	game.floor_number = 1
	game.requested_seed = 4242
	game._begin_run()
	var map: Dictionary = game.current_layout
	check(game.floor_layouts.size() == 1 and map.has("tiles") and map.kind == "floor", "a big-map floor is one tile map")
	check(game.phase == "combat" and not game.enemies.is_empty(), "the rooms are filled when the floor starts")
	var start_ok := true
	for id in game.players:
		if FloorMap.room_at(map, game.players[id].pos) != 0: start_ok = false
	check(start_ok, "the party starts in the start room")
	check(game.enemies.all(func(enemy: Dictionary) -> bool: return FloorMap.room_at(map, enemy.pos) == int(enemy.room)), "every enemy starts in its room")
	check(game.enemies.filter(func(enemy: Dictionary) -> bool: return enemy.get("floor_boss", false)).size() == 1, "the floor has exactly one boss")

	# The boss sleeps until a hero is in its arena.
	var boss: Dictionary = game.enemies.filter(func(enemy: Dictionary) -> bool: return enemy.get("floor_boss", false))[0]
	var boss_start: Vector2 = boss.pos
	for id in game.players: game.players[id].invulnerable = 99.0
	game._simulate_enemies(0.5)
	check(boss.pos == boss_start and not boss.get("awake", false) and game._boss_bar().is_empty(), "the boss waits unseen while the party is elsewhere")
	game.players[1].pos = map.rooms[int(boss.room)].player_spawns[0]
	game._simulate_enemies(0.05)
	check(boss.get("awake", false) and not game._boss_bar().is_empty(), "a hero in the arena wakes the boss and shows its bar")

	# Walls hold on the map: walking at a wall without a doorway keeps a hero inside.
	var hero: Dictionary = game.players[200]
	hero.pos = map.rooms[0].player_spawns[0]
	var floor_rect: Array = map.rooms[0].floor
	var inside := Rect2(float(floor_rect[0]) * 32.0, float(floor_rect[1]) * 32.0, float(floor_rect[2]) * 32.0, float(floor_rect[3]) * 32.0)
	var directions := {"north": Vector2.UP, "east": Vector2.RIGHT, "south": Vector2.DOWN, "west": Vector2.LEFT}
	var closed: String = ""
	for side in directions:
		if not map.rooms[0].doors.has(side): closed = side
	game.commands[200] = {"move": directions.get(closed, Vector2.UP), "aim": Vector2.LEFT, "fire": false, "sequence": 1, "time": Time.get_ticks_msec() / 1000.0}
	game.players[1].pos = hero.pos
	for step in range(150): game._simulate_players(0.02)
	check(not closed.is_empty() and inside.grow(-11.9).has_point(hero.pos), "a wall without a doorway keeps a hero in the room")

	# Leash: a hero cannot run off screen from the rest of the party.
	var anchor: Vector2 = game.players[1].pos
	hero.pos = anchor
	game.commands[200] = {"move": Vector2.RIGHT, "aim": Vector2.RIGHT, "fire": false, "sequence": 2, "time": Time.get_ticks_msec() / 1000.0}
	game.commands.erase(1)
	for step in range(400): game._simulate_players(0.02)
	var limit: float = float(game.balance.camera.view[0]) - 2.0 * float(game.balance.camera.leash_margin)
	check(hero.pos.distance_to(game.players[1].pos) <= limit + 1.0, "the leash keeps a hero within the party's view")

	# The boss's fall ends the floor; the portal opens in its arena.
	boss.hp = 0
	game.enemies.erase(boss)
	game._check_room_end()
	var arena: Array = map.rooms[int(boss.room)].floor
	var arena_rect := Rect2(float(arena[0]) * 32.0, float(arena[1]) * 32.0, float(arena[2]) * 32.0, float(arena[3]) * 32.0)
	check(game.phase == "reward" and game.enemies.is_empty(), "the boss's fall ends the floor with a reward")
	check(arena_rect.has_point(game.portal), "the portal opens inside the boss arena")

	# The next floor is a new map.
	var first_seed: int = game.run_seed
	for id in game.players:
		game.players[id].picked = true
		game.players[id].ready = true
	game._advance_if_ready()
	check(game.floor_number == 2 and game.run_seed != first_seed and game.current_layout.has("tiles"), "the next floor is a new big map")

	print("BIG_MAP checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
