extends SceneTree
## Builds the Schläfer der Tiefe sprites from sleeper.json (mirrored halves),
## plus a preview with sample tentacles. Usage:
##   godot --headless --path . -s res://production/art-proof/0x72-style/make_sleeper.gd -- <out_dir>

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://production/art-proof/0x72-style/sleeper.json"))
	var palette: Dictionary = data.palette
	var mantle := _mirror(data.mantle_left_halves)
	var fin: Array = data.fin_left
	var mantle_image := _paint(mantle, palette)
	mantle_image.save_png(out.path_join("sleeper_mantle.png"))
	var fin_image := _paint(fin, palette)
	fin_image.save_png(out.path_join("sleeper_fin_left.png"))
	# Preview: fins, mantle and resting tentacles, scaled 6x.
	var preview := Image.create(48, 44, false, Image.FORMAT_RGBA8)
	preview.fill(Color("13111c"))
	var mx := 10
	var flipped := fin_image.duplicate()
	flipped.flip_x()
	preview.blend_rect(fin_image, Rect2i(Vector2i.ZERO, fin_image.get_size()), Vector2i(mx - 6, 8))
	preview.blend_rect(flipped, Rect2i(Vector2i.ZERO, flipped.get_size()), Vector2i(mx + 26, 8))
	var tentacle: Dictionary = data.tentacle
	for index in range(tentacle.roots.size()):
		var root := Vector2(mx + float(tentacle.roots[index]) + 0.5, float(tentacle.root_y))
		var angle := PI / 2 + (float(index) - 2.5) * 0.18
		var point := root
		for segment in range(int(tentacle.segments)):
			var k := float(segment) / float(int(tentacle.segments) - 1)
			var radius := lerpf(float(tentacle.radius_start), float(tentacle.radius_end), k)
			angle += 0.12 * sin(index * 1.7 + segment * 0.8)
			_disc(preview, point, radius, palette, segment % 2 == 0)
			point += Vector2.from_angle(angle) * float(tentacle.spacing)
	preview.blend_rect(mantle_image, Rect2i(Vector2i.ZERO, mantle_image.get_size()), Vector2i(mx, 0))
	preview.resize(preview.get_width() * 6, preview.get_height() * 6, Image.INTERPOLATE_NEAREST)
	preview.save_png(out.path_join("sleeper_preview.png"))
	print("SLEEPER mantle=%s fin=%s" % [mantle_image.get_size(), fin_image.get_size()])
	quit()

func _mirror(halves: Array) -> Array:
	var rows := []
	for half: String in halves:
		if half.length() != 14: push_error("row width %d: %s" % [half.length(), half])
		rows.append(half + half.reverse())
	return rows

func _paint(rows: Array, palette: Dictionary) -> Image:
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var key: String = rows[y][x]
			if palette.has(key): image.set_pixel(x, y, Color(palette[key]))
	return image

func _disc(image: Image, center: Vector2, radius: float, palette: Dictionary, light: bool) -> void:
	var r := int(ceil(radius)) + 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := Vector2i(int(floor(center.x)) + dx, int(floor(center.y)) + dy)
			if p.x < 0 or p.y < 0 or p.x >= image.get_width() or p.y >= image.get_height(): continue
			var d := Vector2(dx, dy).length()
			if d <= radius - 0.5: image.set_pixel(p.x, p.y, Color(palette.T if light else palette.D))
			elif d <= radius + 0.5 and image.get_pixel(p.x, p.y) != Color(palette.T) and image.get_pixel(p.x, p.y) != Color(palette.D): image.set_pixel(p.x, p.y, Color(palette.A))
