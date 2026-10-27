extends Control
## Read-only floor diagram. Room coordinates and progress come from the host.

const CURRENT := Color("#72dcc8")
const CLEARED := Color("#ac925d")
const UPCOMING := Color("#555366")
const INK := Color("#151520")
const CONNECTOR := Color("#383643")
const MAX_ROOMS := 10
const DEFAULT_SIZE := Vector2(264, 40)

var _rooms: Array[Dictionary] = []
var _current_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	resized.connect(queue_redraw)


## Shows up to ten floor rooms, preserving their host-supplied grid coordinates.
## The current room is turquoise; cleared rooms are gold; bosses carry a crown.
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
	for room: Dictionary in _rooms:
		var cell: Vector2i = _coordinates(room)
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	var available := Vector2(size.x if size.x > 0.0 else DEFAULT_SIZE.x, size.y if size.y > 0.0 else DEFAULT_SIZE.y)
	var span := Vector2(maximum - minimum)
	var spacing := Vector2(
		maxf(1.0, floorf(minf(24.0, (available.x - 20.0) / maxf(span.x, 1.0)))),
		maxf(1.0, floorf(minf(14.0, (available.y - 24.0) / maxf(span.y, 1.0))))
	)
	var origin: Vector2 = ((available - span * spacing) * 0.5).floor()
	var points: Array[Vector2] = []
	for room: Dictionary in _rooms:
		points.append((origin + Vector2(_coordinates(room) - minimum) * spacing).floor())
	# The floor is an ordered route. Two cells can touch after a bend without
	# creating a shortcut, so only connect consecutive rooms on that route.
	for first: int in range(_rooms.size() - 1):
		var second: int = first + 1
		var difference: Vector2i = _coordinates(_rooms[first]) - _coordinates(_rooms[second])
		if absi(difference.x) + absi(difference.y) == 1:
			draw_line(points[first], points[second], CONNECTOR, 2.0)
	var half_width: float = minf(7.0, maxf(1.0, floorf(spacing.x * 0.3)))
	var half_height: float = minf(4.0, maxf(1.0, floorf(spacing.y * 0.3)))
	for index: int in range(_rooms.size()):
		var room: Dictionary = _rooms[index]
		var point: Vector2 = points[index]
		var is_current: bool = str(room.get("id", "")) == _current_id
		var color: Color = CURRENT if is_current else (CLEARED if bool(room.get("cleared", false)) else UPCOMING)
		var bounds := Rect2(point - Vector2(half_width, half_height), Vector2(half_width * 2, half_height * 2))
		draw_rect(bounds.grow(2), INK)
		draw_rect(bounds, color)
		if bool(room.get("boss", false)):
			draw_rect(bounds.grow(2), color, false, 1.0)
			var crown_offset := Vector2(0, -half_height - 5)
			for other_room: Dictionary in _rooms:
				if _coordinates(other_room) == _coordinates(room) + Vector2i.UP:
					crown_offset = Vector2(half_width + 8, 0)
					break
			_draw_crown(point + crown_offset, color)
		elif is_current:
			draw_rect(Rect2(point - Vector2(1, 1), Vector2(2, 2)), INK)


func _coordinates(room: Dictionary) -> Vector2i:
	return Vector2i(int(room.get("grid_x", 0)), int(room.get("grid_y", 0)))


func _draw_crown(point: Vector2, color: Color) -> void:
	draw_rect(Rect2(point + Vector2(-4, 0), Vector2(8, 3)), color)
	for offset: int in [-4, -1, 2]:
		draw_rect(Rect2(point + Vector2(offset, -2), Vector2(2, 2)), color)
