extends "res://src/game.gd"
## Isolated, offline, playable Necromancer presentation study. No campaign changes.
const LAB_DATA := "res://assets/data/debug_necro_lab.json"
const LabPanel = preload("res://src/debug/necro_lab_panel.gd")
const LabArt = preload("res://src/debug/necro_lab_art.gd")
var lab_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAB_DATA))
var lab_spec := "curse"
var lab_kit := 0
var lab_auto := true
var lab_god := true
var lab_rings := true
var lab_aiming := false
var lab_preview := "curse_7"
var lab_panel: Control
var lab_art: Node2D
var lab_ready := false

func _ready() -> void:
	progress.save_path = str(lab_cfg.profile_path)
	progress.profile = Profile.fresh(Profile.data())
	player_classes[1] = str(lab_cfg.get("class_id","necromancer"))
	var size: Array = lab_cfg.world_size
	var at: Array = lab_cfg.spawn
	var layout := {"id":"necro-lab","title":str(lab_cfg.title),"grid_x":0,"grid_y":0,"template_id":"necro-lab","generator_version":4,"world_size":[int(size[0]),int(size[1])],"tile_size":32,
		"play_bounds":[32,32,int(size[0])-64,int(size[1])-64],"obstacles":lab_cfg.obstacles.duplicate(true),"exits":[],"boss":false,
		"player_spawns":[at,at,at,at],"enemy_spawns":[],"render_style":"classic_quiet","decoration_enabled":false}
	configure_editor_preview({"crypt_procedural":false},layout,str(lab_cfg.labels.hint))
	super._ready()
	start_editor_preview()
	test_arena = true
	hordes.enabled = false
	view.round_actor_markers = true
	view.shake_scale = 0.25
	pause_menu.set_save_enabled(false)
	editor_return_requested.connect(func(): get_tree().quit())
	lab_spec = str(lab_cfg.default_spec)
	lab_panel = LabPanel.new()
	lab_panel.lab = self
	ui.add_child(lab_panel)
	lab_art = LabArt.new()
	lab_art.lab = self
	view.add_child(lab_art)
	lab_ready = true
	lab_reset()
	get_window().title = str(lab_cfg.title)
	print("NECRO_LAB_READY offline=true class=",str(lab_cfg.get("class_id","necromancer")))

## UI requests are handled by this local authoritative host, never the painter.
func lab_action(action: String, value: Variant) -> void:
	if not lab_ready: return
	match action:
		"spec":
			if not lab_cfg.specs.has(str(value)): return
			lab_spec = str(value)
			lab_kit = 0
			lab_reset()
		"kit":
			lab_kit = clampi(int(value),0,1)
			_lab_build(true)
		"group": _lab_group(false)
		"dummy": _lab_group(true)
		"clear":
			enemies.clear()
			bullets.clear()
		"reset": lab_reset()
		"auto": lab_auto = bool(value)
		"god":
			lab_god = bool(value)
			players[1].cheat_god = lab_god
		"rings": lab_rings = bool(value)
		"preview":
			var rt: Dictionary = talent_combat.runtime(1)
			if str(value) in rt.bar or str(value)==str(rt.ultimate): lab_preview = str(value)
		"souls": talent_combat.runtime(1).res = float(talent_combat.runtime(1).res_max)
		"blood":
			var hero_at := Vector2(players[1].pos)
			for n in range(4):
				var point := hero_at+Vector2.from_angle(n*TAU/4)*80
				if not talent_combat._blocked(hero_at,point,1): talent_combat.necromancer.pool(talent_combat,1,"blood",point,48,20)
	lab_panel.rebuild()
	_broadcast_state(true)
	_refresh_ui()

## Reset only transient training data; no campaign save or persistent reward.
func lab_reset() -> void:
	lab_aiming = false
	talent_combat.reset(4242)
	body_parts.reset(4242)
	boss_moves.reset()
	elements.reset()
	sheet_monsters.reset()
	fx_events.clear()
	bullets.clear()
	enemies.clear()
	commands.clear()
	team_progress.reset(4242)
	perk_combat.reset()
	view.reset_feedback()
	players[1].pos = Vector2(float(lab_cfg.spawn[0]),float(lab_cfg.spawn[1]))
	players[1].hp = int(players[1].max_hp)
	players[1].cheat_god = lab_god
	players[1].knockback = Vector2.ZERO
	players[1].hitstun = 0.0
	_camera_room_id = ""
	phase = "combat"
	reward_open = false
	run_slot = 0
	_lab_build(false)
	_lab_group(false)
	_broadcast_state(true)
	_refresh_ui()

func _lab_build(keep: bool) -> void:
	var data: Dictionary = talent_combat.data
	var selected: Dictionary = lab_cfg.specs[lab_spec]
	var ranks := {}
	var class_id := str(lab_cfg.get("class_id","necromancer"))
	for spec: Dictionary in data.classes[class_id].specs:
		if str(spec.id)!=lab_spec: continue
		for id: String in spec.talents: ranks[id] = int(data.talents[id].ranks)
	var bar: Array = selected.kits[lab_kit].bar.duplicate()
	talent_combat.set_build(1,{"class":class_id,"level":30,"ranks":ranks,"bar":bar,"soul_tier":0},keep)
	var rt: Dictionary = talent_combat.runtime(1)
	# Explicit training build: all ranks, same actual cast/cost/cooldown code.
	rt.ranks = ranks
	rt.bar = bar
	rt.ultimate = str(selected.ultimate)
	rt.pet_auto = [true,false]
	if not keep: rt.res = float(rt.res_max)
	lab_preview = "curse_7" if lab_spec=="curse" and lab_kit==0 else str(bar[1])
	if is_instance_valid(lab_panel): lab_panel.rebuild()

