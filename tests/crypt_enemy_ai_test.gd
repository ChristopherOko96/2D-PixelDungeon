extends SceneTree
## Controlled host fixture for three distinct telegraphed crypt enemy behaviours.

class HostFixture extends Node:
	var balance: Dictionary = {}
	var current_layout: Dictionary = {"id":"crypt-ai-fixture","world_size":[768,512],"play_bounds":[32,32,704,448],"obstacles":[],"exits":[],"tile_size":32}
	var players: Dictionary = {1:{"pos":Vector2(420,256),"hp":8}}
	var enemies: Array = []
	var bullets: Array = []
	var damage_calls: int = 0
	var summon_calls: int = 0
	var allow_summon: bool = true
	func _add_bullet(point: Vector2, velocity: Vector2, owner: int, damage: float, metadata: Dictionary = {}) -> Dictionary:
		var result: Dictionary = {"pos":point,"velocity":velocity,"owner":owner,"damage":damage}
		result.merge(metadata,true)
		bullets.append(result)
		return result
	func _damage_player(id: int, damage: int, _direction: Vector2 = Vector2.ZERO) -> void:
		players[id].hp = maxi(0,int(players[id].hp)-damage)
		damage_calls += 1
	func spawn_crypt_minion(caster_id: int, point: Vector2) -> bool:
		summon_calls += 1
		if not allow_summon: return false
		for enemy: Dictionary in enemies:
			if int(enemy.id) == caster_id: enemy.summons_cast = int(enemy.get("summons_cast",0))+1
		enemies.append({"id":9000+summon_calls,"pos":point,"hp":8,"kind":"skeleton_guard","caster_id":caster_id,"summoned":true})
		return true

