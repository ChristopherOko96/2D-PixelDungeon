@tool
extends RefCounted
## Original16px atlas masonry projected onto the32px gameplay grid.
## The host's collision footprints and port positions remain authoritative.

const ItemArt = preload("res://src/item_art.gd")
const Palette = preload("res://src/tile_palette.gd")
const CryptArt = preload("res://src/crypt_art.gd")
const UnifiedSkin = preload("res://src/unified_dungeon_skin.gd")
const THEMES := {
	"rose": preload("res://assets/tilesets/dungeon_rose.png"),
	"moss": preload("res://assets/tilesets/dungeon_moss.png"),
	"amber": preload("res://assets/tilesets/dungeon_amber.png"),
	"violet": preload("res://assets/tilesets/dungeon_violet.png")
}
const FLOOR := [Rect2(48,32,16,16), Rect2(64,32,16,16), Rect2(48,48,16,16), Rect2(64,48,16,16)]
# These source regions are masonry. The atlas's corner-shaped black openings
# are staircases and must never be used as the outside corners of a room.
const CAP := Rect2(32,1,16,3)
const BRICK := Rect2(32,4,16,12)
const SIDE_LEFT := Rect2(12,48,4,16)
const SIDE_RIGHT := Rect2(96,48,4,16)
const STAIRS := Rect2(0,0,16,16)
const INK := Color("#171222")
const PILLAR_HEIGHT := 12.0
static var _roof_colors: Dictionary = {}

## Draws floor, raised back/side walls, structural shadows and rear gateways.
## Raised obstacles are separate Y-sorted entries; south masonry is foreground.
static func draw_room(canvas: Node2D, snapshot: Dictionary) -> void:
	var layout: Dictionary = snapshot.get("room_layout",{})
	if layout.get("layout_mode","") == "freeform":
		if layout.get("crypt_profile",false):
			CryptArt.draw_background(canvas,layout,float(snapshot.get("ambience_clock",0)))
			return
		var dimensions: Array = layout.get("world_size",[896,480])
		canvas.draw_rect(Rect2(0,0,dimensions[0],dimensions[1]),snapshot.get("editor_background",Color.BLACK))
		return
	var scale := float(snapshot.get("room_layout",{}).get("tile_size",32))/16.0
	var native := snapshot.duplicate()
	native.room_layout = _native_layout(snapshot.get("room_layout",{}),scale)
	native._atlas_projection_scale = scale
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale)
	_draw_room_native(canvas,native)
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)


## Projects32px collision feet to original artwork without changing gameplay data.
static func draw_obstacle(canvas: Node2D, layout: Dictionary, footprint: Rect2) -> void:
	var scale := float(layout.get("tile_size",32))/16.0
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale)
	_draw_obstacle_native(canvas,_native_layout(layout,scale),Rect2(footprint.position/scale,footprint.size/scale))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)


## South foreground uses the same exact atlas-to-world projection as the walls.
static func draw_foreground(canvas: Node2D, snapshot: Dictionary) -> void:
	if snapshot.get("room_layout",{}).get("layout_mode","") == "freeform": return
	var scale := float(snapshot.get("room_layout",{}).get("tile_size",32))/16.0
	var native := snapshot.duplicate()
	native.room_layout = _native_layout(snapshot.get("room_layout",{}),scale)
	native._atlas_projection_scale = scale
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale)
	_draw_foreground_native(canvas,native)
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

## Freeform gateways use authored coordinates and art without invented jambs.
## Doorway availability changes only its leaf/marker, never the room silhouette.
static func draw_authored_exit(canvas: Node2D, layout: Dictionary, exit: Dictionary, snapshot: Dictionary) -> void:
	if layout.get("crypt_profile",false) and UnifiedSkin.enabled():
		CryptArt.draw_exit(canvas,exit,snapshot)
		return
	var rect := _rect(exit.rect)
	var tile: String = str(exit.get("tile","violet_000" if exit.kind == "stairs" else "items_002"))
	var rotation := int(exit.get("rotation",0))
	if exit.kind == "stairs" and layout.has("stairs_art"):
		tile = str(layout.stairs_art.tile)
		rotation = int(layout.stairs_art.rotation)
	var available: bool = snapshot.get("phase","") == "explore" and not exit.get("blocked",false)
	var cell := {"x":int(rect.position.x/32),"y":int(rect.position.y/32),"tile":tile,"rotation":rotation}
	Palette.draw(canvas,[cell],0.25 if available and exit.kind == "door" else 1.0)
	if available: canvas.draw_rect(rect.grow(-1),Color("89edc4"),false,1)


