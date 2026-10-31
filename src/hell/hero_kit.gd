extends RefCounted
## The hero's growth in themed runs (the Frostgruft): experience and level-ups,
## the class skills on keys 1-4 (assets/data/hero_skills.json, unlocked at their
## level, distances scaled to this world) and the gravity wall and bar the
## relics use (relic_kit.gd). Works on the game (src/hell/hell_game.gd): its
## state, player, mobs, shots and zones. Damage is a multiple of the weapon damage.
## Level-up cards (card_kit.gd) widen the skills in small steps.

const CardKit = preload("res://src/hell/card_kit.gd")


# ---------- experience ----------

## Experience needed to go from level to level + 1.
static func need(cfg: Dictionary, level: int) -> int:
	return int(round(float(cfg.base) * pow(float(level), float(cfg.exponent))))


## Adds experience; returns how many levels were gained.
static func gain(g: Node, amount: int) -> int:
	var cfg: Dictionary = g.theme.get("leveling", {})
	if cfg.is_empty() or amount <= 0:
		return 0
	var ups := 0
	g.state.exp = int(g.state.exp) + amount
	while int(g.state.level) < int(cfg.max_level) and int(g.state.exp) >= need(cfg, int(g.state.level)):
		g.state.exp = int(g.state.exp) - need(cfg, int(g.state.level))
		g.state.level = int(g.state.level) + 1
		ups += 1
		_level_up(g, cfg)
	return ups


static func _level_up(g: Node, cfg: Dictionary) -> void:
	g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + int(cfg.heal))
	g.levelfx = {"t": 0.0, "level": int(g.state.level)}
	# no class skills open any more: the talents on 1-4 come from the talent menu (29.10.2026)
	var sub := "+1 Herz"
	g.state.banner = {"text": "LEVEL %d" % int(g.state.level), "sub": sub, "t": 0.0}
	g._burst(Vector2(g.player.x, g.player.y - 50), 50, true)
	g._sound("level_up")
	CardKit.on_level_up(g)


## Experience for a felled enemy (its kind's exp, guardians by floor kind).
static func exp_for(g: Node, m: Dictionary) -> int:
	var cfg: Dictionary = g.theme.get("leveling", {})
	if m.kind == "boss":
		if g.W.final:
			return 0
		return int(cfg.get("boss_exp", {}).get("mini" if g.W.boss.get("mini", false) else "guardian", 0))
	return int((m.def as Dictionary).get("exp", 0))


# ---------- skills ----------

## The class skills from hero_skills.json, distances scaled to this world.
static func load_skills(g: Node, class_id: String) -> Array:
	var cfg: Dictionary = g.theme.get("leveling", {})
	if cfg.is_empty() or class_id == "":
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(cfg.skills)))
	if not (data is Dictionary) or not (data.classes as Dictionary).has(class_id):
		return []
	var k := float(cfg.scale)
	var out: Array = []
	for raw: Dictionary in data.classes[class_id].skills:
		var s := raw.duplicate(true)
		for key in ["radius", "range", "width", "speed", "distance", "jump_range", "length", "caltrop_radius", "burst_radius"]:
			if s.has(key):
				s[key] = float(s[key]) * k
		out.append(s)
	return out


static func unlocked(g: Node, s: Dictionary) -> bool:
	return int(g.state.level) >= int(s.unlock)


## Key press of a skill (1-4). Hold skills start charging here and fire on release.
static func press(g: Node, key: String) -> void:
	for s: Dictionary in g.skills:
		if str(s.key) != key:
			continue
		if not unlocked(g, s):
			g._toast("%s ab Level %d." % [s.name, int(s.unlock)])
			return
		# a curse on an equipped piece can seal a skill (src/hero/story_items.gd)
		if g.get("story_items") != null and g.story_items.sealed(key):
			g._toast("%s ist versiegelt. Ein Fluchbrecherstein hilft." % s.name)
			return
		if float(g.state.skill_cd.get(key, 0.0)) > 0.0:
			g._sound("no_cooldown")
			return
		if s.get("hold", false):
			g.hold = {"id": str(s.id), "key": key, "t": 0.0}
			if str(s.id) == "photon":
				g.hold.duration = float(s.duration) + float(CardKit.value(g, "long_breath", "time", 0.0)) * CardKit.level(g, "long_breath")
				g.hold.angle = _aim(g).angle()
				g.hold.tick = 0.0
			g._sound_raw(str(s.sound))
			return
		_cast(g, s)
		g.state.skill_cd[key] = float(s.cooldown) * (g.story_items.cooldown_scale() if g.get("story_items") != null else 1.0)
		g._sound_raw(str(s.sound))


