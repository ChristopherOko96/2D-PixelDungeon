extends SceneTree
## Element reactions readable and rewarded (proposal D3: src/hell/story_elements.gd,
## assets/data/reactions_lexicon.json) on the Krypta scene: a reaction the hero
## sets off is entered as discovered in the profile, shows its sign, and the
## monsters it catches pay reward.hero_exp_mul times the EXP on their kill
## (src/hell/hell_talents.gd killed); one the monsters set off is neither; the
## profile keeps the list (src/progress/profile.gd); the lexicon has an entry
## for every reaction id story_elements can report; the pause's Elemente page
## (src/pause_menu.gd) lists them all and marks the discovered ones. Also the
## room signs of proposal D2 (src/hell/hell_game.gd room_sign): the boss room,
## a found secret room, and none for a secret room behind an unbroken wall.
## Run: godot --headless --path . -s res://tests/reactions_lexicon_test.gd

const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const StoryElements = preload("res://src/hell/story_elements.gd")
const PauseMenu = preload("res://src/pause_menu.gd")
const Profile = preload("res://src/progress/profile.gd")
const TalentRules = preload("res://src/progress/talent_rules.gd")
const HellRules = preload("res://src/hell/hell_rules.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const SOURCE := "res://src/hell/story_elements.gd"

var game: Node
var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("REACTIONS_LEXICON_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_lexicon_covers_every_reaction()
	_test_profile_keeps_the_discovered()
	game = KryptaScene.instantiate()
	game.class_id = "swordsman"
	game.settings_path = "user://settings_test.cfg"
	root.add_child(game)
	for i in range(2):
		await process_frame
	_test_monster_reaction_is_neither_discovered_nor_rewarded()
	_test_hero_reaction_is_discovered_and_rewarded()
	_test_pause_info_names_the_discovered()
	_test_room_signs()
	# the signs and the room plates are drawn by the running world a few frames (no errors)
	for i in range(3):
		await process_frame
	game.queue_free()
	await process_frame
	await _test_pause_page_lists_and_marks()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile_test.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings_test.cfg"))
	print("REACTIONS_LEXICON checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## No fight, no monsters, a fresh discovery list and no signs showing.
func _calm() -> void:
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true
	game.mobs = []
	game.eshots = []
	game.profile.reactions = []
	game.story_elements.popups.clear()


func _hero() -> Vector2:
	return Vector2(game.player.x, game.player.y)


## A monster of the crypt at the hero + `off`, standing still (its attacks far off).
func _spawn(off: Vector2) -> Dictionary:
	var m: Dictionary = game.monsters.spawn(int(game.state.room), _hero() + off, str(game.monsters.defs.keys()[0]))
	m.spawn = 0.0
	for k in range(m.cds.size()):
		m.cds[k] = 99.0
	return m


## A water puddle of radius `r` at `at` (as a monster's water attack leaves one).
func _water(at: Vector2, r := 40.0) -> Dictionary:
	game.monsters._zone({"kind": "puddle", "p": at, "r": r, "T": 8.0, "dmg": 0, "st": "water", "m": {"id": "test", "def": {"name": "Test"}, "boss": false}})
	return game.monsters.zones[-1]


func _signs(id: String) -> Array:
	return game.story_elements.popups.filter(func(q: Dictionary) -> bool: return str(q.get("id", "")) == id)


func _test_lexicon_covers_every_reaction() -> void:
	# Arrange: every id the source reports (_reacted("id"), _explode(..., "id"), the default id)
	var src := FileAccess.get_file_as_string(SOURCE)
	var found := {}
	for pattern: String in ["_reacted\\(\"(\\w+)\"", "_explode\\([^\\n]*\"(\\w+)\"\\)", "id := \"(\\w+)\""]:
		var re := RegEx.new()
		re.compile(pattern)
		for hit: RegExMatch in re.search_all(src):
			found[hit.get_string(1)] = true
	var lex := StoryElements.lexicon()
	var entries: Dictionary = lex.get("reactions", {})
	# Assert
	check(found.size() >= 10, "the reactions report their ids (%s)" % str(found.keys()))
	for id: String in found:
		check(id in StoryElements.REACTIONS, "reported reaction %s is in REACTIONS" % id)
	for id: String in StoryElements.REACTIONS:
		check(found.has(id), "REACTIONS id %s is really reported" % id)
		var info: Dictionary = entries.get(id, {})
		check(not str(info.get("name", "")).is_empty() and not str(info.get("cause", "")).is_empty() and not str(info.get("effect", "")).is_empty(), "the lexicon names %s with cause and effect" % id)
		var rows: Array = info.get("icon", [])
		var pal: Dictionary = info.get("pal", {})
		var whole := rows.size() == 7
		for row: Variant in rows:
			whole = whole and str(row).length() == 7
			for ch in str(row):
				whole = whole and (ch == "." or pal.has(ch))
		check(whole, "the sign of %s is 7 x 7 pixels in its palette" % id)
	check((lex.get("order", []) as Array).size() == StoryElements.REACTIONS.size() and entries.size() == StoryElements.REACTIONS.size(), "the lexicon lists exactly the reactions in its order")
	check(float(lex.get("reward", {}).get("hero_exp_mul", 0.0)) > 1.0, "the hero's reactions pay more EXP")


func _test_profile_keeps_the_discovered() -> void:
	var d := Profile.data()
	var fresh: Variant = Profile.fresh(d).get("reactions")
	check(fresh is Array and (fresh as Array).is_empty(), "a fresh profile has an empty reaction list")
	var kept: Array = Profile.sanitize({"reactions": ["steam", 5, "freeze"]}, d).reactions
	check(kept == ["steam", "freeze"], "the profile keeps the discovered reactions through a reload (%s)" % str(kept))


func _test_monster_reaction_is_neither_discovered_nor_rewarded() -> void:
	# Arrange: a monster standing in water
	_calm()
	var m := _spawn(Vector2(180, 0))
	_water(Vector2(m.p))
	# Act: a monster's fire lands in it (owner 0)
	game.story_elements.fire_at(Vector2(m.p), 30.0)
	# Assert
	check(not (game.profile.reactions as Array).has("steam"), "a monster's steam is not the hero's discovery")
	check(is_equal_approx(game.story_elements.exp_mul(m), 1.0), "a monster's reaction pays no reward")
	var signs := _signs("steam")
	check(signs.size() == 1 and not bool(signs[0].hero), "a monster's steam still shows its sign, quieter (%d)" % signs.size())


func _test_hero_reaction_is_discovered_and_rewarded() -> void:
	# Arrange: one monster in water, one far off; the talents at level 1 with no EXP
	_calm()
	var caught := _spawn(Vector2(180, 0))
	var far := _spawn(Vector2(-900, 0))
	_water(Vector2(caught.p))
	var talents: Object = game.talents
	var data: Dictionary = talents.data
	var state: Dictionary = Profile.class_state(game.profile, game.class_id)
	state.level = 1
	state.exp = 0
	var base := int(data.exp.kill)
	var mul := float(StoryElements.lexicon().reward.hero_exp_mul)
	# Act: the hero's fire lands in the water
	game.story_elements.fire_at(Vector2(caught.p), 30.0, 1)
	# Assert: discovered, its sign new and his, the monster in reach marked
	check((game.profile.reactions as Array).has("steam"), "the hero's steam is entered as discovered")
	var signs := _signs("steam")
	check(signs.size() == 1 and bool(signs[0].hero) and bool(signs[0].fresh), "the hero's first steam shows as his and new")
	check(is_equal_approx(game.story_elements.exp_mul(caught), mul), "the monster the steam caught pays x%.2f" % mul)
	check(is_equal_approx(game.story_elements.exp_mul(far), 1.0), "a monster out of its reach pays the plain EXP")
	# a second steam is not new any more
	_water(Vector2(far.p) + Vector2(600, 0))
	game.story_elements.fire_at(Vector2(far.p) + Vector2(600, 0), 30.0, 1)
	check((game.profile.reactions as Array).count("steam") == 1, "a reaction is entered once")
	# Act: both fall
	check(TalentRules.exp_to_next(data, 1) > roundi(base * mul), "arrange: no level-up in between")
	var run_exp := int(game.state.exp)
	var run_level := int(game.state.level)
	talents.killed(caught)
	var with_bonus := int(state.exp)
	state.exp = 0
	talents.killed(far)
	# Assert
	check(with_bonus == roundi(float(base) * mul), "the caught monster pays %d EXP (got %d)" % [roundi(float(base) * mul), with_bonus])
	check(int(state.exp) == base, "the other pays the plain %d EXP (got %d)" % [base, int(state.exp)])
	check(game.story_elements.popups.any(func(q: Dictionary) -> bool: return str(q.get("kind", "")) == "exp"), "the reward rises from the monster")
	var extra := roundi(float(HeroKit.exp_for(game, caught)) * (mul - 1.0))
	if extra > 0 and int(game.state.level) == run_level:
		check(int(game.state.exp) - run_exp == extra, "the run level gets the reward share too (%d)" % (int(game.state.exp) - run_exp))
	# Act: the time window runs out
	caught.react_t = float(game.state.t) - float(StoryElements.lexicon().reward.window) - 0.1
	check(is_equal_approx(game.story_elements.exp_mul(caught), 1.0), "after the window the reward is gone")


func _test_pause_info_names_the_discovered() -> void:
	var info: Dictionary = game.pause_info()
	check((info.get("reactions", []) as Array).has("steam"), "the pause info names the discovered reactions")


func _test_room_signs() -> void:
	var rooms: Array = game.W.rooms
	var boss: Dictionary = {}
	var secret_door: Dictionary = {}
	for r: Dictionary in rooms:
		if str(r.type) == "boss": boss = r
	for d: Dictionary in game.W.doors:
		if str(d.kind) == "secret": secret_door = d
	if not boss.is_empty():
		boss.cleared = false
		check(game.room_sign(boss) == "icon_demon_big", "the boss room shows the boss sign (%s)" % game.room_sign(boss))
		boss.cleared = true
		check(game.room_sign(boss) == "", "a beaten boss shows none")
	if secret_door.is_empty():
		return
	var room: int = int(secret_door.b) if str(rooms[int(secret_door.b)].type) == "secret" else int(secret_door.a)
	var outside: int = int(secret_door.a) if room == int(secret_door.b) else int(secret_door.b)
	var visited: Dictionary = game.state.visited.duplicate()
	game.state.visited = {outside: true}
	secret_door.broken = false
	check(not HellRules.known_rooms(game.W.doors, game.state.visited).has(room), "a secret room behind an unbroken wall is not known (no sign)")
	secret_door.broken = true
	check(HellRules.known_rooms(game.W.doors, game.state.visited).has(room) and game.room_sign(rooms[room]) == "rune_gem", "a found secret room shows the secret sign (%s)" % game.room_sign(rooms[room]))
	game.state.room = outside
	check(game._sign_side(secret_door) == room, "the door's sign names the room on the far side")
	secret_door.broken = false
	game.state.visited = visited


func _test_pause_page_lists_and_marks() -> void:
	var menu: Control = PauseMenu.new()
	root.add_child(menu)
	await process_frame
	menu.use_story_mode("")
	menu.set_story_state({"overview": "", "quests": [], "reactions": ["steam"]})
	var rows: Array = menu.reaction_rows
	var ids: Array = rows.map(func(r: Dictionary) -> String: return str(r.id))
	check(ids == Array(StoryElements.lexicon().order), "the Elemente page lists every reaction in order (%s)" % str(ids))
	var seen: Array = rows.filter(func(r: Dictionary) -> bool: return bool(r.seen)).map(func(r: Dictionary) -> String: return str(r.id))
	check(seen == ["steam"], "the page marks the discovered ones only (%s)" % str(seen))
	check(menu.navigation.elements.visible and menu.navigation.elements.text == "Elemente", "the story pause has an Elemente section")
	menu.select_section("elements")
	check(menu.pages.elements.visible and not menu.pages.floor.visible, "Elemente opens its page")
	menu.queue_free()
	await process_frame