static func _native_layout(source: Dictionary, scale: float) -> Dictionary:
	var layout := source.duplicate(true)
	layout.world_size = source.get("world_size",[896,480]).map(func(value): return float(value)/scale)
	layout.play_bounds = source.get("play_bounds",[32,48,832,400]).map(func(value): return float(value)/scale)
	layout.obstacles = []
	for rect: Array in source.get("obstacles",[]): layout.obstacles.append(rect.map(func(value): return float(value)/scale))
	if source.has("visual_obstacles"):
		layout.visual_obstacles = []
		for rect: Array in source.visual_obstacles: layout.visual_obstacles.append(rect.map(func(value): return float(value)/scale))
	layout.exits = []
	for exit: Dictionary in source.get("exits",[]):
		var entry := exit.duplicate(true)
		entry.rect = exit.rect.map(func(value): return float(value)/scale)
		layout.exits.append(entry)
	layout.art_style = source.get("art_style",{}).duplicate()
	for key: String in ["pillar_height","north_wall_height"]:
		if layout.art_style.has(key): layout.art_style[key] = float(layout.art_style[key])/scale
	return layout


static func _draw_room_native(canvas: Node2D, snapshot: Dictionary) -> void:
	var layout: Dictionary = snapshot.get("room_layout", {})
	var texture := _texture(layout)
	var bounds := _bounds(layout)
	var dimensions: Array = layout.get("world_size", [448,240])
	var art: Dictionary = layout.get("art_style", {})
	var wall_tint: Color = art.get("wall_tint", Color.WHITE)
	var shadow := clampf(float(art.get("shadow_strength", 1.0)), 0, 1.5)
	canvas.draw_rect(Rect2(0,0,float(dimensions[0]),float(dimensions[1])), INK)
	_draw_floor(canvas, texture, bounds, int(snapshot.get("seed",0)), art.get("floor_tint", Color.WHITE))
	_draw_north_wall(canvas, texture, bounds, clampf(float(art.get("north_wall_height", 24.0)), 12, 24), wall_tint)
	_draw_side_walls(canvas, texture, bounds, wall_tint)
	_draw_inside_shadows(canvas, bounds, shadow)
	for value: Variant in layout.get("visual_obstacles",layout.get("obstacles", [])):
		if value is Array and value.size() == 4:
			var footprint := _rect(value)
			canvas.draw_rect(Rect2(footprint.position+Vector2(3,2),footprint.size+Vector2(2,2)),Color(0.05,0.02,0.1,0.24 * shadow))
			canvas.draw_rect(Rect2(footprint.end.x,footprint.position.y+3,4,footprint.size.y),Color(0.05,0.02,0.1,0.17 * shadow))
	for exit_value: Variant in layout.get("exits", []):
		if exit_value is Dictionary and str(exit_value.get("side","north")) != "south":
			_draw_exit(canvas,texture,exit_value,bounds,snapshot)

## Paints one raised cover piece at its depth in the entity render order.
## Its visible roof projects north; its brick foot ends at the collision base.
static func _draw_obstacle_native(canvas: Node2D, layout: Dictionary, footprint: Rect2) -> void:
	var texture := _texture(layout)
	var art: Dictionary = layout.get("art_style", {})
	var height := floorf(clampf(float(art.get("pillar_height", PILLAR_HEIGHT)), 4, 20))
	var tint: Color = art.get("wall_tint", Color.WHITE)
	var roof := Rect2(footprint.position-Vector2(0,height),footprint.size)
	canvas.draw_rect(roof.grow(1),INK)
	# The empty atlas slots carry colored RGB but zero alpha. Use an opaque
	# sampled crown pigment for the horizontal plane, never those empty slots.
	canvas.draw_rect(roof,_roof_color(texture) * tint)
	_fill(canvas,texture,Rect2(roof.position.x,roof.position.y,roof.size.x,3),CAP,tint)
	canvas.draw_rect(Rect2(roof.position.x,roof.position.y,1,roof.size.y),Color(0.95,0.83,1.0,0.5))
	canvas.draw_rect(Rect2(roof.end.x-2,roof.position.y,2,roof.size.y),Color(0.07,0.02,0.14,0.4))
	var face := Rect2(footprint.position.x,footprint.end.y-height,footprint.size.x,height)
	_fill(canvas,texture,face,BRICK,tint)
	canvas.draw_rect(Rect2(face.position.x,face.position.y,face.size.x,1),INK)
	canvas.draw_rect(Rect2(face.position.x,face.end.y-1,face.size.x,1),Color(0.03,0.01,0.06,0.8))

