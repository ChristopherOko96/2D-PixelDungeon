extends SceneTree
## The actual source catalog, complete native pixel ownership and continuous joints.
const Cutouts=preload("res://src/rig/cutout_motion.gd")
const Sheets=preload("res://src/vfx/sheet_art.gd")
const Library=preload("res://src/rig/rig_library.gd")
var checked:=0
var failures:=0
func check(ok: bool, label: String) -> void:
	checked+=1
	if not ok: failures+=1; printerr("CUTOUT_FAIL: ",label)
func _initialize() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/vfx_sprites.json"))
	var frames:=0
	var library: RefCounted=Library.shared()
	for file: String in ["res://assets/data/hell_monsters.json","res://assets/data/krypta_monsters.json"]:
		var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
		for id: String in registry.defs:
			var rig: Dictionary=library.rig(str(registry.defs[id].get("rig",id)))
			check(not rig.is_empty() and rig.parts.size()>1,id+" uses a complete body-part rig")
	var balance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	for id: String in balance.enemy_roster.definitions:
		var name:=str(balance.enemy_roster.definitions[id].get("rig",""))
		if not name.is_empty(): check(library.rig(name).get("parts",[]).size()>1,id+" native crypt body is articulated")
	var frost: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/frost_theme.json"))
	for id: String in frost.rigs:
		if id.begins_with("_"): continue
		check(library.rig(str(frost.rigs[id])).get("parts",[]).size()>1,id+" frost body is articulated")
	var talents: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/talents.json"))
	for id: String in talents.pet.kinds:
		var rig: Dictionary=library.rig(str(talents.pet.kinds[id].get("rig","")))
		check(not rig.is_empty() and rig.parts.size()>1,id+" companion rig survives the central build")
	for name: String in data.sheets:
		var entry: Dictionary=data.sheets[name]
		var texture: Texture2D=load(str(entry.file))
		var source:=texture.get_image()
		if source.is_compressed(): source.decompress()
		for frame in range(int(entry.frames)):
			var rig:=Cutouts.prepare(texture,name,Vector2i(entry.size[0],entry.size[1]),frame,Vector2(entry.anchor[0],entry.anchor[1]))
			check(not rig.is_empty(),name+" frame "+str(frame)+" has real rig")
			if rig.is_empty(): continue
			check(_complete(rig,source.get_region(Rect2i(frame*int(entry.size[0]),0,int(entry.size[0]),int(entry.size[1])))),name+" frame "+str(frame)+" owns every native pixel once")
			frames+=1
	var actors:=Sheets.MOB_SPRITES.keys()+Sheets.SHEET_KINDS.keys()
	for name: String in actors:
		var path: String="res://assets/sprites/0x72/%s_idle_anim_f0.png"%Sheets.MOB_SPRITES[name] if Sheets.MOB_SPRITES.has(name) else "res://assets/sprites/%s/frames/%s_idle_anim_f0.png"%[Sheets.SHEET_KINDS[name][0],Sheets.SHEET_KINDS[name][1]]
		var texture: Texture2D=load(path)
		var rig:=Cutouts.prepare(texture,name,Vector2i(texture.get_size()),0,Vector2(texture.get_width()*0.5,texture.get_height()),true)
		var source:=texture.get_image()
		if source.is_compressed(): source.decompress()
		check(_complete(rig,source),name+" complete bind silhouette")
		var state:={"moving":true,"id":1,"attack":"windup","attack_p":0.4}
		var a:=Cutouts.actor(texture,name,Vector2(100,100),2,1,0.3,state,Color.WHITE)
		var b:=Cutouts.actor(texture,name,Vector2(100,100),2,1,0.35,state,Color.WHITE)
		check(a.size()>=3 and a[0].texture==b[0].texture,"cached independent parts for "+name)
		check(a!=b,"continuous part poses for "+name)
		var flashed:=Cutouts.actor(texture,name,Vector2(100,100),2,1,0.3,state,Color.WHITE,{"flash":1.0})
		check(flashed.size()==a.size()*2,"hit flash follows each articulated silhouette for "+name)
	print("CUTOUT_COVERAGE checked=%d failures=%d sheets=%d frames=%d actors=%d"%[checked,failures,data.sheets.size(),frames,actors.size()])
	quit(1 if failures else 0)
func _complete(rig: Dictionary, source: Image) -> bool:
	if rig.is_empty(): return false
	var layers: Array=rig.parts
	var total:=0
	var expected:=0
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x,y).a>=0.5: expected+=1
	var unique:={}
	for part: Dictionary in layers:
		var image: Image=part.image
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y).a<0.5: continue
				var point:=Vector2i(x,y)
				if unique.has(point): return false
				if source.get_pixel(x,y)!=image.get_pixel(x,y): return false
				unique[point]=true
				total+=1
	return total==expected and total>0
