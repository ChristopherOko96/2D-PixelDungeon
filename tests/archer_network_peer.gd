extends "res://tests/necro_blood_network_peer.gd"
## Ordinary validated inputs across two real ENet processes, controlled arena.
func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	var host: bool="--ring-host" in args
	var game:=Game.new()
	game.name="Main"
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path="user://archer_network_fixture.json"
	game.session_bind_ip="127.0.0.1"
	game.address_input.text="127.0.0.1"
	game.port_input.text=args[args.find("--ring-port")+1]
	if host: game._host_session()
	else: game._join_session()
	var started:=false
	var ready_at:=-1
	var clock:=-1
	var marked:=false
	var charged:=false
	var pinned:=false
	var boss_safe:=true
	var trap_charges:={}
	var traps_seen:=false
	var diagnosed:=false
	var deadline:=Time.get_ticks_msec()+50000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if host and not started and game.phase=="lobby" and game.players.size()==2:
			if ready_at<0: ready_at=Time.get_ticks_msec()
			if Time.get_ticks_msec()-ready_at<500: continue
			game._begin_run()
			game.hordes.enabled=false
			game.enemies.clear()
			game.bullets.clear()
			game.talent_combat.reset(44)
			game.current_layout={"id":"archer-network","template_id":"archer-network","generator_version":4,"world_size":[1408,800],"tile_size":32,"play_bounds":[32,32,1344,736],"obstacles":[[1000,32,32,736]],"exits":[],"boss":false,"render_style":"classic_quiet","decoration_enabled":false}
			game._room_layout_revision+=1
			for id: int in game.players:
				game.players[id].class_id="archer"
				game.players[id].pos=Vector2(300,300 if id==1 else 550)
				game.players[id].invulnerable=99
				var spec: Dictionary=game.talent_combat.data.classes.archer.specs[0 if id==1 else 1]
				var ranks:={}
				for talent: String in spec.talents: ranks[talent]=1
				var extra:=29-ranks.size()
				for talent: String in ranks:
					var add:=mini(extra,int(game.talent_combat.data.talents[talent].ranks)-1)
					ranks[talent]=int(ranks[talent])+add
					extra-=add
				game.talent_combat.set_build(id,{"class":"archer","level":30,"ranks":ranks,"bar":["sniper_5"] if id==1 else ["trapper_3"]})
				game.talent_combat.runtime(id).res=100
			for n in range(3):
				var enemy: Dictionary=game._create_enemy("skelet",Vector2(440+n*64,300))
				enemy.hp=5000
				enemy.max_hp=5000
				enemy.speed=0
				enemy.boss=n==2
				game.enemies.append(enemy)
			game._broadcast_state(true)
			started=true
		var state: Dictionary=game.state
		if str(state.get("room_layout",{}).get("id",""))!="archer-network": continue
		if clock<0:
			clock=Time.get_ticks_msec()
			# Room generation and cold native-rig caches precede the input trial.
			# Give the actual replicated combat trial its own bounded deadline.
			deadline=clock+30000
		var age:=Time.get_ticks_msec()-clock
		if age>4500 and not diagnosed:
			diagnosed=true
			print("ARCHER_NET_DIAG role=",host," phase=",game.phase," pause=",game.pause_open," transition=",game.is_transitioning()," command=",game.commands.get(1,{})," build=",game.talent_combat.runtime(1))
		game.scripted_target=Vector2(900,300) if host else Vector2(520,620)
		if host:
			game.scripted_skills=(1<<game.talent_combat.BAR_BIT) if age>300 and age<500 else ((1<<game.talent_combat.ULT_BIT) if age>1800 and age<2500 else 0)
		else:
			# Distinct presses respect the real one-second global cooldown.
			var place: bool=(age>800 and age<1000) or (age>2100 and age<2300) or (age>3400 and age<3600)
			game.scripted_skills=(1<<game.talent_combat.BAR_BIT) if place else 0
		var talents: Dictionary=state.get("talents",{})
		marked=marked or not talents.get("archer_marks",[]).is_empty()
		charged=charged or talents.get("charges",[]).any(func(c:Dictionary)->bool:return str(c.talent)=="sniper_14" and float(c.power)>0.15 and int(c.owner)==1)
		pinned=pinned or talents.get("archer_pins",[]).size()>=2
		traps_seen=traps_seen or talents.get("traps",[]).size()>=3
		for p: Dictionary in state.get("players",{}).values():
			for slot: Dictionary in p.get("talents",{}).get("slots",[]):
				if str(slot.id)=="trapper_3": trap_charges[str(int(slot.get("charges_left",-1)))]=true
		if host:
			for enemy: Dictionary in game.enemies:
				if bool(enemy.get("boss",false)): boss_safe=boss_safe and not enemy.has("marksman_pin")
		if age>(6500 if host else 5800):
			if not host: break
			# Local harness lifetime only: keep the real host alive while a cold
			# client finishes inspecting its snapshots and writes its receipt.
			var result_path: String=args[args.find("--ring-result")+1]
			if FileAccess.file_exists(result_path.get_base_dir().path_join("client.json")) or age>20000: break
	check(marked,"per-owner one-use marks replicate")
	check(charged,"host R hold produces a paid charge snapshot")
	check(pinned,"normal line victims are carried and pinned in snapshots")
	check(boss_safe,"boss never receives pin")
	check(traps_seen and trap_charges.has("0"),"client trap inputs consume three actual charges")
	var result:={"passed":failures.is_empty(),"role":"host" if host else "client","failures":failures,"marks":marked,"charge":charged,"pins":pinned,"boss_safe":boss_safe,"traps":traps_seen,"charge_counts":trap_charges,"scope":"two real local ENet processes, controlled fixture; not LAN/performance"}
	FileAccess.open(args[args.find("--ring-result")+1],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game._leave_session()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
