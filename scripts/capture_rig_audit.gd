extends SceneTree
## Actual effect and monster draw routes, controlled visual fixtures, never gameplay proof.
const DEST:="res://production/qa/evidence/rig-audit"
class FeedbackStub extends RefCounted:
	func pose(_key: String,_entity: Dictionary,_clock: float) -> Dictionary: return {"alpha":1.0,"flash":0.0}
class Board extends Node2D:
	var fx:=preload("res://src/vfx/fx_sprites.gd").new()
	var monsters:=preload("res://src/vfx/sheet_art.gd").new()
	var font: Font=preload("res://assets/fonts/pixel_operator8.ttf")
	var _feedback:=FeedbackStub.new()
	var body_rigs:=preload("res://src/rig/rig_renderer.gd").new()
	var mode:="effects"
	var page:=0
	var clock:=0.3
	var fallbacks:=0
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		monsters.prepare({},func(t:Texture2D)->Texture2D:return t)
	func _position(e: Dictionary) -> Vector2: return e.pos
	func _box(x: float,y: float,w: float,h: float,col: Color) -> void: draw_rect(Rect2(x,y,w,h),col)
	func _draw_sprite(_t:Texture2D,_p:Vector2,_f:float,_feet:float,_pose:Dictionary,_s:float)->void: fallbacks+=1
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("171521"))
		draw_string(font,Vector2(30,30),"RIG-PRUEFANSICHT · BESTEHENDE QUELLGRAFIKEN · "+mode.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e5ca8c"))
		var names: Array=fx._sheets.keys() if mode=="effects" else ["glutschaedel","krypta_mimik","krypta_leerenbomber"] if mode=="native" else monsters.MOB_SPRITES.keys()+monsters.SHEET_KINDS.keys()
		var per:=28 if mode=="effects" else 21
		for index in range(page*per,mini(names.size(),(page+1)*per)):
			var local:=index%per
			var origin:=Vector2(30+(local%7)*175,60+(local/7)*150)
			draw_rect(Rect2(origin,Vector2(165,140)),Color("242130"))
			var name: String=names[index]
			var words:=name.split("_")
			draw_string(font,origin+Vector2(6,19),words[0],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ddd5bc"))
			if words.size()>1: draw_string(font,origin+Vector2(6,37),"_".join(words.slice(1)),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ddd5bc"))
			if mode=="effects":
				fx.pixel=1 if Vector2(fx._sheets[name].size).y>45 or Vector2(fx._sheets[name].size).x>76 else 2
				var sheet: Dictionary=fx._sheets[name]
				var corner:=origin+Vector2((165-Vector2(sheet.size).x*fx.pixel)*0.5,48+(88-Vector2(sheet.size).y*fx.pixel)*0.5)
				fx.draw_at(self,name,corner+Vector2(sheet.anchor)*fx.pixel,0,1,fposmod(clock*float(sheet.fps)/float(sheet.frames),1))
			elif mode=="native":
				body_rigs.draw_enemy(self,{"rig":name,"id":index+101,"hp":70,"max_hp":100,"moving":true,"attack":"windup","attack_p":0.4,"face":1.0},origin+Vector2(82,100))
			else:
				monsters.draw_enemy(self,{"kind":name,"pos":origin+Vector2(82,104),"id":index+1,"hp":70,"max_hp":100,"moving":true,"attack":"windup","attack_p":0.4,"face":-1.0 if index%2 else 1.0},clock)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	var board:=Board.new()
	root.add_child(board)
	await process_frame
	for mode: String in ["effects","monsters","native"]:
		board.mode=mode
		for page in range(3 if mode=="effects" else 1):
			board.page=page
			for phase in range(2):
				board.clock=0.3+phase*0.18
				board.body_rigs.step(0.18)
				board.queue_redraw()
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(DEST.path_join("%s-%d-%d.png"%[mode,page,phase]))
	print("RIG_CAPTURE images=10 native=1280x720 monster_fallbacks=",board.fallbacks)
	board.queue_free()
	await process_frame
	quit()
