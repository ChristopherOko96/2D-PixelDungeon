extends RefCounted
## Story 1's extra enemy moves in the Frostgruft. The moves themselves are the
## crypt's (assets/data/combat_boss_moves.json: ice fan, frost nova, hail, ice
## slide, ice armour, frost breath, pounce ...); theme.moves says which enemy
## kind uses which set and scales the crypt's pixels and half hearts to this
## world. Every move warns first (circles, cones, lanes that fill up) and can
## be dodged; it runs windup -> active -> recovery, and the enemy stands while
## it winds up. Guardians without their own boss kit use the "guardian" set;
## kit bosses (boss_kit.gd) keep theirs. Bullets are enemy shots (game.eshots)
## with damage, effect and style, so gravity walls and shield walls stop them.

const HeroFx = preload("res://src/hell/hero_fx.gd")
const DATA_PATH := "res://assets/data/combat_boss_moves.json"
## Move types this runtime plays (barrier, cage, grab, shield and twin_beam need the crypt's rooms and team).
const TYPES := ["strikes", "bullets", "lob", "dash", "blink", "vortex", "cone", "spin", "summon", "armor"]
const STYLE := {"ice": Color(0.65, 0.9, 1.0), "frost": Color(0.8, 0.96, 1.0), "quake": Color(0.75, 0.6, 0.45), "poison": Color(0.55, 0.9, 0.35),
	"void": Color(0.75, 0.45, 0.95), "bone": Color(0.92, 0.88, 0.78), "fire": Color(1.0, 0.55, 0.25), "curse": Color(0.6, 0.45, 0.9), "charge": Color(1.0, 0.45, 0.4),
	"dust": Color(0.75, 0.7, 0.65), "arrow": Color(0.95, 0.9, 0.8), "spit": Color(0.6, 0.85, 0.35), "skull": Color(0.92, 0.88, 0.78)}

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func _cfg(g: Node) -> Dictionary:
	return g.theme.get("moves", {})


## The move set of an enemy ({} when it has none).
static func set_for(g: Node, m: Dictionary) -> Dictionary:
	var sets: Dictionary = _cfg(g).get("sets", {})
	if m.has("kit"):
		return {}
	var key := "guardian" if m.kind == "boss" else str(m.kind)
	return sets.get(key, {})


static func move(id: String) -> Dictionary:
	return data().get("moves", {}).get(id, {})


static func _k(g: Node) -> float:
	return float(_cfg(g).get("scale", 2.4))


## Crypt half hearts to this world's hits (at least one).
static func _dmg(g: Node, d: Variant) -> int:
	return 0 if float(d) <= 0.0 else maxi(1, int(round(float(d) * float(_cfg(g).get("damage_scale", 0.5)))))


static func _zones(g: Node) -> Array:
	if not g.state.has("mzones"):
		g.state.mzones = []
	return g.state.mzones


static func _hero(g: Node) -> Vector2:
	return Vector2(g.player.x, g.player.y)


## The world's pixel look and feel of the attacks (src/hell/frost_fx.gd), null without theme.vfx.
static func _fx(g: Node) -> RefCounted:
	return g.get("frost_fx")


static func _boss(m: Dictionary) -> bool:
	return str(m.get("kind", "")) == "boss"


# ---------- choosing and running ----------

static func update(g: Node, dt: float) -> void:
	if _cfg(g).is_empty():
		return
	var hidden := float(g.state.get("stealth", 0.0)) > 0.0
	for m: Dictionary in g.mobs.duplicate():
		var set := set_for(g, m)
		if set.is_empty() or m.spawn > 0.0:
			continue
		if not m.has("mv"):
			var every: Array = set.get("every", [3.0, 5.0])
			m.mv = {"next": randf_range(float(every[0]), float(every[1])), "cd": {}, "used": {}, "rage": false, "run": {}}
		var mv: Dictionary = m.mv
		for id: String in (mv.cd as Dictionary).keys():
			mv.cd[id] = float(mv.cd[id]) - dt
		if set.has("rage_below") and not mv.rage and m.hp < m.max * float(set.rage_below):
			mv.rage = true
			g._sound_raw("attack_roar")
			if g.feel != null:
				g.feel.on_blast(m.p, 200.0, "frost")
		var run: Dictionary = mv.run
		if not run.is_empty():
			_run(g, m, run, dt)
			continue
		m.mv_hold = false
		if hidden or float(m.get("stun", 0.0)) > 0.0:
			continue
		mv.next = float(mv.next) - dt
		if float(mv.next) > 0.0:
			continue
		var every: Array = set.get("every", [3.0, 5.0])
		mv.next = randf_range(float(every[0]), float(every[1])) * (float(data().get("rage", {}).get("cooldown_scale", 0.6)) if mv.rage else 1.0)
		var pick := choose(g, m, set)
		if not pick.is_empty():
			_begin(g, m, pick)
	_update_zones(g, dt)


