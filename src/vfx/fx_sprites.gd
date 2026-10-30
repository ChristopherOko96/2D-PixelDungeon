extends RefCounted
## Plays the pixel-art effect animations (assets/sprites/fx, made by
## scripts/make_fx_sprites.gd; frame data in assets/data/vfx_sprites.json).
## `spawn` starts a one-shot animation at a world point (rotated, scaled,
## tinted); `draw_loop` draws a looping sheet for things that persist (orbs,
## fireballs, auras). Each sprite pixel is `pixel` world px: 2 like the 0x72
## art in the crypt, 3 on the story worlds' grid.
##
## Fade-outs: every animation eases out instead of stopping, by the 4x4
## ordered dither (sprite pixels drop out in steps, never see-through; a tint
## with alpha < 1 dithers the same way); magic lingers on its last frame for a
## moment and lights up the bloom layer (MAGIC; bright sparks too, weaker:
## SPARKS). Wall boundary: with `clip`, the effect is cut where a ray from its
## centre meets a wall, so a burst at a wall spreads along it instead of
## showing through. Presentation only.

const Glow = preload("res://src/vfx/glow.gd")
const DATA_PATH := "res://assets/data/vfx_sprites.json"
const PIXEL := 2.0
const MAX_LIVE := 220
const RAYS := 28
## 4x4 ordered dither thresholds (0..15), the art grid's (src/vfx/pixel_paint.gd).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## Coverage of the dithered copies of a sheet, densest first.
const DITHER_LEVELS := [0.75, 0.5, 0.25]
## Magic effects: long ease-out, a lingering last frame and a soft glow.
const MAGIC := {"arcane_burst": Color(0.7, 0.55, 1.0), "magic_burst": Color(0.4, 1.0, 0.7), "frost_burst": Color(0.55, 0.9, 1.0),
	"void_burst": Color(0.75, 0.45, 1.0), "fire_burst": Color(1.0, 0.6, 0.25), "poison_burst": Color(0.6, 1.0, 0.35),
	"blink": Color(0.75, 0.6, 1.0), "beam_hit": Color(0.8, 0.95, 1.0), "pickup": Color(1.0, 0.9, 0.5), "level_up": Color(1.0, 0.88, 0.45)}
## Bright non-magic effects that light up the bloom layer too (weaker).
const SPARKS := {"hit_spark": Color(1.0, 0.9, 0.65), "crit_spark": Color(1.0, 0.8, 0.35), "slash_rage": Color(1.0, 0.35, 0.25),
	"whirl": Color(0.9, 0.95, 1.0), "blade_wave": Color(0.75, 0.9, 1.0), "arrow_hit": Color(1.0, 0.9, 0.7)}

## World px per sprite pixel (2 in the crypt, 3 in the story worlds).
var pixel := PIXEL
## Where effects may show: Callable(world point) -> bool, false inside walls (the
## story worlds' floor test); without it the room's floor cells (`set_layout`) are used.
var floor_open := Callable()

var _sheets: Dictionary = {}
var _live: Array[Dictionary] = []
## Walkable floor cells of the room (32 px) for clipping at walls.
var _walkable: Dictionary = {}
## Clip polygons of effects drawn from snapshots (same place, same frame shape).
var _polys: Dictionary = {}
## Dither masks by "w,h,level" (shared by sheets of one size).
static var _masks: Dictionary = {}


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	if not parsed is Dictionary: return
	for name: String in parsed.get("sheets", {}):
		var entry: Dictionary = parsed.sheets[name]
		if not ResourceLoader.exists(str(entry.file)): continue
		_sheets[name] = {"texture": load(str(entry.file)), "size": Vector2(float(entry.size[0]), float(entry.size[1])),
			"frames": int(entry.frames), "fps": float(entry.fps), "anchor": Vector2(float(entry.anchor[0]), float(entry.anchor[1])),
			"fade": 0.4 if MAGIC.has(name) else 0.7, "linger": 0.28 if MAGIC.has(name) else 0.06}


## The room the effects play in: its floor cells bound clipped effects.
func set_layout(layout: Dictionary) -> void:
	_walkable = walkable_cells(layout)
	_polys.clear()


## Sets the floor cells directly (Vector2i, 32 px -> true), for worlds without a
## crypt room layout (the story worlds, src/hero/story_skill_fx.gd).
func set_walkable(cells: Dictionary) -> void:
	_walkable = cells
	_polys.clear()


