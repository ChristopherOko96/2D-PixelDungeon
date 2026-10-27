@tool
extends RefCounted
## Whitelisted environmental loops. Frame choice is local, never gameplay state.
const MANIFEST := "res://assets/crypt/living/living_manifest.json"
const COUNT := 16
const FRAMES := 4
const UnifiedSkin = preload("res://src/unified_dungeon_skin.gd")
static var _definitions: Dictionary = {}
static var _frames: Dictionary = {}
static var _source_images: Dictionary = {}
static var _composed_images: Dictionary = {}
static var _loaded := false

## Fixed numeric IDs prevent draft data from loading arbitrary resources.
static func valid_id(id: String) -> bool:
	if not id.begins_with("living_") or id.length() != 10: return false
	var suffix := id.substr(7)
	return suffix.is_valid_int() and int(suffix) >= 0 and int(suffix) < COUNT and suffix == "%03d" % int(suffix)

## Returns timing and size metadata from the local animation manifest.
static func definition(id: String) -> Dictionary:
	if not valid_id(id): return {}
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary:
			for entry: Dictionary in parsed.get("animations",[]):
				if valid_id(str(entry.get("id",""))): _definitions[entry.id] = entry
	return _definitions.get(id,{})

## Per-placement phase prevents a whole flower bed from moving in lockstep.
static func texture(id: String, clock: float = 0.0, phase: float = 0.0) -> Texture2D:
	var entry := definition(id)
	if entry.is_empty(): return null
	var frame := posmod(int(floor((clock+phase)*float(entry.get("fps",4.0)))),FRAMES)
	var key := _render_key(id,frame)
	if not _frames.has(key):
		var pixels := _composed_image(id,frame)
		if pixels == null: return null
		_frames[key] = ImageTexture.create_from_image(pixels)
	return _frames[key]

## Authoring previews can inspect the exact rendered frame without editing PNGs.
## The caller receives a copy; cached body/effect pixels stay immutable.
static func frame_image(id: String, frame: int) -> Image:
	var pixels := _composed_image(id,posmod(frame,FRAMES))
	return pixels.duplicate() as Image if pixels != null else null

static func _source_image(id: String, frame: int) -> Image:
	var key := id+"_%d" % frame
	if not _source_images.has(key):
		var path := "res://assets/crypt/living/frames/%s_f%d.png" % [id,frame]
		if not valid_id(id) or not ResourceLoader.exists(path): return null
		var source: Texture2D = load(path)
		var pixels := source.get_image()
		if pixels == null or pixels.is_empty(): return null
		if pixels.is_compressed(): pixels.decompress()
		if pixels.get_format() != Image.FORMAT_RGBA8: pixels.convert(Image.FORMAT_RGBA8)
		_source_images[key] = pixels
	return _source_images[key]

