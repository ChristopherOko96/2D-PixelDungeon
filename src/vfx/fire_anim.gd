extends RefCounted
## Fires and fountains that move, in every story world and graphics set (src/hell/hell_game.gd):
## a few pictures per sprite are made from the loaded sprite itself when the set loads, so no
## extra art is needed and a rebuilt set moves too.
## - Fire: only the flame's pixels change (found by colour: bright and coloured, or a near-white
##   core beside them; stone, wood and snow are grey, so they stay still): bands of light rise
##   through the flame and the pixels of its top edge fade in and out, so it burns and licks a
##   little all the time.
## - Water: only the fountain's water pixels change (blue and coloured): bands of light run down
##   through them, with a few glints, so the water flows down the whole time.
## Each instance runs at its own point of the loop (from its position), so fires never flicker in
## step. Values from assets/data/vfx_fire_anim.json. Presentation only.

const DATA_PATH := "res://assets/data/vfx_fire_anim.json"

## The data file's values (frames, fps, fire {...}, water {...}).
var cfg: Dictionary = {}
## Sprite name -> its pictures (Array of Texture2D), fps.
var _frames: Dictionary = {}
var _fps: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	cfg = data
	if cfg.is_empty() and FileAccess.file_exists(DATA_PATH):
		cfg = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


## Makes the pictures for every fire and fountain sprite of `tex` (name -> Texture2D). `block` =
## the set's pixel size (3 for a pixel set), so the light's bands keep its grid.
func build(tex: Dictionary, block := 1) -> void:
	_frames = {}
	_fps = {}
	var n := int(cfg.get("frames", 8))
	for kind: String in ["fire", "water"]:
		var spec: Dictionary = cfg.get(kind, {})
		for name: Variant in spec.get("names", []):
			var t: Texture2D = tex.get(str(name))
			if t == null:
				continue
			var image := t.get_image()
			if image == null:
				continue
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			var pics := fire_frames(image, spec, n, maxi(1, block)) if kind == "fire" else water_frames(image, spec, n, maxi(1, block))
			if pics.is_empty():
				continue
			var textures: Array = []
			for pic: Image in pics:
				textures.append(ImageTexture.create_from_image(pic))
			_frames[str(name)] = textures
			_fps[str(name)] = float(spec.get("fps", cfg.get("fps", 9)))


## True when `name` moves.
func has(name: String) -> bool:
	return _frames.has(name)


## The picture of `name` for an instance at `at` (world px) at time `t` (s); null when it does not move.
func frame(name: String, at: Vector2, t: float) -> Texture2D:
	var pics: Array = _frames.get(name, [])
	if pics.is_empty():
		return null
	var start := absf(sin(at.x * 12.9898 + at.y * 78.233) * 43758.5453)
	return pics[int(t * float(_fps[name]) + start) % pics.size()]


static func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


