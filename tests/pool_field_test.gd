extends SceneTree
## The pool field (src/physics_kit/pool_field.gd, PoolField; BAUPLAN M1d) on a
## fake host, no game:
## - the shape stops at walls and keeps its volume;
## - a pool spreads from its middle, lives, ends rim first; finish ends it early;
## - materials_at lists every material lying there (ElementRules.top picks),
##   covers by style and alias, liquid_at / wet_at, pools_at with its owner,
##   centre, evaporate;
## - freeze_near gives ice one stands on (counts in materials_at, not in
##   covers), thaw_near takes it again;
## - a big pool shaped on a worker thread counts exactly from its commit_delay
##   on (the field waits for its worker then), never earlier, never later;
## - cells whose time is over are forgotten (purge);
## - the painter (src/vfx/pool_paint.gd) draws the field's own cells (the same
##   arrays), and what it draws only (drop puddles, a liquid turned to ice by an
##   ice pool) never counts in the field: the painter's old gameplay API
##   answers from the field.
## Values come from assets/data/vfx_pools.json. Deterministic; writes nothing.

const PoolPaint = preload("res://src/vfx/pool_paint.gd")
const ElementRules = preload("res://src/combat/element_rules.gd")
## World px per art cell in the tests (the story worlds' art pixel).
const ART := 3.0
## The wall: everything at x >= WALL_X world px is solid.
const WALL_X := 300.0
var checked := 0
var failures: Array[String] = []


## A fake floor: open everywhere left of WALL_X; counts its calls.
class FakeHost extends "res://src/physics_kit/field_host.gd":
	var calls := 0
	func is_open(point: Vector2) -> bool:
		calls += 1
		return point.x < 300.0


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("POOL_FIELD_FAIL: ", label)


