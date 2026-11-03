extends SceneTree
## Two admitted real ENet peers: host blood/form authority and ordinary curse input.
const Game = preload("res://src/game.gd")
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); printerr("NECRO_NET_FAIL: ", label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var host := "--ring-host" in args
	var game := Game.new()
	game.name = "Main"
	root.add_child(game)
	await process_frame
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://necro_blood_network.json"
	game.session_bind_ip = "127.0.0.1"
	game.address_input.text = "127.0.0.1"
	game.port_input.text = args[args.find("--ring-port") + 1]
	game.requested_seed = 4242
	if host: game._host_session()
	else: game._join_session()
	var started := false
	var ready_at := -1
	var clock := -1
	var blood_seen := false
	var visible_uptake_seen := false
	var large_seen := false
	var stored_full_seen := false
	var draining_seen := false
	var poison_seen := false
	var command_seen := false
	var link_seen := false
	var multi_seen := false
	var curse_flight_seen := false
	var curse_death_sent := false
	var ritual_seeded := false
	var ritual_killed := false
	var monster_seen := false
	var bone_charge_seen := false
	var curse_wave_seen := false
	var brood_seen := false
	var whirl_seen := false
	var link_from := Vector2.INF
	var link_moved := false
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if host and not started and game.phase == "lobby" and game.players.size() == 2:
			if ready_at < 0: ready_at = Time.get_ticks_msec()
			if Time.get_ticks_msec() - ready_at < 500: continue
			game._begin_run()
			game.hordes.enabled = false
			game.enemies.clear()
			game.bullets.clear()
			game.boss_moves.zones.clear()
			game.talent_combat.reset(33)
			game.current_layout = {"id": "necro-network", "template_id": "necro-network", "generator_version": 4, "world_size": [1408, 704], "tile_size": 32, "play_bounds": [32, 32, 1344, 640], "obstacles": [], "exits": [], "boss": false, "render_style": "classic_quiet", "decoration_enabled": false}
			game._room_layout_revision += 1
			for id: int in game.players:
				game.players[id].class_id = "necromancer"
				game.players[id].pos = Vector2(300 if id == 1 else 650, 300)
				game.players[id].invulnerable = 99.0
				var tc = game.talent_combat
				var spec: Dictionary = tc.data.classes.necromancer.specs[0 if id == 1 else 1]
				var ranks := {}
				for talent: String in spec.talents: ranks[talent] = 1
				var remaining: int = tc.Rules.points_total(tc.data, 30) - ranks.size()
				for talent: String in spec.talents:
					var extra := mini(remaining, int(tc.data.talents[talent].ranks) - 1)
					ranks[talent] = int(ranks[talent]) + extra
					remaining -= extra
				tc.set_build(id, {"class": "necromancer", "level": 30, "ranks": ranks, "bar": ["minion_1", "minion_9", "minion_5"] if id == 1 else ["curse_1", "curse_7", "curse_9"]})
				tc.runtime(id).res = 100.0
				if id!=1: tc.runtime(id).pet_auto = [false,false]
				if id == 1:
					tc.cast(id,"minion_1",{"aim":Vector2.RIGHT})
					var pet: Dictionary = tc.permanent_pet(id)
					for n in range(4): tc.necromancer.pool(tc, id, "blood", pet.pos, 70, 20)
			var enemy: Dictionary = game._create_enemy("skelet", Vector2(735, 300))
			enemy.hp = 5000.0
			enemy.max_hp = 5000.0
			enemy.speed = 0.0
			game.enemies.append(enemy)
			for at: Vector2 in [Vector2(650,380),Vector2(810,300)]:
				var extra: Dictionary = game._create_enemy("skelet",at)
				extra.hp = 5000
				extra.max_hp = 5000
				extra.speed = 0
				game.enemies.append(extra)
			game._broadcast_state(true)
			started = true
		var state: Dictionary = game.state
		if str(state.get("room_layout", {}).get("id", "")) != "necro-network": continue
		if clock < 0: clock = Time.get_ticks_msec()
		var elapsed := Time.get_ticks_msec() - clock
		game.scripted_target = Vector2(735, 300)
		game.scripted_skills = 0
		if not host:
			if elapsed < 300: game.scripted_skills = 1 << game.talent_combat.BAR_BIT
			if elapsed > 1400 and elapsed < 1750: game.scripted_skills = 1 << (game.talent_combat.BAR_BIT + 1)
			if elapsed > 3000 and elapsed < 3400: game.scripted_skills = 1 << (game.talent_combat.BAR_BIT + 2)
			if elapsed > 5000 and elapsed < 5400: game.scripted_skills = 1 << game.talent_combat.ULT_BIT
			if elapsed > 8100 and elapsed < 8450: game.scripted_skills = 1 << game.talent_combat.PET_BIT
			if elapsed > 9400 and elapsed < 9750: game.scripted_skills = 1 << (game.talent_combat.PET_BIT+1)
		elif elapsed > 10500 and elapsed < 10800: game.scripted_skills = 1 << game.talent_combat.ULT_BIT
		elif elapsed > 12000 and elapsed < 12400: game.scripted_skills = 1 << game.talent_combat.PET_BIT
		elif elapsed > 13200 and elapsed < 13600: game.scripted_skills = 1 << (game.talent_combat.PET_BIT+1)
		if host and elapsed > 3000 and elapsed < 3600 and not game.enemies.is_empty(): game.enemies[0].pos = Vector2(735,300+sin(float(elapsed)*0.002)*35.0)
		if host and elapsed>3600 and not curse_death_sent:
			curse_death_sent = true
			game._damage_enemy(game.enemies[0],99999,Vector2.RIGHT,1,true,false)
		if host and elapsed>5800 and not ritual_seeded:
			ritual_seeded = true
			var victim: Dictionary = game._create_enemy("skelet",Vector2(735,300))
			victim.hp = 5000
			victim.max_hp = 5000
			victim.speed = 0
			victim.ritual_probe = true
			game.enemies.append(victim)
		if host and elapsed>6800 and not ritual_killed:
			ritual_killed = true
			var client_owner: int = game.players.keys().filter(func(id:Variant)->bool:return int(id)!=1)[0]
			for victim: Dictionary in game.enemies:
				if bool(victim.get("ritual_probe",false)): game._damage_enemy(victim,99999,Vector2.RIGHT,client_owner,true,false)
		multi_seen = multi_seen or state.get("talents",{}).get("blood_links",[]).filter(func(l:Dictionary)->bool:return str(l.kind)=="blood").size()>=2
		bone_charge_seen = bone_charge_seen or not state.get("talents",{}).get("bone_charges",[]).is_empty()
		curse_wave_seen = curse_wave_seen or state.get("talents",{}).get("events",[]).any(func(e:Dictionary)->bool:return str(e.kind)=="necro_bone_wave")
		curse_flight_seen = curse_flight_seen or state.get("bullets",[]).any(func(b:Dictionary)->bool:return str(b.get("style",""))=="curse_spirit")
		for p: Dictionary in state.get("talents", {}).get("pets", []):
			monster_seen = monster_seen or (str(p.get("kind",""))=="curse_colossus" and str(p.get("rig",""))=="curse_colossus")
			brood_seen = brood_seen or (str(p.get("kind",""))=="curse_spawn" and str(p.get("rig",""))=="curse_spawn")
			blood_seen = blood_seen or (float(p.get("blood", 0)) > 0 and float(p.get("blood", 0)) < 100)
			if float(p.get("blood_pending",0))>0 and float(p.get("blood_wait",1))<=0 and float(p.get("blood_pool_r",0))>0:
				visible_uptake_seen = visible_uptake_seen or state.get("boss_zones",[]).any(func(z:Dictionary)->bool:return str(z.get("st",""))=="blood" and Vector2(z.x,z.y).distance_to(Vector2(p.blood_x,p.blood_y))<1)
			large_seen = large_seen or (str(p.get("rig", "")) == "blood_colossus" and float(p.get("blood_form", 0)) > 0)
			stored_full_seen = stored_full_seen or (str(p.get("kind",""))=="bone_warrior" and float(p.get("blood",0))>=float(game.talent_combat.necromancer.cfg.blood.min_activation))
			draining_seen = draining_seen or (str(p.get("kind",""))=="blood_colossus" and float(p.get("blood",0))<99 and float(p.get("blood",0))>1)
			whirl_seen = whirl_seen or not p.get("whirl",{}).is_empty()
		for l: Dictionary in state.get("talents",{}).get("blood_links",[]):
			if str(l.kind) != "blood": continue
			link_seen = true
			var point := Vector2(l.tx,l.ty)
			if not link_from.is_finite(): link_from = point
			if point.distance_to(link_from)>5: link_moved = true
		for z: Dictionary in state.get("boss_zones", []): poison_seen = poison_seen or str(z.get("st", "")) == "poison"
		for e: Dictionary in state.get("talents", {}).get("events", []): command_seen = command_seen or str(e.get("talent", "")) == "bone_stomp"
		if elapsed > (15700 if host else 15200):
			if host:
				for id: Variant in game.talent_combat.runtimes:
					var rt: Dictionary = game.talent_combat.runtime(int(id))
					print("NECRO_NET_RUNTIME ", id, " bar=", rt.bar, " cds=", rt.cds, " resource=", rt.res)
			break
	check(blood_seen, "partial authoritative blood reaches peer")
	check(visible_uptake_seen,"real blood source and rigged uptake endpoints coexist in replicated state")
	check(large_seen, "proper large skeletal form reaches peer")
	check(stored_full_seen and draining_seen,"at least half blood waits for normal R input and then visibly drains on both peers")
	check(poison_seen, "validated client curse creates actual poison")
	check(command_seen, "normal key 5 commands transformed skeleton")
	check(whirl_seen,"normal key 6 starts replicated sustained blade storm")
	check(link_seen and link_moved,"blood connection follows moving target on both real peers")
	check(multi_seen and curse_flight_seen,"multiple drain links and real death curse flight replicate to both peers")
	var result := {"passed": failures.is_empty(), "role": "host" if host else "client", "blood": blood_seen, "large": large_seen, "poison": poison_seen, "command": command_seen,"whirl":whirl_seen,"linked_target_moved":link_seen and link_moved, "scope": "two real local ENet peers, controlled fixture; no LAN/performance claim", "failures": failures}
	var file := FileAccess.open(args[args.find("--ring-result") + 1], FileAccess.WRITE)
	result["visible_source_uptake"] = visible_uptake_seen
	result["multi_drain_and_death_curse"] = multi_seen and curse_flight_seen
	check(monster_seen,"real poison ritual manifests friendly curse monster on host and client")
	check(bone_charge_seen and curse_wave_seen and brood_seen,"paid charge, normal5 curse wave and normal6 real corpse brood replicate")
	result["curse_evolution"] = {"charge":bone_charge_seen,"wave":curse_wave_seen,"brood":brood_seen}
	result["curse_monster"] = monster_seen
	result.passed = failures.is_empty()
	result.failures = failures
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	game._leave_session()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
