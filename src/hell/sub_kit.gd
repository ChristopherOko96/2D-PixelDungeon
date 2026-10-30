extends RefCounted
## The six further subclasses of the Frostgruft (assets/data/frost_talents.json):
## Frostmagier, Nekromant, Tankkrieger, Axtkrieger, Schattenläufer and
## Tierbändiger. Each brings its own attack (shot or melee), four skills on keys
## 1-4 and two master skills on key 5, all built from a few data-driven building
## blocks (do: shot, wall, zone, nova, summon, buff, corpse, harvest, taunt, leap,
## stealth, step, trap, rally). Talent nodes with "mod" change a skill's values.
## Works on the game (src/hell/hell_game.gd) like hero_kit.gd and relic_kit.gd;
## an empty game.sub_kit means the standard subclass with the class skills.

const HeroKit = preload("res://src/hell/hero_kit.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")
const HERO := "res://assets/sprites/0x72/%s_%s_anim_f%d.png"
const WEAPON := "res://assets/sprites/0x72/%s.png"
## Most corpses the necromancer keeps track of.
const CORPSE_CAP := 10
## Seconds between two heals from hit chances (blood rush, blood god).
const HEAL_GAP := 0.6


# ---------- the run's kit ----------

## The subclass kit a run starts with: the data with the tree's mods applied and
## its master skills by id; {} for the standard subclass or without talents.
static func build(d: Dictionary, talent: Dictionary, class_id: String) -> Dictionary:
	if d.is_empty() or talent.is_empty() or not (d.classes as Dictionary).has(class_id):
		return {}
	var cls: Dictionary = d.classes[class_id]
	var sub := str(talent.get("sub", ""))
	var raw: Dictionary = cls.subs.get(sub, {})
	if sub == str(cls.standard) or not raw.has("attack"):
		return {}
	var kit: Dictionary = raw.duplicate(true)
	kit.id = sub
	kit.base_damage = float(raw.attack.damage)
	for s: Dictionary in kit.skills:
		s.count0 = int(s.get("count", 1))
	for m: Dictionary in talent.get("mods", []):
		var parts := str(m.to).split(".")
		if parts.size() < 2:
			continue
		var into: Dictionary = kit.attack if parts[0] == "attack" else _skill_by_id(kit, parts[0])
		if into.is_empty():
			continue
		into[parts[1]] = (float(into.get(parts[1], 0.0)) + float(m.get("add", 0.0))) * (1.0 + float(m.get("mul", 0.0)))
	var masters := {}
	for t: Array in kit.tiers:
		for n: Dictionary in t:
			if n.has("do"):
				masters[str(n.id)] = n
	kit.masters = masters
	return kit


static func _skill_by_id(kit: Dictionary, id: String) -> Dictionary:
	for s: Dictionary in kit.skills:
		if str(s.id) == id:
			return s
	return {}


## Puts the run's subclass in the hero's hands: look, weapon (the attack's values,
## so state.dmg and the cooldown follow it) and the skills on keys 1-4.
static func apply(g: Node, talent: Dictionary) -> void:
	var kit := build(g.meta_data, talent, g.class_id)
	g.sub_kit = kit
	g.weapon = (g.hero.get("weapon", {}) as Dictionary).duplicate(true)
	var sprite := str(g.hero.get("sprite", "knight_m"))
	if kit.is_empty():
		g.skills = HeroKit.load_skills(g, g.class_id)
	else:
		var atk: Dictionary = kit.attack
		sprite = str(kit.sprite)
		g.weapon.name = str(atk.name)
		g.weapon.damage = float(kit.base_damage)
		g.weapon.cooldown = float(atk.cooldown)
		if str(atk.do) == "melee":
			g.weapon.type = "melee"
			g.weapon.reach = float(atk.reach)
			g.weapon.arc = float(atk.arc)
		else:
			g.weapon.type = "projectile"
			g.weapon.shot = str(atk.kind)
			g.weapon.speed = float(atk.speed)
			g.weapon.life = float(atk.life)
			g.weapon.splash = 0.0
		if kit.has("weapon"):
			g.weapon.sprite = str(kit.weapon)
		g.skills = kit.skills
		kit.tex = {"axe": load(WEAPON % "weapon_axe"), "knife": load(WEAPON % "weapon_knife")}
		for n: Dictionary in (kit.masters as Dictionary).values():
			if str(n.get("buff", "")) == "transform":
				kit.ogre = _frames(str(n.sprite))
	if g.weapon.has("sprite"):
		g.weapon_tex = load(WEAPON % str(g.weapon.sprite))
	g.hero_frames = _frames(sprite)


static func _frames(sprite: String) -> Dictionary:
	var out := {}
	for kind in ["idle", "run"]:
		var frames: Array = []
		for f in range(4):
			frames.append(load(HERO % [sprite, kind, f]))
		out[kind] = frames
	return out


## A running buff's data (its skill), or {} when it is not active.
static func on(g: Node, id: String) -> Dictionary:
	var b: Dictionary = g.state.get("sbuff", {}).get(id, {})
	return b.s if not b.is_empty() and float(b.t) > 0.0 else {}


## Cooldown factor of the attack (blood rush, frenzy).
static func rate_scale(g: Node) -> float:
	return 1.0 / (1.0 + float(on(g, "bloodrush").get("rate", 0.0)) + float(on(g, "frenzy").get("rate", 0.0)))


## Damage factor on an enemy: frenzy and beast form, taunted enemies take more.
static func factor(g: Node, m: Dictionary) -> float:
	if g.sub_kit.is_empty():
		return 1.0
	var f := 1.0 + float(on(g, "frenzy").get("damage", 0.0)) + float(on(g, "transform").get("damage", 0.0))
	if float(m.get("vuln_t", 0.0)) > 0.0:
		f *= 1.0 + float(m.get("vuln", 0.0))
	return f


# ---------- attack ----------

