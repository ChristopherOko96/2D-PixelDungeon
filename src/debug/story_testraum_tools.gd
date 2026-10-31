extends RefCounted
## The story Testraum's tools (src/debug/story_testraum.gd, its section
## WERKZEUGE and the force tools of ELEMENTE):
##   KI AUS: training dummies. A hell monster marked ai_off starts no act and
##     does not walk (the check in src/hell/hell_monsters.gd update); a theme
##     mob of the Frostgruft (it has no such check) is held where it stands.
##   Damage numbers over every monster that lost HP this frame (whatever hit
##     it: blade, shot, talent, burn, element), in the pixel font, coloured by
##     the element (the hero's own hit: his class, src/hell/hell_game.gd
##     on_hero_hit, which also flags crits, shown bigger; an element hit:
##     story_elements hurt_mob's last_el; else a status), and the DPS meter
##     (damage of the last window s, per second, and the total since RESET).
##   The parts overlay: the monster nearest the mouse, its hit zone (the body
##     circle blades and shots test) and, for a part rig (src/hell/drake_rig_host.gd),
##     every part's box coloured by its HP share with a list of part HP.
##   The element readout: what lies under the mouse (the floor tile, the
##     puddle zones with frozen / crust / charge, the pool layer's materials,
##     the gas and its density).
##   The force tools BLITZ, STURM, DRUCKWELLE, BEBEN, HEILIG: their aim,
##     timing and look here; their element work in src/hell/story_elements.gd.
## Two overlays draw it: WorldFx (a Node2D in the world: bolts, storms, rings,
## the holy light, stun marks, part boxes, the armed tool's ring at the mouse)
## and ScreenFx (a Control in the HUD under the panel: the numbers, the parts
## list, the readout, the armed tool's label).
## Values: assets/data/debug_story_testraum.json "tools" and elements.kraft.

const PixelBolt = preload("res://src/vfx/pixel_bolt.gd")
const ElementRules = preload("res://src/combat/element_rules.gd")
const HudStyle = preload("res://src/ui/hud_style.gd")
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")

## The Testraum node (story_testraum.gd) and its story game (hell_game.gd).
var host: Node
var g: Node
## debug_story_testraum.json "tools", elements.kraft and texts.
var cfg: Dictionary = {}
var force: Dictionary = {}
var texts: Dictionary = {}
## A probe can aim the overlays at a world point instead of the mouse (INF: the mouse).
var mouse_override := Vector2.INF
## Rising damage numbers ({at: world px, text, col, size, t, T, dx, crit}).
var numbers: Array = []
## The DPS meter: [[time, damage], ...] of the last window, and the total since its reset.
var hits: Array = []
var total := 0.0
## Lightning drawn for a moment ({a, b, t0, life, seed}).
var bolts: Array = []
## Running storms ({p, r, t0, T, next}).
var storms: Array = []
## Expanding rings of the shockwave and the quake, the holy light ({kind, p, r, t0, T, col}).
var rings: Array = []
var world_fx: Node2D
var screen_fx: Control
## Per tracked monster (its tr_id): {m, hp} as last seen.
var _seen: Dictionary = {}
var _serial := 0
var _seed := 0


func _init(host_node: Node, game: Node, conf: Dictionary) -> void:
	host = host_node
	g = game
	cfg = conf.get("tools", {})
	force = (conf.get("elements", {}) as Dictionary).get("kraft", {})
	texts = conf.get("texts", {})


## Adds the two overlays (the screen one into `ui` before the panel, so the
## panel stays on top) and takes the game's hero-hit hook.
func mount(ui: CanvasLayer) -> void:
	var w := WorldFx.new()
	w.tools = self
	w.name = "TestraumWorldFx"
	w.z_index = 4000
	w.z_as_relative = false
	g.add_child(w)
	world_fx = w
	var s := ScreenFx.new()
	s.tools = self
	s.name = "TestraumScreenFx"
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(s)
	screen_fx = s
	if g.get("on_hero_hit") is Callable:
		g.set("on_hero_hit", on_hero_hit)


func now() -> float:
	return float(g.state.t)


## The world point the tools aim at: the mouse, or a probe's point.
func mouse_world() -> Vector2:
	return mouse_override if mouse_override.is_finite() else g.get_global_mouse_position()


## The same point in the HUD's screen px.
func mouse_screen(c: CanvasItem) -> Vector2:
	if mouse_override.is_finite():
		return g.get_viewport().get_canvas_transform() * mouse_override
	return c.get_local_mouse_position()


