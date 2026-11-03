extends SceneTree
## Consuming one blood source must not erase overlapping live liquid.
const Pools = preload("res://src/vfx/pool_paint.gd")
func _initialize() -> void:
	var p := Pools.new(2.0, func(_at: Vector2) -> bool: return true)
	p.add(1, "blood", Vector2(100,100), Vector2.ZERO, 10, 0, 10, "test")
	p.add(2, "blood", Vector2(100,100), Vector2.ZERO, 10, 0, 20, "test")
	p._now = 3.0
	var before := p.covers(Vector2(100,100), "blood")
	p.finish("test:1", 2.0)
	var remains := p.covers(Vector2(100,100), "blood")
	p.finish("test:2", 2.0)
	var gone := not p.covers(Vector2(100,100), "blood")
	print("POOL_CONSUMPTION before=%s overlap_survives=%s all_spent_gone=%s" % [before,remains,gone])
	p.clear()
	quit(0 if before and remains and gone else 1)
