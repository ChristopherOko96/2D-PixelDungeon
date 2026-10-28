extends RefCounted
## Part rigs of the 0x72 figures (assets/data/rigs.json, exported from the
## approved review page). Each source frame is split into parts by rects; parts
## and held items get their own textures once. The host uses the rest-pose part
## areas and HP weights for body-part hits; the presentation draws the parts.
## No node and no singleton: each owner keeps one instance (see shared()).

const DATA_PATH := "res://assets/data/rigs.json"
## Rigs are drawn at 2x, like every other 0x72 sprite in the game.
const PIXEL_SCALE := 2.0
## Floating figures are drawn this many source pixels above their rest pose.
const HOVER := {"necro": 3.0, "void": 5.0, "bomber": 3.0}

static var _shared: RefCounted

## name -> rig Dictionary (see _finish for the fields).
var rigs: Dictionary = {}
var ready := false


## One library per process; building textures is cheap but not free.
static func shared() -> RefCounted:
	if _shared == null:
		_shared = load("res://src/rig/rig_library.gd").new()
		_shared.load_data()
	return _shared


## Loads and builds every rig. Returns false when the data file is missing.
func load_data(path: String = DATA_PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return false
	var images: Dictionary = data.get("images", {})
	var art: Dictionary = data.get("pixel_art", {})
	for name: String in data.get("rigs", {}):
		var built := _build_rig(name, data.rigs[name], images, art)
		if not built.is_empty(): rigs[name] = built
	if data.has("void"): rigs["void"] = _build_void(data.void)
	if data.has("bomber"): rigs["bomber"] = _build_bomber(data.bomber)
	# Size factors (bosses are drawn 3x): world pixels per source pixel.
	for name: String in rigs: rigs[name].scale = PIXEL_SCALE * float(data.get("scales", {}).get(name, 1.0))
	ready = not rigs.is_empty()
	return ready


## The rig, or an empty Dictionary for unknown names.
func rig(name: String) -> Dictionary:
	return rigs.get(name, {})


# --------------------------------------------------------------- building

func _image(path: String) -> Image:
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var texture: Texture2D = load(path)
	if texture == null: return null
	var image := texture.get_image()
	if image == null: return null
	image = image.duplicate()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _pixels(rows: Array, palette: Dictionary) -> Image:
	var image := Image.create(str(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			if palette.has(row[x]): image.set_pixel(x, y, Color(str(palette[row[x]])))
	return image


func _source(key: String, images: Dictionary, art: Dictionary) -> Image:
	if art.has(key): return _pixels(art[key].rows, art[key].palette)
	return _image(str(images.get(key, "")))


func _recolor(image: Image, mapping: Dictionary) -> void:
	var lookup: Dictionary = {}
	for from: String in mapping: lookup[from.trim_prefix("#").to_lower()] = Color(str(mapping[from]))
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a < 0.5: continue
			var key := color.to_html(false).to_lower()
			if lookup.has(key): image.set_pixel(x, y, lookup[key])


func _build_rig(name: String, def: Dictionary, images: Dictionary, art: Dictionary) -> Dictionary:
	var source := _source(str(def.img), images, art)
	if source == null: return {}
	if def.get("recolor") is Dictionary: _recolor(source, def.recolor)
	var w := source.get_width()
	var h := source.get_height()
	var defs: Array = def.get("parts", [])
	var owned: Array[Image] = []
	for _part in defs: owned.append(Image.create(w, h, false, Image.FORMAT_RGBA8))
	for y in range(h):
		for x in range(w):
			var color := source.get_pixel(x, y)
			if color.a < 0.5: continue
			for index in range(defs.size()):
				if _in_rects(defs[index].rects, x, y):
					owned[index].set_pixel(x, y, color)
					break
	var parts: Array[Dictionary] = []
	for index in range(defs.size()):
		var spec: Dictionary = defs[index]
		var part := _layer(owned[index])
		part.merge(_part_fields(spec), true)
		parts.append(part)
	var items: Array[Dictionary] = []
	for spec: Dictionary in def.get("items", []):
		var item_image := _source(str(spec.img), images, art)
		if item_image == null: continue
		if bool(spec.get("bow", false)): _remove_bow_string(item_image)
		var item := _layer(item_image)
		item.merge(_part_fields(spec), true)
		item.is_item = true
		item.grip = _vec(spec.grip)
		item.hand = _vec(spec.hand)
		item.rest = float(spec.get("rest", 0.0))
		item.tip = _vec(spec.get("tip", [0, 0]))
		item.bow = bool(spec.get("bow", false))
		item.bounds = _item_bounds(item)
		items.append(item)
	return _finish(name, def, parts, items, source)


func _in_rects(rects: Array, x: int, y: int) -> bool:
	for rect: Array in rects:
		if x >= int(rect[0]) and x <= int(rect[2]) and y >= int(rect[1]) and y <= int(rect[3]): return true
	return false


func _vec(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _part_fields(spec: Dictionary) -> Dictionary:
	return {"id": str(spec.id), "pivot": _vec(spec.get("pivot", [0, 0])), "parent": str(spec.get("parent", "")) if spec.get("parent") != null else "",
		"z": int(spec.get("z", 0)), "hp": float(spec.get("hp", 0)), "label": str(spec.get("label", spec.id)), "vital": bool(spec.get("vital", false)),
		"disables": str(spec.get("disables", "")), "regrow": float(spec.get("regrow", 0)), "also_detach": Array(spec.get("alsoDetach", [])),
		"exposed": str(spec.get("exposed", "")), "is_item": false}


## A drawable layer: texture, white silhouette for hit flashes, opaque bounds.
func _layer(image: Image) -> Dictionary:
	var used := image.get_used_rect()
	var silhouette := image.duplicate()
	var sum := Vector2.ZERO
	var count := 0
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var alpha := image.get_pixel(x, y).a
			if alpha < 0.5: continue
			silhouette.set_pixel(x, y, Color(1, 1, 1, alpha))
			sum += Vector2(x + 0.5, y + 0.5)
			count += 1
	return {"texture": ImageTexture.create_from_image(image), "white": ImageTexture.create_from_image(silhouette), "image": image,
		"bounds": Rect2(used.position, used.size), "center": sum / maxf(1.0, float(count)), "size": Vector2(image.get_size())}


func _remove_bow_string(image: Image) -> void:
	for y in range(image.get_height()):
		for x in [7, 8]:
			if x >= image.get_width(): continue
			var color := image.get_pixel(x, y)
			if color.a > 0.5 and color.r8 == 0xd3 and color.g8 == 0xbf: image.set_pixel(x, y, Color(0, 0, 0, 0))


## Rest-pose box of a held item in the figure's source pixels.
func _item_bounds(item: Dictionary) -> Rect2:
	var xform := Transform2D(float(item.rest), Vector2(item.hand)) * Transform2D(0.0, -Vector2(item.grip))
	var box: Rect2 = item.bounds
	var result := Rect2(xform * box.position, Vector2.ZERO)
	for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		result = result.expand(xform * corner)
	return result


func _finish(name: String, def: Dictionary, parts: Array[Dictionary], items: Array[Dictionary], source: Image) -> Dictionary:
	var by_id: Dictionary = {}
	for part in parts + items: by_id[part.id] = part
	var center := Vector2.ZERO
	var count := 0
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x, y).a >= 0.5:
				center += Vector2(x + 0.5, y + 0.5)
				count += 1
	center /= maxf(1.0, float(count))
	var family: String = str(def.get("family", ""))
	return {"name": name, "family": family, "variant": str(def.get("variant", "")), "attack": str(def.get("attack", "")),
		"ground": _vec(def.get("ground", [0, 0])), "width": float(def.get("width", 10)), "center": center, "top": float(source.get_used_rect().position.y),
		"hover": float(HOVER.get(family, 0.0)), "size": Vector2(source.get_size()), "parts": parts, "items": items, "by_id": by_id}


## Leerenrufer: the body is a flipbook of 8 frames, the eye has three states,
## both claws (one mirrored) overlap the body. All layers share a 44x44 frame.
func _build_void(data: Dictionary) -> Dictionary:
	var frame: Dictionary = data.frame
	var w := int(frame.w)
	var h := int(frame.h)
	var palette: Dictionary = data.palette
	var place := func(image: Image, at: Vector2i, flip: bool = false) -> Image:
		var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var copy := image.duplicate()
		if flip: copy.flip_x()
		canvas.blend_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), at)
		return canvas
	var body: Array[Dictionary] = []
	for path: String in data.frames:
		var image := _image(path)
		if image != null: body.append(_layer(place.call(image, Vector2i.ZERO)))
	var claw := _pixels(data.claw_left, palette)
	var pivot := _vec(data.claw_pivot)
	var shoulder := _vec(data.shoulder_left)
	var tip := _vec(data.claw_tip)
	var right_shoulder := Vector2(w - 1 - shoulder.x, shoulder.y)
	var right_x := right_shoulder.x - (claw.get_width() - 1 - pivot.x)
	var eye_at := _vec(data.eye.at)
	var eyes: Array[Dictionary] = []
	for state: String in ["closed", "half", "open"]:
		eyes.append(_layer(place.call(_pixels(data.eye[state], palette), Vector2i(eye_at))))
	var specs: Dictionary = data.get("parts", {})
	var make := func(id: String, layers: Array, fields: Dictionary) -> Dictionary:
		var part: Dictionary = layers[0].duplicate()
		part.merge(_part_fields(_spec(specs, id)), true)
		part.merge(fields, true)
		if layers.size() > 1:
			part.frames = layers
			var bounds: Rect2 = layers[0].bounds
			for layer: Dictionary in layers: bounds = bounds.merge(layer.bounds)
			part.bounds = bounds
			part.image = _union_image(layers)
		return part
	var parts: Array[Dictionary] = [
		make.call("core", body, {"pivot": Vector2(float(frame.center_x), float(frame.bottom)), "parent": "", "z": 2}),
		make.call("eye", eyes, {"pivot": eye_at + Vector2(3, 2), "parent": "core", "z": 3}),
		make.call("claw_l", [_layer(place.call(claw, Vector2i(shoulder - pivot)))], {"pivot": shoulder, "parent": "core", "z": 4, "tip": shoulder - pivot + tip + Vector2(0.5, 0.5)}),
		make.call("claw_r", [_layer(place.call(claw, Vector2i(int(right_x), int(shoulder.y - pivot.y)), true))], {"pivot": right_shoulder, "parent": "core", "z": 4,
			"tip": Vector2(right_x + (claw.get_width() - 1 - tip.x) + 0.5, shoulder.y - pivot.y + tip.y + 0.5)}),
	]
	# The open eye is the hit area; closed it is only a slit.
	parts[1].bounds = eyes[2].bounds
	parts[1].image = eyes[2].image
	var rig := _finish("void", {"family": "void", "ground": [float(frame.center_x), h - 1], "width": 20}, parts, [], _union_image(body))
	rig.eye_center = eye_at + Vector2(3.5, 2.5)
	rig.skull = ImageTexture.create_from_image(_pixels(data.skull, palette))
	rig.fps = float(frame.get("fps", 9))
	return rig


func _spec(specs: Dictionary, id: String) -> Dictionary:
	var spec: Dictionary = specs.get(id, {}).duplicate()
	spec.id = id
	return spec


func _union_image(layers: Array[Dictionary]) -> Image:
	var image: Image = layers[0].texture.get_image()
	image = image.duplicate()
	for layer: Dictionary in layers.slice(1):
		var other: Image = layer.texture.get_image()
		image.blend_rect(other, Rect2i(Vector2i.ZERO, other.get_size()), Vector2i.ZERO)
	return image


## Leerenbomber: one vital skull, a 10 fps flipbook of the sheet's frames.
func _build_bomber(data: Dictionary) -> Dictionary:
	var frames: Array[Dictionary] = []
	for path: String in data.frames:
		var image := _image(path)
		if image != null: frames.append(_layer(image))
	if frames.is_empty(): return {}
	var part: Dictionary = frames[0].duplicate()
	part.merge(_part_fields(_spec(data.get("parts", {}), "skull")), true)
	part.frames = frames
	part.pivot = _vec(data.ground)
	var bounds: Rect2 = frames[0].bounds
	for layer: Dictionary in frames: bounds = bounds.merge(layer.bounds)
	part.bounds = bounds
	part.image = _union_image(frames)
	var rig := _finish("bomber", {"family": "bomber", "ground": data.ground, "width": data.get("width", 8)}, [part], [], _union_image(frames))
	rig.fps = float(data.get("fps", 10))
	return rig


# --------------------------------------------------------------- host queries

## HP weights of all breakable parts and items (id -> weight).
func weights(name: String) -> Dictionary:
	var result: Dictionary = {}
	var data := rig(name)
	for part: Dictionary in data.get("parts", []) + data.get("items", []):
		if float(part.hp) > 0: result[part.id] = float(part.hp)
	return result


## Maps a world point to the rig's source pixels for an actor whose body
## centre is at `origin` and who faces `face` (+1 right, -1 left).
func to_source(name: String, origin: Vector2, face: float, point: Vector2) -> Vector2:
	var data := rig(name)
	if data.is_empty(): return Vector2.ZERO
	var ground: Vector2 = data.ground
	var center: Vector2 = data.center
	var sign := -1.0 if face < 0.0 else 1.0
	# Floating figures are drawn `hover` pixels higher than their rest pose.
	var scale := float(data.get("scale", PIXEL_SCALE))
	return Vector2(ground.x + (point.x - origin.x) / scale * sign, center.y + float(data.hover) + (point.y - origin.y) / scale)


## The breakable part with an opaque rest-pose pixel nearest to a world point,
## within `reach` world pixels (a projectile's radius). Only ids in `alive`
## count, and `exposed` parts only while their action is `active`. Ties go to
## the part drawn in front. Returns "" when no part is that close.
func part_at(name: String, origin: Vector2, face: float, point: Vector2, alive: Dictionary, active: String = "", reach: float = 2.0) -> String:
	var data := rig(name)
	if data.is_empty(): return ""
	var local := to_source(name, origin, face, point)
	var radius := maxf(0.5, reach / float(data.get("scale", PIXEL_SCALE)))
	var best := ""
	var best_distance := INF
	var best_z := -999
	for part: Dictionary in data.parts + data.items:
		if not alive.has(part.id): continue
		if not str(part.exposed).is_empty() and str(part.exposed) != active: continue
		var distance := _pixel_distance(part, local, radius)
		if distance < best_distance - 0.01 or (distance < best_distance + 0.01 and distance < INF and int(part.z) > best_z):
			best = part.id
			best_distance = distance
			best_z = int(part.z)
	return best


## Distance from a source point to the part's nearest opaque pixel centre, or
## INF beyond `radius`. Items are tested in their own rest-pose frame.
func _pixel_distance(part: Dictionary, local: Vector2, radius: float) -> float:
	var image: Image = part.get("image")
	if image == null: return INF
	var probe := local
	if bool(part.is_item):
		probe = (Transform2D(float(part.rest), Vector2(part.hand)) * Transform2D(0.0, -Vector2(part.grip))).affine_inverse() * local
	var best := INF
	var span := int(ceil(radius))
	var base := Vector2i(floori(probe.x), floori(probe.y))
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var pixel := base + Vector2i(dx, dy)
			if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height(): continue
			if image.get_pixelv(pixel).a < 0.5: continue
			var distance := probe.distance_to(Vector2(pixel) + Vector2(0.5, 0.5))
			if distance <= radius + 0.71 and distance < best: best = distance
	return best


## The living part nearest to a world point (for melee, splash and fallbacks).
func nearest_part(name: String, origin: Vector2, face: float, point: Vector2, alive: Dictionary, active: String = "") -> String:
	var close := part_at(name, origin, face, point, alive, active, 48.0)
	if not close.is_empty(): return close
	# Far away: the part whose box is nearest.
	var data := rig(name)
	if data.is_empty(): return ""
	var local := to_source(name, origin, face, point)
	var best := ""
	var best_distance := INF
	for part: Dictionary in data.parts + data.items:
		if not alive.has(part.id): continue
		if not str(part.exposed).is_empty() and str(part.exposed) != active: continue
		var area: Rect2 = part.bounds
		var distance := local.distance_squared_to(local.clamp(area.position, area.end))
		if distance < best_distance:
			best = part.id
			best_distance = distance
	return best