## The subclass attack instead of the class weapon's; true when it handled the shot.
static func attack(g: Node, dir: Vector2) -> bool:
	var kit: Dictionary = g.sub_kit
	if kit.is_empty():
		return false
	var atk: Dictionary = kit.attack
	g.state.cool = float(atk.cooldown) * CardKit.rate_mult(g) * rate_scale(g)
	var mult: float = float(atk.damage) / g.base_damage()
	var from := Vector2(g.player.x, g.player.y - 40)
	if str(atk.do) == "shot":
		var kind := str(atk.kind)
		g.shots.append({"p": from, "v": dir * float(atk.speed), "t": float(atk.life), "kind": "arrow" if kind == "arrow" else "sub_" + kind,
			"mult": mult, "hits": [], "fx": atk})
		g._sound("shot_arrow" if kind == "arrow" else "shot_magic")
		return true
	var reach := float(atk.reach) * (1.0 + float(on(g, "transform").get("reach", 0.0)))
	var half := float(atk.arc) / 2.0
	# the first stab out of hiding (TARNUNG) hits several times as hard
	var ambush := float(g.state.get("ambush", 0.0)) if float(g.state.get("stealth", 0.0)) > 0.0 else 0.0
	g.swing = {"a": dir.angle(), "t": 0.16}
	for m: Dictionary in g.mobs:
		var to: Vector2 = m.p - Vector2(0, m.cy) - from
		if m.spawn > 0.0 or to.length() >= reach + m.r or absf(angle_difference(dir.angle(), to.angle())) > half:
			continue
		var f := mult
		if atk.has("backstab") and ((m.face as Vector2).dot(to.normalized()) > 0.2 or float(m.get("stun", 0.0)) > 0.0):
			f *= float(atk.backstab)
		if ambush > 0.0:
			f *= ambush
		if g._damage_mob(m, dir * float(atk.get("push", 300.0)), f):
			hit(g, m, atk)
	for e: Dictionary in g.breakables:
		var to := Vector2(e.x, e.y - 40) - from
		if not e.get("broken", false) and to.length() < reach + 40.0 and absf(angle_difference(dir.angle(), to.angle())) <= half:
			g._hit_breakable(e, Vector2(e.x, e.y - 40))
	if ambush > 0.0:
		g.state.stealth = 0.0
		g.state.ambush = 0.0
	g._sound("swing")
	return true


## On-hit effects of the attack or a shot (src: its data) and of running buffs.
static func hit(g: Node, m: Dictionary, src: Dictionary) -> void:
	if src.has("stun"):
		m.stun = maxf(float(m.get("stun", 0.0)), float(src.stun))
	if src.has("slow"):
		HeroKit.slow_mob(g, m, float(src.slow), float(src.get("slow_time", 1.0)))
	if src.has("bleed"):
		HeroKit.burn_mob(m, float(src.bleed), float(src.get("bleed_time", 2.0)))
	var every := int(src.get("heal_every", 0))
	if every > 0:
		g.state.sub_hits = int(g.state.get("sub_hits", 0)) + 1
		if int(g.state.sub_hits) % every == 0:
			heal(g, 1)
	var poison := on(g, "poison")
	if not poison.is_empty():
		HeroKit.burn_mob(m, float(poison.dps), float(poison.poison_time))
	var chance := float(on(g, "bloodrush").get("heal_chance", 0.0)) + float(on(g, "bloodgod").get("heal_chance", 0.0))
	if chance > 0.0 and float(g.state.get("heal_cd", 0.0)) <= 0.0 and randf() < chance:
		g.state.heal_cd = HEAL_GAP
		heal(g, 1)
	var god := on(g, "bloodgod")
	if not god.is_empty() and src.has("bleed"):
		# the blood god: bleeding jumps to the enemies close by
		for o: Dictionary in g.mobs:
			if o != m and (o.p as Vector2).distance_to(m.p) < float(god.spread):
				HeroKit.burn_mob(o, float(src.bleed), float(src.get("bleed_time", 2.0)))


## Gives the hero half hearts back.
static func heal(g: Node, n: int) -> void:
	if n <= 0:
		return
	g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + n)
	g.fx.append({"kind": "sub_heal", "p": Vector2(g.player.x, g.player.y - 40), "t": 0.6, "max": 0.6})


## Freezes (or roots) an enemy in place; kit bosses shrug it off, guardians feel half.
static func freeze(g: Node, m: Dictionary, time: float, root := false) -> void:
	if m.has("kit") or time <= 0.0:
		return
	var tm := time * (0.5 if m.kind == "boss" else 1.0)
	m.stun = maxf(float(m.get("stun", 0.0)), tm)
	var key := "rooted" if root else "frozen"
	m[key] = maxf(float(m.get(key, 0.0)), tm)


# ---------- skills 1-4 and the master skill ----------

## Key press of a subclass skill; false when no subclass kit is active.
static func press(g: Node, key: String) -> bool:
	if g.sub_kit.is_empty():
		return false
	for s: Dictionary in g.skills:
		if str(s.key) != key:
			continue
		if int(g.state.level) < int(s.unlock):
			g._toast("%s ab Level %d." % [s.name, int(s.unlock)])
			return true
		if float(g.state.skill_cd.get(key, 0.0)) > 0.0:
			g._sound("no_cooldown")
			return true
		if cast(g, s):
			g.state.skill_cd[key] = float(s.cooldown)
		return true
	return false


## Key 5 with a subclass master skill; false when the master belongs to the class skills.
static func master(g: Node) -> bool:
	var kit: Dictionary = g.sub_kit
	var id := str(g.state.get("talent", {}).get("master", ""))
	if kit.is_empty() or not (kit.masters as Dictionary).has(id):
		return false
	if float(g.state.skill_cd.get("5", 0.0)) > 0.0:
		g._sound("no_cooldown")
		return true
	if cast(g, kit.masters[id]):
		g.state.skill_cd["5"] = float(g.theme.get("master_cooldown", 45.0))
	return true


