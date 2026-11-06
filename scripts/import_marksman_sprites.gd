extends SceneTree
## Imports the approved generated effect source into hard-alpha native sprites.
const ROOT := "res://assets/sprites/marksman/"
const NAMES := ["aimed_arrow", "piercing_arrow", "volley_arrow", "hail_arrow", "spear_arrow", "hunters_mark", "hit_small", "hit_large", "chips_a", "chips_b", "dust_a", "dust_b"]
const PALETTE := [Color("191919"), Color("33251c"), Color("59402b"), Color("826349"), Color("ac8051"), Color("c8985c"), Color("e5bb79"), Color("f4dfad"), Color("fff1ca"), Color("ffffff"), Color("947023"), Color("cf9b32"), Color("f6cf78"), Color("ffe070"), Color("494b38"), Color("717051"), Color("96916a"), Color("b4aa80")]

func _initialize() -> void:
	var image := Image.load_from_file(ROOT + "source/attack_effects.png")
	if image == null:
		push_error("Missing marksman source")
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	for index in range(NAMES.size()):
		var x0 := roundi(float(index % 4) * image.get_width() / 4.0)
		var x1 := roundi(float(index % 4 + 1) * image.get_width() / 4.0)
		var y0 := roundi(float(index / 4) * image.get_height() / 3.0)
		var y1 := roundi(float(index / 4 + 1) * image.get_height() / 3.0)
		var cell := image.get_region(Rect2i(x0, y0, x1-x0, y1-y0))
		# Remove the source's soft edge before measuring or resampling its silhouette.
		for y in range(cell.get_height()):
			for x in range(cell.get_width()):
				var c := cell.get_pixel(x,y)
				cell.set_pixel(x,y,Color(c.r,c.g,c.b,1) if c.a >= 0.65 else Color.TRANSPARENT)
		cell = cell.get_region(cell.get_used_rect())
		var size := Vector2i(21,7) if index < 3 or index == 4 else (Vector2i(7,21) if index == 3 else Vector2i(16,16))
		cell.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
		for y in range(size.y):
			for x in range(size.x):
				var c := cell.get_pixel(x,y)
				if c.a < 0.5: continue
				var best: Color = PALETTE[0]
				var distance := INF
				for ink: Color in PALETTE:
					var d := Vector3(c.r-ink.r,c.g-ink.g,c.b-ink.b).length_squared()
					if d < distance:
						distance = d
						best = ink
				cell.set_pixel(x,y,best)
		if index < 3 or index == 4:
			cell.rotate_90(COUNTERCLOCKWISE)
		if index == 3: cell.rotate_180()
		var result := cell.save_png(ROOT + str(NAMES[index]) + ".png")
		if result != OK:
			push_error("Cannot save marksman sprite: " + str(NAMES[index]))
			quit(1)
			return
	print("MARKSMAN_IMPORT sprites=12 hard_alpha=true native_arrows=7x21 native_effects=16x16")
	quit()