## A move that fits now: in range, off cooldown, HP condition, rage, weight.
static func choose(g: Node, m: Dictionary, set: Dictionary) -> Dictionary:
	var d: float = (m.p as Vector2).distance_to(_hero(g))
	var k := _k(g)
	var pool: Array = []
	var total := 0.0
	for e: Dictionary in set.get("moves", []):
		var spec := move(str(e.move))
		if spec.is_empty() or not str(spec.type) in TYPES:
			continue
		if float(m.mv.cd.get(str(e.move), 0.0)) > 0.0 or (e.get("once", false) and m.mv.used.has(str(e.move))):
			continue
		if e.has("near") and d > float(e.near) * k or e.has("far") and d < float(e.far) * k:
			continue
		if e.has("hp_below") and m.hp >= m.max * float(e.hp_below) or e.get("rage", false) and not m.mv.rage:
			continue
		pool.append(e)
		total += float(e.get("weight", 1.0))
	var roll := randf() * total
	for e: Dictionary in pool:
		roll -= float(e.get("weight", 1.0))
		if roll <= 0.0:
			return e
	return {}


static func _begin(g: Node, m: Dictionary, e: Dictionary) -> void:
	var id := str(e.move)
	var spec := move(id)
	m.mv.cd[id] = float(e.get("cooldown", 0.0))
	m.mv.used[id] = true
	var aim: Vector2 = (_hero(g) - (m.p as Vector2)).normalized()
	m.mv.run = {"id": id, "spec": spec, "phase": "windup", "t": float(spec.get("windup", 0.5)), "aim": aim, "at": _hero(g), "tick": 0.0, "hit": false, "moved": 0.0}
	m.mv_hold = true
	match str(spec.get("anim", "attack")):
		"roar":
			g._sound_raw("attack_roar")
		"cast":
			g._sound_raw("windup_beam")
		"summon":
			g._sound_raw("windup_summon")
		_:
			g._sound_raw("windup_fuse")
	# the warning shows during the windup: circles at the targets, lanes and cones
	var k := _k(g)
	match str(spec.type):
		"strikes", "lob":
			_place_strikes(g, m, m.mv.run)
		"dash":
			var dir: Vector2 = -aim if spec.get("away", false) else aim
			m.mv.run.aim = dir
			if not spec.get("away", false):
				_zones(g).append({"kind": "lane", "p": m.p, "q": (m.p as Vector2) + dir * float(spec.distance) * k, "w": maxf(30.0, float(spec.width) * k), "t": float(spec.windup), "max": float(spec.windup), "style": str(spec.get("style", "charge"))})
		"cone":
			_zones(g).append({"kind": "cone", "p": m.p, "a": aim.angle(), "r": float(spec.reach) * k, "arc": float(spec.angle), "t": float(spec.windup), "max": float(spec.windup), "style": str(spec.get("style", "frost"))})