## South wall occludes feet that are behind its raised front edge.
static func _draw_foreground_native(canvas: Node2D, snapshot: Dictionary) -> void:
	var layout: Dictionary = snapshot.get("room_layout", {})
	var texture := _texture(layout)
	var bounds := _bounds(layout)
	var tint: Color = layout.get("art_style", {}).get("wall_tint", Color.WHITE)
	var width := bounds.size.x+32.0
	var left := bounds.position.x-16.0
	var top := bounds.end.y
	_fill(canvas,texture,Rect2(left,top,width,3),CAP,tint)
	_fill(canvas,texture,Rect2(left,top+3,width,12),BRICK,tint)
	canvas.draw_rect(Rect2(left,top+15,width,1),INK)
	# End blocks join the side courses into a continuous masonry corner.
	for x: float in [left,bounds.end.x]:
		_fill(canvas,texture,Rect2(x,top,16,3),CAP,tint)
		_fill(canvas,texture,Rect2(x,top+3,16,12),BRICK,tint)
	for exit_value: Variant in layout.get("exits", []):
		if exit_value is Dictionary and str(exit_value.get("side","north")) == "south":
			_draw_exit(canvas,texture,exit_value,bounds,snapshot)

static func _texture(layout: Dictionary) -> Texture2D:
	var theme_name := str(layout.get("theme","violet"))
	if theme_name not in THEMES: theme_name = "violet"
	if UnifiedSkin.enabled():
		var skin := UnifiedSkin.atlas(theme_name)
		if skin != null: return skin
	return THEMES[theme_name]

static func _roof_color(texture: Texture2D) -> Color:
	var key := texture.get_instance_id()
	if not _roof_colors.has(key):
		var source_scale := float(texture.get_meta("unified_atlas_scale",1.0))
		_roof_colors[key] = texture.get_image().get_pixel(int(34*source_scale),int(source_scale))
	return _roof_colors[key]

static func _bounds(layout: Dictionary) -> Rect2:
	return _rect(layout.get("play_bounds",[16,24,416,200]))

static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))

static func _tile(canvas: Node2D, texture: Texture2D, destination: Rect2, source: Rect2, tint: Color = Color.WHITE) -> void:
	var source_scale := float(texture.get_meta("unified_atlas_scale",1.0))
	canvas.draw_texture_rect_region(texture,destination,Rect2(source.position*source_scale,source.size*source_scale),tint)

static func _fill(canvas: Node2D, texture: Texture2D, bounds: Rect2, source: Rect2, tint: Color = Color.WHITE) -> void:
	# Every repeated pixel is 1:1. Partial edges crop, rather than stretching art.
	for y: int in range(int(bounds.position.y),int(bounds.end.y),int(source.size.y)):
		for x: int in range(int(bounds.position.x),int(bounds.end.x),int(source.size.x)):
			var dimensions := Vector2(minf(source.size.x,bounds.end.x-x),minf(source.size.y,bounds.end.y-y))
			_tile(canvas,texture,Rect2(Vector2(x,y),dimensions),Rect2(source.position,dimensions),tint)

static func _draw_floor(canvas: Node2D, texture: Texture2D, bounds: Rect2, seed_value: int, tint: Color = Color.WHITE) -> void:
	for y: int in range(int(bounds.position.y),int(bounds.end.y),16):
		for x: int in range(int(bounds.position.x),int(bounds.end.x),16):
			var dimensions := Vector2(minf(16.0,bounds.end.x-x),minf(16.0,bounds.end.y-y))
			var index := posmod(int(x/16)*73+int(y/16)*137+seed_value,FLOOR.size())
			_tile(canvas,texture,Rect2(Vector2(x,y),dimensions),Rect2(FLOOR[index].position,dimensions),tint)

static func _draw_north_wall(canvas: Node2D, texture: Texture2D, bounds: Rect2, height: float = 24.0, tint: Color = Color.WHITE) -> void:
	var left := bounds.position.x-16.0
	var width := bounds.size.x+32.0
	var cap_y := bounds.position.y - floorf(height)
	var face_height := floorf(height) - 4.0
	canvas.draw_rect(Rect2(left,0,width,bounds.position.y),INK)
	_fill(canvas,texture,Rect2(left,cap_y+1,width,3),CAP,tint)
	_fill(canvas,texture,Rect2(left,cap_y+4,width,face_height),BRICK,tint)
	canvas.draw_rect(Rect2(left,bounds.position.y-1,width,1),Color(0.04,0.01,0.08,0.75))
	# Corner piers have the same raised crown and brick body, never stair icons.
	for x: float in [left,bounds.end.x]:
		_fill(canvas,texture,Rect2(x,cap_y+1,16,3),CAP,tint)
		_fill(canvas,texture,Rect2(x,cap_y+4,16,face_height),BRICK,tint)
		canvas.draw_rect(Rect2(x+15,cap_y+4,1,face_height),Color(0.04,0.01,0.08,0.45))

