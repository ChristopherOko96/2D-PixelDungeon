extends "res://tests/hell_talents_test.gd"
## Real Krypta renderer: physical ground, actual steam blindness and UI-selected replacement.
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const OUT := "res://production/qa/evidence/alchemist-followup/"
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,720)
	clear_fixture_profile()
	var game := await _new("archer","trapper",KryptaScene)
	var at := Vector2(game.player.x,game.player.y)
	for id: String in ["trapper_1","trapper_3","trapper_5","trapper_7"]: game.talents.tc.runtime(1).ranks[id] = 3
	await lay(game,"trapper_1",at+Vector2(150,0))
	await advance_scene(game,0.8)
	await photo("01-poison-puddle")
	await lay(game,"trapper_3",at-Vector2(150,0))
	await lay(game,"trapper_5",at+Vector2(0,160))
	await lay(game,"trapper_7",at-Vector2(0,160))
	await advance_scene(game,0.8)
	await photo("02-four-ground-surfaces")
	game.monsters.zones.clear()
	game._pool_layer().clear()
	game.talents.tc.alchemist.clear()
	await lay(game,"trapper_3",at+Vector2(140,0))
	await lay(game,"trapper_5",at+Vector2(140,0))
	await advance_scene(game,0.3)
	# Place the training enemy IN an actual dense steam puff; an earlier fixture
	# let it walk out before the water boiled and therefore never entered steam.
	var steam_at := at+Vector2(140,0)
	for cloud: Dictionary in game.gas.gas_field._clouds.values():
		if str(cloud.mat)=="steam" and not cloud.puffs.is_empty():
			steam_at = cloud.puffs[0].p
			break
	var target := _mob(game,steam_at-at)
	game._update_mobs(1.0/60)
	await advance_scene(game,0.08)
	check(float(target.get("sight_blind_s",0))>0,"actual boiling-water steam blinds captured enemy")
	await photo("03-steam-blind")
	await _free(game)
	clear_fixture_profile()
	game = await _new("archer","beast",KryptaScene)
	await advance_scene(game,0.2)
	await photo("04-wolf")
	game.open_run_talents()
	game.run_talents._cycle_companion()
	await photo("05-bear-selected")
	game.run_talents.close()
	game.talents._with_sync(func(): check(game.talents.tc.cast(1,"beast_1"),"paid UI-selected replacement in GPU scene"))
	await advance_scene(game,0.3)
	check(str(game.talents.tc.permanent_pet(1).kind)=="bear","new bear really appears in captured story")
	await photo("06-bear-summoned")
	await _free(game)
	print("FOLLOWUP_CAPTURE checked=%d failures=%d images=6 training=true actual_story=true" % [checked,failures.size()])
	quit(1 if not failures.is_empty() else 0)

func lay(game: Node, id: String, point: Vector2) -> void:
	var tc: RefCounted = game.talents.tc
	tc.runtime(1).gcd = 0.0
	tc.runtime(1).res = tc.runtime(1).res_max
	tc.runtime(1).cds[id] = 0.0
	game.talents._with_sync(func(): check(tc.cast(1,id,{"target":point}),"paid captured cast "+id))
	await advance_scene(game,0.55)
	game.talents._with_sync(func(): tc.alchemist.detonate(tc,1,point,180))

func advance_scene(game: Node, seconds: float) -> void:
	for frame in range(ceili(seconds*60)):
		var dt := 1.0/60
		game.state.t = float(game.state.t)+dt
		game.talents.update(dt)
		game._step_gas(dt)
		game._step_elements(dt)
		game._update_mobs(dt)
		game.story_hero.update(dt)
		game.feel.update(dt)
		game.actors.queue_redraw()
		await process_frame

func photo(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func clear_fixture_profile() -> void:
	var file := "user://hell_talents_test_profile.json"
	if FileAccess.file_exists(file): DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