## Strike points by pattern; each warns, then bursts (lob: a glob flies first).
static func _place_strikes(g: Node, m: Dictionary, run: Dictionary) -> void:
	var spec: Dictionary = run.spec
	var k := _k(g)
	var me := _hero(g)
	var pts: Array = []
	var delays: Array = []
	match str(spec.get("pattern", "near_players")):
		"under_players", "under_target":
			pts = [me]
		"self":
			pts = [m.p]
		"line":
			for i in range(int(spec.get("count", 6))):
				pts.append((m.p as Vector2) + (run.aim as Vector2) * float(spec.spacing) * k * (i + 1))
				delays.append(float(spec.get("step_delay", 0.06)) * i)
		_:
			var n := int(spec.get("count", 3))
			for i in range(n):
				pts.append(me if i == 0 else me + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.3, 1.0) * float(spec.get("spread", 90)) * k)
	var warn := float(spec.get("windup", 0.5)) + float(spec.get("warn", spec.get("flight", 0.8)))
	for i in range(pts.size()):
		var delay: float = delays[i] if i < delays.size() else 0.0
		var z := {"kind": "strike", "p": pts[i], "r": maxf(20.0, float(spec.get("radius", 30)) * k), "t": warn + delay, "max": warn + delay,
			"dmg": _dmg(g, spec.get("damage", 1)), "effect": spec.get("effect", {}), "style": str(spec.get("style", "ice")), "pool": spec.get("pool", {}),
			# who struck and how: around itself a burst of frost, elsewhere hail from above (frost_fx.gd)
			"src": m.p, "boss": _boss(m), "self": str(spec.get("pattern", "")) == "self", "seed": randf() * 9.0}
		if str(spec.type) == "lob":
			z.from = (m.p as Vector2) - Vector2(0, m.cy)
		_zones(g).append(z)


static func _run(g: Node, m: Dictionary, run: Dictionary, dt: float) -> void:
	var spec: Dictionary = run.spec
	run.t = float(run.t) - dt
	match str(run.phase):
		"windup":
			m.tele = true
			if float(run.t) > 0.0:
				return
			m.tele = false
			_release(g, m, run)
			run.phase = "active"
			run.t = float(spec.get("active", 0.0))
			if str(spec.type) == "dash":
				run.t = float(spec.distance) / maxf(1.0, float(spec.speed))
		"active":
			_active(g, m, run, dt)
			if float(run.t) > 0.0:
				return
			_finish(g, m, run)
			run.phase = "recovery"
			run.t = float(spec.get("recovery", 0.4))
		"recovery":
			m.mv_hold = true
			if float(run.t) <= 0.0:
				m.mv.run = {}
				m.mv_hold = false


