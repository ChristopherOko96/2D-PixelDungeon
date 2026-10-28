extends RefCounted
## Story 1's items in the Frostgruft (data: assets/data/items.json, rules as in
## src/items/inventory.gd and item_rules.gd). The hero carries one weapon and a
## bag (state.bag). Weapons are class-bound, have a rarity, are found
## unidentified and often cursed; potions are known only by colour until drunk,
## thrown or identified (colours shuffled per run); identification crystals and
## curse-breaker stones stack. A weapon's strength is its damage and interval
## against the class's start weapon, so it lifts the class weapon, the
## subclass attack and the skills alike; its effects (venom, cinder, frost,
## storm, crit, execution ...) work on every hit. Curses act as in the crypt
## (thorns, blood toll, burning blade, leaden hand, seal, fragile, sluggish,
## night) and turn into their blessing once broken. Chests, skull heaps and
## guardians drop loot; the hero picks it up by walking over it.

const HeroKit = preload("res://src/hell/hero_kit.gd")
const HeroFx = preload("res://src/hell/hero_fx.gd")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
const DATA_PATH := "res://assets/data/items.json"
const PERKS_PATH := "res://src/data/balance.json"
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
## Bag slot index meaning "the weapon in hand".
const EQUIPPED := 99

static var _data: Dictionary = {}
static var _perk_names: Dictionary = {}
## Loaded item sprites, kept so a texture drawn this frame is still alive when the frame renders.
static var _textures: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func weapon_spec(id: String) -> Dictionary:
	for w: Dictionary in data().get("weapons", []):
		if str(w.id) == id:
			return w
	return {}


static func start_spec(class_id: String) -> Dictionary:
	for w: Dictionary in data().get("weapons", []):
		if str(w["class"]) == class_id and bool(w.get("start", false)):
			return w
	return {}


static func curse(id: String) -> Dictionary:
	return data().get("curses", {}).get(id, {})


## Crypt pixels to this world (theme.items.scale) and crypt damage to this world's.
static func _k(g: Node) -> float:
	return float(g.theme.get("items", {}).get("scale", 2.4))


static func _dmg_scale(g: Node) -> float:
	return float(g.theme.get("items", {}).get("damage_scale", 0.5))


static func on(g: Node) -> bool:
	return not (g.theme.get("items", {}) as Dictionary).is_empty()


static func inv(g: Node) -> Dictionary:
	return g.state.get("bag", {})


# ---------- the run ----------

## A new run: shuffled potion colours, the class's start weapon, an empty bag.
static func new_run(g: Node) -> void:
	if not on(g):
		return
	var kinds: Array = data().get("potions", {}).keys()
	var palette: Array = data().get("potion_colors", {}).keys()
	palette.shuffle()
	var colors := {}
	for i in range(kinds.size()):
		colors[str(kinds[i])] = str(palette[i % palette.size()])
	var start := start_spec(g.class_id)
	g.state.bag = {"weapon": make_weapon(str(start.get("id", "")), true, "") if not start.is_empty() else {}, "bag": [], "colors": colors, "known": {},
		"augments": {}, "kills": 0, "shots_hit": 0, "curse_t": 0.0, "note": "", "note_t": 0.0, "shield": 0, "ground": []}


static func make_weapon(id: String, identified: bool, curse_id: String) -> Dictionary:
	var item := {"type": "weapon", "id": id, "identified": identified, "curse": curse_id, "blessed": false}
	if curse_id == "sealed":
		item.seal = randi_range(1, 4)
	return item


static func make_stack(type: String, potion := "", count := 1) -> Dictionary:
	var item := {"type": type, "count": count}
	if type == "potion":
		item.potion = potion
	return item


## What a source (crate, chest, mimic, gold_crate) drops on this floor ([] for nothing).
static func roll(g: Node, source: String) -> Array:
	var spec: Dictionary = data().get("drops", {}).get(source, {})
	if spec.is_empty():
		return []
	var depth := clampf((float(g.state.floor) - 1.0) / 9.0, 0.0, 1.0)
	var chance: Array = spec.get("chance", [0.2, 0.2])
	if randf() > lerpf(float(chance[0]), float(chance[1]), depth):
		return []
	var out: Array = [_roll_kind(g, spec, depth)]
	for extra: String in spec.get("extra", []):
		out.append(make_stack(extra))
	return out


static func _roll_kind(g: Node, spec: Dictionary, depth: float) -> Dictionary:
	var kinds: Dictionary = spec.get("kinds", {"potion": 1})
	var total := 0.0
	for kind: String in kinds:
		total += float(kinds[kind])
	var r := randf() * total
	var chosen := "potion"
	for kind: String in kinds:
		r -= float(kinds[kind])
		if r <= 0.0:
			chosen = kind
			break
	match chosen:
		"weapon":
			return roll_weapon(g, depth, str(spec.get("min_rarity", "common")))
		"potion":
			var potions: Array = data().get("potions", {}).keys()
			return make_stack("potion", str(potions[randi() % potions.size()]))
	return make_stack(chosen)


