extends SceneTree
## Builds the Krypta's pixel graphics set (assets/sprites/krypta_pixel/): for every
## sprite of the HD set (assets/sprites/krypta/manifest.json) a PNG of the SAME name
## and the SAME pixel size, composed from the 16 px pixel sources the old crypt
## drew with (assets/sprites/0x72, crypt_props, decor, 0x72_extended), scaled
## nearest-neighbour (no smoothing). The manifest is copied with the HD sizes,
## so the world kit builds the same floor from the same run number in both sets.
##
## Density: one source pixel = 3 world pixels (K), the hero's hero_scale 3.0.
## The HD canvases are larger than the 0x72 pieces, so the art sits on a
## transparent canvas: props bottom-centre (their foot stays put), wall decor
## top-centre with seven rows of air (it hangs on the brick face), decals centred.
## Pieces the pixel packs lack (banners, braziers, urns, barrels, chains, bones,
## spires, runes, blood) are drawn here in the 0x72 manner with the packs' own
## colours. Names without any pixel equivalent copy the HD sprite (reported).
##
## Usage (repo root):
##   godot --headless --path . -s res://tools/krypta_dungeon/build_krypta_pixel_skin.gd
## Writes <name>.png and manifest.json to assets/sprites/krypta_pixel/.
## Mapping table: tools/krypta_dungeon/README.md.

const K := 3
const HD := "res://assets/sprites/krypta/"
const OUT := "res://assets/sprites/krypta_pixel/"
const TILES := "res://assets/sprites/0x72/"
const PROPS := "res://assets/sprites/crypt_props/"
const DECOR := "res://assets/sprites/decor/"
const EXT := "res://assets/sprites/0x72_extended/"
## Rows of air above wall decor (source px): the piece hangs on the brick face, not on the cap.
const HANG_PAD := 7

## Palette for the drawn pieces: 0x72's own colours (stone, wood, bone, fire, iron)
## plus the Krypta's soul green, poison mire, blue fire, blood and banner cloths.
const HEX := {
	"ink": "1d1218", "s0": "222222", "s1": "302c2b", "s2": "3b3332", "s3": "483b3a", "s4": "775c55", "s5": "aa8d7a", "pale": "d3bfa9", "white": "fdf7ed",
	"w0": "38262d", "w1": "62232f", "w2": "8f4029", "w3": "c56025", "w4": "ee8e2e",
	"b0": "775c55", "b1": "aa8d7a", "b2": "d3bfa9", "b3": "fdf7ed",
	"f0": "da4e38", "f1": "ee8e2e", "f2": "facb3e", "f3": "fccba3",
	"v0": "2e5a2a", "v1": "3fae4a", "v2": "8fc46a", "v3": "cfe3b0", "v4": "f0ffe0",
	"m0": "16241a", "m1": "1e3a22", "m2": "2a5a2e", "m3": "3f7a3a", "m4": "6aa34a", "m5": "9ed06a",
	"u0": "2f5fa8", "u1": "6aa8ff", "u2": "c8e8ff", "u3": "ffffff",
	"i0": "1d1218", "i1": "2a2a3a", "i2": "4a4a5e", "i3": "6e6e86", "i4": "9a9ab0",
	"r0": "3a0c14", "r1": "62232f", "r2": "9f294e", "r3": "dc4a7b",
	"y0": "b07a2a", "y1": "e8b84a", "y2": "fff0a0",
	"p0": "2a1838", "p1": "5f2d56", "p2": "8a4ac8", "p3": "c08cff",
	# banner cloths: darker, main, lighter
	"red0": "62232f", "red1": "9f294e", "red2": "dc4a7b", "blue0": "1c2c6a", "blue1": "2f5fa8", "blue2": "6aa8ff",
	"green0": "1e5a2a", "green1": "3fae4a", "green2": "8fc46a", "gold0": "b07a2a", "gold1": "e8b84a", "gold2": "fff0a0",
	"purple0": "4a1e6a", "purple1": "8a4ac8", "purple2": "c08cff", "teal0": "1a5a5a", "teal1": "3ab0a8", "teal2": "7fe0d8",
	"pink0": "6a1e4a", "pink1": "d85a9a", "pink2": "f0a0c8", "dark0": "1d1218", "dark1": "2a1838", "dark2": "5f2d56",
}
const STONE := ["ink", "s1", "s2", "s3", "s4"]
const SOUL_FLAME := ["v1", "v2", "v3", "v4"]
const BLUE_FLAME := ["u0", "u1", "u2", "u3"]

## A skull in the 0x72 manner (the pack's own skull is a 7 px floor crumb).
const SKULL := [
	"..kkkkk..",
	".khhhhbk.",
	"khhbbbbsk",
	"kheebeesk",
	"kbeebeesk",
	"kbbbkbbsk",
	".ksbbbsk.",
	".kbtbtbk.",
	"..kkkkk..",
]
## A big carved skull for lintels and the floor seal.
const BIG_SKULL := [
	"....kkkkkkk....",
	"..kkhhhhhhhkk..",
	".khhhhhhhhhhbk.",
	"khhhhhhhhhhbbsk",
	"khhhbbhhhbbbbsk",
	"khheeebhheeebsk",
	"kbeeeebkbeeebsk",
	"kbeeeebkbeeebsk",
	"kbbeebbbbbeebsk",
	".kbbbbkkkbbbsk.",
	".kbbbkbkbkbbsk.",
	"..kbbkkkkkbbk..",
	"..kbtbtbtbtbk..",
	"...kbtbtbtbk...",
	"....kkkkkkk....",
]

var old: Dictionary = {}
var manifest: Dictionary = {}
var done: Dictionary = {}
var notes: Dictionary = {}
var cropped: Array = []
var hd_copies: Array = []
var _c := {}
var _cache := {}


