extends "res://tests/hell_talents_test.gd"
## Paid charge and release through both actual story runtimes, isolated test profiles.
const OUT:="res://production/qa/evidence/himmelsspeer-rig/"
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size=Vector2i(1280,720)
	for scene: PackedScene in [HellScene,FrostScene]:
		var game:=await _new("archer","sniper",scene)
		game.feel.update(1.0/60)
		var tc: RefCounted=game.talents.tc
		check(tc.cast(1,"sniper_14",{"aim":Vector2.RIGHT}),"actual paid story ultimate begins")
		await step_scene(game,0.8,true)
		check(tc.runtime(1).has("soul_charge"),"training hold preserves actual paid charge")
		var tag:="hell" if scene==HellScene else "frost"
		await photo(tag+"-charge")
		check(game.story_hero.look._bow_sockets.has("hero"),"charge has actual hero bow socket")
		tc.SoulCharge.hold(tc,1,false,Vector2.RIGHT)
		await step_scene(game,0.07)
		await photo(tag+"-flight")
		check(tc.events.any(func(e:Dictionary)->bool:return str(e.get("kind",""))=="spear"),"release reaches the real story renderer")
		await step_scene(game,0.27)
		await photo(tag+"-impact")
		await _free(game)
	print("HIMMELSSPEER_STORY checked=%d failures=%d images=6 training=true"%[checked,failures.size()])
	quit(1 if not failures.is_empty() else 0)
func step_scene(game: Node, seconds: float, held := false) -> void:
	for n in range(ceili(seconds*60)):
		game.state.t=float(game.state.t)+1.0/60
		if held:
			# Same host tick, explicitly held instead of reading this PC's physical R key.
			game.talents._with_sync(func()->void:
				var tc: RefCounted=game.talents.tc
				tc.SoulCharge.hold(tc,1,true,Vector2.RIGHT)
				tc.step(1.0/60)
				game.talents._step_bullets(1.0/60)
				game.talents._step_statuses(1.0/60))
		else: game.talents.update(1.0/60)
		game.story_hero.update(1.0/60)
		game.feel.update(1.0/60)
		game.actors.queue_redraw()
		await process_frame
func photo(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
