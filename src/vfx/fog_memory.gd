extends Node2D
## Fog of war for themed open floors: the floor is split into `cell`-sized
## squares; squares no hero has seen are almost black (`dark_alpha`), seen
## ones stay dimmed (`memory_alpha`), and around each living hero the fog
## clears completely within `light_radius`, fading out over `fade`.
## The state lives in a small image (one pixel per square) drawn stretched
## with linear filtering, so edges are soft. Only squares near a hero change
## per update. Presentation only; values come from layout.floor_fog.

var _key := ""
var _cell := 16.0
var _columns := 0
var _rows := 0
var _config: Dictionary = {}
## 1 for every square a hero has seen on this floor.
var _seen := PackedByteArray()
## Squares lit in the last update; they fall back to memory first.
var _lit: Dictionary = {}
var _image: Image
var _texture: ImageTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Starts a fresh fog for a new floor (`key` changes) of `world_size` pixels.
func configure(key: String, world_size: Vector2, config: Dictionary) -> void:
	if key == _key and _image != null: return
	_key = key
	_config = config
	_cell = maxf(4.0, float(config.get("cell", 16)))
	_columns = maxi(1, ceili(world_size.x / _cell))
	_rows = maxi(1, ceili(world_size.y / _cell))
	_seen = PackedByteArray()
	_seen.resize(_columns * _rows)
	_lit.clear()
	_image = Image.create(_columns, _rows, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, float(config.get("dark_alpha", 0.93))))
	_texture = ImageTexture.create_from_image(_image)
	queue_redraw()


## Clears the fog around `lights` (world points) and marks those squares seen.
func reveal(lights: Array[Vector2]) -> void:
	if _image == null: return
	var radius: float = float(_config.get("light_radius", 170))
	var fade: float = maxf(1.0, float(_config.get("fade", 110)))
	var memory: float = float(_config.get("memory_alpha", 0.62))
	var dark: float = float(_config.get("dark_alpha", 0.93))
	var lit_now: Dictionary = {}
	var reach := radius + fade
	for light: Vector2 in lights:
		var first := Vector2i(floori((light.x - reach) / _cell), floori((light.y - reach) / _cell))
		var last := Vector2i(floori((light.x + reach) / _cell), floori((light.y + reach) / _cell))
		for y in range(maxi(0, first.y), mini(_rows, last.y + 1)):
			for x in range(maxi(0, first.x), mini(_columns, last.x + 1)):
				var centre := Vector2((x + 0.5) * _cell, (y + 0.5) * _cell)
				var light_amount: float = 1.0 - clampf((centre.distance_to(light) - radius) / fade, 0.0, 1.0)
				if light_amount <= 0.0: continue
				var square := Vector2i(x, y)
				lit_now[square] = maxf(float(lit_now.get(square, 0.0)), light_amount)
	for square: Vector2i in _lit:
		if not lit_now.has(square): _image.set_pixel(square.x, square.y, Color(0, 0, 0, memory if _seen[square.y * _columns + square.x] == 1 else dark))
	for square: Vector2i in lit_now:
		var amount: float = lit_now[square]
		if amount > 0.5: _seen[square.y * _columns + square.x] = 1
		var base: float = memory if _seen[square.y * _columns + square.x] == 1 else dark
		_image.set_pixel(square.x, square.y, Color(0, 0, 0, lerpf(base, 0.0, amount)))
	_lit = lit_now
	_texture.update(_image)
	queue_redraw()


## How many squares have been seen (tests, debug).
func seen_count() -> int:
	return _seen.count(1)


func _draw() -> void:
	if _texture == null: return
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(_columns, _rows) * _cell), false)
