extends RefCounted
## Void atmosphere of the Krypta der Verdammten (story 1, the live crypt run):
## a colour filter on the room (darker, more contrast, violet shadows), a
## faint violet fog drifting through the rooms, and torches, candle columns
## and floor fires burning in the 0x72 violet ramp with violet light.
## Values come from assets/data/vfx_crypt_atmosphere.json (schema in
## docs/KRYPTA-ATMOSPHAERE.de.md). The dungeon view owns the nodes; this file
## loads and checks the data, repaints flame frames and builds the materials.
## Presentation only: every client draws it for itself, no game rules.

const DATA_PATH := "res://assets/data/vfx_crypt_atmosphere.json"
const GRADE_SHADER := preload("res://assets/shaders/canvas_vfx_crypt_grade.gdshader")
const FOG_SHADER := preload("res://assets/shaders/canvas_vfx_crypt_fog.gdshader")
const MAX_FOG_LAYERS := 3
## The 0x72 violet ramp (DungeonTileset II): the only colours flames may take.
const VIOLET_RAMP := ["473579", "5f2d56", "8156aa", "993970", "c278d0", "f0b3dd", "fdf7ed"]

## Used for every key the file leaves out (and for a missing or broken file).
const DEFAULTS := {
	"enabled": true,
	"grade": {"enabled": true, "exposure": 0.8, "highlight_from": 0.55, "highlight_to": 0.9, "contrast": 1.14, "pivot": 0.32,
		"saturation": 0.82, "tint_color": "#473579", "tint_strength": 0.55, "tint_range": 0.5},
	"darkness": {"strength": 0.32, "shade_color": "#0d0818"},
	"fog": {"enabled": true, "over_actors": false, "color": "#8156aa", "density": 0.2, "coverage": 0.5, "softness": 0.16,
		"stretch": 2.6, "warp": 0.9, "pixel": 2.0, "bands": 4,
		"layers": [{"scale": 210.0, "wind": [9.0, 2.5], "weight": 0.6}, {"scale": 120.0, "wind": [-6.0, 1.5], "weight": 0.4}]},
	"flames": {"enabled": true, "floor_fires": true,
		"recolor": {"da4e38": "8156aa", "c56025": "8156aa", "8f4029": "5f2d56", "ee8e2e": "c278d0", "facb3e": "f0b3dd", "fdf7ed": "fdf7ed"},
		"light_color": "#c278d0", "glow_strength": 0.26, "light_radius_scale": 0.85},
}

## Allowed range per number: [min, max]. Values outside are clamped.
const RANGES := {
	"grade": {"exposure": [0.0, 1.5], "highlight_from": [0.0, 1.0], "highlight_to": [0.0, 1.0], "contrast": [0.5, 2.0], "pivot": [0.0, 1.0],
		"saturation": [0.0, 2.0], "tint_strength": [0.0, 1.0], "tint_range": [0.01, 1.0]},
	"darkness": {"strength": [0.0, 1.0]},
	"fog": {"density": [0.0, 1.0], "coverage": [0.0, 1.0], "softness": [0.01, 1.0], "stretch": [0.5, 6.0], "warp": [0.0, 3.0],
		"pixel": [1.0, 8.0], "bands": [1.0, 16.0]},
	"flames": {"glow_strength": [0.0, 1.0], "light_radius_scale": [0.0, 2.0]},
}

## Repainted flame frames by source path and colour map (built once per run).
static var _flame_cache: Dictionary = {}


## vfx_crypt_atmosphere.json, checked and typed (see `parse`). A missing or
## broken file gives the defaults.
static func load_data(path: String = DATA_PATH) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not raw is Dictionary: push_warning("Crypt atmosphere: %s missing or not a JSON object, using defaults." % path)
	return parse(raw if raw is Dictionary else {})


## Pure: lays `raw` over DEFAULTS, clamps numbers to RANGES and turns colours
## into Color. Fog layers become Vector4(scale, wind x, wind y, weight), at most
## MAX_FOG_LAYERS. Flame recolor keeps only 0x72 source colours mapped onto
## VIOLET_RAMP colours (lowercase "rrggbb" -> Color); anything else is dropped.
static func parse(raw: Dictionary) -> Dictionary:
	var result := {"enabled": bool(raw.get("enabled", DEFAULTS.enabled))}
	for section: String in ["grade", "darkness", "fog", "flames"]:
		var given: Variant = raw.get(section, {})
		var source: Dictionary = given if given is Dictionary else {}
		var out: Dictionary = {}
		for key: String in DEFAULTS[section]:
			var fallback: Variant = DEFAULTS[section][key]
			var value: Variant = source.get(key, fallback)
			if fallback is bool: out[key] = bool(value) if value is bool else fallback
			elif fallback is float or fallback is int:
				var number := float(value) if (value is float or value is int) else float(fallback)
				var limits: Array = RANGES.get(section, {}).get(key, [-INF, INF])
				out[key] = clampf(number, float(limits[0]), float(limits[1]))
			elif fallback is String: out[key] = _color(value, Color(str(fallback)))
			else: out[key] = value
		result[section] = out
	result.fog.layers = _fog_layers(result.fog.layers)
	result.flames.recolor = _recolor_map(result.flames.recolor)
	return result


