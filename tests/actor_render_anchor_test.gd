extends SceneTree
## GPU regression: transparent atlas padding must not move the feet under recoil.
class Probe extends "res://src/dungeon_view.gd":
	var fixture: Texture2D
	var legacy: Texture2D
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_process(false)
		var pixels := Image.create(16,32,false,Image.FORMAT_RGBA8)
		pixels.fill_rect(Rect2i(6,4,4,16),Color.BLUE)
		pixels.fill_rect(Rect2i(7,20,2,1),Color.MAGENTA)
		fixture = ImageTexture.create_from_image(pixels)
		legacy = ImageTexture.create_from_image(pixels.get_region(Rect2i(0,0,16,21)))
	func _draw() -> void:
		draw_rect(Rect2(0,0,520,180),Color("101019"))
		var poses := [{"scale":Vector2.ONE},{"scale":Vector2(1.3,0.5)},{"scale":Vector2(1.2,0.7),"lean":0.3},{"scale":Vector2(0.8,1.2),"lean":-0.25,"offset":Vector2(4,-2)}]
		for index: int in range(4):
			_draw_sprite(fixture,Vector2(60+100*index,100),1.0,38.0,poses[index],2.0,null,Vector2(8,21))
		_draw_sprite(legacy,Vector2(460,100),1.0,16.0,{"scale":Vector2(1.3,0.5)},2.0)

var failures: Array[String] = []
var checks: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("ACTOR_ANCHOR_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(520,180)
	root.content_scale_size = Vector2i.ZERO
	var probe := Probe.new()
	root.add_child(probe)
	await process_frame
	await RenderingServer.frame_post_draw
	var captured: Image = root.get_texture().get_image()
	var expected := [Vector2(60,116),Vector2(160,116),Vector2(260,116),Vector2(364,114),Vector2(460,116)]
	for index: int in range(expected.size()):
		var center := Vector2.ZERO
		var count: int = 0
		for y: int in range(captured.get_height()):
			for x: int in range(index*100+10,index*100+100):
				var pixel: Color = captured.get_pixel(x,y)
				if pixel.r > 0.9 and pixel.b > 0.9 and pixel.g < 0.1:
					center += Vector2(x+0.5,y+0.5)
					count += 1
		check(count > 0,"visible foot marker in rendered variant%d"%index)
		if count > 0:
			center /= count
			check(center.distance_to(expected[index]) < 3.0,"padding preserves the foot anchor under squash/lean/offset variant%d: observed%s expected%s"%[index,center,expected[index]])
	var args := OS.get_cmdline_user_args()
	var capture_index: int = args.find("--capture")
	if capture_index >= 0 and capture_index+1 < args.size(): captured.save_png(args[capture_index+1])
	print("ACTOR_ANCHOR checked=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
