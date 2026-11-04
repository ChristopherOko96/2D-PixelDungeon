extends "res://scripts/capture_soul_absorption.gd"
## Actual Krypta renderer, legal ring cast and the boss runtime's real force-front hook.
const MATTER_OUT := "res://output/soul-matter"

func _capture(me: Vector2, source: Vector2, _room: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATTER_OUT))
	var tc = game.talents.tc
	# Prefer a genuinely open spot on this generated map, without deleting props
	# or walls just to obtain a circular screenshot.
	var best_score := -INF
	for r: Dictionary in game.W.rooms:
		if str(r.type)!="combat": continue
		for cell: Vector2i in r.cells:
			var point := (Vector2(cell)+Vector2(0.5,0.8))*96
			if game.box_blocked(game._player_box(point.x,point.y)): continue
			var coverage := 0
			for i in range(20):
				if game._floor_open(point+Vector2.from_angle(i*TAU/20)*160): coverage+=1
			var score := coverage*10000-point.distance_to(me)
			if score>best_score:
				best_score=score
				me=point
	game.player.x=me.x
	game.player.y=me.y
	game.camera.position=me+Vector2(-50,-20)
	game.camera.reset_smoothing()
	var info: Dictionary = tc.data.talents.soul_3
	var ranks := {}
	var needed := int(tc.data.tiers[str(int(info.tier))].points)
	for id: String in tc.data.talents:
		var other: Dictionary = tc.data.talents[id]
		if str(other.spec)!="soul" or int(other.tier)>=int(info.tier) or needed<=0: continue
		var take := mini(int(other.ranks),needed)
		ranks[id] = take
		needed -= take
	ranks.soul_3 = 1
	tc.set_build(1,{"class":"necromancer","level":30,"ranks":ranks,"bar":["soul_3"]})
	game.talents._sync_hero()
	assert(tc.cast(1,"soul_3"))
	var origin := me+Vector2(-90,-30)
	var max_offset := 0.0
	var max_pixels := 0
	for frame in range(276):
		var dt := 1.0/60
		game.state.t = 20.0+frame*dt
		tc.step(dt)
		game.story_hero.update(dt)
		game.feel.update(dt)
		if frame>=150 and frame<180:
			var r0 := (frame-150)*16.0
			game.monsters._blow_front({"p":origin},r0,r0+16,0,TAU,1,1)
		game.actors.queue_redraw()
		game.hud.queue_redraw()
		game.story_glow.frame()
		await process_frame
		await RenderingServer.frame_post_draw
		var current_offset:=0.0
		if game.pools != null:
			for n: Dictionary in game.pools.surface.nodes.values(): current_offset=maxf(current_offset,Vector2(n.d).length())
		max_offset=maxf(max_offset,current_offset)
		max_pixels = maxi(max_pixels,game.feel.feedback.particles.count())
		if frame%2==0:
			root.get_texture().get_image().save_png(MATTER_OUT.path_join("frame-%03d.png"%frame))
		if frame in [140,160,170,180,250]:
			root.get_texture().get_image().save_png(MATTER_OUT.path_join("sample-%03d.png"%frame))
			print("SOUL_MATTER_CAPTURE frame=%d particles=%d displacement=%.3f"%[frame,game.feel.feedback.particles.count(),current_offset])
	assert(max_offset>2,"real boss force must move a visible material surface")
	assert(max_pixels>10 and max_pixels<=900,"physical soul pixels use the existing budget")
	print("SOUL_MATTER_CAPTURE max_offset=%.3f max_pixels=%d"%[max_offset,max_pixels])
	print("SOUL_MATTER_CAPTURE pool_draw_mean_us=%.1f"%[float(game.pools.draw_us)/maxi(1,int(game.pools.draw_frames))])
