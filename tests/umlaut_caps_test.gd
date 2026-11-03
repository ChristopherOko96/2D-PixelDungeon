extends SceneTree
## The capital umlauts of the UI font (src/ui/umlaut_caps.gd, src/pixel_style.gd):
## Pixel Operator 8 ships Ä Ö Ü as short letters with the dots inside the cap
## height ("RüSTUNG"); the patched face draws them as full capitals with dots
## above, keeps ä ö ü as they were, and every user of the face gets it (the UI
## font and the HUD's own preload of the same file).

const PixelStyle = preload("res://src/pixel_style.gd")
const UmlautCaps = preload("res://src/ui/umlaut_caps.gd")
const FACE_PATH := "res://assets/fonts/pixel_operator8.ttf"
var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("UMLAUT_CAPS_FAIL: ", label)


func _initialize() -> void:
	_test_original_face_has_short_capitals()
	_test_patched_capitals_are_taller_than_their_letter()
	_test_small_umlauts_keep_their_look()
	_test_hud_preload_and_ui_font_share_the_fix()
	print("UMLAUT_CAPS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## Glyph height (px at the 8 px design size) of `ch` in `font`.
func _height(font: FontFile, ch: String) -> float:
	var glyph := font.get_glyph_index(PixelStyle.BASE_SIZE, ch.unicode_at(0), 0)
	return font.get_glyph_size(0, Vector2i(PixelStyle.BASE_SIZE, 0), glyph).y


## A fresh face from the patched bytes or from `bytes`.
func _face(bytes: PackedByteArray) -> FontFile:
	var font := FontFile.new()
	font.data = bytes
	return font


## The font file's own bytes (the imported resource is patched at load); empty
## where the source file is not shipped.
func _original_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(FACE_PATH)


func _test_original_face_has_short_capitals() -> void:
	# Arrange: the font file as shipped (the bug's cause)
	var raw := _original_bytes()
	if raw.is_empty():
		check(true, "the raw font file is not readable in this build (exported); skipped")
		return
	var original := _face(raw)
	# Act / Assert: Ü is no taller than U there (dots squeezed into the cap height)
	check(_height(original, "Ü") <= _height(original, "U"), "the shipped face squeezes Ü into the cap height (the reason for RüSTUNG)")


func _test_patched_capitals_are_taller_than_their_letter() -> void:
	# Arrange
	var raw := _original_bytes()
	if raw.is_empty(): raw = (load(FACE_PATH) as FontFile).data
	var scratch := _face(raw)
	# Act
	var patched := _face(UmlautCaps.patch(raw, func(code: int) -> int: return scratch.get_glyph_index(PixelStyle.BASE_SIZE, code, 0)))
	# Assert: each capital umlaut is its full capital plus the dots above it
	for pair: Array in [["Ä", "A"], ["Ö", "O"], ["Ü", "U"]]:
		check(_height(patched, pair[0]) > _height(patched, pair[1]), "%s stands taller than %s (dots above the full capital)" % pair)
	check(_height(patched, "A") == _height(scratch, "A"), "the plain capitals stay as they were")


func _test_small_umlauts_keep_their_look() -> void:
	# Arrange
	var raw := _original_bytes()
	if raw.is_empty(): raw = (load(FACE_PATH) as FontFile).data
	var scratch := _face(raw)
	# Act
	var patched := _face(UmlautCaps.patch(raw, func(code: int) -> int: return scratch.get_glyph_index(PixelStyle.BASE_SIZE, code, 0)))
	# Assert: ö and ü were aliases of Ö and Ü in this face; they keep the small form
	for ch: String in ["ä", "ö", "ü"]:
		check(_height(patched, ch) == _height(scratch, ch), "%s keeps its small form" % ch)
		check(_height(patched, ch) < _height(patched, ch.to_upper()), "%s is smaller than %s" % [ch, ch.to_upper()])


func _test_hud_preload_and_ui_font_share_the_fix() -> void:
	# Arrange: the HUD draws with the imported face directly (hell_game FONT)
	var hud: FontFile = load(FACE_PATH)
	# Act / Assert
	check(PixelStyle.has_tall_umlauts(hud), "the HUD's preload of the face draws tall capital umlauts")
	check(PixelStyle.has_tall_umlauts(PixelStyle.create_font()), "the UI font draws tall capital umlauts")
	check(hud.get_string_size("RÜSTUNG", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x == hud.get_string_size("RUSTUNG", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, "the umlaut keeps the letter's width")
