extends "res://tests/curse_rework_test.gd"
## Forest traps arm before triggering, keep wall checks, leave real fire media.
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos":Vector2(300,240),"class_id":"archer","hp":100,"max_hp":100,"damage":10.0,"aim":Vector2.RIGHT}
	game.current_layout = {"id":"forest-traps","tile_size":32,"play_bounds":[0,0,1408,704],"world_size":[1408,704],"obstacles":[]}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	_setup(d.talents.beast_6)
	tc.pets.clear()
	check(_cast(d.talents.beast_6),"thorn bait casts")
	check(tc.traps.size()==1,"forest attack is a real trap")
	if not tc.traps.is_empty():
		var trap: Dictionary = tc.traps[0]
		var foe := _dummy(trap.pos)
		var hidden := _dummy(Vector2(trap.pos)+Vector2(60,0))
		game.current_layout.obstacles = [[float(trap.pos.x)+25,0,16,704]]
		_tick(0.2)
		check(float(foe.hp)==float(foe.max_hp),"trap cannot explode before arming")
		_tick(0.5)
		check(float(foe.hp)<float(foe.max_hp),"armed thorn trap damages intruder")
		check(float(hidden.hp)==float(hidden.max_hp),"trap never damages through wall")
	game.current_layout.obstacles = []
	_setup(d.talents.beast_7)
	tc.pets.clear()
	game.boss_moves.zones.clear()
	_cast(d.talents.beast_7)
	check(tc.traps.size()==1,"ember trap placed")
	if not tc.traps.is_empty():
		_dummy(tc.traps[0].pos)
		_tick(0.7)
		check(tc.necromancer.media(tc).any(func(z:Dictionary)->bool:return str(z.get("style",""))=="fire" and int(z.get("fed_by",-1))==1 and float(z.get("radius",0))>=96),"fire trap leaves substantial actual owned fire field")
	game.queue_free()
	await process_frame
	print("FOREST_TRAPS checked=%d failures=%d"%[checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
