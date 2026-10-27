extends SceneTree
## Builds the Leerenrufer (void boss) sprites:
## cuts the 8 black frames from the user's sheet, aligns them on their centre
## of mass, finishes the cut-off bottom with a dissolving veil, paints the new
## parts from void.json and writes preview strips. Usage:
##   godot --headless --path . -s res://production/art-proof/0x72-style/make_void.gd -- <sheet.png> <out_dir>

var cfg: Dictionary

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var sheet := Image.load_from_file(args[0])
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://production/art-proof/0x72-style/void.json"))
	var frames := _cut(sheet)
	for i in range(frames.size()):
		frames[i].save_png(out.path_join("void_body_f%d.png" % i))
	var palette: Dictionary = cfg.palette
	var claw := _paint(cfg.claw_left, palette)
	claw.save_png(out.path_join("void_claw_left.png"))
	for state in ["closed", "half", "open"]:
		_paint(cfg.eye[state], palette).save_png(out.path_join("void_eye_%s.png" % state))
	_preview(frames, claw, out)
	var bomber := _cut_bomber(sheet)
	for i in range(bomber.size()):
		bomber[i].save_png(out.path_join("void_bomber_f%d.png" % i))
	print("VOID frames=%d size=%s bomber=%d" % [frames.size(), frames[0].get_size(), bomber.size()])
	quit()

# Leerenbomber: every non-background pixel in the band, grouped into connected
# frames left to right, x centred in a 16x16 cell, the sheet's bob kept.
func _cut_bomber(sheet: Image) -> Array[Image]:
	var data: Dictionary = cfg.bomber
	var band := Rect2i(int(data.band[0]), int(data.band[1]), int(data.band[2]), int(data.band[3]))
	var background: Array = data.background
	var ink := func(p: Vector2i) -> bool:
		return band.has_point(p) and sheet.get_pixelv(p).a > 0.5 and not (sheet.get_pixelv(p).to_html(false) in background)
	var seen := {}
	var comps := []
	for y in range(band.position.y, band.end.y):
		for x in range(band.position.x, band.end.x):
			var start := Vector2i(x, y)
			if seen.has(start) or not ink.call(start): continue
			var stack := [start]
			var pixels := []
			seen[start] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				pixels.append(p)
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var q := p + Vector2i(dx, dy)
						if seen.has(q) or not ink.call(q): continue
						seen[q] = true
						stack.append(q)
			if pixels.size() >= 30: comps.append(pixels)
	comps.sort_custom(func(a, b): return _mean_x(a) < _mean_x(b))
	var frames: Array[Image] = []
	var cell := Vector2i(int(data.cell[0]), int(data.cell[1]))
	for pixels in comps.slice(0, int(data.frames)):
		var left := 9999
		var right := -1
		for p: Vector2i in pixels:
			left = mini(left, p.x)
			right = maxi(right, p.x)
		var shift := Vector2i(cell.x / 2 - (left + right + 1) / 2, -int(data.top_row))
		var image := Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
		for p: Vector2i in pixels:
			var q := p + shift
			if q.x >= 0 and q.y >= 0 and q.x < cell.x and q.y < cell.y: image.set_pixelv(q, sheet.get_pixelv(p))
		frames.append(image)
	return frames

func _ink(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).to_html(false) in cfg.sheet.ink

# Connected ink components in the bottom band; the 8 large ones are the frames,
# small specks join the frame whose centre is nearest.
func _cut(sheet: Image) -> Array[Image]:
	var y0 := int(cfg.sheet.band_y)
	var max_x := int(cfg.sheet.max_x)
	var seen := {}
	var comps := []
	for y in range(y0, sheet.get_height()):
		for x in range(0, max_x):
			var start := Vector2i(x, y)
			if seen.has(start) or not _ink(sheet, x, y): continue
			var stack := [start]
			var pixels := []
			seen[start] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				pixels.append(p)
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var q := p + Vector2i(dx, dy)
						if q.x < 0 or q.y < y0 or q.x >= max_x or q.y >= sheet.get_height() or seen.has(q) or not _ink(sheet, q.x, q.y): continue
						seen[q] = true
						stack.append(q)
			comps.append(pixels)
	var big := comps.filter(func(c): return c.size() >= 100)
	big.sort_custom(func(a, b): return _mean_x(a) < _mean_x(b))
	for small in comps.filter(func(c): return c.size() < 100):
		var best = big[0]
		for candidate in big:
			if absf(_mean_x(candidate) - _mean_x(small)) < absf(_mean_x(best) - _mean_x(small)): best = candidate
		best.append_array(small)
	var frames: Array[Image] = []
	var w := int(cfg.frame.w)
	var h := int(cfg.frame.h)
	var bottom := int(cfg.frame.bottom)
	for pixels in big:
		var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var shift := int(cfg.frame.center_x) - int(round(_mean_x(pixels)))
		for p: Vector2i in pixels:
			var q := Vector2i(p.x + shift, p.y - int(cfg.sheet.bottom_row) + bottom)
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h: image.set_pixelv(q, sheet.get_pixelv(p))
		_veil(image, bottom, int(cfg.frame.veil))
		frames.append(image)
	return frames