static func _release(g: Node, m: Dictionary, run: Dictionary) -> void:
	var spec: Dictionary = run.spec
	var k := _k(g)
	var me := _hero(g)
	var from: Vector2 = (m.p as Vector2) - Vector2(0, m.cy)
	var aim: Vector2 = (me - Vector2(0, 30) - from).normalized()
	match str(spec.type):
		"bullets":
			var pattern := str(spec.get("pattern", "single"))
			var angles: Array = []
			match pattern:
				"fan":
					var n := int(spec.get("count", 3))
					for i in range(n):
						angles.append(aim.angle() + (float(i) - (n - 1) / 2.0) * float(spec.get("spread", 0.2)))
				"ring":
					var n := int(spec.get("count", 16))
					var gap := float(spec.get("gap", 0.6))
					for i in range(n):
						var a := aim.angle() + gap / 2.0 + (TAU - gap) * float(i) / n
						angles.append(a)
				"spiral":
					pass
				_:
					angles = [aim.angle()]
			for a: float in angles:
				_bullet(g, from, a, spec, m)
			g._sound_raw("attack_salve" if angles.size() > 2 else "attack_arrow")
			# the shards break loose: frost chips and sparkles at the muzzle
			if _fx(g) != null and str(spec.get("style", "")) in ["ice", "frost"]:
				_fx(g).shatter(from, 6 + angles.size(), 12.0, aim, 140.0)
				_fx(g).impact(from, "small" if angles.size() > 2 else "tiny", _boss(m))
		"blink":
			var lo := float(spec.get("min", 100)) * k
			var hi := float(spec.get("max", 200)) * k
			var old: Vector2 = m.p
			for i in range(12):
				var cand := me + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(lo, hi) if not spec.get("toward", false) else (m.p as Vector2) + ((me - (m.p as Vector2)).normalized() * randf_range(lo, hi))
				if not g.box_blocked(Rect2(cand.x - 20, cand.y - 16, 40, 16), true):
					m.p = cand
					break
			if spec.has("pool"):
				_zones(g).append(_pool(g, old, spec.pool))
			if g.feel != null:
				g.feel.spawn("blink", old - Vector2(0, 30), 1.0)
				g.feel.spawn("blink", (m.p as Vector2) - Vector2(0, 30), 1.0)
			g._sound_raw("void_burst")
		"cone":
			var to := me - (m.p as Vector2)
			if to.length() < float(spec.reach) * k + 20.0 and absf(angle_difference((run.aim as Vector2).angle(), to.angle())) < float(spec.angle) / 2.0 + 0.1:
				_hit_hero(g, _dmg(g, spec.get("damage", 1)), spec.get("effect", {}), "vom Frostatem getroffen", m.p, "breath", _boss(m))
			if _fx(g) != null:
				_fx(g).breath((m.p as Vector2) - Vector2(0, float(m.cy) * 0.6), run.aim, float(spec.reach) * k, float(spec.angle))
				_fx(g).impact(m.p, "small", _boss(m))
			elif g.feel != null:
				g.feel.on_blast((m.p as Vector2) + (run.aim as Vector2) * float(spec.reach) * k * 0.5, float(spec.reach) * k * 0.6, str(spec.get("style", "frost")))
			g._sound_raw("attack_beam")
		"summon":
			var kinds: Array = spec.get("kinds", [])
			var map: Dictionary = _cfg(g).get("summon_map", {})
			for i in range(kinds.size()):
				var kind := str(map.get(str(kinds[i]), kinds[i]))
				if not (g.theme.get("mobs", {}) as Dictionary).has(kind):
					continue
				var a := TAU * i / kinds.size()
				var at := (m.p as Vector2) + Vector2(cos(a), sin(a)) * float(spec.get("offset", 70)) * k
				g._spawn_mob(m.room, at, kind)
				# the dead break up through the ice: chips, snow and rime where each one rises
				if _fx(g) != null:
					_fx(g).shatter(at, 14, 34.0, Vector2.ZERO, 200.0)
			g._sound_raw("attack_summon")
			if _fx(g) != null:
				_fx(g).nova(m.p, float(spec.get("offset", 70)) * k * 1.3, 0.4)
				_fx(g).impact(m.p, "small", _boss(m))
		"armor":
			m.armor_t = float(spec.time)
			m.armor_max = float(spec.time)
			m.armor = float(spec.scale)
			g._sound_raw("block")
			# the ice grows round it with a crack: crystals and sparkles
			if _fx(g) != null:
				_fx(g).shatter((m.p as Vector2) - Vector2(0, float(m.cy) * 0.5), 12, float(m.r), Vector2.ZERO, 120.0)
				_fx(g).impact(m.p, "small", _boss(m))
		"dash", "spin", "vortex":
			g._sound_raw("attack_bite" if str(spec.type) == "dash" else "attack_slam")
			# it pushes off: snow kicked up behind it
			if str(spec.type) == "dash" and _fx(g) != null:
				_fx(g).kick(m.p, 14, run.aim)
				_fx(g).impact(m.p, "tiny", _boss(m))
	# strikes and lob zones were placed at the windup and burst by themselves


