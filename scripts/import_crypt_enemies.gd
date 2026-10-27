extends SceneTree
## Deterministic asset import of built-in Imagegen source sheets, not gameplay.
## Crops equal animation cells, aligns skull/body and feet, maps the restrained
## crypt palette and writes16x24-effective artwork on32x48 transparent frames.

const ROOT: String = "res://assets/sprites/crypt_enemies/"
const ROLES: Array[String] = ["skeleton_archer","necromancer","skeleton_guard"]
const STATES: Array[String] = ["idle","run","attack"]
const PALETTE: Array[Color] = [
	Color("191426"),Color("30243e"),Color("4b3b59"),Color("67556e"),
	Color("95839a"),Color("b7a48a"),Color("d8c2a0"),Color("f2dfb7"),
	Color("fff0ce"),Color("51372d"),Color("775135"),Color("a17143"),
	Color("615665"),Color("96909b"),Color("c8c3cc"),Color("f0e8ee"),
	Color("164948"),Color("28716a"),Color("55a898"),Color("94d8bf")]

var failed: bool = false

func _initialize() -> void:
	var report: Dictionary = {"canvas":[32,48],"effective_canvas":[16,24],"source_grid":[4,3],"roles":{}}
	var contact: Image = Image.create(384,144,false,Image.FORMAT_RGBA8)
	contact.fill(Color.TRANSPARENT)
	for role_index: int in range(ROLES.size()):
		var role: String = ROLES[role_index]
		var source: Image = Image.load_from_file(ROOT+"source/"+role+"_sheet.png")
		if source == null:
			printerr("CRYPT_ART_IMPORT_FAIL source=",role)
			failed = true
			continue
		source.convert(Image.FORMAT_RGBA8)
		var rectangles: Array[Rect2i] = []
		var maximum_height: int = 0
		for row: int in range(3):
			for column: int in range(4):
				var cell: Rect2i = _cell(source,column,row)
				var bounds: Rect2i = _bounds(source,cell)
				rectangles.append(bounds)
				maximum_height = maxi(maximum_height,bounds.size.y)
		# One role-wide scale preserves body/weapon sizes across all animation frames.
		var scale: float = minf(22.0/maxf(1,maximum_height),14.0/maxf(1,rectangles[0].size.x))
		var role_report: Array[Dictionary] = []
		for frame: int in range(12):
			var bounds: Rect2i = rectangles[frame]
			var canvas: Image = Image.create(16,24,false,Image.FORMAT_RGBA8)
			canvas.fill(Color.TRANSPARENT)
			var target_height: int = maxi(1,roundi(bounds.size.y*scale))
			var target_width: int = maxi(1,roundi(bounds.size.x*scale))
			var cropped: Image = source.get_region(bounds)
			cropped.resize(target_width,target_height,Image.INTERPOLATE_NEAREST)
			_palette_map(cropped)
			var target_x: int = floori((16-target_width)/2.0)
			var target_y: int = 23-target_height
			canvas.blit_rect(cropped,Rect2i(0,0,target_width,target_height),Vector2i(target_x,target_y))
			canvas.resize(32,48,Image.INTERPOLATE_NEAREST)
			var state: String = STATES[frame/4]
			var output: String = ROOT+role+"_"+state+"_f"+str(frame%4)+".png"
			if canvas.save_png(output) != OK: failed = true
			contact.blit_rect(canvas,Rect2i(0,0,32,48),Vector2i(frame*32,role_index*48))
			role_report.append({"frame":frame,"source_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"projected_size":[target_width,target_height],"target_origin":[target_x,target_y]})
		report.roles[role] = {"source_size":[source.get_width(),source.get_height()],"uniform_scale":scale,"frames":role_report}
	contact.save_png(ROOT+"preview_contact.png")
	contact.resize(1536,576,Image.INTERPOLATE_NEAREST)
	contact.save_png(ROOT+"preview_zoom.png")
	var file: FileAccess = FileAccess.open(ROOT+"import_report.json",FileAccess.WRITE)
	if file == null: failed = true
	else: file.store_string(JSON.stringify(report,"\t")+"\n")
	print("CRYPT_ART_IMPORTED roles=3 frames=36 canvas=32x48 pixel_blocks=2 result=", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _cell(source: Image, column: int, row: int) -> Rect2i:
	var left: int = roundi(column*source.get_width()/4.0)
	var right: int = roundi((column+1)*source.get_width()/4.0)
	var top: int = roundi(row*source.get_height()/3.0)
	var bottom: int = roundi((row+1)*source.get_height()/3.0)
	return Rect2i(left,top,right-left,bottom-top)

func _bounds(source: Image, cell: Rect2i) -> Rect2i:
	var minimum: Vector2i = cell.end
	var maximum: Vector2i = cell.position
	for y: int in range(cell.position.y,cell.end.y):
		for x: int in range(cell.position.x,cell.end.x):
			if source.get_pixel(x,y).a < 0.6: continue
			minimum.x = mini(minimum.x,x)
			minimum.y = mini(minimum.y,y)
			maximum.x = maxi(maximum.x,x)
			maximum.y = maxi(maximum.y,y)
	return Rect2i(minimum,maximum-minimum+Vector2i.ONE)

func _palette_map(source: Image) -> void:
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var color: Color = source.get_pixel(x,y)
			if color.a < 0.6:
				source.set_pixel(x,y,Color.TRANSPARENT)
				continue
			var closest: Color = PALETTE[0]
			var distance: float = INF
			for candidate: Color in PALETTE:
				var difference: float = pow(color.r-candidate.r,2)+pow(color.g-candidate.g,2)+pow(color.b-candidate.b,2)
				if difference < distance:
					distance = difference
					closest = candidate
			source.set_pixel(x,y,closest)
