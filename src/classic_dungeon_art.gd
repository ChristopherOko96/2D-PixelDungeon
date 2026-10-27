@tool
extends RefCounted
## Quiet native32 surfaces and limited masonry colors from Godot commit44c9b80.
## prepare() is an explicit room-change boundary; draw methods never hash rooms.
const FLOOR_SOURCE: Texture2D = preload("res://assets/sprites/floor_stone.png")
const INK := Color("10101c")
const GROUT := Color("242334")
const STONE := Color("575064")
const CROWN := Color("726477")
const FACE := Color("3a334b")
const SIDE := Color("484054")
const SIDE_LIGHT := Color("63556c")
const SOUTH := Color("51475c")
const SOUTH_LIGHT := Color("766373")
const EDGE := Color("796171")
const SIDE_IDS := [1,3,4,5,7,13,14,20,21,27,28,34,36,38,40,47]
const TERRAIN_GROUPS := ["violet","rose","moss","amber"]
static var _floor_variants: Array[Image] = []
static var _wall_images: Dictionary = {}
static var _wall_textures: Dictionary = {}
static var _rotated_wall_images: Dictionary = {}
static var _shadows: Dictionary = {}

var _floor_texture: Texture2D
var _world_size := Vector2(896,480)
var _wall_cells: Array[Dictionary] = []
var _wall_rows: Array[Dictionary] = []
var _prepared := false

