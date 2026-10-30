extends SceneTree
## Charged puddles (src/combat/boss_moves.gd electrify, balance.json "element"):
## lightning into a liquid pool (water, poison, blood) charges it for a while;
## enemies standing in it take damage and are stunned each tick, enemies beside
## it and the heroes are spared; ice and lava do not conduct; the charge runs
## out; a storm zone over a puddle charges it; the snapshot carries the charge
## so every client draws it.

const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const DT := 1.0 / 60.0
var checked := 0
var failures: Array[String] = []
var game


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ELEMENT_CHARGE_FAIL: ", label)


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
	_test_lightning_charges_liquids_only()
	_test_charged_puddle_hurts_and_stuns_enemies_in_it()
	_test_charge_runs_out()
	_test_storm_charges_a_puddle()
	print("ELEMENT_CHARGE checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)


func _arena() -> Dictionary:
	var best := 0
	for index in range(game.floor_layouts.size()):
		var world: Array = game.floor_layouts[index].world_size
		var own: Array = game.floor_layouts[best].world_size
		if float(world[0]) * float(world[1]) > float(own[0]) * float(own[1]): best = index
	game.room = best + 1
	game._spawn_room()
	game.enemies.clear()
	game.bullets.clear()
	game.boss_moves.reset()
	game.hero_skills.zones.clear()
	game.phase = "combat"
	var hero: Dictionary = game.players[1]
	hero.hp = 200
	hero.max_hp = 200
	hero.invulnerable = 0.0
	hero.effects = {}
	hero.pos = _open_spot(game.current_layout)
	return hero


func _open_spot(layout: Dictionary) -> Vector2:
	var best := Vector2.ZERO
	var room := 0.0
	for entry: Dictionary in layout.painted_tiles:
		if str(entry.get("layer", "")) != "floor": continue
		var point := Vector2(float(entry.x) * 32.0 + 16.0, float(entry.y) * 32.0 + 16.0)
		var free := 0.0
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var reach := 0.0
			while reach < 320.0 and not Dungeon.segment_blocked(point, point + direction * (reach + 16.0), 14.0, layout): reach += 16.0
			free += minf(reach, 200.0)
		if free > room:
			room = free
			best = point
	return best


## A skeleton standing at `at`, kept there.
func _foe(at: Vector2) -> Dictionary:
	var enemy: Dictionary = game._create_enemy("skeleton", at)
	enemy.pos = at
	enemy.hp = 500.0
	enemy.max_hp = 500.0
	game.enemies.append(enemy)
	return enemy


func _settle(seconds: float, keep: Array = []) -> void:
	var spots := keep.map(func(enemy: Dictionary) -> Vector2: return Vector2(enemy.pos))
	var time := 0.0
	while time < seconds:
		game.boss_moves.update(DT)
		game.hero_skills._step_zones(DT)
		for index in range(keep.size()): keep[index].pos = spots[index]
		game.players[1].invulnerable = 0.0
		time += DT


func _pool(at: Vector2, style: String) -> Dictionary:
	return game.boss_moves._pool(at, {"style": style, "radius": 40, "time": 30, "dps": 0}, Vector2.RIGHT)


func _test_lightning_charges_liquids_only() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(40, 0)
	var water := _pool(spot, "water")
	game.boss_moves.electrify(spot, 24.0, 1)
	check(float(water.get("charge", 0.0)) > 0.0, "lightning into water charges it")
	var entry: Dictionary = game.boss_moves.snapshot().filter(func(e: Dictionary) -> bool: return int(e.id) == int(water.id))[0]
	check(float(entry.get("ch", 0.0)) > 0.0, "the snapshot carries the charge for the clients")
	hero = _arena()
	var ice := _pool(spot, "ice")
	var lava := _pool(spot + Vector2(0, 60), "lava")
	game.boss_moves.electrify(spot, 24.0, 1)
	game.boss_moves.electrify(spot + Vector2(0, 60), 24.0, 1)
	check(float(ice.get("charge", 0.0)) <= 0.0, "ice does not conduct")
	check(float(lava.get("charge", 0.0)) <= 0.0, "lava does not conduct")
	hero = _arena()
	var far := _pool(spot, "poison")
	game.boss_moves.electrify(spot + Vector2(400, 0), 24.0, 1)
	check(float(far.get("charge", 0.0)) <= 0.0, "lightning far away leaves a puddle alone")


func _test_charged_puddle_hurts_and_stuns_enemies_in_it() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(60, 0)
	_pool(spot, "water")
	var inside := _foe(spot)
	var outside := _foe(spot + Vector2(0, 150))
	hero.pos = spot + Vector2(-6, 4)
	var hero_hp := int(hero.hp)
	game.boss_moves.electrify(spot, 24.0, 1)
	_settle(0.6, [inside, outside])
	check(float(inside.hp) < 500.0, "an enemy in the charged puddle takes damage")
	check(float(inside.get("hitstun", 0.0)) > 0.0, "an enemy in the charged puddle is stunned")
	check(float(outside.hp) >= 500.0, "an enemy beside the puddle is spared")
	check(int(hero.hp) == hero_hp, "the hero's own lightning spares heroes in the puddle")


func _test_charge_runs_out() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(60, 0)
	var water := _pool(spot, "water")
	var inside := _foe(spot)
	game.boss_moves.electrify(spot, 24.0, 1)
	_settle(float(game.balance.element.charge_time) + 0.2, [inside])
	check(float(water.get("charge", 0.0)) <= 0.0, "the charge runs out")
	var hp := float(inside.hp)
	_settle(1.5, [inside])
	check(is_equal_approx(float(inside.hp), hp), "a puddle no longer charged does no damage")


func _test_storm_charges_a_puddle() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(60, 0)
	var water := _pool(spot, "blood")
	game.hero_skills._zone({"kind": "storm", "pos": spot, "radius": 50.0, "time": 2.0, "owner": 1, "dps": 0.0, "tick": 0.0})
	_settle(0.6)
	check(float(water.get("charge", 0.0)) > 0.0, "a storm zone over a puddle charges it")
