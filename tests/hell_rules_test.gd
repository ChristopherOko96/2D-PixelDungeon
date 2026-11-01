extends SceneTree
## Hell room rules (src/hell/hell_rules.gd): a fight shuts every door of the
## room, keys and puzzles open their own gates only, the boss gate waits for the
## boss, sequence plates must be stepped in order and a wrong plate resets them,
## the map knows a room only through a door that is not a closed secret, seal
## blessings change the hero within their caps, seals and skull heaps break on
## their last hit only, and the clone cannot be stopped once started.

const Rules = preload("res://src/hell/hell_rules.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
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

	# seal blessings (values as in hell_balance.json "blessings")
	var cfg := {"dmg": 1, "rate_mul": 0.85, "rate_min": 0.12, "speed_mul": 1.1, "range_mul": 1.25, "heart": 2}
	var hero := {"dmg": 1.0, "rate": 0.26, "speed_mul": 1.0, "range": 0.8, "hp": 6, "max_hp": 12, "buffs": []}
	Rules.apply_blessing(hero, "dmg", cfg, 24)
	check(is_equal_approx(hero.dmg, 2.0) and hero.buffs.size() == 1, "Höllenfeuer adds one damage and is listed")
	hero.rate = 0.13
	Rules.apply_blessing(hero, "rate", cfg, 24)
	check(is_equal_approx(hero.rate, 0.12), "Schnellfeuer never drops the cooldown below its minimum")
	Rules.apply_blessing(hero, "heart", cfg, 24)
	check(hero.max_hp == 14 and hero.hp == 8, "a heart container raises the cap and heals one heart")
	hero.max_hp = 24
	var at_cap := Rules.apply_blessing(hero, "heart", cfg, 24)
	check(hero.max_hp == 24 and not at_cap.begins_with("Herzcontainer"), "a heart at the cap gives the next open blessing (%s)" % at_cap)
	check(not Rules.blessing_open(hero, "heart", cfg, 24) and Rules.blessing_open(hero, "heart", cfg), "a heart is not offered at the cap (open without a cap)")
	# gear hearts (items.hp_bonus) sit on top of the cap, and a heart never lowers max life
	var armoured := {"hp": 24, "max_hp": 24, "items": {"hp_bonus": 10}}
	check(Rules.raised_max_hp(armoured, 2, 18) == 26 and Rules.heart_room(armoured, 18), "with 10 gear half hearts a heart still grows the base life 14 -> 16")
	armoured.max_hp = 30
	check(Rules.raised_max_hp(armoured, 2, 18) == 30 and not Rules.heart_room(armoured, 18), "above the cap a heart never lowers max life (base 20, cap 18)")
	var plain := {"hp": 20, "max_hp": 20}
	check(Rules.raised_max_hp(plain, 2, 18) == 20, "a max life above the cap stays as it is")
	# the giant vault says the life it really added (nacharbeit L6)
	var vault := {"hp": 16, "max_hp": 16}
	var vault_gain := Rules.raised_max_hp(vault, 4, 18) - int(vault.max_hp)
	check(vault_gain == 2 and Rules.vault_note(vault_gain, 9).contains("+1 Herzcontainer (+2 LP)"), "a vault of 2 hearts at 16 of 18 LP names the 1 container the cap let through (%s)" % Rules.vault_note(vault_gain, 9))
	check(Rules.vault_note(0, 9).contains("schon am Höchstwert") and not Rules.vault_note(0, 9).contains("Herzcontainer"), "at the cap the vault names no container")
	check(Rules.vault_note(1, 9).contains("+1 LP") and Rules.vault_note(4, 9).contains("+2 Herzcontainer (+4 LP)") and Rules.vault_note(4, 9).contains("+9 Runensteine"), "half a heart reads in LP, whole ones as containers with their LP and the stones")
	# the seal's price in words the pixel font can draw (it has no "½")
	check(Rules.price_text(1) == "ein halbes Herz" and Rules.price_text(2) == "1 Herz" and Rules.price_text(3) == "1,5 Herzen" and Rules.price_text(4) == "2 Herzen", "prices read ein halbes Herz / 1 Herz / 1,5 Herzen / 2 Herzen")
	var missing := ""
	for p in range(1, 6):
		for ch in Rules.price_text(p):
			if not PixelStyle.FACE.has_char(ch.unicode_at(0)):
				missing += ch
	check(missing == "", "every character of a price is in the pixel font (missing: '%s')" % missing)
	# blessing caps (balance package D5): speed and range stop at speed_max / range_max,
	# a blessing at its cap gives the next open one in roll order
	var caps := {"dmg": 1, "rate_mul": 0.85, "rate_min": 0.12, "speed_mul": 1.1, "speed_max": 1.3, "range_mul": 1.25, "range_max": 1.6, "heart": 2}
	var runner := {"dmg": 1.0, "rate": 0.26, "speed_mul": 1.0, "range": 0.8, "hp": 6, "max_hp": 12, "buffs": []}
	for i in range(3):
		Rules.apply_blessing(runner, "speed", caps, 24)
	check(is_equal_approx(runner.speed_mul, 1.3), "Glutläufer stops at x1.3 (%.3f)" % runner.speed_mul)
	var given := Rules.apply_blessing(runner, "speed", caps, 24)
	check(is_equal_approx(runner.speed_mul, 1.3) and given.begins_with("Weitschuss") and is_equal_approx(runner.range, 1.0), "a capped speed blessing gives the next open one (%s)" % given)
	Rules.apply_blessing(runner, "range", caps, 24)
	given = Rules.apply_blessing(runner, "range", caps, 24)
	check(is_equal_approx(runner.range, 0.8 * 1.5625) and given.begins_with("Herzcontainer"), "range stays within x1.6, then the seal gives a heart (%.3f, %s)" % [runner.range, given])
	for id: String in Rules.BLESSINGS:
		check(Rules.BLESSING_TEXT.has(id), "blessing %s has a text" % id)

	# breakables: a skull heap needs exactly three hits
	var heap := {"type": "skullheap", "hp": 3}
	check(not Rules.hit_breakable(heap) and not Rules.hit_breakable(heap), "two hits leave the skull heap standing")
	check(Rules.hit_breakable(heap) and heap.broken, "the third hit breaks the skull heap")
	check(not Rules.hit_breakable(heap), "a broken heap ignores further hits")

	# clone skill
	var skill := {"owned": false, "active": false, "left": 120.0}
	check(Rules.start_skill(skill) == "none", "without the floor-9 reward there is no clone")
	skill.owned = true
	check(Rules.start_skill(skill) == "started" and skill.active, "Q starts the clone")
	check(Rules.start_skill(skill) == "running" and skill.active, "a second Q does not stop the clone")
	check(not Rules.tick_skill(skill, 60.0) and is_equal_approx(skill.left, 60.0), "the clock runs while the clone fights")
	skill.active = false
	check(not Rules.tick_skill(skill, 30.0) and is_equal_approx(skill.left, 60.0), "a paused clone keeps its time")
	Rules.start_skill(skill)
	check(Rules.tick_skill(skill, 61.0) and not skill.active and skill.left == 0.0, "the clone ends when its time is spent")
	check(Rules.start_skill(skill) == "spent", "a spent clone cannot be called again")
	print("HELL_RULES checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