static func _active(g: Node, m: Dictionary, run: Dictionary, dt: float) -> void:
	var spec: Dictionary = run.spec
	var k := _k(g)
	var me := _hero(g)
	match str(spec.type):
		"dash":
			var step: Vector2 = (run.aim as Vector2) * float(spec.speed) * k * dt
			var nx: Vector2 = (m.p as Vector2) + step
			if g.box_blocked(Rect2(nx.x - m.r * 0.7, nx.y - m.r * 0.7, m.r * 1.4, m.r * 0.7), true):
				run.t = 0.0
				if spec.has("stun_on_wall"):
					m.stun = float(spec.stun_on_wall)
				return
			m.p = nx
			run.moved = float(run.moved) + step.length()
			if spec.has("lane_pool") and fmod(float(run.moved), 60.0) < step.length():
				_zones(g).append(_pool(g, m.p, spec.lane_pool))
			# snow sprays from under it as it slides
			if _fx(g) != null and randf() < 0.6:
				_fx(g).kick(m.p, 2, run.aim)
			if not run.hit and float(spec.get("damage", 0)) > 0.0 and me.distance_to(m.p) < maxf(30.0, float(spec.width) * k * 0.5) + m.r:
				run.hit = true
				_hit_hero(g, _dmg(g, spec.damage), spec.get("effect", {}), "überrannt", m.p, "dash", _boss(m))
		"spin":
			if float(spec.get("chase", 0)) > 0.0:
				m.p += (me - (m.p as Vector2)).normalized() * float(spec.chase) * k * dt
			run.tick = float(run.tick) - dt
			if float(run.tick) <= 0.0:
				run.tick = float(spec.get("tick", 0.4))
				if me.distance_to(m.p) < float(spec.radius) * k:
					_hit_hero(g, _dmg(g, spec.damage), {}, "im Wirbel zerschnitten")
				if g.feel != null:
					g.feel.spawn("whirl", (m.p as Vector2) - Vector2(0, m.cy), float(spec.radius) / 60.0)
		"vortex":
			var to: Vector2 = (m.p as Vector2) - me
			if to.length() < float(spec.reach) * k and to.length() > 40.0:
				var pull: Vector2 = to.normalized() * float(spec.pull) * k * dt
				if not g.box_blocked(g._player_box(g.player.x + pull.x, g.player.y + pull.y)):
					g.player.x += pull.x
					g.player.y += pull.y
		"bullets":
			if str(spec.get("pattern", "")) == "spiral":
				run.tick = float(run.tick) - dt
				if float(run.tick) <= 0.0:
					run.tick = float(spec.get("rate", 0.2))
					run.spin = float(run.get("spin", 0.0)) + float(spec.get("turn", 1.5)) * float(spec.get("rate", 0.2))
					var arms := int(spec.get("arms", 3))
					for i in range(arms):
						_bullet(g, (m.p as Vector2) - Vector2(0, m.cy), float(run.spin) + TAU * i / arms, spec, m)


static func _finish(g: Node, m: Dictionary, run: Dictionary) -> void:
	var spec: Dictionary = run.spec
	var k := _k(g)
	if str(spec.type) == "vortex":
		if _hero(g).distance_to(m.p) < float(spec.burst) * k:
			_hit_hero(g, _dmg(g, spec.damage), {}, "vom Sog verschlungen", m.p, "wave", _boss(m))
		if _fx(g) != null:
			_fx(g).nova(m.p, float(spec.burst) * k)
			_fx(g).impact(m.p, "medium", _boss(m))
		elif g.feel != null:
			g.feel.on_blast(m.p, float(spec.burst) * k, str(spec.get("style", "void")))


## An enemy shot of a move: an eshot with damage, effect and style (and
## whether a guardian threw it, for the weight of its hit).
static func _bullet(g: Node, from: Vector2, a: float, spec: Dictionary, m: Dictionary = {}) -> void:
	var k := _k(g)
	g.eshots.append({"p": from, "v": Vector2(cos(a), sin(a)) * float(spec.get("speed", 200)) * k, "t": float(spec.get("life", 3.0)),
		"dmg": _dmg(g, spec.get("damage", 1)), "effect": spec.get("effect", {}), "style": str(spec.get("style", "ice")), "size": float(spec.get("radius", 6)) * k * 0.5,
		"end_pool": spec.get("end_pool", {}), "boss": _boss(m), "seed": randf() * 9.0})


static func _pool(g: Node, p: Vector2, spec: Dictionary) -> Dictionary:
	return {"kind": "pool", "p": p, "r": float(spec.get("radius", 40)) * _k(g), "t": float(spec.get("time", 4.0)), "max": float(spec.get("time", 4.0)),
		"dps": float(spec.get("dps", 0.0)), "slip": bool(spec.get("slip", false)), "style": str(spec.get("style", "ice")), "tick": 0.0}


