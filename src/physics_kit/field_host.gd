extends RefCounted
## The host contract of PoolField (src/physics_kit/pool_field.gd) and GasField
## (src/physics_kit/gas_field.gd): what the two gameplay fields ask of a game,
## and nothing more. They only need to know where matter may lie: a pool runs
## out over open floor and stops at walls and solid props, a cloud's puffs
## flow over it and slide along walls. A game extends this file in an adapter
## of its own and passes it to PoolField.new(art, host) / GasField.new(art, host).
## The default is open floor everywhere (an empty room without walls).
##
## A game that only has a Callable(world point) -> bool for it (the painters'
## old `open`, e.g. src/hell/hell_game.gd _floor_open) wraps it in
## src/physics_kit/callable_field_host.gd instead of writing an adapter.
##
## Threads: a big pool (vfx_pools.json thread_cells cells or more) is shaped on
## a WorkerThreadPool thread, so is_open may be called from that thread while
## the game runs on. It must only read: answer from data that the main thread
## does not rebuild while a shape is being worked out, or accept that a wall
## that changes in that moment may or may not stop the pool.
##
## [codeblock]
## extends "res://src/physics_kit/field_host.gd"
## var walls: Dictionary  # Vector2i cell (64 px) -> true for a wall
## func is_open(point: Vector2) -> bool:
##     return not walls.has(Vector2i((point / 64.0).floor()))
## [/codeblock]


## True when liquid may lie and gas may flow at `point` (world px): open
## floor. False inside walls and solid props.
func is_open(_point: Vector2) -> bool:
	return true
