extends SceneTree
## Cut the eight approved concept pieces, preserving source art; no active atlas replacement.
const SOURCE := "res://production/qa/evidence/curse-spirit-concept-v1/fluchgeist-konzept-v1.png"
const OUT := "res://assets/vfx/curse_spirit/rig"
const SIZE := Vector2i(32,44)
const PARTS := [
	["head",Rect2i(934,88,147,148),Rect2i(9,1,14,15),Vector2i(16,15),"core",4],
	["jaw",Rect2i(1138,151,99,91),Rect2i(11,12,10,8),Vector2i(16,13),"head",5],
	["core",Rect2i(1282,87,158,150),Rect2i(10,14,13,14),Vector2i(16,23),"",2],
	["claw_l",Rect2i(1003,283,160,99),Rect2i(1,15,11,11),Vector2i(11,17),"core",3],
	["claw_r",Rect2i(1233,279,142,107),Rect2i(20,15,11,11),Vector2i(21,17),"core",3],
	["tail_root",Rect2i(919,445,161,101),Rect2i(12,25,10,8),Vector2i(16,26),"core",1],
	["tail_mid",Rect2i(1110,470,188,78),Rect2i(14,30,10,8),Vector2i(17,31),"tail_root",0],
	["tail_tip",Rect2i(1329,463,159,74),Rect2i(13,35,9,8),Vector2i(18,36),"tail_mid",0]
]
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/curse-spirit"))
	var source := Image.load_from_file(SOURCE)
	source.convert(Image.FORMAT_RGBA8)
	var parts: Array = []
	var bind := Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
	for spec: Array in PARTS:
		var patch := source.get_region(spec[1])
		# Reject neutral slate/grid, retaining the approved ivory, plum and green pixels.
		for y in range(patch.get_height()):
			for x in range(patch.get_width()):
				var c := patch.get_pixel(x,y)
				var bone := c.r>0.35 and c.r>c.b*1.18 and c.g>c.b*1.1
				var green := c.g>c.r*1.15 and c.g>c.b*1.1 and c.g>0.18
				var purple := c.r>c.g*1.3 and c.b>c.g*1.35 and c.r>0.12
				patch.set_pixel(x,y,Color(c,1) if bone or green or purple else Color.TRANSPARENT)
		var used := patch.get_used_rect()
		assert(used.has_area(),"approved part must retain source pixels")
		patch = patch.get_region(used)
		var target: Rect2i = spec[2]
		patch.resize(target.size.x,target.size.y,Image.INTERPOLATE_NEAREST)
		var layer := Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
		layer.blit_rect(patch,Rect2i(Vector2i.ZERO,target.size),target.position)
		# A one-native-pixel dark cutout outline restores legibility after grid removal.
		var outlined := layer.duplicate() as Image
		for y in range(1,SIZE.y-1):
			for x in range(1,SIZE.x-1):
				if layer.get_pixel(x,y).a>0.5: continue
				for n: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					if layer.get_pixelv(Vector2i(x,y)+n).a>0.5:
						outlined.set_pixel(x,y,Color("211626"))
						break
		assert(outlined.save_png(OUT.path_join(str(spec[0])+".png"))==OK)
		bind.blend_rect(outlined,Rect2i(Vector2i.ZERO,SIZE),Vector2i.ZERO)
		parts.append({"id":spec[0],"parent":spec[4],"pivot":[spec[3].x,spec[3].y],"z":spec[5],"img":OUT.path_join(str(spec[0])+".png"),"cut_rects":[[target.position.x,target.position.y,target.end.x-1,target.end.y-1]]})
	var data := {"schema_version":1,"_note":"User-approved curse-spirit board cut into eight native layers. Independent identity, no soul-spirit images. Source and importer retained.","rigs":{"curse_spirit":{"family":"curse_spirit","size":[SIZE.x,SIZE.y],"ground":[16,40],"width":22,"parts":parts}}}
	var file := FileAccess.open("res://assets/data/curse_spirit_rig.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"  "))
	bind.save_png(OUT.path_join("bind.png"))
	bind.resize(256,352,Image.INTERPOLATE_NEAREST)
	bind.save_png("res://output/curse-spirit/bind-8x.png")
	print("CURSE_SPIRIT_IMPORT parts=",parts.size())
	quit()