## A hit from a move: hearts (via the game's hurt) and the move's condition;
## with frost_fx the blow from `from` pushes the hero back (`kind`,
## theme.vfx.knock) and is felt (a guardian's harder than a mob's).
static func _hit_hero(g: Node, dmg: int, effect: Variant, why: String, from := Vector2.INF, kind := "", boss := true, tier := "small") -> void:
	if dmg > 0:
		var before: int = g.state.hp
		g._hurt(why, dmg)
		if int(g.state.hp) >= before:
			return
		if _fx(g) != null and from.is_finite() and kind != "":
			_fx(g).hit_hero(from, kind, tier, boss)
	if effect is Dictionary and not (effect as Dictionary).is_empty():
		HeroFx.apply_spec(g, effect)


## An enemy shot of a move reached the hero (called by the game instead of its plain hit).
static func shot_hit(g: Node, s: Dictionary) -> void:
	var from: Vector2 = (s.p as Vector2) - (s.v as Vector2).normalized() * 40.0
	_hit_hero(g, int(s.get("dmg", 1)), s.get("effect", {}), "von Eis getroffen", from, "shot", bool(s.get("boss", true)), "tiny")
	# the shard bursts on him
	if _fx(g) != null and str(s.get("style", "ice")) in ["ice", "frost"]:
		_fx(g).shatter(s.p, 8, 14.0, (s.v as Vector2).normalized(), 120.0)


## A move's shot ended: a pool where it had one (fire arrow).
static func shot_end(g: Node, s: Dictionary) -> void:
	if not (s.get("end_pool", {}) as Dictionary).is_empty():
		_zones(g).append(_pool(g, s.p, s.end_pool))


## A strike bursting with frost_fx: around its caster a ring of frost running
## out (a nova), elsewhere a hailstone smashing into ice chips, snow and rime.
static func _strike_fx(g: Node, z: Dictionary, big: bool) -> void:
	var fx := _fx(g)
	var boss := bool(z.get("boss", true))
	if big:
		fx.nova(z.p, float(z.r))
		fx.shatter(z.p, 18, float(z.r) * 0.3, Vector2.ZERO, 260.0)
		fx.impact(z.p, "large" if boss else "medium", boss)
	else:
		fx.shatter(z.p, 16, float(z.r), Vector2.ZERO, 220.0)
		fx.impact(z.p, "small", boss)


static func _update_zones(g: Node, dt: float) -> void:
	var me := _hero(g)
	for z: Dictionary in _zones(g):
		z.t = float(z.t) - dt
		match str(z.kind):
			"strike":
				if float(z.t) <= 0.0:
					var big := bool(z.get("self", false)) and float(z.r) > 60.0
					if me.distance_to(z.p) < float(z.r) + 20.0:
						_hit_hero(g, int(z.dmg), z.effect, "von %s getroffen" % ("Hagel" if str(z.style) == "ice" else "der Wucht"),
							z.get("src", z.p) if big else z.p, "wave" if big else "slam", bool(z.get("boss", true)), "medium" if big else "small")
					if not (z.pool as Dictionary).is_empty():
						_zones(g).append(_pool(g, z.p, z.pool))
					if _fx(g) != null and float(z.r) > 0.0:
						_strike_fx(g, z, big)
					elif g.feel != null and float(z.r) > 0.0:
						g.feel.on_blast(z.p, float(z.r), str(z.style))
			"pool":
				if me.distance_to(z.p) < float(z.r):
					if z.slip:
						HeroFx.apply(g, "slip", 0.4, 1.0)
					if float(z.dps) > 0.0:
						HeroFx.apply(g, "poison" if str(z.style) == "poison" else ("burn" if str(z.style) == "fire" else "slow"), 1.2, float(z.dps) if str(z.style) in ["poison", "fire"] else 0.6)
	g.state.mzones = _zones(g).filter(func(z: Dictionary) -> bool: return float(z.t) > 0.0)


## Damage factor on an enemy (ice armour).
static func damage_taken(m: Dictionary) -> float:
	return float(m.get("armor", 1.0)) if float(m.get("armor_t", 0.0)) > 0.0 else 1.0


