extends Node
## Plays the Frostgruft straight from its first ice room, to try how it slides: the hero stands in the
## middle, the room's monsters are awake. F5 goes to the next ice room on the floor.
## Usage:
##   godot --path . res://scripts/preview_ice_room.tscn
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")

var _game: Node
var _at := 0


func _ready() -> void:
	_game = FrostScene.instantiate()
	_game.class_id = "swordsman"
	add_child(_game)
	_go.call_deferred(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_F5:
		_go(_at + 1)


func _go(step: int) -> void:
	var rooms: Array = (_game.W.rooms as Array).filter(func(r: Dictionary) -> bool: return bool(r.get("ice", false)))
	if rooms.is_empty():
		return
	_at = step % rooms.size()
	var room: Dictionary = rooms[_at]
	var cell: Vector2i = room.cells[(room.cells as Array).size() / 2]
	_game.player.x = (cell.x + 0.5) * _game.C
	_game.player.y = (cell.y + 0.5) * _game.C
	_game.player.vel = Vector2.ZERO
