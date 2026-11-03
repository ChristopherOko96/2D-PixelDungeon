extends "res://tests/curse_rework_test.gd"
## Real temporary summons, severable rigs, delayed spit, actual material and expiry.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos":Vector2(300,240),"class_id":"archer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout = {"id":"forest-worms","tile_size":32,"play_bounds":[0,0,1408,704],"world_size":[1408,704],"obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	_setup(d.talents.beast_14)
	game.boss_moves.zones.clear()
	check(_cast(d.talents.beast_14),"forest ultimate casts")
	var worms: Array = tc.pets.filter(func(p:Dictionary)->bool:return str(p.kind) in ["poison_worm","fire_worm"])
	check(worms.size()==2,"R summons both approved worm species")
	if worms.size()==2:
		check(worms.all(func(p:Dictionary)->bool:return p.parts.size()==8 and is_equal_approx(float(p.life),15)),"eight actual body parts and fifteen second life each")
		var foe := _dummy(Vector2(450,240))
		for p: Dictionary in worms: p.timer=0.01
		_tick(0.1)
		check(tc.necromancer.media(tc).is_empty(),"spit must travel before material lands")
		_tick(0.6)
		var pools: Array = tc.necromancer.media(tc).filter(func(z:Dictionary)->bool:return z.has("forest_worm"))
		check(pools.size()==2 and pools.all(func(z:Dictionary)->bool:return float(z.radius)>=96 and int(z.fed_by)==1),"both leave large actual owned pools")
		check(pools.any(func(z:Dictionary)->bool:return str(z.style)=="fire") and pools.any(func(z:Dictionary)->bool:return str(z.style)=="poison"),"distinct existing fire and poison materials")
		var hp := float(foe.hp)
		game.boss_moves.update(1)
		check(float(foe.hp)<hp,"pools damage an actual enemy")
		for n in range(5):
			for pet: Dictionary in worms: tc.forest_summons.spit(tc,pet,foe)
		tc.forest_summons.step(tc,0.5)
		var live_pools: Array = tc.necromancer.media(tc).filter(func(z:Dictionary)->bool:return z.has("forest_worm") and tc.necromancer._live(z))
		check(live_pools.size()<=6 and live_pools.size()>0,"rapid re-spits cannot exceed three live pools per species")
		game.boss_moves.zones.clear()
		# Like an actual room handoff, replace the layout snapshot so the
		# shared pool/navigation cache sees the newly authored wall.
		game.current_layout=game.current_layout.duplicate(true)
		game.current_layout.obstacles=[[400,0,16,704]]
		for pet: Dictionary in worms: tc.forest_summons.spit(tc,pet,foe)
		tc.forest_summons.step(tc,0.5)
		check(tc.necromancer.media(tc).all(func(z:Dictionary)->bool:return float(z.pos.x)<400),"landing stays on caster side of first wall")
		hp=float(foe.hp)
		for z: Dictionary in game.boss_moves.zones:
			print("WORM_WALL_POOL ",z.pos," in=",game.boss_moves._in_pool(z,foe.pos,foe.radius)," blocked=",tc._blocked(z.pos,foe.pos,1))
		game.boss_moves.update(1)
		check(float(foe.hp)==hp,"large pool never damages across wall")
		game.current_layout.obstacles=[]
		game.boss_moves.zones.clear()
		tc.forest_summons.spit(tc,worms[0],foe)
		game.players[1].hp=0
		tc.forest_summons.step(tc,0.5)
		check(game.boss_moves.zones.is_empty(),"dead caster cannot finish spawning a field")
		game.players[1].hp=100
		_tick(15.2)
		check(not tc.pets.any(func(p:Dictionary)->bool:return str(p.kind) in ["poison_worm","fire_worm"] and float(p.hp)>0),"both temporary summons expire")
		check(not tc.permanent_pet(1).is_empty(),"original permanent companion is preserved")
	game.queue_free()
	await process_frame
	print("FOREST_WORMS checked=%d failures=%d"%[checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
