extends RefCounted
## The decor catalog (assets/data/dungeon_decor.json): which floor styles,
## carpets, wall pieces and objects the Dungeon-Werkstatt offers, sorted into
## categories, and how the crypt renderer (crypt_0x72_art.gd) draws them.
## Rooms store decor as plain arrays [x, y, "id", variant]:
## `decor_areas` (floor styles and carpets, at most one of each per cell) and
## `decor` (wall pieces and objects, one per cell). Unknown ids are skipped, so
## a room never breaks when the catalog changes.

const PATH := "res://assets/data/dungeon_decor.json"
const SPRITES := "res://assets/sprites/"
## Area kinds paint cells; the others are single pieces.
const AREA_KINDS := ["floor", "carpet"]
const T := 16

static var _data: Dictionary = {}
static var _by_id: Dictionary = {}
static var _images: Dictionary = {}
static var _textures: Dictionary = {}


## The whole catalog (loaded once).
static func data() -> Dictionary:
	if _data.is_empty(): reload()
	return _data


## Reads the catalog again (after the file changed).
static func reload(path: String = PATH) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_data = parsed if parsed is Dictionary else {"categories": [], "items": []}
	_by_id.clear()
	for entry: Variant in _data.get("items", []):
		if entry is Dictionary: _by_id[str(entry.get("id", ""))] = entry


## [{id, label, hint}] in display order.
static func categories() -> Array:
	return data().get("categories", [])


## Items of one category, in catalog order.
static func items_in(category: String) -> Array:
	return data().get("items", []).filter(func(entry: Dictionary) -> bool: return str(entry.get("category", "")) == category)


## The item with `id`, or {} when the catalog has none.
static func item(id: String) -> Dictionary:
	data()
	return _by_id.get(id, {})


static func kind(id: String) -> String:
	return str(item(id).get("kind", ""))


## True for floor styles and carpets (painted like floor).
static func is_area(id: String) -> bool:
	return kind(id) in AREA_KINDS


static func is_solid(id: String) -> bool:
	return bool(item(id).get("solid", false))


static func gives_light(id: String) -> bool:
	return bool(item(id).get("light", false))


## Number of variants (1 for carpets and single-tile items).
static func variants(id: String) -> int:
	return maxi(1, Array(item(id).get("tiles", [])).size())


## Variant a new piece gets: random when the item says so and `random` is on.
static func pick_variant(id: String, wanted: int, random: bool, rng: RandomNumberGenerator) -> int:
	if random and variants(id) > 1: return rng.randi_range(0, variants(id) - 1)
	return posmod(wanted, variants(id))


## res:// path of a variant's tile (or the carpet sheet).
static func tile_path(id: String, variant: int = 0) -> String:
	var entry := item(id)
	if entry.has("sheet"): return SPRITES + str(entry.sheet) + ".png"
	var tiles: Array = entry.get("tiles", [])
	if tiles.is_empty(): return ""
	return SPRITES + str(tiles[posmod(variant, tiles.size())]) + ".png"


## Art offset (16-px art units) of tall pieces such as columns.
static func offset(id: String) -> Vector2i:
	var value: Array = item(id).get("offset", [0, 0])
	return Vector2i(int(value[0]), int(value[1])) if value.size() == 2 else Vector2i.ZERO


## The tile as an RGBA image (cached), for baking.
static func image(path: String) -> Image:
	if path.is_empty(): return null
	if not _images.has(path):
		var source: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if source == null:
			_images[path] = null
		else:
			var picture := source.get_image().duplicate()
			if picture.is_compressed(): picture.decompress()
			picture.convert(Image.FORMAT_RGBA8)
			_images[path] = picture
	return _images[path]


## The tile as a texture (cached), for thumbnails and previews.
static func texture(id: String, variant: int = 0) -> Texture2D:
	var path := tile_path(id, variant)
	if path.is_empty() or not ResourceLoader.exists(path): return null
	if not _textures.has(path): _textures[path] = load(path)
	return _textures[path]


## One 16x16 carpet cell cut from a 3x3 sheet (corners, edges, middle): each
## quarter takes the edge only where the carpet ends on that side, so any
## painted shape gets a closed border. `n`, `e`, `s`, `w`: carpet continues.
static func carpet_cell(sheet: Image, n: bool, e: bool, s: bool, w: bool) -> Image:
	var cell := Image.create(T, T, false, Image.FORMAT_RGBA8)
	if sheet == null: return cell
	var half := T / 2
	for qy in range(2):
		for qx in range(2):
			var across: bool = w if qx == 0 else e
			var along: bool = n if qy == 0 else s
			var column: int = 1 if across else (0 if qx == 0 else 2)
			var row: int = 1 if along else (0 if qy == 0 else 2)
			cell.blit_rect(sheet, Rect2i(column * T + qx * half, row * T + qy * half, half, half), Vector2i(qx * half, qy * half))
	return cell


