extends RefCounted
## The remaining legacy atlas paths: cached native masks, actual joint solver,
## continuous part motion. Does not invent or activate replacement character art.
const Library = preload("res://src/rig/rig_library.gd")
const Renderer = preload("res://src/rig/rig_renderer.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
const PATH := "res://assets/data/cutout_motion.json"
static var config: Dictionary={}
static var cache: Dictionary={}
static var sources: Dictionary={}
static var library: RefCounted
static var renderer: RefCounted

## Build once from the existing native frame, not from a resized screenshot.
static func prepare(texture: Texture2D, name: String, size: Vector2i, frame: int, anchor: Vector2, actor := false) -> Dictionary:
	if config.is_empty(): config=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if library==null: library=Library.new(); renderer=Renderer.new(library)
	var key:="%d:%s:%d:%s"%[texture.get_instance_id(),name,frame,actor]
	if cache.has(key): return cache[key]
	var source_key:=texture.get_instance_id()
	if not sources.has(source_key):
		var source:=texture.get_image()
		if source==null: return {}
		if source.is_compressed(): source.decompress()
		sources[source_key]=source
	var image: Image=sources[source_key].get_region(Rect2i(Vector2i(frame*size.x,0),size))
	var used:=image.get_used_rect()
	if not used.has_area(): return {}
	var x:=used.position.x
	var y:=used.position.y
	var w:=used.size.x
	var h:=used.size.y
	var cx:=x+w*0.5
	var cy:=y+h*0.5
	var defs: Array=[]
	if actor:
		var a: Dictionary=config.actor
		var head:=y+int(h*float(a.head_end))
		var foot:=y+int(h*float(a.leg_start))
		var side:=maxi(1,int(w*float(a.arm_width)))
		if name in config.winged_actors:
			defs.append(_part("arm_l",[x,y,x+side-1,foot-1],Vector2(x+side,cy)))
			defs.append(_part("arm_r",[x+w-side,y,x+w-1,foot-1],Vector2(x+w-side,cy)))
		defs.append(_part("head",[x,y,x+w-1,head-1],Vector2(cx,head)))
		if name not in config.winged_actors:
			defs.append(_part("arm_l",[x,head,x+side-1,foot-1],Vector2(x+side,head+1)))
			defs.append(_part("arm_r",[x+w-side,head,x+w-1,foot-1],Vector2(x+w-side,head+1)))
		defs.append(_part("leg_l",[x,foot,int(cx)-1,y+h-1],Vector2(cx-1,foot)))
		defs.append(_part("leg_r",[int(cx),foot,x+w-1,y+h-1],Vector2(cx+1,foot)))
	elif name in config.get("skulls",[]):
		defs.append(_part("jaw",[x,y+int(h*0.7),x+w-1,y+h-1],Vector2(cx,y+h*0.7)))
	elif name in config.projectiles:
		var split:=x+maxi(1,int(w*0.3))
		defs.append(_part("tip",[x+int(w*0.7),y,x+w-1,y+h-1],Vector2(x+w*0.7,cy)))
		defs.append(_part("tail_l",[x,y,split-1,int(cy)-1],Vector2(split,cy)))
		defs.append(_part("tail_r",[x,int(cy),split-1,y+h-1],Vector2(split,cy)))
	else:
		var side:=maxi(1,int(w*0.3))
		defs.append(_part("edge_l",[x,y,x+side-1,y+h-1],Vector2(x+side,cy)))
		defs.append(_part("edge_r",[x+w-side,y,x+w-1,y+h-1],Vector2(x+w-side,cy)))
		defs.append(_part("edge_up",[x+side,y,x+w-side-1,y+maxi(1,int(h*0.3))-1],Vector2(cx,cy)))
		defs.append(_part("edge_down",[x+side,y+int(h*0.7),x+w-side-1,y+h-1],Vector2(cx,cy)))
	defs.append({"id":"core","rects":[[0,0,size.x-1,size.y-1]],"pivot":[anchor.x,anchor.y],"parent":null,"z":0,"hp":1})
	var rig: Dictionary=library.cutout_frame(key,image,{"family":"cutout","ground":[anchor.x,anchor.y],"width":size.x,"parts":defs,"items":[]})
	cache[key]=rig
	return rig

static func _part(id: String, rect: Array, pivot: Vector2) -> Dictionary:
	return {"id":id,"rects":[rect],"pivot":[pivot.x,pivot.y],"parent":"core","z":1,"hp":1}

## Effects keep their authored frame expansion; joints move between those frames.
static func effect(texture: Texture2D, name: String, size: Vector2i, frame: int, anchor: Vector2, at: Vector2, rotation: float, scale: float, age: float, tint: Color) -> Array:
	var rig:=prepare(texture,name,size,frame,anchor)
	if rig.is_empty(): return []
	var pose:=Poses.blank()
	pose.whole.rot=rotation
	var cfg: Dictionary=config.effect
	if name not in config.rigid_effects:
		for part: Dictionary in rig.parts:
			if str(part.id)=="core": continue
			var phase:=float(str(part.id).hash()&255)*0.1
			var joint:=Poses.P(pose,part.id)
			joint.rot=sin(age*float(cfg.speed)+phase)*float(cfg.tail_swing if name in config.projectiles else cfg.wing_swing if name in config.winged_effects else cfg.joint_swing)
	return _parts(rig,pose,at,1,scale,tint)

## Legacy creatures use bind art with head, arms/wings and legs moving independently.
static func actor(texture: Texture2D, name: String, feet: Vector2, scale: float, face: float, clock: float, state: Dictionary, tint: Color, feedback: Dictionary = {}) -> Array:
	var rig:=prepare(texture,name,Vector2i(texture.get_size()),0,Vector2(texture.get_width()*0.5,texture.get_height()),true)
	if rig.is_empty(): return []
	var pose:=Poses.blank()
	var recoil: Vector2=feedback.get("scale",Vector2.ONE)
	pose.whole.sx=recoil.x
	pose.whole.sy=recoil.y
	pose.whole.rot=float(feedback.get("lean",0))
	feet+=Vector2(feedback.get("offset",Vector2.ZERO))
	var a: Dictionary=config.actor
	var moving:=bool(state.get("moving",false)) or bool(state.get("dash",false))
	var stride:=sin(clock*float(a.walk_speed)+float(int(state.get("id",0))%17)) if moving else 0.0
	Poses.P(pose,"head").rot=sin(clock*float(a.idle_speed))*float(a.head_sway)
	for side in [-1,1]:
		var limb:="l" if side<0 else "r"
		Poses.P(pose,"leg_"+limb).rot=stride*float(side)*float(a.leg_swing)
		Poses.P(pose,"arm_"+limb).rot=-stride*float(side)*float(a.arm_swing)
		if name in config.winged_actors: Poses.P(pose,"arm_"+limb).rot=sin(clock*float(a.walk_speed))*side*float(a.wing_swing)
	var phase:=str(state.get("attack",""))
	if phase in ["windup","active","recovery"]:
		var p:=clampf(float(state.get("attack_p",0)),0,1)
		Poses.P(pose,"arm_r").rot+=float(a.attack_swing)*(-p if phase=="windup" else 1.0 if phase=="active" else 1-p)
	var death:=float(state.get("dying_p",-1))
	if death>=0:
		var p:=clampf(death,0,1)
		for part: Dictionary in rig.parts:
			var joint:=Poses.P(pose,part.id)
			var side:=-1.0 if Vector2(part.pivot).x<rig.ground.x else 1.0
			joint.dx+=side*p*4
			joint.dy+=p*p*6
			joint.rot+=side*p*0.7
			tint.a*=1-smoothstep(0.65,1,p) if str(part.id)=="core" else 1
	var out:=_parts(rig,pose,feet,face,scale,tint)
	var flash:=clampf(float(feedback.get("flash",0)),0,1)*tint.a
	if flash>0:
		for part: Dictionary in rig.parts:
			if not Rect2(part.bounds).has_area(): continue
			var base: Array=out.filter(func(p:Dictionary)->bool:return str(p.id)==str(part.id))
			if base.is_empty(): continue
			var overlay: Dictionary=base[0].duplicate()
			overlay.texture=part.white
			overlay.tint=Color(feedback.get("flash_color",Color.WHITE),flash)
			out.append(overlay)
	return out

static func _parts(rig: Dictionary, pose: Dictionary, at: Vector2, face: float, scale: float, tint: Color) -> Array:
	var world: Dictionary=renderer.solve_pose(rig,pose,at,face,scale)
	var out: Array=[]
	for part: Dictionary in rig.parts:
		if not Rect2(part.bounds).has_area(): continue
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":tint})
	return out

## Actor layers keep native nearest-filtered pixels and reset the caller's transform.
static func draw(canvas: CanvasItem, parts: Array) -> void:
	for part: Dictionary in parts:
		canvas.draw_set_transform_matrix(part.transform)
		canvas.draw_texture(part.texture,Vector2.ZERO,part.tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Native sprite rects retain their exact size, pivot and tint while cutouts articulate.
static func sprite(canvas: CanvasItem, texture: Texture2D, name: String, rect: Rect2, clock: float, tint := Color.WHITE, rotation := 0.0, pivot := Vector2.ZERO) -> void:
	var parts:=effect(texture,name,Vector2i(texture.get_size()),0,Vector2.ZERO,Vector2.ZERO,0,1,clock,tint)
	var size:=rect.size/texture.get_size()
	var placement:=Transform2D(rotation,pivot)*Transform2D(0,-pivot)*Transform2D(Vector2(size.x,0),Vector2(0,size.y),rect.position)
	for part: Dictionary in parts: part.transform=placement*Transform2D(part.transform)
	draw(canvas,parts)
