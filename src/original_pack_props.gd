@tool
extends RefCounted
## Original pack substitutes for the optional detailed crypt props.
## Existing prop IDs and their authored collision/placement remain unchanged.
const ITEMS: Texture2D = preload("res://assets/items/item_sheet_items.png")
const ANIMATIONS: Texture2D = preload("res://assets/items/animation_sheet_items.png")
const ITEM_CELLS := [13,12,10,7,43,-1,28,44,8,45,23,12,0,1,-1,-1]
const NAMES := ["Grabtruhe","Offene Grabtruhe","Altartisch","Grabfass","Schädel","Grabkerzen","Kerzenleuchter","Knochen","Vorratskiste","Archivrolle","Gedenkbanner","Reliquientruhe","Kryptentor geschlossen","Kryptentor offen","Eingang · Mauerbruch","Kryptentreppe"]
static var _textures: Dictionary = {}

## Only the fixed sixteen crypt IDs can select original atlas regions.
static func supports(id: String) -> bool:
	if not id.begins_with("crypt_") or id.length() != 9: return false
	var suffix := id.substr(6)
	return suffix.is_valid_int() and int(suffix) >= 0 and int(suffix) < 16 and suffix == "%03d" % int(suffix)

## Describes the actual original-pack equivalent rather than a missing statue.
static func display_name(id: String) -> String:
	return NAMES[int(id.substr(6))] if supports(id) else id

## Uses original16px art at2x, without repainting or replacing source PNGs.
static func texture(id: String) -> Texture2D:
	if not supports(id): return null
	if _textures.has(id): return _textures[id]
	var index := int(id.substr(6))
	var output: Texture2D
	if index in [14,15]:
		output = load("res://assets/tilesets/cells32/violet_%03d.png" % (45 if index == 14 else 0))
	else:
		var atlas := AtlasTexture.new()
		if index == 5:
			atlas.atlas = ANIMATIONS
			atlas.region = Rect2(80,80,16,16)
		else:
			var cell: int = ITEM_CELLS[index]
			atlas.atlas = ITEMS
			atlas.region = Rect2((cell%8)*16,(cell/8)*16,16,16)
		# Match the existing32px palette thumbnails as well as world placement.
		var pixels := atlas.get_image()
		if pixels == null: return null
		if pixels.is_compressed(): pixels.decompress()
		pixels.resize(32,32,Image.INTERPOLATE_NEAREST)
		output = ImageTexture.create_from_image(pixels)
	_textures[id] = output
	return output

## The original art occupies one32px cell, with the same fixed ground anchor.
static func draw_rect() -> Rect2:
	return Rect2(-16,-16,32,32)