static func roll_weapon(g: Node, depth: float, minimum: String) -> Dictionary:
	var weights: Dictionary = data().get("rarity_weights", {})
	var lowest := RARITIES.find(minimum)
	var total := 0.0
	for i in range(lowest, RARITIES.size()):
		var pair: Array = weights.get(RARITIES[i], [1, 1])
		total += lerpf(float(pair[0]), float(pair[1]), depth)
	var r := randf() * total
	var rarity: String = RARITIES[lowest]
	for i in range(lowest, RARITIES.size()):
		var pair: Array = weights.get(RARITIES[i], [1, 1])
		r -= lerpf(float(pair[0]), float(pair[1]), depth)
		if r <= 0.0:
			rarity = RARITIES[i]
			break
	var pool: Array = data().get("weapons", []).filter(func(w: Dictionary) -> bool: return str(w.rarity) == rarity and str(w["class"]) == g.class_id and not bool(w.get("start", false)))
	if pool.is_empty():
		pool = data().get("weapons", []).filter(func(w: Dictionary) -> bool: return str(w["class"]) == g.class_id and not bool(w.get("start", false)))
	var spec: Dictionary = pool[randi() % pool.size()]
	var curse_id := ""
	if randf() < float(data().get("curse_chance", 0.6)):
		var curses: Array = data().get("curses", {}).keys()
		curse_id = str(curses[randi() % curses.size()])
	return make_weapon(str(spec.id), false, curse_id)


## Loot lies on the floor at `at`, scattered a little; the hero picks it up by walking over it.
static func drop_loot(g: Node, items: Array, at: Vector2) -> void:
	if not on(g):
		return
	for i in range(items.size()):
		var a := TAU * i / maxf(1.0, items.size()) + randf()
		g.state.bag.ground.append({"item": items[i], "p": at + Vector2(cos(a), sin(a)) * (30.0 + 20.0 * i), "t": 0.0})
	if not items.is_empty() and g.feel != null:
		g.feel.spawn("pickup", at - Vector2(0, 20), 1.0)


# ---------- names and looks ----------

## The name the hero sees: unknown weapons and potions only show what they look like.
static func name_of(g: Node, item: Dictionary) -> String:
	match str(item.get("type", "")):
		"weapon":
			var spec := weapon_spec(str(item.id))
			if not bool(item.get("identified", false)):
				return str(spec.get("unknown_name", "UNBEKANNTE WAFFE"))
			var title := str(spec.get("name", "WAFFE"))
			if bool(item.get("blessed", false)):
				return title + " · " + str(curse(str(item.curse)).get("blessing", {}).get("name", ""))
			if str(item.get("curse", "")) != "":
				return title + " · " + str(curse(str(item.curse)).get("name", "VERFLUCHT"))
			return title
		"potion":
			var kind := str(item.get("potion", ""))
			if inv(g).get("known", {}).has(kind):
				return str(data().potions[kind].get("name", "TRANK"))
			return str(data().get("potion_colors", {}).get(str(inv(g).colors.get(kind, "red")), "TRANK"))
		"crystal":
			return str(data().get("crystal", {}).get("name", "KRISTALL"))
		"stone":
			return str(data().get("stone", {}).get("name", "STEIN"))
	return "?"


## Sprite path of an item (assets/sprites/...).
static func sprite_of(g: Node, item: Dictionary) -> String:
	match str(item.get("type", "")):
		"weapon":
			return "res://assets/sprites/%s.png" % str(weapon_spec(str(item.id)).get("sprite", ""))
		"potion":
			return "res://assets/sprites/items/potion_%s.png" % str(inv(g).colors.get(str(item.potion), "red"))
		"crystal", "stone":
			return "res://assets/sprites/%s.png" % str(data().get(str(item.type), {}).get("sprite", ""))
	return ""


## The item's sprite as a texture (cached), or null.
static func texture_of(g: Node, item: Dictionary) -> Texture2D:
	var path := sprite_of(g, item)
	if not _textures.has(path):
		_textures[path] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _textures[path]


## Rarity colour of an item (weapons; consumables have their own).
static func color_of(item: Dictionary) -> Color:
	match str(item.get("type", "")):
		"weapon":
			return Color(str(data().rarities.get(str(weapon_spec(str(item.id)).get("rarity", "common")), {}).get("color", "c9c0b6")))
		"crystal":
			return Color("8fd8e6")
		"stone":
			return Color("edbf75")
	return Color("d3bfa9")


