extends RefCounted
## Fires and fountains that move, in every story world and graphics set (src/hell/hell_game.gd):
## a few pictures per sprite are made from the loaded sprite itself when the set loads, so no
## extra art is needed and a rebuilt set moves too.
## - Fire: only the flame's pixels change (found by colour: bright and coloured, or a near-white
##   core beside them; stone, wood and snow are grey, so they stay still). The flame's shape
##   moves: it curls sideways, most at the tip, and grows and shrinks from its still base, in
##   whole pixels of the set (user, 2026-11-01: "züngeln"). Then bands of light rise through the
##   flame and the pixels of its top edge fade in and out, so it burns and licks all the time.
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
## First each flame's shape moves (flame_regions, _move_flames: it curls sideways and grows and
## shrinks from its still base, in whole art pixels of the sprite's own grid), then the light runs
## through the flame as it is in that picture.
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
	var grid := art_grid(image, block)
	var regions := flame_regions(mask, w, h, spec, block, image)
	# which pixels are not open air (alpha 0.1 and up), kept up to date as the flame moves
	var solid_drawn := PackedByteArray()
	solid_drawn.resize(w * h)
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a >= 0.1:
				solid_drawn[y * w + x] = 1
	var out: Array = []
	for k in range(n):
		var phase := TAU * k / float(n)
		var pic := image.duplicate() as Image
		# `live`: the flame pixels of this picture (the shape has moved); `solid` its non-air pixels
		var live := mask.duplicate()
		var solid := solid_drawn.duplicate()
		_move_flames(image, pic, live, solid, regions, spec, phase, block, grid)
		for y in range(h):
			for x in range(w):
				var i := y * w + x
				if live[i] != 1:
					continue
				# the light's cells lie on the sprite's own art grid
				var bx := (x - grid.x + block) / block
				var by := (y - grid.y + block) / block
				var c := pic.get_pixel(x, y)
				# bands of light rising through the flame, a little uneven across it
				var f := 1.0 + band * sin(float(by * block) * k_y + phase + _hash(bx, 0, 3) * 1.5)
				c = Color(minf(1.0, c.r * f), minf(1.0, c.g * f), minf(1.0, c.b * f), c.a)
				# the top edge licks: some of its pixels fade out, in changing places
				if _hash(bx, by, k) < tip and _top_edge(solid, live, x, y, w, rows):
					c.a *= 0.15 + 0.5 * _hash(bx, by, k + 31)
				pic.set_pixel(x, y, c)
		out.append(pic)
	return out


## True when flame pixel (x, y) of a picture has open air within `rows` px above it (its top
## edge); `solid` marks the picture's non-air pixels, `live` its flame pixels.
static func _top_edge(solid: PackedByteArray, live: PackedByteArray, x: int, y: int, w: int, rows: int) -> bool:
	for r in range(1, rows + 1):
		var yy := y - r
		if yy < 0 or solid[yy * w + x] == 0:
			return true
		if live[yy * w + x] != 1:
			return false
	return false


## Where the art pixel grid of `image` starts, (ox, oy) in 0..block-1: a pixel set's sprite is
## made of block x block cells and its colour changes fall on their borders, which need not start
## at the corner. (0, 0) for block 1. Cell of pixel (x, y): ((x - ox + block) / block, (y - oy + block) / block).
## [codeblock]
## var grid := FireAnim.art_grid(image, 3)
## [/codeblock]
static func art_grid(image: Image, block: int) -> Vector2i:
	if image == null or block <= 1:
		return Vector2i.ZERO
	var w := image.get_width()
	var h := image.get_height()
	var cols := PackedInt32Array()
	cols.resize(block)
	var rows := PackedInt32Array()
	rows.resize(block)
	for y in range(h):
		for x in range(w):
			var c := image.get_pixel(x, y)
			if x + 1 < w and not c.is_equal_approx(image.get_pixel(x + 1, y)):
				cols[(x + 1) % block] += 1
			if y + 1 < h and not c.is_equal_approx(image.get_pixel(x, y + 1)):
				rows[(y + 1) % block] += 1
	var ox := 0
	var oy := 0
	for r in range(block):
		if cols[r] > cols[ox]:
			ox = r
		if rows[r] > rows[oy]:
			oy = r
	return Vector2i(ox, oy)


