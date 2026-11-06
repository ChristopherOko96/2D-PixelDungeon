extends "res://tests/hell_talents_test.gd"
## Actual projectile hits in both current story scenes, isolated training profile.
const OUT := "res://production/qa/evidence/hit-rig/"
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,720)
	for scene: PackedScene in [HellScene,FrostScene]:
		var game := await _new("archer","sniper",scene)
		var target := _mob(game,Vector2(150,0))
		game.feel.update(1.0/60)
		var hp_before := float(target.hp)
		var at := Vector2(game.player.x,game.player.y)
		check(game.talents.tc.cast(1,"sniper_1",{"aim":Vector2.RIGHT,"target":at+Vector2(200,0)}),"actual story cast")
		var impact := false
		for frame in range(90):
			game.state.t = float(game.state.t)+1.0/60
			game.talents.update(1.0/60)
			game.story_hero.update(1.0/60)
			game.feel.update(1.0/60)
			game.actors.queue_redraw()
			await process_frame
			if not game.feel.feedback.hit_rigs.live.is_empty():
				impact = true
				break
		check(impact and float(target.hp)<hp_before,"actual damaging collision drives story rig")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+("03-hell-hit.png" if scene==HellScene else "04-frost-hit.png"))
		await _free(game)
	print("HIT_RIG_STORY checked=%d failures=%d images=2 training=true"%[checked,failures.size()])
	quit(1 if not failures.is_empty() else 0)