## Per enemy timers that run outside a move (armour, then its shards).
static func tick_mob(g: Node, m: Dictionary, dt: float) -> void:
	if float(m.get("armor_t", 0.0)) > 0.0:
		m.armor_t = float(m.armor_t) - dt
		if float(m.armor_t) <= 0.0:
			var spec := move("ice_armor")
			for i in range(int(spec.get("shards", 10))):
				_bullet(g, (m.p as Vector2) - Vector2(0, m.cy), TAU * i / float(spec.get("shards", 10)), spec, m)
			g._sound_raw("blast")
			# the shell bursts: its crystals fly as shards, chips rain down round it
			if _fx(g) != null:
				_fx(g).shatter((m.p as Vector2) - Vector2(0, float(m.cy) * 0.5), 22, float(m.r) * 1.3, Vector2.ZERO, 260.0)
				_fx(g).impact(m.p, "medium", _boss(m))


# ---------- drawing ----------

## Warnings that fill up, pools, globs in flight, armour and windup glow.
static func draw(g: Node, l: CanvasItem, t: float) -> void:
	if _fx(g) != null:
		_draw_px(g, l, t)
		return
	for z: Dictionary in _zones(g):
		var c: Color = STYLE.get(str(z.get("style", "ice")), Color(0.8, 0.9, 1.0))
		var k: float = 1.0 - float(z.t) / maxf(0.01, float(z.get("max", 1.0)))
		match str(z.kind):
			"strike":
				l.draw_circle(z.p, float(z.r), Color(c, 0.12 + 0.25 * k))
				l.draw_circle(z.p, float(z.r) * k, Color(c, 0.25))
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 32, Color(c, 0.9), 3.0)
				if z.has("from"):
					var q: Vector2 = (z.from as Vector2).lerp(z.p, k) - Vector2(0, sin(k * PI) * 160.0)
					l.draw_circle(q, 14.0, Color(c, 0.95))
			"pool":
				var a := clampf(float(z.t), 0.0, 1.0)
				l.draw_circle(z.p, float(z.r), Color(c, 0.28 * a))
				for i in range(5):
					var q: Vector2 = z.p + Vector2(cos(i * 1.3 + t), sin(i * 2.1 + t * 0.7)) * float(z.r) * 0.6
					l.draw_circle(q, 5.0, Color(c.lightened(0.3), 0.6 * a))
			"lane":
				l.draw_line(z.p, z.q, Color(c, 0.18 + 0.3 * k), float(z.w))
				l.draw_line(z.p, (z.p as Vector2).lerp(z.q, k), Color(c, 0.45), float(z.w) * 0.5)
			"cone":
				var pts := PackedVector2Array([z.p])
				for i in range(13):
					var a := float(z.a) - float(z.arc) / 2.0 + float(z.arc) * i / 12.0
					pts.append((z.p as Vector2) + Vector2(cos(a), sin(a)) * float(z.r))
				l.draw_colored_polygon(pts, Color(c, 0.12 + 0.3 * k))
	for m: Dictionary in g.mobs:
		var mid: Vector2 = (m.p as Vector2) - Vector2(0, m.cy)
		if m.get("tele", false):
			l.draw_arc(m.p, float(m.r) + 22.0 + 6.0 * sin(t * 20.0), 0.0, TAU, 24, Color(1.0, 0.5, 0.45, 0.85), 4.0)
		if float(m.get("armor_t", 0.0)) > 0.0:
			l.draw_circle(mid, float(m.r) * 1.3 + 10.0, Color(0.7, 0.92, 1.0, 0.3))
			l.draw_arc(mid, float(m.r) * 1.3 + 10.0, 0.0, TAU, 6, Color(0.9, 0.98, 1.0, 0.9), 4.0)


