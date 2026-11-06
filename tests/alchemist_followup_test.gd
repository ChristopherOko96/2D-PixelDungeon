extends "res://tests/alchemist_traps_test.gd"
## Actual regression: visible liquid, elemental ground spills, steam pursuit and live pet switch.
const PoolPaint = preload("res://src/vfx/pool_paint.gd")
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos":Vector2(300,240),"class_id":"archer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout = {"id":"followup-test","tile_size":32,"play_bounds":[0,0,1600,800],"world_size":[1600,800],"obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	check(str(PoolPaint.settings().materials.poison.get("look","liquid")) == "liquid", "poison presents a liquid surface rather than miasma")
	for pair: Array in [["trapper_5","fire"],["trapper_7","ice"]]:
		prepare_case()
		var at := Vector2(470,240)
		put(str(pair[0]),at)
		open_all(at)
		check(game.boss_moves.zones.any(func(z: Dictionary) -> bool: return str(z.style)==str(pair[1]) and float(z.timer)>0), "element capsule leaves real "+str(pair[1])+" ground medium")
	prepare_case()
	var foe: Dictionary = game._create_enemy("skelet",Vector2(500,240))
	foe.hp = 5000
	foe.max_hp = 5000
	foe.speed = 80
	foe.aggro = true
	foe.aggro_target = 1
	game.enemies.append(foe)
	game.elements.add_gas("steam",foe.pos,100,0.4,1)
	game.elements.update(0.05)
	check(float(foe.get("sight_blind_s",0)) >= 2.9,"actual steam exposure applies three seconds of lost sight")
	var start: Vector2 = foe.pos
	game._simulate_enemies(0.05)
	check(Vector2(foe.pos)==start and int(foe.get("aggro_target",-1))==-1,"blinded enemy drops focus and stops chasing")
	game.elements.clouds.clear()
	for n in range(20): game._simulate_enemies(0.1)
	check(Vector2(foe.pos)==start,"sight remains lost after leaving steam for the remaining three seconds")
	for n in range(15): game._simulate_enemies(0.1)
	game.players[1].pos = start-Vector2(60,0) # Re-enter its ordinary notice radius.
	game._simulate_enemies(0.05)
	check(float(foe.get("sight_blind_s",0))<=0 and int(foe.get("aggro_target",-1))==1,"enemy can see and reacquire normally after blindness expires")
	game.enemies.clear()
	tc.reset(7)
	var build := {"class":"archer","level":30,"ranks":{"beast_1":1},"bar":["beast_1"],"companion":"wolf"}
	tc.set_build(1,build)
	tc.runtime(1).res = 100
	if tc.permanent_pet(1).is_empty(): tc.cast(1,"beast_1")
	check(str(tc.permanent_pet(1).kind)=="wolf","initial build owns the selected wolf")
	build.companion = "bear"
	tc.set_build(1,build,true)
	tc.runtime(1).gcd = 0.0
	tc.runtime(1).cds.beast_1 = 0.0
	check(str(tc.permanent_pet(1).kind)=="wolf","selection alone does not silently replace live pet")
	var before := float(tc.runtime(1).res)
	check(tc.cast(1,"beast_1"),"reactivation after selecting bear can replace live wolf")
	check(str(tc.permanent_pet(1).kind)=="bear" and tc._own_pets(1).size()==1,"exactly the selected bear is present after reactivation")
	check(is_equal_approx(before-float(tc.runtime(1).res),tc.cost_of(tc.runtime(1),"beast_1")) and float(tc.runtime(1).cds.beast_1)>0,"replacement pays real cost and cooldown")
	tc.runtime(1).gcd = 0
	tc.runtime(1).cds.beast_1 = 0
	check(not tc.cast(1,"beast_1"),"same selected live kind cannot be repeatedly resummoned for free healing")
	game.queue_free()
	await process_frame
	print("ALCHEMIST_FOLLOWUP checked=%d failures=%d" % [checked,failures.size()])
	quit(1 if not failures.is_empty() else 0)
