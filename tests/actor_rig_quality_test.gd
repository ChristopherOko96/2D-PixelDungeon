extends "res://scripts/bake_actor_animations.gd"
## Regression for raised claws being detached from arms and staff handedness.
var checked: int = 0
var failed: int = 0

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failed += 1
		printerr("ACTOR_RIG_FAIL: ", label)

func _initialize() -> void:
	configuration = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var idle: Image = Image.create(24,24,false,Image.FORMAT_RGBA8)
	for y: int in range(5,21):
		for x: int in range(9,15): idle.set_pixel(x,y,Color("aa4455"))
	# A horn belonging to the idle head must remain with that head.
	idle.set_pixel(7,2,Color("f1dfac"))
	idle.set_pixel(8,3,Color("f1dfac"))
	idle.set_pixel(8,4,Color("f1dfac"))
	var model: Dictionary = _rig_model(idle)
	var attack: Image = idle.duplicate()
	attack.set_pixel(1,0,Color("f1dfac")) # Raised claw outside the actual head.
	var split: Dictionary = _split_layers(attack,model)
	check(split.layers.head.get_pixel(1,0).a == 0 and split.layers.arm_l.get_pixel(1,0).a > 0,"raised outer claw follows its arm rather than the head")
	check(split.layers.head.get_pixel(7,2).a > 0,"the idle head silhouette preserves the horn")
	for direction: String in ["south","north"]:
		var real_idle: Image = _source("boss",direction,"idle")
		var real_attack: Image = _source("boss",direction,"attack")
		var real_model: Dictionary = _rig_model(real_idle)
		var real_split: Dictionary = _split_layers(real_attack,real_model)
		var raised_pixels: int = 0
		var misplaced: int = 0
		for y: int in range(maxi(0,int(real_model.top))):
			for x: int in range(real_attack.get_width()):
				if real_attack.get_pixel(x,y).a < 0.5 or absf(x-float(real_model.center)) <= float(real_model.core)+1: continue
				raised_pixels += 1
				if real_split.layers.head.get_pixel(x,y).a > 0: misplaced += 1
		check(raised_pixels > 0 and misplaced == 0,"real boss " + direction + " raised claws have no detached head-layer pixels")
	# Historical unstable key fixture; new art may supply a stable attack key.
	var necromancer: Dictionary = {"pose_remap":{"attack":"idle"}}
	check(str(necromancer.get("pose_remap",{}).get("attack","")) == "idle","unstable necromancer attack key has an explicit authored remap")
	check(has_method("_pose_for_actor"),"baker resolves actor-specific key selection through its pose data")
	if has_method("_pose_for_actor"):
		check(call("_pose_for_actor",necromancer,"attack") == "idle","staff attack reuses the stable hand while body-part curves still animate")
		check(call("_pose_for_actor",necromancer,"hurt") == "hurt","the remap leaves unaffected hurt art intact")
	print("ACTOR_RIG checked=%d failures=%d" % [checked,failed])
	quit(0 if failed == 0 else 1)

func _source(actor: String, direction: String, pose: String) -> Image:
	var image: Image = Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/actors/keys/"+actor+"/"+direction+"_"+pose+".png"))
	return image
