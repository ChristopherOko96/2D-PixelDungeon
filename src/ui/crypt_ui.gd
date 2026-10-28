extends RefCounted
## Delve Disaster's shared look: the 0x72 crypt palette, bevelled pixel frames
## and one Theme for every menu, panel, field and HUD frame. The 0x72 pack has
## no panel art, so the frames are drawn here from its palette in 2 px pixels.

const PixelStyle = preload("res://src/pixel_style.gd")

## Game name shown on the title, lobby and window.
const GAME_TITLE := "DELVE DISASTER"

# 0x72 palette (sampled from the tileset) plus two UI accents.
const INK := Color("1a1414")
const SHADOW := Color("2a2020")
const STONE_DARK := Color("342a29")
const STONE := Color("483b3a")
const STONE_LIGHT := Color("775c55")
const SAND := Color("aa8d7a")
const BONE := Color("d3bfa9")
const CREAM := Color("fdf7ed")
const BLOOD := Color("da4e38")
const BLOOD_DARK := Color("7a2a24")
const GOLD := Color("edbf75")
const MUTED := Color("9c8a7e")
const DISABLED := Color("6d625d")
const VOID := Color("b06ad8")
const FROST := Color("8fd8e6")

## One art pixel of a frame in screen pixels (matches the 2x world scale).
const PX := 2

static var _theme: Theme
static var _boxes: Dictionary = {}