## Key release: fires a charged ballista arrow or ends the photon beam.
static func release(g: Node, key: String) -> void:
	var h: Dictionary = g.hold
	if h.is_empty() or str(h.key) != key:
		return
	var s := _skill(g, str(h.id))
	if str(h.id) == "ballista":
		var charge := float(s.charge) * (1.0 - float(CardKit.value(g, "quick_draw", "charge", 0.0)) * CardKit.level(g, "quick_draw"))
		var share := clampf(float(h.t) / charge, 0.0, 1.0)
		var dmg := lerpf(float(s.damage_min), float(s.damage_max), share) * (1.0 + float(CardKit.value(g, "heavy_tip", "damage", 0.0)) * CardKit.level(g, "heavy_tip"))
		_hero_shot(g, _aim(g) * minf(float(s.speed), 2000.0), float(s.range) / minf(float(s.speed), 2000.0), {"kind": "arrow", "pierce": true, "mult": dmg, "big": 1.4})
		g._sound_raw("shoot_arrow")
	g.hold = {}
	g.state.skill_cd[key] = float(s.cooldown) * (g.story_items.cooldown_scale() if g.get("story_items") != null else 1.0)


static func _skill(g: Node, id: String) -> Dictionary:
	for s: Dictionary in g.skills:
		if str(s.id) == id:
			return s
	return {}


## Where the hero aims skills: the mouse in the world, or game.aim_at when set (tests, debug).
static func target(g: Node) -> Vector2:
	return g.aim_at if g.aim_at != null else g.get_global_mouse_position()


static func _aim(g: Node) -> Vector2:
	var to: Vector2 = target(g) - Vector2(g.player.x, g.player.y - 40)
	return to.normalized() if to.length() > 1.0 else Vector2(float(g.player.face), 0)


static func _hero_shot(g: Node, v: Vector2, life: float, extra: Dictionary) -> void:
	var s := {"p": Vector2(g.player.x, g.player.y - 40), "v": v, "t": life, "kind": "", "splash": 0.0, "hits": []}
	s.merge(extra, true)
	g.shots.append(s)


