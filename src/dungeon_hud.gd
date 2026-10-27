@tool
extends Control
## Read-only pixel HUD using the user's original UI atlas and host snapshots.

const SHEET := preload("res://assets/ui/asset_sheet_ui.png")
const HealthStrip = preload("res://src/health_strip.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const BAR_FRAME := Rect2(38, 85, 68, 8)
const MAX_HEARTS := 12
const HEART_PITCH := 24.0
const DEFAULT_SIZE := Vector2(560, 64)
const INK := Color("#170c1d")
const PANEL := Color("#29152f")
const GOLD := Color("#edbc81")
const MUTED := Color("#ad96b5")

var _snapshot: Dictionary = {}
var _local_peer := 0
var _font: Font
var _health_key := Vector3i(-1, -1, -1)
var _health_texture: ImageTexture
@export var health_only := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_font = PixelStyle.create_font()
	resized.connect(queue_redraw)
	if not SHEET.changed.is_connected(_invalidate_health): SHEET.changed.connect(_invalidate_health)


func _invalidate_health() -> void:
	_health_key = Vector3i(-1, -1, -1)
	queue_redraw()


## Displays local health and the host's cleared-room count; no XP is inferred.
## Two HP equal one heart. Capacity beyond twelve icons remains in the numbers.
func set_state(snapshot: Dictionary, local_peer: int) -> void:
	_snapshot = snapshot
	_local_peer = local_peer
	queue_redraw()


## Builds a square pixel frame for matching panels and buttons outside this HUD.
## Callers may supply state colours; this does not alter the original UI image.
static func panel_style(fill: Color = PANEL, border: Color = GOLD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.shadow_color = Color("#100a15")
	style.shadow_size = 2
	style.shadow_offset = Vector2(2, 2)
	return style


func _draw() -> void:
	if _font == null:
		return
	var dimensions := Vector2(size.x if size.x > 0 else DEFAULT_SIZE.x, size.y if size.y > 0 else DEFAULT_SIZE.y)
	if health_only:
		_draw_compact_health(_snapshot.get("players",{}).get(_local_peer,{}),dimensions.x)
		return
	draw_rect(Rect2(Vector2.ZERO, dimensions), INK)
	draw_rect(Rect2(2, 2, dimensions.x - 4, dimensions.y - 4), PANEL)
	draw_line(Vector2(2, 0), Vector2(dimensions.x - 2, 0), Color("#69446f"), 2)
	var players: Dictionary = _snapshot.get("players", {})
	var player: Dictionary = players.get(_local_peer, {})
	_draw_health(player, dimensions.x)
	_draw_floor_progress(dimensions.x)


func _draw_compact_health(player: Dictionary, width: float) -> void:
	if player.is_empty(): return
	var maximum := maxi(0,int(player.get("max_hp",0)))
	var health := clampi(int(player.get("hp",0)),0,maximum)
	var count := mini(MAX_HEARTS,ceili(maximum/2.0))
	var zoom := 3.0
	count = mini(count,maxi(0,int(width/(HealthStrip.PITCH*zoom))))
	var key := Vector3i(health,maximum,count)
	if key != _health_key:
		_health_key = key
		_health_texture = ImageTexture.create_from_image(HealthStrip.make_image(health,maximum,count))
	if count > 0: draw_texture_rect(_health_texture,Rect2(Vector2(0,6),_health_texture.get_size()*zoom),false)
	if ceili(maximum/2.0) > count:
		_text("+",Vector2(count*HealthStrip.PITCH*zoom,25),16,GOLD)


func _draw_health(player: Dictionary, width: float) -> void:
	if player.is_empty():
		_text("DEIN WANDERER", Vector2(10, 21), PixelStyle.BODY_SIZE, MUTED)
		return
	var maximum: int = maxi(0, int(player.get("max_hp", 0)))
	var health: int = clampi(int(player.get("hp", 0)), 0, maximum)
	var count: int = mini(MAX_HEARTS, ceili(maximum / 2.0))
	# At the intended width all twelve icons fit; smaller embedded previews
	# reserve enough room for the numeric health before dropping extra symbols.
	var available: int = maxi(0, int((width - 160.0) / HEART_PITCH))
	count = mini(count, available)
	var key := Vector3i(health, maximum, count)
	if key != _health_key:
		_health_key = key
		_health_texture = ImageTexture.create_from_image(HealthStrip.make_image(health, maximum, count))
	if count > 0:
		draw_texture_rect(_health_texture, Rect2(Vector2(10, 7), _health_texture.get_size() * 2.0), false)
	var health_text := "%d / %d LP" % [health, maximum]
	var text_width: float = _font.get_string_size(health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelStyle.BODY_SIZE).x
	_text(health_text, Vector2(maxf(10, width - text_width - 10), 21), PixelStyle.BODY_SIZE, GOLD if health > 0 else Color("#f4666d"))


## Returns the same native health image used by the live HUD, for export/review.
func get_health_image() -> Image:
	var player: Dictionary = _snapshot.get("players", {}).get(_local_peer, {})
	return HealthStrip.make_image(int(player.get("hp", 0)), int(player.get("max_hp", 0)))


func _draw_floor_progress(width: float) -> void:
	var rooms: Array = _snapshot.get("floor_map", [])
	var total: int = rooms.size()
	var cleared := 0
	for value: Variant in rooms:
		if value is Dictionary and bool(value.get("cleared", false)):
			cleared += 1
	var floor_number: int = maxi(1, int(_snapshot.get("floor_index", 1)))
	var description := "EBENE %d · RÄUME %d/%d" % [floor_number, cleared, total] if total > 0 else "EBENE — · RÄUME —"
	_text(description, Vector2(10, 47), PixelStyle.BODY_SIZE, MUTED)
	var description_width := _font.get_string_size(description,HORIZONTAL_ALIGNMENT_LEFT,-1,PixelStyle.BODY_SIZE).x
	var bar_start := maxf(206,ceilf(description_width)+20)
	if width < bar_start+34: return
	var bar := Rect2(bar_start, 34, floorf(width-bar_start-10), 16)
	_draw_progress_bar(bar, float(cleared) / float(total) if total > 0 else 0.0)


func _draw_progress_bar(target: Rect2, ratio: float) -> void:
	# Native 4px endcaps stay at 2x; only the solid middle column stretches.
	# The atlas contains a demonstration blue fill, which is covered completely.
	draw_texture_rect_region(SHEET, Rect2(target.position, Vector2(8, 16)), Rect2(BAR_FRAME.position, Vector2(4, 8)))
	draw_texture_rect_region(SHEET, Rect2(target.position + Vector2(8, 0), Vector2(target.size.x - 16, 16)), Rect2(60, 85, 1, 8))
	draw_texture_rect_region(SHEET, Rect2(target.position + Vector2(target.size.x - 8, 0), Vector2(8, 16)), Rect2(102, 85, 4, 8))
	var inner := Rect2(target.position + Vector2(6, 6), Vector2(target.size.x - 12, 4))
	draw_texture_rect_region(SHEET, inner, Rect2(96, 88, 1, 2))
	var fill_width: float = floorf(inner.size.x * clampf(ratio, 0.0, 1.0) / 2.0) * 2.0
	if fill_width > 0:
		draw_texture_rect_region(SHEET, Rect2(inner.position, Vector2(fill_width, inner.size.y)), Rect2(60, 88, 1, 2))


func _text(value: String, at: Vector2, font_size: int, colour: Color) -> void:
	var raster_size := maxi(PixelStyle.BODY_SIZE,roundi(float(font_size)/PixelStyle.BASE_SIZE)*PixelStyle.BASE_SIZE)
	draw_string(_font, at + Vector2(0, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, raster_size, Color("#100a15"))
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, raster_size, colour)
