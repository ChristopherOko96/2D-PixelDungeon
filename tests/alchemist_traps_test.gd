extends "res://tests/talent_combat_test.gd"
## Actual host casts, finite shared media, owner-only triggers and boss-safe reactions.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos":Vector2(300,240),"class_id":"archer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout = {"id":"alchemist-test","tile_size":32,"play_bounds":[0,0,1600,800],"world_size":[1600,800],"obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	check(d.talents.trapper_1.name == "Giftköder", "first active is the new poison bait")
	check(d.talents.trapper_11.type == "alchemy_detonate", "sixth active is an explicit chain detonator")
	_setup(d.talents.trapper_1)
	check(_cast(d.talents.trapper_1), "paid poison bait cast accepted")
	check(tc.traps.size() == 1, "poison bait creates a physical trap rather than firing a dart")
	test_owner_wall_arming_and_cap()
	test_real_media_reactions_and_shatter()
	test_bait_ordered_detonation_and_ultimate()
	game.queue_free()
	await process_frame
	print("ALCHEMIST_TRAPS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func prepare_case() -> Dictionary:
	var rt := _setup(d.talents.trapper_14)
	for id: String in ["trapper_1","trapper_3","trapper_5","trapper_7","trapper_9","trapper_11"]: rt.ranks[id] = 3
	game.boss_moves.zones.clear()
	game.elements.clouds.clear()
	game.current_layout.obstacles = []
	return rt

func put(id: String, at: Vector2) -> void:
	var rt: Dictionary = tc.runtime(1)
	rt.gcd = 0.0
	rt.cds[id] = 0.0
	rt.res = float(rt.res_max)
	if rt.get("ability_charges",{}).has(id): rt.ability_charges[id].left = 3
	check(tc.cast(1,id,{"target":at,"aim":Vector2.RIGHT}), "host accepts " + id)

func open_all(at: Vector2) -> void:
	tc.alchemist.step(tc,0.51)
	tc.alchemist.detonate(tc,1,at,300)

func test_owner_wall_arming_and_cap() -> void:
	prepare_case()
	var at := Vector2(460,240)
	put("trapper_3",at)
	tc.alchemist.arrow(tc,1,Vector2(350,240),Vector2(600,240))
	check(tc.traps.size() == 1, "fresh capsule cannot trigger before arming")
	tc.alchemist.step(tc,0.51)
	tc.alchemist.arrow(tc,2,Vector2(350,240),Vector2(600,240))
	check(tc.traps.size() == 1, "another player's arrow cannot trigger owned capsule")
	game.current_layout.obstacles = [[400,0,16,800]]
	tc.alchemist.arrow(tc,1,Vector2(350,240),Vector2(600,240))
	check(tc.traps.size() == 1, "arrow cannot trigger through intervening wall")
	game.current_layout.obstacles = []
	tc.alchemist.arrow(tc,1,Vector2(350,240),Vector2(600,240))
	check(tc.traps.is_empty() and game.boss_moves.zones.size() == 1, "swept own arrow opens real water capsule once")
	tc.alchemist.arrow(tc,1,Vector2(350,240),Vector2(600,240))
	check(game.boss_moves.zones.size() == 1, "repeated arrow path cannot duplicate consumed media")
	prepare_case()
	put("trapper_3",at)
	tc.alchemist.step(tc,0.51)
	game._add_bullet(Vector2(400,240),Vector2(600,0),1,1,{"style":"arrow","primary":true,"life":1})
	game._simulate_bullets(0.12)
	check(tc.traps.is_empty() and game.boss_moves.zones.size()==1,"real host bullet simulation invokes capsule collision hook")
	for n in range(8): put("trapper_1",Vector2(430+n*7,390))
	check(tc.traps.size() == 6, "physical traps obey six-per-owner cap")
	tc.room_changed()
	check(tc.traps.is_empty() and tc.alchemist.fields.is_empty() and tc.alchemist.pulses.is_empty(), "room reset forgets pending alchemy")

func test_real_media_reactions_and_shatter() -> void:
	prepare_case()
	var at := Vector2(470,240)
	put("trapper_1",at)
	open_all(at)
	check(game.boss_moves.zones.any(func(z: Dictionary) -> bool: return str(z.style) == "poison" and float(z.timer)>0), "poison is native live medium")
	var victim := _dummy(at)
	var before := float(victim.hp)
	tc.alchemist.step(tc,1)
	check(float(victim.hp) < before and victim.statuses.has("poison"), "live poison field ticks actual rank-scaled damage and status")
	put("trapper_5",at)
	open_all(at)
	check(game.boss_moves.zones.filter(func(z: Dictionary) -> bool: return str(z.style) == "poison").all(func(z: Dictionary) -> bool: return float(z.timer)<=0), "fire consumes native poison instead of overlaying permanent damage")
	tc.alchemist.step(tc,0.01)
	check(tc.alchemist.pulses.all(func(p: Dictionary) -> bool: return str(p.mat)!="poison"), "consumed poison cannot continue ghost ticks while real fire remains")
	prepare_case()
	put("trapper_3",at)
	open_all(at)
	var wet := _dummy(at)
	var boss := _dummy(at+Vector2(0,20),true)
	tc.alchemist.step(tc,1.01)
	check(wet.statuses.has("wet") and boss.statuses.has("wet"),"walking into existing liquid wets actors on actual pool cells")
	put("trapper_7",at)
	open_all(at)
	check(wet.statuses.has("freeze"), "frost freezes an actually wet normal target")
	check(not boss.statuses.has("freeze") and boss.statuses.has("slow"), "boss is slowed and never frozen")
	check(game.boss_moves.zones.any(func(z: Dictionary) -> bool: return str(z.style) == "water" and float(z.get("frozen",0))>0), "water is frozen by existing element reaction")
	before = float(wet.hp)
	put("trapper_9",at)
	open_all(at)
	check(float(wet.hp) < before-15 and not wet.statuses.has("freeze"), "glass shatters frozen targets with bonus damage and consumes freeze")
	prepare_case()
	put("trapper_3",at)
	open_all(at)
	put("trapper_5",at)
	open_all(at)
	check(game.elements.clouds.any(func(c: Dictionary) -> bool: return str(c.mat) == "steam"), "fire on water creates actual steam")
	var hidden := _dummy(at+Vector2(50,0))
	game.current_layout.obstacles = [[490,0,16,800]]
	var hp := float(hidden.hp)
	put("trapper_9",at)
	open_all(at)
	check(float(hidden.hp) == hp, "capsule blast is stopped by a wall")

func test_bait_ordered_detonation_and_ultimate() -> void:
	prepare_case()
	var at := Vector2(470,240)
	put("trapper_1",at)
	tc.alchemist.step(tc,0.51)
	var foe := _dummy(at+Vector2(70,0))
	var boss := _dummy(at+Vector2(70,30),true)
	check(not tc.forced_target(foe).is_empty() and tc.forced_target(boss).is_empty(), "ready poison bait attracts normals but never bosses")
	prepare_case()
	for id: String in ["trapper_5","trapper_7","trapper_1","trapper_3"]: put(id,at)
	tc.alchemist.step(tc,0.51)
	tc.events.clear()
	put("trapper_11",at)
	var order: Array = []
	for e: Dictionary in tc.events:
		if str(e.kind) == "alchemy_burst": order.append(str(e.recipe))
	check(order == ["water","poison","frost","fire"], "detonator uses recipe order independent of placement order")
	check(tc.traps.is_empty(), "chain ignition consumes each own capsule once")
	prepare_case()
	put("trapper_14",at)
	check(tc.alchemist.fields.size() == 1 and game.boss_moves.zones.is_empty(), "ultimate pays once and starts a delayed apparatus")
	tc.alchemist.step(tc,0.4)
	check(game.boss_moves.zones.is_empty(), "ultimate does not place liquid before deployment")
	tc.alchemist.step(tc,0.4)
	check(game.boss_moves.zones.size() == 6, "ultimate deploys six real owned water/poison media")
	tc.alchemist.step(tc,0.8)
	check(game.boss_moves.zones.any(func(z: Dictionary) -> bool: return str(z.style) == "water" and float(z.get("frozen",0))>0), "ultimate frost phase freezes its water")
	tc.alchemist.step(tc,1)
	check(tc.alchemist.fields.is_empty(), "ultimate finishes its phase scheduler exactly once")
	check(game.boss_moves.zones.filter(func(z: Dictionary) -> bool: return str(z.style) == "poison").all(func(z: Dictionary) -> bool: return float(z.timer)<=0), "ultimate final ignition consumes its poison")
