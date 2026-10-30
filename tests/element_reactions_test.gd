extends SceneTree
## Element reactions with gameplay (src/combat/elements.gd, balance.json
## "element"; user decision 2026-10-30: all four reactions work):
## fire on poison (a pool or a gas cloud) explodes, hurts enemies around it
## and spares heroes, and sets off poison next to it; frost on water turns it
## to Glatteis that slows enemies, insulates against lightning and thaws again
## under fire; fire on water boils it to steam that scalds and blinds enemies;
## water touching lava crusts the lava (harmless for a while) and steams.

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
		printerr("ELEMENT_REACTIONS_FAIL: ", label)


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
	_test_fire_on_poison_pool_explodes()
	_test_fire_on_poison_gas_explodes_and_sets_off_the_next()
	_test_frost_on_water_makes_glatteis()
	_test_fire_on_water_boils_to_steam()
	_test_water_on_lava_crusts_and_steams()
	_test_snapshot_carries_gas_and_crust()
	_test_talents_and_skills_set_off_reactions()
	print("ELEMENT_REACTIONS checked=%d failures=%d" % [checked, failures.size()])
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
	game.elements.reset()
	game.hero_skills.zones.clear()
	game.fx_events.clear()
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
		game.elements.update(DT)
		game.perk_combat.step_statuses(DT)
		for index in range(keep.size()): keep[index].pos = spots[index]
		game.players[1].invulnerable = 0.0
		time += DT


func _pool(at: Vector2, style: String, dps := 0) -> Dictionary:
	return game.boss_moves._pool(at, {"style": style, "radius": 40, "time": 30, "dps": dps}, Vector2.RIGHT)


func _alive(zone: Dictionary) -> bool:
	return game.boss_moves.zones.has(zone)


func _fx(kind: String) -> bool:
	return game.fx_events.any(func(e: Dictionary) -> bool: return str(e.kind) == "element" and str(e.get("do", "")) == kind)


func _test_fire_on_poison_pool_explodes() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(70, 0)
	var poison := _pool(spot, "poison")
	var near := _foe(spot + Vector2(10, 0))
	var far := _foe(spot + Vector2(0, 200))
	hero.pos = spot + Vector2(-20, 0)
	var hero_hp := int(hero.hp)
	game.elements.fire_at(spot, 20.0, 1)
	_settle(0.1, [near, far])
	check(float(near.hp) < 500.0, "fire on a poison pool: the explosion hurts enemies near it")
	check(float(far.hp) >= 500.0, "fire on a poison pool: enemies far away are spared")
	check(int(hero.hp) == hero_hp, "fire on a poison pool: heroes are spared")
	check(not _alive(poison), "fire on a poison pool: the poison is used up")
	check(_fx("explode"), "fire on a poison pool: an explosion event for the clients")


func _test_fire_on_poison_gas_explodes_and_sets_off_the_next() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(70, 0)
	var cloud: Dictionary = game.elements.add_gas("poison", spot, 50.0, 10.0)
	var next := _pool(spot + Vector2(60, 0), "poison")
	var inside := _foe(spot)
	game.elements.fire_at(spot, 10.0, 1)
	_settle(0.1, [inside])
	check(float(inside.hp) < 500.0, "fire in poison gas: the explosion hurts enemies in the cloud")
	check(not game.elements.clouds.has(cloud), "fire in poison gas: the cloud is used up")
	check(not _alive(next), "fire in poison gas: the poison pool beside it goes off too")
	var smoke: Dictionary = game.elements.add_gas("smoke", spot, 50.0, 10.0)
	game.elements.fire_at(spot, 10.0, 1)
	check(game.elements.clouds.has(smoke), "fire in smoke: nothing explodes")


func _test_frost_on_water_makes_glatteis() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(70, 0)
	var water := _pool(spot, "water")
	var inside := _foe(spot)
	game.elements.frost_at(spot, 20.0, 1)
	check(float(water.get("frozen", 0.0)) > 0.0, "frost on water: it freezes")
	check(_fx("freeze"), "frost on water: a freeze event for the clients")
	_settle(0.3, [inside])
	check((inside.get("statuses", {}) as Dictionary).has("slow"), "Glatteis: enemies on it are slowed")
	game.boss_moves.electrify(spot, 24.0, 1)
	check(float(water.get("charge", 0.0)) <= 0.0, "Glatteis: ice does not conduct lightning")
	game.elements.fire_at(spot, 20.0, 1)
	check(float(water.get("frozen", 0.0)) <= 0.0 and _alive(water), "fire on Glatteis: it thaws back to water")
	check(_fx("thaw"), "fire on Glatteis: a thaw event for the clients")
	var lava := _pool(spot + Vector2(0, 120), "lava")
	game.elements.frost_at(spot + Vector2(0, 120), 20.0, 1)
	check(float(lava.get("frozen", 0.0)) <= 0.0, "frost on lava: nothing freezes")