## Runs one building block; false when it found nothing to work on (no cooldown then).
static func cast(g: Node, s: Dictionary) -> bool:
	if not g.state.has("sbuff"):
		g.state.sbuff = {}
	var at := HeroKit.target(g)
	var me := Vector2(g.player.x, g.player.y)
	var aim := HeroKit._aim(g)
	match str(s.do):
		"shot":
			var n := int(s.get("count", 1))
			for k in range(n):
				var a := aim.angle() + ((float(k) / (n - 1) - 0.5) * float(s.get("spread", 0.3)) if n > 1 else 0.0)
				g.shots.append({"p": me - Vector2(0, 40), "v": Vector2(cos(a), sin(a)) * float(s.speed), "t": float(s.life), "life": float(s.life),
					"kind": "sub_" + str(s.kind), "mult": float(s.damage), "hits": [], "fx": s, "pierce": bool(s.get("pierce", false)),
					"boomerang": float(s.get("back", 0.0)) > 0.0, "seek": bool(s.get("home", false)), "big": 1.5})
			g._sound_raw("attack_arrow" if str(s.kind) == "hawk" else "swing")
		"wall":
			var side := Vector2(-aim.y, aim.x) * float(s.length) / 2.0
			g.gwalls.append({"a": at - side, "b": at + side, "t": float(s.time), "max": float(s.time), "w": float(s.get("thickness", 34.0)), "ice": true})
			g._sound_raw("void_burst")
		"zone":
			var follow := bool(s.get("on_hero", false))
			g.zones.append({"kind": "sub_zone", "p": me if follow else at, "r": float(s.radius), "t": float(s.time), "max": float(s.time),
				"every": float(s.every), "tick": 0.0, "dmg": float(s.damage), "slow": float(s.slow), "freeze_after": float(s.get("freeze_after", 0.0)), "follow": follow})
			g._sound_raw("windup_beam")
		"nova":
			for m: Dictionary in g.mobs:
				if m.spawn <= 0.0 and (m.p as Vector2).distance_to(me) < float(s.radius) + m.r:
					g._damage_mob(m, ((m.p as Vector2) - me).normalized() * 400.0, float(s.damage))
					freeze(g, m, float(s.get("freeze", 0.0)))
					if s.has("stun"):
						m.stun = maxf(float(m.get("stun", 0.0)), float(s.stun))
			var shards := int(s.get("shards", 0))
			for k in range(shards):
				var a := TAU * k / shards
				g.shots.append({"p": me - Vector2(0, 40), "v": Vector2(cos(a), sin(a)) * 760.0, "t": 0.6, "kind": "sub_ice", "mult": 0.8, "hits": [],
					"fx": {"slow": 0.3, "slow_time": 1.0}})
			var ice := s.has("freeze")
			g.fx.append({"kind": "sub_ring", "p": me - Vector2(0, 20), "r": float(s.radius), "t": 0.45, "max": 0.45,
				"c": Color(0.7, 0.9, 1.0) if ice else Color(0.85, 0.65, 0.4)})
			g._sound("blast")
		"summon":
			_summon(g, s, me)
		"buff":
			g.state.sbuff[str(s.buff)] = {"t": float(s.time), "s": s, "n": 0, "hits": int(s.get("hits", 0)), "acc": 0.0}
			g._burst(me - Vector2(0, 40), 24, true)
			g._sound_raw("attack_roar" if str(s.buff) in ["transform", "frenzy", "bloodgod", "bloodrush"] else "void_burst")
		"corpse":
			var corpses: Array = g.state.get("corpses", [])
			var near := corpses.filter(func(c: Dictionary) -> bool: return (c.p as Vector2).distance_to(at) < 420.0)
			if near.is_empty():
				g._toast("Keine Leiche in der Nähe des Ziels.")
				return false
			near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.p as Vector2).distance_to(at) < (b.p as Vector2).distance_to(at))
			_explode(g, near[0], s)
			for k in range(mini(int(s.get("chain", 0)), near.size() - 1)):
				_queue(g, {"do": "corpse", "t": 0.25 * (k + 1), "c": near[k + 1], "s": s})
		"harvest":
			var souls := 0
			for m: Dictionary in g.mobs:
				if m.spawn <= 0.0 and (m.p as Vector2).distance_to(me) < float(s.radius) + m.r:
					g._damage_mob(m, Vector2.ZERO, float(s.damage))
					g.fx.append({"kind": "bolt", "p": (m.p as Vector2) - Vector2(0, m.cy), "q": me - Vector2(0, 40), "t": 0.35, "max": 0.35})
					souls += 1
			heal(g, int(float(souls) / maxf(1.0, float(s.heal_per))))
			g.fx.append({"kind": "sub_ring", "p": me - Vector2(0, 20), "r": float(s.radius), "t": 0.5, "max": 0.5, "c": Color(0.7, 0.5, 1.0)})
			g._sound_raw("void_burst")
		"taunt":
			for m: Dictionary in g.mobs:
				var to: Vector2 = me - m.p
				if m.spawn > 0.0 or to.length() > float(s.radius) + m.r:
					continue
				if not m.has("kit") and m.kind != "boss" and to.length() > 70.0:
					m.p += to.normalized() * minf(float(s.pull), to.length() - 70.0)
				m.vuln = float(s.vuln)
				m.vuln_t = float(s.time)
			g.fx.append({"kind": "sub_ring", "p": me - Vector2(0, 20), "r": float(s.radius), "t": 0.5, "max": 0.5, "c": Color(1.0, 0.8, 0.35)})
			g._sound_raw("attack_roar")
		"leap":
			var dist := minf(float(s.distance), (me - Vector2(0, 40)).distance_to(at))
			g.dash = {"dir": aim, "speed": dist / 0.35, "t": 0.35, "mult": 0.0, "hit": [], "land": "sub_leap"}
			g.state.sub_leap = s
			g.state.inv = maxf(float(g.state.inv), 0.5)
			g._sound_raw("step")
		"stealth":
			g.state.stealth = float(s.time)
			g.state.ambush = float(s.ambush)
			g._burst(me - Vector2(0, 40), 20)
			# he melts into a shadow on the floor
			g.shadow_at(me, 6, 40.0)
			g._sound_raw("void_burst")
		"step":
			var near: Array = g.mobs.filter(func(m: Dictionary) -> bool: return m.spawn <= 0.0 and (m.p as Vector2).distance_to(me) < float(s.range))
			if near.is_empty():
				g._toast("Kein Gegner in Reichweite.")
				return false
			near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.p as Vector2).distance_to(at) < (b.p as Vector2).distance_to(at))
			var hits := int(s.hits)
			for k in range(hits):
				_queue(g, {"do": "step", "t": float(s.every) * k, "m": near[k % near.size()], "s": s})
			g.state.inv = maxf(float(g.state.inv), float(s.every) * hits + 0.2)
			if s.has("stealth"):
				g.state.stealth = float(s.stealth)
			g._sound_raw("void_burst")
		"trap":
			g.zones.append({"kind": "sub_trap", "p": at, "r": float(s.radius), "t": float(s.time), "max": float(s.time), "dmg": float(s.damage), "root": float(s.root)})
			g._sound_raw("step")
		"rally":
			g.state.sbuff.rally = {"t": float(s.time), "s": s, "n": 0}
			for a: Dictionary in g.allies:
				if a.has("sub"):
					g._burst((a.p as Vector2) - Vector2(0, 30), 10, true)
			g._sound_raw("attack_roar")
	return true


