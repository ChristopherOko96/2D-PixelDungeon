extends SceneTree
## Offline import of newly generated detail art; historical keys stay intact.
const PROFILE := "res://assets/data/actor_detail_profile.json"
var profile: Dictionary
var problems: Array[String] = []

func _initialize() -> void:
	profile = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	var report: Dictionary = {"schema_version":1,"visual_revision":profile.visual_revision,"actors":{}}
	for actor: Dictionary in profile.actors:
		var result: Dictionary = _import(actor)
		if not result.is_empty(): report.actors[actor.id] = result
	_write(str(profile.get("report_path","res://assets/actors/detail32/import_report.json")),report)
	for problem: String in problems: printerr("ACTOR_DETAIL_IMPORT_FAIL: ",problem)
	print("ACTOR_DETAIL_IMPORT actors=%d keys=%d failures=%d"%[report.actors.size(),report.actors.size()*16,problems.size()])
	quit(0 if problems.is_empty() and report.actors.size() == 8 else 1)

func _import(actor: Dictionary) -> Dictionary:
	var path: String = str(profile.source_root)+str(actor.source)
	if not FileAccess.file_exists(path):
		problems.append("Missing generated source "+path)
		return {}
	var source: Image = Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		problems.append("Unreadable source "+path)
		return {}
	source.convert(Image.FORMAT_RGBA8)
	var crops: Array[Image] = _source_crops(source)
	if crops.size() != 16:
		problems.append("Expected16 complete silhouettes in "+path)
		return {}
	var idle_height: int = 1
	var max_width: int = 1
	var max_height: int = 1
	for index: int in range(crops.size()):
		var used: Rect2i = crops[index].get_used_rect()
		if index < 4: idle_height = maxi(idle_height,used.size.y)
		max_width = maxi(max_width,used.size.x)
		max_height = maxi(max_height,used.size.y)
	var canvas_size := Vector2i(int(actor.canvas[0]),int(actor.canvas[1]))
	var scale: float = minf(float(actor.idle_height)/idle_height,minf(float(canvas_size.x-2)/max_width,float(canvas_size.y-2)/max_height))
	var frames: Array[Image] = []
	var histogram: Dictionary = {}
	for crop: Image in crops:
		crop.resize(maxi(1,roundi(crop.get_width()*scale)),maxi(1,roundi(crop.get_height()*scale)),Image.INTERPOLATE_NEAREST)
		for y: int in range(crop.get_height()):
			for x: int in range(crop.get_width()):
				var color: Color = crop.get_pixel(x,y)
				if color.a < float(profile.alpha_threshold): crop.set_pixel(x,y,Color.TRANSPARENT)
				else:
					var key: int = _color_key(color)
					histogram[key] = int(histogram.get(key,0))+1
					crop.set_pixel(x,y,_color(key))
		frames.append(crop)
	var color_ids: Array = _palette_keys(histogram)
	var palette: Array[Color] = []
	for id: int in color_ids: palette.append(_color(id))
	var mapped: Dictionary = {}
	var directory: String = str(profile.key_root)+str(actor.id)+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var contact := Image.create(canvas_size.x*4,canvas_size.y*4,false,Image.FORMAT_RGBA8)
	var entries: Array[Dictionary] = []
	for index: int in range(frames.size()):
		var crop: Image = frames[index]
		for y: int in range(crop.get_height()):
			for x: int in range(crop.get_width()):
				var color: Color = crop.get_pixel(x,y)
				if color.a == 0: continue
				var key: int = color.to_rgba32()
				if not mapped.has(key):
					var best: Color = palette[0]
					var distance: float = INF
					for candidate: Color in palette:
						var next: float = Vector3(color.r-candidate.r,color.g-candidate.g,color.b-candidate.b).length_squared()
						if next < distance: best = candidate; distance = next
					mapped[key] = best
				crop.set_pixel(x,y,mapped[key])
		var bounds: Rect2i = crop.get_used_rect()
		var foot_center: float = _foot_center(crop,bounds)
		var target := Vector2i(clampi(roundi(canvas_size.x*0.5-foot_center),0,canvas_size.x-crop.get_width()),canvas_size.y-1-bounds.end.y)
		var canvas := Image.create(canvas_size.x,canvas_size.y,false,Image.FORMAT_RGBA8)
		canvas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),target)
		var name: String = str(profile.directions[index%4])+"_"+str(profile.poses[index/4])
		if canvas.save_png(directory+name+".png") != OK: problems.append("Cannot write "+directory+name)
		contact.blit_rect(canvas,Rect2i(Vector2i.ZERO,canvas_size),Vector2i((index%4)*canvas_size.x,(index/4)*canvas_size.y))
		var used: Rect2i = canvas.get_used_rect()
		entries.append({"key":name,"bounds":[used.position.x,used.position.y,used.size.x,used.size.y],"foot_end_y":used.end.y})
	contact.save_png(directory+"preview_contact.png")
	contact.resize(canvas_size.x*12,canvas_size.y*12,Image.INTERPOLATE_NEAREST)
	contact.save_png(directory+"preview_zoom.png")
	var result := {"canvas":actor.canvas,"target_idle_height":actor.idle_height,"source":path,"uniform_scale":scale,"world_scale":actor.render_scale,"palette_colors":palette.size(),"frames":entries}
	_write(directory+"layout.json",result)
	return result

