extends RefCounted
## Class relics of themed runs (the Frostgruft): each run hides one relic for
## the hero's class (theme.relics.pools) in the secret room of a random floor,
## sealed by four plates stepped in order. A wielded relic replaces the attack
## (stronger than the class weapon) and the skills on keys 1-4, which open at
## their level: the gravity staff (ball, wall, bar, rock throw, stone golem)
## and the gravity hammer (smash, leap slam, gravity field, rock wave, meteor).
## Works on the game (src/hell/hell_game.gd) like hero_kit.gd and boss_kit.gd.

const HeroKit = preload("res://src/hell/hero_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")


# ---------- the run's relic ----------

## Rolls where and which relic this run hides (none when the class has no relic yet).
static func choose_run(g: Node) -> void:
	var cfg: Dictionary = g.theme.get("relics", {})
	var pool: Array = cfg.get("pools", {}).get(g.class_id, [])
	if cfg.is_empty() or pool.is_empty():
		g.state.relic_floor = 0
		g.state.relic_item = ""
		return
	var floors: Array = cfg.floors
	g.state.relic_floor = int(floors[randi() % floors.size()])
	g.state.relic_item = str(pool[randi() % pool.size()])


## On the relic's floor: with drop "boss" nothing waits in a room, the guardian
## drops it (drop); otherwise the shrine (relic and four sealing plates) goes into the secret room.
static func place(g: Node) -> void:
	if int(g.state.get("relic_floor", 0)) != int(g.state.floor) or str(g.state.get("relic_item", "")) == "" or str(g.state.relic) != "":
		return
	if str(g.theme.get("relics", {}).get("drop", "")) == "boss":
		return
	var room: Dictionary = {}
	for r: Dictionary in g.W.rooms:
		if r.type == "secret":
			room = r
	if room.is_empty():
		return
	var cfg: Dictionary = g.theme.relics
	var c: float = g.C
	g.W.ents = g.W.ents.filter(func(e: Dictionary) -> bool: return not (e.room == room.index and e.type == "chest"))
	g.W.ents.append({"type": "relic", "x": (room.bx + room.bw / 2.0) * c, "y": (room.by + room.bh / 2.0) * c, "room": room.index, "item": g.state.relic_item, "seal": "relic"})
	var spots := [[2.5, 2.2], [room.bw - 2.5, 2.2], [2.5, room.bh - 2.2], [room.bw - 2.5, room.bh - 2.2]]
	for i in range(4):
		g.W.ents.append({"type": "plate", "x": (room.bx + spots[i][0]) * c, "y": (room.by + spots[i][1]) * c, "room": room.index, "group": "relic", "order": int(cfg.order[i])})
	g.W.groups["relic"] = {"kind": "sequence", "label": str(cfg.label), "reward": "relic", "solved": false, "next": 1}
	room.info = "Ein Siegel aus vier Platten bewacht ein Relikt."
	g.state.relic_room = room.index


## The guardian of the relic floor falls: its relic chest lies where it fell.
static func drop(g: Node, at: Vector2) -> void:
	if int(g.state.get("relic_floor", 0)) != int(g.state.floor) or str(g.state.get("relic_item", "")) == "" or str(g.state.relic) != "":
		return
	if str(g.theme.get("relics", {}).get("drop", "")) != "boss":
		return
	g.W.ents.append({"type": "relic", "x": at.x, "y": at.y + 40.0, "room": g.state.room, "item": g.state.relic_item, "chest": true})
	g._burst(at - Vector2(0, 40), 60, true)
	g._toast("Der Wächter lässt eine Reliktruhe fallen!")


## True when a relic can be taken: boss chests at once, shrines once their seal broke.
static func relic_free(g: Node, e: Dictionary) -> bool:
	return not e.has("seal") or bool(g.W.groups.get(e.seal, {}).get("solved", false))


## The wielded relic's data, or {} with the class weapon in hand.
static func wielded(g: Node) -> Dictionary:
	return g.theme.get(str(g.state.relic), {}) if g.relic_on() else {}


