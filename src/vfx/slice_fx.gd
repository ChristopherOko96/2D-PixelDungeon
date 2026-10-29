extends RefCounted
## Enemies cut in two by the swordsman's Rage (snapshot field `slice` = the cut's
## angle): the body's rest image splits along the cut, both halves slide apart,
## tip over and sink while a dark red line marks the cut, then fade. Client only.

const LIFE := 1.5
const BLOOD := Color("#7a1414")

var library: RefCounted
var _records: Dictionary = {}
var _textures: Dictionary = {}


func _init(rig_library: RefCounted) -> void:
	library = rig_library


## True for a dying enemy that was cut: the view skips its normal death.
func handles(enemy: Dictionary) -> bool:
	return enemy.has("slice") and float(enemy.get("dying_p", -1.0)) >= 0.0


## Starts the halves the first time a cut enemy is seen dying.
func observe(enemy: Dictionary, point: Vector2, clock: float) -> void:
	var id := int(enemy.get("id", 0))
	if _records.has(id): return
	var name := str(enemy.get("rig", ""))
	var rig: Dictionary = library.rig(name)
	if rig.is_empty(): return
	_records[id] = {"texture": _texture(name, rig), "size": Vector2(rig.size), "ground": Vector2(rig.ground), "center": Vector2(rig.center),
		"hover": float(rig.get("hover", 0.0)), "scale": float(rig.get("scale", 2.0)), "face": -1.0 if float(enemy.get("face", -1.0)) < 0.0 else 1.0,
		"origin": point, "angle": float(enemy.slice), "start": clock}


## Draws every running cut; finished ones are dropped.
func draw(canvas: CanvasItem, clock: float) -> void:
	for id: int in _records.keys():
		var r: Dictionary = _records[id]
		var age := clock - float(r.start)
		if age > LIFE or age < 0.0:
			_records.erase(id)
			continue
		_draw_record(canvas, r, age / LIFE)


func reset() -> void:
	_records.clear()


func _draw_record(canvas: CanvasItem, r: Dictionary, t: float) -> void:
	var size: Vector2 = r.size
	var face: float = r.face
	var world_dir := Vector2.RIGHT.rotated(float(r.angle))
	# the cut in source pixels (mirrored for figures facing left), through the body's centre
	var dir := Vector2(world_dir.x * face, world_dir.y)
	var normal := dir.orthogonal()
	var center: Vector2 = r.center
	var rect := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	var alpha := clampf((1.0 - t) / 0.3, 0.0, 1.0)
	var open := ease(clampf(t / 0.35, 0.0, 1.0), 0.4)
	for side: float in [1.0, -1.0]:
		var half := _clip(rect, center, normal * side)
		if half.size() < 3: continue
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		var world_normal := Vector2(normal.x * face, normal.y) * side
		var shift := world_normal * (4.0 + 18.0 * open) + Vector2(0, 14.0 * t * t)
		var pivot := _to_world(r, center) + shift
		var spin := side * 0.6 * open
		for p: Vector2 in half:
			var w := _to_world(r, p) + shift
			points.append(pivot + (w - pivot).rotated(spin))
			uvs.append(p / size)
		canvas.draw_colored_polygon(points, Color(1, 1, 1, alpha), uvs, r.texture)
		# the cut edge bleeds
		var edge := _segment_in(half, r)
		if edge.size() == 2:
			canvas.draw_line(pivot + (edge[0] + shift - pivot).rotated(spin), pivot + (edge[1] + shift - pivot).rotated(spin), Color(BLOOD, alpha), maxf(1.0, float(r.scale)))
	# a few drops fall from the cut while it opens
	if t < 0.5:
		var mid := _to_world(r, center)
		for i in range(4):
			var drop := mid + Vector2((float(i) - 1.5) * 4.0 * float(r.scale), 30.0 * t + float(i % 2) * 6.0)
			canvas.draw_rect(Rect2(drop, Vector2(float(r.scale), float(r.scale) * 2.0)), Color(BLOOD, alpha))


## Source pixel -> world, as the rig renderer places the figure (ground anchor, facing, scale).
func _to_world(r: Dictionary, p: Vector2) -> Vector2:
	var scale := float(r.scale)
	return Vector2(r.origin) + Vector2((p.x - Vector2(r.ground).x) * float(r.face) * scale, (p.y - Vector2(r.center).y - float(r.hover)) * scale)


## The part of a convex polygon on the side `normal` points to (Sutherland-Hodgman, one plane).
func _clip(poly: PackedVector2Array, origin: Vector2, normal: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := (a - origin).dot(normal)
		var db := (b - origin).dot(normal)
		if da >= 0.0: out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


## The cut edge of a half (its points lying on the cut), in world pixels.
func _segment_in(half: PackedVector2Array, r: Dictionary) -> PackedVector2Array:
	var dir := Vector2.RIGHT.rotated(float(r.angle))
	dir = Vector2(dir.x * float(r.face), dir.y)
	var normal := dir.orthogonal()
	var on := PackedVector2Array()
	for p: Vector2 in half:
		if absf((p - Vector2(r.center)).dot(normal)) < 0.01: on.append(_to_world(r, p))
	return on if on.size() == 2 else PackedVector2Array()


## The rig's rest pose as one texture (all parts and items laid together).
func _texture(name: String, rig: Dictionary) -> Texture2D:
	if _textures.has(name): return _textures[name]
	var size := Vector2i(rig.size)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for part: Dictionary in rig.get("parts", []) + rig.get("items", []):
		var piece: Variant = part.get("image")
		if not piece is Image: continue
		var at := Vector2i.ZERO if (piece as Image).get_size() == size else Vector2i(Rect2(part.get("bounds", Rect2())).position)
		var src := (piece as Image).duplicate() as Image
		src.convert(Image.FORMAT_RGBA8)
		image.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
	var texture := ImageTexture.create_from_image(image)
	_textures[name] = texture
	return texture
