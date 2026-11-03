extends SceneTree
const Pal = preload("res://src/vfx/talent_palette.gd")
const Patterns = preload("res://src/vfx/soul_patterns.gd")
const Field = preload("res://src/vfx/soul_field.gd")
const Pools = preload("res://src/vfx/pool_paint.gd")
var count := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures += 1
		printerr("SOUL_DETAIL_FAIL: ", label)
func _initialize() -> void:
	for n in range(1, 15): check(Pal.element_of("soul_%d" % n) == "soul", "soul talent has own material palette")
	var config := Pools.settings()
	check(str(config.materials.soul.style) == "lava", "soul surface uses lava plates and seams")
	check(not config.materials.soul.has("void_pull"), "cosmetic pool adds no particle pull")
	var unique := {}
	for phase in range(24):
		var pixels := Patterns.wave_cells(48, phase)
		unique[hash(pixels)] = true
		var shades := {}
		var highlights := 0
		for i in range(1, pixels.size(), 2):
			shades[pixels[i]] = true
			if pixels[i] == Pal.ramp("soul")[4]: highlights += 1
		check(shades.size() >= 3 and highlights < pixels.size() / 8, "wave has shaded body and sparse highlights")
	check(unique.size() == 24, "24 different moving wave phases")
	Field.prepare()
	check(Field._ghost_frames.size() == 24, "approved ghost motion preserved")
	check(Field._ghost_frames[0].get_image().get_pixel(128, 180).a == 0.0, "old flat field removed from ghost overlay")
	for frame in range(24):
		var ghosts := Field._ghost_frames[frame].get_image()
		var clean := true
		var head_pixels := 0
		for y in range(ghosts.get_height()):
			var occupied := 0
			for x in range(ghosts.get_width()):
				var pixel := ghosts.get_pixel(x, y)
				if pixel.a > 0.0:
					occupied += 1
					if pixel.r > 0.6 and pixel.g > 0.7: head_pixels += 1
			if occupied >= 64: clean = false
		check(clean, "no old pool surface or horizontal rune band in ghost frame %d" % frame)
		check(head_pixels > 20, "ghost heads survive surface removal frame %d" % frame)
	print("SOUL_DETAIL checked=%d failures=%d" % [count, failures])
	quit(1 if failures else 0)
