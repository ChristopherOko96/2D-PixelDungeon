extends RefCounted
## Armour with an ability in the story worlds (src/hell/hell_game.gd through
## src/hero/story_items.gd; user request 2026-11-01, "das absolut Wichtigste").
## The pieces are items.json gear with "class" (only that class may wear them)
## and "power" (an entry of assets/data/armor_powers.json). While one is worn
## its power sits on key F (skill bar slot F, src/ui/talent_bar.gd power_slot):
##   Schwertkämpfer  SCHILDWALL      front block, attackers thrown back
##                   BLUTRAUSCH      faster swings, life steal
##   Bogenschütze    SCHATTENSPRUNG  dash, nearby enemies lose the track
##                   PFEILHAGEL      arrows rain on the mouse point
##   Magier          FLAMMENKREIS    ring of fire, ignites oil / poison / gas
##                   EISPANZER       absorb shield, chills attackers, ice crust
##                   LEERENSCHRITT   blink, a void pull where he left
##   Nekromant       KNOCHENSCHILD   orbiting bones block shots, splinter
##                   SEELENSOG       drains life in soul streaks
## Effects follow the element physics (fire: story_elements fire_at and fire
## puddles; ice: frost_at, crust, shards; void: void_at and the pull; bone:
## splinters that fall and settle as pixel matter) and return to rest; nothing
## roots the hero or takes his input. Passive stats the item rules do not know
## (armor, range) are applied here. All values: armor_powers.json.
## Works without a world (g == null) for the unit test: the rules (class lock,
## cooldown, charges) run, the effects are skipped.

const ItemRules = preload("res://src/items/item_rules.gd")
const DATA_PATH := "res://assets/data/armor_powers.json"

static var _data: Dictionary = {}

## The story world (null in tests).
var g: Node
## The item node (src/hero/story_items.gd) for the cooldown factor (null in tests).
var items: Node
## The power of the worn armour ("" for none) and that armour's item.
var id := ""
var worn: Dictionary = {}
## Seconds until F works again, and the full cooldown last started.
var cd := 0.0
var cd_max := 0.0
## Seconds the running power still lasts (0: none runs).
var active := 0.0
## The running power's own state (direction, charges, bones, target ...).
var run: Dictionary = {}
## Short-lived drawings: {kind, p, t, max, ...} in world px.
var fx: Array = []
## Pixel matter: {p (ground point), h (height), v, vh, col, life, rest, rise}.
var bits: Array = []
var rng := RandomNumberGenerator.new()
var _ground: Node2D
var _top: Node2D
var _sound_gap := 0.0


## A world layer that hands its drawing back to this object.
class PowerLayer extends Node2D:
	var powers: RefCounted
	var top := false
	func _draw() -> void:
		if top: powers.draw_top(self)
		else: powers.draw_ground(self)


## `game`: the story world (null in tests); `owner`: the item node.
func _init(game: Node = null, owner: Node = null) -> void:
	g = game
	items = owner
	rng.seed = 7331
	if g == null: return
	_ground = PowerLayer.new()
	_ground.powers = self
	_ground.z_index = 9
	_top = PowerLayer.new()
	_top.powers = self
	_top.top = true
	_top.z_index = 40
	g.add_child.call_deferred(_ground)
	g.add_child.call_deferred(_top)


# --- the table and the item rules ---------------------------------------------------

## The power table (read once).
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {}
	return _data


## One power's row ({} when unknown).
static func power(power_id: String) -> Dictionary:
	return data().get("powers", {}).get(power_id, {})


## A text of the table with its fallback.
static func text(key: String, fallback := "") -> String:
	return str(data().get("texts", {}).get(key, fallback))


## The power of an item ("" for none: not gear, or gear without "power").
static func power_of(item: Dictionary) -> String:
	if str(item.get("type", "")) != "gear": return ""
	return str(ItemRules.gear(str(item.get("id", ""))).get("power", ""))


## The class an item is bound to ("" for every class).
static func class_of(item: Dictionary) -> String:
	match str(item.get("type", "")):
		"weapon": return str(ItemRules.weapon(str(item.get("id", ""))).get("class", ""))
		"gear": return str(ItemRules.gear(str(item.get("id", ""))).get("class", ""))
	return ""


## True when a hero of `class_id` may wear `item`.
static func may_wear(item: Dictionary, class_id: String) -> bool:
	var bound := class_of(item)
	return bound.is_empty() or bound == class_id


## The note an equip attempt gets when the piece is bound to another class
## ("Nur für Magier."), "" when it may be worn. `names`: class id -> name.
static func equip_block(item: Dictionary, class_id: String, names: Dictionary) -> String:
	if str(item.get("type", "")) != "gear" or may_wear(item, class_id): return ""
	return text("class_wrong", "Nur für %s.") % _class_name(class_of(item), names)


## Every power armour id (of one class when `class_id` is set), items.json order.
static func armor_ids(class_id := "") -> Array:
	var out: Array = []
	for entry: Dictionary in ItemRules.data().get("gear", []):
		if str(entry.get("power", "")).is_empty(): continue
		if class_id.is_empty() or str(entry.get("class", "")) == class_id: out.append(str(entry.id))
	return out


## The worn armour's power ("" for none) from a hero's inventory.
static func worn_power(inventory: Dictionary) -> String:
	return power_of(inventory.get("armor", {}))


## A power armour id for a find: of the hero's class with the share
## drops.own_class, else of any class ("" when there are none).
static func pick_armor(class_id: String, roll: RandomNumberGenerator, rarity := "") -> String:
	var own := armor_ids(class_id)
	var all := armor_ids()
	# a find on the side gives only armours of `rarity` (Beuteordnung: epic; legendary ones only from its map)
	if not rarity.is_empty():
		own = own.filter(func(id: String) -> bool: return str(ItemRules.gear(id).get("rarity", "")) == rarity)
		all = all.filter(func(id: String) -> bool: return str(ItemRules.gear(id).get("rarity", "")) == rarity)
	if all.is_empty(): return ""
	var pool := own if not own.is_empty() and roll.randf() < float(data().get("drops", {}).get("own_class", 0.8)) else all
	return str(pool[roll.randi_range(0, pool.size() - 1)])


static func _class_name(class_id: String, names: Dictionary) -> String:
	var name := str(names.get(class_id, class_id))
	return name.capitalize() if name == name.to_upper() else name


