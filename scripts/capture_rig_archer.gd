extends "res://scripts/capture_archer_rework.gd"
## Recheck actual main-game held weapons, R charge/pin and traps without replacing old photos.
func _initialize() -> void:
	capture_out="res://production/qa/evidence/rig-audit/live-archer"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_out))
	super._initialize()
