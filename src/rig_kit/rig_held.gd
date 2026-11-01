class_name RigHeld
extends RefCounted
## Held items: art that a figure holds in a rig item's hand, chosen at run time
## (the hero's equipped weapon), but posed and drawn by the rig like any item.
##
## Rig data: an item of a rig (rigs.json "items", built by tools/rig_kit/) may
## carry a "held" block. It says how the figure holds whatever art it is given:
##   "held": {"style": "sword", "hand": [8, 14.4], "grip": [0.5, 0.9], "tip": [0.5, 0.0], "rest": 0.0, "scale": 1.0}
## - style: how the host moves it (the hero: sword, bow or staff, src/hero/hero_look.gd);
## - hand: figure px on the item's parent part: the shoulder the hand works
##   from (sword and bow swing round it toward the aim, the staff is held at
##   "side" figure px from it toward the facing side);
## - grip: share of the art's width and height where the hand holds it;
## - tip: share of the art at its tip (where an element shines);
## - rest: rad added to the style's angle; scale: factor on the art's size;
## - style extras (staff): side [x, y] figure px, length figure px.
## The item's own "parent" and "z" place it in the figure: it moves with that
## part and is drawn between the parts by its z. Its other fields (img, grip,
## hand, rest, tip) are the item's look on the review page and are not used
## for held art.
##
## Each frame the rig asks its RigHeldHost (src/rig_kit/rig_held_host.gd) for
## the pieces of every item with a held block, placed for the figure standing
## still; RigHeld.follow carries them with the parent part's real motion
## (breathing, steps, recoil), so the art and its effects follow the hand.
## No game access; static functions only.

## Offsets of an outline ring in art px (the rig's own RING is the same).
const RING_DEFAULT := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

## White silhouettes of held art for outlines: texture -> ImageTexture.
static var _white: Dictionary = {}


## The held block of rig item `item` (its "held" key) with every [x, y] pair
## as a Vector2 and every number as a float; strings stay. {} when the item
## holds no run-time art.
static func spec(item: Dictionary) -> Dictionary:
	var raw: Variant = item.get("held", {})
	if not raw is Dictionary: return {}
	var out: Dictionary = {}
	for key: Variant in raw:
		var value: Variant = raw[key]
		if value is Array and (value as Array).size() == 2 and _is_number(value[0]) and _is_number(value[1]):
			out[str(key)] = Vector2(float(value[0]), float(value[1]))
		elif _is_number(value):
			out[str(key)] = float(value)
		elif value is Vector2 or value is String or value is bool:
			out[str(key)] = value
	return out


## True when rig `rig` (a RigLibrary rig) has an item with a held block.
static func holds(rig: Dictionary) -> bool:
	for item: Dictionary in rig.get("items", []):
		if not spec(item).is_empty(): return true
	return false


## The motion that carries a held piece along with its parent part: the part's
## change from `rest` (its transform with the figure standing still) to `posed`
## (as drawn now), taken at `pivot` (world px, the hand) and kept rigid: the
## hand goes where the part takes that point, the art turns as far as the part
## turns, and never stretches with the part's squash. IDENTITY when the part
## did not move.
static func follow(rest: Transform2D, posed: Transform2D, pivot: Vector2) -> Transform2D:
	if posed == rest: return Transform2D.IDENTITY
	var change := posed * rest.affine_inverse()
	var turn := atan2(change.x.y, change.x.x)
	return Transform2D(turn, change * pivot) * Transform2D(0.0, -pivot)


## A copy of `piece` carried by `follow`: its hand moved, its angle turned.
static func place(piece: Dictionary, follow_xform: Transform2D) -> Dictionary:
	var out := piece.duplicate()
	if follow_xform == Transform2D.IDENTITY: return out
	out.hand = follow_xform * Vector2(piece.get("hand", Vector2.ZERO))
	out.angle = float(piece.get("angle", 0.0)) + atan2(follow_xform.x.y, follow_xform.x.x)
	return out


## Draws `piece` carried by `follow` at the figure's `alpha`: its "under"
## effects, the art turned about its hand, its "over" effects (both with the
## canvas under `follow`). Returns the placed piece (see place). Leaves the
## canvas transform at identity.
static func draw(canvas: CanvasItem, piece: Dictionary, follow_xform: Transform2D, alpha: float = 1.0) -> Dictionary:
	var placed := place(piece, follow_xform)
	var under: Variant = piece.get("under")
	if under is Callable and (under as Callable).is_valid():
		canvas.draw_set_transform_matrix(follow_xform)
		(under as Callable).call(canvas, follow_xform)
	var texture: Variant = piece.get("texture")
	if texture is Texture2D:
		var tint: Color = piece.get("tint", Color.WHITE)
		canvas.draw_set_transform(Vector2(placed.hand), float(placed.angle), Vector2.ONE)
		canvas.draw_texture_rect(texture, Rect2(piece.get("rect", Rect2())), false, Color(tint, tint.a * alpha))
	var over: Variant = piece.get("over")
	if over is Callable and (over as Callable).is_valid():
		canvas.draw_set_transform_matrix(follow_xform)
		(over as Callable).call(canvas, follow_xform)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	return placed


## The figure's outline round `piece` carried by `follow`: its silhouette in
## `color`, shifted by each of `offsets` (art px, the rig's ring). Nothing for
## a piece with "outline" false or without art. Leaves the canvas transform at
## identity.
static func draw_outline(canvas: CanvasItem, piece: Dictionary, follow_xform: Transform2D, color: Color, offsets: Array = RING_DEFAULT) -> void:
	var texture: Variant = piece.get("texture")
	if color.a <= 0.0 or not bool(piece.get("outline", true)) or not texture is Texture2D: return
	var white := silhouette(texture)
	var rect: Rect2 = piece.get("rect", Rect2())
	var art := (texture as Texture2D).get_size()
	var k := Vector2(rect.size.x / maxf(1.0, art.x), rect.size.y / maxf(1.0, art.y))
	var placed := place(piece, follow_xform)
	canvas.draw_set_transform(Vector2(placed.hand), float(placed.angle), Vector2.ONE)
	for offset: Vector2 in offsets:
		canvas.draw_texture_rect(white, Rect2(rect.position + offset * k, rect.size), false, color)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## The white silhouette of `texture` (opaque from alpha 0.5, like the rig's
## parts), made once and kept.
static func silhouette(texture: Texture2D) -> Texture2D:
	if _white.has(texture): return _white[texture]
	var image := texture.get_image()
	if image == null: return texture
	image = image.duplicate() as Image
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			image.set_pixel(x, y, Color(1, 1, 1, alpha) if alpha >= 0.5 else Color(1, 1, 1, 0))
	var white := ImageTexture.create_from_image(image)
	_white[texture] = white
	return white


## Where an item of draw order `z` goes in `layers` (parts and items sorted by
## z): after every layer whose z is not above it, so it never changes the
## order of the others and two held items of the same z keep theirs.
static func slot(layers: Array, z: int) -> int:
	var at := 0
	for i in range(layers.size()):
		if int((layers[i] as Dictionary).get("z", 0)) <= z: at = i + 1
	return at


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