## The inventory window's lines for a power armour (class lock, passive
## stats the rules do not show, the F ability with its cooldown) and
## v.class; other items stay as they are. `stage_f`: the piece's stage factor.
static func describe(view: Dictionary, item: Dictionary, class_id: String, names: Dictionary) -> void:
	if view.is_empty() or str(item.get("type", "")) != "gear": return
	var spec := ItemRules.gear(str(item.get("id", "")))
	var bound := str(spec.get("class", ""))
	var lines: Array = view.get("lines", [])
	var extra: Array = []
	if not bound.is_empty():
		view["class"] = bound
		extra.append(text("class_only", "NUR FÜR %s") % str(names.get(bound, bound)).to_upper())
	var stats: Dictionary = spec.get("stats", {})
	var factor := ItemRules.stage_factor(item) if bool(item.get("identified", false)) else 1.0
	if stats.has("armor"): extra.append(text("armor", "RÜSTUNG %d %%") % roundi(float(stats.armor) * factor * 100.0))
	if stats.has("range"): extra.append(text("range", "REICHWEITE +%d %%") % roundi(float(stats.range) * factor * 100.0))
	if stats.has("mana"): extra.append(text("mana", "MANA +%d %%") % roundi(float(stats.mana) * factor * 100.0))
	var row := power(str(spec.get("power", "")))
	if not row.is_empty():
		extra.append(text("ability", "FÄHIGKEIT [F] %s: %s") % [str(row.get("name", "")), str(row.get("text", ""))])
		extra.append(text("cooldown", "Abklingzeit %s s") % _number(float(row.get("cooldown", 0.0))))
	var at := mini(1, lines.size())
	if not bound.is_empty():
		var lock: Variant = extra.pop_front()
		# another class sees the lock first; the own class does not need it
		if bound != class_id:
			lines.push_front(lock)
			at = mini(2, lines.size())
	# the ability right after the stats line, before stage and curse
	for line: String in extra:
		lines.insert(at, line)
		at += 1
	view.lines = lines


static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.1f" % value).replace(".", ",")


# --- wearing and pressing -----------------------------------------------------------

## After every change of the equipment: the worn armour's power takes key F.
## A new power starts ready; taking the armour off ends a running one.
func wear(item: Dictionary) -> void:
	var next := power_of(item)
	worn = item
	if next == id: return
	if active > 0.0: _end()
	id = next
	cd = 0.0
	cd_max = 0.0
	active = 0.0
	run = {}


## The worn armour's extra share of the mana pool (the Seelenmantel: 0.25 = +25 %).
func mana_bonus() -> float:
	if worn.is_empty() or str(worn.get("type", "")) != "gear": return 0.0
	var stats: Dictionary = ItemRules.gear(str(worn.get("id", ""))).get("stats", {})
	var factor := ItemRules.stage_factor(worn) if bool(worn.get("identified", false)) else 1.0
	return float(stats.get("mana", 0.0)) * factor


## The worn power's row ({} for none).
func row() -> Dictionary:
	return power(id)


## The cooldown of the worn power, scaled by the hero's cooldown factor.
func cooldown() -> float:
	var scale: float = float(items.cooldown_scale()) if items != null and items.has_method("cooldown_scale") else 1.0
	return float(row().get("cooldown", 10.0)) * maxf(0.2, scale)


## Key F: starts the worn power at `target` (world px, the mouse point).
## False when none is worn, it cools down or one still runs (a note says so).
func press(target: Vector2 = Vector2.INF) -> bool:
	var spec := row()
	if spec.is_empty(): return false
	if cd > 0.0 or active > 0.0:
		if g != null and g.has_method("_toast") and cd > 0.0:
			g._toast(text("not_ready", "%s: noch %s s") % [str(spec.get("name", "")), _number(snappedf(cd, 0.1))])
		return false
	cd_max = cooldown()
	cd = cd_max
	run = {}
	active = float(spec.get("time", 0.0))
	_start(spec, target)
	return true


## True while the worn power runs.
func running() -> bool:
	return active > 0.0


## Attack pause factor of a running power (Blutrausch < 1), else 1.
func rate_factor() -> float:
	if id == "blood_rush" and active > 0.0: return float(row().get("rate", 0.65))
	return 1.0


## Share of a hero shot's flight the worn armour adds (stats.range by stage).
func range_bonus() -> float:
	var stats: Dictionary = ItemRules.gear(str(worn.get("id", ""))).get("stats", {})
	return float(stats.get("range", 0.0)) * ItemRules.stage_factor(worn) if not worn.is_empty() else 0.0


## Chance to shrug off a hit (stats.armor by stage).
func armor_share() -> float:
	var stats: Dictionary = ItemRules.gear(str(worn.get("id", ""))).get("stats", {})
	return clampf(float(stats.get("armor", 0.0)) * ItemRules.stage_factor(worn), 0.0, 0.75) if not worn.is_empty() else 0.0


## A blow on the hero from `from` (world px; ZERO or INF: unknown): true when
## the running power stops it (Schildwall from the front, a Eispanzer charge)
## or the armour shrugs it off (stats.armor).
func absorb(from: Vector2 = Vector2.ZERO) -> bool:
	var spec := row()
	if active > 0.0 and id == "shield_wall":
		var src := _source(from, float(spec.get("reach", 170.0)))
		if src.is_finite() and _in_front(src, spec):
			_wall_block(src, spec)
			return true
	if active > 0.0 and id == "ice_armor" and int(run.get("charges", 0)) > 0:
		run.charges = int(run.charges) - 1
		_ice_hit(spec, int(run.charges) <= 0)
		return true
	var share := armor_share()
	if share > 0.0 and rng.randf() < share:
		if g != null:
			var me := _hero() - Vector2(0, 40)
			_spray(me, Color("e0cc90"), 6, 140.0, 30.0)
			fx.append({"kind": "flash", "p": me, "t": 0.18, "max": 0.18, "r": 26.0, "col": Color("e0cc90")})
			_play_raw("block")
		return true
	return false


## A hero hit on monster `m` (Blutrausch: every heal_every-th hit heals).
func on_hit(m: Dictionary) -> void:
	if id != "blood_rush" or active <= 0.0: return
	var spec := row()
	run.hits = int(run.get("hits", 0)) + 1
	if int(run.hits) % maxi(1, int(spec.get("heal_every", 4))) == 0 and int(run.get("healed", 0)) < int(spec.get("heal_max", 3)):
		if _heal(1):
			run.healed = int(run.get("healed", 0)) + 1
			fx.append({"kind": "streak", "a": (m.p as Vector2) - Vector2(0, float(m.get("cy", 30.0))), "t": 0.45, "max": 0.45, "col": Color("d23a3a"), "seed": rng.randf() * 10.0})
			_sfx(spec, "heal")