## A small preview of a carpet (3 x 2 cells) for the library.
static func carpet_preview(id: String) -> Image:
	var sheet := image(tile_path(id))
	var preview := Image.create(T * 3, T * 2, false, Image.FORMAT_RGBA8)
	for y in range(2):
		for x in range(3):
			var cell := carpet_cell(sheet, y > 0, x < 2, y < 1, x > 0)
			preview.blend_rect(cell, Rect2i(0, 0, T, T), Vector2i(x * T, y * T))
	return preview


## A piece as it will look (16 px art): {image, origin}, where `origin` is
## the top-left of its own cell inside the image (tall pieces reach above).
## `ground` puts it on a wall or floor tile (library thumbnails); without it
## the image is the bare piece (the placement ghost).
static func preview(id: String, variant: int = 0, ground: bool = true) -> Dictionary:
	var entry := item(id)
	var piece_kind := str(entry.get("kind", ""))
	if piece_kind == "carpet": return {"image": carpet_preview(id), "origin": Vector2i.ZERO}
	if piece_kind == "floor": return {"image": image(tile_path(id, variant)), "origin": Vector2i.ZERO}
	if str(entry.get("draw", "")) == "shaft": return {"image": shaft_preview(ground), "origin": Vector2i(4, 32)}
	var wall := piece_kind == "wall"
	var layers: Array = []
	if ground: layers.append([image(SPRITES + ("0x72/wall_mid.png" if wall else "0x72/floor_1.png")), Vector2i.ZERO])
	var style := str(entry.get("draw", "stamp"))
	if style == "fountain":
		layers.append([image(SPRITES + "0x72/wall_fountain_top_1.png"), Vector2i(0, -T)])
		layers.append([image(tile_path(id, variant)), Vector2i.ZERO])
		layers.append([image(SPRITES + "0x72/wall_fountain_basin_%s_anim_f0.png" % str(entry.get("color", "red"))), Vector2i(0, T)])
	else:
		if entry.has("below"):
			if ground: layers.append([image(SPRITES + "0x72/floor_1.png"), Vector2i(0, T)])
			layers.append([image(SPRITES + str(entry.below) + ".png"), Vector2i(0, T)])
		layers.append([image(tile_path(id, variant)), Vector2i(0, -8) if style == "torch" else offset(id)])
	var low := Vector2i.ZERO
	var high := Vector2i(T, T)
	for layer: Array in layers:
		var picture: Image = layer[0]
		if picture == null: continue
		var at: Vector2i = layer[1]
		low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
		high = Vector2i(maxi(high.x, at.x + picture.get_width()), maxi(high.y, at.y + picture.get_height()))
	var result := Image.create(high.x - low.x, high.y - low.y, false, Image.FORMAT_RGBA8)
	for layer: Array in layers:
		var picture: Image = layer[0]
		if picture != null: result.blend_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), Vector2i(layer[1]) - low)
	return {"image": result, "origin": -low}


## A small picture of the light shaft (it has no tile): a warm cone from the
## top onto a floor tile, with a few specks of dust. 24 x 48 art pixels.
static func shaft_preview(ground: bool = true) -> Image:
	var result := Image.create(24, 48, false, Image.FORMAT_RGBA8)
	if ground:
		var floor_tile := image(SPRITES + "0x72/floor_1.png")
		if floor_tile != null: result.blend_rect(floor_tile, Rect2i(0, 0, T, T), Vector2i(4, 32))
	for y in range(48):
		var half := lerpf(2.0, 11.0, float(y) / 47.0)
		var alpha := lerpf(0.05, 0.55, float(y) / 47.0)
		for x in range(24):
			var off := absf(float(x) - 11.5)
			if off > half: continue
			var light := Color(1.0, 0.93, 0.7, alpha * (1.0 - off / (half + 1.0) * 0.6))
			result.set_pixel(x, y, result.get_pixel(x, y).blend(light))
	for speck: Vector2i in [Vector2i(10, 12), Vector2i(14, 22), Vector2i(8, 30), Vector2i(13, 38), Vector2i(11, 6)]:
		result.set_pixel(speck.x, speck.y, Color(1.0, 0.98, 0.88, 0.95))
	return result


## True when a wall piece may hang on `cell`: a wall with floor right below.
static func wall_spot(floor_cells: Dictionary, cell: Vector2i) -> bool:
	return not floor_cells.has(cell) and floor_cells.has(cell + Vector2i.DOWN)


## Checks the shape of stored decor lists (the generator calls this before
## trusting a room): arrays of [x, y, id, variant] inside `cells`.
static func valid_list(value: Variant, cells: Vector2i, limit: int) -> bool:
	if not value is Array or value.size() > limit: return false
	for entry: Variant in value:
		if not entry is Array or entry.size() < 3 or entry.size() > 4: return false
		for index in [0, 1]:
			var number: Variant = entry[index]
			if not (number is int or number is float) or not is_finite(float(number)) or float(number) != floorf(float(number)): return false
		if int(entry[0]) < 0 or int(entry[1]) < 0 or int(entry[0]) >= cells.x or int(entry[1]) >= cells.y: return false
		if not entry[2] is String or str(entry[2]).length() > 40: return false
		if entry.size() == 4 and (not (entry[3] is int or entry[3] is float) or int(entry[3]) < 0 or int(entry[3]) > 63): return false
	return true