## Bakes only the visible floor once and classifies masonry without copying props.
## The caller must invoke this again after an editor layout change, even with same ID.
func prepare(layout: Dictionary, seed_value: int = 0) -> Dictionary:
	var dimensions: Array = layout.get("world_size",[896,480])
	_world_size = Vector2(float(dimensions[0]),float(dimensions[1]))
	var width := clampi(int(_world_size.x),32,2048)
	var height := clampi(int(_world_size.y),32,1536)
	var output := Image.create(width,height,false,Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var floors: Dictionary = {}
	_wall_cells = []
	_ensure_floor_variants()
	var freeform := str(layout.get("layout_mode","")) == "freeform"
	if freeform:
		for cell: Dictionary in layout.get("painted_tiles",[]):
			var layer := str(cell.get("layer","structure" if cell.get("solid",false) else "floor"))
			var point := Vector2i(int(cell.get("x",0)),int(cell.get("y",0)))
			if layer == "floor": floors[point] = true
			elif _is_masonry(cell):
				_wall_cells.append(cell)
				_wall_texture(_tile_number(str(cell.get("tile",""))))
		for point: Vector2i in floors:
			var destination := point*32
			if destination.x < 0 or destination.y < 0 or destination.x+32 > width or destination.y+32 > height: continue
			output.blit_rect(_floor_variants[_floor_variant(point,seed_value)],Rect2i(0,0,32,32),destination)
		# Restrained contact shading is baked, not recomputed on every frame.
		for point: Vector2i in floors:
			var destination := point*32
			if not floors.has(point+Vector2i.UP): output.blend_rect(_shadow("north"),Rect2i(0,0,32,4),destination)
			if not floors.has(point+Vector2i.LEFT): output.blend_rect(_shadow("west"),Rect2i(0,0,4,32),destination)
	else:
		var values: Array = layout.get("play_bounds",[32,48,832,400])
		var bounds := Rect2i(int(values[0]),int(values[1]),int(values[2]),int(values[3])).intersection(Rect2i(0,0,width,height))
		for y in range(bounds.position.y,bounds.end.y,32):
			for x in range(bounds.position.x,bounds.end.x,32):
				var point := Vector2i(x/32,y/32)
				var dimensions_left := Vector2i(mini(32,bounds.end.x-x),mini(32,bounds.end.y-y))
				output.blit_rect(_floor_variants[_floor_variant(point,seed_value)],Rect2i(Vector2i.ZERO,dimensions_left),Vector2i(x,y))
		_build_legacy_wall_cells(bounds,width,height)
	_floor_texture = ImageTexture.create_from_image(output)
	_wall_rows = _prepare_wall_rows()
	_prepared = true
	return {"floor_texture":_floor_texture,"floor_cells":floors,"wall_cells":_wall_cells,"wall_rows":_wall_rows,"world_size":_world_size}

## Flat dark outside space; no atmospheric particle or noise pass.
func draw_background(canvas: Node2D, layout: Dictionary = {}) -> void:
	var values: Array = layout.get("world_size",[_world_size.x,_world_size.y])
	canvas.draw_rect(Rect2(-64,-64,float(values[0])+128,float(values[1])+128),INK)

## One draw call for the entire floor. Baking belongs to prepare(), not redraw.
func draw_floor(canvas: Node2D, _layout: Dictionary = {}, _seed_value: int = 0) -> void:
	if _prepared and _floor_texture != null: canvas.draw_texture(_floor_texture,Vector2.ZERO)

## Native32 wall silhouettes stay aligned to the authored cell and quarter-turn.
## The limited slab palette replaces all dense/saturated material surfaces.
func draw_wall_cell(canvas: Node2D, cell: Dictionary) -> void:
	var index := _tile_number(str(cell.get("tile","violet_002")))
	var texture := _wall_texture(index)
	if texture == null: return
	var center := Vector2(float(cell.get("x",0))*32+16,float(cell.get("y",0))*32+16)
	var rotation := int(cell.get("rotation",0))
	if rotation == 0:
		canvas.draw_texture(texture,center-Vector2(16,16))
	else:
		canvas.draw_set_transform(center,float(rotation)*PI*0.5)
		canvas.draw_texture(texture,Vector2(-16,-16))
		canvas.draw_set_transform(Vector2.ZERO)

## A prepared horizontal strip preserves wall-foot Y sorting in one draw call.
func draw_wall_row(canvas: Node2D, row: Dictionary) -> void:
	var texture: Texture2D = row.get("texture")
	if texture != null: canvas.draw_texture(texture,row.rect.position)

## Legacy structural cover uses the same calm raised slabs, not pack decoration.
func draw_obstacle(canvas: Node2D, layout: Dictionary, footprint: Rect2) -> void:
	var art: Dictionary = layout.get("art_style",{})
	var height := floorf(clampf(float(art.get("pillar_height",24)),8,40))
	var roof := Rect2(footprint.position-Vector2(0,height),footprint.size)
	canvas.draw_rect(roof.grow(2),INK)
	canvas.draw_rect(roof,STONE)
	canvas.draw_rect(Rect2(roof.position,Vector2(roof.size.x,3)),CROWN)
	canvas.draw_rect(Rect2(roof.position+Vector2(2,3),Vector2(3,maxf(0,roof.size.y-3))),SIDE_LIGHT)
	var face := Rect2(footprint.position.x,footprint.end.y-height,footprint.size.x,height)
	canvas.draw_rect(face,FACE)
	canvas.draw_rect(Rect2(face.position,Vector2(face.size.x,3)),SOUTH_LIGHT)
	canvas.draw_rect(Rect2(face.position+Vector2(0,face.size.y-2),Vector2(face.size.x,2)),INK)

## Gameplay gateways use simple inset bars/steps, not decorative imported props.
func draw_exit(canvas: Node2D, _layout: Dictionary, exit: Dictionary, snapshot: Dictionary) -> void:
	var values: Array = exit.get("rect",[0,0,32,32])
	var region := Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
	var center := region.get_center()
	var available: bool = str(snapshot.get("phase","")) == "explore" and not bool(exit.get("blocked",false))
	if str(exit.get("kind","door")) == "stairs":
		var stairs := Rect2(center-Vector2(20,20),Vector2(40,40))
		canvas.draw_rect(stairs,INK)
		canvas.draw_rect(stairs,EDGE,false,2)
		for index in range(4):
			canvas.draw_rect(Rect2(stairs.position+Vector2(4,7+index*7),Vector2(32,3)),Color("3d354a").lightened(index*0.08))
		if available: canvas.draw_rect(Rect2(stairs.position+Vector2(4,35),Vector2(32,2)),Color("b38c64"))
		return
	var top_left := center+Vector2(-20,-36)
	canvas.draw_rect(Rect2(top_left,Vector2(40,52)),INK)
	canvas.draw_rect(Rect2(top_left+Vector2(-4,-4),Vector2(6,56)),SIDE_LIGHT)
	canvas.draw_rect(Rect2(top_left+Vector2(38,-4),Vector2(6,56)),SIDE)
	canvas.draw_rect(Rect2(top_left+Vector2(-4,-6),Vector2(48,6)),STONE)
	canvas.draw_rect(Rect2(top_left+Vector2(-2,-6),Vector2(44,2)),CROWN)
	if not available:
		for index in range(3): canvas.draw_rect(Rect2(top_left+Vector2(8+index*12,2),Vector2(4,46)),Color("776277"))
		canvas.draw_rect(Rect2(top_left+Vector2(4,18),Vector2(32,4)),Color("9e7a80"))
	canvas.draw_rect(Rect2(top_left+Vector2(2,48),Vector2(36,2)),Color("b38c64") if available else FACE)

## Exposes prepared wall entries without reconstructing them in the dynamic loop.
func wall_cells() -> Array[Dictionary]:
	return _wall_cells

## Entries have kind/y/texture/rect and can join the dynamic actor depth list.
func wall_rows() -> Array[Dictionary]:
	return _wall_rows

func _prepare_wall_rows() -> Array[Dictionary]:
	var groups: Dictionary = {}
	for cell: Dictionary in _wall_cells:
		var top := roundi(float(cell.get("y",0))*32)
		if not groups.has(top): groups[top] = []
		groups[top].append(cell)
	var rows: Array[Dictionary] = []
	var positions := groups.keys()
	positions.sort()
	for top: int in positions:
		var left := 2147483647
		var right := -2147483648
		for cell: Dictionary in groups[top]:
			var x := roundi(float(cell.get("x",0))*32)
			left = mini(left,x)
			right = maxi(right,x+32)
		if right <= left: continue
		var pixels := Image.create(right-left,32,false,Image.FORMAT_RGBA8)
		pixels.fill(Color.TRANSPARENT)
		for cell: Dictionary in groups[top]:
			var index := _tile_number(str(cell.get("tile","violet_002")))
			var image := _rotated_wall_image(index,posmod(int(cell.get("rotation",0)),4))
			if image != null: pixels.blit_rect(image,Rect2i(0,0,32,32),Vector2i(roundi(float(cell.get("x",0))*32)-left,0))
		rows.append({"kind":"classic_wall_row","y":float(top+32),"texture":ImageTexture.create_from_image(pixels),"rect":Rect2(float(left),float(top),float(right-left),32.0)})
	return rows

static func _rotated_wall_image(index: int, quarter_turns: int) -> Image:
	var source := _wall_image(index)
	if source == null or quarter_turns == 0: return source
	var key := "%d:%d" % [index,quarter_turns]
	if not _rotated_wall_images.has(key):
		var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
		for y in range(32):
			for x in range(32):
				var point := Vector2i(y,31-x) if quarter_turns == 1 else Vector2i(31-x,31-y) if quarter_turns == 2 else Vector2i(31-y,x)
				image.set_pixel(x,y,source.get_pixelv(point))
		_rotated_wall_images[key] = image
	return _rotated_wall_images[key]

static func _ensure_floor_variants() -> void:
	if not _floor_variants.is_empty(): return
	var source := FLOOR_SOURCE.get_image()
	if source.is_compressed(): source.decompress()
	if source.get_format() != Image.FORMAT_RGBA8: source.convert(Image.FORMAT_RGBA8)
	if source.get_size() != Vector2i(32,32): source.resize(32,32,Image.INTERPOLATE_NEAREST)
	for multiplier: float in [1.0,0.92,1.04]:
		var image := source.duplicate() as Image
		if multiplier != 1.0:
			for y in range(32):
				for x in range(32):
					var color := source.get_pixel(x,y)
					image.set_pixel(x,y,Color(color.r*multiplier,color.g*multiplier,color.b*multiplier,color.a))
		_floor_variants.append(image)

static func _floor_variant(point: Vector2i, seed_value: int) -> int:
	var key := absi(point.x*73+point.y*137+seed_value%997)
	if key%17 == 0: return 1
	if key%29 == 0: return 2
	return 0

static func _shadow(side: String) -> Image:
	if not _shadows.has(side):
		var image := Image.create(32 if side == "north" else 4,4 if side == "north" else 32,false,Image.FORMAT_RGBA8)
		image.fill(Color(0.025,0.018,0.045,0.24))
		_shadows[side] = image
	return _shadows[side]

static func _is_masonry(cell: Dictionary) -> bool:
	if cell.get("crypt_wall",false): return true
	var tile := str(cell.get("tile",""))
	var parts := tile.rsplit("_",true,1)
	return cell.get("solid",false) and parts.size() == 2 and parts[0] in TERRAIN_GROUPS

static func _tile_number(tile: String) -> int:
	var parts := tile.rsplit("_",true,1)
	return clampi(int(parts[1]),0,55) if parts.size() == 2 and parts[1].is_valid_int() else 2

static func _wall_texture(index: int) -> Texture2D:
	if not _wall_textures.has(index):
		var image := _wall_image(index)
		if image == null: return null
		_wall_textures[index] = ImageTexture.create_from_image(image)
	return _wall_textures[index]

static func _wall_image(index: int) -> Image:
	if _wall_images.has(index): return _wall_images[index]
	# Original alpha is a contour mask only; none of its palette/material is used.
	var path := "res://assets/tilesets/cells32/violet_%03d.png" % index
	if not ResourceLoader.exists(path): return null
	var resource: Texture2D = load(path)
	var mask := resource.get_image()
	if mask.is_compressed(): mask.decompress()
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var bounds := mask.get_used_rect()
	for y in range(32):
		for x in range(32):
			var alpha := mask.get_pixel(x,y).a
			if alpha <= 0: continue
			var color := FACE
			if index in SIDE_IDS:
				var relative := x-bounds.position.x
				color = SIDE_LIGHT if relative < 2 else SIDE
				if relative == bounds.size.x-1: color = INK
				if y == 0 or y == 30: color = INK
			else:
				color = SOUTH if index in [8,10,12,29,33,37] else STONE
				if y < 2 or y in [20,21,31] or x == 0 or x == 31: color = INK
				elif y in [3,4,5]: color = SOUTH_LIGHT if index in [8,10,12,29,33,37] else CROWN
				elif y >= 22: color = FACE
				elif x == 16: color = Color("484054")
			image.set_pixel(x,y,Color(color.r,color.g,color.b,alpha))
	_wall_images[index] = image
	return image

func _build_legacy_wall_cells(bounds: Rect2i, width: int, height: int) -> void:
	for x in range(maxi(0,bounds.position.x-32),mini(width,bounds.end.x+32),32):
		for y in [maxi(0,bounds.position.y-32),mini(height-32,bounds.end.y)]:
			var cell := {"x":float(x)/32.0,"y":float(y)/32.0,"tile":"violet_002","rotation":0,"solid":true,"layer":"structure"}
			_wall_cells.append(cell)
	for y in range(bounds.position.y,bounds.end.y,32):
		for x in [maxi(0,bounds.position.x-32),mini(width-32,bounds.end.x)]:
			var cell := {"x":float(x)/32.0,"y":float(y)/32.0,"tile":"violet_021" if x < bounds.position.x else "violet_027","rotation":0,"solid":true,"layer":"structure"}
			_wall_cells.append(cell)
	_wall_texture(2)
	_wall_texture(21)
	_wall_texture(27)
