extends RefCounted
## The host contract of MotionKit (src/physics_kit/motion_kit.gd): what the
## motion kit asks of a game to move its hero, and nothing more. A game extends
## this file in an adapter of its own (the story worlds: src/hell/story_motion_host.gd)
## and gives it to MotionKit.new(host). Every method has a neutral default, so
## an empty host is a hero standing at the origin on open floor.
##
## Positions are plain floats (world px) so a game that keeps its hero in
## 64-bit numbers keeps every digit. Monsters need no host: MotionKit.step_body
## takes their numbers and a solid(x, y) Callable and gives back new ones.
##
## [codeblock]
## extends "res://src/physics_kit/motion_host.gd"
## var hero := {"x": 100.0, "y": 100.0, "vel": Vector2.ZERO, "knock": {}}
## func hero_x() -> float: return hero.x
## func hero_y() -> float: return hero.y
## func place_hero(x: float, y: float) -> void:
##     hero.x = x
##     hero.y = y
## func hero_blocked(x: float, y: float) -> bool: return x > 500.0  # a wall
## [/codeblock]


## The hero's feet, x (world px).
func hero_x() -> float:
	return 0.0


## The hero's feet, y (world px).
func hero_y() -> float:
	return 0.0


## Puts the hero's feet at (`x`, `y`). MotionKit only passes places that
## hero_blocked said are free (or where he already stands).
func place_hero(_x: float, _y: float) -> void:
	pass


## True when the hero standing with his feet at (`x`, `y`) would overlap a
## wall or a solid prop.
func hero_blocked(_x: float, _y: float) -> bool:
	return false


## The hero's walking velocity (px/s) as it carries over between frames (his
## momentum on ice and blood).
func hero_velocity() -> Vector2:
	return Vector2.ZERO


## Keeps the hero's walking velocity `velocity` for the next frame.
func set_hero_velocity(_velocity: Vector2) -> void:
	pass


## The hero's running knockback ({} for none), as MotionKit made it:
## {"v": Vector2 px/s at its start, "t": seconds gone, "T": seconds in all}.
func knock_state() -> Dictionary:
	return {}


## Keeps the knockback `knock` ({} ends it).
func set_knock_state(_knock: Dictionary) -> void:
	pass
