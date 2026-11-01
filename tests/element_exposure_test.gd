extends SceneTree
## The element exposure kit (src/physics_kit/element_exposure.gd,
## ElementExposure; BAUPLAN M1c) on a fake host, no game:
## - a monster's hurt lands on the rule's tick (enemy_hurt x tick, boss_hurt
##   of it on a boss), the hero's drains every frame (hurt per second);
## - conditions from the rule's status (damage over time scaled by the
##   profile), the hero's WAHN left to his own clock, water douses;
## - immunity by tags, crusted lava, the host's exempt and warded;
## - the combos: burning into poison sets it off (pool and gas), wet into
##   frost freezes solid (never a boss; the hero only in frost gas);
## - dead, burrowed and airborne creatures are skipped;
## - gas sampling radii and counts from the data, blind and vision from the gas,
##   the void's pull centre and the maddening flag;
## - the madness split: MadnessRules holds madness and gefuege, ElementRules
##   forwards and keeps only physics.
## Values come from assets/data/element_rules.json and madness_rules.json.
## Deterministic; writes nothing.

const ElementRules = preload("res://src/combat/element_rules.gd")
const DT := 1.0 / 60.0
## A pool's reach round its centre in the fake world (world px).
const POOL_R := 40.0
var checked := 0
var failures: Array[String] = []


## A fake world: round pools ({at, style}), one gas answer for every point,
## crusted spots, an ignite log. Actors are dictionaries: {p, hp, profile,
## tags, burrowed, alt, boss, statuses {kind: [value, s]}, timers, hurt, why}.
class FakeHost extends "res://src/physics_kit/exposure_host.gd":
	var pools: Array = []
	var cloud: Dictionary = {"mat": "", "d": 0.0}
	var crusted := false
	var reactions := true
	var ignites: Array = []
	var asked_gas: Array = []
	var centre := Vector2(7, 9)
	var exempt_from := ""
	var ward := ""
	var combos_shown: Array = []

	func pools_under(at: Vector2) -> Array:
		var out: Array = []
		for pool: Dictionary in pools:
			if at.distance_to(pool.at) <= POOL_R:
				out.append(pool.style)
		return out

	func gas_around(_at: Vector2, radius: float, samples: int) -> Dictionary:
		asked_gas.append([radius, samples])
		return cloud

	func pool_centre(_at: Vector2, _style: String) -> Vector2:
		return centre

	func lava_crusted(_at: Vector2) -> bool:
		return crusted

	func ignite(at: Vector2, radius: float) -> bool:
		ignites.append([at, radius])
		return reactions

	func world_scale() -> float:
		return 1.5

	func profile(actor: Variant) -> String:
		return str(actor.get("profile", "monster"))

	func actor_at(actor: Variant) -> Vector2:
		return actor.p

	func actor_alive(actor: Variant) -> bool:
		return float(actor.hp) > 0.0

	func actor_burrowed(actor: Variant) -> bool:
		return bool(actor.get("burrowed", false))

	func actor_altitude(actor: Variant) -> float:
		return float(actor.get("alt", 0.0))

	func actor_boss(actor: Variant) -> bool:
		return bool(actor.get("boss", false))

	func actor_tags(actor: Variant) -> Array:
		return actor.get("tags", [])

	func exempt(_actor: Variant, material: String) -> bool:
		return material == exempt_from

	func warded(_actor: Variant, what: String) -> bool:
		return what == ward

	func has_status(actor: Variant, kind: String) -> bool:
		return (actor.statuses as Dictionary).has(kind)

	func set_status(actor: Variant, kind: String, value: float, seconds: float) -> void:
		actor.statuses[kind] = [value, seconds]

	func clear_status(actor: Variant, kind: String) -> void:
		(actor.statuses as Dictionary).erase(kind)

	func hurt(actor: Variant, amount: float, why: String) -> void:
		actor.hurt = float(actor.hurt) + amount
		actor.why = why

	func timer(actor: Variant, key: String) -> float:
		return float((actor.timers as Dictionary).get(key, 0.0))

	func set_timer(actor: Variant, key: String, seconds: float) -> void:
		actor.timers[key] = seconds

	func show_combo(_actor: Variant, combo: String) -> void:
		combos_shown.append(combo)


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ELEMENT_EXPOSURE_FAIL: ", label)


