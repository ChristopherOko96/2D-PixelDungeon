extends "res://tests/hell_talents_test.gd"
## Story timers feed the shared cosmetic owner in both real scene adapters.
const ExposureHost = preload("res://src/hell/story_exposure_host.gd")
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const OUT := "res://production/qa/evidence/enemy-status/"
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 720)
	for scene: PackedScene in [HellScene, FrostScene, KryptaScene]:
		var game := await _new("archer", "trapper", scene)
		var host := ExposureHost.new(game)
		var kinds := ["burn", "poison", "wet"]
		for n in range(kinds.size()):
			var offset := Vector2(130+n*100, 0)
			var target: Dictionary
			if scene == HellScene:
				game.monsters.spawn(game.state.room, Vector2(game.player.x, game.player.y) + offset, "kettenschinder")
				target = game.mobs[-1]
				target.spawn = 0.0
				target.hp = 400
				target.max = 400
			else: target = _mob(game, offset)
			host.set_status(target, kinds[n], 0.01, 10)
		game.feel.update(1.0 / 60)
		for target: Dictionary in game.mobs:
			check(not target.feel_e.statuses.is_empty(), "actual story status reaches presentation")
		for frame in range(45):
			game.state.t = float(game.state.t) + 1.0 / 60
			game.story_hero.update(1.0 / 60)
			game.feel.update(1.0 / 60)
			game.actors.queue_redraw()
			await process_frame
		var seen: Dictionary = {}
		for p: Dictionary in game.feel.feedback.particles._particles:
			if p.has("status_kind"): seen[p.status_kind] = true
		check(seen.has("burn") and seen.has("poison") and seen.has("wet"), "all three story effects emit in shared solver")
		await RenderingServer.frame_post_draw
		var name := "04-hell" if scene == HellScene else "05-frost" if scene == FrostScene else "06-krypta"
		root.get_texture().get_image().save_png(OUT + name + ".png")
		root.get_texture().get_image().get_region(Rect2i(660,275,300,130)).save_png(OUT + name + "-detail.png")
		await _free(game)
	print("ENEMY_STATUS_STORY checked=%d failures=%d images=3 training=true" % [checked, failures.size()])
	quit(1 if not failures.is_empty() else 0)
