extends SceneTree
## Direct entry to the isolated offline Necromancer study.
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	var game := preload("res://src/debug/necro_lab_game.gd").new()
	root.add_child(game)
	current_scene = game