## The skill bar's F slot as data ({} when no power armour is worn): name,
## text, cd, max, icon motif, colour, running.
func slot_view() -> Dictionary:
	var spec := row()
	if spec.is_empty(): return {}
	return {"id": id, "name": str(spec.get("name", "")), "text": str(spec.get("text", "")), "cd": cd, "max": maxf(0.01, cd_max if cd_max > 0.0 else cooldown()),
		"cooldown": cooldown(), "icon": str(spec.get("icon", "shield")), "color": str(spec.get("color", "ffffff")), "running": active > 0.0,
		"armor": str(ItemRules.gear(str(worn.get("id", ""))).get("name", ""))}


# --- per frame ----------------------------------------------------------------------

## Cooldown, the running power, the passive range, the drawings and the pixel matter.
func update(dt: float) -> void:
	cd = maxf(0.0, cd - dt)
	_sound_gap = maxf(0.0, _sound_gap - dt)
	if active > 0.0:
		active -= dt
		if g != null: _step(row(), dt)
		if active <= 0.0:
			active = 0.0
			_end()
	if g == null: return
	_step_range()
	for f: Dictionary in fx:
		f.t = float(f.t) - dt
	fx = fx.filter(func(f: Dictionary) -> bool: return float(f.t) > 0.0)
	_step_bits(dt)
	if _ground != null: _ground.queue_redraw()
	if _top != null: _top.queue_redraw()


func _start(spec: Dictionary, target: Vector2) -> void:
	_sfx(spec, "cast")
	if g == null:
		match id:
			"ice_armor": run.charges = int(spec.get("charges", 3))
			"bone_shield": run.bones = _new_bones(spec)
		return
	var me := _hero()
	var col := Color(str(spec.get("color", "ffffff")))
	# the telegraph: a short ring on the hero in the power's colour
	fx.append({"kind": "ring", "p": me - Vector2(0, 30), "t": 0.3, "max": 0.3, "r": 70.0, "col": col})
	_shake(float(spec.get("shake", 2.0)))
	match id:
		"shield_wall":
			run.dir = _aim()
		"blood_rush":
			run.hits = 0
			_spray(me - Vector2(0, 40), col, 14, 160.0, 40.0)
		"shadow_leap":
			var dir := _aim()
			var vel: Variant = g.player.get("vel", Vector2.ZERO)
			if vel is Vector2 and (vel as Vector2).length() > 20.0: dir = (vel as Vector2).normalized()
			run.dir = dir
			run.left = float(spec.get("dash_time", 0.18))
			run.speed = float(spec.get("dash", 230.0)) / maxf(0.01, float(run.left))
			g.state.inv = maxf(float(g.state.get("inv", 0.0)), float(run.left) + float(spec.get("inv_extra", 0.15)))
			_smoke(me, 18)
			var lost := float(spec.get("lost", 2.0))
			active = lost
			for m: Dictionary in _mobs_near(me, float(spec.get("lost_radius", 460.0))):
				var t := lost * (float(spec.get("boss_share", 0.5)) if str(m.get("kind", "")) == "boss" else 1.0)
				m.stun = maxf(float(m.get("stun", 0.0)), t)
				m["_lost_t"] = t
		"arrow_hail":
			var at := target if target.is_finite() else me + _aim() * 200.0
			var reach := float(spec.get("range", 560.0))
			if at.distance_to(me) > reach: at = me + (at - me).normalized() * reach
			run.at = at
			run.warn = float(spec.get("telegraph", 0.45))
			run.spawned = 0
			run.clock = 0.0
			run.arrows = []
			active = float(spec.get("telegraph", 0.45)) + float(spec.get("rain", 1.0)) + 0.6
		"flame_ring":
			run.at = me
			run.tick = 0.0
			run.lit = 0.0
			_ignite_ring(spec)
		"ice_armor":
			run.charges = int(spec.get("charges", 3))
			var crust := float(spec.get("crust_radius", 150.0))
			if g.get("story_elements") != null: g.story_elements.frost_at(me, crust, 1)
			# real ice on the floor: a friendly ice puddle of the element physics (it slides, thaws
			# in fire, the void eats it); the drawn crust stays only where no puddle layer exists
			var zoned := false
			if g.get("monsters") != null:
				g.monsters._zone({"kind": "puddle", "p": me, "r": crust, "T": float(spec.get("crust_time", 6.0)), "dmg": 0, "friend": true, "st": "ice",
					"m": {"id": "eispanzer", "def": {"name": "Eispanzer"}, "boss": false}, "dir": Vector2.ZERO})
				zoned = true
			if not zoned:
				fx.append({"kind": "crust", "p": me, "t": float(spec.get("crust_time", 6.0)), "max": float(spec.get("crust_time", 6.0)), "r": crust, "seed": rng.randf() * 100.0})
			for m: Dictionary in _mobs_near(me, float(spec.get("chill_radius", 150.0))):
				g.HeroKit.slow_mob(g, m, float(spec.get("chill", 0.5)), float(spec.get("chill_time", 2.5)))
			_spray(me - Vector2(0, 30), col, 16, 150.0, 30.0)
		"void_step":
			var goal := target if target.is_finite() else me + _aim() * float(spec.get("range", 330.0))
			var reach := float(spec.get("range", 330.0))
			if goal.distance_to(me) > reach: goal = me + (goal - me).normalized() * reach
			var dest := _free_on_line(me, goal)
			fx.append({"kind": "ghost", "p": me, "t": 0.5, "max": 0.5, "col": col})
			g.player.x = dest.x
			g.player.y = dest.y
			g.state.inv = maxf(float(g.state.get("inv", 0.0)), float(spec.get("inv", 0.3)))
			fx.append({"kind": "ring", "p": dest - Vector2(0, 30), "t": 0.3, "max": 0.3, "r": 50.0, "col": col})
			_sfx(spec, "land")
			run.at = me
			active = float(spec.get("pull_time", 1.4))
			if g.get("story_elements") != null: g.story_elements.void_at(me, float(spec.get("eat_radius", 80.0)), 1)
		"bone_shield":
			run.bones = _new_bones(spec)
		"soul_drain":
			run.tick = 0.0
			run.drained = 0
			run.healed = 0


