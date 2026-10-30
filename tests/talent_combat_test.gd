extends SceneTree
## Every one of the 168 talents does something in a real game (src/combat/talent_combat.gd):
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


## A level 30 hero of the talent's class: the talent at its top rank and just
## enough lower talents of the same branch to open its row (a character can
## no longer learn a whole branch; 29 points, rows need up to 20 below them).
func _setup(talent: Dictionary, with_talent: bool = true) -> Dictionary:
	var player: Dictionary = game.players[1]
	player.class_id = str(talent["class"])
	player.pos = Vector2(300, 240)
	player.aim = Vector2.RIGHT
	player.hp = 999
	player.invulnerable = 0.0
	var ranks := {}
	var needed := int(d.tiers[str(int(talent.tier))].points)
	var below := 0
	for id: String in d.talents:
		var other: Dictionary = d.talents[id]
		if str(other.spec) != str(talent.spec) or id == str(talent.id) or str(other.kind) == "ultimate" or int(other.tier) >= int(talent.tier): continue
		if below >= needed: break
		var take := mini(int(other.ranks), needed - below)
		ranks[id] = take
		below += take
	if with_talent: ranks[str(talent.id)] = int(talent.ranks)
	var bar: Array = []
	if with_talent and str(talent.kind) == "active": bar.append(str(talent.id))
	for id: String in ranks:
		if str(d.talents[id].kind) == "active" and bar.size() < 4 and not bar.has(id): bar.append(id)
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
				var targets: Array = [_dummy(Vector2(350, 240)), _dummy(Vector2(380, 240)), _dummy(Vector2(410, 240))].slice(0, mini(3, int(talent.pierce)))
				rt.cds.clear()
				rt.gcd = 0.0
				_cast(talent)
				_tick(0.8)
				check(targets.all(func(e: Dictionary) -> bool: return e.hp < e.max_hp), "%s: pierces %d enemies" % [id, mini(3, int(talent.pierce))])
			if talent.has("splash_m"):
				# the Feuerball bursts where it lands: its neighbour burns too
				var struck := _dummy(Vector2(420, 240))
				var neighbour := _dummy(Vector2(420, 270))
				rt.cds.clear()
				rt.gcd = 0.0
				_cast(talent)
				_tick(0.6)
				check(struck.hp < struck.max_hp and neighbour.hp < neighbour.max_hp, "%s: explodes on impact" % id)
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
		"drawn":
			# Flammenmeer: held, the line follows the mouse up to its length; released, it burns
			var on_line := _dummy(Vector2(420, 300))
			var off_line := _dummy(Vector2(520, 160))
			check(_cast(talent, {"target": Vector2(420, 200)}) and tc.runtime(1).has("drawing"), "%s: the key starts a line at the mouse" % id)
			for k in range(1, 30): tc.hold(1, true, false, Vector2(420, 200 + k * 10), Vector2.ZERO)
			var length := float(talent.length_m) * 32.0
			check(tc.runtime(1).has("drawing") and float(tc.runtime(1).drawing.left) < length, "%s: the fill bar empties while drawing" % id)
			tc.hold(1, false, false, Vector2(420, 500), Vector2.ZERO)
			check(not tc.runtime(1).has("drawing") and tc.zones.size() == 1 and (tc.zones[0].path as Array).size() > 2, "%s: letting go sets the line on fire" % id)
			var drawn := 0.0
			var path: Array = tc.zones[0].path
			for i in range(path.size() - 1): drawn += Vector2(path[i]).distance_to(path[i + 1])
			check(drawn <= length + 0.5, "%s: the line is never longer than %s m" % [id, talent.length_m])
			_tick(1.1)
			check(on_line.hp < on_line.max_hp and is_equal_approx(off_line.hp, off_line.max_hp), "%s: burns what stands on the line only" % id)
		"zone":
			var enemy := _dummy(Vector2(420, 240))
			check(_cast(talent, {"target": Vector2(420, 240)}) and tc.zones.size() == 1, "%s: creates the zone" % id)
			_tick(2.2)
			check(enemy.hp < enemy.max_hp, "%s: the zone hurts" % id)
			if talent.has("status"): check(enemy.statuses.has(str(talent.status)), "%s: the zone applies %s" % [id, talent.status])
			if talent.has("slow"): check(enemy.statuses.has("slow"), "%s: the zone slows" % id)
			if str(talent.get("look", "")) == "arrows":
				# Pfeilhagel: the last volley strikes at once when the field ends
				tc.events.clear()
				_tick(float(talent.time) - 2.0)
				check(tc.zones.is_empty() and tc.events.any(func(e: Dictionary) -> bool: return str(e.kind) == "arrow_finale"), "%s: ends with the closing volley" % id)
		"summon":
			var enemy := _dummy(Vector2(360, 240))
			if bool(talent.get("permanent", false)):
				# a permanent companion is there with the build and is called again only after it fell
				check(not tc.permanent_pet(1).is_empty() and not _cast(talent), "%s: the companion stands there from the start, once" % id)
				if talent.has("pet_kind"): check(str(tc.permanent_pet(1).kind) == str(talent.pet_kind), "%s: summons %s" % [id, talent.pet_kind])
				tc.pets.clear()
				rt.gcd = 0.0
				check(_cast(talent) and not tc.permanent_pet(1).is_empty(), "%s: calls a fallen companion again" % id)
			else:
				check(_cast(talent) and not tc.pets.is_empty(), "%s: summons" % id)
				var own := 1 if not tc.permanent_pet(1).is_empty() or not bool(talent.get("pack", false)) else 0
				if bool(talent.get("pack", false)): check(tc.pets.size() == int(talent.count) + 1, "%s: the pack plus the own summon (%d)" % [id, own])
				if talent.has("pet_kind"): check(tc.pets.filter(func(p: Dictionary) -> bool: return not bool(p.get("permanent", false))).all(func(p: Dictionary) -> bool: return str(p.kind) == str(talent.pet_kind)), "%s: summons %s" % [id, talent.pet_kind])
			_tick(2.5)
			check(enemy.hp < enemy.max_hp, "%s: the summons bite" % id)
		"pet_leap":
			var enemy := _dummy(Vector2(420, 240))
			var other := _dummy(Vector2(440, 260))
			tc.pets.clear()
			check(not _cast(talent), "%s: needs an active wolf" % id)
			tc.cast(1, _summoner(talent), {"aim": Vector2.RIGHT})
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
			_tick(float(talent.time) + 0.2)
			check(enemy.hp < before and rt.channel.is_empty(), "%s: %d strikes over %.0f seconds" % [id, int(talent.hits), float(talent.time)])
		"wall":
			# the wall stands across the aim at the target: 420,240 is on it, 420,320 is beside its end
			var on_wall := _dummy(Vector2(420, 260))
			var beside := _dummy(Vector2(420 + 60, 240 + float(talent.length_m) * 32.0))
			check(_cast(talent) and tc.zones.size() == 1 and tc.zones[0].has("wall"), "%s: raises a wall" % id)
			_tick(1.0)
			check(on_wall.hp < on_wall.max_hp and on_wall.statuses.has("burn"), "%s: burns what touches it" % id)
			check(is_equal_approx(beside.hp, beside.max_hp), "%s: nothing beside the wall" % id)
		"chain":
			var first := _dummy(Vector2(420, 240))
			var second := _dummy(Vector2(480, 250))
			var third := _dummy(Vector2(530, 280))
			var lonely := _dummy(Vector2(900, 600))
			check(_cast(talent) and first.hp < first.max_hp, "%s: hits the enemy at the target" % id)
			check(second.hp < second.max_hp and third.hp < third.max_hp, "%s: jumps on from enemy to enemy" % id)
			check(first.max_hp - first.hp > third.max_hp - third.hp, "%s: each jump is weaker" % id)
			check(is_equal_approx(lonely.hp, lonely.max_hp), "%s: never jumps further than its reach" % id)
		"meteor":
			var enemy := _dummy(Vector2(420, 240))
			check(_cast(talent) and is_equal_approx(enemy.hp, enemy.max_hp), "%s: the meteor is still falling" % id)
			_tick(float(talent.delay) + 0.1)
			check(enemy.hp < enemy.max_hp and tc.zones.size() == 1 and str(tc.zones[0].status) == "burn" and str(tc.zones[0].look) == "crater", "%s: lands on the target and leaves a burning crater" % id)
		"glacier":
			var middle := _dummy(Vector2(420, 240))
			var edge := _dummy(Vector2(420 + float(talent.radius_m) * 32.0 - 20.0, 240))
			check(_cast(talent) and middle.statuses.has("freeze") and not edge.statuses.has("freeze"), "%s: freezes the middle of the block only" % id)
			_tick(1.2)
			check(edge.hp < edge.max_hp and edge.statuses.has("slow"), "%s: the block chills and slows" % id)
		"singularity":
			var drawn := _dummy(Vector2(420 + 120, 240))
			var start := Vector2(drawn.pos).distance_to(Vector2(420, 240))
			check(_cast(talent), "%s casts" % id)
			_tick(1.0)
			check(Vector2(drawn.pos).distance_to(Vector2(420, 240)) < start - 20.0, "%s: pulls enemies to its heart" % id)
			var hp_mid := float(drawn.hp)
			_tick(float(talent.time))
			check(tc.zones.is_empty() and float(drawn.hp) < hp_mid, "%s: collapses at the end" % id)
		"line":
			var first := _dummy(Vector2(340, 240))
			var second := _dummy(Vector2(400, 240))
			var aside := _dummy(Vector2(370, 320))
			check(_cast(talent), "%s casts" % id)
			check(first.hp < first.max_hp and second.hp < second.max_hp and is_equal_approx(aside.hp, aside.max_hp), "%s: pierces everything in the line, nothing beside it" % id)
		"net":
			var caught := _dummy(Vector2(420, 240))
			var boss := _dummy(Vector2(440, 250), true)
			check(_cast(talent) and float(caught.statuses.get("slow", {}).get("power", 0.0)) >= 1.0, "%s: the net holds" % id)
			check(float(boss.statuses.get("slow", {}).get("power", 1.0)) < 1.0, "%s: a boss is only slowed" % id)
			check(tc.traps.size() == int(talent.traps), "%s: lays %d traps" % [id, int(talent.traps)])
		"awaken":
			var pet: Dictionary = tc.permanent_pet(1)
			var near := _dummy(Vector2(330, 250))
			var hp_max := float(pet.get("hp_max", 0.0))
			check(not pet.is_empty() and _cast(talent) and float(pet.awake) > 0.0 and float(pet.hp_max) > hp_max, "%s: the companion grows" % id)
			check(near.has("pet_taunt"), "%s: it roars enemies onto itself" % id)
			_tick(float(talent.time) + 0.2)
			check(is_equal_approx(float(pet.hp_max), hp_max), "%s: and shrinks back" % id)
		"leap":
			var landing := _dummy(Vector2(430, 240))
			check(_cast(talent) and Vector2(player.pos).distance_to(Vector2(420, 240)) < 30.0, "%s: leaps onto the target" % id)
			check(landing.hp < landing.max_hp and rt.buffs.has("fury"), "%s: the impact hits and the fury starts" % id)
		"bulwark":
			var near := _dummy(Vector2(360, 240))
			check(_cast(talent) and near.has("talent_taunt") and float(rt.buffs.unbreakable.reduction_pct) == float(talent.reduction_pct), "%s: taunts and hardens" % id)
			check(tc.incoming(1, 10, Vector2.LEFT) <= 5, "%s: halves the damage" % id)
		"harvest":
			var weak := _dummy(Vector2(340, 240))
			weak.hp = weak.max_hp * 0.12
			var strong := _dummy(Vector2(260, 240))
			player.hp = 500
			rt.res = 60.0
			check(_cast(talent) and float(weak.hp) <= 0.0 and float(strong.hp) > 0.0, "%s: a weak normal enemy falls at once" % id)
			check(int(player.hp) > 500 and float(rt.res) > 60.0 - float(talent.cost), "%s: each hit heals and gives mana" % id)
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
			var build := {"class": "archer", "level": 30, "ranks": {"trapper_1": 2, "trapper_3": 3, str(talent.id): 3}, "bar": ["trapper_3"]}
			tc.set_build(1, build)
			tc.runtime(1).res = 999.0
			tc.cast(1, "trapper_3", {"aim": Vector2.RIGHT, "target": Vector2(420, 240)})
			var bonus: float = tc.traps[0].dmg
			tc.reset(7)
			build.ranks.erase(str(talent.id))
			tc.set_build(1, build)
			tc.runtime(1).res = 999.0
			tc.cast(1, "trapper_3", {"aim": Vector2.RIGHT, "target": Vector2(420, 240)})
			check(bonus > float(tc.traps[0].dmg), "%s: stronger traps" % id)
		"pet_bonus":
			# the permanent companion comes with the build; a filler opens tier 2 for the frost elemental
			var summoner := _summoner(talent)
			var base_ranks := {summoner: 3}
			if not summoner.ends_with("_1"): base_ranks[str(talent.spec) + "_1"] = 2
			var with_bonus := base_ranks.duplicate()
			with_bonus[str(talent.id)] = 3
			tc.reset(7)
			tc.set_build(1, {"class": str(talent["class"]), "level": 30, "ranks": with_bonus, "bar": [summoner]})
			var hp: float = float(tc.permanent_pet(1).get("hp", 0.0))
			tc.reset(7)
			tc.set_build(1, {"class": str(talent["class"]), "level": 30, "ranks": base_ranks, "bar": [summoner]})
			check(hp > float(tc.permanent_pet(1).get("hp", INF)), "%s: a tougher companion" % id)
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
		"damage_pct":
			var with_it: float = tc.outgoing(1, enemy, 10.0, false)
			_setup(talent, false)
			check(with_it > tc.outgoing(1, enemy, 10.0, false), "%s: more damage with everything" % id)
		"talent_pct":
			tc._cur_talent = str(talent.target)
			var with_it: float = tc.outgoing(1, enemy, 10.0, false)
			var other: float = 0.0
			tc._cur_talent = ""
			other = tc.outgoing(1, enemy, 10.0, false)
			check(with_it > other, "%s: only %s hits harder" % [id, talent.target])
		"cdr_pct", "cost_pct":
			var active := ""
			for other_id: String in d.classes[talent["class"]].specs.filter(func(sp: Dictionary) -> bool: return str(sp.id) == str(talent.spec))[0].talents:
				if str(d.talents[other_id].kind) == "active" and float(d.talents[other_id].cost) > 0.0 and not bool(d.talents[other_id].get("permanent", false)): active = other_id; break
			var ranks: Dictionary = rt.ranks.duplicate()
			ranks[active] = maxi(int(ranks.get(active, 0)), 1)
			tc.set_build(1, {"class": str(talent["class"]), "level": 30, "ranks": ranks, "bar": [active]})
			var fresh: Dictionary = tc.runtime(1)
			fresh.res = 999.0
			tc.cast(1, active, {"aim": Vector2.RIGHT, "target": Vector2(420, 240)})
			if str(talent.type) == "cdr_pct": check(float(fresh.cds[active]) < float(d.talents[active].cd), "%s: shorter cooldowns" % id)
			else: check(tc.cost_of(fresh, active) < float(d.talents[active].cost), "%s: cheaper talents" % id)
		"res_on_kill":
			rt.res = 0.0
			var victim := _dummy(Vector2(420, 240))
			victim.hp = 1.0
			game._damage_enemy(victim, 5.0, Vector2.RIGHT, 1, true)
			check(float(rt.res) >= _value(talent, "amount"), "%s: a kill refills the resource (%.1f)" % [id, rt.res])
		_:
			check(false, "%s: no test for type %s" % [id, talent.type])


