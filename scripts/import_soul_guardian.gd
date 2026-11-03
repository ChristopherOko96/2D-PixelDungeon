extends SceneTree
## Mechanical source-sheet extraction: nearest resize, hard alpha, fixed scale
## and a shared anchor. Source PNG and exact Imagegen prompt stay intact.
const SOURCE := "res://assets/vfx/soul_guardian/source_sheet.png"
const OUTPUT := "res://assets/vfx/soul_guardian/guardian_atlas.png"
const CELL := Vector2i(192, 256)
const NATIVE := Vector2i(128, 80)
const COLORS := ["111321", "1b2036", "282039", "352447", "49305d", "614078", "1b354f", "20566f", "286d83", "2d8499", "359ca9", "47b6bd", "60c9cb", "7edcda", "9ce7e2", "b9f1ed", "d3f9f2", "e6ffff"]

func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null or source.get_size() != CELL * Vector2i(8, 4):
		printerr("SOUL_GUARDIAN_IMPORT unexpected source dimensions")
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	var atlas := Image.create(NATIVE.x * 8, NATIVE.y * 4, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var palette: Array[Color] = []
	for hex: String in COLORS: palette.append(Color(hex))
	for row in range(4):
		for frame in range(8):
			# The generated extension crosses two cells. Extract the entire
			# articulated pose and deliberately hold it for the two impact keys.
			var col := frame
			var width := CELL.x
			if row == 2:
				col = [0, 1, 2, 3, 3, 5, 6, 7][frame]
				if frame in [3, 4]: width *= 2
			var image := source.get_region(Rect2i(col * CELL.x, row * CELL.y, width, CELL.y))
			image.resize(width / 4, CELL.y / 4, Image.INTERPOLATE_NEAREST)
			# A detached sliver of the prior wide attack lies at this cell's
			# left edge. It is not part of the recovery pose or its particles.
			if row == 2 and frame == 6: image.fill_rect(Rect2i(0, 0, 5, image.get_height()), Color.TRANSPARENT)
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var c := image.get_pixel(x, y)
					if c.a < 0.5:
						image.set_pixel(x, y, Color.TRANSPARENT)
						continue
					var best := INF
					var result := Color.WHITE
					for color: Color in palette:
						var distance := Vector3(c.r - color.r, c.g - color.g, c.b - color.b).length_squared()
						if distance < best:
							best = distance
							result = color
					image.set_pixel(x, y, result)
			atlas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(frame * NATIVE.x + 24, row * NATIVE.y))
	var error := atlas.save_png(OUTPUT)
	print("SOUL_GUARDIAN_IMPORT result=%d atlas=%s native_cell=%s" % [error, atlas.get_size(), NATIVE])
	quit(0 if error == OK else 1)
