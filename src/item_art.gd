@tool
extends RefCounted
## Native 16px regions from the user's original item/animation sheets.

const ITEMS: Texture2D = preload("res://assets/items/item_sheet_items.png")
const ANIMATIONS: Texture2D = preload("res://assets/items/animation_sheet_items.png")
const CHEST_OPEN_REGION := Rect2(64, 16, 16, 16)
const CLOSED_DOOR_REGION := Rect2(32, 0, 16, 16)
const PERK_REGIONS := {
	"ember": Rect2(0, 48, 16, 16),
	"shadow": Rect2(32, 64, 16, 16),
	"heart": Rect2(16, 80, 16, 16),
	"quick": Rect2(64, 48, 16, 16),
	"mend": Rect2(80, 48, 16, 16)
}

## Stable icons for the five existing perks; unknown IDs use the scroll icon.
static func perk_icon_rect(perk_id: String) -> Rect2:
	return PERK_REGIONS.get(perk_id, Rect2(80, 80, 16, 16))


## Three original flame-and-urn frames, sampled at 8 FPS without interpolation.
static func fire_frame(time: float) -> Rect2:
	return Rect2(16 + posmod(int(time * 8.0), 3) * 16, 48, 16, 16)


## Three native impact cloud frames; the renderer calls this only on a hit.
static func impact_frame(time: float) -> Rect2:
	return Rect2(64 + posmod(int(time * 18.0), 3) * 16, 32, 16, 16)


## Original golden spark frames for the brief stun indicator.
static func stun_frame(time: float) -> Rect2:
	return Rect2(posmod(int(time * 12.0), 4) * 16, 64, 16, 16)
