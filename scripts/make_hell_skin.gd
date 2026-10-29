extends SceneTree
## Builds the Hell-Dungeon sprite skin in the 0x72 pixel style
## (assets/sprites/hell_0x72/): every name the hell core and runtime draw
## (assets/sprites/hell/manifest.json) at one pixel density, 16 px tiles x3.
##
## The hell look stays: its colours are a fixed hell palette sampled from the
## first hell art (violet-grey stone, glowing red cracks, lava, dark red wood,
## reddish bones). The style is 0x72's: 16 px grid, 1 px dark outline, light
## from the top left, flat shading in few steps, no soft edges.
## - Pieces 0x72 has (floor, walls, column, skull, chests, flames, torches,
##   arches, stairs, spikes, hole) are cut from DungeonTileset II and its
##   extended set and every pixel is remapped onto the hell palette.
## - Hell pieces 0x72 lacks (lava, spires, rocks, chains, cages, braziers,
##   banners with sigils, seal, skull heap, altar, runes, portcullis, bridges,
##   grates, portal, lintel) are drawn here pixel by pixel in that style.
##
## Usage (repo root):
##   godot --headless --path . -s res://scripts/make_hell_skin.gd -- "<...>/Sprite Sheet 0x72" [out_dir]
## Writes <name>.png and manifest.json; LICENSE-NOTE.md is kept by hand.

const K := 3
const OLD_MANIFEST := "res://assets/sprites/hell/manifest.json"

## Hell palette. Ramps run dark -> light. Sampled from assets/sprites/hell.
const HEX := {
	"ink": "120a12", "gap": "1c1320", "s1": "2b1f30", "s2": "38293d", "s3": "4c3a4f", "s4": "5e4a60", "s5": "7f6880", "pale": "c9b2bf",
	"f0": "1e1626", "f1": "35283a", "f2": "4a3a4e",
	"r0": "2a0f16", "r1": "4a1620", "r2": "6e1a24", "r3": "a8201a",
	"l0": "c4220f", "l1": "ee3311", "l2": "ff5a14", "l3": "ffa030", "l4": "ffe080",
	"b0": "3a2026", "b1": "5a3a3e", "b2": "86605e", "b3": "b08c84", "b4": "d8c0b0",
	"o0": "2e1420", "o1": "44202c", "o2": "62303a", "o3": "7e4448", "o4": "9a5a58",
	"i0": "33222c", "i1": "523a44", "i2": "7a5a62", "i3": "a08088",
	"w0": "2a0c14", "w1": "4a1620", "w2": "6a2228", "w3": "8e3a30",
	"g1": "b07a2a", "g2": "e8b84a", "g3": "fff0a0",
	"k1": "6a5a5a", "k2": "b8a8a0", "k3": "f0e4dc",
}

## 0x72 colour -> hell role, per material. Unlisted colours fall back by brightness.
const STONE := {"222222": "gap", "111111": "ink", "0e0c0c": "ink", "140c11": "ink", "1d1218": "ink", "21141b": "ink", "23151d": "gap",
	"2b2929": "s1", "302c2b": "s1", "333333": "s1", "2a2a3a": "s1", "38262d": "r0", "3b3332": "s2", "483b3a": "s2", "775c55": "s3", "aa8d7a": "s4",
	"d3bfa9": "s5", "fdf7ed": "pale"}
const FLOOR := {"222222": "f0", "483b3a": "f1", "775c55": "f2"}
const FIRE := {"da4e38": "l1", "ee8e2e": "l2", "facb3e": "l3", "fccba3": "l4", "fdf7ed": "l4", "8f4029": "r3", "c56025": "l0", "62232f": "r2", "f78697": "l2"}
const WOOD := {"8f4029": "w2", "62232f": "w1", "ee8e2e": "w3", "c56025": "w3", "222222": "ink", "111111": "ink", "facb3e": "g2", "fccba3": "g3",
	"fdf7ed": "g3", "72d6ce": "i3", "3c9f9c": "i2", "da4e38": "w3", "ffad3b": "g2", "97da3f": "l1"}
const BONE := {"d3bfa9": "b3", "aa8d7a": "b2", "fdf7ed": "b4", "222222": "b0", "775c55": "b1"}
const BANNER := {"da4e38": "r3", "9f294e": "r2", "dc4a7b": "l0", "b6cbcf": "i3", "38262d": "r0", "222222": "ink"}
const BUTTON := {"da4e38": "r3", "5f2d56": "r1", "9f294e": "r2", "222222": "ink"}
const DEMON := {"da4e38": "r3", "9f294e": "r2", "62232f": "r1", "f78697": "l1", "fdf7ed": "l4", "222222": "ink", "38262d": "r0", "facb3e": "l3",
	"ee8e2e": "l2", "8f4029": "r1", "dc4a7b": "l0"}
const METAL := {"fdf7ed": "k3", "3c9f9c": "i2", "72d6ce": "i3", "b6cbcf": "k2", "55a894": "i2"}

## Hand-drawn pieces in the 0x72 manner (one character per pixel).
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
## Glowing floor cracks laid over plain 0x72 floor tiles: c dim edge, h core, y hottest.
const CRACKS := [
	["................", "...c............", "....c...........", "....hc..........", ".....h......c...", ".....hh....c....", "......yhhhhc....",
		"......h.........", ".....h.c........", "....c...c.......", "...c.....c......", "..........c.....", "................", "................",
		"................", "................"],
	["................", "................", "..........c.....", ".........c......", "..c.....hc......", "...cc..h........", ".....hyh........",
		"......h.........", "......hh........", ".......hc.......", ".......c.cc.....", "......c.....c...", "................", "................",
		"................", "................"],
	["................", "................", "................", "................", ".c..........c...", "..c........c....", "...hh....hh.....",
		".....hyyh.......", ".......h........", "......c.c.......", ".....c...c......", "....c.....c.....", "................", "................",
		"................", "................"],
]

