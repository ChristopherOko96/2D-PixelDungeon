extends "res://tests/soul_guardian_commands_test.gd"
func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.players[1] = {"pos": Vector2(300, 240), "class_id": "necromancer", "hp": 100, "max_hp": 100, "damage": 10.0, "aim": Vector2.RIGHT}
	game.current_layout = {"id": "leap", "tile_size": 32, "play_bounds": [0, 0, 1408, 704], "world_size": [1408, 704], "obstacles": []}
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	check(str(game.view.CLASS_RIGS.get("necromancer", "")) == "necro", "playable necromancer actually uses existing source cutout rig")
	var rt := _setup(d.talents.soul_7)
	var before := Vector2(game.players[1].pos)
	check(_cast(d.talents.soul_7), "learned shadow jump casts")
	check(game.players[1].pos == before and rt.has("soul_leap"), "jump starts with rig anticipation rather than instant teleport")
	if rt.has("soul_leap"):
		_tick(0.3)
		check(Vector2(game.players[1].pos).x > before.x + 50 and Vector2(game.players[1].pos).x < before.x + 320, "host advances along bounded leap")
		check(not tc.player_state(1).leap.is_empty(), "shared hero rig receives jump progress")
		_tick(0.5)
		check(not rt.has("soul_leap") and Vector2(game.players[1].pos).distance_to(before) > 300, "highest rank travels ten metres")
		check(tc.zones.size() == 1 and str(tc.zones[0].look) == "souls_trail", "landing leaves one coherent soul trail")
		if not tc.zones.is_empty():
			var middle := _dummy(before + Vector2(150, 0))
			var side := _dummy(before + Vector2(150, 90))
			_tick(0.1)
			check(middle.statuses.has("soul_bind") and not side.statuses.has("soul_bind"), "only actual trail touches bind")
			_tick(4.1)
			check(not tc.zones.is_empty(), "trail remains for five seconds after landing")
			_tick(1.0)
			check(tc.zones.is_empty(), "trail expires without permanent residue")
	_setup(d.talents.soul_7)
	game.current_layout.obstacles = [[420, 0, 16, 704]]
	_cast(d.talents.soul_7)
	_tick(0.9)
	check(Vector2(game.players[1].pos).x <= 420 - float(game.balance.player.radius) and Vector2(game.players[1].pos).x > 300, "jump respects actual collision radius")
	game.current_layout.obstacles = []
	rt = _setup(d.talents.soul_7)
	_cast(d.talents.soul_7)
	tc.room_changed()
	_tick(1.0)
	check(not rt.has("soul_leap") and tc.zones.is_empty(), "room change cancels leap and trail")
	check(float(d.talents.soul_3.ring_time) == 5 and float(d.talents.soul_11.time) == 5, "ring and placed field last five seconds")
	game.queue_free()
	await process_frame
	print("SOUL_LEAP checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
