extends SceneTree
## Builds the Pyro-Monster's frames (user decision 2026-10-31): 0x72's big
## demon (assets/sprites/0x72/big_demon_idle|run_anim_f0..3.png) recoloured
## to the talent palette's fire ramp (src/vfx/talent_palette.gd "fire": deep,
## shade, body, lite, spec). The ink outline and the white eyes and teeth stay.
## The body red becomes the ramp's body, the dark red its shade; a body pixel
## right under the top outline takes the lite (lit from above), a shade pixel
## right above the bottom outline the deep (in its own shadow). The flame
## crest is NOT baked here: rig_renderer draws it from companion_rigs.json
## "burn". Writes assets/sprites/companions/pyro_demon_idle|run_f0..3.png
## (same 32x36 frames); the editor imports them on its next start.
## Usage:
##   godot --headless --path . -s res://tools/companions/build_pyro_demon.gd
const Pal = preload("res://src/vfx/talent_palette.gd")
const SRC := "res://assets/sprites/0x72/big_demon_%s_anim_f%d.png"
const OUT := "res://assets/sprites/companions/pyro_demon_%s_f%d.png"
## 0x72 big demon colours -> fire ramp index (0 deep, 1 shade, 2 body, 3 lite, 4 spec).
const RECOLOR := {"da4e38": 2, "9f294e": 1}
## Kept as they are: the ink outline and the white of eyes and teeth.
const KEEP := ["222222", "fdf7ed"]
## The 0x72 frame sets and the names the companion frames get.
const SETS := {"idle": "idle", "run": "run"}
const FRAMES := 4


func _init() -> void:
	var ramp: Array = Pal.ramp("fire")
	var written := 0
	for set_name: String in SETS:
		for index in range(FRAMES):
			var src := ProjectSettings.globalize_path(SRC % [set_name, index])
			var image := Image.load_from_file(src)
			if image == null:
				push_error("build_pyro_demon: missing %s" % src)
				continue
			image.convert(Image.FORMAT_RGBA8)
			var out := _recolor(image, ramp)
			var path := ProjectSettings.globalize_path(OUT % [SETS[set_name], index])
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var err := out.save_png(path)
			print("%s -> %s (%s)" % [src.get_file(), path.get_file(), error_string(err)])
			if err == OK: written += 1
	print("PYRO_DEMON frames written: %d of %d" % [written, SETS.size() * FRAMES])
	quit(0 if written == SETS.size() * FRAMES else 1)


## The frame in ember colours (see the file comment for the rules).
func _recolor(image: Image, ramp: Array) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var ink := Color(KEEP[0])
	for y in range(h):
		for x in range(w):
			var c := image.get_pixel(x, y)
			if c.a < 0.5: continue
			var key := c.to_html(false).to_lower()
			if key in KEEP or not RECOLOR.has(key):
				out.set_pixel(x, y, c)
				continue
			var index := int(RECOLOR[key])
			if index == 2 and _is(image, x, y - 1, ink) and _clear(image, x, y - 2): index = 3
			if index == 1 and _is(image, x, y + 1, ink) and _clear(image, x, y + 2): index = 0
			out.set_pixel(x, y, ramp[index])
	return out


func _is(image: Image, x: int, y: int, color: Color) -> bool:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height(): return false
	var c := image.get_pixel(x, y)
	return c.a >= 0.5 and c.to_html(false).to_lower() == color.to_html(false).to_lower()


func _clear(image: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height(): return true
	return image.get_pixel(x, y).a < 0.5
