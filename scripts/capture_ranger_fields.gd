extends "res://scripts/capture_archer_rework.gd"
## Actual game renderer, explicitly prepared training states, eight native images.
func _start() -> void:
	capture_out="res://production/qa/evidence/ranger-fields"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_out))
	await _make(true)
	game.lab_action("spec","sniper")
	game.lab_action("clear",null)
	game.players[1].pos=Vector2(640,360)
	game.players[1].aim=Vector2.RIGHT
	game.players[1].face=1
	for n in range(3): _foe(Vector2(820+n*65,360+n*16))
	game.talent_combat.cast(1,"sniper_14",{"aim":Vector2.RIGHT})
	await _advance(1.0)
	await _photo("01-himmelsspeer-laden")
	game.talent_combat.SoulCharge.hold(game.talent_combat,1,false,Vector2.RIGHT)
	await _advance(0.1)
	await _photo("02-breiter-pfeil")
	await _advance(0.34)
	await _photo("03-wandkontakt-splitter")
	game.lab_action("spec","trapper")
	game.lab_action("clear",null)
	var at:=Vector2(820,480)
	game.talent_combat.cast(1,"trapper_7",{"target":at})
	await _advance(0.6)
	await _photo("04-giftfalle-scharf")
	_foe(at)
	await _advance(1.5)
	await _photo("05-vorhandene-giftpfuetze-und-wolke")
	game.lab_action("reset",null)
	game.lab_action("clear",null)
	for n in range(5): _foe(at+Vector2.from_angle(float(n)*TAU/5)*135)
	game.talent_combat.cast(1,"trapper_11",{"target":at})
	await _advance(0.1)
	await _photo("06-rankensog-beginn")
	await _advance(0.65)
	await _photo("07-rankensog-zusammengezogen")
	await _tree("trapper_7","08-fallenbaum-giftfalle")
	game.queue_free()
	await process_frame
	print("RANGER_CAPTURE images=8 native=1280x720 controlled=true")
	quit()

func _foe(at: Vector2) -> void:
	var enemy: Dictionary=game._create_enemy("skelet",at)
	enemy.hp=10000
	enemy.max_hp=10000
	enemy.speed=0
	enemy.lab_dummy=true
	game.enemies.append(enemy)

func _sync_view() -> void:
	game._broadcast_state(true)
	game._refresh_ui()
	game.view.set_state(game.state,1)
	game._update_camera(1.0/60)
	game.lab_art.queue_redraw()

func _advance(seconds: float) -> void:
	for frame in range(ceili(seconds*60)):
		_step(1.0/60)
		_sync_view()
		await process_frame

func _photo(name: String) -> void:
	_sync_view()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_out.path_join(name+".png"))
