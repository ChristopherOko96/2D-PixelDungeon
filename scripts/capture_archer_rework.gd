extends "res://scripts/capture_necro_forest.gd"
## Current renderer, controlled training states. No earned campaign claim.
const OUT := "res://production/qa/evidence/archer-rework"
var capture_out:=OUT
func _start() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _make(true)
	game.lab_action("spec","sniper")
	game.lab_action("clear",null)
	for n in range(3):
		var enemy: Dictionary=game._create_enemy("skelet",Vector2(760+n*64,480))
		enemy.hp=10000
		enemy.max_hp=10000
		enemy.speed=0
		enemy.lab_dummy=true
		game.enemies.append(enemy)
	game.players[1].aim=Vector2.RIGHT
	game.players[1].face=1
	game.talent_combat.cast(1,"sniper_5")
	await _photo("01-jaegermal")
	game.talent_combat.runtime(1).gcd=0
	game.talent_combat.runtime(1).res=100
	game.talent_combat.cast(1,"sniper_14",{"aim":Vector2.RIGHT})
	game.talent_combat.step(1.0)
	await _photo("02-himmelsspeer-laden")
	game.talent_combat.SoulCharge.hold(game.talent_combat,1,false,Vector2.RIGHT)
	game.talent_combat.step(0.12)
	await _photo("03-himmelsspeer-anpinnen")
	await _tree("sniper_14","04-scharfschuetzen-baum")
	game.lab_action("spec","trapper")
	game.lab_action("clear",null)
	var points: Array[Vector2]=[Vector2(540,410),Vector2(650,365),Vector2(760,410),Vector2(550,560),Vector2(670,590),Vector2(800,540)]
	for n in range(6):
		var rt: Dictionary=game.talent_combat.runtime(1)
		rt.gcd=0
		rt.res=100
		game.talent_combat.cast(1,"trapper_3" if n<3 else "trapper_5",{"target":points[n]})
	game.talent_combat.step(0.6)
	await _photo("05-sechs-grosse-fallen")
	await _tree("trapper_3","06-fallensteller-baum")
	game.queue_free()
	await process_frame
	print("ARCHER_CAPTURE images=6 native=1280x720 controlled=true")
	quit()
func _tree(talent: String, name: String) -> void:
	var screen:=preload("res://src/ui/talent_screen.gd").new()
	game.ui.add_child(screen)
	var build: Dictionary=game.talent_combat.runtime(1)
	game.progress.profile.classes.archer.level=30
	game.progress.profile.classes.archer.ranks=build.ranks.duplicate()
	game.progress.profile.classes.archer.ultimate=str(build.ultimate)
	game.progress.profile.debug_free=true
	screen.open(game.progress.data,game.progress.profile,game.progress.save_path,"archer")
	screen.selected=talent
	screen._refresh()
	await _photo(name)
	screen.queue_free()
	await process_frame
func _photo(name: String) -> void:
	game._broadcast_state(true)
	game._refresh_ui()
	game.view.set_state(game.state,1)
	game._update_camera(0.016)
	game.lab_art.queue_redraw()
	for frame in range(600):
		await process_frame
		var pools: RefCounted=game.view._talent_fx.pools
		var ready: bool=pools!=null and pools.pool_field.pending()==0 and pools._laying.is_empty()
		if ready:
			for field: Dictionary in pools._fields.values():
				if field.has("work"): ready=false
		if frame>25 and ready: break
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_out.path_join(name+".png"))
