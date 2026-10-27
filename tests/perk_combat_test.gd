extends SceneTree
## Controlled Game integration fixtures exercise actual combat methods, not a run.

const Game = preload("res://src/game.gd")
var checked: int = 0
var failures: Array[String] = []
var game: Node

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("PERK_COMBAT_FAIL: ", description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	_test_catalogue_contains_distinct_effects()
	_test_scatter_changes_actual_shot_pattern()
	_test_heavy_shot_increases_damage_and_costs_fire_rate()
	_test_extra_patterns_have_distinct_directions()
	_test_steering_changes_actual_projectile_motion()
	_test_piercing_hits_two_targets_once()
	_test_ricochet_preserves_bullet_and_reflects_motion()
	_test_elemental_hit_changes_future_enemy_health()
	_test_frost_and_shatter_increase_followup_damage()
	_test_poison_death_spreads_with_original_owner()
	_test_combustion_cannot_recursively_chain_deaths()
	_test_shield_absorbs_damage()
	_test_second_wind_prevents_one_lethal_hit()
	_test_room_resources_cannot_be_farmed_by_revisiting()
	_test_earned_soul_guard_survives_new_room()
	_test_kill_healing_is_owned_and_cannot_count_one_death_twice()
	_test_combined_patterns_respect_projectile_budget()
	_test_focus_momentum_and_low_health_change_actual_volleys()
	_test_execution_mark_longshot_and_first_strike_change_impact_damage()
	_test_storm_conductor_and_convergence_reward_prepared_targets()
	_test_permafrost_and_catalyst_change_status_duration()
	_test_echo_split_blast_and_overkill_have_distinct_secondaries()
	_test_armor_thorns_desperation_and_renewal_have_real_defensive_effects()
	_test_retaliation_killed_boss_cannot_finish_attack()
	_test_leech_crit_and_legacy_perks_change_real_combat()
	_test_player_factory_discards_old_build()
	game.queue_free()
	await process_frame
	print("PERK_COMBAT checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _reset() -> void:
	game.players.clear()
	game.commands.clear()
	game.bullets.clear()
	game.enemies.clear()
	game._add_player(1)
	game.players[1].pos = Vector2(160, 256)
	game.phase = "combat"
	game.current_layout = {"id":"perk-fixture", "tile_size":32, "world_size":[512,512], "play_bounds":[32,32,448,448], "obstacles":[], "exits":[], "boss":false, "title":"Fixture", "grid_x":0, "grid_y":0}
	game.floor_layouts.clear()
	game.floor_layouts.append(game.current_layout)
	game.room = 1
	game.floor_index = 1

func _grant(perk_id: String) -> bool:
	for definition: Dictionary in game.balance.perks:
		if str(definition.id) == perk_id:
			game._grant_perk(1, definition)
			return perk_id in game.players[1].perks
	check(false, "catalogue defines implemented perk " + perk_id)
	return false

func _enemy(identifier: int, position: Vector2, hp: float = 100.0) -> Dictionary:
	return {"id":identifier, "pos":position, "hp":hp, "max_hp":hp, "boss":false, "radius":13.0, "speed":0.0, "shot_timer":1.0, "nav_timer":10.0, "nav_path":PackedVector2Array(), "hitstun":0.0, "hit_flash":0.0, "knockback":Vector2.ZERO, "stun_cooldown":0.0, "kind":"chaser", "hits":0, "attacks":0, "moving":false, "face":-1.0, "direction":Vector2.ZERO, "attack":"", "attack_time":0.0, "dying":0.0}

func _shoot(aim: Vector2 = Vector2.RIGHT, owner: int = 1) -> void:
	game.commands[owner] = {"move":Vector2.ZERO, "aim":aim, "fire":true, "sequence":1, "time":Time.get_ticks_msec()/1000.0}
	game._simulate_players(0.01)
	game.commands.clear()

func _combat_available() -> bool:
	var available: bool = game.get("perk_combat") != null
	check(available,"host combat effect module is bound")
	return available

func _impact(target: Dictionary, damage: float = 2.0, distance: float = 0.0, primary: bool = true) -> float:
	if not game.enemies.has(target): game.enemies.append(target)
	var before: float = float(target.hp)
	game.perk_combat.hit({"owner":1,"damage":damage,"velocity":Vector2.RIGHT*600,"distance":distance,"primary":primary,"critical":false,"element":""},target)
	return before-float(target.hp)

func _test_catalogue_contains_distinct_effects() -> void:
	var identities: Dictionary = {}
	for definition: Dictionary in game.balance.perks:
		identities[str(definition.id)] = true
	check(game.balance.perks.size() == 48 and identities.size() == 48, "catalogue contains48 unique perk IDs")

func _test_scatter_changes_actual_shot_pattern() -> void:
	_reset()
	_grant("scatter")
	_shoot()
	check(game.bullets.size() >= 3, "scatter produces at least three real projectiles")
	var directions: Dictionary = {}
	for bullet: Dictionary in game.bullets:
		directions[roundf(bullet.velocity.angle()*1000.0)] = true
	check(directions.size() >= 3, "scatter projectiles travel in different directions")

func _test_heavy_shot_increases_damage_and_costs_fire_rate() -> void:
	_reset()
	_shoot()
	var base_damage: float = float(game.bullets[0].damage)
	var base_cooldown: float = float(game.players[1].shot_timer)
	_reset()
	_grant("heavy")
	_shoot()
	check(not game.bullets.is_empty() and float(game.bullets[0].damage) > base_damage,"heavy shot causes more damage than the baseline shot")
	check(float(game.players[1].shot_timer) > base_cooldown,"heavy shot pays its promised longer cooldown")

func _test_extra_patterns_have_distinct_directions() -> void:
	_reset()
	_grant("twin")
	_shoot()
	check(game.bullets.size() == 2 and game.bullets[0].pos != game.bullets[1].pos and game.bullets[0].velocity == game.bullets[1].velocity,"twin creates two offset parallel projectiles")
	_reset()
	_grant("backshot")
	_shoot()
	check(game.bullets.any(func(bullet: Dictionary) -> bool: return float(bullet.velocity.x) < 0),"backshot creates a genuine backwards shot")
	_reset()
	_grant("sidewinder")
	_shoot()
	check(game.bullets.any(func(bullet: Dictionary) -> bool: return float(bullet.velocity.y) > 1) and game.bullets.any(func(bullet: Dictionary) -> bool: return float(bullet.velocity.y) < -1),"sidewinder creates genuine left and right flank shots")

func _test_steering_changes_actual_projectile_motion() -> void:
	_reset()
	_grant("homing")
	game.enemies = [_enemy(7,Vector2(350,330))]
	_shoot()
	game._simulate_bullets(0.05)
	check(not game.bullets.is_empty() and float(game.bullets[0].velocity.y) > 0,"homing bends a real projectile toward an off-axis target")
	_reset()
	_grant("orbit")
	_shoot()
	game._simulate_bullets(0.05)
	check(not game.bullets.is_empty() and absf(float(game.bullets[0].velocity.y)) > 0.01,"orbit changes the projectile direction over time")

func _test_piercing_hits_two_targets_once() -> void:
	_reset()
	_grant("piercer")
	var first: Dictionary = _enemy(11, Vector2(208,256))
	var second: Dictionary = _enemy(12, Vector2(272,256))
	game.enemies = [first, second]
	_shoot()
	for frame: int in range(15):
		game._simulate_bullets(0.01)
	check(float(first.hp) < 100.0 and float(second.hp) < 100.0, "one piercing shot damages two aligned enemies")
	check(int(first.hits) == 1 and int(second.hits) == 1, "piercing cannot damage the same enemy every overlapping frame")

func _test_ricochet_preserves_bullet_and_reflects_motion() -> void:
	_reset()
	_grant("ricochet")
	game.players[1].pos = Vector2(440,256)
	_shoot()
	for frame: int in range(8):
		game._simulate_bullets(0.01)
	check(not game.bullets.is_empty(), "ricochet survives its first wall collision")
	check(not game.bullets.is_empty() and game.bullets[0].velocity.x < 0.0, "ricochet reverses the wall-normal velocity")

func _test_elemental_hit_changes_future_enemy_health() -> void:
	_reset()
	_grant("cinder")
	var target: Dictionary = _enemy(21, Vector2(208,256))
	game.enemies = [target]
	_shoot()
	for frame: int in range(8):
		game._simulate_bullets(0.01)
	var after_impact: float = float(target.hp)
	for frame: int in range(20):
		game._simulate_enemies(0.1)
	check(after_impact < 100.0, "elemental shot still causes an immediate actual hit")
	check(float(target.hp) < after_impact, "cinder causes additional burn damage after the projectile is gone")

func _test_shield_absorbs_damage() -> void:
	_reset()
	_grant("shield")
	var before: int = int(game.players[1].hp)
	game.players[1].invulnerable = 0.0
	game._damage_player(1, 1)
	check(int(game.players[1].hp) == before, "a fresh shield prevents one actual incoming hit")
	game.players[1].invulnerable = 0.0
	game._damage_player(1, 1)
	check(int(game.players[1].hp) < before, "shield cannot absorb unlimited hits")

func _test_frost_and_shatter_increase_followup_damage() -> void:
	_reset()
	_grant("frost")
	_grant("shatter")
	var target: Dictionary = _enemy(31,Vector2(208,256))
	game.enemies = [target]
	_shoot()
	for frame: int in range(8): game._simulate_bullets(0.01)
	var first_damage: float = 100.0-float(target.hp)
	check(target.get("statuses",{}).has("slow"),"frost attaches a real slowing status to the target")
	target.pos = Vector2(208,256)
	target.knockback = Vector2.ZERO
	game.players[1].shot_timer = 0.0
	_shoot()
	for frame: int in range(8): game._simulate_bullets(0.01)
	var second_damage: float = 100.0-first_damage-float(target.hp)
	check(second_damage > first_damage,"shatter increases follow-up damage against a previously frost-slowed target")

func _test_poison_death_spreads_with_original_owner() -> void:
	_reset()
	_grant("venom")
	_grant("plague")
	var source: Dictionary = _enemy(41,Vector2(208,256),1)
	var neighbor: Dictionary = _enemy(42,Vector2(248,256),100)
	game.enemies = [source,neighbor]
	_shoot()
	for frame: int in range(8): game._simulate_bullets(0.01)
	check(float(source.hp) == 0.0 and neighbor.get("statuses",{}).has("poison"),"plague transfers poison from a killed target to a nearby enemy")
	check(int(neighbor.get("statuses",{}).get("poison",{}).get("owner",-1)) == 1,"spread poison retains the actual attacking player's ownership")
	var before: float = float(neighbor.hp)
	for frame: int in range(10): game._simulate_enemies(0.1)
	check(float(neighbor.hp) < before,"spread poison performs actual subsequent host damage")

func _test_combustion_cannot_recursively_chain_deaths() -> void:
	_reset()
	_grant("cinder")
	_grant("combustion")
	var radius: float = float(game.balance.get("perk_rules",{}).get("mechanics",{}).get("blast_radius",70.0))
	var source: Dictionary = _enemy(51,Vector2(208,256),1)
	var second: Dictionary = _enemy(52,Vector2(208+radius*0.6,256),1)
	var outside: Dictionary = _enemy(53,Vector2(208+radius+10,256),100)
	game.enemies = [source,second,outside]
	_shoot()
	for frame: int in range(8): game._simulate_bullets(0.01)
	check(float(source.hp) == 0.0 and float(second.hp) == 0.0,"combustion causes a real secondary area kill")
	check(float(outside.hp) == 100.0,"secondary area deaths do not recursively explode beyond the original blast")

func _test_second_wind_prevents_one_lethal_hit() -> void:
	_reset()
	_grant("second_wind")
	game.players[1].invulnerable = 0.0
	game._damage_player(1, 999)
	check(int(game.players[1].hp) > 0, "second wind restores life after one lethal hit")
	game.players[1].invulnerable = 0.0
	game._damage_player(1, 999)
	check(int(game.players[1].hp) == 0, "second wind is consumed rather than granting permanent immortality")

func _test_room_resources_cannot_be_farmed_by_revisiting() -> void:
	_reset()
	if not _combat_available(): return
	_grant("shield")
	game._damage_player(1,1)
	game.players[1].invulnerable = 0.0
	game.perk_combat.enter_room(true)
	var before: int = int(game.players[1].hp)
	game._damage_player(1,1)
	check(int(game.players[1].hp) == before-1,"returning to a cleared room cannot replenish an exhausted shield")
	game.players[1].invulnerable = 0.0
	game.perk_combat.enter_room(false)
	before = int(game.players[1].hp)
	game._damage_player(1,1)
	check(int(game.players[1].hp) == before,"a genuinely new encounter replenishes a room shield")

func _test_kill_healing_is_owned_and_cannot_count_one_death_twice() -> void:
	_reset()
	if not _combat_available(): return
	_grant("vampire")
	game._add_player(200)
	game.players[1].hp = 2
	game.players[200].hp = 2
	var cadence: int = maxi(1,int(game.players[1].build.vampire))
	for index: int in range(cadence):
		var target: Dictionary = _enemy(100+index,Vector2(208,256),1)
		game.enemies = [target]
		game._damage_enemy(target,1,Vector2.RIGHT,1,true)
		game._damage_enemy(target,1,Vector2.RIGHT,1,true)
	check(int(game.players[1].hp) == 3,"vampire heals only once after its real kill cadence")
	check(int(game.players[200].hp) == 2,"one owner's kill healing never changes another player's health")

func _test_earned_soul_guard_survives_new_room() -> void:
	_reset()
	if not _combat_available(): return
	_grant("soul_guard")
	var cadence: int = maxi(1,int(game.players[1].build.soul_guard))
	for index: int in range(cadence):
		var target: Dictionary = _enemy(200+index,Vector2(208,256),1)
		game.enemies = [target]
		game._damage_enemy(target,1,Vector2.RIGHT,1,true)
	# A soul shield is earned by kills, unlike the separately renewed room shield.
	game.perk_combat.enter_room(false)
	var before: int = int(game.players[1].hp)
	game.players[1].invulnerable = 0.0
	game._damage_player(1,1)
	check(int(game.players[1].hp) == before,"earned soul-guard charge survives transition into the next new encounter")

func _test_combined_patterns_respect_projectile_budget() -> void:
	_reset()
	for perk_id: String in ["scatter","twin","backshot","sidewinder","echo","split"]:
		_grant(perk_id)
	for identifier: int in [200,201,202]:
		game._add_player(identifier)
		game.players[identifier].pos = Vector2(160,256)
		for perk_id: String in ["scatter","twin","backshot","sidewinder","echo","split"]:
			for definition: Dictionary in game.balance.perks:
				if str(definition.id) == perk_id: game._grant_perk(identifier,definition)
	for volley: int in range(100):
		for identifier: int in [1,200,201,202]:
			game.players[identifier].shot_timer = 0.0
			_shoot(Vector2.RIGHT,identifier)
	var limits: Dictionary = game.balance.get("perk_rules",{}).get("mechanics",{})
	var maximum: int = int(limits.get("max_projectiles",game.balance.bullet.max_count))
	var per_owner: int = int(limits.get("max_player_projectiles",24))
	check(game.bullets.size() <= maximum,"four combined pattern builds cannot exceed the configured total projectile cap")
	for identifier: int in [1,200,201,202]:
		var owned: int = game.bullets.filter(func(bullet: Dictionary) -> bool: return int(bullet.owner) == identifier).size()
		check(owned <= per_owner,"one player cannot exceed its projectile budget: %d" % identifier)
	var before_enemy: int = game.bullets.size()
	game._add_bullet(Vector2(300,256),Vector2.LEFT*145,0,1)
	check(game.bullets.size() == before_enemy+1 and int(game.bullets.back().owner) == 0,"heavy player builds preserve reserved capacity for enemy projectiles")
	for attempt: int in range(maximum*2):
		game._add_bullet(Vector2(300,256),Vector2.LEFT*145,0,1)
	check(game.bullets.size() == maximum,"even enemy projectile creation stops at the total hard cap")

func _test_retaliation_killed_boss_cannot_finish_attack() -> void:
	# Arrange a normal contact hit on the final frame of a boss windup.
	_reset()
	_grant("thorns")
	var boss: Dictionary = _enemy(390,Vector2(170,256),1)
	boss.boss = true
	boss.attack = "windup"
	boss.attack_time = 0.001
	game.enemies = [boss]
	game.players[1].invulnerable = 0.0
	# Act: retaliation kills this boss inside the contact-damage callback.
	game._simulate_enemies(0.01)
	# Assert: no posthumous projectile salvo from the same simulation iteration.
	check(float(boss.hp) == 0.0,"contact retaliation really kills the prepared boss")
	check(game.bullets.is_empty(),"a boss killed by contact retaliation cannot complete a queued windup")

func _test_player_factory_discards_old_build() -> void:
	_reset()
	_grant("ember")
	_grant("piercer")
	game._add_player(1)
	check(game.players[1].perks.is_empty() and is_equal_approx(float(game.players[1].damage),float(game.balance.player.damage)), "new-run player factory removes previous owned perks and damage")
	check(float(game.players[1].get("build",{}).get("piercer",0.0)) == 0.0, "new-run player factory removes previous projectile modifiers")

func _test_focus_momentum_and_low_health_change_actual_volleys() -> void:
	_reset()
	if not _combat_available(): return
	_grant("focus")
	_grant("momentum")
	_shoot()
	var still_damage: float = float(game.bullets[0].damage)
	var still_interval: float = float(game.players[1].shot_timer)
	game.bullets.clear()
	game.players[1].shot_timer = 0.0
	game.commands[1] = {"move":Vector2.RIGHT,"aim":Vector2.RIGHT,"fire":true,"sequence":2,"time":Time.get_ticks_msec()/1000.0}
	game._simulate_players(0.01)
	game.commands.clear()
	check(not game.bullets.is_empty() and float(game.bullets[0].damage) < still_damage,"focus damage applies while stationary and disappears while moving")
	check(float(game.players[1].shot_timer) < still_interval,"momentum shortens an actually moving player's volley cooldown")
	_reset()
	_grant("adrenaline")
	_grant("berserk")
	_shoot()
	var healthy_damage: float = float(game.bullets[0].damage)
	var healthy_interval: float = float(game.players[1].shot_timer)
	game.bullets.clear()
	game.players[1].hp = 1
	game.players[1].shot_timer = 0.0
	_shoot()
	check(float(game.bullets[0].damage) > healthy_damage,"berserk increases an actual low-health shot's damage")
	check(float(game.players[1].shot_timer) < healthy_interval,"adrenaline shortens actual low-health volley cooldown")

func _test_execution_mark_longshot_and_first_strike_change_impact_damage() -> void:
	_reset()
	if not _combat_available(): return
	_grant("execution")
	var healthy: Dictionary = _enemy(300,Vector2(300,256))
	var wounded: Dictionary = _enemy(301,Vector2(300,256))
	wounded.hp = 20.0
	check(_impact(wounded) > _impact(healthy),"execution causes extra real damage only against low-health enemies")
	_reset()
	_grant("mark")
	var marked: Dictionary = _enemy(302,Vector2(300,256))
	var first: float = _impact(marked)
	var followup: float = _impact(marked)
	var switched: float = _impact(_enemy(303,Vector2(300,256)))
	check(followup > first and is_equal_approx(switched,first),"mark ramps consecutive target hits and resets when switching targets")
	_reset()
	_grant("longshot")
	check(_impact(_enemy(304,Vector2(300,256)),2,400) > _impact(_enemy(305,Vector2(300,256)),2,0),"longshot uses actual traveled-distance metadata to increase hit damage")
	_reset()
	_grant("first_strike")
	var untouched: Dictionary = _enemy(306,Vector2(300,256))
	var first_strike: float = _impact(untouched)
	var later: float = _impact(untouched)
	check(first_strike > later,"first strike improves the first hit without improving later hits")
	_reset()
	_grant("close_quarters")
	check(_impact(_enemy(307,Vector2(200,256))) > _impact(_enemy(308,Vector2(400,256))),"close quarters increases damage only within its proximity range")

func _test_storm_conductor_and_convergence_reward_prepared_targets() -> void:
	_reset()
	if not _combat_available(): return
	_grant("storm")
	var source: Dictionary = _enemy(320,Vector2(208,256))
	var neighbor: Dictionary = _enemy(321,Vector2(248,256))
	game.enemies = [source,neighbor]
	_impact(source)
	var base_chain: float = 100.0-float(neighbor.hp)
	check(base_chain > 0.0,"storm damages a neighboring enemy through an actual chain effect")
	_grant("conductor")
	neighbor.hp = 100.0
	neighbor.statuses = {"slow":{"power":0.2,"time":3.0,"owner":1,"tick":0.0}}
	_impact(source)
	check(100.0-float(neighbor.hp) > base_chain,"conductor increases chain damage against a previously afflicted neighbor")
	_reset()
	_grant("convergence")
	var plain: Dictionary = _enemy(322,Vector2(208,256))
	var afflicted: Dictionary = _enemy(323,Vector2(208,256))
	afflicted.statuses = {"burn":{"power":1.0,"time":3.0,"owner":1,"tick":0.0},"poison":{"power":1.0,"time":3.0,"owner":1,"tick":0.0}}
	check(_impact(afflicted) > _impact(plain),"convergence rewards multiple existing elements with increased actual impact damage")

func _test_permafrost_and_catalyst_change_status_duration() -> void:
	_reset()
	if not _combat_available(): return
	_grant("frost")
	var simple: Dictionary = _enemy(340,Vector2(208,256))
	_impact(simple)
	var base_time: float = float(simple.statuses.slow.time)
	_grant("catalyst")
	var extended: Dictionary = _enemy(341,Vector2(208,256))
	_impact(extended)
	check(float(extended.statuses.slow.time) > base_time,"catalyst lengthens an actually applied slow status")
	_grant("permafrost")
	var frozen: Dictionary = _enemy(342,Vector2(208,256))
	var boss: Dictionary = _enemy(343,Vector2(208,256))
	boss.boss = true
	var required: int = int(game.balance.get("perk_rules",{}).get("mechanics",{}).get("freeze_hits",4))
	for hit: int in range(required):
		_impact(frozen)
		_impact(boss)
	check(frozen.get("statuses",{}).has("freeze") and boss.get("statuses",{}).has("freeze"),"permafrost freezes both ordinary and boss targets after repeated frost hits")
	check(float(boss.get("statuses",{}).get("freeze",{}).get("time",0)) < float(frozen.get("statuses",{}).get("freeze",{}).get("time",0)),"boss freeze duration is shorter than ordinary-enemy freeze duration")
	var frozen_time: float = float(frozen.statuses.freeze.time)
	for hit: int in range(required): _impact(frozen)
	check(float(frozen.statuses.freeze.time) <= frozen_time,"repeated instant hits cannot indefinitely extend a freeze during its lockout")

func _test_echo_split_blast_and_overkill_have_distinct_secondaries() -> void:
	_reset()
	if not _combat_available(): return
	_grant("echo")
	_grant("twin")
	var cadence: int = int(game.balance.get("perk_rules",{}).get("mechanics",{}).get("echo_every",4))
	var echo_count: int = 0
	for volley: int in range(cadence):
		game.bullets.clear()
		game.players[1].shot_timer = 0.0
		_shoot()
		echo_count = game.bullets.filter(func(bullet: Dictionary) -> bool: return not bool(bullet.get("primary",true))).size()
		if volley < cadence-1: check(echo_count == 0,"echo waits for its cadence rather than duplicating every volley")
	check(echo_count == 2,"echo repeats the actual twin pattern on its cadence")
	_reset()
	_grant("split")
	var target: Dictionary = _enemy(360,Vector2(208,256))
	_impact(target)
	check(game.bullets.size() == 2 and game.bullets.all(func(bullet: Dictionary) -> bool: return not bool(bullet.get("primary",true))),"split creates two weaker secondary projectiles")
	var before: int = game.bullets.size()
	_impact(target,2,0,false)
	check(game.bullets.size() == before,"a secondary projectile cannot split again recursively")
	_reset()
	_grant("blast")
	var direct: Dictionary = _enemy(361,Vector2(208,256))
	var splash: Dictionary = _enemy(362,Vector2(248,256))
	game.enemies = [direct,splash]
	_impact(direct)
	check(float(splash.hp) < 100.0,"blast causes actual nearby splash damage without requiring a kill")
	_reset()
	_grant("overkill")
	var killed: Dictionary = _enemy(363,Vector2(208,256),1)
	var leftover: Dictionary = _enemy(364,Vector2(248,256))
	game.enemies = [killed,leftover]
	_impact(killed,8)
	check(float(leftover.hp) < 100.0,"overkill converts surplus lethal damage into real nearby damage")

func _test_armor_thorns_desperation_and_renewal_have_real_defensive_effects() -> void:
	_reset()
	if not _combat_available(): return
	_grant("stone_skin")
	var cadence: int = maxi(1,int(game.players[1].build.stone_skin))
	var before: int = int(game.players[1].hp)
	for hit: int in range(cadence):
		game.players[1].invulnerable = 0.0
		game._damage_player(1,1)
	check(int(game.players[1].hp) == before-(cadence-1),"stationary stone skin absorbs its periodic incoming hit")
	game.players[1].moving = true
	game.players[1].invulnerable = 0.0
	before = int(game.players[1].hp)
	game._damage_player(1,1)
	check(int(game.players[1].hp) == before-1,"stone skin does not grant stationary protection while moving")
	_reset()
	_grant("thorns")
	_grant("desperation")
	var retaliated: Dictionary = _enemy(380,Vector2(208,256))
	game.enemies = [retaliated]
	game._damage_player(1,1)
	check(float(retaliated.hp) < 100.0,"thorns inflicts actual damage after the owner loses health")
	check(float(game.players[1].invulnerable) > float(game.balance.player.invulnerability),"desperation extends real post-hit invulnerability")
	_reset()
	_grant("renewal")
	game.players[1].hp = 2
	game.perk_combat.room_cleared()
	var renewed: int = int(game.players[1].hp)
	check(renewed > 2,"renewal restores actual missing health at encounter completion")
	game.perk_combat.enter_room(true)
	check(int(game.players[1].hp) == renewed,"renewal cannot heal by revisiting an already cleared room")

func _test_leech_crit_and_legacy_perks_change_real_combat() -> void:
	_reset()
	if not _combat_available(): return
	_grant("leech")
	game.players[1].hp = 2
	var cadence: int = maxi(1,int(game.players[1].build.leech))
	var target: Dictionary = _enemy(400,Vector2(208,256),1000)
	for hit: int in range(cadence): _impact(target)
	check(int(game.players[1].hp) == 3,"leech restores life after its actual successful-hit cadence")
	_reset()
	_grant("crit")
	game.perk_combat.reset()
	var critical: int = 0
	var ordinary: int = 0
	for shot: int in range(96):
		game.bullets.clear()
		game.players[1].shot_timer = 0.0
		_shoot()
		if bool(game.bullets[0].get("critical",false)):
			critical += 1
			check(float(game.bullets[0].damage) > float(game.players[1].damage),"a seeded critical shot carries increased actual damage")
		else: ordinary += 1
	check(critical > 0 and ordinary > 0,"fixed-seed critical chance produces both ordinary and enhanced real projectiles")
	_reset()
	_grant("ember")
	_grant("quick")
	_grant("shadow")
	_shoot()
	check(float(game.bullets[0].damage) > float(game.balance.player.damage) and float(game.players[1].shot_timer) < float(game.balance.player.shot_interval),"legacy damage and quick-fire perks still affect actual projectiles and cooldowns")
	var position: Vector2 = game.players[1].pos
	game.commands[1] = {"move":Vector2.RIGHT,"aim":Vector2.RIGHT,"fire":false,"sequence":2,"time":Time.get_ticks_msec()/1000.0}
	game._simulate_players(0.1)
	game.commands.clear()
	check(game.players[1].pos.x-position.x > float(game.balance.player.speed)*0.1,"shadow increases actual authoritative movement distance")
	_grant("heart")
	game.players[1].hp = 1
	_grant("mend")
	check(int(game.players[1].max_hp) > int(game.balance.player.hp) and int(game.players[1].hp) > 1,"heart and mend change real maximum and current health")
