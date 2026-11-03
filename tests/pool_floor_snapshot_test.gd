extends SceneTree
## Immutable floor callbacks survive owner resets and execute on real workers.
const Particles = preload("res://src/vfx/particles.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("POOL_FLOOR_FAIL: ",label)
func _initialize() -> void:
	var particles := Particles.new()
	particles.set_walkable({Vector2i(2,3):true},"first")
	var floor_open := particles.open_floor_test()
	check(floor_open.call(Vector2(70,100)),"original floor open")
	check(not floor_open.call(Vector2(0,0)),"original wall closed")
	particles.set_walkable({Vector2i.ZERO:true},"replacement")
	particles = null
	var result := {}
	var task := WorkerThreadPool.add_task(func():
		result.open = floor_open.call(Vector2(70,100))
		result.wall = floor_open.call(Vector2.ZERO))
	WorkerThreadPool.wait_for_task_completion(task)
	check(bool(result.open) and not bool(result.wall),"real worker retains original immutable floor after reset/free")
	particles=Particles.new()
	particles.set_layout({"play_bounds":[0,0,160,128],"obstacles":[[64,0,8,128]]},"rectangle")
	var rectangular := particles.open_floor_test()
	check(rectangular.call(Vector2(40,40)) and not rectangular.call(Vector2(67,40)),"legacy room snapshot respects exact thin obstacle")
	check(not rectangular.call(Vector2(180,40)),"legacy room snapshot respects world bounds")
	particles.set_walkable({Vector2i.ZERO:true},"other")
	check(not rectangular.call(Vector2(67,40)),"old geometry snapshot survives another floor mode")
	print("POOL_FLOOR checked=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