func _particles() -> RefCounted:
	return g.feel.feedback.particles if g.get("feel") != null else null


func _pscale() -> float:
	return float(g.feel.scale) if g.get("feel") != null else 1.0


func _numbers_cfg() -> Dictionary:
	return cfg.get("numbers", {})


## The body centre of `m` (blades and shots aim there): m.cy above its feet.
static func body(m: Dictionary) -> Vector2:
	return Vector2(m.p) - Vector2(0, float(m.get("cy", 30.0)))


## A damage value for the numbers and the meter: 1 decimal below 10, thousands as k.
static func fmt(v: float) -> String:
	if v >= 10000.0:
		return "%dk" % roundi(v / 1000.0)
	if v >= 1000.0:
		return ("%.1fk" % (v / 1000.0)).replace(".", ",")
	if v >= 10.0:
		return "%d" % roundi(v)
	return ("%.1f" % v).replace(".", ",")


# ---------- per frame ----------

## Once a frame after the game moved: dummies, damage tracking, storms, ageing.
func step(dt: float) -> void:
	_dummies()
	_track()
	_step_storms(dt)
	var t := now()
	for i in range(numbers.size() - 1, -1, -1):
		var n: Dictionary = numbers[i]
		n.t = float(n.t) + dt
		if float(n.t) >= float(n.T):
			numbers.remove_at(i)
	bolts = bolts.filter(func(b: Dictionary) -> bool: return t - float(b.t0) < float(b.life))
	rings = rings.filter(func(r: Dictionary) -> bool: return t - float(r.t0) < float(r.T))
	var window := float((cfg.get("dps", {}) as Dictionary).get("window", 5.0))
	while not hits.is_empty() and t - float(hits[0][0]) > window:
		hits.pop_front()
	if world_fx != null:
		world_fx.queue_redraw()


## KI AUS ALLE marks every monster; a marked theme mob is held where it stands
## (its shot, summon and dash timers held), a hell monster stands by its own check.
func _dummies() -> void:
	var every := str(host.opts().get("ai", "on")) == "all"
	for m: Dictionary in g.mobs:
		if every:
			m.ai_off = true
		if not bool(m.get("ai_off", false)) or m.has("cds"):
			continue
		if not m.has("tr_pin"):
			m.tr_pin = m.p
		m.p = m.tr_pin
		m.k = Vector2.ZERO
		m.shoot = maxf(float(m.get("shoot", 0.0)), 0.5)
		m.summon = maxf(float(m.get("summon", 0.0)), 0.5)
		m.dash = 0.0
		m.dash_t = maxf(float(m.get("dash_t", 0.0)), 0.5)


## The KI choice `mode` taken: "on" frees every dummy, "all" marks every monster now.
func set_ai(mode: String) -> void:
	for m: Dictionary in g.mobs:
		if mode == "on":
			m.erase("ai_off")
			m.erase("tr_pin")
		elif mode == "all":
			m.ai_off = true


## The monsters from index `from_index` on just spawned: dummies when the KI is off for new ones.
func mark_new(from_index: int) -> void:
	if str(host.opts().get("ai", "on")) == "on":
		return
	var list: Array = g.mobs
	for i in range(from_index, list.size()):
		var m: Dictionary = list[i]
		m.ai_off = true


## HP lost since the last frame, per monster (also the one that died and left the list this frame).
func _track() -> void:
	var live := {}
	for m: Dictionary in g.mobs:
		if not m.has("tr_id"):
			_serial += 1
			m.tr_id = _serial
		var id := int(m.tr_id)
		live[id] = true
		if not _seen.has(id):
			_seen[id] = {"m": m, "hp": float(m.hp)}
			continue
		_check(_seen[id])
	for id: Variant in _seen.keys():
		if not live.has(id):
			_check(_seen[id])
			_seen.erase(id)


func _check(rec: Dictionary) -> void:
	var m: Dictionary = rec.m
	var hp := float(m.hp)
	var lost := float(rec.hp) - hp
	rec.hp = hp
	if lost <= 0.001:
		return
	var crit := bool(m.get("tr_crit", false))
	var el := _element_of(m)
	m.erase("tr_crit")
	m.erase("tr_el")
	hits.append([now(), lost])
	total += lost
	if bool(host.opts().get("numbers", true)):
		_number(body(m) - Vector2(0, float(m.get("cy", 30.0)) + 6.0), fmt(lost) + ("!" if crit else ""), el, crit)


