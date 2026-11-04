extends SceneTree
## Isolated new CPU surface solver, not a whole-game FPS or four-peer claim.
const Motion = preload("res://src/vfx/surface_motion.gd")
func _initialize() -> void:
	var cfg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/vfx_pools.json")).surface_motion
	var surface := Motion.new(2,func(_p:Vector2)->bool:return true,cfg)
	surface.advance(0)
	surface.touch_box(Rect2(96,96,720,480))
	surface.pressure(Vector2(100,100),0,1100,0,TAU,340,1)
	var started:=Time.get_ticks_usec()
	for i in range(120):
		surface.advance(float(i+1)/60)
		surface.touch_box(Rect2(96,96,720,480))
	var mean_us:=float(Time.get_ticks_usec()-started)/120
	var ok:=mean_us<8000 and surface.nodes.size()<=int(cfg.max_nodes)
	print("SURFACE_BENCH nodes=%d mean_us=%.1f budget_us=8000 failures=%d"%[surface.nodes.size(),mean_us,0 if ok else 1])
	quit(0 if ok else 1)
