extends SceneTree
## Ignaroth's host module (src/hell/drake_rig_host.gd) on the real rigs
## (assets/data/hell_rigs.json) and monster data (hell_monsters.json), with
## monster dicts built the way hell_monsters.gd spawn() builds them:
## - BOSS-01: exactly four forms on floors 3/6/9/10, forms 1-3 change into
##   the next one (complete, same uid), only form 4 dies; every rig action
##   is one of the form's attacks;
## - PART-05: part shares 8-20 %, together <= 60 %, every hit counts fully;
## - PART-01: every severed part disables its attack or lowers a value by
##   >= 30 % on a COPY (the shared attack dict stays unchanged), a part lost
##   in the windup cancels the attack (every approved link), a channelled
##   breath stops, lost crystals take beams out of a running beam, echoes 3 -> 1;
## - PART-02/03: the sever event (wound, material, its own sound first,
##   hitstop, flash; an echo's lighter feedback), debris and a glowing stump
##   in the view, 1 s stagger without attacks, the hold without the feel;
## - no regrowth inside Ignaroth's forms (also under a partial config), the
##   general regrow for others;
## - hits: rest pose and current pose (the tail whirl mirrors the figure),
##   tail tip -> tail_2, a closed throat -> body, unaimed hits -> body, the
##   sword's arc and a blast's radius reach the parts where they are drawn,
##   nothing below the floor while he sinks;
## - BOSS-04: out of reach at most 4.6 s per flight, then 2 s on the ground;
## - drawing: sink cut, tint/alpha, the death, a corpse, the glow record
##   handed to the glow hook (never into the monster dict), the muzzles.
## Deterministic; reads only res:// data, writes nothing.

const DrakeRigHost = preload("res://src/hell/drake_rig_host.gd")
const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const BodyParts = preload("res://src/combat/body_parts.gd")
const Rules = preload("res://src/hell/hell_monster_rules.gd")
const StoryGlow = preload("res://src/hero/story_glow.gd")
const MONSTERS := "res://assets/data/hell_monsters.json"
const BALANCE := "res://assets/data/hell_balance.json"
const FORMS: Array[String] = ["drache1", "drache2", "drache3", "drache4"]
const FLOORS := {"drache1": 3, "drache2": 6, "drache3": 9, "drache4": 10}
const BOSS_HP := 1200.0
const AT := Vector2(640, 560)
## The approved map (docs/HOELLE-RIGS.de.md): [part, attack, "off" or the weakened param].
const SEVER_MAP := {
	"drache1": [["jaw", "spucke", "off"], ["arm", "graben", "ring"], ["tail_2", "huschen", "speed"], ["tail_2", "satz", "radius"]],
	"drache2": [["jaw", "salve", "count"], ["tail_2", "schwanz", "off"], ["arm", "lavabruch", "ring"], ["arm", "lavabruch", "lava"]],
	"drache3": [["wing_far", "bombenflug", "duration"], ["wing_near", "bombenflug", "duration"], ["throat", "atem", "off"], ["horns", "faecher", "count"]],
	"drache4": [["crystal_1", "strahlen", "beams"], ["crystal_2", "strahlen", "beams"], ["crystal_3", "strahlen", "beams"],
		["wing_far", "leerenregen", "duration"], ["wing_near", "leerenregen", "duration"], ["throat", "atem", "off"], ["horns", "echos", "forms"]],
}

var checked := 0
var failures: Array[String] = []
var library: RefCounted
var defs: Dictionary = {}
var floors: Dictionary = {}
var monster_cfg: Dictionary = {}
var _canvas: Node2D
var _draw_fn: Callable


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("DRAKE_RIG_HOST_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MONSTERS))
	defs = data.defs
	floors = data.floors
	var balance: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE))
	monster_cfg = balance.monsters
	library = RigLibrary.new()
	library.load_data()
	_canvas = Node2D.new()
	root.add_child(_canvas)
	_canvas.draw.connect(_on_draw)
	var loaded := true
	for id: String in FORMS:
		if library.rig(id).is_empty() or not bool(library.rig(id).get("layered", false)): loaded = false
	check(loaded, "every form of Ignaroth has a layered rig in hell_rigs.json")
	if loaded:
		_test_boss_01_four_forms()
		_test_attach_uid_and_centre()
		_test_part_05_shares_and_full_hits()
		_test_part_01_every_sever_has_effect()
		_test_part_01_shared_attack_unchanged()
		_test_part_01_windup_cancel_and_channels()
		_test_part_01_windup_cut_cancels_every_link()
		_test_part_03_event_and_stagger()
		_test_part_03_echo_feedback_and_hold()
		_test_no_regrow_in_forms_and_general_regrow()
		_test_config_merges_key_by_key()
		_test_new_form_starts_complete()
		_test_echo_hp_split_again()
		_test_on_release_leaves_other_monsters_alone()
		_test_routing_rest_pose()
		_test_unaimed_hits_and_take_aim()
		_test_swing_and_blast_reach_the_drawn_parts()
		_test_boss_04_flight_and_ground()
		await _test_routing_current_pose()
		await _test_part_02_debris_and_wound()
		await _test_drawing_cut_tint_death_and_glow()
		await _test_glow_record_goes_to_the_hook()
		await _test_sunk_parts_cannot_be_hit()
		await _test_muzzles_follow_the_pose()
	print("DRAKE_RIG_HOST checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


# ------------------------------------------------------------------ fixtures

## A monster dict as hell_monsters.gd spawn() builds it (shared def.stats).
func _spawn(id: String, boss := true) -> Dictionary:
	var def: Dictionary = defs[id]
	var st: Dictionary = def.stats
	var hp := Rules.spawn_hp(st, boss, BOSS_HP, 1.0)
	var cds: Array = []
	for a: Dictionary in st.attacks: cds.append(Rules.first_cooldown(a, 0.5))
	return {"room": 0, "id": id, "def": def, "st": st, "boss": boss, "kind": "boss" if boss else "mob", "p": AT,
		"hp": hp, "max": hp, "sp": float(st.speed), "s": float(def.scale), "r": float(st.r), "cy": float(def.h) * float(def.scale) * 0.45,
		"seed": 1.0, "k": Vector2.ZERO, "hit": 0.0, "spawn": 0.0, "act": null, "anim": "idle", "at": 0.0, "face": 1.0, "alpha": 1.0,
		"hop_t": 0.0, "cds": cds, "alt": 0.0, "sink": 0.0, "burrowed": false, "intro": null, "trans": null, "dying": null, "circ": 1.0,
		"landed": false, "trail": 0.0}


## hell_monsters.gd _set_form.
func _set_form(m: Dictionary, id: String) -> void:
	var def: Dictionary = defs[id]
	m.id = id
	m.def = def
	m.st = def.stats
	m.s = float(def.scale)
	m.r = float(def.stats.r)
	m.cy = float(def.h) * float(def.scale) * 0.45


func _host(extra: Dictionary = {}, view := true) -> RefCounted:
	var cfg: Dictionary = monster_cfg.duplicate(true)
	if not extra.is_empty(): cfg.rigs = extra
	var host: RefCounted = DrakeRigHost.new(cfg, library, BodyParts.new(library), RigRenderer.new(library) if view else null, view)
	host.reset(7)
	return host


func _attached(host: RefCounted, id: String) -> Dictionary:
	var m := _spawn(id)
	host.attach(m)
	return m


func _attack(m: Dictionary, id: String) -> Dictionary:
	for a: Dictionary in m.st.attacks:
		if str(a.id) == id: return a
	return {}


## An act as hell_monsters.gd _start_act builds it, on the prepared copy.
func _act(a: Dictionary, t: float) -> Dictionary:
	return {"a": a, "kind": a.kind, "t": t, "dir": Vector2.RIGHT, "n": 0, "anim": "attack", "v": Vector2.ZERO}


## Severs `part` with one hit of its full share (the throat during its breath).
func _sever(host: RefCounted, m: Dictionary, part: String) -> Dictionary:
	var spec: Dictionary = library.rig(str(m.id)).by_id[part]
	if not str(spec.exposed).is_empty(): m.exposed_action = str(spec.exposed)
	var result: Dictionary = host.damage(m, float(m.parts[part].max) + 0.01, part)
	m.exposed_action = ""
	return result


func _clear_stagger(host: RefCounted, m: Dictionary) -> void:
	host.frame([m], [], float(host.cfg.stagger) + 0.01)


func _severable(id: String) -> Array[String]:
	var out: Array[String] = []
	for part: Dictionary in library.rig(id).parts:
		if float(part.hp) > 0.0 and not bool(part.unbreakable): out.append(str(part.id))
	return out


func _on_draw() -> void:
	if _draw_fn.is_valid(): _draw_fn.call()


func _draw(fn: Callable) -> void:
	_draw_fn = fn
	_canvas.queue_redraw()
	await process_frame
	await process_frame
	_draw_fn = Callable()


func _foot(m: Dictionary) -> Vector2:
	return Vector2(m.p) + Vector2(0, 4.0 - float(m.alt))


## The test's own rest pose: source px -> world px (facing m.face).
func _rest(m: Dictionary) -> Transform2D:
	var rig: Dictionary = library.rig(str(m.id))
	var S := float(rig.scale)
	var face := -1.0 if float(m.face) < 0.0 else 1.0
	var centre := _foot(m) - Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * S)
	return Transform2D(Vector2(face * S, 0), Vector2(0, S), centre - Vector2(face * S * float(rig.ground.x), S * float(rig.center.y)))


