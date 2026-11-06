extends SceneTree
## Actual story adapters: incremental membership and full-scan movement parity.
const SCENES := ["res://src/hell/krypta_dungeon.tscn","res://src/hell/frost_dungeon.tscn","res://src/hell/hell_dungeon.tscn"]
var checked:=0
var failures:=0
var scratch:=""

class FullScan extends "res://src/physics_kit/story_enemy_index.gd":
	func _query(_from:Vector2,_to:Vector2,_include_parts:=false)->Array:
		var result:Array=[]
		for entry:Dictionary in _entries:
			if not entry.is_empty():result.append(entry.actor)
		return result

func check(ok:bool,label:String)->void:
	checked+=1
	if not ok:
		failures+=1
		printerr("STORY_ENEMY_INTEGRATION_FAIL: ",label)

func _initialize()->void:
	scratch="res://tests/.tmp_enemy_index_%d"%Time.get_ticks_usec()
	_run.call_deferred()

func _run()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	for scene:String in SCENES:
		seed(4242)
		var game:Node=(load(scene) as PackedScene).instantiate()
		game.class_id="necromancer"
		game.profile_path=scratch.path_join("profile.json")
		game.meta_path=scratch.path_join("meta.cfg")
		game.settings_path=scratch.path_join("settings.cfg")
		game.graphics_path=game.settings_path
		root.add_child(game)
		game.set_process(false)
		await process_frame
		if game.loading_screen!=null:
			game.loading_screen.queue_free()
			game.loading_screen=null
		var room:Dictionary={}
		for candidate:Dictionary in game.W.rooms:
			candidate.cleared=true
			candidate.fight=false
			if str(candidate.type)=="combat" and (room.is_empty() or candidate.cells.size()>room.cells.size()):room=candidate
		var spots:Array=[]
		for cell:Vector2i in room.cells:
			var at:Vector2=(Vector2(cell)+Vector2(0.5,0.8))*game.C
			if not game.box_blocked(game._player_box(at.x,at.y)):spots.append(at)
		check(not spots.is_empty(),scene+": free test floor")
		if spots.is_empty():game.queue_free();await process_frame;continue
		game.mobs.clear()
		game.prepare_mob_queries()
		for i in range(32):
			var at:Vector2=spots[i%spots.size()]+Vector2((i%3)*4,0)
			if game.monsters!=null:
				var kind:String="skelett" if game.monsters.defs.has("skelett") else str(game.monsters.defs.keys()[0])
				game.monsters.spawn(room.index,at,kind)
			else:game._spawn_mob(room.index,at,"frost_skeleton")
			var enemy:Dictionary=game.mobs.back()
			enemy.spawn=0.0
			enemy.hp=10000.0
			enemy.max=10000.0
			enemy.shoot=99.0
			if enemy.has("cds"):enemy.cds.fill(99.0)
		var before_shots:Array=game.mobs.duplicate(true)
		var first:Dictionary=game.mobs[0]
		var second:Dictionary=game.mobs[1]
		first.p=spots[spots.size()/2]
		second.p=first.p
		first.r=20.0
		second.r=20.0
		first.cy=20.0
		second.cy=20.0
		game.mobs=[first,second]
		game.shots=[{"p":first.p-Vector2(0,20),"v":Vector2.ZERO,"t":1.0,"kind":"arrow","splash":0.0}]
		game._update_shots(0.0)
		check(float(first.hp)<10000.0 and float(second.hp)==10000.0,scene+": basic shot hits the original first overlapping enemy")
		first.hp=10000.0
		game.mobs=[second,first]
		game.shots=[{"p":first.p-Vector2(0,20),"v":Vector2.ZERO,"t":1.0,"kind":"arrow","splash":0.0}]
		game._update_shots(0.0)
		check(float(second.hp)<10000.0 and float(first.hp)==10000.0,scene+": changed enemy-list order still controls first hit")
		game.mobs=before_shots
		game.shots.clear()
		game.prepare_mob_queries()
		var enemy:Dictionary=game.mobs[0]
		game.talents._sync_mobs()
		check(not game.talents._talent_queries_ready,scene+": sync invalidates lazy talent phase")
		check(not game.talents.tc._nearest(enemy.p,0.0).is_empty() and game.talents._talent_queries_ready,scene+": first bounded talent query prepares real spatial phase")
		check(contains(game.mob_candidates(enemy.p,1),enemy),scene+": spawn immediately joins index")
		var original:Vector2=enemy.p
		enemy.p=original+Vector2(4000,0)
		game.mob_moved(enemy)
		check(contains(game.mob_candidates(enemy.p,1),enemy),scene+": teleport joins destination")
		check(is_same(game.talents.tc._nearest(enemy.p,0.0),enemy),scene+": talent target sees same-phase teleport")
		check(not contains(game.mob_candidates(original,1),enemy),scene+": teleport unlinks old location")
		enemy.p=original
		game.mob_moved(enemy)
		game.talents._sync_mobs()
		game.talents.tc._shove(enemy,original+Vector2(0,4000))
		check(enemy.p==enemy.pos and contains(game.mob_candidates(enemy.p,1),enemy),scene+": combat shove updates both position aliases and index")
		enemy.p=original
		game.mob_moved(enemy)
		var saved:Array=game.mobs.duplicate(true)
		var real_index:RefCounted=game._mob_space
		var traces:Array=[]
		for scan_all:bool in [false,true]:
			game.mobs=saved.duplicate(true)
			game._mob_space=FullScan.new(game.C) if scan_all else real_index
			game.state.inv=999.0
			game.state.dead=0.0
			game.player.x=Vector2(spots[0]).x+100
			game.player.y=Vector2(spots[0]).y
			for frame in range(4):
				seed(854+frame)
				game.state.t=40.0+frame/60.0
				game._update_mobs(1.0/60)
			var trace:Array=[]
			for body:Dictionary in game.mobs:trace.append(Vector2(body.p))
			traces.append(trace)
		var same:bool=traces[0].size()==traces[1].size()
		for i in range(mini(traces[0].size(),traces[1].size())):same=same and Vector2(traces[0][i]).is_equal_approx(traces[1][i])
		check(same,scene+": actual multi-body movement matches the full-scan oracle")
		game.end_run(false)
		check(game._mob_space._entries.is_empty(),scene+": run end releases indexed body references")
		game.queue_free()
		await process_frame
	for file:String in ["profile.json","meta.cfg","settings.cfg"]:
		var path:=ProjectSettings.globalize_path(scratch.path_join(file))
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	print("STORY_ENEMY_INTEGRATION checked=%d failures=%d"%[checked,failures])
	quit(0 if failures==0 else 1)

func contains(actors:Array,actor:Dictionary)->bool:
	for other:Dictionary in actors:
		if is_same(other,actor):return true
	return false