## Lines of text about an item, as Story 1 shows them.
static func lines_of(g: Node, item: Dictionary) -> Array:
	var out: Array = []
	match str(item.get("type", "")):
		"weapon":
			var spec := weapon_spec(str(item.id))
			var start := start_spec(g.class_id)
			out.append("%s · STÄRKE %d %% · TEMPO %d %%" % [str(data().rarities.get(str(spec.rarity), {}).get("label", "")),
				roundi(100.0 * float(spec.damage) / maxf(0.01, float(start.get("damage", spec.damage)))), roundi(100.0 * float(start.get("interval", spec.interval)) / maxf(0.01, float(spec.interval)))])
			if str(spec["class"]) != g.class_id:
				out.append("Nur für eine andere Klasse.")
			if bool(item.get("identified", false)):
				var fx: Array = []
				for key: String in spec.get("effects", {}):
					fx.append(perk_name(key))
				if not fx.is_empty():
					out.append("EFFEKT: " + ", ".join(fx))
				var c := str(item.get("curse", ""))
				if c != "":
					out.append(("SEGEN: " + str(curse(c).blessing.get("text", ""))) if bool(item.get("blessed", false)) else ("FLUCH: " + str(curse(c).get("text", ""))))
				else:
					out.append("Kein Fluch.")
			else:
				out.append("Unbekannt: Wirkung und Fluch zeigt ein Kristall oder das Anlegen.")
		"potion":
			var kind := str(item.potion)
			if inv(g).get("known", {}).has(kind):
				out.append("TRINKEN: " + str(data().potions[kind].get("drink", "")))
				out.append("WERFEN: " + str(data().potions[kind].get("throw", "")))
			else:
				out.append("Unbekannter Trank. Ein Kristall verrät ihn, oder du probierst ihn.")
		"crystal", "stone":
			out.append(str(data().get(str(item.type), {}).get("text", "")))
	return out


static func perk_name(key: String) -> String:
	if _perk_names.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PERKS_PATH))
		var perks: Variant = parsed.get("perks", []) if parsed is Dictionary else []
		for p: Dictionary in (perks.values() if perks is Dictionary else perks):
			_perk_names[str(p.get("id", ""))] = str(p.get("name", ""))
	return str(_perk_names.get(key, key.to_upper()))


static func note(g: Node, text: String) -> void:
	if inv(g).is_empty():
		return
	g.state.bag.note = text
	g.state.bag.note_t = 4.0
	g._toast(text)


# ---------- what the weapon in hand does ----------

static func _held(g: Node) -> Dictionary:
	return inv(g).get("weapon", {})


static func _blessing(g: Node) -> Dictionary:
	var w := _held(g)
	return curse(str(w.get("curse", ""))).get("blessing", {}) if bool(w.get("blessed", false)) else {}


## The curse that holds the hero now ("" when none or broken; known once equipped).
static func active_curse(g: Node) -> String:
	var w := _held(g)
	return str(w.get("curse", "")) if not bool(w.get("blessed", false)) and bool(w.get("identified", false)) else ""


## Damage factor of the weapon in hand against the class's start weapon.
static func power(g: Node) -> float:
	var w := _held(g)
	if w.is_empty():
		return 1.0
	var start := start_spec(g.class_id)
	return float(weapon_spec(str(w.id)).get("damage", 1.0)) / maxf(0.01, float(start.get("damage", 1.0)))


## Factor on the time between attacks: the weapon's interval, the leaden hand or the quick hand.
static func rate(g: Node) -> float:
	var w := _held(g)
	if w.is_empty():
		return 1.0
	var start := start_spec(g.class_id)
	var f := float(weapon_spec(str(w.id)).get("interval", 1.0)) / maxf(0.01, float(start.get("interval", 1.0)))
	if active_curse(g) == "leaden":
		f *= float(curse("leaden").get("interval", 1.4))
	f *= float(_blessing(g).get("interval", 1.0))
	return f


## Walking speed factor (sluggish / light foot).
static func speed(g: Node) -> float:
	return (float(curse("sluggish").get("speed", 0.8)) if active_curse(g) == "sluggish" else 1.0) * float(_blessing(g).get("speed", 1.0))


## Skill cooldown factor (the unbound blessing).
static func cooldown_scale(g: Node) -> float:
	return float(_blessing(g).get("cooldown", 1.0))


## The skill key a seal holds ("" for none).
static func sealed_key(g: Node) -> String:
	return str(int(_held(g).get("seal", 1))) if active_curse(g) == "sealed" else ""


## Extra half hearts every hit costs (fragile).
static func extra_hurt(g: Node) -> int:
	return int(curse("fragile").get("extra_damage", 1)) if active_curse(g) == "fragile" else 0


## True while the night curse dims the light.
static func dim(g: Node) -> bool:
	return active_curse(g) == "night"


## Every effect on the hero's hits: the weapon's, drunk augments, the blessing's.
static func effects(g: Node) -> Dictionary:
	var out: Dictionary = {}
	var w := _held(g)
	if not w.is_empty() and bool(w.get("identified", true)):
		for key: String in weapon_spec(str(w.id)).get("effects", {}):
			out[key] = float(out.get(key, 0.0)) + float(weapon_spec(str(w.id)).effects[key])
	for key: String in inv(g).get("augments", {}):
		out[key] = float(out.get(key, 0.0)) + float(inv(g).augments[key])
	for key: String in _blessing(g).get("effects", {}):
		out[key] = float(out.get(key, 0.0)) + float(_blessing(g).effects[key])
	return out


# ---------- hits ----------