## Calls up allies; older ones of the same kind crumble when the cap is reached.
static func _summon(g: Node, s: Dictionary, me: Vector2) -> void:
	var n := int(s.get("count", 1))
	var cap := int(s.get("cap", n)) + n - int(s.get("count0", n))
	var same: Array = g.allies.filter(func(a: Dictionary) -> bool: return a.has("sub") and float(a.t) > 0.0 and str(a.s.id) == str(s.id))
	while same.size() + n > cap and not same.is_empty():
		var old: Dictionary = same.pop_front()
		old.t = 0.0
	var face := float(g.player.face)
	for k in range(n):
		var off := Vector2(face * 90.0, 0) + Vector2(cos(k * 2.4), sin(k * 2.4)) * (0.0 if n == 1 else 60.0)
		g.allies.append({"sub": true, "p": me + off, "t": float(s.time), "max": float(s.time), "dmg": float(s.damage), "cool": 0.4,
			"face": face, "rise": 0.5, "slam": 0.0, "tick": 0.0, "heal_t": 4.0, "seed": randf() * 9.0, "s": s})
	g._burst(me - Vector2(0, 30) + Vector2(face * 90.0, 0), 40, true)
	g._sound_raw("attack_summon")


static func _queue(g: Node, p: Dictionary) -> void:
	if not g.state.has("sub_q"):
		g.state.sub_q = []
	g.state.sub_q.append(p)


static func _explode(g: Node, c: Dictionary, s: Dictionary) -> void:
	var corpses: Array = g.state.get("corpses", [])
	corpses.erase(c)
	RelicKit._area(g, c.p, float(s.radius), float(s.damage), 0.0)
	g.fx.append({"kind": "sub_ring", "p": c.p, "r": float(s.radius), "t": 0.4, "max": 0.4, "c": Color(0.65, 0.4, 1.0)})
	g._burst((c.p as Vector2) - Vector2(0, 20), 30, true)
	g._sound("blast")


## A leap (BOLLWERK-SPRUNG) ends: blow and stun around the landing point.
static func land(g: Node, what: String) -> void:
	if what != "sub_leap":
		return
	var s: Dictionary = g.state.get("sub_leap", {})
	var at := Vector2(g.player.x, g.player.y)
	RelicKit._area(g, at, float(s.radius), float(s.damage), 0.0)
	for m: Dictionary in g.mobs:
		if at.distance_to(m.p) < float(s.radius) + m.r:
			m.stun = maxf(float(m.get("stun", 0.0)), float(s.stun))
	g.fx.append({"kind": "sub_ring", "p": at, "r": float(s.radius), "t": 0.4, "max": 0.4, "c": Color(1.0, 0.85, 0.5)})
	g._sound("blast")


# ---------- hits on the hero ----------

## Called before the hero loses a half heart: true when a shield, the fortress,
## vengeance or the iron will took the hit.
static func guard(g: Node) -> bool:
	if g.sub_kit.is_empty():
		return false
	var buffs: Dictionary = g.state.get("sbuff", {})
	var inv := float(g.balance.player.invulnerable)
	if not on(g, "fortress").is_empty():
		return true
	if not on(g, "vengeance").is_empty():
		buffs.vengeance.n = int(buffs.vengeance.n) + 1
		g.state.inv = inv
		return true
	if not on(g, "absorb").is_empty() and int(buffs.absorb.hits) > 0:
		buffs.absorb.hits = int(buffs.absorb.hits) - 1
		if int(buffs.absorb.hits) <= 0:
			buffs.erase("absorb")
		g.state.inv = inv
		g._burst(Vector2(g.player.x, g.player.y - 40), 14)
		g._sound("block")
		return true
	if not on(g, "block_front").is_empty():
		var me := Vector2(g.player.x, g.player.y)
		var aim: Vector2 = g.player.get("aim", Vector2(float(g.player.face), 0))
		for m: Dictionary in g.mobs:
			var to: Vector2 = (m.p as Vector2) - me
			if to.length() < 170.0 + m.r and to.normalized().dot(aim) > 0.0:
				g.state.inv = inv
				g._sound("block")
				return true
	var red := on(g, "reduce")
	if not red.is_empty():
		buffs.reduce.acc = float(buffs.reduce.acc) + float(red.value)
		if float(buffs.reduce.acc) >= 1.0:
			buffs.reduce.acc = float(buffs.reduce.acc) - 1.0
			g.state.inv = inv
			return true
	return false


