extends RefCounted
## The neutral HUD look every world shares (crypt, Hell-Dungeon, Frostgruft):
## dark see-through panels with a faint light edge, off-white text with a dark
## outline, one warm accent for what is ready or important, red for danger and
## the blood of the life bar, green for experience. No world tints its HUD.
## Colours, sizes and the life bar's timings: assets/data/ui_hud_style.json.
## Static helpers, display only.

const DATA_PATH := "res://assets/data/ui_hud_style.json"
const DEFAULT_COLORS := {"panel": "0f0f12c8", "panel_edge": "ffffff2e", "panel_shine": "ffffff10", "slot": "0b0b0ee6", "text": "f2efe8",
	"text_dim": "aaa59d", "text_muted": "6f6b65", "outline": "08080a", "accent": "f2c66d", "danger": "e2584a", "danger_dark": "5a2320",
	"blood_lite": "f4917a", "blood_glow": "ff7a5a", "exp": "7dd3a2", "track": "26262b", "ok": "8fd6a5", "auto": "7fe3ff"}
const DEFAULT_SIZES := {"margin": 16, "pad": 10, "heart_size": 26, "heart_gap": 3, "hearts_per_row": 10, "bar_width": 287, "bar_height": 14,
	"badge_height": 26, "map_panel_width": 236, "map_panel_height": 160, "boss_bar_width": 560, "font_title": 16, "font_small": 12,
	"font_body": 16, "font_banner": 28, "life_ghost_hold": 0.1, "life_ghost_time": 0.4, "life_heal_sweep": 0.45, "life_pulse_hz": 1.2,
	"life_low_pulse_hz": 2.4, "life_wobble_hz": 0.6, "life_low_share": 0.25, "life_hit_threshold": 0.5, "pet_row_height": 44, "pet_pad": 4,
	"pet_portrait": 36, "pet_slot": 36, "pet_icon": 36, "pet_slot_gap": 4, "pet_bar_height": 8, "pet_key_size": 10, "pet_number_size": 14}
# Named lookup tables (string -> string), e.g. "pet_portraits": companion kind -> idle frame path.
const DEFAULT_TABLES := {"pet_portraits": {}}

static var _colors: Dictionary = {}
static var _sizes: Dictionary = {}
static var _tables: Dictionary = {}


static func _load() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var colors: Dictionary = data.get("colors", {})
	for key: String in DEFAULT_COLORS:
		_colors[key] = Color(str(colors.get(key, DEFAULT_COLORS[key])))
	for key: String in DEFAULT_SIZES:
		_sizes[key] = float(data.get(key, DEFAULT_SIZES[key]))
	for key: String in DEFAULT_TABLES:
		var table: Variant = data.get(key, DEFAULT_TABLES[key])
		_tables[key] = (table as Dictionary).duplicate() if table is Dictionary else {}


## A colour of the HUD by role ("panel", "text", "accent", "danger", ...).
static func color(role: String) -> Color:
	if _colors.is_empty(): _load()
	return _colors.get(role, Color.MAGENTA)


## A size or timing of the HUD by name ("margin", "bar_width", "life_pulse_hz", "font_body", ...).
static func size(name: String) -> float:
	if _sizes.is_empty(): _load()
	return float(_sizes.get(name, 0.0))


## A lookup table of the HUD by name ("pet_portraits": companion kind -> texture path); {} when unknown.
static func table(name: String) -> Dictionary:
	if _tables.is_empty(): _load()
	return _tables.get(name, {})


## A panel: dark see-through fill, a faint light edge and a shine on its top line.
static func panel(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0) -> void:
	var fill := color("panel")
	canvas.draw_rect(rect, Color(fill, fill.a * alpha))
	canvas.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 1)), Color(color("panel_shine"), color("panel_shine").a * alpha))
	canvas.draw_rect(rect, Color(color("panel_edge"), color("panel_edge").a * alpha), false, 1.0)


## A thin bar: track, filled share (0..1) in `fill`.
static func bar(canvas: CanvasItem, rect: Rect2, share: float, fill: Color, alpha: float = 1.0) -> void:
	canvas.draw_rect(rect, Color(color("track"), alpha))
	canvas.draw_rect(Rect2(rect.position, Vector2(roundf(rect.size.x * clampf(share, 0.0, 1.0)), rect.size.y)), Color(fill, fill.a * alpha))


## Outlined text; `align` 0 left, 1 centred on `at.x`, 2 right-aligned to `at.x`.
static func text(canvas: CanvasItem, font: Font, at: Vector2, value: String, font_size: int, tint: Color, align: int = 0) -> void:
	var x := at.x
	if align != 0:
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		x -= floorf(width * (0.5 if align == 1 else 1.0))
	canvas.draw_string_outline(font, Vector2(x, at.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(color("outline"), tint.a))
	canvas.draw_string(font, Vector2(x, at.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


## Width of a text in px.
static func width(font: Font, value: String, font_size: int) -> float:
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## A flat style box in the HUD look for real buttons (menu, inventory).
static func button_box(hover: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color("panel") if not hover else color("panel").lightened(0.12)
	box.border_color = color("panel_edge") if not hover else Color(color("accent"), 0.8)
	box.set_border_width_all(1)
	box.set_content_margin_all(6)
	return box


## Gives a Godot button the HUD look (normal, hover, pressed, focus).
static func style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_box())
	button.add_theme_stylebox_override("hover", button_box(true))
	button.add_theme_stylebox_override("pressed", button_box(true))
	button.add_theme_stylebox_override("focus", button_box(true))
	button.add_theme_color_override("font_color", color("text_dim"))
	button.add_theme_color_override("font_hover_color", color("text"))
	button.add_theme_color_override("font_pressed_color", color("accent"))