## The flames of a sprite whose shape moves, from its flame `mask` (w x h) and the sprite `image`,
## on its art grid (art_grid; `block` px per art px):
## - flame-mask pixels within `gap` art px of each other form a group;
## - a flame is a group of at least min_pixels art px and flame_share of the largest group, whose top
##   lies in the upper top_share of the sprite's drawn part and within near_share of the largest
##   group's height below that group's top (a glowing rune or eyes lower down only get the light),
##   and that is not slim (narrower than slim_share of its height, like a candle with its wax);
## - with `image` it grows over its whole painted body: connected pixels of its own hue (within
##   body_hue) at least body_sat saturated and body_val bright, and faint anti-aliased edge pixels,
##   down to its lowest mask row; plus pale cores (core_lum) enclosed by it on their row; then
##   whole art cells; small groups just above it within spark_reach of its height are its sparks;
##   no pixel goes to two flames;
## - its still base is its lowest static_share of art rows (at least one).
## Each flame: {moving (PackedByteArray w*h, 1 = moves), list (PackedInt32Array of those pixels),
## open (PackedByteArray w*h, 1 = may become air: close enough to the air for the sway to uncover it;
## anywhere else the painted pixel stays under the moved flame, so no hole opens inside the sprite),
## pivot (its last moving px row), pivot_c, top_c (art rows), x0, x1 (px), sway (art px), seed}.
## [codeblock]
## var regions := FireAnim.flame_regions(FireAnim.flame_mask(image, spec), w, h, spec, 3, image)
## [/codeblock]
static func flame_regions(mask: PackedByteArray, w: int, h: int, spec: Dictionary, block := 1, image: Image = null) -> Array:
	var grid := art_grid(image, block)
	var ox := grid.x
	var oy := grid.y
	var cw := (w - 1 - ox + block) / block + 1
	var ch := (h - 1 - oy + block) / block + 1
	# 1. group the mask on the art grid: cells within `gap` cells join
	var gap := maxi(1, int(spec.get("gap", 2)))
	var cells := PackedByteArray()
	cells.resize(cw * ch)
	for i in range(w * h):
		if mask[i] == 1:
			cells[((i / w) - oy + block) / block * cw + ((i % w) - ox + block) / block] = 1
	var cell_group := PackedInt32Array()
	cell_group.resize(cw * ch)
	cell_group.fill(-1)
	var count := 0
	for start in range(cw * ch):
		if cells[start] != 1 or cell_group[start] >= 0:
			continue
		var todo := PackedInt32Array([start])
		cell_group[start] = count
		while not todo.is_empty():
			var c := todo[todo.size() - 1]
			todo.remove_at(todo.size() - 1)
			var cx := c % cw
			var cy := c / cw
			for dy in range(-gap, gap + 1):
				var ny := cy + dy
				if ny < 0 or ny >= ch:
					continue
				for dx in range(-gap, gap + 1):
					var nx := cx + dx
					if nx < 0 or nx >= cw:
						continue
					var j := ny * cw + nx
					if cells[j] == 1 and cell_group[j] < 0:
						cell_group[j] = count
						todo.append(j)
		count += 1
	if count == 0:
		return []
	# each group's pixels, bounds (px) and mean hue, in two passes over the picture
	var sizes := PackedInt32Array()
	sizes.resize(count)
	var tops := PackedInt32Array()
	tops.resize(count)
	tops.fill(h)
	var bottoms := PackedInt32Array()
	bottoms.resize(count)
	bottoms.fill(-1)
	var lefts := PackedInt32Array()
	lefts.resize(count)
	lefts.fill(w)
	var rights := PackedInt32Array()
	rights.resize(count)
	rights.fill(-1)
	var hue_x := PackedFloat32Array()
	hue_x.resize(count)
	var hue_y := PackedFloat32Array()
	hue_y.resize(count)
	var gid := PackedInt32Array()
	gid.resize(w * h)
	gid.fill(-1)
	for i in range(w * h):
		if mask[i] != 1:
			continue
		var k := cell_group[((i / w) - oy + block) / block * cw + ((i % w) - ox + block) / block]
		gid[i] = k
		sizes[k] += 1
		tops[k] = mini(tops[k], i / w)
		bottoms[k] = maxi(bottoms[k], i / w)
		lefts[k] = mini(lefts[k], i % w)
		rights[k] = maxi(rights[k], i % w)
		if image != null:
			var c := image.get_pixel(i % w, i / w)
			hue_x[k] += cos(c.h * TAU) * c.s
			hue_y[k] += sin(c.h * TAU) * c.s
	var starts := PackedInt32Array()
	starts.resize(count)
	var total := 0
	for k in range(count):
		starts[k] = total
		total += sizes[k]
	var order := PackedInt32Array()
	order.resize(total)
	var fill := starts.duplicate()
	for i in range(w * h):
		if gid[i] >= 0:
			order[fill[gid[i]]] = i
			fill[gid[i]] += 1
	var groups: Array = []
	for k in range(count):
		groups.append({"top": tops[k], "bottom": bottoms[k], "x0": lefts[k], "x1": rights[k], "pixels": order.slice(starts[k], starts[k] + sizes[k]),
			"hue": fposmod(atan2(hue_y[k], hue_x[k]) / TAU, 1.0), "flame": false})
	# 2. which groups are flames
	var drawn_top := 0
	var drawn_h := h
	if image != null:
		var used := image.get_used_rect()
		drawn_top = used.position.y
		drawn_h = maxi(1, used.size.y)
	var top_limit := float(drawn_top) + float(spec.get("top_share", 0.6)) * float(drawn_h)
	var largest: Dictionary = {}
	for g: Dictionary in groups:
		if float(g.top) < top_limit and (largest.is_empty() or (g.pixels as PackedInt32Array).size() > (largest.pixels as PackedInt32Array).size()):
			largest = g
	if largest.is_empty():
		return []
	var least := maxi(int(spec.get("min_pixels", 4)) * block * block, int(ceil(float(spec.get("flame_share", 0.15)) * float((largest.pixels as PackedInt32Array).size()))))
	var near := float(largest.top) + float(spec.get("near_share", 0.25)) * float(int(largest.bottom) - int(largest.top) + 1)
	var slim := float(spec.get("slim_share", 0.35))
	var flames: Array = []
	for g: Dictionary in groups:
		var tall := float(int(g.bottom) - int(g.top) + 1)
		var wide := float(int(g.x1) - int(g.x0) + 1)
		if (g.pixels as PackedInt32Array).size() >= least and float(g.top) < top_limit and float(g.top) <= near and wide >= slim * tall:
			g.flame = true
			flames.append(g)
	# 3. each flame takes its whole painted body, its enclosed pale core and whole art cells; no pixel
	# goes to two flames
	var have := PackedByteArray()
	have.resize(w * h)
	for f: Dictionary in flames:
		for i: int in f.pixels:
			have[i] = 1
	if image != null:
		var body_sat := float(spec.get("body_sat", 0.5))
		var body_val := float(spec.get("body_val", 0.45))
		var body_hue := float(spec.get("body_hue", 0.08))
		var core := float(spec.get("core_lum", 0.82))
		for f: Dictionary in flames:
			var hue := float(f.hue)
			var lowest := int(f.bottom)
			var grown := PackedInt32Array()
			var frontier: PackedInt32Array = f.pixels
			while not frontier.is_empty():
				var next := PackedInt32Array()
				for i: int in frontier:
					var x := i % w
					var y := i / w
					for dy in range(-1, 2):
						var ny := y + dy
						if ny < 0 or ny >= h or ny > lowest:
							continue
						for dx in range(-1, 2):
							var nx := x + dx
							if nx < 0 or nx >= w:
								continue
							var j := ny * w + nx
							if have[j] == 1:
								continue
							var c := image.get_pixel(nx, ny)
							if c.a < 0.02:
								continue
							var near_hue := _hue_near(c.h, hue, body_hue)
							if (c.s >= body_sat and c.v >= body_val and near_hue) or (c.a <= 0.3 and (near_hue or c.s < 0.15)):
								have[j] = 1
								grown.append(j)
								next.append(j)
				frontier = next
			# pale cores enclosed on their row by the flame (a blue flame's white heart)
			var row_min := PackedInt32Array()
			row_min.resize(h)
			row_min.fill(w)
			var row_max := PackedInt32Array()
			row_max.resize(h)
			row_max.fill(-1)
			for i: int in f.pixels:
				row_min[i / w] = mini(row_min[i / w], i % w)
				row_max[i / w] = maxi(row_max[i / w], i % w)
			for i: int in grown:
				row_min[i / w] = mini(row_min[i / w], i % w)
				row_max[i / w] = maxi(row_max[i / w], i % w)
			for y in range(int(f.top), lowest + 1):
				for x in range(row_min[y] + 1, row_max[y]):
					var j := y * w + x
					if have[j] == 1:
						continue
					var c := image.get_pixel(x, y)
					if c.a >= 0.1 and _lum(c) >= core * 0.85:
						have[j] = 1
						grown.append(j)
			var joined: PackedInt32Array = f.pixels
			joined.append_array(grown)
			# whole art cells: a cell with any pixel of the flame is all flame (its colour is one)
			if block > 1:
				var in_cell := {}
				for i: int in joined:
					in_cell[((i / w) - oy + block) / block * cw + ((i % w) - ox + block) / block] = true
				var extra := PackedInt32Array()
				for cell: int in in_cell:
					var cy := cell / cw
					var cx := cell % cw
					for yy in range(oy + (cy - 1) * block, oy + cy * block):
						if yy < 0 or yy >= h or yy > lowest:
							continue
						for xx in range(ox + (cx - 1) * block, ox + cx * block):
							if xx < 0 or xx >= w:
								continue
							var j := yy * w + xx
							if have[j] == 0 and image.get_pixel(xx, yy).a >= 0.1:
								have[j] = 1
								extra.append(j)
				joined.append_array(extra)
			f.pixels = joined
	# sparks: small groups just above a flame, within its width
	var spark_reach := float(spec.get("spark_reach", 0.45))
	var reach_px := gap * block
	for g: Dictionary in groups:
		if g.flame:
			continue
		for f: Dictionary in flames:
			var above := float(f.top) - float(g.bottom)
			if above > 0.0 and above <= spark_reach * float(int(f.bottom) - int(f.top) + 1) and g.x1 >= f.x0 - reach_px and g.x0 <= f.x1 + reach_px:
				var free := PackedInt32Array()
				for i: int in g.pixels:
					if have[i] == 0:
						have[i] = 1
						free.append(i)
				var joined: PackedInt32Array = f.pixels
				joined.append_array(free)
				f.pixels = joined
				f.top = mini(f.top, g.top)
				break
	# 4. the still base, the moving part, and how close each moving pixel is to the air
	var air := _air_distance(image, mask, w, h)
	var still := clampf(float(spec.get("static_share", 0.3)), 0.0, 0.9)
	var out: Array = []
	for f: Dictionary in flames:
		var top_c := (int(f.top) - oy + block) / block
		var bottom_c := (int(f.bottom) - oy + block) / block
		var pivot_c := bottom_c - maxi(1, int(ceil(still * float(bottom_c - top_c + 1))))
		if pivot_c < top_c:
			continue
		var pivot := mini(h - 1, oy + pivot_c * block - 1)
		var sway := maxf(float(spec.get("sway_min", 1.0)), float(spec.get("sway", 0.14)) * float(int(f.x1) - int(f.x0) + 1) / float(block))
		var open_px := (int(ceil(sway)) + 1) * block
		var moving := PackedByteArray()
		moving.resize(w * h)
		var open := PackedByteArray()
		open.resize(w * h)
		var list := PackedInt32Array()
		for i: int in f.pixels:
			if i / w <= pivot:
				moving[i] = 1
				list.append(i)
				if air[i] <= open_px:
					open[i] = 1
		if list.is_empty():
			continue
		out.append({"moving": moving, "list": list, "open": open, "pivot": pivot, "pivot_c": pivot_c, "top_c": top_c,
			"x0": int(f.x0), "x1": int(f.x1), "sway": sway, "seed": _hash(int(f.x0), int(f.top), 5) * TAU})
	return out