static func _composed_image(id: String, frame: int) -> Image:
	var entry := definition(id)
	if entry.is_empty(): return null
	var key := _render_key(id,frame)
	if _composed_images.has(key): return _composed_images[key]
	var base := _source_image(id,0)
	var effect := _source_image(id,frame)
	if base == null or effect == null or base.get_size() != effect.get_size(): return null
	# The vessel, stone rim, pot, stand and roots are always the original frame0.
	# Only explicitly permitted effect pixels can differ. No frame-specific
	# translation, rescaling or moving bounding-box alignment is performed.
	# Small per-region sampling offsets may attach a generated flame to the
	# same fixed wick; they never move the sprite or any body pixels.
	var result := base.duplicate() as Image
	if frame != 0:
		for region: Dictionary in entry.get("effect_regions",[]):
			for y in range(base.get_height()):
				for x in range(base.get_width()):
					if not _inside_region(Vector2(x+0.5,y+0.5),region): continue
					var fixed := base.get_pixel(x,y)
					var source_point := Vector2i(x,y)
					var offsets: Array = region.get("frame_source_offsets",[])
					if frame < offsets.size(): source_point += Vector2i(int(offsets[frame][0]),int(offsets[frame][1]))
					var animated := Color.TRANSPARENT
					if source_point.x >= 0 and source_point.y >= 0 and source_point.x < effect.get_width() and source_point.y < effect.get_height(): animated = effect.get_pixelv(source_point)
					if not _base_filter(fixed,region): continue
					var mode := str(region.get("mode","replace"))
					if mode in ["cyan_only","foliage_only","warm_only"]:
						var selector := "cyan" if mode == "cyan_only" else "warm" if mode == "warm_only" else "foliage"
						if fixed.a > 0.02 and not _color_matches(fixed,selector): continue
						if _color_matches(animated,selector): result.set_pixel(x,y,animated)
						elif region.get("preserve_base_when_empty",false) and fixed.a > 0.02: result.set_pixel(x,y,fixed)
						else: result.set_pixel(x,y,Color.TRANSPARENT)
					elif mode == "color_only":
						if fixed.a <= 0.02 or animated.a <= 0.02: continue
						var selector := str(region.get("source_color",""))
						if not selector.is_empty() and not _color_matches(animated,selector): continue
						result.set_pixel(x,y,Color(animated.r,animated.g,animated.b,fixed.a))
					else: result.set_pixel(x,y,animated)
	if not UnifiedSkin.active:
		# The supplied pack uses16px artwork on a32px world cell. Apply the
		# same2-world-pixel projection after effect compositing, identically
		# for frame0 and every other frame. Bodies cannot wobble or rescale.
		var size_values: Array = entry.get("draw_size",[32,32])
		var logical_width := maxi(1,int(size_values[0])/2)
		var logical_height := maxi(1,int(size_values[1])/2)
		var final_size := result.get_size()
		result.resize(logical_width,logical_height,Image.INTERPOLATE_NEAREST)
		result.resize(final_size.x,final_size.y,Image.INTERPOLATE_NEAREST)
	_composed_images[key] = result
	return result

static func _render_key(id: String, frame: int) -> String:
	return id+"_%d_" % frame+("detailed" if UnifiedSkin.active else "original")

static func _base_filter(color: Color, region: Dictionary) -> bool:
	if color.r*0.2126+color.g*0.7152+color.b*0.0722 < float(region.get("base_min_luma",0)): return false
	var selector := str(region.get("base_color",""))
	return selector.is_empty() or _color_matches(color,selector)

static func _color_matches(color: Color, selector: String) -> bool:
	if color.a <= 0.02: return false
	if selector == "cyan": return color.g > 0.3 and color.b > 0.25 and color.g > color.r*1.17 and color.b > color.r*1.12
	if selector == "foliage": return color.g > 0.2 and color.g > color.r*1.03 and color.g > color.b*1.02
	if selector == "warm": return color.r > 0.45 and color.r > color.b*1.7 and color.g > color.b*1.4
	return true

static func _inside_region(point: Vector2, region: Dictionary) -> bool:
	match str(region.get("shape","rect")):
		"ellipse":
			var center: Array = region.get("center",[0,0])
			var radii: Array = region.get("radii",[0,0])
			if float(radii[0]) <= 0 or float(radii[1]) <= 0: return false
			var distance := (point-Vector2(center[0],center[1]))/Vector2(radii[0],radii[1])
			return distance.length_squared() <= 1.0
		"polygon":
			var points: Array = region.get("points",[])
			if points.size() < 3: return false
			var inside := false
			var previous := points.size()-1
			for index in range(points.size()):
				var a := Vector2(points[index][0],points[index][1])
				var b := Vector2(points[previous][0],points[previous][1])
				if (a.y > point.y) != (b.y > point.y) and point.x < (b.x-a.x)*(point.y-a.y)/(b.y-a.y)+a.x: inside = not inside
				previous = index
			return inside
		_:
			var values: Array = region.get("rect",[0,0,0,0])
			return Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3])).has_point(point)

## All frames share a ground anchor, including larger32-grid overhangs.
static func draw_rect(id: String) -> Rect2:
	var size_values: Array = definition(id).get("draw_size",[32,32])
	var dimensions := Vector2(float(size_values[0]),float(size_values[1]))
	return Rect2(Vector2(-dimensions.x*0.5,16-dimensions.y),dimensions)
