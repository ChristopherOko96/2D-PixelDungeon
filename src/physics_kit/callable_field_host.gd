extends "res://src/physics_kit/field_host.gd"
## A FieldHost (src/physics_kit/field_host.gd) made of one Callable(world point)
## -> bool: true on open floor. The painters (src/vfx/pool_paint.gd,
## src/vfx/gas.gd) are still made with such a Callable (PoolPaint.new(art,
## open)); they wrap it in this host for their field. Without a valid Callable
## the floor is open everywhere.
##
## [codeblock]
## # (PoolField.CallableHost and GasField.CallableHost preload this file)
## var field := PoolField.new(3.0, PoolField.CallableHost.new(func(p: Vector2) -> bool: return p.x < 500.0))
## [/codeblock]

## Callable(world point: Vector2) -> bool, true on open floor.
var open_floor: Callable


## A host asking `open` (Callable(world point) -> bool) where the floor is open.
func _init(open: Callable = Callable()) -> void:
	open_floor = open


## True when `open_floor` says the floor at `point` (world px) is open, or when
## there is no valid Callable.
func is_open(point: Vector2) -> bool:
	return bool(open_floor.call(point)) if open_floor.is_valid() else true
