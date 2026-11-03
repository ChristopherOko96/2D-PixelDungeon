extends SceneTree
## Real GPU captures of the offline lab, controlled fixtures, not a campaign.
const Lab = preload("res://src/debug/necro_lab_game.gd")
const DEST := "res://production/qa/evidence/necro-lab"
var game: Node
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	game = Lab.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.lab_action("auto",false)
	game.scripted_target = Vector2(game.players[1].pos)+Vector2(180,0)
	game.lab_aiming = true
	await _photo("01-zielen")
	game.lab_aiming = false
	game.talent_combat.cast(1,"curse_14",{"target":game.scripted_target})
	_step(0.2)
	game._damage_enemy(game.enemies[1],99999,Vector2.RIGHT,1,true,false)
	_step(1.1)
	game.talent_combat.cast(1,"curse_9")
	_step(0.2)
	await _photo("02-fluch-blut")
	game.lab_action("spec","soul")
	game.talent_combat.cast(1,"soul_3")
	_step(1.5)
	await _photo("03-seelenring")
	game.lab_action("spec","minion")
	game.talent_combat.cast(1,"minion_1")
	_step(1.1)
	game.talent_combat.cast(1,"minion_9")
	game.lab_action("blood",null)
	_step(0.3)
	await _photo("04-diener")
	game.queue_free()
	await process_frame
	print("NECRO_LAB_CAPTURE images=4 original=1280x720")
	quit()
func _step(seconds: float) -> void:
	for n in range(ceili(seconds*60)):
		game._step_world(1.0/60)
func _photo(name: String) -> void:
	game._broadcast_state(true)
	game._refresh_ui()
	game.view.set_state(game.state,1)
	game._update_camera(0.016)
	game.view._clock = 20.0
	game.lab_art.queue_redraw()
	for frame in range(90):
		await process_frame
		var pools: RefCounted = game.view._talent_fx.pools
		var ready: bool = pools!=null and pools.pool_field.pending()==0 and pools._laying.is_empty()
		if ready:
			for field: Dictionary in pools._fields.values():
				if field.has("work"): ready=false
		if frame>30 and ready: break
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST.path_join(name+".png"))