## Damage factor of a hero hit before it lands: crit, execution, first strike,
## shatter, the hunter's mark, long shots. Sets state.last_crit.
static func hit_factor(g: Node, m: Dictionary, shot: Dictionary) -> float:
	if not on(g) or inv(g).is_empty():
		return 1.0
	var fx := effects(g)
	var f := 1.0
	g.state.last_crit = false
	if fx.has("crit") and randf() < float(fx.crit):
		f *= 1.75
		g.state.last_crit = true
	if fx.has("execution") and m.hp < m.max * 0.3:
		f *= 1.0 + float(fx.execution)
	if fx.has("first_strike") and m.hp >= m.max:
		f *= 1.0 + float(fx.first_strike)
	if fx.has("shatter") and (float(m.get("slow_t", 0.0)) > 0.0 or float(m.get("stun", 0.0)) > 0.0):
		f *= 1.0 + float(fx.shatter)
	if fx.has("mark"):
		f *= 1.0 + minf(1.0, float(m.get("marks", 0)) * float(fx.mark))
		m.marks = int(m.get("marks", 0)) + 1
	if fx.has("longshot") and shot.has("from"):
		f *= 1.0 + float(fx.longshot) * clampf((shot.p as Vector2).distance_to(shot.from) / (240.0 * _k(g)), 0.0, 1.0)
	return f


## After a hero hit: poison, fire, frost, storm and blast, leech on shots.
static func after_hit(g: Node, m: Dictionary, dealt: float, shot: Dictionary) -> void:
	if not on(g) or inv(g).is_empty() or dealt <= 0.0:
		return
	var fx := effects(g)
	var per_dmg := 1.0 / maxf(0.01, float(g.state.dmg))
	var ds := _dmg_scale(g)
	if fx.has("venom"):
		HeroKit.burn_mob(m, float(fx.venom) * ds * per_dmg, 3.0)
		m.poisoned = 3.0
	if fx.has("cinder"):
		HeroKit.burn_mob(m, float(fx.cinder) * ds * per_dmg, 3.0)
		m.burning = 3.0
	if fx.has("frost"):
		HeroKit.slow_mob(g, m, float(fx.frost), 3.0)
		m.frost_hits = int(m.get("frost_hits", 0)) + 1
		if fx.has("permafrost") and int(m.frost_hits) % 4 == 0 and not m.has("kit"):
			m.stun = maxf(float(m.get("stun", 0.0)), float(fx.permafrost) * (0.4 if m.kind == "boss" else 1.0))
			m.frozen = float(m.stun)
	if fx.has("storm"):
		var jumps := 0
		for o: Dictionary in g.mobs:
			if o != m and o.spawn <= 0.0 and (o.p as Vector2).distance_to(m.p) < 150.0 * _k(g) and jumps < 2:
				o.hp -= dealt * float(fx.storm)
				o.hit = 0.12
				g.fx.append({"kind": "bolt", "p": (m.p as Vector2) - Vector2(0, m.cy), "q": (o.p as Vector2) - Vector2(0, o.cy), "t": 0.25, "max": 0.25})
				jumps += 1
	if fx.has("blast"):
		for o: Dictionary in g.mobs:
			if o != m and o.spawn <= 0.0 and (o.p as Vector2).distance_to(m.p) < 60.0 * _k(g):
				o.hp -= dealt * float(fx.blast)
				o.hit = 0.12
		if g.feel != null:
			g.feel.on_blast(m.p, 60.0 * _k(g), "fire")
	if fx.has("leech") and not shot.is_empty():
		g.state.bag.shots_hit = int(inv(g).shots_hit) + 1
		if int(inv(g).shots_hit) % maxi(1, int(fx.leech)) == 0:
			_heal(g, 1)
	if fx.has("split") and not shot.is_empty() and not shot.get("split_done", false):
		shot.split_done = true
		for side in [-0.5, 0.5]:
			var v: Vector2 = (shot.v as Vector2).rotated(side)
			g.shots.append({"p": shot.p, "v": v, "t": 0.5, "kind": str(shot.get("kind", "")), "mult": float(shot.get("mult", 1.0)) * float(fx.split), "hits": [m], "split_done": true})


## A hero kill: overkill, plague, combustion and the vampire's count.
static func after_kill(g: Node, m: Dictionary) -> void:
	if not on(g) or inv(g).is_empty():
		return
	var fx := effects(g)
	var near: Array = g.mobs.filter(func(o: Dictionary) -> bool: return o != m and o.spawn <= 0.0 and (o.p as Vector2).distance_to(m.p) < 110.0 * _k(g))
	if fx.has("overkill") and float(m.hp) < 0.0 and not near.is_empty():
		var o: Dictionary = near[0]
		o.hp -= -float(m.hp) * float(fx.overkill)
		o.hit = 0.12
	if fx.has("plague") and float(m.get("poisoned", 0.0)) > 0.0:
		for o: Dictionary in near:
			HeroKit.burn_mob(o, float(m.get("burn", 0.3)), 3.0)
			o.poisoned = 3.0
	if fx.has("combustion") and float(m.get("burning", 0.0)) > 0.0:
		for o: Dictionary in near:
			o.hp -= float(g.state.dmg) * float(fx.combustion)
			o.hit = 0.12
		if g.feel != null:
			g.feel.on_blast(m.p, 110.0 * _k(g), "fire")
		g._sound_raw("blast")
	g.state.bag.kills = int(inv(g).kills) + 1
	if fx.has("vampire") and int(inv(g).kills) % maxi(1, int(fx.vampire)) == 0:
		_heal(g, 1)