static func skill(g: Node, key: String) -> Dictionary:
	for s: Dictionary in wielded(g).get("skills", []):
		if str(s.key) == key:
			return s
	return {}


# ---------- attack ----------

## The relic's attack instead of the class weapon's; true when it handled the shot.
static func attack(g: Node, dir: Vector2) -> bool:
	var rel := wielded(g)
	if rel.is_empty():
		return false
	if rel.has("ball"):
		var ball: Dictionary = rel.ball
		g.state.cool = float(ball.cooldown) * CardKit.rate_mult(g)
		var n := 1 + CardKit.level(g, "twin_ball")
		for k in range(n):
			var a := dir.angle() + (float(k) - (n - 1) / 2.0) * float(CardKit.value(g, "twin_ball", "spread", 0.18))
			g.shots.append({"p": Vector2(g.player.x, g.player.y - 40), "v": Vector2(cos(a), sin(a)) * float(ball.speed), "t": float(ball.life), "kind": "gravity",
				"splash": float(ball.burst), "mult": float(ball.damage) / g.base_damage(), "hits": []})
		g._sound("shot_magic")
		return true
	var atk: Dictionary = rel.attack
	g.state.cool = float(atk.cooldown) * CardKit.rate_mult(g)
	var back := float(atk.get("backstab", 1.0))
	var reach := float(atk.reach) * (1.0 + float(CardKit.value(g, "wide_smash", "reach", 0.0)) * CardKit.level(g, "wide_smash"))
	var from := Vector2(g.player.x, g.player.y - 40)
	g.swing = {"a": dir.angle(), "t": 0.22}
	for m: Dictionary in g.mobs:
		var to: Vector2 = m.p - Vector2(0, m.cy) - from
		if m.spawn <= 0.0 and to.length() < reach + m.r and absf(angle_difference(dir.angle(), to.angle())) <= float(atk.arc) / 2.0:
			# a stab into a back (an enemy not facing the hero, or a stunned one) hits harder
			var behind: bool = (m.face as Vector2).dot(to.normalized()) > 0.2 or float(m.get("stun", 0.0)) > 0.0
			g._damage_mob(m, dir * 400.0, float(atk.damage) / g.base_damage() * (back if behind else 1.0))
			if not m.has("kit") and m.kind != "boss":
				m.p -= to.normalized() * float(atk.pull) * 0.3
	for e: Dictionary in g.breakables:
		var to := Vector2(e.x, e.y - 40) - from
		if not e.get("broken", false) and to.length() < reach + 40.0 and absf(angle_difference(dir.angle(), to.angle())) <= float(atk.arc) / 2.0:
			g._hit_breakable(e, Vector2(e.x, e.y - 40))
	g.fx.append({"kind": "smash", "p": from, "a": dir.angle(), "r": reach, "arc": float(atk.arc), "t": 0.22, "max": 0.22})
	g._sound("swing")
	return true


# ---------- skills 1-4 ----------

