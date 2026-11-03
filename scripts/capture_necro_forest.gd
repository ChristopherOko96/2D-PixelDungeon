extends SceneTree
## Controlled states in the actual renderer, never a played campaign.
const Lab = preload("res://src/debug/necro_lab_game.gd")
const DEST := "res://production/qa/evidence/necro-forest-rework"
var capture_dest:=DEST
var game: Node
func _initialize() -> void:
	_start.call_deferred()
func _make(forest: bool) -> void:
	game = Lab.new()
	if forest: game.lab_cfg=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/debug_forest_lab.json"))
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.lab_action("auto",false)
	game.players[1].aim=Vector2.RIGHT
	game.players[1].face=1
func _start() -> void:
	await _make(false)
	game.talent_combat.cast(1,"curse_3")
	_step(0.3)
	await _photo("01-aufsteigende-flueche")
	game.lab_action("reset",null)
	game.talent_combat.cast(1,"curse_1",{"aim":Vector2.RIGHT})
	_step(0.36)
	await _photo("02-knochenkern")
	_step(0.36)
	await _photo("03-knochenspur")
	_step(0.32)
	await _photo("04-knochenburst")
	game.lab_action("reset",null)
	game.talent_combat.cast(1,"curse_14",{"target":Vector2(game.players[1].pos)+Vector2(80,0)})
	_step(1.1)
	game.talent_combat.runtime(1).pet_auto=[false,false]
	game.talent_combat.runtime(1).pet_cds.clear()
	game.talent_combat.pet_cast(1,0,true)
	_step(0.96)
	await _photo("05-knochenwelle")
	game.lab_action("spec","soul")
	game.talent_combat.cast(1,"soul_3")
	_step(1.7)
	await _photo("06-seelenring")
	game.queue_free()
	await process_frame
	await _make(true)
	game.talent_combat.cast(1,"beast_14")
	_step(0.4)
	await _photo("07-wuermer-spucken")
	_step(0.8)
	await _photo("08-wuermer-felder")
	game.lab_action("reset",null)
	game.talent_combat.cast(1,"beast_6",{"target":Vector2(game.players[1].pos)+Vector2(100,-80)})
	await _photo("09-geriggte-falle")
	var screen := preload("res://src/ui/talent_screen.gd").new()
	game.ui.add_child(screen)
	# Explicit presentation fixture, mirroring the already max-rank training build.
	var build: Dictionary = game.talent_combat.runtime(1)
	game.progress.profile.classes.archer.level=30
	game.progress.profile.classes.archer.ranks=build.ranks.duplicate()
	game.progress.profile.classes.archer.ultimate="beast_14"
	game.progress.profile.debug_free=true
	screen.open(game.progress.data,game.progress.profile,game.progress.save_path,"archer")
	screen.selected="beast_14"
	screen._refresh()
	await _photo("10-waldmeister-baum")
	game.queue_free()
	await process_frame
	print("NECRO_FOREST_CAPTURE images=10 native=1280x720")
	quit()
func _step(seconds: float) -> void:
	for n in range(ceili(seconds*60)): game._step_world(1.0/60)
func _photo(name: String) -> void:
	game._broadcast_state(true)
	game._refresh_ui()
	game.view.set_state(game.state,1)
	game._update_camera(0.016)
	game.lab_art.queue_redraw()
	for frame in range(600):
		await process_frame
		var pools: RefCounted = game.view._talent_fx.pools
		var ready: bool = pools!=null and pools.pool_field.pending()==0 and pools._laying.is_empty()
		if ready:
			for field: Dictionary in pools._fields.values():
				if field.has("work"): ready=false
		if frame>25 and ready: break
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dest.path_join(name+".png"))
