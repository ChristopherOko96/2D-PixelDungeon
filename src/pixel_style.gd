@tool
extends RefCounted
## Shared native8px typography. UI16/24/32 render the pixel grid at2x/3x/4x.
## The locally bundled face includes German text; no installed font is needed.
const FACE: FontFile = preload("res://assets/fonts/pixel_operator8.ttf")
const BASE_SIZE := 8
const BODY_SIZE := 16
const HEADING_SIZE := 24
const TITLE_SIZE := 32
static var _font: FontFile

## Returns the proportional pixel font with crisp integer-positioned outlines.
## Use multiples of BASE_SIZE; display scaling is owned by the root viewport.
static func create_font() -> Font:
	if _font == null:
		_font = FACE.duplicate()
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
