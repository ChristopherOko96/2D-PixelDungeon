extends RefCounted
## The host contract of MatterKit (src/physics_kit/matter_kit.gd): what the
## pixel-grid kit asks of a game, and nothing more. A game that wants its walls
## to cut pixels, pools and splats extends this file in an adapter of its own
## and passes it to MatterKit.clip_for(host). Every method has a neutral
## default, so an empty host is open floor everywhere that never changes.
##
## [codeblock]
## extends "res://src/physics_kit/matter_host.gd"
## var grid: Dictionary  # Vector2i cell -> true for wall
## var rev := 0
## func is_open(world_point: Vector2) -> bool:
##     return not grid.has(Vector2i((world_point / 96.0).floor()))
## func wall_revision() -> int:
##     return rev  # bump it whenever a wall breaks or a prop is built
## [/codeblock]


## True when matter may show or flow at `world_point` (world px): open floor.
## False inside walls and solid props. MatterKit asks it once per art cell and
## remembers the answer until wall_revision() changes.
func is_open(_world_point: Vector2) -> bool:
	return true


## A number that changes whenever the answers of is_open may change (a wall
## broke, a prop was built or smashed). MatterKit drops what it remembered
## when it sees a new number. The default never changes.
func wall_revision() -> int:
	return 0
