extends SceneTree
## Void atmosphere of the crypt (assets/data/vfx_crypt_atmosphere.json,
## src/vfx/crypt_atmosphere.gd): the shipped file loads with every value in
## range, gaps fall back to the defaults, bad values are clamped or dropped,
## flames only take colours of the 0x72 violet ramp and keep their exact
## pixel shapes, and the dark crypt gets the atmosphere's darkness.
## Usage: godot --headless --path . -s tests/vfx_crypt_atmosphere_test.gd

const Atmosphere = preload("res://src/vfx/crypt_atmosphere.gd")
const Crypt72 = preload("res://src/crypt_0x72_art.gd")
const PROPS := "res://assets/sprites/crypt_props/"
const DECOR := "res://assets/sprites/decor/"
## The orange flame colours of the 0x72 torch, candle and fire frames.
const ORANGE := ["da4e38", "c56025", "8f4029", "ee8e2e", "facb3e"]

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("CRYPT_ATMOSPHERE_FAIL: ", label)


func _initialize() -> void:
	_test_shipped_file_loads_with_values_in_range()
	_test_missing_keys_fall_back_to_defaults()
	_test_missing_file_gives_defaults()
	_test_out_of_range_values_are_clamped()
	_test_bad_colours_and_foreign_flame_colours_are_dropped()
	_test_fog_layers_are_capped()
	_test_flames_turn_violet_with_the_same_pixels()
	_test_crypt_art_uses_violet_flame_frames()
	_test_candle_content_fits_the_drawn_region()
	_test_darkness_override_keeps_other_lighting()
	print("CRYPT_ATMOSPHERE checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_shipped_file_loads_with_values_in_range() -> void:
	# Arrange
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(Atmosphere.DATA_PATH))
	# Act
	var data := Atmosphere.load_data()
	# Assert
	check(raw is Dictionary, "the shipped file is a JSON object")
	check(data.get("enabled") is bool, "enabled is a bool")
	for section: String in ["grade", "darkness", "fog", "flames"]:
		check(data.get(section) is Dictionary, "section %s exists" % section)
		check(raw is Dictionary and (raw as Dictionary).has(section), "the shipped file names section %s itself" % section)
	for section: String in Atmosphere.RANGES:
		for key: String in Atmosphere.RANGES[section]:
			var limits: Array = Atmosphere.RANGES[section][key]
			var given: Variant = (raw as Dictionary).get(section, {}).get(key) if raw is Dictionary else null
			check(given is float, "%s.%s is a number in the file" % [section, key])
			check(given is float and float(given) >= float(limits[0]) and float(given) <= float(limits[1]), "%s.%s lies in %s" % [section, key, limits])
	check(data.grade.tint_color is Color and data.fog.color is Color and data.flames.light_color is Color and data.darkness.shade_color is Color, "colours become Color")
	var layers: Array = data.fog.layers
	check(layers.size() >= 1 and layers.size() <= Atmosphere.MAX_FOG_LAYERS, "the fog has 1..3 layers")
	check(layers.all(func(layer: Variant) -> bool: return layer is Vector4 and layer.x >= 16.0 and layer.w > 0.0), "fog layers are Vector4(scale, wind, weight)")
	check(float(data.fog.density) <= 0.25, "the fog stays faint (density <= 0.25)")
	check(float(data.darkness.strength) > 0.2, "the crypt gets darker than balance.json's 0.2")
	check(data.flames.recolor.size() == raw.flames.recolor.size(), "every shipped flame colour is a ramp colour")


func _test_missing_keys_fall_back_to_defaults() -> void:
	# Arrange
	var defaults := Atmosphere.parse(Atmosphere.DEFAULTS)
	# Act
	var data := Atmosphere.parse({"grade": {"exposure": 0.7}})
	# Assert
	check(is_equal_approx(float(data.grade.exposure), 0.7), "a given value is kept")
	check(is_equal_approx(float(data.grade.contrast), float(defaults.grade.contrast)), "a missing grade value is the default")
	check(data.fog.layers == defaults.fog.layers, "missing fog layers are the default layers")
	check(data.flames.recolor == defaults.flames.recolor, "a missing recolor map is the default map")
	check(bool(data.enabled), "a missing enabled flag means on")


func _test_missing_file_gives_defaults() -> void:
	# Act
	var data := Atmosphere.load_data("res://tests/fixtures/no_such_atmosphere.json")
	# Assert
	check(data == Atmosphere.parse({}), "a missing file gives the defaults")


func _test_out_of_range_values_are_clamped() -> void:
	# Act
	var data := Atmosphere.parse({"grade": {"exposure": 9.0, "contrast": 0.0}, "fog": {"density": -1.0, "bands": 99.0}, "darkness": {"strength": "dunkel"}})
	# Assert
	check(is_equal_approx(float(data.grade.exposure), 1.5), "exposure is clamped to 1.5")
	check(is_equal_approx(float(data.grade.contrast), 0.5), "contrast is clamped to 0.5")
	check(is_equal_approx(float(data.fog.density), 0.0), "density is clamped to 0")
	check(is_equal_approx(float(data.fog.bands), 16.0), "bands are clamped to 16")
	check(is_equal_approx(float(data.darkness.strength), float(Atmosphere.DEFAULTS.darkness.strength)), "a non-number falls back to the default")


