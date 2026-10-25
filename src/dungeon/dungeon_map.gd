extends Control
## Read-only Isaac-style minimap. The host only sends rooms the party has visited
## or stands next to; this draws them on their grid with the doors between them.

const CURRENT := Color("#72dcc8")
const CLEARED := Color("#ac925d")
const VISITED := Color("#6f6a82")
const UNSEEN := Color("#2c2a38")
const UNSEEN_EDGE := Color("#555366")
const BOSS := Color("#b84a4f")
const TREASURE := Color("#efc76a")
const INK := Color("#151520")
const CONNECTOR := Color("#383643")
const MAX_ROOMS := 12
const DEFAULT_SIZE := Vector2(264, 108)
const DIRECTION_OFFSETS := {"north": Vector2i(0, -1), "east": Vector2i(1, 0), "south": Vector2i(0, 1), "west": Vector2i(-1, 0)}

var _rooms: Array[Dictionary] = []
var _current_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	resized.connect(queue_redraw)


## Shows up to twelve known rooms at their host-supplied grid coordinates.
## Current room is turquoise, cleared rooms gold, visited rooms grey, rooms only
## seen through a door are dark outlines; boss and treasure carry their marks.
func set_floor(rooms: Array, current_id: String) -> void:
	_rooms.clear()
	for value: Variant in rooms:
		if value is Dictionary:
			_rooms.append(value)
		if _rooms.size() >= MAX_ROOMS:
			break
	_current_id = current_id
	queue_redraw()


func _draw() -> void:
	if _rooms.is_empty():
		return
	var minimum: Vector2i = _coordinates(_rooms[0])
	var maximum: Vector2i = minimum
	var by_cell: Dictionary = {}
	for room: Dictionary in _rooms:
		var cell: Vector2i = _coordinates(room)
		by_cell[cell] = room
		minimum = Vector2i(mini(minimum.x, cell.x), mini(minimum.y, cell.y))
		maximum = Vector2i(maxi(maximum.x, cell.x), maxi(maximum.y, cell.y))
	var available := Vector2(size.x if size.x > 0.0 else DEFAULT_SIZE.x, size.y if size.y > 0.0 else DEFAULT_SIZE.y)
	var cells_across := Vector2(maximum - minimum) + Vector2.ONE
	# Square cells at a 3:2 room aspect keep the map readable at any floor shape.
	var step: float = floorf(minf(28.0, minf((available.x - 8.0) / cells_across.x, (available.y - 8.0) / cells_across.y / 0.7)))
	step = maxf(step, 6.0)
	var cell_size := Vector2(step, floorf(step * 0.7))
	var origin: Vector2 = ((available - cells_across * cell_size) * 0.5).floor()
	var room_size: Vector2 = (cell_size - Vector2(4, 4)).max(Vector2(2, 2))
	# Corridors first, so room boxes sit on top of them.
	for room: Dictionary in _rooms:
		var cell: Vector2i = _coordinates(room)
		var center: Vector2 = origin + (Vector2(cell - minimum) + Vector2(0.5, 0.5)) * cell_size
		for side: Variant in room.get("doors", []):
			var offset: Vector2i = DIRECTION_OFFSETS.get(str(side), Vector2i.ZERO)
			if by_cell.has(cell + offset):
				draw_line(center, center + Vector2(offset) * cell_size * 0.5, CONNECTOR, 2.0)
	for room: Dictionary in _rooms:
		var cell: Vector2i = _coordinates(room)
		var center: Vector2 = origin + (Vector2(cell - minimum) + Vector2(0.5, 0.5)) * cell_size
		var bounds := Rect2((center - room_size * 0.5).floor(), room_size)
		var is_current: bool = str(room.get("id", "")) == _current_id
		var visited: bool = bool(room.get("visited", false))
		var color: Color = CURRENT if is_current else CLEARED if bool(room.get("cleared", false)) else VISITED if visited else UNSEEN
		draw_rect(bounds.grow(1), INK)
		draw_rect(bounds, color)
		if not visited and not is_current:
			draw_rect(bounds, UNSEEN_EDGE, false, 1.0)
		match str(room.get("kind", "")):
			"boss":
				draw_rect(bounds.grow(1), BOSS, false, 1.0)
				_draw_crown(center + Vector2(0, 2), BOSS if not is_current else INK)
			"treasure":
				_draw_gem(center, TREASURE if not is_current else INK)


func _coordinates(room: Dictionary) -> Vector2i:
	return Vector2i(int(room.get("grid_x", 0)), int(room.get("grid_y", 0)))


func _draw_crown(point: Vector2, color: Color) -> void:
	draw_rect(Rect2(point + Vector2(-4, 0), Vector2(8, 3)), color)
	for offset: int in [-4, -1, 2]:
		draw_rect(Rect2(point + Vector2(offset, -2), Vector2(2, 2)), color)


func _draw_gem(point: Vector2, color: Color) -> void:
	draw_rect(Rect2(point + Vector2(-1, -3), Vector2(2, 6)), color)
	draw_rect(Rect2(point + Vector2(-3, -1), Vector2(6, 2)), color)