static func _cast(g: Node, s: Dictionary) -> void:
	var aim := _aim(g)
	var me := Vector2(g.player.x, g.player.y - 40)
	match str(s.id):
		"whirl":
			var radius := float(s.radius) * (1.0 + float(CardKit.value(g, "wide_swing", "radius", 0.0)) * CardKit.level(g, "wide_swing"))
			for m: Dictionary in g.mobs:
				if m.spawn <= 0.0 and me.distance_to(m.p - Vector2(0, m.cy)) < radius + m.r:
					g._damage_mob(m, (m.p - me).normalized() * float(s.knockback), float(s.damage))
			g.fx.append({"kind": "whirl", "p": me, "r": radius, "t": float(s.duration), "max": float(s.duration)})
			if CardKit.level(g, "double_whirl") > 0:
				g.pending.append({"do": "quake", "t": float(s.duration), "at": me, "r": radius, "mult": float(s.damage) * float(CardKit.value(g, "double_whirl", "damage", 0.6))})
		"wave":
			var waves := 3 if CardKit.level(g, "wave_fan") > 0 else 1
			var wmult := float(s.damage) * (float(CardKit.value(g, "wave_fan", "damage", 0.6)) if waves > 1 else 1.0)
			for k in range(waves):
				var a := aim.angle() + (k - (waves - 1) / 2.0) * float(CardKit.value(g, "wave_fan", "spread", 0.35))
				_hero_shot(g, Vector2(cos(a), sin(a)) * float(s.speed), float(s.range) / float(s.speed), {"kind": "wave", "pierce": true, "mult": wmult, "big": 2.2})
		"charge":
			g.dash = {"dir": aim, "speed": float(s.distance) / float(s.duration), "t": float(s.duration), "mult": float(s.damage), "hit": [],
				"land": "shockwave" if CardKit.level(g, "shockwave") > 0 else ""}
			g.state.inv = maxf(float(g.state.inv), float(s.duration) + 0.1)
		"rage":
			g.state.rage = float(s.duration)
		"volley":
			var n := int(s.count) + int(CardKit.value(g, "wide_volley", "count", 0)) * CardKit.level(g, "wide_volley")
			var extra := {"kind": "arrow", "mult": float(s.damage)}
			if CardKit.level(g, "poison_tips") > 0:
				extra.burn = float(CardKit.value(g, "poison_tips", "dps", 0.8))
				extra.burn_time = float(CardKit.value(g, "poison_tips", "time", 3))
			for k in range(n):
				var a := aim.angle() + (float(k) / maxf(1.0, n - 1.0) - 0.5) * float(s.spread)
				_hero_shot(g, Vector2(cos(a), sin(a)) * float(g.weapon.get("speed", 1000)), float(g.weapon.get("life", 0.8)), extra.duplicate())
		"backflip":
			var away := -aim
			g.dash = {"dir": away, "speed": float(s.distance) / float(s.duration), "t": float(s.duration), "mult": 0.0, "hit": []}
			g.state.inv = maxf(float(g.state.inv), float(s.duration) + 0.1)
			var slow := float(CardKit.value(g, "ice_thorns", "slow", s.slow)) if CardKit.level(g, "ice_thorns") > 0 else float(s.slow)
			g.zones.append({"kind": "caltrop", "p": Vector2(g.player.x, g.player.y), "r": float(s.caltrop_radius), "t": float(s.caltrop_time), "max": float(s.caltrop_time), "slow": slow})
		"fist":
			_hero_shot(g, aim * float(s.speed), float(s.range) / float(s.speed), {"kind": "fist", "pierce": true, "mult": float(s.damage), "push": true, "big": 3.0,
				"burst": float(s.burst_radius), "burst_mult": float(s.burst_damage) * (1.0 + float(CardKit.value(g, "wall_breaker", "burst", 0.0)) * CardKit.level(g, "wall_breaker")),
				"slow": float(s.slow), "slow_time": float(s.slow_time)})
		"fireball":
			var balls := 1 + CardKit.level(g, "twin_fire")
			var radius := float(s.radius) * (1.0 + float(CardKit.value(g, "wildfire", "radius", 0.0)) * CardKit.level(g, "wildfire"))
			for k in range(balls):
				var a := aim.angle() + (k - (balls - 1) / 2.0) * float(CardKit.value(g, "twin_fire", "spread", 0.22))
				_hero_shot(g, Vector2(cos(a), sin(a)) * float(s.speed), float(s.range) / float(s.speed), {"kind": "fireball", "mult": float(s.damage), "burst": radius, "burst_mult": float(s.damage),
					"burn": float(s.burn_dps), "burn_time": float(s.burn_time), "big": 1.8})
		"chain":
			_chain(g, s)
		"blink":
			if CardKit.level(g, "arcane_rift") > 0:
				g.pending.append({"do": "quake", "t": 0.0, "at": Vector2(g.player.x, g.player.y), "r": float(CardKit.value(g, "arcane_rift", "radius", 150)),
					"mult": float(CardKit.value(g, "arcane_rift", "damage", 2.0))})
			var to := Vector2(g.player.x, g.player.y)
			var step := aim * 12.0
			for i in range(int(float(s.distance) / 12.0)):
				var nx: Vector2 = to + step
				if g.box_blocked(g._player_box(nx.x, nx.y)):
					break
				to = nx
			g.fx.append({"kind": "blink", "p": Vector2(g.player.x, g.player.y - 40), "q": to - Vector2(0, 40), "t": 0.3, "max": 0.3})
			g.player.x = to.x
			g.player.y = to.y
			g.state.inv = maxf(float(g.state.inv), float(s.invulnerable))