func _color_key(color: Color) -> int:
	return (clampi(roundi(color.r*31),0,31)<<10)|(clampi(roundi(color.g*31),0,31)<<5)|clampi(roundi(color.b*31),0,31)
func _color(key: int) -> Color:
	return Color(float((key>>10)&31)/31.0,float((key>>5)&31)/31.0,float(key&31)/31.0,1)

## Rare eyes/crystal highlights remain readable beside common costume shades.
func _palette_keys(histogram: Dictionary) -> Array:
	var frequent: Array = histogram.keys()
	frequent.sort_custom(func(a: int,b: int): return int(histogram[a]) > int(histogram[b]) if histogram[a] != histogram[b] else a < b)
	var limit: int = int(profile.palette_limit)
	if frequent.size() <= limit: return frequent
	var result: Array = frequent.slice(0,maxi(1,limit-8))
	var bright: Array = frequent.duplicate()
	bright.sort_custom(func(a: int,b: int): return _color(a).v > _color(b).v if _color(a).v != _color(b).v else a < b)
	var added: int = 0
	for key: int in bright:
		if histogram[key] < 2 or key in result: continue
		result.append(key)
		added += 1
		if added == 4: break
	added = 0
	for key: int in bright:
		var color: Color = _color(key)
		if histogram[key] < 2 or key in result or color.g < color.r*1.2 or color.g < color.b*0.9: continue
		result.append(key)
		added += 1
		if added == 4 or result.size() >= limit: break
	for key: int in frequent:
		if result.size() >= limit: break
		if key not in result: result.append(key)
	return result
func _foot_center(source: Image, bounds: Rect2i) -> float:
	var total: float = 0
	var count: int = 0
	for y: int in range(maxi(bounds.position.y,bounds.end.y-maxi(2,bounds.size.y/8)),bounds.end.y):
		for x: int in range(bounds.position.x,bounds.end.x):
			if source.get_pixel(x,y).a > 0:
				total += x+0.5
				count += 1
	return total/maxi(1,count)

## Extract complete silhouettes; generated sheet gutters are not exact quarters.
func _source_crops(cell: Image) -> Array[Image]:
	var width: int = cell.get_width()
	var height: int = cell.get_height()
	var visited := PackedByteArray()
	visited.resize(width*height)
	var pieces: Array[Dictionary] = []
	for start: int in range(visited.size()):
		if visited[start] or cell.get_pixel(start%width,start/width).a < float(profile.alpha_threshold): continue
		var queue := PackedInt32Array([start])
		visited[start] = 1
		var minimum := Vector2i(start%width,start/width)
		var maximum := minimum
		var cursor: int = 0
		while cursor < queue.size():
			var current: int = queue[cursor]
			cursor += 1
			var point := Vector2i(current%width,current/width)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
			for dy: int in range(-1,2):
				for dx: int in range(-1,2):
					var next := point+Vector2i(dx,dy)
					if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height: continue
					var offset: int = next.y*width+next.x
					if visited[offset] or cell.get_pixelv(next).a < float(profile.alpha_threshold): continue
					visited[offset] = 1
					queue.append(offset)
		pieces.append({"pixels":queue,"bounds":Rect2i(minimum,maximum-minimum+Vector2i.ONE)})
	var result: Array[Image] = []
	if pieces.size() < 16: return result
	pieces.sort_custom(func(a: Dictionary,b: Dictionary): return a.pixels.size() > b.pixels.size())
	pieces.resize(16)
	pieces.sort_custom(func(a: Dictionary,b: Dictionary): return a.bounds.get_center().y < b.bounds.get_center().y)
	var ordered: Array[Dictionary] = []
	for row: int in range(4):
		var line: Array[Dictionary] = []
		for column: int in range(4): line.append(pieces[row*4+column])
		line.sort_custom(func(a: Dictionary,b: Dictionary): return a.bounds.get_center().x < b.bounds.get_center().x)
		ordered.append_array(line)
	for piece: Dictionary in ordered:
		var bounds: Rect2i = piece.bounds
		var isolated := Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
		for offset: int in piece.pixels:
			var point := Vector2i(offset%width,offset/width)
			var color: Color = cell.get_pixelv(point)
			color.a = 1
			isolated.set_pixelv(point-bounds.position,color)
		result.append(isolated)
	return result
func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: problems.append("Cannot write "+path)
	else: file.store_string(JSON.stringify(data,"\t")+"\n")
