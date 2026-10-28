extends SceneTree
## Chests, Mimiks and the floor route (src/dungeon/chests.gd, gates in
## dungeon_generator.gd): every floor gets 3-5 chests outside the boss room,
## attacks do not break them, E opens them, the loot is a perk the hero takes by
## walking over it; a Mimik looks like a chest, bites the opener, fights and
## drops two perks; crates still break; a revisited room keeps its state; a
## floor has 6 rooms whose gates sit in walls and point the way on.

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
		var boxes: Array = Array(game.chests.chests[room_id]).filter(func(item: Dictionary) -> bool: return str(item.kind) != "crate")
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

	# Go to a room with a chest: swings leave it whole, E opens it.
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
	for swing in range(4):
		game.perk_combat.melee(1, Vector2.RIGHT)
	check(not bool(chest.open), "attacks no longer break a chest")
	hero.pos = Vector2(chest.pos) + Vector2(-120, 0)
	game.action_times.clear()
	game._server_action(1, "interact", 0)
	check(not bool(chest.open), "E from afar does nothing")
	hero.pos = Vector2(chest.pos) + Vector2(-30, 0)
	game.action_times.clear()
	game._server_action(1, "interact", 0)
	check(bool(chest.open), "E next to the chest opens it")
	check(Dungeon.segment_blocked(chest.pos, chest.pos, 0.0, game.current_layout), "an opened chest still stands in the way")
	# A chest drops one perk and often an item (assets/data/items.json drops.chest).
	var drops: Array = game.chests.loot.get(chest_room_id, [])
	var perk_drops: Array = drops.filter(func(drop: Dictionary) -> bool: return str(drop.kind) == "perk")
	check(perk_drops.size() == 1 and not str(perk_drops[0].perk).is_empty(), "the chest drops a perk")
	check(drops.all(func(drop: Dictionary) -> bool: return str(drop.kind) in ["perk", "item"]), "anything else a chest drops is an item")
	var definition: Dictionary = game.PerkRules.find(game.balance, str(perk_drops[0].perk)) if not perk_drops.is_empty() else {}
	check(not bool(definition.get("projectile_only", false)), "a swordsman's chest never drops a projectile-only perk")
	var snapshot: Dictionary = game._make_snapshot()
	check(snapshot.loot_chests.chests.size() >= 1 and snapshot.loot_chests.loot.size() == drops.size(), "clients see the chest and its loot")
	# Walking over the loot takes it.
	for drop: Dictionary in drops.duplicate():
		hero.pos = Vector2(drop.pos)
		for step in range(40): game.chests.step(1.0 / 60.0)
	check(Array(hero.perks).size() == perks_before + 1 and Array(game.chests.loot.get(chest_room_id, [])).is_empty(), "walking over the loot grants the perk")

	# Crates still break: one shot counts once, explosions count too.
	var spare: Dictionary = {"id": 9999, "kind": "crate", "pos": Vector2(chest.pos) + Vector2(0, 120), "hits": 0, "max": 3, "open": false}
	game.chests.chests[chest_room_id].append(spare)
	var shot := {"owner": 1}
	game.chests.hit_segment(Vector2(spare.pos) - Vector2(30, 0), Vector2(spare.pos) + Vector2(30, 0), 4.0, 1, shot)
	game.chests.hit_segment(Vector2(spare.pos) - Vector2(30, 0), Vector2(spare.pos) + Vector2(30, 0), 4.0, 1, shot)
	check(int(spare.hits) == 1, "a single shot hits a crate once")
	game.chests.hit_circle(Vector2(spare.pos), 40.0, 1)
	check(int(spare.hits) == 2, "an explosion counts as a hit on a crate")

	# A Mimik: looks like a chest, bites the opener, fights, drops two perks.
	# (In a real run a calm room has beaten its horde; this test skipped the fight.)
	var horde_state: Dictionary = game.hordes.rooms.get(game.hordes._id(), {})
	if not horde_state.is_empty(): horde_state.left = 0
	var bite: int = int(game.chests._value("mimic_bite", 2))
	var mimic: Dictionary = {"id": 9998, "kind": "mimic", "pos": Vector2(chest.pos) + Vector2(160, 0), "hits": 0, "max": 0, "open": false}
	game.chests.chests[chest_room_id].append(mimic)
	snapshot = game._make_snapshot()
	check(snapshot.loot_chests.chests.any(func(item: Dictionary) -> bool: return int(item.id) == 9998 and str(item.kind) == "chest"), "clients see a Mimik as an ordinary chest")
	for swing in range(3):
		hero.pos = Vector2(mimic.pos) + Vector2(-40, 0)
		game.perk_combat.melee(1, Vector2.RIGHT)
	check(game.enemies.is_empty() and Array(game.chests.chests[chest_room_id]).has(mimic), "hitting a Mimik does not wake it")
	hero.pos = Vector2(mimic.pos) + Vector2(-30, 0)
	hero.invulnerable = 0.0
	var hp_before := int(hero.hp)
	game.action_times.clear()
	game._server_action(1, "interact", 0)
	var beast: Array = game.enemies.filter(func(enemy: Dictionary) -> bool: return str(enemy.kind) == "mimic")
	check(beast.size() == 1 and not Array(game.chests.chests[chest_room_id]).has(mimic), "E on a Mimik wakes it as an enemy")
	check(int(hero.hp) == hp_before - bite, "the Mimik bites the opener (%d -> %d)" % [hp_before, int(hero.hp)])
	check(game.phase == "combat", "the room fights again")
	check(not beast.is_empty() and str(beast[0].get("rig", beast[0].get("body_rig", "mimic"))) != "" and game.crypt_ai.definition("mimic").get("rig", "") == "mimic", "the Mimik has its own figure")
	var count_kind := func(kind: String) -> int: return Array(game.chests.loot.get(chest_room_id, [])).filter(func(drop: Dictionary) -> bool: return str(drop.kind) == kind).size()
	var perks_lying: int = count_kind.call("perk")
	var items_lying: int = count_kind.call("item")
	if not beast.is_empty(): game._damage_enemy(beast[0], 9999.0, Vector2.RIGHT, 1)
	check(count_kind.call("perk") == perks_lying + 2, "a fallen Mimik drops two perks")
	check(count_kind.call("item") >= items_lying + 1, "a fallen Mimik also drops a weapon")
	game.enemies.clear()
	game._check_room_end()
	check(game.phase == "explore", "with the Mimik gone the room is calm again")

	# Random Mimiks only from floor 2; the editor's mimic_spawns always hold one.
	var saved_floor: int = game.floor_index
	var counts := {"chest": 0, "mimic": 0}
	for floor_number: int in [1, 4]:
		game.floor_index = floor_number
		for seed_value in range(12):
			game.chests.place_floor(game.floor_layouts, 500 + seed_value)
			for room_id: String in game.chests.chests:
				for item: Dictionary in game.chests.chests[room_id]:
					var kind := str(item.kind)
					if kind != "crate": counts[kind if floor_number > 1 else "chest"] = int(counts.get(kind if floor_number > 1 else "chest", 0)) + 1
					if floor_number == 1: check(kind != "mimic", "no random Mimik on floor 1")
	check(int(counts.mimic) > 0 and int(counts.mimic) < int(counts.chest), "deeper floors hide a few Mimiks (%d of %d)" % [int(counts.mimic), int(counts.mimic) + int(counts.chest)])
	game.floor_index = 1
	var authored: Dictionary = game.floor_layouts[game.room - 1]
	authored.mimic_spawns = [[int(Vector2(chest.pos).x / 32.0), int(Vector2(chest.pos).y / 32.0) + 3]]
	game.chests.place_floor(game.floor_layouts, 77)
	check(Array(game.chests.chests.get(str(authored.id), [])).any(func(item: Dictionary) -> bool: return str(item.kind) == "mimic"), "a Mimik set in the editor is always there")
	authored.erase("mimic_spawns")
	game.floor_index = saved_floor
	game.chests.place_floor(game.floor_layouts, 4242)
	chest.open = true
	game.chests.chests[chest_room_id] = [chest]

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
