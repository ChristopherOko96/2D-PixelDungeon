@tool
extends RefCounted
## Whitelisted, separately extracted 32px cells. No draft can load arbitrary paths.
const GROUPS := ["violet","rose","moss","amber","items","crypt","living"]
const Living = preload("res://src/living_sprite_library.gd")
const UnifiedSkin = preload("res://src/unified_dungeon_skin.gd")
const OriginalProps = preload("res://src/original_pack_props.gd")
const CRYPT_NAMES := ["Sarkophag","Offener Sarkophag","Seelenaltar","Graburne","Grabstein","Kerzen","Kandelaber","Knochen","Sarg","Bücherregal","Trauerstatue","Reliquienschrein","Kryptentor geschlossen","Kryptentor offen","Eingang · Mauerbruch","Kryptentreppe"]
static var _textures: Dictionary = {}

## Stable cell IDs for the selected original sheet, in row-major order.
static func ids(group: String) -> Array[String]:
	var result: Array[String] = []
	if group not in GROUPS: return result
	for index in range(16 if group in ["crypt","living"] else 56): result.append("%s_%03d" % [group,index])
	return result

## Rejects unknown IDs before resource access or host geometry generation.
static func valid_id(id: String) -> bool:
	var bits := id.rsplit("_",true,1)
	return bits.size() == 2 and bits[0] in GROUPS and bits[1].is_valid_int() and int(bits[1]) >= 0 and int(bits[1]) < (16 if bits[0] in ["crypt","living"] else 56) and bits[1] == "%03d" % int(bits[1])

## Human-readable names for the additional crypt furniture palette.
static func display_name(id: String) -> String:
	if id.begins_with("living_"): return str(Living.definition(id).get("name",id))
	if not UnifiedSkin.active and OriginalProps.supports(id): return OriginalProps.display_name(id)
	return CRYPT_NAMES[int(id.get_slice("_",1))] if valid_id(id) and id.begins_with("crypt_") else id

## Loads one extracted native32 PNG, cached for both editor and game.
static func texture(id: String) -> Texture2D:
	if not valid_id(id): return null
	if id.begins_with("living_"): return Living.texture(id)
	if not UnifiedSkin.active and OriginalProps.supports(id): return OriginalProps.texture(id)
	if UnifiedSkin.supports(id) and UnifiedSkin.enabled(): return UnifiedSkin.texture(id)
	if not _textures.has(id):
		var path := "res://assets/crypt/props/%s.png" % id if id.begins_with("crypt_") else "res://assets/tilesets/cells32/%s.png" % id
		_textures[id] = load(path)
	return _textures[id]

## Draws the exact chosen cells and quarter-turns; collision is handled by host.
static func draw(canvas: Node2D, cells: Array, hover_alpha: float = 1.0, origin: Vector2 = Vector2.ZERO, zoom: float = 1.0, clock: float = 0.0) -> void:
	for cell: Dictionary in cells:
		var id := str(cell.get("tile",""))
		var phase := float(posmod(int(cell.get("x",0))*73+int(cell.get("y",0))*137,97))/97.0
		var image := Living.texture(id,clock,phase) if id.begins_with("living_") else texture(id)
		if image == null: continue
		canvas.draw_set_transform(cell_center(cell,origin,zoom),float(cell.rotation)*PI*0.5,Vector2.ONE*zoom)
		var target := Living.draw_rect(id) if id.begins_with("living_") else OriginalProps.draw_rect() if not UnifiedSkin.active and OriginalProps.supports(id) else Rect2(-32,-48,64,64) if id.begins_with("crypt_") else Rect2(-16,-16,32,32)
		canvas.draw_texture_rect(image,target,false,Color(1,1,1,hover_alpha))
	canvas.draw_set_transform(Vector2.ZERO)

## Shared placement transform for full-size gameplay and scaled editor ghosts.
static func cell_center(cell: Dictionary, origin: Vector2, zoom: float) -> Vector2:
	return origin+Vector2(float(cell.x)*32+16,float(cell.y)*32+16)*zoom
