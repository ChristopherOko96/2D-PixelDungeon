extends SceneTree
## The talent trees work the same in the Frostgruft and the Hölle
## (src/hell/hell_talents.gd on the hell runtime): Shift + 1-4 and R cast the
## build of the shared profile, talent damage, statuses, blink, wolves,
## shields and reductions reach the hell's mobs and hero, kills bring EXP and
## gold, and the difficulty scales enemy health.

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const Profile = preload("res://src/progress/profile.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_TALENTS_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await test_mage_in_the_frostgruft()
	await test_archer_wolf_and_warrior_shield_in_the_hell()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	print("HELL_TALENTS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## A game whose profile holds a full branch of `spec` (level 30, ultimate).
func _new(class_id: String, spec: String, scene: PackedScene) -> Node:
	var game: Node = scene.instantiate()
	game.start_floor = 2
	game.class_id = class_id
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var d := Profile.data()
	var state := Profile.class_state(game.profile, class_id)
	state.level = 30
	state.ranks = {}
	state.bar = []
	for id: String in d.talents:
		if str(d.talents[id].spec) == spec: state.ranks[id] = int(d.talents[id].ranks)
		if str(d.talents[id].spec) == spec and str(d.talents[id].kind) == "active": state.bar.append(id)
	game.profile.shards = {"have": 0, "earned": 3, "spent": 3}
	game.talents.bind(game, game.profile, game.profile_path, class_id)
	game.mobs.clear()
	game.player.aim = Vector2.RIGHT
	game.aim_at = Vector2(game.player.x + 160.0, game.player.y)
	game.state.hp = 99
	game.state.max_hp = 99
	return game


func _mob(game: Node, offset: Vector2) -> Dictionary:
	var at := Vector2(game.player.x, game.player.y) + offset
	# The Hölle spawns its own monsters (hell_monsters.gd), the Frostgruft its mobs.
	if game.monsters != null: game.monsters.spawn(game.state.room, at, str(game.monsters.defs.keys()[0]))
	else: game._spawn_mob(game.state.room, at, "ice_zombie")
	var m: Dictionary = game.mobs[game.mobs.size() - 1]
	m.spawn = 0.0
	m.hp = 400.0
	m.max = 400.0
	return m


func _tick(game: Node, seconds: float) -> void:
	for i in range(int(seconds / 0.05)): game.talents.update(0.05)


func _key(game: Node, key: Key, shift: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.shift_pressed = shift
	game._unhandled_input(event)


func test_mage_in_the_frostgruft() -> void:
	# Arrange
	var game := await _new("mage", "fire", FrostScene)
	check(game.talents != null and game.talents.hud_state().slots.size() == 3, "the Frostgruft plays the profile's talent build")
	var near := _mob(game, Vector2(60, 0))
	var far := _mob(game, Vector2(400, 0))
	# Act: Shift + 2 is Feuerring (the second active of the fire branch).
	_key(game, KEY_2, true)
	# Assert
	check(near.hp < 400.0 and far.hp == 400.0, "Shift + 2 casts Feuerring around the hero")
	check(near.statuses.has("burn") and float(near.get("burn", 0.0)) > 0.0 or near.has("burn_t") or near.statuses.has("burn"), "Feuerring sets the mob on fire")
	var mana_after_ring: float = game.talents.hud_state().res
	check(mana_after_ring < 100.0, "the cast costs mana")
	_tick(game, 1.1)
	var before_arrow: float = near.hp
	_key(game, KEY_1, true)
	_tick(game, 0.6)
	check(near.hp < before_arrow, "Shift + 1 fires Flammenpfeil")
	# Act: the ultimate on R (Inferno).
	_tick(game, 1.1)
	var hp_before: float = near.hp
	_key(game, KEY_R, false)
	check(near.hp < hp_before, "R casts Inferno")
	# Blink: Phönixschritt moves the hero.
	_tick(game, 1.1)
	var x0: float = game.player.x
	game.talents.tc.runtime(1).res = 100.0
	_key(game, KEY_3, true)
	check(absf(float(game.player.x) - x0) > 20.0, "Phönixschritt moves the hero")
	# Kills: EXP and gold into the shared profile.
	var gold: int = int(game.profile.gold)
	near.hp = 0.0
	game.talents.killed(near)
	check(int(game.profile.gold) > gold, "a kill brings gold into the profile")
	await _free(game)


func test_archer_wolf_and_warrior_shield_in_the_hell() -> void:
	var game := await _new("archer", "beast", HellScene)
	var prey := _mob(game, Vector2(70, 0))
	_key(game, KEY_1, true)
	check(not game.talents.tc.pets.is_empty(), "Wolfsgefährte summons a wolf in the Hölle")
	_tick(game, 2.5)
	check(prey.hp < 400.0, "the wolf bites hell monsters")
	await _free(game)
	var warrior := await _new("swordsman", "guard", HellScene)
	warrior.state.inv = 0.0
	var hp: int = warrior.state.hp
	for i in range(20):
		warrior.state.inv = 0.0
		warrior._hurt("Test", 2)
	var with_skin: int = hp - int(warrior.state.hp)
	check(with_skin < 40, "Eisenhaut lowers damage in the Hölle (%d of 40)" % with_skin)
	_key(warrior, KEY_2, true)
	check(warrior.talents.tc.runtime(1).buffs.has("bulwark"), "Shift + 2 raises Schutzwall")
	await _free(warrior)
	# Difficulty: Albtraum gives mobs more health.
	var hard := await _new("swordsman", "berserk", HellScene)
	var id: String = str(hard.monsters.defs.keys()[0])
	hard.profile.difficulty = "nightmare"
	var tough: Dictionary = hard.monsters.spawn(hard.state.room, Vector2(hard.player.x + 50, hard.player.y), id)
	hard.profile.difficulty = "normal"
	var plain: Dictionary = hard.monsters.spawn(hard.state.room, Vector2(hard.player.x + 80, hard.player.y), id)
	check(float(tough.hp) > float(plain.hp) * 2.0, "Albtraum gives hell monsters more health")
	await _free(hard)


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame
