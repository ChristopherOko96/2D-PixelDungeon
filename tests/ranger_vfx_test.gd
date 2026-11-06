extends SceneTree
## Native fragments, continuous source joints and wall-contact particle scheduling.
const Art=preload("res://src/vfx/marksman_art.gd")
const Roots=preload("res://src/rig/forest_trap_rig.gd")
const Fx=preload("res://src/vfx/talent_fx.gd")
class Matter extends RefCounted:
	var chips_count:=0
	var sparks_count:=0
	var at:=Vector2.ZERO
	func chips(point: Vector2, n: int, _dir: Vector2, _colors: Array) -> void:
		at=point
		chips_count+=n
	func sparks(point: Vector2, _dir: Vector2, n: int, _colors: Array) -> void:
		at=point
		sparks_count+=n
var checked:=0
var failures:=0
func check(ok: bool, label: String) -> void:
	checked+=1
	if not ok: failures+=1; printerr("RANGER_VFX_FAIL: ",label)
func _initialize() -> void:
	var cfg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/vfx_talents.json")).ranger
	var event:={"id":97,"kind":"spear","talent":"sniper_14","x":100.0,"y":100.0,"tx":800.0,"ty":100.0,"r":38.4,"wall":true,"nx":-1.0,"ny":0.0,"span":0.93,"life":0.93,"flight":0.28/0.93}
	var a:=Art.fragments(event,0.1,2.0,2.0,cfg.arrow)
	var b:=Art.fragments(event,0.2,2.1,2.0,cfg.arrow)
	check(is_equal_approx(Art.arrow_scale(event,2,cfg.arrow)*float(Art.spear_rig.width),float(event.r)*2*float(cfg.arrow.width_share)),"native spear silhouette width reflects authoritative lane regardless of source resolution")
	check(a.size()==9 and b.size()==9,"wall breaks all nine independently rigged spear masks into fragments")
	for n in range(a.size()):
		check(a[n].texture==b[n].texture,"fragment source texture cached "+str(n))
		check(a[n].transform!=b[n].transform,"independent ballistic fragment motion "+str(n))
		var bounds: Rect2=b[n].bounds
		var matrix: Transform2D=b[n].transform
		var vertices:=[bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]
		check(vertices.all(func(p:Vector2)->bool:return (matrix*p).x<=800.01),"entire rotating fragment stays on caster side of impact wall "+str(n))
	check(Art.fragments(event,0.7,3,2,cfg.arrow).is_empty(),"fragments expire without a looping whole arrow")
	var roots:=Roots.lure_parts(Vector2(300,300),160,2,1,7,1,cfg.lure)
	var next:=Roots.lure_parts(Vector2(300,300),160,2,1.05,7,1,cfg.lure)
	check(roots.size()==9 and roots[1].texture==next[1].texture,"lure uses cached existing hub and eight joint cutouts")
	check(roots[1].transform!=next[1].transform,"lure joints flow between frames")
	var fx:=Fx.new()
	var matter:=Matter.new()
	fx.particles=matter
	fx.to_particles=1
	fx._observe({"events":[event]},5)
	fx._run_deferred(5.27)
	check(matter.chips_count==0 and matter.sparks_count==0,"wall particles wait for arrow arrival")
	fx._run_deferred(5.29)
	check(matter.chips_count==int(cfg.arrow.chip_count) and matter.sparks_count==int(cfg.arrow.spark_count),"one arrival emits physical chips and sparks")
	check(matter.at==Vector2(800,100),"burst occurs at actual first-wall endpoint")
	fx._observe({"events":[event]},5.3)
	fx._run_deferred(6)
	check(matter.chips_count==int(cfg.arrow.chip_count),"repeated snapshots never duplicate wall burst")
	print("RANGER_VFX checked=%d failures=%d"%[checked,failures])
	quit(1 if failures else 0)
