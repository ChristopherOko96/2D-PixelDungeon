extends "res://tests/necro_blood_cycle_test.gd"
## The real puddle stays present until its finite blood has entered a rigged pet.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos":Vector2(300,240),"class_id":"necromancer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout = {"id":"visible-absorption","tile_size":32,"play_bounds":[0,0,1408,704],"world_size":[1408,704],"obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	_warrior()
	var pet: Dictionary = tc.permanent_pet(1)
	var source := _source(pet)
	_tick(0.3)
	check(float(source.timer)>0 and float(pet.get("blood",0))==0,"blood puddle forms visibly before uptake starts")
	_tick(0.9)
	check(float(source.timer)>0 and float(pet.get("blood",0))>0 and float(pet.get("blood",0))<25,"real source remains alive while particles and blood enter warrior")
	var snap: Dictionary = tc.snapshot().pets[0]
	check(float(snap.get("blood_pool_r",0))>0 and float(snap.get("blood_wait",-1))==0,"clients receive real puddle origin radius and uptake phase")
	_tick(3)
	check(float(source.timer)<=0 and is_equal_approx(float(pet.blood),25),"puddle ends only after its twenty-five blood have arrived")
	_warrior()
	pet = tc.permanent_pet(1)
	source = _source(pet)
	_tick(1.2)
	var received := float(pet.get("blood",0))
	pet.hp = 0
	_tick(0.1)
	check(float(source.timer)>0 and float(pet.get("blood_pending",0))==0,"dead warrior releases remaining physical blood instead of draining a ghost source")
	var rt: Dictionary = tc.runtime(1)
	rt.cds.erase("minion_1")
	rt.gcd = 0
	rt.res = 100
	check(tc.cast(1,"minion_1"),"replacement warrior is paid normally")
	var next: Dictionary = tc.permanent_pet(1)
	next.pos = source.pos
	_tick(4)
	check(is_equal_approx(received+float(next.get("blood",0)),25),"partial uptake never duplicates the remaining source budget")
	_warrior()
	pet = tc.permanent_pet(1)
	source = _source(pet)
	_tick(1.2)
	var blood := float(pet.get("blood",0))
	source.timer = 0
	_tick(1)
	check(is_equal_approx(float(pet.get("blood",0)),blood) and float(pet.get("blood_pending",0))==0,"externally destroyed puddle stops all further credit and particles")
	_warrior()
	pet = tc.permanent_pet(1)
	source = _source(pet)
	_tick(1.2)
	blood = float(pet.get("blood",0))
	game.boss_moves.zones.erase(source)
	_tick(1)
	check(is_equal_approx(float(pet.get("blood",0)),blood) and float(pet.get("blood_pending",0))==0,"removed physical medium cannot keep feeding through a stale dictionary reference")
	_warrior()
	pet = tc.permanent_pet(1)
	source = _source(pet)
	_tick(1.2)
	tc.room_changed()
	check(float(pet.get("blood_pending",0))==0,"room transfer clears source attachment and particle stream")
	_warrior()
	pet = tc.permanent_pet(1)
	source = _source(pet)
	game.players[2] = game.players[1].duplicate(true)
	tc.set_build(2,{"class":"necromancer","level":30,"ranks":{"minion_1":1},"bar":["minion_1"]})
	tc.cast(2,"minion_1")
	var other: Dictionary = tc.permanent_pet(2)
	other.pos = pet.pos
	_tick(1.2)
	check(float(source.timer)>0 and not (float(pet.get("blood",0))>0 and float(other.get("blood",0))>0),"two warriors cannot drain the same visible puddle simultaneously")
	_tick(4)
	check(is_equal_approx(float(pet.get("blood",0))+float(other.get("blood",0)),25),"one shared physical pool still pays exactly once")
	game.queue_free()
	await process_frame
	print("NECRO_POOL_ABSORPTION checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _source(pet: Dictionary) -> Dictionary:
	game.boss_moves.zones.clear()
	tc.necromancer.pool(tc,1,"blood",pet.pos,80,12)
	return game.boss_moves.zones[-1]
