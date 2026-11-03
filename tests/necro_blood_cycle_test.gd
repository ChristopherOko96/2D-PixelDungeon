extends "res://tests/soul_guardian_commands_test.gd"
## Requested Diener cycle: explicit summons, death marks, finite blood and R gate.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos":Vector2(300,240),"class_id":"necromancer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout = {"id":"blood-cycle","tile_size":32,"play_bounds":[0,0,1408,704],"world_size":[1408,704],"obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	var rt := _setup(d.talents.minion_1)
	check(tc.permanent_pet(1).is_empty(),"learning warrior does not silently summon it")
	if tc.permanent_pet(1).is_empty(): check(_cast(d.talents.minion_1),"warrior has its own paid summon ability")
	var pet: Dictionary = tc.permanent_pet(1)
	check(not pet.is_empty() and not _cast(d.talents.minion_1),"summon cannot duplicate a living warrior")
	game.boss_moves.zones.clear()
	pet.blood = 100.0
	_tick(0.1)
	check(str(pet.kind)=="bone_warrior","full blood waits for R instead of automatic transformation")
	rt = _warrior()
	pet = tc.permanent_pet(1)
	pet.blood = 49.9
	var before := float(rt.res)
	check(not _cast(d.talents.minion_14),"R refuses less than half blood")
	check(is_equal_approx(float(rt.res),before) and not rt.cds.has("minion_14"),"blocked R spends neither souls nor cooldown")
	rt = _warrior()
	pet = tc.permanent_pet(1)
	pet.blood = 50.0
	pet.hp *= 0.7
	var ratio := float(pet.hp)/float(pet.hp_max)
	check(_cast(d.talents.minion_14),"half blood activates R")
	check(str(pet.kind)=="blood_colossus" and is_equal_approx(float(pet.blood),50),"large form keeps actual half gauge")
	check(is_equal_approx(float(pet.hp)/float(pet.hp_max),ratio),"transformation preserves wounded life ratio")
	_tick(2)
	check(absf(float(pet.blood)-40.0)<0.1,"large form visibly consumes five blood per second")
	_tick(9)
	check(str(pet.kind)=="bone_warrior" and float(pet.blood)==0,"spent half gauge returns warrior after ten seconds")
	rt = _warrior()
	pet = tc.permanent_pet(1)
	game.boss_moves.zones.clear()
	var provision_ranks: Dictionary = rt.ranks.duplicate()
	provision_ranks.minion_1 = int(provision_ranks.minion_1)-1
	provision_ranks.minion_13 = 1
	tc.set_build(1,{"class":"necromancer","level":30,"ranks":provision_ranks,"bar":["minion_1","minion_9","minion_5","minion_7"]})
	for source in range(2): tc.necromancer.pool(tc,1,"blood",pet.pos,80,12)
	for frame in range(360): tc.step(1.0/60)
	check(is_equal_approx(float(pet.get("blood",0)),50) and _cast(d.talents.minion_14),"two real sources at sixty Hz reach usable half blood without floating point rejection")
	rt = _warrior()
	pet = tc.permanent_pet(1)
	pet.hp = 0
	check(not _cast(d.talents.minion_14),"R requires the actual living warrior; no replacement giant")
	rt = _setup(d.talents.minion_5)
	game.boss_moves.zones.clear()
	var marked := _dummy(Vector2(410,240))
	var untouched := _dummy(Vector2(800,240))
	check(_cast(d.talents.minion_5,{"target":marked.pos}),"blood mark has its own ability")
	check(marked.get("blood_marks",{}).has("1") and not untouched.get("blood_marks",{}).has("1"),"mark affects only enemies inside target area")
	game._damage_enemy(marked,99999,Vector2.ZERO,1,true,false)
	var pools: Array = tc.necromancer.media(tc).filter(func(z:Dictionary)->bool:return str(z.get("style",""))=="blood" and float(z.get("timer",0))>0)
	check(pools.size()==1 and float(pools[0].radius)>=float(d.meter_px)*2,"marked real death leaves a large existing blood puddle")
	tc.enemy_killed(marked,1)
	check(tc.necromancer.media(tc).size()==pools.size(),"duplicate death cannot pay blood twice")
	game._damage_enemy(untouched,99999,Vector2.ZERO,1,true,false)
	check(tc.necromancer.media(tc).size()==pools.size(),"unmarked death does not produce blood")
	rt = _warrior()
	pet = tc.permanent_pet(1)
	game.boss_moves.zones.clear()
	var source := Vector2(pet.pos)+Vector2(180,0)
	tc.necromancer.pool(tc,1,"blood",source,25,12)
	var start := Vector2(pet.pos)
	_tick(1.2)
	check(Vector2(pet.pos).distance_to(source)<start.distance_to(source) and float(pet.get("blood",0))+float(pet.get("blood_pending",0))>0,"idle warrior walks to nearby blood and automatically absorbs it")
	rt = _setup(d.talents.minion_9)
	check(_cast(d.talents.minion_9),"separate archer summon casts")
	var archers: Array = tc.pets.filter(func(p:Dictionary)->bool:return str(p.kind)=="bone_archer")
	check(archers.size()==2 and archers.all(func(p:Dictionary)->bool:return is_equal_approx(float(p.life),15)),"exactly two archers last fifteen seconds")
	if not archers.is_empty():
		var archer: Dictionary = archers[0]
		var victim := _dummy(Vector2(archer.pos)+Vector2(15,0))
		archer.hp = 0
		tc._step_pets(0.05)
		var hp := float(victim.hp)
		check(hp<float(victim.max_hp),"killed archer deals an actual corpse explosion")
		check(tc.events.any(func(e:Dictionary)->bool:return str(e.kind)=="necro_bones" and str(e.get("talent",""))=="minion_9"),"archer death uses source-part explosion effect")
		tc._step_pets(0.1)
		check(is_equal_approx(float(victim.hp),hp),"dying rig cannot explode a second time")
		var last: Dictionary = archers[-1]
		last.life = 0.01
		victim.pos = last.pos
		var life_before := float(victim.hp)
		tc._step_pets(0.05)
		check(float(victim.hp)<life_before,"fifteen-second expiry also triggers one corpse explosion")
	game.queue_free()
	await process_frame
	print("NECRO_BLOOD_CYCLE checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _warrior() -> Dictionary:
	var rt := _setup(d.talents.minion_14)
	if tc.permanent_pet(1).is_empty():
		tc.cast(1,"minion_1",{"aim":Vector2.RIGHT})
		rt.gcd = 0.0
		rt.res = float(rt.res_max)
	rt.pet_auto = [false,false]
	return rt
