@tool
extends RefCounted
## Composes the original full/half/empty icons into one transparent health image.

const SHEET := preload("res://assets/ui/asset_sheet_ui.png")
const FULL := Rect2i(36, 5, 9, 8)
const HALF := Rect2i(52, 5, 9, 8)
const EMPTY := Rect2i(68, 5, 9, 8)
const PITCH := 12

## Native 1x artwork; callers display the complete strip with integer scaling.
## Zero capacity returns a transparent pixel. Numeric HP remains the HUD's job.
static func make_image(health: int, maximum: int, limit: int = 12) -> Image:
	var count := mini(clampi(limit, 0, 12), ceili(maxi(0, maximum) / 2.0))
	var result := Image.create(maxi(1, count * PITCH - 3), 8, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var source := SHEET.get_image()
	if source.is_compressed(): source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var remaining := clampi(health, 0, maxi(0, maximum))
	for index in range(count):
		var region := FULL if remaining >= 2 else HALF if remaining == 1 else EMPTY
		result.blit_rect(source, region, Vector2i(index * PITCH, 0))
		remaining = maxi(0, remaining - 2)
	return result