## A fresh shot of the hero (any attack): twin barrels, homing, piercing.
static func shape_shot(g: Node, s: Dictionary) -> void:
	if not on(g) or inv(g).is_empty():
		return
	var fx := effects(g)
	s.from = s.p
	if fx.has("piercer"):
		s.pierce = true
	if fx.has("homing"):
		s.item_seek = float(fx.homing)
	if fx.has("twin") and not s.get("twin_done", false):
		s.twin_done = true
		s.mult = float(s.get("mult", 1.0)) * float(fx.twin)
		var side: Vector2 = (s.v as Vector2).normalized().orthogonal() * 16.0
		var copy: Dictionary = s.duplicate()
		copy.hits = []
		copy.p = (s.p as Vector2) + side
		s.p = (s.p as Vector2) - side
		g.shots.append(copy)


## The hero blocks one more hit (shield potion, hardened blessing); true when it did.
static func guard(g: Node) -> bool:
	if inv(g).is_empty() or int(inv(g).get("shield", 0)) <= 0:
		return false
	g.state.bag.shield = int(inv(g).shield) - 1
	if int(inv(g).shield) <= 0:
		HeroFx.clear(g, "shield")
	if g.feel != null:
		g.feel.spawn("hit_spark", Vector2(g.player.x, g.player.y - 40), 1.6, Color(1.0, 0.85, 0.4))
	g._sound("block")
	return true


## A fight room starts: the hardened blessing guards one hit.
static func on_fight(g: Node) -> void:
	if inv(g).is_empty():
		return
	var shield := int(effects(g).get("shield", 0))
	if shield > 0:
		g.state.bag.shield = maxi(int(inv(g).shield), shield)


## The hero attacks: the burning blade sometimes burns its bearer.
static func on_attack(g: Node) -> void:
	if active_curse(g) == "burning_blade" and randf() < float(curse("burning_blade").get("chance", 0.18)):
		HeroFx.apply(g, "burn", float(curse("burning_blade").get("time", 2.0)), 1.0)


static func _heal(g: Node, n: int) -> void:
	g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + n)
	if g.feel != null:
		g.feel.spawn("pickup", Vector2(g.player.x, g.player.y - 40), 0.8, Color(0.6, 1.0, 0.6))


# ---------- per frame ----------

## Curses over time, homing shots, loot on the floor.
static func update(g: Node, dt: float) -> void:
	if not on(g) or inv(g).is_empty():
		return
	var iv: Dictionary = g.state.bag
	iv.note_t = maxf(0.0, float(iv.note_t) - dt)
	var me := Vector2(g.player.x, g.player.y)
	# loot: walk over it to take it
	for it: Dictionary in iv.ground:
		it.t = float(it.t) + dt
		if float(it.t) > 0.4 and me.distance_to(it.p) < 70.0:
			if add(g, it.item):
				it.taken = true
				g._sound("key")
	iv.ground = (iv.ground as Array).filter(func(it: Dictionary) -> bool: return not it.get("taken", false))
	for s: Dictionary in g.shots:
		if float(s.get("item_seek", 0.0)) > 0.0:
			var best: Dictionary = {}
			var bd := 420.0
			for m: Dictionary in g.mobs:
				var d := (s.p as Vector2).distance_to((m.p as Vector2) - Vector2(0, m.cy))
				if m.spawn <= 0.0 and d < bd and not (s.get("hits", []) as Array).has(m):
					bd = d
					best = m
			if not best.is_empty():
				var speed := (s.v as Vector2).length()
				s.v = (s.v as Vector2).lerp((((best.p as Vector2) - Vector2(0, best.cy)) - s.p).normalized() * speed, 1.0 - pow(0.15, dt * float(s.item_seek)))
	for m: Dictionary in g.mobs:
		for key: String in ["poisoned", "burning", "frozen"]:
			if m.has(key):
				m[key] = maxf(0.0, float(m[key]) - dt)
	var c := str(_held(g).get("curse", ""))
	if c == "" or not bool(_held(g).get("identified", false)):
		return
	var rules := curse(c)
	var blessed := bool(_held(g).get("blessed", false))
	var every := float(rules.get("blessing", {}).get("every", 0.0)) if blessed else float(rules.get("every", 0.0))
	if every <= 0.0:
		return
	iv.curse_t = float(iv.get("curse_t", every)) - dt
	if float(iv.curse_t) > 0.0:
		return
	iv.curse_t = every
	match c:
		"thorns":
			if blessed:
				var best: Dictionary = {}
				var bd := 260.0 * _k(g)
				for m: Dictionary in g.mobs:
					if m.spawn <= 0.0 and me.distance_to(m.p) < bd:
						bd = me.distance_to(m.p)
						best = m
				if not best.is_empty():
					g._damage_mob(best, Vector2.ZERO, float(rules.blessing.get("damage", 5)) * _dmg_scale(g) / maxf(0.01, float(g.state.dmg)))
					if g.feel != null:
						g.feel.on_blast(best.p, 30.0 * _k(g), "bone")
			elif not g.mobs.is_empty():
				g.state.mzones = g.state.get("mzones", [])
				g.state.mzones.append({"kind": "strike", "p": me, "r": 26.0 * _k(g), "t": float(rules.get("warn", 0.7)), "max": float(rules.get("warn", 0.7)),
					"dmg": int(rules.get("damage", 1)), "effect": {}, "style": "bone", "pool": {}})
		"bloodthirst":
			if not blessed:
				g.dot_hurt(int(rules.get("damage", 1)), "vom Blutzoll ausgesaugt")