func _initialize() -> void:
	for k: String in HEX:
		_c[k] = Color.html(HEX[k])
	old = JSON.parse_string(FileAccess.get_file_as_string(HD + "manifest.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build()
	# names without a recipe keep the HD sprite, so the set is complete
	for n: String in old:
		if not done.has(n):
			_save(n, img(HD + n + ".png"), "HD copy (no pixel equivalent)")
			hd_copies.append(n)
	# manifest in the HD order (same sizes and kinds), extras after
	var out := {}
	for n: String in old:
		out[n] = manifest[n]
	for n: String in manifest:
		if not out.has(n):
			out[n] = manifest[n]
	var f := FileAccess.open(OUT.path_join("manifest.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " ", true))
	f.close()
	print("KRYPTA_PIXEL %d sprites -> %s | pixel-built=%d hd-copies=%s cropped=%s" % [out.size(), OUT, out.size() - hd_copies.size(), hd_copies, cropped])
	quit(0)


# ---------------------------------------------------------------- sources and pixel tools

func col(role: String) -> Color:
	return _c[role]


func blank(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


## A source image (cached), as RGBA8.
func img(path: String) -> Image:
	if not _cache.has(path):
		var im := Image.load_from_file(ProjectSettings.globalize_path(path))
		im.convert(Image.FORMAT_RGBA8)
		_cache[path] = im
	return (_cache[path] as Image).duplicate()


func tile(n: String) -> Image:
	return img(TILES + n + ".png")


func decor(n: String) -> Image:
	return img(DECOR + n + ".png")


func prop(n: String) -> Image:
	return img(PROPS + n + ".png")


func crop(im: Image, x: int, y: int, w: int, h: int) -> Image:
	return im.get_region(Rect2i(x, y, w, h))


func trim(im: Image) -> Image:
	var r := im.get_used_rect()
	return im.get_region(r) if r.size.x > 0 else im


## Nearest-neighbour upscale by k: every source pixel becomes a k x k block.
func up(im: Image, k: int = K) -> Image:
	var o := im.duplicate() as Image
	o.resize(im.get_width() * k, im.get_height() * k, Image.INTERPOLATE_NEAREST)
	return o


func paste(dst: Image, im: Image, x: int, y: int) -> void:
	dst.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))


func flip_x(im: Image) -> Image:
	var o := im.duplicate() as Image
	o.flip_x()
	return o


func opaque(im: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height() and im.get_pixel(x, y).a > 0.5


func lum(c: Color) -> float:
	return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b


func warm(c: Color) -> bool:
	return c.a > 0.5 and c.r > 0.6 and c.r > c.g and c.g > c.b


## The pack's flame colours (red, orange, yellow, pale) onto another four-step ramp.
func recolor_fire(im: Image, ramp: Array) -> Image:
	var o := im.duplicate() as Image
	for y in range(o.get_height()):
		for x in range(o.get_width()):
			var c := o.get_pixel(x, y)
			if not warm(c):
				continue
			var l := lum(c)
			var i := 0 if l < 0.5 else (1 if l < 0.7 else (2 if l < 0.82 else 3))
			o.set_pixel(x, y, col(ramp[i]))
	return o


## The flame removed (a dead torch): the warm pixels go, stick and sconce stay.
func strip_fire(im: Image) -> Image:
	var o := im.duplicate() as Image
	for y in range(o.get_height()):
		for x in range(o.get_width()):
			if warm(o.get_pixel(x, y)):
				o.set_pixel(x, y, Color(0, 0, 0, 0))
	return o


## Only the green pixels of a tile (moss over a floor tile), the floor gone.
func green_only(im: Image) -> Image:
	var o := im.duplicate() as Image
	for y in range(o.get_height()):
		for x in range(o.get_width()):
			var c := o.get_pixel(x, y)
			if not (c.a > 0.5 and c.g > c.r + 0.08 and c.g > c.b + 0.08):
				o.set_pixel(x, y, Color(0, 0, 0, 0))
	return o


## Red cloth turned blue (the blue rug): strongly red pixels swap red and blue.
func red_to_blue(im: Image) -> Image:
	var o := im.duplicate() as Image
	for y in range(o.get_height()):
		for x in range(o.get_width()):
			var c := o.get_pixel(x, y)
			if c.a > 0.5 and c.r > 0.5 and c.g < 0.5 and c.b < 0.5:
				o.set_pixel(x, y, Color(c.b, c.g, c.r, c.a))
	return o


## A figure turned to stone: every pixel onto the stone ramp by brightness (statues).
func stone(im: Image) -> Image:
	var o := im.duplicate() as Image
	var ramp := ["ink", "s1", "s2", "s3", "s4", "s5", "pale"]
	for y in range(o.get_height()):
		for x in range(o.get_width()):
			var c := o.get_pixel(x, y)
			if c.a < 0.5:
				o.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			o.set_pixel(x, y, col(ramp[clampi(int(lum(c) * 7.5), 0, ramp.size() - 1)]))
	return o


## Nine-slice resize: `b` px of border kept, the middle tiled (rugs, lintel).
func nine(im: Image, w: int, h: int, b: int) -> Image:
	var o := blank(w, h)
	var iw := im.get_width()
	var ih := im.get_height()
	for y in range(h):
		var sy := y if y < b else (ih - (h - y) if y >= h - b else b + (y - b) % (ih - 2 * b))
		for x in range(w):
			var sx := x if x < b else (iw - (w - x) if x >= w - b else b + (x - b) % (iw - 2 * b))
			o.set_pixel(x, y, im.get_pixel(sx, sy))
	return o


## A pixel grid from strings: one character per pixel, "." transparent.
func grid(rows: Array, legend: Dictionary) -> Image:
	var w := 0
	for r: String in rows:
		w = maxi(w, r.length())
	var im := blank(w, rows.size())
	for y in range(rows.size()):
		var r: String = rows[y]
		for x in range(r.length()):
			var ch := r[x]
			if ch != "." and ch != " ":
				im.set_pixel(x, y, col(legend[ch]))
	return im


func mask_rows(rows: Array) -> Image:
	var w := 0
	for r: String in rows:
		w = maxi(w, r.length())
	var im := blank(w, rows.size())
	for y in range(rows.size()):
		var r: String = rows[y]
		for x in range(r.length()):
			if r[x] != "." and r[x] != " ":
				im.set_pixel(x, y, Color.WHITE)
	return im


func rect_mask(w: int, h: int) -> Image:
	var m := blank(w, h)
	m.fill(Color.WHITE)
	return m


func ellipse_mask(w: int, h: int, bump := 0) -> Image:
	var m := blank(w, h)
	for y in range(h):
		for x in range(w):
			var dx := (x + 0.5 - w / 2.0) / (w / 2.0)
			var dy := (y + 0.5 - h / 2.0) / (h / 2.0)
			var r := 1.0 + (0.12 if bump > 0 and (x + y * 3 + bump) % 4 == 0 else 0.0)
			if dx * dx + dy * dy <= r:
				m.set_pixel(x, y, Color.WHITE)
	return m


## A stalagmite / grave spire mask: base width w, height h, tip leaning by `lean`.
func spire_mask(w: int, h: int, lean: int, seed_value: int) -> Image:
	var m := blank(w, h)
	for y in range(h):
		var t := float(y + 1) / float(h)
		var half := maxf(0.5, (w / 2.0) * pow(t, 0.85))
		var cx := w / 2.0 - 0.5 + lean * (1.0 - t)
		var jag := 1 if ((y * 7 + seed_value) % 5 == 0 and y > 2) else 0
		for x in range(w):
			if absf(x - cx) <= half - jag * 0.6:
				m.set_pixel(x, y, Color.WHITE)
	return m


## An urn / vase mask from a width profile: neck, belly, foot.
func urn_mask(w: int, h: int, belly: float, neck: float) -> Image:
	var m := blank(w, h)
	for y in range(h):
		var t := float(y) / float(h - 1)
		var half: float
		if t < 0.15:
			half = w * neck * 0.5
		elif t < 0.2:
			half = w * (neck + 0.15) * 0.5
		elif t < 0.75:
			var u := (t - 0.2) / 0.55
			half = w * 0.5 * (belly - 0.25 * absf(u - 0.45) * 2.0)
		else:
			var u2 := (t - 0.75) / 0.25
			half = w * 0.5 * (0.45 - 0.1 * u2)
		var cx := w / 2.0 - 0.5
		for x in range(w):
			if absf(x - cx) <= half - 0.5:
				m.set_pixel(x, y, Color.WHITE)
	return m


## 0x72 shading of a mask: light on top/left edges, shade on bottom/right, dark outline around.
func shade(mask: Image, ramp: Array, outline := true) -> Image:
	var o := blank(mask.get_width() + 2, mask.get_height() + 2)
	for y in range(mask.get_height()):
		for x in range(mask.get_width()):
			if not opaque(mask, x, y):
				continue
			var lit := not opaque(mask, x, y - 1) or not opaque(mask, x - 1, y)
			var dim := not opaque(mask, x, y + 1) or not opaque(mask, x + 1, y)
			var role: String = ramp[2]
			if lit and not dim:
				role = ramp[3] if opaque(mask, x, y - 1) or opaque(mask, x - 1, y) else ramp[4]
			elif dim and not lit:
				role = ramp[1]
			o.set_pixel(x + 1, y + 1, col(role))
	if outline:
		_outline(o, ramp[0])
	return o


## Columns shaded by position across each row: left light, right shade (pillars, spires, barrels).
func shade_cols(mask: Image, ramp: Array) -> Image:
	var o := blank(mask.get_width() + 2, mask.get_height() + 2)
	for y in range(mask.get_height()):
		var x0 := -1
		var x1 := -1
		for x in range(mask.get_width()):
			if opaque(mask, x, y):
				if x0 < 0:
					x0 = x
				x1 = x
		if x0 < 0:
			continue
		for x in range(x0, x1 + 1):
			if not opaque(mask, x, y):
				continue
			var t := 0.5 if x1 == x0 else float(x - x0) / float(x1 - x0)
			var role: String = ramp[2]
			if t < 0.34:
				role = ramp[3]
			elif t > 0.7:
				role = ramp[1]
			if not opaque(mask, x, y - 1) and t < 0.6:
				role = ramp[4]
			o.set_pixel(x + 1, y + 1, col(role))
	_outline(o, ramp[0])
	return o


func _outline(o: Image, role: String) -> void:
	var c := col(role)
	var add: Array[Vector2i] = []
	for y in range(o.get_height()):
		for x in range(o.get_width()):
			if opaque(o, x, y):
				continue
			if opaque(o, x - 1, y) or opaque(o, x + 1, y) or opaque(o, x, y - 1) or opaque(o, x, y + 1):
				add.append(Vector2i(x, y))
	for p in add:
		o.set_pixelv(p, c)


func circle_px(im: Image, cx: float, cy: float, r: float, role: String) -> void:
	var steps := int(TAU * r * 2.0)
	for s in range(steps):
		var a := TAU * s / steps
		var p := Vector2i(roundi(cx + cos(a) * r), roundi(cy + sin(a) * r))
		if p.x >= 0 and p.y >= 0 and p.x < im.get_width() and p.y < im.get_height():
			im.set_pixelv(p, col(role))


## Several pieces on one image: [image, x, y] each, the lowest foot drawn last (in front).
func group(parts: Array) -> Image:
	var w := 0
	var h := 0
	for p: Array in parts:
		var im: Image = p[0]
		w = maxi(w, p[1] + im.get_width())
		h = maxi(h, p[2] + im.get_height())
	var o := blank(w, h)
	var sorted := parts.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[2] + a[0].get_height() < b[2] + b[0].get_height())
	for p: Array in sorted:
		paste(o, p[0], p[1], p[2])
	return o


# ---------------------------------------------------------------- output

func _save(name: String, im: Image, note: String) -> void:
	im.save_png(ProjectSettings.globalize_path(OUT.path_join(name + ".png")))
	var spec: Dictionary = old.get(name, {})
	manifest[name] = {"w": im.get_width(), "h": im.get_height(), "kind": str(spec.get("kind", "design" if name == "wall_top" else "sprite")), "src": note}
	done[name] = true


## `art` (source pixels) scaled x`k` on the HD canvas of `name`, anchored at (ax, ay);
## overflow is cropped away from the anchor (reported).
func put(name: String, art: Image, note: String, ax := 0.5, ay := 1.0, k := K) -> void:
	var spec: Dictionary = old[name]
	var w := int(spec.w)
	var h := int(spec.h)
	var big := up(art, k)
	if big.get_width() > w or big.get_height() > h:
		var cw := mini(w, big.get_width())
		var ch := mini(h, big.get_height())
		var cx := int(round((big.get_width() - cw) * 0.5))
		var cy := int(round((big.get_height() - ch) * (1.0 - ay)))
		big = big.get_region(Rect2i(cx, cy, cw, ch))
		cropped.append("%s(-%dx-%d)" % [name, up(art, k).get_width() - cw, up(art, k).get_height() - ch])
	var o := blank(w, h)
	paste(o, big, int(round((w - big.get_width()) * ax)), int(round((h - big.get_height()) * ay)))
	_save(name, o, note)


## Wall decor: top-centre with rows of air, so it hangs on the brick face.
func hang(name: String, art: Image, note: String, pad := HANG_PAD, k := K) -> void:
	var o := blank(art.get_width(), art.get_height() + pad)
	paste(o, art, 0, pad)
	put(name, o, note, 0.5, 0.0, k)


## A floor decal: centred on its canvas.
func decal(name: String, art: Image, note: String, k := K) -> void:
	put(name, art, note, 0.5, 0.5, k)


## An image already at the HD size (tiles, walls, bridges).
func raw(name: String, im: Image, note: String) -> void:
	var spec: Dictionary = old.get(name, {"w": im.get_width(), "h": im.get_height()})
	if im.get_width() != int(spec.w) or im.get_height() != int(spec.h):
		printerr("size mismatch %s: %dx%d, HD %dx%d" % [name, im.get_width(), im.get_height(), int(spec.w), int(spec.h)])
	_save(name, im, note)


# ---------------------------------------------------------------- shared drawn parts

func skull() -> Image:
	return grid(SKULL, {"k": "b0", "h": "b3", "b": "b2", "s": "b1", "e": "ink", "t": "b3"})


## The skull with soul-lit eyes.
func soul_skull() -> Image:
	return grid(SKULL, {"k": "b0", "h": "b3", "b": "b2", "s": "b1", "e": "v2", "t": "b3"})


func big_skull() -> Image:
	return grid(BIG_SKULL, {"k": "b0", "h": "b3", "b": "b2", "s": "b1", "e": "ink", "t": "b3"})


func bone(kind: int) -> Image:
	var shapes := [
		[".kk.....kk.", "khbkkkkkhbk", ".khhhhhhhk.", "kbskkkkkbsk", ".kk.....kk."],
		[".kk.....", "khhk....", "khbbk...", ".kbbbk..", "..kbbbk.", "...kbbsk", "....ksbk", ".....kk."],
		[".....kk.", "....khhk", "...kbbhk", "..kbbbk.", ".kbbbk..", "kbsbk...", "kbsk....", ".kk....."],
		[".kk.", "khbk", "kbsk", ".kk.", ".kh.", ".kb.", ".kb.", ".kh.", ".kk.", "khbk", "kbsk", ".kk."],
		[".kk......kk.", "khbkkkkkkhbk", ".khhhhhhhhk.", ".kk......kk."],
		["kk....", "khbk..", ".kbbk.", "..kbbk", "...kbk", "....kk"],
		["..kkk.", ".khhbk", "khbbbk", "kbbbsk", ".kbsk.", "..kk.."],
	]
	var m: Array = shapes[kind % shapes.size()]
	return grid(m, {"k": "b0", "h": "b3", "b": "b2", "s": "b1"})


## A vertical iron chain of n links (5 px wide, 6 px per link).
func iron_link_v(n: int) -> Image:
	var rows: Array = []
	for i in range(n):
		rows.append_array([".kkk.", "kh.mk", "kh.sk", ".kkk.", "..h..", "..m.."])
	return grid(rows, {"k": "i0", "h": "i4", "s": "i1", "m": "i2"})


## A stone fire bowl (the Krypta's soul bowls), w px wide, 5 rows.
func bowl(w: int) -> Image:
	var rows: Array = []
	rows.append("k" + "h".repeat(w - 2) + "k")
	rows.append("k" + "l".repeat(w - 2) + "k")
	rows.append(".k" + "m".repeat(w - 4) + "k.")
	rows.append("..k" + "s".repeat(w - 6) + "k..")
	rows.append("...k" + "k".repeat(w - 8) + "k...")
	return grid(rows, {"k": "ink", "h": "s5", "l": "s4", "m": "s3", "s": "s2"})


## A glowing soul rune (5 x 5).
func glyph(i: int, role := "v2") -> Image:
	var g := [
		[".h.h.", ".hhh.", "..h..", "..h..", ".hhh."],
		["h...h", ".h.h.", "..h..", ".h.h.", "h...h"],
		["..h..", ".h.h.", "h.h.h", ".h.h.", "..h.."],
		["hhhhh", "h...h", "..h..", "h...h", "hhhhh"],
	]
	return grid(g[i % g.size()], {"h": role})


## The pack's floor fire (decor/fire_f*), trimmed, in another flame ramp when given.
func fire(i: int, ramp: Array = []) -> Image:
	var f := trim(decor("fire_f%d" % (i % 8)))
	return recolor_fire(f, ramp) if not ramp.is_empty() else f


## The pack's wall torch (crypt_props), trimmed, recoloured when a ramp is given.
func torch(i: int, ramp: Array = []) -> Image:
	var t := trim(prop("wall_torch_f%d" % (i % 8)))
	return recolor_fire(t, ramp) if not ramp.is_empty() else t


## A 0x72-style banner: iron rod, shaded cloth with a notched tail, optional skull sigil.
func banner(w: int, h: int, cloth: String, sigil: bool) -> Image:
	var m := blank(w, h)
	var tail := 4
	for y in range(h):
		for x in range(w):
			if y >= h - tail and absf(x - (w - 1) / 2.0) < float(y - (h - tail)) + 1.0:
				continue
			m.set_pixel(x, y, Color.WHITE)
	var c := shade(m, ["ink", cloth + "0", cloth + "1", cloth + "2", cloth + "2"])
	var im := blank(w + 4, h + 4)
	paste(im, c, 1, 2)
	for x in range(w + 4):
		im.set_pixel(x, 1, col("i3" if x % 3 != 0 else "i4"))
	im.set_pixel(0, 0, col("i4"))
	im.set_pixel(w + 3, 0, col("i4"))
	if sigil:
		var s := skull()
		paste(im, s, int((w + 4 - s.get_width()) / 2.0), 3 + int(h / 4.0))
	return im


## A wooden table: lit top plank, dark front board, two legs.
func table(w: int, h: int) -> Image:
	var im := blank(w, h)
	for y in range(h):
		for x in range(w):
			var role := ""
			if y <= 7:
				if y == 0 or y == 7 or x == 0 or x == w - 1:
					role = "ink"
				elif y == 1:
					role = "w4"
				elif y < 4:
					role = "w3"
				elif y == 4:
					role = "w1"
				else:
					role = "w2"
			else:
				var leg := (x >= 2 and x <= 5) or (x >= w - 6 and x <= w - 3)
				if leg:
					role = "ink" if (x == 2 or x == 5 or x == w - 6 or x == w - 3 or y == h - 1) else ("w2" if x < 5 or x == w - 5 else "w1")
			if role != "":
				im.set_pixel(x, y, col(role))
	return im


## A wooden barrel with two iron bands.
func barrel(w: int, h: int) -> Image:
	var m := blank(w, h)
	for y in range(h):
		for x in range(w):
			if (x == 0 or x == w - 1) and (y == 0 or y == h - 1):
				continue
			m.set_pixel(x, y, Color.WHITE)
	var im := shade_cols(m, ["ink", "w1", "w2", "w3", "w4"])
	for band: int in [int(h * 0.25), int(h * 0.72)]:
		for x in range(1, w + 1):
			im.set_pixel(x, band + 1, col("i3" if x % 4 != 0 else "i4"))
	for x in range(4, w, 4):
		for y in range(1, h + 1):
			if im.get_pixel(x + 1, y).a > 0.5 and im.get_pixel(x + 1, y) != col("i3") and im.get_pixel(x + 1, y) != col("i4"):
				im.set_pixel(x + 1, y, col("w1"))
	return im


## A barrel lying on its side: wood rings seen end-on.
func barrel_side(w: int, h: int) -> Image:
	var im := shade(ellipse_mask(w, h), ["ink", "w1", "w2", "w3", "w4"])
	for x in range(2, w):
		im.set_pixel(x, int(h / 2.0) + 1, col("w1"))
		im.set_pixel(x, int(h / 2.0) + 2, col("w0"))
	circle_px(im, (w + 1) / 2.0, (h + 1) / 2.0, h / 2.0 - 1.5, "i3")
	return im


## A stone or clay urn, with a dotted band round the belly.
func urn(w: int, h: int, ramp: Array, band := true) -> Image:
	var im := shade_cols(urn_mask(w, h, 0.95, 0.5), ramp)
	if band:
		var by := int(h * 0.45) + 1
		for x in range(1, w + 1):
			if opaque(im, x, by) and x % 2 == 0:
				im.set_pixel(x, by, col(ramp[1]))
	return im


## A sack: a shaded blob with a tied neck.
func sack(w: int, h: int, bump: int) -> Image:
	var im := shade(ellipse_mask(w, h, bump), ["ink", "b0", "b1", "b2", "b2"])
	var o := blank(im.get_width(), im.get_height() + 3)
	paste(o, im, 0, 3)
	var cx := int(im.get_width() / 2.0)
	paste(o, grid([".kk.", "kbbk", ".kk."], {"k": "ink", "b": "b1"}), cx - 2, 0)
	return o


## A blood splat: a pool with satellites and drips, seeded.
func splat(w: int, h: int, seed_value: int) -> Image:
	var im := blank(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var blobs: Array = [[w / 2.0, h / 2.0, w * 0.32, h * 0.26]]
	for i in range(4 + rng.randi_range(0, 3)):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.25, 0.5)
		blobs.append([w / 2.0 + cos(a) * d * w, h / 2.0 + sin(a) * d * h, rng.randf_range(1.5, 4.0), rng.randf_range(1.2, 3.0)])
	for b: Array in blobs:
		for y in range(h):
			for x in range(w):
				var dx: float = (x + 0.5 - float(b[0])) / float(b[2])
				var dy: float = (y + 0.5 - float(b[1])) / float(b[3])
				if dx * dx + dy * dy <= 1.0:
					im.set_pixel(x, y, col("r1"))
	for i in range(rng.randi_range(1, 3)):
		var x := rng.randi_range(int(w * 0.3), int(w * 0.7))
		var y0 := int(h / 2.0)
		for y in range(y0, mini(h, y0 + rng.randi_range(3, 7))):
			im.set_pixel(x, y, col("r1"))
	# darker rim at the lower edge, a few lit specks
	var o := im.duplicate() as Image
	for y in range(h):
		for x in range(w):
			if not opaque(im, x, y):
				continue
			if not opaque(im, x, y + 1) or not opaque(im, x + 1, y):
				o.set_pixel(x, y, col("r0"))
			elif (x * 5 + y * 3 + seed_value) % 13 == 0:
				o.set_pixel(x, y, col("r2"))
	return o


## A floor plate (stone slab) of w x h with a sunk centre.
func plate(w: int, h: int) -> Image:
	var im := shade(rect_mask(w, h), STONE)
	for y in range(3, h - 1):
		for x in range(3, w - 1):
			im.set_pixel(x, y, col("s2"))
	for x in range(3, w - 1):
		im.set_pixel(x, 3, col("s1"))
	for y in range(3, h - 1):
		im.set_pixel(3, y, col("s1"))
	return im


## A rune circle in soul green: two rings, six marks, a glyph.
func rune_circle(r: float, size: int) -> Image:
	var im := blank(size, size)
	var c := (size - 1) / 2.0
	circle_px(im, c, c, r, "v0")
	circle_px(im, c, c, r - 2.0, "v1")
	circle_px(im, c, c, r - 5.0, "v0")
	for i in range(6):
		var a := -PI / 2.0 + TAU * i / 6.0
		for d: float in [r - 1.0, r - 3.5]:
			var p := Vector2(c, c) + Vector2(cos(a), sin(a)) * d
			im.set_pixel(roundi(p.x), roundi(p.y), col("v2" if d > r - 2.0 else "v1"))
	paste(im, glyph(2), int(c) - 2, int(c) - 2)
	return im


## A floor grate: frame, bars, dark (or glowing) gaps.
func grate(w: int, h: int, glow: bool) -> Image:
	var rows: Array = []
	for y in range(h):
		var r := ""
		for x in range(w):
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				r += "f"
			elif x % 3 == 0:
				r += "b"
			else:
				r += "g" if not glow else ("y" if (x + y) % 4 == 0 else "g")
		rows.append(r)
	var im := grid(rows, {"f": "s3", "b": "s2", "g": "ink" if not glow else "v0", "y": "v2"})
	var o := blank(w + 2, h + 2)
	paste(o, im, 1, 1)
	_outline(o, "ink")
	return o


## A crypt spire: a stone stalagmite with strata lines.
func spire(w: int, h: int, lean: int, s: int) -> Image:
	var im := shade_cols(spire_mask(w, h, lean, s), STONE)
	for y in range(4, im.get_height() - 2, 5):
		for x in range(im.get_width()):
			if opaque(im, x, y) and not im.get_pixel(x, y).is_equal_approx(col("ink")) and (x + y + s) % 3 == 0:
				im.set_pixel(x, y, col("s1"))
	return im


func rock(w: int, h: int, b: int, ramp: Array = STONE) -> Image:
	return shade(ellipse_mask(w, h, b), ramp)


## Moss specks from the pack's moss tile, laid over an image at (x, y).
func mossed(im: Image, x: int, y: int) -> Image:
	var o := blank(maxi(im.get_width(), x + 16), maxi(im.get_height(), y + 16))
	paste(o, im, 0, 0)
	paste(o, green_only(decor("floor_moss")), x, y)
	return trim(o)


## The 0x72 arch (doors_leaf_open / _closed), its inside filled by `fill` (x, y -> role or "").
func arch(open: bool, fill: Callable) -> Image:
	var im := tile("doors_leaf_open" if open else "doors_leaf_closed")
	for y in range(im.get_height()):
		var x0 := -1
		var x1 := -1
		for x in range(im.get_width()):
			if opaque(im, x, y):
				if x0 < 0:
					x0 = x
				x1 = x
		if x0 < 0:
			continue
		for x in range(x0, x1 + 1):
			if not opaque(im, x, y):
				var role: String = fill.call(x, y)
				if role != "":
					im.set_pixel(x, y, col(role))
	return im


## A gate: the arch between the pack's door frame posts (64 x 32).
func gate(leaf: Image) -> Image:
	var o := blank(64, 32)
	paste(o, tile("doors_frame_left"), 0, 0)
	paste(o, leaf, 16, 0)
	paste(o, tile("doors_frame_right"), 48, 0)
	return o


## The side wall seen from above: dark wall top, lit 0x72 edge strip towards the room (right).
func wall_side(w: int, h: int, strip_x: int) -> Image:
	var im := blank(w, h)
	im.fill(col("s0"))
	for y in range(h):
		for x in range(strip_x, w):
			var d := x - strip_x
			var role := "ink" if d < 3 else ("s4" if d < 9 else ("s3" if d < 12 else "s2"))
			if d >= 3 and (y % 35) < 3:
				role = "s1"
			im.set_pixel(x, y, col(role))
	return im


## A wall niche with a skull inside (wall_hole without the brick background).
func niche(w: int, h: int, two: bool) -> Image:
	var im := shade(rect_mask(w, h), STONE)
	for y in range(2, h):
		for x in range(2, w):
			im.set_pixel(x, y, col("ink" if y < h - 1 else "s1"))
	var s := soul_skull()
	if two:
		paste(im, s, 2, h - 8)
		paste(im, skull(), w - 9, h - 7)
	else:
		paste(im, s, int((w + 2 - s.get_width()) / 2.0), h - 8)
	return im


## A tileable 32 px poison mire (the Krypta's liquid): waves cut into murky green bands.
func mire_tile(seed_value: int) -> Image:
	var im := blank(32, 32)
	var ph := seed_value * 1.7
	var bands := ["m0", "m1", "m1", "m2", "m3", "m4", "m5"]
	for y in range(32):
		for x in range(32):
			var u := TAU * x / 32.0
			var v := TAU * y / 32.0
			var f := sin(u + 2.0 * v + ph) + 0.7 * sin(2.0 * u - v + ph * 0.5) + 0.45 * sin(3.0 * u + v - ph) + 0.35 * sin(u - 3.0 * v + 1.3)
			var i := 0
			if f < -1.45: i = 0
			elif f < -0.8: i = 1
			elif f < 0.1: i = 2
			elif f < 1.0: i = 3
			elif f < 1.6: i = 4
			elif f < 2.0: i = 5
			else: i = 6
			im.set_pixel(x, y, col(bands[i]))
	# no lone pixels (0x72 never dithers); bubbles as 2 px rings
	var o := im.duplicate() as Image
	for y in range(32):
		for x in range(32):
			var c := im.get_pixel(x, y)
			var same := 0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if im.get_pixel(posmod(x + d.x, 32), posmod(y + d.y, 32)).is_equal_approx(c):
					same += 1
			if same == 0:
				o.set_pixel(x, y, im.get_pixel(posmod(x + 1, 32), y))
	for p: Vector2i in [Vector2i(6 + seed_value, 9), Vector2i(22, 24 - seed_value), Vector2i(14, 28)]:
		o.set_pixel(posmod(p.x, 32), posmod(p.y, 32), col("m4"))
		o.set_pixel(posmod(p.x + 1, 32), posmod(p.y, 32), col("m5"))
	return o


# ---------------------------------------------------------------- build

func _build() -> void:
	_floors()
	_mire()
	_walls()
	_wall_decor()
	_pillars_and_braziers()
	_spires_and_rocks()
	_bones()
	_chains_and_cages()
	_decals()
	_gates_and_portals()
	_furniture()
	_loot_and_icons()


## 96 px floor cells: 2 x 2 of the pack's 16 px floor tiles, mostly plain, details sparse.
func _floors() -> void:
	var sets := {
		"floor_00": ["floor_1", "floor_1", "floor_1", "floor_1"], "floor_04": ["floor_1", "floor_1", "floor_1", "floor_5"], "floor_10": ["floor_5", "floor_1", "floor_1", "floor_1"],
		"floor_01": ["floor_1", "floor_2", "floor_1", "floor_1"], "floor_11": ["floor_1", "floor_1", "floor_3", "floor_1"], "floor_02": ["floor_4", "floor_1", "floor_1", "floor_2"],
		"floor_03": ["floor_1", "floor_6", "floor_1", "floor_1"], "floor_08": ["floor_1", "floor_1", "floor_1", "floor_7"],
		"floor_07": ["floor_8", "floor_1", "floor_1", "floor_6"], "floor_09": ["floor_1", "floor_7", "floor_8", "floor_1"],
		"floor_05": ["@floor_dark_1", "floor_1", "floor_1", "@floor_dark_2"], "floor_06": ["floor_1", "@floor_moss", "@floor_crack_3", "floor_1"],
	}
	for n: String in sets:
		var o := blank(32, 32)
		var names: Array = sets[n]
		for i in range(4):
			var t: String = names[i]
			var im := decor(t.substr(1)) if t.begins_with("@") else tile(t)
			paste(o, im, (i % 2) * 16, int(i / 2.0) * 16)
		raw(n, up(o), "0x72 floor tiles 2x2 (%s)" % ", ".join(names))


## The poison mire ("Moder") and its rim.
func _mire() -> void:
	raw("lava_00", up(mire_tile(0)), "drawn: tileable 32 px poison mire")
	raw("lava_01", up(mire_tile(3)), "drawn: tileable 32 px poison mire")
	# rim where the floor drops into the mire: dark edge and lit lip on the floor side (rows 4-5),
	# a brick lip hanging into the mire (6-9), slime at the waterline (10-11)
	var rim := blank(32, 32)
	for x in range(32):
		rim.set_pixel(x, 4, col("ink"))
		rim.set_pixel(x, 5, col("s5"))
		rim.set_pixel(x, 6, col("s1" if x % 8 == 0 else "s4"))
		rim.set_pixel(x, 7, col("s1" if x % 8 == 0 else "s3"))
		rim.set_pixel(x, 8, col("s1" if (x + 4) % 8 == 0 else "s3"))
		rim.set_pixel(x, 9, col("s1" if (x + 4) % 8 == 0 else "s2"))
		rim.set_pixel(x, 10, col("m2"))
		if (x * 5) % 7 < 3:
			rim.set_pixel(x, 11, col("m3"))
	raw("lava_edge_top", up(rim), "drawn: 0x72-style brick lip with slime line")


func _walls() -> void:
	# north/south wall: the pack's wall cap (wall_top_mid rows 7-15) over its brick face (wall_mid);
	# the foot sits at 75 px, the HD foot line (74); the rows below stay clear
	var cap := crop(tile("wall_top_mid"), 0, 7, 16, 9)
	var face := tile("wall_mid")
	var strip := blank(64, 25)
	for i in range(4):
		paste(strip, cap, i * 16, 0)
		paste(strip, face, i * 16, 9)
	var wall := blank(186, 85)
	paste(wall, crop(up(strip), 0, 0, 186, 75), 0, 0)
	raw("wall_h", wall, "0x72 wall_top_mid + wall_mid")
	raw("wall_v", wall_side(62, 70, 48), "drawn: dark wall top, lit edge strip (0x72 wall_edge_mid)")
	var top := blank(96, 96)
	top.fill(col("s0"))
	raw("wall_top", top, "0x72 wall top (flat), fills wall islands")
	# corner cap: a capstone like the top of the 0x72 column, lit bevel and sunk centre
	var rows: Array = []
	for y in range(23):
		rows.append("x".repeat(23))
	var c := shade(mask_rows(rows), ["ink", "s1", "s2", "s3", "s4"])
	for i in range(5, 20):
		c.set_pixel(i, 5, col("s1"))
		c.set_pixel(5, i, col("s1"))
		c.set_pixel(i, 19, col("s3"))
		c.set_pixel(19, i, col("s3"))
	put("corner_cap", c, "drawn: 0x72-style capstone", 0.5, 0.5)
	# posts in the north wall: a pillar with a soul slit, and the pack's column_wall
	var post := shade_cols(rect_mask(13, 33), STONE)
	for y in range(12, 26):
		post.set_pixel(7, y, col("v2" if y > 13 and y < 24 else "v1"))
		post.set_pixel(8, y, col("v1" if y > 13 and y < 24 else "v0"))
	put("wall_h_glowpost", post, "drawn: 0x72-style wall post with soul slit")
	put("wall_post_slit", tile("column_wall"), "0x72 column_wall")
	# side-wall pieces with a light: the side wall pattern over the whole canvas, a torch on it
	for spec: Array in [["wall_v_glow", torch(0), 69, 159, 4], ["wall_v_glow_blue", torch(0, BLUE_FLAME), 69, 159, 4]]:
		var o := blank(spec[2], spec[3])
		paste(o, wall_side(62, spec[3], 48), spec[4], 0)
		var t := up(spec[1])
		paste(o, t, spec[4] + 31 - int(t.get_width() / 2.0), int((spec[3] - t.get_height()) / 2.0))
		raw(spec[0], o, "drawn side wall + crypt_props wall_torch")
	var ob := blank(63, 150)
	paste(ob, wall_side(62, 150, 48), 1, 0)
	var nb := up(niche(13, 14, false))
	paste(ob, nb, 32 - int(nb.get_width() / 2.0), int((150 - nb.get_height()) / 2.0))
	raw("wall_v_glow_b", ob, "drawn side wall + skull niche")


func _wall_decor() -> void:
	hang("banner_1", banner(12, 16, "red", false), "drawn: 0x72-style banner, red")
	hang("banner_2", banner(12, 16, "blue", false), "drawn: 0x72-style banner, blue")
	hang("banner_3", banner(12, 16, "green", false), "drawn: 0x72-style banner, green")
	hang("banner_4", banner(12, 16, "gold", false), "drawn: 0x72-style banner, gold")
	hang("banner_5", banner(12, 16, "purple", true), "drawn: 0x72-style banner, purple, skull sigil")
	hang("banner_a", banner(12, 22, "red", true), "drawn: long 0x72-style banner, skull sigil")
	hang("banner_b", banner(14, 26, "dark", true), "drawn: long black 0x72-style banner, skull sigil")
	var bc := blank(16, 32)
	paste(bc, iron_link_v(2), 0, 0)
	paste(bc, iron_link_v(2), 11, 0)
	paste(bc, banner(12, 16, "red", false), 0, 12)
	hang("banner_chain", bc, "drawn: 0x72-style banner on chains")
	for spec: Array in [["boss_banner", "red"], ["boss_banner_blue", "blue"], ["boss_banner_green", "green"], ["boss_banner_purple", "purple"],
			["boss_banner_gold", "gold"], ["boss_banner_teal", "teal"], ["boss_banner_pink", "pink"]]:
		hang(spec[0], banner(18, 34, spec[1], true), "drawn: tall 0x72-style boss banner, %s, skull sigil" % spec[1])
	# torches: the crypt's wall torch frames (crypt_props = dungeontiles-extended)
	hang("torch_a", torch(0), "crypt_props wall_torch_f0")
	hang("torch_b", torch(3), "crypt_props wall_torch_f3")
	hang("torch_c", torch(6), "crypt_props wall_torch_f6")
	hang("wall_torch_hook", trim(img(EXT + "wall_torch_anim_f2.png")), "0x72_extended wall_torch_anim_f2")
	hang("torch_dead", strip_fire(torch(0)), "crypt_props wall_torch_f0 without flame")
	hang("wall_torch_blue", torch(0, BLUE_FLAME), "crypt_props wall_torch_f0, blue flame")
	var block := shade(rect_mask(10, 7), STONE)
	var tb := blank(12, 34)
	var t5 := torch(5)
	paste(tb, t5, int((12 - t5.get_width()) / 2.0), 0)
	paste(tb, block, 0, 25)
	hang("wall_torch_block", trim(tb), "crypt_props wall_torch_f5 on a drawn stone block")
	# wall fire bowl with a soul flame, on a bracket
	var wb := blank(14, 22)
	var fl := fire(2, SOUL_FLAME)
	paste(wb, fl, int((14 - fl.get_width()) / 2.0), 12 - fl.get_height())
	paste(wb, bowl(12), 1, 12)
	paste(wb, grid(["..kk..", "..kk..", ".kmmk.", "kmmmmk"], {"k": "ink", "m": "i1"}), 4, 17)
	hang("wall_brazier", trim(wb), "drawn: wall soul bowl, decor fire")
	# hanging fire basket on two chains
	var hb := blank(30, 26)
	paste(hb, iron_link_v(2), 3, 0)
	paste(hb, iron_link_v(2), 22, 0)
	var fl2 := fire(4, SOUL_FLAME)
	paste(hb, fl2, int((30 - fl2.get_width()) / 2.0), 18 - fl2.get_height())
	paste(hb, grid(["k.k.k.k.k.k.k.k.k.k.k.", "kmkmkmkmkmkmkmkmkmkmkk", ".kmmmmmmmmmmmmmmmmmmk.", "..kkkkkkkkkkkkkkkkkk.."], {"k": "ink", "m": "i2"}), 4, 18)
	hang("hanging_brazier", trim(hb), "drawn: hanging fire basket, decor fire", 3)
	hang("wall_skull_a", niche(13, 14, false), "drawn: wall niche with 0x72-style skull")
	hang("wall_skull_b", niche(18, 13, true), "drawn: wall niche with two skulls")


func _pillars_and_braziers() -> void:
	var column := trim(tile("column"))
	for i in range(3):
		var p := column.duplicate() as Image
		paste(p, glyph(i), int((p.get_width() - 5) / 2.0), 16 + (i % 2) * 3)
		put("rune_pillar_%s" % ["a", "b", "c"][i], p, "0x72 column, soul rune")
	var candle := trim(prop("candle_column_f0"))
	put("rune_pillar_d", candle, "crypt_props candle_column_f0")
	put("torch_pillar", candle, "crypt_props candle_column_f0")
	put("torch_pillar_blue", recolor_fire(candle, BLUE_FLAME), "crypt_props candle_column_f0, blue flames")
	put("candelabra", candle, "crypt_props candle_column_f0")
	put("jamb_a", column, "0x72 column")
	put("jamb_b", flip_x(column), "0x72 column, mirrored")
	put("shelf", trim(decor("cabinet")), "decor cabinet")
	# obelisk: a tall tapering stone with two runes
	var ob := shade_cols(mask_rows([
		".....xx.....", "....xxxx....", "....xxxx....", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...",
		"...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "..xxxxxxxx..", "..xxxxxxxx..",
		"..xxxxxxxx..", "..xxxxxxxx..", "..xxxxxxxx..", "..xxxxxxxx..", "..xxxxxxxx..", "..xxxxxxxx..", ".xxxxxxxxxx.", ".xxxxxxxxxx.",
		"xxxxxxxxxxxx", "xxxxxxxxxxxx", "xxxxxxxxxxxx"]), STONE)
	paste(ob, glyph(0), 4, 8)
	paste(ob, glyph(2), 4, 16)
	put("obelisk", ob, "drawn: 0x72-style obelisk with soul runes")
	var so := crop(column, 0, 0, column.get_width(), mini(36, column.get_height()))
	var sk := soul_skull()
	var so2 := blank(so.get_width(), so.get_height() + 8)
	paste(so2, so, 0, 8)
	paste(so2, sk, int((so.get_width() - sk.get_width()) / 2.0), 0)
	put("skull_obelisk", so2, "0x72 column + drawn skull")
	# the soul bowl: flame in rows 2-12 (above canvas row 46, so unlit draws only the bowl), bowl and foot below
	var bowl_art := func(fl: Image, bw: int, foot_h: int, base: bool, glyph_i: int) -> Image:
		var h := 12 + 5 + foot_h + (2 if base else 0)
		var o := blank(16, h)
		paste(o, fl, int((16 - fl.get_width()) / 2.0), 12 - fl.get_height())
		paste(o, bowl(bw), int((16 - bw) / 2.0), 12)
		if foot_h > 0:
			paste(o, shade_cols(rect_mask(4, foot_h - 2), STONE), 5, 16)
		if base:
			paste(o, shade(rect_mask(10, 1), STONE), 2, h - 3)
		if glyph_i >= 0:
			paste(o, glyph(glyph_i), 6, 20)
		return o
	raw("brazier_bowl", _canvas(up(bowl_art.call(fire(0, SOUL_FLAME), 14, 11, true, -1)), "brazier_bowl"), "drawn: soul bowl on a foot, decor fire (flame above row 46)")
	raw("brazier_blue", _canvas(up(bowl_art.call(fire(0, BLUE_FLAME), 14, 11, true, -1)), "brazier_blue"), "drawn: blue soul bowl, decor fire")
	raw("bowl_blue", _canvas(up(bowl_art.call(grid(["..u..", ".uuu.", "uuuuu"], {"u": "u0"}), 14, 9, true, -1)), "bowl_blue"), "drawn: faint blue bowl")
	put("brazier_floor", bowl_art.call(fire(1, SOUL_FLAME), 14, 3, false, -1), "drawn: floor soul bowl, decor fire")
	put("brazier_low", bowl_art.call(fire(3, SOUL_FLAME), 12, 3, false, -1), "drawn: low soul bowl, decor fire")
	var lowb: Image = bowl_art.call(fire(5, SOUL_FLAME), 12, 3, false, -1)
	paste(lowb, grid(["c.y.c.y", ".c.c.c."], {"c": "v0", "y": "v2"}), 4, 11)
	put("brazier_low_b", lowb, "drawn: low soul bowl with embers, decor fire")
	put("brazier_pillar", bowl_art.call(fire(2, SOUL_FLAME), 14, 29, true, -1), "drawn: soul bowl on a pillar, decor fire")
	put("brazier_rune", bowl_art.call(fire(6, SOUL_FLAME), 12, 17, true, 1), "drawn: soul bowl on a rune pillar, decor fire")
	# the skull bowl: a bowl with a carved skull on the front, on a pedestal
	var db: Image = bowl_art.call(fire(7, SOUL_FLAME), 14, 19, true, -1)
	paste(db, skull(), 4, 15)
	put("brazier_demon", db, "drawn: skull soul bowl, decor fire")
	# coals: dark stones with soul embers
	var coal: Image = group([[rock(7, 5, 1, ["ink", "ink", "s0", "s1", "s2"]), 0, 2], [rock(6, 5, 2, ["ink", "ink", "s0", "s1", "s2"]), 5, 0], [rock(5, 4, 3, ["ink", "ink", "s0", "s1", "s2"]), 10, 3]])
	for p: Vector2i in [Vector2i(3, 4), Vector2i(7, 2), Vector2i(8, 3), Vector2i(12, 5), Vector2i(5, 6)]:
		if opaque(coal, p.x, p.y):
			coal.set_pixelv(p, col("v2" if p.x % 2 == 0 else "v1"))
	put("coal", coal, "drawn: 0x72-style coals with soul embers")
	var cs := blank(coal.get_width() + 2, coal.get_height() + 7)
	paste(cs, coal, 0, 7)
	paste(cs, soul_skull(), 4, 0)
	put("coal_skulls", trim(cs), "drawn coals + skull")


## A scaled image on the HD canvas of `name`, bottom-centre (for raw-sized checks).
func _canvas(big: Image, name: String) -> Image:
	var spec: Dictionary = old[name]
	var o := blank(int(spec.w), int(spec.h))
	paste(o, big, int(round((int(spec.w) - big.get_width()) * 0.5)), int(spec.h) - big.get_height())
	return o


func _spires_and_rocks() -> void:
	var big := spire(14, 32, 1, 1)
	put("spire_big", big, "drawn: 0x72-style stone spire")
	put("spire_big_b", spire(12, 28, -1, 4), "drawn: 0x72-style stone spire")
	put("spire_big_t", group([[big, 6, 0], [spire(8, 16, 1, 2), 0, 17], [spire(7, 12, -1, 3), 15, 21]]), "drawn: 0x72-style spire group")
	put("spire_mid", spire(10, 22, 1, 5), "drawn: 0x72-style stone spire")
	put("spire_small", spire(8, 15, -1, 6), "drawn: 0x72-style stone spire")
	put("spire_tiny", spire(6, 10, 1, 7), "drawn: 0x72-style stone spire")
	put("spire_t", group([[spire(9, 20, 1, 8), 0, 0], [spire(7, 13, -1, 9), 7, 8]]), "drawn: 0x72-style spire pair")
	put("spires_t", group([[spire(7, 14, 1, 2), 0, 2], [spire(8, 17, 0, 3), 5, 0], [spire(6, 10, -1, 4), 11, 7]]), "drawn: 0x72-style spire cluster")
	var sl: Image = group([[spire(9, 20, 1, 3), 0, 0], [spire(7, 13, -1, 5), 8, 8]])
	for y in range(sl.get_height() - 4, sl.get_height()):
		for x in range(sl.get_width()):
			if opaque(sl, x, y) and not sl.get_pixel(x, y).is_equal_approx(col("ink")):
				sl.set_pixel(x, y, col("m3" if y < sl.get_height() - 2 else "m4"))
	put("spires_lava", sl, "drawn: 0x72-style spires slimed at the base")
	put("rocks_a", group([[rock(9, 7, 1), 0, 3], [rock(7, 6, 2), 8, 0], [rock(5, 4, 3), 12, 7]]), "drawn: 0x72-style rocks")
	put("rocks_b", group([[rock(8, 6, 2), 0, 1], [rock(6, 5, 1), 7, 3]]), "drawn: 0x72-style rocks")
	var dark := ["ink", "s0", "s1", "s2", "s3"]
	put("rocks_dark", group([[rock(8, 7, 3, dark), 0, 2], [rock(6, 5, 1, dark), 6, 0]]), "drawn: 0x72-style dark rocks")
	var rl: Image = group([[rock(9, 7, 1), 0, 2], [rock(7, 6, 2), 7, 0]])
	for p: Vector2i in [Vector2i(3, 5), Vector2i(4, 6), Vector2i(5, 6), Vector2i(10, 3), Vector2i(10, 4), Vector2i(11, 5)]:
		if opaque(rl, p.x, p.y):
			rl.set_pixelv(p, col("m4"))
	put("rocks_lava", rl, "drawn: 0x72-style rocks with slime")
	put("boulders", group([[rock(12, 9, 2), 0, 2], [rock(9, 8, 3), 10, 0]]), "drawn: 0x72-style boulders")
	var rubble: Image = group([[rock(5, 3, 1), 0, 4], [rock(4, 3, 2), 5, 1], [rock(6, 4, 3), 9, 4], [rock(3, 2, 1), 15, 2], [rock(4, 3, 2), 3, 8]])
	put("rubble", rubble, "drawn: 0x72-style rubble")
	decal("moss_rubble_a", mossed(rubble, 2, -2 + 4), "drawn rubble + decor floor_moss specks")
	decal("moss_rubble_b", mossed(group([[rock(6, 4, 1), 0, 2], [rock(5, 3, 2), 7, 0], [rock(4, 3, 3), 13, 3]]), 1, 0), "drawn rubble + decor floor_moss specks")
	var column := trim(tile("column"))
	var ruin := crop(column, 0, column.get_height() - 24, column.get_width(), 24)
	put("moss_ruin", mossed(ruin, 0, 6), "0x72 column stump + decor floor_moss specks")
	var moss := green_only(decor("floor_moss"))
	for spec: Array in [["moss_a", 10, 8], ["moss_b", -6, 7], ["moss_c", 4, -9]]:
		var o := blank(32, 32)
		paste(o, moss, 8, 8)
		paste(o, moss, 8 + spec[1], 8 + spec[2])
		decal(spec[0], trim(o), "decor floor_moss specks (two patches)")


func _bones() -> void:
	var s := skull()
	var hs := soul_skull()
	var pile := func(spots: Array) -> Image:
		var o := blank(40, 30)
		for p: Vector2i in spots:
			paste(o, s if (p.x + p.y) % 3 else hs, p.x, p.y)
		return trim(o)
	put("skull_pile", pile.call([Vector2i(0, 6), Vector2i(7, 6), Vector2i(14, 6), Vector2i(3, 1), Vector2i(10, 1)]), "drawn: 0x72-style skull pile")
	put("skull_pile_t", pile.call([Vector2i(0, 5), Vector2i(7, 5), Vector2i(4, 0)]), "drawn: 0x72-style skull pile")
	var heap := blank(40, 30)
	for p: Vector2i in [Vector2i(0, 16), Vector2i(7, 17), Vector2i(14, 17), Vector2i(21, 17), Vector2i(28, 16), Vector2i(4, 11), Vector2i(11, 11),
			Vector2i(18, 11), Vector2i(25, 11), Vector2i(8, 6), Vector2i(15, 5), Vector2i(22, 6), Vector2i(12, 0), Vector2i(19, 1)]:
		paste(heap, hs if (p.x * 3 + p.y) % 4 == 0 else s, p.x, p.y)
	paste(heap, bone(0), 26, 21)
	paste(heap, bone(1), 0, 20)
	put("skull_heap", trim(heap), "drawn: 0x72-style skull heap (secret wall marker)")
	for i in range(7):
		decal("bone_%s" % ["a", "b", "c", "d", "e", "f", "g"][i], bone(i), "drawn: 0x72-style bone")
	var bs := blank(24, 16)
	paste(bs, bone(0), 0, 6)
	paste(bs, bone(1), 12, 0)
	paste(bs, bone(3), 9, 2)
	decal("bones_scatter", trim(bs), "drawn: 0x72-style bones")
	var bt := blank(20, 14)
	paste(bt, bone(2), 0, 0)
	paste(bt, s, 8, 4)
	decal("bones_t", trim(bt), "drawn bones + skull")
	decal("demon_head", big_skull(), "drawn: carved skull in the floor")


func _chains_and_cages() -> void:
	hang("chain_a", iron_link_v(5), "drawn: 0x72-style iron chain", 0)
	hang("chain_b", iron_link_v(4), "drawn: 0x72-style iron chain", 0)
	hang("chain_long", iron_link_v(6), "drawn: 0x72-style iron chain", 0)
	hang("chain_long_b", iron_link_v(5), "drawn: 0x72-style iron chain", 0)
	hang("chain_hang", iron_link_v(7), "drawn: 0x72-style iron chain", 0)
	var hook := iron_link_v(5)
	var hk := blank(7, hook.get_height() + 3)
	paste(hk, hook, 1, 0)
	paste(hk, grid(["k.....k", "kk...kk", ".kmmmk."], {"k": "i0", "m": "i2"}), 0, hook.get_height())
	hang("chain_hook", hk, "drawn: 0x72-style chain with hook", 0)
	# two chains from the wall joined by a sagging chain
	var swag := func(w: int, sag: float, drop: int) -> Image:
		var o := blank(w, drop + int(sag) + 6)
		paste(o, iron_link_v(drop / 6), 0, 0)
		paste(o, iron_link_v(drop / 6), w - 5, 0)
		for x in range(2, w - 2):
			var t := float(x - 2) / float(w - 5)
			var y := drop + int(round(sag * 4.0 * t * (1.0 - t)))
			o.set_pixel(x, y, col("i4" if x % 3 == 0 else "i3"))
			o.set_pixel(x, y + 1, col("i1"))
		return trim(o)
	hang("chain_swag", swag.call(17, 7.0, 18), "drawn: 0x72-style chains with a sagging link", 0)
	hang("chain_swag_b", swag.call(17, 5.0, 12), "drawn: 0x72-style chains with a sagging link", 0)
	var cuff := grid([".kkkk.", "kmssmk", "km..mk", "kmssmk", ".kkkk."], {"k": "i0", "m": "i2", "s": "i3"})
	for i in range(2):
		var o := blank(6, 30)
		paste(o, iron_link_v(2 + i), 0, 0)
		paste(o, cuff, 0, 12 + 6 * i)
		hang("shackle_%s" % ["a", "b"][i], trim(o), "drawn: 0x72-style shackle on a chain", 0)
	var ss := blank(10, 30)
	paste(ss, iron_link_v(2), 2, 0)
	paste(ss, cuff, 2, 12)
	paste(ss, soul_skull(), 1, 16)
	hang("shackle_skull", trim(ss), "drawn shackle + skull", 0)
	var cage := func(w: int, h: int, with_skull: bool) -> Image:
		var o := blank(w, h)
		for y in range(h):
			for x in range(w):
				var edge_y := y == 0 or y == 1 or y == h - 1 or y == h - 2
				var bar := x % 3 == 0 or x == w - 1
				if edge_y:
					o.set_pixel(x, y, col("i2" if y % 2 == 0 else "i1"))
				elif bar:
					o.set_pixel(x, y, col("i3" if x < w / 2.0 else "i1"))
		if with_skull:
			var sk := soul_skull()
			var inside := blank(w, h)
			paste(inside, sk, int((w - sk.get_width()) / 2.0), h - 2 - sk.get_height())
			paste(inside, o, 0, 0)
			o = inside
		var framed := blank(w + 2, h + 2)
		paste(framed, o, 1, 1)
		_outline(framed, "i0")
		return framed
	var hang_cage := blank(14, 34)
	paste(hang_cage, iron_link_v(2), 5, 0)
	paste(hang_cage, cage.call(12, 20, true), 0, 12)
	hang("cage_hang", trim(hang_cage), "drawn: 0x72-style hanging cage with skull")
	put("cage_small", cage.call(12, 18, true), "drawn: 0x72-style standing cage with skull")


func _decals() -> void:
	decal("rune_big", rune_circle(12.0, 26), "drawn: 0x72-style soul rune circle")
	decal("rune_small", rune_circle(13.5, 29), "drawn: 0x72-style soul rune circle")
	var pl := plate(20, 20)
	var button := trim(tile("button_blue_up"))
	paste(pl, button, int((22 - button.get_width()) / 2.0), int((22 - button.get_height()) / 2.0))
	decal("rune_plate", pl, "0x72 button_blue_up in a drawn stone plate")
	var fp := plate(20, 20)
	paste(fp, grid(["kkkkkkkkkkkk", "kyklkyklkyk", "kkkkkkkkkkkk", "klkyklkyklk", "kkkkkkkkkkkk", "kyklkyklkyk", "kkkkkkkkkkkk"], {"k": "ink", "y": "v2", "l": "v1"}), 5, 7)
	decal("fire_plate", fp, "drawn: 0x72-style soul grate plate")
	var dp := plate(20, 20)
	var bsk := big_skull()
	paste(dp, bsk, int((22 - bsk.get_width()) / 2.0), int((22 - bsk.get_height()) / 2.0))
	decal("demon_plate", dp, "drawn: stone plate with carved skull")
	# pit: a dark hole with a stone rim, the near rim lit
	var pit := blank(30, 26)
	var outer := ellipse_mask(30, 26)
	var inner := ellipse_mask(24, 20)
	for y in range(26):
		for x in range(30):
			if not opaque(outer, x, y):
				continue
			var role := "s2" if y < 13 else "s3"
			if opaque(inner, x - 3, y - 3):
				role = "ink" if y > 6 else "s0"
			pit.set_pixel(x, y, col(role))
	_outline(pit, "ink")
	decal("pit", pit, "drawn: 0x72-style pit")
	decal("grate", grate(19, 19, false), "drawn: 0x72-style floor grate")
	decal("grate_a", grate(13, 13, false), "drawn: 0x72-style floor grate")
	decal("grate_b", grate(16, 13, true), "drawn: 0x72-style grate with soul glow")
	decal("vent", grate(13, 13, true), "drawn: 0x72-style vent with soul glow")
	# spikes: a stone plate with iron spikes; a block with bone spikes on top
	var spikes := func(w: int, n: int) -> Image:
		var o := plate(w, w)
		var step := int((w - 4) / float(n))
		for i in range(n):
			for j in range(n):
				var sx := 4 + i * step + int(step / 2.0) - 1
				var sy := 4 + j * step + int(step / 2.0) - 3
				paste(o, grid([".w.", ".m.", "kmk", "kkk"], {"w": "i4", "m": "i3", "k": "i1"}), sx, sy)
		return o
	decal("spike_trap", spikes.call(24, 3), "drawn: 0x72-style spike plate")
	decal("spike_trap_b", spikes.call(16, 2), "drawn: 0x72-style spike plate")
	var sb := blank(22, 22)
	paste(sb, shade(rect_mask(20, 13), STONE), 0, 7)
	for i in range(5):
		paste(sb, grid([".h.", ".b.", "sbs"], {"h": "b3", "b": "b2", "s": "b1"}), 1 + i * 4, 5)
	put("spike_block", sb, "drawn: stone block with bone spikes")
	for i in range(6):
		decal("blood_%s" % ["a", "b", "c", "d", "e", "f"][i], splat(26, 22, 11 + i * 7), "drawn: blood splat (seeded)")
	# bridges: dark planks between iron rails, tiled along their run by the game (tools: _tile_bridge)
	for spec: Array in [["bridge_v", true], ["bridge_h", false]]:
		var im := blank(212, 212)
		var rails_on_x: bool = spec[1]
		for y in range(212):
			for x in range(212):
				var a := x if rails_on_x else y
				var b := y if rails_on_x else x
				var pa := int(a / 3.0)
				var pb := int(b / 3.0)
				var role: String
				if pa < 4 or pa >= 67:
					role = ["i0", "i2", "i3", "i1"][mini(pa, 70 - pa)]
				elif pa == 4 or pa == 66:
					role = "ink"
				else:
					var plank := int(pb / 4.0)
					role = "ink" if pb % 4 == 3 else ("w2" if (plank + int(pa / 10.0)) % 2 == 0 else "w1")
				im.set_pixel(x, y, col(role))
		raw(spec[0], im, "drawn: planks between iron rails")
	# rugs and carpets: the pack's rugs, nine-sliced to the HD footprint
	var rug := decor("rug_red")
	var beige := decor("rug_beige")
	decal("rug_red", nine(rug, 30, 56, 6), "decor rug_red, nine-sliced")
	decal("rug_blue", nine(red_to_blue(rug), 29, 55, 6), "decor rug_red turned blue, nine-sliced")
	decal("carpet", nine(rug, 19, 48, 6), "decor rug_red as a runner, nine-sliced")
	decal("rug_square", nine(beige, 16, 19, 6), "decor rug_beige, nine-sliced")
	decal("mat", nine(beige, 27, 18, 6), "decor rug_beige, nine-sliced")


func _gates_and_portals() -> void:
	var soul := func(x: int, y: int) -> String:
		var cx := absi(x - 16)
		if (x * 7 + y * 13) % 11 == 0:
			return "v3"
		return "p3" if cx < 3 and y > 10 else ("p2" if cx < 7 else "p1")
	var dark := func(_x: int, _y: int) -> String:
		return "s0"
	var stairs_tile := tile("floor_stairs")
	var stairs := func(x: int, y: int) -> String:
		if y >= 16 and x >= 8 and x < 24:
			var c := stairs_tile.get_pixel(x - 8, y - 16)
			if c.a > 0.5:
				return "s1" if lum(c) < 0.25 else ("s3" if lum(c) < 0.4 else "s4")
		return "ink"
	put("portal", arch(true, soul), "0x72 doors_leaf_open with soul glow")
	put("portal_dark", arch(true, dark), "0x72 doors_leaf_open, dark")
	put("stairs_down", arch(true, stairs), "0x72 doors_leaf_open + floor_stairs", 0.5, 1.0, 4)
	put("door_stairs", gate(arch(true, stairs)), "0x72 door frames + doors_leaf_open + floor_stairs")
	put("door_stairs_small", arch(true, stairs), "0x72 doors_leaf_open + floor_stairs")
	var closed := arch(false, dark)
	put("gate_side", gate(closed), "0x72 door frames + doors_leaf_closed")
	# portcullis: iron bars over the closed leaf
	var bars := closed.duplicate() as Image
	for y in range(9, 31):
		for x in range(7, 26, 3):
			bars.set_pixel(x, y, col("i3" if y % 6 != 0 else "i4"))
			bars.set_pixel(x + 1, y, col("i1"))
	put("portcullis", gate(bars), "0x72 door frames + doors_leaf_closed with drawn iron bars")
	# the lintel over a gate: the pack's frame top stretched, a carved skull on it
	var lintel := blank(88, 31)
	paste(lintel, nine(tile("doors_frame_top"), 88, 16, 8), 0, 15)
	paste(lintel, big_skull(), 36, 0)
	put("demon_lintel", lintel, "0x72 doors_frame_top nine-sliced + carved skull", 0.5, 0.5)
	# the boss gate: the same gate larger (x4), torches on its posts
	var boss := gate(closed)
	var t := torch(1)
	paste(boss, t, 8 - int(t.get_width() / 2.0), 4)
	paste(boss, t, 56 - int(t.get_width() / 2.0), 4)
	put("boss_gate", boss, "0x72 door frames + doors_leaf_closed, crypt_props torches, x4", 0.5, 1.0, 4)
	var boss_blue := gate(closed)
	var tb := torch(1, BLUE_FLAME)
	paste(boss_blue, tb, 8 - int(tb.get_width() / 2.0), 4)
	paste(boss_blue, tb, 56 - int(tb.get_width() / 2.0), 4)
	put("boss_gate_blue", boss_blue, "0x72 door frames + doors_leaf_closed, blue torches, x4", 0.5, 1.0, 4)
	put("boss_arch", gate(arch(true, soul)), "0x72 door frames + doors_leaf_open with soul glow, x4", 0.5, 1.0, 4)
	# the altar: slab on a pedestal, skull and candles on it
	var altar := blank(30, 24)
	paste(altar, shade_cols(rect_mask(16, 12), STONE), 6, 10)
	paste(altar, shade(rect_mask(28, 5), STONE), 0, 7)
	paste(altar, skull(), 10, 0)
	for x: int in [3, 24]:
		paste(altar, grid([".f.", ".p.", ".p.", "kpk"], {"f": "f2", "p": "b3", "k": "ink"}), x, 3)
	put("altar", altar, "drawn: stone altar with skull and candles")
	# the fountain: the pack's wall fountain (top, mid, basin), blue water
	var fountain := blank(16, 48)
	paste(fountain, tile("wall_fountain_top_1"), 0, 0)
	paste(fountain, tile("wall_fountain_mid_blue_anim_f0"), 0, 16)
	paste(fountain, tile("wall_fountain_basin_blue_anim_f0"), 0, 32)
	put("fountain", fountain, "0x72 wall_fountain top + mid + basin (blue)")
	# statues: the pack's figures turned to stone, on a pedestal
	var statue := func(figure: Image, pw: int) -> Image:
		var f := trim(stone(figure))
		var o := blank(maxi(f.get_width(), pw + 2), f.get_height() + 5)
		paste(o, shade(rect_mask(pw, 3), STONE), int((o.get_width() - pw - 2) / 2.0), f.get_height())
		paste(o, f, int((o.get_width() - f.get_width()) / 2.0), 0)
		return o
	put("statue_angel", statue.call(tile("angel_idle_anim_f0"), 14), "0x72 angel frame turned to stone, on a pedestal")
	put("statue_monk", statue.call(tile("necromancer_idle_anim_f0"), 12), "0x72 necromancer frame turned to stone, on a pedestal")
	put("gargoyle", statue.call(tile("big_demon_idle_anim_f0"), 28), "0x72 big_demon frame turned to stone, on a pedestal")


func _furniture() -> void:
	put("table_a", table(38, 20), "drawn: 0x72-style wooden table")
	var tb := table(40, 24)
	paste(tb, skull(), 15, -1)
	put("table_b", tb, "drawn: 0x72-style wooden table with skull")
	var tc := table(50, 22)
	paste(tc, grid([".f.", ".p.", "kpk"], {"f": "f2", "p": "b3", "k": "ink"}), 10, -1)
	paste(tc, grid([".f.", ".p.", "kpk"], {"f": "f2", "p": "b3", "k": "ink"}), 37, -1)
	put("table_c", tc, "drawn: 0x72-style wooden table with candles")
	var bench := blank(42, 14)
	paste(bench, crop(table(42, 20), 0, 0, 42, 8), 0, 0)
	for x: int in [2, 36]:
		paste(bench, grid(["kwwk", "kwwk", "kwwk", "kwwk", "kwwk", "kkkk"], {"k": "ink", "w": "w1"}), x, 8)
	put("bench", bench, "drawn: 0x72-style wooden bench")
	var shop := table(54, 30)
	var fx := 6
	for n: String in ["flask_red", "flask_blue", "flask_green", "flask_big_yellow"]:
		var f := trim(tile(n))
		paste(shop, f, fx, 1 - f.get_height() + 1)
		fx += f.get_width() + 5
	put("shop_table", shop, "drawn: 0x72-style counter with 0x72 flasks")
	var crate := trim(tile("crate"))
	put("crate_a", crate, "0x72 crate")
	var cb := flip_x(crate)
	paste(cb, trim(decor("skull_small")), 4, -1)
	put("crate_b", cb, "0x72 crate, mirrored, decor skull_small")
	var cc := blank(crate.get_width() + 4, crate.get_height() + 3)
	paste(cc, crate, 0, 3)
	paste(cc, bone(1), crate.get_width() - 5, 0)
	put("crate_c", trim(cc), "0x72 crate with a drawn bone")
	var pile := blank(crate.get_width() * 2 - 2, crate.get_height() + 13)
	paste(pile, crate, 0, 13)
	paste(pile, flip_x(crate), crate.get_width() - 2, 13)
	paste(pile, crate, int(crate.get_width() / 2.0) - 1, 0)
	put("crate_pile", trim(pile), "0x72 crates stacked")
	put("barrel_a", barrel(11, 15), "drawn: 0x72-style barrel")
	put("barrel_b", barrel(13, 17), "drawn: 0x72-style barrel")
	put("barrel_c", barrel_side(15, 11), "drawn: 0x72-style barrel on its side")
	var clay := ["ink", "w1", "w2", "w3", "w4"]
	put("urn_a", urn(13, 20, STONE), "drawn: 0x72-style stone urn")
	put("urn_b", urn(9, 14, clay, false), "drawn: 0x72-style clay pot")
	put("urn_c", urn(12, 20, STONE), "drawn: 0x72-style stone urn")
	put("urn_d", urn(13, 22, clay), "drawn: 0x72-style clay urn")
	var ue := blank(16, 24)
	paste(ue, urn(14, 20, STONE), 0, 4)
	paste(ue, bone(3), 10, 0)
	put("urn_e", trim(ue), "drawn: 0x72-style stone urn with a bone")
	put("sacks_a", group([[sack(10, 9, 1), 0, 4], [sack(9, 8, 2), 8, 2]]), "drawn: 0x72-style sacks")
	put("sacks_b", group([[sack(10, 9, 1), 0, 2], [sack(9, 8, 2), 10, 3], [sack(10, 9, 3), 19, 1]]), "drawn: 0x72-style sacks in a row")
	put("sacks_c", group([[sack(10, 9, 1), 0, 6], [sack(10, 9, 2), 10, 6], [sack(9, 8, 3), 5, 0]]), "drawn: 0x72-style sack pile")


func _loot_and_icons() -> void:
	decal("heart", trim(tile("ui_heart_full")), "0x72 ui_heart_full")
	var orb := shade(ellipse_mask(12, 13), ["v0", "v1", "v2", "v3", "v4"])
	orb.set_pixel(5, 4, col("v4"))
	orb.set_pixel(6, 4, col("v4"))
	decal("fire_orb", orb, "drawn: soul orb")
	decal("key", grid([".kkk.", "kyyyk", "ky.yk", "kyyyk", ".kyk.", ".kyk.", ".khk.", ".kyyk", ".kyk.", ".kyyk", ".kkk."], {"k": "ink", "y": "y1", "h": "y2"}), "drawn: 0x72-style key")
	decal("rune_gem", grid(["....k....", "...kpk...", "..kphpk..", ".kpphppk.", "kppphpppk", ".kpppppk.", "..kdpdk..", "...kdk...", "....k...."], {"k": "ink", "p": "p2", "h": "p3", "d": "p1"}), "drawn: soul gem")
	var closed := trim(tile("chest_full_open_anim_f0"))
	var open_full := trim(tile("chest_full_open_anim_f2"))
	var open_empty := trim(tile("chest_empty_open_anim_f2"))
	put("chest_closed", closed, "0x72 chest_full_open_anim_f0")
	put("chest_open", open_full, "0x72 chest_full_open_anim_f2")
	put("chest_empty", open_empty, "0x72 chest_empty_open_anim_f2")
	put("chest_vault", closed, "0x72 chest_full_open_anim_f0, x4 (the vault chest)", 0.5, 1.0, 4)
	put("chest_gold", open_full, "0x72 chest_full_open_anim_f2, x4 (the vault chest open)", 0.5, 1.0, 4)
	decal("icon_chest", closed, "0x72 chest_full_open_anim_f0")
	decal("icon_scroll", trim(decor("sign_1")), "decor sign_1")
	decal("icon_door", trim(tile("doors_leaf_closed")), "0x72 doors_leaf_closed, x2", 2)
	decal("icon_demon", skull(), "drawn skull, x5", 5)
	decal("icon_demon_big", big_skull(), "drawn big skull, x4", 4)
	# crossed swords: two 0x72-style blades, hilts low
	var sw := blank(15, 15)
	for i in range(11):
		for p: Vector2i in [Vector2i(2 + i, i), Vector2i(12 - i, i)]:
			sw.set_pixelv(p, col("i4" if i < 9 else "y1"))
			if i < 9:
				var q := p + Vector2i(1 if p.x < 7 else -1, 0)
				if sw.get_pixel(q.x, q.y).a < 0.5:
					sw.set_pixelv(q, col("i3"))
	for p: Vector2i in [Vector2i(10, 9), Vector2i(14, 9), Vector2i(0, 9), Vector2i(4, 9), Vector2i(13, 11), Vector2i(14, 12), Vector2i(1, 11), Vector2i(0, 12)]:
		sw.set_pixelv(p, col("y1" if p.y == 9 else "w2"))
	var swo := blank(17, 17)
	paste(swo, sw, 1, 1)
	_outline(swo, "ink")
	decal("icon_swords", swo, "drawn: crossed swords")
	# the merchant: the HD set's frames are already the pack's 16 x 28 dwarf, kept as they are
	for i in range(4):
		raw("npc_idle_f%d" % i, img(HD + "npc_idle_f%d.png" % i), "0x72 dwarf_m idle (as in the HD set)")