## Walkable floor cells (Vector2i, 32 px) of a room: floor tiles that are not
## solid and hold no breakable crate or chest. Empty for rooms without painted
## floors (nothing is clipped there).
static func walkable_cells(layout: Dictionary) -> Dictionary:
	var walkable := {}
	var blocked := {}
	for rect: Variant in layout.get("breakable_obstacles", []): blocked[Vector2i(int(rect[0] / 32.0), int(rect[1] / 32.0))] = true
	for entry: Dictionary in layout.get("painted_tiles", []):
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if str(entry.get("layer", "")) == "floor" and not bool(entry.get("solid", false)) and not blocked.has(cell): walkable[cell] = true
	for entry: Dictionary in layout.get("painted_tiles", []):
		if bool(entry.get("solid", false)): walkable.erase(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))
	return walkable


## True when `point` lies on the room's floor (always true without a floor map).
func open(point: Vector2) -> bool:
	if floor_open.is_valid(): return bool(floor_open.call(point))
	return _walkable.is_empty() or _walkable.has(Vector2i(floori(point.x / 32.0), floori(point.y / 32.0)))


## True when walls are known, so effects can be cut at them.
func _can_clip() -> bool:
	return floor_open.is_valid() or not _walkable.is_empty()


## How far light from `point` reaches before a wall along `rays` evenly spaced
## directions (at most `radius` px each); for discs that stop at walls.
func reach(point: Vector2, radius: float, rays: int = RAYS) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(rays)
	for index in range(rays):
		var direction := Vector2.from_angle(TAU * float(index) / float(rays))
		var length := radius
		var travelled := 0.0
		while travelled < radius:
			travelled = minf(radius, travelled + 3.0)
			if not open(point + direction * travelled):
				length = maxf(0.0, travelled - 3.0)
				break
		result[index] = length
	return result


## A filled disc of `radius` around `point` that stops where `limits` (from
## reach) end; a plain circle without limits.
static func clipped_disc(canvas: CanvasItem, point: Vector2, radius: float, limits: PackedFloat32Array, color: Color) -> void:
	if radius < 0.5: return
	if limits.is_empty():
		canvas.draw_circle(point, radius, color)
		return
	var polygon := PackedVector2Array()
	for index in range(limits.size()):
		polygon.append(point + Vector2.from_angle(TAU * float(index) / float(limits.size())) * maxf(0.5, minf(radius, limits[index])))
	canvas.draw_colored_polygon(polygon, color)


## True when the sheet exists (missing files fall back to the old drawings).
func has(name: String) -> bool:
	return _sheets.has(name)


## Frame size of a sheet in art px (Vector2.ZERO when missing).
func frame_size(name: String) -> Vector2:
	return _sheets[name].size if _sheets.has(name) else Vector2.ZERO


## A sheet's scale as a whole number (at least 1): every sprite pixel is a
## whole number of art pixels, never 0.7 or 2.4 of one (no mixed pixel sizes;
## art review, production/qa/evidence/crypt-vfx-review).
static func whole(scale: float) -> float:
	return maxf(1.0, roundf(scale))


## An unturned sheet sits on the art grid (a turned one cannot).
func _on_grid(point: Vector2, rotation: float) -> Vector2:
	return point.snapped(Vector2(pixel, pixel)) if is_zero_approx(fposmod(rotation, TAU)) else point


## Draws the frame of a one-shot sheet at `progress` (0 = first, 1 = last
## frame) without keeping state, for effects whose age comes from a snapshot.
## `fade` 1..0 thins it out by the dither; `clip` cuts it at walls.
func draw_at(canvas: CanvasItem, name: String, point: Vector2, rotation: float, scale: float, progress: float, tint: Color = Color.WHITE, clip: bool = false, fade: float = 1.0) -> void:
	if not _sheets.has(name): return
	scale = whole(scale)
	point = _on_grid(point, rotation)
	var sheet: Dictionary = _sheets[name]
	var frame := clampi(int(progress * float(sheet.frames)), 0, int(sheet.frames) - 1)
	var poly := PackedVector2Array()
	if clip and _can_clip(): poly = _cached_poly(name, sheet, point, rotation, scale)
	tint.a *= fade
	_frame(canvas, sheet, frame, point, rotation, scale, tint, poly)


## The clip polygon of a sheet at a place, kept while the effect stays there.
func _cached_poly(name: String, sheet: Dictionary, point: Vector2, rotation: float, scale: float) -> PackedVector2Array:
	var key := "%s|%d|%d|%.2f|%.0f" % [name, int(point.x), int(point.y), rotation, scale]
	if not _polys.has(key):
		if _polys.size() > 160: _polys.clear()
		_polys[key] = _clip_polygon(sheet, point, rotation, scale)
	return _polys[key]


## Starts a one-shot animation. `scale` multiplies the sprite's pixel size; `clip`
## cuts it at walls.
func spawn(name: String, point: Vector2, rotation: float = 0.0, scale: float = 1.0, tint: Color = Color.WHITE, speed: float = 1.0, clip: bool = false) -> void:
	if not _sheets.has(name): return
	scale = whole(scale)
	point = _on_grid(point, rotation)
	if _live.size() >= MAX_LIVE: _live.pop_front()
	var item := {"name": name, "pos": point, "rot": rotation, "scale": scale, "tint": tint, "time": 0.0, "speed": speed}
	if clip and _can_clip(): item.poly = _clip_polygon(_sheets[name], point, rotation, scale)
	_live.append(item)