# ---------- the bag ----------

## Puts an item in the bag (consumables stack). False when it is full.
static func add(g: Node, item: Dictionary) -> bool:
	var bag: Array = g.state.bag.bag
	if str(item.type) != "weapon":
		for held: Dictionary in bag:
			if str(held.type) == str(item.type) and str(held.get("potion", "")) == str(item.get("potion", "")):
				held.count = int(held.count) + int(item.get("count", 1))
				note(g, "Gefunden: " + name_of(g, item))
				return true
	if bag.size() >= int(data().get("bag", 12)):
		note(g, "Rucksack voll.")
		return false
	bag.append(item)
	note(g, "Gefunden: " + name_of(g, item))
	return true


static func slot(g: Node, i: int) -> Dictionary:
	if i == EQUIPPED:
		return g.state.bag.weapon
	var bag: Array = g.state.bag.bag
	return bag[i] if i >= 0 and i < bag.size() else {}


## The actions an item offers in the bag (Story 1's verbs).
static func actions(g: Node, i: int) -> Array:
	var item := slot(g, i)
	var out: Array = []
	match str(item.get("type", "")):
		"weapon":
			if i != EQUIPPED:
				out.append("equip")
			if not bool(item.get("identified", false)):
				out.append("identify")
			elif str(item.get("curse", "")) != "" and not bool(item.get("blessed", false)):
				out.append("cleanse")
		"potion":
			out.append_array(["drink", "throw"])
			if not inv(g).known.has(str(item.potion)):
				out.append("identify")
	if i != EQUIPPED and not item.is_empty():
		out.append("drop")
	return out


static func act(g: Node, action: String, i: int, target := Vector2.INF) -> void:
	match action:
		"equip":
			_equip(g, i)
		"identify":
			_identify(g, i)
		"cleanse":
			_cleanse(g, i)
		"drink":
			_drink(g, i)
		"throw":
			_throw(g, i, target)
		"drop":
			var item := slot(g, i)
			if i != EQUIPPED and not item.is_empty():
				g.state.bag.bag.remove_at(i)
				drop_loot(g, [item], Vector2(g.player.x + float(g.player.face) * 90.0, g.player.y))
				g.state.bag.ground[g.state.bag.ground.size() - 1].t = -2.0
				note(g, "Abgelegt: " + name_of(g, item))


static func _spend(g: Node, type: String) -> bool:
	var bag: Array = g.state.bag.bag
	for i in range(bag.size()):
		if str(bag[i].type) == type:
			bag[i].count = int(bag[i].count) - 1
			if int(bag[i].count) <= 0:
				bag.remove_at(i)
			return true
	return false


static func _equip(g: Node, i: int) -> void:
	var item := slot(g, i)
	if i == EQUIPPED or str(item.get("type", "")) != "weapon":
		return
	if str(weapon_spec(str(item.id))["class"]) != g.class_id:
		note(g, "Diese Waffe ist für eine andere Klasse.")
		return
	var held: Dictionary = g.state.bag.weapon
	if active_curse(g) != "" and str(held.get("curse", "")) != "":
		note(g, "Verflucht! Die Waffe lässt sich nicht ablegen. Ein Fluchbrecherstein hilft.")
		return
	g.state.bag.bag[i] = held
	g.state.bag.weapon = item
	var first := not bool(item.get("identified", false))
	item.identified = true
	equip_look(g)
	if first and str(item.get("curse", "")) != "":
		var rules := curse(str(item.curse))
		note(g, "VERFLUCHT: %s. %s" % [str(rules.get("name", "")), str(rules.get("text", ""))])
		if g.feel != null:
			g.feel.burst(Vector2(g.player.x, g.player.y - 40), Color("5a2a7a"), 20, 260.0, 0.8)
		g._sound_raw("attack_roar")
	else:
		note(g, "Angelegt: " + name_of(g, item))


static func _identify(g: Node, i: int) -> void:
	var item := slot(g, i)
	if item.is_empty() or not str(item.type) in ["weapon", "potion"]:
		return
	if str(item.type) == "weapon" and bool(item.get("identified", false)) or str(item.type) == "potion" and inv(g).known.has(str(item.potion)):
		return
	if not _spend(g, "crystal"):
		note(g, "Dafür brauchst du einen Identifizierungskristall.")
		return
	if str(item.type) == "potion":
		_learn(g, str(item.potion))
		return
	item.identified = true
	var c := str(item.get("curse", ""))
	note(g, "%s: %s" % [name_of(g, item), ("Verflucht! " + str(curse(c).get("text", ""))) if c != "" else "kein Fluch."])
	g._sound("key")


