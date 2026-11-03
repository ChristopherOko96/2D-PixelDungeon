extends SceneTree
## The hero's x-ray (nacharbeit L1, VORSCHLAEGE.md A3; src/rig/rig_renderer.gd
## draw_xray, src/hero/story_hero.gd draw_cover): an enemy figure standing in
## front of the hero (feet lower) that covers his body is noted with the parts
## that cover him (hero_cover), and the hero's renderer draws his silhouette
## only where those parts hide him. An enemy behind him covers nothing, and
## with no covers nothing is drawn. Two plain renderers, no game.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const HERO_AT := Vector2(240, 200)
const HERO_RIG := "knight"
const FOE_RIG := "skeleton"
const SIZE := 1.5
var checked := 0
var failures: Array[String] = []
var _canvas: Node2D
var _draw_fn := Callable()


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("HERO_XRAY_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_canvas = Node2D.new()
	root.add_child(_canvas)
	_canvas.draw.connect(func() -> void: if _draw_fn.is_valid(): _draw_fn.call())
	var library: RefCounted = RigLibrary.shared()
	check(not library.rig(HERO_RIG).is_empty() and not library.rig(FOE_RIG).is_empty(), "the knight and skeleton rigs load")
	if failures.is_empty():
		await _test_front_enemy_covers_and_xray_draws(library)
		await _test_enemy_behind_covers_nothing(library)
		await _test_no_covers_draws_nothing(library)
	_canvas.queue_free()
	print("HERO_XRAY checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _draw(fn: Callable) -> void:
	_draw_fn = fn
	_canvas.queue_redraw()
	await process_frame
	await process_frame
	_draw_fn = Callable()


## The hero drawn on `hero`, then `foes` minding his body and drawing a skeleton
## at his centre + `offset`; returns {covered, covers, xray (px drawn)}.
func _scene(library: RefCounted, offset: Vector2, with_covers := true) -> Dictionary:
	var hero := RigRenderer.new(library)
	var foes := RigRenderer.new(library)
	var out := {}
	await _draw(func() -> void:
		hero.draw_hero(_canvas, "hero", {"hp": 1}, HERO_AT, HERO_RIG, 1.0, 1.0, SIZE)
		var feet: Vector2 = hero.actor_feet("hero")
		foes.guard_hero(_canvas, Rect2(feet.x - 20.0, feet.y - 60.0, 40.0, 60.0))
		foes.draw_enemy(_canvas, {"rig": FOE_RIG, "uid": 7, "face": -1.0}, HERO_AT + offset)
		out.covered = foes.hero_covered
		out.covers = foes.hero_cover.duplicate()
		out.xray = hero.draw_xray(_canvas, "hero", foes.hero_cover if with_covers else [], Color("f2b84b"), Color("120d16")))
	return out


func _test_front_enemy_covers_and_xray_draws(library: RefCounted) -> void:
	# Arrange / Act: a skeleton a little lower than the hero (in front of him), over his body
	var seen := {}
	for dy: float in [12.0, 18.0, 24.0, 30.0]:
		seen = await _scene(library, Vector2(6, dy))
		if bool(seen.get("covered", false)): break
	# Assert
	check(bool(seen.get("covered", false)), "a skeleton standing in front over the hero covers him")
	check(not (seen.get("covers", []) as Array).is_empty() and (seen.covers[0] as Dictionary).get("image") is Image, "the covering parts are noted with their images")
	check(int(seen.get("xray", 0)) > 0, "the hero's x-ray is drawn where he is hidden (%d px)" % int(seen.get("xray", 0)))


func _test_enemy_behind_covers_nothing(library: RefCounted) -> void:
	# Arrange / Act: the skeleton stands behind him (its feet higher up)
	var seen: Dictionary = await _scene(library, Vector2(6, -30))
	# Assert
	check(not bool(seen.covered) and (seen.covers as Array).is_empty() and int(seen.xray) == 0, "a skeleton behind the hero covers nothing and no x-ray is drawn")


func _test_no_covers_draws_nothing(library: RefCounted) -> void:
	# Arrange / Act: in front, but the x-ray is handed no covers
	var seen: Dictionary = await _scene(library, Vector2(6, 18), false)
	# Assert
	check(int(seen.xray) == 0, "without covers the x-ray draws nothing")