## The branch's summon talent (the companion or the first skeleton).
func _summoner(talent: Dictionary) -> String:
	for id: String in d.talents:
		var other: Dictionary = d.talents[id]
		if str(other.spec) == str(talent.spec) and str(other.type) == "summon" and not bool(other.get("pack", false)): return id
	return "beast_1"


## Top-rank value of `key`.
func _value(talent: Dictionary, key: String) -> float:
	var raw: Variant = talent.get(key, 0.0)
	return float(raw[-1]) if raw is Array else float(raw)


func _average_hit(enemy: Dictionary) -> float:
	tc._rng.seed = 11
	var total := 0.0
	for i in range(3000): total += tc.outgoing(1, enemy, 10.0, true)
	return total / 3000.0


func _test_resources_and_cooldowns() -> void:
	# Flammenmeer (row IV) brings points of the Feuerball along
	var rt := _setup(d.talents.fire_7)
	_dummy(Vector2(420, 240))
	check(_cast(d.talents.fire_1) and is_equal_approx(float(rt.res), float(rt.res_max) - 14.0), "a spell costs its mana")
	check(not _cast(d.talents.fire_7), "the global cooldown blocks the next talent for a second")
	_tick(1.05)
	check(_cast(d.talents.fire_7), "after the global cooldown another talent works")
	_tick(1.05)
	check(not _cast(d.talents.fire_1), "a talent waits for its own cooldown")
	rt.res = 5.0
	rt.cds.clear()
	rt.gcd = 0.0
	check(not _cast(d.talents.fire_1), "without enough mana nothing is cast")
	_tick(2.0)
	check(float(rt.res) > 5.0 + float(rt.regen) * 1.8, "mana regenerates (%.1f)" % rt.res)
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
	check(float(warrior.cds.get(str(warrior.bar[0]), 0.0)) > 0.0, "key 1 casts the first bar slot")


