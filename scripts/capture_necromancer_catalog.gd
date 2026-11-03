extends "res://scripts/capture_necro_rigs.gd"
## Real game recordings for one interactive Necromancer catalogue; controlled fixtures.
const CATALOG := "res://production/qa/evidence/necromancer-catalog"
const Icons = preload("res://src/ui/talent_icons.gd")
var scene_game: Node
var combat: RefCounted
var metadata: Array = []
var catalog_path := CATALOG
var capture_scale := 1

func _run() -> void:
	if "--hq" in OS.get_cmdline_user_args():
		catalog_path += "-hq"
		capture_scale = 2
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(catalog_path))
	scene_game = Game.new()
	root.add_child(scene_game)
	await process_frame
	scene_game.view.set_audio_enabled(false)
	scene_game.progress.save_path = "user://necromancer_catalog_capture.json"
	scene_game.session_bind_ip = "127.0.0.1"
	var probe := PacketPeerUDP.new()
	probe.bind(0,"127.0.0.1")
	scene_game.port_input.text = str(probe.get_local_port())
	probe.close()
	scene_game._host_session()
	for draw in range(120): await process_frame
	scene_game.player_classes[1] = "necromancer"
	scene_game.requested_seed = 4242
	scene_game._begin_run()
	scene_game.set_process(false)
	scene_game.set_physics_process(false)
	scene_game.hordes.enabled = false
	scene_game.main_menu.hide()
	combat = scene_game.talent_combat
	var cases: Array = []
	for index in range(3):
		var spec: Dictionary = combat.data.classes.necromancer.specs[index]
		for id: String in spec.talents:
			if str(combat.data.talents[id].kind) in ["active","ultimate"]: cases.append({"id":id,"spec":index})
	cases.append_array([{"id":"basic","spec":2},{"id":"defense","spec":2},{"id":"shield_bash","spec":0},{"id":"bone_shout","spec":0},{"id":"bone_stomp","spec":0},{"id":"bone_whirl","spec":0},{"id":"guardian_beam","spec":2},{"id":"guardian_wave","spec":2},{"id":"archer_death","spec":0},{"id":"curse_death","spec":1}])
	for index in range(3):
		var ultimate: String = ["minion_14","curse_14","soul_14"][index]
		for stage in [1,2]: cases.append({"id":ultimate+"_stage_"+str(stage+1),"talent":ultimate,"spec":index,"stage":stage})
	cases.append({"id":"soul_9_tap","talent":"soul_9","spec":2})
	cases.append_array([{"id":"curse_wave","spec":1},{"id":"curse_brood","spec":1}])
	var expected := cases.size()
	var args := OS.get_cmdline_user_args()
	if "--curse-evolution" in args:
		var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path.path_join("catalog.json")))
		var changed := ["curse_1","curse_14","curse_14_stage_2","curse_14_stage_3","curse_wave","curse_brood"]
		metadata = previous.cases.filter(func(e:Dictionary)->bool:return str(e.id) not in changed)
		cases = cases.filter(func(e:Dictionary)->bool:return str(e.id) in changed)
	elif "--only" in args:
		var selected := str(args[args.find("--only")+1])
		var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path.path_join("catalog.json")))
		metadata = previous.cases.filter(func(e:Dictionary)->bool:return str(e.id)!=selected)
		cases = cases.filter(func(e:Dictionary)->bool:return str(e.id)==selected)
	elif "--curse-ultimates" in args:
		var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path.path_join("catalog.json")))
		metadata = previous.cases.filter(func(e:Dictionary)->bool:return str(e.get("talent",e.id))!="curse_14")
		cases = cases.filter(func(e:Dictionary)->bool:return str(e.get("talent",e.id))=="curse_14")
	elif "--append-variants" in args:
		var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path.path_join("catalog.json")))
		metadata = previous.cases.filter(func(e:Dictionary)->bool:return not "_stage_" in str(e.id) and str(e.id)!="soul_9_tap")
		cases = cases.filter(func(e:Dictionary)->bool:return "_stage_" in str(e.id) or str(e.id)=="soul_9_tap")
	for entry: Dictionary in cases: await _record(entry)
	assert(metadata.size()==expected,"every requested catalogue case must have a valid completed recording")
	var file := FileAccess.open(catalog_path.path_join("catalog.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":15*capture_scale,"width":320*capture_scale,"height":180*capture_scale,"cases":metadata,"talents":combat.data,"scope":"Actual controlled Godot recordings; not an earned campaign or performance result."}," "))
	print("NECROMANCER_CATALOG complete cases=",metadata.size())
	scene_game._leave_session()
	scene_game.queue_free()
	await process_frame
	quit()

