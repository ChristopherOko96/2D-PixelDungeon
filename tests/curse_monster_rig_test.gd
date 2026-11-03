extends SceneTree
const Monster = preload("res://src/rig/curse_monster_rig.gd")
const Library = preload("res://src/rig/rig_library.gd")
const Renderer = preload("res://src/rig/rig_renderer.gd")
const Companions = preload("res://src/vfx/companion_rigs.gd")
const BoneBall = preload("res://src/rig/bone_ball_rig.gd")
var checked := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failed += 1
		printerr("CURSE_MONSTER_RIG_FAIL: ",label)
func _initialize() -> void:
	var library := Library.shared()
	library.rigs.erase("curse_colossus")
	check(Companions.draws("curse_colossus"),"cold client can display first monster without an earlier companion")
	Monster.prepare(library)
	var rig: Dictionary = library.rig("curse_colossus")
	check(rig.parts.size()==8 and rig.family=="curse_monster","eight actual articulated approved curse parts")
	check(float(rig.scale)==3.0,"large monster uses native integer3x pixels")
	check(Companions.draws("curse_colossus"),"ordinary companion rendering recognizes new monster")
	var solver := Renderer.new(library)
	var companions := Companions.new(solver)
	companions.register(solver)
	check(solver.families.has("curse_monster"),"existing renderer has actual curse pose family")
	var a := Monster.pose(rig,{"t":1.0,"clip":"hover"})
	var b := Monster.pose(rig,{"t":1.0+1.0/60.0,"clip":"hover"})
	var aw: Dictionary = solver.solve_pose(rig,a,Vector2(300,240),1,3)
	var bw: Dictionary = solver.solve_pose(rig,b,Vector2(300,240),1,3)
	for part: Dictionary in rig.parts:
		check(Rect2(part.bounds).has_area() and part.texture!=null,str(part.id)+" has original visible source pixels")
		check((Transform2D(aw[part.id])*Vector2(part.center)).distance_to(Transform2D(bw[part.id])*Vector2(part.center))<1.5,str(part.id)+" moves continuously")
		if not str(part.parent).is_empty(): check(rig.by_id.has(part.parent),"valid parent for "+str(part.id))
	var strike := Monster.pose(rig,{"t":1.0,"clip":"attack","u":0.5})
	check(float(strike.parts.claw_r.dx)>3 and float(strike.parts.claw_l.dx)>2,"both claws have a real attack pose")
	var texture: Texture2D = rig.parts[0].texture
	Monster.prepare(library)
	check(library.rig("curse_colossus").parts[0].texture==texture,"approved source textures cached")
	check(Companions.draws("curse_spawn") and library.rig("curse_spawn").parts.size()==8,"cold miniature uses same approved eight parts")
	check(float(library.rig("curse_spawn").scale)==1.0,"miniature uses native1x pixels versus giant3x")
	var wave := Monster.pose(rig,{"t":1.0,"curse_command":"curse_wave","curse_left":0.15})
	check(float(wave.parts.claw_l.dy)<-2 and float(wave.parts.jaw.dy)>1,"continuous command raises claws and opens jaw")
	var balls := BoneBall.parts(Vector2(300,240),1,2)
	var next := BoneBall.parts(Vector2(300,240),1+1.0/60,2)
	check(balls.size()==7,"knochenball has seven actual cutout joints")
	for n in range(balls.size()):
		check(balls[n].texture==next[n].texture,"boneball texture cached")
		check(Transform2D(balls[n].transform).origin.distance_to(Transform2D(next[n].transform).origin)<2,"boneball joint motion continuous")
	var assembled := BoneBall.parts(Vector2.ZERO,1,2,1,1)
	var gathering := BoneBall.parts(Vector2.ZERO,1,2,1,0)
	check(Transform2D(gathering[1].transform).origin.length()>Transform2D(assembled[1].transform).origin.length(),"windup physically gathers separate bones")
	print("CURSE_MONSTER_RIG checked=%d failures=%d" % [checked,failed])
	quit(1 if failed else 0)
