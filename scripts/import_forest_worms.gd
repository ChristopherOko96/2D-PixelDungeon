extends SceneTree
## Approved Imagegen sources -> native hard-alpha, common-framed 32x40 art.
const DEST := "res://assets/sprites/companions/forest_worms"
func _initialize() -> void:
	var sources: Array[Image] = []
	var union := Rect2i()
	for name: String in ["poison","fire"]:
		var src := Image.load_from_file(DEST.path_join("source/"+name+".png"))
		src.convert(Image.FORMAT_RGBA8)
		for y in range(src.get_height()):
			for x in range(src.get_width()):
				if src.get_pixel(x,y).a<0.5: src.set_pixel(x,y,Color.TRANSPARENT)
		sources.append(src)
		union = src.get_used_rect() if union.size==Vector2i.ZERO else union.merge(src.get_used_rect())
	var factor := minf(30.0/union.size.x,38.0/union.size.y)
	var size := Vector2i(Vector2(union.size)*factor)
	for i in range(2):
		var src := sources[i].get_region(union)
		src.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
		var palette := {}
		for y in range(size.y):
			for x in range(size.x):
				var col := src.get_pixel(x,y)
				if col.a<0.5: src.set_pixel(x,y,Color.TRANSPARENT); continue
				col.a = 1
				# Quantized source colors retain the same shared dark outlines.
				col = Color(roundf(col.r*15)/15,roundf(col.g*15)/15,roundf(col.b*15)/15,1)
				src.set_pixel(x,y,col)
				palette[col.to_rgba32()] = int(palette.get(col.to_rgba32(),0))+1
		var keys: Array = palette.keys()
		keys.sort_custom(func(a:int,b:int)->bool:return int(palette[a])>int(palette[b]))
		keys.resize(mini(20,keys.size()))
		for y in range(size.y):
			for x in range(size.x):
				var col := src.get_pixel(x,y)
				if col.a<0.5: continue
				var best := col
				var distance := INF
				for key: int in keys:
					var pick := Color.hex(key)
					var gap := Vector3(col.r,col.g,col.b).distance_squared_to(Vector3(pick.r,pick.g,pick.b))
					if gap<distance: distance=gap; best=pick
				src.set_pixel(x,y,best)
		var image := Image.create(32,40,false,Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		image.blit_rect(src,Rect2i(Vector2i.ZERO,size),Vector2i((32-size.x)/2,39-size.y))
		var name: String = ["poison","fire"][i]
		image.save_png(DEST.path_join(name+".png"))
		var enlarged := image.duplicate()
		enlarged.resize(256,320,Image.INTERPOLATE_NEAREST)
		enlarged.save_png("res://production/qa/evidence/necro-forest-rework/"+name+"-native-preview.png")
		print("WORM_IMPORTED ",name," native=32x40 palette=",keys.size()," used=",image.get_used_rect())
	quit()
