extends "res://tests/curse_rework_test.gd"
## Real host regression: area curse, direct summon, bone wave, passive and focus.
const Targets = preload("res://src/combat/companion_targets.gd")
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos":Vector2(300,240),"class_id":"necromancer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout = {"id":"necro-forest","tile_size":32,"play_bounds":[0,0,1600,800],"world_size":[1600,800],"obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	test_area_curse_ignores_cursor_and_respects_walls()
	test_all_classes_dash_and_recharge()
	test_pet_retains_target_then_clears_room()
	test_ultimate_directly_summons_and_hits_curse()
	game.queue_free()
	await process_frame
	print("NECRO_FOREST checked=%d failures=%d"%[checked,failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_area_curse_ignores_cursor_and_respects_walls() -> void:
	_setup(d.talents.curse_3)
	var a := _dummy(Vector2(360,240))
	var b := _dummy(Vector2(230,210))
	var far := _dummy(Vector2(650,240))
	var hidden := _dummy(Vector2(300,330))
	game.current_layout.obstacles = [[250,280,100,16]]
	check(tc.cast(1,"curse_3",{"target":far.pos}),"self-centered curse casts")
	check(a.get("necro_curses",{}).has("1") and b.get("necro_curses",{}).has("1"),"all nearby enemies cursed independently of cursor")
	check(not far.get("necro_curses",{}).has("1") and not hidden.get("necro_curses",{}).has("1"),"range and walls exclude targets")
	game.current_layout.obstacles = []

func test_all_classes_dash_and_recharge() -> void:
	for cls: String in d.resources:
		tc.reset(3)
		tc.set_build(1,{"class":cls,"level":30,"ranks":{},"bar":[]})
		game.players[1].pos = Vector2(300,240)
		var rt: Dictionary = tc.runtime(1)
		var start := Vector2(game.players[1].pos)
		tc.hold(1,false,true,Vector2.INF,Vector2.RIGHT)
		check(Vector2(game.players[1].pos).distance_to(start)>60,"Shift dashes "+cls)
		var held := Vector2(game.players[1].pos)
		tc.hold(1,false,true,Vector2.INF,Vector2.RIGHT)
		check(Vector2(game.players[1].pos)==held,"holding Shift never repeats "+cls)
		for n in range(int(rt.defense.max)+1):
			tc.hold(1,false,false,Vector2.INF,Vector2.RIGHT)
			tc.hold(1,false,true,Vector2.INF,Vector2.RIGHT)
		held = Vector2(game.players[1].pos)
		tc.hold(1,false,false,Vector2.INF,Vector2.RIGHT)
		tc.hold(1,false,true,Vector2.INF,Vector2.RIGHT)
		check(Vector2(game.players[1].pos)==held,"no unlimited dash "+cls)
		_tick(4.2)
		check(float(rt.defense.left)>=1,"dash charge returns "+cls)

func test_pet_retains_target_then_clears_room() -> void:
	_setup(d.talents.beast_1)
	check(not tc.permanent_pet(1).is_empty(),"learned forest companion starts alongside hero")
	var pet: Dictionary = tc.permanent_pet(1)
	var a := _dummy(Vector2(pet.pos)+Vector2(50,0))
	var b := _dummy(Vector2(pet.pos)+Vector2(70,20))
	pet.target = a.id
	tc.runtime(1).hero_target = b.id
	check(int(tc._pet_prey(pet,game.players[1]).get("id",-1))==int(a.id),"hero attacking another enemy does not break pet focus")
	a.hp = 0
	b.pos = Vector2(pet.pos)+Vector2(800,0)
	check(int(tc._pet_prey(pet,game.players[1]).get("id",-1))==int(b.id),"engaged pet continues across current room after first target dies")
	b.hp = 0
	check(tc._pet_prey(pet,game.players[1]).is_empty(),"pet follows only after room is clear")

func test_ultimate_directly_summons_and_hits_curse() -> void:
	_setup(d.talents.curse_14)
	game.boss_moves.zones.clear()
	check(_cast(d.talents.curse_14),"ultimate casts without enemy death")
	var giants: Array = tc.pets.filter(func(p:Dictionary)->bool:return str(p.kind)=="curse_colossus")
	check(giants.size()==1,"R directly calls one curse monster")
	if giants.is_empty(): return
	var giant: Dictionary = giants[0]
	tc.runtime(1).pet_auto = [false,false]
	_tick(1.05)
	var foe := _dummy(Vector2(giant.pos)+Vector2(60,0))
	tc._pet_hit(giant,tc.runtime(1),foe,1,{})
	check(float(foe.get("necro_curses",{}).get("1",{}).get("mark",0))>0,"monster resolved hit applies passive curse")
	var before := float(foe.hp)
	check(tc.pet_cast(1,0,true),"5 starts bone wave")
	_tick(0.9)
	check(float(foe.hp)<before,"bone wave actually damages enemies")
	check(tc.events.any(func(e:Dictionary)->bool:return str(e.kind)=="necro_bone_wave"),"bone wave publishes rigged bone effect")