## The element a monster's HP loss of this frame came in (see the header).
func _element_of(m: Dictionary) -> String:
	if m.has("tr_el"):
		return str(m.tr_el)
	if float(m.get("last_el_t", -9.0)) >= now() - 0.1:
		return str(m.last_el)
	var N := _numbers_cfg()
	var by_status: Dictionary = N.get("status_el", {})
	var statuses: Dictionary = m.get("statuses", {})
	for key: Variant in statuses:
		if by_status.has(str(key)):
			return str(by_status[str(key)])
	if float(m.get("fire_t", 0.0)) > 0.0:
		return "fire"
	return str((N.get("class_el", {}) as Dictionary).get(str(g.class_id), "phys"))


## The game's hook (hell_game.gd _damage_mob): a hit of the hero's weapon, its crit.
func on_hero_hit(m: Dictionary, _dealt: float, crit: bool) -> void:
	if crit:
		m.tr_crit = true
	m.tr_el = str((_numbers_cfg().get("class_el", {}) as Dictionary).get(str(g.class_id), "phys"))


func _number(at: Vector2, text: String, el: String, crit: bool) -> void:
	var N := _numbers_cfg()
	var cols: Dictionary = N.get("colors", {})
	_seed += 1
	var jitter := float(N.get("jitter", 14.0))
	numbers.append({"at": at, "text": text, "col": Color(str(cols.get(el, cols.get("phys", "ffffff")))),
		"size": int(N.get("crit_size" if crit else "size", 16)), "t": 0.0,
		"T": float(N.get("life", 0.9)) * (1.25 if crit else 1.0), "dx": float((_seed * 37) % 100 - 50) / 50.0 * jitter, "crit": crit})
	while numbers.size() > int(N.get("max", 80)):
		numbers.pop_front()


## A number of its own (a heal over the hero) at world point `at`.
func number_at(at: Vector2, text: String, el: String) -> void:
	_number(at, text, el, false)


## The DPS meter's two lines for the panel header: per second over the
## window, then the window's sum and the total since RESET.
func dps_lines() -> Array:
	var window := float((cfg.get("dps", {}) as Dictionary).get("window", 5.0))
	var sum := 0.0
	for h: Array in hits:
		sum += float(h[1])
	return [str(texts.get("dps", "DPS %s")) % fmt(sum / maxf(0.01, window)), str(texts.get("dps_more", "%d s: %s · %s")) % [int(window), fmt(sum), fmt(total)]]


## The DPS meter in one line (logs).
func dps_line() -> String:
	return " · ".join(PackedStringArray(dps_lines()))


func reset_dps() -> void:
	hits.clear()
	total = 0.0
	numbers.clear()


# ---------- force tools ----------

## Force tool `what` (elements.kraft kinds' do) at world point `at`; returns a
## message for the Testraum's toasts ("" for none).
func force_at(what: String, at: Vector2) -> String:
	var el: Variant = g.get("story_elements")
	if el == null:
		return str(texts.get("not_here", ""))
	var spec: Dictionary = force.get(what, {})
	var r := float(spec.get("r", 120.0))
	match what:
		"blitz":
			if _blitz(el, at, spec) > 0:
				return str(texts.get("charged", ""))
		"sturm":
			storms.append({"p": at, "r": r, "t0": now(), "T": float(spec.get("time", 6.0)), "next": 0.0})
		"druckwelle":
			el.wave_at(at, r, spec)
			_ring("wave", at, r, float(spec.get("ring_time", 0.35)), str(spec.get("col", "c8d8e0")))
		"beben":
			el.quake_at(at, r, spec)
			_ring("quake", at, r, float(spec.get("ring_time", 0.5)), str(spec.get("col", "d8b48a")))
		"heilig":
			var res: Dictionary = el.holy_at(at, r, spec)
			_ring("holy", at, r, float(spec.get("ring_time", 0.8)), str(spec.get("col", "ffe08a")))
			if int(res.get("healed", 0)) > 0:
				number_at(Vector2(float(g.player.x), float(g.player.y) - 90.0), "+%d" % int(res.healed), "heal")
				return str(texts.get("healed", "+%d")) % int(res.healed)
	return ""


