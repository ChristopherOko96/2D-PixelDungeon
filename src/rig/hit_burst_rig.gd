extends RefCounted
## Cached impact cutouts, animated by the game's real parent/joint solver.
## One owner per feedback layer; no damage, nodes, global particles or network state.
const Library = preload("res://src/rig/rig_library.gd")
const Renderer = preload("res://src/rig/rig_renderer.gd")
const Poses = preload("res://src/rig/rig_poses.gd")
const PATH := "res://assets/data/hit_feedback.json"
static var config: Dictionary = {}
static var rig: Dictionary = {}
static var solver: RefCounted
var live: Array[Dictionary] = []

## Split the approved native spark into nine non-overlapping textured parts once.
static func prepare() -> void:
	if not rig.is_empty(): return
	config = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var library := Library.new()
	var image: Image = (load(str(config.source)) as Texture2D).get_image()
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	rig = library.cutout_frame("hit_burst",image,config.rig)
	solver = Renderer.new(library)

## A confirmed hit creates a bounded one-shot; the material's physical particles stay shared.
func spawn(ground: Vector2, direction: Vector2, seed_value: int, strong := false, pixel := 2.0) -> void:
	prepare()
	var aim := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	if live.size() >= int(config.cap): live.pop_front()
	live.append({"ground":ground,"at":ground-aim*float(config.contact_inset)*pixel-Vector2(0,float(config.lift)*pixel),"aim":aim,"seed":seed_value,"strong":strong,"pixel":pixel,"age":0.0})

## Time belongs to feedback update, never to draw frequency.
func update(delta: float) -> void:
	for index in range(live.size()-1,-1,-1):
		live[index].age = float(live[index].age)+maxf(0,delta)
		if float(live[index].age) >= float(config.life): live.remove_at(index)

## A room/run change removes every old impact immediately.
func clear() -> void:
	live.clear()

## The core snaps off first; four rays open, four chips spin and fall independently.
static func parts(event: Dictionary) -> Array:
	prepare()
	var age := float(event.age)
	var p := age/float(config.life)
	if age < 0 or p >= 1: return []
	var aim: Vector2 = event.aim
	var strength := 1.2 if bool(event.get("strong",false)) else 1.0
	var pose := Poses.blank()
	pose.whole.rot = aim.angle()+float(int(event.seed)%5-2)*0.07
	var fade := 1.0-smoothstep(0.35,1,p)
	var out: Array = []
	for index in range(1,rig.parts.size()):
		var part: Dictionary = rig.parts[index]
		var direction := (Vector2(part.pivot)-Vector2(8,8)).normalized()
		var joint := Poses.P(pose,str(part.id))
		if str(part.id).begins_with("ray_"):
			var travel := (1-pow(1-p,3))*float(config.travel)*strength
			joint.dx = direction.x*travel
			joint.dy = direction.y*travel
		else:
			# Gravity points down on screen even when the impact rig faces another way.
			var flight := direction*age*float(config.chip_speed)*strength
			flight += Vector2(0,-float(config.chip_lift)*age+0.5*float(config.gravity)*age*age).rotated(-float(pose.whole.rot))
			joint.dx = flight.x
			joint.dy = flight.y
			joint.rot = age*float(config.spin)*(-1.0 if index%2 else 1.0)
	var world: Dictionary = solver.solve_pose(rig,pose,Vector2(event.at),1,float(event.pixel))
	for part: Dictionary in rig.parts:
		var alpha := (1.0-age/float(config.core_s)) if str(part.id)=="core" else fade
		if alpha <= 0: continue
		out.append({"id":part.id,"texture":part.texture,"bounds":part.bounds,"transform":world[part.id],"tint":Color(1,1,1,ceilf(alpha*4)/4)})
	return out

## Ground clipping uses the same room boundary as the game's other articulated effects.
func draw(canvas: CanvasItem, sprites: RefCounted) -> void:
	if sprites == null: return
	for event: Dictionary in live:
		sprites.draw_external_rig(canvas,parts(event),Vector2(event.ground))