func _initialize() -> void:
	test_monster_hurt_on_the_tick()
	test_hero_drains_every_frame()
	test_immunity_by_tags()
	test_douse()
	test_crusted_lava_skip()
	test_burning_into_poison()
	test_wet_into_frost()
	test_burrowed_and_airborne_skip()
	test_exempt_and_warded()
	test_gas_sampling_from_the_data()
	test_pull_madness_blind_vision()
	test_empty_host()
	test_madness_split()
	print("ELEMENT_EXPOSURE checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _actor(profile := "monster", tags: Array = []) -> Dictionary:
	return {"p": Vector2.ZERO, "hp": 10.0, "profile": profile, "tags": tags, "statuses": {}, "timers": {}, "hurt": 0.0, "why": ""}


func _host_with_pool(style: String) -> FakeHost:
	var host := FakeHost.new()
	host.pools = [{"at": Vector2.ZERO, "style": style}]
	return host


func _run(kit: ElementExposure, actor: Dictionary, seconds: float) -> Dictionary:
	var last := {}
	for i in range(roundi(seconds / DT)):
		last = kit.step(actor, DT)
	return last


func _profile(name: String) -> Dictionary:
	return (ElementRules.data().exposure as Dictionary)[name]


func test_monster_hurt_on_the_tick() -> void:
	var rule := ElementRules.medium("poison")
	var tick := float(rule.tick)
	var kit := ElementExposure.new(_host_with_pool("poison"))
	var m := _actor()
	# 2.5 s: a tick at once, then every tick s (three for poison's 1.2 s)
	var seconds := tick * 2.0 + 0.1
	var met := _run(kit, m, seconds)
	var ticks := floori(seconds / tick) + 1
	check(absf(float(m.hurt) - float(rule.enemy_hurt) * tick * ticks) < 0.0001, "a monster loses enemy_hurt x tick on each of %d ticks (%.3f)" % [ticks, m.hurt])
	var prof := _profile("monster")
	var spec: Array = rule.status.poison
	check(is_equal_approx(float(m.statuses.poison[0]), float(spec[0]) * float(prof.dot_scale)) and is_equal_approx(float(m.statuses.poison[1]), float(spec[1])),
		"its poison: the rule's value x dot_scale for its time")
	check(met.style == "poison" and (met.medium as Dictionary).has("slow") and not (met.medium as Dictionary).has("centre"), "the medium comes back for the movement")
	# a boss feels boss_hurt of it
	var boss := _actor()
	boss.boss = true
	_run(ElementExposure.new(_host_with_pool("poison")), boss, seconds)
	check(absf(float(boss.hurt) - float(m.hurt) * float(prof.boss_hurt)) < 0.0001, "a boss loses boss_hurt of it")


func test_hero_drains_every_frame() -> void:
	var rule := ElementRules.medium("lava")
	var kit := ElementExposure.new(_host_with_pool("lava"))
	var hero := _actor("hero")
	_run(kit, hero, 1.0)
	check(absf(float(hero.hurt) - float(rule.hurt)) < 0.0001, "the hero loses hurt half hearts per second, drained every frame (%.4f)" % hero.hurt)
	check(hero.why == str(rule.why), "he reads the rule's why")
	var spec: Array = rule.status.burn
	check(is_equal_approx(float(hero.statuses.burn[0]), float(spec[0]) * float(_profile("hero").dot_scale)), "his burn: the rule's half hearts per second")
	# the gas without a why of its own: the profile's why with the material
	var host := FakeHost.new()
	host.cloud = {"mat": "probe_gas", "d": 1.0}
	var probe := ElementExposure.new(host)
	var plain := {"hurt": 1.0}
	probe.combos = {}
	var hero2 := _actor("hero")
	probe._harm(hero2, _profile("hero"), plain, "probe_gas", "gas_tick", DT)
	check(hero2.why == str(_profile("hero").why) % "probe_gas", "a rule without why: the profile's why (%s)" % hero2.why)


func test_immunity_by_tags() -> void:
	var rule := ElementRules.medium("poison")
	var immune_tag := str((rule.immune as Array)[0])
	var kit := ElementExposure.new(_host_with_pool("poison"))
	var m := _actor("monster", [immune_tag])
	var met := _run(kit, m, 2.0)
	check(is_zero_approx(float(m.hurt)) and (m.statuses as Dictionary).is_empty(), "a creature of %s feels nothing of the poison" % immune_tag)
	check((met.medium as Dictionary).is_empty() and met.style == "poison", "no footing either, but the pool is named")


func test_douse() -> void:
	var kit := ElementExposure.new(_host_with_pool("water"))
	var m := _actor()
	m.statuses.burn = [1.0, 5.0]
	kit.step(m, DT)
	check(not (m.statuses as Dictionary).has("burn"), "water douses a burning monster")
	check((m.statuses as Dictionary).has("wet"), "and makes it wet")


func test_crusted_lava_skip() -> void:
	var host := _host_with_pool("lava")
	host.crusted = true
	var m := _actor()
	var met := _run(ElementExposure.new(host), m, 1.0)
	check(is_zero_approx(float(m.hurt)) and (m.statuses as Dictionary).is_empty(), "crusted lava burns nobody")
	check(met.style == "" and (met.medium as Dictionary).is_empty(), "it is cool stone: no style, no medium")


func test_burning_into_poison() -> void:
	var combos: Dictionary = ElementRules.data().combos
	var host := _host_with_pool("poison")
	var kit := ElementExposure.new(host)
	var m := _actor("monster", ["poison"])
	m.p = Vector2(3, 4)
	m.statuses.burn = [1.0, 5.0]
	var met := kit.step(m, DT)
	check(met.ignited == "pool" and host.ignites.size() == 1, "a burning monster sets the poison it stands in off, even one of poison")
	check(host.ignites[0][0] == m.p and is_equal_approx(float(host.ignites[0][1]), float(combos.explode_r) * host.world_scale()), "at its feet, explode_r x world_scale")
	check(not (m.statuses as Dictionary).has("poison") and is_zero_approx(float(m.hurt)), "the pool is gone for it: no poison this frame")
	# through the gas
	var air := FakeHost.new()
	air.cloud = {"mat": "poison", "d": 1.0}
	var hero := _actor("hero")
	hero.statuses.burn = [1.0, 5.0]
	check(ElementExposure.new(air).step(hero, DT).ignited == "gas" and air.ignites.size() == 1, "a burning hero sets poison gas off")
	# a world without reactions: the poison simply acts
	var dull := _host_with_pool("poison")
	dull.reactions = false
	var n := _actor()
	n.statuses.burn = [1.0, 5.0]
	var plain := ElementExposure.new(dull).step(n, DT)
	check(plain.ignited == "" and (n.statuses as Dictionary).has("poison"), "without reactions the poison poisons it")


func test_wet_into_frost() -> void:
	var freeze := float(ElementRules.data().combos.freeze_wet)
	var host := FakeHost.new()
	host.cloud = {"mat": "frost", "d": 1.0}
	var kit := ElementExposure.new(host)
	var m := _actor()
	m.statuses.wet = [1.0, 5.0]
	kit.step(m, DT)
	check((m.statuses as Dictionary).has("freeze") and is_equal_approx(float(m.statuses.freeze[1]), freeze), "a wet monster freezes solid in frost gas for freeze_wet s")
	check(not (m.statuses as Dictionary).has("wet") and host.combos_shown == ["freeze"], "its water is ice now, and it shows")
	var boss := _actor()
	boss.boss = true
	boss.statuses.wet = [1.0, 5.0]
	kit.step(boss, DT)
	check(not (boss.statuses as Dictionary).has("freeze"), "a boss never freezes")
	# on an ice pool: a monster freezes, the hero only slips (his freeze_on is frost gas)
	var ice := _host_with_pool("frost")
	var on_ice := _actor()
	on_ice.statuses.wet = [1.0, 5.0]
	ElementExposure.new(ice).step(on_ice, DT)
	check((on_ice.statuses as Dictionary).has("freeze"), "a wet monster freezes on ice")
	var hero := _actor("hero")
	hero.statuses.wet = [1.0, 5.0]
	ElementExposure.new(_host_with_pool("frost")).step(hero, DT)
	check(not (hero.statuses as Dictionary).has("freeze") and (hero.statuses as Dictionary).has("slip"), "a wet hero on ice slips and does not freeze")


func test_burrowed_and_airborne_skip() -> void:
	var air_above := float(ElementRules.data().exposure.air_above)
	for pick: Array in [["burrowed", true, true], ["alt", air_above + 1.0, true], ["alt", air_above - 1.0, false]]:
		var host := _host_with_pool("lava")
		var m := _actor()
		m[pick[0]] = pick[1]
		var met := _run(ElementExposure.new(host), m, 1.0)
		if pick[2]:
			check(met.skipped and is_zero_approx(float(m.hurt)) and host.asked_gas.is_empty(), "%s %s: no pool or gas reaches it" % [pick[0], str(pick[1])])
		else:
			check(not met.skipped and float(m.hurt) > 0.0, "%s %s: low enough to burn" % [pick[0], str(pick[1])])
	var dead := _actor()
	dead.hp = 0.0
	check(ElementExposure.new(_host_with_pool("lava")).step(dead, DT).skipped, "a dead one feels nothing")


func test_exempt_and_warded() -> void:
	var host := _host_with_pool("void")
	host.exempt_from = "void"
	var hero := _actor("hero")
	var met := _run(ElementExposure.new(host), hero, 1.0)
	check((met.medium as Dictionary).is_empty() and not met.maddening and met.style == "void", "exempt: nothing of the void, not its pull or madness")
	check(is_zero_approx(float(hero.hurt)) and (hero.statuses as Dictionary).is_empty(), "exempt: no hurt, no silence")
	var warded := _host_with_pool("lava")
	warded.ward = "lava"
	var hero2 := _actor("hero")
	var met2 := _run(ElementExposure.new(warded), hero2, 1.0)
	check(is_zero_approx(float(hero2.hurt)) and (hero2.statuses as Dictionary).is_empty(), "warded against lava: no hurt, no burn")
	check((met2.medium as Dictionary).has("slow"), "warded: the lava still slows him")
	var burn_ward := _host_with_pool("lava")
	burn_ward.ward = "burn"
	var hero3 := _actor("hero")
	_run(ElementExposure.new(burn_ward), hero3, 1.0)
	check(float(hero3.hurt) > 0.0 and not (hero3.statuses as Dictionary).has("burn"), "warded against burning: the lava hurts, no burn")


func test_gas_sampling_from_the_data() -> void:
	var host := FakeHost.new()
	var kit := ElementExposure.new(host)
	kit.step(_actor("hero"), DT)
	kit.step(_actor(), DT)
	var hero: Dictionary = _profile("hero")
	var mob: Dictionary = _profile("monster")
	var want_hero := float(hero.gas_body) * (host.world_scale() if bool(hero.gas_body_crypt_px) else 1.0) + float(hero.gas_pad)
	var want_mob := float(mob.gas_body) * (host.world_scale() if bool(mob.gas_body_crypt_px) else 1.0) + float(mob.gas_pad)
	check(is_equal_approx(float(host.asked_gas[0][0]), want_hero) and int(host.asked_gas[0][1]) == int(hero.gas_samples), "the hero breathes at %.1f px over %d points" % [want_hero, int(hero.gas_samples)])
	check(is_equal_approx(float(host.asked_gas[1][0]), want_mob) and int(host.asked_gas[1][1]) == int(mob.gas_samples), "a monster at %.1f px over %d points" % [want_mob, int(mob.gas_samples)])
	# the story worlds' numbers (hero 22 x 1.5 + 24, monsters 18 + 24 = the Frostgruft's old 42)
	check(is_equal_approx(want_hero, 57.0) and is_equal_approx(want_mob, 42.0), "the old radii are kept")


func test_pull_madness_blind_vision() -> void:
	var host := _host_with_pool("void")
	var m := _actor()
	var met := ElementExposure.new(host).step(m, DT)
	check((met.medium as Dictionary).get("centre") == host.centre, "the void pulls to the host's centre")
	check(met.maddening and (m.statuses as Dictionary).has("mad"), "the void maddens a monster (status mad)")
	var hero := _actor("hero")
	var met_hero := ElementExposure.new(_host_with_pool("void")).step(hero, DT)
	check(met_hero.maddening and not (hero.statuses as Dictionary).has("mad") and (hero.statuses as Dictionary).has("silence"), "the hero's WAHN runs on his own clock (own_clock), his silence is put on")
	var steam := FakeHost.new()
	steam.cloud = {"mat": "steam", "d": 1.0}
	var rule := ElementRules.gas("steam")
	var met_gas := ElementExposure.new(steam).step(_actor(), DT)
	check(met_gas.gas_mat == "steam" and is_equal_approx(float(met_gas.blind), float(rule.blind_shots)) and is_equal_approx(float(met_gas.vision), float(rule.vision)), "steam blinds its shots and closes the view")
	var thin := FakeHost.new()
	thin.cloud = {"mat": "steam", "d": ElementRules.dense_from() * 0.5}
	check(ElementExposure.new(thin).step(_actor(), DT).gas_mat == "", "a thin wisp is clean air")


func test_empty_host() -> void:
	var kit := ElementExposure.new()
	check(kit.step({}, DT).skipped, "an empty host (the contract's defaults) has no living creatures")
	check(kit.profile_of("nobody") == _profile("monster"), "an unknown profile is the monster's")


func test_madness_split() -> void:
	var rules := ElementRules.data()
	check(not rules.has("madness") and not rules.has("gefuege") and rules.has("exposure"), "element_rules.json keeps physics only")
	check(not MadnessRules.madness().is_empty() and int(MadnessRules.gefuege().get("cap", 0)) > 0, "madness_rules.json holds madness and gefuege")
	check(ElementRules.madness() == MadnessRules.madness() and ElementRules.mad_rule(2.0) == MadnessRules.mad_rule(2.0), "ElementRules forwards")
	var m := {}
	check(ElementRules.madden(m, 1.5, []) and is_equal_approx(float(m.mad_t), 1.5), "madden through the forwarder")
	check(not ElementRules.madden({}, 1.5, MadnessRules.madness().get("immune_tags", ["void"])), "the void's own cannot go mad")
	check(ElementRules.void_mind(str(MadnessRules.madness().immune_class), str(MadnessRules.madness().immune_spec)), "void_mind forwards")
