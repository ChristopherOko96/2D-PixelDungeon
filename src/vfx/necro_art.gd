extends RefCounted
## Presentation only. Cutout bone parts use the existing rig texture cache;
## fluid ribbons are continuous joint chains. Ground fields belong to PoolPaint.
const Library = preload("res://src/rig/rig_library.gd")
const Paint = preload("res://src/vfx/pixel_paint.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")
const Bank = preload("res://src/rig/necro_spell_rig.gd")
const BoneBall = preload("res://src/rig/bone_ball_rig.gd")

## One source cutout transformed around its own joint, clipped by FxSprites.
static func bone(canvas: CanvasItem, id: String, at: Vector2, angle: float, art: float, sprites: RefCounted, alpha := 1.0) -> void:
	sprites.draw_external_rig(canvas,Bank.bone_parts(id,at,angle,art,alpha),at)

## Readable corpse tokens independent of the short enemy death animation.
static func corpses(canvas: CanvasItem, state: Dictionary, art: float, sprites: RefCounted) -> void:
	for c: Dictionary in state.get("corpses", []):
		var at := Vector2(c.x, c.y)
		bone(canvas, "skull", at, 1.35, art * 0.75, sprites, clampf(float(c.time), 0, 1))

## A fluid spine bends smoothly between fixed endpoints; beads ride the spine.
static func stream(canvas: CanvasItem, from: Vector2, to: Vector2, clock: float, art: float, seed: int, progress := -1.0, renderer: RefCounted = null) -> void:
	if renderer == null: return
	var fade := 1.0 if progress < 0 else sin(PI*clampf(progress,0,1))
	renderer.draw_external_rig(canvas,Bank.beam_parts(from,to,clock+seed*0.17,art,fade),from.lerp(to,0.5))

## Absorption attaches to the actual skeleton's torso. Gauges use rig top bounds.
static func blood(canvas: CanvasItem, pet: Dictionary, top: float, at: Vector2, clock: float, art: float, sprites: RefCounted, into := Vector2.INF, pools: RefCounted = null) -> void:
	if str(pet.get("kind", "")) not in ["bone_warrior", "blood_colossus"]: return
	if float(pet.get("blood_pending", 0)) > 0 and float(pet.get("blood_wait",0)) <= 0:
		var from := Vector2(pet.get("blood_x",at.x),pet.get("blood_y",at.y))
		var target := into if into.is_finite() else at-Vector2(0,12*art)
		Bank.prepare()
		var cfg: Dictionary = Bank.data.motion.absorption
		var count := int(cfg.particles)
		for n in range(count):
			var angle := n*2.39996+float(pet.id)*0.37
			var origin := from+Vector2(cos(angle),sin(angle)*0.65)*float(pet.get("blood_pool_r",0))*float(cfg.spread)
			if pools != null and not pools.covers(origin,"blood"): origin = from
			var phase := fposmod(clock/float(cfg.cycle_s)+float(n)/count,1.0)
			var point := Bank.absorption_point(origin,target,phase,art)
			var size := art*float(cfg.size)*(0.75+0.25*sin(n*1.7))
			var alpha := smoothstep(0,0.1,phase)*(1-smoothstep(0.88,1,phase))
			alpha *= smoothstep(0,0.1,float(pet.get("blood_draw",0)))*smoothstep(0,4,float(pet.blood_pending))
			sprites.draw_external_rig(canvas,Bank.parts("necro_blood",point,(target-origin).normalized(),clock+n,size,alpha),point)
	var form := float(pet.get("blood_form", 0))
	var fill := clampf(float(pet.get("blood", 0)) / 100.0, 0, 1)
	var pos := Vector2(at.x - 18.0 * art, top - 7.0 * art)
	canvas.draw_rect(Rect2(pos - Vector2.ONE * art, Vector2(38, 5) * art), Color("17131f"))
	canvas.draw_rect(Rect2(pos, Vector2(36.0 * fill, 3) * art), Color("e65c63") if form <= 0 else Color("f2cf91"))
	# Four notches identify the blood threshold without relying on hue alone.
	for n in range(1, 4): canvas.draw_line(pos + Vector2(9 * n, 0) * art, pos + Vector2(9 * n, 3) * art, Color("291827"), art)