static func _chain(g: Node, s: Dictionary) -> void:
	var mouse: Vector2 = target(g)
	var me := Vector2(g.player.x, g.player.y - 40)
	var first: Dictionary = {}
	var best := INF
	for m: Dictionary in g.mobs:
		var p: Vector2 = m.p - Vector2(0, m.cy)
		if m.spawn <= 0.0 and me.distance_to(p) < float(s.range) and p.distance_to(mouse) < best:
			best = p.distance_to(mouse)
			first = m
	if first.is_empty():
		return
	var hit: Array = [first]
	var from := me
	var mult := float(s.damage)
	var cur := first
	for j in range(int(s.jumps) + int(CardKit.value(g, "more_jumps", "jumps", 0)) * CardKit.level(g, "more_jumps") + 1):
		var p: Vector2 = cur.p - Vector2(0, cur.cy)
		g.fx.append({"kind": "bolt", "p": from, "q": p, "t": 0.25, "max": 0.25})
		g._damage_mob(cur, (p - from).normalized() * 200.0, mult)
		cur.stun = maxf(float(cur.get("stun", 0.0)), float(s.stun))
		mult *= 1.0 - float(s.falloff)
		from = p
		var nxt: Dictionary = {}
		var nd := float(s.jump_range)
		for m: Dictionary in g.mobs:
			if m.spawn <= 0.0 and not hit.has(m) and p.distance_to(m.p - Vector2(0, m.cy)) < nd:
				nd = p.distance_to(m.p - Vector2(0, m.cy))
				nxt = m
		if nxt.is_empty():
			break
		hit.append(nxt)
		cur = nxt


# ---------- master skills (talent tier 5, key 5) ----------

## Key 5: the talent tree's master skill (state.talent.master), with its long cooldown.
static func master_press(g: Node) -> void:
	var id := str(g.state.get("talent", {}).get("master", ""))
	if id == "":
		g._toast("Keine Meisterfähigkeit. Skille sie im Hauptmenü unter TALENTE.")
		return
	if float(g.state.skill_cd.get("5", 0.0)) > 0.0:
		g._sound("no_cooldown")
		return
	var at := target(g)
	var me := Vector2(g.player.x, g.player.y - 40)
	match id:
		"meteor_rain":
			for k in range(6):
				var p := at + Vector2(randf_range(-160, 160), randf_range(-120, 120))
				g.pending.append({"do": "meteor", "t": 0.6 + k * 0.45, "at": p, "s": {"radius": 150, "damage": 5.0}, "mult": 1.0})
				g.zones.append({"kind": "meteor", "p": p, "r": 150.0, "t": 0.6 + k * 0.45, "max": 0.6 + k * 0.45})
			g._sound_raw("windup_beam")
		"phoenix":
			g.state.phoenix_t = 8.0
			g._sound_raw("attack_roar")
		"blade_storm":
			g.state.storm_blades = 4.0
			g._sound_raw("swing")
		"execute":
			var aim := _aim(g)
			for m: Dictionary in g.mobs:
				var to: Vector2 = m.p - Vector2(0, m.cy) - me
				if m.spawn <= 0.0 and to.length() < 210.0 + m.r and absf(angle_difference(aim.angle(), to.angle())) < 1.0:
					if m.kind != "boss" and not m.has("kit") and m.hp < m.max * 0.3:
						m.hp = 0.0
						g._burst(m.p - Vector2(0, m.cy), 30, true)
					else:
						g._damage_mob(m, aim * 600.0, 3.0 if (m.kind == "boss" or m.has("kit")) else 2.0)
			g.fx.append({"kind": "whirl", "p": me, "r": 210.0, "t": 0.3, "max": 0.3})
			g._sound_raw("attack_slash")
		"death_shot":
			g.pending.append({"do": "death_shot", "t": 1.2})
			g.fx.append({"kind": "charge", "p": me, "t": 1.2, "max": 1.2})
			g._sound_raw("windup_beam")
		"arrow_rain":
			g.zones.append({"kind": "rain", "p": at, "r": 230.0, "t": 4.0, "max": 4.0, "tick": 0.0})
			g._sound_raw("attack_salve")
	g.state.skill_cd["5"] = float(g.theme.get("master_cooldown", 45.0))