func _mean_x(pixels: Array) -> float:
	var sum := 0.0
	for p: Vector2i in pixels: sum += p.x
	return sum / max(1, pixels.size())

# The sheet cuts the creature off at its last row. Below it the mass thins
# into ragged drips, longest in the middle, with a few loose droplets.
func _veil(image: Image, bottom: int, depth: int) -> void:
	var dark := Color("222222")
	var xs := []
	for x in range(image.get_width()):
		if image.get_pixel(x, bottom).a > 0.5: xs.append(x)
	if xs.is_empty(): return
	var mid := (float(xs.front()) + float(xs.back())) / 2.0
	var half := maxf(1.0, (float(xs.back()) - float(xs.front())) / 2.0 + 1.0)
	for x: int in xs:
		var rel := absf(x - mid) / half
		var taper := 1.0 - pow(rel, 1.6)
		var noise := _hash(x - int(round(mid)))
		var length := int(round(depth * taper * (0.4 + 0.6 * noise)))
		for d in range(1, length + 1):
			if bottom + d < image.get_height(): image.set_pixel(x, bottom + d, dark)
		if noise > 0.82 and length >= 2 and bottom + length + 2 < image.get_height():
			image.set_pixel(x, bottom + length + 2, dark)

func _hash(n: int) -> float:
	var v := sin(float(n) * 12.9898 + 4.1) * 43758.5453
	return v - floor(v)

func _paint(rows: Array, palette: Dictionary) -> Image:
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var key: String = rows[y][x]
			if palette.has(key): image.set_pixel(x, y, Color(palette[key]))
	return image

# Two strips at 4x: the raw aligned frames, and the frames with claws and the
# open eye as the boss will look.
func _preview(frames: Array[Image], claw: Image, out: String) -> void:
	var w := int(cfg.frame.w)
	var h := int(cfg.frame.h)
	var strip := Image.create(w * frames.size(), h * 2 + 4, false, Image.FORMAT_RGBA8)
	strip.fill(Color("13111c"))
	var mirrored := claw.duplicate()
	mirrored.flip_x()
	var pivot := Vector2i(int(cfg.claw_pivot[0]), int(cfg.claw_pivot[1]))
	var shoulder := Vector2i(int(cfg.shoulder_left[0]), int(cfg.shoulder_left[1]))
	var right_shoulder := Vector2i(w - 1 - shoulder.x, shoulder.y)
	var right_pivot := Vector2i(claw.get_width() - 1 - pivot.x, pivot.y)
	var eye := _paint(cfg.eye.open, cfg.palette)
	var eye_at := Vector2i(int(cfg.eye.at[0]), int(cfg.eye.at[1]))
	for i in range(frames.size()):
		var f := frames[i]
		strip.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i(i * w, 0))
		var base := Vector2i(i * w, h + 4)
		strip.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), base)
		strip.blend_rect(claw, Rect2i(Vector2i.ZERO, claw.get_size()), base + shoulder - pivot)
		strip.blend_rect(mirrored, Rect2i(Vector2i.ZERO, mirrored.get_size()), base + right_shoulder - right_pivot)
		strip.blend_rect(eye, Rect2i(Vector2i.ZERO, eye.get_size()), base + eye_at)
	strip.resize(strip.get_width() * 4, strip.get_height() * 4, Image.INTERPOLATE_NEAREST)
	strip.save_png(out.path_join("void_preview.png"))
