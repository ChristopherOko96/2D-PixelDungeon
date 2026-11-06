extends "res://scripts/capture_ranger_fields.gd"
## Real projectile/target collision in the current runtime, with a training target.
func _start() -> void:
	capture_out = "res://production/qa/evidence/hit-rig"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_out))
	await _make(true)
	game.lab_action("spec","sniper")
	game.lab_action("clear",null)
	game.players[1].pos = Vector2(640,360)
	game.players[1].aim = Vector2.RIGHT
	_foe(Vector2(830,360))
	_sync_view()
	await process_frame
	var target: Dictionary = game.enemies[0]
	var hp_before := float(target.hp)
	var cast_ok: bool = game.talent_combat.cast(1,"sniper_1",{"aim":Vector2.RIGHT})
	var landed := false
	for frame in range(90):
		await _advance(1.0/60)
		if not game.view._feedback.hit_rigs.live.is_empty():
			landed = true
			break
	await _photo("01-confirmed-hit")
	# Advance the same presentation owner to inspect independent parts after the flash.
	game.view._feedback.hit_rigs.update(0.09)
	await _photo("02-rays-and-chips")
	var damaged := float(target.hp)<hp_before
	print("HIT_RIG_CAPTURE cast=%s landed=%s resolved_damage=%s images=2 training=true"%[cast_ok,landed,damaged])
	game.queue_free()
	await process_frame
	quit(0 if cast_ok and landed and damaged else 1)