## The shared Theme: Pixel Operator 8 plus crypt frames for Button, Panel,
## LineEdit, sliders, progress bars and tooltips. Cached per process.
static func create_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme := PixelStyle.create_theme()
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type, box("button"))
		theme.set_stylebox("hover", type, box("button_hover"))
		theme.set_stylebox("pressed", type, box("button_pressed"))
		theme.set_stylebox("hover_pressed", type, box("button_pressed"))
		theme.set_stylebox("disabled", type, box("button_disabled"))
		theme.set_stylebox("focus", type, box("focus"))
		theme.set_color("font_color", type, BONE)
		theme.set_color("font_hover_color", type, CREAM)
		theme.set_color("font_pressed_color", type, GOLD)
		theme.set_color("font_hover_pressed_color", type, GOLD)
		theme.set_color("font_focus_color", type, CREAM)
		theme.set_color("font_disabled_color", type, DISABLED)
		theme.set_color("font_outline_color", type, INK)
		theme.set_constant("outline_size", type, 0)
	# Check buttons stay frameless rows; only the focus ring and colours apply.
	for type: String in ["CheckButton", "CheckBox"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, type, box("row_hover") if state.begins_with("hover") else box("row"))
		theme.set_stylebox("focus", type, box("focus"))
		theme.set_color("font_color", type, BONE)
		theme.set_color("font_hover_color", type, CREAM)
		theme.set_color("font_pressed_color", type, BONE)
		theme.set_color("font_hover_pressed_color", type, CREAM)
		theme.set_color("font_focus_color", type, CREAM)
	for type: String in ["Panel", "PanelContainer"]:
		theme.set_stylebox("panel", type, box("panel"))
	theme.set_stylebox("panel", "TooltipPanel", box("inset"))
	theme.set_color("font_color", "TooltipLabel", BONE)
	theme.set_stylebox("normal", "LineEdit", box("field"))
	theme.set_stylebox("focus", "LineEdit", box("focus"))
	theme.set_stylebox("read_only", "LineEdit", box("inset"))
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("selection_color", "LineEdit", Color(STONE_LIGHT, 0.8))
	theme.set_color("font_color", "Label", BONE)
	theme.set_stylebox("slider", "HSlider", box("inset"))
	theme.set_stylebox("grabber_area", "HSlider", _flat(SAND, Color.TRANSPARENT, 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(GOLD, Color.TRANSPARENT, 0))
	theme.set_stylebox("background", "ProgressBar", box("inset"))
	theme.set_stylebox("fill", "ProgressBar", _flat(BLOOD, Color.TRANSPARENT, 0))
	_theme = theme
	return theme


## A named frame: panel, inset, field, button, button_hover, button_pressed,
## button_disabled, focus, row, row_hover, slot, slot_ready. Cached.
static func box(kind: String) -> StyleBox:
	if _boxes.has(kind):
		return _boxes[kind]
	var style: StyleBox
	match kind:
		"panel": style = _bevel(Color(0.13, 0.10, 0.10, 0.94), STONE_LIGHT, SHADOW, 2, Vector4(16, 14, 16, 14))
		"inset": style = _bevel(Color(0.08, 0.06, 0.06, 0.92), SHADOW, STONE, 1, Vector4(10, 8, 10, 8))
		"field": style = _bevel(Color(0.08, 0.06, 0.06, 0.95), SHADOW, STONE_LIGHT, 1, Vector4(10, 6, 10, 6))
		"button": style = _bevel(STONE, STONE_LIGHT, STONE_DARK, 1, Vector4(12, 6, 12, 8), 2)
		"button_hover": style = _bevel(STONE_LIGHT, SAND, STONE, 1, Vector4(12, 6, 12, 8), 2)
		"button_pressed": style = _bevel(STONE_DARK, SHADOW, STONE, 1, Vector4(12, 8, 12, 6))
		"button_disabled": style = _bevel(Color(0.16, 0.13, 0.13, 0.9), STONE_DARK, SHADOW, 1, Vector4(12, 6, 12, 8))
		"focus":
			var ring := _flat(Color.TRANSPARENT, GOLD, PX)
			ring.draw_center = false
			ring.set_expand_margin_all(PX)
			style = ring
		"row":
			var row := StyleBoxEmpty.new()
			row.set_content_margin_all(6)
			style = row
		"row_hover": style = _flat(Color(STONE, 0.6), Color.TRANSPARENT, 0, 6)
		"slot": style = _bevel(Color(0.10, 0.08, 0.08, 0.92), SHADOW, STONE, 1, Vector4(4, 4, 4, 4))
		"slot_ready": style = _bevel(Color(0.18, 0.14, 0.12, 0.95), SAND, STONE_DARK, 1, Vector4(4, 4, 4, 4))
		_: style = StyleBoxEmpty.new()
	_boxes[kind] = style
	return style


## A heading label (gold, 24 or 32 px) with a dark outline for busy backdrops.
static func heading(text: String, font_size: int = PixelStyle.HEADING_SIZE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Draws a named frame onto any CanvasItem (HUD panels drawn in _draw).
static func draw_box(canvas: CanvasItem, kind: String, rect: Rect2) -> void:
	box(kind).draw(canvas.get_canvas_item(), rect)


# Bevelled frame as a 9-slice texture: a 1-art-pixel ink outline, `depth` art
# pixels of light on the top/left and shade on the bottom/right, then the fill.
# `drop` adds that many art pixels of extra shade below (a raised button).
static func _bevel(fill: Color, light: Color, shade: Color, depth: int, content: Vector4, drop: int = 0) -> StyleBoxTexture:
	var edge := 1 + depth
	var cells := edge * 2 + 2
	var image := Image.create_empty(cells * PX, (cells + drop) * PX, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var height := cells + drop
	for y in range(height):
		for x in range(cells):
			var color := fill
			var outer := x == 0 or y == 0 or x == cells - 1 or y == height - 1
			if outer:
				# Corners stay open for a softer pixel silhouette.
				if (x == 0 or x == cells - 1) and (y == 0 or y == height - 1): continue
				color = INK
			elif y >= height - 1 - drop - depth:
				color = shade
			elif x >= cells - 1 - depth:
				color = shade
			elif y <= depth or x <= depth:
				color = light
			image.fill_rect(Rect2i(x * PX, y * PX, PX, PX), color)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.texture_margin_left = edge * PX
	style.texture_margin_top = edge * PX
	style.texture_margin_right = edge * PX
	style.texture_margin_bottom = (edge + drop) * PX
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style


static func _flat(fill: Color, border: Color, width: int, content: int = -1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(0)
	if content >= 0: style.set_content_margin_all(content)
	return style
