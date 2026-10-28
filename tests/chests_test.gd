extends SceneTree
## Breakable chests and the floor route (src/dungeon/chests.gd, gates in
## dungeon_generator.gd): every floor gets 3-5 chests outside the boss room,
## attacks break them after 3 hits, the loot is a perk the hero takes by
## walking over it, a revisited room keeps its state; a floor has 6 rooms whose
## gates sit in walls and point the way on.

const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
var checked := 0
var failures: Array[String] = []
var game

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("CHESTS_FAIL: ", label)

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
	game.requested_seed = 4242
	game._begin_run()

	# Floor route: 6 rooms, gates in walls, the onward gate marked, stairs last.
	check(game.floor_layouts.size() == 6, "a floor has 6 rooms")
	for index in range(game.floor_layouts.size()):
		var layout: Dictionary = game.floor_layouts[index]
		for exit: Dictionary in layout.exits:
			if str(exit.kind) != "door": continue
			check(exit.has("door_cell"), "room %d: the door is a gate in a wall" % (index + 1))
			check(bool(exit.get("forward", false)) == (int(exit.target_room) > index + 1), "room %d: only the onward gate is marked as the way on" % (index + 1))
	check(Array(game.floor_layouts.back().exits).any(func(exit: Dictionary) -> bool: return str(exit.kind) == "stairs"), "the last room holds the stairs down")

	# Placement: 3-5 chests, never in the boss room, on clear floor.
	var total := 0
	var crates := 0
	for room_id: String in game.chests.chests:
		var boxes: Array = Array(game.chests.chests[room_id]).filter(func(item: Dictionary) -> bool: return str(item.kind) == "chest")
		total += boxes.size()
		crates += Array(game.chests.chests[room_id]).size() - boxes.size()
		if not boxes.is_empty(): check(room_id != str(game.floor_layouts.back().id), "no chest in the boss room")
		var layout: Dictionary = {}
		for candidate: Dictionary in game.floor_layouts:
			if str(candidate.id) == room_id: layout = candidate
		for chest: Dictionary in game.chests.chests[room_id]:
			# Solid: its 32 px cell is part of the room's collision.
			check(Dungeon.segment_blocked(chest.pos, chest.pos, 0.0, layout) and Array(layout.get("breakable_obstacles", [])).has(game.chests._rect_of(chest)), "chests and crates are solid")
	check(total >= 3 and total <= 5, "3 to 5 chests per floor (%d)" % total)
	check(crates >= game.floor_layouts.size() * 2, "every room has a few crates (%d)" % crates)

	# Go to a room with a chest and break it with sword swings.
	var chest_room_id := ""
	for room_id: String in game.chests.chests:
		if chest_room_id.is_empty() and Array(game.chests.chests[room_id]).any(func(item: Dictionary) -> bool: return str(item.kind) == "chest"): chest_room_id = room_id
	for index in range(game.floor_layouts.size()):
		if str(game.floor_layouts[index].id) == chest_room_id: game.room = index + 1
	game._spawn_room()
	game.enemies.clear()
	game.phase = "explore"
	var chest: Dictionary = Array(game.chests.chests[chest_room_id]).filter(func(item: Dictionary) -> bool: return str(item.kind) == "chest")[0]
	var hero: Dictionary = game.players[1]
	hero.pos = Vector2(chest.pos) + Vector2(-40, 0)
	var perks_before := Array(hero.perks).size()
	for swing in range(2):
		game.perk_combat.melee(1, Vector2.RIGHT)
	check(not bool(chest.open) and int(chest.hits) == 2, "two hits leave the chest closed")
	game.perk_combat.melee(1, Vector2.RIGHT)
	check(bool(chest.open), "the third hit breaks it open")
	check(not Dungeon.segment_blocked(chest.pos, chest.pos, 0.0, game.current_layout), "an opened chest no longer blocks")
	var drops: Array = game.chests.loot.get(chest_room_id, [])
	check(drops.size() == 1 and str(drops[0].kind) == "perk" and not str(drops[0].perk).is_empty(), "the chest drops a perk")
	var definition: Dictionary = game.PerkRules.find(game.balance, str(drops[0].perk))
	check(not bool(definition.get("projectile_only", false)), "a swordsman's chest never drops a projectile-only perk")
	var snapshot: Dictionary = game._make_snapshot()
	check(snapshot.loot_chests.chests.size() >= 1 and snapshot.loot_chests.loot.size() == 1, "clients see the chest and its loot")
	# Walking over the loot takes the perk.
	hero.pos = Vector2(drops[0].pos)
	for step in range(40): game.chests.step(1.0 / 60.0)
	check(Array(hero.perks).size() == perks_before + 1 and Array(game.chests.loot.get(chest_room_id, [])).is_empty(), "walking over the loot grants the perk")

	# Shots: one shot counts once on a chest.
	var spare: Dictionary = {"id": 9999, "pos": Vector2(chest.pos) + Vector2(0, 120), "hits": 0, "max": 3, "open": false}
	game.chests.chests[chest_room_id].append(spare)
	var shot := {"owner": 1}
	game.chests.hit_segment(Vector2(spare.pos) - Vector2(30, 0), Vector2(spare.pos) + Vector2(30, 0), 4.0, 1, shot)
	game.chests.hit_segment(Vector2(spare.pos) - Vector2(30, 0), Vector2(spare.pos) + Vector2(30, 0), 4.0, 1, shot)
	check(int(spare.hits) == 1, "a single shot hits a chest once")
	# Explosions hit every chest in range.
	game.chests.hit_circle(Vector2(spare.pos), 40.0, 1)
	check(int(spare.hits) == 2, "an explosion counts as a hit")

	# Leaving and returning keeps the opened chest open.
	var here: int = game.room
	game.room = 1 if here != 1 else 2
	game._spawn_room()
	game.room = here
	game._spawn_room()
	check(bool(chest.open), "a revisited room keeps its opened chest")
	# A new floor places new chests.
	var first_floor_ids: Array = game.chests.chests.keys()
	game._enter_next_floor()
	check(not game.chests.chests.is_empty() and game.chests.chests.keys() != first_floor_ids, "the next floor gets its own chests")
	print("CHESTS checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)
