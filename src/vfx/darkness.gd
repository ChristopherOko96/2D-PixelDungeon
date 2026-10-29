extends Node2D
## Dark crypt overlay for live runs: a shader darkens the world except inside
## light circles. The dungeon view decides which lights exist each frame
## (players, braziers, void effects) and passes them in; this node only draws.
## Values come from balance.json "lighting"; presentation only, no game rules.

const SHADER := preload("res://assets/shaders/canvas_vfx_darkness.gdshader")
const MAX_LIGHTS := 48
## The overlay reaches this far past the room so camera movement never shows an edge.
const MARGIN := 2048.0
## The shader's own shade colour, used when the lighting names none.
const SHADE := Color(0.03, 0.02, 0.06, 1.0)

var _material := ShaderMaterial.new()
var _size := Vector2(1280, 720)


func _ready() -> void:
	_material.shader = SHADER
	material = _material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_lights([])


## Room size in world pixels; the overlay covers it plus a wide margin.
func set_world_size(size: Vector2) -> void:
	if size == _size: return
	_size = size
	queue_redraw()


## Darkness strength and look from balance.json "lighting"; an optional
## "shade_color" (Color, from the crypt atmosphere) tints the dark.
func configure(lighting: Dictionary) -> void:
	_material.set_shader_parameter("darkness", float(lighting.get("darkness", 0.82)))
	var shade: Variant = lighting.get("shade_color")
	_material.set_shader_parameter("shade_color", shade if shade is Color else SHADE)


## Lights as Vector3(x, y, radius) or Vector4(x, y, radius, strength); the
## first MAX_LIGHTS are used.
func set_lights(lights: Array) -> void:
	var packed: Array[Vector4] = []
	for light: Variant in lights:
		if packed.size() >= MAX_LIGHTS: break
		if light is Vector4: packed.append(light)
		elif light is Vector3: packed.append(Vector4(light.x, light.y, light.z, 1.0))
	var count := packed.size()
	while packed.size() < MAX_LIGHTS: packed.append(Vector4.ZERO)
	_material.set_shader_parameter("lights", packed)
	_material.set_shader_parameter("light_count", count)


func _draw() -> void:
	draw_rect(Rect2(-Vector2(MARGIN, MARGIN), _size + Vector2(MARGIN, MARGIN) * 2.0), Color.WHITE)
