extends SceneTree
## Builds the stone slab that closes a doorway in a wall running up and down, for each graphics set
## (assets/data/world_gates.json): the set's own wall stone, iron bands and a lit seam where its two
## halves meet. side_slab.png is the shut slab, as long as the two cells of a doorway; side_slab_open.png
## is what stays when it has slid apart. Pixel sets keep their grid and their palette.
## Adds both to the set's manifest.json, then needs an import run (godot --headless --import).
## Usage:
##   godot --headless --path . --script res://tools/world_kit/build_side_gates.gd
const CONFIG := "res://assets/data/world_gates.json"


func _initialize() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	var look: Dictionary = cfg.slab
	var made := 0
	for set_def: Dictionary in cfg.sets:
		var folder := str(set_def.folder)
		var grid := int(set_def.get("grid", 1))
		var palette := _set_palette(folder, look) if grid > 1 else []
		var slab := _slab(_read(folder + "wall_v.png"), _capstone(_read(folder + "wall_h.png")), look, set_def, grid, palette)
		var left := _stubs(slab, look, grid)
		_store(slab, folder, str(look.shut_name))
		_store(left, folder, str(look.open_name))
		_add_to_manifest(folder, look, slab)
		made += 2
	print("SIDE_GATES made=", made)
	quit()


func _store(image: Image, folder: String, name: String) -> void:
	image.save_png(ProjectSettings.globalize_path(folder + name + ".png"))


func _add_to_manifest(folder: String, look: Dictionary, slab: Image) -> void:
	var path := folder + "manifest.json"
	if not FileAccess.file_exists(path):
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key: String in manifest.keys():
		if key.begins_with("side_"):
			manifest.erase(key)
	for name: Variant in [look.shut_name, look.open_name]:
		manifest[str(name)] = {"w": slab.get_width(), "h": slab.get_height(), "kind": "sprite", "src": "stone slab from wall_v"}
	var file := FileAccess.open(path, FileAccess.WRITE)
	# whole numbers stay whole, the file changes only by what is new
	file.store_string(RegEx.create_from_string("(\\d)\\.0(,?\\n)").sub(JSON.stringify(manifest, " ", false), "$1$2", true))
	file.close()


func _read(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	return image


## The colours a pixel set's slab may use: those of its own pictures.
func _set_palette(folder: String, look: Dictionary) -> Array:
	var seen := {}
	for name: Variant in look.palette_from:
		var path := folder + str(name) + ".png"
		if not FileAccess.file_exists(path):
			continue
		var image := _read(path)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var c := image.get_pixel(x, y)
				if c.a > 0.5:
					seen[c.to_html(false)] = c
	return seen.values()


func _nearest(color: Color, palette: Array) -> Color:
	if palette.is_empty():
		return color
	var best: Color = palette[0]
	var best_d := INF
	for c: Color in palette:
		var d := Vector3(c.r - color.r, c.g - color.g, c.b - color.b).length_squared()
		if d < best_d:
			best_d = d
			best = c
	best.a = 1.0
	return best


## The wall's stone over the doorway's whole length, bands across it and the seam in the middle.
func _slab(wall: Image, cap: Color, look: Dictionary, set_def: Dictionary, grid: int, palette: Array) -> Image:
	var light := float(set_def.get("stone_light", look.stone_light))
	var w := wall.get_width()
	var h := int(look.length)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var step := maxi(1, grid)
	# on the set's pixel grid: each block takes one colour of the wall
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := wall.get_pixel(mini(x + step / 2, wall.get_width() - 1), (y + step / 2) % wall.get_height())
			c = _nearest(Color(c.r * light, c.g * light, c.b * light, 1.0), palette)
			_fill(out, x, y, step, step, c)
	var edge := _nearest(Color(str(look.edge)), palette)
	# the slab's rails in the wall's capstone colour, so it stands out from the dark wall
	var rail := _nearest(cap, palette)
	var rail_w := _snap(float(look.rail_px), step)
	for x0: int in [0, (w - rail_w - step) / step * step]:
		_fill(out, x0, 0, step, h, edge)
		_fill(out, x0 + step, 0, rail_w - step, h, rail)
		_fill(out, x0 + rail_w, 0, step, h, edge)
	var iron := _nearest(Color(str(look.iron)), palette)
	var iron_light := _nearest(Color(str(look.iron_light)), palette)
	for at: Variant in look.bands:
		var y := _snap(float(at) * h, step)
		_fill(out, 0, y, w, _snap(float(look.band_px), step), iron)
		_fill(out, 0, y, w, step, iron_light)
	var seam := _nearest(Color(str(set_def.get("seam", look.seam))), palette)
	var seam_dark := _nearest(Color(str(look.seam_dark)), palette)
	var middle := _snap(h * 0.5, step)
	_fill(out, 0, middle - step * 3, w, step * 6, seam_dark)
	_fill(out, 0, middle - step * 2, w, step * 4, seam)
	# a soft glow in the stone beside the seam; pixel sets stay hard
	if palette.is_empty():
		var reach := int(look.glow_px)
		for k in range(1, reach + 1):
			var a := 0.55 * (1.0 - float(k) / (reach + 1))
			for x in range(w):
				for y: int in [middle - step * 3 - k, middle + step * 3 + k - 1]:
					out.set_pixel(x, y, out.get_pixel(x, y).lerp(seam, a))
	return out


## The colour of a wall's capstone: the brightest row of its top part, on average.
func _capstone(wall: Image) -> Color:
	var best := Color.BLACK
	var best_v := -1.0
	for y in range(mini(24, wall.get_height())):
		var sum := Color(0, 0, 0, 1)
		var n := 0
		for x in range(wall.get_width()):
			var c := wall.get_pixel(x, y)
			if c.a > 0.5:
				sum = Color(sum.r + c.r, sum.g + c.g, sum.b + c.b, 1.0)
				n += 1
		if n == 0:
			continue
		var mean := Color(sum.r / n, sum.g / n, sum.b / n, 1.0)
		if mean.v > best_v:
			best_v = mean.v
			best = mean
	return best


## What stays of the slab when open: its two ends, slid back into the wall.
func _stubs(slab: Image, look: Dictionary, grid: int) -> Image:
	var h := slab.get_height()
	var out := Image.create(slab.get_width(), h, false, Image.FORMAT_RGBA8)
	var stub := _snap(float(look.stub_px), maxi(1, grid))
	out.blit_rect(slab, Rect2i(0, 0, slab.get_width(), stub), Vector2i.ZERO)
	out.blit_rect(slab, Rect2i(0, h - stub, slab.get_width(), stub), Vector2i(0, h - stub))
	return out


func _snap(value: float, step: int) -> int:
	return int(round(value / step)) * step


func _fill(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, w, h), color)
