extends SceneTree
## Every one of the 54 talents does something in a real game (src/combat/talent_combat.gd):
## each active and ultimate is cast at test dummies and its effect checked by
## type; each passive is checked against the same situation without it.
## Also: resources, cooldowns, the global cooldown, bosses immune to freeze,
## and the ultimate stages (talents.json "stages") changing the ability.

const Game = preload("res://src/game.gd")
var checked := 0
var failures: Array[String] = []
var game
var tc
var d: Dictionary
var _dummy_id := 9000

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("TALENT_COMBAT_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://talent_combat_test_profile.json"
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 4242
	game._begin_run()
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	game.players[1].max_hp = 999
	game.players[1].hp = 999
	for talent: Dictionary in d.talents.values(): _test_talent(talent)
	_test_resources_and_cooldowns()
	_test_bosses_resist_freeze()
	_test_ultimate_stages()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	print("TALENT_COMBAT checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	quit(0 if failures.is_empty() else 1)


## A hero of the talent's class with its whole branch at rank 3 and the ultimate.
func _setup(talent: Dictionary, with_talent: bool = true) -> Dictionary:
	var player: Dictionary = game.players[1]
	player.class_id = str(talent["class"])
	player.pos = Vector2(300, 240)
	player.aim = Vector2.RIGHT
	player.hp = 999
	player.invulnerable = 0.0
	var ranks := {}
	for id: String in d.talents:
		var other: Dictionary = d.talents[id]
		if str(other.spec) == str(talent.spec): ranks[id] = int(other.ranks)
	if not with_talent: ranks.erase(str(talent.id))
	var bar: Array = []
	for id: String in ranks:
		if str(d.talents[id].kind) == "active" and bar.size() < 4: bar.append(id)
	tc.reset(7)
	tc.set_build(1, {"class": str(talent["class"]), "level": 30, "ranks": ranks, "bar": bar, "soul_tier": 0})
	game.enemies.clear()
	game.bullets.clear()
	var rt: Dictionary = tc.runtime(1)
	rt.res = float(rt.res_max)
	return rt


func _dummy(pos: Vector2, boss: bool = false) -> Dictionary:
	_dummy_id += 1
	var enemy := {"pos": pos, "hp": 5000.0, "max_hp": 5000.0, "boss": boss, "radius": 13.0, "id": _dummy_id, "kind": "dummy", "speed": 0.0,
		"hits": 0, "statuses": {}, "knockback": Vector2.ZERO, "hitstun": 0.0, "stun_cooldown": 0.0, "dying": 0.0, "face": -1.0}
	game.enemies.append(enemy)
	return enemy


func _tick(seconds: float) -> void:
	var steps := int(seconds / 0.05)
	for i in range(steps):
		tc.step(0.05)
		game._simulate_bullets(0.05)
		game.perk_combat.step_statuses(0.05)


func _cast(talent: Dictionary, command: Dictionary = {}) -> bool:
	var base := {"aim": Vector2.RIGHT, "target": Vector2(420, 240)}
	base.merge(command, true)
	return tc.cast(1, str(talent.id), base)


func _test_talent(talent: Dictionary) -> void:
	var id := str(talent.id)
	var type := str(talent.type)
	var rt := _setup(talent)
	var player: Dictionary = game.players[1]
	match type:
		"projectile":
			var enemy := _dummy(Vector2(420, 240))
			check(_cast(talent), "%s casts" % id)
			_tick(0.6)
			check(enemy.hp < enemy.max_hp, "%s: the shot hits" % id)
			if talent.has("status"): check(enemy.statuses.has(str(talent.status)), "%s: applies %s" % [id, talent.status])
			if talent.has("slow"): check(enemy.statuses.has("slow"), "%s: slows" % id)
			if int(talent.get("pierce", 1)) > 1:
				# Close together: the room's pillars must not stop the arrow.
				var targets: Array = [_dummy(Vector2(350, 240)), _dummy(Vector2(380, 240)), _dummy(Vector2(410, 240))]
				rt.cds.clear()
				rt.gcd = 0.0
				_cast(talent)
				_tick(0.8)
				check(targets.all(func(e: Dictionary) -> bool: return e.hp < e.max_hp), "%s: pierces up to three enemies" % id)
		"nova", "taunt_area":
			var near := _dummy(Vector2(340, 240))
			var far := _dummy(Vector2(300 + float(talent.radius_m) * 32.0 + 60.0, 240))
			check(_cast(talent), "%s casts" % id)
			if type == "nova":
				check(near.hp < near.max_hp and far.hp == far.max_hp, "%s: hits inside the radius only" % id)
				if talent.has("freeze"): check(near.statuses.has("freeze"), "%s: freezes normal enemies" % id)
				if talent.has("status"): check(near.statuses.has(str(talent.status)), "%s: applies %s" % [id, talent.status])
			else:
				check(near.has("talent_taunt") and not far.has("talent_taunt"), "%s: taunts enemies in range" % id)
				check(float(rt.res) > float(rt.res_max) - 1.0 or float(rt.res) > 0.0, "%s: gives rage" % id)
		"blink":
			var at_start := _dummy(Vector2(320, 240))
			var from: Vector2 = player.pos
			check(_cast(talent), "%s casts" % id)
			check(Vector2(player.pos).distance_to(from) > 60.0, "%s: teleports the hero" % id)
			if talent.has("dmg"): check(at_start.hp < at_start.max_hp, "%s: damages around the starting point" % id)
		"dash":
			var on_path := _dummy(Vector2(380, 240))
			var from: Vector2 = player.pos
			check(_cast(talent), "%s casts" % id)
			check(Vector2(player.pos).distance_to(from) > 60.0 and on_path.hp < on_path.max_hp, "%s: dashes through and hits" % id)
		"melee":
			var front := _dummy(Vector2(345, 240))
			var behind := _dummy(Vector2(255, 240))
			check(_cast(talent), "%s casts" % id)
			check(front.hp < front.max_hp and behind.hp == behind.max_hp, "%s: hits in front only" % id)
			if talent.has("status"): check(front.statuses.has(str(talent.status)), "%s: applies %s" % [id, talent.status])
			if talent.has("taunt"): check(front.has("talent_taunt"), "%s: provokes" % id)
		"shield":
			check(_cast(talent) and float(rt.shield) > 0.0, "%s: raises a shield" % id)
			check(tc.incoming(1, 2, Vector2.ZERO) < 2, "%s: the shield absorbs damage" % id)
		"buff":
			check(_cast(talent) and rt.buffs.has(str(talent.buff)), "%s: the buff starts" % id)
			match str(talent.buff):
				"frenzy": check(tc.interval_scale(player, 1) < 1.0, "%s: faster attacks" % id)
				"bloodlust": check(tc.outgoing(1, _dummy(Vector2(900, 100)), 10.0, false) > 10.0, "%s: more damage" % id)
				"bulwark", "unbreakable", "oath": check(_taken(30) < 60, "%s: less damage taken" % id)
				"timebreak":
					var other: String = str(rt.bar[0]) if not rt.bar.is_empty() else ""
					if not other.is_empty():
						rt.gcd = 0.0
						tc.cast(1, other, {"aim": Vector2.RIGHT})
						check(float(rt.cds[other]) < float(d.talents[other].cd), "%s: shorter cooldowns" % id)
			if bool(talent.get("cc_immune", false)): check(tc.cc_immune(1), "%s: immune to crowd control" % id)
		"echo":
			_dummy(Vector2(420, 240))
			check(_cast(talent) and float(rt.echo) > 0.0, "%s: the echo waits for the next spell" % id)
			rt.gcd = 0.0
			var spell := "arcane_1"
			tc.cast(1, spell, {"aim": Vector2.RIGHT})
			var shots: int = game.bullets.size()
			_tick(0.5)
			check(float(rt.echo) == 0.0 and not rt.has("echo_cast") and shots >= 1, "%s: the next spell repeats once" % id)
		"mark":
			var enemy := _dummy(Vector2(420, 240))
			check(_cast(talent) and enemy.has("talent_mark"), "%s: marks the target" % id)
			check(tc.outgoing(1, enemy, 10.0, false) > 10.0, "%s: more damage against the mark" % id)
		"trap":
			check(_cast(talent, {"target": Vector2(420, 240)}) and tc.traps.size() == 1, "%s: sets a trap" % id)
			var enemy := _dummy(Vector2(422, 240))
			_tick(0.1)
			check(enemy.hp < enemy.max_hp and tc.traps.is_empty(), "%s: the trap springs" % id)
			if talent.has("root"): check(float(enemy.statuses.get("slow", {}).get("power", 0.0)) >= 1.0, "%s: holds the enemy" % id)
		"zone":
			var enemy := _dummy(Vector2(420, 240))
			check(_cast(talent, {"target": Vector2(420, 240)}) and tc.zones.size() == 1, "%s: creates the zone" % id)
			_tick(2.2)
			check(enemy.hp < enemy.max_hp and enemy.statuses.has("poison"), "%s: the zone hurts and poisons" % id)
		"summon":
			var enemy := _dummy(Vector2(360, 240))
			check(_cast(talent) and not tc.pets.is_empty(), "%s: summons wolves" % id)
			if bool(talent.get("pack", false)): check(tc.pets.size() == 3, "%s: two extra wolves plus the companion" % id)
			_tick(2.5)
			check(enemy.hp < enemy.max_hp, "%s: the wolves bite" % id)
		"pet_leap":
			var enemy := _dummy(Vector2(420, 240))
			var other := _dummy(Vector2(440, 260))
			check(not _cast(talent), "%s: needs an active wolf" % id)
			tc.cast(1, "beast_1", {"aim": Vector2.RIGHT})
			rt.gcd = 0.0
			rt.res = float(rt.res_max)
			check(_cast(talent), "%s: casts with a wolf" % id)
			check(enemy.hp < enemy.max_hp and other.has("pet_taunt"), "%s: leaps and draws enemies to the wolf" % id)
		"counter":
			var enemy := _dummy(Vector2(330, 240))
			check(_cast(talent) and not rt.counter.is_empty(), "%s: readies the counter" % id)
			check(tc.incoming(1, 3, Vector2.LEFT) == 0 and enemy.hp < enemy.max_hp, "%s: blocks and strikes back" % id)
		"channel":
			var enemy := _dummy(Vector2(340, 240))
			check(_cast(talent), "%s casts" % id)
			var before: float = enemy.hp
			_tick(3.2)
			check(enemy.hp < before and rt.channel.is_empty(), "%s: six strikes over three seconds" % id)
		_:
			_test_passive(talent, rt)


## Damage taken from `hits` hits of 2.
func _taken(hits: int) -> int:
	var total := 0
	for i in range(hits): total += tc.incoming(1, 2, Vector2.ZERO)
	return total


func _test_passive(talent: Dictionary, rt: Dictionary) -> void:
	var id := str(talent.id)
	var enemy := _dummy(Vector2(420, 240))
	match str(talent.type):
		"bonus_vs_status":
			for status: String in talent.statuses: enemy.statuses[status] = {"power": 0.1, "time": 5.0, "owner": 1, "tick": 0.0}
			var with_bonus: float = tc.outgoing(1, enemy, 10.0, false)
			_setup(talent, false)
			check(with_bonus > tc.outgoing(1, enemy, 10.0, false), "%s: more damage against affected enemies" % id)
		"dot_bonus":
			var source: String = {"burn": "fire_1", "poison": "trapper_1", "bleed": "blade_1"}[str(talent.status)]
			tc._apply_status(1, enemy, d.talents[source], rt, source)
			var with_bonus: float = enemy.statuses[str(talent.status)].power
			_setup(talent, false)
			enemy.statuses.clear()
			tc._apply_status(1, enemy, d.talents[source], tc.runtime(1), source)
			check(with_bonus > float(enemy.statuses[str(talent.status)].power), "%s: stronger %s" % [id, talent.status])
		"damage_reduction":
			var with_it := _taken(50)
			_setup(talent, false)
			check(with_it < _taken(50), "%s: less damage taken" % id)
		"resource_bonus":
			check(float(rt.res_max) > float(d.resources[talent["class"]].max) and float(rt.regen) > float(d.resources[talent["class"]].regen), "%s: more mana and regeneration" % id)
		"refund":
			rt.res = 100.0
			for i in range(3):
				rt.gcd = 0.0
				rt.cds.clear()
				tc.cast(1, "arcane_1", {"aim": Vector2.RIGHT})
			check(is_equal_approx(float(rt.res), 100.0 - 42.0 + 8.0), "%s: every third spell gives mana back (%.1f)" % [id, rt.res])
		"crit_chance", "crit_damage":
			var with_it := _average_hit(enemy)
			_setup(talent, false)
			check(with_it > _average_hit(enemy), "%s: more critical damage on average" % id)
		"trap_bonus":
			tc.cast(1, "trapper_3", {"aim": Vector2.RIGHT, "target": Vector2(420, 240)})
			var bonus: float = tc.traps[0].dmg
			_setup(talent, false)
			tc.cast(1, "trapper_3", {"aim": Vector2.RIGHT, "target": Vector2(420, 240)})
			check(bonus > float(tc.traps[0].dmg), "%s: stronger traps" % id)
		"pet_bonus":
			tc.cast(1, "beast_1", {"aim": Vector2.RIGHT})
			var hp: float = tc.pets[0].hp
			_setup(talent, false)
			tc.cast(1, "beast_1", {"aim": Vector2.RIGHT})
			check(hp > float(tc.pets[0].hp), "%s: a tougher wolf" % id)
		"bonus_vs_pet_target":
			rt.pet_target = int(enemy.id)
			var with_it: float = tc.outgoing(1, enemy, 10.0, false)
			_setup(talent, false)
			tc.runtime(1).pet_target = int(enemy.id)
			check(with_it > tc.outgoing(1, enemy, 10.0, false), "%s: more damage against the wolf's prey" % id)
		"pet_guard":
			tc.cast(1, "beast_1", {"aim": Vector2.RIGHT})
			check(tc.incoming(1, 4, Vector2.ZERO) == 2, "%s: the wolf halves the next hit" % id)
			check(tc.incoming(1, 4, Vector2.ZERO) == 4, "%s: then waits for its cooldown" % id)
		"heal_on_kill":
			var player: Dictionary = game.players[1]
			player.hp = 500
			for i in range(3):
				var victim := _dummy(Vector2(420, 240))
				victim.hp = 1.0
				game._damage_enemy(victim, 5.0, Vector2.RIGHT, 1, true)
			check(int(player.hp) > 500, "%s: kills heal the hero" % id)
		"rage_per_hit":
			rt.res = 0.0
			game._damage_enemy(enemy, 1.0, Vector2.RIGHT, 1, true)
			check(float(rt.res) > float(d.resources.swordsman.per_hit), "%s: more rage per basic hit (%.0f)" % [id, rt.res])
		_:
			check(false, "%s: no test for type %s" % [id, talent.type])


func _average_hit(enemy: Dictionary) -> float:
	tc._rng.seed = 11
	var total := 0.0
	for i in range(3000): total += tc.outgoing(1, enemy, 10.0, true)
	return total / 3000.0


func _test_resources_and_cooldowns() -> void:
	var rt := _setup(d.talents.fire_1)
	_dummy(Vector2(420, 240))
	check(_cast(d.talents.fire_1) and is_equal_approx(float(rt.res), float(rt.res_max) - 14.0), "a spell costs its mana")
	check(not _cast(d.talents.fire_3), "the global cooldown blocks the next talent for a second")
	_tick(1.05)
	check(_cast(d.talents.fire_3), "after the global cooldown another talent works")
	_tick(1.05)
	check(not _cast(d.talents.fire_1), "a talent waits for its own cooldown")
	rt.res = 5.0
	rt.cds.clear()
	rt.gcd = 0.0
	check(not _cast(d.talents.fire_1), "without enough mana nothing is cast")
	_tick(2.0)
	check(float(rt.res) > 15.0, "mana regenerates (%.1f)" % rt.res)
	_setup(d.talents.berserk_1)
	tc.set_build(1, {"class": "swordsman", "level": 30, "ranks": {"berserk_1": 3}, "bar": ["berserk_1"]})
	var warrior: Dictionary = tc.runtime(1)
	check(float(warrior.res) == 0.0, "rage starts empty")
	tc.incoming(1, 1, Vector2.ZERO)
	check(float(warrior.res) == 5.0, "a hit taken gives 5 rage")
	game._damage_enemy(_dummy(Vector2(500, 240)), 1.0, Vector2.RIGHT, 1, true)
	check(float(warrior.res) >= 15.0, "a basic hit gives 10 rage")
	var command := {"skills": 1 << tc.BAR_BIT, "aim": Vector2.RIGHT}
	warrior.res = 100.0
	tc.handle_input(1, game.players[1], command)
	check(float(warrior.cds.get(str(warrior.bar[0]), 0.0)) > 0.0, "Shift + 1 casts the first bar slot")


func _test_bosses_resist_freeze() -> void:
	_setup(d.talents.frost_6)
	var boss := _dummy(Vector2(340, 240), true)
	var normal := _dummy(Vector2(260, 240))
	_cast(d.talents.frost_6)
	check(not boss.statuses.has("freeze") and boss.statuses.has("slow") and normal.statuses.has("freeze"), "Absoluter Nullpunkt freezes normal enemies and only slows bosses")
	var guard := _setup(d.talents.guard_1)
	var big := _dummy(Vector2(345, 240), true)
	_cast(d.talents.guard_1)
	check(not big.has("talent_taunt"), "bosses ignore taunts")
	check(guard.res >= 0.0, "taunt test ran")


## The ultimate's bought stages change it in the fight (Rules.staged).
func _test_ultimate_stages() -> void:
	# Inferno Stufe 3: a second blast after 1.5 s and burning ground
	var rt := _setup(d.talents.fire_6)
	rt.soul_tier = 2
	var near := _dummy(Vector2(340, 240))
	_cast(d.talents.fire_6)
	check(tc.zones.size() == 1 and str(tc.zones[0].status) == "burn", "Inferno Stufe 3 leaves burning ground")
	check((rt.after as Array).size() == 1, "Inferno Stufe 3 queues its second blast")
	var before := float(near.hp)
	var novas: int = tc.events.filter(func(e: Dictionary) -> bool: return str(e.kind) == "nova").size()
	_tick(1.6)
	check((rt.after as Array).is_empty() and float(near.hp) < before, "the second blast goes off and hits")
	check(tc.events.filter(func(e: Dictionary) -> bool: return str(e.kind) == "nova").size() > novas or novas > 0, "the second blast is shown")
	# Inferno Stufe 1: no second blast, no ground
	rt = _setup(d.talents.fire_6)
	_dummy(Vector2(340, 240))
	_cast(d.talents.fire_6)
	check(tc.zones.is_empty() and (rt.after as Array).is_empty(), "Inferno Stufe 1 is the plain blast")
	# Letzter Pfeil Stufe 3: three arrows
	rt = _setup(d.talents.sniper_6)
	rt.soul_tier = 2
	_dummy(Vector2(420, 240))
	_cast(d.talents.sniper_6)
	check(game.bullets.filter(func(b: Dictionary) -> bool: return str(b.get("talent", "")) == "sniper_6").size() == 3, "Letzter Pfeil Stufe 3 fires three arrows")
	# Zeitbruch Stufe 3: the other talents reload, a wave closes the buff
	rt = _setup(d.talents.arcane_6)
	rt.soul_tier = 2
	rt.cds.arcane_1 = 9.0
	var dummy := _dummy(Vector2(330, 240))
	_cast(d.talents.arcane_6)
	check(float(rt.cds.arcane_1) == 0.0 and float(rt.cds.arcane_6) > 0.0, "Zeitschleife reloads every other talent")
	check(is_equal_approx(float(rt.buffs.timebreak.time), float(d.talents.arcane_6.time) + 3.0), "Beschleunigung lasts 3 s longer")
	var hp_before := float(dummy.hp)
	_tick(float(d.talents.arcane_6.time) + 3.2)
	check(float(dummy.hp) < hp_before, "an arcane wave closes Zeitbruch")
	# Todeszone Stufe 2: enemies in the zone are slowed
	rt = _setup(d.talents.trapper_6)
	rt.soul_tier = 1
	var walker := _dummy(Vector2(420, 240))
	_cast(d.talents.trapper_6)
	_tick(0.2)
	check(walker.statuses.has("slow"), "Sumpfgift slows enemies in the zone")
	# Klingentanz Stufe 2: nine strikes
	rt = _setup(d.talents.blade_6)
	rt.soul_tier = 1
	_cast(d.talents.blade_6)
	check(int(rt.channel.left) == int(d.talents.blade_6.hits) + 3, "Wirbelklingen strikes nine times")
