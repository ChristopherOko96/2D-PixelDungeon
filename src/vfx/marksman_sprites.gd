extends RefCounted
## Approved attack cutouts. Textures are cached once; all calls only draw snapshot data.
const ROOT := "res://assets/sprites/marksman/"
const ARROWS := {"sniper_1":"aimed_arrow", "sniper_3":"piercing_arrow", "sniper_7":"volley_arrow"}
static var _textures: Dictionary = {}

## Returns a native imported sprite, retaining the same texture between draws.
static func texture(name: String) -> Texture2D:
	if not _textures.has(name): _textures[name] = load("res://assets/sprites/0x72/weapon_arrow.png" if name == "basic_arrow" else ROOT + name + ".png")
	return _textures[name]

## The native art in one rigid part, compatible with the existing wall clipper.
static func part(name: String, at: Vector2, angle: float, art: float, alpha := 1.0) -> Dictionary:
	var tex := texture(name)
	var anchor := tex.get_size() * 0.5
	var matrix := Transform2D(Vector2.from_angle(angle)*art,Vector2.from_angle(angle+PI*0.5)*art,at)
	matrix = matrix * Transform2D(0,-anchor)
	return {"id":name,"texture":tex,"bounds":Rect2(Vector2.ZERO,tex.get_size()),"transform":matrix,"tint":Color(1,1,1,alpha)}

## A cutout uses the same world-pixel scale and wall clipping as the surrounding effects.
static func draw(canvas: CanvasItem, name: String, at: Vector2, angle: float, art: float, sprites: RefCounted = null, alpha := 1.0, ground := Vector2.INF) -> void:
	if alpha <= 0: return
	var layer := part(name,at.snapped(Vector2.ONE*art),angle,art,alpha)
	if sprites != null:
		sprites.draw_external_rig(canvas,[layer],ground if ground.is_finite() else at)
	else:
		canvas.draw_set_transform_matrix(layer.transform)
		canvas.draw_texture(layer.texture,Vector2.ZERO,layer.tint)
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

## The three projectile abilities keep distinct arrowheads and fletching.
static func arrow(canvas: CanvasItem, talent: String, at: Vector2, aim: Vector2, art: float, sprites: RefCounted = null, ground := Vector2.INF) -> bool:
	if not ARROWS.has(talent): return false
	draw(canvas,str(ARROWS[talent]),at,aim.angle()+PI*0.5,art,sprites,1.0,ground)
	return true

## Brief native spark, followed by two outward splinter frames; no lasting false hit area.
static func impact(canvas: CanvasItem, at: Vector2, p: float, art: float, sprites: RefCounted = null) -> void:
	if p < 0 or p >= 1: return
	var name := "hit_small" if p < 0.18 else ("hit_large" if p < 0.4 else ("chips_a" if p < 0.7 else "chips_b"))
	draw(canvas,name,at,0,art,sprites,1.0-smoothstep(0.55,1,p))

## A real Pfeilhagel arrow falls point-first and leaves a short native impact.
static func hail(canvas: CanvasItem, at: Vector2, p: float, art: float, sprites: RefCounted) -> void:
	if not sprites.open(at): return
	if p < 0.3:
		var point := at + Vector2(6,-50)*art*(1.0-p/0.3)
		draw(canvas,"hail_arrow",point,PI,art,sprites,1.0,at)
	else:
		impact(canvas,at,(p-0.3)/0.7,art,sprites)

## Takeoff and landing dust follow the backflip's actual clamped endpoints.
static func backflip(canvas: CanvasItem, from: Vector2, to: Vector2, p: float, art: float, sprites: RefCounted) -> void:
	draw(canvas,"dust_a" if p < 0.3 else "dust_b",from,0,art,sprites,1.0-p)
	if p > 0.55: draw(canvas,"dust_a" if p < 0.8 else "dust_b",to,0,art,sprites,1.0-smoothstep(0.8,1,p))