func _step(spec: Dictionary, dt: float) -> void:
	var me := _hero()
	match id:
		"shield_wall":
			var aim := _aim()
			run.dir = (run.dir as Vector2).slerp(aim, clampf(float(spec.get("turn", 10.0)) * dt, 0.0, 1.0)).normalized()
			# shots that meet the wall break on it
			var centre := me - Vector2(0, 30)
			for s: Dictionary in g.eshots:
				var rel: Vector2 = (s.p as Vector2) - centre
				if float(s.get("t", 0.0)) > 0.0 and rel.length() < float(spec.get("shot_reach", 80.0)) and _in_front(s.p, spec):
					s.t = 0.0
					_spray(s.p, Color(str(spec.color)), 5, 120.0, 0.0)
					_play_once(spec, "block")
		"blood_rush":
			if rng.randf() < dt * 14.0:
				bits.append({"p": me + Vector2(rng.randf_range(-18, 18), 2), "h": rng.randf_range(10, 60), "v": Vector2.ZERO, "vh": rng.randf_range(30, 70), "col": Color("d23a3a"), "life": 0.6, "rest": false, "rise": true})
		"shadow_leap":
			if float(run.get("left", 0.0)) > 0.0:
				var step := minf(float(run.left), dt)
				run.left = float(run.left) - dt
				var next := me + (run.dir as Vector2) * float(run.speed) * step
				if _open(next):
					g.player.x = next.x
					g.player.y = next.y
					if rng.randf() < 0.8: _smoke(next, 2)
				else: run.left = 0.0
				if float(run.left) <= 0.0:
					_sfx(spec, "land")
					_smoke(_hero(), 8)
		"arrow_hail":
			_step_hail(spec, dt)
		"flame_ring":
			run.tick = float(run.tick) - dt
			run.lit = float(run.lit) + dt
			if float(run.lit) >= float(spec.get("reignite", 2.0)):
				run.lit = 0.0
				_ignite_ring(spec)
			var at: Vector2 = run.at
			var radius := float(spec.get("radius", 150.0))
			if rng.randf() < dt * 40.0:
				var a := rng.randf() * TAU
				bits.append({"p": at + Vector2(cos(a), sin(a) * 0.62) * radius, "h": rng.randf_range(4, 30), "v": Vector2.ZERO, "vh": rng.randf_range(50, 110), "col": Color("ffb040") if rng.randf() < 0.6 else Color("ff5a1a"), "life": 0.7, "rest": false, "rise": true})
			if float(run.tick) <= 0.0:
				run.tick = float(spec.get("tick", 0.5))
				for m: Dictionary in g.mobs:
					if not g._hittable(m): continue
					var d := _ellipse_gap(m.p, at)
					if absf(d - radius) < float(spec.get("band", 34.0)) + float(m.get("r", 20.0)):
						g._damage_mob(m, ((m.p as Vector2) - at).normalized() * 120.0, float(spec.get("hits", 0.35)))
						if float(m.get("wet_t", 0.0)) <= 0.0:
							g.HeroKit.burn_mob(m, float(spec.get("burn_dps", 0.7)), float(spec.get("burn_time", 3.0)))
							m.fire_t = maxf(float(m.get("fire_t", 0.0)), float(spec.get("burn_time", 3.0)))
				_play_once(spec, "tick")
		"ice_armor":
			if rng.randf() < dt * 6.0:
				var a := rng.randf() * TAU
				bits.append({"p": me + Vector2(cos(a), sin(a) * 0.5) * 30.0, "h": rng.randf_range(20, 70), "v": Vector2.ZERO, "vh": -20.0, "col": Color("e8fbff"), "life": 0.8, "rest": false, "rise": true})
		"void_step":
			var at: Vector2 = run.at
			var pull := float(spec.get("pull_speed", 260.0))
			for m: Dictionary in _mobs_near(at, float(spec.get("pull_radius", 190.0))):
				var gap: Vector2 = at - (m.p as Vector2)
				if gap.length() < 12.0: continue
				var share := float(spec.get("boss_share", 0.3)) if str(m.get("kind", "")) == "boss" else 1.0
				var next: Vector2 = (m.p as Vector2) + gap.normalized() * minf(gap.length(), pull * share * dt)
				if _open(next): m.p = next
			if g.get("gas") != null and g.gas.has_method("suck"):
				g.gas.suck(at, float(spec.get("pull_radius", 190.0)), 1.0, 0.5, dt, float(g.state.get("t", 0.0)))
			if rng.randf() < dt * 30.0:
				var a := rng.randf() * TAU
				var r := float(spec.get("pull_radius", 190.0)) * rng.randf_range(0.5, 1.0)
				var from := at + Vector2(cos(a), sin(a) * 0.62) * r
				bits.append({"p": from, "h": rng.randf_range(2, 20), "v": (at - from) * 1.6, "vh": 0.0, "col": Color("b07bff") if rng.randf() < 0.5 else Color("3c1a6a"), "life": 0.55, "rest": false, "rise": true})
		"bone_shield":
			run.angle = float(run.get("angle", 0.0)) + float(spec.get("spin", 3.2)) * dt
			var alive := 0
			for i in range((run.bones as Array).size()):
				var bone: Dictionary = run.bones[i]
				if not bool(bone.alive): continue
				alive += 1
				var at := _bone_at(i, spec)
				for s: Dictionary in g.eshots:
					if float(s.get("t", 0.0)) > 0.0 and (s.p as Vector2).distance_to(at) < float(spec.get("block_radius", 22.0)):
						s.t = 0.0
						break_bone(i)
						break
			if alive == 0: active = 0.0
		"soul_drain":
			run.tick = float(run.tick) - dt
			if float(run.tick) <= 0.0:
				run.tick = float(spec.get("tick", 0.4))
				var near := _mobs_near(me, float(spec.get("radius", 240.0)))
				near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.p as Vector2).distance_to(me) < (b.p as Vector2).distance_to(me))
				for m: Dictionary in near.slice(0, int(spec.get("targets", 5))):
					g._damage_mob(m, Vector2.ZERO, float(spec.get("hits", 0.4)))
					fx.append({"kind": "streak", "a": (m.p as Vector2) - Vector2(0, float(m.get("cy", 30.0))), "t": float(spec.get("streak_time", 0.55)), "max": float(spec.get("streak_time", 0.55)), "col": Color(str(spec.color)), "seed": rng.randf() * 10.0})
					run.drained = int(run.drained) + 1
					if int(run.drained) % maxi(1, int(spec.get("heal_every", 5))) == 0 and int(run.healed) < int(spec.get("heal_max", 2)) and _heal(1):
						run.healed = int(run.healed) + 1
						_sfx(spec, "heal")