## True when hue `a` lies within `tolerance` of hue `b` (hues 0..1, around the circle).
static func _hue_near(a: float, b: float, tolerance: float) -> bool:
	var d := absf(a - b)
	return minf(d, 1.0 - d) <= tolerance


## How far (px, counting diagonal steps as one) each pixel is from open air: a pixel of alpha
## below 0.1 in `image` (or, without one, outside the mask), or beyond the picture's border.
static func _air_distance(image: Image, mask: PackedByteArray, w: int, h: int) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(w * h)
	for y in range(h):
		for x in range(w):
			var open: bool = image.get_pixel(x, y).a < 0.1 if image != null else mask[y * w + x] != 1
			dist[y * w + x] = 0 if open else mini(mini(x + 1, y + 1), mini(w - x, h - y))
	for y in range(h):
		for x in range(w):
			var i := y * w + x
			var m := dist[i]
			if m == 0:
				continue
			if x > 0:
				m = mini(m, dist[i - 1] + 1)
			if y > 0:
				m = mini(m, dist[i - w] + 1)
				if x > 0:
					m = mini(m, dist[i - w - 1] + 1)
				if x + 1 < w:
					m = mini(m, dist[i - w + 1] + 1)
			dist[i] = m
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var m := dist[i]
			if m == 0:
				continue
			if x + 1 < w:
				m = mini(m, dist[i + 1] + 1)
			if y + 1 < h:
				m = mini(m, dist[i + w] + 1)
				if x + 1 < w:
					m = mini(m, dist[i + w + 1] + 1)
				if x > 0:
					m = mini(m, dist[i + w - 1] + 1)
			dist[i] = m
	return dist


