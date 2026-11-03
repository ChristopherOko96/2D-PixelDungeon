extends "res://tests/soul_guardian_commands_test.gd"
## Regression: an authoritative beam stays on one moving enemy, never a slot.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos":Vector2(300,240),"class_id":"necromancer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout = {"id":"guardian-adhesion","tile_size":32,"play_bounds":[0,0,1408,704],"world_size":[1408,704],"obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	test_beam_follows_the_same_moving_enemy()
	test_dead_or_occluded_target_breaks_without_switching()
	test_out_of_range_and_owner_death_end_the_connection()
	game.queue_free()
	await process_frame
	print("GUARDIAN_ADHESION checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _attached() -> Dictionary:
	_setup(d.talents.soul_14)
	var target := _dummy(Vector2(450,240))
	_cast(d.talents.soul_14)
	_tick(0.7)
	tc.guardians.actors[0].autos = [false,false]
	check(tc.guardians.command(tc,1,0,Vector2.RIGHT),"paid guardian command starts channel")
	_tick(0.5)
	return target

func test_beam_follows_the_same_moving_enemy() -> void:
	var target := _attached()
	var guardian: Dictionary = tc.guardians.actors[0]
	check(int(guardian.get("beam_target",-1))==int(target.id),"beam captures stable target identity")
	var spare := _dummy(Vector2(520,240))
	var hp := float(target.hp)
	target.pos = Vector2(450,330)
	game.players[1].aim = Vector2.LEFT
	_tick(0.3)
	check(float(target.hp)<hp,"beam still damages enemy after lateral movement")
	check(Vector2(guardian.aim).dot((Vector2(target.pos)-Vector2(guardian.pos)).normalized())>0.999,"aim follows enemy rather than hero cursor")
	check(float(spare.hp)==float(spare.max_hp),"original empty firing line no longer deals stray damage")
	var snap: Dictionary = tc.guardians.snapshot()[0]
	check(int(snap.get("beam_target_id",-1))==int(target.id) and Vector2(snap.get("beam_tx",0),snap.get("beam_ty",0)).is_equal_approx(target.pos),"snapshot carries live target ID and endpoint")
	check(is_equal_approx(float(guardian.beam_length),Vector2(guardian.pos).distance_to(target.pos)),"beam ends at the attached enemy rather than behind it")

func test_dead_or_occluded_target_breaks_without_switching() -> void:
	var target := _attached()
	var replacement := _dummy(Vector2(500,240))
	target.hp = 0.0
	_tick(0.3)
	check(float(replacement.hp)==float(replacement.max_hp) and float(tc.guardians.actors[0].beam_length)==0,"dead target releases beam without attaching to another enemy")
	target = _attached()
	var hp := float(target.hp)
	game.current_layout.obstacles = [[400,0,16,704]]
	_tick(0.3)
	check(float(target.hp)==hp and float(tc.guardians.actors[0].beam_length)==0,"new wall breaks live connection before next damage tick")
	game.current_layout.obstacles = []
	_tick(0.2)
	check(float(target.hp)==hp,"broken channel cannot reconnect through later wall removal")

func test_out_of_range_and_owner_death_end_the_connection() -> void:
	var target := _attached()
	var hp := float(target.hp)
	target.pos = Vector2(1000,240)
	_tick(0.25)
	check(float(target.hp)==hp and float(tc.guardians.actors[0].beam_length)==0,"leaving configured range ends attached damage")
	_attached()
	game.players[1].hp = 0
	_tick(0.1)
	check(tc.guardians.actors.is_empty(),"dead owner cannot leave a damaging channel")