## The running power ends: what it leaves returns to rest.
func _end() -> void:
	var spec := row()
	if g == null:
		run = {}
		return
	match id:
		"shield_wall", "blood_rush", "soul_drain", "flame_ring":
			_sfx(spec, "end")
		"ice_armor":
			if int(run.get("charges", 0)) > 0: _ice_hit(spec, true, true)
		"void_step":
			var at: Vector2 = run.get("at", _hero())
			for m: Dictionary in _mobs_near(at, float(spec.get("collapse_radius", 80.0))):
				g._damage_mob(m, Vector2.ZERO, float(spec.get("hits", 0.8)))
			fx.append({"kind": "ring", "p": at - Vector2(0, 10), "t": 0.25, "max": 0.25, "r": float(spec.get("collapse_radius", 80.0)), "col": Color("e8d0ff")})
			_spray(at - Vector2(0, 10), Color("b07bff"), 12, 200.0, 10.0)
			_shake(float(spec.get("shake", 3.0)))
			_sfx(spec, "collapse")
		"bone_shield":
			for i in range((run.get("bones", []) as Array).size()):
				if bool(run.bones[i].alive): break_bone(i, true)
			_sfx(spec, "end")
	run = {}


## A Knochenschild bone breaks (a shot, or the time ran out: `soft`): its
## splinters fall from where it flew and settle on the floor.
func break_bone(index: int, soft := false) -> void:
	var bones: Array = run.get("bones", [])
	if index < 0 or index >= bones.size() or not bool(bones[index].alive): return
	bones[index].alive = false
	if g == null: return
	var spec := row()
	var at := _bone_at(index, spec)
	var ground := at + Vector2(0, float(spec.get("lift", 34.0)))
	for k in range(int(spec.get("splinters", 10)) >> (1 if soft else 0)):
		var a := rng.randf() * TAU
		var speed := rng.randf_range(40.0, 160.0 if not soft else 60.0)
		bits.append({"p": ground, "h": float(spec.get("lift", 34.0)), "v": Vector2(cos(a), sin(a) * 0.6) * speed, "vh": rng.randf_range(60.0, 220.0),
			"col": Color("e8dcb0") if rng.randf() < 0.65 else Color("a8946a"), "life": float(data().get("settle_time", 5.0)) + rng.randf_range(0.0, 1.5), "rest": false, "rise": false, "len": rng.randi_range(1, 3)})
	fx.append({"kind": "flash", "p": at, "t": 0.15, "max": 0.15, "r": 18.0, "col": Color("fff4d0")})
	if not soft:
		_shake(2.0)
		_sfx(spec, "block")


# --- the powers' pieces -------------------------------------------------------------

func _new_bones(spec: Dictionary) -> Array:
	var bones: Array = []
	for i in range(int(spec.get("count", 3))): bones.append({"alive": true})
	return bones


## Where Knochenschild bone `index` flies now (world px, at chest height).
func _bone_at(index: int, spec: Dictionary) -> Vector2:
	var count := maxi(1, (run.get("bones", []) as Array).size())
	var a := float(run.get("angle", 0.0)) + TAU * float(index) / float(count)
	var orbit := float(spec.get("orbit", 62.0))
	return _hero() - Vector2(0, float(spec.get("lift", 34.0))) + Vector2(cos(a) * orbit, sin(a) * orbit * 0.55)


func _wall_block(src: Vector2, spec: Dictionary) -> void:
	var me := _hero()
	var dir: Vector2 = run.get("dir", _aim())
	for m: Dictionary in _mobs_near(me, float(spec.get("reach", 170.0))):
		if _in_front(m.p, spec):
			g._damage_mob(m, ((m.p as Vector2) - me).normalized() * float(spec.get("push", 700.0)), float(spec.get("bash_hits", 0.5)))
	var hit := me - Vector2(0, 30) + dir * 34.0
	fx.append({"kind": "flash", "p": hit, "t": 0.2, "max": 0.2, "r": 34.0, "col": Color("fff1c0")})
	_spray(hit, Color(str(spec.get("color", "d9c48a"))), 10, 220.0, 0.0, (src - me).normalized())
	_shake(float(spec.get("shake", 5.0)))
	_sfx(spec, "block")


func _ice_hit(spec: Dictionary, shatter: bool, soft := false) -> void:
	# the last charge breaks the shell (the rule, with or without a world)
	if shatter: active = 0.0
	if g == null: return
	var me := _hero()
	for m: Dictionary in _mobs_near(me, float(spec.get("chill_radius", 150.0))):
		g.HeroKit.slow_mob(g, m, float(spec.get("chill", 0.5)), float(spec.get("chill_time", 2.5)))
	var n := 22 if shatter else 7
	for k in range(n >> (1 if soft else 0)):
		var a := rng.randf() * TAU
		bits.append({"p": me + Vector2(cos(a), sin(a) * 0.5) * 20.0, "h": rng.randf_range(20.0, 60.0), "v": Vector2(cos(a), sin(a) * 0.6) * rng.randf_range(60.0, 200.0), "vh": rng.randf_range(40.0, 180.0),
			"col": Color("c8f0ff") if rng.randf() < 0.6 else Color("7ab8e0"), "life": float(data().get("settle_time", 5.0)) * 0.6, "rest": false, "rise": false, "len": 1})
	fx.append({"kind": "flash", "p": me - Vector2(0, 36), "t": 0.2, "max": 0.2, "r": 40.0, "col": Color("e8fbff")})
	_shake(float(spec.get("shake", 3.0)) * (1.4 if shatter else 0.7))
	_sfx(spec, "break" if shatter else "hit")


func _ignite_ring(spec: Dictionary) -> void:
	var at: Vector2 = run.get("at", _hero())
	var radius := float(spec.get("radius", 150.0))
	var points := int(spec.get("points", 12))
	var time := maxf(0.5, active)
	for i in range(points):
		var a := TAU * float(i) / float(points)
		var p := at + Vector2(cos(a), sin(a) * 0.62) * radius
		if not _open(p): continue
		# element physics: the fire touches what lies there (oil, poison, gas, water)
		if g.get("story_elements") != null: g.story_elements.fire_at(p, float(spec.get("puddle_r", 34.0)), 1)
		if g.get("monsters") != null and float(run.get("zoned", 0.0)) <= 0.0:
			g.monsters._zone({"kind": "puddle", "p": p, "r": float(spec.get("puddle_r", 34.0)), "T": time, "dmg": 0, "friend": true, "st": "fire",
				"m": {"id": "glutrobe", "def": {"name": "Flammenkreis"}, "boss": false}, "dir": Vector2(cos(a), sin(a))})
	run.zoned = 1.0


