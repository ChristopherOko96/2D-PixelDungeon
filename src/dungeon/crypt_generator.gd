extends RefCounted
## Independent chamber graphs -> connected floor -> complete contour -> masonry.
## Uses the author's tile roles, never stamps or rotates the author's room.
const DIRECTIONS := [Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
const Palette = preload("res://src/tile_palette.gd")
const THEMES := ["entrance","ossuary","tombs","chapel","catacombs","cursed_garden","archive","lost_graves","mourning","throne"]
const TERRAIN_PALETTES := ["violet","rose","moss","amber"]
const LARGE_LIVING := ["living_002","living_003","living_006","living_010","living_011","living_012","living_013"]

## Makes a seeded library in memory. Files and authored samples are never mutated.
static func realize(config: Dictionary, seed_value: int) -> Dictionary:
	if not config.get("crypt_procedural",false) or not config.get("crypt_style_source") is Dictionary: return config
	var result := config.duplicate(true)
	var style: Dictionary = result.crypt_style_source
	for room: Dictionary in result.templates:
		if not room.get("crypt_recipe") is Dictionary: continue
		room.render_style = str(room.get("render_style",result.get("render_style","original_pack")))
		room.decoration_enabled = bool(room.get("decoration_enabled",result.get("decoration_enabled",true)))
		var terrain_theme := str(room.get("theme","violet"))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value ^ str(room.id).hash()
		var floor_cells: Dictionary = {}
		var rectangles: Array[Rect2i] = []
		for index in range(room.crypt_recipe.chambers.size()):
			var values: Array = room.crypt_recipe.chambers[index]
			var rectangle := Rect2i(int(values[0]),int(values[1]),int(values[2]),int(values[3]))
			if index >= 2: rectangle.size += Vector2i(rng.randi_range(0,1),rng.randi_range(0,1))
			rectangles.append(rectangle)
			for y in range(rectangle.position.y,rectangle.end.y):
				for x in range(rectangle.position.x,rectangle.end.x): floor_cells[Vector2i(x,y)] = true
		for link: Array in room.crypt_recipe.links:
			var a := Vector2i(rectangles[int(link[0])].get_center())
			var b := Vector2i(rectangles[int(link[1])].get_center())
			var elbow := Vector2i(b.x,a.y) if rng.randi_range(0,1) == 0 else Vector2i(a.x,b.y)
			_corridor(floor_cells,a,elbow)
			_corridor(floor_cells,elbow,b)
		var tiles: Array = []
		var border: Dictionary = {}
		for point: Vector2i in floor_cells:
			var floor_art := _terrain_tile(str(style.floor_tiles[1 if rng.randi_range(0,29) == 0 else 0]),terrain_theme)
			tiles.append(_cell(point,floor_art,false,"floor"))
			for direction: Vector2i in DIRECTIONS:
				if not floor_cells.has(point+direction): border[point+direction] = true
		# One wall per void cell, including all four diagonal corner cases.
		# There is no random wall selection and no duplicated wall layer.
		for point: Vector2i in border:
			var tile := _terrain_tile(str(style.wall_roles[_wall_role(point,floor_cells)]),terrain_theme)
			if room.get("crypt_entrance",false) and point == Vector2i(8,3): tile = _terrain_tile("violet_045",terrain_theme)
			var wall := _cell(point,tile,true,"structure")
			wall.crypt_wall = true
			tiles.append(wall)
		room.painted_tiles = tiles
		_dress_into(room,result,int(rng.randi()))
		room.encounter_seed = rng.randi()
	return result

## Returns themed dressing on an independent copy, preserving all authored geometry.
## Root-level crypt_decoration_catalog supplies the art and placement tuning.
static func dress_template(template: Dictionary, config: Dictionary, seed_value: int) -> Dictionary:
	var dressed := template.duplicate(true)
	_dress_into(dressed,config,seed_value)
	return dressed

static func _dress_into(room: Dictionary, config: Dictionary, seed_value: int) -> void:
	var theme_name := str(room.get("room_theme",_theme_for_id(str(room.get("id","")))))
	room.room_theme = theme_name
	room.render_style = str(room.get("render_style",config.get("render_style","original_pack")))
	room.decoration_enabled = bool(room.get("decoration_enabled",config.get("decoration_enabled",true)))
	if not room.decoration_enabled:
		# Decoration is optional authoring data. Remove only our tagged generated
		# dressing; untagged walls/floors and the author's own placements survive.
		var structural: Array = []
		for cell: Dictionary in room.get("painted_tiles",[]):
			if not cell.get("crypt_dressing",false): structural.append(cell)
		room.painted_tiles = structural
		room.decoration_summary = {"theme":theme_name,"placed":0,"layout":"disabled"}
		return
	var catalog: Dictionary = config.get("crypt_decoration_catalog",{})
	if not catalog.get(theme_name) is Dictionary: return
	var settings: Dictionary = catalog[theme_name]
	var recipe: Dictionary = room.get("crypt_recipe",{})
	if not recipe.get("chambers") is Array: return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ theme_name.hash()
	var cells: Array = []
	var floor_cells: Dictionary = {}
	var occupied: Dictionary = {}
	var reserved: Array[Vector2] = []
	for cell: Dictionary in room.get("painted_tiles",[]):
		if cell.get("crypt_dressing",false): continue
		cells.append(cell)
		var point := Vector2i(int(cell.x),int(cell.y))
		if cell.get("layer","") == "floor": floor_cells[point] = true
		else: occupied[point] = true
	for key: String in ["player_spawns","enemy_spawns","brazier_spawns"]:
		for point: Array in room.get(key,[]): reserved.append(Vector2(point[0],point[1]))
	for key: String in ["reward_spawn","stairs_spawn"]:
		if room.has(key): reserved.append(Vector2(room[key][0],room[key][1]))
	for door: Dictionary in room.get("authored_doors",[]): reserved.append(Vector2(float(door.x)*32+16,float(door.y)*32+16))
	var rectangles: Array[Rect2i] = []
	var hero_index := -1
	var hero_area := 0
	for values: Array in recipe.chambers.slice(2):
		var rectangle := Rect2i(int(values[0]),int(values[1]),int(values[2]),int(values[3]))
		rectangles.append(rectangle)
		if rectangle.get_area() > hero_area:
			hero_area = rectangle.get_area()
			hero_index = rectangles.size()-1
	var placed: Array[Vector2i] = []
	var layout := str(settings.get("layout","paired_rows"))
	for index in range(rectangles.size()):
		var rectangle := rectangles[index]
		var center := Vector2i(rectangle.get_center())
		var added := 0
		var limit := clampi(int(settings.get("max_props_per_chamber",14)),0,32)
		# A single focal object establishes the theme; side chambers stay quieter.
		if index == hero_index:
			var focal := str(settings.get("focal",""))
			for point: Vector2i in [Vector2i(center.x,rectangle.end.y-3),Vector2i(center.x,rectangle.position.y+3),Vector2i(rectangle.end.x-3,center.y)]:
				if added >= limit: break
				if _place_dressing(cells,point,focal,bool(settings.get("focal_solid",false)),floor_cells,occupied,reserved,placed,settings,rectangle,true):
					added += 1
					break
		var corners: Array[Vector2i] = [rectangle.position+Vector2i(2,2),Vector2i(rectangle.end.x-3,rectangle.position.y+2),Vector2i(rectangle.position.x+2,rectangle.end.y-3),rectangle.end-Vector2i(3,3)]
		# Pick coherent opposite beds/rows, rather than scattering isolated props.
		var maximum := clampi(int(settings.get("max_clusters_per_chamber",2)),0,4)
		var order: Array[int] = [0,3,1,2]
		if rng.randi_range(0,1) != 0: order.assign([1,2,0,3])
		for cluster_index in range(maximum):
			var corner_index := order[cluster_index]
			var anchor := corners[corner_index]
			var inward := Vector2i(1 if corner_index in [0,2] else -1,1 if corner_index in [0,1] else -1)
			var offsets: Array[Vector2i] = _cluster_pattern(layout,inward)
			for offset_index in range(offsets.size()):
				if added >= limit: break
				var id := _pick_art(settings,"primary" if offset_index < 2 else "secondary",rng)
				if _place_dressing(cells,anchor+offsets[offset_index],id,false,floor_cells,occupied,reserved,placed,settings,rectangle,false): added += 1
		# Accents belong near their grouped furniture/planting beds, never the aisle.
		for corner_index in [0,3]:
			if added >= limit: break
			var anchor := corners[corner_index]
			var inward_y := 1 if corner_index == 0 else -1
			var id := _pick_art(settings,"accent",rng)
			if _place_dressing(cells,anchor+Vector2i(0,inward_y*4),id,false,floor_cells,occupied,reserved,placed,settings,rectangle,false): added += 1
	room.painted_tiles = cells
	room.decoration_summary = {"theme":theme_name,"placed":placed.size(),"layout":layout}

static func _theme_for_id(id: String) -> String:
	var number := id.get_slice("_",1).to_int()-1
	return THEMES[number] if number >= 0 and number < THEMES.size() else "entrance"

static func _cluster_pattern(layout: String, inward: Vector2i) -> Array[Vector2i]:
	match layout:
		"garden_beds": return [Vector2i.ZERO,Vector2i(0,inward.y*2),Vector2i(inward.x*2,0),inward*2]
		"archive": return [Vector2i.ZERO,Vector2i(inward.x*2,0),Vector2i(inward.x*4,0),Vector2i(0,inward.y*2)]
		"altar", "ritual": return [Vector2i.ZERO,Vector2i(0,inward.y*2),Vector2i(inward.x*2,0)]
		"memorial": return [Vector2i.ZERO,Vector2i(0,inward.y*2),Vector2i(0,inward.y*4),Vector2i(inward.x*2,0)]
	return [Vector2i.ZERO,Vector2i(0,inward.y*2),Vector2i(inward.x*2,0)]

static func _pick_art(settings: Dictionary, key: String, rng: RandomNumberGenerator) -> String:
	var options: Variant = settings.get(key,[])
	if not options is Array or options.is_empty(): return ""
	return str(options[rng.randi_range(0,options.size()-1)])

static func _place_dressing(cells: Array, point: Vector2i, id: String, solid: bool, floor_cells: Dictionary, occupied: Dictionary, reserved: Array[Vector2], placed: Array[Vector2i], settings: Dictionary, rectangle: Rect2i, focal: bool) -> bool:
	if not Palette.valid_id(id) or occupied.has(point) or not floor_cells.has(point): return false
	if not rectangle.has_point(point): return false
	var center := Vector2(point)*32+Vector2(16,16)
	var safety := maxf(64,float(settings.get("safety_radius",112)))
	for protected: Vector2 in reserved:
		if center.distance_to(protected) < safety: return false
	var aisle := maxi(1,int(settings.get("aisle_half_width",1)))
	var axis := Vector2i(rectangle.get_center())
	if not focal and (absi(point.x-axis.x) <= aisle or absi(point.y-axis.y) <= aisle): return false
	var spacing := maxi(2,int(settings.get("spacing_cells",2)))
	for existing: Vector2i in occupied:
		if absi(point.x-existing.x) < spacing and absi(point.y-existing.y) < spacing: return false
	#64px art projects above its32px footprint. Keep full surrounding floor and
	# an extra northern margin so plants/statues never cut across wall silhouettes.
	if id.begins_with("crypt_") or id in LARGE_LIVING:
		for direction: Vector2i in DIRECTIONS:
			if not floor_cells.has(point+direction): return false
		if not floor_cells.has(point+Vector2i(0,-2)): return false
	var cell := _cell(point,id,solid,"structure")
	cell.crypt_dressing = true
	cells.append(cell)
	occupied[point] = true
	placed.append(point)
	return true

static func _corridor(target: Dictionary, a: Vector2i, b: Vector2i) -> void:
	if a.y == b.y:
		for x in range(mini(a.x,b.x),maxi(a.x,b.x)+1):
			for y in range(a.y-2,a.y+3): target[Vector2i(x,y)] = true
	else:
		for y in range(mini(a.y,b.y),maxi(a.y,b.y)+1):
			for x in range(a.x-2,a.x+3): target[Vector2i(x,y)] = true

static func _wall_role(p: Vector2i, f: Dictionary) -> String:
	var n: bool = f.has(p+Vector2i.UP)
	var e: bool = f.has(p+Vector2i.RIGHT)
	var s: bool = f.has(p+Vector2i.DOWN)
	var w: bool = f.has(p+Vector2i.LEFT)
	if n and w: return "inner_nw"
	if n and e: return "inner_ne"
	if s and w: return "inner_sw"
	if s and e: return "inner_se"
	if s: return "north"
	if n: return "south"
	if e: return "west"
	if w: return "east"
	if f.has(p+Vector2i(1,1)): return "outer_nw"
	if f.has(p+Vector2i(-1,1)): return "outer_ne"
	if f.has(p+Vector2i(1,-1)): return "outer_sw"
	return "outer_se"

static func _cell(p: Vector2i, tile: String, solid: bool, layer: String) -> Dictionary:
	return {"x":p.x,"y":p.y,"tile":tile,"solid":solid,"layer":layer,"rotation":0}

static func _terrain_tile(id: String, theme_name: String) -> String:
	var pieces := id.rsplit("_",true,1)
	if pieces.size() != 2 or pieces[0] not in TERRAIN_PALETTES or theme_name not in TERRAIN_PALETTES: return id
	return theme_name+"_"+str(pieces[1])
