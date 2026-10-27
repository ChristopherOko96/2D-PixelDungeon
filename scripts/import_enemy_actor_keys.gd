extends SceneTree
## Deterministic import of generated four-direction enemy key poses.
## Keeps a role-wide idle-derived scale, hard palette and a shared feet anchor.
const ROLES: Array[String] = ["skeleton_archer","necromancer","skeleton_guard","boss"]
const DIRECTIONS: Array[String] = ["south","east","north","west"]
const POSES: Array[String] = ["idle","move","attack","hurt"]
const ROOT: String = "res://assets/actors/"
const BASE_PALETTE: Array[Color] = [Color("191426"),Color("30243e"),Color("4b3b59"),Color("67556e"),Color("95839a"),Color("b7a48a"),Color("d8c2a0"),Color("f2dfb7"),Color("fff0ce"),Color("51372d"),Color("775135"),Color("a17143"),Color("615665"),Color("96909b"),Color("c8c3cc"),Color("f0e8ee"),Color("164948"),Color("28716a"),Color("55a898"),Color("94d8bf")]
const BOSS_PALETTE: Array[Color] = [Color("3e2037"),Color("632345"),Color("8e2b4e"),Color("b83452"),Color("d3455b"),Color("ec5b65"),Color("ff843a"),Color("ffdc63"),Color("ff412b"),Color("b91d28")]
var failed: bool = false