func _step_hail(spec: Dictionary, dt: float) -> void:
	run.clock = float(run.clock) + dt
	var warn := float(spec.get("telegraph", 0.45))
	var count := int(spec.get("count", 16))
	var rain := float(spec.get("rain", 1.0))
	if float(run.clock) >= warn and int(run.spawned) < count:
		var due := int(clampf((float(run.clock) - warn) / maxf(0.01, rain), 0.0, 1.0) * count) + 1
		while int(run.spawned) < mini(due, count):
			run.spawned = int(run.spawned) + 1
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * float(spec.get("radius", 110.0))
			(run.arrows as Array).append({"p": (run.at as Vector2) + Vector2(cos(a), sin(a) * 0.62) * r, "h": float(spec.get("fall", 280.0)), "down": true})
			if int(run.spawned) % 4 == 1: _sfx(spec, "rain")
	for arrow: Dictionary in run.arrows:
		if not bool(arrow.down): continue
		arrow.h = float(arrow.h) - float(spec.get("fall_speed", 1100.0)) * dt
		if float(arrow.h) <= 0.0:
			arrow.down = false
			fx.append({"kind": "stuck", "p": arrow.p, "t": float(spec.get("stick", 1.6)), "max": float(spec.get("stick", 1.6)), "tilt": rng.randf_range(-0.3, 0.3)})
			_spray(arrow.p, Color("c9b48a"), 3, 80.0, 0.0)
			for m: Dictionary in _mobs_near(arrow.p, float(spec.get("hit_radius", 26.0))):
				g._damage_mob(m, Vector2.ZERO, float(spec.get("hits", 0.6)))
			_play_once(spec, "land")
	if int(run.spawned) == count and int(run.spawned) > 0 and float(run.clock) < warn + rain + 0.05 and float(run.clock) + dt >= warn + rain:
		_shake(float(spec.get("shake", 2.0)))


func _step_range() -> void:
	var bonus := range_bonus()
	if bonus <= 0.0 or g.get("shots") == null: return
	for s: Dictionary in g.shots:
		if not s.has("_ranged"):
			s._ranged = true
			s.t = float(s.get("t", 0.0)) * (1.0 + bonus)


func _step_bits(dt: float) -> void:
	var gravity := float(data().get("gravity", 900.0))
	for b: Dictionary in bits:
		b.life = float(b.life) - dt
		if bool(b.rest): continue
		if bool(b.get("rise", false)):
			b.h = float(b.h) + float(b.vh) * dt
			b.p = (b.p as Vector2) + (b.v as Vector2) * dt
			continue
		b.vh = float(b.vh) - gravity * dt
		b.h = float(b.h) + float(b.vh) * dt
		b.p = (b.p as Vector2) + (b.v as Vector2) * dt
		b.v = (b.v as Vector2) * maxf(0.0, 1.0 - 3.0 * dt)
		if float(b.h) <= 0.0:
			b.h = 0.0
			if absf(float(b.vh)) > 90.0:
				b.vh = -float(b.vh) * 0.3
				b.v = (b.v as Vector2) * 0.5
			else:
				b.rest = true
	bits = bits.filter(func(b: Dictionary) -> bool: return float(b.life) > 0.0)
	var cap := int(data().get("max_bits", 420))
	if bits.size() > cap: bits = bits.slice(bits.size() - cap)


# --- drawing ------------------------------------------------------------------------

## Ground layer (under the figures): the fire ring, the ice crust, the hail's
## warning and its stuck arrows, the void's swirl, settled pixel matter.
func draw_ground(l: CanvasItem) -> void:
	var t := float(g.state.get("t", 0.0)) if g != null else 0.0
	var px := float(data().get("pixel", 3.0))
	for f: Dictionary in fx:
		var k := float(f.t) / maxf(0.01, float(f.max))
		match str(f.kind):
			"crust":
				var fade := clampf(float(f.t) / 1.2, 0.0, 1.0)
				_pixel_ellipse(l, f.p, float(f.r) * (1.0 - 0.15 * (1.0 - k)), Color(0.75, 0.93, 1.0, 0.22 * fade), px * 2.0, true, float(f.seed))
				_pixel_ellipse(l, f.p, float(f.r), Color(0.9, 0.98, 1.0, 0.55 * fade), px, false, float(f.seed))
			"stuck":
				var tip: Vector2 = f.p
				var tail := tip + Vector2(sin(float(f.tilt)) * 18.0, -18.0)
				l.draw_line(tip, tail, Color(0.55, 0.42, 0.28, minf(1.0, k * 3.0)), 2.0)
				l.draw_rect(Rect2(tail - Vector2(2, 2), Vector2(4, 4)), Color(0.9, 0.9, 0.95, minf(1.0, k * 3.0)))
	if active > 0.0:
		var spec := row()
		match id:
			"arrow_hail":
				var warn := float(spec.get("telegraph", 0.45))
				var grow := clampf(float(run.get("clock", 0.0)) / maxf(0.01, warn), 0.0, 1.0)
				_pixel_ellipse(l, run.at, float(spec.get("radius", 110.0)) * (0.4 + 0.6 * grow), Color(0.75, 0.86, 0.95, 0.65), px, false, 0.0)
				_pixel_ellipse(l, run.at, float(spec.get("radius", 110.0)), Color(0.7, 0.85, 1.0, 0.10), px * 2.0, true, 0.0)
			"flame_ring":
				var at: Vector2 = run.at
				var radius := float(spec.get("radius", 150.0))
				var fade := clampf(active / 0.6, 0.0, 1.0)
				var n := 64
				for i in range(n):
					var a := TAU * float(i) / float(n)
					var p := at + Vector2(cos(a), sin(a) * 0.62) * radius
					var flick := 0.5 + 0.5 * sin(t * 13.0 + float(i) * 2.1)
					var h := (8.0 + 16.0 * flick) * fade
					l.draw_rect(Rect2(p - Vector2(px, h), Vector2(px * 2.0, h)), Color(1.0, 0.45 + 0.3 * flick, 0.1, 0.85 * fade))
					l.draw_rect(Rect2(p - Vector2(px * 0.5, h * 0.6), Vector2(px, h * 0.6)), Color(1.0, 0.92, 0.55, 0.9 * fade))
				_pixel_ellipse(l, at, radius, Color(0.3, 0.08, 0.02, 0.45 * fade), px, false, 0.0)
			"void_step":
				var at: Vector2 = run.at
				var r := float(spec.get("pull_radius", 190.0)) * clampf(active / maxf(0.01, float(spec.get("pull_time", 1.4))), 0.2, 1.0)
				for ring in range(3):
					var rr := r * fmod(1.0 - t * 1.6 + float(ring) / 3.0, 1.0)
					_pixel_ellipse(l, at, rr, Color(0.69, 0.48, 1.0, 0.25 + 0.25 * (1.0 - rr / maxf(1.0, r))), px, false, float(ring))
				l.draw_circle(at, 14.0, Color("0a0612"))
				l.draw_circle(at, 9.0, Color("3c1a6a"))
	for b: Dictionary in bits:
		if bool(b.rest): _draw_bit(l, b, px)