static func _draw_side_walls(canvas: Node2D, texture: Texture2D, bounds: Rect2, tint: Color = Color.WHITE) -> void:
	var left := bounds.position.x-16.0
	var right := bounds.end.x
	_fill(canvas,texture,Rect2(left,bounds.position.y,12,bounds.size.y),BRICK,tint)
	_fill(canvas,texture,Rect2(left+12,bounds.position.y,4,bounds.size.y),SIDE_LEFT,tint)
	_fill(canvas,texture,Rect2(right,bounds.position.y,4,bounds.size.y),SIDE_RIGHT,tint)
	_fill(canvas,texture,Rect2(right+4,bounds.position.y,12,bounds.size.y),BRICK,tint)
	canvas.draw_rect(Rect2(left,bounds.position.y,10,bounds.size.y),Color(0.03,0.01,0.08,0.3))
	canvas.draw_rect(Rect2(right+6,bounds.position.y,10,bounds.size.y),Color(0.03,0.01,0.08,0.3))

static func _draw_inside_shadows(canvas: Node2D, bounds: Rect2, strength: float = 1.0) -> void:
	canvas.draw_rect(Rect2(bounds.position.x,bounds.position.y,bounds.size.x,3),Color(0.04,0.01,0.1,0.28 * strength))
	canvas.draw_rect(Rect2(bounds.position.x,bounds.position.y+3,bounds.size.x,2),Color(0.04,0.01,0.1,0.1 * strength))
	canvas.draw_rect(Rect2(bounds.position.x,bounds.position.y,3,bounds.size.y),Color(0.04,0.01,0.1,0.24 * strength))
	canvas.draw_rect(Rect2(bounds.end.x-3,bounds.position.y,3,bounds.size.y),Color(0.04,0.01,0.1,0.24 * strength))
	canvas.draw_rect(Rect2(bounds.position.x,bounds.end.y-3,bounds.size.x,3),Color(0.04,0.01,0.1,0.14 * strength))

static func _draw_exit(canvas: Node2D, texture: Texture2D, exit_data: Dictionary, bounds: Rect2, snapshot: Dictionary) -> void:
	var values: Variant = exit_data.get("rect",[])
	if not values is Array or values.size() != 4:
		return
	var trigger := _rect(values)
	var available := str(snapshot.get("phase","")) == "explore"
	if str(exit_data.get("kind","door")) == "stairs":
		canvas.draw_rect(trigger.grow(1),INK)
		_tile(canvas,texture,trigger,STAIRS)
		if available:
			canvas.draw_rect(trigger.grow(1),Color("#89edc4"),false,1.0)
		return
	var side := str(exit_data.get("side","north"))
	var point := trigger.get_center()
	var angle := 0.0
	match side:
		"north": point.y=bounds.position.y; angle=0.0
		"south": point.y=bounds.end.y; angle=PI
		"west": point.x=bounds.position.x; angle=-PI/2.0
		"east": point.x=bounds.end.x; angle=PI/2.0
	var style: Dictionary = snapshot.get("room_layout", {}).get("art_style", {})
	var tint: Color = style.get("wall_tint", Color.WHITE)
	var depth := clampf(float(style.get("north_wall_height", 24.0)), 12, 24) if side == "north" else 16.0
	var projection := float(snapshot.get("_atlas_projection_scale",1.0))
	canvas.draw_set_transform(point*projection,angle,Vector2.ONE*projection)
	canvas.draw_rect(Rect2(-8,-depth,16,depth+1),INK)
	# Recessed jambs and a raised lintel terminate exactly at the logical opening.
	_fill(canvas,texture,Rect2(-11,-depth,3,depth),Rect2(BRICK.position,Vector2(3,12)),tint)
	_fill(canvas,texture,Rect2(8,-depth,3,depth),Rect2(BRICK.position+Vector2(13,0),Vector2(3,12)),tint)
	_fill(canvas,texture,Rect2(-11,-depth,22,3),CAP,tint)
	canvas.draw_rect(Rect2(-8,-depth+3,16,2),Color(0,0,0,0.45))
	if not available:
		if side == "north":
			_tile(canvas,ItemArt.ITEMS,Rect2(-8,-16,16,16),ItemArt.CLOSED_DOOR_REGION)
		else:
			# Side/south doors retain their planks without rotated ladder-like bars.
			_tile(canvas,ItemArt.ITEMS,Rect2(-8,-16,16,16),ItemArt.CLOSED_DOOR_REGION)
	canvas.draw_rect(Rect2(-8,14,16,1),Color("#89edc4") if available else Color("#e19964"))
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE*projection)
