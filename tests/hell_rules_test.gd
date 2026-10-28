extends SceneTree
## Hell room rules (src/hell/hell_rules.gd): a fight shuts every door of the
## room, keys and puzzles open their own gates only, the boss gate waits for the
## boss, sequence plates must be stepped in order and a wrong plate resets them,
## and the map knows a room only through a door that is not a closed secret.

const Rules = preload("res://src/hell/hell_rules.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_RULES_FAIL: ", description)


func _rooms() -> Array:
	return [{"fight": false}, {"fight": false}, {"fight": false}]


func _door(kind: String, extra := {}) -> Dictionary:
	var d := {"a": 0, "b": 1, "kind": kind, "key": "", "group": "", "unlocked": false, "broken": false}
	d.merge(extra, true)
	return d


func _initialize() -> void:
	var rooms := _rooms()
	var groups := {"feuer": {"kind": "braziers", "solved": false, "next": 1}}
	check(not Rules.door_closed(_door("open"), rooms, groups, false), "an open door lets the hero through")
	rooms[1].fight = true
	check(Rules.door_closed(_door("open"), rooms, groups, false), "a fight in either room shuts the door")
	rooms[1].fight = false
	var lock := _door("lock", {"key": "A"})
	check(Rules.door_closed(lock, rooms, groups, false), "a lock stays shut without its key")
	lock.unlocked = true
	check(not Rules.door_closed(lock, rooms, groups, false), "an unlocked gate stays open")
	var puzzle := _door("puzzle", {"group": "feuer"})
	check(Rules.door_closed(puzzle, rooms, groups, false), "a puzzle gate waits for its group")
	groups.feuer.solved = true
	check(not Rules.door_closed(puzzle, rooms, groups, false), "a solved group opens its gate")
	check(Rules.door_closed(_door("boss"), rooms, groups, false) and not Rules.door_closed(_door("boss"), rooms, groups, true), "the portal gate opens only after the boss")
	check(Rules.door_closed(_door("secret"), rooms, groups, true), "a secret wall is shut until broken")

	# braziers spread over rooms count as one group
	var ents: Array = [{"group": "feuer", "lit": true}, {"group": "feuer", "lit": false}, {"group": "other", "lit": true}]
	check(Rules.group_progress(ents, "feuer") == Vector2i(1, 2), "group progress counts only its own pieces")

	# sequence plates
	var seq_groups := {"seq": {"kind": "sequence", "solved": false, "next": 1}}
	var plates: Array = [{"group": "seq", "order": 2, "on": false}, {"group": "seq", "order": 1, "on": false}, {"group": "seq", "order": 3, "on": false}]
	check(Rules.step_sequence(plates, seq_groups, plates[1]) == "right", "the first plate in order lights")
	check(Rules.step_sequence(plates, seq_groups, plates[2]) == "wrong" and not plates[1].on and seq_groups.seq.next == 1, "a wrong plate switches all plates off")
	Rules.step_sequence(plates, seq_groups, plates[1])
	Rules.step_sequence(plates, seq_groups, plates[0])
	check(Rules.step_sequence(plates, seq_groups, plates[2]) == "solved" and seq_groups.seq.solved, "the full order solves the group")
	check(Rules.step_sequence(plates, seq_groups, plates[0]) == "ignored", "a solved group ignores further steps")

	# map knowledge
	var doors: Array = [_door("open"), {"a": 1, "b": 2, "kind": "secret", "broken": false}]
	var known := Rules.known_rooms(doors, {0: true})
	check(known.has(1) and not known.has(2), "a neighbour is known, a room behind a closed secret wall is not")
	doors[1].broken = true
	check(Rules.known_rooms(doors, {0: true, 1: true}).has(2), "a broken secret wall reveals the room behind it")
	print("HELL_RULES checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
