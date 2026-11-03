extends Node2D
## Thin targeting/attack guides over the real rigs, fields and particles.
## All reach and hit shapes come from the actual talent/AI data.
var lab: Node

func _ring(at: Vector2, radius: float, color: Color, progress := -1.0) -> void:
	if radius<=0: return
	for n in range(40):
		var a := n*TAU/40.0
		var b := (n+0.65)*TAU/40.0
		if lab.talent_combat._blocked(at,at+Vector2.from_angle((a+b)*0.5)*radius,0): continue
		draw_arc(at,radius,a,b,4,color,2,false)
	if progress>=0: draw_arc(at,radius+3,-PI*0.5,-PI*0.5+TAU*clampf(progress,0,1),96,Color(color,0.9),2,false)

## The same host-clamped cast center and radius as the selected actual talent.
func preview() -> Dictionary:
	var tc: RefCounted = lab.talent_combat
	var rt: Dictionary = tc.runtime(1)
	if not tc.data.talents.has(str(lab.lab_preview)): return {}
	var info: Dictionary = tc._info(rt,str(lab.lab_preview))
	var hero: Dictionary = lab.players.get(1,{})
	if hero.is_empty(): return {}
	var mouse: Vector2 = lab.view.to_local(lab.get_global_mouse_position())
	if lab.scripted_target.is_finite(): mouse = lab.scripted_target
	var center := Vector2(hero.pos)
	if str(info.type)=="zone": center = tc.zone_center(hero,mouse)
	elif str(info.type)=="trap": center=tc._move(hero.pos,(mouse-Vector2(hero.pos)).limit_length(6*float(tc.data.meter_px)),10)
	elif str(info.type)=="blood_mark": center = tc._move(hero.pos,(mouse-Vector2(hero.pos)).limit_length(float(info.reach_m)*float(tc.data.meter_px)),2)
	var radius: float = tc._value(info,"radius_m",rt,str(lab.lab_preview))*float(tc.data.meter_px)
	return {"center":center,"r":radius,"info":info,"mouse":mouse}

func _draw() -> void:
	if not lab.lab_ready or lab.pause_open: return
	var hero: Dictionary = lab.players.get(1,{})
	if hero.is_empty(): return
	var at := Vector2(hero.pos)
	var color := Color(str(lab.lab_cfg.specs[lab.lab_spec].color))
	if lab.lab_rings:
		var rt: Dictionary = lab.talent_combat.runtime(1)
		if str(lab.lab_spec)=="curse":
			var info: Dictionary = lab.talent_combat._info(rt,"curse_9")
			_ring(at,lab.talent_combat._value(info,"radius_m",rt,"curse_9")*float(lab.talent_combat.data.meter_px),Color(Color("b64d68"),0.3))
		for pet: Dictionary in lab.talent_combat.pets:
			if float(pet.hp)>0: _ring(Vector2(pet.pos)+Vector2(0,8),14,Color(color,0.55))
	if lab.lab_aiming:
		var p := preview()
		if not p.is_empty():
			var radius := float(p.r)
			if radius>0: _ring(p.center,radius,Color(color,0.85))
			else:
				var end: Vector2 = lab.talent_combat._move(at,(Vector2(p.mouse)-at).limit_length(320),2)
				draw_line(at,end,Color(color,0.5),2,false)
				_ring(end,12,Color(color,0.9))
	for enemy: Dictionary in lab.enemies:
		if float(enemy.hp)<=0 or str(enemy.get("attack",""))!="windup": continue
		var kind := str(enemy.get("attack_kind",""))
		var cfg: Dictionary = lab.crypt_ai._attack(kind)
		var origin := Vector2(enemy.pos)
		var progress := 1-float(enemy.attack_time)/maxf(0.01,float(enemy.attack_length))
		var danger := Color(Color("ed8d70"),0.72)
		if kind=="explode": _ring(origin,float(cfg.get("radius",72)),danger,progress)
		elif kind in ["slash","bite","slam"]:
			var radius := float(cfg.get("range",56))
			var aim := Vector2(enemy.attack_aim).angle()
			var arc := acos(clampf(float(cfg.get("arc_dot",0.35)),-1,1))
			draw_arc(origin,radius,aim-arc,aim+arc,32,danger,3,false)
			draw_line(origin,origin+Vector2.from_angle(aim-arc)*radius,danger,2,false)
			draw_line(origin,origin+Vector2.from_angle(aim+arc)*radius,danger,2,false)
