extends "res://src/physics_kit/motion_host.gd"
## The story worlds' side of MotionKit (src/physics_kit/motion_kit.gd): the
## adapter between the kit's host contract (src/physics_kit/motion_host.gd)
## and the world (src/hell/hell_game.gd). The hero is g.player (x, y, vel),
## his knockback g.state.knock (null for none), walls and props g.box_blocked
## round his box. hell_game.gd, hell_monsters.gd and frost_fx.gd each make a
## MotionKit.new(StoryMotionHost.new(g)) of their own (they share the world's
## state through it); the kit holds this host, never the other way round (no
## reference cycle). Only this file reaches into the world.

const HeroKit = preload("res://src/hell/hero_kit.gd")

## The world (src/hell/hell_game.gd).
var g: Node


func _init(game: Node) -> void:
	g = game


func hero_x() -> float:
	return float(g.player.x)


func hero_y() -> float:
	return float(g.player.y)


func place_hero(x: float, y: float) -> void:
	g.player.x = x
	g.player.y = y


func hero_blocked(x: float, y: float) -> bool:
	return bool(g.box_blocked(g._player_box(x, y)))


func hero_velocity() -> Vector2:
	return g.player.vel


func set_hero_velocity(velocity: Vector2) -> void:
	g.player.vel = velocity


func knock_state() -> Dictionary:
	var knock: Variant = g.state.get("knock")
	return knock if knock is Dictionary else {}


func set_knock_state(knock: Dictionary) -> void:
	g.state.knock = null if knock.is_empty() else knock


## The solid test of a monster's footprint (half width `rr`) at (x, y): the
## world's walls and props round its box (`avoid`: also the lava and liquid
## tiles a walker keeps off) and the walls of the wreck (src/hell/hero_kit.gd wall_blocks).
func mob_solid(rr: float, avoid: bool) -> Callable:
	return func(x: float, y: float) -> bool:
		return bool(g.box_blocked(Rect2(x - rr, y - rr, rr * 2.0, rr), avoid)) or bool(HeroKit.wall_blocks(g, Vector2(x, y), rr))