## `lighting` (balance.json "lighting") with the atmosphere's darkness strength
## and shade colour, for the dark crypt overlay while the atmosphere is on.
static func lighting_with_darkness(lighting: Dictionary, data: Dictionary) -> Dictionary:
	var merged := lighting.duplicate()
	var darkness: Dictionary = data.get("darkness", {})
	if darkness.has("strength"): merged.darkness = float(darkness.strength)
	if darkness.has("shade_color"): merged.shade_color = darkness.shade_color
	return merged


## Material for the room layer from the parsed "grade" section.
static func grade_material(grade: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRADE_SHADER
	for key: String in ["exposure", "highlight_from", "highlight_to", "contrast", "pivot", "saturation", "tint_color", "tint_strength", "tint_range"]:
		if grade.has(key): material.set_shader_parameter(key, grade[key])
	return material


## Copy of `image` with every colour in `mapping` ("rrggbb" -> Color) swapped,
## alpha kept. Pixel positions never change, so the 0x72 shapes stay exact.
static func recolor(image: Image, mapping: Dictionary) -> Image:
	var out := image.duplicate() as Image
	if out.is_compressed(): out.decompress()
	out.convert(Image.FORMAT_RGBA8)
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var pixel := out.get_pixel(x, y)
			if pixel.a <= 0.0: continue
			var key := pixel.to_html(false)
			if mapping.has(key): out.set_pixel(x, y, Color(mapping[key], pixel.a))
	return out


## The flame frame at `path` repainted with `mapping` (cached).
static func flame_texture(path: String, mapping: Dictionary) -> Texture2D:
	var key := "%s|%s" % [path, str(mapping)]
	if not _flame_cache.has(key):
		var source: Texture2D = load(path)
		_flame_cache[key] = ImageTexture.create_from_image(recolor(source.get_image(), mapping))
	return _flame_cache[key]


static func _color(value: Variant, fallback: Color) -> Color:
	if value is String:
		var text := str(value).trim_prefix("#")
		if text.is_valid_html_color(): return Color(text)
	return fallback


static func _fog_layers(value: Variant) -> Array[Vector4]:
	var layers: Array[Vector4] = []
	if value is Array:
		for entry: Variant in value:
			if layers.size() >= MAX_FOG_LAYERS: break
			if not entry is Dictionary: continue
			var wind: Variant = entry.get("wind", [0.0, 0.0])
			var wind_ok: bool = wind is Array and wind.size() == 2 and (wind[0] is float or wind[0] is int) and (wind[1] is float or wind[1] is int)
			var scale_value: Variant = entry.get("scale", 160.0)
			var weight_value: Variant = entry.get("weight", 1.0)
			layers.append(Vector4(clampf(float(scale_value) if (scale_value is float or scale_value is int) else 160.0, 16.0, 2048.0),
				float(wind[0]) if wind_ok else 0.0, float(wind[1]) if wind_ok else 0.0,
				clampf(float(weight_value) if (weight_value is float or weight_value is int) else 1.0, 0.0, 1.0)))
	return layers


static func _recolor_map(value: Variant) -> Dictionary:
	var mapping: Dictionary = {}
	if not value is Dictionary: return mapping
	for from: Variant in value:
		var source := str(from).trim_prefix("#").to_lower()
		var target := str(value[from]).trim_prefix("#").to_lower()
		if not source.is_valid_html_color() or source.length() != 6: continue
		if not target in VIOLET_RAMP:
			push_warning("Crypt atmosphere: flame colour %s is not in the 0x72 violet ramp, ignored." % target)
			continue
		mapping[source] = Color(target)
	return mapping


## Draws behind its parent (show_behind_parent) through `source`, so the
## room can carry the grade material while actors keep their own colours.
class RoomLayer extends Node2D:
	## Callable(canvas: CanvasItem) that draws the room.
	var source: Callable

	func _draw() -> void:
		if source.is_valid(): source.call(self)


## The fog: one rectangle over the room with the fog shader.
class CryptFog extends Node2D:
	var _material := ShaderMaterial.new()
	var _size := Vector2.ZERO

	func _init() -> void:
		_material.shader = FOG_SHADER
		material = _material
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	## Look and layers from the parsed "fog" section.
	func configure(fog: Dictionary) -> void:
		for key: String in ["density", "coverage", "softness", "stretch", "warp", "pixel", "bands"]:
			_material.set_shader_parameter(key, float(fog.get(key, 0.0)))
		_material.set_shader_parameter("fog_color", fog.get("color", Color.WHITE))
		var layers: Array[Vector4] = []
		layers.assign(fog.get("layers", []))
		var count := mini(layers.size(), MAX_FOG_LAYERS)
		while layers.size() < MAX_FOG_LAYERS: layers.append(Vector4.ZERO)
		_material.set_shader_parameter("layers", layers.slice(0, MAX_FOG_LAYERS))
		_material.set_shader_parameter("layer_count", count)

	## Room size in world px; the fog covers exactly the room.
	func set_world_size(size: Vector2) -> void:
		if size == _size: return
		_size = size
		queue_redraw()

	## The view's clock (seconds), so a frozen view freezes the fog.
	func set_clock(seconds: float) -> void:
		_material.set_shader_parameter("clock", seconds)

	func _draw() -> void:
		if _size.x > 0.0 and _size.y > 0.0: draw_rect(Rect2(Vector2.ZERO, _size), Color.WHITE)
