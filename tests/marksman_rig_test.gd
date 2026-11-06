extends SceneTree
const Art=preload("res://src/vfx/marksman_art.gd")
var checked:=0
var failures:=0
func check(ok: bool, label: String) -> void:
	checked+=1
	if not ok: failures+=1; printerr("MARKSMAN_RIG_FAIL: ",label)
func _initialize() -> void:
	var parts:=Art.parts(Vector2(100,100),Vector2.RIGHT,0.2,2)
	check(parts.size()==4,"four real articulated source masks")
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/marksman_rig.json"))
	var source: Image=(load(str(spec.images.marksman_arrow)) as Texture2D).get_image()
	var total:=0
	var assigned:=0
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x,y).a>0.5: total+=1
	for part: Dictionary in parts:
		var image: Image=part.texture.get_image()
		var count:=0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y).a>0.5: count+=1
		check(count>0,str(part.id)+" mask has real pixels")
		assigned+=count
	check(assigned==total,"every opaque source pixel assigned exactly once")
	var next:=Art.parts(Vector2(100,100),Vector2.RIGHT,0.5,2)
	check(parts[0].texture==next[0].texture,"native textures cached across frames")
	check(parts[1].transform!=next[1].transform,"fletching joint moves continuously")
	check(parts[3].transform==next[3].transform,"rigid shaft stays stable")
	print("MARKSMAN_RIG checked=%d failures=%d"%[checked,failures])
	quit(1 if failures else 0)
