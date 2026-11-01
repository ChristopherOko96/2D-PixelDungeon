extends SceneTree
## Balance packages B3 and D1 (production/qa/evidence/gameplay-review/VORSCHLAEGE.md)
## on the Krypta scene (src/hell/hell_game.gd):
## - B3: Shift pressed within talents.json defense <class>.perfect.window before a
##   blow lands is a perfect block: the attacker reels (and deals no blow while
##   it does), the block keeps its charge. Pressed earlier, or mashed, it is a
##   plain block that costs a charge. A roll started within the window readies
##   the archer's counter: his next shot deals counter_mul times its damage.
## - D1: a broken demon seal offers two different blessings for a safe price
##   shown with them, the world waits, and only the chosen blessing is applied;
##   no demons, no hidden roll; with too little life nothing is paid or given.

const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")
const Rules = preload("res://src/hell/hell_rules.gd")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("PERFECT_BLOCK_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(23)
	var game: Node = await _new("swordsman")
	if game.talents == null:
		check(false, "the Krypta hero has his talents (Shift defense)")
	else:
		_test_block_inside_window_staggers_and_keeps_charge(game)
		_test_block_outside_window_is_plain(game)
		_test_mashed_block_is_plain(game)
		_test_perfect_block_breaks_far_shot_shooter_stands(game)
		_test_perfect_block_shot_in_reach_reels_shooter(game)
		_test_plain_shot_still_hurts(game)
		_test_frost_move_hit_names_its_attacker(game)
		_test_seal_offers_two_and_applies_only_the_chosen(game)
		_test_seal_price_never_kills(game)
	game.queue_free()
	await process_frame
	var archer: Node = await _new("archer")
	if archer.talents != null:
		_test_perfect_roll_readies_counter(archer)
		_test_perfect_roll_breaks_shot(archer)
	else:
		check(false, "the Krypta archer has his talents (Shift roll)")
	archer.queue_free()
	await process_frame
	for path: String in ["user://profile_test.json", "user://settings_test.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PERFECT_BLOCK checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## A Krypta world for `class_id`, driven by hand (its own _process is off).
func _new(class_id: String) -> Node:
	var game: Node = KryptaScene.instantiate()
	game.class_id = class_id
	game.settings_path = "user://settings_test.cfg"
	root.add_child(game)
	for i in range(2):
		await process_frame
	game.set_process(false)
	return game


## No fight, no monsters, the hero whole, no recent hit, no recent Shift press.
func _calm(game: Node) -> void:
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true
	game.mobs.clear()
	game.eshots.clear()
	game.state.max_hp = 12
	game.state.hp = 12
	game.state.dead = 0.0
	game.state.inv = 0.0
	game.state.def_held = false
	game.state.def_last = HeroKit.NO_PRESS
	game.state.def_press = HeroKit.NO_PRESS
	_shift(game, false)
	var guard := _guard(game)
	guard.broken = 0.0
	guard.left = float(guard.max)
	guard.iframes = 0.0


func _guard(game: Node) -> Dictionary:
	return game.talents.tc.runtime(1).get("defense", {})


## Shift down or up at game time `t` (the talents read it, then the hero kit notes the press).
func _shift(game: Node, down: bool, t := -1.0) -> void:
	if t >= 0.0:
		game.state.t = t
	game.talents.tc.hold(1, false, down, Vector2.INF, Vector2.ZERO)
	HeroKit.track_defense(game)


func _monster(game: Node) -> Dictionary:
	var hero := Vector2(game.player.x, game.player.y)
	var m: Dictionary = game.monsters.spawn(int(game.state.room), hero + Vector2(40, 0), str(game.monsters.defs.keys()[0]))
	m.spawn = 0.0
	return m


## Monster `id` (the first def for "") at the hero + `offset`, grown in, its attacks far off.
func _monster_at(game: Node, offset: Vector2, id := "") -> Dictionary:
	var hero := Vector2(game.player.x, game.player.y)
	var m: Dictionary = game.monsters.spawn(int(game.state.room), hero + offset, id if id != "" else str(game.monsters.defs.keys()[0]))
	m.spawn = 0.0
	for k in range(m.cds.size()):
		m.cds[k] = 99.0
	return m


## A shot of `by` (hell_monsters.gd's kind, its shooter named) right at the hero's
## body, flying at him from the east; the monsters' shot update lands it.
func _shot_at_hero(game: Node, by: Dictionary) -> Dictionary:
	var s := {"p": Vector2(game.player.x, game.player.y - 34), "v": Vector2(-380, 0), "t": 2.0, "c": "bone", "by": by}
	game.eshots.append(s)
	game.monsters.update_shots(0.001)
	return s


## A block raised `share` of the window before the hit, at game time `t`.
func _block_in_time(game: Node, t: float, share: float) -> void:
	var window := float(game.talents.tc.data.defense.swordsman.perfect.window)
	_shift(game, true, t)
	game.state.t = t + window * share


## L4: a perfect block against a projectile breaks it with the PERFEKT feedback,
## costs nothing; its shooter, far off, does not reel.
func _test_perfect_block_breaks_far_shot_shooter_stands(game: Node) -> void:
	# Arrange: an archer far east, the block raised inside the window
	_calm(game)
	var reach := float(game.talents.tc.data.defense.swordsman.perfect.reel_reach)
	var shooter := _monster_at(game, Vector2(reach + 300.0, 0))
	var guard := _guard(game)
	_block_in_time(game, 60.0, 0.5)
	var hp: int = game.state.hp
	# Act
	var s := _shot_at_hero(game, shooter)
	# Assert
	check(int(game.state.hp) == hp and float(guard.left) == float(guard.max), "a perfect block takes a shot whole and keeps its charge")
	check(bool(s.get("perfect", false)) and float(s.t) <= 0.0 and not game.eshots.has(s), "the shot breaks on the perfect block")
	check(HeroKit.perfect_now(game), "the shot met a perfect block (PERFEKT feedback)")
	check(float(shooter.get("reel", 0.0)) <= 0.0, "a shooter out of melee reach does not reel")


## L4: the same against a shooter within reel_reach: it reels.
func _test_perfect_block_shot_in_reach_reels_shooter(game: Node) -> void:
	# Arrange: an archer close by
	_calm(game)
	var reach := float(game.talents.tc.data.defense.swordsman.perfect.reel_reach)
	var shooter := _monster_at(game, Vector2(maxf(10.0, reach * 0.5), 0))
	_block_in_time(game, 70.0, 0.5)
	var hp: int = game.state.hp
	# Act
	var s := _shot_at_hero(game, shooter)
	# Assert
	check(int(game.state.hp) == hp and bool(s.get("perfect", false)), "the close shot breaks on the perfect block")
	check(float(shooter.get("reel", 0.0)) > 0.5, "a shooter in melee reach reels")


## L4: without Shift in time a shot still lands and nobody reels.
func _test_plain_shot_still_hurts(game: Node) -> void:
	# Arrange: no block raised
	_calm(game)
	var shooter := _monster_at(game, Vector2(60, 0))
	game.state.t = 80.0
	var hp: int = game.state.hp
	# Act
	var s := _shot_at_hero(game, shooter)
	# Assert
	check(int(game.state.hp) < hp and not bool(s.get("perfect", false)), "an unblocked shot hurts")
	check(float(shooter.get("reel", 0.0)) <= 0.0, "an unblocked shot lets nobody reel")


## L4: a Frostgruft move hit (frost_moves.gd) names its attacker: a perfect
## block lets it reel; its projectiles name their shooter too.
func _test_frost_move_hit_names_its_attacker(game: Node) -> void:
	# Arrange: a monster dashing into the hero, the block in time
	_calm(game)
	var dasher := _monster_at(game, Vector2(40, 0))
	_block_in_time(game, 90.0, 0.5)
	var hp: int = game.state.hp
	# Act
	FrostMoves._hit_hero(game, 1, {}, "überrannt", Vector2(dasher.p), "dash", false, "small", dasher)
	# Assert
	check(int(game.state.hp) == hp and float(dasher.get("reel", 0.0)) > 0.5, "a frost move's blow met by a perfect block lets its attacker reel")
	# a move's bullet carries its shooter
	var before: int = game.eshots.size()
	FrostMoves._bullet(game, Vector2(dasher.p), 0.0, {"speed": 200}, dasher)
	check(game.eshots.size() == before + 1 and is_same((game.eshots[-1] as Dictionary).get("by"), dasher), "a frost move's bullet names its shooter")
	game.eshots.clear()


## L4: a perfect roll against a shot breaks it too and readies the counter.
func _test_perfect_roll_breaks_shot(game: Node) -> void:
	# Arrange: the roll began inside the window
	_calm(game)
	var guard := _guard(game)
	var info: Dictionary = game.talents.tc.data.defense.archer
	var shooter := _monster_at(game, Vector2(500, 0))
	game.state.t = 100.0
	game.talents.tc.hold(1, false, true, Vector2.INF, Vector2.RIGHT)
	guard.iframes = float(info.iframes) - float(info.perfect.window) * 0.5
	var hp: int = game.state.hp
	# Act
	var s := _shot_at_hero(game, shooter)
	# Assert
	check(int(game.state.hp) == hp and bool(s.get("perfect", false)) and not game.eshots.has(s), "a perfect roll breaks the shot")
	check(not (game.state.get("counter", {}) as Dictionary).is_empty(), "a perfect roll through a shot readies the counter")
	check(float(shooter.get("reel", 0.0)) <= 0.0, "a roll lets no shooter reel")


func _test_block_inside_window_staggers_and_keeps_charge(game: Node) -> void:
	_calm(game)
	var m := _monster(game)
	var guard := _guard(game)
	var window := float(game.talents.tc.data.defense.swordsman.perfect.window)
	_shift(game, true, 10.0)
	check(bool(guard.up), "Shift raises the swordsman's block")
	game.state.t = 10.0 + window * 0.6
	var hp: int = game.state.hp
	game.monsters._hurt_by(m, 1, "getroffen", m.p, "contact")
	check(float(m.get("reel", 0.0)) > 0.5, "a block raised inside the window lets the attacker reel")
	check(float(m.get("stun", 0.0)) > 0.5 and m.act == null, "the reeling attacker stands and starts no attack")
	check(float(guard.left) == float(guard.max), "a perfect block keeps its charge")
	check(int(game.state.hp) == hp, "a perfect block takes the whole blow")
	# while it reels it strikes nothing, even with the hero open again
	game.state.inv = 0.0
	game.monsters._hurt_by(m, 1, "getroffen", m.p, "contact")
	check(float(guard.left) == float(guard.max) and int(game.state.hp) == hp, "a reeling monster deals no blow")
	# it comes back to itself after the stagger
	HeroKit.tick_mob(game, m, float(game.talents.tc.data.defense.swordsman.perfect.stagger) + 0.05)
	check(float(m.reel) <= 0.0, "the stagger runs out")


func _test_block_outside_window_is_plain(game: Node) -> void:
	_calm(game)
	var m := _monster(game)
	var guard := _guard(game)
	var window := float(game.talents.tc.data.defense.swordsman.perfect.window)
	_shift(game, true, 20.0)
	game.state.t = 20.0 + window + 0.35
	var hp: int = game.state.hp
	game.monsters._hurt_by(m, 1, "getroffen", m.p, "contact")
	check(float(m.get("reel", 0.0)) <= 0.0, "a block held since before the window lets nobody reel")
	check(float(guard.left) == float(guard.max) - 1.0, "a plain block costs a charge")
	check(int(game.state.hp) == hp, "a plain block still takes the blow")


func _test_mashed_block_is_plain(game: Node) -> void:
	_calm(game)
	var m := _monster(game)
	var guard := _guard(game)
	_shift(game, true, 30.0)
	_shift(game, false, 30.05)
	# pressed again at once: within rearm of the last press it is no fresh perfect press
	_shift(game, true, 30.1)
	game.state.t = 30.15
	game.monsters._hurt_by(m, 1, "getroffen", m.p, "contact")
	check(float(m.get("reel", 0.0)) <= 0.0 and float(guard.left) == float(guard.max) - 1.0, "mashing Shift gives a plain block")


func _test_seal_offers_two_and_applies_only_the_chosen(game: Node) -> void:
	_calm(game)
	game.state.buffs = []
	game.state.hp = 10
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var e := {"type": "seal", "x": float(game.player.x), "y": float(game.player.y) - 120.0, "room": int(game.state.room)}
	CardKit.seal_offer(game, e, rng)
	check(CardKit.seal_open(game), "a broken seal opens its blessing cards")
	var pick: Dictionary = game.state.get("seal_pick", {})
	var ids: Array = pick.get("ids", [])
	check(ids.size() == 2 and str(ids[0]) != str(ids[1]), "the seal offers two different blessings")
	check(ids.all(func(id: Variant) -> bool: return Rules.BLESSINGS.has(str(id))), "both are seal blessings")
	var price := int(pick.get("price", -1))
	check(price == int(CardKit.seal_cfg(game).price_hp) and price > 0, "the price shown is the seal's fixed price")
	# the world waits while the cards are open
	var t0 := float(game.state.t)
	game._process(0.016)
	check(float(game.state.t) == t0, "the world waits while the seal's cards are open")
	# key 2 takes the second blessing (and casts no talent)
	var expected: Dictionary = game.state.duplicate(true)
	expected.erase("seal_pick")
	var text := Rules.take_seal_blessing(expected, str(ids[1]), game.balance.blessings, int(game.balance.player.max_hp_cap), price)
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	# a key (or click) in the first seal.arm_s after the cards open was meant for the last blow
	var hp_before := int(game.state.hp)
	game._unhandled_input(key)
	check(CardKit.seal_open(game) and int(game.state.hp) == hp_before and (game.state.buffs as Array).is_empty(), "a key at once after the seal broke picks nothing")
	game.state.seal_pick.ms = Time.get_ticks_msec() - 10000
	game._unhandled_input(key)
	check(not CardKit.seal_open(game), "taking a blessing closes the cards")
	check((game.state.buffs as Array) == [text], "only the chosen blessing is granted")
	var same := true
	for k: String in ["hp", "max_hp", "dmg", "rate", "speed_mul", "range"]:
		same = same and is_equal_approx(float(game.state[k]), float(expected[k]))
	check(same, "the hero carries the chosen blessing and paid its price, nothing of the other")
	# no demons any more: breaking a seal spawns nobody and locks nothing
	game.mobs.clear()
	game._break_seal(e)
	var room: Dictionary = game.W.rooms[int(game.state.room)]
	check(game.mobs.is_empty() and not bool(room.fight), "a seal releases no demons")
	check(CardKit.seal_open(game), "every broken seal offers its blessings (no hidden roll)")
	CardKit.seal_leave(game)


func _test_seal_price_never_kills(game: Node) -> void:
	_calm(game)
	# the Krypta's balance names its own seal (nacharbeit L7): offers and price, no dead keys
	var own: Dictionary = game.balance.get("seal", {})
	check(own.has("offers") and own.has("price_hp") and not own.has("bless_chance") and not own.has("demons"), "krypta_balance.json seal holds offers and price_hp, no bless_chance or demons")
	game.state.buffs = []
	var price := int(CardKit.seal_cfg(game).price_hp)
	game.state.hp = price
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	CardKit.seal_offer(game, {"x": float(game.player.x), "y": float(game.player.y)}, rng)
	check(not CardKit.seal_choose(game, 0), "with too little life a blessing cannot be taken")
	check(int(game.state.hp) == price and (game.state.buffs as Array).is_empty() and CardKit.seal_open(game), "nothing is paid, nothing given, the cards stay")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	game._unhandled_input(esc)
	check(not CardKit.seal_open(game) and int(game.state.hp) == price, "Esc leaves both blessings for nothing")


func _test_perfect_roll_readies_counter(game: Node) -> void:
	_calm(game)
	var guard := _guard(game)
	var info: Dictionary = game.talents.tc.data.defense.archer
	var perfect: Dictionary = info.perfect
	check(str(guard.type) == "dodge", "the archer rolls on Shift")
	game.state.t = 40.0
	game.talents.tc.hold(1, false, true, Vector2.INF, Vector2.RIGHT)
	check(float(guard.iframes) > 0.0, "the roll makes him untouchable")
	# the blow lands inside the window after the roll began
	guard.iframes = float(info.iframes) - float(perfect.window) * 0.5
	var hero := Vector2(game.player.x, game.player.y)
	var hp: int = game.state.hp
	game._hurt("getroffen", 1, hero + Vector2(60, 0))
	check(int(game.state.hp) == hp, "the perfect roll slips the blow")
	check(not (game.state.get("counter", {}) as Dictionary).is_empty(), "a perfect roll readies the counter")
	game.state.cool = 0.0
	game._attack(Vector2.RIGHT)
	var shot: Dictionary = game.shots[-1]
	check(is_equal_approx(float(shot.get("mult", 1.0)), float(perfect.counter_mul)), "the counter shot deals counter_mul times its damage")
	check((game.state.get("counter", {}) as Dictionary).is_empty(), "the counter is spent on that shot")
	# the counter runs out unused
	game.state.counter = {"t": 0.1, "max": 1.5, "mul": 1.5}
	HeroKit.update(game, 0.2)
	check((game.state.get("counter", {}) as Dictionary).is_empty(), "an unused counter runs out")
	# a roll that began earlier than the window only dodges
	game.state.inv = 0.0
	guard.iframes = float(info.iframes) - float(perfect.window) - 0.1
	game._hurt("getroffen", 1, hero + Vector2(60, 0))
	check(int(game.state.hp) == hp and (game.state.get("counter", {}) as Dictionary).is_empty(), "a late roll only dodges, no counter")
	game.state.cool = 0.0
	game._attack(Vector2.RIGHT)
	check(is_equal_approx(float((game.shots[-1] as Dictionary).get("mult", 1.0)), 1.0), "without a counter the shot is plain")