## Key press with a relic in hand; false when no relic skill sits on that key.
static func press(g: Node, key: String) -> bool:
	var s := skill(g, key)
	if s.is_empty():
		return false
	if int(g.state.level) < int(s.unlock):
		g._toast("%s ab Level %d." % [s.name, int(s.unlock)])
		return true
	if float(g.state.skill_cd.get(str(s.id), 0.0)) > 0.0:
		g._sound("no_cooldown")
		return true
	var aim := HeroKit._aim(g)
	var at := HeroKit.target(g)
	match str(s.id):
		"g_wall":
			var size := 1.0 + float(CardKit.value(g, "dense_wall", "size", 0.0)) * CardKit.level(g, "dense_wall")
			HeroKit.gravity_wall(g, size)
		"g_bar":
			g.bar_drag = {"a": at, "key": true}
			return true
		"g_rock":
			# a boulder rises at the aim, then flies at the nearest enemy
			g.pending.append({"do": "rock", "t": float(s.lift), "at": at, "s": s})
			g.fx.append({"kind": "lift", "p": at, "t": float(s.lift), "max": float(s.lift)})
			g._sound_raw("windup_summon")
		"g_golem":
			var boost := 1.0 + float(CardKit.value(g, "golem_core", "boost", 0.0)) * CardKit.level(g, "golem_core")
			g.allies.append({"p": Vector2(g.player.x + float(g.player.face) * 90.0, g.player.y), "t": float(s.time), "max": float(s.time), "hp": float(s.hp) * boost,
				"dmg": float(s.damage) * boost, "cool": 0.5, "slam": 0.0, "face": 1.0, "rise": 0.6, "s": s})
			g._burst(Vector2(g.player.x, g.player.y - 30), 40, true)
			g._sound_raw("attack_summon")
		"h_leap":
			var dist := minf(float(s.distance), Vector2(g.player.x, g.player.y - 40).distance_to(at))
			g.dash = {"dir": aim, "speed": dist / float(s.time), "t": float(s.time), "mult": 0.0, "hit": [], "land": "h_leap"}
			g.state.inv = maxf(float(g.state.inv), float(s.time) + 0.15)
			g._sound_raw("step")
		"h_field":
			var boost := 1.0 + float(CardKit.value(g, "deep_field", "boost", 0.0)) * CardKit.level(g, "deep_field")
			g.zones.append({"kind": "gfield", "p": at, "r": float(s.radius) * boost, "t": float(s.time), "max": float(s.time), "pull": float(s.pull) * boost,
				"slow": float(s.slow), "dps": float(s.dps)})
			g._sound_raw("void_burst")
		"h_wave":
			for k in range(int(s.count)):
				var p := Vector2(g.player.x, g.player.y) + aim * float(s.step) * (k + 1)
				g.pending.append({"do": "spike", "t": float(s.every) * (k + 1), "at": p, "s": s})
			g._sound_raw("attack_slam")
		"d_step":
			# through up to `hits` enemies near the aim, a stab in each back
			var hits := int(s.hits) + int(CardKit.value(g, "long_shadow", "hits", 0)) * CardKit.level(g, "long_shadow")
			var near: Array = g.mobs.filter(func(m: Dictionary) -> bool: return m.spawn <= 0.0 and (m.p as Vector2).distance_to(Vector2(g.player.x, g.player.y)) < float(s.range))
			near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.p as Vector2).distance_to(at) < (b.p as Vector2).distance_to(at))
			for k in range(mini(hits, near.size())):
				g.pending.append({"do": "step", "t": float(s.every) * k, "m": near[k], "s": s})
			g.state.inv = maxf(float(g.state.inv), float(s.every) * hits + 0.2)
			g._sound_raw("void_burst")
		"d_blades":
			var cyc := 1.0 + float(CardKit.value(g, "blade_cyclone", "radius", 0.0)) * CardKit.level(g, "blade_cyclone")
			g.state.blades = {"t": float(s.time), "r": float(s.radius) * cyc, "every": float(s.every), "tick": 0.0, "dmg": float(s.damage)}
			g._sound_raw("swing")
		"d_smoke":
			var tm := float(s.time) + float(CardKit.value(g, "thick_smoke", "time", 0.0)) * CardKit.level(g, "thick_smoke")
			g.state.stealth = tm
			g.zones.append({"kind": "smoke", "p": Vector2(g.player.x, g.player.y), "r": float(s.radius), "t": tm, "max": tm, "slow": float(s.slow)})
			g._sound_raw("blast")
		"d_thousand":
			g.zones.append({"kind": "blades", "p": at, "r": float(s.radius), "t": float(s.time), "max": float(s.time), "tick": 0.0, "every": float(s.every), "dmg": float(s.damage)})
			g._sound_raw("attack_salve")
		"h_meteor":
			var n := 1 + int(CardKit.value(g, "meteor_shower", "count", 0)) * CardKit.level(g, "meteor_shower")
			for k in range(n):
				var off := Vector2.ZERO if k == 0 else Vector2(cos(k * 2.1), sin(k * 2.1)) * float(s.radius) * 0.9
				var mult := 1.0 if k == 0 else float(CardKit.value(g, "meteor_shower", "damage", 0.4))
				g.pending.append({"do": "meteor", "t": float(s.delay) + k * 0.2, "at": at + off, "s": s, "mult": mult})
				g.zones.append({"kind": "meteor", "p": at + off, "r": float(s.radius) * (1.0 if k == 0 else 0.6), "t": float(s.delay) + k * 0.2, "max": float(s.delay) + k * 0.2})
			g._sound_raw("windup_beam")
	g.state.skill_cd[str(s.id)] = float(s.cooldown)
	return true