static func _cleanse(g: Node, i: int) -> void:
	var item := slot(g, i)
	if str(item.get("type", "")) != "weapon" or str(item.get("curse", "")) == "" or bool(item.get("blessed", false)) or not bool(item.get("identified", false)):
		note(g, "Auf dieser Waffe liegt kein bekannter Fluch.")
		return
	if not _spend(g, "stone"):
		note(g, "Dafür brauchst du einen Fluchbrecherstein.")
		return
	item.blessed = true
	var b: Dictionary = curse(str(item.curse)).get("blessing", {})
	note(g, "Fluch gebrochen! Segen: %s. %s" % [str(b.get("name", "")), str(b.get("text", ""))])
	g._sound("room_clear")


static func _learn(g: Node, kind: String) -> void:
	if inv(g).known.has(kind):
		return
	g.state.bag.known[kind] = true
	note(g, "%s ist ein %s." % [str(data().get("potion_colors", {}).get(str(inv(g).colors.get(kind, "")), "TRANK")), str(data().potions[kind].get("name", ""))])


static func _take_potion(g: Node, i: int) -> String:
	var item := slot(g, i)
	if str(item.get("type", "")) != "potion":
		return ""
	item.count = int(item.count) - 1
	if int(item.count) <= 0:
		g.state.bag.bag.remove_at(i)
	return str(item.potion)


static func _drink(g: Node, i: int) -> void:
	var kind := _take_potion(g, i)
	if kind == "":
		return
	var spec: Dictionary = data().potions.get(kind, {})
	_learn(g, kind)
	match kind:
		"healing":
			g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + int(spec.get("heal", 4)))
		"strength":
			HeroFx.apply(g, "strength", float(spec.get("time", 20)), float(spec.get("value", 1.4)))
		"haste":
			HeroFx.apply(g, "haste", float(spec.get("time", 15)), float(spec.get("value", 1.35)))
		"shield":
			g.state.bag.shield = int(inv(g).shield) + int(spec.get("charges", 2))
			HeroFx.apply(g, "shield", 999.0, 1.0)
		"regeneration":
			HeroFx.apply(g, "regen", float(spec.get("time", 18)), float(spec.get("every", 3)))
		"aftershock", "chainlight":
			for key: String in spec.get("effects", {}):
				g.state.bag.augments[key] = float(inv(g).augments.get(key, 0.0)) + float(spec.effects[key])
		"fire":
			HeroFx.apply(g, "burn", float(spec.get("time", 4)), 1.0)
		"ice":
			HeroFx.apply(g, "slow", float(spec.get("time", 6)), 0.6)
			HeroFx.apply(g, "weak", float(spec.get("time", 6)), 0.5)
		"blind":
			HeroFx.apply(g, "blind", float(spec.get("time", 10)), 1.0)
		"poison":
			HeroFx.apply(g, "poison", float(spec.get("time", 5)), 1.0)
		"explosion":
			if g.feel != null:
				g.feel.on_blast(Vector2(g.player.x, g.player.y), 120.0, "fire")
			g.dot_hurt(int(spec.get("self_damage", 3)), "vom Sprengtrank zerrissen")
	if g.feel != null:
		g.feel.burst(Vector2(g.player.x, g.player.y - 56), Color(potion_color(g, kind)), 10, 160.0, 0.6, Vector2.UP, 1.0)
	g._sound("key")


static func potion_color(g: Node, kind: String) -> String:
	var hexes := {"red": "d23c3c", "orange": "e8812e", "yellow": "f2d24a", "lime": "9be04a", "green": "3fbf5a", "teal": "38c9b0", "sky": "6cc6f0", "blue": "3b5fe0", "violet": "9a4fe0", "pink": "ef7ab8", "white": "f2efe8", "black": "3a3436"}
	return str(hexes.get(str(inv(g).colors.get(kind, "red")), "c8323a"))