func _step(dt: float) -> void:
	combat.step(dt)
	scene_game._simulate_bullets(dt)
	scene_game.perk_combat.step_statuses(dt)
	scene_game.boss_moves.update(dt)

func _enemy(at: Vector2) -> Dictionary:
	var enemy: Dictionary = scene_game._create_enemy("skelet",at)
	enemy.hp = 5000
	enemy.max_hp = 5000
	enemy.speed = 0
	scene_game.enemies.append(enemy)
	return enemy

func _cast(id: String) -> void:
	var player: Dictionary = scene_game.players[1]
	assert(combat.cast(1,id,{"aim":Vector2.RIGHT,"target":Vector2(player.pos)+Vector2(110,0)}),"catalogue must execute real cast: "+id+" blocker="+combat.cast_blocker(1,id))

func _record(entry: Dictionary) -> void:
	var id := str(entry.id)
	var talent := str(entry.get("talent",id))
	var index := int(entry.spec)
	combat.reset(119+metadata.size())
	scene_game.enemies.clear()
	scene_game.bullets.clear()
	scene_game.boss_moves.zones.clear()
	scene_game.phase = "combat"
	scene_game.players[1].pos = Vector2(390,250)
	scene_game.players[1].aim = Vector2.RIGHT
	scene_game.players[1].cheat_god = true
	scene_game.players[1].hit_flash = 0
	scene_game.players[1].knockback = Vector2.ZERO
	scene_game.current_layout = {"id":"catalog-"+id,"template_id":"catalog-"+id,"generator_version":4,"world_size":[896,480],"tile_size":32,"play_bounds":[32,32,832,416],"obstacles":[],"exits":[],"boss":false,"render_style":"classic_quiet","decoration_enabled":false}
	scene_game._room_layout_revision += 1
	var spec: Dictionary = combat.data.classes.necromancer.specs[index]
	var bar: Array = []
	for talent_key: String in spec.talents:
		if str(combat.data.talents[talent_key].kind)=="active" and bar.size()<4: bar.append(talent_key)
	_build(combat,index,bar)
	combat.runtime(1).soul_tier = int(entry.get("stage",0))
	combat.runtime(1).pet_auto = [false,false]
	if index==0 and id!="minion_1":
		_cast("minion_1")
		for tick in range(75): _step(1.0/60)
	if id in ["bone_stomp","bone_whirl"]:
		combat.permanent_pet(1).blood = 100.0
		_cast("minion_14")
		for tick in range(75): _step(1.0/60)
	if id in ["guardian_beam","guardian_wave"]:
		_cast("soul_14")
		for tick in range(60): _step(1.0/60)
		combat.guardians.actors[0].autos = [false,false]
	if id=="archer_death":
		_cast("minion_9")
		for tick in range(75): _step(1.0/60)
	if talent=="minion_14": combat.permanent_pet(1).blood = 100.0
	for offset: Vector2 in [Vector2(80,-42),Vector2(115,0),Vector2(75,55),Vector2(145,65)]: _enemy(Vector2(scene_game.players[1].pos)+offset)
	if id in ["curse_wave","curse_brood"]:
		_cast("curse_14")
		scene_game._damage_enemy(scene_game.enemies[1],99999,Vector2.RIGHT,1,true,false)
		for tick in range(65): _step(1.0/60)
		assert(not combat.command_pet(1).is_empty(),"actual enemy death must manifest giant before its commands")
	if id=="shield_bash": scene_game.enemies[0].pos = Vector2(combat.permanent_pet(1).pos)+Vector2(20,0)
	if id=="minion_3":
		scene_game.enemies.clear()
		for x in [80,130,185]: _enemy(Vector2(scene_game.players[1].pos)+Vector2(x,0))
	if id=="minion_7":
		var dead := _enemy(Vector2(scene_game.players[1].pos)+Vector2(110,0))
		scene_game._damage_enemy(dead,99999,Vector2.RIGHT,1,true,false)
	if id=="curse_11":
		_cast("curse_3")
		for tick in range(75): _step(1.0/60)
		combat.necromancer.pool(combat,1,"poison",Vector2(scene_game.players[1].pos)+Vector2(90,0),35,8,true)
	scene_game.view.reset_feedback()
	scene_game.view._talent_fx = scene_game.view.TalentFx.new()
	scene_game.view._talent_fx.rigs = scene_game.view._rigs
	scene_game.view._talent_fx.necro_staff = Callable(scene_game.view._hero_look,"staff_socket")
	var frames := 46
	if talent in ["minion_1","minion_9","minion_14","curse_3","curse_9","curse_death","guardian_beam","guardian_wave"]: frames = 61
	if talent in ["minion_5","curse_7","curse_14","soul_3","soul_7","soul_11","soul_14"]: frames = 91
	if id in ["curse_wave","curse_brood"]: frames = 91
	var folder := catalog_path.path_join(id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for captured_frame in range(frames*capture_scale):
		var frame := captured_frame/capture_scale
		var trigger := captured_frame%capture_scale==0
		var age := captured_frame/(15.0*capture_scale)
		if id=="guardian_beam" and frame>7:
			# Deliberate moving target: the real host beam must remain attached.
			scene_game.enemies[1].pos = Vector2(scene_game.players[1].pos)+Vector2(115,sin((age-0.5)*1.5)*55)
		if trigger and frame==3:
			if combat.data.talents.has(talent): _cast(talent)
			elif id=="curse_death": _cast("curse_9")
			elif id in ["shield_bash","bone_shout","bone_stomp","bone_whirl"]: assert(combat.pet_cast(1,0 if id in ["shield_bash","bone_stomp"] else 1,true))
			elif id in ["guardian_beam","guardian_wave"]: assert(combat.pet_cast(1,0 if id=="guardian_beam" else 1,true))
			elif id in ["curse_wave","curse_brood"]: assert(combat.pet_cast(1,0 if id=="curse_wave" else 1,true))
		if trigger and id=="soul_9" and frame==28: combat.SoulCharge.hold(combat,1,false,Vector2.RIGHT)
		if trigger and id=="soul_9_tap" and frame==5: combat.SoulCharge.hold(combat,1,false,Vector2.RIGHT)
		if trigger and id=="minion_14_stage_3" and frame==40: combat.permanent_pet(1).hp = 0
		if trigger and id=="minion_11" and frame==12: combat.incoming(1,5,Vector2.RIGHT)
		if trigger and talent in ["minion_5","curse_7","curse_14","curse_death"] and frame==15:
			var victim: Dictionary = scene_game.enemies[0 if id=="curse_death" else 1]
			scene_game._damage_enemy(victim,99999,Vector2.RIGHT,1,true,false)
		if trigger and id=="archer_death" and frame==12:
			for pet: Dictionary in combat.pets:
				if str(pet.kind)=="bone_archer": pet.hp = 0
		for tick in range(4/capture_scale):
			if trigger and id=="basic" and frame%9==3 and tick==0: scene_game.perk_combat.shoot(1,Vector2.RIGHT)
			if id=="defense": combat.hold(1,false,frame>3 and frame<35,Vector2.INF,Vector2.ZERO)
			_step(1.0/60)
		scene_game.view._clock = 20+metadata.size()*20+age
		scene_game.view._feedback.hitstop = 0
		scene_game._apply_snapshot(scene_game._make_snapshot())
		scene_game.view.set_state(scene_game.state,1)
		scene_game._refresh_ui()
		for draw in range(2): await process_frame
		await RenderingServer.frame_post_draw
		var full := root.get_texture().get_image()
		var detail := full.get_region(Rect2i(320,210,640,360))
		if capture_scale==1: detail.resize(320,180,Image.INTERPOLATE_NEAREST)
		detail.save_png(folder.path_join("frame-%03d.png" % captured_frame))
		if trigger and frame in [15,30,frames-1]: full.save_png(folder.path_join("full-%03d.png" % captured_frame))
	var info: Dictionary = combat.data.talents.get(talent,{"id":id,"name":id,"kind":"command"})
	var icon_info := info
	if id in ["guardian_beam","guardian_wave"]: icon_info = {"icon":"bolt" if id=="guardian_beam" else "ring","kind":"command"}
	var texture: Texture2D = Icons.make(spec,str(icon_info.get("icon","skull")),true,str(info.kind)=="ultimate")
	texture.get_image().save_png(folder.path_join("icon.png"))
	metadata.append({"id":id,"talent":talent,"spec":str(spec.id),"frames":frames*capture_scale,"rank":int(combat.runtime(1).ranks.get(talent,1)),"stage":int(entry.get("stage",0))})
	print("NECROMANCER_CATALOG id=",id," frames=",frames)