## A bounded source-part burst, blood tether or paid lifedrain.
static func event(canvas: CanvasItem, e: Dictionary, p: float, clock: float, art: float, sprites: RefCounted) -> void:
	var at := Vector2(e.x, e.y)
	match str(e.kind):
		"forest_spit":
			var to := Vector2(e.tx,e.ty)
			var aim := (to-at).normalized()
			var color := Color("a0d84c") if str(e.get("kind_name",""))=="poison_worm" else Color("ff9c3b")
			var orb := at.lerp(to,p)-Vector2(0,art*(12+sin(PI*p)*22))
			for n in range(5):
				var point := orb-aim*n*art*3
				var parts: Array = Bank.parts("forest_spit",point,aim,clock+n,art*(0.8-n*0.1),1-float(n)/6)
				for part: Dictionary in parts: part.tint = color*Color(1,1,1,1-float(n)/6)
				sprites.draw_external_rig(canvas,parts,point)
		"necro_bone_release":
			var aim := Vector2.from_angle(float(e.get("angle",0)))
			for n in range(5):
				var point := at+aim*art*(8+p*12)-Vector2(0,10*art)+aim.orthogonal()*(n-2)*art*p*3
				bone(canvas,"leg_l",point,clock+n,art*0.65,sprites,1-p)
		"necro_monster_cast", "necro_curse_wave":
			var wave := str(e.kind)=="necro_curse_wave"
			for n in range(12):
				var angle := n*TAU/12+clock*0.35
				var radius := float(e.r)*(p if wave else 0.2*(1-p))
				var point := at+Vector2(cos(angle),sin(angle)*0.65)*radius-Vector2(0,(12+sin(PI*p)*6)*art)
				if not wave and not bool(e.get("brood",false)):
					bone(canvas,"leg_l",point,clock+n,art*0.8,sprites,sin(PI*p))
				else: sprites.draw_external_rig(canvas,Bank.Curse.parts(point,art*0.35,clock+n,1-p,float(n)),point)
		"necro_bone_wave":
			for n in range(32):
				var angle := n*TAU/32
				var point := at+Vector2.from_angle(angle)*float(e.r)*smoothstep(0,1,p)-Vector2(0,sin(PI*p)*art*7)
				bone(canvas,"skull" if n%5==0 else "leg_l",point,angle+PI*0.5+p*0.4,art*0.85,sprites,1-smoothstep(0.6,1,p))
		"necro_curse_aura":
			for n in range(16):
				var point := at+Vector2.from_angle(n*TAU/16)*float(e.r)*smoothstep(0,1,p)-Vector2(0,p*art*10)
				sprites.draw_external_rig(canvas,Bank.Curse.parts(point,art*0.25,clock,1-p,float(n)),point)
		"necro_impact":
			if str(e.talent)=="curse_1":
				if bool(e.get("curse_spirit",false)):
					sprites.draw_external_rig(canvas,Bank.Curse.parts(at,art*0.7,clock,1-smoothstep(0.2,1,p),float(e.id),Vector2.ZERO,p),at)
					return
				Bank.prepare()
				var cfg: Dictionary = Bank.data.motion.bone_ball
				for n in range(int(cfg.burst_count)):
					var angle := n*2.39996+float(e.id)
					var point := at+Vector2.from_angle(angle)*float(e.r)*float(cfg.burst_reach)*sin(p*PI*0.5)-Vector2(0,sin(PI*p)*art*12)
					bone(canvas,"skull" if n%4==0 else "leg_l",point,angle+p*3,art*0.7,sprites,1-smoothstep(0.35,1,p))
				return
			for n in range(5):
				var angle := n*2.39996+float(e.id)
				var point := at+Vector2.from_angle(angle)*float(e.r)*p
				var kind := "necro_curse" if str(e.talent)=="curse_1" else "necro_spear"
				sprites.draw_external_rig(canvas,Bank.parts(kind,point,Vector2.from_angle(angle),clock+n,art*0.5,1-smoothstep(0.2,1.0,p)),at)
		"necro_drain", "necro_tether":
			var to := Vector2(float(e.tx), float(e.ty))
			stream(canvas, at - Vector2(0, art * 5), to - Vector2(0, art * 7), clock, art, int(e.id), p,sprites)
		"necro_bones":
			if str(e.get("talent","")) == "curse_11":
				for n in range(6):
					var angle := n*TAU/6.0
					var point := at+Vector2.from_angle(angle)*float(e.r)*(1-smoothstep(0,1,p))
					sprites.draw_external_rig(canvas,Bank.parts("curse_spirit",point,-Vector2.from_angle(angle),clock+n,art*0.4,sin(PI*p)),at)
				return
			for i in range(12):
				var angle := TAU * float(i) / 12.0 + float(e.id) * 0.37
				var radius := float(e.r) * (0.12 + 0.78 * sin(p * PI * 0.5))
				var pos := at + Vector2.from_angle(angle) * radius - Vector2(0, sin(p * PI) * art * 10.0)
				bone(canvas, "leg_l" if i % 3 else "torso", pos, angle + p * 2.5, art, sprites, 1.0 - smoothstep(0.6, 1.0, p))

