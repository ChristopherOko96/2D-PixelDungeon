extends "res://scripts/capture_necro_forest.gd"
## Preserve earlier evidence; use the exact existing live-game fixture after this integration.
func _initialize() -> void:
	capture_dest="res://production/qa/evidence/rig-audit/live-necro"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dest))
	super._initialize()

func _photo(name: String) -> void:
	if name=="05-knochenwelle":
		# Show the articulated body between white hurt flashes in this fixture.
		for pet: Dictionary in game.talent_combat.pets: pet.hurt=0.0
	await super._photo(name)