## Key release: the bar drawn while key 2 was held.
static func release(g: Node, key: String) -> bool:
	var s := skill(g, key)
	if s.is_empty():
		return false
	if str(s.id) == "g_bar" and g.bar_drag.get("key", false):
		HeroKit.gravity_bar(g, g.bar_drag.a, HeroKit.target(g))
		g.bar_drag = {}
	return true


## Where a leap slam lands: the area blow, its pull and the aftershock card.
static func land(g: Node, what: String) -> void:
	if what != "h_leap":
		return
	var s := skill(g, "1")
	var at := Vector2(g.player.x, g.player.y)
	_area(g, at, float(s.radius), float(s.damage), float(s.pull))
	g.fx.append({"kind": "quake", "p": at, "r": float(s.radius), "t": 0.4, "max": 0.4})
	g._sound("blast")
	if CardKit.level(g, "aftershock") > 0:
		g.pending.append({"do": "quake", "t": 0.4, "at": at, "r": float(s.radius), "mult": float(s.damage) * float(CardKit.value(g, "aftershock", "damage", 0.6))})


## Hits every enemy in a circle; pull > 0 drags them towards the centre first.
static func _area(g: Node, at: Vector2, radius: float, mult: float, pull: float) -> void:
	for m: Dictionary in g.mobs:
		var to: Vector2 = m.p - at
		if m.spawn <= 0.0 and to.length() < radius + m.r:
			if pull > 0.0 and not m.has("kit") and m.kind != "boss" and to.length() > 20.0:
				m.p -= to.normalized() * minf(pull, to.length() - 20.0)
			g._damage_mob(m, to.normalized() * 300.0, mult)


# ---------- per frame ----------