func _test_bosses_resist_freeze() -> void:
	_setup(d.talents.frost_14)
	var boss := _dummy(Vector2(420, 240), true)
	var normal := _dummy(Vector2(430, 245))
	_cast(d.talents.frost_14)
	check(not boss.statuses.has("freeze") and boss.statuses.has("slow") and normal.statuses.has("freeze"), "Gletschergrab freezes normal enemies and only slows bosses")
	var guard := _setup(d.talents.guard_1)
	var big := _dummy(Vector2(345, 240), true)
	_cast(d.talents.guard_1)
	check(not big.has("talent_taunt"), "bosses ignore taunts")
	check(guard.res >= 0.0, "taunt test ran")


## The ultimate's bought stages change it in the fight (Rules.staged): one
## check per stage of the 12 signature ultimates (user decision 30.10.2026).
func _test_ultimate_stages() -> void:
	# Meteor Stufe 2 + 3: a bigger, longer crater and three small meteors
	var rt := _setup(d.talents.fire_14)
	rt.soul_tier = 2
	_dummy(Vector2(420, 240))
	_dummy(Vector2(470, 260))
	_cast(d.talents.fire_14)
	_tick(1.1)
	check(tc.zones.size() == 1 and float(tc.zones[0].time) > 6.0, "Glutkrater burns longer")
	check((rt.after as Array).size() == 3, "Meteorschauer drops three small meteors")
	_tick(1.5)
	check((rt.after as Array).is_empty(), "the small meteors land")
	# Gletschergrab Stufe 2 + 3: longer, and it shatters with a freeze
	rt = _setup(d.talents.frost_14)
	rt.soul_tier = 2
	var chilled := _dummy(Vector2(420 + 100, 240))
	_cast(d.talents.frost_14)
	check(is_equal_approx(float(tc.zones[0].time), float(d.talents.frost_14.time) + 3.0), "Ewiger Winter lasts 3 s longer")
	_tick(float(d.talents.frost_14.time) + 3.2)
	check(tc.zones.is_empty() and chilled.statuses.has("freeze"), "Eissturz shatters the block and freezes")
	# Singularität Stufe 3: the collapse reloads the other talents
	rt = _setup(d.talents.arcane_14)
	rt.soul_tier = 2
	_cast(d.talents.arcane_14)
	rt.cds.arcane_1 = 9.0
	_tick(float(d.talents.arcane_14.time) + 0.2)
	check(float(rt.cds.arcane_1) == 0.0 and float(rt.cds.arcane_14) > 0.0, "Urknall reloads every other talent")
	# Himmelsspeer Stufe 2 + 3: a brand and the burst at the end
	rt = _setup(d.talents.sniper_14)
	rt.soul_tier = 2
	var branded := _dummy(Vector2(380, 240))
	_cast(d.talents.sniper_14)
	check(int(branded.get("talent_mark", {}).get("owner", -1)) == 1, "Brandmal marks every enemy hit")
	check(tc.events.any(func(e: Dictionary) -> bool: return str(e.kind) == "nova" and str(e.talent) == "sniper_14"), "Sternenfall bursts at the end of the line")
	# Jagdgrund Stufe 3: a sprung trap leaves a poison cloud
	rt = _setup(d.talents.trapper_14)
	rt.soul_tier = 2
	_cast(d.talents.trapper_14)
	check(tc.traps.size() == int(d.talents.trapper_14.traps) + 2, "Treibjagd lays five traps")
	_dummy(Vector2(tc.traps[0].pos))
	_tick(0.1)
	check(tc.zones.any(func(z: Dictionary) -> bool: return str(z.status) == "poison"), "Giftköder leaves a poison cloud")
	# Wildes Erwachen Stufe 3: two spirit wolves
	rt = _setup(d.talents.beast_14)
	rt.soul_tier = 2
	_cast(d.talents.beast_14)
	check(tc.pets.filter(func(p: Dictionary) -> bool: return bool(p.pack)).size() == 2, "Geisterrudel calls two spirit wolves")
	# Erdspalter Stufe 2: the impact stuns
	rt = _setup(d.talents.berserk_14)
	rt.soul_tier = 1
	var stunned := _dummy(Vector2(430, 240))
	_cast(d.talents.berserk_14)
	check(stunned.statuses.has("freeze"), "Erdbeben stuns at the impact")
	# Bollwerk Stufe 2: whoever hits the hero is hurt back
	rt = _setup(d.talents.guard_14)
	rt.soul_tier = 1
	var attacker := _dummy(Vector2(320, 240))
	_cast(d.talents.guard_14)
	var hp_before := float(attacker.hp)
	tc.incoming(1, 2, Vector2.LEFT)
	check(float(attacker.hp) < hp_before, "Dornenschild hits the attacker back")
	# Klingensturm Stufe 3: six ghost blades at the end
	rt = _setup(d.talents.blade_14)
	rt.soul_tier = 2
	_cast(d.talents.blade_14)
	for step in range(120):
		if rt.channel.is_empty(): break
		tc.step(0.05)
	check(game.bullets.filter(func(b: Dictionary) -> bool: return str(b.get("talent", "")) == "blade_14").size() == 6, "Geisterklingen fly in six directions")
	# Knochenkoloss Stufe 3: it bursts when it falls
	rt = _setup(d.talents.minion_14)
	rt.soul_tier = 2
	_cast(d.talents.minion_14)
	var colossus: Dictionary = tc.pets.filter(func(p: Dictionary) -> bool: return str(p.kind) == "colossus")[0]
	var close := _dummy(Vector2(colossus.pos) + Vector2(40, 0))
	colossus.hp = 0.0
	hp_before = float(close.hp)
	_tick(0.1)
	check(float(close.hp) < hp_before, "Knochensplitter burst when the colossus falls")
	# Seuchengrube: the pit weakens; Totenruf raises the dead
	rt = _setup(d.talents.curse_14)
	rt.soul_tier = 1
	var sick := _dummy(Vector2(310, 240))
	_cast(d.talents.curse_14, {"target": Vector2(310, 240)})
	_tick(0.1)
	check(sick.has("talent_weak"), "Seuchengrube weakens enemies in the pit")
	check(tc.incoming(1, 10, Vector2.LEFT) < 10, "a weakened enemy hits softer")
	var pets_before: int = tc.pets.size()
	tc.enemy_killed(sick, 1)
	check(tc.pets.size() == pets_before + 1 and str(tc.pets[-1].kind) == "skeleton", "Totenruf raises the fallen as a skeleton")
	# Seelenernte Stufe 3: a second wave and every other talent reloads
	rt = _setup(d.talents.soul_14)
	rt.soul_tier = 2
	rt.cds.soul_1 = 9.0
	_dummy(Vector2(340, 240))
	_cast(d.talents.soul_14)
	check(float(rt.cds.soul_1) == 0.0 and (rt.after as Array).size() == 1, "Seelensturm reloads and queues a second wave")
