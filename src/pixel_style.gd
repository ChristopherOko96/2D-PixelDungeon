@tool
extends RefCounted
## Shared native8px typography. UI16/24/32 render the pixel grid at2x/3x/4x.
## The locally bundled face includes German text; no installed font is needed.
const FACE: FontFile = preload("res://assets/fonts/pixel_operator8.ttf")
const BASE_SIZE := 8
const BODY_SIZE := 16
const HEADING_SIZE := 24
const TITLE_SIZE := 32
const UmlautCaps = preload("res://src/ui/umlaut_caps.gd")
static var _font: FontFile


# The face's capital umlauts are short (Ä looks like ä). At runtime the shared
# face itself is patched once, so every preload of it (HUD, menus) draws them
# as full capitals; the editor keeps its imported resource untouched.
static func _static_init() -> void:
	if not Engine.is_editor_hint():
		_patch_umlauts(FACE)


## Returns the proportional pixel font with crisp integer-positioned outlines.
## Use multiples of BASE_SIZE; display scaling is owned by the root viewport.
static func create_font() -> Font:
	if _font == null:
		_font = FACE.duplicate()
		if Engine.is_editor_hint():
			_patch_umlauts(_font)
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.multichannel_signed_distance_field = false
		_font.oversampling = 1.0
		_font.allow_system_fallback = false
	return _font

## Uses the same face for controls, dialogs and text drawn directly on a canvas.
static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = create_font()
	theme.default_font_size = BODY_SIZE
	return theme


## True once `font` draws Ä Ö Ü as full capitals (taller than the plain capital).
static func has_tall_umlauts(font: Font) -> bool:
	var file := font as FontFile
	if file == null:
		return false
	var plain := file.get_glyph_size(0, Vector2i(BASE_SIZE, 0), file.get_glyph_index(BASE_SIZE, "U".unicode_at(0), 0))
	var umlaut := file.get_glyph_size(0, Vector2i(BASE_SIZE, 0), file.get_glyph_index(BASE_SIZE, "Ü".unicode_at(0), 0))
	return umlaut.y > plain.y


# Glyph lookups run on a scratch copy: a face that already built size caches
# does not take new bytes cleanly, so `font` itself only receives the result.
static func _patch_umlauts(font: FontFile) -> void:
	var before: PackedByteArray = font.data
	var scratch := FontFile.new()
	scratch.data = before
	var after := UmlautCaps.patch(before, func(code: int) -> int: return scratch.get_glyph_index(BASE_SIZE, code, 0))
	if after.size() != before.size() or after != before:
		font.data = after
		font.clear_cache()