## The warnings on the pixel grid (frost_fx.gd), under the actors: rings that
## fill with a dot grid and a growing inner ring, lanes and cones the same,
## other pools as rings, and a crawling rim at a winding-up foot. Ice pools
## are drawn by frost_fx.gd as one slab under the hero's shadow.
static func _draw_px(g: Node, l: CanvasItem, t: float) -> void:
	var fx := _fx(g)
	for z: Dictionary in _zones(g):
		var c: Color = STYLE.get(str(z.get("style", "ice")), Color(0.8, 0.9, 1.0))
		var k: float = 1.0 - float(z.t) / maxf(0.01, float(z.get("max", 1.0)))
		match str(z.kind):
			"strike":
				if float(z.r) > 0.0:
					fx.ring(l, z.p, float(z.r), k, c, t)
			"pool":
				# ice pools are one slab on the floor's own layer (frost_fx.gd draw_floor)
				if not str(z.style) in ["ice", "frost"]:
					var fade := clampf(float(z.t), 0.0, 1.0) * clampf((float(z.max) - float(z.t)) / 0.3, 0.0, 1.0)
					fx.ring(l, z.p, float(z.r), 0.0, Color(c, fade), t)
			"lane":
				var to: Vector2 = (z.q as Vector2) - (z.p as Vector2)
				fx.strip(l, z.p, to.normalized(), to.length(), float(z.w) * 0.5, k, c, t)
			"cone":
				fx.cone(l, z.p, float(z.r), float(z.a), float(z.arc), k, c, t)
	for m: Dictionary in g.mobs:
		if m.get("tele", false):
			fx.px_ellipse(l, m.p, float(m.r) + 18.0, (float(m.r) + 18.0) * 0.62, Color(1.0, 0.55, 0.5, 0.85), 3, int(floorf(t * 12.0)))


## Over the actors (frost_fx.gd): ice shards in flight, hail falling onto its
## warnings, globs on their arc, a guardian's ice armour and impact flashes.
static func draw_over(g: Node, l: CanvasItem, t: float) -> void:
	var fx := _fx(g)
	if fx == null:
		return
	for z: Dictionary in _zones(g):
		if str(z.kind) != "strike" or float(z.r) <= 0.0 or bool(z.get("self", false)):
			continue
		var k: float = 1.0 - float(z.t) / maxf(0.01, float(z.get("max", 1.0)))
		if z.has("from"):
			# a glob thrown in an arc
			var q: Vector2 = (z.from as Vector2).lerp(z.p, k)
			fx.hailstone(l, q, sin(k * PI) * 160.0, 2, k)
		elif k > 0.55:
			# hail: a stone dropping out of the dark onto its warning
			var f := (k - 0.55) / 0.45
			fx.hailstone(l, z.p, (1.0 - f * f) * 420.0, 2 + int(float(z.r) > 50.0), f)
	for m: Dictionary in g.mobs:
		if float(m.get("armor_t", 0.0)) > 0.0:
			var share := clampf(float(m.armor_t) / maxf(0.1, float(m.get("armor_max", 4.0))), 0.0, 1.0)
			# the shell stands round the figure as it is drawn (a guardian is drawn much larger than its body)
			var span := maxf(float(m.r) * 1.25 + 8.0, float(m.cy) * 0.95)
			fx.armor(l, (m.p as Vector2) - Vector2(0, 6), span, share, t, clampi(int(span / 22.0), 3, 8))
	for s: Dictionary in g.eshots:
		var size := clampi(int(float(s.get("size", 8.0)) / 3.0) + 3, 4, 8)
		if s.get("fist", false):
			size = 9
		if str(s.get("style", "ice")) in ["ice", "frost"] or not s.has("style"):
			fx.shard(l, s.p, s.v, size, t, float(s.get("seed", 0.0)))
		else:
			draw_shot(l, s, t)
	fx.draw_flashes(l)


## A move's enemy shot in its style; false for plain shots. With frost_fx every
## shot is drawn over the actors instead (draw_over), so this reports it drawn.
static func draw_shot(l: CanvasItem, s: Dictionary, t: float) -> bool:
	if not s.has("style"):
		return false
	var c: Color = STYLE.get(str(s.style), Color(0.8, 0.9, 1.0))
	var r := float(s.get("size", 14.0))
	var d := (s.v as Vector2).normalized()
	if str(s.style) in ["ice", "frost"]:
		var n := Vector2(-d.y, d.x)
		l.draw_circle(s.p, r * 1.6, Color(c, 0.3))
		l.draw_colored_polygon(PackedVector2Array([s.p + d * r * 1.6, s.p + n * r * 0.6, s.p - d * r, s.p - n * r * 0.6]), Color(0.92, 0.98, 1.0))
	else:
		l.draw_circle(s.p, r * 1.5, Color(c, 0.35))
		l.draw_circle(s.p, r * 0.8, c)
	return true