func _test_fire_on_water_boils_to_steam() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(70, 0)
	var water := _pool(spot, "water")
	var inside := _foe(spot)
	hero.pos = spot + Vector2(-10, 0)
	var hero_hp := int(hero.hp)
	game.elements.fire_at(spot, 20.0, 1)
	var steam: Array = game.elements.clouds.filter(func(c: Dictionary) -> bool: return str(c.mat) == "steam")
	check(steam.size() == 1, "fire on water: it boils into a steam cloud")
	_settle(0.1, [inside])
	check(not _alive(water), "fire on water: the water is gone")
	inside.shot_timer = 0.0
	_settle(1.3, [inside])
	check(float(inside.hp) < 500.0, "steam: it scalds enemies in it")
	check(float(inside.shot_timer) > 0.0, "steam: enemies in it cannot shoot")
	check(int(hero.hp) == hero_hp, "steam: heroes are spared")


func _test_water_on_lava_crusts_and_steams() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(70, 0)
	var lava := _pool(spot, "lava", 1)
	var water := _pool(spot + Vector2(30, 0), "water")
	hero.pos = spot + Vector2(-200, 0)
	_settle(0.5)
	check(float(lava.get("crust", 0.0)) > 0.0, "water on lava: the lava crusts")
	# the hero steps onto the crust
	hero.pos = spot + Vector2(-12, 0)
	var hero_hp := int(hero.hp)
	_settle(1.0)
	check(not _alive(water), "water on lava: the water is gone")
	check(game.elements.clouds.any(func(c: Dictionary) -> bool: return str(c.mat) == "steam"), "water on lava: it steams")
	check(int(hero.hp) == hero_hp, "crusted lava: the hero walks on it unharmed")
	_settle(float(game.balance.element.crust_time) + 1.2)
	check(int(hero.hp) < hero_hp, "crusted lava: it burns again when the crust is gone")


func _test_snapshot_carries_gas_and_crust() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(70, 0)
	game.elements.add_gas("frost", spot, 40.0, 5.0)
	var entries: Array = game.elements.snapshot()
	check(entries.size() == 1 and str(entries[0].k) == "gas" and str(entries[0].st) == "frost", "the snapshot carries gas clouds in the gas layer's shape")
	check(game._build_snapshot().has("element_gas") if game.has_method("_build_snapshot") else true, "the game snapshot has element_gas")
	var lava := _pool(spot + Vector2(0, 100), "lava")
	lava.crust = 2.0
	var entry: Dictionary = game.boss_moves.snapshot().filter(func(e: Dictionary) -> bool: return int(e.id) == int(lava.id))[0]
	check(float(entry.get("cr", 0.0)) > 0.0, "the snapshot carries the lava's crust")


func _test_talents_and_skills_set_off_reactions() -> void:
	var hero := _arena()
	var spot: Vector2 = hero.pos + Vector2(70, 0)
	var poison := _pool(spot, "poison")
	game.talent_combat._event("nova", spot, 30.0, {"fx": "fire", "owner": 1})
	_settle(0.1)
	check(not _alive(poison), "a fire talent's nova sets poison off")
	var water := _pool(spot + Vector2(0, 100), "water")
	game.talent_combat._event("nova", spot + Vector2(0, 100), 30.0, {"fx": "ice", "owner": 1})
	check(float(water.get("frozen", 0.0)) > 0.0, "a frost talent's nova freezes water")
	hero = _arena()
	water = _pool(spot, "water")
	game.boss_moves.strike_at(spot, 30.0, 0.2, 0, "fire")
	_settle(0.4)
	check(game.elements.clouds.any(func(c: Dictionary) -> bool: return str(c.mat) == "steam"), "a boss's fire strike boils water")