func _initialize() -> void:
	_test_shape_stops_at_walls()
	_test_life_spread_and_finish()
	_test_materials_overlap_and_styles()
	_test_freeze_and_thaw()
	_test_owner_centre_evaporate()
	_test_worker_commit_is_deterministic()
	_test_purge()
	_test_painter_draws_the_field()
	_test_drawing_only_cells_never_count()
	print("POOL_FIELD checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## A field on the fake floor; every pool shaped at once unless `thread_cells` is given.
func _field(thread_cells := 1 << 30) -> PoolField:
	var field := PoolField.new(ART, FakeHost.new())
	field.cfg = PoolField.settings().duplicate(true)
	field.cfg.thread_cells = thread_cells
	return field


func _zone(id: int, style: String, at: Vector2, r: float, length: float, dir := Vector2.ZERO, owner := 0) -> Dictionary:
	return {"id": id, "k": "pool", "st": style, "x": at.x, "y": at.y, "r": r, "dx": dir.x, "dy": dir.y, "p": 0.0, "L": length, "owner": owner}


func _test_shape_stops_at_walls() -> void:
	var field := _field()
	# thrown at the wall from the left: it runs on along its flight and piles up there
	field.sync([_zone(1, "poison", Vector2(WALL_X - 40.0, 200.0), 60.0, 5.0, Vector2.RIGHT)], 0.0)
	field.advance(2.0)
	var cells: Dictionary = field.cells_of("poison")
	var beyond := 0
	for q: Vector2i in cells:
		if (float(q.x) + 0.5) * ART >= WALL_X: beyond += 1
	check(beyond == 0, "shape: no cell lies in the wall (%d did)" % beyond)
	# dropped straight down against the wall (no droplets flung ahead): its whole volume lies
	var blot := _field()
	blot.sync([_zone(2, "poison", Vector2(WALL_X - 20.0, 200.0), 60.0, 5.0)], 0.0)
	check(blot.cells_of("poison").size() == MatterKit.cells_for(60.0, ART, float(field.cfg.squash)), "shape: the volume is kept at the wall (%d cells)" % blot.cells_of("poison").size())
	check(field.materials_at(Vector2(WALL_X + 10.0, 200.0)).is_empty(), "shape: nothing lies behind the wall")
	check(field.materials_at(Vector2(WALL_X - 5.0, 200.0)) == ["poison"], "shape: it piles up against the wall")


func _test_life_spread_and_finish() -> void:
	var field := _field()
	var at := Vector2(120.0, 200.0)
	var rim := at + Vector2(0.0, 30.0)
	field.sync([_zone(1, "water", at, 50.0, 4.0)], 10.0)
	check(field.covers(at), "life: its middle lies at once")
	check(not field.covers(rim), "life: its rim is not there yet (it spreads)")
	field.advance(10.0 + float(field.cfg.spread_time) + 0.01)
	check(field.covers(rim), "life: after spread_time it reaches its rim")
	# the zone leaves the list: it ends now, rim first
	field.sync([], 11.0)
	check(field.covers(at) and field.pool("%s:%d" % ["", 1]).end == 11.0, "life: an ended pool keeps its middle a moment")
	field.advance(11.0 + float(field.cfg.edge_time))
	check(not field.covers(at) and not field.covers(rim), "life: half edge_time after its end it is gone")
	field.sync([], 13.0)
	check(not field.has_pool(":1"), "life: edge_time after its end the pool is forgotten")
	# a pool that runs its full time goes on its own
	field.sync([_zone(2, "water", at, 50.0, 2.0)], 20.0)
	field.advance(22.0)
	check(not field.covers(at), "life: at its end it is gone")


func _test_materials_overlap_and_styles() -> void:
	var field := _field()
	var at := Vector2(120.0, 200.0)
	field.sync([_zone(1, "poison", at, 50.0, 6.0), _zone(2, "lava", at + Vector2(10, 0), 50.0, 6.0), _zone(3, "flesh", Vector2(120.0, 400.0), 40.0, 6.0)], 0.0)
	field.advance(3.0)
	var mats: Array = field.materials_at(at)
	mats.sort()
	check(mats == ["lava", "poison"], "overlap: both materials lie there (%s)" % str(mats))
	check(ElementRules.top(field.materials_at(at)) == "lava", "overlap: the rules' priority picks lava")
	check(field.covers(Vector2(120.0, 400.0), "flesh") and field.covers(Vector2(120.0, 400.0), "blood"), "styles: flesh lies as blood")
	check(field.materials_at(Vector2(120.0, 400.0)) == ["blood"], "styles: its material is blood")
	check(not field.covers(at, "no_such_style"), "styles: an unknown style covers nothing")
	check(field.liquid_at(Vector2(120.0, 400.0)) == "blood" and field.wet_at(Vector2(120.0, 400.0)), "liquid_at / wet_at: blood is a liquid")
	check(field.liquid_at(Vector2(20.0, 20.0)) == "" and not field.wet_at(Vector2(20.0, 20.0)), "liquid_at: dry floor")


func _test_freeze_and_thaw() -> void:
	var field := _field()
	var at := Vector2(120.0, 200.0)
	field.sync([_zone(1, "water", at, 50.0, 8.0)], 0.0)
	field.advance(1.0)
	var frozen := field.freeze_near(at, 20.0)
	check(frozen > 0, "freeze: liquid near the frost freezes (%d cells)" % frozen)
	check(not field.materials_at(at).has("ice"), "freeze: the ice is not there at once (it freezes rim first)")
	field.advance(1.0 + float(field.cfg.physics.freeze_time) + 0.01)
	check(field.materials_at(at).has("ice") and field.materials_at(at).has("water"), "freeze: ice lies over the water (%s)" % str(field.materials_at(at)))
	check(ElementRules.top(field.materials_at(at)) == "ice", "freeze: one stands on ice")
	check(not field.covers(at, "ice"), "freeze: frozen ice is ground, no pool (covers)")
	check(field.materials_at(at + Vector2(40, 0)) == ["water"], "freeze: the water beyond the frost's reach stays water")
	var thawed := field.thaw_near(at, 60.0)
	check(thawed > 0 and not field.materials_at(at).has("ice"), "thaw: fire takes the ice again (%d cells)" % thawed)
	check(field.materials_at(at) == ["water"], "thaw: the water is there again")
	# from the fire's side: the ice farther away goes on its time (physics plan R25)
	check(field.materials_at(at + Vector2(16, 0)).has("ice"), "thaw: the ice farther from the fire is still there for a moment")
	field.advance(1.0 + float(field.cfg.physics.freeze_time) + 0.02 + float(field.cfg.physics.get("thaw_time", 0.35)))
	check(not field.materials_at(at + Vector2(16, 0)).has("ice"), "thaw: after thaw_time all of it has thawed")
	# poison freezes the same way; lava and fire are no liquid
	var hot := _field()
	hot.sync([_zone(1, "lava", at, 50.0, 8.0)], 0.0)
	hot.advance(1.0)
	check(hot.freeze_near(at, 40.0) == 0, "freeze: lava does not freeze")


func _test_owner_centre_evaporate() -> void:
	var field := _field()
	var a := Vector2(100.0, 200.0)
	var b := Vector2(100.0, 420.0)
	field.sync([_zone(1, "void", a, 40.0, 6.0, Vector2.ZERO, 7), _zone(2, "void", b, 40.0, 6.0), _zone(3, "water", Vector2(100.0, 650.0), 40.0, 6.0)], 0.0, "talent")
	field.advance(1.0)
	var here: Array = field.pools_at(a)
	check(here.size() == 1 and int(here[0].owner) == 7 and str(here[0].key) == "talent:1", "pools_at: the pool and its owner")
	# one pool asked by its key (a talent zone lying as a pool: talent_combat _zone_reach)
	check(field.pool_covers("talent:1", a) and not field.pool_covers("talent:1", b), "pool_covers: only that pool's own liquid")
	check(not field.pool_covers("talent:9", a), "pool_covers: an unknown pool covers nothing")
	check(field.centre(a + Vector2(5, 30), "void") == a, "centre: the nearest void pool's middle")
	check(field.centre(b + Vector2(0, -20), "curse") == b, "centre: by material (curse is void)")
	check(field.centre(Vector2(5, 5), "lava") == Vector2(5, 5), "centre: none of that material: the point itself")
	var ended: Array = field.evaporate(Vector2(100.0, 650.0), 20.0)
	check(ended == ["talent:3"], "evaporate: the water there ends (%s)" % str(ended))
	field.advance(1.0 + float(field.cfg.edge_time))
	check(field.materials_at(Vector2(100.0, 650.0)).is_empty(), "evaporate: it is gone rim first")
	check(field.materials_at(a) == ["void"], "evaporate: the void stays (no liquid)")


func _test_worker_commit_is_deterministic() -> void:
	# a pool of thread_cells cells or more is shaped on a worker thread
	var field := _field(50)
	var commit := field.commit_delay(MatterKit.cells_for(60.0, ART, float(field.cfg.squash)))
	var at := Vector2(120.0, 200.0)
	field.sync([_zone(1, "poison", at, 60.0, 5.0)], 0.0)
	check(field.pending() == 1, "worker: the big pool is being shaped")
	check(field.materials_at(at).is_empty(), "worker: it does not count before its moment")
	# however fast the worker is, the field's answer depends on its clock only
	OS.delay_msec(30)
	field.advance(commit * 0.5)
	check(field.pending() == 1 and field.materials_at(at).is_empty(), "worker: still nothing half way to its moment")
	field.advance(commit)
	check(field.pending() == 0 and field.has_pool(":1"), "worker: at its commit_delay it lies (the field waited for its worker)")
	check(field.materials_at(at) == ["poison"], "worker: and counts from then")
	# the same shape as shaped at once
	var direct := _field()
	direct.sync([_zone(1, "poison", at, 60.0, 5.0)], 0.0)
	check(direct.cells_of("poison").keys() == field.cells_of("poison").keys(), "worker: the same cells as on the main thread")
	# clear waits for its workers: nothing is left running
	var busy := _field(50)
	busy.sync([_zone(9, "poison", at, 60.0, 5.0)], 0.0)
	busy.clear()
	check(busy.pending() == 0 and busy.pools().is_empty(), "worker: clear waits and forgets")


func _test_purge() -> void:
	var field := _field()
	field.sync([_zone(1, "water", Vector2(120.0, 200.0), 40.0, 1.0)], 0.0)
	check(field.cells_of("water").size() > 0, "purge: cells while it lives")
	field.advance(1.5)
	field.advance(3.0)
	check(field.cells_of("water").is_empty() and not field.materials().has("water"), "purge: its cells are forgotten after their time")


func _test_painter_draws_the_field() -> void:
	var painter := PoolPaint.new(ART, func(p: Vector2) -> bool: return p.x < WALL_X)
	var at := Vector2(120.0, 200.0)
	painter.sync([_zone(1, "water", at, 40.0, 5.0)], 0.0, "boss")
	var field: PoolField = painter.pool_field
	var q := Vector2i((at / ART).floor())
	var drawn: Dictionary = painter._fields["water"].cells
	check(drawn.has(q) and is_same(drawn[q], field.cells_of("water")[q]), "painter: it draws the field's own cell")
	check(drawn.size() == field.cells_of("water").size(), "painter: every cell of the pool")
	painter.advance(1.0)
	check(painter.covers(at) == field.covers(at) and painter.materials_at(at) == field.materials_at(at), "painter: its gameplay API answers from the field")
	check(painter.handles("flesh") and painter.material_for("curse") == "void", "painter: styles through the field")
	# a big pool on a worker thread shows when the field lays it (the picture follows)
	var big := PoolPaint.new(ART, func(p: Vector2) -> bool: return p.x < WALL_X)
	big.pool_field.cfg = PoolField.settings().duplicate(true)
	big.pool_field.cfg.thread_cells = 50
	big.sync([_zone(2, "poison", at, 60.0, 5.0)], 0.0)
	check(not big._fields.has("poison"), "painter: nothing drawn before the field lays it")
	big.advance(big.pool_field.commit_delay(MatterKit.cells_for(60.0, ART, 0.75)))
	check(big._fields.has("poison") and (big._fields.poison.cells as Dictionary).size() == big.pool_field.cells_of("poison").size(), "painter: drawn when the field lays it")
	big.clear()
	painter.clear()


func _test_drawing_only_cells_never_count() -> void:
	var painter := PoolPaint.new(ART, func(p: Vector2) -> bool: return p.x < WALL_X)
	var at := Vector2(120.0, 200.0)
	# poison and a frost pool (an ice style) lying over each other: the poison there is
	# drawn as ice (vfx_pools.json reactions liquid+ice: a_to ice, drawing only)
	painter.sync([_zone(1, "poison", at, 50.0, 8.0), _zone(2, "frost", at + Vector2(20, 0), 40.0, 8.0)], 0.0)
	painter.advance(2.0)
	# the reactions run with the drawing; the fields' boxes come from the first shading
	for mat: String in painter._fields:
		painter._bake(painter._fields[mat], mat, painter._look(mat), 2.0, 0)
		while painter._fields[mat].has("work"):
			painter._bake_step(painter._fields[mat], Time.get_ticks_usec() + 1000000)
	painter._reacted = -100.0
	painter._react(2.0)
	var field: PoolField = painter.pool_field
	var overlap := 0
	var turned := 0
	var wrong := 0
	for q: Vector2i in field.cells_of("poison"):
		if not field.cells_of("frost").has(q):
			continue
		overlap += 1
		# drawn: the picture's ice holds the poison's cell, turned (a fourth entry)
		var c: Array = (painter._fields.get("ice", {"cells": {}}).cells as Dictionary).get(q, [])
		# (the old rule, pool_paint.gd materials_at before M1d, counted every live
		# ice cell of the picture: these are exactly the cells it got wrong)
		if c.size() > 3 and float(c[0]) <= 2.0 and 2.0 < float(c[1]):
			turned += 1
			# but the field never saw it: no ice lies there for the rules
			if painter.materials_at((Vector2(q) + Vector2(0.5, 0.5)) * ART).has("ice"): wrong += 1
	check(overlap > 0, "drawing only: the two pools overlap (%d cells)" % overlap)
	check(turned > 0, "drawing only: the poison turned to ice in the picture (%d cells)" % turned)
	check(wrong == 0, "drawing only: ice turned from a liquid never counts as ice (%d of %d did)" % [wrong, turned])
	# a drop puddle on dry floor is drawn, never a pool
	var dry := Vector2(40.0, 600.0)
	painter.drop_landed(dry, "poison")
	var dq := Vector2i((dry / ART).floor())
	check((painter._fields.poison.cells as Dictionary).has(dq), "drawing only: the drop lies in the picture")
	check(painter.materials_at(dry).is_empty() and not painter.covers(dry), "drawing only: a drop puddle never counts")
	painter.clear()