func _test_bad_colours_and_foreign_flame_colours_are_dropped() -> void:
	# Act
	var data := Atmosphere.parse({"grade": {"tint_color": "lila"}, "flames": {"recolor": {"da4e38": "ff0000", "#EE8E2E": "#C278D0", "zz": "8156aa"}}})
	# Assert
	check(data.grade.tint_color == Color(str(Atmosphere.DEFAULTS.grade.tint_color)), "an unreadable colour falls back to the default")
	check(not data.flames.recolor.has("da4e38"), "a target outside the violet ramp is dropped")
	check(data.flames.recolor.get("ee8e2e") == Color("c278d0"), "keys and targets are read without # and case")
	check(data.flames.recolor.size() == 1, "an unreadable source colour is dropped")


func _test_fog_layers_are_capped() -> void:
	# Arrange
	var many: Array = []
	for i in range(5): many.append({"scale": 100.0 + i, "wind": [1.0, 2.0], "weight": 0.5})
	# Act
	var data := Atmosphere.parse({"fog": {"layers": many + ["kaputt"]}})
	var broken := Atmosphere.parse({"fog": {"layers": [{"scale": "groß", "wind": [1.0]}]}})
	# Assert
	check(data.fog.layers.size() == Atmosphere.MAX_FOG_LAYERS, "at most three fog layers")
	check(data.fog.layers[0] == Vector4(100.0, 1.0, 2.0, 0.5), "a layer becomes Vector4(scale, wind x, wind y, weight)")
	check(broken.fog.layers.size() == 1 and broken.fog.layers[0] == Vector4(160.0, 0.0, 0.0, 1.0), "a broken layer gets safe values")


func _test_flames_turn_violet_with_the_same_pixels() -> void:
	# Arrange
	var mapping: Dictionary = Atmosphere.load_data().flames.recolor
	var paths: Array[String] = []
	for i in range(8):
		paths.append(PROPS + "wall_torch_f%d.png" % i)
		paths.append(PROPS + "candle_column_f%d.png" % i)
		paths.append(DECOR + "fire_f%d.png" % i)
	var orange_left := 0
	var shapes_kept := true
	var violet := 0
	for path: String in paths:
		var source: Image = (load(path) as Texture2D).get_image()
		source.convert(Image.FORMAT_RGBA8)
		# Act
		var repainted := Atmosphere.recolor(source, mapping)
		# Assert (collected)
		for y in range(source.get_height()):
			for x in range(source.get_width()):
				var before := source.get_pixel(x, y)
				var after := repainted.get_pixel(x, y)
				if not is_equal_approx(before.a, after.a): shapes_kept = false
				if after.a <= 0.0: continue
				var html := after.to_html(false)
				if html in ORANGE: orange_left += 1
				if before.to_html(false) in ORANGE and html in Atmosphere.VIOLET_RAMP: violet += 1
	check(orange_left == 0, "no orange flame pixel is left (%d left)" % orange_left)
	check(shapes_kept, "every frame keeps its exact pixel shape (alpha unchanged)")
	check(violet > 500, "the flames are repainted in the violet ramp (%d px)" % violet)


func _test_crypt_art_uses_violet_flame_frames() -> void:
	# Arrange
	var art := Crypt72.new()
	var mapping: Dictionary = Atmosphere.load_data().flames.recolor
	# Act
	art.use_flame_colors(mapping, true)
	# Assert
	var frames: Array = [art._torch_frames[0], art._candle_frames[0], art._fire_frames[0]]
	for frame: Texture2D in frames:
		var image := frame.get_image()
		var seen := {}
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).a > 0.0: seen[image.get_pixel(x, y).to_html(false)] = true
		check(not seen.keys().any(func(c: String) -> bool: return c in ORANGE), "the crypt draws violet frames (%s)" % frame.resource_path)
		check(seen.keys().any(func(c: String) -> bool: return c in ["8156aa", "993970", "5f2d56"]), "the frame carries violet flame pixels")
	check(art._torch_frames.size() == Crypt72.FRAMES and art._candle_frames.size() == Crypt72.FRAMES, "all eight frames stay")


func _test_candle_content_fits_the_drawn_region() -> void:
	# The candle frames are drawn from CANDLE_REGION into PROP_SIZE at 2x: the
	# region must have the target's size (else the 16x32 column is squashed
	# into 16x24 and loses pixel rows) and hold everything visible.
	check(Crypt72.CANDLE_REGION.size == Crypt72.PROP_SIZE, "candle columns are drawn unsquashed (%s into %s)" % [Crypt72.CANDLE_REGION.size, Crypt72.PROP_SIZE])
	for i in range(8):
		var image: Image = (load(PROPS + "candle_column_f%d.png" % i) as Texture2D).get_image()
		var used := image.get_used_rect()
		check(Rect2i(Crypt72.CANDLE_REGION).encloses(used), "candle frame %d fits the drawn 16x24 region (%s)" % [i, used])


func _test_darkness_override_keeps_other_lighting() -> void:
	# Arrange
	var lighting := {"darkness": 0.2, "player_radius": 220, "torch_radius": 120}
	var data := Atmosphere.parse({"darkness": {"strength": 0.4, "shade_color": "#0d0818"}})
	# Act
	var merged := Atmosphere.lighting_with_darkness(lighting, data)
	# Assert
	check(is_equal_approx(float(merged.darkness), 0.4), "the atmosphere sets the darkness")
	check(merged.shade_color == Color("0d0818"), "the atmosphere sets the shade colour")
	check(int(merged.player_radius) == 220 and int(merged.torch_radius) == 120, "other lighting values stay")
	check(is_equal_approx(float(lighting.darkness), 0.2), "balance.json's lighting is not changed")
