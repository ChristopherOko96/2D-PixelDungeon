extends RefCounted
## Plays the pixel-art effect animations (assets/sprites/fx, made by
## scripts/make_fx_sprites.gd; frame data in assets/data/vfx_sprites.json).
## `spawn` starts a one-shot animation at a world point (rotated, scaled,
## tinted); `draw_loop` draws a looping sheet for things that persist (orbs,
## fireballs, auras). Everything is drawn at 2x like the 0x72 art.
##
## Fade-outs: every animation eases out instead of stopping; magic lingers on
## its last frame for a moment and lights up the bloom layer (MAGIC; bright
## sparks too, weaker: SPARKS). Wall boundary: with `clip`, the effect is cut
## where a ray from its centre meets a wall, so a burst at a wall spreads along
## it instead of showing through. Presentation only.

const Glow = preload("res://src/vfx/glow.gd")
const DATA_PATH := "res://assets/data/vfx_sprites.json"
const PIXEL := 2.0
const MAX_LIVE := 220
const RAYS := 28
## Magic effects: long ease-out, a lingering last frame and a soft glow.
const MAGIC := {"arcane_burst": Color(0.7, 0.55, 1.0), "magic_burst": Color(0.4, 1.0, 0.7), "frost_burst": Color(0.55, 0.9, 1.0),
	"void_burst": Color(0.75, 0.45, 1.0), "fire_burst": Color(1.0, 0.6, 0.25), "poison_burst": Color(0.6, 1.0, 0.35),
	"blink": Color(0.75, 0.6, 1.0), "beam_hit": Color(0.8, 0.95, 1.0), "pickup": Color(1.0, 0.9, 0.5), "level_up": Color(1.0, 0.88, 0.45)}
## Bright non-magic effects that light up the bloom layer too (weaker).
const SPARKS := {"hit_spark": Color(1.0, 0.9, 0.65), "crit_spark": Color(1.0, 0.8, 0.35), "slash_rage": Color(1.0, 0.35, 0.25),
	"whirl": Color(0.9, 0.95, 1.0), "blade_wave": Color(0.75, 0.9, 1.0), "arrow_hit": Color(1.0, 0.9, 0.7)}

var _sheets: Dictionary = {}
var _live: Array[Dictionary] = []
## Walkable floor cells of the room (32 px) for clipping at walls.
var _walkable: Dictionary = {}


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
	return _walkable.is_empty() or _walkable.has(Vector2i(floori(point.x / 32.0), floori(point.y / 32.0)))


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


## Starts a one-shot animation. `scale` multiplies the 2x pixel size; `clip`
## cuts it at walls.
func spawn(name: String, point: Vector2, rotation: float = 0.0, scale: float = 1.0, tint: Color = Color.WHITE, speed: float = 1.0, clip: bool = false) -> void:
	if not _sheets.has(name): return
	if _live.size() >= MAX_LIVE: _live.pop_front()
	var item := {"name": name, "pos": point, "rot": rotation, "scale": scale, "tint": tint, "time": 0.0, "speed": speed}
	if clip and not _walkable.is_empty(): item.poly = _clip_polygon(_sheets[name], point, rotation, scale)
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


## Draws every running one-shot animation with its ease-out.
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
		var radius := maxf(float(sheet.size.x), float(sheet.size.y)) * PIXEL * float(item.scale) * (0.6 + 0.35 * progress)
		var strength := (0.55 if MAGIC.has(item.name) else 0.3) * alpha * (1.0 - 0.4 * progress)
		Glow.dot(canvas, item.pos, radius, Color(color, strength * level))
		Glow.dot(canvas, item.pos, radius * 0.4, Color(color.lightened(0.4), strength * 0.8 * level))


## Light circles for the dark crypt from running magic effects (Vector4 x, y,
## radius, strength).
func lights() -> Array:
	var result: Array = []
	for item: Dictionary in _live:
		if not MAGIC.has(item.name): continue
		var sheet: Dictionary = _sheets[item.name]
		var progress := float(item.time) / _length(sheet)
		if progress > 0.8: continue
		result.append(Vector4(item.pos.x, item.pos.y, maxf(float(sheet.size.x), float(sheet.size.y)) * PIXEL * float(item.scale) * 1.1, 0.9 * (1.0 - progress)))
	return result


