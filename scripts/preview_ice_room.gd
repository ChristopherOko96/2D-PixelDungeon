extends Node
## Plays the Frostgruft straight from an ice room, to try how it slides: the hero stands in the
## middle, the room's monsters are awake. A floor has at most one, so F5 goes on to the next floor
## that has one.
## Usage:
##   godot --path . res://scripts/preview_ice_room.tscn
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const FLOORS := 9
const TRIES := 40

var _game: Node
var _floor := 1


func _ready() -> void:
	_game = FrostScene.instantiate()
	_game.class_id = "swordsman"
	add_child(_game)
	_go.call_deferred(_floor)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_F5:
		_go(_floor % FLOORS + 1)


func _go(first: int) -> void:
	_floor = first
	for i in range(TRIES):
		_game.load_floor(_floor, false)
		var rooms: Array = (_game.W.rooms as Array).filter(func(r: Dictionary) -> bool: return bool(r.get("ice", false)))
		if not rooms.is_empty():
			var room: Dictionary = rooms[0]
			var cell: Vector2i = room.cells[(room.cells as Array).size() / 2]
			_game.player.x = (cell.x + 0.5) * _game.C
			_game.player.y = (cell.y + 0.5) * _game.C
			_game.player.vel = Vector2.ZERO
			return
		_floor = _floor % FLOORS + 1
