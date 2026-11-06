extends "res://scripts/capture_ranger_fields.gd"
## All seven actual casts through the current game renderer, in explicit training states.
var cast_failures := 0

func _start() -> void:
	capture_out = "res://production/qa/evidence/marksman-sprites"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_out))
	await _make(true)
	game.lab_action("spec","sniper")
	for talent: String in ["sniper_1","sniper_3","sniper_5","sniper_7","sniper_9","sniper_11","sniper_14"]:
		game.lab_action("reset",null)
		game.lab_action("auto",false)
		game.lab_action("clear",null)
		game.players[1].pos = Vector2(640,360)
		game.players[1].aim = Vector2.RIGHT
		game.players[1].face = 1
		if talent in ["sniper_9","sniper_11"]: game.lab_action("kit",1)
		for n in range(3): _foe(Vector2(810+n*64,360))
		_sync_view()
		await process_frame
		var ok: bool = game.talent_combat.cast(1,talent,{"aim":Vector2.RIGHT,"target":Vector2(900,360)})
		if not ok:
			cast_failures += 1
			printerr("MARKSMAN_CAPTURE_CAST_FAILED ",talent)
		if talent == "sniper_14":
			await _advance(0.9)
			await _photo(talent+"-charge")
			game.talent_combat.SoulCharge.hold(game.talent_combat,1,false,Vector2.RIGHT)
			await _advance(0.12)
			await _photo(talent+"-flight")
			await _advance(0.22)
			await _photo(talent+"-impact")
		else:
			await _advance(0.18 if talent != "sniper_11" else 0.3)
			await _photo(talent)
	game.queue_free()
	await process_frame
	print("MARKSMAN_CAPTURE images=9 actual_casts=7 cast_failures=%d training=true"%cast_failures)
	quit(1 if cast_failures else 0)
