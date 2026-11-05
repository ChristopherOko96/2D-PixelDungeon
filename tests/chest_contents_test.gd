extends SceneTree
## What the Weltbauer puts in chests and breakable pieces (docs/WELTBAUER.de.md "Teile einstellen"):
## - a placed Mimik or Truhenfresser waits as a chest and wakes on opening, never fights from the start;
## - a chest may be a Mimik always, never or by chance;
## - content "Zufällig" is the floor's choice;
## - up to two chosen enemies come out of a chest or a broken piece and lock the room.

const Data = preload("res://src/world_editor/world_room_data.gd")
const Pack = preload("res://src/world_kit/world_pack.gd")
const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const RoomWorld = preload("res://src/world_editor/world_room_world.gd")
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const TEMP_FOLDER := "user://chest_contents_rooms"
## Chests of the chance test: enough that "sometimes" cannot come out as "never" or "always".
const MANY := 200

var checked := 0
var failures: Array[String] = []
var game: Node


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("CHEST_CONTENTS_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(7)
	_test_placed_mimics_wait_as_chests()
	_test_placed_mimic_ignores_the_chance_mode()
	_test_chest_mimic_option()
	_test_random_content_is_the_floors_choice()
	_test_enemy_slots_hold_two_at_most()
	_test_floor_keeps_the_options()
	game = KryptaScene.instantiate()
	game.class_id = "swordsman"
	root.add_child(game)
	await _frames(2)
	await _test_placed_truhenfresser_wakes_on_opening()
	await _test_mimic_pays_the_chests_content_when_beaten()
	await _test_chest_releases_its_enemies()
	_test_broken_piece_releases_its_enemies()
	_test_broken_crate_releases_its_enemies()
	game.queue_free()
	await process_frame
	print("CHEST_CONTENTS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


# ---------- fixtures ----------

func _fight_room() -> Dictionary:
	for t: Dictionary in RoomFloor.library("krypta"):
		if str(t.role) == "combat":
			var copy: Dictionary = t.duplicate(true)
			copy.objects = (copy.objects as Array).filter(func(o: Dictionary) -> bool: return str(o.kind) in ["start", "prop"] and not o.has("loot"))
			copy.spawn_mode = "manual"
			return copy
	return {}


func _spot(room: Dictionary, k: int) -> Dictionary:
	return {"x": (int(room.width) / 2 + k % 3) * 96.0 + 48.0, "y": (int(room.height) / 2) * 96.0 + 48.0}


func _with(room: Dictionary, parts: Array) -> Dictionary:
	var out: Dictionary = room.duplicate(true)
	for k in range(parts.size()):
		(out.objects as Array).append(_spot(room, k).merged(parts[k]))
	return out


func _raw(room: Dictionary) -> Dictionary:
	return RoomWorld.new(room).build_raw(3, 1)


func _chests(raw: Dictionary) -> Array:
	return (raw.ents as Array).filter(func(e: Dictionary) -> bool: return str(e.type) == "chest")


func _frames(n: int) -> void:
	for i in range(n):
		if game != null and not game.state.is_empty():
			game.state.inv = 0.0
			game.state.hp = game.state.max_hp
		await process_frame


func _calm() -> void:
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true
		r.mimic_loot = []
	game.mobs = []


## A free spot of a fight room of the live floor, and the room.
func _free_spot() -> Dictionary:
	for r: Dictionary in game.W.rooms:
		if str(r.type) != "combat":
			continue
		for c: Vector2i in r.cells:
			var p := Vector2((c.x + 0.5) * 96.0, (c.y + 0.5) * 96.0)
			if game._room_at_world(p.x, p.y) == int(r.index) and not game.box_blocked(Rect2(p.x - 70, p.y - 60, 140, 200), true):
				return {"room": r, "at": p}
	return {}


## Puts chest `e` on the live floor with the hero before it, then opens it.
func _open_on_floor(e: Dictionary) -> Dictionary:
	_calm()
	var free := _free_spot()
	e.x = (free.at as Vector2).x
	e.y = (free.at as Vector2).y
	e.room = int((free.room as Dictionary).index)
	game.W.ents.append(e)
	game._index_solids()
	game.player.x = float(e.x)
	game.player.y = float(e.y) + 80.0
	await _frames(2)
	game.act()
	await _frames(2)
	return free


func _count(id: String) -> int:
	return (game.mobs as Array).filter(func(m: Dictionary) -> bool: return str(m.id) == id).size()


# ---------- room data ----------

func _test_placed_mimics_wait_as_chests() -> void:
	# Arrange: a Mimik, a Truhenfresser and a plain enemy set by hand
	var room := _with(_fight_room(), [{"kind": "enemy", "mob": "mimik"}, {"kind": "enemy", "mob": "truhenfresser"}, {"kind": "enemy", "mob": "zombie"}])
	# Act
	var raw := _raw(room)
	# Assert
	var placed: Array = ((raw.rooms as Array)[0] as Dictionary).get("placed_mobs", [])
	var mobs := placed.map(func(m: Dictionary) -> String: return str(m.mob))
	check(not mobs.has("mimik"), "a placed Mimik does not fight from the start")
	check(not mobs.has("truhenfresser"), "a placed Truhenfresser does not fight from the start")
	check(mobs.has("zombie"), "a plain enemy still stands and fights")
	var chests := _chests(raw)
	check(chests.any(func(e: Dictionary) -> bool: return e.get("mimic", false) and str(e.get("mimic_mob", "")) == "mimik"), "a placed Mimik is a chest that hides a Mimik")
	check(chests.any(func(e: Dictionary) -> bool: return e.get("mimic", false) and str(e.get("mimic_mob", "")) == "truhenfresser"), "a placed Truhenfresser is a chest that hides a Truhenfresser")


func _test_placed_mimic_ignores_the_chance_mode() -> void:
	# Arrange: the room's enemies come by chance, which would drop a set enemy
	var room := _with(_fight_room(), [{"kind": "enemy", "mob": "mimik"}])
	room.spawn_mode = "random"
	# Act
	var chests := _chests(_raw(room))
	# Assert
	check(chests.any(func(e: Dictionary) -> bool: return e.get("mimic", false)), "a placed Mimik stands as a chest in a room of chance enemies too")


func _test_chest_mimic_option() -> void:
	# Arrange
	var never := _with(_fight_room(), [{"kind": "chest", "mimic": "no", "loot": {"type": "gold", "amount": 6}}])
	var always := _with(_fight_room(), [{"kind": "chest", "mimic": "yes", "mimic_mob": "truhenfresser", "loot": {"type": "gold", "amount": 6}}])
	var parts: Array = []
	for i in range(MANY):
		parts.append({"kind": "chest", "mimic": "random", "loot": {"type": "gold", "amount": 6}})
	var chance := _with(_fight_room(), parts)
	# Act
	var never_chest: Dictionary = _chests(_raw(never))[0]
	var always_chest: Dictionary = _chests(_raw(always))[0]
	var by_chance := _chests(_raw(chance)).filter(func(e: Dictionary) -> bool: return e.get("mimic", false)).size()
	# Assert
	check(not never_chest.get("mimic", false), "Mimik \"Nein\" is a real chest")
	check(always_chest.get("mimic", false) and str(always_chest.get("mimic_mob", "")) == "truhenfresser", "Mimik \"Ja\" always bites, with the chosen monster")
	check(by_chance > 0 and by_chance < MANY, "Mimik \"Zufällig\" bites only sometimes (%d of %d)" % [by_chance, MANY])


func _test_random_content_is_the_floors_choice() -> void:
	# Arrange
	var parts: Array = []
	for i in range(MANY):
		parts.append({"kind": "chest", "loot": {"type": "random"}})
	# Act
	var chests := _chests(_raw(_with(_fight_room(), parts)))
	# Assert
	check(chests.size() == MANY, "every chest set with random content stands there")
	check(chests.all(func(e: Dictionary) -> bool: return not e.has("exact") and not e.has("give")), "random content takes the floor's loot rolls")
	check(chests.all(func(e: Dictionary) -> bool: return int((e.loot as Dictionary).get("gems", 0)) > 0), "a random chest holds gold")
	var hearts := chests.filter(func(e: Dictionary) -> bool: return (e.loot as Dictionary).get("heart", false)).size()
	check(hearts > 0 and hearts < MANY, "a random chest holds a heart only sometimes (%d of %d)" % [hearts, MANY])


func _test_enemy_slots_hold_two_at_most() -> void:
	# Arrange
	var room := _with(_fight_room(), [
		{"kind": "chest", "loot": {"type": "gold", "amount": 1}, "enemies": ["zombie", "zombie", "zombie"]},
		{"kind": "prop", "asset": "krypta/urn_a", "enemies": ["zombie"], "loot": {"type": "random"}}])
	# Act
	var raw := _raw(room)
	# Assert
	check((_chests(raw)[0].get("enemies", []) as Array).size() == 2, "a chest lets out two enemies at most")
	var with_enemies := (raw.props as Array).filter(func(p: Dictionary) -> bool: return p.has("enemies"))
	check(with_enemies.size() == 1 and with_enemies[0].enemies == ["zombie"], "a piece keeps its enemies for when it breaks")


func _test_floor_keeps_the_options() -> void:
	# Arrange: every fight room of a library holds all of it
	var base := TEMP_FOLDER
	for t: Dictionary in RoomFloor.library("krypta"):
		var copy: Dictionary = t.duplicate(true)
		copy.erase("_path")
		if str(copy.role) == "combat":
			(copy.objects as Array).append({"kind": "enemy", "mob": "mimik", "x": 288.0, "y": 288.0})
			(copy.objects as Array).append({"kind": "chest", "x": 384.0, "y": 288.0, "mimic": "yes", "mimic_mob": "truhenfresser", "loot": {"type": "random"}, "enemies": ["zombie"]})
		Data.save(copy, base)
	var pack := Pack.new("res://assets/data/krypta_world.json", "res://assets/sprites/krypta/manifest.json")
	pack.pack.room_library.folder = base
	RoomFloor.forget()
	# Act
	var W := RoomFloor.build(2, 4242, pack)
	# Assert
	check(not W.is_empty(), "the floor builds")
	var chests: Array = (W.get("ents", []) as Array).filter(func(e: Dictionary) -> bool: return str(e.type) == "chest")
	check(chests.any(func(e: Dictionary) -> bool: return str(e.get("mimic_mob", "")) == "mimik"), "a floor stands a placed Mimik as a chest")
	check(chests.any(func(e: Dictionary) -> bool: return str(e.get("mimic_mob", "")) == "truhenfresser" and e.get("enemies", []) == ["zombie"] and not e.has("exact")), "a floor keeps a chest's options")
	for r: Dictionary in W.get("rooms", []):
		for m: Dictionary in r.get("placed_mobs", []):
			check(str(m.mob) != "mimik", "no floor room lets a placed Mimik fight from the start")
	RoomFloor.forget()
	for file: String in DirAccess.get_files_at(base):
		DirAccess.remove_absolute(base.path_join(file))
	DirAccess.remove_absolute(base)


# ---------- in the game ----------

func _test_placed_truhenfresser_wakes_on_opening() -> void:
	# Arrange
	var e := {"type": "chest", "mimic": true, "mimic_mob": "truhenfresser", "loot": {"gems": 0}}
	# Act
	var free: Dictionary = await _open_on_floor(e)
	# Assert
	check(_count("truhenfresser") == 1, "opening the chest wakes the Truhenfresser")
	check(_count("mimik") == 0, "and not a plain Mimik")
	check((free.room as Dictionary).fight, "the room locks")
	check((game.W.ents as Array).all(func(x: Dictionary) -> bool: return not is_same(x, e)), "the chest is gone")


func _test_mimic_pays_the_chests_content_when_beaten() -> void:
	# Arrange: a chest set to hold a key that turned out to be a Mimik must not lose the key
	var e := {"type": "chest", "mimic": true, "mimic_mob": "mimik", "exact": true, "loot": {"gems": 0, "key": "A"}}
	var free: Dictionary = await _open_on_floor(e)
	(free.room as Dictionary).drop = ""
	var keys_before := (game.W.ents as Array).filter(func(x: Dictionary) -> bool: return str(x.type) == "key").size()
	# Act: it falls
	game.mobs = []
	game._clear_room(free.room, Vector2(float(e.x), float(e.y)))
	# Assert
	var keys_after := (game.W.ents as Array).filter(func(x: Dictionary) -> bool: return str(x.type) == "key").size()
	check(keys_after == keys_before + 1, "a beaten Mimik gives the chest's key (%d -> %d)" % [keys_before, keys_after])


func _test_chest_releases_its_enemies() -> void:
	# Arrange
	var e := {"type": "chest", "state": "", "exact": true, "loot": {"gems": 1, "heart": false}, "enemies": ["zombie", "zombie"]}
	# Act
	var free: Dictionary = await _open_on_floor(e)
	# Assert
	check(_count("zombie") == 2, "two zombies come out of the chest (%d)" % _count("zombie"))
	check((free.room as Dictionary).fight, "the room locks for them")


func _test_broken_piece_releases_its_enemies() -> void:
	# Arrange
	_calm()
	var free := _free_spot()
	# Act
	var exact: bool = game.world_room_smashed({"enemies": ["zombie"], "loot": {"type": "random"}}, free.at)
	# Assert
	check(exact, "a piece with enemies does not roll the chance loot on top")
	check(_count("zombie") == 1, "the zombie comes out of the broken piece")
	check((free.room as Dictionary).fight, "the room locks for it")


func _test_broken_crate_releases_its_enemies() -> void:
	# Arrange
	_calm()
	var free := _free_spot()
	var at: Vector2 = free.at
	# Act: "random" takes one of the floor's own monsters
	game._break_crate({"type": "crate", "x": at.x, "y": at.y, "room": int((free.room as Dictionary).index), "drop": "none", "enemies": ["random", "zombie"]})
	# Assert
	check((game.mobs as Array).size() == 2, "both enemies come out of the crate (%d)" % (game.mobs as Array).size())
	check((game.mobs as Array).all(func(m: Dictionary) -> bool: return str(m.id) != "mimik"), "a random enemy is never a Mimik without its chest")