static func _hash(x: int, y: int, k: int) -> float:
	var h := (x * 374761393 + y * 668265263 + k * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## The flame pixels of `image`: bright and coloured, plus near-white cores inside them.
static func flame_mask(image: Image, spec: Dictionary) -> PackedByteArray:
	var w := image.get_width()
	var h := image.get_height()
	var mask := PackedByteArray()
	mask.resize(w * h)
	var lum := float(spec.get("lum", 0.45))
	var sat := float(spec.get("sat", 0.4))
	for y in range(h):
		for x in range(w):
			var c := image.get_pixel(x, y)
			if c.a > 0.3 and _lum(c) >= lum and c.s >= sat:
				mask[y * w + x] = 1
	var core := float(spec.get("core_lum", 0.82))
	var cores: Array = []
	for y in range(h):
		for x in range(w):
			if mask[y * w + x] == 1:
				continue
			var c := image.get_pixel(x, y)
			if c.a <= 0.3 or _lum(c) < core:
				continue
			# a core lies inside the flame (flame on two sides at least); snow on a bowl's rim
			# touches the flame on one side only and stays still
			var flame_sides := 0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and mask[ny * w + nx] == 1:
					flame_sides += 1
			if flame_sides >= 2:
				cores.append(y * w + x)
	for i: int in cores:
		mask[i] = 1
	return mask


## `n` pictures of a burning sprite (see the header); [] when it has no flame.
static func fire_frames(image: Image, spec: Dictionary, n: int, block := 1) -> Array:
	var w := image.get_width()
	var h := image.get_height()
	var mask := flame_mask(image, spec)
	if mask.count(1) < 4:
		return []
	var band := float(spec.get("band", 0.22))
	var k_y := float(spec.get("band_k", 0.3))
	var tip := float(spec.get("tip", 0.45))
	var rows := int(spec.get("tip_rows", 4)) * block
	# the flame's top edge: flame pixels with open air within `rows` px above them
	var edge := PackedByteArray()
	edge.resize(w * h)
	for y in range(h):
		for x in range(w):
			if mask[y * w + x] != 1:
				continue
			for r in range(1, rows + 1):
				var yy := y - r
				if yy < 0 or (image.get_pixel(x, yy).a < 0.1):
					edge[y * w + x] = 1
					break
				if mask[yy * w + x] != 1:
					break
	var out: Array = []
	for k in range(n):
		var phase := TAU * k / float(n)
		var pic := image.duplicate() as Image
		for y in range(h):
			for x in range(w):
				var i := y * w + x
				if mask[i] != 1:
					continue
				var bx := x / block
				var by := y / block
				var c := image.get_pixel(x, y)
				# bands of light rising through the flame, a little uneven across it
				var f := 1.0 + band * sin(float(by * block) * k_y + phase + _hash(bx, 0, 3) * 1.5)
				c = Color(minf(1.0, c.r * f), minf(1.0, c.g * f), minf(1.0, c.b * f), c.a)
				# the top edge licks: some of its pixels fade out, in changing places
				if edge[i] == 1 and _hash(bx, by, k) < tip:
					c.a *= 0.15 + 0.5 * _hash(bx, by, k + 31)
				pic.set_pixel(x, y, c)
		out.append(pic)
	return out


## The water pixels of `image`: blue over red and coloured.
static func water_mask(image: Image, spec: Dictionary) -> PackedByteArray:
	var w := image.get_width()
	var h := image.get_height()
	var mask := PackedByteArray()
	mask.resize(w * h)
	var over := float(spec.get("blue_over", 45)) / 255.0
	var low := float(spec.get("blue_min", 130)) / 255.0
	var sat := float(spec.get("sat", 0.35))
	for y in range(h):
		for x in range(w):
			var c := image.get_pixel(x, y)
			if c.a > 0.3 and c.b >= low and c.b - c.r >= over and c.s >= sat:
				mask[y * w + x] = 1
	return mask


## `n` pictures of a fountain whose water flows down (see the header); [] when it has none.
static func water_frames(image: Image, spec: Dictionary, n: int, block := 1) -> Array:
	var w := image.get_width()
	var h := image.get_height()
	var mask := water_mask(image, spec)
	if mask.count(1) < 4:
		return []
	var band := float(spec.get("band", 0.3))
	var k_y := float(spec.get("band_k", 0.22))
	var sparkle := float(spec.get("sparkle", 0.04))
	var out: Array = []
	for k in range(n):
		var phase := TAU * k / float(n)
		var pic := image.duplicate() as Image
		for y in range(h):
			for x in range(w):
				if mask[y * w + x] != 1:
					continue
				var bx := x / block
				var by := y / block
				var c := image.get_pixel(x, y)
				# bands of light running down: the band at height y moves down as the phase grows
				var f := 1.0 + band * sin(float(by * block) * k_y - phase + _hash(bx, 1, 7) * 0.8)
				c = Color(minf(1.0, c.r * f), minf(1.0, c.g * f), minf(1.0, c.b * f), c.a)
				if _hash(bx, by - k * 2, 11) < sparkle:
					c = c.lerp(Color(1, 1, 1, c.a), 0.6)
				pic.set_pixel(x, y, c)
		out.append(pic)
	return out