## Per frame: cooldowns, rage, dashes, charging, the photon beam, effects and statuses.
static func update(g: Node, dt: float) -> void:
	var cds: Dictionary = g.state.skill_cd
	for k: String in cds:
		cds[k] = maxf(0.0, float(cds[k]) - dt)
	g.state.rage = maxf(0.0, float(g.state.get("rage", 0.0)) - dt)
	for f: Dictionary in g.fx:
		f.t = float(f.t) - dt
	g.fx = g.fx.filter(func(f: Dictionary) -> bool: return float(f.t) > 0.0)
	if not g.levelfx.is_empty():
		g.levelfx.t = float(g.levelfx.t) + dt
		if float(g.levelfx.t) > 1.4:
			g.levelfx = {}
	_update_dash(g, dt)
	_update_hold(g, dt)
	_update_master(g, dt)
	for w: Dictionary in g.gwalls:
		w.t = float(w.t) - dt
	g.gwalls = g.gwalls.filter(func(w: Dictionary) -> bool: return float(w.t) > 0.0)
	for b: Dictionary in g.gbars:
		b.t = float(b.t) - dt
	g.gbars = g.gbars.filter(func(b: Dictionary) -> bool: return float(b.t) > 0.0)


## Running master skills: the phoenix's flame ring and the blade storm.
static func _update_master(g: Node, dt: float) -> void:
	var me := Vector2(g.player.x, g.player.y - 40)
	for k: String in ["phoenix_t", "storm_blades"]:
		if float(g.state.get(k, 0.0)) <= 0.0:
			continue
		g.state[k] = float(g.state[k]) - dt
		g.state[k + "_tick"] = float(g.state.get(k + "_tick", 0.0)) - dt
		if float(g.state[k + "_tick"]) > 0.0:
			continue
		g.state[k + "_tick"] = 0.5 if k == "phoenix_t" else 0.25
		var radius := 170.0 if k == "phoenix_t" else 200.0
		for m: Dictionary in g.mobs:
			if m.spawn <= 0.0 and me.distance_to(m.p - Vector2(0, m.cy)) < radius + m.r:
				g._damage_mob(m, (m.p - me).normalized() * 200.0, 1.5 if k == "phoenix_t" else 1.0)
				if k == "phoenix_t":
					burn_mob(m, 1.0, 2.0)
		g.fx.append({"kind": "whirl", "p": me, "r": radius, "t": 0.25, "max": 0.25})


static func _update_dash(g: Node, dt: float) -> void:
	var d: Dictionary = g.dash
	if d.is_empty():
		return
	d.t = float(d.t) - dt
	var step: Vector2 = d.dir * float(d.speed) * dt
	if not g.box_blocked(g._player_box(g.player.x + step.x, g.player.y)):
		g.player.x += step.x
	if not g.box_blocked(g._player_box(g.player.x, g.player.y + step.y)):
		g.player.y += step.y
	if float(d.mult) > 0.0:
		var me := Vector2(g.player.x, g.player.y - 40)
		for m: Dictionary in g.mobs:
			if m.spawn <= 0.0 and not (d.hit as Array).has(m) and me.distance_to(m.p - Vector2(0, m.cy)) < m.r + 50.0:
				d.hit.append(m)
				g._damage_mob(m, d.dir * 500.0, float(d.mult))
	if float(d.t) <= 0.0:
		g.dash = {}
		if str(d.get("land", "")) != "":
			g.on_dash_land(str(d.land))


