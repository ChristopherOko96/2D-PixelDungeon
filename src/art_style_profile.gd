@tool
extends Resource
## Presentation-only settings. Native collision footprints are not changed here.

@export var floor_tint := Color.WHITE:
	set(value):
		floor_tint = value
		emit_changed()
@export var wall_tint := Color.WHITE:
	set(value):
		wall_tint = value
		emit_changed()
@export_range(8, 40, 1) var pillar_height := 24.0:
	set(value):
		pillar_height = clampf(value, 8, 40)
		emit_changed()
@export_range(24, 48, 1) var north_wall_height := 48.0:
	set(value):
		north_wall_height = clampf(value, 24, 48)
		emit_changed()
@export_range(0, 1.5, 0.05) var shadow_strength := 1.0:
	set(value):
		shadow_strength = clampf(value, 0, 1.5)
		emit_changed()

## Produces a snapshot-compatible presentation dictionary; never contains nodes.
func as_dictionary() -> Dictionary:
	return {"floor_tint": floor_tint, "wall_tint": wall_tint, "pillar_height": pillar_height, "north_wall_height": north_wall_height, "shadow_strength": shadow_strength}
