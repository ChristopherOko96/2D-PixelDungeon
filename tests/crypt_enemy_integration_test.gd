extends SceneTree
## Controlled host integration fixtures, not a played campaign or LAN benchmark.

const Game = preload("res://src/game.gd")
var checked: int = 0
var failures: Array[String] = []
var game: Node

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("CRYPT_INTEGRATION_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.session_bind_ip = "127.0.0.1"
	game.port_input.text = str(45000+OS.get_process_id()%10000)
	game.requested_seed = 42026
	game._host_session()
	check(game.hosting and game.active,"controlled host fixture starts on an owned local port")
	_test_campaign_spawns_varied_crypt_roles_and_only_final_boss()
	_test_summons_validate_space_owner_and_budgets()
	_test_snapshot_preserves_enemy_intent_and_projectile_style()
	_test_hitstun_and_freeze_stop_archer_release()
	_test_guard_is_directional_and_element_damage_still_works()
	_test_new_run_discards_summons()
	game._leave_session()
	game.queue_free()
	await process_frame
	print("CRYPT_INTEGRATION checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _reset() -> void:
	game.players.clear()
	game.commands.clear()
	game.bullets.clear()
	game.enemies.clear()
	game._add_player(1)
	game.players[1].pos = Vector2(96,384)
	game.players[1].invulnerable = 0.0
	game.phase = "combat"
	game.current_layout = {"id":"crypt-integration-fixture","tile_size":32,"world_size":[1024,768],"play_bounds":[32,32,960,704],"obstacles":[],"exits":[],"boss":false,"title":"Controlled crypt fixture","grid_x":0,"grid_y":0}
	game.floor_layouts.clear()
	game.floor_layouts.append(game.current_layout)
	game.room = 1
	game.floor_index = 1

func _enemy(identifier: int, kind: String, point: Vector2, hp: float = 100.0) -> Dictionary:
	return {"id":identifier,"kind":kind,"pos":point,"hp":hp,"max_hp":hp,"boss":false,"radius":13.0,"speed":0.0,"damage":1,"shot_timer":0.0,"nav_timer":10.0,"nav_path":PackedVector2Array(),"hitstun":0.0,"hit_flash":0.0,"knockback":Vector2.ZERO,"stun_cooldown":0.0,"hits":0,"attacks":0,"moving":false,"face":-1.0,"direction":Vector2.ZERO,"facing_dir":Vector2.RIGHT,"attack":"","attack_time":0.0,"attack_length":1.0,"attack_kind":"arrow" if kind == "skeleton_archer" else "soul" if kind == "necromancer" else "slash","attack_aim":Vector2.LEFT,"attack_target":1,"summon_point":Vector2(448,512),"summons_cast":0,"dying":0.0,"blocks":0}

func _test_campaign_spawns_varied_crypt_roles_and_only_final_boss() -> void:
	# Arrange a normal generated ten-room host campaign, without completing rooms.
	game._begin_run()
	var late_kinds: Dictionary = {}
	for index: int in range(1,11):
		game.room = index
		game._spawn_room()
		var kinds: Dictionary = {}
		var bosses: int = 0
		var necromancers: int = 0
		for enemy: Dictionary in game.enemies:
			if bool(enemy.boss): bosses += 1
			else:
				kinds[str(enemy.kind)] = true
				if str(enemy.kind) == "necromancer": necromancers += 1
				check(str(enemy.kind) in ["skeleton_guard","skeleton_archer","necromancer"],"ordinary spawns use the three crypt roles in room%d" % index)
		check(bosses == (1 if index == 10 else 0),"the only boss appears in room10, checked room%d" % index)
		var necro_limit: int = int(game.balance.get("enemy_roster",{}).get("encounter",{}).get("necromancer_max_per_room",1))
		check(necromancers <= necro_limit,"actual room%d respects its configured necromancer cap" % index)
		if index == 1:
			check(kinds.has("skeleton_guard") and kinds.has("skeleton_archer") and not kinds.has("necromancer"),"first encounter introduces the guard and archer before necromancy")
		if index >= 3:
			for kind: String in kinds: late_kinds[kind] = true
		if index == 10:
			check(game.enemies.size() == 3 and kinds.size() == 2,"boss encounter retains one boss and two distinct ordinary companions")
	check(late_kinds.has("necromancer"),"later ordinary encounters actually include necromancers")

func _summoning_available() -> bool:
	var available: bool = game.has_method("spawn_crypt_minion")
	check(available,"Game exposes a validated host-only crypt minion spawn boundary")
	return available

func _test_summons_validate_space_owner_and_budgets() -> void:
	_reset()
	if not _summoning_available(): return
	var caster: Dictionary = _enemy(501,"necromancer",Vector2(704,192))
	game.enemies = [caster]
	# Act/assert invalid requests never consume the caster's finite allowance.
	game.hosting = false
	check(not game.spawn_crypt_minion(501,Vector2(512,512)),"a non-host cannot authorize a minion spawn")
	game.hosting = true
	game.phase = "explore"
	check(not game.spawn_crypt_minion(501,Vector2(512,512)),"cleared exploration cannot create new enemies")
	game.phase = "combat"
	check(not game.spawn_crypt_minion(999,Vector2(512,512)),"a nonexistent caster cannot summon")
	check(not game.spawn_crypt_minion(501,Vector2(NAN,0)),"a nonfinite summon point is rejected")
	check(not game.spawn_crypt_minion(501,Vector2(8,384)),"a summon cannot appear outside the walkable floor bounds")
	check(not game.spawn_crypt_minion(501,Vector2(120,384)),"summons cannot appear inside the party safety radius")
	game.current_layout.obstacles = [[448,448,96,96]]
	check(not game.spawn_crypt_minion(501,Vector2(480,480)),"a summon cannot spawn through collision walls")
	check(int(caster.summons_cast) == 0,"rejected spawns do not consume summon charges")
	game.current_layout.obstacles = []
	# Clear valid points are far from players and existing actors.
	check(game.spawn_crypt_minion(501,Vector2(512,512)),"a clear distant summon point creates a real minion")
	if game.enemies.size() > 1:
		var minion: Dictionary = game.enemies.back()
		check(str(minion.kind) == "skeleton_guard" and not bool(minion.boss),"necromancy creates the ordinary shield skeleton, never a boss")
		check(int(minion.get("caster_id",0)) == 501 and bool(minion.get("summoned",false)),"summoned ownership and presentation marker identify its actual caster")
	check(game.spawn_crypt_minion(501,Vector2(704,512)),"one caster may use its second bounded summon")
	check(not game.spawn_crypt_minion(501,Vector2(832,512)),"one caster cannot exceed its summon allowance")
	for enemy: Dictionary in game.enemies:
		if int(enemy.get("caster_id",0)) == 501: enemy.hp = 0.0
	check(not game.spawn_crypt_minion(501,Vector2(832,512)),"killing the first summons does not create an endless resummon factory")
	check(int(caster.summons_cast) == 2,"exactly the successful spawn calls consume the two charges")
	# A separate full encounter cannot bypass the global living-actor cap.
	_reset()
	caster = _enemy(502,"necromancer",Vector2(704,192))
	game.enemies = [caster]
	var maximum: int = int(game.balance.get("enemy_roster",{}).get("limits",{}).get("max_enemies",12))
	for index: int in range(maximum-1): game.enemies.append(_enemy(600+index,"skeleton_guard",Vector2(512+index*20,96)))
	check(not game.spawn_crypt_minion(502,Vector2(512,512)),"global living-actor cap rejects further minions even for a fresh caster")

func _test_snapshot_preserves_enemy_intent_and_projectile_style() -> void:
	_reset()
	var archer: Dictionary = _enemy(701,"skeleton_archer",Vector2(512,384))
	archer.attack = "windup"
	archer.attack_time = 0.4
	archer.attack_length = 0.6
	archer.attack_aim = Vector2.LEFT
	archer.summon_point = Vector2(448,512)
	game.enemies = [archer]
	game._add_bullet(Vector2(480,384),Vector2.LEFT*180,0,1,{"style":"arrow"})
	var snapshot: Dictionary = game._make_snapshot()
	var visible: Dictionary = snapshot.enemies[0]
	for field: String in ["enemy_name","attack_kind","attack_length","aim_x","aim_y","tx","ty","blocks","cast_count","caster_id"]:
		check(visible.has(field),"enemy snapshot preserves presentation field "+field)
	check(str(visible.get("kind","")) == "skeleton_archer" and str(visible.get("attack","")) == "windup","snapshot identifies the actual ranged actor and its telegraph state")
	check(str(snapshot.bullets[0].get("style","")) == "arrow","projectile snapshot preserves the arrow presentation style")

func _ai_available() -> bool:
	var available: bool = game.get("crypt_ai") != null
	check(available,"Game binds the crypt-specific combat controller")
	return available

func _test_hitstun_and_freeze_stop_archer_release() -> void:
	_reset()
	if not _ai_available(): return
	var archer: Dictionary = _enemy(801,"skeleton_archer",Vector2(512,384))
	archer.attack = "windup"
	archer.attack_time = 0.001
	archer.hitstun = 0.3
	game.enemies = [archer]
	game._simulate_enemies(0.01)
	check(game.bullets.is_empty() and float(archer.attack_time) > 0,"hitstun prevents a prepared arrow from firing")
	archer.hitstun = 0.0
	archer.statuses = {"freeze":{"power":1.0,"time":1.0,"owner":1,"tick":0.0}}
	game._simulate_enemies(0.01)
	check(game.bullets.is_empty() and float(archer.attack_time) > 0,"perk freeze also pauses the ranged release")

func _test_guard_is_directional_and_element_damage_still_works() -> void:
	_reset()
	if not _ai_available(): return
	var front: Dictionary = _enemy(901,"skeleton_guard",Vector2(512,384))
	var back: Dictionary = _enemy(902,"skeleton_guard",Vector2(704,384))
	game.enemies = [front,back]
	# A left-moving hit approaches a right-facing shield from its front.
	game._damage_enemy(front,10,Vector2.LEFT,1)
	game._damage_enemy(back,10,Vector2.RIGHT,1)
	check(100.0-float(front.hp) < 100.0-float(back.hp),"front shield protection reduces actual damage while rear hits remain effective")
	check(int(front.get("blocks",0)) == 1 and int(back.get("blocks",0)) == 0,"only the frontal block increments visible shield feedback")
	front.hitstun = 0.0
	front.attack = ""
	var before: float = float(front.hp)
	game._damage_enemy(front,2,Vector2.ZERO,1,true,false)
	check(is_equal_approx(before-float(front.hp),2.0),"periodic elemental damage bypasses directional shielding")
	var cinder: Dictionary = {}
	for definition: Dictionary in game.balance.perks:
		if str(definition.id) == "cinder": cinder = definition
	game._grant_perk(1,cinder)
	game.perk_combat.hit({"owner":1,"damage":2.0,"velocity":Vector2.LEFT*600,"distance":0.0,"primary":true},front)
	check(front.get("statuses",{}).has("burn"),"a shield skeleton still receives actual elemental perk statuses")
	before = float(front.hp)
	game._simulate_enemies(0.6)
	check(float(front.hp) < before,"burn on a shield skeleton performs actual subsequent damage")

func _test_new_run_discards_summons() -> void:
	# Arrange a finite summoned encounter, then use the ordinary fresh-run path.
	game._begin_run()
	var no_minions: bool = true
	for enemy: Dictionary in game.enemies:
		if bool(enemy.get("summoned",false)) or int(enemy.get("caster_id",0)) != 0: no_minions = false
	check(no_minions and game.room == 1 and game.floor_index == 1,"fresh runs discard all summoned actors and restart the first encounter")