func _rest_xforms(m: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var xform := _rest(m)
	for part: Dictionary in library.rig(str(m.id)).parts:
		if not str(part.id) in m.parts_lost: out[str(part.id)] = xform
	return out


func _opaque(image: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and image.get_pixel(x, y).a >= 0.5


func _opaque_near(image: Image, local: Vector2, r: float) -> bool:
	var span := int(ceil(r))
	var base := Vector2i(floori(local.x), floori(local.y))
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var p := base + Vector2i(dx, dy)
			if _opaque(image, p.x, p.y) and local.distance_to(Vector2(p) + Vector2(0.5, 0.5)) <= r: return true
	return false


## A world point on an inner pixel of part `id` under `xforms` that no part
## drawn at the same or a higher z covers within 2 source px; INF if none.
func _front_probe(rig: Dictionary, xforms: Dictionary, id: String) -> Vector2:
	var part: Dictionary = rig.by_id[id]
	var image: Image = part.image
	var area: Rect2 = part.bounds
	var xform: Transform2D = xforms[id]
	for y in range(int(area.position.y), int(area.end.y)):
		for x in range(int(area.position.x), int(area.end.x)):
			if not (_opaque(image, x, y) and _opaque(image, x - 1, y) and _opaque(image, x + 1, y) and _opaque(image, x, y - 1) and _opaque(image, x, y + 1)): continue
			var w: Vector2 = xform * Vector2(x + 0.5, y + 0.5)
			var covered := false
			for other: Dictionary in rig.parts:
				var oid := str(other.id)
				if oid == id or not xforms.has(oid) or int(other.z) < int(part.z): continue
				if _opaque_near(other.image, Transform2D(xforms[oid]).affine_inverse() * w, 2.0):
					covered = true
					break
			if not covered: return w
	return Vector2.INF


func _shot(host: RefCounted, m: Dictionary, at: Vector2) -> String:
	return host.shot_part(m, at - Vector2(1, 0), at + Vector2(1, 0), 0.5)


# ------------------------------------------------------------------ BOSS-01

func _test_boss_01_four_forms() -> void:
	var lords: Array[String] = []
	for id: String in defs:
		if Rules.is_lord(defs[id]): lords.append(id)
	lords.sort()
	check(lords == FORMS, "exactly four forms of Ignaroth: %s" % str(lords))
	for i in range(FORMS.size()):
		var id: String = FORMS[i]
		check(int(defs[id].phase) == i + 1, "%s is phase %d" % [id, i + 1])
		check(str(floors[str(FLOORS[id])].boss) == id, "%s is the boss of floor %d" % [id, int(FLOORS[id])])
		var next := Rules.next_form(defs, id)
		if i < 3: check(next == FORMS[i + 1], "%s changes into %s at 0 HP and flees (no death)" % [id, FORMS[i + 1]])
		else: check(next == "", "the Obsidianform has no next form: it dies")
		var attack_ids: Array[String] = []
		for a: Dictionary in defs[id].stats.attacks: attack_ids.append(str(a.id))
		for entry: Array in SEVER_MAP[id]:
			check(str(entry[1]) in attack_ids, "%s keeps its attack %s" % [id, entry[1]])
		# every attack a rig part or group names is an attack of this form
		var rig: Dictionary = library.rig(id)
		var named: Array[String] = []
		for part: Dictionary in rig.parts:
			named.append_array(RigLibrary.disabled_actions(part.disables))
			for action: String in part.weakens: named.append(action)
		for group: Dictionary in rig.groups.values(): named.append_array(RigLibrary.disabled_actions(group.disables))
		var unknown := named.filter(func(action: String) -> bool: return not action in attack_ids)
		check(unknown.is_empty(), "%s: every action of its rig is one of its attacks (%s)" % [id, str(unknown)])
		var expected: Array[String] = []
		for entry: Array in SEVER_MAP[id]:
			if not str(entry[0]) in expected: expected.append(str(entry[0]))
		var severable := _severable(id)
		expected.sort()
		severable.sort()
		check(severable == expected, "%s: the severable parts are the approved ones (%s)" % [id, str(severable)])
	# hell_monsters.gd: dragon kinds cover the four forms' special acts
	for kind: String in ["burrow", "flight", "sweep", "echoes"]: check(kind in Rules.DRAGON_KINDS, "the dragon runtime plays %s" % kind)


func _test_attach_uid_and_centre() -> void:
	var host := _host()
	var a := _attached(host, "drache1")
	var b := _attached(host, "drache1")
	check(a.uid is int and b.uid is int and int(a.uid) != int(b.uid), "two Salamanders get two distinct int uids")
	check(host.has_rig(a) and str(a.rig) == "drache1" and str(a.id) == "drache1", "the rig is the form's id, the string id stays")
	var rig: Dictionary = library.rig("drache1")
	var centre := _foot(a) - Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * float(rig.scale))
	check(Vector2(a.pos).distance_to(centre) < 0.01, "m.pos is the body centre above the feet (%s)" % str(a.pos))
	a.alt = 200.0
	host.frame([a], [], 0.0)
	check(is_equal_approx(Vector2(a.pos).y, centre.y - 200.0), "a flying dragon's centre rises with his altitude")
	var plain := {"id": "glutimp", "hp": 10.0, "max": 10.0, "p": AT}
	check(not host.attach(plain) and not host.has_rig(plain), "a monster without a rig keeps its sprite")
	host.damage(plain, 3.0)
	check(is_equal_approx(float(plain.hp), 7.0), "without a rig damage just lowers m.hp")


# ------------------------------------------------------------------ PART-05

func _test_part_05_shares_and_full_hits() -> void:
	for id: String in FORMS:
		var host := _host()
		var m := _attached(host, id)
		var total := 0.0
		for part: String in m.parts: total += float(m.parts[part].max)
		check(is_equal_approx(total, float(m.max)) and is_equal_approx(float(m.hp), float(m.max)), "%s: the parts add up to the form's HP" % id)
		var severable := 0.0
		for part: String in _severable(id):
			var share := float(m.parts[part].max) / float(m.max)
			severable += share
			check(share >= 0.08 - 0.0001 and share <= 0.20 + 0.0001, "%s: %s holds 8-20 %% of the HP (%.1f %%)" % [id, part, share * 100.0])
		check(severable <= 0.60 + 0.0001, "%s: severable parts together <= 60 %% (%.1f %%)" % [id, severable * 100.0])
		# every hit counts fully: a severing hit, a body hit, a tail-tip hit, a closed throat, no part at all
		var hits: Array = [[_severable(id)[0], 0.0], ["body", 7.0], ["tail_4", 5.0], ["", 3.0]]
		if m.parts.has("throat"): hits.append(["throat", 4.0])
		var dealt := 0.0
		for hit: Array in hits:
			var amount: float = float(hit[1]) if float(hit[1]) > 0.0 else float(m.parts[str(hit[0])].max) + 0.01
			var before := float(m.hp)
			host.damage(m, amount, str(hit[0]))
			dealt += amount
			check(is_equal_approx(before - float(m.hp), amount), "%s: a hit on '%s' takes all %.1f off the HP bar" % [id, hit[0], amount])
		check(is_equal_approx(float(m.hp), float(m.max) - dealt), "%s: the HP bar lost exactly what was dealt" % id)


# ------------------------------------------------------------------ PART-01

func _test_part_01_every_sever_has_effect() -> void:
	for id: String in FORMS:
		for entry: Array in SEVER_MAP[id]:
			var host := _host()
			var m := _attached(host, id)
			var part := str(entry[0])
			var action := str(entry[1])
			var param := str(entry[2])
			var a := _attack(m, action)
			var intact: Dictionary = host.prepare(m, a)
			check(not intact.is_empty(), "%s: %s starts while %s is attached" % [id, action, part])
			var cut := _sever(host, m, part)
			check(bool(cut.destroyed) and part in m.parts_lost, "%s: %s is severed by its share" % [id, part])
			_clear_stagger(host, m)
			var copy: Dictionary = host.prepare(m, a)
			if param == "off":
				check(copy.is_empty() and not host.parts.can(m, action), "%s: without %s there is no %s" % [id, part, action])
				continue
			check(not copy.is_empty(), "%s: %s still starts without %s, weakened" % [id, action, part])
			if copy.is_empty(): continue
			var before: Variant = a[param]
			var after: Variant = copy[param]
			if before is bool:
				check(bool(before) and not bool(after), "%s: without %s %s loses its %s" % [id, part, action, param])
			else:
				check(float(after) <= float(before) * 0.7 + 0.0001, "%s: without %s %s.%s drops >= 30 %% (%s -> %s)" % [id, part, action, param, str(before), str(after)])
	# the counts of the approved table
	var host := _host()
	var counts := [["drache2", "jaw", "salve", "count", 1], ["drache3", "horns", "faecher", "count", 3], ["drache1", "arm", "graben", "ring", 5], ["drache2", "arm", "lavabruch", "ring", 8]]
	for entry: Array in counts:
		var m := _attached(host, str(entry[0]))
		_sever(host, m, str(entry[1]))
		_clear_stagger(host, m)
		var copy: Dictionary = host.prepare(m, _attack(m, str(entry[2])))
		check(int(copy.get(str(entry[3]), -1)) == int(entry[4]), "%s: %s %s is %d without %s (%s)" % [entry[0], entry[2], entry[3], entry[4], entry[1], str(copy.get(str(entry[3])))])
	# crystals: 3 -> 2 -> 1 beams, then the group takes the beams
	var obsidian := _attached(host, "drache4")
	var beams: Array[int] = []
	for crystal: String in ["crystal_1", "crystal_2", "crystal_3"]:
		_sever(host, obsidian, crystal)
		_clear_stagger(host, obsidian)
		var copy: Dictionary = host.prepare(obsidian, _attack(obsidian, "strahlen"))
		beams.append(int(copy.get("beams", 0)) if not copy.is_empty() else 0)
	check(beams == [2, 1, 0], "every crystal takes one void beam: 3 -> %s" % str(beams))
	# wings: one halves the flight, both ground him
	for id: String in ["drache3", "drache4"]:
		var m := _attached(host, id)
		var flight := _attack(m, "bombenflug" if id == "drache3" else "leerenregen")
		_sever(host, m, "wing_far")
		_clear_stagger(host, m)
		var one: Dictionary = host.prepare(m, flight)
		check(not one.is_empty() and is_equal_approx(float(one.duration), minf(float(flight.duration) * 0.5, host.max_flight())), "%s: one wing lost halves the flight (%.2f s)" % [id, float(one.get("duration", -1.0))])
		_sever(host, m, "wing_near")
		_clear_stagger(host, m)
		check(host.prepare(m, flight).is_empty(), "%s: both wings lost: no flight" % id)
	# echoes: 3 -> 1 earlier form
	var lord := _attached(host, "drache4")
	var echos := _attack(lord, "echos")
	var earlier: Array = ["drache1", "drache2", "drache3"]
	check(host.echo_forms(lord, host.prepare(lord, echos), earlier) == earlier, "intact horns: all three echoes")
	_sever(host, lord, "horns")
	_clear_stagger(host, lord)
	var prepared: Dictionary = host.prepare(lord, echos)
	check(int(prepared.get("forms", 0)) == 1 and host.echo_forms(lord, prepared, earlier) == ["drache1"], "without horns only one echo (round(3 x 0.34) = 1): %s" % str(host.echo_forms(lord, prepared, earlier)))
	check(host.echo_forms(lord, echos, earlier).size() == 1, "the unprepared attack gives the same count")


func _test_part_01_shared_attack_unchanged() -> void:
	var host := _host()
	var m := _attached(host, "drache2")
	var other := _attached(host, "drache2")
	var shared: Dictionary = m.st.attacks[0]
	var before := JSON.stringify(shared)
	check(str(shared.id) == "salve" and is_same(shared, defs.drache2.stats.attacks[0]) and is_same(m.st, other.st), "the attack dict is shared by reference with the def")
	_sever(host, m, "jaw")
	_clear_stagger(host, m)
	var copy: Dictionary = host.prepare(m, shared)
	check(int(copy.count) == 1 and not is_same(copy, shared), "the weakened volley is a copy with 1 shot")
	check(JSON.stringify(shared) == before and int(shared.count) == 3, "the shared attack dict is unchanged (%s)" % JSON.stringify(shared))
	var intact: Dictionary = host.prepare(other, other.st.attacks[0])
	check(int(intact.count) == 3, "another Jungdrache still fires three")
	# flight cap on a copy too
	var long_flight := {"id": "bombenflug", "kind": "flight", "duration": 6.0, "every": 11.0}
	var capped: Dictionary = host.prepare(_attached(host, "drache3"), long_flight)
	check(is_equal_approx(float(capped.duration), host.max_flight()) and host.max_flight() < 6.0 and is_equal_approx(float(long_flight.duration), 6.0), "a 6 s flight is capped at %.2f s on the copy only" % host.max_flight())


func _test_part_01_windup_cancel_and_channels() -> void:
	var host := _host()
	# spit in its windup, the jaw falls: the spit is dropped
	var m := _attached(host, "drache1")
	m.act = _act(host.prepare(m, _attack(m, "spucke")), 0.2)
	check(not host.cancels(m), "an intact Salamander keeps winding up his spit")
	host.take_events()
	_sever(host, m, "jaw")
	check(host.cancels(m), "the jaw severed in the windup cancels the spit")
	var events: Array = host.take_events().filter(func(e: Dictionary) -> bool: return str(e.name) == DrakeRigHost.EVENT_CANCEL)
	check(events.size() == 1 and str(events[0].action) == "spucke" and not bool(events[0].released), "the cancel is raised once for the spit in its windup")
	# a released bolt flies on
	var n := _attached(host, "drache1")
	n.act = _act(host.prepare(n, _attack(n, "spucke")), 0.4)
	host.on_release(n)
	_sever(host, n, "jaw")
	check(not host.cancels(n), "after its release the spit is out: nothing to cancel")
	# the breath: the throat opens on the release and its loss stops the sweep
	var glut := _attached(host, "drache3")
	glut.act = _act(host.prepare(glut, _attack(glut, "atem")), 0.5)
	check(str(glut.exposed_action) == "", "the throat is closed in the breath's windup")
	host.on_release(glut)
	check(str(glut.exposed_action) == "atem", "the release opens the throat")
	var hit: Dictionary = host.damage(glut, float(glut.parts.throat.max) + 0.01, "throat")
	check(str(hit.part) == "throat" and bool(hit.destroyed), "during the breath the throat is hit and severed")
	check(host.cancels(glut), "a severed throat stops the running breath (channelled)")
	glut.act = null
	host.frame([glut], [], 0.016)
	check(str(glut.exposed_action) == "", "no act, no open throat")
	# beams: a crystal falls in the middle of the beams
	var obsidian := _attached(host, "drache4")
	var act := _act(host.prepare(obsidian, _attack(obsidian, "strahlen")), 1.0)
	act.beams = [0.0, 2.1, 4.2]
	obsidian.act = act
	host.on_release(obsidian)
	_sever(host, obsidian, "crystal_2")
	check(not host.cancels(obsidian) and (act.beams as Array).size() == 2, "a lost crystal takes one beam out of the running beams")
	# a flight is never stopped in the air; a rising one is put back down
	var high := _attached(host, "drache3")
	high.act = _act(host.prepare(high, _attack(high, "bombenflug")), 0.6)
	high.alt = 200.0
	_sever(host, high, "wing_far")
	_sever(host, high, "wing_near")
	check(not host.cancels(high) and is_equal_approx(float(high.alt), 200.0), "in the air (out of reach) the flight goes on")
	high.alt = 12.0
	check(host.cancels(high) and is_equal_approx(float(high.alt), 0.0), "still in reach, both wings lost: the take-off is dropped and he stands on the floor")


## PART-01 "a part severed in the windup cancels the attack", for EVERY
## approved part -> attack link (disabling and weakening ones alike): the act
## runs on prepare()'s copy, the part falls halfway through the windup, the
## act stops; once the stagger is over the attack starts again weakened (or
## not at all). A part lost before the attack started does not cancel it.
func _test_part_01_windup_cut_cancels_every_link() -> void:
	for id: String in FORMS:
		for entry: Array in SEVER_MAP[id]:
			# Arrange: the attack winds up on the copy prepare() made
			var host := _host()
			var m := _attached(host, id)
			var part := str(entry[0])
			var action := str(entry[1])
			var a := _attack(m, action)
			var copy: Dictionary = host.prepare(m, a)
			var times: Dictionary = host.cfg.get("act_times", DrakeRigHost.ACT_TIMES)
			var windup := float(times.get(str(a.kind), [0.4])[0])
			m.act = _act(copy, windup * 0.5)
			check(not host.cancels(m), "%s: %s winds up while %s is attached" % [id, action, part])
			host.take_events()
			# Act: the part falls in the windup
			_sever(host, m, part)
			var cancelled: bool = host.cancels(m)
			# Assert
			check(cancelled, "%s: %s severed in the windup cancels %s" % [id, part, action])
			var events: Array = host.take_events().filter(func(e: Dictionary) -> bool: return str(e.name) == DrakeRigHost.EVENT_CANCEL)
			check(events.size() == 1 and str(events[0].action) == action and str(events[0].get("part", "")) == part and not bool(events[0].released),
				"%s: the cancel names %s and its part %s (%s)" % [id, action, part, str(events)])
	# a cut of another part in the windup breaks it off too (he reels)
	var host := _host()
	var jung := _attached(host, "drache2")
	jung.act = _act(host.prepare(jung, _attack(jung, "salve")), 0.15)
	_sever(host, jung, "arm")
	check(host.cancels(jung), "any part severed in the windup breaks the volley off (the stagger begins)")
	# a part lost BEFORE the attack started does not cancel it: it fires weakened
	var old := _attached(host, "drache2")
	_sever(host, old, "jaw")
	_clear_stagger(host, old)
	var weak: Dictionary = host.prepare(old, _attack(old, "salve"))
	old.act = _act(weak, 0.15)
	check(not host.cancels(old) and int(weak.count) == 1, "an attack started after the jaw fell winds up on, with one shot")
	# after its release a weakening cut no longer stops a bolt
	var out := _attached(host, "drache3")
	out.act = _act(host.prepare(out, _attack(out, "faecher")), 0.4)
	host.on_release(out)
	_sever(host, out, "horns")
	check(not host.cancels(out), "the fan already released flies on when the horns fall")


# ------------------------------------------------------------------ PART-03

func _test_part_03_event_and_stagger() -> void:
	for id: String in ["drache1", "drache4"]:
		var host := _host()
		var m := _attached(host, id)
		var part := "jaw" if id == "drache1" else "horns"
		var breaks := int(m.get("part_breaks", 0))
		_sever(host, m, part)
		var events: Array = host.take_events().filter(func(e: Dictionary) -> bool: return str(e.name) == DrakeRigHost.EVENT_SEVER)
		check(events.size() == 1, "%s: one sever event for the %s" % [id, part])
		if events.is_empty(): continue
		var e: Dictionary = events[0]
		var material := "ember" if id == "drache1" else "obsidian"
		check(str(e.part) == part and int(e.uid) == int(m.uid) and str(e.monster) == id and bool(e.boss), "%s: the event names the part, uid and boss" % id)
		check(str(e.material) == material and (e.wound as Array).size() == 3 and not (e.chips as Array).is_empty(), "%s: debris and wound in %s" % [id, material])
		# PART-03 own sound: the event names the material's own break first, then fallbacks that exist today
		var sfx_events: Dictionary = _sfx_events()
		check(str(e.sound) == "break_" + material and (e.sounds as Array)[0] == e.sound, "%s: the event names its own break sound first (%s)" % [id, e.sound])
		check((e.sounds as Array).any(func(s: Variant) -> bool: return sfx_events.has(str(s))), "%s: a break sound of the list exists in audio_sfx.json (%s)" % [id, str(e.sounds)])
		if sfx_events.has(str(e.sound)):
			check(true, "%s: the own break sound %s exists in audio_sfx.json" % [id, e.sound])
		else:
			print("PENDING PART-03 %s: own sound %s is not in audio_sfx.json yet (audio owner); the cut plays %s meanwhile" % [id, e.sound, str((e.sounds as Array).filter(func(s: Variant) -> bool: return sfx_events.has(str(s))))])
		# feedback.gd's generic break (break_<crypt material> from part_breaks) stays silent: the game plays e.sounds
		check(bool(e.own_sound) and int(m.get("part_breaks", 0)) == breaks and int(m.get("rig_breaks", 0)) == 1, "%s: the cut is counted in rig_breaks, not in feedback.gd's part_breaks" % id)
		check(float(e.hitstop) > 0.0 and float(e.flash) > 0.0 and float(e.shake) > 0.0, "%s: hitstop, flash and shake on the cut" % id)
		check(is_equal_approx(float(e.hitstop), float(host.cfg.hitstop)) and is_equal_approx(float(e.shake), float(host.cfg.shake)), "%s: the boss's cut takes the boss's hitstop and shake" % id)
		check((e.at as Vector2).is_finite() and (e.center as Vector2).is_finite(), "%s: the wound sits at a world point" % id)
		var expect: String = "spucke" if id == "drache1" else "echos"
		check(id == "drache4" or expect in (e.disabled as Array), "%s: the event lists the attack it takes (%s)" % [id, str(e.disabled)])
		if id == "drache4": check((e.weakened as Dictionary).has("echos"), "the Obsidianform's event lists the weakened echoes")
		check(is_equal_approx(float(e.stagger), 1.0) and host.staggered(m), "%s: he staggers 1 s" % id)
		var started := 0
		for a: Dictionary in m.st.attacks:
			if not host.prepare(m, a).is_empty(): started += 1
		check(started == 0, "%s: no attack starts while he staggers" % id)
		host.frame([m], [], 0.5)
		check(host.staggered(m), "%s: still staggering after 0.5 s" % id)
		host.frame([m], [], 0.51)
		check(not host.staggered(m), "%s: the stagger ends after 1 s" % id)
		var able := 0
		for a: Dictionary in m.st.attacks:
			if not host.prepare(m, a).is_empty(): able += 1
		check(able > 0, "%s: after the stagger he attacks again" % id)
	# with own_break_sound off feedback.gd's break plays as for crypt rigs
	var plain := _host({"own_break_sound": false})
	var salamander := _attached(plain, "drache1")
	_sever(plain, salamander, "jaw")
	check(int(salamander.get("part_breaks", 0)) == 1 and int(salamander.get("rig_breaks", 0)) == 0, "own_break_sound false: part_breaks counts the cut again")


func _sfx_events() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/audio_sfx.json"))
	return parsed.get("events", {}) if parsed is Dictionary else {}


## A cut on an echo (not the boss) takes cfg.minor's lighter feedback (no
## hitstop chain under multishot); the hold keeps the picture without the feel.
func _test_part_03_echo_feedback_and_hold() -> void:
	# Arrange
	var host := _host()
	var echo := _spawn("drache2", false)
	echo.hp = 120.0
	echo.max = 120.0
	host.attach(echo)
	# Act
	_sever(host, echo, "jaw")
	var events: Array = host.take_events().filter(func(e: Dictionary) -> bool: return str(e.name) == DrakeRigHost.EVENT_SEVER)
	# Assert
	var minor: Dictionary = host.cfg.minor
	check(events.size() == 1 and not bool(events[0].boss), "an echo's cut raises one event, not a boss's")
	if events.size() == 1:
		check(is_equal_approx(float(events[0].hitstop), float(minor.hitstop)) and float(events[0].hitstop) < float(host.cfg.hitstop), "an echo's cut holds the picture shorter (%.2f s)" % float(events[0].hitstop))
		check(is_equal_approx(float(events[0].shake), float(minor.shake)) and float(events[0].shake) < float(host.cfg.shake), "an echo's cut shakes less (%.1f px)" % float(events[0].shake))
		check(is_equal_approx(float(events[0].stagger), float(minor.stagger)) and host.staggered(echo), "an echo still reels")
	# the hold: hitstop without the feel
	check(not host.frozen(), "nothing holds the picture at first")
	host.hold(0.09)
	host.hold(0.05)
	check(host.frozen() and is_equal_approx(host.hitstop_left, 0.09), "hold keeps the longest hitstop")
	host.freeze(0.05)
	check(host.frozen(), "still held after 0.05 s")
	host.freeze(0.05)
	check(not host.frozen(), "released after 0.09 s")


# ------------------------------------------------------------------ regrow

func _test_no_regrow_in_forms_and_general_regrow() -> void:
	var host := _host()
	var m := _attached(host, "drache1")
	check(is_equal_approx(float(m.regrow_after), 0.0), "Ignaroth's forms never regrow")
	_sever(host, m, "arm")
	host.take_events()
	for i in range(30): host.frame([m], [], 1.0)
	check("arm" in m.parts_lost and host.take_events().is_empty(), "30 s later the claw is still gone")
	# another hell boss (a family that regrows): 12 s, the tail's tip with it
	var other := _host({"regrow": {"drake": 12.0}})
	var b := _attached(other, "drache1")
	check(is_equal_approx(float(b.regrow_after), 12.0), "a regrowing family takes the 12 s delay")
	_sever(other, b, "tail_2")
	check("tail_3" in b.parts_lost and "tail_5" in b.parts_lost, "the severed tail takes its tip along")
	other.take_events()
	other.frame([b], [], 11.9)
	check("tail_2" in b.parts_lost, "not before 12 s")
	other.frame([b], [], 0.2)
	check(not "tail_2" in b.parts_lost and not "tail_3" in b.parts_lost and not "tail_5" in b.parts_lost, "after 12 s the tail grows back with its tip")
	var regrown: Array = other.take_events().filter(func(e: Dictionary) -> bool: return str(e.name) == DrakeRigHost.EVENT_REGROW)
	check(regrown.size() >= 1 and str(regrown[0].part) == "tail_2", "the regrowth is raised as an event")
	check(is_equal_approx(float(b.parts.tail_2.hp), float(b.parts.tail_2.max) * 0.5), "it returns with half its HP")


## hell_balance.json monsters.rigs may give any key: nested tables merge key
## by key, so a partial regrow or break_sounds keeps the rest (no regrowth
## sneaks into Ignaroth's forms).
func _test_config_merges_key_by_key() -> void:
	# Arrange / Act
	var host := _host({"regrow": {"default": 10.0}, "break_sounds": {"ember": ["break_ash"]}, "stagger": 0.8})
	var m := _attached(host, "drache1")
	# Assert
	check(is_equal_approx(float(host.cfg.regrow.default), 10.0) and is_equal_approx(float(host.cfg.regrow.drake), 0.0), "a partial regrow keeps drake 0 (%s)" % str(host.cfg.regrow))
	check(is_equal_approx(float(m.regrow_after), 0.0), "Ignaroth still never regrows under a partial regrow table")
	check(host.cfg.break_sounds.ember == ["break_ash"] and host.cfg.break_sounds.has("obsidian"), "a partial break_sounds keeps the other material (%s)" % str(host.cfg.break_sounds))
	check(is_equal_approx(float(host.cfg.stagger), 0.8) and is_equal_approx(float(host.cfg.hitstop), float(DrakeRigHost.DEFAULTS.hitstop)), "plain keys replace, the rest stay the defaults")
	check(is_equal_approx(float(DrakeRigHost.DEFAULTS.regrow.default), 12.0), "the defaults themselves stay unchanged")


func _test_new_form_starts_complete() -> void:
	var host := _host()
	var m := _attached(host, "drache1")
	var uid: int = int(m.uid)
	for i in range(3):
		var form: String = FORMS[i]
		for part: String in _severable(form): _sever(host, m, part)
		m.hp = 1.0
		_set_form(m, Rules.next_form(defs, form))
		host.on_form_changed(m)
		var next: String = FORMS[i + 1]
		check(str(m.rig) == next and Array(m.parts_lost).is_empty(), "%s -> %s: the new form comes complete" % [form, next])
		check(int(m.uid) == uid and is_equal_approx(float(m.hp), 1.0), "%s: same uid, the HP is kept through the change" % next)
		check(not host.staggered(m) and str(m.exposed_action) == "", "%s: no stagger or open throat carries over" % next)
		var all_start := true
		for a: Dictionary in m.st.attacks:
			if host.prepare(m, a).is_empty(): all_start = false
		check(all_start, "%s: every attack is available again" % next)
	# frame() notices a form change by itself too
	var n := _attached(host, "drache2")
	_set_form(n, "drache3")
	host.frame([n], [], 0.0)
	check(str(n.rig) == "drache3", "frame() re-attaches a form changed without the hook")


func _test_echo_hp_split_again() -> void:
	var host := _host()
	var e := _attached(host, "drache2")
	e.hp = 120.0
	e.max = 120.0
	e.echo = 10.0
	host.frame([e], [], 0.0)
	var total := 0.0
	for part: String in e.parts: total += float(e.parts[part].max)
	check(is_equal_approx(total, 120.0) and is_equal_approx(float(e.hp), 120.0), "an echo's small HP is split over its parts again (%.1f)" % total)
	check(bool(_sever(host, e, "jaw").destroyed), "an echo's jaw breaks at its own share")
	# a re-split keeps what is going on: the lost jaw, the stagger, the ground lock, regrow timers
	var other := _host({"regrow": {"drake": 12.0}})
	var f := _attached(other, "drache2")
	_sever(other, f, "jaw")
	f.rig_ground = 1.5
	var timer := float(f.regrow.get("jaw", 0.0))
	f.max = 150.0
	f.hp = 150.0
	other.frame([f], [], 0.0)
	var split := 0.0
	for part: String in f.parts: split += float(f.parts[part].max)
	check(is_equal_approx(split, 150.0), "the new HP is split again (%.1f)" % split)
	check("jaw" in f.parts_lost and is_zero_approx(float(f.parts.jaw.hp)), "the lost jaw stays lost through the re-split")
	check(other.staggered(f) and is_equal_approx(float(f.rig_ground), 1.5), "the stagger and the ground lock carry over (%.2f, %.2f)" % [float(f.rig_stagger), float(f.rig_ground)])
	check(timer > 0.0 and is_equal_approx(float(f.regrow.get("jaw", 0.0)), timer), "the jaw's regrow timer carries over")


## on_release() only touches rigged monsters (hook A3 runs it for all).
func _test_on_release_leaves_other_monsters_alone() -> void:
	var host := _host()
	var imp := {"id": "glutimp", "hp": 5.0, "max": 5.0, "act": {"a": {"id": "x"}, "kind": "bolt", "t": 0.4}}
	host.on_release(imp)
	check(not imp.has("exposed_action") and not (imp.act as Dictionary).has("rig_out"), "a glutimp's dict gets no rig keys from the release")
	check(not host.cancels(imp) and host.prepare(imp, imp.act.a) == imp.act.a, "nor does it cancel or copy its attacks")


# ------------------------------------------------------------------ hits

func _test_routing_rest_pose() -> void:
	var host := _host({}, false)
	# the tail beyond tail_2 counts on tail_2
	var m := _attached(host, "drache1")
	var rig: Dictionary = library.rig("drache1")
	var tip := _front_probe(rig, _rest_xforms(m), "tail_4")
	check(tip.is_finite(), "the Salamander's tail_4 has a free pixel")
	if tip.is_finite():
		check(_shot(host, m, tip) == "tail_2", "a shot on tail_4 counts on the severable tail_2")
		check(host.melee_part(m, tip) == "tail_2", "a blade on tail_4 counts on tail_2")
	check(host.parts.carrier(m, "tail_5") == "tail_2" and host.parts.carrier(m, "body") == "body", "BodyParts.carrier: tail tip -> tail_2, the body stays")
	# the throat: hidden outside the breath (the hit goes to the body)
	var glut := _attached(host, "drache3")
	var throat := _front_probe(library.rig("drache3"), _rest_xforms(glut), "throat")
	check(throat.is_finite(), "the Glutdrache's throat has a free pixel")
	if throat.is_finite():
		check(_shot(host, glut, throat) == "body", "outside the breath a shot on the throat hits the body")
		glut.exposed_action = "atem"
		check(_shot(host, glut, throat) == "throat", "during the breath it hits the throat")
		glut.exposed_action = ""
	var routed: Dictionary = host.damage(glut, 5.0, "throat")
	check(str(routed.part) == "body" and not bool(routed.destroyed), "damage aimed at the closed throat lands on the body")
	# a miss is a miss, and a shot sets the next damage's part
	check(_shot(host, glut, AT + Vector2(3000, 0)) == "", "a shot far away misses")
	var jaw := _front_probe(rig, _rest_xforms(m), "jaw")
	if jaw.is_finite():
		check(host.shot_hits(m, jaw - Vector2(1, 0), jaw + Vector2(1, 0), 0.5), "shot_hits reports the hit")
		var hit: Dictionary = host.damage(m, 2.0)
		check(str(hit.part) == "jaw", "the shot's part takes the next damage (%s)" % str(hit.part))
	# melee: the blade meets the nearest part
	var arm := _front_probe(rig, _rest_xforms(m), "arm")
	if arm.is_finite():
		check(host.melee_part(m, arm + Vector2(2, 0)) == "arm", "a blade next to the claw hits the claw")


## Hits without an impact point (burn ticks, zones, skills) land on the body,
## not on a seeded random part; take_aim() hands an aim out once, so a hit
## _damage_mob refuses leaves nothing for the next damage.
func _test_unaimed_hits_and_take_aim() -> void:
	# Arrange
	var host := _host({}, false)
	var m := _attached(host, "drache1")
	# Act / Assert: unaimed
	var hits: Array[String] = []
	for i in range(12): hits.append(str(host.damage(m, 0.5).part))
	check(hits.all(func(p: String) -> bool: return p == "body"), "12 hits without an impact point all land on the body (%s)" % str(hits))
	check(Array(m.parts_lost).is_empty(), "no burn severs a part by chance")
	# Act / Assert: take_aim
	host.aim(m, "jaw")
	check(host.take_aim(m) == "jaw" and host.take_aim(m) == "", "take_aim hands the aimed part out once")
	host.aim(m, "jaw")
	host.take_aim(m)
	check(str(host.damage(m, 1.0).part) == "body", "an aim taken by a refused hit does not linger to the next damage")
	host.aim(m, "arm")
	check(str(host.damage(m, 1.0).part) == "arm", "an aimed hit still lands on its part")
	# the seeded pick stays one setting away
	var random := _host({"unaimed": "random"}, false)
	var r := _attached(random, "drache1")
	var picked: Dictionary = {}
	for i in range(40): picked[str(random.damage(r, 0.01).part)] = true
	check(picked.size() > 1, "unaimed random: BodyParts' seeded pick spreads the hits (%d parts)" % picked.size())


## The sword's arc and a blast's radius are tested against the drawn parts:
## the Obsidianform's far wing, drawn hundreds of px from the old m.r circle,
## is hit where it is (finding: the old gate only reached the torso).
func _test_swing_and_blast_reach_the_drawn_parts() -> void:
	# Arrange
	var host := _host({}, false)
	var lord := _attached(host, "drache4")
	var rig: Dictionary = library.rig("drache4")
	var wing := _front_probe(rig, _rest_xforms(lord), "wing_far")
	check(wing.is_finite(), "the Obsidianform's far wing has a free pixel")
	if not wing.is_finite(): return
	var old_centre := Vector2(lord.p) - Vector2(0, float(lord.cy))
	var reach := 120.0
	var body_centre: Vector2 = host.centre(lord)
	var out: Vector2 = (wing - body_centre).normalized()
	var from: Vector2 = wing + out * (reach * 0.6)
	print("SWING the far wing pixel lies %.0f px from the old centre (m.r %.0f)" % [wing.distance_to(old_centre), float(lord.r)])
	# Act
	var part: String = host.swing_part(lord, from, -out, reach, 0.6)
	var away: String = host.swing_part(lord, from, out, reach, 0.6)
	var short: String = host.swing_part(lord, from, -out, reach * 0.3, 0.6)
	# Assert
	check(part in ["wing_far", "wing_near"], "a blade swung at the wing tip meets a wing (%s)" % part)
	check(away == "" and short == "", "swung away or short of him the blade misses (%s / %s)" % [away, short])
	check(host.swing_hits(lord, from, -out, reach, 0.6) and str(host.damage(lord, 1.0).part) == part, "swing_hits aims the next damage at that part")
	check(host.blast_part(lord, wing, 30.0) == "wing_far", "a blast on the wing pixel hits the far wing")
	check(host.blast_part(lord, wing + out * 400.0, 60.0) == "", "a blast 400 px beyond the wing misses")
	check(host.blast_hits(lord, wing + out * 20.0, 60.0) and str(host.damage(lord, 1.0).part) != "", "a blast just outside the wing reaches it and aims the damage")
	# the Salamander's tail tip: a blast there counts on the severable tail_2
	var salamander := _attached(host, "drache1")
	var tip := _front_probe(library.rig("drache1"), _rest_xforms(salamander), "tail_4")
	if tip.is_finite(): check(host.blast_part(salamander, tip, 20.0) == "tail_2", "a blast on the tail tip counts on tail_2 (%s)" % host.blast_part(salamander, tip, 20.0))


func _test_routing_current_pose() -> void:
	var host := _host()
	var m := _attached(host, "drache2")
	host.frame([m], [], 0.0)
	# the tail whirl, halfway through its spin: the figure faces the other way
	var whirl: Dictionary = host.prepare(m, _attack(m, "schwanz"))
	var act := _act(whirl, 0.0)
	m.act = act
	act.t = 0.35
	host.on_release(m)
	act.t = 0.35 + 0.1
	var phase: Dictionary = host.act_phase(m)
	check(str(phase.attack) == "active" and absf(float(phase.attack_p) - 0.5) < 0.01, "the whirl is halfway active (%s)" % str(phase))
	await _draw(func() -> void: host.draw(_canvas, m, _foot(m)))
	var xforms: Dictionary = host.renderer.part_transforms(RigRenderer.key_of(m))
	check(xforms.has("head") and Transform2D(xforms.body).x.x < 0.0, "mid-whirl the drawn body is mirrored though he faces right")
	if not xforms.has("head"): return
	var rig: Dictionary = library.rig("drache2")
	var head := _front_probe(rig, xforms, "head")
	check(head.is_finite(), "the mirrored head has a free pixel")
	if not head.is_finite(): return
	check(_shot(host, m, head) == "head", "a shot at the head where it is drawn hits the head")
	var rest_head := _front_probe(rig, _rest_xforms(m), "head")
	check(rest_head.is_finite() and _shot(host, m, rest_head) != "head", "where the head would be at rest there is no head now")
	var arm := _front_probe(rig, xforms, "arm")
	if arm.is_finite(): check(host.melee_part(m, arm + Vector2(0, 3)) == "arm", "the blade finds the claw where it is drawn")
	# not drawn for two frames: the rest pose again
	host.frame([m], [], 0.0)
	host.frame([m], [], 0.0)
	check(_shot(host, m, rest_head) == "head", "a pose not drawn for two frames falls back to the rest pose: the head is where the rig has it")


# ------------------------------------------------------------------ PART-02

func _test_part_02_debris_and_wound() -> void:
	var host := _host()
	var m := _attached(host, "drache1")
	host.frame([m], [], 0.0)
	await _draw(func() -> void: host.draw(_canvas, m, _foot(m)))
	var key := RigRenderer.key_of(m)
	check(host.renderer.last_drawn(key).get("shown", {}).has("jaw"), "the jaw is drawn before the cut")
	_sever(host, m, "jaw")
	var events: Array = host.take_events().filter(func(e: Dictionary) -> bool: return str(e.name) == DrakeRigHost.EVENT_SEVER)
	host.frame([m], [], 0.016)
	var debris: Array = host.renderer.debris_of(key).filter(func(d: Dictionary) -> bool: return str(d.id) == "jaw")
	check(debris.size() == 1 and str(debris[0].material) == "ember", "the jaw falls as ember debris")
	await _draw(func() -> void: host.draw(_canvas, m, _foot(m)))
	var drawn: Dictionary = host.renderer.last_drawn(key)
	check(not drawn.get("shown", {}).has("jaw"), "the jaw is no longer drawn")
	var stumps: Array = drawn.get("stumps", [])
	var stump: Array = stumps.filter(func(s: Dictionary) -> bool: return str(s.id) == "jaw")
	check(stump.size() == 1, "a glowing wound stays at the jaw's joint")
	if stump.size() == 1 and events.size() == 1:
		var reach := float(library.rig("drache1").scale) * 8.0
		check((stump[0].at as Vector2).distance_to(events[0].at) < reach, "the event's wound point is the joint the view draws (%.1f px)" % (stump[0].at as Vector2).distance_to(events[0].at))


# ------------------------------------------------------------------ BOSS-04

## BOSS-04 "a flight lasts at most 4.6 s, then he lands and you have at least
## 2 s to hit him", read strictly by default (flight_basis "air"): all the
## time he is out of reach, rise and landing above immune_altitude included.
func _test_boss_04_flight_and_ground() -> void:
	var host := _host()
	var top := float(monster_cfg.flight_altitude)
	var immune := float(monster_cfg.immune_altitude)
	var rise := float(host.cfg.flight_rise)
	var land := float(host.cfg.flight_land)
	var limit := float(host.cfg.flight_max)
	var ground_min := float(host.cfg.ground_min)
	check(str(host.cfg.flight_basis) == "air" and is_equal_approx(limit, 4.6), "the default reading is the strict one: out of reach at most 4.6 s")
	for id: String in ["drache3", "drache4"]:
		var m := _attached(host, id)
		for a: Dictionary in m.st.attacks:
			if str(a.kind) != "flight": continue
			var copy: Dictionary = host.prepare(m, a)
			var air: float = DrakeRigHost.air_time(float(copy.duration), top, immune, rise, land)
			print("BOSS-04 %s %s: circling %.2f s (data %.2f s), out of reach %.2f s, airborne %.2f s" % [id, a.id, float(copy.duration), float(a.duration), air, rise + float(copy.duration) + land])
			check(air <= limit + 0.001, "%s: %s keeps him out of reach %.2f s (<= %.1f s, rise and landing included)" % [id, a.id, air, limit])
			check(float(a.duration) > float(copy.duration) or DrakeRigHost.air_time(float(a.duration), top, immune, rise, land) <= limit + 0.001, "%s: the cap is what keeps %s within the limit" % [id, a.id])
			# cooldown inspection: after landing the next flight is at least ground_min away
			var ground := float(a.every) - (rise + float(copy.duration) + land)
			check(ground >= ground_min, "%s: after %s he stays %.1f s on the ground before it can come again" % [id, a.id, ground])
	# the lock: a landing keeps him on the floor for ground_min
	var m := _attached(host, "drache4")
	var flight := _attack(m, "leerenregen")
	m.act = _act(host.prepare(m, flight), 0.3)
	host.frame([m], [], 0.016)
	m.act = null
	host.frame([m], [], 0.016)
	check(is_equal_approx(float(m.rig_ground), ground_min), "the landing starts %.1f s on the ground" % ground_min)
	check(host.prepare(m, flight).is_empty(), "no new flight right after the landing")
	check(not host.prepare(m, _attack(m, "sterne")).is_empty(), "attacks on the ground still start: he can be hit")
	host.frame([m], [], ground_min * 0.5)
	check(host.prepare(m, flight).is_empty(), "halfway through the lock he still stays down")
	host.frame([m], [], ground_min * 0.5 + 0.01)
	check(not host.prepare(m, flight).is_empty(), "after the lock he may fly again")
	# the other readings are one setting away
	var circle := _host({"flight_basis": "circle"})
	check(is_equal_approx(circle.max_flight(), limit), "flight_basis circle: the circling itself may last %.1f s" % limit)
	var total := _host({"flight_basis": "total"})
	check(is_equal_approx(total.max_flight() + rise + land, limit), "flight_basis total: take-off to touch-down lasts %.1f s" % limit)
	check(host.max_flight() < circle.max_flight() and host.max_flight() > total.max_flight(), "air lies between circle and total (%.2f s)" % host.max_flight())


# ------------------------------------------------------------------ drawing

func _parts_drawn(renderer: RefCounted) -> Array:
	return renderer.draw_log.filter(func(d: Dictionary) -> bool: return str(d.what) == "part")


func _test_drawing_cut_tint_death_and_glow() -> void:
	var host := _host()
	var marks: Array = []
	host.glow_mark = func(body: Dictionary, record: Dictionary) -> void: marks.append([body, record])
	var m := _attached(host, "drache1")
	host.frame([m], [], 0.0)
	host.renderer.record_draws = true
	host.renderer.draw_log.clear()
	await _draw(func() -> void: host.draw(_canvas, m, _foot(m)))
	var whole := _parts_drawn(host.renderer).size()
	check(whole > 0, "the Salamander's parts are drawn")
	check(host.renderer.draw_log.filter(func(d: Dictionary) -> bool: return str(d.what) == "shadow").is_empty(), "the rig's own shadow stays off (the lord draws his)")
	var mouth: Variant = _last_record(marks, m).get("points", {}).get("mouth")
	check(mouth is Vector2 and (mouth as Vector2).is_finite(), "the mouth point is where the pose put it")
	check(host.point(m, "mouth", Vector2.ZERO) == mouth, "point() hands the drawn mouth to the attacks")
	# sinking: half in the floor, then fully gone
	host.renderer.draw_log.clear()
	await _draw(func() -> void: host.draw(_canvas, m, _foot(m), 1.0, Color.WHITE, 0.5))
	var half := _parts_drawn(host.renderer).size()
	check(half > 0 and half <= whole, "half sunk he is still drawn above the floor (%d of %d parts)" % [half, whole])
	host.renderer.draw_log.clear()
	await _draw(func() -> void: host.draw(_canvas, m, _foot(m), 1.0, Color.WHITE, 1.0))
	check(_parts_drawn(host.renderer).is_empty(), "fully sunk nothing of him is drawn")
	check(not Vector2(_last_record(marks, m).get("points", {}).get("mouth", Vector2.ZERO)).is_finite(), "a sunk mouth has no glow")
	check(host.point(m, "mouth", Vector2(-1, -1)) == Vector2(-1, -1), "a sunk mouth sends attacks from the fallback")
	# an echo's violet tint and fade reach every part
	var echo_tint := Color(0.95, 0.6, 1.9, 0.55)
	host.renderer.draw_log.clear()
	await _draw(func() -> void: host.draw(_canvas, m, _foot(m), 1.0, echo_tint))
	var colors: Array = _parts_drawn(host.renderer).map(func(d: Dictionary) -> Color: return d.color)
	check(not colors.is_empty() and colors.all(func(c: Color) -> bool: return is_equal_approx(c.b, 1.9) and c.a <= 0.55 + 0.001), "the echo tint and its fade reach every part")
	host.renderer.record_draws = false
	# the Obsidianform's death sheds wings, horns and crystals
	var lord := _attached(host, "drache4")
	host.frame([lord], [], 0.0)
	await _draw(func() -> void: host.draw(_canvas, lord, _foot(lord)))
	lord.dying = {"t": 1.0, "glow": 0.3}
	host.frame([lord], [], 0.016)
	await _draw(func() -> void: host.draw(_canvas, lord, _foot(lord)))
	var key := RigRenderer.key_of(lord)
	check(host.renderer.last_drawn(key).get("shown", {}).has("wing_far"), "before the end of his reeling he keeps his wings")
	lord.dying.t = float(host.cfg.death_start) + 0.1
	host.frame([lord], [], 0.016)
	await _draw(func() -> void: host.draw(_canvas, lord, _foot(lord)))
	var shown: Dictionary = host.renderer.last_drawn(key).get("shown", {})
	check(not shown.has("wing_far") and not shown.has("horns") and not shown.has("crystal_1") and shown.has("body"), "his death sheds wings, horns and crystals, the body stays")
	# the corpse keeps falling apart and fades
	var corpse := {"id": "drache4", "p": lord.p, "s": lord.s, "face": lord.face, "t": 0.5, "uid": lord.uid}
	host.frame([], [corpse], 0.016)
	host.renderer.record_draws = true
	host.renderer.draw_log.clear()
	var drew := [false]
	await _draw(func() -> void: drew[0] = host.draw_corpse(_canvas, corpse))
	var faded: Array = _parts_drawn(host.renderer)
	check(drew[0] and not faded.is_empty() and faded.all(func(d: Dictionary) -> bool: return (d.color as Color).a < 0.5), "the corpse is drawn by the rig, fading")
	var corpse_record := _last_record(marks, corpse)
	check(not corpse_record.is_empty() and not corpse.has("drawn") and not host.renderer.last_drawn(key).get("shown", {}).has("wing_far"), "the corpse's glow goes to the hook and it keeps its shed parts off")
	check(Vector2(corpse_record.get("src", Vector2.ZERO)) == Vector2(float(defs.drache4.w), float(defs.drache4.h)), "the corpse's glow box is its form's atlas frame (from the live draw)")
	host.renderer.record_draws = false


## The glow record of the last draw of `body` the hook received, {} if none.
func _last_record(marks: Array, body: Dictionary) -> Dictionary:
	for i in range(marks.size() - 1, -1, -1):
		if is_same(marks[i][0], body): return marks[i][1]
	return {}


## Finding: story_glow.gd keeps the glow records itself (mark(body, record));
## the host hands them to glow_mark and writes no `drawn` into the monster
## dict. The box is the form's atlas frame (vfx_glow.json anchors are authored
## in it), its bottom centre on the drawn feet; the rig points ride along.
func _test_glow_record_goes_to_the_hook() -> void:
	var glow_table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/vfx_glow.json")).story.hell_monsters
	for id: String in FORMS:
		# Arrange
		var host := _host()
		var marks: Array = []
		host.glow_mark = func(body: Dictionary, record: Dictionary) -> void: marks.append([body, record])
		var m := _attached(host, id)
		host.frame([m], [], 0.0)
		# Act
		await _draw(func() -> void: host.draw(_canvas, m, _foot(m)))
		# Assert
		check(marks.size() == 1 and is_same(marks[0][0], m), "%s: the glow hook gets the body it drew, once" % id)
		if marks.is_empty(): continue
		var record: Dictionary = marks[0][1]
		check(not m.has("drawn"), "%s: no glow record lands in the monster dict" % id)
		var keys := ["foot", "size", "src", "face", "lean", "cut", "alpha", "rig", "points"]
		check(keys.all(func(k: String) -> bool: return record.has(k)), "%s: the record has hell_monsters.gd _mark()'s keys plus rig and points" % id)
		var S := float(library.rig(id).scale)
		var atlas := Vector2(float(defs[id].w), float(defs[id].h))
		check(record.src == atlas and Vector2(record.size).is_equal_approx(atlas * S) and record.foot == _foot(m).round(), "%s: the glow box is the atlas frame %s at the drawn size, on the drawn feet" % [id, str(atlas)])
		var bottom: Vector2 = StoryGlow.anchor(record, [atlas.x * 0.5 - 0.5, atlas.y - 0.5])
		check(bottom.distance_to(_foot(m)) <= S, "%s: the atlas's bottom centre lands on the drawn feet" % id)
		var points: Dictionary = record.points
		check(["mouth", "throat", "hand", "tail_tip", "core"].all(func(p: String) -> bool: return points.get(p) is Vector2 and (points[p] as Vector2).is_finite()), "%s: every rig point is where the pose put it" % id)
		# observation for the glow owner: the atlas anchors against the posed rig points
		for entry: Dictionary in glow_table.get(id, []):
			var near := "tail_tip" if entry.has("flicker") else "mouth" if entry.has("act") else ""
			if near.is_empty(): continue
			var at: Vector2 = StoryGlow.anchor(record, entry.at)
			print("GLOW %s %s anchor %s lies %.0f world px from the rig's %s" % [id, str(entry.at), str(at.round()), at.distance_to(points[near]), near])


## Finding: parts of a half-sunk dragon below the floor were invisible but
## could be hit. Now nothing below the floor line is hit while he sinks.
func _test_sunk_parts_cannot_be_hit() -> void:
	# Arrange
	var host := _host()
	var m := _attached(host, "drache2")
	host.frame([m], [], 0.0)
	var rig: Dictionary = library.rig("drache2")
	var S := float(rig.scale)
	var half_width := float(Vector2(rig.size).x) * S
	# Act: half in the floor
	await _draw(func() -> void: host.draw(_canvas, m, _foot(m), 1.0, Color.WHITE, 0.5))
	# Assert
	var floor_y := _foot(m).y
	var below := 0
	var above := 0
	for x in range(int(AT.x - half_width), int(AT.x + half_width), 6):
		if host.shot_part(m, Vector2(x, floor_y + 2.0), Vector2(x, floor_y + 160.0), 0.5) != "": below += 1
		if host.shot_part(m, Vector2(x, floor_y - 2.0), Vector2(x, floor_y - 160.0), 0.5) != "": above += 1
	check(below == 0, "half sunk, no shot below the floor line hits him (%d did)" % below)
	check(above > 0, "half sunk, shots above the floor still hit him (%d)" % above)
	check(host.blast_part(m, Vector2(AT.x, floor_y + 60.0), 10.0) == "", "a blast below the floor reaches nothing there")
	var key := RigRenderer.key_of(m)
	var shown: Dictionary = host.renderer.last_drawn(key).get("shown", {})
	var xforms: Dictionary = host.renderer.part_transforms(key)
	var buried: Array = shown.keys().filter(func(id: Variant) -> bool: return not xforms.has(id))
	check(not buried.is_empty(), "the view leaves parts wholly below the floor out of the hittable pose (%s)" % str(buried))


## Finding: shots, rings and beams started at m.p - (0, m.cy). muzzle() gives
## the drawn mouth for bolts, breath and sweep, the core for rings and beams.
func _test_muzzles_follow_the_pose() -> void:
	# Arrange
	var host := _host()
	var lord := _attached(host, "drache4")
	host.frame([lord], [], 0.0)
	var fallback := Vector2(-5, -5)
	check(host.muzzle(lord, "bolt", fallback) == fallback, "before he is drawn the act starts from the caller's point")
	# Act
	await _draw(func() -> void: host.draw(_canvas, lord, _foot(lord)))
	# Assert
	var mouth: Vector2 = host.point(lord, "mouth", fallback)
	var core: Vector2 = host.point(lord, "core", fallback)
	check(mouth != fallback and core != fallback and mouth.distance_to(core) > 100.0, "mouth and core are drawn points far apart (%.0f px)" % mouth.distance_to(core))
	for kind: String in ["bolt", "breath", "homing", "sweep", "lob"]:
		check(host.muzzle(lord, kind, fallback) == mouth, "a %s leaves the drawn mouth" % kind)
	for kind: String in ["ring", "beam", "burrow", "spiral"]:
		check(host.muzzle(lord, kind, fallback) == core, "a %s leaves the drawn core" % kind)
	check(mouth.x > core.x, "facing right the mouth is right of the core")