## BLITZ: a bolt from the hero's hand to the monster nearest the click (else
## to the floor there), jumping on to the next ones; each hit charges the
## puddles under it. Returns how many puddle charges it set.
func _blitz(el: Object, at: Vector2, spec: Dictionary) -> int:
	var charge: Dictionary = force.get("charge", {})
	var reach := float(spec.get("reach", 36.0))
	var share := float(spec.get("boss_share", 0.5))
	var from := Vector2(float(g.player.x), float(g.player.y) - 40.0)
	var target := _nearest_mob(at, float(spec.get("chain_reach", 160.0)), [])
	var charged := 0
	if target.is_empty():
		_bolt(from, at, spec)
		_sparks(at, 10)
		return el.lightning_at(at, reach, charge)
	var done: Array = []
	var strength := float(spec.get("hits", 1.2))
	while not target.is_empty() and done.size() <= int(spec.get("jumps", 4)):
		var to := body(target)
		_bolt(from, to, spec)
		el.hurt_mob(target, strength, "lightning", to, share)
		el.stun_mob(target, float(spec.get("stun", 0.25)), share)
		charged += int(el.lightning_at(Vector2(target.p), reach, charge))
		_sparks(to, 6)
		done.append(target)
		strength *= float(spec.get("falloff", 0.8))
		from = to
		target = _nearest_mob(Vector2(target.p), float(spec.get("chain_range", 190.0)), done)
	# the struck point itself (a puddle clicked next to the monsters)
	return charged + int(el.lightning_at(at, reach, charge))