## Top layer (over the figures): the wall, the ice shell, the bones, falling
## arrows and matter in flight, soul and blood streaks, the lost marks, flashes.
func draw_top(l: CanvasItem) -> void:
	if g == null: return
	var t := float(g.state.get("t", 0.0))
	var px := float(data().get("pixel", 3.0))
	var me := _hero()
	var spec := row()
	if active > 0.0:
		match id:
			"shield_wall":
				var dir: Vector2 = run.get("dir", Vector2.RIGHT)
				var centre := me - Vector2(0, 30)
				var half := deg_to_rad(float(spec.get("arc_deg", 130.0))) * 0.5
				var fade := clampf(active / 0.4, 0.0, 1.0)
				var steps := 14
				for i in range(steps + 1):
					var a := dir.angle() - half + 2.0 * half * float(i) / float(steps)
					var p := centre + Vector2(cos(a), sin(a) * 0.8) * 48.0
					var glint := 0.6 + 0.4 * sin(t * 9.0 + float(i))
					l.draw_rect(Rect2(p - Vector2(px, px * 2.0), Vector2(px * 2.0, px * 4.0)), Color(0.85, 0.77, 0.54, 0.75 * fade))
					l.draw_rect(Rect2(p - Vector2(px * 0.5, px * 2.0), Vector2(px, px)), Color(1.0, 0.96, 0.8, glint * fade))
			"blood_rush":
				var pulse := 0.5 + 0.5 * sin(t * 10.0)
				_pixel_ellipse(l, me, 26.0 + 4.0 * pulse, Color(0.85, 0.15, 0.15, 0.35 + 0.25 * pulse), px, false, 0.0)
			"ice_armor":
				var charges := int(run.get("charges", 0))
				var shell := 0.25 + 0.12 * float(charges)
				var c := me - Vector2(0, 36)
				l.draw_circle(c, 40.0, Color(0.7, 0.92, 1.0, shell * 0.35))
				_pixel_ellipse(l, c, 40.0, Color(0.9, 0.98, 1.0, shell + 0.2), px, false, 3.0, 1.0)
				for i in range(charges):
					var a := t * 1.5 + TAU * float(i) / maxf(1.0, float(charges))
					var p := c + Vector2(cos(a), sin(a)) * 30.0
					l.draw_rect(Rect2(p - Vector2(px, px), Vector2(px * 2.0, px * 2.0)), Color("e8fbff"))
			"shadow_leap":
				for m: Dictionary in g.mobs:
					if float(m.get("_lost_t", 0.0)) > 0.0 and float(m.get("stun", 0.0)) > 0.0:
						var head: Vector2 = (m.p as Vector2) - Vector2(0, float(m.get("cy", 30.0)) * 2.0 + 14.0 + sin(t * 6.0) * 3.0)
						_draw_mark(l, head, px)
			"arrow_hail":
				for arrow: Dictionary in run.get("arrows", []):
					if not bool(arrow.down): continue
					var tip: Vector2 = (arrow.p as Vector2) - Vector2(0, float(arrow.h))
					l.draw_line(tip, tip - Vector2(0, 22), Color(0.55, 0.42, 0.28), 2.0)
					l.draw_rect(Rect2(tip - Vector2(2, 1), Vector2(4, 4)), Color(0.92, 0.92, 0.98))
					l.draw_rect(Rect2(tip - Vector2(3, 24), Vector2(6, 4)), Color(0.85, 0.85, 0.9, 0.8))
			"bone_shield":
				for i in range((run.get("bones", []) as Array).size()):
					if not bool(run.bones[i].alive): continue
					var at := _bone_at(i, spec)
					var a := float(run.get("angle", 0.0)) * 2.0 + float(i)
					var axis := Vector2(cos(a), sin(a)) * 13.0
					l.draw_line(at - axis, at + axis, Color("5e5032"), 9.0)
					l.draw_line(at - axis, at + axis, Color("e8dcb0"), 5.0)
					for end: Vector2 in [at - axis, at + axis]:
						l.draw_rect(Rect2(end - Vector2(px * 1.5, px * 1.5), Vector2(px * 3.0, px * 3.0)), Color("5e5032"))
						l.draw_rect(Rect2(end - Vector2(px, px), Vector2(px * 2.0, px * 2.0)), Color("f4ecd0"))
			"soul_drain":
				var pulse := 0.5 + 0.5 * sin(t * 8.0)
				_pixel_ellipse(l, me - Vector2(0, 30), 22.0 + 6.0 * pulse, Color(0.56, 0.82, 0.88, 0.5), px, false, 0.0)
	for f: Dictionary in fx:
		var k := float(f.t) / maxf(0.01, float(f.max))
		match str(f.kind):
			"ring":
				_pixel_ellipse(l, f.p, float(f.r) * (1.2 - 0.6 * k), Color(f.col as Color, k), px, false, 0.0)
			"flash":
				l.draw_circle(f.p, float(f.r) * (1.3 - 0.5 * k), Color(f.col as Color, 0.55 * k))
			"ghost":
				var c := Color(f.col as Color, 0.6 * k)
				l.draw_rect(Rect2((f.p as Vector2) - Vector2(10, 56), Vector2(20, 56)), c)
				l.draw_circle((f.p as Vector2) - Vector2(0, 62), 9.0, c)
			"streak":
				var a: Vector2 = f.a
				var b := me - Vector2(0, 36)
				var along := 1.0 - k
				var col: Color = f.col
				for i in range(6):
					var s := clampf(along - float(i) * 0.06, 0.0, 1.0)
					var bend := Vector2(0, -40.0 * sin(s * PI)) + Vector2(sin(s * 9.0 + float(f.seed)) * 6.0, 0)
					var p := a.lerp(b, s) + bend
					l.draw_rect(Rect2(p - Vector2(px, px), Vector2(px * 2.0, px * 2.0)), Color(col.lightened(0.3 * float(i == 0)), 1.0 - float(i) / 6.0))
	for b: Dictionary in bits:
		if not bool(b.rest): _draw_bit(l, b, px)


