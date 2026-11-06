extends SceneTree
## Nine-part ownership, actual parent chains, wall planes and render-rate independent matter.
const Art=preload("res://src/vfx/marksman_art.gd")
const Matter=preload("res://src/vfx/marksman_matter.gd")
const Look=preload("res://src/hero/hero_look.gd")
class World extends RefCounted:
	var layout_key:="room-a"
	var emitted: Array=[]
	var spark_count:=0
	var full:=false
	func count() -> int: return 600 if full else emitted.size()
	func emit(at: Vector2, vel: Vector2, color: Color, life: float, _mode: String, _size: float, _height: float, _lift: float, _drag: float) -> Dictionary:
		var p:={"at":at,"vel":vel,"color":color,"life":life}
		emitted.append(p)
		return p
	func sparks(_at: Vector2, _dir: Vector2, n: int, _colors: Array) -> void: spark_count+=n
var checked:=0
var failures:=0
func check(ok: bool, text: String) -> void:
	checked+=1
	if not ok:
		failures+=1
		printerr("ULTIMATE_FX_FAIL ",text)
func event() -> Dictionary:
	return {"id":1,"kind":"spear","talent":"sniper_14","x":100.0,"y":100.0,"tx":800.0,"ty":100.0,"r":38.4,"wall":true,"nx":-1.0,"ny":0.0,"span":0.93,"life":0.93,"flight":0.28/0.93}
func _initialize() -> void:
	var first:=Art.spear_parts(Vector2(100,100),Vector2.RIGHT,0,2,0)
	var second:=Art.spear_parts(Vector2(100,100),Vector2.RIGHT,0.13,2,1)
	check(first.size()==9 and second.size()==9,"ultimate has nine real textured parts")
	var image: Image=(load("res://assets/sprites/marksman/celestial_lance.png") as Texture2D).get_image()
	var source:=0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a>0.5: source+=1
	var owned:=0
	for n in range(first.size()):
		var part: Dictionary=first[n]
		check(part.texture==second[n].texture,"no new texture while posing "+str(part.id))
		var native: Image=part.texture.get_image()
		var pixels:=0
		for y in range(native.get_height()):
			for x in range(native.get_width()):
				if native.get_pixel(x,y).a>0.5: pixels+=1
		check(pixels>0,"every advertised part has actual pixels "+str(part.id))
		owned+=pixels
	check(owned==source,"source pixels are assigned exactly once")
	check(first[0].transform!=second[0].transform and first[1].transform!=second[1].transform,"both halves of the spearhead unfold")
	check(str(Art.spear_rig.by_id.tip.parent)=="shaft_front","head follows the front shaft joint")
	var wake:=Art.wake_parts(Vector2.ZERO,Vector2(300,0),Vector2.RIGHT,0,2)
	var wake_next:=Art.wake_parts(Vector2.ZERO,Vector2(300,0),Vector2.RIGHT,0.1,2)
	check(wake.size()==10,"two genuine five-joint wake chains")
	check(str(Art.wake_rig.by_id.wake_0_4.parent)=="wake_0_3","wake tip inherits its previous joint")
	check(wake[4].transform!=wake_next[4].transform,"wake waves rather than stamping whole arrows")
	var behind:=true
	for part: Dictionary in wake:
		var b: Rect2=part.bounds
		for corner: Vector2 in [b.position,Vector2(b.end.x,b.position.y),b.end,Vector2(b.position.x,b.end.y)]:
			if (Transform2D(part.transform)*corner).x>=300: behind=false
	check(behind,"wake starts behind its tail anchor, outside the opaque spear body")
	check(Art.wake_parts(Vector2.ZERO,Vector2(1,0),Vector2.RIGHT,0,2).is_empty(),"no wake before the launch origin")
	for direction: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized()]:
		var shot:=event()
		var to:=Vector2(100,100)+direction*700
		shot.tx=to.x
		shot.ty=to.y
		shot.nx=-direction.x
		shot.ny=-direction.y
		var pieces:=Art.fragments(shot,0.2,1,2)
		var valid:=true
		for part: Dictionary in pieces:
			var b: Rect2=part.bounds
			for corner: Vector2 in [b.position,Vector2(b.end.x,b.position.y),b.end,Vector2(b.position.x,b.end.y)]:
				if ((Transform2D(part.transform)*corner-to).dot(-direction))< -0.01: valid=false
		check(valid,"rotating debris stays on caster side of contact plane "+str(direction))
	var slow:=emission(60)
	var fast:=emission(144)
	check(absi(int(slow.trail)-int(fast.trail))<=1,"flight particle rate independent of 60 versus 144 draws/s")
	check(int(slow.sparks)==int(Art.ultimate.release_sparks) and slow.sparks==fast.sparks,"one release spark burst at either frame rate")
	var world:=World.new()
	var matter:=Matter.new()
	var shot:=event()
	var state:={"events":[shot]}
	matter.update(state,0,world,1,2)
	matter.update(state,0.1,world,1,2)
	var n:=world.emitted.size()
	var sparks:=world.spark_count
	for draw in range(12): matter.update(state,0.1,world,1,2)
	check(world.emitted.size()==n and world.spark_count==sparks,"redrawing a paused frame adds no matter")
	check(is_equal_approx(matter.age_for(shot,0.15),0.05),"repeated snapshots never extrapolate more than fifty ms beyond the host")
	shot.life=0.79
	check(is_equal_approx(matter.age_for(shot,0.2),0.19),"new host age advances the bounded presentation clock")
	world.full=true
	matter.update(state,0.2,world,1,2)
	check(world.emitted.size()==n,"global particle soft cap is respected")
	world.full=false
	world.layout_key="room-b"
	matter.update({},0.3,world,1,2)
	check(matter.shots.is_empty() and matter.charges.is_empty(),"room boundaries forget shot and charge clocks")
	shot.life=0.2
	matter.update(state,1,world,1,2)
	check(world.spark_count==sparks,"joining after impact never replays launch sparks")
	var charge:={"owner":1,"talent":"sniper_14","x":100.0,"y":100.0,"ax":1.0,"ay":0.0,"power":0.8,"age":1.2}
	matter.update({"charges":[charge]},2,world,1,2)
	matter.update({"charges":[charge]},2.1,world,1,2)
	check(world.emitted.size()>n,"holding paid charge attracts physical motes")
	check(world.emitted[-1].vel.length()>0,"charge motes have actual velocities")
	matter.update({},2.2,world,1,2)
	check(matter.charges.is_empty(),"cancelled charge does not keep emitting")
	var look:=Look.new()
	check(look.bow_socket("hero",Vector2(9,9),1)==Vector2(9,9),"missing bow socket keeps a safe fallback")
	look._bow_sockets.hero={"at":Vector2(50,60),"clock":1.0}
	check(look.bow_socket("hero",Vector2.ZERO,1)==Vector2(50,60),"current frame uses the actual posed bow centre")
	check(look.bow_socket("hero",Vector2(9,9),2)==Vector2(9,9),"stale bow socket cannot drag the charge behind the player")
	print("MARKSMAN_ULTIMATE_FX checked=%d failures=%d"%[checked,failures])
	quit(1 if failures else 0)
func emission(fps: int) -> Dictionary:
	var matter:=Matter.new()
	var world:=World.new()
	var shot:=event()
	for frame in range(fps+1):
		var clock:=float(frame)/fps
		shot.life=maxf(0,0.93-clock)
		matter.update({"events":[shot]},clock,world,1,2)
	return {"trail":world.emitted.size(),"sparks":world.spark_count}