## Draws a looping sheet at `clock` (seconds), e.g. a flying orb. With `clip`,
## a sheet that reaches a wall is cut there (a fireball grazing a wall never
## shows on its far side).
func draw_loop(canvas: CanvasItem, name: String, point: Vector2, rotation: float, scale: float, clock: float, tint: Color = Color.WHITE, clip: bool = false) -> void:
	if not _sheets.has(name): return
	var sheet: Dictionary = _sheets[name]
	var poly := PackedVector2Array()
	if clip and _near_wall(point, maxf(float(sheet.size.x), float(sheet.size.y)) * PIXEL * scale * 0.5): poly = _clip_polygon(sheet, point, rotation, scale)
	_frame(canvas, sheet, int(clock * float(sheet.fps)) % int(sheet.frames), point, rotation, scale, tint, poly)


## True when a wall cell lies within `radius` of `point` (cheap pre-check).
func _near_wall(point: Vector2, radius: float) -> bool:
	if _walkable.is_empty(): return false
	var low := Vector2i(floori((point.x - radius) / 32.0), floori((point.y - radius) / 32.0))
	var high := Vector2i(floori((point.x + radius) / 32.0), floori((point.y + radius) / 32.0))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if not _walkable.has(Vector2i(x, y)): return true
	return false


func _frame(canvas: CanvasItem, sheet: Dictionary, frame: int, point: Vector2, rotation: float, scale: float, tint: Color, poly: PackedVector2Array) -> void:
	var size: Vector2 = sheet.size
	var anchor: Vector2 = sheet.anchor
	if poly.is_empty():
		canvas.draw_set_transform(point, rotation, Vector2(PIXEL * scale, PIXEL * scale))
		canvas.draw_texture_rect_region(sheet.texture, Rect2(-anchor, size), Rect2(Vector2(frame * size.x, 0), size), tint)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# Clipped: the frame drawn as a textured polygon that stops at the walls.
	var texture_size := Vector2(sheet.texture.get_width(), sheet.texture.get_height())
	var uvs := PackedVector2Array()
	for local: Vector2 in poly: uvs.append((Vector2(frame * size.x, 0) + local) / texture_size)
	var colors := PackedColorArray()
	colors.resize(poly.size())
	colors.fill(tint)
	canvas.draw_polygon(_to_world(poly, sheet, point, rotation, scale), colors, uvs, sheet.texture)


func _to_world(poly: PackedVector2Array, sheet: Dictionary, point: Vector2, rotation: float, scale: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for local: Vector2 in poly: result.append(point + ((local - Vector2(sheet.anchor)) * PIXEL * scale).rotated(rotation))
	return result


## The part of the frame (in its own art pixels) a viewer at the effect's centre
## can see: rays from the anchor stop at the frame edge or at the first wall.
## Empty when no ray meets a wall (draw the whole frame).
func _clip_polygon(sheet: Dictionary, point: Vector2, rotation: float, scale: float) -> PackedVector2Array:
	var size: Vector2 = sheet.size
	var anchor: Vector2 = sheet.anchor
	if not _walkable.has(Vector2i(int(floor(point.x / 32.0)), int(floor(point.y / 32.0)))): return PackedVector2Array()
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
		var world_step := direction.rotated(rotation) * PIXEL * scale
		var length := reach
		var travelled := 0.0
		while travelled < reach:
			travelled = minf(reach, travelled + 3.0 / (PIXEL * scale))
			var sample: Vector2 = point + world_step * travelled
			if not _walkable.has(Vector2i(int(floor(sample.x / 32.0)), int(floor(sample.y / 32.0)))):
				length = maxf(0.5, travelled - 3.0 / (PIXEL * scale))
				clipped = true
				break
		result.append(anchor + direction * length)
	return result if clipped else PackedVector2Array()
