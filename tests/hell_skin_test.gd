extends SceneTree
## The 0x72 hell skin (assets/sprites/hell_0x72 from scripts/make_hell_skin.gd):
## every sprite the hell draws exists, keeps the sizes the runtime relies on,
## uses only the hell palette, and is made of whole pixels (3 x 3 blocks, a few
## pickups 4 or 5 because the game draws them smaller), so nothing is smeared.
## The hell runs on it with sharp pixels; the Frostgruft keeps its own drawing.

const HellSkin = preload("res://scripts/make_hell_skin.gd")
const HellGame = preload("res://src/hell/hell_game.gd")
const DIR := "res://assets/sprites/hell_0x72/"
const OLD_MANIFEST := "res://assets/sprites/hell/manifest.json"
## Pixel size per sprite where it is not 3 (pickups the game scales down).
const BLOCK := {"heart": 4, "icon_scroll": 4, "icon_demon_big": 4, "rune_gem": 5}
## Figures, not level art: the key room's merchant is the same 0x72 figure in every world, drawn at
## the hero's scale like the hero (hell_game.gd), so its own colours and 1 px pixels stay.
const FIGURES := ["npc_idle_f0", "npc_idle_f1", "npc_idle_f2", "npc_idle_f3"]
## Sizes the hell runtime and core hard-code (hell_walls.gd, hell_game.gd).
const FIXED := {"wall_h": Vector2i(-1, 74), "wall_v": Vector2i(62, -1), "corner_cap": Vector2i(76, 76), "wall_top": Vector2i(96, 96),
	"lava_00": Vector2i(96, 96), "lava_01": Vector2i(96, 96), "lava_edge_top": Vector2i(96, 96)}

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("HELL_SKIN_FAIL: ", label)


func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "manifest.json"))
	var images := {}
	for n: String in manifest:
		var im := Image.load_from_file(ProjectSettings.globalize_path(DIR + n + ".png"))
		if im != null:
			im.convert(Image.FORMAT_RGBA8)
			images[n] = im
	_test_every_hell_name_has_a_sprite(manifest, images)
	_test_runtime_sizes_hold(images)
	_test_only_hell_palette_colours(images)
	_test_whole_pixels_only(images)
	_test_hell_uses_the_skin_with_sharp_pixels()
	print("HELL_SKIN checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_every_hell_name_has_a_sprite(manifest: Dictionary, images: Dictionary) -> void:
	# Arrange
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OLD_MANIFEST))
	# Act
	var missing := old.keys().filter(func(n: String) -> bool: return not manifest.has(n) or not images.has(n))
	# Assert
	check(missing.is_empty(), "every hell sprite name has a 0x72 sprite (%s)" % str(missing))
	check(images.size() == manifest.size(), "every manifest entry loads")


func _test_runtime_sizes_hold(images: Dictionary) -> void:
	for n: String in FIXED:
		var want: Vector2i = FIXED[n]
		var im: Image = images.get(n)
		var ok := im != null and (want.x < 0 or im.get_width() == want.x) and (want.y < 0 or im.get_height() == want.y)
		check(ok, "%s keeps the size the runtime draws it at (%s)" % [n, str(want)])
	for i in range(12):
		var n := "floor_%02d" % i
		var im: Image = images.get(n)
		check(im != null and im.get_size() == Vector2i(96, 96) and not im.detect_alpha(), "%s is one opaque 96 px cell" % n)


func _test_only_hell_palette_colours(images: Dictionary) -> void:
	# Arrange
	var palette := {}
	for k: String in HellSkin.HEX:
		palette[Color.html(HellSkin.HEX[k]).to_html(false)] = true
	# Act
	var strays := {}
	for n: String in images:
		if n in FIGURES:
			continue
		var im: Image = images[n]
		for y in range(im.get_height()):
			for x in range(im.get_width()):
				var c := im.get_pixel(x, y)
				if c.a > 0.5 and not palette.has(c.to_html(false)):
					strays[n] = c.to_html(false)
	# Assert
	check(strays.is_empty(), "every pixel is a hell palette colour (%s)" % str(strays))


## True when the image splits into k x k blocks of one colour at some grid offset.
func _blocky(im: Image, k: int) -> bool:
	for oy in range(k):
		for ox in range(k):
			var clean := true
			var by := -oy
			while clean and by < im.get_height():
				var bx := -ox
				while clean and bx < im.get_width():
					var first := Color(0, 0, 0, -1)
					for y in range(maxi(by, 0), mini(by + k, im.get_height())):
						for x in range(maxi(bx, 0), mini(bx + k, im.get_width())):
							var c := im.get_pixel(x, y)
							if c.a < 0.5:
								c = Color(0, 0, 0, 0)
							if first.a < -0.5:
								first = c
							elif not c.is_equal_approx(first):
								clean = false
					bx += k
				by += k
			if clean:
				return true
	return false


func _test_whole_pixels_only(images: Dictionary) -> void:
	var smeared: Array = []
	for n: String in images:
		if n in FIGURES:
			continue
		if not _blocky(images[n], int(BLOCK.get(n, HellSkin.K))):
			smeared.append(n)
	check(smeared.is_empty(), "every sprite is made of whole 0x72 pixels (%s)" % str(smeared))


func _test_hell_uses_the_skin_with_sharp_pixels() -> void:
	# Arrange
	var look: Dictionary = HellGame.THEME_DEFAULT
	var frost: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/frost_theme.json"))
	# Assert
	check(str(look.sprites) == DIR and bool(look.pixel) and bool(look.pixel_tiles), "the hell look is the 0x72 skin with sharp pixels and 1:1 tiles")
	check(is_equal_approx(float(look.hero_scale), float(HellSkin.K)), "the hero is drawn at the skin's pixel size")
	check(not bool(frost.get("pixel_tiles", true)), "the Frostgruft keeps its own liquid and bridge drawing")