## Moves the flames (flame_regions) of `image` in picture `pic` for `phase`. First every flame's
## moving pixels that may open to the air are taken out (anywhere else the painted pixel stays
## under the moved flame); then every flame is drawn again curled sideways (most at the tip, the
## bend rising up the flame: sway, curl; neighbouring art rows shift by one art px at most, so no
## tongue tears off) and grown or shrunk from its base (stretch, stretch2), in whole art px of the
## sprite's grid, with its own colours, never over the painted stone or metal around it.
static func _move_flames(image: Image, pic: Image, live: PackedByteArray, solid: PackedByteArray, regions: Array, spec: Dictionary, phase: float, block: int, grid: Vector2i) -> void:
	var w := image.get_width()
	for region: Dictionary in regions:
		var open: PackedByteArray = region.open
		for i: int in region.list:
			if open[i] == 1:
				pic.set_pixel(i % w, i / w, Color(0, 0, 0, 0))
				live[i] = 0
				solid[i] = 0
	for region: Dictionary in regions:
		_draw_moved(image, pic, live, solid, region, spec, phase, block, grid)


static func _draw_moved(image: Image, pic: Image, live: PackedByteArray, solid: PackedByteArray, region: Dictionary, spec: Dictionary, phase: float, block: int, grid: Vector2i) -> void:
	var w := image.get_width()
	var moving: PackedByteArray = region.moving
	var ox := grid.x
	var oy := grid.y
	var seed := float(region.seed)
	var grow := 1.0 + float(spec.get("stretch", 0.1)) * sin(phase + seed) + float(spec.get("stretch2", 0.04)) * sin(2.0 * phase + 1.3 + seed)
	var sway := float(region.sway)
	var curl := float(spec.get("curl", 3.5))
	var pivot: int = region.pivot
	var pivot_c: int = region.pivot_c
	var top_c: int = region.top_c
	var span := maxf(1.0, float(pivot_c - top_c))
	var tallest := float(spec.get("stretch", 0.1)) + float(spec.get("stretch2", 0.04))
	var first_c := top_c - int(ceil(span * tallest)) - 1
	# the shift of each art row, from the base up; neighbouring rows differ by one art px at most
	var shifts := {}
	var prev := 0
	for c in range(pivot_c, first_c - 1, -1):
		var reach := clampf(float(pivot_c - c) / span, 0.0, 1.0)
		var want := int(round(sway * pow(reach, 1.4) * sin(phase - reach * curl + seed)))
		prev = clampi(want, prev - 1, prev + 1)
		shifts[c] = prev
	var margin := (int(ceil(sway)) + 1) * block
	var x0 := maxi(0, int(region.x0) - margin)
	var x1 := mini(w - 1, int(region.x1) + margin)
	var y0 := maxi(0, oy + (first_c - 1) * block)
	for y in range(y0, pivot + 1):
		var cy := (y - oy + block) / block
		var within := y - (oy + (cy - 1) * block)
		var src_c := pivot_c - int(round(float(pivot_c - cy) / grow))
		var src_y := oy + (src_c - 1) * block + within
		if src_y < 0 or src_y > pivot:
			continue
		var shift: int = int(shifts.get(cy, 0)) * block
		for x in range(x0, x1 + 1):
			var src_x := x - shift
			if src_x < 0 or src_x >= w or moving[src_y * w + src_x] != 1:
				continue
			var j := y * w + x
			# never over the painted stone or metal around the flame
			if solid[j] == 1 and moving[j] != 1 and live[j] != 1:
				continue
			var c := image.get_pixel(src_x, src_y)
			pic.set_pixel(x, y, c)
			live[j] = 1
			solid[j] = 1 if c.a >= 0.1 else 0


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
