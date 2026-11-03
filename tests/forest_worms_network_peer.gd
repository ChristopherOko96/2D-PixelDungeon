extends "res://tests/necro_blood_network_peer.gd"
## Two real ENet peers; ordinary R input, primitive snapshots and local rig lookup.
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var host := "--ring-host" in args
	var game := Game.new()
	game.name="Main"
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path="user://forest_network_test.json"
	game.session_bind_ip="127.0.0.1"
	game.address_input.text="127.0.0.1"
	game.port_input.text=args[args.find("--ring-port")+1]
	if host: game._host_session()
	else: game._join_session()
	var started := false
	var ready_at := -1
	var clock := -1
	var kinds := {}
	var materials := {}
	var flight := false
	var own_input := false
	var deadline := Time.get_ticks_msec()+50000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if host and not started and game.phase=="lobby" and game.players.size()==2:
			# Allow the admitted client's normal profile exchange to finish,
			# like the existing Necromancer network fixture.
			if ready_at<0: ready_at=Time.get_ticks_msec()
			if Time.get_ticks_msec()-ready_at<500: continue
			game._begin_run()
			game.hordes.enabled=false
			game.enemies.clear()
			game.bullets.clear()
			game.talent_combat.reset(44)
			game.current_layout={"id":"forest-network","template_id":"forest-network","generator_version":4,"world_size":[1408,704],"tile_size":32,"play_bounds":[32,32,1344,640],"obstacles":[],"exits":[],"boss":false,"render_style":"classic_quiet","decoration_enabled":false}
			game._room_layout_revision+=1
			for id: int in game.players:
				game.players[id].class_id="archer"
				game.players[id].pos=Vector2(300 if id==1 else 360,300)
				game.players[id].invulnerable=99
				var ranks := {}
				for talent: String in game.talent_combat.data.classes.archer.specs[2].talents: ranks[talent]=1
				var extra := 29-ranks.size()
				for talent: String in ranks:
					var add := mini(extra,int(game.talent_combat.data.talents[talent].ranks)-1)
					ranks[talent]=int(ranks[talent])+add
					extra-=add
				game.talent_combat.set_build(id,{"class":"archer","level":30,"ranks":ranks,"bar":["beast_6","beast_7","beast_11"]})
				game.talent_combat.runtime(id).res=100
			var enemy: Dictionary = game._create_enemy("skelet",Vector2(560,300))
			enemy.hp=5000
			enemy.max_hp=5000
			enemy.speed=0
			game.enemies.append(enemy)
			game._broadcast_state(true)
			started=true
		var state: Dictionary = game.state
		if str(state.get("room_layout",{}).get("id",""))!="forest-network": continue
		if clock<0: clock=Time.get_ticks_msec()
		var age := Time.get_ticks_msec()-clock
		game.scripted_target=Vector2(560,300)
		game.scripted_skills=(1<<game.talent_combat.ULT_BIT) if age>300 and age<700 else 0
		for pet: Dictionary in state.get("talents",{}).get("pets",[]):
			if str(pet.kind) not in ["poison_worm","fire_worm"]: continue
			kinds[str(pet.kind)]=true
			check(str(pet.rig)==str(pet.kind),"canonical worm rig in snapshot")
			check(not preload("res://src/rig/rig_library.gd").shared().rig(str(pet.rig)).is_empty(),"receiving process resolves real rig")
			if int(pet.owner)==game.multiplayer.get_unique_id(): own_input=true
		for zone: Dictionary in state.get("boss_zones",[]):
			if str(zone.st) in ["poison","fire"] and float(zone.r)>=96: materials[str(zone.st)]=true
		flight=flight or state.get("talents",{}).get("events",[]).any(func(e:Dictionary)->bool:return str(e.kind)=="forest_spit")
		if age>(6200 if host else 5500): break
	check(kinds.size()==2,"both worm species replicate")
	check(materials.size()==2,"both large existing liquid materials replicate")
	check(flight,"spit flight event replicates")
	check(own_input,"own ordinary R input creates owned summons on host")
	var result := {"passed":failures.is_empty(),"role":"host" if host else "client","failures":failures,"species":kinds,"materials":materials,"flight":flight,"own_r_input":own_input,"scope":"two real local ENet processes, controlled fixture; not LAN/performance"}
	FileAccess.open(args[args.find("--ring-result")+1],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game._leave_session()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