func _lab_group(dummy: bool) -> void:
	var living := enemies.filter(func(e:Dictionary)->bool:return float(e.hp)>0).size()
	var count := mini(1 if dummy else int(lab_cfg.group_count),int(lab_cfg.enemy_cap)-living)
	var at := Vector2(players[1].pos)+Vector2(float(lab_cfg.group_distance),0)
	for n in range(count):
		var point := at if dummy else at+Vector2.from_angle(n*TAU/maxi(1,count))*float(lab_cfg.group_radius)
		point = talent_combat._move(players[1].pos,point-Vector2(players[1].pos),18)
		if point.distance_to(players[1].pos)<48: continue
		var kind := "skeleton_guard" if n%3==0 and not dummy else "skelet"
		var enemy := _create_enemy(kind,point)
		var hp := float(lab_cfg.dummy_hp if dummy else lab_cfg.enemy_hp)
		enemy.hp = hp
		enemy.max_hp = hp
		if body_parts.has_parts(enemy):
			# Reattach after HP tuning so actual part HP sums match the fixture.
			body_parts.attach(enemy,str(enemy.rig))
		enemy.lab_dummy = dummy
		if dummy: enemy.speed = 0.0
		enemies.append(enemy)

## Auto attacks retain the normal interval; talents keep mouse aim independently.
func lab_step(_delta: float) -> void:
	if not lab_ready or pause_open or tree_open or reward_open or menu_open or inventory_panel.open or is_transitioning(): return
	if get_viewport().gui_get_hovered_control()!=null: return
	var hero: Dictionary = players.get(1,{})
	if hero.is_empty() or float(hero.hp)<=0: return
	var rt: Dictionary = talent_combat.runtime(1)
	if not lab_auto or lab_aiming or float(hero.shot_timer)>0 or float(hero.hitstun)>0 or rt.has("soul_charge") or rt.has("soul_leap") or rt.has("bone_charge"): return
	var victim := {}
	var reach := float(lab_cfg.auto_range_m)*float(talent_combat.data.meter_px)
	for enemy: Dictionary in talent_combat._living():
		var gap := Vector2(enemy.pos).distance_to(hero.pos)
		if gap<=reach and not talent_combat._blocked(hero.pos,enemy.pos,1):
			reach = gap
			victim = enemy
	if victim.is_empty(): return
	var aim := (Vector2(victim.pos)-Vector2(hero.pos)).normalized()
	hero.shot_timer = perk_combat.shot_interval(hero)*talent_combat.interval_scale(hero,1)
	inventory.on_attack(hero)
	perk_combat.shoot(1,aim)
	hero_skills.basic_attack(1,hero,aim)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	lab_step(delta)
	if is_instance_valid(lab_art): lab_art.queue_redraw()

func _simulate_enemies(delta: float) -> void:
	var dummies: Array = enemies.filter(func(e:Dictionary)->bool:return bool(e.get("lab_dummy",false)) and float(e.hp)>0)
	for e: Dictionary in dummies: enemies.erase(e)
	super._simulate_enemies(delta)
	enemies.append_array(dummies)

func _check_room_end() -> void:
	pass # This is a training fixture, never campaign clearance/rewards.

func _enemy_fell(enemy: Dictionary, direction: Vector2, owner: int, kill_effects: bool) -> void:
	super._enemy_fell(enemy,direction,owner,kill_effects)
	team_progress.orbs.clear() # Keep real death/corpse/soul rules, no training level cards.

func _refresh_ui() -> void:
	super._refresh_ui()
	if lab_ready:
		run_hud._right.hide()
		menu_button.position.y = 14
		context_hint.text = str(lab_cfg.labels.hint)
		context_hint.visible = not pause_open

func _update_camera(delta: float) -> void:
	if not lab_ready:
		super._update_camera(delta)
		return
	var hero: Dictionary = players.get(1,{})
	if hero.is_empty(): return
	var world := Vector2(float(lab_cfg.world_size[0]),float(lab_cfg.world_size[1]))
	var zoom := float(lab_cfg.camera_zoom)
	view.scale = Vector2(zoom,zoom)
	var visible_area := world_clip.size/zoom
	if _camera_room_id!="necro-lab":
		_camera_room_id = "necro-lab"
		room_camera.reset(hero.pos,world,visible_area)
	var mouse_delta := (get_global_mouse_position()-view.to_global(hero.pos))/zoom
	view.set_world_origin(room_camera.update(hero.pos,mouse_delta,world,visible_area,delta,balance.camera,pause_open)*zoom)

func _input(event: InputEvent) -> void:
	if lab_ready and event is InputEventKey and event.pressed and event.keycode in [KEY_K,KEY_B]:
		get_viewport().set_input_as_handled()
		return
	if lab_ready and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		if run_hud.pet_slot_at(run_hud.get_local_mouse_position())>=0:
			super._input(event)
			return
		if pause_open or inventory_panel.open or get_viewport().gui_get_hovered_control()!=null:
			lab_aiming = false
			return
		if event.pressed: lab_aiming = true
		elif lab_aiming:
			lab_aiming = false
			var at := view.to_local(get_global_mouse_position())
			var rt: Dictionary = talent_combat.runtime(1)
			talent_combat.cast(1,lab_preview,{"target":at,"aim":(at-Vector2(players[1].pos)).normalized(),"slot":maxi(0,rt.bar.find(lab_preview))})
		get_viewport().set_input_as_handled()
		return
	super._input(event)