## Where an enemy runs: to a taunting ally close by, else to the hero.
static func chase(g: Node, m: Dictionary, me: Vector2) -> Vector2:
	if m.kind == "boss":
		return me
	for a: Dictionary in g.allies:
		if a.has("sub") and bool(a.s.get("taunt", false)) and float(a.rise) <= 0.0 and (a.p as Vector2).distance_to(m.p) < 700.0:
			return a.p
	return me


## A felled enemy leaves a corpse for the necromancer.
static func on_kill(g: Node, m: Dictionary) -> void:
	var kit: Dictionary = g.sub_kit
	if kit.is_empty() or not (kit.skills as Array).any(func(s: Dictionary) -> bool: return str(s.do) == "corpse"):
		return
	if not g.state.has("corpses"):
		g.state.corpses = []
	g.state.corpses.append({"p": m.p, "t": 15.0})
	if g.state.corpses.size() > CORPSE_CAP:
		g.state.corpses.pop_front()


# ---------- per frame ----------

static func update(g: Node, dt: float) -> void:
	if g.sub_kit.is_empty():
		return
	if not g.state.has("sbuff"):
		g.state.sbuff = {}
	var buffs: Dictionary = g.state.sbuff
	for id: String in buffs.keys():
		var b: Dictionary = buffs[id]
		b.t = float(b.t) - dt
		if float(b.t) <= 0.0:
			buffs.erase(id)
			if id == "vengeance":
				_vengeance(g, b)
	g.state.heal_cd = maxf(0.0, float(g.state.get("heal_cd", 0.0)) - dt)
	_update_queue(g, dt)
	_update_zones(g, dt)
	_update_shots(g, dt)
	_update_guard(g)
	for m: Dictionary in g.mobs:
		for k: String in ["frozen", "rooted", "vuln_t"]:
			if m.has(k):
				m[k] = maxf(0.0, float(m[k]) - dt)
	var corpses: Array = g.state.get("corpses", [])
	for c: Dictionary in corpses:
		c.t = float(c.t) - dt
	g.state.corpses = corpses.filter(func(c: Dictionary) -> bool: return float(c.t) > 0.0)
	_update_allies(g, dt)


## Vengeance ends: every stored hit comes back as a blast around the hero.
static func _vengeance(g: Node, b: Dictionary) -> void:
	var s: Dictionary = b.s
	var at := Vector2(g.player.x, g.player.y)
	RelicKit._area(g, at, float(s.radius), float(s.damage) * (1.0 + mini(int(b.n), 6)), 0.0)
	g.fx.append({"kind": "sub_ring", "p": at, "r": float(s.radius), "t": 0.5, "max": 0.5, "c": Color(1.0, 0.35, 0.3)})
	g._sound("blast")


static func _update_queue(g: Node, dt: float) -> void:
	var q: Array = g.state.get("sub_q", [])
	for p: Dictionary in q:
		p.t = float(p.t) - dt
		if float(p.t) > 0.0:
			continue
		var s: Dictionary = p.s
		match str(p.do):
			"step":
				var m: Dictionary = p.m
				if not g.mobs.has(m):
					continue
				var from := Vector2(g.player.x, g.player.y - 40)
				# the shadow he steps into and out of
				g.shadow_at(from + Vector2(0, 40))
				var behind: Vector2 = m.p - (m.face as Vector2) * 60.0
				if not g.box_blocked(g._player_box(behind.x, behind.y)):
					g.player.x = behind.x
					g.player.y = behind.y
				g.shadow_at(Vector2(g.player.x, g.player.y), 4, 24.0)
				g.fx.append({"kind": "blink", "p": from, "q": Vector2(g.player.x, g.player.y - 40), "t": 0.25, "max": 0.25})
				g._damage_mob(m, ((m.p as Vector2) - from).normalized() * 300.0, float(s.damage) * float(g.sub_kit.attack.get("backstab", 2.0)))
			"corpse":
				if (g.state.get("corpses", []) as Array).has(p.c):
					_explode(g, p.c, s)
	g.state.sub_q = q.filter(func(p: Dictionary) -> bool: return float(p.t) > 0.0)


## Blizzard and eternal winter (cold, slow, freeze after a while) and the traps.
static func _update_zones(g: Node, dt: float) -> void:
	for z: Dictionary in g.zones:
		match z.kind:
			"sub_zone":
				if z.follow:
					z.p = Vector2(g.player.x, g.player.y)
				z.tick = float(z.tick) - dt
				if float(z.tick) > 0.0:
					continue
				z.tick = float(z.every)
				for m: Dictionary in g.mobs:
					if m.spawn > 0.0 or (m.p as Vector2).distance_to(z.p) > float(z.r) + m.r:
						continue
					g._damage_mob(m, Vector2.ZERO, float(z.dmg))
					HeroKit.slow_mob(g, m, float(z.slow), float(z.every) + 0.2)
					if float(z.freeze_after) > 0.0:
						m.cold = float(m.get("cold", 0.0)) + float(z.every)
						if float(m.cold) >= float(z.freeze_after):
							m.cold = 0.0
							freeze(g, m, 1.0)
			"sub_trap":
				for m: Dictionary in g.mobs:
					if m.spawn <= 0.0 and (m.p as Vector2).distance_to(z.p) < float(z.r) + m.r:
						g._damage_mob(m, Vector2.ZERO, float(z.dmg))
						freeze(g, m, float(z.root), true)
						z.t = 0.0
						g._burst(z.p, 16)
						g._sound("block")
						break


