extends "res://tests/hell_talents_test.gd"
## Actual story scenes, isolated training profiles and real casts. Not a played campaign.
const OUT := "res://production/qa/evidence/marksman-sprites/"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,720)
	for scene: PackedScene in [HellScene,FrostScene]:
		var game := await _new("archer","sniper",scene)
		# _new stops simulation; let presentation prepare its terrain before casting.
		for n in range(10): await process_frame
		var tc: RefCounted = game.talents.tc
		var at := Vector2(game.player.x,game.player.y)
		check(tc.cast(1,"sniper_7",{"aim":Vector2.RIGHT,"target":at+Vector2(200,0)}),"real story volley "+scene.resource_path)
		for n in range(8):
			game.state.t = float(game.state.t)+1.0/60
			game.talents.update(1.0/60)
			game.story_hero.update(1.0/60)
			game.queue_redraw()
			for child: Node in game.get_children():
				if child is CanvasItem: (child as CanvasItem).queue_redraw()
			await process_frame
		await RenderingServer.frame_post_draw
		var name := "story-frost" if scene == FrostScene else "story-hell"
		root.get_texture().get_image().save_png(OUT+name+".png")
		await _free(game)
	print("MARKSMAN_STORY_CAPTURE checked=%d failures=%d images=2 training=true"%[checked,failures.size()])
	quit(1 if not failures.is_empty() else 0)