static func update(g: Node, dt: float) -> void:
	for p: Dictionary in g.pending:
		p.t = float(p.t) - dt
		if float(p.t) > 0.0:
			continue
		var s: Dictionary = p.get("s", {})
		match str(p.do):
			"rock":
				var from: Vector2 = p.at - Vector2(0, 90)
				var target := HeroKit.target(g)
				var best := INF
				for m: Dictionary in g.mobs:
					if m.spawn <= 0.0 and from.distance_to(m.p) < best:
						best = from.distance_to(m.p)
						target = m.p - Vector2(0, m.cy)
				g.shots.append({"p": from, "v": (target - from).normalized() * float(s.speed), "t": float(s.life), "kind": "rock", "mult": float(s.damage),
					"burst": float(s.burst), "burst_mult": float(s.damage), "hits": [], "big": 2.0,
					"split": CardKit.level(g, "heavy_rock") * int(CardKit.value(g, "heavy_rock", "count", 4))})
				g._sound_raw("attack_slam")
			"spike":
				_area(g, p.at, float(s.radius), float(s.damage), 0.0)
				g.fx.append({"kind": "spike", "p": p.at, "t": 0.5, "max": 0.5})
			"meteor":
				_area(g, p.at, float(s.radius) * (1.0 if float(p.mult) >= 1.0 else 0.6), float(s.damage) * float(p.mult), 0.0)
				g.fx.append({"kind": "quake", "p": p.at, "r": float(s.radius), "t": 0.5, "max": 0.5})
				g._burst(p.at, 50, true)
				g._sound("blast")
			"quake":
				_area(g, p.at, float(p.r), float(p.mult), 0.0)
				g.fx.append({"kind": "quake", "p": p.at, "r": float(p.r), "t": 0.35, "max": 0.35})
			"step":
				var m: Dictionary = p.m
				if g.mobs.has(m):
					var from := Vector2(g.player.x, g.player.y - 40)
					var behind: Vector2 = m.p - (m.face as Vector2) * 60.0
					if not g.box_blocked(g._player_box(behind.x, behind.y)):
						g.player.x = behind.x
						g.player.y = behind.y
					g.fx.append({"kind": "blink", "p": from, "q": Vector2(g.player.x, g.player.y - 40), "t": 0.25, "max": 0.25})
					g._damage_mob(m, (m.p - from).normalized() * 300.0, float(s.damage) * float(g.theme.shadow_dagger.attack.backstab))
			"death_shot":
				var aim := HeroKit._aim(g)
				g.shots.append({"p": Vector2(g.player.x, g.player.y - 40), "v": aim * 1600.0, "t": 1.2, "kind": "arrow", "mult": 12.0, "pierce": true, "hits": [], "big": 4.0})
				g._burst(Vector2(g.player.x, g.player.y - 40), 30, true)
				g._sound_raw("attack_arrow")
	g.pending = g.pending.filter(func(p: Dictionary) -> bool: return float(p.t) > 0.0)
	var bl: Dictionary = g.state.get("blades", {})
	if not bl.is_empty():
		bl.t = float(bl.t) - dt
		bl.tick = float(bl.tick) - dt
		if float(bl.tick) <= 0.0:
			bl.tick = float(bl.every)
			_area(g, Vector2(g.player.x, g.player.y - 30), float(bl.r), float(bl.dmg), 0.0)
		if float(bl.t) <= 0.0:
			g.state.blades = {}
	g.state.stealth = maxf(0.0, float(g.state.get("stealth", 0.0)) - dt)
	for z: Dictionary in g.zones:
		match z.kind:
			"blades", "rain":
				z.tick = float(z.tick) - dt
				if float(z.tick) <= 0.0:
					z.tick = float(z.get("every", 0.2))
					_area(g, z.p, float(z.r), float(z.get("dmg", 0.6)), 0.0)
			"smoke":
				for m: Dictionary in g.mobs:
					if (m.p as Vector2).distance_to(z.p) < float(z.r):
						HeroKit.slow_mob(g, m, float(z.slow), 0.2)
		if z.kind != "gfield":
			continue
		# gravity field: enemies are dragged to the middle, slowed and ground down
		for m: Dictionary in g.mobs:
			var to: Vector2 = z.p - m.p
			if m.spawn <= 0.0 and to.length() < float(z.r):
				if not m.has("kit") and m.kind != "boss" and to.length() > 16.0:
					m.p += to.normalized() * minf(float(z.pull) * dt, to.length() - 16.0)
				HeroKit.slow_mob(g, m, float(z.slow), 0.2)
				m.hp -= float(z.dps) * g.base_damage() * dt
	_update_allies(g, dt)


## The stone golem: rises, walks to the nearest enemy, slams it; crumbles when its time is up.
static func _update_allies(g: Node, dt: float) -> void:
	for a: Dictionary in g.allies:
		if a.has("sub"):
			continue
		a.t = float(a.t) - dt
		a.rise = maxf(0.0, float(a.rise) - dt)
		a.slam = maxf(0.0, float(a.slam) - dt)
		a.cool = float(a.cool) - dt
		if float(a.rise) > 0.0:
			continue
		var s: Dictionary = a.s
		var best: Dictionary = {}
		var bd := INF
		for m: Dictionary in g.mobs:
			if m.spawn <= 0.0 and (a.p as Vector2).distance_to(m.p) < bd:
				bd = (a.p as Vector2).distance_to(m.p)
				best = m
		var goal: Vector2 = best.p if not best.is_empty() else Vector2(g.player.x - 80.0, g.player.y + 20.0)
		var to: Vector2 = goal - a.p
		if to.length() > float(s.reach) * 0.8:
			var step: Vector2 = to.normalized() * float(s.speed) * dt
			if not g.box_blocked(Rect2(a.p.x + step.x - 30, a.p.y + step.y - 24, 60, 24), true):
				a.p += step
			a.face = signf(to.x) if absf(to.x) > 1.0 else a.face
		elif not best.is_empty() and float(a.cool) <= 0.0:
			a.cool = float(s.every)
			a.slam = 0.3
			_area(g, best.p, 70.0, float(a.dmg), 0.0)
			g.fx.append({"kind": "quake", "p": best.p, "r": 70.0, "t": 0.3, "max": 0.3})
			g._sound_raw("attack_slam")
	for a: Dictionary in g.allies:
		if float(a.t) <= 0.0:
			g._burst(a.p - Vector2(0, 40), 30)
	g.allies = g.allies.filter(func(a: Dictionary) -> bool: return float(a.t) > 0.0)


