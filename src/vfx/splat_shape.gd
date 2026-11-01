extends RefCounted
## The shape of a splat of liquid on the art grid, from where it lands, which
## way it was flying and how much there is (vfx_pools.json). The flood itself
## lives in MatterKit (src/physics_kit/matter_kit.gd, MatterKit.flood): the
## liquid runs out cell by cell from the landing point, cheapest first, along
## its flight, stopped by walls and solid props, its rim roughened by smooth
## noise; fast splats fling a few droplets ahead. Pure and deterministic (same
## inputs, same cells), so the server's hit test and every client's drawing
## agree. This file keeps the old API for its consumers (src/vfx/pool_paint.gd).

## The flood's steps to the eight neighbours: MatterKit.FLOOD_STEPS.
const STEPS := MatterKit.FLOOD_STEPS
## Cost buckets per unit of path cost: MatterKit.FLOOD_QUANT.
const QUANT := MatterKit.FLOOD_QUANT


## Cells (Vector2i art px -> rank 0..n-1, the order the liquid reached them) of
## a splat of `count` cells landing at `origin` (world px) moving along `dir`
## (ZERO: straight down, a round blot). `art`: world px per art pixel; `open`:
## Callable(world point) -> bool, true on floor the liquid may cover; `seed`
## varies the rim; `squash` < 1 flattens it (the floor seen at a slant);
## `momentum` 0..1 how strongly it runs on along the flight; `droplets` how
## many drops a fast splat flings ahead. See MatterKit.flood.
static func flood(origin: Vector2, dir: Vector2, count: int, art: float, open: Callable, seed: int,
		squash := 0.75, momentum := 0.5, droplets := 0) -> Dictionary:
	return MatterKit.flood(origin, dir, count, art, open, seed, squash, momentum, droplets)


## Cell count for a splat that covers about the area of a circle of `radius`
## world px (squashed like the floor), so a pool keeps its old volume.
static func cells_for(radius: float, art: float, squash := 0.75) -> int:
	return MatterKit.cells_for(radius, art, squash)