## Seeking hawks and returning axes.
static func _update_shots(g: Node, dt: float) -> void:
	var me := Vector2(g.player.x, g.player.y - 40)
	for s: Dictionary in g.shots:
		var speed := (s.v as Vector2).length()
		if s.get("seek", false):
			var best: Dictionary = {}
			var bd := 700.0
			for m: Dictionary in g.mobs:
				var d := (s.p as Vector2).distance_to((m.p as Vector2) - Vector2(0, m.cy))
				if m.spawn <= 0.0 and d < bd and not (s.hits as Array).has(m):
					bd = d
					best = m
			if not best.is_empty():
				var want: Vector2 = (((best.p as Vector2) - Vector2(0, best.cy)) - s.p).normalized() * speed
				s.v = (s.v as Vector2).lerp(want, 1.0 - pow(0.02, dt))
		if s.get("boomerang", false) and not s.get("returning", false) and float(s.t) < float(s.life) * 0.5:
			s.returning = true
			s.hits = []
			s.t = float(s.life)
		if s.get("returning", false):
			s.v = (me - s.p).normalized() * speed
			if (s.p as Vector2).distance_to(me) < 50.0:
				s.t = 0.0


## The shield wall stops (or throws back) shots from the front; the fortress throws enemies off.
static func _update_guard(g: Node) -> void:
	var me := Vector2(g.player.x, g.player.y - 34)
	var block := on(g, "block_front")
	if not block.is_empty():
		var aim: Vector2 = g.player.get("aim", Vector2(float(g.player.face), 0))
		for s: Dictionary in g.eshots:
			if float(s.t) > 0.0 and (s.p as Vector2).distance_to(me) < 110.0 and ((s.p as Vector2) - me).normalized().dot(aim) > 0.0:
				s.t = 0.0
				g._burst(s.p, 6, true)
				if float(block.get("reflect", 0.0)) > 0.0:
					g.shots.append({"p": s.p, "v": -(s.v as Vector2), "t": 1.0, "kind": "", "mult": 1.5, "hits": []})
	if not on(g, "fortress").is_empty():
		for m: Dictionary in g.mobs:
			var to: Vector2 = (m.p as Vector2) - Vector2(g.player.x, g.player.y)
			if not m.has("kit") and m.kind != "boss" and to.length() < 110.0 + m.r:
				m.k = to.normalized() * 700.0


## Subclass allies: walk to the nearest enemy, strike (alone or in an area),
## shoot from afar; the forest keeper roots and heals where it stands.
static func _update_allies(g: Node, dt: float) -> void:
	var rally := on(g, "rally")
	var hero := Vector2(g.player.x, g.player.y)
	for a: Dictionary in g.allies:
		if not a.has("sub"):
			continue
		a.t = float(a.t) - dt
		a.rise = maxf(0.0, float(a.rise) - dt)
		a.slam = maxf(0.0, float(a.slam) - dt)
		a.cool = float(a.cool) - dt
		if float(a.rise) > 0.0:
			continue
		var s: Dictionary = a.s
		var dmg := float(a.dmg) * (1.0 + float(rally.get("damage", 0.0)))
		var speed := float(s.speed) * (1.0 + float(rally.get("speed", 0.0)))
		if float(s.get("root", 0.0)) > 0.0:
			a.tick = float(a.tick) - dt
			if float(a.tick) <= 0.0:
				a.tick = float(s.every)
				for m: Dictionary in g.mobs:
					if m.spawn <= 0.0 and (m.p as Vector2).distance_to(a.p) < float(s.radius) + m.r:
						g._damage_mob(m, Vector2.ZERO, dmg)
						freeze(g, m, float(s.root), true)
				g.fx.append({"kind": "sub_ring", "p": a.p, "r": float(s.radius), "t": 0.4, "max": 0.4, "c": Color(0.5, 0.9, 0.4)})
			a.heal_t = float(a.heal_t) - dt
			if float(a.heal_t) <= 0.0 and hero.distance_to(a.p) < float(s.radius) * 1.5:
				a.heal_t = 4.0
				heal(g, int(s.get("heal", 0)))
			continue
		var best: Dictionary = {}
		var bd := 900.0
		for m: Dictionary in g.mobs:
			if m.spawn <= 0.0 and (a.p as Vector2).distance_to(m.p) < bd:
				bd = (a.p as Vector2).distance_to(m.p)
				best = m
		var goal: Vector2 = best.p if not best.is_empty() else hero + Vector2(-float(g.player.face) * 90.0, 30.0)
		var to: Vector2 = goal - a.p
		var want := float(s.reach) * (0.7 if bool(s.get("ranged", false)) else 0.8) if not best.is_empty() else 100.0
		if to.length() > want and speed > 0.0:
			var step: Vector2 = to.normalized() * speed * dt
			if not g.box_blocked(Rect2(a.p.x + step.x - 20, a.p.y + step.y - 16, 40, 16), true):
				a.p += step
			elif not g.box_blocked(Rect2(a.p.x + step.x - 20, a.p.y - 16, 40, 16), true):
				a.p += Vector2(step.x, 0)
			elif not g.box_blocked(Rect2(a.p.x - 20, a.p.y + step.y - 16, 40, 16), true):
				a.p += Vector2(0, step.y)
		if absf(to.x) > 1.0:
			a.face = signf(to.x)
		if best.is_empty() or to.length() > float(s.reach) + float(best.r) or float(a.cool) > 0.0:
			continue
		a.cool = float(s.every)
		a.slam = 0.3
		if bool(s.get("ranged", false)):
			var ice := "ice" in str(s.sprite)
			var from: Vector2 = (a.p as Vector2) - Vector2(0, 50)
			var aim_to: Vector2 = (best.p as Vector2) - Vector2(0, best.cy)
			g.shots.append({"p": from, "v": (aim_to - from).normalized() * 720.0, "t": 1.0, "kind": "sub_ice" if ice else "fireball", "mult": dmg, "hits": [],
				"fx": {"slow": 0.3, "slow_time": 1.0} if ice else {"bleed": 0.5, "bleed_time": 2.0}})
		elif s.has("radius"):
			RelicKit._area(g, best.p, float(s.radius), dmg, 0.0)
			for m: Dictionary in g.mobs:
				if (m.p as Vector2).distance_to(best.p) < float(s.radius) + m.r:
					freeze(g, m, float(s.get("freeze", 0.0)))
			g.fx.append({"kind": "sub_ring", "p": best.p, "r": float(s.radius), "t": 0.3, "max": 0.3, "c": Color(0.7, 0.9, 1.0) if s.has("freeze") else Color(0.9, 0.75, 0.55)})
			g._sound_raw("attack_slam")
		else:
			g._damage_mob(best, ((best.p as Vector2) - (a.p as Vector2)).normalized() * 300.0, dmg)