func _initialize() -> void:
	var report: Dictionary = {"schema_version":1,"source_grid":[4,4],"column_directions":DIRECTIONS,"row_poses":POSES,"roles":{}}
	for role_index: int in range(ROLES.size()):
		var role: String = ROLES[role_index]
		var source: Image = Image.load_from_file(ROOT+"source/"+role+"_poses.png")
		if source == null:
			failed = true
			printerr("ACTOR_KEY_IMPORT_FAIL missing=",role)
			continue
		source.convert(Image.FORMAT_RGBA8)
		var width: int = 40 if role == "boss" else 24
		var height: int = 48 if role == "boss" else 32
		var foot: int = height-1
		var nominal: Vector2i = Vector2i(32,40) if role == "boss" else Vector2i(16,24)
		var idle_height: int = 32 if role == "boss" else 20
		var idle_maximum: Vector2i = Vector2i.ONE
		# Source sheets have uneven outer margins. Detect the sixteen connected
		# silhouettes instead of cutting at arbitrary quarter-image boundaries.
		var silhouettes: Array[Dictionary] = _silhouettes(source)
		if silhouettes.size() != 16:
			failed = true
			printerr("ACTOR_KEY_IMPORT_FAIL silhouettes=",role," count=",silhouettes.size())
			continue
		for index: int in range(4):
			var idle_bounds: Rect2i = silhouettes[index].bounds
			idle_maximum.x = maxi(idle_maximum.x,idle_bounds.size.x)
			idle_maximum.y = maxi(idle_maximum.y,idle_bounds.size.y)
		var uniform_scale: float = float(idle_height)/idle_maximum.y
		# Wide swords and shields get transparent padding, never a squeezed body.
		var maximum_pose_width: int = 0
		for silhouette: Dictionary in silhouettes:
			maximum_pose_width = maxi(maximum_pose_width,roundi(silhouette.bounds.size.x*uniform_scale))
		if maximum_pose_width > width:
			width = ceili(maximum_pose_width/4.0)*4
		var palette: Array[Color] = BASE_PALETTE.duplicate()
		if role == "boss": palette.append_array(BOSS_PALETTE)
		var frames: Array[Dictionary] = []
		var directory: String = ROOT+"keys/"+role+"/"
		DirAccess.make_dir_recursive_absolute(directory)
		var role_contact: Image = Image.create(width*4,height*4,false,Image.FORMAT_RGBA8)
		role_contact.fill(Color.TRANSPARENT)
		for index: int in range(16):
			var bounds: Rect2i = silhouettes[index].bounds
			var cropped: Image = _isolate(source,silhouettes[index])
			var projected: Vector2i = Vector2i(maxi(1,roundi(bounds.size.x*uniform_scale)),maxi(1,roundi(bounds.size.y*uniform_scale)))
			cropped.resize(projected.x,projected.y,Image.INTERPOLATE_NEAREST)
			_map_palette(cropped,palette)
			var used: Rect2i = cropped.get_used_rect()
			if not used.has_area():
				failed = true
				printerr("ACTOR_KEY_IMPORT_FAIL empty=",role," frame=",index)
				continue
			var canvas: Image = Image.create(width,height,false,Image.FORMAT_RGBA8)
			canvas.fill(Color.TRANSPARENT)
			var target: Vector2i = Vector2i(floori((width-used.size.x)/2.0),foot-used.size.y)
			var clipping: bool = used.size.x > width or used.size.y > foot
			if clipping:
				failed = true
				printerr("ACTOR_KEY_IMPORT_FAIL clipping=",role," frame=",index," projected=",used.size)
			canvas.blit_rect(cropped,used,target)
			var direction: String = DIRECTIONS[index%4]
			var pose: String = POSES[index/4]
			var path: String = directory+direction+"_"+pose+".png"
			if canvas.save_png(path) != OK: failed = true
			role_contact.blit_rect(canvas,Rect2i(0,0,width,height),Vector2i((index%4)*width,(index/4)*height))
			frames.append({"direction":direction,"pose":pose,"path":path.trim_prefix("res://"),"source_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"projected_size":[used.size.x,used.size.y],"origin":[target.x,target.y],"used_end_y":canvas.get_used_rect().end.y,"clipped":clipping})
		var layout: Dictionary = {"schema_version":1,"actor":role,"canvas":[width,height],"nominal_body_box":[nominal.x,nominal.y],"idle_height":idle_height,"world_scale":2,"foot_end_y":foot,"directions":DIRECTIONS,"poses":POSES,"uniform_idle_scale":uniform_scale,"source_extraction":"sixteen largest eight-connected alpha silhouettes, ordered by row then column","direction_source":"independently generated front/east/rear/west views","frames":frames}
		var file: FileAccess = FileAccess.open(directory+"layout.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(layout,"\t")+"\n")
		role_contact.save_png(directory+"preview_contact.png")
		role_contact.resize(width*16,height*16,Image.INTERPOLATE_NEAREST)
		role_contact.save_png(directory+"preview_zoom.png")
		report.roles[role] = layout
	var report_file: FileAccess = FileAccess.open(ROOT+"enemy_key_import_report.json",FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report,"\t")+"\n")
	print("ENEMY_ACTOR_KEYS roles=4 keys=64 source_scale=2 result=", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _silhouettes(source: Image) -> Array[Dictionary]:
	var width: int = source.get_width()
	var height: int = source.get_height()
	var alpha: PackedByteArray = PackedByteArray()
	alpha.resize(width*height)
	for y: int in range(height):
		for x: int in range(width):
			if source.get_pixel(x,y).a >= 0.6: alpha[y*width+x] = 1
	var components: Array[Dictionary] = []
	for start: int in range(alpha.size()):
		if alpha[start] != 1: continue
		var pixels: PackedInt32Array = PackedInt32Array([start])
		alpha[start] = 2
		var minimum: Vector2i = Vector2i(start%width,start/width)
		var maximum: Vector2i = minimum
		var cursor: int = 0
		while cursor < pixels.size():
			var position: Vector2i = Vector2i(pixels[cursor]%width,pixels[cursor]/width)
			cursor += 1
			minimum.x = mini(minimum.x,position.x)
			minimum.y = mini(minimum.y,position.y)
			maximum.x = maxi(maximum.x,position.x)
			maximum.y = maxi(maximum.y,position.y)
			for dy: int in range(-1,2):
				for dx: int in range(-1,2):
					var point: Vector2i = position+Vector2i(dx,dy)
					if point.x < 0 or point.x >= width or point.y < 0 or point.y >= height: continue
					var next: int = point.y*width+point.x
					if alpha[next] != 1: continue
					alpha[next] = 2
					pixels.append(next)
		components.append({"bounds":Rect2i(minimum,maximum-minimum+Vector2i.ONE),"pixels":pixels})
	components.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.pixels.size() > b.pixels.size())
	if components.size() < 16: return []
	components.resize(16)
	components.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.bounds.get_center().y < b.bounds.get_center().y)
	var ordered: Array[Dictionary] = []
	for row: int in range(4):
		var line: Array[Dictionary] = []
		for column: int in range(4): line.append(components[row*4+column])
		line.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.bounds.get_center().x < b.bounds.get_center().x)
		ordered.append_array(line)
	return ordered

func _isolate(source: Image, silhouette: Dictionary) -> Image:
	var bounds: Rect2i = silhouette.bounds
	var result: Image = Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for index: int in silhouette.pixels:
		var position: Vector2i = Vector2i(index%source.get_width(),index/source.get_width())
		result.set_pixelv(position-bounds.position,source.get_pixelv(position))
	return result

func _map_palette(source: Image, palette: Array[Color]) -> void:
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var color: Color = source.get_pixel(x,y)
			if color.a < 0.6:
				source.set_pixel(x,y,Color.TRANSPARENT)
				continue
			var nearest: Color = palette[0]
			var distance: float = INF
			for candidate: Color in palette:
				var difference: float = pow(color.r-candidate.r,2)+pow(color.g-candidate.g,2)+pow(color.b-candidate.b,2)
				if difference < distance:
					distance = difference
					nearest = candidate
			source.set_pixel(x,y,nearest)
