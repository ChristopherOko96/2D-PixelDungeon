extends SceneTree
const Field = preload("res://src/vfx/soul_field.gd")
class Recorder extends RefCounted:
	var weights: Array[float] = []
	var parts: Array = []
	func draw_external_frame(_canvas: CanvasItem, _key: String, _texture: Texture2D, _at: Vector2, _anchor: Vector2, _scale: float, tint: Color = Color.WHITE) -> void:
		weights.append(tint.a)
	func draw_external_rig(_canvas: CanvasItem, entries: Array, _ground: Vector2) -> void:
		parts.append_array(entries)
var failures := 0
var count := 0
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures += 1
		printerr("SOUL_FIELD_FAIL: ", label)
func _initialize() -> void:
	Field.prepare()
	var unique := {}
	check(Field._frames.size() == 24, "24 distinct animation frames prepared")
	for frame in range(24):
		check(Field.frame_index(frame * 0.055 + 0.001) == frame, "new intermediate frame at 55ms")
		if frame >= Field._frames.size(): continue
		var image := Field._frames[frame].get_image()
		unique[hash(image.get_data())] = true
		check(image.get_pixel(0, 0).a == 0.0, "backdrop transparent")
		check(image.get_size() == Vector2i(256, 256), "source proportions retained")
	check(Field.frame_index(1.320001) == 0, "same 1.32s loop wraps")
	check(unique.size() == 24, "all 24 frames contain different art, no repeated holds")
	check(Field.frame_index(2.0) == 12, "late snapshot samples existing loop")
	var first := Field._frames[0] if not Field._frames.is_empty() else null
	Field.prepare()
	check(not Field._frames.is_empty() and first == Field._frames[0], "textures reused")
	var canvas := Node2D.new()
	var recorder := Recorder.new()
	Field.draw(canvas, Vector2.ZERO, 115.2, 0.0275, recorder, "test", true, 0.4)
	check(recorder.weights.is_empty(), "live ghost overlay draws no old whole-sheet frames")
	var heads := 0
	var bounded := true
	for part: Dictionary in recorder.parts:
		if str(part.id) == "head": heads += 1
		if float(part.tint.a) > 0.40001: bounded = false
	check(heads == 5 and bounded, "five rig ghosts retain the field appearance/exit fade")
	canvas.free()
	print("SOUL_FIELD checked=%d failures=%d" % [count, failures])
	quit(1 if failures else 0)