# ---------- drawing ----------

## A subclass shot; false for shots of other kinds.
static func draw_shot(g: Node, l: Node2D, s: Dictionary, t: float) -> bool:
	var kit: Dictionary = g.sub_kit
	var a := (s.v as Vector2).angle()
	match str(s.get("kind", "")):
		"sub_ice":
			var d := Vector2(cos(a), sin(a))
			var n := Vector2(-d.y, d.x)
			l.draw_circle(s.p, 16.0, Color(0.6, 0.85, 1.0, 0.3))
			l.draw_colored_polygon(PackedVector2Array([s.p + d * 20.0, s.p + n * 7.0, s.p - d * 14.0, s.p - n * 7.0]), Color(0.85, 0.97, 1.0))
		"sub_soul":
			l.draw_circle(s.p - (s.v as Vector2).normalized() * 18.0, 10.0, Color(0.5, 0.3, 0.9, 0.35))
			l.draw_circle(s.p, 15.0, Color(0.55, 0.35, 1.0, 0.5))
			l.draw_circle(s.p, 7.0, Color(0.9, 0.85, 1.0))
		"sub_axe", "sub_knife":
			var im: Texture2D = kit.get("tex", {}).get("axe" if s.kind == "sub_axe" else "knife")
			if im == null:
				return false
			var size := im.get_size() * 2.4
			l.draw_set_transform(s.p, t * 14.0 if s.kind == "sub_axe" else a + PI / 2.0)
			l.draw_texture_rect(im, Rect2(-size / 2.0, size), false)
			l.draw_set_transform(Vector2.ZERO)
		"sub_hawk":
			l.draw_circle(s.p, 20.0, Color(1.0, 0.8, 0.35, 0.3))
			if g.arrow_tex != null:
				var asz: Vector2 = g.arrow_tex.get_size() * 3.6
				l.draw_set_transform(s.p, a + PI / 2.0)
				l.draw_texture_rect(g.arrow_tex, Rect2(-asz / 2.0, asz), false, Color(1.0, 0.85, 0.4))
				l.draw_set_transform(Vector2.ZERO)
		_:
			return false
	return true


## Subclass effects in the world: blizzards, traps, corpses, frozen and rooted
## enemies, the hero's buffs, the allies and the rings of novas and blasts.
static func draw(g: Node, l: Node2D, t: float) -> void:
	if g.sub_kit.is_empty():
		return
	var hero := Vector2(g.player.x, g.player.y)
	for z: Dictionary in g.zones:
		match z.kind:
			"sub_zone":
				if not z.follow:
					l.draw_circle(z.p, float(z.r), Color(0.6, 0.8, 1.0, 0.16))
					l.draw_arc(z.p, float(z.r), 0.0, TAU, 40, Color(0.8, 0.92, 1.0, 0.5), 3.0)
				var spread := float(z.r) if not z.follow else 700.0
				for i in range(30 if z.follow else 18):
					var fall := fmod(t * 0.7 + i * 0.137, 1.0)
					var q: Vector2 = z.p + Vector2(fmod(i * 173.0, 2.0 * spread) - spread + fall * 120.0, (fall - 0.5) * 2.0 * spread * (0.55 if z.follow else 0.8))
					l.draw_circle(q, 4.0, Color(0.95, 0.98, 1.0, 0.85))
			"sub_trap":
				var trap: Texture2D = g.tex.get("spike_trap")
				if trap != null:
					l.draw_texture_rect(trap, Rect2(z.p - trap.get_size() / 2.0, trap.get_size()), false, Color(1, 1, 1, 0.9))
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 24, Color(0.9, 0.8, 0.5, 0.35), 2.0)
	for c: Dictionary in g.state.get("corpses", []):
		l.draw_circle(c.p, 16.0, Color(0.15, 0.08, 0.2, 0.45))
		l.draw_circle((c.p as Vector2) - Vector2(0, 14.0 + 6.0 * sin(t * 3.0 + c.p.x)), 6.0, Color(0.7, 0.5, 1.0, 0.6))
	for m: Dictionary in g.mobs:
		var mid: Vector2 = (m.p as Vector2) - Vector2(0, m.cy)
		if float(m.get("frozen", 0.0)) > 0.0:
			l.draw_circle(mid, float(m.r) * 1.2 + 6.0, Color(0.65, 0.88, 1.0, 0.38))
			l.draw_arc(mid, float(m.r) * 1.2 + 6.0, 0.0, TAU, 24, Color(0.9, 0.97, 1.0, 0.8), 3.0)
		if float(m.get("rooted", 0.0)) > 0.0:
			for i in range(3):
				l.draw_arc(m.p, float(m.r) * (0.7 + i * 0.25), PI * 0.1 + i, PI * 0.9 + i, 10, Color(0.4, 0.75, 0.3, 0.9), 4.0)
		if float(m.get("vuln_t", 0.0)) > 0.0:
			l.draw_arc(mid, float(m.r) + 10.0, 0.0, TAU, 20, Color(1.0, 0.8, 0.35, 0.6), 2.0)
	var buffs: Dictionary = g.state.get("sbuff", {})
	var chest := hero - Vector2(0, 40)
	if buffs.has("absorb"):
		for i in range(int(buffs.absorb.hits)):
			var a := t * 3.0 + i * TAU / maxf(1.0, float(buffs.absorb.hits))
			l.draw_circle(chest + Vector2(cos(a), sin(a)) * 62.0, 8.0, Color(0.93, 0.9, 0.82))
	if buffs.has("block_front"):
		var aim: Vector2 = g.player.get("aim", Vector2(float(g.player.face), 0))
		l.draw_arc(chest, 72.0, aim.angle() - 1.2, aim.angle() + 1.2, 18, Color(1.0, 0.85, 0.4, 0.85), 10.0)
	if buffs.has("fortress"):
		l.draw_arc(chest, 84.0 + 4.0 * sin(t * 8.0), 0.0, TAU, 40, Color(1.0, 0.85, 0.35, 0.9), 8.0)
	if buffs.has("vengeance"):
		l.draw_arc(chest, 60.0 + 10.0 * int(buffs.vengeance.n), 0.0, TAU, 40, Color(1.0, 0.3, 0.25, 0.8), 6.0)
	if buffs.has("reduce"):
		l.draw_arc(chest, 70.0, 0.0, TAU, 40, Color(0.75, 0.8, 0.9, 0.6), 4.0)
	for id: String in ["bloodrush", "frenzy", "bloodgod", "transform"]:
		if buffs.has(id):
			l.draw_circle(hero, 56.0, Color(0.9, 0.15, 0.15, 0.22))
	if buffs.has("poison"):
		for i in range(5):
			var q := chest + Vector2(cos(t * 2.0 + i * 1.3) * 34.0, -fmod(t * 40.0 + i * 17.0, 60.0) + 20.0)
			l.draw_circle(q, 5.0, Color(0.45, 0.9, 0.3, 0.75))
	for a: Dictionary in g.allies:
		if a.has("sub"):
			_draw_ally(g, l, a, t, not buffs.get("rally", {}).is_empty())
	for f: Dictionary in g.fx:
		var k: float = float(f.t) / maxf(0.01, float(f.max))
		match f.kind:
			"sub_ring":
				var c: Color = f.c
				l.draw_circle(f.p, float(f.r) * (1.0 - k * 0.4), Color(c, 0.18 * k))
				l.draw_arc(f.p, float(f.r) * (1.1 - k * 0.3), 0.0, TAU, 40, Color(c, k), 8.0)
			"sub_heal":
				for i in range(6):
					var q: Vector2 = f.p + Vector2(cos(i * 1.05) * 30.0, -(1.0 - k) * 50.0 + sin(i * 2.0) * 10.0)
					l.draw_rect(Rect2(q - Vector2(3, 8), Vector2(6, 16)), Color(0.5, 1.0, 0.5, k))
					l.draw_rect(Rect2(q - Vector2(8, 3), Vector2(16, 6)), Color(0.5, 1.0, 0.5, k))


