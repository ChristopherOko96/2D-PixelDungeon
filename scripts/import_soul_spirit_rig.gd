extends SceneTree
## Cut the existing approved field ghost; no new illustration or source edit.
const Field = preload("res://src/vfx/soul_field.gd")
const OUT := "res://assets/vfx/soul_field/rig"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/soul-field-particles"))
	Field.prepare()
	var image := Field._single_ghost.get_image()
	image.resize(21, 43, Image.INTERPOLATE_NEAREST)
	image.convert(Image.FORMAT_RGBA8)
	_clean(image)
	image.save_png(OUT + "/bind.png")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/soul_spirit_rig.json"))
	var parts: Array = data.rigs.soul_spirit.parts
	var layers := {}
	for part: Dictionary in parts: layers[part.id] = Image.create(21, 43, false, Image.FORMAT_RGBA8)
	for y in range(43):
		for x in range(21):
			if image.get_pixel(x, y).a < 0.5: continue
			for part: Dictionary in parts:
				var r: Array = part.cut_rects[0]
				if x < int(r[0]) or y < int(r[1]) or x > int(r[2]) or y > int(r[3]): continue
				layers[part.id].set_pixel(x, y, image.get_pixel(x, y))
				break
	for part: Dictionary in parts:
		if str(part.parent).is_empty(): continue
		var pivot := Vector2(float(part.pivot[0]), float(part.pivot[1]))
		for y in range(43):
			for x in range(21):
				if Vector2(x + 0.5, y + 0.5).distance_to(pivot) > 2.0: continue
				var c := image.get_pixel(x, y)
				if c.a < 0.5: continue
				layers[part.id].set_pixel(x, y, c)
				layers[part.parent].set_pixel(x, y, c)
	for part: Dictionary in parts: assert(layers[part.id].save_png(str(part.img)) == OK)
	image.resize(168, 344, Image.INTERPOLATE_NEAREST)
	image.save_png("res://output/soul-field-particles/ghost-bind-8x.png")
	print("SOUL_SPIRIT_RIG_IMPORT parts=%d" % parts.size())
	quit()

func _clean(image: Image) -> void:
	var visited := {}
	var largest: Array[Vector2i] = []
	for y in range(43):
		for x in range(21):
			var start := Vector2i(x, y)
			if visited.has(start) or image.get_pixelv(start).a < 0.5: continue
			var pending: Array[Vector2i] = [start]
			visited[start] = true
			var index := 0
			while index < pending.size():
				var at := pending[index]
				index += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var p := at + Vector2i(dx, dy)
						if p.x < 0 or p.y < 0 or p.x >= 21 or p.y >= 43 or visited.has(p): continue
						if image.get_pixelv(p).a < 0.5: continue
						visited[p] = true
						pending.append(p)
			if pending.size() > largest.size(): largest = pending
	var keep := {}
	for p: Vector2i in largest: keep[p] = true
	for y in range(43):
		for x in range(21):
			var c := image.get_pixel(x, y)
			c.a = 1.0 if keep.has(Vector2i(x, y)) else 0.0
			image.set_pixel(x, y, c)
