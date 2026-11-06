extends SceneTree
## Candidate completeness/order and local synchronisation, without a scene/save.
const INDEX_PATH := "res://src/physics_kit/story_enemy_index.gd"
var checked := 0
var failures := 0

class World extends Node:
	var mobs: Array = []

class CountAdapter extends "res://src/hell/hell_talents.gd":
	var full_syncs := 0
	func _sync_mobs() -> void:
		full_syncs += 1
		super._sync_mobs()

func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("STORY_ENEMY_INDEX_FAIL: ",label)

func _initialize() -> void:
	test_chase_syncs_only_the_queried_enemy_and_keeps_taunt()
	check(FileAccess.file_exists(INDEX_PATH),"shared spatial enemy index exists")
	if FileAccess.file_exists(INDEX_PATH):
		var script = load(INDEX_PATH)
		test_moves_removal_order_and_unbounded_boss(script)
		test_candidates_include_every_exact_overlap(script)
	print("STORY_ENEMY_INDEX checked=%d failures=%d"%[checked,failures])
	quit(0 if failures==0 else 1)

func test_chase_syncs_only_the_queried_enemy_and_keeps_taunt() -> void:
	var world := World.new()
	var adapter := CountAdapter.new()
	adapter.g = world
	adapter.tc.game = adapter
	adapter.players = {1:{"hp":6,"pos":Vector2.ZERO}}
	for i in range(32):world.mobs.append({"p":Vector2(i*200,50),"r":12.0,"hp":10.0,"boss":false})
	for enemy:Dictionary in world.mobs:adapter.chase_goal(enemy,Vector2.ZERO)
	check(adapter.full_syncs==0,"32 individual target queries never run a full-list sync")
	var ids := {}
	for enemy:Dictionary in world.mobs:ids[int(enemy.tid)] = true
	check(ids.size()==32,"local sync still supplies unique combat IDs")
	var enemy:Dictionary=world.mobs[0]
	enemy.p=Vector2(900,200)
	adapter.tc.pets=[{"id":8,"pos":Vector2(500,100)}]
	enemy.pet_taunt={"pet":8}
	check(adapter.chase_goal(enemy,Vector2.ZERO)==Vector2(500,100),"companion taunt retains its current target")
	check(enemy.pos==enemy.p and enemy.radius==enemy.r,"single-body position and radius remain current")
	enemy.pet_taunt={"pet":999}
	check(adapter.chase_goal(enemy,Vector2(10,20))==Vector2(10,20),"missing companion releases its target")
	adapter.release()
	world.free()

func test_moves_removal_order_and_unbounded_boss(script:Script) -> void:
	var index=script.new(96.0)
	var a:Dictionary={"p":Vector2(95,0),"r":20.0,"cy":45.0}
	var b:Dictionary={"p":Vector2(-1,0),"r":100.0,"cy":0.0}
	var far:Dictionary={"p":Vector2(4000,4000),"r":15.0}
	var boss:Dictionary={"p":Vector2(9000,9000),"r":20.0,"boss":true}
	index.rebuild([a,b,far,boss])
	var found:Array=index.near(Vector2(80,-45),5.0)
	check(found.size()==3 and is_same(found[0],a) and is_same(found[1],b),"multi-cell bodies deduplicate and retain original enemy order")
	check(is_same(found[-1],boss),"rig bosses remain conservative candidates beyond their nominal body")
	a.p=Vector2(2000,-300)
	index.upsert(a)
	check(not contains(index.near(Vector2(80,-45),5),a),"movement unlinks the old buckets")
	check(contains(index.near(a.p,1),a),"movement immediately links the new buckets")
	check(contains(index.swept(Vector2(1800,-300),Vector2(2200,-300),2),a),"swept shots find enemies between endpoints")
	index.remove(a)
	check(not contains(index.near(a.p,1),a),"removed enemies leave no stale candidate")
	index.upsert(a)
	check(contains(index.near(a.p,1),a),"a spawned/reinserted enemy is immediately queryable")
	index.rebuild([far])
	check(index.near(Vector2.ZERO,1).is_empty(),"a new list/floor discards old enemies and bosses")
	check(index.near(Vector2.ZERO,100000).size()==1,"huge queries remain complete without visiting an unbounded cell range")
	var rigged:Dictionary={"p":Vector2(1500,0),"r":12.0,"parts":{"weapon":1.0}}
	index.rebuild([rigged,far])
	check(contains(index.swept(Vector2.ZERO,Vector2(20,0),2),rigged),"animated part masks outside the nominal body are not culled from shot tests")
	check(not contains(index.near(Vector2.ZERO,2),rigged),"extended weapons do not turn body separation back into a global scan")

func test_candidates_include_every_exact_overlap(script:Script) -> void:
	var index=script.new(96.0)
	var rng:=RandomNumberGenerator.new()
	rng.seed=4242
	var actors:Array=[]
	for i in range(160):actors.append({"p":Vector2(rng.randf_range(-2000,2000),rng.randf_range(-2000,2000)),"r":rng.randf_range(8,85),"cy":rng.randf_range(0,100)})
	index.rebuild(actors)
	var total_candidates:=0
	for actor:Dictionary in actors:
		var nearby:Array=index.near(actor.p,float(actor.r))
		total_candidates+=nearby.size()
		var full_force:=Vector2.ZERO
		var indexed_force:=Vector2.ZERO
		for other:Dictionary in actors:full_force+=repel(actor,other)
		for other:Dictionary in nearby:indexed_force+=repel(actor,other)
		check(full_force.is_equal_approx(indexed_force),"indexed separation matches full scan at %s"%str(actor.p))
	check(total_candidates<actors.size()*actors.size()/5,"sparse horde avoids at least 80 percent of pair candidates")
	for i in range(30):
		var from:=Vector2(rng.randf_range(-2000,2000),rng.randf_range(-2000,2000))
		var to:=from+Vector2(rng.randf_range(-600,600),rng.randf_range(-600,600))
		var candidates:Array=index.swept(from,to,12)
		var complete:=true
		for actor:Dictionary in actors:
			for center:Vector2 in [Vector2(actor.p),Vector2(actor.p)-Vector2(0,float(actor.cy))]:
				if Geometry2D.get_closest_point_to_segment(center,from,to).distance_to(center)<=float(actor.r)+12:
					complete=complete and contains(candidates,actor)
		check(complete,"swept candidate set includes feet and raised body hits %d"%i)

func repel(actor:Dictionary,other:Dictionary)->Vector2:
	if is_same(actor,other):return Vector2.ZERO
	var offset:Vector2=actor.p-other.p
	var distance:=offset.length()
	return offset/distance*120 if distance>0 and distance<float(actor.r)+float(other.r) else Vector2.ZERO

func contains(actors:Array,actor:Dictionary)->bool:
	for other:Dictionary in actors:
		if is_same(other,actor):return true
	return false
