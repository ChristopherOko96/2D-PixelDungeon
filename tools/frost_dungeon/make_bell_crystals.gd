extends SceneTree
## Makes the Kristallglocken's coloured ice crystals from the Frostgruft's ice spire picture
## (assets/sprites/frost_hd/spire_big.png): one picture per note, the ice tinted to the note's hue,
## the snow at its foot left white. Writes assets/sprites/frost_hd/bells/bell_crystal_<note>.png.
## The colours: world_frost_puzzles.json bells.crystals (note 1 first).
## Run (repo root): godot --headless --path . -s tools/frost_dungeon/make_bell_crystals.gd
const SOURCE := "res://assets/sprites/frost_hd/spire_big.png"
const OUT := "res://assets/sprites/frost_hd/bells"
const DATA := "res://assets/data/world_frost_puzzles.json"


func _initialize() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var list: Array = (cfg.get("bells", {}) as Dictionary).get("crystals", [])
	var src := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	src.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for i in range(list.size()):
		var hue := Color(str((list[i] as Dictionary).color)).h
		var im := tint(src, hue)
		var path := "%s/bell_crystal_%d.png" % [OUT, i + 1]
		im.save_png(ProjectSettings.globalize_path(path))
		print("wrote ", path)
	quit(0)


## The picture with its ice turned to `hue`: the light snow (nearly white) stays, the rest keeps its
## brightness and takes the hue, a little more saturated so each note reads at a glance.
static func tint(src: Image, hue: float) -> Image:
	var im := src.duplicate() as Image
	for y in range(im.get_height()):
		for x in range(im.get_width()):
			var c := im.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if c.s < 0.1 and c.v > 0.8:
				continue
			var s := clampf(c.s * 1.35 + 0.12, 0.3, 1.0)
			im.set_pixel(x, y, Color.from_hsv(hue, s, c.v, c.a))
	return im