var src := ""
var out_dir := "res://assets/sprites/hell_0x72/"
var manifest := {}
var old: Dictionary = {}
var unknown := {}
var _ext: Image
var _c := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -- <Sprite Sheet 0x72 folder> [out_dir]")
		quit(1)
		return
	src = args[0]
	if args.size() > 1:
		out_dir = args[1]
	for k: String in HEX:
		_c[k] = Color.html(HEX[k])
	old = JSON.parse_string(FileAccess.get_file_as_string(OLD_MANIFEST))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_build()
	var missing: Array = []
	for n: String in old:
		if not manifest.has(n):
			missing.append(n)
	var f := FileAccess.open(out_dir.path_join("manifest.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, " ", true))
	f.close()
	print("HELL_SKIN %d sprites -> %s missing=%s unmapped=%s" % [manifest.size(), out_dir, missing, unknown.keys()])
	quit(0 if missing.is_empty() else 1)


# ---------------------------------------------------------------- pixel tools

func col(role: String) -> Color:
	return _c[role]


func blank(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func frame(name: String) -> Image:
	var im := Image.load_from_file(src.path_join("0x72_DungeonTilesetII_v1.7/frames/" + name + ".png"))
	im.convert(Image.FORMAT_RGBA8)
	return im


func ext(x: int, y: int, w: int, h: int) -> Image:
	if _ext == null:
		_ext = Image.load_from_file(src.path_join("dungeontiles-extended v1.1/dungeontileset-extended.png"))
		_ext.convert(Image.FORMAT_RGBA8)
	return _ext.get_region(Rect2i(x, y, w, h))


func crop(im: Image, x: int, y: int, w: int, h: int) -> Image:
	return im.get_region(Rect2i(x, y, w, h))


func trim(im: Image) -> Image:
	var r := im.get_used_rect()
	return im.get_region(r) if r.size.x > 0 else im


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


func _lum(c: Color) -> float:
	return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b


## Every pixel onto the hell palette: the first map that knows the colour wins.
func recolor(im: Image, maps: Array) -> Image:
	var o := im.duplicate() as Image
	var ramp := ["ink", "gap", "s1", "s2", "s3", "s4", "s5", "pale"]
	for y in range(o.get_height()):
		for x in range(o.get_width()):
			var c := o.get_pixel(x, y)
			if c.a < 0.5:
				o.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var h := c.to_html(false)
			var role := ""
			for m: Dictionary in maps:
				if m.has(h):
					role = m[h]
					break
			if role.is_empty():
				unknown[h] = true
				role = ramp[clampi(int(_lum(c) * 9.0), 0, ramp.size() - 1)]
			o.set_pixel(x, y, col(role))
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


## Columns shaded by position across each row: left light, right shade (pillars, spires).
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


## A stalagmite mask: base width w, height h, tip leaning by `lean` pixels.
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


func circle_px(im: Image, cx: float, cy: float, r: float, role: String, every := 1, offset := 0) -> void:
	var steps := int(TAU * r * 2.0)
	var seen := {}
	var i := 0
	for s in range(steps):
		var a := TAU * s / steps
		var p := Vector2i(roundi(cx + cos(a) * r), roundi(cy + sin(a) * r))
		if seen.has(p):
			continue
		seen[p] = true
		if (i + offset) % every == 0 and p.x >= 0 and p.y >= 0 and p.x < im.get_width() and p.y < im.get_height():
			im.set_pixelv(p, col(role))
		i += 1


func put(name: String, im: Image, note: String) -> void:
	im.save_png(ProjectSettings.globalize_path(out_dir.path_join(name + ".png")))
	var kind: String = (old.get(name, {}) as Dictionary).get("kind", "sprite")
	manifest[name] = {"w": im.get_width(), "h": im.get_height(), "kind": kind, "src": note}


## A K-scaled image on a canvas of exactly w x h (art anchored bottom-centre unless told).
func on_canvas(im: Image, w: int, h: int, ax := 0.5, ay := 1.0) -> Image:
	var o := blank(w, h)
	paste(o, im, int(round((w - im.get_width()) * ax)), int(round((h - im.get_height()) * ay)))
	return o


# ---------------------------------------------------------------- shared parts

func flame(i: int) -> Image:
	return trim(recolor(ext(128 + 16 * (i % 8), 336, 16, 16), [FIRE, STONE]))


## A big hell flame drawn like the 0x72 flames (red rim, orange body, yellow-white core), 11 x 16.
func big_flame() -> Image:
	return grid([
		".....o.....",
		"....oo.....",
		"....oyo..o.",
		"...oyyo.oo.",
		"...oyyyooo.",
		"..oyyhyyyo.",
		".ooyhhhyyo.",
		".oyyhwhhyoo",
		"oyyhhwwhyyo",
		"oyhhwwwwhyo",
		"oyhwwwwwhyo",
		"oyhhwwwhhyo",
		"royhhhhhyor",
		".royyyyyor.",
		"..rooooor..",
		"...rrrrr...",
	], {"o": "l1", "y": "l2", "h": "l3", "w": "l4", "r": "r3"})


func torch(i: int) -> Image:
	return trim(recolor(ext(128 + 16 * (i % 8), 352, 16, 24), [FIRE, METAL, STONE]))


## A skull drawn 0x72-style (the pack's own skull is a 7 px floor crumb, too small for hell piles).
func skull() -> Image:
	return grid(SKULL, {"k": "b0", "h": "b4", "b": "b3", "s": "b2", "e": "ink", "t": "b4"})


## The same skull with ember eyes.
func hot_skull() -> Image:
	return grid(SKULL, {"k": "b0", "h": "b4", "b": "b3", "s": "b2", "e": "r3", "t": "b4"})


func bone(kind: int) -> Image:
	var shapes := [
		[".kk.....kk.", "khbkkkkkhbk", ".khhhhhhhk.", "kbskkkkkbsk", ".kk.....kk."],
		[".kk.....", "khhk....", "khbbk...", ".kbbbk..", "..kbbbk.", "...kbbsk", "....ksbk", ".....kk."],
		[".....kk.", "....khhk", "...kbbhk", "..kbbbk.", ".kbbbk..", "kbsbk...", "kbsk....", ".kk....."],
		[".kk.", "khbk", "kbsk", ".kk.", ".kh.", ".kb.", ".kb.", ".kh.", ".kk.", "khbk", "kbsk", ".kk."],
	]
	var m: Array = shapes[kind % shapes.size()]
	return grid(m, {"k": "b0", "h": "b4", "b": "b3", "s": "b2"})


func iron_link_v(n: int) -> Image:
	var rows: Array = []
	for i in range(n):
		rows.append_array([".kkk.", "kh.mk", "kh.sk", ".kkk.", "..h..", "..m.."])
	return grid(rows, {"k": "ink", "h": "k2", "s": "i1", "m": "i2"})


func bowl(w: int) -> Image:
	var rows: Array = []
	rows.append("k" + "h".repeat(w - 2) + "k")
	rows.append("k" + "l".repeat(w - 2) + "k")
	rows.append(".k" + "m".repeat(w - 4) + "k.")
	rows.append("..k" + "s".repeat(w - 6) + "k..")
	rows.append("...k" + "k".repeat(w - 8) + "k...")
	return grid(rows, {"k": "ink", "h": "r3", "l": "s4", "m": "s3", "s": "s2"})


## A glowing rune glyph (5 x 5) in lava colours.
func glyph(i: int) -> Image:
	var g := [
		[".h.h.", ".hhh.", "..h..", "..h..", ".hhh."],
		["h...h", ".h.h.", "..h..", ".h.h.", "h...h"],
		["..h..", ".h.h.", "h.h.h", ".h.h.", "..h.."],
		["hhhhh", "h...h", "..h..", "h...h", "hhhhh"],
	]
	return grid(g[i % g.size()], {"h": "l2"})


func plain_floor(i: int) -> Image:
	return recolor(frame("floor_%d" % (1 + i % 8)), [FLOOR])


func tile2(a: Image, b: Image, c: Image, d: Image) -> Image:
	var o := blank(32, 32)
	paste(o, a, 0, 0)
	paste(o, b, 16, 0)
	paste(o, c, 0, 16)
	paste(o, d, 16, 16)
	return o


## A plain floor tile with one of the drawn glowing cracks over it.
func hot_tile(i: int, crack: int) -> Image:
	var t := plain_floor(i)
	paste(t, grid(CRACKS[crack % CRACKS.size()], {"c": "r2", "h": "r3", "y": "l1"}), 0, 0)
	return t


# ---------------------------------------------------------------- build

func _build() -> void:
	_floors()
	_lava()
	_walls()
	_wall_decor()
	_pillars_and_braziers()
	_rocks_and_spires()
	_bones()
	_chains_and_cages()
	_decals()
	_gates_and_portals()
	_loot_and_icons()


func _floors() -> void:
	var cracks := []
	for p: Vector2i in [Vector2i(16, 64), Vector2i(32, 64), Vector2i(48, 64), Vector2i(16, 80), Vector2i(32, 80), Vector2i(48, 80), Vector2i(16, 96), Vector2i(32, 96)]:
		cracks.append(recolor(ext(p.x, p.y, 16, 16), [FLOOR, STONE]))
	for i in range(12):
		var a: Image = plain_floor(i)
		var b: Image = plain_floor(i + 3)
		var c: Image = plain_floor(i + 5)
		var d: Image = plain_floor(i + 6)
		if i in [2, 3, 7, 8, 9]:
			# hot slabs: drawn glowing cracks over 0x72 tiles, like the old hell floor
			a = hot_tile(i, i)
			d = hot_tile(i + 6, i + 1)
			put("floor_%02d" % i, up(tile2(a, b, c, d)), "0x72 floor_1..8, hell palette, drawn glowing cracks")
			continue
		if i >= 10:
			a = cracks[i - 10]
			d = cracks[i - 4]
		put("floor_%02d" % i, up(tile2(a, b, c, d)), "0x72 floor_1..8 (+ extended cracks), hell palette")


func _lava_tile(seed_value: int) -> Image:
	# tileable 32 x 32 lava: sums of waves whose periods divide 32, cut into ramp bands
	var im := blank(32, 32)
	var ph := seed_value * 1.7
	var bands := ["r2", "r3", "l0", "l1", "l2", "l3", "l4"]
	for y in range(32):
		for x in range(32):
			var u := TAU * x / 32.0
			var v := TAU * y / 32.0
			var f := sin(u + 2.0 * v + ph) + 0.7 * sin(2.0 * u - v + ph * 0.5) + 0.45 * sin(3.0 * u + v - ph) + 0.35 * sin(u - 3.0 * v + 1.3)
			# mostly red-orange melt, dark crust in the troughs, few hot yellow crests
			var i := 0
			if f < -1.45: i = 0
			elif f < -0.95: i = 1
			elif f < -0.15: i = 2
			elif f < 0.85: i = 3
			elif f < 1.5: i = 4
			elif f < 1.95: i = 5
			else: i = 6
			im.set_pixel(x, y, col(bands[i]))
	# drop lone pixels (0x72 never dithers)
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
	# crust islands get a dark rim below them, like 0x72 shadows
	var p := o.duplicate() as Image
	for y in range(32):
		for x in range(32):
			if o.get_pixel(x, y).is_equal_approx(col("r2")) and not o.get_pixel(x, posmod(y + 1, 32)).is_equal_approx(col("r2")):
				p.set_pixel(x, posmod(y + 1, 32), col("r1"))
	return p


func _lava() -> void:
	put("lava_00", up(_lava_tile(0)), "drawn: tileable 32 px lava in the hell lava ramp")
	put("lava_01", up(_lava_tile(3)), "drawn: tileable 32 px lava in the hell lava ramp")
	# rim where floor drops into lava: brick lip on the floor side, glowing crust into the lava
	var rim := blank(32, 32)
	var rows := {5: "s4", 6: "s3", 7: "s2", 8: "s2", 9: "s1", 10: "r2", 11: "r3"}
	for y: int in rows:
		for x in range(32):
			var role: String = rows[y]
			if (y == 7 or y == 8) and (x + (0 if y == 7 else 4)) % 8 == 0:
				role = "gap"
			if y == 11 and (x * 5) % 7 < 3:
				continue
			rim.set_pixel(x, y, col(role))
	for x in range(32):
		rim.set_pixel(x, 4, col("gap"))
	put("lava_edge_top", up(rim), "drawn: 0x72-style brick lip with glowing crust")


func _walls() -> void:
	var cap := crop(recolor(frame("wall_top_mid"), [STONE]), 0, 7, 16, 9)
	var face := recolor(frame("wall_mid"), [STONE])
	# hell touch: the lowest mortar line glows faintly
	for x in range(16):
		if face.get_pixel(x, 15).is_equal_approx(col("gap")) and x % 3 != 1:
			face.set_pixel(x, 15, col("r1"))
	var wall := blank(64, 25)
	for i in range(4):
		paste(wall, cap, i * 16, 0)
		paste(wall, face, i * 16, 9)
	put("wall_h", crop(up(wall), 0, 0, 192, 74), "0x72 wall_top_mid + wall_mid, hell palette, glowing base mortar")
	# side wall seen from above: dark wall top, lit 0x72 edge strip towards the room (right)
	var edge := recolor(frame("wall_edge_mid_right"), [STONE])
	var side := blank(21, 16)
	side.fill(col("gap"))
	paste(side, crop(edge, 11, 0, 5, 16), 16, 0)
	put("wall_v", crop(up(side), 1, 0, 62, 48), "0x72 wall_edge_mid_right strip on a dark wall top, hell palette")
	# wall islands inside rooms: the flat dark 0x72 wall top (hell_game fills them with it)
	var top := blank(32, 32)
	top.fill(col("gap"))
	put("wall_top", up(top), "0x72 wall top (flat), hell palette")
	# glowing slit in a side wall, 2 tiles high
	var glow := blank(21, 32)
	glow.fill(col("gap"))
	paste(glow, crop(edge, 11, 0, 5, 16), 16, 0)
	paste(glow, crop(edge, 11, 0, 5, 16), 16, 16)
	var slit := grid([".kkkkk.", "kssssk.", "ks...sk", "ks.h.sk", "ks.h.sk", "ks.y.sk", "ks.y.sk", "ks.y.sk", "ks.y.sk", "ks.y.sk", "ks.h.sk", "ks.h.sk",
		"ks...sk", "ksssssk", ".kkkkk."], {"k": "ink", "s": "s3", "h": "l1", "y": "l3"})
	var pit := grid(["..l..", ".lll.", ".lll.", ".lll.", ".lll.", ".lll.", ".lll.", ".lll.", ".lll.", ".lll.", ".lll.", "..l.."], {"l": "r3"})
	paste(glow, pit, 6, 9)
	paste(glow, slit, 5, 8)
	put("wall_v_glow", crop(up(glow), 1, 0, 62, 96), "drawn: lava slit in a 0x72 side wall")
	var glow_b := blank(21, 32)
	glow_b.fill(col("gap"))
	paste(glow_b, crop(edge, 11, 0, 5, 16), 16, 0)
	paste(glow_b, crop(edge, 11, 0, 5, 16), 16, 16)
	var plate := shade(mask_rows(["xxxxxxx", "xxxxxxx", "xxxxxxx", "xxxxxxx", "xxxxxxx", "xxxxxxx", "xxxxxxx"]), ["ink", "s2", "s3", "s4", "s5"])
	paste(glow_b, plate, 4, 11)
	paste(glow_b, glyph(2), 6, 13)
	put("wall_v_glow_b", crop(up(glow_b), 1, 0, 62, 96), "drawn: rune plate in a 0x72 side wall")
	# corner cap: a capstone like the top of the 0x72 column (lit bevel, sunk centre) with the hell's red stud
	var cap_rows: Array = []
	for y in range(23):
		cap_rows.append("x".repeat(23))
	var c := shade(mask_rows(cap_rows), ["ink", "s1", "s2", "s3", "s4"])
	for i in range(5, 20):
		for p: Vector2i in [Vector2i(i, 5), Vector2i(5, i)]:
			c.set_pixelv(p, col("s1"))
		for p: Vector2i in [Vector2i(i, 19), Vector2i(19, i)]:
			c.set_pixelv(p, col("s3"))
	var stud := grid(["..k..", ".kmk.", "kmymk", ".kmk.", "..k.."], {"k": "ink", "m": "r2", "y": "r3"})
	paste(c, stud, 10, 10)
	put("corner_cap", on_canvas(up(c), 76, 76, 0.5, 0.5), "drawn: 0x72-style capstone with red stud")
	# posts in the north wall: 0x72 column_wall with a glowing slit
	var col_wall := recolor(frame("column_wall"), [STONE])
	var post := crop(col_wall, 0, 0, 16, 32)
	for y in range(13, 27):
		post.set_pixel(7, y, col("l2" if y > 14 and y < 25 else "r3"))
		post.set_pixel(8, y, col("r3" if y > 14 and y < 25 else "r2"))
	put("wall_h_glowpost", up(post), "0x72 column_wall, hell palette, glowing slit")
	put("wall_post_slit", up(crop(col_wall, 0, 0, 16, 32)), "0x72 column_wall, hell palette")


func _banner(sigil: int, tall: bool, dark: bool) -> Image:
	# 0x72 banner shape (rod, cloth, notched tail) at hell sizes, with a sigil
	var rows := [
		"p.kkkkkkkkkk.p",
		"pkhrrrrrrrrskp",
		".khrrrrrrrrsk.",
		".khrrrrrrrrsk.",
		".khrrrrrrrrsk.",
		".khrrrrrrrrsk.",
		".khrrrrrrrrsk.",
		".khrrrrrrrrsk.",
		".khrrrrrrrrsk.",
	]
	if tall:
		rows.append_array([".khrrrrrrrrsk.", ".khrrrrrrrrsk.", ".khrrrrrrrrsk.", ".khrrrrrrrrsk."])
	rows.append_array([".khrrrrrrrrsk.", ".khrrrsskrrsk.", ".khrrsk.ksrsk.", ".khrsk...ksrk.", ".kksk.....kkk.", ".kk.........k."])
	var legend := {"p": "i2", "k": "ink", "h": "l0" if not dark else "r1", "r": "r3" if not dark else "r0", "s": "r2" if not dark else "ink"}
	var im := grid(rows, legend)
	var sig: Array = [
		[],
		["..g..g..", "..g..g..", "..gggg..", "...gg...", "...gg...", "..gggg.."],
		["..gggg..", ".gggggg.", ".g.gg.g.", ".gggggg.", "..g..g..", "..gggg.."],
		["...gg...", "..g..g..", ".g.gg.g.", "..g..g..", "...gg..."],
	][sigil % 4]
	if not sig.is_empty():
		paste(im, grid(sig, {"g": "l3" if not dark else "l1"}), 3, 3 + (2 if tall else 0))
	return im


func _wall_decor() -> void:
	# wall decor hangs from the wall's top edge + 6 px; 7 rows of air put it on the brick face
	var pad := func(im: Image) -> Image:
		var o := blank(im.get_width(), im.get_height() + 7)
		paste(o, im, 0, 7)
		return up(o)
	put("banner_1", pad.call(_banner(0, false, false)), "drawn: 0x72-style banner, hell red")
	put("banner_2", pad.call(_banner(1, false, false)), "drawn: 0x72-style banner with trident sigil")
	put("banner_3", pad.call(_banner(2, false, false)), "drawn: 0x72-style banner with skull sigil")
	put("banner_4", pad.call(_banner(3, false, true)), "drawn: 0x72-style black banner, red rune")
	put("banner_5", pad.call(_banner(1, false, true)), "drawn: 0x72-style black banner, red trident")
	put("banner_a", pad.call(_banner(1, true, false)), "drawn: long 0x72-style banner")
	put("banner_b", pad.call(_banner(2, true, true)), "drawn: long black 0x72-style banner")
	var bc := blank(30, 30)
	paste(bc, iron_link_v(1).get_region(Rect2i(0, 0, 5, 6)), 0, 0)
	paste(bc, iron_link_v(1).get_region(Rect2i(0, 0, 5, 6)), 25, 0)
	paste(bc, _banner(1, false, false), 8, 4)
	put("banner_chain", pad.call(bc), "drawn: 0x72-style banner on chain hooks")
	# torches: extended 0x72 torch in a sconce, hell fire
	for i in range(3):
		put("torch_%s" % ["a", "b", "c"][i], pad.call(torch(i * 3)), "extended 0x72 torch, hell fire")
	put("wall_torch_hook", pad.call(torch(1)), "extended 0x72 torch, hell fire")
	var block := shade(mask_rows(["xxxxxxxxxx", "xxxxxxxxxx", "xxxxxxxxxx", "xxxxxxxxxx", "xxxxxxxxxx", "xxxxxxxxxx"]), ["ink", "s2", "s3", "s4", "s5"])
	var tb := blank(12, 24)
	paste(tb, torch(5), 3, 0)
	paste(tb, block, 0, 16)
	put("wall_torch_block", pad.call(trim(tb)), "extended 0x72 torch on a drawn stone block")
	# wall brazier: bracket + bowl + flame
	var wb := blank(14, 22)
	paste(wb, flame(2), 2, 0)
	paste(wb, bowl(12), 1, 12)
	paste(wb, grid(["..kk..", "..kk..", ".kmmk.", "kmmmmk"], {"k": "ink", "m": "i1"}), 4, 17)
	put("wall_brazier", pad.call(trim(wb)), "drawn: wall fire bowl, extended 0x72 flame")
	# hanging fire basket on a chain
	var hb := blank(14, 34)
	paste(hb, iron_link_v(2), 4, 0)
	paste(hb, flame(4), 2, 9)
	paste(hb, grid(["k.k.k.k.k.k.", "kmkmkmkmkmkk", ".kmmmmmmmmk.", "..kkkkkkkk.."], {"k": "ink", "m": "i2"}), 1, 21)
	put("hanging_brazier", pad.call(trim(hb)), "drawn: hanging fire basket, extended 0x72 flame")
	# wall skulls: a skull in a wall niche (0x72 wall_hole)
	for i in range(2):
		var n := recolor(frame("wall_hole_%d" % (i + 1)), [STONE])
		paste(n, hot_skull(), 4, 5 + i)
		put("wall_skull_%s" % ["a", "b"][i], up(n), "0x72 wall_hole + skull, hell palette")


func _pillars_and_braziers() -> void:
	var column := trim(recolor(frame("column"), [STONE]))
	for i in range(4):
		var p := column.duplicate() as Image
		paste(p, glyph(i), 5, 16 + (i % 2) * 3)
		put("rune_pillar_%s" % ["a", "b", "c", "d"][i], up(p), "0x72 column, hell palette, glowing rune")
	var ob := shade_cols(mask_rows([
		".....xx.....", "....xxxx....", "....xxxx....", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...",
		"...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "...xxxxxx...", "..xxxxxxxx..", "..xxxxxxxx..",
		"..xxxxxxxx..", "..xxxxxxxx..", "..xxxxxxxx..", "..xxxxxxxx..", "..xxxxxxxx..", "..xxxxxxxx..", ".xxxxxxxxxx.", ".xxxxxxxxxx.",
		"xxxxxxxxxxxx", "xxxxxxxxxxxx", "xxxxxxxxxxxx"]), ["ink", "o0", "o1", "o2", "o3"])
	paste(ob, glyph(0), 4, 8)
	paste(ob, glyph(2), 4, 16)
	put("obelisk", up(ob), "drawn: 0x72-style obsidian obelisk with runes")
	var so := column.duplicate() as Image
	var sk := hot_skull()
	var so2 := blank(so.get_width(), so.get_height() + 8)
	paste(so2, so, 0, 8)
	paste(so2, sk, (so.get_width() - sk.get_width()) / 2, 0)
	put("skull_obelisk", up(so2), "0x72 column + 0x72 skull, hell palette")
	# the entity brazier: flame in rows 0-15 (above px 46), bowl and foot below (unlit draws only below the cut)
	var bb := blank(16, 28)
	paste(bb, big_flame(), 2, 0)
	paste(bb, bowl(14), 1, 15)
	paste(bb, shade_cols(mask_rows(["xxxx", "xxxx", "xxxx", "xxxx", "xxxx", "xxxx"]), ["ink", "s1", "s2", "s3", "s4"]), 5, 19)
	paste(bb, shade(mask_rows(["xxxxxxxxxx", "xxxxxxxxxx"]), ["ink", "s1", "s2", "s3", "s4"]), 2, 25)
	put("brazier_bowl", up(trim(bb)), "drawn: fire bowl on a foot, drawn 0x72-style hell flame")
	var tall := func(top: Image, h: int, rune: int) -> Image:
		var o := blank(16, h)
		paste(o, top, (16 - top.get_width()) / 2, 0)
		var shaft_rows: Array = []
		for y in range(h - top.get_height() - 3):
			shaft_rows.append("xxxxxx")
		var shaft := shade_cols(mask_rows(shaft_rows), ["ink", "s1", "s2", "s3", "s4"])
		paste(o, shaft, 4, top.get_height() - 1)
		paste(o, shade(mask_rows(["xxxxxxxxxxxx", "xxxxxxxxxxxx"]), ["ink", "s1", "s2", "s3", "s4"]), 1, h - 4)
		if rune >= 0:
			paste(o, glyph(rune), 5, top.get_height() + 4)
		return trim(o)
	var head := func(fi: int, w: int) -> Image:
		var o := blank(16, 22)
		var f := big_flame() if fi < 0 else flame(fi)
		paste(o, f, (16 - f.get_width()) / 2, 16 - f.get_height())
		paste(o, bowl(w), (16 - w) / 2, 15)
		return trim(o)
	put("brazier_pillar", up(tall.call(head.call(-1, 14), 46, -1)), "drawn: fire bowl on a pillar, drawn 0x72-style hell flame")
	put("brazier_rune", up(tall.call(head.call(-1, 12), 40, 1)), "drawn: fire bowl on a rune pillar, drawn 0x72-style hell flame")
	# demon brazier: horned bowl with glowing eyes
	var db := blank(18, 28)
	var f2 := big_flame()
	paste(db, f2, (18 - f2.get_width()) / 2, 0)
	var demon := grid([
		"k................k",
		"hk..............kh",
		"hhk............khh",
		".hhkkkkkkkkkkkkhh.",
		"..kllllllllllllk..",
		"..kmmyymmmmyymmk..",
		"..kmmyymmmmyymmk..",
		"...kmmmmmmmmmmk...",
		"...kmmkkkkkkmmk...",
		"....kmkwkwkkmk....",
		".....kmmmmmmk.....",
		"......kkkkkk......"], {"k": "ink", "h": "b3", "l": "s4", "m": "s2", "y": "l2", "w": "b4"})
	paste(db, demon, 0, 11)
	paste(db, shade(mask_rows(["xxxxxxxxxx", "xxxxxxxxxx"]), ["ink", "s1", "s2", "s3", "s4"]), 3, 22)
	put("brazier_demon", up(trim(db)), "drawn: horned demon fire bowl, extended 0x72 flame")
	# low fire bowls on the floor
	var low := func(fi: int, w: int, coals: bool) -> Image:
		var o := blank(16, 22)
		var f := big_flame() if fi < 0 else flame(fi)
		paste(o, f, (16 - f.get_width()) / 2, maxi(0, 14 - f.get_height()))
		paste(o, bowl(w), (16 - w) / 2, 13)
		if coals:
			paste(o, grid(["c.y.c.y", ".c.c.c."], {"c": "r2", "y": "l2"}), (16 - 7) / 2, 12)
		return trim(o)
	put("brazier_floor", up(low.call(-1, 14, false)), "drawn: floor fire bowl, drawn 0x72-style hell flame")
	put("brazier_low", up(low.call(0, 12, false)), "drawn: low fire bowl, extended 0x72 flame")
	put("brazier_low_b", up(low.call(-1, 12, true)), "drawn: low fire bowl with coals, drawn 0x72-style hell flame")


func _rocks_and_spires() -> void:
	var obs := ["ink", "o0", "o1", "o2", "o3"]
	var spire := func(w: int, h: int, lean: int, s: int) -> Image:
		var im := shade_cols(spire_mask(w, h, lean, s), obs)
		# strata: a few short shade lines across the rock
		for y in range(4, im.get_height() - 2, 5):
			for x in range(im.get_width()):
				if opaque(im, x, y) and not im.get_pixel(x, y).is_equal_approx(col("ink")) and (x + y + s) % 3 == 0:
					im.set_pixel(x, y, col("o1"))
		return im
	var group := func(parts: Array) -> Image:
		var w := 0
		var h := 0
		for p: Array in parts:
			var im: Image = p[0]
			w = maxi(w, p[1] + im.get_width())
			h = maxi(h, p[2] + im.get_height())
		var o := blank(w, h)
		parts.sort_custom(func(a: Array, b: Array) -> bool: return a[2] + a[0].get_height() < b[2] + b[0].get_height())
		for p: Array in parts:
			paste(o, p[0], p[1], p[2])
		return o
	var big: Image = spire.call(14, 32, 1, 1)
	put("spire_big", up(big), "drawn: 0x72-style obsidian spire")
	put("spire_big_b", up(spire.call(12, 28, -1, 4)), "drawn: 0x72-style obsidian spire")
	put("spire_big_t", up(group.call([[big, 6, 0], [spire.call(8, 16, 1, 2), 0, 17], [spire.call(7, 12, -1, 3), 15, 21]])), "drawn: 0x72-style spire group")
	put("spire_mid", up(spire.call(10, 22, 1, 5)), "drawn: 0x72-style obsidian spire")
	put("spire_small", up(spire.call(8, 15, -1, 6)), "drawn: 0x72-style obsidian spire")
	put("spire_tiny", up(spire.call(6, 10, 1, 7)), "drawn: 0x72-style obsidian spire")
	put("spire_t", up(group.call([[spire.call(9, 20, 1, 8), 0, 0], [spire.call(7, 13, -1, 9), 7, 8]])), "drawn: 0x72-style spire pair")
	put("spires_t", up(group.call([[spire.call(7, 14, 1, 2), 0, 2], [spire.call(8, 17, 0, 3), 5, 0], [spire.call(6, 10, -1, 4), 11, 7]])), "drawn: 0x72-style spire cluster")
	var sl: Image = group.call([[spire.call(9, 20, 1, 3), 0, 0], [spire.call(7, 13, -1, 5), 8, 8]])
	var glow_base := sl.duplicate() as Image
	for y in range(sl.get_height() - 4, sl.get_height()):
		for x in range(sl.get_width()):
			if opaque(sl, x, y) and not sl.get_pixel(x, y).is_equal_approx(col("ink")):
				glow_base.set_pixel(x, y, col("r3" if y < sl.get_height() - 2 else "l1"))
	put("spires_lava", up(glow_base), "drawn: 0x72-style spires glowing at the base")
	var stone := ["ink", "s1", "s2", "s3", "s4"]
	var rock := func(w: int, h: int, b: int, ramp: Array) -> Image:
		return shade(ellipse_mask(w, h, b), ramp)
	put("rocks_a", up(group.call([[rock.call(9, 7, 1, stone), 0, 3], [rock.call(7, 6, 2, stone), 8, 0], [rock.call(5, 4, 3, stone), 12, 7]])), "drawn: 0x72-style rocks")
	put("rocks_b", up(group.call([[rock.call(8, 6, 2, stone), 0, 1], [rock.call(6, 5, 1, stone), 7, 3]])), "drawn: 0x72-style rocks")
	put("rocks_dark", up(group.call([[rock.call(8, 7, 3, ["ink", "gap", "s1", "s2", "s3"]), 0, 2], [rock.call(6, 5, 1, ["ink", "gap", "s1", "s2", "s3"]), 6, 0]])), "drawn: 0x72-style dark rocks")
	var rl: Image = group.call([[rock.call(9, 7, 1, obs), 0, 2], [rock.call(7, 6, 2, obs), 7, 0]])
	for p: Vector2i in [Vector2i(3, 5), Vector2i(4, 6), Vector2i(5, 6), Vector2i(10, 3), Vector2i(10, 4), Vector2i(11, 5)]:
		if opaque(rl, p.x, p.y):
			rl.set_pixelv(p, col("l2"))
	put("rocks_lava", up(rl), "drawn: 0x72-style rocks with glowing cracks")
	put("boulders", up(group.call([[rock.call(12, 9, 2, stone), 0, 2], [rock.call(9, 8, 3, stone), 10, 0]])), "drawn: 0x72-style boulders")
	put("rubble", up(group.call([[rock.call(5, 3, 1, stone), 0, 4], [rock.call(4, 3, 2, stone), 5, 1], [rock.call(6, 4, 3, stone), 9, 4], [rock.call(3, 2, 1, stone), 15, 2], [rock.call(4, 3, 2, stone), 3, 8]])), "drawn: 0x72-style rubble")
	var coal: Image = group.call([[rock.call(7, 5, 1, ["ink", "ink", "gap", "s1", "s2"]), 0, 2], [rock.call(6, 5, 2, ["ink", "ink", "gap", "s1", "s2"]), 5, 0], [rock.call(5, 4, 3, ["ink", "ink", "gap", "s1", "s2"]), 10, 3]])
	for p: Vector2i in [Vector2i(3, 4), Vector2i(7, 2), Vector2i(8, 3), Vector2i(12, 5), Vector2i(5, 6)]:
		if opaque(coal, p.x, p.y):
			coal.set_pixelv(p, col("l1" if p.x % 2 == 0 else "r3"))
	put("coal", up(coal), "drawn: 0x72-style coal with embers")
	var cs := coal.duplicate() as Image
	var big_cs := blank(cs.get_width() + 2, cs.get_height() + 7)
	paste(big_cs, cs, 0, 7)
	paste(big_cs, hot_skull(), 4, 0)
	put("coal_skulls", up(trim(big_cs)), "drawn coal + 0x72 skull, hell palette")


func _bones() -> void:
	var s := skull()
	var hs := hot_skull()
	var pile := func(spots: Array) -> Image:
		var o := blank(40, 30)
		for p: Vector2i in spots:
			paste(o, s if (p.x + p.y) % 3 else hs, p.x, p.y)
		return trim(o)
	put("skull_pile", up(pile.call([Vector2i(0, 6), Vector2i(7, 6), Vector2i(14, 6), Vector2i(3, 1), Vector2i(10, 1)])), "0x72 skull pile, hell palette")
	put("skull_pile_t", up(pile.call([Vector2i(0, 5), Vector2i(7, 5), Vector2i(4, 0)])), "0x72 skull pile, hell palette")
	var heap := blank(40, 30)
	for p: Vector2i in [Vector2i(0, 16), Vector2i(7, 17), Vector2i(14, 17), Vector2i(21, 17), Vector2i(28, 16), Vector2i(4, 11), Vector2i(11, 11),
			Vector2i(18, 11), Vector2i(25, 11), Vector2i(8, 6), Vector2i(15, 5), Vector2i(22, 6), Vector2i(12, 0), Vector2i(19, 1)]:
		paste(heap, hs if (p.x * 3 + p.y) % 4 == 0 else s, p.x, p.y)
	paste(heap, bone(0), 26, 21)
	paste(heap, bone(1), 0, 20)
	put("skull_heap", up(trim(heap)), "0x72 skulls heaped high (secret wall marker), hell palette")
	for i in range(7):
		put("bone_%s" % ["a", "b", "c", "d", "e", "f", "g"][i], up(bone(i)), "drawn: 0x72-style bone")
	var bs := blank(24, 16)
	paste(bs, bone(0), 0, 6)
	paste(bs, bone(1), 12, 0)
	paste(bs, bone(3), 9, 2)
	put("bones_scatter", up(trim(bs)), "drawn: 0x72-style bones")
	var bt := blank(20, 14)
	paste(bt, bone(2), 0, 0)
	paste(bt, s, 8, 4)
	put("bones_t", up(trim(bt)), "drawn bones + 0x72 skull")
	# a demon face set into the floor
	put("demon_head", up(grid([
		"k............k",
		"hk..........kh",
		"hhkkkkkkkkkkhh",
		".kmmmmmmmmmmk.",
		".kmyymmmmyymk.",
		".kmmmmmmmmmmk.",
		"..kmmkkkkmmk..",
		"..kmkwkwkkmk..",
		"...kmmmmmmk...",
		"....kkkkkk...."], {"k": "ink", "h": "b2", "m": "o1", "y": "l2", "w": "b3"})), "drawn: 0x72-style demon face in the floor")


func _chains_and_cages() -> void:
	put("chain_a", up(iron_link_v(5)), "drawn: 0x72-style iron chain")
	put("chain_b", up(iron_link_v(4)), "drawn: 0x72-style iron chain")
	put("chain_long", up(iron_link_v(6)), "drawn: 0x72-style iron chain")
	put("chain_long_b", up(iron_link_v(5)), "drawn: 0x72-style iron chain")
	put("chain_hang", up(iron_link_v(5)), "drawn: 0x72-style iron chain")
	var hook := iron_link_v(5)
	var hk := blank(7, hook.get_height() + 3)
	paste(hk, hook, 1, 0)
	paste(hk, grid(["k.....k", "kk...kk", ".kmmmk."], {"k": "i0", "m": "i2"}), 0, hook.get_height())
	put("chain_hook", up(hk), "drawn: 0x72-style chain with hook")
	# a sagging chain between two wall rings
	var swag := func(w: int, sag: float) -> Image:
		var o := blank(w, int(sag) + 6)
		for x in range(w):
			var t := float(x) / float(w - 1)
			var y := int(round(2 + sag * 4.0 * t * (1.0 - t)))
			o.set_pixel(x, y, col("i3" if x % 3 == 0 else "i2"))
			o.set_pixel(x, y + 1, col("i1"))
		for e: int in [0, w - 3]:
			paste(o, grid([".k.", "kmk", ".k."], {"k": "i0", "m": "i3"}), e, 0)
		_outline(o, "i0")
		return trim(o)
	put("chain_swag", up(swag.call(24, 9.0)), "drawn: 0x72-style sagging chain")
	put("chain_swag_b", up(swag.call(18, 7.0)), "drawn: 0x72-style sagging chain")
	var cuff := grid([".kkkk.", "kmssmk", "km..mk", "kmssmk", ".kkkk."], {"k": "i0", "m": "i2", "s": "i3"})
	for i in range(2):
		var o := blank(6, 30)
		paste(o, iron_link_v(3 + i), 0, 0)
		paste(o, cuff, 0, 18 + 6 * i)
		put("shackle_%s" % ["a", "b"][i], up(trim(o)), "drawn: 0x72-style shackle on a chain")
	var ss := blank(10, 34)
	paste(ss, iron_link_v(3), 2, 0)
	paste(ss, cuff, 2, 18)
	paste(ss, hot_skull(), 1, 22)
	put("shackle_skull", up(trim(ss)), "drawn shackle + 0x72 skull")
	var cage := func(w: int, h: int, with_skull: bool) -> Image:
		var o := blank(w, h)
		for y in range(h):
			for x in range(w):
				var edge_y := y == 0 or y == 1 or y == h - 1 or y == h - 2
				var bar := x % 3 == 0 or x == w - 1
				if edge_y:
					o.set_pixel(x, y, col("i2" if y % 2 == 0 else "i1"))
				elif bar:
					o.set_pixel(x, y, col("i3" if x < w / 2 else "i1"))
		if with_skull:
			var sk := hot_skull()
			var inside := blank(w, h)
			paste(inside, sk, (w - sk.get_width()) / 2, h - 2 - sk.get_height())
			paste(inside, o, 0, 0)
			o = inside
		var framed := blank(w + 2, h + 2)
		paste(framed, o, 1, 1)
		_outline(framed, "i0")
		return framed
	var hang := blank(14, 34)
	paste(hang, iron_link_v(2), 5, 0)
	paste(hang, cage.call(12, 20, true), 0, 12)
	put("cage_hang", up(trim(hang)), "drawn: 0x72-style hanging cage with 0x72 skull")
	put("cage_small", up(cage.call(12, 18, true)), "drawn: 0x72-style standing cage with 0x72 skull")


func _rune_circle(r: float, size: int) -> Image:
	var im := blank(size, size)
	var c := (size - 1) / 2.0
	circle_px(im, c, c, r, "r2")
	circle_px(im, c, c, r - 2.0, "r3")
	circle_px(im, c, c, r - 5.0, "r2")
	# six glowing marks between the rings, a rune in the middle
	for i in range(6):
		var a := -PI / 2.0 + TAU * i / 6.0
		for d: float in [r - 1.0, r - 3.5]:
			var p := Vector2(c, c) + Vector2(cos(a), sin(a)) * d
			im.set_pixel(roundi(p.x), roundi(p.y), col("l2" if d > r - 2.0 else "r3"))
	var g := glyph(2)
	paste(im, g, int(c) - 2, int(c) - 2)
	return im


func _decals() -> void:
	put("rune_big", up(_rune_circle(14.5, 32)), "drawn: 0x72-style rune circle")
	put("rune_small", up(_rune_circle(10.5, 24)), "drawn: 0x72-style rune circle")
	var plate := blank(22, 22)
	var frame_img := shade(mask_rows(["xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx",
		"xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx",
		"xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx",
		"xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxx"]), ["ink", "s1", "s2", "s3", "s4"])
	paste(plate, frame_img, 0, 0)
	var button := trim(recolor(frame("button_red_up"), [BUTTON]))
	paste(plate, button, (22 - button.get_width()) / 2, (22 - button.get_height()) / 2)
	paste(plate, glyph(2), 9 - 1, 8)
	put("rune_plate", up(plate), "0x72 button_red_up in a drawn stone plate, hell palette")
	var fp := plate.duplicate() as Image
	var grill := grid(["kkkkkkkkkkkk", "kyklkykl kyk", "kkkkkkkkkkkk", "klkykl kykl k", "kkkkkkkkkkkk", "kykl kykl kyk", "kkkkkkkkkkkk"], {"k": "ink", "y": "l2", "l": "r3"})
	paste(fp, grill, 5, 7)
	put("fire_plate", up(fp), "drawn: 0x72-style fire grate plate")
	# pit: 0x72 hole widened to one cell by repeating its middle rows and columns
	var hole := recolor(frame("hole"), [STONE])
	var pit := blank(32, 32)
	for y in range(32):
		var sy := y if y < 6 else (15 - (31 - y) if y > 25 else 8)
		for x in range(32):
			var sx := x if x < 6 else (15 - (31 - x) if x > 25 else 8)
			pit.set_pixel(x, y, hole.get_pixel(sx, sy))
	put("pit", up(pit), "0x72 hole, widened to a cell, hell palette")
	var grate := func(w: int, h: int, hot: bool) -> Image:
		var rows: Array = []
		for y in range(h):
			var r := ""
			for x in range(w):
				if x == 0 or y == 0 or x == w - 1 or y == h - 1:
					r += "f"
				elif x % 3 == 0:
					r += "b"
				else:
					r += "g" if not hot else ("y" if (x + y) % 4 == 0 else "g")
			rows.append(r)
		var im := grid(rows, {"f": "s3", "b": "s2", "g": "ink" if not hot else "r2", "y": "r3"})
		var o := blank(w + 2, h + 2)
		paste(o, im, 1, 1)
		_outline(o, "ink")
		return o
	put("grate", up(grate.call(19, 19, false)), "drawn: 0x72-style floor grate")
	put("grate_a", up(grate.call(13, 13, false)), "drawn: 0x72-style floor grate")
	put("grate_b", up(grate.call(16, 13, true)), "drawn: 0x72-style glowing grate")
	put("vent", up(grate.call(13, 13, true)), "drawn: 0x72-style vent with embers")
	# bridges: dark planks between iron-bound rails; tiled along their length in game
	var planks := func(across: int, along: int, rails_on_x: bool) -> Image:
		var w := across if rails_on_x else along
		var h := along if rails_on_x else across
		var o := blank(w, h)
		for y in range(h):
			for x in range(w):
				var a := x if rails_on_x else y
				var b := y if rails_on_x else x
				var role := "w2"
				if a < 4 or a >= across - 4:
					role = ["i0", "i2", "i1", "i0"][mini(a, across - 1 - a)]
				elif b % 8 == 7:
					role = "w0"
				elif b % 8 == 6:
					role = "w1"
				elif b % 8 == 0:
					role = "w3"
				elif (a + b * 5) % 11 == 0:
					role = "w1"
				o.set_pixel(x, y, col(role))
		return o
	put("bridge_h", up(planks.call(71, 16, true)), "drawn: 0x72-style plank bridge (vertical run)")
	put("bridge_v", up(planks.call(71, 16, false)), "drawn: 0x72-style plank bridge (horizontal run)")


func _arch(inside: Image) -> Image:
	# extended 0x72 arch (open doorway), hell palette, with something inside
	var arch := recolor(ext(192, 224, 32, 32), [STONE, METAL, WOOD])
	var o := blank(32, 32)
	paste(o, inside, 4, 8)
	paste(o, arch, 0, 0)
	return o


func _gates_and_portals() -> void:
	# stairs down into the dark, drawn like 0x72 floor_stairs: lit nosing, tread, dark riser
	var steps := blank(24, 24)
	steps.fill(col("ink"))
	var ramps := [["s5", "s4", "s2"], ["s4", "s3", "s1"], ["s3", "s2", "gap"], ["s2", "s1", "gap"], ["s1", "gap", "ink"], ["gap", "ink", "ink"]]
	for i in range(6):
		var y0 := 24 - 3 - i * 3
		var inset := i
		for row in range(3):
			for x in range(inset, 24 - inset):
				steps.set_pixel(x, y0 + row, col(ramps[i][row]))
	put("door_stairs", up(_arch(steps)), "extended 0x72 arch + drawn 0x72-style stairs, hell palette")
	put("door_stairs_small", up(crop(_arch(steps), 4, 4, 24, 28)), "extended 0x72 arch + drawn 0x72-style stairs, hell palette")
	put("icon_door", up(crop(_arch(steps), 4, 4, 24, 28)), "extended 0x72 arch + drawn 0x72-style stairs, hell palette")
	# spike traps: 0x72 floor_spikes without the floor under them, steel in hell iron
	var spikes := func(f: int) -> Image:
		var s := frame("floor_spikes_anim_f%d" % f)
		var o := blank(32, 16)
		for k in range(2):
			for y in range(16):
				for x in range(16):
					var h := s.get_pixel(x, y).to_html(false)
					if s.get_pixel(x, y).a > 0.5 and h != "483b3a" and h != "775c55":
						o.set_pixel(x + 16 * k, y, col({"222222": "ink", "fdf7ed": "k3", "3c9f9c": "i2"}.get(h, "i1")))
		return trim(o)
	put("spike_trap", up(spikes.call(3)), "0x72 floor_spikes_anim_f3, hell iron")
	put("spike_trap_b", up(spikes.call(2)), "0x72 floor_spikes_anim_f2, hell iron")
	var sb := shade(mask_rows(["xxxxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxxxx",
		"xxxxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxxxx"]), ["ink", "s1", "s2", "s3", "s4"])
	var block := blank(24, 22)
	paste(block, sb, 0, 12)
	paste(block, spikes.call(3), 0, 4)
	put("spike_block", up(trim(block)), "0x72 floor_spikes on a drawn stone block, hell palette")
	# portal: swirl of hell fire in the arch; dark when closed
	var swirl := func(lit: bool) -> Image:
		var o := blank(24, 24)
		o.fill(col("ink"))
		var c := Vector2(11.5, 13.5)
		for y in range(24):
			for x in range(24):
				var d := Vector2(x, y) - c
				var a := atan2(d.y, d.x)
				var r := d.length()
				var band := sin(r * 0.9 - a * 2.0)
				var role := "ink"
				if lit:
					role = "l3" if r < 2.5 else ("l2" if band > 0.6 else ("l0" if band > 0.0 else ("r2" if band > -0.6 else "r1")))
				else:
					role = "r1" if band > 0.55 else ("r0" if band > -0.2 else "ink")
				o.set_pixel(x, y, col(role))
		return o
	put("portal", up(_arch(swirl.call(true))), "extended 0x72 arch with a drawn fire swirl")
	put("portal_dark", up(_arch(swirl.call(false))), "extended 0x72 arch with a dark swirl")
	# portcullis: iron bars with spikes, 2 cells wide
	var pc := blank(64, 32)
	for y in range(32):
		for x in range(64):
			var role := ""
			if y < 3:
				role = ["i0", "i2", "i1"][y]
			elif y == 12 or y == 22:
				role = "i2"
			elif y == 13 or y == 23:
				role = "i0"
			elif x % 6 == 2:
				role = "i3"
			elif x % 6 == 3:
				role = "i1"
			elif x % 6 == 1 or x % 6 == 4:
				role = "i0" if y > 2 else ""
			if y >= 29 and x % 6 in [1, 4]:
				role = ""
			if y == 31 and x % 6 == 3:
				role = ""
			if not role.is_empty():
				pc.set_pixel(x, y, col(role))
	put("portcullis", up(pc), "drawn: 0x72-style iron portcullis")
	put("gate_side", up(crop(pc, 0, 0, 32, 32)), "drawn: 0x72-style iron portcullis (half)")
	put("jamb_a", up(recolor(frame("doors_frame_left"), [STONE, METAL])), "0x72 doors_frame_left, hell palette")
	put("jamb_b", up(recolor(frame("doors_frame_right"), [STONE, METAL])), "0x72 doors_frame_right, hell palette")
	# demon lintel over the boss gate: wall cap row with a horned skull and two red studs
	var lin := blank(64, 24)
	var cap := crop(recolor(frame("wall_top_mid"), [STONE]), 0, 7, 16, 9)
	for i in range(4):
		paste(lin, cap, i * 16, 9)
	var horned := grid([
		"kh..................hk",
		"khh................hhk",
		".khhh.............hhk.",
		"..khhkkkkkkkkkkkkhhk..",
		"...kllllllllllllllk...",
		"..kllmmmmmmmmmmmmllk..",
		"..klmyyymmmmmmyyymlk..",
		"..klmyyymmmmmmyyymlk..",
		"..klmmmmmmkkmmmmmmlk..",
		"...klmmmmkkkkmmmmlk...",
		"....kmkwkwkkwkwkmk....",
		".....kmmmmmmmmmmk.....",
		"......kkkkkkkkkk......"], {"k": "ink", "h": "b3", "l": "s4", "m": "s2", "y": "l2", "w": "b4"})
	paste(lin, horned, 21, 4)
	var stud := grid(["..k..", ".kmk.", "kmymk", ".kmk.", "..k.."], {"k": "ink", "m": "r3", "y": "l2"})
	paste(lin, stud, 6, 11)
	paste(lin, stud, 53, 11)
	put("demon_lintel", up(lin), "0x72 wall cap + drawn horned demon skull")


func _loot_and_icons() -> void:
	put("chest_closed", up(trim(recolor(frame("chest_full_open_anim_f0"), [WOOD]))), "0x72 chest, hell wood")
	put("chest_open", up(trim(recolor(frame("chest_full_open_anim_f2"), [WOOD]))), "0x72 chest (open, full), hell wood")
	put("chest_gold", up(trim(recolor(frame("chest_full_open_anim_f2"), [WOOD]))), "0x72 chest (open, full), hell wood")
	put("chest_empty", up(trim(recolor(frame("chest_empty_open_anim_f2"), [WOOD]))), "0x72 chest (open, empty), hell wood")
	put("icon_chest", up(trim(recolor(frame("chest_full_open_anim_f0"), [WOOD]))), "0x72 chest, hell wood")
	# heart drawn x0.7 in game: 4x keeps it near 3 px per pixel
	var heart := trim(recolor(frame("ui_heart_full"), [{"da4e38": "l1", "9f294e": "r3", "f78697": "l3", "fdf7ed": "k3", "222222": "ink", "2a2a3a": "ink", "62232f": "r2"}]))
	put("heart", up(heart, 4), "0x72 ui_heart_full, hell red")
	# key: the Glut key shows its own gold, the others tint it (theme keys), drawn x0.9 -> 3x
	var key := trim(recolor(ext(320, 320, 16, 16), [{"facb3e": "g2", "ee8e2e": "g1", "c56025": "g1", "8f4029": "w2", "222222": "ink", "fdf7ed": "g3"}]))
	put("key", up(key, 3), "extended 0x72 key, hell gold")
	# runestone drawn x0.55 -> 5x
	var gem := grid(["..k..", ".kyk.", "kyhrk", "khrrk", "krrsk", ".ksk.", "..k.."], {"k": "ink", "y": "l4", "h": "l2", "r": "r3", "s": "r2"})
	put("rune_gem", up(gem, 5), "drawn: 0x72-style red runestone")
	put("fire_orb", up(flame(2)), "extended 0x72 flame, hell fire")
	var sign := trim(recolor(ext(320, 384, 16, 16), [WOOD, {"aa8d7a": "b2", "d3bfa9": "b3", "775c55": "b1"}]))
	put("icon_scroll", up(sign, 4), "extended 0x72 sign, hell wood")
	var sword := trim(recolor(frame("weapon_regular_sword"), [METAL, STONE, {"8f4029": "w2", "62232f": "w1", "facb3e": "g2", "ee8e2e": "g1"}]))
	var two := blank(sword.get_width() * 2 + 2, sword.get_height())
	paste(two, sword, 0, 0)
	paste(two, flip_x(sword), sword.get_width() + 2, 0)
	put("icon_swords", up(two), "0x72 weapon_regular_sword x2, hell steel")
	var dh := trim(crop(recolor(frame("big_demon_idle_anim_f0"), [DEMON, STONE]), 0, 0, 32, 22))
	put("icon_demon", up(dh), "0x72 big_demon head, hell palette")
	put("icon_demon_big", up(dh, 4), "0x72 big_demon head, hell palette")
	# altar: stone table, red cloth, candles, a skull
	var alt := blank(40, 28)
	var cloth := grid([
		"kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk",
		"khhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhk",
		"kllllllllllllllllllllllllllllllllllk",
		"kmmmmmmmmkrrrrrrrrrrrrrrrrkmmmmmmmmk",
		"kmmmmmmmmkrrrrrrgrrgrrrrrrkmmmmmmmmk",
		"kmmmmmmmmkrrrrrrggggrrrrrrkmmmmmmmmk",
		"kmmmmmmmmkrrrrrrrggrrrrrrrkmmmmmmmmk",
		"kmmmmmmmmkrrrrrrrggrrrrrrrkmmmmmmmmk",
		"ksssssssskrrrrrrggggrrrrrrkssssssssk",
		"ksssssssskrrrrrrrrrrrrrrrrkssssssssk",
		"ksssssssskrsrsrsrsrsrsrsrskssssssssk",
		"kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk"], {"k": "ink", "h": "s5", "l": "s4", "m": "s3", "s": "s2", "r": "r3", "g": "l3"})
	paste(alt, cloth, 2, 15)
	var candle := trim(recolor(ext(128, 400, 16, 24), [FIRE, STONE, BONE]))
	paste(alt, candle, 3, 15 - candle.get_height() + 2)
	paste(alt, candle, 31, 15 - candle.get_height() + 2)
	var sk := hot_skull()
	paste(alt, sk, 20 - sk.get_width() / 2, 15 - sk.get_height() + 1)
	put("altar", up(trim(alt)), "drawn altar + extended 0x72 candles + 0x72 skull, hell palette")
	# demon seal: a stone stele with a horned face and a glowing ring (as large as the old seal)
	var stele_rows: Array = []
	for y in range(27):
		var inset: int = [5, 3, 2, 1, 1][y] if y < 5 else 0
		stele_rows.append(".".repeat(inset) + "x".repeat(27 - inset * 2) + ".".repeat(inset))
	var stele := shade(mask_rows(stele_rows), ["ink", "s1", "s2", "s3", "s4"])
	var ring := blank(23, 23)
	circle_px(ring, 11.0, 11.0, 10.5, "r3")
	circle_px(ring, 11.0, 11.0, 10.5, "l2", 4)
	circle_px(ring, 11.0, 11.0, 8.5, "r2")
	paste(stele, ring, 3, 3)
	var face := grid([
		"k........k",
		"hk......kh",
		".hkkkkkkh.",
		".kmmmmmmk.",
		".kyymmyyk.",
		".kmmmmmmk.",
		"..kmkkmk..",
		"..kwkwkk..",
		"...kkkk..."], {"k": "ink", "h": "b3", "m": "o2", "y": "l2", "w": "b4"})
	paste(stele, face, 10, 10)
	put("demon_plate", up(stele), "drawn: 0x72-style demon seal stele")