var checked: int = 0
var failures: int = 0
var host: HostFixture
var ai: RefCounted

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures += 1
		printerr("CRYPT_AI_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not FileAccess.file_exists("res://src/crypt_enemy_ai.gd"):
		check(false,"crypt enemy AI module exists")
		_finish()
		return
	host = HostFixture.new()
	root.add_child(host)
	host.balance = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	ai = load("res://src/crypt_enemy_ai.gd").new()
	ai.bind(host)
	_test_catalog_and_seeded_mixing()
	_test_archer_lock_release_and_recovery()
	_test_archer_sight_and_retreat()
	_test_blocked_muzzle_cannot_count_an_attack()
	_test_necromancer_summon_limits()
	_test_blocked_summon_sites_choose_soul_before_telegraph()
	_test_rejected_summon_placement_stops_retrying()
	_test_guard_telegraph_dodge_and_damage()
	_test_shield_front_rear_and_vulnerability()
	host.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	print("CRYPT_AI checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)

func _reset() -> void:
	host.players = {1:{"pos":Vector2(420,256),"hp":8}}
	host.current_layout = {"id":"crypt-ai-fixture","world_size":[768,512],"play_bounds":[32,32,704,448],"obstacles":[],"exits":[],"tile_size":32}
	host.enemies.clear()
	host.bullets.clear()
	host.damage_calls = 0
	host.summon_calls = 0
	host.allow_summon = true

func _enemy(kind: String, point: Vector2 = Vector2(200,256)) -> Dictionary:
	var definition: Dictionary = ai.definition(kind)
	return {"id":100,"kind":kind,"pos":point,"hp":float(definition.get("hp",8)),"max_hp":float(definition.get("hp",8)),"radius":float(definition.get("radius",12)),"speed":float(definition.get("speed",55)),"boss":false,"attack":"","attack_time":0.0,"shot_timer":0.0,"hitstun":0.0,"statuses":{},"nav_timer":0.0,"nav_path":PackedVector2Array(),"moving":false,"face":1.0,"facing_dir":Vector2.RIGHT,"attacks":0,"summons_cast":0}

func _attack(kind: String) -> Dictionary:
	return host.balance.enemy_roster.attacks[kind]

func _test_catalog_and_seeded_mixing() -> void:
	for kind: String in ["skeleton_archer","necromancer","skeleton_guard"]:
		var definition: Dictionary = ai.definition(kind)
		check(not definition.is_empty() and float(definition.get("hp",0)) > 0,"definition has real health: "+kind)
		check(float(definition.get("radius",0)) > 0 and float(definition.get("speed",0)) > 0,"definition has movement footprint: "+kind)
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 1026
	second_rng.seed = 1026
	for room: int in range(1,11):
		var mixed: Dictionary = {}
		for index: int in range(6):
			var kind: String = ai.choose_kind(room,index,6,room == 10,first_rng)
			check(kind == ai.choose_kind(room,index,6,room == 10,second_rng),"kind choice repeats with the same seed")
			mixed[kind] = true
			if room == 1: check(kind != "necromancer","entrance does not introduce necromancers")
			if room < 10: check(kind != "boss","normal room cannot select a boss")
		check(mixed.size() >= 2,"normal encounter mixes distinct enemy silhouettes")
	check(ai.choose_kind(10,0,3,true,first_rng) == "boss","boss retains the first boss-room slot")
	check(ai.choose_kind(10,1,3,true,first_rng) != ai.choose_kind(10,2,3,true,first_rng),"two boss companions use distinct roles")

func _test_archer_lock_release_and_recovery() -> void:
	_reset()
	var enemy: Dictionary = _enemy("skeleton_archer")
	host.enemies = [enemy]
	check(ai.step(enemy,1,0.01),"archer is handled by the distinct AI")
	check(enemy.attack == "windup" and host.bullets.is_empty(),"archer visibly prepares before a shot")
	var locked: Vector2 = enemy.attack_aim
	host.players[1].pos = Vector2(420,370)
	ai.step(enemy,1,float(_attack("arrow").windup)+0.01)
	check(host.bullets.size() == 1,"one completed archer windup releases one arrow")
	check(not host.bullets.is_empty() and Vector2(host.bullets[0].velocity).normalized().dot(locked) > 0.999,"arrow follows the locked aim rather than tracking the dodge")
	check(not host.bullets.is_empty() and host.bullets[0].get("style","") == "arrow","physical arrow carries its render style")
	check(int(enemy.attacks) == 1,"counter advances exactly once on successful projectile release")
	ai.step(enemy,1,0.01)
	check(host.bullets.size() == 1,"active/recovery cannot release duplicate arrows")

func _test_archer_sight_and_retreat() -> void:
	_reset()
	var enemy: Dictionary = _enemy("skeleton_archer")
	host.current_layout.obstacles = [[300,32,32,448]]
	host.enemies = [enemy]
	ai.step(enemy,1,0.1)
	check(enemy.attack == "" and host.bullets.is_empty(),"a wall blocks acquiring an arrow attack")
	_reset()
	enemy = _enemy("skeleton_archer",Vector2(360,256))
	host.enemies = [enemy]
	var before: float = Vector2(enemy.pos).distance_to(host.players[1].pos)
	enemy.shot_timer = 2.0
	ai.step(enemy,1,0.1)
	check(Vector2(enemy.pos).distance_to(host.players[1].pos) > before,"nearby archer retreats instead of melee chasing")
	enemy.nav_timer = 0.2
	ai.step(enemy,1,0.05)
	check(float(enemy.nav_timer) > 0 and float(enemy.nav_timer) < 0.2,"cached paths retain their refresh timer between steps")

func _test_necromancer_summon_limits() -> void:
	_reset()
	var enemy: Dictionary = _enemy("necromancer")
	enemy.attacks = int(host.balance.enemy_roster.encounter.summon_every_attacks)-1
	host.enemies = [enemy]
	ai.step(enemy,1,0.01)
	check(enemy.attack_kind == "summon" and enemy.attack == "windup","necromancer announces its bounded summon cast")
	check(enemy.has("summon_point"),"summon has a telegraphed world point")
	ai.step(enemy,1,float(_attack("summon").windup)+0.01)
	check(host.summon_calls == 1 and int(enemy.summons_cast) == 1,"successful summon calls host once without double-counting its lifetime use")
	_reset()
	enemy = _enemy("necromancer")
	enemy.attacks = int(host.balance.enemy_roster.encounter.summon_every_attacks)-1
	enemy.summons_cast = int(host.balance.enemy_roster.limits.max_summons_per_caster)
	host.enemies = [enemy]
	ai.step(enemy,1,0.01)
	check(enemy.attack_kind == "soul","spent summon allowance falls back to a soul projectile")
	_reset()
	enemy = _enemy("necromancer")
	enemy.attacks = int(host.balance.enemy_roster.encounter.summon_every_attacks)-1
	host.enemies = [enemy,{"id":101,"kind":"skeleton_guard","hp":8,"caster_id":100},{"id":102,"kind":"skeleton_guard","hp":8,"caster_id":100}]
	ai.step(enemy,1,0.01)
	check(enemy.attack_kind == "soul","two live summoned guards prevent another summon windup")

func _test_rejected_summon_placement_stops_retrying() -> void:
	_reset()
	host.allow_summon = false
	var enemy: Dictionary = _enemy("necromancer")
	enemy.attacks = int(host.balance.enemy_roster.encounter.summon_every_attacks)-1
	host.enemies = [enemy]
	var cap: int = int(host.balance.enemy_roster.limits.max_summon_failures)
	for attempt: int in range(cap):
		enemy.attack = ""
		enemy.shot_timer = 0.0
		ai.step(enemy,1,0.01)
		ai.step(enemy,1,float(_attack("summon").windup)+0.01)
	check(host.summon_calls == cap and int(enemy.summons_cast) == 0,"failed placement cannot consume a successful lifetime summon charge")
	check(int(enemy.get("summon_failures",0)) == cap,"placement failures are bounded independently from successful casts")
	enemy.attack = ""
	enemy.shot_timer = 0.0
	ai.step(enemy,1,0.01)
	check(enemy.attack_kind == "soul","repeated invalid summon positions switch to a normal soul attack")

func _test_blocked_summon_sites_choose_soul_before_telegraph() -> void:
	_reset()
	var enemy: Dictionary = _enemy("necromancer")
	enemy.attacks = int(host.balance.enemy_roster.encounter.summon_every_attacks)-1
	enemy.summon_point = Vector2(200,184)
	host.enemies = [enemy]
	host.current_layout.obstacles = [[176,160,48,48],[176,304,48,48]]
	ai.step(enemy,1,0.01)
	check(enemy.attack_kind == "soul" and not enemy.has("summon_point"),"two blocked summon sites choose a soul windup and remove stale summon telegraphs")

func _test_blocked_muzzle_cannot_count_an_attack() -> void:
	_reset()
	var enemy: Dictionary = _enemy("skeleton_archer")
	host.enemies = [enemy]
	ai.step(enemy,1,0.01)
	# A wall is inserted only after acquisition, reproducing an invalid release.
	host.current_layout.obstacles = [[209,230,16,52]]
	ai.step(enemy,1,float(_attack("arrow").windup)+0.01)
	check(host.bullets.is_empty(),"a blocked muzzle cannot emit an arrow through a wall")
	check(int(enemy.attacks) == 0,"a blocked release does not fake a shot event or sound counter")

func _test_guard_telegraph_dodge_and_damage() -> void:
	_reset()
	var enemy: Dictionary = _enemy("skeleton_guard",Vector2(380,256))
	host.enemies = [enemy]
	ai.step(enemy,1,0.01)
	check(enemy.attack == "windup" and host.damage_calls == 0,"guard melee has a damage-free readable windup")
	host.players[1].pos = Vector2(580,256)
	ai.step(enemy,1,float(_attack("slash").windup)+0.01)
	check(host.damage_calls == 0,"leaving the sword reach during windup dodges the slash")
	_reset()
	enemy = _enemy("skeleton_guard",Vector2(380,256))
	host.enemies = [enemy]
	ai.step(enemy,1,0.01)
	ai.step(enemy,1,float(_attack("slash").windup)+0.01)
	check(host.damage_calls == 1 and int(host.players[1].hp) == 7,"a completed undodged slash applies one actual damage call")
	var position: Vector2 = enemy.pos
	ai.step(enemy,1,0.02)
	check(enemy.pos == position and host.damage_calls == 1,"attack recovery neither moves nor repeats melee damage")

func _test_shield_front_rear_and_vulnerability() -> void:
	_reset()
	var enemy: Dictionary = _enemy("skeleton_guard")
	check(ai.guard_multiplier(enemy,Vector2.LEFT) < 1.0,"shield protects against a frontal incoming projectile")
	check(is_equal_approx(ai.guard_multiplier(enemy,Vector2.RIGHT),1.0),"rear projectile bypasses the small shield")
	check(is_equal_approx(ai.guard_multiplier(enemy,Vector2.LEFT,false),1.0),"status/area damage bypasses shield feedback boundary")
	for state: String in ["windup","active","recovery"]:
		enemy.attack = state
		check(is_equal_approx(ai.guard_multiplier(enemy,Vector2.LEFT),1.0),"shield exposes the guard during "+state)
	enemy.attack = ""
	enemy.hitstun = 0.1
	check(is_equal_approx(ai.guard_multiplier(enemy,Vector2.LEFT),1.0),"stunned guard cannot block")
	enemy.hitstun = 0.0
	enemy.statuses = {"freeze":{"time":0.3}}
	check(is_equal_approx(ai.guard_multiplier(enemy,Vector2.LEFT),1.0),"frozen guard cannot block")