## All fourteen actives use cutout rigs for their cast, without creating a second pool.
static func cast(canvas: CanvasItem, e: Dictionary, at: Vector2, p: float, clock: float, art: float, sprites: RefCounted) -> bool:
	var skill := Bank.skill(str(e.get("talent","")))
	if skill.is_empty(): return false
	if str(e.get("talent",""))=="curse_1": return true # live charge snapshot owns assembly
	var alpha := sin(PI*p)
	var aim := Vector2.from_angle(float(e.get("angle",0)))
	var hand := at-Vector2(0,12*art)+aim*art*5.0
	for n in range(3):
		var angle := n*TAU/3.0+clock*1.2
		var pos := hand+Vector2.from_angle(angle)*art*(7.0-3.0*p)
		sprites.draw_external_rig(canvas,Bank.parts(str(skill.rig),pos,aim,clock+n,art*0.55,alpha),at)
	return true

## A jaw, skull and two delayed tail joints instead of a cycling full frame.
static func projectile(canvas: CanvasItem, shot: Dictionary, clock: float, art: float, sprites: RefCounted) -> bool:
	var id := str(shot.get("talent",""))
	if id not in ["curse_1","minion_3"]: return false
	var kind := "necro_curse" if id == "curse_1" else "necro_spear"
	var at := Vector2(shot.x,shot.y)
	var aim := Vector2(shot.get("vx",1),shot.get("vy",0)).normalized()
	if id=="curse_1":
		if bool(shot.get("curse_spirit",false)) or str(shot.get("style",""))=="curse_spirit":
			sprites.draw_external_rig(canvas,Bank.Curse.parts(at,art*0.55,clock,1,float(shot.get("id",0)),aim),at)
			return true
		Bank.prepare()
		var cfg: Dictionary = Bank.data.motion.bone_ball
		for n in range(int(cfg.trail_count),0,-1):
			var share := float(n)/float(cfg.trail_count)
			var point := at-aim*float(cfg.trail_spacing)*n+aim.orthogonal()*sin(clock*6-n*0.6)*art*share
			bone(canvas,"torso" if n%3==0 else "leg_l",point,clock*2+n,art*lerpf(0.7,0.3,share),sprites,0.7*(1-share*0.8))
		sprites.draw_external_rig(canvas,BoneBall.parts(at,clock,art*1.2),at)
		return true
	sprites.draw_external_rig(canvas,Bank.parts(kind,at,aim,clock,art*1.15),at)
	return true

