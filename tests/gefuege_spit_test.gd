extends SceneTree
## The Singularität mixes the Leerenmagier's Arkanes Gefüge inside it into one clump and lets out
## only that mixture (user, 2026-11-01; src/combat/talent_combat.gd _collapse, _mix_globs,
## _land_mix; rules assets/data/madness_rules.json gefuege.spit), in a real story world (Hölle):
## - while the whirl runs, the zone carries the Gefüge's units for its clump look;
## - at the collapse the Gefüge empties: gefuege.spit.stay of every element stays in the explosion
##   zone, landing on the core at once as one mixed field ("mix_land" with stay) that goes on
##   mixing there (one "churn" event on the core); the rest flies out as min_count..count globs
##   with one "spit" event, every glob the same mixture (every element, an equal share, fire
##   last), spread round the core in all directions, gefuege.spit.m [min, max] metres away;
## - each glob lands as all its elements at once on its spot (one "land" each, fire last) and one
##   "mix_land" splash; nothing is scattered as single units any more (no "eject").
## Uses the test profile; deletes it and the test settings afterwards.

const Profile = preload("res://src/progress/profile.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const STEP := 1.0 / 60.0
const EXPECTED_CHECKS := 17

var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("GEFUEGE_SPIT_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await test_singularity_keeps_part_of_the_clump_and_spits_the_rest_into_every_corner()
	# a script error stops a test function silently: every check must have run
	if checked < EXPECTED_CHECKS:
		failures.append("only %d of %d checks ran (a script error stopped the test)" % [checked, EXPECTED_CHECKS])
		printerr("GEFUEGE_SPIT_FAIL: ", failures[-1])
	for path: String in [Profile.default_path(), "user://settings_test.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("GEFUEGE_SPIT checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _game() -> Node:
	var game: Node = HellScene.instantiate()
	game.class_id = "mage"
	game.settings_path = "user://settings_test.cfg"
	root.add_child(game)
	for i in range(2):
		await process_frame
	game.set_process(false)
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true
	game.mobs.clear()
	game.state.hp = 99
	game.state.max_hp = 99
	return game


## Steps the talents for `seconds`, keeping every new event (by id) in `seen`.
func _step(game: Node, seconds: float, seen: Dictionary) -> void:
	for k in range(roundi(seconds / STEP)):
		game.talents.update(STEP)
		for event: Dictionary in game.talents.tc.events:
			seen[int(event.id)] = event


func _of(seen: Dictionary, kind: String) -> Array:
	return seen.values().filter(func(e: Dictionary) -> bool: return str(e.kind) == kind)


func _spot(glob: Dictionary) -> Vector2:
	return Vector2(float(glob.tx), float(glob.ty))


func _kinds(mix: Array) -> Array:
	return mix.map(func(part: Dictionary) -> String: return str(part.el))


## True when `mix` holds poison, water and fire, the fire last.
func _whole(mix: Array) -> bool:
	var kinds := _kinds(mix)
	return kinds.size() == 3 and kinds.has("poison") and kinds.has("water") and str(kinds[-1]) == "fire"


func _units(mix: Array) -> float:
	var sum := 0.0
	for part: Dictionary in mix:
		sum += float(part.n)
	return sum


func test_singularity_keeps_part_of_the_clump_and_spits_the_rest_into_every_corner() -> void:
	# Arrange: the Leerenmagier with the Singularität, his Gefüge holding poison, water and fire
	var game := await _game()
	var tc: RefCounted = game.talents.tc
	tc.set_build(1, {"class": "mage", "level": 30})
	var rt: Dictionary = tc.runtime(1)
	var info: Dictionary = tc.data.talents["arcane_14"]
	rt.ranks["arcane_14"] = 1
	rt.bar = ["arcane_14"]
	rt.res = 999.0
	rt.gefuege = [{"el": "fire", "n": 5}, {"el": "poison", "n": 6}, {"el": "water", "n": 4}]
	var hero := Vector2(float(game.player.x), float(game.player.y))
	game.aim_at = hero + Vector2(160, -40)
	var spit: Dictionary = tc._gf_cfg().get("spit", {})
	var span: Array = spit.get("m", [6, 8])
	var stay := float(spit.get("stay", 0.4))
	var meter := float(tc.data.meter_px)
	var seen := {}
	# Act: cast, let the whirl run
	var fired: bool = game.talents.press(0)
	_step(game, 1.0, seen)
	# Assert: the whirl carries the Gefüge for its clump look
	check(fired and tc.zones.size() == 1, "the Singularität is cast")
	var whirl: Dictionary = tc.zones[0] if not tc.zones.is_empty() else {}
	var center: Vector2 = whirl.get("pos", Vector2.ZERO)
	check((whirl.get("mix", []) as Array).size() >= 3, "the whirl carries the Gefüge's elements for its clump look")
	# Act: on to the collapse
	_step(game, float(info.time), seen)
	# Assert: part of the clump stays on the core as one mixed field and goes on mixing there
	check(tc.zones.is_empty(), "the whirl has collapsed")
	check(int(tc.gefuege_units(rt)) == 0, "the collapse empties the Gefüge")
	check(stay > 0.0 and stay < 1.0, "part of the mixture stays, part flies (stay %.2f)" % stay)
	var stays: Array = _of(seen, "mix_land").filter(func(e: Dictionary) -> bool: return bool(e.get("stay", false)))
	var kept: Array = stays[0].els if stays.size() == 1 else []
	check(stays.size() == 1 and Vector2(float(stays[0].x), float(stays[0].y)).is_equal_approx(center) and _whole(kept),
		"one mixed field of every element lands on the core at once, fire last")
	check(is_equal_approx(_units(kept), 15.0 * stay), "the stay share of the units stays there (%.2f of 15)" % _units(kept))
	var churns := _of(seen, "churn")
	check(churns.size() == 1 and Vector2(float(churns[0].x), float(churns[0].y)).is_equal_approx(center) and _whole(churns[0].els) and float(churns[0].r) > meter,
		"its elements go on mixing in the explosion zone (one churn on the core, wider than a metre)")
	# Assert: the rest flies out as a few globs, all the same mixture, into every corner
	var spits := _of(seen, "spit")
	var globs: Array = spits[0].get("globs", []) if spits.size() == 1 else []
	check(spits.size() == 1 and globs.size() >= int(spit.get("min_count", 3)) and globs.size() <= int(spit.get("count", 6)),
		"one spit event with %s..%s globs (%d)" % [str(spit.get("min_count")), str(spit.get("count")), globs.size()])
	check(_of(seen, "eject").is_empty(), "nothing is scattered as single units any more")
	var same := not globs.is_empty()
	for glob: Dictionary in globs:
		same = same and _whole(glob.els) and is_equal_approx(float(glob.n), 15.0 * (1.0 - stay) / float(globs.size()))
	check(same, "every glob is the whole mixture: every element, an equal share, fire last")
	var flown := 0.0
	for glob: Dictionary in globs:
		flown += float(glob.n)
	check(is_equal_approx(flown + _units(kept), 15.0), "all 15 units go into the field and the globs (%.2f + %.2f)" % [_units(kept), flown])
	var far := globs.all(func(glob: Dictionary) -> bool:
		var d := _spot(glob).distance_to(center)
		return d <= float(span[1]) * meter + 1.0 and d > meter)
	check(not globs.is_empty() and far, "they fly up to %s m from the core (walls permitting)" % str(span[1]))
	# every corner: no gap between neighbouring directions wider than two even steps
	var angles: Array = globs.map(func(glob: Dictionary) -> float: return fposmod((_spot(glob) - center).angle(), TAU))
	angles.sort()
	var widest := 0.0
	for k in range(angles.size()):
		var next: float = angles[(k + 1) % angles.size()] + (TAU if k == angles.size() - 1 else 0.0)
		widest = maxf(widest, next - float(angles[k]))
	check(angles.size() >= 3 and widest < 2.0 * TAU / float(angles.size()), "they fly into every corner (widest gap %.0f°)" % rad_to_deg(widest))
	# Act: let them land
	var last := 0.5
	for glob: Dictionary in globs:
		last = maxf(last, float(glob.t))
	_step(game, last + 0.3, seen)
	# Assert: each glob lands as all its elements at once on its spot, fire last, one splash each
	var lands: Array = _of(seen, "land").filter(func(e: Dictionary) -> bool:
		return bool(e.get("eject", false)) and not Vector2(float(e.x), float(e.y)).is_equal_approx(center))
	lands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	check(lands.size() == globs.size() * 3, "every element of every glob lands (%d of %d)" % [lands.size(), globs.size() * 3])
	var together := not globs.is_empty()
	var fire_last := not globs.is_empty()
	for glob: Dictionary in globs:
		var here: Array = lands.filter(func(e: Dictionary) -> bool: return Vector2(float(e.x), float(e.y)).is_equal_approx(_spot(glob)))
		together = together and here.size() == 3
		fire_last = fire_last and not here.is_empty() and str(here[-1].el) == "fire"
	check(together and fire_last, "each glob's elements land together on its own spot, the fire last")
	check(_of(seen, "mix_land").size() == globs.size() + 1, "one splash where each glob lands, and the field on the core")
	game.queue_free()
	await process_frame
