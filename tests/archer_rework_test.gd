extends "res://tests/curse_rework_test.gd"
## One-use marks, real R hold/release, boss-safe pinning and paid trap charges.
func _run() -> void:
	game=Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1]={"pos":Vector2(300,240),"class_id":"archer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout={"id":"archer-rules","tile_size":32,"play_bounds":[0,0,1600,800],"world_size":[1600,800],"obstacles":[]}
	game.phase="combat"
	tc=game.talent_combat
	d=tc.data
	test_marks_bonus_is_owned_and_spent_once()
	test_r_charges_releases_and_pins_except_boss()
	test_traps_have_three_charges_and_six_ground_slots()
	test_marks_owner_expiry_and_paid_charge_boundaries()
	game.queue_free()
	await process_frame
	print("ARCHER_REWORK checked=%d failures=%d"%[checked,failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_marks_bonus_is_owned_and_spent_once() -> void:
	_setup(d.talents.sniper_5)
	var a:=_dummy(Vector2(360,240))
	var b:=_dummy(Vector2(420,240))
	var hidden:=_dummy(Vector2(300,400))
	game.current_layout.obstacles=[[0,350,600,32]]
	check(_cast(d.talents.sniper_5),"marksman casts once")
	check(a.get("marksman_marks",{}).has("1") and b.get("marksman_marks",{}).has("1"),"visible nearby foes each get a one-use mark")
	check(not hidden.get("marksman_marks",{}).has("1"),"mark cannot pass a wall")
	var shot:={"owner":1,"damage":10.0,"velocity":Vector2.RIGHT*560,"style":"arrow","primary":true}
	var hp:=float(a.hp)
	tc._rng.seed=12345
	game.perk_combat.hit(shot,a)
	var first:=hp-float(a.hp)
	check(not a.get("marksman_marks",{}).has("1"),"confirmed own arrow consumes its mark")
	hp=float(a.hp)
	tc._rng.seed=12345
	game.perk_combat.hit(shot,a)
	check(first>hp-float(a.hp)+1,"only first own arrow receives the bonus")
	check(b.get("marksman_marks",{}).has("1"),"other victims retain their own unused mark")
	game._damage_enemy(b,1,Vector2.ZERO,1,true,false)
	check(b.get("marksman_marks",{}).has("1"),"damage over time never consumes the arrow mark")
	game.current_layout.obstacles=[]

func test_r_charges_releases_and_pins_except_boss() -> void:
	_setup(d.talents.sniper_14)
	var a:=_dummy(Vector2(400,240))
	var b:=_dummy(Vector2(480,240))
	var boss:=_dummy(Vector2(560,240),true)
	var hidden:=_dummy(Vector2(900,240))
	game.current_layout.obstacles=[[800,0,32,800]]
	var input:={"skills":1<<tc.ULT_BIT,"aim":Vector2.RIGHT,"target":Vector2(1000,240)}
	tc.handle_input(1,game.players[1],input)
	tc.step(0.35)
	tc.handle_input(1,game.players[1],input)
	check(tc.runtime(1).has("soul_charge"),"R remains charging while R is held")
	check(float(a.hp)==float(a.max_hp),"no damage before release")
	tc.handle_input(1,game.players[1],{"skills":0,"aim":Vector2.RIGHT})
	check(not tc.runtime(1).has("soul_charge") and float(a.hp)<float(a.max_hp) and float(b.hp)<float(b.max_hp),"release hits all foes along the arrow line")
	check(float(hidden.hp)==float(hidden.max_hp),"ultimate stops at wall")
	_tick(0.3)
	check(float(a.pos.x)>400 and float(b.pos.x)>480,"arrow carries normal enemies forward")
	check(a.has("marksman_pin") and b.has("marksman_pin"),"normal enemies remain pinned after knockback")
	check(not boss.has("marksman_pin") and Vector2(boss.pos)==Vector2(560,240),"boss takes damage but never gets carried or pinned")
	check(float(boss.hp)<float(boss.max_hp),"boss still takes ultimate damage")
	check(not tc.cast(1,"sniper_14"),"ultimate cooldown forbids another charge")
	game.current_layout.obstacles=[]

func test_traps_have_three_charges_and_six_ground_slots() -> void:
	var rt:=_setup(d.talents.trapper_3)
	for n in range(3):
		rt.gcd=0
		check(_cast(d.talents.trapper_3,{"target":Vector2(400+n*32,180)}),"paid trap charge "+str(n+1))
	check(tc.traps.size()==3,"three placements without waiting a whole cooldown")
	check(tc.traps.all(func(t:Dictionary)->bool:return float(t.r)>=64),"thorn trap hit area is larger")
	rt.gcd=0
	check(not tc.cast(1,"trapper_3"),"fourth cast waits for a charge")
	_tick(12.2)
	check(tc.cast(1,"trapper_3"),"one charge returns after cooldown")
	rt=_setup(d.talents.trapper_14)
	for talent: String in ["trapper_3","trapper_5"]:
		for n in range(3):
			rt.gcd=0
			rt.res=1000
			tc.cast(1,talent,{"target":Vector2(400+n*24,180 if talent=="trapper_3" else 320)})
	check(tc.traps.size()==6,"three charges of each trap coexist before expiry")
	rt.gcd=0
	tc.cast(1,"trapper_14")
	check(tc.traps.size()==6,"six simultaneous ground traps, oldest replaced at limit")
	var slot: Dictionary=tc.player_state(1).slots.filter(func(s:Dictionary)->bool:return str(s.id)=="trapper_3")[0]
	check(int(slot.get("charges_max",0))==3,"HUD exposes trap charges")
	var spent: int=rt.ability_charges.trapper_3.left
	var progress: float=rt.ability_charges.trapper_3.timer
	tc.set_build(1,{"class":"archer","level":30,"ranks":rt.ranks.duplicate(),"bar":rt.bar.duplicate()},true)
	rt=tc.runtime(1)
	check(int(rt.ability_charges.trapper_3.left)==spent and is_equal_approx(float(rt.ability_charges.trapper_3.timer),progress),"same-class build edits preserve spent charges and refill progress")
	tc.TalentCharges.step(rt,1000)
	check(int(rt.ability_charges.trapper_3.left)==3 and float(rt.ability_charges.trapper_3.timer)==0,"long refill tick stops at three charges")

func test_marks_owner_expiry_and_paid_charge_boundaries() -> void:
	_setup(d.talents.sniper_5)
	var foe:=_dummy(Vector2(400,240))
	_cast(d.talents.sniper_5)
	game.players[2]=game.players[1].duplicate(true)
	tc.set_build(2,{"class":"archer","level":30,"ranks":{"sniper_1":1},"bar":["sniper_1"]})
	game.perk_combat.hit({"owner":2,"damage":10.0,"velocity":Vector2.RIGHT*560,"style":"arrow","primary":true},foe)
	check(foe.get("marksman_marks",{}).has("1"),"another player's arrow cannot spend the owner's mark")
	game.perk_combat.hit({"owner":1,"damage":10.0,"velocity":Vector2.RIGHT*560,"style":"arrow","primary":false},foe)
	check(foe.get("marksman_marks",{}).has("1"),"secondary arrow cannot spend the mark")
	tc.marksman.step(tc,13)
	check(foe.get("marksman_marks",{}).is_empty(),"unused marks expire without a bonus hit")
	game.players.erase(2)
	var rt:=_setup(d.talents.sniper_14)
	foe=_dummy(Vector2(400,240))
	rt.res=100
	check(tc.cast(1,"sniper_14",{"aim":Vector2.RIGHT,"charge":999999}),"R accepts normal cast but ignores supplied charge power")
	tc.SoulCharge.step(tc,1,10)
	check(not rt.has("soul_charge") and is_equal_approx(float(rt.res),25),"full R automatically releases and pays exactly 50 plus 25")
	check(tc.events.filter(func(e:Dictionary)->bool:return str(e.kind)=="spear").size()==1,"long charge step emits exactly one shot")
	rt=_setup(d.talents.sniper_14)
	foe=_dummy(Vector2(400,240))
	tc.cast(1,"sniper_14")
	tc.handle_input(1,game.players[1],{"skills":1<<tc.CANCEL_BIT})
	tc.step(2)
	check(not rt.has("soul_charge") and float(foe.hp)==float(foe.max_hp),"modal cancel prevents delayed ultimate damage")
	rt=_setup(d.talents.sniper_14)
	foe=_dummy(Vector2(760,240))
	game.current_layout.obstacles=[[800,0,32,800]]
	tc.cast(1,"sniper_14",{"aim":Vector2.RIGHT})
	tc.SoulCharge.step(tc,1,2)
	_tick(0.3)
	check(Vector2(foe.pos).x<=800-float(foe.radius),"carried enemy stops at wall instead of passing through it")
	_tick(2.2)
	check(not foe.has("marksman_pin"),"pin state expires after its bounded duration")
	game.current_layout.obstacles=[]