## Live windup attached to the staff socket; the skull and six bones converge.
static func bone_charge(canvas: CanvasItem, charge: Dictionary, at: Vector2, clock: float, art: float, sprites: RefCounted) -> void:
	var power := clampf(float(charge.power),0,1)
	Bank.prepare()
	var cfg: Dictionary = Bank.data.motion.bone_ball
	var energy: Array = Bank.parts("forest_spit",at,Vector2.RIGHT,clock,art*lerpf(0.45,1.1,power),0.25+power*0.45)
	for part: Dictionary in energy: part.tint = Color(0.74,0.88,0.80,0.25+power*0.45)
	sprites.draw_external_rig(canvas,energy,at)
	for n in range(int(cfg.charge_particles)):
		var angle := n*2.39996
		var arrive := clampf(power*1.6-float(n%4)*0.16,0,1)
		var pos := at+Vector2.from_angle(angle)*art*lerpf(25,2,smoothstep(0,1,arrive))
		bone(canvas,"torso" if n%3==0 else "leg_l",pos,angle+arrive*2,art*0.45,sprites,sin(PI*arrive))
	sprites.draw_external_rig(canvas,BoneBall.parts(at,clock,art*lerpf(0.6,float(cfg.core_scale),power),smoothstep(0,0.12,power),power),at)

## Rigged glyphs on the existing poison material. The material itself remains PoolPaint's.
static func field(canvas: CanvasItem, zone: Dictionary, clock: float, art: float, sprites: RefCounted) -> void:
	var at := Vector2(zone.x,zone.y)
	var radius := float(zone.r)
	var count := 4 if str(zone.talent) == "curse_14" else 3
	var fade := clampf(float(zone.time),0,1)
	for n in range(count):
		var angle := n*TAU/count+float(zone.id)*0.3
		var point := at+Vector2(cos(angle),sin(angle)*0.72)*radius*0.78-Vector2(0,(3+sin(clock*2+n))*art)
		sprites.draw_external_rig(canvas,Bank.parts("curse_spirit",point,Vector2.RIGHT,clock+n,art*0.3,fade),point)

## Staggered vertical ascents; each spirit has a fixed side and never orbits.
static func rising_curses(at: Vector2, clock: float, seed: int) -> Array:
	Bank.prepare()
	var cfg: Dictionary = Bank.data.motion.curse_spirit
	var out: Array = []
	for n in range(int(cfg.count)):
		var p := fposmod(clock/float(cfg.rise_s)+float(n)/float(cfg.count)+seed*0.137,1)
		var side := float(n)-float(cfg.count-1)*0.5
		out.append({"at":at+Vector2(side*float(cfg.spread_px)+sin(p*PI*2+n)*float(cfg.sway_px),4-p*float(cfg.rise_px)),"alpha":smoothstep(0,0.15,p)*(1-smoothstep(0.65,1,p)),"phase":p})
	return out

## Existing eight-part curse source, with continuously bending cloth and jaws.
static func curse_mark(canvas: CanvasItem, at: Vector2, clock: float, art: float, seed: int, fade: float, sprites: RefCounted) -> void:
	Bank.prepare()
	var cfg: Dictionary = Bank.data.motion.curse_spirit
	var samples := rising_curses(at,clock,seed)
	for n in range(samples.size()):
		var point: Vector2 = samples[n].at
		sprites.draw_external_rig(canvas,Bank.Curse.parts(point,art*float(cfg.scale),clock,fade*float(samples[n].alpha),float(n)),point)

## The six articulated blades are depth-split around the companion's own body.
static func storm(canvas: CanvasItem, pet: Dictionary, clock: float, art: float, sprites: RefCounted, front: bool) -> void:
	var w: Dictionary = pet.get("whirl",{})
	if w.is_empty(): return
	var age := float(w.age)
	var ramp := smoothstep(0,float(w.windup),age)*(1-smoothstep(float(w.time)-0.3,float(w.time),age))
	var at := Vector2(pet.x,pet.y)
	for n in range(6):
		var angle := age*5.0+n*TAU/6.0
		if (sin(angle)>=0) != front: continue
		var point := at+Vector2(cos(angle),sin(angle)*0.65)*float(w.r)*ramp-Vector2(0,6*art)
		sprites.draw_external_rig(canvas,Bank.parts("necro_blade",point,Vector2.from_angle(angle+PI*0.5),clock+n,art*0.85,ramp),at)
