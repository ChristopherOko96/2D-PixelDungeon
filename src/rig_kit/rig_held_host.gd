class_name RigHeldHost
extends RefCounted
## What a rig figure holds in its hands this frame (src/rig_kit/rig_held.gd).
## The rig data names the item, its parent part, its z and its hold (an item's
## "held" block); the host puts the art into that hand at run time, because the
## art changes in play (the hero's equipped weapon, a picked-up item). Extend it
## and override what your figure holds; every method has a neutral default, so
## a bare RigHeldHost holds nothing and the item is not drawn (like a rig drawn
## without its items).
##
## A piece is a Dictionary, in world px with the figure standing still:
## - texture: Texture2D, the art;
## - hand: Vector2, the point of the art the hand holds, where it is;
## - angle: float (rad), the art's turn about the hand;
## - rect: Rect2, where the texture is drawn in the hand's frame (origin at the
##   hand, turned by angle; its size sets the art's size);
## optional:
## - tint: Color (white), multiplied by the figure's alpha;
## - under / over: Callable(canvas: CanvasItem, follow: Transform2D), drawn just
##   before / after the piece with the canvas under `follow` (effects that go
##   with the hand: a swing's crescent, a bow string, a glow);
## - outline: bool (true), whether the figure's outline rims it;
## - main: bool, the host's own mark (RigHeld passes every key through).
## The rig then moves every piece with the item's parent part (RigHeld.follow).
##
## Adapter today: src/hero/story_weapon_host.gd (the story worlds' hero weapon,
## posed through src/hero/hero_look.gd).


## The pieces actor `_key` holds in rig item `_item` (its rig data, with the
## "held" block, see RigHeld.spec) this frame, in drawing order. `_rest` maps
## the figure's source px to world px with the figure standing still at this
## frame's feet, facing and size (no breathing, step or recoil): place the
## pieces for that figure, e.g. a hand at `_rest * RigHeld.spec(_item).hand`;
## the rig carries them along with the parent part's real motion. Default:
## nothing held (the item is not drawn).
func pieces(_key: String, _item: Dictionary, _rest: Transform2D) -> Array[Dictionary]:
	return []


## Called once per drawn item after its pieces were drawn, with where they
## really went: `_placed` holds the pieces in the same order with hand and
## angle after the parent part's motion (so a weapon that falls from the hand
## starts there). Default: nothing.
func drawn(_key: String, _item_id: String, _placed: Array[Dictionary]) -> void:
	pass
