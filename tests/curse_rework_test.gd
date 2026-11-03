extends "res://tests/soul_guardian_commands_test.gd"
## Actual host behavior: multi-target drains, death curses and chasing corpse runners.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos":Vector2(300,240),"class_id":"necromancer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout = {"id":"curse-rework","tile_size":32,"play_bounds":[0,0,1408,704],"world_size":[1408,704],"obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	var rt := _setup(d.talents.curse_9)
	var victims: Array = []
	for at: Vector2 in [Vector2(480,240),Vector2(500,270),Vector2(490,200),Vector2(530,280)]: victims.append(_dummy(at))
	var outside := _dummy(Vector2(620,240))
	var before := float(rt.res)
	check(_cast(d.talents.curse_9),"multi-target blood drain casts")
	check(tc.snapshot().get("blood_links",[]).size()==4,"rank three links four visible targets beyond five and inside eight metres")
	check(is_equal_approx(before-float(rt.res),tc.cost_of(rt,"curse_9")),"one cast pays souls once rather than once per link")
	_tick(0.4)
	check(victims.all(func(e:Dictionary)->bool:return float(e.hp)<float(e.max_hp)) and float(outside.hp)==float(outside.max_hp),"all linked targets drain while outside target remains untouched")
	game._damage_enemy(victims[0],99999,Vector2.RIGHT,1,true,false)
	check(game.bullets.any(func(b:Dictionary)->bool:return bool(b.get("curse_spirit",false))),"linked death releases a real moving curse projectile")
	var flights: int = game.bullets.filter(func(b:Dictionary)->bool:return bool(b.get("curse_spirit",false))).size()
	tc.enemy_killed(victims[0],1)
	check(game.bullets.filter(func(b:Dictionary)->bool:return bool(b.get("curse_spirit",false))).size()==flights,"repeated death callback cannot duplicate curse flights")
	_tick(0.9)
	check(outside.get("necro_curses",{}).has("1"),"death curse flies to another enemy and actually curses it")
	rt = _setup(d.talents.curse_9)
	var hidden := _dummy(Vector2(400,240))
	game.current_layout.obstacles = [[350,0,16,704]]
	_cast(d.talents.curse_9)
	check(tc.snapshot().blood_links.is_empty() and float(hidden.hp)==float(hidden.max_hp),"multi-drain cannot attach through a wall")
	game.current_layout.obstacles = []
	rt = _setup(d.talents.curse_7)
	game.boss_moves.zones.clear()
	check(_cast(d.talents.curse_7),"real poison field casts")
	var dead := _dummy(Vector2(420,240))
	game._damage_enemy(dead,99999,Vector2.RIGHT,1,true,false)
	var runners: Array = tc.pets.filter(func(p:Dictionary)->bool:return bool(p.get("plague_runner",false)))
	check(runners.size()==1,"death inside own real poison pool raises one skeletal runner")
	if not runners.is_empty():
		var runner: Dictionary = runners[0]
		check(str(runner.rig)=="skeleton" and not bool(runner.permanent),"raised runner uses actual skeleton body-part rig")
		var foe := _dummy(Vector2(runner.pos)+Vector2(90,0))
		var start := Vector2(runner.pos)
		_tick(0.25)
		check(Vector2(runner.pos).distance_to(foe.pos)<start.distance_to(foe.pos),"runner actively chases nearby enemy")
		var hp := float(game.players[1].hp)
		_tick(0.8)
		check(float(foe.hp)<float(foe.max_hp) and (float(runner.hp)<=0 or float(runner.life)<=0),"contact triggers the runner's actual corpse explosion")
		check(float(game.players[1].hp)==hp,"friendly corpse burst does not damage its hero")
		check(tc.events.any(func(e:Dictionary)->bool:return str(e.kind)=="necro_bones"),"runner explosion emits rigged bone fragments")
	rt = _setup(d.talents.curse_7)
	game.boss_moves.zones.clear()
	_cast(d.talents.curse_7)
	for n in range(9):
		var foe := _dummy(Vector2(410+n,240))
		game._damage_enemy(foe,99999,Vector2.RIGHT,1,true,false)
	check(tc.pets.filter(func(p:Dictionary)->bool:return bool(p.get("plague_runner",false))).size()==6,"skeletal runner population is bounded at six per owner")
	var prior: int = tc.pets.size()
	var killed_by_runner := _dummy(Vector2(420,240))
	tc._pet_source = 999
	game._damage_enemy(killed_by_runner,99999,Vector2.RIGHT,1,true,false)
	tc._pet_source = -1
	check(tc.pets.size()==prior,"runner secondary kills cannot recursively raise a new army")
	tc.necromancer.consume_poison(tc,1,Vector2(420,240),200,3)
	var no_source := _dummy(Vector2(420,240))
	game._damage_enemy(no_source,99999,Vector2.RIGHT,1,true,false)
	check(tc.pets.size()==prior,"consumed physical poison cannot raise invisible-field minions")
	var boss := _dummy(Vector2(420,240),true)
	game._damage_enemy(boss,99999,Vector2.RIGHT,1,true,false)
	check(tc.pets.size()==prior,"bosses are never converted into runners")
	game.queue_free()
	await process_frame
	print("CURSE_REWORK checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