## Splits a bursting rock into shards (heavy_rock card).
static func split_rock(g: Node, s: Dictionary) -> void:
	var n := int(s.get("split", 0))
	for k in range(n):
		var a := TAU * k / n
		g.shots.append({"p": s.p, "v": Vector2(cos(a), sin(a)) * 600.0, "t": 0.45, "kind": "shard", "mult": float(CardKit.value(g, "heavy_rock", "damage", 1.0)), "hits": []})


# ---------- drawing ----------

## Relic effects in the world: lifted rocks, smash arcs, quakes, spikes, the field, the golem,
## the dagger's smoke, blade cyclone and blade rain, the arrow rain and charging shots.
static func draw(g: Node, l: Node2D, t: float) -> void:
	var dagger: Texture2D = g.tex.get("weapon_shadow_dagger")
	for z: Dictionary in g.zones:
		match z.kind:
			"smoke":
				var a: float = clampf(float(z.t), 0.0, 1.0)
				for i in range(9):
					var q: Vector2 = z.p + Vector2(cos(i * 0.7 + t * 0.5), sin(i * 1.3 + t * 0.4)) * float(z.r) * 0.55
					l.draw_circle(q, float(z.r) * 0.4, Color(0.35, 0.33, 0.45, 0.28 * a))
			"blades", "rain":
				l.draw_circle(z.p, float(z.r), Color(0.6, 0.5, 0.9, 0.12))
				for i in range(10):
					var fall := fmod(t * 3.0 + i * 0.37, 1.0)
					var q: Vector2 = z.p + Vector2(fmod(i * 97.0, 2.0 * float(z.r)) - float(z.r), fmod(i * 53.0, float(z.r)) - float(z.r) * 0.5)
					if z.kind == "blades" and dagger != null:
						l.draw_texture_rect(dagger, Rect2(q - Vector2(6, 200.0 * (1.0 - fall)), dagger.get_size() * 2.0), false, Color(0.85, 0.75, 1.0, 1.0 - fall * 0.4))
					else:
						l.draw_line(q - Vector2(0, 220.0 * (1.0 - fall)), q - Vector2(0, 220.0 * (1.0 - fall) - 30.0), Color(0.9, 0.95, 1.0, 0.9), 3.0)
	var bl: Dictionary = g.state.get("blades", {})
	if not bl.is_empty() and dagger != null:
		for i in range(4):
			var a := t * 9.0 + i * TAU / 4.0
			var q := Vector2(g.player.x, g.player.y - 30) + Vector2(cos(a), sin(a)) * float(bl.r) * 0.8
			l.draw_set_transform(q, a + PI / 2.0)
			l.draw_texture_rect(dagger, Rect2(-dagger.get_size(), dagger.get_size() * 2.0), false, Color(0.85, 0.75, 1.0))
			l.draw_set_transform(Vector2.ZERO)
	if float(g.state.get("phoenix_t", 0.0)) > 0.0:
		var c := Vector2(g.player.x, g.player.y - 30)
		for i in range(6):
			var a := t * 4.0 + i * TAU / 6.0
			l.draw_circle(c + Vector2(cos(a), sin(a)) * 150.0, 16.0, Color(1.0, 0.55, 0.2, 0.8))
	for f: Dictionary in g.fx:
		if f.kind == "charge":
			var k: float = 1.0 - float(f.t) / maxf(0.01, float(f.max))
			l.draw_arc(Vector2(g.player.x, g.player.y - 40), 70.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(1.0, 0.9, 0.5), 7.0)
	for f: Dictionary in g.fx:
		var k: float = float(f.t) / maxf(0.01, float(f.max))
		match f.kind:
			"lift":
				var rock: Texture2D = g.tex.rock_throw
				var c: Vector2 = f.p - Vector2(0, 90.0 * (1.0 - k))
				l.draw_circle(f.p, 40.0 * (1.0 - k) + 10.0, Color(0.55, 0.4, 1.0, 0.3))
				l.draw_texture_rect(rock, Rect2(c - rock.get_size(), rock.get_size() * 2.0), false, Color(1, 1, 1, 1.0 - k * 0.5))
			"smash":
				var a0: float = float(f.a) - float(f.arc) / 2.0
				l.draw_arc(f.p, float(f.r) * (1.0 - k * 0.3), a0, a0 + float(f.arc), 24, Color(0.75, 0.6, 1.0, k), 14.0)
			"quake":
				l.draw_arc(f.p, float(f.r) * (1.2 - k), 0.0, TAU, 40, Color(0.7, 0.55, 1.0, k), 10.0)
				l.draw_circle(f.p, float(f.r) * (1.0 - k) * 0.6, Color(0.35, 0.2, 0.7, 0.35 * k))
			"spike":
				var sp: Texture2D = g.tex.rock_spike
				var h := sp.get_size() * Vector2(1.0, 1.0 - absf(k - 0.5) * 2.0 + 0.4)
				l.draw_texture_rect(sp, Rect2(f.p - Vector2(h.x / 2.0, h.y), h), false)
	for z: Dictionary in g.zones:
		match z.kind:
			"gfield":
				l.draw_circle(z.p, float(z.r), Color(0.25, 0.12, 0.55, 0.28))
				for i in range(3):
					var r: float = float(z.r) * fmod(1.0 - t * 0.6 - i / 3.0, 1.0)
					l.draw_arc(z.p, maxf(4.0, r), 0.0, TAU, 32, Color(0.75, 0.6, 1.0, 0.6), 3.0)
			"meteor":
				var k: float = 1.0 - float(z.t) / maxf(0.01, float(z.max))
				l.draw_circle(z.p, float(z.r), Color(1.0, 0.4, 0.5, 0.12 + 0.25 * k))
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 40, Color(1.0, 0.6, 0.7, 0.9), 3.0)
				var rock: Texture2D = g.tex.rock_throw
				var c: Vector2 = z.p - Vector2(0, 600.0 * (1.0 - k))
				l.draw_texture_rect(rock, Rect2(c - rock.get_size() * 1.5, rock.get_size() * 3.0), false)
	for a: Dictionary in g.allies:
		if a.has("sub"):
			continue
		var frames := 6
		var walk: bool = float(a.slam) <= 0.0
		var name := "%s%d" % ["ally_golem_walk_f" if walk else "ally_golem_f", int(t * 8.0) % frames]
		var im: Texture2D = g.tex.get(name)
		if im == null:
			continue
		var grow := 1.0 - float(a.rise) / 0.6
		var size := im.get_size() * float(a.s.scale) * 0.5 * (0.4 + 0.6 * grow)
		var pos: Vector2 = a.p - Vector2(size.x / 2.0, size.y)
		var alpha := clampf(float(a.t) / 1.0, 0.0, 1.0)
		if float(a.face) < 0.0:
			l.draw_set_transform(pos + Vector2(size.x, 0), 0.0, Vector2(-1, 1))
			l.draw_texture_rect(im, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, alpha))
			l.draw_set_transform(Vector2.ZERO)
		else:
			l.draw_texture_rect(im, Rect2(pos, size), false, Color(1, 1, 1, alpha))
		# life left as a thin bar over the golem
		l.draw_rect(Rect2(a.p - Vector2(40, size.y + 14), Vector2(80, 6)), Color(0.05, 0.03, 0.1, 0.8))
		l.draw_rect(Rect2(a.p - Vector2(40, size.y + 14), Vector2(80.0 * float(a.t) / float(a.max), 6)), Color(0.75, 0.6, 1.0))