static func _update_hold(g: Node, dt: float) -> void:
	var h: Dictionary = g.hold
	if h.is_empty():
		return
	h.t = float(h.t) + dt
	if str(h.id) != "photon":
		return
	var s := _skill(g, "photon")
	var want := _aim(g).angle()
	h.angle = rotate_toward(float(h.angle), want, float(s.turn) * dt)
	h.tick = float(h.tick) - dt
	if float(h.tick) <= 0.0:
		h.tick = float(s.tick)
		var me := Vector2(g.player.x, g.player.y - 40)
		var dir := Vector2(cos(float(h.angle)), sin(float(h.angle)))
		# the beam stops at the first wall, as it is drawn
		var reach := beam_end(g, me, dir, float(s.length)).distance_to(me)
		for m: Dictionary in g.mobs:
			var p: Vector2 = m.p - Vector2(0, m.cy) - me
			var along := p.dot(dir)
			if m.spawn <= 0.0 and along > 0.0 and along < reach and absf(p.cross(dir)) < float(s.width) / 2.0 + m.r:
				g._damage_mob(m, Vector2.ZERO, float(s.dps) * float(s.tick))
				slow_mob(g, m, float(s.slow), float(s.slow_decay))
				burn_mob(m, float(s.ignite_dps), float(s.ignite_time))
	if float(h.t) >= float(h.get("duration", s.duration)):
		release(g, str(h.key))


## Where the photon beam from `from` along `dir` ends: after `length` px or at the first wall.
static func beam_end(g: Node, from: Vector2, dir: Vector2, length: float) -> Vector2:
	var C: float = g.C
	var travelled := 0.0
	while travelled < length:
		var next := minf(length, travelled + 12.0)
		var at := from + dir * next
		if g._cell_blocked(int(floor(at.x / C)), int(floor(at.y / C)), false):
			break
		travelled = next
	return from + dir * travelled


## Speed factor while holding a skill (ballista and beam slow the hero).
static func move_scale(g: Node) -> float:
	var h: Dictionary = g.hold
	if h.is_empty():
		return 1.0
	return float(_skill(g, str(h.id)).get("move_scale", 1.0))


## Rage: faster attacks and critical hits for the swordsman.
static func rate_scale(g: Node) -> float:
	return float(_skill(g, "rage").get("rate", 1.0)) if float(g.state.get("rage", 0.0)) > 0.0 else 1.0


static func crit(g: Node) -> float:
	if float(g.state.get("rage", 0.0)) <= 0.0:
		return 1.0
	var s := _skill(g, "rage")
	var chance := float(s.crit) + float(CardKit.value(g, "sharp_blades", "crit", 0.0)) * CardKit.level(g, "sharp_blades")
	return float(s.crit_mult) if randf() < chance else 1.0


# ---------- statuses on enemies ----------

## Slows an enemy (share of its speed); kit bosses shrug it off, other guardians feel half.
static func slow_mob(g: Node, m: Dictionary, share: float, time: float) -> void:
	if m.has("kit"):
		return
	if m.kind == "boss":
		share *= float(g.theme.get("leveling", {}).get("slow_boss_scale", 0.5))
	m.slow = maxf(float(m.get("slow", 0.0)), share)
	m.slow_t = maxf(float(m.get("slow_t", 0.0)), time)


## Sets an enemy burning: `dps` damage over time for `time` s (the stronger
## source holds). Fire alone: a wet monster cannot be set burning.
static func burn_mob(m: Dictionary, dps: float, time: float) -> void:
	# a wet monster (it stood in water, element_rules.json combos) cannot be set burning
	if float(m.get("wet_t", 0.0)) > 0.0:
		return
	m.burn = maxf(float(m.get("burn", 0.0)), dps)
	m.burn_t = maxf(float(m.get("burn_t", 0.0)), time)


## Poisons an enemy: `dps` damage over time for `time` s that water does not
## wash off (a wet monster is still poisoned; only fire is blocked by wet).
## Ticks in tick_mob beside the burn. For a venom weapon's hits
## (items.json effect venom -> element poison); the fire path stays burn_mob.
static func poison_mob(m: Dictionary, dps: float, time: float) -> void:
	m.poison = maxf(float(m.get("poison", 0.0)), dps)
	m.poison_t = maxf(float(m.get("poison_t", 0.0)), time)


