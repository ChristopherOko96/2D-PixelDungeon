extends SceneTree
## The parts the reworked jump puzzles are built from (docs/WELTBAUER.de.md "Rätsel bauen"):
## - a Sprungplatte may sleep until a group is solved, then it throws;
## - an Inschrift shows its text while the hero stands near it;
## - a Schatz chest pays much: gold by floor, a heart and several item rolls;
## - a plate of an ordered group may let out up to two enemies when stepped in the wrong order.

const Data = preload("res://src/world_editor/world_room_data.gd")
const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const RoomWorld = preload("res://src/world_editor/world_room_world.gd")
const Contents = preload("res://src/world_kit/room_contents.gd")
const LaunchPads = preload("res://src/hell/launch_pads.gd")
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")

var checked := 0
var failures: Array[String] = []
var game: Node


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("JUMP_PARTS_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(11)
	_test_sleeping_pad_keeps_its_group()
	_test_floor_gives_the_pad_its_rooms_group()
	_test_group_that_only_wakes_pads_is_no_hint()
	_test_tablet_is_text_and_stone()
	_test_hoard_chest_pays_much()
	_test_plate_keeps_its_enemies()
	_test_floor_keeps_the_puzzle_parts()
	game = KryptaScene.instantiate()
	game.class_id = "swordsman"
	root.add_child(game)
	await _frames(2)
	await _test_sleeping_pad_throws_only_when_awake()
	await _test_wrong_plate_lets_out_its_enemies()
	_test_tablet_is_read_near_it()
	await _test_hoard_chest_opens_with_items()
	game.queue_free()
	await process_frame
	print("JUMP_PARTS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


# ---------- fixtures ----------

func _jump_room(parts: Array) -> Dictionary:
	var room := Data.fresh("krypta", "Teiltest", Vector2i(16, 12))
	room.role = "jump"
	for k in range(parts.size()):
		var at := {"x": (3 + k * 2) * 96.0 + 48.0, "y": 5 * 96.0 + 48.0}
		(room.objects as Array).append(at.merged(parts[k]))
	return room


func _raw(room: Dictionary, n := 3) -> Dictionary:
	return RoomWorld.new(room).build_raw(n, 1)


func _ents(raw: Dictionary, type: String) -> Array:
	return (raw.ents as Array).filter(func(e: Dictionary) -> bool: return str(e.type) == type)


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
	game.mobs = []


## A free spot of a fight room of the live floor, and the room.
func _free_spot() -> Dictionary:
	for r: Dictionary in game.W.rooms:
		if str(r.type) != "combat":
			continue
		for c: Vector2i in r.cells:
			var p := Vector2((c.x + 0.5) * 96.0, (c.y + 0.5) * 96.0)
			if game._room_at_world(p.x, p.y) == int(r.index) and not game.box_blocked(Rect2(p.x - 140, p.y - 60, 280, 200), true):
				return {"room": r, "at": p}
	return {}


# ---------- room data ----------

func _test_sleeping_pad_keeps_its_group() -> void:
	# Arrange
	var room := _jump_room([{"kind": "launch", "dir": "e", "cells": 3, "wake": "B"}, {"kind": "launch", "dir": "e", "cells": 3}])
	# Act
	var pads := _ents(_raw(room), "launch")
	# Assert
	check(pads.size() == 2, "both pads stand")
	check(pads.any(func(e: Dictionary) -> bool: return str(e.get("wake", "")) == "B"), "a sleeping pad knows the group that wakes it")
	check(pads.any(func(e: Dictionary) -> bool: return not e.has("wake")), "a plain pad has no group")
	check(not LaunchPads.awake({"wake": "B"}, {"B": {"solved": false}}), "a pad sleeps while its group is unsolved")
	check(LaunchPads.awake({"wake": "B"}, {"B": {"solved": true}}), "the solved group wakes it")
	check(LaunchPads.awake({}, {}), "a plain pad is always awake")


func _test_floor_gives_the_pad_its_rooms_group() -> void:
	# Arrange: groups on a floor carry the room's number
	var W := {"ents": [], "occupied": {}, "COLS": 200}
	var r := {"index": 4}
	# Act
	RoomFloor._put_own(W, r, {"kind": "launch", "dir": "n", "cells": 3, "wake": "C", "x": 48.0, "y": 48.0}, 48.0, 48.0, {})
	# Assert
	check((W.ents as Array).size() == 1 and str(W.ents[0].get("wake", "")) == "4_C", "on a floor the pad waits for its own room's group")


func _test_group_that_only_wakes_pads_is_no_hint() -> void:
	# Arrange
	var room := _jump_room([{"kind": "plate", "group": "B", "order": 0}, {"kind": "launch", "dir": "e", "cells": 3, "wake": "B"}])
	# Act
	var hints := Data.hints(room)
	# Assert
	check(not hints.any(func(h: String) -> bool: return h.contains("Gruppe B")), "a group that wakes pads opens something (%s)" % [hints])


func _test_tablet_is_text_and_stone() -> void:
	# Arrange
	var room := _jump_room([{"kind": "tablet", "text": "Erst der Engel, dann der Mönch."}])
	# Act
	var raw := _raw(room)
	# Assert
	var tablets := _ents(raw, "tablet")
	check(tablets.size() == 1 and str(tablets[0].get("text", "")) == "Erst der Engel, dann der Mönch.", "the Inschrift keeps its text")
	var stones := (raw.props as Array).filter(func(p: Dictionary) -> bool: return str(p.name) == str((Contents.cfg().tablet as Dictionary).asset))
	check(stones.size() == 1 and stones[0].solid != null, "the Inschrift stands as a stone that blocks the way")


func _test_hoard_chest_pays_much() -> void:
	# Arrange
	var room := _jump_room([{"kind": "chest", "loot": {"type": "hoard"}}, {"kind": "chest", "loot": {"type": "random"}}])
	# a Schatz without a tier pays tier 1 (room_contents.gd hoard_tier)
	var paid: Dictionary = (Contents.cfg().hoard as Dictionary).merged(((Contents.cfg().hoard as Dictionary).get("tiers", {}) as Dictionary).get("1", {}), true)
	# Act
	var on_3 := _ents(_raw(room, 3), "chest")
	var on_7 := _ents(_raw(room, 7), "chest")
	# Assert
	var hoard: Dictionary = on_3.filter(func(e: Dictionary) -> bool: return e.has("hoard"))[0] if on_3.any(func(e: Dictionary) -> bool: return e.has("hoard")) else {}
	check(not hoard.is_empty(), "a Schatz chest stands there")
	if hoard.is_empty():
		return
	var later: Dictionary = on_7.filter(func(e: Dictionary) -> bool: return e.has("hoard"))[0]
	var plain: Dictionary = on_3.filter(func(e: Dictionary) -> bool: return not e.has("hoard"))[0]
	check(int(hoard.loot.gems) == int(paid.gems_base) + 3 * int(paid.gems_per_floor), "its gold is base + floor share (%d)" % int(hoard.loot.gems))
	check(int(later.loot.gems) > int(hoard.loot.gems), "a deeper floor pays more")
	check(int(hoard.loot.gems) > int(plain.loot.gems) * 2, "it pays far more than a random chest")
	check(bool(hoard.loot.get("heart", false)), "it holds a heart")
	check((hoard.hoard as Array).size() >= 2, "it rolls several items")
	check(not hoard.has("exact") and bool(hoard.get("magic", false)), "it is a magic chest with the floor's rolls")


func _test_plate_keeps_its_enemies() -> void:
	# Arrange
	var room := _jump_room([{"kind": "plate", "group": "A", "order": 2, "enemies": ["zombie", "zombie", "zombie"]}, {"kind": "plate", "group": "A", "order": 1}])
	# Act
	var plates := _ents(_raw(room), "plate")
	# Assert
	check(plates.any(func(e: Dictionary) -> bool: return e.get("enemies", []) == ["zombie", "zombie"]), "a plate keeps two enemies at most")


func _test_floor_keeps_the_puzzle_parts() -> void:
	# Arrange: the Krypta's own library; a floor that takes the room of the sleeping locks
	var Pack = load("res://src/world_kit/world_pack.gd")
	var pack: RefCounted = Pack.new("res://assets/data/krypta_world.json", "res://assets/sprites/krypta/manifest.json")
	RoomFloor.forget()
	var W := {}
	var room := {}
	for run in range(1, 80):
		for n in range(1, 6):
			var built := RoomFloor.build(n, run * 1000 + 7, pack)
			for r: Dictionary in built.get("rooms", []):
				if str((r.get("file", {}) as Dictionary).get("id", "")) == "k_sprung_moderbecken_la":
					W = built
					room = r
		if not room.is_empty():
			break
	check(not room.is_empty(), "some floor takes the room of the sleeping locks")
	if room.is_empty():
		return
	# Act
	var mine := (W.ents as Array).filter(func(e: Dictionary) -> bool: return int(e.get("room", -1)) == int(room.index))
	# Assert
	var sleeping := mine.filter(func(e: Dictionary) -> bool: return str(e.type) == "launch" and e.has("wake"))
	check(sleeping.size() >= 3, "its sleeping pads are on the floor (%d)" % sleeping.size())
	check(sleeping.all(func(e: Dictionary) -> bool: return (W.groups as Dictionary).has(str(e.wake))), "each waits for a group the floor knows")
	var tablets := mine.filter(func(e: Dictionary) -> bool: return str(e.type) == "tablet")
	check(tablets.size() == 1 and str(tablets[0].text).length() > 20, "its Inschrift keeps the text")
	if tablets.size() == 1:
		var stone := (W.props as Array).filter(func(p: Dictionary) -> bool: return absf(float(p.x) - float(tablets[0].x)) < 1.0 and absf(float(p.y) - float(tablets[0].y)) < 1.0)
		check(stone.size() == 1 and stone[0].has("solid"), "and stands as a solid stone")
	var hoards := mine.filter(func(e: Dictionary) -> bool: return str(e.type) == "chest" and e.has("hoard"))
	check(hoards.size() == 1, "its Schatz chest stands there")
	# its key and lock are the room's own, never the floor's keys A, B, C
	var own := "%dA" % int(room.index)
	var keys := mine.filter(func(e: Dictionary) -> bool: return str(e.type) == "chest" and (e.get("loot", {}) as Dictionary).has("key"))
	check(keys.size() == 1 and str(keys[0].loot.key) == own, "its key chest holds the room's own key (%s)" % [keys.map(func(e: Dictionary) -> String: return str(e.loot.key))])
	var locks := (W.doors as Array).filter(func(d: Dictionary) -> bool: return str(d.kind) == "lock" and str(d.get("key", "")) == own)
	check(locks.size() == 1, "and its gate wants that key")
	RoomFloor.forget()


# ---------- in the game ----------

func _test_sleeping_pad_throws_only_when_awake() -> void:
	# Arrange
	_calm()
	var free := _free_spot()
	var at: Vector2 = free.at
	game.W.groups["t_wake"] = {"kind": "plates", "solved": false}
	var pad := {"type": "launch", "x": at.x, "y": at.y, "dir": "e", "cells": 1, "room": int((free.room as Dictionary).index), "wake": "t_wake"}
	game.W.ents.append(pad)
	game.player.x = at.x + 200.0
	game.player.y = at.y + 10.0
	await _frames(2)
	# Act: on the sleeping pad
	game.player.x = at.x
	game.player.y = at.y + 10.0
	var asleep_thrown := false
	for i in range(30):
		await _frames(1)
		asleep_thrown = asleep_thrown or game.launch_pads.flying()
	# Assert
	check(not asleep_thrown, "a sleeping pad does not throw")
	game.launch_pads.flight = {}
	# Act: the group is solved, the hero steps off and on again
	game._solve_group("t_wake")
	game.player.x = at.x + 200.0
	await _frames(2)
	game.player.x = at.x
	game.player.y = at.y + 10.0
	var thrown := false
	for i in range(30):
		await _frames(1)
		thrown = thrown or game.launch_pads.flying()
	check(thrown, "the woken pad throws")
	game.W.ents.erase(pad)
	game.launch_pads.flight = {}


func _test_wrong_plate_lets_out_its_enemies() -> void:
	# Arrange
	_calm()
	var free := _free_spot()
	var at: Vector2 = free.at
	var room := int((free.room as Dictionary).index)
	game.W.groups["t_seq"] = {"kind": "sequence", "solved": false, "next": 1, "count": 2}
	var first := {"type": "plate", "x": at.x - 100.0, "y": at.y, "group": "t_seq", "order": 1, "on": false, "room": room}
	var second := {"type": "plate", "x": at.x + 100.0, "y": at.y, "group": "t_seq", "order": 2, "on": false, "room": room, "enemies": ["zombie"]}
	game.W.ents.append_array([first, second])
	# Act: the second plate first
	game.player.x = float(second.x)
	game.player.y = float(second.y) + 10.0
	await _frames(3)
	# Assert
	var zombies := (game.mobs as Array).filter(func(m: Dictionary) -> bool: return str(m.id) == "zombie").size()
	check(zombies == 1, "the wrong plate lets out its zombie (%d)" % zombies)
	check((free.room as Dictionary).fight, "the room locks for it")
	check(not second.has("enemies"), "it does so only once")
	game.W.ents.erase(first)
	game.W.ents.erase(second)
	_calm()


func _test_tablet_is_read_near_it() -> void:
	# Arrange
	var free := _free_spot()
	var at: Vector2 = free.at
	var tablet := {"type": "tablet", "x": at.x, "y": at.y, "text": "Der Schatz liegt im Norden.", "room": int((free.room as Dictionary).index)}
	game.W.ents.append(tablet)
	# Act
	game.player.x = at.x
	game.player.y = at.y + 90.0
	var near: String = game.inscription()
	game.player.x = at.x + 900.0
	var far: String = game.inscription()
	# Assert
	check(near == "Der Schatz liegt im Norden.", "near the stone the hero reads it (%s)" % near)
	check(far == "", "far from it nothing shows")
	game.W.ents.erase(tablet)


func _test_hoard_chest_opens_with_items() -> void:
	# Arrange
	_calm()
	var free := _free_spot()
	var at: Vector2 = free.at
	var e := {"type": "chest", "x": at.x, "y": at.y, "room": int((free.room as Dictionary).index), "state": "", "magic": true,
		"loot": {"gems": 20, "heart": true}, "hoard": ["gold_crate", "chest"]}
	game.W.ents.append(e)
	game._index_solids()
	var bag_before: int = (game.story_items.players[1].inventory.bag as Array).size()
	var floor_before: int = (game.story_items.floor_items as Array).size()
	game.player.x = at.x
	game.player.y = at.y + 80.0
	await _frames(2)
	# Act
	game.act()
	await _frames(2)
	# Assert
	var bag_after: int = (game.story_items.players[1].inventory.bag as Array).size()
	var floor_after: int = (game.story_items.floor_items as Array).size()
	check(bag_after + floor_after > bag_before + floor_before, "the Schatz gives items (%d -> %d)" % [bag_before + floor_before, bag_after + floor_after])
	check(str(e.state) == "open", "its heart waits inside")
