extends SceneTree
## Isolated Archer/Waldmeister lab using the existing offline training host.
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	var game := preload("res://src/debug/necro_lab_game.gd").new()
	game.lab_cfg = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/debug_forest_lab.json"))
	root.add_child(game)
	current_scene = game
