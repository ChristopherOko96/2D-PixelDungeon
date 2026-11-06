extends SceneTree
## Paired CPU A/B on a seeded real Krypta floor; no FPS claim.
## Baseline: three scripts from 7c39036e in output/enemy-index-baseline,
## with that hell_game.gd pointing at the two baseline adapter scripts.
## Run alone: --headless --path . -s res://scripts/bench_story_enemies.gd
const SCENE = preload("res://src/hell/krypta_dungeon.tscn")
const OUT := "res://output/enemy-index-bench"
var games:Array[Node]=[]

func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for legacy:bool in [true,false]:
		seed(4242)
		var game:Node=SCENE.instantiate()
		var theme:String=game.theme_path
		game.set_script(load("res://output/enemy-index-baseline/hell_game.gd" if legacy else "res://src/hell/hell_game.gd"))
		game.theme_path=theme
		var label:String="paired-before" if legacy else "paired-after"
		game.class_id="necromancer"
		game.profile_path=OUT.path_join(label+"-profile.json")
		game.meta_path=OUT.path_join(label+"-meta.json")
		game.settings_path=OUT.path_join(label+"-settings.cfg")
		game.graphics_path=game.settings_path
		root.add_child(game)
		game.set_process(false)
		games.append(game)
		await process_frame
		if game.loading_screen!=null:
			game.loading_screen.queue_free()
			game.loading_screen=null
		var room:Dictionary={}
		for r:Dictionary in game.W.rooms:
			r.cleared=true
			r.fight=false
			if str(r.type)=="combat" and (room.is_empty() or r.cells.size()>room.cells.size()):room=r
		var points:Array[Vector2]=[]
		for cell:Vector2i in room.cells:
			var point:Vector2=(Vector2(cell)+Vector2(0.5,0.8))*game.C
			if not game.box_blocked(game._player_box(point.x,point.y)):points.append(point)
		assert(points.size()>3)
		game.set_meta("bench_room",room)
		game.set_meta("bench_points",points)
	var rows:Array=[]
	for dense:bool in [false,true]:
		for n:int in [8,32,64,128]:
			for game:Node in games:_reset_case(game,n,dense)
			for j in range(8):
				for game:Node in games:
					seed(400+j)
					game._update(1.0/60)
			var times:Array=[[],[]]
			var ratios:Array=[]
			for j in range(60):
				for k:int in ([0,1] if j%2==0 else [1,0]):
					seed(500+j)
					var start:int=Time.get_ticks_usec()
					games[k]._update(1.0/60)
					times[k].append(float(Time.get_ticks_usec()-start)/1000)
				ratios.append(float(times[0].back())/maxf(0.001,float(times[1].back())))
			var chase:Array=[[],[]]
			for j in range(40):
				for k:int in ([0,1] if j%2==0 else [1,0]):
					var game:Node=games[k]
					var start:int=Time.get_ticks_usec()
					for m:Dictionary in game.mobs:game.talents.chase_goal(m,Vector2(game.player.x,game.player.y))
					chase[k].append(float(Time.get_ticks_usec()-start)/1000)
			var same:bool=games[0].mobs.size()==games[1].mobs.size()
			for i in range(mini(games[0].mobs.size(),games[1].mobs.size())):
				same=same and Vector2(games[0].mobs[i].p).is_equal_approx(Vector2(games[1].mobs[i].p))
			ratios.sort()
			var row:Dictionary={"mobs":n,"dense":dense,"before":stats(times[0]),"after":stats(times[1]),"chase_before":stats(chase[0]),"chase_after":stats(chase[1]),"paired_speedup_median":ratios[ratios.size()/2],"motion_same":same}
			rows.append(row)
			print("ENEMY_PAIRED ",JSON.stringify(row))
	var f:=FileAccess.open(OUT.path_join("paired.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(rows,"\t"))
	f.close()
	for game:Node in games:game.queue_free()
	await process_frame
	for label:String in ["paired-before","paired-after"]:
		for suffix:String in ["-profile.json","-meta.json","-settings.cfg"]:
			var path:=ProjectSettings.globalize_path(OUT.path_join(label+suffix))
			if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("ENEMY_PAIRED_DONE")
	quit()

func _reset_case(game:Node,n:int,dense:bool)->void:
	seed(8242+n)
	game.mobs.clear()
	game.eshots.clear()
	game.shots.clear()
	game.monsters.reset()
	game.feel.reset()
	game.feel.feedback.particles.clear()
	game.state.t=20.0
	game.state.inv=9999.0
	game.state.dead=0.0
	var room:Dictionary=game.get_meta("bench_room")
	var points:Array=game.get_meta("bench_points")
	var hero:Vector2=points[points.size()/2]
	game.player.x=hero.x
	game.player.y=hero.y
	for i in range(n):
		var point:Vector2=points[0]+Vector2((i%8)*3,(i/8)*3) if dense else points[(i*31)%points.size()]
		var m:Dictionary=game.monsters.spawn(room.index,point,"skelett")
		m.hp=100000.0
		m.max=100000.0
		m.spawn=0.0
		m.cds.fill(99.0)
	game.talents._sync_mobs()

func stats(values:Array)->Dictionary:
	values.sort()
	var total:=0.0
	for value:float in values:total+=value
	return {"mean_ms":total/values.size(),"p95_ms":values[int(values.size()*0.95)]}