func update(delta: float) -> void:
	for index in range(_live.size() - 1, -1, -1):
		var item: Dictionary = _live[index]
		item.time = float(item.time) + delta * float(item.speed)
		var sheet: Dictionary = _sheets[item.name]
		if float(item.time) >= _length(sheet): _live.remove_at(index)


func _length(sheet: Dictionary) -> float:
	return float(sheet.frames) / float(sheet.fps) + float(sheet.linger)


func clear() -> void:
	_live.clear()


func count() -> int:
	return _live.size()


## Draws every running one-shot animation with its dithered ease-out.
func draw(canvas: CanvasItem) -> void:
	for item: Dictionary in _live:
		var sheet: Dictionary = _sheets[item.name]
		var progress := float(item.time) / _length(sheet)
		var frame := mini(int(float(item.time) * float(sheet.fps)), int(sheet.frames) - 1)
		var alpha := 1.0 - smoothstep(float(sheet.fade), 1.0, progress)
		var tint: Color = item.tint
		tint.a *= alpha
		_frame(canvas, sheet, frame, item.pos, float(item.rot), float(item.scale), tint, item.get("poly", PackedVector2Array()))


## Bloom for magic effects and sparks: a soft light that swells and fades with
## the animation (drawn into the additive glow layer, src/vfx/glow.gd).
func draw_glow(canvas: CanvasItem, level: float) -> void:
	if level <= 0.0: return
	for item: Dictionary in _live:
		var color: Color = MAGIC.get(item.name, SPARKS.get(item.name, Color(0, 0, 0, 0)))
		if color.a <= 0.0: continue
		var sheet: Dictionary = _sheets[item.name]
		var progress := float(item.time) / _length(sheet)
		var alpha := 1.0 - smoothstep(float(sheet.fade), 1.0, progress)
		var radius := maxf(float(sheet.size.x), float(sheet.size.y)) * pixel * float(item.scale) * (0.6 + 0.35 * progress)
		# a soft halo in the effect's colour only: no white-hot core over the
		# pixel sprite (art review: the bloom must not burn the shapes away)
		var strength := (0.35 if MAGIC.has(item.name) else 0.16) * alpha * (1.0 - 0.4 * progress)
		Glow.dot(canvas, item.pos, radius * 0.8, Color(color, strength * level))


## Light circles for the dark crypt from running magic effects (Vector4 x, y,
## radius, strength).
func lights() -> Array:
	var result: Array = []
	for item: Dictionary in _live:
		if not MAGIC.has(item.name): continue
		var sheet: Dictionary = _sheets[item.name]
		var progress := float(item.time) / _length(sheet)
		if progress > 0.8: continue
		result.append(Vector4(item.pos.x, item.pos.y, maxf(float(sheet.size.x), float(sheet.size.y)) * pixel * float(item.scale) * 1.1, 0.9 * (1.0 - progress)))
	return result


## Draws a looping sheet at `clock` (seconds), e.g. a flying orb. With `clip`,
## a sheet that reaches a wall is cut there (a fireball grazing a wall never
## shows on its far side).
func draw_loop(canvas: CanvasItem, name: String, point: Vector2, rotation: float, scale: float, clock: float, tint: Color = Color.WHITE, clip: bool = false) -> void:
	if not _sheets.has(name): return
	scale = whole(scale)
	point = _on_grid(point, rotation)
	var sheet: Dictionary = _sheets[name]
	var poly := PackedVector2Array()
	if clip and _near_wall(point, maxf(float(sheet.size.x), float(sheet.size.y)) * pixel * scale * 0.5): poly = _clip_polygon(sheet, point, rotation, scale)
	_frame(canvas, sheet, int(clock * float(sheet.fps)) % int(sheet.frames), point, rotation, scale, tint, poly)


## True when a wall lies within `radius` of `point` (cheap pre-check).
func _near_wall(point: Vector2, radius: float) -> bool:
	if floor_open.is_valid():
		for index in range(8):
			if not open(point + Vector2.from_angle(TAU * float(index) / 8.0) * radius): return true
		return not open(point)
	if _walkable.is_empty(): return false
	var low := Vector2i(floori((point.x - radius) / 32.0), floori((point.y - radius) / 32.0))
	var high := Vector2i(floori((point.x + radius) / 32.0), floori((point.y + radius) / 32.0))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if not _walkable.has(Vector2i(x, y)): return true
	return false


