extends "res://tests/curse_rework_test.gd"
## Enemy-born giant, host commands and boneball windup through actual game paths.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos":Vector2(300,240),"class_id":"necromancer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout = {"id":"curse-monster","tile_size":32,"play_bounds":[0,0,1408,704],"world_size":[1408,704],"obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	test_enemy_death_manifests_once_and_bursts()
	test_material_and_secondary_guards()
	test_wave_and_brood_commands()
	test_brood_cap_and_dead_caster_cancellation()
	test_boneball_charge_and_cancel()
	game.queue_free()
	await process_frame
	print("CURSE_EVOLUTION checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _pit() -> Dictionary:
	_setup(d.talents.curse_14)
	game.boss_moves.zones.clear()
	check(_cast(d.talents.curse_14),"R places actual poison ultimate")
	tc.runtime(1).pet_auto = [false,false]
	return tc.zones[-1]

func _monsters() -> Array:
	return tc.pets.filter(func(p:Dictionary)->bool:return str(p.kind)=="curse_colossus" and float(p.hp)>0 and float(p.life)>0)

func test_enemy_death_manifests_once_and_bursts() -> void:
	var zone := _pit()
	check(_monsters().size()==1,"ultimate directly summons without a death")
	var bystander := _dummy(Vector2(zone.pos)+Vector2(20,0))
	game._damage_enemy(_dummy(zone.pos),99999,Vector2.RIGHT,1,true,false)
	check(_monsters().size()==1,"enemy death never duplicates summoned giant")
	check(float(bystander.hp)<float(bystander.max_hp),"pit corpse explodes immediately")
	check(not tc.pets.any(func(p:Dictionary)->bool:return bool(p.get("plague_runner",false)) and float(p.hp)>0),"ultimate leaves no chasing skeleton")
	if _monsters().is_empty(): return
	var giant: Dictionary = _monsters()[0]
	check(str(giant.rig)=="curse_colossus" and giant.parts.size()==8,"eight real combat rig parts")
	check(Vector2(giant.pos).distance_to(zone.pos)<1,"giant emerges from pit center")
	game._damage_enemy(_dummy(zone.pos),99999,Vector2.RIGHT,1,true,false)
	check(_monsters().size()==1,"one giant per pit")
	tc._hurt_pet(giant,99999,giant.pos)
	tc._step_pets(0.05)
	game._damage_enemy(_dummy(zone.pos),99999,Vector2.RIGHT,1,true,false)
	check(_monsters().is_empty(),"spent pit cannot revive giant")

func test_material_and_secondary_guards() -> void:
	for reason: String in ["outside","consumed","expired","ordinary","wall","dead_owner","foreign","boss","summoned","pet_kill"]:
		var zone := _pit()
		for giant: Dictionary in _monsters():
			tc._hurt_pet(giant,99999,giant.pos)
		tc._step_pets(0.05)
		var enemy := _dummy(zone.pos)
		match reason:
			"outside": enemy.pos = Vector2(zone.pos)+Vector2(float(zone.r)+30,0)
			"consumed": tc.necromancer.consume_poison(tc,1,zone.pos,float(zone.r),3)
			"expired": zone.time = 0.0
			"ordinary": zone.talent = "curse_7"
			"wall":
				enemy.pos = Vector2(zone.pos)+Vector2(60,0)
				game.current_layout.obstacles = [[float(zone.pos.x)+25,0,16,704]]
			"dead_owner": game.players[1].hp = 0
			"foreign": zone.owner = 99
			"boss": enemy.boss = true
			"summoned": enemy.summoned = true
			"pet_kill": tc._pet_source = 99
		game._damage_enemy(enemy,99999,Vector2.RIGHT,1,true,false)
		tc._pet_source = -1
		check(_monsters().is_empty(),reason+" cannot revive the spent ultimate's giant")
		game.current_layout.obstacles = []

func test_wave_and_brood_commands() -> void:
	var zone := _pit()
	game._damage_enemy(_dummy(zone.pos),99999,Vector2.RIGHT,1,true,false)
	if _monsters().is_empty():
		check(false,"command setup requires enemy-born giant")
		return
	_tick(1.05)
	var giant: Dictionary = _monsters()[0]
	var a := _dummy(Vector2(giant.pos)+Vector2(70,0))
	var b := _dummy(Vector2(giant.pos)+Vector2(-60,25))
	var hidden := _dummy(Vector2(giant.pos)+Vector2(240,0))
	game.current_layout.obstacles = [[float(giant.pos.x)+180,0,16,704]]
	check(tc.pet_cast(1,0,true),"five commands curse wave")
	_tick(0.9)
	check(a.get("necro_curses",{}).has("1") and b.get("necro_curses",{}).has("1"),"wave curses all visible nearby foes")
	check(not hidden.get("necro_curses",{}).has("1"),"wave respects walls")
	check(not tc.pet_cast(1,0,true),"wave cooldown enforced")
	game.current_layout.obstacles = []
	check(tc.pet_cast(1,1,true),"six orders corpse brood")
	_tick(1.1)
	var small: Array = tc.pets.filter(func(p:Dictionary)->bool:return str(p.kind)=="curse_spawn" and float(p.hp)>0)
	check(small.size()==1,"one corpse creates one small curse monster")
	if not small.is_empty():
		check(str(small[0].rig)=="curse_spawn" and small[0].parts.size()==8,"same eight-part mini anatomy")
		var hp := float(a.hp)
		_tick(1.6)
		check(float(a.hp)<hp,"mini actually fights")
	var hud: Dictionary = tc.player_state(1).pet
	check(not hud.is_empty() and hud.abilities.size()==2,"HUD exposes giant commands")
	tc.runtime(1).pet_cds.clear()
	check(not tc.pet_cast(1,1,true),"spent corpse cannot summon twice")
	tc.room_changed()
	check(tc.pets.is_empty(),"room transition clears entire brood")

func test_brood_cap_and_dead_caster_cancellation() -> void:
	var zone := _pit()
	for n in range(6): game._damage_enemy(_dummy(Vector2(zone.pos)+Vector2(n*2,0)),99999,Vector2.RIGHT,1,true,false)
	_tick(1.05)
	check(tc.pet_cast(1,1,true),"brood uses available real corpses")
	_tick(0.9)
	check(tc.pets.filter(func(p:Dictionary)->bool:return str(p.kind)=="curse_spawn").size()==3,"brood bounded to three actual minis")
	tc.runtime(1).pet_cds.clear()
	check(not tc.pet_cast(1,1,true),"living brood cap cannot be bypassed by cooldown reset")
	zone = _pit()
	game._damage_enemy(_dummy(zone.pos),99999,Vector2.RIGHT,1,true,false)
	_tick(1.05)
	check(tc.pet_cast(1,1,true),"second fixture starts delayed brood")
	tc._hurt_pet(_monsters()[0],99999,zone.pos)
	_tick(1.0)
	check(not tc.pets.any(func(p:Dictionary)->bool:return str(p.kind)=="curse_spawn"),"dead giant cannot finish summoning")
	check(tc.necromancer.corpses.all(func(c:Dictionary)->bool:return not c.has("reserved")),"cancelled brood releases corpse reservations")

func test_boneball_charge_and_cancel() -> void:
	_setup(d.talents.curse_1)
	var foe := _dummy(Vector2(400,240))
	check(_cast(d.talents.curse_1),"boneball starts paid cast")
	check(game.bullets.is_empty(),"no projectile before charge")
	_tick(0.15)
	check(float(foe.hp)==float(foe.max_hp),"cannot damage early")
	_tick(1.05)
	check(float(foe.hp)<float(foe.max_hp),"charged ball hits first body")
	check(tc.events.any(func(e:Dictionary)->bool:return str(e.kind)=="necro_impact"),"actual impact event")
	_setup(d.talents.curse_1)
	_cast(d.talents.curse_1)
	tc.handle_input(1,game.players[1],{"skills":1<<tc.CANCEL_BIT})
	_tick(0.7)
	check(game.bullets.is_empty(),"modal cancels delayed projectile")
	_setup(d.talents.curse_1)
	game.current_layout.obstacles = [[350,0,16,704]]
	foe = _dummy(Vector2(400,240))
	_cast(d.talents.curse_1)
	_tick(1.2)
	check(float(foe.hp)==float(foe.max_hp) and game.bullets.is_empty(),"bone ball stops at first wall")
	game.current_layout.obstacles = []
	_setup(d.talents.curse_1)
	foe = _dummy(Vector2(380,240))
	var behind := _dummy(Vector2(440,240))
	_cast(d.talents.curse_1)
	_tick(1.2)
	check(float(foe.hp)<float(foe.max_hp) and float(behind.hp)==float(behind.max_hp),"bone ball stops at first enemy without piercing")
