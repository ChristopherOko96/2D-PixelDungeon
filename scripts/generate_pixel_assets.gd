extends SceneTree
## Rebuilds the project's original 32 × 32 source sprites without external art.
## Run: Godot --headless --path . --script scripts/generate_pixel_assets.gd
## All drawing uses integer source pixels; PNGs are versioned alongside this source.

const OUTPUT := "res://assets/sprites/"
const INK := Color("#141321")
const SKIN := Color("#e7bb9b")
const GOLD := Color("#efc76a")
const COLORS := [Color("#72dcc8"), Color("#edb563"), Color("#bc91de"), Color("#ed8a91")]

var _failed: bool = false


func _initialize() -> void:
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Cannot create sprite directory: %s" % error_string(error))
		quit(1)
		return
	for index: int in range(COLORS.size()):
		_save(_player(COLORS[index]), "player_%d.png" % (index + 1))
	_save(_slime(), "slime.png")
	_save(_boss(), "boss.png")
	_save(_torch(), "torch.png")
	_save(_floor_stone(), "floor_stone.png")
	if _failed:
		quit(1)
		return
	print("PIXEL_ASSETS_GENERATED files=8 source_size=32x32")
	quit()


func _canvas() -> Image:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image


func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for py: int in range(maxi(0, y), mini(32, y + height)):
		for px: int in range(maxi(0, x), mini(32, x + width)):
			image.set_pixel(px, py, color)


func _save(image: Image, filename: String) -> void:
	var error: Error = image.save_png(OUTPUT + filename)
	if error != OK:
		push_error("Cannot write %s: %s" % [filename, error_string(error)])
		_failed = true


func _player(color: Color) -> Image:
	var image := _canvas()
	# Compact hood silhouette with two-pixel stair steps around the crown.
	_rect(image, 8, 2, 15, 3, INK)
	_rect(image, 5, 5, 21, 13, INK)
	_rect(image, 7, 3, 17, 15, color.darkened(0.22))
	_rect(image, 10, 3, 11, 3, color.lightened(0.2))
	_rect(image, 6, 7, 4, 9, color)
	_rect(image, 9, 8, 14, 10, SKIN)
	_rect(image, 9, 8, 3, 10, Color("#bd8e83"))
	_rect(image, 12, 11, 2, 3, INK)
	_rect(image, 19, 11, 2, 3, INK)
	_rect(image, 16, 15, 3, 1, Color("#ac7978"))
	_rect(image, 7, 17, 18, 12, INK)
	_rect(image, 9, 19, 14, 9, color.darkened(0.35))
	_rect(image, 7, 17, 18, 4, color)
	_rect(image, 9, 18, 11, 1, color.lightened(0.25))
	_rect(image, 21, 20, 3, 6, color.darkened(0.15))
	_rect(image, 4, 19, 5, 7, INK)
	_rect(image, 5, 20, 4, 4, color.darkened(0.2))
	_rect(image, 5, 24, 4, 3, SKIN)
	_rect(image, 24, 19, 4, 8, INK)
	_rect(image, 23, 23, 4, 4, SKIN)
	_rect(image, 9, 26, 14, 3, Color("#72515f"))
	_rect(image, 14, 26, 4, 3, GOLD)
	_rect(image, 8, 29, 7, 3, INK)
	_rect(image, 18, 29, 7, 3, INK)
	_rect(image, 9, 29, 5, 1, Color("#675367"))
	_rect(image, 19, 29, 5, 1, Color("#675367"))
	return image


func _slime() -> Image:
	var image := _canvas()
	var color := Color("#bd6f9d")
	_rect(image, 8, 6, 16, 4, INK)
	_rect(image, 5, 10, 22, 3, INK)
	_rect(image, 2, 13, 28, 15, INK)
	_rect(image, 5, 27, 22, 3, INK)
	_rect(image, 8, 9, 16, 5, color)
	_rect(image, 5, 13, 22, 12, color.darkened(0.1))
	_rect(image, 3, 19, 26, 7, color.darkened(0.3))
	_rect(image, 6, 25, 20, 3, color.darkened(0.2))
	_rect(image, 9, 10, 6, 2, color.lightened(0.35))
	_rect(image, 7, 16, 7, 7, Color("#fff0d7"))
	_rect(image, 19, 16, 7, 7, Color("#fff0d7"))
	_rect(image, 11, 17, 3, 5, INK)
	_rect(image, 19, 17, 3, 5, INK)
	_rect(image, 14, 24, 5, 2, INK)
	_rect(image, 4, 26, 5, 2, color)
	_rect(image, 24, 26, 5, 2, color)
	return image


func _boss() -> Image:
	var image := _canvas()
	var color := Color("#b982d3")
	_rect(image, 6, 11, 21, 5, INK)
	_rect(image, 3, 16, 27, 12, INK)
	_rect(image, 6, 27, 21, 4, INK)
	_rect(image, 7, 13, 19, 14, color)
	_rect(image, 4, 20, 25, 7, color.darkened(0.3))
	_rect(image, 7, 27, 19, 2, color.darkened(0.2))
	_rect(image, 8, 14, 7, 2, color.lightened(0.3))
	_rect(image, 7, 18, 7, 6, Color("#fff0d7"))
	_rect(image, 19, 18, 7, 6, Color("#fff0d7"))
	_rect(image, 11, 18, 3, 5, INK)
	_rect(image, 19, 18, 3, 5, INK)
	_rect(image, 13, 26, 7, 2, INK)
	# Three-point crown identifies the boss even without the health bar.
	_rect(image, 6, 3, 5, 9, INK)
	_rect(image, 14, 1, 5, 11, INK)
	_rect(image, 22, 3, 5, 9, INK)
	_rect(image, 7, 8, 19, 5, INK)
	_rect(image, 7, 4, 3, 7, GOLD)
	_rect(image, 15, 2, 3, 9, GOLD)
	_rect(image, 23, 4, 3, 7, GOLD)
	_rect(image, 8, 9, 17, 3, GOLD.darkened(0.1))
	_rect(image, 15, 9, 3, 3, Color("#e58079"))
	return image


func _torch() -> Image:
	var image := _canvas()
	_rect(image, 12, 23, 8, 9, INK)
	_rect(image, 14, 23, 4, 8, Color("#9d6d62"))
	_rect(image, 7, 19, 18, 6, INK)
	_rect(image, 8, 19, 16, 4, Color("#a9866d"))
	_rect(image, 9, 20, 13, 1, Color("#e8ba7f"))
	_rect(image, 10, 9, 12, 10, Color("#cc6246"))
	_rect(image, 12, 5, 8, 14, Color("#ee9251"))
	_rect(image, 16, 1, 3, 8, Color("#f5ac5f"))
	_rect(image, 13, 9, 5, 10, Color("#f9c575"))
	_rect(image, 15, 14, 4, 5, Color("#fff0ac"))
	return image


func _floor_stone() -> Image:
	var image := _canvas()
	image.fill(Color("#242334"))
	_rect(image, 1, 1, 30, 30, Color("#363348"))
	_rect(image, 2, 2, 28, 2, Color("#454057"))
	_rect(image, 2, 29, 28, 2, Color("#292638"))
	_rect(image, 29, 4, 2, 25, Color("#302b40"))
	_rect(image, 7, 9, 5, 1, Color("#494056"))
	_rect(image, 24, 23, 3, 2, Color("#51445b"))
	_rect(image, 18, 17, 4, 1, Color("#312b40"))
	return image
