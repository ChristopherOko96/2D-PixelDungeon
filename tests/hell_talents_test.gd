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
	for scene: PackedScene in [HellScene, FrostScene]:
		var necro := await _new("necromancer", "soul", scene)
		var target := _mob(necro, Vector2(30, 0))
		target.act = {"kind": "sweep"}
		necro.talents._status(target, "soul_bind", 1.0, 0.45, 1)
		check(float(target.get("stun", 0.0)) >= 0.45 and target.act == null, "soul bind pauses and interrupts enemy attacks in " + scene.resource_path)
		check(not target.has("frozen"), "soul stun is not an ice effect in " + scene.resource_path)
		var hp_before := float(target.hp)
		_key(necro, KEY_R, false)
		check(necro.talents.tc.guardians.actors.size() == 1, "R summons soul guardian in " + scene.resource_path)
		check(float(target.hp) == hp_before, "guardian deals no instant harvest damage in " + scene.resource_path)
		_tick(necro, 1.05)
		check(float(target.hp) < hp_before, "animated guardian applies real mob damage in " + scene.resource_path)
		check(necro.talents.tc.snapshot().guardians.size() == 1, "same guardian presentation reaches story renderer in " + scene.resource_path)
		var rt: Dictionary = necro.talents.tc.runtime(1)
		check(str(rt.res_kind) == "souls", "story necromancer uses souls in " + scene.resource_path)
		rt.res = 0.0
		var dead := {"p": Vector2(necro.player.x + 10, necro.player.y), "hp": 0.0, "boss": false, "kind": "skeleton"}
		necro.talents.killed(dead)
		var income := float(rt.res)
		check(income >= 8.0, "actual story kill adapter grants souls in " + scene.resource_path)
		necro.talents.killed(dead)
		check(float(rt.res) == income, "duplicate story death cannot mint souls in " + scene.resource_path)
		await _free(necro)
	for scene: PackedScene in [HellScene, FrostScene]:
		var mage := await _new("mage", "fire", scene)
		mage.shots.clear()
		var mana := float(mage.talents.tc.runtime(1).res)
		mage._attack(Vector2.RIGHT)
		check(not mage.shots.is_empty() and str(mage.shots[-1].kind) == "magic", "standard mage attack is neutral magic in " + scene.resource_path)
		check(is_equal_approx(float(mage.talents.tc.runtime(1).res), mana), "standard attack spends no talent mana in " + scene.resource_path)
		await _free(mage)
	await test_mage_in_the_frostgruft()
	await test_archer_wolf_and_warrior_shield_in_the_hell()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://hell_talents_test_profile.json"))
	print("HELL_TALENTS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## A game whose profile holds a level 30 build of `spec`: 20 points from row I
## down (in branch order), then the ultimate; the first four actives on keys 1-4.
func _new(class_id: String, spec: String, scene: PackedScene) -> Node:
	var game: Node = scene.instantiate()
	game.profile_path = "user://hell_talents_test_profile.json"
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
	var points := 0
	for id: String in d.talents:
		var info: Dictionary = d.talents[id]
		if str(info.spec) != spec: continue
		if str(info.kind) == "ultimate":
			state.ranks[id] = 1
			state.ultimate = id
			continue
		if points >= int(d.tiers["8"].points): continue
		state.ranks[id] = mini(int(info.ranks), int(d.tiers["8"].points) - points)
		points += int(state.ranks[id])
		if str(info.kind) == "active" and state.bar.size() < int(d.bar_slots): state.bar.append(id)
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
	check(game.talents != null and game.talents.hud_state().slots.size() == 4, "the Frostgruft plays the profile's talent build")
	var near := _mob(game, Vector2(60, 0))
	var far := _mob(game, Vector2(400, 0))
	# Key 2 is the Pyro-Monster (user wish 30.10.2026): learned, it is already there.
	check(str(game.talents.tc.permanent_pet(1).get("kind", "")) == "pyro", "the learned Pyro-Monster fights beside the hero")
	# Act: key 4 draws the Flammenmeer; a tap without dragging lays a short line.
	_key(game, KEY_4, false)
	_tick(game, 0.1)
	# Assert
	check(game.talents.tc.zones.any(func(z: Dictionary) -> bool: return z.has("path")), "key 4 lays the Flammenmeer as a line")
	check(is_equal_approx(far.hp, 400.0), "the line burns where it was aimed, not on the far mob")
	var mana_after_ring: float = game.talents.hud_state().res
	check(mana_after_ring < float(game.talents.hud_state().res_max), "the cast costs mana")
	_tick(game, 1.1)
	var before_arrow: float = near.hp
	_key(game, KEY_1, false)
	_tick(game, 0.6)
	check(near.hp < before_arrow, "key 1 fires the Feuerball")
	# Act: the ultimate on R (Meteor, it lands after its fall).
	_tick(game, 1.1)
	game.talents.tc.runtime(1).res = 100.0
	_key(game, KEY_R, false)
	check(float(game.talents.tc.runtime(1).cds.get("fire_14", 0.0)) > 50.0, "R casts the Meteor (a minute to reload)")
	# Blink: Phönixschritt moves the hero.
	_tick(game, 1.1)
	var x0: float = game.player.x
	game.talents.tc.runtime(1).res = 100.0
	_key(game, KEY_3, false)
	check(absf(float(game.player.x) - x0) > 20.0, "Phönixschritt moves the hero")
	# Kills: EXP and gold into the shared profile.
	var gold: int = game.gold_count()
	near.hp = 0.0
	game.talents.killed(near)
	check(game.gold_count() > gold, "a kill brings gold to the character")
	await _free(game)


func test_archer_wolf_and_warrior_shield_in_the_hell() -> void:
	var game := await _new("archer", "beast", HellScene)
	var prey := _mob(game, Vector2(70, 0))
	_key(game, KEY_1, false)
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
	_key(warrior, KEY_2, false)
	check(warrior.talents.tc.runtime(1).buffs.has("bulwark"), "key 2 raises Schutzwall")
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
