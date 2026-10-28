extends Node2D
## Additive light layer over the dark crypt: the bloom of spells, projectiles,
## the Photoneneis beam, torches, EXP orbs and glowing particles. It draws
## above the darkness with BLEND_MODE_ADD, so bright effects bleed light into
## their surroundings (the gl_compatibility renderer has no dependable 2D glow
## post-process). The dungeon view fills it through `source` every frame.
## Strengths come from assets/data/vfx_glow.json. Presentation only.

const DATA_PATH := "res://assets/data/vfx_glow.json"
const SIZE := 64
## Gaussian falloff: exp(-FALLOFF * d^2) with d = 0 at the centre, 1 at the rim.
const FALLOFF := 4.5

## Callable(canvas: CanvasItem) that draws this frame's lights.
var source: Callable
## False when vfx_glow.json switches the bloom off (the view keeps it hidden).
var enabled := true
## Overall intensity (vfx_glow.json "strength").
var strength := 1.0
## Per-source multipliers from vfx_glow.json ("beam", "bullets", ...).
var scales: Dictionary = {}

static var _dot: Texture2D
static var _band: Texture2D


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var data := load_data()
	strength = float(data.get("strength", 1.0))
	scales = data.get("scales", {})
	enabled = bool(data.get("enabled", true))


## vfx_glow.json as a Dictionary ({} when missing or broken).
static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	return parsed if parsed is Dictionary else {}


## Intensity for one source ("beam", "bullets", "spells", "torches", "orbs",
## "particles", "void"): the overall strength times its own scale.
func level(kind: String) -> float:
	return strength * float(scales.get(kind, 1.0))


func _draw() -> void:
	if source.is_valid(): source.call(self)


## A soft round light of `radius` px; the colour's alpha is its intensity.
static func dot(canvas: CanvasItem, point: Vector2, radius: float, color: Color) -> void:
	if radius < 1.0 or color.a <= 0.003: return
	canvas.draw_texture_rect(dot_texture(), Rect2(point - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


## A soft band of light from `from` to `to`, `width` px across (no end caps).
static func line(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 1.0 or width < 1.0 or color.a <= 0.003: return
	canvas.draw_set_transform(from, (to - from).angle(), Vector2.ONE)
	canvas.draw_texture_rect(band_texture(), Rect2(0.0, -width * 0.5, length, width), false, color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## White radial falloff, built once.
static func dot_texture() -> Texture2D:
	if _dot == null:
		var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		for y in range(SIZE):
			for x in range(SIZE):
				var d := Vector2(x + 0.5 - SIZE * 0.5, y + 0.5 - SIZE * 0.5).length() / (SIZE * 0.5)
				image.set_pixel(x, y, Color(1, 1, 1, _falloff(d)))
		_dot = ImageTexture.create_from_image(image)
	return _dot


## White falloff across a band (one column, stretched along the light).
static func band_texture() -> Texture2D:
	if _band == null:
		var image := Image.create_empty(1, SIZE, false, Image.FORMAT_RGBA8)
		for y in range(SIZE):
			image.set_pixel(0, y, Color(1, 1, 1, _falloff(absf(y + 0.5 - SIZE * 0.5) / (SIZE * 0.5))))
		_band = ImageTexture.create_from_image(image)
	return _band


static func _falloff(d: float) -> float:
	if d >= 1.0: return 0.0
	var rim := exp(-FALLOFF)
	return clampf((exp(-FALLOFF * d * d) - rim) / (1.0 - rim), 0.0, 1.0)
