extends "res://scripts/capture_soul_absorption.gd"
## Controlled real-story encounter: normal shot, actual corpse, paid soul event.
const CORPSE_OUT := "res://output/soul-from-corpse"

func _capture(me: Vector2, source: Vector2, room: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CORPSE_OUT))
	var best := INF
	for angle in range(16):
		var point := me+Vector2.from_angle(angle*TAU/16)*220
		if game.talents.talent_blocked(me,point,8): continue
		if game.box_blocked(Rect2(point-Vector2(32,30),Vector2(64,52))): continue
		var score := point.distance_to(me+Vector2(-220,0))
		if score<best:
			best=score
			source=point
	assert(best<INF,"corpse encounter needs a real unobstructed shot")
	game.camera.position=(me+source)*0.5-Vector2(0,44)
	game.camera.zoom=Vector2(2,2)
	game.camera.reset_smoothing()
	var enemy: Dictionary=game.monsters.spawn(int(room.index),source,"skelett")
	enemy.spawn=0.0
	enemy.hp=0.5
	enemy.max=0.5
	enemy.sp=0.0
	enemy.hold=true
	enemy.face=signf(me.x-source.x)
	game.state.inv=99.0
	game.talents._sync_mobs()
	game.talents.tc.runtime(1).res=0.0
	var death_frame:=-1
	var saw_corpse:=false
	var saw_soul:=false
	var soul_events: Dictionary={}
	for frame in range(150):
		var dt:=1.0/60
		game.state.t=20.0+frame*dt
		if frame==36:
			game._attack((source-Vector2(me.x,me.y-40)-Vector2(0,float(enemy.cy))).normalized())
			assert(not game.shots.is_empty(),"normal necromancer attack must fire")
		game.talents._sync_hero()
		game.talents._sync_mobs()
		game._update_shots(dt)
		game.monsters.update(dt)
		game.talents.tc.step(dt)
		if game.mobs.is_empty() and death_frame<0:
			death_frame=frame
			print("CORPSE_CAPTURE death_frame=%d corpses=%d"%[frame,game.monsters.corpses.size()])
		saw_corpse=saw_corpse or not game.monsters.corpses.is_empty()
		for e: Dictionary in game.talents.tc.events:
			if str(e.kind)=="souls": soul_events[int(e.id)]=true
		for pixel: Dictionary in game.feel.feedback.particles._particles:
			if bool(pixel.get("soul_head",false)): saw_soul=true
		game.feel.update(dt)
		game.story_hero.update(dt)
		game.actors.queue_redraw()
		game.hud.queue_redraw()
		game.story_glow.frame()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(CORPSE_OUT.path_join("frame-%03d.png"%frame))
	assert(death_frame>36 and saw_corpse and saw_soul,"normal hit must produce a corpse and a physical soul")
	assert(soul_events.size()==1,"exactly one collected soul event for this death")
	print("CORPSE_CAPTURE corpse=%s soul=%s events=%d resource=%.2f"%[saw_corpse,saw_soul,soul_events.size(),float(game.talents.tc.runtime(1).res)])