## A thrown potion bursts where the hero aims (within the throw range, stopped by walls).
static func _throw(g: Node, i: int, target: Vector2) -> void:
	var kind := _take_potion(g, i)
	if kind == "":
		return
	var spec: Dictionary = data().potions.get(kind, {})
	_learn(g, kind)
	var k := _k(g)
	var from := Vector2(g.player.x, g.player.y)
	if not target.is_finite():
		target = from + Vector2(float(g.player.face), 0) * 160.0 * k
	var rng := float(data().get("throw_range", 320)) * k
	if from.distance_to(target) > rng:
		target = from + (target - from).normalized() * rng
	var point := from
	var steps := maxi(1, int(from.distance_to(target) / 24.0))
	for st in range(1, steps + 1):
		var nx := from.lerp(target, float(st) / steps)
		if g.box_blocked(Rect2(nx.x - 6, nx.y - 6, 12, 12)):
			break
		point = nx
	var radius := float(spec.get("radius", 60)) * k
	var ds := _dmg_scale(g)
	var per := 1.0 / maxf(0.01, float(g.state.dmg))
	if g.feel != null:
		g.feel.burst(point, Color(potion_color(g, kind)), 22, 420.0, 0.6)
		g.feel.stain(point, Color(potion_color(g, kind)).darkened(0.3), radius * 0.4)
	g._sound_raw("crate_break")
	var near: Array = g.mobs.filter(func(m: Dictionary) -> bool: return m.spawn <= 0.0 and (m.p as Vector2).distance_to(point) <= radius + m.r)
	match kind:
		"healing":
			if from.distance_to(point) <= radius:
				g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + int(spec.get("throw_heal", 2)))
		"regeneration":
			if from.distance_to(point) <= radius:
				HeroFx.apply(g, "regen", float(spec.get("time", 18)), float(spec.get("every", 3)))
		"fire", "poison":
			g.state.hzones = g.state.get("hzones", [])
			g.state.hzones.append({"kind": kind, "p": point, "r": radius, "t": float(spec.get("pool_time", 5)), "max": float(spec.get("pool_time", 5)), "dps": float(spec.get("dps", 2)) * ds * per})
		"ice":
			for m: Dictionary in near:
				if not m.has("kit"):
					m.stun = maxf(float(m.get("stun", 0.0)), float(spec.get("freeze", 2.5)) * (0.35 if m.kind == "boss" else 1.0))
					m.frozen = float(m.stun)
		"blind":
			for m: Dictionary in near:
				if not m.has("kit"):
					m.stun = maxf(float(m.get("stun", 0.0)), float(spec.get("daze", 4)) * (0.35 if m.kind == "boss" else 1.0))
		"explosion":
			for m: Dictionary in near:
				g._damage_mob(m, ((m.p as Vector2) - point).normalized() * 500.0, float(spec.get("damage", 12)) * ds * per)
			if g.feel != null:
				g.feel.on_blast(point, radius, "fire")
		"aftershock":
			for j in range(3):
				var spot := point + Vector2.from_angle(TAU * j / 3.0) * 34.0 * k
				for m: Dictionary in g.mobs:
					if m.spawn <= 0.0 and (m.p as Vector2).distance_to(spot) <= float(spec.get("radius", 50)) * k + m.r:
						g._damage_mob(m, ((m.p as Vector2) - spot).normalized() * 300.0, float(spec.get("damage", 3)) * ds * per)
				if g.feel != null:
					g.feel.on_blast(spot, float(spec.get("radius", 50)) * k, "fire")
		"chainlight":
			var from_p := point
			for j in range(mini(4, near.size())):
				var m: Dictionary = near[j]
				g._damage_mob(m, Vector2.ZERO, float(spec.get("damage", 4)) * ds * per)
				g.fx.append({"kind": "bolt", "p": from_p, "q": (m.p as Vector2) - Vector2(0, m.cy), "t": 0.3, "max": 0.3})
				from_p = (m.p as Vector2) - Vector2(0, m.cy)
		_:
			note(g, "Der Trank zerplatzt wirkungslos.")


## Thrown fire and poison: pools that burn or poison the enemies standing in them.
static func update_pools(g: Node, dt: float) -> void:
	var pools: Array = g.state.get("hzones", [])
	for z: Dictionary in pools:
		z.t = float(z.t) - dt
		for m: Dictionary in g.mobs:
			if m.spawn <= 0.0 and (m.p as Vector2).distance_to(z.p) < float(z.r) + m.r:
				HeroKit.burn_mob(m, float(z.dps), 1.0)
				if str(z.kind) == "poison":
					m.poisoned = 1.0
				else:
					m.burning = 1.0
	g.state.hzones = pools.filter(func(z: Dictionary) -> bool: return float(z.t) > 0.0)


## The weapon in hand drawn by the hero: its sprite replaces the class weapon's
## (not for a subclass with its own weapon look).
static func equip_look(g: Node) -> void:
	var w := _held(g)
	if w.is_empty() or g.sub_kit.has("weapon"):
		return
	var path := sprite_of(g, w)
	if ResourceLoader.exists(path):
		g.weapon_tex = load(path)


# ---------- drawing ----------

## Loot on the floor (bobbing, rarity glow) and the thrown pools.
static func draw(g: Node, l: CanvasItem, t: float) -> void:
	if inv(g).is_empty():
		return
	for z: Dictionary in g.state.get("hzones", []):
		var c := Color(0.55, 0.9, 0.35) if str(z.kind) == "poison" else Color(1.0, 0.55, 0.25)
		var a := clampf(float(z.t), 0.0, 1.0)
		l.draw_circle(z.p, float(z.r), Color(c, 0.25 * a))
		for i in range(6):
			var q: Vector2 = z.p + Vector2(cos(i * 1.1 + t * 1.3), sin(i * 1.7 + t)) * float(z.r) * 0.6
			l.draw_circle(q, 7.0, Color(c.lightened(0.3), 0.6 * a))
	for it: Dictionary in inv(g).ground:
		var item: Dictionary = it.item
		var tex := texture_of(g, item)
		var bob := sin(t * 3.0 + float(it.p.x)) * 6.0
		var c := color_of(item)
		l.draw_circle(it.p, 26.0, Color(c, 0.25 + 0.1 * sin(t * 4.0)))
		if tex != null:
			var size := tex.get_size() * 3.0
			l.draw_texture_rect(tex, Rect2((it.p as Vector2) - Vector2(size.x / 2.0, size.y + 6.0 + bob), size), false)
