extends SceneTree
## Status-to-matter lifecycle, distinct motion, bounded rates and no gameplay residue.
const Fx = preload("res://src/vfx/enemy_status_fx.gd")
const Feedback = preload("res://src/vfx/feedback.gd")
var checked := 0
var failures := 0
class World extends RefCounted:
	var emitted: Array = []
	var occupied := 0
	func count() -> int: return occupied + emitted.size()
	func emit(at: Vector2, velocity: Vector2, colour: Color, life: float, mode: String, size: float, height: float, lift: float, drag: float) -> Dictionary:
		var p := {"at": at, "vel": velocity, "color": colour, "life": life, "mode": mode, "size": size, "height": height, "lift": lift, "drag": drag}
		emitted.append(p)
		return p
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("STATUS_FX_FAIL ", label)
func enemy(statuses: Variant = ["burn", "poison", "wet", "freeze"]) -> Dictionary:
	return {"id": 1, "x": 100.0, "y": 100.0, "hp": 10.0, "statuses": statuses}
func _initialize() -> void:
	var fx := Fx.new()
	var world := World.new()
	var e := enemy()
	var before := e.duplicate(true)
	fx.observe([e])
	for n in range(10): fx.observe([e])
	check(world.emitted.is_empty(), "repeated snapshots never emit")
	fx.update(0, world)
	check(world.emitted.is_empty(), "paused time never emits")
	fx.update(0.1, world)
	check(world.emitted.size() == 4, "independent rates emit burn, poison and wet in first tenth second")
	fx.update(0.1, world)
	var kinds: Dictionary = {}
	for p: Dictionary in world.emitted:
		kinds[p.status_kind] = p
		check(not p.settle and p.fade, "status matter fades without creating persistent floor matter")
	check(kinds.size() == 4, "all four supported effects coexist")
	check(kinds.burn.gravity < 0 and kinds.burn.has("ramp"), "fire rises as actual flame tongues")
	check(kinds.poison.gravity < 0 and not kinds.poison.has("ramp"), "poison bubbles rise without fire shape")
	check(kinds.wet.gravity > 0 and kinds.wet.lift < 0, "water droplets fall down the body")
	check(kinds.freeze.plus, "frost has crystalline sparkle shape")
	check(e == before, "presentation never mutates authoritative enemy or statuses")
	e.x = 400
	fx.observe([e])
	var start := world.emitted.size()
	fx.update(0.1, world)
	check(world.emitted[start].at.x > 350, "new particles follow moved actor instead of old location")
	fx.observe([enemy([])])
	start = world.emitted.size()
	fx.update(0.1, world)
	check(world.emitted.size() == start and fx.actors.is_empty(), "cure immediately stops every emitter")
	e = enemy()
	e.hp = 0
	fx.observe([e])
	check(fx.actors.is_empty(), "dead actors do not emit")
	e.hp = 1
	e.dying_p = 0.1
	fx.observe([e])
	check(fx.actors.is_empty(), "dying animation does not emit")
	check(Fx.active(enemy({"burn": {"time": 0}, "poison": {"time": 2}})) == ["poison"], "expired dictionary entries are ignored")
	check(Fx.story_statuses({"hp": 1, "poison_t": 2, "bleed_t": 3, "stun": 2}) == ["poison"], "poison, blood and generic stun never masquerade as fire or frost")
	check(Fx.story_statuses({"hp": 1, "burn_t": 2, "wet_t": 2}) == ["wet"], "doused story burn timer cannot show false flames")
	check(Fx.story_statuses({"hp": 1, "fire_t": 2, "poison_t": 2, "frozen": 1}) == ["burn", "poison", "freeze"], "story fire, poison and real frost are mapped independently")
	var slow := rates(60)
	var fast := rates(144)
	for kind: String in Fx.settings().styles:
		check(absi(int(slow.get(kind, 0)) - int(fast.get(kind, 0))) <= 1, "rate independent of refresh frequency: " + kind)
	world = World.new()
	world.occupied = int(Fx.settings().soft_cap)
	fx.observe([enemy()])
	fx.update(0.1, world)
	check(world.emitted.is_empty(), "soft cap reserves room for combat matter")
	world.occupied = 0
	fx.update(0.001, world)
	check(world.emitted.is_empty(), "budget saturation never accumulates burst debt")
	var crowd: Array = []
	for id in range(100):
		var actor := enemy()
		actor.id = id
		crowd.append(actor)
	fx.observe(crowd)
	fx.update(1, world)
	check(world.emitted.size() <= int(Fx.settings().frame_budget), "long frames and crowds obey per-update cap")
	fx.clear()
	check(fx.actors.is_empty(), "reset clears all clocks")
	var feedback := Feedback.new()
	feedback.observe({"room_layout": {"id": "a"}, "enemies": [enemy()]}, 1)
	feedback.hitstop = 0.1
	feedback.update(0.05)
	check(feedback.particles.count() == 0, "hitstop freezes status emission with existing matter")
	feedback.update(0.1)
	feedback.update(0.1)
	check(feedback.particles.count() > 0, "shared feedback owner emits real solver particles")
	feedback.observe({"room_layout": {"id": "b"}, "enemies": []}, 1)
	check(feedback.particles.count() == 0 and feedback.status_fx.actors.is_empty(), "room change clears live status matter and clocks")
	print("ENEMY_STATUS_FX checked=%d failures=%d" % [checked, failures])
	quit(1 if failures else 0)
func rates(fps: int) -> Dictionary:
	var fx := Fx.new()
	var world := World.new()
	for frame in range(fps):
		fx.observe([enemy()])
		fx.update(1.0 / fps, world)
	var out: Dictionary = {}
	for p: Dictionary in world.emitted: out[p.status_kind] = int(out.get(p.status_kind, 0)) + 1
	return out
