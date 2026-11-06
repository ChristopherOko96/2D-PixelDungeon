extends RefCounted
## Code-native five-part glass capsule, articulated by the shared rig solver.
const Library = preload("res://src/rig/rig_library.gd")
const Renderer = preload("res://src/rig/rig_renderer.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
const GRID := ["...ooo...","...omo...","..ooooo..","..olwlo..","..ol.lo..",".ol...lo.","olmmmmmlo","olmmwmmlo","olmmmmmlo","olmmmmmlo",".olmmmlo.","..ooooo..","..odddo.."]
static var rigs: Dictionary = {}
static var solver: RefCounted
static var cfg: Dictionary = {}

## Cache distinct element palettes and five disjoint cutout masks once.
static func prepare() -> void:
	if not rigs.is_empty(): return
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/alchemist_rules.json"))
	var library := Library.new()
	solver = Renderer.new(library)
	for recipe: String in cfg.colours:
		var tint := Color(str(cfg.colours[recipe]))
		var palette := {"o":Color("302b35"), "d":Color("69565b"), "m":tint, "l":tint.lightened(0.35), "w":Color("f5f6df")}
		var image := Image.create(9,13,false,Image.FORMAT_RGBA8)
		for y in range(GRID.size()):
			for x in range(9):
				var cell: String = GRID[y][x]
				if palette.has(cell): image.set_pixel(x,y,palette[cell])
		# Shape cue as well as colour: liquid dot, ice cross, hot spark, glass diagonal.
		for p: Vector2i in _symbol(recipe): image.set_pixelv(p,Color("f5f6df"))
		rigs[recipe] = library.cutout_frame("alchemy_"+recipe,image,{"family":"alchemy", "ground":[4,12], "width":9, "parts":[
			{"id":"cap","rects":[[0,0,8,2]],"pivot":[4,3],"parent":"core","z":3},
			{"id":"glass_l","rects":[[0,3,2,10]],"pivot":[4,10],"parent":"base","z":2},
			{"id":"glass_r","rects":[[6,3,8,10]],"pivot":[4,10],"parent":"base","z":2},
			{"id":"core","rects":[[3,3,5,10]],"pivot":[4,8],"parent":"base","z":1},
			{"id":"base","rects":[[0,0,8,12]],"pivot":[4,12],"parent":null,"z":0}],"items":[]})

static func _symbol(recipe: String) -> Array[Vector2i]:
	match recipe:
		"water": return [Vector2i(4,7),Vector2i(4,8),Vector2i(3,9),Vector2i(4,9),Vector2i(5,9)]
		"frost": return [Vector2i(4,7),Vector2i(3,8),Vector2i(4,8),Vector2i(5,8),Vector2i(4,9)]
		"fire": return [Vector2i(5,7),Vector2i(4,8),Vector2i(3,9),Vector2i(4,9)]
		"shatter": return [Vector2i(3,9),Vector2i(4,8),Vector2i(5,7)]
		_: return [Vector2i(3,7),Vector2i(5,7),Vector2i(4,9)]

## Sealed glass subtly rocks; cork, shell halves and liquid separate on release.
static func parts(at: Vector2, recipe: String, art: float, clock: float, progress := -1.0, armed := true) -> Array:
	prepare()
	var rig: Dictionary = rigs.get(recipe,rigs.poison)
	var pose := Poses.blank()
	if progress < 0:
		Poses.P(pose,"core").rot = sin(clock*3.0)*0.04 if armed else 0.0
		Poses.P(pose,"cap").dy = -absf(sin(clock*4.0))*0.4 if armed else 0.0
	else:
		Poses.P(pose,"cap").dy = -float(cfg.art.cap_lift)*sin(progress*PI*0.65)
		for side: String in ["glass_l","glass_r"]:
			var sign_value := -1.0 if side == "glass_l" else 1.0
			Poses.P(pose,side).rot = sign_value*progress*2.5
			Poses.P(pose,side).dx = sign_value*progress*float(cfg.art.flight_px)
			Poses.P(pose,side).dy = progress*progress*10
		Poses.P(pose,"core").dy = -sin(progress*PI)*6
	var world: Dictionary = solver.solve_pose(rig,pose,at,1,art*float(cfg.art.spread))
	var alpha := 1.0 if progress < 0 else 1.0-progress
	var out: Array = []
	for part: Dictionary in rig.parts:
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":Color(1,1,1,alpha) if armed else Color(0.6,0.6,0.6,alpha)})
	return out

## The ultimate's actual apparatus unfolds six glass capsules around its hub.
static func field(canvas: CanvasItem, event: Dictionary, progress: float, art: float, clock: float, sprites: RefCounted) -> void:
	prepare()
	var at := Vector2(event.x,event.y)
	var open := smoothstep(0,0.16,progress)
	var radius := float(event.r)*float(cfg.field.spread)*open
	for n in range(int(cfg.field.capsules)):
		var spot := at+Vector2.from_angle(TAU*n/int(cfg.field.capsules))*radius
		var recipe := "water" if n%2 == 0 else "poison"
		var phase := progress*float(event.get("span",3.3))
		var release := float(cfg.field.water_at_s) if n%2 == 0 else float(cfg.field.poison_at_s)
		var p := clampf((phase-release)/float(cfg.art.open_s),0,1) if phase >= release else -1.0
		if p < 1: sprites.draw_external_rig(canvas,parts(spot,recipe,art,clock,p),spot)
	var core := "frost" if progress*float(event.get("span",3.3)) < float(cfg.field.fire_at_s) else "fire"
	sprites.draw_external_rig(canvas,parts(at,core,art*1.35,clock,-1 if progress<0.75 else (progress-0.75)*4),at)