static func _draw_ally(g: Node, l: Node2D, a: Dictionary, t: float, rallied: bool) -> void:
	var s: Dictionary = a.s
	var im: Texture2D
	var size_k := float(s.scale)
	var tint := Color(1, 1, 1, clampf(float(a.t), 0.0, 1.0))
	if str(s.sprite) == "hero":
		im = g.hero_frames.run[int(t * 10.0 + float(a.seed)) % 4]
		size_k *= float(g.theme.hero_scale)
		var c: Array = s.get("tint", [0.3, 0.25, 0.5])
		tint = Color(float(c[0]), float(c[1]), float(c[2]), 0.85 * tint.a)
	elif int(s.get("frames", 1)) > 1:
		im = g.tex.get("%s_f%d" % [s.sprite, int(t * 8.0 + float(a.seed)) % int(s.frames)])
	else:
		im = g.tex.get(str(s.sprite))
	if im == null:
		return
	var grow := 1.0 - float(a.rise) / 0.5
	var size := im.get_size() * size_k * (0.4 + 0.6 * grow)
	var hover := 0.0 if int(s.get("frames", 1)) > 1 or str(s.sprite) == "hero" else 10.0 + 6.0 * sin(t * 3.0 + float(a.seed))
	var pos: Vector2 = (a.p as Vector2) - Vector2(size.x / 2.0, size.y + hover)
	if rallied:
		l.draw_arc(a.p, size.x * 0.45, 0.0, TAU, 24, Color(1.0, 0.65, 0.3, 0.8), 4.0)
	if float(a.slam) > 0.0:
		pos.y -= 8.0 * sin(float(a.slam) / 0.3 * PI)
	if float(a.face) < 0.0:
		l.draw_set_transform(pos + Vector2(size.x, 0), 0.0, Vector2(-1, 1))
		l.draw_texture_rect(im, Rect2(Vector2.ZERO, size), false, tint)
		l.draw_set_transform(Vector2.ZERO)
	else:
		l.draw_texture_rect(im, Rect2(pos, size), false, tint)
	var top: Vector2 = (a.p as Vector2) - Vector2(30, size.y + hover + 12)
	l.draw_rect(Rect2(top, Vector2(60, 5)), Color(0.05, 0.03, 0.1, 0.8))
	l.draw_rect(Rect2(top, Vector2(60.0 * clampf(float(a.t) / float(a.max), 0.0, 1.0), 5)), Color(0.6, 0.9, 1.0))


## How the hero looks now: frames (the beast form's ogre), tint (subclass colour,
## faint while hidden) and size factor.
static func look(g: Node) -> Dictionary:
	var out := {"frames": g.hero_frames, "tint": Color.WHITE, "scale": 1.0}
	var kit: Dictionary = g.sub_kit
	if not kit.is_empty():
		var c: Variant = kit.get("tint")
		if c is Array:
			out.tint = Color(float(c[0]), float(c[1]), float(c[2]))
		if not on(g, "transform").is_empty() and kit.has("ogre"):
			out.frames = kit.ogre
			out.scale = 1.5
	if float(g.state.get("stealth", 0.0)) > 0.0:
		out.tint.a = 0.35
	return out
