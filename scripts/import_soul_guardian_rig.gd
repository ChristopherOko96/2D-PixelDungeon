extends SceneTree
## Mechanical cutout of the approved guardian; never changes its source atlas.
const ATLAS := "res://assets/vfx/soul_guardian/guardian_atlas.png"
const OUT := "res://assets/vfx/soul_guardian/rig"
const DATA := "res://assets/data/soul_guardian_rig.json"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var atlas := Image.load_from_file(ATLAS)
	var bind := atlas.get_region(Rect2i(0, 80, 128, 80))
	bind.convert(Image.FORMAT_RGBA8)
	_remove_detached(bind)
	bind.save_png(OUT + "/bind.png")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var parts: Array = data.rigs.soul_guardian.parts
	var layers := {}
	for part: Dictionary in parts:
		layers[part.id] = Image.create(128, 80, false, Image.FORMAT_RGBA8)
	for y in range(80):
		for x in range(128):
			var color := bind.get_pixel(x, y)
			if color.a < 0.5: continue
			for part: Dictionary in parts:
				if not _contains(part.cut_rects, x, y): continue
				layers[part.id].set_pixel(x, y, color)
				break
	# Restore a small overlap of the SAME source pixels on both sides of each
	# joint. Rotating a limb must not open a transparent cut through the body.
	for part: Dictionary in parts:
		if str(part.parent).is_empty(): continue
		var joint := Vector2(float(part.pivot[0]), float(part.pivot[1]))
		var radius := float(part.joint_radius)
		for y in range(80):
			for x in range(128):
				if Vector2(x + 0.5, y + 0.5).distance_to(joint) > radius: continue
				var color := bind.get_pixel(x, y)
				if color.a < 0.5: continue
				layers[part.id].set_pixel(x, y, color)
				layers[part.parent].set_pixel(x, y, color)
	for part: Dictionary in parts:
		assert(layers[part.id].save_png(str(part.img)) == OK)
	bind.resize(768, 480, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/soul-guardian-rig"))
	bind.save_png("res://output/soul-guardian-rig/bind-6x.png")
	print("SOUL_GUARDIAN_RIG_IMPORT parts=%d" % parts.size())
	quit()

func _contains(rects: Array, x: int, y: int) -> bool:
	for r: Array in rects:
		if x >= int(r[0]) and y >= int(r[1]) and x <= int(r[2]) and y <= int(r[3]): return true
	return false

## Keep the largest connected silhouette. Sheet motes become the existing
## lifetime-based aura instead of floating rigidly on a cutout bone.
func _remove_detached(image: Image) -> void:
	var seen := {}
	var largest: Array[Vector2i] = []
	for y in range(80):
		for x in range(128):
			var p := Vector2i(x, y)
			if seen.has(p) or image.get_pixelv(p).a < 0.5: continue
			var pixels: Array[Vector2i] = [p]
			seen[p] = true
			var index := 0
			while index < pixels.size():
				var at := pixels[index]
				index += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var near := at + Vector2i(dx, dy)
						if near.x < 0 or near.y < 0 or near.x >= 128 or near.y >= 80 or seen.has(near): continue
						if image.get_pixelv(near).a < 0.5: continue
						seen[near] = true
						pixels.append(near)
			if pixels.size() > largest.size(): largest = pixels
	var keep := {}
	for p: Vector2i in largest: keep[p] = true
	for y in range(80):
		for x in range(128):
			if not keep.has(Vector2i(x, y)): image.set_pixel(x, y, Color.TRANSPARENT)