func _draw_bit(l: CanvasItem, b: Dictionary, px: float) -> void:
	var col: Color = b.col
	var fade := clampf(float(b.life) / 0.8, 0.0, 1.0)
	var at: Vector2 = (b.p as Vector2) - Vector2(0, float(b.h))
	at = Vector2(floorf(at.x / px) * px, floorf(at.y / px) * px)
	var length := int(b.get("len", 1))
	l.draw_rect(Rect2(at, Vector2(px * float(length), px)), Color(col, col.a * fade))


func _draw_mark(l: CanvasItem, at: Vector2, px: float) -> void:
	var col := Color(0.85, 0.85, 0.95, 0.9)
	for cell: Vector2 in [Vector2(-1, -3), Vector2(0, -4), Vector2(1, -3), Vector2(1, -2), Vector2(0, -1), Vector2(0, 1)]:
		l.draw_rect(Rect2(at + cell * px, Vector2(px, px)), col)


## A pixel ellipse (y squashed to the floor's view) of radius `r`, filled or as a ring.
func _pixel_ellipse(l: CanvasItem, c: Vector2, r: float, col: Color, px: float, filled: bool, seed: float, squash := 0.62) -> void:
	if r <= 1.0: return
	if filled:
		l.draw_set_transform(c, 0.0, Vector2(1.0, squash))
		l.draw_circle(Vector2.ZERO, r, col)
		l.draw_set_transform(Vector2.ZERO)
		return
	var n := clampi(int(r * 0.5), 12, 96)
	for i in range(n):
		var a := TAU * float(i) / float(n) + seed
		var p := c + Vector2(cos(a), sin(a) * squash) * r
		l.draw_rect(Rect2(Vector2(floorf(p.x / px) * px, floorf(p.y / px) * px), Vector2(px, px)), col)


# --- helpers on the world -----------------------------------------------------------

func _hero() -> Vector2:
	return Vector2(float(g.player.x), float(g.player.y)) if g != null else Vector2.ZERO


func _aim() -> Vector2:
	if g == null: return Vector2.RIGHT
	var aim: Vector2 = g.HeroKit._aim(g)
	return aim.normalized() if aim.length() > 0.01 else Vector2.RIGHT


func _mobs_near(at: Vector2, r: float) -> Array:
	var out: Array = []
	for m: Dictionary in g.mobs:
		if g._hittable(m) and (m.p as Vector2).distance_to(at) < r + float(m.get("r", 20.0)): out.append(m)
	return out


## Distance on the floor's squashed view (rings are drawn with y x 0.62).
func _ellipse_gap(p: Vector2, c: Vector2) -> float:
	var d := p - c
	return Vector2(d.x, d.y / 0.62).length()


## Where a blow came from: `from` when known, else the nearest monster within `reach`.
func _source(from: Vector2, reach: float) -> Vector2:
	if from.is_finite() and from != Vector2.ZERO: return from
	if g == null: return Vector2.INF
	var best := Vector2.INF
	var near := reach
	for m: Dictionary in _mobs_near(_hero(), reach):
		var d := (m.p as Vector2).distance_to(_hero())
		if d < near:
			near = d
			best = m.p
	return best


func _in_front(p: Vector2, spec: Dictionary) -> bool:
	var dir: Vector2 = run.get("dir", Vector2.RIGHT)
	var rel := p - (_hero() - Vector2(0, 30))
	if rel.length() < 1.0: return true
	return rel.normalized().dot(dir) > cos(deg_to_rad(float(spec.get("arc_deg", 130.0))) * 0.5)


func _open(p: Vector2) -> bool:
	if g == null or not g.has_method("_cell_blocked"): return true
	var C: float = float(g.C)
	return not g._cell_blocked(int(floor(p.x / C)), int(floor(p.y / C)), false)


## The farthest open point on the way from `a` to `b` (blink stops at walls).
func _free_on_line(a: Vector2, b: Vector2) -> Vector2:
	var steps := maxi(1, int(a.distance_to(b) / 12.0))
	for i in range(steps, 0, -1):
		var p := a.lerp(b, float(i) / float(steps))
		if _open(p): return p
	return a


func _heal(n: int) -> bool:
	if g == null: return false
	var before := int(g.state.hp)
	g.state.hp = mini(int(g.state.max_hp), before + n)
	if int(g.state.hp) > before and g.get("feel") != null: g.feel.hero_perk("heal")
	return int(g.state.hp) > before


func _spray(at: Vector2, col: Color, n: int, speed: float, height: float, dir := Vector2.ZERO) -> void:
	for k in range(n):
		var a := dir.angle() + rng.randf_range(-0.9, 0.9) if dir != Vector2.ZERO else rng.randf() * TAU
		bits.append({"p": at + Vector2(0, height), "h": height, "v": Vector2(cos(a), sin(a) * 0.6) * rng.randf_range(speed * 0.4, speed), "vh": rng.randf_range(40.0, 160.0),
			"col": col, "life": rng.randf_range(0.4, 0.9), "rest": false, "rise": false})


func _smoke(at: Vector2, n: int) -> void:
	for k in range(n):
		bits.append({"p": at + Vector2(rng.randf_range(-16, 16), rng.randf_range(-6, 6)), "h": rng.randf_range(4, 40), "v": Vector2(rng.randf_range(-20, 20), 0), "vh": rng.randf_range(10, 40),
			"col": Color(0.2, 0.22, 0.2, 0.75) if rng.randf() < 0.6 else Color(0.43, 0.48, 0.41, 0.6), "life": rng.randf_range(0.4, 0.8), "rest": false, "rise": true})


func _shake(n: float) -> void:
	if g != null: g.state.shake = maxf(float(g.state.get("shake", 0.0)), n)


func _sfx(spec: Dictionary, key: String) -> void:
	var event := str(spec.get("sounds", {}).get(key, ""))
	if event.is_empty() or g == null: return
	if g.has_method("_sound_raw"): g._sound_raw(event)


## A sound that repeats in quick hits (blocks, landings, ticks) at most every 0.08 s.
func _play_once(spec: Dictionary, key: String) -> void:
	if _sound_gap > 0.0: return
	_sound_gap = 0.08
	_sfx(spec, key)


func _play_raw(event: String) -> void:
	if g != null and g.has_method("_sound_raw"): g._sound_raw(event)
