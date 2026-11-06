extends "res://scripts/capture_ranger_fields.gd"
## Actual charged ultimate through the current renderer; explicit training state, not earned progression.
func _start() -> void:
	capture_out="res://production/qa/evidence/himmelsspeer-lance"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_out))
	await _make(true)
	game.lab_action("spec","sniper")
	game.lab_action("auto",false)
	game.lab_action("clear",null)
	game.commands.clear() # This manually stepped capture has no live held-key source.
	game.players[1].pos=Vector2(640,360)
	game.players[1].aim=Vector2.RIGHT
	game.players[1].face=1
	for n in range(3): _foe(Vector2(820+n*64,360))
	var ok: bool=game.talent_combat.cast(1,"sniper_14",{"aim":Vector2.RIGHT})
	await _advance(0.35)
	await _photo("01-aufbau")
	await _advance(0.65)
	if not game.talent_combat.runtime(1).has("soul_charge"):
		printerr("HIMMELSSPEER_CAPTURE charge unexpectedly released")
		quit(1)
		return
	await _photo("02-gespannt")
	game.talent_combat.SoulCharge.hold(game.talent_combat,1,false,Vector2.RIGHT)
	await _advance(0.08)
	await _photo("03-abschuss")
	await _advance(0.1)
	await _photo("04-flug")
	await _advance(0.13)
	await _photo("05-wandkontakt")
	await _advance(0.16)
	await _photo("06-einzelteile")
	print("HIMMELSSPEER_CAPTURE cast=%s images=6 real_renderer=true training=true"%ok)
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
