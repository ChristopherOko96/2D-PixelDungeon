class_name RigDebrisHost
extends RefCounted
## What RigDebris (src/rig_kit/rig_debris.gd) asks of the world its pieces
## fall in. Extend it and override what your world has; every method has a
## neutral default, so a bare RigDebrisHost is an open floor without walls and
## without any look (pieces only fly, bounce and come to rest).
##
## Adapters today: the rig look in src/rig/rig_renderer.gd (walls from the
## renderer's `solid`, element matter, wall dust, frozen parts shattering),
## src/hell/story_wreck.gd (the floor grid) and src/hero/hero_look.gd (none:
## a fallen weapon has no walls).


## True when world point `_point` lies inside a wall: a piece flying into it is
## thrown back (wall_bounce), a piece shoved there by another stays put. A piece
## that starts inside a wall may leave it freely. Default: no walls.
func solid(_point: Vector2) -> bool:
	return false


## Called once per step for every piece, before it moves (also for resting and
## crumbling ones): what a piece gives off while it lies there (smoke, motes,
## drips). `_delta` is the step in seconds. Default: nothing.
func on_tick(_piece: Dictionary, _delta: float) -> void:
	pass


## Called right after `_piece` was thrown back by a wall (its velocity already
## reflected): dust, a knock. Default: nothing.
func on_wall(_piece: Dictionary) -> void:
	pass


## Called once, at the first landing of `_piece` that bounces (its velocities
## already bounced). Returns new pieces that join the debris after this step
## (shards); setting piece.broken = true removes the piece itself. Default: [].
func on_land(_piece: Dictionary) -> Array[Dictionary]:
	return []
