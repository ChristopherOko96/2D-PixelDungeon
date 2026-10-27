extends RefCounted
## Local presentation only. Returns integer translations, never changes gameplay.
var center := Vector2.ZERO

## Resets under the room's black transition; small rooms start centered.
func reset(player: Vector2, world: Vector2, viewport: Vector2) -> void:
	center = Vector2(player.x if world.x > viewport.x else world.x*0.5,player.y if world.y > viewport.y else world.y*0.5)
	center = _bounded(center,world,viewport,0)

## Exponential following with bounded mouse look; frozen menus retain framing.
func update(player: Vector2, mouse_delta: Vector2, world: Vector2, viewport: Vector2, delta: float, tuning: Dictionary, frozen: bool) -> Vector2:
	if not frozen and player.is_finite() and mouse_delta.is_finite() and is_finite(delta) and delta >= 0:
		var look := mouse_delta.limit_length(float(tuning.get("look_ahead",24)))
		var small := float(tuning.get("small_room_follow",0.18))
		var target := Vector2(player.x if world.x > viewport.x else world.x*0.5+(player.x-world.x*0.5)*small,player.y if world.y > viewport.y else world.y*0.5+(player.y-world.y*0.5)*small)+look
		target = _bounded(target,world,viewport,float(tuning.get("edge_margin",32)))
		center = center.lerp(target,1-exp(-float(tuning.get("follow_speed",5))*delta))
	return (viewport*0.5-center).round()

func _bounded(point: Vector2, world: Vector2, viewport: Vector2, margin: float) -> Vector2:
	var result := point
	for axis in range(2):
		if world[axis] >= viewport[axis]: result[axis] = clampf(point[axis],viewport[axis]*0.5-margin,world[axis]-viewport[axis]*0.5+margin)
		else: result[axis] = clampf(point[axis],world[axis]*0.5-margin,world[axis]*0.5+margin)
	return result