## Ticks an enemy's slow, burn, poison and stun; returns its speed factor (0 while stunned).
static func tick_mob(g: Node, m: Dictionary, dt: float) -> float:
	m.slow_t = maxf(0.0, float(m.get("slow_t", 0.0)) - dt)
	m.stun = maxf(0.0, float(m.get("stun", 0.0)) - dt)
	m.wet_t = maxf(0.0, float(m.get("wet_t", 0.0)) - dt)
	# fire_t: the monster is on fire (lava, a fire pool, a burn); burn_t alone is any damage over time
	m.fire_t = maxf(0.0, float(m.get("fire_t", 0.0)) - dt)
	if float(m.get("burn_t", 0.0)) > 0.0:
		m.burn_t = float(m.burn_t) - dt
		m.hp -= float(m.burn) * float(g.state.dmg) * dt
	# poison_t: poisoned (poison_mob), a damage over time of its own that wet does not stop
	if float(m.get("poison_t", 0.0)) > 0.0:
		m.poison_t = float(m.poison_t) - dt
		m.hp -= float(m.poison) * float(g.state.dmg) * dt
	for z: Dictionary in g.zones:
		if z.kind == "caltrop" and m.p.distance_to(z.p) < float(z.r):
			slow_mob(g, m, float(z.slow), 0.2)
	if float(m.stun) > 0.0 and not m.has("kit"):
		return 0.0
	return 1.0 - (float(m.get("slow", 0.0)) if float(m.slow_t) > 0.0 else 0.0)


# ---------- the gravity staff ----------

## Opens the relic's seal reward: the staff now lies free.
static func can_wield(g: Node, item: String) -> bool:
	return g.class_id in (g.theme.get(item, {}).get("classes", []) as Array)


## Key 1 with the staff: a wall of gravity across the aim at the mouse; no enemy passes.
static func gravity_wall(g: Node, size := 1.0) -> void:
	var cfg: Dictionary = g.theme.gravity_staff.wall
	if float(g.state.skill_cd.get("g_wall", 0.0)) > 0.0:
		g._sound("no_cooldown")
		return
	var at: Vector2 = target(g)
	var aim := _aim(g)
	var side := Vector2(-aim.y, aim.x) * float(cfg.length) * size / 2.0
	g.gwalls.append({"a": at - side, "b": at + side, "t": float(cfg.time) * size, "max": float(cfg.time) * size, "w": float(cfg.thickness)})
	g.state.skill_cd["g_wall"] = float(cfg.cooldown)
	g._sound_raw("void_burst")


## Right mouse released after a drag from a to b: the shot-catching bar.
static func gravity_bar(g: Node, a: Vector2, b: Vector2) -> void:
	var cfg: Dictionary = g.theme.gravity_staff.bar
	if float(g.state.skill_cd.get("g_bar", 0.0)) > 0.0:
		g._sound("no_cooldown")
		return
	if a.distance_to(b) > float(cfg.max_length):
		b = a + (b - a).normalized() * float(cfg.max_length)
	if a.distance_to(b) < 40.0:
		return
	g.gbars.append({"a": a, "b": b, "t": float(cfg.time), "max": float(cfg.time), "w": float(cfg.width)})
	g.state.skill_cd["g_bar"] = float(cfg.cooldown)
	g._sound_raw("windup_beam")


## Distance from p to the segment a-b.
static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## True when a gravity wall stands in the way of an enemy at p (radius r).
static func wall_blocks(g: Node, p: Vector2, r: float) -> bool:
	for w: Dictionary in g.gwalls:
		if seg_dist(p, w.a, w.b) < float(w.w) / 2.0 + r:
			return true
	return false


## Enemy shots: walls swallow them, bars hold them still for a while.
static func catch_shot(g: Node, s: Dictionary, dt: float) -> bool:
	if float(s.get("held", 0.0)) > 0.0:
		s.held = float(s.held) - dt
		s.t = float(s.t) + dt
		if float(s.held) <= 0.0:
			s.v = s.keep
			s.passed = true
		return true
	for w: Dictionary in g.gwalls:
		if seg_dist(s.p, w.a, w.b) < float(w.w) / 2.0:
			s.t = 0.0
			return true
	for b: Dictionary in g.gbars:
		if not s.get("passed", false) and seg_dist(s.p, b.a, b.b) < float(b.w) / 2.0:
			s.keep = s.v
			s.v = Vector2.ZERO
			s.held = float(g.theme.gravity_staff.bar.hold)
			return true
	return false
