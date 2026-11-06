extends "res://tests/curse_rework_test.gd"
## Actual host casts: room-wide arrow, physical poison trap and boss-safe lure.
func _run() -> void:
	game=Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1]={"pos":Vector2(300,240),"class_id":"archer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout={"id":"ranger-fields","tile_size":32,"play_bounds":[0,0,1600,800],"world_size":[1600,800],"obstacles":[]}
	game.phase="combat"
	tc=game.talent_combat
	d=tc.data
	test_arrow_reaches_far_targets_with_wide_wall_stopped_lane()
	test_diagonal_arrow_stays_on_ray_instead_of_sliding_along_wall()
	# Former poison-cloud trap and ranger-pull rules are superseded by
	# alchemist_traps_test.gd; retain the charged-arrow geometry regressions here.
	game.queue_free()
	await process_frame
	print("RANGER_FIELDS checked=%d failures=%d"%[checked,failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_arrow_reaches_far_targets_with_wide_wall_stopped_lane() -> void:
	_setup(d.talents.sniper_14)
	var wide:=_dummy(Vector2(600,285))
	var far:=_dummy(Vector2(1250,240))
	var hidden:=_dummy(Vector2(1480,240))
	game.current_layout.obstacles=[[1400,0,32,800]]
	_cast(d.talents.sniper_14,{"aim":Vector2.RIGHT})
	tc.SoulCharge.step(tc,1,2)
	check(float(wide.hp)<float(wide.max_hp),"wide ultimate catches an off-axis target missed by old thin line")
	check(float(far.hp)<float(far.max_hp),"charged arrow crosses the room beyond former fourteen metres")
	check(float(hidden.hp)==float(hidden.max_hp),"wide arrow still cannot hit through the wall")
	var shots: Array=tc.events.filter(func(e:Dictionary)->bool:return str(e.kind)=="spear")
	check(shots.size()==1,"one release creates one arrow")
	if not shots.is_empty():
		check(float(shots[0].tx)>1390 and float(shots[0].tx)<1400,"arrow endpoint reaches actual first wall")
		check(bool(shots[0].get("wall",false)) and float(shots[0].r)>=32,"wall impact and actual hit radius replicate to renderer")
	game.current_layout.obstacles=[]

func test_diagonal_arrow_stays_on_ray_instead_of_sliding_along_wall() -> void:
	_setup(d.talents.sniper_14)
	game.current_layout.obstacles=[[900,0,32,800]]
	var aim:=Vector2(1,0.5).normalized()
	_cast(d.talents.sniper_14,{"aim":aim})
	tc.SoulCharge.step(tc,1,2)
	var shots: Array=tc.events.filter(func(e:Dictionary)->bool:return str(e.kind)=="spear")
	if not shots.is_empty():
		var ray:=Vector2(shots[0].tx,shots[0].ty)-Vector2(300,240)
		check(absf(ray.cross(aim))<0.1,"diagonal arrow is clipped on its ray, never wall-slides")
		check(Vector2(shots[0].tx,shots[0].ty).distance_to(Vector2(896,538))<2,"first diagonal contact matches wall geometry")
	game.current_layout.obstacles=[]
