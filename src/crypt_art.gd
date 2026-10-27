@tool
extends RefCounted
## Dark void ambience behind authored floors. All fog is presentation only.
const Palette = preload("res://src/tile_palette.gd")
static var _shadow_key := ""
static var _floor_shadows: Array[Rect2] = []

## Contact shadows follow actual floor edges, so walls read as raised masonry.
static func draw_floor_shadows(canvas: Node2D, layout: Dictionary) -> void:
	var key := str(layout.get("id",""))+":"+str(hash(layout.get("painted_tiles",[])))
	if key != _shadow_key:
		_shadow_key = key
		_floor_shadows.clear()
		var floor_cells := {}
		for cell: Dictionary in layout.get("painted_tiles",[]):
			if cell.get("layer","") == "floor": floor_cells[Vector2i(int(cell.x),int(cell.y))] = true
		for point: Vector2i in floor_cells:
			if not floor_cells.has(point+Vector2i.UP): _floor_shadows.append(Rect2(Vector2(point)*32,Vector2(32,4)))
			if not floor_cells.has(point+Vector2i.LEFT): _floor_shadows.append(Rect2(Vector2(point)*32,Vector2(3,32)))
	for rectangle: Rect2 in _floor_shadows: canvas.draw_rect(rectangle,Color(0.10,0.03,0.17,0.24))

## Low-contrast, pixel-stepped drifting fog; floors and walls draw over it.
static func draw_background(canvas: Node2D, layout: Dictionary, clock: float) -> void:
	var dimensions: Array = layout.get("world_size",[2048,1408])
	canvas.draw_rect(Rect2(-1024,-1024,float(dimensions[0])+2048,float(dimensions[1])+2048),Color("08060f"))
	var settings: Dictionary = layout.get("crypt_ambience",{})
	var opacity := clampf(float(settings.get("fog_opacity",0.16)),0,0.3)
	var speed := float(settings.get("fog_speed",5.0))
	for index in range(18):
		var x := fposmod(index*277.0+clock*speed*(0.6+float(index%3)*0.2),float(dimensions[0])+800.0)-400.0
		var y := fposmod(index*193.0+sin(clock*0.06+index)*44.0,float(dimensions[1])+300.0)-150.0
		for band in range(7):
			var width := 140.0+float(band)*52.0
			var point := Vector2(floorf((x-width*0.5)/4)*4,floorf((y+float(band-3)*8)/4)*4)
			var alpha := opacity*(1.0-absf(float(band-3))/5.0)*0.17
			canvas.draw_rect(Rect2(point,Vector2(width,12)),Color(0.34,0.29,0.43,alpha))

## Full-size, detailed doors retain the same host-authorized interaction cell.
static func draw_exit(canvas: Node2D, exit: Dictionary, snapshot: Dictionary) -> void:
	var rectangle: Array = exit.rect
	var center := Vector2(float(rectangle[0])+16,float(rectangle[1])+16)
	var open: bool = snapshot.get("phase","") == "explore" and not exit.get("blocked",false)
	var id := "crypt_015" if exit.kind == "stairs" else "crypt_013" if open else "crypt_012"
	var texture := Palette.texture(id)
	if texture == null: return
	canvas.draw_texture_rect(texture,Rect2(center+Vector2(-32,-48),Vector2(64,64)),false)
	if open:
		# Small threshold glint instead of a bright rectangle around the portal.
		canvas.draw_rect(Rect2(center+Vector2(-10,13),Vector2(20,2)),Color("8fb9be"))