func _frame(canvas: CanvasItem, sheet: Dictionary, frame: int, point: Vector2, rotation: float, scale: float, tint: Color, poly: PackedVector2Array) -> void:
	# a faded frame drops whole sprite pixels by the dither instead of turning see-through
	var texture: Texture2D = sheet.texture
	if tint.a < 0.999:
		texture = _dithered(sheet, tint.a)
		if texture == null: return
		tint.a = 1.0
	var size: Vector2 = sheet.size
	var anchor: Vector2 = sheet.anchor
	if poly.is_empty():
		canvas.draw_set_transform(point, rotation, Vector2(pixel * scale, pixel * scale))
		canvas.draw_texture_rect_region(texture, Rect2(-anchor, size), Rect2(Vector2(frame * size.x, 0), size), tint)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# Clipped: the frame drawn as a textured polygon that stops at the walls.
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	var uvs := PackedVector2Array()
	for local: Vector2 in poly: uvs.append((Vector2(frame * size.x, 0) + local) / texture_size)
	var colors := PackedColorArray()
	colors.resize(poly.size())
	colors.fill(tint)
	canvas.draw_polygon(_to_world(poly, sheet, point, rotation, scale), colors, uvs, texture)


## The sheet thinned to `visible` (0..1) by the ordered dither: the full sheet
## near 1, a copy keeping 75 / 50 / 25 % of its pixels below, null near 0. The
## copies are made once per sheet on first use; without image data (a server
## without a renderer) the plain sheet is kept.
func _dithered(sheet: Dictionary, visible: float) -> Texture2D:
	if visible >= 0.875: return sheet.texture
	if visible < 0.125: return null
	var level := 0 if visible >= 0.625 else (1 if visible >= 0.375 else 2)
	if not sheet.has("dither"):
		sheet.dither = []
		var image: Image = sheet.texture.get_image()
		if image != null:
			if image.is_compressed(): image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			for k: float in DITHER_LEVELS:
				var out := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
				out.blit_rect_mask(image, _mask(image.get_width(), image.get_height(), k), Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
				sheet.dither.append(ImageTexture.create_from_image(out))
	var copies: Array = sheet.dither
	return copies[level] if level < copies.size() else sheet.texture


## A w x h mask of the 4x4 ordered dither at coverage `k` (opaque where a pixel
## stays), built by doubling one tile.
static func _mask(w: int, h: int, k: float) -> Image:
	var key := "%d,%d,%.2f" % [w, h, k]
	if _masks.has(key): return _masks[key]
	var mask := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(mini(4, h)):
		for x in range(mini(4, w)):
			if float(BAYER[y * 4 + x]) < k * 16.0: mask.set_pixel(x, y, Color.WHITE)
	var filled := 4
	while filled < w:
		mask.blit_rect(mask.get_region(Rect2i(0, 0, filled, mini(4, h))), Rect2i(0, 0, filled, mini(4, h)), Vector2i(filled, 0))
		filled *= 2
	filled = 4
	while filled < h:
		mask.blit_rect(mask.get_region(Rect2i(0, 0, w, filled)), Rect2i(0, 0, w, filled), Vector2i(0, filled))
		filled *= 2
	_masks[key] = mask
	return mask


func _to_world(poly: PackedVector2Array, sheet: Dictionary, point: Vector2, rotation: float, scale: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for local: Vector2 in poly: result.append(point + ((local - Vector2(sheet.anchor)) * pixel * scale).rotated(rotation))
	return result


## The part of the frame (in its own art pixels) a viewer at the effect's centre
## can see: rays from the anchor stop at the frame edge or at the first wall.
## Empty when no ray meets a wall (draw the whole frame).
func _clip_polygon(sheet: Dictionary, point: Vector2, rotation: float, scale: float) -> PackedVector2Array:
	var size: Vector2 = sheet.size
	var anchor: Vector2 = sheet.anchor
	if not open(point): return PackedVector2Array()
	var result := PackedVector2Array()
	var clipped := false
	for index in range(RAYS):
		var direction := Vector2.from_angle(TAU * float(index) / float(RAYS))
		# Distance from the anchor to the frame's edge along this ray.
		var reach := INF
		if direction.x > 0.001: reach = minf(reach, (size.x - anchor.x) / direction.x)
		elif direction.x < -0.001: reach = minf(reach, -anchor.x / direction.x)
		if direction.y > 0.001: reach = minf(reach, (size.y - anchor.y) / direction.y)
		elif direction.y < -0.001: reach = minf(reach, -anchor.y / direction.y)
		var world_step := direction.rotated(rotation) * pixel * scale
		var length := reach
		var travelled := 0.0
		while travelled < reach:
			travelled = minf(reach, travelled + 3.0 / (pixel * scale))
			if not open(point + world_step * travelled):
				length = maxf(0.5, travelled - 3.0 / (pixel * scale))
				clipped = true
				break
		result.append(anchor + direction * length)
	return result if clipped else PackedVector2Array()