## The living, hittable monster nearest `at` within `reach` (to its rim), not one of `skip`.
func _nearest_mob(at: Vector2, reach: float, skip: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for m: Dictionary in g.mobs:
		if float(m.hp) <= 0.0 or not bool(g._hittable(m)):
			continue
		var taken := false
		for s: Dictionary in skip:
			if is_same(s, m):
				taken = true
		if taken:
			continue
		var d := Vector2(m.p).distance_to(at) - float(m.get("r", 0.0))
		if d <= reach and d < best_d:
			best_d = d
			best = m
	return best


## STURM: every `every` s a strike at a random point of each running storm
## (now and then on a monster in it): monsters there hurt and stunned, puddles charged.
func _step_storms(dt: float) -> void:
	if storms.is_empty():
		return
	var spec: Dictionary = force.get("sturm", {})
	var el: Variant = g.get("story_elements")
	var t := now()
	for i in range(storms.size() - 1, -1, -1):
		var s: Dictionary = storms[i]
		if t - float(s.t0) >= float(s.T):
			storms.remove_at(i)
			continue
		s.next = float(s.next) - dt
		if float(s.next) > 0.0 or el == null:
			continue
		s.next = float(spec.get("every", 0.45))
		var p := Vector2(s.p) + Vector2.from_angle(randf() * TAU) * float(s.r) * sqrt(randf())
		if randf() < float(spec.get("seek", 0.4)):
			var m := _nearest_mob(p, float(s.r), [])
			if not m.is_empty() and Vector2(m.p).distance_to(s.p) <= float(s.r) + float(m.get("r", 0.0)):
				p = Vector2(m.p)
		_strike(el, p, spec)


func _strike(el: Object, p: Vector2, spec: Dictionary) -> void:
	var share := float(spec.get("boss_share", 0.5))
	var reach := float(spec.get("strike_r", 38.0))
	_bolt(p - Vector2(randf_range(-30.0, 30.0), float(spec.get("height", 260.0))), p, spec)
	for m: Dictionary in g.mobs:
		if float(m.hp) <= 0.0 or float(m.get("alt", 0.0)) > 20.0 or Vector2(m.p).distance_to(p) > reach + float(m.get("r", 0.0)):
			continue
		el.hurt_mob(m, float(spec.get("hits", 0.8)), "lightning", p, share)
		el.stun_mob(m, float(spec.get("stun", 0.2)), share)
	el.lightning_at(p, reach, force.get("charge", {}))
	_sparks(p, 8)
	if g.get("monsters") != null:
		g.monsters._impact(p, "small")


func _bolt(a: Vector2, b: Vector2, spec: Dictionary) -> void:
	_seed += 1
	bolts.append({"a": a, "b": b, "t0": now(), "life": float(spec.get("life", 0.22)), "seed": _seed})
	if g.get("monsters") != null:
		g.monsters._impact(b, "small")


func _sparks(at: Vector2, n: int) -> void:
	var P := _particles()
	if P != null:
		PixelBolt.sparks(P, at / _pscale(), n)


func _ring(kind: String, p: Vector2, r: float, life: float, col: String) -> void:
	rings.append({"kind": kind, "p": p, "r": r, "t0": now(), "T": life, "col": col})


# ---------- parts and readout ----------

## The living monster whose body centre lies nearest `point` within parts.pick_reach px of its rim.
func mob_under(point: Vector2) -> Dictionary:
	var reach := float((cfg.get("parts", {}) as Dictionary).get("pick_reach", 60.0))
	var best: Dictionary = {}
	var best_d := INF
	for m: Dictionary in g.mobs:
		if float(m.hp) <= 0.0:
			continue
		var d := body(m).distance_to(point) - float(m.get("r", 0.0))
		if d < reach and d < best_d:
			best_d = d
			best = m
	return best


## The drawn parts of a rigged `m` ({id, key: its BodyParts id, poly: world px},
## from the pose last drawn); empty without a part rig.
func parts_of(m: Dictionary) -> Array:
	var rig: Variant = g.get("drake_rig")
	var out: Array = []
	if rig == null or not rig.has_rig(m):
		return out
	var states: Dictionary = m.get("parts", {})
	for c: Dictionary in rig._candidates(m):
		var xf: Transform2D = Transform2D(c.inv).affine_inverse()
		var b: Rect2 = c.part.bounds
		var poly := PackedVector2Array([xf * b.position, xf * Vector2(b.end.x, b.position.y), xf * b.end, xf * Vector2(b.position.x, b.end.y)])
		var id := str(c.id)
		out.append({"id": id, "key": id if states.has(id) else str(rig._route(m, id)), "poly": poly})
	return out


func _part_col(m: Dictionary, key: String) -> Color:
	var P: Dictionary = cfg.get("parts", {})
	if key in Array(m.get("parts_lost", [])):
		return Color(str(P.get("lost", "6b6b6b")))
	var st: Dictionary = (m.get("parts", {}) as Dictionary).get(key, {})
	var share := float(st.get("hp", 0.0)) / maxf(0.01, float(st.get("max", 1.0)))
	if share >= 0.6:
		return Color(str(P.get("ok", "7ee07e")))
	return Color(str(P.get("hurt", "ffd166"))) if share >= 0.3 else Color(str(P.get("low", "ff5a5a")))


## The parts list of `m`: its name and HP, then each part's HP ("> " the one under the mouse).
func parts_lines(m: Dictionary) -> Array:
	var def: Dictionary = m.get("def", {})
	var name := str(def.get("name", m.get("id", m.get("kind", "?"))))
	var out: Array = ["%s · HP %s / %s" % [name, fmt(float(m.hp)), fmt(float(m.get("max", m.get("max_hp", m.hp))))]]
	out.append(str(texts.get("zone", "r %d")) % int(float(m.get("r", 0.0))))
	var states: Dictionary = m.get("parts", {})
	var rig: Variant = g.get("drake_rig")
	if rig == null or not rig.has_rig(m) or states.is_empty():
		out.append(str(texts.get("no_rig", "")))
		return out
	var under := ""
	var mouse := mouse_world()
	for part: Dictionary in parts_of(m):
		if Geometry2D.is_point_in_polygon(mouse, part.poly):
			under = str(part.key)
	var lost: Array = m.get("parts_lost", [])
	var most := int((cfg.get("parts", {}) as Dictionary).get("max_lines", 10))
	# the rig's own German part names ("Linkes Bein", "Schädel") where it has them
	var spec: Dictionary = rig.library.rig(rig.rig_of(m)) if rig.get("library") != null else {}
	var named: Dictionary = spec.get("by_id", {})
	for id: Variant in states:
		if out.size() >= most + 2:
			break
		var st: Dictionary = states[id]
		var tail := str(texts.get("part_lost", "-")) if id in lost else "%s / %s" % [fmt(float(st.get("hp", 0.0))), fmt(float(st.get("max", 0.0)))]
		var label := str((named.get(id, {}) as Dictionary).get("label", id))
		out.append("%s%s  %s" % ["> " if str(id) == under else "  ", label, tail])
	return out


## What lies at world point `at` (see the header), one line each; the first is the title.
func readout(at: Vector2) -> Array:
	var names: Dictionary = (cfg.get("readout", {}) as Dictionary).get("names", {})
	var out: Array = [str(texts.get("readout_title", ""))]
	var cell := float(g.C)
	var tile := int(g._cell(int(floor(at.x / cell)), int(floor(at.y / cell))))
	if tile == 2:
		var liquid: Dictionary = g.theme.get("liquid", {})
		out.append(str(texts.get("tile_hot" if bool(liquid.get("hurt", false)) else "tile_ice", "")))
	elif tile != 1:
		out.append(str(texts.get("wall", "")))
	var mons: Variant = g.get("monsters")
	if mons != null:
		for z: Dictionary in mons.zones:
			if str(z.kind) != "puddle" or float(z.t) >= float(z.T) or at.distance_to(z.p) > float(z.r):
				continue
			var line := "%s %s" % [str(texts.get("puddle", "")), _name(names, str(z.get("st", "lava")))]
			if bool(z.get("frozen", false)):
				line += " · " + str(texts.get("frozen", ""))
			if float(z.get("crust", 0.0)) > 0.0:
				line += " · %s %.1fs" % [str(texts.get("crust", "")), float(z.crust)]
			if float(z.get("charge", 0.0)) > 0.0:
				line += " · %s %.1fs" % [str(texts.get("charged_tag", "")), float(z.charge)]
			out.append(line + " · %ds" % int(ceil(float(z.T) - float(z.t))))
	var layer: Variant = g._pool_layer() if g.has_method("_pool_layer") else null
	if layer != null:
		var mats: Array = layer.materials_at(at)
		if not mats.is_empty():
			var shown := PackedStringArray()
			for mat: Variant in mats:
				shown.append(_name(names, str(mat)))
			out.append("%s %s" % [str(texts.get("layer", "")), ", ".join(shown)])
	var gas: Variant = g.get("gas")
	if gas != null:
		var cloud: Dictionary = gas.at(at)
		if str(cloud.get("mat", "")) != "" and float(cloud.get("d", 0.0)) > 0.01:
			var d := float(cloud.d)
			var works := (" · " + str(texts.get("dense", ""))) if d >= ElementRules.dense_from() else ""
			out.append("%s %s · %s %d %%%s" % [str(texts.get("gas", "")), _name(names, str(cloud.mat)), str(texts.get("density", "")), roundi(d * 100.0), works])
	if out.size() == 1:
		out.append(str(texts.get("nothing", "")))
	return out


static func _name(names: Dictionary, key: String) -> String:
	return str(names.get(key, key.capitalize()))


## The radius an armed tool shows at the mouse (world px).
func tool_radius(tool: Dictionary) -> float:
	var group := str(tool.get("group", ""))
	if group == "kraft":
		return float((force.get(str(tool.get("do", "")), {}) as Dictionary).get("r", 60.0))
	return float((host.cfg.elements.get(group, {}) as Dictionary).get("r", 60.0))


# ---------- drawing ----------

## WorldFx: in world px, over everything of the world.
func draw_world(c: Node2D) -> void:
	if host.hidden_now():
		return
	var t := now()
	var art := float(g.PIXEL_WORLD)
	for s: Dictionary in storms:
		var left := clampf(1.0 - (t - float(s.t0)) / maxf(0.01, float(s.T)), 0.0, 1.0)
		_pixel_ring(c, Vector2(s.p), float(s.r), Color(0.55, 0.62, 1.0, 0.55 * left), art, 0.8)
		_pixel_ring(c, Vector2(s.p), float(s.r) * 0.55, Color(0.4, 0.45, 0.9, 0.3 * left), art, 0.8)
	for b: Dictionary in bolts:
		PixelBolt.draw(c, Vector2(b.a), Vector2(b.b), t - float(b.t0), int(b.seed), art, PixelBolt.STORM, float(b.life), 2)
	for r: Dictionary in rings:
		var f := clampf((t - float(r.t0)) / maxf(0.01, float(r.T)), 0.0, 1.0)
		var col := Color(str(r.col))
		if str(r.kind) == "holy":
			_light(c, Vector2(r.p), float(r.r), f, col, art)
		else:
			_pixel_ring(c, Vector2(r.p), float(r.r) * (0.25 + 0.75 * f), Color(col, 1.0 - f), art, 0.8)
			_pixel_ring(c, Vector2(r.p), float(r.r) * (0.15 + 0.6 * f), Color(col, 0.5 * (1.0 - f)), art, 0.8)
	for m: Dictionary in g.mobs:
		if float(m.hp) <= 0.0:
			continue
		if float(m.get("stun", 0.0)) > 0.0:
			_stun_mark(c, m, t, art)
		var zap := t - float(m.get("zap_t", -9.0))
		if zap < 0.2:
			PixelBolt.draw(c, body(m) - Vector2(0, float(m.get("cy", 30.0))), Vector2(m.p), zap, int(m.get("tr_id", 0)) * 13 + int(t * 20.0), art, PixelBolt.STORM, 0.2, 1)
	if bool(host.opts().get("parts", false)):
		_draw_parts(c, art)
	_draw_armed(c, art)


func _draw_parts(c: Node2D, art: float) -> void:
	var m := mob_under(mouse_world())
	if m.is_empty():
		return
	var zone := Color(str((cfg.get("parts", {}) as Dictionary).get("zone", "6fe7ff")))
	# the hit zone: blades and shots test the body circle (m.r round the body centre); the feet at m.p
	_pixel_ring(c, body(m), float(m.get("r", 20.0)), zone, art, 1.0)
	c.draw_rect(Rect2((Vector2(m.p) / art).floor() * art - Vector2(art, 0), Vector2(art * 3.0, art)), zone)
	var mouse := mouse_world()
	for part: Dictionary in parts_of(m):
		var poly: PackedVector2Array = part.poly
		if poly[0].distance_to(poly[2]) < 2.0:
			continue
		var col := _part_col(m, str(part.key))
		var over := Geometry2D.is_point_in_polygon(mouse, poly)
		c.draw_colored_polygon(poly, Color(col, 0.3 if over else 0.12))
		var outline := poly.duplicate()
		outline.append(poly[0])
		c.draw_polyline(outline, Color(col, 1.0 if over else 0.8), 2.0 if over else 1.0)


func _draw_armed(c: Node2D, art: float) -> void:
	var tool: Dictionary = host.tool
	if tool.is_empty():
		return
	var at := mouse_world()
	if str(tool.get("group", "")) == "spawn":
		_pixel_ring(c, at, 26.0, Color("7ee07e") if bool(host._open(at)) else Color("ff5a5a"), art, 0.8)
		return
	_pixel_ring(c, at, tool_radius(tool), Color(1, 1, 1, 0.55), art, 0.8)


static func _pixel_ring(c: CanvasItem, p: Vector2, r: float, col: Color, art: float, squash: float) -> void:
	if r <= 0.0 or col.a <= 0.01:
		return
	var n := clampi(int(TAU * r / (art * 1.5)), 12, 256)
	for k in range(n):
		var a := TAU * float(k) / float(n)
		var q := ((p + Vector2(cos(a) * r, sin(a) * r * squash)) / art).floor() * art
		c.draw_rect(Rect2(q, Vector2(art, art)), col)


## HEILIG's light: a dithered pillar falling on the spot, thinning upwards, and a ring on the floor.
static func _light(c: CanvasItem, p: Vector2, r: float, f: float, col: Color, art: float) -> void:
	var fade := 1.0 - f
	var half := r * 0.35 * (1.0 - 0.5 * f)
	var high := r * 2.2
	var step := art * 2.0
	var row := 0
	var y := 0.0
	while y < high:
		var share := 1.0 - y / high
		var k := 0
		var x := -half
		while x < half:
			if share > 0.6 or (row + k) % 2 == 0:
				var q := ((p + Vector2(x, -y)) / art).floor() * art
				c.draw_rect(Rect2(q, Vector2(art, art)), Color(col, 0.55 * fade * share))
			x += step
			k += 1
		y += step
		row += 1
	_pixel_ring(c, p, r * (0.4 + 0.6 * f), Color(col, fade), art, 0.8)


## Three small stars circling over a stunned monster's head.
static func _stun_mark(c: CanvasItem, m: Dictionary, t: float, art: float) -> void:
	var head := body(m) - Vector2(0, float(m.get("cy", 30.0)) + 10.0)
	for k in range(3):
		var a := t * 5.0 + TAU * float(k) / 3.0
		var q := ((head + Vector2(cos(a) * 16.0, sin(a) * 5.0)) / art).floor() * art
		c.draw_rect(Rect2(q - Vector2(art, 0), Vector2(art * 3.0, art)), Color("fff27a"))
		c.draw_rect(Rect2(q - Vector2(0, art), Vector2(art, art * 3.0)), Color("fff27a"))


## ScreenFx: in the HUD's screen px.
func draw_screen(c: Control) -> void:
	if host.hidden_now():
		return
	var ct: Transform2D = g.get_viewport().get_canvas_transform()
	var N := _numbers_cfg()
	var rise := float(N.get("rise", 38.0))
	var pop := float(N.get("pop", 0.12))
	for n: Dictionary in numbers:
		var f := float(n.t) / maxf(0.01, float(n.T))
		var p: Vector2 = ct * Vector2(n.at) + Vector2(float(n.dx), -rise * (1.0 - pow(1.0 - f, 2.0)))
		var size := int(n.size)
		if bool(n.crit) and float(n.t) < pop:
			size = int(float(size) * 1.35)
		var a := 1.0 if f < 0.65 else clampf(1.0 - (f - 0.65) / 0.35, 0.0, 1.0)
		_outlined(c, p, str(n.text), size, Color(n.col, a), bool(n.crit))
	var mouse := mouse_screen(c)
	var R: Dictionary = cfg.get("readout", {})
	# boxes stay out from under the panel column: one that would reach it flips to the left
	var avoid := c.get_viewport_rect().size.x
	if host.panel != null and bool(host.panel.visible):
		avoid = (host.panel.call("chip_rect") as Rect2).position.x - float(R.get("panel_gap", 6.0))
	if bool(host.opts().get("parts", false)):
		var m := mob_under(mouse_world())
		if not m.is_empty():
			var side := Vector2(float(m.get("r", 20.0)) + 18.0, -float(m.get("cy", 30.0)))
			_box(c, ct * (body(m) + side), parts_lines(m), 0.92, avoid, (ct * (body(m) - Vector2(side.x, 0))).x)
	var off: Array = R.get("offset", [18, 16])
	if bool(host.opts().get("readout", false)):
		_box(c, mouse + Vector2(float(off[0]), float(off[1])), readout(mouse_world()), 0.92, avoid, mouse.x - float(off[0]))
	var tool: Dictionary = host.tool
	if not tool.is_empty():
		var label := str(tool.get("name", ""))
		if str(tool.get("group", "")) == "spawn" and not bool(tool.get("boss", false)):
			label += " ×%d" % int(host.opts().get("count", 1))
		_box(c, mouse + Vector2(float(off[0]), -52.0), [str(texts.get("armed", "%s")) % label, str(texts.get("disarm", ""))], 0.8, avoid, mouse.x - float(off[0]))


static func _outlined(c: CanvasItem, p: Vector2, text: String, size: int, col: Color, crit: bool) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(roundf(p.x - w / 2.0), roundf(p.y))
	c.draw_string_outline(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4 if crit else 3, Color(0.05, 0.03, 0.06, col.a))
	c.draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A small HUD box of `lines` at screen point `at` (kept on the screen); the
## first line in the accent. A box reaching past x `avoid` (the panel column)
## is right-aligned to x `flip` instead.
static func _box(c: Control, at: Vector2, lines: Array, alpha := 0.92, avoid := INF, flip := NAN) -> void:
	if lines.is_empty():
		return
	var fs := int(HudStyle.size("font_small"))
	var w := 0.0
	for l: Variant in lines:
		w = maxf(w, HudStyle.width(FONT, str(l), fs))
	var lh := float(fs) + 5.0
	var screen := c.get_viewport_rect().size
	var r := Rect2(at, Vector2(w + 12.0, lh * float(lines.size()) + 8.0))
	if r.end.x > avoid and not is_nan(flip):
		r.position.x = flip - r.size.x
	r.position.x = clampf(r.position.x, 4.0, maxf(4.0, screen.x - r.size.x - 4.0))
	r.position.y = clampf(r.position.y, 4.0, maxf(4.0, screen.y - r.size.y - 4.0))
	HudStyle.panel(c, r, alpha)
	var y := r.position.y + 4.0 + float(fs)
	for i in range(lines.size()):
		HudStyle.text(c, FONT, Vector2(r.position.x + 6.0, y), str(lines[i]), fs, HudStyle.color("accent") if i == 0 else HudStyle.color("text"))
		y += lh


## The world overlay (a child of the game, drawn over the world).
class WorldFx extends Node2D:
	var tools: RefCounted

	func _draw() -> void:
		tools.draw_world(self)


## The screen overlay (in the HUD layer, under the panel; it takes no input).
class ScreenFx extends Control:
	var tools: RefCounted

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		tools.draw_screen(self)
