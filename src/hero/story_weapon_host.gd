extends RigHeldHost
## The story hero's weapon as the held item of his part rig (src/rig_kit/rig_held.gd):
## the game side of RigHeldHost for src/hero/story_hero.gd. The hero kit hands
## over this frame's hero (frame()) before it draws his rig; the rig then asks
## for the pieces of its weapon item, which the hero look (src/hero/hero_look.gd)
## places at the shoulder the rig data names (the item's held "hand"), and
## reports where it drew them, so a fall throws the weapon from there. Reads
## nothing of the world itself.

const HeroLook = preload("res://src/hero/hero_look.gd")

## The look that moves the weapon (the hero kit's).
var look: HeroLook
var _view: Dictionary = {}
var _aim := Vector2.RIGHT
var _clock := 0.0
var _texture: Texture2D
var _glow := Color(1, 0.95, 0.8)
var _element := ""
var _armed := false


## `hero_look` moves and draws the weapon's pieces.
func _init(hero_look: HeroLook) -> void:
	look = hero_look


## This frame's hero: his view state (hero_look's player fields), aim (unit
## vector), clock (s), weapon art, shot glow and weapon element. `armed` false
## holds nothing (no weapon, a relic in hand, a fallen hero whose weapon fell).
func frame(view: Dictionary, aim: Vector2, clock: float, texture: Texture2D, glow: Color, element: String, armed: bool) -> void:
	_view = view
	_aim = aim
	_clock = clock
	_texture = texture
	_glow = glow
	_element = element
	_armed = armed


## RigHeldHost: the weapon's pieces from the look, its shoulder the item's held
## hand on the figure standing still (`rest`).
func pieces(key: String, item: Dictionary, rest: Transform2D) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	if not _armed or _texture == null or look == null: return none
	var held := RigHeld.spec(item)
	return look.hold(key, _view, rest * Vector2(held.get("hand", Vector2.ZERO)), _aim, _clock, _texture, _glow, _element, held)


## RigHeldHost: where the rig drew the hero's own weapon (the look's "main"
## piece): the look remembers it for a fall.
func drawn(key: String, _item_id: String, placed: Array[Dictionary]) -> void:
	for piece: Dictionary in placed:
		if bool(piece.get("main", false)): look.held_at(key, piece)
