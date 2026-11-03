extends "res://tests/soul_guardian_commands_test.gd"
## Moving target identity, line of sight and a sustained articulated minion action.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos": Vector2(300,240), "class_id":"necromancer", "hp":100, "max_hp":100, "damage":10.0, "aim":Vector2.RIGHT}
	game.current_layout = {"id":"rig-link", "tile_size":32, "play_bounds":[0,0,1408,704], "world_size":[1408,704], "obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	var rt := _setup(d.talents.curse_9)
	var victim := _dummy(Vector2(400,240))
	var other := _dummy(Vector2(440,300))
	check(_cast(d.talents.curse_9, {"target":victim.pos}), "blood beam casts at actual enemy")
	var links: Array = tc.snapshot().get("blood_links", [])
	check(links.size() == 2, "blood beam connects both nearby victims")
	if not links.is_empty():
		check(int(links[0].target_id) == int(victim.id), "link owns exact target identity")
		victim.pos += Vector2(25,60)
		game.players[1].pos += Vector2(-10,25)
		_tick(0.3)
		links = tc.snapshot().blood_links
		check(not links.is_empty() and Vector2(links[0].tx,links[0].ty).is_equal_approx(victim.pos), "host endpoint follows moving enemy")
		check(not links.is_empty() and Vector2(links[0].x,links[0].y).is_equal_approx(game.players[1].pos), "beam origin follows moving hero")
		check(float(victim.hp) < float(victim.max_hp) and float(other.hp) < float(other.max_hp), "channel damages both connected targets")
		game.current_layout.obstacles = [[350,0,16,704]]
		var hp := float(victim.hp)
		_tick(0.3)
		check(tc.snapshot().blood_links.is_empty(), "wall breaks beam before another channel tick")
		game.current_layout.obstacles = []
	rt = _setup(d.talents.minion_14)
	rt.pet_auto = [false,false]
	tc.permanent_pet(1).blood = 100.0
	check(_cast(d.talents.minion_14), "large skeleton active")
	_tick(1.2)
	var pet: Dictionary = tc.command_pet(1)
	check(tc.pet_ability(str(pet.kind),1).id == "bone_whirl", "large form owns blade storm on six")
	victim = _dummy(Vector2(pet.pos)+Vector2(50,0))
	check(tc.pet_cast(1,1,true), "blade storm command starts")
	check(pet.has("whirl"), "storm is sustained host state rather than instant nova")
	if pet.has("whirl"):
		var hp := float(victim.hp)
		_tick(0.8)
		check(float(victim.hp) < hp, "storm hits during active sweep")
		check(tc.snapshot().pets.any(func(p: Dictionary)->bool: return not p.get("whirl",{}).is_empty()), "storm phase replicates for rig poses")
		_tick(3.0)
		check(not pet.has("whirl"), "storm ends and normal companion combat resumes")
	rt = _setup(d.talents.curse_1)
	victim = _dummy(Vector2(400,240))
	game.current_layout.obstacles = [[460,0,16,704]]
	_cast(d.talents.curse_1)
	_tick(0.8)
	check(float(victim.hp)<float(victim.max_hp) and game.bullets.is_empty(), "rigged curse projectile hits enemy before a farther wall")
	check(tc.events.any(func(e:Dictionary)->bool:return str(e.kind)=="necro_impact"), "source-part impact is authoritative at contact")
	game.current_layout.obstacles = []
	rt = _setup(d.talents.curse_9)
	victim = _dummy(Vector2(400,240))
	_cast(d.talents.curse_9,{"target":victim.pos})
	victim.hp = 0.0
	_tick(0.1)
	check(tc.snapshot().blood_links.is_empty(),"dead target ends connection without selecting another victim")
	rt = _setup(d.talents.curse_9)
	victim = _dummy(Vector2(400,240))
	_cast(d.talents.curse_9,{"target":victim.pos})
	victim.pos = Vector2(900,240)
	_tick(0.1)
	check(tc.snapshot().blood_links.is_empty(),"out of range target breaks connection")
	rt = _setup(d.talents.curse_9)
	victim = _dummy(Vector2(400,240))
	_cast(d.talents.curse_9,{"target":victim.pos})
	tc.room_changed()
	check(tc.snapshot().blood_links.is_empty(),"room change clears bound actors")
	game.queue_free()
	await process_frame
	print("NECRO_RIG_LINK checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
